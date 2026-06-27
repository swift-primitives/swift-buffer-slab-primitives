import Bit_Vector_Bounded_Primitives
import Buffer_Slab_Primitives
import Buffer_Slab_Primitives_Test_Support
import Memory_Allocator_Primitive
import Memory_Heap_Primitives
import Storage_Contiguous_Primitives
import Testing

@Suite("Buffer.Slab.Header")
struct SlabHeaderTests {

    @Test
    func `init creates empty bitmap`() {
        let header: Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Int>>.Slab.Header = .init(capacity: 8)
        #expect(header.isEmpty == true)
        #expect(!header.isFull == true)
        #expect(header.occupancy == 0)
    }

    @Test
    func `isOccupied tracks bitmap state`() {
        var header: Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Int>>.Slab.Header = .init(capacity: 8)
        let slot: Bit.Index = 3
        #expect(!header.isOccupied(at: slot) == true)

        header.bitmap[slot] = true
        #expect(header.isOccupied(at: slot) == true)
    }

    @Test
    func `occupancy reflects popcount`() {
        var header: Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Int>>.Slab.Header = .init(capacity: 8)
        header.bitmap[0] = true
        header.bitmap[3] = true
        header.bitmap[7] = true
        #expect(header.occupancy == 3)
    }

    @Test
    func `firstVacant scans for empty slot`() {
        var header: Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Int>>.Slab.Header = .init(capacity: 4)
        header.bitmap[0] = true
        header.bitmap[1] = true
        let vacant = header.firstVacant(max: header.bitmap.capacity.maximum)
        #expect(vacant == 2)
    }

    @Test
    func `firstVacant returns nil when full`() {
        var header: Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Int>>.Slab.Header = .init(capacity: 4)
        header.bitmap[0] = true
        header.bitmap[1] = true
        header.bitmap[2] = true
        header.bitmap[3] = true
        let vacant = header.firstVacant(max: header.bitmap.capacity.maximum)
        #expect(vacant == nil)
    }
}
