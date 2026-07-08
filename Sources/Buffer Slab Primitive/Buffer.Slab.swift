import Affine_Primitives_Standard_Library_Integration
public import Bit_Vector_Bounded_Primitives
import Index_Primitives
import Ordinal_Primitives_Standard_Library_Integration
public import Storage_Protocol_Primitives
public import Store_Protocol_Primitives

extension Buffer where S: Store.`Protocol`, S: ~Copyable {

    // MARK: - Slab

    /// A sparse-occupancy slab buffer over a plain element-storage substrate.
    ///
    /// `Buffer<S>.Slab` is the sparse sibling of Ring and Linear. The
    /// occupancy bitmap AND the cleanup oracle live HERE, in a private
    /// reference `Box` — bitmap-as-truth is the Buffer tier's one concern,
    /// and the bd04f32 evidence record proves the bitmap-driven teardown
    /// requires a CLASS `deinit`. The substrate `S` is plain element storage
    /// (`Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Entity>>.Slab` is the common tower) reached
    /// through the element-store seam.
    ///
    /// ## Value semantics
    ///
    /// `Buffer.Slab` is **move-only**. CoW (`ensureUnique`) is withdrawn at the
    /// storage tier: the element-free `Storage.Contiguous` is unconditionally
    /// `~Copyable` with an explicit `copy()`, so the slab no longer shares a box
    /// across copies and is exclusively owned. An independent deep copy is
    /// obtained explicitly via ``clone()`` (occupancy-aware: only occupied slots
    /// are copied).
    ///
    /// ## Teardown
    ///
    /// The `Box` is retained (it is the bitmap-driven deinit teardown oracle,
    /// independent of CoW): `Box.deinit` walks `header.bitmap.ones` and moves
    /// each occupied slot out of the substrate — the substrate's own
    /// tracked-range cleanup never sees these untracked initializations.
    public struct Slab: ~Copyable {

        @usableFromInline
        internal var box: Box

        @inlinable
        package init(header: Header, storage: consuming S) {
            self.box = Box(header: header, storage: storage)
        }
    }
}

extension Buffer.Slab where S: ~Copyable {
    // MARK: - The relocated cleanup oracle

    @usableFromInline
    internal final class Box {
        @usableFromInline
        internal var header: Header

        @usableFromInline
        internal var storage: S

        @usableFromInline
        internal init(header: Header, storage: consuming S) {
            self.header = header
            self.storage = storage
        }

        deinit {
            header.bitmap.ones.forEach { bitIndex in
                _ = storage.move(at: bitIndex.retag(S.Element.self))
            }
        }
    }
}

extension Buffer.Slab where S: ~Copyable {
    /// In-place view of the box's header.
    ///
    /// Reads and mutations route through the reference; the satellite operations
    /// modules reach occupancy state through this forwarder (which keeps the
    /// per-slot inout threading the static ops expect).
    @usableFromInline
    internal var header: Header {
        @inlinable _read { yield box.header }
        @inlinable _modify { yield &box.header }
    }

    /// In-place view of the box's storage substrate.
    ///
    /// See ``header``.
    @usableFromInline
    internal var storage: S {
        @inlinable _read { yield box.storage }
        @inlinable _modify { yield &box.storage }
    }
}

// MARK: - Conditional Conformances (Slab)

/// Sendable conformance for `Buffer.Slab`.
///
/// ## Safety Invariant
///
/// `Buffer.Slab` is `~Copyable` and owns its box exclusively. Single
/// ownership enforced; cross-thread transfer is a move.
///
/// ## Non-Goals
///
/// - Not a shared concurrent slab; external synchronization required.
extension Buffer.Slab: @unsafe @unchecked Sendable where S: Sendable {}
