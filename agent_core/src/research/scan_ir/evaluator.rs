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
