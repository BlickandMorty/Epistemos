//! Source:
//! - `docs/fusion/jordan's research/ternary kernel.md` — canonical
//!   ordering of the 7 J1 kernels + "decode-first invariant" (every
//!   kernel justifies itself against decode performance before
//!   prefill-only optimization is considered).
//! - `docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_B_2026_05_16.md`
//!   §5 J1 row.
//! - Companions: [`super::pack`], [`super::gemv`],
//!   [`super::residual_island`], [`super::fused_rmsnorm`],
//!   [`super::kv_fingerprint`], [`super::activation_tap`],
//!   [`super::steering`].
//!
//! # Wave J1 — Ternary kernel taxonomy
//!
//! The doc comment on `ternary/mod.rs` enumerates the 7 kernels in
//! prose; this file lifts that into a typed enum so the decode-first
//! invariant is enforceable in code.
//!
//! ## Per-token-cost taxonomy
//!
//! | Kernel             | Per-token cost      | Decode-first priority |
//! |--------------------|---------------------|-----------------------|
//! | pack               | one-time (load)     | Critical (warm cache) |
//! | gemv               | every token         | Critical              |
//! | fused_rmsnorm      | every token         | Critical              |
//! | residual_island    | every token         | Critical              |
//! | steering           | every token if on   | Conditional           |
//! | activation_tap     | every token if on   | Conditional           |
//! | kv_fingerprint     | routing-time only   | NonDecode             |
//!
//! `Critical` = hot path; latency/throughput regression is a §10 wind-down trigger.
//! `Conditional` = only active when the corresponding feature flag is on.
//! `NonDecode` = used at prefill / routing / dedup — never blocks the decode path.

use serde::{Deserialize, Serialize};

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize)]
pub enum TernaryKernelKind {
    Pack,
    Gemv,
    FusedRmsnorm,
    ResidualIsland,
    Steering,
    ActivationTap,
    KvFingerprint,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize)]
pub enum DecodePriority {
    Critical,
    Conditional,
    NonDecode,
}

impl TernaryKernelKind {
    pub const ALL: [TernaryKernelKind; 7] = [
        TernaryKernelKind::Pack,
        TernaryKernelKind::Gemv,
        TernaryKernelKind::FusedRmsnorm,
        TernaryKernelKind::ResidualIsland,
        TernaryKernelKind::Steering,
        TernaryKernelKind::ActivationTap,
        TernaryKernelKind::KvFingerprint,
    ];

    pub const fn code(self) -> &'static str {
        match self {
            TernaryKernelKind::Pack => "pack",
            TernaryKernelKind::Gemv => "gemv",
            TernaryKernelKind::FusedRmsnorm => "fused_rmsnorm",
            TernaryKernelKind::ResidualIsland => "residual_island",
            TernaryKernelKind::Steering => "steering",
            TernaryKernelKind::ActivationTap => "activation_tap",
            TernaryKernelKind::KvFingerprint => "kv_fingerprint",
        }
    }

    pub const fn priority(self) -> DecodePriority {
        match self {
            TernaryKernelKind::Pack
            | TernaryKernelKind::Gemv
            | TernaryKernelKind::FusedRmsnorm
            | TernaryKernelKind::ResidualIsland => DecodePriority::Critical,
            TernaryKernelKind::Steering | TernaryKernelKind::ActivationTap => {
                DecodePriority::Conditional
            }
            TernaryKernelKind::KvFingerprint => DecodePriority::NonDecode,
        }
    }

    pub const fn is_on_decode_hot_path(self) -> bool {
        matches!(self.priority(), DecodePriority::Critical | DecodePriority::Conditional)
    }

    /// Reverse lookup for [`Self::code`]. `None` for unknown codes.
    pub fn from_code(code: &str) -> Option<Self> {
        Self::ALL.iter().copied().find(|k| k.code() == code)
    }
}

impl DecodePriority {
    pub const ALL: [DecodePriority; 3] = [
        DecodePriority::Critical,
        DecodePriority::Conditional,
        DecodePriority::NonDecode,
    ];

    pub const fn code(self) -> &'static str {
        match self {
            DecodePriority::Critical => "critical",
            DecodePriority::Conditional => "conditional",
            DecodePriority::NonDecode => "non_decode",
        }
    }

    pub fn from_code(code: &str) -> Option<Self> {
        Self::ALL.iter().copied().find(|p| p.code() == code)
    }

    pub const fn is_critical(self) -> bool {
        matches!(self, DecodePriority::Critical)
    }

    pub const fn is_conditional(self) -> bool {
        matches!(self, DecodePriority::Conditional)
    }

    /// Cross-surface invariant: `is_critical XOR is_conditional XOR
    /// is_non_decode` partitions all variants.
    pub const fn is_non_decode(self) -> bool {
        matches!(self, DecodePriority::NonDecode)
    }
}

impl OptimizationError {
    /// Stable identifier for the failure cause.
    pub const fn cause(&self) -> &'static str {
        match self {
            OptimizationError::PrefillOptimizationOnCriticalKernel { .. } => {
                "prefill_opt_on_critical_kernel"
            }
        }
    }

    /// Kernel whose decode-first invariant was violated.
    pub const fn kernel(&self) -> TernaryKernelKind {
        match self {
            OptimizationError::PrefillOptimizationOnCriticalKernel { kernel } => *kernel,
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum OptimizationError {
    PrefillOptimizationOnCriticalKernel { kernel: TernaryKernelKind },
}

/// Validate a proposed optimization against the decode-first invariant.
/// `targets_prefill_only` is the optimizer's promise that the change
/// is prefill-specific (e.g. a batched-tile rewrite, FlashAttention
/// variant). Per the invariant, no `Critical`-priority kernel may
/// accept a prefill-only optimization until a decode-side win is on
/// record.
pub fn validate_optimization(
    kernel: TernaryKernelKind,
    targets_prefill_only: bool,
) -> Result<(), OptimizationError> {
    if targets_prefill_only && matches!(kernel.priority(), DecodePriority::Critical) {
        return Err(OptimizationError::PrefillOptimizationOnCriticalKernel { kernel });
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn seven_distinct_kernels() {
        let s: std::collections::HashSet<_> = TernaryKernelKind::ALL.iter().copied().collect();
        assert_eq!(s.len(), 7);
    }

    #[test]
    fn priority_partition_four_two_one() {
        let mut critical = 0usize;
        let mut conditional = 0usize;
        let mut non_decode = 0usize;
        for k in TernaryKernelKind::ALL.iter() {
            match k.priority() {
                DecodePriority::Critical => critical += 1,
                DecodePriority::Conditional => conditional += 1,
                DecodePriority::NonDecode => non_decode += 1,
            }
        }
        assert_eq!(critical, 4);
        assert_eq!(conditional, 2);
        assert_eq!(non_decode, 1);
    }

    #[test]
    fn critical_kernels_are_the_four_hot_path() {
        let critical: Vec<_> = TernaryKernelKind::ALL
            .iter()
            .filter(|k| matches!(k.priority(), DecodePriority::Critical))
            .copied()
            .collect();
        assert!(critical.contains(&TernaryKernelKind::Pack));
        assert!(critical.contains(&TernaryKernelKind::Gemv));
        assert!(critical.contains(&TernaryKernelKind::FusedRmsnorm));
        assert!(critical.contains(&TernaryKernelKind::ResidualIsland));
    }

    #[test]
    fn conditional_kernels_are_steering_and_activation_tap() {
        assert_eq!(TernaryKernelKind::Steering.priority(), DecodePriority::Conditional);
        assert_eq!(TernaryKernelKind::ActivationTap.priority(), DecodePriority::Conditional);
    }

    #[test]
    fn kv_fingerprint_is_non_decode() {
        assert_eq!(TernaryKernelKind::KvFingerprint.priority(), DecodePriority::NonDecode);
    }

    #[test]
    fn on_decode_hot_path_excludes_only_non_decode() {
        for k in TernaryKernelKind::ALL.iter() {
            let on_path = k.is_on_decode_hot_path();
            let non_decode = matches!(k.priority(), DecodePriority::NonDecode);
            assert_ne!(on_path, non_decode, "kernel {:?} miscategorized", k);
        }
    }

    #[test]
    fn all_codes_unique() {
        let mut s = std::collections::HashSet::new();
        for k in TernaryKernelKind::ALL.iter() {
            assert!(s.insert(k.code()));
        }
    }

    #[test]
    fn codes_are_snake_case() {
        for k in TernaryKernelKind::ALL.iter() {
            let c = k.code();
            assert!(!c.is_empty());
            assert!(c.chars().all(|ch| ch.is_ascii_lowercase() || ch == '_'));
        }
    }

    #[test]
    fn prefill_opt_on_critical_kernel_rejected() {
        for k in [
            TernaryKernelKind::Pack,
            TernaryKernelKind::Gemv,
            TernaryKernelKind::FusedRmsnorm,
            TernaryKernelKind::ResidualIsland,
        ] {
            assert_eq!(
                validate_optimization(k, true).unwrap_err(),
                OptimizationError::PrefillOptimizationOnCriticalKernel { kernel: k }
            );
        }
    }

    #[test]
    fn prefill_opt_on_conditional_kernel_passes() {
        assert!(validate_optimization(TernaryKernelKind::Steering, true).is_ok());
        assert!(validate_optimization(TernaryKernelKind::ActivationTap, true).is_ok());
    }

    #[test]
    fn prefill_opt_on_non_decode_passes() {
        assert!(validate_optimization(TernaryKernelKind::KvFingerprint, true).is_ok());
    }

    #[test]
    fn decode_opt_on_critical_kernel_passes() {
        for k in TernaryKernelKind::ALL.iter() {
            assert!(validate_optimization(*k, false).is_ok());
        }
    }

    #[test]
    fn kernel_serde_roundtrip() {
        let k = TernaryKernelKind::FusedRmsnorm;
        let json = serde_json::to_string(&k).unwrap();
        let back: TernaryKernelKind = serde_json::from_str(&json).unwrap();
        assert_eq!(k, back);
    }

    #[test]
    fn priority_serde_roundtrip() {
        let p = DecodePriority::Conditional;
        let json = serde_json::to_string(&p).unwrap();
        let back: DecodePriority = serde_json::from_str(&json).unwrap();
        assert_eq!(p, back);
    }

    // ── diagnostic surface (iter 173) ────────────────────────────────────────

    #[test]
    fn kernel_from_code_roundtrips_all() {
        for k in TernaryKernelKind::ALL.iter().copied() {
            assert_eq!(TernaryKernelKind::from_code(k.code()), Some(k));
        }
        assert_eq!(TernaryKernelKind::from_code("Pack"), None);
        assert_eq!(TernaryKernelKind::from_code(""), None);
    }

    #[test]
    fn priority_from_code_roundtrips_all() {
        for p in DecodePriority::ALL.iter().copied() {
            assert_eq!(DecodePriority::from_code(p.code()), Some(p));
        }
    }

    #[test]
    fn priority_classifiers_partition_variants() {
        // Cross-surface invariant: is_critical XOR is_conditional XOR is_non_decode.
        for p in DecodePriority::ALL.iter().copied() {
            let trio = [p.is_critical(), p.is_conditional(), p.is_non_decode()];
            assert_eq!(trio.iter().filter(|x| **x).count(), 1, "{:?}", p);
        }
    }

    #[test]
    fn opt_error_cause_and_kernel_extract() {
        let err = OptimizationError::PrefillOptimizationOnCriticalKernel {
            kernel: TernaryKernelKind::Gemv,
        };
        assert_eq!(err.cause(), "prefill_opt_on_critical_kernel");
        assert_eq!(err.kernel(), TernaryKernelKind::Gemv);
    }

    #[test]
    fn opt_error_kernel_aligned_with_validate_input() {
        // Cross-surface: validate_optimization-returned error carries
        // the kernel it was called with.
        for k in [
            TernaryKernelKind::Pack,
            TernaryKernelKind::Gemv,
            TernaryKernelKind::FusedRmsnorm,
            TernaryKernelKind::ResidualIsland,
        ] {
            let err = validate_optimization(k, true).unwrap_err();
            assert_eq!(err.kernel(), k);
        }
    }
}
