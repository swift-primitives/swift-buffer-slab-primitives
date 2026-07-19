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
    ///
    /// fable-448 F-002: while in `.inline` mode, a slot at or past `inlineCapacity` can never
    /// be occupied (`insert` always spills before writing there — see `insert(_:at:)`), so it
    /// reads as vacant (`false`) rather than trapping. This keeps `isOccupied` total over every
    /// `Bit.Index`, matching `firstVacant()`'s own range (which never yields such a slot).
    @inlinable
    public func isOccupied(at slot: Bit.Index) -> Bool {
        switch _storage {
        // refined-C: base `Buffer.Slab` exposes a public `isOccupied(at:)`, so reach it
        // directly rather than through the now-internal `header` ([MOD-036]).
        case .heap(let buf): return buf.isOccupied(at: slot)

        case .inline(let buf):
            guard let bounded = Bit.Index.Bounded<inlineCapacity>(slot) else {
                return false
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
    /// If inline storage is full, or `slot` falls outside the inline range, spills to heap
    /// automatically using moves. The heap spill target is the common-tower
    /// `Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>` substrate.
    ///
    /// fable-448 F-002: the prior predicate spilled on occupancy alone (`!buf.isFull`), so a
    /// sparse `slot >= inlineCapacity` on an otherwise near-empty buffer bypassed the spill and
    /// reached the fixed inline store directly — an out-of-bounds write. Spilling is now also
    /// forced whenever `slot` itself does not fit `Bit.Index.Bounded<inlineCapacity>`.
    ///
    /// - Precondition: The slot is not occupied.
    @inlinable
    public mutating func insert<E>(_ element: consuming E, at slot: Bit.Index) where S == Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E> {
        switch _storage {
        case .heap(var buf):
            buf.insert(consume element, at: slot)
            self = Self(_storage: .heap(consume buf))

        case .inline(var buf):
            if !buf.isFull, let bounded = Bit.Index.Bounded<inlineCapacity>(slot) {
                buf.insert(consume element, at: bounded)
                self = Self(_storage: .inline(consume buf))
            } else {
                self = Self(_storage: .inline(consume buf))
                _spillToHeapMoving(coveringAtLeast: slot)
                guard case .heap(var buf) = _storage else { fatalError("expected heap mode after spill") }
                buf.insert(consume element, at: slot)
                self = Self(_storage: .heap(consume buf))
            }
        }
    }

    /// Removes and returns the element at the given slot.
    ///
    /// fable-448 F-002: bounds-checked in `.inline` mode (was unchecked — a slot at or past
    /// `inlineCapacity` reached the fixed inline store's unbounded `remove` directly, an
    /// out-of-bounds read/move). A slot past `inlineCapacity` was never occupiable while
    /// inline (`insert` always spills before writing there), so this is a caller-contract
    /// violation, not a recoverable case — it traps, matching `isOccupied`'s documented
    /// precondition ("the slot is occupied").
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
            guard let bounded = Bit.Index.Bounded<inlineCapacity>(slot) else {
                preconditionFailure("slot exceeds inlineCapacity — never occupiable in inline mode")
            }
            let element = buf.remove(at: bounded)
            self = Self(_storage: .inline(consume buf))
            return element
        }
    }

    /// Replaces the element at the given slot and returns the old element.
    ///
    /// fable-448 F-002: bounds-checked in `.inline` mode — see `remove(at:)`.
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
            guard let bounded = Bit.Index.Bounded<inlineCapacity>(slot) else {
                preconditionFailure("slot exceeds inlineCapacity — never occupiable in inline mode")
            }
            let old = buf.update(at: bounded, with: consume element)
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
    ///
    /// - Parameter slot: The slot the caller is about to insert at (possibly outside the inline
    ///   range). fable-448 F-002: the new capacity is `max(slot + 1, inlineCapacity * 2)` — the
    ///   normal doubling growth is not enough when a sparse `insert(at:)` names a slot past it.
    @usableFromInline
    mutating func _spillToHeapMoving<E>(coveringAtLeast slot: Bit.Index) where S == Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E> {
        switch _storage {
        case .heap(let buf):
            self = Self(_storage: .heap(consume buf))
            return

        case .inline(var buf):
            let requiredForSlot = Int(bitPattern: slot) + 1
            let newCapacity = Index<E>.Count(UInt(Swift.max(requiredForSlot, inlineCapacity * 2)))
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
