//! Active Assembly Runtime (AAR) substrate-floor.
//!
//! Source:
//! - Driver §4.G hierarchy: AAR = "NERVOUS SYSTEM — decides which packets /
//!   components / model mechanisms fire for the current state."
//! - Canonical doctrine `docs/fusion/UAS_ACS_CANONICAL_ARCHITECTURE_2026_05_16.md`
//!   §2 hierarchy + §5 register row #25.
//! - F-ActiveAssembly-Minimal falsifier `docs/falsifiers/F-ActiveAssembly-Minimal_2026_05_17.md`
//!   §2 (synthetic packet graph) + §3 (margin-anchored greedy-pull selector).
//! - Phase B blueprint `docs/audits/UAS_ACS_PHASE_B_BLUEPRINT_2026_05_17.md`
//!   §3 iters 51-58 → landed early at iter 37 (reordered; F-UAS-ZeroCopy
//!   paths 4/5/6 deferred to follow-up iters; this work is non-conflicting
//!   and self-contained).
//!
//! # Phase B.G.B6 — substrate-floor scope
//!
//! Lands the type surface that F-ActiveAssembly-Minimal exercises (gate #6
//! in the §4.G ladder). The harness lives in `agent_core/tests/active_
//! assembly_minimal.rs` (lands in a follow-up iter); this module exposes:
//!
//! - [`Packet`] — a single packet (id, input pattern, output pattern, cost).
//! - [`PacketGraph`] — a DAG of N packets with 1-4 predecessor edges each.
//!
//! Future iter follow-ups (per F-ActiveAssembly falsifier §3):
//!
//! - `MarginAnchoredGreedyPull` selector strategy.
//! - `GroundTruthQuerySet` synthetic query generator.
//! - Two-sided constraint test: output ≤ 4-bit Hamming AND cost-ratio < 0.40
//!   AND firing-ratio < 0.50.

pub mod packet;
pub mod selector;

pub use packet::{Packet, PacketGraph, PacketGraphError, PacketId};
pub use selector::{MarginAnchoredGreedyPull, Selector, SelectorError};
