// swift-tools-version: 6.3.1

import PackageDescription

let package = Package(
    name: "swift-buffer-slab-primitives",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
        .tvOS(.v26),
        .watchOS(.v26),
        .visionOS(.v26),
    ],
    products: [
        // MARK: - Type modules (lean ~Copyable types; Copyable-requiring conformances live in the ops modules per [MOD-004])
        .library(name: "Buffer Slab Primitive", targets: ["Buffer Slab Primitive"]),
        .library(name: "Buffer Slab Bounded Primitive", targets: ["Buffer Slab Bounded Primitive"]),
        .library(name: "Buffer Slab Inline Primitive", targets: ["Buffer Slab Inline Primitive"]),
        .library(name: "Buffer Slab Small Primitive", targets: ["Buffer Slab Small Primitive"]),
        // MARK: - Ops modules (one per variant); `Buffer Slab Primitives` doubles as the [MOD-005] umbrella
        .library(name: "Buffer Slab Primitives", targets: ["Buffer Slab Primitives"]),
        .library(name: "Buffer Slab Bounded Primitives", targets: ["Buffer Slab Bounded Primitives"]),
        .library(name: "Buffer Slab Inline Primitives", targets: ["Buffer Slab Inline Primitives"]),
        .library(name: "Buffer Slab Small Primitives", targets: ["Buffer Slab Small Primitives"]),
        .library(name: "Buffer Slab Primitives Test Support", targets: ["Buffer Slab Primitives Test Support"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swift-primitives/swift-memory-inline-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-buffer-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-growth-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-storage-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-bit-vector-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-index-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-finite-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-affine-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-ordinal-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-memory-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-sequence-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-iterator-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-pair-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-memory-heap-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-memory-allocation-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-memory-small-primitives.git", branch: "main"),
    ],
    targets: [

        // MARK: - Type modules — lean ~Copyable types + @usableFromInline internal ops co-located with storage ([MOD-036])
        .target(
            name: "Buffer Slab Primitive",
            dependencies: [
                .product(name: "Buffer Primitive", package: "swift-buffer-primitives"),
                .product(name: "Growth Primitives", package: "swift-growth-primitives"),
                .product(name: "Memory Allocator Protocol Primitives", package: "swift-memory-allocation-primitives"),
                .product(name: "Buffer Protocol Primitives", package: "swift-buffer-primitives"),
                .product(name: "Storage Contiguous Primitives", package: "swift-storage-primitives"),
                .product(name: "Storage Contiguous Primitives", package: "swift-storage-primitives"),
                .product(name: "Memory Heap Primitives", package: "swift-memory-heap-primitives"),
                .product(name: "Memory Allocator Primitive", package: "swift-memory-allocation-primitives"),
                .product(name: "Memory Inline Primitives", package: "swift-memory-inline-primitives"),
                .product(name: "Store Initialization Primitives", package: "swift-storage-primitives"),
                .product(name: "Storage Protocol Primitives", package: "swift-storage-primitives"),
                .product(name: "Store Protocol Primitives", package: "swift-storage-primitives"),
                .product(name: "Bit Vector Bounded Primitives", package: "swift-bit-vector-primitives"),
                .product(name: "Index Primitives", package: "swift-index-primitives"),
                .product(name: "Memory Primitives", package: "swift-memory-primitives"),
                .product(name: "Affine Primitives", package: "swift-affine-primitives"),
                .product(name: "Ordinal Primitives", package: "swift-ordinal-primitives"),
                .product(name: "Sequence Primitives", package: "swift-sequence-primitives"),
                .product(name: "Pair Primitives", package: "swift-pair-primitives"),
            ]
        ),
        .target(
            name: "Buffer Slab Bounded Primitive",
            dependencies: [
                "Buffer Slab Primitive",
                .product(name: "Buffer Primitive", package: "swift-buffer-primitives"),
                .product(name: "Growth Primitives", package: "swift-growth-primitives"),
                .product(name: "Memory Allocator Protocol Primitives", package: "swift-memory-allocation-primitives"),
                .product(name: "Buffer Protocol Primitives", package: "swift-buffer-primitives"),
                .product(name: "Storage Contiguous Primitives", package: "swift-storage-primitives"),
                .product(name: "Storage Contiguous Primitives", package: "swift-storage-primitives"),
                .product(name: "Memory Heap Primitives", package: "swift-memory-heap-primitives"),
                .product(name: "Memory Allocator Primitive", package: "swift-memory-allocation-primitives"),
                .product(name: "Memory Inline Primitives", package: "swift-memory-inline-primitives"),
                .product(name: "Store Initialization Primitives", package: "swift-storage-primitives"),
                .product(name: "Storage Protocol Primitives", package: "swift-storage-primitives"),
                .product(name: "Store Protocol Primitives", package: "swift-storage-primitives"),
                .product(name: "Bit Vector Bounded Primitives", package: "swift-bit-vector-primitives"),
                .product(name: "Index Primitives", package: "swift-index-primitives"),
                .product(name: "Memory Primitives", package: "swift-memory-primitives"),
                .product(name: "Affine Primitives", package: "swift-affine-primitives"),
                .product(name: "Ordinal Primitives", package: "swift-ordinal-primitives"),
                .product(name: "Sequence Primitives", package: "swift-sequence-primitives"),
                .product(name: "Pair Primitives", package: "swift-pair-primitives"),
            ]
        ),
        .target(
            name: "Buffer Slab Inline Primitive",
            dependencies: [
                "Buffer Slab Primitive",
                .product(name: "Buffer Primitive", package: "swift-buffer-primitives"),
                .product(name: "Growth Primitives", package: "swift-growth-primitives"),
                .product(name: "Buffer Protocol Primitives", package: "swift-buffer-primitives"),
                .product(name: "Storage Contiguous Primitives", package: "swift-storage-primitives"),
                .product(name: "Storage Contiguous Primitives", package: "swift-storage-primitives"),
                .product(name: "Memory Heap Primitives", package: "swift-memory-heap-primitives"),
                .product(name: "Memory Inline Primitives", package: "swift-memory-inline-primitives"),
                .product(name: "Store Initialization Primitives", package: "swift-storage-primitives"),
                .product(name: "Store Inline Primitives", package: "swift-storage-primitives"),
                .product(name: "Bit Vector Static Primitives", package: "swift-bit-vector-primitives"),
                .product(name: "Index Primitives", package: "swift-index-primitives"),
                .product(name: "Finite Bounded Primitives", package: "swift-finite-primitives"),
                .product(name: "Memory Primitives", package: "swift-memory-primitives"),
                .product(name: "Affine Primitives", package: "swift-affine-primitives"),
                .product(name: "Ordinal Primitives", package: "swift-ordinal-primitives"),
                .product(name: "Sequence Primitives", package: "swift-sequence-primitives"),
                .product(name: "Pair Primitives", package: "swift-pair-primitives"),
            ]
        ),
        .target(
            name: "Buffer Slab Small Primitive",
            dependencies: [
                "Buffer Slab Primitive",
                "Buffer Slab Inline Primitive",
                .product(name: "Buffer Primitive", package: "swift-buffer-primitives"),
                .product(name: "Growth Primitives", package: "swift-growth-primitives"),
                .product(name: "Buffer Protocol Primitives", package: "swift-buffer-primitives"),
                .product(name: "Storage Contiguous Primitives", package: "swift-storage-primitives"),
                .product(name: "Storage Contiguous Primitives", package: "swift-storage-primitives"),
                .product(name: "Memory Heap Primitives", package: "swift-memory-heap-primitives"),
                .product(name: "Memory Allocator Primitive", package: "swift-memory-allocation-primitives"),
                .product(name: "Memory Inline Primitives", package: "swift-memory-inline-primitives"),
                .product(name: "Store Initialization Primitives", package: "swift-storage-primitives"),
                .product(name: "Storage Protocol Primitives", package: "swift-storage-primitives"),
                .product(name: "Store Protocol Primitives", package: "swift-storage-primitives"),
                .product(name: "Index Primitives", package: "swift-index-primitives"),
                .product(name: "Finite Bounded Primitives", package: "swift-finite-primitives"),
                .product(name: "Memory Primitives", package: "swift-memory-primitives"),
                .product(name: "Affine Primitives", package: "swift-affine-primitives"),
                .product(name: "Ordinal Primitives", package: "swift-ordinal-primitives"),
                .product(name: "Sequence Primitives", package: "swift-sequence-primitives"),
            ]
        ),

        // MARK: - Ops modules — Copyable-requiring conformances isolated per [MOD-004].
        //         `Buffer Slab Primitives` (the base conformances module) doubles as the
        //         [MOD-005] umbrella: it re-exports every variant module (two module forms only —
        //         `… Primitive` type modules and `… Primitives` ops modules).
        .target(
            name: "Buffer Slab Primitives",
            dependencies: [
                "Buffer Slab Primitive",
                "Buffer Slab Bounded Primitives",
                "Buffer Slab Inline Primitives",
                "Buffer Slab Small Primitives",
                .product(name: "Index Primitives", package: "swift-index-primitives"),
                .product(name: "Memory Primitives", package: "swift-memory-primitives"),
                .product(name: "Sequence Primitives", package: "swift-sequence-primitives"),
                .product(name: "Pair Primitives", package: "swift-pair-primitives"),
            ]
        ),
        .target(
            name: "Buffer Slab Bounded Primitives",
            dependencies: [
                "Buffer Slab Bounded Primitive",
                .product(name: "Index Primitives", package: "swift-index-primitives"),
                .product(name: "Memory Primitives", package: "swift-memory-primitives"),
                .product(name: "Sequence Primitives", package: "swift-sequence-primitives"),
                .product(name: "Pair Primitives", package: "swift-pair-primitives"),
            ]
        ),
        .target(
            name: "Buffer Slab Inline Primitives",
            dependencies: [
                "Buffer Slab Inline Primitive",
                .product(name: "Storage Contiguous Primitives", package: "swift-storage-primitives"),
                .product(name: "Storage Contiguous Primitives", package: "swift-storage-primitives"),
                .product(name: "Memory Heap Primitives", package: "swift-memory-heap-primitives"),
                .product(name: "Memory Inline Primitives", package: "swift-memory-inline-primitives"),
                .product(name: "Index Primitives", package: "swift-index-primitives"),
                .product(name: "Finite Bounded Primitives", package: "swift-finite-primitives"),
                .product(name: "Memory Primitives", package: "swift-memory-primitives"),
                .product(name: "Sequence Primitives", package: "swift-sequence-primitives"),
                .product(name: "Iterable", package: "swift-iterator-primitives"),
                .product(name: "Iterator Chunk Primitives", package: "swift-iterator-primitives"),
                .product(name: "Pair Primitives", package: "swift-pair-primitives"),
            ]
        ),
        .target(
            name: "Buffer Slab Small Primitives",
            dependencies: [
                "Buffer Slab Small Primitive",
                "Buffer Slab Primitive",
                "Buffer Slab Inline Primitives",
                .product(name: "Index Primitives", package: "swift-index-primitives"),
                .product(name: "Memory Primitives", package: "swift-memory-primitives"),
                .product(name: "Sequence Primitives", package: "swift-sequence-primitives"),
            ]
        ),
        // MARK: - Test Support
        .target(
            name: "Buffer Slab Primitives Test Support",
            dependencies: [
                "Buffer Slab Primitives",
                "Buffer Slab Bounded Primitives",
                "Buffer Slab Inline Primitives",
                "Buffer Slab Small Primitives",
                .product(name: "Memory Primitives Test Support", package: "swift-memory-primitives"),
            ],
            path: "Tests/Support"
        ),

        // MARK: - Tests
        .testTarget(
            name: "Buffer Slab Primitives Tests",
            dependencies: ["Buffer Slab Primitives", "Buffer Slab Primitives Test Support", .product(name: "Memory Allocator Primitive", package: "swift-memory-allocation-primitives"), .product(name: "Memory Small Primitives", package: "swift-memory-small-primitives")]
        ),
        .testTarget(
            name: "Buffer Slab Bounded Primitives Tests",
            dependencies: ["Buffer Slab Bounded Primitives", "Buffer Slab Primitives Test Support", .product(name: "Memory Allocator Primitive", package: "swift-memory-allocation-primitives"), .product(name: "Memory Small Primitives", package: "swift-memory-small-primitives")]
        ),
        .testTarget(
            name: "Buffer Slab Inline Primitives Tests",
            dependencies: ["Buffer Slab Inline Primitives", "Buffer Slab Primitives Test Support", .product(name: "Finite Bounded Primitives", package: "swift-finite-primitives"), .product(name: "Memory Allocator Primitive", package: "swift-memory-allocation-primitives"),
                // PROBE-only deps (HANDOFF-sparse-occupancy-placement Step 1): real Store.Inline substrate for the T1 isolation leaf.
                .product(name: "Store Inline Primitives", package: "swift-storage-primitives"),
                .product(name: "Store Initialization Primitives", package: "swift-storage-primitives"),
                .product(name: "Index Primitives", package: "swift-index-primitives")]
        ),
        .testTarget(
            name: "Buffer Slab Small Primitives Tests",
            dependencies: ["Buffer Slab Small Primitives", "Buffer Slab Primitives Test Support", .product(name: "Memory Allocator Primitive", package: "swift-memory-allocation-primitives")]
        ),
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    let ecosystem: [SwiftSetting] = [
        .strictMemorySafety(),
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
        .enableExperimentalFeature("LifetimeDependence"),
        .enableExperimentalFeature("Lifetimes"),
        .enableExperimentalFeature("SuppressedAssociatedTypes"),
        .enableUpcomingFeature("InferIsolatedConformances"),
        .enableUpcomingFeature("LifetimeDependence"),
    ]

    let package: [SwiftSetting] = [
        .enableExperimentalFeature("BuiltinModule"),
        .enableExperimentalFeature("RawLayout"),
    ]

    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem + package
}
