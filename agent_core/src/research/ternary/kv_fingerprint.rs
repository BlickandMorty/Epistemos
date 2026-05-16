//! Source: `docs/fusion/jordan's research/ternary kernel.md` §"Ternary KV
//! fingerprint kernel" — "Do **not** ternarize full KV cache first. Instead,
//! compute a **ternary fingerprint shadow** for each token or segment:
//! sign of dominant key channels · zero bucket for near-zero channels ·
//! small block scale metadata. This gives you retrieval / memory routing /
//! semantic dedupe / implant matching / cache selection without risking
//! core-generation quality."
//!
//! # Wave J1 kernel #5 — Ternary KV fingerprint
//!
//! A per-token ternary digest of the K vector. Channels with magnitude
//! above `threshold_ratio · max(|k|)` become `+1` or `-1` (preserving sign);
//! everything else collapses to `0`. The result packs into the same
//! [`super::pack`] format the other Wave J1 kernels use, so downstream
//! routing layers can compute Hamming-like distances cheaply.
//!
//! The doctrine deliberately keeps the full KV path floating-point —
//! ternarizing the live KV cache risks generation quality. The fingerprint
//! is a separate, parallel data structure used only by the routing layer.
//!
//! # Distance semantics
//!
//! Hamming distance on trit alphabets has three flavors:
//! - **Strict**: any pair `(Neg, Pos)` or `(Pos, Neg)` is one full
//!   "distance unit"; pairs with a zero (`Zero` vs `Neg`/`Pos`) are half a
//!   unit. [`fingerprint_distance`] uses this.
//! - Future work: weighted-by-channel-magnitude variant (deferred until a
//!   real routing layer needs it).

use super::pack::{pack_trits_u32, unpack_trits_u32, PackError, TRITS_PER_U32};
use super::trit::Trit;
use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct KvFingerprint {
    /// Packed trits, 16 per u32, LSB slot first.
    pub blocks: Vec<u32>,
    /// `max(|k|)` for the source K vector. Used as the small block scale
    /// metadata called out in the doctrine — preserved so the routing
    /// layer can normalize across tokens with different K magnitudes.
    pub max_abs: f32,
    /// Source channel count (pre-padding). The packed `blocks` may carry
    /// trailing `Trit::Zero` slots if `channel_count % 16 != 0`.
    pub channel_count: usize,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum FingerprintError {
    /// `threshold_ratio` was outside `[0.0, 1.0]`.
    ThresholdOutOfRange { ratio: f32 },
    /// `channel_count` did not match between two fingerprints in
    /// [`fingerprint_distance`].
    ChannelCountMismatch { left: usize, right: usize },
    /// Underlying pack error (unreachable on inputs produced by
    /// [`fingerprint_k_vector`] but reachable on tampered fingerprints).
    Pack(PackError),
}

impl From<PackError> for FingerprintError {
    fn from(err: PackError) -> Self {
        FingerprintError::Pack(err)
    }
}

/// Compute the ternary fingerprint of a K vector.
///
/// `threshold_ratio` controls sparsity: 0.0 keeps every non-zero channel
/// (extreme density); 1.0 keeps only the max-magnitude channel(s); typical
/// values are 0.1-0.3. The routing layer's recall/precision trade-off is
/// tuned via this ratio.
pub fn fingerprint_k_vector(
    k: &[f32],
    threshold_ratio: f32,
) -> Result<KvFingerprint, FingerprintError> {
    if !(0.0..=1.0).contains(&threshold_ratio) {
        return Err(FingerprintError::ThresholdOutOfRange { ratio: threshold_ratio });
    }
    if k.is_empty() {
        return Ok(KvFingerprint {
            blocks: Vec::new(),
            max_abs: 0.0,
            channel_count: 0,
        });
    }
    let max_abs = k.iter().fold(0.0_f32, |acc, &v| acc.max(v.abs()));
    let cutoff = threshold_ratio * max_abs;
    let trits: Vec<Trit> = k
        .iter()
        .map(|&v| {
            if v == 0.0 || v.abs() < cutoff || max_abs == 0.0 {
                Trit::Zero
            } else if v.is_sign_positive() {
                Trit::Pos
            } else {
                Trit::Neg
            }
        })
        .collect();
    let block_count = (trits.len() + TRITS_PER_U32 - 1) / TRITS_PER_U32;
    let mut blocks = Vec::with_capacity(block_count);
    for b in 0..block_count {
        let start = b * TRITS_PER_U32;
        let end = (start + TRITS_PER_U32).min(trits.len());
        blocks.push(pack_trits_u32(&trits[start..end])?);
    }
    Ok(KvFingerprint {
        blocks,
        max_abs,
        channel_count: k.len(),
    })
}

/// Sum of per-channel trit distances, scaled to 0.0..=1.0 by max possible.
///
/// Distance table (a, b):
/// - identical → 0
/// - one is `Zero`, the other isn't → 1
/// - opposite signs (`Neg` vs `Pos`) → 2
///
/// Maximum per-channel = 2; total max = `2 * channel_count`. Returned
/// value is the raw sum / max, so 0.0 = identical, 1.0 = every channel
/// flipped sign.
pub fn fingerprint_distance(
    a: &KvFingerprint,
    b: &KvFingerprint,
) -> Result<f32, FingerprintError> {
    if a.channel_count != b.channel_count {
        return Err(FingerprintError::ChannelCountMismatch {
            left: a.channel_count,
            right: b.channel_count,
        });
    }
    if a.channel_count == 0 {
        return Ok(0.0);
    }
    let mut total: u32 = 0;
    for (block_a, block_b) in a.blocks.iter().zip(b.blocks.iter()) {
        let trits_a = unpack_trits_u32(*block_a)?;
        let trits_b = unpack_trits_u32(*block_b)?;
        for (ta, tb) in trits_a.iter().zip(trits_b.iter()) {
            total += trit_pair_distance(*ta, *tb);
        }
    }
    let max = 2u32 * a.channel_count as u32;
    let trimmed = total.min(max);
    Ok((trimmed as f32) / (max as f32))
}

fn trit_pair_distance(a: Trit, b: Trit) -> u32 {
    if a == b {
        0
    } else if a == Trit::Zero || b == Trit::Zero {
        1
    } else {
        2
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn empty_k_vector_returns_empty_fingerprint() {
        let fp = fingerprint_k_vector(&[], 0.1).unwrap();
        assert!(fp.blocks.is_empty());
        assert_eq!(fp.channel_count, 0);
        assert_eq!(fp.max_abs, 0.0);
    }

    #[test]
    fn threshold_zero_keeps_every_nonzero_channel() {
        let k = vec![0.0, 1.0, -2.0, 0.5];
        let fp = fingerprint_k_vector(&k, 0.0).unwrap();
        assert_eq!(fp.channel_count, 4);
        assert_eq!(fp.max_abs, 2.0);
        let trits = unpack_trits_u32(fp.blocks[0]).unwrap();
        assert_eq!(trits[0], Trit::Zero);
        assert_eq!(trits[1], Trit::Pos);
        assert_eq!(trits[2], Trit::Neg);
        assert_eq!(trits[3], Trit::Pos);
    }

    #[test]
    fn threshold_above_max_collapses_everything_to_zero() {
        let k = vec![0.1, -0.2, 0.3];
        let fp = fingerprint_k_vector(&k, 1.5).unwrap_err();
        assert_eq!(fp, FingerprintError::ThresholdOutOfRange { ratio: 1.5 });
    }

    #[test]
    fn threshold_one_keeps_only_max_magnitude_channels() {
        let k = vec![0.1, 0.2, 1.0, -1.0, 0.5];
        let fp = fingerprint_k_vector(&k, 1.0).unwrap();
        let trits = unpack_trits_u32(fp.blocks[0]).unwrap();
        assert_eq!(trits[0], Trit::Zero);
        assert_eq!(trits[1], Trit::Zero);
        assert_eq!(trits[2], Trit::Pos);
        assert_eq!(trits[3], Trit::Neg);
        assert_eq!(trits[4], Trit::Zero);
    }

    #[test]
    fn all_zero_input_yields_all_zero_fingerprint() {
        let k = vec![0.0; 5];
        let fp = fingerprint_k_vector(&k, 0.1).unwrap();
        assert_eq!(fp.max_abs, 0.0);
        let trits = unpack_trits_u32(fp.blocks[0]).unwrap();
        assert!(trits.iter().take(5).all(|&t| t == Trit::Zero));
    }

    #[test]
    fn channel_count_beyond_block_size_packs_into_multiple_blocks() {
        let k: Vec<f32> = (0..20).map(|i| if i % 2 == 0 { 1.0 } else { -1.0 }).collect();
        let fp = fingerprint_k_vector(&k, 0.5).unwrap();
        assert_eq!(fp.channel_count, 20);
        assert_eq!(fp.blocks.len(), 2);
    }

    #[test]
    fn distance_identical_is_zero() {
        let k = vec![1.0, -2.0, 0.0, 0.5];
        let fp = fingerprint_k_vector(&k, 0.1).unwrap();
        assert_eq!(fingerprint_distance(&fp, &fp).unwrap(), 0.0);
    }

    #[test]
    fn distance_fully_inverted_is_one() {
        let k = vec![1.0, -1.0, 1.0, -1.0];
        let neg = vec![-1.0, 1.0, -1.0, 1.0];
        let fp_a = fingerprint_k_vector(&k, 0.5).unwrap();
        let fp_b = fingerprint_k_vector(&neg, 0.5).unwrap();
        assert_eq!(fingerprint_distance(&fp_a, &fp_b).unwrap(), 1.0);
    }

    #[test]
    fn distance_partial_for_one_flipped() {
        let k = vec![1.0, 1.0, 1.0, 1.0];
        let one_flipped = vec![-1.0, 1.0, 1.0, 1.0];
        let fp_a = fingerprint_k_vector(&k, 0.5).unwrap();
        let fp_b = fingerprint_k_vector(&one_flipped, 0.5).unwrap();
        let d = fingerprint_distance(&fp_a, &fp_b).unwrap();
        assert!((d - 0.25).abs() < 1e-6);
    }

    #[test]
    fn distance_mismatched_channel_count_errors() {
        let k_a = vec![1.0, 1.0];
        let k_b = vec![1.0, 1.0, 1.0];
        let fp_a = fingerprint_k_vector(&k_a, 0.5).unwrap();
        let fp_b = fingerprint_k_vector(&k_b, 0.5).unwrap();
        let err = fingerprint_distance(&fp_a, &fp_b).unwrap_err();
        assert_eq!(
            err,
            FingerprintError::ChannelCountMismatch { left: 2, right: 3 }
        );
    }

    #[test]
    fn threshold_negative_rejected() {
        let err = fingerprint_k_vector(&[1.0], -0.1).unwrap_err();
        assert_eq!(err, FingerprintError::ThresholdOutOfRange { ratio: -0.1 });
    }

    #[test]
    fn zero_vs_signed_is_half_distance_per_channel() {
        let k_a = vec![0.0];
        let k_b = vec![1.0];
        let fp_a = fingerprint_k_vector(&k_a, 0.5).unwrap();
        let fp_b = fingerprint_k_vector(&k_b, 0.5).unwrap();
        let d = fingerprint_distance(&fp_a, &fp_b).unwrap();
        assert!((d - 0.5).abs() < 1e-6);
    }
}
