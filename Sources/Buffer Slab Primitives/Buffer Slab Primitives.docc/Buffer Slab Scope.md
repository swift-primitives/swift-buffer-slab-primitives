# Buffer Slab Primitives — Scope

What this package is, and what it deliberately leaves to its siblings.

## Overview

`swift-buffer-slab-primitives` provides the **slab buffer discipline** over the `Buffer`
namespace: a sparse, bitmap-indexed slot store with O(1) insert/remove at arbitrary slots. It
defines ``Buffer/Slab`` and its capacity variants:

- ``Buffer/Slab`` — heap-backed and growable.
- `Buffer.Slab.Bounded` — fixed-capacity, heap-backed (with a phantom-typed `Indexed` view for `Index<Tag>` access).
- `Buffer.Slab.Inline` — fixed inline storage, no heap allocation.
- `Buffer.Slab.Small` — small-buffer optimization: inline storage that spills to the heap on overflow.

A `Bit.Vector` bitmap is the single source of truth for which slots are occupied; cleanup
iterates the set bits, so sparse buffers cost O(count) rather than O(capacity). It is one
specialized buffer discipline among siblings — linear, ring, linked, slots, arena, aligned,
unbounded — each its own package. Every variant supports noncopyable (`~Copyable`) element types.

## Module shape

Each variant ships as **two modules**:

- A **type module** (`Buffer Slab …​ Primitive`, singular) — the lean `~Copyable` value type
  together with the operations that touch its storage internals. Those operations are
  `@usableFromInline internal` and live next to the storage so they remain inlinable across
  package boundaries.
- A **conformances module** (`Buffer Slab …​ Primitives`, plural) — the `Copyable`-requiring
  protocol conformances (e.g. `Sequence.Protocol`),
  kept in their own module so they never constrain the type's noncopyable support. Cold
  conformances reach the now-internal storage through small `package` windows
  (`_sequenceIteratorState`) in the type module.

`Buffer Slab Primitives` is both the base conformances module and the package umbrella:
`import Buffer_Slab_Primitives` brings in the whole package, while a consumer who needs only
one variant imports that variant's module directly.

> This two-module shape is a structural choice — co-locating internal operations with their
> storage is a standard-library-grade technique for keeping a public type lean while its
> operations stay inlinable. It is not a workaround for any compiler defect.

## Core targets

| Module | Form | Holds |
|--------|------|-------|
| `Buffer Slab Primitive` | type | `Buffer.Slab`, `Buffer.Slab.Inline`, `.Header`, `.Header.Static`, internal + static ops |
| `Buffer Slab Bounded Primitive` | type | `Buffer.Slab.Bounded`, `.Bounded.Indexed`, internal ops |
| `Buffer Slab Small Primitive` | type | `Buffer.Slab.Small`, internal ops |
| `Buffer Slab Primitives` | conformances + umbrella | base conformances; re-exports every variant |
| `Buffer Slab Bounded Primitives` | conformances | `Bounded` conformances |
| `Buffer Slab Inline Primitives` | conformances | `Inline` `Sequence.Protocol` |
| `Buffer Slab Small Primitives` | consumer surface | re-exports `Small` (+ `Inline` it delegates to); carries no conformances of its own |

## Out of scope

| Capability | Belongs in |
|------------|------------|
| Other buffer disciplines (linear, ring, linked, slots, arena) | `swift-buffer-{linear,ring,linked,slots,arena}-primitives` |
| Aligned and unbounded buffer forms | `swift-buffer-aligned-primitives`, `swift-buffer-unbounded-primitives` |
| The `Buffer` namespace and capacity-growth vocabulary | `swift-buffer-primitives` |
| Slab and inline storage substrate (`Storage.Slab`, `Storage.Inline`) | `swift-storage-slab-primitives`, `swift-storage-primitives` |
| The occupancy-bitmap vocabulary (`Bit.Vector`, `Bit.Vector.Static`) | `swift-bit-vector-primitives` |
| Indices, offsets, and counts | `swift-index-primitives` |

## Evaluation rule

Additions are evaluated against this scope. A buffer form that is not the *slab* discipline
extracts to its own sibling package rather than growing this one. A new operation belongs here
only if it operates *on* a slab buffer; storage, bitmap, and indexing concerns delegate to the
packages above.
