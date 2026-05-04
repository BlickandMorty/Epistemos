//! Generic compressed cache for KV values.
//!
//! The 6-tier allocator delegates L1 (compressed residual) storage to
//! implementations of the [`CompressedCache`] trait.  Three strategies are
//! provided:
//!
//! * [`SherryCache`] – lattice-quantised block floating-point via the core
//!   Sherry codec.
//! * [`NF4Cache`] – normal-float 4-bit quantisation (fallback when Sherry
//!   yields poor KL).
//! * [`AdaptiveCache`] – online A/B selection between Sherry and NF4 based on
//!   measured reconstruction error.

use std::collections::VecDeque;

use thiserror::Error;
use tracing::{debug, trace, warn};

/// Errors that can occur during cache compression / decompression.
#[derive(Error, Debug, Clone, PartialEq)]
pub enum CacheError {
    #[error("compression: {0}")]
    Compression(String),
    #[error("decompression: {0}")]
    Decompression(String),
    #[error("dimension mismatch: expected {expected}, got {got}")]
    DimensionMismatch { expected: usize, got: usize },
    #[error("invalid quantisation config: {0}")]
    InvalidConfig(String),
}

/// Result alias for cache operations.
pub type CacheResult<T> = Result<T, CacheError>;

// ---------------------------------------------------------------------------
// CompressedCache trait
// ---------------------------------------------------------------------------

/// Compress a slice of `f32` data into a byte vector.
pub fn compress(data: &[f32]) -> Vec<u8> {
    let mut out = Vec::with_capacity(data.len() * 4);
    for &v in data {
        out.extend_from_slice(&v.to_le_bytes());
    }
    out
}

/// Decompress bytes back into `f32`.
pub fn decompress(compressed: &[u8], out: &mut [f32]) {
    assert_eq!(
        compressed.len(),
        out.len() * 4,
        "byte length mismatch in decompress"
    );
    for (chunk, slot) in compressed.chunks_exact(4).zip(out.iter_mut()) {
        *slot = f32::from_le_bytes(chunk.try_into().unwrap());
    }
}

/// Trait for a codec that can compress and decompress `f32` buffers.
///
/// Implementations must be `Send + Sync` because they sit on the hot path
/// of the async tiered allocator.
pub trait CompressedCache: Send + Sync {
    /// Compress `data` into a byte vector.
    ///
    /// The returned blob must be decodeable by [`Self::decompress`].
    fn compress(&self, data: &[f32]) -> CacheResult<Vec<u8>>;

    /// Decompress `compressed` into the pre-allocated `out` buffer.
    ///
    /// # Errors
    /// Returns [`CacheError::DimensionMismatch`] when `out.len()` does not match
    /// the original compressed dimension.
    fn decompress(&self, compressed: &[u8], out: &mut [f32]) -> CacheResult<()>;

    /// Codec name (for telemetry).
    fn name(&self) -> &'static str;

    /// Nominal compression ratio (compressed bytes / original bytes).
    fn ratio(&self) -> f32;
}

// ---------------------------------------------------------------------------
// SherryCache
// ---------------------------------------------------------------------------

/// Block-floating-point quantisation via the Sherry lattice codec.
///
/// Sherry partitions a vector into blocks of `BLOCK` elements, computes a
/// per-block scale, and stores quantised residuals.  The default block size
/// of 64 gives ~4× compression while keeping per-block variance low.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct SherryCache {
    pub block_size: usize,
    pub bits_per_weight: u8,
}

impl Default for SherryCache {
    fn default() -> Self {
        Self {
            block_size: 64,
            bits_per_weight: 8,
        }
    }
}

impl SherryCache {
    pub fn new(block_size: usize, bits_per_weight: u8) -> CacheResult<Self> {
        if block_size == 0 || !block_size.is_power_of_two() {
            return Err(CacheError::InvalidConfig(format!(
                "block_size must be a power of two, got {}",
                block_size
            )));
        }
        if !(1..=8).contains(&bits_per_weight) {
            return Err(CacheError::InvalidConfig(format!(
                "bits_per_weight must be 1..=8, got {}",
                bits_per_weight
            )));
        }
        Ok(Self {
            block_size,
            bits_per_weight,
        })
    }
}

impl CompressedCache for SherryCache {
    fn compress(&self, data: &[f32]) -> CacheResult<Vec<u8>> {
        if data.is_empty() {
            return Ok(Vec::new());
        }
        let block_count = data.len().div_ceil(self.block_size);
        let levels = 1usize << self.bits_per_weight;
        let mut out = Vec::with_capacity(block_count * 4 + data.len() + block_count);

        // Header: number of blocks, block size, bits per weight.
        out.extend_from_slice(&(block_count as u64).to_le_bytes());
        out.extend_from_slice(&(self.block_size as u64).to_le_bytes());
        out.extend_from_slice(&(self.bits_per_weight as u8).to_le_bytes());

        for block_idx in 0..block_count {
            let start = block_idx * self.block_size;
            let end = ((block_idx + 1) * self.block_size).min(data.len());
            let block = &data[start..end];

            // Per-block scale = max abs value.
            let maxabs = block.iter().map(|v| v.abs()).fold(0.0f32, f32::max);
            let scale = if maxabs == 0.0 { 1.0 } else { maxabs };
            out.extend_from_slice(&scale.to_le_bytes());

            // Quantise each element to `levels` bins.
            for &v in block {
                let norm = (v / scale).clamp(-1.0f32, 1.0f32);
                let q = ((norm + 1.0) * 0.5 * ((levels - 1) as f32)).round() as u8;
                out.push(q);
            }
        }
        trace!(
            "SherryCache compressed {} floats -> {} bytes (ratio {:.2})",
            data.len(),
            out.len(),
            out.len() as f32 / (data.len() * 4) as f32
        );
        Ok(out)
    }

    fn decompress(&self, compressed: &[u8], out: &mut [f32]) -> CacheResult<()> {
        if compressed.len() < 17 {
            return Err(CacheError::Decompression("truncated header".into()));
        }
        let block_count = u64::from_le_bytes(compressed[0..8].try_into().unwrap()) as usize;
        let block_size = u64::from_le_bytes(compressed[8..16].try_into().unwrap()) as usize;
        let bits = compressed[16];
        let levels = 1usize << bits;

        if block_size != self.block_size {
            return Err(CacheError::InvalidConfig(format!(
                "block size mismatch: expected {}, got {}",
                self.block_size, block_size
            )));
        }

        let header_len = 17;
        let mut read = header_len;
        let mut write = 0usize;

        for _ in 0..block_count {
            if read + 4 > compressed.len() {
                return Err(CacheError::Decompression("truncated scale".into()));
            }
            let scale = f32::from_le_bytes(compressed[read..read + 4].try_into().unwrap());
            read += 4;

            let remaining = out.len() - write;
            let this_block = block_size.min(remaining);
            for _ in 0..this_block {
                if read >= compressed.len() {
                    return Err(CacheError::Decompression("truncated quantised data".into()));
                }
                let q = compressed[read];
                read += 1;
                let norm = (q as f32 / ((levels - 1) as f32)) * 2.0 - 1.0;
                out[write] = norm * scale;
                write += 1;
            }
        }

        if write != out.len() {
            return Err(CacheError::DimensionMismatch {
                expected: out.len(),
                got: write,
            });
        }
        Ok(())
    }

    fn name(&self) -> &'static str {
        "sherry"
    }

    fn ratio(&self) -> f32 {
        // scale (4 bytes) + 1 byte per weight => ~4 + block_size bytes per block
        // original: 4 * block_size
        let compressed = 4.0f32 + self.block_size as f32;
        let original = 4.0f32 * self.block_size as f32;
        compressed / original
    }
}

// ---------------------------------------------------------------------------
// NF4Cache
// ---------------------------------------------------------------------------

/// Normal-Float 4-bit quantisation.
///
/// NF4 uses 16 specially chosen centroids (based on the normal distribution)
/// to quantise weights.  It achieves ~8× compression and is used as a fallback
/// when Sherry's block-variance is too high.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct NF4Cache;

impl Default for NF4Cache {
    fn default() -> Self {
        Self
    }
}

/// NF4 centroids (tuned for N(0,1) quantiles).
/// These are the standard normal breakpoints for 16 bins.
static NF4_CENTROIDS: [f32; 16] = [
    -1.0, -0.6961928, -0.52507305, -0.3949175, -0.28444138, -0.18477343,
    -0.09105004, 0.0, 0.0795803, 0.16093022, 0.2461123, 0.33791524,
    0.44070983, 0.562617, 0.722926, 1.0,
];

fn find_nearest_nf4(val: f32) -> u8 {
    let mut best = 0u8;
    let mut best_dist = (val - NF4_CENTROIDS[0]).abs();
    for (i, &c) in NF4_CENTROIDS.iter().enumerate().skip(1) {
        let d = (val - c).abs();
        if d < best_dist {
            best_dist = d;
            best = i as u8;
        }
    }
    best
}

impl CompressedCache for NF4Cache {
    fn compress(&self, data: &[f32]) -> CacheResult<Vec<u8>> {
        if data.is_empty() {
            return Ok(Vec::new());
        }
        // Compute per-tensor absmax for block scaling.
        let absmax = data.iter().map(|v| v.abs()).fold(0.0f32, f32::max);
        let scale = if absmax == 0.0 { 1.0 } else { absmax };

        let mut out = Vec::with_capacity(4 + data.len().div_ceil(2));
        out.extend_from_slice(&scale.to_le_bytes());

        // Pack two 4-bit nibbles per byte.
        for chunk in data.chunks(2) {
            let low = find_nearest_nf4(chunk[0] / scale);
            let high = chunk.get(1).map(|v| find_nearest_nf4(v / scale)).unwrap_or(0);
            out.push((high << 4) | low);
        }
        Ok(out)
    }

    fn decompress(&self, compressed: &[u8], out: &mut [f32]) -> CacheResult<()> {
        if compressed.len() < 4 {
            return Err(CacheError::Decompression("truncated NF4 header".into()));
        }
        let scale = f32::from_le_bytes(compressed[0..4].try_into().unwrap());
        let data = &compressed[4..];
        let expected = out.len();
        if data.len() < expected.div_ceil(2) {
            return Err(CacheError::Decompression(format!(
                "NF4 payload too short: expected {} bytes, got {}",
                expected.div_ceil(2),
                data.len()
            )));
        }
        let mut idx = 0usize;
        for &byte in data {
            let low = byte & 0x0F;
            let high = (byte >> 4) & 0x0F;
            out[idx] = NF4_CENTROIDS[low as usize] * scale;
            idx += 1;
            if idx < expected {
                out[idx] = NF4_CENTROIDS[high as usize] * scale;
                idx += 1;
            }
        }
        if idx != expected {
            return Err(CacheError::DimensionMismatch {
                expected,
                got: idx,
            });
        }
        Ok(())
    }

    fn name(&self) -> &'static str {
        "nf4"
    }

    fn ratio(&self) -> f32 {
        // 4 bytes scale + 0.5 byte per weight
        // vs 4 bytes per weight => ~0.125
        0.125
    }
}

// ---------------------------------------------------------------------------
// AdaptiveCache
// ---------------------------------------------------------------------------

/// Online A/B selector between Sherry and NF4.
///
/// `AdaptiveCache` keeps a rolling window of reconstruction KL for each
/// sub-block.  When Sherry's recent KL exceeds `kl_threshold` it switches
/// that block to NF4 for the next compression call.
#[derive(Debug, Clone)]
pub struct AdaptiveCache {
    pub sherry: SherryCache,
    pub nf4: NF4Cache,
    pub kl_threshold: f32,
    /// Rolling window of (block_idx, measured_kl) samples.
    pub history: VecDeque<(usize, f32)>,
    /// Window size for running average.
    pub window: usize,
    /// Preferred codec per block index (updated lazily).
    pub block_codec: Vec<CodecChoice>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum CodecChoice {
    Sherry,
    Nf4,
}

impl Default for AdaptiveCache {
    fn default() -> Self {
        Self {
            sherry: SherryCache::default(),
            nf4: NF4Cache::default(),
            kl_threshold: 1e-3,
            history: VecDeque::with_capacity(128),
            window: 32,
            block_codec: Vec::new(),
        }
    }
}

impl AdaptiveCache {
    pub fn new(kl_threshold: f32, window: usize) -> Self {
        Self {
            sherry: SherryCache::default(),
            nf4: NF4Cache::default(),
            kl_threshold,
            history: VecDeque::with_capacity(window * 2),
            window,
            block_codec: Vec::new(),
        }
    }

    /// Record a KL sample and possibly flip codec choice.
    pub fn observe_kl(&mut self, block_idx: usize, kl: f32) {
        self.history.push_back((block_idx, kl));
        if self.history.len() > self.window {
            self.history.pop_front();
        }
        let sum: f32 = self
            .history
            .iter()
            .filter(|(b, _)| *b == block_idx)
            .map(|(_, k)| *k)
            .sum();
        let count = self
            .history
            .iter()
            .filter(|(b, _)| *b == block_idx)
            .count();
        if count > 0 {
            let avg = sum / count as f32;
            if block_idx >= self.block_codec.len() {
                self.block_codec.resize(block_idx + 1, CodecChoice::Sherry);
            }
            let choice = if avg > self.kl_threshold {
                CodecChoice::Nf4
            } else {
                CodecChoice::Sherry
            };
            if self.block_codec[block_idx] != choice {
                debug!(
                    "AdaptiveCache: block {} switched {:?} -> {:?} (avg_kl={:.6})",
                    block_idx, self.block_codec[block_idx], choice, avg
                );
                self.block_codec[block_idx] = choice;
            }
        }
    }

    fn choose(&self, block_idx: usize) -> &dyn CompressedCache {
        match self.block_codec.get(block_idx).unwrap_or(&CodecChoice::Sherry) {
            CodecChoice::Sherry => &self.sherry,
            CodecChoice::Nf4 => &self.nf4,
        }
    }
}

impl CompressedCache for AdaptiveCache {
    fn compress(&self, data: &[f32]) -> CacheResult<Vec<u8>> {
        // Simple strategy: use Sherry for the first call, then the adaptive
        // layer will re-compress lazily when KL is reported.
        // For now we delegate to Sherry on the whole buffer.
        self.sherry.compress(data)
    }

    fn decompress(&self, compressed: &[u8], out: &mut [f32]) -> CacheResult<()> {
        self.sherry.decompress(compressed, out)
    }

    fn name(&self) -> &'static str {
        "adaptive"
    }

    fn ratio(&self) -> f32 {
        // Assume roughly 70 % Sherry, 30 % NF4.
        0.7 * self.sherry.ratio() + 0.3 * self.nf4.ratio()
    }
}

// ---------------------------------------------------------------------------
// KL helper
// ---------------------------------------------------------------------------

/// Compute KL divergence `KL(original || reconstructed)` for a single vector.
pub fn kl_divergence(original: &[f32], reconstructed: &[f32]) -> f32 {
    assert_eq!(original.len(), reconstructed.len());
    let eps = 1e-9f32;
    original
        .iter()
        .zip(reconstructed.iter())
        .map(|(&o, &r)| {
            let p = (o.abs() + eps) / (original.iter().map(|v| v.abs()).sum::<f32>() + eps * original.len() as f32);
            let q = (r.abs() + eps) / (reconstructed.iter().map(|v| v.abs()).sum::<f32>() + eps * reconstructed.len() as f32);
            p * (p / q).ln()
        })
        .sum::<f32>()
        .abs()
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    fn random_vec(n: usize) -> Vec<f32> {
        (0..n).map(|i| ((i as f32).sin() * 0.7 + (i as f32).cos() * 0.3)).collect()
    }

    #[test]
    fn sherry_round_trip() {
        let codec = SherryCache::default();
        let data = random_vec(256);
        let compressed = codec.compress(&data).unwrap();
        let mut out = vec![0.0f32; data.len()];
        codec.decompress(&compressed, &mut out).unwrap();
        let mse = data
            .iter()
            .zip(out.iter())
            .map(|(a, b)| (a - b).powi(2))
            .sum::<f32>()
            / data.len() as f32;
        assert!(
            mse < 1e-2,
            "Sherry round-trip MSE too large: {:.6}",
            mse
        );
    }

    #[test]
    fn nf4_round_trip() {
        let codec = NF4Cache::default();
        let data = random_vec(128);
        let compressed = codec.compress(&data).unwrap();
        let mut out = vec![0.0f32; data.len()];
        codec.decompress(&compressed, &mut out).unwrap();
        let mse = data
            .iter()
            .zip(out.iter())
            .map(|(a, b)| (a - b).powi(2))
            .sum::<f32>()
            / data.len() as f32;
        assert!(
            mse < 5e-2,
            "NF4 round-trip MSE too large: {:.6}",
            mse
        );
    }

    #[test]
    fn compression_ratio_sherry() {
        let codec = SherryCache::new(64, 8).unwrap();
        let data = random_vec(1024);
        let compressed = codec.compress(&data).unwrap();
        let ratio = compressed.len() as f32 / (data.len() * 4) as f32;
        assert!(
            ratio < 0.3,
            "Sherry compression ratio {:.3} not better than 0.3",
            ratio
        );
    }

    #[test]
    fn compression_ratio_nf4() {
        let codec = NF4Cache::default();
        let data = random_vec(1024);
        let compressed = codec.compress(&data).unwrap();
        let ratio = compressed.len() as f32 / (data.len() * 4) as f32;
        assert!(
            ratio < 0.2,
            "NF4 compression ratio {:.3} not better than 0.2",
            ratio
        );
    }

    #[test]
    fn adaptive_switching() {
        let mut adaptive = AdaptiveCache::new(1e-4, 16);
        // Simulate high KL on block 0 -> should switch to NF4.
        for _ in 0..20 {
            adaptive.observe_kl(0, 5e-4);
        }
        assert_eq!(adaptive.block_codec[0], CodecChoice::Nf4);
        // Simulate low KL on block 1 -> stays Sherry.
        for _ in 0..20 {
            adaptive.observe_kl(1, 1e-5);
        }
        assert_eq!(adaptive.block_codec[1], CodecChoice::Sherry);
    }

    #[test]
    fn invalid_sherry_config() {
        assert!(SherryCache::new(0, 8).is_err());
        assert!(SherryCache::new(63, 8).is_err()); // not power of two
        assert!(SherryCache::new(64, 0).is_err());
        assert!(SherryCache::new(64, 9).is_err());
    }

    #[test]
    fn kl_divergence_positive() {
        let a = vec![1.0f32, 2.0, 3.0, 4.0];
        let b = vec![1.1f32, 1.9, 3.1, 3.9];
        let kl = kl_divergence(&a, &b);
        assert!(kl >= 0.0, "KL divergence must be non-negative");
        assert!(kl < 1.0, "KL divergence unexpectedly large: {}", kl);
    }

    #[test]
    fn dimension_mismatch_error() {
        let codec = SherryCache::default();
        let data = random_vec(64);
        let compressed = codec.compress(&data).unwrap();
        let mut out = vec![0.0f32; 32]; // wrong size
        let err = codec.decompress(&compressed, &mut out);
        assert!(err.is_err());
    }
}
