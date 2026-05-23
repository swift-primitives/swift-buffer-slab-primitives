import Ordinal_Primitives_Standard_Library_Integration
import Affine_Primitives_Standard_Library_Integration
public import Buffer_Growth_Primitives

// MARK: - forEach.occupied for Slab

extension Property.Borrow where Base: ~Copyable {

    /// Visits each occupied slot in the slab.
    ///
    /// Uses Wegner/Kernighan bit iteration — O(count) rather than O(capacity).
    @inlinable
    public func occupied<Element>(
        _ body: (Bit.Index) -> Void
    ) where Tag == Sequence.ForEach, Base == Buffer<Element>.Slab {
        base.value.header.bitmap.ones.forEach(body)
    }
}

// MARK: - forEach.occupied for Slab.Bounded

extension Property.Borrow where Base: ~Copyable {

    /// Visits each occupied slot in the bounded slab.
    ///
    /// Uses Wegner/Kernighan bit iteration — O(count) rather than O(capacity).
    @inlinable
    public func occupied<Element>(
        _ body: (Bit.Index) -> Void
    ) where Tag == Sequence.ForEach, Base == Buffer<Element>.Slab.Bounded {
        base.value.header.bitmap.ones.forEach(body)
    }
}
