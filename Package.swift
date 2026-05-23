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
        .library(name: "Buffer Slab Primitive", targets: ["Buffer Slab Primitive"]),
        .library(name: "Buffer Slab Primitives", targets: ["Buffer Slab Primitives"]),
        .library(name: "Buffer Slab Inline Primitives", targets: ["Buffer Slab Inline Primitives"]),
        .library(name: "Buffer Slab Primitives Test Support", targets: ["Buffer Slab Primitives Test Support"]),
    ],
    dependencies: [
        .package(path: "../swift-buffer-primitives"),
        .package(path: "../swift-storage-primitives"),
        .package(path: "../swift-storage-slab-primitives"),
        .package(path: "../swift-bit-vector-primitives"),
        .package(path: "../swift-index-primitives"),
        .package(path: "../swift-affine-primitives"),
        .package(path: "../swift-ordinal-primitives"),
        .package(path: "../swift-memory-primitives"),
        .package(path: "../swift-sequence-primitives"),
    ],
    targets: [
        .target(
            name: "Buffer Slab Primitive",
            dependencies: [
                .product(name: "Buffer Primitive", package: "swift-buffer-primitives"),
                .product(name: "Buffer Growth Primitives", package: "swift-buffer-primitives"),
                .product(name: "Storage Slab Primitives", package: "swift-storage-slab-primitives"),
                .product(name: "Storage Inline Primitives", package: "swift-storage-primitives"),
                .product(name: "Storage Initialization Primitives", package: "swift-storage-primitives"),
                .product(name: "Bit Vector Static Primitives", package: "swift-bit-vector-primitives"),
                .product(name: "Index Primitives", package: "swift-index-primitives"),
                .product(name: "Memory Primitives", package: "swift-memory-primitives"),
                .product(name: "Affine Primitives", package: "swift-affine-primitives"),
                .product(name: "Ordinal Primitives", package: "swift-ordinal-primitives"),
            ]
        ),
        .target(
            name: "Buffer Slab Primitives",
            dependencies: [
                "Buffer Slab Primitive",
                .product(name: "Storage Slab Primitives", package: "swift-storage-slab-primitives"),
                .product(name: "Index Primitives", package: "swift-index-primitives"),
                .product(name: "Memory Primitives", package: "swift-memory-primitives"),
                .product(name: "Sequence Primitives", package: "swift-sequence-primitives"),
            ]
        ),
        .target(
            name: "Buffer Slab Inline Primitives",
            dependencies: [
                "Buffer Slab Primitive",
                "Buffer Slab Primitives",
                .product(name: "Storage Slab Primitives", package: "swift-storage-slab-primitives"),
                .product(name: "Storage Inline Primitives", package: "swift-storage-primitives"),
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
                "Buffer Slab Inline Primitives",
                .product(name: "Memory Primitives Test Support", package: "swift-memory-primitives"),
            ],
            path: "Tests/Support"
        ),

        // MARK: - Tests
        .testTarget(
            name: "Buffer Slab Primitives Tests",
            dependencies: ["Buffer Slab Primitives", "Buffer Slab Primitives Test Support"]
        ),
        .testTarget(
            name: "Buffer Slab Inline Primitives Tests",
            dependencies: ["Buffer Slab Inline Primitives", "Buffer Slab Primitives Test Support"]
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
