//! `helios-bench` — Empirical validation layer for the Epistenos system.
//!
//! This crate provides comprehensive benchmark suites that validate the Helios
//! architecture through real measurement, statistical rigor, and deterministic
//! testing. The benchmark hierarchy mirrors the six gates of the system:
//!
//! | Gate | Benchmark | Validates |
//! |------|-----------|-----------|
//! | G1   | `g1_kv_direct`     | KV-Direct reconstruction fidelity vs exact KV |
//! | G2   | `g2_recall`        | Long-context recall at 4K/32K/128K tokens |
//! | G3   | `g3_memory`        | Memory tier compression & query performance |
//! | G4   | `g4_determinism`   | Seeded replay determinism |
//! | G5   | `g5_self_tuning`   | Titans-MAC coherence & bounded drift |
//! | G6   | `g6_vault_security`| Biometric gate, HMAC tokens, permission boundaries |
//!
//! Each benchmark produces JSONL output suitable for regression tracking and
//! CI integration. Statistical summaries include confidence intervals, not just
//! point estimates.

#![warn(missing_docs)]
#![warn(rust_2018_idioms)]

pub mod g1_kv_direct;
pub mod g2_recall;
pub mod g3_memory;
pub mod g4_determinism;
pub mod g5_self_tuning;
pub mod g6_vault_security;
pub mod metrics;

pub use metrics::*;
