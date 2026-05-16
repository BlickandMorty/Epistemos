//! Source:
//! - `~/Documents/Epistemos-QuickCapture/BIOMETRIC_TAMAGOTCHI_BRAIN_EXPORT_ADDENDUM.md`
//!   §0 (Wave 10 NET-NEW UX) + §Biometric Tamagotchi sections.
//! - `docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_B_2026_05_16.md`
//!   §5 Phase B.7 — Biometric Tamagotchi: HRV / coherence / arousal
//!   signal → companion state. Cross-link to Wave G companion
//!   lifecycle.
//! - Companion to Wave G `Epistemos/Views/Simulation/` (Simulation
//!   mode UI; B-owned per §2).
//!
//! # Phase B.7 — Biometric Tamagotchi substrate
//!
//! Biometric signals collected by the user-facing app feed three
//! channels:
//!
//! - **HRV** (heart-rate variability, ms RMSSD) — proxy for autonomic
//!   balance. High → calm; low → stressed.
//! - **Coherence** (HRV spectral coherence in the 0.04-0.26 Hz band)
//!   — proxy for focus / flow state.
//! - **Arousal** (skin conductance / inferred valence) — proxy for
//!   intensity (orthogonal to coherence).
//!
//! These map to a [`CompanionState`] that the Wave G simulation
//! surface renders. Substrate floor owns the typed envelope + the
//! mapping function; the simulation rendering is Wave G's domain.

pub mod animation;
pub mod sprite_atlas;

use serde::{Deserialize, Serialize};

#[derive(Clone, Copy, Debug, PartialEq, Serialize, Deserialize)]
pub struct BiometricSignal {
    pub hrv_rmssd_ms: f32,
    pub coherence_ratio: f32,
    pub arousal_normalized: f32,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize)]
pub enum CompanionState {
    Calm,
    Focused,
    Excited,
    Stressed,
    Sleeping,
}

impl CompanionState {
    pub const fn code(self) -> &'static str {
        match self {
            CompanionState::Calm => "calm",
            CompanionState::Focused => "focused",
            CompanionState::Excited => "excited",
            CompanionState::Stressed => "stressed",
            CompanionState::Sleeping => "sleeping",
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum TamagotchiError {
    HrvOutOfRange { value: f32 },
    CoherenceOutOfRange { value: f32 },
    ArousalOutOfRange { value: f32 },
}

impl BiometricSignal {
    pub fn new(
        hrv_rmssd_ms: f32,
        coherence_ratio: f32,
        arousal_normalized: f32,
    ) -> Result<Self, TamagotchiError> {
        if !hrv_rmssd_ms.is_finite() || hrv_rmssd_ms < 0.0 || hrv_rmssd_ms > 200.0 {
            return Err(TamagotchiError::HrvOutOfRange { value: hrv_rmssd_ms });
        }
        if !coherence_ratio.is_finite() || !(0.0..=1.0).contains(&coherence_ratio) {
            return Err(TamagotchiError::CoherenceOutOfRange { value: coherence_ratio });
        }
        if !arousal_normalized.is_finite() || !(0.0..=1.0).contains(&arousal_normalized) {
            return Err(TamagotchiError::ArousalOutOfRange { value: arousal_normalized });
        }
        Ok(Self { hrv_rmssd_ms, coherence_ratio, arousal_normalized })
    }

    /// Map signal → companion state. Substrate floor uses simple
    /// thresholds; production replaces with a learned classifier.
    ///
    /// Threshold logic:
    /// - HRV < 5 → Sleeping (rest / very-low autonomic activity).
    /// - HRV < 20 → Stressed (low autonomic balance).
    /// - Coherence > 0.6 → Focused (flow state).
    /// - Arousal > 0.7 → Excited.
    /// - Otherwise → Calm.
    pub fn to_companion_state(&self) -> CompanionState {
        if self.hrv_rmssd_ms < 5.0 {
            return CompanionState::Sleeping;
        }
        if self.hrv_rmssd_ms < 20.0 {
            return CompanionState::Stressed;
        }
        if self.coherence_ratio > 0.6 {
            return CompanionState::Focused;
        }
        if self.arousal_normalized > 0.7 {
            return CompanionState::Excited;
        }
        CompanionState::Calm
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn five_distinct_states() {
        let s: std::collections::HashSet<_> = [
            CompanionState::Calm,
            CompanionState::Focused,
            CompanionState::Excited,
            CompanionState::Stressed,
            CompanionState::Sleeping,
        ]
        .iter()
        .copied()
        .collect();
        assert_eq!(s.len(), 5);
    }

    #[test]
    fn state_codes_stable() {
        assert_eq!(CompanionState::Calm.code(), "calm");
        assert_eq!(CompanionState::Focused.code(), "focused");
        assert_eq!(CompanionState::Excited.code(), "excited");
        assert_eq!(CompanionState::Stressed.code(), "stressed");
        assert_eq!(CompanionState::Sleeping.code(), "sleeping");
    }

    #[test]
    fn ok_signal_constructs() {
        let s = BiometricSignal::new(40.0, 0.5, 0.5).unwrap();
        assert_eq!(s.hrv_rmssd_ms, 40.0);
    }

    #[test]
    fn hrv_negative_rejected() {
        let err = BiometricSignal::new(-1.0, 0.5, 0.5).unwrap_err();
        assert!(matches!(err, TamagotchiError::HrvOutOfRange { .. }));
    }

    #[test]
    fn hrv_above_200_rejected() {
        let err = BiometricSignal::new(300.0, 0.5, 0.5).unwrap_err();
        assert!(matches!(err, TamagotchiError::HrvOutOfRange { .. }));
    }

    #[test]
    fn coherence_out_of_range_rejected() {
        let err = BiometricSignal::new(40.0, 1.5, 0.5).unwrap_err();
        assert!(matches!(err, TamagotchiError::CoherenceOutOfRange { .. }));
        let err = BiometricSignal::new(40.0, -0.1, 0.5).unwrap_err();
        assert!(matches!(err, TamagotchiError::CoherenceOutOfRange { .. }));
    }

    #[test]
    fn arousal_out_of_range_rejected() {
        let err = BiometricSignal::new(40.0, 0.5, 2.0).unwrap_err();
        assert!(matches!(err, TamagotchiError::ArousalOutOfRange { .. }));
    }

    #[test]
    fn nan_rejected_everywhere() {
        assert!(BiometricSignal::new(f32::NAN, 0.5, 0.5).is_err());
        assert!(BiometricSignal::new(40.0, f32::NAN, 0.5).is_err());
        assert!(BiometricSignal::new(40.0, 0.5, f32::NAN).is_err());
    }

    #[test]
    fn very_low_hrv_maps_to_sleeping() {
        let s = BiometricSignal::new(2.0, 0.5, 0.5).unwrap();
        assert_eq!(s.to_companion_state(), CompanionState::Sleeping);
    }

    #[test]
    fn low_hrv_maps_to_stressed() {
        let s = BiometricSignal::new(15.0, 0.5, 0.5).unwrap();
        assert_eq!(s.to_companion_state(), CompanionState::Stressed);
    }

    #[test]
    fn high_coherence_maps_to_focused() {
        let s = BiometricSignal::new(40.0, 0.8, 0.5).unwrap();
        assert_eq!(s.to_companion_state(), CompanionState::Focused);
    }

    #[test]
    fn high_arousal_maps_to_excited() {
        let s = BiometricSignal::new(40.0, 0.4, 0.8).unwrap();
        assert_eq!(s.to_companion_state(), CompanionState::Excited);
    }

    #[test]
    fn middling_signal_maps_to_calm() {
        let s = BiometricSignal::new(40.0, 0.4, 0.4).unwrap();
        assert_eq!(s.to_companion_state(), CompanionState::Calm);
    }

    #[test]
    fn signal_roundtrips_through_serde_json() {
        let s = BiometricSignal::new(40.0, 0.5, 0.5).unwrap();
        let json = serde_json::to_string(&s).unwrap();
        let back: BiometricSignal = serde_json::from_str(&json).unwrap();
        assert_eq!(s, back);
    }

    #[test]
    fn state_serializes_through_serde_json() {
        let st = CompanionState::Focused;
        let json = serde_json::to_string(&st).unwrap();
        let back: CompanionState = serde_json::from_str(&json).unwrap();
        assert_eq!(st, back);
    }
}
