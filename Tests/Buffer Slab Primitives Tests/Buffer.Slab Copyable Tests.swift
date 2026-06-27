import Buffer_Slab_Primitives
import Buffer_Slab_Primitives_Test_Support
import Memory_Allocator_Primitive
import Memory_Heap_Primitives
import Storage_Contiguous_Primitives
import Testing

// `Buffer.Slab` / `.Bounded` are MOVE-ONLY (the 90f5991 reshape: the element-free
// `Storage.Contiguous` is unconditionally `~Copyable`, so the slab never shares a box
// across copies and is exclusively owned). The former CoW capability
// (`isUnique`/`ensureUnique` divergence) was MIGRATED to an explicit `clone()` — a fresh,
// occupancy-aware, independent deep copy — NOT removed. This suite therefore tests
// `clone()` (the surviving capability) and single-free teardown (the box's bitmap-driven
// `deinit`); the withdrawn `isUnique`/`ensureUnique` sharing tests, which have no `clone()`
// analog, are dropped. (Holding patch: file name retained for minimal churn; the intent is
// now clone + teardown, not CoW. See HANDOFF-storage-inline-finalization.md.)

@Suite("Buffer.Slab Clone & Teardown")
struct SlabCloneTests {

    // MARK: - Buffer.Slab.clone()

    @Test
    func `clone preserves the occupied slots`() {
        var original = Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Int>>.Slab(minimumCapacity: 8)
        original.insert(10, at: 0)
        original.insert(20, at: 3)
        original.insert(30, at: 7)

        let copy = original.clone()
        #expect(copy.occupancy == 3)
        #expect(copy[Bit.Index(Ordinal(0 as UInt))] == 10)
        #expect(copy[Bit.Index(Ordinal(3 as UInt))] == 20)
        #expect(copy[Bit.Index(Ordinal(7 as UInt))] == 30)
        // `clone()` borrows (does not consume) — the original remains valid.
        #expect(original.occupancy == 3)
    }

    @Test
    func `clone yields an independent copy`() {
        var original = Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Int>>.Slab(minimumCapacity: 8)
        original.insert(10, at: 0)
        original.insert(20, at: 3)

        var copy = original.clone()

        // The deep copy preserves the occupied slots exactly.
        #expect(copy.occupancy == 2)
        #expect(copy[Bit.Index(Ordinal(0 as UInt))] == 10)
        #expect(copy[Bit.Index(Ordinal(3 as UInt))] == 20)

        // Mutations to the copy do NOT affect the original.
        copy.insert(77, at: 5)
        _ = copy.remove(at: 0)
        #expect(original.isOccupied(at: 5) == false)
        #expect(original.isOccupied(at: 0) == true)
        #expect(original.occupancy == 2)

        // And mutations to the original do NOT affect the clone.
        original.insert(99, at: 6)
        #expect(copy.isOccupied(at: 6) == false)
    }

    @Test
    func `clone of an empty slab is empty`() {
        let original = Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Int>>.Slab(minimumCapacity: 4)
        let copy = original.clone()
        #expect(copy.isEmpty == true)
        #expect(copy.occupancy == .zero)
    }

    // MARK: - Teardown (single-free)

    @Test
    func `original and clone each free exactly once`() {
        // Two independent boxes (original + clone). Each box's bitmap-driven `deinit`
        // frees ONLY its own occupied slots — dropping both never double-frees.
        var original = Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Int>>.Slab(minimumCapacity: 4)
        original.insert(10, at: 0)
        original.insert(20, at: 2)
        do {
            let copy = original.clone()
            #expect(copy.occupancy == 2)
        }  // copy's box deinit frees its 2 slots once
        // The original is unaffected by the clone's teardown.
        #expect(original.occupancy == 2)
    }  // original's box deinit frees its 2 slots once

    // MARK: - Buffer.Slab.Bounded.clone()

    @Test
    func `Bounded clone preserves the occupied slots`() {
        var original = Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Int>>.Slab.Bounded(minimumCapacity: 8)
        original.insert(10, at: 0)
        original.insert(20, at: 3)

        let copy = original.clone()
        #expect(copy.occupancy == 2)
        #expect(copy.peek(at: 0) == 10)
        #expect(copy.peek(at: 3) == 20)
        #expect(original.occupancy == 2)
    }

    // MARK: - Bitmap Sync (move-only — assert directly on the mutated buffer)

    @Test
    func `bitmap stays synced after insert-remove cycle`() {
        var buffer = Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Int>>.Slab(minimumCapacity: 8)
        buffer.insert(10, at: 0)
        buffer.insert(20, at: 1)
        buffer.insert(30, at: 2)
        _ = buffer.remove(at: 1)

        #expect(buffer.occupancy == 2)
        #expect(buffer.isOccupied(at: 0) == true)
        #expect(buffer.isOccupied(at: 1) == false)
        #expect(buffer.isOccupied(at: 2) == true)
    }

    @Test
    func `bitmap stays synced after removeAll`() {
        var buffer = Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Int>>.Slab(minimumCapacity: 8)
        buffer.insert(10, at: 0)
        buffer.insert(20, at: 3)
        buffer.removeAll()

        #expect(buffer.isEmpty == true)
        #expect(buffer.occupancy == .zero)
    }

    @Test
    func `bitmap stays synced after drain`() {
        var buffer = Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Int>>.Slab(minimumCapacity: 8)
        buffer.insert(10, at: 0)
        buffer.insert(20, at: 3)
        buffer.drain { _ in }

        #expect(buffer.isEmpty == true)
    }

    @Test
    func `update preserves the new value`() {
        var buffer = Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Int>>.Slab(minimumCapacity: 8)
        buffer.insert(10, at: 0)
        _ = buffer.update(at: 0, with: 99)
        #expect(buffer[Bit.Index(Ordinal(0 as UInt))] == 99)
    }
}
