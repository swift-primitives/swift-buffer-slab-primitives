import Affine_Primitives_Standard_Library_Integration
import Index_Primitives
import Ordinal_Primitives_Standard_Library_Integration

extension Buffer.Slab.Inline where S: ~Copyable {
    /// Errors that can occur during inline slab buffer operations.
    public enum Error: Swift.Error, Sendable, Equatable {
        /// The number of elements exceeds the buffer's capacity.
        case capacityExceeded
    }
}
