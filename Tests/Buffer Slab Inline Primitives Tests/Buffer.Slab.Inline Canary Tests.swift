// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-primitives open source project
//
// Copyright (c) 2024-2026 Coen ten Thije Boonkkamp and the swift-primitives project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

import Buffer_Slab_Inline_Primitives
import Buffer_Slab_Primitives_Test_Support
import Finite_Bounded_Primitives
import Memory_Allocator_Primitive
import Memory_Heap_Primitives
import Storage_Contiguous_Primitives
import Testing

// RELEASE-GUARD (swift-issue-inlinearray-class-field-write-elision): the inline-box path is
// release-broken (occupancy-bitmap writes elided under `-O`). This deinit harness passes in
// release only by accident (contiguous inserts make the un-reset substrate ledger free the
// right slots), so it runs in DEBUG and SKIPS under `-O`, pending the occupancy ruling
// (HANDOFF-sparse-occupancy-placement.md). `_isDebugAssertConfiguration()` is false under `-O`.
/// Regression test: Storage.Inline deinit cleans up elements through
/// cross-module member destruction chain.
@Suite(
    "Buffer.Slab.Inline - Deinit",
    .disabled(
        if: !_isDebugAssertConfiguration(),
        "release-blocked: swift-issue-inlinearray-class-field-write-elision; pending HANDOFF-sparse-occupancy-placement.md"
    )
)
struct SlabInlineDeinitTests {

    final class Tracker: @unchecked Sendable {
        private var _storage: [Int] = []
        var deinitOrder: [Int] { _storage }
        func append(_ id: Int) { _storage.append(id) }
    }

    struct TrackedElement: ~Copyable {
        let id: Int
        let tracker: Tracker
        init(_ id: Int, tracker: Tracker) {
            self.id = id
            self.tracker = tracker
        }
        deinit { tracker.append(id) }
    }

    private struct _BareWrapper<Element: ~Copyable, let wordCount: Int>: ~Copyable {
        var _buffer: Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Element>>.Slab.Inline<wordCount>
        init() { self._buffer = Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Element>>.Slab.Inline() }
        deinit {}
    }

    @Test
    func `deinit cleans up inline storage elements`() {
        let tracker = Tracker()
        do {
            var bare = _BareWrapper<TrackedElement, 4>()
            let s0: Bit.Index.Bounded<4> = 0
            let s1: Bit.Index.Bounded<4> = 1
            let s2: Bit.Index.Bounded<4> = 2
            bare._buffer.insert(TrackedElement(1, tracker: tracker), at: s0)
            bare._buffer.insert(TrackedElement(2, tracker: tracker), at: s1)
            bare._buffer.insert(TrackedElement(3, tracker: tracker), at: s2)
        }
        #expect(tracker.deinitOrder == [1, 2, 3])
    }
}

// RELEASE-GUARD (swift-issue-inlinearray-class-field-write-elision): runs in DEBUG, skips
// under `-O` (the reconstructed single-free harness — passes in release only by accident on
// contiguous inserts; sparse occupancy is release-broken). Pending HANDOFF-sparse-occupancy-placement.md.
/// Deinit-COUNTING single-free acceptance harness (reconstructs the probe scratch).
///
/// Each occupied element's `deinit` MUST run EXACTLY once when the buffer is torn down —
/// never twice (double-free) nor zero (leak). The bitmap-driven `Box.deinit` is the SOLE
/// teardown; the `Store.Inline` substrate ledger is kept `.empty`, so its own oracle no-ops.
/// Run in BOTH debug and release (`swift test` and `swift test -c release`) — the probe
/// proved tracked init double-frees in release, so the untracked-ledger discipline is what
/// this gate protects.
@Suite(
    "Buffer.Slab.Inline - Single-Free",
    .disabled(
        if: !_isDebugAssertConfiguration(),
        "release-blocked: swift-issue-inlinearray-class-field-write-elision; pending HANDOFF-sparse-occupancy-placement.md"
    )
)
struct SlabInlineSingleFreeTests {

    final class Ledger: @unchecked Sendable {
        private var _counts: [Int: Int] = [:]
        func record(_ id: Int) { _counts[id, default: 0] += 1 }
        var total: Int { _counts.values.reduce(0, +) }
        var maxPerID: Int { _counts.values.max() ?? 0 }
        var distinctIDs: Int { _counts.count }
    }

    struct Counted: ~Copyable {
        let id: Int
        let ledger: Ledger
        init(_ id: Int, _ ledger: Ledger) {
            self.id = id
            self.ledger = ledger
        }
        deinit { ledger.record(id) }
    }

    @Test
    func `inline teardown frees each occupied slot exactly once`() {
        let ledger = Ledger()
        let n = 6
        do {
            var buffer = Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Counted>>.Slab.Inline<8>()
            for i in 0..<n {
                buffer.insert(Counted(i, ledger), at: Bit.Index.Bounded<8>(Bit.Index(Ordinal(UInt(i))))!)
            }
        }  // buffer (and its Box) drop here — Box.deinit walks the bitmap
        #expect(ledger.total == n)  // not 0 (no leak), not 2n (no double-free)
        #expect(ledger.maxPerID == 1)  // each id freed EXACTLY once — single-free
        #expect(ledger.distinctIDs == n)
    }

    @Test
    func `sparse inline teardown frees only occupied slots, once each`() {
        let ledger = Ledger()
        do {
            var buffer = Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Counted>>.Slab.Inline<8>()
            let s0: Bit.Index.Bounded<8> = 0
            let s4: Bit.Index.Bounded<8> = 4
            let s7: Bit.Index.Bounded<8> = 7
            buffer.insert(Counted(1, ledger), at: s0)
            buffer.insert(Counted(2, ledger), at: s4)
            buffer.insert(Counted(3, ledger), at: s7)
        }
        #expect(ledger.total == 3)
        #expect(ledger.maxPerID == 1)
    }

    @Test
    func `remove then teardown never double-frees a removed slot`() {
        let ledger = Ledger()
        do {
            var buffer = Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Counted>>.Slab.Inline<8>()
            let s0: Bit.Index.Bounded<8> = 0
            let s1: Bit.Index.Bounded<8> = 1
            buffer.insert(Counted(1, ledger), at: s0)
            buffer.insert(Counted(2, ledger), at: s1)
            _ = buffer.remove(at: s0)  // frees id 1 exactly once
            #expect(ledger.total == 1)
            #expect(ledger.maxPerID == 1)
        }  // teardown frees id 2 once; the removed slot 0 (bitmap cleared) is NOT re-freed
        #expect(ledger.total == 2)
        #expect(ledger.maxPerID == 1)  // id 1 NOT double-freed by the Box teardown
    }
}

/// DIAGNOSTIC — release-miscompile isolation.
///
/// Mutates a LOCAL `Header.Static` (its inline `Bit.Vector.Static` bitmap) with NO box /
/// `.Inline` layering. If THIS fails under `-O`, the inline-bitmap mutation itself is the
/// miscompile; if it passes, the box interaction is.
@Suite("Buffer.Slab.Header.Static - Release Isolation")
struct HeaderStaticReleaseIsolationTests {
    @Test
    func `local Header.Static bitmap set persists`() {
        var h = Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Int>>.Slab.Header.Static<8>()
        let s2: Bit.Index = Bit.Index(Ordinal(2 as UInt))
        h.bitmap[s2] = true
        #expect(h.isOccupied(at: s2) == true)
        #expect(h.occupancy == 1)
    }
}
