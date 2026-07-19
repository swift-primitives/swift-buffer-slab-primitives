// ===----------------------------------------------------------------------===//
//
// PROBE — Step 1 of HANDOFF-sparse-occupancy-placement.md (NOT production code).
//
// Question: does a LEAF-owned (value-position) bitmap write escape the dossier'd DSE
// (swift-issue-inlinearray-class-field-write-elision) that elides the BOX (class-position)
// bitmap write under -O?
//
// Empirical findings driving this probe shape (observe, don't theorize — [ISSUE-023]):
//  1. The bug is FULL-STACK-ONLY (dossier): only the REAL Store.Inline co-located with the
//     real Bit.Vector.Static bitmap reproduces it; hand-rolled reducers A/B/C all pass. So a
//     valid positive control must use the real types. PC below is the real Buffer.Slab.Inline.
//  2. The bug is SHAPE-SENSITIVE: in isolated test functions it fires at Inline<4> / single
//     insert@2 (occupancy -> 0) but NOT at Inline<8>/<16>. So the leaf MUST be compared to the
//     box at the SAME triggering shape (wordCount 4, insert@2), or the comparison lies.
//
// Decisive isolation (real Store.Inline + real bitmap, only class-vs-struct differs):
//   PC      : real Buffer.Slab.Inline<4>, insert@2            — fires the DSE (occupancy 0).
//   T1Box   : final class { Store.Inline<Int,4> + Bitmap4 }   — does the class reproduce it?
//   T1Leaf  : struct ~Copyable { Store.Inline<Int,4> + Bitmap4 } — THE ANSWER (1 escapes / 0 also-DSE).
//
// Context (hand-built cells, NO real Store.Inline — expected not to carry the trigger, per the
// dossier reducers; included to show the intended leaf's end-shape + single-free):
//   T0Box   : final class owning @_rawLayout cells + Bitmap4.
//   T2Leaf  : struct ~Copyable owning @_rawLayout cells + Bitmap4 + bitmap-walking deinit.
//
// Run: swift test -c release --filter "Probe"   (the answer — read the printed occupancy)
//      swift test            --filter "Probe"   (debug control — every value must be correct)

import Buffer_Slab_Inline_Primitives
import Buffer_Slab_Primitives_Test_Support
import Finite_Bounded_Primitives
import Index_Primitives
import Memory_Allocator_Primitive
import Memory_Heap_Primitives
import Storage_Contiguous_Primitives
import Store_Initialization_Primitives
import Store_Inline_Primitives
import Testing

// The real occupancy bitmap holder (Bit.Vector.Static<4>-backed), reused verbatim from
// production. `S` is a phantom on Header.Static (it stores only the bitmap).
private typealias Bitmap4 =
    Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Int>>.Slab.Header.Static<4>

private func bitIndex(_ slot: Int) -> Bit.Index { Bit.Index(Ordinal(UInt(slot))) }
private func idx4(_ slot: Int) -> Index<Int> { bitIndex(slot).retag(Int.self) }

// Single-free observation (mirrors the package's own Ledger/Counted harness).
private final class Ledger: @unchecked Sendable {
    private var _counts: [Int: Int] = [:]
}

extension Ledger {
    func record(_ id: Int) { _counts[id, default: 0] += 1 }
    var total: Int { _counts.values.reduce(0, +) }
    var maxPerID: Int { _counts.values.max() ?? 0 }
}
private struct Counted: ~Copyable {
    let id: Int
    let ledger: Ledger
    init(_ id: Int, _ ledger: Ledger) {
        self.id = id
        self.ledger = ledger
    }
    deinit { ledger.record(id) }
}

// MARK: - PC: the real buffer-owned class Box (positive control)
//
// RE-VERIFIED 2026-07-19 (fable-448 F-001): this suite got its answer — the real production
// `Box.insert` still elides the bitmap write under `-O` (occupancy=0), exactly like `T1Box`
// below. As the fix for F-001, `Box`'s mutations now `precondition` on
// `_isDebugAssertConfiguration()` and trap in release, so re-running this suite under
// `swift test -c release` would abort the whole test process rather than print a diagnostic.
// Disabled under `-O` for that reason; the T0/T1/T2 suites below use hand-built types that are
// NOT routed through the guarded production `Box`, so they remain safely runnable in release.
@Suite(
    .disabled(
        if: !_isDebugAssertConfiguration(),
        "real Box.insert now preconditions in release (fable-448 F-001 fix) — would abort the process, not fail a test"
    )
)
struct `OccupancyPlacementProbe - PC (real Buffer.Slab.Inline)` {
    @Test
    func `PC real box Inline4 insert@2 under -O`() {
        var buffer = Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Int>>.Slab.Inline<4>()
        let s2: Bit.Index.Bounded<4> = 2
        buffer.insert(42, at: s2)
        let occ = buffer.occupancy
        let o2 = buffer.isOccupied(at: s2)
        print("PC[real box, Inline4, insert@2]: occupancy=\(String(describing: occ)) isOccupied(2)=\(o2)  [correct: 1/true ; DSE: 0/false]")
    }

    @Test
    func `PC real box Inline8 sparse 0-4-7 under -O (context)`() {
        var buffer = Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Int>>.Slab.Inline<8>()
        let s0: Bit.Index.Bounded<8> = 0
        let s4: Bit.Index.Bounded<8> = 4
        let s7: Bit.Index.Bounded<8> = 7
        buffer.insert(10, at: s0)
        buffer.insert(40, at: s4)
        buffer.insert(70, at: s7)
        let occ = buffer.occupancy
        print("PC[real box, Inline8, sparse 0/4/7]: occupancy=\(String(describing: occ))  [correct: 3]")
    }
}

// MARK: - T1: real Store.Inline + real bitmap, class vs struct (the decisive isolation)

private final class T1Box {
    var header: Bitmap4
    var storage: Store.Inline<Int, 4>
    init() {
        self.header = .init()
        self.storage = .init()
    }
}

extension T1Box {
    // Mirrors the production Box.insert exactly (#1 survives; #2/#3 elided in the real box).
    func insert(_ value: Int, at slot: Int) {
        storage.initialize(at: idx4(slot), to: value)  // #1 raw-pointer cell write
        storage.initialization = .empty  // #2 ledger reset (value-field write)
        header.bitmap[bitIndex(slot)] = true  // #3 bitmap write (value-field write)
    }
    var occupancy: Bit.Index.Count { header.occupancy }
    func isOccupied(at slot: Int) -> Bool { header.isOccupied(at: bitIndex(slot)) }
}

private struct T1Leaf: ~Copyable {
    var header: Bitmap4
    var storage: Store.Inline<Int, 4>
    init() {
        self.header = .init()
        self.storage = .init()
    }
}

extension T1Leaf {
    // SAME body as T1Box — the ONLY difference between T1Box and T1Leaf is class vs struct.
    mutating func insert(_ value: Int, at slot: Int) {
        storage.initialize(at: idx4(slot), to: value)  // #1
        storage.initialization = .empty  // #2
        header.bitmap[bitIndex(slot)] = true  // #3 — value-leaf bitmap write (the seam)
    }
    var occupancy: Bit.Index.Count { header.occupancy }
    func isOccupied(at slot: Int) -> Bool { header.isOccupied(at: bitIndex(slot)) }
}

@Suite
struct `OccupancyPlacementProbe - T1 (real Store.Inline: class vs struct)` {
    @Test
    func `T1Box class over real Store.Inline insert@2 under -O`() {
        let box = T1Box()
        box.insert(42, at: 2)
        let occ = box.occupancy
        let o2 = box.isOccupied(at: 2)
        print("T1Box[class, real Store.Inline, insert@2]: occupancy=\(String(describing: occ)) isOccupied(2)=\(o2)  [correct: 1/true ; DSE: 0/false]")
    }

    @Test
    func `T1Leaf struct over real Store.Inline insert@2 under -O (THE ANSWER)`() {
        var leaf = T1Leaf()
        leaf.insert(42, at: 2)
        let occ = leaf.occupancy
        let o2 = leaf.isOccupied(at: 2)
        print("T1Leaf[struct, real Store.Inline, insert@2]: occupancy=\(String(describing: occ)) isOccupied(2)=\(o2)  [escapes: 1/true ; also-DSE: 0/false]")
    }
}

// MARK: - T0 / T2: hand-built cells (intended end-shape + single-free; context)

private final class T0Box<Element: ~Copyable> {
    var header: Bitmap4
    @_rawLayout(likeArrayOf: Element, count: 4)
    struct _Raw: ~Copyable {}
    var _storage: _Raw
    init() {
        self.header = .init()
        self._storage = _Raw()
    }
    func insert(_ element: consuming Element, at slot: Int) {
        let base = unsafe withUnsafeMutablePointer(to: &_storage) { raw in
            unsafe UnsafeMutableRawPointer(raw).assumingMemoryBound(to: Element.self)
        }
        unsafe (base + slot).initialize(to: element)
        header.bitmap[bitIndex(slot)] = true
    }
    var occupancy: Bit.Index.Count { header.occupancy }
    deinit {
        for slot in 0..<4 where header.isOccupied(at: bitIndex(slot)) {
            unsafe withUnsafePointer(to: _storage) { raw in
                let base = unsafe UnsafeMutableRawPointer(mutating: UnsafeRawPointer(raw))
                    .assumingMemoryBound(to: Element.self)
                unsafe (base + slot).deinitialize(count: 1)
            }
        }
    }
}

private struct T2Leaf<Element: ~Copyable>: ~Copyable {
    var _deinitWorkaround: AnyObject? = nil
    var header: Bitmap4
    @_rawLayout(likeArrayOf: Element, count: 4)
    struct _Raw: ~Copyable {}
    var _storage: _Raw
    init() {
        self._deinitWorkaround = nil
        self.header = .init()
        self._storage = _Raw()
    }
    mutating func insert(_ element: consuming Element, at slot: Int) {
        let base = unsafe withUnsafeMutablePointer(to: &_storage) { raw in
            unsafe UnsafeMutableRawPointer(raw).assumingMemoryBound(to: Element.self)
        }
        unsafe (base + slot).initialize(to: element)
        header.bitmap[bitIndex(slot)] = true  // value-leaf bitmap write (the seam)
    }
    var occupancy: Bit.Index.Count { header.occupancy }
    func isOccupied(at slot: Int) -> Bool { header.isOccupied(at: bitIndex(slot)) }
    deinit {
        for slot in 0..<4 where header.isOccupied(at: bitIndex(slot)) {
            unsafe withUnsafePointer(to: _storage) { raw in
                let base = unsafe UnsafeMutableRawPointer(mutating: UnsafeRawPointer(raw))
                    .assumingMemoryBound(to: Element.self)
                unsafe (base + slot).deinitialize(count: 1)
            }
        }
    }
}

@Suite
struct `OccupancyPlacementProbe - T0/T2 (hand-built leaf end-shape)` {
    @Test
    func `T0Box hand-built class insert@2 under -O (context)`() {
        let box = T0Box<Int>()
        box.insert(42, at: 2)
        let occ = box.occupancy
        print("T0Box[class, hand-built cells, insert@2]: occupancy=\(String(describing: occ))  [correct: 1]")
    }

    @Test
    func `T2Leaf intended leaf insert@2 occupancy AND single-free under -O`() {
        let ledger = Ledger()
        do {
            var leaf = T2Leaf<Counted>()
            leaf.insert(Counted(2, ledger), at: 2)
            let occ = leaf.occupancy
            let o2 = leaf.isOccupied(at: 2)
            print("T2Leaf[struct, hand-built cells, insert@2]: occupancy=\(String(describing: occ)) isOccupied(2)=\(o2)  [correct: 1/true]")
        }
        print("T2Leaf single-free: total=\(ledger.total) maxPerID=\(ledger.maxPerID)  [correct: 1/1 ; bitmap-lost: 0/0]")
    }
}
