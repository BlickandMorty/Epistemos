//! Universal ternary plasticity gate.

use crate::types::LearningMode;

/// Ternary update sign for a bounded learning operation.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum TernaryUpdate {
    Down = -1,
    Hold = 0,
    Up = 1,
}

/// Decision returned by the plasticity gate.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct PlasticityDecision {
    pub mode: LearningMode,
    pub update: TernaryUpdate,
    pub confidence: f32,
}

/// Single primitive for fast weights, LoRA routing, and sketch updates.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct PlasticityGate {
    pub deadband: f32,
    pub lora_threshold: f32,
    pub fast_weight_threshold: f32,
}

impl Default for PlasticityGate {
    fn default() -> Self {
        Self { deadband: 0.02, fast_weight_threshold: 0.10, lora_threshold: 0.40 }
    }
}

impl PlasticityGate {
    /// Gate a scalar surprise-gradient signal into a reversible learning decision.
    #[must_use]
    pub fn decide(self, surprise_gradient: f32, repeated: bool) -> PlasticityDecision {
        let magnitude = surprise_gradient.abs();
        let update = if magnitude < self.deadband {
            TernaryUpdate::Hold
        } else if surprise_gradient > 0.0 {
            TernaryUpdate::Up
        } else {
            TernaryUpdate::Down
        };
        let mode = if update == TernaryUpdate::Hold {
            LearningMode::Freeze
        } else if repeated && magnitude >= self.lora_threshold {
            LearningMode::LoRa
        } else if magnitude >= self.fast_weight_threshold {
            LearningMode::FastWeight
        } else {
            LearningMode::Sketch
        };
        PlasticityDecision { mode, update, confidence: magnitude.min(1.0) }
    }
}

#[cfg(test)]
mod tests {
    use super::{PlasticityGate, TernaryUpdate};
    use crate::types::LearningMode;

    #[test]
    fn deadband_freezes() {
        let d = PlasticityGate::default().decide(0.001, false);
        assert_eq!(d.mode, LearningMode::Freeze);
        assert_eq!(d.update, TernaryUpdate::Hold);
    }

    #[test]
    fn repeated_large_signal_routes_to_lora() {
        assert_eq!(PlasticityGate::default().decide(0.8, true).mode, LearningMode::LoRa);
    }
}
