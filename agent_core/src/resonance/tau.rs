//! τ — Kleene K3 ternary truth value.
//!
//! Per doctrine §4.1 + Annex A.4 (six mathematical pillars under the
//! Gate, pillar 1): "Kleene K3 ternary logic for τ." The third value
//! `Unknown` is load-bearing — collapsing to a `bool` would lose the
//! distinction between "we have evidence against" (False) and "we
//! haven't accumulated evidence yet" (Unknown), which downstream
//! consumers (Evidence Supremacy Protocol, Sovereign Gate) depend on.

use crate::resonance::{Claim, ClaimType};
use serde::{Deserialize, Serialize};

/// Kleene K3 ternary truth value. The integer encoding (-1, 0, +1)
/// matches the donor-research `ResonanceSignature.ternary: i8` field
/// so a future FFI surface can serialize a signature as primitives.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum Truth {
    /// τ = +1 — claim is supported.
    True,
    /// τ = 0 — claim is not yet decidable from current evidence.
    Unknown,
    /// τ = -1 — claim is contradicted. Doctrine §4.1 invariant 1:
    /// no token with τ = -1 reaches the user.
    False,
}

impl Truth {
    /// Integer encoding for FFI / serialization.
    pub const fn as_int(self) -> i8 {
        match self {
            Truth::True => 1,
            Truth::Unknown => 0,
            Truth::False => -1,
        }
    }

    /// Kleene K3 NOT.
    pub const fn not(self) -> Truth {
        match self {
            Truth::True => Truth::False,
            Truth::Unknown => Truth::Unknown,
            Truth::False => Truth::True,
        }
    }

    /// Kleene K3 AND. False is absorbing; Unknown propagates if the other
    /// operand is not False.
    pub const fn and(self, other: Truth) -> Truth {
        match (self, other) {
            (Truth::False, _) | (_, Truth::False) => Truth::False,
            (Truth::True, Truth::True) => Truth::True,
            _ => Truth::Unknown,
        }
    }

    /// Kleene K3 OR. True is absorbing; Unknown propagates if the other
    /// operand is not True.
    pub const fn or(self, other: Truth) -> Truth {
        match (self, other) {
            (Truth::True, _) | (_, Truth::True) => Truth::True,
            (Truth::False, Truth::False) => Truth::False,
            _ => Truth::Unknown,
        }
    }
}

/// Evaluate the τ component for a claim.
///
/// **Seed scope.** The Core seed evaluates a small set of decidable types
/// directly and defers the rest to `Unknown` for downstream T2+ verifiers.
/// Once Pro tier ships δ + ρ, those signals can promote `Unknown` toward
/// `True`/`False`. Once Research tier ships η, Engram-anchored claims
/// resolve immediately.
///
/// **Hot-path cost.** O(1) — single match arm + arithmetic on `evidence_count`.
pub fn evaluate_truth(claim: &Claim) -> Truth {
    match claim.kind {
        // Definitions are tautologically true within their own corpus.
        ClaimType::Definition => Truth::True,

        // Empirical claims promote on accumulating evidence. Threshold of 3
        // is the seed default; a future Pro slice may make this configurable
        // per ResonanceConfig.
        ClaimType::Empirical => {
            if claim.evidence_count >= 3 {
                Truth::True
            } else {
                Truth::Unknown
            }
        }

        // Composites without dependencies are structurally invalid (a
        // composite by definition is built from 2+ underlying claims).
        ClaimType::Composite if claim.dependencies.is_empty() => Truth::False,

        // CodeInvariants need a test runner; Equation/Inequality need a
        // T2+ solver. Both live off the hot path. Seed defers to Unknown.
        ClaimType::CodeInvariant
        | ClaimType::Equation
        | ClaimType::Inequality
        | ClaimType::Causal
        | ClaimType::Prime
        | ClaimType::Composite
        | ClaimType::Gap => Truth::Unknown,
    }
}
