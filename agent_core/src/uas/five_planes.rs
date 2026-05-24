//! MAS-safe mirror of the V6.1 five-plane runtime formalism.
//!
//! The research crate keeps the full HELIOS doctrine surface. This mirror
//! exposes only the stable enum needed by product code so MAS builds can tag
//! UAS objects without depending on `epistemos-research`.

use serde::{Deserialize, Serialize};

// UAS: uas/runtime-plane/<plane>
// Plane: RuntimePlane::Verification
// Residency: ResidencyTier::CurrentApp
/// One of the five canonical runtime planes.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum RuntimePlane {
    State,
    Episodic,
    Assembly,
    Controller,
    Verification,
}

impl RuntimePlane {
    pub const fn plane_number(self) -> u32 {
        match self {
            RuntimePlane::State => 1,
            RuntimePlane::Episodic => 2,
            RuntimePlane::Assembly => 3,
            RuntimePlane::Controller => 4,
            RuntimePlane::Verification => 5,
        }
    }

    pub const fn wire_tag(self) -> &'static str {
        match self {
            RuntimePlane::State => "state",
            RuntimePlane::Episodic => "episodic",
            RuntimePlane::Assembly => "assembly",
            RuntimePlane::Controller => "controller",
            RuntimePlane::Verification => "verification",
        }
    }

    pub fn from_wire_tag(tag: &str) -> Option<Self> {
        match tag {
            "state" => Some(RuntimePlane::State),
            "episodic" => Some(RuntimePlane::Episodic),
            "assembly" => Some(RuntimePlane::Assembly),
            "controller" => Some(RuntimePlane::Controller),
            "verification" => Some(RuntimePlane::Verification),
            _ => None,
        }
    }
}

pub const FIVE_RUNTIME_PLANES: [RuntimePlane; 5] = [
    RuntimePlane::State,
    RuntimePlane::Episodic,
    RuntimePlane::Assembly,
    RuntimePlane::Controller,
    RuntimePlane::Verification,
];

impl Default for RuntimePlane {
    fn default() -> Self {
        RuntimePlane::Episodic
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn wire_tags_round_trip() {
        for plane in FIVE_RUNTIME_PLANES {
            assert_eq!(RuntimePlane::from_wire_tag(plane.wire_tag()), Some(plane));
        }
    }

    #[test]
    fn plane_numbers_are_v6_1_order() {
        for (i, plane) in FIVE_RUNTIME_PLANES.iter().copied().enumerate() {
            assert_eq!(plane.plane_number(), (i + 1) as u32);
        }
    }
}
