import Bit_Vector_Bounded_Primitives
import Buffer_Slab_Primitives
import Buffer_Slab_Primitives_Test_Support
import Memory_Allocator_Primitive
import Memory_Heap_Primitives
import Storage_Contiguous_Primitives
import Testing

@Suite
struct `Buffer.Slab Static Operations` {

    @Test
    func `insert and remove`() {
        var header: Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Int>>.Slab.Header = .init(capacity: 8)
        var storage = Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Int>.create(minimumCapacity: 8)

        let slot: Bit.Index = 3
        Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Int>>.Slab.insert(42, at: slot, header: &header, storage: &storage)

        #expect(header.isOccupied(at: slot) == true)
        #expect(header.occupancy == 1)

        let value = Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Int>>.Slab.remove(at: slot, header: &header, storage: &storage)
        #expect(value == 42)
        #expect(!header.isOccupied(at: slot) == true)
        #expect(header.isEmpty == true)
    }

    @Test
    func `forEachOccupied visits all occupied slots`() {
        var header: Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Int>>.Slab.Header = .init(capacity: 8)
        var storage = Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Int>.create(minimumCapacity: 8)

        Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Int>>.Slab.insert(10, at: 1, header: &header, storage: &storage)
        Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Int>>.Slab.insert(30, at: 5, header: &header, storage: &storage)

        var visited: [UInt] = []
        Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Int>>.Slab.forEachOccupied(header: header, storage: storage) { storageIndex in
            visited.append(storageIndex.underlying.rawValue)
        }

        #expect(visited.sorted() == [1, 5])

        Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Int>>.Slab.deinitializeAll(header: &header, storage: &storage)
    }

    @Test
    func `firstVacant finds first empty slot`() {
        var header: Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Int>>.Slab.Header = .init(capacity: 4)
        header.bitmap[0] = true
        header.bitmap[1] = true

        let vacant = Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Int>>.Slab.firstVacant(header: header)
        #expect(vacant == 2)
    }

    @Test
    func `deinitializeAll clears all occupied slots`() {
        var header: Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Int>>.Slab.Header = .init(capacity: 8)
        var storage = Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Int>.create(minimumCapacity: 8)

        Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Int>>.Slab.insert(10, at: 0, header: &header, storage: &storage)
        Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Int>>.Slab.insert(20, at: 3, header: &header, storage: &storage)
        Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Int>>.Slab.insert(30, at: 7, header: &header, storage: &storage)

        Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Int>>.Slab.deinitializeAll(header: &header, storage: &storage)

        #expect(header.isEmpty == true)
        #expect(header.occupancy == 0)
    }
}
