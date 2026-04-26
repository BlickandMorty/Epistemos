//! W8.4.e stub — Reciprocal Rank Fusion.
//!
//! Filled in by the W8.4.e commit. Pure function, ~30 LOC:
//!
//!   pub fn rrf_fuse(
//!       dense:   &[(String, f32)],
//!       lexical: &[(String, f32)],
//!       k:       usize,         // typically 60
//!       limit:   usize,
//!   ) -> Vec<(String, f32)>;
//!
//! Implements `score(d) = Σ 1/(k + rank_i(d))` per the canonical
//! Cormack/Clarke/Büttcher SIGIR 2009 paper. k=60 is the
//! original-pilot-study constant; anywhere in `[20, 100]` MAP barely
//! moves so we pick the canonical default.
//!
//! No I/O, fully unit-testable in isolation. The W8.4.e tests pin:
//!   - rrf_fuses_dense_and_lexical
//!   - rrf_handles_empty_dense_path
//!   - rrf_handles_empty_lexical_path

#![allow(dead_code)]
