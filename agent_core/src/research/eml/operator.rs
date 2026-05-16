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

/// `∂eml/∂x = exp(x)`. Rejects non-finite `x` and non-finite result.
/// The `y` argument is ignored (partial doesn't depend on it) but
/// kept in the signature for symmetry with [`eml`] and
/// [`eml_partial_y`].
pub fn eml_partial_x(x: f64, _y: f64) -> Result<f64, EmlError> {
    if !x.is_finite() {
        return Err(EmlError::NonFiniteResult { x, y: _y, result: f64::NAN });
    }
    let r = x.exp();
    if !r.is_finite() {
        return Err(EmlError::NonFiniteResult { x, y: _y, result: r });
    }
    Ok(r)
}

/// `∂eml/∂y = -1/y`. Rejects `y ≤ 0` (matches [`eml`]'s branch cut)
/// and non-finite `y`.
pub fn eml_partial_y(_x: f64, y: f64) -> Result<f64, EmlError> {
    if y <= 0.0 || !y.is_finite() {
        return Err(EmlError::NonPositiveLogArg { y });
    }
    Ok(-1.0 / y)
}

/// Solve for `x` given `(z, y)` such that `eml(x, y) = z`:
/// `x = ln(z + ln(y))`. Requires `z + ln(y) > 0` (the inner log's
/// branch cut); rejects `y ≤ 0` and any non-finite intermediate.
/// The "find the x that produces this z" inverse — the F-Action-Demo
/// search workflow needs this to back-solve target trajectories.
pub fn eml_inverse_x(z: f64, y: f64) -> Result<f64, EmlError> {
    if y <= 0.0 || !y.is_finite() {
        return Err(EmlError::NonPositiveLogArg { y });
    }
    if !z.is_finite() {
        return Err(EmlError::NonFiniteResult { x: z, y, result: f64::NAN });
    }
    let inner = z + y.ln();
    if inner <= 0.0 {
        // ln of non-positive — no real x satisfies eml(x, y) = z here.
        return Err(EmlError::NonPositiveLogArg { y: inner });
    }
    let x = inner.ln();
    if !x.is_finite() {
        return Err(EmlError::NonFiniteResult { x: z, y, result: x });
    }
    Ok(x)
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

    // ── partials + inverse tests (iter 133) ─────────────────────────────────

    fn approx(a: f64, b: f64, tol: f64) -> bool {
        (a - b).abs() < tol
    }

    #[test]
    fn partial_x_at_zero_is_one() {
        assert!(approx(eml_partial_x(0.0, 1.0).unwrap(), 1.0, 1e-12));
    }

    #[test]
    fn partial_x_at_one_is_e() {
        assert!(approx(eml_partial_x(1.0, 1.0).unwrap(), std::f64::consts::E, 1e-12));
    }

    #[test]
    fn partial_x_ignores_y() {
        // ∂eml/∂x doesn't depend on y. Same x → same partial regardless
        // of y.
        let a = eml_partial_x(0.5, 1.0).unwrap();
        let b = eml_partial_x(0.5, 100.0).unwrap();
        assert!(approx(a, b, 1e-12));
    }

    #[test]
    fn partial_x_rejects_nan() {
        assert!(eml_partial_x(f64::NAN, 1.0).is_err());
    }

    #[test]
    fn partial_y_at_one_is_minus_one() {
        assert!(approx(eml_partial_y(0.0, 1.0).unwrap(), -1.0, 1e-12));
    }

    #[test]
    fn partial_y_at_two_is_minus_half() {
        assert!(approx(eml_partial_y(0.0, 2.0).unwrap(), -0.5, 1e-12));
    }

    #[test]
    fn partial_y_rejects_zero_y() {
        assert!(matches!(
            eml_partial_y(0.0, 0.0).unwrap_err(),
            EmlError::NonPositiveLogArg { .. }
        ));
    }

    #[test]
    fn inverse_round_trip_at_one_e() {
        // eml(1, e) = e^1 - ln(e) = e - 1.
        // eml_inverse_x(e - 1, e) should give 1.
        let y = std::f64::consts::E;
        let z = eml(1.0, y).unwrap();
        let x = eml_inverse_x(z, y).unwrap();
        assert!(approx(x, 1.0, 1e-12));
    }

    #[test]
    fn inverse_round_trip_at_zero_one() {
        // eml(0, 1) = 1.
        let z = eml(0.0, 1.0).unwrap();
        let x = eml_inverse_x(z, 1.0).unwrap();
        assert!(approx(x, 0.0, 1e-12));
    }

    #[test]
    fn inverse_rejects_z_plus_ln_y_non_positive() {
        // z = -10, y = 1 → inner = -10 + 0 = -10; ln undefined.
        let err = eml_inverse_x(-10.0, 1.0).unwrap_err();
        assert!(matches!(err, EmlError::NonPositiveLogArg { .. }));
    }

    #[test]
    fn inverse_rejects_zero_y() {
        assert!(matches!(
            eml_inverse_x(1.0, 0.0).unwrap_err(),
            EmlError::NonPositiveLogArg { .. }
        ));
    }

    #[test]
    fn forward_inverse_round_trip_grid() {
        // For a grid of (x, y), forward then inverse should recover x.
        for &x in &[-1.5_f64, -0.5, 0.0, 0.5, 1.5] {
            for &y in &[0.5_f64, 1.0, 2.0] {
                let z = eml(x, y).unwrap();
                let recovered = eml_inverse_x(z, y);
                if let Ok(rec) = recovered {
                    assert!(
                        approx(rec, x, 1e-9),
                        "x={}, y={}: z={}, recovered={}",
                        x, y, z, rec
                    );
                }
            }
        }
    }
}
