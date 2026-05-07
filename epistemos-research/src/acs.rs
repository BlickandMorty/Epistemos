//! HELIOS V5 — Anchored Cognitive Substrate (ACS) + CMS-X v3.
//!
//! HELIOS-ACS guard
//!
//! Per `docs/HELIOS_V5_INTEGRATION_PLAN_v2_FINALIZE_2026_05_05.md` §M:
//!
//! > "Ternary Kernel Lane (Gate3 / BitNet / T-MAC) → Lane 1 Tier-2.
//! >  ACS / CMS-X v3 (constitutive field on top of Helios) →
//! >  Lane 3 (Research). ODSC² / OSFT-PSOFT-coSO → Lane 3 (research)
//! >  / L5 (vault)."
//!
//! Source: HELIOS v4 preservation package
//! `source_docs/CMS_v2_Final_Definitive.md`.
//!
//! ACS = "Anchored Cognitive Substrate" — the constitutive field
//! that ties the Foundational Seven (E1-E7) into a coherent
//! computational fabric. Lifted as research-tier substrate types;
//! NEVER ships in MAS.

use serde::{Deserialize, Serialize};

use crate::five_planes::RuntimePlane;
use crate::theorem_status::FOUNDATIONAL_SEVEN;

/// V6.1 plane placement for ACS anchors: ACS stores exact,
/// addressable cognitive coordinates, so it lives in the Episodic
/// plane. The theorem labels attached to anchors are audited by the
/// Verification plane, but ACS is not the State-plane semantic spine.
pub const ACS_CANONICAL_PLANE: RuntimePlane = RuntimePlane::Episodic;

/// The audit plane that checks ACS theorem labels and compatibility
/// claims.
pub const ACS_AUDIT_PLANE: RuntimePlane = RuntimePlane::Verification;

/// One anchor in the Anchored Cognitive Substrate. Each anchor is a
/// stable reference point in the constitutive field that downstream
/// CMS-X v3 paths can attach claims and computations to.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct AcsAnchor {
    pub anchor_id: String,
    /// E-id of the foundational theorem this anchor reifies (E1..E7).
    pub theorem_id: String,
    /// Salience score in [0, 1].
    pub salience: f32,
}

impl AcsAnchor {
    /// True when the anchor names one of the Foundational Seven
    /// theorem ids (E1..E7). ACS anchors may reference these ids;
    /// non-canonical ids belong in research/vault notes until promoted.
    pub fn is_foundational_theorem_anchor(&self) -> bool {
        FOUNDATIONAL_SEVEN
            .iter()
            .any(|entry| entry.internal_id == self.theorem_id.as_str())
    }

    /// Minimal ACS well-formedness contract: non-empty coordinate,
    /// canonical theorem id, and finite salience inside [0, 1].
    pub fn is_well_formed(&self) -> bool {
        !self.anchor_id.is_empty()
            && self.is_foundational_theorem_anchor()
            && self.salience.is_finite()
            && (0.0..=1.0).contains(&self.salience)
    }
}

/// CMS-X v3 constitutive field — a collection of anchors plus the
/// pairwise compatibility matrix that defines which anchors can be
/// composed without contradiction.
#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct CmsXField {
    pub anchors: Vec<AcsAnchor>,
    /// `compatible[i*n + j] = true` iff anchors i and j compose.
    pub compatibility: Vec<bool>,
}

impl CmsXField {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn add_anchor(&mut self, anchor: AcsAnchor) {
        let n = self.anchors.len();
        self.anchors.push(anchor);
        // Resize compatibility matrix to (n+1) × (n+1), default true on
        // diagonal, false off-diagonal until explicitly set compatible.
        let new_n = n + 1;
        let mut new_compat = vec![false; new_n * new_n];
        // Copy old values.
        for i in 0..n {
            for j in 0..n {
                new_compat[i * new_n + j] = self.compatibility[i * n + j];
            }
        }
        // Identity is always compatible.
        for i in 0..new_n {
            new_compat[i * new_n + i] = true;
        }
        self.compatibility = new_compat;
    }

    pub fn set_compatible(&mut self, i: usize, j: usize, compatible: bool) {
        let n = self.anchors.len();
        if i < n && j < n {
            self.compatibility[i * n + j] = compatible;
            self.compatibility[j * n + i] = compatible; // symmetric
        }
    }

    pub fn are_compatible(&self, i: usize, j: usize) -> bool {
        let n = self.anchors.len();
        if i < n && j < n {
            self.compatibility[i * n + j]
        } else {
            false
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn empty_field_has_no_anchors() {
        let f = CmsXField::new();
        assert!(f.anchors.is_empty());
    }

    #[test]
    fn acs_lives_in_episodic_plane_and_audits_in_verification() {
        assert_eq!(ACS_CANONICAL_PLANE, RuntimePlane::Episodic);
        assert_ne!(ACS_CANONICAL_PLANE, RuntimePlane::State);
        assert_eq!(ACS_AUDIT_PLANE, RuntimePlane::Verification);
    }

    #[test]
    fn well_formed_anchor_requires_foundational_theorem_and_finite_salience() {
        let ok = AcsAnchor {
            anchor_id: "atlas://e1".to_string(),
            theorem_id: "E1".to_string(),
            salience: 1.0,
        };
        assert!(ok.is_well_formed());

        let unknown_theorem = AcsAnchor {
            theorem_id: "T99".to_string(),
            ..ok.clone()
        };
        assert!(!unknown_theorem.is_well_formed());

        let nan_salience = AcsAnchor {
            salience: f32::NAN,
            ..ok.clone()
        };
        assert!(!nan_salience.is_well_formed());

        let empty_coordinate = AcsAnchor {
            anchor_id: String::new(),
            ..ok
        };
        assert!(!empty_coordinate.is_well_formed());
    }

    #[test]
    fn diagonal_compatibility_is_self_consistent() {
        let mut f = CmsXField::new();
        f.add_anchor(AcsAnchor {
            anchor_id: "a0".to_string(),
            theorem_id: "E1".to_string(),
            salience: 1.0,
        });
        assert!(f.are_compatible(0, 0));
    }

    #[test]
    fn compatibility_is_symmetric() {
        let mut f = CmsXField::new();
        for i in 0..3 {
            f.add_anchor(AcsAnchor {
                anchor_id: format!("a{}", i),
                theorem_id: format!("E{}", i + 1),
                salience: 0.5,
            });
        }
        f.set_compatible(0, 1, true);
        assert!(f.are_compatible(0, 1));
        assert!(f.are_compatible(1, 0));
    }
}
