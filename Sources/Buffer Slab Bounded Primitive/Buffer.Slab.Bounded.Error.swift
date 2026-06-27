import Affine_Primitives_Standard_Library_Integration
import Ordinal_Primitives_Standard_Library_Integration

extension Buffer.Slab.Bounded where S: ~Copyable {
    /// Errors that can occur during bounded slab buffer operations.
    public enum Error: Swift.Error, Sendable, Equatable {
        /// The number of elements exceeds the buffer's capacity.
        case capacityExceeded
    }
}
