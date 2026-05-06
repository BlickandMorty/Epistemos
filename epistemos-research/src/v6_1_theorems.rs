//! HELIOS V6.1 — Sharpened theorem family T35-T42 (Lane 3 RESEARCH-ONLY).
//!
//! HELIOS-V6_1-THEOREMS guard
//!
//! Per `Epistemos V6_1 — Final Synthesis Lock` PART 4 — the
//! V6.1-sharpened theorem family. V6 had T35-T44 at status
//! CANDIDATE; V6.1 reorganizes the same conceptual content under
//! the interrupt-driven framing.
//!
//! Numbering preserves V6 indexes; the *statements* are sharpened.
//!
//! - T35 Interruptive Recall Efficiency (sharpened; ρ_max = 0.20 falsifier)
//! - T36 WBO-Gated Skip Bound (sharpened)
//! - T37 Sheaf-Triggered Recall Completeness (sharpened)
//! - T38 Distilled Hybrid Lift (NEW — replaces V6's T38)
//! - T39 Tool-Augmented State Generalization (sharpened; Apple ICLR 2026)
//! - T40 Connectome-RAG Novel Retrieval (V6 carry-forward; CANDIDATE)
//! - T41 Convergent Number Representation Universality (carry-forward; EV)
//! - T42 Connectome-State Coupling (NEW; bridges Lane-3 PCF to
//!   Lane-1 runtime via ConnectomeAlarm)
//!
//! ## §2.5.2 compliance posture
//!
//! Lane 3 RESEARCH-ONLY substrate. Building requires `--features
//! research`. The theorems themselves are doctrine; their
//! falsifiers are M2 Max protocols (Pro-tier benchmarking).

use serde::{Deserialize, Serialize};

/// One V6.1 theorem id from the T35-T42 family.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum V6_1Theorem {
    /// T35 — Interruptive Recall Efficiency.
    /// Falsifier: on RULER@128K, ρ > 0.20 OR quality drift > ε.
    T35InterruptiveRecallEfficiency,
    /// T36 — WBO-Gated Skip Bound.
    T36WboGatedSkipBound,
    /// T37 — Sheaf-Triggered Recall Completeness.
    T37SheafTriggeredRecallCompleteness,
    /// T38 — Distilled Hybrid Lift (NEW; replaces V6's T38).
    /// V6.1 default training ramp: donor-distilled student
    /// outperforms from-scratch hybrid at matched compute.
    T38DistilledHybridLift,
    /// T39 — Tool-Augmented State Generalization (Apple ICLR 2026).
    T39ToolAugmentedStateGeneralization,
    /// T40 — Connectome-RAG Novel Retrieval (V6 carry-forward).
    /// CANDIDATE; does NOT ship in MAS without first crossing falsifier.
    T40ConnectomeRagNovelRetrieval,
    /// T41 — Convergent Number Representation Universality.
    /// V6 carry-forward; status EV.
    T41ConvergentNumberRepresentation,
    /// T42 — Connectome-State Coupling (NEW IN V6.1).
    /// Load-bearing theorem connecting Lane 3 PCF research to
    /// Lane 1 runtime gating via the ConnectomeAlarm signal.
    T42ConnectomeStateCoupling,
}

impl V6_1Theorem {
    /// Theorem id label per V6.1 §"PART 4".
    pub fn id_label(self) -> &'static str {
        match self {
            V6_1Theorem::T35InterruptiveRecallEfficiency => "T35",
            V6_1Theorem::T36WboGatedSkipBound => "T36",
            V6_1Theorem::T37SheafTriggeredRecallCompleteness => "T37",
            V6_1Theorem::T38DistilledHybridLift => "T38",
            V6_1Theorem::T39ToolAugmentedStateGeneralization => "T39",
            V6_1Theorem::T40ConnectomeRagNovelRetrieval => "T40",
            V6_1Theorem::T41ConvergentNumberRepresentation => "T41",
            V6_1Theorem::T42ConnectomeStateCoupling => "T42",
        }
    }

    /// Lane assignment per V6.1 §"PART 4".
    pub fn lane(self) -> &'static str {
        match self {
            V6_1Theorem::T35InterruptiveRecallEfficiency => "L1",
            V6_1Theorem::T36WboGatedSkipBound => "L1",
            V6_1Theorem::T37SheafTriggeredRecallCompleteness => "L1/L3",
            V6_1Theorem::T38DistilledHybridLift => "L2/L3",
            V6_1Theorem::T39ToolAugmentedStateGeneralization => "L1/L2",
            // T40 — Lane 3 ONLY; "DOES NOT SHIP IN MAS without first
            // crossing falsifier"
            V6_1Theorem::T40ConnectomeRagNovelRetrieval => "L3 only",
            V6_1Theorem::T41ConvergentNumberRepresentation => "L3",
            V6_1Theorem::T42ConnectomeStateCoupling => "L3",
        }
    }

    /// True when the theorem is NEW in V6.1 (not a V6 carry-forward).
    pub fn is_new_in_v6_1(self) -> bool {
        matches!(
            self,
            // T38 was REPLACED in V6.1 (different statement than V6's T38)
            V6_1Theorem::T38DistilledHybridLift
                | V6_1Theorem::T42ConnectomeStateCoupling
        )
    }

    /// True when the theorem was sharpened in V6.1 (V6 statement
    /// preserved but tightened).
    pub fn is_sharpened_in_v6_1(self) -> bool {
        matches!(
            self,
            V6_1Theorem::T35InterruptiveRecallEfficiency
                | V6_1Theorem::T36WboGatedSkipBound
                | V6_1Theorem::T37SheafTriggeredRecallCompleteness
                | V6_1Theorem::T39ToolAugmentedStateGeneralization
        )
    }

    /// True when the theorem is a V6 carry-forward (statement
    /// preserved verbatim).
    pub fn is_v6_carry_forward(self) -> bool {
        matches!(
            self,
            V6_1Theorem::T40ConnectomeRagNovelRetrieval
                | V6_1Theorem::T41ConvergentNumberRepresentation
        )
    }

    /// True when the theorem is the load-bearing bridge from Lane
    /// 3 (PCF research) to Lane 1 (runtime gating). Per V6.1
    /// §"PART 4": "T42 (Connectome-State Coupling) ... is the load-
    /// bearing theorem connecting Lane 3 (PCF research) to
    /// Lane 1 (interrupt-score δ term)."
    pub fn bridges_lane_3_to_lane_1(self) -> bool {
        matches!(self, V6_1Theorem::T42ConnectomeStateCoupling)
    }
}

/// All 8 V6.1 theorems in canonical T35..T42 order.
pub const EIGHT_V6_1_THEOREMS: [V6_1Theorem; 8] = [
    V6_1Theorem::T35InterruptiveRecallEfficiency,
    V6_1Theorem::T36WboGatedSkipBound,
    V6_1Theorem::T37SheafTriggeredRecallCompleteness,
    V6_1Theorem::T38DistilledHybridLift,
    V6_1Theorem::T39ToolAugmentedStateGeneralization,
    V6_1Theorem::T40ConnectomeRagNovelRetrieval,
    V6_1Theorem::T41ConvergentNumberRepresentation,
    V6_1Theorem::T42ConnectomeStateCoupling,
];

/// T42 Connectome-State Coupling falsifier per V6.1 §"PART 4":
/// "Falsifier: ConnectomeAlarm has zero predictive power on
/// held-out interrupt traces."
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum T42FalsifierOutcome {
    /// ConnectomeAlarm has predictive power above chance on held-
    /// out interrupt traces. T42 holds.
    PredictiveAboveChance,
    /// ConnectomeAlarm has zero (or below-chance) predictive power.
    /// T42 fails — the Lane-3 ↔ Lane-1 bridge collapses.
    ZeroOrBelowChance,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn eight_theorems_in_canonical_t35_to_t42_order() {
        assert_eq!(EIGHT_V6_1_THEOREMS.len(), 8);
        assert_eq!(
            EIGHT_V6_1_THEOREMS[0],
            V6_1Theorem::T35InterruptiveRecallEfficiency
        );
        assert_eq!(
            EIGHT_V6_1_THEOREMS[7],
            V6_1Theorem::T42ConnectomeStateCoupling
        );
    }

    #[test]
    fn eight_theorems_are_distinct() {
        let set: std::collections::HashSet<V6_1Theorem> =
            EIGHT_V6_1_THEOREMS.iter().copied().collect();
        assert_eq!(set.len(), 8);
    }

    #[test]
    fn id_labels_follow_t35_to_t42_pattern() {
        let expected = ["T35", "T36", "T37", "T38", "T39", "T40", "T41", "T42"];
        for (theorem, expected_label) in EIGHT_V6_1_THEOREMS.iter().zip(expected.iter()) {
            assert_eq!(theorem.id_label(), *expected_label);
        }
    }

    #[test]
    fn t42_is_new_in_v6_1() {
        // T42 (Connectome-State Coupling) is NEW per V6.1 §PART 4.
        assert!(V6_1Theorem::T42ConnectomeStateCoupling.is_new_in_v6_1());
    }

    #[test]
    fn t38_is_new_in_v6_1_replacing_v6_t38() {
        // V6.1 explicitly says: "T38 — Distilled Hybrid Lift.
        // NEW IN V6.1 (replaces V6's T38)."
        assert!(V6_1Theorem::T38DistilledHybridLift.is_new_in_v6_1());
    }

    #[test]
    fn t35_t36_t37_t39_are_sharpened_not_new() {
        for theorem in [
            V6_1Theorem::T35InterruptiveRecallEfficiency,
            V6_1Theorem::T36WboGatedSkipBound,
            V6_1Theorem::T37SheafTriggeredRecallCompleteness,
            V6_1Theorem::T39ToolAugmentedStateGeneralization,
        ] {
            assert!(theorem.is_sharpened_in_v6_1());
            assert!(!theorem.is_new_in_v6_1());
        }
    }

    #[test]
    fn t40_t41_are_v6_carry_forward() {
        assert!(V6_1Theorem::T40ConnectomeRagNovelRetrieval.is_v6_carry_forward());
        assert!(V6_1Theorem::T41ConvergentNumberRepresentation.is_v6_carry_forward());
    }

    #[test]
    fn classifications_partition_the_eight_theorems() {
        // Every theorem is exactly ONE of: new, sharpened, carry-forward.
        for theorem in EIGHT_V6_1_THEOREMS {
            let count = [
                theorem.is_new_in_v6_1(),
                theorem.is_sharpened_in_v6_1(),
                theorem.is_v6_carry_forward(),
            ]
            .iter()
            .filter(|&&b| b)
            .count();
            assert_eq!(
                count, 1,
                "{:?} fits exactly one classification",
                theorem
            );
        }
    }

    #[test]
    fn only_t42_bridges_lane_3_to_lane_1() {
        for theorem in EIGHT_V6_1_THEOREMS {
            if theorem == V6_1Theorem::T42ConnectomeStateCoupling {
                assert!(theorem.bridges_lane_3_to_lane_1());
            } else {
                assert!(!theorem.bridges_lane_3_to_lane_1());
            }
        }
    }

    #[test]
    fn t40_is_lane_3_only() {
        // V6.1: "Lane: L3 only — DOES NOT SHIP IN MAS without
        // first crossing falsifier."
        assert_eq!(V6_1Theorem::T40ConnectomeRagNovelRetrieval.lane(), "L3 only");
    }

    #[test]
    fn t35_lane_is_l1() {
        // T35 Interruptive Recall Efficiency is L1 (MAS-tier
        // canonical invariant; ρ_max = 0.20 enforced).
        assert_eq!(V6_1Theorem::T35InterruptiveRecallEfficiency.lane(), "L1");
    }

    #[test]
    fn t42_falsifier_outcomes_are_distinct() {
        assert_ne!(
            T42FalsifierOutcome::PredictiveAboveChance,
            T42FalsifierOutcome::ZeroOrBelowChance
        );
    }

    #[test]
    fn v6_1_theorem_serializes_in_snake_case() {
        for (theorem, expected) in [
            (
                V6_1Theorem::T35InterruptiveRecallEfficiency,
                "\"t35_interruptive_recall_efficiency\"",
            ),
            (
                V6_1Theorem::T42ConnectomeStateCoupling,
                "\"t42_connectome_state_coupling\"",
            ),
        ] {
            assert_eq!(serde_json::to_string(&theorem).unwrap(), expected);
        }
    }

    #[test]
    fn round_trip_through_json() {
        for theorem in EIGHT_V6_1_THEOREMS {
            let json = serde_json::to_string(&theorem).unwrap();
            let parsed: V6_1Theorem = serde_json::from_str(&json).unwrap();
            assert_eq!(parsed, theorem);
        }
        for outcome in [
            T42FalsifierOutcome::PredictiveAboveChance,
            T42FalsifierOutcome::ZeroOrBelowChance,
        ] {
            let json = serde_json::to_string(&outcome).unwrap();
            let parsed: T42FalsifierOutcome = serde_json::from_str(&json).unwrap();
            assert_eq!(parsed, outcome);
        }
    }
}
