import Buffer_Slab_Primitives
import Buffer_Slab_Primitives_Test_Support
import Memory_Allocator_Primitive
import Memory_Heap_Primitives
import Memory_Small_Primitives
import Storage_Contiguous_Primitives
import Testing

// [DS-029] form-2 probe for the Bounded slab discipline (W3.1 buffer-slab leg) — the NAMED
// W3.1 probe. The Bounded construction / clone / array-init pins were generalized from a
// `Memory.Heap` hardcode to `Resource: Memory.Growable`, so a `Memory.Small<64>`-leaf bounded
// slab — `Buffer<Storage<Memory.Allocator<Memory.Small<64>>>.Contiguous<Int>>.Slab.Bounded` —
// is now expressible: construction + insert/remove + occupancy walk, plus array-init and clone.

@Suite("Buffer.Slab.Bounded — DS-029 Small-column probe")
struct SlabBoundedSmallColumnProbeTests {

    typealias SmallColumn = Storage<Memory.Allocator<Memory.Small<64>>>.Contiguous<Int>

    @Test
    func `construct, insert, remove, and occupancy-walk a Memory.Small<64> bounded column`() {
        // #5 — Buffer.Slab.Bounded.init(minimumCapacity:), generalized over Resource: Memory.Growable.
        var buffer = Buffer<SmallColumn>.Slab.Bounded(minimumCapacity: 8)
        buffer.insert(10, at: 0)
        buffer.insert(20, at: 2)
        buffer.insert(30, at: 5)

        #expect(buffer.occupancy == 3)

        // Occupancy walk over the fixed capacity via `isOccupied`.
        var occupied = 0
        for raw in 0..<8 where buffer.isOccupied(at: Bit.Index(Ordinal(UInt(raw)))) {
            occupied += 1
        }
        #expect(occupied == 3)
        #expect(buffer.isOccupied(at: 0) == true)
        #expect(buffer.isOccupied(at: 1) == false)

        #expect(buffer.remove(at: 2) == 20)
        #expect(buffer.occupancy == 2)
        #expect(buffer.isOccupied(at: 2) == false)
    }

    @Test
    func `array-init then clone a Memory.Small<64> bounded column`() throws {
        // #7 — Buffer.Slab.Bounded.init(_:capacity:), generalized over Resource: Memory.Growable.
        var buffer = try Buffer<SmallColumn>.Slab.Bounded([10, 20, 30], capacity: 8)
        #expect(buffer.occupancy == 3)
        #expect(buffer.peek(at: 0) == 10)
        #expect(buffer.peek(at: 1) == 20)
        #expect(buffer.peek(at: 2) == 30)

        // #6 — Buffer.Slab.Bounded.clone(), generalized over Resource: Memory.Growable.
        let copy = buffer.clone()
        #expect(copy.occupancy == 3)
        #expect(copy.peek(at: 0) == 10)

        // Independence: mutating the original leaves the clone untouched.
        _ = buffer.remove(at: 0)
        #expect(buffer.occupancy == 2)
        #expect(copy.occupancy == 3)
    }
}
