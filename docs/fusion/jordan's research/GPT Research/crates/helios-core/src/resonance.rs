//! Resonance Gate: token/event signature validation and routing decisions.

use crate::types::{ClaimType, ResonanceSignature, TierState};

/// Gate output.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum GateDecision {
    AcceptLocal,
    RequireEvidence,
    Quarantine,
    EscalateCloud,
}

/// Tunable policy for the Resonance Gate.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct GatePolicy {
    pub min_coherence: f32,
    pub max_surprise_local: f32,
    pub max_entropy_local: f32,
}

impl Default for GatePolicy {
    fn default() -> Self {
        Self { min_coherence: 0.75, max_surprise_local: 0.20, max_entropy_local: 0.80 }
    }
}

/// Stateless verifier for token and agent-event signatures.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct ResonanceGate {
    pub policy: GatePolicy,
}

impl Default for ResonanceGate {
    fn default() -> Self {
        Self { policy: GatePolicy::default() }
    }
}

impl ResonanceGate {
    #[must_use]
    pub const fn new(policy: GatePolicy) -> Self {
        Self { policy }
    }

    /// Classify one signature.
    #[must_use]
    pub fn decide(self, sig: ResonanceSignature) -> GateDecision {
        if !sig.scalar_fields_valid() || sig.claim_type == ClaimType::Gap {
            return GateDecision::Quarantine;
        }
        if sig.tier == TierState::Cloud || sig.claim_type == ClaimType::Composite {
            return GateDecision::RequireEvidence;
        }
        if sig.coherence < self.policy.min_coherence {
            return GateDecision::RequireEvidence;
        }
        if sig.surprise > self.policy.max_surprise_local {
            return GateDecision::EscalateCloud;
        }
        if sig.entropy > self.policy.max_entropy_local {
            return GateDecision::RequireEvidence;
        }
        GateDecision::AcceptLocal
    }
}

#[cfg(test)]
mod tests {
    use super::{GateDecision, ResonanceGate};
    use crate::types::{ClaimType, Direction, ResonanceSignature, TierState};

    fn sig() -> ResonanceSignature {
        ResonanceSignature { token_id: 1, tier: TierState::Hot, claim_type: ClaimType::Prime, direction: Direction::None, coherence: 0.9, surprise: 0.1, provenance_hash: 7, entropy: 0.4 }
    }

    #[test]
    fn accepts_clean_prime_claim() {
        assert_eq!(ResonanceGate::default().decide(sig()), GateDecision::AcceptLocal);
    }

    #[test]
    fn composite_claim_requires_evidence() {
        let mut s = sig();
        s.claim_type = ClaimType::Composite;
        assert_eq!(ResonanceGate::default().decide(s), GateDecision::RequireEvidence);
    }
}
