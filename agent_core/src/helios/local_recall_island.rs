//! Source:
//! - `docs/fusion/helios v6.2.md` 8-stage falsifier §7 —
//!   LocalRecallIsland.metal 32K Core acceptance: 50 trials × 5 depths
//!   passkey ≥ 0.95, niah_single_1 ≥ 0.95.
//! - Mohtashami & Jaggi, "Landmark Attention: Random-Access Infinite
//!   Context Length for Transformers", arXiv:2305.16300, 2023 — the
//!   passkey-retrieval benchmark methodology.
//! - Hsieh et al., "RULER: What's the Real Context Size of Your
//!   Long-Context Language Models?", arXiv:2404.06654, 2024 — niah
//!   (needle-in-a-haystack) `niah_single_1` task definition.
//!
//! # Helios stage 7 — LocalRecallIsland passkey-retrieval substrate
//!
//! Substrate-floor harness for the stage-7 acceptance bar. Owns:
//!
//! - [`RecallStore`] — a fixed-capacity append-only window of
//!   `(position, token)` pairs, the substrate-floor analog of the
//!   32K-token Core context.
//! - [`passkey_retrieve`] — given a numeric `key` (the "passkey"),
//!   returns the position it was inserted at, or `None` if absent.
//! - [`run_passkey_trials`] — runs `n_trials × depths` trials and
//!   reports per-depth recall rate. The 0.95 acceptance bar from
//!   stage 7 is a downstream check on the returned [`RecallReport`].
//!
//! Real validation needs a live 32K-context model + the niah_single_1
//! prompt template; substrate floor here is the harness shape that
//! Wave J9 paper_registry seeds and that the Swift falsifier driver
//! will call into once the Metal kernel + Swift wire-in lands.

use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct RecallStore {
    pub capacity: usize,
    pub tokens: Vec<(usize, u64)>,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum RecallError {
    ZeroCapacity,
    CapacityExceeded { capacity: usize, attempted_len: usize },
    InvalidDepth { depth: f32 },
    NoTrials,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct RecallReport {
    pub per_depth_recall: Vec<f32>,
    pub overall_recall: f32,
    pub trials_per_depth: usize,
    pub depths: Vec<f32>,
}

impl RecallReport {
    pub fn meets_threshold(&self, threshold: f32) -> bool {
        self.per_depth_recall.iter().all(|&r| r >= threshold)
    }
}

impl RecallStore {
    pub fn new(capacity: usize) -> Result<Self, RecallError> {
        if capacity == 0 {
            return Err(RecallError::ZeroCapacity);
        }
        Ok(Self { capacity, tokens: Vec::new() })
    }

    pub fn insert(&mut self, position: usize, token: u64) -> Result<(), RecallError> {
        if self.tokens.len() >= self.capacity {
            return Err(RecallError::CapacityExceeded {
                capacity: self.capacity,
                attempted_len: self.tokens.len() + 1,
            });
        }
        self.tokens.push((position, token));
        Ok(())
    }

    pub fn len(&self) -> usize {
        self.tokens.len()
    }

    pub fn is_empty(&self) -> bool {
        self.tokens.is_empty()
    }

    pub fn clear(&mut self) {
        self.tokens.clear();
    }
}

/// Find the position the given numeric `key` was inserted at. Returns
/// the position of the *first* match (single-needle semantics per
/// `niah_single_1`).
pub fn passkey_retrieve(store: &RecallStore, key: u64) -> Option<usize> {
    store
        .tokens
        .iter()
        .find(|(_, t)| *t == key)
        .map(|(p, _)| *p)
}

/// Generate a synthetic context of length `context_len`, insert
/// `key` at the position computed from `depth ∈ [0.0, 1.0]`, and try
/// to retrieve it. Returns `true` iff retrieval found the right
/// position.
pub fn single_passkey_trial(
    context_len: usize,
    depth: f32,
    key: u64,
) -> Result<bool, RecallError> {
    if !(0.0..=1.0).contains(&depth) {
        return Err(RecallError::InvalidDepth { depth });
    }
    if context_len == 0 {
        return Err(RecallError::ZeroCapacity);
    }
    let mut store = RecallStore::new(context_len)?;
    let insert_pos = ((depth * (context_len.saturating_sub(1)) as f32).round() as usize)
        .min(context_len - 1);
    for i in 0..context_len {
        let token = if i == insert_pos { key } else { (i as u64).wrapping_add(1) };
        store.insert(i, token)?;
    }
    Ok(passkey_retrieve(&store, key) == Some(insert_pos))
}

/// Run `n_trials × depths.len()` passkey trials and report per-depth
/// recall rate. Acceptance against the stage-7 bar (0.95) is a
/// downstream check via [`RecallReport::meets_threshold`].
pub fn run_passkey_trials(
    context_len: usize,
    depths: &[f32],
    n_trials: usize,
    key_base: u64,
) -> Result<RecallReport, RecallError> {
    if depths.is_empty() {
        return Err(RecallError::NoTrials);
    }
    if n_trials == 0 {
        return Err(RecallError::NoTrials);
    }
    let mut per_depth = Vec::with_capacity(depths.len());
    let mut total_pass: usize = 0;
    let mut total_trials: usize = 0;
    for (d_idx, &depth) in depths.iter().enumerate() {
        let mut passes: usize = 0;
        for t in 0..n_trials {
            let key = key_base
                .wrapping_add((d_idx as u64) << 32)
                .wrapping_add(t as u64)
                .wrapping_add(u64::MAX / 2);
            if single_passkey_trial(context_len, depth, key)? {
                passes += 1;
            }
        }
        let rate = (passes as f32) / (n_trials as f32);
        per_depth.push(rate);
        total_pass += passes;
        total_trials += n_trials;
    }
    let overall = (total_pass as f32) / (total_trials as f32);
    Ok(RecallReport {
        per_depth_recall: per_depth,
        overall_recall: overall,
        trials_per_depth: n_trials,
        depths: depths.to_vec(),
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn store_zero_capacity_rejected() {
        let err = RecallStore::new(0).unwrap_err();
        assert_eq!(err, RecallError::ZeroCapacity);
    }

    #[test]
    fn store_insert_and_retrieve_roundtrip() {
        let mut s = RecallStore::new(8).unwrap();
        s.insert(3, 42).unwrap();
        assert_eq!(passkey_retrieve(&s, 42), Some(3));
        assert_eq!(passkey_retrieve(&s, 99), None);
    }

    #[test]
    fn store_capacity_exceeded_errors() {
        let mut s = RecallStore::new(2).unwrap();
        s.insert(0, 1).unwrap();
        s.insert(1, 2).unwrap();
        let err = s.insert(2, 3).unwrap_err();
        assert_eq!(
            err,
            RecallError::CapacityExceeded { capacity: 2, attempted_len: 3 }
        );
    }

    #[test]
    fn single_trial_invalid_depth_errors() {
        let err = single_passkey_trial(10, -0.1, 999).unwrap_err();
        assert_eq!(err, RecallError::InvalidDepth { depth: -0.1 });
        let err = single_passkey_trial(10, 1.5, 999).unwrap_err();
        assert_eq!(err, RecallError::InvalidDepth { depth: 1.5 });
    }

    #[test]
    fn single_trial_passes_for_substrate_floor_retrieval() {
        // Substrate floor uses exact-match retrieval, so it should
        // pass at every depth as long as the key is distinguishable
        // from the generated tokens (key = ::MAX / 2 + offset).
        for depth in &[0.0_f32, 0.25, 0.5, 0.75, 1.0] {
            assert!(single_passkey_trial(64, *depth, u64::MAX / 2 + 1).unwrap());
        }
    }

    #[test]
    fn run_passkey_trials_empty_depths_errors() {
        let err = run_passkey_trials(32, &[], 5, 0).unwrap_err();
        assert_eq!(err, RecallError::NoTrials);
    }

    #[test]
    fn run_passkey_trials_zero_trials_errors() {
        let err = run_passkey_trials(32, &[0.5], 0, 0).unwrap_err();
        assert_eq!(err, RecallError::NoTrials);
    }

    #[test]
    fn run_passkey_trials_substrate_floor_meets_threshold() {
        let depths = vec![0.0_f32, 0.25, 0.5, 0.75, 1.0];
        let report = run_passkey_trials(128, &depths, 10, 0).unwrap();
        assert_eq!(report.per_depth_recall.len(), 5);
        assert!(report.meets_threshold(0.95));
        assert!(report.overall_recall >= 0.95);
    }

    #[test]
    fn report_meets_threshold_requires_all_depths() {
        let r = RecallReport {
            per_depth_recall: vec![1.0, 0.9, 1.0],
            overall_recall: 0.967,
            trials_per_depth: 10,
            depths: vec![0.0, 0.5, 1.0],
        };
        assert!(!r.meets_threshold(0.95));
        assert!(r.meets_threshold(0.85));
    }

    #[test]
    fn store_serializes_through_serde_json() {
        let mut s = RecallStore::new(4).unwrap();
        s.insert(0, 1).unwrap();
        s.insert(1, 2).unwrap();
        let json = serde_json::to_string(&s).unwrap();
        let back: RecallStore = serde_json::from_str(&json).unwrap();
        assert_eq!(s, back);
    }

    #[test]
    fn report_serializes_through_serde_json() {
        let r = RecallReport {
            per_depth_recall: vec![1.0, 0.95],
            overall_recall: 0.975,
            trials_per_depth: 10,
            depths: vec![0.0, 1.0],
        };
        let json = serde_json::to_string(&r).unwrap();
        let back: RecallReport = serde_json::from_str(&json).unwrap();
        assert_eq!(r, back);
    }

    #[test]
    fn store_clear_resets_to_empty() {
        let mut s = RecallStore::new(4).unwrap();
        s.insert(0, 1).unwrap();
        s.insert(1, 2).unwrap();
        assert_eq!(s.len(), 2);
        s.clear();
        assert!(s.is_empty());
        assert_eq!(s.capacity, 4);
    }

    #[test]
    fn passkey_retrieve_returns_first_match_on_duplicates() {
        let mut s = RecallStore::new(8).unwrap();
        s.insert(3, 42).unwrap();
        s.insert(5, 42).unwrap();
        assert_eq!(passkey_retrieve(&s, 42), Some(3));
    }

    #[test]
    fn run_passkey_trials_short_context_still_runs() {
        let depths = vec![0.5_f32];
        let report = run_passkey_trials(4, &depths, 3, 0).unwrap();
        assert_eq!(report.trials_per_depth, 3);
        assert_eq!(report.per_depth_recall.len(), 1);
    }
}
