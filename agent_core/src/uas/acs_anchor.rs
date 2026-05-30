//! MAS-safe ACS (Active Cold Storage) anchor reference.
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
/// Typed ACS (Active Cold Storage) anchor for MAS-visible metadata.
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

/// Borrowed, allocation-free projection of an [`AcsAnchor`] onto the V6.1
/// five-plane formalism.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct AcsAnchorPlaneProjection<'a> {
    pub anchor_id: &'a str,
    pub theorem_id: &'a str,
    pub plane: RuntimePlane,
    pub residency: ResidencyTier,
    pub source_hash: Option<&'a str>,
    pub active_packet_id: Option<&'a str>,
}

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
        is_valid_anchor_id(&self.anchor_id)
            && self.is_foundational_theorem_anchor()
            && self.salience.is_finite()
            && (0.0..=1.0).contains(&self.salience)
    }

    pub fn project_to_plane(&self) -> AcsAnchorPlaneProjection<'_> {
        AcsAnchorPlaneProjection {
            anchor_id: &self.anchor_id,
            theorem_id: &self.theorem_id,
            plane: self.plane,
            residency: self.residency,
            source_hash: self.source_hash.as_deref(),
            active_packet_id: self.active_packet_id.as_deref(),
        }
    }
}

fn is_valid_anchor_id(value: &str) -> bool {
    !value.is_empty()
        && value.trim() == value
        && !value
            .chars()
            .any(|ch| ch.is_control() || ch.is_whitespace() || matches!(ch, '|' | '@'))
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

    #[test]
    fn malformed_anchor_ids_fail_closed_before_projection() {
        for anchor_id in [" claim-1", "claim-1 ", "claim\n1", "claim|1", "claim@1"] {
            let anchor = AcsAnchor::new(
                anchor_id,
                "E1",
                RuntimePlane::Episodic,
                ResidencyTier::VerifiedFloor,
                0.7,
            );
            assert!(
                !anchor.is_well_formed(),
                "malformed anchor_id {anchor_id:?} must not pass the UAS/ACS read guard"
            );
        }
    }

    #[test]
    fn plane_projection_preserves_inversion_fields_without_allocation() {
        let mut anchor = AcsAnchor::new(
            "claim-1",
            "E1",
            RuntimePlane::Verification,
            ResidencyTier::VerifiedFloor,
            0.7,
        );
        anchor.source_hash = Some("blake3:abc".to_string());
        anchor.active_packet_id = Some("packet-1".to_string());

        let projection = anchor.project_to_plane();

        assert_eq!(projection.anchor_id, "claim-1");
        assert_eq!(projection.theorem_id, "E1");
        assert_eq!(projection.plane, RuntimePlane::Verification);
        assert_eq!(projection.residency, ResidencyTier::VerifiedFloor);
        assert_eq!(projection.source_hash, Some("blake3:abc"));
        assert_eq!(projection.active_packet_id, Some("packet-1"));
    }
}
