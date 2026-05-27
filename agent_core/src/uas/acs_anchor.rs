//! MAS-safe ACS (Anchored Cognitive Substrate) anchor reference.
//!
//! This is the product-code mirror of the research-only
//! `epistemos-research::acs::AcsAnchor`. It carries the lookup fields needed
//! by cognitive DAG nodes and falsifier harnesses without importing the
//! research crate into MAS builds.

use serde::{Deserialize, Serialize};

use crate::uas::{ResidencyTier, RuntimePlane};

const FOUNDATIONAL_SEVEN_IDS: [&str; 7] = ["E1", "E2", "E3", "E4", "E5", "E6", "E7"];

// UAS: uas/acs-anchor/<anchor_id>
// Plane: RuntimePlane::Episodic
// Residency: ResidencyTier::VerifiedFloor
/// Typed ACS (Anchored Cognitive Substrate) anchor for MAS-visible metadata.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct AcsAnchor {
    pub anchor_id: String,
    pub theorem_id: String,
    pub plane: RuntimePlane,
    pub residency: ResidencyTier,
    pub source_hash: Option<String>,
    pub active_packet_id: Option<String>,
    pub compatibility_edge: Option<String>,
    pub salience: f32,
}

impl Eq for AcsAnchor {}

impl AcsAnchor {
    pub fn new(
        anchor_id: impl Into<String>,
        theorem_id: impl Into<String>,
        plane: RuntimePlane,
        residency: ResidencyTier,
        salience: f32,
    ) -> Self {
        Self {
            anchor_id: anchor_id.into(),
            theorem_id: theorem_id.into(),
            plane,
            residency,
            source_hash: None,
            active_packet_id: None,
            compatibility_edge: None,
            salience,
        }
    }

    pub fn is_foundational_theorem_anchor(&self) -> bool {
        FOUNDATIONAL_SEVEN_IDS.contains(&self.theorem_id.as_str())
    }

    pub fn is_well_formed(&self) -> bool {
        !self.anchor_id.trim().is_empty()
            && self.is_foundational_theorem_anchor()
            && self.salience.is_finite()
            && (0.0..=1.0).contains(&self.salience)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn foundational_anchor_is_well_formed() {
        let anchor = AcsAnchor::new(
            "claim-1",
            "E1",
            RuntimePlane::Episodic,
            ResidencyTier::VerifiedFloor,
            0.7,
        );
        assert!(anchor.is_well_formed());
    }

    #[test]
    fn unknown_theorem_fails_closed() {
        let anchor = AcsAnchor::new(
            "claim-1",
            "X9",
            RuntimePlane::Episodic,
            ResidencyTier::VerifiedFloor,
            0.7,
        );
        assert!(!anchor.is_well_formed());
    }
}
