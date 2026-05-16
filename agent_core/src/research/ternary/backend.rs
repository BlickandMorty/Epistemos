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
}
