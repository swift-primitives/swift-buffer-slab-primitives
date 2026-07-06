// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-primitives open source project
//
// Copyright (c) 2024-2026 Coen ten Thije Boonkkamp and the swift-primitives project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

public import Buffer_Protocol_Primitives

// MARK: - Buffer.Protocol Conformance (Slab.Small, sparse / bitmap-domain count)

/// `Buffer.Slab.Small` is a `Buffer.Protocol` capability conformer.
///
/// A slab's native ledger counts occupied bitmap slots (`occupancy`, a
/// `Bit.Index.Count`); M7 re-tags that into the concrete element-domain
/// `Index<Element>.Count` at the `count` witness in
/// `Buffer.Slab.Small+Operations.swift` (one occupied slot IS one live element).
/// The slab supplies its own `isEmpty`.
///
/// This is the LOGICAL capability surface only — iteration is orthogonal and NOT
/// part of this conformance. The banked `where S: ~Copyable` conformance is
/// preserved.
extension Buffer.Slab.Small: Buffer.`Protocol` where S: ~Copyable {
    /// The substrate's element type.
    ///
    /// M7: `count` is the concrete `Index<Element>.Count`, re-tagged from the
    /// bitmap-domain `occupancy`; the former `Count` associated type is gone.
    public typealias Element = S.Element
}
