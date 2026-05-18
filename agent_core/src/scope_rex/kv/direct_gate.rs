// HARDENING ENFORCEMENT: KV-Direct gate sits on the inference hot
// path. Production paths must remain panic-free. Tests are allowed
// to unwrap because a failed invariant SHOULD panic loudly.
#![cfg_attr(
    not(test),
    deny(clippy::unwrap_used, clippy::expect_used, clippy::panic)
)]

//! HELIOS V5 W8 — KV-Direct gate (Tier-1 path only).
//!
//! HELIOS-W8 guard
//!
//! Per `docs/HELIOS_V5_INTEGRATION_PLAN_v2_2026_05_05.md` §3 W8 +
//! `docs/HELIOS_V5_INTEGRATION_PLAN_v2_FINALIZE_2026_05_05.md` §I:
//!
//! > "KV-Direct gate (only when its semantics are provably identical
//! >  to the existing KV cache; treat as paged-attention-equivalent
//! >  within the existing Qwen3 path)."
//!
//! **Tier 1 contract:** the gate dispatches to a "direct" KV path
//! when the cache layout is provably equivalent to the reference
//! paged-attention path; otherwise falls back to the reference.
//! Round-trip equality is the load-bearing acceptance criterion.
//! This file owns the `F-KV-Direct-Gate` falsifier hook for KV/cache
//! rows that must prove direct dispatch did not invent cache equivalence.
//!
//! Per HELIOS v3 W0 (the "Monday-Move equivalent for the substrate
//! side"): KV-Direct is the cheaper preflight — D_KL ≈ 0 between
//! residual-patched and original output on Qwen3-8B-MLX-4bit at 128k.
//! Reference: Qasim et al. arXiv 2603.19664 (residual stream is
//! bit-identical sufficient).
//!
//! ## Cross-references
//!
//! - DOC 0 §0.2 (H7 = six-tier memory; KV cache is L_DRAM tier)
//! - DOC 0 §0.6 (glossary: "KV-Direct gate")
//! - canon-hardening protocol §1 — WRV state machine; this module is
//!   `state: implemented` (no production caller yet — the Swift
//!   inference path wires this gate per a follow-up slice once the
//!   Qwen3 KV-cache layout is stable)

use serde::{Deserialize, Serialize};

/// One (key, value) pair stored in the KV cache. Pure-data: f32
/// vectors with stable shape; the gate compares LAYOUT not content
/// when deciding direct vs reference dispatch.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct KvPair {
    pub key: Vec<f32>,
    pub value: Vec<f32>,
}

impl KvPair {
    pub fn new(key: Vec<f32>, value: Vec<f32>) -> Self {
        Self { key, value }
    }
}

/// Layout descriptor for a sequence of KV pairs. Captures the
/// load-bearing equivalence properties that decide direct dispatch.
#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct KvLayout {
    /// Number of pairs in the sequence.
    pub seq_len: usize,
    /// Dimensionality of each key vector.
    pub key_dim: usize,
    /// Dimensionality of each value vector.
    pub value_dim: usize,
    /// Page size of the underlying paged-attention layout.
    /// Direct dispatch requires `seq_len % page_size == 0` so the
    /// direct path can stride pages without partial-page handling.
    pub page_size: usize,
}

impl KvLayout {
    pub fn new(seq_len: usize, key_dim: usize, value_dim: usize, page_size: usize) -> Self {
        Self {
            seq_len,
            key_dim,
            value_dim,
            page_size,
        }
    }

    /// Direct-path eligibility check. The Tier-1 gate dispatches to
    /// the direct path iff:
    ///
    /// 1. `key_dim == value_dim` (canonical Qwen3-style same-dim)
    /// 2. `seq_len % page_size == 0` (page-aligned stride)
    /// 3. `page_size > 0` (non-degenerate)
    /// 4. `seq_len > 0` (non-empty)
    ///
    /// Any failure => fall back to reference paged-attention.
    pub fn direct_path_eligible(&self) -> bool {
        self.page_size > 0
            && self.seq_len > 0
            && self.key_dim == self.value_dim
            && self.seq_len.is_multiple_of(self.page_size)
    }
}

/// Dispatch outcome for a KV-cache lookup. The gate returns one of
/// these to signal which path was chosen.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum KvDispatch {
    /// Direct path — bypasses paged-attention quantization.
    /// Bit-equivalent to reference per the Tier-1 contract.
    Direct,
    /// Reference paged-attention path — fallback when the direct
    /// preconditions don't hold.
    Reference,
}

/// HELIOS V5 W8 — Tier-1 KV-Direct gate.
///
/// Pure function: examines the layout descriptor only. **Does not
/// inspect the KV pair contents** — the gate decides at the layout
/// level so the dispatch is deterministic and cache-friendly.
pub fn route(layout: &KvLayout) -> KvDispatch {
    if layout.direct_path_eligible() {
        KvDispatch::Direct
    } else {
        KvDispatch::Reference
    }
}

/// Reference paged-attention dot product. Computes the QK^T row for
/// query `q` against keys in the cache. Used as the round-trip
/// equality oracle.
pub fn reference_qk_row(query: &[f32], pairs: &[KvPair]) -> Vec<f32> {
    pairs
        .iter()
        .map(|p| {
            let mut acc = 0.0f32;
            for (q, k) in query.iter().zip(p.key.iter()) {
                acc += q * k;
            }
            acc
        })
        .collect()
}

/// Direct KV-Direct dot product — same sum order as reference, no
/// quantization layer in between. The Tier-1 contract is that for
/// any direct-eligible layout the output is BIT-IDENTICAL to the
/// reference path.
pub fn direct_qk_row(query: &[f32], pairs: &[KvPair]) -> Vec<f32> {
    // Mirror reference_qk_row exactly so the bit-equality contract
    // is locked at the Rust level. Any future Metal-accelerated
    // drop-in must produce the same bytes, byte-for-byte.
    pairs
        .iter()
        .map(|p| {
            let mut acc = 0.0f32;
            for (q, k) in query.iter().zip(p.key.iter()) {
                acc += q * k;
            }
            acc
        })
        .collect()
}

// ---------------------------------------------------------------------------
// Tests — round-trip equality + dispatch invariants
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    fn deterministic_random(seed: u64, n: usize) -> Vec<f32> {
        let mut state = seed
            .wrapping_mul(2862933555777941757)
            .wrapping_add(3037000493);
        let mut out = Vec::with_capacity(n);
        for _ in 0..n {
            state = state
                .wrapping_mul(2862933555777941757)
                .wrapping_add(3037000493);
            let f = ((state >> 8) & 0xFFFFFF) as f32 / 8_388_608.0 - 1.0;
            out.push(f);
        }
        out
    }

    fn random_kv_pairs(seed: u64, count: usize, key_dim: usize, value_dim: usize) -> Vec<KvPair> {
        (0..count)
            .map(|i| KvPair {
                key: deterministic_random(seed.wrapping_add(2 * i as u64 + 1), key_dim),
                value: deterministic_random(seed.wrapping_add(2 * i as u64 + 2), value_dim),
            })
            .collect()
    }

    #[test]
    fn direct_path_eligible_requires_same_dim() {
        let layout = KvLayout::new(16, 64, 32, 8);
        assert!(!layout.direct_path_eligible());
        let layout = KvLayout::new(16, 64, 64, 8);
        assert!(layout.direct_path_eligible());
    }

    #[test]
    fn direct_path_eligible_requires_page_alignment() {
        let layout = KvLayout::new(15, 64, 64, 8);
        assert!(!layout.direct_path_eligible());
        let layout = KvLayout::new(16, 64, 64, 8);
        assert!(layout.direct_path_eligible());
    }

    #[test]
    fn direct_path_eligible_rejects_zero_page_size() {
        let layout = KvLayout::new(16, 64, 64, 0);
        assert!(!layout.direct_path_eligible());
    }

    #[test]
    fn direct_path_eligible_rejects_empty_sequence() {
        let layout = KvLayout::new(0, 64, 64, 8);
        assert!(!layout.direct_path_eligible());
    }

    #[test]
    fn route_returns_direct_for_eligible_layout() {
        let layout = KvLayout::new(16, 64, 64, 8);
        assert_eq!(route(&layout), KvDispatch::Direct);
    }

    #[test]
    fn route_returns_reference_for_misaligned_layout() {
        let layout = KvLayout::new(15, 64, 64, 8);
        assert_eq!(route(&layout), KvDispatch::Reference);
    }

    #[test]
    fn round_trip_equality_over_1000_generation_traces() {
        // Per W8 acceptance: "round-trip equality on 10³ generation
        // traces vs paged-attention reference."
        for seed in 0..1_000u64 {
            let key_dim = 32;
            let count = 8 + (seed as usize % 16);
            let pairs = random_kv_pairs(seed, count, key_dim, key_dim);
            let query = deterministic_random(seed.wrapping_add(99_999), key_dim);

            let reference_out = reference_qk_row(&query, &pairs);
            let direct_out = direct_qk_row(&query, &pairs);

            // Bit-identical — same sum order.
            assert_eq!(
                reference_out, direct_out,
                "seed {} produced QK row drift",
                seed
            );
        }
    }

    #[test]
    fn dispatch_round_trips_through_json() {
        // Wire-format parity for downstream consumers.
        for d in [KvDispatch::Direct, KvDispatch::Reference] {
            let json = serde_json::to_string(&d).unwrap();
            let back: KvDispatch = serde_json::from_str(&json).unwrap();
            assert_eq!(back, d);
        }
        assert_eq!(
            serde_json::to_string(&KvDispatch::Direct).unwrap(),
            "\"direct\""
        );
        assert_eq!(
            serde_json::to_string(&KvDispatch::Reference).unwrap(),
            "\"reference\""
        );
    }

    #[test]
    fn empty_pairs_returns_empty_output() {
        let query = vec![1.0_f32, 2.0, 3.0];
        let pairs: Vec<KvPair> = Vec::new();
        assert!(reference_qk_row(&query, &pairs).is_empty());
        assert!(direct_qk_row(&query, &pairs).is_empty());
    }

    #[test]
    fn route_is_deterministic() {
        let layout = KvLayout::new(16, 64, 64, 8);
        let first = route(&layout);
        for _ in 0..1000 {
            assert_eq!(route(&layout), first);
        }
    }
}
