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

/// Smooth (max, +) inner product (LSE relaxation):
///
/// `⟨a, b⟩_β = (1/β) · ln Σ_i exp(β · (a_i + b_i))`.
///
/// Numerically stable: shifts by the max of `(a_i + b_i)` before
/// exp. As `β → ∞`, converges to the sharp (max, +) inner product
/// `max_i (a_i + b_i)`. As `β → 0`, approaches the arithmetic
/// mean plus `(ln n)/β`.
///
/// Behavior:
/// - Empty / length-mismatched inputs → `None`.
/// - `β ≤ 0` or non-finite → `Some(NaN)`.
/// - NaN component → propagates.
///
/// Iter-442 — differentiable companion to
/// [`tropical_inner_product`] (iter-134). Pairs with the existing
/// scalar-fold smooth-max [`tropical_smooth_max`] (iter-346) and
/// the smooth-amplitude [`tropical_smooth_amplitude`] (iter-436).
/// Useful as:
/// - Inner-loop of differentiable tropical matrix-vector ops.
/// - Soft single-step relaxation of longest-path costs.
/// - Smooth surrogate for max-plus bilinear attention scores.
///
/// Source. LSE-smooth max: Nielsen & Sun, "Guaranteed bounds on
/// information-theoretic measures of univariate mixtures using
/// piecewise log-sum-exp inequalities", Entropy 18(12):442 (2016)
/// §2 — applied to the coordinatewise (a_i + b_i) sequence.
/// Tropical inner-product reference: Cuninghame-Green, "Minimax
/// Algebra", LNEMS 166 (1979) §1.3.
pub fn tropical_smooth_inner_product(a: &[f64], b: &[f64], beta: f64) -> Option<f64> {
    if a.is_empty() || b.is_empty() || a.len() != b.len() {
        return None;
    }
    if beta <= 0.0 || !beta.is_finite() {
        return Some(f64::NAN);
    }
    let sums: Vec<f64> = a.iter().zip(b.iter()).map(|(x, y)| x + y).collect();
    let m = sums.iter().copied().fold(f64::NEG_INFINITY, f64::max);
    if !m.is_finite() {
        return Some(m);
    }
    let exp_sum: f64 = sums.iter().map(|s| (beta * (s - m)).exp()).sum();
    Some(m + exp_sum.ln() / beta)
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

/// Per-column min-plus ⊕-fold: `c_j = min_i A_{i,j}`.
///
/// Returns a vector of length `a[0].len()`. Empty matrix →
/// empty Vec; ragged input → None.
///
/// Iter-274 — min-plus column companion to
/// `tropical_matrix_col_max` (iter-256). Closes the
/// (max-row, max-col, min-row, min-col) fold matrix in
/// idempotent semiring linear algebra on matrices.
pub fn min_plus_matrix_col_min(a: &[Vec<f64>]) -> Option<Vec<f64>> {
    if a.is_empty() {
        return Some(Vec::new());
    }
    let n_cols = a[0].len();
    for row in a {
        if row.len() != n_cols {
            return None;
        }
    }
    let mut out = vec![f64::INFINITY; n_cols];
    for row in a {
        for (j, &x) in row.iter().enumerate() {
            if x < out[j] {
                out[j] = x;
            }
        }
    }
    Some(out)
}

/// Per-column tropical ⊕-fold: `c_j = max_i A_{i,j}`.
///
/// Returns a vector of length `a[0].len()`. Each entry is the
/// max over that column. Returns `None` on ragged input (rows of
/// different lengths). Empty matrix → empty result.
///
/// Iter-256 — column-axis companion to `tropical_matrix_row_max`
/// (iter-250). Used in tropical-DP value-iteration steps that
/// reduce along the action (column) dimension.
pub fn tropical_matrix_col_max(a: &[Vec<f64>]) -> Option<Vec<f64>> {
    if a.is_empty() {
        return Some(Vec::new());
    }
    let n_cols = a[0].len();
    for row in a {
        if row.len() != n_cols {
            return None;
        }
    }
    let mut out = vec![f64::NEG_INFINITY; n_cols];
    for row in a {
        for (j, &x) in row.iter().enumerate() {
            if x > out[j] {
                out[j] = x;
            }
        }
    }
    Some(out)
}

/// Per-row min-plus ⊕-fold: `r_i = min_j A_{i,j}`.
///
/// Returns a vector of length `a.len()`. Empty row → INFINITY.
/// Iter-268 — min-plus row companion to
/// `tropical_matrix_row_max` (iter-250).
pub fn min_plus_matrix_row_min(a: &[Vec<f64>]) -> Vec<f64> {
    a.iter().map(|row| min_plus_vector_min(row)).collect()
}

/// Per-row tropical ⊕-fold: `r_i = max_j A_{i,j}`.
///
/// Returns a vector of length `a.len()`. Each entry is the
/// (max, +) "sum" of that row — `NEG_INFINITY` if the row is
/// empty.
///
/// Equivalent to applying `tropical_vector_max` to each row.
///
/// Iter-250 — companion to `tropical_matrix_max_fold` (all
/// entries) and `tropical_matrix_diagonal` (diagonal only);
/// this folds along the column axis to produce a row vector.
pub fn tropical_matrix_row_max(a: &[Vec<f64>]) -> Vec<f64> {
    a.iter().map(|row| tropical_vector_max(row)).collect()
}

/// Min-plus ⊕-fold over all entries of a matrix:
/// `min_{i,j} A_{i,j}`.
///
/// The (min, +) "scalar sum" of the matrix. Returns
/// `INFINITY` (min-plus additive identity) on empty input.
///
/// Iter-262 — min-plus companion to `tropical_matrix_max_fold`
/// (iter-238). Together they form the all-entries fold pair.
pub fn min_plus_matrix_min_fold(a: &[Vec<f64>]) -> f64 {
    let mut best = f64::INFINITY;
    for row in a {
        for &x in row {
            if x < best {
                best = x;
            }
        }
    }
    best
}

/// Tropical ⊕-fold over all entries of a matrix:
/// `⊕_{i,j} A_{i,j} = max_{i,j} A_{i,j}`.
///
/// The "scalar sum" of the matrix in (max, +). Returns
/// `NEG_INFINITY` (additive identity) on an empty matrix or any
/// matrix consisting only of empty rows.
///
/// Iter-238 — companion to `tropical_vector_max` (vector fold)
/// and `tropical_matrix_trace` (diagonal fold); this folds over
/// all entries.
pub fn tropical_matrix_max_fold(a: &[Vec<f64>]) -> f64 {
    let mut best = f64::NEG_INFINITY;
    for row in a {
        for &x in row {
            if x > best {
                best = x;
            }
        }
    }
    best
}

/// Tropical (max, +) arg-max + value: returns
/// `Some((idx, max))` for the first occurrence of the maximum,
/// or `None` on empty input.
///
/// Iter-316 — packed companion to `tropical_argmax_idx` and
/// `tropical_vector_max`. Single-pass O(n).
pub fn tropical_vector_argmax_value(v: &[f64]) -> Option<(usize, f64)> {
    if v.is_empty() {
        return None;
    }
    let mut best_idx = 0_usize;
    let mut best_val = f64::NEG_INFINITY;
    for (i, &x) in v.iter().enumerate() {
        if x > best_val {
            best_val = x;
            best_idx = i;
        }
    }
    Some((best_idx, best_val))
}

/// Min-plus argmin + value: returns `Some((idx, min))` for the
/// first occurrence of the minimum, or `None` on empty input.
///
/// Iter-322 — packed companion to `tropical_argmin_idx` and
/// `min_plus_vector_min` (the (min, +) duals of the (max, +)
/// fold). Single-pass O(n). Mirror of
/// [`tropical_vector_argmax_value`] (iter-316) for the dual
/// semiring; useful in tropical-DP shortest-path backtrace
/// where the action index + path cost pair is the natural
/// state.
///
/// Source. Standard packed argmin-value; cf. Cuninghame-Green,
/// "Minimax Algebra", Lecture Notes in Economics and Mathematical
/// Systems 166 (1979) §1.2 — (min, +) semiring fold.
pub fn min_plus_vector_argmin_value(v: &[f64]) -> Option<(usize, f64)> {
    if v.is_empty() {
        return None;
    }
    let mut best_idx = 0_usize;
    let mut best_val = f64::INFINITY;
    for (i, &x) in v.iter().enumerate() {
        if x < best_val {
            best_val = x;
            best_idx = i;
        }
    }
    Some((best_idx, best_val))
}

/// Single-pass (min, max) of a tropical vector.
///
/// Returns `Some((min, max))` over `v`, or `None` on empty input.
/// Equivalent to `(min_plus_vector_min, tropical_vector_max)` but
/// produced in one O(n) traversal — the natural fold-pair across
/// the (max, +) / (min, +) semirings.
///
/// The difference `max − min` is the *tropical amplitude* of the
/// vector — the value range that the tropical-DP value function
/// spans when `v` is a slice of states. Combined with
/// [`tropical_vector_argmax_value`] / [`min_plus_vector_argmin_value`],
/// callers get the four extremal scalars (min, argmin, max,
/// argmax) of a tropical vector with two single-pass calls
/// instead of four folds.
///
/// Iter-328 — packed pair primitive; mirror of `running_min_max_pair`
/// (Scan-IR iter-?) on the static-vector side.
///
/// Source. Standard min-max single-pass; in tropical / (max, +)
/// algebra the (min, max) pair is the canonical *amplitude*
/// statistic, cf. Cuninghame-Green, "Minimax Algebra", LNEMS 166
/// (Springer, 1979) §1.2.
pub fn tropical_vector_min_max_pair(v: &[f64]) -> Option<(f64, f64)> {
    if v.is_empty() {
        return None;
    }
    let mut lo = f64::INFINITY;
    let mut hi = f64::NEG_INFINITY;
    for &x in v {
        if x < lo {
            lo = x;
        }
        if x > hi {
            hi = x;
        }
    }
    Some((lo, hi))
}

/// Single-pass (argmin, argmax) index pair of a vector.
///
/// Returns `Some((min_idx, max_idx))` over `v`, or `None` on
/// empty input. Ties at either extreme go to the first
/// occurrence (lowest index).
///
/// Iter-394 — index-side companion to
/// [`tropical_vector_min_max_pair`] (iter-328, value side).
/// The (min_idx, max_idx, min_val, max_val) quartet for a
/// tropical vector now decomposes cleanly into two packed
/// primitives instead of four separate folds.
///
/// Source. Standard min-max single-pass; tropical-DP backtrace
/// uses both extremes simultaneously when a value function
/// admits dual interpretations (e.g., reward + cost paths).
pub fn tropical_vector_argmin_argmax_indices(v: &[f64]) -> Option<(usize, usize)> {
    if v.is_empty() {
        return None;
    }
    let mut min_idx = 0_usize;
    let mut max_idx = 0_usize;
    let mut lo = f64::INFINITY;
    let mut hi = f64::NEG_INFINITY;
    for (i, &x) in v.iter().enumerate() {
        if x < lo {
            lo = x;
            min_idx = i;
        }
        if x > hi {
            hi = x;
            max_idx = i;
        }
    }
    Some((min_idx, max_idx))
}

/// Tropical amplitude scalar: `max(v) − min(v)`.
///
/// Returns `Some(amp)` over non-empty `v`, `None` on empty.
/// Always ≥ 0; equals 0 iff every element is identical.
///
/// Iter-400 — scalar-difference companion to
/// [`tropical_vector_min_max_pair`] (iter-328, packed tuple).
/// Useful as a single-number "value-function spread"
/// diagnostic in tropical-DP. Identical in value across
/// (max, +) and (min, +) semirings: both yield the same scalar
/// `hi − lo`.
///
/// Source. Tropical amplitude / dynamic range: Cuninghame-Green,
/// "Minimax Algebra", LNEMS 166 (1979) §1.2 (eq. 1.2.4 — the
/// (max, +) range as the canonical magnitude statistic).
pub fn tropical_vector_amplitude(v: &[f64]) -> Option<f64> {
    let (lo, hi) = tropical_vector_min_max_pair(v)?;
    Some(hi - lo)
}

/// Recenter a tropical vector to maximum 0:
/// `(v_i − max_j v_j)` componentwise.
///
/// The canonical (max, +) normalization for LSE-stability and
/// for working with shifted-tropical value functions. After
/// recentering, `max = 0`, all other entries `≤ 0`. Distinct
/// from the (min, +) recentering (shift so `min = 0`); use
/// `tropical_vector_scalar_add(v, -min(v))` for that.
///
/// Returns an empty `Vec` on empty input.
///
/// Iter-424 — companion to [`tropical_vector_scalar_add`]
/// (iter-280, scalar shift) and [`tropical_smooth_max`]
/// (iter-346, LSE) — the canonical preprocessing step that
/// makes both stable: LSE_β over a recentered vector never
/// overflows the exp.
///
/// Source. (max, +) normalization as the canonical
/// shift-invariance of the LSE: Cuninghame-Green, "Minimax
/// Algebra", LNEMS 166 (1979) §1.2 (the shift-invariance of
/// max + scalar).
pub fn tropical_vector_recenter(v: &[f64]) -> Vec<f64> {
    if v.is_empty() {
        return Vec::new();
    }
    let m = tropical_vector_max(v);
    v.iter().map(|&x| x - m).collect()
}

/// Chebyshev / sup-norm tropical distance:
/// `dist(a, b) = max_i |a_i − b_i|`.
///
/// Returns `None` on length mismatch (the (max, +) semiring
/// folds aren't defined across different-length vectors).
/// Always ≥ 0; zero iff `a == b` pointwise.
///
/// The (max, +) semiring's natural distance: bounded by the
/// largest single coordinate-wise gap. In tropical-DP this is
/// the "longest single state transition cost" — the worst-case
/// step cost in a path.
///
/// Iter-406 — vector companion to [`tropical_distance_matrix`]
/// (matrix construction, iter-?) and to `vector_distance_l1`
/// (Geometry-IR's L¹ distance, iter-282) under a different
/// p-norm.
///
/// Source. Chebyshev / L∞ distance + tropical interpretation:
/// Cuninghame-Green, "Minimax Algebra", LNEMS 166 (1979) §1.2
/// (sup-norm as the (max, +)-natural distance).
pub fn tropical_chebyshev_distance(a: &[f64], b: &[f64]) -> Option<f64> {
    if a.len() != b.len() {
        return None;
    }
    if a.is_empty() {
        return Some(0.0);
    }
    let mut max_diff = 0.0_f64;
    for (&x, &y) in a.iter().zip(b.iter()) {
        let d = (x - y).abs();
        if d > max_diff {
            max_diff = d;
        }
    }
    Some(max_diff)
}

/// LSE-smoothed Chebyshev (L∞) distance:
/// `d_β(a, b) = (1/β) · ln Σ_i exp(β · |a_i − b_i|)`.
///
/// Differentiable surrogate for [`tropical_chebyshev_distance`].
/// As β → ∞, converges to the sharp max-absolute gap; as β → 0,
/// approaches `(mean|a−b|) + (ln n)/β`. Numerically stable:
/// shifts by the max of `|a_i − b_i|` before exp.
///
/// Behavior:
/// - Length mismatch → `None`.
/// - Empty/empty   → `Some(0)`.
/// - `β ≤ 0` / non-finite → `Some(NaN)`.
/// - NaN component → propagates.
///
/// Iter-448 — differentiable pairwise-distance companion to
/// the existing smooth-fold family
/// (`tropical_smooth_max`, `tropical_smooth_min`,
/// `tropical_smooth_amplitude`, `tropical_smooth_inner_product`).
/// Useful as:
/// - Gradient-friendly worst-coordinate-gap loss.
/// - Adversarial L∞-ball relaxation.
/// - Soft Hausdorff-style distance in metric learning.
///
/// Source. LSE-smooth max: Nielsen & Sun, Entropy 18(12):442
/// (2016) §2. Chebyshev distance reference: Cuninghame-Green,
/// "Minimax Algebra", LNEMS 166 (1979) §1.2.
pub fn tropical_smooth_chebyshev_distance(
    a: &[f64],
    b: &[f64],
    beta: f64,
) -> Option<f64> {
    if a.len() != b.len() {
        return None;
    }
    if a.is_empty() {
        return Some(0.0);
    }
    if beta <= 0.0 || !beta.is_finite() {
        return Some(f64::NAN);
    }
    let diffs: Vec<f64> = a.iter().zip(b.iter()).map(|(x, y)| (x - y).abs()).collect();
    let m = diffs.iter().copied().fold(f64::NEG_INFINITY, f64::max);
    if !m.is_finite() {
        return Some(m);
    }
    let exp_sum: f64 = diffs.iter().map(|d| (beta * (d - m)).exp()).sum();
    Some(m + exp_sum.ln() / beta)
}

/// L¹ (Manhattan / taxicab) tropical distance:
/// `dist(a, b) = Σ_i |a_i − b_i|`.
///
/// Returns `None` on length mismatch. Always ≥ 0; zero iff
/// `a == b` pointwise.
///
/// Closes the (L¹, L∞) tropical pairwise-distance pair
/// alongside [`tropical_chebyshev_distance`] (iter-406). Useful
/// in tropical-DP when *cumulative* coordinate-wise gaps
/// matter (total transition-cost difference between two
/// trajectories) rather than the worst-single gap.
///
/// Iter-430 — sum-of-absolute-differences companion; bounds
/// the Chebyshev distance: `Chebyshev ≤ L¹ ≤ n · Chebyshev`
/// where `n` is the vector length.
///
/// Source. ℓ_p tropical pairwise distances: Maclagan &
/// Sturmfels, "Introduction to Tropical Geometry", GSM 161
/// (2015) §1.1 (L¹ and L∞ as canonical metrics on the (max, +)
/// semiring's affine support).
pub fn tropical_l1_distance(a: &[f64], b: &[f64]) -> Option<f64> {
    if a.len() != b.len() {
        return None;
    }
    if a.is_empty() {
        return Some(0.0);
    }
    let sum: f64 = a
        .iter()
        .zip(b.iter())
        .map(|(&x, &y)| (x - y).abs())
        .sum();
    Some(sum)
}

/// Element-wise tropical (max, +) addition of two same-length
/// vectors: `(a ⊕ b)_i = max(a_i, b_i)`.
///
/// Returns `None` if `a.len() != b.len()` (length must match for
/// the (max, +) semiring to define the operation on the same
/// index set).
///
/// Iter-334 — vector-vector counterpart of `tropical_outer_sum`
/// (which builds the (max, +) outer-sum matrix). The pair
/// (`tropical_pairwise_max`, `min_plus_pairwise_min`) are the
/// semiring-additive folds on a pair of indexed sequences.
///
/// Source. Standard (max, +) componentwise semiring sum: Maclagan
/// & Sturmfels, "Introduction to Tropical Geometry", GSM 161 §1.1.
pub fn tropical_pairwise_max(a: &[f64], b: &[f64]) -> Option<Vec<f64>> {
    if a.len() != b.len() {
        return None;
    }
    Some(a.iter().zip(b.iter()).map(|(&x, &y)| x.max(y)).collect())
}

/// Element-wise tropical (max, +) / (min, +) "multiplication"
/// (`⊗`) of two same-length vectors: `(a ⊗ b)_i = a_i + b_i`.
///
/// In both the (max, +) and (min, +) semirings, the semiring
/// product is ordinary scalar addition. Lifted to vectors,
/// this is standard component-wise addition — but having a
/// named tropical primitive at the API surface makes
/// tropical-DP value-function shifts a one-call operation
/// instead of inline `iter().zip().map(|(x, y)| x + y)` at
/// every site.
///
/// Returns `None` on length mismatch.
///
/// Iter-358 — completes the (semiring-⊕, semiring-⊗) vector-
/// vector pair on the tropical side. Pairs with
/// [`tropical_pairwise_max`] (iter-334, ⊕ in max-plus) and
/// [`min_plus_pairwise_min`] (iter-334, ⊕ in min-plus).
///
/// Source. (max, +) semiring multiplication as ordinary scalar
/// addition: Maclagan & Sturmfels, "Introduction to Tropical
/// Geometry", GSM 161 (2015) §1.1. Vector-lifted form: standard
/// componentwise.
pub fn tropical_vector_pairwise_add(a: &[f64], b: &[f64]) -> Option<Vec<f64>> {
    if a.len() != b.len() {
        return None;
    }
    Some(a.iter().zip(b.iter()).map(|(&x, &y)| x + y).collect())
}

/// Element-wise (min, +) addition of two same-length vectors:
/// `(a ⊕_min b)_i = min(a_i, b_i)`.
///
/// Returns `None` if `a.len() != b.len()`. Dual of
/// [`tropical_pairwise_max`] under the (min, +) semiring.
///
/// Iter-334 — closes the (max, min) pairwise-fold pair on indexed
/// sequences.
pub fn min_plus_pairwise_min(a: &[f64], b: &[f64]) -> Option<Vec<f64>> {
    if a.len() != b.len() {
        return None;
    }
    Some(a.iter().zip(b.iter()).map(|(&x, &y)| x.min(y)).collect())
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

/// Entrywise vector negation: `(−v)_i = −v_i`.
///
/// Vector companion of `tropical_matrix_negate` (iter-244). The
/// (max, +) ↔ (min, +) bridge at the vector level.
///
/// Iter-304 — semiring-bridge primitive on vectors.
pub fn tropical_vector_negate(v: &[f64]) -> Vec<f64> {
    v.iter().map(|x| -x).collect()
}

/// Entrywise negation: `(−A)_{i,j} = −A_{i,j}`.
///
/// The (max, +) ↔ (min, +) bridge: if `A` is a (max, +) matrix
/// representing max-path costs, `−A` is the corresponding
/// (min, +) matrix for the dual shortest-path problem (and
/// vice versa). Empty matrix → empty result; ragged rows
/// pass through.
///
/// Iter-244 — semiring-bridge primitive. Together with
/// `tropical_matrix_max_pointwise` (max ⊕),
/// `min_plus_matrix_min_pointwise` (min ⊕), and the multiplies,
/// closes the (max, +) ↔ (min, +) duality at the matrix level.
pub fn tropical_matrix_negate(a: &[Vec<f64>]) -> Vec<Vec<f64>> {
    a.iter()
        .map(|row| row.iter().map(|x| -x).collect())
        .collect()
}

/// Tropical (max, +) vector scalar add: `(v ⊕ c)_i = vᵢ + c`.
///
/// The vector-level companion of `tropical_matrix_scalar_add`
/// (iter-202). In (max, +) semantics this is the scalar
/// "multiplication" lifted to vectors.
///
/// Iter-280 — element-wise shift; semiring-neutral (same for
/// max-plus and min-plus). Companion to tropical_matrix_scalar_add.
pub fn tropical_vector_scalar_add(v: &[f64], c: f64) -> Vec<f64> {
    v.iter().map(|x| x + c).collect()
}

/// Tropical (max, +) vector scalar max: `(v ⊕ c)_i = max(vᵢ, c)`.
///
/// Element-wise max against a constant scalar — the semiring
/// "addition" lifted to (vector, scalar). The canonical
/// implementation of a ReLU-like element when `c = 0`:
/// `tropical_vector_scalar_max(v, 0.0)` is the (max, +) form of
/// the ReLU activation applied to a tropical-value vector.
///
/// Iter-340 — semiring-add companion to
/// [`tropical_vector_scalar_add`] (semiring-mul / scalar shift).
/// In (max, +): ⊕ ↔ max, ⊗ ↔ +. The pair (`scalar_add`,
/// `scalar_max`) closes the (scalar `⊗`, scalar `⊕`) primitives.
///
/// Source. (max, +) semiring tropical operations: Maclagan &
/// Sturmfels, "Introduction to Tropical Geometry", GSM 161
/// (2015) §1.1. The ReLU-as-(max, +) interpretation:
/// Zhang/Naitzat/Lim "Tropical Geometry of Deep Neural Networks",
/// arXiv:1805.07091 §3.
pub fn tropical_vector_scalar_max(v: &[f64], c: f64) -> Vec<f64> {
    v.iter().map(|x| x.max(c)).collect()
}

/// (min, +) vector scalar min: `(v ⊕_min c)_i = min(vᵢ, c)`.
///
/// Sibling of [`tropical_vector_scalar_max`] under the (min, +)
/// semiring. Useful as the upper-clip element when `c` is a
/// saturation bound on a (min, +) value function.
///
/// Iter-340 — closes the (max, min) `scalar_⊕` pair.
pub fn min_plus_vector_scalar_min(v: &[f64], c: f64) -> Vec<f64> {
    v.iter().map(|x| x.min(c)).collect()
}

/// Smooth (max, +) approximation via log-sum-exp:
/// `LSE_β(v) = (1/β) · ln(Σᵢ exp(β · vᵢ))`.
///
/// As `β → ∞`, converges to the (max, +) fold `max_i v_i`
/// (sharp tropical max). For finite β, this is the standard
/// differentiable surrogate used in soft-max activation and
/// regularization-of-tropical-polynomial relaxations.
///
/// Numerically stable: shifts by the max before exp to avoid
/// overflow, then re-applies the shift in log-space.
///
/// Behavior:
/// - Empty input → `f64::NEG_INFINITY` (matches `tropical_vector_max`).
/// - `β ≤ 0` → NaN (the LSE smooth-max needs strictly positive
///   temperature inverse; the β = 0 limit is `ln(n)/β` which
///   is undefined and the β < 0 case produces smooth-min, which
///   has its own sibling builder if needed).
/// - NaN component → propagates to NaN (via exp/ln).
///
/// Iter-346 — differentiable companion to `tropical_vector_max`
/// (iter-220). The sharp/smooth pair is the bridge from
/// Tropical-IR to gradient-friendly Operator-IR layers.
///
/// Source. Log-sum-exp / softmax interpretation as smooth max:
/// Nielsen & Sun, "Guaranteed bounds on information-theoretic
/// measures of univariate mixtures using piecewise log-sum-exp
/// inequalities", Entropy 18(12):442 (2016) §2. Differentiable
/// tropical relaxation: Charisopoulos, Maragos,
/// "A Tropical Approach to Neural Networks with Piecewise Linear
/// Activations", arXiv:1805.08749 §4.
pub fn tropical_smooth_max(v: &[f64], beta: f64) -> f64 {
    if v.is_empty() {
        return f64::NEG_INFINITY;
    }
    if beta <= 0.0 || !beta.is_finite() {
        return f64::NAN;
    }
    let m = tropical_vector_max(v);
    if !m.is_finite() {
        return m;
    }
    let sum: f64 = v.iter().map(|&x| (beta * (x - m)).exp()).sum();
    m + sum.ln() / beta
}

/// Smooth (min, +) approximation via log-sum-exp duality:
/// `LSE_β^{min}(v) = −(1/β) · ln(Σᵢ exp(−β · vᵢ))`.
///
/// As `β → ∞`, converges to the (min, +) fold `min_i v_i`. For
/// finite β, this is the standard differentiable surrogate for
/// the sharp tropical min, equivalent to `−tropical_smooth_max(−v, β)`
/// (semiring duality).
///
/// Numerically stable: shifts by the min before exp.
///
/// Behavior:
/// - Empty input → `f64::INFINITY` (matches `min_plus_vector_min`).
/// - `β ≤ 0` / non-finite → NaN.
/// - NaN component → propagates.
///
/// Iter-352 — sibling of [`tropical_smooth_max`] (iter-346)
/// under (min, +) duality. Pairs the differentiable (max, min)
/// approximations across both semirings.
///
/// Source. LSE-form smooth min via duality of the (max, +) /
/// (min, +) semirings: Cuninghame-Green, "Minimax Algebra",
/// LNEMS 166 (1979) §1.2 (semiring duality) + Nielsen & Sun,
/// Entropy 18(12):442 (2016) §2 (LSE smooth-max).
pub fn tropical_smooth_min(v: &[f64], beta: f64) -> f64 {
    if v.is_empty() {
        return f64::INFINITY;
    }
    if beta <= 0.0 || !beta.is_finite() {
        return f64::NAN;
    }
    let m = min_plus_vector_min(v);
    if !m.is_finite() {
        return m;
    }
    let sum: f64 = v.iter().map(|&x| (-beta * (x - m)).exp()).sum();
    m - sum.ln() / beta
}

/// Differentiable amplitude (LSE-smoothed range):
/// `A_β(v) = smooth_max(v, β) − smooth_min(v, β)`.
///
/// Continuous, non-negative, everywhere-differentiable surrogate
/// for `tropical_vector_amplitude` (hard max − min). As β → ∞,
/// converges to the sharp amplitude `max v − min v`; as β → 0,
/// shrinks toward 0 (LSE soft-max and soft-min collapse toward
/// the per-coordinate mean log-sum-exp).
///
/// Behavior:
/// - Empty input → `None`.
/// - `β ≤ 0` / non-finite → `Some(NaN)` via the sub-folds.
/// - NaN component → propagates.
///
/// Iter-436 — closes the smooth-fold triple
/// `(smooth_max, smooth_min, smooth_amplitude)` over (max, +).
/// Useful as:
/// - Gradient-friendly spread regularizer.
/// - Soft-classification confidence gap surrogate.
/// - Differentiable surrogate for L∞-style range loss.
///
/// Source. LSE smooth-max / smooth-min: Nielsen & Sun, "Guaranteed
/// bounds on information-theoretic measures of univariate mixtures
/// using piecewise log-sum-exp inequalities", Entropy 18(12):442
/// (2016) §2. Tropical sharp-amplitude limit: Maclagan & Sturmfels,
/// "Introduction to Tropical Geometry", GSM 161 (2015) §1.1.
pub fn tropical_smooth_amplitude(v: &[f64], beta: f64) -> Option<f64> {
    if v.is_empty() {
        return None;
    }
    Some(tropical_smooth_max(v, beta) - tropical_smooth_min(v, beta))
}

/// Tropical softmax (differentiable argmax-weight distribution):
/// `w_i = exp(β · vᵢ) / Σⱼ exp(β · vⱼ)`.
///
/// Numerically stable via max-shift before exp (otherwise the
/// numerator and denominator overflow at moderate β / |v|).
///
/// The returned vector is a valid probability distribution
/// (entries non-negative, sum to 1) — the soft-argmax companion
/// to the soft-max scalar [`tropical_smooth_max`] (iter-346).
/// As β → ∞, concentrates on the argmax index; as β → 0,
/// becomes uniform.
///
/// Behavior:
/// - Empty input → empty Vec.
/// - β ≤ 0 / non-finite → empty Vec (signals invalid parameter
///   without panicking).
///
/// Iter-364 — argmax-weight companion to `tropical_smooth_max`
/// + `tropical_smooth_min`. Pair the smooth fold (value) with
/// the soft-argmax (weights) for end-to-end differentiable
/// tropical-DP.
///
/// Source. Softmax as the smooth-argmax distribution:
/// Goodfellow, Bengio, Courville, "Deep Learning" (MIT Press,
/// 2016) §6.2.2.2 eq. (6.30); semiring interpretation:
/// Charisopoulos & Maragos arXiv:1805.08749 §4.
pub fn tropical_softmax(v: &[f64], beta: f64) -> Vec<f64> {
    if v.is_empty() || beta <= 0.0 || !beta.is_finite() {
        return Vec::new();
    }
    let m = tropical_vector_max(v);
    if !m.is_finite() {
        return vec![0.0; v.len()];
    }
    let mut weights: Vec<f64> = v.iter().map(|&x| (beta * (x - m)).exp()).collect();
    let z: f64 = weights.iter().sum();
    if z <= 0.0 {
        return vec![0.0; v.len()];
    }
    for w in weights.iter_mut() {
        *w /= z;
    }
    weights
}

/// Numerically stable log-softmax over the (max, +) coordinates:
/// `log_softmax_i(v; β) = β · v_i − ln Σ_j exp(β · v_j)`.
///
/// Computed in log-domain via max-shift to avoid overflow:
///   `= β · (v_i − m) − ln Σ_j exp(β · (v_j − m))`,
///   where `m = max_j v_j`.
///
/// Returns a vector whose softmax-exponentials sum to 1 (i.e.
/// `exp(log_softmax(v)) ≡ tropical_softmax(v, β)`). Negative-
/// valued entries; the argmax index is the *least* negative
/// (zero in the β → ∞ limit). Useful as the numerically stable
/// loss-side companion to `tropical_softmax` (iter-364) — direct
/// `log(softmax(·))` would underflow at moderate β / |v|.
///
/// Behavior:
/// - Empty input → empty Vec.
/// - β ≤ 0 / non-finite → empty Vec (matches tropical_softmax).
/// - Non-finite `m` → vector of zeros (matches tropical_softmax).
///
/// Iter-466 — log-domain companion to [`tropical_softmax`]
/// (iter-364) and the LSE smooth-max [`tropical_smooth_max`]
/// (iter-346). Useful as:
/// - Numerically stable cross-entropy / NLL loss input.
/// - Knowledge-distillation log-probability surrogate.
/// - Loss-side companion to tropical-ReLU compilation.
///
/// Source. Numerically stable log-softmax: Bridle, "Probabilistic
/// Interpretation of Feedforward Classification Network Outputs",
/// Neurocomputing (1990) §3 (the original softmax formulation
/// uses the log-form). LSE max-shift trick: Robertson & Wright,
/// "A Note on Log-Sum-Exp", manuscript (2010).
pub fn tropical_log_softmax(v: &[f64], beta: f64) -> Vec<f64> {
    if v.is_empty() || beta <= 0.0 || !beta.is_finite() {
        return Vec::new();
    }
    let m = tropical_vector_max(v);
    if !m.is_finite() {
        return vec![0.0; v.len()];
    }
    let exp_sum: f64 = v.iter().map(|&x| (beta * (x - m)).exp()).sum();
    let log_z = exp_sum.ln();
    v.iter().map(|&x| beta * (x - m) - log_z).collect()
}

/// Tropical softmin (differentiable argmin-weight distribution):
/// `w_i = exp(−β · vᵢ) / Σⱼ exp(−β · vⱼ)`.
///
/// Numerically stable via min-shift before exp. Returns a valid
/// probability distribution. As β → ∞ concentrates on argmin
/// index; as β → 0 becomes uniform.
///
/// Behavior:
/// - Empty input → empty Vec.
/// - β ≤ 0 / non-finite → empty Vec.
///
/// Iter-370 — sibling of [`tropical_softmax`] (iter-364) under
/// (min, +) / (max, +) duality. Together they close the
/// (soft-argmax, soft-argmin) weight-distribution pair for
/// differentiable tropical-DP.
///
/// Source. Softmin as smooth-argmin distribution: dual under
/// negation of the softmax interpretation in Goodfellow,
/// Bengio, Courville, "Deep Learning" (MIT Press, 2016)
/// §6.2.2.2.
pub fn tropical_softmin(v: &[f64], beta: f64) -> Vec<f64> {
    if v.is_empty() || beta <= 0.0 || !beta.is_finite() {
        return Vec::new();
    }
    let m = min_plus_vector_min(v);
    if !m.is_finite() {
        return vec![0.0; v.len()];
    }
    let mut weights: Vec<f64> = v.iter().map(|&x| (-beta * (x - m)).exp()).collect();
    let z: f64 = weights.iter().sum();
    if z <= 0.0 {
        return vec![0.0; v.len()];
    }
    for w in weights.iter_mut() {
        *w /= z;
    }
    weights
}

/// Numerically stable log-softmin over the (min, +) coordinates:
/// `log_softmin_i(v; β) = −β · v_i − ln Σ_j exp(−β · v_j)`.
///
/// Computed in log-domain via min-shift to avoid overflow:
///   `= −β · (v_i − m) − ln Σ_j exp(−β · (v_j − m))`,
///   where `m = min_j v_j`.
///
/// Returns a vector whose softmin-exponentials sum to 1 (i.e.
/// `exp(log_softmin(v)) ≡ tropical_softmin(v, β)`). Negative-
/// valued entries; the argmin index is the *least* negative
/// (zero in the β → ∞ limit). Dual of [`tropical_log_softmax`]
/// (iter-466) under the (max, +) / (min, +) semiring duality.
///
/// Behavior:
/// - Empty input → empty Vec.
/// - β ≤ 0 / non-finite → empty Vec (matches tropical_softmin).
/// - Non-finite `m` → vector of zeros (matches tropical_softmin).
///
/// Iter-472 — log-domain companion to [`tropical_softmin`]
/// (iter-370) and the LSE smooth-min [`tropical_smooth_min`]
/// (iter-352). Closes the (log_softmax, log_softmin) pair on the
/// tropical / (max, +)-(min, +) duality.
///
/// Source. Numerically stable log-softmax: Bridle, "Probabilistic
/// Interpretation of Feedforward Classification Network Outputs",
/// Neurocomputing (1990) §3. Semiring duality: Cuninghame-Green,
/// "Minimax Algebra", LNEMS 166 (1979) §1.2.
pub fn tropical_log_softmin(v: &[f64], beta: f64) -> Vec<f64> {
    if v.is_empty() || beta <= 0.0 || !beta.is_finite() {
        return Vec::new();
    }
    let m = min_plus_vector_min(v);
    if !m.is_finite() {
        return vec![0.0; v.len()];
    }
    let exp_sum: f64 = v.iter().map(|&x| (-beta * (x - m)).exp()).sum();
    let log_z = exp_sum.ln();
    v.iter().map(|&x| -beta * (x - m) - log_z).collect()
}

/// Shannon entropy of the tropical softmax distribution at
/// inverse-temperature `β`:
/// `H(softmax(v; β)) = − Σ_j p_j · ln(p_j)`, where
/// `p_j = exp(log_softmax_j(v; β))`.
///
/// Returns a single non-negative scalar in nats. Bounded in
/// `[0, ln(n)]`; equals `ln(n)` at the uniform distribution
/// (β → 0 limit) and 0 at the one-hot argmax (β → ∞ limit).
///
/// Computed in log-space directly from `tropical_log_softmax`
/// to stay numerically stable for skewed inputs.
///
/// Behavior:
/// - Empty input → 0.0.
/// - β ≤ 0 / non-finite → 0.0 (degenerate log-softmax path).
///
/// Iter-478 — calibration / uncertainty diagnostic on the
/// tropical side. Pairs with `tropical_softmax` (iter-364) and
/// `tropical_log_softmax` (iter-466). Cross-IR companion of
/// `apply_layer_softmax_entropy` (iter-467, Operator) and
/// `multivector_grade_entropy` (Geometry).
///
/// Source. Shannon entropy: Cover & Thomas, "Elements of
/// Information Theory" (2nd ed., 2006) §2.1 eq. (2.1). Softmax
/// as smooth-argmax distribution: Goodfellow/Bengio/Courville,
/// "Deep Learning" (MIT Press, 2016) §6.2.2.2.
pub fn tropical_softmax_entropy(v: &[f64], beta: f64) -> f64 {
    let log_p = tropical_log_softmax(v, beta);
    if log_p.is_empty() {
        return 0.0;
    }
    let mut h = 0.0_f64;
    for lp in log_p {
        let p = lp.exp();
        if p > 0.0 {
            h -= p * lp;
        }
    }
    h
}

/// Shannon entropy of the tropical softmin distribution at
/// inverse-temperature `β`:
/// `H(softmin(v; β)) = − Σ_j p_j · ln(p_j)`, where
/// `p_j = exp(log_softmin_j(v; β))`.
///
/// Returns a single non-negative scalar in nats. Bounded in
/// `[0, ln(n)]`; equals `ln(n)` at the uniform distribution
/// (β → 0 limit) and 0 at the one-hot argmin (β → ∞ limit).
///
/// Computed in log-space directly from `tropical_log_softmin`
/// (iter-472) to stay numerically stable for skewed inputs. Dual
/// of `tropical_softmax_entropy` (iter-478) under the (max, +) /
/// (min, +) semiring duality.
///
/// Behavior:
/// - Empty input → 0.0.
/// - β ≤ 0 / non-finite → 0.0 (degenerate log-softmin path).
///
/// Iter-484 — calibration / uncertainty diagnostic on the (min, +)
/// side. Pairs with `tropical_softmin` (iter-370),
/// `tropical_log_softmin` (iter-472), and `tropical_softmax_entropy`
/// (iter-478, dual under negation).
///
/// Source. Shannon entropy: Cover & Thomas, "Elements of
/// Information Theory" (2nd ed., 2006) §2.1 eq. (2.1). Semiring
/// duality: Cuninghame-Green, "Minimax Algebra", LNEMS 166 (1979)
/// §1.2.
pub fn tropical_softmin_entropy(v: &[f64], beta: f64) -> f64 {
    let log_p = tropical_log_softmin(v, beta);
    if log_p.is_empty() {
        return 0.0;
    }
    let mut h = 0.0_f64;
    for lp in log_p {
        let p = lp.exp();
        if p > 0.0 {
            h -= p * lp;
        }
    }
    h
}

/// KL divergence between two tropical softmax distributions at
/// shared inverse-temperature `β`:
/// `KL(softmax(p; β) ‖ softmax(q; β)) = Σ_j P_j · (log P_j − log Q_j)`,
/// where `P = softmax(p; β)`, `Q = softmax(q; β)`.
///
/// Computed in log-space directly from `tropical_log_softmax`
/// (iter-466) to stay numerically stable for skewed inputs.
/// Non-negative scalar; zero iff `softmax(p) ≡ softmax(q)` (which
/// holds iff `p` and `q` differ only by a constant shift — softmax
/// is shift-invariant).
///
/// Behavior:
/// - Empty / length-mismatched inputs → `None`.
/// - β ≤ 0 / non-finite → `Some(NaN)` via log_softmax sub-path.
///
/// Iter-490 — knowledge-distillation primitive on the tropical
/// side. Cross-IR companion of `apply_layer_softmax_kl_divergence`
/// (iter-473, Operator). Pairs with the tropical entropy /
/// JS / TV family for end-to-end soft-classification chains.
///
/// Source. Knowledge distillation via KL on softmax outputs:
/// Hinton, Vinyals, Dean, "Distilling the Knowledge in a Neural
/// Network", arXiv:1503.02531 (2015) §2. KL definition: Cover &
/// Thomas, "Elements of Information Theory" (2nd ed., 2006) §2.3.
pub fn tropical_softmax_kl_divergence(
    p: &[f64],
    q: &[f64],
    beta: f64,
) -> Option<f64> {
    if p.is_empty() || q.is_empty() || p.len() != q.len() {
        return None;
    }
    let log_pp = tropical_log_softmax(p, beta);
    let log_pq = tropical_log_softmax(q, beta);
    if log_pp.is_empty() || log_pq.is_empty() {
        return Some(f64::NAN);
    }
    let mut kl = 0.0_f64;
    for (lp, lq) in log_pp.iter().zip(log_pq.iter()) {
        let p = lp.exp();
        if p > 0.0 {
            kl += p * (lp - lq);
        }
    }
    Some(kl)
}

/// Cross-entropy between two tropical softmax distributions at
/// shared inverse-temperature `β`:
/// `CE(softmax(p; β), softmax(q; β)) = −Σ_j P_j · log Q_j`.
///
/// Computed in log-space directly from `tropical_log_softmax` to
/// avoid underflow on skewed coordinates. Satisfies the standard
/// identity `CE(P, Q) = H(P) + KL(P ‖ Q)`.
///
/// Behavior:
/// - Empty / length-mismatched inputs → `None`.
/// - β ≤ 0 / non-finite → `Some(NaN)` via log_softmax sub-path.
///
/// Iter-496 — supervised / distillation loss primitive on the
/// tropical side. Cross-IR companion of
/// `apply_layer_softmax_cross_entropy` (iter-491, Operator) and
/// `cross_entropy_from_probs` (Info).
///
/// Source. Cross-entropy decomposition: Cover & Thomas,
/// "Elements of Information Theory" (2nd ed., 2006) §2.3.
/// Softmax classifier loss: Goodfellow, Bengio, Courville,
/// "Deep Learning" (MIT Press, 2016) §6.2.2.3.
pub fn tropical_softmax_cross_entropy(
    p: &[f64],
    q: &[f64],
    beta: f64,
) -> Option<f64> {
    if p.is_empty() || q.is_empty() || p.len() != q.len() {
        return None;
    }
    let log_pp = tropical_log_softmax(p, beta);
    let log_pq = tropical_log_softmax(q, beta);
    if log_pp.is_empty() || log_pq.is_empty() {
        return Some(f64::NAN);
    }
    let mut ce = 0.0_f64;
    for (lp, lq) in log_pp.iter().zip(log_pq.iter()) {
        let p = lp.exp();
        if p > 0.0 {
            ce -= p * lq;
        }
    }
    Some(ce)
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

/// Constant-valued matrix: `rows × cols` matrix where every
/// entry equals `value`.
///
/// Semiring-neutral (same constructor for max-plus and min-plus).
/// `tropical_constant_matrix(n, m, NEG_INFINITY)` matches
/// `tropical_zero_matrix(n, m)`.
///
/// Iter-298 — generic initializer; useful for "shift A by c"
/// patterns via `tropical_matrix_max_pointwise(A, constant)`.
pub fn tropical_constant_matrix(rows: usize, cols: usize, value: f64) -> Vec<Vec<f64>> {
    (0..rows).map(|_| vec![value; cols]).collect()
}

/// Tropical scaled identity matrix: `c · I` in (max, +).
///
/// Returns an `n × n` matrix with `c` on the diagonal and
/// `NEG_INFINITY` (additive identity) elsewhere. `c = 0`
/// recovers the multiplicative identity
/// `tropical_identity_matrix(n)`.
///
/// Iter-310 — diagonal-scaling primitive companion to
/// `tropical_identity_matrix` and `tropical_zero_matrix`.
pub fn tropical_identity_matrix_scaled(n: usize, c: f64) -> Vec<Vec<f64>> {
    let mut m = tropical_zero_matrix(n, n);
    for i in 0..n {
        m[i][i] = c;
    }
    m
}

/// Tropical (max, +) zero matrix: `rows × cols` matrix of
/// `NEG_INFINITY` entries — the additive identity for
/// `tropical_matrix_max_pointwise`.
///
/// Returns an empty Vec if `rows == 0`.
///
/// Iter-292 — additive-identity constructor; pairs with
/// `tropical_identity_matrix` (multiplicative identity).
pub fn tropical_zero_matrix(rows: usize, cols: usize) -> Vec<Vec<f64>> {
    (0..rows).map(|_| vec![f64::NEG_INFINITY; cols]).collect()
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

/// Tropical partial Kleene closure: `A_k* = I ⊕ A ⊕ A² ⊕ … ⊕ Aᵏ`
/// in the (max, +) semiring.
///
/// The entry `(A_k*)_{i,j}` is the max-weight path from `i` to
/// `j` of length at most `k` (with path length 0 contributing
/// the identity diagonal). Naive O(k · n³) via repeated multiply
/// + entrywise max.
///
/// Returns `None` on non-square or ragged input. `k = 0` returns
/// the tropical identity matrix.
///
/// Iter-286 — finite-truncation of the Kleene closure A* used in
/// max-weight path algorithms. The full closure converges when
/// there are no positive-weight cycles (Cuninghame-Green
/// Cyclic Property); the partial version up to k always exists.
pub fn tropical_matrix_kleene_partial(a: &[Vec<f64>], k: usize) -> Option<Vec<Vec<f64>>> {
    if a.is_empty() {
        return None;
    }
    let n = a.len();
    for row in a {
        if row.len() != n {
            return None;
        }
    }
    let mut acc = tropical_identity_matrix(n);
    let mut power = tropical_identity_matrix(n);
    for _ in 1..=k {
        power = tropical_matrix_multiply(&power, a)?;
        acc = tropical_matrix_max_pointwise(&acc, &power)?;
    }
    Some(acc)
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

/// LSE-smoothed tropical (max, +) polynomial at `x`:
///
/// `p_β(x) = (1/β) · ln Σ_k exp(β · (a_k + k · x))`.
///
/// Numerically stable: shifts by the max of `(a_k + k·x)` before
/// exp. As `β → ∞`, converges to the sharp tropical polynomial
/// `max_k (a_k + k·x)`; as `β → 0`, approaches the arithmetic
/// mean of the affine lines plus `(ln n)/β`.
///
/// Empty coefficients yield `f64::NEG_INFINITY` (matches the
/// sharp form). `β ≤ 0` / non-finite → NaN.
///
/// Iter-454 — differentiable companion to [`tropical_polynomial`]
/// (iter-108). Extends the smooth-fold family (`smooth_max`,
/// `smooth_min`, `smooth_amplitude`, `smooth_inner_product`,
/// `smooth_chebyshev_distance`) to the upper-envelope-of-affine-
/// lines primitive that underlies tropical ReLU networks. Useful
/// as:
/// - Differentiable surrogate for `compile_relu_layer` outputs.
/// - Soft activation-piece selector for tropical-DP backtraces.
///
/// Source. LSE-smooth max applied to the affine-line family
/// `{a_k + k·x}_k`: Nielsen & Sun, Entropy 18(12):442 (2016) §2.
/// Tropical polynomial reference: Maclagan & Sturmfels,
/// "Introduction to Tropical Geometry", GSM 161 (2015) §1.1.
pub fn tropical_smooth_polynomial(coeffs: &[f64], x: f64, beta: f64) -> f64 {
    if coeffs.is_empty() {
        return f64::NEG_INFINITY;
    }
    if beta <= 0.0 || !beta.is_finite() {
        return f64::NAN;
    }
    let values: Vec<f64> = coeffs
        .iter()
        .enumerate()
        .map(|(k, &a)| a + (k as f64) * x)
        .collect();
    let m = values.iter().copied().fold(f64::NEG_INFINITY, f64::max);
    if !m.is_finite() {
        return m;
    }
    let sum: f64 = values.iter().map(|v| (beta * (v - m)).exp()).sum();
    m + sum.ln() / beta
}

/// Argmax index of a tropical (max, +) polynomial at `x`:
/// returns the integer `k` such that `a_k + k · x` is the
/// largest among the affine lines. Ties go to the lowest
/// index.
///
/// Returns `None` only on empty coefficient input.
///
/// This is the *slope of the active piece* at `x` — the
/// piecewise-linear convex polynomial's right-derivative at
/// `x` lies in the interval `[k_active, k_active + 1]` when
/// `x` is on the interior of a kink, but at the kinks
/// themselves the subgradient set includes multiple slopes.
/// The first-occurrence tie-break makes the function
/// deterministic.
///
/// Iter-382 — argmax companion to [`tropical_polynomial`]
/// (iter-108, value form). The (value, argmax) packed pair
/// gives the (value, active-piece-index) of the upper
/// envelope at a single x — useful for tropical-DP backtrace,
/// where the index identifies the action that achieves the
/// optimum.
///
/// Source. Active-piece / subgradient interpretation of
/// piecewise-linear convex polynomials: Rockafellar, "Convex
/// Analysis" (Princeton, 1970) §25. Tropical-DP backtrace:
/// Cuninghame-Green, "Minimax Algebra", LNEMS 166 (1979)
/// Ch. 4.
pub fn tropical_polynomial_argmax_at(coeffs: &[f64], x: f64) -> Option<usize> {
    if coeffs.is_empty() {
        return None;
    }
    let mut best_idx = 0_usize;
    let mut best_val = f64::NEG_INFINITY;
    for (k, &a) in coeffs.iter().enumerate() {
        let v = a + (k as f64) * x;
        if v > best_val {
            best_val = v;
            best_idx = k;
        }
    }
    Some(best_idx)
}

/// Packed (argmax index, value) of a tropical (max, +)
/// polynomial at `x`: returns `Some((k, a_k + k·x))` for the
/// active piece.
///
/// Single-pass companion to [`tropical_polynomial`] (value) and
/// [`tropical_polynomial_argmax_at`] (index). Empty input → None.
///
/// Iter-412 — closes the (value, index, packed) triple for the
/// (max, +) polynomial active piece. Useful in tropical-DP
/// backtrace pipelines where both the optimal index and the
/// optimal cost are consumed in the same step.
///
/// Source. Argmax-with-value packed pattern; cf. Rockafellar
/// "Convex Analysis" (1970) §25.
pub fn tropical_polynomial_argmax_value_at(
    coeffs: &[f64],
    x: f64,
) -> Option<(usize, f64)> {
    if coeffs.is_empty() {
        return None;
    }
    let mut best_idx = 0_usize;
    let mut best_val = f64::NEG_INFINITY;
    for (k, &a) in coeffs.iter().enumerate() {
        let v = a + (k as f64) * x;
        if v > best_val {
            best_val = v;
            best_idx = k;
        }
    }
    Some((best_idx, best_val))
}

/// Tropical (min, +) polynomial evaluation:
/// `p(x) = min_k (a_k + k · x)`.
///
/// The lower envelope of affine lines `y = a_k + k·x` — the
/// piecewise-linear *concave* function obtained from the
/// coefficient sequence under the (min, +) semiring. Dual of
/// [`tropical_polynomial`] (iter-108, upper envelope under
/// (max, +)).
///
/// Special cases:
/// - Empty coefficients: returns `f64::INFINITY` (the (min, +)
///   additive identity).
/// - Single coefficient `[a]`: returns `a`.
///
/// Iter-376 — closes the (max, min)-polynomial pair on
/// Tropical-IR. Useful for shortest-path / min-cost-of-arrival
/// formulations where the value function is the lower envelope
/// of action-conditional costs.
///
/// Source. (min, +) polynomials / lower envelope: Cuninghame-
/// Green, "Minimax Algebra", LNEMS 166 (1979) §1.3
/// (piecewise-linear function families); modern context:
/// Maclagan & Sturmfels, "Introduction to Tropical Geometry",
/// GSM 161 (2015) §1.1 (semiring duality between max/min
/// polynomial formalisms).
pub fn tropical_min_polynomial(coeffs: &[f64], x: f64) -> f64 {
    coeffs
        .iter()
        .enumerate()
        .map(|(k, &a)| a + (k as f64) * x)
        .fold(f64::INFINITY, f64::min)
}

/// LSE-smoothed tropical (min, +) polynomial at `x`:
///
/// `p_β^{min}(x) = −(1/β) · ln Σ_k exp(−β · (a_k + k · x))`.
///
/// Numerically stable: shifts by `min_k (a_k + k·x)` before exp.
/// As `β → ∞`, converges to the sharp lower envelope
/// `min_k (a_k + k·x)`; as `β → 0`, approaches the arithmetic
/// mean of the affine lines minus `(ln n)/β`.
///
/// Empty coefficients yield `f64::INFINITY` (matches the sharp
/// form). `β ≤ 0` / non-finite → NaN.
///
/// Iter-460 — differentiable companion to
/// [`tropical_min_polynomial`] (iter-?). Dual of
/// [`tropical_smooth_polynomial`] (iter-454, upper envelope under
/// (max, +)) — completes the smooth-envelope pair on the
/// piecewise-linear concave / convex polynomial primitives.
///
/// Source. LSE-smooth min via (max, +) / (min, +) duality:
/// Cuninghame-Green, "Minimax Algebra", LNEMS 166 (1979) §1.2
/// (semiring duality). LSE form: Nielsen & Sun, Entropy
/// 18(12):442 (2016) §2.
pub fn tropical_smooth_min_polynomial(coeffs: &[f64], x: f64, beta: f64) -> f64 {
    if coeffs.is_empty() {
        return f64::INFINITY;
    }
    if beta <= 0.0 || !beta.is_finite() {
        return f64::NAN;
    }
    let values: Vec<f64> = coeffs
        .iter()
        .enumerate()
        .map(|(k, &a)| a + (k as f64) * x)
        .collect();
    let m = values.iter().copied().fold(f64::INFINITY, f64::min);
    if !m.is_finite() {
        return m;
    }
    let sum: f64 = values.iter().map(|v| (-beta * (v - m)).exp()).sum();
    m - sum.ln() / beta
}

/// Argmin index of a tropical (min, +) polynomial at `x`:
/// returns the integer `k` such that `a_k + k · x` is the
/// smallest among the affine lines. Ties go to the lowest
/// index. Returns `None` on empty coefficient input.
///
/// The active-piece index of the lower-envelope concave
/// piecewise-linear function — the (min, +) dual of
/// [`tropical_polynomial_argmax_at`] (iter-382).
///
/// Iter-388 — closes the (max-argmax, min-argmin) polynomial-
/// argmax pair on Tropical-IR. Together with the value forms
/// (`tropical_polynomial` / `tropical_min_polynomial`), each
/// semiring exposes both (value, active-piece-index) for
/// tropical-DP backtrace in either direction.
///
/// Source. (min, +) active piece / subgradient interpretation:
/// dual of Rockafellar (1970) §25 under the (min, +) / (max, +)
/// semiring duality (Cuninghame-Green 1979 §1.2).
pub fn tropical_min_polynomial_argmin_at(coeffs: &[f64], x: f64) -> Option<usize> {
    if coeffs.is_empty() {
        return None;
    }
    let mut best_idx = 0_usize;
    let mut best_val = f64::INFINITY;
    for (k, &a) in coeffs.iter().enumerate() {
        let v = a + (k as f64) * x;
        if v < best_val {
            best_val = v;
            best_idx = k;
        }
    }
    Some(best_idx)
}

/// Packed (argmin index, value) of a tropical (min, +)
/// polynomial at `x`: returns `Some((k, a_k + k·x))` for the
/// active piece. Empty → None.
///
/// Iter-418 — dual of [`tropical_polynomial_argmax_value_at`]
/// (iter-412). Closes the (max, +)/(min, +) packed-(value,
/// index) symmetry on the polynomial side.
///
/// Source. Argmin-with-value packed pattern; semiring duality:
/// Cuninghame-Green, "Minimax Algebra", LNEMS 166 (1979) §1.2.
pub fn tropical_min_polynomial_argmin_value_at(
    coeffs: &[f64],
    x: f64,
) -> Option<(usize, f64)> {
    if coeffs.is_empty() {
        return None;
    }
    let mut best_idx = 0_usize;
    let mut best_val = f64::INFINITY;
    for (k, &a) in coeffs.iter().enumerate() {
        let v = a + (k as f64) * x;
        if v < best_val {
            best_val = v;
            best_idx = k;
        }
    }
    Some((best_idx, best_val))
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

    // ── iter-274: min_plus_matrix_col_min ─────────────────────────

    #[test]
    fn matrix_col_min_basic() {
        let a = vec![vec![1.0, 5.0, 3.0], vec![4.0, 2.0, 6.0]];
        let cm = min_plus_matrix_col_min(&a).unwrap();
        assert_eq!(cm, vec![1.0, 2.0, 3.0]);
    }

    #[test]
    fn matrix_col_min_empty_is_empty() {
        let a: Vec<Vec<f64>> = vec![];
        assert!(min_plus_matrix_col_min(&a).unwrap().is_empty());
    }

    #[test]
    fn matrix_col_min_ragged_rejected() {
        let a = vec![vec![1.0, 2.0], vec![3.0]];
        assert!(min_plus_matrix_col_min(&a).is_none());
    }

    #[test]
    fn matrix_col_min_transpose_equals_row_min() {
        let a = vec![vec![1.0, 5.0, 3.0], vec![4.0, 2.0, 6.0]];
        let cm = min_plus_matrix_col_min(&a).unwrap();
        let at = tropical_matrix_transpose(&a).unwrap();
        let rm = min_plus_matrix_row_min(&at);
        assert_eq!(cm, rm);
    }

    // ── iter-268: min_plus_matrix_row_min ─────────────────────────

    #[test]
    fn matrix_row_min_basic() {
        let a = vec![vec![1.0, 5.0, 3.0], vec![4.0, 2.0, 6.0]];
        assert_eq!(min_plus_matrix_row_min(&a), vec![1.0, 2.0]);
    }

    #[test]
    fn matrix_row_min_empty_input_is_empty() {
        let a: Vec<Vec<f64>> = vec![];
        assert!(min_plus_matrix_row_min(&a).is_empty());
    }

    #[test]
    fn matrix_row_min_empty_row_is_infinity() {
        let a = vec![vec![1.0, 2.0], vec![]];
        let r = min_plus_matrix_row_min(&a);
        assert_eq!(r[0], 1.0);
        assert!(r[1].is_infinite());
    }

    #[test]
    fn matrix_row_min_min_of_min_equals_overall_min() {
        let a = vec![vec![1.0, 5.0], vec![3.0, 2.0]];
        let rows = min_plus_matrix_row_min(&a);
        let overall = min_plus_vector_min(&rows);
        let direct = min_plus_matrix_min_fold(&a);
        assert!((overall - direct).abs() < 1e-12);
    }

    // ── iter-262: min_plus_matrix_min_fold ────────────────────────

    #[test]
    fn matrix_min_fold_basic() {
        let a = vec![vec![1.0, 5.0], vec![3.0, 2.0]];
        assert_eq!(min_plus_matrix_min_fold(&a), 1.0);
    }

    #[test]
    fn matrix_min_fold_empty_is_infinity() {
        let a: Vec<Vec<f64>> = vec![];
        assert!(min_plus_matrix_min_fold(&a).is_infinite());
        assert!(min_plus_matrix_min_fold(&a) > 0.0);
    }

    #[test]
    fn matrix_min_fold_all_positive() {
        let a = vec![vec![3.0, 1.0], vec![7.0, 5.0]];
        assert_eq!(min_plus_matrix_min_fold(&a), 1.0);
    }

    #[test]
    fn matrix_min_fold_dual_of_max_via_negation() {
        let a = vec![vec![1.0, 5.0], vec![3.0, 2.0]];
        let neg = tropical_matrix_negate(&a);
        let mn = min_plus_matrix_min_fold(&a);
        let mx = tropical_matrix_max_fold(&neg);
        assert!((mn + mx).abs() < 1e-12);
    }

    // ── iter-256: tropical_matrix_col_max ─────────────────────────

    #[test]
    fn matrix_col_max_basic() {
        let a = vec![vec![1.0, 5.0, 3.0], vec![4.0, 2.0, 6.0]];
        let cm = tropical_matrix_col_max(&a).unwrap();
        assert_eq!(cm, vec![4.0, 5.0, 6.0]);
    }

    #[test]
    fn matrix_col_max_empty_is_empty() {
        let a: Vec<Vec<f64>> = vec![];
        assert!(tropical_matrix_col_max(&a).unwrap().is_empty());
    }

    #[test]
    fn matrix_col_max_ragged_rejected() {
        let a = vec![vec![1.0, 2.0], vec![3.0]];
        assert!(tropical_matrix_col_max(&a).is_none());
    }

    #[test]
    fn matrix_col_max_transpose_equals_row_max() {
        // col_max(A) = row_max(Aᵀ).
        let a = vec![vec![1.0, 5.0, 3.0], vec![4.0, 2.0, 6.0]];
        let cm = tropical_matrix_col_max(&a).unwrap();
        let at = tropical_matrix_transpose(&a).unwrap();
        let rm = tropical_matrix_row_max(&at);
        assert_eq!(cm, rm);
    }

    // ── iter-250: tropical_matrix_row_max ─────────────────────────

    #[test]
    fn matrix_row_max_basic() {
        let a = vec![vec![1.0, 5.0, 3.0], vec![4.0, 2.0, 6.0]];
        assert_eq!(tropical_matrix_row_max(&a), vec![5.0, 6.0]);
    }

    #[test]
    fn matrix_row_max_empty_input_is_empty() {
        let a: Vec<Vec<f64>> = vec![];
        assert!(tropical_matrix_row_max(&a).is_empty());
    }

    #[test]
    fn matrix_row_max_empty_row_is_neg_infinity() {
        let a = vec![vec![1.0, 2.0], vec![]];
        let r = tropical_matrix_row_max(&a);
        assert_eq!(r[0], 2.0);
        assert!(r[1].is_infinite() && r[1] < 0.0);
    }

    #[test]
    fn matrix_row_max_fold_matches_overall_max() {
        // max over rows of row-max == overall max.
        let a = vec![vec![1.0, 5.0], vec![3.0, 2.0]];
        let rows = tropical_matrix_row_max(&a);
        let overall = tropical_vector_max(&rows);
        let direct = tropical_matrix_max_fold(&a);
        assert!((overall - direct).abs() < 1e-12);
    }

    // ── iter-304: tropical_vector_negate ──────────────────────────

    #[test]
    fn vector_negate_basic() {
        assert_eq!(tropical_vector_negate(&[1.0, -2.0, 3.0]), vec![-1.0, 2.0, -3.0]);
    }

    #[test]
    fn vector_negate_involution() {
        let v = vec![1.0, -2.0, 3.0];
        let nn = tropical_vector_negate(&tropical_vector_negate(&v));
        assert_eq!(nn, v);
    }

    #[test]
    fn vector_negate_max_becomes_min() {
        // -max(v) = min(-v).
        let v = vec![1.0, 5.0, 3.0];
        let lhs = -tropical_vector_max(&v);
        let rhs = min_plus_vector_min(&tropical_vector_negate(&v));
        assert!((lhs - rhs).abs() < 1e-12);
    }

    #[test]
    fn vector_negate_empty_is_empty() {
        let v: Vec<f64> = vec![];
        assert!(tropical_vector_negate(&v).is_empty());
    }

    // ── iter-244: tropical_matrix_negate ──────────────────────────

    #[test]
    fn matrix_negate_basic() {
        let a = vec![vec![1.0, -2.0], vec![3.0, 0.0]];
        let neg = tropical_matrix_negate(&a);
        assert_eq!(neg, vec![vec![-1.0, 2.0], vec![-3.0, 0.0]]);
    }

    #[test]
    fn matrix_negate_involution() {
        let a = vec![vec![1.0, -2.0], vec![3.0, 0.0]];
        let nn = tropical_matrix_negate(&tropical_matrix_negate(&a));
        assert_eq!(nn, a);
    }

    #[test]
    fn matrix_negate_empty_is_empty() {
        let a: Vec<Vec<f64>> = vec![];
        assert!(tropical_matrix_negate(&a).is_empty());
    }

    #[test]
    fn matrix_negate_max_becomes_min_on_negation() {
        // tropical_matrix_max_fold(A) = -min_plus_vector_min(flat(-A)).
        let a = vec![vec![1.0, 5.0], vec![3.0, 2.0]];
        let mx = tropical_matrix_max_fold(&a);
        let neg = tropical_matrix_negate(&a);
        let flat_neg: Vec<f64> = neg.iter().flatten().copied().collect();
        let mn_neg = min_plus_vector_min(&flat_neg);
        assert!((mx + mn_neg).abs() < 1e-12);
    }

    // ── iter-238: tropical_matrix_max_fold ────────────────────────

    #[test]
    fn matrix_max_fold_basic() {
        let a = vec![vec![1.0, 5.0], vec![3.0, 2.0]];
        assert_eq!(tropical_matrix_max_fold(&a), 5.0);
    }

    #[test]
    fn matrix_max_fold_empty_is_neg_infinity() {
        let a: Vec<Vec<f64>> = vec![];
        assert!(tropical_matrix_max_fold(&a).is_infinite());
        assert!(tropical_matrix_max_fold(&a) < 0.0);
    }

    #[test]
    fn matrix_max_fold_all_negative() {
        let a = vec![vec![-3.0, -1.0], vec![-7.0, -2.0]];
        assert_eq!(tropical_matrix_max_fold(&a), -1.0);
    }

    #[test]
    fn matrix_max_fold_equals_vector_max_of_flattened() {
        let a = vec![vec![1.0, 5.0], vec![3.0, 2.0]];
        let flat: Vec<f64> = a.iter().flatten().copied().collect();
        assert!((tropical_matrix_max_fold(&a) - tropical_vector_max(&flat)).abs() < 1e-12);
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

    // ── iter-316: tropical_vector_argmax_value ────────────────────

    #[test]
    fn vector_argmax_value_basic() {
        let r = tropical_vector_argmax_value(&[1.0, 5.0, 3.0, 5.0]);
        // First occurrence of max wins.
        assert_eq!(r, Some((1, 5.0)));
    }

    #[test]
    fn vector_argmax_value_empty_is_none() {
        assert!(tropical_vector_argmax_value(&[]).is_none());
    }

    #[test]
    fn vector_argmax_value_singleton() {
        assert_eq!(tropical_vector_argmax_value(&[42.0]), Some((0, 42.0)));
    }

    #[test]
    fn vector_argmax_value_matches_max_and_argmax_idx() {
        let v = vec![1.0, 5.0, 3.0, 2.0];
        let (idx, val) = tropical_vector_argmax_value(&v).unwrap();
        let direct_idx = tropical_argmax_idx(&v).unwrap();
        let direct_val = tropical_vector_max(&v);
        assert_eq!(idx, direct_idx);
        assert_eq!(val, direct_val);
    }

    // ── iter-322: min_plus_vector_argmin_value ────────────────────

    #[test]
    fn vector_argmin_value_basic() {
        // First occurrence of min wins.
        let r = min_plus_vector_argmin_value(&[5.0, 1.0, 3.0, 1.0]);
        assert_eq!(r, Some((1, 1.0)));
    }

    #[test]
    fn vector_argmin_value_empty_is_none() {
        assert!(min_plus_vector_argmin_value(&[]).is_none());
    }

    #[test]
    fn vector_argmin_value_singleton() {
        assert_eq!(min_plus_vector_argmin_value(&[42.0]), Some((0, 42.0)));
    }

    #[test]
    fn vector_argmin_value_matches_min_and_argmin_idx() {
        let v = vec![5.0, 1.0, 3.0, 2.0];
        let (idx, val) = min_plus_vector_argmin_value(&v).unwrap();
        let direct_idx = tropical_argmin_idx(&v).unwrap();
        let direct_val = min_plus_vector_min(&v);
        assert_eq!(idx, direct_idx);
        assert_eq!(val, direct_val);
    }

    #[test]
    fn vector_argmin_value_dual_to_argmax_value_under_negation() {
        // arg min v = arg max (−v); min v = −max(−v). Verifies the
        // (min, +)/(max, +) semiring duality.
        let v = vec![3.0, 1.0, 5.0, 2.0, -1.0, 4.0];
        let neg: Vec<f64> = v.iter().map(|x| -*x).collect();
        let (min_idx, min_val) = min_plus_vector_argmin_value(&v).unwrap();
        let (max_idx, max_val) = tropical_vector_argmax_value(&neg).unwrap();
        assert_eq!(min_idx, max_idx);
        assert!((min_val + max_val).abs() < 1e-12);
    }

    // ── iter-328: tropical_vector_min_max_pair ────────────────────

    #[test]
    fn min_max_pair_basic() {
        let r = tropical_vector_min_max_pair(&[3.0, 1.0, 4.0, 1.0, 5.0, 9.0, 2.0]);
        assert_eq!(r, Some((1.0, 9.0)));
    }

    #[test]
    fn min_max_pair_empty_is_none() {
        assert!(tropical_vector_min_max_pair(&[]).is_none());
    }

    #[test]
    fn min_max_pair_singleton() {
        assert_eq!(tropical_vector_min_max_pair(&[42.0]), Some((42.0, 42.0)));
    }

    #[test]
    fn min_max_pair_matches_separate_folds() {
        let v = vec![-3.0, 7.0, 2.0, -1.0, 5.0];
        let (lo, hi) = tropical_vector_min_max_pair(&v).unwrap();
        assert_eq!(lo, min_plus_vector_min(&v));
        assert_eq!(hi, tropical_vector_max(&v));
    }

    #[test]
    fn min_max_pair_amplitude_is_nonneg() {
        // Tropical amplitude max - min ≥ 0 on every non-empty vector.
        let v = vec![-3.0, 7.0, 2.0, -1.0, 5.0];
        let (lo, hi) = tropical_vector_min_max_pair(&v).unwrap();
        assert!(hi - lo >= -1e-12);
    }

    // ── iter-334: tropical_pairwise_max / min_plus_pairwise_min ───

    #[test]
    fn pairwise_max_basic() {
        let r = tropical_pairwise_max(&[1.0, 5.0, 3.0], &[4.0, 2.0, 3.0]).unwrap();
        assert_eq!(r, vec![4.0, 5.0, 3.0]);
    }

    #[test]
    fn pairwise_min_basic() {
        let r = min_plus_pairwise_min(&[1.0, 5.0, 3.0], &[4.0, 2.0, 3.0]).unwrap();
        assert_eq!(r, vec![1.0, 2.0, 3.0]);
    }

    #[test]
    fn pairwise_length_mismatch_is_none() {
        assert!(tropical_pairwise_max(&[1.0, 2.0], &[1.0, 2.0, 3.0]).is_none());
        assert!(min_plus_pairwise_min(&[1.0, 2.0, 3.0], &[1.0, 2.0]).is_none());
    }

    #[test]
    fn pairwise_empty_returns_empty_vec() {
        assert_eq!(tropical_pairwise_max(&[], &[]).unwrap(), Vec::<f64>::new());
        assert_eq!(min_plus_pairwise_min(&[], &[]).unwrap(), Vec::<f64>::new());
    }

    #[test]
    fn pairwise_max_min_with_negation_are_dual() {
        // pairwise_min(a, b) = -pairwise_max(-a, -b) (semiring duality).
        let a = vec![1.0, 5.0, -2.0, 3.0];
        let b = vec![4.0, 2.0, -1.0, 3.0];
        let neg_a: Vec<f64> = a.iter().map(|x| -x).collect();
        let neg_b: Vec<f64> = b.iter().map(|x| -x).collect();
        let mn = min_plus_pairwise_min(&a, &b).unwrap();
        let mx = tropical_pairwise_max(&neg_a, &neg_b).unwrap();
        for i in 0..a.len() {
            assert!((mn[i] + mx[i]).abs() < 1e-12);
        }
    }

    // ── iter-340: tropical_vector_scalar_max / min_plus_..._min ───

    #[test]
    fn vector_scalar_max_basic() {
        let r = tropical_vector_scalar_max(&[-1.0, 3.0, 0.5, -2.0], 0.0);
        assert_eq!(r, vec![0.0, 3.0, 0.5, 0.0]);
    }

    #[test]
    fn vector_scalar_max_is_relu_at_zero() {
        // Canonical interpretation: max(·, 0) ≡ ReLU element-wise.
        let v = vec![-3.0, 2.5, -0.1, 0.0, 4.0];
        let relu = tropical_vector_scalar_max(&v, 0.0);
        for (xi, ri) in v.iter().zip(relu.iter()) {
            assert_eq!(*ri, xi.max(0.0));
        }
    }

    #[test]
    fn vector_scalar_min_basic() {
        let r = min_plus_vector_scalar_min(&[1.0, -3.0, 0.5, 5.0], 0.0);
        assert_eq!(r, vec![0.0, -3.0, 0.0, 0.0]);
    }

    #[test]
    fn vector_scalar_max_min_negation_duality() {
        // scalar_min(v, c) = -scalar_max(-v, -c) (semiring duality).
        let v = vec![-1.0, 3.0, 0.5, -2.0, 4.0];
        let c = 0.5_f64;
        let mn = min_plus_vector_scalar_min(&v, c);
        let neg_v: Vec<f64> = v.iter().map(|x| -x).collect();
        let mx = tropical_vector_scalar_max(&neg_v, -c);
        for (m, mx_) in mn.iter().zip(mx.iter()) {
            assert!((m + mx_).abs() < 1e-12);
        }
    }

    #[test]
    fn vector_scalar_max_empty_returns_empty() {
        let r = tropical_vector_scalar_max(&[], 5.0);
        assert!(r.is_empty());
    }

    // ── iter-346: tropical_smooth_max ─────────────────────────────

    #[test]
    fn smooth_max_empty_is_neg_infinity() {
        assert!(tropical_smooth_max(&[], 1.0).is_infinite());
        assert!(tropical_smooth_max(&[], 1.0) < 0.0);
    }

    #[test]
    fn smooth_max_high_beta_approaches_max() {
        let v = vec![1.0, 5.0, 3.0, 2.0];
        let sharp = tropical_vector_max(&v);
        let smooth = tropical_smooth_max(&v, 100.0);
        assert!((smooth - sharp).abs() < 1e-2);
    }

    #[test]
    fn smooth_max_singleton_equals_value() {
        let s = tropical_smooth_max(&[3.5], 1.0);
        assert!((s - 3.5).abs() < 1e-12);
    }

    #[test]
    fn smooth_max_low_beta_grows_above_sharp_max() {
        // LSE_β ≥ max always, with equality only in the β → ∞ limit.
        let v = vec![1.0, 1.0, 1.0, 1.0];
        let sharp = tropical_vector_max(&v);
        let smooth = tropical_smooth_max(&v, 0.5);
        // For uniform v all = 1: LSE_β = 1 + ln(4)/0.5 = 1 + 2ln(4) ≈ 3.773.
        let expected = 1.0 + 4.0_f64.ln() / 0.5;
        assert!((smooth - expected).abs() < 1e-9);
        assert!(smooth >= sharp - 1e-12);
    }

    #[test]
    fn smooth_max_invalid_beta_is_nan() {
        assert!(tropical_smooth_max(&[1.0, 2.0], 0.0).is_nan());
        assert!(tropical_smooth_max(&[1.0, 2.0], -1.0).is_nan());
    }

    // ── iter-352: tropical_smooth_min ─────────────────────────────

    #[test]
    fn smooth_min_empty_is_infinity() {
        assert!(tropical_smooth_min(&[], 1.0).is_infinite());
        assert!(tropical_smooth_min(&[], 1.0) > 0.0);
    }

    #[test]
    fn smooth_min_high_beta_approaches_sharp_min() {
        let v = vec![1.0, 5.0, 3.0, 2.0];
        let sharp = min_plus_vector_min(&v);
        let smooth = tropical_smooth_min(&v, 100.0);
        assert!((smooth - sharp).abs() < 1e-2);
    }

    #[test]
    fn smooth_min_singleton_equals_value() {
        let s = tropical_smooth_min(&[3.5], 1.0);
        assert!((s - 3.5).abs() < 1e-12);
    }

    #[test]
    fn smooth_min_dual_to_smooth_max_under_negation() {
        // tropical_smooth_min(v, β) = −tropical_smooth_max(−v, β).
        let v = vec![1.0, 5.0, 3.0, 2.0, -1.0];
        let neg: Vec<f64> = v.iter().map(|x| -x).collect();
        let sm = tropical_smooth_min(&v, 1.5);
        let sx = tropical_smooth_max(&neg, 1.5);
        assert!((sm + sx).abs() < 1e-12);
    }

    #[test]
    fn smooth_min_low_beta_falls_below_sharp_min() {
        // LSE_β^{min} ≤ min always, with equality only at β → ∞.
        let v = vec![1.0, 1.0, 1.0, 1.0];
        let sharp = min_plus_vector_min(&v);
        let smooth = tropical_smooth_min(&v, 0.5);
        // For uniform v all = 1: 1 - ln(4)/0.5 ≈ -1.773.
        let expected = 1.0 - 4.0_f64.ln() / 0.5;
        assert!((smooth - expected).abs() < 1e-9);
        assert!(smooth <= sharp + 1e-12);
    }

    #[test]
    fn smooth_min_invalid_beta_is_nan() {
        assert!(tropical_smooth_min(&[1.0, 2.0], 0.0).is_nan());
        assert!(tropical_smooth_min(&[1.0, 2.0], -1.0).is_nan());
    }

    // ── iter-436: tropical_smooth_amplitude ───────────────────────

    #[test]
    fn smooth_amplitude_empty_is_none() {
        assert!(tropical_smooth_amplitude(&[], 1.0).is_none());
    }

    #[test]
    fn smooth_amplitude_high_beta_approaches_sharp_amplitude() {
        let v = vec![1.0, 5.0, 3.0, 2.0, -1.0];
        let sharp = tropical_vector_amplitude(&v).unwrap();
        let smooth = tropical_smooth_amplitude(&v, 100.0).unwrap();
        assert!((smooth - sharp).abs() < 1e-2);
    }

    #[test]
    fn smooth_amplitude_singleton_is_zero() {
        // For a single coordinate, smooth_max = smooth_min = the value
        // → amplitude = 0.
        let a = tropical_smooth_amplitude(&[3.5], 1.0).unwrap();
        assert!(a.abs() < 1e-12);
    }

    #[test]
    fn smooth_amplitude_matches_smooth_max_minus_smooth_min() {
        // Defining identity for the smooth-amplitude primitive.
        let v = vec![1.0, 5.0, 3.0, 2.0, -1.0];
        let a = tropical_smooth_amplitude(&v, 1.5).unwrap();
        let expected = tropical_smooth_max(&v, 1.5) - tropical_smooth_min(&v, 1.5);
        assert!((a - expected).abs() < 1e-12);
    }

    #[test]
    fn smooth_amplitude_invalid_beta_propagates_nan() {
        let r = tropical_smooth_amplitude(&[1.0, 2.0], 0.0).unwrap();
        assert!(r.is_nan());
        let r2 = tropical_smooth_amplitude(&[1.0, 2.0], -1.0).unwrap();
        assert!(r2.is_nan());
    }

    // ── iter-442: tropical_smooth_inner_product ───────────────────

    #[test]
    fn smooth_inner_product_empty_is_none() {
        assert!(tropical_smooth_inner_product(&[], &[], 1.0).is_none());
    }

    #[test]
    fn smooth_inner_product_length_mismatch_is_none() {
        assert!(tropical_smooth_inner_product(&[1.0, 2.0], &[1.0], 1.0).is_none());
    }

    #[test]
    fn smooth_inner_product_high_beta_approaches_sharp() {
        let a = vec![1.0, -1.0, 2.0, 0.5];
        let b = vec![0.5, 3.0, -0.25, 1.0];
        let sharp = tropical_inner_product(&a, &b);
        let smooth = tropical_smooth_inner_product(&a, &b, 100.0).unwrap();
        assert!((smooth - sharp).abs() < 1e-2);
    }

    #[test]
    fn smooth_inner_product_invalid_beta_propagates_nan() {
        let r = tropical_smooth_inner_product(&[1.0, 2.0], &[3.0, 4.0], 0.0).unwrap();
        assert!(r.is_nan());
        let r2 = tropical_smooth_inner_product(&[1.0, 2.0], &[3.0, 4.0], -1.0).unwrap();
        assert!(r2.is_nan());
    }

    #[test]
    fn smooth_inner_product_singleton_equals_sum() {
        // For length-1 vectors, smooth_inner_product = a[0] + b[0].
        let r = tropical_smooth_inner_product(&[2.0], &[3.5], 1.0).unwrap();
        assert!((r - 5.5).abs() < 1e-12);
    }

    #[test]
    fn smooth_inner_product_bounded_below_by_sharp() {
        // LSE_β over the (a_i + b_i) sequence ≥ max_i (a_i + b_i)
        // for any finite β > 0 (LSE has positive bias).
        let a = vec![1.0, -1.0, 2.0, 0.5];
        let b = vec![0.5, 3.0, -0.25, 1.0];
        let sharp = tropical_inner_product(&a, &b);
        let smooth = tropical_smooth_inner_product(&a, &b, 0.5).unwrap();
        assert!(smooth + 1e-12 >= sharp);
    }

    // ── iter-448: tropical_smooth_chebyshev_distance ──────────────

    #[test]
    fn smooth_chebyshev_distance_length_mismatch_is_none() {
        assert!(
            tropical_smooth_chebyshev_distance(&[1.0, 2.0], &[1.0, 2.0, 3.0], 1.0).is_none()
        );
    }

    #[test]
    fn smooth_chebyshev_distance_empty_is_zero() {
        assert_eq!(
            tropical_smooth_chebyshev_distance(&[], &[], 1.0),
            Some(0.0)
        );
    }

    #[test]
    fn smooth_chebyshev_distance_self_high_beta_approaches_zero() {
        // |a − a| = 0, so smooth Chebyshev = ln(n)/β → 0 as β → ∞.
        let v = vec![1.0, 2.0, 3.0, 4.0];
        let d = tropical_smooth_chebyshev_distance(&v, &v, 1000.0).unwrap();
        assert!(d.abs() < 1e-2);
    }

    #[test]
    fn smooth_chebyshev_distance_high_beta_approaches_sharp() {
        let a = vec![1.0, 5.0, 3.0];
        let b = vec![4.0, 1.0, 7.0];
        let sharp = tropical_chebyshev_distance(&a, &b).unwrap();
        let smooth = tropical_smooth_chebyshev_distance(&a, &b, 100.0).unwrap();
        assert!((smooth - sharp).abs() < 1e-2);
    }

    #[test]
    fn smooth_chebyshev_distance_invalid_beta_propagates_nan() {
        let r = tropical_smooth_chebyshev_distance(&[1.0], &[0.0], 0.0).unwrap();
        assert!(r.is_nan());
    }

    #[test]
    fn smooth_chebyshev_distance_bounded_below_by_sharp() {
        // LSE positive bias ⇒ smooth ≥ sharp (over the non-negative |·|).
        let a = vec![1.0, 5.0, 3.0];
        let b = vec![4.0, 1.0, 7.0];
        let sharp = tropical_chebyshev_distance(&a, &b).unwrap();
        let smooth = tropical_smooth_chebyshev_distance(&a, &b, 0.5).unwrap();
        assert!(smooth + 1e-12 >= sharp);
    }

    // ── iter-358: tropical_vector_pairwise_add ────────────────────

    #[test]
    fn pairwise_add_basic() {
        let r = tropical_vector_pairwise_add(&[1.0, 2.0, 3.0], &[4.0, 5.0, 6.0]).unwrap();
        assert_eq!(r, vec![5.0, 7.0, 9.0]);
    }

    #[test]
    fn pairwise_add_length_mismatch_is_none() {
        assert!(tropical_vector_pairwise_add(&[1.0, 2.0], &[1.0, 2.0, 3.0]).is_none());
    }

    #[test]
    fn pairwise_add_empty_returns_empty() {
        assert_eq!(
            tropical_vector_pairwise_add(&[], &[]).unwrap(),
            Vec::<f64>::new()
        );
    }

    #[test]
    fn pairwise_add_with_zero_vec_is_identity() {
        // In (max, +) / (min, +), the multiplicative identity is 0
        // (scalar additive zero).
        let v = vec![1.0, -2.5, 3.0, 0.0];
        let zeros = vec![0.0; v.len()];
        let r = tropical_vector_pairwise_add(&v, &zeros).unwrap();
        assert_eq!(r, v);
    }

    #[test]
    fn pairwise_add_distributive_over_pairwise_max_on_nonneg_shift() {
        // (a + c) ⊕ (b + c) = (a ⊕ b) + c for scalar c — verified
        // component-wise via vector shift.
        let a = vec![1.0, 5.0, 3.0];
        let b = vec![4.0, 2.0, 6.0];
        let c = vec![2.0, 2.0, 2.0];
        let lhs_max = tropical_pairwise_max(
            &tropical_vector_pairwise_add(&a, &c).unwrap(),
            &tropical_vector_pairwise_add(&b, &c).unwrap(),
        )
        .unwrap();
        let rhs_max = tropical_vector_pairwise_add(
            &tropical_pairwise_max(&a, &b).unwrap(),
            &c,
        )
        .unwrap();
        assert_eq!(lhs_max, rhs_max);
    }

    // ── iter-364: tropical_softmax ────────────────────────────────

    #[test]
    fn softmax_sums_to_one_on_valid_input() {
        let w = tropical_softmax(&[1.0, 2.0, 3.0, 4.0], 1.0);
        let s: f64 = w.iter().sum();
        assert!((s - 1.0).abs() < 1e-12);
    }

    #[test]
    fn softmax_high_beta_concentrates_on_argmax() {
        // β = 50: nearly delta at index 1.
        let w = tropical_softmax(&[1.0, 5.0, 2.0, 3.0], 50.0);
        assert!(w[1] > 0.99, "w_argmax = {} should be near 1", w[1]);
        for (i, wi) in w.iter().enumerate() {
            if i != 1 {
                assert!(*wi < 0.01, "w_{} = {} should be near 0", i, wi);
            }
        }
    }

    #[test]
    fn softmax_uniform_input_is_uniform_distribution() {
        let n = 5_usize;
        let v = vec![3.0; n];
        let w = tropical_softmax(&v, 2.0);
        for wi in w {
            assert!((wi - 1.0 / n as f64).abs() < 1e-12);
        }
    }

    #[test]
    fn softmax_empty_or_invalid_beta_returns_empty() {
        assert!(tropical_softmax(&[], 1.0).is_empty());
        assert!(tropical_softmax(&[1.0, 2.0], 0.0).is_empty());
        assert!(tropical_softmax(&[1.0, 2.0], -1.0).is_empty());
    }

    #[test]
    fn softmax_nonnegative_entries() {
        let w = tropical_softmax(&[-2.0, 1.0, 3.0, -1.0, 0.5], 0.7);
        for &wi in &w {
            assert!(wi >= 0.0, "negative softmax entry: {}", wi);
        }
    }

    // ── iter-466: tropical_log_softmax ────────────────────────────

    #[test]
    fn log_softmax_exp_matches_softmax() {
        // exp(log_softmax(v)) ≡ softmax(v, β).
        let v = vec![1.0, 2.0, 3.0, 4.0];
        let beta = 1.5_f64;
        let log_w = tropical_log_softmax(&v, beta);
        let w = tropical_softmax(&v, beta);
        assert_eq!(log_w.len(), w.len());
        for (lw, w) in log_w.iter().zip(w.iter()) {
            assert!((lw.exp() - w).abs() < 1e-12);
        }
    }

    #[test]
    fn log_softmax_sums_to_zero_in_exp_domain() {
        // Σ exp(log_softmax) = Σ softmax = 1.
        let log_w = tropical_log_softmax(&[1.0, 2.0, 3.0], 1.0);
        let s: f64 = log_w.iter().map(|x| x.exp()).sum();
        assert!((s - 1.0).abs() < 1e-12);
    }

    #[test]
    fn log_softmax_high_beta_argmax_approaches_zero() {
        // β = 50 ⇒ exp(log_softmax_argmax) ≈ 1 ⇒ log_softmax_argmax ≈ 0;
        // other entries are very negative.
        let log_w = tropical_log_softmax(&[1.0, 5.0, 2.0, 3.0], 50.0);
        assert!(log_w[1].abs() < 0.01);
        for (i, lwi) in log_w.iter().enumerate() {
            if i != 1 {
                assert!(*lwi < -10.0);
            }
        }
    }

    #[test]
    fn log_softmax_uniform_input_is_minus_ln_n() {
        // For v all equal, log_softmax_i = −ln(n).
        let n = 5_usize;
        let v = vec![3.0_f64; n];
        let log_w = tropical_log_softmax(&v, 2.0);
        let expected = -((n as f64).ln());
        for lw in log_w {
            assert!((lw - expected).abs() < 1e-12);
        }
    }

    #[test]
    fn log_softmax_empty_or_invalid_beta_returns_empty() {
        assert!(tropical_log_softmax(&[], 1.0).is_empty());
        assert!(tropical_log_softmax(&[1.0, 2.0], 0.0).is_empty());
        assert!(tropical_log_softmax(&[1.0, 2.0], -1.0).is_empty());
    }

    #[test]
    fn log_softmax_nonpositive_entries() {
        // Every entry ≤ 0 (since exp(entry) ≤ 1 with sum 1).
        let log_w = tropical_log_softmax(&[-2.0, 1.0, 3.0, -1.0, 0.5], 0.7);
        for &lwi in &log_w {
            assert!(lwi <= 1e-12, "positive log-softmax entry: {}", lwi);
        }
    }

    // ── iter-472: tropical_log_softmin ────────────────────────────

    #[test]
    fn log_softmin_exp_matches_softmin() {
        // exp(log_softmin(v, β)) ≡ softmin(v, β).
        let v = vec![1.0, 2.0, 3.0, 4.0];
        let beta = 1.5_f64;
        let log_w = tropical_log_softmin(&v, beta);
        let w = tropical_softmin(&v, beta);
        for (lw, w) in log_w.iter().zip(w.iter()) {
            assert!((lw.exp() - w).abs() < 1e-12);
        }
    }

    #[test]
    fn log_softmin_high_beta_argmin_approaches_zero() {
        // β = 50 ⇒ exp(log_softmin_argmin) ≈ 1 ⇒ entry ≈ 0;
        // other entries very negative.
        let log_w = tropical_log_softmin(&[5.0, 1.0, 3.0, 7.0], 50.0);
        // argmin index is 1.
        assert!(log_w[1].abs() < 0.01);
        for (i, lwi) in log_w.iter().enumerate() {
            if i != 1 {
                assert!(*lwi < -10.0);
            }
        }
    }

    #[test]
    fn log_softmin_uniform_input_is_minus_ln_n() {
        let n = 5_usize;
        let v = vec![3.0_f64; n];
        let log_w = tropical_log_softmin(&v, 2.0);
        let expected = -((n as f64).ln());
        for lw in log_w {
            assert!((lw - expected).abs() < 1e-12);
        }
    }

    #[test]
    fn log_softmin_dual_to_log_softmax_under_negation() {
        // tropical_log_softmin(v, β) ≡ tropical_log_softmax(−v, β)
        // (semiring duality: softmin = softmax-of-negation).
        let v = vec![1.0, 5.0, 3.0, 2.0, -1.0];
        let neg: Vec<f64> = v.iter().map(|x| -x).collect();
        let lo_min = tropical_log_softmin(&v, 1.5);
        let lo_max = tropical_log_softmax(&neg, 1.5);
        for (a, b) in lo_min.iter().zip(lo_max.iter()) {
            assert!((a - b).abs() < 1e-12);
        }
    }

    #[test]
    fn log_softmin_empty_or_invalid_beta_returns_empty() {
        assert!(tropical_log_softmin(&[], 1.0).is_empty());
        assert!(tropical_log_softmin(&[1.0, 2.0], 0.0).is_empty());
        assert!(tropical_log_softmin(&[1.0, 2.0], -1.0).is_empty());
    }

    // ── iter-478: tropical_softmax_entropy ────────────────────────

    #[test]
    fn softmax_entropy_uniform_input_is_ln_n() {
        // Uniform input ⇒ uniform softmax ⇒ H = ln(n).
        let n = 5_usize;
        let v = vec![3.0_f64; n];
        let h = tropical_softmax_entropy(&v, 2.0);
        assert!((h - (n as f64).ln()).abs() < 1e-12);
    }

    #[test]
    fn softmax_entropy_high_beta_approaches_zero() {
        // β = 100 ⇒ near-one-hot ⇒ H ≈ 0.
        let h = tropical_softmax_entropy(&[1.0, 5.0, 2.0, 3.0], 100.0);
        assert!(h < 1e-12);
    }

    #[test]
    fn softmax_entropy_bounded_by_ln_n() {
        // H ∈ [0, ln(n)] for any valid β > 0.
        let v = vec![1.0, 5.0, 2.0, 3.0, -1.0];
        let n = v.len();
        for beta in [0.1_f64, 0.5, 1.0, 2.0, 10.0] {
            let h = tropical_softmax_entropy(&v, beta);
            assert!(h >= -1e-12);
            assert!(h <= (n as f64).ln() + 1e-12, "β={}: H={}", beta, h);
        }
    }

    #[test]
    fn softmax_entropy_empty_or_invalid_beta_is_zero() {
        assert_eq!(tropical_softmax_entropy(&[], 1.0), 0.0);
        assert_eq!(tropical_softmax_entropy(&[1.0, 2.0], 0.0), 0.0);
        assert_eq!(tropical_softmax_entropy(&[1.0, 2.0], -1.0), 0.0);
    }

    #[test]
    fn softmax_entropy_matches_direct_neg_p_log_p() {
        // H ≡ −Σ p · ln(p) via tropical_softmax distribution.
        let v = vec![1.0, 5.0, 2.0, 3.0];
        let beta = 1.5_f64;
        let p = tropical_softmax(&v, beta);
        let h_direct: f64 = p.iter()
            .filter(|p| **p > 0.0)
            .map(|p| -p * p.ln())
            .sum();
        let h_helper = tropical_softmax_entropy(&v, beta);
        assert!((h_helper - h_direct).abs() < 1e-12);
    }

    // ── iter-484: tropical_softmin_entropy ────────────────────────

    #[test]
    fn softmin_entropy_uniform_input_is_ln_n() {
        let n = 5_usize;
        let v = vec![3.0_f64; n];
        let h = tropical_softmin_entropy(&v, 2.0);
        assert!((h - (n as f64).ln()).abs() < 1e-12);
    }

    #[test]
    fn softmin_entropy_high_beta_approaches_zero() {
        let h = tropical_softmin_entropy(&[5.0, 1.0, 3.0, 7.0], 100.0);
        assert!(h < 1e-12);
    }

    #[test]
    fn softmin_entropy_bounded_by_ln_n() {
        let v = vec![1.0, 5.0, 2.0, 3.0, -1.0];
        let n = v.len();
        for beta in [0.1_f64, 0.5, 1.0, 2.0, 10.0] {
            let h = tropical_softmin_entropy(&v, beta);
            assert!(h >= -1e-12);
            assert!(h <= (n as f64).ln() + 1e-12, "β={}: H={}", beta, h);
        }
    }

    #[test]
    fn softmin_entropy_empty_or_invalid_beta_is_zero() {
        assert_eq!(tropical_softmin_entropy(&[], 1.0), 0.0);
        assert_eq!(tropical_softmin_entropy(&[1.0, 2.0], 0.0), 0.0);
        assert_eq!(tropical_softmin_entropy(&[1.0, 2.0], -1.0), 0.0);
    }

    #[test]
    fn softmin_entropy_negation_duality_with_softmax_entropy() {
        // H(softmin(v, β)) ≡ H(softmax(−v, β)).
        let v = vec![1.0, 5.0, 2.0, 3.0, -1.0];
        let neg: Vec<f64> = v.iter().map(|x| -x).collect();
        let h_min = tropical_softmin_entropy(&v, 1.5);
        let h_max_of_neg = tropical_softmax_entropy(&neg, 1.5);
        assert!((h_min - h_max_of_neg).abs() < 1e-12);
    }

    // ── iter-490: tropical_softmax_kl_divergence ──────────────────

    #[test]
    fn softmax_kl_self_is_zero() {
        let kl = tropical_softmax_kl_divergence(&[1.0, 5.0, 2.0], &[1.0, 5.0, 2.0], 1.0).unwrap();
        assert!(kl.abs() < 1e-12);
    }

    #[test]
    fn softmax_kl_shift_invariant() {
        // softmax is shift-invariant ⇒ KL(softmax(v), softmax(v + c)) ≡ 0.
        let v = vec![1.0, 5.0, 2.0, 3.0];
        let c = 7.5_f64;
        let v_shift: Vec<f64> = v.iter().map(|x| x + c).collect();
        let kl = tropical_softmax_kl_divergence(&v, &v_shift, 1.5).unwrap();
        assert!(kl.abs() < 1e-12, "shift-invariance broken: KL={}", kl);
    }

    #[test]
    fn softmax_kl_length_mismatch_is_none() {
        assert!(tropical_softmax_kl_divergence(&[1.0, 2.0], &[1.0, 2.0, 3.0], 1.0).is_none());
        assert!(tropical_softmax_kl_divergence(&[], &[], 1.0).is_none());
    }

    #[test]
    fn softmax_kl_nonneg_on_grid() {
        let p = vec![1.0, 5.0, 2.0, 3.0];
        let q = vec![2.0, 1.0, 4.0, -1.0];
        for beta in [0.1_f64, 0.5, 1.0, 2.0] {
            let kl = tropical_softmax_kl_divergence(&p, &q, beta).unwrap();
            assert!(kl >= -1e-12);
        }
    }

    #[test]
    fn softmax_kl_matches_direct_kl_from_probs() {
        let p = vec![1.0, 5.0, 2.0, 3.0];
        let q = vec![2.0, 1.0, 4.0, -1.0];
        let beta = 1.5_f64;
        let kl_helper = tropical_softmax_kl_divergence(&p, &q, beta).unwrap();
        let pa = tropical_softmax(&p, beta);
        let qb = tropical_softmax(&q, beta);
        let kl_direct: f64 = pa.iter().zip(qb.iter())
            .filter(|(p, _)| **p > 0.0)
            .map(|(p, q)| p * (p.ln() - q.ln()))
            .sum();
        assert!((kl_helper - kl_direct).abs() < 1e-12);
    }

    // ── iter-496: tropical_softmax_cross_entropy ─────────────────

    #[test]
    fn softmax_cross_entropy_self_equals_entropy() {
        let v = vec![1.0, 5.0, 2.0, 3.0];
        let ce = tropical_softmax_cross_entropy(&v, &v, 1.5).unwrap();
        let h = tropical_softmax_entropy(&v, 1.5);
        assert!((ce - h).abs() < 1e-12);
    }

    #[test]
    fn softmax_cross_entropy_decomposes_as_entropy_plus_kl() {
        let p = vec![1.0, 5.0, 2.0, 3.0];
        let q = vec![2.0, 1.0, 4.0, -1.0];
        let beta = 1.5_f64;
        let ce = tropical_softmax_cross_entropy(&p, &q, beta).unwrap();
        let h = tropical_softmax_entropy(&p, beta);
        let kl = tropical_softmax_kl_divergence(&p, &q, beta).unwrap();
        assert!((ce - (h + kl)).abs() < 1e-12);
    }

    #[test]
    fn softmax_cross_entropy_matches_direct_probs() {
        let p = vec![1.0, 5.0, 2.0, 3.0];
        let q = vec![2.0, 1.0, 4.0, -1.0];
        let beta = 1.5_f64;
        let pa = tropical_softmax(&p, beta);
        let qb = tropical_softmax(&q, beta);
        let direct: f64 = pa.iter().zip(qb.iter())
            .filter(|(p, _)| **p > 0.0)
            .map(|(p, q)| -p * q.ln())
            .sum();
        let helper = tropical_softmax_cross_entropy(&p, &q, beta).unwrap();
        assert!((helper - direct).abs() < 1e-12);
    }

    #[test]
    fn softmax_cross_entropy_length_mismatch_is_none() {
        assert!(tropical_softmax_cross_entropy(&[1.0, 2.0], &[1.0, 2.0, 3.0], 1.0).is_none());
        assert!(tropical_softmax_cross_entropy(&[], &[], 1.0).is_none());
    }

    #[test]
    fn softmax_cross_entropy_invalid_beta_is_nan() {
        let ce = tropical_softmax_cross_entropy(&[1.0, 2.0], &[2.0, 1.0], 0.0).unwrap();
        assert!(ce.is_nan());
    }

    // ── iter-370: tropical_softmin ────────────────────────────────

    #[test]
    fn softmin_sums_to_one_on_valid_input() {
        let w = tropical_softmin(&[1.0, 2.0, 3.0, 4.0], 1.0);
        let s: f64 = w.iter().sum();
        assert!((s - 1.0).abs() < 1e-12);
    }

    #[test]
    fn softmin_high_beta_concentrates_on_argmin() {
        let w = tropical_softmin(&[5.0, 1.0, 4.0, 3.0], 50.0);
        assert!(w[1] > 0.99);
        for (i, wi) in w.iter().enumerate() {
            if i != 1 {
                assert!(*wi < 0.01, "w_{} = {} should be near 0", i, wi);
            }
        }
    }

    #[test]
    fn softmin_uniform_input_is_uniform_distribution() {
        let n = 5_usize;
        let v = vec![3.0; n];
        let w = tropical_softmin(&v, 2.0);
        for wi in w {
            assert!((wi - 1.0 / n as f64).abs() < 1e-12);
        }
    }

    #[test]
    fn softmin_empty_or_invalid_beta_returns_empty() {
        assert!(tropical_softmin(&[], 1.0).is_empty());
        assert!(tropical_softmin(&[1.0, 2.0], 0.0).is_empty());
        assert!(tropical_softmin(&[1.0, 2.0], -1.0).is_empty());
    }

    #[test]
    fn softmin_under_negation_equals_softmax() {
        // softmin(v, β) = softmax(−v, β) — semiring duality.
        let v = vec![1.0, 5.0, 2.0, 3.0];
        let neg: Vec<f64> = v.iter().map(|x| -x).collect();
        let smin = tropical_softmin(&v, 1.5);
        let smax = tropical_softmax(&neg, 1.5);
        for (a, b) in smin.iter().zip(smax.iter()) {
            assert!((a - b).abs() < 1e-12);
        }
    }

    // ── iter-376: tropical_min_polynomial ─────────────────────────

    #[test]
    fn min_polynomial_empty_is_infinity() {
        assert!(tropical_min_polynomial(&[], 1.0).is_infinite());
        assert!(tropical_min_polynomial(&[], 1.0) > 0.0);
    }

    #[test]
    fn min_polynomial_single_coeff_is_constant() {
        assert_eq!(tropical_min_polynomial(&[3.5], 100.0), 3.5);
        assert_eq!(tropical_min_polynomial(&[-2.0], -50.0), -2.0);
    }

    #[test]
    fn min_polynomial_dual_to_tropical_polynomial_under_neg() {
        // p_min(x; a_k) = min_k (a_k + k·x); under both sign-flips
        // (coefficients AND argument), the rhs is
        // -max_k(-a_k + k·(-x)) = -max_k(-a_k - k·x) = min_k(a_k + k·x).
        // I.e. p_min(x; a) = -p_max(-x; -a).
        let a = vec![1.0, -3.0, 2.0, 0.5];
        let neg_a: Vec<f64> = a.iter().map(|x| -x).collect();
        for x in [-2.0_f64, -0.5, 0.0, 0.5, 2.0] {
            let lhs = tropical_min_polynomial(&a, x);
            let rhs = -tropical_polynomial(&neg_a, -x);
            assert!((lhs - rhs).abs() < 1e-12, "x={}: lhs={} rhs={}", x, lhs, rhs);
        }
    }

    #[test]
    fn min_polynomial_linear_with_two_coeffs_is_min_of_lines() {
        // p_min(x; [a_0, a_1]) = min(a_0, a_1 + x).
        let coeffs = [3.0, 1.0]; // y = 3 vs y = 1 + x; cross at x=2.
        // At x = 0: min(3, 1) = 1.
        let v0 = tropical_min_polynomial(&coeffs, 0.0);
        assert_eq!(v0, 1.0);
        // At x = 5: min(3, 6) = 3.
        let v5 = tropical_min_polynomial(&coeffs, 5.0);
        assert_eq!(v5, 3.0);
    }

    // ── iter-382: tropical_polynomial_argmax_at ───────────────────

    #[test]
    fn polynomial_argmax_empty_is_none() {
        assert!(tropical_polynomial_argmax_at(&[], 0.0).is_none());
    }

    #[test]
    fn polynomial_argmax_at_zero_is_max_coeff() {
        // At x = 0: a_k + k·0 = a_k → argmax k = argmax a_k.
        let coeffs = vec![1.0, 5.0, 3.0, 4.0];
        assert_eq!(tropical_polynomial_argmax_at(&coeffs, 0.0), Some(1));
    }

    #[test]
    fn polynomial_argmax_at_large_x_selects_highest_index() {
        // For large positive x, the high-k slope dominates.
        let coeffs = vec![10.0, -5.0, 0.0, 1.0];
        assert_eq!(tropical_polynomial_argmax_at(&coeffs, 100.0), Some(3));
    }

    #[test]
    fn polynomial_argmax_at_negative_x_selects_lowest_index() {
        // For x large negative, the k=0 piece (slope 0) is best
        // when its constant exceeds all other (a_k − k·|x|).
        let coeffs = vec![10.0, -5.0, 0.0, 1.0];
        assert_eq!(tropical_polynomial_argmax_at(&coeffs, -100.0), Some(0));
    }

    #[test]
    fn polynomial_argmax_consistent_with_value() {
        // a_argmax + argmax·x ≡ tropical_polynomial(coeffs, x).
        let coeffs = vec![1.5, -2.0, 3.5, 0.5];
        for x in [-3.0_f64, -1.0, 0.0, 0.5, 2.0, 5.0] {
            let k = tropical_polynomial_argmax_at(&coeffs, x).unwrap();
            let direct_val = coeffs[k] + (k as f64) * x;
            let poly_val = tropical_polynomial(&coeffs, x);
            assert!((direct_val - poly_val).abs() < 1e-12, "x={}", x);
        }
    }

    // ── iter-388: tropical_min_polynomial_argmin_at ───────────────

    #[test]
    fn min_polynomial_argmin_empty_is_none() {
        assert!(tropical_min_polynomial_argmin_at(&[], 0.0).is_none());
    }

    #[test]
    fn min_polynomial_argmin_at_zero_is_min_coeff() {
        // At x = 0: a_k + k·0 = a_k → argmin k = argmin a_k.
        let coeffs = vec![5.0, 1.0, 3.0, 2.0];
        assert_eq!(tropical_min_polynomial_argmin_at(&coeffs, 0.0), Some(1));
    }

    #[test]
    fn min_polynomial_argmin_at_large_x_selects_lowest_index() {
        // For large positive x, the high-k slope dominates upward;
        // argmin is the lowest-k (slope 0) piece.
        let coeffs = vec![10.0, -5.0, 0.0, 1.0];
        assert_eq!(tropical_min_polynomial_argmin_at(&coeffs, 100.0), Some(0));
    }

    #[test]
    fn min_polynomial_argmin_consistent_with_value() {
        let coeffs = vec![1.5, -2.0, 3.5, 0.5];
        for x in [-3.0_f64, -1.0, 0.0, 0.5, 2.0, 5.0] {
            let k = tropical_min_polynomial_argmin_at(&coeffs, x).unwrap();
            let direct_val = coeffs[k] + (k as f64) * x;
            let poly_val = tropical_min_polynomial(&coeffs, x);
            assert!((direct_val - poly_val).abs() < 1e-12, "x={}", x);
        }
    }

    #[test]
    fn min_polynomial_argmin_dual_to_argmax_under_neg() {
        // argmin_a (a_k + k·x) ≡ argmax_{−a} (−a_k − k·(−x))
        // → check at corresponding (−x, −a) pair.
        let coeffs = vec![1.5, -2.0, 3.5, 0.5];
        let neg_coeffs: Vec<f64> = coeffs.iter().map(|c| -c).collect();
        for x in [-1.5_f64, 0.0, 1.5, 3.0] {
            let min_arg = tropical_min_polynomial_argmin_at(&coeffs, x).unwrap();
            let max_arg = tropical_polynomial_argmax_at(&neg_coeffs, -x).unwrap();
            assert_eq!(min_arg, max_arg, "x={}", x);
        }
    }

    // ── iter-394: tropical_vector_argmin_argmax_indices ───────────

    #[test]
    fn argmin_argmax_indices_basic() {
        let r = tropical_vector_argmin_argmax_indices(&[3.0, 1.0, 4.0, 1.0, 5.0, 9.0, 2.0]);
        // First-occurrence ties: min at idx 1, max at idx 5.
        assert_eq!(r, Some((1, 5)));
    }

    #[test]
    fn argmin_argmax_indices_empty_is_none() {
        assert!(tropical_vector_argmin_argmax_indices(&[]).is_none());
    }

    #[test]
    fn argmin_argmax_indices_singleton_both_zero() {
        assert_eq!(tropical_vector_argmin_argmax_indices(&[42.0]), Some((0, 0)));
    }

    #[test]
    fn argmin_argmax_indices_consistent_with_individual_argfuncs() {
        let v = vec![-3.0, 7.0, 2.0, -1.0, 5.0];
        let (min_idx, max_idx) = tropical_vector_argmin_argmax_indices(&v).unwrap();
        let direct_min = tropical_argmin_idx(&v).unwrap();
        let direct_max = tropical_argmax_idx(&v).unwrap();
        assert_eq!(min_idx, direct_min);
        assert_eq!(max_idx, direct_max);
    }

    // ── iter-400: tropical_vector_amplitude ───────────────────────

    #[test]
    fn amplitude_basic() {
        let a = tropical_vector_amplitude(&[1.0, 5.0, 3.0]).unwrap();
        assert_eq!(a, 4.0);
    }

    #[test]
    fn amplitude_empty_is_none() {
        assert!(tropical_vector_amplitude(&[]).is_none());
    }

    #[test]
    fn amplitude_singleton_is_zero() {
        let a = tropical_vector_amplitude(&[42.0]).unwrap();
        assert_eq!(a, 0.0);
    }

    #[test]
    fn amplitude_constant_vector_is_zero() {
        let a = tropical_vector_amplitude(&[7.0, 7.0, 7.0, 7.0]).unwrap();
        assert_eq!(a, 0.0);
    }

    #[test]
    fn amplitude_consistent_with_min_max_pair() {
        let v = vec![-3.0, 7.0, 2.0, -1.0, 5.0];
        let (lo, hi) = tropical_vector_min_max_pair(&v).unwrap();
        let amp = tropical_vector_amplitude(&v).unwrap();
        assert!((amp - (hi - lo)).abs() < 1e-12);
    }

    // ── iter-406: tropical_chebyshev_distance ─────────────────────

    #[test]
    fn chebyshev_distance_basic() {
        let r = tropical_chebyshev_distance(&[1.0, 2.0, 3.0], &[4.0, 0.5, 6.0]).unwrap();
        // Diffs: 3, 1.5, 3 → max 3.
        assert_eq!(r, 3.0);
    }

    #[test]
    fn chebyshev_distance_self_is_zero() {
        let v = vec![1.0, 2.0, 3.0, 4.0];
        assert_eq!(tropical_chebyshev_distance(&v, &v).unwrap(), 0.0);
    }

    #[test]
    fn chebyshev_distance_empty_inputs_is_zero() {
        assert_eq!(tropical_chebyshev_distance(&[], &[]).unwrap(), 0.0);
    }

    #[test]
    fn chebyshev_distance_length_mismatch_is_none() {
        assert!(tropical_chebyshev_distance(&[1.0, 2.0], &[1.0, 2.0, 3.0]).is_none());
    }

    #[test]
    fn chebyshev_distance_symmetric() {
        let a = vec![1.0, 5.0, 3.0];
        let b = vec![4.0, 1.0, 7.0];
        let ab = tropical_chebyshev_distance(&a, &b).unwrap();
        let ba = tropical_chebyshev_distance(&b, &a).unwrap();
        assert_eq!(ab, ba);
    }

    // ── iter-412: tropical_polynomial_argmax_value_at ─────────────

    #[test]
    fn polynomial_argmax_value_empty_is_none() {
        assert!(tropical_polynomial_argmax_value_at(&[], 0.0).is_none());
    }

    #[test]
    fn polynomial_argmax_value_at_zero_is_max_coeff_pair() {
        let coeffs = vec![1.0, 5.0, 3.0, 4.0];
        let r = tropical_polynomial_argmax_value_at(&coeffs, 0.0);
        assert_eq!(r, Some((1, 5.0)));
    }

    #[test]
    fn polynomial_argmax_value_consistent_with_index_and_value_calls() {
        let coeffs = vec![1.5, -2.0, 3.5, 0.5];
        for x in [-3.0_f64, -1.0, 0.0, 0.5, 2.0, 5.0] {
            let (k, v) = tropical_polynomial_argmax_value_at(&coeffs, x).unwrap();
            let direct_k = tropical_polynomial_argmax_at(&coeffs, x).unwrap();
            let direct_v = tropical_polynomial(&coeffs, x);
            assert_eq!(k, direct_k, "x={}", x);
            assert!((v - direct_v).abs() < 1e-12, "x={}", x);
        }
    }

    // ── iter-418: tropical_min_polynomial_argmin_value_at ─────────

    #[test]
    fn min_polynomial_argmin_value_empty_is_none() {
        assert!(tropical_min_polynomial_argmin_value_at(&[], 0.0).is_none());
    }

    #[test]
    fn min_polynomial_argmin_value_at_zero_is_min_coeff_pair() {
        let coeffs = vec![5.0, 1.0, 3.0, 2.0];
        assert_eq!(
            tropical_min_polynomial_argmin_value_at(&coeffs, 0.0),
            Some((1, 1.0))
        );
    }

    #[test]
    fn min_polynomial_argmin_value_consistent_with_individual_calls() {
        let coeffs = vec![1.5, -2.0, 3.5, 0.5];
        for x in [-3.0_f64, -1.0, 0.0, 0.5, 2.0, 5.0] {
            let (k, v) = tropical_min_polynomial_argmin_value_at(&coeffs, x).unwrap();
            let direct_k = tropical_min_polynomial_argmin_at(&coeffs, x).unwrap();
            let direct_v = tropical_min_polynomial(&coeffs, x);
            assert_eq!(k, direct_k, "x={}", x);
            assert!((v - direct_v).abs() < 1e-12, "x={}", x);
        }
    }

    // ── iter-424: tropical_vector_recenter ────────────────────────

    #[test]
    fn recenter_max_is_zero() {
        let v = vec![1.0, 5.0, 3.0, 2.0];
        let r = tropical_vector_recenter(&v);
        let new_max = tropical_vector_max(&r);
        assert!((new_max).abs() < 1e-12);
    }

    #[test]
    fn recenter_empty_returns_empty() {
        let r = tropical_vector_recenter(&[]);
        assert!(r.is_empty());
    }

    #[test]
    fn recenter_preserves_differences() {
        // Pointwise differences are preserved by a constant shift.
        let v = vec![-3.0, 7.0, 2.0, -1.0, 5.0];
        let r = tropical_vector_recenter(&v);
        for i in 0..v.len() - 1 {
            assert!((v[i + 1] - v[i] - (r[i + 1] - r[i])).abs() < 1e-12);
        }
    }

    #[test]
    fn recenter_all_entries_non_positive() {
        // After recentering, every entry ≤ 0 (max is 0).
        let v = vec![1.0, 5.0, 3.0, 2.0];
        let r = tropical_vector_recenter(&v);
        for &x in &r {
            assert!(x <= 1e-12);
        }
    }

    #[test]
    fn recenter_idempotent() {
        // Applying recenter twice gives the same vector as once.
        let v = vec![1.0, 5.0, 3.0, 2.0];
        let r1 = tropical_vector_recenter(&v);
        let r2 = tropical_vector_recenter(&r1);
        for (a, b) in r1.iter().zip(r2.iter()) {
            assert!((a - b).abs() < 1e-12);
        }
    }

    // ── iter-430: tropical_l1_distance ────────────────────────────

    #[test]
    fn l1_distance_basic() {
        let r = tropical_l1_distance(&[1.0, 2.0, 3.0], &[4.0, 0.5, 6.0]).unwrap();
        // Diffs: 3, 1.5, 3 → sum 7.5.
        assert!((r - 7.5).abs() < 1e-12);
    }

    #[test]
    fn l1_distance_self_is_zero() {
        let v = vec![1.0, 2.0, 3.0];
        assert_eq!(tropical_l1_distance(&v, &v).unwrap(), 0.0);
    }

    #[test]
    fn l1_distance_empty_is_zero() {
        assert_eq!(tropical_l1_distance(&[], &[]).unwrap(), 0.0);
    }

    #[test]
    fn l1_distance_length_mismatch_is_none() {
        assert!(tropical_l1_distance(&[1.0, 2.0], &[1.0, 2.0, 3.0]).is_none());
    }

    #[test]
    fn l1_distance_bounded_below_by_chebyshev() {
        // Chebyshev ≤ L¹ for any pair of vectors.
        let a = vec![1.0, 5.0, 3.0];
        let b = vec![4.0, 1.0, 7.0];
        let l1 = tropical_l1_distance(&a, &b).unwrap();
        let linf = tropical_chebyshev_distance(&a, &b).unwrap();
        assert!(linf <= l1 + 1e-12);
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

    // ── iter-280: tropical_vector_scalar_add ──────────────────────

    #[test]
    fn vector_scalar_add_zero_is_identity() {
        let v = vec![1.0, 2.0, 3.0];
        assert_eq!(tropical_vector_scalar_add(&v, 0.0), v);
    }

    #[test]
    fn vector_scalar_add_known() {
        let v = vec![1.0, 2.0, 3.0];
        assert_eq!(tropical_vector_scalar_add(&v, 5.0), vec![6.0, 7.0, 8.0]);
    }

    #[test]
    fn vector_scalar_add_distributes_over_max() {
        // max(v + c) = max(v) + c.
        let v = vec![1.0_f64, 5.0, 3.0];
        let c = 7.0;
        let lhs = tropical_vector_max(&tropical_vector_scalar_add(&v, c));
        let rhs = tropical_vector_max(&v) + c;
        assert!((lhs - rhs).abs() < 1e-12);
    }

    #[test]
    fn vector_scalar_add_empty_is_empty() {
        let v: Vec<f64> = vec![];
        assert!(tropical_vector_scalar_add(&v, 5.0).is_empty());
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

    // ── iter-298: tropical_constant_matrix ────────────────────────

    #[test]
    fn constant_matrix_3x2_value_5() {
        let m = tropical_constant_matrix(3, 2, 5.0);
        assert_eq!(m.len(), 3);
        for row in &m {
            assert_eq!(row.len(), 2);
            for &v in row {
                assert_eq!(v, 5.0);
            }
        }
    }

    #[test]
    fn constant_matrix_zero_rows_is_empty() {
        let m = tropical_constant_matrix(0, 4, 7.0);
        assert!(m.is_empty());
    }

    #[test]
    fn constant_matrix_neg_infinity_matches_zero_matrix() {
        let a = tropical_constant_matrix(2, 3, f64::NEG_INFINITY);
        let b = tropical_zero_matrix(2, 3);
        assert_eq!(a, b);
    }

    // ── iter-310: tropical_identity_matrix_scaled ─────────────────

    #[test]
    fn identity_scaled_c_zero_is_tropical_identity() {
        let m = tropical_identity_matrix_scaled(3, 0.0);
        assert_eq!(m, tropical_identity_matrix(3));
    }

    #[test]
    fn identity_scaled_diagonal_is_c() {
        let m = tropical_identity_matrix_scaled(3, 5.0);
        for i in 0..3 {
            assert_eq!(m[i][i], 5.0);
        }
    }

    #[test]
    fn identity_scaled_off_diagonal_is_neg_infinity() {
        let m = tropical_identity_matrix_scaled(3, 7.0);
        for i in 0..3 {
            for j in 0..3 {
                if i != j {
                    assert!(m[i][j].is_infinite() && m[i][j] < 0.0);
                }
            }
        }
    }

    // ── iter-292: tropical_zero_matrix ────────────────────────────

    #[test]
    fn zero_matrix_2x3_all_neg_infinity() {
        let z = tropical_zero_matrix(2, 3);
        assert_eq!(z.len(), 2);
        for row in &z {
            assert_eq!(row.len(), 3);
            for &v in row {
                assert!(v.is_infinite() && v < 0.0);
            }
        }
    }

    #[test]
    fn zero_matrix_zero_rows_is_empty() {
        let z = tropical_zero_matrix(0, 5);
        assert!(z.is_empty());
    }

    #[test]
    fn zero_matrix_additive_identity_for_max_pointwise() {
        // Z ⊕ A = A (NEG_INFINITY is the additive identity).
        let a = vec![vec![1.0, 5.0], vec![3.0, 2.0]];
        let z = tropical_zero_matrix(2, 2);
        let za = tropical_matrix_max_pointwise(&z, &a).unwrap();
        assert_eq!(za, a);
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

    // ── iter-286: tropical_matrix_kleene_partial ──────────────────

    #[test]
    fn kleene_partial_k_zero_is_identity() {
        let a = vec![vec![1.0, 2.0], vec![3.0, 0.0]];
        let k0 = tropical_matrix_kleene_partial(&a, 0).unwrap();
        assert_eq!(k0, tropical_identity_matrix(2));
    }

    #[test]
    fn kleene_partial_k_one_is_identity_max_a() {
        let a = vec![vec![1.0, 2.0], vec![3.0, 0.0]];
        let k1 = tropical_matrix_kleene_partial(&a, 1).unwrap();
        let expected = tropical_matrix_max_pointwise(&tropical_identity_matrix(2), &a).unwrap();
        assert_eq!(k1, expected);
    }

    #[test]
    fn kleene_partial_monotone_in_k() {
        // Successively larger k accumulates more terms; each entry
        // can only grow under (max, +) ⊕.
        let a = vec![vec![0.0, 1.0], vec![1.0, 0.0]];
        let k1 = tropical_matrix_kleene_partial(&a, 1).unwrap();
        let k2 = tropical_matrix_kleene_partial(&a, 2).unwrap();
        for (r1, r2) in k1.iter().zip(k2.iter()) {
            for (x, y) in r1.iter().zip(r2.iter()) {
                assert!(*y >= *x - 1e-12);
            }
        }
    }

    #[test]
    fn kleene_partial_non_square_rejected() {
        let a = vec![vec![1.0, 2.0, 3.0]];
        assert!(tropical_matrix_kleene_partial(&a, 2).is_none());
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

    // ── iter-454: tropical_smooth_polynomial ──────────────────────

    #[test]
    fn smooth_polynomial_empty_is_neg_infinity() {
        assert_eq!(
            tropical_smooth_polynomial(&[], 1.0, 1.0),
            f64::NEG_INFINITY
        );
    }

    #[test]
    fn smooth_polynomial_invalid_beta_is_nan() {
        assert!(tropical_smooth_polynomial(&[1.0, 2.0], 1.0, 0.0).is_nan());
        assert!(tropical_smooth_polynomial(&[1.0, 2.0], 1.0, -1.0).is_nan());
    }

    #[test]
    fn smooth_polynomial_high_beta_approaches_sharp() {
        let coeffs = [0.0, 1.0, 0.0];
        for x in [-5.0_f64, 0.0, 2.0, 5.0] {
            let sharp = tropical_polynomial(&coeffs, x);
            let smooth = tropical_smooth_polynomial(&coeffs, x, 100.0);
            assert!(
                (smooth - sharp).abs() < 1e-2,
                "x={}: smooth={} sharp={}",
                x,
                smooth,
                sharp
            );
        }
    }

    #[test]
    fn smooth_polynomial_singleton_equals_value() {
        // For one coefficient, the polynomial collapses to a_0.
        let v = tropical_smooth_polynomial(&[3.5], 100.0, 1.0);
        assert!((v - 3.5).abs() < 1e-12);
    }

    #[test]
    fn smooth_polynomial_bounded_below_by_sharp() {
        // LSE positive bias ⇒ smooth ≥ sharp for any finite β > 0.
        let coeffs = [0.0, 1.0, 0.0, 2.0];
        for x in [-2.0_f64, 0.0, 3.0] {
            let sharp = tropical_polynomial(&coeffs, x);
            let smooth = tropical_smooth_polynomial(&coeffs, x, 0.5);
            assert!(smooth + 1e-12 >= sharp);
        }
    }

    // ── iter-460: tropical_smooth_min_polynomial ──────────────────

    #[test]
    fn smooth_min_polynomial_empty_is_infinity() {
        let r = tropical_smooth_min_polynomial(&[], 1.0, 1.0);
        assert!(r.is_infinite());
        assert!(r > 0.0);
    }

    #[test]
    fn smooth_min_polynomial_invalid_beta_is_nan() {
        assert!(tropical_smooth_min_polynomial(&[1.0, 2.0], 1.0, 0.0).is_nan());
        assert!(tropical_smooth_min_polynomial(&[1.0, 2.0], 1.0, -1.0).is_nan());
    }

    #[test]
    fn smooth_min_polynomial_high_beta_approaches_sharp() {
        let coeffs = [0.0, 1.0, 0.0];
        for x in [-5.0_f64, 0.0, 2.0, 5.0] {
            let sharp = tropical_min_polynomial(&coeffs, x);
            let smooth = tropical_smooth_min_polynomial(&coeffs, x, 100.0);
            assert!(
                (smooth - sharp).abs() < 1e-2,
                "x={}: smooth={} sharp={}",
                x,
                smooth,
                sharp
            );
        }
    }

    #[test]
    fn smooth_min_polynomial_bounded_above_by_sharp() {
        // LSE_β^{min} ≤ min always for finite β > 0 (negative bias).
        let coeffs = [0.0, 1.0, 0.0, 2.0];
        for x in [-2.0_f64, 0.0, 3.0] {
            let sharp = tropical_min_polynomial(&coeffs, x);
            let smooth = tropical_smooth_min_polynomial(&coeffs, x, 0.5);
            assert!(smooth <= sharp + 1e-12);
        }
    }

    #[test]
    fn smooth_min_polynomial_dual_to_smooth_polynomial_under_negation() {
        // smooth_min(coeffs, x; β) ≡ −smooth_max(−coeffs at lines with negated slopes).
        // For polynomial evaluation we negate the affine lines value, which means
        // smooth_min(a_k + k·x; β) = −smooth_max(−(a_k + k·x); β). We can build
        // an equivalent test by separately computing both forms over the same
        // value vector and asserting equality up to sign.
        let coeffs = [0.0, 1.0, 0.0, 2.0];
        for x in [-2.0_f64, 0.0, 3.0] {
            let smooth_min = tropical_smooth_min_polynomial(&coeffs, x, 1.5);
            // Build the value vector explicitly and feed −v into the smooth-max
            // form via direct tropical_smooth_max call.
            let values: Vec<f64> = coeffs
                .iter()
                .enumerate()
                .map(|(k, &a)| -(a + (k as f64) * x))
                .collect();
            let smooth_max_of_neg = tropical_smooth_max(&values, 1.5);
            assert!((smooth_min + smooth_max_of_neg).abs() < 1e-12);
        }
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
