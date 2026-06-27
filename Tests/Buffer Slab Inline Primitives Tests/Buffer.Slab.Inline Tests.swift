import Buffer_Slab_Inline_Primitives
import Buffer_Slab_Primitives_Test_Support
import Finite_Bounded_Primitives
import Memory_Allocator_Primitive
import Memory_Heap_Primitives
import Storage_Contiguous_Primitives
import Testing

// RELEASE-GUARD — swift-institute/Issues/swift-issue-inlinearray-class-field-write-elision:
// the InlineArray-backed occupancy bitmap, stored in the class `Box` field, has its writes
// elided under `-O`, so `.Inline` sparse occupancy is wrong in release. These functional tests
// run in DEBUG (proving the logic is correct) and SKIP under `-O` (documented), pending the
// occupancy-placement ruling (~/Developer/.handoffs/HANDOFF-sparse-occupancy-placement.md).
// (`_isDebugAssertConfiguration()` is true under `-Onone`/debug, false under `-O`/release.)
@Suite(
    "Buffer.Slab.Inline",
    .disabled(
        if: !_isDebugAssertConfiguration(),
        "release-blocked: swift-issue-inlinearray-class-field-write-elision; .Inline release-broken pending HANDOFF-sparse-occupancy-placement.md"
    )
)
struct SlabBoundedInlineTests {

    @Test
    func `insert and remove at specific slots`() throws {
        var buffer = Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Int>>.Slab.Inline<4>()
        let slot: Bit.Index.Bounded<4> = 2
        buffer.insert(42, at: slot)
        #expect(buffer.isOccupied(at: slot) == true)
        #expect(buffer.occupancy == 1)

        let value = buffer.remove(at: slot)
        #expect(value == 42)
        #expect(!buffer.isOccupied(at: slot) == true)
        #expect(buffer.isEmpty == true)
    }

    @Test
    func `sparse occupancy — non-contiguous slots`() throws {
        var buffer = Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Int>>.Slab.Inline<4>()
        let s0: Bit.Index.Bounded<4> = 0
        let s2: Bit.Index.Bounded<4> = 2
        let s3: Bit.Index.Bounded<4> = 3
        buffer.insert(10, at: s0)
        buffer.insert(20, at: s2)
        buffer.insert(30, at: s3)

        #expect(buffer.occupancy == 3)
        #expect(buffer.isOccupied(at: s0) == true)
        #expect(!buffer.isOccupied(at: 1) == true)
        #expect(buffer.isOccupied(at: s2) == true)
        #expect(buffer.isOccupied(at: s3) == true)
    }

    @Test
    func `slot reuse after removal`() throws {
        var buffer = Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Int>>.Slab.Inline<4>()
        let slot: Bit.Index.Bounded<4> = 1
        buffer.insert(10, at: slot)
        _ = buffer.remove(at: slot)
        buffer.insert(20, at: slot)
        #expect(buffer.remove(at: slot) == 20)
    }

    @Test
    func `firstVacant finds available slot`() throws {
        var buffer = Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Int>>.Slab.Inline<4>()
        let s0: Bit.Index.Bounded<4> = 0
        let s1: Bit.Index.Bounded<4> = 1
        buffer.insert(10, at: s0)
        buffer.insert(20, at: s1)

        let vacant = buffer.firstVacant()
        #expect(vacant == 2)
    }

    @Test
    func `firstVacant returns nil when full`() throws {
        var buffer = Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Int>>.Slab.Inline<4>()
        let s0: Bit.Index.Bounded<4> = 0
        let s1: Bit.Index.Bounded<4> = 1
        let s2: Bit.Index.Bounded<4> = 2
        let s3: Bit.Index.Bounded<4> = 3
        buffer.insert(10, at: s0)
        buffer.insert(20, at: s1)
        buffer.insert(30, at: s2)
        buffer.insert(40, at: s3)
        #expect(buffer.isFull == true)

        let vacant = buffer.firstVacant()
        #expect(vacant == nil)
    }

    @Test
    func `drain removes all elements`() throws {
        var buffer = try Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Int>>.Slab.Inline<8>([10, 20, 30])
        var drained: [Int] = []
        buffer.drain { drained.append($0) }
        #expect(buffer.isEmpty == true)
        #expect(drained.sorted() == [10, 20, 30])
    }

    @Test
    func `removeAll clears buffer`() throws {
        var buffer = try Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Int>>.Slab.Inline<8>([1, 2, 3])
        buffer.removeAll()
        #expect(buffer.isEmpty == true)
        #expect(buffer.occupancy == 0)
    }

    @Test
    func `peek reads without removing (Copyable)`() throws {
        var buffer = Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Int>>.Slab.Inline<8>()
        let slot: Bit.Index.Bounded<8> = 3
        buffer.insert(42, at: slot)
        #expect(buffer.peek(at: slot) == 42)
        #expect(buffer.isOccupied(at: slot) == true)
    }

    @Test
    func `Sequence.Protocol iteration (Copyable)`() throws {
        let buffer = try Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Int>>.Slab.Inline<8>([10, 20, 30])
        var collected: [Int] = []
        var iter: Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Int>>.Slab.Inline<8>.Iterator = buffer.makeIterator()
        while let value = iter.next() {
            collected.append(value)
        }
        #expect(collected == [10, 20, 30])
    }
}
