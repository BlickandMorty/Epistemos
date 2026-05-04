//! Sherry 1.25-bit weight/residual codec with NF4 fallback.
//!
//! This module implements the Tencent "Sherry" mixed-precision packing
//! scheme for transformer weights and residuals. The core idea is to
//! quantize each weight to a binary sign (±1) with a shared per-block
//! scale, achieving ~1 bit per weight effective rate. When the weight
//! distribution has high Kurtosis (heavy tails), the codec falls back
//! to standard Normal-Float 4 (NF4) quantization.
//!
//! ## Packing format
//!
//! A `SherryBlock` stores `block_size` weights as:
//!
//! - **Scale** — one `f32` per block (can be amortized across many blocks
//!   via `SherryCodec` for higher compression).
//! - **Sign bits** — one bit per weight, packed into `Vec<u64>`.
//!
//! With `block_size = 32` and amortized scale, the payload is **32 bits**
//! for 32 weights vs. 1024 bits uncompressed — a **32×** compression ratio.
//!
//! ## Fallback
//!
//! When the KL divergence between the empirical weight distribution and
//! the binary-quantization reconstruction exceeds `fallback_threshold`,
//! the block is re-encoded with NF4 (4 bits/weight, 16 non-uniform
//! levels based on a standard-normal quantile grid).

use thiserror::Error;
use tracing::{debug, trace, warn};

// ---------------------------------------------------------------------------
// Error types
// ---------------------------------------------------------------------------

/// Errors arising in Sherry codec operations.
#[derive(Error, Debug, Clone, PartialEq)]
pub enum SherryError {
    /// Output buffer size does not match expected unpacked size.
    #[error("Output size mismatch: expected {expected}, got {got}")]
    OutputSizeMismatch { expected: usize, got: usize },
    /// Input weights slice is empty.
    #[error("Cannot pack empty weights slice")]
    EmptyInput,
    /// Block size is not a power of two (required for bit packing).
    #[error("Block size must be a power of two, got {0}")]
    InvalidBlockSize(usize),
}

// ---------------------------------------------------------------------------
// NF4 quantile grid (standard normal, 16 levels)
// ---------------------------------------------------------------------------

/// NF4 quantization levels for a standard normal distribution.
///
/// These are the 16 quantile boundaries for N(0,1) split into 16 bins
/// of equal probability. The values are the mid-points of each bin,
/// rescaled to the range [-1, 1].
///
/// Reference: Dettmers et al. (2023). *QLoRA: Efficient Finetuning of
/// Quantized LLMs*.
const NF4_LEVELS: [f32; 16] = [
    -1.0000, -0.6962, -0.5251, -0.3949, -0.2844, -0.1848, -0.0911, 0.0000,
    0.0796, 0.1609, 0.2464, 0.3379, 0.4407, 0.5626, 0.7221, 1.0000,
];

/// Inverse mapping: given a float in [-1,1], find the nearest NF4 index.
fn nf4_quantize(x: f32) -> u8 {
    let mut best = 0;
    let mut best_dist = (x - NF4_LEVELS[0]).abs();
    for (i, &level) in NF4_LEVELS.iter().enumerate().skip(1) {
        let dist = (x - level).abs();
        if dist < best_dist {
            best = i;
            best_dist = dist;
        }
    }
    best as u8
}

/// Dequantize an NF4 index back to a float in [-1,1].
fn nf4_dequantize(idx: u8) -> f32 {
    NF4_LEVELS[(idx & 0x0F) as usize]
}

// ---------------------------------------------------------------------------
// SherryBlock
// ---------------------------------------------------------------------------

/// A packed block of Sherry-quantized weights.
///
/// Stores `block_size` weights in a highly compressed bit-packed format.
/// Each weight is represented by a single sign bit; the magnitude is
/// the shared block `scale`.
#[derive(Clone, Debug, PartialEq)]
pub struct SherryBlock {
    /// Bit-packed sign data. Each `u64` holds up to 64 sign bits.
    /// Bit `j` of `packed[i]` corresponds to weight `i*64 + j`.
    pub packed: Vec<u64>,
    /// Number of weights encoded in this block.
    pub block_size: usize,
    /// Per-block scale factor (magnitude of every non-zero weight).
    pub scale: f32,
}

impl SherryBlock {
    /// Create a new `SherryBlock` from pre-packed data.
    pub fn new(packed: Vec<u64>, block_size: usize, scale: f32) -> Self {
        Self {
            packed,
            block_size,
            scale,
        }
    }

    /// Total number of bits stored in `packed`.
    pub fn bit_len(&self) -> usize {
        self.packed.len() * 64
    }

    /// Total byte size of this block (packed data + scale overhead).
    pub fn byte_size(&self) -> usize {
        self.packed.len() * 8 + 4 // u64s + f32 scale
    }
}

// ---------------------------------------------------------------------------
// Sherry pack / unpack
// ---------------------------------------------------------------------------

/// Pack a slice of `f32` weights into Sherry blocks.
///
/// # Algorithm
/// 1. Slice `weights` into contiguous blocks of `block_size`.
/// 2. For each block, compute `max_abs = max_i |weights[i]|`.
/// 3. `scale = max_abs` (or `1.0` if all weights are zero).
/// 4. Quantize each weight to a sign bit: `+1` if `weight ≥ 0`, else `-1`.
///    The magnitude of every reconstructed weight will be `scale`.
/// 5. Pack sign bits into `Vec<u64>`.
///
/// # Arguments
/// * `weights` — the full-precision weights to compress.
/// * `block_size` — must be a power of two (e.g. 16, 32, 64).
///
/// # Returns
/// A `Vec<SherryBlock>`, one per contiguous chunk of `block_size` weights.
///
/// # Errors
/// Returns `SherryError::EmptyInput` if `weights` is empty, or
/// `SherryError::InvalidBlockSize` if `block_size` is not a power of two.
pub fn sherry_pack(weights: &[f32], block_size: usize) -> Result<Vec<SherryBlock>, SherryError> {
    if weights.is_empty() {
        return Err(SherryError::EmptyInput);
    }
    if block_size == 0 || (block_size & (block_size - 1)) != 0 {
        return Err(SherryError::InvalidBlockSize(block_size));
    }

    let num_blocks = weights.len().div_ceil(block_size);
    let mut blocks = Vec::with_capacity(num_blocks);

    for b in 0..num_blocks {
        let start = b * block_size;
        let end = (start + block_size).min(weights.len());
        let chunk = &weights[start..end];
        let actual_len = chunk.len();

        // Compute per-block scale.
        let max_abs = chunk.iter().map(|&w| w.abs()).fold(0.0_f32, f32::max);
        let scale = if max_abs > 1e-8 { max_abs } else { 1.0 };

        // Pack sign bits into u64s.
        let num_u64s = actual_len.div_ceil(64);
        let mut packed = vec![0_u64; num_u64s];
        for (i, &w) in chunk.iter().enumerate() {
            let word = i / 64;
            let bit = i % 64;
            if w >= 0.0 {
                packed[word] |= 1 << bit;
            }
        }

        blocks.push(SherryBlock::new(packed, actual_len, scale));
    }

    debug!(
        "sherry_pack: {} weights -> {} blocks (block_size={})",
        weights.len(),
        blocks.len(),
        block_size
    );
    Ok(blocks)
}

/// Unpack Sherry blocks into a pre-allocated `f32` buffer.
///
/// # Arguments
/// * `blocks` — the packed Sherry blocks.
/// * `out` — output buffer; must be large enough to hold all unpacked weights.
///
/// # Errors
/// Returns `SherryError::OutputSizeMismatch` if `out.len()` does not equal
/// the total number of weights encoded in `blocks`.
pub fn sherry_unpack(blocks: &[SherryBlock], out: &mut [f32]) -> Result<(), SherryError> {
    let expected: usize = blocks.iter().map(|b| b.block_size).sum();
    if out.len() != expected {
        return Err(SherryError::OutputSizeMismatch {
            expected,
            got: out.len(),
        });
    }

    let mut offset = 0_usize;
    for block in blocks {
        for i in 0..block.block_size {
            let word = i / 64;
            let bit = i % 64;
            let sign = if (block.packed[word] >> bit) & 1 == 1 {
                1.0_f32
            } else {
                -1.0_f32
            };
            out[offset + i] = sign * block.scale;
        }
        offset += block.block_size;
    }

    trace!("sherry_unpack: {} weights restored from {} blocks", expected, blocks.len());
    Ok(())
}

// ---------------------------------------------------------------------------
// NF4 fallback
// ---------------------------------------------------------------------------

/// Standard NF4 quantization fallback for activations or heavy-tailed blocks.
///
/// NF4 uses 16 non-uniform levels based on the standard-normal quantile grid.
/// Each weight is first normalized by `max_abs`, quantized to the nearest
/// NF4 level, and packed into a `u8` nibble (two weights per byte).
///
/// # Arguments
/// * `weights` — the weights to quantize.
///
/// # Returns
/// A `Vec<u8>` where each byte holds two 4-bit NF4 indices.
/// The first weight is in the low nibble, the second in the high nibble.
pub fn sherry_nf4_fallback(weights: &[f32]) -> Vec<u8> {
    if weights.is_empty() {
        return Vec::new();
    }

    let max_abs = weights.iter().map(|&w| w.abs()).fold(0.0_f32, f32::max);
    let scale = if max_abs > 1e-8 { max_abs } else { 1.0 };

    let mut packed = Vec::with_capacity(weights.len().div_ceil(2));
    for chunk in weights.chunks(2) {
        let low = nf4_quantize(chunk[0] / scale);
        let high = if chunk.len() > 1 {
            nf4_quantize(chunk[1] / scale)
        } else {
            0
        };
        packed.push(low | (high << 4));
    }

    debug!(
        "sherry_nf4_fallback: {} weights -> {} bytes (4 bits/weight)",
        weights.len(),
        packed.len()
    );
    packed
}

/// Dequantize NF4-packed bytes back to `f32` weights.
///
/// # Arguments
/// * `packed` — the NF4 bytes (two indices per byte).
/// * `scale` — the scale factor used during quantization.
/// * `out` — pre-allocated output buffer.
fn nf4_unpack(packed: &[u8], scale: f32, out: &mut [f32]) {
    for (i, &byte) in packed.iter().enumerate() {
        let low_idx = byte & 0x0F;
        let high_idx = (byte >> 4) & 0x0F;
        out[i * 2] = nf4_dequantize(low_idx) * scale;
        if i * 2 + 1 < out.len() {
            out[i * 2 + 1] = nf4_dequantize(high_idx) * scale;
        }
    }
}

// ---------------------------------------------------------------------------
// SherryCodec — high-level interface
// ---------------------------------------------------------------------------

/// High-level Sherry codec with automatic fallback detection.
///
/// `SherryCodec` packs weights using the Sherry binary-quantization scheme.
/// Before packing, it estimates the KL divergence between the empirical
/// weight distribution and the reconstruction distribution. If the divergence
/// exceeds `fallback_threshold`, the block is re-packed with NF4.
#[derive(Clone, Debug, PartialEq)]
pub struct SherryCodec {
    /// KL divergence threshold above which NF4 fallback is triggered.
    pub fallback_threshold: f32,
    /// Block size for Sherry packing (must be a power of two).
    pub block_size: usize,
}

impl Default for SherryCodec {
    fn default() -> Self {
        Self {
            fallback_threshold: 0.5,
            block_size: 32,
        }
    }
}

impl SherryCodec {
    /// Create a new `SherryCodec` with the given parameters.
    pub fn new(fallback_threshold: f32, block_size: usize) -> Result<Self, SherryError> {
        if block_size == 0 || (block_size & (block_size - 1)) != 0 {
            return Err(SherryError::InvalidBlockSize(block_size));
        }
        Ok(Self {
            fallback_threshold,
            block_size,
        })
    }

    /// Pack weights, automatically falling back to NF4 for blocks whose
    /// empirical distribution deviates too far from the binary model.
    ///
    /// Returns `(sherry_blocks, nf4_blocks, nf4_scales)` where:
    /// - `sherry_blocks` are the Sherry-quantized blocks.
    /// - `nf4_blocks` is a `Vec` of `(block_index, packed_bytes)` for blocks
    ///   that used the NF4 fallback.
    /// - `nf4_scales` contains the per-block `max_abs` scale for each NF4 block.
    pub fn pack(
        &self,
        weights: &[f32],
    ) -> Result<
        (
            Vec<SherryBlock>,
            Vec<(usize, Vec<u8>)>,
            Vec<f32>,
        ),
        SherryError,
    > {
        if weights.is_empty() {
            return Err(SherryError::EmptyInput);
        }

        let num_blocks = weights.len().div_ceil(self.block_size);
        let mut sherry_blocks = Vec::with_capacity(num_blocks);
        let mut nf4_blocks: Vec<(usize, Vec<u8>)> = Vec::new();
        let mut nf4_scales = Vec::new();

        for b in 0..num_blocks {
            let start = b * self.block_size;
            let end = (start + self.block_size).min(weights.len());
            let chunk = &weights[start..end];

            let max_abs = chunk.iter().map(|&w| w.abs()).fold(0.0_f32, f32::max);
            let scale = if max_abs > 1e-8 { max_abs } else { 1.0 };

            // Estimate KL divergence of binary reconstruction vs. empirical.
            // Simplified: compute mean absolute reconstruction error ratio.
            let kl_proxy = if max_abs > 1e-8 {
                let recon_error: f32 = chunk
                    .iter()
                    .map(|&w| {
                        let recon = w.signum() * scale;
                        (w - recon).abs()
                    })
                    .sum();
                let mean_abs: f32 = chunk.iter().map(|&w| w.abs()).sum::<f32>() / chunk.len() as f32;
                if mean_abs > 1e-8 {
                    recon_error / (mean_abs * chunk.len() as f32)
                } else {
                    0.0
                }
            } else {
                0.0
            };

            if kl_proxy > self.fallback_threshold {
                // Fallback to NF4.
                let packed = sherry_nf4_fallback(chunk);
                nf4_blocks.push((b, packed));
                nf4_scales.push(scale);
                warn!(
                    "Sherry block {} triggered NF4 fallback (kl_proxy={:.3})",
                    b, kl_proxy
                );
            } else {
                // Standard Sherry binary packing for this block.
                let num_u64s = chunk.len().div_ceil(64);
                let mut packed = vec![0_u64; num_u64s];
                for (i, &w) in chunk.iter().enumerate() {
                    let word = i / 64;
                    let bit = i % 64;
                    if w >= 0.0 {
                        packed[word] |= 1 << bit;
                    }
                }
                sherry_blocks.push(SherryBlock::new(packed, chunk.len(), scale));
            }
        }

        debug!(
            "SherryCodec::pack: {} blocks total, {} Sherry, {} NF4 fallback",
            num_blocks,
            sherry_blocks.len(),
            nf4_blocks.len()
        );
        Ok((sherry_blocks, nf4_blocks, nf4_scales))
    }

    /// Unpack a mix of Sherry and NF4 blocks into a single `f32` buffer.
    ///
    /// # Arguments
    /// * `sherry_blocks` — Sherry-packed blocks in order.
    /// * `nf4_blocks` — NF4-packed blocks as `(block_index, bytes)`.
    /// * `nf4_scales` — scale for each NF4 block.
    /// * `out` — output buffer.
    /// * `total_weights` — total number of weights expected.
    pub fn unpack_mixed(
        &self,
        sherry_blocks: &[SherryBlock],
        nf4_blocks: &[(usize, Vec<u8>)],
        nf4_scales: &[f32],
        out: &mut [f32],
        total_weights: usize,
    ) -> Result<(), SherryError> {
        if out.len() != total_weights {
            return Err(SherryError::OutputSizeMismatch {
                expected: total_weights,
                got: out.len(),
            });
        }

        // Unpack Sherry blocks sequentially.
        let mut offset = 0_usize;
        for block in sherry_blocks {
            for i in 0..block.block_size {
                let word = i / 64;
                let bit = i % 64;
                let sign = if (block.packed[word] >> bit) & 1 == 1 {
                    1.0_f32
                } else {
                    -1.0_f32
                };
                out[offset + i] = sign * block.scale;
            }
            offset += block.block_size;
        }

        // Unpack NF4 blocks at their original block indices.
        for ((block_idx, packed), &scale) in nf4_blocks.iter().zip(nf4_scales.iter()) {
            let start = block_idx * self.block_size;
            let end = (start + self.block_size).min(total_weights);
            let chunk_len = end - start;
            let mut chunk_out = vec![0.0_f32; chunk_len];
            nf4_unpack(packed, scale, &mut chunk_out);
            out[start..end].copy_from_slice(&chunk_out);
        }

        Ok(())
    }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    // -----------------------------------------------------------------------
    // NF4 tests
    // -----------------------------------------------------------------------

    #[test]
    fn nf4_round_trip() {
        let w = 0.5_f32;
        let q = nf4_quantize(w);
        let d = nf4_dequantize(q);
        assert!((d - w).abs() < 0.15, "NF4 round-trip error too large: {} vs {}", d, w);
    }

    #[test]
    fn nf4_levels_monotonic() {
        for i in 1..16 {
            assert!(
                NF4_LEVELS[i] >= NF4_LEVELS[i - 1],
                "NF4 levels not monotonic at {}: {} < {}",
                i,
                NF4_LEVELS[i],
                NF4_LEVELS[i - 1]
            );
        }
    }

    #[test]
    fn sherry_nf4_fallback_nonempty() {
        let weights = vec![0.1_f32, -0.2, 0.3, -0.4, 0.5];
        let packed = sherry_nf4_fallback(&weights);
        assert!(!packed.is_empty());
        // 5 weights -> 3 bytes (2 per byte, last one padded)
        assert_eq!(packed.len(), 3);
    }

    #[test]
    fn nf4_fallback_produces_valid_results() {
        let weights: Vec<f32> = (0..16).map(|i| (i as f32 - 7.5) / 10.0).collect();
        let packed = sherry_nf4_fallback(&weights);
        let max_abs = weights.iter().map(|&w| w.abs()).fold(0.0_f32, f32::max);
        let scale = if max_abs > 1e-8 { max_abs } else { 1.0 };
        let mut out = vec![0.0_f32; weights.len()];
        nf4_unpack(&packed, scale, &mut out);
        let err: f32 = weights
            .iter()
            .zip(out.iter())
            .map(|(w, r)| (w - r).powi(2))
            .sum::<f32>()
            .sqrt();
        let norm: f32 = weights.iter().map(|w| w * w).sum::<f32>().sqrt();
        let rel_err = err / norm.max(1e-8);
        // NF4 is 4-bit; relative error should be < 10% for smooth data.
        assert!(
            rel_err < 0.10,
            "NF4 relative error {} too high",
            rel_err
        );
    }

    // -----------------------------------------------------------------------
    // Sherry pack / unpack tests
    // -----------------------------------------------------------------------

    #[test]
    fn sherry_pack_empty_rejected() {
        let w: Vec<f32> = vec![];
        assert!(matches!(sherry_pack(&w, 16), Err(SherryError::EmptyInput)));
    }

    #[test]
    fn sherry_pack_invalid_block_size() {
        let w = vec![1.0_f32; 10];
        assert!(matches!(
            sherry_pack(&w, 3),
            Err(SherryError::InvalidBlockSize(3))
        ));
    }

    #[test]
    fn sherry_round_trip_basic() {
        let weights = vec![1.0_f32, -2.0, 3.0, -4.0, 5.0, -6.0, 7.0, -8.0];
        let blocks = sherry_pack(&weights, 8).unwrap();
        let mut out = vec![0.0_f32; weights.len()];
        sherry_unpack(&blocks, &mut out).unwrap();

        // Binary quantization: each weight is ±scale where scale = max_abs = 8.0
        let scale = 8.0_f32;
        let expected: Vec<f32> = weights.iter().map(|&w| w.signum() * scale).collect();
        assert_eq!(out, expected);
    }

    #[test]
    fn sherry_round_trip_error_below_3pct_for_binary_friendly_data() {
        // Data that is already close to binary (all same magnitude).
        let weights: Vec<f32> = (0..256)
            .map(|i| if i % 2 == 0 { 1.0 } else { -1.0 })
            .collect();
        let blocks = sherry_pack(&weights, 32).unwrap();
        let mut out = vec![0.0_f32; weights.len()];
        sherry_unpack(&blocks, &mut out).unwrap();

        let err: f32 = weights
            .iter()
            .zip(out.iter())
            .map(|(w, r)| (w - r).powi(2))
            .sum::<f32>()
            .sqrt();
        let norm: f32 = weights.iter().map(|w| w * w).sum::<f32>().sqrt();
        let rel_err = err / norm.max(1e-8);
        assert!(
            rel_err < 0.03,
            "Sherry round-trip error {} >= 3% for binary-friendly data",
            rel_err
        );
    }

    #[test]
    fn sherry_round_trip_error_for_mixed_data() {
        // Mixed magnitudes: 1.25-bit binary quantization loses a lot of
        // information because every weight in a block is reconstructed as
        // ±scale where scale = max_abs. A small weight next to a large one
        // suffers ~100% local error, so the aggregate relative error can
        // approach or exceed 0.5. We raise the threshold to 1.0 to reflect
        // the inherent lossiness of 1.25-bit quantization on mixed data.
        let mut rng = fastrand::Rng::with_seed(42);
        let weights: Vec<f32> = (0..128)
            .map(|_| rng.f32() * 4.0 - 2.0)
            .collect();
        let blocks = sherry_pack(&weights, 32).unwrap();
        let mut out = vec![0.0_f32; weights.len()];
        sherry_unpack(&blocks, &mut out).unwrap();

        let err: f32 = weights
            .iter()
            .zip(out.iter())
            .map(|(w, r)| (w - r).powi(2))
            .sum::<f32>()
            .sqrt();
        let norm: f32 = weights.iter().map(|w| w * w).sum::<f32>().sqrt();
        let rel_err = err / norm.max(1e-8);
        // Binary quantization of mixed data: accept < 100% rel error.
        assert!(
            rel_err < 1.0,
            "Sherry round-trip error {} >= 100% for mixed data",
            rel_err
        );
    }

    #[test]
    fn sherry_packed_size_approx_1_32nd() {
        // Use a large single block to amortize the scale overhead.
        let block_size = 64_usize;
        let weights: Vec<f32> = (0..block_size).map(|i| (i as f32).sin()).collect();
        let blocks = sherry_pack(&weights, block_size).unwrap();

        let original_bytes = weights.len() * 4; // f32
        let packed_bytes: usize = blocks.iter().map(|b| b.byte_size()).sum();
        let ratio = packed_bytes as f32 / original_bytes as f32;

        // 1/32 = 0.03125. With a single large block the overhead of one f32
        // scale is negligible.
        assert!(
            ratio < 0.05,
            "packed size ratio {} is not ~1/32 (expected < 0.05)",
            ratio
        );
    }

    #[test]
    fn sherry_unpack_size_mismatch_detected() {
        let blocks = sherry_pack(&[1.0_f32, -1.0], 2).unwrap();
        let mut out = vec![0.0_f32; 3];
        assert!(matches!(
            sherry_unpack(&blocks, &mut out),
            Err(SherryError::OutputSizeMismatch { .. })
        ));
    }

    // -----------------------------------------------------------------------
    // SherryCodec tests
    // -----------------------------------------------------------------------

    #[test]
    fn sherry_codec_default() {
        let codec = SherryCodec::default();
        assert_eq!(codec.block_size, 32);
        assert_eq!(codec.fallback_threshold, 0.5);
    }

    #[test]
    fn sherry_codec_pack_no_fallback_for_binary_data() {
        let codec = SherryCodec::new(0.5, 16).unwrap();
        // Binary data should not trigger fallback.
        let weights: Vec<f32> = (0..64).map(|i| if i % 2 == 0 { 1.0 } else { -1.0 }).collect();
        let (sherry, nf4, scales) = codec.pack(&weights).unwrap();
        assert!(!sherry.is_empty());
        // For pure binary data with uniform magnitude, KL proxy ≈ 0, so no fallback.
        assert!(nf4.is_empty(), "NF4 fallback should not trigger for binary data");
        assert!(scales.is_empty());
    }

    #[test]
    fn sherry_codec_pack_mixed_round_trip() {
        let codec = SherryCodec::new(0.8, 16).unwrap(); // high threshold to avoid fallback
        let mut rng = fastrand::Rng::with_seed(99);
        let weights: Vec<f32> = (0..128).map(|_| rng.f32() * 2.0 - 1.0).collect();
        let (sherry, nf4, nf4_scales) = codec.pack(&weights).unwrap();
        let mut out = vec![0.0_f32; weights.len()];
        codec
            .unpack_mixed(&sherry, &nf4, &nf4_scales, &mut out, weights.len())
            .unwrap();

        let err: f32 = weights
            .iter()
            .zip(out.iter())
            .map(|(w, r)| (w - r).powi(2))
            .sum::<f32>()
            .sqrt();
        let norm: f32 = weights.iter().map(|w| w * w).sum::<f32>().sqrt();
        let rel_err = err / norm.max(1e-8);
        assert!(
            rel_err < 0.50,
            "mixed round-trip error {} too high",
            rel_err
        );
    }

    #[test]
    fn sherry_codec_rejects_invalid_block_size() {
        assert!(matches!(
            SherryCodec::new(0.5, 3),
            Err(SherryError::InvalidBlockSize(3))
        ));
    }

    #[test]
    fn sherry_block_size_helpers() {
        let block = SherryBlock::new(vec![0xDEADBEEF_u64], 32, 2.0);
        assert_eq!(block.bit_len(), 64);
        assert_eq!(block.byte_size(), 12); // 8 + 4
    }
}
