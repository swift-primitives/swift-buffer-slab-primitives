import Affine_Primitives_Standard_Library_Integration
import Bit_Vector_Static_Primitives
import Index_Primitives
import Ordinal_Primitives_Standard_Library_Integration
public import Store_Initialization_Primitives
public import Store_Inline_Primitives

extension Buffer.Slab where S: ~Copyable {
    // MARK: - Inline (Fixed-Capacity, Stack-Allocated)

    /// A fixed-capacity slab buffer backed by inline (stack-allocated) typed storage.
    ///
    /// Uses `Store.Inline<S.Element, wordCount>` for the inline element bytes and
    /// `Header.Static<wordCount>` for the occupancy bitmap.
    ///
    /// ## Teardown + operations — owned by a class `Box` (INTERIM DEBT)
    ///
    /// Element cleanup is owned by a private reference `Box`, mirroring the heap
    /// `Buffer.Slab.Box`: the bitmap is the source of truth, and `Box.deinit` walks it and
    /// moves each occupied slot out of the substrate. The substrate `Store.Inline`'s ledger
    /// is kept `.empty` (untracked) after every seam write, so `Store.Inline.deinit` no-ops
    /// and the `Box`'s bitmap walk is the SOLE teardown — single-free in debug AND release.
    ///
    /// The MUTATING operations also live on the `Box` (as methods), and `.Inline` delegates
    /// to them. This was believed load-bearing for RELEASE correctness: the occupancy bitmap
    /// (`Header.Static`'s inline `Bit.Vector.Static`) and the ledger are INLINE values, and
    /// an in-place subscript/property SET reached through `self.box.header` / `self.box.storage`
    /// from the `.Inline` struct's mutating method IS ELIDED under `-O`. Routing the mutations
    /// through `Box` methods was expected to make them mutate the class instance's own fields
    /// via the class's `self` and therefore persist.
    ///
    /// **RE-VERIFIED 2026-07-19 (fable-448 F-001) — that expectation is FALSE.** Re-running
    /// the `PROBE-occupancy-placement-leaf-vs-box.swift` decisive isolation on the pinned
    /// toolchain (`swift-6.3.3-RELEASE`) under `swift test -c release` shows the CLASS-position
    /// `Box` write is *still* elided even when routed through a method on `self` (both the real
    /// production `Box.insert` and the hand-built `T1Box` class reducer print
    /// `occupancy=0 isOccupied(2)=false` — the DSE fires either way). Only the STRUCT-position
    /// (`~Copyable` value/leaf) placement of the same bitmap + `Store.Inline` pair escapes it
    /// (`T1Leaf` prints `occupancy=1 isOccupied(2)=true`, and the hand-built `T2Leaf` leaf shape
    /// is additionally single-free-correct). So the discriminator is class-vs-struct placement,
    /// not method-call-vs-property-access as this doc previously claimed — and the box-owned
    /// design here remains genuinely release-unsound. Because a leaf placement needs a raw,
    /// non-`mutating`-self teardown seam that `Store.Inline` does not currently expose (see
    /// below), resolving this is deferred and out of this branch's scope; see "INTERIM DEBT"
    /// below. Every `Box` mutation (`insert`/`remove`/`update`/`removeAll`/`drain`) now
    /// `precondition`s on `_isDebugAssertConfiguration()` so a release (`-O`) build traps
    /// loudly at the point of mutation instead of silently losing occupancy.
    ///
    /// A CLASS `Box` is independently REQUIRED for teardown: a `~Copyable` struct `deinit`
    /// has IMMUTABLE `self` ([MEM-COPY-001a]) and could only tear down via a raw pointer, but
    /// `Store.Inline` exposes none — only a class `deinit`'s mutable `self` can drive the
    /// mutating `move(at:)` seam. It is also the `#86652`-safe shape ([MEM-SAFE-027] /
    /// [MEM-SAFE-028] drain-box rule).
    ///
    /// ## INTERIM DEBT — occupancy placement is UNRESOLVED; RELEASE USE IS GUARDED OFF
    ///
    /// This holding patch keeps occupancy + teardown **buffer-owned** (the bitmap in
    /// `Box.header`), adjacent to the active `cow-box-deinit-omission-miscompile`; that risk
    /// is accepted *for the interim*, but its release-mode unsoundness is no longer silent —
    /// see the `precondition` note above. Whether sparse occupancy + teardown should move to
    /// the leaf is a genuine, DEFERRED architecture decision — see
    /// `.handoffs/HANDOFF-sparse-occupancy-placement.md`. Do NOT dissolve `.Inline` / `.Small`,
    /// relocate occupancy, or strip `Store.Inline` here. Moving to a leaf placement additionally
    /// requires `Store.Inline` (`swift-storage-primitives`) to expose a non-`mutating`-self
    /// teardown seam a `~Copyable` struct `deinit` can call — a cross-package change, not a
    /// decision this package can make unilaterally.
    public struct Inline<let wordCount: Int>: ~Copyable {

        @usableFromInline
        internal var box: Box

        @inlinable
        package init(
            header: Header.Static<wordCount>,
            storage: consuming Store.Inline<S.Element, wordCount>
        ) {
            self.box = Box(header: header, storage: storage)
        }
    }
}

extension Buffer.Slab.Inline where S: ~Copyable {
    // MARK: - The buffer-owned cleanup oracle + operation owner (interim)

    // refined-C ([MOD-036]): `@usableFromInline internal` so the co-located hot ops stay
    // cross-package inlinable. The cold conformances reach occupied elements through the
    // `_occupiedElements` `package` window, never the box directly (no [MOD-037] flip).
    @usableFromInline
    internal final class Box {
        @usableFromInline
        internal var header: Buffer.Slab.Header.Static<wordCount>

        @usableFromInline
        internal var storage: Store.Inline<S.Element, wordCount>

        @usableFromInline
        internal init(
            header: Buffer.Slab.Header.Static<wordCount>,
            storage: consuming Store.Inline<S.Element, wordCount>
        ) {
            self.header = header
            self.storage = storage
        }

        // The bitmap-driven teardown oracle (single-free; substrate ledger is `.empty`).
        deinit {
            var slot: Bit.Index = .zero
            let end = Bit.Index.Count(UInt(wordCount)).map(Ordinal.init)
            while slot < end {
                if header.bitmap[slot] {
                    _ = storage.move(at: slot.retag(S.Element.self))
                }
                slot += .one
            }
        }
    }
}

extension Buffer.Slab.Inline.Box where S: ~Copyable {
    // MARK: Reads

    @usableFromInline var occupancy: Bit.Index.Count { header.occupancy }
    @usableFromInline var isEmpty: Bool { header.isEmpty }
    @usableFromInline
    func isFull(capacity: Bit.Index.Count) -> Bool { header.occupancy >= capacity }
    @usableFromInline
    func isOccupied(at slot: Bit.Index) -> Bool { header.isOccupied(at: slot) }
    @usableFromInline
    func firstVacant(max: Bit.Index.Count) -> Bit.Index? { header.firstVacant(max: max) }

    // MARK: - Release-mode soundness gate (fable-448 F-001)
    //
    // RE-VERIFIED 2026-07-19: class-position (`Box`) bitmap writes are elided under `-O` even
    // when routed through a method on `self` — see the type doc-comment and
    // `PROBE-occupancy-placement-leaf-vs-box.swift`. Every mutation below traps in release
    // (`-O`) builds instead of silently losing occupancy; debug (`-Onone`) is unaffected
    // (`_isDebugAssertConfiguration()` is `true` there, so the precondition never fires).
    // `precondition` (not `assert`) is used deliberately: it stays active under `-O` and is
    // stripped only by `-Ounchecked`, which this ecosystem does not build with.
    @usableFromInline
    static func _preconditionReleaseSound(function: StaticString = #function) {
        precondition(
            _isDebugAssertConfiguration(),
            "Buffer.Slab.Inline/.Small mutation (\(function)) is release-mode-unsound "
                + "(swift-issue-inlinearray-class-field-write-elision): the box-owned occupancy "
                + "bitmap write is elided under -O, silently corrupting sparse occupancy. "
                + "Blocked pending the occupancy-placement decision — see the type doc-comment "
                + "on Buffer.Slab.Inline and .handoffs/HANDOFF-sparse-occupancy-placement.md."
        )
    }

    // MARK: Mutations (class-self writes; release-mode-unsound — see the gate above)

    @usableFromInline
    func insert(_ element: consuming S.Element, at slot: Bit.Index) {
        Self._preconditionReleaseSound()
        storage.initialize(at: slot.retag(S.Element.self), to: consume element)
        storage.initialization = .empty  // untracked: the bitmap is the source of truth
        header.bitmap[slot] = true
    }

    @usableFromInline
    func remove(at slot: Bit.Index) -> S.Element {
        Self._preconditionReleaseSound()
        let element = storage.move(at: slot.retag(S.Element.self))
        storage.initialization = .empty
        header.bitmap[slot] = false
        return element
    }

    @usableFromInline
    func update(at slot: Bit.Index, with element: consuming S.Element) -> S.Element {
        Self._preconditionReleaseSound()
        let index = slot.retag(S.Element.self)
        let old = storage.move(at: index)
        storage.initialize(at: index, to: consume element)
        storage.initialization = .empty
        return old
    }

    @usableFromInline
    func removeAll() {
        Self._preconditionReleaseSound()
        var slot: Bit.Index = .zero
        let end = Bit.Index.Count(UInt(wordCount)).map(Ordinal.init)
        while slot < end {
            if header.bitmap[slot] {
                _ = storage.move(at: slot.retag(S.Element.self))
                storage.initialization = .empty
                header.bitmap[slot] = false
            }
            slot += .one
        }
    }

    @usableFromInline
    func drain(_ body: (consuming S.Element) -> Void) {
        Self._preconditionReleaseSound()
        var slot: Bit.Index = .zero
        let end = Bit.Index.Count(UInt(wordCount)).map(Ordinal.init)
        while slot < end {
            if header.bitmap[slot] {
                let element = storage.move(at: slot.retag(S.Element.self))
                storage.initialization = .empty
                header.bitmap[slot] = false
                body(consume element)
            }
            slot += .one
        }
    }
}

extension Buffer.Slab.Inline.Box where S: ~Copyable, S.Element: Copyable {
    @usableFromInline
    func peek(at slot: Bit.Index) -> S.Element { storage[slot.retag(S.Element.self)] }

    @usableFromInline
    func occupiedElements(max wordCount: Int) -> [S.Element] {
        var result: [S.Element] = []
        var slot: Bit.Index = .zero
        let end = Bit.Index.Count(UInt(wordCount)).map(Ordinal.init)
        while slot < end {
            if header.bitmap[slot] {
                result.append(storage[slot.retag(S.Element.self)])
            }
            slot += .one
        }
        return result
    }
}

// MARK: - Conditional Conformances (Slab.Inline)

/// Sendable conformance for `Buffer.Slab.Inline`.
///
/// ## Safety Invariant
///
/// Category B (ownership transfer): `Buffer.Slab.Inline` is `~Copyable` (move-only,
/// like the heap `Buffer.Slab`) and uniquely owns its reference `Box`; cross-thread
/// transfer is a move, never sharing.
extension Buffer.Slab.Inline: @unchecked Sendable where S: ~Copyable, S.Element: Sendable {}
