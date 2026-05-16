//! Source:
//! - `docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_B_2026_05_16.md`
//!   §5 Phase B.3 G4 — "Hermes Snake as Graph Faculty (z+1 plane;
//!   NOT a Companion-Farm citizen)".
//! - CANONICAL_UNIFICATION_INVENTORY §4.3 — Hermes Snake placement rule.
//! - `docs/fusion/jordan's research/hermes_snake.md` — design doc.
//!
//! # Phase B.3 G4 — Hermes Snake z+1 plane substrate
//!
//! Hermes Snake is structurally distinct from Companion-Farm
//! citizens: it lives on a separate z+1 plane (visually "above" the
//! companion grid) and acts as the Graph Faculty (it weaves between
//! companions, surfacing cross-citizen edges; it is not itself a
//! companion). Substrate floor owns:
//!
//! - [`PlaneZ`] enum: `CompanionFarm` (z=0) vs `Snake` (z=1).
//! - [`HermesSnake`] type — distinct from any companion type.
//! - [`is_companion_farm_citizen`] returns `false` for HermesSnake.
//!
//! Doctrine pin: any future code that tries to enumerate the Companion
//! Farm + accidentally include the Snake gets caught by the type
//! system + this predicate.

use serde::{Deserialize, Serialize};

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize)]
pub enum PlaneZ {
    CompanionFarm,
    Snake,
}

impl PlaneZ {
    pub const fn z_value(self) -> i32 {
        match self {
            PlaneZ::CompanionFarm => 0,
            PlaneZ::Snake => 1,
        }
    }

    pub const fn code(self) -> &'static str {
        match self {
            PlaneZ::CompanionFarm => "companion_farm",
            PlaneZ::Snake => "snake",
        }
    }
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct HermesSnake {
    pub display_name: String,
    pub plane: PlaneZ,
    pub edges_woven: u32,
}

impl HermesSnake {
    /// Construct a Hermes Snake. The constructor pins the plane to
    /// `Snake` (z=1); callers cannot accidentally place the Snake on
    /// the companion-farm plane.
    pub fn new(display_name: impl Into<String>) -> Self {
        Self {
            display_name: display_name.into(),
            plane: PlaneZ::Snake,
            edges_woven: 0,
        }
    }

    /// Record one cross-citizen edge weaving.
    pub fn weave_edge(&mut self) {
        self.edges_woven = self.edges_woven.saturating_add(1);
    }
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum HermesSnakeError {
    AttemptedCompanionFarmCitizen,
}

/// True only when the entity is a citizen of the Companion Farm
/// plane. Hermes Snake is intentionally false (it's on z=1, Graph
/// Faculty, not a companion).
pub fn is_companion_farm_citizen(plane: PlaneZ) -> bool {
    plane == PlaneZ::CompanionFarm
}

/// Defensive constructor: refuses to build a Snake whose plane is
/// the companion-farm. Catches doctrine drift if a future caller
/// mutates `plane` post-construction.
pub fn verify_snake_placement(snake: &HermesSnake) -> Result<(), HermesSnakeError> {
    if snake.plane == PlaneZ::CompanionFarm {
        return Err(HermesSnakeError::AttemptedCompanionFarmCitizen);
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn two_distinct_planes() {
        let s: std::collections::HashSet<_> =
            [PlaneZ::CompanionFarm, PlaneZ::Snake].iter().copied().collect();
        assert_eq!(s.len(), 2);
    }

    #[test]
    fn plane_z_values_match_doctrine() {
        assert_eq!(PlaneZ::CompanionFarm.z_value(), 0);
        assert_eq!(PlaneZ::Snake.z_value(), 1);
    }

    #[test]
    fn plane_codes_stable() {
        assert_eq!(PlaneZ::CompanionFarm.code(), "companion_farm");
        assert_eq!(PlaneZ::Snake.code(), "snake");
    }

    #[test]
    fn hermes_snake_constructor_pins_plane_to_snake() {
        let s = HermesSnake::new("Hermes");
        assert_eq!(s.plane, PlaneZ::Snake);
        assert_eq!(s.plane.z_value(), 1);
    }

    #[test]
    fn hermes_snake_starts_with_zero_edges_woven() {
        let s = HermesSnake::new("Hermes");
        assert_eq!(s.edges_woven, 0);
    }

    #[test]
    fn weave_edge_increments() {
        let mut s = HermesSnake::new("Hermes");
        s.weave_edge();
        s.weave_edge();
        s.weave_edge();
        assert_eq!(s.edges_woven, 3);
    }

    #[test]
    fn weave_edge_saturates_at_u32_max() {
        let mut s = HermesSnake::new("Hermes");
        s.edges_woven = u32::MAX;
        s.weave_edge();
        assert_eq!(s.edges_woven, u32::MAX);
    }

    #[test]
    fn is_companion_farm_citizen_true_for_farm_plane() {
        assert!(is_companion_farm_citizen(PlaneZ::CompanionFarm));
    }

    #[test]
    fn is_companion_farm_citizen_false_for_snake_plane() {
        assert!(!is_companion_farm_citizen(PlaneZ::Snake));
    }

    #[test]
    fn verify_snake_placement_passes_on_snake_plane() {
        let s = HermesSnake::new("Hermes");
        assert!(verify_snake_placement(&s).is_ok());
    }

    #[test]
    fn verify_snake_placement_rejects_companion_farm() {
        let mut s = HermesSnake::new("Hermes");
        s.plane = PlaneZ::CompanionFarm;
        let err = verify_snake_placement(&s).unwrap_err();
        assert_eq!(err, HermesSnakeError::AttemptedCompanionFarmCitizen);
    }

    #[test]
    fn snake_roundtrips_through_serde_json() {
        let mut s = HermesSnake::new("Hermes");
        s.weave_edge();
        let json = serde_json::to_string(&s).unwrap();
        let back: HermesSnake = serde_json::from_str(&json).unwrap();
        assert_eq!(s, back);
    }

    #[test]
    fn plane_serializes_through_serde_json() {
        let p = PlaneZ::Snake;
        let json = serde_json::to_string(&p).unwrap();
        let back: PlaneZ = serde_json::from_str(&json).unwrap();
        assert_eq!(p, back);
    }

    #[test]
    fn display_name_stored_verbatim() {
        let s = HermesSnake::new("Hermes ⚯");
        assert_eq!(s.display_name, "Hermes ⚯");
    }
}
