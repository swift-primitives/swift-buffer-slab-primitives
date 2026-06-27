import Affine_Primitives_Standard_Library_Integration
public import Bit_Vector_Bounded_Primitives
import Index_Primitives
public import Memory_Allocator_Primitive
public import Memory_Heap_Primitives
import Ordinal_Primitives_Standard_Library_Integration
public import Storage_Contiguous_Primitives

// MARK: - Explicit deep copy (the heap column)
//
// CoW (`ensureUnique`) is withdrawn at the storage tier: the element-free
// `Storage.Contiguous` is unconditionally `~Copyable` with an explicit `copy()`,
// so `Buffer.Slab` is move-only and never shares a box across copies. The former
// occupancy-aware CoW choke is replaced by this explicit `clone()` — a fresh,
// independent deep copy. Unlike a dense buffer, the slab copies ONLY the occupied
// slots (the bitmap is the source of truth; unoccupied slots hold no live element
// to copy). Heap-pinned (the common tower) because building a fresh substrate
// requires the concrete `Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>.create`
// allocation seam.

extension Buffer.Slab where S: ~Copyable {

    /// Returns an independent copy of this slab with its own box and storage.
    ///
    /// Unlike a CoW value-semantic copy, which may share storage until mutation,
    /// `clone()` always allocates new storage. The copy is occupancy-aware: only
    /// the `header.bitmap.ones` slots are copied (subscript-read →
    /// `initialize(at:to:)`); vacant slots are skipped.
    ///
    /// - Complexity: O(`occupancy`)
    @inlinable
    public func clone<E>() -> Self where S == Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>, E: Copyable {
        let capacity = storage.capacity
        var fresh = Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>.create(minimumCapacity: capacity)
        header.bitmap.ones.forEach { bitIndex in
            let index = bitIndex.retag(E.self)
            let element = storage[index]
            fresh.initialize(at: index, to: element)
        }
        return Self(header: header, storage: fresh)
    }
}
