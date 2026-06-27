extension Buffer.Slab where S: ~Copyable {
    // MARK: - Small (Inline with Heap Spill)

    // CONVERGED-EQUILIBRIUM EXCEPTION (permanent-but-removable; §C.3 hard-floor KEEP).
    // This concrete `.Small` (inline ⊕ heap-spill) variant is a KEPT exception to the tower's
    // "compose the Memory leaves, zero structural carve-outs" mandate: its INLINE arm is the
    // sparse + inline + move-only corner that cannot go pure-generic — a conditionally-`Copyable`
    // generic buffer cannot host the buffer-level `deinit` its sparse occupancy teardown needs
    // (SE-0427 `deinit ⟹ unconditionally ~Copyable`; "Wall 1"). The heap-spill arm tears down via
    // Memory.Heap's class `deinit` (unaffected). Converged design equilibrium (Apple's `Box`;
    // Rust's hoist-the-bound), NOT workaround debt.
    // REMOVAL GATE: dissolve to the pure-generic spelling if/when Swift gains a conditional
    //   `deinit` for `~Copyable` (LOW horizon). REFS: Research/
    //   conditional-deinit-conditionally-copyable-generics.md; package-map §C.3 / [MOD-PLACE];
    //   swift-compiler-bug-catalog.md §A14 + swiftlang/swift#86652 (Wall 2 cross-package teardown).
    /// A slab buffer that starts with inline bitmap and storage, spilling
    /// to heap-allocated storage when the inline capacity is exceeded.
    ///
    /// Uses the two-field storage pattern per
    /// Research/small-buffer-storage-representation.md.
    @frozen
    public struct Small<let inlineCapacity: Int>: ~Copyable {
        @usableFromInline
        internal var _storage: _Representation

        // [PATTERN-052] left: `package init` is blocked because the parameter type
        // `_Representation` is `@usableFromInline internal` (load-bearing per [MOD-036],
        // referenced from `@inlinable` cross-module ops). Widening `_Representation` to
        // `package` breaks those `@inlinable` case references; `@usableFromInline` is
        // rejected on an `@inlinable init`. `package` is insufficient — left per brief.
        @inlinable
        internal init(_storage: consuming _Representation) {
            self._storage = _storage
        }

        // No explicit deinit needed:
        // Enum destroys only the active case:
        // - .inline: Slab.Inline's deinit handles bitmap-driven cleanup
        // - .heap: Slab's deinit handles heap element cleanup
    }
}

extension Buffer.Slab.Small where S: ~Copyable {
    // Enum storage (see Buffer.Ring.Small for full rationale).
    // refined-C ([MOD-036]): `@usableFromInline internal` (was `package`) so the co-located
    // hot ops that switch on `_storage` stay cross-package inlinable. Small carries no
    // Copyable-imposing conformance, so no cross-module ops module reaches these.
    @frozen @usableFromInline
    internal enum _Representation: ~Copyable {
        case inline(Buffer.Slab.Inline<inlineCapacity>)
        case heap(Buffer.Slab)
    }
}

// Copyable suppressed per INV-INLINE-004a (contains Inline).
// extension Buffer.Slab.Small: Copyable where S: Copyable {}
/// Sendable conformance for `Buffer.Slab.Small._Representation`.
///
/// ## Safety Invariant
///
/// `~Copyable` enum payload — either inline or heap variant. Single ownership
/// enforced; cross-thread transfer is a move.
///
/// ## Intended Use
///
/// - Internal storage representation for `Buffer.Slab.Small`.
///
/// ## Non-Goals
///
/// - Not for direct use; package-scoped.
extension Buffer.Slab.Small._Representation: @unsafe @unchecked Sendable where S: ~Copyable, S: Sendable, S.Element: Sendable {}
extension Buffer.Slab.Small: Sendable where S: ~Copyable, S: Sendable, S.Element: Sendable {}
