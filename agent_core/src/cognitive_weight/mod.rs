//! Cognitive Weight Class — typed seam for the 4-tier system.
//!
//! Doctrine: `docs/fusion/COGNITIVE_WEIGHT_CLASS_DOCTRINE_2026_05_04.md`
//! Source: `docs/fusion/research/FINAL_SYNTHESIS.md` §3.
//!
//! The four-tier class system distinguishes Semantic Gravity (which
//! documents pull attention) from Policy Authority (which documents
//! constrain action). Conflating these is the "old file accidentally
//! too powerful" failure mode FINAL_SYNTHESIS §3 warns against.
//!
//! **Semantic Gravity pulls attention; Policy Authority controls action;
//! do not confuse the two.**

use serde::{Deserialize, Serialize};

/// The four canonical classes from FINAL_SYNTHESIS §3 / doctrine §2.
/// Numeric ranges are normative — they tile [0, 1] without gaps or
/// overlap.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum CognitiveWeightClass {
    /// 0.00–0.30 · trailing context · no policy authority
    Soft,
    /// 0.31–0.60 · inline context · no policy authority
    Preferred,
    /// 0.61–0.85 · above-fold context · advisory (UI hint only)
    StrongAnchor,
    /// 0.86–1.00 · immutable system context · ENFORCED policy authority
    /// (gates tools — but ONLY after the §3 five gates clear AND
    /// `signed_plan_hash` validates)
    PolicyGrade,
}

/// Where in the rendered context window a class lands.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ContextPlacement {
    /// Soft memory — bottom of the context window
    Trailing,
    /// Preferred context — inline at relevance order
    Inline,
    /// Strong anchor — above the fold (top of context)
    AboveFold,
    /// Policy-grade — immutable system block, never displaced
    ImmutableSystem,
}

/// Per-document cognitive weight. Carries enough metadata for the
/// retrieval surface (RRF / Halo) to apply boost AND for the policy
/// surface (Sovereign Gate) to check authority. The `policy_authority`
/// boolean is GUARDED — even setting it to true requires `class ==
/// PolicyGrade` AND a valid `signed_plan_hash` per the doctrine §3
/// gates.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct CognitiveWeight {
    /// The provider's raw weight, in [0, 1]. Source of truth from
    /// which `class` is derived. Kept for audit.
    pub raw_score: f32,
    /// Derived from `raw_score` per doctrine §2 table.
    pub class: CognitiveWeightClass,
    /// Only `PolicyGrade` may be true; even then must be confirmed
    /// by `signed_plan_hash` before honored.
    pub policy_authority: bool,
    /// Bounded by `class` per doctrine §2 retrieval-priority column.
    pub retrieval_priority_boost: f32,
    /// Bounded by `class` per doctrine §2 context-placement column.
    pub context_placement: ContextPlacement,
}

impl Default for CognitiveWeight {
    fn default() -> Self {
        Self::from_raw_score(0.0)
    }
}

impl CognitiveWeight {
    /// Deterministic mapping from a raw [0, 1] score to a fully-
    /// populated weight. `policy_authority` always starts false; it
    /// must be promoted via the doctrine §3 five gates.
    pub fn from_raw_score(raw_score: f32) -> Self {
        let raw = raw_score.clamp(0.0, 1.0);
        let class = Self::classify(raw);
        let (boost, placement) = Self::bias_for_class(class);
        Self {
            raw_score: raw,
            class,
            policy_authority: false,
            retrieval_priority_boost: boost,
            context_placement: placement,
        }
    }

    /// Per-table classification. Maps score to class per doctrine §2.
    pub fn classify(raw: f32) -> CognitiveWeightClass {
        match raw.clamp(0.0, 1.0) {
            r if r <= 0.30 => CognitiveWeightClass::Soft,
            r if r <= 0.60 => CognitiveWeightClass::Preferred,
            r if r <= 0.85 => CognitiveWeightClass::StrongAnchor,
            _ => CognitiveWeightClass::PolicyGrade,
        }
    }

    /// Returns the canonical retrieval-priority boost + context
    /// placement for a class. Boost values are the midpoint of the
    /// doctrine §2 retrieval-priority range so different scores
    /// within the same class produce identical biases (which is the
    /// intended behavior — class is the unit of retrieval-priority
    /// distinction, not raw score).
    pub fn bias_for_class(class: CognitiveWeightClass) -> (f32, ContextPlacement) {
        match class {
            CognitiveWeightClass::Soft => (0.05, ContextPlacement::Trailing),
            CognitiveWeightClass::Preferred => (0.20, ContextPlacement::Inline),
            CognitiveWeightClass::StrongAnchor => (0.45, ContextPlacement::AboveFold),
            CognitiveWeightClass::PolicyGrade => (0.80, ContextPlacement::ImmutableSystem),
        }
    }

    /// THE policy authority gate. Returns true ONLY if all three:
    /// - `class == PolicyGrade`
    /// - `policy_authority == true` (must be explicitly promoted)
    /// - `signed_plan_hash.is_some()` (a valid LivePlan signature
    ///   exists; the runtime never honors unsigned policy authority)
    ///
    /// Anything less and the document is treated as advisory at most.
    /// This is the §3.1 boundary in code: Semantic Gravity surfaces
    /// (retrieval) read `class` directly; only this method gates
    /// Policy Authority.
    pub fn can_constrain_tools(&self, signed_plan_hash: Option<&[u8; 32]>) -> bool {
        self.class == CognitiveWeightClass::PolicyGrade
            && self.policy_authority
            && signed_plan_hash.is_some()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn classify_honors_doctrine_table_boundaries() {
        // Tile boundaries from doctrine §2 — boundary scores fall to
        // the LOWER class (the table reads "0.00–0.30" inclusive).
        assert_eq!(CognitiveWeight::classify(0.0), CognitiveWeightClass::Soft);
        assert_eq!(CognitiveWeight::classify(0.30), CognitiveWeightClass::Soft);
        assert_eq!(
            CognitiveWeight::classify(0.31),
            CognitiveWeightClass::Preferred
        );
        assert_eq!(
            CognitiveWeight::classify(0.60),
            CognitiveWeightClass::Preferred
        );
        assert_eq!(
            CognitiveWeight::classify(0.61),
            CognitiveWeightClass::StrongAnchor
        );
        assert_eq!(
            CognitiveWeight::classify(0.85),
            CognitiveWeightClass::StrongAnchor
        );
        assert_eq!(
            CognitiveWeight::classify(0.86),
            CognitiveWeightClass::PolicyGrade
        );
        assert_eq!(
            CognitiveWeight::classify(1.0),
            CognitiveWeightClass::PolicyGrade
        );
    }

    #[test]
    fn from_raw_score_default_is_soft_with_no_authority() {
        let w = CognitiveWeight::default();
        assert_eq!(w.class, CognitiveWeightClass::Soft);
        assert!(!w.policy_authority);
        assert_eq!(w.context_placement, ContextPlacement::Trailing);
    }

    #[test]
    fn policy_authority_starts_false_even_for_policy_grade_score() {
        // §3 contract: policy_authority must be EXPLICITLY promoted via
        // the five gates. Constructing a 0.95-score weight does NOT
        // grant authority.
        let w = CognitiveWeight::from_raw_score(0.95);
        assert_eq!(w.class, CognitiveWeightClass::PolicyGrade);
        assert!(
            !w.policy_authority,
            "authority must be opted in via §3 gates"
        );
    }

    #[test]
    fn can_constrain_tools_requires_all_three_conditions() {
        let mut w = CognitiveWeight::from_raw_score(0.95);
        let sig = [0u8; 32];

        // Fresh policy_grade with no authority + no sig: no
        assert!(!w.can_constrain_tools(Some(&sig)));
        assert!(!w.can_constrain_tools(None));

        // Authority opted in but no sig: no
        w.policy_authority = true;
        assert!(!w.can_constrain_tools(None));

        // Authority opted in AND sig present: YES
        assert!(w.can_constrain_tools(Some(&sig)));

        // Wrong class, even with authority + sig: no
        let mut w2 = CognitiveWeight::from_raw_score(0.5);
        w2.policy_authority = true;
        assert!(!w2.can_constrain_tools(Some(&sig)));
    }

    #[test]
    fn bias_for_each_class_is_within_doctrine_range() {
        // §2 retrieval-priority columns:
        //   Soft: 0–10% → 0.05 midpoint
        //   Preferred: 10–30% → 0.20
        //   StrongAnchor: 30–60% → 0.45
        //   PolicyGrade: 60–100% → 0.80
        for (class, (low, high)) in [
            (CognitiveWeightClass::Soft, (0.00, 0.10)),
            (CognitiveWeightClass::Preferred, (0.10, 0.30)),
            (CognitiveWeightClass::StrongAnchor, (0.30, 0.60)),
            (CognitiveWeightClass::PolicyGrade, (0.60, 1.00)),
        ] {
            let (boost, _placement) = CognitiveWeight::bias_for_class(class);
            assert!(
                boost >= low && boost <= high,
                "boost for {:?} = {} outside doctrine range [{},{}]",
                class,
                boost,
                low,
                high
            );
        }
    }

    #[test]
    fn placement_matches_doctrine_per_class() {
        assert_eq!(
            CognitiveWeight::bias_for_class(CognitiveWeightClass::Soft).1,
            ContextPlacement::Trailing
        );
        assert_eq!(
            CognitiveWeight::bias_for_class(CognitiveWeightClass::Preferred).1,
            ContextPlacement::Inline
        );
        assert_eq!(
            CognitiveWeight::bias_for_class(CognitiveWeightClass::StrongAnchor).1,
            ContextPlacement::AboveFold
        );
        assert_eq!(
            CognitiveWeight::bias_for_class(CognitiveWeightClass::PolicyGrade).1,
            ContextPlacement::ImmutableSystem
        );
    }

    #[test]
    fn weight_round_trips_through_json() {
        let mut w = CognitiveWeight::from_raw_score(0.7);
        w.policy_authority = false; // strong_anchor never has authority
        let encoded = serde_json::to_string(&w).expect("encode");
        let decoded: CognitiveWeight = serde_json::from_str(&encoded).expect("decode");
        assert_eq!(w, decoded);
    }
}
