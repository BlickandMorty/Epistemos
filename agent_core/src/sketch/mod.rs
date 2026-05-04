//! Core sketch primitives for the future L2 Shadow Sketch tier.
//!
//! This module re-derives GPT's CountSketch, sparse Johnson-Lindenstrauss, and
//! free-random-projection mockup into Epistemos shape: deterministic hashing,
//! explicit shape validation, no public panics, and bounded allocations. The
//! current role is a Core-safe Rust foundation; runtime graph/RRF wiring remains
//! a later slice.

use serde::{Deserialize, Serialize};

/// CountSketch with deterministic FNV-derived hash families.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct CountSketch {
    width: usize,
    depth: usize,
    seed: u64,
    buckets: Vec<Vec<f32>>,
}

impl CountSketch {
    pub fn new(width: usize, depth: usize, seed: u64) -> Result<Self, SketchError> {
        if width == 0 || depth == 0 {
            return Err(SketchError::InvalidShape);
        }
        Ok(Self {
            width,
            depth,
            seed,
            buckets: vec![vec![0.0; width]; depth],
        })
    }

    pub fn update(&mut self, key: &[u8], value: f32) -> Result<(), SketchError> {
        validate_finite(value)?;
        for row in 0..self.depth {
            let h = self.hash_for_row(key, row);
            let bucket = (h as usize) % self.width;
            self.buckets[row][bucket] += sign_from_hash(h) * value;
        }
        Ok(())
    }

    pub fn estimate(&self, key: &[u8]) -> Result<f32, SketchError> {
        let mut estimates = Vec::with_capacity(self.depth);
        for row in 0..self.depth {
            let h = self.hash_for_row(key, row);
            let bucket = (h as usize) % self.width;
            estimates.push(sign_from_hash(h) * self.buckets[row][bucket]);
        }
        median(&mut estimates).ok_or(SketchError::InvalidShape)
    }

    pub fn top_k<'a>(
        &self,
        keys: &'a [&'a [u8]],
        k: usize,
    ) -> Result<Vec<(&'a [u8], f32)>, SketchError> {
        let mut pairs = Vec::with_capacity(keys.len());
        for key in keys {
            pairs.push((*key, self.estimate(key)?));
        }
        pairs.sort_by(|lhs, rhs| rhs.1.total_cmp(&lhs.1).then_with(|| lhs.0.cmp(rhs.0)));
        pairs.truncate(k.min(pairs.len()));
        Ok(pairs)
    }

    pub const fn width(&self) -> usize {
        self.width
    }

    pub const fn depth(&self) -> usize {
        self.depth
    }

    pub fn buckets(&self) -> &[Vec<f32>] {
        &self.buckets
    }

    fn hash_for_row(&self, key: &[u8], row: usize) -> u64 {
        hash64(
            key,
            self.seed ^ ((row as u64).wrapping_mul(0x9E37_79B9_7F4A_7C15)),
        )
    }
}

/// Sparse Johnson-Lindenstrauss projection matrix generated on the fly.
#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct SparseJlMatrix {
    rows: usize,
    cols: usize,
    sparsity: usize,
    seed: u64,
}

impl SparseJlMatrix {
    pub fn new(rows: usize, cols: usize, sparsity: usize, seed: u64) -> Result<Self, SketchError> {
        if rows == 0 || cols == 0 || sparsity == 0 {
            return Err(SketchError::InvalidShape);
        }
        Ok(Self {
            rows,
            cols,
            sparsity,
            seed,
        })
    }

    pub fn project_i8(&self, vector: &[f32]) -> Result<Vec<i8>, SketchError> {
        validate_dim(self.cols, vector.len())?;
        validate_vector(vector)?;

        let mut out = vec![0.0_f32; self.rows];
        let scale = (self.sparsity as f32).sqrt();
        for (col, value) in vector.iter().enumerate() {
            for sample in 0..self.sparsity {
                let h = mix64(self.seed ^ ((col as u64) << 32) ^ (sample as u64));
                let row = (h as usize) % self.rows;
                out[row] += sign_from_hash(h) * *value / scale;
            }
        }
        Ok(out
            .into_iter()
            .map(|value| value.round().clamp(-127.0, 127.0) as i8)
            .collect())
    }

    pub const fn rows(&self) -> usize {
        self.rows
    }

    pub const fn cols(&self) -> usize {
        self.cols
    }

    pub const fn sparsity(&self) -> usize {
        self.sparsity
    }
}

/// Free-random-projection-inspired basis: sign flip + permutation + FWHT.
#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct FrpBasis {
    dimension: usize,
    seed: u64,
}

impl FrpBasis {
    pub fn new(dimension: usize, seed: u64) -> Result<Self, SketchError> {
        if dimension == 0 || !dimension.is_power_of_two() {
            return Err(SketchError::InvalidShape);
        }
        Ok(Self { dimension, seed })
    }

    pub fn project(&self, vector: &[f32], runtime_seed: u64) -> Result<Vec<f32>, SketchError> {
        validate_dim(self.dimension, vector.len())?;
        validate_vector(vector)?;

        let mut out = vec![0.0; self.dimension];
        let shift = (mix64(self.seed ^ runtime_seed) as usize) % self.dimension;
        for (idx, dst) in out.iter_mut().enumerate() {
            let src = (idx + shift) % self.dimension;
            let h = mix64(self.seed ^ runtime_seed ^ (idx as u64));
            *dst = sign_from_hash(h) * vector[src];
        }
        fwht_inplace(&mut out)?;
        let norm = (self.dimension as f32).sqrt();
        for value in &mut out {
            *value /= norm;
        }
        Ok(out)
    }

    pub const fn dimension(&self) -> usize {
        self.dimension
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub enum SketchError {
    InvalidShape,
    DimensionMismatch { expected: usize, actual: usize },
    InvalidValue,
}

fn fwht_inplace(values: &mut [f32]) -> Result<(), SketchError> {
    if values.is_empty() || !values.len().is_power_of_two() {
        return Err(SketchError::InvalidShape);
    }
    let mut h = 1;
    while h < values.len() {
        for idx in (0..values.len()).step_by(h * 2) {
            for offset in idx..(idx + h) {
                let x = values[offset];
                let y = values[offset + h];
                values[offset] = x + y;
                values[offset + h] = x - y;
            }
        }
        h *= 2;
    }
    Ok(())
}

fn median(values: &mut [f32]) -> Option<f32> {
    if values.is_empty() {
        return None;
    }
    values.sort_by(f32::total_cmp);
    Some(values[values.len() / 2])
}

fn hash64(bytes: &[u8], seed: u64) -> u64 {
    let mut hash = 0xcbf2_9ce4_8422_2325_u64 ^ seed;
    for byte in bytes {
        hash ^= u64::from(*byte);
        hash = hash.wrapping_mul(0x1000_0000_01b3);
    }
    mix64(hash)
}

fn mix64(mut value: u64) -> u64 {
    value ^= value >> 30;
    value = value.wrapping_mul(0xbf58_476d_1ce4_e5b9);
    value ^= value >> 27;
    value = value.wrapping_mul(0x94d0_49bb_1331_11eb);
    value ^ (value >> 31)
}

fn sign_from_hash(hash: u64) -> f32 {
    if (hash >> 63) == 0 {
        1.0
    } else {
        -1.0
    }
}

fn validate_vector(vector: &[f32]) -> Result<(), SketchError> {
    if vector.iter().any(|value| !value.is_finite()) {
        return Err(SketchError::InvalidValue);
    }
    Ok(())
}

fn validate_finite(value: f32) -> Result<(), SketchError> {
    if value.is_finite() {
        Ok(())
    } else {
        Err(SketchError::InvalidValue)
    }
}

fn validate_dim(expected: usize, actual: usize) -> Result<(), SketchError> {
    if expected == actual {
        Ok(())
    } else {
        Err(SketchError::DimensionMismatch { expected, actual })
    }
}
