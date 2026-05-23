//! Validation failures for ledger-only lattice/WBO structures.

use serde::{de, Deserialize, Deserializer, Serialize, Serializer};

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
