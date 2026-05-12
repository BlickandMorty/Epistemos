//! HELIOS V5 — SCOPE-Rex Omega `FeatureObservatory` trait.
//!
//! HELIOS-OBSERVATORY guard
//!
//! Per HELIOS v4 preservation `source_docs/scope_rex_omega.md`
//! "Observatory Mode" — sparse-feature observability via Qwen-Scope-
//! style SAE inspection on Qwen-family local models, with SAELens /
//! NNsight / Neuronpedia analysis surfaces.
//!
//! The feature observatory exposes:
//!   * point-in-time inspection of layer/token feature activations
//!   * suggested edits (steering) per a SteeringMode policy
//!
//! Used by the constrained action-selection objective:
//!
//! ```text
//! a_t* = argmin λ_v V(a) + λ_p P(a) + λ_d D(a) + λ_c C(a)
//!              - λ_i I(a) - λ_f F(a)
//! ```
//!
//! where `F(a)` is the feature-target match supplied by this trait.
//!
//! Lane 3 RESEARCH-ONLY for the real SAE backend (Qwen-Scope etc.).
//! The default no-op implementation lives in `mas-build` per Tier 2
//! "Verified Research Mode → Hopfield retrieval" toggle (W15) +
//! "Connectome Browser" toggle (W10).

use serde::{Deserialize, Serialize};

/// One feature signal — the activation of a sparse-autoencoder
/// feature at a given (layer, token) position.
#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct FeatureSignal {
    pub feature_index: u32,
    pub layer: u32,
    pub token_index: u32,
    pub activation: f32,
}

/// Steering mode for the feature observatory's suggested-edits
/// surface. Maps to Tier-2 settings per W15 (Verified Research
/// Mode → Hopfield retrieval) + W10 (Connectome Browser).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum SteeringMode {
    /// Read-only inspection — suggest no edits.
    ReadOnly,
    /// Suggest amplification of low-activation target features.
    Amplify,
    /// Suggest suppression of high-activation off-target features.
    Suppress,
    /// Suggest steering toward a target feature distribution.
    Steer,
}

/// One suggested feature edit. The runtime decides whether to
/// apply (and the user's biometric approval gates the apply per
/// Tier-2 §2.5.2 compliance).
#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct FeatureEdit {
    pub feature_index: u32,
    pub layer: u32,
    pub multiplier: f32, // 1.0 = no change
}

/// Feature observatory trait — exposes SAE inspection + suggested
/// edits. Real backends (Qwen-Scope, SAELens, Neuronpedia) implement
/// this; the default no-op implementation returns empty surfaces.
pub trait FeatureObservatory {
    fn inspect(&self, layer: usize, token_ix: usize) -> Vec<FeatureSignal>;
    fn suggest_edits(&self, mode: SteeringMode) -> Vec<FeatureEdit>;
}

/// No-op default observatory — always returns empty surfaces.
/// Useful as a placeholder until a real SAE backend lands per
/// Lane 3 follow-up (W17/W18/W19 integration).
#[derive(Debug, Clone, Copy, Default)]
pub struct NoOpFeatureObservatory;

impl FeatureObservatory for NoOpFeatureObservatory {
    fn inspect(&self, _layer: usize, _token_ix: usize) -> Vec<FeatureSignal> {
        Vec::new()
    }

    fn suggest_edits(&self, _mode: SteeringMode) -> Vec<FeatureEdit> {
        Vec::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn no_op_observatory_returns_empty_surfaces() {
        let o = NoOpFeatureObservatory;
        assert!(o.inspect(0, 0).is_empty());
        assert!(o.suggest_edits(SteeringMode::ReadOnly).is_empty());
    }

    #[test]
    fn steering_mode_serializes_in_snake_case() {
        for (m, expected) in [
            (SteeringMode::ReadOnly, "\"read_only\""),
            (SteeringMode::Amplify, "\"amplify\""),
            (SteeringMode::Suppress, "\"suppress\""),
            (SteeringMode::Steer, "\"steer\""),
        ] {
            assert_eq!(serde_json::to_string(&m).unwrap(), expected);
        }
    }

    #[test]
    fn feature_signal_round_trips_through_json() {
        let s = FeatureSignal {
            feature_index: 42,
            layer: 12,
            token_index: 7,
            activation: 0.85,
        };
        let json = serde_json::to_string(&s).unwrap();
        let parsed: FeatureSignal = serde_json::from_str(&json).unwrap();
        assert_eq!(parsed, s);
    }

    #[test]
    fn feature_edit_default_multiplier_is_unity() {
        // Identity edit — multiplier=1.0 means "no change".
        let e = FeatureEdit {
            feature_index: 0,
            layer: 0,
            multiplier: 1.0,
        };
        // sanity — this is a no-op edit.
        assert!((e.multiplier - 1.0).abs() < 1e-9);
    }
}
