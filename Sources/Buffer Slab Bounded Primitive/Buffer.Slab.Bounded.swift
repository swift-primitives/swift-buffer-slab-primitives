import Affine_Primitives_Standard_Library_Integration
public import Bit_Vector_Bounded_Primitives
import Index_Primitives
import Ordinal_Primitives_Standard_Library_Integration
public import Storage_Protocol_Primitives
public import Store_Protocol_Primitives

extension Buffer.Slab where S: ~Copyable {
    // MARK: - Bounded (Fixed-Capacity)

    /// A fixed-capacity slab buffer over a plain element-storage substrate.
    ///
    /// `Buffer<S>.Slab.Bounded` is the capacity-policy sibling of the growable
    /// ``Buffer/Slab`` — identical sparse-occupancy semantics over the SAME
    /// relocated cleanup oracle (the private reference `Box`), differing only in
    /// that it offers no growth path. The occupancy bitmap AND the teardown live
    /// in the box: the bitmap-driven cleanup requires a CLASS `deinit` (the
    /// bd04f32 evidence record), so the box is a CLASS boundary.
    ///
    /// ## Value semantics
    ///
    /// `Buffer.Slab.Bounded` is **move-only**. CoW (`ensureUnique`) is withdrawn
    /// at the storage tier (the element-free `Storage.Contiguous` is
    /// unconditionally `~Copyable` with an explicit `copy()`), so it no longer
    /// shares a box across copies and is exclusively owned. An independent deep
    /// copy is obtained explicitly via ``clone()``.
    public struct Bounded: ~Copyable {

        @usableFromInline
        internal var box: Box

        @inlinable
        package init(
            header: Header,
            storage: consuming S
        ) {
            self.box = Box(header: header, storage: storage)
        }
    }
}

extension Buffer.Slab.Bounded where S: ~Copyable {
    // MARK: - The relocated cleanup oracle

    @usableFromInline
    internal final class Box {
        @usableFromInline
        internal var header: Buffer.Slab.Header

        @usableFromInline
        internal var storage: S

        @usableFromInline
        internal init(header: Buffer.Slab.Header, storage: consuming S) {
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

extension Buffer.Slab.Bounded where S: ~Copyable {
    /// In-place view of the box's header (see ``Buffer/Slab/header``).
    @usableFromInline
    internal var header: Buffer.Slab.Header {
        @inlinable _read { yield box.header }
        @inlinable _modify { yield &box.header }
    }

    /// In-place view of the box's storage substrate (see ``Buffer/Slab/header``).
    @usableFromInline
    internal var storage: S {
        @inlinable _read { yield box.storage }
        @inlinable _modify { yield &box.storage }
    }
}

/// Sendable conformance for `Buffer.Slab.Bounded`.
///
/// ## Safety Invariant
///
/// `Buffer.Slab.Bounded` is `~Copyable` and owns its box exclusively.
/// Single ownership enforced; cross-thread transfer is a move.
///
/// ## Non-Goals
///
/// - Not a shared concurrent slab; external synchronization required.
extension Buffer.Slab.Bounded: @unsafe @unchecked Sendable where S: Sendable {}
