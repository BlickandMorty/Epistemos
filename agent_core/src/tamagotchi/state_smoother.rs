//! Source:
//! - `~/Documents/Epistemos-QuickCapture/BIOMETRIC_TAMAGOTCHI_BRAIN_EXPORT_ADDENDUM.md`
//!   §Biometric Tamagotchi — "signals are noisy; state must not flap
//!   between Calm/Stressed every few seconds under normal breathing".
//! - `docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_B_2026_05_16.md`
//!   §5 Phase B.7 — Biometric Tamagotchi substrate layer.
//! - Companion to [`super::BiometricSignal`] / [`super::CompanionState`].
//!
//! # Phase B.7 — Tamagotchi state smoother + hysteresis
//!
//! Raw HRV/coherence/arousal streams are bursty (breath cycle, motion
//! artifacts, electrode noise). Applying the threshold mapper from
//! `super::BiometricSignal::to_companion_state` to every sample would
//! make the companion state thrash every breath cycle, which is both
//! unpleasant and clinically meaningless.
//!
//! Two layers solve this:
//!
//! 1. **EMA smoothing** ([`EmaSmoother`]) — exponential moving average
//!    on the f32 signal channels. `alpha ∈ (0, 1]`; new = α·sample +
//!    (1−α)·previous. Smaller α = more smoothing = more lag.
//! 2. **State hysteresis** ([`StateHysteresis`]) — once a candidate
//!    state has been observed for `hold_samples` consecutive readings,
//!    transition to it. Otherwise stay in the current state. Prevents
//!    single-sample dropouts from triggering state changes.
//!
//! Combined wrapper [`SmoothedSignalStream`] applies both layers in
//! the correct order: smooth the signal first, then map → candidate
//! state, then hysteresis-debounce → committed state.

use super::{BiometricSignal, CompanionState};
use serde::{Deserialize, Serialize};

#[derive(Clone, Copy, Debug, PartialEq, Serialize, Deserialize)]
pub struct EmaSmoother {
    pub alpha: f32,
    state: Option<BiometricSignal>,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum SmootherError {
    AlphaOutOfRange { value: f32 },
}

impl EmaSmoother {
    /// `alpha` must be in (0.0, 1.0]. alpha=1.0 → no smoothing (pass-through);
    /// alpha→0.0 → infinite smoothing (output never moves).
    pub fn new(alpha: f32) -> Result<Self, SmootherError> {
        if !alpha.is_finite() || alpha <= 0.0 || alpha > 1.0 {
            return Err(SmootherError::AlphaOutOfRange { value: alpha });
        }
        Ok(Self { alpha, state: None })
    }

    /// Feed a sample, return the smoothed signal. First sample passes
    /// through unchanged (no history to blend against).
    pub fn observe(&mut self, sample: BiometricSignal) -> BiometricSignal {
        let next = match self.state {
            None => sample,
            Some(prev) => BiometricSignal {
                hrv_rmssd_ms: blend(self.alpha, prev.hrv_rmssd_ms, sample.hrv_rmssd_ms),
                coherence_ratio: blend(self.alpha, prev.coherence_ratio, sample.coherence_ratio),
                arousal_normalized: blend(
                    self.alpha,
                    prev.arousal_normalized,
                    sample.arousal_normalized,
                ),
            },
        };
        self.state = Some(next);
        next
    }

    pub fn current(&self) -> Option<BiometricSignal> {
        self.state
    }

    pub fn reset(&mut self) {
        self.state = None;
    }
}

fn blend(alpha: f32, prev: f32, sample: f32) -> f32 {
    alpha * sample + (1.0 - alpha) * prev
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct StateHysteresis {
    pub hold_samples: u32,
    committed: Option<CompanionState>,
    candidate: Option<CompanionState>,
    candidate_run: u32,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum HysteresisError {
    ZeroHold,
}

impl StateHysteresis {
    /// `hold_samples` must be ≥ 1. 1 = no hysteresis (commit immediately).
    pub fn new(hold_samples: u32) -> Result<Self, HysteresisError> {
        if hold_samples == 0 {
            return Err(HysteresisError::ZeroHold);
        }
        Ok(Self {
            hold_samples,
            committed: None,
            candidate: None,
            candidate_run: 0,
        })
    }

    /// Feed an instantaneous candidate state. Returns the currently
    /// committed state (which may have just transitioned). The first
    /// observation seeds `committed` directly so the stream has a
    /// state from sample 1.
    pub fn observe(&mut self, instantaneous: CompanionState) -> CompanionState {
        match self.committed {
            None => {
                self.committed = Some(instantaneous);
                self.candidate = None;
                self.candidate_run = 0;
                instantaneous
            }
            Some(curr) if curr == instantaneous => {
                self.candidate = None;
                self.candidate_run = 0;
                curr
            }
            Some(curr) => {
                if self.candidate == Some(instantaneous) {
                    self.candidate_run += 1;
                } else {
                    self.candidate = Some(instantaneous);
                    self.candidate_run = 1;
                }
                if self.candidate_run >= self.hold_samples {
                    self.committed = Some(instantaneous);
                    self.candidate = None;
                    self.candidate_run = 0;
                    instantaneous
                } else {
                    curr
                }
            }
        }
    }

    pub fn committed_state(&self) -> Option<CompanionState> {
        self.committed
    }

    pub fn candidate_run_length(&self) -> u32 {
        self.candidate_run
    }
}

/// End-to-end pipeline: smooth → map → hysteresis → committed state.
#[derive(Clone, Debug)]
pub struct SmoothedSignalStream {
    smoother: EmaSmoother,
    hysteresis: StateHysteresis,
}

impl SmoothedSignalStream {
    pub fn new(alpha: f32, hold_samples: u32) -> Result<Self, StreamConfigError> {
        let smoother = EmaSmoother::new(alpha).map_err(StreamConfigError::Smoother)?;
        let hysteresis =
            StateHysteresis::new(hold_samples).map_err(StreamConfigError::Hysteresis)?;
        Ok(Self { smoother, hysteresis })
    }

    pub fn observe(&mut self, sample: BiometricSignal) -> CompanionState {
        let smoothed = self.smoother.observe(sample);
        let candidate = smoothed.to_companion_state();
        self.hysteresis.observe(candidate)
    }

    pub fn committed_state(&self) -> Option<CompanionState> {
        self.hysteresis.committed_state()
    }
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum StreamConfigError {
    Smoother(SmootherError),
    Hysteresis(HysteresisError),
}

#[cfg(test)]
mod tests {
    use super::*;

    fn sig(hrv: f32, coh: f32, ar: f32) -> BiometricSignal {
        BiometricSignal::new(hrv, coh, ar).unwrap()
    }

    #[test]
    fn alpha_zero_rejected() {
        assert!(matches!(
            EmaSmoother::new(0.0).unwrap_err(),
            SmootherError::AlphaOutOfRange { .. }
        ));
    }

    #[test]
    fn alpha_above_one_rejected() {
        assert!(matches!(
            EmaSmoother::new(1.5).unwrap_err(),
            SmootherError::AlphaOutOfRange { .. }
        ));
    }

    #[test]
    fn alpha_nan_rejected() {
        assert!(EmaSmoother::new(f32::NAN).is_err());
    }

    #[test]
    fn first_sample_passes_through() {
        let mut sm = EmaSmoother::new(0.5).unwrap();
        let s = sig(40.0, 0.5, 0.5);
        let out = sm.observe(s);
        assert_eq!(out, s);
    }

    #[test]
    fn second_sample_blends_50_50() {
        let mut sm = EmaSmoother::new(0.5).unwrap();
        sm.observe(sig(40.0, 0.4, 0.4));
        let out = sm.observe(sig(80.0, 0.8, 0.8));
        assert!((out.hrv_rmssd_ms - 60.0).abs() < 1e-4);
        assert!((out.coherence_ratio - 0.6).abs() < 1e-4);
        assert!((out.arousal_normalized - 0.6).abs() < 1e-4);
    }

    #[test]
    fn alpha_one_passes_through_every_sample() {
        let mut sm = EmaSmoother::new(1.0).unwrap();
        let a = sig(40.0, 0.4, 0.4);
        let b = sig(80.0, 0.8, 0.8);
        assert_eq!(sm.observe(a), a);
        assert_eq!(sm.observe(b), b);
    }

    #[test]
    fn reset_clears_history() {
        let mut sm = EmaSmoother::new(0.5).unwrap();
        sm.observe(sig(40.0, 0.5, 0.5));
        sm.reset();
        assert_eq!(sm.current(), None);
        let s = sig(10.0, 0.1, 0.1);
        assert_eq!(sm.observe(s), s);
    }

    #[test]
    fn smoother_roundtrips_through_serde_json() {
        let mut sm = EmaSmoother::new(0.5).unwrap();
        sm.observe(sig(40.0, 0.5, 0.5));
        let json = serde_json::to_string(&sm).unwrap();
        let back: EmaSmoother = serde_json::from_str(&json).unwrap();
        assert_eq!(sm, back);
    }

    #[test]
    fn hold_zero_rejected() {
        assert_eq!(StateHysteresis::new(0).unwrap_err(), HysteresisError::ZeroHold);
    }

    #[test]
    fn hold_one_commits_immediately() {
        let mut h = StateHysteresis::new(1).unwrap();
        assert_eq!(h.observe(CompanionState::Calm), CompanionState::Calm);
        assert_eq!(h.observe(CompanionState::Focused), CompanionState::Focused);
    }

    #[test]
    fn hold_three_requires_three_in_a_row() {
        let mut h = StateHysteresis::new(3).unwrap();
        assert_eq!(h.observe(CompanionState::Calm), CompanionState::Calm);
        assert_eq!(h.observe(CompanionState::Focused), CompanionState::Calm);
        assert_eq!(h.observe(CompanionState::Focused), CompanionState::Calm);
        assert_eq!(h.observe(CompanionState::Focused), CompanionState::Focused);
    }

    #[test]
    fn candidate_run_resets_on_interrupt() {
        let mut h = StateHysteresis::new(3).unwrap();
        h.observe(CompanionState::Calm);
        h.observe(CompanionState::Focused);
        h.observe(CompanionState::Focused);
        h.observe(CompanionState::Excited);
        assert_eq!(h.committed_state(), Some(CompanionState::Calm));
        assert_eq!(h.candidate_run_length(), 1);
    }

    #[test]
    fn same_as_committed_clears_candidate() {
        let mut h = StateHysteresis::new(3).unwrap();
        h.observe(CompanionState::Calm);
        h.observe(CompanionState::Focused);
        h.observe(CompanionState::Focused);
        h.observe(CompanionState::Calm);
        assert_eq!(h.committed_state(), Some(CompanionState::Calm));
        assert_eq!(h.candidate_run_length(), 0);
    }

    #[test]
    fn end_to_end_stream_smooths_and_holds() {
        // alpha=0.9 lets the new sample dominate: 0.9*15 + 0.1*40 = 17.5,
        // so smoothed HRV drops below the 20 Stressed threshold after one
        // stressed sample. hold_samples=2 then forces the new state to be
        // observed twice before commit, so the second stressed sample is
        // what flips the committed state.
        let mut stream = SmoothedSignalStream::new(0.9, 2).unwrap();
        let calm = sig(40.0, 0.4, 0.4);
        let stressed = sig(15.0, 0.5, 0.5);
        assert_eq!(stream.observe(calm), CompanionState::Calm);
        assert_eq!(stream.observe(stressed), CompanionState::Calm);
        assert_eq!(stream.observe(stressed), CompanionState::Stressed);
        assert_eq!(stream.committed_state(), Some(CompanionState::Stressed));
    }

    #[test]
    fn stream_config_errors_propagate() {
        assert!(matches!(
            SmoothedSignalStream::new(0.0, 2).unwrap_err(),
            StreamConfigError::Smoother(_)
        ));
        assert!(matches!(
            SmoothedSignalStream::new(0.5, 0).unwrap_err(),
            StreamConfigError::Hysteresis(_)
        ));
    }
}
