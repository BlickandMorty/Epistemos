//! Resonance Gate τ + π + λ daemon — Core seed.
//!
//! This module is the **first piece of the visible Resonance Gate philosophy**
//! per `docs/fusion/EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md` §4.1. It is the
//! Core entry: τ (truth, Kleene K3 ternary), π (prime/composite/gap
//! classification over 9 typed claims), and λ (residency target L0–L3).
//!
//! ## Tier scope
//!
//! - **Core** (this module): τ + π + λ only. CPU-only, synchronous,
//!   no Z3 / Kani / Lean inline (they live off the hot path per Annex A.2).
//! - **Pro** (future, separate module): δ (direction, Koopman) +
//!   ρ (resonance, Laplace–Beltrami).
//! - **Research** (future, separate module): κ (KAM stability,
//!   Diophantine) + η (evidence, Engram + search).
//!
//! ## Hot-path target
//!
//! Doctrine §4.1 sets the per-token signature target at < 100 µs.
//! `compute_signature_core` is a pure function over a `Claim` value with
//! no allocations beyond what `Claim` itself owns.
//!
//! ## What is NOT here
//!
//! - No FFI surface (Swift consumer + UniFFI bridge are a separate slice).
//! - No `agent_loop.rs` integration (signature emission is also separate).
//! - No δ / ρ / κ / η scaffolding (Pro / Research only).
//! - No Z3 / Lean / Kani / Kissat calls (T2 ceiling per Annex A.2).
//! - No Metal / MLX / ANE imports (CPU-only seed).

pub mod lambda;
pub mod pi;
pub mod tau;

pub use lambda::{target_residency, ResidencyLevel};
pub use pi::{classify, ClaimClass, ClaimType};
pub use tau::{evaluate_truth, Truth};

/// Opaque reference to a previously-known claim. The Core seed treats this
/// as a u64 nonce; future tiers may attach a real claim graph identifier.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Ord, PartialOrd)]
pub struct ClaimRef(pub u64);

/// Input to the Resonance Gate τ + π + λ daemon.
///
/// The seed deliberately keeps the input tiny: a typed kind, a statement
/// (carried for downstream display + audit, not used by τ/π/λ math), a
/// dependency list (used by π for compositeness), and an evidence count
/// (used by τ + π for confidence).
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Claim {
    pub kind: ClaimType,
    pub statement: String,
    pub dependencies: Vec<ClaimRef>,
    pub evidence_count: u32,
}

/// Core-tier Resonance signature — the τ + π + λ subset of the full
/// 7-field Σ defined in doctrine §4.1.
///
/// Pro tier extends with `direction: Direction` + `resonance: f32`.
/// Research tier extends with `kam_stability: f32` + `evidence: EvidenceStatus`.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub struct ResonanceSignatureCore {
    pub truth: Truth,
    pub class: ClaimClass,
    pub residency: ResidencyLevel,
}

impl ResonanceSignatureCore {
    /// Whether this signature passes the doctrine §4.1 invariant 1: "no
    /// token with τ = -1 ever reaches the user." Used by downstream
    /// emission paths to short-circuit before display.
    pub const fn passes_truth_invariant(&self) -> bool {
        !matches!(self.truth, Truth::False)
    }

    /// Whether this signature is Core-allowed. Returns `false` for any
    /// Pro/Research-only residency level (L4–L6); a Core build that
    /// produces such a signature is a tier-leakage bug.
    pub const fn is_core_compatible(&self) -> bool {
        self.residency.is_core_allowed()
    }
}

/// Compute the Core-tier τ + π + λ signature for a claim.
///
/// **Pure function.** Same input → same output. No I/O. No async. No
/// allocation beyond what `Claim` already owns.
pub fn compute_signature_core(claim: &Claim) -> ResonanceSignatureCore {
    ResonanceSignatureCore {
        truth: evaluate_truth(claim),
        class: classify(claim),
        residency: target_residency(claim),
    }
}
