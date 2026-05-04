//! Helios core mathematical substrate.
//!
//! This crate intentionally avoids external dependencies in the first scaffold so
//! the core invariants remain audit-readable and portable. Platform-specific MLX,
//! Metal, UniFFI, and XPC code live in sibling crates.

pub mod inequality;
pub mod lattice;
pub mod plasticity;
pub mod prcda;
pub mod resonance;
pub mod sketch;
pub mod types;

pub use inequality::{InequalityError, WBOSix, WBOTerms};
pub use lattice::{babai_nearest_plane, quantize_to_lattice, CholeskyBasis, E8Codebook, LatticeType, LeechCodebook, QuantizedVector};
pub use plasticity::{PlasticityDecision, PlasticityGate, TernaryUpdate};
pub use prcda::{compute_surprise, Predictor, ResidualCheckpoint, SherryCodec, SherryPacked};
pub use resonance::{GateDecision, GatePolicy, ResonanceGate};
pub use sketch::{CountSketch, FRPBasis, SparseJLMatrix};
pub use types::{ClaimType, Direction, LearningMode, PageHeader, ResonanceSignature, TierState, TokenId};
