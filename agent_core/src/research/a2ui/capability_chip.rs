//! Source:
//! - `docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_B_2026_05_16.md`
//!   §5 Phase B.5 — Wave I A2UI catalog component `CapabilityChip`.
//! - `MASTER_FUSION §6 Wave I` — canonical component list.
//! - Companion to [`super::WaveIComponentKind::CapabilityChip`].
//!
//! # Wave I — CapabilityChip component
//!
//! Typed props struct + `validate()` returning a structural error for
//! malformed envelopes. Substrate floor only; Swift A2UI dispatcher
//! owns the renderer.

use serde::{Deserialize, Serialize};

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize)]
pub enum CapabilityTier {
    Free,
    Pro,
    Research,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct CapabilityChipProps {
    pub capability_name: String,
    pub tier: CapabilityTier,
    pub enabled: bool,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum CapabilityChipError {
    EmptyCapabilityName,
}

impl CapabilityChipProps {
    pub fn validate(&self) -> Result<(), CapabilityChipError> {
        if self.capability_name.is_empty() {
            return Err(CapabilityChipError::EmptyCapabilityName);
        }
        Ok(())
    }
}

impl CapabilityTier {
    pub const ALL: [CapabilityTier; 3] = [
        CapabilityTier::Free,
        CapabilityTier::Pro,
        CapabilityTier::Research,
    ];

    pub const fn code(self) -> &'static str {
        match self {
            CapabilityTier::Free => "free",
            CapabilityTier::Pro => "pro",
            CapabilityTier::Research => "research",
        }
    }

    /// Reverse lookup for [`Self::code`]. `None` for unknown codes.
    pub fn from_code(code: &str) -> Option<Self> {
        Self::ALL.iter().copied().find(|t| t.code() == code)
    }

    /// Predicate: this tier requires Pro entitlement (Pro or Research).
    /// Cross-surface invariant: `requires_pro XOR is_free` partitions
    /// all 3 tiers.
    pub const fn requires_pro(self) -> bool {
        matches!(self, CapabilityTier::Pro | CapabilityTier::Research)
    }

    /// Predicate: this is the free / no-entitlement tier.
    pub const fn is_free(self) -> bool {
        matches!(self, CapabilityTier::Free)
    }
}

impl CapabilityChipError {
    pub const fn cause(&self) -> &'static str {
        match self {
            CapabilityChipError::EmptyCapabilityName => "empty_capability_name",
        }
    }
}

impl CapabilityChipProps {
    pub fn is_valid(&self) -> bool {
        self.validate().is_ok()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn three_distinct_tiers() {
        let s: std::collections::HashSet<_> =
            [CapabilityTier::Free, CapabilityTier::Pro, CapabilityTier::Research]
                .iter()
                .copied()
                .collect();
        assert_eq!(s.len(), 3);
    }

    #[test]
    fn tier_codes_stable() {
        assert_eq!(CapabilityTier::Free.code(), "free");
        assert_eq!(CapabilityTier::Pro.code(), "pro");
        assert_eq!(CapabilityTier::Research.code(), "research");
    }

    #[test]
    fn empty_name_rejected() {
        let c = CapabilityChipProps {
            capability_name: String::new(),
            tier: CapabilityTier::Free,
            enabled: true,
        };
        assert_eq!(c.validate().unwrap_err(), CapabilityChipError::EmptyCapabilityName);
    }

    #[test]
    fn non_empty_name_validates() {
        let c = CapabilityChipProps {
            capability_name: "scheduling".into(),
            tier: CapabilityTier::Pro,
            enabled: false,
        };
        assert!(c.validate().is_ok());
    }

    #[test]
    fn serde_json_roundtrip() {
        let c = CapabilityChipProps {
            capability_name: "cap".into(),
            tier: CapabilityTier::Research,
            enabled: true,
        };
        let json = serde_json::to_string(&c).unwrap();
        let back: CapabilityChipProps = serde_json::from_str(&json).unwrap();
        assert_eq!(c, back);
    }

    // ── diagnostic surface (iter 204) ────────────────────────────────────────

    #[test]
    fn tier_from_code_roundtrips_all() {
        for t in CapabilityTier::ALL.iter().copied() {
            assert_eq!(CapabilityTier::from_code(t.code()), Some(t));
        }
        assert_eq!(CapabilityTier::from_code("Free"), None);
    }

    #[test]
    fn tier_requires_pro_xor_is_free_partition() {
        // Cross-surface invariant.
        for t in CapabilityTier::ALL.iter().copied() {
            assert_ne!(t.requires_pro(), t.is_free());
        }
        assert!(CapabilityTier::Pro.requires_pro());
        assert!(CapabilityTier::Research.requires_pro());
        assert!(CapabilityTier::Free.is_free());
    }

    #[test]
    fn error_cause_stable() {
        assert_eq!(
            CapabilityChipError::EmptyCapabilityName.cause(),
            "empty_capability_name"
        );
    }

    #[test]
    fn is_valid_matches_validate_ok() {
        let good = CapabilityChipProps {
            capability_name: "x".into(),
            tier: CapabilityTier::Free,
            enabled: true,
        };
        assert_eq!(good.is_valid(), good.validate().is_ok());
        assert!(good.is_valid());
    }
}
