//! HELIOS V5 — Lane 4 physical-falsifier verdict format
//! (Lane 3 RESEARCH-ONLY metadata about Lane 4 experiments).
//!
//! HELIOS-LANE4-FALSIFIER guard
//!
//! Per `docs/fusion/helios v5 first.md` DOC 4 §4.5 (Physical
//! falsifier verdict format):
//!
//! ```text
//! {
//!   experiment:           BZ | Sandpile | Other,
//!   hypothesis:           T_id,
//!   predicted:            range,
//!   observed:             range,
//!   verdict:              Confirms | Falsifies | Inconclusive,
//!   video_anchor:         Sha256,
//!   lab_notebook_anchor:  Sha256
//! }
//! ```
//!
//! ## Lane-promotion rules
//!
//! - Lane 4 → Lane 5 (vault) on `Falsifies`
//! - Lane 5 → Lane 3 (research) on `Confirms`
//! - Lane stays put on `Inconclusive`
//!
//! Lane 4 is Substrate-Independent — physical experiments
//! (Belousov-Zhabotinsky, sandpile self-organized criticality,
//! Julia oracle) intended to falsify substrate-equivalence
//! claims. NEVER product; lives only in the Pro/Research
//! distribution channels per H10.
//!
//! ## §2.5.2 compliance posture
//!
//! Lane 3 RESEARCH-ONLY substrate. Building requires `--features
//! research`. The Lane 4 experiments themselves NEVER ship in MAS
//! (Julia interpreter would violate App Review §2.5.2).

use serde::{Deserialize, Serialize};

/// Physical experiment kind per DOC 4 §4.5.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum PhysicalExperiment {
    /// Belousov-Zhabotinsky reaction (Adamatzky et al. arXiv:0902.0587,
    /// 1009.2044; Tsompanas et al. light-sensitive Ru-catalyzed BZ).
    Bz,
    /// Sandpile self-organized criticality (Bak-Tang-Wiesenfeld).
    Sandpile,
    /// Other physical substrate experiment (escape hatch).
    Other,
}

/// Verdict from one Lane 4 physical experiment.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Verdict {
    /// Observed range matches predicted range — substrate
    /// equivalence claim is confirmed at this experiment.
    Confirms,
    /// Observed range falls outside predicted range — claim is
    /// falsified.
    Falsifies,
    /// Observed range is ambiguous; experiment must be re-run
    /// or extended.
    Inconclusive,
}

/// Lane-promotion outcome per the canonical rules in DOC 4 §4.5.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum LanePromotion {
    /// Lane 4 result → Lane 5 vault (on Falsifies).
    L4ToL5Vault,
    /// Lane 5 result → Lane 3 research (on Confirms).
    L5ToL3Research,
    /// Stay put — no promotion (on Inconclusive).
    Stay,
}

/// Apply the canonical Lane 4/5 promotion rule to a verdict.
///
/// Note: this is the OUTGOING-from-Lane-4 rule. The same verdict
/// from Lane 5 promotes to Lane 3 on Confirms. The caller picks
/// the right rule based on which lane the experiment originated
/// in (callers can use `promote_from_lane_4` or
/// `promote_from_lane_5` for clarity).
pub fn promote_from_lane_4(verdict: Verdict) -> LanePromotion {
    match verdict {
        Verdict::Falsifies => LanePromotion::L4ToL5Vault,
        Verdict::Confirms | Verdict::Inconclusive => LanePromotion::Stay,
    }
}

/// Apply the canonical Lane 5 promotion rule.
pub fn promote_from_lane_5(verdict: Verdict) -> LanePromotion {
    match verdict {
        Verdict::Confirms => LanePromotion::L5ToL3Research,
        Verdict::Falsifies | Verdict::Inconclusive => LanePromotion::Stay,
    }
}

/// All three physical experiment kinds.
pub const THREE_EXPERIMENTS: [PhysicalExperiment; 3] = [
    PhysicalExperiment::Bz,
    PhysicalExperiment::Sandpile,
    PhysicalExperiment::Other,
];

/// All three verdict outcomes.
pub const THREE_VERDICTS: [Verdict; 3] =
    [Verdict::Confirms, Verdict::Falsifies, Verdict::Inconclusive];

/// All three lane-promotion outcomes.
pub const THREE_PROMOTIONS: [LanePromotion; 3] = [
    LanePromotion::L4ToL5Vault,
    LanePromotion::L5ToL3Research,
    LanePromotion::Stay,
];

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn three_experiments_are_distinct() {
        let set: std::collections::HashSet<PhysicalExperiment> =
            THREE_EXPERIMENTS.iter().copied().collect();
        assert_eq!(set.len(), 3);
    }

    #[test]
    fn three_verdicts_are_distinct() {
        let set: std::collections::HashSet<Verdict> = THREE_VERDICTS.iter().copied().collect();
        assert_eq!(set.len(), 3);
    }

    #[test]
    fn three_promotions_are_distinct() {
        let set: std::collections::HashSet<LanePromotion> =
            THREE_PROMOTIONS.iter().copied().collect();
        assert_eq!(set.len(), 3);
    }

    #[test]
    fn lane_4_falsifies_promotes_to_l5_vault() {
        assert_eq!(promote_from_lane_4(Verdict::Falsifies), LanePromotion::L4ToL5Vault);
    }

    #[test]
    fn lane_4_confirms_stays_put() {
        assert_eq!(promote_from_lane_4(Verdict::Confirms), LanePromotion::Stay);
    }

    #[test]
    fn lane_4_inconclusive_stays_put() {
        assert_eq!(promote_from_lane_4(Verdict::Inconclusive), LanePromotion::Stay);
    }

    #[test]
    fn lane_5_confirms_promotes_to_l3_research() {
        assert_eq!(promote_from_lane_5(Verdict::Confirms), LanePromotion::L5ToL3Research);
    }

    #[test]
    fn lane_5_falsifies_stays_put() {
        assert_eq!(promote_from_lane_5(Verdict::Falsifies), LanePromotion::Stay);
    }

    #[test]
    fn lane_5_inconclusive_stays_put() {
        assert_eq!(promote_from_lane_5(Verdict::Inconclusive), LanePromotion::Stay);
    }

    #[test]
    fn promotion_rules_are_distinct_across_lanes() {
        // Confirms behaves differently between Lane 4 and Lane 5;
        // Falsifies behaves differently too. Inconclusive is the
        // same (Stay) on both.
        assert_ne!(
            promote_from_lane_4(Verdict::Confirms),
            promote_from_lane_5(Verdict::Confirms)
        );
        assert_ne!(
            promote_from_lane_4(Verdict::Falsifies),
            promote_from_lane_5(Verdict::Falsifies)
        );
        assert_eq!(
            promote_from_lane_4(Verdict::Inconclusive),
            promote_from_lane_5(Verdict::Inconclusive)
        );
    }

    #[test]
    fn experiment_serializes_in_snake_case() {
        for (exp, expected) in [
            (PhysicalExperiment::Bz, "\"bz\""),
            (PhysicalExperiment::Sandpile, "\"sandpile\""),
            (PhysicalExperiment::Other, "\"other\""),
        ] {
            assert_eq!(serde_json::to_string(&exp).unwrap(), expected);
        }
    }

    #[test]
    fn verdict_serializes_in_snake_case() {
        for (v, expected) in [
            (Verdict::Confirms, "\"confirms\""),
            (Verdict::Falsifies, "\"falsifies\""),
            (Verdict::Inconclusive, "\"inconclusive\""),
        ] {
            assert_eq!(serde_json::to_string(&v).unwrap(), expected);
        }
    }

    #[test]
    fn promotion_serializes_in_snake_case() {
        for (p, expected) in [
            (LanePromotion::L4ToL5Vault, "\"l4_to_l5_vault\""),
            (LanePromotion::L5ToL3Research, "\"l5_to_l3_research\""),
            (LanePromotion::Stay, "\"stay\""),
        ] {
            assert_eq!(serde_json::to_string(&p).unwrap(), expected);
        }
    }

    #[test]
    fn round_trip_through_json() {
        for exp in THREE_EXPERIMENTS {
            let json = serde_json::to_string(&exp).unwrap();
            let parsed: PhysicalExperiment = serde_json::from_str(&json).unwrap();
            assert_eq!(parsed, exp);
        }
        for v in THREE_VERDICTS {
            let json = serde_json::to_string(&v).unwrap();
            let parsed: Verdict = serde_json::from_str(&json).unwrap();
            assert_eq!(parsed, v);
        }
        for p in THREE_PROMOTIONS {
            let json = serde_json::to_string(&p).unwrap();
            let parsed: LanePromotion = serde_json::from_str(&json).unwrap();
            assert_eq!(parsed, p);
        }
    }
}
