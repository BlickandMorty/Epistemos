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
pub mod hermes_snake;
pub mod lora_hot_swap;
pub mod scheduler;
pub mod sprite_atlas;
pub mod state_smoother;

pub use state_smoother::{
    EmaSmoother, HysteresisError, SmootherError, SmoothedSignalStream, StateHysteresis,
    StreamConfigError,
};

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
    pub const ALL: [CompanionState; 5] = [
        CompanionState::Calm,
        CompanionState::Focused,
        CompanionState::Excited,
        CompanionState::Stressed,
        CompanionState::Sleeping,
    ];

    pub const fn code(self) -> &'static str {
        match self {
            CompanionState::Calm => "calm",
            CompanionState::Focused => "focused",
            CompanionState::Excited => "excited",
            CompanionState::Stressed => "stressed",
            CompanionState::Sleeping => "sleeping",
        }
    }

    /// Reverse lookup for [`Self::code`]. `None` for unknown codes.
    pub fn from_code(code: &str) -> Option<Self> {
        Self::ALL.iter().copied().find(|s| s.code() == code)
    }

    /// Predicate: this state has elevated user-engagement signal
    /// (Focused or Excited). The simulation surface uses this to
    /// pick the "active" animation lane.
    pub const fn is_engaged(self) -> bool {
        matches!(self, CompanionState::Focused | CompanionState::Excited)
    }

    /// Predicate: this state has low / baseline engagement (Calm,
    /// Stressed, Sleeping). Cross-surface invariant: exactly one of
    /// `is_engaged` / `is_resting` is true for any CompanionState.
    pub const fn is_resting(self) -> bool {
        matches!(
            self,
            CompanionState::Calm | CompanionState::Stressed | CompanionState::Sleeping
        )
    }
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum TamagotchiError {
    HrvOutOfRange { value: f32 },
    CoherenceOutOfRange { value: f32 },
    ArousalOutOfRange { value: f32 },
}

impl TamagotchiError {
    /// Field name the validation error pertains to. Used by the
    /// telemetry layer that wants a stable identifier instead of
    /// the Debug formatter.
    pub const fn field(&self) -> &'static str {
        match self {
            TamagotchiError::HrvOutOfRange { .. } => "hrv_rmssd_ms",
            TamagotchiError::CoherenceOutOfRange { .. } => "coherence_ratio",
            TamagotchiError::ArousalOutOfRange { .. } => "arousal_normalized",
        }
    }

    /// The out-of-range value that triggered the error. Used by the
    /// "what value did the user submit?" diagnostic.
    pub const fn offending_value(&self) -> f32 {
        match self {
            TamagotchiError::HrvOutOfRange { value }
            | TamagotchiError::CoherenceOutOfRange { value }
            | TamagotchiError::ArousalOutOfRange { value } => *value,
        }
    }

    pub const fn is_hrv(&self) -> bool {
        matches!(self, TamagotchiError::HrvOutOfRange { .. })
    }

    pub const fn is_coherence(&self) -> bool {
        matches!(self, TamagotchiError::CoherenceOutOfRange { .. })
    }

    pub const fn is_arousal(&self) -> bool {
        matches!(self, TamagotchiError::ArousalOutOfRange { .. })
    }
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

    /// Predicate: HRV in the Sleeping zone (`< 5.0` ms). Companion
    /// to the first branch of [`Self::to_companion_state`].
    pub fn is_in_sleep_zone(&self) -> bool {
        self.hrv_rmssd_ms < 5.0
    }

    /// Predicate: HRV in the Stressed zone (`5.0 ≤ HRV < 20.0`).
    /// Companion to the second branch of [`Self::to_companion_state`].
    pub fn is_in_stressed_zone(&self) -> bool {
        self.hrv_rmssd_ms >= 5.0 && self.hrv_rmssd_ms < 20.0
    }

    /// Predicate: coherence above the Focused threshold (`> 0.6`).
    pub fn is_in_focused_zone(&self) -> bool {
        self.coherence_ratio > 0.6
    }

    /// Predicate: arousal above the Excited threshold (`> 0.7`).
    pub fn is_in_excited_zone(&self) -> bool {
        self.arousal_normalized > 0.7
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

    // ── diagnostic surface (iter 142) ────────────────────────────────────────

    #[test]
    fn companion_state_all_has_five_distinct() {
        let s: std::collections::HashSet<_> = CompanionState::ALL.iter().copied().collect();
        assert_eq!(s.len(), 5);
    }

    #[test]
    fn from_code_roundtrips_all_states() {
        for st in CompanionState::ALL.iter().copied() {
            assert_eq!(CompanionState::from_code(st.code()), Some(st));
        }
    }

    #[test]
    fn from_code_unknown_returns_none() {
        assert_eq!(CompanionState::from_code("not-a-state"), None);
        assert_eq!(CompanionState::from_code("Calm"), None); // case-sensitive
        assert_eq!(CompanionState::from_code(""), None);
    }

    #[test]
    fn is_engaged_includes_focused_and_excited_only() {
        let engaged = [CompanionState::Focused, CompanionState::Excited];
        for st in CompanionState::ALL.iter().copied() {
            assert_eq!(st.is_engaged(), engaged.contains(&st));
        }
    }

    #[test]
    fn is_engaged_xor_is_resting_partitions_all() {
        // Cross-surface invariant: exactly one of is_engaged / is_resting
        // is true for every CompanionState.
        for st in CompanionState::ALL.iter().copied() {
            assert_ne!(st.is_engaged(), st.is_resting());
        }
    }

    #[test]
    fn is_in_sleep_zone_aligns_with_to_companion_state() {
        // Cross-surface invariant: is_in_sleep_zone implies the
        // mapper returns Sleeping (regardless of coherence/arousal).
        let s = BiometricSignal::new(2.0, 0.95, 0.95).unwrap();
        assert!(s.is_in_sleep_zone());
        assert_eq!(s.to_companion_state(), CompanionState::Sleeping);
    }

    #[test]
    fn is_in_stressed_zone_aligns_with_to_companion_state() {
        // 5 ≤ HRV < 20 → Stressed (regardless of other channels).
        let s = BiometricSignal::new(10.0, 0.95, 0.95).unwrap();
        assert!(s.is_in_stressed_zone());
        assert!(!s.is_in_sleep_zone());
        assert_eq!(s.to_companion_state(), CompanionState::Stressed);
    }

    #[test]
    fn sleep_and_stressed_zones_are_disjoint() {
        // Cross-surface: a single HRV value can't be in both zones.
        for hrv_int in 0..=200 {
            let hrv = hrv_int as f32;
            let s = BiometricSignal::new(hrv, 0.5, 0.5).unwrap();
            assert!(!(s.is_in_sleep_zone() && s.is_in_stressed_zone()), "hrv={}", hrv);
        }
    }

    #[test]
    fn focused_zone_only_triggers_when_hrv_is_healthy() {
        // is_in_focused_zone is purely about coherence — but the
        // mapper checks HRV gates first. Verify the predicate and
        // mapper agree only when HRV is in the healthy range.
        let healthy = BiometricSignal::new(40.0, 0.8, 0.3).unwrap();
        assert!(healthy.is_in_focused_zone());
        assert_eq!(healthy.to_companion_state(), CompanionState::Focused);

        // Same coherence but HRV in stressed zone → mapper says Stressed
        // even though is_in_focused_zone is still true at the channel level.
        let low_hrv = BiometricSignal::new(15.0, 0.8, 0.3).unwrap();
        assert!(low_hrv.is_in_focused_zone());
        assert_eq!(low_hrv.to_companion_state(), CompanionState::Stressed);
    }

    #[test]
    fn excited_zone_predicate_matches_threshold() {
        let high = BiometricSignal::new(40.0, 0.3, 0.8).unwrap();
        assert!(high.is_in_excited_zone());
        let low = BiometricSignal::new(40.0, 0.3, 0.7).unwrap();
        assert!(!low.is_in_excited_zone());
    }

    #[test]
    fn error_field_matches_variant() {
        // Cross-surface: error.field() agrees with which variant predicate is true.
        let hrv = TamagotchiError::HrvOutOfRange { value: 999.0 };
        let coh = TamagotchiError::CoherenceOutOfRange { value: 2.0 };
        let aro = TamagotchiError::ArousalOutOfRange { value: -1.0 };
        assert_eq!(hrv.field(), "hrv_rmssd_ms");
        assert_eq!(coh.field(), "coherence_ratio");
        assert_eq!(aro.field(), "arousal_normalized");
        assert!(hrv.is_hrv() && !hrv.is_coherence() && !hrv.is_arousal());
        assert!(!coh.is_hrv() && coh.is_coherence() && !coh.is_arousal());
        assert!(!aro.is_hrv() && !aro.is_coherence() && aro.is_arousal());
    }

    #[test]
    fn error_offending_value_extracts_value() {
        assert_eq!(
            TamagotchiError::HrvOutOfRange { value: 999.0 }.offending_value(),
            999.0
        );
        assert_eq!(
            TamagotchiError::CoherenceOutOfRange { value: -0.5 }.offending_value(),
            -0.5
        );
        assert_eq!(
            TamagotchiError::ArousalOutOfRange { value: 1.5 }.offending_value(),
            1.5
        );
    }
}
