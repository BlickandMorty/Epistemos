//! Source:
//! - Conway, J. H., Sloane, N. J. A., "Sphere Packings, Lattices and
//!   Groups", Springer 1988 (3rd ed. 1999) — canonical reference. The
//!   Leech lattice nearest-point algorithm is Algorithm 6 in Chapter
//!   20 ("Algorithms for finding the closest lattice point"); requires
//!   binary Golay (G_24) decoding which we explicitly defer.
//! - Huang et al., arXiv:2603.11021 — Leech-Lattice Vector
//!   Quantization (the production target J7 builds toward).
//! - NestQuant, arXiv:2502.09720 — nested-lattice VQ that uses E8 +
//!   Leech as second-moment-shaping codebooks.
//! - `docs/fusion/jordan's research/helios v3.md` Part II T_K row:
//!   `G(Leech_24) = 0.0658` — second-moment shaping gain (the reason
//!   we want this lattice over a plain cubic Z^24 quantizer).
//! - Companion to [`super::e8`] (J7 #2, the 8-dimensional sibling).
//!
//! # J7 #3 — Leech-24 lattice substrate
//!
//! The Leech lattice Λ_24 is the unique 24-dimensional even unimodular
//! lattice with no vectors of squared-norm 2. It is the optimal
//! sphere-packing lattice in 24 dimensions (Cohn-Kumar-Miller-
//! Radchenko-Viazovska 2017). Its kissing number 196 560 is also
//! optimal.
//!
//! For substrate-floor purposes this module ships:
//!
//! 1. **Canonical constants** — dimension, shaping gain, kissing
//!    number, minimum squared norm. Future code that references the
//!    Leech lattice MUST source these constants from here so the
//!    numbers can't drift between modules.
//! 2. **`Leech24Point`** — typed envelope around a `[f64; 24]`
//!    coordinate vector with helpers for `norm_squared`, addition,
//!    and scalar multiply.
//! 3. **`nearest_leech_point_placeholder`** — substrate-floor
//!    nearest-point oracle that simply rounds each coordinate to the
//!    nearest integer (Z^24 nearest-point). Documented as a
//!    placeholder; production replaces with Conway-Sloane Ch. 20
//!    Algorithm 6 which decodes through the binary Golay code G_24.
//!    The placeholder is exposed so downstream substrate (residency
//!    layer, KV-cache quantizer) can wire against the typed API
//!    today and the real decoder lands behind the same signature.
//!
//! ## Why a placeholder is honest substrate
//!
//! A true Leech decoder requires a working Golay (24, 12, 8) decoder,
//! which we haven't built yet (and which is itself a non-trivial
//! kernel — minimum-weight-coset enumeration over 4 096 cosets). The
//! placeholder lets the rest of the pipeline compile and exercise the
//! envelope shape without claiming to deliver the 0.0658 second-moment
//! shaping gain. Callers that need the real gain MUST gate behind a
//! capability check; the placeholder returns a Z^24 point that lies
//! on the Leech lattice only when the input already does.

use serde::{Deserialize, Serialize};

/// Canonical dimension of the Leech lattice.
pub const LEECH_DIMENSION: usize = 24;

/// Second-moment shaping gain `G(Λ_24)` per Conway-Sloane / Helios v3
/// Part II T_K. The production KV-cache quantizer trades a 0.0658
/// distortion-rate reduction (versus cubic Z^24) for the cost of a
/// Leech decoder. Substrate value pinned here so callers can't drift.
pub const LEECH_SHAPING_GAIN: f64 = 0.0658;

/// Kissing number (number of unit spheres touching the central one in
/// the optimal Leech packing). Famous combinatorial constant from
/// Leech 1967; proven optimal by CKMRV 2017.
pub const LEECH_KISSING_NUMBER: u32 = 196_560;

/// Minimum squared norm of a non-zero Leech vector under the standard
/// normalization (lattice scaled so the minimum vectors have norm² 4).
/// Equivalently: the Leech lattice has no roots (no vectors of norm² 2),
/// which is the defining property that distinguishes it from the
/// related Niemeier lattices.
pub const LEECH_MIN_NORM_SQUARED: f64 = 4.0;

#[derive(Clone, Copy, Debug, PartialEq, Serialize, Deserialize)]
pub struct Leech24Point {
    pub coords: [f64; LEECH_DIMENSION],
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum LeechError {
    DimensionMismatch { got: usize, expected: usize },
    NonFiniteCoordinate { index: usize },
}

impl LeechError {
    /// Stable identifier for the failure cause.
    pub const fn cause(&self) -> &'static str {
        match self {
            LeechError::DimensionMismatch { .. } => "dimension_mismatch",
            LeechError::NonFiniteCoordinate { .. } => "non_finite_coordinate",
        }
    }

    pub const fn is_dimension_mismatch(&self) -> bool {
        matches!(self, LeechError::DimensionMismatch { .. })
    }

    /// Cross-surface invariant: `is_dimension_mismatch XOR
    /// is_non_finite_coordinate` partitions all variants.
    pub const fn is_non_finite_coordinate(&self) -> bool {
        matches!(self, LeechError::NonFiniteCoordinate { .. })
    }
}

impl Leech24Point {
    pub fn zero() -> Self {
        Self { coords: [0.0; LEECH_DIMENSION] }
    }

    pub fn from_slice(slice: &[f64]) -> Result<Self, LeechError> {
        if slice.len() != LEECH_DIMENSION {
            return Err(LeechError::DimensionMismatch {
                got: slice.len(),
                expected: LEECH_DIMENSION,
            });
        }
        let mut coords = [0.0; LEECH_DIMENSION];
        for (i, &v) in slice.iter().enumerate() {
            if !v.is_finite() {
                return Err(LeechError::NonFiniteCoordinate { index: i });
            }
            coords[i] = v;
        }
        Ok(Self { coords })
    }

    pub fn norm_squared(&self) -> f64 {
        self.coords.iter().map(|c| c * c).sum()
    }

    pub fn add(&self, other: &Self) -> Self {
        let mut out = [0.0; LEECH_DIMENSION];
        for i in 0..LEECH_DIMENSION {
            out[i] = self.coords[i] + other.coords[i];
        }
        Self { coords: out }
    }

    pub fn scale(&self, k: f64) -> Self {
        let mut out = [0.0; LEECH_DIMENSION];
        for i in 0..LEECH_DIMENSION {
            out[i] = self.coords[i] * k;
        }
        Self { coords: out }
    }

    /// Pointwise subtraction `self - other`. Cross-surface invariant:
    /// `a.sub(b).add(b) == a` (within fp precision).
    pub fn sub(&self, other: &Self) -> Self {
        let mut out = [0.0; LEECH_DIMENSION];
        for i in 0..LEECH_DIMENSION {
            out[i] = self.coords[i] - other.coords[i];
        }
        Self { coords: out }
    }

    /// Squared Euclidean distance to `other`: `Σ (self[i] - other[i])²`.
    /// Cross-surface invariants: `distance_squared(a, a) == 0`;
    /// `distance_squared(a, b) == distance_squared(b, a)` (symmetric).
    pub fn distance_squared(&self, other: &Self) -> f64 {
        self.coords
            .iter()
            .zip(other.coords.iter())
            .map(|(a, b)| (a - b) * (a - b))
            .sum()
    }

    /// Predicate: every coordinate is exactly 0.0.
    pub fn is_zero(&self) -> bool {
        self.coords.iter().all(|&c| c == 0.0)
    }

    /// Predicate: every coordinate is an integer (the point lies on
    /// Z^24, which is a strict superset of the Leech lattice). Cross-
    /// surface invariant: [`nearest_leech_point_placeholder`] output
    /// always satisfies this.
    pub fn is_integer_lattice_point(&self) -> bool {
        self.coords.iter().all(|&c| c.fract() == 0.0)
    }
}

/// Squared quantization error from `input` to `quantized`. Companion to
/// [`nearest_leech_point_placeholder`] for the rate-distortion
/// telemetry pipeline. Just an alias for
/// `input.distance_squared(quantized)` but reads more clearly at the
/// call site.
pub fn leech_quantization_error(input: &Leech24Point, quantized: &Leech24Point) -> f64 {
    input.distance_squared(quantized)
}

/// Substrate-floor nearest-point oracle. Rounds each coordinate to the
/// nearest integer (Z^24). **This is NOT a true Leech decoder** — the
/// real decoder requires Golay (24,12) decoding (Conway-Sloane Ch. 20
/// Algorithm 6). The placeholder is exposed so downstream code can wire
/// against the typed API today; the real implementation lands behind
/// the same signature once the Golay decoder ships.
///
/// Returned point lies on Z^24, which is a strict superset of Λ_24.
/// Callers MUST NOT assume the result is on the Leech lattice without
/// a follow-on `is_on_leech_lattice` check (which would itself need
/// the Golay machinery to be reliable).
pub fn nearest_leech_point_placeholder(input: &Leech24Point) -> Leech24Point {
    let mut coords = [0.0; LEECH_DIMENSION];
    for i in 0..LEECH_DIMENSION {
        coords[i] = input.coords[i].round();
    }
    Leech24Point { coords }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn dimension_is_24() {
        assert_eq!(LEECH_DIMENSION, 24);
    }

    #[test]
    fn shaping_gain_pinned() {
        assert!((LEECH_SHAPING_GAIN - 0.0658).abs() < 1e-9);
    }

    #[test]
    fn kissing_number_pinned() {
        assert_eq!(LEECH_KISSING_NUMBER, 196_560);
    }

    #[test]
    fn min_norm_squared_pinned() {
        assert!((LEECH_MIN_NORM_SQUARED - 4.0).abs() < 1e-12);
    }

    #[test]
    fn zero_point_has_zero_norm() {
        let z = Leech24Point::zero();
        assert_eq!(z.norm_squared(), 0.0);
    }

    #[test]
    fn from_slice_rejects_wrong_dimension() {
        let bad = vec![0.0; 23];
        assert!(matches!(
            Leech24Point::from_slice(&bad).unwrap_err(),
            LeechError::DimensionMismatch { got: 23, expected: 24 }
        ));
        let bad = vec![0.0; 25];
        assert!(matches!(
            Leech24Point::from_slice(&bad).unwrap_err(),
            LeechError::DimensionMismatch { got: 25, expected: 24 }
        ));
    }

    #[test]
    fn from_slice_rejects_nan() {
        let mut v = vec![0.0; 24];
        v[7] = f64::NAN;
        assert!(matches!(
            Leech24Point::from_slice(&v).unwrap_err(),
            LeechError::NonFiniteCoordinate { index: 7 }
        ));
    }

    #[test]
    fn from_slice_rejects_infinity() {
        let mut v = vec![0.0; 24];
        v[0] = f64::INFINITY;
        assert!(matches!(
            Leech24Point::from_slice(&v).unwrap_err(),
            LeechError::NonFiniteCoordinate { index: 0 }
        ));
    }

    #[test]
    fn from_slice_accepts_24_finite() {
        let v: Vec<f64> = (0..24).map(|i| i as f64).collect();
        let p = Leech24Point::from_slice(&v).unwrap();
        assert_eq!(p.coords[0], 0.0);
        assert_eq!(p.coords[23], 23.0);
    }

    #[test]
    fn norm_squared_matches_sum_of_squares() {
        let v: Vec<f64> = (1..=24).map(|i| i as f64).collect();
        let p = Leech24Point::from_slice(&v).unwrap();
        let expected: f64 = (1..=24).map(|i| (i * i) as f64).sum();
        assert!((p.norm_squared() - expected).abs() < 1e-9);
    }

    #[test]
    fn add_is_pointwise() {
        let a = Leech24Point::from_slice(&vec![1.0; 24]).unwrap();
        let b = Leech24Point::from_slice(&vec![2.0; 24]).unwrap();
        let c = a.add(&b);
        assert!(c.coords.iter().all(|&x| x == 3.0));
    }

    #[test]
    fn scale_multiplies_every_coordinate() {
        let a = Leech24Point::from_slice(&vec![1.0; 24]).unwrap();
        let b = a.scale(2.5);
        assert!(b.coords.iter().all(|&x| x == 2.5));
    }

    #[test]
    fn placeholder_rounds_to_nearest_integer() {
        let v: Vec<f64> = (0..24).map(|i| i as f64 + 0.3).collect();
        let p = Leech24Point::from_slice(&v).unwrap();
        let q = nearest_leech_point_placeholder(&p);
        for i in 0..24 {
            assert_eq!(q.coords[i], i as f64);
        }
    }

    #[test]
    fn placeholder_rounds_negative_correctly() {
        let v: Vec<f64> = vec![-0.6; 24];
        let p = Leech24Point::from_slice(&v).unwrap();
        let q = nearest_leech_point_placeholder(&p);
        for i in 0..24 {
            assert_eq!(q.coords[i], -1.0);
        }
    }

    #[test]
    fn placeholder_is_idempotent_on_integer_points() {
        let v: Vec<f64> = (0..24).map(|i| i as f64).collect();
        let p = Leech24Point::from_slice(&v).unwrap();
        let q = nearest_leech_point_placeholder(&p);
        assert_eq!(p, q);
        let qq = nearest_leech_point_placeholder(&q);
        assert_eq!(q, qq);
    }

    #[test]
    fn leech_serde_roundtrip() {
        let v: Vec<f64> = (0..24).map(|i| i as f64).collect();
        let p = Leech24Point::from_slice(&v).unwrap();
        let json = serde_json::to_string(&p).unwrap();
        let back: Leech24Point = serde_json::from_str(&json).unwrap();
        assert_eq!(p, back);
    }

    // ── diagnostic surface (iter 176) ────────────────────────────────────────

    #[test]
    fn error_cause_distinct() {
        let variants = [
            LeechError::DimensionMismatch { got: 23, expected: 24 },
            LeechError::NonFiniteCoordinate { index: 0 },
        ];
        let causes: std::collections::HashSet<_> = variants.iter().map(|e| e.cause()).collect();
        assert_eq!(causes.len(), 2);
    }

    #[test]
    fn error_classifiers_partition() {
        // Cross-surface invariant: is_dimension_mismatch XOR is_non_finite_coordinate.
        for e in [
            LeechError::DimensionMismatch { got: 23, expected: 24 },
            LeechError::NonFiniteCoordinate { index: 0 },
        ] {
            assert_ne!(e.is_dimension_mismatch(), e.is_non_finite_coordinate());
        }
    }

    #[test]
    fn sub_is_pointwise_and_inverse_of_add() {
        // Cross-surface invariant: a.sub(b).add(b) == a.
        let a = Leech24Point::from_slice(&(1..=24).map(|i| i as f64).collect::<Vec<_>>())
            .unwrap();
        let b = Leech24Point::from_slice(&vec![0.5; 24]).unwrap();
        let diff = a.sub(&b);
        let back = diff.add(&b);
        for i in 0..LEECH_DIMENSION {
            assert!((back.coords[i] - a.coords[i]).abs() < 1e-9);
        }
    }

    #[test]
    fn distance_squared_self_is_zero() {
        // Cross-surface invariant: distance_squared(a, a) == 0.
        let a = Leech24Point::from_slice(&vec![3.14; 24]).unwrap();
        assert_eq!(a.distance_squared(&a), 0.0);
    }

    #[test]
    fn distance_squared_symmetric() {
        // Cross-surface invariant: d²(a,b) == d²(b,a).
        let a = Leech24Point::from_slice(&(1..=24).map(|i| i as f64).collect::<Vec<_>>())
            .unwrap();
        let b = Leech24Point::from_slice(&vec![0.5; 24]).unwrap();
        assert!((a.distance_squared(&b) - b.distance_squared(&a)).abs() < 1e-9);
    }

    #[test]
    fn distance_squared_pythagorean_canonical() {
        // 24-dim version of 3-4-5: vector of all 1s vs vector of all 0s.
        let zero = Leech24Point::zero();
        let ones = Leech24Point::from_slice(&vec![1.0; 24]).unwrap();
        // d²(zero, ones) = 24 × 1² = 24.
        assert!((zero.distance_squared(&ones) - 24.0).abs() < 1e-9);
    }

    #[test]
    fn is_zero_matches_zero_factory() {
        let z = Leech24Point::zero();
        assert!(z.is_zero());
        let nz = Leech24Point::from_slice(&vec![0.0; 23].into_iter().chain([0.001]).collect::<Vec<_>>())
            .unwrap();
        assert!(!nz.is_zero());
    }

    #[test]
    fn is_integer_lattice_point_true_for_integer_coords() {
        let v: Vec<f64> = (0..24).map(|i| i as f64).collect();
        let p = Leech24Point::from_slice(&v).unwrap();
        assert!(p.is_integer_lattice_point());
    }

    #[test]
    fn is_integer_lattice_point_false_for_fractional_coords() {
        let mut v: Vec<f64> = vec![0.0; 24];
        v[5] = 1.5;
        let p = Leech24Point::from_slice(&v).unwrap();
        assert!(!p.is_integer_lattice_point());
    }

    #[test]
    fn placeholder_output_always_integer_lattice_point() {
        // Cross-surface invariant: nearest_leech_point_placeholder
        // output always lies on Z^24.
        let v: Vec<f64> = (0..24).map(|i| (i as f64) * 0.37 + 0.13).collect();
        let p = Leech24Point::from_slice(&v).unwrap();
        let q = nearest_leech_point_placeholder(&p);
        assert!(q.is_integer_lattice_point());
    }

    #[test]
    fn leech_quantization_error_alias_matches_distance_squared() {
        // Cross-surface: leech_quantization_error(a, b) == a.distance_squared(b).
        let a = Leech24Point::from_slice(&(0..24).map(|i| i as f64 * 0.5).collect::<Vec<_>>())
            .unwrap();
        let b = nearest_leech_point_placeholder(&a);
        assert!(
            (leech_quantization_error(&a, &b) - a.distance_squared(&b)).abs() < 1e-9
        );
    }
}
