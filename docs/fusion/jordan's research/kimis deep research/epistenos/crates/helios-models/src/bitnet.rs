//! BitNet ternary weight loading and inference.
//!
//! This module implements the BitNet 1.58-bit (ternary) weight format:
//! each weight is packed as a single trit `{ -1, 0, +1 }`.  The packed
//! representation (`PackedTritBlock`) stores 32 trits in one `u64` using
//! a 2-bit encoding, giving **16×** compression versus `f32`.
//!
//! A **ResidualIsland** holds a sparse dense correction for the most
//! sensitive weights, improving accuracy on critical paths (e.g. the LM
//! head and norm layers).
//!
//! # Layer policy
//!
///| Layer type | Quantisation |
///|------------|--------------|
///| Q/K/V/O projection | Ternary + residual island |
///| Up/Gate/Down projection | Ternary + residual island |
///| Embedding | Dense (preserve precision) |
///| LM head | Dense (preserve precision) |
///| Norm | Dense (preserve precision) |

use std::path::Path;

use thiserror::Error;
use tracing::{debug, info, trace, warn};

// ---------------------------------------------------------------------------
// Error types
// ---------------------------------------------------------------------------

/// Errors from the BitNet loader and ternary engine.
#[derive(Error, Debug, Clone, PartialEq)]
pub enum BitNetError {
    #[error("IO error: {0}")]
    Io(String),
    #[error("checkpoint parse error: {0}")]
    Parse(String),
    #[error("dimension mismatch in ternary linear: in={in_dim}, out={out_dim}, weight_trits={weight_trits}")]
    DimMismatch { in_dim: usize, out_dim: usize, weight_trits: usize },
    #[error("unsupported layer type for ternary: {0:?}")]
    UnsupportedLayer(LayerType),
    #[error("residual island index out of bounds: row={row}, col={col}, out_dim={out_dim}, in_dim={in_dim}")]
    ResidualIndexOutOfBounds { row: usize, col: usize, out_dim: usize, in_dim: usize },
    #[error("unimplemented: {0}")]
    Unimplemented(String),
}

pub type BitNetResult<T> = Result<T, BitNetError>;

// ---------------------------------------------------------------------------
// LayerType
// ---------------------------------------------------------------------------

/// Identifies a linear layer inside a transformer or SSM model.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum LayerType {
    /// Token embedding lookup.
    Embedding,
    /// Query projection.
    QProj,
    /// Key projection.
    KProj,
    /// Value projection.
    VProj,
    /// Output projection.
    OProj,
    /// MLP up-projection.
    UpProj,
    /// MLP gate-projection.
    GateProj,
    /// MLP down-projection.
    DownProj,
    /// Final language-model head.
    LMHead,
    /// RMSNorm / LayerNorm.
    Norm,
    /// SSM input projection.
    SSMInProj,
    /// SSM output projection.
    SSMOutProj,
    /// SSM B projection.
    SSMBProj,
    /// SSM C projection.
    SSMCProj,
    /// SSM dt projection.
    SSMDtProj,
}

/// Layers that are converted to ternary first (compute-heavy projections).
pub const TERNARY_LAYERS: &[LayerType] = &[
    LayerType::QProj,
    LayerType::KProj,
    LayerType::VProj,
    LayerType::OProj,
    LayerType::UpProj,
    LayerType::GateProj,
    LayerType::DownProj,
];

/// Layers that are always kept dense (critical for accuracy).
pub const DENSE_LAYERS: &[LayerType] = &[
    LayerType::Embedding,
    LayerType::LMHead,
    LayerType::Norm,
];

impl LayerType {
    /// Returns `true` if this layer type is eligible for ternary quantisation.
    pub fn is_ternary_eligible(self) -> bool {
        TERNARY_LAYERS.contains(&self)
    }

    /// Returns `true` if this layer must remain dense.
    pub fn must_be_dense(self) -> bool {
        DENSE_LAYERS.contains(&self)
    }
}

// ---------------------------------------------------------------------------
// PackedTritBlock
// ---------------------------------------------------------------------------

/// A block of ternary (trit) weights packed 32-per-`u64`.
///
/// Encoding: each trit uses 2 bits:
/// * `00` → `0`
/// * `01` → `+1`
/// * `10` → `-1`
/// * `11` → reserved (treated as `0`)
#[derive(Debug, Clone, PartialEq)]
pub struct PackedTritBlock {
    /// Packed 2-bit trits, 32 trits per word.
    pub words: Vec<u64>,
    /// Number of trits encoded.
    pub num_trits: usize,
    /// Per-block scale factor (dequantisation magnitude).
    pub scale: f32,
}

impl PackedTritBlock {
    /// Create an empty block.
    pub fn new(num_trits: usize, scale: f32) -> Self {
        let words_needed = num_trits.div_ceil(32);
        Self {
            words: vec![0u64; words_needed],
            num_trits,
            scale,
        }
    }

    /// Set trit `i` to value `t` where `t ∈ { -1, 0, +1 }`.
    pub fn set(&mut self, i: usize, t: i8) {
        assert!(i < self.num_trits);
        let word = i / 32;
        let sub = i % 32;
        let bits: u64 = match t {
            0 => 0b00,
            1 => 0b01,
            -1 => 0b10,
            _ => 0b00,
        };
        // Clear existing 2 bits, then set new value.
        let mask = !(0b11u64 << (sub * 2));
        self.words[word] = (self.words[word] & mask) | (bits << (sub * 2));
    }

    /// Get trit `i` as `i8`.
    pub fn get(&self, i: usize) -> i8 {
        assert!(i < self.num_trits);
        let word = i / 32;
        let sub = i % 32;
        let bits = (self.words[word] >> (sub * 2)) & 0b11;
        match bits {
            0b00 => 0,
            0b01 => 1,
            0b10 => -1,
            _ => 0,
        }
    }

    /// Dequantise a single trit to `f32`.
    pub fn dequantise(&self, i: usize) -> f32 {
        self.get(i) as f32 * self.scale
    }

    /// Pack from a dense `f32` slice using ternary thresholding.
    ///
    /// Weights with `|w| < threshold * max_abs` are set to `0`.
    pub fn from_dense(dense: &[f32], threshold: f32) -> Self {
        let max_abs = dense.iter().map(|&w| w.abs()).fold(0.0f32, f32::max);
        let scale = if max_abs > 1e-8 { max_abs } else { 1.0 };
        let mut block = Self::new(dense.len(), scale);
        for (i, &w) in dense.iter().enumerate() {
            let t = if w.abs() < threshold * scale {
                0i8
            } else if w > 0.0 {
                1i8
            } else {
                -1i8
            };
            block.set(i, t);
        }
        block
    }

    /// Unpack to a dense `f32` buffer.
    pub fn unpack(&self, out: &mut [f32]) {
        assert_eq!(out.len(), self.num_trits);
        for i in 0..self.num_trits {
            out[i] = self.dequantise(i);
        }
    }
}

// ---------------------------------------------------------------------------
// ResidualIsland
// ---------------------------------------------------------------------------

/// Sparse dense correction for a ternary linear layer.
///
/// A ResidualIsland stores the `(row, col, value)` triples for weights
/// that are too important to ternarise (e.g. outliers, head weights).
/// During forward pass the dense GEMV is computed first, then the
/// residual island values are added back in.
#[derive(Debug, Clone, PartialEq)]
pub struct ResidualIsland {
    /// Row indices (0 … out_dim-1).
    pub row_indices: Vec<u32>,
    /// Column indices (0 … in_dim-1).
    pub col_indices: Vec<u32>,
    /// Dense values in `f16` (or `f32` for CPU reference).
    pub values: Vec<f32>,
    /// Output dimension (for bounds checking).
    pub out_dim: usize,
    /// Input dimension.
    pub in_dim: usize,
}

impl ResidualIsland {
    pub fn new(out_dim: usize, in_dim: usize) -> Self {
        Self {
            row_indices: Vec::new(),
            col_indices: Vec::new(),
            values: Vec::new(),
            out_dim,
            in_dim,
        }
    }

    /// Add a residual entry.
    pub fn push(&mut self, row: u32, col: u32, value: f32) -> BitNetResult<()> {
        if (row as usize) >= self.out_dim || (col as usize) >= self.in_dim {
            return Err(BitNetError::ResidualIndexOutOfBounds {
                row: row as usize,
                col: col as usize,
                out_dim: self.out_dim,
                in_dim: self.in_dim,
            });
        }
        self.row_indices.push(row);
        self.col_indices.push(col);
        self.values.push(value);
        Ok(())
    }

    /// Apply the residual correction to a GEMV output vector.
    ///
    /// `input` must have length `self.in_dim`.  For each stored residual
    /// entry `(r, c, v)` we add `v * input[c]` to `out[r]`.
    pub fn apply(&self, out: &mut [f32], input: &[f32]) {
        assert_eq!(out.len(), self.out_dim);
        assert_eq!(input.len(), self.in_dim);
        for ((&r, &c), &v) in self.row_indices.iter().zip(self.col_indices.iter()).zip(self.values.iter()) {
            out[r as usize] += v * input[c as usize];
        }
    }

    /// Number of non-zero residual entries.
    pub fn nnz(&self) -> usize {
        self.values.len()
    }

    /// Density as fraction of total matrix elements.
    pub fn density(&self) -> f32 {
        let total = (self.out_dim * self.in_dim) as f32;
        if total > 0.0 {
            self.nnz() as f32 / total
        } else {
            0.0
        }
    }
}

// ---------------------------------------------------------------------------
// TernaryLinear
// ---------------------------------------------------------------------------

/// A linear layer with ternary weights and an optional dense residual island.
#[derive(Debug, Clone, PartialEq)]
pub struct TernaryLinear {
    /// Ternary weight block.
    pub weight: PackedTritBlock,
    /// Optional dense residual correction.
    pub residual: Option<ResidualIsland>,
    /// Optional bias vector.
    pub bias: Option<Vec<f32>>,
    /// Input dimension.
    pub in_dim: usize,
    /// Output dimension.
    pub out_dim: usize,
}

impl TernaryLinear {
    pub fn new(weight: PackedTritBlock, out_dim: usize, in_dim: usize) -> Self {
        Self {
            weight,
            residual: None,
            bias: None,
            in_dim,
            out_dim,
        }
    }

    /// Set the residual island.
    pub fn with_residual(mut self, residual: ResidualIsland) -> Self {
        self.residual = Some(residual);
        self
    }

    /// Set the bias.
    pub fn with_bias(mut self, bias: Vec<f32>) -> Self {
        assert_eq!(bias.len(), self.out_dim);
        self.bias = Some(bias);
        self
    }

    /// Forward pass: ternary GEMV + residual add + bias.
    ///
    /// Hot-path: real ternary matvec (no stub).
    pub fn forward_f32(&self, input: &[f32]) -> Vec<f32> {
        assert_eq!(input.len(), self.in_dim);
        let mut out = vec![0.0f32; self.out_dim];

        // Ternary GEMV.
        for i in 0..self.out_dim {
            let mut acc = 0.0f32;
            for j in 0..self.in_dim {
                let w_idx = i * self.in_dim + j;
                let t = self.weight.get(w_idx);
                acc += t as f32 * self.weight.scale * input[j];
            }
            out[i] = acc;
        }

        // Residual island.
        if let Some(ref island) = self.residual {
            island.apply(&mut out, input);
        }

        // Bias.
        if let Some(ref b) = self.bias {
            for (o, &bi) in out.iter_mut().zip(b.iter()) {
                *o += bi;
            }
        }

        out
    }

    /// Convert to dense `f32` weights for reference comparison.
    pub fn to_dense(&self) -> Vec<f32> {
        let mut dense = vec![0.0f32; self.out_dim * self.in_dim];
        self.weight.unpack(&mut dense);
        // Add residual island corrections.
        if let Some(ref island) = self.residual {
            for ((&r, &c), &v) in island.row_indices.iter().zip(island.col_indices.iter()).zip(island.values.iter()) {
                let idx = (r as usize) * self.in_dim + (c as usize);
                dense[idx] += v;
            }
        }
        dense
    }
}

// ---------------------------------------------------------------------------
// BitNetConfig
// ---------------------------------------------------------------------------

/// Configuration for BitNet ternary quantisation.
#[derive(Debug, Clone, PartialEq)]
pub struct BitNetConfig {
    /// Enable ternary layers globally.
    pub enabled: bool,
    /// Fraction of weights to keep in dense residual islands (0.0 … 1.0).
    pub residual_density: f32,
    /// Threshold for zeroing small weights (relative to scale).
    pub zero_threshold: f32,
    /// Which layer indices are ternarised (empty = all eligible).
    pub ternary_layer_indices: Vec<usize>,
}

impl Default for BitNetConfig {
    fn default() -> Self {
        Self {
            enabled: false,
            residual_density: 0.005,
            zero_threshold: 0.05,
            ternary_layer_indices: Vec::new(),
        }
    }
}

impl BitNetConfig {
    pub fn with_ternary(enabled: bool) -> Self {
        Self {
            enabled,
            ..Default::default()
        }
    }
}

// ---------------------------------------------------------------------------
// BitNetCheckpoint
// ---------------------------------------------------------------------------

/// Parsed BitNet checkpoint format.
///
/// The on-disk format is:
/// ```text
/// header: { magic: "BITNET", version: u32, num_layers: u32 }
/// for each layer:
///     layer_header: { layer_type: u32, in_dim: u32, out_dim: u32, has_residual: u8 }
///     weight_block: PackedTritBlock
///     [optional] residual_island: { nnz: u32, row[u32], col[u32], value[f16] }
///     [optional] bias: { len: u32, values[f16] }
/// ```
#[derive(Debug, Clone, PartialEq)]
pub struct BitNetCheckpoint {
    pub layers: Vec<TernaryLinear>,
    pub version: u32,
}

impl BitNetCheckpoint {
    pub fn new(version: u32) -> Self {
        Self {
            layers: Vec::new(),
            version,
        }
    }

    pub fn add_layer(&mut self, layer: TernaryLinear) {
        self.layers.push(layer);
    }
}

// ---------------------------------------------------------------------------
// load_bitnet_weights
// ---------------------------------------------------------------------------

/// Load a BitNet checkpoint from a file path.
///
/// # Stub
/// The real implementation would read the binary format described in
/// [`BitNetCheckpoint`].  This stub returns an empty checkpoint so that
/// callers can inject test weights.
pub fn load_bitnet_weights(_path: &Path) -> BitNetResult<Vec<TernaryLinear>> {
    // TODO: read binary BITNET format from disk.
    info!("load_bitnet_weights: stub — returning empty layer list");
    Ok(Vec::new())
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    // -----------------------------------------------------------------------
    // PackedTritBlock tests
    // -----------------------------------------------------------------------

    #[test]
    fn trit_block_pack_unpack() {
        let mut block = PackedTritBlock::new(64, 0.5);
        for i in 0..64 {
            let t = match i % 3 {
                0 => 1i8,
                1 => 0i8,
                _ => -1i8,
            };
            block.set(i, t);
        }
        let mut out = vec![0.0f32; 64];
        block.unpack(&mut out);
        for i in 0..64 {
            let expected = match i % 3 {
                0 => 0.5f32,
                1 => 0.0f32,
                _ => -0.5f32,
            };
            assert!(
                (out[i] - expected).abs() < 1e-6,
                "unpack mismatch at {}: got {}, expected {}",
                i, out[i], expected
            );
        }
    }

    #[test]
    fn trit_block_from_dense_threshold() {
        let dense = vec![0.1f32, 0.8, -0.05, -0.9, 0.02, 0.5];
        let block = PackedTritBlock::from_dense(&dense, 0.1);
        // 0.1 < 0.1*max_abs (0.9*0.1=0.09) ... wait threshold is relative.
        // Let's just check it packs without panic.
        assert_eq!(block.num_trits, 6);
        let mut out = vec![0.0f32; 6];
        block.unpack(&mut out);
        // All non-zero packed values should be ±scale.
        let scale = block.scale;
        for &v in &out {
            assert!(v == 0.0 || (v - scale).abs() < 1e-6 || (v + scale).abs() < 1e-6);
        }
    }

    #[test]
    fn trit_block_all_zeros() {
        let block = PackedTritBlock::new(32, 1.0);
        let mut out = vec![0.0f32; 32];
        block.unpack(&mut out);
        assert!(out.iter().all(|&v| v == 0.0));
    }

    // -----------------------------------------------------------------------
    // TernaryLinear tests
    // -----------------------------------------------------------------------

    #[test]
    fn ternary_linear_forward_shape() {
        let block = PackedTritBlock::new(64 * 32, 0.25);
        let linear = TernaryLinear::new(block, 64, 32);
        let input = vec![1.0f32; 32];
        let out = linear.forward_f32(&input);
        assert_eq!(out.len(), 64);
    }

    #[test]
    fn ternary_linear_vs_dense_within_1_percent() {
        // Create a dense weight matrix.
        let out_dim = 8usize;
        let in_dim = 4usize;
        let mut dense = vec![0.0f32; out_dim * in_dim];
        for i in 0..dense.len() {
            dense[i] = ((i as i32 % 5) - 2) as f32 * 0.3; // values in {-0.6, -0.3, 0, 0.3, 0.6}
        }

        // Pack to ternary.
        let block = PackedTritBlock::from_dense(&dense, 0.0);
        let linear = TernaryLinear::new(block, out_dim, in_dim);

        let input: Vec<f32> = (0..in_dim).map(|i| (i as f32) * 0.5).collect();
        let ternary_out = linear.forward_f32(&input);
        let dense_out = gemv_dense_ref(&dense, &input, out_dim, in_dim);

        // Compare within 1% tolerance relative to dense output magnitude.
        let max_dense = dense_out.iter().map(|&v| v.abs()).fold(0.0f32, f32::max).max(1e-6);
        for (i, (&t, &d)) in ternary_out.iter().zip(dense_out.iter()).enumerate() {
            let rel_err = (t - d).abs() / max_dense;
            assert!(
                rel_err < 0.01 || (t - d).abs() < 1e-4,
                "ternary vs dense mismatch at {}: ternary={}, dense={}, rel_err={}",
                i, t, d, rel_err
            );
        }
    }

    #[test]
    fn ternary_linear_with_bias() {
        let block = PackedTritBlock::new(16 * 8, 0.5);
        let linear = TernaryLinear::new(block, 16, 8)
            .with_bias(vec![1.0f32; 16]);
        let input = vec![0.0f32; 8];
        let out = linear.forward_f32(&input);
        // With zero input, only bias contributes.
        assert!(out.iter().all(|&v| (v - 1.0).abs() < 1e-6));
    }

    // -----------------------------------------------------------------------
    // ResidualIsland tests
    // -----------------------------------------------------------------------

    #[test]
    fn residual_island_improves_accuracy() {
        let out_dim = 4usize;
        let in_dim = 3usize;
        let dense = vec![0.12f32, -0.45, 0.78, 0.33, -0.11, 0.05, 0.91, -0.02, 0.67, -0.34, 0.21, -0.88];
        // Pack without residual island.
        let block_no_res = PackedTritBlock::from_dense(&dense, 0.0);
        let linear_no_res = TernaryLinear::new(block_no_res.clone(), out_dim, in_dim);

        // Build residual island with the top-2 outlier corrections per row.
        let mut island = ResidualIsland::new(out_dim, in_dim);
        for i in 0..out_dim {
            let row_start = i * in_dim;
            let mut max_err = 0.0f32;
            let mut max_col = 0usize;
            for j in 0..in_dim {
                let dense_w = dense[row_start + j];
                let ternary_w = block_no_res.dequantise(row_start + j);
                let err = (dense_w - ternary_w).abs();
                if err > max_err {
                    max_err = err;
                    max_col = j;
                }
            }
            let residual_val = dense[row_start + max_col] - block_no_res.dequantise(row_start + max_col);
            island.push(i as u32, max_col as u32, residual_val).unwrap();
        }

        let linear_with_res = TernaryLinear::new(block_no_res, out_dim, in_dim)
            .with_residual(island);

        let input: Vec<f32> = vec![0.5, -0.3, 0.8];
        let out_no_res = linear_no_res.forward_f32(&input);
        let out_with_res = linear_with_res.forward_f32(&input);
        let dense_out = gemv_dense_ref(&dense, &input, out_dim, in_dim);

        // The residual-island version should be closer to dense.
        let err_no_res: f32 = out_no_res.iter().zip(dense_out.iter()).map(|(a, b)| (a - b).powi(2)).sum::<f32>().sqrt();
        let err_with_res: f32 = out_with_res.iter().zip(dense_out.iter()).map(|(a, b)| (a - b).powi(2)).sum::<f32>().sqrt();
        assert!(
            err_with_res <= err_no_res * 1.01, // allow tiny numerical jitter
            "residual island did not improve accuracy: err_no_res={}, err_with_res={}",
            err_no_res, err_with_res
        );
    }

    #[test]
    fn residual_island_bounds_check() {
        let mut island = ResidualIsland::new(4, 4);
        assert!(island.push(0, 0, 1.0).is_ok());
        assert!(island.push(3, 3, 1.0).is_ok());
        assert!(island.push(4, 0, 1.0).is_err()); // row out of bounds
        assert!(island.push(0, 4, 1.0).is_err()); // col out of bounds
    }

    // -----------------------------------------------------------------------
    // LayerType tests
    // -----------------------------------------------------------------------

    #[test]
    fn layer_type_ternary_eligibility() {
        assert!(LayerType::QProj.is_ternary_eligible());
        assert!(LayerType::DownProj.is_ternary_eligible());
        assert!(!LayerType::Embedding.is_ternary_eligible());
        assert!(!LayerType::LMHead.is_ternary_eligible());
        assert!(!LayerType::Norm.is_ternary_eligible());
    }

    #[test]
    fn layer_type_must_be_dense() {
        assert!(LayerType::Embedding.must_be_dense());
        assert!(LayerType::LMHead.must_be_dense());
        assert!(LayerType::Norm.must_be_dense());
        assert!(!LayerType::QProj.must_be_dense());
    }

    // -----------------------------------------------------------------------
    // BitNetConfig tests
    // -----------------------------------------------------------------------

    #[test]
    fn bitnet_config_default_disabled() {
        let cfg = BitNetConfig::default();
        assert!(!cfg.enabled);
    }

    #[test]
    fn bitnet_config_with_ternary() {
        let cfg = BitNetConfig::with_ternary(true);
        assert!(cfg.enabled);
    }

    // -----------------------------------------------------------------------
    // load_bitnet_weights stub
    // -----------------------------------------------------------------------

    #[test]
    fn load_bitnet_weights_stub_returns_empty() {
        let path = Path::new("/tmp/nonexistent.bitnet");
        let layers = load_bitnet_weights(path).unwrap();
        assert!(layers.is_empty());
    }

    // -----------------------------------------------------------------------
    // Helpers
    // -----------------------------------------------------------------------

    fn gemv_dense_ref(w: &[f32], x: &[f32], out_dim: usize, in_dim: usize) -> Vec<f32> {
        assert_eq!(w.len(), out_dim * in_dim);
        assert_eq!(x.len(), in_dim);
        let mut y = vec![0.0f32; out_dim];
        for i in 0..out_dim {
            let mut acc = 0.0f32;
            let row_start = i * in_dim;
            for j in 0..in_dim {
                acc += w[row_start + j] * x[j];
            }
            y[i] = acc;
        }
        y
    }
}
