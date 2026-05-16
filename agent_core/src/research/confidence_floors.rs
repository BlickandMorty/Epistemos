//! Source:
//! - `docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_B_2026_05_16.md`
//!   §5 Phase B.6.9 — Confidence floors + flags. FLOOR_T1 (≥0.85) /
//!   FLOOR_T2 (≥0.75) / FLOOR_T3 (≥0.70). `escalate_on_empty` flag
//!   (default false). LadderLog → Provenance Console wiring.
//!
//! # Wave J B.6.9 — Confidence-floor ladder substrate
//!
//! Each tier has a hard confidence floor. A score that doesn't clear
//! the floor either:
//! - cascades down to the next-lower tier, OR
//! - if `escalate_on_empty` is set AND no tier accepts, escalates to
//!   a human / external check.
//!
//! Substrate floor: the three tier thresholds + the
//! [`ConfidenceLadderLog`] that records every per-attempt decision so
//! the Provenance Console can render the cascade.

use serde::{Deserialize, Serialize};

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize)]
pub enum ConfidenceFloor {
    T1,
    T2,
    T3,
}

impl ConfidenceFloor {
    pub const ALL: [ConfidenceFloor; 3] =
        [ConfidenceFloor::T1, ConfidenceFloor::T2, ConfidenceFloor::T3];

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
}

#[derive(Clone, Copy, Debug, PartialEq, Serialize, Deserialize)]
pub enum LadderDecision {
    Accepted(ConfidenceFloor),
    Escalated,
    EmptyNoEscalate,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct LadderLogEntry {
    pub score: f32,
    pub decision: LadderDecision,
    pub escalate_on_empty: bool,
}

#[derive(Clone, Debug, PartialEq, Default, Serialize, Deserialize)]
pub struct ConfidenceLadderLog {
    pub entries: Vec<LadderLogEntry>,
}

impl ConfidenceLadderLog {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn len(&self) -> usize {
        self.entries.len()
    }

    pub fn is_empty(&self) -> bool {
        self.entries.is_empty()
    }

    /// Walk the floors T1 → T2 → T3; accept at first floor where
    /// score ≥ floor.threshold(). If none accept and
    /// `escalate_on_empty` is set, return Escalated; otherwise
    /// EmptyNoEscalate. Returns the decision and appends a log entry.
    pub fn decide(
        &mut self,
        score: f32,
        escalate_on_empty: bool,
    ) -> LadderDecision {
        let decision = if score >= ConfidenceFloor::T1.threshold() {
            LadderDecision::Accepted(ConfidenceFloor::T1)
        } else if score >= ConfidenceFloor::T2.threshold() {
            LadderDecision::Accepted(ConfidenceFloor::T2)
        } else if score >= ConfidenceFloor::T3.threshold() {
            LadderDecision::Accepted(ConfidenceFloor::T3)
        } else if escalate_on_empty {
            LadderDecision::Escalated
        } else {
            LadderDecision::EmptyNoEscalate
        };
        self.entries.push(LadderLogEntry { score, decision, escalate_on_empty });
        decision
    }

    pub fn count_by_decision(&self) -> std::collections::BTreeMap<&'static str, usize> {
        let mut m = std::collections::BTreeMap::new();
        for e in &self.entries {
            let key = match e.decision {
                LadderDecision::Accepted(ConfidenceFloor::T1) => "T1",
                LadderDecision::Accepted(ConfidenceFloor::T2) => "T2",
                LadderDecision::Accepted(ConfidenceFloor::T3) => "T3",
                LadderDecision::Escalated => "Escalated",
                LadderDecision::EmptyNoEscalate => "EmptyNoEscalate",
            };
            *m.entry(key).or_insert(0) += 1;
        }
        m
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn three_distinct_floors() {
        let s: std::collections::HashSet<_> = ConfidenceFloor::ALL.iter().copied().collect();
        assert_eq!(s.len(), 3);
    }

    #[test]
    fn floor_thresholds_match_doctrine() {
        assert_eq!(ConfidenceFloor::T1.threshold(), 0.85);
        assert_eq!(ConfidenceFloor::T2.threshold(), 0.75);
        assert_eq!(ConfidenceFloor::T3.threshold(), 0.70);
    }

    #[test]
    fn floor_codes_stable() {
        assert_eq!(ConfidenceFloor::T1.code(), "T1");
        assert_eq!(ConfidenceFloor::T2.code(), "T2");
        assert_eq!(ConfidenceFloor::T3.code(), "T3");
    }

    #[test]
    fn high_score_accepts_at_t1() {
        let mut log = ConfidenceLadderLog::new();
        let d = log.decide(0.95, false);
        assert_eq!(d, LadderDecision::Accepted(ConfidenceFloor::T1));
    }

    #[test]
    fn mid_score_accepts_at_t2() {
        let mut log = ConfidenceLadderLog::new();
        let d = log.decide(0.80, false);
        assert_eq!(d, LadderDecision::Accepted(ConfidenceFloor::T2));
    }

    #[test]
    fn low_score_accepts_at_t3() {
        let mut log = ConfidenceLadderLog::new();
        let d = log.decide(0.71, false);
        assert_eq!(d, LadderDecision::Accepted(ConfidenceFloor::T3));
    }

    #[test]
    fn below_t3_with_escalate_false_returns_empty_no_escalate() {
        let mut log = ConfidenceLadderLog::new();
        let d = log.decide(0.5, false);
        assert_eq!(d, LadderDecision::EmptyNoEscalate);
    }

    #[test]
    fn below_t3_with_escalate_true_returns_escalated() {
        let mut log = ConfidenceLadderLog::new();
        let d = log.decide(0.5, true);
        assert_eq!(d, LadderDecision::Escalated);
    }

    #[test]
    fn exact_threshold_accepts_at_that_tier() {
        let mut log = ConfidenceLadderLog::new();
        assert_eq!(log.decide(0.85, false), LadderDecision::Accepted(ConfidenceFloor::T1));
        assert_eq!(log.decide(0.75, false), LadderDecision::Accepted(ConfidenceFloor::T2));
        assert_eq!(log.decide(0.70, false), LadderDecision::Accepted(ConfidenceFloor::T3));
    }

    #[test]
    fn log_records_each_decision() {
        let mut log = ConfidenceLadderLog::new();
        log.decide(0.95, false);
        log.decide(0.5, true);
        assert_eq!(log.len(), 2);
        assert!(matches!(log.entries[0].decision, LadderDecision::Accepted(ConfidenceFloor::T1)));
        assert_eq!(log.entries[1].decision, LadderDecision::Escalated);
    }

    #[test]
    fn count_by_decision_groups_correctly() {
        let mut log = ConfidenceLadderLog::new();
        log.decide(0.95, false);
        log.decide(0.95, false);
        log.decide(0.80, false);
        log.decide(0.5, true);
        let counts = log.count_by_decision();
        assert_eq!(counts.get("T1"), Some(&2));
        assert_eq!(counts.get("T2"), Some(&1));
        assert_eq!(counts.get("Escalated"), Some(&1));
        assert_eq!(counts.get("T3"), None);
    }

    #[test]
    fn empty_log_is_empty() {
        let log = ConfidenceLadderLog::new();
        assert!(log.is_empty());
    }

    #[test]
    fn log_roundtrips_through_serde_json() {
        let mut log = ConfidenceLadderLog::new();
        log.decide(0.95, false);
        log.decide(0.5, true);
        let json = serde_json::to_string(&log).unwrap();
        let back: ConfidenceLadderLog = serde_json::from_str(&json).unwrap();
        assert_eq!(log, back);
    }

    #[test]
    fn floor_serializes_through_serde_json() {
        let f = ConfidenceFloor::T2;
        let json = serde_json::to_string(&f).unwrap();
        let back: ConfidenceFloor = serde_json::from_str(&json).unwrap();
        assert_eq!(f, back);
    }
}
