//! WBO register core: residency tiers, codec families, side-information kinds,
//! and the per-row ledger entry that ties a tier to its codec/budget/falsifier.

use serde::{de, Deserialize, Deserializer, Serialize, Serializer};

use super::accounting::{ActiveSupportBudget, LatticeBudget, WboTermCode};
use super::error::LatticeWboError;
use super::verifier::{
    contains_any_falsifier_hook, contains_falsifier_hook, falsifier_hooks_are_owned,
};
use super::wire::{deserialize_explicit_public_option, ExplicitPublicOption};

/// Canonical residency tiers named by the lattice/WBO register.
#[derive(Clone, Copy, Debug, Eq, PartialEq, Hash)]
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

    pub const CODES: [&'static str; 7] = [
        "L0 RAM hot",
        "L1 Compressed Residual",
        "L2 Shadow Sketch",
        "L3 SSD Oracle",
        "L4 Engram",
        "L5 Network Cascade",
        "L_SE Self-Evolving",
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

    pub const fn requires_active_support_budget(self) -> bool {
        matches!(self, Self::L2ShadowSketch)
    }

    pub const fn allows_secondary_active_support_budget(self) -> bool {
        matches!(self, Self::L3SsdOracle)
    }

    pub const fn allows_active_support_budget(self) -> bool {
        self.requires_active_support_budget() || self.allows_secondary_active_support_budget()
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

impl Serialize for ResidencyTier {
    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: Serializer,
    {
        serializer.serialize_str(self.canonical_name())
    }
}

impl<'de> Deserialize<'de> for ResidencyTier {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: Deserializer<'de>,
    {
        let key = String::deserialize(deserializer)?;
        Self::from_canonical_name(&key)
            .ok_or_else(|| de::Error::unknown_variant(&key, &Self::CODES))
    }
}

/// Canonical codec families referenced by the lattice/WBO register.
#[derive(Clone, Copy, Debug, Eq, PartialEq, Hash)]
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

    pub const CODES: [&'static str; 13] = [
        "exact-hot",
        "lattice-wyner-ziv-residual",
        "babai-gptq-nearest-plane",
        "sherry-3-of-4-ternary",
        "shadow-kv-sketch",
        "engram-hash-recall",
        "nested-e8",
        "nested-leech-24",
        "quip-e8",
        "nf4-ssd-oracle",
        "residual-sketch",
        "network-cascade",
        "self-evolving-adapter",
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

    pub fn from_canonical_name(name: &str) -> Option<Self> {
        match name {
            "exact-hot" => Some(Self::ExactHot),
            "lattice-wyner-ziv-residual" => Some(Self::LatticeWynerZivResidual),
            "babai-gptq-nearest-plane" => Some(Self::BabaiGptqNearestPlane),
            "sherry-3-of-4-ternary" => Some(Self::SherryTernary3Of4),
            "shadow-kv-sketch" => Some(Self::ShadowKvSketch),
            "engram-hash-recall" => Some(Self::EngramHashRecall),
            "nested-e8" => Some(Self::NestedE8),
            "nested-leech-24" => Some(Self::NestedLeech24),
            "quip-e8" => Some(Self::QuipE8),
            "nf4-ssd-oracle" => Some(Self::Nf4SsdOracle),
            "residual-sketch" => Some(Self::ResidualSketch),
            "network-cascade" => Some(Self::NetworkCascade),
            "self-evolving-adapter" => Some(Self::SelfEvolvingAdapter),
            _ => None,
        }
    }

    pub const fn primary_residency_tier(self) -> Option<ResidencyTier> {
        match self {
            Self::ExactHot => Some(ResidencyTier::L0RamHot),
            Self::LatticeWynerZivResidual => Some(ResidencyTier::L1CompressedResidual),
            Self::ShadowKvSketch => Some(ResidencyTier::L2ShadowSketch),
            Self::Nf4SsdOracle => Some(ResidencyTier::L3SsdOracle),
            Self::EngramHashRecall => Some(ResidencyTier::L4Engram),
            Self::NetworkCascade => Some(ResidencyTier::L5NetworkCascade),
            Self::SelfEvolvingAdapter => Some(ResidencyTier::LSeSelfEvolving),
            Self::BabaiGptqNearestPlane
            | Self::SherryTernary3Of4
            | Self::NestedE8
            | Self::NestedLeech24
            | Self::QuipE8
            | Self::ResidualSketch => None,
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

impl Serialize for LatticeCoderKind {
    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: Serializer,
    {
        serializer.serialize_str(self.canonical_name())
    }
}

impl<'de> Deserialize<'de> for LatticeCoderKind {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: Deserializer<'de>,
    {
        let name = String::deserialize(deserializer)?;
        Self::from_canonical_name(&name)
            .ok_or_else(|| de::Error::unknown_variant(&name, &Self::CODES))
    }
}

/// Decoder side information used by a codec's accounting row.
#[derive(Clone, Copy, Debug, Eq, PartialEq, Hash)]
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

    pub const CODES: [&'static str; 10] = [
        "None",
        "DecoderLmState",
        "ResidualStream",
        "CalibrationHessian",
        "RuntimeKvHessian",
        "ActiveSupport",
        "SsdOracle",
        "StaticFactKey",
        "NetworkTeacher",
        "SurpriseGradient",
    ];

    pub const fn key(self) -> &'static str {
        match self {
            Self::None => "None",
            Self::DecoderLmState => "DecoderLmState",
            Self::ResidualStream => "ResidualStream",
            Self::CalibrationHessian => "CalibrationHessian",
            Self::RuntimeKvHessian => "RuntimeKvHessian",
            Self::ActiveSupport => "ActiveSupport",
            Self::SsdOracle => "SsdOracle",
            Self::StaticFactKey => "StaticFactKey",
            Self::NetworkTeacher => "NetworkTeacher",
            Self::SurpriseGradient => "SurpriseGradient",
        }
    }

    pub fn from_key(key: &str) -> Option<Self> {
        match key {
            "None" => Some(Self::None),
            "DecoderLmState" => Some(Self::DecoderLmState),
            "ResidualStream" => Some(Self::ResidualStream),
            "CalibrationHessian" => Some(Self::CalibrationHessian),
            "RuntimeKvHessian" => Some(Self::RuntimeKvHessian),
            "ActiveSupport" => Some(Self::ActiveSupport),
            "SsdOracle" => Some(Self::SsdOracle),
            "StaticFactKey" => Some(Self::StaticFactKey),
            "NetworkTeacher" => Some(Self::NetworkTeacher),
            "SurpriseGradient" => Some(Self::SurpriseGradient),
            _ => None,
        }
    }

    pub const fn uses_calibration_hessian(self) -> bool {
        matches!(self, Self::CalibrationHessian)
    }

    pub const fn uses_runtime_kv_hessian(self) -> bool {
        matches!(self, Self::RuntimeKvHessian)
    }
}

impl Serialize for SideInformationKind {
    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: Serializer,
    {
        serializer.serialize_str(self.key())
    }
}

impl<'de> Deserialize<'de> for SideInformationKind {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: Deserializer<'de>,
    {
        let key = String::deserialize(deserializer)?;
        Self::from_key(&key).ok_or_else(|| de::Error::unknown_variant(&key, &Self::CODES))
    }
}

/// One row in the Lattice-Wyner-Ziv / WBO register.
#[derive(Clone, Debug, PartialEq, Serialize)]
#[serde(deny_unknown_fields)]
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
        if self.budget.rate_milli_bits_per_symbol
            != residency_tier.primary_rate_milli_bits_per_symbol()
        {
            return Err(LatticeWboError::InvalidRate);
        }
        if self.falsifier.trim().is_empty() {
            return Err(LatticeWboError::EmptyFalsifier);
        }
        if !falsifier_hooks_are_owned(&self.falsifier) {
            return Err(LatticeWboError::MissingCanonicalFalsifier);
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
        self.budget.validate_before_numerical_post_correction()?;
        if self.active_support.is_none() && residency_tier.requires_active_support_budget() {
            return Err(LatticeWboError::MissingActiveSupportBudget);
        }
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
        }
        self.budget.validate_numerical_post_correction()?;
        self.budget.validate_composition_totals()?;
        if !residency_tier
            .canonical_register_terms()
            .iter()
            .filter(|term| **term != WboTermCode::NumericalPostCorrection)
            .all(|term| {
                self.budget
                    .contributions
                    .iter()
                    .any(|contribution| contribution.term == *term)
            })
        {
            return Err(LatticeWboError::InvalidWboTermForResidencyTier);
        }
        if !has_numerical_post_correction {
            return Err(LatticeWboError::MissingNumericalPostCorrectionTerm);
        }
        Ok(())
    }
}

impl<'de> Deserialize<'de> for WboLedgerEntry {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: Deserializer<'de>,
    {
        #[derive(Deserialize)]
        #[serde(deny_unknown_fields)]
        struct RawEntry {
            memory_tier: String,
            budget: LatticeBudget,
            #[serde(default, deserialize_with = "deserialize_explicit_public_option")]
            active_support: ExplicitPublicOption<ActiveSupportBudget>,
            falsifier: String,
            caveat: String,
        }

        let raw = RawEntry::deserialize(deserializer)?;
        let active_support = raw.active_support.require("active_support")?;
        let entry = Self::new(
            raw.memory_tier,
            raw.budget,
            active_support,
            raw.falsifier,
            raw.caveat,
        );
        entry
            .validate()
            .map_err(|error| de::Error::custom(error.key()))?;
        Ok(entry)
    }
}
