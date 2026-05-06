//! HELIOS V5 PCF-10 — Interpretability-to-Runtime Transfer.
//!
//! Per `docs/HELIOS_V5_INTEGRATION_PLAN_v2_FINALIZE_2026_05_05.md` §B:
//!
//! > "PCF-10 Interpretability-to-Runtime Transfer — faithful SPD
//! >  decomposition transfers to runtime as active-rank-one path
//! >  with bounded PPL drift."
//!
//! Lane 5 Vault — NEVER in MAS. State:candidate per v5.2 Caveat 2.

use serde::{Deserialize, Serialize};

/// One Interpretability-to-Runtime transfer record. Captures the
/// SPD anchor library + the runtime acceptance threshold (max PPL
/// drift on the validation set).
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct InterpretabilityTransfer {
    pub transfer_id: String,
    /// Anchor library id this transfer was distilled from (PCF-1).
    pub source_anchor_library_id: String,
    /// Maximum allowed PPL drift on the validation prompts.
    pub ppl_drift_max: f32,
    /// Whether the transfer has been verified on M2 Max.
    pub verified: bool,
}

impl InterpretabilityTransfer {
    pub fn new(transfer_id: String, anchor_library_id: String) -> Self {
        Self {
            transfer_id,
            source_anchor_library_id: anchor_library_id,
            ppl_drift_max: 0.5,
            verified: false,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn new_transfer_starts_unverified() {
        let t = InterpretabilityTransfer::new("t1".to_string(), "lib-a".to_string());
        assert!(!t.verified);
        assert!((t.ppl_drift_max - 0.5).abs() < 1e-6);
    }
}
