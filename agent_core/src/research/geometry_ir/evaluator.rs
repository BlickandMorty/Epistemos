//! Source:
//! - Hestenes-Sobczyk (Reidel 1984) Ch. 1 — geometric-product axioms.
//! - Dorst-Fontijne-Mann (Morgan Kaufmann 2007) §10.3 — algorithmic
//!   form of the geometric product via the basis-blade XOR rule +
//!   anticommutation sign count.
//! - Doctrine §4.6 — Geometry-IR first lowering target.
//! - Companion: [`super::grammar`] (the GeoExpr we evaluate).
//!
//! # Cl(3,0) geometric product
//!
//! Basis-blade representation:
//!
//! | Index | Bitmask | Blade   |
//! |-------|---------|---------|
//! | 0     | 0b000   | 1       |
//! | 1     | 0b001   | e_1     |
//! | 2     | 0b010   | e_2     |
//! | 3     | 0b100   | e_3     |
//! | 4     | 0b011   | e_12    |
//! | 5     | 0b101   | e_13    |
//! | 6     | 0b110   | e_23    |
//! | 7     | 0b111   | e_123   |
//!
//! Two basis blades A (bitmask `a`) and B (bitmask `b`) multiply
//! to a single basis blade with:
//!
//! - **Result bitmask** = `a XOR b` (shared indices cancel because
//!   `e_i² = +1` in Cl(3,0)).
//! - **Sign** = `(-1)^k` where `k` is the number of swaps needed
//!   to bring B's e_i factors past A's higher-index e_j factors.
//!   Concretely: for each bit `i` set in `b`, count bits in `a` at
//!   positions `> i`; sum modulo 2.

use super::grammar::{GeoExpr, Multivector};

/// Index → 3-bit bitmask mapping used by the blade-product algorithm.
const INDEX_TO_BITMASK: [u8; 8] = [
    0b000, // scalar
    0b001, // e_1
    0b010, // e_2
    0b100, // e_3
    0b011, // e_12
    0b101, // e_13
    0b110, // e_23
    0b111, // e_123
];

/// Reverse mapping: bitmask (0..8) → grade-blocked index.
const BITMASK_TO_INDEX: [usize; 8] = [
    0, // 0b000 → scalar
    1, // 0b001 → e_1
    2, // 0b010 → e_2
    4, // 0b011 → e_12
    3, // 0b100 → e_3
    5, // 0b101 → e_13
    6, // 0b110 → e_23
    7, // 0b111 → e_123
];

/// Compute `(result_index, sign)` for the geometric product of two
/// basis blades indexed by [`INDEX_TO_BITMASK`].
fn blade_product(a_idx: usize, b_idx: usize) -> (usize, f64) {
    let a_bits = INDEX_TO_BITMASK[a_idx];
    let b_bits = INDEX_TO_BITMASK[b_idx];
    let result_bits = a_bits ^ b_bits;
    let mut swap_count: u32 = 0;
    for i in 0..3 {
        if (b_bits & (1 << i)) != 0 {
            swap_count += (a_bits >> (i + 1)).count_ones();
        }
    }
    let sign = if swap_count % 2 == 0 { 1.0 } else { -1.0 };
    (BITMASK_TO_INDEX[result_bits as usize], sign)
}

/// Compute the Cl(3,0) geometric product of two multivectors.
pub fn geo_product(a: &Multivector, b: &Multivector) -> Multivector {
    let mut out = [0.0_f64; 8];
    for i in 0..8 {
        if a.components[i] == 0.0 {
            continue;
        }
        for j in 0..8 {
            if b.components[j] == 0.0 {
                continue;
            }
            let (k, sign) = blade_product(i, j);
            out[k] += sign * a.components[i] * b.components[j];
        }
    }
    Multivector { components: out }
}

/// Symmetric / inner part of the geometric product:
/// `a · b = (a b + b a) / 2`.
///
/// For two vectors `u`, `v` this reduces to the Euclidean scalar
/// dot product `(u · v) = u_x v_x + u_y v_y + u_z v_z` lifted into
/// the scalar grade. For mixed grades the symmetric part may
/// span multiple grades.
///
/// Iter-85 — Clifford-algebra primitive completing the
/// (dot / wedge) decomposition of [`geo_product`].
pub fn geo_dot(a: &Multivector, b: &Multivector) -> Multivector {
    let ab = geo_product(a, b);
    let ba = geo_product(b, a);
    ab.add(&ba).scale(0.5)
}

/// Antisymmetric / outer (wedge) part of the geometric product:
/// `a ∧ b = (a b − b a) / 2`.
///
/// For two vectors this yields the bivector representing the
/// oriented parallelogram they span.
///
/// Iter-85 — companion to [`geo_dot`]. Together they satisfy
/// `a b = a · b + a ∧ b`.
pub fn geo_wedge(a: &Multivector, b: &Multivector) -> Multivector {
    let ab = geo_product(a, b);
    let ba = geo_product(b, a);
    ab.sub(&ba).scale(0.5)
}

/// Angle between two non-zero vectors `u, v`, returned in `[0, π]`.
///
/// `θ = arccos(u · v / (|u| · |v|))`.
///
/// Returns 0 if either vector is zero (degenerate case; caller
/// should guard against this).
///
/// Iter-123 — composes geo_dot + vector_part().
pub fn angle_between_vectors(u: &Multivector, v: &Multivector) -> f64 {
    let nu = u.grade_norm_squared(1).sqrt();
    let nv = v.grade_norm_squared(1).sqrt();
    if nu == 0.0 || nv == 0.0 {
        return 0.0;
    }
    let dot = geo_dot(u, v).scalar_part();
    let ratio = (dot / (nu * nv)).clamp(-1.0, 1.0);
    ratio.acos()
}

/// Scalar triple product `u · (v × w)` — the signed volume of the
/// parallelepiped spanned by `u, v, w`.
///
/// Iter-123 — classical 3D primitive useful for orientation checks
/// (positive = right-handed coordinate frame).
pub fn scalar_triple_product(u: &Multivector, v: &Multivector, w: &Multivector) -> f64 {
    let cross_vw = vector_cross_product(v, w);
    geo_dot(u, &cross_vw).scalar_part()
}

/// Project a vector `v` onto the plane spanned by a unit bivector
/// `B`: `proj_B(v) = (v ∧ B) · B^{-1}`.
///
/// For a unit bivector with `B² = -1` in Cl(3, 0), `B^{-1} = -B`,
/// so `proj_B(v) = -(v ∧ B) · B`. The wedge captures the
/// antisymmetric part of `vB` (the component of v inside the
/// plane); multiplying by `B^{-1}` rotates back into vector grade.
///
/// Iter-162 — geometric primitive for projection onto a 2D plane
/// embedded in 3D.
pub fn project_onto_bivector_plane(v: &Multivector, b: &Multivector) -> Multivector {
    let wedge = geo_wedge(v, b);
    // For unit B with B² = -1, B^{-1} = -B.
    geo_product(&wedge, b).scale(-1.0)
}

/// Reject a vector from a bivector plane (complementary to
/// [`project_onto_bivector_plane`]): `v − proj_B(v)`.
///
/// The result is the component of `v` perpendicular to the plane
/// of `B`.
///
/// Iter-162.
pub fn reject_from_bivector_plane(v: &Multivector, b: &Multivector) -> Multivector {
    let proj = project_onto_bivector_plane(v, b);
    v.sub(&proj)
}

/// Project vector `v` onto vector `n`:
/// `proj_n(v) = ((v · n) / (n · n)) · n`.
///
/// Returns the zero vector if `n` is zero (degenerate).
///
/// Iter-130 — standard vector decomposition primitive.
pub fn vector_projection(v: &Multivector, n: &Multivector) -> Multivector {
    let nn = geo_dot(n, n).scalar_part();
    if nn == 0.0 {
        return Multivector::zero();
    }
    let vn = geo_dot(v, n).scalar_part();
    n.scale(vn / nn)
}

/// Reject `v` from `n` (component of `v` perpendicular to `n`):
/// `rej_n(v) = v − proj_n(v)`.
///
/// Iter-130 — companion to [`vector_projection`]. Together they
/// decompose `v = proj_n(v) + rej_n(v)`.
pub fn vector_rejection(v: &Multivector, n: &Multivector) -> Multivector {
    let proj = vector_projection(v, n);
    v.sub(&proj)
}

/// Hodge dual of a multivector via the pseudoscalar:
/// `dual(M) = M · I^{-1}` where `I = e_{123}` is the unit
/// pseudoscalar.
///
/// In Cl(3, 0), `I² = -1` so `I^{-1} = -I`. The dual maps grades:
/// - scalar (grade 0) ↔ pseudoscalar (grade 3)
/// - vector (grade 1) ↔ bivector (grade 2)
///
/// Iter-174 — Clifford-algebra dual operation; useful for
/// converting between vector and bivector representations of
/// the same geometric object.
pub fn multivector_dual(m: &Multivector) -> Multivector {
    let i_inv = Multivector::pseudoscalar(-1.0); // I^{-1} = -I.
    geo_product(m, &i_inv)
}

/// Grade-k L² norm of a multivector: free-function form of
/// [`Multivector::grade_norm`].
///
/// Returns 0 for grades outside `0..=3` (the range valid in Cl(3, 0)).
///
/// Iter-210 — companion to [`Multivector::norm`] (total norm) and
/// [`Multivector::grade_projection`]; useful for asserting that a
/// multivector "is approximately grade k" by checking that
/// `grade_norm(_, k) > tol` and `grade_norm(_, other) < tol`.
pub fn multivector_grade_norm(m: &Multivector, grade: usize) -> f64 {
    m.grade_norm(grade)
}

/// Normalize a multivector to unit L² norm, or return the zero
/// multivector if the input has zero norm.
///
/// Total-fallback companion to [`Multivector::normalize`] (which
/// returns `Option`). Useful at call sites where a "best
/// available unit direction" is needed but no error path can be
/// surfaced (e.g., in pipeline chains where None would need to
/// propagate).
///
/// Iter-252 — ergonomic wrapper; in numerical code that needs to
/// know the input was degenerate, prefer `Multivector::normalize`.
pub fn multivector_normalize_or_zero(m: &Multivector) -> Multivector {
    m.normalize().unwrap_or_else(Multivector::zero)
}

/// L¹ (sum-of-absolute-values) norm of a multivector.
///
/// Returns `Σᵢ |cᵢ|` over the 8 Cl(3, 0) components. This is the
/// taxicab / Manhattan norm in component space and provides an
/// upper bound on the L² norm (with equality iff at most one
/// component is non-zero). Useful for sparsity-promoting
/// regularization, ℓ¹-trust-region bounds, and diagnostic
/// component-budget assertions.
///
/// Iter-318 — companion to [`Multivector::norm`] (L²) and
/// [`multivector_linf_norm`] (L∞). The (L¹, L², L∞) triple
/// closes the standard ℓ_p-norm family on 8-component vectors.
///
/// Source. Standard ℓ_p-norm definition for `p = 1`.
pub fn multivector_l1_norm(m: &Multivector) -> f64 {
    m.components.iter().map(|x| x.abs()).sum()
}

/// L∞ (max-absolute-component) norm of a multivector.
///
/// Returns `maxᵢ |cᵢ|` over the 8 Cl(3, 0) components. This is
/// the Chebyshev / sup-norm in component space and provides a
/// lower bound on the L² norm scaled by `1/sqrt(8)`. Useful for
/// detecting whether a multivector has *any* component above a
/// numerical tolerance — the standard zero-test predicate when
/// L² noise floors are inconvenient.
///
/// Iter-318 — companion to [`multivector_l1_norm`] (L¹) and
/// [`Multivector::norm`] (L²).
///
/// Source. Standard ℓ_p-norm definition for `p = ∞`.
pub fn multivector_linf_norm(m: &Multivector) -> f64 {
    m.components
        .iter()
        .map(|x| x.abs())
        .fold(0.0_f64, f64::max)
}

/// Approximate-pure-grade predicate: returns `true` iff `m`'s
/// components in every grade other than `grade` are below
/// `tolerance` in absolute value.
///
/// Unlike `Multivector::is_pure_grade` (iter-?), this version
/// tolerates numerical drift — useful after a sequence of
/// geometric-product operations that should preserve grade
/// structure but accumulate ε-scale noise in off-grade slots.
///
/// `grade > 3` returns `false`.
///
/// Iter-306 — fault-tolerant grade-purity check.
pub fn multivector_is_approximately_pure_grade(
    m: &Multivector,
    grade: usize,
    tolerance: f64,
) -> bool {
    let target_indices: &[usize] = match grade {
        0 => &[0],
        1 => &[1, 2, 3],
        2 => &[4, 5, 6],
        3 => &[7],
        _ => return false,
    };
    for i in 0..8 {
        if !target_indices.contains(&i) && m.components[i].abs() > tolerance {
            return false;
        }
    }
    true
}

/// Grade filter: keep components in `grades_to_keep` (a bitmask
/// over grades 0..=3), zero out the rest.
///
/// `grades_to_keep & (1 << k)` non-zero ⇒ grade-`k` components
/// are preserved. Bits for grade > 3 are ignored.
///
/// Examples:
/// - `0b0001` (1) keeps only scalar.
/// - `0b0101` (5) keeps scalar + bivector (= even part).
/// - `0b1010` (10) keeps vector + pseudoscalar (= odd part).
/// - `0b1111` (15) is the identity.
///
/// Iter-312 — generalized grade projection. Subsumes
/// `multivector_even_part` (mask = 5) and `multivector_odd_part`
/// (mask = 10) and any custom-grade-subset filter.
pub fn multivector_grade_filter(m: &Multivector, grades_to_keep: u8) -> Multivector {
    let keep_grade = |g: usize| (grades_to_keep & (1u8 << g)) != 0;
    let mut comp = [0.0_f64; 8];
    if keep_grade(0) {
        comp[0] = m.components[0];
    }
    if keep_grade(1) {
        comp[1] = m.components[1];
        comp[2] = m.components[2];
        comp[3] = m.components[3];
    }
    if keep_grade(2) {
        comp[4] = m.components[4];
        comp[5] = m.components[5];
        comp[6] = m.components[6];
    }
    if keep_grade(3) {
        comp[7] = m.components[7];
    }
    Multivector { components: comp }
}

/// Even-grade projection: keep grades 0 and 2, zero out grades
/// 1 and 3.
///
/// For `m = α + v + B + I·β` in Cl(3, 0):
///   even_part(m) = α + B.
///
/// The +1 eigenspace of the grade involution (iter-270). The
/// even subalgebra is closed under the geometric product and
/// equals the rotor algebra Cl⁺(3, 0) ≅ ℍ (the quaternions).
///
/// Iter-300 — milestone. Even/odd projection primitive for spin-
/// geometry workflows.
pub fn multivector_even_part(m: &Multivector) -> Multivector {
    let mut comp = [0.0_f64; 8];
    comp[0] = m.components[0];
    comp[4] = m.components[4];
    comp[5] = m.components[5];
    comp[6] = m.components[6];
    Multivector { components: comp }
}

/// Odd-grade projection: keep grades 1 and 3, zero out grades 0
/// and 2.
///
/// For `m = α + v + B + I·β` in Cl(3, 0):
///   odd_part(m) = v + I·β.
///
/// The −1 eigenspace of the grade involution.
///
/// Iter-300 — odd companion to `multivector_even_part`. The odd
/// part is NOT closed under the geometric product (product of
/// two odd elements is even).
pub fn multivector_odd_part(m: &Multivector) -> Multivector {
    let mut comp = [0.0_f64; 8];
    comp[1] = m.components[1];
    comp[2] = m.components[2];
    comp[3] = m.components[3];
    comp[7] = m.components[7];
    Multivector { components: comp }
}

/// Grade involution `m̂`: negate grades 1 and 3 (odd grades), keep
/// grades 0 and 2 (even grades).
///
/// For `m = α + v + B + I·β` in Cl(3, 0):
///   `m̂ = α − v + B − I·β`.
///
/// Together with `reverse` (negates grades 2, 3) and the Clifford
/// conjugate `bar` (negates grades 1, 2) — the three grade-flip
/// involutions form a Z₂ × Z₂ group with `bar = reverse ∘ grade_
/// involution`.
///
/// The grade involution is the natural automorphism that
/// distinguishes the even subalgebra (eigenspace +1, the rotor
/// algebra) from the odd part (eigenspace −1, the vector +
/// pseudoscalar fragment).
///
/// Iter-270 — completes the grade-flip trio
/// (reverse, conjugate, involution) on Cl(3, 0).
pub fn multivector_grade_involution(m: &Multivector) -> Multivector {
    let mut comp = m.components;
    // Grade 0 (index 0) → keep.
    // Grade 1 (indices 1, 2, 3) → negate.
    comp[1] = -comp[1];
    comp[2] = -comp[2];
    comp[3] = -comp[3];
    // Grade 2 (indices 4, 5, 6) → keep.
    // Grade 3 (index 7) → negate.
    comp[7] = -comp[7];
    Multivector { components: comp }
}

/// Clifford conjugation `bar(m)`: negate grade-1 and grade-2 parts,
/// keep grade-0 and grade-3 parts.
///
/// For `m = α + v + B + I·β` in Cl(3, 0): `bar(m) = α − v − B + I·β`.
///
/// Compose of [`Multivector::reverse`] (which negates grades 2, 3)
/// and grade-involution (negate grade-1, grade-3). The Clifford
/// conjugate satisfies `bar(ab) = bar(b)·bar(a)` (anti-automorphism)
/// and is the natural conjugation for the Cl(p, q) inner product
/// `⟨a, b⟩ = scalar_part(bar(a) · b)`.
///
/// Iter-264 — completes the trio of grade-flip involutions:
/// reverse (rotor-friendly), conjugate (this iter), grade-involution
/// (Multivector negation by even/odd grade — derivable from these).
pub fn multivector_clifford_conjugate(m: &Multivector) -> Multivector {
    let mut comp = m.components;
    // Grade 0 (index 0) → keep.
    // Grade 1 (indices 1, 2, 3) → negate.
    comp[1] = -comp[1];
    comp[2] = -comp[2];
    comp[3] = -comp[3];
    // Grade 2 (indices 4, 5, 6) → negate.
    comp[4] = -comp[4];
    comp[5] = -comp[5];
    comp[6] = -comp[6];
    // Grade 3 (index 7) → keep.
    Multivector { components: comp }
}

/// Multivector squared L² distance: `||a − b||²`.
///
/// Sqrt-free companion to [`multivector_distance`]. Useful when
/// only the ordering matters (k-nearest-neighbour ranking,
/// gradient-descent loss terms) — avoids the cost and the
/// non-smoothness of the sqrt at zero.
///
/// Iter-276 — gradient-friendly companion to
/// [`multivector_distance`] (iter-246) and
/// [`multivector_cosine_similarity`] (iter-234).
pub fn multivector_distance_squared(a: &Multivector, b: &Multivector) -> f64 {
    a.sub(b).norm_squared()
}

/// L¹ (Manhattan / taxicab) distance between vector parts:
/// `Σᵢ |uᵢ − vᵢ|` over the grade-1 components.
///
/// Considers only the vector part — bivector and higher-grade
/// components of the inputs are ignored. For pure vectors this
/// matches the classical L¹ distance.
///
/// Iter-282 — companion to `multivector_distance` (L²); used as
/// a robust outlier-resistant distance in clustering and as the
/// taxicab metric in lattice / grid problems.
pub fn vector_distance_l1(u: &Multivector, v: &Multivector) -> f64 {
    let (ux, uy, uz) = u.vector_part();
    let (vx, vy, vz) = v.vector_part();
    (ux - vx).abs() + (uy - vy).abs() + (uz - vz).abs()
}

/// Multivector L² distance: `dist(a, b) = ||a − b||`.
///
/// Computed as the Euclidean norm of the componentwise
/// difference. Always non-negative; zero iff `a == b`.
///
/// Iter-246 — companion to `multivector_cosine_similarity`
/// (iter-234, normalized inner product) and
/// `multivector_lerp` (iter-240, flat-space interpolation). On
/// pure-grade-1 inputs this reduces to the standard Euclidean
/// vector distance.
pub fn multivector_distance(a: &Multivector, b: &Multivector) -> f64 {
    a.sub(b).norm()
}

/// Normalized linear interpolation (NLERP):
/// `nlerp(a, b, t) = normalize((1−t)·a + t·b)`.
///
/// LERP followed by renormalization. Cheaper than `rotor_slerp`
/// (no log/exp/power) and a good SLERP approximation for small
/// angle differences. For unit-rotor inputs the result is also
/// approximately unit (exact at `t ∈ {0, 1}` and at antipodal-
/// symmetry points).
///
/// Returns zero multivector if `lerp(a, b, t)` is the zero
/// multivector — caller's responsibility to check `t` and
/// magnitudes.
///
/// Iter-258 — companion to `multivector_lerp` (iter-240) and
/// `rotor_slerp` (iter-204); the speed/accuracy compromise in
/// the rotor-interpolation family.
pub fn vector_lerp_normalized(a: &Multivector, b: &Multivector, t: f64) -> Multivector {
    multivector_normalize_or_zero(&multivector_lerp(a, b, t))
}

/// Componentwise minimum of two multivectors.
///
/// `min(a, b)_i = min(a_i, b_i)` for every component index `i`
/// (across all 8 components of the Cl(3, 0) basis).
///
/// Iter-294 — lower-envelope companion to
/// `multivector_componentwise_max` (iter-288); together they
/// form the bounding-box pair on the 8-D Cl(3, 0) component
/// space.
pub fn multivector_componentwise_min(a: &Multivector, b: &Multivector) -> Multivector {
    let mut comp = [0.0_f64; 8];
    for i in 0..8 {
        let x = a.components[i];
        let y = b.components[i];
        comp[i] = if x <= y { x } else { y };
    }
    Multivector { components: comp }
}

/// Componentwise maximum of two multivectors.
///
/// `max(a, b)_i = max(a_i, b_i)` for every component index `i`
/// (across all 8 components of the Cl(3, 0) basis).
///
/// Iter-288 — bounding-multivector / envelope construction.
/// Useful when constructing a tight upper-envelope across a set
/// of multivectors (e.g., for interval-arithmetic bounds on
/// rotor accumulators).
pub fn multivector_componentwise_max(a: &Multivector, b: &Multivector) -> Multivector {
    let mut comp = [0.0_f64; 8];
    for i in 0..8 {
        let x = a.components[i];
        let y = b.components[i];
        comp[i] = if x >= y { x } else { y };
    }
    Multivector { components: comp }
}

/// Componentwise linear interpolation:
/// `lerp(a, b, t) = (1 − t) · a + t · b`.
///
/// At `t = 0` returns `a`; at `t = 1` returns `b`; at `t = 0.5`
/// returns the componentwise mean. Distinct from
/// `rotor_slerp` (iter-204) which interpolates on the Spin(3)
/// manifold — this is the flat-space LERP that does NOT
/// preserve unit-rotor normalization.
///
/// Iter-240 — flat-space interpolation primitive. Useful as a
/// component of higher-order blending (e.g., normalized LERP =
/// LERP + renormalize as a cheap rotor-slerp approximation).
pub fn multivector_lerp(a: &Multivector, b: &Multivector, t: f64) -> Multivector {
    let one_minus_t = 1.0 - t;
    a.scale(one_minus_t).add(&b.scale(t))
}

/// Cosine similarity between two multivectors via the graded
/// scalar inner product:
///
///   cos(a, b) = ⟨a, b⟩ / (||a|| · ||b||).
///
/// Bounded in `[-1, 1]` for like-grade inputs. Returns `0` if
/// either input has zero norm (degenerate case — no defined
/// direction). Equivalent to the vector cosine when both inputs
/// are pure grade-1.
///
/// Iter-234 — companion to `multivector_scalar_inner_product`
/// (iter-228) and `angle_between_vectors` (iter-104); the former
/// is the un-normalized inner product, this is the normalized
/// cosine, and the latter is the arc-cosine specialized to
/// vector inputs.
pub fn multivector_cosine_similarity(a: &Multivector, b: &Multivector) -> f64 {
    let denom = a.norm() * b.norm();
    if denom <= 0.0 {
        return 0.0;
    }
    multivector_scalar_inner_product(a, b) / denom
}

/// Scalar inner product `⟨a, b⟩ = scalar_part(ã · b)`.
///
/// The canonical graded inner product on Cl(3, 0). For pure
/// vectors it collapses to the dot product; for pure rotors it is
/// `cos(θ₁/2)·cos(θ₂/2) + sin(θ₁/2)·sin(θ₂/2)·B̂₁·B̂₂`. Bilinear,
/// symmetric (when `ã = a`, i.e. for grades 0 and 1), and induces
/// the same `norm_squared` as `Multivector::norm_squared` via
/// `⟨a, a⟩ = ||a||²` for grades 0..=3 in Cl(3, 0).
///
/// Iter-228 — graded-inner-product primitive. Companion to
/// [`geo_dot`] (which returns the full grade-projection-mixing
/// half of the geometric product) and to
/// [`Multivector::grade_norm`] (which is the un-squared L² norm
/// per grade).
pub fn multivector_scalar_inner_product(a: &Multivector, b: &Multivector) -> f64 {
    let product = geo_product(&a.reverse(), b);
    product.scalar_part()
}

/// Commutator product `[a, b] = ½(ab − ba)`.
///
/// The antisymmetric half of the geometric product. For two pure
/// vectors `u, v` this collapses to the wedge product `u ∧ v`:
/// the bivector spanned by `u, v`. Vanishes when `a = b` (and more
/// generally whenever `ab = ba`, e.g. when one operand is a scalar).
///
/// Iter-186 — completes the (commutator, anticommutator) split of
/// the geometric product alongside `geo_dot` / `geo_wedge`.
pub fn multivector_commutator(a: &Multivector, b: &Multivector) -> Multivector {
    let ab = geo_product(a, b);
    let ba = geo_product(b, a);
    ab.sub(&ba).scale(0.5)
}

/// Anticommutator product `{a, b} = ½(ab + ba)`.
///
/// The symmetric half of the geometric product. For two pure
/// vectors `u, v` this collapses to the scalar inner product
/// `u · v`. Identically equals `ab` when `a` and `b` commute.
///
/// Iter-186 — anticommutator companion to `multivector_commutator`.
pub fn multivector_anticommutator(a: &Multivector, b: &Multivector) -> Multivector {
    let ab = geo_product(a, b);
    let ba = geo_product(b, a);
    ab.add(&ba).scale(0.5)
}

/// Geometric inverse of a non-zero vector: `v^{-1} = v / (v · v)`.
///
/// Since `v · v = ||v||²` for a pure vector, the inverse points
/// in the same direction with magnitude `1/||v||`. Verified by
/// `v · v^{-1} = 1` in Cl(3, 0).
///
/// Returns `None` if `v` is the zero vector (non-invertible).
///
/// Iter-167 — Clifford-algebra division primitive.
pub fn vector_inverse(v: &Multivector) -> Option<Multivector> {
    let v2 = v.grade_norm_squared(1);
    if v2 == 0.0 {
        return None;
    }
    Some(v.scale(1.0 / v2))
}

/// 3D vector cross product via geometric algebra:
/// `u × v = -I · (u ∧ v)`
///
/// where `I = e_{123}` is the unit pseudoscalar. Equivalently,
/// `u × v` is the Hodge dual of the bivector `u ∧ v` in Cl(3,0).
///
/// Component-wise this matches the standard 3D cross product:
/// `(u × v)_x = u_y v_z - u_z v_y`
/// `(u × v)_y = u_z v_x - u_x v_z`
/// `(u × v)_z = u_x v_y - u_y v_x`
///
/// Inputs are taken as vector-grade multivectors; non-vector
/// components are ignored.
///
/// Iter-104 — bridges Geometry-IR's bivector-native algebra
/// with the classical 3D cross product used in physics.
pub fn vector_cross_product(u: &Multivector, v: &Multivector) -> Multivector {
    let (ux, uy, uz) = u.vector_part();
    let (vx, vy, vz) = v.vector_part();
    Multivector::vector(
        uy * vz - uz * vy,
        uz * vx - ux * vz,
        ux * vy - uy * vx,
    )
}

/// Reflect a vector `v` through the hyperplane orthogonal to a
/// unit vector `n`: `v' = -n v n`.
///
/// In Cl(3,0), reflection across the plane normal to a unit vector
/// `n` is given by the sandwich `−n v n`. The caller is responsible
/// for normalizing `n` to unit length; an un-normalized `n` scales
/// the result by `|n|²`.
///
/// Iter-85 — fundamental Clifford-algebra operation; rotors decompose
/// into pairs of reflections.
pub fn reflect_vector(v: &Multivector, n: &Multivector) -> Multivector {
    geo_product(&geo_product(n, v), n).scale(-1.0)
}

/// Evaluate a [`GeoExpr`] tree to a single [`Multivector`].
pub fn evaluate(expr: &GeoExpr) -> Multivector {
    match expr {
        GeoExpr::Literal(m) => *m,
        GeoExpr::Reverse(a) => evaluate(a).reverse(),
        GeoExpr::GeoProduct(a, b) => geo_product(&evaluate(a), &evaluate(b)),
    }
}

#[cfg(test)]
mod iter_85_tests {
    use super::super::grammar::Multivector;
    use super::*;

    // ── iter-174: multivector_dual ────────────────────────────────

    #[test]
    fn dual_of_scalar_is_pseudoscalar() {
        let s = Multivector::scalar(3.0);
        let d = multivector_dual(&s);
        // dual(s) = s · (-I) = -s · e_123.
        // Pseudoscalar coefficient should be -3.
        assert_eq!(d.pseudoscalar_part(), -3.0);
    }

    #[test]
    fn dual_of_pseudoscalar_is_negative_scalar() {
        let p = Multivector::pseudoscalar(2.0);
        let d = multivector_dual(&p);
        // dual(I) = I · (-I) = -I² = -(-1) = 1; so dual(2I) = 2.
        assert_eq!(d.scalar_part(), 2.0);
    }

    #[test]
    fn dual_of_e1_is_bivector() {
        // e_1 · (-e_{123}) = -e_1 · e_1 · e_2 · e_3 = -e_2 e_3 = -e_{23}.
        let e1 = Multivector::e1();
        let d = multivector_dual(&e1);
        let (b12, b13, b23) = d.bivector_part();
        assert_eq!(b12, 0.0);
        assert_eq!(b13, 0.0);
        assert_eq!(b23, -1.0);
    }

    #[test]
    fn double_dual_returns_original_up_to_sign() {
        // In Cl(3, 0): dual² = -1 (Hodge).
        let v = Multivector::vector(1.0, 2.0, 3.0);
        let dual_v = multivector_dual(&v);
        let double = multivector_dual(&dual_v);
        for (a, b) in v.components.iter().zip(double.components.iter()) {
            assert!((a + b).abs() < 1e-12, "v={}, dual²(v)={}", a, b);
        }
    }

    // ── iter-167: vector_inverse ──────────────────────────────────

    #[test]
    fn vector_inverse_unit_vector_is_self() {
        let e1 = Multivector::e1();
        let inv = vector_inverse(&e1).unwrap();
        assert_eq!(inv.vector_part(), (1.0, 0.0, 0.0));
    }

    #[test]
    fn vector_inverse_scales_correctly() {
        // v = (2, 0, 0); v·v = 4; v^{-1} = (0.5, 0, 0).
        let v = Multivector::vector(2.0, 0.0, 0.0);
        let inv = vector_inverse(&v).unwrap();
        assert_eq!(inv.vector_part(), (0.5, 0.0, 0.0));
    }

    #[test]
    fn vector_inverse_zero_returns_none() {
        let z = Multivector::zero();
        assert!(vector_inverse(&z).is_none());
    }

    #[test]
    fn vector_times_inverse_is_one() {
        // v · v^{-1} = 1 (scalar).
        let v = Multivector::vector(3.0, 4.0, 0.0); // |v|² = 25.
        let inv = vector_inverse(&v).unwrap();
        let product = geo_product(&v, &inv);
        assert!((product.scalar_part() - 1.0).abs() < 1e-12);
    }

    // ── iter-258: vector_lerp_normalized (NLERP) ──────────────────

    #[test]
    fn nlerp_at_zero_returns_a_normalized() {
        let a = Multivector::vector(3.0, 4.0, 0.0); // |a| = 5
        let b = Multivector::vector(0.0, 0.0, 1.0);
        let r = vector_lerp_normalized(&a, &b, 0.0);
        assert!((r.norm() - 1.0).abs() < 1e-12);
        // Direction of r is direction of a.
        let (rx, ry, _rz) = r.vector_part();
        assert!((rx - 0.6).abs() < 1e-12);
        assert!((ry - 0.8).abs() < 1e-12);
    }

    #[test]
    fn nlerp_at_one_returns_b_normalized() {
        let a = Multivector::vector(1.0, 0.0, 0.0);
        let b = Multivector::vector(0.0, 5.0, 0.0);
        let r = vector_lerp_normalized(&a, &b, 1.0);
        assert!((r.norm() - 1.0).abs() < 1e-12);
        let (rx, ry, _rz) = r.vector_part();
        assert!((rx).abs() < 1e-12);
        assert!((ry - 1.0).abs() < 1e-12);
    }

    #[test]
    fn nlerp_midpoint_unit_vectors_is_unit() {
        // For orthogonal unit vectors, midpoint NLERP is the 45° unit.
        let a = Multivector::vector(1.0, 0.0, 0.0);
        let b = Multivector::vector(0.0, 1.0, 0.0);
        let r = vector_lerp_normalized(&a, &b, 0.5);
        assert!((r.norm() - 1.0).abs() < 1e-12);
        let half = 0.5_f64.sqrt();
        let (rx, ry, _rz) = r.vector_part();
        assert!((rx - half).abs() < 1e-9);
        assert!((ry - half).abs() < 1e-9);
    }

    #[test]
    fn nlerp_zero_endpoint_returns_zero_when_lerp_collapses() {
        let a = Multivector::vector(1.0, 0.0, 0.0);
        let b = Multivector::vector(-1.0, 0.0, 0.0);
        // At t = 0.5: lerp = 0 → normalize_or_zero → 0.
        let r = vector_lerp_normalized(&a, &b, 0.5);
        for &c in &r.components {
            assert_eq!(c, 0.0);
        }
    }

    // ── iter-252: multivector_normalize_or_zero ───────────────────

    #[test]
    fn normalize_or_zero_nonzero_yields_unit_norm() {
        let v = Multivector::vector(3.0, 4.0, 0.0);
        let n = multivector_normalize_or_zero(&v);
        assert!((n.norm() - 1.0).abs() < 1e-12);
    }

    #[test]
    fn normalize_or_zero_zero_input_returns_zero() {
        let z = Multivector::zero();
        let n = multivector_normalize_or_zero(&z);
        for &c in &n.components {
            assert_eq!(c, 0.0);
        }
    }

    #[test]
    fn normalize_or_zero_preserves_direction() {
        // After normalization, vector should be parallel to input.
        let v = Multivector::vector(2.0, 4.0, 6.0);
        let n = multivector_normalize_or_zero(&v);
        // n is parallel to v iff for all i,j: n[i]·v[j] == n[j]·v[i].
        let (vx, vy, vz) = v.vector_part();
        let (nx, ny, nz) = n.vector_part();
        assert!((nx * vy - ny * vx).abs() < 1e-9);
        assert!((nx * vz - nz * vx).abs() < 1e-9);
    }

    // ── iter-312: multivector_grade_filter ────────────────────────

    #[test]
    fn grade_filter_identity_mask_passes_through() {
        let m = Multivector::scalar(1.0)
            .add(&Multivector::vector(2.0, 3.0, 4.0))
            .add(&Multivector::bivector(5.0, 6.0, 7.0))
            .add(&Multivector::pseudoscalar(8.0));
        let f = multivector_grade_filter(&m, 0b1111);
        for (a, b) in m.components.iter().zip(f.components.iter()) {
            assert_eq!(a, b);
        }
    }

    #[test]
    fn grade_filter_zero_mask_returns_zero() {
        let m = Multivector::vector(1.0, 2.0, 3.0);
        let f = multivector_grade_filter(&m, 0);
        for &c in &f.components {
            assert_eq!(c, 0.0);
        }
    }

    #[test]
    fn grade_filter_even_mask_matches_even_part() {
        let m = Multivector::scalar(1.0)
            .add(&Multivector::vector(2.0, 3.0, 4.0))
            .add(&Multivector::bivector(5.0, 6.0, 7.0))
            .add(&Multivector::pseudoscalar(8.0));
        let f = multivector_grade_filter(&m, 0b0101);
        let e = multivector_even_part(&m);
        for (a, b) in f.components.iter().zip(e.components.iter()) {
            assert_eq!(a, b);
        }
    }

    #[test]
    fn grade_filter_odd_mask_matches_odd_part() {
        let m = Multivector::scalar(1.0)
            .add(&Multivector::vector(2.0, 3.0, 4.0))
            .add(&Multivector::bivector(5.0, 6.0, 7.0))
            .add(&Multivector::pseudoscalar(8.0));
        let f = multivector_grade_filter(&m, 0b1010);
        let o = multivector_odd_part(&m);
        for (a, b) in f.components.iter().zip(o.components.iter()) {
            assert_eq!(a, b);
        }
    }

    // ── iter-306: multivector_is_approximately_pure_grade ─────────

    #[test]
    fn approx_pure_grade_pure_vector_passes_grade_1() {
        let v = Multivector::vector(3.0, 4.0, 5.0);
        assert!(multivector_is_approximately_pure_grade(&v, 1, 1e-12));
    }

    #[test]
    fn approx_pure_grade_tolerates_small_drift() {
        // Vector with tiny noise in scalar slot.
        let mut v = Multivector::vector(1.0, 0.0, 0.0);
        v.components[0] = 1e-10;
        assert!(multivector_is_approximately_pure_grade(&v, 1, 1e-9));
        assert!(!multivector_is_approximately_pure_grade(&v, 1, 1e-11));
    }

    #[test]
    fn approx_pure_grade_rejects_mixed_grade() {
        let mixed = Multivector::vector(1.0, 0.0, 0.0)
            .add(&Multivector::bivector(1.0, 0.0, 0.0));
        assert!(!multivector_is_approximately_pure_grade(&mixed, 1, 1e-9));
    }

    #[test]
    fn approx_pure_grade_invalid_grade_returns_false() {
        let v = Multivector::vector(1.0, 0.0, 0.0);
        assert!(!multivector_is_approximately_pure_grade(&v, 99, 1.0));
    }

    // ── iter-300: multivector_even_part / odd_part ────────────────

    #[test]
    fn even_part_keeps_grades_0_2() {
        let m = Multivector::scalar(1.0)
            .add(&Multivector::vector(2.0, 3.0, 4.0))
            .add(&Multivector::bivector(5.0, 6.0, 7.0))
            .add(&Multivector::pseudoscalar(8.0));
        let e = multivector_even_part(&m);
        assert_eq!(e.scalar_part(), 1.0);
        assert_eq!(e.vector_part(), (0.0, 0.0, 0.0));
        assert_eq!(e.bivector_part(), (5.0, 6.0, 7.0));
        assert_eq!(e.pseudoscalar_part(), 0.0);
    }

    #[test]
    fn odd_part_keeps_grades_1_3() {
        let m = Multivector::scalar(1.0)
            .add(&Multivector::vector(2.0, 3.0, 4.0))
            .add(&Multivector::bivector(5.0, 6.0, 7.0))
            .add(&Multivector::pseudoscalar(8.0));
        let o = multivector_odd_part(&m);
        assert_eq!(o.scalar_part(), 0.0);
        assert_eq!(o.vector_part(), (2.0, 3.0, 4.0));
        assert_eq!(o.bivector_part(), (0.0, 0.0, 0.0));
        assert_eq!(o.pseudoscalar_part(), 8.0);
    }

    #[test]
    fn even_plus_odd_reconstructs_input() {
        let m = Multivector::scalar(1.0)
            .add(&Multivector::vector(2.0, 3.0, 4.0))
            .add(&Multivector::bivector(5.0, 6.0, 7.0))
            .add(&Multivector::pseudoscalar(8.0));
        let e = multivector_even_part(&m);
        let o = multivector_odd_part(&m);
        let reconstructed = e.add(&o);
        for (a, b) in m.components.iter().zip(reconstructed.components.iter()) {
            assert_eq!(a, b);
        }
    }

    #[test]
    fn even_part_is_grade_involution_fixpoint() {
        // m̂ = m iff m is even (eigenspace +1 of grade involution).
        let m = Multivector::scalar(1.0).add(&Multivector::bivector(2.0, 3.0, 4.0));
        let m_hat = multivector_grade_involution(&m);
        for (a, b) in m.components.iter().zip(m_hat.components.iter()) {
            assert_eq!(a, b);
        }
    }

    // ── iter-270: multivector_grade_involution ────────────────────

    #[test]
    fn grade_involution_negates_odd_grades_keeps_even() {
        let m = Multivector::scalar(1.0)
            .add(&Multivector::vector(2.0, 3.0, 4.0))
            .add(&Multivector::bivector(5.0, 6.0, 7.0))
            .add(&Multivector::pseudoscalar(8.0));
        let inv = multivector_grade_involution(&m);
        assert_eq!(inv.scalar_part(), 1.0);
        assert_eq!(inv.vector_part(), (-2.0, -3.0, -4.0));
        assert_eq!(inv.bivector_part(), (5.0, 6.0, 7.0));
        assert_eq!(inv.pseudoscalar_part(), -8.0);
    }

    #[test]
    fn grade_involution_involution_property() {
        let m = Multivector::vector(1.0, 2.0, 3.0);
        let ii = multivector_grade_involution(&multivector_grade_involution(&m));
        for (a, b) in m.components.iter().zip(ii.components.iter()) {
            assert_eq!(a, b);
        }
    }

    #[test]
    fn grade_involution_compose_with_reverse_yields_conjugate() {
        // bar(m) = reverse(grade_involution(m)).
        let m = Multivector::scalar(1.0)
            .add(&Multivector::vector(2.0, 3.0, 4.0))
            .add(&Multivector::bivector(5.0, 6.0, 7.0))
            .add(&Multivector::pseudoscalar(8.0));
        let bar = multivector_clifford_conjugate(&m);
        let via_compose = multivector_grade_involution(&m).reverse();
        for (a, b) in bar.components.iter().zip(via_compose.components.iter()) {
            assert!((a - b).abs() < 1e-12);
        }
    }

    // ── iter-264: multivector_clifford_conjugate ──────────────────

    #[test]
    fn clifford_conjugate_negates_grade_1() {
        let v = Multivector::vector(3.0, 4.0, 5.0);
        let c = multivector_clifford_conjugate(&v);
        assert_eq!(c.vector_part(), (-3.0, -4.0, -5.0));
    }

    #[test]
    fn clifford_conjugate_negates_grade_2() {
        let b = Multivector::bivector(1.0, 2.0, 3.0);
        let c = multivector_clifford_conjugate(&b);
        assert_eq!(c.bivector_part(), (-1.0, -2.0, -3.0));
    }

    #[test]
    fn clifford_conjugate_keeps_scalar_and_pseudoscalar() {
        let s = Multivector::scalar(5.0).add(&Multivector::pseudoscalar(7.0));
        let c = multivector_clifford_conjugate(&s);
        assert_eq!(c.scalar_part(), 5.0);
        assert_eq!(c.pseudoscalar_part(), 7.0);
    }

    #[test]
    fn clifford_conjugate_involution() {
        let m = Multivector::scalar(1.0)
            .add(&Multivector::vector(2.0, 3.0, 4.0))
            .add(&Multivector::bivector(5.0, 6.0, 7.0))
            .add(&Multivector::pseudoscalar(8.0));
        let cc = multivector_clifford_conjugate(&multivector_clifford_conjugate(&m));
        for (a, b) in m.components.iter().zip(cc.components.iter()) {
            assert_eq!(a, b);
        }
    }

    // ── iter-282: vector_distance_l1 ──────────────────────────────

    #[test]
    fn vector_distance_l1_self_is_zero() {
        let v = Multivector::vector(1.0, 2.0, 3.0);
        assert_eq!(vector_distance_l1(&v, &v), 0.0);
    }

    #[test]
    fn vector_distance_l1_known() {
        let u = Multivector::vector(1.0, 2.0, 3.0);
        let v = Multivector::vector(-1.0, 4.0, 0.0);
        // |1-(-1)| + |2-4| + |3-0| = 2 + 2 + 3 = 7.
        assert_eq!(vector_distance_l1(&u, &v), 7.0);
    }

    #[test]
    fn vector_distance_l1_ignores_bivector_part() {
        // Only grade-1 components contribute.
        let u = Multivector::vector(1.0, 0.0, 0.0)
            .add(&Multivector::bivector(100.0, 100.0, 100.0));
        let v = Multivector::vector(0.0, 0.0, 0.0);
        assert_eq!(vector_distance_l1(&u, &v), 1.0);
    }

    #[test]
    fn vector_distance_l1_at_least_linf() {
        // L¹ ≥ max |u_i - v_i| = L^∞.
        let u = Multivector::vector(1.0, 2.0, 5.0);
        let v = Multivector::vector(0.0, 0.0, 0.0);
        let l1 = vector_distance_l1(&u, &v);
        assert!(l1 >= 5.0 - 1e-9);
    }

    // ── iter-276: multivector_distance_squared ────────────────────

    #[test]
    fn distance_squared_self_is_zero() {
        let v = Multivector::vector(1.0, 2.0, 3.0);
        assert_eq!(multivector_distance_squared(&v, &v), 0.0);
    }

    #[test]
    fn distance_squared_matches_distance_squared_value() {
        let u = Multivector::vector(0.0, 0.0, 0.0);
        let v = Multivector::vector(3.0, 4.0, 0.0);
        let d = multivector_distance(&u, &v);
        let d2 = multivector_distance_squared(&u, &v);
        assert!((d2 - d * d).abs() < 1e-9);
    }

    #[test]
    fn distance_squared_symmetric() {
        let a = Multivector::vector(1.0, 0.0, 0.0);
        let b = Multivector::bivector(0.0, 1.0, 0.0);
        assert!((multivector_distance_squared(&a, &b)
            - multivector_distance_squared(&b, &a))
        .abs() < 1e-12);
    }

    // ── iter-246: multivector_distance ────────────────────────────

    #[test]
    fn multivector_distance_self_is_zero() {
        let v = Multivector::vector(1.0, 2.0, 3.0);
        assert_eq!(multivector_distance(&v, &v), 0.0);
    }

    #[test]
    fn multivector_distance_matches_vector_distance() {
        let u = Multivector::vector(0.0, 0.0, 0.0);
        let v = Multivector::vector(3.0, 4.0, 0.0);
        assert!((multivector_distance(&u, &v) - 5.0).abs() < 1e-12);
    }

    #[test]
    fn multivector_distance_symmetric() {
        let a = Multivector::vector(1.0, 2.0, 3.0);
        let b = Multivector::bivector(4.0, 5.0, 6.0);
        assert!((multivector_distance(&a, &b) - multivector_distance(&b, &a)).abs() < 1e-12);
    }

    #[test]
    fn multivector_distance_triangle_inequality() {
        let a = Multivector::vector(1.0, 0.0, 0.0);
        let b = Multivector::vector(0.0, 1.0, 0.0);
        let c = Multivector::vector(0.0, 0.0, 1.0);
        let d_ab = multivector_distance(&a, &b);
        let d_bc = multivector_distance(&b, &c);
        let d_ac = multivector_distance(&a, &c);
        assert!(d_ac <= d_ab + d_bc + 1e-12);
    }

    // ── iter-294: multivector_componentwise_min ───────────────────

    #[test]
    fn componentwise_min_basic() {
        let a = Multivector::vector(1.0, 5.0, 3.0);
        let b = Multivector::vector(4.0, 2.0, 6.0);
        let m = multivector_componentwise_min(&a, &b);
        assert_eq!(m.vector_part(), (1.0, 2.0, 3.0));
    }

    #[test]
    fn componentwise_min_idempotent() {
        let v = Multivector::vector(1.0, 2.0, 3.0);
        let m = multivector_componentwise_min(&v, &v);
        for (a, b) in v.components.iter().zip(m.components.iter()) {
            assert_eq!(a, b);
        }
    }

    #[test]
    fn componentwise_min_dominated_by_each_input() {
        let a = Multivector::vector(1.0, 5.0, 3.0);
        let b = Multivector::vector(4.0, 2.0, 6.0);
        let m = multivector_componentwise_min(&a, &b);
        for i in 0..8 {
            assert!(m.components[i] <= a.components[i]);
            assert!(m.components[i] <= b.components[i]);
        }
    }

    #[test]
    fn componentwise_min_plus_max_equals_sum() {
        // min(a, b) + max(a, b) = a + b componentwise.
        let a = Multivector::vector(1.0, 5.0, 3.0);
        let b = Multivector::bivector(2.0, 7.0, 1.0);
        let mn = multivector_componentwise_min(&a, &b);
        let mx = multivector_componentwise_max(&a, &b);
        let sum = mn.add(&mx);
        let direct = a.add(&b);
        for (s, d) in sum.components.iter().zip(direct.components.iter()) {
            assert_eq!(s, d);
        }
    }

    // ── iter-288: multivector_componentwise_max ───────────────────

    #[test]
    fn componentwise_max_basic() {
        let a = Multivector::vector(1.0, 5.0, 3.0);
        let b = Multivector::vector(4.0, 2.0, 6.0);
        let m = multivector_componentwise_max(&a, &b);
        assert_eq!(m.vector_part(), (4.0, 5.0, 6.0));
    }

    #[test]
    fn componentwise_max_idempotent() {
        let v = Multivector::vector(1.0, 2.0, 3.0);
        let m = multivector_componentwise_max(&v, &v);
        for (a, b) in v.components.iter().zip(m.components.iter()) {
            assert_eq!(a, b);
        }
    }

    #[test]
    fn componentwise_max_commutative() {
        let a = Multivector::vector(1.0, 5.0, 3.0);
        let b = Multivector::bivector(2.0, 7.0, 1.0);
        let ab = multivector_componentwise_max(&a, &b);
        let ba = multivector_componentwise_max(&b, &a);
        for (x, y) in ab.components.iter().zip(ba.components.iter()) {
            assert_eq!(x, y);
        }
    }

    #[test]
    fn componentwise_max_dominates_each_input() {
        let a = Multivector::vector(1.0, 5.0, 3.0);
        let b = Multivector::vector(4.0, 2.0, 6.0);
        let m = multivector_componentwise_max(&a, &b);
        for i in 0..8 {
            assert!(m.components[i] >= a.components[i]);
            assert!(m.components[i] >= b.components[i]);
        }
    }

    // ── iter-240: multivector_lerp ────────────────────────────────

    #[test]
    fn lerp_at_zero_returns_a() {
        let a = Multivector::vector(1.0, 2.0, 3.0);
        let b = Multivector::vector(4.0, 5.0, 6.0);
        let l = multivector_lerp(&a, &b, 0.0);
        assert_eq!(l.vector_part(), a.vector_part());
    }

    #[test]
    fn lerp_at_one_returns_b() {
        let a = Multivector::vector(1.0, 2.0, 3.0);
        let b = Multivector::vector(4.0, 5.0, 6.0);
        let l = multivector_lerp(&a, &b, 1.0);
        assert_eq!(l.vector_part(), b.vector_part());
    }

    #[test]
    fn lerp_at_half_is_componentwise_mean() {
        let a = Multivector::vector(0.0, 0.0, 0.0);
        let b = Multivector::vector(2.0, 4.0, 6.0);
        let l = multivector_lerp(&a, &b, 0.5);
        assert_eq!(l.vector_part(), (1.0, 2.0, 3.0));
    }

    #[test]
    fn lerp_three_eighths_known() {
        let a = Multivector::vector(0.0, 0.0, 0.0);
        let b = Multivector::vector(8.0, 16.0, 0.0);
        // 0.625·a + 0.375·b = (3, 6, 0).
        let l = multivector_lerp(&a, &b, 0.375);
        assert_eq!(l.vector_part(), (3.0, 6.0, 0.0));
    }

    // ── iter-234: multivector_cosine_similarity ───────────────────

    #[test]
    fn cosine_similarity_self_is_one() {
        let v = Multivector::vector(1.0, 2.0, 3.0);
        let c = multivector_cosine_similarity(&v, &v);
        assert!((c - 1.0).abs() < 1e-12);
    }

    #[test]
    fn cosine_similarity_antiparallel_is_minus_one() {
        let v = Multivector::vector(1.0, 0.0, 0.0);
        let nv = Multivector::vector(-1.0, 0.0, 0.0);
        assert!((multivector_cosine_similarity(&v, &nv) + 1.0).abs() < 1e-12);
    }

    #[test]
    fn cosine_similarity_orthogonal_is_zero() {
        let u = Multivector::vector(1.0, 0.0, 0.0);
        let v = Multivector::vector(0.0, 1.0, 0.0);
        assert!(multivector_cosine_similarity(&u, &v).abs() < 1e-12);
    }

    #[test]
    fn cosine_similarity_zero_input_returns_zero() {
        let z = Multivector::zero();
        let v = Multivector::vector(1.0, 0.0, 0.0);
        assert_eq!(multivector_cosine_similarity(&z, &v), 0.0);
    }

    #[test]
    fn cosine_similarity_matches_vector_dot_normalized() {
        let u = Multivector::vector(3.0, 4.0, 0.0);
        let v = Multivector::vector(0.0, 5.0, 0.0);
        // u · v = 20; |u| = 5; |v| = 5; cos = 20/25 = 0.8.
        let c = multivector_cosine_similarity(&u, &v);
        assert!((c - 0.8).abs() < 1e-12);
    }

    // ── iter-228: multivector_scalar_inner_product ────────────────

    #[test]
    fn scalar_inner_product_two_vectors_is_euclidean_dot() {
        let u = Multivector::vector(1.0, 2.0, 3.0);
        let v = Multivector::vector(4.0, -1.0, 2.0);
        let ip = multivector_scalar_inner_product(&u, &v);
        let expected = 1.0 * 4.0 + 2.0 * (-1.0) + 3.0 * 2.0;
        assert!((ip - expected).abs() < 1e-12);
    }

    #[test]
    fn scalar_inner_product_self_is_norm_squared() {
        // For grades 0..=3 in Cl(3, 0), ⟨a, a⟩ = ||a||².
        let v = Multivector::vector(3.0, 4.0, 0.0);
        let ip = multivector_scalar_inner_product(&v, &v);
        assert!((ip - 25.0).abs() < 1e-12);
        let b = Multivector::bivector(1.0, -2.0, 3.0);
        let ip_b = multivector_scalar_inner_product(&b, &b);
        let expected_b = 1.0 + 4.0 + 9.0;
        assert!((ip_b - expected_b).abs() < 1e-12);
    }

    #[test]
    fn scalar_inner_product_orthogonal_vectors_is_zero() {
        let u = Multivector::vector(1.0, 0.0, 0.0);
        let v = Multivector::vector(0.0, 1.0, 0.0);
        assert!(multivector_scalar_inner_product(&u, &v).abs() < 1e-12);
    }

    #[test]
    fn scalar_inner_product_scalars_is_product() {
        let a = Multivector::scalar(3.5);
        let b = Multivector::scalar(2.0);
        assert!((multivector_scalar_inner_product(&a, &b) - 7.0).abs() < 1e-12);
    }

    // ── iter-210: multivector_grade_norm ──────────────────────────

    #[test]
    fn grade_norm_pure_vector_matches_length() {
        // v = (3, 4, 0): |v|_grade1 = 5; other grades = 0.
        let v = Multivector::vector(3.0, 4.0, 0.0);
        assert!((multivector_grade_norm(&v, 1) - 5.0).abs() < 1e-12);
        assert_eq!(multivector_grade_norm(&v, 0), 0.0);
        assert_eq!(multivector_grade_norm(&v, 2), 0.0);
        assert_eq!(multivector_grade_norm(&v, 3), 0.0);
    }

    #[test]
    fn grade_norm_unit_rotor_grade_0_and_2_complement() {
        // Unit rotor: |R|_grade0² + |R|_grade2² = 1.
        let r = Multivector::scalar(0.6).add(&Multivector::bivector(0.0, 0.8, 0.0));
        let n0 = multivector_grade_norm(&r, 0);
        let n2 = multivector_grade_norm(&r, 2);
        assert!((n0 * n0 + n2 * n2 - 1.0).abs() < 1e-12, "n0={} n2={}", n0, n2);
    }

    #[test]
    fn grade_norm_pseudoscalar_only_in_grade_3() {
        let i = Multivector::pseudoscalar(7.0);
        assert!((multivector_grade_norm(&i, 3) - 7.0).abs() < 1e-12);
        for g in 0..=2 {
            assert_eq!(multivector_grade_norm(&i, g), 0.0);
        }
    }

    #[test]
    fn grade_norm_invalid_grade_returns_zero() {
        let v = Multivector::vector(1.0, 2.0, 3.0);
        assert_eq!(multivector_grade_norm(&v, 4), 0.0);
        assert_eq!(multivector_grade_norm(&v, 99), 0.0);
    }

    // ── iter-186: commutator / anticommutator ─────────────────────

    #[test]
    fn commutator_of_equal_vectors_is_zero() {
        let u = Multivector::vector(1.0, 2.0, 3.0);
        let c = multivector_commutator(&u, &u);
        for &x in &c.components {
            assert!(x.abs() < 1e-12);
        }
    }

    #[test]
    fn commutator_of_two_vectors_equals_wedge() {
        // [u, v] = u ∧ v for pure vectors in Cl(3, 0).
        let u = Multivector::vector(1.0, 2.0, 0.0);
        let v = Multivector::vector(3.0, 4.0, 0.0);
        let c = multivector_commutator(&u, &v);
        let w = geo_wedge(&u, &v);
        for (a, b) in c.components.iter().zip(w.components.iter()) {
            assert!((a - b).abs() < 1e-12, "comm={}, wedge={}", a, b);
        }
    }

    #[test]
    fn anticommutator_of_two_vectors_equals_dot() {
        // {u, v} = u · v (scalar) for pure vectors.
        let u = Multivector::vector(1.0, 2.0, 3.0);
        let v = Multivector::vector(-1.0, 0.0, 4.0);
        let a = multivector_anticommutator(&u, &v);
        let d = geo_dot(&u, &v);
        for (x, y) in a.components.iter().zip(d.components.iter()) {
            assert!((x - y).abs() < 1e-12, "anticomm={}, dot={}", x, y);
        }
    }

    #[test]
    fn commutator_anticommutator_sum_equals_geo_product() {
        // [a, b] + {a, b} = ab.
        let a = Multivector::vector(0.0, 1.0, 2.0);
        let b = Multivector::vector(3.0, -1.0, 1.0);
        let comm = multivector_commutator(&a, &b);
        let anti = multivector_anticommutator(&a, &b);
        let prod = geo_product(&a, &b);
        let sum = comm.add(&anti);
        for (s, p) in sum.components.iter().zip(prod.components.iter()) {
            assert!((s - p).abs() < 1e-12);
        }
    }

    #[test]
    fn commutator_with_scalar_is_zero() {
        // Scalars commute with everything → commutator vanishes.
        let s = Multivector::scalar(5.0);
        let v = Multivector::vector(1.0, -2.0, 3.0);
        let c = multivector_commutator(&s, &v);
        for &x in &c.components {
            assert!(x.abs() < 1e-12);
        }
    }

    // ── iter-162: project_onto_bivector_plane ─────────────────────

    #[test]
    fn project_e3_onto_e12_plane_is_zero() {
        // e_3 is perpendicular to the xy-plane (e_12). Projection = 0.
        let e3 = Multivector::e3();
        let e12 = Multivector::e12();
        let proj = project_onto_bivector_plane(&e3, &e12);
        assert!((proj.vector_part().0).abs() < 1e-12);
        assert!((proj.vector_part().1).abs() < 1e-12);
        assert!((proj.vector_part().2).abs() < 1e-12);
    }

    #[test]
    fn reject_e3_from_e12_plane_is_e3() {
        // e_3 has no xy-component, so rejection = e_3.
        let e3 = Multivector::e3();
        let e12 = Multivector::e12();
        let rej = reject_from_bivector_plane(&e3, &e12);
        let (x, y, z) = rej.vector_part();
        assert!(x.abs() < 1e-12);
        assert!(y.abs() < 1e-12);
        assert!((z - 1.0).abs() < 1e-12);
    }

    #[test]
    fn project_plus_reject_equals_v() {
        // v = proj_B(v) + rej_B(v).
        let v = Multivector::vector(1.0, 2.0, 3.0);
        let b = Multivector::e12();
        let proj = project_onto_bivector_plane(&v, &b);
        let rej = reject_from_bivector_plane(&v, &b);
        let sum = proj.add(&rej);
        let (sx, sy, sz) = sum.vector_part();
        let (vx, vy, vz) = v.vector_part();
        assert!((sx - vx).abs() < 1e-12);
        assert!((sy - vy).abs() < 1e-12);
        assert!((sz - vz).abs() < 1e-12);
    }

    // ── iter-130: vector_projection + vector_rejection ────────────

    #[test]
    fn vector_projection_onto_axis_aligned() {
        // v = (3, 4, 0), n = e_1. proj = (3, 0, 0).
        let v = Multivector::vector(3.0, 4.0, 0.0);
        let n = Multivector::vector(1.0, 0.0, 0.0);
        let proj = vector_projection(&v, &n);
        assert_eq!(proj.vector_part(), (3.0, 0.0, 0.0));
    }

    #[test]
    fn vector_projection_onto_zero_returns_zero() {
        let v = Multivector::vector(1.0, 2.0, 3.0);
        let n = Multivector::zero();
        let proj = vector_projection(&v, &n);
        assert_eq!(proj.vector_part(), (0.0, 0.0, 0.0));
    }

    #[test]
    fn vector_projection_self_is_self() {
        // proj_v(v) = v.
        let v = Multivector::vector(1.0, 2.0, 3.0);
        let proj = vector_projection(&v, &v);
        assert!((proj.vector_part().0 - 1.0).abs() < 1e-12);
        assert!((proj.vector_part().1 - 2.0).abs() < 1e-12);
        assert!((proj.vector_part().2 - 3.0).abs() < 1e-12);
    }

    #[test]
    fn vector_rejection_orthogonal_to_n() {
        // rej_n(v) should be perpendicular to n.
        let v = Multivector::vector(3.0, 4.0, 5.0);
        let n = Multivector::vector(1.0, 0.0, 0.0);
        let rej = vector_rejection(&v, &n);
        let dot = geo_dot(&rej, &n).scalar_part();
        assert!(dot.abs() < 1e-12, "rej · n = {}", dot);
    }

    #[test]
    fn projection_plus_rejection_recovers_v() {
        // v = proj_n(v) + rej_n(v).
        let v = Multivector::vector(2.0, 3.0, -1.0);
        let n = Multivector::vector(1.0, 1.0, 0.0);
        let proj = vector_projection(&v, &n);
        let rej = vector_rejection(&v, &n);
        let sum = proj.add(&rej);
        let (sx, sy, sz) = sum.vector_part();
        let (vx, vy, vz) = v.vector_part();
        assert!((sx - vx).abs() < 1e-12);
        assert!((sy - vy).abs() < 1e-12);
        assert!((sz - vz).abs() < 1e-12);
    }

    // ── iter-123: angle_between + scalar_triple_product ───────────

    #[test]
    fn angle_orthogonal_is_pi_over_2() {
        let e1 = Multivector::vector(1.0, 0.0, 0.0);
        let e2 = Multivector::vector(0.0, 1.0, 0.0);
        let theta = angle_between_vectors(&e1, &e2);
        assert!((theta - std::f64::consts::FRAC_PI_2).abs() < 1e-12);
    }

    #[test]
    fn angle_parallel_is_zero() {
        let u = Multivector::vector(2.0, 0.0, 0.0);
        let v = Multivector::vector(3.0, 0.0, 0.0);
        let theta = angle_between_vectors(&u, &v);
        assert!(theta.abs() < 1e-12);
    }

    #[test]
    fn angle_anti_parallel_is_pi() {
        let u = Multivector::vector(1.0, 0.0, 0.0);
        let v = Multivector::vector(-2.0, 0.0, 0.0);
        let theta = angle_between_vectors(&u, &v);
        assert!((theta - std::f64::consts::PI).abs() < 1e-12);
    }

    #[test]
    fn angle_symmetric() {
        let u = Multivector::vector(1.0, 2.0, 0.0);
        let v = Multivector::vector(0.5, 1.5, 1.0);
        let a = angle_between_vectors(&u, &v);
        let b = angle_between_vectors(&v, &u);
        assert!((a - b).abs() < 1e-12);
    }

    #[test]
    fn angle_zero_vector_returns_zero_no_panic() {
        let u = Multivector::zero();
        let v = Multivector::vector(1.0, 2.0, 3.0);
        assert_eq!(angle_between_vectors(&u, &v), 0.0);
    }

    #[test]
    fn scalar_triple_product_basis_is_one() {
        let e1 = Multivector::vector(1.0, 0.0, 0.0);
        let e2 = Multivector::vector(0.0, 1.0, 0.0);
        let e3 = Multivector::vector(0.0, 0.0, 1.0);
        let v = scalar_triple_product(&e1, &e2, &e3);
        assert!((v - 1.0).abs() < 1e-12);
    }

    #[test]
    fn scalar_triple_product_left_handed_is_negative() {
        let e1 = Multivector::vector(1.0, 0.0, 0.0);
        let e2 = Multivector::vector(0.0, 1.0, 0.0);
        let e3 = Multivector::vector(0.0, 0.0, -1.0);
        let v = scalar_triple_product(&e1, &e2, &e3);
        assert!(v < 0.0);
    }

    #[test]
    fn scalar_triple_product_cyclic_invariant() {
        // u·(v×w) = v·(w×u) = w·(u×v).
        let u = Multivector::vector(1.0, 2.0, 3.0);
        let v = Multivector::vector(0.5, -0.7, 1.2);
        let w = Multivector::vector(-1.0, 0.4, 0.8);
        let uvw = scalar_triple_product(&u, &v, &w);
        let vwu = scalar_triple_product(&v, &w, &u);
        let wuv = scalar_triple_product(&w, &u, &v);
        assert!((uvw - vwu).abs() < 1e-12);
        assert!((vwu - wuv).abs() < 1e-12);
    }

    #[test]
    fn scalar_triple_product_coplanar_is_zero() {
        // If three vectors lie in the same plane (e.g. all in xy):
        // scalar triple product = 0.
        let u = Multivector::vector(1.0, 0.0, 0.0);
        let v = Multivector::vector(0.0, 1.0, 0.0);
        let w = Multivector::vector(2.0, 3.0, 0.0); // linear combo of u, v
        let v_triple = scalar_triple_product(&u, &v, &w);
        assert!(v_triple.abs() < 1e-12);
    }

    // ── iter-111: grade_projection ────────────────────────────────

    #[test]
    fn grade_projection_extracts_pure_grade() {
        // Build a mixed multivector: scalar + vector + bivector.
        let m = Multivector::scalar(2.0)
            .add(&Multivector::vector(1.0, 2.0, 3.0))
            .add(&Multivector::bivector(4.0, 5.0, 6.0));

        let scalar_only = m.grade_projection(0);
        assert_eq!(scalar_only.scalar_part(), 2.0);
        assert_eq!(scalar_only.vector_part(), (0.0, 0.0, 0.0));
        assert_eq!(scalar_only.bivector_part(), (0.0, 0.0, 0.0));

        let vector_only = m.grade_projection(1);
        assert_eq!(vector_only.scalar_part(), 0.0);
        assert_eq!(vector_only.vector_part(), (1.0, 2.0, 3.0));
        assert_eq!(vector_only.bivector_part(), (0.0, 0.0, 0.0));

        let bivector_only = m.grade_projection(2);
        assert_eq!(bivector_only.scalar_part(), 0.0);
        assert_eq!(bivector_only.vector_part(), (0.0, 0.0, 0.0));
        assert_eq!(bivector_only.bivector_part(), (4.0, 5.0, 6.0));
    }

    #[test]
    fn grade_projection_above_three_is_zero() {
        let m = Multivector::pseudoscalar(7.0);
        let zero = m.grade_projection(4);
        assert_eq!(zero.norm_squared(), 0.0);
    }

    #[test]
    fn grade_projection_idempotent() {
        // P_k(P_k(m)) = P_k(m).
        let m = Multivector::scalar(1.0)
            .add(&Multivector::vector(2.0, 0.0, 1.0))
            .add(&Multivector::pseudoscalar(3.0));
        for grade in 0..4 {
            let once = m.grade_projection(grade);
            let twice = once.grade_projection(grade);
            for (a, b) in once.components.iter().zip(twice.components.iter()) {
                assert_eq!(a, b);
            }
        }
    }

    #[test]
    fn grade_projection_sum_recovers_full_multivector() {
        // m = Σ_k P_k(m) — the multivector decomposes into its grade parts.
        let m = Multivector::scalar(1.0)
            .add(&Multivector::vector(2.0, 3.0, 4.0))
            .add(&Multivector::bivector(5.0, 6.0, 7.0))
            .add(&Multivector::pseudoscalar(8.0));
        let mut reconstructed = Multivector::zero();
        for grade in 0..4 {
            reconstructed = reconstructed.add(&m.grade_projection(grade));
        }
        for (a, b) in m.components.iter().zip(reconstructed.components.iter()) {
            assert_eq!(a, b);
        }
    }

    // ── iter-104: cross product, normalize, is_pure_grade ────────

    #[test]
    fn vector_cross_product_e1_e2_is_e3() {
        let e1 = Multivector::vector(1.0, 0.0, 0.0);
        let e2 = Multivector::vector(0.0, 1.0, 0.0);
        let cross = vector_cross_product(&e1, &e2);
        assert_eq!(cross.vector_part(), (0.0, 0.0, 1.0));
    }

    #[test]
    fn vector_cross_product_anticommutative() {
        let u = Multivector::vector(1.0, 2.0, 3.0);
        let v = Multivector::vector(4.0, 5.0, 6.0);
        let uv = vector_cross_product(&u, &v);
        let vu = vector_cross_product(&v, &u);
        let (uvx, uvy, uvz) = uv.vector_part();
        let (vux, vuy, vuz) = vu.vector_part();
        assert_eq!(uvx, -vux);
        assert_eq!(uvy, -vuy);
        assert_eq!(uvz, -vuz);
    }

    #[test]
    fn vector_cross_product_parallel_is_zero() {
        let u = Multivector::vector(2.0, 4.0, 6.0);
        let v = Multivector::vector(1.0, 2.0, 3.0); // parallel
        let cross = vector_cross_product(&u, &v);
        assert_eq!(cross.vector_part(), (0.0, 0.0, 0.0));
    }

    #[test]
    fn vector_cross_product_perpendicular_to_inputs() {
        // (u × v) · u = 0 and (u × v) · v = 0.
        let u = Multivector::vector(1.0, 2.0, -1.0);
        let v = Multivector::vector(3.0, -1.0, 2.0);
        let cross = vector_cross_product(&u, &v);
        let dot_u = geo_dot(&cross, &u);
        let dot_v = geo_dot(&cross, &v);
        assert!(dot_u.scalar_part().abs() < 1e-12);
        assert!(dot_v.scalar_part().abs() < 1e-12);
    }

    #[test]
    fn multivector_normalize_unit_vector() {
        let v = Multivector::vector(3.0, 4.0, 0.0); // norm = 5
        let normalized = v.normalize().unwrap();
        let (x, y, z) = normalized.vector_part();
        // Float-tolerant comparison (3 * 0.2 isn't exactly 0.6 in f64).
        assert!((x - 0.6).abs() < 1e-12);
        assert!((y - 0.8).abs() < 1e-12);
        assert!((z - 0.0).abs() < 1e-12);
        assert!((normalized.norm() - 1.0).abs() < 1e-12);
    }

    #[test]
    fn multivector_normalize_zero_returns_none() {
        let v = Multivector::zero();
        assert!(v.normalize().is_none());
    }

    #[test]
    fn multivector_is_pure_grade_classification() {
        let scalar = Multivector::scalar(2.5);
        let vector = Multivector::vector(1.0, 0.0, 1.0);
        let bivector = Multivector::bivector(1.0, 0.0, 0.5);
        let pseudoscalar = Multivector::pseudoscalar(0.7);

        assert!(scalar.is_pure_grade(0));
        assert!(!scalar.is_pure_grade(1));

        assert!(vector.is_pure_grade(1));
        assert!(!vector.is_pure_grade(0));

        assert!(bivector.is_pure_grade(2));
        assert!(!bivector.is_pure_grade(1));

        assert!(pseudoscalar.is_pure_grade(3));
        assert!(!pseudoscalar.is_pure_grade(2));

        // Mixed-grade: scalar + vector.
        let mixed = scalar.add(&vector);
        assert!(!mixed.is_pure_grade(0));
        assert!(!mixed.is_pure_grade(1));

        // Out-of-range grade returns false.
        assert!(!vector.is_pure_grade(5));
    }

    #[test]
    fn multivector_zero_is_pure_every_grade() {
        let zero = Multivector::zero();
        // Zero has no non-zero components, so it trivially passes
        // is_pure_grade for any valid grade (0-3).
        assert!(zero.is_pure_grade(0));
        assert!(zero.is_pure_grade(1));
        assert!(zero.is_pure_grade(2));
        assert!(zero.is_pure_grade(3));
    }

    #[test]
    fn geo_dot_of_orthogonal_vectors_is_zero() {
        let u = Multivector::vector(1.0, 0.0, 0.0);
        let v = Multivector::vector(0.0, 1.0, 0.0);
        let dot = geo_dot(&u, &v);
        assert!(dot.is_scalar());
        assert_eq!(dot.scalar_part(), 0.0);
    }

    #[test]
    fn geo_dot_of_parallel_vectors_is_dot_product() {
        let u = Multivector::vector(2.0, 1.0, -1.0);
        let v = Multivector::vector(3.0, -2.0, 4.0);
        let dot = geo_dot(&u, &v);
        // 2·3 + 1·(-2) + (-1)·4 = 6 - 2 - 4 = 0 → also orthogonal
        assert_eq!(dot.scalar_part(), 0.0);

        let v2 = Multivector::vector(1.0, 1.0, 1.0);
        let u2 = Multivector::vector(2.0, 3.0, 4.0);
        let dot2 = geo_dot(&u2, &v2);
        assert_eq!(dot2.scalar_part(), 2.0 + 3.0 + 4.0);
    }

    #[test]
    fn geo_wedge_of_parallel_vectors_is_zero() {
        let u = Multivector::vector(2.0, 0.0, 0.0);
        let v = Multivector::vector(3.0, 0.0, 0.0);
        let wedge = geo_wedge(&u, &v);
        assert_eq!(wedge.grade_norm_squared(2), 0.0);
    }

    #[test]
    fn geo_wedge_of_x_y_is_e12() {
        // e_1 ∧ e_2 = e_12 (the xy bivector).
        let e1 = Multivector::vector(1.0, 0.0, 0.0);
        let e2 = Multivector::vector(0.0, 1.0, 0.0);
        let wedge = geo_wedge(&e1, &e2);
        let (b12, b13, b23) = wedge.bivector_part();
        assert_eq!((b12, b13, b23), (1.0, 0.0, 0.0));
    }

    #[test]
    fn geo_dot_plus_geo_wedge_equals_geo_product() {
        // a · b + a ∧ b = ab.
        let u = Multivector::vector(1.5, -0.7, 2.0);
        let v = Multivector::vector(-0.3, 1.2, 0.8);
        let prod = geo_product(&u, &v);
        let sum = geo_dot(&u, &v).add(&geo_wedge(&u, &v));
        for i in 0..8 {
            assert!(
                (prod.components[i] - sum.components[i]).abs() < 1e-12,
                "component {}: prod={}, dot+wedge={}", i, prod.components[i], sum.components[i]
            );
        }
    }

    #[test]
    fn reflect_vector_across_x_axis_flips_y_and_z() {
        // n = e_1 (unit vector along x-axis). Reflection: v' = -e_1 v e_1.
        // For v = (vx, vy, vz), result should be (vx, -vy, -vz)
        // (reflection across the YZ-plane normal to e_1 sends x → x,
        // but the formula -n v n with n = e_1 gives the reflection
        // ACROSS the plane perpendicular to n — flipping the
        // n-component). Verify: -e_1 v e_1 = (-vx, vy, vz).
        let v = Multivector::vector(2.0, 3.0, -1.0);
        let e1 = Multivector::vector(1.0, 0.0, 0.0);
        let refl = reflect_vector(&v, &e1);
        let (x, y, z) = refl.vector_part();
        assert!((x - (-2.0)).abs() < 1e-12);
        assert!((y - 3.0).abs() < 1e-12);
        assert!((z - (-1.0)).abs() < 1e-12);
    }

    #[test]
    fn reflect_vector_preserves_norm() {
        let v = Multivector::vector(1.5, -2.0, 0.7);
        let n = Multivector::vector(1.0, 0.0, 0.0);
        let refl = reflect_vector(&v, &n);
        assert!(
            (v.grade_norm_squared(1) - refl.grade_norm_squared(1)).abs() < 1e-12,
            "norm² before = {}, after = {}",
            v.grade_norm_squared(1), refl.grade_norm_squared(1)
        );
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn approx_mv(a: &Multivector, b: &Multivector, tol: f64) -> bool {
        a.components
            .iter()
            .zip(b.components.iter())
            .all(|(x, y)| (x - y).abs() < tol)
    }

    // ── Basis-blade self-products ────────────────────────────────

    #[test]
    fn e1_squared_is_scalar_one() {
        let e1 = Multivector::vector(1.0, 0.0, 0.0);
        let r = geo_product(&e1, &e1);
        assert!(approx_mv(&r, &Multivector::scalar(1.0), 1e-12));
    }

    #[test]
    fn e2_squared_is_scalar_one() {
        let e2 = Multivector::vector(0.0, 1.0, 0.0);
        let r = geo_product(&e2, &e2);
        assert!(approx_mv(&r, &Multivector::scalar(1.0), 1e-12));
    }

    #[test]
    fn e3_squared_is_scalar_one() {
        let e3 = Multivector::vector(0.0, 0.0, 1.0);
        let r = geo_product(&e3, &e3);
        assert!(approx_mv(&r, &Multivector::scalar(1.0), 1e-12));
    }

    #[test]
    fn pseudoscalar_squared_is_minus_one() {
        // e_123 = e_1 e_2 e_3; (e_123)² = -1 in Cl(3,0).
        let i = Multivector::pseudoscalar(1.0);
        let r = geo_product(&i, &i);
        assert!(approx_mv(&r, &Multivector::scalar(-1.0), 1e-12));
    }

    // ── Anticommutativity of distinct basis vectors ───────────────

    #[test]
    fn e1_times_e2_is_e12() {
        let e1 = Multivector::vector(1.0, 0.0, 0.0);
        let e2 = Multivector::vector(0.0, 1.0, 0.0);
        let r = geo_product(&e1, &e2);
        assert!(approx_mv(&r, &Multivector::bivector(1.0, 0.0, 0.0), 1e-12));
    }

    #[test]
    fn e2_times_e1_is_minus_e12() {
        let e1 = Multivector::vector(1.0, 0.0, 0.0);
        let e2 = Multivector::vector(0.0, 1.0, 0.0);
        let r = geo_product(&e2, &e1);
        assert!(approx_mv(&r, &Multivector::bivector(-1.0, 0.0, 0.0), 1e-12));
    }

    #[test]
    fn anticommutativity_holds_for_e1_e2() {
        let e1 = Multivector::vector(1.0, 0.0, 0.0);
        let e2 = Multivector::vector(0.0, 1.0, 0.0);
        let ab = geo_product(&e1, &e2);
        let ba = geo_product(&e2, &e1);
        assert!(approx_mv(&ab, &ba.scale(-1.0), 1e-12));
    }

    // ── Bivector squares ─────────────────────────────────────────

    #[test]
    fn e12_squared_is_minus_one() {
        let e12 = Multivector::bivector(1.0, 0.0, 0.0);
        let r = geo_product(&e12, &e12);
        assert!(approx_mv(&r, &Multivector::scalar(-1.0), 1e-12));
    }

    #[test]
    fn e13_squared_is_minus_one() {
        let e13 = Multivector::bivector(0.0, 1.0, 0.0);
        let r = geo_product(&e13, &e13);
        assert!(approx_mv(&r, &Multivector::scalar(-1.0), 1e-12));
    }

    #[test]
    fn e23_squared_is_minus_one() {
        let e23 = Multivector::bivector(0.0, 0.0, 1.0);
        let r = geo_product(&e23, &e23);
        assert!(approx_mv(&r, &Multivector::scalar(-1.0), 1e-12));
    }

    // ── Scalar distributivity ────────────────────────────────────

    #[test]
    fn scalar_times_vector_yields_scaled_vector() {
        let s = Multivector::scalar(3.0);
        let v = Multivector::vector(1.0, 2.0, 4.0);
        let r = geo_product(&s, &v);
        assert!(approx_mv(&r, &Multivector::vector(3.0, 6.0, 12.0), 1e-12));
    }

    #[test]
    fn one_is_left_identity() {
        let v = Multivector::vector(1.5, -2.5, 0.5);
        let r = geo_product(&Multivector::scalar(1.0), &v);
        assert!(approx_mv(&r, &v, 1e-12));
    }

    #[test]
    fn one_is_right_identity() {
        let v = Multivector::vector(1.5, -2.5, 0.5);
        let r = geo_product(&v, &Multivector::scalar(1.0));
        assert!(approx_mv(&r, &v, 1e-12));
    }

    // ── Associativity ────────────────────────────────────────────

    #[test]
    fn geometric_product_is_associative_on_basis_vectors() {
        let e1 = Multivector::vector(1.0, 0.0, 0.0);
        let e2 = Multivector::vector(0.0, 1.0, 0.0);
        let e3 = Multivector::vector(0.0, 0.0, 1.0);
        let lhs = geo_product(&geo_product(&e1, &e2), &e3);
        let rhs = geo_product(&e1, &geo_product(&e2, &e3));
        assert!(approx_mv(&lhs, &rhs, 1e-12));
        // Both should equal the pseudoscalar e_123 = i.
        assert!(approx_mv(&lhs, &Multivector::pseudoscalar(1.0), 1e-12));
    }

    // ── GeoExpr evaluator ─────────────────────────────────────────

    #[test]
    fn evaluate_literal_returns_value() {
        let v = Multivector::vector(1.0, 2.0, 3.0);
        let e = GeoExpr::literal(v);
        let r = evaluate(&e);
        assert_eq!(r, v);
    }

    #[test]
    fn evaluate_reverse_negates_grade_2() {
        let b = Multivector::bivector(1.0, 2.0, 3.0);
        let e = GeoExpr::reverse(GeoExpr::literal(b));
        let r = evaluate(&e);
        assert!(approx_mv(&r, &Multivector::bivector(-1.0, -2.0, -3.0), 1e-12));
    }

    #[test]
    fn evaluate_geo_product_yields_correct_blade() {
        let e1 = GeoExpr::literal(Multivector::vector(1.0, 0.0, 0.0));
        let e2 = GeoExpr::literal(Multivector::vector(0.0, 1.0, 0.0));
        let e = GeoExpr::product(e1, e2);
        let r = evaluate(&e);
        assert!(approx_mv(&r, &Multivector::bivector(1.0, 0.0, 0.0), 1e-12));
    }

    #[test]
    fn evaluate_nested_product_associative() {
        // (e1 e2) e3 = e_123
        let e1 = GeoExpr::literal(Multivector::vector(1.0, 0.0, 0.0));
        let e2 = GeoExpr::literal(Multivector::vector(0.0, 1.0, 0.0));
        let e3 = GeoExpr::literal(Multivector::vector(0.0, 0.0, 1.0));
        let e = GeoExpr::product(GeoExpr::product(e1, e2), e3);
        let r = evaluate(&e);
        assert!(approx_mv(&r, &Multivector::pseudoscalar(1.0), 1e-12));
    }

    // ── iter-318: multivector_l1_norm / _linf_norm ─────────────────

    #[test]
    fn multivector_l1_norm_basic_sum_of_abs() {
        // Components: [1, -2, 3, -4, 5, -6, 7, -8] → L1 = 36.
        let m = Multivector {
            components: [1.0, -2.0, 3.0, -4.0, 5.0, -6.0, 7.0, -8.0],
        };
        assert!((multivector_l1_norm(&m) - 36.0).abs() < 1e-12);
    }

    #[test]
    fn multivector_linf_norm_basic_max_abs() {
        let m = Multivector {
            components: [1.0, -2.0, 3.0, -4.0, 5.0, -6.0, 7.0, -8.0],
        };
        assert!((multivector_linf_norm(&m) - 8.0).abs() < 1e-12);
    }

    #[test]
    fn multivector_norm_triple_inequality_holds() {
        // L∞ ≤ L² ≤ L¹ on every multivector.
        let m = Multivector {
            components: [0.5, -1.5, 2.0, -0.25, 1.0, -3.0, 0.75, -2.5],
        };
        let linf = multivector_linf_norm(&m);
        let l2 = m.norm();
        let l1 = multivector_l1_norm(&m);
        assert!(linf <= l2 + 1e-12);
        assert!(l2 <= l1 + 1e-12);
    }

    #[test]
    fn multivector_zero_has_zero_l1_and_linf() {
        let z = Multivector::zero();
        assert_eq!(multivector_l1_norm(&z), 0.0);
        assert_eq!(multivector_linf_norm(&z), 0.0);
    }

    #[test]
    fn multivector_l1_equals_linf_when_one_component_active() {
        // Single non-zero component → L1 == L∞ == |that component|.
        let mut c = [0.0; 8];
        c[5] = -4.25;
        let m = Multivector { components: c };
        assert!((multivector_l1_norm(&m) - 4.25).abs() < 1e-12);
        assert!((multivector_linf_norm(&m) - 4.25).abs() < 1e-12);
    }

    #[test]
    fn evaluate_full_blade_table_self_consistent() {
        // For each ordered pair of basis blades, geo_product should
        // produce a valid multivector (no panics, no NaN).
        for i in 0..8 {
            for j in 0..8 {
                let mut ai = [0.0; 8];
                ai[i] = 1.0;
                let mut bj = [0.0; 8];
                bj[j] = 1.0;
                let a = Multivector { components: ai };
                let b = Multivector { components: bj };
                let r = geo_product(&a, &b);
                for c in &r.components {
                    assert!(c.is_finite(), "blade ({},{}) gave non-finite", i, j);
                }
            }
        }
    }
}
