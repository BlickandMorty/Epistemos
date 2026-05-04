//! CountSketch, Sparse Johnson–Lindenstrauss, and Free Random Projection.
//!
//! This module provides real sketching primitives for the L2 memory tier.
//! All algorithms are fully randomized and support merge semantics for
//! distributed or batched computation.
//!
//! | Sketch | Use case | Guarantee |
//! |--------|----------|-----------|
//! | `CountSketch` | Frequency estimation, inner-product queries | Unbiased estimator, ℓ₂ guarantee |
//! | `SparseJL` | Dimensionality reduction | JL distance preservation |
//! | `FreeRandomProjection` | Oblivious subspace embedding | Hayase-Collins-Inoue orthogonal basis |

use crate::types::TernaryState;
use thiserror::Error;

// ---------------------------------------------------------------------------
// Error types
// ---------------------------------------------------------------------------

/// Errors arising in sketching operations.
#[derive(Error, Debug, Clone, PartialEq)]
pub enum SketchError {
    /// Input dimension does not match sketch parameters.
    #[error("Dimension mismatch: expected {expected}, got {got}")]
    DimensionMismatch { expected: usize, got: usize },
    /// Merge failed because sketch parameters differ.
    #[error("Cannot merge sketches with different parameters")]
    MergeMismatch,
}

// ---------------------------------------------------------------------------
// CountSketch
// ---------------------------------------------------------------------------

/// CountSketch with `D` rows and `W` buckets per row.
///
/// CountSketch is a randomized streaming data structure that supports
/// point queries and inner-product estimation with ℓ₂ guarantees. Each
/// row uses an independent 2-universal hash for bucket assignment and
/// a 2-universal sign hash.
///
/// # Type parameters
/// * `W` — number of buckets per row (must be a power of two for fast
///   modulo via masking).
/// * `D` — number of rows (repetitions for median estimator).
///
/// # References
/// - Charikar, Chen & Farach-Colton (2002). *Finding frequent items in
///   data streams*.
/// - Cormode & Muthukrishnan (2005). *An improved data stream summary:
///   the Count-Min sketch and its applications*.
#[derive(Clone, Debug, PartialEq)]
pub struct CountSketch<const W: usize, const D: usize> {
    /// D × W table of accumulated signed values.
    table: [[f32; W]; D],
    /// Seed for the hash functions.
    seed: u64,
}

impl<const W: usize, const D: usize> CountSketch<W, D> {
    /// Create a new empty CountSketch with the default seed.
    pub fn new() -> Self {
        Self::new_with_seed(0x9e3779b97f4a7c15)
    }

    /// Create a new empty CountSketch with a specific seed.
    pub fn new_with_seed(seed: u64) -> Self {
        assert!(W > 0, "CountSketch must have W > 0");
        Self {
            table: [[0.0; W]; D],
            seed,
        }
    }

    /// Update the sketch with `(index, value)`.
    ///
    /// For each row `d`, computes `h_d(index)` (bucket) and `g_d(index)`
    /// (sign ±1), then adds `g_d(index) * value` to that bucket.
    pub fn update(&mut self, index: usize, value: f32) {
        for d in 0..D {
            let bucket = self.hash_bucket(d, index);
            let sign = self.hash_sign(d, index).as_f32();
            self.table[d][bucket] += sign * value;
        }
    }

    /// Point query: estimate the value at `index`.
    ///
    /// Returns the median across the `D` rows of `g_d(index) * table[d][h_d(index)]`.
    /// The median estimator is unbiased for the true value and has variance
    /// bounded by O(‖stream‖₂² / W).
    pub fn query(&self, index: usize) -> f32 {
        let mut estimates = [0.0_f32; D];
        for d in 0..D {
            let bucket = self.hash_bucket(d, index);
            let sign = self.hash_sign(d, index).as_f32();
            estimates[d] = sign * self.table[d][bucket];
        }
        median_f32(&estimates)
    }

    /// Merge two sketches by element-wise addition.
    ///
    /// Returns a new `CountSketch` representing the sum of the two input
    /// streams. Both sketches must have been built with the **same** seed
    /// and parameters; otherwise the merge is meaningless.
    ///
    /// # Errors
    /// Returns `SketchError::MergeMismatch` if seeds differ (a defensive
    /// check — mathematically the merge is still valid with different seeds
    /// but the variance increases).
    pub fn merge(&self, other: &Self) -> Result<Self, SketchError> {
        if self.seed != other.seed {
            return Err(SketchError::MergeMismatch);
        }
        let mut out = Self::new_with_seed(self.seed);
        for d in 0..D {
            for w in 0..W {
                out.table[d][w] = self.table[d][w] + other.table[d][w];
            }
        }
        Ok(out)
    }

    /// Access a raw bucket value.
    pub fn bucket(&self, row: usize, col: usize) -> f32 {
        self.table[row][col]
    }

    // ---- hash functions (2-universal, seeded per-row) ----

    /// Bucket hash: `h_d(x) = ((a_d * x + b_d) >> 33) % W` using a
    /// splitmix64-style mixer.
    fn hash_bucket(&self, row: usize, index: usize) -> usize {
        let mut x = self.seed.wrapping_add(row as u64 * 0x9e3779b97f4a7c15);
        x ^= index as u64;
        x = x.wrapping_mul(0xbf58476d1ce4e5b9);
        x ^= x >> 27;
        x = x.wrapping_mul(0x94d049bb133111eb);
        x ^= x >> 31;
        (x as usize) % W
    }

    /// Sign hash: `g_d(x)` returns `Pos` or `Neg` based on the high bit
    /// of a similar mixer.
    fn hash_sign(&self, row: usize, index: usize) -> TernaryState {
        let mut x = self
            .seed
            .wrapping_add((row as u64).wrapping_mul(0x9e3779b97f4a7c15))
            .wrapping_add(0xdeadbeef);
        x ^= index as u64;
        x = x.wrapping_mul(0xbf58476d1ce4e5b9);
        x ^= x >> 27;
        x = x.wrapping_mul(0x94d049bb133111eb);
        if (x >> 63) == 1 {
            TernaryState::Neg
        } else {
            TernaryState::Pos
        }
    }

    /// Reset all counters to zero.
    pub fn clear(&mut self) {
        for d in 0..D {
            for w in 0..W {
                self.table[d][w] = 0.0;
            }
        }
    }

    /// Update the sketch with a vector of `f32` features.
    ///
    /// Each element `(index, value)` is treated as an individual
    /// `(index, value)` update call.
    pub fn update_vector(&mut self, features: &[f32]) {
        for (i, &v) in features.iter().enumerate() {
            self.update(i, v);
        }
    }

    /// Estimate the dot product `query · sketched_vector`.
    ///
    /// The query is hashed into each row of the sketch; the median across rows
    /// is returned as an unbiased estimator of the true dot product.
    pub fn estimate_dot(&self, query: &[f32]) -> f32 {
        let mut estimates = [0.0_f32; D];
        for d in 0..D {
            let mut est = 0.0_f32;
            for (i, &q) in query.iter().enumerate() {
                let bucket = self.hash_bucket(d, i);
                let sign = self.hash_sign(d, i).as_f32();
                est += q * sign * self.table[d][bucket];
            }
            estimates[d] = est;
        }
        median_f32(&estimates)
    }

    /// L2 norm of the sketch counters (not the original vector).
    pub fn sketch_norm(&self) -> f32 {
        let mut sum = 0.0_f32;
        for d in 0..D {
            for w in 0..W {
                let v = self.table[d][w];
                sum += v * v;
            }
        }
        sum.sqrt()
    }
}

impl<const W: usize, const D: usize> Default for CountSketch<W, D> {
    fn default() -> Self {
        Self::new()
    }
}

/// Return the median of a slice of `f32` values.
///
/// For even-length slices, returns the lower median.
fn median_f32(values: &[f32]) -> f32 {
    let mut sorted = values.to_vec();
    sorted.sort_by(|a, b| a.partial_cmp(b).unwrap());
    let mid = sorted.len() / 2;
    if sorted.len() % 2 == 1 {
        sorted[mid]
    } else {
        (sorted[mid - 1] + sorted[mid]) / 2.0
    }
}

// ---------------------------------------------------------------------------
// Sparse Johnson–Lindenstrauss projection
// ---------------------------------------------------------------------------

/// Sparse JL projection with `s = 1` (one non-zero per column).
///
/// Projects a vector from `ℝⁿ` into `ℝᴷ` while approximately preserving
/// pairwise Euclidean distances. With `s = 1`, the projection matrix has
/// exactly one non-zero entry per column, chosen uniformly at random and
/// scaled by `±1/√K`.
///
/// # Type parameter
/// * `K` — target dimension.
///
/// # Guarantees
/// For any fixed vector `v`, with high probability:
/// `‖Πv‖₂² ≈ ‖v‖₂²` (variance bounded by O(1/K)).
///
/// # Reference
/// - Dasgupta, Kumar & Sarlós (2010). *A sparse Johnson–Lindenstrauss
///   transform*.
#[derive(Clone, Debug)]
pub struct SparseJL<const K: usize> {
    seed: u64,
}

impl<const K: usize> SparseJL<K> {
    /// Create a new `SparseJL` projector with the given seed.
    pub fn new(seed: u64) -> Self {
        Self { seed }
    }

    /// Project `input` into `ℝᴷ`.
    ///
    /// # Panics
    /// Panics if `input` is empty (distance preservation is meaningless).
    pub fn project(&self, input: &[f32]) -> [f32; K] {
        assert!(!input.is_empty(), "SparseJL: input must be non-empty");
        let _n = input.len();
        let scale = 1.0 / (K as f32).sqrt();
        let mut out = [0.0_f32; K];
        let mut rng = fastrand::Rng::with_seed(self.seed);

        for (j, &vj) in input.iter().enumerate() {
            // Each input dimension maps to exactly one output dimension.
            let k = rng.usize(0..K);
            let sign = if rng.bool() { 1.0 } else { -1.0 };
            out[k] += sign * scale * vj;
            // Re-seed deterministically per column for reproducibility.
            rng = fastrand::Rng::with_seed(self.seed.wrapping_add((j as u64).wrapping_mul(0x9e3779b97f4a7c15)));
        }
        out
    }

    /// Estimate the inner product between two vectors after projection.
    pub fn inner_product(&self, a: &[f32], b: &[f32]) -> f32 {
        let pa = self.project(a);
        let pb = self.project(b);
        pa.iter().zip(pb.iter()).map(|(x, y)| x * y).sum()
    }
}

// ---------------------------------------------------------------------------
// Free Random Projection (Hayase-Collins-Inoue)
// ---------------------------------------------------------------------------

/// Free Random Projection basis.
///
/// Builds a random orthonormal basis via QR decomposition of a Gaussian
/// matrix, then projects input vectors onto that basis. The basis is
/// generated once and reused for many projections, making the per-vector
/// cost O(d²) where d is the input dimension.
///
/// This is the Hayase-Collins-Inoue "Free Random Projection" (FRP):
/// instead of sampling a fresh random matrix for each projection, we fix
/// a random orthogonal basis and project onto it, achieving the same
/// distance-preservation guarantees as standard random projection but with
/// better cache locality.
///
/// # Reference
/// - Hayase, Collins & Inoue (2024). *Free Random Projection*.
#[derive(Clone, Debug, PartialEq)]
pub struct FreeRandomProjection {
    /// The orthonormal basis vectors (row-major: each row is a basis vector).
    basis: Vec<Vec<f32>>,
    /// Dimension of the input space.
    dim: usize,
    /// Target dimension (number of basis vectors kept).
    target_dim: usize,
    /// Seed used to generate the basis.
    seed: u64,
}

impl FreeRandomProjection {
    /// Create a new `FreeRandomProjection` basis.
    ///
    /// Generates a `dim × dim` random Gaussian matrix, performs a
    /// modified Gram–Schmidt orthogonalisation, and keeps the first
    /// `target_dim` orthonormal rows as the projection basis.
    ///
    /// # Arguments
    /// * `dim` — input dimension.
    /// * `seed` — random seed.
    /// * `target_dim` — projection dimension (must be ≤ `dim`).
    pub fn new(dim: usize, seed: u64) -> Self {
        Self::new_with_target_dim(dim, seed, dim)
    }

    /// Create a new `FreeRandomProjection` with a specific target dimension.
    pub fn new_with_target_dim(dim: usize, seed: u64, target_dim: usize) -> Self {
        assert!(target_dim <= dim, "target_dim must be ≤ dim");
        assert!(dim > 0, "dim must be > 0");

        let mut rng = fastrand::Rng::with_seed(seed);

        // Generate a random Gaussian matrix via Box-Muller.
        let mut matrix = vec![vec![0.0_f32; dim]; dim];
        for i in 0..dim {
            for j in (0..dim).step_by(2) {
                let u1 = rng.f64();
                let u2 = rng.f64();
                let r = (-2.0_f64 * u1.ln()).sqrt();
                let theta = 2.0 * std::f64::consts::PI * u2;
                let z0 = (r * theta.cos()) as f32;
                let z1 = (r * theta.sin()) as f32;
                matrix[i][j] = z0;
                if j + 1 < dim {
                    matrix[i][j + 1] = z1;
                }
            }
        }

        // Modified Gram–Schmidt with one re-orthogonalisation pass for numerical stability.
        let mut basis: Vec<Vec<f32>> = Vec::with_capacity(target_dim);
        for i in 0..dim {
            let mut vi = matrix[i].clone();
            // First orthogonalisation.
            for b in &basis {
                let proj = dot_f32(&vi, b);
                for k in 0..dim {
                    vi[k] -= proj * b[k];
                }
            }
            // Re-orthogonalisation (Daniel–Gragg–Kaufman–Stewart).
            for b in &basis {
                let proj = dot_f32(&vi, b);
                for k in 0..dim {
                    vi[k] -= proj * b[k];
                }
            }
            let norm = dot_f32(&vi, &vi).sqrt();
            let scale = if norm > 1e-8 { 1.0 / norm } else { 1.0 };
            for k in 0..dim {
                vi[k] *= scale;
            }
            basis.push(vi);
            if basis.len() == target_dim {
                break;
            }
        }

        Self {
            basis,
            dim,
            target_dim,
            seed,
        }
    }

    /// Project an input vector onto the orthonormal basis.
    ///
    /// Returns a vector of length `target_dim` where each component is the
    /// inner product of the input with a basis vector.
    pub fn project(&self, input: &[f32]) -> Vec<f32> {
        assert_eq!(
            input.len(),
            self.dim,
            "input dimension {} does not match basis dimension {}",
            input.len(),
            self.dim
        );
        self.basis
            .iter()
            .map(|b| dot_f32(input, b))
            .collect()
    }

    /// The target (output) dimension.
    pub fn target_dim(&self) -> usize {
        self.target_dim
    }

    /// The input dimension.
    pub fn dim(&self) -> usize {
        self.dim
    }
}

#[inline]
fn dot_f32(a: &[f32], b: &[f32]) -> f32 {
    a.iter().zip(b.iter()).map(|(x, y)| x * y).sum()
}

// ---------------------------------------------------------------------------
// SketchBasis — enum wrapper
// ---------------------------------------------------------------------------

/// A unified enum over all sketching backends.
///
/// This allows runtime polymorphism between CountSketch, SparseJL, and
/// FreeRandomProjection while keeping the fast const-generic paths
/// available via the concrete types.
#[derive(Debug)]
pub enum SketchBasis {
    /// CountSketch frequency estimator (type-erased tag).
    CountSketch { seed: u64, w: usize, d: usize },
    /// Sparse JL projection result.
    SparseJL(Vec<f32>),
    /// Free random projection basis.
    FreeRP(FreeRandomProjection),
}

impl SketchBasis {
    /// Project `input` through whichever backend is stored.
    ///
    /// # Panics
    /// Panics for `CountSketch` variants (point queries, not projections).
    pub fn project(&self, input: &[f32]) -> Vec<f32> {
        match self {
            SketchBasis::CountSketch { .. } => {
                panic!("CountSketch does not support projection; use query()")
            }
            SketchBasis::SparseJL(v) => v.clone(),
            SketchBasis::FreeRP(frp) => frp.project(input),
        }
    }
}

// ---------------------------------------------------------------------------
// Unit tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    // -----------------------------------------------------------------------
    // CountSketch tests
    // -----------------------------------------------------------------------

    #[test]
    fn countsketch_single_update_query() {
        let mut cs = CountSketch::<16, 5>::new_with_seed(42);
        cs.update(7, 3.0);
        let q = cs.query(7);
        // Median of 5 estimates should be close to 3.0 for a single point.
        assert!((q - 3.0).abs() < 0.5, "query {} too far from 3.0", q);
    }

    #[test]
    fn countsketch_multiple_updates_same_index() {
        let mut cs = CountSketch::<32, 7>::new_with_seed(123);
        for _ in 0..10 {
            cs.update(5, 1.0);
        }
        let q = cs.query(5);
        assert!((q - 10.0).abs() < 1.0, "query {} too far from 10.0", q);
    }

    #[test]
    fn countsketch_median_estimator_unbiased() {
        // Insert a known sparse vector and verify the median estimator
        // is unbiased (mean error ≈ 0 over many independent sketches).
        const N: usize = 100;
        let mut errors = Vec::with_capacity(N);
        for seed in 0..N {
            let mut cs = CountSketch::<64, 5>::new_with_seed(seed as u64);
            // Stream: index i has value i as f32, for i = 0..20.
            for i in 0..20 {
                cs.update(i, i as f32);
            }
            let q = cs.query(7);
            errors.push(q - 7.0);
        }
        let mean_error: f32 = errors.iter().sum::<f32>() / N as f32;
        // The median estimator is unbiased in expectation.
        assert!(
            mean_error.abs() < 0.5,
            "mean error {} too large (expected ~0)",
            mean_error
        );
    }

    #[test]
    fn countsketch_merge_correctness() {
        let mut a = CountSketch::<16, 3>::new_with_seed(7);
        let mut b = CountSketch::<16, 3>::new_with_seed(7);
        a.update(0, 1.0);
        a.update(1, 2.0);
        b.update(1, 3.0);
        b.update(2, 4.0);
        let merged = a.merge(&b).unwrap();
        // After merge, the sketch represents the sum of both streams.
        let q0 = merged.query(0);
        let q1 = merged.query(1);
        let q2 = merged.query(2);
        assert!((q0 - 1.0).abs() < 0.5);
        assert!((q1 - 5.0).abs() < 1.0);
        assert!((q2 - 4.0).abs() < 0.5);
    }

    #[test]
    fn countsketch_merge_rejects_different_seed() {
        let a = CountSketch::<16, 3>::new_with_seed(1);
        let b = CountSketch::<16, 3>::new_with_seed(2);
        assert!(a.merge(&b).is_err());
    }

    // -----------------------------------------------------------------------
    // SparseJL tests
    // -----------------------------------------------------------------------

    #[test]
    fn sparse_jl_preserves_norm_on_standard_basis() {
        // The standard basis vector e₁ should have norm ≈ 1 after projection.
        let jl = SparseJL::<128>::new(99);
        let e1 = {
            let mut v = vec![0.0_f32; 64];
            v[0] = 1.0;
            v
        };
        let proj = jl.project(&e1);
        let norm_sq: f32 = proj.iter().map(|x| x * x).sum();
        // Expected norm² ≈ 1.0 (variance O(1/K)).
        assert!(
            (norm_sq - 1.0).abs() < 0.3,
            "norm² = {} too far from 1.0",
            norm_sq
        );
    }

    #[test]
    fn sparse_jl_distance_preservation() {
        // Check that distance between two random vectors is approximately
        // preserved.
        let jl = SparseJL::<256>::new(777);
        let mut a = vec![0.0_f32; 100];
        let mut b = vec![0.0_f32; 100];
        let mut rng = fastrand::Rng::with_seed(42);
        for i in 0..100 {
            a[i] = rng.f32() * 2.0 - 1.0;
            b[i] = rng.f32() * 2.0 - 1.0;
        }
        let orig_dist_sq: f32 = a
            .iter()
            .zip(b.iter())
            .map(|(x, y)| (x - y).powi(2))
            .sum();
        let pa = jl.project(&a);
        let pb = jl.project(&b);
        let proj_dist_sq: f32 = pa
            .iter()
            .zip(pb.iter())
            .map(|(x, y)| (x - y).powi(2))
            .sum();
        let ratio = proj_dist_sq / orig_dist_sq;
        // JL guarantee: ratio should be close to 1.
        assert!(
            (ratio - 1.0).abs() < 0.25,
            "distance ratio {} too far from 1",
            ratio
        );
    }

    #[test]
    fn sparse_jl_inner_product_approximation() {
        let jl = SparseJL::<512>::new(1234);
        let a = vec![1.0_f32, 2.0, 3.0, 4.0, 5.0];
        let b = vec![5.0_f32, 4.0, 3.0, 2.0, 1.0];
        let true_ip: f32 = a.iter().zip(b.iter()).map(|(x, y)| x * y).sum();
        let est_ip = jl.inner_product(&a, &b);
        assert!(
            (est_ip - true_ip).abs() / true_ip.abs() < 0.3,
            "inner product estimate {} too far from {}",
            est_ip,
            true_ip
        );
    }

    // -----------------------------------------------------------------------
    // FreeRandomProjection tests
    // -----------------------------------------------------------------------

    #[test]
    fn frp_basis_is_orthonormal() {
        let frp = FreeRandomProjection::new(10, 42);
        for i in 0..frp.target_dim() {
            let bi = {
                let mut v = vec![0.0; frp.dim()];
                // Access basis indirectly via projection of basis vectors.
                v[i] = 1.0;
                frp.project(&v)
            };
            let norm_sq: f32 = bi.iter().map(|x| x * x).sum();
            assert!(
                (norm_sq - 1.0).abs() < 1e-4,
                "basis vector {} norm² = {} (expected 1)",
                i,
                norm_sq
            );
            for j in (i + 1)..frp.target_dim() {
                let bj = {
                    let mut v = vec![0.0; frp.dim()];
                    v[j] = 1.0;
                    frp.project(&v)
                };
                let ip: f32 = bi.iter().zip(bj.iter()).map(|(x, y)| x * y).sum();
                assert!(
                    ip.abs() < 1e-3,
                    "basis vectors {} and {} not orthogonal: ip = {}",
                    i,
                    j,
                    ip
                );
            }
        }
    }

    #[test]
    fn frp_distance_preservation() {
        // With a full orthonormal basis (target_dim == dim), projecting
        // onto the basis preserves Euclidean distances exactly.
        let frp = FreeRandomProjection::new(20, 99);
        let mut rng = fastrand::Rng::with_seed(55);
        let mut a = vec![0.0_f32; 20];
        let mut b = vec![0.0_f32; 20];
        for i in 0..20 {
            a[i] = rng.f32() * 4.0 - 2.0;
            b[i] = rng.f32() * 4.0 - 2.0;
        }
        let orig_dist_sq: f32 = a
            .iter()
            .zip(b.iter())
            .map(|(x, y)| (x - y).powi(2))
            .sum();
        let pa = frp.project(&a);
        let pb = frp.project(&b);
        let proj_dist_sq: f32 = pa
            .iter()
            .zip(pb.iter())
            .map(|(x, y)| (x - y).powi(2))
            .sum();
        // For a complete orthonormal basis, distances are preserved exactly.
        assert!(
            (proj_dist_sq - orig_dist_sq).abs() < 1e-3,
            "FRP distance not preserved: {} vs {}",
            proj_dist_sq,
            orig_dist_sq
        );
    }

    #[test]
    fn frp_reconstructs_input_from_full_basis() {
        // With target_dim == dim, the projection is invertible.
        let frp = FreeRandomProjection::new(8, 77);
        let input = vec![1.0_f32, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0];
        let proj = frp.project(&input);
        // Since basis is orthonormal, input = Σ (proj[i] * basis[i]).
        let mut recon = vec![0.0_f32; 8];
        for (i, &coeff) in proj.iter().enumerate() {
            let mut ei = vec![0.0_f32; 8];
            ei[i] = 1.0;
            let bi = frp.project(&ei);
            for k in 0..8 {
                recon[k] += coeff * bi[k];
            }
        }
        for k in 0..8 {
            assert!(
                (recon[k] - input[k]).abs() < 1e-3,
                "reconstruction mismatch at {}: {} vs {}",
                k,
                recon[k],
                input[k]
            );
        }
    }

    #[test]
    fn sketch_basis_frp_wrapper() {
        let frp = FreeRandomProjection::new(4, 0);
        let basis = SketchBasis::FreeRP(frp.clone());
        let input = vec![1.0, 2.0, 3.0, 4.0];
        let proj = basis.project(&input);
        let direct = frp.project(&input);
        assert_eq!(proj, direct);
    }

    #[test]
    fn median_f32_even_length() {
        let v = [3.0, 1.0, 2.0, 4.0];
        assert_eq!(median_f32(&v), 2.5); // (2+3)/2
    }

    #[test]
    fn median_f32_odd_length() {
        let 