//! HELIOS V5 — Per-term falsifier actions for Master Inequality
//! (Lane 3 RESEARCH-ONLY).
//!
//! HELIOS-FALSIFIER-ACTIONS guard
//!
//! Per HELIOS v4 preservation `source_docs/epistemos_definitive_master.md`
//! §"PART VI" §2 (Per-Term Falsifier Table).
//!
//! When a Master Inequality term exceeds its threshold, doctrine
//! prescribes a concrete fallback action. This module ships those
//! actions as a typed substrate.
//!
//! ## Per-term falsifier table (verbatim)
//!
//! | Term | Threshold | Falsifier Action |
//! |------|-----------|-----------------|
//! | T_W  | KL_W < 0.02 at 4-bit | Switch to Leech-shaped codebook; if fails, raise to 5-bit |
//! | T_K  | post-Hadamard MSE within 1 dB of E_8 NSM | Try Leech; if fails, abandon nested-lattice |
//! | T_R  | residual KL < 0.01 (WZ ceiling) | Increase Sherry rank 3:4 → 7:8 |
//! | T_Q  | Sherry trapping loss < 0.5% PPL | Fall back to NF4 |
//! | T_S  | empirical T_S ≤ 2 × theoretical | C_S calibration is wrong; re-fit |
//! | T_SE | online surprise variance < 1.5 × oracle replay variance | Drop momentum, fall back to TTT-Linear |
//!
//! ## §2.5.2 compliance posture
//!
//! Lane 3 RESEARCH-ONLY. Building requires `--features research`.

use serde::{Deserialize, Serialize};

/// One of the six Master-Inequality terms per WBO-6.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum InequalityTerm {
    /// T_W — weight quantization drift.
    Tw,
    /// T_K — KV-lattice quantization.
    Tk,
    /// T_R — Wyner-Ziv residual gap.
    Tr,
    /// T_Q — Sherry 1.25-bit codec.
    Tq,
    /// T_S — sketch + escalation drift.
    Ts,
    /// T_SE — self-evolving update drift.
    Tse,
}

/// Concrete fallback action prescribed when a term exceeds its
/// threshold. Each action names a specific implementation pivot
/// from the doctrine.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum FalsifierAction {
    /// Primary fallback for T_W. Switch to Leech-shaped codebook.
    SwitchToLeechCodebook,
    /// Secondary fallback for T_W if Leech also fails. Raise from
    /// 4-bit to 5-bit precision.
    RaiseTo5Bit,
    /// Primary fallback for T_K. Try Leech lattice.
    TryLeechLattice,
    /// Secondary fallback for T_K. Abandon nested-lattice
    /// quantization, use scalar instead.
    AbandonNestedLatticeUseScalar,
    /// Fallback for T_R. Increase Sherry sparsity from 3:4 to 7:8
    /// to give the residual codec more headroom.
    IncreaseSherryRank,
    /// Fallback for T_Q. Switch from Sherry 1.25-bit to NF4
    /// (4-bit groupwise).
    FallBackToNf4,
    /// Fallback for T_S. The C_S calibration is wrong; re-fit it
    /// from production telemetry.
    RefitCsCalibration,
    /// Primary fallback for T_SE. Drop momentum from the Titans-MAC
    /// LMM update rule.
    DropMomentum,
    /// Secondary fallback for T_SE. Fall back to TTT-Linear (no
    /// momentum, simpler hidden-state update).
    FallBackToTttLinear,
}

/// One entry of the per-term falsifier table.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize)]
pub struct FalsifierEntry {
    pub term: InequalityTerm,
    /// Short description of the per-term threshold (free-form
    /// doctrine prose; pinned for replay-bundle integrity).
    pub threshold: &'static str,
    /// Primary action when the term first violates the threshold.
    pub primary_action: FalsifierAction,
    /// Optional secondary action if the primary action fails.
    pub secondary_action: Option<FalsifierAction>,
}

/// All six per-term falsifier entries in canonical order
/// matching the WBO-6 sum (T_W + T_K + T_R + T_Q + T_S + T_SE).
pub const FALSIFIER_TABLE: [FalsifierEntry; 6] = [
    FalsifierEntry {
        term: InequalityTerm::Tw,
        threshold: "KL_W < 0.02 at 4-bit",
        primary_action: FalsifierAction::SwitchToLeechCodebook,
        secondary_action: Some(FalsifierAction::RaiseTo5Bit),
    },
    FalsifierEntry {
        term: InequalityTerm::Tk,
        threshold: "post-Hadamard MSE within 1 dB of E_8 NSM",
        primary_action: FalsifierAction::TryLeechLattice,
        secondary_action: Some(FalsifierAction::AbandonNestedLatticeUseScalar),
    },
    FalsifierEntry {
        term: InequalityTerm::Tr,
        threshold: "residual KL < 0.01 (Wyner-Ziv ceiling)",
        primary_action: FalsifierAction::IncreaseSherryRank,
        secondary_action: None,
    },
    FalsifierEntry {
        term: InequalityTerm::Tq,
        threshold: "Sherry trapping loss < 0.5% PPL",
        primary_action: FalsifierAction::FallBackToNf4,
        secondary_action: None,
    },
    FalsifierEntry {
        term: InequalityTerm::Ts,
        threshold: "empirical T_S <= 2 * theoretical",
        primary_action: FalsifierAction::RefitCsCalibration,
        secondary_action: None,
    },
    FalsifierEntry {
        term: InequalityTerm::Tse,
        threshold: "online surprise variance < 1.5 * oracle replay variance",
        primary_action: FalsifierAction::DropMomentum,
        secondary_action: Some(FalsifierAction::FallBackToTttLinear),
    },
];

impl InequalityTerm {
    /// Look up this term's falsifier table entry.
    pub fn falsifier_entry(self) -> FalsifierEntry {
        for entry in FALSIFIER_TABLE {
            if entry.term == self {
                return entry;
            }
        }
        unreachable!("FALSIFIER_TABLE must contain every InequalityTerm variant")
    }

    /// Short canonical name for telemetry / dashboards.
    pub fn canonical_name(self) -> &'static str {
        match self {
            InequalityTerm::Tw => "T_W",
            InequalityTerm::Tk => "T_K",
            InequalityTerm::Tr => "T_R",
            InequalityTerm::Tq => "T_Q",
            InequalityTerm::Ts => "T_S",
            InequalityTerm::Tse => "T_SE",
        }
    }
}

/// All six terms in canonical WBO-6 order.
pub const SIX_TERMS: [InequalityTerm; 6] = [
    InequalityTerm::Tw,
    InequalityTerm::Tk,
    InequalityTerm::Tr,
    InequalityTerm::Tq,
    InequalityTerm::Ts,
    InequalityTerm::Tse,
];

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn six_terms_in_canonical_wbo6_order() {
        assert_eq!(SIX_TERMS.len(), 6);
        assert_eq!(SIX_TERMS[0], InequalityTerm::Tw);
        assert_eq!(SIX_TERMS[5], InequalityTerm::Tse);
    }

    #[test]
    fn six_terms_are_distinct() {
        let set: std::collections::HashSet<InequalityTerm> = SIX_TERMS.iter().copied().collect();
        assert_eq!(set.len(), 6);
    }

    #[test]
    fn falsifier_table_has_one_entry_per_term() {
        assert_eq!(FALSIFIER_TABLE.len(), 6);
        for term in SIX_TERMS {
            let entry = term.falsifier_entry();
            assert_eq!(entry.term, term);
        }
    }

    #[test]
    fn canonical_names_match_doctrine() {
        assert_eq!(InequalityTerm::Tw.canonical_name(), "T_W");
        assert_eq!(InequalityTerm::Tk.canonical_name(), "T_K");
        assert_eq!(InequalityTerm::Tr.canonical_name(), "T_R");
        assert_eq!(InequalityTerm::Tq.canonical_name(), "T_Q");
        assert_eq!(InequalityTerm::Ts.canonical_name(), "T_S");
        assert_eq!(InequalityTerm::Tse.canonical_name(), "T_SE");
    }

    #[test]
    fn tw_primary_action_is_leech_codebook() {
        let entry = InequalityTerm::Tw.falsifier_entry();
        assert_eq!(entry.primary_action, FalsifierAction::SwitchToLeechCodebook);
        assert_eq!(entry.secondary_action, Some(FalsifierAction::RaiseTo5Bit));
    }

    #[test]
    fn tk_secondary_abandons_nested_lattice() {
        let entry = InequalityTerm::Tk.falsifier_entry();
        assert_eq!(entry.primary_action, FalsifierAction::TryLeechLattice);
        assert_eq!(
            entry.secondary_action,
            Some(FalsifierAction::AbandonNestedLatticeUseScalar)
        );
    }

    #[test]
    fn tr_has_no_secondary_action() {
        let entry = InequalityTerm::Tr.falsifier_entry();
        assert_eq!(entry.secondary_action, None);
    }

    #[test]
    fn tse_secondary_is_ttt_linear() {
        let entry = InequalityTerm::Tse.falsifier_entry();
        assert_eq!(entry.primary_action, FalsifierAction::DropMomentum);
        assert_eq!(
            entry.secondary_action,
            Some(FalsifierAction::FallBackToTttLinear)
        );
    }

    #[test]
    fn three_terms_have_secondary_actions() {
        let with_secondary = SIX_TERMS
            .iter()
            .filter(|t| t.falsifier_entry().secondary_action.is_some())
            .count();
        // T_W, T_K, T_SE have secondary actions; T_R, T_Q, T_S do not.
        assert_eq!(with_secondary, 3);
    }

    #[test]
    fn inequality_term_serializes_in_snake_case() {
        for (term, expected) in [
            (InequalityTerm::Tw, "\"tw\""),
            (InequalityTerm::Tk, "\"tk\""),
            (InequalityTerm::Tr, "\"tr\""),
            (InequalityTerm::Tq, "\"tq\""),
            (InequalityTerm::Ts, "\"ts\""),
            (InequalityTerm::Tse, "\"tse\""),
        ] {
            assert_eq!(serde_json::to_string(&term).unwrap(), expected);
        }
    }

    #[test]
    fn falsifier_action_serializes_in_snake_case() {
        for (action, expected) in [
            (FalsifierAction::SwitchToLeechCodebook, "\"switch_to_leech_codebook\""),
            (FalsifierAction::RaiseTo5Bit, "\"raise_to5_bit\""),
            (FalsifierAction::TryLeechLattice, "\"try_leech_lattice\""),
            (FalsifierAction::FallBackToNf4, "\"fall_back_to_nf4\""),
            (FalsifierAction::RefitCsCalibration, "\"refit_cs_calibration\""),
            (FalsifierAction::DropMomentum, "\"drop_momentum\""),
            (FalsifierAction::FallBackToTttLinear, "\"fall_back_to_ttt_linear\""),
        ] {
            assert_eq!(serde_json::to_string(&action).unwrap(), expected);
        }
    }

    #[test]
    fn round_trip_through_json_for_term_and_action() {
        for term in SIX_TERMS {
            let json = serde_json::to_string(&term).unwrap();
            let parsed: InequalityTerm = serde_json::from_str(&json).unwrap();
            assert_eq!(parsed, term);
        }
        for entry in FALSIFIER_TABLE {
            let action_json = serde_json::to_string(&entry.primary_action).unwrap();
            let parsed: FalsifierAction = serde_json::from_str(&action_json).unwrap();
            assert_eq!(parsed, entry.primary_action);
        }
    }

    #[test]
    fn entry_serializes_to_json_with_term_and_threshold() {
        for entry in FALSIFIER_TABLE {
            let json = serde_json::to_string(&entry).unwrap();
            assert!(json.contains(entry.threshold));
        }
    }
}
