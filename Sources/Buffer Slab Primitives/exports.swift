@_exported public import Buffer_Slab_Bounded_Primitives
@_exported public import Buffer_Slab_Inline_Primitives
// `Buffer Slab Primitives` is the base conformances module AND the [MOD-005] umbrella:
// it re-exports the base type plus every variant ops module, so `import Buffer_Slab_Primitives`
// surfaces the whole package. Consumers needing only one variant import that variant per [MOD-015].
@_exported public import Buffer_Slab_Primitive
@_exported public import Buffer_Slab_Small_Primitives
@_exported public import Sequence_Primitives
