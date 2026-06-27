import Affine_Primitives_Standard_Library_Integration
public import Bit_Vector_Bounded_Primitives
public import Growth_Primitives
import Ordinal_Primitives_Standard_Library_Integration
public import Storage_Protocol_Primitives
public import Store_Protocol_Primitives

// MARK: - Static Operations for ~Copyable Elements on the substrate
//
// The per-slot element transitions go through `Storage.Slab`'s north-star typed
// witnesses (`initialize(at:to:)` / `move(at:)` / `subscript`), which take exclusive
// `&self` — so the storage is threaded `inout S` (the buffer's own
// stored field, passed `&storage`), NOT borrowed through the read-only `.heap`
// accessor. The Slab witnesses delegate element access to the backing
// `Storage<Memory.Allocator<Memory.Heap>>.Contiguous<S.Element>` and ALSO flip the slab's internal occupancy bitmap
// (`_backing._bitmap`), which is the `deinit` teardown oracle.
//
// The buffer keeps its own `Header.bitmap` as the read-API occupancy truth (occupancy /
// firstVacant / iteration) and the caller (`Buffer.Slab+Operations`) syncs it down with
// `storage.bitmap = header.bitmap` after each op. That sync is now redundant with the
// witness's per-slot bit flip (both write the same value) but is retained — it remains
// correct and keeps the read-API truth and the slab oracle in lock-step. (Slab keeps
// `storage.initialization` at `.empty`; the bitmap is the source of truth.)

extension Buffer.Slab where S: ~Copyable {

    // MARK: Insert

    /// Initializes the element at the given slot and marks it occupied in the bitmap.
    ///
    /// - Precondition: The slot is not already occupied.
    @inlinable
    public static func insert(
        _ element: consuming S.Element,
        at slot: Bit.Index,
        header: inout Header,
        storage: inout S
    ) {
        storage.initialize(at: slot.retag(S.Element.self), to: consume element)
        header.bitmap[slot] = true
    }

    // MARK: Remove

    /// Moves the element out of the given slot and marks it vacant in the bitmap.
    ///
    /// - Precondition: The slot is occupied.
    @inlinable
    public static func remove(
        at slot: Bit.Index,
        header: inout Header,
        storage: inout S
    ) -> S.Element {
        let element = storage.move(at: slot.retag(S.Element.self))
        header.bitmap[slot] = false
        return element
    }

    // MARK: Update

    /// Replaces the element at the given slot and returns the old element.
    ///
    /// The bitmap is unchanged — the slot remains occupied.
    ///
    /// - Precondition: The slot is occupied.
    @inlinable
    public static func update(
        at slot: Bit.Index,
        with element: consuming S.Element,
        storage: inout S
    ) -> S.Element {
        let storageIndex = slot.retag(S.Element.self)
        let old = storage.move(at: storageIndex)
        storage.initialize(at: storageIndex, to: consume element)
        return old
    }

    // MARK: For Each Occupied

    /// Visits each occupied slot, passing the storage index of the element.
    @inlinable
    public static func forEachOccupied(
        header: borrowing Header,
        storage: borrowing S,
        _ body: (Index<S.Element>) -> Void
    ) {
        header.bitmap.ones.forEach { bitIndex in
            body(bitIndex.retag(S.Element.self))
        }
    }

    // MARK: First Vacant

    /// Returns the first vacant slot, or `nil` if all slots are full.
    @inlinable
    public static func firstVacant(
        header: borrowing Header
    ) -> Bit.Index? {
        header.firstVacant(max: header.bitmap.capacity.maximum)
    }

    // MARK: Deinitialize All

    /// Deinitializes all occupied slots using the bitmap as truth.
    @inlinable
    public static func deinitializeAll(
        header: inout Header,
        storage: inout S
    ) {
        header.bitmap.ones.forEach { bitIndex in
            // `move(at:)` returns the element; discarding the returned ~Copyable
            // value deinitializes it (mirrors `Storage.Protocol.deinitialize(at:)`
            // = `_ = move(at:)`) and clears the slab's occupancy bit. Uses the
            // façade's own public `move` rather than the protocol derivation to stay
            // `@inlinable`-visible without importing `Storage_Protocol_Primitives`.
            _ = storage.move(at: bitIndex.retag(S.Element.self))
            header.bitmap[bitIndex] = false
        }
    }
}
