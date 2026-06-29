//! Deterministic confidence-floor decision policy (F4 promote-lean, P5.H).
//!
//! Promoted from `research::confidence_floors` (research-gated, default OFF)
//! into the always-compiled core — JUST the scalar policy the app needs to make
//! a verifiable accept/escalate decision, byte-identical to the research
//! `ConfidenceLadderLog::decide` (minus the per-attempt log append). The heavier
//! observability (the log, stats, health verdict) stays research-gated; this is
//! the deterministic kernel that pairs with the EML route fusion
//! ([`crate::eml_rerank`]) — a local answer either clears a hard confidence
//! floor or escalates, with no model in the loop.
//!
//! Floors (Wave J B.6.9, `docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_B_2026_05_16.md`
//! §5 Phase B.6.9): T1 ≥ 0.85, T2 ≥ 0.75, T3 ≥ 0.70.

use serde::{Deserialize, Serialize};

/// A tiered confidence floor. Walk T1 → T2 → T3; accept at the first floor the
/// score clears.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize)]
pub enum ConfidenceFloor {
    T1,
    T2,
    T3,
}

impl ConfidenceFloor {
    pub const ALL: [ConfidenceFloor; 3] = [
        ConfidenceFloor::T1,
        ConfidenceFloor::T2,
        ConfidenceFloor::T3,
    ];

    /// Hard confidence floor for the tier. Byte-identical to the research module.
    pub const fn threshold(self) -> f32 {
        match self {
            ConfidenceFloor::T1 => 0.85,
            ConfidenceFloor::T2 => 0.75,
            ConfidenceFloor::T3 => 0.70,
        }
    }

    pub const fn code(self) -> &'static str {
        match self {
            ConfidenceFloor::T1 => "T1",
            ConfidenceFloor::T2 => "T2",
            ConfidenceFloor::T3 => "T3",
        }
    }

    /// Reverse lookup for [`Self::code`]. `None` for unknown codes.
    pub fn from_code(code: &str) -> Option<Self> {
        Self::ALL.iter().copied().find(|f| f.code() == code)
    }
}

/// The outcome of a single confidence-floor decision. Exactly one predicate
/// (`is_accepted` / `is_escalated` / `is_empty_no_escalate`) holds per variant.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub enum FloorOutcome {
    /// Accepted at this tier (score ≥ `tier.threshold()`).
    Accepted(ConfidenceFloor),
    /// No tier accepted and `escalate_on_empty` was set → external/human check.
    Escalated,
    /// No tier accepted and escalation was off → empty, no escalation.
    EmptyNoEscalate,
}

impl FloorOutcome {
    pub const fn is_accepted(&self) -> bool {
        matches!(self, FloorOutcome::Accepted(_))
    }

    pub const fn is_escalated(&self) -> bool {
        matches!(self, FloorOutcome::Escalated)
    }

    pub const fn is_empty_no_escalate(&self) -> bool {
        matches!(self, FloorOutcome::EmptyNoEscalate)
    }

    /// The accepting tier, or `None` if the decision did not accept.
    /// Invariant: `accepted_at_tier().is_some()` iff `is_accepted()`.
    pub const fn accepted_at_tier(&self) -> Option<ConfidenceFloor> {
        match self {
            FloorOutcome::Accepted(t) => Some(*t),
            _ => None,
        }
    }

    /// Stable code for the outcome (the accepting tier code, or the variant).
    pub const fn code(&self) -> &'static str {
        match self {
            FloorOutcome::Accepted(ConfidenceFloor::T1) => "T1",
            FloorOutcome::Accepted(ConfidenceFloor::T2) => "T2",
            FloorOutcome::Accepted(ConfidenceFloor::T3) => "T3",
            FloorOutcome::Escalated => "Escalated",
            FloorOutcome::EmptyNoEscalate => "EmptyNoEscalate",
        }
    }
}

/// Walk the floors T1 → T2 → T3; accept at the first floor the score clears.
/// If none accept and `escalate_on_empty`, escalate; otherwise empty-no-escalate.
/// Byte-identical to `research::confidence_floors::ConfidenceLadderLog::decide`
/// (minus the log append), so the promoted kernel and the research observability
/// agree exactly on the cascade.
pub fn decide_floor(score: f32, escalate_on_empty: bool) -> FloorOutcome {
    if score >= ConfidenceFloor::T1.threshold() {
        FloorOutcome::Accepted(ConfidenceFloor::T1)
    } else if score >= ConfidenceFloor::T2.threshold() {
        FloorOutcome::Accepted(ConfidenceFloor::T2)
    } else if score >= ConfidenceFloor::T3.threshold() {
        FloorOutcome::Accepted(ConfidenceFloor::T3)
    } else if escalate_on_empty {
        FloorOutcome::Escalated
    } else {
        FloorOutcome::EmptyNoEscalate
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn thresholds_are_the_doctrine_floors() {
        assert_eq!(ConfidenceFloor::T1.threshold(), 0.85);
        assert_eq!(ConfidenceFloor::T2.threshold(), 0.75);
        assert_eq!(ConfidenceFloor::T3.threshold(), 0.70);
        // Strictly descending.
        assert!(ConfidenceFloor::T1.threshold() > ConfidenceFloor::T2.threshold());
        assert!(ConfidenceFloor::T2.threshold() > ConfidenceFloor::T3.threshold());
    }

    #[test]
    fn cascade_accepts_at_the_first_cleared_floor() {
        assert_eq!(
            decide_floor(0.90, false),
            FloorOutcome::Accepted(ConfidenceFloor::T1)
        );
        assert_eq!(
            decide_floor(0.80, false),
            FloorOutcome::Accepted(ConfidenceFloor::T2)
        );
        assert_eq!(
            decide_floor(0.72, false),
            FloorOutcome::Accepted(ConfidenceFloor::T3)
        );
    }

    #[test]
    fn boundary_scores_clear_their_floor_exactly() {
        // `>=` semantics: a score exactly on the floor clears it.
        assert_eq!(
            decide_floor(0.85, false),
            FloorOutcome::Accepted(ConfidenceFloor::T1)
        );
        assert_eq!(
            decide_floor(0.75, false),
            FloorOutcome::Accepted(ConfidenceFloor::T2)
        );
        assert_eq!(
            decide_floor(0.70, false),
            FloorOutcome::Accepted(ConfidenceFloor::T3)
        );
        // Just under the lowest floor falls through.
        assert!(decide_floor(0.6999, false).is_empty_no_escalate());
    }

    #[test]
    fn empty_respects_the_escalate_flag() {
        assert_eq!(decide_floor(0.50, true), FloorOutcome::Escalated);
        assert_eq!(decide_floor(0.50, false), FloorOutcome::EmptyNoEscalate);
    }

    #[test]
    fn exactly_one_predicate_holds_per_outcome() {
        for outcome in [
            FloorOutcome::Accepted(ConfidenceFloor::T1),
            FloorOutcome::Accepted(ConfidenceFloor::T3),
            FloorOutcome::Escalated,
            FloorOutcome::EmptyNoEscalate,
        ] {
            let n = [
                outcome.is_accepted(),
                outcome.is_escalated(),
                outcome.is_empty_no_escalate(),
            ]
            .iter()
            .filter(|b| **b)
            .count();
            assert_eq!(n, 1, "exactly one predicate must hold for {outcome:?}");
            // accepted_at_tier is Some iff is_accepted.
            assert_eq!(outcome.accepted_at_tier().is_some(), outcome.is_accepted());
        }
    }

    #[test]
    fn floor_codes_round_trip() {
        for f in ConfidenceFloor::ALL {
            assert_eq!(ConfidenceFloor::from_code(f.code()), Some(f));
        }
        assert_eq!(ConfidenceFloor::from_code("nope"), None);
    }
}
