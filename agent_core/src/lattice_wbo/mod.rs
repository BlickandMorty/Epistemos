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
    pub const ALL: [Self; 11] = [
        Self::ExactHot,
        Self::LatticeWynerZivResidual,
        Self::SherryTernary3Of4,
        Self::ShadowKvSketch,
        Self::NestedE8,
        Self::NestedLeech24,
        Self::QuipE8,
        Self::Nf4SsdOracle,
        Self::ResidualSketch,
        Self::NetworkCascade,
        Self::SelfEvolvingAdapter,
    ];

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
    pub const ALL: [Self; 9] = [
        Self::None,
        Self::DecoderLmState,
        Self::ResidualStream,
        Self::CalibrationHessian,
        Self::RuntimeKvHessian,
        Self::ActiveSupport,
        Self::SsdOracle,
        Self::NetworkTeacher,
        Self::SurpriseGradient,
    ];

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
    pub const ALL: [Self; 7] = [
        Self::WeightRuntime,
        Self::KvCache,
        Self::ResidualWynerZiv,
        Self::Quantization,
        Self::SubstrateBoundary,
        Self::SelfEvolvingSecurity,
        Self::NumericalPostCorrection,
    ];

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

/// Rate/error budget for one `LatticeCoder<BITS>`-style representation.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct LatticeBudget {
    pub coder: LatticeCoderKind,
    /// Milli-bits per symbol so 1.25 bits can be represented as 1250.
    pub rate_milli_bits_per_symbol: Option<u32>,
    pub side_information: SideInformationKind,
    pub contributions: Vec<LatticeErrorContribution>,
}

impl LatticeBudget {
    pub fn new(
        coder: LatticeCoderKind,
        rate_milli_bits_per_symbol: Option<u32>,
        side_information: SideInformationKind,
        contributions: Vec<LatticeErrorContribution>,
    ) -> Self {
        Self {
            coder,
            rate_milli_bits_per_symbol,
            side_information,
            contributions,
        }
    }

    pub fn pre_softmax_budget(&self) -> f64 {
        self.contributions
            .iter()
            .map(|contribution| contribution.budget)
            .sum()
    }

    pub fn softmax_half_corrected_budget(&self) -> f64 {
        0.5 * self.pre_softmax_budget()
    }
}

/// Budget for the active support selected out of a larger memory tier.
#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct ActiveSupportBudget {
    pub max_active_tokens: u32,
    pub max_active_pages: u32,
    pub max_resident_bytes: u64,
    pub side_information: SideInformationKind,
}

impl ActiveSupportBudget {
    pub const fn new(
        max_active_tokens: u32,
        max_active_pages: u32,
        max_resident_bytes: u64,
        side_information: SideInformationKind,
    ) -> Self {
        Self {
            max_active_tokens,
            max_active_pages,
            max_resident_bytes,
            side_information,
        }
    }

    pub const fn zero(side_information: SideInformationKind) -> Self {
        Self::new(0, 0, 0, side_information)
    }

    pub const fn is_zero(self) -> bool {
        self.max_active_tokens == 0 && self.max_active_pages == 0 && self.max_resident_bytes == 0
    }
}

/// One row in the Lattice-Wyner-Ziv / WBO register.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct WboLedgerEntry {
    pub memory_tier: String,
    pub budget: LatticeBudget,
    pub active_support: Option<ActiveSupportBudget>,
    pub falsifier: String,
    pub caveat: String,
}

impl WboLedgerEntry {
    pub fn new(
        memory_tier: impl Into<String>,
        budget: LatticeBudget,
        active_support: Option<ActiveSupportBudget>,
        falsifier: impl Into<String>,
        caveat: impl Into<String>,
    ) -> Self {
        Self {
            memory_tier: memory_tier.into(),
            budget,
            active_support,
            falsifier: falsifier.into(),
            caveat: caveat.into(),
        }
    }

    pub fn wbo_terms(&self) -> Vec<WboTermCode> {
        let mut terms = Vec::with_capacity(self.budget.contributions.len());
        for contribution in &self.budget.contributions {
            if !terms.contains(&contribution.term) {
                terms.push(contribution.term);
            }
        }
        terms
    }

    pub fn validate(&self) -> Result<(), LatticeWboError> {
        if self.memory_tier.is_empty() {
            return Err(LatticeWboError::EmptyMemoryTier);
        }
        if self.budget.contributions.is_empty() {
            return Err(LatticeWboError::EmptyContributions);
        }
        if self.falsifier.is_empty() {
            return Err(LatticeWboError::EmptyFalsifier);
        }
        if self.caveat.is_empty() {
            return Err(LatticeWboError::EmptyCaveat);
        }
        if self.budget.side_information == SideInformationKind::ActiveSupport {
            match self.active_support {
                Some(active_support) if !active_support.is_zero() => {}
                _ => return Err(LatticeWboError::MissingActiveSupportBudget),
            }
        }
        Ok(())
    }
}

/// Validation failures for ledger-only lattice/WBO structures.
#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub enum LatticeWboError {
    InvalidBudget,
    EmptySource,
    EmptyMemoryTier,
    EmptyContributions,
    EmptyFalsifier,
    EmptyCaveat,
    MissingActiveSupportBudget,
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

    #[test]
    fn lattice_budget_round_trips_json() {
        let contribution =
            LatticeErrorContribution::new(WboTermCode::Quantization, "Sherry residual codec", 0.04)
                .expect("valid contribution");
        let value = LatticeBudget::new(
            LatticeCoderKind::SherryTernary3Of4,
            Some(1250),
            SideInformationKind::ResidualStream,
            vec![contribution],
        );

        let encoded = serde_json::to_string(&value).expect("serialize budget");
        let decoded: LatticeBudget = serde_json::from_str(&encoded).expect("deserialize budget");

        assert_eq!(decoded, value);
        assert_eq!(decoded.pre_softmax_budget(), 0.04);
        assert_eq!(decoded.softmax_half_corrected_budget(), 0.02);
    }

    #[test]
    fn active_support_budget_round_trips_json() {
        let value = ActiveSupportBudget::new(
            4096,
            64,
            256 * 1024 * 1024,
            SideInformationKind::ActiveSupport,
        );

        let encoded = serde_json::to_string(&value).expect("serialize active support budget");
        let decoded: ActiveSupportBudget =
            serde_json::from_str(&encoded).expect("deserialize active support budget");

        assert_eq!(decoded, value);
        assert!(!decoded.is_zero());
        assert!(ActiveSupportBudget::zero(SideInformationKind::None).is_zero());
    }

    #[test]
    fn wbo_ledger_entry_round_trips_json() {
        let contribution =
            LatticeErrorContribution::new(WboTermCode::SubstrateBoundary, "ShadowKV support", 0.01)
                .expect("valid support contribution");
        let budget = LatticeBudget::new(
            LatticeCoderKind::ShadowKvSketch,
            None,
            SideInformationKind::ActiveSupport,
            vec![contribution],
        );
        let support = ActiveSupportBudget::new(
            2048,
            32,
            64 * 1024 * 1024,
            SideInformationKind::ActiveSupport,
        );
        let value = WboLedgerEntry::new(
            "L2 Shadow Sketch",
            budget,
            Some(support),
            "F-WBO-DriftLedger",
            "Active support is accounting metadata, not a speed claim.",
        );

        let encoded = serde_json::to_string(&value).expect("serialize ledger entry");
        let decoded: WboLedgerEntry =
            serde_json::from_str(&encoded).expect("deserialize ledger entry");

        assert_eq!(decoded, value);
        assert_eq!(decoded.wbo_terms(), vec![WboTermCode::SubstrateBoundary]);
    }

    #[test]
    fn typed_catalogs_cover_all_wbo_and_side_information_rows() {
        assert_eq!(
            WboTermCode::ALL.iter().map(|term| term.code()).collect::<Vec<_>>(),
            vec!["T_W", "T_K", "T_R", "T_Q", "T_S", "T_SE", "T_num"]
        );
        assert!(LatticeCoderKind::ALL.contains(&LatticeCoderKind::SherryTernary3Of4));
        assert!(LatticeCoderKind::ALL.contains(&LatticeCoderKind::ShadowKvSketch));
        assert!(LatticeCoderKind::ALL.contains(&LatticeCoderKind::QuipE8));
        assert!(SideInformationKind::ALL.contains(&SideInformationKind::CalibrationHessian));
        assert!(SideInformationKind::ALL.contains(&SideInformationKind::RuntimeKvHessian));
        assert!(SideInformationKind::ALL.contains(&SideInformationKind::ActiveSupport));
    }

    #[test]
    fn ledger_validation_requires_active_support_for_active_support_rows() {
        let contribution =
            LatticeErrorContribution::new(WboTermCode::SubstrateBoundary, "ShadowKV support", 0.01)
                .expect("valid support contribution");
        let budget = LatticeBudget::new(
            LatticeCoderKind::ShadowKvSketch,
            None,
            SideInformationKind::ActiveSupport,
            vec![contribution],
        );
        let missing_support = WboLedgerEntry::new(
            "L2 Shadow Sketch",
            budget,
            None,
            "F-WBO-DriftLedger",
            "Active support must be explicitly budgeted.",
        );

        assert_eq!(
            missing_support.validate(),
            Err(LatticeWboError::MissingActiveSupportBudget)
        );
    }

    #[test]
    fn ledger_validation_rejects_empty_register_fields() {
        let budget = LatticeBudget::new(
            LatticeCoderKind::ExactHot,
            None,
            SideInformationKind::None,
            Vec::new(),
        );
        let empty_tier = WboLedgerEntry::new(
            "",
            budget,
            None,
            "F-WBO-DriftLedger",
            "Exact path still pays numerics.",
        );

        assert_eq!(empty_tier.validate(), Err(LatticeWboError::EmptyMemoryTier));
    }

    #[test]
    fn contribution_budget_rejects_negative_nan_and_infinite_values() {
        for budget in [-0.01, f64::NAN, f64::INFINITY, f64::NEG_INFINITY] {
            assert_eq!(
                LatticeErrorContribution::new(WboTermCode::Quantization, "bad budget", budget),
                Err(LatticeWboError::InvalidBudget)
            );
        }

        let contribution =
            LatticeErrorContribution::new(WboTermCode::Quantization, "finite budget", 1.0)
                .expect("finite budget should be valid");
        assert_eq!(
            contribution.with_measured(f64::NAN),
            Err(LatticeWboError::InvalidBudget)
        );
    }

    #[test]
    fn active_support_budget_preserves_max_values() {
        let value = ActiveSupportBudget::new(
            u32::MAX,
            u32::MAX,
            u64::MAX,
            SideInformationKind::ActiveSupport,
        );
        let encoded = serde_json::to_string(&value).expect("serialize max active support budget");
        let decoded: ActiveSupportBudget =
            serde_json::from_str(&encoded).expect("deserialize max active support budget");

        assert_eq!(decoded, value);
        assert!(!decoded.is_zero());
    }
}
