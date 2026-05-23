//! Source:
//! - Dao, Gu arXiv:2405.21060 §6 — Structured State Space Duality
//!   (SSD) algorithm. The parallel-block-scan decomposition that
//!   this module structurally implements.
//! - Blelloch CMU-CS-90-190 — the original parallel-prefix-sum
//!   abstraction; SSD is its modern, structured-matrix specialization.
//! - Doctrine §4.3 — Scan-IR second lowering target.
//! - Companion: [`super::evaluator`] (the sequential reference);
//!   [`super::grammar`] (the ScanProgram this module consumes).
//!
//! # SSD parallel-block-scan structure
//!
//! Dao/Gu §6 decomposes a scan into three passes:
//!
//! 1. **Per-block reduce.** Partition the input sequence into
//!    blocks of fixed size `B`. For each block, fold the block's
//!    inputs into a single "block delta" starting from a
//!    user-supplied `identity` element.
//! 2. **Prefix-scan of block deltas.** Run a sequential scan
//!    over the deltas (one step per block) to compute, for each
//!    block, the running state of the *prior* block's output.
//!    This is the "block offset" each block starts from.
//! 3. **Per-block scan.** Within each block, run a sequential
//!    scan starting from its offset, emitting the per-step output
//!    states.
//!
//! Passes 1 and 3 are parallel across blocks (each block's
//! work is independent). Pass 2 is the small sequential bridge
//! between them. This is what makes SSD asymptotically faster
//! than a flat sequential scan on hardware with parallelism;
//! correctness-wise, the output is **identical** to
//! [`super::evaluator::sequential_scan`] (proven by the property
//! test in iter-27).
//!
//! ## Identity element requirement
//!
//! The caller must supply a `T` value that's the **left identity**
//! of the op (`op(&identity, &x) == x` for all `x`). The SSD
//! lowering uses it to seed per-block reduces in pass 1, which
//! makes the per-block computations independent of cross-block
//! state. The sequential reference [`super::evaluator::sequential_scan`]
//! does NOT require an identity, so the two routes have different
//! interfaces; the cross-check (iter-27) supplies the identity
//! explicitly for the SSD path.

use super::grammar::ScanProgram;

/// SSD parallel-block-scan structure (Dao/Gu §6).
///
/// Returns the same output as
/// [`super::evaluator::sequential_scan`] for an associative op +
/// correct left-identity, but structures the computation as three
/// passes over `B`-sized blocks. Per-block work is independent and
/// could be parallelized (this routine does not use threads today).
pub fn ssd_block_scan<T, F>(
    program: &ScanProgram<T>,
    op: F,
    identity: T,
    block_size: usize,
) -> Vec<T>
where
    T: Clone,
    F: Fn(&T, &T) -> T,
{
    let bs = block_size.max(1);
    let inputs = &program.inputs;

    if inputs.is_empty() {
        return vec![program.initial.clone()];
    }

    // ── Pass 1: per-block reduce starting from `identity` ───────────
    let blocks: Vec<&[T]> = inputs.chunks(bs).collect();
    let block_deltas: Vec<T> = blocks
        .iter()
        .map(|block| {
            let mut s = identity.clone();
            for input in block.iter() {
                s = op(&s, input);
            }
            s
        })
        .collect();

    // ── Pass 2: prefix-scan of block deltas → per-block offsets ────
    // block_offsets[i] = op(initial, delta[0]) ⊕ delta[1] ⊕ … ⊕ delta[i-1]
    // i.e. the running state right BEFORE block i begins.
    let mut block_offsets: Vec<T> = Vec::with_capacity(blocks.len());
    let mut acc = program.initial.clone();
    block_offsets.push(acc.clone());
    for delta in block_deltas.iter().take(block_deltas.len() - 1) {
        acc = op(&acc, delta);
        block_offsets.push(acc.clone());
    }

    // ── Pass 3: per-block scan starting from each offset ──────────
    let mut out: Vec<T> = Vec::with_capacity(program.output_count());
    out.push(program.initial.clone());
    for (block_idx, block) in blocks.iter().enumerate() {
        let mut s = block_offsets[block_idx].clone();
        for input in block.iter() {
            s = op(&s, input);
            out.push(s.clone());
        }
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::research::scan_ir::evaluator::sequential_scan;

    #[test]
    fn ssd_empty_program_returns_initial() {
        let p: ScanProgram<i32> = ScanProgram::just_initial(42);
        let out = ssd_block_scan(&p, |a, b| a + b, 0, 4);
        assert_eq!(out, vec![42]);
    }

    #[test]
    fn ssd_matches_sequential_for_prefix_sum() {
        // Critical property: SSD output == sequential output for an
        // associative op + correct identity.
        let p = ScanProgram::new(0i32, vec![1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
        let op = |a: &i32, b: &i32| a + b;
        let identity = 0i32;
        for bs in [1, 2, 3, 4, 5, 6, 7, 8, 11, 100] {
            let ssd_out = ssd_block_scan(&p, op, identity, bs);
            let seq_out = sequential_scan(&p, op);
            assert_eq!(
                ssd_out, seq_out,
                "SSD vs sequential differ at block_size={}",
                bs
            );
        }
    }

    #[test]
    fn ssd_matches_sequential_for_running_max() {
        let p = ScanProgram::new(i32::MIN, vec![3, 1, 4, 1, 5, 9, 2, 6, 5, 3, 5]);
        let op = |a: &i32, b: &i32| *a.max(b);
        let identity = i32::MIN; // identity for max is -inf
        for bs in [1, 2, 4, 16] {
            let ssd_out = ssd_block_scan(&p, op, identity, bs);
            let seq_out = sequential_scan(&p, op);
            assert_eq!(ssd_out, seq_out, "block_size={}", bs);
        }
    }

    #[test]
    fn ssd_block_size_one_is_sequential() {
        // With block_size = 1 each block is a single input — should
        // still produce the same output as sequential.
        let p = ScanProgram::new(0i32, vec![10, 20, 30]);
        let out = ssd_block_scan(&p, |a, b| a + b, 0, 1);
        assert_eq!(out, vec![0, 10, 30, 60]);
    }

    #[test]
    fn ssd_block_size_larger_than_inputs_is_one_block() {
        let p = ScanProgram::new(0i32, vec![1, 2, 3]);
        let out = ssd_block_scan(&p, |a, b| a + b, 0, 100);
        assert_eq!(out, vec![0, 1, 3, 6]);
    }

    #[test]
    fn ssd_output_length_is_one_plus_step_count() {
        let p = ScanProgram::new(0i32, vec![1, 2, 3, 4, 5, 6, 7]);
        let out = ssd_block_scan(&p, |a, b| a + b, 0, 3);
        assert_eq!(out.len(), p.output_count());
    }

    #[test]
    fn ssd_first_output_is_initial() {
        let p = ScanProgram::new(99i32, vec![1, 2]);
        let out = ssd_block_scan(&p, |a, b| a + b, 0, 1);
        assert_eq!(out[0], 99);
    }

    #[test]
    fn ssd_zero_block_size_treated_as_one() {
        // Defensive: block_size=0 is bumped to 1 internally.
        let p = ScanProgram::new(0i32, vec![1, 2, 3]);
        let out = ssd_block_scan(&p, |a, b| a + b, 0, 0);
        assert_eq!(out, vec![0, 1, 3, 6]);
    }

    #[test]
    fn ssd_f64_sum_matches_sequential() {
        let p = ScanProgram::new(0.0f64, vec![1.5, 2.5, -1.0, 3.0, 0.5, 4.5]);
        let op = |a: &f64, b: &f64| a + b;
        let identity = 0.0_f64;
        for bs in [1, 2, 3, 4] {
            let ssd_out = ssd_block_scan(&p, op, identity, bs);
            let seq_out = sequential_scan(&p, op);
            assert_eq!(ssd_out, seq_out, "block_size={}", bs);
        }
    }

    #[test]
    fn ssd_non_zero_initial_propagates() {
        // initial = 5, inputs = [1, 2, 3]; expected = [5, 6, 8, 11].
        let p = ScanProgram::new(5i32, vec![1, 2, 3]);
        let out = ssd_block_scan(&p, |a, b| a + b, 0, 2);
        assert_eq!(out, vec![5, 6, 8, 11]);
    }

    #[test]
    fn ssd_string_concat_matches_sequential() {
        // String op: NOT associative-on-the-left unless we're careful.
        // String concatenation IS associative; identity is "".
        let p = ScanProgram::new(
            "init:".to_string(),
            vec!["a".into(), "b".into(), "c".into(), "d".into()],
        );
        let op = |a: &String, b: &String| format!("{}{}", a, b);
        let identity = "".to_string();
        for bs in [1, 2, 3, 4, 5] {
            let ssd_out = ssd_block_scan(&p, op.clone(), identity.clone(), bs);
            let seq_out = sequential_scan(&p, op.clone());
            assert_eq!(ssd_out, seq_out, "block_size={}", bs);
        }
    }
}
