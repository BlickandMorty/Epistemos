//! Source: `docs/fusion/jordan's research/ternary kernel.md` §"Steering delta
//! apply kernel" — "A tiny kernel that adds or removes small dense steering
//! vectors or residual patches, layer by layer, without reloading the model.
//! That becomes the mechanism behind 'manual information implantation,'
//! 'behavior sliders,' and safe experimental editing."
//!
//! Related upstream: Representation Engineering (RepE) literature — Zou et al.
//! 2023 "Representation Engineering: A Top-Down Approach to AI Transparency",
//! arXiv:2310.01405 — activation steering as a mechanism for behavior control.
//!
//! # Wave J1 kernel #7 — Steering delta apply (final of 7-kernel portfolio)
//!
//! Each [`SteeringDelta`] is a sparse fp32 vector (channel-indexed). A
//! [`SteeringStack`] composes multiple deltas with per-delta gains, applied
//! linearly to a target activation slice. Push/pop semantics let the
//! control room snap deltas in and out without re-loading the model.
//!
//! Linearity: applying then removing the same delta is a no-op (within
//! fp32 precision). Multiple deltas accumulate additively. Negative gain
//! is the canonical "remove" form.
//!
//! Per the doctrine, this is the substrate beneath three control-room
//! features:
//! - **Manual information implantation** — push a vector that pulls
//!   activations toward a target concept.
//! - **Behavior sliders** — bind a delta to a UI slider, apply with
//!   `slider_value` as the gain.
//! - **Safe experimental editing** — push a delta with `gain = 1.0`,
//!   evaluate, pop it back out if it misbehaves.

use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, Default, PartialEq, Serialize, Deserialize)]
pub struct SteeringDelta {
    /// Sparse `(channel_index, delta_value)` pairs. No uniqueness or
    /// ordering requirement; duplicate channels simply double-apply.
    pub entries: Vec<(usize, f32)>,
}

#[derive(Clone, Debug, Default, PartialEq, Serialize, Deserialize)]
pub struct SteeringStack {
    deltas: Vec<(SteeringDelta, f32)>,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum SteeringError {
    /// A delta entry referenced a channel outside `0..activations.len()`.
    ChannelOutOfRange { channel: usize, input_len: usize },
}

impl SteeringStack {
    pub fn new() -> Self {
        Self { deltas: Vec::new() }
    }

    pub fn push(&mut self, delta: SteeringDelta, gain: f32) {
        self.deltas.push((delta, gain));
    }

    pub fn pop(&mut self) -> Option<(SteeringDelta, f32)> {
        self.deltas.pop()
    }

    pub fn len(&self) -> usize {
        self.deltas.len()
    }

    pub fn is_empty(&self) -> bool {
        self.deltas.is_empty()
    }

    pub fn clear(&mut self) {
        self.deltas.clear();
    }

    /// Apply every (delta, gain) in stack order to `activations` in place.
    /// Validates all channel indices up front so a partial apply never
    /// occurs (either every delta lands or none does).
    pub fn apply(&self, activations: &mut [f32]) -> Result<(), SteeringError> {
        for (delta, _gain) in &self.deltas {
            for &(ch, _) in &delta.entries {
                if ch >= activations.len() {
                    return Err(SteeringError::ChannelOutOfRange {
                        channel: ch,
                        input_len: activations.len(),
                    });
                }
            }
        }
        for (delta, gain) in &self.deltas {
            for &(ch, val) in &delta.entries {
                activations[ch] += gain * val;
            }
        }
        Ok(())
    }
}

/// Standalone helper for applying a single delta without stacking. Useful
/// when the caller wants the apply primitive without the composition
/// machinery (e.g. one-shot implant from a UI action).
pub fn apply_delta(
    activations: &mut [f32],
    delta: &SteeringDelta,
    gain: f32,
) -> Result<(), SteeringError> {
    for &(ch, _) in &delta.entries {
        if ch >= activations.len() {
            return Err(SteeringError::ChannelOutOfRange {
                channel: ch,
                input_len: activations.len(),
            });
        }
    }
    for &(ch, val) in &delta.entries {
        activations[ch] += gain * val;
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn delta(entries: Vec<(usize, f32)>) -> SteeringDelta {
        SteeringDelta { entries }
    }

    #[test]
    fn empty_stack_leaves_activations_unchanged() {
        let stack = SteeringStack::new();
        let mut a = vec![1.0, 2.0, 3.0];
        stack.apply(&mut a).unwrap();
        assert_eq!(a, vec![1.0, 2.0, 3.0]);
    }

    #[test]
    fn single_delta_unit_gain_adds_directly() {
        let mut stack = SteeringStack::new();
        stack.push(delta(vec![(0, 0.5), (2, -1.0)]), 1.0);
        let mut a = vec![1.0, 2.0, 3.0];
        stack.apply(&mut a).unwrap();
        assert_eq!(a, vec![1.5, 2.0, 2.0]);
    }

    #[test]
    fn gain_scales_delta() {
        let mut stack = SteeringStack::new();
        stack.push(delta(vec![(0, 2.0)]), 0.25);
        let mut a = vec![1.0, 0.0];
        stack.apply(&mut a).unwrap();
        assert_eq!(a, vec![1.5, 0.0]);
    }

    #[test]
    fn negative_gain_subtracts() {
        let mut stack = SteeringStack::new();
        stack.push(delta(vec![(1, 1.0)]), -1.0);
        let mut a = vec![5.0, 5.0];
        stack.apply(&mut a).unwrap();
        assert_eq!(a, vec![5.0, 4.0]);
    }

    #[test]
    fn multiple_deltas_accumulate_additively() {
        let mut stack = SteeringStack::new();
        stack.push(delta(vec![(0, 1.0)]), 1.0);
        stack.push(delta(vec![(0, 2.0)]), 1.0);
        let mut a = vec![10.0];
        stack.apply(&mut a).unwrap();
        assert_eq!(a, vec![13.0]);
    }

    #[test]
    fn apply_then_remove_is_no_op() {
        let mut stack = SteeringStack::new();
        let d = delta(vec![(0, 0.7), (1, -0.3)]);
        stack.push(d.clone(), 1.0);
        let mut a = vec![1.0, 2.0];
        stack.apply(&mut a).unwrap();
        stack.clear();
        stack.push(d, -1.0);
        stack.apply(&mut a).unwrap();
        assert!((a[0] - 1.0).abs() < 1e-6);
        assert!((a[1] - 2.0).abs() < 1e-6);
    }

    #[test]
    fn channel_out_of_range_errors_before_any_apply() {
        let mut stack = SteeringStack::new();
        stack.push(delta(vec![(0, 1.0)]), 1.0);
        stack.push(delta(vec![(99, 1.0)]), 1.0);
        let mut a = vec![5.0, 5.0];
        let err = stack.apply(&mut a).unwrap_err();
        assert_eq!(
            err,
            SteeringError::ChannelOutOfRange { channel: 99, input_len: 2 }
        );
        assert_eq!(a, vec![5.0, 5.0]);
    }

    #[test]
    fn pop_returns_last_pushed_and_decrements_len() {
        let mut stack = SteeringStack::new();
        stack.push(delta(vec![(0, 1.0)]), 1.0);
        stack.push(delta(vec![(1, 2.0)]), 0.5);
        assert_eq!(stack.len(), 2);
        let (popped, gain) = stack.pop().unwrap();
        assert_eq!(popped.entries, vec![(1, 2.0)]);
        assert_eq!(gain, 0.5);
        assert_eq!(stack.len(), 1);
    }

    #[test]
    fn duplicate_channel_double_applies() {
        let mut stack = SteeringStack::new();
        stack.push(delta(vec![(0, 1.0), (0, 1.0)]), 1.0);
        let mut a = vec![0.0];
        stack.apply(&mut a).unwrap();
        assert_eq!(a, vec![2.0]);
    }

    #[test]
    fn standalone_apply_delta_matches_stack_with_single_entry() {
        let d = delta(vec![(0, 0.5), (1, -0.5)]);
        let mut a_stack = vec![1.0, 2.0];
        let mut stack = SteeringStack::new();
        stack.push(d.clone(), 2.0);
        stack.apply(&mut a_stack).unwrap();

        let mut a_solo = vec![1.0, 2.0];
        apply_delta(&mut a_solo, &d, 2.0).unwrap();

        assert_eq!(a_stack, a_solo);
    }

    #[test]
    fn standalone_apply_delta_validates_oob() {
        let d = delta(vec![(99, 1.0)]);
        let mut a = vec![0.0; 2];
        let err = apply_delta(&mut a, &d, 1.0).unwrap_err();
        assert_eq!(
            err,
            SteeringError::ChannelOutOfRange { channel: 99, input_len: 2 }
        );
    }
}
