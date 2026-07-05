import Affine_Primitives_Standard_Library_Integration
public import Bit_Vector_Bounded_Primitives
public import Memory_Allocator_Primitive
import Ordinal_Primitives_Standard_Library_Integration
public import Sequence_Primitives
public import Storage_Contiguous_Primitives

// MARK: - Extensions for Slab (declared in Core)

extension Buffer.Slab where S: ~Copyable {
    /// Creates a growable heap-backed slab buffer with at least the given capacity.
    ///
    /// The common-tower instantiation (`S == Storage<Memory.Allocator<Memory.Heap>>.Contiguous<S.Element>`); other
    /// substrates construct their storage and use `init(header:storage:)`-style
    /// wiring through their own factories.
    @inlinable
    public init<E: ~Copyable>(minimumCapacity: Index<E>.Count) where S == Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E> {
        let storage = Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>.create(minimumCapacity: minimumCapacity)
        self.init(
            header: Self.Header(capacity: storage.capacity.retag(Bit.self)),
            storage: storage
        )
    }
}

extension Buffer.Slab where S: ~Copyable {

    /// The number of occupied slots.
    @inlinable
    public var occupancy: Bit.Index.Count { header.occupancy }

    /// The number of elements logically held by the buffer, in the element domain.
    ///
    /// A slab's native ledger counts occupied bitmap slots (``occupancy``, a
    /// `Bit.Index.Count`). M7 re-tags that into the concrete element domain at this
    /// ``Buffer/`Protocol``` `count` witness — one occupied slot IS one live element,
    /// a numerically-sound phantom-label change (`.retag(Element.self)`).
    @inlinable
    public var count: Index<Element>.Count { occupancy.retag(Element.self) }

    /// Whether no slots are occupied.
    @inlinable
    public var isEmpty: Bool { header.isEmpty }

    /// Whether all slots are occupied.
    @inlinable
    public var isFull: Bool { header.isFull }

    /// Whether a specific slot is occupied.
    @inlinable
    public func isOccupied(at slot: Bit.Index) -> Bool {
        header.isOccupied(at: slot)
    }

    /// The occupied slot indices, as a bitmap-level iterator.
    ///
    /// - Complexity: O(count) total via Wegner/Kernighan bit extraction,
    ///   not O(capacity) linear scan.
    @inlinable
    public var occupiedSlots: Bit.Vector.Ones.Bounded {
        header.bitmap.ones
    }

    // MARK: - Mutations

    /// Inserts an element at the given slot.
    ///
    /// - Precondition: The slot is not occupied.
    @inlinable
    public mutating func insert(_ element: consuming S.Element, at slot: Bit.Index) {
        // Reach the box's two distinct stored fields directly: passing `&header`
        // and `&storage` (both `box`-backed forwarders) in one call overlaps the
        // single `self`/`box` access. The class's stored properties are separately
        // exclusive, so `&box.header, &box.storage` is legal.
        Self.insert(consume element, at: slot, header: &box.header, storage: &box.storage)
    }

    /// Removes and returns the element at the given slot.
    ///
    /// - Precondition: The slot is occupied.
    @inlinable
    public mutating func remove(at slot: Bit.Index) -> S.Element {
        Self.remove(at: slot, header: &box.header, storage: &box.storage)
    }

    /// Replaces the element at the given slot and returns the old element.
    ///
    /// - Precondition: The slot is occupied.
    @inlinable
    public mutating func update(at slot: Bit.Index, with element: consuming S.Element) -> S.Element {
        Self.update(at: slot, with: consume element, storage: &box.storage)
    }

    /// Returns the first vacant slot, or `nil` if all slots are full.
    @inlinable
    public func firstVacant() -> Bit.Index? {
        Self.firstVacant(header: header)
    }

    /// Removes all elements from the buffer.
    @inlinable
    public mutating func removeAll() {
        Self.deinitializeAll(header: &box.header, storage: &box.storage)
    }
}

// MARK: - Sequence.Drain.Protocol

extension Buffer.Slab: Sequence.Drain.`Protocol` where S: ~Copyable {
    /// Removes every occupied element, consuming each through `body`.
    @inlinable
    public mutating func drain(_ body: (consuming S.Element) -> Void) {
        box.header.bitmap.ones.forEach { bitIndex in
            body(Self.remove(at: bitIndex, header: &box.header, storage: &box.storage))
        }
    }
}

// MARK: - Property.Inout (.drain)

extension Buffer.Slab where S: ~Copyable {
    /// In-place accessor that drains the buffer through the `Sequence.Drain` capability.
    @inlinable
    public var drain: Property<Sequence.Drain, Self>.Inout {
        mutating _read {
            yield Property<Sequence.Drain, Self>.Inout(&self)
        }
        mutating _modify {
            var accessor = Property<Sequence.Drain, Self>.Inout(&self)
            yield &accessor
        }
    }
}
