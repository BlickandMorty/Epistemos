use helios_runtime::gate::{ResonanceGate, ResonanceSignature as RustSig};
use helios_core::types::{LearningMode, ClaimType, Direction};
use uniffi;

/// Swift-mirrorable ResonanceSignature — flattened for FFI.
#[derive(uniffi::Record)]
pub struct ResonanceSignatureFFI {
    pub load_pressure: f32,
    pub entropy_curvature: f32,
    pub semantic_torsion: f32,
    pub predictive_residual: f32,
    pub plasticity_state: String,    // "freeze", "fast_weight", "lora", "sketch"
    pub claim_type: String,          // "prime", "composite", "gap"
    pub direction: String,           // "upward", "downward", "sideways", "inward", "on_itself", "none"
    pub kam_stability: f32,
}

#[derive(uniffi::Enum)]
pub enum GateActionFFI {
    Pass,
    Hold,
    Quarantine,
    TriggerEvidenceSupremacy,
    EngramAnchor,
    MigrateResidency { tier: String },
}

#[uniffi::export]
pub fn compute_resonance_signature_core(
    load_pressure: f32,
    entropy_curvature: f32,
    semantic_torsion: f32,
    predictive_residual: f32,
    plasticity_state: String,
    claim_type: String,
    direction: String,
    kam_stability: f32,
) -> ResonanceSignatureFFI {
    // Map strings to Rust enums
    let plasticity = match plasticity_state.as_str() {
        "fast_weight" => LearningMode::FastWeight,
        "lora" => LearningMode::LoRA,
        "sketch" => LearningMode::Sketch,
        _ => LearningMode::Freeze,
    };
    let claim = match claim_type.as_str() {
        "prime" => ClaimType::Prime,
        "composite" => ClaimType::Composite,
        "gap" => ClaimType::Gap,
        _ => ClaimType::Composite,
    };
    let dir = match direction.as_str() {
        "upward" => Direction::Upward,
        "downward" => Direction::Downward,
        "sideways" => Direction::Sideways,
        "inward" => Direction::Inward,
        "on_itself" => Direction::OnItself,
        _ => Direction::None,
    };
    
    let sig = RustSig {
        load_pressure,
        entropy_curvature,
        semantic_torsion,
        predictive_residual,
        plasticity_state: plasticity,
        claim_type: claim,
        direction: dir,
        kam_stability,
    };
    
    ResonanceSignatureFFI {
        load_pressure: sig.load_pressure,
        entropy_curvature: sig.entropy_curvature,
        semantic_torsion: sig.semantic_torsion,
        predictive_residual: sig.predictive_residual,
        plasticity_state: plasticity_state,
        claim_type: claim_type,
        direction: direction,
        kam_stability: sig.kam_stability,
    }
}

#[uniffi::export]
pub fn resonance_gate_decide(sig: ResonanceSignatureFFI) -> GateActionFFI {
    let rust_sig = RustSig {
        load_pressure: sig.load_pressure,
        entropy_curvature: sig.entropy_curvature,
        semantic_torsion: sig.semantic_torsion,
        predictive_residual: sig.predictive_residual,
        plasticity_state: match sig.plasticity_state.as_str() {
            "fast_weight" => LearningMode::FastWeight,
            "lora" => LearningMode::LoRA,
            "sketch" => LearningMode::Sketch,
            _ => LearningMode::Freeze,
        },
        claim_type: match sig.claim_type.as_str() {
            "prime" => ClaimType::Prime,
            "composite" => ClaimType::Composite,
            "gap" => ClaimType::Gap,
            _ => ClaimType::Composite,
        },
        direction: match sig.direction.as_str() {
            "upward" => Direction::Upward,
            "downward" => Direction::Downward,
            "sideways" => Direction::Sideways,
            "inward" => Direction::Inward,
            "on_itself" => Direction::OnItself,
            _ => Direction::None,
        },
        kam_stability: sig.kam_stability,
    };
    
    let mut gate = ResonanceGate::new();
    match gate.decide(&rust_sig) {
        helios_runtime::gate::GateAction::Pass => GateActionFFI::Pass,
        helios_runtime::gate::GateAction::Hold => GateActionFFI::Hold,
        helios_runtime::gate::GateAction::Quarantine => GateActionFFI::Quarantine,
        helios_runtime::gate::GateAction::TriggerEvidenceSupremacy => GateActionFFI::TriggerEvidenceSupremacy,
        helios_runtime::gate::GateAction::EngramAnchor => GateActionFFI::EngramAnchor,
        helios_runtime::gate::GateAction::MigrateResidency(t) => GateActionFFI::MigrateResidency { tier: format!("{:?}", t) },
    }
}
