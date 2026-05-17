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
