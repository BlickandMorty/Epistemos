//! # Scan-IR — recurrence / SSM / Mamba-2 / linear-attention substrate
//!
//! Source:
//! - Dao, Gu, "Transformers are SSMs: Generalized Models and Efficient
//!   Algorithms Through Structured State Space Duality", arXiv:2405.21060
//!   (ICML 2024). §6 the SSD algorithm — the canonical parallel-block
//!   scan that this IR's lowering targets.
//! - Blelloch, "Prefix Sums and Their Applications", CMU-CS-90-190
//!   (1990). The associative-operator-over-monoid abstraction.
//! - Doctrine §2.3 + §4.3 — Scan-IR primitive signature + lowering plan.
//! - Phase B2 close-out `docs/audits/PHASE_B2_CLOSEOUT_2026_05_17.md` §6
//!   — iter-24 plan entry.
//!
//! ## T3 coordination
//!
//! Per driver SCOPE LOCK: this module is **coord T3 for F-SemiseparableBlockScan-
//! Correctness**. Scan-IR exports the typed AST [`grammar::ScanProgram`] +
//! the associativity-certificate emitter (Phase B3 iter-28). T3 owns the
//! falsifier oracle (a Dao/Gu reference SSD implementation + a fixture
//! sequence). Iter-26 lowering + iter-27 integration test is the
//! handoff window.

pub mod evaluator;
pub mod grammar;
pub mod lowering;

pub use evaluator::{sequential_reduce, sequential_scan};
pub use grammar::ScanProgram;
pub use lowering::ssd_block_scan;
