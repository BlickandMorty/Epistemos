//! Source:
//! - `docs/fusion/jordan's research/kimis deep research/acs_meta_layer.md`
//!   — Autopoietic Cognitive Stack (ACS) doctrine. Six scale levels
//!   (transistor → cell → tissue → organ → organism → ecosystem); same
//!   Residency-Governance pattern applies at every scale.
//! - `docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_B_2026_05_16.md`
//!   §5 J5 row.
//! - Companions: [`super::kuramoto`] (cell→tissue sync),
//!   [`super::notch_delta`] (cell differentiation),
//!   [`super::autopoiesis`] (organism closure check),
//!   [`super::vsm`] (organ→organism governance).
//!
//! # Wave J5 — ACS multi-scale governance envelope
//!
//! Each ACS sub-primitive already ships its substrate-floor kernel
//! under a sibling module. This file is the typed envelope that pins
//! each primitive to the canonical scale level it operates at, so
//! future code wiring ACS dispatch can't accidentally route — say —
//! a Notch-Delta inhibition signal through the organism-level closure
//! check.
//!
//! ## Scale taxonomy (canonical, per `acs_meta_layer.md`)
//!
//! | Level # | Scale       | Concrete unit                         |
//! |---------|-------------|---------------------------------------|
//! | 0       | Transistor  | physical compute element              |
//! | 1       | Cell        | SCOPE-Rex instance (one model+ctx)    |
//! | 2       | Tissue      | synchronized cell pool                |
//! | 3       | Organ       | task-specialized tissue cluster       |
//! | 4       | Organism    | self-contained agentic deployment     |
//! | 5       | Ecosystem   | federation of organisms               |
//!
//! ## Primitive → scale mapping
//!
//! | Primitive    | Scale (canonical)             | Doctrine role                                       |
//! |--------------|-------------------------------|-----------------------------------------------------|
//! | Kuramoto     | Tissue                        | phase-coupled cell sync via mean-field coupling     |
//! | NotchDelta   | Cell                          | lateral inhibition → cell-type differentiation      |
//! | Autopoiesis  | Organism                      | Maturana-Varela 6-criteria operational closure      |
//! | VSM          | Organ + Organism (recursive)  | Stafford Beer viable-systems governance             |

use serde::{Deserialize, Serialize};

/// Six scale levels per `acs_meta_layer.md`. Numeric tag matches the
/// doctrine's level index.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize)]
pub enum AcsScale {
    Transistor = 0,
    Cell = 1,
    Tissue = 2,
    Organ = 3,
    Organism = 4,
    Ecosystem = 5,
}

impl AcsScale {
    pub const ALL: [AcsScale; 6] = [
        AcsScale::Transistor,
        AcsScale::Cell,
        AcsScale::Tissue,
        AcsScale::Organ,
        AcsScale::Organism,
        AcsScale::Ecosystem,
    ];

    pub const fn name(self) -> &'static str {
        match self {
            AcsScale::Transistor => "transistor",
            AcsScale::Cell => "cell",
            AcsScale::Tissue => "tissue",
            AcsScale::Organ => "organ",
            AcsScale::Organism => "organism",
            AcsScale::Ecosystem => "ecosystem",
        }
    }

    pub const fn index(self) -> u8 {
        self as u8
    }

    /// Reverse lookup for [`Self::name`]. `None` for unknown names.
    pub fn from_name(name: &str) -> Option<Self> {
        Self::ALL.iter().copied().find(|s| s.name() == name)
    }

    /// Reverse lookup for [`Self::index`]. `None` for values outside
    /// `0..=5`.
    pub const fn from_index(idx: u8) -> Option<Self> {
        match idx {
            0 => Some(AcsScale::Transistor),
            1 => Some(AcsScale::Cell),
            2 => Some(AcsScale::Tissue),
            3 => Some(AcsScale::Organ),
            4 => Some(AcsScale::Organism),
            5 => Some(AcsScale::Ecosystem),
            _ => None,
        }
    }

    /// Predicate: this is the physical-compute level (Transistor).
    /// No primitive operates here per the J5 substrate floor.
    pub const fn is_physical(self) -> bool {
        matches!(self, AcsScale::Transistor)
    }

    /// Predicate: this is one of the biological-metaphor scales
    /// (Cell / Tissue / Organ / Organism). The 4 J5 primitives all
    /// dispatch in this band.
    pub const fn is_biological(self) -> bool {
        matches!(
            self,
            AcsScale::Cell | AcsScale::Tissue | AcsScale::Organ | AcsScale::Organism
        )
    }

    /// Predicate: this is the federation frontier (Ecosystem).
    /// Cross-surface invariant: exactly one of `is_physical /
    /// is_biological / is_federation` is true per variant
    /// (3-way partition over 6 scales).
    pub const fn is_federation(self) -> bool {
        matches!(self, AcsScale::Ecosystem)
    }
}

/// Catalog of the 4 ACS primitives plus their canonical scales. Used
/// for dispatch validation: an attempt to route a primitive at the
/// wrong scale returns a typed `AcsDispatchError`.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize)]
pub enum AcsPrimitive {
    /// Kuramoto mean-field phase coupling — Tissue scale.
    Kuramoto,
    /// Notch-Delta lateral inhibition — Cell scale.
    NotchDelta,
    /// Autopoietic operational-closure check — Organism scale.
    Autopoiesis,
    /// Stafford Beer VSM — recursive, spans Organ + Organism.
    Vsm,
}

impl AcsPrimitive {
    pub const ALL: [AcsPrimitive; 4] = [
        AcsPrimitive::Kuramoto,
        AcsPrimitive::NotchDelta,
        AcsPrimitive::Autopoiesis,
        AcsPrimitive::Vsm,
    ];

    pub const fn code(self) -> &'static str {
        match self {
            AcsPrimitive::Kuramoto => "kuramoto",
            AcsPrimitive::NotchDelta => "notch_delta",
            AcsPrimitive::Autopoiesis => "autopoiesis",
            AcsPrimitive::Vsm => "vsm",
        }
    }

    /// True iff `scale` is a valid dispatch target for this primitive
    /// per the doctrine's canonical mapping. VSM is the only primitive
    /// allowed at more than one scale (recursive by construction).
    pub fn allows_scale(self, scale: AcsScale) -> bool {
        match self {
            AcsPrimitive::Kuramoto => scale == AcsScale::Tissue,
            AcsPrimitive::NotchDelta => scale == AcsScale::Cell,
            AcsPrimitive::Autopoiesis => scale == AcsScale::Organism,
            AcsPrimitive::Vsm => matches!(scale, AcsScale::Organ | AcsScale::Organism),
        }
    }

    /// Reverse lookup for [`Self::code`]. `None` for unknown codes.
    pub fn from_code(code: &str) -> Option<Self> {
        Self::ALL.iter().copied().find(|p| p.code() == code)
    }

    /// All scales this primitive is allowed to dispatch at. Cross-
    /// surface invariant: `allowed_scales().contains(&s) iff
    /// allows_scale(s)` for every `s` in `AcsScale::ALL`.
    pub fn allowed_scales(self) -> Vec<AcsScale> {
        AcsScale::ALL
            .iter()
            .copied()
            .filter(|&s| self.allows_scale(s))
            .collect()
    }

    /// Predicate: this primitive operates at more than one scale
    /// (currently only VSM, the Stafford Beer recursive). Cross-
    /// surface invariant: `is_recursive iff allowed_scales().len() > 1`.
    pub fn is_recursive(self) -> bool {
        self.allowed_scales().len() > 1
    }
}

impl AcsDispatchError {
    /// Stable identifier for the failure cause.
    pub const fn cause(&self) -> &'static str {
        match self {
            AcsDispatchError::ScaleMismatch { .. } => "scale_mismatch",
            AcsDispatchError::TransistorScaleHasNoPrimitive => "transistor_scale_has_no_primitive",
            AcsDispatchError::EcosystemScaleNotYetWired => "ecosystem_scale_not_yet_wired",
        }
    }

    pub const fn is_scale_mismatch(&self) -> bool {
        matches!(self, AcsDispatchError::ScaleMismatch { .. })
    }

    pub const fn is_transistor(&self) -> bool {
        matches!(self, AcsDispatchError::TransistorScaleHasNoPrimitive)
    }

    /// Cross-surface invariant: `is_scale_mismatch XOR is_transistor
    /// XOR is_ecosystem_unwired` partitions all variants.
    pub const fn is_ecosystem_unwired(&self) -> bool {
        matches!(self, AcsDispatchError::EcosystemScaleNotYetWired)
    }
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum AcsDispatchError {
    ScaleMismatch {
        primitive: AcsPrimitive,
        attempted: AcsScale,
    },
    TransistorScaleHasNoPrimitive,
    EcosystemScaleNotYetWired,
}

/// Validate that a primitive submission targets a scale it's
/// canonically allowed at. Transistor + Ecosystem return their own
/// error variants because no primitive in the J5 substrate floor
/// operates at those scales yet — Transistor is the physical compute
/// element (no governance to dispatch), Ecosystem is the federation
/// frontier (not yet wired in B-owned substrate).
pub fn validate_dispatch(
    primitive: AcsPrimitive,
    attempted: AcsScale,
) -> Result<(), AcsDispatchError> {
    match attempted {
        AcsScale::Transistor => Err(AcsDispatchError::TransistorScaleHasNoPrimitive),
        AcsScale::Ecosystem => Err(AcsDispatchError::EcosystemScaleNotYetWired),
        _ => {
            if primitive.allows_scale(attempted) {
                Ok(())
            } else {
                Err(AcsDispatchError::ScaleMismatch { primitive, attempted })
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn six_distinct_scales() {
        let s: std::collections::HashSet<_> = AcsScale::ALL.iter().copied().collect();
        assert_eq!(s.len(), 6);
    }

    #[test]
    fn scale_indices_match_doctrine_order() {
        assert_eq!(AcsScale::Transistor.index(), 0);
        assert_eq!(AcsScale::Cell.index(), 1);
        assert_eq!(AcsScale::Tissue.index(), 2);
        assert_eq!(AcsScale::Organ.index(), 3);
        assert_eq!(AcsScale::Organism.index(), 4);
        assert_eq!(AcsScale::Ecosystem.index(), 5);
    }

    #[test]
    fn four_distinct_primitives() {
        let s: std::collections::HashSet<_> = AcsPrimitive::ALL.iter().copied().collect();
        assert_eq!(s.len(), 4);
    }

    #[test]
    fn kuramoto_only_at_tissue() {
        assert!(AcsPrimitive::Kuramoto.allows_scale(AcsScale::Tissue));
        for s in [AcsScale::Cell, AcsScale::Organ, AcsScale::Organism] {
            assert!(!AcsPrimitive::Kuramoto.allows_scale(s));
        }
    }

    #[test]
    fn notch_delta_only_at_cell() {
        assert!(AcsPrimitive::NotchDelta.allows_scale(AcsScale::Cell));
        for s in [AcsScale::Tissue, AcsScale::Organ, AcsScale::Organism] {
            assert!(!AcsPrimitive::NotchDelta.allows_scale(s));
        }
    }

    #[test]
    fn autopoiesis_only_at_organism() {
        assert!(AcsPrimitive::Autopoiesis.allows_scale(AcsScale::Organism));
        for s in [AcsScale::Cell, AcsScale::Tissue, AcsScale::Organ] {
            assert!(!AcsPrimitive::Autopoiesis.allows_scale(s));
        }
    }

    #[test]
    fn vsm_recursive_at_organ_and_organism() {
        assert!(AcsPrimitive::Vsm.allows_scale(AcsScale::Organ));
        assert!(AcsPrimitive::Vsm.allows_scale(AcsScale::Organism));
        for s in [AcsScale::Cell, AcsScale::Tissue] {
            assert!(!AcsPrimitive::Vsm.allows_scale(s));
        }
    }

    #[test]
    fn dispatch_transistor_always_fails() {
        for p in AcsPrimitive::ALL.iter() {
            assert_eq!(
                validate_dispatch(*p, AcsScale::Transistor).unwrap_err(),
                AcsDispatchError::TransistorScaleHasNoPrimitive
            );
        }
    }

    #[test]
    fn dispatch_ecosystem_returns_unwired() {
        for p in AcsPrimitive::ALL.iter() {
            assert_eq!(
                validate_dispatch(*p, AcsScale::Ecosystem).unwrap_err(),
                AcsDispatchError::EcosystemScaleNotYetWired
            );
        }
    }

    #[test]
    fn correct_dispatch_passes() {
        assert!(validate_dispatch(AcsPrimitive::Kuramoto, AcsScale::Tissue).is_ok());
        assert!(validate_dispatch(AcsPrimitive::NotchDelta, AcsScale::Cell).is_ok());
        assert!(validate_dispatch(AcsPrimitive::Autopoiesis, AcsScale::Organism).is_ok());
        assert!(validate_dispatch(AcsPrimitive::Vsm, AcsScale::Organ).is_ok());
        assert!(validate_dispatch(AcsPrimitive::Vsm, AcsScale::Organism).is_ok());
    }

    #[test]
    fn scale_mismatch_rejected() {
        let err = validate_dispatch(AcsPrimitive::Kuramoto, AcsScale::Cell).unwrap_err();
        assert!(matches!(
            err,
            AcsDispatchError::ScaleMismatch {
                primitive: AcsPrimitive::Kuramoto,
                attempted: AcsScale::Cell,
            }
        ));
    }

    #[test]
    fn all_primitive_codes_unique() {
        let mut s = std::collections::HashSet::new();
        for p in AcsPrimitive::ALL.iter() {
            assert!(s.insert(p.code()));
        }
    }

    #[test]
    fn scale_names_lowercase() {
        for sc in AcsScale::ALL.iter() {
            assert!(!sc.name().is_empty());
            assert!(sc.name().chars().all(|c| c.is_ascii_lowercase()));
        }
    }

    #[test]
    fn scale_serde_roundtrip() {
        let s = AcsScale::Organism;
        let json = serde_json::to_string(&s).unwrap();
        let back: AcsScale = serde_json::from_str(&json).unwrap();
        assert_eq!(s, back);
    }

    #[test]
    fn primitive_serde_roundtrip() {
        let p = AcsPrimitive::Vsm;
        let json = serde_json::to_string(&p).unwrap();
        let back: AcsPrimitive = serde_json::from_str(&json).unwrap();
        assert_eq!(p, back);
    }

    // ── diagnostic surface (iter 177) ────────────────────────────────────────

    #[test]
    fn scale_from_name_roundtrips_all() {
        for s in AcsScale::ALL.iter().copied() {
            assert_eq!(AcsScale::from_name(s.name()), Some(s));
        }
        assert_eq!(AcsScale::from_name("Cell"), None);
        assert_eq!(AcsScale::from_name(""), None);
    }

    #[test]
    fn scale_from_index_roundtrips_all() {
        for s in AcsScale::ALL.iter().copied() {
            assert_eq!(AcsScale::from_index(s.index()), Some(s));
        }
        assert_eq!(AcsScale::from_index(6), None);
        assert_eq!(AcsScale::from_index(255), None);
    }

    #[test]
    fn scale_3way_classifiers_partition() {
        // Cross-surface invariant: is_physical XOR is_biological XOR is_federation.
        for s in AcsScale::ALL.iter().copied() {
            let trio = [s.is_physical(), s.is_biological(), s.is_federation()];
            assert_eq!(trio.iter().filter(|t| **t).count(), 1, "{:?}", s);
        }
        assert_eq!(AcsScale::ALL.iter().filter(|s| s.is_physical()).count(), 1);
        assert_eq!(AcsScale::ALL.iter().filter(|s| s.is_biological()).count(), 4);
        assert_eq!(AcsScale::ALL.iter().filter(|s| s.is_federation()).count(), 1);
    }

    #[test]
    fn primitive_from_code_roundtrips_all() {
        for p in AcsPrimitive::ALL.iter().copied() {
            assert_eq!(AcsPrimitive::from_code(p.code()), Some(p));
        }
        assert_eq!(AcsPrimitive::from_code("Kuramoto"), None);
    }

    #[test]
    fn primitive_allowed_scales_matches_allows_scale_invariant() {
        // Cross-surface invariant: allowed_scales().contains(s) iff allows_scale(s).
        for p in AcsPrimitive::ALL.iter().copied() {
            let allowed = p.allowed_scales();
            for s in AcsScale::ALL.iter().copied() {
                assert_eq!(allowed.contains(&s), p.allows_scale(s), "p={:?} s={:?}", p, s);
            }
        }
    }

    #[test]
    fn primitive_is_recursive_only_for_vsm() {
        // Cross-surface invariant: is_recursive iff allowed_scales.len() > 1.
        for p in AcsPrimitive::ALL.iter().copied() {
            assert_eq!(p.is_recursive(), p.allowed_scales().len() > 1);
        }
        assert!(AcsPrimitive::Vsm.is_recursive());
        assert!(!AcsPrimitive::Kuramoto.is_recursive());
        assert!(!AcsPrimitive::NotchDelta.is_recursive());
        assert!(!AcsPrimitive::Autopoiesis.is_recursive());
    }

    #[test]
    fn dispatch_error_cause_distinct() {
        let variants = [
            AcsDispatchError::ScaleMismatch {
                primitive: AcsPrimitive::Kuramoto,
                attempted: AcsScale::Cell,
            },
            AcsDispatchError::TransistorScaleHasNoPrimitive,
            AcsDispatchError::EcosystemScaleNotYetWired,
        ];
        let causes: std::collections::HashSet<_> = variants.iter().map(|e| e.cause()).collect();
        assert_eq!(causes.len(), 3);
    }

    #[test]
    fn dispatch_error_3way_classifier_partition() {
        let variants = [
            AcsDispatchError::ScaleMismatch {
                primitive: AcsPrimitive::Kuramoto,
                attempted: AcsScale::Cell,
            },
            AcsDispatchError::TransistorScaleHasNoPrimitive,
            AcsDispatchError::EcosystemScaleNotYetWired,
        ];
        // Cross-surface invariant: is_scale_mismatch XOR is_transistor XOR
        // is_ecosystem_unwired.
        for e in variants {
            let trio = [e.is_scale_mismatch(), e.is_transistor(), e.is_ecosystem_unwired()];
            assert_eq!(trio.iter().filter(|t| **t).count(), 1, "{:?}", e);
        }
    }

    #[test]
    fn real_dispatch_errors_carry_matching_classifier() {
        // Cross-surface: validate_dispatch errors carry matching predicates.
        let err = validate_dispatch(AcsPrimitive::Kuramoto, AcsScale::Cell).unwrap_err();
        assert!(err.is_scale_mismatch());
        let err = validate_dispatch(AcsPrimitive::Kuramoto, AcsScale::Transistor).unwrap_err();
        assert!(err.is_transistor());
        let err = validate_dispatch(AcsPrimitive::Kuramoto, AcsScale::Ecosystem).unwrap_err();
        assert!(err.is_ecosystem_unwired());
    }
}
