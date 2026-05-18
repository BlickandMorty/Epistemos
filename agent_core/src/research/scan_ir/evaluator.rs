//! Source:
//! - Blelloch CMU-CS-90-190 — the canonical sequential left-fold
//!   formulation of scan. The reference oracle for iter-26's SSD
//!   parallel-block lowering.
//! - Dao/Gu arXiv:2405.21060 §6 (SSD algorithm) — produces the
//!   same scan outputs as sequential left-fold; iter-27's property
//!   test cross-checks.
//! - Doctrine §4.3 — Scan-IR first lowering target shape.
//! - Companion: [`super::grammar`] (the ScanProgram this module
//!   evaluates).
//!
//! # Sequential reference scan
//!
//! Walks the input sequence left-to-right, applying the supplied
//! associative operator `op(&state, &input)` to fold the next
//! input into the running state. Pushes the new state to the
//! output at each step.
//!
//! For an input program `(initial, [a_1, a_2, …, a_n])`, the
//! output is `[initial, op(initial, a_1), op(op(initial, a_1), a_2), …]`
//! with length `1 + n`.

use super::grammar::ScanProgram;

/// Sequential scan: left-fold the inputs into the running state.
///
/// Generic over the carrier `T` (must be `Clone` so we can store
/// the running state at each output position) and the op (a
/// closure or fn pointer). The op is NOT required to be
/// associative for this routine to produce SOME output — but the
/// SSD parallel lowering (iter-26) requires associativity, and
/// the property test (iter-27) compares both routes.
pub fn sequential_scan<T, F>(program: &ScanProgram<T>, op: F) -> Vec<T>
where
    T: Clone,
    F: Fn(&T, &T) -> T,
{
    let mut out = Vec::with_capacity(program.output_count());
    let mut state = program.initial.clone();
    out.push(state.clone());
    for input in &program.inputs {
        state = op(&state, input);
        out.push(state.clone());
    }
    out
}

/// Variant of [`sequential_scan`] that returns only the FINAL
/// state (the reduce, not the full scan).
pub fn sequential_reduce<T, F>(program: &ScanProgram<T>, op: F) -> T
where
    T: Clone,
    F: Fn(&T, &T) -> T,
{
    let mut state = program.initial.clone();
    for input in &program.inputs {
        state = op(&state, input);
    }
    state
}

/// Running sum: prefix-sums of f64 inputs starting from `program.initial`.
///
/// Equivalent to `sequential_scan(program, |a, b| a + b)`.
///
/// Iter-90 — convenience wrapper for the addition-monoid scan.
pub fn running_sum(program: &ScanProgram<f64>) -> Vec<f64> {
    sequential_scan(program, |a, b| a + b)
}

/// Running maximum: at each step, the max of the running state and
/// the next input.
///
/// Iter-90 — convenience wrapper for the max-semilattice scan.
pub fn running_max(program: &ScanProgram<f64>) -> Vec<f64> {
    sequential_scan(program, |a, b| if a > b { *a } else { *b })
}

/// Running minimum.
///
/// Iter-90 — convenience wrapper for the min-semilattice scan.
pub fn running_min(program: &ScanProgram<f64>) -> Vec<f64> {
    sequential_scan(program, |a, b| if a < b { *a } else { *b })
}

/// Running product: prefix-products of f64 inputs.
///
/// Iter-90 — convenience wrapper for the multiplication-monoid scan.
pub fn running_product(program: &ScanProgram<f64>) -> Vec<f64> {
    sequential_scan(program, |a, b| a * b)
}

/// Running min-abs: `min_{i ≤ t} |xᵢ|`.
///
/// Cumulative minimum of absolute values over the prefix. The
/// first emitted value is `|initial|`; each subsequent step folds
/// `min(|state|, |x|)`.
///
/// Iter-249 — companion to `running_max_abs` (iter-135). Useful
/// for tracking the "best so far" magnitude in convergence
/// monitoring and for detecting how close a trajectory has come
/// to zero (the floor of any closed-form vanishing argument).
pub fn running_min_abs(program: &ScanProgram<f64>) -> Vec<f64> {
    let mut min_abs = program.initial.abs();
    let mut out = Vec::with_capacity(program.output_count());
    out.push(min_abs);
    for &x in &program.inputs {
        let ax = x.abs();
        if ax < min_abs {
            min_abs = ax;
        }
        out.push(min_abs);
    }
    out
}

/// Running count of strict increases between consecutive
/// elements: number of indices `i ≤ t` with `x_i > x_{i-1}`.
///
/// First emit is 0 (no prior element). Monotonically non-decreasing.
///
/// Iter-315 — directional jump counter; companion to
/// `running_sign_changes` (iter-231, which counts sign flips
/// not value-direction).
pub fn running_count_strict_increase(program: &ScanProgram<f64>) -> Vec<u64> {
    let mut prev = program.initial;
    let mut count: u64 = 0;
    let mut out = Vec::with_capacity(program.output_count());
    out.push(count);
    for &x in &program.inputs {
        if x > prev {
            count += 1;
        }
        out.push(count);
        prev = x;
    }
    out
}

/// Per-step absolute first difference: `|x_t − x_{t-1}|` (not
/// cumulative).
///
/// Distinct from `running_total_variation` (cumulative sum). The
/// first emitted value is 0 (no previous element). Each subsequent
/// step emits the magnitude of the single most recent jump.
///
/// Iter-303 — instantaneous path-element companion to
/// `running_total_variation` (iter-243); useful as a
/// per-sample volatility / jump-size measure.
pub fn running_first_difference_abs(program: &ScanProgram<f64>) -> Vec<f64> {
    let mut prev = program.initial;
    let mut out = Vec::with_capacity(program.output_count());
    out.push(0.0);
    for &x in &program.inputs {
        out.push((x - prev).abs());
        prev = x;
    }
    out
}

/// Running cumulative quadratic variation:
/// `QV_t = Σ_{i ≤ t} (x_i − x_{i-1})²`.
///
/// Cumulative sum of squared first differences. Bounded below
/// by 0; monotone non-decreasing. First emit is 0.
///
/// Iter-309 — quadratic companion to `running_total_variation`
/// (linear path length, iter-243). In stochastic process theory:
/// for a Wiener process, QV_T → T in probability as the
/// partition mesh → 0 (Itô's lemma foundation).
pub fn running_squared_increments(program: &ScanProgram<f64>) -> Vec<f64> {
    let mut prev = program.initial;
    let mut qv = 0.0_f64;
    let mut out = Vec::with_capacity(program.output_count());
    out.push(qv);
    for &x in &program.inputs {
        let d = x - prev;
        qv += d * d;
        out.push(qv);
        prev = x;
    }
    out
}

/// Running total variation: `TV_t = Σ_{i ≤ t} |x_i − x_{i-1}|`.
///
/// Cumulative sum of the absolute first differences — the
/// discrete L¹ path length. Bounded below by 0; monotonically
/// non-decreasing. First emit is 0 (no prior element).
///
/// Iter-243 — stream-roughness diagnostic; pairs with
/// `running_range` (iter-195, amplitude),
/// `running_sign_changes` (iter-231, oscillation count), and
/// `running_max_drawdown` (iter-237, asymmetric risk) as four
/// orthogonal "shape of the prefix" measures.
pub fn running_total_variation(program: &ScanProgram<f64>) -> Vec<f64> {
    let mut prev = program.initial;
    let mut tv = 0.0_f64;
    let mut out = Vec::with_capacity(program.output_count());
    out.push(tv);
    for &x in &program.inputs {
        tv += (x - prev).abs();
        out.push(tv);
        prev = x;
    }
    out
}

/// Running maximum drawup: at step `t`, the largest trough-to-
/// peak gain observed in the prefix.
///
/// Recurrence (dual of `running_max_drawdown`):
///   trough_t = min(trough_{t-1}, x_t).
///   drawup_t = max(drawup_{t-1}, x_t − trough_t).
///
/// Bounded below by 0; monotonically non-decreasing.
///
/// Iter-255 — dual of `running_max_drawdown` (iter-237). Captures
/// the upside-risk / "fall miss" symmetric to the downside-risk
/// drawdown measure. Useful in trend-following / momentum-signal
/// analysis.
pub fn running_max_drawup(program: &ScanProgram<f64>) -> Vec<f64> {
    let mut trough = program.initial;
    let mut max_du = 0.0_f64;
    let mut out = Vec::with_capacity(program.output_count());
    out.push(max_du);
    for &x in &program.inputs {
        if x < trough {
            trough = x;
        }
        let du = x - trough;
        if du > max_du {
            max_du = du;
        }
        out.push(max_du);
    }
    out
}

/// Running maximum drawdown: at step `t`, the largest peak-to-
/// trough decline observed in the prefix `[initial, x_1, …, x_t]`.
///
/// Recurrence:
///   peak_t = max(peak_{t-1}, x_t).
///   drawdown_t = max(drawdown_{t-1}, peak_t − x_t).
///
/// Bounded below by 0; monotonically non-decreasing.
///
/// Iter-237 — financial / time-series streaming primitive. Pairs
/// with `running_range` (iter-195) for amplitude monitoring and
/// `running_sign_changes` (iter-231) for oscillation monitoring;
/// drawdown captures the asymmetric "fall from peak" risk.
pub fn running_max_drawdown(program: &ScanProgram<f64>) -> Vec<f64> {
    let mut peak = program.initial;
    let mut max_dd = 0.0_f64;
    let mut out = Vec::with_capacity(program.output_count());
    out.push(max_dd);
    for &x in &program.inputs {
        if x > peak {
            peak = x;
        }
        let dd = peak - x;
        if dd > max_dd {
            max_dd = dd;
        }
        out.push(max_dd);
    }
    out
}

/// Running count of sign changes between consecutive elements.
///
/// At step `t`, returns the number of pairs `(x_{i-1}, x_i)` with
/// `i ≤ t` where the signs differ — that is, the cumulative
/// "sign-flip count" of the prefix. Zero values do not flip
/// (treated as continuing the previous sign).
///
/// The first emitted value is always 0 (no prior element to
/// compare). Monotonically non-decreasing.
///
/// Iter-231 — oscillation diagnostic; pairs with
/// `running_range` (iter-195) for amplitude vs. frequency dual
/// monitoring of a stream.
pub fn running_sign_changes(program: &ScanProgram<f64>) -> Vec<u64> {
    let mut count: u64 = 0;
    let mut prev_sign: i32 = program.initial.signum() as i32;
    if program.initial == 0.0 {
        prev_sign = 0;
    }
    let mut out = Vec::with_capacity(program.output_count());
    out.push(count);
    for &x in &program.inputs {
        let s = if x == 0.0 {
            0
        } else {
            x.signum() as i32
        };
        if s != 0 && prev_sign != 0 && s != prev_sign {
            count += 1;
        }
        if s != 0 {
            prev_sign = s;
        }
        out.push(count);
    }
    out
}

/// Running mean of squared values: `Σ_{i≤t} xᵢ² / (t+1)`.
///
/// Sqrt-free companion to [`running_quadratic_mean`]: the second
/// raw moment, useful when downstream code wants the variance
/// formula `Var = E[X²] − (E[X])²` or where sqrt is irrelevant.
///
/// Iter-279 — second-moment online aggregator.
pub fn running_mean_squared(program: &ScanProgram<f64>) -> Vec<f64> {
    let mut count = 1.0_f64;
    let mut sum_sq = program.initial * program.initial;
    let mut out = Vec::with_capacity(program.output_count());
    out.push(sum_sq / count);
    for &x in &program.inputs {
        count += 1.0;
        sum_sq += x * x;
        out.push(sum_sq / count);
    }
    out
}

/// Running root-mean-square (quadratic mean):
/// `RMS_t = √((1/t) · Σ_{i ≤ t} xᵢ²)`.
///
/// Online accumulator over squared values. First emitted value is
/// `|initial|`; each subsequent step folds `x²` into the running
/// sum and emits `√(sum_sq / count)`.
///
/// Iter-225 — completes the quartet of online means on the EML
/// stack: AM (iter-90), GM (iter-213), HM (iter-219), QM (this
/// iter). The Power-Mean inequality QM ≥ AM ≥ GM ≥ HM holds at
/// every prefix on positive data.
pub fn running_quadratic_mean(program: &ScanProgram<f64>) -> Vec<f64> {
    let mut count = 1.0_f64;
    let mut sum_sq = program.initial * program.initial;
    let mut out = Vec::with_capacity(program.output_count());
    out.push((sum_sq / count).sqrt());
    for &x in &program.inputs {
        count += 1.0;
        sum_sq += x * x;
        out.push((sum_sq / count).sqrt());
    }
    out
}

/// Running harmonic mean of a positive stream:
/// `HM_t = t / Σ_{i ≤ t} (1 / xᵢ)`.
///
/// Online accumulator over reciprocals (constant memory). Returns
/// the program's `initial` value as the first emitted output;
/// subsequent steps maintain `sum_recip += 1/x_t` and emit
/// `count / sum_recip`.
///
/// Returns NaN at any step where the next input is non-positive
/// (preserves the AM ≥ GM ≥ HM regime contract on the prefix).
///
/// Iter-219 — companion to `running_mean` (AM, iter-90) and
/// `running_geometric_mean` (GM, iter-213); together they expose
/// the full streaming AM-GM-HM triad.
pub fn running_harmonic_mean(program: &ScanProgram<f64>) -> Vec<f64> {
    let mut count = 1.0_f64;
    let mut sum_recip = if program.initial > 0.0 {
        1.0 / program.initial
    } else {
        f64::NAN
    };
    let mut out = Vec::with_capacity(program.output_count());
    out.push(program.initial);
    for &x in &program.inputs {
        count += 1.0;
        if x > 0.0 && sum_recip.is_finite() {
            sum_recip += 1.0 / x;
            out.push(count / sum_recip);
        } else {
            sum_recip = f64::NAN;
            out.push(f64::NAN);
        }
    }
    out
}

/// Running geometric mean of a positive stream:
/// `GM_t = exp((1/t) · Σ_{i ≤ t} ln(x_i))`.
///
/// Computed via the additive recurrence on log-space (avoids
/// product overflow):
///
///   sum_log_{t} = sum_log_{t-1} + ln(x_t)
///   GM_t        = exp(sum_log_t / count_t)
///
/// `initial` is taken as the first emitted value (must be > 0
/// for the running statistics to be meaningful — callers may use
/// 1 as a neutral starting GM). Returns NaN at any step where the
/// next input is non-positive.
///
/// Iter-213 — positive-data online aggregate; companion to
/// `running_mean` (arithmetic) and `running_l1_norm` (sum-abs).
pub fn running_geometric_mean(program: &ScanProgram<f64>) -> Vec<f64> {
    let mut count = 1.0_f64;
    let mut sum_log = if program.initial > 0.0 {
        program.initial.ln()
    } else {
        f64::NAN
    };
    let mut out = Vec::with_capacity(program.output_count());
    out.push(program.initial);
    for &x in &program.inputs {
        count += 1.0;
        if x > 0.0 && sum_log.is_finite() {
            sum_log += x.ln();
            out.push((sum_log / count).exp());
        } else {
            sum_log = f64::NAN;
            out.push(f64::NAN);
        }
    }
    out
}

/// Running L2 (Euclidean) norm of the prefix.
///
/// At step `t`, returns `√(initial² + Σ_{i ≤ t} x_i²)`. Computed
/// in one pass via the recurrence `state_t = √(state_{t-1}² + x_t²)`
/// — a Pythagorean fold, monotonically non-decreasing.
///
/// Iter-201 — Euclidean companion to `running_l1_norm` (L¹) and
/// `running_max_abs` (L^∞). Useful for cumulative-gradient-norm
/// tracking and convergence diagnostics on long sequences.
pub fn running_l2_norm(program: &ScanProgram<f64>) -> Vec<f64> {
    sequential_scan(program, |state, input| (state * state + input * input).sqrt())
}

/// Running range `max - min` over the prefix.
///
/// At step `t`, returns `max_{0..=t} x_i − min_{0..=t} x_i`.
/// Bounded below by zero; monotonically non-decreasing.
///
/// Iter-195 — companion to `running_min_max_pair` (iter-127);
/// useful as a one-number "spread so far" diagnostic for stream
/// monitoring and outlier-burst detection.
pub fn running_range(program: &ScanProgram<f64>) -> Vec<f64> {
    let pairs = running_min_max_pair(program);
    pairs.into_iter().map(|(lo, hi)| hi - lo).collect()
}

/// Numerically stable running log-sum-exp.
///
/// At step `t`, returns `ln(Σ_{i ≤ t} exp(x_i))` computed via the
/// shift-and-rescale identity
///
///   LSE(prev, x) = m + ln(exp(prev − m) + exp(x − m)),  m = max(prev, x).
///
/// Avoids overflow on large positives and preserves precision on
/// large-magnitude differences. The first emitted value is the
/// program's `initial` (taken as a starting log-sum-exp).
///
/// Iter-189 — foundational primitive for streaming softmax
/// denominators + sequential beam search.
pub fn running_log_sum_exp(program: &ScanProgram<f64>) -> Vec<f64> {
    sequential_scan(program, |state, input| {
        let m = if state >= input { *state } else { *input };
        if m.is_infinite() && m < 0.0 {
            return f64::NEG_INFINITY;
        }
        m + ((state - m).exp() + (input - m).exp()).ln()
    })
}

/// Running mean of absolute values: `Σ_{i≤t} |xᵢ| / (t+1)`.
///
/// Online L¹ mean — the average magnitude of the prefix. The
/// first emitted value is `|initial|`; subsequent steps fold
/// the running sum-of-abs and normalize by the count.
///
/// Iter-273 — companion to `running_l1_norm` (sum-form) and
/// `running_mean` (arithmetic). The "expected absolute value"
/// of a stream, useful in robust statistics (MAD numerator) and
/// gradient-stability monitoring.
pub fn running_mean_abs(program: &ScanProgram<f64>) -> Vec<f64> {
    let mut count = 1.0_f64;
    let mut sum_abs = program.initial.abs();
    let mut out = Vec::with_capacity(program.output_count());
    out.push(sum_abs / count);
    for &x in &program.inputs {
        count += 1.0;
        sum_abs += x.abs();
        out.push(sum_abs / count);
    }
    out
}

/// Running L1 norm: running sum of absolute values.
///
/// At step `t`, returns `|initial| + Σ |inputs[0..t]|`.
///
/// Iter-135 — useful for gradient-norm tracking and convergence
/// diagnostics.
pub fn running_l1_norm(program: &ScanProgram<f64>) -> Vec<f64> {
    sequential_scan(program, |state, input| state.abs() + input.abs())
}

/// Running max-abs (chebyshev / L-infinity norm of the prefix):
/// `max_{0..=t} |x_i|`.
///
/// Iter-135 — companion to running_l1_norm; useful for spike-
/// detection and bound monitoring.
pub fn running_max_abs(program: &ScanProgram<f64>) -> Vec<f64> {
    let mut max_abs = program.initial.abs();
    let mut out = Vec::with_capacity(program.output_count());
    out.push(max_abs);
    for &x in &program.inputs {
        let ax = x.abs();
        if ax > max_abs {
            max_abs = ax;
        }
        out.push(max_abs);
    }
    out
}

/// Running count of inputs above a threshold.
///
/// At step `t`, returns the number of elements in
/// `[initial, inputs[0], …, inputs[t-1]]` strictly greater than
/// `threshold`.
///
/// Iter-126 — useful for outlier counting, threshold-based
/// alerting, and CUSUM-style change-point detection.
pub fn running_count_above(program: &ScanProgram<f64>, threshold: f64) -> Vec<u64> {
    let mut count: u64 = if program.initial > threshold { 1 } else { 0 };
    let mut out = Vec::with_capacity(program.output_count());
    out.push(count);
    for &x in &program.inputs {
        if x > threshold {
            count += 1;
        }
        out.push(count);
    }
    out
}

/// Running proportion below threshold:
/// `r_t = count_below_t / (t + 1)`.
///
/// Iter-267 — companion to `running_above_ratio` (iter-261);
/// lower-tail proportion estimator.
pub fn running_below_ratio(program: &ScanProgram<f64>, threshold: f64) -> Vec<f64> {
    let mut count_below: u64 = if program.initial < threshold { 1 } else { 0 };
    let mut total: u64 = 1;
    let mut out = Vec::with_capacity(program.output_count());
    out.push(count_below as f64 / total as f64);
    for &x in &program.inputs {
        total += 1;
        if x < threshold {
            count_below += 1;
        }
        out.push(count_below as f64 / total as f64);
    }
    out
}

/// Running count of strictly positive inputs in the prefix.
///
/// Iter-297 — sign-stratified counter; companion to
/// `running_count_negative` (iter-291).
pub fn running_count_positive(program: &ScanProgram<f64>) -> Vec<u64> {
    let mut count: u64 = if program.initial > 0.0 { 1 } else { 0 };
    let mut out = Vec::with_capacity(program.output_count());
    out.push(count);
    for &x in &program.inputs {
        if x > 0.0 {
            count += 1;
        }
        out.push(count);
    }
    out
}

/// Running count of strictly negative inputs in the prefix.
///
/// At step `t`, returns the number of elements in
/// `[initial, x_0, …, x_{t-1}]` with `x_i < 0`. Monotone
/// non-decreasing.
///
/// Iter-291 — sign-stratified counter. Pairs with
/// `running_above_ratio` / `running_below_ratio` for a
/// signed-direction stream-monitoring trio.
pub fn running_count_negative(program: &ScanProgram<f64>) -> Vec<u64> {
    let mut count: u64 = if program.initial < 0.0 { 1 } else { 0 };
    let mut out = Vec::with_capacity(program.output_count());
    out.push(count);
    for &x in &program.inputs {
        if x < 0.0 {
            count += 1;
        }
        out.push(count);
    }
    out
}

/// Running count of inputs in the inclusive interval `[lo, hi]`.
///
/// At step `t`, returns the number of elements in
/// `[initial, x_0, …, x_{t-1}]` satisfying `lo ≤ xᵢ ≤ hi`.
/// Monotonically non-decreasing. `lo > hi` returns counts of
/// zero throughout (empty interval).
///
/// Iter-285 — histogram-bin online counter. Pairs with
/// `running_count_above` (iter-126) and `running_count_below`
/// (iter-207); the in-range version is the central case
/// between the two threshold-tail counters.
pub fn running_count_in_range(
    program: &ScanProgram<f64>,
    lo: f64,
    hi: f64,
) -> Vec<u64> {
    let in_range = |x: f64| x >= lo && x <= hi;
    let mut count: u64 = if in_range(program.initial) { 1 } else { 0 };
    let mut out = Vec::with_capacity(program.output_count());
    out.push(count);
    for &x in &program.inputs {
        if in_range(x) {
            count += 1;
        }
        out.push(count);
    }
    out
}

/// Running proportion above threshold:
/// `r_t = count_above_t / (t + 1)`.
///
/// Online estimate of P(X > threshold) using the empirical
/// distribution of the prefix. Bounded in `[0, 1]`.
///
/// Iter-261 — companion to `running_count_above` (iter-126) and
/// `running_count_below` (iter-207); this is the normalized
/// ratio form useful for proportion estimation and tail-mass
/// monitoring.
pub fn running_above_ratio(program: &ScanProgram<f64>, threshold: f64) -> Vec<f64> {
    let mut count_above: u64 = if program.initial > threshold { 1 } else { 0 };
    let mut total: u64 = 1;
    let mut out = Vec::with_capacity(program.output_count());
    out.push(count_above as f64 / total as f64);
    for &x in &program.inputs {
        total += 1;
        if x > threshold {
            count_above += 1;
        }
        out.push(count_above as f64 / total as f64);
    }
    out
}

/// Running count of inputs strictly below a threshold.
///
/// At step `t`, returns the number of elements in
/// `[initial, inputs[0], …, inputs[t-1]]` strictly less than
/// `threshold`. Complements [`running_count_above`]; together
/// with the prefix length they sum to the count of strictly-equal
/// entries.
///
/// Iter-207 — useful for lower-tail outlier counting, two-sided
/// CUSUM, and empirical-CDF tracking.
pub fn running_count_below(program: &ScanProgram<f64>, threshold: f64) -> Vec<u64> {
    let mut count: u64 = if program.initial < threshold { 1 } else { 0 };
    let mut out = Vec::with_capacity(program.output_count());
    out.push(count);
    for &x in &program.inputs {
        if x < threshold {
            count += 1;
        }
        out.push(count);
    }
    out
}

/// Running z-score: at each step `t ≥ 2`, returns
/// `(x_t − μ_t) / σ_t` where μ_t and σ_t are the running mean and
/// (population) standard deviation through step `t`.
///
/// Steps 0 and 1 return 0 (insufficient data for a meaningful
/// z-score with population variance). Steps with `σ_t = 0` also
/// return 0 to avoid division by zero.
///
/// Iter-151 — useful for online standardization in streaming
/// normalization layers.
pub fn running_zscore(program: &ScanProgram<f64>) -> Vec<f64> {
    let mut count = 1.0_f64;
    let mut mean = program.initial;
    let mut m2 = 0.0_f64;

    let mut out = Vec::with_capacity(program.output_count());
    out.push(0.0); // single sample → z-score undefined.

    for &x in &program.inputs {
        count += 1.0;
        let delta = x - mean;
        mean += delta / count;
        let delta2 = x - mean;
        m2 += delta * delta2;
        let variance = m2 / count;
        if variance > 1e-12 {
            out.push((x - mean) / variance.sqrt());
        } else {
            out.push(0.0);
        }
    }
    out
}

/// Running standardized skewness `g_1 = m_3 / σ^3` via Welford-style
/// online update.
///
/// At each step, returns g_1 = (M3 / n) / (M2 / n)^{3/2}, where M2
/// and M3 are the second and third central moments accumulated so
/// far. Returns 0 for steps with zero variance.
///
/// Iter-171 — standardized skewness companion to
/// running_third_central_moment (iter-165).
pub fn running_skewness(program: &ScanProgram<f64>) -> Vec<f64> {
    let mut count = 1.0_f64;
    let mut mean = program.initial;
    let mut m2 = 0.0_f64;
    let mut m3 = 0.0_f64;

    let mut out = Vec::with_capacity(program.output_count());
    out.push(0.0);

    for &x in &program.inputs {
        let n1 = count;
        count += 1.0;
        let delta = x - mean;
        let delta_n = delta / count;
        let term1 = delta * delta_n * n1;
        m3 += term1 * delta_n * (count - 2.0) - 3.0 * delta_n * m2;
        m2 += term1;
        mean += delta_n;

        let variance = m2 / count;
        if variance > 1e-12 {
            let m3_norm = m3 / count;
            let sigma3 = variance.sqrt().powi(3);
            out.push(m3_norm / sigma3);
        } else {
            out.push(0.0);
        }
    }
    out
}

/// Running standardized excess kurtosis `g_2 = m_4 / σ^4 - 3` via
/// Welford-style online update. Excess kurtosis is 0 for Gaussian
/// distributions; positive for heavy-tailed (leptokurtic); negative
/// for light-tailed (platykurtic).
///
/// Returns 0 when variance is zero (insufficient samples).
///
/// Iter-183 — companion to running_fourth_central_moment (iter-175).
pub fn running_kurtosis(program: &ScanProgram<f64>) -> Vec<f64> {
    let mut count = 1.0_f64;
    let mut mean = program.initial;
    let mut m2 = 0.0_f64;
    let mut m3 = 0.0_f64;
    let mut m4 = 0.0_f64;

    let mut out = Vec::with_capacity(program.output_count());
    out.push(0.0);

    for &x in &program.inputs {
        let n1 = count;
        count += 1.0;
        let delta = x - mean;
        let delta_n = delta / count;
        let delta_n2 = delta_n * delta_n;
        let term1 = delta * delta_n * n1;
        m4 += term1 * delta_n2 * (count * count - 3.0 * count + 3.0)
            + 6.0 * delta_n2 * m2
            - 4.0 * delta_n * m3;
        m3 += term1 * delta_n * (count - 2.0) - 3.0 * delta_n * m2;
        m2 += term1;
        mean += delta_n;

        let variance = m2 / count;
        if variance > 1e-12 {
            let m4_norm = m4 / count;
            let sigma4 = variance * variance;
            out.push(m4_norm / sigma4 - 3.0);
        } else {
            out.push(0.0);
        }
    }
    out
}

/// Running fourth central moment `M4 / n` via Welford-style online
/// update.
///
/// `m_4 = (1/n) · Σ (x_i − μ_t)⁴`. Building block for kurtosis
/// (g_2 = m_4 / σ⁴ − 3, normalized) and tail-heaviness diagnostics.
///
/// Iter-175 — Welford four-moment recursion (Terriberry 2007).
pub fn running_fourth_central_moment(program: &ScanProgram<f64>) -> Vec<f64> {
    let mut count = 1.0_f64;
    let mut mean = program.initial;
    let mut m2 = 0.0_f64;
    let mut m3 = 0.0_f64;
    let mut m4 = 0.0_f64;

    let mut out = Vec::with_capacity(program.output_count());
    out.push(0.0);

    for &x in &program.inputs {
        let n1 = count;
        count += 1.0;
        let delta = x - mean;
        let delta_n = delta / count;
        let delta_n2 = delta_n * delta_n;
        let term1 = delta * delta_n * n1;
        // Update higher moments first (use old mean/m2/m3).
        m4 += term1 * delta_n2 * (count * count - 3.0 * count + 3.0)
            + 6.0 * delta_n2 * m2
            - 4.0 * delta_n * m3;
        m3 += term1 * delta_n * (count - 2.0) - 3.0 * delta_n * m2;
        m2 += term1;
        mean += delta_n;
        out.push(m4 / count);
    }
    out
}

/// Running third central moment `M3 / n` via Welford-style online
/// update. At step `t`, returns the third central moment
/// `(1/t) · Σ (x_i − μ_t)³` from `initial` through `inputs[t-1]`.
///
/// This is the un-normalized "skewness numerator". Divide by
/// `σ_t³` externally to get standardized skewness `g_1`.
///
/// Iter-165 — extends running statistics beyond mean/variance.
pub fn running_third_central_moment(program: &ScanProgram<f64>) -> Vec<f64> {
    let mut count = 1.0_f64;
    let mut mean = program.initial;
    let mut m2 = 0.0_f64;
    let mut m3 = 0.0_f64;

    let mut out = Vec::with_capacity(program.output_count());
    out.push(0.0); // single sample → m3 = 0.

    for &x in &program.inputs {
        let n1 = count;
        count += 1.0;
        let delta = x - mean;
        let delta_n = delta / count;
        let term1 = delta * delta_n * n1;
        // Update m3 first (uses old mean).
        m3 += term1 * delta_n * (count - 2.0) - 3.0 * delta_n * m2;
        m2 += term1;
        mean += delta_n;
        out.push(m3 / count);
    }
    out
}

/// Running sum of squared consecutive differences: at each step
/// `t ≥ 1`, returns `Σ_{i=1..=t} (x_i − x_{i-1})²`.
///
/// Useful as a convergence-rate diagnostic; for a steady-state
/// signal the running sum saturates.
///
/// Iter-159 — companion to first_difference (iter-145) for
/// numerical-stability monitoring.
pub fn running_squared_differences(program: &ScanProgram<f64>) -> Vec<f64> {
    let mut acc = 0.0_f64;
    let mut prev = program.initial;
    let mut out = Vec::with_capacity(program.output_count());
    out.push(0.0); // no differences yet at step 0.
    for &x in &program.inputs {
        let d = x - prev;
        acc += d * d;
        out.push(acc);
        prev = x;
    }
    out
}

/// First-difference operator: `Δx_t = inputs[t] − inputs[t-1]`
/// for `t = 1..n`, with `inputs[0] − initial` as the first
/// difference.
///
/// Returns a vector of length `n` (one fewer than `output_count`).
/// Differs from the typical scan signature; that's intentional —
/// differences are a fence-post quantity that doesn't have an
/// initial-state value.
///
/// Iter-145 — useful for derivative-style stream processing and
/// rate-of-change monitoring.
pub fn first_difference(program: &ScanProgram<f64>) -> Vec<f64> {
    if program.inputs.is_empty() {
        return Vec::new();
    }
    let mut out = Vec::with_capacity(program.inputs.len());
    let mut prev = program.initial;
    for &x in &program.inputs {
        out.push(x - prev);
        prev = x;
    }
    out
}

/// Running argmin: returns `(index, value)` pairs at each step,
/// where `index` is the position of the running min-so-far.
///
/// Position 0 = initial. Positions 1..=n correspond to inputs[0..n-1].
/// First-occurrence wins ties.
///
/// Iter-139 — companion to running_argmax (iter-120). Useful for
/// nadir detection, drawdown tracking, and convergence diagnostics.
pub fn running_argmin(program: &ScanProgram<f64>) -> Vec<(usize, f64)> {
    let mut min_idx: usize = 0;
    let mut min_val = program.initial;
    let mut current: usize = 0;
    let mut out = Vec::with_capacity(program.output_count());
    out.push((min_idx, min_val));
    for &x in &program.inputs {
        current += 1;
        if x < min_val {
            min_idx = current;
            min_val = x;
        }
        out.push((min_idx, min_val));
    }
    out
}

/// Running argmax: returns `(index, value)` pairs at each step,
/// where `index` is the position of the running max-so-far.
///
/// Position 0 = initial state. Positions 1..=n correspond to
/// inputs[0..n-1]. First occurrence wins ties.
///
/// Iter-120 — change-point detection, Viterbi backtrack, and
/// peak-tracking primitive.
pub fn running_argmax(program: &ScanProgram<f64>) -> Vec<(usize, f64)> {
    let mut max_idx: usize = 0;
    let mut max_val = program.initial;
    let mut current: usize = 0;
    let mut out = Vec::with_capacity(program.output_count());
    out.push((max_idx, max_val));
    for &x in &program.inputs {
        current += 1;
        if x > max_val {
            max_idx = current;
            max_val = x;
        }
        out.push((max_idx, max_val));
    }
    out
}

/// Track both running min and running max in a single pass.
/// Returns a vector of `(min, max)` pairs at each step.
///
/// More efficient than running min and max separately (one pass
/// through the inputs instead of two).
///
/// Iter-114 — useful for one-shot range estimation in streaming
/// statistics, anomaly-bound determination, and Bayesian
/// uniform-prior estimation.
pub fn running_min_max_pair(program: &ScanProgram<f64>) -> Vec<(f64, f64)> {
    let mut min = program.initial;
    let mut max = program.initial;
    let mut out = Vec::with_capacity(program.output_count());
    out.push((min, max));
    for &x in &program.inputs {
        if x < min {
            min = x;
        }
        if x > max {
            max = x;
        }
        out.push((min, max));
    }
    out
}

/// Running variance via Welford's online algorithm:
///
/// `state_{t+1} = (count + 1, μ + δ/(count+1), M2 + δ·(x - μ_new))`
///
/// where `δ = x - μ` is the increment of the new sample. Returns
/// the **population variance** `M2 / count` at each step (use
/// `M2 / (count - 1)` externally for the unbiased sample variance).
///
/// Properties:
/// - Initial state contributes as the first sample.
/// - Output[0] = 0 (variance of a single sample).
/// - Numerically stable across long streams (Welford 1962).
///
/// Iter-107 — building block for streaming standardization,
/// anomaly detection, and online statistics monitoring.
pub fn running_variance(program: &ScanProgram<f64>) -> Vec<f64> {
    let mut count = 1.0_f64;
    let mut mean = program.initial;
    let mut m2 = 0.0_f64;

    let mut out = Vec::with_capacity(program.output_count());
    out.push(0.0); // variance of a single sample = 0 by convention.

    for &x in &program.inputs {
        count += 1.0;
        let delta = x - mean;
        mean += delta / count;
        let delta2 = x - mean;
        m2 += delta * delta2;
        out.push(m2 / count); // population variance
    }
    out
}

/// Exponentially-weighted moving average:
/// `state_{t+1} = α · state_t + (1 - α) · input_t`
///
/// where `α ∈ [0, 1]` is the smoothing / decay factor:
/// - `α = 0`: no smoothing (output ≡ input shifted).
/// - `α = 1`: never updates (output ≡ initial).
/// - `α ≈ 0.9–0.999`: typical Adam / momentum / EMA filter values.
///
/// Iter-102 — used in Adam optimizer momentum tracks, Polyak
/// averaging of model weights, real-time signal smoothing.
pub fn running_ema(program: &ScanProgram<f64>, alpha: f64) -> Vec<f64> {
    sequential_scan(program, move |state, input| alpha * state + (1.0 - alpha) * input)
}

/// Running running-mean: at each step, the arithmetic mean of all
/// values seen so far (treating `program.initial` as the starting
/// "empty-prefix mean").
///
/// At step `k` (1-indexed), output equals
/// `(initial + Σ_{i=1..=k} inputs[i-1]) / (k + 1)` — this includes
/// `initial` in the average. Caller can compensate by setting
/// `initial = 0.0` and dividing each output by step-index k.
///
/// Iter-90 — useful for running-statistics monitoring in scan
/// streams.
pub fn running_mean(program: &ScanProgram<f64>) -> Vec<f64> {
    let mut out = Vec::with_capacity(program.output_count());
    let mut sum = program.initial;
    let mut count: f64 = 1.0;
    out.push(sum);
    for input in &program.inputs {
        sum += input;
        count += 1.0;
        out.push(sum / count);
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn empty_program_yields_initial_only() {
        let p: ScanProgram<i32> = ScanProgram::just_initial(42);
        let out = sequential_scan(&p, |a, b| a + b);
        assert_eq!(out, vec![42]);
    }

    #[test]
    fn integer_add_scan_yields_prefix_sums() {
        let p = ScanProgram::new(0i32, vec![1, 2, 3, 4]);
        let out = sequential_scan(&p, |a, b| a + b);
        assert_eq!(out, vec![0, 1, 3, 6, 10]);
    }

    #[test]
    fn integer_max_scan_yields_running_max() {
        let p = ScanProgram::new(0i32, vec![3, 1, 4, 1, 5, 9, 2, 6]);
        let out = sequential_scan(&p, |a, b| *a.max(b));
        assert_eq!(out, vec![0, 3, 3, 4, 4, 5, 9, 9, 9]);
    }

    #[test]
    fn output_length_is_one_plus_step_count() {
        let p = ScanProgram::new(0i32, vec![1, 2, 3, 4, 5]);
        let out = sequential_scan(&p, |a, b| a + b);
        assert_eq!(out.len(), p.output_count());
    }

    #[test]
    fn first_output_is_initial() {
        let p = ScanProgram::new(100i32, vec![1, 2]);
        let out = sequential_scan(&p, |a, b| a + b);
        assert_eq!(out[0], 100);
    }

    #[test]
    fn last_output_equals_reduce() {
        let p = ScanProgram::new(0i32, vec![1, 2, 3, 4]);
        let scan_out = sequential_scan(&p, |a, b| a + b);
        let reduce_out = sequential_reduce(&p, |a, b| a + b);
        assert_eq!(*scan_out.last().unwrap(), reduce_out);
    }

    #[test]
    fn string_concat_scan() {
        let p = ScanProgram::new("".to_string(), vec!["a".to_string(), "b".to_string(), "c".to_string()]);
        let out = sequential_scan(&p, |a, b| format!("{}{}", a, b));
        assert_eq!(out, vec!["".to_string(), "a".into(), "ab".into(), "abc".into()]);
    }

    #[test]
    fn reduce_empty_is_initial() {
        let p: ScanProgram<i32> = ScanProgram::just_initial(7);
        assert_eq!(sequential_reduce(&p, |a, b| a + b), 7);
    }

    #[test]
    fn associative_op_invariance_check() {
        // For an associative op, scan output[i+1] = op(output[i], inputs[i]).
        // This is the recursive characterization of scan.
        let p = ScanProgram::new(0i32, vec![1, 2, 3, 4, 5]);
        let op = |a: &i32, b: &i32| a + b;
        let out = sequential_scan(&p, op);
        for i in 0..p.step_count() {
            assert_eq!(out[i + 1], op(&out[i], &p.inputs[i]));
        }
    }

    // ── iter-90: running aggregator wrappers ─────────────────────

    #[test]
    fn running_sum_matches_prefix_sums() {
        let p = ScanProgram::new(0.0_f64, vec![1.0, 2.0, 3.0, 4.0]);
        let out = running_sum(&p);
        assert_eq!(out, vec![0.0, 1.0, 3.0, 6.0, 10.0]);
    }

    #[test]
    fn running_max_tracks_high_water_mark() {
        let p = ScanProgram::new(0.0_f64, vec![1.5, 0.5, 3.0, 2.0, 4.5]);
        let out = running_max(&p);
        assert_eq!(out, vec![0.0, 1.5, 1.5, 3.0, 3.0, 4.5]);
    }

    #[test]
    fn running_min_tracks_low_water_mark() {
        let p = ScanProgram::new(10.0_f64, vec![3.0, 5.0, -1.0, 2.0, 0.0]);
        let out = running_min(&p);
        assert_eq!(out, vec![10.0, 3.0, 3.0, -1.0, -1.0, -1.0]);
    }

    #[test]
    fn running_product_compounds() {
        let p = ScanProgram::new(1.0_f64, vec![2.0, 3.0, 0.5, 4.0]);
        let out = running_product(&p);
        assert_eq!(out, vec![1.0, 2.0, 6.0, 3.0, 12.0]);
    }

    #[test]
    fn running_mean_converges() {
        // Mean of (1, 1, 1, 1) = 1; with initial=0 we have running
        // means: 0/1=0, 1/2=0.5, 2/3, 3/4, 4/5.
        let p = ScanProgram::new(0.0_f64, vec![1.0, 1.0, 1.0, 1.0]);
        let out = running_mean(&p);
        let expected = vec![0.0, 0.5, 2.0 / 3.0, 0.75, 0.8];
        for (a, b) in out.iter().zip(expected.iter()) {
            assert!((a - b).abs() < 1e-12, "got {} expected {}", a, b);
        }
    }

    // ── iter-135: running_l1_norm + running_max_abs ───────────────

    #[test]
    fn running_l1_norm_accumulates_abs() {
        // initial=1, inputs=(-2, 3, -4):
        // step 0: |1| = 1
        // step 1: 1 + |-2| = 3 (wait, state=1, op = |state|+|input| applied,
        //                       so state→ |1| + |-2| = 3)
        // step 2: |3| + |3| = 6
        // step 3: |6| + |-4| = 10
        let p = ScanProgram::new(1.0_f64, vec![-2.0, 3.0, -4.0]);
        let out = running_l1_norm(&p);
        assert_eq!(out, vec![1.0, 3.0, 6.0, 10.0]);
    }

    #[test]
    fn running_max_abs_tracks_largest_magnitude() {
        let p = ScanProgram::new(0.0_f64, vec![1.0, -3.0, 2.0, -0.5, 5.0]);
        let out = running_max_abs(&p);
        assert_eq!(out, vec![0.0, 1.0, 3.0, 3.0, 3.0, 5.0]);
    }

    #[test]
    fn running_max_abs_with_negative_initial() {
        let p = ScanProgram::new(-7.0_f64, vec![1.0, 2.0, 3.0]);
        let out = running_max_abs(&p);
        // |initial| = 7, never exceeded.
        assert_eq!(out, vec![7.0, 7.0, 7.0, 7.0]);
    }

    #[test]
    fn running_max_abs_zero_stream() {
        let p = ScanProgram::new(0.0_f64, vec![0.0, 0.0, 0.0]);
        let out = running_max_abs(&p);
        assert_eq!(out, vec![0.0, 0.0, 0.0, 0.0]);
    }

    // ── iter-126: running_count_above ─────────────────────────────

    #[test]
    fn running_count_above_threshold_below_initial() {
        // threshold=0, initial=1 → count starts at 1.
        let p = ScanProgram::new(1.0_f64, vec![2.0, -1.0, 3.0]);
        let out = running_count_above(&p, 0.0);
        assert_eq!(out, vec![1, 2, 2, 3]);
    }

    #[test]
    fn running_count_above_threshold_above_initial() {
        // threshold=5, initial=1 → count starts at 0.
        let p = ScanProgram::new(1.0_f64, vec![3.0, 6.0, 4.0, 10.0]);
        let out = running_count_above(&p, 5.0);
        assert_eq!(out, vec![0, 0, 1, 1, 2]);
    }

    #[test]
    fn running_count_above_all_below() {
        let p = ScanProgram::new(0.0_f64, vec![-1.0, -2.0, -3.0]);
        let out = running_count_above(&p, 10.0);
        assert_eq!(out, vec![0, 0, 0, 0]);
    }

    #[test]
    fn running_count_above_strict_inequality() {
        // threshold=5, x=5 (equal) is NOT counted.
        let p = ScanProgram::new(5.0_f64, vec![5.0, 5.0]);
        let out = running_count_above(&p, 5.0);
        assert_eq!(out, vec![0, 0, 0]);
    }

    // ── iter-255: running_max_drawup ──────────────────────────────

    #[test]
    fn running_max_drawup_monotone_down_stays_zero() {
        let p = ScanProgram::new(10.0_f64, vec![5.0, 0.0, -5.0]);
        let out = running_max_drawup(&p);
        for v in &out {
            assert_eq!(*v, 0.0);
        }
    }

    #[test]
    fn running_max_drawup_trough_then_peak() {
        // (5, 2, 8, 1, 9): trough 5→2→2→1→1; drawup 0→0→6→6→8.
        let p = ScanProgram::new(5.0_f64, vec![2.0, 8.0, 1.0, 9.0]);
        let out = running_max_drawup(&p);
        assert_eq!(out, vec![0.0, 0.0, 6.0, 6.0, 8.0]);
    }

    #[test]
    fn running_max_drawup_monotone_nondecreasing() {
        let p = ScanProgram::new(0.0_f64, vec![10.0, -5.0, 7.0, -10.0, 12.0]);
        let out = running_max_drawup(&p);
        for win in out.windows(2) {
            assert!(win[1] >= win[0] - 1e-12);
        }
    }

    #[test]
    fn running_max_drawup_constant_stream_is_zero() {
        let p = ScanProgram::new(5.0_f64, vec![5.0, 5.0]);
        let out = running_max_drawup(&p);
        for v in &out {
            assert_eq!(*v, 0.0);
        }
    }

    // ── iter-273: running_mean_abs ────────────────────────────────

    #[test]
    fn running_mean_abs_first_emit_is_abs_initial() {
        let p = ScanProgram::new(-5.0_f64, vec![]);
        let out = running_mean_abs(&p);
        assert_eq!(out, vec![5.0]);
    }

    #[test]
    fn running_mean_abs_signed_doesnt_change_mean() {
        // Negated stream gives same mean-abs.
        let p_pos = ScanProgram::new(3.0_f64, vec![4.0, 5.0]);
        let p_neg = ScanProgram::new(-3.0_f64, vec![-4.0, -5.0]);
        let pos = running_mean_abs(&p_pos);
        let neg = running_mean_abs(&p_neg);
        assert_eq!(pos, neg);
    }

    #[test]
    fn running_mean_abs_known() {
        // |3|, |−4|, |5|: cumulative (3, 7, 12); count (1, 2, 3); means (3, 3.5, 4).
        let p = ScanProgram::new(3.0_f64, vec![-4.0, 5.0]);
        let out = running_mean_abs(&p);
        assert_eq!(out, vec![3.0, 3.5, 4.0]);
    }

    #[test]
    fn running_mean_abs_zero_stream_is_zero() {
        let p = ScanProgram::new(0.0_f64, vec![0.0, 0.0]);
        let out = running_mean_abs(&p);
        for v in &out {
            assert_eq!(*v, 0.0);
        }
    }

    // ── iter-249: running_min_abs ─────────────────────────────────

    #[test]
    fn running_min_abs_first_emit_is_abs_initial() {
        let p = ScanProgram::new(-5.0_f64, vec![]);
        let out = running_min_abs(&p);
        assert_eq!(out, vec![5.0]);
    }

    #[test]
    fn running_min_abs_finds_smallest_magnitude() {
        // |−3|, |2|, |−7|: min decreases to 2.
        let p = ScanProgram::new(-3.0_f64, vec![2.0, -7.0]);
        let out = running_min_abs(&p);
        assert_eq!(out, vec![3.0, 2.0, 2.0]);
    }

    #[test]
    fn running_min_abs_monotone_nonincreasing() {
        let p = ScanProgram::new(10.0_f64, vec![-5.0, 7.0, -1.0, 100.0]);
        let out = running_min_abs(&p);
        for win in out.windows(2) {
            assert!(win[1] <= win[0]);
        }
    }

    #[test]
    fn running_min_abs_zero_drops_to_zero() {
        let p = ScanProgram::new(5.0_f64, vec![0.0, -3.0]);
        let out = running_min_abs(&p);
        assert_eq!(out, vec![5.0, 0.0, 0.0]);
    }

    // ── iter-309: running_squared_increments ──────────────────────

    #[test]
    fn squared_increments_first_emit_is_zero() {
        let p = ScanProgram::new(5.0_f64, vec![]);
        let out = running_squared_increments(&p);
        assert_eq!(out, vec![0.0]);
    }

    #[test]
    fn squared_increments_known() {
        // (0, 3, 7, 5): diffs (3, 4, -2)² = (9, 16, 4); cumulative (0, 9, 25, 29).
        let p = ScanProgram::new(0.0_f64, vec![3.0, 7.0, 5.0]);
        let out = running_squared_increments(&p);
        assert_eq!(out, vec![0.0, 9.0, 25.0, 29.0]);
    }

    #[test]
    fn squared_increments_constant_stream_is_zero() {
        let p = ScanProgram::new(3.0_f64, vec![3.0, 3.0, 3.0]);
        let out = running_squared_increments(&p);
        for v in &out {
            assert_eq!(*v, 0.0);
        }
    }

    #[test]
    fn squared_increments_monotone_nondecreasing() {
        let p = ScanProgram::new(0.0_f64, vec![1.0, -2.0, 3.0, -4.0]);
        let out = running_squared_increments(&p);
        for win in out.windows(2) {
            assert!(win[1] >= win[0] - 1e-12);
        }
    }

    // ── iter-315: running_count_strict_increase ───────────────────

    #[test]
    fn strict_increase_monotone_up_increments_each_step() {
        let p = ScanProgram::new(0.0_f64, vec![1.0, 2.0, 3.0]);
        let out = running_count_strict_increase(&p);
        assert_eq!(out, vec![0, 1, 2, 3]);
    }

    #[test]
    fn strict_increase_monotone_down_stays_zero() {
        let p = ScanProgram::new(5.0_f64, vec![4.0, 3.0, 2.0]);
        let out = running_count_strict_increase(&p);
        for v in &out {
            assert_eq!(*v, 0);
        }
    }

    #[test]
    fn strict_increase_equal_doesnt_count() {
        let p = ScanProgram::new(2.0_f64, vec![2.0, 3.0, 3.0, 4.0]);
        let out = running_count_strict_increase(&p);
        // Equal → no increase; (2→2): no, (2→3): yes, (3→3): no, (3→4): yes.
        assert_eq!(out, vec![0, 0, 1, 1, 2]);
    }

    // ── iter-303: running_first_difference_abs ────────────────────

    #[test]
    fn first_difference_abs_first_emit_is_zero() {
        let p = ScanProgram::new(5.0_f64, vec![]);
        let out = running_first_difference_abs(&p);
        assert_eq!(out, vec![0.0]);
    }

    #[test]
    fn first_difference_abs_known() {
        // (0, 1, 3, 2): per-step |diffs| (0, 1, 2, 1).
        let p = ScanProgram::new(0.0_f64, vec![1.0, 3.0, 2.0]);
        let out = running_first_difference_abs(&p);
        assert_eq!(out, vec![0.0, 1.0, 2.0, 1.0]);
    }

    #[test]
    fn first_difference_abs_constant_stream_is_zero() {
        let p = ScanProgram::new(7.0_f64, vec![7.0, 7.0]);
        let out = running_first_difference_abs(&p);
        for v in &out {
            assert_eq!(*v, 0.0);
        }
    }

    #[test]
    fn first_difference_abs_sum_equals_total_variation_last() {
        // Σ per-step |Δ| over the stream = total_variation at the last index.
        let p = ScanProgram::new(0.0_f64, vec![1.0, -2.0, 3.0, -4.0]);
        let per = running_first_difference_abs(&p);
        let tv = running_total_variation(&p);
        let summed: f64 = per.iter().sum();
        assert!((summed - tv[tv.len() - 1]).abs() < 1e-12);
    }

    // ── iter-243: running_total_variation ─────────────────────────

    #[test]
    fn running_total_variation_constant_stream_is_zero() {
        let p = ScanProgram::new(3.0_f64, vec![3.0, 3.0, 3.0]);
        let out = running_total_variation(&p);
        for v in &out {
            assert_eq!(*v, 0.0);
        }
    }

    #[test]
    fn running_total_variation_known() {
        // (0, 1, 3, 2): diffs (1, 2, 1) → cumulative (0, 1, 3, 4).
        let p = ScanProgram::new(0.0_f64, vec![1.0, 3.0, 2.0]);
        let out = running_total_variation(&p);
        assert_eq!(out, vec![0.0, 1.0, 3.0, 4.0]);
    }

    #[test]
    fn running_total_variation_monotone_nondecreasing() {
        let p = ScanProgram::new(0.0_f64, vec![1.0, -2.0, 3.0, -4.0]);
        let out = running_total_variation(&p);
        for win in out.windows(2) {
            assert!(win[1] >= win[0]);
        }
    }

    #[test]
    fn running_total_variation_oscillating_unit_step_increments_each_step() {
        // (1, -1, 1, -1): each step has |diff| = 2 → out = (0, 2, 4, 6).
        let p = ScanProgram::new(1.0_f64, vec![-1.0, 1.0, -1.0]);
        let out = running_total_variation(&p);
        assert_eq!(out, vec![0.0, 2.0, 4.0, 6.0]);
    }

    // ── iter-237: running_max_drawdown ────────────────────────────

    #[test]
    fn running_max_drawdown_monotone_up_stays_zero() {
        let p = ScanProgram::new(1.0_f64, vec![2.0, 3.0, 4.0]);
        let out = running_max_drawdown(&p);
        for v in &out {
            assert_eq!(*v, 0.0);
        }
    }

    #[test]
    fn running_max_drawdown_peak_then_trough() {
        // (1, 5, 2, 8, 3): peaks 1→5→5→8→8; drawdowns 0→0→3→3→5.
        let p = ScanProgram::new(1.0_f64, vec![5.0, 2.0, 8.0, 3.0]);
        let out = running_max_drawdown(&p);
        assert_eq!(out, vec![0.0, 0.0, 3.0, 3.0, 5.0]);
    }

    #[test]
    fn running_max_drawdown_monotone_nondecreasing() {
        let p = ScanProgram::new(0.0_f64, vec![10.0, -5.0, 7.0, -10.0, 12.0]);
        let out = running_max_drawdown(&p);
        for win in out.windows(2) {
            assert!(win[1] >= win[0] - 1e-12);
        }
    }

    #[test]
    fn running_max_drawdown_constant_stream_is_zero() {
        let p = ScanProgram::new(5.0_f64, vec![5.0, 5.0]);
        let out = running_max_drawdown(&p);
        for v in &out {
            assert_eq!(*v, 0.0);
        }
    }

    // ── iter-231: running_sign_changes ────────────────────────────

    #[test]
    fn running_sign_changes_no_flips_stays_zero() {
        let p = ScanProgram::new(1.0_f64, vec![2.0, 3.0, 4.0]);
        let out = running_sign_changes(&p);
        assert_eq!(out, vec![0, 0, 0, 0]);
    }

    #[test]
    fn running_sign_changes_alternating_increments_each_step() {
        // (1, -1, 1, -1) → flips at 1, 2, 3.
        let p = ScanProgram::new(1.0_f64, vec![-1.0, 1.0, -1.0]);
        let out = running_sign_changes(&p);
        assert_eq!(out, vec![0, 1, 2, 3]);
    }

    #[test]
    fn running_sign_changes_zeros_continue_previous_sign() {
        // initial = -1 (neg); inputs (0, 0, 1) — only the 1 flips.
        let p = ScanProgram::new(-1.0_f64, vec![0.0, 0.0, 1.0]);
        let out = running_sign_changes(&p);
        assert_eq!(out, vec![0, 0, 0, 1]);
    }

    #[test]
    fn running_sign_changes_monotone_nondecreasing() {
        let p = ScanProgram::new(0.5_f64, vec![-0.5, 0.5, -0.5, 0.5]);
        let out = running_sign_changes(&p);
        for win in out.windows(2) {
            assert!(win[1] >= win[0]);
        }
    }

    // ── iter-279: running_mean_squared ────────────────────────────

    #[test]
    fn running_mean_squared_constant_stream() {
        let p = ScanProgram::new(3.0_f64, vec![3.0, 3.0]);
        let out = running_mean_squared(&p);
        for v in &out {
            assert!((v - 9.0).abs() < 1e-9);
        }
    }

    #[test]
    fn running_mean_squared_3_4_known() {
        // initial = 3, input = 4 → (9 + 16) / 2 = 12.5.
        let p = ScanProgram::new(3.0_f64, vec![4.0]);
        let out = running_mean_squared(&p);
        assert!((out[1] - 12.5).abs() < 1e-9);
    }

    #[test]
    fn running_mean_squared_is_quadratic_mean_squared() {
        // E[X²] = (QM)².
        let p = ScanProgram::new(1.0_f64, vec![2.0, 3.0, 4.0]);
        let ms = running_mean_squared(&p);
        let qm = running_quadratic_mean(&p);
        for (m, q) in ms.iter().zip(qm.iter()) {
            assert!((m - q * q).abs() < 1e-9);
        }
    }

    // ── iter-225: running_quadratic_mean (RMS) ────────────────────

    #[test]
    fn running_quadratic_mean_constant_stream() {
        let p = ScanProgram::new(3.0_f64, vec![3.0, 3.0]);
        let out = running_quadratic_mean(&p);
        for v in &out {
            assert!((v - 3.0).abs() < 1e-9);
        }
    }

    #[test]
    fn running_quadratic_mean_3_4_known() {
        // initial=3, input=4: RMS = √((9+16)/2) = √12.5 ≈ 3.5355.
        let p = ScanProgram::new(3.0_f64, vec![4.0]);
        let out = running_quadratic_mean(&p);
        assert!((out[1] - (12.5_f64).sqrt()).abs() < 1e-9, "got {}", out[1]);
    }

    #[test]
    fn running_quadratic_mean_signed_inputs_match_squared() {
        // RMS only cares about magnitudes.
        let p1 = ScanProgram::new(3.0_f64, vec![4.0, -5.0]);
        let p2 = ScanProgram::new(-3.0_f64, vec![-4.0, 5.0]);
        let o1 = running_quadratic_mean(&p1);
        let o2 = running_quadratic_mean(&p2);
        for (a, b) in o1.iter().zip(o2.iter()) {
            assert!((a - b).abs() < 1e-12);
        }
    }

    #[test]
    fn running_quadratic_mean_at_least_running_mean_abs() {
        // QM ≥ AM_abs on the absolute-value stream (power-mean monotonicity).
        let p = ScanProgram::new(1.0_f64, vec![2.0, 4.0, 8.0]);
        let qm = running_quadratic_mean(&p);
        let am = running_mean(&p); // all positive — equals AM_abs
        for (q, a) in qm.iter().zip(am.iter()) {
            assert!(*q >= *a - 1e-9, "qm={} am={}", q, a);
        }
    }

    // ── iter-219: running_harmonic_mean ───────────────────────────

    #[test]
    fn running_harmonic_mean_constant_stream() {
        let p = ScanProgram::new(4.0_f64, vec![4.0, 4.0]);
        let out = running_harmonic_mean(&p);
        for v in &out {
            assert!((v - 4.0).abs() < 1e-9);
        }
    }

    #[test]
    fn running_harmonic_mean_1_2_known() {
        // HM(1, 2) = 2 / (1 + 0.5) = 4/3.
        let p = ScanProgram::new(1.0_f64, vec![2.0]);
        let out = running_harmonic_mean(&p);
        assert!((out[1] - 4.0 / 3.0).abs() < 1e-9, "got {}", out[1]);
    }

    #[test]
    fn running_harmonic_mean_2_3_6_known() {
        // HM(2, 3, 6) = 3 / (1/2 + 1/3 + 1/6) = 3.
        let p = ScanProgram::new(2.0_f64, vec![3.0, 6.0]);
        let out = running_harmonic_mean(&p);
        assert!((out[2] - 3.0).abs() < 1e-9, "got {}", out[2]);
    }

    #[test]
    fn running_harmonic_mean_at_most_running_mean() {
        // AM ≥ HM on positive data.
        let p = ScanProgram::new(1.0_f64, vec![2.0, 4.0, 8.0]);
        let hm = running_harmonic_mean(&p);
        let am = running_mean(&p);
        for (h, a) in hm.iter().zip(am.iter()) {
            assert!(*h <= *a + 1e-9, "hm={} am={}", h, a);
        }
    }

    #[test]
    fn running_harmonic_mean_non_positive_propagates_nan() {
        let p = ScanProgram::new(1.0_f64, vec![-1.0, 4.0]);
        let out = running_harmonic_mean(&p);
        assert!(out[0].is_finite());
        assert!(out[1].is_nan());
        assert!(out[2].is_nan());
    }

    // ── iter-213: running_geometric_mean ──────────────────────────

    #[test]
    fn running_geometric_mean_constant_stream() {
        // GM(4, 4, 4) = 4.
        let p = ScanProgram::new(4.0_f64, vec![4.0, 4.0]);
        let out = running_geometric_mean(&p);
        for v in &out {
            assert!((v - 4.0).abs() < 1e-9, "got {}", v);
        }
    }

    #[test]
    fn running_geometric_mean_doubling_stream() {
        // 1, 2 → GM = √2; 1, 2, 4 → GM = ³√8 = 2.
        let p = ScanProgram::new(1.0_f64, vec![2.0, 4.0]);
        let out = running_geometric_mean(&p);
        assert!((out[0] - 1.0).abs() < 1e-12);
        assert!((out[1] - 2.0_f64.sqrt()).abs() < 1e-9);
        assert!((out[2] - 2.0).abs() < 1e-9);
    }

    #[test]
    fn running_geometric_mean_at_most_arithmetic_mean() {
        let p = ScanProgram::new(1.0_f64, vec![2.0, 4.0, 8.0]);
        let gm = running_geometric_mean(&p);
        let am = running_mean(&p);
        for (g, a) in gm.iter().zip(am.iter()) {
            assert!(*g <= *a + 1e-9, "gm={} am={}", g, a);
        }
    }

    #[test]
    fn running_geometric_mean_non_positive_input_produces_nan() {
        let p = ScanProgram::new(1.0_f64, vec![2.0, -1.0, 4.0]);
        let out = running_geometric_mean(&p);
        assert!(out[1].is_finite());
        assert!(out[2].is_nan());
        assert!(out[3].is_nan());
    }

    // ── iter-267: running_below_ratio ─────────────────────────────

    #[test]
    fn running_below_ratio_all_below_is_one() {
        let p = ScanProgram::new(1.0_f64, vec![2.0, 3.0]);
        let out = running_below_ratio(&p, 100.0);
        for v in &out {
            assert_eq!(*v, 1.0);
        }
    }

    #[test]
    fn running_below_ratio_none_below_is_zero() {
        let p = ScanProgram::new(10.0_f64, vec![20.0, 30.0]);
        let out = running_below_ratio(&p, 5.0);
        for v in &out {
            assert_eq!(*v, 0.0);
        }
    }

    #[test]
    fn running_below_ratio_complements_above_when_no_ties() {
        // For all non-threshold inputs, below + above = 1.
        let p = ScanProgram::new(1.0_f64, vec![7.0, 3.0, 9.0]);
        let below = running_below_ratio(&p, 5.0);
        let above = running_above_ratio(&p, 5.0);
        for (b, a) in below.iter().zip(above.iter()) {
            assert!((b + a - 1.0).abs() < 1e-12);
        }
    }

    #[test]
    fn running_below_ratio_bounded_in_unit() {
        let p = ScanProgram::new(0.5_f64, vec![3.0, -1.0, 4.0, 0.0]);
        let out = running_below_ratio(&p, 1.0);
        for v in &out {
            assert!(*v >= 0.0 && *v <= 1.0);
        }
    }

    // ── iter-297: running_count_positive ──────────────────────────

    #[test]
    fn running_count_positive_all_negative_is_zero() {
        let p = ScanProgram::new(-1.0_f64, vec![-2.0, -3.0]);
        let out = running_count_positive(&p);
        for v in &out {
            assert_eq!(*v, 0);
        }
    }

    #[test]
    fn running_count_positive_alternating() {
        let p = ScanProgram::new(-1.0_f64, vec![2.0, -3.0, 4.0]);
        let out = running_count_positive(&p);
        assert_eq!(out, vec![0, 1, 1, 2]);
    }

    #[test]
    fn running_count_positive_plus_negative_plus_zeros_equals_n() {
        // For a stream with no exact zeros, pos + neg = n.
        let p = ScanProgram::new(-1.0_f64, vec![2.0, -3.0, 4.0]);
        let pos = running_count_positive(&p);
        let neg = running_count_negative(&p);
        for (i, (p, n)) in pos.iter().zip(neg.iter()).enumerate() {
            assert_eq!((p + n) as usize, i + 1);
        }
    }

    // ── iter-291: running_count_negative ──────────────────────────

    #[test]
    fn running_count_negative_all_positive_is_zero() {
        let p = ScanProgram::new(1.0_f64, vec![2.0, 3.0]);
        let out = running_count_negative(&p);
        for v in &out {
            assert_eq!(*v, 0);
        }
    }

    #[test]
    fn running_count_negative_alternating() {
        let p = ScanProgram::new(-1.0_f64, vec![2.0, -3.0, 4.0, -5.0]);
        let out = running_count_negative(&p);
        assert_eq!(out, vec![1, 1, 2, 2, 3]);
    }

    #[test]
    fn running_count_negative_zero_doesnt_count() {
        // x = 0 is not strictly negative.
        let p = ScanProgram::new(0.0_f64, vec![0.0, -1.0]);
        let out = running_count_negative(&p);
        assert_eq!(out, vec![0, 0, 1]);
    }

    // ── iter-285: running_count_in_range ──────────────────────────

    #[test]
    fn running_count_in_range_all_inside() {
        let p = ScanProgram::new(5.0_f64, vec![6.0, 7.0]);
        let out = running_count_in_range(&p, 0.0, 10.0);
        assert_eq!(out, vec![1, 2, 3]);
    }

    #[test]
    fn running_count_in_range_none_inside() {
        let p = ScanProgram::new(5.0_f64, vec![6.0, 7.0]);
        let out = running_count_in_range(&p, 100.0, 200.0);
        for v in &out {
            assert_eq!(*v, 0);
        }
    }

    #[test]
    fn running_count_in_range_known_pattern() {
        // [1, 7, 3, 9] with range [2, 8]: in-range at indices 1, 2 (7, 3).
        let p = ScanProgram::new(1.0_f64, vec![7.0, 3.0, 9.0]);
        let out = running_count_in_range(&p, 2.0, 8.0);
        assert_eq!(out, vec![0, 1, 2, 2]);
    }

    #[test]
    fn running_count_in_range_empty_interval_returns_zero() {
        // lo > hi → empty interval; no value satisfies.
        let p = ScanProgram::new(5.0_f64, vec![6.0, 7.0]);
        let out = running_count_in_range(&p, 10.0, 0.0);
        for v in &out {
            assert_eq!(*v, 0);
        }
    }

    // ── iter-261: running_above_ratio ─────────────────────────────

    #[test]
    fn running_above_ratio_all_above_is_one() {
        let p = ScanProgram::new(10.0_f64, vec![20.0, 30.0]);
        let out = running_above_ratio(&p, 5.0);
        for v in &out {
            assert_eq!(*v, 1.0);
        }
    }

    #[test]
    fn running_above_ratio_none_above_is_zero() {
        let p = ScanProgram::new(1.0_f64, vec![2.0, 3.0]);
        let out = running_above_ratio(&p, 100.0);
        for v in &out {
            assert_eq!(*v, 0.0);
        }
    }

    #[test]
    fn running_above_ratio_known() {
        // threshold = 5, inputs (initial = 1, 7, 3, 9): above at 1, 3 → counts 0, 1, 1, 2 / lens 1, 2, 3, 4.
        let p = ScanProgram::new(1.0_f64, vec![7.0, 3.0, 9.0]);
        let out = running_above_ratio(&p, 5.0);
        assert_eq!(out, vec![0.0, 0.5, 1.0 / 3.0, 0.5]);
    }

    #[test]
    fn running_above_ratio_bounded_in_unit() {
        let p = ScanProgram::new(0.5_f64, vec![3.0, -1.0, 4.0, 0.0]);
        let out = running_above_ratio(&p, 1.0);
        for v in &out {
            assert!(*v >= 0.0 && *v <= 1.0);
        }
    }

    // ── iter-207: running_count_below ─────────────────────────────

    #[test]
    fn running_count_below_basic() {
        // Threshold 5, inputs (1, 7, 3, 9): below at positions 0, 2.
        let p = ScanProgram::new(0.0_f64, vec![1.0, 7.0, 3.0, 9.0]);
        let out = running_count_below(&p, 5.0);
        assert_eq!(out, vec![1, 2, 2, 3, 3]);
    }

    #[test]
    fn running_count_below_complements_above() {
        // count_below + count_above + count_equal == n.
        let p = ScanProgram::new(5.0_f64, vec![1.0, 5.0, 7.0, 5.0, 9.0]);
        let below = running_count_below(&p, 5.0);
        let above = running_count_above(&p, 5.0);
        // 6 total entries; equality cases at positions 0, 2, 4 (three 5.0s).
        let total = below.last().unwrap() + above.last().unwrap();
        assert_eq!(total, 6 - 3, "below+above = {} expected {}", total, 3);
    }

    #[test]
    fn running_count_below_monotone_nondecreasing() {
        let p = ScanProgram::new(0.0_f64, vec![1.0, 2.0, 3.0, 0.0, -1.0]);
        let out = running_count_below(&p, 1.5);
        for win in out.windows(2) {
            assert!(win[1] >= win[0]);
        }
    }

    #[test]
    fn running_count_below_no_matches_stays_zero() {
        let p = ScanProgram::new(10.0_f64, vec![20.0, 30.0]);
        let out = running_count_below(&p, 5.0);
        assert_eq!(out, vec![0, 0, 0]);
    }

    // ── iter-201: running_l2_norm ─────────────────────────────────

    #[test]
    fn running_l2_norm_pythagorean_triple() {
        // initial = 0, inputs = [3, 4]: out = [0, 3, 5].
        let p = ScanProgram::new(0.0_f64, vec![3.0, 4.0]);
        let out = running_l2_norm(&p);
        assert_eq!(out.len(), 3);
        assert!((out[1] - 3.0).abs() < 1e-12);
        assert!((out[2] - 5.0).abs() < 1e-12);
    }

    #[test]
    fn running_l2_norm_unit_increments_match_sqrt_n() {
        // After n unit elements: √n.
        let p = ScanProgram::new(0.0_f64, vec![1.0; 4]);
        let out = running_l2_norm(&p);
        for (k, v) in out.iter().enumerate() {
            assert!((v - (k as f64).sqrt()).abs() < 1e-12);
        }
    }

    #[test]
    fn running_l2_norm_constant_zero_stays_zero() {
        let p = ScanProgram::new(0.0_f64, vec![0.0; 5]);
        let out = running_l2_norm(&p);
        for v in &out {
            assert_eq!(*v, 0.0);
        }
    }

    #[test]
    fn running_l2_norm_monotone_nondecreasing() {
        // Squaring drops the sign, so the accumulator can't shrink.
        let p = ScanProgram::new(0.0_f64, vec![2.0, -3.0, 5.0, -1.0]);
        let out = running_l2_norm(&p);
        for win in out.windows(2) {
            assert!(win[1] >= win[0] - 1e-12, "shrink: {:?}", win);
        }
    }

    // ── iter-195: running_range ───────────────────────────────────

    #[test]
    fn running_range_single_value_is_zero() {
        let p = ScanProgram::new(5.0_f64, vec![]);
        let out = running_range(&p);
        assert_eq!(out, vec![0.0]);
    }

    #[test]
    fn running_range_increasing_stream() {
        // After each step the range = max - min so far.
        let p = ScanProgram::new(1.0_f64, vec![3.0, 7.0]);
        let out = running_range(&p);
        assert_eq!(out, vec![0.0, 2.0, 6.0]);
    }

    #[test]
    fn running_range_is_monotone_nondecreasing() {
        // No step can shrink the range.
        let p = ScanProgram::new(2.0_f64, vec![5.0, 1.0, 9.0, 4.0]);
        let out = running_range(&p);
        for win in out.windows(2) {
            assert!(win[1] >= win[0], "range went down: {:?}", win);
        }
    }

    #[test]
    fn running_range_constant_stream_is_zero() {
        let p = ScanProgram::new(3.0_f64, vec![3.0, 3.0, 3.0]);
        let out = running_range(&p);
        for v in &out {
            assert_eq!(*v, 0.0);
        }
    }

    // ── iter-189: running_log_sum_exp ─────────────────────────────

    #[test]
    fn running_log_sum_exp_initial_is_emitted() {
        let p = ScanProgram::new(0.0_f64, vec![]);
        let out = running_log_sum_exp(&p);
        assert_eq!(out, vec![0.0]);
    }

    #[test]
    fn running_log_sum_exp_pair_known() {
        // initial = 0, input = 0: LSE(0, 0) = ln(2).
        let p = ScanProgram::new(0.0_f64, vec![0.0]);
        let out = running_log_sum_exp(&p);
        assert_eq!(out.len(), 2);
        assert!((out[1] - 2.0_f64.ln()).abs() < 1e-12);
    }

    #[test]
    fn running_log_sum_exp_stable_at_extreme_magnitude() {
        // Naive exp(1000) overflows; shift-and-rescale must stay finite.
        let p = ScanProgram::new(1000.0_f64, vec![1000.0]);
        let out = running_log_sum_exp(&p);
        let expected = 1000.0 + 2.0_f64.ln();
        assert!((out[1] - expected).abs() < 1e-9);
    }

    #[test]
    fn running_log_sum_exp_dominated_by_max() {
        // initial = 0, input = 1000: result ≈ 1000.
        let p = ScanProgram::new(0.0_f64, vec![1000.0]);
        let out = running_log_sum_exp(&p);
        assert!((out[1] - 1000.0).abs() < 1e-9);
    }

    #[test]
    fn running_log_sum_exp_neg_infinity_preserved() {
        // LSE with NEG_INFINITY initial collapses to second element.
        let p = ScanProgram::new(f64::NEG_INFINITY, vec![3.0]);
        let out = running_log_sum_exp(&p);
        assert!((out[1] - 3.0).abs() < 1e-12);
    }

    // ── iter-183: running_kurtosis ────────────────────────────────

    #[test]
    fn running_kurtosis_constant_stream_is_zero() {
        let p = ScanProgram::new(3.0_f64, vec![3.0, 3.0]);
        let out = running_kurtosis(&p);
        for &v in &out {
            assert_eq!(v, 0.0);
        }
    }

    #[test]
    fn running_kurtosis_uniform_5_samples() {
        // (0, 1, 2, 3, 4): mean = 2, σ² = 2, m_4 = 6.8,
        // g_2 = 6.8 / 4 - 3 = 1.7 - 3 = -1.3.
        let p = ScanProgram::new(0.0_f64, vec![1.0, 2.0, 3.0, 4.0]);
        let out = running_kurtosis(&p);
        let last = *out.last().unwrap();
        assert!((last - (-1.3)).abs() < 1e-9, "g_2 = {}", last);
    }

    #[test]
    fn running_kurtosis_returns_finite_under_variance() {
        let p = ScanProgram::new(0.0_f64, vec![1.0, 2.0, 3.0, 4.0, 5.0]);
        let out = running_kurtosis(&p);
        for &v in &out {
            assert!(v.is_finite());
        }
    }

    // ── iter-175: running_fourth_central_moment ───────────────────

    #[test]
    fn running_fourth_moment_constant_stream_is_zero() {
        let p = ScanProgram::new(3.0_f64, vec![3.0, 3.0, 3.0]);
        let out = running_fourth_central_moment(&p);
        for &v in &out {
            assert!(v.abs() < 1e-12);
        }
    }

    #[test]
    fn running_fourth_moment_known_uniform() {
        // (0, 1, 2, 3, 4): mean = 2, sum(x-mean)^4 = 16+1+0+1+16 = 34, m4 = 6.8.
        let p = ScanProgram::new(0.0_f64, vec![1.0, 2.0, 3.0, 4.0]);
        let out = running_fourth_central_moment(&p);
        let last = *out.last().unwrap();
        assert!((last - 6.8).abs() < 1e-10, "m_4 = {}", last);
    }

    #[test]
    fn running_fourth_moment_non_negative() {
        // m_4 is always ≥ 0 (sum of 4th powers).
        let p = ScanProgram::new(-3.0_f64, vec![1.5, -2.0, 4.0, 0.5]);
        let out = running_fourth_central_moment(&p);
        for &v in &out {
            assert!(v >= -1e-12, "m_4 = {}", v);
        }
    }

    // ── iter-171: running_skewness ────────────────────────────────

    #[test]
    fn running_skewness_constant_stream_is_zero() {
        let p = ScanProgram::new(3.0_f64, vec![3.0, 3.0, 3.0]);
        let out = running_skewness(&p);
        for &v in &out {
            assert_eq!(v, 0.0);
        }
    }

    #[test]
    fn running_skewness_symmetric_stream_is_zero() {
        // Symmetric (-1, 0, 1) has g_1 = 0.
        let p = ScanProgram::new(-1.0_f64, vec![0.0, 1.0]);
        let out = running_skewness(&p);
        let last = *out.last().unwrap();
        assert!(last.abs() < 1e-12);
    }

    #[test]
    fn running_skewness_right_skewed_positive() {
        // Heavy right tail.
        let p = ScanProgram::new(0.0_f64, vec![0.0, 0.0, 0.0, 10.0]);
        let out = running_skewness(&p);
        let last = *out.last().unwrap();
        assert!(last > 0.5, "expected positive skew > 0.5, got {}", last);
    }

    // ── iter-165: running_third_central_moment ────────────────────

    #[test]
    fn running_third_moment_constant_stream_is_zero() {
        let p = ScanProgram::new(3.0_f64, vec![3.0, 3.0, 3.0]);
        let out = running_third_central_moment(&p);
        for &v in &out {
            assert!(v.abs() < 1e-12);
        }
    }

    #[test]
    fn running_third_moment_symmetric_stream_is_zero() {
        // (−1, 0, 1) is symmetric → 3rd moment = 0.
        let p = ScanProgram::new(-1.0_f64, vec![0.0, 1.0]);
        let out = running_third_central_moment(&p);
        let last = *out.last().unwrap();
        assert!(last.abs() < 1e-12, "m3 = {}", last);
    }

    #[test]
    fn running_third_moment_skewed_stream_is_nonzero() {
        // Right-skewed: most values low, one high.
        let p = ScanProgram::new(0.0_f64, vec![0.0, 0.0, 10.0]);
        let out = running_third_central_moment(&p);
        let last = *out.last().unwrap();
        assert!(last > 0.0, "expected positive skew, got {}", last);
    }

    // ── iter-159: running_squared_differences ─────────────────────

    #[test]
    fn running_squared_differences_constant_stream_is_zero() {
        let p = ScanProgram::new(3.0_f64, vec![3.0, 3.0, 3.0]);
        let out = running_squared_differences(&p);
        assert_eq!(out, vec![0.0, 0.0, 0.0, 0.0]);
    }

    #[test]
    fn running_squared_differences_accumulates() {
        // initial=0, inputs=(1, 3, 7, 15).
        // diffs² = (1, 4, 16, 64); running = (0, 1, 5, 21, 85).
        let p = ScanProgram::new(0.0_f64, vec![1.0, 3.0, 7.0, 15.0]);
        let out = running_squared_differences(&p);
        assert_eq!(out, vec![0.0, 1.0, 5.0, 21.0, 85.0]);
    }

    #[test]
    fn running_squared_differences_initial_only() {
        let p: ScanProgram<f64> = ScanProgram::just_initial(5.0);
        let out = running_squared_differences(&p);
        assert_eq!(out, vec![0.0]);
    }

    // ── iter-151: running_zscore ──────────────────────────────────

    #[test]
    fn running_zscore_single_sample_is_zero() {
        let p: ScanProgram<f64> = ScanProgram::just_initial(5.0);
        let out = running_zscore(&p);
        assert_eq!(out, vec![0.0]);
    }

    #[test]
    fn running_zscore_constant_stream_is_zero() {
        // No variance → z-score = 0.
        let p = ScanProgram::new(3.0_f64, vec![3.0, 3.0, 3.0]);
        let out = running_zscore(&p);
        for &v in &out {
            assert_eq!(v, 0.0);
        }
    }

    #[test]
    fn running_zscore_final_step_correct_for_known_distribution() {
        // (0, 1, 2, 3, 4): mean = 2, pop variance = 2 (10/5),
        // std = √2. z(x=4) = (4-2)/√2 = √2.
        let p = ScanProgram::new(0.0_f64, vec![1.0, 2.0, 3.0, 4.0]);
        let out = running_zscore(&p);
        let last = *out.last().unwrap();
        assert!((last - 2.0_f64.sqrt()).abs() < 1e-12, "z = {}", last);
    }

    #[test]
    fn running_zscore_output_length_matches_inputs() {
        let p = ScanProgram::new(0.0_f64, vec![1.0, 2.0, 3.0]);
        let out = running_zscore(&p);
        assert_eq!(out.len(), 4); // initial + 3 inputs.
    }

    // ── iter-145: first_difference ────────────────────────────────

    #[test]
    fn first_difference_empty_program() {
        let p: ScanProgram<f64> = ScanProgram::just_initial(5.0);
        let out = first_difference(&p);
        assert!(out.is_empty());
    }

    #[test]
    fn first_difference_constant_stream_is_zeros() {
        let p = ScanProgram::new(3.0_f64, vec![3.0, 3.0, 3.0]);
        let out = first_difference(&p);
        assert_eq!(out, vec![0.0, 0.0, 0.0]);
    }

    #[test]
    fn first_difference_known() {
        // initial=0, inputs=(1, 3, 7, 15) → diffs (1-0, 3-1, 7-3, 15-7) = (1, 2, 4, 8).
        let p = ScanProgram::new(0.0_f64, vec![1.0, 3.0, 7.0, 15.0]);
        let out = first_difference(&p);
        assert_eq!(out, vec![1.0, 2.0, 4.0, 8.0]);
    }

    #[test]
    fn first_difference_telescopes_to_total_change() {
        // sum of first differences = inputs[-1] - initial.
        let p = ScanProgram::new(2.0_f64, vec![5.0, 1.0, 8.0, 3.0]);
        let diffs = first_difference(&p);
        let sum: f64 = diffs.iter().sum();
        assert_eq!(sum, 3.0 - 2.0); // last input minus initial.
    }

    // ── iter-139: running_argmin ──────────────────────────────────

    #[test]
    fn running_argmin_single_sample() {
        let p = ScanProgram::just_initial(5.0_f64);
        let out = running_argmin(&p);
        assert_eq!(out, vec![(0, 5.0)]);
    }

    #[test]
    fn running_argmin_monotone_decreasing() {
        let p = ScanProgram::new(10.0_f64, vec![5.0, 3.0, 1.0]);
        let out = running_argmin(&p);
        assert_eq!(out, vec![(0, 10.0), (1, 5.0), (2, 3.0), (3, 1.0)]);
    }

    #[test]
    fn running_argmin_late_low() {
        let p = ScanProgram::new(5.0_f64, vec![3.0, 7.0, 1.0, 4.0]);
        let out = running_argmin(&p);
        assert_eq!(out, vec![(0, 5.0), (1, 3.0), (1, 3.0), (3, 1.0), (3, 1.0)]);
    }

    #[test]
    fn running_argmin_value_matches_running_min() {
        let p = ScanProgram::new(0.0_f64, vec![5.0, -1.0, 3.0, -2.0, 0.0]);
        let argmin = running_argmin(&p);
        let min = running_min(&p);
        for (i, &(_, v)) in argmin.iter().enumerate() {
            assert_eq!(v, min[i]);
        }
    }

    // ── iter-120: running_argmax ──────────────────────────────────

    #[test]
    fn running_argmax_single_sample() {
        let p = ScanProgram::just_initial(5.0_f64);
        let out = running_argmax(&p);
        assert_eq!(out, vec![(0, 5.0)]);
    }

    #[test]
    fn running_argmax_monotone_increasing_tracks_latest() {
        let p = ScanProgram::new(0.0_f64, vec![1.0, 2.0, 3.0, 4.0]);
        let out = running_argmax(&p);
        assert_eq!(out, vec![(0, 0.0), (1, 1.0), (2, 2.0), (3, 3.0), (4, 4.0)]);
    }

    #[test]
    fn running_argmax_constant_first_wins() {
        // All values equal → first occurrence wins.
        let p = ScanProgram::new(3.0_f64, vec![3.0, 3.0, 3.0]);
        let out = running_argmax(&p);
        assert_eq!(out, vec![(0, 3.0), (0, 3.0), (0, 3.0), (0, 3.0)]);
    }

    #[test]
    fn running_argmax_with_late_peak() {
        // Peak in the middle, then descent.
        let p = ScanProgram::new(1.0_f64, vec![3.0, 5.0, 2.0, 4.0]);
        let out = running_argmax(&p);
        // step 0: max=1 at 0.
        // step 1: max=3 at 1.
        // step 2: max=5 at 2.
        // step 3: still max=5 at 2 (2 < 5).
        // step 4: still max=5 at 2 (4 < 5).
        assert_eq!(out, vec![(0, 1.0), (1, 3.0), (2, 5.0), (2, 5.0), (2, 5.0)]);
    }

    #[test]
    fn running_argmax_value_matches_running_max() {
        // The value component of running_argmax should equal running_max.
        let p = ScanProgram::new(2.0_f64, vec![5.0, -1.0, 3.0, 7.0, 0.0]);
        let argmax = running_argmax(&p);
        let max = running_max(&p);
        for (i, &(_, v)) in argmax.iter().enumerate() {
            assert_eq!(v, max[i]);
        }
    }

    // ── iter-114: running_min_max_pair ────────────────────────────

    #[test]
    fn running_min_max_pair_initial_only() {
        let p = ScanProgram::just_initial(5.0_f64);
        let out = running_min_max_pair(&p);
        assert_eq!(out, vec![(5.0, 5.0)]);
    }

    #[test]
    fn running_min_max_pair_tracks_both_bounds() {
        let p = ScanProgram::new(3.0_f64, vec![1.0, 5.0, -2.0, 4.0]);
        let out = running_min_max_pair(&p);
        assert_eq!(out, vec![(3.0, 3.0), (1.0, 3.0), (1.0, 5.0), (-2.0, 5.0), (-2.0, 5.0)]);
    }

    #[test]
    fn running_min_max_pair_equals_separate_helpers() {
        // running_min_max_pair[i].0 == running_min(prog)[i].
        // running_min_max_pair[i].1 == running_max(prog)[i].
        let p = ScanProgram::new(2.0_f64, vec![5.0, -1.0, 3.0, 7.0, 0.0]);
        let pair = running_min_max_pair(&p);
        let separate_min = running_min(&p);
        let separate_max = running_max(&p);
        for (i, (m, x)) in pair.iter().enumerate() {
            assert_eq!(*m, separate_min[i]);
            assert_eq!(*x, separate_max[i]);
        }
    }

    #[test]
    fn running_min_max_pair_min_le_max_always() {
        let p = ScanProgram::new(0.0_f64, vec![1.0, -5.0, 3.0, -2.0, 10.0]);
        let pair = running_min_max_pair(&p);
        for &(min, max) in &pair {
            assert!(min <= max, "min = {} > max = {}", min, max);
        }
    }

    // ── iter-107: running_variance (Welford) ──────────────────────

    #[test]
    fn running_variance_single_sample_is_zero() {
        let p = ScanProgram::just_initial(5.0_f64);
        let out = running_variance(&p);
        assert_eq!(out, vec![0.0]);
    }

    #[test]
    fn running_variance_constant_stream_is_zero() {
        // All samples = 3.0 → variance = 0 at every step.
        let p = ScanProgram::new(3.0_f64, vec![3.0, 3.0, 3.0, 3.0]);
        let out = running_variance(&p);
        for &v in &out {
            assert!(v.abs() < 1e-12, "expected 0, got {}", v);
        }
    }

    #[test]
    fn running_variance_1_2_3_4_known() {
        // Population variance of (1,2,3,4): mean = 2.5; deviations
        // (-1.5)² + (-0.5)² + (0.5)² + (1.5)² = 5; variance = 5/4 = 1.25.
        let p = ScanProgram::new(1.0_f64, vec![2.0, 3.0, 4.0]);
        let out = running_variance(&p);
        assert!((out[3] - 1.25).abs() < 1e-12, "final variance = {}", out[3]);
    }

    #[test]
    fn running_variance_two_distinct_samples() {
        // (1, 3): mean = 2; deviations (-1)² + (1)² = 2; pop var = 2/2 = 1.
        let p = ScanProgram::new(1.0_f64, vec![3.0]);
        let out = running_variance(&p);
        assert!((out[1] - 1.0).abs() < 1e-12);
    }

    #[test]
    fn running_variance_grows_after_outlier() {
        // Stream of 5's then a 100; variance jumps after the outlier.
        let p = ScanProgram::new(5.0_f64, vec![5.0, 5.0, 5.0, 100.0]);
        let out = running_variance(&p);
        // Initially zero variance for the constant run.
        assert!(out[3].abs() < 1e-12);
        // Variance jumps after step 4.
        assert!(out[4] > 100.0);
    }

    #[test]
    fn running_variance_numerical_stability_large_offset() {
        // Welford handles large means correctly where naive E[X²]-E[X]²
        // would lose precision. With initial=1e9 and tiny perturbations,
        // variance should match the perturbation-only variance closely.
        let p = ScanProgram::new(
            1.0e9_f64,
            vec![1.0e9 + 1.0, 1.0e9 - 1.0, 1.0e9 + 2.0],
        );
        let out = running_variance(&p);
        // Mean = 1e9 + 0.5; pop variance of (0, 1, -1, 2):
        // mean shift = 0.5; deviations from 0.5:
        // (-0.5)², (0.5)², (-1.5)², (1.5)² → 0.25 + 0.25 + 2.25 + 2.25 = 5
        // variance = 5 / 4 = 1.25.
        assert!((out[3] - 1.25).abs() < 1e-3, "variance = {}", out[3]);
    }

    // ── iter-102: EMA ─────────────────────────────────────────────

    #[test]
    fn running_ema_alpha_zero_takes_input_as_output() {
        // α = 0 → state_{t+1} = input_t (initial preserved at index 0).
        let p = ScanProgram::new(0.0_f64, vec![1.5, 2.5, -1.0, 3.0]);
        let out = running_ema(&p, 0.0);
        assert_eq!(out, vec![0.0, 1.5, 2.5, -1.0, 3.0]);
    }

    #[test]
    fn running_ema_alpha_one_holds_initial() {
        // α = 1 → state never updates.
        let p = ScanProgram::new(5.0_f64, vec![100.0, -50.0, 7.0]);
        let out = running_ema(&p, 1.0);
        assert_eq!(out, vec![5.0, 5.0, 5.0, 5.0]);
    }

    #[test]
    fn running_ema_alpha_half_averages() {
        // α = 0.5 → state' = (state + input) / 2.
        let p = ScanProgram::new(0.0_f64, vec![4.0, 4.0]);
        let out = running_ema(&p, 0.5);
        // step 1: 0.5·0 + 0.5·4 = 2.
        // step 2: 0.5·2 + 0.5·4 = 3.
        assert_eq!(out, vec![0.0, 2.0, 3.0]);
    }

    #[test]
    fn running_ema_converges_to_constant_input() {
        // For α ∈ (0, 1), EMA converges to constant input value
        // over many steps.
        let p = ScanProgram::new(0.0_f64, vec![10.0; 100]);
        let out = running_ema(&p, 0.9);
        // After 100 steps with α = 0.9, output should be very close to 10.
        let final_value = *out.last().unwrap();
        assert!((final_value - 10.0).abs() < 1e-3, "EMA = {}", final_value);
    }

    #[test]
    fn running_ema_smooths_noise() {
        // EMA over noisy inputs around mean 5 should produce smoother
        // outputs (less variance than raw inputs).
        let inputs = vec![5.0_f64, 7.0, 3.0, 6.0, 4.0, 5.5, 4.5, 5.0, 4.8, 5.2];
        let p = ScanProgram::new(5.0_f64, inputs.clone());
        let smoothed = running_ema(&p, 0.7);

        // Compute variance of inputs and of smoothed outputs.
        let input_mean: f64 = inputs.iter().sum::<f64>() / inputs.len() as f64;
        let input_var: f64 = inputs.iter().map(|x| (x - input_mean).powi(2)).sum::<f64>()
            / inputs.len() as f64;
        let smoothed_no_init = &smoothed[1..];
        let smoothed_mean: f64 = smoothed_no_init.iter().sum::<f64>() / smoothed_no_init.len() as f64;
        let smoothed_var: f64 = smoothed_no_init.iter().map(|x| (x - smoothed_mean).powi(2)).sum::<f64>()
            / smoothed_no_init.len() as f64;

        assert!(
            smoothed_var < input_var,
            "EMA didn't smooth: input_var = {}, smoothed_var = {}",
            input_var, smoothed_var
        );
    }

    #[test]
    fn running_aggregators_handle_empty_program() {
        let p_sum: ScanProgram<f64> = ScanProgram::just_initial(5.0);
        assert_eq!(running_sum(&p_sum), vec![5.0]);
        assert_eq!(running_max(&p_sum), vec![5.0]);
        assert_eq!(running_min(&p_sum), vec![5.0]);
        assert_eq!(running_product(&p_sum), vec![5.0]);
        assert_eq!(running_mean(&p_sum), vec![5.0]);
    }

    #[test]
    fn running_sum_consistent_with_sequential_scan() {
        let p = ScanProgram::new(0.0_f64, vec![1.5, 2.5, -1.0, 3.0]);
        let wrapper = running_sum(&p);
        let direct = sequential_scan(&p, |a, b| a + b);
        assert_eq!(wrapper, direct);
    }

    #[test]
    fn float_add_scan_matches_iter_running_sum() {
        let inputs: Vec<f64> = vec![1.5, 2.5, -1.0, 3.0];
        let p = ScanProgram::new(0.0_f64, inputs.clone());
        let out = sequential_scan(&p, |a, b| a + b);
        // Compare to running sum.
        let mut acc = 0.0;
        let mut expected = vec![acc];
        for v in &inputs {
            acc += v;
            expected.push(acc);
        }
        assert_eq!(out, expected);
    }

    #[test]
    fn complex_op_state_carry_works() {
        // Pair scan: state is (count, sum); input is the next value.
        // op((c, s), v) = (c+1, s+v).
        let p = ScanProgram::new((0u32, 0.0f64), vec![(1, 1.0), (1, 2.0), (1, 4.0)]);
        let out = sequential_scan(&p, |a, b| (a.0 + b.0, a.1 + b.1));
        assert_eq!(out.len(), 4);
        assert_eq!(out[3], (3, 7.0));
    }
}
