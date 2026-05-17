//! # Geometry-IR — Clifford algebra / rotor sandwich substrate
//!
//! Source:
//! - Hestenes, Sobczyk, "Clifford Algebra to Geometric Calculus:
//!   A Unified Language for Mathematics and Physics", Reidel (1984),
//!   ISBN 978-90-277-1673-6. Ch. 1 — geometric-product axioms.
//! - Dorst, Fontijne, Mann, "Geometric Algebra for Computer Science",
//!   Morgan Kaufmann (2007), ISBN 978-0-12-369465-2. §10.3 rotor
//!   sandwich + computational algorithms.
//! - Doctrine `docs/fusion/PRIMITIVE_IR_STACK_DOCTRINE_2026_05_17.md`
//!   §2.6 + §4.6 — Geometry-IR primitive signature.
//! - Phase B5 close-out `docs/audits/PHASE_B5_CLOSEOUT_2026_05_17.md` §5
//!   — iter-42 plan entry.

//! ## Usage example
//!
//! Rotate a 3D vector by π/2 around the e_12 (xy) plane via rotor
//! sandwich. e_1 → e_2 (per the right-acting convention).
//!
//! ```
//! use agent_core::research::geometry_ir::{
//!     rotate, rotor_from_angle_and_bivector, Multivector,
//! };
//! use std::f64::consts::PI;
//!
//! let r = rotor_from_angle_and_bivector(PI / 2.0, 1.0, 0.0, 0.0);
//! let e1 = Multivector::vector(1.0, 0.0, 0.0);
//! let rotated = rotate(&e1, &r);
//!
//! let (x, y, z) = rotated.vector_part();
//! assert!(x.abs() < 1e-9);
//! assert!((y - 1.0).abs() < 1e-9);
//! assert!(z.abs() < 1e-9);
//! ```

pub mod certificate;
pub mod evaluator;
pub mod grammar;
pub mod rotor;

pub use certificate::lean_certificate as geometry_lean_certificate;
pub use evaluator::{
    angle_between_vectors, evaluate, geo_dot, geo_product, geo_wedge,
    multivector_anticommutator, multivector_commutator, multivector_dual,
    multivector_grade_norm, project_onto_bivector_plane, reflect_vector,
    reject_from_bivector_plane, scalar_triple_product, vector_cross_product,
    vector_inverse, vector_projection, vector_rejection,
};
pub use grammar::{GeoExpr, GeoExprError, Multivector};
pub use rotor::{
    apply_rotor, bivector_exp, bivector_log, rotate, rotor_compose,
    rotor_from_angle_and_bivector, rotor_power, rotor_slerp,
    rotor_from_two_vectors, rotor_identity, rotor_inverse,
    rotor_to_angle_and_bivector,
};
