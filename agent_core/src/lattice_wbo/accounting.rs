//! Lattice accounting: WBO term axes, per-term error contributions, the rate /
//! side-information / measurement bundle (`LatticeBudget`), and the
//! active-support carve-out (`ActiveSupportBudget`).

use serde::{de, Deserialize, Deserializer, Serialize, Serializer};

use super::error::LatticeWboError;
use super::register::{LatticeCoderKind, SideInformationKind};
use super::verifier::validate_nonnegative_finite;
use super::wire::{deserialize_explicit_public_option, ExplicitPublicOption};

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
            #[serde(default, deserialize_with = "deserialize_explicit_public_option")]
            measured: ExplicitPublicOption<f64>,
        }

        let raw = RawContribution::deserialize(deserializer)?;
        let measured = raw.measured.require("measured")?;
        validate_nonnegative_finite(raw.budget).map_err(|error| de::Error::custom(error.key()))?;
        if raw.source.trim().is_empty() {
            return Err(de::Error::custom(LatticeWboError::EmptySource.key()));
        }
        if let Some(measured) = measured {
            validate_nonnegative_finite(measured)
                .map_err(|error| de::Error::custom(error.key()))?;
        }

        Ok(Self {
            term: raw.term,
            source: raw.source,
            budget: raw.budget,
            measured,
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

    pub fn softmax_half_pre_correction_budget(&self) -> f64 {
        self.pre_softmax_budget()
    }

    pub fn softmax_half_post_correction_budget(&self) -> f64 {
        self.softmax_half_corrected_budget()
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

    pub fn measured_softmax_half_pre_correction_total(&self) -> Option<f64> {
        self.measured_pre_softmax_total()
    }

    pub fn measured_softmax_half_post_correction_total(&self) -> Option<f64> {
        self.measured_softmax_half_corrected_total()
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

    pub(super) fn validate_before_numerical_post_correction(&self) -> Result<(), LatticeWboError> {
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

    pub(super) fn validate_numerical_post_correction(&self) -> Result<(), LatticeWboError> {
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

    pub(super) fn validate_composition_totals(&self) -> Result<(), LatticeWboError> {
        let measured_pre_softmax_total = self.measured_pre_softmax_total_after_value_validation();
        let measured_semantic_total =
            self.measured_pre_softmax_sum_after_value_validation(WboTermCode::is_semantic_wbo6);
        let measured_numerical_total =
            self.measured_pre_softmax_sum_after_value_validation(|term| {
                term == WboTermCode::NumericalPostCorrection
            });
        let measured_half_corrected_total =
            self.measured_softmax_half_corrected_total_after_value_validation();

        if self.pre_softmax_budget().is_finite()
            && self.semantic_wbo6_pre_softmax_budget().is_finite()
            && self.numerical_post_correction_budget().is_finite()
            && self.softmax_half_corrected_budget().is_finite()
            && measured_pre_softmax_total.is_none_or(f64::is_finite)
            && measured_semantic_total.is_none_or(f64::is_finite)
            && measured_numerical_total.is_none_or(f64::is_finite)
            && measured_half_corrected_total.is_none_or(f64::is_finite)
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
            #[serde(default, deserialize_with = "deserialize_explicit_public_option")]
            rate_milli_bits_per_symbol: ExplicitPublicOption<u32>,
            side_information: SideInformationKind,
            contributions: Vec<LatticeErrorContribution>,
        }

        let raw = RawBudget::deserialize(deserializer)?;
        let rate_milli_bits_per_symbol = raw
            .rate_milli_bits_per_symbol
            .require("rate_milli_bits_per_symbol")?;
        let budget = Self::new(
            raw.coder,
            rate_milli_bits_per_symbol,
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
