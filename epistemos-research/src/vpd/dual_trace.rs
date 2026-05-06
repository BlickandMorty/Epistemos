//! HELIOS V5 W19 + PCF-7 — Dual Connectome Trace.
//!
//! HELIOS-W19 guard
//!
//! Per `docs/HELIOS_V5_INTEGRATION_PLAN_v2_FINALIZE_2026_05_05.md` §B:
//!
//! > "PCF-7 DualConnectomeTrace (parameter-space + activation-space
//! >  joint traces)"
//!
//! Combines an SPD parameter-component trace with an SAE activation-
//! component trace at the same forward-pass timestamp. The dual
//! representation is more faithful than either alone (PCF-7 / T31).

use serde::{Deserialize, Serialize};

/// One dual-trace sample at a single token position.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct DualTraceSample {
    pub token_position: u32,
    pub layer: u32,
    /// SPD parameter-space component activations.
    pub param_activations: Vec<f32>,
    /// SAE activation-space component activations.
    pub act_activations: Vec<f32>,
}

/// Trace a sequence of dual-trace samples for a single forward pass.
#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct DualConnectomeTrace {
    pub trace_id: String,
    pub samples: Vec<DualTraceSample>,
}

impl DualConnectomeTrace {
    pub fn new(trace_id: String) -> Self {
        Self {
            trace_id,
            samples: Vec::new(),
        }
    }

    pub fn push(&mut self, s: DualTraceSample) {
        self.samples.push(s);
    }

    pub fn len(&self) -> usize {
        self.samples.len()
    }

    pub fn is_empty(&self) -> bool {
        self.samples.is_empty()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn empty_trace_starts_with_no_samples() {
        let t = DualConnectomeTrace::new("t1".to_string());
        assert!(t.is_empty());
    }

    #[test]
    fn dual_trace_round_trip_through_json() {
        let mut t = DualConnectomeTrace::new("t1".to_string());
        t.push(DualTraceSample {
            token_position: 0,
            layer: 0,
            param_activations: vec![0.1, 0.2],
            act_activations: vec![0.3, 0.4],
        });
        let json = serde_json::to_string(&t).unwrap();
        let parsed: DualConnectomeTrace = serde_json::from_str(&json).unwrap();
        assert_eq!(parsed, t);
    }
}
