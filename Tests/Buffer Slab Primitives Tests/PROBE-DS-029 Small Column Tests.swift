import Buffer_Slab_Primitives
import Buffer_Slab_Primitives_Test_Support
import Memory_Allocator_Primitive
import Memory_Heap_Primitives
import Memory_Small_Primitives
import Storage_Contiguous_Primitives
import Testing

// [DS-029] form-2 (allocation-generic pin) probe for the buffer-slab discipline (W3.1 leg).
//
// The construction/clone pins were generalized from a `Memory.Heap` hardcode to
// `Resource: Memory.Growable`, so a `Memory.Small<n>`-leaf slab over the standard
// `Storage.Contiguous` column is now EXPRESSIBLE and constructible — distinct from the hand
// `Buffer.Slab.Small` inline⊕heap-spill type. `Memory.Inline` stays fenced out (it does not
// conform `Memory.Growable`). Column under test: `Memory.Small<64>` (64-byte inline budget = 8
// `Int` slots).

@Suite
struct `Buffer.Slab — DS-029 Small-column probe` {

    typealias SmallColumn = Storage<Memory.Allocator<Memory.Small<64>>>.Contiguous<Int>

    @Test
    func `construct, insert, remove, and occupancy-walk a Memory.Small<64> column`() {
        // #1 — Buffer.Slab.init(minimumCapacity:), generalized over Resource: Memory.Growable.
        var buffer = Buffer<SmallColumn>.Slab(minimumCapacity: 8)
        buffer.insert(10, at: 0)
        buffer.insert(20, at: 2)
        buffer.insert(30, at: 5)

        #expect(buffer.occupancy == 3)

        // Occupancy walk via the bitmap-level `occupiedSlots` iterator.
        var seen: [Bit.Index] = []
        buffer.occupiedSlots.forEach { seen.append($0) }
        #expect(seen.count == 3)
        #expect(buffer.isOccupied(at: 0) == true)
        #expect(buffer.isOccupied(at: 1) == false)
        #expect(buffer.isOccupied(at: 2) == true)
        #expect(buffer.isOccupied(at: 5) == true)

        #expect(buffer.remove(at: 2) == 20)
        #expect(buffer.occupancy == 2)
        #expect(buffer.isOccupied(at: 2) == false)
    }

    @Test
    func `clone a Memory.Small<64> column`() {
        // #2 — Buffer.Slab.clone(), generalized over Resource: Memory.Growable.
        var original = Buffer<SmallColumn>.Slab(minimumCapacity: 8)
        original.insert(10, at: 0)
        original.insert(20, at: 3)

        var copy = original.clone()
        #expect(copy.occupancy == 2)
        #expect(copy[Bit.Index(Ordinal(0 as UInt))] == 10)
        #expect(copy[Bit.Index(Ordinal(3 as UInt))] == 20)

        // Deep, independent copy: mutating the clone leaves the original untouched.
        copy.insert(99, at: 6)
        #expect(original.isOccupied(at: 6) == false)
        #expect(original.occupancy == 2)
    }
}
