//! HELIOS V5 W20 + PCF-6 — ModelSurgeryEnvelope.
//!
//! HELIOS-W20 guard
//!
//! Per `docs/HELIOS_V5_INTEGRATION_PLAN_v2_2026_05_05.md` §3 W20 +
//! `docs/fusion/helios v5 updated.md` PART 5 T29 (PCF-6):
//!
//! > "Component Edit Safety Bound — editing component subset S of
//! >  size ≤ s_max bounds downstream PPL drift on out-of-edit
//! >  prompts by O(s_max · σ_max(W_edit))."
//!
//! Lane 5 Vault — NEVER in MAS. The envelope captures (a) the
//! component subset to edit, (b) the safety predicate that gates
//! the edit, (c) the PPL drift bound, all with provenance.

use serde::{Deserialize, Serialize};

/// One model-surgery edit — a request to modify a specified
/// component subset, gated by a PPL drift safety bound.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ModelSurgeryEnvelope {
    pub envelope_id: String,
    pub target_component_ids: Vec<u32>,
    /// Maximum allowed size of the edit set (`s_max`).
    pub s_max: u32,
    /// PPL drift ceiling on out-of-edit prompts.
    pub ppl_drift_max: f32,
    /// Author/operator id (provenance).
    pub author: String,
    /// Free-form description of the edit's intent.
    pub description: String,
}

impl ModelSurgeryEnvelope {
    /// Validates the envelope's structural invariants:
    /// * `target_component_ids.len() <= s_max as usize`
    /// * `ppl_drift_max >= 0.0`
    pub fn validate(&self) -> Result<(), SurgeryError> {
        if self.target_component_ids.len() > self.s_max as usize {
            return Err(SurgeryError::EditSetTooLarge {
                actual: self.target_component_ids.len(),
                allowed: self.s_max,
            });
        }
        if self.ppl_drift_max < 0.0 {
            return Err(SurgeryError::NegativePplDriftBound(self.ppl_drift_max));
        }
        Ok(())
    }
}

#[derive(Debug, Clone, PartialEq, thiserror::Error)]
pub enum SurgeryError {
    #[error("edit set size {actual} exceeds s_max {allowed}")]
    EditSetTooLarge { actual: usize, allowed: u32 },

    #[error("ppl_drift_max must be non-negative, got {0}")]
    NegativePplDriftBound(f32),
}

#[cfg(test)]
mod tests {
    use super::*;

    fn well_formed() -> ModelSurgeryEnvelope {
        ModelSurgeryEnvelope {
            envelope_id: "env-1".to_string(),
            target_component_ids: vec![1, 2, 3],
            s_max: 10,
            ppl_drift_max: 1.0,
            author: "operator-jojo".to_string(),
            description: "edit emoticon component".to_string(),
        }
    }

    #[test]
    fn well_formed_envelope_validates() {
        assert_eq!(well_formed().validate(), Ok(()));
    }

    #[test]
    fn over_size_edit_set_rejected() {
        let mut e = well_formed();
        e.target_component_ids = vec![0; 11]; // s_max = 10
        assert!(matches!(
            e.validate(),
            Err(SurgeryError::EditSetTooLarge { .. })
        ));
    }

    #[test]
    fn negative_ppl_drift_rejected() {
        let mut e = well_formed();
        e.ppl_drift_max = -1.0;
        assert!(matches!(
            e.validate(),
            Err(SurgeryError::NegativePplDriftBound(_))
        ));
    }

    #[test]
    fn envelope_round_trips_through_json() {
        let e = well_formed();
        let json = serde_json::to_string(&e).unwrap();
        let parsed: ModelSurgeryEnvelope = serde_json::from_str(&json).unwrap();
        assert_eq!(parsed, e);
    }
}
