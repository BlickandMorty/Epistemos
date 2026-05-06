//! HELIOS V5 — Learning modes + direction taxonomy (Lane 3 RESEARCH-ONLY).
//!
//! HELIOS-LEARNING-MODES guard
//!
//! Per HELIOS v4 preservation `source_docs/epistenos_build_prompt.md`
//! §2.1 (`helios-core::types` canonical type lists):
//!
//! - `LearningMode` enum: Freeze, FastWeight, LoRA, Sketch
//! - `Direction` enum: Upward, Downward, Sideways, Inward,
//!   OnItself, None
//!
//! These two enums are part of the canonical helios-core types
//! list per the build-prompt §2.1.
//!
//! ## §2.5.2 compliance posture
//!
//! Lane 3 RESEARCH-ONLY. Building requires `--features research`.

use serde::{Deserialize, Serialize};

/// One of four canonical learning modes per the helios-core
/// canonical types list.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum LearningMode {
    /// Freeze — no parameter updates. Base model stays immutable.
    Freeze,
    /// FastWeight — `W_fast += η · z_pre ⊗ z_post` per the
    /// fast-weight programmer family. Per-session, transient.
    FastWeight,
    /// LoRA — orthogonal adapter (QOFT / O-LoRA), EWC-protected.
    /// Per-domain, persistent.
    LoRa,
    /// Sketch — CountSketch gradient memory; permanent record of
    /// all conversation gradients (always-record).
    Sketch,
}

impl LearningMode {
    /// True when this mode produces NO parameter updates
    /// (Freeze only).
    pub fn is_frozen(self) -> bool {
        matches!(self, LearningMode::Freeze)
    }

    /// True when this mode persists state across sessions
    /// (LoRA + Sketch).
    pub fn is_persistent(self) -> bool {
        matches!(self, LearningMode::LoRa | LearningMode::Sketch)
    }
}

/// One of six canonical directions per the helios-core canonical
/// types list. Used by the δ-direction component of the
/// Σ-signature (Pro tier per scope_rex/delta.rs).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Direction {
    /// Upward — escalation toward higher residency tier or
    /// stronger evidence.
    Upward,
    /// Downward — demotion toward lower residency tier or
    /// weaker evidence.
    Downward,
    /// Sideways — lateral motion within the same tier.
    Sideways,
    /// Inward — recursion into a deeper sub-claim.
    Inward,
    /// OnItself — self-referential / fixed point.
    OnItself,
    /// None — no direction (used as the absence-of-motion default).
    None,
}

impl Direction {
    /// True when the direction is purely vertical (Upward or
    /// Downward).
    pub fn is_vertical(self) -> bool {
        matches!(self, Direction::Upward | Direction::Downward)
    }

    /// True when the direction has zero net motion (None or OnItself).
    pub fn has_zero_displacement(self) -> bool {
        matches!(self, Direction::None | Direction::OnItself)
    }
}

/// All four learning modes in canonical doctrine order.
pub const FOUR_LEARNING_MODES: [LearningMode; 4] = [
    LearningMode::Freeze,
    LearningMode::FastWeight,
    LearningMode::LoRa,
    LearningMode::Sketch,
];

/// All six directions in canonical doctrine order.
pub const SIX_DIRECTIONS: [Direction; 6] = [
    Direction::Upward,
    Direction::Downward,
    Direction::Sideways,
    Direction::Inward,
    Direction::OnItself,
    Direction::None,
];

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn four_learning_modes_in_canonical_order() {
        assert_eq!(FOUR_LEARNING_MODES.len(), 4);
        assert_eq!(FOUR_LEARNING_MODES[0], LearningMode::Freeze);
        assert_eq!(FOUR_LEARNING_MODES[3], LearningMode::Sketch);
    }

    #[test]
    fn four_learning_modes_are_distinct() {
        let set: std::collections::HashSet<LearningMode> =
            FOUR_LEARNING_MODES.iter().copied().collect();
        assert_eq!(set.len(), 4);
    }

    #[test]
    fn only_freeze_is_frozen() {
        for mode in FOUR_LEARNING_MODES {
            if mode == LearningMode::Freeze {
                assert!(mode.is_frozen());
            } else {
                assert!(!mode.is_frozen());
            }
        }
    }

    #[test]
    fn lora_and_sketch_are_persistent() {
        assert!(LearningMode::LoRa.is_persistent());
        assert!(LearningMode::Sketch.is_persistent());
        assert!(!LearningMode::Freeze.is_persistent());
        assert!(!LearningMode::FastWeight.is_persistent());
    }

    #[test]
    fn six_directions_in_canonical_order() {
        assert_eq!(SIX_DIRECTIONS.len(), 6);
        assert_eq!(SIX_DIRECTIONS[0], Direction::Upward);
        assert_eq!(SIX_DIRECTIONS[5], Direction::None);
    }

    #[test]
    fn six_directions_are_distinct() {
        let set: std::collections::HashSet<Direction> = SIX_DIRECTIONS.iter().copied().collect();
        assert_eq!(set.len(), 6);
    }

    #[test]
    fn upward_and_downward_are_vertical() {
        assert!(Direction::Upward.is_vertical());
        assert!(Direction::Downward.is_vertical());
        for d in [Direction::Sideways, Direction::Inward, Direction::OnItself, Direction::None] {
            assert!(!d.is_vertical());
        }
    }

    #[test]
    fn none_and_on_itself_have_zero_displacement() {
        assert!(Direction::None.has_zero_displacement());
        assert!(Direction::OnItself.has_zero_displacement());
        for d in [Direction::Upward, Direction::Downward, Direction::Sideways, Direction::Inward] {
            assert!(!d.has_zero_displacement());
        }
    }

    #[test]
    fn learning_mode_serializes_in_snake_case() {
        for (mode, expected) in [
            (LearningMode::Freeze, "\"freeze\""),
            (LearningMode::FastWeight, "\"fast_weight\""),
            (LearningMode::LoRa, "\"lo_ra\""),
            (LearningMode::Sketch, "\"sketch\""),
        ] {
            assert_eq!(serde_json::to_string(&mode).unwrap(), expected);
        }
    }

    #[test]
    fn direction_serializes_in_snake_case() {
        for (direction, expected) in [
            (Direction::Upward, "\"upward\""),
            (Direction::Downward, "\"downward\""),
            (Direction::Sideways, "\"sideways\""),
            (Direction::Inward, "\"inward\""),
            (Direction::OnItself, "\"on_itself\""),
            (Direction::None, "\"none\""),
        ] {
            assert_eq!(serde_json::to_string(&direction).unwrap(), expected);
        }
    }

    #[test]
    fn round_trip_through_json() {
        for mode in FOUR_LEARNING_MODES {
            let json = serde_json::to_string(&mode).unwrap();
            let parsed: LearningMode = serde_json::from_str(&json).unwrap();
            assert_eq!(parsed, mode);
        }
        for direction in SIX_DIRECTIONS {
            let json = serde_json::to_string(&direction).unwrap();
            let parsed: Direction = serde_json::from_str(&json).unwrap();
            assert_eq!(parsed, direction);
        }
    }

    #[test]
    fn vertical_and_zero_displacement_are_disjoint() {
        for d in SIX_DIRECTIONS {
            // Vertical and zero-displacement should not overlap.
            assert!(!(d.is_vertical() && d.has_zero_displacement()));
        }
    }
}
