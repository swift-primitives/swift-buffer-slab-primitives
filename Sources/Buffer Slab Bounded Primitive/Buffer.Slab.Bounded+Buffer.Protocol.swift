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

// MARK: - Buffer.Protocol Conformance (Slab.Bounded, sparse / bitmap-domain count)

/// `Buffer.Slab.Bounded` is a `Buffer.Protocol` capability conformer.
///
/// A slab counts in the bitmap (slot) domain, so its `Count` associated type is
/// `Bit.Index.Count` (inferred from the `count` witness in
/// `Buffer.Slab.Bounded+Operations.swift`), overriding the protocol's element-domain
/// default. `count` equals the live-element cardinality (`occupancy`); the slab
/// supplies its own `isEmpty`.
///
/// This is the LOGICAL capability surface only — iteration is orthogonal and NOT
/// part of this conformance. The banked `where S: ~Copyable` conformance is
/// preserved.
extension Buffer.Slab.Bounded: Buffer.`Protocol` where S: ~Copyable {
    // The count witness (`Bit.Index.Count`) does not mention `Element`, so pin
    // both associated types explicitly.
    /// The substrate's element type.
    public typealias Element = S.Element

    /// The slab count type, in the bitmap (slot) domain.
    public typealias Count = Bit.Index.Count
}
