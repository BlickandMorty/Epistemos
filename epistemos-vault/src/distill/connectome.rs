//! HELIOS V5 PCF-9 — Connectome Distillation.
//!
//! HELIOS-PCF9 guard
//!
//! Per `docs/HELIOS_V5_INTEGRATION_PLAN_v2_FINALIZE_2026_05_05.md` §B:
//!
//! > "PCF-9 Connectome Distillation — model can be distilled to
//! >  top-k component clusters with bounded PPL drift, producing a
//! >  NEW model file."
//!
//! Lane 5 Vault. Output is an alternate model file (NOT a runtime
//! mutation). May eventually ship Tier-2 in a future MAS release
//! after a fresh §2.5.2 audit.

use serde::{Deserialize, Serialize};

/// One Connectome Distillation result. Records the input model id,
/// the top-k component cluster count chosen, and the resulting
/// alternate model file's hash.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ConnectomeDistillation {
    pub distillation_id: String,
    pub source_model_id: String,
    pub top_k: u32,
    /// SHA-256 (hex) of the produced alternate model file.
    pub output_model_sha256: String,
    /// Measured PPL drift on the validation set.
    pub ppl_drift_observed: f32,
    /// Acceptance threshold used (matches PCF-9 falsifier rig).
    pub ppl_drift_max: f32,
}

impl ConnectomeDistillation {
    pub fn passes_acceptance(&self) -> bool {
        self.ppl_drift_observed <= self.ppl_drift_max
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn well_formed() -> ConnectomeDistillation {
        ConnectomeDistillation {
            distillation_id: "d1".to_string(),
            source_model_id: "qwen3-8b".to_string(),
            top_k: 2000,
            output_model_sha256: "a".repeat(64),
            ppl_drift_observed: 1.0,
            ppl_drift_max: 1.5,
        }
    }

    #[test]
    fn within_threshold_passes() {
        assert!(well_formed().passes_acceptance());
    }

    #[test]
    fn over_threshold_fails() {
        let mut d = well_formed();
        d.ppl_drift_observed = 2.0;
        assert!(!d.passes_acceptance());
    }
}
