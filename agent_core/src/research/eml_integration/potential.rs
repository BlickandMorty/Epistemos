//! Source:
//! - `docs/fusion/EML_INTEGRATION_DOCTRINE_2026_05_17.md` §3.2 — the
//!   `EmlPotential` design with encoding `x = ln(1 + s)`, `y = 1 + s`.
//! - Companion: [`super::super::eml::operator::eml`] — the substrate
//!   binary primitive this newtype wraps.
//! - Odrzywołek arXiv:2603.21852 — universality proof for `eml(x, y) =
//!   exp(x) − ln(y)` on the Liouvillian-solvable subdomain. The
//!   encoding here is one specific point in the subdomain; the
//!   resulting potential value carries the same universality guarantee
//!   as the underlying primitive.
//!
//! # EmlPotential — monotone-encoded EML over a strictly-positive score
//!
//! Given a non-negative finite scalar `s` (interpreted as a score —
//! e.g. a feature-firing magnitude from the SAE Cognition Observatory,
//! a BM25 hit-strength from F-VaultRecall, a confidence estimate from
//! the ConfidenceRouter), `EmlPotential::from_score(s)` constructs a
//! deterministic potential value:
//!
//! ```text
//! x = ln(1 + s)        // always finite for any finite s ≥ 0
//! y = 1 + s             // strictly positive for s ≥ 0
//! value = eml(x, y)     // = exp(ln(1+s)) − ln(1+s) = (1+s) − ln(1+s)
//! ```
//!
//! ## Properties (paper-pinned + property-tested)
//!
//! - **Floor**: `value(0) = (1 + 0) − ln(1 + 0) = 1 − 0 = 1.0`.
//! - **Monotone-increasing in `s`** for `s ≥ 0`. Proof: derivative
//!   `dv/ds = 1 − 1/(1 + s)` is `> 0` for any `s > 0`. Pinned by the
//!   property test [`tests::monotone_in_score_across_grid`].
//! - **Bounded below by 1.0** for any valid input. Pinned by
//!   [`tests::floor_holds_across_grid`].
//! - **Deterministic** — pure function of `s`. Pinned by
//!   [`tests::deterministic`].
//! - **Rejects `s < 0`** (out-of-domain) and **non-finite `s`** with
//!   typed errors.
//!
//! ## Why this specific encoding?
//!
//! The doctrine doc §3.3 establishes the **AUC-preserving cornerstone**:
//! because this encoding is a strictly monotone transform of `s`, the
//! rank-based AUC formula in `cognition_observatory::sae::auc_roc`
//! (Hanley & McNeil 1982; `sae.rs:144-201`) is **identically preserved**
//! when the augmented potential value replaces the raw score. This
//! makes the MVP integration semantically neutral on the existing
//! acceptance gate while still surfacing the EML potential as a
//! diagnostic.

use serde::{Deserialize, Serialize};

use super::super::eml::operator::{eml, EmlError};

/// A non-negative finite score, encoded into the EML primitive's
/// `(x, y) = (ln(1+s), 1+s)` shape and evaluated. The four fields
/// expose the raw score, the encoded inputs, and the resulting
/// potential value — auditable end-to-end.
///
/// Construct via [`Self::from_score`]. Direct field construction is
/// not supported (no public constructor) — every potential is the
/// result of the documented encoding, ensuring the §5 "no hand-waving"
/// rule holds.
///
/// Derives `Serialize` + `Deserialize` (iter 15) so the diagnostic
/// surface can carry a vector of potentials in its JSON payload. The
/// fields are serialized in canonical order
/// (`raw_score`, `x`, `y`, `value`) and a round-trip preserves
/// equality (pinned by [`tests::potential_serde_json_roundtrip`]).
#[derive(Clone, Copy, Debug, PartialEq, Serialize, Deserialize)]
pub struct EmlPotential {
    raw_score: f64,
    x: f64,
    y: f64,
    value: f64,
}

#[derive(Clone, Copy, Debug, PartialEq, Serialize, Deserialize)]
pub enum EmlPotentialError {
    /// Score was strictly less than zero — out of the encoding's
    /// domain.
    NegativeScore { score: f64 },
    /// Score was NaN or `±∞`. The encoded `x = ln(1+s)` cannot be a
    /// well-defined potential in that case.
    NonFiniteScore { score: f64 },
    /// The underlying `eml(x, y)` primitive rejected the encoded
    /// inputs (e.g. overflow when `s` is near f64::MAX). Carries the
    /// inner error verbatim for diagnostic.
    Operator(EmlError),
}

impl From<EmlError> for EmlPotentialError {
    fn from(e: EmlError) -> Self {
        EmlPotentialError::Operator(e)
    }
}

impl EmlPotential {
    /// Construct from a non-negative finite score. See module docs for
    /// the encoding and properties.
    pub fn from_score(s: f64) -> Result<Self, EmlPotentialError> {
        if !s.is_finite() {
            return Err(EmlPotentialError::NonFiniteScore { score: s });
        }
        if s < 0.0 {
            return Err(EmlPotentialError::NegativeScore { score: s });
        }
        let y = 1.0 + s;
        let x = y.ln();
        let value = eml(x, y)?;
        Ok(EmlPotential { raw_score: s, x, y, value })
    }

    /// Original score the potential was derived from.
    pub fn raw_score(&self) -> f64 {
        self.raw_score
    }

    /// Encoded `x` argument: `ln(1 + raw_score)`.
    pub fn x(&self) -> f64 {
        self.x
    }

    /// Encoded `y` argument: `1 + raw_score`.
    pub fn y(&self) -> f64 {
        self.y
    }

    /// Evaluated potential: `eml(x, y) = (1 + s) − ln(1 + s)`.
    pub fn value(&self) -> f64 {
        self.value
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn approx(a: f64, b: f64, tol: f64) -> bool {
        (a - b).abs() < tol
    }

    #[test]
    fn from_zero_score_is_potential_one() {
        // s = 0 → x = ln(1) = 0, y = 1, value = exp(0) - ln(1) = 1.
        let p = EmlPotential::from_score(0.0).unwrap();
        assert!(approx(p.raw_score(), 0.0, 1e-12));
        assert!(approx(p.x(), 0.0, 1e-12));
        assert!(approx(p.y(), 1.0, 1e-12));
        assert!(approx(p.value(), 1.0, 1e-12));
    }

    #[test]
    fn from_positive_score_exceeds_floor() {
        // For any s > 0, value > 1.0 (floor is strictly tight at s = 0).
        for &s in &[1e-6_f64, 0.1, 1.0, 10.0, 1000.0] {
            let p = EmlPotential::from_score(s).unwrap();
            assert!(p.value() > 1.0, "s={}: value={}", s, p.value());
        }
    }

    #[test]
    fn monotone_in_score_across_grid() {
        // Cornerstone property: dv/ds > 0 for any s > 0. Pinned across
        // a dense grid spanning multiple decades.
        let grid: Vec<f64> = (0..50).map(|i| 0.001 * (1.4_f64.powi(i))).collect();
        let values: Vec<f64> = grid
            .iter()
            .map(|&s| EmlPotential::from_score(s).unwrap().value())
            .collect();
        for w in values.windows(2) {
            assert!(w[0] < w[1], "monotonicity violated: {} >= {}", w[0], w[1]);
        }
    }

    #[test]
    fn floor_holds_across_grid() {
        // value ≥ 1.0 for any s ≥ 0.
        let grid: Vec<f64> = (0..50).map(|i| 0.001 * (1.4_f64.powi(i))).collect();
        for &s in &grid {
            let v = EmlPotential::from_score(s).unwrap().value();
            assert!(v >= 1.0, "floor violated at s={}: value={}", s, v);
        }
    }

    #[test]
    fn encoding_matches_closed_form() {
        // value = (1 + s) - ln(1 + s) by the encoding's algebra.
        for &s in &[0.0_f64, 0.5, 1.0, 7.5, 100.0] {
            let p = EmlPotential::from_score(s).unwrap();
            let expected = (1.0 + s) - (1.0 + s).ln();
            assert!(approx(p.value(), expected, 1e-9),
                "s={}: got {}, expected {}", s, p.value(), expected);
        }
    }

    #[test]
    fn encoded_y_equals_one_plus_score() {
        for &s in &[0.0_f64, 0.5, 2.0, 50.0] {
            let p = EmlPotential::from_score(s).unwrap();
            assert!(approx(p.y(), 1.0 + s, 1e-12));
        }
    }

    #[test]
    fn encoded_x_equals_log_one_plus_score() {
        for &s in &[0.0_f64, 0.5, 2.0, 50.0] {
            let p = EmlPotential::from_score(s).unwrap();
            assert!(approx(p.x(), (1.0 + s).ln(), 1e-12));
        }
    }

    #[test]
    fn rejects_negative_score() {
        let err = EmlPotential::from_score(-1.0).unwrap_err();
        assert_eq!(err, EmlPotentialError::NegativeScore { score: -1.0 });
    }

    #[test]
    fn rejects_negative_score_tiny() {
        // Even -ε rejects: the domain is [0, +∞).
        let err = EmlPotential::from_score(-1e-12).unwrap_err();
        assert!(matches!(err, EmlPotentialError::NegativeScore { .. }));
    }

    #[test]
    fn rejects_nan_score() {
        let err = EmlPotential::from_score(f64::NAN).unwrap_err();
        assert!(matches!(err, EmlPotentialError::NonFiniteScore { .. }));
    }

    #[test]
    fn rejects_positive_infinity_score() {
        let err = EmlPotential::from_score(f64::INFINITY).unwrap_err();
        assert!(matches!(err, EmlPotentialError::NonFiniteScore { .. }));
    }

    #[test]
    fn rejects_negative_infinity_score() {
        let err = EmlPotential::from_score(f64::NEG_INFINITY).unwrap_err();
        assert!(matches!(err, EmlPotentialError::NonFiniteScore { .. }));
    }

    #[test]
    fn deterministic() {
        // Pure function of s: same input → same output, regardless of
        // call count or ordering.
        for &s in &[0.0_f64, 1.0, 42.0] {
            let p1 = EmlPotential::from_score(s).unwrap();
            let p2 = EmlPotential::from_score(s).unwrap();
            let p3 = EmlPotential::from_score(s).unwrap();
            assert_eq!(p1, p2);
            assert_eq!(p2, p3);
        }
    }

    #[test]
    fn value_grows_approximately_linearly_for_large_s() {
        // For s >> 1: value ≈ (1+s) - ln(1+s) ≈ s. Sanity-check the
        // big-s growth rate so future encoding-change PRs flag any
        // accidental switch to a saturating form.
        let s = 1e6;
        let p = EmlPotential::from_score(s).unwrap();
        let ratio = p.value() / s;
        assert!(ratio > 0.99 && ratio < 1.01,
            "value/s ratio at s=1e6 was {} (expected ≈ 1)", ratio);
    }

    #[test]
    fn from_error_conversion_wraps_operator_error() {
        let inner = EmlError::NonPositiveLogArg { y: 0.0 };
        let wrapped: EmlPotentialError = inner.into();
        assert_eq!(wrapped, EmlPotentialError::Operator(inner));
    }

    // ── serde roundtrip tests (iter 15) ──────────────────────────────────────

    #[test]
    fn potential_serde_json_roundtrip() {
        let p = EmlPotential::from_score(2.5).unwrap();
        let json = serde_json::to_string(&p).unwrap();
        let back: EmlPotential = serde_json::from_str(&json).unwrap();
        assert_eq!(p, back);
        // Spot-check that the JSON contains the canonical field names.
        assert!(json.contains("\"raw_score\""), "json was {}", json);
        assert!(json.contains("\"x\""), "json was {}", json);
        assert!(json.contains("\"y\""), "json was {}", json);
        assert!(json.contains("\"value\""), "json was {}", json);
    }

    #[test]
    fn potential_error_serde_json_roundtrip() {
        // JSON serde maps NaN / ±Inf to `null`, which cannot deserialize
        // back into a typed f64 field. So we test only the finite-value
        // variants. The NonFiniteScore variant is exercised by
        // `rejects_nan_score` / `rejects_positive_infinity_score` /
        // `rejects_negative_infinity_score` instead.
        for err in [
            EmlPotentialError::NegativeScore { score: -1.5 },
            EmlPotentialError::Operator(EmlError::NonPositiveLogArg { y: 0.0 }),
            EmlPotentialError::Operator(EmlError::NonFiniteResult {
                x: 1.0,
                y: 1.0,
                result: 1.0,
            }),
        ] {
            let json = serde_json::to_string(&err).unwrap();
            let back: EmlPotentialError = serde_json::from_str(&json).unwrap();
            assert_eq!(err, back);
        }
    }
}
