# Buffer Slab Primitives

![Development Status](https://img.shields.io/badge/status-active--development-blue.svg)

The slab buffer discipline over the `Buffer` namespace — a sparse, bitmap-indexed slot store with O(1) insert and remove at arbitrary slots, in four capacity variants (growable, bounded, inline, and small-buffer-optimized), each generic over noncopyable (`~Copyable`) elements.

---

## Quick Start

A slab tracks occupancy with a bitmap, so each element keeps a *stable slot index*: inserting and removing never shift the other elements, and a removed slot stays empty until you reuse it. This is the opposite of a positional buffer, where removing element *i* slides everything after it down.

```swift
import Buffer_Slab_Primitives
import Memory_Allocator_Primitive
import Memory_Heap_Primitives
import Storage_Contiguous_Primitives

// A growable, heap-backed slab of `Int`. Slots are stable addresses, not positions.
typealias IntSlab = Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Int>>.Slab

var slab = IntSlab(minimumCapacity: 8)
slab.insert(42, at: 3)
slab.insert(7, at: 5)
_ = slab.remove(at: 3)            // removing slot 3 never disturbs slot 5
print(slab.occupancy)            // 1
print(slab.isOccupied(at: 5))    // true
```

`Buffer.Slab.Small` keeps short slot maps off the heap entirely and only allocates once they outgrow their inline capacity, while presenting the same slot API as the growable form:

```swift
import Buffer_Slab_Primitives
import Memory_Allocator_Primitive
import Memory_Heap_Primitives
import Storage_Contiguous_Primitives

// Small-buffer optimization: inline storage until it overflows, then a heap spill.
var small = Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Int>>.Slab.Small<2>()
small.insert(10, at: 0)
small.insert(20, at: 1)          // inline arm now full (capacity 2)
print(small.isSpilled)           // false — still inline

small.insert(30, at: 2)          // overflow → transparently spills to the heap
print(small.isSpilled)           // true
print(small.occupancy)           // 3
```

---

## Installation

```swift
dependencies: [
    .package(url: "https://github.com/swift-primitives/swift-buffer-slab-primitives.git", branch: "main")
]
```

```swift
.target(
    name: "App",
    dependencies: [
        // The umbrella — the whole package.
        .product(name: "Buffer Slab Primitives", package: "swift-buffer-slab-primitives"),
        // …or depend on just the variant you use, e.g.:
        // .product(name: "Buffer Slab Inline Primitives", package: "swift-buffer-slab-primitives"),
    ]
)
```

Requires Swift 6.3.1 and macOS 26 / iOS 26 / tvOS 26 / watchOS 26 / visionOS 26 (or the matching Linux / Windows toolchain).

---

## Variants

| Type | Storage | Reach for it when |
|------|---------|-------------------|
| `Buffer.Slab` | heap, growable | the slot count isn't known up front |
| `Buffer.Slab.Bounded` | heap, fixed | the capacity is known and fixed |
| `Buffer.Slab.Inline<n>` | inline, fixed | the maximum is small and known at compile time |
| `Buffer.Slab.Small<n>` | inline → heap | usually small, occasionally larger (SBO) |

Every variant is generic over `Element` — including noncopyable element types — and uses a `Bit.Vector` bitmap as the source of truth for occupancy.

---

## Architecture

Each variant ships as **two modules**: a lean *type* module (the value type plus the operations that touch its storage) and an *ops* module (the `Sequence` / `Iterable` conformances, kept separate so they never constrain noncopyable use). Importing `Buffer Slab Primitives` brings in the whole package; importing a single variant module brings in just that variant.

| Product | Purpose |
|---------|---------|
| `Buffer Slab Primitives` | Umbrella — re-exports the base type and every variant's conformances. |
| `Buffer Slab Primitive` | The growable `Buffer.Slab` value type and its storage operations. |
| `Buffer Slab Bounded Primitive` · `Buffer Slab Bounded Primitives` | Fixed-capacity `Buffer.Slab.Bounded`: type module · conformances. |
| `Buffer Slab Inline Primitive` · `Buffer Slab Inline Primitives` | Inline `Buffer.Slab.Inline<n>`: type module · `Iterable` conformance. |
| `Buffer Slab Small Primitive` · `Buffer Slab Small Primitives` | Small-buffer `Buffer.Slab.Small<n>`: type module · conformances. |
| `Buffer Slab Primitives Test Support` | Re-exports for downstream test targets. |

Foundation-free.

---

## Platform Support

| Platform | Status |
|----------|--------|
| macOS 26 | Full support |
| Linux | Full support |
| Windows | Full support |
| iOS / tvOS / watchOS / visionOS | Supported |

---

## Related Packages

- [`swift-buffer-primitives`](https://github.com/swift-primitives/swift-buffer-primitives) — the `Buffer` namespace and capacity-growth vocabulary.
- [`swift-bit-vector-primitives`](https://github.com/swift-primitives/swift-bit-vector-primitives) — the occupancy-bitmap vocabulary.
- [`swift-storage-primitives`](https://github.com/swift-primitives/swift-storage-primitives) — the contiguous-storage substrate.
- Sibling buffer disciplines: `swift-buffer-linear-primitives`, `swift-buffer-ring-primitives`.

---

## Community

<!-- BEGIN: discussion -->
<!-- Discussion thread created at publication. -->
<!-- END: discussion -->

## License

Apache 2.0. See [LICENSE.md](LICENSE.md).
