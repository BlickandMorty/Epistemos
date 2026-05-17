//! Source:
//! - Zhang/Naitzat/Lim arXiv:1805.07091 §2 — tropical-semiring
//!   semantics on the AST (max for ⊕, + for ⊗).
//! - Charisopoulos/Maragos arXiv:1805.08749 §3 — the tropical
//!   rational form's f64 evaluation.
//! - Doctrine §2.2 + §4.2 — Tropical-IR first lowering target.
//! - Companion: [`super::grammar`] (the AST this module evaluates);
//!   [`super::super::tropical`] (the substrate-floor module whose
//!   `tropical_add` / `tropical_mul` operators we delegate to for
//!   the binary operations).
//!
//! # Tropical (max, +) evaluator
//!
//! Given an [`super::grammar::TropicalExpr`] and a valuation vector
//! `valuation: &[f64]`, [`evaluate`] computes the tree's f64 value
//! using:
//!
//! - `Const(v)` → `v`.
//! - `Var(i)` → `valuation[i]` (out-of-range index → error).
//! - `Max([])` → `f64::NEG_INFINITY` (the tropical additive identity).
//! - `Max([a, …, z])` → `max(eval(a), …, eval(z))`.
//! - `Plus(a, b)` → `eval(a) + eval(b)` (standard real addition;
//!   tropical multiplication).
//!
//! Non-finite intermediates (e.g. NaN) propagate. The evaluator
//! rejects out-of-range `Var` indices but otherwise lets the
//! tropical semantics carry through.

use super::grammar::{TropicalExpr, TropicalRational};

/// Evaluation error for tropical-IR trees.
#[derive(Clone, Copy, Debug, PartialEq)]
pub enum TropicalEvalError {
    /// `Var(idx)` referenced an index that exceeds the valuation
    /// vector's length.
    VarOutOfRange { idx: usize, valuation_len: usize },
    /// A computed intermediate was NaN. The evaluator surfaces this
    /// rather than propagating silently — most consumers want
    /// determinism, not IEEE NaN drift.
    NonFiniteIntermediate { value: f64 },
}

/// Evaluate a tropical expression against a valuation vector.
///
/// Returns the f64 value or a [`TropicalEvalError`] on out-of-range
/// `Var` or NaN propagation. Infinities (positive and negative) are
/// permitted intermediates and outputs — tropical semantics use
/// `f64::NEG_INFINITY` as the additive identity, and overflow to
/// `f64::INFINITY` is a valid tropical-multiplication result.
pub fn evaluate(
    expr: &TropicalExpr,
    valuation: &[f64],
) -> Result<f64, TropicalEvalError> {
    let v = match expr {
        TropicalExpr::Const(c) => *c,
        TropicalExpr::Var(i) => {
            if *i >= valuation.len() {
                return Err(TropicalEvalError::VarOutOfRange {
                    idx: *i,
                    valuation_len: valuation.len(),
                });
            }
            valuation[*i]
        }
        TropicalExpr::Max(args) => {
            if args.is_empty() {
                return Ok(f64::NEG_INFINITY);
            }
            let mut best = f64::NEG_INFINITY;
            for a in args {
                let av = evaluate(a, valuation)?;
                if av > best {
                    best = av;
                }
            }
            best
        }
        TropicalExpr::Plus(l, r) => evaluate(l, valuation)? + evaluate(r, valuation)?,
        TropicalExpr::Scale(s, e) => s * evaluate(e, valuation)?,
    };
    if v.is_nan() {
        return Err(TropicalEvalError::NonFiniteIntermediate { value: v });
    }
    Ok(v)
}

/// Estimate the dominant tropical eigenvalue of a square (max, +)
/// matrix via power iteration:
///
/// `x_{k+1} = A ⊗ x_k` (tropical matrix-vector),
/// `λ ≈ avg_i (x_{k+1,i} − x_{k,i})` after sufficient iterations.
///
/// Equivalent to the maximum cycle mean of a weighted directed
/// graph with adjacency matrix `A`. Returns `None` for empty or
/// non-square matrices.
///
/// Iter-154 — Cuninghame-Green 1979 §3; foundational max-plus
/// linear-algebra spectral primitive.
pub fn tropical_eigenvalue_estimate(matrix: &[Vec<f64>], num_iters: usize) -> Option<f64> {
    if matrix.is_empty() {
        return None;
    }
    let n = matrix.len();
    if matrix[0].len() != n {
        return None;
    }

    let mut x = vec![0.0_f64; n];
    let mut prev = x.clone();
    for _ in 0..num_iters {
        prev = x.clone();
        x = tropical_matrix_vector(matrix, &x)?;
    }

    // λ ≈ average (x_t - x_{t-1}) at convergence.
    let diffs: Vec<f64> = x.iter().zip(prev.iter()).map(|(a, b)| a - b).collect();
    let avg: f64 = diffs.iter().sum::<f64>() / n as f64;
    Some(avg)
}

/// Tropical (max, +) additive identity: `-∞`.
///
/// In the (max, +) semiring, `x ⊕ tropical_zero() = max(x, -∞) = x`.
/// Returned as `f64::NEG_INFINITY`.
///
/// Iter-146 — semiring identity constants for tropical algebra.
pub fn tropical_zero() -> f64 {
    f64::NEG_INFINITY
}

/// Tropical (max, +) multiplicative identity: `0`.
///
/// In the (max, +) semiring, `x ⊗ tropical_one() = x + 0 = x`.
///
/// Iter-146 — semiring identity constants.
pub fn tropical_one() -> f64 {
    0.0
}

/// (min, +) additive identity: `+∞`. Companion of [`tropical_zero`].
///
/// Iter-146.
pub fn min_plus_zero() -> f64 {
    f64::INFINITY
}

/// Tropical argmax: index of the maximum element.
///
/// Returns `None` for empty input. First-occurrence wins ties.
///
/// Iter-160 — useful for selecting the dominant variable in
/// tropical computations (e.g. winning class in max-plus
/// classification).
pub fn tropical_argmax_idx(v: &[f64]) -> Option<usize> {
    if v.is_empty() {
        return None;
    }
    let mut idx = 0;
    let mut val = v[0];
    for (i, &x) in v.iter().enumerate().skip(1) {
        if x > val {
            val = x;
            idx = i;
        }
    }
    Some(idx)
}

/// (min, +) companion: index of the minimum element.
///
/// Iter-160 — shortest-path-selection primitive.
pub fn tropical_argmin_idx(v: &[f64]) -> Option<usize> {
    if v.is_empty() {
        return None;
    }
    let mut idx = 0;
    let mut val = v[0];
    for (i, &x) in v.iter().enumerate().skip(1) {
        if x < val {
            val = x;
            idx = i;
        }
    }
    Some(idx)
}

/// Tropical (max, +) "norm" of a vector: `max_i v_i`.
///
/// The (max, +) semiring's natural notion of magnitude. Returns
/// `f64::NEG_INFINITY` for empty input (tropical additive identity).
///
/// Iter-140 — companion of [`tropical_inner_product`] for
/// single-vector quantification.
pub fn tropical_norm_max(v: &[f64]) -> f64 {
    v.iter().copied().fold(f64::NEG_INFINITY, f64::max)
}

/// (min, +) companion: `min_i v_i`. Tropical magnitude for
/// shortest-path semiring.
///
/// Iter-140 — companion of [`tropical_norm_max`].
pub fn tropical_norm_min(v: &[f64]) -> f64 {
    v.iter().copied().fold(f64::INFINITY, f64::min)
}

/// (max, +) inner product of two equal-length vectors:
///
/// `⟨a, b⟩_tropical = max_i (a_i + b_i)`
///
/// where addition replaces ordinary multiplication and max replaces
/// the outer sum. Returns `f64::NEG_INFINITY` for empty inputs.
///
/// Iter-134 — Cuninghame-Green 1979 §1.3; building block for
/// max-plus algebra (longest-path through a complete bipartite
/// graph), and the inner-loop of tropical matrix-vector products.
pub fn tropical_inner_product(a: &[f64], b: &[f64]) -> f64 {
    if a.is_empty() || b.is_empty() || a.len() != b.len() {
        return f64::NEG_INFINITY;
    }
    a.iter()
        .zip(b.iter())
        .map(|(x, y)| x + y)
        .fold(f64::NEG_INFINITY, f64::max)
}

/// (min, +) inner product — companion of [`tropical_inner_product`]
/// for shortest-path semantics.
///
/// `⟨a, b⟩_min = min_i (a_i + b_i)`
///
/// Iter-134 — shortest-path single-step relaxation primitive.
pub fn min_plus_inner_product(a: &[f64], b: &[f64]) -> f64 {
    if a.is_empty() || b.is_empty() || a.len() != b.len() {
        return f64::INFINITY;
    }
    a.iter()
        .zip(b.iter())
        .map(|(x, y)| x + y)
        .fold(f64::INFINITY, f64::min)
}

/// Pairwise tropical "distance" matrix from a position vector:
///
/// `M_{i,j} = |pos_i − pos_j|` in standard distance; in tropical
/// algebra this is the additive cost of going from i to j on a
/// 1D number line (max-plus / min-plus interpretation depends on
/// semiring).
///
/// Returns symmetric matrix with zero diagonal.
///
/// Iter-179 — building block for tropical-graph path-cost matrices.
pub fn tropical_distance_matrix(positions: &[f64]) -> Vec<Vec<f64>> {
    let n = positions.len();
    let mut m = vec![vec![0.0; n]; n];
    for i in 0..n {
        for j in 0..n {
            m[i][j] = (positions[i] - positions[j]).abs();
        }
    }
    m
}

/// Construct a tropical diagonal matrix from a diagonal vector.
///
/// The result is an `n × n` matrix where `M_{i,i} = diagonal[i]`
/// and `M_{i,j} = -∞` for `i ≠ j` (tropical additive identity).
///
/// Iter-168 — building block for tropical linear algebra.
pub fn tropical_diagonal_matrix(diagonal: &[f64]) -> Vec<Vec<f64>> {
    let n = diagonal.len();
    let mut m = vec![vec![f64::NEG_INFINITY; n]; n];
    for (i, &d) in diagonal.iter().enumerate() {
        m[i][i] = d;
    }
    m
}

/// Tropical (max, +) identity matrix of size `n × n`.
///
/// `I_{i,i} = 0` (tropical multiplicative identity), `I_{i,j} = -∞`
/// elsewhere. Satisfies `I ⊗ x = x` for any vector `x`.
///
/// Iter-168.
pub fn tropical_identity_matrix(n: usize) -> Vec<Vec<f64>> {
    tropical_diagonal_matrix(&vec![0.0; n])
}

/// (max, +) outer product (or "outer sum") of two vectors:
///
/// `M_{i,j} = a_i + b_j`
///
/// This is the (max, +) analog of ordinary outer product
/// `M_{i,j} = a_i · b_j`, mapping ordinary multiplication to
/// tropical multiplication (= regular addition).
///
/// The result has shape `(a.len(), b.len())`. Empty inputs yield
/// an empty matrix.
///
/// Iter-125 — useful for tropical-rank-one decompositions and
/// composing edge-cost matrices in graph algorithms.
pub fn tropical_outer_sum(a: &[f64], b: &[f64]) -> Vec<Vec<f64>> {
    if a.is_empty() || b.is_empty() {
        return Vec::new();
    }
    let mut out = Vec::with_capacity(a.len());
    for &ai in a {
        let row: Vec<f64> = b.iter().map(|bj| ai + bj).collect();
        out.push(row);
    }
    out
}

/// (max, +) matrix multiplication:
///
/// `(A ⊗ B)_{i,j} = max_k (A_{i,k} + B_{k,j})`
///
/// `A` must be `m × n`; `B` must be `n × p`. Returns `m × p` matrix
/// or `None` on dimension mismatch / empty input.
///
/// Iter-172 — fundamental tropical linear algebra primitive
/// (Cuninghame-Green 1979 §2). Building block for matrix powers
/// (longest-path of length k), shortest-path APSP (min-plus
/// variant), and tropical Schur decomposition.
pub fn tropical_matrix_multiply(a: &[Vec<f64>], b: &[Vec<f64>]) -> Option<Vec<Vec<f64>>> {
    if a.is_empty() || b.is_empty() {
        return None;
    }
    let m = a.len();
    let n = a[0].len();
    if b.len() != n {
        return None;
    }
    let p = b[0].len();
    for row in a {
        if row.len() != n {
            return None;
        }
    }
    for row in b {
        if row.len() != p {
            return None;
        }
    }
    let mut out = vec![vec![f64::NEG_INFINITY; p]; m];
    for i in 0..m {
        for j in 0..p {
            let mut best = f64::NEG_INFINITY;
            for k in 0..n {
                let v = a[i][k] + b[k][j];
                if v > best {
                    best = v;
                }
            }
            out[i][j] = best;
        }
    }
    Some(out)
}

/// Min-plus additive fold over a vector: `⊕_min vᵢ = min_i vᵢ`.
///
/// Companion to `tropical_vector_max` (the dual fold in (max, +)).
/// Returns `INFINITY` (the (min, +) additive identity) on empty
/// input.
///
/// Iter-226 — used as the final-state projection in shortest-path
/// algorithms (the cost-to-go = min over candidate vertices).
pub fn min_plus_vector_min(v: &[f64]) -> f64 {
    let mut best = f64::INFINITY;
    for &x in v {
        if x < best {
            best = x;
        }
    }
    best
}

/// Tropical (max, +) additive fold over a vector:
/// `⊕_i vᵢ = max_i vᵢ`.
///
/// The semiring "sum" of a vector — the scalar that the
/// matrix-vector product `[1 1 … 1] ⊗ v` collapses to in
/// (max, +). Returns `NEG_INFINITY` (the additive identity) on
/// empty input.
///
/// Iter-220 — scalar-fold companion to `tropical_inner_product`
/// (which folds with a weight vector) and `tropical_matrix_vector`
/// (matrix on the left). Convenient as the "tropical sum" used
/// in tropical-DP value-function aggregates.
pub fn tropical_vector_max(v: &[f64]) -> f64 {
    let mut best = f64::NEG_INFINITY;
    for &x in v {
        if x > best {
            best = x;
        }
    }
    best
}

/// Min-plus entrywise addition: `(A ⊕ B)_{i,j} = min(A_{i,j}, B_{i,j})`.
///
/// The dual semiring "addition" for the (min, +) algebra. Same
/// shape-check semantics as `tropical_matrix_max_pointwise`.
///
/// Iter-214 — min-plus companion to iter-208's max-plus ⊕.
/// In the shortest-paths interpretation: combining two relaxation
/// candidate matrices by entrywise min.
pub fn min_plus_matrix_min_pointwise(
    a: &[Vec<f64>],
    b: &[Vec<f64>],
) -> Option<Vec<Vec<f64>>> {
    if a.len() != b.len() {
        return None;
    }
    let mut out = Vec::with_capacity(a.len());
    for (row_a, row_b) in a.iter().zip(b.iter()) {
        if row_a.len() != row_b.len() {
            return None;
        }
        out.push(
            row_a
                .iter()
                .zip(row_b.iter())
                .map(|(x, y)| if x <= y { *x } else { *y })
                .collect(),
        );
    }
    Some(out)
}

/// Tropical (max, +) entrywise addition: `(A ⊕ B)_{i,j} = max(A_{i,j}, B_{i,j})`.
///
/// The semiring "addition" lifted to matrices. Both inputs must
/// have identical shape; returns `None` on shape mismatch or
/// ragged input.
///
/// Iter-208 — semigroup-operation companion to
/// `tropical_matrix_multiply` (the semiring "multiplication");
/// together they make the matrix space `(Mₙ, ⊕, ⊗)` a semiring.
pub fn tropical_matrix_max_pointwise(
    a: &[Vec<f64>],
    b: &[Vec<f64>],
) -> Option<Vec<Vec<f64>>> {
    if a.len() != b.len() {
        return None;
    }
    let mut out = Vec::with_capacity(a.len());
    for (row_a, row_b) in a.iter().zip(b.iter()) {
        if row_a.len() != row_b.len() {
            return None;
        }
        out.push(
            row_a
                .iter()
                .zip(row_b.iter())
                .map(|(x, y)| if x >= y { *x } else { *y })
                .collect(),
        );
    }
    Some(out)
}

/// Tropical scalar add: `(A ⊕ c) = A_{i,j} + c` for every `i, j`.
///
/// In the (max, +) semiring this is the standard "scalar
/// multiplication" (tropical `⊗`-by-c): every entry shifts by `c`.
/// Empty input returns an empty matrix; non-rectangular input
/// (ragged rows) is propagated as-is (each row's length is
/// preserved).
///
/// Iter-202 — companion to `tropical_matrix_multiply`; together
/// they express the affine action `A ↦ B ⊕ (c · A)` that appears
/// in tropical-DP value-function updates and in projection-onto-
/// tropical-hyperplane algorithms.
pub fn tropical_matrix_scalar_add(a: &[Vec<f64>], c: f64) -> Vec<Vec<f64>> {
    a.iter()
        .map(|row| row.iter().map(|x| x + c).collect())
        .collect()
}

/// Extract the main diagonal of a square matrix.
///
/// Returns the vector `[A_{0,0}, A_{1,1}, …, A_{n-1, n-1}]`.
/// Returns `None` on non-square or ragged input; empty input
/// returns the empty vector.
///
/// Semiring-neutral (same for (max, +) and (min, +)); the
/// diagonal-extract primitive that `tropical_matrix_trace` folds
/// via `tropical_vector_max`.
///
/// Iter-232 — companion to `tropical_matrix_trace` (iter-196) and
/// `tropical_diagonal_matrix` (which constructs from a diagonal
/// vector); together they round-trip a `Vec<f64>` through the
/// matrix space.
pub fn tropical_matrix_diagonal(a: &[Vec<f64>]) -> Option<Vec<f64>> {
    if a.is_empty() {
        return Some(Vec::new());
    }
    let n = a.len();
    for row in a {
        if row.len() != n {
            return None;
        }
    }
    let mut out = Vec::with_capacity(n);
    for i in 0..n {
        out.push(a[i][i]);
    }
    Some(out)
}

/// Tropical (max-plus) trace `tr_⊕(A) = max_i A_{i,i}`.
///
/// Square matrix `A` over the (max, +) semiring. Equivalently:
/// the largest fixed-point loop weight (a 1-step cycle from i back
/// to i). Per Cuninghame-Green this is a lower bound on the
/// tropical eigenvalue (max-cycle-mean): `λ_max(A) ≥ tr_⊕(A) / 1`,
/// since a 1-cycle is itself a candidate cycle.
///
/// Returns `f64::NEG_INFINITY` for the empty matrix (the (max, +)
/// additive identity). Returns `None` on non-square or ragged input.
///
/// Iter-196 — companion to `tropical_eigenvalue_estimate` (the
/// k → ∞ generalization).
pub fn tropical_matrix_trace(a: &[Vec<f64>]) -> Option<f64> {
    if a.is_empty() {
        return Some(f64::NEG_INFINITY);
    }
    let n = a.len();
    for row in a {
        if row.len() != n {
            return None;
        }
    }
    let mut best = f64::NEG_INFINITY;
    for i in 0..n {
        if a[i][i] > best {
            best = a[i][i];
        }
    }
    Some(best)
}

/// Tropical k-th matrix power `A^k = A ⊗ A ⊗ … ⊗ A` (k copies).
///
/// `A` must be square (n × n). Returns `None` on non-square,
/// ragged, or empty input. `k = 0` returns the tropical identity
/// matrix.
///
/// In (max, +) semiring this gives the matrix of maximum-weight
/// k-step paths between vertex pairs — the heart of the
/// Floyd-Warshall-on-max algorithm and the Karp tropical
/// eigenvalue estimator (which we already implement via
/// [`tropical_eigenvalue_estimate`]).
///
/// Implementation: naive iterated multiplication. `O(k · n^3)`.
///
/// Iter-190 — semigroup-power primitive over the (max, +) semiring.
pub fn tropical_matrix_power(a: &[Vec<f64>], k: usize) -> Option<Vec<Vec<f64>>> {
    if a.is_empty() {
        return None;
    }
    let n = a.len();
    for row in a {
        if row.len() != n {
            return None;
        }
    }
    if k == 0 {
        return Some(tropical_identity_matrix(n));
    }
    let mut acc: Vec<Vec<f64>> = a.iter().map(|r| r.clone()).collect();
    for _ in 1..k {
        acc = tropical_matrix_multiply(&acc, a)?;
    }
    Some(acc)
}

/// Tropical matrix transpose — semiring-neutral (same for max,+ and min,+).
///
/// `(Aᵀ)_{j,i} = A_{i,j}`. Required to express `A · Aᵀ`-style tropical
/// outer products and to test symmetry of `Cuninghame-Green`-style
/// pair matrices.
///
/// Returns `None` on ragged input.
///
/// Iter-184 — companion to tropical_matrix_multiply (iter-172).
pub fn tropical_matrix_transpose(a: &[Vec<f64>]) -> Option<Vec<Vec<f64>>> {
    if a.is_empty() {
        return Some(Vec::new());
    }
    let m = a.len();
    let n = a[0].len();
    for row in a {
        if row.len() != n {
            return None;
        }
    }
    let mut out = vec![vec![0.0_f64; m]; n];
    for i in 0..m {
        for j in 0..n {
            out[j][i] = a[i][j];
        }
    }
    Some(out)
}

/// (min, +) matrix multiplication — shortest-path companion.
///
/// `(A ⊗_min B)_{i,j} = min_k (A_{i,k} + B_{k,j})`
///
/// Iter-172 — Bellman-Ford / Floyd-Warshall inner loop.
pub fn min_plus_matrix_multiply(a: &[Vec<f64>], b: &[Vec<f64>]) -> Option<Vec<Vec<f64>>> {
    if a.is_empty() || b.is_empty() {
        return None;
    }
    let m = a.len();
    let n = a[0].len();
    if b.len() != n {
        return None;
    }
    let p = b[0].len();
    for row in a {
        if row.len() != n {
            return None;
        }
    }
    for row in b {
        if row.len() != p {
            return None;
        }
    }
    let mut out = vec![vec![f64::INFINITY; p]; m];
    for i in 0..m {
        for j in 0..p {
            let mut best = f64::INFINITY;
            for k in 0..n {
                let v = a[i][k] + b[k][j];
                if v < best {
                    best = v;
                }
            }
            out[i][j] = best;
        }
    }
    Some(out)
}

/// (max, +) matrix-vector multiplication:
///
/// `(A ⊗ x)_i = max_j (A_{i,j} + x_j)`
///
/// Building block of tropical linear algebra. Maps to "longest
/// path of length ≤ 1" on a weighted DAG with adjacency matrix A.
///
/// Returns `None` if `A` is empty or has mismatched dimensions.
///
/// Iter-119 — Cuninghame-Green 1979 §2; foundation for max-plus
/// matrix powers, eigenvalue computation, and tropical SVD.
pub fn tropical_matrix_vector(matrix: &[Vec<f64>], x: &[f64]) -> Option<Vec<f64>> {
    if matrix.is_empty() {
        return None;
    }
    let cols = matrix[0].len();
    if cols != x.len() {
        return None;
    }
    let mut out = Vec::with_capacity(matrix.len());
    for row in matrix {
        if row.len() != cols {
            return None;
        }
        let mut best = f64::NEG_INFINITY;
        for (a, xj) in row.iter().zip(x.iter()) {
            let v = a + xj;
            if v > best {
                best = v;
            }
        }
        out.push(best);
    }
    Some(out)
}

/// (min, +) matrix-vector multiplication — companion of
/// [`tropical_matrix_vector`] for the shortest-path semiring.
///
/// `(A ⊗_min x)_i = min_j (A_{i,j} + x_j)`
///
/// Iter-119 — shortest-path / Bellman-Ford one-step relaxation
/// primitive.
pub fn min_plus_matrix_vector(matrix: &[Vec<f64>], x: &[f64]) -> Option<Vec<f64>> {
    if matrix.is_empty() {
        return None;
    }
    let cols = matrix[0].len();
    if cols != x.len() {
        return None;
    }
    let mut out = Vec::with_capacity(matrix.len());
    for row in matrix {
        if row.len() != cols {
            return None;
        }
        let mut best = f64::INFINITY;
        for (a, xj) in row.iter().zip(x.iter()) {
            let v = a + xj;
            if v < best {
                best = v;
            }
        }
        out.push(best);
    }
    Some(out)
}

/// Compile a tropical-polynomial coefficient vector into a
/// TropicalExpr tree.
///
/// Produces `Max([Plus(Const(a_k), Scale(k, Var(0)))])` for each
/// degree `k`. Variable slot 0 represents `x`.
///
/// Iter-113 — companion to [`tropical_polynomial`] that lifts the
/// numerical evaluation into an AST so it can pass through
/// optimizer passes, Lean certificate generators, or fusion
/// with other TropicalExpr trees.
pub fn compile_tropical_polynomial(coeffs: &[f64]) -> TropicalExpr {
    let terms: Vec<TropicalExpr> = coeffs
        .iter()
        .enumerate()
        .map(|(k, &a)| {
            let kx = TropicalExpr::scale(k as f64, TropicalExpr::var(0));
            TropicalExpr::plus(TropicalExpr::constant(a), kx)
        })
        .collect();
    TropicalExpr::max(terms)
}

/// Evaluate a tropical (max, +) polynomial:
///
/// `p(x) = max_k (a_k + k · x)` for coefficients `a = (a_0, a_1, …, a_n)`.
///
/// This is the (max, +) analog of ordinary polynomial evaluation
/// `Σ_k a_k · x^k`. The max-plus polynomial defines a piecewise-
/// linear convex function whose graph is the upper envelope of
/// affine lines `y = a_k + k·x`.
///
/// Special cases:
/// - Empty coefficients: returns `f64::NEG_INFINITY` (the tropical
///   additive identity).
/// - Single coefficient `[a]`: returns `a` (constant function).
///
/// Iter-108 — tropical polynomial primitive. Companion to
/// [`tropical_convolution`] (which IS tropical polynomial
/// multiplication).
pub fn tropical_polynomial(coeffs: &[f64], x: f64) -> f64 {
    coeffs
        .iter()
        .enumerate()
        .map(|(k, &a)| a + (k as f64) * x)
        .fold(f64::NEG_INFINITY, f64::max)
}

/// Discrete tropical (max, +) convolution of two sequences:
///
/// `(a ⊛ b)_k = max_{i+j=k} (a_i + b_j)`
///
/// where addition replaces ordinary multiplication (tropical
/// multiplication = real +), and `max` replaces ordinary summation
/// (tropical addition = max). The result has length `a.len() + b.len() - 1`.
///
/// Equivalent to:
/// - Longest-path computation on a DAG with edge weights.
/// - Viterbi recurrence inner loop (max-product → tropical max-sum
///   under log transform).
/// - Polynomial-product analogue in the tropical semiring.
///
/// Iter-103 — Cuninghame-Green tropical algebra primitive
/// (Cuninghame-Green 1979 "Minimax Algebra"). Inputs of length 0
/// yield an empty output.
pub fn tropical_convolution(a: &[f64], b: &[f64]) -> Vec<f64> {
    if a.is_empty() || b.is_empty() {
        return Vec::new();
    }
    let n = a.len() + b.len() - 1;
    let mut out = vec![f64::NEG_INFINITY; n];
    for (i, &ai) in a.iter().enumerate() {
        for (j, &bj) in b.iter().enumerate() {
            let v = ai + bj;
            if v > out[i + j] {
                out[i + j] = v;
            }
        }
    }
    out
}

/// Tropical (min, +) convolution — companion of [`tropical_convolution`]
/// for shortest-path / minimization semantics.
///
/// `(a ⊛_min b)_k = min_{i+j=k} (a_i + b_j)`
///
/// Iter-103 — anti-tropical analogue (min, +) of the standard
/// (max, +) operation.
pub fn min_plus_convolution(a: &[f64], b: &[f64]) -> Vec<f64> {
    if a.is_empty() || b.is_empty() {
        return Vec::new();
    }
    let n = a.len() + b.len() - 1;
    let mut out = vec![f64::INFINITY; n];
    for (i, &ai) in a.iter().enumerate() {
        for (j, &bj) in b.iter().enumerate() {
            let v = ai + bj;
            if v < out[i + j] {
                out[i + j] = v;
            }
        }
    }
    out
}

/// Evaluate a [`TropicalRational`] = `numerator ⊘ denominator`.
/// Tropical division is standard subtraction (because tropical
/// multiplication is `+`, the tropical inverse is `−`).
pub fn evaluate_rational(
    rational: &TropicalRational,
    valuation: &[f64],
) -> Result<f64, TropicalEvalError> {
    let n = evaluate(&rational.numerator, valuation)?;
    let d = evaluate(&rational.denominator, valuation)?;
    Ok(n - d)
}

#[cfg(test)]
mod tests {
    use super::*;

    // ── iter-154: tropical_eigenvalue_estimate ────────────────────

    #[test]
    fn tropical_eigenvalue_2x2_known() {
        // A = ((1, 2), (3, 4)). Tropical eigenvalue equals max
        // diagonal cycle mean. Self-loop 0→0 has mean 1, 1→1 has
        // mean 4. 2-cycle 0→1→0 has mean (2 + 3)/2 = 2.5.
        // Max cycle mean = 4.
        let a = vec![vec![1.0, 2.0], vec![3.0, 4.0]];
        let lambda = tropical_eigenvalue_estimate(&a, 50).unwrap();
        assert!((lambda - 4.0).abs() < 1e-6, "λ = {}", lambda);
    }

    #[test]
    fn tropical_eigenvalue_identity_matrix_is_zero() {
        // A = ((0, -∞), (-∞, 0)): tropical identity. Eigenvalue = 0.
        let a = vec![
            vec![0.0, f64::NEG_INFINITY],
            vec![f64::NEG_INFINITY, 0.0],
        ];
        let lambda = tropical_eigenvalue_estimate(&a, 30).unwrap();
        assert!(lambda.abs() < 1e-6, "λ = {}", lambda);
    }

    #[test]
    fn tropical_eigenvalue_rejects_non_square() {
        let a = vec![vec![1.0, 2.0, 3.0], vec![4.0, 5.0, 6.0]];
        assert!(tropical_eigenvalue_estimate(&a, 10).is_none());
    }

    #[test]
    fn tropical_eigenvalue_rejects_empty() {
        let a: Vec<Vec<f64>> = vec![];
        assert!(tropical_eigenvalue_estimate(&a, 10).is_none());
    }

    // ── iter-146: tropical_zero + tropical_one identities ─────────

    #[test]
    fn tropical_zero_is_neg_infinity() {
        assert_eq!(tropical_zero(), f64::NEG_INFINITY);
    }

    #[test]
    fn tropical_one_is_zero() {
        assert_eq!(tropical_one(), 0.0);
    }

    #[test]
    fn min_plus_zero_is_pos_infinity() {
        assert_eq!(min_plus_zero(), f64::INFINITY);
    }

    #[test]
    fn tropical_zero_is_max_identity() {
        // max(x, -inf) = x for any finite x.
        for x in [-100.0_f64, 0.0, 100.0] {
            assert_eq!(x.max(tropical_zero()), x);
        }
    }

    #[test]
    fn tropical_one_is_plus_identity() {
        // x + 0 = x.
        for x in [-100.0_f64, 0.0, 100.0] {
            assert_eq!(x + tropical_one(), x);
        }
    }

    // ── iter-160: tropical_argmax_idx + tropical_argmin_idx ───────

    #[test]
    fn tropical_argmax_idx_known() {
        assert_eq!(tropical_argmax_idx(&[1.0, 3.0, 2.0]), Some(1));
        assert_eq!(tropical_argmax_idx(&[-5.0, -1.0, -2.0]), Some(1));
        assert_eq!(tropical_argmax_idx(&[]), None);
    }

    #[test]
    fn tropical_argmax_idx_first_wins_ties() {
        assert_eq!(tropical_argmax_idx(&[5.0, 5.0, 5.0]), Some(0));
    }

    #[test]
    fn tropical_argmin_idx_known() {
        assert_eq!(tropical_argmin_idx(&[1.0, 3.0, 2.0]), Some(0));
        assert_eq!(tropical_argmin_idx(&[-5.0, -1.0, -2.0]), Some(0));
        assert_eq!(tropical_argmin_idx(&[]), None);
    }

    #[test]
    fn tropical_argmin_argmax_complement() {
        // argmax(v) ≠ argmin(v) when there's variation.
        let v = vec![1.0_f64, 5.0, 3.0, 0.0, 4.0];
        let amax = tropical_argmax_idx(&v).unwrap();
        let amin = tropical_argmin_idx(&v).unwrap();
        assert_ne!(amax, amin);
        assert_eq!(amax, 1); // 5 is largest
        assert_eq!(amin, 3); // 0 is smallest
    }

    // ── iter-140: tropical_norm_max + tropical_norm_min ───────────

    #[test]
    fn tropical_norm_max_picks_max() {
        assert_eq!(tropical_norm_max(&[1.0, 3.0, 2.0]), 3.0);
        assert_eq!(tropical_norm_max(&[-5.0, -1.0, -2.0]), -1.0);
        assert_eq!(tropical_norm_max(&[]), f64::NEG_INFINITY);
    }

    #[test]
    fn tropical_norm_min_picks_min() {
        assert_eq!(tropical_norm_min(&[1.0, 3.0, 2.0]), 1.0);
        assert_eq!(tropical_norm_min(&[-5.0, -1.0, -2.0]), -5.0);
        assert_eq!(tropical_norm_min(&[]), f64::INFINITY);
    }

    #[test]
    fn tropical_norm_duality() {
        let v = vec![1.0_f64, -2.0, 3.0, 0.5];
        let neg: Vec<f64> = v.iter().map(|x| -x).collect();
        assert_eq!(tropical_norm_max(&neg), -tropical_norm_min(&v));
    }

    // ── iter-134: tropical_inner_product + min_plus_inner_product ─

    #[test]
    fn tropical_inner_product_3d_known() {
        // a=(1, 2, 3), b=(4, 5, 6) → max(5, 7, 9) = 9.
        let v = tropical_inner_product(&[1.0, 2.0, 3.0], &[4.0, 5.0, 6.0]);
        assert_eq!(v, 9.0);
    }

    #[test]
    fn tropical_inner_product_empty_returns_neg_infinity() {
        assert_eq!(tropical_inner_product(&[], &[]), f64::NEG_INFINITY);
        assert_eq!(tropical_inner_product(&[1.0, 2.0], &[1.0]), f64::NEG_INFINITY);
    }

    #[test]
    fn tropical_inner_product_commutative() {
        let a = vec![1.5_f64, -0.5, 2.0];
        let b = vec![0.7_f64, 1.3, -1.0];
        let ab = tropical_inner_product(&a, &b);
        let ba = tropical_inner_product(&b, &a);
        assert_eq!(ab, ba);
    }

    #[test]
    fn min_plus_inner_product_3d_known() {
        // a=(1, 2, 3), b=(4, 5, 6) → min(5, 7, 9) = 5.
        let v = min_plus_inner_product(&[1.0, 2.0, 3.0], &[4.0, 5.0, 6.0]);
        assert_eq!(v, 5.0);
    }

    #[test]
    fn min_plus_max_plus_inner_duality() {
        let a = vec![1.0_f64, 2.0, 3.0];
        let b = vec![4.0_f64, 5.0, 6.0];
        let neg_a: Vec<f64> = a.iter().map(|x| -x).collect();
        let neg_b: Vec<f64> = b.iter().map(|x| -x).collect();
        let max_inner = tropical_inner_product(&neg_a, &neg_b);
        let min_inner = min_plus_inner_product(&a, &b);
        assert_eq!(max_inner, -min_inner);
    }

    // ── iter-179: tropical_distance_matrix ────────────────────────

    #[test]
    fn tropical_distance_matrix_zero_diagonal() {
        let m = tropical_distance_matrix(&[1.0, 2.0, 5.0]);
        for i in 0..3 {
            assert_eq!(m[i][i], 0.0);
        }
    }

    #[test]
    fn tropical_distance_matrix_symmetric() {
        let m = tropical_distance_matrix(&[1.0, 3.5, -2.0, 0.0]);
        for i in 0..4 {
            for j in 0..4 {
                assert_eq!(m[i][j], m[j][i]);
            }
        }
    }

    #[test]
    fn tropical_distance_matrix_known() {
        let m = tropical_distance_matrix(&[0.0, 1.0, 5.0]);
        assert_eq!(m[0][1], 1.0);
        assert_eq!(m[1][2], 4.0);
        assert_eq!(m[0][2], 5.0);
    }

    // ── iter-168: tropical_diagonal_matrix + identity ─────────────

    #[test]
    fn tropical_diagonal_matrix_known() {
        let m = tropical_diagonal_matrix(&[1.0, 2.0, 3.0]);
        assert_eq!(m.len(), 3);
        assert_eq!(m[0][0], 1.0);
        assert_eq!(m[1][1], 2.0);
        assert_eq!(m[2][2], 3.0);
        assert_eq!(m[0][1], f64::NEG_INFINITY);
        assert_eq!(m[1][2], f64::NEG_INFINITY);
    }

    #[test]
    fn tropical_identity_matrix_correct() {
        let m = tropical_identity_matrix(3);
        for i in 0..3 {
            for j in 0..3 {
                if i == j {
                    assert_eq!(m[i][j], 0.0);
                } else {
                    assert_eq!(m[i][j], f64::NEG_INFINITY);
                }
            }
        }
    }

    #[test]
    fn tropical_identity_matrix_preserves_vectors() {
        // I ⊗ x = x.
        let i = tropical_identity_matrix(3);
        let x = vec![5.0, -2.0, 7.0];
        let result = tropical_matrix_vector(&i, &x).unwrap();
        assert_eq!(result, x);
    }

    // ── iter-125: tropical_outer_sum ──────────────────────────────

    #[test]
    fn tropical_outer_sum_2x3_known() {
        // a = (1, 2), b = (10, 20, 30).
        // M_{0,j} = 1 + b_j = (11, 21, 31).
        // M_{1,j} = 2 + b_j = (12, 22, 32).
        let m = tropical_outer_sum(&[1.0, 2.0], &[10.0, 20.0, 30.0]);
        assert_eq!(m, vec![vec![11.0, 21.0, 31.0], vec![12.0, 22.0, 32.0]]);
    }

    #[test]
    fn tropical_outer_sum_empty_inputs_yields_empty() {
        assert!(tropical_outer_sum(&[], &[1.0, 2.0]).is_empty());
        assert!(tropical_outer_sum(&[1.0, 2.0], &[]).is_empty());
    }

    #[test]
    fn tropical_outer_sum_single_element() {
        // a = (5), b = (1, 2, 3) → M = ((6, 7, 8)).
        let m = tropical_outer_sum(&[5.0], &[1.0, 2.0, 3.0]);
        assert_eq!(m, vec![vec![6.0, 7.0, 8.0]]);
    }

    #[test]
    fn tropical_outer_sum_transpose_swaps_axes() {
        // outer(a, b)^T = outer(b, a).
        let a = vec![1.0_f64, 2.0, 3.0];
        let b = vec![4.0_f64, 5.0];
        let ab = tropical_outer_sum(&a, &b);
        let ba = tropical_outer_sum(&b, &a);
        for i in 0..a.len() {
            for j in 0..b.len() {
                assert_eq!(ab[i][j], ba[j][i]);
            }
        }
    }

    // ── iter-172: tropical_matrix_multiply + min_plus ─────────────

    #[test]
    fn tropical_matrix_multiply_identity_preserves() {
        // I ⊗ A = A.
        let id = tropical_identity_matrix(2);
        let a = vec![vec![1.0, 2.0], vec![3.0, 4.0]];
        let out = tropical_matrix_multiply(&id, &a).unwrap();
        assert_eq!(out, a);
    }

    #[test]
    fn tropical_matrix_multiply_2x2_known() {
        // A = ((1, 2), (3, 0)); B = ((1, 0), (2, 1)).
        // (A⊗B)_{0,0} = max(1+1, 2+2) = 4.
        // (A⊗B)_{0,1} = max(1+0, 2+1) = 3.
        // (A⊗B)_{1,0} = max(3+1, 0+2) = 4.
        // (A⊗B)_{1,1} = max(3+0, 0+1) = 3.
        let a = vec![vec![1.0, 2.0], vec![3.0, 0.0]];
        let b = vec![vec![1.0, 0.0], vec![2.0, 1.0]];
        let out = tropical_matrix_multiply(&a, &b).unwrap();
        assert_eq!(out, vec![vec![4.0, 3.0], vec![4.0, 3.0]]);
    }

    #[test]
    fn tropical_matrix_multiply_dim_mismatch_rejected() {
        let a = vec![vec![1.0, 2.0]];
        let b = vec![vec![3.0], vec![4.0], vec![5.0]]; // wrong dim
        assert!(tropical_matrix_multiply(&a, &b).is_none());
    }

    #[test]
    fn min_plus_matrix_multiply_2x2_known() {
        // Same matrices, min-plus.
        // (A⊗B)_{0,0} = min(1+1, 2+2) = 2.
        let a = vec![vec![1.0, 2.0], vec![3.0, 0.0]];
        let b = vec![vec![1.0, 0.0], vec![2.0, 1.0]];
        let out = min_plus_matrix_multiply(&a, &b).unwrap();
        assert_eq!(out, vec![vec![2.0, 1.0], vec![2.0, 1.0]]);
    }

    // ── iter-232: tropical_matrix_diagonal ────────────────────────

    #[test]
    fn matrix_diagonal_basic() {
        let a = vec![vec![1.0, 2.0], vec![3.0, 4.0]];
        assert_eq!(tropical_matrix_diagonal(&a).unwrap(), vec![1.0, 4.0]);
    }

    #[test]
    fn matrix_diagonal_3x3() {
        let a = vec![
            vec![1.0, 0.0, 0.0],
            vec![0.0, 2.0, 0.0],
            vec![0.0, 0.0, 3.0],
        ];
        assert_eq!(tropical_matrix_diagonal(&a).unwrap(), vec![1.0, 2.0, 3.0]);
    }

    #[test]
    fn matrix_diagonal_empty_is_empty() {
        let a: Vec<Vec<f64>> = vec![];
        assert!(tropical_matrix_diagonal(&a).unwrap().is_empty());
    }

    #[test]
    fn matrix_diagonal_non_square_rejected() {
        let a = vec![vec![1.0, 2.0, 3.0]];
        assert!(tropical_matrix_diagonal(&a).is_none());
    }

    #[test]
    fn matrix_diagonal_max_equals_trace() {
        // tropical_vector_max(diagonal(A)) = tropical_matrix_trace(A).
        let a = vec![vec![1.0, 5.0], vec![2.0, 3.0]];
        let diag = tropical_matrix_diagonal(&a).unwrap();
        let max_diag = tropical_vector_max(&diag);
        let tr = tropical_matrix_trace(&a).unwrap();
        assert!((max_diag - tr).abs() < 1e-12);
    }

    // ── iter-226: min_plus_vector_min ─────────────────────────────

    #[test]
    fn min_plus_vector_min_empty_is_infinity() {
        assert!(min_plus_vector_min(&[]).is_infinite());
        assert!(min_plus_vector_min(&[]) > 0.0);
    }

    #[test]
    fn min_plus_vector_min_basic() {
        assert_eq!(min_plus_vector_min(&[1.0, 5.0, 3.0, 2.0]), 1.0);
    }

    #[test]
    fn min_plus_vector_min_all_positive() {
        assert_eq!(min_plus_vector_min(&[3.0, 1.0, 7.0]), 1.0);
    }

    #[test]
    fn min_plus_vector_min_dual_of_max_negated() {
        // min(v) = -max(-v) (entrywise negation duality).
        let v = vec![1.0_f64, 5.0, 3.0, 2.0];
        let neg: Vec<f64> = v.iter().map(|x| -x).collect();
        let mn = min_plus_vector_min(&v);
        let mx = tropical_vector_max(&neg);
        assert!((mn + mx).abs() < 1e-12);
    }

    // ── iter-220: tropical_vector_max ─────────────────────────────

    #[test]
    fn tropical_vector_max_empty_is_neg_infinity() {
        assert!(tropical_vector_max(&[]).is_infinite());
        assert!(tropical_vector_max(&[]) < 0.0);
    }

    #[test]
    fn tropical_vector_max_basic() {
        assert_eq!(tropical_vector_max(&[1.0, 5.0, 3.0, 2.0]), 5.0);
    }

    #[test]
    fn tropical_vector_max_all_negative() {
        assert_eq!(tropical_vector_max(&[-3.0, -1.0, -7.0]), -1.0);
    }

    #[test]
    fn tropical_vector_max_singleton_is_self() {
        assert_eq!(tropical_vector_max(&[42.0]), 42.0);
    }

    // ── iter-214: min_plus_matrix_min_pointwise ───────────────────

    #[test]
    fn min_plus_pointwise_basic() {
        let a = vec![vec![1.0, 5.0], vec![3.0, 2.0]];
        let b = vec![vec![4.0, 2.0], vec![3.0, 6.0]];
        let c = min_plus_matrix_min_pointwise(&a, &b).unwrap();
        assert_eq!(c, vec![vec![1.0, 2.0], vec![3.0, 2.0]]);
    }

    #[test]
    fn min_plus_pointwise_idempotent() {
        let a = vec![vec![1.0, 5.0], vec![3.0, 2.0]];
        let c = min_plus_matrix_min_pointwise(&a, &a).unwrap();
        assert_eq!(c, a);
    }

    #[test]
    fn min_plus_pointwise_dual_of_max_pointwise() {
        // min(a, b) + max(a, b) = a + b — entrywise.
        let a = vec![vec![1.0, 5.0], vec![3.0, 2.0]];
        let b = vec![vec![4.0, 2.0], vec![3.0, 6.0]];
        let mn = min_plus_matrix_min_pointwise(&a, &b).unwrap();
        let mx = tropical_matrix_max_pointwise(&a, &b).unwrap();
        for i in 0..2 {
            for j in 0..2 {
                let sum = mn[i][j] + mx[i][j];
                let expected = a[i][j] + b[i][j];
                assert!((sum - expected).abs() < 1e-12);
            }
        }
    }

    #[test]
    fn min_plus_pointwise_shape_mismatch_rejected() {
        let a = vec![vec![1.0, 2.0]];
        let b = vec![vec![1.0]];
        assert!(min_plus_matrix_min_pointwise(&a, &b).is_none());
    }

    // ── iter-208: tropical_matrix_max_pointwise ───────────────────

    #[test]
    fn tropical_max_pointwise_basic() {
        let a = vec![vec![1.0, 5.0], vec![3.0, 2.0]];
        let b = vec![vec![4.0, 2.0], vec![3.0, 6.0]];
        let c = tropical_matrix_max_pointwise(&a, &b).unwrap();
        assert_eq!(c, vec![vec![4.0, 5.0], vec![3.0, 6.0]]);
    }

    #[test]
    fn tropical_max_pointwise_idempotent() {
        // A ⊕ A = A in any idempotent semiring.
        let a = vec![vec![1.0, 5.0], vec![3.0, 2.0]];
        let c = tropical_matrix_max_pointwise(&a, &a).unwrap();
        assert_eq!(c, a);
    }

    #[test]
    fn tropical_max_pointwise_commutative() {
        let a = vec![vec![1.0, 5.0]];
        let b = vec![vec![4.0, 2.0]];
        let ab = tropical_matrix_max_pointwise(&a, &b).unwrap();
        let ba = tropical_matrix_max_pointwise(&b, &a).unwrap();
        assert_eq!(ab, ba);
    }

    #[test]
    fn tropical_max_pointwise_shape_mismatch_rejected() {
        let a = vec![vec![1.0, 2.0]];
        let b = vec![vec![1.0]];
        assert!(tropical_matrix_max_pointwise(&a, &b).is_none());
    }

    // ── iter-202: tropical_matrix_scalar_add ──────────────────────

    #[test]
    fn tropical_matrix_scalar_add_zero_is_identity() {
        let a = vec![vec![1.0, 2.0], vec![3.0, 4.0]];
        let b = tropical_matrix_scalar_add(&a, 0.0);
        assert_eq!(b, a);
    }

    #[test]
    fn tropical_matrix_scalar_add_known() {
        let a = vec![vec![1.0, 2.0], vec![3.0, 4.0]];
        let b = tropical_matrix_scalar_add(&a, 5.0);
        assert_eq!(b, vec![vec![6.0, 7.0], vec![8.0, 9.0]]);
    }

    #[test]
    fn tropical_matrix_scalar_add_distributes_over_multiply() {
        // (c · A) ⊗ B = c · (A ⊗ B) under (max, +).
        let a = vec![vec![1.0, 2.0], vec![3.0, 0.0]];
        let b = vec![vec![1.0, 0.0], vec![2.0, 1.0]];
        let c = 5.0;
        let lhs = tropical_matrix_multiply(&tropical_matrix_scalar_add(&a, c), &b).unwrap();
        let rhs = tropical_matrix_scalar_add(&tropical_matrix_multiply(&a, &b).unwrap(), c);
        assert_eq!(lhs, rhs);
    }

    #[test]
    fn tropical_matrix_scalar_add_empty_is_empty() {
        let a: Vec<Vec<f64>> = vec![];
        assert!(tropical_matrix_scalar_add(&a, 5.0).is_empty());
    }

    // ── iter-196: tropical_matrix_trace ───────────────────────────

    #[test]
    fn tropical_matrix_trace_basic() {
        let a = vec![vec![1.0, 2.0], vec![3.0, 4.0]];
        assert_eq!(tropical_matrix_trace(&a).unwrap(), 4.0);
    }

    #[test]
    fn tropical_matrix_trace_negative_diagonal() {
        let a = vec![vec![-1.0, 5.0], vec![5.0, -2.0]];
        assert_eq!(tropical_matrix_trace(&a).unwrap(), -1.0);
    }

    #[test]
    fn tropical_matrix_trace_lower_bounds_eigenvalue() {
        // For any A, λ_max(A) ≥ tr_⊕(A).
        let a = vec![vec![1.0, 0.0], vec![0.0, 3.0]];
        let lam = tropical_eigenvalue_estimate(&a, 20).unwrap();
        let tr = tropical_matrix_trace(&a).unwrap();
        assert!(lam >= tr - 1e-9, "λ={} < tr={}", lam, tr);
    }

    #[test]
    fn tropical_matrix_trace_empty_is_neg_infinity() {
        let a: Vec<Vec<f64>> = vec![];
        assert!(tropical_matrix_trace(&a).unwrap().is_infinite());
        assert!(tropical_matrix_trace(&a).unwrap() < 0.0);
    }

    #[test]
    fn tropical_matrix_trace_non_square_rejected() {
        let a = vec![vec![1.0, 2.0, 3.0]];
        assert!(tropical_matrix_trace(&a).is_none());
    }

    // ── iter-190: tropical_matrix_power ───────────────────────────

    #[test]
    fn tropical_matrix_power_zero_is_identity() {
        let a = vec![vec![1.0, 2.0], vec![3.0, 4.0]];
        let p0 = tropical_matrix_power(&a, 0).unwrap();
        assert_eq!(p0, tropical_identity_matrix(2));
    }

    #[test]
    fn tropical_matrix_power_one_is_self() {
        let a = vec![vec![1.0, 2.0], vec![3.0, 4.0]];
        let p1 = tropical_matrix_power(&a, 1).unwrap();
        assert_eq!(p1, a);
    }

    #[test]
    fn tropical_matrix_power_two_matches_multiply() {
        let a = vec![vec![1.0, 2.0], vec![3.0, 0.0]];
        let p2 = tropical_matrix_power(&a, 2).unwrap();
        let aa = tropical_matrix_multiply(&a, &a).unwrap();
        assert_eq!(p2, aa);
    }

    #[test]
    fn tropical_matrix_power_three_associative() {
        // A^3 = A^2 ⊗ A = A ⊗ A^2.
        let a = vec![vec![0.0, 1.0], vec![2.0, 0.0]];
        let p3 = tropical_matrix_power(&a, 3).unwrap();
        let a2 = tropical_matrix_multiply(&a, &a).unwrap();
        let p3_left = tropical_matrix_multiply(&a2, &a).unwrap();
        let p3_right = tropical_matrix_multiply(&a, &a2).unwrap();
        assert_eq!(p3, p3_left);
        assert_eq!(p3, p3_right);
    }

    #[test]
    fn tropical_matrix_power_non_square_rejected() {
        let a = vec![vec![1.0, 2.0, 3.0], vec![4.0, 5.0, 6.0]];
        assert!(tropical_matrix_power(&a, 2).is_none());
    }

    // ── iter-184: tropical_matrix_transpose ───────────────────────

    #[test]
    fn tropical_matrix_transpose_2x3_known() {
        let a = vec![vec![1.0, 2.0, 3.0], vec![4.0, 5.0, 6.0]];
        let at = tropical_matrix_transpose(&a).unwrap();
        assert_eq!(at, vec![vec![1.0, 4.0], vec![2.0, 5.0], vec![3.0, 6.0]]);
    }

    #[test]
    fn tropical_matrix_transpose_involution() {
        // (Aᵀ)ᵀ = A.
        let a = vec![vec![1.0, 2.0], vec![3.0, 4.0], vec![5.0, 6.0]];
        let att = tropical_matrix_transpose(
            &tropical_matrix_transpose(&a).unwrap(),
        )
        .unwrap();
        assert_eq!(att, a);
    }

    #[test]
    fn tropical_matrix_transpose_empty_is_empty() {
        let a: Vec<Vec<f64>> = vec![];
        assert_eq!(tropical_matrix_transpose(&a).unwrap(), Vec::<Vec<f64>>::new());
    }

    #[test]
    fn tropical_matrix_transpose_ragged_rejected() {
        let a = vec![vec![1.0, 2.0], vec![3.0]];
        assert!(tropical_matrix_transpose(&a).is_none());
    }

    // ── iter-119: tropical_matrix_vector + min_plus_matrix_vector ─

    #[test]
    fn tropical_matrix_vector_identity_like() {
        // A = ((0, -∞), (-∞, 0)) — tropical identity.
        let a = vec![
            vec![0.0, f64::NEG_INFINITY],
            vec![f64::NEG_INFINITY, 0.0],
        ];
        let x = vec![5.0, 7.0];
        let out = tropical_matrix_vector(&a, &x).unwrap();
        assert_eq!(out, vec![5.0, 7.0]);
    }

    #[test]
    fn tropical_matrix_vector_2x2_known() {
        // A = ((1, 2), (3, 0)); x = (1, 4).
        // out_0 = max(1+1, 2+4) = max(2, 6) = 6
        // out_1 = max(3+1, 0+4) = max(4, 4) = 4
        let a = vec![vec![1.0, 2.0], vec![3.0, 0.0]];
        let x = vec![1.0, 4.0];
        let out = tropical_matrix_vector(&a, &x).unwrap();
        assert_eq!(out, vec![6.0, 4.0]);
    }

    #[test]
    fn tropical_matrix_vector_rejects_dim_mismatch() {
        let a = vec![vec![1.0, 2.0]];
        let x = vec![1.0, 2.0, 3.0];
        assert!(tropical_matrix_vector(&a, &x).is_none());
    }

    #[test]
    fn tropical_matrix_vector_empty_matrix_returns_none() {
        let a: Vec<Vec<f64>> = vec![];
        let x = vec![1.0, 2.0];
        assert!(tropical_matrix_vector(&a, &x).is_none());
    }

    #[test]
    fn min_plus_matrix_vector_2x2_known() {
        // A = ((1, 2), (3, 0)); x = (1, 4).
        // out_0 = min(1+1, 2+4) = min(2, 6) = 2
        // out_1 = min(3+1, 0+4) = min(4, 4) = 4
        let a = vec![vec![1.0, 2.0], vec![3.0, 0.0]];
        let x = vec![1.0, 4.0];
        let out = min_plus_matrix_vector(&a, &x).unwrap();
        assert_eq!(out, vec![2.0, 4.0]);
    }

    #[test]
    fn min_plus_max_plus_duality() {
        // min_plus(A, x) = -max_plus(-A, -x).
        let a = vec![vec![1.0_f64, 2.0], vec![3.0, 0.0]];
        let x = vec![1.0_f64, 4.0];

        let min_out = min_plus_matrix_vector(&a, &x).unwrap();

        let neg_a: Vec<Vec<f64>> = a.iter().map(|r| r.iter().map(|v| -v).collect()).collect();
        let neg_x: Vec<f64> = x.iter().map(|v| -v).collect();
        let max_out = tropical_matrix_vector(&neg_a, &neg_x).unwrap();

        for (m, n) in min_out.iter().zip(max_out.iter()) {
            assert!((m + n).abs() < 1e-12, "duality fails: min={} max={}", m, n);
        }
    }

    // ── iter-113: compile_tropical_polynomial ─────────────────────

    #[test]
    fn compile_tropical_polynomial_constant_matches_direct() {
        let tree = compile_tropical_polynomial(&[3.5]);
        let v = evaluate(&tree, &[100.0]).unwrap();
        let direct = tropical_polynomial(&[3.5], 100.0);
        assert_eq!(v, direct);
        assert_eq!(v, 3.5);
    }

    #[test]
    fn compile_tropical_polynomial_linear_matches_direct() {
        // p(x) = max(a_0, a_1 + x).
        let coeffs = [5.0_f64, 0.0];
        let tree = compile_tropical_polynomial(&coeffs);
        for x in [-3.0_f64, 3.0, 5.0, 10.0] {
            let tree_v = evaluate(&tree, &[x]).unwrap();
            let direct_v = tropical_polynomial(&coeffs, x);
            assert_eq!(tree_v, direct_v);
        }
    }

    #[test]
    fn compile_tropical_polynomial_cubic_matches_direct() {
        // p(x) = max(1, 2 + x, 0 + 2x, -1 + 3x).
        let coeffs = [1.0_f64, 2.0, 0.0, -1.0];
        let tree = compile_tropical_polynomial(&coeffs);
        for x in [-2.0_f64, 0.0, 1.0, 5.0] {
            let tree_v = evaluate(&tree, &[x]).unwrap();
            let direct_v = tropical_polynomial(&coeffs, x);
            assert_eq!(tree_v, direct_v);
        }
    }

    #[test]
    fn compile_tropical_polynomial_has_correct_max_var_index() {
        let tree = compile_tropical_polynomial(&[1.0, 2.0, 3.0]);
        assert_eq!(tree.max_var_index(), Some(0));
    }

    // ── iter-108: tropical_polynomial ─────────────────────────────

    #[test]
    fn tropical_polynomial_empty_coeffs_is_neg_infinity() {
        assert_eq!(tropical_polynomial(&[], 1.0), f64::NEG_INFINITY);
    }

    #[test]
    fn tropical_polynomial_constant_returns_constant() {
        assert_eq!(tropical_polynomial(&[3.5], 100.0), 3.5);
        assert_eq!(tropical_polynomial(&[-2.0], -100.0), -2.0);
    }

    #[test]
    fn tropical_polynomial_linear_two_coeffs() {
        // p(x) = max(a_0, a_1 + x).
        // a = (5, 0): max(5, x) — switches at x = 5.
        assert_eq!(tropical_polynomial(&[5.0, 0.0], 3.0), 5.0); // x < 5
        assert_eq!(tropical_polynomial(&[5.0, 0.0], 5.0), 5.0); // x = 5
        assert_eq!(tropical_polynomial(&[5.0, 0.0], 10.0), 10.0); // x > 5
    }

    #[test]
    fn tropical_polynomial_quadratic_three_coeffs() {
        // p(x) = max(0, 1 + x, 0 + 2x).
        // At x = -5: max(0, -4, -10) = 0.
        // At x = 0:  max(0, 1, 0) = 1.
        // At x = 5:  max(0, 6, 10) = 10.
        let coeffs = [0.0, 1.0, 0.0];
        assert_eq!(tropical_polynomial(&coeffs, -5.0), 0.0);
        assert_eq!(tropical_polynomial(&coeffs, 0.0), 1.0);
        assert_eq!(tropical_polynomial(&coeffs, 5.0), 10.0);
    }

    #[test]
    fn tropical_polynomial_is_convex_via_3_point_check() {
        // Tropical polynomials are convex piecewise-linear functions.
        // Verify: p((x+y)/2) ≤ (p(x) + p(y)) / 2 — but tropical
        // max IS convex by definition. Check at random points.
        let coeffs = [0.0, 0.5, -1.0, 2.0];
        let x = 1.0_f64;
        let y = 5.0;
        let mid = (x + y) / 2.0;
        let p_x = tropical_polynomial(&coeffs, x);
        let p_y = tropical_polynomial(&coeffs, y);
        let p_mid = tropical_polynomial(&coeffs, mid);
        // Convexity: p(mid) ≤ (p_x + p_y) / 2.
        assert!(
            p_mid <= (p_x + p_y) / 2.0 + 1e-12,
            "convexity fails: p({}) = {}, average = {}",
            mid, p_mid, (p_x + p_y) / 2.0
        );
    }

    #[test]
    fn tropical_polynomial_dominant_coefficient_wins_at_extreme_x() {
        // As x → +∞, the term a_n + n·x dominates (highest degree).
        // a = (10, 0, 0, 1) at x = 100: max(10, 100, 200, 301) = 301.
        let v = tropical_polynomial(&[10.0, 0.0, 0.0, 1.0], 100.0);
        assert_eq!(v, 301.0);
    }

    #[test]
    fn tropical_polynomial_negative_x_favors_low_degree() {
        // a = (5, 0, 0) at x = -100: max(5, -100, -200) = 5.
        let v = tropical_polynomial(&[5.0, 0.0, 0.0], -100.0);
        assert_eq!(v, 5.0);
    }

    // ── iter-103: tropical_convolution + min_plus_convolution ─────

    #[test]
    fn tropical_convolution_single_element_left() {
        // a = [3], b = [1, 2, 4] → output_k = 3 + b_k.
        let out = tropical_convolution(&[3.0], &[1.0, 2.0, 4.0]);
        assert_eq!(out, vec![4.0, 5.0, 7.0]);
    }

    #[test]
    fn tropical_convolution_2x2_known() {
        // a = [1, 2], b = [3, 4].
        // (a ⊛ b)_0 = max(1+3) = 4
        // (a ⊛ b)_1 = max(1+4, 2+3) = 5
        // (a ⊛ b)_2 = max(2+4) = 6
        let out = tropical_convolution(&[1.0, 2.0], &[3.0, 4.0]);
        assert_eq!(out, vec![4.0, 5.0, 6.0]);
    }

    #[test]
    fn tropical_convolution_zero_padding_concept() {
        // a = [0, 0, 0], b = [1, 2, 3]. Each output is max of
        // 0+b_k where i+j=k. Since 0+b_k = b_k for any i:
        // out_0 = max(b_0) = 1
        // out_1 = max(b_0, b_1) = 2
        // out_2 = max(b_0, b_1, b_2) = 3
        // out_3 = max(b_1, b_2) = 3
        // out_4 = max(b_2) = 3
        let out = tropical_convolution(&[0.0, 0.0, 0.0], &[1.0, 2.0, 3.0]);
        assert_eq!(out, vec![1.0, 2.0, 3.0, 3.0, 3.0]);
    }

    #[test]
    fn tropical_convolution_commutative() {
        let a = vec![1.5_f64, -0.5, 2.0];
        let b = vec![0.7_f64, 1.3];
        let ab = tropical_convolution(&a, &b);
        let ba = tropical_convolution(&b, &a);
        assert_eq!(ab, ba);
    }

    #[test]
    fn tropical_convolution_empty_input_yields_empty_output() {
        assert!(tropical_convolution(&[], &[1.0, 2.0]).is_empty());
        assert!(tropical_convolution(&[1.0, 2.0], &[]).is_empty());
    }

    #[test]
    fn min_plus_convolution_2x2_known() {
        // a = [1, 2], b = [3, 4].
        // (a ⊛_min b)_0 = min(1+3) = 4
        // (a ⊛_min b)_1 = min(1+4, 2+3) = 5
        // (a ⊛_min b)_2 = min(2+4) = 6
        let out = min_plus_convolution(&[1.0, 2.0], &[3.0, 4.0]);
        assert_eq!(out, vec![4.0, 5.0, 6.0]);
    }

    #[test]
    fn min_plus_convolution_picks_smaller_path() {
        // a = [0, 5], b = [0, 3].
        // (a ⊛_min b)_1 = min(0+3, 5+0) = 3.
        let out = min_plus_convolution(&[0.0, 5.0], &[0.0, 3.0]);
        assert_eq!(out, vec![0.0, 3.0, 8.0]);
    }

    #[test]
    fn tropical_min_plus_negation_duality() {
        // min(a) = -max(-a). Verify on convolution:
        //   min_plus_conv(a, b) = -max_plus_conv(-a, -b)? NO — the
        //   duality is on the result not the operation. Let's check
        //   that max_plus_conv(-a, -b) = -min_plus_conv(a, b)
        //   ELEMENTWISE.
        let a = vec![1.0_f64, -2.0, 3.0];
        let b = vec![0.5_f64, 1.5];
        let max_conv: Vec<f64> = tropical_convolution(
            &a.iter().map(|x| -x).collect::<Vec<_>>(),
            &b.iter().map(|x| -x).collect::<Vec<_>>(),
        );
        let min_conv = min_plus_convolution(&a, &b);
        for (m, n) in max_conv.iter().zip(min_conv.iter()) {
            assert!((m + n).abs() < 1e-12, "duality fails: max={} + min={}", m, n);
        }
    }

    #[test]
    fn const_evaluates_to_its_value() {
        assert_eq!(evaluate(&TropicalExpr::constant(3.5), &[]).unwrap(), 3.5);
    }

    #[test]
    fn var_evaluates_to_valuation_slot() {
        let v = evaluate(&TropicalExpr::var(2), &[10.0, 20.0, 30.0]).unwrap();
        assert_eq!(v, 30.0);
    }

    #[test]
    fn var_out_of_range_is_rejected() {
        let err = evaluate(&TropicalExpr::var(5), &[10.0]).unwrap_err();
        assert_eq!(
            err,
            TropicalEvalError::VarOutOfRange {
                idx: 5,
                valuation_len: 1,
            }
        );
    }

    #[test]
    fn empty_max_is_neg_infinity() {
        let v = evaluate(&TropicalExpr::max(vec![]), &[]).unwrap();
        assert_eq!(v, f64::NEG_INFINITY);
    }

    #[test]
    fn nonempty_max_picks_largest_argument() {
        let e = TropicalExpr::max(vec![
            TropicalExpr::constant(1.0),
            TropicalExpr::constant(5.0),
            TropicalExpr::constant(3.0),
        ]);
        assert_eq!(evaluate(&e, &[]).unwrap(), 5.0);
    }

    #[test]
    fn plus_is_standard_real_addition() {
        // Tropical multiplication: 2 ⊗ 3 = 2 + 3 = 5.
        let e = TropicalExpr::plus(
            TropicalExpr::constant(2.0),
            TropicalExpr::constant(3.0),
        );
        assert_eq!(evaluate(&e, &[]).unwrap(), 5.0);
    }

    #[test]
    fn nested_max_plus_evaluates_correctly() {
        // max(x + 1, x + 2) where x = 10 → max(11, 12) = 12.
        let e = TropicalExpr::max(vec![
            TropicalExpr::plus(TropicalExpr::var(0), TropicalExpr::constant(1.0)),
            TropicalExpr::plus(TropicalExpr::var(0), TropicalExpr::constant(2.0)),
        ]);
        assert_eq!(evaluate(&e, &[10.0]).unwrap(), 12.0);
    }

    #[test]
    fn max_propagates_var_out_of_range_error() {
        let e = TropicalExpr::max(vec![
            TropicalExpr::constant(1.0),
            TropicalExpr::var(9),
        ]);
        let err = evaluate(&e, &[3.0]).unwrap_err();
        assert!(matches!(err, TropicalEvalError::VarOutOfRange { .. }));
    }

    #[test]
    fn plus_propagates_var_out_of_range_error() {
        let e = TropicalExpr::plus(
            TropicalExpr::constant(1.0),
            TropicalExpr::var(9),
        );
        let err = evaluate(&e, &[3.0]).unwrap_err();
        assert!(matches!(err, TropicalEvalError::VarOutOfRange { .. }));
    }

    #[test]
    fn nan_intermediate_is_rejected() {
        // Plus(NaN, 0.0) — direct construction.
        let e = TropicalExpr::plus(
            TropicalExpr::constant(f64::NAN),
            TropicalExpr::constant(0.0),
        );
        let err = evaluate(&e, &[]).unwrap_err();
        assert!(matches!(err, TropicalEvalError::NonFiniteIntermediate { .. }));
    }

    #[test]
    fn infinity_is_permitted_intermediate() {
        // Max([+inf, 1.0]) → +inf.
        let e = TropicalExpr::max(vec![
            TropicalExpr::constant(f64::INFINITY),
            TropicalExpr::constant(1.0),
        ]);
        assert_eq!(evaluate(&e, &[]).unwrap(), f64::INFINITY);
    }

    #[test]
    fn rational_evaluates_as_numerator_minus_denominator() {
        let r = TropicalRational::new(
            TropicalExpr::constant(7.0),
            TropicalExpr::constant(3.0),
        );
        assert_eq!(evaluate_rational(&r, &[]).unwrap(), 4.0);
    }

    #[test]
    fn rational_with_vars_evaluates_correctly() {
        // numerator: max(x + 1, x + 2) at x=10 → 12
        // denominator: x at x=10 → 10
        // result: 12 - 10 = 2
        let r = TropicalRational::new(
            TropicalExpr::max(vec![
                TropicalExpr::plus(TropicalExpr::var(0), TropicalExpr::constant(1.0)),
                TropicalExpr::plus(TropicalExpr::var(0), TropicalExpr::constant(2.0)),
            ]),
            TropicalExpr::var(0),
        );
        assert_eq!(evaluate_rational(&r, &[10.0]).unwrap(), 2.0);
    }

    #[test]
    fn empty_max_in_rational_yields_neg_infinity_or_finite_diff() {
        // numerator empty Max → -inf; denominator 0 → -inf - 0 = -inf
        let r = TropicalRational::new(
            TropicalExpr::max(vec![]),
            TropicalExpr::constant(0.0),
        );
        assert_eq!(evaluate_rational(&r, &[]).unwrap(), f64::NEG_INFINITY);
    }

    // ── Scale variant evaluation (iter-61) ────────────────────────

    #[test]
    fn scale_const_evaluates_to_product() {
        let e = TropicalExpr::scale(3.0, TropicalExpr::constant(4.0));
        assert_eq!(evaluate(&e, &[]).unwrap(), 12.0);
    }

    #[test]
    fn scale_var_evaluates_to_real_multiplication() {
        // Scale(2.5, Var(0)) at x=4 → 2.5 * 4 = 10.
        let e = TropicalExpr::scale(2.5, TropicalExpr::var(0));
        assert_eq!(evaluate(&e, &[4.0]).unwrap(), 10.0);
    }

    #[test]
    fn scale_with_negative_weight() {
        let e = TropicalExpr::scale(-2.0, TropicalExpr::var(0));
        assert_eq!(evaluate(&e, &[3.0]).unwrap(), -6.0);
    }

    #[test]
    fn scale_inside_plus_for_real_linear_combination() {
        // 2*x_0 + 3*x_1 + 5 — typical ReLU pre-activation form.
        let e = TropicalExpr::plus(
            TropicalExpr::plus(
                TropicalExpr::scale(2.0, TropicalExpr::var(0)),
                TropicalExpr::scale(3.0, TropicalExpr::var(1)),
            ),
            TropicalExpr::constant(5.0),
        );
        // x = (1, 2) → 2 + 6 + 5 = 13.
        assert_eq!(evaluate(&e, &[1.0, 2.0]).unwrap(), 13.0);
    }

    #[test]
    fn scale_inside_max_for_general_relu_layer() {
        // max(0, 2*x_0 + 3*x_1 - 1) — a single ReLU neuron with
        // arbitrary real weights.
        let pre_activation = TropicalExpr::plus(
            TropicalExpr::plus(
                TropicalExpr::scale(2.0, TropicalExpr::var(0)),
                TropicalExpr::scale(3.0, TropicalExpr::var(1)),
            ),
            TropicalExpr::constant(-1.0),
        );
        let relu = TropicalExpr::max(vec![
            TropicalExpr::constant(0.0),
            pre_activation,
        ]);
        // x = (1, 1) → max(0, 2+3-1) = max(0, 4) = 4.
        assert_eq!(evaluate(&relu, &[1.0, 1.0]).unwrap(), 4.0);
        // x = (-1, 0) → max(0, -2 + 0 - 1) = max(0, -3) = 0.
        assert_eq!(evaluate(&relu, &[-1.0, 0.0]).unwrap(), 0.0);
    }

    #[test]
    fn scale_by_zero_yields_zero() {
        let e = TropicalExpr::scale(0.0, TropicalExpr::var(0));
        assert_eq!(evaluate(&e, &[100.0]).unwrap(), 0.0);
    }

    #[test]
    fn scale_propagates_var_out_of_range_error() {
        let e = TropicalExpr::scale(2.0, TropicalExpr::var(9));
        let err = evaluate(&e, &[1.0]).unwrap_err();
        assert!(matches!(err, TropicalEvalError::VarOutOfRange { .. }));
    }
}
