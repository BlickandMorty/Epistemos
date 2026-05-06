//! HELIOS V5 → V6 → V6.1 — V6.1 Final Synthesis Lock substrate (Lane 3).
//!
//! HELIOS-V6_1 guard
//!
//! Per `docs/fusion/Epistemos V6_1 — Final Synthesis Lock (Attention as Interrupt).pdf`
//! ("Final Synthesis Lock", May 2026):
//!
//! > "Five lanes, three tiers, seven-plus-three-plus-seven, one
//! >  Monday — one plan, three streams, three users — hybrid-SSM,
//! >  parameter-connectome, Heavy-Thinking, vectorless-retrieval,
//! >  brain-inspired, App-Store-native — and the floor never moves —
//! >  and **attention is an interrupt, not a substrate.**"
//!
//! V6.1 is a STRICT SHARPENING of V6, not a re-architecture. V5 and
//! V6 locks are preserved VERBATIM. The Verified Floor anchor
//! `ac8c6d28` is immutable and carries forward.
//!
//! ## The deepest reframing of the V5 → V6 → V6.1 arc
//!
//! **Attention is reframed as an INTERRUPT, not a SUBSTRATE.** This
//! is the only doctrinal change the present substrate captures with
//! certainty from the title-page extract; the remaining four
//! sharpening points and the per-stream details are document-level
//! and land in the canonical V6.1 doctrine prose, not the type
//! system here.
//!
//! ## §2.5.2 compliance posture
//!
//! Lane 3 RESEARCH-ONLY. Building requires `--features research`.
//!
//! ## Cross-references
//!
//! - V5 source canon: `docs/fusion/helios v5 first.md` +
//!   `docs/fusion/helios v5 updated.md`
//! - V6.1 lock: `docs/fusion/Epistemos V6_1 — Final Synthesis Lock
//!   (Attention as Interrupt).pdf`
//! - Verified Floor: commit `ac8c6d28` (immutable carry-forward)

use serde::{Deserialize, Serialize};

/// V6.1 canonical anchor — the immutable Verified Floor commit.
///
/// Per V6.1 lock TL;DR: "the floor never moves." Any change to this
/// constant is a CANON VIOLATION and must be flagged HALT-class.
pub const VERIFIED_FLOOR_ANCHOR: &str = "ac8c6d28";

/// Attention-mechanism mode per the V6.1 reframing.
///
/// V6.1 §1 (Sharpening Point 1): "Attention is reframed as an
/// **interrupt**, not a substrate. This is the deepest reframing
/// in the entire V5 → V6 → V6.1 arc."
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum AttentionMode {
    /// V6.1 canonical: attention is an event-driven interrupt
    /// mechanism that fires when the SSM/state-space substrate
    /// requests it. NOT a primary computational substrate.
    Interrupt,
    /// V5 / V6 framing: attention as the primary substrate. This
    /// arm is preserved verbatim per the V5/V6 locks but is
    /// **superseded** by `Interrupt` in V6.1.
    Substrate,
}

impl AttentionMode {
    /// V6.1 canonical mode. New work that lands after the V6.1
    /// lock should use this default.
    pub const V6_1_CANONICAL: AttentionMode = AttentionMode::Interrupt;

    /// Returns true when this mode is the V6.1 canonical reframing.
    pub fn is_v6_1_canonical(self) -> bool {
        matches!(self, AttentionMode::Interrupt)
    }
}

impl Default for AttentionMode {
    fn default() -> Self {
        Self::V6_1_CANONICAL
    }
}

/// One of the four canonical locks in the V5 → V6.1 arc.
///
/// Per V6.1 TL;DR: "V5 lock: preserved verbatim. V6 lock: preserved
/// verbatim. V6.1: strict sharpening." All four locks are valid
/// reference points; V6.1 is the latest, but V5 and V6 are NOT
/// retired — every claim that survived their lock is still load-
/// bearing.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum CanonLock {
    /// V5 lock — preserved verbatim. The substrate this crate ships.
    V5,
    /// V6 lock — preserved verbatim. Layered between V5 and V6.1.
    V6,
    /// V6.1 lock — strict sharpening. Current canonical reframing.
    V6_1,
    /// Verified Floor anchor (immutable commit `ac8c6d28`). NOT a
    /// per-version lock — the floor that all other locks build on.
    VerifiedFloor,
}

/// The six doctrinal keywords from the V6.1 title-page slogan.
/// Each names a load-bearing axis of the V6.1 synthesis.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum V6_1Axis {
    /// Hybrid state-space + transformer SSM stack.
    HybridSsm,
    /// Parameter connectome — the SPD/APD-style decomposition
    /// substrate (PCF-1..PCF-8 family).
    ParameterConnectome,
    /// Heavy-Thinking — extended-deliberation tier.
    HeavyThinking,
    /// Vectorless retrieval — retrieval without embedding-vector
    /// indices; cf. ASA / Atlas / sparse-feature paths.
    VectorlessRetrieval,
    /// Brain-inspired topology (basal ganglia / PFC / amygdala
    /// design patterns from CMS v2 §Part III).
    BrainInspired,
    /// App-Store-native distribution — MAS-shippable build.
    AppStoreNative,
}

/// All four canon locks in the V5 → V6.1 arc.
pub const ALL_LOCKS: [CanonLock; 4] = [
    CanonLock::V5,
    CanonLock::V6,
    CanonLock::V6_1,
    CanonLock::VerifiedFloor,
];

/// All six doctrinal axes from the V6.1 slogan.
pub const ALL_AXES: [V6_1Axis; 6] = [
    V6_1Axis::HybridSsm,
    V6_1Axis::ParameterConnectome,
    V6_1Axis::HeavyThinking,
    V6_1Axis::VectorlessRetrieval,
    V6_1Axis::BrainInspired,
    V6_1Axis::AppStoreNative,
];

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn verified_floor_anchor_is_ac8c6d28() {
        // The floor never moves. Any change to this constant is a
        // canon violation per the V6.1 lock.
        assert_eq!(VERIFIED_FLOOR_ANCHOR, "ac8c6d28");
    }

    #[test]
    fn attention_canonical_v6_1_mode_is_interrupt() {
        // The deepest reframing of the V5 → V6 → V6.1 arc.
        assert_eq!(AttentionMode::V6_1_CANONICAL, AttentionMode::Interrupt);
    }

    #[test]
    fn attention_default_is_v6_1_canonical() {
        let default: AttentionMode = AttentionMode::default();
        assert!(default.is_v6_1_canonical());
    }

    #[test]
    fn substrate_mode_is_not_v6_1_canonical() {
        // V5 / V6 framing preserved but superseded.
        assert!(!AttentionMode::Substrate.is_v6_1_canonical());
    }

    #[test]
    fn four_canon_locks_are_distinct() {
        let set: std::collections::HashSet<CanonLock> =
            ALL_LOCKS.iter().copied().collect();
        assert_eq!(set.len(), 4);
    }

    #[test]
    fn six_v6_1_axes_are_distinct() {
        let set: std::collections::HashSet<V6_1Axis> =
            ALL_AXES.iter().copied().collect();
        assert_eq!(set.len(), 6);
    }

    #[test]
    fn attention_mode_serializes_in_snake_case() {
        assert_eq!(
            serde_json::to_string(&AttentionMode::Interrupt).unwrap(),
            "\"interrupt\""
        );
        assert_eq!(
            serde_json::to_string(&AttentionMode::Substrate).unwrap(),
            "\"substrate\""
        );
    }

    #[test]
    fn canon_lock_serializes_in_snake_case() {
        for (lock, expected) in [
            (CanonLock::V5, "\"v5\""),
            (CanonLock::V6, "\"v6\""),
            (CanonLock::V6_1, "\"v6_1\""),
            (CanonLock::VerifiedFloor, "\"verified_floor\""),
        ] {
            assert_eq!(serde_json::to_string(&lock).unwrap(), expected);
        }
    }

    #[test]
    fn axis_serializes_in_snake_case() {
        for (axis, expected) in [
            (V6_1Axis::HybridSsm, "\"hybrid_ssm\""),
            (V6_1Axis::ParameterConnectome, "\"parameter_connectome\""),
            (V6_1Axis::HeavyThinking, "\"heavy_thinking\""),
            (V6_1Axis::VectorlessRetrieval, "\"vectorless_retrieval\""),
            (V6_1Axis::BrainInspired, "\"brain_inspired\""),
            (V6_1Axis::AppStoreNative, "\"app_store_native\""),
        ] {
            assert_eq!(serde_json::to_string(&axis).unwrap(), expected);
        }
    }

    #[test]
    fn all_three_enums_round_trip_through_json() {
        for mode in [AttentionMode::Interrupt, AttentionMode::Substrate] {
            let json = serde_json::to_string(&mode).unwrap();
            let parsed: AttentionMode = serde_json::from_str(&json).unwrap();
            assert_eq!(parsed, mode);
        }
        for lock in ALL_LOCKS {
            let json = serde_json::to_string(&lock).unwrap();
            let parsed: CanonLock = serde_json::from_str(&json).unwrap();
            assert_eq!(parsed, lock);
        }
        for axis in ALL_AXES {
            let json = serde_json::to_string(&axis).unwrap();
            let parsed: V6_1Axis = serde_json::from_str(&json).unwrap();
            assert_eq!(parsed, axis);
        }
    }

    #[test]
    fn verified_floor_anchor_is_8_hex_chars() {
        // Sanity: ac8c6d28 is exactly 8 lowercase-hex characters
        // (matching the standard short-SHA convention).
        assert_eq!(VERIFIED_FLOOR_ANCHOR.len(), 8);
        assert!(VERIFIED_FLOOR_ANCHOR
            .chars()
            .all(|c| c.is_ascii_hexdigit() && (!c.is_ascii_alphabetic() || c.is_ascii_lowercase())));
    }
}
