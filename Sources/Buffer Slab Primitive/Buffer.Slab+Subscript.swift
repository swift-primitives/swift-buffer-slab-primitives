import Affine_Primitives_Standard_Library_Integration
public import Bit_Vector_Bounded_Primitives
import Growth_Primitives
import Ordinal_Primitives_Standard_Library_Integration
public import Storage_Protocol_Primitives
public import Store_Protocol_Primitives

// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-primitives open source project
//
// Copyright (c) 2024-2026 Coen ten Thije Boonkkamp and the swift-primitives project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

// MARK: - Capacity

extension Buffer.Slab where S: ~Copyable {
    /// The total number of slots (occupied + vacant).
    @inlinable
    public var capacity: Bit.Index.Count {
        header.bitmap.capacity.maximum
    }
}

// MARK: - Read Subscript

extension Buffer.Slab where S: ~Copyable {
    /// Borrows the element at the given slot without removing it.
    ///
    /// - Precondition: The slot is occupied.
    @inlinable
    public subscript(slot: Bit.Index) -> S.Element {
        _read {
            yield storage[slot.retag(S.Element.self)]
        }
    }
}

// MARK: - Iteration

extension Buffer.Slab where S: ~Copyable {
    /// Read-only view for occupied slot iteration.
    ///
    /// Usage: `slab.forEach.occupied { slot in ... }`
    ///
    /// Uses Wegner/Kernighan bit iteration — O(count) rather than O(capacity).
    @inlinable
    public var forEach: Property<Sequence.ForEach, Self>.Borrow {
        _read {
            yield Property<Sequence.ForEach, Self>.Borrow(self)
        }
    }
}
