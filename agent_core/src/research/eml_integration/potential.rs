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

use std::fmt;

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

impl fmt::Display for EmlPotential {
    /// Compact human-readable form: `EmlPotential { s: <raw>, value: <value> }`.
    /// Uses 6-decimal-digit precision — enough to distinguish typical
    /// SAE scores in `[0, 1]` without exposing all 15+ f64 digits.
    /// Useful for CLI logs, debug prints, and the diagnostic surface
    /// when a textual rendering is preferred over JSON.
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(
            f,
            "EmlPotential {{ s: {:.6}, value: {:.6} }}",
            self.raw_score, self.value
        )
    }
}

/// The exact f64 value of the EML-potential floor (= `eml(ln(1), 1) = 1.0`).
/// Compile-time constant for callers that need to compare against the floor
/// without constructing an EmlPotential. Pinned by
/// `potential::tests::floor_value_const_matches_from_zero_score`.
pub const FLOOR_VALUE: f64 = 1.0;

impl EmlPotential {
    /// True iff this potential was constructed from a zero score
    /// (raw_score == 0.0). At s=0.0 the encoding produces value
    /// exactly equal to [`FLOOR_VALUE`] (1.0) by f64 arithmetic; for
    /// very small s > 0 (below ~1e-8) the encoded value also rounds
    /// to 1.0 in f64 representation, so `is_floor` checks the source
    /// rather than the value — "was this constructed from zero?"
    /// reads cleaner than "did the value round to 1.0?".
    pub fn is_floor(&self) -> bool {
        self.raw_score == 0.0
    }

    /// The canonical sentinel: `EmlPotential::from_score(1.0)`. Used
    /// by the diagnostic surface (`compute_live_readout`) as a
    /// forward-stable canary against accidental encoding-change
    /// regressions — the value is `(1+1) − ln(1+1) = 2 − ln(2)
    /// ≈ 1.30685281944...`.
    ///
    /// Infallible by construction: `s = 1.0` is finite + non-negative,
    /// the encoded `y = 2.0` is strictly positive, and the encoded
    /// `x = ln(2) ≈ 0.693` is finite, so the underlying `eml(x, y)`
    /// returns Ok unconditionally. The `unwrap()` here is the
    /// documented infallibility point; cross-pinned by
    /// [`tests::sentinel_at_one_matches_from_score_one`].
    pub fn sentinel_at_one() -> Self {
        // SAFETY-ish discipline: from_score(1.0) cannot fail. The
        // property test below pins this; if a future encoding-change
        // PR breaks it, that test will fire before this unwrap
        // panics in production.
        #[allow(clippy::unwrap_used)]
        {
            Self::from_score(1.0).unwrap()
        }
    }

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

    // ── is_floor + FLOOR_VALUE tests (iter 27) ────────────────────────────

    #[test]
    fn floor_value_const_equals_one() {
        assert_eq!(FLOOR_VALUE, 1.0);
    }

    #[test]
    fn floor_value_const_matches_from_zero_score() {
        let p = EmlPotential::from_score(0.0).unwrap();
        assert_eq!(p.value(), FLOOR_VALUE);
    }

    #[test]
    fn is_floor_true_at_zero_score() {
        let p = EmlPotential::from_score(0.0).unwrap();
        assert!(p.is_floor());
    }

    #[test]
    fn is_floor_false_at_positive_score() {
        // is_floor checks raw_score, not value — so even very small s
        // (which f64-rounds the value to 1.0) is correctly is_floor=false.
        for &s in &[1e-9_f64, 0.001, 0.5, 1.0, 100.0] {
            let p = EmlPotential::from_score(s).unwrap();
            assert!(!p.is_floor(), "s={}: value={}", s, p.value());
        }
    }

    #[test]
    fn is_floor_uses_raw_score_not_value() {
        // Documents the subtle precision case explicitly. For s = 1e-12,
        // f64 rounds (1+s) - ln(1+s) to exactly 1.0, but is_floor still
        // returns false because raw_score is nonzero.
        let p = EmlPotential::from_score(1e-12).unwrap();
        assert!(!p.is_floor(),
            "raw_score={} value={}", p.raw_score(), p.value());
        // Note: p.value() may equal FLOOR_VALUE under f64 rounding —
        // the assertion above proves we don't conflate that with floor.
    }

    #[test]
    fn is_floor_false_for_sentinel_at_one() {
        let p = EmlPotential::sentinel_at_one();
        assert!(!p.is_floor());
    }

    // ── Display impl tests (iter 25) ──────────────────────────────────────

    #[test]
    fn display_zero_score_format() {
        let p = EmlPotential::from_score(0.0).unwrap();
        let s = format!("{}", p);
        // Expected: "EmlPotential { s: 0.000000, value: 1.000000 }".
        assert!(s.contains("s: 0.000000"), "display: {}", s);
        assert!(s.contains("value: 1.000000"), "display: {}", s);
    }

    #[test]
    fn display_sentinel_format() {
        let p = EmlPotential::sentinel_at_one();
        let s = format!("{}", p);
        assert!(s.contains("s: 1.000000"), "display: {}", s);
        // 2 − ln(2) ≈ 1.306853 → "1.306853" with 6-digit precision.
        assert!(s.contains("value: 1.306853"), "display: {}", s);
    }

    #[test]
    fn display_includes_struct_name_for_grep_friendliness() {
        let p = EmlPotential::from_score(0.5).unwrap();
        let s = format!("{}", p);
        assert!(s.starts_with("EmlPotential {"),
            "display should start with type name: {}", s);
    }

    #[test]
    fn display_format_is_stable_across_calls() {
        let p = EmlPotential::from_score(0.42).unwrap();
        let s1 = format!("{}", p);
        let s2 = format!("{}", p);
        assert_eq!(s1, s2);
    }

    // ── sentinel_at_one tests (iter 21) ───────────────────────────────────

    #[test]
    fn sentinel_at_one_matches_from_score_one() {
        // The infallibility-discipline pin: if from_score(1.0) ever
        // changes its result, the unwrap inside sentinel_at_one would
        // need to be re-examined. This test fires first.
        let sentinel = EmlPotential::sentinel_at_one();
        let direct = EmlPotential::from_score(1.0).unwrap();
        assert_eq!(sentinel, direct);
    }

    #[test]
    fn sentinel_at_one_value_equals_two_minus_ln_two() {
        let s = EmlPotential::sentinel_at_one();
        let expected = 2.0_f64 - 2.0_f64.ln();
        assert!((s.value() - expected).abs() < 1e-12,
            "sentinel value was {}, expected {}", s.value(), expected);
    }

    #[test]
    fn sentinel_at_one_encoded_fields_match_closed_form() {
        let s = EmlPotential::sentinel_at_one();
        assert!(approx(s.raw_score(), 1.0, 1e-12));
        assert!(approx(s.y(), 2.0, 1e-12));
        assert!(approx(s.x(), 2.0_f64.ln(), 1e-12));
    }

    #[test]
    fn sentinel_at_one_is_deterministic_across_calls() {
        // Pure function; two calls return the same value.
        let a = EmlPotential::sentinel_at_one();
        let b = EmlPotential::sentinel_at_one();
        assert_eq!(a, b);
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
