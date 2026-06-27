import Affine_Primitives_Standard_Library_Integration
import Bit_Vector_Static_Primitives
import Ordinal_Primitives_Standard_Library_Integration

extension Buffer.Slab.Header where S: ~Copyable {
    // MARK: - Header.Static

    /// Compile-time word count slab header using `Bit.Vector.Static`.
    ///
    /// Unlike `Buffer.Slab.Header` which uses `Bit.Vector` (~Copyable),
    /// this type uses `Bit.Vector.Static<wordCount>` which IS Copyable.
    /// This means types using this header CAN be Copyable when their
    /// elements are Copyable.
    public struct Static<let wordCount: Int>: Copyable, Sendable {
        /// Bitmap tracking which slots are occupied.
        public var bitmap: Bit.Vector.Static<wordCount>

        /// Creates a header with all slots vacant.
        @inlinable
        public init() {
            self.bitmap = .init()
        }
    }
}
