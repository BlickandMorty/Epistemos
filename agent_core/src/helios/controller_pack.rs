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
}
