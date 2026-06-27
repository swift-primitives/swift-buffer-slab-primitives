# ``Buffer_Slab_Primitives``

The slab buffer discipline over `Buffer` — a sparse, bitmap-indexed slot store with O(1)
insert/remove at arbitrary slots, in inline and small-buffer-optimized variants, for
noncopyable elements.

## Overview

`Buffer.Slab` is a sparse slot buffer: a `Bit.Vector` bitmap tracks which slots are occupied,
so elements live at stable slot indices and removal leaves a hole rather than shifting
neighbours. It comes in four capacity flavours that share one slot API and all support
noncopyable (`~Copyable`) element types:

- **`Buffer.Slab`** — heap-backed and growable.
- **`Buffer.Slab.Bounded`** — fixed-capacity, heap-backed (plus a phantom-typed `Indexed` view).
- **`Buffer.Slab.Inline<wordCount>`** — fixed inline storage, no heap allocation.
- **`Buffer.Slab.Small<inlineCapacity>`** — small-buffer optimization: inline until it overflows, then spills to the heap.

The bitmap is the single source of truth for occupancy; deinitialization iterates the set bits
rather than a contiguous range, so sparse buffers cost O(count), not O(capacity).

Importing `Buffer_Slab_Primitives` brings in every variant. A consumer that needs only one
variant imports that variant's module directly — for example `Buffer_Slab_Inline_Primitives`.

```swift
import Buffer_Slab_Primitives

var slab = Buffer<Storage<Int>.Heap>.Slab(minimumCapacity: 8)
slab.insert(42, at: 3)
slab.insert(7, at: 5)
let value = slab[3]                 // 42 — slots are stable, not positional
_ = slab.remove(at: 3)              // leaves slot 5 untouched
```

## Topics

### Scope

- <doc:Buffer-Slab-Scope>
