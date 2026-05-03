//! π — prime / composite / gap classification over 9 typed claims.
//!
//! Per doctrine §4.1: "the Resonance Gate's prime/composite/gap
//! classification operates over 9 typed claims, not free-form strings."
//! The 9 input claim types are concrete (Equation/Inequality/Causal/
//! Definition/Empirical/CodeInvariant) and ontological (Prime/Composite/
//! Gap). The π output is one of three structural classes: Prime,
//! Composite, or Gap.
//!
//! ## Knowledge Sieve mechanics
//!
//! Per doctrine Annex A.13: the Knowledge Sieve "constructs the graph by
//! eliminating composites" and the Gap Winner Rule "ranks retrieval
//! sources by dependency depth." The seed implementation honors this by:
//!
//! - 0 dependencies + accumulated evidence → Prime (foundational)
//! - 2+ dependencies → Composite (built from primes)
//! - Anything in between → Gap (cannot decide yet)
//!
//! Pre-classified ontological inputs (Definition/Prime/Composite/Gap)
//! short-circuit to their declared class.

use crate::resonance::Claim;
use serde::{Deserialize, Serialize};

/// The 9 claim types per doctrine §4.1. Six concrete + three ontological.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum ClaimType {
    // Concrete (six)
    Equation,
    Inequality,
    Causal,
    Definition,
    Empirical,
    CodeInvariant,
    // Ontological (three) — pre-classify to the matching ClaimClass
    Prime,
    Composite,
    Gap,
}

impl ClaimType {
    /// All 9 variants, in doctrine order. Useful for exhaustiveness
    /// checks and parametric tests.
    pub const ALL: [ClaimType; 9] = [
        ClaimType::Equation,
        ClaimType::Inequality,
        ClaimType::Causal,
        ClaimType::Definition,
        ClaimType::Empirical,
        ClaimType::CodeInvariant,
        ClaimType::Prime,
        ClaimType::Composite,
        ClaimType::Gap,
    ];
}

/// The π output classification — three structural classes per
/// doctrine §4.1.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum ClaimClass {
    /// Foundational claim with no dependencies on other claims of this corpus.
    Prime,
    /// Built from two or more prime/composite claims.
    Composite,
    /// Cannot be classified yet — needs more evidence or a missing
    /// dependency. The Gap Winner Rule (Annex A.13) ranks Gap claims
    /// for retrieval prioritization.
    Gap,
}

/// Classify a claim into Prime / Composite / Gap.
///
/// **Hot-path cost.** O(1) — pre-classification short-circuit + a
/// length check on `dependencies`.
pub fn classify(claim: &Claim) -> ClaimClass {
    // Pre-classified ontological inputs short-circuit. Definitions are
    // also Prime by convention (axiomatic, no further dependency).
    match claim.kind {
        ClaimType::Definition | ClaimType::Prime => return ClaimClass::Prime,
        ClaimType::Composite => return ClaimClass::Composite,
        ClaimType::Gap => return ClaimClass::Gap,
        _ => {}
    }

    let dep_count = claim.dependencies.len();
    let has_evidence = claim.evidence_count > 0;

    match (dep_count, has_evidence) {
        // Foundational: no upstream deps, but we have direct evidence.
        (0, true) => ClaimClass::Prime,
        // Composite: built from at least two upstream claims.
        (n, _) if n >= 2 => ClaimClass::Composite,
        // Everything else (1 dep, or 0 deps + 0 evidence) is a Gap.
        _ => ClaimClass::Gap,
    }
}
