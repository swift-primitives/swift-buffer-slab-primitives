import Affine_Primitives_Standard_Library_Integration
public import Finite_Bounded_Primitives
public import Memory_Allocator_Primitive
import Ordinal_Primitives_Standard_Library_Integration
public import Storage_Contiguous_Primitives
public import Storage_Protocol_Primitives

// MARK: - Extensions for Slab.Small (declared in Core)

extension Buffer.Slab.Small where S: ~Copyable {

    /// Creates an empty small slab buffer with inline storage.
    @inlinable
    public init() {
        self.init(
            _storage: .inline(Buffer.Slab.Inline<inlineCapacity>())
        )
    }

    /// Whether the buffer has spilled to heap storage.
    @inlinable
    public var isSpilled: Bool {
        switch _storage {
        case .heap: return true
        case .inline: return false
        }
    }

    // MARK: - Properties

    /// The number of occupied slots.
    @inlinable
    public var occupancy: Bit.Index.Count {
        switch _storage {
        case .heap(let buf): return buf.occupancy
        case .inline(let buf): return buf.occupancy
        }
    }

    /// The number of elements logically held by the buffer.
    ///
    /// A slab counts in the bitmap (slot) domain, so `count` equals the live-element
    /// cardinality reported by ``occupancy`` (a `Bit.Index.Count`). This is the
    /// ``Buffer/`Protocol``` `count` witness — its domain (`Bit.Index.Count`) overrides
    /// the protocol's element-domain default.
    @inlinable
    public var count: Bit.Index.Count { occupancy }

    /// Whether no slots are occupied.
    @inlinable
    public var isEmpty: Bool {
        switch _storage {
        case .heap(let buf): return buf.isEmpty
        case .inline(let buf): return buf.isEmpty
        }
    }

    /// Whether all storage slots are occupied.
    @inlinable
    public var isFull: Bool {
        switch _storage {
        case .heap(let buf): return buf.isFull
        case .inline(let buf): return buf.isFull
        }
    }

    /// Whether a specific slot is occupied.
    @inlinable
    public func isOccupied(at slot: Bit.Index) -> Bool {
        switch _storage {
        // refined-C: base `Buffer.Slab` exposes a public `isOccupied(at:)`, so reach it
        // directly rather than through the now-internal `header` ([MOD-036]).
        case .heap(let buf): return buf.isOccupied(at: slot)

        case .inline(let buf):
            guard let bounded = Bit.Index.Bounded<inlineCapacity>(slot) else {
                preconditionFailure("slot exceeds inlineCapacity")
            }
            return buf.isOccupied(at: bounded)
        }
    }

    /// Returns the first vacant slot, or `nil` if all slots are full.
    @inlinable
    public func firstVacant() -> Bit.Index? {
        switch _storage {
        case .heap(let buf): return buf.firstVacant()
        case .inline(let buf): return buf.firstVacant().map { Bit.Index($0) }
        }
    }

    // MARK: - Mutations

    /// Inserts an element at the given slot.
    ///
    /// If inline storage is full, spills to heap automatically using moves.
    /// The heap spill target is the common-tower `Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>` substrate.
    ///
    /// - Precondition: The slot is not occupied.
    @inlinable
    public mutating func insert<E>(_ element: consuming E, at slot: Bit.Index) where S == Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E> {
        switch _storage {
        case .heap(var buf):
            buf.insert(consume element, at: slot)
            self = Self(_storage: .heap(consume buf))

        case .inline(var buf):
            if !buf.isFull {
                buf.insert(consume element, at: slot)
                self = Self(_storage: .inline(consume buf))
            } else {
                self = Self(_storage: .inline(consume buf))
                _spillToHeapMoving()
                guard case .heap(var buf) = _storage else { fatalError("expected heap mode after spill") }
                buf.insert(consume element, at: slot)
                self = Self(_storage: .heap(consume buf))
            }
        }
    }

    /// Removes and returns the element at the given slot.
    ///
    /// - Precondition: The slot is occupied.
    @inlinable
    public mutating func remove(at slot: Bit.Index) -> S.Element {
        switch _storage {
        case .heap(var buf):
            let element = buf.remove(at: slot)
            self = Self(_storage: .heap(consume buf))
            return element

        case .inline(var buf):
            let element = buf.remove(at: slot)
            self = Self(_storage: .inline(consume buf))
            return element
        }
    }

    /// Replaces the element at the given slot and returns the old element.
    ///
    /// - Precondition: The slot is occupied.
    @inlinable
    public mutating func update(at slot: Bit.Index, with element: consuming S.Element) -> S.Element {
        switch _storage {
        case .heap(var buf):
            let old = buf.update(at: slot, with: consume element)
            self = Self(_storage: .heap(consume buf))
            return old

        case .inline(var buf):
            let old = buf.update(at: slot, with: consume element)
            self = Self(_storage: .inline(consume buf))
            return old
        }
    }

    /// Removes all elements from the buffer.
    ///
    /// Resets to inline mode.
    @inlinable
    public mutating func removeAll() {
        switch _storage {
        case .heap(var buf):
            buf.removeAll()
            self = Self(_storage: .inline(Buffer.Slab.Inline<inlineCapacity>()))
            _ = consume buf

        case .inline(var buf):
            buf.removeAll()
            self = Self(_storage: .inline(consume buf))
        }
    }

    // MARK: - Spill

    /// Moves inline elements to heap storage and activates heap mode.
    ///
    /// The heap spill target is the common-tower `Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>` substrate.
    @usableFromInline
    mutating func _spillToHeapMoving<E>() where S == Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E> {
        switch _storage {
        case .heap(let buf):
            self = Self(_storage: .heap(consume buf))
            return

        case .inline(var buf):
            let newCapacity = Index<E>.Count(UInt(inlineCapacity * 2))
            var heap = Buffer.Slab(minimumCapacity: newCapacity)

            // [MOD-037]: drain the inline buffer through its PUBLIC slot API and re-insert
            // each occupied element at the SAME slot index on the heap, preserving the sparse
            // bitmap positions. Reaching the Inline variant only through its public
            // `isOccupied`/`remove` surface keeps Inline's storage internals
            // `@usableFromInline internal` (refined-C) rather than pinned to `package` —
            // the Small satellite no longer touches `buf.storage`/`buf.header` or the
            // static `moveSlotToHeap` helper.
            var slot: Bit.Index = .zero
            let end = Bit.Index.Count(UInt(inlineCapacity)).map(Ordinal.init)
            while slot < end {
                guard let bounded = Bit.Index.Bounded<inlineCapacity>(slot) else {
                    preconditionFailure("slot exceeds inlineCapacity")
                }
                if buf.isOccupied(at: bounded) {
                    heap.insert(buf.remove(at: bounded), at: slot)
                }
                slot += .one
            }

            self = Self(_storage: .heap(consume heap))
        // buf goes out of scope — deinit runs on empty (drained) state
        }
    }
}

// MARK: - Sequence.Drain.Protocol

extension Buffer.Slab.Small: Sequence.Drain.`Protocol` where S: ~Copyable {
    /// Removes every occupied element, consuming each through `body`.
    @inlinable
    public mutating func drain(_ body: (consuming S.Element) -> Void) {
        switch _storage {
        case .heap(var buf):
            buf.drain(body)
            self = Self(_storage: .inline(Buffer.Slab.Inline<inlineCapacity>()))
            _ = consume buf

        case .inline(var buf):
            buf.drain(body)
            self = Self(_storage: .inline(consume buf))
        }
    }
}

// MARK: - Property.Inout (.drain)

extension Buffer.Slab.Small where S: ~Copyable {
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
