// The `Inline` type now lives in the parallel `Buffer Slab Inline Primitive` type module
// (mirroring `Buffer Slab Bounded Primitive`), so the Inline ops module re-exports that type
// singular. The Inline type singular itself re-exports `Buffer_Slab_Primitive`, so consumers
// still see the base `Buffer.Slab` namespace transitively. (NOT the base ops plural
// `Buffer Slab Primitives`, which re-exports this module — that would be a [MOD-005] cycle.)
@_exported public import Buffer_Slab_Inline_Primitive
@_exported public import Iterable
@_exported public import Sequence_Primitives
