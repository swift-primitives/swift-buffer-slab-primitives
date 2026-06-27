import Affine_Primitives_Standard_Library_Integration
public import Bit_Vector_Bounded_Primitives
public import Growth_Primitives
public import Memory_Allocator_Primitive
public import Memory_Heap_Primitives
import Ordinal_Primitives_Standard_Library_Integration
public import Storage_Contiguous_Primitives

// MARK: - forEach.occupied for Slab.Bounded
//
// Co-located with the `Buffer.Slab.Bounded` type ([MOD-036]) so it can reach the now-
// `@usableFromInline internal` `header` intra-module.

extension Property.Borrow where Base: ~Copyable {

    /// Visits each occupied slot in the bounded slab.
    ///
    /// Uses Wegner/Kernighan bit iteration — O(count) rather than O(capacity).
    @inlinable
    public func occupied<Element>(
        _ body: (Bit.Index) -> Void
    ) where Tag == Sequence.ForEach, Base == Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Element>>.Slab.Bounded {
        base.value.header.bitmap.ones.forEach(body)
    }
}
