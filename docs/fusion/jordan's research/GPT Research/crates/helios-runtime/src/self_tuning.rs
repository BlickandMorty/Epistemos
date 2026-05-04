//! Bounded self-tuning state: fast weights, LoRA bank, and gradient archive.

use helios_core::{PlasticityDecision, PlasticityGate};

#[derive(Clone, Debug, Default, PartialEq)]
pub struct GradientArchive {
    pub gradients: Vec<Vec<f32>>,
}

impl GradientArchive {
    pub fn record(&mut self, gradient: &[f32]) { self.gradients.push(gradient.to_vec()); }
}

#[derive(Clone, Debug, Default, PartialEq)]
pub struct LoraBank {
    pub adapters: Vec<Vec<f32>>,
}

#[derive(Clone, Debug, PartialEq)]
pub struct SelfTuningState {
    pub gate: PlasticityGate,
    pub archive: GradientArchive,
    pub lora_bank: LoraBank,
}

impl Default for SelfTuningState {
    fn default() -> Self { Self { gate: PlasticityGate::default(), archive: GradientArchive::default(), lora_bank: LoraBank::default() } }
}

impl SelfTuningState {
    pub fn observe(&mut self, gradient: &[f32], repeated: bool) -> PlasticityDecision {
        self.archive.record(gradient);
        let mean = if gradient.is_empty() { 0.0 } else { gradient.iter().sum::<f32>() / gradient.len() as f32 };
        self.gate.decide(mean, repeated)
    }
}
