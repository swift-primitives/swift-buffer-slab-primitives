import Affine_Primitives_Standard_Library_Integration
public import Bit_Vector_Bounded_Primitives
import Index_Primitives
public import Memory_Allocator_Primitive
public import Memory_Heap_Primitives
import Ordinal_Primitives_Standard_Library_Integration
public import Storage_Contiguous_Primitives
public import Store_Protocol_Primitives

// MARK: - Copyable-element features for Buffer.Slab.Bounded
//
// CoW (`ensureUnique`) is withdrawn at the storage tier: `Storage.Contiguous` is
// unconditionally `~Copyable` with an explicit `copy()`, so `Buffer.Slab.Bounded`
// is move-only and the former CoW-safe shadows are removed. What remains here is
// genuinely Copyable-only and CoW-free: peek-by-value, array initialization, and
// the explicit `clone()` deep copy.

extension Buffer.Slab.Bounded where S: ~Copyable, S.Element: Copyable {

    /// Reads the element at the given slot without removing it.
    ///
    /// - Precondition: The slot is occupied.
    @inlinable
    public func peek(at slot: Bit.Index) -> S.Element {
        let storageIndex = slot.retag(S.Element.self)
        return storage[storageIndex]
    }
}

// MARK: - Explicit deep copy (the heap column)

extension Buffer.Slab.Bounded where S: ~Copyable {

    /// Returns an independent copy of this bounded slab with its own box and
    /// storage, preserving the fixed capacity.
    ///
    /// Occupancy-aware: only the `header.bitmap.ones` slots are copied; vacant
    /// slots are skipped.
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

// MARK: - Array Initialization

extension Buffer.Slab.Bounded where S: ~Copyable {

    /// Creates a bounded slab buffer populated with the given elements.
    ///
    /// Elements are inserted at sequential slot indices starting from zero.
    /// The common-tower instantiation (`S == Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>`).
    ///
    /// - Parameters:
    ///   - elements: The elements to populate the buffer with.
    ///   - capacity: The fixed capacity for the buffer.
    /// - Throws: ``Error/capacityExceeded`` if `elements.count` exceeds `capacity`.
    @inlinable
    public init<E>(_ elements: [E], capacity: UInt) throws(Self.Error) where S == Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E> {
        guard elements.count <= Int(capacity) else { throw .capacityExceeded }
        var buffer = Self(minimumCapacity: Index<E>.Count(Cardinal(capacity)))
        for (i, element) in elements.enumerated() {
            buffer.insert(element, at: Bit.Index(Ordinal(UInt(i))))
        }
        self = buffer
    }
}
