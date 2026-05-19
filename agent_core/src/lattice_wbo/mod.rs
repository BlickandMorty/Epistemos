//! Lightweight Lattice-Wyner-Ziv / WBO accounting types.
//!
//! This module is deliberately ledger-only. It names codecs, budgets, side
//! information, and falsifier hooks so callers cannot hide approximation error
//! behind UAS residency or active-support terminology.

use serde::{de, Deserialize, Deserializer, Serialize, Serializer};

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

/// Register-local WBO term codes, including `T_num` for numerical correction.
#[derive(Clone, Copy, Debug, Eq, PartialEq, Hash)]
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

    pub const CODES: [&'static str; 7] = ["T_W", "T_K", "T_R", "T_Q", "T_S", "T_SE", "T_num"];

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

    pub fn from_code(code: &str) -> Option<Self> {
        match code {
            "T_W" => Some(Self::WeightRuntime),
            "T_K" => Some(Self::KvCache),
            "T_R" => Some(Self::ResidualWynerZiv),
            "T_Q" => Some(Self::Quantization),
            "T_S" => Some(Self::SubstrateBoundary),
            "T_SE" => Some(Self::SelfEvolvingSecurity),
            "T_num" => Some(Self::NumericalPostCorrection),
            _ => None,
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

impl Serialize for WboTermCode {
    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: Serializer,
    {
        serializer.serialize_str(self.code())
    }
}

impl<'de> Deserialize<'de> for WboTermCode {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: Deserializer<'de>,
    {
        let code = String::deserialize(deserializer)?;
        Self::from_code(&code).ok_or_else(|| de::Error::unknown_variant(&code, &Self::CODES))
    }
}

/// Owner for a cataloged `F-*` falsifier hook.
#[derive(Clone, Copy, Debug, Eq, PartialEq, Hash, Serialize)]
#[serde(deny_unknown_fields)]
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

impl<'de> Deserialize<'de> for FalsifierHookOwner {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: Deserializer<'de>,
    {
        #[derive(Deserialize)]
        #[serde(deny_unknown_fields)]
        struct RawFalsifierHookOwner {
            hook: String,
            owner: String,
        }

        let raw = RawFalsifierHookOwner::deserialize(deserializer)?;
        FALSIFIER_HOOK_OWNERS
            .iter()
            .copied()
            .find(|owner| owner.hook == raw.hook && owner.owner == raw.owner)
            .ok_or_else(|| de::Error::custom(LatticeWboError::MissingCanonicalFalsifier.key()))
    }
}

/// A measured or reserved contribution to the lattice/WBO ledger.
#[derive(Clone, Debug, PartialEq, Serialize)]
#[serde(deny_unknown_fields)]
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
        if self.source.trim().is_empty() {
            return None;
        }
        let measured = self.measured?;
        validate_nonnegative_finite(measured).ok()?;
        Some(measured <= self.budget)
    }
}

impl<'de> Deserialize<'de> for LatticeErrorContribution {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: Deserializer<'de>,
    {
        #[derive(Deserialize)]
        #[serde(deny_unknown_fields)]
        struct RawContribution {
            term: WboTermCode,
            source: String,
            budget: f64,
            measured: Option<f64>,
        }

        let raw = RawContribution::deserialize(deserializer)?;
        validate_nonnegative_finite(raw.budget).map_err(|error| de::Error::custom(error.key()))?;
        if raw.source.trim().is_empty() {
            return Err(de::Error::custom(LatticeWboError::EmptySource.key()));
        }
        if let Some(measured) = raw.measured {
            validate_nonnegative_finite(measured)
                .map_err(|error| de::Error::custom(error.key()))?;
        }

        Ok(Self {
            term: raw.term,
            source: raw.source,
            budget: raw.budget,
            measured: raw.measured,
        })
    }
}

/// Rate/error budget for one `LatticeCoder<BITS>`-style representation.
#[derive(Clone, Debug, PartialEq, Serialize)]
#[serde(deny_unknown_fields)]
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

    fn measured_pre_softmax_sum_after_value_validation(
        &self,
        include: impl Fn(WboTermCode) -> bool,
    ) -> Option<f64> {
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
            let measured = contribution.measured?;
            if include(contribution.term) {
                total += measured;
            }
        }
        Some(total)
    }

    fn measured_pre_softmax_total_after_value_validation(&self) -> Option<f64> {
        self.measured_pre_softmax_sum_after_value_validation(|_| true)
    }

    fn measured_softmax_half_corrected_total_after_value_validation(&self) -> Option<f64> {
        self.measured_pre_softmax_total_after_value_validation()
            .map(|total| 0.5 * total)
    }

    pub fn measured_pre_softmax_total(&self) -> Option<f64> {
        self.validate().ok()?;
        self.measured_pre_softmax_total_after_value_validation()
    }

    pub fn measured_semantic_wbo6_pre_softmax_total(&self) -> Option<f64> {
        self.validate().ok()?;
        self.measured_pre_softmax_sum_after_value_validation(WboTermCode::is_semantic_wbo6)
    }

    pub fn measured_numerical_post_correction_total(&self) -> Option<f64> {
        self.validate().ok()?;
        self.measured_pre_softmax_sum_after_value_validation(|term| {
            term == WboTermCode::NumericalPostCorrection
        })
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
        self.validate_composition_totals()
    }

    fn validate_contract_fields(&self) -> Result<(), LatticeWboError> {
        self.validate_before_numerical_post_correction()?;
        self.validate_numerical_post_correction()
    }

    fn validate_before_numerical_post_correction(&self) -> Result<(), LatticeWboError> {
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
        Ok(())
    }

    fn validate_numerical_post_correction(&self) -> Result<(), LatticeWboError> {
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
        self.validate_contract_fields()?;
        self.validate_composition_totals()
    }

    fn validate_composition_totals(&self) -> Result<(), LatticeWboError> {
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

impl<'de> Deserialize<'de> for LatticeBudget {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: Deserializer<'de>,
    {
        #[derive(Deserialize)]
        #[serde(deny_unknown_fields)]
        struct RawBudget {
            coder: LatticeCoderKind,
            rate_milli_bits_per_symbol: Option<u32>,
            side_information: SideInformationKind,
            contributions: Vec<LatticeErrorContribution>,
        }

        let raw = RawBudget::deserialize(deserializer)?;
        let budget = Self::new(
            raw.coder,
            raw.rate_milli_bits_per_symbol,
            raw.side_information,
            raw.contributions,
        );
        budget
            .validate()
            .map_err(|error| de::Error::custom(error.key()))?;
        Ok(budget)
    }
}

/// Budget for the active support selected out of a larger memory tier.
#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize)]
#[serde(deny_unknown_fields)]
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

impl<'de> Deserialize<'de> for ActiveSupportBudget {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: Deserializer<'de>,
    {
        #[derive(Deserialize)]
        #[serde(deny_unknown_fields)]
        struct RawActiveSupportBudget {
            max_active_tokens: u32,
            max_active_pages: u32,
            max_resident_bytes: u64,
            side_information: SideInformationKind,
        }

        let raw = RawActiveSupportBudget::deserialize(deserializer)?;
        let budget = Self::new(
            raw.max_active_tokens,
            raw.max_active_pages,
            raw.max_resident_bytes,
            raw.side_information,
        );
        if budget.has_zero_axis() || budget.side_information != SideInformationKind::ActiveSupport {
            return Err(de::Error::custom(
                LatticeWboError::InvalidActiveSupportSideInformation.key(),
            ));
        }
        Ok(budget)
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
            active_support: Option<ActiveSupportBudget>,
            falsifier: String,
            caveat: String,
        }

        let raw = RawEntry::deserialize(deserializer)?;
        let entry = Self::new(
            raw.memory_tier,
            raw.budget,
            raw.active_support,
            raw.falsifier,
            raw.caveat,
        );
        entry
            .validate()
            .map_err(|error| de::Error::custom(error.key()))?;
        Ok(entry)
    }
}

/// Validation failures for ledger-only lattice/WBO structures.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
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

    pub const CODES: [&'static str; 18] = [
        "InvalidBudget",
        "EmptySource",
        "EmptyMemoryTier",
        "EmptyContributions",
        "EmptyFalsifier",
        "EmptyCaveat",
        "MissingActiveSupportBudget",
        "MissingSubstrateBoundaryTerm",
        "MissingNumericalPostCorrectionTerm",
        "InvalidSideInformation",
        "InvalidActiveSupportSideInformation",
        "UnknownResidencyTier",
        "InvalidRate",
        "MissingCanonicalFalsifier",
        "InvalidWboTermForCodec",
        "InvalidBudgetComposition",
        "ResidencyCodecMismatch",
        "InvalidWboTermForResidencyTier",
    ];

    pub const fn key(self) -> &'static str {
        match self {
            Self::InvalidBudget => "InvalidBudget",
            Self::EmptySource => "EmptySource",
            Self::EmptyMemoryTier => "EmptyMemoryTier",
            Self::EmptyContributions => "EmptyContributions",
            Self::EmptyFalsifier => "EmptyFalsifier",
            Self::EmptyCaveat => "EmptyCaveat",
            Self::MissingActiveSupportBudget => "MissingActiveSupportBudget",
            Self::MissingSubstrateBoundaryTerm => "MissingSubstrateBoundaryTerm",
            Self::MissingNumericalPostCorrectionTerm => "MissingNumericalPostCorrectionTerm",
            Self::InvalidSideInformation => "InvalidSideInformation",
            Self::InvalidActiveSupportSideInformation => "InvalidActiveSupportSideInformation",
            Self::UnknownResidencyTier => "UnknownResidencyTier",
            Self::InvalidRate => "InvalidRate",
            Self::MissingCanonicalFalsifier => "MissingCanonicalFalsifier",
            Self::InvalidWboTermForCodec => "InvalidWboTermForCodec",
            Self::InvalidBudgetComposition => "InvalidBudgetComposition",
            Self::ResidencyCodecMismatch => "ResidencyCodecMismatch",
            Self::InvalidWboTermForResidencyTier => "InvalidWboTermForResidencyTier",
        }
    }

    pub fn from_key(key: &str) -> Option<Self> {
        match key {
            "InvalidBudget" => Some(Self::InvalidBudget),
            "EmptySource" => Some(Self::EmptySource),
            "EmptyMemoryTier" => Some(Self::EmptyMemoryTier),
            "EmptyContributions" => Some(Self::EmptyContributions),
            "EmptyFalsifier" => Some(Self::EmptyFalsifier),
            "EmptyCaveat" => Some(Self::EmptyCaveat),
            "MissingActiveSupportBudget" => Some(Self::MissingActiveSupportBudget),
            "MissingSubstrateBoundaryTerm" => Some(Self::MissingSubstrateBoundaryTerm),
            "MissingNumericalPostCorrectionTerm" => Some(Self::MissingNumericalPostCorrectionTerm),
            "InvalidSideInformation" => Some(Self::InvalidSideInformation),
            "InvalidActiveSupportSideInformation" => {
                Some(Self::InvalidActiveSupportSideInformation)
            }
            "UnknownResidencyTier" => Some(Self::UnknownResidencyTier),
            "InvalidRate" => Some(Self::InvalidRate),
            "MissingCanonicalFalsifier" => Some(Self::MissingCanonicalFalsifier),
            "InvalidWboTermForCodec" => Some(Self::InvalidWboTermForCodec),
            "InvalidBudgetComposition" => Some(Self::InvalidBudgetComposition),
            "ResidencyCodecMismatch" => Some(Self::ResidencyCodecMismatch),
            "InvalidWboTermForResidencyTier" => Some(Self::InvalidWboTermForResidencyTier),
            _ => None,
        }
    }
}

impl Serialize for LatticeWboError {
    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: Serializer,
    {
        serializer.serialize_str(self.key())
    }
}

impl<'de> Deserialize<'de> for LatticeWboError {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: Deserializer<'de>,
    {
        let key = String::deserialize(deserializer)?;
        Self::from_key(&key).ok_or_else(|| de::Error::unknown_variant(&key, &Self::CODES))
    }
}

fn validate_nonnegative_finite(value: f64) -> Result<(), LatticeWboError> {
    if value.is_finite() && value >= 0.0 {
        Ok(())
    } else {
        Err(LatticeWboError::InvalidBudget)
    }
}

fn contains_falsifier_hook(candidate: &str, canonical_hook: &str) -> bool {
    let canonical_hook = canonical_hook.trim();
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
    ch.is_none_or(|ch| {
        ch.is_whitespace()
            || (ch.is_ascii()
                && !(ch.is_ascii_alphanumeric() || ch == '-' || ch == '_' || ch == '/'))
    })
}

fn contains_any_falsifier_hook(candidate: &str, canonical: &str) -> bool {
    canonical
        .split(';')
        .map(str::trim)
        .filter(|hook| !hook.is_empty())
        .any(|hook| contains_falsifier_hook(candidate, hook))
}

fn f_hooks_in(candidate: &str) -> Vec<&str> {
    let mut hooks = Vec::new();
    let bytes = candidate.as_bytes();
    let mut start = 0;

    while start + 1 < bytes.len() {
        if !((bytes[start] == b'F' || bytes[start] == b'f') && bytes[start + 1] == b'-') {
            start += 1;
            continue;
        }
        if !is_falsifier_hook_boundary(candidate[..start].chars().next_back()) {
            start += 1;
            continue;
        }

        let rest = &candidate[start..];
        let end = rest
            .find(|ch: char| is_falsifier_hook_boundary(Some(ch)))
            .unwrap_or(rest.len());
        hooks.push(&rest[..end]);
        start += end;
    }
    hooks
}

fn falsifier_hooks_are_owned(candidate: &str) -> bool {
    let hooks = f_hooks_in(candidate);
    !hooks.is_empty()
        && hooks
            .into_iter()
            .all(|hook| FALSIFIER_HOOK_OWNERS.iter().any(|owner| owner.hook == hook))
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

    fn measured_probe_budget(
        coder: LatticeCoderKind,
        rate_milli_bits_per_symbol: Option<u32>,
        side_information: SideInformationKind,
    ) -> LatticeBudget {
        let mut contributions = Vec::with_capacity(coder.canonical_wbo_terms().len());
        for term in coder.canonical_wbo_terms() {
            contributions.push(
                LatticeErrorContribution::new(
                    *term,
                    format!("measured probe {}", term.code()),
                    0.0,
                )
                .expect("canonical measured probe contribution should be valid")
                .with_measured(0.0)
                .expect("canonical measured probe measurement should be valid"),
            );
        }
        LatticeBudget::new(
            coder,
            rate_milli_bits_per_symbol,
            side_information,
            contributions,
        )
    }

    fn assert_budget_measurements_pending(budget: &LatticeBudget) {
        assert_eq!(budget.measured_pre_softmax_total(), None);
        assert_eq!(budget.measured_semantic_wbo6_pre_softmax_total(), None);
        assert_eq!(budget.measured_numerical_post_correction_total(), None);
        assert_eq!(budget.measured_softmax_half_corrected_total(), None);
        assert_eq!(budget.measured_within_budget(), None);
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

    fn assert_unique_catalog_keys(mut keys: Vec<String>, label: &str) {
        keys.sort_unstable();
        for pair in keys.windows(2) {
            assert_ne!(pair[0], pair[1], "{label} must not duplicate {}", pair[0]);
        }
    }

    fn assert_json_unknown_field_rejected<T>(value: serde_json::Value, field: &str)
    where
        T: for<'de> Deserialize<'de>,
    {
        let error = match serde_json::from_value::<T>(value) {
            Ok(_) => panic!("unknown public JSON field must be rejected"),
            Err(error) => error,
        };
        let message = error.to_string();
        assert!(message.contains("unknown field"), "{message}");
        assert!(message.contains(field), "{message}");
    }

    fn assert_json_duplicate_field_rejected<T>(json: &str, field: &str)
    where
        T: for<'de> Deserialize<'de>,
    {
        let error = match serde_json::from_str::<T>(json) {
            Ok(_) => panic!("duplicate public JSON field must be rejected"),
            Err(error) => error,
        };
        let message = error.to_string();
        assert!(message.contains("duplicate field"), "{message}");
        assert!(message.contains(field), "{message}");
    }

    fn assert_json_missing_field_rejected<T>(json: &str, field: &str)
    where
        T: for<'de> Deserialize<'de>,
    {
        let error = match serde_json::from_str::<T>(json) {
            Ok(_) => panic!("missing public JSON field must be rejected"),
            Err(error) => error,
        };
        let message = error.to_string();
        assert!(message.contains("missing field"), "{message}");
        assert!(message.contains(field), "{message}");
    }

    fn assert_json_wrong_type_rejected<T>(json: &str)
    where
        T: for<'de> Deserialize<'de>,
    {
        let error = match serde_json::from_str::<T>(json) {
            Ok(_) => panic!("wrong-type public JSON field must be rejected"),
            Err(error) => error,
        };
        let message = error.to_string();
        assert!(message.contains("invalid type"), "{message}");
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
        assert!(contains_falsifier_hook(
            "`F-ULP-Oracle`, F-WBO-DriftLedger",
            "F-ULP-Oracle"
        ));
        assert!(contains_falsifier_hook(
            "(F-KV-Direct-Gate)",
            "F-KV-Direct-Gate"
        ));
        assert!(!contains_falsifier_hook("not-F-ULP-Oracle", "F-ULP-Oracle"));
        assert!(!contains_falsifier_hook("F-ULP-Oracle-v2", "F-ULP-Oracle"));
        assert!(!contains_falsifier_hook(
            "not-F-WBO-DriftLedger",
            "F-WBO-DriftLedger"
        ));
        assert!(!contains_falsifier_hook(
            "F-WBO-DriftLedger/v2",
            "F-WBO-DriftLedger"
        ));
        assert!(!contains_falsifier_hook(
            "Provider/provenance replay",
            "provider/provenance replay"
        ));
        assert!(!contains_falsifier_hook("βF-ULP-Oracle", "F-ULP-Oracle"));
        assert!(!contains_falsifier_hook("F-ULP-Oracleβ", "F-ULP-Oracle"));
        assert_eq!(f_hooks_in("F-ULP-Oracle/v2"), vec!["F-ULP-Oracle/v2"]);
        assert_eq!(
            f_hooks_in("F-WBO-DriftLedger/v2"),
            vec!["F-WBO-DriftLedger/v2"]
        );
        assert_eq!(f_hooks_in("F-ULP-Oracleβ"), vec!["F-ULP-Oracleβ"]);
        assert!(!falsifier_hooks_are_owned("F-ULP-Oracle/v2"));
        assert!(!falsifier_hooks_are_owned("F-WBO-DriftLedger/v2"));
        assert!(!falsifier_hooks_are_owned("F-ULP-Oracleβ"));
        assert!(!falsifier_hooks_are_owned("f-ulp-oracle"));
        assert!(!falsifier_hooks_are_owned("f-wbo-driftledger"));
        assert!(!falsifier_hooks_are_owned("residual KL slice"));
    }

    #[test]
    fn falsifier_hook_extraction_accepts_markdown_punctuation_boundaries() {
        let candidate =
            "[`F-ULP-Oracle`], (F-KV-Direct-Gate); {F-ACS-AnchorLookup}. <F-WBO-DriftLedger>";
        assert_eq!(
            f_hooks_in(candidate),
            vec![
                "F-ULP-Oracle",
                "F-KV-Direct-Gate",
                "F-ACS-AnchorLookup",
                "F-WBO-DriftLedger"
            ]
        );
        assert!(falsifier_hooks_are_owned(candidate));
        for hook in [
            "F-ULP-Oracle",
            "F-KV-Direct-Gate",
            "F-ACS-AnchorLookup",
            "F-WBO-DriftLedger",
        ] {
            assert!(contains_falsifier_hook(candidate, hook));
        }

        assert!(f_hooks_in("xF-ULP-Oracle").is_empty());
        assert!(!contains_falsifier_hook("xF-ULP-Oracle", "F-ULP-Oracle"));
        assert!(!contains_falsifier_hook("F-ULP-Oraclex", "F-ULP-Oracle"));
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
    fn lattice_coder_json_uses_canonical_keys_and_rejects_debug_labels() {
        let encoded =
            serde_json::to_string(&LatticeCoderKind::ALL).expect("serialize lattice coder kinds");
        let expected_keys = LatticeCoderKind::ALL
            .iter()
            .map(|coder| coder.canonical_name())
            .collect::<Vec<_>>();
        let expected_json = serde_json::to_string(&expected_keys).expect("serialize codec keys");
        assert_eq!(encoded, expected_json);

        for coder in LatticeCoderKind::ALL {
            let public_json = format!(r#""{}""#, coder.canonical_name());
            assert_eq!(
                serde_json::from_str::<LatticeCoderKind>(&public_json).expect("public codec key"),
                coder
            );

            let debug_json = format!(r#""{coder:?}""#);
            assert!(
                serde_json::from_str::<LatticeCoderKind>(&debug_json).is_err(),
                "{debug_json} must not deserialize"
            );
        }

        for spoof in [
            r#""LATTICE-WYNER-ZIV-RESIDUAL""#,
            r#""lattice_wyner_ziv_residual""#,
            r#"" lattice-wyner-ziv-residual""#,
            r#""lattice-wyner-ziv-residual ""#,
            r#""nested-e8/quip""#,
        ] {
            assert!(
                serde_json::from_str::<LatticeCoderKind>(spoof).is_err(),
                "{spoof} must not deserialize"
            );
        }
    }

    #[test]
    fn lattice_coder_canonical_names_are_trimmed_kebab_case_keys() {
        for coder in LatticeCoderKind::ALL {
            let name = coder.canonical_name();
            assert!(!name.is_empty(), "{coder:?}");
            assert_eq!(name.trim(), name, "{coder:?}");
            assert!(name.is_ascii(), "{coder:?}");
            assert_eq!(name, name.to_ascii_lowercase(), "{coder:?}");
            assert!(!name.starts_with('-'), "{coder:?}");
            assert!(!name.ends_with('-'), "{coder:?}");
            assert!(name
                .chars()
                .all(|ch| ch.is_ascii_lowercase() || ch.is_ascii_digit() || ch == '-'));
            assert_ne!(name, format!("{coder:?}"), "{coder:?}");
        }
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
    fn residency_tier_json_uses_canonical_names_and_rejects_debug_labels() {
        let encoded =
            serde_json::to_string(&ResidencyTier::ALL).expect("serialize residency tiers");
        let expected_keys = ResidencyTier::ALL
            .iter()
            .map(|tier| tier.canonical_name())
            .collect::<Vec<_>>();
        let expected_json = serde_json::to_string(&expected_keys).expect("serialize tier keys");
        assert_eq!(encoded, expected_json);

        for tier in ResidencyTier::ALL {
            let public_json = format!(r#""{}""#, tier.canonical_name());
            assert_eq!(
                serde_json::from_str::<ResidencyTier>(&public_json).expect("public residency key"),
                tier
            );

            let debug_json = format!(r#""{tier:?}""#);
            assert!(
                serde_json::from_str::<ResidencyTier>(&debug_json).is_err(),
                "{debug_json} must not deserialize"
            );
        }

        for spoof in [
            r#""L0RamHot""#,
            r#"" L0 RAM hot""#,
            r#""L0 RAM hot ""#,
            r#""l0 RAM hot""#,
            r#""LSE Self-Evolving""#,
        ] {
            assert!(
                serde_json::from_str::<ResidencyTier>(spoof).is_err(),
                "{spoof} must not deserialize"
            );
        }
    }

    #[test]
    fn lattice_wbo_error_round_trips_json() {
        let encoded =
            serde_json::to_string(&LatticeWboError::ALL).expect("serialize lattice wbo errors");
        let decoded: [LatticeWboError; 18] =
            serde_json::from_str(&encoded).expect("deserialize lattice wbo error");

        assert_eq!(decoded, LatticeWboError::ALL);
        assert_eq!(
            decoded
                .iter()
                .map(|error| format!("{error:?}"))
                .collect::<Vec<_>>(),
            vec![
                "InvalidBudget",
                "EmptySource",
                "EmptyMemoryTier",
                "EmptyContributions",
                "EmptyFalsifier",
                "EmptyCaveat",
                "MissingActiveSupportBudget",
                "MissingSubstrateBoundaryTerm",
                "MissingNumericalPostCorrectionTerm",
                "InvalidSideInformation",
                "InvalidActiveSupportSideInformation",
                "UnknownResidencyTier",
                "InvalidRate",
                "MissingCanonicalFalsifier",
                "InvalidWboTermForCodec",
                "InvalidBudgetComposition",
                "ResidencyCodecMismatch",
                "InvalidWboTermForResidencyTier",
            ]
        );
        assert!(decoded.contains(&LatticeWboError::InvalidActiveSupportSideInformation));
        assert!(decoded.contains(&LatticeWboError::MissingSubstrateBoundaryTerm));
        assert!(decoded.contains(&LatticeWboError::MissingNumericalPostCorrectionTerm));
    }

    #[test]
    fn lattice_wbo_error_json_uses_explicit_public_keys() {
        let encoded =
            serde_json::to_string(&LatticeWboError::ALL).expect("serialize lattice wbo errors");
        let expected_keys = LatticeWboError::ALL
            .iter()
            .map(|error| error.key())
            .collect::<Vec<_>>();
        let expected_json = serde_json::to_string(&expected_keys).expect("serialize error keys");
        assert_eq!(encoded, expected_json);

        for error in LatticeWboError::ALL {
            let public_json = format!(r#""{}""#, error.key());
            assert_eq!(
                serde_json::from_str::<LatticeWboError>(&public_json).expect("public error key"),
                error
            );
        }

        for spoof in [
            r#""invalidbudget""#,
            r#""Invalid Budget""#,
            r#""Invalid-Budget""#,
            r#"" InvalidBudget""#,
            r#""InvalidBudget ""#,
        ] {
            assert!(
                serde_json::from_str::<LatticeWboError>(spoof).is_err(),
                "{spoof} must not deserialize"
            );
        }
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
    fn side_information_json_uses_explicit_public_keys() {
        let encoded =
            serde_json::to_string(&SideInformationKind::ALL).expect("serialize side information");
        let expected_keys = SideInformationKind::ALL
            .iter()
            .map(|kind| kind.key())
            .collect::<Vec<_>>();
        let expected_json =
            serde_json::to_string(&expected_keys).expect("serialize side-information keys");
        assert_eq!(encoded, expected_json);

        for kind in SideInformationKind::ALL {
            let public_json = format!(r#""{}""#, kind.key());
            assert_eq!(
                serde_json::from_str::<SideInformationKind>(&public_json)
                    .expect("public side-information key"),
                kind
            );
        }

        for spoof in [
            r#""ActiveSupport ""#,
            r#"" active-support""#,
            r#""active-support""#,
            r#""RuntimeKVHessian""#,
            r#""Calibration Hessian""#,
        ] {
            assert!(
                serde_json::from_str::<SideInformationKind>(spoof).is_err(),
                "{spoof} must not deserialize"
            );
        }
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
    fn wbo_term_code_json_uses_public_axis_keys_and_rejects_debug_labels() {
        let encoded = serde_json::to_string(&WboTermCode::ALL).expect("serialize wbo terms");
        assert_eq!(encoded, r#"["T_W","T_K","T_R","T_Q","T_S","T_SE","T_num"]"#);

        for term in WboTermCode::ALL {
            let public_json = format!(r#""{}""#, term.code());
            assert_eq!(
                serde_json::from_str::<WboTermCode>(&public_json).expect("public term code"),
                term
            );

            let debug_json = format!(r#""{term:?}""#);
            assert!(
                serde_json::from_str::<WboTermCode>(&debug_json).is_err(),
                "{debug_json} must not deserialize"
            );
        }

        for spoof in [
            r#""t_w""#,
            r#""T_NUM""#,
            r#"" T_W""#,
            r#""T_W ""#,
            r#""T-SE""#,
        ] {
            assert!(
                serde_json::from_str::<WboTermCode>(spoof).is_err(),
                "{spoof} must not deserialize"
            );
        }
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
    fn lattice_error_contribution_serializes_public_accounting_keys() {
        let value =
            LatticeErrorContribution::new(WboTermCode::ResidualWynerZiv, "L1 residual gap", 0.05)
                .expect("valid residual contribution")
                .with_measured(0.02)
                .expect("valid measured contribution");
        let encoded = serde_json::to_value(&value).expect("serialize contribution");
        let object = encoded
            .as_object()
            .expect("contribution must serialize as an object");
        let mut keys = object.keys().map(String::as_str).collect::<Vec<_>>();
        keys.sort_unstable();

        assert_eq!(keys, vec!["budget", "measured", "source", "term"]);
        assert_eq!(object["term"], serde_json::json!("T_R"));
        assert_eq!(object["source"], serde_json::json!("L1 residual gap"));
        assert_eq!(object["budget"], serde_json::json!(0.05));
        assert_eq!(object["measured"], serde_json::json!(0.02));
    }

    #[test]
    fn lattice_error_contribution_serializes_pending_measurement_as_null() {
        let value =
            LatticeErrorContribution::new(WboTermCode::ResidualWynerZiv, "L1 residual gap", 0.05)
                .expect("valid residual contribution");
        let encoded = serde_json::to_value(&value).expect("serialize contribution");
        let object = encoded
            .as_object()
            .expect("contribution must serialize as an object");

        assert!(object.contains_key("measured"));
        assert_eq!(object["measured"], serde_json::Value::Null);
        assert_eq!(value.measured_within_budget(), None);
    }

    #[test]
    fn lattice_error_contribution_json_rejects_invalid_public_fields() {
        for (label, contribution) in [
            (
                "negative budget",
                serde_json::json!({
                    "term": "T_num",
                    "source": "exact ULP guard",
                    "budget": -0.01,
                    "measured": null,
                }),
            ),
            (
                "negative measured value",
                serde_json::json!({
                    "term": "T_num",
                    "source": "exact ULP guard",
                    "budget": 0.0,
                    "measured": -0.01,
                }),
            ),
            (
                "blank source",
                serde_json::json!({
                    "term": "T_num",
                    "source": " ",
                    "budget": 0.0,
                    "measured": null,
                }),
            ),
            (
                "string budget",
                serde_json::json!({
                    "term": "T_num",
                    "source": "exact ULP guard",
                    "budget": "0.0",
                    "measured": null,
                }),
            ),
            (
                "boolean budget",
                serde_json::json!({
                    "term": "T_num",
                    "source": "exact ULP guard",
                    "budget": true,
                    "measured": null,
                }),
            ),
            (
                "object budget",
                serde_json::json!({
                    "term": "T_num",
                    "source": "exact ULP guard",
                    "budget": { "value": 0.0 },
                    "measured": null,
                }),
            ),
            (
                "array budget",
                serde_json::json!({
                    "term": "T_num",
                    "source": "exact ULP guard",
                    "budget": [0.0],
                    "measured": null,
                }),
            ),
            (
                "string measured value",
                serde_json::json!({
                    "term": "T_num",
                    "source": "exact ULP guard",
                    "budget": 0.0,
                    "measured": "0.0",
                }),
            ),
            (
                "boolean measured value",
                serde_json::json!({
                    "term": "T_num",
                    "source": "exact ULP guard",
                    "budget": 0.0,
                    "measured": false,
                }),
            ),
            (
                "object measured value",
                serde_json::json!({
                    "term": "T_num",
                    "source": "exact ULP guard",
                    "budget": 0.0,
                    "measured": { "value": 0.0 },
                }),
            ),
            (
                "array measured value",
                serde_json::json!({
                    "term": "T_num",
                    "source": "exact ULP guard",
                    "budget": 0.0,
                    "measured": [0.0],
                }),
            ),
        ] {
            assert!(
                serde_json::from_value::<LatticeErrorContribution>(contribution).is_err(),
                "{label} must not deserialize as a public contribution"
            );
        }

        let pending_measurement = serde_json::json!({
            "term": "T_num",
            "source": "exact ULP guard",
            "budget": 0.0,
            "measured": null,
        });
        assert!(
            serde_json::from_value::<LatticeErrorContribution>(pending_measurement).is_ok(),
            "null measured remains the public pending-measurement form"
        );
    }

    #[test]
    fn lattice_budget_round_trips_json() {
        let residual_contribution = LatticeErrorContribution::new(
            WboTermCode::ResidualWynerZiv,
            "LWZ residual codec",
            0.04,
        )
        .expect("valid contribution");
        let numerical_contribution = LatticeErrorContribution::new(
            WboTermCode::NumericalPostCorrection,
            "exact ULP guard",
            0.0,
        )
        .expect("valid numerical contribution");
        let value = LatticeBudget::new(
            LatticeCoderKind::LatticeWynerZivResidual,
            Some(1250),
            SideInformationKind::ResidualStream,
            vec![residual_contribution, numerical_contribution],
        );

        let encoded = serde_json::to_string(&value).expect("serialize budget");
        let decoded: LatticeBudget = serde_json::from_str(&encoded).expect("deserialize budget");

        assert_eq!(decoded, value);
        assert_eq!(decoded.pre_softmax_budget(), 0.04);
        assert_eq!(decoded.softmax_half_corrected_budget(), 0.02);
    }

    #[test]
    fn lattice_budget_serializes_public_accounting_keys() {
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
        let encoded = serde_json::to_value(&value).expect("serialize budget");
        let object = encoded
            .as_object()
            .expect("budget must serialize as an object");
        let mut keys = object.keys().map(String::as_str).collect::<Vec<_>>();
        keys.sort_unstable();

        assert_eq!(
            keys,
            vec![
                "coder",
                "contributions",
                "rate_milli_bits_per_symbol",
                "side_information",
            ]
        );
        assert_eq!(
            object["coder"],
            serde_json::json!("lattice-wyner-ziv-residual")
        );
        assert_eq!(
            object["rate_milli_bits_per_symbol"],
            serde_json::json!(1250)
        );
        assert_eq!(
            object["side_information"],
            serde_json::json!("ResidualStream")
        );
        assert!(object["contributions"].is_array());
    }

    #[test]
    fn lattice_budget_serializes_non_rate_rate_field_as_null() {
        let contribution = LatticeErrorContribution::new(
            WboTermCode::NumericalPostCorrection,
            "exact ULP guard",
            0.0,
        )
        .expect("valid numerical contribution");
        let value = LatticeBudget::new(
            LatticeCoderKind::ExactHot,
            None,
            SideInformationKind::None,
            vec![contribution],
        );
        let encoded = serde_json::to_value(&value).expect("serialize budget");
        let object = encoded
            .as_object()
            .expect("budget must serialize as an object");

        assert!(object.contains_key("rate_milli_bits_per_symbol"));
        assert_eq!(
            object["rate_milli_bits_per_symbol"],
            serde_json::Value::Null
        );
        assert!(value.validate().is_ok());
    }

    #[test]
    fn lattice_budget_json_rejects_unsigned_rate_spoofs() {
        fn budget_with_rate(rate: serde_json::Value) -> serde_json::Value {
            serde_json::json!({
                "coder": "nested-e8",
                "rate_milli_bits_per_symbol": rate,
                "side_information": "CalibrationHessian",
                "contributions": [
                    {
                        "term": "T_W",
                        "source": "NestedE8 weight lattice",
                        "budget": 0.01,
                        "measured": null,
                    },
                    {
                        "term": "T_Q",
                        "source": "NestedE8 quantization lattice",
                        "budget": 0.01,
                        "measured": null,
                    },
                    {
                        "term": "T_num",
                        "source": "exact ULP guard",
                        "budget": 0.0,
                        "measured": null,
                    },
                ],
            })
        }

        for (label, rate) in [
            ("negative rate", serde_json::json!(-1)),
            ("fractional rate", serde_json::json!(1250.5)),
            ("string rate", serde_json::json!("1250")),
            ("boolean rate", serde_json::json!(true)),
            ("object rate", serde_json::json!({ "milli_bits": 1250 })),
            ("array rate", serde_json::json!([1250])),
            ("oversized rate", serde_json::json!((u32::MAX as u64) + 1)),
        ] {
            assert!(
                serde_json::from_value::<LatticeBudget>(budget_with_rate(rate)).is_err(),
                "{label} must not deserialize as a lattice budget rate"
            );
        }
    }

    #[test]
    fn lattice_budget_json_rejects_invalid_public_envelopes() {
        let cases = [
            (
                "empty contributions",
                serde_json::json!({
                    "coder": "exact-hot",
                    "rate_milli_bits_per_symbol": null,
                    "side_information": "None",
                    "contributions": [],
                }),
            ),
            (
                "missing numerical guard",
                serde_json::json!({
                    "coder": "nested-e8",
                    "rate_milli_bits_per_symbol": 1250,
                    "side_information": "CalibrationHessian",
                    "contributions": [
                        {
                            "term": "T_W",
                            "source": "NestedE8 weight lattice",
                            "budget": 0.01,
                            "measured": null,
                        },
                        {
                            "term": "T_Q",
                            "source": "NestedE8 quantization lattice",
                            "budget": 0.01,
                            "measured": null,
                        },
                    ],
                }),
            ),
            (
                "wrong side information",
                serde_json::json!({
                    "coder": "exact-hot",
                    "rate_milli_bits_per_symbol": null,
                    "side_information": "ActiveSupport",
                    "contributions": [{
                        "term": "T_num",
                        "source": "exact ULP guard",
                        "budget": 0.0,
                        "measured": null,
                    }],
                }),
            ),
        ];

        for (label, budget) in cases {
            assert!(
                serde_json::from_value::<LatticeBudget>(budget).is_err(),
                "{label} must not deserialize as a public lattice budget"
            );
        }
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
    fn active_support_budget_serializes_public_accounting_keys() {
        let value = ActiveSupportBudget::new(
            4096,
            64,
            256 * 1024 * 1024,
            SideInformationKind::ActiveSupport,
        );
        let encoded = serde_json::to_value(value).expect("serialize active support budget");
        let object = encoded
            .as_object()
            .expect("active support budget must serialize as an object");
        let mut keys = object.keys().map(String::as_str).collect::<Vec<_>>();
        keys.sort_unstable();

        assert_eq!(
            keys,
            vec![
                "max_active_pages",
                "max_active_tokens",
                "max_resident_bytes",
                "side_information",
            ]
        );
        assert_eq!(object["max_active_tokens"], serde_json::json!(4096));
        assert_eq!(object["max_active_pages"], serde_json::json!(64));
        assert_eq!(object["max_resident_bytes"], serde_json::json!(268_435_456));
        assert_eq!(
            object["side_information"],
            serde_json::json!("ActiveSupport")
        );
    }

    #[test]
    fn active_support_budget_json_rejects_unsigned_axis_spoofs() {
        let cases = [
            (
                "negative token axis",
                serde_json::json!({
                    "max_active_tokens": -1,
                    "max_active_pages": 1,
                    "max_resident_bytes": 1,
                    "side_information": "ActiveSupport",
                }),
            ),
            (
                "fractional page axis",
                serde_json::json!({
                    "max_active_tokens": 1,
                    "max_active_pages": 1.5,
                    "max_resident_bytes": 1,
                    "side_information": "ActiveSupport",
                }),
            ),
            (
                "string resident-byte axis",
                serde_json::json!({
                    "max_active_tokens": 1,
                    "max_active_pages": 1,
                    "max_resident_bytes": "1",
                    "side_information": "ActiveSupport",
                }),
            ),
            (
                "boolean token axis",
                serde_json::json!({
                    "max_active_tokens": true,
                    "max_active_pages": 1,
                    "max_resident_bytes": 1,
                    "side_information": "ActiveSupport",
                }),
            ),
            (
                "object resident-byte axis",
                serde_json::json!({
                    "max_active_tokens": 1,
                    "max_active_pages": 1,
                    "max_resident_bytes": { "bytes": 1 },
                    "side_information": "ActiveSupport",
                }),
            ),
            (
                "array page axis",
                serde_json::json!({
                    "max_active_tokens": 1,
                    "max_active_pages": [1],
                    "max_resident_bytes": 1,
                    "side_information": "ActiveSupport",
                }),
            ),
            (
                "oversized token axis",
                serde_json::json!({
                    "max_active_tokens": (u32::MAX as u64) + 1,
                    "max_active_pages": 1,
                    "max_resident_bytes": 1,
                    "side_information": "ActiveSupport",
                }),
            ),
            (
                "oversized page axis",
                serde_json::json!({
                    "max_active_tokens": 1,
                    "max_active_pages": (u32::MAX as u64) + 1,
                    "max_resident_bytes": 1,
                    "side_information": "ActiveSupport",
                }),
            ),
        ];

        for (label, value) in cases {
            assert!(
                serde_json::from_value::<ActiveSupportBudget>(value).is_err(),
                "{label} must not deserialize as an active-support budget"
            );
        }

        let oversized_resident_bytes = r#"{
            "max_active_tokens": 1,
            "max_active_pages": 1,
            "max_resident_bytes": 18446744073709551616,
            "side_information": "ActiveSupport"
        }"#;
        assert!(
            serde_json::from_str::<ActiveSupportBudget>(oversized_resident_bytes).is_err(),
            "oversized resident-byte axis must not deserialize as an active-support budget"
        );
    }

    #[test]
    fn active_support_budget_json_rejects_invalid_public_budget() {
        let cases = [
            (
                "zero token axis",
                serde_json::json!({
                    "max_active_tokens": 0,
                    "max_active_pages": 1,
                    "max_resident_bytes": 1,
                    "side_information": "ActiveSupport",
                }),
            ),
            (
                "zero page axis",
                serde_json::json!({
                    "max_active_tokens": 1,
                    "max_active_pages": 0,
                    "max_resident_bytes": 1,
                    "side_information": "ActiveSupport",
                }),
            ),
            (
                "zero resident-byte axis",
                serde_json::json!({
                    "max_active_tokens": 1,
                    "max_active_pages": 1,
                    "max_resident_bytes": 0,
                    "side_information": "ActiveSupport",
                }),
            ),
            (
                "wrong side information",
                serde_json::json!({
                    "max_active_tokens": 1,
                    "max_active_pages": 1,
                    "max_resident_bytes": 1,
                    "side_information": "ResidualStream",
                }),
            ),
        ];

        for (label, value) in cases {
            assert!(
                serde_json::from_value::<ActiveSupportBudget>(value).is_err(),
                "{label} must not deserialize as a public active-support budget"
            );
        }
    }

    #[test]
    fn wbo_ledger_entry_round_trips_json() {
        let budget = LatticeBudget::new(
            LatticeCoderKind::ShadowKvSketch,
            None,
            SideInformationKind::ActiveSupport,
            tier_probe_contributions(ResidencyTier::L2ShadowSketch),
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
            "F-WBO-DriftLedger; F-ULP-Oracle; F-KV-Direct-Gate; F-ACS-AnchorLookup",
            "Active support is accounting metadata, not a speed claim.",
        );

        let encoded = serde_json::to_string(&value).expect("serialize ledger entry");
        let decoded: WboLedgerEntry =
            serde_json::from_str(&encoded).expect("deserialize ledger entry");

        assert_eq!(decoded, value);
        assert_eq!(
            decoded.wbo_terms(),
            vec![
                WboTermCode::KvCache,
                WboTermCode::SubstrateBoundary,
                WboTermCode::NumericalPostCorrection,
            ]
        );
    }

    #[test]
    fn wbo_ledger_entry_json_rejects_invalid_public_rows() {
        fn exact_hot_entry(memory_tier: &str, falsifier: &str, caveat: &str) -> serde_json::Value {
            serde_json::json!({
                "memory_tier": memory_tier,
                "budget": {
                    "coder": "exact-hot",
                    "rate_milli_bits_per_symbol": null,
                    "side_information": "None",
                    "contributions": [{
                        "term": "T_num",
                        "source": "exact ULP guard",
                        "budget": 0.0,
                        "measured": null,
                    }],
                },
                "active_support": null,
                "falsifier": falsifier,
                "caveat": caveat,
            })
        }

        fn shadow_entry(active_support: serde_json::Value) -> serde_json::Value {
            serde_json::json!({
                "memory_tier": "L2 Shadow Sketch",
                "budget": {
                    "coder": "shadow-kv-sketch",
                    "rate_milli_bits_per_symbol": null,
                    "side_information": "ActiveSupport",
                    "contributions": [
                        {
                            "term": "T_S",
                            "source": "ShadowKV support",
                            "budget": 0.01,
                            "measured": null,
                        },
                        {
                            "term": "T_num",
                            "source": "exact ULP guard",
                            "budget": 0.0,
                            "measured": null,
                        },
                    ],
                },
                "active_support": active_support,
                "falsifier": "F-WBO-DriftLedger; F-ULP-Oracle; F-KV-Direct-Gate; F-ACS-AnchorLookup",
                "caveat": "Active support is accounting metadata, not a speed claim.",
            })
        }

        let cases = [
            (
                "blank memory tier",
                exact_hot_entry(
                    " ",
                    "F-WBO-DriftLedger; F-ULP-Oracle",
                    "Exact hot rows still need numerical post-correction.",
                ),
            ),
            (
                "missing ULP oracle",
                exact_hot_entry(
                    "L0 RAM hot",
                    "F-WBO-DriftLedger",
                    "Exact hot rows still need numerical post-correction.",
                ),
            ),
            (
                "blank caveat",
                exact_hot_entry("L0 RAM hot", "F-WBO-DriftLedger; F-ULP-Oracle", " "),
            ),
            (
                "missing active support",
                shadow_entry(serde_json::Value::Null),
            ),
        ];

        for (label, entry) in cases {
            assert!(
                serde_json::from_value::<WboLedgerEntry>(entry).is_err(),
                "{label} must not deserialize as a public WBO ledger row"
            );
        }
    }

    #[test]
    fn wbo_ledger_entry_serializes_public_accounting_keys() {
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
        let encoded = serde_json::to_value(&value).expect("serialize ledger entry");
        let object = encoded
            .as_object()
            .expect("ledger entry must serialize as an object");
        let mut keys = object.keys().map(String::as_str).collect::<Vec<_>>();
        keys.sort_unstable();

        assert_eq!(
            keys,
            vec![
                "active_support",
                "budget",
                "caveat",
                "falsifier",
                "memory_tier"
            ]
        );
        assert_eq!(object["memory_tier"], serde_json::json!("L2 Shadow Sketch"));
        assert!(object["budget"].is_object());
        assert!(object["active_support"].is_object());
        assert_eq!(object["falsifier"], serde_json::json!("F-WBO-DriftLedger"));
        assert_eq!(
            object["caveat"],
            serde_json::json!("Active support is accounting metadata, not a speed claim.")
        );
    }

    #[test]
    fn public_accounting_json_rejects_unknown_fields() {
        let contribution = serde_json::json!({
            "term": "T_num",
            "source": "exact ULP guard",
            "budget": 0.0,
            "measured": null,
            "debug": "ignored field",
        });
        assert_json_unknown_field_rejected::<LatticeErrorContribution>(contribution, "debug");

        let budget = serde_json::json!({
            "coder": "exact-hot",
            "rate_milli_bits_per_symbol": null,
            "side_information": "None",
            "contributions": [{
                "term": "T_num",
                "source": "exact ULP guard",
                "budget": 0.0,
                "measured": null,
            }],
            "memory_tier": "L0 RAM hot",
        });
        assert_json_unknown_field_rejected::<LatticeBudget>(budget, "memory_tier");

        let support = serde_json::json!({
            "max_active_tokens": 1,
            "max_active_pages": 1,
            "max_resident_bytes": 1,
            "side_information": "ActiveSupport",
            "codec": "shadow-kv-sketch",
        });
        assert_json_unknown_field_rejected::<ActiveSupportBudget>(support, "codec");

        let entry = serde_json::json!({
            "memory_tier": "L0 RAM hot",
            "budget": {
                "coder": "exact-hot",
                "rate_milli_bits_per_symbol": null,
                "side_information": "None",
                "contributions": [{
                    "term": "T_num",
                    "source": "exact ULP guard",
                    "budget": 0.0,
                    "measured": null,
                }],
            },
            "active_support": null,
            "falsifier": "F-WBO-DriftLedger + F-ULP-Oracle",
            "caveat": "Exact hot rows still need numerical post-correction.",
            "residency_tier": "L0RamHot",
        });
        assert_json_unknown_field_rejected::<WboLedgerEntry>(entry, "residency_tier");
    }

    #[test]
    fn public_accounting_json_rejects_nested_unknown_fields() {
        let budget = serde_json::json!({
            "coder": "exact-hot",
            "rate_milli_bits_per_symbol": null,
            "side_information": "None",
            "contributions": [{
                "term": "T_num",
                "source": "exact ULP guard",
                "budget": 0.0,
                "measured": null,
                "debug": "nested field",
            }],
        });
        assert_json_unknown_field_rejected::<LatticeBudget>(budget, "debug");

        let entry = serde_json::json!({
            "memory_tier": "L2 Shadow Sketch",
            "budget": {
                "coder": "shadow-kv-sketch",
                "rate_milli_bits_per_symbol": null,
                "side_information": "ActiveSupport",
                "contributions": [
                    {
                        "term": "T_S",
                        "source": "ShadowKV support",
                        "budget": 0.01,
                        "measured": null,
                    },
                    {
                        "term": "T_num",
                        "source": "exact ULP guard",
                        "budget": 0.0,
                        "measured": null,
                    },
                ],
            },
            "active_support": {
                "max_active_tokens": 1,
                "max_active_pages": 1,
                "max_resident_bytes": 1,
                "side_information": "ActiveSupport",
                "codec": "shadow-kv-sketch",
            },
            "falsifier": "F-WBO-DriftLedger; F-ACS-AnchorLookup; F-ULP-Oracle",
            "caveat": "Active support must be explicitly budgeted.",
        });
        assert_json_unknown_field_rejected::<WboLedgerEntry>(entry, "codec");
    }

    #[test]
    fn public_accounting_json_rejects_duplicate_public_keys() {
        assert_json_duplicate_field_rejected::<LatticeErrorContribution>(
            r#"{
                "term": "T_num",
                "source": "exact ULP guard",
                "source": "shadowed source",
                "budget": 0.0,
                "measured": null
            }"#,
            "source",
        );
        assert_json_duplicate_field_rejected::<LatticeBudget>(
            r#"{
                "coder": "exact-hot",
                "coder": "shadow-kv-sketch",
                "rate_milli_bits_per_symbol": null,
                "side_information": "None",
                "contributions": [{
                    "term": "T_num",
                    "source": "exact ULP guard",
                    "budget": 0.0,
                    "measured": null
                }]
            }"#,
            "coder",
        );
        assert_json_duplicate_field_rejected::<ActiveSupportBudget>(
            r#"{
                "max_active_tokens": 1,
                "max_active_pages": 1,
                "max_active_pages": 2,
                "max_resident_bytes": 1,
                "side_information": "ActiveSupport"
            }"#,
            "max_active_pages",
        );
        assert_json_duplicate_field_rejected::<WboLedgerEntry>(
            r#"{
                "memory_tier": "L0 RAM hot",
                "budget": {
                    "coder": "exact-hot",
                    "rate_milli_bits_per_symbol": null,
                    "side_information": "None",
                    "contributions": [{
                        "term": "T_num",
                        "source": "exact ULP guard",
                        "budget": 0.0,
                        "measured": null
                    }]
                },
                "active_support": null,
                "falsifier": "F-WBO-DriftLedger; F-ULP-Oracle",
                "falsifier": "F-WBO-DriftLedger",
                "caveat": "Exact hot rows still need numerical post-correction."
            }"#,
            "falsifier",
        );
        assert_json_duplicate_field_rejected::<FalsifierHookOwner>(
            r#"{
                "hook": "F-ULP-Oracle",
                "hook": "F-WBO-DriftLedger",
                "owner": "agent_core/src/research/eml/ulp_oracle.rs"
            }"#,
            "hook",
        );
    }

    #[test]
    fn public_accounting_json_rejects_missing_required_keys() {
        assert_json_missing_field_rejected::<LatticeErrorContribution>(
            r#"{
                "term": "T_num",
                "budget": 0.0,
                "measured": null
            }"#,
            "source",
        );
        assert_json_missing_field_rejected::<LatticeBudget>(
            r#"{
                "coder": "exact-hot",
                "rate_milli_bits_per_symbol": null,
                "side_information": "None"
            }"#,
            "contributions",
        );
        assert_json_missing_field_rejected::<ActiveSupportBudget>(
            r#"{
                "max_active_tokens": 1,
                "max_active_pages": 1,
                "max_resident_bytes": 1
            }"#,
            "side_information",
        );
        assert_json_missing_field_rejected::<WboLedgerEntry>(
            r#"{
                "memory_tier": "L0 RAM hot",
                "budget": {
                    "coder": "exact-hot",
                    "rate_milli_bits_per_symbol": null,
                    "side_information": "None",
                    "contributions": [{
                        "term": "T_num",
                        "source": "exact ULP guard",
                        "budget": 0.0,
                        "measured": null
                    }]
                },
                "active_support": null,
                "falsifier": "F-WBO-DriftLedger; F-ULP-Oracle"
            }"#,
            "caveat",
        );
        assert_json_missing_field_rejected::<FalsifierHookOwner>(
            r#"{
                "hook": "F-ULP-Oracle"
            }"#,
            "owner",
        );
    }

    #[test]
    fn public_accounting_json_rejects_wrong_type_public_fields() {
        assert_json_wrong_type_rejected::<LatticeErrorContribution>(
            r#"{
                "term": ["T_num"],
                "source": "exact ULP guard",
                "budget": 0.0,
                "measured": null
            }"#,
        );
        assert_json_wrong_type_rejected::<LatticeErrorContribution>(
            r#"{
                "term": "T_num",
                "source": ["exact ULP guard"],
                "budget": 0.0,
                "measured": null
            }"#,
        );
        assert_json_wrong_type_rejected::<LatticeBudget>(
            r#"{
                "coder": {"key": "exact-hot"},
                "rate_milli_bits_per_symbol": null,
                "side_information": "None",
                "contributions": [{
                    "term": "T_num",
                    "source": "exact ULP guard",
                    "budget": 0.0,
                    "measured": null
                }]
            }"#,
        );
        assert_json_wrong_type_rejected::<LatticeBudget>(
            r#"{
                "coder": "exact-hot",
                "rate_milli_bits_per_symbol": null,
                "side_information": 0,
                "contributions": [{
                    "term": "T_num",
                    "source": "exact ULP guard",
                    "budget": 0.0,
                    "measured": null
                }]
            }"#,
        );
        assert_json_wrong_type_rejected::<LatticeBudget>(
            r#"{
                "coder": "exact-hot",
                "rate_milli_bits_per_symbol": null,
                "side_information": "None",
                "contributions": {
                    "term": "T_num",
                    "source": "exact ULP guard",
                    "budget": 0.0,
                    "measured": null
                }
            }"#,
        );
        assert_json_wrong_type_rejected::<ActiveSupportBudget>(
            r#"{
                "max_active_tokens": 1,
                "max_active_pages": 1,
                "max_resident_bytes": 1,
                "side_information": false
            }"#,
        );
        assert_json_wrong_type_rejected::<WboLedgerEntry>(
            r#"{
                "memory_tier": ["L0 RAM hot"],
                "budget": {
                    "coder": "exact-hot",
                    "rate_milli_bits_per_symbol": null,
                    "side_information": "None",
                    "contributions": [{
                        "term": "T_num",
                        "source": "exact ULP guard",
                        "budget": 0.0,
                        "measured": null
                    }]
                },
                "active_support": null,
                "falsifier": "F-WBO-DriftLedger; F-ULP-Oracle",
                "caveat": "Exact hot rows still need numerical post-correction."
            }"#,
        );
        assert_json_wrong_type_rejected::<WboLedgerEntry>(
            r#"{
                "memory_tier": "L0 RAM hot",
                "budget": true,
                "active_support": null,
                "falsifier": "F-WBO-DriftLedger; F-ULP-Oracle",
                "caveat": "Exact hot rows still need numerical post-correction."
            }"#,
        );
        assert_json_wrong_type_rejected::<WboLedgerEntry>(
            r#"{
                "memory_tier": "L0 RAM hot",
                "budget": {
                    "coder": "exact-hot",
                    "rate_milli_bits_per_symbol": null,
                    "side_information": "None",
                    "contributions": [{
                        "term": "T_num",
                        "source": "exact ULP guard",
                        "budget": 0.0,
                        "measured": null
                    }]
                },
                "active_support": true,
                "falsifier": "F-WBO-DriftLedger; F-ULP-Oracle",
                "caveat": "Exact hot rows still need numerical post-correction."
            }"#,
        );
        assert_json_wrong_type_rejected::<WboLedgerEntry>(
            r#"{
                "memory_tier": "L0 RAM hot",
                "budget": {
                    "coder": "exact-hot",
                    "rate_milli_bits_per_symbol": null,
                    "side_information": "None",
                    "contributions": [{
                        "term": "T_num",
                        "source": "exact ULP guard",
                        "budget": 0.0,
                        "measured": null
                    }]
                },
                "active_support": null,
                "falsifier": 1,
                "caveat": "Exact hot rows still need numerical post-correction."
            }"#,
        );
        assert_json_wrong_type_rejected::<FalsifierHookOwner>(
            r#"{
                "hook": ["F-ULP-Oracle"],
                "owner": "agent_core/src/research/eml/ulp_oracle.rs"
            }"#,
        );
        assert_json_wrong_type_rejected::<FalsifierHookOwner>(
            r#"{
                "hook": "F-ULP-Oracle",
                "owner": {"path": "agent_core/src/research/eml/ulp_oracle.rs"}
            }"#,
        );
    }

    #[test]
    fn wbo_ledger_entry_serializes_absent_active_support_as_null() {
        let contribution = LatticeErrorContribution::new(
            WboTermCode::NumericalPostCorrection,
            "exact ULP guard",
            0.0,
        )
        .expect("valid numerical contribution");
        let budget = LatticeBudget::new(
            LatticeCoderKind::ExactHot,
            None,
            SideInformationKind::None,
            vec![contribution],
        );
        let value = WboLedgerEntry::new(
            "L0 RAM hot",
            budget,
            None,
            "F-WBO-DriftLedger; F-ULP-Oracle",
            "Exact hot is the reference path, not a compression claim.",
        );
        let encoded = serde_json::to_value(&value).expect("serialize ledger entry");
        let object = encoded
            .as_object()
            .expect("ledger entry must serialize as an object");

        assert!(object.contains_key("active_support"));
        assert_eq!(object["active_support"], serde_json::Value::Null);
        assert!(value.validate().is_ok());
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
        assert_eq!(
            LatticeCoderKind::ALL
                .iter()
                .map(|coder| coder.canonical_name())
                .collect::<Vec<_>>(),
            vec![
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
            ]
        );
        assert_eq!(
            SideInformationKind::ALL
                .iter()
                .map(|side_information| format!("{side_information:?}"))
                .collect::<Vec<_>>(),
            vec![
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
            ]
        );
        assert!(SideInformationKind::ALL.contains(&SideInformationKind::CalibrationHessian));
        assert!(SideInformationKind::ALL.contains(&SideInformationKind::RuntimeKvHessian));
        assert!(SideInformationKind::ALL.contains(&SideInformationKind::ActiveSupport));
        assert!(SideInformationKind::ALL.contains(&SideInformationKind::StaticFactKey));
    }

    #[test]
    fn typed_all_catalogs_have_unique_public_keys() {
        assert_unique_catalog_keys(
            ResidencyTier::CODES
                .iter()
                .map(|key| (*key).to_owned())
                .collect(),
            "ResidencyTier::CODES public keys",
        );
        assert_unique_catalog_keys(
            LatticeCoderKind::ALL
                .iter()
                .map(|coder| coder.canonical_name().to_owned())
                .collect(),
            "LatticeCoderKind::ALL canonical names",
        );
        assert_unique_catalog_keys(
            LatticeCoderKind::CODES
                .iter()
                .map(|key| (*key).to_owned())
                .collect(),
            "LatticeCoderKind::CODES public keys",
        );
        assert_unique_catalog_keys(
            LatticeCoderKind::ALL
                .iter()
                .map(|coder| format!("{coder:?}"))
                .collect(),
            "LatticeCoderKind::ALL debug row keys",
        );
        assert_unique_catalog_keys(
            SideInformationKind::CODES
                .iter()
                .map(|key| (*key).to_owned())
                .collect(),
            "SideInformationKind::CODES public keys",
        );
        assert_unique_catalog_keys(
            WboTermCode::CODES
                .iter()
                .map(|key| (*key).to_owned())
                .collect(),
            "WboTermCode::CODES public keys",
        );
        assert_unique_catalog_keys(
            LatticeWboError::CODES
                .iter()
                .map(|key| (*key).to_owned())
                .collect(),
            "LatticeWboError::CODES public keys",
        );
    }

    #[test]
    fn explicit_public_key_tables_follow_all_catalog_order() {
        assert_eq!(
            ResidencyTier::CODES.to_vec(),
            ResidencyTier::ALL
                .iter()
                .map(|tier| tier.canonical_name())
                .collect::<Vec<_>>()
        );
        assert_eq!(
            LatticeCoderKind::CODES.to_vec(),
            LatticeCoderKind::ALL
                .iter()
                .map(|coder| coder.canonical_name())
                .collect::<Vec<_>>()
        );
        assert_eq!(
            SideInformationKind::CODES.to_vec(),
            SideInformationKind::ALL
                .iter()
                .map(|kind| kind.key())
                .collect::<Vec<_>>()
        );
        assert_eq!(
            WboTermCode::CODES.to_vec(),
            WboTermCode::ALL
                .iter()
                .map(|term| term.code())
                .collect::<Vec<_>>()
        );
        assert_eq!(
            LatticeWboError::CODES.to_vec(),
            LatticeWboError::ALL
                .iter()
                .map(|error| error.key())
                .collect::<Vec<_>>()
        );
    }

    #[test]
    fn public_key_registries_deserialize_from_owned_json_values() {
        assert_eq!(
            serde_json::from_value::<ResidencyTier>(serde_json::json!("L0 RAM hot"))
                .expect("owned residency key value"),
            ResidencyTier::L0RamHot
        );
        assert_eq!(
            serde_json::from_value::<LatticeCoderKind>(serde_json::json!(
                "lattice-wyner-ziv-residual"
            ))
            .expect("owned codec key value"),
            LatticeCoderKind::LatticeWynerZivResidual
        );
        assert_eq!(
            serde_json::from_value::<SideInformationKind>(serde_json::json!("ResidualStream"))
                .expect("owned side-information key value"),
            SideInformationKind::ResidualStream
        );
        assert_eq!(
            serde_json::from_value::<WboTermCode>(serde_json::json!("T_num"))
                .expect("owned term key value"),
            WboTermCode::NumericalPostCorrection
        );
        assert_eq!(
            serde_json::from_value::<LatticeWboError>(serde_json::json!(
                "InvalidBudgetComposition"
            ))
            .expect("owned error key value"),
            LatticeWboError::InvalidBudgetComposition
        );
    }

    #[test]
    fn public_key_registries_reject_wrong_type_json_values() {
        assert_json_wrong_type_rejected::<ResidencyTier>(r#"["L0 RAM hot"]"#);
        assert_json_wrong_type_rejected::<LatticeCoderKind>(r#"{"codec": "exact-hot"}"#);
        assert_json_wrong_type_rejected::<SideInformationKind>(r#"0"#);
        assert_json_wrong_type_rejected::<WboTermCode>(r#"true"#);
        assert_json_wrong_type_rejected::<LatticeWboError>(r#"null"#);
    }

    #[test]
    fn public_key_registries_reject_cross_registry_keys() {
        fn reject_keys<T>(registry: &str, keys: Vec<&'static str>)
        where
            T: for<'de> Deserialize<'de>,
        {
            for key in keys {
                assert!(
                    serde_json::from_value::<T>(serde_json::json!(key)).is_err(),
                    "{registry} accepted cross-registry key {key}"
                );
            }
        }

        reject_keys::<ResidencyTier>(
            "ResidencyTier",
            [
                &LatticeCoderKind::CODES[..],
                &SideInformationKind::CODES[..],
                &WboTermCode::CODES[..],
                &LatticeWboError::CODES[..],
            ]
            .concat(),
        );
        reject_keys::<LatticeCoderKind>(
            "LatticeCoderKind",
            [
                &ResidencyTier::CODES[..],
                &SideInformationKind::CODES[..],
                &WboTermCode::CODES[..],
                &LatticeWboError::CODES[..],
            ]
            .concat(),
        );
        reject_keys::<SideInformationKind>(
            "SideInformationKind",
            [
                &ResidencyTier::CODES[..],
                &LatticeCoderKind::CODES[..],
                &WboTermCode::CODES[..],
                &LatticeWboError::CODES[..],
            ]
            .concat(),
        );
        reject_keys::<WboTermCode>(
            "WboTermCode",
            [
                &ResidencyTier::CODES[..],
                &LatticeCoderKind::CODES[..],
                &SideInformationKind::CODES[..],
                &LatticeWboError::CODES[..],
            ]
            .concat(),
        );
        reject_keys::<LatticeWboError>(
            "LatticeWboError",
            [
                &ResidencyTier::CODES[..],
                &LatticeCoderKind::CODES[..],
                &SideInformationKind::CODES[..],
                &WboTermCode::CODES[..],
            ]
            .concat(),
        );
    }

    #[test]
    fn public_key_registries_reject_unicode_adjacent_public_keys() {
        fn reject_unicode_adjacent_keys<T>(registry: &str, keys: &[&str])
        where
            T: for<'de> Deserialize<'de>,
        {
            for key in keys {
                for spoof in [format!("β{key}"), format!("{key}β")] {
                    assert!(
                        serde_json::from_value::<T>(serde_json::json!(spoof)).is_err(),
                        "{registry} accepted unicode-adjacent key {key}"
                    );
                }
            }
        }

        reject_unicode_adjacent_keys::<ResidencyTier>("ResidencyTier", &ResidencyTier::CODES);
        reject_unicode_adjacent_keys::<LatticeCoderKind>(
            "LatticeCoderKind",
            &LatticeCoderKind::CODES,
        );
        reject_unicode_adjacent_keys::<SideInformationKind>(
            "SideInformationKind",
            &SideInformationKind::CODES,
        );
        reject_unicode_adjacent_keys::<WboTermCode>("WboTermCode", &WboTermCode::CODES);
        reject_unicode_adjacent_keys::<LatticeWboError>("LatticeWboError", &LatticeWboError::CODES);
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
    fn ledger_validation_rejects_missing_active_support_before_missing_t_num() {
        let contributions = vec![
            LatticeErrorContribution::new(WboTermCode::KvCache, "ShadowKV cache", 0.01)
                .expect("valid cache contribution"),
            LatticeErrorContribution::new(WboTermCode::SubstrateBoundary, "ShadowKV support", 0.01)
                .expect("valid support contribution"),
        ];
        let budget = LatticeBudget::new(
            LatticeCoderKind::ShadowKvSketch,
            None,
            SideInformationKind::ActiveSupport,
            contributions,
        );
        let missing_support = WboLedgerEntry::new_for_tier(
            ResidencyTier::L2ShadowSketch,
            budget,
            None,
            "F-WBO-DriftLedger; F-KV-Direct-Gate; F-ACS-AnchorLookup",
            "Missing required active support must not be hidden by a missing numerical guard.",
        );

        assert_eq!(
            missing_support.validate(),
            Err(LatticeWboError::MissingActiveSupportBudget)
        );
    }

    #[test]
    fn ledger_validation_rejects_malformed_active_support_before_missing_t_num() {
        let malformed_support = [
            ActiveSupportBudget::zero(SideInformationKind::ActiveSupport),
            ActiveSupportBudget::new(128, 4, 1024, SideInformationKind::ResidualStream),
        ];
        let mut checked = 0;

        for tier in ResidencyTier::ALL
            .iter()
            .copied()
            .filter(|tier| tier.allows_active_support_budget())
        {
            let contributions = tier
                .canonical_register_terms()
                .iter()
                .copied()
                .filter(|term| *term != WboTermCode::NumericalPostCorrection)
                .map(|term| {
                    LatticeErrorContribution::new(
                        term,
                        format!("{} without T_num", tier.canonical_name()),
                        0.01,
                    )
                    .expect("valid contribution")
                })
                .collect::<Vec<_>>();
            let budget = LatticeBudget::new(
                tier.primary_coder(),
                tier.primary_rate_milli_bits_per_symbol(),
                tier.primary_side_information(),
                contributions,
            );

            for active_support in malformed_support {
                let entry = WboLedgerEntry::new_for_tier(
                    tier,
                    budget.clone(),
                    Some(active_support),
                    tier.primary_falsifier(),
                    "Malformed active support must not be hidden by a missing numerical guard.",
                );

                assert_eq!(
                    entry.validate(),
                    Err(LatticeWboError::InvalidActiveSupportSideInformation),
                    "{} let missing T_num hide malformed active support {:?}",
                    tier.canonical_name(),
                    active_support
                );
                checked += 1;
            }
        }

        let allowed_tiers = ResidencyTier::ALL
            .iter()
            .filter(|tier| tier.allows_active_support_budget())
            .count();
        assert_eq!(checked, allowed_tiers * malformed_support.len());
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
        for measured in [-0.01, f64::NAN, f64::INFINITY, f64::NEG_INFINITY] {
            assert_eq!(
                contribution.clone().with_measured(measured),
                Err(LatticeWboError::InvalidBudget)
            );
        }
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
    fn active_support_budget_zero_axis_predicates_distinguish_partial_zero() {
        let zero = ActiveSupportBudget::zero(SideInformationKind::ActiveSupport);
        assert!(zero.is_zero());
        assert!(zero.has_zero_axis());

        for partial in [
            ActiveSupportBudget::new(0, 1, 1, SideInformationKind::ActiveSupport),
            ActiveSupportBudget::new(1, 0, 1, SideInformationKind::ActiveSupport),
            ActiveSupportBudget::new(1, 1, 0, SideInformationKind::ActiveSupport),
        ] {
            assert!(!partial.is_zero());
            assert!(partial.has_zero_axis());
        }

        let nonzero = ActiveSupportBudget::new(1, 1, 1, SideInformationKind::ActiveSupport);
        assert!(!nonzero.is_zero());
        assert!(!nonzero.has_zero_axis());
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
        for tier in ResidencyTier::ALL {
            for (index, term) in tier.canonical_register_terms().iter().enumerate() {
                assert!(
                    !tier.canonical_register_terms()[index + 1..].contains(term),
                    "{} must not duplicate {} in canonical register terms",
                    tier.canonical_name(),
                    term.code()
                );
            }
        }

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
    fn residency_primary_falsifiers_name_ulp_oracle_for_numerical_guard() {
        for tier in ResidencyTier::ALL {
            assert!(
                tier.canonical_register_terms()
                    .contains(&WboTermCode::NumericalPostCorrection),
                "{} must carry T_num before requiring F-ULP-Oracle",
                tier.canonical_name()
            );
            assert!(
                contains_falsifier_hook(tier.primary_falsifier(), "F-ULP-Oracle"),
                "{} owns T_num and must name F-ULP-Oracle in its primary falsifier",
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
    fn residency_tier_catalog_pins_primary_rate_rows() {
        let rows = ResidencyTier::ALL
            .iter()
            .map(|tier| {
                (
                    tier.canonical_name(),
                    tier.primary_rate_milli_bits_per_symbol(),
                )
            })
            .collect::<Vec<_>>();

        assert_eq!(
            rows,
            vec![
                ("L0 RAM hot", None),
                ("L1 Compressed Residual", Some(1250)),
                ("L2 Shadow Sketch", None),
                ("L3 SSD Oracle", Some(4000)),
                ("L4 Engram", None),
                ("L5 Network Cascade", None),
                ("L_SE Self-Evolving", None),
            ]
        );
    }

    #[test]
    fn residency_tier_primary_rates_match_primary_codec_rate_ownership() {
        for tier in ResidencyTier::ALL {
            assert_eq!(
                tier.primary_rate_milli_bits_per_symbol().is_some(),
                tier.primary_coder().allows_rate_parameter(),
                "{} primary rate must match {:?} rate ownership",
                tier.canonical_name(),
                tier.primary_coder()
            );
        }
    }

    #[test]
    fn residency_tier_catalog_maps_every_tier_to_side_information_witnesses() {
        for tier in ResidencyTier::ALL {
            for (index, witness) in tier.side_information_witnesses().iter().enumerate() {
                assert!(
                    !tier.side_information_witnesses()[index + 1..].contains(witness),
                    "{} must not duplicate {witness:?} in side-information witnesses",
                    tier.canonical_name()
                );
            }
        }

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
    fn residency_tier_side_information_witnesses_match_primary_codec_catalog() {
        for tier in ResidencyTier::ALL {
            for witness in tier.side_information_witnesses() {
                assert!(
                    tier.primary_coder()
                        .canonical_side_information()
                        .contains(witness),
                    "{} witness {:?} must be accepted by {:?}",
                    tier.canonical_name(),
                    witness,
                    tier.primary_coder()
                );
            }
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
    fn residency_tier_catalog_distinguishes_required_and_secondary_active_support_budget() {
        let required_tiers = ResidencyTier::ALL
            .iter()
            .copied()
            .filter(|tier| tier.requires_active_support_budget())
            .map(ResidencyTier::canonical_name)
            .collect::<Vec<_>>();
        let secondary_tiers = ResidencyTier::ALL
            .iter()
            .copied()
            .filter(|tier| tier.allows_secondary_active_support_budget())
            .map(ResidencyTier::canonical_name)
            .collect::<Vec<_>>();

        assert_eq!(required_tiers, vec!["L2 Shadow Sketch"]);
        assert_eq!(secondary_tiers, vec!["L3 SSD Oracle"]);
        for tier in ResidencyTier::ALL {
            assert_eq!(
                tier.allows_active_support_budget(),
                tier.requires_active_support_budget()
                    || tier.allows_secondary_active_support_budget(),
                "{} active-support budget allowance must be exhausted by required or secondary paths",
                tier.canonical_name()
            );
            assert!(
                !(tier.requires_active_support_budget()
                    && tier.allows_secondary_active_support_budget()),
                "{} cannot be both a required primary and optional secondary active-support row",
                tier.canonical_name()
            );
        }
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
        let mut active_support_rows = Vec::new();

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
            let active_support = tier.allows_active_support_budget().then(|| {
                active_support_rows.push(tier.canonical_name());
                ActiveSupportBudget::new(
                    2048,
                    32,
                    64 * 1024 * 1024,
                    SideInformationKind::ActiveSupport,
                )
            });
            let entry = WboLedgerEntry::new_for_tier(
                tier,
                budget,
                active_support,
                format!("{}; F-ULP-Oracle", tier.primary_coder().falsifier()),
                "Canonical register row keeps residency, codec, terms, and falsifier aligned.",
            );

            assert_eq!(entry.validate(), Ok(()), "{}", tier.canonical_name());
        }

        assert_eq!(
            active_support_rows,
            vec!["L2 Shadow Sketch", "L3 SSD Oracle"]
        );
    }

    #[test]
    fn wbo_ledger_entry_new_for_tier_serializes_canonical_memory_tier_names() {
        for tier in ResidencyTier::ALL {
            let budget = LatticeBudget::new(
                tier.primary_coder(),
                tier.primary_rate_milli_bits_per_symbol(),
                tier.primary_side_information(),
                tier_probe_contributions(tier),
            );
            let active_support = tier.allows_active_support_budget().then(|| {
                ActiveSupportBudget::new(128, 4, 1024, SideInformationKind::ActiveSupport)
            });
            let value = WboLedgerEntry::new_for_tier(
                tier,
                budget,
                active_support,
                tier.primary_falsifier(),
                "Typed residency row uses canonical public tier names.",
            );
            let encoded = serde_json::to_value(&value).expect("serialize ledger entry");
            let object = encoded
                .as_object()
                .expect("ledger entry must serialize as an object");

            assert_eq!(
                object["memory_tier"],
                serde_json::json!(tier.canonical_name())
            );
            assert_ne!(
                object["memory_tier"],
                serde_json::json!(format!("{tier:?}"))
            );
            assert!(value.validate().is_ok(), "{}", tier.canonical_name());
        }
    }

    #[test]
    fn register_doc_preserves_required_canon_cross_links_and_caveats() {
        let register = include_str!("../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
        let required = [
            "`docs/NO_COMPROMISE_ENDGAME_PROMPT_DECK_2026_05_18.md` §4 line 346",
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
            "cross-link guardrail rows include concrete `line N` anchors",
            "UAS §2, §4, and §5 line anchors are checked against current headings",
            "MASTER_FUSION §3.2, §3.4, §3.8, §3.16, and §3.18 line anchors are checked against current headings",
            "`register_doc_canonical_anchor_list_matches_guardrail_rows`",
            "canonical-anchor list and cross-link guardrail table line anchors share the same source/section/line triples",
            "`register_doc_cross_link_rows_name_current_canon_headings`",
            "cross-link guardrail row titles mirror the current source headings",
            "`LatticeCoder<BITS>` is an abstraction",
            "It cannot borrow a weight-codec",
            "Weight quantization and KV quantization use different Hessians",
            "`ResidencyTier::primary_falsifier()`",
            "`residency_tier_catalog_maps_every_tier_to_primary_falsifier`",
            "every residency primary falsifier equals its primary codec falsifier",
            "`wbo_ledger_entry_new_for_tier_serializes_canonical_memory_tier_names`",
            "`WboLedgerEntry::new_for_tier()` serializes every `memory_tier` as `ResidencyTier::canonical_name()`",
            "`ledger_validation_rejects_residency_debug_labels`",
            "every `ResidencyTier` debug label is rejected as `UnknownResidencyTier`",
            "`residency_tier_canonical_names_are_trimmed_and_display_safe`",
            "canonical residency names are trimmed, nonempty, ASCII, and free of debug-only enum spelling",
            "`wbo_ledger_entry_serializes_public_accounting_keys`",
            "WboLedgerEntry serializes only `memory_tier`, `budget`, `active_support`, `falsifier`, and `caveat` public keys",
            "`wbo_ledger_entry_json_rejects_invalid_public_rows`",
            "ledger JSON rejects blank row fields, missing `F-ULP-Oracle`, and missing required active support before becoming a public row",
            "`wbo_ledger_entry_serializes_absent_active_support_as_null`",
            "ledger rows without secondary active support keep `active_support` as null",
            "`public_accounting_json_rejects_unknown_fields`",
            "public accounting JSON rejects unknown fields on contribution, budget, active-support budget, and ledger-entry surfaces",
            "`public_accounting_json_rejects_nested_unknown_fields`",
            "public accounting JSON rejects nested unknown fields inside budget contributions and ledger active-support budgets",
            "`public_accounting_json_rejects_duplicate_public_keys`",
            "public JSON rows reject duplicate public keys before validation",
            "`public_accounting_json_rejects_missing_required_keys`",
            "public JSON rows reject missing required keys before validation",
            "`public_accounting_json_rejects_wrong_type_public_fields`",
            "public JSON rows reject wrong-type public fields before validation",
            "`lattice_budget_json_rejects_invalid_public_envelopes`",
            "budget JSON rejects empty contribution lists, missing `T_num`, and wrong side-information before becoming a public budget envelope",
            "`lattice_coder_canonical_names_are_trimmed_kebab_case_keys`",
            "canonical codec names are trimmed, nonempty, ASCII kebab-case keys and free of debug-only enum spelling",
            "`lattice_coder_json_uses_canonical_keys_and_rejects_debug_labels`",
            "codec JSON emits and accepts only canonical kebab-case keys; debug enum labels and spoofed case/spacing/separator keys are rejected",
            "`LatticeCoderKind::canonical_side_information()`",
            "`budget_validation_accepts_canonical_side_information_by_codec`",
            "`register_doc_side_information_rows_follow_catalog_order`",
            "side-information register order follows `SideInformationKind::ALL`",
            "`side_information_json_uses_explicit_public_keys`",
            "side-information JSON emits and accepts only explicit public witness keys; spacing, kebab-case, acronym, and prose spoof keys are rejected",
            "`ledger_validation_rejects_every_nonprimary_codec_for_every_residency_tier`",
            "every residency tier rejects every non-primary codec before side-information or falsifier borrowing",
            "non-primary codecs still fail when borrowing the tier primary side-information and falsifier",
            "`ledger_validation_rejects_nonprimary_codec_before_foreign_terms`",
            "non-primary codecs fail before simultaneous residency-term mismatches",
            "`ledger_validation_rejects_every_term_outside_residency_tier_map`",
            "every residency tier rejects every contribution term outside its canonical map",
            "the exhaustive residency-term fixture includes primary-codec-owned terms that remain tier-foreign",
            "`ledger_validation_rejects_missing_non_numerical_residency_terms`",
            "typed residency rows reject sparse rows that omit tier-owned non-`T_num` axes",
            "`ledger_validation_rejects_foreign_terms_before_nonprimary_side_information`",
            "foreign residency terms fail before simultaneous non-primary side-information mismatches",
            "`lattice_budget_validation_rejects_terms_outside_codec_map`",
            "full `LatticeBudget::validate()` and public `validate_composition()` paths",
            "`lattice_budget_validation_rejects_foreign_terms_before_missing_t_num`",
            "foreign codec terms fail before missing numerical post-correction",
            "measured invalid-term fixture also exercises public `validate_composition()` rejection",
            "`budget_validation_rejects_every_noncanonical_side_information_for_every_codec`",
            "every codec row rejects every side-information witness outside its canonical set",
            "full `LatticeBudget::validate()`, public `validate_composition()`, and direct `validate_side_information()` paths",
            "direct `validate_side_information()` rejects the same noncanonical codec witnesses",
            "`budget_validation_rejects_wrong_side_information_before_term_mismatch`",
            "wrong side-information is rejected before a simultaneous foreign-term mismatch",
            "`budget_validation_rejects_every_wrong_side_information_before_term_mismatch`",
            "every noncanonical side-information witness is rejected before simultaneous codec-term mismatches",
            "measured invalid-side-information fixtures also exercise public `validate_composition()` rejection",
            "`ledger_validation_rejects_side_information_outside_residency_primary`",
            "`ledger_validation_rejects_every_nonprimary_side_information_for_every_residency_tier`",
            "every residency tier rejects every non-primary side-information kind",
            "the exhaustive residency side-information fixture includes primary-codec-accepted witnesses that remain tier-nonprimary",
            "`typed_catalogs_assign_every_side_information_to_codec_rows`",
            "`residency_tier_side_information_matches_primary_codec_catalog`",
            "`ResidencyTier::side_information_witnesses()`",
            "`residency_tier_catalog_maps_every_tier_to_side_information_witnesses`",
            "`residency_tier_side_information_witnesses_match_primary_codec_catalog`",
            "every residency side-information witness is accepted by that tier's primary codec",
            "`ledger_validation_allows_mixed_side_information_with_valid_active_support_budget`",
            "mixed primary side-information rows with valid secondary `ActiveSupportBudget` validate",
            "`ledger_validation_allows_l3_ssd_oracle_without_active_support_budget`",
            "`ledger_validation_allows_max_active_support_budget_without_lattice_overflow`",
            "max-valued secondary active-support axes validate without entering lattice measured totals",
            "`codec_side_information_catalog_keeps_hessian_domains_disjoint`",
            "`weight_codec_catalogs_do_not_claim_kv_cache_terms`",
            "`codec_falsifiers_cover_every_canonical_term_falsifier`",
            "`register_doc_names_every_residency_tier_and_wbo_term`",
            "`register_doc_names_every_codec_and_side_information_kind`",
            "`register_doc_names_every_lattice_wbo_error_variant`",
            "every `LatticeWboError::ALL` variant has one register error row",
            "error variant register rejects stale rows outside `LatticeWboError::ALL`",
            "`register_doc_error_variant_rows_follow_lattice_wbo_error_all_order`",
            "error variant register order follows `LatticeWboError::ALL`",
            "`lattice_wbo_error_json_uses_explicit_public_keys`",
            "LatticeWboError JSON emits and accepts only explicit public error keys; lowercase, prose, dashed, and spaced spoof keys are rejected",
            "`typed_all_catalogs_have_unique_public_keys`",
            "typed ALL catalogs keep unique residency, codec, side-information, term, and error public keys",
            "`explicit_public_key_tables_follow_all_catalog_order`",
            "explicit public key tables follow their typed ALL catalog order for residency, codec, side-information, WBO term, and error registries",
            "explicit public key tables are exact, non-normalizing surfaces; padded, blank, case-shifted, or separator-shifted keys remain invalid",
            "`public_key_registries_deserialize_from_owned_json_values`",
            "public key registries deserialize from owned JSON values for residency, codec, side-information, WBO term, and error keys",
            "`public_key_registries_reject_wrong_type_json_values`",
            "public key registries reject wrong-type JSON values before string-key lookup",
            "`public_key_registries_reject_cross_registry_keys`",
            "public key registries reject keys owned by every other WBO registry",
            "`public_key_registries_reject_unicode_adjacent_public_keys`",
            "unicode-adjacent canonical keys stay invalid",
            "`wbo_term_codes_are_trimmed_ascii_axis_keys`",
            "WBO term codes are trimmed, nonempty, ASCII axis keys and free of debug-only enum spelling",
            "`wbo_term_code_json_uses_public_axis_keys_and_rejects_debug_labels`",
            "WBO term JSON emits and accepts only public `T_*` axis keys; debug enum labels and spoofed case/whitespace keys are rejected",
            "`register_doc_wbo_term_rows_follow_catalog_order`",
            "WBO term register order follows `WboTermCode::ALL`",
            "`register_doc_residency_rows_follow_catalog_order`",
            "residency register order follows `ResidencyTier::ALL`",
            "`register_doc_codec_rows_follow_catalog_order`",
            "codec coverage order follows `LatticeCoderKind::ALL`",
            "exact residency-to-side-information witness set",
            "exact residency-to-falsifier `F-*` hook set",
            "exact term-to-falsifier `F-*` hook set",
            "exact codec-to-falsifier `F-*` hook set",
            "exact codec-to-side-information witness set",
            "`lattice_budget_serializes_public_accounting_keys`",
            "LatticeBudget serializes only `coder`, `rate_milli_bits_per_symbol`, `side_information`, and `contributions` public keys",
            "`lattice_budget_composition_rejects_empty_public_contributions`",
            "`lattice_budget_composition_requires_numerical_post_correction_term`",
            "`lattice_budget_composition_rejects_empty_source_public_contributions`",
            "empty-source composition fixture also exercises full `LatticeBudget::validate()` rejection",
            "`lattice_budget_measured_status_returns_none_for_empty_public_contributions`",
            "semantic and numerical measured slices also remain pending for empty public contribution lists",
            "empty public-contribution measured-status fixture also exercises public `validate_composition()` rejection",
            "`lattice_budget_validate_combines_rate_and_side_information_guards`",
            "combined budget guard fixture rejects empty, invalid-rate, and invalid side-information rows independently",
            "`lattice_budget_composition_handles_signed_max_and_mixed_axes`",
            "signed, max, and mixed semantic/numerical axes are validated together",
            "signed mixed-axis invalid public fields keep every measured-status surface pending",
            "`lattice_budget_validation_accepts_zero_and_single_max_budget_edges`",
            "`lattice_budget_validation_rejects_signed_contribution_fields_even_when_totals_cancel`",
            "`lattice_error_contribution_serializes_public_accounting_keys`",
            "LatticeErrorContribution serializes only `term`, `source`, `budget`, and `measured` public keys",
            "`lattice_error_contribution_json_rejects_invalid_public_fields`",
            "contribution JSON rejects negative budget, negative measured, blank source, and wrong-type budget/measured fields",
            "`contribution_measured_status_returns_none_for_invalid_public_fields`",
            "`lattice_budget_measured_status_returns_none_for_invalid_public_fields`",
            "semantic and numerical measured slices also remain pending when public fields are invalid",
            "invalid public-field measured-status fixture also exercises public `validate_composition()` rejection",
            "`lattice_budget_measured_status_returns_none_for_invalid_side_information`",
            "semantic and numerical measured slices also remain pending when side-information ownership is invalid",
            "`lattice_budget_measured_status_returns_none_for_every_noncanonical_side_information`",
            "every codec-level noncanonical side-information measured-status fixture remains pending",
            "`lattice_budget_measured_status_returns_none_for_invalid_terms`",
            "semantic and numerical measured slices also remain pending when codec term ownership is invalid",
            "`ledger_entry_wbo_terms_deduplicates_every_codec_catalog`",
            "ledger WBO term summaries preserve first-seen codec term order while dropping duplicate contributions",
            "`cache_offload_codecs_pin_kv_boundary_quantization_and_numerical_terms`",
            "ShadowKV terms are `T_K` + `T_S` + `T_num`; NF4 SSD Oracle terms are `T_K` + `T_Q` + `T_S` + `T_num`",
            "`lattice_budget_measured_status_returns_none_for_invalid_rate`",
            "invalid-rate measured-status fixture keeps budget totals pending",
            "invalid-rate measured-status fixture covers missing, zero, and stray explicit rates",
            "invalid-rate measured-status fixture also exercises public `validate_composition()` rejection",
            "`ledger_validation_rejects_invalid_rate_on_typed_rate_rows`",
            "typed rate-bearing ledger rows reject missing primary rates",
            "`ledger_validation_rejects_zero_rate_on_typed_rate_rows`",
            "typed rate-bearing ledger rows reject zero primary rates",
            "`ledger_validation_rejects_wrong_primary_rate_on_typed_rate_rows`",
            "typed rate-bearing ledger rows reject nonzero rates that differ from the residency primary rate",
            "`ledger_validation_rejects_rate_on_typed_non_rate_rows`",
            "typed non-rate ledger rows reject explicit borrowed rates",
            "`lattice_budget_serializes_non_rate_rate_field_as_null`",
            "non-rate budget JSON keeps `rate_milli_bits_per_symbol` as null",
            "`lattice_budget_json_rejects_unsigned_rate_spoofs`",
            "budget JSON rejects negative, fractional, string, boolean, object, array, and oversized rate fields",
            "`lattice_coder_catalog_marks_non_rate_codecs`",
            "the exact non-rate codec set is `ExactHot`, `BabaiGptqNearestPlane`, `ShadowKvSketch`, `EngramHashRecall`, `NetworkCascade`, and `SelfEvolvingAdapter`",
            "`lattice_budget_measured_status_returns_none_for_overflowed_totals`",
            "semantic and numerical measured slices also remain pending when aggregate totals overflow",
            "overflowed aggregate measured-status fixture also exercises full `LatticeBudget::validate()` rejection",
            "public struct literals cannot bypass",
            "`lattice_budget_slice_partition_is_order_invariant_across_all_axes`",
            "semantic plus numerical slices conserve the total across reordered and duplicated axes",
            "`lattice_budget_slice_partition_conserves_every_codec_catalog`",
            "codec-wide slice fixture preserves semantic plus numerical conservation for every codec catalog row",
            "`residency_tier_catalog_pins_primary_rate_rows`",
            "only L1 carries 1250 milli-bits and L3 carries 4000 milli-bits",
            "`residency_tier_primary_rates_match_primary_codec_rate_ownership`",
            "each residency primary rate exists exactly when its primary codec is rate-bearing",
            "`ledger_validation_requires_term_falsifier_hook_for_each_contribution`",
            "`ledger_validation_requires_ulp_oracle_for_numerical_post_correction`",
            "`lattice_budget_measured_status_requires_numerical_post_correction_term`",
            "semantic and numerical measured slices also remain pending without `T_num`",
            "missing-`T_num` measured-status fixture also exercises public `validate_composition()` rejection",
            "`falsifier_hook_matching_rejects_substring_collisions`",
            "exact-case verifier matching",
            "hook checks are exact-case and delimiter-aware, not case-insensitive substrings",
            "non-ASCII hook adjacency is rejected instead of treated as punctuation",
            "punctuation-delimited canonical hooks remain valid",
            "`falsifier_hook_extraction_accepts_markdown_punctuation_boundaries`",
            "Markdown punctuation around canonical `F-*` hooks is accepted while adjacent word characters stay rejected",
            "capitalized verifier phrases",
            "`ledger_validation_rejects_spoofed_ulp_oracle_hook`",
            "`ledger_validation_requires_wbo_drift_ledger_for_every_row`",
            "Every ledger row must name `F-WBO-DriftLedger`",
            "`wbo_term_catalog_requires_drift_ledger_for_every_axis`",
            "every WBO term falsifier includes `F-WBO-DriftLedger`",
            "`term_falsifier_catalogs_name_owned_f_hooks_for_every_axis`",
            "`FALSIFIER_HOOK_OWNERS`",
            "`falsifier_hook_registry_owns_every_f_hook_named_by_catalogs`",
            "every falsifier owner hook key must use the `F-` prefix",
            "exact four-row owner map for `F-WBO-DriftLedger`, `F-ULP-Oracle`, `F-KV-Direct-Gate`, and `F-ACS-AnchorLookup`",
            "`falsifier_hook_owner_registry_has_unique_public_hooks`",
            "falsifier owner registry hook keys are unique public `F-*` hooks",
            "`falsifier_hook_registry_owner_rows_follow_canonical_order`",
            "falsifier owner registry order is `F-WBO-DriftLedger`, `F-ULP-Oracle`, `F-KV-Direct-Gate`, then `F-ACS-AnchorLookup`",
            "`falsifier_hook_owner_registry_serializes_public_keys`",
            "FalsifierHookOwner serializes only `hook` and `owner` public keys",
            "`falsifier_hook_owner_json_rejects_unknown_fields`",
            "FalsifierHookOwner JSON rejects unknown fields",
            "`falsifier_hook_owner_json_rejects_unregistered_public_rows`",
            "owner JSON rejects unowned hooks, blank owners, and hook/owner mismatches while accepting exact registry rows",
            "owner JSON rejects unicode-adjacent owner hook keys",
            "`falsifier_hook_owner_json_rejects_cross_owner_borrowing`",
            "owner JSON rejects cross-owner hook and owner-path borrowing",
            "exactly one owner row",
            "`codec_falsifier_catalogs_name_owned_f_hooks_for_every_codec`",
            "`codec_falsifier_catalogs_cover_every_owned_f_hook`",
            "every owned `F-*` hook appears in at least one codec falsifier row",
            "`residency_primary_falsifiers_name_owned_f_hooks_for_every_tier`",
            "`residency_primary_falsifiers_cover_every_owned_f_hook`",
            "every owned `F-*` hook appears in at least one residency primary falsifier",
            "`falsifier_hook_registry_owner_paths_exist`",
            "`term_falsifier_catalogs_cover_every_owned_f_hook`",
            "every owned `F-*` hook appears in at least one WBO term falsifier",
            "each falsifier owner path resolves to an existing repo file",
            "falsifier owner paths are relative repository paths without `..` traversal",
            "owner paths must resolve to files, not directories",
            "`falsifier_hook_registry_owner_paths_stay_in_canonical_surfaces`",
            "falsifier owner paths stay inside `docs/fusion/`, `agent_core/src/research/`, or `agent_core/src/scope_rex/` surfaces",
            "`falsifier_hook_owner_files_name_their_hooks`",
            "each falsifier owner file names the exact `F-*` hook it owns",
            "`register_doc_f_hooks_are_owned_by_registry`",
            "every concrete register `F-*` hook has a registry owner",
            "register F-* hook set must match falsifier owner registry",
            "`ledger_validation_rejects_unowned_falsifier_hooks`",
            "canonical hook slash-suffix and non-ASCII adjacency variants are rejected by the ledger owner path",
            "`residency_tier_catalog_attaches_numerical_guard_to_every_tier`",
            "`lattice_coder_catalog_attaches_numerical_guard_to_every_codec`",
            "`residency_primary_falsifiers_name_ulp_oracle_for_numerical_guard`",
            "every residency primary falsifier names `F-ULP-Oracle` for `T_num`",
            "`register_doc_requires_ulp_oracle_on_t_num_table_rows`",
            "`register_doc_codec_falsifier_table_names_ulp_oracle_for_t_num_codecs`",
            "`lattice_coder_catalog_marks_rate_bearing_codecs`",
            "the exact rate-bearing codec set includes standalone `NestedE8` and `NestedLeech24` rows",
            "`F-WBO-DriftLedger` alone is insufficient",
            "`ledger_validation_rejects_active_support_budget_without_substrate_boundary_term`",
            "`residency_tier_catalog_marks_active_support_budget_tiers`",
            "the exact active-support budget tier set is `L2 Shadow Sketch` and `L3 SSD Oracle`",
            "`residency_tier_catalog_distinguishes_required_and_secondary_active_support_budget`",
            "required active-support budget row is `L2 Shadow Sketch` and optional secondary active-support budget row is `L3 SSD Oracle`",
            "`residency_tier_catalog_requires_substrate_boundary_for_active_support_budget_tiers`",
            "active-support-capable residency tiers must own `T_S`",
            "`ledger_validation_requires_active_support_for_active_support_rows`",
            "`MissingActiveSupportBudget`",
            "`canonical_residency_rows_validate_against_tier_maps`",
            "typed residency validation supplies `ActiveSupportBudget` for active-support-capable rows",
            "`ledger_validation_accepts_canonical_active_support_budget`",
            "canonical `ActiveSupport` rows with nonzero secondary budgets validate",
            "`ledger_validation_rejects_missing_active_support_before_missing_t_num`",
            "missing required active support fails before missing `T_num`",
            "`ledger_validation_rejects_malformed_active_support_before_missing_t_num`",
            "malformed secondary active support fails before missing `T_num`",
            "`ledger_validation_rejects_active_support_budget_on_disallowed_tiers`",
            "max active-support axes do not bypass disallowed tier rejection",
            "`ledger_validation_rejects_every_non_active_support_budget_side_information`",
            "secondary `ActiveSupportBudget` rejects every non-`ActiveSupport` side-information tag",
            "secondary active-support side-information rejection covers both `L2 Shadow Sketch` and `L3 SSD Oracle`",
            "`ledger_validation_rejects_zero_active_support_budget_even_when_secondary`",
            "`ledger_validation_rejects_partial_zero_active_support_axes`",
            "token, page, and resident-byte axes are each nonzero",
            "`ledger_validation_rejects_zero_active_support_budget_with_wrong_side_information`",
            "all-zero active-support budgets crossed with non-ActiveSupport witnesses stay invalid",
            "`ledger_validation_rejects_combined_malformed_active_support_budget`",
            "combined malformed secondary active-support fixture covers every active-support-capable tier",
            "`active_support_budget_serializes_public_accounting_keys`",
            "ActiveSupportBudget serializes only `max_active_tokens`, `max_active_pages`, `max_resident_bytes`, and `side_information` public keys",
            "`active_support_budget_json_rejects_unsigned_axis_spoofs`",
            "ActiveSupportBudget JSON rejects negative, fractional, string, boolean, object, array, and oversized axis values",
            "`active_support_budget_json_rejects_invalid_public_budget`",
            "standalone active-support JSON rejects zero axes and non-`ActiveSupport` side information",
            "partial-zero active-support axis fixture covers every active-support-capable tier",
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
            "`nested_lattice_codecs_pin_weight_quantization_terms_and_rate`",
            "nested standalone codec terms remain `T_W` + `T_Q` + `T_num` with explicit rate ownership",
            "`nested_lattice_codecs_reject_residual_and_kv_side_information`",
            "nested standalone rows reject residual, KV, active-support, and SSD-oracle witnesses through direct, full, and composition validators",
            "L3 SSD Oracle keeps `SsdOracle` as primary side information; `ActiveSupportBudget` is allowed but optional",
            "| L0 RAM hot | Exact fp16/bf16 KV and residual stream | `None` beyond live model state | `T_num` only | `F-WBO-DriftLedger`; `F-ULP-Oracle`; per-token KL witness",
            "`exact_hot_codec_pins_reference_term_and_side_information`",
            "ExactHot terms are `T_num` only and side information is `None`",
            "| L1 Compressed Residual | Lattice-Wyner-Ziv residual codec under `LatticeCoder<1250 milli-bits>` | `ResidualStream` plus `DecoderLmState` | `T_R` + `T_Q` + `T_num` | `F-WBO-DriftLedger`; `F-ULP-Oracle`; residual KL slice",
            "| L2 Shadow Sketch | ShadowKV-style active-support sketch: retained pages/tokens plus residual or JL/CountSketch correction | `ActiveSupport` mask, page criticality, residual sketch | `T_K` + `T_S` + `T_num` | `F-WBO-DriftLedger`; `F-ULP-Oracle`; `F-KV-Direct-Gate`; `F-ACS-AnchorLookup`",
            "| L3 SSD Oracle | NF4 mmap/IOSurface pages under `Nf4SsdOracle<4000 milli-bits>` with cold exact-or-higher-fidelity page oracle | `SsdOracle` page plus `ResidualStream` reconstruction witness | `T_K` + `T_Q` + `T_S` + `T_num` | `F-KV-Direct-Gate`; `F-ULP-Oracle`; `F-WBO-DriftLedger`; layerwise reconstruction/logit drift witness; `F-ACS-AnchorLookup`",
            "| L4 Engram | Fixed-budget hash recall for static facts, signatures, dates, and API contracts | Content hash, provenance edge, `StaticFactKey` | `T_S` + `T_num` | `F-ACS-AnchorLookup`; `F-ULP-Oracle`; `F-WBO-DriftLedger`",
            "| L5 Network Cascade | Outlier escalation to larger/cloud teacher or cross-model verifier | `NetworkTeacher` output, signed provenance, claim ledger witness | `T_S` + `T_SE` + `T_num` | `F-WBO-DriftLedger`; `F-ULP-Oracle`; `F-ACS-AnchorLookup`; provider/provenance replay",
            "| L_SE Self-Evolving | Titans-MAC / SEAL-DoRA adapter or surprise-gradient state | `SurpriseGradient`, adapter provenance, replayable mutation envelope | `T_W` + `T_SE` + `T_num` | `F-WBO-DriftLedger`; `F-ULP-Oracle`; adapter replay/provenance verifier; layerwise reconstruction/logit drift witness before promotion",
            "| Babai/GPTQ nearest-plane | Weight quantization as nearest-plane rounding in a Hessian-induced lattice | Calibration Hessian from the weight quantization calibration set | `T_W` + `T_num` | `F-WBO-DriftLedger`; `F-ULP-Oracle`; layerwise reconstruction/logit drift witness; layerwise KL/logit drift harness",
            "`lattice_coder_catalog_includes_babai_gptq_nearest_plane`",
            "Babai/GPTQ nearest-plane terms are `T_W` + `T_num`, side information is `CalibrationHessian`, and it is non-rate",
            "| `BabaiGptqNearestPlane` | Babai/GPTQ nearest-plane codec row | `F-WBO-DriftLedger`; `F-ULP-Oracle`; layerwise reconstruction/logit drift witness |",
            "| Sherry 3:4 sparse ternary | 1.25-bit sparse ternary lattice packing used as a weight-codec reference only | Calibration Hessian for weight lanes | `T_W` + `T_Q` + `T_num` | `F-WBO-DriftLedger`; `F-ULP-Oracle`; layerwise reconstruction/logit drift witness",
            "`sherry_ternary_codec_pins_weight_terms_rate_and_calibration_side_information`",
            "Sherry terms are `T_W` + `T_Q` + `T_num` with explicit rate ownership and `CalibrationHessian` evidence",
            "| QuIP/E8 | Incoherence rotation plus E8-style lattice codebook for weight blocks | Calibration Hessian / whitening statistics | `T_W` + `T_Q` + `T_num` | `F-WBO-DriftLedger`; `F-ULP-Oracle`; layerwise reconstruction/logit drift witness",
            "`quip_e8_codec_pins_weight_quantization_terms_and_rate`",
            "QuIP/E8 terms are `T_W` + `T_Q` + `T_num` with explicit rate ownership and calibration-side evidence",
            "| Lattice-Wyner-Ziv / `LatticeCoder<BITS>` | Rate-limited residual or state codec decoded with model side information | Decoder LM state, residual stream, active support, or oracle page depending on tier | `T_R` + tier-specific `T_K`/`T_Q`/`T_S` + `T_num` | `F-WBO-DriftLedger`; `F-ULP-Oracle`; `F-ACS-AnchorLookup`; tier-specific KL/reconstruction witness",
            "`lattice_wyner_ziv_residual_codec_pins_terms_rate_and_decoder_witnesses`",
            "LatticeWynerZivResidual terms are `T_K` + `T_R` + `T_Q` + `T_S` + `T_num` with `DecoderLmState`, `ResidualStream`, `ActiveSupport`, and `SsdOracle` witnesses",
            "| Residual sketch | JL / CountSketch / FRP-shaped correction stream attached to a compressed residual or KV restore path | Residual stream witness plus decoder LM state; active-support mask when the sketch repairs skipped support | `T_R` + `T_Q` + tier-specific `T_S` + `T_num` | `F-WBO-DriftLedger`; `F-ULP-Oracle`; `F-ACS-AnchorLookup`; tier-specific reconstruction witness",
            "`residual_sketch_codec_pins_correction_terms_and_side_information`",
            "ResidualSketch terms are `T_R` + `T_Q` + `T_S` + `T_num` with `ResidualStream`, `DecoderLmState`, and `ActiveSupport` witnesses",
            "| Engram hash recall | Fixed-budget static-fact hash lookup for signatures, dates, API contracts, and never-recompute knowledge | `StaticFactKey`, content hash, and provenance edge | `T_S` + `T_num` | `F-ACS-AnchorLookup`; `F-ULP-Oracle`; `F-WBO-DriftLedger`",
            "`engram_hash_recall_codec_pins_static_fact_boundary`",
            "EngramHashRecall terms are `T_S` + `T_num`, side information is `StaticFactKey`, and it is non-rate",
            "| Network cascade | Outlier escalation to a larger model, cloud teacher, or cross-model verifier at the L5 boundary | Signed teacher output, provider receipt, claim ledger witness, and replayable provenance | `T_S` + `T_SE` + `T_num` | provider/provenance replay; `F-ULP-Oracle`; `F-WBO-DriftLedger`; `F-ACS-AnchorLookup`",
            "`network_cascade_codec_pins_teacher_boundary_terms_and_side_information`",
            "NetworkCascade terms are `T_S` + `T_SE` + `T_num`, side information is `NetworkTeacher`, and it is non-rate",
            "| Self-evolving adapter | Titans-MAC / SEAL-DoRA / QDoRA-style adapter state that mutates the effective runtime model | Surprise gradient, adapter provenance, replayable mutation envelope, and promotion witness | `T_W` + `T_SE` + `T_num` | adapter replay/provenance verifier; `F-ULP-Oracle`; `F-WBO-DriftLedger`; layerwise reconstruction/logit drift witness",
            "`self_evolving_adapter_codec_pins_mutation_terms_and_side_information`",
            "SelfEvolvingAdapter terms are `T_W` + `T_SE` + `T_num`, side information is `SurpriseGradient`, and it is non-rate",
            "rate_milli_bits_per_symbol` on non-rate codecs",
            "`budget_validation_rejects_zero_explicit_rate`",
            "`budget_validation_rejects_missing_rate_on_rate_codecs`",
            "`budget_validation_accepts_nonzero_rate_on_rate_codecs`",
            "`budget_validation_rejects_rate_on_non_rate_codecs`",
            "invalid-rate fixtures also assert the public `validate_composition()` path",
            "only `L2 Shadow Sketch` and `L3 SSD Oracle` rows may carry this budget surface",
            "`WboTermCode::falsifier()`",
            "`F-KV-Direct-Gate` for `T_K`",
            "`F-ULP-Oracle` for `T_num`",
            "must conserve",
            "`lattice_budget_measured_total_includes_numerical_post_correction`",
            "`measured_semantic_wbo6_pre_softmax_total()`",
            "`measured_numerical_post_correction_total()`",
            "`lattice_budget_measured_slices_partition_complete_total`",
            "`lattice_budget_measured_total_sums_duplicate_semantic_and_numerical_axes`",
            "duplicate semantic and numerical measured slices stay separately summed",
            "`lattice_budget_measured_slices_require_complete_cross_axis_measurements`",
            "semantic and numerical measured slices remain pending when any contribution lacks measured data",
            "missing semantic or missing numerical measurements both keep every measured surface pending",
            "`lattice_error_contribution_serializes_pending_measurement_as_null`",
            "unmeasured contribution JSON keeps `measured` as null",
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
            let row_count = register
                .lines()
                .filter(|line| line.starts_with(&needle))
                .count();
            assert_eq!(
                row_count,
                1,
                "{} must name one residency register row",
                tier.canonical_name()
            );
            let row = register
                .lines()
                .find(|line| line.starts_with(&needle))
                .expect("residency row should exist");
            let cells = row
                .trim_matches('|')
                .split('|')
                .map(str::trim)
                .collect::<Vec<_>>();
            match tier.primary_rate_milli_bits_per_symbol() {
                Some(rate) => assert!(
                    row.contains(&format!("{rate} milli-bits")),
                    "{} row must name primary rate {rate} milli-bits",
                    tier.canonical_name()
                ),
                None => assert!(
                    !row.contains("milli-bits"),
                    "{} row must not name a primary rate",
                    tier.canonical_name()
                ),
            }
            let side_information_cell = cells.get(2).unwrap_or_else(|| {
                panic!(
                    "{} row must have side-information cell",
                    tier.canonical_name()
                )
            });
            for side_information in SideInformationKind::ALL {
                let side_information_name = format!("`{side_information:?}`");
                let expected = tier
                    .side_information_witnesses()
                    .contains(&side_information);
                assert_eq!(
                    side_information_cell.contains(&side_information_name),
                    expected,
                    "{} row side-information cell must exactly match {side_information_name} ownership",
                    tier.canonical_name()
                );
            }
            let falsifier_cell = cells.get(4).unwrap_or_else(|| {
                panic!("{} row must have falsifier cell", tier.canonical_name())
            });
            let mut expected_hooks = f_hooks_in(tier.primary_falsifier());
            for term in tier.canonical_register_terms() {
                for hook in f_hooks_in(term.falsifier()) {
                    if !expected_hooks.contains(&hook) {
                        expected_hooks.push(hook);
                    }
                }
            }
            for hook in f_hooks_in(falsifier_cell) {
                assert!(
                    expected_hooks.contains(&hook),
                    "{} residency row must not name unowned hook {hook}",
                    tier.canonical_name()
                );
            }
        }

        for term in WboTermCode::ALL {
            let needle = format!("| `{}` |", term.code());
            assert!(
                register.contains(&needle),
                "missing WBO term doc row for {}",
                term.code()
            );
            let row_count = register
                .lines()
                .filter(|line| line.starts_with(&needle))
                .count();
            assert_eq!(
                row_count,
                1,
                "{} must name one WBO term obligation row",
                term.code()
            );
            let row = register
                .lines()
                .find(|line| line.starts_with(&needle))
                .expect("term row should exist");
            let cells = row
                .trim_matches('|')
                .split('|')
                .map(str::trim)
                .collect::<Vec<_>>();
            assert!(
                cells.get(1).is_some_and(|cell| cell
                    .to_ascii_lowercase()
                    .contains(&term.obligation().to_ascii_lowercase())),
                "{} doc row must name typed obligation {}",
                term.code(),
                term.obligation()
            );
            let falsifier_cell = cells
                .get(4)
                .unwrap_or_else(|| panic!("{} doc row must have falsifier cell", term.code()));
            for clause in term.falsifier().split(';').map(str::trim) {
                assert!(
                    falsifier_cell.contains(clause),
                    "{} doc falsifier cell must name typed falsifier clause {clause}",
                    term.code()
                );
            }
            let row_hooks = f_hooks_in(row);
            for hook in f_hooks_in(term.falsifier()) {
                assert!(
                    row_hooks.contains(&hook),
                    "{} doc row must name falsifier hook {hook}",
                    term.code()
                );
            }
            let expected_hooks = f_hooks_in(term.falsifier());
            for hook in f_hooks_in(falsifier_cell) {
                assert!(
                    expected_hooks.contains(&hook),
                    "{} doc falsifier cell must not name unowned hook {hook}",
                    term.code()
                );
            }
        }
    }

    fn register_residency_rows(register: &str) -> Vec<String> {
        register
            .lines()
            .skip_while(|line| *line != "## Register")
            .skip(1)
            .take_while(|line| !line.starts_with("## "))
            .filter_map(|line| {
                let name = line.strip_prefix("| ")?.split_once(" |")?.0;
                (name != "Memory tier" && !name.starts_with("---")).then(|| name.to_owned())
            })
            .collect::<Vec<_>>()
    }

    #[test]
    fn register_doc_residency_rows_follow_catalog_order() {
        let register = include_str!("../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
        let expected = ResidencyTier::ALL
            .iter()
            .map(|tier| tier.canonical_name().to_owned())
            .collect::<Vec<_>>();

        assert_eq!(
            register_residency_rows(register),
            expected,
            "residency rows must stay in ResidencyTier::ALL order"
        );
    }

    fn register_wbo_term_rows(register: &str) -> Vec<String> {
        register
            .lines()
            .skip_while(|line| *line != "## WBO Term Obligation Map")
            .skip(1)
            .take_while(|line| !line.starts_with("## "))
            .filter_map(|line| {
                line.strip_prefix("| `")
                    .and_then(|tail| tail.split_once("` |"))
                    .map(|(name, _)| name.to_owned())
            })
            .collect::<Vec<_>>()
    }

    #[test]
    fn register_doc_wbo_term_rows_follow_catalog_order() {
        let register = include_str!("../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
        let expected = WboTermCode::ALL
            .iter()
            .map(|term| term.code().to_owned())
            .collect::<Vec<_>>();

        assert_eq!(
            register_wbo_term_rows(register),
            expected,
            "WBO term rows must stay in WboTermCode::ALL order"
        );
    }

    struct RegisterCanonAnchor {
        path: &'static str,
        section: &'static str,
        line_number: usize,
        source: &'static str,
        expected_heading: &'static str,
        row_title: &'static str,
    }

    impl RegisterCanonAnchor {
        fn doc_anchor(&self) -> String {
            format!("`{}` {} line {}", self.path, self.section, self.line_number)
        }

        fn guardrail_row_prefix(&self) -> String {
            format!("| {}", self.doc_anchor())
        }
    }

    fn register_canon_anchors() -> [RegisterCanonAnchor; 10] {
        let endgame_deck =
            include_str!("../../../docs/NO_COMPROMISE_ENDGAME_PROMPT_DECK_2026_05_18.md");
        let helios_budget = include_str!("../../../docs/fusion/HELIOS_WBO6_BUDGET_2026_05_03.md");
        let master_fusion = include_str!("../../../docs/MASTER_FUSION_NO_COMPROMISE_2026_05_13.md");
        let uas_canon =
            include_str!("../../../docs/fusion/UNIFIED_ACTIVE_SUBSTRATE_CANON_2026_05_16.md");
        [
            RegisterCanonAnchor {
                path: "docs/NO_COMPROMISE_ENDGAME_PROMPT_DECK_2026_05_18.md",
                section: "§4",
                line_number: 346,
                source: endgame_deck,
                expected_heading: "### T17B - Lattice / WBO Register",
                row_title: "T17B - Lattice / WBO Register",
            },
            RegisterCanonAnchor {
                path: "docs/fusion/HELIOS_WBO6_BUDGET_2026_05_03.md",
                section: "§Canonical Inequality Shape",
                line_number: 30,
                source: helios_budget,
                expected_heading: "## Canonical Inequality Shape",
                row_title: "Canonical Inequality Shape",
            },
            RegisterCanonAnchor {
                path: "docs/MASTER_FUSION_NO_COMPROMISE_2026_05_13.md",
                section: "§3.2",
                line_number: 79,
                source: master_fusion,
                expected_heading: "### 3.2 Six-tier memory hierarchy",
                row_title: "Six-tier memory hierarchy",
            },
            RegisterCanonAnchor {
                path: "docs/MASTER_FUSION_NO_COMPROMISE_2026_05_13.md",
                section: "§3.4",
                line_number: 119,
                source: master_fusion,
                expected_heading: "### 3.4 SCOPE-Rex",
                row_title: "SCOPE-Rex",
            },
            RegisterCanonAnchor {
                path: "docs/MASTER_FUSION_NO_COMPROMISE_2026_05_13.md",
                section: "§3.8",
                line_number: 175,
                source: master_fusion,
                expected_heading: "### 3.8 ACS",
                row_title: "ACS",
            },
            RegisterCanonAnchor {
                path: "docs/MASTER_FUSION_NO_COMPROMISE_2026_05_13.md",
                section: "§3.16",
                line_number: 267,
                source: master_fusion,
                expected_heading: "### 3.16 Helios kernels",
                row_title: "Helios kernels",
            },
            RegisterCanonAnchor {
                path: "docs/MASTER_FUSION_NO_COMPROMISE_2026_05_13.md",
                section: "§3.18",
                line_number: 302,
                source: master_fusion,
                expected_heading: "### 3.18 Provenance ledger",
                row_title: "Provenance ledger",
            },
            RegisterCanonAnchor {
                path: "docs/fusion/UNIFIED_ACTIVE_SUBSTRATE_CANON_2026_05_16.md",
                section: "§2",
                line_number: 19,
                source: uas_canon,
                expected_heading: "## 2. The 6 canonical surfaces",
                row_title: "The 6 canonical surfaces",
            },
            RegisterCanonAnchor {
                path: "docs/fusion/UNIFIED_ACTIVE_SUBSTRATE_CANON_2026_05_16.md",
                section: "§4",
                line_number: 49,
                source: uas_canon,
                expected_heading: "## 4. UAS-ACS cross-link map",
                row_title: "UAS-ACS cross-link map",
            },
            RegisterCanonAnchor {
                path: "docs/fusion/UNIFIED_ACTIVE_SUBSTRATE_CANON_2026_05_16.md",
                section: "§5",
                line_number: 91,
                source: uas_canon,
                expected_heading: "## 5. V1 / V1.x / V2 / Never-ships sort",
                row_title: "V1 / V1.x / V2 / Never-ships sort",
            },
        ]
    }

    #[test]
    fn register_doc_canon_line_anchors_match_current_sources() {
        let register = include_str!("../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");

        for anchor in register_canon_anchors() {
            let doc_anchor = anchor.doc_anchor();
            assert!(
                register.contains(&doc_anchor),
                "register missing {doc_anchor}"
            );
            let actual_line = anchor
                .source
                .lines()
                .nth(anchor.line_number - 1)
                .expect("canon anchor line should exist");
            assert!(
                actual_line.contains(anchor.expected_heading),
                "{doc_anchor} points at {actual_line:?}, expected {:?}",
                anchor.expected_heading
            );
        }
    }

    #[test]
    fn register_doc_cross_link_rows_name_canon_paths() {
        let register = include_str!("../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
        let anchors = register_canon_anchors();

        for anchor in anchors {
            let row_prefix = anchor.guardrail_row_prefix();
            assert!(register.contains(&row_prefix), "missing {row_prefix}");
        }
        let anchored_doc_rows = register
            .lines()
            .filter(|line| line.starts_with("| `docs/") && line.contains(" line "))
            .count();
        assert_eq!(
            anchored_doc_rows,
            register_canon_anchors().len(),
            "every canon-source line-anchor row must have an explicit test guard"
        );
    }

    #[test]
    fn register_doc_cross_link_rows_name_current_canon_headings() {
        let register = include_str!("../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");

        for anchor in register_canon_anchors() {
            let actual_heading = anchor
                .source
                .lines()
                .nth(anchor.line_number - 1)
                .expect("canon heading line should exist");
            assert!(
                actual_heading.contains(anchor.expected_heading),
                "{} points at {actual_heading:?}",
                anchor.doc_anchor()
            );
            let row_prefix = anchor.guardrail_row_prefix();
            let row = register
                .lines()
                .find(|line| line.starts_with(&row_prefix))
                .expect("register cross-link row should exist");
            assert!(
                row.contains(anchor.row_title),
                "{row_prefix} row must name current heading title {:?}: {row:?}",
                anchor.row_title
            );
        }
    }

    #[test]
    fn register_doc_json_surface_source_line_anchors_match_current_code() {
        let register = include_str!("../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
        let source = include_str!("mod.rs");
        let required_structs = [
            "FalsifierHookOwner",
            "LatticeErrorContribution",
            "LatticeBudget",
            "ActiveSupportBudget",
            "WboLedgerEntry",
        ];

        for struct_name in required_structs {
            let declaration = format!("pub struct {struct_name}");
            let line_number = source
                .lines()
                .position(|line| line.contains(&declaration))
                .map(|index| index + 1)
                .expect("serialized surface declaration should exist");
            let anchor =
                format!("`agent_core/src/lattice_wbo/mod.rs:{line_number}` `{struct_name}`");
            assert!(
                register.contains(&anchor),
                "register missing serialized source anchor {anchor}"
            );
        }
    }

    #[test]
    fn register_doc_canonical_anchor_list_matches_guardrail_rows() {
        let register = include_str!("../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
        let canonical_anchor_lines = register
            .lines()
            .skip_while(|line| *line != "Canonical anchors:")
            .skip(1)
            .skip_while(|line| line.trim().is_empty())
            .take_while(|line| !line.trim().is_empty())
            .collect::<Vec<_>>();

        for anchor in register_canon_anchors() {
            let path_needle = format!("`{}`", anchor.path);
            let section_line_needle = format!("{} line {}", anchor.section, anchor.line_number);
            assert!(
                canonical_anchor_lines.iter().any(|line| {
                    line.contains(&path_needle) && line.contains(&section_line_needle)
                }),
                "canonical anchor list missing {path_needle} {section_line_needle}"
            );
            assert!(
                register.contains(&format!("| {path_needle} {section_line_needle}")),
                "guardrail table missing {path_needle} {section_line_needle}"
            );
        }
    }

    #[test]
    fn register_doc_keeps_nested_lattice_codec_rows_standalone() {
        let register = include_str!("../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");

        for row_prefix in ["| QuIP/E8 |", "| Nested E8 |", "| Nested Leech24 |"] {
            let row_count = register
                .lines()
                .filter(|line| line.starts_with(row_prefix))
                .count();
            assert_eq!(row_count, 1, "{row_prefix} must name one standalone row");
        }
    }

    #[test]
    fn register_doc_names_every_codec_and_side_information_kind() {
        let register = include_str!("../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");

        assert!(
            register.contains("## Codec-to-Falsifier / Side-Information Coverage"),
            "codec coverage section must name both falsifiers and side information"
        );

        for coder in LatticeCoderKind::ALL {
            let needle = format!("| `{:?}` |", coder);
            assert!(register.contains(&needle), "missing doc row for {coder:?}");
            let row_count = register
                .lines()
                .filter(|line| line.starts_with(&needle))
                .count();
            assert_eq!(row_count, 1, "{coder:?} must name one codec doc row");
            let row = register
                .lines()
                .find(|line| line.starts_with(&needle))
                .expect("codec falsifier row should exist");
            let cells = row
                .trim_matches('|')
                .split('|')
                .map(str::trim)
                .collect::<Vec<_>>();
            let falsifier_cell = cells
                .get(2)
                .unwrap_or_else(|| panic!("{coder:?} doc row must have falsifier cell"));
            for clause in coder.falsifier().split(';').map(str::trim) {
                assert!(
                    falsifier_cell.contains(clause),
                    "{coder:?} doc falsifier cell must name typed falsifier clause {clause}"
                );
            }
            let expected_hooks = f_hooks_in(coder.falsifier());
            for hook in f_hooks_in(falsifier_cell) {
                assert!(
                    expected_hooks.contains(&hook),
                    "{coder:?} doc falsifier cell must not name unowned hook {hook}"
                );
            }
            let side_information_cell = cells
                .get(3)
                .unwrap_or_else(|| panic!("{coder:?} doc row must have side-information cell"));
            for side_information in SideInformationKind::ALL {
                let side_information_name = format!("`{side_information:?}`");
                let expected = coder
                    .canonical_side_information()
                    .contains(&side_information);
                assert_eq!(
                    side_information_cell.contains(&side_information_name),
                    expected,
                    "{coder:?} doc row side-information cell must exactly match {side_information_name} ownership"
                );
            }
        }

        for side_information in SideInformationKind::ALL {
            let needle = format!("| `{:?}` |", side_information);
            assert!(
                register.contains(&needle),
                "missing side-information doc row for {side_information:?}"
            );
            let row_count = register
                .lines()
                .filter(|line| line.starts_with(&needle))
                .count();
            assert_eq!(
                row_count, 1,
                "{side_information:?} must name one side-information doc row"
            );
            let row = register
                .lines()
                .find(|line| line.starts_with(&needle))
                .expect("side-information row should exist");
            let cells = row
                .trim_matches('|')
                .split('|')
                .map(str::trim)
                .collect::<Vec<_>>();
            let caveat = match side_information {
                SideInformationKind::None => "L0 still pays `T_num`",
                SideInformationKind::DecoderLmState => {
                    "Calibration Hessian or runtime KV curvature"
                }
                SideInformationKind::ResidualStream => "Weight-only quantization evidence",
                SideInformationKind::CalibrationHessian => "Runtime KV Hessian",
                SideInformationKind::RuntimeKvHessian => "Offline calibration Hessian",
                SideInformationKind::ActiveSupport => "active support must still pay `T_S`",
                SideInformationKind::SsdOracle => "Proof that NF4 pages are exact",
                SideInformationKind::StaticFactKey => "Dynamic reasoning, residual reconstruction",
                SideInformationKind::NetworkTeacher => "Local lattice decoding",
                SideInformationKind::SurpriseGradient => "KV/cache compression",
            };
            assert!(
                cells.get(2).is_some_and(|cell| cell.contains(caveat)),
                "{side_information:?} doc row must preserve caveat {caveat}"
            );
        }
    }

    fn register_codec_rows(register: &str) -> Vec<String> {
        register
            .lines()
            .skip_while(|line| *line != "## Codec-to-Falsifier / Side-Information Coverage")
            .skip(1)
            .take_while(|line| !line.starts_with("## "))
            .filter_map(|line| {
                line.strip_prefix("| `")
                    .and_then(|tail| tail.split_once("` |"))
                    .map(|(name, _)| name.to_owned())
            })
            .collect::<Vec<_>>()
    }

    #[test]
    fn register_doc_codec_rows_follow_catalog_order() {
        let register = include_str!("../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
        let expected = LatticeCoderKind::ALL
            .iter()
            .map(|coder| format!("{coder:?}"))
            .collect::<Vec<_>>();

        assert_eq!(
            register_codec_rows(register),
            expected,
            "codec coverage rows must stay in LatticeCoderKind::ALL order"
        );
    }

    fn register_side_information_rows(register: &str) -> Vec<String> {
        register
            .lines()
            .skip_while(|line| *line != "## Side-Information Decoding Kinds")
            .skip(1)
            .take_while(|line| !line.starts_with("## "))
            .filter_map(|line| {
                line.strip_prefix("| `")
                    .and_then(|tail| tail.split_once("` |"))
                    .map(|(name, _)| name.to_owned())
            })
            .collect::<Vec<_>>()
    }

    #[test]
    fn register_doc_side_information_rows_follow_catalog_order() {
        let register = include_str!("../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
        let expected = SideInformationKind::ALL
            .iter()
            .map(|side_information| format!("{side_information:?}"))
            .collect::<Vec<_>>();

        assert_eq!(
            register_side_information_rows(register),
            expected,
            "side-information rows must stay in SideInformationKind::ALL order"
        );
    }

    fn register_error_rows(register: &str) -> Vec<String> {
        assert!(
            register.contains("## Error Variant Register"),
            "register must include a dedicated LatticeWboError section"
        );
        register
            .lines()
            .skip_while(|line| *line != "## Error Variant Register")
            .skip(1)
            .take_while(|line| !line.starts_with("## "))
            .filter_map(|line| {
                line.strip_prefix("| `")
                    .and_then(|tail| tail.split_once("` |"))
                    .map(|(name, _)| name.to_owned())
            })
            .collect::<Vec<_>>()
    }

    #[test]
    fn register_doc_names_every_lattice_wbo_error_variant() {
        let register = include_str!("../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");

        let expected = LatticeWboError::ALL
            .iter()
            .map(|error| format!("{error:?}"))
            .collect::<Vec<_>>();
        let actual_rows = register_error_rows(register);

        assert_eq!(
            actual_rows.len(),
            expected.len(),
            "error register must not keep stale or missing rows"
        );
        for row in &actual_rows {
            assert!(
                expected.contains(row),
                "error register row {row} is not in LatticeWboError::ALL"
            );
        }
        for error in LatticeWboError::ALL {
            let needle = format!("| `{:?}` |", error);
            let row_count = register
                .lines()
                .filter(|line| line.starts_with(&needle))
                .count();
            assert_eq!(row_count, 1, "{error:?} must name one register error row");
        }
    }

    #[test]
    fn register_doc_error_variant_rows_follow_lattice_wbo_error_all_order() {
        let register = include_str!("../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
        let expected = LatticeWboError::ALL
            .iter()
            .map(|error| format!("{error:?}"))
            .collect::<Vec<_>>();

        assert_eq!(
            register_error_rows(register),
            expected,
            "error register rows must stay in LatticeWboError::ALL order"
        );
    }

    #[test]
    fn register_doc_names_tier_specific_security_verifier_clauses() {
        let register = include_str!("../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
        let expected = [
            (
                ResidencyTier::L5NetworkCascade,
                "provider/provenance replay",
            ),
            (
                ResidencyTier::LSeSelfEvolving,
                "adapter replay/provenance verifier",
            ),
        ];

        for (tier, verifier) in expected {
            let needle = format!("| {} |", tier.canonical_name());
            let row = register
                .lines()
                .find(|line| line.starts_with(&needle))
                .unwrap_or_else(|| {
                    panic!("missing register doc row for {}", tier.canonical_name())
                });
            let cells = row
                .trim_matches('|')
                .split('|')
                .map(str::trim)
                .collect::<Vec<_>>();
            let falsifier_cell = cells.get(4).unwrap_or_else(|| {
                panic!("{} doc row must have falsifier cell", tier.canonical_name())
            });
            let clauses = falsifier_cell.split(';').map(str::trim).collect::<Vec<_>>();
            assert!(
                clauses.contains(&verifier),
                "{} doc row must name exact security verifier clause {verifier}",
                tier.canonical_name()
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
            for (index, term) in coder.canonical_wbo_terms().iter().enumerate() {
                assert!(
                    !coder.canonical_wbo_terms()[index + 1..].contains(term),
                    "{coder:?} must not duplicate {} in canonical WBO terms",
                    term.code()
                );
            }
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
        let owner_rows = owners
            .iter()
            .map(|owner| (owner.hook, owner.owner))
            .collect::<Vec<_>>();
        assert_eq!(
            owner_rows,
            vec![
                (
                    "F-WBO-DriftLedger",
                    "docs/fusion/HELIOS_WBO6_BUDGET_2026_05_03.md",
                ),
                ("F-ULP-Oracle", "agent_core/src/research/eml/ulp_oracle.rs"),
                (
                    "F-KV-Direct-Gate",
                    "agent_core/src/scope_rex/kv/direct_gate.rs",
                ),
                ("F-ACS-AnchorLookup", "agent_core/src/research/acs/mod.rs"),
            ]
        );
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
    fn falsifier_hook_owner_registry_has_unique_public_hooks() {
        assert_unique_catalog_keys(
            falsifier_hook_owners()
                .iter()
                .map(|owner| owner.hook.to_owned())
                .collect(),
            "falsifier hook owner registry",
        );
    }

    #[test]
    fn falsifier_hook_registry_owner_rows_follow_canonical_order() {
        let hooks = falsifier_hook_owners()
            .iter()
            .map(|owner| owner.hook)
            .collect::<Vec<_>>();

        assert_eq!(
            hooks,
            vec![
                "F-WBO-DriftLedger",
                "F-ULP-Oracle",
                "F-KV-Direct-Gate",
                "F-ACS-AnchorLookup",
            ],
            "falsifier owner rows must stay in canonical owner order"
        );
    }

    #[test]
    fn falsifier_hook_owner_registry_serializes_public_keys() {
        let encoded =
            serde_json::to_value(falsifier_hook_owners()).expect("serialize falsifier owners");
        let rows = encoded
            .as_array()
            .expect("owner registry serializes as rows");
        assert_eq!(rows.len(), falsifier_hook_owners().len());

        for row in rows {
            let object = row.as_object().expect("owner row must serialize as object");
            let mut keys = object.keys().map(String::as_str).collect::<Vec<_>>();
            keys.sort_unstable();
            assert_eq!(keys, vec!["hook", "owner"]);
            assert!(object["hook"]
                .as_str()
                .expect("hook must serialize as string")
                .starts_with("F-"));
            assert!(!object["owner"]
                .as_str()
                .expect("owner must serialize as string")
                .trim()
                .is_empty());
        }
    }

    #[test]
    fn falsifier_hook_owner_json_rejects_unknown_fields() {
        let error = serde_json::from_str::<FalsifierHookOwner>(
            r#"{
                "hook": "F-WBO-DriftLedger",
                "owner": "docs/fusion/HELIOS_WBO6_BUDGET_2026_05_03.md",
                "debug": "ignored field"
            }"#,
        )
        .expect_err("unknown falsifier owner JSON field must be rejected");
        let message = error.to_string();
        assert!(message.contains("unknown field"), "{message}");
        assert!(message.contains("debug"), "{message}");
    }

    #[test]
    fn falsifier_hook_owner_json_rejects_unregistered_public_rows() {
        for (label, row) in [
            (
                "unowned hook",
                r#"{
                    "hook": "F-NOT-OWNED",
                    "owner": "docs/fusion/HELIOS_WBO6_BUDGET_2026_05_03.md"
                }"#,
            ),
            (
                "unicode-adjacent hook suffix",
                r#"{
                    "hook": "F-ULP-Oracleβ",
                    "owner": "agent_core/src/research/eml/ulp_oracle.rs"
                }"#,
            ),
            (
                "unicode-adjacent hook prefix",
                r#"{
                    "hook": "βF-ULP-Oracle",
                    "owner": "agent_core/src/research/eml/ulp_oracle.rs"
                }"#,
            ),
            (
                "blank owner",
                r#"{
                    "hook": "F-WBO-DriftLedger",
                    "owner": " "
                }"#,
            ),
            (
                "mismatched owner",
                r#"{
                    "hook": "F-WBO-DriftLedger",
                    "owner": "agent_core/src/research/eml/ulp_oracle.rs"
                }"#,
            ),
        ] {
            assert!(
                serde_json::from_str::<FalsifierHookOwner>(row).is_err(),
                "{label} must not deserialize as a falsifier owner row"
            );
        }

        let ulp_owner = serde_json::from_str::<FalsifierHookOwner>(
            r#"{
                "hook": "F-ULP-Oracle",
                "owner": "agent_core/src/research/eml/ulp_oracle.rs"
            }"#,
        )
        .expect("canonical falsifier owner row should deserialize");
        assert_eq!(ulp_owner, FALSIFIER_HOOK_OWNERS[1]);
    }

    #[test]
    fn falsifier_hook_owner_json_rejects_cross_owner_borrowing() {
        for owner in falsifier_hook_owners() {
            for other in falsifier_hook_owners() {
                if owner == other {
                    continue;
                }

                let borrowed_owner = serde_json::json!({
                    "hook": owner.hook,
                    "owner": other.owner,
                });
                assert!(
                    serde_json::from_value::<FalsifierHookOwner>(borrowed_owner).is_err(),
                    "{} must not borrow {}",
                    owner.hook,
                    other.owner
                );

                let borrowed_hook = serde_json::json!({
                    "hook": other.hook,
                    "owner": owner.owner,
                });
                assert!(
                    serde_json::from_value::<FalsifierHookOwner>(borrowed_hook).is_err(),
                    "{} must not borrow {}",
                    owner.owner,
                    other.hook
                );
            }
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
    fn codec_falsifier_catalogs_cover_every_owned_f_hook() {
        let mut codec_hooks = Vec::new();
        for coder in LatticeCoderKind::ALL {
            codec_hooks.extend(f_hooks_in(coder.falsifier()));
        }
        codec_hooks.sort_unstable();
        codec_hooks.dedup();

        for owner in falsifier_hook_owners() {
            assert!(
                codec_hooks.contains(&owner.hook),
                "{} owner hook must be emitted by at least one codec falsifier row",
                owner.hook
            );
        }
    }

    #[test]
    fn residency_primary_falsifiers_name_owned_f_hooks_for_every_tier() {
        let owners = falsifier_hook_owners();

        for tier in ResidencyTier::ALL {
            let hooks = f_hooks_in(tier.primary_falsifier());
            assert!(
                !hooks.is_empty(),
                "{} must name at least one F-* hook",
                tier.canonical_name()
            );
            for hook in hooks {
                assert!(
                    owners.iter().any(|owner| owner.hook == hook),
                    "{} names unowned falsifier hook {hook}",
                    tier.canonical_name()
                );
            }
        }
    }

    #[test]
    fn residency_primary_falsifiers_cover_every_owned_f_hook() {
        let mut residency_hooks = Vec::new();
        for tier in ResidencyTier::ALL {
            residency_hooks.extend(f_hooks_in(tier.primary_falsifier()));
        }
        residency_hooks.sort_unstable();
        residency_hooks.dedup();

        for owner in falsifier_hook_owners() {
            assert!(
                residency_hooks.contains(&owner.hook),
                "{} owner hook must be emitted by at least one residency primary falsifier",
                owner.hook
            );
        }
    }

    fn lattice_wbo_repo_root() -> std::path::PathBuf {
        std::path::Path::new(env!("CARGO_MANIFEST_DIR"))
            .parent()
            .expect("agent_core should have a repository parent")
            .to_path_buf()
    }

    #[test]
    fn falsifier_hook_registry_owner_paths_exist() {
        let repo_root = lattice_wbo_repo_root();

        for owner in falsifier_hook_owners() {
            let owner_path = std::path::Path::new(owner.owner);
            assert!(
                owner_path.is_relative()
                    && !owner_path
                        .components()
                        .any(|component| matches!(component, std::path::Component::ParentDir)),
                "{} owner path must be relative to the repository without `..`: {}",
                owner.hook,
                owner.owner
            );
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
    fn falsifier_hook_registry_owner_paths_stay_in_canonical_surfaces() {
        let allowed_prefixes = [
            "docs/fusion/",
            "agent_core/src/research/",
            "agent_core/src/scope_rex/",
        ];

        for owner in falsifier_hook_owners() {
            assert!(
                allowed_prefixes
                    .iter()
                    .any(|prefix| owner.owner.starts_with(prefix)),
                "{} owner path must stay in a canonical falsifier surface: {}",
                owner.hook,
                owner.owner
            );
        }
    }

    #[test]
    fn falsifier_hook_owner_files_name_their_hooks() {
        let repo_root = lattice_wbo_repo_root();

        for owner in falsifier_hook_owners() {
            let path = repo_root.join(owner.owner);
            let contents = std::fs::read_to_string(&path)
                .unwrap_or_else(|error| panic!("failed to read {}: {error}", path.display()));
            assert!(
                contents.contains(owner.hook),
                "{} owner file must name owned hook {}",
                owner.owner,
                owner.hook
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
        let mut owner_hooks = owners.iter().map(|owner| owner.hook).collect::<Vec<_>>();
        owner_hooks.sort_unstable();

        for hook in &hooks {
            assert!(
                owners.iter().any(|owner| owner.hook == *hook),
                "register hook {hook} must have a falsifier owner"
            );
        }
        assert_eq!(
            hooks, owner_hooks,
            "register F-* hook set must match falsifier owner registry"
        );
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
    fn cache_offload_codecs_pin_kv_boundary_quantization_and_numerical_terms() {
        assert_eq!(
            LatticeCoderKind::ShadowKvSketch.canonical_wbo_terms(),
            &[
                WboTermCode::KvCache,
                WboTermCode::SubstrateBoundary,
                WboTermCode::NumericalPostCorrection,
            ]
        );
        assert_eq!(
            LatticeCoderKind::Nf4SsdOracle.canonical_wbo_terms(),
            &[
                WboTermCode::KvCache,
                WboTermCode::Quantization,
                WboTermCode::SubstrateBoundary,
                WboTermCode::NumericalPostCorrection,
            ]
        );
    }

    #[test]
    fn exact_hot_codec_pins_reference_term_and_side_information() {
        assert_eq!(
            LatticeCoderKind::ExactHot.canonical_wbo_terms(),
            &[WboTermCode::NumericalPostCorrection]
        );
        assert_eq!(
            LatticeCoderKind::ExactHot.canonical_side_information(),
            &[SideInformationKind::None]
        );
        assert!(!LatticeCoderKind::ExactHot.allows_rate_parameter());
        assert_eq!(
            LatticeCoderKind::ExactHot.falsifier(),
            "F-WBO-DriftLedger; F-ULP-Oracle"
        );
    }

    #[test]
    fn nested_lattice_codecs_pin_weight_quantization_terms_and_rate() {
        for coder in [LatticeCoderKind::NestedE8, LatticeCoderKind::NestedLeech24] {
            assert!(
                coder.allows_rate_parameter(),
                "{coder:?} must keep explicit rate ownership"
            );
            assert_eq!(
                coder.canonical_wbo_terms(),
                &[
                    WboTermCode::WeightRuntime,
                    WboTermCode::Quantization,
                    WboTermCode::NumericalPostCorrection,
                ],
                "{coder:?} must stay a weight plus quantization lane"
            );
            assert_eq!(
                coder.canonical_side_information(),
                &[SideInformationKind::CalibrationHessian],
                "{coder:?} must use calibration-side weight evidence only"
            );
        }
    }

    #[test]
    fn quip_e8_codec_pins_weight_quantization_terms_and_rate() {
        assert!(LatticeCoderKind::QuipE8.allows_rate_parameter());
        assert_eq!(
            LatticeCoderKind::QuipE8.canonical_wbo_terms(),
            &[
                WboTermCode::WeightRuntime,
                WboTermCode::Quantization,
                WboTermCode::NumericalPostCorrection,
            ]
        );
        assert_eq!(
            LatticeCoderKind::QuipE8.canonical_side_information(),
            &[SideInformationKind::CalibrationHessian]
        );
    }

    #[test]
    fn sherry_ternary_codec_pins_weight_terms_rate_and_calibration_side_information() {
        assert!(LatticeCoderKind::SherryTernary3Of4.allows_rate_parameter());
        assert_eq!(
            LatticeCoderKind::SherryTernary3Of4.canonical_wbo_terms(),
            &[
                WboTermCode::WeightRuntime,
                WboTermCode::Quantization,
                WboTermCode::NumericalPostCorrection,
            ]
        );
        assert_eq!(
            LatticeCoderKind::SherryTernary3Of4.canonical_side_information(),
            &[SideInformationKind::CalibrationHessian]
        );
        assert!(!LatticeCoderKind::SherryTernary3Of4
            .canonical_wbo_terms()
            .contains(&WboTermCode::ResidualWynerZiv));
        assert!(!LatticeCoderKind::SherryTernary3Of4
            .canonical_side_information()
            .contains(&SideInformationKind::ResidualStream));
    }

    #[test]
    fn lattice_wyner_ziv_residual_codec_pins_terms_rate_and_decoder_witnesses() {
        assert!(LatticeCoderKind::LatticeWynerZivResidual.allows_rate_parameter());
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
            LatticeCoderKind::LatticeWynerZivResidual.canonical_side_information(),
            &[
                SideInformationKind::DecoderLmState,
                SideInformationKind::ResidualStream,
                SideInformationKind::ActiveSupport,
                SideInformationKind::SsdOracle,
            ]
        );
    }

    #[test]
    fn residual_sketch_codec_pins_correction_terms_and_side_information() {
        assert!(LatticeCoderKind::ResidualSketch.allows_rate_parameter());
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
            LatticeCoderKind::ResidualSketch.canonical_side_information(),
            &[
                SideInformationKind::ResidualStream,
                SideInformationKind::DecoderLmState,
                SideInformationKind::ActiveSupport,
            ]
        );
    }

    #[test]
    fn engram_hash_recall_codec_pins_static_fact_boundary() {
        assert!(!LatticeCoderKind::EngramHashRecall.allows_rate_parameter());
        assert_eq!(
            LatticeCoderKind::EngramHashRecall.canonical_wbo_terms(),
            &[
                WboTermCode::SubstrateBoundary,
                WboTermCode::NumericalPostCorrection,
            ]
        );
        assert_eq!(
            LatticeCoderKind::EngramHashRecall.canonical_side_information(),
            &[SideInformationKind::StaticFactKey]
        );
        assert!(!LatticeCoderKind::EngramHashRecall
            .canonical_wbo_terms()
            .contains(&WboTermCode::KvCache));
        assert!(!LatticeCoderKind::EngramHashRecall
            .canonical_wbo_terms()
            .contains(&WboTermCode::ResidualWynerZiv));
    }

    #[test]
    fn network_cascade_codec_pins_teacher_boundary_terms_and_side_information() {
        assert!(!LatticeCoderKind::NetworkCascade.allows_rate_parameter());
        assert_eq!(
            LatticeCoderKind::NetworkCascade.canonical_wbo_terms(),
            &[
                WboTermCode::SubstrateBoundary,
                WboTermCode::SelfEvolvingSecurity,
                WboTermCode::NumericalPostCorrection,
            ]
        );
        assert_eq!(
            LatticeCoderKind::NetworkCascade.canonical_side_information(),
            &[SideInformationKind::NetworkTeacher]
        );
        assert!(LatticeCoderKind::NetworkCascade
            .falsifier()
            .contains("provider/provenance replay"));
        assert!(!LatticeCoderKind::NetworkCascade
            .canonical_wbo_terms()
            .contains(&WboTermCode::KvCache));
    }

    #[test]
    fn self_evolving_adapter_codec_pins_mutation_terms_and_side_information() {
        assert!(!LatticeCoderKind::SelfEvolvingAdapter.allows_rate_parameter());
        assert_eq!(
            LatticeCoderKind::SelfEvolvingAdapter.canonical_wbo_terms(),
            &[
                WboTermCode::WeightRuntime,
                WboTermCode::SelfEvolvingSecurity,
                WboTermCode::NumericalPostCorrection,
            ]
        );
        assert_eq!(
            LatticeCoderKind::SelfEvolvingAdapter.canonical_side_information(),
            &[SideInformationKind::SurpriseGradient]
        );
        assert!(LatticeCoderKind::SelfEvolvingAdapter
            .falsifier()
            .contains("adapter replay/provenance verifier"));
        assert!(!LatticeCoderKind::SelfEvolvingAdapter
            .canonical_wbo_terms()
            .contains(&WboTermCode::KvCache));
        assert!(!LatticeCoderKind::SelfEvolvingAdapter
            .canonical_wbo_terms()
            .contains(&WboTermCode::ResidualWynerZiv));
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
            for (index, side_information) in coder.canonical_side_information().iter().enumerate() {
                assert!(
                    !coder.canonical_side_information()[index + 1..].contains(side_information),
                    "{coder:?} must not duplicate {side_information:?} in canonical side information"
                );
            }
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
    fn lattice_coder_catalog_marks_non_rate_codecs() {
        let non_rate = LatticeCoderKind::ALL
            .iter()
            .copied()
            .filter(|coder| !coder.allows_rate_parameter())
            .collect::<Vec<_>>();

        assert_eq!(
            non_rate,
            vec![
                LatticeCoderKind::ExactHot,
                LatticeCoderKind::BabaiGptqNearestPlane,
                LatticeCoderKind::ShadowKvSketch,
                LatticeCoderKind::EngramHashRecall,
                LatticeCoderKind::NetworkCascade,
                LatticeCoderKind::SelfEvolvingAdapter,
            ]
        );
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
    fn lattice_budget_composition_requires_numerical_post_correction_term() {
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
            budget.validate_composition(),
            Err(LatticeWboError::MissingNumericalPostCorrectionTerm)
        );
    }

    #[test]
    fn lattice_budget_composition_rejects_empty_source_public_contributions() {
        let contribution = LatticeErrorContribution {
            term: WboTermCode::NumericalPostCorrection,
            source: " ".to_string(),
            budget: 0.0,
            measured: Some(0.0),
        };
        let budget = LatticeBudget::new(
            LatticeCoderKind::ExactHot,
            None,
            SideInformationKind::None,
            vec![contribution],
        );

        assert_eq!(
            budget.validate_composition(),
            Err(LatticeWboError::EmptySource)
        );
        assert_eq!(budget.validate(), Err(LatticeWboError::EmptySource));
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
        assert_eq!(
            budget.validate_composition(),
            Err(LatticeWboError::MissingNumericalPostCorrectionTerm)
        );
        assert_budget_measurements_pending(&budget);
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
        assert_eq!(
            budget.validate_composition(),
            Err(LatticeWboError::InvalidSideInformation)
        );
        assert_budget_measurements_pending(&budget);
    }

    #[test]
    fn lattice_budget_measured_status_returns_none_for_every_noncanonical_side_information() {
        let mut checked = 0;
        for coder in LatticeCoderKind::ALL {
            let allowed = coder.canonical_side_information();
            for side_information in SideInformationKind::ALL {
                if allowed.contains(&side_information) {
                    continue;
                }

                let budget = measured_probe_budget(
                    coder,
                    coder.allows_rate_parameter().then_some(1250),
                    side_information,
                );

                assert_eq!(
                    budget.validate(),
                    Err(LatticeWboError::InvalidSideInformation),
                    "{coder:?} measured status accepted noncanonical side information {side_information:?}"
                );
                assert_eq!(
                    budget.validate_composition(),
                    Err(LatticeWboError::InvalidSideInformation),
                    "{coder:?} measured composition accepted noncanonical side information {side_information:?}"
                );
                assert_budget_measurements_pending(&budget);
                checked += 1;
            }
        }

        let expected = LatticeCoderKind::ALL
            .iter()
            .map(|coder| SideInformationKind::ALL.len() - coder.canonical_side_information().len())
            .sum::<usize>();
        assert_eq!(checked, expected);
    }

    #[test]
    fn lattice_budget_measured_status_returns_none_for_invalid_rate() {
        let mut checked = 0;
        for coder in LatticeCoderKind::ALL
            .iter()
            .copied()
            .filter(|coder| coder.allows_rate_parameter())
        {
            for invalid_rate in [None, Some(0)] {
                let budget = measured_probe_budget(
                    coder,
                    invalid_rate,
                    coder.canonical_side_information()[0],
                );

                assert_eq!(budget.validate(), Err(LatticeWboError::InvalidRate));
                assert_eq!(
                    budget.validate_composition(),
                    Err(LatticeWboError::InvalidRate)
                );
                assert_budget_measurements_pending(&budget);
                checked += 1;
            }
        }
        for coder in LatticeCoderKind::ALL
            .iter()
            .copied()
            .filter(|coder| !coder.allows_rate_parameter())
        {
            let budget =
                measured_probe_budget(coder, Some(1250), coder.canonical_side_information()[0]);

            assert_eq!(budget.validate(), Err(LatticeWboError::InvalidRate));
            assert_eq!(
                budget.validate_composition(),
                Err(LatticeWboError::InvalidRate)
            );
            assert_budget_measurements_pending(&budget);
            checked += 1;
        }

        let rate_codec_count = LatticeCoderKind::ALL
            .iter()
            .filter(|coder| coder.allows_rate_parameter())
            .count();
        let non_rate_codec_count = LatticeCoderKind::ALL.len() - rate_codec_count;
        assert_eq!(checked, (2 * rate_codec_count) + non_rate_codec_count);
    }

    #[test]
    fn lattice_budget_validation_rejects_terms_outside_codec_map() {
        let mut checked = 0;
        for coder in LatticeCoderKind::ALL {
            let canonical_terms = coder.canonical_wbo_terms();
            for term in WboTermCode::ALL {
                if canonical_terms.contains(&term) {
                    continue;
                }

                let invalid_term =
                    LatticeErrorContribution::new(term, format!("invalid {}", term.code()), 0.01)
                        .expect("valid contribution");
                let numerical = LatticeErrorContribution::new(
                    WboTermCode::NumericalPostCorrection,
                    "softmax half correction",
                    0.0,
                )
                .expect("valid numerical contribution");
                let invalid = LatticeBudget::new(
                    coder,
                    coder.allows_rate_parameter().then_some(1250),
                    coder.canonical_side_information()[0],
                    vec![invalid_term, numerical],
                );
                assert_eq!(
                    invalid.validate(),
                    Err(LatticeWboError::InvalidWboTermForCodec),
                    "{coder:?} accepted noncanonical WBO term {term:?}"
                );
                assert_eq!(
                    invalid.validate_composition(),
                    Err(LatticeWboError::InvalidWboTermForCodec),
                    "{coder:?} composition accepted noncanonical WBO term {term:?}"
                );
                checked += 1;
            }
        }

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
        let expected = LatticeCoderKind::ALL
            .iter()
            .map(|coder| WboTermCode::ALL.len() - coder.canonical_wbo_terms().len())
            .sum::<usize>();
        assert_eq!(checked, expected);
    }

    #[test]
    fn lattice_budget_validation_rejects_foreign_terms_before_missing_t_num() {
        let mut checked = 0;

        for coder in LatticeCoderKind::ALL {
            let canonical_terms = coder.canonical_wbo_terms();
            for term in WboTermCode::ALL {
                if canonical_terms.contains(&term) {
                    continue;
                }

                let invalid_term = LatticeErrorContribution::new(
                    term,
                    format!("{coder:?} foreign {}", term.code()),
                    0.01,
                )
                .expect("valid foreign contribution shape");
                let budget = LatticeBudget::new(
                    coder,
                    coder.allows_rate_parameter().then_some(1250),
                    coder.canonical_side_information()[0],
                    vec![invalid_term],
                );

                assert!(
                    !budget.contributions.iter().any(|contribution| {
                        contribution.term == WboTermCode::NumericalPostCorrection
                    }),
                    "{coder:?} fixture must also omit T_num"
                );
                assert_eq!(
                    budget.validate_terms(),
                    Err(LatticeWboError::InvalidWboTermForCodec),
                    "{coder:?} fixture must carry a real foreign term {term:?}"
                );
                assert_eq!(
                    budget.validate(),
                    Err(LatticeWboError::InvalidWboTermForCodec),
                    "{coder:?} full validation let missing T_num hide {term:?}"
                );
                assert_eq!(
                    budget.validate_composition(),
                    Err(LatticeWboError::InvalidWboTermForCodec),
                    "{coder:?} composition let missing T_num hide {term:?}"
                );
                checked += 1;
            }
        }

        let expected = LatticeCoderKind::ALL
            .iter()
            .map(|coder| WboTermCode::ALL.len() - coder.canonical_wbo_terms().len())
            .sum::<usize>();
        assert_eq!(checked, expected);
    }

    #[test]
    fn lattice_budget_measured_status_returns_none_for_invalid_terms() {
        let mut checked = 0;
        for coder in LatticeCoderKind::ALL {
            let canonical_terms = coder.canonical_wbo_terms();
            for term in WboTermCode::ALL {
                if canonical_terms.contains(&term) {
                    continue;
                }

                let invalid_term =
                    LatticeErrorContribution::new(term, format!("invalid {}", term.code()), 0.01)
                        .expect("valid contribution")
                        .with_measured(0.01)
                        .expect("valid measurement");
                let numerical = LatticeErrorContribution::new(
                    WboTermCode::NumericalPostCorrection,
                    "softmax half correction",
                    0.0,
                )
                .expect("valid numerical contribution")
                .with_measured(0.0)
                .expect("valid numerical measurement");
                let budget = LatticeBudget::new(
                    coder,
                    coder.allows_rate_parameter().then_some(1250),
                    coder.canonical_side_information()[0],
                    vec![invalid_term, numerical],
                );

                assert_eq!(
                    budget.validate(),
                    Err(LatticeWboError::InvalidWboTermForCodec),
                    "{coder:?} measured status accepted noncanonical WBO term {term:?}"
                );
                assert_eq!(
                    budget.validate_composition(),
                    Err(LatticeWboError::InvalidWboTermForCodec),
                    "{coder:?} measured composition accepted noncanonical WBO term {term:?}"
                );
                assert_budget_measurements_pending(&budget);
                checked += 1;
            }
        }

        let expected = LatticeCoderKind::ALL
            .iter()
            .map(|coder| WboTermCode::ALL.len() - coder.canonical_wbo_terms().len())
            .sum::<usize>();
        assert_eq!(checked, expected);
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
        assert_eq!(
            budget.validate_composition(),
            Err(LatticeWboError::EmptyContributions)
        );
        assert_budget_measurements_pending(&budget);
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
        assert_eq!(
            budget.validate(),
            Err(LatticeWboError::InvalidBudgetComposition)
        );
        assert_budget_measurements_pending(&budget);
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
        assert_eq!(
            budget.validate_composition(),
            Err(LatticeWboError::InvalidBudget)
        );
        assert_budget_measurements_pending(&budget);
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
    fn lattice_budget_composition_handles_signed_max_and_mixed_axes() {
        let max_residual =
            LatticeErrorContribution::new(WboTermCode::ResidualWynerZiv, "max residual", f64::MAX)
                .expect("single finite max residual")
                .with_measured(f64::MAX)
                .expect("single finite max residual measurement");
        let zero_numerics = LatticeErrorContribution::new(
            WboTermCode::NumericalPostCorrection,
            "zero numerics",
            0.0,
        )
        .expect("valid zero numerical guard")
        .with_measured(0.0)
        .expect("valid zero numerical measurement");
        let single_max_mixed_axis = LatticeBudget::new(
            LatticeCoderKind::LatticeWynerZivResidual,
            Some(1250),
            SideInformationKind::ResidualStream,
            vec![max_residual.clone(), zero_numerics.clone()],
        );

        assert_eq!(single_max_mixed_axis.validate(), Ok(()));
        assert_eq!(
            single_max_mixed_axis.measured_pre_softmax_total(),
            Some(f64::MAX)
        );
        assert_eq!(single_max_mixed_axis.measured_within_budget(), Some(true));

        let overflowed_mixed_axes = LatticeBudget::new(
            LatticeCoderKind::LatticeWynerZivResidual,
            Some(1250),
            SideInformationKind::ResidualStream,
            vec![
                max_residual,
                LatticeErrorContribution::new(
                    WboTermCode::NumericalPostCorrection,
                    "max numerics",
                    f64::MAX,
                )
                .expect("single finite max numerical guard")
                .with_measured(f64::MAX)
                .expect("single finite max numerical measurement"),
            ],
        );

        assert_eq!(
            overflowed_mixed_axes.validate(),
            Err(LatticeWboError::InvalidBudgetComposition)
        );
        assert_eq!(overflowed_mixed_axes.measured_pre_softmax_total(), None);
        assert_eq!(overflowed_mixed_axes.measured_within_budget(), None);

        let signed_mixed_axis = LatticeBudget::new(
            LatticeCoderKind::LatticeWynerZivResidual,
            Some(1250),
            SideInformationKind::ResidualStream,
            vec![
                LatticeErrorContribution {
                    term: WboTermCode::ResidualWynerZiv,
                    source: "signed residual".to_string(),
                    budget: -1.0,
                    measured: Some(0.0),
                },
                zero_numerics,
            ],
        );

        assert_eq!(
            signed_mixed_axis.validate_composition(),
            Err(LatticeWboError::InvalidBudget)
        );
        assert_eq!(
            signed_mixed_axis.validate(),
            Err(LatticeWboError::InvalidBudget)
        );
        assert_budget_measurements_pending(&signed_mixed_axis);
    }

    #[test]
    fn wbo_term_codes_are_trimmed_ascii_axis_keys() {
        for term in WboTermCode::ALL {
            let code = term.code();
            let debug = format!("{term:?}");
            assert!(!code.is_empty(), "{term:?}");
            assert_eq!(code.trim(), code, "{term:?}");
            assert!(code.is_ascii(), "{term:?}");
            assert!(code.starts_with("T_"), "{term:?}");
            assert!(!code.contains("  "), "{term:?}");
            assert_ne!(code, debug.as_str(), "{term:?}");

            if term == WboTermCode::NumericalPostCorrection {
                assert_eq!(code, "T_num");
            } else {
                assert!(
                    !code.chars().any(|ch| ch.is_ascii_lowercase()),
                    "{term:?} code {code}"
                );
                assert!(
                    code.chars()
                        .all(|ch| ch == '_' || ch.is_ascii_uppercase() || ch.is_ascii_digit()),
                    "{term:?} code {code}"
                );
            }
        }
    }

    #[test]
    fn wbo_term_catalog_names_obligations_for_every_axis() {
        for term in WboTermCode::ALL {
            assert!(!term.obligation().is_empty());
        }
        assert_eq!(
            WboTermCode::ALL
                .iter()
                .map(|term| (term.code(), term.obligation()))
                .collect::<Vec<_>>(),
            vec![
                ("T_W", "lattice/weight/runtime perturbation"),
                ("T_K", "KV/cache compression and restore drift"),
                ("T_R", "residual reconstruction gap"),
                ("T_Q", "quantization approximation"),
                ("T_S", "side-information and active-support boundary"),
                ("T_SE", "self-evolving or security enforcement"),
                ("T_num", "numerical guard before softmax half-contraction"),
            ]
        );
    }

    #[test]
    fn wbo_term_catalog_names_falsifiers_for_every_axis() {
        for term in WboTermCode::ALL {
            assert!(!term.falsifier().is_empty());
        }
        assert_eq!(
            WboTermCode::ALL
                .iter()
                .map(|term| (term.code(), term.falsifier()))
                .collect::<Vec<_>>(),
            vec![
                (
                    "T_W",
                    "F-WBO-DriftLedger; layerwise reconstruction/logit drift witness",
                ),
                ("T_K", "F-KV-Direct-Gate; F-WBO-DriftLedger"),
                ("T_R", "F-WBO-DriftLedger; residual KL slice"),
                (
                    "T_Q",
                    "F-WBO-DriftLedger; layerwise reconstruction/logit drift witness",
                ),
                (
                    "T_S",
                    "F-ACS-AnchorLookup; provider/provenance replay; F-WBO-DriftLedger",
                ),
                (
                    "T_SE",
                    "adapter replay/provenance verifier; provider/provenance replay; F-WBO-DriftLedger",
                ),
                ("T_num", "F-ULP-Oracle; F-WBO-DriftLedger"),
            ]
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
    fn term_falsifier_catalogs_name_owned_f_hooks_for_every_axis() {
        let owners = falsifier_hook_owners();

        for term in WboTermCode::ALL {
            let hooks = f_hooks_in(term.falsifier());
            assert!(
                !hooks.is_empty(),
                "{} must name at least one F-* hook",
                term.code()
            );
            for hook in hooks {
                assert!(
                    owners.iter().any(|owner| owner.hook == hook),
                    "{} names unowned falsifier hook {hook}",
                    term.code()
                );
            }
        }
    }

    #[test]
    fn term_falsifier_catalogs_cover_every_owned_f_hook() {
        let mut term_hooks = Vec::new();
        for term in WboTermCode::ALL {
            term_hooks.extend(f_hooks_in(term.falsifier()));
        }
        term_hooks.sort_unstable();
        term_hooks.dedup();

        for owner in falsifier_hook_owners() {
            assert!(
                term_hooks.contains(&owner.hook),
                "{} owner hook must be emitted by at least one WBO term falsifier",
                owner.hook
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
        let mut duplicated_semantic = reversed.clone();
        duplicated_semantic.push(
            LatticeErrorContribution::new(
                WboTermCode::WeightRuntime,
                "second runtime weight guard",
                0.25,
            )
            .expect("valid duplicate semantic contribution"),
        );
        let mut mixed_duplicates = duplicated_semantic.clone();
        mixed_duplicates.push(
            LatticeErrorContribution::new(
                WboTermCode::NumericalPostCorrection,
                "mixed duplicate numerical guard",
                0.75,
            )
            .expect("valid mixed duplicate numerical contribution"),
        );

        for contributions in [
            forward,
            reversed,
            duplicated_numerics,
            duplicated_semantic,
            mixed_duplicates,
        ] {
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
    fn lattice_budget_slice_partition_conserves_every_codec_catalog() {
        for coder in LatticeCoderKind::ALL {
            let contributions = coder
                .canonical_wbo_terms()
                .iter()
                .copied()
                .enumerate()
                .map(|(index, term)| {
                    LatticeErrorContribution::new(
                        term,
                        format!("{coder:?} {}", term.code()),
                        (index + 1) as f64 / 16.0,
                    )
                    .expect("valid contribution")
                })
                .collect::<Vec<_>>();
            let budget = LatticeBudget::new(
                coder,
                coder.allows_rate_parameter().then_some(1250),
                coder.canonical_side_information()[0],
                contributions,
            );

            assert_eq!(budget.validate(), Ok(()), "{coder:?}");
            assert_eq!(
                budget.semantic_wbo6_pre_softmax_budget()
                    + budget.numerical_post_correction_budget(),
                budget.pre_softmax_budget(),
                "{coder:?} failed reserved slice conservation"
            );
        }
    }

    #[test]
    fn budget_validation_accepts_canonical_side_information_by_codec() {
        let mut checked = 0;
        for coder in LatticeCoderKind::ALL {
            for side_information in coder.canonical_side_information() {
                let budget = side_information_probe_budget(coder, *side_information);
                assert_eq!(
                    budget.validate(),
                    Ok(()),
                    "{coder:?} rejected canonical side information {side_information:?}"
                );
                checked += 1;
            }
        }

        let expected = LatticeCoderKind::ALL
            .iter()
            .map(|coder| coder.canonical_side_information().len())
            .sum::<usize>();
        assert_eq!(checked, expected);
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
                    budget.validate_side_information(),
                    Err(LatticeWboError::InvalidSideInformation),
                    "{coder:?} direct side-information validator accepted {side_information:?}"
                );
                assert_eq!(
                    budget.validate(),
                    Err(LatticeWboError::InvalidSideInformation),
                    "{coder:?} accepted noncanonical side information {side_information:?}"
                );
                assert_eq!(
                    budget.validate_composition(),
                    Err(LatticeWboError::InvalidSideInformation),
                    "{coder:?} composition accepted noncanonical side information {side_information:?}"
                );
                checked += 1;
            }
        }

        let expected = LatticeCoderKind::ALL
            .iter()
            .map(|coder| SideInformationKind::ALL.len() - coder.canonical_side_information().len())
            .sum::<usize>();
        assert_eq!(checked, expected);
    }

    #[test]
    fn budget_validation_rejects_wrong_side_information_before_term_mismatch() {
        let mut checked = 0;

        for coder in LatticeCoderKind::ALL {
            let side_information = SideInformationKind::ALL
                .into_iter()
                .find(|side_information| {
                    !coder
                        .canonical_side_information()
                        .contains(side_information)
                })
                .expect("each codec must have at least one noncanonical side-information witness");
            let foreign_term = WboTermCode::ALL
                .into_iter()
                .find(|term| !coder.canonical_wbo_terms().contains(term))
                .expect("each codec must have at least one foreign WBO term");
            let contribution = LatticeErrorContribution::new(
                foreign_term,
                format!("{coder:?} foreign {}", foreign_term.code()),
                0.0,
            )
            .expect("valid foreign contribution shape");
            let budget = LatticeBudget::new(
                coder,
                coder.allows_rate_parameter().then_some(1250),
                side_information,
                vec![contribution],
            );

            assert_eq!(
                budget.validate_terms(),
                Err(LatticeWboError::InvalidWboTermForCodec),
                "{coder:?} fixture must carry a real term mismatch"
            );
            assert_eq!(
                budget.validate_side_information(),
                Err(LatticeWboError::InvalidSideInformation),
                "{coder:?} fixture must carry a real side-information mismatch"
            );
            assert_eq!(
                budget.validate(),
                Err(LatticeWboError::InvalidSideInformation),
                "{coder:?} full validation must reject side-information before term mismatch"
            );
            assert_eq!(
                budget.validate_composition(),
                Err(LatticeWboError::InvalidSideInformation),
                "{coder:?} composition validation must reject side-information before term mismatch"
            );
            checked += 1;
        }

        assert_eq!(checked, LatticeCoderKind::ALL.len());
    }

    #[test]
    fn budget_validation_rejects_every_wrong_side_information_before_term_mismatch() {
        let mut checked = 0;

        for coder in LatticeCoderKind::ALL {
            let foreign_term = WboTermCode::ALL
                .into_iter()
                .find(|term| !coder.canonical_wbo_terms().contains(term))
                .expect("each codec must have at least one foreign WBO term");
            let contribution = LatticeErrorContribution::new(
                foreign_term,
                format!("{coder:?} foreign {}", foreign_term.code()),
                0.0,
            )
            .expect("valid foreign contribution shape");

            for side_information in SideInformationKind::ALL {
                if coder
                    .canonical_side_information()
                    .contains(&side_information)
                {
                    continue;
                }

                let budget = LatticeBudget::new(
                    coder,
                    coder.allows_rate_parameter().then_some(1250),
                    side_information,
                    vec![contribution.clone()],
                );

                assert_eq!(
                    budget.validate_terms(),
                    Err(LatticeWboError::InvalidWboTermForCodec),
                    "{coder:?} fixture must carry a real term mismatch"
                );
                assert_eq!(
                    budget.validate_side_information(),
                    Err(LatticeWboError::InvalidSideInformation),
                    "{coder:?} fixture must carry side-information mismatch {side_information:?}"
                );
                assert_eq!(
                    budget.validate(),
                    Err(LatticeWboError::InvalidSideInformation),
                    "{coder:?} full validation let term mismatch hide {side_information:?}"
                );
                assert_eq!(
                    budget.validate_composition(),
                    Err(LatticeWboError::InvalidSideInformation),
                    "{coder:?} composition let term mismatch hide {side_information:?}"
                );
                checked += 1;
            }
        }

        let expected = LatticeCoderKind::ALL
            .iter()
            .map(|coder| SideInformationKind::ALL.len() - coder.canonical_side_information().len())
            .sum::<usize>();
        assert_eq!(checked, expected);
    }

    #[test]
    fn nested_lattice_codecs_reject_residual_and_kv_side_information() {
        let nested_codecs = [LatticeCoderKind::NestedE8, LatticeCoderKind::NestedLeech24];
        let borrowed_witnesses = [
            SideInformationKind::DecoderLmState,
            SideInformationKind::ResidualStream,
            SideInformationKind::RuntimeKvHessian,
            SideInformationKind::ActiveSupport,
            SideInformationKind::SsdOracle,
        ];
        let mut checked = 0;

        for coder in nested_codecs {
            assert_eq!(
                coder.canonical_side_information(),
                &[SideInformationKind::CalibrationHessian],
                "{coder:?} must stay a standalone weight-codec row"
            );

            for side_information in borrowed_witnesses {
                let budget = side_information_probe_budget(coder, side_information);
                assert_eq!(
                    budget.validate_side_information(),
                    Err(LatticeWboError::InvalidSideInformation),
                    "{coder:?} direct validator borrowed {side_information:?}"
                );
                assert_eq!(
                    budget.validate(),
                    Err(LatticeWboError::InvalidSideInformation),
                    "{coder:?} full validator borrowed {side_information:?}"
                );
                assert_eq!(
                    budget.validate_composition(),
                    Err(LatticeWboError::InvalidSideInformation),
                    "{coder:?} composition validator borrowed {side_information:?}"
                );
                checked += 1;
            }
        }

        assert_eq!(checked, nested_codecs.len() * borrowed_witnesses.len());
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
        let mut checked = 0;

        for tier in ResidencyTier::ALL
            .iter()
            .copied()
            .filter(|tier| tier.allows_active_support_budget())
        {
            let budget = LatticeBudget::new(
                tier.primary_coder(),
                tier.primary_rate_milli_bits_per_symbol(),
                tier.primary_side_information(),
                tier_probe_contributions(tier),
            );
            for side_information in SideInformationKind::ALL {
                if side_information == SideInformationKind::ActiveSupport {
                    continue;
                }
                let support = ActiveSupportBudget::new(128, 4, 1024, side_information);
                let entry = WboLedgerEntry::new_for_tier(
                    tier,
                    budget.clone(),
                    Some(support),
                    tier.primary_falsifier(),
                    "Active support budget must use ActiveSupport side information.",
                );

                assert_eq!(
                    entry.validate(),
                    Err(LatticeWboError::InvalidActiveSupportSideInformation),
                    "{} accepted active-support budget side information {side_information:?}",
                    tier.canonical_name()
                );
                checked += 1;
            }
        }

        let allowed_tiers = ResidencyTier::ALL
            .iter()
            .filter(|tier| tier.allows_active_support_budget())
            .count();
        assert_eq!(
            checked,
            allowed_tiers * (SideInformationKind::ALL.len() - 1)
        );
    }

    #[test]
    fn ledger_validation_allows_mixed_side_information_with_valid_active_support_budget() {
        let contributions = vec![
            LatticeErrorContribution::new(WboTermCode::KvCache, "SSD KV restore", 0.0)
                .expect("valid KV contribution"),
            LatticeErrorContribution::new(WboTermCode::Quantization, "NF4 page quant", 0.0)
                .expect("valid quantization contribution"),
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
            ResidencyTier::L3SsdOracle.primary_falsifier(),
            "SSD oracle rows may still carry active-support accounting.",
        );

        assert_eq!(entry.validate(), Ok(()));
    }

    #[test]
    fn ledger_validation_allows_max_active_support_budget_without_lattice_overflow() {
        let contributions = vec![
            LatticeErrorContribution::new(WboTermCode::KvCache, "SSD KV restore", 0.0)
                .expect("valid KV contribution")
                .with_measured(0.0)
                .expect("valid measured KV contribution"),
            LatticeErrorContribution::new(WboTermCode::Quantization, "NF4 page quant", 0.0)
                .expect("valid quantization contribution")
                .with_measured(0.0)
                .expect("valid measured quantization contribution"),
            LatticeErrorContribution::new(WboTermCode::SubstrateBoundary, "SSD boundary", 0.01)
                .expect("valid contribution")
                .with_measured(0.01)
                .expect("valid measured contribution"),
            LatticeErrorContribution::new(
                WboTermCode::NumericalPostCorrection,
                "softmax half correction",
                0.0,
            )
            .expect("valid numerical contribution")
            .with_measured(0.0)
            .expect("valid measured numerical contribution"),
        ];
        let budget = LatticeBudget::new(
            LatticeCoderKind::Nf4SsdOracle,
            Some(4000),
            SideInformationKind::SsdOracle,
            contributions,
        );
        let support = ActiveSupportBudget::new(
            u32::MAX,
            u32::MAX,
            u64::MAX,
            SideInformationKind::ActiveSupport,
        );
        let entry = WboLedgerEntry::new_for_tier(
            ResidencyTier::L3SsdOracle,
            budget,
            Some(support),
            ResidencyTier::L3SsdOracle.primary_falsifier(),
            "SSD oracle rows keep active-support accounting separate from lattice totals.",
        );

        assert_eq!(entry.validate(), Ok(()));
        assert_eq!(entry.budget.measured_pre_softmax_total(), Some(0.01));
        assert_eq!(entry.budget.measured_within_budget(), Some(true));
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

    fn assert_typed_row_rejects_rate(tier: ResidencyTier, rate: Option<u32>) {
        let budget = LatticeBudget::new(
            tier.primary_coder(),
            rate,
            tier.primary_side_information(),
            tier_probe_contributions(tier),
        );
        let entry = WboLedgerEntry::new_for_tier(
            tier,
            budget,
            None,
            tier.primary_coder().falsifier(),
            "Typed rows still reject invalid codec rates.",
        );

        assert_eq!(
            entry.validate(),
            Err(LatticeWboError::InvalidRate),
            "{} accepted rate {rate:?}",
            tier.canonical_name()
        );
    }

    #[test]
    fn ledger_validation_rejects_invalid_rate_on_typed_rate_rows() {
        let mut checked = 0;
        for tier in ResidencyTier::ALL
            .iter()
            .copied()
            .filter(|tier| tier.primary_rate_milli_bits_per_symbol().is_some())
        {
            assert_typed_row_rejects_rate(tier, None);
            checked += 1;
        }

        assert_eq!(checked, 2);
    }

    #[test]
    fn ledger_validation_rejects_zero_rate_on_typed_rate_rows() {
        let mut checked = 0;
        for tier in ResidencyTier::ALL
            .iter()
            .copied()
            .filter(|tier| tier.primary_rate_milli_bits_per_symbol().is_some())
        {
            assert_typed_row_rejects_rate(tier, Some(0));
            checked += 1;
        }

        assert_eq!(checked, 2);
    }

    #[test]
    fn ledger_validation_rejects_wrong_primary_rate_on_typed_rate_rows() {
        let mut checked = 0;
        for tier in ResidencyTier::ALL
            .iter()
            .copied()
            .filter(|tier| tier.primary_rate_milli_bits_per_symbol().is_some())
        {
            let wrong_rate = tier
                .primary_rate_milli_bits_per_symbol()
                .expect("rate-bearing tier")
                + 1;
            assert_typed_row_rejects_rate(tier, Some(wrong_rate));
            checked += 1;
        }

        assert_eq!(checked, 2);
    }

    #[test]
    fn ledger_validation_rejects_rate_on_typed_non_rate_rows() {
        let mut checked = 0;
        for tier in ResidencyTier::ALL
            .iter()
            .copied()
            .filter(|tier| tier.primary_rate_milli_bits_per_symbol().is_none())
        {
            assert_typed_row_rejects_rate(tier, Some(1250));
            checked += 1;
        }

        assert_eq!(checked, ResidencyTier::ALL.len() - 2);
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
    fn ledger_validation_rejects_zero_active_support_budget_with_wrong_side_information() {
        let mut checked = 0;

        for tier in ResidencyTier::ALL
            .iter()
            .copied()
            .filter(|tier| tier.allows_active_support_budget())
        {
            let budget = LatticeBudget::new(
                tier.primary_coder(),
                tier.primary_rate_milli_bits_per_symbol(),
                tier.primary_side_information(),
                tier_probe_contributions(tier),
            );
            for side_information in SideInformationKind::ALL {
                if side_information == SideInformationKind::ActiveSupport {
                    continue;
                }

                let entry = WboLedgerEntry::new_for_tier(
                    tier,
                    budget.clone(),
                    Some(ActiveSupportBudget::zero(side_information)),
                    tier.primary_falsifier(),
                    "Zero active-support budgets with wrong witnesses stay invalid.",
                );

                assert_eq!(
                    entry.validate(),
                    Err(LatticeWboError::InvalidActiveSupportSideInformation),
                    "{} accepted all-zero active support with {side_information:?}",
                    tier.canonical_name()
                );
                checked += 1;
            }
        }

        let allowed_tiers = ResidencyTier::ALL
            .iter()
            .filter(|tier| tier.allows_active_support_budget())
            .count();
        let non_active_side_information = SideInformationKind::ALL
            .iter()
            .filter(|kind| **kind != SideInformationKind::ActiveSupport)
            .count();
        assert_eq!(checked, allowed_tiers * non_active_side_information);
    }

    #[test]
    fn ledger_validation_rejects_partial_zero_active_support_axes() {
        let active_support_cases = [
            ActiveSupportBudget::new(0, 8, 4 * 1024 * 1024, SideInformationKind::ActiveSupport),
            ActiveSupportBudget::new(256, 0, 4 * 1024 * 1024, SideInformationKind::ActiveSupport),
            ActiveSupportBudget::new(256, 8, 0, SideInformationKind::ActiveSupport),
        ];
        let mut checked = 0;
        for tier in ResidencyTier::ALL
            .iter()
            .copied()
            .filter(|tier| tier.allows_active_support_budget())
        {
            let budget = LatticeBudget::new(
                tier.primary_coder(),
                tier.primary_rate_milli_bits_per_symbol(),
                tier.primary_side_information(),
                tier_probe_contributions(tier),
            );
            for active_support in active_support_cases {
                let entry = WboLedgerEntry::new_for_tier(
                    tier,
                    budget.clone(),
                    Some(active_support),
                    tier.primary_falsifier(),
                    "Every active-support axis must be nonzero.",
                );

                assert_eq!(
                    entry.validate(),
                    Err(LatticeWboError::InvalidActiveSupportSideInformation),
                    "{} accepted partial-zero active support {:?}",
                    tier.canonical_name(),
                    active_support
                );
                checked += 1;
            }
        }
        let allowed_tiers = ResidencyTier::ALL
            .iter()
            .filter(|tier| tier.allows_active_support_budget())
            .count();
        assert_eq!(checked, allowed_tiers * active_support_cases.len());
    }

    #[test]
    fn ledger_validation_rejects_combined_malformed_active_support_budget() {
        let partial_axes: [(u32, u32, u64); 3] = [
            (0, 8, 4 * 1024 * 1024),
            (256, 0, 4 * 1024 * 1024),
            (256, 8, 0),
        ];
        let mut checked = 0;
        for tier in ResidencyTier::ALL
            .iter()
            .copied()
            .filter(|tier| tier.allows_active_support_budget())
        {
            let budget = LatticeBudget::new(
                tier.primary_coder(),
                tier.primary_rate_milli_bits_per_symbol(),
                tier.primary_side_information(),
                tier_probe_contributions(tier),
            );
            for (tokens, pages, bytes) in partial_axes {
                for side_information in SideInformationKind::ALL
                    .iter()
                    .copied()
                    .filter(|kind| *kind != SideInformationKind::ActiveSupport)
                {
                    let entry = WboLedgerEntry::new_for_tier(
                        tier,
                        budget.clone(),
                        Some(ActiveSupportBudget::new(
                            tokens,
                            pages,
                            bytes,
                            side_information,
                        )),
                        tier.primary_falsifier(),
                        "Malformed active-support budgets stay invalid even when defects combine.",
                    );

                    assert_eq!(
                        entry.validate(),
                        Err(LatticeWboError::InvalidActiveSupportSideInformation),
                        "{} accepted active-support axes ({tokens}, {pages}, {bytes}) with {side_information:?}",
                        tier.canonical_name()
                    );
                    checked += 1;
                }
            }
        }
        let allowed_tiers = ResidencyTier::ALL
            .iter()
            .filter(|tier| tier.allows_active_support_budget())
            .count();
        let non_active_side_information = SideInformationKind::ALL
            .iter()
            .filter(|kind| **kind != SideInformationKind::ActiveSupport)
            .count();
        assert_eq!(
            checked,
            allowed_tiers * partial_axes.len() * non_active_side_information
        );
    }

    #[test]
    fn ledger_validation_rejects_active_support_budget_on_disallowed_tiers() {
        let mut checked = 0;
        let active_support_cases = [
            ActiveSupportBudget::new(1, 1, 1, SideInformationKind::ActiveSupport),
            ActiveSupportBudget::new(
                u32::MAX,
                u32::MAX,
                u64::MAX,
                SideInformationKind::ActiveSupport,
            ),
        ];
        for support in active_support_cases {
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
                    Some(support),
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
        }
        let expected = ResidencyTier::ALL
            .iter()
            .filter(|tier| !tier.allows_active_support_budget())
            .count();
        assert_eq!(checked, expected * active_support_cases.len());
    }

    #[test]
    fn residency_tier_round_trips_from_canonical_name() {
        for tier in ResidencyTier::ALL {
            assert_eq!(
                ResidencyTier::from_canonical_name(tier.canonical_name()),
                Some(tier)
            );
        }
        for alias in [
            "L6 Unknown",
            " L0 RAM hot",
            "L0 RAM hot ",
            "l0 RAM hot",
            "LSE Self-Evolving",
            "L_SE self-evolving",
            "L4 Network Cascade",
        ] {
            assert_eq!(ResidencyTier::from_canonical_name(alias), None);
        }
    }

    #[test]
    fn residency_tier_canonical_names_are_trimmed_and_display_safe() {
        for tier in ResidencyTier::ALL {
            let name = tier.canonical_name();
            assert!(!name.is_empty(), "{tier:?}");
            assert_eq!(name.trim(), name, "{tier:?}");
            assert!(name.is_ascii(), "{tier:?}");
            assert!(!name.contains("  "), "{tier:?}");
            assert_ne!(name, format!("{tier:?}"), "{tier:?}");
            assert_eq!(ResidencyTier::from_canonical_name(name), Some(tier));
        }
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
    fn ledger_validation_rejects_residency_debug_labels() {
        let contribution =
            LatticeErrorContribution::new(WboTermCode::NumericalPostCorrection, "numerics", 0.0)
                .expect("valid contribution");
        let budget = LatticeBudget::new(
            LatticeCoderKind::ExactHot,
            None,
            SideInformationKind::None,
            vec![contribution],
        );

        for tier in ResidencyTier::ALL {
            let debug_label = format!("{tier:?}");
            let entry = WboLedgerEntry::new(
                debug_label.as_str(),
                budget.clone(),
                None,
                "F-WBO-DriftLedger; F-ULP-Oracle",
                "Only canonical T17B tier names are valid.",
            );

            assert_ne!(debug_label, tier.canonical_name());
            assert_eq!(ResidencyTier::from_canonical_name(&debug_label), None);
            assert_eq!(
                entry.validate(),
                Err(LatticeWboError::UnknownResidencyTier),
                "{debug_label}"
            );
        }
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
        let numerics_a =
            LatticeErrorContribution::new(WboTermCode::NumericalPostCorrection, "numerics a", 0.0)
                .expect("valid numerical contribution");
        let numerics_b =
            LatticeErrorContribution::new(WboTermCode::NumericalPostCorrection, "numerics b", 0.0)
                .expect("valid numerical contribution");
        let budget = LatticeBudget::new(
            LatticeCoderKind::LatticeWynerZivResidual,
            Some(1250),
            SideInformationKind::ResidualStream,
            vec![residual_a, quantization, numerics_a, residual_b, numerics_b],
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
    fn ledger_entry_wbo_terms_deduplicates_every_codec_catalog() {
        for coder in LatticeCoderKind::ALL {
            let mut contributions = coder
                .canonical_wbo_terms()
                .iter()
                .copied()
                .enumerate()
                .map(|(index, term)| {
                    LatticeErrorContribution::new(
                        term,
                        format!("{coder:?} first {}", term.code()),
                        (index + 1) as f64 / 32.0,
                    )
                    .expect("valid contribution")
                })
                .collect::<Vec<_>>();
            contributions.extend(
                coder
                    .canonical_wbo_terms()
                    .iter()
                    .rev()
                    .copied()
                    .enumerate()
                    .map(|(index, term)| {
                        LatticeErrorContribution::new(
                            term,
                            format!("{coder:?} duplicate {}", term.code()),
                            (index + 1) as f64 / 64.0,
                        )
                        .expect("valid duplicate contribution")
                    }),
            );
            let entry = WboLedgerEntry::new(
                "catalog probe",
                LatticeBudget::new(
                    coder,
                    coder.allows_rate_parameter().then_some(1250),
                    coder.canonical_side_information()[0],
                    contributions,
                ),
                None,
                "F-WBO-DriftLedger",
                "Summary probe only.",
            );

            assert_eq!(
                entry.wbo_terms(),
                coder.canonical_wbo_terms(),
                "{coder:?} leaked duplicate terms or changed first-seen order"
            );
        }
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

                let borrowed_tier_budget = LatticeBudget::new(
                    coder,
                    coder.allows_rate_parameter().then_some(1250),
                    tier.primary_side_information(),
                    tier_probe_contributions(tier),
                );
                let borrowed_tier_entry = WboLedgerEntry::new_for_tier(
                    tier,
                    borrowed_tier_budget,
                    None,
                    tier.primary_falsifier(),
                    "Residency rows cannot borrow a tier-owned witness for a nonprimary codec.",
                );

                assert_eq!(
                    borrowed_tier_entry.validate(),
                    Err(LatticeWboError::ResidencyCodecMismatch),
                    "{} accepted nonprimary codec {:?} with tier-owned witnesses",
                    tier.canonical_name(),
                    coder
                );
                checked += 1;
            }
        }

        assert_eq!(
            checked,
            2 * ResidencyTier::ALL.len() * (LatticeCoderKind::ALL.len() - 1)
        );
    }

    #[test]
    fn ledger_validation_rejects_nonprimary_codec_before_foreign_terms() {
        let mut checked = 0;

        for tier in ResidencyTier::ALL {
            let coder = LatticeCoderKind::ALL
                .into_iter()
                .find(|coder| *coder != tier.primary_coder())
                .expect("each tier must have a nonprimary codec fixture");
            let foreign_term = WboTermCode::ALL
                .into_iter()
                .find(|term| !tier.canonical_register_terms().contains(term))
                .expect("each tier must have at least one foreign register term");
            let contribution = LatticeErrorContribution::new(
                foreign_term,
                format!("{} foreign {}", tier.canonical_name(), foreign_term.code()),
                0.01,
            )
            .expect("valid foreign residency contribution");
            let budget = LatticeBudget::new(
                coder,
                coder.allows_rate_parameter().then_some(1250),
                coder.canonical_side_information()[0],
                vec![contribution],
            );
            let entry = WboLedgerEntry::new_for_tier(
                tier,
                budget,
                None,
                coder.falsifier(),
                "Residency codec mismatch must win before term borrowing.",
            );

            assert!(
                entry.budget.contributions.iter().any(|contribution| !tier
                    .canonical_register_terms()
                    .contains(&contribution.term)),
                "{} fixture must carry a real residency-term mismatch",
                tier.canonical_name()
            );
            assert_eq!(
                entry.validate(),
                Err(LatticeWboError::ResidencyCodecMismatch),
                "{} must reject nonprimary codec before foreign register terms",
                tier.canonical_name()
            );
            checked += 1;
        }

        assert_eq!(checked, ResidencyTier::ALL.len());
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
        let mut primary_codec_owned_but_tier_foreign = 0;
        for tier in ResidencyTier::ALL {
            for term in WboTermCode::ALL {
                if tier.canonical_register_terms().contains(&term) {
                    continue;
                }
                if tier.primary_coder().canonical_wbo_terms().contains(&term) {
                    primary_codec_owned_but_tier_foreign += 1;
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

        let expected = ResidencyTier::ALL
            .iter()
            .map(|tier| {
                WboTermCode::ALL
                    .iter()
                    .filter(|term| !tier.canonical_register_terms().contains(term))
                    .count()
            })
            .sum::<usize>();
        assert_eq!(checked, expected);
        assert!(
            primary_codec_owned_but_tier_foreign > 0,
            "term fixture must include terms owned by a primary codec but foreign to its residency tier"
        );
    }

    #[test]
    fn ledger_validation_rejects_missing_non_numerical_residency_terms() {
        let mut checked = 0;

        for tier in ResidencyTier::ALL {
            for omitted_term in tier.canonical_register_terms() {
                if *omitted_term == WboTermCode::NumericalPostCorrection
                    || (tier.allows_active_support_budget()
                        && *omitted_term == WboTermCode::SubstrateBoundary)
                {
                    continue;
                }

                let contributions = tier
                    .canonical_register_terms()
                    .iter()
                    .filter(|term| *term != omitted_term)
                    .map(|term| {
                        LatticeErrorContribution::new(
                            *term,
                            format!("{} sparse row kept {}", tier.canonical_name(), term.code()),
                            0.01,
                        )
                        .expect("sparse residency contribution should be valid")
                    })
                    .collect::<Vec<_>>();
                let budget = LatticeBudget::new(
                    tier.primary_coder(),
                    tier.primary_rate_milli_bits_per_symbol(),
                    tier.primary_side_information(),
                    contributions,
                );
                let active_support = tier.requires_active_support_budget().then(|| {
                    ActiveSupportBudget::new(
                        2048,
                        32,
                        64 * 1024 * 1024,
                        SideInformationKind::ActiveSupport,
                    )
                });
                let entry = WboLedgerEntry::new_for_tier(
                    tier,
                    budget,
                    active_support,
                    tier.primary_falsifier(),
                    "Residency rows must not omit tier-owned WBO axes.",
                );

                assert_eq!(
                    entry.validate(),
                    Err(LatticeWboError::InvalidWboTermForResidencyTier),
                    "{} accepted sparse residency row missing {}",
                    tier.canonical_name(),
                    omitted_term.code()
                );
                checked += 1;
            }
        }

        assert_eq!(checked, 10);
    }

    #[test]
    fn ledger_validation_rejects_foreign_terms_before_nonprimary_side_information() {
        let mut checked = 0;

        for tier in ResidencyTier::ALL {
            let foreign_term = WboTermCode::ALL
                .into_iter()
                .find(|term| !tier.canonical_register_terms().contains(term))
                .expect("each tier must have at least one foreign register term");
            let side_information = SideInformationKind::ALL
                .into_iter()
                .find(|side_information| *side_information != tier.primary_side_information())
                .expect("each tier must have a nonprimary side-information fixture");
            let mut contributions = tier_probe_contributions(tier);
            contributions.push(
                LatticeErrorContribution::new(
                    foreign_term,
                    format!("{} foreign {}", tier.canonical_name(), foreign_term.code()),
                    0.01,
                )
                .expect("valid foreign residency contribution"),
            );
            let budget = LatticeBudget::new(
                tier.primary_coder(),
                tier.primary_coder().allows_rate_parameter().then_some(1250),
                side_information,
                contributions,
            );
            let entry = WboLedgerEntry::new_for_tier(
                tier,
                budget,
                None,
                tier.primary_falsifier(),
                "Residency term mismatch must win before side-information borrowing.",
            );

            assert_ne!(
                entry.budget.side_information,
                tier.primary_side_information(),
                "{} fixture must carry a real side-information mismatch",
                tier.canonical_name()
            );
            assert!(
                entry.budget.contributions.iter().any(|contribution| !tier
                    .canonical_register_terms()
                    .contains(&contribution.term)),
                "{} fixture must carry a real residency-term mismatch",
                tier.canonical_name()
            );
            assert_eq!(
                entry.validate(),
                Err(LatticeWboError::InvalidWboTermForResidencyTier),
                "{} must reject foreign register terms before nonprimary side information",
                tier.canonical_name()
            );
            checked += 1;
        }

        assert_eq!(checked, ResidencyTier::ALL.len());
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
        let mut primary_codec_accepted_but_tier_nonprimary = 0;
        for tier in ResidencyTier::ALL {
            for side_information in SideInformationKind::ALL {
                if side_information == tier.primary_side_information() {
                    continue;
                }
                if tier
                    .primary_coder()
                    .canonical_side_information()
                    .contains(&side_information)
                {
                    primary_codec_accepted_but_tier_nonprimary += 1;
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
        assert!(
            primary_codec_accepted_but_tier_nonprimary > 0,
            "side-information fixture must include witnesses accepted by a primary codec but nonprimary for its residency tier"
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
        let empty_source_contribution = LatticeErrorContribution {
            term: WboTermCode::NumericalPostCorrection,
            source: " ".to_string(),
            budget: 0.0,
            measured: Some(0.0),
        };

        for contribution in [
            signed_contribution,
            nonfinite_contribution,
            empty_source_contribution,
        ] {
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
            incomplete_budget.measured_semantic_wbo6_pre_softmax_total(),
            None
        );
        assert_eq!(
            incomplete_budget.measured_numerical_post_correction_total(),
            None
        );
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
    fn lattice_budget_measured_total_sums_duplicate_semantic_and_numerical_axes() {
        let residual_a =
            LatticeErrorContribution::new(WboTermCode::ResidualWynerZiv, "residual a", 0.25)
                .expect("valid residual contribution")
                .with_measured(0.125)
                .expect("valid residual measurement");
        let residual_b =
            LatticeErrorContribution::new(WboTermCode::ResidualWynerZiv, "residual b", 0.125)
                .expect("valid residual contribution")
                .with_measured(0.0625)
                .expect("valid residual measurement");
        let numerics_a = LatticeErrorContribution::new(
            WboTermCode::NumericalPostCorrection,
            "numerics a",
            0.0625,
        )
        .expect("valid numerical contribution")
        .with_measured(0.03125)
        .expect("valid numerical measurement");
        let numerics_b = LatticeErrorContribution::new(
            WboTermCode::NumericalPostCorrection,
            "numerics b",
            0.03125,
        )
        .expect("valid numerical contribution")
        .with_measured(0.015625)
        .expect("valid numerical measurement");
        let budget = LatticeBudget::new(
            LatticeCoderKind::LatticeWynerZivResidual,
            Some(1250),
            SideInformationKind::ResidualStream,
            vec![residual_a, numerics_a, residual_b, numerics_b],
        );

        assert_eq!(
            budget.measured_semantic_wbo6_pre_softmax_total(),
            Some(0.1875)
        );
        assert_eq!(
            budget.measured_numerical_post_correction_total(),
            Some(0.046875)
        );
        assert_eq!(budget.measured_pre_softmax_total(), Some(0.234375));
        assert_eq!(
            budget.measured_softmax_half_corrected_total(),
            Some(0.1171875)
        );
        assert_eq!(budget.measured_within_budget(), Some(true));
    }

    #[test]
    fn lattice_budget_measured_slices_partition_complete_total() {
        let residual =
            LatticeErrorContribution::new(WboTermCode::ResidualWynerZiv, "residual", 0.25)
                .expect("valid residual contribution")
                .with_measured(0.125)
                .expect("valid residual measurement");
        let quantization =
            LatticeErrorContribution::new(WboTermCode::Quantization, "quantization", 0.5)
                .expect("valid quantization contribution")
                .with_measured(0.25)
                .expect("valid quantization measurement");
        let numerics_a = LatticeErrorContribution::new(
            WboTermCode::NumericalPostCorrection,
            "numerics a",
            0.0625,
        )
        .expect("valid numerical contribution")
        .with_measured(0.03125)
        .expect("valid numerical measurement");
        let numerics_b = LatticeErrorContribution::new(
            WboTermCode::NumericalPostCorrection,
            "numerics b",
            0.03125,
        )
        .expect("valid numerical contribution")
        .with_measured(0.015625)
        .expect("valid numerical measurement");
        let budget = LatticeBudget::new(
            LatticeCoderKind::LatticeWynerZivResidual,
            Some(1250),
            SideInformationKind::ResidualStream,
            vec![residual.clone(), numerics_a, quantization, numerics_b],
        );

        let semantic = budget.measured_semantic_wbo6_pre_softmax_total();
        let numerical = budget.measured_numerical_post_correction_total();
        assert_eq!(semantic, Some(0.375));
        assert_eq!(numerical, Some(0.046875));
        assert_eq!(budget.measured_pre_softmax_total(), Some(0.421875));
        assert_eq!(
            semantic.zip(numerical).map(|(lhs, rhs)| lhs + rhs),
            Some(0.421875)
        );

        let incomplete_budget = LatticeBudget::new(
            LatticeCoderKind::LatticeWynerZivResidual,
            Some(1250),
            SideInformationKind::ResidualStream,
            vec![
                residual,
                LatticeErrorContribution::new(
                    WboTermCode::NumericalPostCorrection,
                    "unmeasured numerics",
                    0.03125,
                )
                .expect("valid numerical contribution"),
            ],
        );

        assert_eq!(
            incomplete_budget.measured_semantic_wbo6_pre_softmax_total(),
            None
        );
        assert_eq!(
            incomplete_budget.measured_numerical_post_correction_total(),
            None
        );
    }

    #[test]
    fn lattice_budget_measured_slices_require_complete_cross_axis_measurements() {
        let measured_residual =
            LatticeErrorContribution::new(WboTermCode::ResidualWynerZiv, "residual", 0.25)
                .expect("valid residual contribution")
                .with_measured(0.125)
                .expect("valid residual measurement");
        let unmeasured_residual =
            LatticeErrorContribution::new(WboTermCode::ResidualWynerZiv, "residual", 0.25)
                .expect("valid residual contribution");
        let measured_numerics = LatticeErrorContribution::new(
            WboTermCode::NumericalPostCorrection,
            "numerics",
            0.03125,
        )
        .expect("valid numerical contribution")
        .with_measured(0.015625)
        .expect("valid numerical measurement");
        let unmeasured_numerics = LatticeErrorContribution::new(
            WboTermCode::NumericalPostCorrection,
            "numerics",
            0.03125,
        )
        .expect("valid numerical contribution");

        for budget in [
            LatticeBudget::new(
                LatticeCoderKind::LatticeWynerZivResidual,
                Some(1250),
                SideInformationKind::ResidualStream,
                vec![unmeasured_residual, measured_numerics],
            ),
            LatticeBudget::new(
                LatticeCoderKind::LatticeWynerZivResidual,
                Some(1250),
                SideInformationKind::ResidualStream,
                vec![measured_residual, unmeasured_numerics],
            ),
        ] {
            assert_eq!(budget.validate(), Ok(()));
            assert_budget_measurements_pending(&budget);
        }
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
        let budget = LatticeBudget::new(
            LatticeCoderKind::ShadowKvSketch,
            None,
            SideInformationKind::ActiveSupport,
            tier_probe_contributions(ResidencyTier::L2ShadowSketch),
        );
        for support in [
            ActiveSupportBudget::new(
                2048,
                32,
                64 * 1024 * 1024,
                SideInformationKind::ActiveSupport,
            ),
            ActiveSupportBudget::new(
                u32::MAX,
                u32::MAX,
                u64::MAX,
                SideInformationKind::ActiveSupport,
            ),
        ] {
            let entry = WboLedgerEntry::new_for_tier(
                ResidencyTier::L2ShadowSketch,
                budget.clone(),
                Some(support),
                "F-WBO-DriftLedger; F-ULP-Oracle; F-KV-Direct-Gate; F-ACS-AnchorLookup",
                "Active support is accounting metadata, not a speed claim.",
            );

            assert_eq!(entry.validate(), Ok(()));
        }
    }

    #[test]
    fn budget_validation_rejects_zero_explicit_rate() {
        let mut checked = 0;
        for coder in LatticeCoderKind::ALL
            .iter()
            .copied()
            .filter(|coder| coder.allows_rate_parameter())
        {
            checked += 1;
            let contribution = LatticeErrorContribution::new(
                WboTermCode::NumericalPostCorrection,
                "numerics",
                0.0,
            )
            .expect("valid contribution");
            let budget = LatticeBudget::new(
                coder,
                Some(0),
                coder.canonical_side_information()[0],
                vec![contribution],
            );

            assert_eq!(budget.validate(), Err(LatticeWboError::InvalidRate));
            assert_eq!(
                budget.validate_composition(),
                Err(LatticeWboError::InvalidRate)
            );
        }
        let expected = LatticeCoderKind::ALL
            .iter()
            .filter(|coder| coder.allows_rate_parameter())
            .count();
        assert_eq!(checked, expected);
    }

    #[test]
    fn budget_validation_rejects_missing_rate_on_rate_codecs() {
        let mut checked = 0;
        for coder in LatticeCoderKind::ALL
            .iter()
            .copied()
            .filter(|coder| coder.allows_rate_parameter())
        {
            checked += 1;
            let budget = LatticeBudget::new(
                coder,
                None,
                coder.canonical_side_information()[0],
                vec![LatticeErrorContribution::new(
                    WboTermCode::NumericalPostCorrection,
                    "softmax half correction",
                    0.0,
                )
                .expect("valid numerical contribution")],
            );

            assert_eq!(budget.validate(), Err(LatticeWboError::InvalidRate));
            assert_eq!(
                budget.validate_composition(),
                Err(LatticeWboError::InvalidRate)
            );
        }
        let expected = LatticeCoderKind::ALL
            .iter()
            .filter(|coder| coder.allows_rate_parameter())
            .count();
        assert_eq!(checked, expected);
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
            assert_eq!(budget.validate(), Err(LatticeWboError::InvalidRate));
            assert_eq!(
                budget.validate_composition(),
                Err(LatticeWboError::InvalidRate)
            );
        }
        let expected = LatticeCoderKind::ALL
            .iter()
            .filter(|coder| !coder.allows_rate_parameter())
            .count();
        assert_eq!(checked, expected);
    }

    #[test]
    fn budget_validation_accepts_nonzero_rate_on_rate_codecs() {
        let mut checked = 0;
        for coder in LatticeCoderKind::ALL
            .iter()
            .copied()
            .filter(|coder| coder.allows_rate_parameter())
        {
            checked += 1;
            let canonical =
                side_information_probe_budget(coder, coder.canonical_side_information()[0]);
            assert_eq!(canonical.validate(), Ok(()), "{coder:?}");

            let max_rate = LatticeBudget::new(
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

            assert_eq!(max_rate.validate_rate(), Ok(()), "{coder:?}");
        }
        let expected = LatticeCoderKind::ALL
            .iter()
            .filter(|coder| coder.allows_rate_parameter())
            .count();
        assert_eq!(checked, expected);
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
        let missing_tier = WboLedgerEntry::new(
            "   ",
            budget.clone(),
            None,
            "F-WBO-DriftLedger; F-ULP-Oracle",
            "Exact path still pays numerics.",
        );
        assert_eq!(
            missing_tier.validate(),
            Err(LatticeWboError::EmptyMemoryTier)
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
        let security_contribution = LatticeErrorContribution::new(
            WboTermCode::SelfEvolvingSecurity,
            "provider replay boundary",
            0.0,
        )
        .expect("valid security contribution");
        let numerics =
            LatticeErrorContribution::new(WboTermCode::NumericalPostCorrection, "numerics", 0.0)
                .expect("valid numerical contribution");
        let budget = LatticeBudget::new(
            LatticeCoderKind::NetworkCascade,
            None,
            SideInformationKind::NetworkTeacher,
            vec![boundary_contribution, security_contribution, numerics],
        );
        let lower_case_provider_hook = WboLedgerEntry::new_for_tier(
            ResidencyTier::L5NetworkCascade,
            budget,
            None,
            "provider/provenance replay; F-ULP-Oracle; F-WBO-DriftLedger; F-ACS-AnchorLookup",
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
            network_budget.clone(),
            None,
            "F-WBO-DriftLedger; F-ULP-Oracle; F-ACS-AnchorLookup",
            "Network security rows must replay provider provenance.",
        );
        let network_with_adapter_replay = WboLedgerEntry::new_for_tier(
            ResidencyTier::L5NetworkCascade,
            network_budget.clone(),
            None,
            "F-WBO-DriftLedger; F-ULP-Oracle; F-ACS-AnchorLookup; adapter replay/provenance verifier",
            "Network security rows cannot borrow adapter replay provenance.",
        );
        let network_with_capitalized_replay = WboLedgerEntry::new_for_tier(
            ResidencyTier::L5NetworkCascade,
            network_budget,
            None,
            "F-WBO-DriftLedger; F-ULP-Oracle; F-ACS-AnchorLookup; Provider/provenance replay",
            "Network security verifier spelling must match the canonical clause.",
        );

        assert_eq!(
            network_without_replay.validate(),
            Err(LatticeWboError::MissingCanonicalFalsifier)
        );
        assert_eq!(
            network_with_adapter_replay.validate(),
            Err(LatticeWboError::MissingCanonicalFalsifier)
        );
        assert_eq!(
            network_with_capitalized_replay.validate(),
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
            adapter_budget.clone(),
            None,
            "F-WBO-DriftLedger; F-ULP-Oracle; layerwise reconstruction/logit drift witness",
            "Adapter security rows must replay adapter provenance.",
        );
        let adapter_with_provider_replay = WboLedgerEntry::new_for_tier(
            ResidencyTier::LSeSelfEvolving,
            adapter_budget.clone(),
            None,
            "F-WBO-DriftLedger; F-ULP-Oracle; provider/provenance replay; layerwise reconstruction/logit drift witness",
            "Adapter security rows cannot borrow provider replay provenance.",
        );
        let adapter_with_capitalized_replay = WboLedgerEntry::new_for_tier(
            ResidencyTier::LSeSelfEvolving,
            adapter_budget,
            None,
            "F-WBO-DriftLedger; F-ULP-Oracle; Adapter replay/provenance verifier; layerwise reconstruction/logit drift witness",
            "Adapter security verifier spelling must match the canonical clause.",
        );

        assert_eq!(
            adapter_without_replay.validate(),
            Err(LatticeWboError::MissingCanonicalFalsifier)
        );
        assert_eq!(
            adapter_with_provider_replay.validate(),
            Err(LatticeWboError::MissingCanonicalFalsifier)
        );
        assert_eq!(
            adapter_with_capitalized_replay.validate(),
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
    fn ledger_validation_rejects_unowned_falsifier_hooks() {
        for falsifier in [
            "F-WBO-DriftLedger; F-ULP-Oracle; F-Imaginary-Probe",
            "F-WBO-DriftLedger; F-ULP-Oracle; f-imaginary-probe",
            "F-WBO-DriftLedger; F-ULP-Oracle; F-Imaginary-Probe/v2",
            "F-WBO-DriftLedger; F-ULP-Oracle/v2",
            "F-WBO-DriftLedger/v2; F-ULP-Oracle",
            "F-WBO-DriftLedger; F-ULP-Oracleβ",
            "βF-WBO-DriftLedger; F-ULP-Oracle",
            "f-wbo-driftledger; f-ulp-oracle",
        ] {
            let contribution = LatticeErrorContribution::new(
                WboTermCode::NumericalPostCorrection,
                "numerics",
                0.0,
            )
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
                falsifier,
                "Extra falsifier hooks must still have owners.",
            );

            assert_eq!(
                entry.validate(),
                Err(LatticeWboError::MissingCanonicalFalsifier)
            );
        }
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
