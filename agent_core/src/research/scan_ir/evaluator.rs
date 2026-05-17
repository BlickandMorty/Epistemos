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
