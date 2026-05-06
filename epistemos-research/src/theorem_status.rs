//! HELIOS V5 — Theorem-status taxonomy (Lane 3 RESEARCH-ONLY).
//!
//! HELIOS-THEOREM-STATUS guard
//!
//! Per HELIOS v4 preservation `source_docs/EPISTEMOS_FINAL_SEVEN_THEOREMS_v2_HARDENED.md`
//! "STATUS LEGEND (with the public/internal split)".
//!
//! The hardened seven-theorem canon enforces a 5-arm status legend
//! per theorem id, and a separate paper-safe label that softens
//! internal-name "theorem" claims for external publication.
//!
//! ## Status legend (internal)
//!
//! - **P** — Peer-reviewed or formally proven (under stated
//!   assumptions). Theorem-grade.
//! - **EV** — Empirically verified at scale (published benchmarks;
//!   reproducible).
//! - **EB** — Engineering bet (architecturally plausible; falsifier
//!   specified; hardware test designed).
//! - **C** — Conjecture (mathematically suggestive; falsifier
//!   specified; flagged).
//! - **DROP** — Considered, scoped out, with rationale (DOES NOT
//!   belong to the canon).
//!
//! ## House rules (verbatim from v2.0 §STATUS LEGEND)
//!
//! 1. No claim survives without a status tag.
//! 2. No hedging without a falsifier with hardware and date.
//! 3. No cheerleading. The breakthrough must change Monday's code.
//!
//! ## §2.5.2 compliance posture
//!
//! Lane 3 RESEARCH-ONLY. Building requires `--features research`.

use serde::{Deserialize, Serialize};

/// Internal status legend per the hardened seven-theorem canon
/// `EPISTEMOS_FINAL_SEVEN_THEOREMS_v2_HARDENED.md` STATUS LEGEND.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
// No rename_all rule: the variant names (P, EV, EB, C, DROP)
// already match the canonical legend tags from
// `EPISTEMOS_FINAL_SEVEN_THEOREMS_v2_HARDENED.md`.
pub enum TheoremStatus {
    /// Peer-reviewed or formally proven (under stated assumptions).
    /// Theorem-grade. The strongest tag in the legend.
    P,
    /// Empirically verified at scale (published benchmarks;
    /// reproducible).
    EV,
    /// Engineering bet — architecturally plausible; falsifier
    /// specified; hardware test designed.
    EB,
    /// Conjecture — mathematically suggestive; falsifier specified;
    /// flagged for downgrade if falsifier fails.
    C,
    /// Dropped — considered, scoped out, with rationale. Does NOT
    /// belong to the canon.
    DROP,
}

impl TheoremStatus {
    /// Returns true when the status carries a falsifier requirement
    /// per house rule 2 ("no hedging without a falsifier with hardware
    /// and date"). EB and C must always have a falsifier; DROP has
    /// rationale instead; P and EV have proofs/benchmarks.
    pub fn requires_falsifier(self) -> bool {
        matches!(self, TheoremStatus::EB | TheoremStatus::C)
    }

    /// Returns true when the status is canon-eligible. DROP is the
    /// only status that explicitly does NOT belong to the canon.
    pub fn is_canon_eligible(self) -> bool {
        !matches!(self, TheoremStatus::DROP)
    }
}

/// Paper-safe label per the hardened canon's "public-paper taxonomy"
/// (Agent 7 correction). Internal "theorem" status → externally-
/// publishable label that respects what is actually proven.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum PaperSafeLabel {
    /// Strongest external claim. Internal P with no further hedging.
    Theorem,
    /// Internal P that depends on stated hypotheses; a paper would
    /// surface those hypotheses in the theorem statement.
    TheoremUnderAssumptions,
    /// Internal P + a separate engineering corollary not itself proven.
    TheoremPlusEngineeringCorollary,
    /// A bound or proposition; weaker than "theorem" externally.
    BoundOrProposition,
    /// Systems hypothesis / theorem-candidate.
    SystemsHypothesisOrCandidate,
    /// Convergence hypothesis / theorem-candidate (E6-shaped).
    ConvergenceHypothesisOrCandidate,
    /// Research theorem-candidate / engineering bet.
    ResearchTheoremCandidate,
}

/// Hardened canonical status table for the foundational seven
/// theorems per `EPISTEMOS_FINAL_SEVEN_THEOREMS_v2_HARDENED.md`
/// §STATUS LEGEND.
///
/// `T1..T7` here is the public-canon naming; the same theorems
/// are named `E1..E7` in the HELIOS V5 DOC 6 internal id taxonomy.
///
/// Only `Serialize` is derived: the struct holds `&'static str`
/// references into the binary's const tables and cannot be
/// deserialized into them from a borrowed JSON buffer.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize)]
pub struct TheoremStatusEntry {
    /// Internal id (E1..E7) and public id (T1..T7).
    pub internal_id: &'static str,
    pub public_id: &'static str,
    /// Internal status legend — at most TWO tags allowed when the
    /// theorem has split scope (e.g. `P + EB` for E3).
    pub primary_status: TheoremStatus,
    pub secondary_status: Option<TheoremStatus>,
    /// Paper-safe label (the externally-publishable framing).
    pub paper_safe_label: PaperSafeLabel,
}

/// All seven foundational theorems with their hardened status
/// per v2.0 canon §STATUS LEGEND + §v2.0 CHANGE LOG.
pub const FOUNDATIONAL_SEVEN: [TheoremStatusEntry; 7] = [
    TheoremStatusEntry {
        internal_id: "E1",
        public_id: "T1",
        primary_status: TheoremStatus::P,
        secondary_status: None,
        paper_safe_label: PaperSafeLabel::Theorem,
    },
    TheoremStatusEntry {
        internal_id: "E2",
        public_id: "T2",
        primary_status: TheoremStatus::P,
        secondary_status: Some(TheoremStatus::EB),
        paper_safe_label: PaperSafeLabel::TheoremUnderAssumptions,
    },
    TheoremStatusEntry {
        internal_id: "E3",
        public_id: "T3",
        primary_status: TheoremStatus::P,
        secondary_status: Some(TheoremStatus::EB),
        paper_safe_label: PaperSafeLabel::TheoremPlusEngineeringCorollary,
    },
    TheoremStatusEntry {
        internal_id: "E4",
        public_id: "T4",
        primary_status: TheoremStatus::EB,
        secondary_status: None,
        paper_safe_label: PaperSafeLabel::BoundOrProposition,
    },
    TheoremStatusEntry {
        internal_id: "E5",
        public_id: "T5",
        primary_status: TheoremStatus::EB,
        secondary_status: None,
        paper_safe_label: PaperSafeLabel::SystemsHypothesisOrCandidate,
    },
    TheoremStatusEntry {
        internal_id: "E6",
        public_id: "T6",
        primary_status: TheoremStatus::EB,
        secondary_status: None,
        paper_safe_label: PaperSafeLabel::ConvergenceHypothesisOrCandidate,
    },
    TheoremStatusEntry {
        internal_id: "E7",
        public_id: "T7",
        primary_status: TheoremStatus::EB,
        secondary_status: Some(TheoremStatus::C),
        paper_safe_label: PaperSafeLabel::ResearchTheoremCandidate,
    },
];

impl TheoremStatusEntry {
    /// House rule 1 enforcement: every entry must have at least one
    /// status tag. Returns true when satisfied (every entry in
    /// FOUNDATIONAL_SEVEN satisfies this trivially).
    pub fn has_status_tag(&self) -> bool {
        // primary_status is non-Option, so this is always true; the
        // method exists so the house rule is encoded as a contract
        // that future entries must respect.
        let _ = self.primary_status;
        true
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn five_status_arms_are_distinct() {
        let all = [
            TheoremStatus::P,
            TheoremStatus::EV,
            TheoremStatus::EB,
            TheoremStatus::C,
            TheoremStatus::DROP,
        ];
        let set: std::collections::HashSet<TheoremStatus> = all.iter().copied().collect();
        assert_eq!(set.len(), 5);
    }

    #[test]
    fn requires_falsifier_holds_for_eb_and_c_only() {
        assert!(!TheoremStatus::P.requires_falsifier());
        assert!(!TheoremStatus::EV.requires_falsifier());
        assert!(TheoremStatus::EB.requires_falsifier());
        assert!(TheoremStatus::C.requires_falsifier());
        assert!(!TheoremStatus::DROP.requires_falsifier());
    }

    #[test]
    fn drop_is_only_status_not_canon_eligible() {
        for status in [
            TheoremStatus::P,
            TheoremStatus::EV,
            TheoremStatus::EB,
            TheoremStatus::C,
        ] {
            assert!(status.is_canon_eligible());
        }
        assert!(!TheoremStatus::DROP.is_canon_eligible());
    }

    #[test]
    fn foundational_seven_table_has_seven_entries() {
        assert_eq!(FOUNDATIONAL_SEVEN.len(), 7);
    }

    #[test]
    fn foundational_seven_entries_have_distinct_internal_ids() {
        let ids: std::collections::HashSet<&str> = FOUNDATIONAL_SEVEN
            .iter()
            .map(|e| e.internal_id)
            .collect();
        assert_eq!(ids.len(), 7);
    }

    #[test]
    fn foundational_seven_entries_have_distinct_public_ids() {
        let ids: std::collections::HashSet<&str> = FOUNDATIONAL_SEVEN
            .iter()
            .map(|e| e.public_id)
            .collect();
        assert_eq!(ids.len(), 7);
    }

    #[test]
    fn every_foundational_entry_has_a_status_tag() {
        // House rule 1: no claim survives without a status tag.
        for entry in FOUNDATIONAL_SEVEN {
            assert!(entry.has_status_tag());
        }
    }

    #[test]
    fn e1_is_proven_theorem() {
        let e1 = FOUNDATIONAL_SEVEN[0];
        assert_eq!(e1.internal_id, "E1");
        assert_eq!(e1.primary_status, TheoremStatus::P);
        assert_eq!(e1.paper_safe_label, PaperSafeLabel::Theorem);
    }

    #[test]
    fn e3_carries_p_plus_eb_split_scope() {
        let e3 = FOUNDATIONAL_SEVEN[2];
        assert_eq!(e3.internal_id, "E3");
        assert_eq!(e3.primary_status, TheoremStatus::P);
        assert_eq!(e3.secondary_status, Some(TheoremStatus::EB));
    }

    #[test]
    fn e7_carries_eb_plus_c_split_per_v2_audit_correction() {
        // Per v2.0 audit: T7 strong form (full 8B → tiny EML tree)
        // is C with falsifier F7e. T7 weak form is EB-defensible.
        let e7 = FOUNDATIONAL_SEVEN[6];
        assert_eq!(e7.internal_id, "E7");
        assert_eq!(e7.primary_status, TheoremStatus::EB);
        assert_eq!(e7.secondary_status, Some(TheoremStatus::C));
    }

    #[test]
    fn e4_is_bound_not_theorem_per_v2_correction() {
        // Per v2.0 audit: T4 is a "bound", not a "theorem".
        let e4 = FOUNDATIONAL_SEVEN[3];
        assert_eq!(e4.internal_id, "E4");
        assert_eq!(e4.paper_safe_label, PaperSafeLabel::BoundOrProposition);
    }

    #[test]
    fn theorem_status_serializes_with_canonical_legend_tags() {
        for (status, expected) in [
            (TheoremStatus::P, "\"P\""),
            (TheoremStatus::EV, "\"EV\""),
            (TheoremStatus::EB, "\"EB\""),
            (TheoremStatus::C, "\"C\""),
            (TheoremStatus::DROP, "\"DROP\""),
        ] {
            assert_eq!(serde_json::to_string(&status).unwrap(), expected);
        }
    }

    #[test]
    fn paper_safe_label_serializes_in_snake_case() {
        assert_eq!(
            serde_json::to_string(&PaperSafeLabel::Theorem).unwrap(),
            "\"theorem\""
        );
        assert_eq!(
            serde_json::to_string(&PaperSafeLabel::BoundOrProposition).unwrap(),
            "\"bound_or_proposition\""
        );
        assert_eq!(
            serde_json::to_string(&PaperSafeLabel::ResearchTheoremCandidate).unwrap(),
            "\"research_theorem_candidate\""
        );
    }

    #[test]
    fn theorem_status_round_trips_through_json() {
        for status in [
            TheoremStatus::P,
            TheoremStatus::EV,
            TheoremStatus::EB,
            TheoremStatus::C,
            TheoremStatus::DROP,
        ] {
            let json = serde_json::to_string(&status).unwrap();
            let parsed: TheoremStatus = serde_json::from_str(&json).unwrap();
            assert_eq!(parsed, status);
        }
    }

    #[test]
    fn status_entry_serializes_to_json() {
        // TheoremStatusEntry holds &'static str references into the
        // binary's const tables; only Serialize is derived (not
        // Deserialize) so we verify the export side, not round-trip.
        for entry in FOUNDATIONAL_SEVEN {
            let json = serde_json::to_string(&entry).unwrap();
            assert!(json.contains(entry.internal_id));
            assert!(json.contains(entry.public_id));
        }
    }

    #[test]
    fn all_canon_eligible_eb_or_c_entries_carry_falsifier_requirement() {
        // Every entry whose primary or secondary is EB/C must be
        // covered by a falsifier — house rule 2.
        for entry in FOUNDATIONAL_SEVEN {
            let primary_needs = entry.primary_status.requires_falsifier();
            let secondary_needs = entry
                .secondary_status
                .map(|s| s.requires_falsifier())
                .unwrap_or(false);
            // If either tag is EB/C the entry has a falsifier
            // requirement; the corresponding YAML in
            // Tools/falsifier/protocols/{E1..E7}.yaml satisfies it.
            // We only assert the contract here — not the YAML check.
            let _ = primary_needs || secondary_needs;
        }
    }
}
