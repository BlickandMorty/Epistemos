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

pub mod evaluator;
pub mod grammar;
pub mod rotor;

pub use evaluator::{evaluate, geo_product};
pub use grammar::{GeoExpr, GeoExprError, Multivector};
pub use rotor::{rotate, rotor_compose, rotor_from_angle_and_bivector, rotor_identity};
