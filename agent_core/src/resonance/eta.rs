//! HELIOS V5 SCOPE-Rex Research — `η` evidence supremacy.
//!
//! HELIOS-ETA guard
//!
//! Per `docs/HELIOS_V5_INTEGRATION_PLAN_v2_FINALIZE_2026_05_05.md` §G:
//!
//! > "η evidence (evidence-supremacy protocol; flags 'edge' claims
//! >  for VRM) — NEW agent_core/src/resonance/eta.rs (Research)"
//!
//! Research tier substrate. The η signal flags claims sitting on the
//! edge of the verified manifold so the Verified Research Mode UI
//! (W3 / W9) can surface them with the `Plausible-but-unverified`
//! label rather than `Verified`.

use serde::{Deserialize, Serialize};

/// Evidence-supremacy verdict for one claim.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum EvidenceSupremacy {
    /// Strong evidence chain — sufficient to ship as Verified.
    Strong,
    /// Edge claim — evidence is borderline; flag for VRM
    /// PlausibleButUnverified handling.
    Edge,
    /// Weak — fall back to Speculative VRM label.
    Weak,
}

/// Threshold for the `Strong` verdict on an evidence-weight signal.
pub const STRONG_THRESHOLD: f32 = 0.8;
/// Threshold for the `Edge` verdict.
pub const EDGE_THRESHOLD: f32 = 0.5;

/// Compute the η verdict from a normalized evidence-weight signal.
/// `evidence_weight ∈ [0, 1]`.
pub fn eta_classify(evidence_weight: f32) -> EvidenceSupremacy {
    if evidence_weight >= STRONG_THRESHOLD {
        EvidenceSupremacy::Strong
    } else if evidence_weight >= EDGE_THRESHOLD {
        EvidenceSupremacy::Edge
    } else {
        EvidenceSupremacy::Weak
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn strong_threshold_returns_strong() {
        assert_eq!(eta_classify(0.9), EvidenceSupremacy::Strong);
        assert_eq!(eta_classify(0.8), EvidenceSupremacy::Strong);
    }

    #[test]
    fn edge_threshold_returns_edge() {
        assert_eq!(eta_classify(0.7), EvidenceSupremacy::Edge);
        assert_eq!(eta_classify(0.5), EvidenceSupremacy::Edge);
    }

    #[test]
    fn below_edge_returns_weak() {
        assert_eq!(eta_classify(0.4), EvidenceSupremacy::Weak);
        assert_eq!(eta_classify(0.0), EvidenceSupremacy::Weak);
    }

    #[test]
    fn eta_serializes_in_snake_case() {
        for (e, expected) in [
            (EvidenceSupremacy::Strong, "\"strong\""),
            (EvidenceSupremacy::Edge, "\"edge\""),
            (EvidenceSupremacy::Weak, "\"weak\""),
        ] {
            assert_eq!(serde_json::to_string(&e).unwrap(), expected);
        }
    }
}
