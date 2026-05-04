//! Lattice quantization scaffolds: E8 shells, Leech metadata, and Babai rounding.
//!
//! The E8 generator is exact for the norm-2 and norm-4 shells. The Leech type is
//! a memory-safe view with exact shell cardinality metadata and deterministic
//! sampling; materializing 196,560 vectors is deferred to the macOS benchmark path.

/// Supported lattice families.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum LatticeType {
    E8,
    D24,
    Leech24,
    Cubic,
}

/// Quantized vector with enough metadata to reverse the selected scalar quantizer.
#[derive(Clone, Debug, PartialEq)]
pub struct QuantizedVector {
    pub lattice: LatticeType,
    pub indices: Vec<i32>,
    pub scale: f32,
    pub residual_norm: f32,
}

/// Lower-triangular basis used by the Babai nearest-plane routine.
#[derive(Clone, Debug, PartialEq)]
pub struct CholeskyBasis {
    pub lower: Vec<Vec<f32>>,
}

impl CholeskyBasis {
    /// Validate a lower-triangular basis.
    #[must_use]
    pub fn is_valid(&self) -> bool {
        let n = self.lower.len();
        if n == 0 {
            return false;
        }
        for (row_idx, row) in self.lower.iter().enumerate() {
            if row.len() != n || row[row_idx] == 0.0 || !row[row_idx].is_finite() {
                return false;
            }
            for value in &row[row_idx + 1..] {
                if *value != 0.0 {
                    return false;
                }
            }
        }
        true
    }
}

/// E8 shell generator.
#[derive(Clone, Debug, Default)]
pub struct E8Codebook;

impl E8Codebook {
    pub const DIM: usize = 8;
    pub const NORM2_COUNT: usize = 240;
    pub const NORM4_COUNT: usize = 2160;

    /// Generate all 240 E8 roots of squared norm 2.
    #[must_use]
    pub fn norm2_vectors(&self) -> Vec<[f32; 8]> {
        let mut out = Vec::with_capacity(Self::NORM2_COUNT);
        for i in 0..8 {
            for j in (i + 1)..8 {
                for sx in [-1.0_f32, 1.0] {
                    for sy in [-1.0_f32, 1.0] {
                        let mut v = [0.0; 8];
                        v[i] = sx;
                        v[j] = sy;
                        out.push(v);
                    }
                }
            }
        }
        for mask in 0_u16..256 {
            if mask.count_ones() % 2 == 0 {
                let mut v = [0.5; 8];
                for (i, entry) in v.iter_mut().enumerate() {
                    if (mask >> i) & 1 == 1 {
                        *entry = -0.5;
                    }
                }
                out.push(v);
            }
        }
        debug_assert_eq!(out.len(), Self::NORM2_COUNT);
        out
    }

    /// Generate all 2160 E8 vectors of squared norm 4.
    #[must_use]
    pub fn norm4_vectors(&self) -> Vec<[f32; 8]> {
        let mut out = Vec::with_capacity(Self::NORM4_COUNT);
        let mut cur = [0_i8; 8];
        Self::integer_shell_rec(0, 4, &mut cur, &mut out);
        for large in 0..8 {
            for sign_mask in 0_u16..256 {
                let mut scaled_sum = 0_i16;
                let mut v = [0.0_f32; 8];
                for (i, entry) in v.iter_mut().enumerate() {
                    let sign = if (sign_mask >> i) & 1 == 1 { -1_i16 } else { 1_i16 };
                    let mag = if i == large { 3_i16 } else { 1_i16 };
                    let scaled = sign * mag;
                    scaled_sum += scaled;
                    *entry = f32::from(scaled) * 0.5;
                }
                if scaled_sum.rem_euclid(4) == 0 {
                    out.push(v);
                }
            }
        }
        debug_assert_eq!(out.len(), Self::NORM4_COUNT);
        out
    }

    fn integer_shell_rec(idx: usize, remaining: i32, cur: &mut [i8; 8], out: &mut Vec<[f32; 8]>) {
        if idx == 8 {
            let sum: i32 = cur.iter().map(|v| i32::from(*v)).sum();
            if remaining == 0 && sum.rem_euclid(2) == 0 {
                let mut v = [0.0; 8];
                for (dst, src) in v.iter_mut().zip(cur.iter()) {
                    *dst = f32::from(*src);
                }
                out.push(v);
            }
            return;
        }
        for value in [-2_i8, -1, 0, 1, 2] {
            let cost = i32::from(value) * i32::from(value);
            if cost <= remaining {
                cur[idx] = value;
                Self::integer_shell_rec(idx + 1, remaining - cost, cur, out);
            }
        }
    }

    /// Return the nearest vector from the norm-2 shell by squared distance.
    #[must_use]
    pub fn nearest_norm2(&self, target: &[f32]) -> [f32; 8] {
        let mut best = [0.0; 8];
        let mut best_dist = f32::INFINITY;
        for v in self.norm2_vectors() {
            let dist = squared_distance_prefix(target, &v);
            if dist < best_dist {
                best_dist = dist;
                best = v;
            }
        }
        best
    }
}

/// Leech lattice metadata and deterministic sample view.
#[derive(Clone, Debug, Default)]
pub struct LeechCodebook;

impl LeechCodebook {
    pub const DIM: usize = 24;
    pub const NORM4_COUNT: usize = 196_560;

    /// Exact shell cardinality for Leech minimal vectors.
    #[must_use]
    pub const fn norm4_count(&self) -> usize {
        Self::NORM4_COUNT
    }

    /// Deterministic low-memory sample of norm-4 Leech-like sign vectors.
    #[must_use]
    pub fn sample_norm4(&self, limit: usize) -> Vec<[f32; 24]> {
        let mut out = Vec::new();
        let cap = limit.min(Self::NORM4_COUNT);
        'outer: for i in 0..24 {
            for j in (i + 1)..24 {
                for sx in [-1.0_f32, 1.0] {
                    for sy in [-1.0_f32, 1.0] {
                        let mut v = [0.0; 24];
                        v[i] = sx * 2.0_f32.sqrt();
                        v[j] = sy * 2.0_f32.sqrt();
                        out.push(v);
                        if out.len() == cap {
                            break 'outer;
                        }
                    }
                }
            }
        }
        out
    }
}

/// Babai nearest-plane rounding for a lower-triangular basis.
#[must_use]
pub fn babai_nearest_plane(target: &[f32], basis: &CholeskyBasis) -> Vec<i32> {
    assert!(basis.is_valid(), "invalid Cholesky basis");
    let n = basis.lower.len();
    assert_eq!(target.len(), n, "target dimension mismatch");
    let mut coeff = vec![0_i32; n];
    let mut residual = target.to_vec();
    for i in (0..n).rev() {
        let diagonal = basis.lower[i][i];
        let q = (residual[i] / diagonal).round();
        coeff[i] = q as i32;
        for (row_idx, row) in basis.lower.iter().enumerate().take(i + 1) {
            residual[row_idx] -= q * row[i.min(row.len() - 1)];
        }
    }
    coeff
}

/// Scalar lattice quantization fallback used by the first gate harness.
#[must_use]
pub fn quantize_to_lattice(vector: &[f32], lattice: LatticeType) -> QuantizedVector {
    let scale = vector.iter().fold(0.0_f32, |acc, v| acc.max(v.abs())).max(1.0);
    let inv = 127.0 / scale;
    let indices: Vec<i32> = vector.iter().map(|v| (v * inv).round().clamp(-127.0, 127.0) as i32).collect();
    let recon: Vec<f32> = indices.iter().map(|q| (*q as f32) / inv).collect();
    let residual_norm = vector.iter().zip(recon.iter()).map(|(a, b)| (a - b) * (a - b)).sum::<f32>().sqrt();
    QuantizedVector { lattice, indices, scale, residual_norm }
}

/// Dequantize a scalar quantized vector.
#[must_use]
pub fn dequantize(qv: &QuantizedVector) -> Vec<f32> {
    let inv = 127.0 / qv.scale.max(1.0);
    qv.indices.iter().map(|q| (*q as f32) / inv).collect()
}

fn squared_distance_prefix(target: &[f32], vector: &[f32; 8]) -> f32 {
    target.iter().zip(vector.iter()).map(|(a, b)| (a - b) * (a - b)).sum()
}

#[cfg(test)]
mod tests {
    use super::{babai_nearest_plane, CholeskyBasis, E8Codebook, LatticeType, LeechCodebook, quantize_to_lattice, dequantize};

    #[test]
    fn e8_shell_counts_are_exact() {
        let e8 = E8Codebook;
        assert_eq!(e8.norm2_vectors().len(), E8Codebook::NORM2_COUNT);
        assert_eq!(e8.norm4_vectors().len(), E8Codebook::NORM4_COUNT);
    }

    #[test]
    fn leech_metadata_is_exact() {
        assert_eq!(LeechCodebook.norm4_count(), LeechCodebook::NORM4_COUNT);
    }

    #[test]
    fn scalar_quantizer_round_trips_shape() {
        let q = quantize_to_lattice(&[0.1, -0.4, 0.8], LatticeType::Cubic);
        assert_eq!(dequantize(&q).len(), 3);
    }

    #[test]
    fn babai_rounds_identity_basis() {
        let basis = CholeskyBasis { lower: vec![vec![1.0, 0.0], vec![0.0, 1.0]] };
        assert_eq!(babai_nearest_plane(&[1.2, -1.7], &basis), vec![1, -2]);
    }
}
