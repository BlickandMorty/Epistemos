//! Runtime wrapper around the core Resonance Gate.

use helios_core::{GateDecision, ResonanceGate, ResonanceSignature};

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct RuntimeGate {
    gate: ResonanceGate,
}

impl Default for RuntimeGate {
    fn default() -> Self { Self { gate: ResonanceGate::default() } }
}

impl RuntimeGate {
    #[must_use]
    pub const fn new(gate: ResonanceGate) -> Self { Self { gate } }

    #[must_use]
    pub fn verify(self, signature: ResonanceSignature) -> GateDecision { self.gate.decide(signature) }
}
