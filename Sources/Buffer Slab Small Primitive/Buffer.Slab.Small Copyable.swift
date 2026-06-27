import Affine_Primitives_Standard_Library_Integration
import Ordinal_Primitives_Standard_Library_Integration

// MARK: - Copyable Conformances for Slab.Small
//
// Note: Slab.Small is NEVER Copyable (contains Inline which has @_rawLayout storage).
// This file provides read-only accessors for Copyable elements.

// `S: ~Copyable, S.Element: Copyable`: `.Small` reads through each backing variant's
// element-copy surface (base `Buffer.Slab.subscript`, `Inline.peek`), both of which admit
// the move-only `Storage.Contiguous` carrier — only the element must be Copyable. ([MEM-COPY-004])
extension Buffer.Slab.Small where S: ~Copyable, S.Element: Copyable {

    /// Reads the element at the given slot without removing it.
    ///
    /// - Precondition: The slot is occupied.
    @inlinable
    public func peek(at slot: Bit.Index) -> S.Element {
        switch _storage {
        // refined-C: reach each backing variant through its PUBLIC read surface — base
        // `Buffer.Slab`'s `subscript` and `Inline`'s `peek` — so neither variant's storage
        // internals need to be visible across the module boundary ([MOD-036]).
        case .heap(let buf):
            return buf[slot]

        case .inline(let buf):
            return buf.peek(at: slot)
        }
    }
}
