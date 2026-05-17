//! Source:
//! - Doctrine `docs/fusion/PRIMITIVE_IR_STACK_DOCTRINE_2026_05_17.md`
//!   §6.2 row 9 — Geometry-IR → Info-IR composition arrow
//!   ("Fisher metric via geometric product").
//! - Amari 1998 §2 — Fisher information is the Riemannian metric
//!   on the statistical manifold; at each point θ, tangent
//!   vectors carry an inner product `g_ij(θ) = I_ij(θ)`.
//! - Companion to iter-93/94/95 (other cross-IR arrows wired).
//!
//! # Composition: Geometry tangent vectors + Info Fisher metric
//!
//! The Fisher information matrix `I(θ) = ∇²A(θ)` (iter-92) IS the
//! Riemannian metric on the statistical manifold of an exp-family.
//! For tangent vectors `u, v` at point θ, the Fisher-induced inner
//! product is:
//!
//! ```text
//! ⟨u, v⟩_Fisher(θ) = u^T · I(θ) · v
//! ```
//!
//! Geometry-IR provides the multivector container for tangent
//! vectors (vector-grade only for this iter); Info-IR provides
//! `fisher_information(family, theta)`. Their composition
//! produces the Fisher norm² of tangent directions.
//!
//! Iter-96 — wires lattice arrow #9. Uses [`Multivector::vector_part`]
//! to extract 3D coordinates from Geometry-IR, then composes with
//! [`info_ir::fisher_information`] for a Categorical{k=4} distribution
//! (which lives in a 3-dim natural-param space matching Geometry's
//! 3D vector grade).

#![cfg(feature = "research")]

use agent_core::research::geometry_ir::Multivector;
use agent_core::research::info_ir::{fisher_information, ExpFamily};

/// Compute the Fisher-quadratic form `v^T · I · v` from a
/// Geometry-IR multivector (vector grade) and an Info-IR Fisher
/// matrix.
fn fisher_norm_squared(v: &Multivector, fisher: &[Vec<f64>]) -> f64 {
    let (vx, vy, vz) = v.vector_part();
    let v_arr = [vx, vy, vz];
    let mut q = 0.0;
    for i in 0..fisher.len() {
        for j in 0..fisher.len() {
            q += v_arr[i] * fisher[i][j] * v_arr[j];
        }
    }
    q
}

/// Compute the Fisher-induced inner product `u^T · I · v`.
fn fisher_inner_product(u: &Multivector, v: &Multivector, fisher: &[Vec<f64>]) -> f64 {
    let (ux, uy, uz) = u.vector_part();
    let (vx, vy, vz) = v.vector_part();
    let u_arr = [ux, uy, uz];
    let v_arr = [vx, vy, vz];
    let mut q = 0.0;
    for i in 0..fisher.len() {
        for j in 0..fisher.len() {
            q += u_arr[i] * fisher[i][j] * v_arr[j];
        }
    }
    q
}

#[test]
fn fisher_norm_at_uniform_categorical_k4_explicit_value() {
    // At θ=0 (uniform), I_ij = (1/4) · δ_ij - (1/4)·(1/4)
    //                       = 0.25 · δ_ij - 0.0625
    // For v = (1, 2, 3):
    // q = Σ_i v_i² · 0.25 - 0.0625 · (Σ_i v_i)²
    //   = 0.25 · 14 - 0.0625 · 36
    //   = 3.5 - 2.25 = 1.25
    let v = Multivector::vector(1.0, 2.0, 3.0);
    let fisher = fisher_information(&ExpFamily::Categorical { k: 4 }, &[0.0, 0.0, 0.0]);
    let q = fisher_norm_squared(&v, &fisher);
    assert!((q - 1.25).abs() < 1e-12, "Fisher norm² = {}", q);
}

#[test]
fn fisher_norm_zero_for_zero_vector() {
    let v = Multivector::zero();
    let fisher = fisher_information(&ExpFamily::Categorical { k: 4 }, &[0.5, -0.5, 0.0]);
    let q = fisher_norm_squared(&v, &fisher);
    assert!(q.abs() < 1e-12);
}

#[test]
fn fisher_norm_is_non_negative_psd_property() {
    // Fisher metric is positive semi-definite (it's a covariance).
    let fisher = fisher_information(&ExpFamily::Categorical { k: 4 }, &[1.0, -1.0, 0.5]);
    for v in [
        Multivector::vector(1.0, 0.0, 0.0),
        Multivector::vector(0.0, 1.0, 0.0),
        Multivector::vector(0.0, 0.0, 1.0),
        Multivector::vector(1.0, 1.0, 1.0),
        Multivector::vector(1.0, -1.0, 0.5),
        Multivector::vector(-2.0, 3.0, -1.5),
    ] {
        let q = fisher_norm_squared(&v, &fisher);
        assert!(
            q >= -1e-12,
            "Fisher norm² = {} should be ≥ 0 for v = {:?}", q, v.vector_part()
        );
    }
}

#[test]
fn fisher_inner_product_is_symmetric() {
    // ⟨u, v⟩_Fisher = ⟨v, u⟩_Fisher.
    let u = Multivector::vector(1.5, -0.7, 2.0);
    let v = Multivector::vector(-0.3, 1.2, 0.8);
    let fisher = fisher_information(&ExpFamily::Categorical { k: 4 }, &[0.2, -0.5, 1.0]);
    let uv = fisher_inner_product(&u, &v, &fisher);
    let vu = fisher_inner_product(&v, &u, &fisher);
    assert!((uv - vu).abs() < 1e-12, "⟨u,v⟩ = {}, ⟨v,u⟩ = {}", uv, vu);
}

#[test]
fn fisher_inner_product_is_bilinear() {
    // ⟨u + w, v⟩ = ⟨u, v⟩ + ⟨w, v⟩.
    let u = Multivector::vector(1.0, 0.0, 0.5);
    let w = Multivector::vector(0.0, 1.0, -0.5);
    let v = Multivector::vector(1.0, 1.0, 1.0);
    let uw = u.add(&w);
    let fisher = fisher_information(&ExpFamily::Categorical { k: 4 }, &[0.0, 0.0, 0.0]);

    let lhs = fisher_inner_product(&uw, &v, &fisher);
    let rhs = fisher_inner_product(&u, &v, &fisher) + fisher_inner_product(&w, &v, &fisher);
    assert!((lhs - rhs).abs() < 1e-12, "linearity: {} != {}", lhs, rhs);
}

#[test]
fn fisher_metric_differs_from_euclidean_metric() {
    // Verify the Fisher metric isn't just the identity (otherwise
    // the composition would be trivial).
    let v = Multivector::vector(1.0, 0.0, 0.0);
    let fisher = fisher_information(&ExpFamily::Categorical { k: 4 }, &[0.0, 0.0, 0.0]);
    let fisher_norm = fisher_norm_squared(&v, &fisher);
    let euclidean_norm = v.grade_norm_squared(1);

    // Fisher: 0.25·1 - 0.0625·1 = 0.1875.
    // Euclidean: 1.0.
    assert!(
        (fisher_norm - euclidean_norm).abs() > 0.5,
        "Fisher = {} vs Euclidean = {} should differ", fisher_norm, euclidean_norm
    );
}

#[test]
fn fisher_metric_scales_quadratically_with_vector() {
    // q(α·v) = α² · q(v).
    let v = Multivector::vector(1.0, 1.0, 1.0);
    let fisher = fisher_information(&ExpFamily::Categorical { k: 4 }, &[0.5, -0.5, 0.0]);
    let base = fisher_norm_squared(&v, &fisher);
    for alpha in [0.5_f64, 2.0, -3.0] {
        let scaled = v.scale(alpha);
        let scaled_q = fisher_norm_squared(&scaled, &fisher);
        assert!(
            (scaled_q - alpha * alpha * base).abs() < 1e-12,
            "q({}v) = {}; α²·q(v) = {}", alpha, scaled_q, alpha * alpha * base
        );
    }
}

#[test]
fn fisher_metric_changes_with_theta_position() {
    // Same tangent vector v evaluated at different θ gives
    // different Fisher norms (the metric is θ-dependent — that's
    // the whole point of a Riemannian metric).
    let v = Multivector::vector(1.0, 1.0, 0.0);
    let fisher_uniform = fisher_information(&ExpFamily::Categorical { k: 4 }, &[0.0, 0.0, 0.0]);
    let fisher_far = fisher_information(&ExpFamily::Categorical { k: 4 }, &[3.0, -2.0, 1.0]);
    let q_uniform = fisher_norm_squared(&v, &fisher_uniform);
    let q_far = fisher_norm_squared(&v, &fisher_far);
    assert!(
        (q_uniform - q_far).abs() > 0.05,
        "θ-independent metric would mean q_uniform={} ≈ q_far={}", q_uniform, q_far
    );
}
