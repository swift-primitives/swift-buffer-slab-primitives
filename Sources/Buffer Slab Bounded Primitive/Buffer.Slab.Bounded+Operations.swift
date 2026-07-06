import Affine_Primitives_Standard_Library_Integration
public import Bit_Vector_Bounded_Primitives
public import Memory_Allocator_Primitive
public import Memory_Allocator_Protocol_Primitives
import Ordinal_Primitives_Standard_Library_Integration
public import Storage_Contiguous_Primitives

// MARK: - Extensions for Slab.Bounded (declared in Core)

extension Buffer.Slab.Bounded where S: ~Copyable {

    /// Creates a bounded slab buffer with at least the given capacity (any growable column).
    ///
    /// Allocation-generic ([DS-029] form 2): pinned over any `Resource: Memory.Growable`, so
    /// `Memory.Heap` and `Memory.Small<n>`-leaf bounded slabs construct uniformly (`Memory.Inline`
    /// is fenced out — it does not conform `Memory.Growable`). Actual capacity comes from
    /// `storage.capacity` per H6.
    @inlinable
    public init<E: ~Copyable, Resource: Memory.Growable & ~Copyable>(minimumCapacity: Index<E>.Count) where S == Storage<Memory.Allocator<Resource>>.Contiguous<E> {
        let storage = S.create(minimumCapacity: minimumCapacity)
        self.init(
            header: Buffer.Slab.Header(capacity: storage.capacity.retag(Bit.self)),
            storage: storage
        )
    }

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

    // MARK: - Mutations

    /// Inserts an element at the given slot.
    ///
    /// - Precondition: The slot is not occupied.
    @inlinable
    public mutating func insert(_ element: consuming S.Element, at slot: Bit.Index) {
        Buffer.Slab.insert(consume element, at: slot, header: &box.header, storage: &box.storage)
    }

    /// Removes and returns the element at the given slot.
    ///
    /// - Precondition: The slot is occupied.
    @inlinable
    public mutating func remove(at slot: Bit.Index) -> S.Element {
        Buffer.Slab.remove(at: slot, header: &box.header, storage: &box.storage)
    }

    /// Replaces the element at the given slot and returns the old element.
    ///
    /// - Precondition: The slot is occupied.
    @inlinable
    public mutating func update(at slot: Bit.Index, with element: consuming S.Element) -> S.Element {
        Buffer.Slab.update(at: slot, with: consume element, storage: &box.storage)
    }

    /// Returns the first vacant slot, or `nil` if all slots are full.
    @inlinable
    public func firstVacant() -> Bit.Index? {
        Buffer.Slab.firstVacant(header: header)
    }

    /// Removes all elements from the buffer.
    @inlinable
    public mutating func removeAll() {
        Buffer.Slab.deinitializeAll(header: &box.header, storage: &box.storage)
    }
}

// MARK: - Sequence.Drain.Protocol (~Copyable)

extension Buffer.Slab.Bounded: Sequence.Drain.`Protocol` where S: ~Copyable {
    /// Removes every occupied element, consuming each through `body`.
    @inlinable
    public mutating func drain(_ body: (consuming S.Element) -> Void) {
        box.header.bitmap.ones.forEach { bitIndex in
            body(Buffer.Slab.remove(at: bitIndex, header: &box.header, storage: &box.storage))
        }
    }
}

// MARK: - Property.Inout (.drain)

extension Buffer.Slab.Bounded where S: ~Copyable {
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

// MARK: - Iteration

extension Buffer.Slab.Bounded where S: ~Copyable {
    /// Visits each occupied slot index via read-only `Property.Borrow`.
    @inlinable
    public var forEach: Property<Sequence.ForEach, Self>.Borrow {
        _read {
            yield Property<Sequence.ForEach, Self>.Borrow(self)
        }
    }
}
