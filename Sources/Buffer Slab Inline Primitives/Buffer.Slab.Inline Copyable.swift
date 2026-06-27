import Affine_Primitives_Standard_Library_Integration
public import Finite_Bounded_Primitives
public import Iterator_Chunk_Primitives
public import Iterator_Primitive
import Ordinal_Primitives_Standard_Library_Integration

// MARK: - Copyable Conformances for Slab.Inline
//
// Unlike heap-backed Slab.Bounded (always ~Copyable due to Bit.Vector),
// Slab.Inline uses Header.Static (Copyable), so the type IS Copyable
// when Element: Copyable.
//
// refined-C ([MOD-004]/[MOD-036]): the `Sequence.Protocol` conformance is isolated here; its
// `makeIterator` reaches the type module through the `_occupiedElements()` `package` window
// ([MOD-037]) — an owned `[S.Element]` snapshot, never the box / a raw base pointer. The
// `peek(at:)` Copyable instance methods co-locate with storage in the type module.

// MARK: - Array Initialization

// `S: ~Copyable, S.Element: Copyable`: the carrier is a phantom (`.Inline` stores
// `Store.Inline<S.Element, wordCount>`), so the element-copy arm constrains only the
// element — the move-only `Storage.Contiguous` carrier must be admitted. ([MEM-COPY-004])
extension Buffer.Slab.Inline where S: ~Copyable, S.Element: Copyable {

    /// Creates an inline slab buffer populated with the given elements.
    ///
    /// Elements are inserted at sequential slot indices starting from zero.
    ///
    /// - Parameter elements: The elements to populate the buffer with.
    /// - Throws: ``Error/capacityExceeded`` if `elements.count` exceeds `wordCount`.
    @inlinable
    public init(_ elements: [S.Element]) throws(Self.Error) {
        guard elements.count <= wordCount else { throw .capacityExceeded }
        var buffer = Self()
        for (i, element) in elements.enumerated() {
            guard let slot = Bit.Index.Bounded<wordCount>(Bit.Index(Ordinal(UInt(i)))) else {
                preconditionFailure("element index exceeds wordCount")
            }
            buffer.insert(element, at: slot)
        }
        self = buffer
    }
}

// MARK: - Sequence.Protocol

extension Buffer.Slab.Inline: Iterable where S: ~Copyable, S.Element: Copyable {
    /// Iterator over slab inline buffer elements.
    ///
    /// Holding-patch shape: iterates an owned, slot-ordered snapshot of the occupied
    /// elements (built once at `makeIterator` via the `_occupiedElements()` package
    /// window). `Store.Inline` vends no public base pointer, so the prior cached-pointer
    /// iterator is replaced by this snapshot. INTERIM DEBT (eager + allocates) — dissolves
    /// with the deferred occupancy decision (HANDOFF-sparse-occupancy-placement.md).
    public struct Iterator: Iterator_Primitive.Iterator.`Protocol`, IteratorProtocol, @unchecked Sendable {
        // WHY: Category B — value-semantic owned snapshot. `@unchecked` bridges the
        // WHY: `[S.Element]` (unconstrained-Copyable) Sendable-inference gap, preserving
        // WHY: the iterator's prior Sendable surface; ownership is unique (a moved copy).
        @usableFromInline
        let elements: [S.Element]
        @usableFromInline
        var position: Int

        @inlinable
        package init(elements: [S.Element]) {
            self.elements = elements
            self.position = 0
        }
    }

    /// Returns an iterator over the occupied elements in slot order.
    public borrowing func makeIterator() -> Iterator {
        // [MOD-037]: reach occupied elements through the type module's `package` window so
        // this cold conformance never touches Inline's internal storage/header. Non-inlinable
        // ([MOD-036]): a public @inlinable body must not reference the `package` window.
        Iterator(elements: _occupiedElements())
    }

    // Iterable's span witness: wrap the scalar snapshot cursor in the generator materialize
    // adapter (the lent span is over the adapter's OWNED slot, not the @_rawLayout storage).
    /// The materializing iterator type backing the `Iterable` conformance.
    @_implements(Iterable,Iterator)
    public typealias IterableIterator = Iterator_Primitive.Iterator.Materializing<Iterator>

    /// Returns the materializing iterator for the `Iterable` conformance.
    @_implements(Iterable,makeIterator())
    public borrowing func iterableMakeIterator() -> Iterator_Primitive.Iterator.Materializing<Iterator> {
        Iterator_Primitive.Iterator.Materializing(Iterator(elements: _occupiedElements()))
    }
}

extension Buffer.Slab.Inline.Iterator where S: ~Copyable, S.Element: Copyable {
    /// Returns the next occupied element, or `nil` when the iterator is exhausted.
    @inlinable
    public mutating func next() -> S.Element? {
        guard position < elements.count else { return nil }
        defer { position += 1 }
        return elements[position]
    }
}

// MARK: - Swift.Sequence
// Blocked on Store.Inline conditional Copyable (INV-INLINE-004a).
// Uncomment when @_rawLayout is replaced with conditionally-Copyable InlineArray.
//
// extension Buffer.Slab.Inline: Swift.Sequence where S: Copyable {
//     @inlinable
//     public var underestimatedCount: Int { Int(bitPattern: header.bitmap.popcount) }
// }
