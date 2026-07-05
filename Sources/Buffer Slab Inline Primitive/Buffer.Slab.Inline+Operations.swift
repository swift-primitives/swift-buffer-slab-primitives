import Affine_Primitives_Standard_Library_Integration
public import Finite_Bounded_Primitives
import Ordinal_Primitives_Standard_Library_Integration
public import Store_Inline_Primitives

// MARK: - Extensions for Slab.Inline (declared in Core)
//
// All occupancy/substrate access DELEGATES to the class `Box`'s methods (declared in
// Buffer.Slab.Inline.swift). This is load-bearing for RELEASE correctness: in-place inline
// bitmap/ledger SETs reached through `self.box.header` / `self.box.storage` from this
// struct's mutating methods are elided under `-O`, but method calls on the `Box` persist.
// See the type doc-comment for the full rationale. The substrate ledger is kept `.empty`
// inside the Box mutations (untracked — the bitmap is the source of truth, single-free).
// INTERIM DEBT: occupancy placement is deferred — see HANDOFF-sparse-occupancy-placement.md.

extension Buffer.Slab.Inline where S: ~Copyable {

    /// Creates an inline slab buffer with all slots vacant.
    ///
    /// The storage capacity equals the `wordCount` generic parameter.
    @inlinable
    public init() {
        self.init(
            header: .init(),
            storage: Store.Inline<S.Element, wordCount>()
        )
    }

    /// The number of occupied slots.
    @inlinable
    public var occupancy: Bit.Index.Count { box.occupancy }

    /// The number of elements logically held by the buffer, in the element domain.
    ///
    /// A slab's native ledger counts occupied bitmap slots (``occupancy``, a
    /// `Bit.Index.Count`). M7 re-tags that into the concrete element domain at this
    /// ``Buffer/`Protocol``` `count` witness — one occupied slot IS one live element,
    /// a numerically-sound phantom-label change (`.retag(Element.self)`).
    @inlinable
    public var count: Index<Element>.Count { box.occupancy.retag(Element.self) }

    /// Whether no slots are occupied.
    @inlinable
    public var isEmpty: Bool { box.isEmpty }

    /// Whether all storage slots are occupied.
    @inlinable
    public var isFull: Bool { box.isFull(capacity: Bit.Index.Count(UInt(wordCount))) }

    /// Whether a specific slot is occupied.
    @inlinable
    public func isOccupied(at slot: Bit.Index.Bounded<wordCount>) -> Bool {
        box.isOccupied(at: Bit.Index(slot))
    }

    // MARK: - Mutations

    /// Inserts an element at the given slot.
    ///
    /// - Precondition: The slot is not occupied.
    @inlinable
    public mutating func insert(_ element: consuming S.Element, at slot: Bit.Index.Bounded<wordCount>) {
        box.insert(consume element, at: Bit.Index(slot))
    }

    /// Removes and returns the element at the given slot.
    ///
    /// - Precondition: The slot is occupied.
    @inlinable
    public mutating func remove(at slot: Bit.Index.Bounded<wordCount>) -> S.Element {
        box.remove(at: Bit.Index(slot))
    }

    /// Replaces the element at the given slot and returns the old element.
    ///
    /// - Precondition: The slot is occupied.
    @inlinable
    public mutating func update(at slot: Bit.Index.Bounded<wordCount>, with element: consuming S.Element) -> S.Element {
        box.update(at: Bit.Index(slot), with: consume element)
    }

    /// Returns the first vacant slot, or `nil` if all slots are full.
    @inlinable
    public func firstVacant() -> Bit.Index.Bounded<wordCount>? {
        guard let slot = box.firstVacant(max: Bit.Index.Count(UInt(wordCount))) else { return nil }
        // Invariant: `box.firstVacant(max: wordCount)` only yields slots < wordCount,
        // so this bounds-checked construction always succeeds; the guard is an
        // unreachable safety net for a broken invariant, not a recoverable error.
        guard let bounded = Bit.Index.Bounded<wordCount>(slot) else {
            preconditionFailure("box.firstVacant returned a slot outside wordCount")
        }
        return bounded
    }

    /// Removes all elements from the buffer.
    @inlinable
    public mutating func removeAll() {
        box.removeAll()
    }
}

extension Buffer.Slab.Inline where S: ~Copyable, S.Element: Copyable {
    // `S` is a phantom carrier (`.Inline` stores `Store.Inline<S.Element, wordCount>`, never
    // an `S`), so the element-copy ops constrain only `S.Element: Copyable` — NOT `S: Copyable`
    // (the `~Copyable` suppression is restated per [MEM-COPY-004] so it propagates). The
    // move-only `Storage.Contiguous` carrier is the common tower; `S: Copyable` would exclude it.

    /// Borrows the element at the given slot without removing it.
    ///
    /// - Precondition: The slot is occupied.
    @inlinable
    public func peek(at slot: Bit.Index.Bounded<wordCount>) -> S.Element {
        box.peek(at: Bit.Index(slot))
    }

    /// Reads the element at the given slot without removing it.
    ///
    /// Package-scoped unbounded overload — narrows internally for `Small` delegation.
    @inlinable
    package func peek(at slot: Bit.Index) -> S.Element {
        box.peek(at: slot)
    }
}

extension Buffer.Slab.Inline where S: ~Copyable {
    /// An owned, slot-ordered snapshot of the occupied elements, for the cold
    /// Copyable-arm `Iterable`/`Sequence` conformance in the ops module.
    ///
    /// Exposed as a `package` window over the public `[S.Element]` type ([MOD-037]) so the
    /// cold conformance never reaches the box, the substrate, or a raw base pointer —
    /// `Store.Inline` deliberately vends no public base pointer. INTERIM DEBT (was a cached
    /// base pointer): this is eager and allocates; it dissolves with the deferred occupancy
    /// decision — see HANDOFF-sparse-occupancy-placement.md.
    @inlinable
    package func _occupiedElements() -> [S.Element] where S.Element: Copyable {
        box.occupiedElements(max: wordCount)
    }
}

// MARK: - Package Convenience (Unbounded Delegation)

extension Buffer.Slab.Inline where S: ~Copyable {

    /// Inserts an element at the given slot.
    ///
    /// Package-scoped unbounded overload — narrows internally for Small delegation.
    @inlinable
    package mutating func insert(_ element: consuming S.Element, at slot: Bit.Index) {
        box.insert(consume element, at: slot)
    }

    /// Removes and returns the element at the given slot.
    @inlinable
    package mutating func remove(at slot: Bit.Index) -> S.Element {
        box.remove(at: slot)
    }

    /// Replaces the element at the given slot and returns the old element.
    @inlinable
    package mutating func update(at slot: Bit.Index, with element: consuming S.Element) -> S.Element {
        box.update(at: slot, with: consume element)
    }
}

// MARK: - Sequence.Drain.Protocol

extension Buffer.Slab.Inline: Sequence.Drain.`Protocol` where S: ~Copyable {
    /// Removes every occupied element, consuming each through `body`.
    @inlinable
    public mutating func drain(_ body: (consuming S.Element) -> Void) {
        box.drain(body)
    }
}

// MARK: - Property.Inout (.drain)

extension Buffer.Slab.Inline where S: ~Copyable {
    /// In-place accessor that drains the buffer through the `Sequence.Drain` capability.
    @inlinable
    public var drain: Property<Sequence.Drain, Self>.Inout {
        mutating _read {
            yield Property<Sequence.Drain, Self>.Inout(&self)
        }
        mutating _modify {
            var accessor = Property<Sequence.Drain, Self>.Inout(&self)
            yield &accessor
        }
    }
}
