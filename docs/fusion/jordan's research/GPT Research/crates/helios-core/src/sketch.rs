//! Sparse sketch operators for L2 shadow memory.

/// CountSketch with deterministic FNV-derived hash families.
#[derive(Clone, Debug, PartialEq)]
pub struct CountSketch {
    width: usize,
    depth: usize,
    seed: u64,
    buckets: Vec<Vec<f32>>,
}

impl CountSketch {
    /// Create a CountSketch with `depth` hash rows and `width` buckets per row.
    #[must_use]
    pub fn new(width: usize, depth: usize, seed: u64) -> Self {
        assert!(width > 0, "width must be nonzero");
        assert!(depth > 0, "depth must be nonzero");
        Self { width, depth, seed, buckets: vec![vec![0.0; width]; depth] }
    }

    /// Streaming update of one keyed value.
    pub fn update(&mut self, key: &[u8], value: f32) {
        for row in 0..self.depth {
            let h = hash64(key, self.seed ^ ((row as u64) * 0x9E37_79B9_7F4A_7C15));
            let bucket = (h as usize) % self.width;
            let sign = if (h >> 63) == 0 { 1.0 } else { -1.0 };
            self.buckets[row][bucket] += sign * value;
        }
    }

    /// Median-of-means estimate for a key.
    #[must_use]
    pub fn estimate(&self, key: &[u8]) -> f32 {
        let mut estimates = Vec::with_capacity(self.depth);
        for row in 0..self.depth {
            let h = hash64(key, self.seed ^ ((row as u64) * 0x9E37_79B9_7F4A_7C15));
            let bucket = (h as usize) % self.width;
            let sign = if (h >> 63) == 0 { 1.0 } else { -1.0 };
            estimates.push(sign * self.buckets[row][bucket]);
        }
        median(&mut estimates)
    }

    /// Return top-k keyed estimates.
    #[must_use]
    pub fn top_k<'a>(&self, keys: &'a [&'a [u8]], k: usize) -> Vec<(&'a [u8], f32)> {
        let mut pairs: Vec<(&[u8], f32)> = keys.iter().map(|key| (*key, self.estimate(key))).collect();
        pairs.sort_by(|a, b| b.1.total_cmp(&a.1));
        pairs.truncate(k.min(pairs.len()));
        pairs
    }

    /// Width in buckets.
    #[must_use]
    pub const fn width(&self) -> usize { self.width }

    /// Depth in hash rows.
    #[must_use]
    pub const fn depth(&self) -> usize { self.depth }
}

/// Sparse Johnson-Lindenstrauss projection matrix generated on the fly.
#[derive(Clone, Debug, PartialEq)]
pub struct SparseJLMatrix {
    rows: usize,
    cols: usize,
    sparsity: usize,
    seed: u64,
}

impl SparseJLMatrix {
    #[must_use]
    pub fn new(rows: usize, cols: usize, sparsity: usize, seed: u64) -> Self {
        assert!(rows > 0 && cols > 0 && sparsity > 0, "invalid sparse JL shape");
        Self { rows, cols, sparsity, seed }
    }

    /// Project a dense float vector into a clipped INT8 sketch.
    #[must_use]
    pub fn project(&self, vector: &[f32]) -> Vec<i8> {
        assert_eq!(vector.len(), self.cols, "JL input dimension mismatch");
        let mut out = vec![0.0_f32; self.rows];
        for (col, value) in vector.iter().enumerate() {
            for s in 0..self.sparsity {
                let h = mix64(self.seed ^ ((col as u64) << 32) ^ (s as u64));
                let row = (h as usize) % self.rows;
                let sign = if (h >> 63) == 0 { 1.0 } else { -1.0 };
                out[row] += sign * *value / (self.sparsity as f32).sqrt();
            }
        }
        out.into_iter().map(|v| v.round().clamp(-127.0, 127.0) as i8).collect()
    }
}

/// Free-random-projection-inspired basis: sign flip + permutation + FWHT.
#[derive(Clone, Debug, PartialEq)]
pub struct FRPBasis {
    dimension: usize,
    seed: u64,
}

impl FRPBasis {
    #[must_use]
    pub fn new(dimension: usize, seed: u64) -> Self {
        assert!(dimension.is_power_of_two(), "FRP dimension must be a power of two");
        Self { dimension, seed }
    }

    #[must_use]
    pub const fn dimension(&self) -> usize { self.dimension }

    /// Deterministic projection with randomized sign flips and cyclic permutation.
    #[must_use]
    pub fn free_random_project(&self, vector: &[f32], runtime_seed: u64) -> Vec<f32> {
        assert_eq!(vector.len(), self.dimension, "FRP dimension mismatch");
        let mut out = vec![0.0; self.dimension];
        let shift = (mix64(self.seed ^ runtime_seed) as usize) % self.dimension;
        for (i, dst) in out.iter_mut().enumerate() {
            let src = (i + shift) % self.dimension;
            let sign = if mix64(self.seed ^ runtime_seed ^ (i as u64)) & 1 == 0 { 1.0 } else { -1.0 };
            *dst = sign * vector[src];
        }
        fwht_inplace(&mut out);
        let norm = (self.dimension as f32).sqrt();
        for value in &mut out {
            *value /= norm;
        }
        out
    }
}

fn fwht_inplace(values: &mut [f32]) {
    let mut h = 1;
    while h < values.len() {
        for i in (0..values.len()).step_by(h * 2) {
            for j in i..(i + h) {
                let x = values[j];
                let y = values[j + h];
                values[j] = x + y;
                values[j + h] = x - y;
            }
        }
        h *= 2;
    }
}

fn median(values: &mut [f32]) -> f32 {
    values.sort_by(f32::total_cmp);
    values[values.len() / 2]
}

fn hash64(bytes: &[u8], seed: u64) -> u64 {
    let mut h = 0xcbf2_9ce4_8422_2325_u64 ^ seed;
    for b in bytes {
        h ^= u64::from(*b);
        h = h.wrapping_mul(0x1000_0000_01b3);
    }
    mix64(h)
}

fn mix64(mut x: u64) -> u64 {
    x ^= x >> 30;
    x = x.wrapping_mul(0xbf58_476d_1ce4_e5b9);
    x ^= x >> 27;
    x = x.wrapping_mul(0x94d0_49bb_1331_11eb);
    x ^ (x >> 31)
}

#[cfg(test)]
mod tests {
    use super::{CountSketch, FRPBasis, SparseJLMatrix};

    #[test]
    fn count_sketch_recovers_heavy_item() {
        let mut sketch = CountSketch::new(128, 5, 42);
        sketch.update(b"hot", 10.0);
        sketch.update(b"cold", 1.0);
        let keys: &[&[u8]] = &[b"hot", b"cold"];
        let top = sketch.top_k(keys, 1);
        assert_eq!(top[0].0, b"hot");
    }

    #[test]
    fn sparse_jl_has_requested_shape() {
        let jl = SparseJLMatrix::new(16, 8, 2, 1);
        assert_eq!(jl.project(&[1.0; 8]).len(), 16);
    }

    #[test]
    fn frp_preserves_l2_norm_approximately() {
        let frp = FRPBasis::new(8, 7);
        let input = [1.0, 2.0, 0.0, -1.0, 3.0, 0.5, -0.5, 2.0];
        let output = frp.free_random_project(&input, 9);
        let a: f32 = input.iter().map(|v| v * v).sum();
        let b: f32 = output.iter().map(|v| v * v).sum();
        assert!((a - b).abs() < 1.0e-4);
    }
}
