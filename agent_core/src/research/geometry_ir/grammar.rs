//! Source:
//! - Hestenes-Sobczyk (Reidel 1984) Ch. 1 — geometric-product axioms:
//!   `e_i * e_j + e_j * e_i = 2 δ_ij` (here the orthonormal basis
//!   `e_1, e_2, e_3` for the Cl(3,0) geometric algebra G3).
//! - Dorst-Fontijne-Mann (Morgan Kaufmann 2007) §10.3 — rotor sandwich
//!   `v' = R v R̃` for 3D rotations.
//! - Doctrine §4.6 — Geometry-IR Rust crate-module shape.
//!
//! # Cl(3,0) multivector representation
//!
//! The 8 basis blades are encoded in [`Multivector::components`]:
//!
//! | Index | Blade   | Grade | Mnemonic            |
//! |-------|---------|-------|---------------------|
//! | 0     | 1       | 0     | scalar              |
//! | 1     | e_1     | 1     | vector x            |
//! | 2     | e_2     | 1     | vector y            |
//! | 3     | e_3     | 1     | vector z            |
//! | 4     | e_12    | 2     | bivector xy         |
//! | 5     | e_13    | 2     | bivector xz         |
//! | 6     | e_23    | 2     | bivector yz         |
//! | 7     | e_123   | 3     | pseudoscalar i      |
//!
//! Rotors are scalar + bivector parts (indices 0, 4, 5, 6).

use serde::{Deserialize, Serialize};
use std::fmt;

/// 8-component multivector in Cl(3,0). Indexing per the module
/// docstring's table.
#[derive(Clone, Copy, Debug, PartialEq, Serialize, Deserialize)]
pub struct Multivector {
    pub components: [f64; 8],
}

impl Multivector {
    /// Zero multivector.
    pub fn zero() -> Self {
        Multivector { components: [0.0; 8] }
    }

    /// Scalar `s` lifted to a grade-0-only multivector.
    pub fn scalar(s: f64) -> Self {
        let mut c = [0.0; 8];
        c[0] = s;
        Multivector { components: c }
    }

    /// Vector `x e_1 + y e_2 + z e_3` as a grade-1-only multivector.
    pub fn vector(x: f64, y: f64, z: f64) -> Self {
        let mut c = [0.0; 8];
        c[1] = x;
        c[2] = y;
        c[3] = z;
        Multivector { components: c }
    }

    /// Bivector `b12 e_12 + b13 e_13 + b23 e_23` as a grade-2-only
    /// multivector.
    pub fn bivector(b12: f64, b13: f64, b23: f64) -> Self {
        let mut c = [0.0; 8];
        c[4] = b12;
        c[5] = b13;
        c[6] = b23;
        Multivector { components: c }
    }

    /// Build a Cl(3, 0) rotor from a `(w, x, y, z)` quaternion.
    ///
    /// Inverse of [`Self::rotor_to_quaternion`]. The mapping:
    /// `scalar = w; b_12 = -z; b_13 = y; b_23 = -x`.
    ///
    /// Iter-155 — interop with quaternion-based libraries.
    pub fn from_quaternion(w: f64, x: f64, y: f64, z: f64) -> Multivector {
        let mut c = [0.0_f64; 8];
        c[0] = w;
        c[4] = -z; // b_12
        c[5] = y;  // b_13
        c[6] = -x; // b_23
        Multivector { components: c }
    }

    /// Convert a Cl(3, 0) rotor to a standard `(w, x, y, z)`
    /// quaternion. The rotor must be a rotor-candidate (scalar +
    /// bivector parts only); the conversion uses the mapping:
    ///
    /// `w = scalar; x = -b_23; y = b_13; z = -b_12`
    ///
    /// (matching the conventional right-handed quaternion ↔ Cl(3,0)
    /// bridge in geometric algebra texts).
    ///
    /// Returns `None` if the multivector has non-zero vector or
    /// pseudoscalar parts (not a rotor-candidate).
    ///
    /// Iter-149 — interop with quaternion-based libraries.
    pub fn rotor_to_quaternion(&self) -> Option<(f64, f64, f64, f64)> {
        if !self.is_rotor_candidate() {
            return None;
        }
        let w = self.scalar_part();
        let (b12, b13, b23) = self.bivector_part();
        Some((w, -b23, b13, -b12))
    }

    /// Euclidean distance to another multivector: `||self − other||`.
    ///
    /// Iter-143 — convenience method composing sub + norm.
    pub fn distance_to(&self, other: &Multivector) -> f64 {
        self.sub(other).norm()
    }

    /// Squared Euclidean distance to another multivector:
    /// `||self − other||²`. Avoids sqrt; useful for distance
    /// comparisons.
    ///
    /// Iter-143 — sqrt-free companion.
    pub fn squared_distance_to(&self, other: &Multivector) -> f64 {
        self.sub(other).norm_squared()
    }

    /// Unit basis vector `e_1` along x-axis. Iter-137.
    pub fn e1() -> Multivector { Self::vector(1.0, 0.0, 0.0) }

    /// Unit basis vector `e_2` along y-axis. Iter-137.
    pub fn e2() -> Multivector { Self::vector(0.0, 1.0, 0.0) }

    /// Unit basis vector `e_3` along z-axis. Iter-137.
    pub fn e3() -> Multivector { Self::vector(0.0, 0.0, 1.0) }

    /// Unit basis bivector `e_12` (xy-plane). Iter-137.
    pub fn e12() -> Multivector { Self::bivector(1.0, 0.0, 0.0) }

    /// Unit basis bivector `e_13` (xz-plane). Iter-137.
    pub fn e13() -> Multivector { Self::bivector(0.0, 1.0, 0.0) }

    /// Unit basis bivector `e_23` (yz-plane). Iter-137.
    pub fn e23() -> Multivector { Self::bivector(0.0, 0.0, 1.0) }

    /// Unit pseudoscalar `I = e_123`. Iter-137.
    pub fn pseudoscalar_unit() -> Multivector { Self::pseudoscalar(1.0) }

    /// Pseudoscalar `s e_123` as a grade-3-only multivector.
    pub fn pseudoscalar(s: f64) -> Self {
        let mut c = [0.0; 8];
        c[7] = s;
        Multivector { components: c }
    }

    /// Scalar part (grade 0).
    pub fn scalar_part(&self) -> f64 {
        self.components[0]
    }

    /// Vector part as `(x, y, z)`.
    pub fn vector_part(&self) -> (f64, f64, f64) {
        (self.components[1], self.components[2], self.components[3])
    }

    /// Bivector part as `(b12, b13, b23)`.
    pub fn bivector_part(&self) -> (f64, f64, f64) {
        (self.components[4], self.components[5], self.components[6])
    }

    /// Pseudoscalar part.
    pub fn pseudoscalar_part(&self) -> f64 {
        self.components[7]
    }

    /// Grade-k L² norm: `√(grade_norm_squared(grade))`.
    ///
    /// Iter-210 — un-squared companion to [`Self::grade_norm_squared`].
    /// Returns 0 if `grade` is outside the grade-0..3 range of Cl(3, 0).
    pub fn grade_norm(&self, grade: usize) -> f64 {
        self.grade_norm_squared(grade).sqrt()
    }

    /// Grade-k component norm² (sum of squares of grade-k coefficients).
    pub fn grade_norm_squared(&self, grade: usize) -> f64 {
        let indices: &[usize] = match grade {
            0 => &[0],
            1 => &[1, 2, 3],
            2 => &[4, 5, 6],
            3 => &[7],
            _ => &[],
        };
        indices.iter().map(|&i| self.components[i] * self.components[i]).sum()
    }

    /// Total multivector norm² = sum of squares across all 8 components.
    ///
    /// Iter-85 — companion to [`Self::grade_norm_squared`].
    pub fn norm_squared(&self) -> f64 {
        self.components.iter().map(|c| c * c).sum()
    }

    /// Total multivector Euclidean norm (`sqrt(norm_squared)`).
    ///
    /// Iter-85 — useful for rotor unit-norm checks and vector
    /// length computation.
    pub fn norm(&self) -> f64 {
        self.norm_squared().sqrt()
    }

    /// Subtract another multivector componentwise.
    ///
    /// Iter-85 — companion to [`Self::add`]; needed for
    /// antisymmetric-product (wedge) construction.
    pub fn sub(&self, other: &Multivector) -> Multivector {
        let mut c = [0.0; 8];
        for i in 0..8 {
            c[i] = self.components[i] - other.components[i];
        }
        Multivector { components: c }
    }

    /// True iff this multivector is approximately a unit rotor —
    /// rotor-candidate (scalar + bivector only) with norm² ≈ 1
    /// to within `tolerance`.
    ///
    /// Iter-85 — useful for verifying that rotor composition keeps
    /// the unit-norm invariant `R̃R = 1`.
    pub fn is_approximately_unit_rotor(&self, tolerance: f64) -> bool {
        self.is_rotor_candidate() && (self.norm_squared() - 1.0).abs() <= tolerance
    }

    /// True iff this multivector has non-zero coefficients ONLY in
    /// the specified grade (or is the zero multivector, which has
    /// no grade-specific support).
    ///
    /// Useful for type-like checks: `is_pure_grade(1)` matches a
    /// pure vector, `is_pure_grade(2)` matches a pure bivector, etc.
    ///
    /// Iter-104 — generalizes [`Self::is_scalar`] / [`Self::is_vector`]
    /// to arbitrary grade.
    pub fn is_pure_grade(&self, grade: usize) -> bool {
        let allowed: &[usize] = match grade {
            0 => &[0],
            1 => &[1, 2, 3],
            2 => &[4, 5, 6],
            3 => &[7],
            _ => return false,
        };
        for (i, c) in self.components.iter().enumerate() {
            if *c != 0.0 && !allowed.contains(&i) {
                return false;
            }
        }
        true
    }

    /// Extract the pure grade-k part of this multivector. Components
    /// outside the specified grade are zeroed.
    ///
    /// Examples:
    /// - `grade_projection(0)`: scalar part only.
    /// - `grade_projection(1)`: vector part only.
    /// - `grade_projection(2)`: bivector part only.
    /// - `grade_projection(3)`: pseudoscalar part only.
    /// - `grade_projection(k > 3)`: zero multivector.
    ///
    /// Iter-111 — multivector grade-filter; useful for separating
    /// mixed-grade results of geometric products.
    pub fn grade_projection(&self, grade: usize) -> Multivector {
        let mut out = [0.0_f64; 8];
        let indices: &[usize] = match grade {
            0 => &[0],
            1 => &[1, 2, 3],
            2 => &[4, 5, 6],
            3 => &[7],
            _ => &[],
        };
        for &i in indices {
            out[i] = self.components[i];
        }
        Multivector { components: out }
    }

    /// Return `Some(self / ||self||)` if the multivector is non-zero,
    /// else `None`. The result is a unit-norm multivector parallel
    /// to the original.
    ///
    /// Caller is responsible for the semantic meaning of "unit-norm"
    /// in their context; for pure vectors this is the standard
    /// Euclidean normalization.
    ///
    /// Iter-104 — companion to [`Self::norm`].
    pub fn normalize(&self) -> Option<Multivector> {
        let n = self.norm();
        if n == 0.0 || !n.is_finite() {
            None
        } else {
            Some(self.scale(1.0 / n))
        }
    }

    /// True iff this multivector is grade-0 only (pure scalar).
    pub fn is_scalar(&self) -> bool {
        (1..8).all(|i| self.components[i] == 0.0)
    }

    /// True iff this multivector is grade-1 only (pure vector).
    pub fn is_vector(&self) -> bool {
        self.components[0] == 0.0
            && (4..8).all(|i| self.components[i] == 0.0)
    }

    /// True iff this multivector is a rotor candidate (scalar +
    /// bivector parts only, grades 1 and 3 zero).
    pub fn is_rotor_candidate(&self) -> bool {
        (1..4).all(|i| self.components[i] == 0.0)
            && self.components[7] == 0.0
    }

    /// Reverse (~): for grade k, multiply by `(-1)^{k(k-1)/2}`.
    /// Grade 0: +; grade 1: +; grade 2: −; grade 3: −.
    pub fn reverse(&self) -> Multivector {
        let c = &self.components;
        Multivector {
            components: [
                c[0],   // scalar (+)
                c[1], c[2], c[3], // vector (+)
                -c[4], -c[5], -c[6], // bivector (−)
                -c[7], // pseudoscalar (−)
            ],
        }
    }

    /// Add two multivectors componentwise.
    pub fn add(&self, other: &Multivector) -> Multivector {
        let mut c = [0.0; 8];
        for i in 0..8 {
            c[i] = self.components[i] + other.components[i];
        }
        Multivector { components: c }
    }

    /// Scale by f64.
    pub fn scale(&self, k: f64) -> Multivector {
        let mut c = self.components;
        for ci in c.iter_mut() {
            *ci *= k;
        }
        Multivector { components: c }
    }
}

impl fmt::Display for Multivector {
    /// Human-readable form: components grouped by grade, joined with
    /// ` + ` (or ` - ` for negative coefficients). Zero components
    /// are omitted. Zero multivector prints as `0`.
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        const LABELS: [&str; 8] = [
            "", "e_1", "e_2", "e_3", "e_12", "e_13", "e_23", "e_123",
        ];
        let mut first = true;
        for (i, &c) in self.components.iter().enumerate() {
            if c == 0.0 {
                continue;
            }
            let (sign, abs) = if c < 0.0 { ("-", -c) } else { ("+", c) };
            if first {
                if c < 0.0 {
                    write!(f, "-")?;
                }
                first = false;
            } else {
                write!(f, " {} ", sign)?;
            }
            if i == 0 {
                // Scalar component prints just the magnitude.
                write!(f, "{}", abs)?;
            } else if abs == 1.0 {
                write!(f, "{}", LABELS[i])?;
            } else {
                write!(f, "{} {}", abs, LABELS[i])?;
            }
        }
        if first {
            // All components were zero.
            write!(f, "0")?;
        }
        Ok(())
    }
}

/// Geometry-IR expression tree.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub enum GeoExpr {
    Literal(Multivector),
    GeoProduct(Box<GeoExpr>, Box<GeoExpr>),
    Reverse(Box<GeoExpr>),
}

#[derive(Clone, Debug, PartialEq)]
pub enum GeoExprError {
    NonFiniteComponent { index: usize, value: f64 },
}

impl GeoExpr {
    pub fn literal(m: Multivector) -> Self {
        GeoExpr::Literal(m)
    }
    pub fn product(a: GeoExpr, b: GeoExpr) -> Self {
        GeoExpr::GeoProduct(Box::new(a), Box::new(b))
    }
    pub fn reverse(a: GeoExpr) -> Self {
        GeoExpr::Reverse(Box::new(a))
    }

    /// Tree depth: literals are depth 0.
    pub fn depth(&self) -> usize {
        match self {
            GeoExpr::Literal(_) => 0,
            GeoExpr::Reverse(a) => 1 + a.depth(),
            GeoExpr::GeoProduct(a, b) => 1 + a.depth().max(b.depth()),
        }
    }

    /// Number of nodes.
    pub fn size(&self) -> usize {
        match self {
            GeoExpr::Literal(_) => 1,
            GeoExpr::Reverse(a) => 1 + a.size(),
            GeoExpr::GeoProduct(a, b) => 1 + a.size() + b.size(),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn zero_multivector_all_zeros() {
        assert!(Multivector::zero().is_scalar());
        assert_eq!(Multivector::zero().scalar_part(), 0.0);
    }

    #[test]
    fn scalar_constructor_sets_only_index_zero() {
        let s = Multivector::scalar(7.5);
        assert_eq!(s.scalar_part(), 7.5);
        assert!(s.is_scalar());
    }

    #[test]
    fn vector_constructor_sets_only_indices_1_2_3() {
        let v = Multivector::vector(1.0, 2.0, 3.0);
        assert_eq!(v.vector_part(), (1.0, 2.0, 3.0));
        assert!(v.is_vector());
        assert!(!v.is_scalar());
    }

    #[test]
    fn bivector_constructor_sets_only_indices_4_5_6() {
        let b = Multivector::bivector(0.1, 0.2, 0.3);
        assert_eq!(b.bivector_part(), (0.1, 0.2, 0.3));
        assert!(b.is_rotor_candidate());
        assert!(!b.is_vector());
    }

    #[test]
    fn pseudoscalar_constructor_sets_only_index_7() {
        let p = Multivector::pseudoscalar(1.0);
        assert_eq!(p.pseudoscalar_part(), 1.0);
        assert!(!p.is_scalar());
        assert!(!p.is_vector());
        assert!(!p.is_rotor_candidate());
    }

    // ── iter-155: from_quaternion (inverse of rotor_to_quaternion) ──

    #[test]
    fn from_quaternion_identity_is_scalar_one() {
        let r = Multivector::from_quaternion(1.0, 0.0, 0.0, 0.0);
        assert_eq!(r.scalar_part(), 1.0);
        assert_eq!(r.bivector_part(), (0.0, 0.0, 0.0));
    }

    #[test]
    fn from_quaternion_roundtrips_with_rotor_to_quaternion() {
        // Build rotor → quaternion → rotor, check identity.
        let r = Multivector::scalar(0.6)
            .add(&Multivector::bivector(0.3, 0.5, 0.4));
        let q = r.rotor_to_quaternion().unwrap();
        let r2 = Multivector::from_quaternion(q.0, q.1, q.2, q.3);
        for (a, b) in r.components.iter().zip(r2.components.iter()) {
            assert!((a - b).abs() < 1e-12);
        }
    }

    #[test]
    fn from_quaternion_then_to_quaternion_is_identity() {
        // Round-trip the other direction.
        let q = (0.5_f64, 0.5, 0.5, 0.5);
        let r = Multivector::from_quaternion(q.0, q.1, q.2, q.3);
        let q2 = r.rotor_to_quaternion().unwrap();
        assert!((q.0 - q2.0).abs() < 1e-12);
        assert!((q.1 - q2.1).abs() < 1e-12);
        assert!((q.2 - q2.2).abs() < 1e-12);
        assert!((q.3 - q2.3).abs() < 1e-12);
    }

    // ── iter-149: rotor_to_quaternion ─────────────────────────────

    #[test]
    fn rotor_to_quaternion_identity_is_one_zero_zero_zero() {
        let r = Multivector::scalar(1.0);
        let q = r.rotor_to_quaternion().unwrap();
        assert_eq!(q, (1.0, 0.0, 0.0, 0.0));
    }

    #[test]
    fn rotor_to_quaternion_xy_bivector_rotor() {
        // R = cos(θ/2) + sin(θ/2) e_12. q = (cos, 0, 0, -sin).
        let r = Multivector::scalar(0.5)
            .add(&Multivector::bivector(0.866, 0.0, 0.0));
        let q = r.rotor_to_quaternion().unwrap();
        assert!((q.0 - 0.5).abs() < 1e-12);
        assert!((q.1 - 0.0).abs() < 1e-12);
        assert!((q.2 - 0.0).abs() < 1e-12);
        assert!((q.3 + 0.866).abs() < 1e-12);
    }

    #[test]
    fn rotor_to_quaternion_with_vector_part_returns_none() {
        let m = Multivector::scalar(1.0).add(&Multivector::vector(1.0, 0.0, 0.0));
        assert!(m.rotor_to_quaternion().is_none());
    }

    #[test]
    fn rotor_to_quaternion_unit_norm_preserved() {
        // ||q||² = w² + x² + y² + z² should match rotor's norm_squared.
        let r = Multivector::scalar(0.5)
            .add(&Multivector::bivector(0.5, 0.5, 0.5));
        let (w, x, y, z) = r.rotor_to_quaternion().unwrap();
        let q_norm_sq = w * w + x * x + y * y + z * z;
        assert!((q_norm_sq - r.norm_squared()).abs() < 1e-12);
    }

    // ── iter-143: distance_to + squared_distance_to ───────────────

    #[test]
    fn distance_to_zero_is_zero() {
        let v = Multivector::vector(1.0, 2.0, 3.0);
        assert_eq!(v.distance_to(&v), 0.0);
    }

    #[test]
    fn distance_to_unit_vectors() {
        let e1 = Multivector::e1();
        let e2 = Multivector::e2();
        // (1, 0, 0) - (0, 1, 0) = (1, -1, 0); norm = √2.
        let d = e1.distance_to(&e2);
        assert!((d - 2.0_f64.sqrt()).abs() < 1e-12);
    }

    #[test]
    fn squared_distance_avoids_sqrt() {
        let e1 = Multivector::e1();
        let e2 = Multivector::e2();
        // norm² = 2.
        assert_eq!(e1.squared_distance_to(&e2), 2.0);
    }

    #[test]
    fn distance_symmetric() {
        let a = Multivector::vector(1.0, 2.0, 3.0);
        let b = Multivector::vector(-1.0, 0.5, 2.0);
        let ab = a.distance_to(&b);
        let ba = b.distance_to(&a);
        assert!((ab - ba).abs() < 1e-12);
    }

    // ── iter-137: basis constructors ──────────────────────────────

    #[test]
    fn basis_constructors_correct_components() {
        assert_eq!(Multivector::e1().vector_part(), (1.0, 0.0, 0.0));
        assert_eq!(Multivector::e2().vector_part(), (0.0, 1.0, 0.0));
        assert_eq!(Multivector::e3().vector_part(), (0.0, 0.0, 1.0));
        assert_eq!(Multivector::e12().bivector_part(), (1.0, 0.0, 0.0));
        assert_eq!(Multivector::e13().bivector_part(), (0.0, 1.0, 0.0));
        assert_eq!(Multivector::e23().bivector_part(), (0.0, 0.0, 1.0));
        assert_eq!(Multivector::pseudoscalar_unit().pseudoscalar_part(), 1.0);
    }

    #[test]
    fn basis_vectors_are_pure_grade_1() {
        assert!(Multivector::e1().is_pure_grade(1));
        assert!(Multivector::e2().is_pure_grade(1));
        assert!(Multivector::e3().is_pure_grade(1));
    }

    #[test]
    fn basis_bivectors_are_pure_grade_2() {
        assert!(Multivector::e12().is_pure_grade(2));
        assert!(Multivector::e13().is_pure_grade(2));
        assert!(Multivector::e23().is_pure_grade(2));
    }

    #[test]
    fn pseudoscalar_unit_is_pure_grade_3() {
        assert!(Multivector::pseudoscalar_unit().is_pure_grade(3));
    }

    #[test]
    fn basis_vectors_are_unit_norm() {
        for v in [Multivector::e1(), Multivector::e2(), Multivector::e3()] {
            assert!((v.norm() - 1.0).abs() < 1e-12);
        }
    }

    #[test]
    fn grade_norm_squared_per_grade() {
        let v = Multivector::vector(3.0, 4.0, 0.0);
        assert_eq!(v.grade_norm_squared(1), 25.0);
        assert_eq!(v.grade_norm_squared(0), 0.0);
        assert_eq!(v.grade_norm_squared(2), 0.0);
        // Iter-85: norm / norm_squared / sub / is_approximately_unit_rotor.
        assert_eq!(v.norm_squared(), 25.0);
        assert_eq!(v.norm(), 5.0);
    }

    #[test]
    fn norm_sub_unit_rotor_helpers_iter_85() {
        // Sub: (3,4,0) - (1,0,0) = (2,4,0); norm² = 20.
        let a = Multivector::vector(3.0, 4.0, 0.0);
        let b = Multivector::vector(1.0, 0.0, 0.0);
        let d = a.sub(&b);
        assert_eq!(d.vector_part(), (2.0, 4.0, 0.0));
        assert!((d.norm_squared() - 20.0).abs() < 1e-12);

        // Unit rotor: scalar=1, no other components.
        let identity = Multivector::scalar(1.0);
        assert!(identity.is_approximately_unit_rotor(1e-12));

        // Half rotor: scalar = 1/√2, bivector e_12 = 1/√2 → norm² = 1.
        let half = Multivector::scalar(1.0 / 2.0_f64.sqrt())
            .add(&Multivector::bivector(1.0 / 2.0_f64.sqrt(), 0.0, 0.0));
        assert!(half.is_approximately_unit_rotor(1e-12));

        // Not a rotor: any vector part.
        let bad = Multivector::vector(0.5, 0.5, 0.5);
        assert!(!bad.is_approximately_unit_rotor(1e-9));
    }

    #[test]
    fn reverse_grade_0_and_1_unchanged() {
        let s = Multivector::scalar(2.5);
        let v = Multivector::vector(1.0, -1.0, 2.0);
        assert_eq!(s.reverse(), s);
        assert_eq!(v.reverse(), v);
    }

    #[test]
    fn reverse_grade_2_and_3_negated() {
        let b = Multivector::bivector(1.0, 2.0, 3.0);
        assert_eq!(b.reverse(), Multivector::bivector(-1.0, -2.0, -3.0));
        let p = Multivector::pseudoscalar(5.0);
        assert_eq!(p.reverse(), Multivector::pseudoscalar(-5.0));
    }

    #[test]
    fn reverse_is_involutive() {
        let mv = Multivector {
            components: [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0],
        };
        assert_eq!(mv.reverse().reverse(), mv);
    }

    #[test]
    fn add_is_componentwise() {
        let a = Multivector::vector(1.0, 2.0, 3.0);
        let b = Multivector::vector(10.0, 20.0, 30.0);
        let c = a.add(&b);
        assert_eq!(c.vector_part(), (11.0, 22.0, 33.0));
    }

    #[test]
    fn scale_multiplies_every_component() {
        let v = Multivector::vector(1.0, 2.0, 3.0);
        let s = v.scale(2.0);
        assert_eq!(s.vector_part(), (2.0, 4.0, 6.0));
    }

    #[test]
    fn geo_expr_literal_has_depth_zero() {
        let e = GeoExpr::literal(Multivector::scalar(1.0));
        assert_eq!(e.depth(), 0);
        assert_eq!(e.size(), 1);
    }

    #[test]
    fn geo_expr_product_depth() {
        let a = GeoExpr::literal(Multivector::scalar(1.0));
        let b = GeoExpr::literal(Multivector::scalar(2.0));
        let p = GeoExpr::product(a, b);
        assert_eq!(p.depth(), 1);
        assert_eq!(p.size(), 3);
    }

    #[test]
    fn geo_expr_reverse_depth() {
        let inner = GeoExpr::literal(Multivector::bivector(1.0, 0.0, 0.0));
        let outer = GeoExpr::reverse(inner);
        assert_eq!(outer.depth(), 1);
        assert_eq!(outer.size(), 2);
    }

    #[test]
    fn round_trips_through_serde_json() {
        let e = GeoExpr::product(
            GeoExpr::literal(Multivector::vector(1.0, 2.0, 3.0)),
            GeoExpr::reverse(GeoExpr::literal(Multivector::bivector(0.5, 0.0, 0.0))),
        );
        let json = serde_json::to_string(&e).unwrap();
        let back: GeoExpr = serde_json::from_str(&json).unwrap();
        assert_eq!(e, back);
    }

    #[test]
    fn rotor_candidate_rejects_vector_part() {
        let mv = Multivector::vector(1.0, 0.0, 0.0);
        assert!(!mv.is_rotor_candidate());
    }

    // ── Multivector Display impl (iter-52) ────────────────────────

    #[test]
    fn display_zero_multivector_is_zero() {
        assert_eq!(format!("{}", Multivector::zero()), "0");
    }

    #[test]
    fn display_scalar_prints_magnitude() {
        assert_eq!(format!("{}", Multivector::scalar(3.5)), "3.5");
    }

    #[test]
    fn display_vector_uses_labels() {
        let v = Multivector::vector(2.0, 0.0, 5.0);
        // 2 e_1 + 5 e_3 (since e_2 = 0 is omitted)
        assert_eq!(format!("{}", v), "2 e_1 + 5 e_3");
    }

    #[test]
    fn display_unit_coefficient_omits_one() {
        let v = Multivector::vector(1.0, 0.0, 0.0);
        assert_eq!(format!("{}", v), "e_1");
    }

    #[test]
    fn display_negative_coefficient_uses_minus() {
        let v = Multivector::vector(-2.0, 0.0, 0.0);
        assert_eq!(format!("{}", v), "-2 e_1");
    }

    #[test]
    fn display_mixed_grade() {
        let mut mv = Multivector::scalar(1.5);
        mv = mv.add(&Multivector::vector(2.0, 0.0, 0.0));
        mv = mv.add(&Multivector::bivector(3.0, 0.0, 0.0));
        assert_eq!(format!("{}", mv), "1.5 + 2 e_1 + 3 e_12");
    }

    #[test]
    fn display_negative_unit_coefficient_omits_one() {
        // Negative unit coefficient still triggers the "omit 1"
        // branch, like a positive unit coefficient does — only
        // the sign appears.
        let mut mv = Multivector::scalar(1.0);
        mv = mv.add(&Multivector::vector(-1.0, 0.0, 0.0));
        assert_eq!(format!("{}", mv), "1 - e_1");
    }

    #[test]
    fn display_negative_non_unit_middle_term() {
        let mut mv = Multivector::scalar(1.0);
        mv = mv.add(&Multivector::vector(-3.0, 0.0, 0.0));
        assert_eq!(format!("{}", mv), "1 - 3 e_1");
    }

    #[test]
    fn display_pseudoscalar() {
        let p = Multivector::pseudoscalar(2.0);
        assert_eq!(format!("{}", p), "2 e_123");
    }
}
