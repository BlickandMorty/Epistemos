//! Source:
//! - §4.I:895 of CODEX_DEEP_INVESTIGATION_PROMPT — "Property test:
//!   identity rotation + composition law."
//! - Phase B5 close-out `docs/audits/PHASE_B5_CLOSEOUT_2026_05_17.md`
//!   §5 — iter-45 plan entry.

#![cfg(feature = "research")]

use agent_core::research::geometry_ir::{
    rotate, rotor_compose, rotor_from_angle_and_bivector, rotor_identity, Multivector,
};
use std::f64::consts::PI;

fn approx_vector(a: (f64, f64, f64), b: (f64, f64, f64), tol: f64) -> bool {
    (a.0 - b.0).abs() < tol && (a.1 - b.1).abs() < tol && (a.2 - b.2).abs() < tol
}

#[test]
fn identity_rotation_fixture_grid() {
    // §4.I:895 part 1: identity rotation returns input unchanged
    // across a fixture grid of vectors.
    let r = rotor_identity();
    let fixtures: Vec<(f64, f64, f64)> = vec![
        (1.0, 0.0, 0.0),
        (0.0, 1.0, 0.0),
        (0.0, 0.0, 1.0),
        (1.0, 1.0, 1.0),
        (3.0, -4.0, 5.0),
        (-1.5, 2.5, -0.5),
        (100.0, -100.0, 50.0),
    ];
    for (x, y, z) in &fixtures {
        let v = Multivector::vector(*x, *y, *z);
        let rotated = rotate(&v, &r);
        assert!(
            approx_vector(rotated.vector_part(), (*x, *y, *z), 1e-12),
            "v=({},{},{}) rotated={:?}", x, y, z, rotated.vector_part()
        );
    }
}

#[test]
fn composition_law_three_axis_rotation() {
    // §4.I:895 part 2: composition law (R_2 R_1) v = R_2 (R_1 v).
    let r1 = rotor_from_angle_and_bivector(PI / 4.0, 1.0, 0.0, 0.0); // π/4 around e_12
    let r2 = rotor_from_angle_and_bivector(PI / 6.0, 0.0, 1.0, 0.0); // π/6 around e_13
    let r_combined = rotor_compose(&r1, &r2);

    let v = Multivector::vector(1.0, 0.5, -0.3);

    // Apply via composition
    let v_via_combined = rotate(&v, &r_combined);
    // Apply step-by-step
    let v_after_r1 = rotate(&v, &r1);
    let v_via_steps = rotate(&v_after_r1, &r2);

    let a = v_via_combined.vector_part();
    let b = v_via_steps.vector_part();
    assert!(
        approx_vector(a, b, 1e-9),
        "combined: {:?}; stepwise: {:?}", a, b
    );
}

#[test]
fn rotation_preserves_norm_across_fixture_grid() {
    // For each rotation in the fixture, verify ∥R̃ v R∥ = ∥v∥
    // (rotation is an isometry on grade-1 vectors).
    let rotations = vec![
        rotor_from_angle_and_bivector(0.1, 1.0, 0.0, 0.0),
        rotor_from_angle_and_bivector(0.5, 0.0, 1.0, 0.0),
        rotor_from_angle_and_bivector(1.0, 0.0, 0.0, 1.0),
        rotor_from_angle_and_bivector(2.7, 0.6, 0.8, 0.0),
    ];
    let v = Multivector::vector(3.0, -4.0, 5.0);
    let v_norm_sq = v.grade_norm_squared(1);
    for r in &rotations {
        let v_rot = rotate(&v, r);
        let n = v_rot.grade_norm_squared(1);
        assert!(
            (n - v_norm_sq).abs() < 1e-9,
            "rotor preserved norm² {} → {}", v_norm_sq, n
        );
    }
}

#[test]
fn quarter_turn_cycle_returns_to_origin_after_four_steps() {
    // Four quarter turns around e_12 should return e_1 to itself.
    let r = rotor_from_angle_and_bivector(PI / 2.0, 1.0, 0.0, 0.0);
    let mut v = Multivector::vector(1.0, 0.0, 0.0);
    for _ in 0..4 {
        v = rotate(&v, &r);
    }
    assert!(
        approx_vector(v.vector_part(), (1.0, 0.0, 0.0), 1e-9),
        "after 4 quarter turns: {:?}", v.vector_part()
    );
}

#[test]
fn inverse_rotation_undoes_rotation() {
    let r = rotor_from_angle_and_bivector(0.7, 0.6, 0.8, 0.0);
    let r_inv = rotor_from_angle_and_bivector(-0.7, 0.6, 0.8, 0.0);
    let v = Multivector::vector(1.0, 2.0, 3.0);
    let v_round_trip = rotate(&rotate(&v, &r), &r_inv);
    assert!(
        approx_vector(v_round_trip.vector_part(), (1.0, 2.0, 3.0), 1e-9),
        "round trip: {:?}", v_round_trip.vector_part()
    );
}

#[test]
fn associativity_of_rotor_composition_across_three_rotations() {
    let r1 = rotor_from_angle_and_bivector(PI / 7.0, 1.0, 0.0, 0.0);
    let r2 = rotor_from_angle_and_bivector(PI / 11.0, 0.0, 1.0, 0.0);
    let r3 = rotor_from_angle_and_bivector(PI / 13.0, 0.0, 0.0, 1.0);
    let v = Multivector::vector(2.0, -1.0, 0.5);

    // (r3 (r2 r1)) v vs r3 (r2 (r1 v))
    let left = rotate(&v, &rotor_compose(&r1, &rotor_compose(&r2, &r3)));
    let mut step = rotate(&v, &r1);
    step = rotate(&step, &r2);
    step = rotate(&step, &r3);

    assert!(
        approx_vector(left.vector_part(), step.vector_part(), 1e-9),
        "compose: {:?}; stepwise: {:?}", left.vector_part(), step.vector_part()
    );
}
