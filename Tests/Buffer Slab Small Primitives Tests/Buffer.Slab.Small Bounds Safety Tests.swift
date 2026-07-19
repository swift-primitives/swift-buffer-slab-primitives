import Buffer_Slab_Primitives_Test_Support
import Buffer_Slab_Small_Primitives
import Memory_Allocator_Primitive
import Memory_Heap_Primitives
import Storage_Contiguous_Primitives
import Testing

// Regression coverage for fable-448 F-002 (correctness-high): `Buffer.Slab.Small.insert`
// spilled to heap on occupancy alone (`!buf.isFull`), so a sparse `insert(at:)` whose `slot`
// was >= `inlineCapacity` bypassed the spill entirely and reached the fixed inline store's
// unbounded, unchecked `Inline.insert(at: Bit.Index)` — an out-of-bounds write into a
// fixed-size 4-element inline store. `remove`/`update`/`peek` had the identical gap (no bounds
// check at all in `.inline` mode, unlike `isOccupied` which trapped). The fix: `insert` now
// also spills when `slot` does not fit `Bit.Index.Bounded<inlineCapacity>`, sized to
// `max(slot + 1, inlineCapacity * 2)`; `remove`/`update`/`peek` now range-check (and trap, since
// such a slot was never occupiable in inline mode — a genuine caller-contract violation, not a
// recoverable case); `isOccupied` now reads such a slot as vacant (`false`) instead of trapping,
// matching `firstVacant()`'s own range.
//
// This suite exercises the actual out-of-bounds write on the PRE-FIX source (deliberately, to
// capture real red/green evidence), so every test is an exit test: the risky call runs in a
// forked child process, isolating any resulting memory corruption (crash, or a silent bad
// write caught by this suite's own `precondition`) from the parent test process. Kept debug-only
// implicitly by the harness — these are logic bugs, not the F-001 release-mode DSE, so they are
// NOT release-guarded and run in both configurations.
@Suite
struct `Buffer.Slab.Small - Bounds Safety` {

    @Test
    func `insert at slot equal to inlineCapacity with vacancies forces a spill instead of an out-of-bounds write`() async {
        if _isDebugAssertConfiguration() {
            await #expect(processExitsWith: .success) {
                var buffer = Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Int>>.Slab.Small<4>()
                buffer.insert(10, at: 0)  // one occupied slot — far from "full" by occupancy count
                buffer.insert(99, at: 4)  // slot == inlineCapacity: outside the inline range
                precondition(buffer.isSpilled, "slot >= inlineCapacity must force a heap spill")
                precondition(buffer.occupancy == 2, "both elements must survive the spill")
                precondition(buffer.peek(at: 0) == 10, "the pre-spill element must survive the move")
                precondition(buffer.peek(at: 4) == 99, "the out-of-range insert must land at its own slot on heap")
            }
        } else {
            // Release: fable-448 F-001's guard already traps on the FIRST in-range inline
            // insert (slot 0), before F-002's own out-of-range check is ever reached — F-001
            // excludes ALL `.Inline`/`.Small` inline-arm mutation from release wholesale, which
            // correctly (if bluntly) subsumes this scenario too. F-002's own protection is only
            // independently observable in debug; see the isOccupied/remove/update cases below,
            // which never touch the F-001-guarded path and so behave identically in both
            // configurations.
            await #expect(processExitsWith: .failure) {
                var buffer = Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Int>>.Slab.Small<4>()
                buffer.insert(10, at: 0)
            }
        }
    }

    @Test
    func `insert at slot equal to 2 times inlineCapacity sizes the heap spill to cover it`() async {
        await #expect(processExitsWith: .success) {
            var buffer = Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Int>>.Slab.Small<4>()
            // slot 8 == 2 * inlineCapacity: doubling alone (capacity 8, valid indices [0,8))
            // would NOT cover index 8 — the fix's `max(slot + 1, inlineCapacity * 2)` must win.
            buffer.insert(7, at: 8)
            precondition(buffer.isSpilled, "must spill")
            precondition(buffer.isOccupied(at: 8), "the far slot must be reachable post-spill")
            precondition(buffer.peek(at: 8) == 7, "the far slot's value must be intact")
        }
    }

    @Test
    func `isOccupied at an out-of-inline-range slot reads vacant instead of trapping`() async {
        await #expect(processExitsWith: .success) {
            let buffer = Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Int>>.Slab.Small<4>()
            // Symmetric with firstVacant(), which never yields a slot >= inlineCapacity either.
            precondition(buffer.isOccupied(at: 4) == false, "slot 4 was never occupiable inline — must read vacant, not trap")
            precondition(buffer.isOccupied(at: 100) == false, "same for a slot far past capacity")
        }
    }

    @Test
    func `remove and update at an out-of-inline-range slot trap instead of reading out of bounds`() async {
        await #expect(processExitsWith: .failure) {
            var buffer = Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Int>>.Slab.Small<4>()
            _ = buffer.remove(at: 4)  // never occupiable in inline mode — must trap, not OOB-read
        }
        await #expect(processExitsWith: .failure) {
            var buffer = Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Int>>.Slab.Small<4>()
            _ = buffer.update(at: 4, with: 1)
        }
    }
}
