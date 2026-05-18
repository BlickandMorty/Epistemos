//! Lightweight Lattice-Wyner-Ziv / WBO accounting types.
//!
//! This module is deliberately ledger-only. It names codecs, budgets, side
//! information, and falsifier hooks so callers cannot hide approximation error
//! behind UAS residency or active-support terminology.

use serde::{Deserialize, Serialize};

/// Canonical residency tiers named by the lattice/WBO register.
#[derive(Clone, Copy, Debug, Eq, PartialEq, Hash, Serialize, Deserialize)]
pub enum ResidencyTier {
    L0RamHot,
    L1CompressedResidual,
    L2ShadowSketch,
    L3SsdOracle,
    L4Engram,
    L5NetworkCascade,
    LSeSelfEvolving,
}

impl ResidencyTier {
    pub const ALL: [Self; 7] = [
        Self::L0RamHot,
        Self::L1CompressedResidual,
        Self::L2ShadowSketch,
        Self::L3SsdOracle,
        Self::L4Engram,
        Self::L5NetworkCascade,
        Self::LSeSelfEvolving,
    ];

    pub const fn canonical_name(self) -> &'static str {
        match self {
            Self::L0RamHot => "L0 RAM hot",
            Self::L1CompressedResidual => "L1 Compressed Residual",
            Self::L2ShadowSketch => "L2 Shadow Sketch",
            Self::L3SsdOracle => "L3 SSD Oracle",
            Self::L4Engram => "L4 Engram",
            Self::L5NetworkCascade => "L5 Network Cascade",
            Self::LSeSelfEvolving => "L_SE Self-Evolving",
        }
    }

    pub fn from_canonical_name(name: &str) -> Option<Self> {
        Self::ALL
            .iter()
            .copied()
            .find(|tier| tier.canonical_name() == name)
    }

    pub const fn primary_coder(self) -> LatticeCoderKind {
        match self {
            Self::L0RamHot => LatticeCoderKind::ExactHot,
            Self::L1CompressedResidual => LatticeCoderKind::LatticeWynerZivResidual,
            Self::L2ShadowSketch => LatticeCoderKind::ShadowKvSketch,
            Self::L3SsdOracle => LatticeCoderKind::Nf4SsdOracle,
            Self::L4Engram => LatticeCoderKind::EngramHashRecall,
            Self::L5NetworkCascade => LatticeCoderKind::NetworkCascade,
            Self::LSeSelfEvolving => LatticeCoderKind::SelfEvolvingAdapter,
        }
    }

    pub const fn primary_rate_milli_bits_per_symbol(self) -> Option<u32> {
        match self {
            Self::L1CompressedResidual => Some(1250),
            Self::L3SsdOracle => Some(4000),
            _ => None,
        }
    }

    pub const fn primary_side_information(self) -> SideInformationKind {
        match self {
            Self::L0RamHot => SideInformationKind::None,
            Self::L1CompressedResidual => SideInformationKind::ResidualStream,
            Self::L2ShadowSketch => SideInformationKind::ActiveSupport,
            Self::L3SsdOracle => SideInformationKind::SsdOracle,
            Self::L4Engram => SideInformationKind::StaticFactKey,
            Self::L5NetworkCascade => SideInformationKind::NetworkTeacher,
            Self::LSeSelfEvolving => SideInformationKind::SurpriseGradient,
        }
    }

    pub const fn side_information_witnesses(self) -> &'static [SideInformationKind] {
        match self {
            Self::L0RamHot => &[SideInformationKind::None],
            Self::L1CompressedResidual => &[
                SideInformationKind::ResidualStream,
                SideInformationKind::DecoderLmState,
            ],
            Self::L2ShadowSketch => &[SideInformationKind::ActiveSupport],
            Self::L3SsdOracle => &[
                SideInformationKind::SsdOracle,
                SideInformationKind::ResidualStream,
            ],
            Self::L4Engram => &[SideInformationKind::StaticFactKey],
            Self::L5NetworkCascade => &[SideInformationKind::NetworkTeacher],
            Self::LSeSelfEvolving => &[SideInformationKind::SurpriseGradient],
        }
    }

    pub const fn primary_falsifier(self) -> &'static str {
        self.primary_coder().falsifier()
    }

    pub const fn allows_active_support_budget(self) -> bool {
        matches!(self, Self::L2ShadowSketch | Self::L3SsdOracle)
    }

    pub const fn canonical_register_terms(self) -> &'static [WboTermCode] {
        match self {
            Self::L0RamHot => &[WboTermCode::NumericalPostCorrection],
            Self::L1CompressedResidual => &[
                WboTermCode::ResidualWynerZiv,
                WboTermCode::Quantization,
                WboTermCode::NumericalPostCorrection,
            ],
            Self::L2ShadowSketch => &[
                WboTermCode::KvCache,
                WboTermCode::SubstrateBoundary,
                WboTermCode::NumericalPostCorrection,
            ],
            Self::L3SsdOracle => &[
                WboTermCode::KvCache,
                WboTermCode::Quantization,
                WboTermCode::SubstrateBoundary,
                WboTermCode::NumericalPostCorrection,
            ],
            Self::L4Engram => &[
                WboTermCode::SubstrateBoundary,
                WboTermCode::NumericalPostCorrection,
            ],
            Self::L5NetworkCascade => &[
                WboTermCode::SubstrateBoundary,
                WboTermCode::SelfEvolvingSecurity,
                WboTermCode::NumericalPostCorrection,
            ],
            Self::LSeSelfEvolving => &[
                WboTermCode::WeightRuntime,
                WboTermCode::SelfEvolvingSecurity,
                WboTermCode::NumericalPostCorrection,
            ],
        }
    }
}

/// Canonical codec families referenced by the lattice/WBO register.
#[derive(Clone, Copy, Debug, Eq, PartialEq, Hash, Serialize, Deserialize)]
pub enum LatticeCoderKind {
    /// Reference path: exact hot residual/KV state, only numerical drift applies.
    ExactHot,
    /// `LatticeCoder<BITS>` residual stream codec with decoder side information.
    LatticeWynerZivResidual,
    /// Babai/GPTQ nearest-plane weight quantization in calibration-Hessian geometry.
    BabaiGptqNearestPlane,
    /// Sherry-style 3:4 sparse ternary packing at 1.25 bits per weight.
    SherryTernary3Of4,
    /// ShadowKV-style active-support sketching and page selection.
    ShadowKvSketch,
    /// Fixed-budget hash/static-fact recall with provenance edge witness.
    EngramHashRecall,
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
    pub const ALL: [Self; 13] = [
        Self::ExactHot,
        Self::LatticeWynerZivResidual,
        Self::BabaiGptqNearestPlane,
        Self::SherryTernary3Of4,
        Self::ShadowKvSketch,
        Self::EngramHashRecall,
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
            Self::BabaiGptqNearestPlane => "babai-gptq-nearest-plane",
            Self::SherryTernary3Of4 => "sherry-3-of-4-ternary",
            Self::ShadowKvSketch => "shadow-kv-sketch",
            Self::EngramHashRecall => "engram-hash-recall",
            Self::NestedE8 => "nested-e8",
            Self::NestedLeech24 => "nested-leech-24",
            Self::QuipE8 => "quip-e8",
            Self::Nf4SsdOracle => "nf4-ssd-oracle",
            Self::ResidualSketch => "residual-sketch",
            Self::NetworkCascade => "network-cascade",
            Self::SelfEvolvingAdapter => "self-evolving-adapter",
        }
    }

    pub const fn allows_rate_parameter(self) -> bool {
        matches!(
            self,
            Self::LatticeWynerZivResidual
                | Self::SherryTernary3Of4
                | Self::NestedE8
                | Self::NestedLeech24
                | Self::QuipE8
                | Self::Nf4SsdOracle
                | Self::ResidualSketch
        )
    }

    pub const fn falsifier(self) -> &'static str {
        match self {
            Self::ExactHot => "F-WBO-DriftLedger; F-ULP-Oracle",
            Self::LatticeWynerZivResidual => {
                "F-WBO-DriftLedger; F-ULP-Oracle; residual KL slice; layerwise reconstruction/logit drift witness; F-ACS-AnchorLookup"
            }
            Self::BabaiGptqNearestPlane => {
                "F-WBO-DriftLedger; F-ULP-Oracle; layerwise reconstruction/logit drift witness"
            }
            Self::SherryTernary3Of4 => {
                "F-WBO-DriftLedger; F-ULP-Oracle; layerwise reconstruction/logit drift witness"
            }
            Self::ShadowKvSketch => {
                "F-WBO-DriftLedger; F-ULP-Oracle; F-KV-Direct-Gate; F-ACS-AnchorLookup"
            }
            Self::EngramHashRecall => "F-ACS-AnchorLookup; F-ULP-Oracle; F-WBO-DriftLedger",
            Self::NestedE8 => {
                "F-WBO-DriftLedger; F-ULP-Oracle; layerwise reconstruction/logit drift witness"
            }
            Self::NestedLeech24 => {
                "F-WBO-DriftLedger; F-ULP-Oracle; layerwise reconstruction/logit drift witness"
            }
            Self::QuipE8 => {
                "F-WBO-DriftLedger; F-ULP-Oracle; layerwise reconstruction/logit drift witness"
            }
            Self::Nf4SsdOracle => {
                "F-KV-Direct-Gate; F-ULP-Oracle; F-WBO-DriftLedger; layerwise reconstruction/logit drift witness; F-ACS-AnchorLookup"
            }
            Self::ResidualSketch => {
                "F-WBO-DriftLedger; F-ULP-Oracle; tier-specific reconstruction witness; F-ACS-AnchorLookup"
            }
            Self::NetworkCascade => {
                "provider/provenance replay; F-ULP-Oracle; F-WBO-DriftLedger; F-ACS-AnchorLookup"
            }
            Self::SelfEvolvingAdapter => {
                "adapter replay/provenance verifier; F-ULP-Oracle; F-WBO-DriftLedger; layerwise reconstruction/logit drift witness"
            }
        }
    }

    pub fn canonical_wbo_terms(self) -> &'static [WboTermCode] {
        match self {
            Self::ExactHot => &[WboTermCode::NumericalPostCorrection],
            Self::LatticeWynerZivResidual => &[
                WboTermCode::KvCache,
                WboTermCode::ResidualWynerZiv,
                WboTermCode::Quantization,
                WboTermCode::SubstrateBoundary,
                WboTermCode::NumericalPostCorrection,
            ],
            Self::BabaiGptqNearestPlane => &[
                WboTermCode::WeightRuntime,
                WboTermCode::NumericalPostCorrection,
            ],
            Self::SherryTernary3Of4 => &[
                WboTermCode::WeightRuntime,
                WboTermCode::Quantization,
                WboTermCode::NumericalPostCorrection,
            ],
            Self::ShadowKvSketch => &[
                WboTermCode::KvCache,
                WboTermCode::SubstrateBoundary,
                WboTermCode::NumericalPostCorrection,
            ],
            Self::EngramHashRecall => &[
                WboTermCode::SubstrateBoundary,
                WboTermCode::NumericalPostCorrection,
            ],
            Self::NestedE8 | Self::NestedLeech24 | Self::QuipE8 => &[
                WboTermCode::WeightRuntime,
                WboTermCode::Quantization,
                WboTermCode::NumericalPostCorrection,
            ],
            Self::Nf4SsdOracle => &[
                WboTermCode::KvCache,
                WboTermCode::Quantization,
                WboTermCode::SubstrateBoundary,
                WboTermCode::NumericalPostCorrection,
            ],
            Self::ResidualSketch => &[
                WboTermCode::ResidualWynerZiv,
                WboTermCode::Quantization,
                WboTermCode::SubstrateBoundary,
                WboTermCode::NumericalPostCorrection,
            ],
            Self::NetworkCascade => &[
                WboTermCode::SubstrateBoundary,
                WboTermCode::SelfEvolvingSecurity,
                WboTermCode::NumericalPostCorrection,
            ],
            Self::SelfEvolvingAdapter => &[
                WboTermCode::WeightRuntime,
                WboTermCode::SelfEvolvingSecurity,
                WboTermCode::NumericalPostCorrection,
            ],
        }
    }

    pub fn canonical_side_information(self) -> &'static [SideInformationKind] {
        match self {
            Self::ExactHot => &[SideInformationKind::None],
            Self::LatticeWynerZivResidual => &[
                SideInformationKind::DecoderLmState,
                SideInformationKind::ResidualStream,
                SideInformationKind::ActiveSupport,
                SideInformationKind::SsdOracle,
            ],
            Self::BabaiGptqNearestPlane => &[SideInformationKind::CalibrationHessian],
            Self::SherryTernary3Of4 => &[SideInformationKind::CalibrationHessian],
            Self::ShadowKvSketch => &[
                SideInformationKind::RuntimeKvHessian,
                SideInformationKind::ActiveSupport,
                SideInformationKind::ResidualStream,
            ],
            Self::EngramHashRecall => &[SideInformationKind::StaticFactKey],
            Self::NestedE8 | Self::NestedLeech24 | Self::QuipE8 => {
                &[SideInformationKind::CalibrationHessian]
            }
            Self::Nf4SsdOracle => &[
                SideInformationKind::SsdOracle,
                SideInformationKind::RuntimeKvHessian,
                SideInformationKind::ResidualStream,
            ],
            Self::ResidualSketch => &[
                SideInformationKind::ResidualStream,
                SideInformationKind::DecoderLmState,
                SideInformationKind::ActiveSupport,
            ],
            Self::NetworkCascade => &[SideInformationKind::NetworkTeacher],
            Self::SelfEvolvingAdapter => &[SideInformationKind::SurpriseGradient],
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
    /// Static fact key, content hash, or provenance edge used by Engram recall.
    StaticFactKey,
    /// Network or larger-model teacher used only outside the local hot path.
    NetworkTeacher,
    /// Surprise-gradient state for self-evolving adapter updates.
    SurpriseGradient,
}

impl SideInformationKind {
    pub const ALL: [Self; 10] = [
        Self::None,
        Self::DecoderLmState,
        Self::ResidualStream,
        Self::CalibrationHessian,
        Self::RuntimeKvHessian,
        Self::ActiveSupport,
        Self::SsdOracle,
        Self::StaticFactKey,
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

    pub const SEMANTIC_WBO6: [Self; 6] = [
        Self::WeightRuntime,
        Self::KvCache,
        Self::ResidualWynerZiv,
        Self::Quantization,
        Self::SubstrateBoundary,
        Self::SelfEvolvingSecurity,
    ];

    pub const fn is_semantic_wbo6(self) -> bool {
        !matches!(self, Self::NumericalPostCorrection)
    }

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

    pub const fn obligation(self) -> &'static str {
        match self {
            Self::WeightRuntime => "lattice/weight/runtime perturbation",
            Self::KvCache => "KV/cache compression and restore drift",
            Self::ResidualWynerZiv => "residual reconstruction gap",
            Self::Quantization => "quantization approximation",
            Self::SubstrateBoundary => "side-information and active-support boundary",
            Self::SelfEvolvingSecurity => "self-evolving or security enforcement",
            Self::NumericalPostCorrection => "numerical guard before softmax half-contraction",
        }
    }

    pub const fn falsifier(self) -> &'static str {
        match self {
            Self::WeightRuntime => {
                "F-WBO-DriftLedger; layerwise reconstruction/logit drift witness"
            }
            Self::KvCache => "F-KV-Direct-Gate; F-WBO-DriftLedger",
            Self::ResidualWynerZiv => "F-WBO-DriftLedger; residual KL slice",
            Self::Quantization => "F-WBO-DriftLedger; layerwise reconstruction/logit drift witness",
            Self::SubstrateBoundary => {
                "F-ACS-AnchorLookup; provider/provenance replay; F-WBO-DriftLedger"
            }
            Self::SelfEvolvingSecurity => {
                "adapter replay/provenance verifier; provider/provenance replay; F-WBO-DriftLedger"
            }
            Self::NumericalPostCorrection => "F-ULP-Oracle; F-WBO-DriftLedger",
        }
    }
}

/// Owner for a cataloged `F-*` falsifier hook.
#[derive(Clone, Copy, Debug, Eq, PartialEq, Hash, Serialize, Deserialize)]
pub struct FalsifierHookOwner {
    pub hook: &'static str,
    pub owner: &'static str,
}

pub const FALSIFIER_HOOK_OWNERS: [FalsifierHookOwner; 4] = [
    FalsifierHookOwner {
        hook: "F-WBO-DriftLedger",
        owner: "docs/fusion/HELIOS_WBO6_BUDGET_2026_05_03.md",
    },
    FalsifierHookOwner {
        hook: "F-ULP-Oracle",
        owner: "agent_core/src/research/eml/ulp_oracle.rs",
    },
    FalsifierHookOwner {
        hook: "F-KV-Direct-Gate",
        owner: "agent_core/src/scope_rex/kv/direct_gate.rs",
    },
    FalsifierHookOwner {
        hook: "F-ACS-AnchorLookup",
        owner: "agent_core/src/research/acs/mod.rs",
    },
];

pub const fn falsifier_hook_owners() -> &'static [FalsifierHookOwner] {
    &FALSIFIER_HOOK_OWNERS
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
        if source.trim().is_empty() {
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

    pub fn measured_within_budget(&self) -> Option<bool> {
        validate_nonnegative_finite(self.budget).ok()?;
        let measured = self.measured?;
        validate_nonnegative_finite(measured).ok()?;
        Some(measured <= self.budget)
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

    pub fn semantic_wbo6_pre_softmax_budget(&self) -> f64 {
        self.contributions
            .iter()
            .filter(|contribution| contribution.term.is_semantic_wbo6())
            .map(|contribution| contribution.budget)
            .sum()
    }

    pub fn numerical_post_correction_budget(&self) -> f64 {
        self.contributions
            .iter()
            .filter(|contribution| contribution.term == WboTermCode::NumericalPostCorrection)
            .map(|contribution| contribution.budget)
            .sum()
    }

    pub fn softmax_half_corrected_budget(&self) -> f64 {
        0.5 * self.pre_softmax_budget()
    }

    fn measured_pre_softmax_total_after_value_validation(&self) -> Option<f64> {
        if self.contributions.is_empty() {
            return None;
        }
        if !self
            .contributions
            .iter()
            .any(|contribution| contribution.term == WboTermCode::NumericalPostCorrection)
        {
            return None;
        }
        self.validate_contribution_values().ok()?;
        let mut total = 0.0;
        for contribution in &self.contributions {
            total += contribution.measured?;
        }
        Some(total)
    }

    fn measured_softmax_half_corrected_total_after_value_validation(&self) -> Option<f64> {
        self.measured_pre_softmax_total_after_value_validation()
            .map(|total| 0.5 * total)
    }

    pub fn measured_pre_softmax_total(&self) -> Option<f64> {
        self.validate().ok()?;
        self.measured_pre_softmax_total_after_value_validation()
    }

    pub fn measured_softmax_half_corrected_total(&self) -> Option<f64> {
        self.measured_pre_softmax_total().map(|total| 0.5 * total)
    }

    pub fn measured_within_budget(&self) -> Option<bool> {
        self.validate().ok()?;
        self.measured_pre_softmax_total_after_value_validation()
            .map(|measured| measured <= self.pre_softmax_budget())
    }

    pub fn validate_rate(&self) -> Result<(), LatticeWboError> {
        if self.rate_milli_bits_per_symbol == Some(0)
            || (self.rate_milli_bits_per_symbol.is_none() && self.coder.allows_rate_parameter())
            || (self.rate_milli_bits_per_symbol.is_some() && !self.coder.allows_rate_parameter())
        {
            Err(LatticeWboError::InvalidRate)
        } else {
            Ok(())
        }
    }

    pub fn validate(&self) -> Result<(), LatticeWboError> {
        self.validate_contract_fields()?;
        self.validate_composition()
    }

    fn validate_contract_fields(&self) -> Result<(), LatticeWboError> {
        if self.contributions.is_empty() {
            return Err(LatticeWboError::EmptyContributions);
        }
        self.validate_contribution_values()?;
        if self
            .contributions
            .iter()
            .any(|contribution| contribution.source.trim().is_empty())
        {
            return Err(LatticeWboError::EmptySource);
        }
        self.validate_rate()?;
        self.validate_side_information()?;
        self.validate_terms()?;
        if !self
            .contributions
            .iter()
            .any(|contribution| contribution.term == WboTermCode::NumericalPostCorrection)
        {
            return Err(LatticeWboError::MissingNumericalPostCorrectionTerm);
        }
        Ok(())
    }

    pub fn validate_contribution_values(&self) -> Result<(), LatticeWboError> {
        for contribution in &self.contributions {
            validate_nonnegative_finite(contribution.budget)?;
            if let Some(measured) = contribution.measured {
                validate_nonnegative_finite(measured)?;
            }
        }
        Ok(())
    }

    pub fn validate_composition(&self) -> Result<(), LatticeWboError> {
        if self.contributions.is_empty() {
            return Err(LatticeWboError::EmptyContributions);
        }
        self.validate_contribution_values()?;
        if self.pre_softmax_budget().is_finite()
            && self.softmax_half_corrected_budget().is_finite()
            && self
                .measured_pre_softmax_total_after_value_validation()
                .is_none_or(|measured| measured.is_finite())
            && self
                .measured_softmax_half_corrected_total_after_value_validation()
                .is_none_or(|measured| measured.is_finite())
        {
            Ok(())
        } else {
            Err(LatticeWboError::InvalidBudgetComposition)
        }
    }

    pub fn validate_terms(&self) -> Result<(), LatticeWboError> {
        let canonical_terms = self.coder.canonical_wbo_terms();
        if self
            .contributions
            .iter()
            .all(|contribution| canonical_terms.contains(&contribution.term))
        {
            Ok(())
        } else {
            Err(LatticeWboError::InvalidWboTermForCodec)
        }
    }

    pub fn validate_side_information(&self) -> Result<(), LatticeWboError> {
        if self
            .coder
            .canonical_side_information()
            .contains(&self.side_information)
        {
            Ok(())
        } else {
            Err(LatticeWboError::InvalidSideInformation)
        }
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

    pub const fn has_zero_axis(self) -> bool {
        self.max_active_tokens == 0 || self.max_active_pages == 0 || self.max_resident_bytes == 0
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

    pub fn new_for_tier(
        memory_tier: ResidencyTier,
        budget: LatticeBudget,
        active_support: Option<ActiveSupportBudget>,
        falsifier: impl Into<String>,
        caveat: impl Into<String>,
    ) -> Self {
        Self::new(
            memory_tier.canonical_name(),
            budget,
            active_support,
            falsifier,
            caveat,
        )
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
        if self.memory_tier.trim().is_empty() {
            return Err(LatticeWboError::EmptyMemoryTier);
        }
        let residency_tier = ResidencyTier::from_canonical_name(&self.memory_tier)
            .ok_or(LatticeWboError::UnknownResidencyTier)?;
        if self.budget.contributions.is_empty() {
            return Err(LatticeWboError::EmptyContributions);
        }
        if self.budget.coder != residency_tier.primary_coder() {
            return Err(LatticeWboError::ResidencyCodecMismatch);
        }
        if !self.budget.contributions.iter().all(|contribution| {
            residency_tier
                .canonical_register_terms()
                .contains(&contribution.term)
        }) {
            return Err(LatticeWboError::InvalidWboTermForResidencyTier);
        }
        if self.budget.side_information != residency_tier.primary_side_information() {
            return Err(LatticeWboError::InvalidSideInformation);
        }
        if self.falsifier.trim().is_empty() {
            return Err(LatticeWboError::EmptyFalsifier);
        }
        if !contains_any_falsifier_hook(&self.falsifier, self.budget.coder.falsifier()) {
            return Err(LatticeWboError::MissingCanonicalFalsifier);
        }
        if !contains_falsifier_hook(&self.falsifier, "F-WBO-DriftLedger") {
            return Err(LatticeWboError::MissingCanonicalFalsifier);
        }
        let has_numerical_post_correction = self
            .budget
            .contributions
            .iter()
            .any(|contribution| contribution.term == WboTermCode::NumericalPostCorrection);
        let has_kv_cache = self
            .budget
            .contributions
            .iter()
            .any(|contribution| contribution.term == WboTermCode::KvCache);
        let has_residual_wyner_ziv = self
            .budget
            .contributions
            .iter()
            .any(|contribution| contribution.term == WboTermCode::ResidualWynerZiv);
        let has_quantization = self
            .budget
            .contributions
            .iter()
            .any(|contribution| contribution.term == WboTermCode::Quantization);
        let has_weight_runtime = self
            .budget
            .contributions
            .iter()
            .any(|contribution| contribution.term == WboTermCode::WeightRuntime);
        let has_substrate_boundary = self
            .budget
            .contributions
            .iter()
            .any(|contribution| contribution.term == WboTermCode::SubstrateBoundary);
        let has_self_evolving_security = self
            .budget
            .contributions
            .iter()
            .any(|contribution| contribution.term == WboTermCode::SelfEvolvingSecurity);
        if !self.budget.contributions.iter().all(|contribution| {
            contains_any_falsifier_hook(&self.falsifier, contribution.term.falsifier())
        }) {
            return Err(LatticeWboError::MissingCanonicalFalsifier);
        }
        if has_numerical_post_correction
            && !contains_falsifier_hook(&self.falsifier, "F-ULP-Oracle")
        {
            return Err(LatticeWboError::MissingCanonicalFalsifier);
        }
        if has_kv_cache && !contains_falsifier_hook(&self.falsifier, "F-KV-Direct-Gate") {
            return Err(LatticeWboError::MissingCanonicalFalsifier);
        }
        if has_residual_wyner_ziv && !contains_falsifier_hook(&self.falsifier, "residual KL slice")
        {
            return Err(LatticeWboError::MissingCanonicalFalsifier);
        }
        if has_quantization
            && !contains_falsifier_hook(
                &self.falsifier,
                "layerwise reconstruction/logit drift witness",
            )
        {
            return Err(LatticeWboError::MissingCanonicalFalsifier);
        }
        if has_weight_runtime
            && !contains_falsifier_hook(
                &self.falsifier,
                "layerwise reconstruction/logit drift witness",
            )
        {
            return Err(LatticeWboError::MissingCanonicalFalsifier);
        }
        if has_substrate_boundary && !contains_falsifier_hook(&self.falsifier, "F-ACS-AnchorLookup")
        {
            return Err(LatticeWboError::MissingCanonicalFalsifier);
        }
        if has_self_evolving_security {
            match self.budget.coder {
                LatticeCoderKind::NetworkCascade
                    if !contains_falsifier_hook(&self.falsifier, "provider/provenance replay") =>
                {
                    return Err(LatticeWboError::MissingCanonicalFalsifier);
                }
                LatticeCoderKind::SelfEvolvingAdapter
                    if !contains_falsifier_hook(
                        &self.falsifier,
                        "adapter replay/provenance verifier",
                    ) =>
                {
                    return Err(LatticeWboError::MissingCanonicalFalsifier);
                }
                _ => {}
            }
        }
        if self.caveat.trim().is_empty() {
            return Err(LatticeWboError::EmptyCaveat);
        }
        self.budget.validate()?;
        if let Some(active_support) = self.active_support {
            if active_support.has_zero_axis()
                || active_support.side_information != SideInformationKind::ActiveSupport
                || !residency_tier.allows_active_support_budget()
            {
                return Err(LatticeWboError::InvalidActiveSupportSideInformation);
            }
            if !self
                .budget
                .contributions
                .iter()
                .any(|contribution| contribution.term == WboTermCode::SubstrateBoundary)
            {
                return Err(LatticeWboError::MissingSubstrateBoundaryTerm);
            }
        } else if self.budget.side_information == SideInformationKind::ActiveSupport {
            return Err(LatticeWboError::MissingActiveSupportBudget);
        }
        if !has_numerical_post_correction {
            return Err(LatticeWboError::MissingNumericalPostCorrectionTerm);
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
    MissingSubstrateBoundaryTerm,
    MissingNumericalPostCorrectionTerm,
    InvalidSideInformation,
    InvalidActiveSupportSideInformation,
    UnknownResidencyTier,
    InvalidRate,
    MissingCanonicalFalsifier,
    InvalidWboTermForCodec,
    InvalidBudgetComposition,
    ResidencyCodecMismatch,
    InvalidWboTermForResidencyTier,
}

impl LatticeWboError {
    pub const ALL: [Self; 18] = [
        Self::InvalidBudget,
        Self::EmptySource,
        Self::EmptyMemoryTier,
        Self::EmptyContributions,
        Self::EmptyFalsifier,
        Self::EmptyCaveat,
        Self::MissingActiveSupportBudget,
        Self::MissingSubstrateBoundaryTerm,
        Self::MissingNumericalPostCorrectionTerm,
        Self::InvalidSideInformation,
        Self::InvalidActiveSupportSideInformation,
        Self::UnknownResidencyTier,
        Self::InvalidRate,
        Self::MissingCanonicalFalsifier,
        Self::InvalidWboTermForCodec,
        Self::InvalidBudgetComposition,
        Self::ResidencyCodecMismatch,
        Self::InvalidWboTermForResidencyTier,
    ];
}

fn validate_nonnegative_finite(value: f64) -> Result<(), LatticeWboError> {
    if value.is_finite() && value >= 0.0 {
        Ok(())
    } else {
        Err(LatticeWboError::InvalidBudget)
    }
}

fn contains_falsifier_hook(candidate: &str, canonical_hook: &str) -> bool {
    let candidate = candidate.to_ascii_lowercase();
    let canonical_hook = canonical_hook.trim().to_ascii_lowercase();
    if canonical_hook.is_empty() {
        return false;
    }

    let mut search_start = 0;
    while let Some(relative_start) = candidate[search_start..].find(&canonical_hook) {
        let start = search_start + relative_start;
        let end = start + canonical_hook.len();
        let before = candidate[..start].chars().next_back();
        let after = candidate[end..].chars().next();
        if is_falsifier_hook_boundary(before) && is_falsifier_hook_boundary(after) {
            return true;
        }
        search_start = start + 1;
    }

    false
}

fn is_falsifier_hook_boundary(ch: Option<char>) -> bool {
    ch.is_none_or(|ch| !(ch.is_ascii_alphanumeric() || ch == '-' || ch == '_' || ch == '/'))
}

fn contains_any_falsifier_hook(candidate: &str, canonical: &str) -> bool {
    canonical
        .split(';')
        .map(str::trim)
        .filter(|hook| !hook.is_empty())
        .any(|hook| contains_falsifier_hook(candidate, hook))
}

#[cfg(test)]
fn f_hooks_in(candidate: &str) -> Vec<&str> {
    let mut hooks = Vec::new();
    for (start, _) in candidate.match_indices("F-") {
        let rest = &candidate[start..];
        let end = rest
            .find(|ch: char| !(ch.is_ascii_alphanumeric() || ch == '-' || ch == '_'))
            .unwrap_or(rest.len());
        hooks.push(&rest[..end]);
    }
    hooks
}

#[cfg(test)]
mod tests {
    use super::*;

    fn side_information_probe_budget(
        coder: LatticeCoderKind,
        side_information: SideInformationKind,
    ) -> LatticeBudget {
        let mut contributions = Vec::with_capacity(coder.canonical_wbo_terms().len());
        for term in coder.canonical_wbo_terms() {
            contributions.push(
                LatticeErrorContribution::new(*term, format!("probe {}", term.code()), 0.0)
                    .expect("canonical probe contribution should be valid"),
            );
        }
        LatticeBudget::new(
            coder,
            coder.allows_rate_parameter().then_some(1250),
            side_information,
            contributions,
        )
    }

    fn tier_probe_contributions(tier: ResidencyTier) -> Vec<LatticeErrorContribution> {
        let mut contributions = Vec::with_capacity(tier.canonical_register_terms().len());
        for term in tier.canonical_register_terms() {
            contributions.push(
                LatticeErrorContribution::new(*term, format!("tier probe {}", term.code()), 0.0)
                    .expect("canonical tier probe contribution should be valid"),
            );
        }
        contributions
    }

    #[test]
    fn falsifier_hook_matching_rejects_substring_collisions() {
        assert!(contains_falsifier_hook(
            "F-ULP-Oracle; F-WBO-DriftLedger",
            "F-ULP-Oracle"
        ));
        assert!(contains_falsifier_hook(
            "residual slice of F-KV-Direct-Gate",
            "F-KV-Direct-Gate"
        ));
        assert!(!contains_falsifier_hook("not-F-ULP-Oracle", "F-ULP-Oracle"));
        assert!(!contains_falsifier_hook("F-ULP-Oracle-v2", "F-ULP-Oracle"));
    }

    #[test]
    fn lattice_coder_kind_round_trips_json() {
        let encoded =
            serde_json::to_string(&LatticeCoderKind::ALL).expect("serialize lattice coder kinds");
        let decoded: [LatticeCoderKind; 13] =
            serde_json::from_str(&encoded).expect("deserialize lattice coder kind");

        assert_eq!(decoded, LatticeCoderKind::ALL);
        assert_eq!(
            LatticeCoderKind::LatticeWynerZivResidual.canonical_name(),
            "lattice-wyner-ziv-residual"
        );
    }

    #[test]
    fn residency_tier_round_trips_json() {
        let encoded =
            serde_json::to_string(&ResidencyTier::ALL).expect("serialize residency tiers");
        let decoded: [ResidencyTier; 7] =
            serde_json::from_str(&encoded).expect("deserialize residency tier");

        assert_eq!(decoded, ResidencyTier::ALL);
        assert_eq!(
            ResidencyTier::LSeSelfEvolving.canonical_name(),
            "L_SE Self-Evolving"
        );
    }

    #[test]
    fn lattice_wbo_error_round_trips_json() {
        let encoded =
            serde_json::to_string(&LatticeWboError::ALL).expect("serialize lattice wbo errors");
        let decoded: [LatticeWboError; 18] =
            serde_json::from_str(&encoded).expect("deserialize lattice wbo error");

        assert_eq!(decoded, LatticeWboError::ALL);
        assert!(decoded.contains(&LatticeWboError::InvalidActiveSupportSideInformation));
        assert!(decoded.contains(&LatticeWboError::MissingSubstrateBoundaryTerm));
        assert!(decoded.contains(&LatticeWboError::MissingNumericalPostCorrectionTerm));
    }

    #[test]
    fn side_information_kind_keeps_hessian_domains_separate() {
        let weight = SideInformationKind::CalibrationHessian;
        let kv = SideInformationKind::RuntimeKvHessian;

        let encoded =
            serde_json::to_string(&SideInformationKind::ALL).expect("serialize side information");
        let decoded: [SideInformationKind; 10] =
            serde_json::from_str(&encoded).expect("deserialize side information");

        assert_eq!(decoded, SideInformationKind::ALL);
        assert!(weight.uses_calibration_hessian());
        assert!(!weight.uses_runtime_kv_hessian());
        assert!(kv.uses_runtime_kv_hessian());
        assert!(!kv.uses_calibration_hessian());
    }

    #[test]
    fn wbo_term_code_round_trips_json() {
        let encoded = serde_json::to_string(&WboTermCode::ALL).expect("serialize wbo terms");
        let decoded: [WboTermCode; 7] =
            serde_json::from_str(&encoded).expect("deserialize wbo terms");

        assert_eq!(decoded, WboTermCode::ALL);
        assert_eq!(decoded[6].code(), "T_num");
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
        let contribution = LatticeErrorContribution::new(
            WboTermCode::ResidualWynerZiv,
            "LWZ residual codec",
            0.04,
        )
        .expect("valid contribution");
        let value = LatticeBudget::new(
            LatticeCoderKind::LatticeWynerZivResidual,
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
            WboTermCode::ALL
                .iter()
                .map(|term| term.code())
                .collect::<Vec<_>>(),
            vec!["T_W", "T_K", "T_R", "T_Q", "T_S", "T_SE", "T_num"]
        );
        assert!(LatticeCoderKind::ALL.contains(&LatticeCoderKind::SherryTernary3Of4));
        assert!(LatticeCoderKind::ALL.contains(&LatticeCoderKind::ShadowKvSketch));
        assert!(LatticeCoderKind::ALL.contains(&LatticeCoderKind::EngramHashRecall));
        assert!(LatticeCoderKind::ALL.contains(&LatticeCoderKind::QuipE8));
        assert!(SideInformationKind::ALL.contains(&SideInformationKind::CalibrationHessian));
        assert!(SideInformationKind::ALL.contains(&SideInformationKind::RuntimeKvHessian));
        assert!(SideInformationKind::ALL.contains(&SideInformationKind::ActiveSupport));
        assert!(SideInformationKind::ALL.contains(&SideInformationKind::StaticFactKey));
    }

    #[test]
    fn ledger_validation_requires_active_support_for_active_support_rows() {
        let contributions = vec![
            LatticeErrorContribution::new(WboTermCode::SubstrateBoundary, "ShadowKV support", 0.01)
                .expect("valid support contribution"),
            LatticeErrorContribution::new(
                WboTermCode::NumericalPostCorrection,
                "softmax half correction",
                0.0,
            )
            .expect("valid numerical contribution"),
        ];
        let budget = LatticeBudget::new(
            LatticeCoderKind::ShadowKvSketch,
            None,
            SideInformationKind::ActiveSupport,
            contributions,
        );
        let missing_support = WboLedgerEntry::new(
            "L2 Shadow Sketch",
            budget,
            None,
            "F-WBO-DriftLedger; F-ACS-AnchorLookup; F-ULP-Oracle",
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

    #[test]
    fn residency_tier_catalog_covers_l0_through_lse_register_rows() {
        assert_eq!(
            ResidencyTier::ALL
                .iter()
                .map(|tier| tier.canonical_name())
                .collect::<Vec<_>>(),
            vec![
                "L0 RAM hot",
                "L1 Compressed Residual",
                "L2 Shadow Sketch",
                "L3 SSD Oracle",
                "L4 Engram",
                "L5 Network Cascade",
                "L_SE Self-Evolving",
            ]
        );
    }

    #[test]
    fn residency_tier_catalog_maps_every_tier_to_primary_codec_and_terms() {
        let rows = ResidencyTier::ALL
            .iter()
            .map(|tier| {
                (
                    tier.canonical_name(),
                    tier.primary_coder(),
                    tier.canonical_register_terms(),
                )
            })
            .collect::<Vec<_>>();

        assert_eq!(
            rows,
            vec![
                (
                    "L0 RAM hot",
                    LatticeCoderKind::ExactHot,
                    &[WboTermCode::NumericalPostCorrection][..],
                ),
                (
                    "L1 Compressed Residual",
                    LatticeCoderKind::LatticeWynerZivResidual,
                    &[
                        WboTermCode::ResidualWynerZiv,
                        WboTermCode::Quantization,
                        WboTermCode::NumericalPostCorrection,
                    ][..],
                ),
                (
                    "L2 Shadow Sketch",
                    LatticeCoderKind::ShadowKvSketch,
                    &[
                        WboTermCode::KvCache,
                        WboTermCode::SubstrateBoundary,
                        WboTermCode::NumericalPostCorrection,
                    ][..],
                ),
                (
                    "L3 SSD Oracle",
                    LatticeCoderKind::Nf4SsdOracle,
                    &[
                        WboTermCode::KvCache,
                        WboTermCode::Quantization,
                        WboTermCode::SubstrateBoundary,
                        WboTermCode::NumericalPostCorrection,
                    ][..],
                ),
                (
                    "L4 Engram",
                    LatticeCoderKind::EngramHashRecall,
                    &[
                        WboTermCode::SubstrateBoundary,
                        WboTermCode::NumericalPostCorrection,
                    ][..],
                ),
                (
                    "L5 Network Cascade",
                    LatticeCoderKind::NetworkCascade,
                    &[
                        WboTermCode::SubstrateBoundary,
                        WboTermCode::SelfEvolvingSecurity,
                        WboTermCode::NumericalPostCorrection,
                    ][..],
                ),
                (
                    "L_SE Self-Evolving",
                    LatticeCoderKind::SelfEvolvingAdapter,
                    &[
                        WboTermCode::WeightRuntime,
                        WboTermCode::SelfEvolvingSecurity,
                        WboTermCode::NumericalPostCorrection,
                    ][..],
                ),
            ]
        );
    }

    #[test]
    fn l1_residual_uses_lwz_and_sherry_stays_weight_side_only() {
        assert_eq!(
            ResidencyTier::L1CompressedResidual.primary_coder(),
            LatticeCoderKind::LatticeWynerZivResidual
        );
        assert_eq!(
            ResidencyTier::L1CompressedResidual.primary_side_information(),
            SideInformationKind::ResidualStream
        );
        assert_eq!(
            LatticeCoderKind::SherryTernary3Of4.canonical_side_information(),
            &[SideInformationKind::CalibrationHessian]
        );
        assert!(
            !LatticeCoderKind::SherryTernary3Of4
                .canonical_wbo_terms()
                .contains(&WboTermCode::ResidualWynerZiv),
            "Sherry is a weight codec; residual transfer must use the Lattice-Wyner-Ziv row"
        );
    }

    #[test]
    fn residency_tier_catalog_attaches_numerical_guard_to_every_tier() {
        for tier in ResidencyTier::ALL {
            assert!(
                tier.canonical_register_terms()
                    .contains(&WboTermCode::NumericalPostCorrection),
                "{} must carry T_num as a numerical post-correction guard",
                tier.canonical_name()
            );
        }
    }

    #[test]
    fn residency_tier_catalog_maps_every_tier_to_side_information() {
        let rows = ResidencyTier::ALL
            .iter()
            .map(|tier| (tier.canonical_name(), tier.primary_side_information()))
            .collect::<Vec<_>>();

        assert_eq!(
            rows,
            vec![
                ("L0 RAM hot", SideInformationKind::None),
                (
                    "L1 Compressed Residual",
                    SideInformationKind::ResidualStream
                ),
                ("L2 Shadow Sketch", SideInformationKind::ActiveSupport),
                ("L3 SSD Oracle", SideInformationKind::SsdOracle),
                ("L4 Engram", SideInformationKind::StaticFactKey),
                ("L5 Network Cascade", SideInformationKind::NetworkTeacher),
                ("L_SE Self-Evolving", SideInformationKind::SurpriseGradient),
            ]
        );
    }

    #[test]
    fn residency_tier_catalog_maps_every_tier_to_side_information_witnesses() {
        let rows = ResidencyTier::ALL
            .iter()
            .map(|tier| (tier.canonical_name(), tier.side_information_witnesses()))
            .collect::<Vec<_>>();

        assert_eq!(
            rows,
            vec![
                ("L0 RAM hot", &[SideInformationKind::None][..]),
                (
                    "L1 Compressed Residual",
                    &[
                        SideInformationKind::ResidualStream,
                        SideInformationKind::DecoderLmState,
                    ][..],
                ),
                (
                    "L2 Shadow Sketch",
                    &[SideInformationKind::ActiveSupport][..]
                ),
                (
                    "L3 SSD Oracle",
                    &[
                        SideInformationKind::SsdOracle,
                        SideInformationKind::ResidualStream,
                    ][..],
                ),
                ("L4 Engram", &[SideInformationKind::StaticFactKey][..]),
                (
                    "L5 Network Cascade",
                    &[SideInformationKind::NetworkTeacher][..]
                ),
                (
                    "L_SE Self-Evolving",
                    &[SideInformationKind::SurpriseGradient][..],
                ),
            ]
        );

        for tier in ResidencyTier::ALL {
            assert!(
                tier.side_information_witnesses()
                    .contains(&tier.primary_side_information()),
                "{} witnesses must include the primary side-information kind",
                tier.canonical_name()
            );
        }
    }

    #[test]
    fn residency_tier_side_information_matches_primary_codec_catalog() {
        for tier in ResidencyTier::ALL {
            assert!(
                tier.primary_coder()
                    .canonical_side_information()
                    .contains(&tier.primary_side_information()),
                "{} primary side information must be accepted by {:?}",
                tier.canonical_name(),
                tier.primary_coder()
            );
        }
    }

    #[test]
    fn residency_tier_catalog_maps_every_tier_to_primary_falsifier() {
        for tier in ResidencyTier::ALL {
            assert_eq!(tier.primary_falsifier(), tier.primary_coder().falsifier());
            assert!(!tier.primary_falsifier().is_empty());
        }
        assert_eq!(
            ResidencyTier::L3SsdOracle.primary_falsifier(),
            "F-KV-Direct-Gate; F-ULP-Oracle; F-WBO-DriftLedger; layerwise reconstruction/logit drift witness; F-ACS-AnchorLookup"
        );
    }

    #[test]
    fn residency_tier_catalog_marks_active_support_budget_tiers() {
        let active_support_tiers = ResidencyTier::ALL
            .iter()
            .copied()
            .filter(|tier| tier.allows_active_support_budget())
            .map(ResidencyTier::canonical_name)
            .collect::<Vec<_>>();

        assert_eq!(
            active_support_tiers,
            vec!["L2 Shadow Sketch", "L3 SSD Oracle"]
        );
    }

    #[test]
    fn residency_tier_catalog_requires_substrate_boundary_for_active_support_budget_tiers() {
        for tier in ResidencyTier::ALL {
            if tier.allows_active_support_budget() {
                assert!(
                    tier.canonical_register_terms()
                        .contains(&WboTermCode::SubstrateBoundary),
                    "{} may carry ActiveSupportBudget and must own T_S",
                    tier.canonical_name()
                );
            }
        }
    }

    #[test]
    fn canonical_residency_rows_validate_against_tier_maps() {
        for tier in ResidencyTier::ALL {
            let contributions = tier
                .canonical_register_terms()
                .iter()
                .map(|term| {
                    LatticeErrorContribution::new(
                        *term,
                        format!("{} {}", tier.canonical_name(), term.code()),
                        0.01,
                    )
                    .expect("canonical contribution should be valid")
                })
                .collect::<Vec<_>>();
            let budget = LatticeBudget::new(
                tier.primary_coder(),
                tier.primary_rate_milli_bits_per_symbol(),
                tier.primary_side_information(),
                contributions,
            );
            let active_support = (tier.primary_side_information()
                == SideInformationKind::ActiveSupport)
                .then_some(ActiveSupportBudget::new(
                    2048,
                    32,
                    64 * 1024 * 1024,
                    SideInformationKind::ActiveSupport,
                ));
            let entry = WboLedgerEntry::new_for_tier(
                tier,
                budget,
                active_support,
                format!("{}; F-ULP-Oracle", tier.primary_coder().falsifier()),
                "Canonical register row keeps residency, codec, terms, and falsifier aligned.",
            );

            assert_eq!(entry.validate(), Ok(()), "{}", tier.canonical_name());
        }
    }

    #[test]
    fn register_doc_preserves_required_canon_cross_links_and_caveats() {
        let register = include_str!("../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
        let required = [
            "`docs/MASTER_FUSION_NO_COMPROMISE_2026_05_13.md` §3.2",
            "`docs/MASTER_FUSION_NO_COMPROMISE_2026_05_13.md` §3.4",
            "`docs/MASTER_FUSION_NO_COMPROMISE_2026_05_13.md` §3.8",
            "`docs/MASTER_FUSION_NO_COMPROMISE_2026_05_13.md` §3.16",
            "`docs/MASTER_FUSION_NO_COMPROMISE_2026_05_13.md` §3.18",
            "`docs/fusion/UNIFIED_ACTIVE_SUBSTRATE_CANON_2026_05_16.md` §2",
            "`docs/fusion/UNIFIED_ACTIVE_SUBSTRATE_CANON_2026_05_16.md` §4",
            "`docs/fusion/UNIFIED_ACTIVE_SUBSTRATE_CANON_2026_05_16.md` §5",
            "`register_doc_canon_line_anchors_match_current_sources`",
            "line anchors must resolve to the current canon section headings",
            "`LatticeCoder<BITS>` is an abstraction",
            "It cannot borrow a weight-codec",
            "Weight quantization and KV quantization use different Hessians",
            "`ResidencyTier::primary_falsifier()`",
            "`LatticeCoderKind::canonical_side_information()`",
            "`ledger_validation_rejects_every_nonprimary_codec_for_every_residency_tier`",
            "every residency tier rejects every non-primary codec before side-information or falsifier borrowing",
            "`ledger_validation_rejects_every_term_outside_residency_tier_map`",
            "every residency tier rejects every contribution term outside its canonical map",
            "`budget_validation_rejects_every_noncanonical_side_information_for_every_codec`",
            "every codec row rejects every side-information witness outside its canonical set",
            "`ledger_validation_rejects_side_information_outside_residency_primary`",
            "`ledger_validation_rejects_every_nonprimary_side_information_for_every_residency_tier`",
            "every residency tier rejects every non-primary side-information kind",
            "`typed_catalogs_assign_every_side_information_to_codec_rows`",
            "`residency_tier_side_information_matches_primary_codec_catalog`",
            "`ResidencyTier::side_information_witnesses()`",
            "`residency_tier_catalog_maps_every_tier_to_side_information_witnesses`",
            "`ledger_validation_allows_l3_ssd_oracle_without_active_support_budget`",
            "`codec_side_information_catalog_keeps_hessian_domains_disjoint`",
            "`weight_codec_catalogs_do_not_claim_kv_cache_terms`",
            "`codec_falsifiers_cover_every_canonical_term_falsifier`",
            "`register_doc_names_every_residency_tier_and_wbo_term`",
            "`register_doc_names_every_codec_and_side_information_kind`",
            "`lattice_budget_composition_rejects_empty_public_contributions`",
            "`lattice_budget_measured_status_returns_none_for_empty_public_contributions`",
            "`lattice_budget_validation_accepts_zero_and_single_max_budget_edges`",
            "`lattice_budget_validation_rejects_signed_contribution_fields_even_when_totals_cancel`",
            "`contribution_measured_status_returns_none_for_invalid_public_fields`",
            "`lattice_budget_measured_status_returns_none_for_invalid_public_fields`",
            "`lattice_budget_measured_status_returns_none_for_invalid_side_information`",
            "`lattice_budget_measured_status_returns_none_for_overflowed_totals`",
            "public struct literals cannot bypass",
            "`lattice_budget_slice_partition_is_order_invariant_across_all_axes`",
            "semantic plus numerical slices conserve the total across reordered and duplicated axes",
            "`ledger_validation_requires_term_falsifier_hook_for_each_contribution`",
            "`ledger_validation_requires_ulp_oracle_for_numerical_post_correction`",
            "`lattice_budget_measured_status_requires_numerical_post_correction_term`",
            "`falsifier_hook_matching_rejects_substring_collisions`",
            "`ledger_validation_rejects_spoofed_ulp_oracle_hook`",
            "`ledger_validation_requires_wbo_drift_ledger_for_every_row`",
            "Every ledger row must name `F-WBO-DriftLedger`",
            "`wbo_term_catalog_requires_drift_ledger_for_every_axis`",
            "every WBO term falsifier includes `F-WBO-DriftLedger`",
            "`FALSIFIER_HOOK_OWNERS`",
            "`falsifier_hook_registry_owns_every_f_hook_named_by_catalogs`",
            "`codec_falsifier_catalogs_name_owned_f_hooks_for_every_codec`",
            "`falsifier_hook_registry_owner_paths_exist`",
            "each falsifier owner path resolves to an existing repo file",
            "`register_doc_f_hooks_are_owned_by_registry`",
            "every concrete register `F-*` hook has a registry owner",
            "`residency_tier_catalog_attaches_numerical_guard_to_every_tier`",
            "`lattice_coder_catalog_attaches_numerical_guard_to_every_codec`",
            "`register_doc_requires_ulp_oracle_on_t_num_table_rows`",
            "`register_doc_codec_falsifier_table_names_ulp_oracle_for_t_num_codecs`",
            "`lattice_coder_catalog_marks_rate_bearing_codecs`",
            "the exact rate-bearing codec set includes standalone `NestedE8` and `NestedLeech24` rows",
            "`F-WBO-DriftLedger` alone is insufficient",
            "`ledger_validation_rejects_active_support_budget_without_substrate_boundary_term`",
            "`residency_tier_catalog_marks_active_support_budget_tiers`",
            "the exact active-support budget tier set is `L2 Shadow Sketch` and `L3 SSD Oracle`",
            "`residency_tier_catalog_requires_substrate_boundary_for_active_support_budget_tiers`",
            "active-support-capable residency tiers must own `T_S`",
            "`ledger_validation_rejects_every_non_active_support_budget_side_information`",
            "secondary `ActiveSupportBudget` rejects every non-`ActiveSupport` side-information tag",
            "`ledger_validation_rejects_partial_zero_active_support_axes`",
            "token, page, and resident-byte axes are each nonzero",
            "`MissingSubstrateBoundaryTerm`",
            "`ledger_validation_requires_numerical_post_correction_contribution`",
            "`MissingNumericalPostCorrectionTerm`",
            "`ledger_validation_requires_kv_direct_gate_for_kv_cache_term`",
            "KV/cache ledger rows must name `F-KV-Direct-Gate`",
            "`ledger_validation_requires_term_specific_security_verifier_for_t_se`",
            "T_SE ledger rows must name provider/provenance replay or adapter replay/provenance verifier",
            "`ledger_validation_requires_residual_kl_slice_for_residual_term`",
            "T_R ledger rows must name residual KL slice",
            "`ledger_validation_requires_layerwise_reconstruction_for_quantization_term`",
            "T_Q ledger rows must name layerwise reconstruction/logit drift witness",
            "`ledger_validation_requires_layerwise_reconstruction_for_weight_runtime_term`",
            "T_W ledger rows must name layerwise reconstruction/logit drift witness",
            "`ledger_validation_requires_anchor_lookup_for_substrate_boundary_term`",
            "T_S ledger rows must name `F-ACS-AnchorLookup`",
            "Sherry is a WEIGHT codec; its public results are weight-side at calibration time",
            "L1 residual rows CANNOT borrow Sherry's calibration Hessian as proof of residual transfer",
            "| Nested E8 | Standalone nested-lattice E8 vector quantization lane",
            "NestedE8 is not a QuIP/E8 subfamily",
            "owns a separate rate row and reconstruction error profile",
            "| `NestedE8` | Nested E8 standalone codec row |",
            "| Nested Leech24 | Standalone nested-lattice Leech_24 vector quantization lane",
            "NestedLeech24 is not a QuIP/E8 subfamily",
            "owns a separate rate row and Leech_24 reconstruction error profile",
            "| `NestedLeech24` | Nested Leech24 standalone codec row |",
            "L3 SSD Oracle keeps `SsdOracle` as primary side information; `ActiveSupportBudget` is allowed but optional",
            "| L0 RAM hot | Exact fp16/bf16 KV and residual stream | None beyond live model state | `T_num` only | `F-WBO-DriftLedger`; `F-ULP-Oracle`; per-token KL witness",
            "| L1 Compressed Residual | Lattice-Wyner-Ziv residual codec under `LatticeCoder<1250 milli-bits>` | Residual stream plus decoder LM state | `T_R` + `T_Q` + `T_num` | `F-WBO-DriftLedger`; `F-ULP-Oracle`; residual KL slice",
            "| L2 Shadow Sketch | ShadowKV-style active-support sketch: retained pages/tokens plus residual or JL/CountSketch correction | Active support mask, page criticality, residual sketch | `T_K` + `T_S` + `T_num` | `F-WBO-DriftLedger`; `F-ULP-Oracle`; `F-KV-Direct-Gate`; `F-ACS-AnchorLookup`",
            "| L3 SSD Oracle | NF4 mmap/IOSurface pages with cold exact-or-higher-fidelity page oracle | SSD oracle page plus residual stream reconstruction witness | `T_K` + `T_Q` + `T_S` + `T_num` | `F-KV-Direct-Gate`; `F-ULP-Oracle`; `F-WBO-DriftLedger`; layerwise reconstruction/logit drift witness; `F-ACS-AnchorLookup`",
            "| L4 Engram | Fixed-budget hash recall for static facts, signatures, dates, and API contracts | Content hash, provenance edge, static-fact key | `T_S` + `T_num` | `F-ACS-AnchorLookup`; `F-ULP-Oracle`; `F-WBO-DriftLedger`",
            "| L5 Network Cascade | Outlier escalation to larger/cloud teacher or cross-model verifier | Network teacher output, signed provenance, claim ledger witness | `T_S` + `T_SE` + `T_num` | `F-WBO-DriftLedger`; `F-ULP-Oracle`; `F-ACS-AnchorLookup`; provider/provenance replay checks",
            "| L_SE Self-Evolving | Titans-MAC / SEAL-DoRA adapter or surprise-gradient state | Surprise gradient, adapter provenance, replayable mutation envelope | `T_W` + `T_SE` + `T_num` | `F-WBO-DriftLedger`; `F-ULP-Oracle`; adapter replay/provenance verifier; layerwise reconstruction/logit drift witness before promotion",
            "| Babai/GPTQ nearest-plane | Weight quantization as nearest-plane rounding in a Hessian-induced lattice | Calibration Hessian from the weight quantization calibration set | `T_W` + `T_num` | `F-WBO-DriftLedger`; `F-ULP-Oracle`; layerwise reconstruction/logit drift witness; layerwise KL/logit drift harness",
            "| `BabaiGptqNearestPlane` | Babai/GPTQ nearest-plane codec row | `F-WBO-DriftLedger`; `F-ULP-Oracle`; layerwise reconstruction/logit drift witness |",
            "| Sherry 3:4 sparse ternary | 1.25-bit sparse ternary lattice packing used as a weight-codec reference only | Calibration Hessian for weight lanes | `T_W` + `T_Q` + `T_num` | `F-WBO-DriftLedger`; `F-ULP-Oracle`; layerwise reconstruction/logit drift witness",
            "| QuIP/E8 | Incoherence rotation plus E8-style lattice codebook for weight blocks | Calibration Hessian / whitening statistics | `T_W` + `T_Q` + `T_num` | `F-WBO-DriftLedger`; `F-ULP-Oracle`; layerwise reconstruction/logit drift witness",
            "| Lattice-Wyner-Ziv / `LatticeCoder<BITS>` | Rate-limited residual or state codec decoded with model side information | Decoder LM state, residual stream, active support, or oracle page depending on tier | `T_R` + tier-specific `T_K`/`T_Q`/`T_S` + `T_num` | `F-WBO-DriftLedger`; `F-ULP-Oracle`; `F-ACS-AnchorLookup`; tier-specific KL/reconstruction witness",
            "| Residual sketch | JL / CountSketch / FRP-shaped correction stream attached to a compressed residual or KV restore path | Residual stream witness plus decoder LM state; active-support mask when the sketch repairs skipped support | `T_R` + `T_Q` + tier-specific `T_S` + `T_num` | `F-WBO-DriftLedger`; `F-ULP-Oracle`; `F-ACS-AnchorLookup`; tier-specific reconstruction witness",
            "| Engram hash recall | Fixed-budget static-fact hash lookup for signatures, dates, API contracts, and never-recompute knowledge | `StaticFactKey`, content hash, and provenance edge | `T_S` + `T_num` | `F-ACS-AnchorLookup`; `F-ULP-Oracle`; `F-WBO-DriftLedger`",
            "| Network cascade | Outlier escalation to a larger model, cloud teacher, or cross-model verifier at the L5 boundary | Signed teacher output, provider receipt, claim ledger witness, and replayable provenance | `T_S` + `T_SE` + `T_num` | Provider/provenance replay; `F-ULP-Oracle`; `F-WBO-DriftLedger`; `F-ACS-AnchorLookup`",
            "| Self-evolving adapter | Titans-MAC / SEAL-DoRA / QDoRA-style adapter state that mutates the effective runtime model | Surprise gradient, adapter provenance, replayable mutation envelope, and promotion witness | `T_W` + `T_SE` + `T_num` | Adapter replay/provenance verifier; `F-ULP-Oracle`; `F-WBO-DriftLedger`; layerwise reconstruction/logit drift witness",
            "rate_milli_bits_per_symbol` on non-rate codecs",
            "`budget_validation_rejects_zero_explicit_rate`",
            "`budget_validation_accepts_nonzero_rate_on_rate_codecs`",
            "`budget_validation_rejects_rate_on_non_rate_codecs`",
            "only `L2 Shadow Sketch` and `L3 SSD Oracle` rows may carry this budget surface",
            "`WboTermCode::falsifier()`",
            "`F-KV-Direct-Gate` for `T_K`",
            "`F-ULP-Oracle` for `T_num`",
            "must conserve",
            "`lattice_budget_measured_total_includes_numerical_post_correction`",
            "`T_num` is tracked as a numerical post-correction guard",
            "not a seventh",
        ];

        for needle in required {
            assert!(register.contains(needle), "missing {needle}");
        }
    }

    #[test]
    fn register_doc_requires_ulp_oracle_on_t_num_table_rows() {
        let register = include_str!("../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
        let mut checked_rows = 0;

        for line in register.lines().filter(|line| line.starts_with('|')) {
            let cells = line
                .trim_matches('|')
                .split('|')
                .map(str::trim)
                .collect::<Vec<_>>();

            if cells.len() >= 6 && cells[3].contains("`T_num`") {
                checked_rows += 1;
                assert!(
                    cells[4].contains("F-ULP-Oracle"),
                    "missing F-ULP-Oracle on numerical row: {line}"
                );
            }
        }

        assert!(
            checked_rows >= 17,
            "expected register and codec rows carrying T_num"
        );
    }

    #[test]
    fn register_doc_codec_falsifier_table_names_ulp_oracle_for_t_num_codecs() {
        let register = include_str!("../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");

        for coder in LatticeCoderKind::ALL {
            if coder
                .canonical_wbo_terms()
                .contains(&WboTermCode::NumericalPostCorrection)
            {
                let prefix = format!("| `{:?}` |", coder);
                let row = register
                    .lines()
                    .find(|line| line.starts_with(&prefix))
                    .unwrap_or_else(|| panic!("missing codec falsifier row for {coder:?}"));
                assert!(
                    row.contains("F-ULP-Oracle"),
                    "codec falsifier row must name F-ULP-Oracle for {coder:?}: {row}"
                );
            }
        }
    }

    #[test]
    fn register_doc_requires_reconstruction_witness_on_t_q_table_rows() {
        let register = include_str!("../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
        let mut checked_rows = 0;

        for line in register.lines().filter(|line| line.starts_with('|')) {
            let cells = line
                .trim_matches('|')
                .split('|')
                .map(str::trim)
                .collect::<Vec<_>>();

            if cells.len() >= 6 && cells[3].contains("`T_Q`") {
                checked_rows += 1;
                assert!(
                    cells[4].contains("layerwise reconstruction/logit drift witness"),
                    "missing quantization reconstruction witness on T_Q row: {line}"
                );
            }
        }

        assert!(checked_rows >= 8, "expected T_Q register and codec rows");
    }

    #[test]
    fn register_doc_requires_reconstruction_witness_on_t_w_table_rows() {
        let register = include_str!("../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
        let mut checked_rows = 0;

        for line in register.lines().filter(|line| line.starts_with('|')) {
            let cells = line
                .trim_matches('|')
                .split('|')
                .map(str::trim)
                .collect::<Vec<_>>();

            if cells.len() >= 6 && cells[3].contains("`T_W`") {
                checked_rows += 1;
                assert!(
                    cells[4].contains("layerwise reconstruction/logit drift witness"),
                    "missing weight/runtime reconstruction witness on T_W row: {line}"
                );
            }
        }

        assert!(checked_rows >= 7, "expected T_W register and codec rows");
    }

    #[test]
    fn register_doc_requires_anchor_lookup_on_t_s_table_rows() {
        let register = include_str!("../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
        let mut checked_rows = 0;

        for line in register.lines().filter(|line| line.starts_with('|')) {
            let cells = line
                .trim_matches('|')
                .split('|')
                .map(str::trim)
                .collect::<Vec<_>>();

            if cells.len() >= 6 && cells[3].contains("`T_S`") {
                checked_rows += 1;
                assert!(
                    cells[4].contains("F-ACS-AnchorLookup"),
                    "missing anchor lookup verifier on T_S row: {line}"
                );
            }
        }

        assert!(checked_rows >= 8, "expected T_S register and codec rows");
    }

    #[test]
    fn register_doc_preserves_babai_gptq_non_rate_caveat() {
        let register = include_str!("../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
        assert!(register.contains(
            "Babai/GPTQ nearest-plane is a calibration-Hessian weight codec, not a `LatticeCoder<BITS>` rate abstraction"
        ));
    }

    #[test]
    fn register_doc_preserves_budget_level_numerical_guard() {
        let register = include_str!("../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
        assert!(register.contains("`LatticeBudget::validate()` rejects budgets without `T_num`"));
    }

    #[test]
    fn register_doc_names_every_residency_tier_and_wbo_term() {
        let register = include_str!("../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");

        for tier in ResidencyTier::ALL {
            let needle = format!("| {} |", tier.canonical_name());
            assert!(
                register.contains(&needle),
                "missing register doc row for {}",
                tier.canonical_name()
            );
        }

        for term in WboTermCode::ALL {
            let needle = format!("| `{}` |", term.code());
            assert!(
                register.contains(&needle),
                "missing WBO term doc row for {}",
                term.code()
            );
        }
    }

    #[test]
    fn register_doc_canon_line_anchors_match_current_sources() {
        let register = include_str!("../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
        let master_fusion = include_str!("../../../docs/MASTER_FUSION_NO_COMPROMISE_2026_05_13.md");
        let uas_canon =
            include_str!("../../../docs/fusion/UNIFIED_ACTIVE_SUBSTRATE_CANON_2026_05_16.md");
        let anchors = [
            (
                "`docs/MASTER_FUSION_NO_COMPROMISE_2026_05_13.md` §3.2 line 79",
                master_fusion,
                79,
                "### 3.2 Six-tier memory hierarchy",
            ),
            (
                "`docs/MASTER_FUSION_NO_COMPROMISE_2026_05_13.md` §3.4 line 119",
                master_fusion,
                119,
                "### 3.4 SCOPE-Rex",
            ),
            (
                "`docs/MASTER_FUSION_NO_COMPROMISE_2026_05_13.md` §3.8 line 175",
                master_fusion,
                175,
                "### 3.8 ACS",
            ),
            (
                "`docs/MASTER_FUSION_NO_COMPROMISE_2026_05_13.md` §3.16 line 267",
                master_fusion,
                267,
                "### 3.16 Helios kernels",
            ),
            (
                "`docs/MASTER_FUSION_NO_COMPROMISE_2026_05_13.md` §3.18 line 302",
                master_fusion,
                302,
                "### 3.18 Provenance ledger",
            ),
            (
                "`docs/fusion/UNIFIED_ACTIVE_SUBSTRATE_CANON_2026_05_16.md` §2 line 19",
                uas_canon,
                19,
                "## 2. The 6 canonical surfaces",
            ),
            (
                "`docs/fusion/UNIFIED_ACTIVE_SUBSTRATE_CANON_2026_05_16.md` §4 line 49",
                uas_canon,
                49,
                "## 4. UAS-ACS cross-link map",
            ),
            (
                "`docs/fusion/UNIFIED_ACTIVE_SUBSTRATE_CANON_2026_05_16.md` §5 line 91",
                uas_canon,
                91,
                "## 5. V1 / V1.x / V2 / Never-ships sort",
            ),
        ];

        for (anchor, source, line_number, expected_heading) in anchors {
            assert!(register.contains(anchor), "register missing {anchor}");
            let actual_line = source
                .lines()
                .nth(line_number - 1)
                .expect("canon anchor line should exist");
            assert!(
                actual_line.contains(expected_heading),
                "{anchor} points at {actual_line:?}, expected {expected_heading:?}"
            );
        }
    }

    #[test]
    fn register_doc_cross_link_rows_name_canon_paths() {
        let register = include_str!("../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
        let required_rows = [
            "| `docs/MASTER_FUSION_NO_COMPROMISE_2026_05_13.md` §3.2 line 79",
            "| `docs/MASTER_FUSION_NO_COMPROMISE_2026_05_13.md` §3.4 line 119",
            "| `docs/MASTER_FUSION_NO_COMPROMISE_2026_05_13.md` §3.8 line 175",
            "| `docs/MASTER_FUSION_NO_COMPROMISE_2026_05_13.md` §3.16 line 267",
            "| `docs/MASTER_FUSION_NO_COMPROMISE_2026_05_13.md` §3.18 line 302",
            "| `docs/fusion/UNIFIED_ACTIVE_SUBSTRATE_CANON_2026_05_16.md` §2 line 19",
            "| `docs/fusion/UNIFIED_ACTIVE_SUBSTRATE_CANON_2026_05_16.md` §4 line 49",
            "| `docs/fusion/UNIFIED_ACTIVE_SUBSTRATE_CANON_2026_05_16.md` §5 line 91",
        ];

        for row_prefix in required_rows {
            assert!(register.contains(row_prefix), "missing {row_prefix}");
        }
    }

    #[test]
    fn register_doc_names_every_codec_and_side_information_kind() {
        let register = include_str!("../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");

        for coder in LatticeCoderKind::ALL {
            let needle = format!("| `{:?}` |", coder);
            assert!(register.contains(&needle), "missing doc row for {coder:?}");
        }

        for side_information in SideInformationKind::ALL {
            let needle = format!("| `{:?}` |", side_information);
            assert!(
                register.contains(&needle),
                "missing side-information doc row for {side_information:?}"
            );
        }
    }

    #[test]
    fn budget_validation_rejects_crossed_hessian_domains() {
        let quantization =
            LatticeErrorContribution::new(WboTermCode::Quantization, "quantization", 0.01)
                .expect("valid contribution");
        let weight_budget = LatticeBudget::new(
            LatticeCoderKind::QuipE8,
            Some(2000),
            SideInformationKind::RuntimeKvHessian,
            vec![quantization.clone()],
        );
        let kv_budget = LatticeBudget::new(
            LatticeCoderKind::ShadowKvSketch,
            None,
            SideInformationKind::CalibrationHessian,
            vec![quantization],
        );

        assert_eq!(
            weight_budget.validate_side_information(),
            Err(LatticeWboError::InvalidSideInformation)
        );
        assert_eq!(
            kv_budget.validate_side_information(),
            Err(LatticeWboError::InvalidSideInformation)
        );
    }

    #[test]
    fn lattice_coder_catalog_names_falsifiers_for_every_codec() {
        for coder in LatticeCoderKind::ALL {
            assert!(!coder.falsifier().is_empty());
        }
        assert_eq!(
            LatticeCoderKind::Nf4SsdOracle.falsifier(),
            "F-KV-Direct-Gate; F-ULP-Oracle; F-WBO-DriftLedger; layerwise reconstruction/logit drift witness; F-ACS-AnchorLookup"
        );
        assert_eq!(
            LatticeCoderKind::EngramHashRecall.falsifier(),
            "F-ACS-AnchorLookup; F-ULP-Oracle; F-WBO-DriftLedger"
        );
        assert_eq!(
            LatticeCoderKind::SelfEvolvingAdapter.falsifier(),
            "adapter replay/provenance verifier; F-ULP-Oracle; F-WBO-DriftLedger; layerwise reconstruction/logit drift witness"
        );
    }

    #[test]
    fn lattice_coder_catalog_includes_babai_gptq_nearest_plane() {
        assert_eq!(
            LatticeCoderKind::BabaiGptqNearestPlane.canonical_name(),
            "babai-gptq-nearest-plane"
        );
        assert_eq!(
            LatticeCoderKind::BabaiGptqNearestPlane.canonical_wbo_terms(),
            &[
                WboTermCode::WeightRuntime,
                WboTermCode::NumericalPostCorrection
            ]
        );
        assert_eq!(
            LatticeCoderKind::BabaiGptqNearestPlane.canonical_side_information(),
            &[SideInformationKind::CalibrationHessian]
        );
        assert!(!LatticeCoderKind::BabaiGptqNearestPlane.allows_rate_parameter());
    }

    #[test]
    fn lattice_coder_catalog_maps_every_codec_to_wbo_terms() {
        for coder in LatticeCoderKind::ALL {
            assert!(!coder.canonical_wbo_terms().is_empty());
        }
        assert_eq!(
            LatticeCoderKind::LatticeWynerZivResidual.canonical_wbo_terms(),
            &[
                WboTermCode::KvCache,
                WboTermCode::ResidualWynerZiv,
                WboTermCode::Quantization,
                WboTermCode::SubstrateBoundary,
                WboTermCode::NumericalPostCorrection,
            ]
        );
        assert_eq!(
            LatticeCoderKind::ResidualSketch.canonical_wbo_terms(),
            &[
                WboTermCode::ResidualWynerZiv,
                WboTermCode::Quantization,
                WboTermCode::SubstrateBoundary,
                WboTermCode::NumericalPostCorrection,
            ]
        );
        assert_eq!(
            LatticeCoderKind::SherryTernary3Of4.canonical_wbo_terms(),
            &[
                WboTermCode::WeightRuntime,
                WboTermCode::Quantization,
                WboTermCode::NumericalPostCorrection,
            ]
        );
        assert_eq!(
            LatticeCoderKind::EngramHashRecall.canonical_wbo_terms(),
            &[
                WboTermCode::SubstrateBoundary,
                WboTermCode::NumericalPostCorrection,
            ]
        );
        assert_eq!(
            LatticeCoderKind::NetworkCascade.canonical_wbo_terms(),
            &[
                WboTermCode::SubstrateBoundary,
                WboTermCode::SelfEvolvingSecurity,
                WboTermCode::NumericalPostCorrection,
            ]
        );
        assert_eq!(
            LatticeCoderKind::SelfEvolvingAdapter.canonical_wbo_terms(),
            &[
                WboTermCode::WeightRuntime,
                WboTermCode::SelfEvolvingSecurity,
                WboTermCode::NumericalPostCorrection,
            ]
        );
    }

    #[test]
    fn lattice_coder_catalog_attaches_numerical_guard_to_every_codec() {
        for coder in LatticeCoderKind::ALL {
            assert!(
                coder
                    .canonical_wbo_terms()
                    .contains(&WboTermCode::NumericalPostCorrection),
                "{coder:?} must carry T_num as a numerical post-correction guard"
            );
        }
    }

    #[test]
    fn codec_falsifiers_cover_every_canonical_term_falsifier() {
        for coder in LatticeCoderKind::ALL {
            for term in coder.canonical_wbo_terms() {
                assert!(
                    contains_any_falsifier_hook(coder.falsifier(), term.falsifier()),
                    "{coder:?} falsifier must cover {}",
                    term.code()
                );
            }
        }
    }

    #[test]
    fn codec_falsifiers_name_ulp_oracle_when_owning_t_num() {
        for coder in LatticeCoderKind::ALL {
            if coder
                .canonical_wbo_terms()
                .contains(&WboTermCode::NumericalPostCorrection)
            {
                assert!(
                    contains_falsifier_hook(coder.falsifier(), "F-ULP-Oracle"),
                    "{coder:?} owns T_num and must name F-ULP-Oracle"
                );
            }
        }
    }

    #[test]
    fn falsifier_hook_registry_owns_every_f_hook_named_by_catalogs() {
        let owners = falsifier_hook_owners();
        for owner in owners {
            assert!(owner.hook.starts_with("F-"));
            assert!(
                !owner.owner.trim().is_empty(),
                "{} must name a concrete owner",
                owner.hook
            );
        }

        let mut hooks = Vec::new();
        for coder in LatticeCoderKind::ALL {
            hooks.extend(f_hooks_in(coder.falsifier()));
        }
        for term in WboTermCode::ALL {
            hooks.extend(f_hooks_in(term.falsifier()));
        }
        for tier in ResidencyTier::ALL {
            hooks.extend(f_hooks_in(tier.primary_falsifier()));
        }
        hooks.sort_unstable();
        hooks.dedup();

        for hook in &hooks {
            assert!(
                owners.iter().any(|owner| owner.hook == *hook),
                "missing falsifier owner for {hook}"
            );
        }
        for owner in owners {
            assert!(
                hooks.contains(&owner.hook),
                "{} owner is stale; no catalog row names it",
                owner.hook
            );
        }
    }

    #[test]
    fn codec_falsifier_catalogs_name_owned_f_hooks_for_every_codec() {
        let owners = falsifier_hook_owners();

        for coder in LatticeCoderKind::ALL {
            let hooks = f_hooks_in(coder.falsifier());
            assert!(
                !hooks.is_empty(),
                "{coder:?} must name at least one F-* hook"
            );
            for hook in hooks {
                assert!(
                    owners.iter().any(|owner| owner.hook == hook),
                    "{coder:?} names unowned falsifier hook {hook}"
                );
            }
        }
    }

    #[test]
    fn falsifier_hook_registry_owner_paths_exist() {
        let repo_root = std::path::Path::new(env!("CARGO_MANIFEST_DIR"))
            .parent()
            .expect("agent_core should have a repository parent");

        for owner in falsifier_hook_owners() {
            let path = repo_root.join(owner.owner);
            assert!(
                path.is_file(),
                "{} owner path must resolve to an existing repo file: {}",
                owner.hook,
                owner.owner
            );
        }
    }

    #[test]
    fn register_doc_f_hooks_are_owned_by_registry() {
        let register = include_str!("../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
        let owners = falsifier_hook_owners();
        let mut hooks = f_hooks_in(register)
            .into_iter()
            .filter(|hook| hook.len() > "F-".len())
            .collect::<Vec<_>>();
        hooks.sort_unstable();
        hooks.dedup();

        for hook in hooks {
            assert!(
                owners.iter().any(|owner| owner.hook == hook),
                "register hook {hook} must have a falsifier owner"
            );
        }
    }

    #[test]
    fn typed_catalogs_assign_every_wbo_term_to_codec_and_residency_rows() {
        for term in WboTermCode::ALL {
            assert!(
                LatticeCoderKind::ALL
                    .iter()
                    .any(|coder| coder.canonical_wbo_terms().contains(&term)),
                "missing codec owner for {}",
                term.code()
            );
            assert!(
                ResidencyTier::ALL
                    .iter()
                    .any(|tier| tier.canonical_register_terms().contains(&term)),
                "missing residency owner for {}",
                term.code()
            );
        }
    }

    #[test]
    fn weight_codec_catalogs_do_not_claim_kv_cache_terms() {
        let weight_codecs = [
            LatticeCoderKind::BabaiGptqNearestPlane,
            LatticeCoderKind::SherryTernary3Of4,
            LatticeCoderKind::NestedE8,
            LatticeCoderKind::NestedLeech24,
            LatticeCoderKind::QuipE8,
        ];

        for coder in weight_codecs {
            assert!(
                !coder.canonical_wbo_terms().contains(&WboTermCode::KvCache),
                "{coder:?} must not collapse T_K into a weight-codec lane"
            );
        }
        assert!(LatticeCoderKind::ShadowKvSketch
            .canonical_wbo_terms()
            .contains(&WboTermCode::KvCache));
        assert!(LatticeCoderKind::Nf4SsdOracle
            .canonical_wbo_terms()
            .contains(&WboTermCode::KvCache));
    }

    #[test]
    fn codec_side_information_catalog_keeps_hessian_domains_disjoint() {
        for coder in LatticeCoderKind::ALL {
            let side_information = coder.canonical_side_information();
            assert!(
                !(side_information.contains(&SideInformationKind::CalibrationHessian)
                    && side_information.contains(&SideInformationKind::RuntimeKvHessian)),
                "{coder:?} must not mix calibration Hessian and runtime KV Hessian"
            );
        }

        assert!(LatticeCoderKind::QuipE8
            .canonical_side_information()
            .contains(&SideInformationKind::CalibrationHessian));
        assert!(LatticeCoderKind::ShadowKvSketch
            .canonical_side_information()
            .contains(&SideInformationKind::RuntimeKvHessian));
    }

    #[test]
    fn lattice_coder_catalog_maps_every_codec_to_side_information() {
        for coder in LatticeCoderKind::ALL {
            assert!(!coder.canonical_side_information().is_empty());
        }
        assert_eq!(
            LatticeCoderKind::ExactHot.canonical_side_information(),
            &[SideInformationKind::None]
        );
        assert_eq!(
            LatticeCoderKind::QuipE8.canonical_side_information(),
            &[SideInformationKind::CalibrationHessian]
        );
        assert_eq!(
            LatticeCoderKind::ShadowKvSketch.canonical_side_information(),
            &[
                SideInformationKind::RuntimeKvHessian,
                SideInformationKind::ActiveSupport,
                SideInformationKind::ResidualStream,
            ]
        );
        assert_eq!(
            LatticeCoderKind::LatticeWynerZivResidual.canonical_side_information(),
            &[
                SideInformationKind::DecoderLmState,
                SideInformationKind::ResidualStream,
                SideInformationKind::ActiveSupport,
                SideInformationKind::SsdOracle,
            ]
        );
        assert_eq!(
            LatticeCoderKind::SherryTernary3Of4.canonical_side_information(),
            &[SideInformationKind::CalibrationHessian]
        );
    }

    #[test]
    fn typed_catalogs_assign_every_side_information_to_codec_rows() {
        for side_information in SideInformationKind::ALL {
            assert!(
                LatticeCoderKind::ALL.iter().any(|coder| coder
                    .canonical_side_information()
                    .contains(&side_information)),
                "missing codec owner for {:?}",
                side_information
            );
        }

        for tier in ResidencyTier::ALL {
            let primary = tier.primary_side_information();
            assert!(SideInformationKind::ALL.contains(&primary));
            assert!(
                LatticeCoderKind::ALL
                    .iter()
                    .any(|coder| coder.canonical_side_information().contains(&primary)),
                "missing codec owner for primary side information on {}",
                tier.canonical_name()
            );
        }
    }

    #[test]
    fn lattice_coder_catalog_marks_rate_bearing_codecs() {
        let rate_bearing = LatticeCoderKind::ALL
            .iter()
            .copied()
            .filter(|coder| coder.allows_rate_parameter())
            .collect::<Vec<_>>();

        assert_eq!(
            rate_bearing,
            vec![
                LatticeCoderKind::LatticeWynerZivResidual,
                LatticeCoderKind::SherryTernary3Of4,
                LatticeCoderKind::NestedE8,
                LatticeCoderKind::NestedLeech24,
                LatticeCoderKind::QuipE8,
                LatticeCoderKind::Nf4SsdOracle,
                LatticeCoderKind::ResidualSketch,
            ]
        );
        assert!(!LatticeCoderKind::ExactHot.allows_rate_parameter());
        assert!(!LatticeCoderKind::EngramHashRecall.allows_rate_parameter());
        assert!(!LatticeCoderKind::NetworkCascade.allows_rate_parameter());
        assert!(!LatticeCoderKind::SelfEvolvingAdapter.allows_rate_parameter());
    }

    #[test]
    fn lattice_budget_validation_requires_numerical_post_correction_term() {
        let contribution =
            LatticeErrorContribution::new(WboTermCode::WeightRuntime, "weight delta", 0.01)
                .expect("valid contribution");
        let budget = LatticeBudget::new(
            LatticeCoderKind::BabaiGptqNearestPlane,
            None,
            SideInformationKind::CalibrationHessian,
            vec![contribution],
        );

        assert_eq!(
            budget.validate(),
            Err(LatticeWboError::MissingNumericalPostCorrectionTerm)
        );
    }

    #[test]
    fn lattice_budget_measured_status_requires_numerical_post_correction_term() {
        let residual =
            LatticeErrorContribution::new(WboTermCode::ResidualWynerZiv, "residual codec", 0.1)
                .expect("valid contribution")
                .with_measured(0.1)
                .expect("valid measurement");
        let budget = LatticeBudget::new(
            LatticeCoderKind::LatticeWynerZivResidual,
            Some(1250),
            SideInformationKind::ResidualStream,
            vec![residual],
        );

        assert_eq!(
            budget.validate(),
            Err(LatticeWboError::MissingNumericalPostCorrectionTerm)
        );
        assert_eq!(budget.measured_pre_softmax_total(), None);
        assert_eq!(budget.measured_softmax_half_corrected_total(), None);
        assert_eq!(budget.measured_within_budget(), None);
    }

    #[test]
    fn lattice_budget_measured_status_returns_none_for_invalid_side_information() {
        let residual =
            LatticeErrorContribution::new(WboTermCode::ResidualWynerZiv, "residual codec", 0.1)
                .expect("valid contribution")
                .with_measured(0.1)
                .expect("valid measurement");
        let numerics = LatticeErrorContribution::new(
            WboTermCode::NumericalPostCorrection,
            "softmax half correction",
            0.0,
        )
        .expect("valid contribution")
        .with_measured(0.0)
        .expect("valid measurement");
        let budget = LatticeBudget::new(
            LatticeCoderKind::LatticeWynerZivResidual,
            Some(1250),
            SideInformationKind::CalibrationHessian,
            vec![residual, numerics],
        );

        assert_eq!(
            budget.validate(),
            Err(LatticeWboError::InvalidSideInformation)
        );
        assert_eq!(budget.measured_pre_softmax_total(), None);
        assert_eq!(budget.measured_softmax_half_corrected_total(), None);
        assert_eq!(budget.measured_within_budget(), None);
    }

    #[test]
    fn lattice_budget_validation_rejects_terms_outside_codec_map() {
        let invalid_term =
            LatticeErrorContribution::new(WboTermCode::KvCache, "kv term on adapter", 0.01)
                .expect("valid contribution");
        let invalid = LatticeBudget::new(
            LatticeCoderKind::SelfEvolvingAdapter,
            None,
            SideInformationKind::SurpriseGradient,
            vec![invalid_term],
        );
        assert_eq!(
            invalid.validate(),
            Err(LatticeWboError::InvalidWboTermForCodec)
        );

        let valid_term = LatticeErrorContribution::new(
            WboTermCode::SelfEvolvingSecurity,
            "adapter replay",
            0.01,
        )
        .expect("valid contribution");
        let numerical = LatticeErrorContribution::new(
            WboTermCode::NumericalPostCorrection,
            "softmax half correction",
            0.0,
        )
        .expect("valid numerical contribution");
        let valid = LatticeBudget::new(
            LatticeCoderKind::SelfEvolvingAdapter,
            None,
            SideInformationKind::SurpriseGradient,
            vec![valid_term, numerical],
        );
        assert_eq!(valid.validate(), Ok(()));
    }

    #[test]
    fn lattice_budget_validation_rejects_nonfinite_composed_totals() {
        let contribution_a =
            LatticeErrorContribution::new(WboTermCode::NumericalPostCorrection, "a", f64::MAX)
                .expect("finite contribution")
                .with_measured(f64::MAX)
                .expect("finite measurement");
        let contribution_b =
            LatticeErrorContribution::new(WboTermCode::NumericalPostCorrection, "b", f64::MAX)
                .expect("finite contribution")
                .with_measured(f64::MAX)
                .expect("finite measurement");
        let budget = LatticeBudget::new(
            LatticeCoderKind::ExactHot,
            None,
            SideInformationKind::None,
            vec![contribution_a, contribution_b],
        );

        assert_eq!(
            budget.validate_composition(),
            Err(LatticeWboError::InvalidBudgetComposition)
        );
        assert_eq!(
            budget.validate(),
            Err(LatticeWboError::InvalidBudgetComposition)
        );
    }

    #[test]
    fn lattice_budget_composition_rejects_empty_public_contributions() {
        let budget = LatticeBudget::new(
            LatticeCoderKind::ExactHot,
            None,
            SideInformationKind::None,
            Vec::new(),
        );

        assert_eq!(
            budget.validate_composition(),
            Err(LatticeWboError::EmptyContributions)
        );
    }

    #[test]
    fn lattice_budget_measured_status_returns_none_for_empty_public_contributions() {
        let budget = LatticeBudget::new(
            LatticeCoderKind::ExactHot,
            None,
            SideInformationKind::None,
            Vec::new(),
        );

        assert_eq!(budget.validate(), Err(LatticeWboError::EmptyContributions));
        assert_eq!(budget.measured_pre_softmax_total(), None);
        assert_eq!(budget.measured_softmax_half_corrected_total(), None);
        assert_eq!(budget.measured_within_budget(), None);
    }

    #[test]
    fn lattice_budget_measured_status_returns_none_for_overflowed_totals() {
        let contribution_a =
            LatticeErrorContribution::new(WboTermCode::NumericalPostCorrection, "a", f64::MAX)
                .expect("finite contribution")
                .with_measured(f64::MAX)
                .expect("finite measurement");
        let contribution_b =
            LatticeErrorContribution::new(WboTermCode::NumericalPostCorrection, "b", f64::MAX)
                .expect("finite contribution")
                .with_measured(f64::MAX)
                .expect("finite measurement");
        let budget = LatticeBudget::new(
            LatticeCoderKind::ExactHot,
            None,
            SideInformationKind::None,
            vec![contribution_a, contribution_b],
        );

        assert_eq!(
            budget.validate_composition(),
            Err(LatticeWboError::InvalidBudgetComposition)
        );
        assert_eq!(budget.measured_pre_softmax_total(), None);
        assert_eq!(budget.measured_softmax_half_corrected_total(), None);
        assert_eq!(budget.measured_within_budget(), None);
    }

    #[test]
    fn lattice_budget_validation_rejects_signed_contribution_fields_even_when_totals_cancel() {
        let negative_budget = LatticeErrorContribution {
            term: WboTermCode::NumericalPostCorrection,
            source: "signed numerics".to_string(),
            budget: -1.0,
            measured: Some(0.0),
        };
        let offsetting_budget = LatticeErrorContribution {
            term: WboTermCode::NumericalPostCorrection,
            source: "offsetting numerics".to_string(),
            budget: 1.0,
            measured: Some(0.0),
        };
        let negative_measurement = LatticeErrorContribution {
            term: WboTermCode::NumericalPostCorrection,
            source: "signed measurement".to_string(),
            budget: 0.0,
            measured: Some(-0.25),
        };
        let offsetting_measurement = LatticeErrorContribution {
            term: WboTermCode::NumericalPostCorrection,
            source: "offsetting measurement".to_string(),
            budget: 0.0,
            measured: Some(0.25),
        };

        for contributions in [
            vec![negative_budget, offsetting_budget],
            vec![negative_measurement, offsetting_measurement],
        ] {
            let budget = LatticeBudget::new(
                LatticeCoderKind::ExactHot,
                None,
                SideInformationKind::None,
                contributions,
            );

            assert_eq!(budget.validate(), Err(LatticeWboError::InvalidBudget));
        }
    }

    #[test]
    fn lattice_budget_measured_status_returns_none_for_invalid_public_fields() {
        let negative_measurement = LatticeErrorContribution {
            term: WboTermCode::NumericalPostCorrection,
            source: "signed measurement".to_string(),
            budget: 0.0,
            measured: Some(-0.25),
        };
        let offsetting_measurement = LatticeErrorContribution {
            term: WboTermCode::NumericalPostCorrection,
            source: "offsetting measurement".to_string(),
            budget: 0.0,
            measured: Some(0.25),
        };
        let budget = LatticeBudget::new(
            LatticeCoderKind::ExactHot,
            None,
            SideInformationKind::None,
            vec![negative_measurement, offsetting_measurement],
        );

        assert_eq!(budget.validate(), Err(LatticeWboError::InvalidBudget));
        assert_eq!(budget.measured_pre_softmax_total(), None);
        assert_eq!(budget.measured_softmax_half_corrected_total(), None);
        assert_eq!(budget.measured_within_budget(), None);
    }

    #[test]
    fn lattice_budget_validation_accepts_zero_and_single_max_budget_edges() {
        let zero_contribution = LatticeErrorContribution::new(
            WboTermCode::NumericalPostCorrection,
            "zero numerics",
            0.0,
        )
        .expect("valid zero contribution")
        .with_measured(0.0)
        .expect("valid zero measurement");
        let zero_budget = LatticeBudget::new(
            LatticeCoderKind::ExactHot,
            None,
            SideInformationKind::None,
            vec![zero_contribution],
        );

        assert_eq!(zero_budget.validate(), Ok(()));
        assert_eq!(zero_budget.pre_softmax_budget(), 0.0);
        assert_eq!(zero_budget.softmax_half_corrected_budget(), 0.0);

        let max_contribution = LatticeErrorContribution::new(
            WboTermCode::NumericalPostCorrection,
            "max finite numerics",
            f64::MAX,
        )
        .expect("single finite max contribution")
        .with_measured(f64::MAX)
        .expect("single finite max measurement");
        let max_budget = LatticeBudget::new(
            LatticeCoderKind::ExactHot,
            None,
            SideInformationKind::None,
            vec![max_contribution],
        );

        assert_eq!(max_budget.validate(), Ok(()));
        assert!(max_budget.softmax_half_corrected_budget().is_finite());
        assert_eq!(max_budget.measured_within_budget(), Some(true));
    }

    #[test]
    fn wbo_term_catalog_names_obligations_for_every_axis() {
        for term in WboTermCode::ALL {
            assert!(!term.obligation().is_empty());
        }
        assert_eq!(
            WboTermCode::KvCache.obligation(),
            "KV/cache compression and restore drift"
        );
        assert_eq!(
            WboTermCode::NumericalPostCorrection.obligation(),
            "numerical guard before softmax half-contraction"
        );
    }

    #[test]
    fn wbo_term_catalog_names_falsifiers_for_every_axis() {
        for term in WboTermCode::ALL {
            assert!(!term.falsifier().is_empty());
        }
        assert_eq!(
            WboTermCode::KvCache.falsifier(),
            "F-KV-Direct-Gate; F-WBO-DriftLedger"
        );
        assert_eq!(
            WboTermCode::NumericalPostCorrection.falsifier(),
            "F-ULP-Oracle; F-WBO-DriftLedger"
        );
    }

    #[test]
    fn wbo_term_catalog_requires_drift_ledger_for_every_axis() {
        for term in WboTermCode::ALL {
            assert!(
                contains_falsifier_hook(term.falsifier(), "F-WBO-DriftLedger"),
                "{} must carry F-WBO-DriftLedger in its term falsifier",
                term.code()
            );
        }
    }

    #[test]
    fn wbo_term_catalog_keeps_t_num_outside_semantic_wbo6() {
        assert_eq!(
            WboTermCode::SEMANTIC_WBO6
                .iter()
                .map(|term| term.code())
                .collect::<Vec<_>>(),
            vec!["T_W", "T_K", "T_R", "T_Q", "T_S", "T_SE"]
        );

        assert!(!WboTermCode::NumericalPostCorrection.is_semantic_wbo6());
        for term in WboTermCode::SEMANTIC_WBO6 {
            assert!(term.is_semantic_wbo6());
        }
    }

    #[test]
    fn lattice_budget_reports_semantic_and_numerical_budget_slices() {
        let residual =
            LatticeErrorContribution::new(WboTermCode::ResidualWynerZiv, "residual", 0.20)
                .expect("valid residual contribution");
        let quantization =
            LatticeErrorContribution::new(WboTermCode::Quantization, "quantization", 0.10)
                .expect("valid quantization contribution");
        let numerics =
            LatticeErrorContribution::new(WboTermCode::NumericalPostCorrection, "numerics", 0.04)
                .expect("valid numerical contribution");
        let budget = LatticeBudget::new(
            LatticeCoderKind::ResidualSketch,
            None,
            SideInformationKind::ResidualStream,
            vec![residual, quantization, numerics],
        );

        assert_eq!(
            budget.semantic_wbo6_pre_softmax_budget(),
            0.30000000000000004
        );
        assert_eq!(budget.numerical_post_correction_budget(), 0.04);
        assert_eq!(budget.pre_softmax_budget(), 0.34);
        assert_eq!(budget.softmax_half_corrected_budget(), 0.17);
    }

    #[test]
    fn lattice_budget_semantic_and_numerical_slices_conserve_total_budget() {
        let contributions = WboTermCode::ALL
            .iter()
            .enumerate()
            .map(|(index, term)| {
                LatticeErrorContribution::new(
                    *term,
                    format!("term {}", term.code()),
                    index as f64 + 1.0,
                )
                .expect("valid contribution")
            })
            .collect::<Vec<_>>();
        let budget = LatticeBudget::new(
            LatticeCoderKind::LatticeWynerZivResidual,
            Some(1250),
            SideInformationKind::DecoderLmState,
            contributions,
        );

        assert_eq!(budget.semantic_wbo6_pre_softmax_budget(), 21.0);
        assert_eq!(budget.numerical_post_correction_budget(), 7.0);
        assert_eq!(
            budget.semantic_wbo6_pre_softmax_budget() + budget.numerical_post_correction_budget(),
            budget.pre_softmax_budget()
        );
    }

    #[test]
    fn lattice_budget_slice_partition_is_order_invariant_across_all_axes() {
        let forward = WboTermCode::ALL
            .iter()
            .copied()
            .enumerate()
            .map(|(index, term)| {
                LatticeErrorContribution::new(
                    term,
                    format!("forward {}", term.code()),
                    index as f64 + 1.0,
                )
                .expect("valid contribution")
            })
            .collect::<Vec<_>>();
        let mut reversed = forward.clone();
        reversed.reverse();
        let mut duplicated_numerics = reversed.clone();
        duplicated_numerics.push(
            LatticeErrorContribution::new(
                WboTermCode::NumericalPostCorrection,
                "second numerical guard",
                0.5,
            )
            .expect("valid duplicate numerical contribution"),
        );

        for contributions in [forward, reversed, duplicated_numerics] {
            let budget = LatticeBudget::new(
                LatticeCoderKind::ExactHot,
                None,
                SideInformationKind::None,
                contributions,
            );
            let semantic = budget.semantic_wbo6_pre_softmax_budget();
            let numerical = budget.numerical_post_correction_budget();

            assert_eq!(semantic + numerical, budget.pre_softmax_budget());
            assert_eq!(
                numerical,
                budget
                    .contributions
                    .iter()
                    .filter(|contribution| {
                        contribution.term == WboTermCode::NumericalPostCorrection
                    })
                    .map(|contribution| contribution.budget)
                    .sum::<f64>()
            );
        }
    }

    #[test]
    fn budget_validation_accepts_canonical_side_information_by_codec() {
        let contribution =
            LatticeErrorContribution::new(WboTermCode::NumericalPostCorrection, "numerics", 0.0)
                .expect("valid zero numerical contribution");
        let cases = [
            (LatticeCoderKind::ExactHot, SideInformationKind::None),
            (
                LatticeCoderKind::LatticeWynerZivResidual,
                SideInformationKind::DecoderLmState,
            ),
            (
                LatticeCoderKind::SherryTernary3Of4,
                SideInformationKind::CalibrationHessian,
            ),
            (
                LatticeCoderKind::ShadowKvSketch,
                SideInformationKind::ActiveSupport,
            ),
            (
                LatticeCoderKind::EngramHashRecall,
                SideInformationKind::StaticFactKey,
            ),
            (
                LatticeCoderKind::NestedE8,
                SideInformationKind::CalibrationHessian,
            ),
            (
                LatticeCoderKind::NestedLeech24,
                SideInformationKind::CalibrationHessian,
            ),
            (
                LatticeCoderKind::QuipE8,
                SideInformationKind::CalibrationHessian,
            ),
            (
                LatticeCoderKind::Nf4SsdOracle,
                SideInformationKind::SsdOracle,
            ),
            (
                LatticeCoderKind::ResidualSketch,
                SideInformationKind::ResidualStream,
            ),
            (
                LatticeCoderKind::NetworkCascade,
                SideInformationKind::NetworkTeacher,
            ),
            (
                LatticeCoderKind::SelfEvolvingAdapter,
                SideInformationKind::SurpriseGradient,
            ),
        ];

        for (coder, side_information) in cases {
            let budget =
                LatticeBudget::new(coder, None, side_information, vec![contribution.clone()]);
            assert_eq!(budget.validate_side_information(), Ok(()));
        }
    }

    #[test]
    fn budget_validation_rejects_side_information_outside_codec_map() {
        let contribution =
            LatticeErrorContribution::new(WboTermCode::NumericalPostCorrection, "numerics", 0.0)
                .expect("valid contribution");
        let cases = [
            (
                LatticeCoderKind::QuipE8,
                SideInformationKind::NetworkTeacher,
            ),
            (
                LatticeCoderKind::ResidualSketch,
                SideInformationKind::SurpriseGradient,
            ),
            (
                LatticeCoderKind::ShadowKvSketch,
                SideInformationKind::CalibrationHessian,
            ),
            (
                LatticeCoderKind::LatticeWynerZivResidual,
                SideInformationKind::NetworkTeacher,
            ),
            (
                LatticeCoderKind::SherryTernary3Of4,
                SideInformationKind::ResidualStream,
            ),
        ];

        for (coder, side_information) in cases {
            let budget =
                LatticeBudget::new(coder, None, side_information, vec![contribution.clone()]);
            assert_eq!(
                budget.validate_side_information(),
                Err(LatticeWboError::InvalidSideInformation)
            );
        }
    }

    #[test]
    fn budget_validation_rejects_every_noncanonical_side_information_for_every_codec() {
        let mut checked = 0;
        for coder in LatticeCoderKind::ALL {
            let allowed = coder.canonical_side_information();
            for side_information in SideInformationKind::ALL {
                if allowed.contains(&side_information) {
                    continue;
                }

                let budget = side_information_probe_budget(coder, side_information);
                assert_eq!(
                    budget.validate(),
                    Err(LatticeWboError::InvalidSideInformation),
                    "{coder:?} accepted noncanonical side information {side_information:?}"
                );
                checked += 1;
            }
        }

        assert!(checked > LatticeCoderKind::ALL.len());
    }

    #[test]
    fn ledger_validation_rejects_active_support_budget_with_wrong_side_information() {
        let contributions = vec![
            LatticeErrorContribution::new(WboTermCode::SubstrateBoundary, "ShadowKV support", 0.01)
                .expect("valid support contribution"),
            LatticeErrorContribution::new(
                WboTermCode::NumericalPostCorrection,
                "softmax half correction",
                0.0,
            )
            .expect("valid numerical contribution"),
        ];
        let budget = LatticeBudget::new(
            LatticeCoderKind::ShadowKvSketch,
            None,
            SideInformationKind::ActiveSupport,
            contributions,
        );
        let wrong_support_kind =
            ActiveSupportBudget::new(128, 4, 1024, SideInformationKind::ResidualStream);
        let entry = WboLedgerEntry::new(
            "L2 Shadow Sketch",
            budget,
            Some(wrong_support_kind),
            "F-WBO-DriftLedger; F-ACS-AnchorLookup; F-ULP-Oracle",
            "Active support must be explicitly budgeted.",
        );

        assert_eq!(
            entry.validate(),
            Err(LatticeWboError::InvalidActiveSupportSideInformation)
        );
    }

    #[test]
    fn ledger_validation_rejects_every_non_active_support_budget_side_information() {
        let contributions = vec![
            LatticeErrorContribution::new(WboTermCode::SubstrateBoundary, "ShadowKV support", 0.01)
                .expect("valid support contribution"),
            LatticeErrorContribution::new(
                WboTermCode::NumericalPostCorrection,
                "softmax half correction",
                0.0,
            )
            .expect("valid numerical contribution"),
        ];
        let budget = LatticeBudget::new(
            LatticeCoderKind::ShadowKvSketch,
            None,
            SideInformationKind::ActiveSupport,
            contributions,
        );
        let mut checked = 0;

        for side_information in SideInformationKind::ALL {
            if side_information == SideInformationKind::ActiveSupport {
                continue;
            }
            let support = ActiveSupportBudget::new(128, 4, 1024, side_information);
            let entry = WboLedgerEntry::new_for_tier(
                ResidencyTier::L2ShadowSketch,
                budget.clone(),
                Some(support),
                "F-WBO-DriftLedger; F-ACS-AnchorLookup; F-ULP-Oracle",
                "Active support budget must use ActiveSupport side information.",
            );

            assert_eq!(
                entry.validate(),
                Err(LatticeWboError::InvalidActiveSupportSideInformation),
                "accepted active-support budget side information {side_information:?}"
            );
            checked += 1;
        }

        assert_eq!(checked, SideInformationKind::ALL.len() - 1);
    }

    #[test]
    fn ledger_validation_allows_mixed_side_information_with_valid_active_support_budget() {
        let contributions = vec![
            LatticeErrorContribution::new(WboTermCode::SubstrateBoundary, "SSD boundary", 0.01)
                .expect("valid contribution"),
            LatticeErrorContribution::new(
                WboTermCode::NumericalPostCorrection,
                "softmax half correction",
                0.0,
            )
            .expect("valid numerical contribution"),
        ];
        let budget = LatticeBudget::new(
            LatticeCoderKind::Nf4SsdOracle,
            Some(4000),
            SideInformationKind::SsdOracle,
            contributions,
        );
        let support =
            ActiveSupportBudget::new(256, 8, 4 * 1024 * 1024, SideInformationKind::ActiveSupport);
        let entry = WboLedgerEntry::new_for_tier(
            ResidencyTier::L3SsdOracle,
            budget,
            Some(support),
            "F-KV-Direct-Gate; F-ULP-Oracle; F-WBO-DriftLedger; F-ACS-AnchorLookup",
            "SSD oracle rows may still carry active-support accounting.",
        );

        assert_eq!(entry.validate(), Ok(()));
    }

    #[test]
    fn ledger_validation_allows_l3_ssd_oracle_without_active_support_budget() {
        let contributions = vec![
            LatticeErrorContribution::new(WboTermCode::KvCache, "SSD KV restore", 0.01)
                .expect("valid KV contribution"),
            LatticeErrorContribution::new(WboTermCode::Quantization, "NF4 page quant", 0.01)
                .expect("valid quantization contribution"),
            LatticeErrorContribution::new(WboTermCode::SubstrateBoundary, "SSD page oracle", 0.01)
                .expect("valid substrate contribution"),
            LatticeErrorContribution::new(
                WboTermCode::NumericalPostCorrection,
                "softmax half correction",
                0.0,
            )
            .expect("valid numerical contribution"),
        ];
        let budget = LatticeBudget::new(
            LatticeCoderKind::Nf4SsdOracle,
            Some(4000),
            SideInformationKind::SsdOracle,
            contributions,
        );
        let entry = WboLedgerEntry::new_for_tier(
            ResidencyTier::L3SsdOracle,
            budget,
            None,
            "F-KV-Direct-Gate; F-ULP-Oracle; F-WBO-DriftLedger; layerwise reconstruction/logit drift witness; F-ACS-AnchorLookup",
            "L3 SSD oracle keeps SsdOracle primary; active-support accounting is optional.",
        );

        assert_eq!(entry.validate(), Ok(()));
    }

    #[test]
    fn ledger_validation_rejects_active_support_budget_without_substrate_boundary_term() {
        let contributions = vec![
            LatticeErrorContribution::new(WboTermCode::KvCache, "ShadowKV restore", 0.01)
                .expect("valid KV contribution"),
            LatticeErrorContribution::new(
                WboTermCode::NumericalPostCorrection,
                "softmax half correction",
                0.0,
            )
            .expect("valid numerical contribution"),
        ];
        let budget = LatticeBudget::new(
            LatticeCoderKind::ShadowKvSketch,
            None,
            SideInformationKind::ActiveSupport,
            contributions,
        );
        let entry = WboLedgerEntry::new_for_tier(
            ResidencyTier::L2ShadowSketch,
            budget,
            Some(ActiveSupportBudget::new(
                2048,
                32,
                64 * 1024 * 1024,
                SideInformationKind::ActiveSupport,
            )),
            "F-KV-Direct-Gate; F-ULP-Oracle; F-WBO-DriftLedger",
            "Active support cannot be attached without a substrate-boundary term.",
        );

        assert_eq!(
            entry.validate(),
            Err(LatticeWboError::MissingSubstrateBoundaryTerm)
        );
    }

    #[test]
    fn ledger_validation_rejects_zero_active_support_budget_even_when_secondary() {
        let contributions = vec![
            LatticeErrorContribution::new(WboTermCode::SubstrateBoundary, "SSD boundary", 0.01)
                .expect("valid contribution"),
            LatticeErrorContribution::new(
                WboTermCode::NumericalPostCorrection,
                "softmax half correction",
                0.0,
            )
            .expect("valid numerical contribution"),
        ];
        let budget = LatticeBudget::new(
            LatticeCoderKind::Nf4SsdOracle,
            Some(4000),
            SideInformationKind::SsdOracle,
            contributions,
        );
        let entry = WboLedgerEntry::new_for_tier(
            ResidencyTier::L3SsdOracle,
            budget,
            Some(ActiveSupportBudget::zero(
                SideInformationKind::ActiveSupport,
            )),
            "F-KV-Direct-Gate; F-WBO-DriftLedger; F-ACS-AnchorLookup; F-ULP-Oracle",
            "A zero active-support budget cannot witness skipped support.",
        );

        assert_eq!(
            entry.validate(),
            Err(LatticeWboError::InvalidActiveSupportSideInformation)
        );
    }

    #[test]
    fn ledger_validation_rejects_partial_zero_active_support_axes() {
        let contributions = vec![
            LatticeErrorContribution::new(WboTermCode::KvCache, "ShadowKV restore", 0.01)
                .expect("valid KV contribution"),
            LatticeErrorContribution::new(WboTermCode::SubstrateBoundary, "ShadowKV support", 0.01)
                .expect("valid substrate contribution"),
            LatticeErrorContribution::new(
                WboTermCode::NumericalPostCorrection,
                "softmax half correction",
                0.0,
            )
            .expect("valid numerical contribution"),
        ];
        let budget = LatticeBudget::new(
            LatticeCoderKind::ShadowKvSketch,
            None,
            SideInformationKind::ActiveSupport,
            contributions,
        );

        for active_support in [
            ActiveSupportBudget::new(0, 8, 4 * 1024 * 1024, SideInformationKind::ActiveSupport),
            ActiveSupportBudget::new(256, 0, 4 * 1024 * 1024, SideInformationKind::ActiveSupport),
            ActiveSupportBudget::new(256, 8, 0, SideInformationKind::ActiveSupport),
        ] {
            let entry = WboLedgerEntry::new_for_tier(
                ResidencyTier::L2ShadowSketch,
                budget.clone(),
                Some(active_support),
                "F-WBO-DriftLedger; F-ULP-Oracle; F-KV-Direct-Gate; F-ACS-AnchorLookup",
                "Every active-support axis must be nonzero.",
            );

            assert_eq!(
                entry.validate(),
                Err(LatticeWboError::InvalidActiveSupportSideInformation)
            );
        }
    }

    #[test]
    fn ledger_validation_rejects_active_support_budget_on_disallowed_tiers() {
        let mut checked = 0;
        for tier in ResidencyTier::ALL
            .iter()
            .copied()
            .filter(|tier| !tier.allows_active_support_budget())
        {
            checked += 1;
            let contribution = LatticeErrorContribution::new(
                WboTermCode::NumericalPostCorrection,
                "numerics",
                0.0,
            )
            .expect("valid contribution");
            let budget = LatticeBudget::new(
                tier.primary_coder(),
                tier.primary_rate_milli_bits_per_symbol(),
                tier.primary_side_information(),
                vec![contribution],
            );
            let entry = WboLedgerEntry::new_for_tier(
                tier,
                budget,
                Some(ActiveSupportBudget::new(
                    1,
                    1,
                    1,
                    SideInformationKind::ActiveSupport,
                )),
                tier.primary_falsifier(),
                "Rows outside L2 and L3 cannot carry active-support side budgets.",
            );

            assert_eq!(
                entry.validate(),
                Err(LatticeWboError::InvalidActiveSupportSideInformation),
                "{}",
                tier.canonical_name()
            );
        }
        assert!(checked >= 5);
    }

    #[test]
    fn residency_tier_round_trips_from_canonical_name() {
        for tier in ResidencyTier::ALL {
            assert_eq!(
                ResidencyTier::from_canonical_name(tier.canonical_name()),
                Some(tier)
            );
        }
        assert_eq!(ResidencyTier::from_canonical_name("L6 Unknown"), None);
    }

    #[test]
    fn ledger_validation_rejects_unknown_residency_tier() {
        let contribution =
            LatticeErrorContribution::new(WboTermCode::NumericalPostCorrection, "numerics", 0.0)
                .expect("valid contribution");
        let budget = LatticeBudget::new(
            LatticeCoderKind::ExactHot,
            None,
            SideInformationKind::None,
            vec![contribution],
        );
        let entry = WboLedgerEntry::new(
            "L6 Unknown",
            budget,
            None,
            "F-WBO-DriftLedger",
            "Only canonical T17B tiers are valid.",
        );

        assert_eq!(entry.validate(), Err(LatticeWboError::UnknownResidencyTier));
    }

    #[test]
    fn ledger_entry_can_be_created_from_typed_residency_tier() {
        let contribution =
            LatticeErrorContribution::new(WboTermCode::NumericalPostCorrection, "numerics", 0.0)
                .expect("valid contribution");
        let budget = LatticeBudget::new(
            LatticeCoderKind::ExactHot,
            None,
            SideInformationKind::None,
            vec![contribution],
        );
        let entry = WboLedgerEntry::new_for_tier(
            ResidencyTier::L0RamHot,
            budget,
            None,
            "F-WBO-DriftLedger; F-ULP-Oracle",
            "Exact path still pays numerics.",
        );

        assert_eq!(entry.memory_tier, "L0 RAM hot");
        assert_eq!(entry.validate(), Ok(()));
    }

    #[test]
    fn ledger_entry_reports_unique_wbo_terms_in_order() {
        let residual_a =
            LatticeErrorContribution::new(WboTermCode::ResidualWynerZiv, "residual a", 0.01)
                .expect("valid residual contribution");
        let quantization =
            LatticeErrorContribution::new(WboTermCode::Quantization, "quantization", 0.02)
                .expect("valid quantization contribution");
        let residual_b =
            LatticeErrorContribution::new(WboTermCode::ResidualWynerZiv, "residual b", 0.03)
                .expect("valid residual contribution");
        let numerics =
            LatticeErrorContribution::new(WboTermCode::NumericalPostCorrection, "numerics", 0.0)
                .expect("valid numerical contribution");
        let budget = LatticeBudget::new(
            LatticeCoderKind::LatticeWynerZivResidual,
            Some(1250),
            SideInformationKind::ResidualStream,
            vec![residual_a, quantization, residual_b, numerics],
        );
        let entry = WboLedgerEntry::new_for_tier(
            ResidencyTier::L1CompressedResidual,
            budget,
            None,
            "F-WBO-DriftLedger; F-ULP-Oracle; residual KL slice; layerwise reconstruction/logit drift witness",
            "Duplicate contribution terms are reported once for ledger accounting.",
        );

        assert_eq!(
            entry.wbo_terms(),
            vec![
                WboTermCode::ResidualWynerZiv,
                WboTermCode::Quantization,
                WboTermCode::NumericalPostCorrection
            ]
        );
        assert_eq!(entry.validate(), Ok(()));
    }

    #[test]
    fn ledger_validation_rejects_residency_codec_mismatch() {
        let contribution =
            LatticeErrorContribution::new(WboTermCode::SubstrateBoundary, "teacher boundary", 0.01)
                .expect("valid contribution");
        let budget = LatticeBudget::new(
            LatticeCoderKind::NetworkCascade,
            None,
            SideInformationKind::NetworkTeacher,
            vec![contribution],
        );
        let entry = WboLedgerEntry::new_for_tier(
            ResidencyTier::L4Engram,
            budget,
            None,
            "provider/provenance replay",
            "Network teacher rows must not be hidden under L4 Engram accounting.",
        );

        assert_eq!(
            entry.validate(),
            Err(LatticeWboError::ResidencyCodecMismatch)
        );
    }

    #[test]
    fn ledger_validation_rejects_every_nonprimary_codec_for_every_residency_tier() {
        let mut checked = 0;
        for tier in ResidencyTier::ALL {
            for coder in LatticeCoderKind::ALL {
                if coder == tier.primary_coder() {
                    continue;
                }

                let budget =
                    side_information_probe_budget(coder, coder.canonical_side_information()[0]);
                let entry = WboLedgerEntry::new_for_tier(
                    tier,
                    budget,
                    None,
                    coder.falsifier(),
                    "Residency rows cannot borrow another tier's codec lane.",
                );

                assert_eq!(
                    entry.validate(),
                    Err(LatticeWboError::ResidencyCodecMismatch),
                    "{} accepted nonprimary codec {:?}",
                    tier.canonical_name(),
                    coder
                );
                checked += 1;
            }
        }

        assert_eq!(
            checked,
            ResidencyTier::ALL.len() * (LatticeCoderKind::ALL.len() - 1)
        );
    }

    #[test]
    fn ledger_validation_rejects_terms_outside_residency_tier_map() {
        let contribution =
            LatticeErrorContribution::new(WboTermCode::WeightRuntime, "Sherry weight lane", 0.01)
                .expect("valid contribution");
        let budget = LatticeBudget::new(
            LatticeCoderKind::LatticeWynerZivResidual,
            Some(1250),
            SideInformationKind::ResidualStream,
            vec![contribution],
        );
        let entry = WboLedgerEntry::new_for_tier(
            ResidencyTier::L1CompressedResidual,
            budget,
            None,
            "F-WBO-DriftLedger",
            "L1 residual rows cannot hide a weight-runtime term.",
        );

        assert_eq!(
            entry.validate(),
            Err(LatticeWboError::InvalidWboTermForResidencyTier)
        );
    }

    #[test]
    fn ledger_validation_rejects_every_term_outside_residency_tier_map() {
        let mut checked = 0;
        for tier in ResidencyTier::ALL {
            for term in WboTermCode::ALL {
                if tier.canonical_register_terms().contains(&term) {
                    continue;
                }

                let mut contributions = tier_probe_contributions(tier);
                contributions.push(
                    LatticeErrorContribution::new(
                        term,
                        format!("foreign term {}", term.code()),
                        0.0,
                    )
                    .expect("foreign probe contribution should be valid"),
                );
                let budget = LatticeBudget::new(
                    tier.primary_coder(),
                    tier.primary_coder().allows_rate_parameter().then_some(1250),
                    tier.primary_side_information(),
                    contributions,
                );
                let entry = WboLedgerEntry::new_for_tier(
                    tier,
                    budget,
                    None,
                    tier.primary_falsifier(),
                    "Residency rows cannot borrow another tier's WBO term.",
                );

                assert_eq!(
                    entry.validate(),
                    Err(LatticeWboError::InvalidWboTermForResidencyTier),
                    "{} accepted foreign term {}",
                    tier.canonical_name(),
                    term.code()
                );
                checked += 1;
            }
        }

        assert!(checked > ResidencyTier::ALL.len());
    }

    #[test]
    fn ledger_validation_rejects_side_information_outside_residency_primary() {
        let contribution = LatticeErrorContribution::new(
            WboTermCode::ResidualWynerZiv,
            "LWZ residual transfer",
            0.01,
        )
        .expect("valid contribution");
        let budget = LatticeBudget::new(
            LatticeCoderKind::LatticeWynerZivResidual,
            Some(1250),
            SideInformationKind::DecoderLmState,
            vec![contribution],
        );
        let entry = WboLedgerEntry::new_for_tier(
            ResidencyTier::L1CompressedResidual,
            budget,
            None,
            "F-WBO-DriftLedger",
            "L1 residual rows must use residual-stream primary side information.",
        );

        assert_eq!(
            entry.validate(),
            Err(LatticeWboError::InvalidSideInformation)
        );
    }

    #[test]
    fn ledger_validation_rejects_every_nonprimary_side_information_for_every_residency_tier() {
        let mut checked = 0;
        for tier in ResidencyTier::ALL {
            for side_information in SideInformationKind::ALL {
                if side_information == tier.primary_side_information() {
                    continue;
                }

                let budget = LatticeBudget::new(
                    tier.primary_coder(),
                    tier.primary_coder().allows_rate_parameter().then_some(1250),
                    side_information,
                    tier_probe_contributions(tier),
                );
                let entry = WboLedgerEntry::new_for_tier(
                    tier,
                    budget,
                    None,
                    tier.primary_falsifier(),
                    "Residency rows cannot borrow another tier's side information.",
                );

                assert_eq!(
                    entry.validate(),
                    Err(LatticeWboError::InvalidSideInformation),
                    "{} accepted nonprimary side information {:?}",
                    tier.canonical_name(),
                    side_information
                );
                checked += 1;
            }
        }

        assert_eq!(
            checked,
            ResidencyTier::ALL.len() * (SideInformationKind::ALL.len() - 1)
        );
    }

    #[test]
    fn contribution_reports_measured_budget_status() {
        let missing_measurement =
            LatticeErrorContribution::new(WboTermCode::Quantization, "unmeasured", 0.1)
                .expect("valid contribution");
        let within_budget = LatticeErrorContribution::new(WboTermCode::Quantization, "within", 0.1)
            .expect("valid contribution")
            .with_measured(0.1)
            .expect("valid measurement");
        let over_budget = LatticeErrorContribution::new(WboTermCode::Quantization, "over", 0.1)
            .expect("valid contribution")
            .with_measured(0.1001)
            .expect("valid measurement");

        assert_eq!(missing_measurement.measured_within_budget(), None);
        assert_eq!(within_budget.measured_within_budget(), Some(true));
        assert_eq!(over_budget.measured_within_budget(), Some(false));
    }

    #[test]
    fn contribution_measured_status_returns_none_for_invalid_public_fields() {
        let signed_contribution = LatticeErrorContribution {
            term: WboTermCode::NumericalPostCorrection,
            source: "signed contribution".to_string(),
            budget: -0.25,
            measured: Some(-0.5),
        };
        let nonfinite_contribution = LatticeErrorContribution {
            term: WboTermCode::NumericalPostCorrection,
            source: "nonfinite contribution".to_string(),
            budget: f64::INFINITY,
            measured: Some(0.0),
        };

        for contribution in [signed_contribution, nonfinite_contribution] {
            assert_eq!(contribution.measured_within_budget(), None);
        }
    }

    #[test]
    fn lattice_budget_composes_measured_totals_only_when_complete() {
        let measured_residual =
            LatticeErrorContribution::new(WboTermCode::ResidualWynerZiv, "residual", 0.2)
                .expect("valid contribution")
                .with_measured(0.12)
                .expect("valid measurement");
        let measured_quantization =
            LatticeErrorContribution::new(WboTermCode::Quantization, "quantization", 0.1)
                .expect("valid contribution")
                .with_measured(0.05)
                .expect("valid measurement");
        let measured_numerics =
            LatticeErrorContribution::new(WboTermCode::NumericalPostCorrection, "numerics", 0.0)
                .expect("valid contribution")
                .with_measured(0.0)
                .expect("valid measurement");
        let complete_budget = LatticeBudget::new(
            LatticeCoderKind::ResidualSketch,
            Some(1250),
            SideInformationKind::ResidualStream,
            vec![
                measured_residual.clone(),
                measured_quantization,
                measured_numerics.clone(),
            ],
        );

        assert_eq!(complete_budget.pre_softmax_budget(), 0.30000000000000004);
        assert_eq!(
            complete_budget.measured_pre_softmax_total(),
            Some(0.16999999999999998)
        );
        assert_eq!(
            complete_budget.measured_softmax_half_corrected_total(),
            Some(0.08499999999999999)
        );
        assert_eq!(complete_budget.measured_within_budget(), Some(true));

        let unmeasured_quantization =
            LatticeErrorContribution::new(WboTermCode::Quantization, "unmeasured", 0.1)
                .expect("valid contribution");
        let incomplete_budget = LatticeBudget::new(
            LatticeCoderKind::ResidualSketch,
            Some(1250),
            SideInformationKind::ResidualStream,
            vec![
                measured_residual,
                unmeasured_quantization,
                measured_numerics,
            ],
        );

        assert_eq!(incomplete_budget.measured_pre_softmax_total(), None);
        assert_eq!(
            incomplete_budget.measured_softmax_half_corrected_total(),
            None
        );
        assert_eq!(incomplete_budget.measured_within_budget(), None);
    }

    #[test]
    fn lattice_budget_measured_total_includes_numerical_post_correction() {
        let residual =
            LatticeErrorContribution::new(WboTermCode::ResidualWynerZiv, "residual", 0.20)
                .expect("valid contribution")
                .with_measured(0.18)
                .expect("valid residual measurement");
        let numerics = LatticeErrorContribution::new(
            WboTermCode::NumericalPostCorrection,
            "softmax half correction",
            0.04,
        )
        .expect("valid numerical contribution")
        .with_measured(0.06)
        .expect("valid numerical measurement");
        let budget = LatticeBudget::new(
            LatticeCoderKind::LatticeWynerZivResidual,
            Some(1250),
            SideInformationKind::ResidualStream,
            vec![residual, numerics],
        );

        assert_eq!(budget.semantic_wbo6_pre_softmax_budget(), 0.20);
        assert_eq!(budget.numerical_post_correction_budget(), 0.04);
        assert_eq!(budget.measured_pre_softmax_total(), Some(0.24));
        assert_eq!(budget.measured_softmax_half_corrected_total(), Some(0.12));
        assert_eq!(budget.measured_within_budget(), Some(true));
    }

    #[test]
    fn lattice_budget_measured_status_handles_zero_and_over_budget_edges() {
        let zero_numerics = LatticeErrorContribution::new(
            WboTermCode::NumericalPostCorrection,
            "zero numerics",
            0.0,
        )
        .expect("valid zero contribution")
        .with_measured(0.0)
        .expect("valid zero measurement");
        let zero_budget = LatticeBudget::new(
            LatticeCoderKind::ExactHot,
            None,
            SideInformationKind::None,
            vec![zero_numerics],
        );

        assert_eq!(zero_budget.measured_pre_softmax_total(), Some(0.0));
        assert_eq!(
            zero_budget.measured_softmax_half_corrected_total(),
            Some(0.0)
        );
        assert_eq!(zero_budget.measured_within_budget(), Some(true));

        let residual =
            LatticeErrorContribution::new(WboTermCode::ResidualWynerZiv, "residual", 0.1)
                .expect("valid contribution")
                .with_measured(0.15)
                .expect("valid measurement");
        let quantization =
            LatticeErrorContribution::new(WboTermCode::Quantization, "quantization", 0.2)
                .expect("valid contribution")
                .with_measured(0.2)
                .expect("valid measurement");
        let numerics =
            LatticeErrorContribution::new(WboTermCode::NumericalPostCorrection, "numerics", 0.0)
                .expect("valid contribution")
                .with_measured(0.0)
                .expect("valid measurement");
        let over_budget = LatticeBudget::new(
            LatticeCoderKind::ResidualSketch,
            Some(1250),
            SideInformationKind::ResidualStream,
            vec![residual, quantization, numerics],
        );

        assert_eq!(over_budget.pre_softmax_budget(), 0.30000000000000004);
        assert_eq!(over_budget.measured_pre_softmax_total(), Some(0.35));
        assert_eq!(
            over_budget.measured_softmax_half_corrected_total(),
            Some(0.175)
        );
        assert_eq!(over_budget.measured_within_budget(), Some(false));
    }

    #[test]
    fn budget_validation_rejects_noncanonical_exact_engram_network_and_adapter_side_info() {
        let contribution =
            LatticeErrorContribution::new(WboTermCode::NumericalPostCorrection, "numerics", 0.0)
                .expect("valid contribution");
        let cases = [
            (
                LatticeCoderKind::ExactHot,
                SideInformationKind::ActiveSupport,
            ),
            (
                LatticeCoderKind::NetworkCascade,
                SideInformationKind::DecoderLmState,
            ),
            (
                LatticeCoderKind::SelfEvolvingAdapter,
                SideInformationKind::ResidualStream,
            ),
            (
                LatticeCoderKind::EngramHashRecall,
                SideInformationKind::NetworkTeacher,
            ),
        ];

        for (coder, side_information) in cases {
            let budget =
                LatticeBudget::new(coder, None, side_information, vec![contribution.clone()]);
            assert_eq!(
                budget.validate_side_information(),
                Err(LatticeWboError::InvalidSideInformation)
            );
        }
    }

    #[test]
    fn ledger_validation_accepts_canonical_active_support_budget() {
        let contributions = vec![
            LatticeErrorContribution::new(WboTermCode::SubstrateBoundary, "ShadowKV support", 0.01)
                .expect("valid support contribution"),
            LatticeErrorContribution::new(
                WboTermCode::NumericalPostCorrection,
                "softmax half correction",
                0.0,
            )
            .expect("valid numerical contribution"),
        ];
        let budget = LatticeBudget::new(
            LatticeCoderKind::ShadowKvSketch,
            None,
            SideInformationKind::ActiveSupport,
            contributions,
        );
        let support = ActiveSupportBudget::new(
            2048,
            32,
            64 * 1024 * 1024,
            SideInformationKind::ActiveSupport,
        );
        let entry = WboLedgerEntry::new_for_tier(
            ResidencyTier::L2ShadowSketch,
            budget,
            Some(support),
            "F-WBO-DriftLedger; F-ULP-Oracle; F-KV-Direct-Gate; F-ACS-AnchorLookup",
            "Active support is accounting metadata, not a speed claim.",
        );

        assert_eq!(entry.validate(), Ok(()));
    }

    #[test]
    fn budget_validation_rejects_zero_explicit_rate() {
        let contribution =
            LatticeErrorContribution::new(WboTermCode::ResidualWynerZiv, "residual", 0.01)
                .expect("valid contribution");
        let budget = LatticeBudget::new(
            LatticeCoderKind::LatticeWynerZivResidual,
            Some(0),
            SideInformationKind::DecoderLmState,
            vec![contribution],
        );

        assert_eq!(budget.validate_rate(), Err(LatticeWboError::InvalidRate));
    }

    #[test]
    fn budget_validation_rejects_missing_rate_on_rate_codecs() {
        let budget = LatticeBudget::new(
            LatticeCoderKind::LatticeWynerZivResidual,
            None,
            SideInformationKind::ResidualStream,
            vec![
                LatticeErrorContribution::new(WboTermCode::ResidualWynerZiv, "residual", 0.01)
                    .expect("valid residual contribution"),
                LatticeErrorContribution::new(
                    WboTermCode::NumericalPostCorrection,
                    "softmax half correction",
                    0.0,
                )
                .expect("valid numerical contribution"),
            ],
        );

        assert_eq!(budget.validate_rate(), Err(LatticeWboError::InvalidRate));
    }

    #[test]
    fn budget_validation_rejects_rate_on_non_rate_codecs() {
        let mut checked = 0;
        for coder in LatticeCoderKind::ALL
            .iter()
            .copied()
            .filter(|coder| !coder.allows_rate_parameter())
        {
            checked += 1;
            let contribution = LatticeErrorContribution::new(
                WboTermCode::NumericalPostCorrection,
                "non-rate codec",
                0.0,
            )
            .expect("valid contribution");
            let budget = LatticeBudget::new(
                coder,
                Some(1250),
                coder.canonical_side_information()[0],
                vec![contribution],
            );
            assert_eq!(budget.validate_rate(), Err(LatticeWboError::InvalidRate));
        }
        assert!(checked >= 4);
    }

    #[test]
    fn budget_validation_accepts_nonzero_rate_on_rate_codecs() {
        for coder in LatticeCoderKind::ALL
            .iter()
            .copied()
            .filter(|coder| coder.allows_rate_parameter())
        {
            let budget = LatticeBudget::new(
                coder,
                Some(u32::MAX),
                coder.canonical_side_information()[0],
                vec![LatticeErrorContribution::new(
                    coder.canonical_wbo_terms()[0],
                    "max rate edge",
                    0.0,
                )
                .expect("valid contribution")],
            );

            assert_eq!(budget.validate_rate(), Ok(()), "{coder:?}");
        }
    }

    #[test]
    fn contribution_rejects_empty_source() {
        assert_eq!(
            LatticeErrorContribution::new(WboTermCode::NumericalPostCorrection, "", 0.0),
            Err(LatticeWboError::EmptySource)
        );
    }

    #[test]
    fn ledger_validation_rejects_empty_contributions_falsifier_and_caveat() {
        let empty_contributions = LatticeBudget::new(
            LatticeCoderKind::ExactHot,
            None,
            SideInformationKind::None,
            Vec::new(),
        );
        let entry = WboLedgerEntry::new_for_tier(
            ResidencyTier::L0RamHot,
            empty_contributions,
            None,
            "F-WBO-DriftLedger",
            "Exact path still pays numerics.",
        );
        assert_eq!(entry.validate(), Err(LatticeWboError::EmptyContributions));

        let contribution =
            LatticeErrorContribution::new(WboTermCode::NumericalPostCorrection, "numerics", 0.0)
                .expect("valid contribution");
        let budget = LatticeBudget::new(
            LatticeCoderKind::ExactHot,
            None,
            SideInformationKind::None,
            vec![contribution.clone()],
        );
        let missing_falsifier = WboLedgerEntry::new_for_tier(
            ResidencyTier::L0RamHot,
            budget,
            None,
            "",
            "Exact path still pays numerics.",
        );
        assert_eq!(
            missing_falsifier.validate(),
            Err(LatticeWboError::EmptyFalsifier)
        );

        let budget = LatticeBudget::new(
            LatticeCoderKind::ExactHot,
            None,
            SideInformationKind::None,
            vec![contribution],
        );
        let missing_caveat = WboLedgerEntry::new_for_tier(
            ResidencyTier::L0RamHot,
            budget,
            None,
            "F-WBO-DriftLedger; F-ULP-Oracle",
            "",
        );
        assert_eq!(missing_caveat.validate(), Err(LatticeWboError::EmptyCaveat));
    }

    #[test]
    fn ledger_string_guards_reject_whitespace_only_fields() {
        assert_eq!(
            LatticeErrorContribution::new(WboTermCode::NumericalPostCorrection, "   ", 0.0),
            Err(LatticeWboError::EmptySource)
        );

        let contribution =
            LatticeErrorContribution::new(WboTermCode::NumericalPostCorrection, "numerics", 0.0)
                .expect("valid contribution");
        let budget = LatticeBudget::new(
            LatticeCoderKind::ExactHot,
            None,
            SideInformationKind::None,
            vec![contribution.clone()],
        );
        let missing_falsifier = WboLedgerEntry::new_for_tier(
            ResidencyTier::L0RamHot,
            budget,
            None,
            "   ",
            "Exact path still pays numerics.",
        );
        assert_eq!(
            missing_falsifier.validate(),
            Err(LatticeWboError::EmptyFalsifier)
        );

        let budget = LatticeBudget::new(
            LatticeCoderKind::ExactHot,
            None,
            SideInformationKind::None,
            vec![contribution],
        );
        let missing_caveat = WboLedgerEntry::new_for_tier(
            ResidencyTier::L0RamHot,
            budget,
            None,
            "F-WBO-DriftLedger; F-ULP-Oracle",
            "   ",
        );
        assert_eq!(missing_caveat.validate(), Err(LatticeWboError::EmptyCaveat));
    }

    #[test]
    fn ledger_validation_requires_codec_falsifier_hook() {
        let contribution =
            LatticeErrorContribution::new(WboTermCode::NumericalPostCorrection, "numerics", 0.0)
                .expect("valid contribution");
        let budget = LatticeBudget::new(
            LatticeCoderKind::ExactHot,
            None,
            SideInformationKind::None,
            vec![contribution.clone()],
        );
        let unrelated_falsifier = WboLedgerEntry::new_for_tier(
            ResidencyTier::L0RamHot,
            budget,
            None,
            "adapter replay/provenance verifier",
            "Exact path still pays numerics.",
        );
        assert_eq!(
            unrelated_falsifier.validate(),
            Err(LatticeWboError::MissingCanonicalFalsifier)
        );

        let boundary_contribution =
            LatticeErrorContribution::new(WboTermCode::SubstrateBoundary, "provider boundary", 0.0)
                .expect("valid boundary contribution");
        let numerics =
            LatticeErrorContribution::new(WboTermCode::NumericalPostCorrection, "numerics", 0.0)
                .expect("valid numerical contribution");
        let budget = LatticeBudget::new(
            LatticeCoderKind::NetworkCascade,
            None,
            SideInformationKind::NetworkTeacher,
            vec![boundary_contribution, numerics],
        );
        let lower_case_provider_hook = WboLedgerEntry::new_for_tier(
            ResidencyTier::L5NetworkCascade,
            budget,
            None,
            "Provider/provenance replay; F-ULP-Oracle; F-WBO-DriftLedger; F-ACS-AnchorLookup",
            "Provider evidence must replay.",
        );
        assert_eq!(lower_case_provider_hook.validate(), Ok(()));
    }

    #[test]
    fn ledger_validation_requires_term_falsifier_hook_for_each_contribution() {
        let contribution =
            LatticeErrorContribution::new(WboTermCode::NumericalPostCorrection, "numerics", 0.0)
                .expect("valid contribution");
        let budget = LatticeBudget::new(
            LatticeCoderKind::NetworkCascade,
            None,
            SideInformationKind::NetworkTeacher,
            vec![contribution],
        );
        let provider_only = WboLedgerEntry::new_for_tier(
            ResidencyTier::L5NetworkCascade,
            budget,
            None,
            "provider/provenance replay",
            "Provider replay alone does not witness the numerical guard.",
        );

        assert_eq!(
            provider_only.validate(),
            Err(LatticeWboError::MissingCanonicalFalsifier)
        );
    }

    #[test]
    fn ledger_validation_requires_wbo_drift_ledger_for_every_row() {
        let contribution =
            LatticeErrorContribution::new(WboTermCode::NumericalPostCorrection, "numerics", 0.0)
                .expect("valid numerical contribution");
        let budget = LatticeBudget::new(
            LatticeCoderKind::ExactHot,
            None,
            SideInformationKind::None,
            vec![contribution],
        );
        let entry = WboLedgerEntry::new_for_tier(
            ResidencyTier::L0RamHot,
            budget,
            None,
            "F-ULP-Oracle",
            "Numerical oracle without drift ledger is incomplete.",
        );

        assert_eq!(
            entry.validate(),
            Err(LatticeWboError::MissingCanonicalFalsifier)
        );
    }

    #[test]
    fn ledger_validation_requires_ulp_oracle_for_numerical_post_correction() {
        let contribution =
            LatticeErrorContribution::new(WboTermCode::NumericalPostCorrection, "numerics", 0.0)
                .expect("valid contribution");
        let budget = LatticeBudget::new(
            LatticeCoderKind::ExactHot,
            None,
            SideInformationKind::None,
            vec![contribution],
        );
        let wbo_only = WboLedgerEntry::new_for_tier(
            ResidencyTier::L0RamHot,
            budget,
            None,
            "F-WBO-DriftLedger",
            "Numerical correction must name the ULP oracle.",
        );

        assert_eq!(
            wbo_only.validate(),
            Err(LatticeWboError::MissingCanonicalFalsifier)
        );
    }

    #[test]
    fn ledger_validation_requires_kv_direct_gate_for_kv_cache_term() {
        let contributions = vec![
            LatticeErrorContribution::new(WboTermCode::KvCache, "ShadowKV restore", 0.01)
                .expect("valid KV contribution"),
            LatticeErrorContribution::new(WboTermCode::SubstrateBoundary, "ShadowKV support", 0.01)
                .expect("valid substrate contribution"),
            LatticeErrorContribution::new(
                WboTermCode::NumericalPostCorrection,
                "softmax half correction",
                0.0,
            )
            .expect("valid numerical contribution"),
        ];
        let budget = LatticeBudget::new(
            LatticeCoderKind::ShadowKvSketch,
            None,
            SideInformationKind::ActiveSupport,
            contributions,
        );
        let entry = WboLedgerEntry::new_for_tier(
            ResidencyTier::L2ShadowSketch,
            budget,
            Some(ActiveSupportBudget::new(
                2048,
                32,
                64 * 1024 * 1024,
                SideInformationKind::ActiveSupport,
            )),
            "F-WBO-DriftLedger; F-ULP-Oracle; F-ACS-AnchorLookup",
            "KV/cache rows must name the direct K/V gate.",
        );

        assert_eq!(
            entry.validate(),
            Err(LatticeWboError::MissingCanonicalFalsifier)
        );
    }

    #[test]
    fn ledger_validation_requires_anchor_lookup_for_substrate_boundary_term() {
        let contributions = vec![
            LatticeErrorContribution::new(WboTermCode::SubstrateBoundary, "engram lookup", 0.01)
                .expect("valid substrate contribution"),
            LatticeErrorContribution::new(
                WboTermCode::NumericalPostCorrection,
                "softmax half correction",
                0.0,
            )
            .expect("valid numerical contribution"),
        ];
        let budget = LatticeBudget::new(
            LatticeCoderKind::EngramHashRecall,
            None,
            SideInformationKind::StaticFactKey,
            contributions,
        );
        let entry = WboLedgerEntry::new_for_tier(
            ResidencyTier::L4Engram,
            budget,
            None,
            "F-WBO-DriftLedger; F-ULP-Oracle",
            "Substrate-boundary rows must name the anchor lookup verifier.",
        );

        assert_eq!(
            entry.validate(),
            Err(LatticeWboError::MissingCanonicalFalsifier)
        );
    }

    #[test]
    fn ledger_validation_requires_term_specific_security_verifier_for_t_se() {
        let network_contributions = vec![
            LatticeErrorContribution::new(WboTermCode::SubstrateBoundary, "teacher boundary", 0.01)
                .expect("valid substrate contribution"),
            LatticeErrorContribution::new(
                WboTermCode::SelfEvolvingSecurity,
                "network teacher security",
                0.01,
            )
            .expect("valid security contribution"),
            LatticeErrorContribution::new(
                WboTermCode::NumericalPostCorrection,
                "softmax half correction",
                0.0,
            )
            .expect("valid numerical contribution"),
        ];
        let network_budget = LatticeBudget::new(
            LatticeCoderKind::NetworkCascade,
            None,
            SideInformationKind::NetworkTeacher,
            network_contributions,
        );
        let network_without_replay = WboLedgerEntry::new_for_tier(
            ResidencyTier::L5NetworkCascade,
            network_budget,
            None,
            "F-WBO-DriftLedger; F-ULP-Oracle; F-ACS-AnchorLookup",
            "Network security rows must replay provider provenance.",
        );

        assert_eq!(
            network_without_replay.validate(),
            Err(LatticeWboError::MissingCanonicalFalsifier)
        );

        let adapter_contributions = vec![
            LatticeErrorContribution::new(WboTermCode::WeightRuntime, "adapter weight delta", 0.01)
                .expect("valid weight contribution"),
            LatticeErrorContribution::new(
                WboTermCode::SelfEvolvingSecurity,
                "adapter promotion",
                0.01,
            )
            .expect("valid security contribution"),
            LatticeErrorContribution::new(
                WboTermCode::NumericalPostCorrection,
                "softmax half correction",
                0.0,
            )
            .expect("valid numerical contribution"),
        ];
        let adapter_budget = LatticeBudget::new(
            LatticeCoderKind::SelfEvolvingAdapter,
            None,
            SideInformationKind::SurpriseGradient,
            adapter_contributions,
        );
        let adapter_without_replay = WboLedgerEntry::new_for_tier(
            ResidencyTier::LSeSelfEvolving,
            adapter_budget,
            None,
            "F-WBO-DriftLedger; F-ULP-Oracle; layerwise reconstruction/logit drift witness",
            "Adapter security rows must replay adapter provenance.",
        );

        assert_eq!(
            adapter_without_replay.validate(),
            Err(LatticeWboError::MissingCanonicalFalsifier)
        );
    }

    #[test]
    fn ledger_validation_requires_residual_kl_slice_for_residual_term() {
        let contributions = vec![
            LatticeErrorContribution::new(WboTermCode::ResidualWynerZiv, "residual", 0.01)
                .expect("valid residual contribution"),
            LatticeErrorContribution::new(WboTermCode::Quantization, "quantization", 0.01)
                .expect("valid quantization contribution"),
            LatticeErrorContribution::new(
                WboTermCode::NumericalPostCorrection,
                "softmax half correction",
                0.0,
            )
            .expect("valid numerical contribution"),
        ];
        let budget = LatticeBudget::new(
            LatticeCoderKind::LatticeWynerZivResidual,
            Some(1250),
            SideInformationKind::ResidualStream,
            contributions,
        );
        let entry = WboLedgerEntry::new_for_tier(
            ResidencyTier::L1CompressedResidual,
            budget,
            None,
            "F-WBO-DriftLedger; F-ULP-Oracle; layerwise reconstruction/logit drift witness",
            "Residual rows must include the residual KL witness.",
        );

        assert_eq!(
            entry.validate(),
            Err(LatticeWboError::MissingCanonicalFalsifier)
        );
    }

    #[test]
    fn ledger_validation_requires_layerwise_reconstruction_for_quantization_term() {
        let contributions = vec![
            LatticeErrorContribution::new(WboTermCode::KvCache, "SSD KV restore", 0.01)
                .expect("valid KV contribution"),
            LatticeErrorContribution::new(WboTermCode::Quantization, "NF4 page quant", 0.01)
                .expect("valid quantization contribution"),
            LatticeErrorContribution::new(WboTermCode::SubstrateBoundary, "SSD page oracle", 0.01)
                .expect("valid substrate contribution"),
            LatticeErrorContribution::new(
                WboTermCode::NumericalPostCorrection,
                "softmax half correction",
                0.0,
            )
            .expect("valid numerical contribution"),
        ];
        let budget = LatticeBudget::new(
            LatticeCoderKind::Nf4SsdOracle,
            Some(4000),
            SideInformationKind::SsdOracle,
            contributions,
        );
        let entry = WboLedgerEntry::new_for_tier(
            ResidencyTier::L3SsdOracle,
            budget,
            None,
            "F-KV-Direct-Gate; F-ULP-Oracle; F-WBO-DriftLedger",
            "Quantization rows must include a reconstruction or logit-drift witness.",
        );

        assert_eq!(
            entry.validate(),
            Err(LatticeWboError::MissingCanonicalFalsifier)
        );
    }

    #[test]
    fn ledger_validation_requires_layerwise_reconstruction_for_weight_runtime_term() {
        let contributions = vec![
            LatticeErrorContribution::new(WboTermCode::WeightRuntime, "adapter delta", 0.01)
                .expect("valid weight contribution"),
            LatticeErrorContribution::new(
                WboTermCode::SelfEvolvingSecurity,
                "adapter replay",
                0.01,
            )
            .expect("valid security contribution"),
            LatticeErrorContribution::new(
                WboTermCode::NumericalPostCorrection,
                "softmax half correction",
                0.0,
            )
            .expect("valid numerical contribution"),
        ];
        let budget = LatticeBudget::new(
            LatticeCoderKind::SelfEvolvingAdapter,
            None,
            SideInformationKind::SurpriseGradient,
            contributions,
        );
        let entry = WboLedgerEntry::new_for_tier(
            ResidencyTier::LSeSelfEvolving,
            budget,
            None,
            "adapter replay/provenance verifier; F-ULP-Oracle; F-WBO-DriftLedger",
            "Weight/runtime rows must include the layerwise reconstruction witness.",
        );

        assert_eq!(
            entry.validate(),
            Err(LatticeWboError::MissingCanonicalFalsifier)
        );
    }

    #[test]
    fn ledger_validation_requires_numerical_post_correction_contribution() {
        let contributions = vec![
            LatticeErrorContribution::new(WboTermCode::ResidualWynerZiv, "residual", 0.01)
                .expect("valid residual contribution"),
            LatticeErrorContribution::new(WboTermCode::Quantization, "quantization", 0.01)
                .expect("valid quantization contribution"),
        ];
        let budget = LatticeBudget::new(
            LatticeCoderKind::LatticeWynerZivResidual,
            Some(1250),
            SideInformationKind::ResidualStream,
            contributions,
        );
        let entry = WboLedgerEntry::new_for_tier(
            ResidencyTier::L1CompressedResidual,
            budget,
            None,
            "F-WBO-DriftLedger; residual KL slice; layerwise reconstruction/logit drift witness",
            "Every ledger row must reserve the numerical post-correction guard.",
        );

        assert_eq!(
            entry.validate(),
            Err(LatticeWboError::MissingNumericalPostCorrectionTerm)
        );
    }

    #[test]
    fn ledger_validation_rejects_spoofed_ulp_oracle_hook() {
        let contribution =
            LatticeErrorContribution::new(WboTermCode::NumericalPostCorrection, "numerics", 0.0)
                .expect("valid contribution");
        let budget = LatticeBudget::new(
            LatticeCoderKind::ExactHot,
            None,
            SideInformationKind::None,
            vec![contribution],
        );
        let spoofed = WboLedgerEntry::new_for_tier(
            ResidencyTier::L0RamHot,
            budget,
            None,
            "not-F-ULP-Oracle; F-WBO-DriftLedger",
            "Numerical correction must name the canonical ULP oracle hook.",
        );

        assert_eq!(
            spoofed.validate(),
            Err(LatticeWboError::MissingCanonicalFalsifier)
        );
    }

    #[test]
    fn lattice_budget_validate_combines_rate_and_side_information_guards() {
        let contribution =
            LatticeErrorContribution::new(WboTermCode::Quantization, "quantization", 0.01)
                .expect("valid contribution");
        let empty_contributions = LatticeBudget::new(
            LatticeCoderKind::QuipE8,
            Some(2000),
            SideInformationKind::CalibrationHessian,
            Vec::new(),
        );
        let invalid_rate = LatticeBudget::new(
            LatticeCoderKind::LatticeWynerZivResidual,
            Some(0),
            SideInformationKind::DecoderLmState,
            vec![contribution.clone()],
        );
        let invalid_side_information = LatticeBudget::new(
            LatticeCoderKind::QuipE8,
            Some(2000),
            SideInformationKind::RuntimeKvHessian,
            vec![contribution.clone()],
        );
        let valid = LatticeBudget::new(
            LatticeCoderKind::QuipE8,
            Some(2000),
            SideInformationKind::CalibrationHessian,
            vec![
                contribution,
                LatticeErrorContribution::new(
                    WboTermCode::NumericalPostCorrection,
                    "softmax half correction",
                    0.0,
                )
                .expect("valid numerical contribution"),
            ],
        );

        assert_eq!(
            empty_contributions.validate(),
            Err(LatticeWboError::EmptyContributions)
        );
        assert_eq!(invalid_rate.validate(), Err(LatticeWboError::InvalidRate));
        assert_eq!(
            invalid_side_information.validate(),
            Err(LatticeWboError::InvalidSideInformation)
        );
        assert_eq!(valid.validate(), Ok(()));
    }
}
