import Affine_Primitives_Standard_Library_Integration
public import Bit_Vector_Bounded_Primitives
public import Growth_Primitives
public import Memory_Allocator_Primitive
public import Memory_Heap_Primitives
import Ordinal_Primitives_Standard_Library_Integration
public import Storage_Contiguous_Primitives

// MARK: - forEach.occupied for Slab
//
// `base.value` is the lean `Buffer.Slab` value; reaching `header.bitmap` here is intra-module
// against the now-`@usableFromInline internal` storage (refined-C, [MOD-036]).
// The `Bounded` variant's `forEach.occupied` lives in the `Buffer Slab Bounded Primitive` type
// module — the only module that sees `Buffer.Slab.Bounded`'s internal `header`.

extension Property.Borrow where Base: ~Copyable {

    /// Visits each occupied slot in the slab.
    ///
    /// Uses Wegner/Kernighan bit iteration — O(count) rather than O(capacity).
    @inlinable
    public func occupied<Element>(
        _ body: (Bit.Index) -> Void
    ) where Tag == Sequence.ForEach, Base == Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Element>>.Slab {
        base.value.header.bitmap.ones.forEach(body)
    }
}
