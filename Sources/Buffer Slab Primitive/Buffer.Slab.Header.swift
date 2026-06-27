import Affine_Primitives_Standard_Library_Integration
public import Bit_Vector_Bounded_Primitives
import Growth_Primitives
import Ordinal_Primitives_Standard_Library_Integration

//
//  Buffer.Slab.Header.swift
//  swift-buffer-primitives
//
//  Created by Coen ten Thije Boonkkamp on 04/02/2026.
//

extension Buffer.Slab where S: ~Copyable {
    // MARK: - Header

    /// Cursor state for a slab (sparse slot) buffer.
    ///
    /// Uses a `Bit.Vector` bitmap as the source of truth for which slots
    /// are occupied. `storage.initialization` stays `.empty` — the bitmap
    /// drives all cleanup.
    ///
    /// Copyable because `Bit.Vector.Bounded` (ContiguousArray-backed) is Copyable.
    ///
    /// Blueprint: `Experiments/initialization-consistency/Sources/main.swift:249-311`
    public struct Header {
        /// Bitmap tracking which slots are occupied.
        public var bitmap: Bit.Vector.Bounded

        /// Creates a header with the given slot capacity, all vacant.
        @inlinable
        public init(capacity: Bit.Index.Count) {
            do {
                self.bitmap = try Bit.Vector.Bounded(capacity: capacity, count: capacity)
            } catch {
                preconditionFailure(
                    "Bit.Vector.Bounded(capacity:count:) cannot overflow when count == capacity: \(error)"
                )
            }
        }
    }
}

extension Buffer.Slab.Header where S: ~Copyable {
    /// The number of occupied slots.
    @inlinable
    public var occupancy: Bit.Index.Count {
        bitmap.popcount
    }

    /// Whether no slots are occupied.
    @inlinable
    public var isEmpty: Bool {
        bitmap.popcount == .zero
    }

    /// Whether all slots are occupied.
    @inlinable
    public var isFull: Bool {
        bitmap.popcount >= bitmap.capacity.maximum
    }

    /// Checks whether a specific slot is occupied.
    @inlinable
    public func isOccupied(at slot: Bit.Index) -> Bool {
        bitmap[slot]
    }

    /// Finds the first vacant slot by scanning the bitmap.
    ///
    /// Uses word-level scanning: inverts each UInt word and finds the lowest
    /// set bit via `trailingZeroBitCount`. O(max/64) instead of O(max).
    ///
    /// Returns `nil` if all slots are full.
    @inlinable
    public func firstVacant(max: Bit.Index.Count) -> Bit.Index? {
        bitmap.zeros.first(max: max)
    }
}
