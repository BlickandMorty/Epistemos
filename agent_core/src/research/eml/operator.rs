//! Source: V6.1 integration §1.2 + Odrzywołek arXiv:2603.21852.
//!
//! # The EML primitive
//!
//! `eml(x, y) = exp(x) − ln(y)` with principal branch over ℂ + terminal `1`.
//! Grammar `S → 1 | eml(S, S)` generates every elementary function on the
//! Liouvillian-solvable subdomain.
//!
//! Substrate floor uses fp64 internally to lock the reference value; the
//! ULP fixture compares against this reference at fp16 to enforce the
//! ≤ 2 ULP fp16 tolerance acceptance bar.

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum EmlError {
    NonPositiveLogArg { y: f64 },
    NonFiniteResult { x: f64, y: f64, result: f64 },
}

/// `eml(x, y) = exp(x) − ln(y)`. Rejects `y ≤ 0` (ln branch cut) and
/// any input that produces non-finite output (overflow / NaN).
pub fn eml(x: f64, y: f64) -> Result<f64, EmlError> {
    if y <= 0.0 || !y.is_finite() {
        return Err(EmlError::NonPositiveLogArg { y });
    }
    if !x.is_finite() {
        return Err(EmlError::NonFiniteResult { x, y, result: f64::NAN });
    }
    let r = x.exp() - y.ln();
    if !r.is_finite() {
        return Err(EmlError::NonFiniteResult { x, y, result: r });
    }
    Ok(r)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn eml_zero_one_equals_one() {
        assert!((eml(0.0, 1.0).unwrap() - 1.0).abs() < 1e-12);
    }

    #[test]
    fn eml_one_e_equals_e_minus_one() {
        let r = eml(1.0, std::f64::consts::E).unwrap();
        assert!((r - (std::f64::consts::E - 1.0)).abs() < 1e-12);
    }

    #[test]
    fn eml_zero_positive_returns_negative_ln_y() {
        let r = eml(0.0, 2.0).unwrap();
        assert!((r - (1.0 - 2.0_f64.ln())).abs() < 1e-12);
    }

    #[test]
    fn eml_rejects_zero_y() {
        let err = eml(1.0, 0.0).unwrap_err();
        assert_eq!(err, EmlError::NonPositiveLogArg { y: 0.0 });
    }

    #[test]
    fn eml_rejects_negative_y() {
        let err = eml(1.0, -1.0).unwrap_err();
        assert_eq!(err, EmlError::NonPositiveLogArg { y: -1.0 });
    }

    #[test]
    fn eml_rejects_nan_y() {
        let err = eml(1.0, f64::NAN).unwrap_err();
        assert!(matches!(err, EmlError::NonPositiveLogArg { .. }));
    }

    #[test]
    fn eml_rejects_inf_x_via_non_finite_result() {
        let err = eml(f64::INFINITY, 1.0).unwrap_err();
        assert!(matches!(err, EmlError::NonFiniteResult { .. }));
    }

    #[test]
    fn eml_rejects_huge_x_that_overflows() {
        let err = eml(1e10, 1.0).unwrap_err();
        assert!(matches!(err, EmlError::NonFiniteResult { .. }));
    }

    #[test]
    fn eml_finite_at_normal_range() {
        for &x in &[-2.0_f64, -1.0, 0.0, 1.0, 2.0] {
            for &y in &[0.5_f64, 1.0, 2.0, 10.0] {
                assert!(eml(x, y).is_ok(), "eml({}, {}) failed", x, y);
            }
        }
    }
}
