@_exported public import Buffer_Slab_Inline_Primitives
// `Buffer Slab Small Primitives` is an exports-only consumer surface: `Buffer.Slab.Small`
// carries no Copyable-imposing conformance of its own (its `peek` returns by value and
// `Sequence.Drain.Protocol` is `~Copyable`), so this ops module re-exports the `Small` type
// plus the `Inline` ops it delegates to ([MOD-009]) and nothing more.
@_exported public import Buffer_Slab_Small_Primitive
@_exported public import Sequence_Primitives
