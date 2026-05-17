//! Source: `docs/fusion/jordan's research/ternary kernel.md` §"What I would
//! actually build" — three-backend research lane (dense baseline · BitNet
//! reference · custom Metal). Each backend implements [`TernaryBackend`]
//! so a single experiment can A/B/C the same decode path against all three.
//!
//! Concrete decode kernels (block-scaled GEMV, fused projection + residual
//! island, RMSNorm fusion, KV fingerprint, activation tap, steering delta)
//! land in sibling submodules in subsequent Wave J1 iterations.

use serde::{Deserialize, Serialize};

/// Identifies which backend is answering a [`TernaryBackend`] call.
/// Used by the control room to label measurements and by A/B/C harnesses
/// to route the same input through each lane.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum BackendKind {
    /// MLX dense fp16/bf16 reference — gold-standard baseline. Lets the
    /// research lane compare quality, latency, and memory against a
    /// known-good dense runtime.
    DenseMlx,
    /// Official BitNet / `bitnet.cpp` external truth source. Validates
    /// the in-tree ternary path against the upstream reference behavior.
    BitnetReference,
    /// In-tree custom Metal lane. Where packed-trit kernels, residual
    /// islands, and the live control room live.
    TernaryMetal,
}

impl BackendKind {
    pub const ALL: [BackendKind; 3] = [
        BackendKind::DenseMlx,
        BackendKind::BitnetReference,
        BackendKind::TernaryMetal,
    ];

    pub const fn code(self) -> &'static str {
        match self {
            BackendKind::DenseMlx => "dense_mlx",
            BackendKind::BitnetReference => "bitnet_reference",
            BackendKind::TernaryMetal => "ternary_metal",
        }
    }

    /// Reverse lookup for [`Self::code`]. `None` for unknown codes.
    pub fn from_code(code: &str) -> Option<Self> {
        Self::ALL.iter().copied().find(|b| b.code() == code)
    }

    /// Predicate: this backend is a reference / baseline lane
    /// (DenseMlx or BitnetReference — used to validate the in-tree
    /// path against). Cross-surface invariant: `is_reference_lane
    /// XOR is_in_tree` partitions all variants.
    pub const fn is_reference_lane(self) -> bool {
        matches!(self, BackendKind::DenseMlx | BackendKind::BitnetReference)
    }

    /// Predicate: this backend is the in-tree custom Metal lane —
    /// the one where packed-trit kernels, residual islands, and the
    /// live control room live.
    pub const fn is_in_tree(self) -> bool {
        matches!(self, BackendKind::TernaryMetal)
    }

    /// Predicate: this backend depends on an external binary
    /// (BitnetReference uses `bitnet.cpp`). The DenseMlx baseline
    /// runs via the MLX shim but isn't a separate process; in-tree
    /// custom Metal is purely native. Used by host-availability checks.
    pub const fn is_external_binary(self) -> bool {
        matches!(self, BackendKind::BitnetReference)
    }
}

/// Find the first backend in `backends` that reports
/// `is_available() == true`. Returns its [`BackendKind`] or `None`
/// if every backend is unavailable. Used by the A/B/C harness's
/// "what can we actually run today?" dispatch.
pub fn first_available_kind(backends: &[&dyn TernaryBackend]) -> Option<BackendKind> {
    backends.iter().find(|b| b.is_available()).map(|b| b.kind())
}

/// Static facts a backend reports about itself. Carrier surface for the
/// substrate floor — concrete decode methods (GEMV, fused projection, …)
/// extend this trait in follow-up iterations.
pub trait TernaryBackend {
    fn kind(&self) -> BackendKind;

    /// Whether this backend can execute on the current host today. Used
    /// by the lane runner to skip MLX on hosts without MLX, BitNet on
    /// hosts without the reference binary, etc.
    fn is_available(&self) -> bool;
}

/// Placeholder MLX dense baseline. `is_available` returns `false` until
/// the MLX shim lands in a subsequent Wave J1 iteration.
#[derive(Debug, Default)]
pub struct DenseMlxBackend;

impl TernaryBackend for DenseMlxBackend {
    fn kind(&self) -> BackendKind {
        BackendKind::DenseMlx
    }
    fn is_available(&self) -> bool {
        false
    }
}

/// Placeholder BitNet reference. `is_available` returns `false` until the
/// `bitnet.cpp` shim lands in a subsequent Wave J1 iteration.
#[derive(Debug, Default)]
pub struct BitnetReferenceBackend;

impl TernaryBackend for BitnetReferenceBackend {
    fn kind(&self) -> BackendKind {
        BackendKind::BitnetReference
    }
    fn is_available(&self) -> bool {
        false
    }
}

/// Placeholder custom Metal lane. `is_available` returns `false` until the
/// first packed-trit GEMV kernel lands.
#[derive(Debug, Default)]
pub struct TernaryMetalBackend;

impl TernaryBackend for TernaryMetalBackend {
    fn kind(&self) -> BackendKind {
        BackendKind::TernaryMetal
    }
    fn is_available(&self) -> bool {
        false
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn three_distinct_backend_kinds() {
        let kinds: std::collections::HashSet<_> = BackendKind::ALL.iter().copied().collect();
        assert_eq!(kinds.len(), 3);
    }

    #[test]
    fn each_backend_reports_its_own_kind() {
        assert_eq!(DenseMlxBackend.kind(), BackendKind::DenseMlx);
        assert_eq!(BitnetReferenceBackend.kind(), BackendKind::BitnetReference);
        assert_eq!(TernaryMetalBackend.kind(), BackendKind::TernaryMetal);
    }

    #[test]
    fn substrate_floor_marks_all_backends_unavailable() {
        assert!(!DenseMlxBackend.is_available());
        assert!(!BitnetReferenceBackend.is_available());
        assert!(!TernaryMetalBackend.is_available());
    }

    #[test]
    fn codes_are_stable_strings() {
        assert_eq!(BackendKind::DenseMlx.code(), "dense_mlx");
        assert_eq!(BackendKind::BitnetReference.code(), "bitnet_reference");
        assert_eq!(BackendKind::TernaryMetal.code(), "ternary_metal");
    }

    // ── diagnostic surface (iter 174) ────────────────────────────────────────

    #[test]
    fn from_code_roundtrips_all() {
        for b in BackendKind::ALL.iter().copied() {
            assert_eq!(BackendKind::from_code(b.code()), Some(b));
        }
        assert_eq!(BackendKind::from_code("DenseMlx"), None);
        assert_eq!(BackendKind::from_code(""), None);
    }

    #[test]
    fn reference_lane_and_in_tree_partition() {
        // Cross-surface invariant: is_reference_lane XOR is_in_tree.
        for b in BackendKind::ALL.iter().copied() {
            assert_ne!(b.is_reference_lane(), b.is_in_tree());
        }
        // 2 reference lanes + 1 in-tree.
        assert_eq!(
            BackendKind::ALL.iter().filter(|b| b.is_reference_lane()).count(),
            2,
        );
        assert_eq!(
            BackendKind::ALL.iter().filter(|b| b.is_in_tree()).count(),
            1,
        );
    }

    #[test]
    fn external_binary_only_for_bitnet_reference() {
        for b in BackendKind::ALL.iter().copied() {
            assert_eq!(b.is_external_binary(), b == BackendKind::BitnetReference);
        }
    }

    #[test]
    fn first_available_kind_returns_none_when_all_unavailable() {
        // Substrate-floor placeholders all return false.
        let a = DenseMlxBackend;
        let b = BitnetReferenceBackend;
        let c = TernaryMetalBackend;
        let backends: Vec<&dyn TernaryBackend> = vec![&a, &b, &c];
        assert_eq!(first_available_kind(&backends), None);
    }

    #[test]
    fn first_available_kind_picks_first_available_in_order() {
        // Build a stub TernaryBackend whose is_available is configurable.
        struct Stub(BackendKind, bool);
        impl TernaryBackend for Stub {
            fn kind(&self) -> BackendKind {
                self.0
            }
            fn is_available(&self) -> bool {
                self.1
            }
        }
        let a = Stub(BackendKind::DenseMlx, false);
        let b = Stub(BackendKind::BitnetReference, true);
        let c = Stub(BackendKind::TernaryMetal, true);
        let backends: Vec<&dyn TernaryBackend> = vec![&a, &b, &c];
        assert_eq!(first_available_kind(&backends), Some(BackendKind::BitnetReference));
        // Reorder: c first → c wins.
        let backends: Vec<&dyn TernaryBackend> = vec![&c, &a, &b];
        assert_eq!(first_available_kind(&backends), Some(BackendKind::TernaryMetal));
    }

    #[test]
    fn first_available_empty_returns_none() {
        let backends: Vec<&dyn TernaryBackend> = vec![];
        assert_eq!(first_available_kind(&backends), None);
    }
}
