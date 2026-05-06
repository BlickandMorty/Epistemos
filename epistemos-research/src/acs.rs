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
