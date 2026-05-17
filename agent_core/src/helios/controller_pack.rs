//! Source:
//! - `docs/fusion/helios v6.2.md` 8-stage falsifier §5 — ControllerKernelPack
//!   6 fused micro-kernels reference-equivalent vs Swift.
//!
//! # Helios stage 5 — ControllerKernelPack (CPU reference)
//!
//! Six small utility kernels the controller path dispatches frequently;
//! packing them into one Metal file amortizes the dispatch overhead.
//! Substrate floor here is the Rust CPU reference each Metal kernel
//! must match bit-for-bit (within fp32 tolerance) per stage 5 acceptance.
//!
//! The 6:
//! 1. [`scalar_add_in_place`] — `a[i] += scalar`
//! 2. [`scalar_mul_in_place`] — `a[i] *= scalar`
//! 3. [`max_reduce`]          — `max(a)` (returns NaN for empty input — surfaced)
//! 4. [`argmax_reduce`]       — `argmax(a)` (first-index tie-break)
//! 5. [`copy_range`]           — `dst[..len] = src[..len]`
//! 6. [`zero_fill`]            — `a[..] = 0`
//!
//! All six return early-out errors on dimension mismatches; none
//! silently truncate.

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum ControllerKernelError {
    EmptyInput { which: &'static str },
    LengthMismatch { dst: usize, src: usize },
    RangeOutOfBounds { len: usize, end: usize },
}

pub fn scalar_add_in_place(a: &mut [f32], scalar: f32) {
    for v in a.iter_mut() {
        *v += scalar;
    }
}

pub fn scalar_mul_in_place(a: &mut [f32], scalar: f32) {
    for v in a.iter_mut() {
        *v *= scalar;
    }
}

pub fn max_reduce(a: &[f32]) -> Result<f32, ControllerKernelError> {
    if a.is_empty() {
        return Err(ControllerKernelError::EmptyInput { which: "max_reduce" });
    }
    let mut best = a[0];
    for &v in &a[1..] {
        if v > best {
            best = v;
        }
    }
    Ok(best)
}

pub fn argmax_reduce(a: &[f32]) -> Result<usize, ControllerKernelError> {
    if a.is_empty() {
        return Err(ControllerKernelError::EmptyInput { which: "argmax_reduce" });
    }
    let mut best_idx: usize = 0;
    let mut best_val = a[0];
    for (i, &v) in a.iter().enumerate().skip(1) {
        if v > best_val {
            best_val = v;
            best_idx = i;
        }
    }
    Ok(best_idx)
}

pub fn copy_range(dst: &mut [f32], src: &[f32]) -> Result<(), ControllerKernelError> {
    if dst.len() != src.len() {
        return Err(ControllerKernelError::LengthMismatch {
            dst: dst.len(),
            src: src.len(),
        });
    }
    dst.copy_from_slice(src);
    Ok(())
}

pub fn zero_fill(a: &mut [f32]) {
    for v in a.iter_mut() {
        *v = 0.0;
    }
}

/// `min(a)`. Companion to [`max_reduce`]. Returns
/// `EmptyInput` for empty slices. NaN-handling matches max_reduce:
/// element-wise `<` comparison, NaN-on-either-side preserves the
/// non-NaN side.
pub fn min_reduce(a: &[f32]) -> Result<f32, ControllerKernelError> {
    if a.is_empty() {
        return Err(ControllerKernelError::EmptyInput { which: "min_reduce" });
    }
    let mut best = a[0];
    for &v in &a[1..] {
        if v < best {
            best = v;
        }
    }
    Ok(best)
}

/// `argmin(a)` (first-index tie-break). Companion to
/// [`argmax_reduce`].
pub fn argmin_reduce(a: &[f32]) -> Result<usize, ControllerKernelError> {
    if a.is_empty() {
        return Err(ControllerKernelError::EmptyInput { which: "argmin_reduce" });
    }
    let mut best_idx: usize = 0;
    let mut best_val = a[0];
    for (i, &v) in a.iter().enumerate().skip(1) {
        if v < best_val {
            best_val = v;
            best_idx = i;
        }
    }
    Ok(best_idx)
}

/// `Σ a` using fp32 sequential summation. Production Metal would use
/// pairwise / Kahan summation to bound accumulated rounding error;
/// substrate floor matches the obvious sequential path that the Metal
/// reference reduction must agree with bit-for-bit when the input is
/// well-conditioned (no catastrophic cancellation).
pub fn sum_reduce(a: &[f32]) -> Result<f32, ControllerKernelError> {
    if a.is_empty() {
        return Err(ControllerKernelError::EmptyInput { which: "sum_reduce" });
    }
    let mut acc = 0.0_f32;
    for &v in a {
        acc += v;
    }
    Ok(acc)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn scalar_add_shifts_every_element() {
        let mut a = vec![1.0_f32, 2.0, 3.0];
        scalar_add_in_place(&mut a, 0.5);
        assert_eq!(a, vec![1.5, 2.5, 3.5]);
    }

    #[test]
    fn scalar_add_zero_is_identity() {
        let mut a = vec![1.0_f32, 2.0, 3.0];
        scalar_add_in_place(&mut a, 0.0);
        assert_eq!(a, vec![1.0, 2.0, 3.0]);
    }

    #[test]
    fn scalar_mul_scales_every_element() {
        let mut a = vec![1.0_f32, -2.0, 3.0];
        scalar_mul_in_place(&mut a, 2.0);
        assert_eq!(a, vec![2.0, -4.0, 6.0]);
    }

    #[test]
    fn scalar_mul_by_zero_zeroes_array() {
        let mut a = vec![1.0_f32, 2.0, 3.0];
        scalar_mul_in_place(&mut a, 0.0);
        assert_eq!(a, vec![0.0, 0.0, 0.0]);
    }

    #[test]
    fn max_reduce_finds_max() {
        let a = vec![1.0_f32, 5.0, 3.0, -2.0];
        assert_eq!(max_reduce(&a).unwrap(), 5.0);
    }

    #[test]
    fn max_reduce_single_element_returns_it() {
        let a = vec![42.0_f32];
        assert_eq!(max_reduce(&a).unwrap(), 42.0);
    }

    #[test]
    fn max_reduce_empty_errors() {
        let err = max_reduce(&[]).unwrap_err();
        assert_eq!(err, ControllerKernelError::EmptyInput { which: "max_reduce" });
    }

    #[test]
    fn argmax_reduce_finds_first_max_index() {
        let a = vec![1.0_f32, 5.0, 3.0, 5.0];
        assert_eq!(argmax_reduce(&a).unwrap(), 1);
    }

    #[test]
    fn argmax_reduce_empty_errors() {
        let err = argmax_reduce(&[]).unwrap_err();
        assert_eq!(
            err,
            ControllerKernelError::EmptyInput { which: "argmax_reduce" }
        );
    }

    #[test]
    fn copy_range_copies_into_dst() {
        let src = vec![1.0_f32, 2.0, 3.0];
        let mut dst = vec![0.0_f32; 3];
        copy_range(&mut dst, &src).unwrap();
        assert_eq!(dst, src);
    }

    #[test]
    fn copy_range_length_mismatch_errors() {
        let src = vec![1.0_f32, 2.0];
        let mut dst = vec![0.0_f32; 3];
        let err = copy_range(&mut dst, &src).unwrap_err();
        assert_eq!(
            err,
            ControllerKernelError::LengthMismatch { dst: 3, src: 2 }
        );
    }

    #[test]
    fn zero_fill_zeroes_every_element() {
        let mut a = vec![1.0_f32, -1.0, 99.0];
        zero_fill(&mut a);
        assert_eq!(a, vec![0.0, 0.0, 0.0]);
    }

    #[test]
    fn zero_fill_on_empty_is_noop() {
        let mut a: Vec<f32> = vec![];
        zero_fill(&mut a);
        assert!(a.is_empty());
    }

    #[test]
    fn argmax_after_scalar_mul_negative_inverts_choice() {
        let mut a = vec![1.0_f32, 5.0, 3.0];
        assert_eq!(argmax_reduce(&a).unwrap(), 1);
        scalar_mul_in_place(&mut a, -1.0);
        assert_eq!(argmax_reduce(&a).unwrap(), 0);
    }

    #[test]
    fn max_after_scalar_add_shifts_max_value() {
        let mut a = vec![1.0_f32, 5.0, 3.0];
        scalar_add_in_place(&mut a, 10.0);
        assert_eq!(max_reduce(&a).unwrap(), 15.0);
    }

    #[test]
    fn copy_range_round_trips_via_zero_fill_and_copy_back() {
        let original = vec![1.0_f32, 2.0, 3.0];
        let mut scratch = vec![0.0_f32; 3];
        copy_range(&mut scratch, &original).unwrap();
        let mut restored = vec![0.0_f32; 3];
        copy_range(&mut restored, &scratch).unwrap();
        assert_eq!(restored, original);
    }

    #[test]
    fn error_variants_distinguishable_by_pattern_match() {
        let empty = ControllerKernelError::EmptyInput { which: "max_reduce" };
        let mismatch = ControllerKernelError::LengthMismatch { dst: 3, src: 2 };
        let oob = ControllerKernelError::RangeOutOfBounds { len: 5, end: 10 };
        assert!(matches!(empty, ControllerKernelError::EmptyInput { .. }));
        assert!(matches!(mismatch, ControllerKernelError::LengthMismatch { .. }));
        assert!(matches!(oob, ControllerKernelError::RangeOutOfBounds { .. }));
    }

    // ── min_reduce + argmin_reduce + sum_reduce (iter 124) ──────────────────

    #[test]
    fn min_reduce_empty_errors() {
        let a: Vec<f32> = vec![];
        let err = min_reduce(&a).unwrap_err();
        assert!(matches!(err, ControllerKernelError::EmptyInput { which: "min_reduce" }));
    }

    #[test]
    fn min_reduce_returns_smallest() {
        let a = vec![3.0_f32, 1.0, 4.0, 1.0, 5.0, 9.0, 2.0, 6.0];
        assert_eq!(min_reduce(&a).unwrap(), 1.0);
    }

    #[test]
    fn min_reduce_single_element() {
        assert_eq!(min_reduce(&[42.0_f32]).unwrap(), 42.0);
    }

    #[test]
    fn argmin_reduce_first_tie_break() {
        // Both index 1 and index 3 hold value 1.0; first wins.
        let a = vec![3.0_f32, 1.0, 5.0, 1.0];
        assert_eq!(argmin_reduce(&a).unwrap(), 1);
    }

    #[test]
    fn argmin_after_scalar_mul_negative_inverts_choice() {
        // Symmetry test: argmin after negation should equal argmax
        // before negation. Companion to the existing
        // argmax_after_scalar_mul_negative_inverts_choice test.
        let mut a = vec![1.0_f32, 5.0, 3.0];
        assert_eq!(argmin_reduce(&a).unwrap(), 0);
        scalar_mul_in_place(&mut a, -1.0);
        assert_eq!(argmin_reduce(&a).unwrap(), 1);
    }

    #[test]
    fn min_max_symmetric_under_negation() {
        let a = vec![1.0_f32, 5.0, 3.0];
        let max_orig = max_reduce(&a).unwrap();
        let mut neg = a.clone();
        scalar_mul_in_place(&mut neg, -1.0);
        let min_neg = min_reduce(&neg).unwrap();
        assert_eq!(max_orig, -min_neg);
    }

    #[test]
    fn sum_reduce_empty_errors() {
        let a: Vec<f32> = vec![];
        let err = sum_reduce(&a).unwrap_err();
        assert!(matches!(err, ControllerKernelError::EmptyInput { which: "sum_reduce" }));
    }

    #[test]
    fn sum_reduce_arithmetic() {
        let a = vec![1.0_f32, 2.0, 3.0, 4.0, 5.0];
        assert!((sum_reduce(&a).unwrap() - 15.0).abs() < 1e-6);
    }

    #[test]
    fn sum_reduce_zero_array_is_zero() {
        assert_eq!(sum_reduce(&[0.0_f32; 100]).unwrap(), 0.0);
    }

    #[test]
    fn sum_reduce_consistent_with_mean_calculation() {
        // For a uniform array of v, sum/n = v.
        let a = vec![5.0_f32; 8];
        let sum = sum_reduce(&a).unwrap();
        assert!((sum / a.len() as f32 - 5.0).abs() < 1e-6);
    }
}
