//! Source: `docs/fusion/jordan's research/ternary kernel.md` §"Live activation
//! capture kernel" — "One tiny side-effect kernel to copy selected activations
//! to a shared ring buffer for the control room."
//!
//! # Wave J1 kernel #6 — Live activation capture (CPU reference)
//!
//! The control room needs to compare ternary outputs against floating-point
//! gold without bloating the hot path. The activation tap is the substrate
//! that collects per-step snapshots of selected channels into a fixed-size
//! ring buffer (FIFO eviction). Hot-path overhead is one slice copy per
//! recorded step; the control-room UI / replay layer drains snapshots
//! asynchronously via [`ActivationTap::snapshot`].
//!
//! Captured activations are fp32 by design — the comparison-against-gold
//! workflow needs full precision; ternarizing the tap would defeat the
//! purpose. The naming hangs off the ternary research lane because that's
//! where the tap originates, not because the captured values are ternary.
//!
//! Metal port of this kernel writes into an on-GPU `device float*` ring;
//! the Swift control-room layer maps the buffer to host memory for
//! visualization. That dispatch wire-in lives outside this substrate floor.

use serde::{Deserialize, Serialize};
use std::collections::VecDeque;

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct ActivationTap {
    capacity: usize,
    captured_channels: Vec<usize>,
    samples: VecDeque<Vec<f32>>,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum ActivationTapError {
    /// Capacity of zero is rejected — the ring can never hold anything,
    /// so we surface the configuration error instead of silently dropping.
    ZeroCapacity,
    /// A configured channel index was outside `0..activations.len()` at
    /// record-time. Channel set is fixed at tap construction so the
    /// channel-index validation happens once per record, not per channel.
    ChannelOutOfRange { channel: usize, input_len: usize },
}

impl ActivationTap {
    /// Build a new tap. `captured_channels` is the fixed set of channel
    /// indices to record on each [`Self::record`] call; an empty channel
    /// list is valid and results in a no-op tap (useful for disabling
    /// instrumentation at runtime without pulling the tap out of the
    /// call graph).
    pub fn new(capacity: usize, captured_channels: Vec<usize>) -> Result<Self, ActivationTapError> {
        if capacity == 0 {
            return Err(ActivationTapError::ZeroCapacity);
        }
        Ok(Self {
            capacity,
            captured_channels,
            samples: VecDeque::with_capacity(capacity),
        })
    }

    /// Record one snapshot of the selected channels. Older samples are
    /// evicted FIFO once the ring is full.
    pub fn record(&mut self, activations: &[f32]) -> Result<(), ActivationTapError> {
        if self.captured_channels.is_empty() {
            return Ok(());
        }
        for &ch in &self.captured_channels {
            if ch >= activations.len() {
                return Err(ActivationTapError::ChannelOutOfRange {
                    channel: ch,
                    input_len: activations.len(),
                });
            }
        }
        let mut snapshot = Vec::with_capacity(self.captured_channels.len());
        for &ch in &self.captured_channels {
            snapshot.push(activations[ch]);
        }
        if self.samples.len() == self.capacity {
            self.samples.pop_front();
        }
        self.samples.push_back(snapshot);
        Ok(())
    }

    pub fn len(&self) -> usize {
        self.samples.len()
    }

    pub fn is_empty(&self) -> bool {
        self.samples.is_empty()
    }

    pub fn capacity(&self) -> usize {
        self.capacity
    }

    pub fn captured_channels(&self) -> &[usize] {
        &self.captured_channels
    }

    /// Borrow the current ring contents in FIFO order (oldest first).
    pub fn snapshot(&self) -> &VecDeque<Vec<f32>> {
        &self.samples
    }

    pub fn clear(&mut self) {
        self.samples.clear();
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn zero_capacity_rejected() {
        let err = ActivationTap::new(0, vec![0]).unwrap_err();
        assert_eq!(err, ActivationTapError::ZeroCapacity);
    }

    #[test]
    fn empty_channel_set_makes_record_a_noop() {
        let mut tap = ActivationTap::new(4, vec![]).unwrap();
        tap.record(&[1.0, 2.0, 3.0]).unwrap();
        tap.record(&[4.0, 5.0, 6.0]).unwrap();
        assert!(tap.is_empty());
        assert_eq!(tap.len(), 0);
    }

    #[test]
    fn single_channel_fifo_eviction_at_capacity() {
        let mut tap = ActivationTap::new(3, vec![0]).unwrap();
        for i in 0..5 {
            tap.record(&[i as f32, 99.0]).unwrap();
        }
        assert_eq!(tap.len(), 3);
        let samples: Vec<f32> =
            tap.snapshot().iter().map(|s| s[0]).collect();
        assert_eq!(samples, vec![2.0, 3.0, 4.0]);
    }

    #[test]
    fn multi_channel_snapshot_preserves_order() {
        let mut tap = ActivationTap::new(2, vec![2, 0, 1]).unwrap();
        tap.record(&[10.0, 20.0, 30.0, 40.0]).unwrap();
        let snap = tap.snapshot();
        assert_eq!(snap.front().unwrap(), &vec![30.0, 10.0, 20.0]);
    }

    #[test]
    fn channel_out_of_range_errors() {
        let mut tap = ActivationTap::new(4, vec![0, 5]).unwrap();
        let err = tap.record(&[1.0, 2.0]).unwrap_err();
        assert_eq!(
            err,
            ActivationTapError::ChannelOutOfRange { channel: 5, input_len: 2 }
        );
    }

    #[test]
    fn clear_resets_to_empty_without_dropping_config() {
        let mut tap = ActivationTap::new(3, vec![0, 1]).unwrap();
        tap.record(&[1.0, 2.0, 3.0]).unwrap();
        tap.record(&[4.0, 5.0, 6.0]).unwrap();
        assert_eq!(tap.len(), 2);
        tap.clear();
        assert!(tap.is_empty());
        assert_eq!(tap.capacity(), 3);
        assert_eq!(tap.captured_channels(), &[0, 1]);
    }

    #[test]
    fn capacity_and_channels_accessors_reflect_constructor() {
        let tap = ActivationTap::new(8, vec![3, 7, 11]).unwrap();
        assert_eq!(tap.capacity(), 8);
        assert_eq!(tap.captured_channels(), &[3, 7, 11]);
    }

    #[test]
    fn record_at_exact_capacity_writes_then_evicts_on_next() {
        let mut tap = ActivationTap::new(2, vec![0]).unwrap();
        tap.record(&[1.0]).unwrap();
        tap.record(&[2.0]).unwrap();
        assert_eq!(tap.len(), 2);
        tap.record(&[3.0]).unwrap();
        let samples: Vec<f32> =
            tap.snapshot().iter().map(|s| s[0]).collect();
        assert_eq!(samples, vec![2.0, 3.0]);
    }
}
