//! Source:
//! - Dao/Gu arXiv:2405.21060 §6 — SSD algorithm. The ScanProgram
//!   AST carries the per-step input sequence that SSD's parallel
//!   block-scan consumes.
//! - Blelloch CMU-CS-90-190 — associative-operator parallel-scan;
//!   the associativity requirement is the AST's contract.
//! - Doctrine §4.3 — Scan-IR Rust crate-module shape.
//!
//! # Scan-IR typed AST
//!
//! A scan is the typed pair `(initial: T, inputs: Vec<T>)` where
//! `T` is the state-monoid carrier. Given an externally-supplied
//! associative operator `⊕ : T × T → T`, the scan produces the
//! running state sequence:
//!
//! ```text
//! outputs = [initial, initial ⊕ inputs[0], initial ⊕ inputs[0] ⊕ inputs[1], …]
//!         (= 1 + inputs.len() outputs total)
//! ```
//!
//! The AST is structural — the associativity witness is supplied
//! by the caller at lowering time (iter-25 sequential evaluator,
//! iter-26 SSD parallel-block lowering). Phase B3's correctness
//! gate (T3 F-SemiseparableBlockScan-Correctness) is the cross-check
//! that both lowerings produce the same output sequence on a
//! fixture.

use serde::{Deserialize, Serialize};
use std::fmt;

/// Typed scan program: `(initial state, sequence of inputs)`.
///
/// The associative operator `⊕` is supplied by the lowering step,
/// not the AST. This keeps the typed-AST surface a pure data form
/// (Serde-derivable) while letting the lowering choose between
/// sequential left-fold and SSD parallel-block scan.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct ScanProgram<T> {
    pub initial: T,
    pub inputs: Vec<T>,
}

impl<T> ScanProgram<T> {
    /// Construct a scan program.
    pub fn new(initial: T, inputs: Vec<T>) -> Self {
        ScanProgram { initial, inputs }
    }

    /// Empty program: just the initial state, no inputs.
    pub fn just_initial(initial: T) -> Self {
        ScanProgram {
            initial,
            inputs: Vec::new(),
        }
    }

    /// `true` iff `inputs` is empty (output sequence has length 1).
    pub fn is_initial_only(&self) -> bool {
        self.inputs.is_empty()
    }

    /// Number of input steps.
    pub fn step_count(&self) -> usize {
        self.inputs.len()
    }

    /// Number of outputs the scan will produce
    /// (= `1 + step_count`: the initial state, then one running
    /// state per applied input).
    pub fn output_count(&self) -> usize {
        1 + self.inputs.len()
    }
}

impl<T: fmt::Display> fmt::Display for ScanProgram<T> {
    /// `"ScanProgram { initial: <T>, inputs: [<T>, …] }"` —
    /// useful for debugging integration tests + Lean cert output.
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "ScanProgram {{ initial: {}, inputs: [", self.initial)?;
        for (i, x) in self.inputs.iter().enumerate() {
            if i > 0 {
                write!(f, ", ")?;
            }
            write!(f, "{}", x)?;
        }
        write!(f, "] }}")
    }
}

impl<T: Clone> ScanProgram<T> {
    /// Append an input step. Returns a new `ScanProgram` with the
    /// new input at the end. Useful for builder-style chains.
    pub fn append(mut self, input: T) -> Self {
        self.inputs.push(input);
        self
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn just_initial_has_no_inputs() {
        let p: ScanProgram<i32> = ScanProgram::just_initial(0);
        assert!(p.is_initial_only());
        assert_eq!(p.step_count(), 0);
        assert_eq!(p.output_count(), 1);
    }

    #[test]
    fn new_with_inputs_has_correct_counts() {
        let p = ScanProgram::new(0i32, vec![1, 2, 3]);
        assert!(!p.is_initial_only());
        assert_eq!(p.step_count(), 3);
        assert_eq!(p.output_count(), 4);
    }

    #[test]
    fn append_grows_input_sequence() {
        let p = ScanProgram::just_initial(0i32)
            .append(1)
            .append(2)
            .append(3);
        assert_eq!(p.inputs, vec![1, 2, 3]);
        assert_eq!(p.step_count(), 3);
    }

    #[test]
    fn empty_program_step_count_is_zero() {
        let p: ScanProgram<i32> = ScanProgram::just_initial(42);
        assert_eq!(p.step_count(), 0);
        assert_eq!(p.output_count(), 1);
    }

    #[test]
    fn initial_value_preserved() {
        let p = ScanProgram::new("hello".to_string(), vec![]);
        assert_eq!(p.initial, "hello");
    }

    #[test]
    fn inputs_vec_is_owned_and_mutable_via_append() {
        let p = ScanProgram::new(0i32, vec![]).append(7);
        assert_eq!(p.inputs, vec![7]);
    }

    #[test]
    fn output_count_invariant_after_appends() {
        let mut p = ScanProgram::just_initial(0i32);
        for i in 0..10 {
            p = p.append(i);
            assert_eq!(p.output_count(), p.step_count() + 1);
            assert_eq!(p.output_count(), (i as usize) + 2);
        }
    }

    #[test]
    fn round_trips_through_serde_json() {
        let p = ScanProgram::new(0i32, vec![1, 2, 3]);
        let json = serde_json::to_string(&p).unwrap();
        let back: ScanProgram<i32> = serde_json::from_str(&json).unwrap();
        assert_eq!(p, back);
    }

    #[test]
    fn round_trips_through_serde_json_with_f64() {
        let p = ScanProgram::new(0.0_f64, vec![1.5, -2.5, 3.25]);
        let json = serde_json::to_string(&p).unwrap();
        let back: ScanProgram<f64> = serde_json::from_str(&json).unwrap();
        assert_eq!(p, back);
    }

    #[test]
    fn is_initial_only_distinguishes_empty_vs_nonempty_inputs() {
        let empty = ScanProgram::<i32>::just_initial(0);
        let nonempty = ScanProgram::new(0i32, vec![1]);
        assert!(empty.is_initial_only());
        assert!(!nonempty.is_initial_only());
    }

    #[test]
    fn append_chain_preserves_input_order() {
        let p = ScanProgram::just_initial(0i32)
            .append(10)
            .append(20)
            .append(30);
        assert_eq!(p.inputs, vec![10, 20, 30]);
    }

    #[test]
    fn clone_yields_equal_program() {
        let p = ScanProgram::new("init".to_string(), vec!["a".into(), "b".into()]);
        let cloned = p.clone();
        assert_eq!(p, cloned);
    }

    // ── Display impl (iter-53) ─────────────────────────────────────

    #[test]
    fn display_empty_program() {
        let p: ScanProgram<i32> = ScanProgram::just_initial(0);
        assert_eq!(format!("{}", p), "ScanProgram { initial: 0, inputs: [] }");
    }

    #[test]
    fn display_with_inputs() {
        let p = ScanProgram::new(0i32, vec![1, 2, 3]);
        assert_eq!(format!("{}", p), "ScanProgram { initial: 0, inputs: [1, 2, 3] }");
    }
}
