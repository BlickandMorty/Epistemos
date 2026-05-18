//! Lightweight Lattice-Wyner-Ziv / WBO accounting types.
//!
//! This module is deliberately ledger-only. It names codecs, budgets, side
//! information, and falsifier hooks so callers cannot hide approximation error
//! behind UAS residency or active-support terminology.

use serde::{Deserialize, Serialize};

/// Canonical codec families referenced by the lattice/WBO register.
#[derive(Clone, Copy, Debug, Eq, PartialEq, Hash, Serialize, Deserialize)]
pub enum LatticeCoderKind {
    /// Reference path: exact hot residual/KV state, only numerical drift applies.
    ExactHot,
    /// `LatticeCoder<BITS>` residual stream codec with decoder side information.
    LatticeWynerZivResidual,
    /// Sherry-style 3:4 sparse ternary packing at 1.25 bits per weight/value.
    SherryTernary3Of4,
    /// ShadowKV-style active-support sketching and page selection.
    ShadowKvSketch,
    /// Nested-lattice E8 vector quantization.
    NestedE8,
    /// Nested-lattice Leech_24 vector quantization.
    NestedLeech24,
    /// QuIP / QuIP# rotation-plus-lattice weight quantization.
    QuipE8,
    /// NF4 page representation for mmap/IOSurface SSD oracle paths.
    Nf4SsdOracle,
    /// Residual sketch correction, usually JL/CountSketch/FRP shaped.
    ResidualSketch,
    /// Network fallback or teacher path for outlier queries.
    NetworkCascade,
    /// Titans/SEAL/DoRA style self-evolving adapter state.
    SelfEvolvingAdapter,
}

impl LatticeCoderKind {
    pub const fn canonical_name(self) -> &'static str {
        match self {
            Self::ExactHot => "exact-hot",
            Self::LatticeWynerZivResidual => "lattice-wyner-ziv-residual",
            Self::SherryTernary3Of4 => "sherry-3-of-4-ternary",
            Self::ShadowKvSketch => "shadow-kv-sketch",
            Self::NestedE8 => "nested-e8",
            Self::NestedLeech24 => "nested-leech-24",
            Self::QuipE8 => "quip-e8",
            Self::Nf4SsdOracle => "nf4-ssd-oracle",
            Self::ResidualSketch => "residual-sketch",
            Self::NetworkCascade => "network-cascade",
            Self::SelfEvolvingAdapter => "self-evolving-adapter",
        }
    }
}

/// Decoder side information used by a codec's accounting row.
#[derive(Clone, Copy, Debug, Eq, PartialEq, Hash, Serialize, Deserialize)]
pub enum SideInformationKind {
    /// No side channel beyond the exact live representation.
    None,
    /// Language-model decoder state used by Wyner-Ziv residual coding.
    DecoderLmState,
    /// Residual stream state used to reconstruct K/V or logits.
    ResidualStream,
    /// Offline calibration Hessian for weight quantization.
    CalibrationHessian,
    /// Runtime attention/KV curvature for cache quantization.
    RuntimeKvHessian,
    /// Active support set, page criticality, or retained-token mask.
    ActiveSupport,
    /// Cold exact or higher-fidelity page used as oracle side information.
    SsdOracle,
    /// Network or larger-model teacher used only outside the local hot path.
    NetworkTeacher,
    /// Surprise-gradient state for self-evolving adapter updates.
    SurpriseGradient,
}

impl SideInformationKind {
    pub const fn uses_calibration_hessian(self) -> bool {
        matches!(self, Self::CalibrationHessian)
    }

    pub const fn uses_runtime_kv_hessian(self) -> bool {
        matches!(self, Self::RuntimeKvHessian)
    }
}

/// Register-local WBO term codes, including `T_num` for numerical correction.
#[derive(Clone, Copy, Debug, Eq, PartialEq, Hash, Serialize, Deserialize)]
pub enum WboTermCode {
    /// `T_W` - weight/runtime perturbation.
    WeightRuntime,
    /// `T_K` - KV/cache compression and restore.
    KvCache,
    /// `T_R` - residual Wyner-Ziv / reconstruction gap in this register lane.
    ResidualWynerZiv,
    /// `T_Q` - quantization approximation.
    Quantization,
    /// `T_S` - substrate/active-support boundary.
    SubstrateBoundary,
    /// `T_SE` - self-evolving or sovereign/security enforcement.
    SelfEvolvingSecurity,
    /// `T_num` - numerical post-correction guard before softmax-1/2.
    NumericalPostCorrection,
}

impl WboTermCode {
    pub const fn code(self) -> &'static str {
        match self {
            Self::WeightRuntime => "T_W",
            Self::KvCache => "T_K",
            Self::ResidualWynerZiv => "T_R",
            Self::Quantization => "T_Q",
            Self::SubstrateBoundary => "T_S",
            Self::SelfEvolvingSecurity => "T_SE",
            Self::NumericalPostCorrection => "T_num",
        }
    }
}

/// A measured or reserved contribution to the lattice/WBO ledger.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct LatticeErrorContribution {
    pub term: WboTermCode,
    pub source: String,
    pub budget: f64,
    pub measured: Option<f64>,
}

impl LatticeErrorContribution {
    pub fn new(
        term: WboTermCode,
        source: impl Into<String>,
        budget: f64,
    ) -> Result<Self, LatticeWboError> {
        validate_nonnegative_finite(budget)?;
        let source = source.into();
        if source.is_empty() {
            return Err(LatticeWboError::EmptySource);
        }
        Ok(Self {
            term,
            source,
            budget,
            measured: None,
        })
    }

    pub fn with_measured(mut self, measured: f64) -> Result<Self, LatticeWboError> {
        validate_nonnegative_finite(measured)?;
        self.measured = Some(measured);
        Ok(self)
    }
}

/// Validation failures for ledger-only lattice/WBO structures.
#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub enum LatticeWboError {
    InvalidBudget,
    EmptySource,
}

fn validate_nonnegative_finite(value: f64) -> Result<(), LatticeWboError> {
    if value.is_finite() && value >= 0.0 {
        Ok(())
    } else {
        Err(LatticeWboError::InvalidBudget)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn lattice_coder_kind_round_trips_json() {
        let value = LatticeCoderKind::LatticeWynerZivResidual;
        let encoded = serde_json::to_string(&value).expect("serialize lattice coder kind");
        let decoded: LatticeCoderKind =
            serde_json::from_str(&encoded).expect("deserialize lattice coder kind");

        assert_eq!(decoded, value);
        assert_eq!(decoded.canonical_name(), "lattice-wyner-ziv-residual");
    }

    #[test]
    fn side_information_kind_keeps_hessian_domains_separate() {
        let weight = SideInformationKind::CalibrationHessian;
        let kv = SideInformationKind::RuntimeKvHessian;

        let encoded = serde_json::to_string(&[weight, kv]).expect("serialize side information");
        let decoded: [SideInformationKind; 2] =
            serde_json::from_str(&encoded).expect("deserialize side information");

        assert!(decoded[0].uses_calibration_hessian());
        assert!(!decoded[0].uses_runtime_kv_hessian());
        assert!(decoded[1].uses_runtime_kv_hessian());
        assert!(!decoded[1].uses_calibration_hessian());
    }

    #[test]
    fn lattice_error_contribution_round_trips_json() {
        let value =
            LatticeErrorContribution::new(WboTermCode::ResidualWynerZiv, "L1 residual gap", 0.05)
                .expect("valid residual contribution")
                .with_measured(0.02)
                .expect("valid measured contribution");

        let encoded = serde_json::to_string(&value).expect("serialize contribution");
        let decoded: LatticeErrorContribution =
            serde_json::from_str(&encoded).expect("deserialize contribution");

        assert_eq!(decoded, value);
        assert_eq!(decoded.term.code(), "T_R");
    }
}
