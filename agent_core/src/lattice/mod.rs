//! Core lattice primitives for the HELIOS hot-path verification floor.
//!
//! This module re-derives the GPT research lattice mockup into Epistemos shape:
//! exact E8 shell generation, Leech shell metadata with bounded samples, safe
//! Babai rounding for lower-triangular bases, and a scalar quantization fallback
//! that reports its `T_Q` contribution to WBO-6. The mathematical anchors are
//! Conway-Sloane for E8/Leech lattice structure and Babai, "On Lovasz' lattice
//! reduction and the nearest lattice point problem" (1986), for nearest-plane
//! rounding; this file is an executable budget surface, not a proof artifact.

use crate::wbo6::{Wbo6Error, Wbo6Term, Wbo6Terms};
use serde::{Deserialize, Serialize};

/// Supported lattice families for the Core quantization surface.
#[derive(Clone, Copy, Debug, Eq, PartialEq, Hash, Serialize, Deserialize)]
pub enum LatticeFamily {
    E8,
    D24,
    Leech24,
    Cubic,
}

impl LatticeFamily {
    pub const fn expected_dim(self) -> Option<usize> {
        match self {
            LatticeFamily::E8 => Some(E8Codebook::DIM),
            LatticeFamily::D24 | LatticeFamily::Leech24 => Some(LeechCodebook::DIM),
            LatticeFamily::Cubic => None,
        }
    }
}

/// Scalar-quantized vector plus the drift needed by the WBO-6 `T_Q` term.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct QuantizedVector {
    pub family: LatticeFamily,
    pub indices: Vec<i32>,
    pub scale: f32,
    pub residual_norm: f32,
}

impl QuantizedVector {
    pub fn quantization_budget_terms(&self) -> Result<Wbo6Terms, Wbo6Error> {
        Wbo6Terms::from_pairs([(Wbo6Term::Quantization, f64::from(self.residual_norm))])
    }
}

/// Lower-triangular basis used by the Babai nearest-plane routine.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct CholeskyBasis {
    pub lower: Vec<Vec<f32>>,
}

impl CholeskyBasis {
    pub fn new(lower: Vec<Vec<f32>>) -> Result<Self, LatticeError> {
        let basis = Self { lower };
        basis.validate()?;
        Ok(basis)
    }

    pub fn validate(&self) -> Result<(), LatticeError> {
        let n = self.lower.len();
        if n == 0 {
            return Err(LatticeError::InvalidBasis);
        }
        for (row_idx, row) in self.lower.iter().enumerate() {
            if row.len() != n {
                return Err(LatticeError::InvalidBasis);
            }
            for value in row {
                if !value.is_finite() {
                    return Err(LatticeError::InvalidValue);
                }
            }
            if self.lower[row_idx][row_idx] <= 0.0 {
                return Err(LatticeError::InvalidBasis);
            }
            if row[row_idx + 1..].iter().any(|value| *value != 0.0) {
                return Err(LatticeError::InvalidBasis);
            }
        }
        Ok(())
    }

    pub const fn dim(&self) -> usize {
        self.lower.len()
    }
}

/// E8 shell generator. Counts are exact and asserted by tests.
#[derive(Clone, Copy, Debug, Default, Eq, PartialEq)]
pub struct E8Codebook;

impl E8Codebook {
    pub const DIM: usize = 8;
    pub const NORM2_COUNT: usize = 240;
    pub const NORM4_COUNT: usize = 2_160;

    #[must_use]
    pub fn norm2_vectors(self) -> Vec<[f32; Self::DIM]> {
        let mut out = Vec::with_capacity(Self::NORM2_COUNT);
        for i in 0..Self::DIM {
            for j in (i + 1)..Self::DIM {
                for sx in [-1.0_f32, 1.0] {
                    for sy in [-1.0_f32, 1.0] {
                        let mut vector = [0.0; Self::DIM];
                        vector[i] = sx;
                        vector[j] = sy;
                        out.push(vector);
                    }
                }
            }
        }
        for mask in 0_u16..256 {
            if mask.count_ones() % 2 == 0 {
                let mut vector = [0.5; Self::DIM];
                for (idx, entry) in vector.iter_mut().enumerate() {
                    if (mask >> idx) & 1 == 1 {
                        *entry = -0.5;
                    }
                }
                out.push(vector);
            }
        }
        debug_assert_eq!(out.len(), Self::NORM2_COUNT);
        out
    }

    #[must_use]
    pub fn norm4_vectors(self) -> Vec<[f32; Self::DIM]> {
        let mut out = Vec::with_capacity(Self::NORM4_COUNT);
        let mut current = [0_i8; Self::DIM];
        Self::integer_shell_rec(0, 4, &mut current, &mut out);

        for large_coordinate in 0..Self::DIM {
            for sign_mask in 0_u16..256 {
                let mut scaled_sum = 0_i16;
                let mut vector = [0.0_f32; Self::DIM];
                for (idx, entry) in vector.iter_mut().enumerate() {
                    let sign = if (sign_mask >> idx) & 1 == 1 {
                        -1_i16
                    } else {
                        1_i16
                    };
                    let magnitude = if idx == large_coordinate {
                        3_i16
                    } else {
                        1_i16
                    };
                    let scaled = sign * magnitude;
                    scaled_sum += scaled;
                    *entry = f32::from(scaled) * 0.5;
                }
                if scaled_sum.rem_euclid(4) == 0 {
                    out.push(vector);
                }
            }
        }
        debug_assert_eq!(out.len(), Self::NORM4_COUNT);
        out
    }

    pub fn nearest_norm2(self, target: &[f32]) -> Result<[f32; Self::DIM], LatticeError> {
        validate_vector(target)?;
        validate_dim(Self::DIM, target.len())?;

        let mut best = [0.0; Self::DIM];
        let mut best_dist = f32::INFINITY;
        for vector in self.norm2_vectors() {
            let dist = squared_distance(target, &vector);
            if dist < best_dist {
                best_dist = dist;
                best = vector;
            }
        }
        Ok(best)
    }

    fn integer_shell_rec(
        idx: usize,
        remaining: i32,
        current: &mut [i8; Self::DIM],
        out: &mut Vec<[f32; Self::DIM]>,
    ) {
        if idx == Self::DIM {
            let sum: i32 = current.iter().map(|value| i32::from(*value)).sum();
            if remaining == 0 && sum.rem_euclid(2) == 0 {
                let mut vector = [0.0; Self::DIM];
                for (dst, src) in vector.iter_mut().zip(current.iter()) {
                    *dst = f32::from(*src);
                }
                out.push(vector);
            }
            return;
        }

        for value in [-2_i8, -1, 0, 1, 2] {
            let cost = i32::from(value) * i32::from(value);
            if cost <= remaining {
                current[idx] = value;
                Self::integer_shell_rec(idx + 1, remaining - cost, current, out);
            }
        }
    }
}

/// Leech lattice metadata. Full 196,560-vector materialization is not hot-path.
#[derive(Clone, Copy, Debug, Default, Eq, PartialEq)]
pub struct LeechCodebook;

impl LeechCodebook {
    pub const DIM: usize = 24;
    pub const NORM4_COUNT: usize = 196_560;

    pub const fn norm4_count(self) -> usize {
        Self::NORM4_COUNT
    }

    #[must_use]
    pub fn sample_norm4(self, limit: usize) -> Vec<[f32; Self::DIM]> {
        let cap = limit.min(Self::NORM4_COUNT);
        if cap == 0 {
            return Vec::new();
        }
        let mut out = Vec::with_capacity(cap.min(Self::DIM * (Self::DIM - 1) * 2));
        'outer: for i in 0..Self::DIM {
            for j in (i + 1)..Self::DIM {
                for sx in [-1.0_f32, 1.0] {
                    for sy in [-1.0_f32, 1.0] {
                        let mut vector = [0.0; Self::DIM];
                        vector[i] = sx * 2.0_f32.sqrt();
                        vector[j] = sy * 2.0_f32.sqrt();
                        out.push(vector);
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

/// Babai nearest-plane rounding for a lower-triangular Cholesky-like basis.
///
/// The donor mockup iterated a lower-triangular basis backward. Epistemos uses a
/// forward column update so lower-triangular dependencies are handled directly.
pub fn babai_nearest_plane(
    target: &[f32],
    basis: &CholeskyBasis,
) -> Result<Vec<i32>, LatticeError> {
    basis.validate()?;
    validate_vector(target)?;
    let n = basis.dim();
    validate_dim(n, target.len())?;

    let mut coeff = vec![0_i32; n];
    let mut residual = target.to_vec();
    for i in 0..n {
        let q = (residual[i] / basis.lower[i][i]).round();
        if !q.is_finite() || q < i32::MIN as f32 || q > i32::MAX as f32 {
            return Err(LatticeError::InvalidValue);
        }
        coeff[i] = q as i32;
        for (row_idx, residual_value) in residual.iter_mut().enumerate().skip(i) {
            *residual_value -= q * basis.lower[row_idx][i];
        }
    }
    Ok(coeff)
}

/// Scalar quantization fallback for Core-safe budget tests.
pub fn quantize_to_lattice(
    vector: &[f32],
    family: LatticeFamily,
) -> Result<QuantizedVector, LatticeError> {
    validate_vector(vector)?;
    if let Some(expected) = family.expected_dim() {
        validate_dim(expected, vector.len())?;
    }

    let scale = vector
        .iter()
        .fold(0.0_f32, |acc, value| acc.max(value.abs()))
        .max(1.0);
    let inverse_scale = 127.0 / scale;
    let indices: Vec<i32> = vector
        .iter()
        .map(|value| (value * inverse_scale).round().clamp(-127.0, 127.0) as i32)
        .collect();
    let reconstructed: Vec<f32> = indices
        .iter()
        .map(|quantized| (*quantized as f32) / inverse_scale)
        .collect();
    let residual_norm = vector
        .iter()
        .zip(reconstructed.iter())
        .map(|(lhs, rhs)| (lhs - rhs) * (lhs - rhs))
        .sum::<f32>()
        .sqrt();

    Ok(QuantizedVector {
        family,
        indices,
        scale,
        residual_norm,
    })
}

pub fn dequantize(quantized: &QuantizedVector) -> Result<Vec<f32>, LatticeError> {
    if quantized.indices.is_empty()
        || !quantized.scale.is_finite()
        || quantized.scale <= 0.0
        || !quantized.residual_norm.is_finite()
        || quantized.residual_norm < 0.0
    {
        return Err(LatticeError::InvalidValue);
    }
    if let Some(expected) = quantized.family.expected_dim() {
        validate_dim(expected, quantized.indices.len())?;
    }

    let inverse_scale = 127.0 / quantized.scale.max(1.0);
    Ok(quantized
        .indices
        .iter()
        .map(|quantized| (*quantized as f32) / inverse_scale)
        .collect())
}

#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub enum LatticeError {
    EmptyVector,
    DimensionMismatch { expected: usize, actual: usize },
    InvalidBasis,
    InvalidValue,
}

fn validate_vector(vector: &[f32]) -> Result<(), LatticeError> {
    if vector.is_empty() {
        return Err(LatticeError::EmptyVector);
    }
    if vector.iter().any(|value| !value.is_finite()) {
        return Err(LatticeError::InvalidValue);
    }
    Ok(())
}

fn validate_dim(expected: usize, actual: usize) -> Result<(), LatticeError> {
    if expected == actual {
        Ok(())
    } else {
        Err(LatticeError::DimensionMismatch { expected, actual })
    }
}

fn squared_distance(target: &[f32], vector: &[f32; E8Codebook::DIM]) -> f32 {
    target
        .iter()
        .zip(vector.iter())
        .map(|(lhs, rhs)| (lhs - rhs) * (lhs - rhs))
        .sum()
}
