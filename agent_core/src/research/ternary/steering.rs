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

    /// Look at the top of the stack without popping. Returns
    /// `(&delta, gain)` of the most-recently-pushed entry, or
    /// `None` if the stack is empty.
    pub fn peek(&self) -> Option<(&SteeringDelta, f32)> {
        self.deltas.last().map(|(d, g)| (d, *g))
    }

    /// Total `(channel, value)` entry count across every delta in the
    /// stack. Useful diagnostic for "how complex is the current
    /// steering configuration?".
    pub fn total_entries(&self) -> usize {
        self.deltas.iter().map(|(d, _)| d.entries.len()).sum()
    }

    /// Sum of every delta's gain. Returns 0.0 on empty stack. Signal
    /// for "is the steering pulling activations strongly?"; values
    /// near 0 mean cancelling deltas, large absolute values mean
    /// significant aggregate pull.
    pub fn total_gain_sum(&self) -> f32 {
        self.deltas.iter().map(|(_, g)| *g).sum()
    }

    /// Set of all channel indices touched by any delta in the stack.
    /// Useful for "what subset of activations will my apply touch?"
    /// before paying the apply cost. Returns sorted unique indices.
    pub fn affected_channels(&self) -> Vec<usize> {
        let mut s: std::collections::BTreeSet<usize> = std::collections::BTreeSet::new();
        for (delta, _) in &self.deltas {
            for &(ch, _) in &delta.entries {
                s.insert(ch);
            }
        }
        s.into_iter().collect()
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

    // ── peek + total_entries + total_gain_sum + affected_channels (iter 119) ─

    #[test]
    fn peek_empty_stack_returns_none() {
        let stack = SteeringStack::new();
        assert!(stack.peek().is_none());
    }

    #[test]
    fn peek_returns_last_pushed() {
        let mut stack = SteeringStack::new();
        stack.push(delta(vec![(0, 1.0)]), 0.5);
        stack.push(delta(vec![(1, 2.0)]), 0.7);
        let (d, g) = stack.peek().unwrap();
        assert_eq!(d.entries, vec![(1, 2.0)]);
        assert!((g - 0.7).abs() < 1e-6);
    }

    #[test]
    fn peek_does_not_pop() {
        let mut stack = SteeringStack::new();
        stack.push(delta(vec![(0, 1.0)]), 0.5);
        let _ = stack.peek();
        assert_eq!(stack.len(), 1);
    }

    #[test]
    fn total_entries_zero_on_empty_stack() {
        let stack = SteeringStack::new();
        assert_eq!(stack.total_entries(), 0);
    }

    #[test]
    fn total_entries_sums_across_deltas() {
        let mut stack = SteeringStack::new();
        stack.push(delta(vec![(0, 1.0), (1, 2.0)]), 1.0);
        stack.push(delta(vec![(2, 3.0)]), 0.5);
        stack.push(delta(vec![(3, 4.0), (4, 5.0), (5, 6.0)]), 0.1);
        assert_eq!(stack.total_entries(), 6);
    }

    #[test]
    fn total_gain_sum_zero_on_empty() {
        let stack = SteeringStack::new();
        assert_eq!(stack.total_gain_sum(), 0.0);
    }

    #[test]
    fn total_gain_sum_arithmetic() {
        let mut stack = SteeringStack::new();
        stack.push(delta(vec![(0, 1.0)]), 0.5);
        stack.push(delta(vec![(0, 1.0)]), -0.3);
        stack.push(delta(vec![(0, 1.0)]), 1.2);
        assert!((stack.total_gain_sum() - 1.4).abs() < 1e-6);
    }

    #[test]
    fn affected_channels_empty_on_empty_stack() {
        let stack = SteeringStack::new();
        assert!(stack.affected_channels().is_empty());
    }

    #[test]
    fn affected_channels_returns_sorted_unique() {
        let mut stack = SteeringStack::new();
        stack.push(delta(vec![(5, 1.0), (2, 1.0)]), 1.0);
        stack.push(delta(vec![(2, 1.0), (7, 1.0), (1, 1.0)]), 1.0);
        let ch = stack.affected_channels();
        // Sorted unique: 1, 2, 5, 7
        assert_eq!(ch, vec![1, 2, 5, 7]);
    }

    #[test]
    fn affected_channels_dedup_across_deltas() {
        let mut stack = SteeringStack::new();
        stack.push(delta(vec![(0, 1.0)]), 1.0);
        stack.push(delta(vec![(0, 2.0)]), 1.0);
        stack.push(delta(vec![(0, 3.0)]), 1.0);
        // Single channel 0 even though 3 deltas reference it.
        assert_eq!(stack.affected_channels(), vec![0]);
    }
}
