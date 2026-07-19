import Buffer_Slab_Inline_Primitives
import Buffer_Slab_Primitives_Test_Support
import Finite_Bounded_Primitives
import Memory_Allocator_Primitive
import Memory_Heap_Primitives
import Storage_Contiguous_Primitives
import Testing

// Regression coverage for fable-448 F-001 (release-risk, blocker): `Buffer.Slab.Inline`'s
// box-owned occupancy bitmap write is elided under `-O`
// (swift-issue-inlinearray-class-field-write-elision), silently corrupting sparse occupancy —
// re-verified against the pinned toolchain via `PROBE-occupancy-placement-leaf-vs-box.swift`.
// Pending the deferred occupancy-placement decision (leaf vs box; see the type doc-comment on
// `Buffer.Slab.Inline` and `.handoffs/HANDOFF-sparse-occupancy-placement.md`), every `Box`
// mutation now `precondition`s on `_isDebugAssertConfiguration()` so release (`-O`) callers
// trap loudly at the point of mutation instead of silently losing data.
//
// This suite is NOT release-guarded (unlike the functional suites in `Buffer.Slab.Inline
// Tests.swift` / `Buffer.Slab.Inline Canary Tests.swift`, which still skip under `-O` — they
// exercise the currently-inert release-mode value contract, not the guard itself): it runs in
// BOTH configurations and asserts configuration-appropriate behavior in each — debug: `insert`
// still works and updates occupancy normally (the guard never fires); release: `insert` traps
// (verified with an exit test), which is the actual fix under test. If a future change removes
// this precondition without replacing it, the release branch below goes red immediately.
@Suite
struct `Buffer.Slab.Inline - Release Safety` {

    @Test
    func `insert on the documented triggering shape traps under release and succeeds under debug`() async {
        if _isDebugAssertConfiguration() {
            var buffer = Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Int>>.Slab.Inline<4>()
            let slot: Bit.Index.Bounded<4> = 2
            buffer.insert(42, at: slot)
            #expect(buffer.occupancy == 1)
            #expect(buffer.isOccupied(at: slot) == true)
        } else {
            await #expect(processExitsWith: .failure) {
                var buffer = Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Int>>.Slab.Inline<4>()
                let slot: Bit.Index.Bounded<4> = 2
                buffer.insert(42, at: slot)
            }
        }
    }

    @Test
    func `remove traps under release and succeeds under debug`() async {
        if _isDebugAssertConfiguration() {
            var buffer = Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Int>>.Slab.Inline<4>()
            let slot: Bit.Index.Bounded<4> = 1
            buffer.insert(10, at: slot)
            #expect(buffer.remove(at: slot) == 10)
        } else {
            await #expect(processExitsWith: .failure) {
                var buffer = Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Int>>.Slab.Inline<4>()
                let slot: Bit.Index.Bounded<4> = 1
                _ = buffer.remove(at: slot)
            }
        }
    }

    @Test
    func `empty-buffer construction and read-only queries remain usable under release`() {
        // Construction and reads are NOT guarded (only Box mutations are) — an empty inline
        // buffer built in a release binary stays inert/inspectable; only touching an occupied
        // slot's bitmap bit is unsound and therefore blocked.
        let buffer = Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Int>>.Slab.Inline<4>()
        #expect(buffer.isEmpty == true)
        #expect(buffer.occupancy == .zero)
        #expect(buffer.isOccupied(at: 0) == false)
    }
}
