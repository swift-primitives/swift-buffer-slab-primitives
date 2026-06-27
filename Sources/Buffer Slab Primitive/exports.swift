// Re-export the `Buffer` namespace + the capability protocol so consumers of
// every Slab variant resolve `Buffer<S>.Slab` and the inherited protocol members
// without a separate import (MemberImportVisibility).
@_exported public import Buffer_Protocol_Primitives
@_exported public import Growth_Primitives
@_exported public import Index_Primitives
@_exported public import Memory_Inline_Primitives
@_exported public import Memory_Primitives
@_exported public import Sequence_Primitives
@_exported public import Storage_Contiguous_Primitives
@_exported public import Store_Initialization_Primitives
