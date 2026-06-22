//! TRINITY orchestrator — slice 2: HEURISTIC role→model-tier selection (owner 2026-06-22, "heuristic-route
//! FIRST"). The reference's learned coordination head picks an agent per subtask from a Qwen3-0.6B hidden state;
//! until that's built + license-cleared (later slices), the orchestrator routes each Thinker/Worker/Verifier
//! role to a model TIER via the EXISTING heuristic classifier (`routing::HeuristicClassifier` → complexity/code/
//! shell signals) mapped onto the app's real `CapabilityTier` (Fast/Think/Code). Pure + cargo-tested; the actual
//! model id + provider call resolve at the call site (RuntimeRouter / provider boundary). The learned router is a
//! clean DROP-IN replacement for `heuristic_role_tier` later — same (role, objective) → tier contract.

use crate::model_profile::CapabilityTier;
use crate::routing::{ClassificationResult, HeuristicClassifier};

use super::trinity_loop::TrinityRole;

/// Map a TRINITY role + a task classification to the capability tier that role should run on.
/// - **Thinker** (plan / decompose) and **Verifier** (judge / accept-or-repair) are REASONING work → `Think`.
/// - **Worker** (execute) routes by the task: `Code` for shell/code work, `Think` for hard non-code work,
///   `Fast` for simple work. Mirrors "route the right model to each subtask" with the available tiers.
pub fn heuristic_role_tier(role: TrinityRole, classification: &ClassificationResult) -> CapabilityTier {
    match role {
        TrinityRole::Thinker | TrinityRole::Verifier => CapabilityTier::Think,
        TrinityRole::Worker => {
            if classification.shell_required {
                CapabilityTier::Code
            } else if classification.complexity >= 0.6 {
                CapabilityTier::Think
            } else {
                CapabilityTier::Fast
            }
        }
    }
}

/// Convenience: classify `objective` with the heuristic classifier, then select the role's tier. This is the
/// single entry the slice-2 executor calls per role; the learned router replaces it wholesale later.
pub fn select_role_tier(role: TrinityRole, objective: &str) -> CapabilityTier {
    let classification = HeuristicClassifier.classify(objective);
    heuristic_role_tier(role, &classification)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn classification(complexity: f32, shell: bool) -> ClassificationResult {
        ClassificationResult {
            complexity,
            tool_count_estimate: 0,
            requires_current_info: false,
            privacy_sensitive: false,
            shell_required: shell,
            research_related: false,
        }
    }

    #[test]
    fn thinker_and_verifier_always_reason() {
        for c in [classification(0.05, false), classification(1.0, true)] {
            assert_eq!(heuristic_role_tier(TrinityRole::Thinker, &c), CapabilityTier::Think);
            assert_eq!(heuristic_role_tier(TrinityRole::Verifier, &c), CapabilityTier::Think);
        }
    }

    #[test]
    fn worker_routes_code_then_complexity_then_fast() {
        // shell/code work → Code, regardless of complexity.
        assert_eq!(heuristic_role_tier(TrinityRole::Worker, &classification(0.1, true)), CapabilityTier::Code);
        // hard non-code work → Think.
        assert_eq!(heuristic_role_tier(TrinityRole::Worker, &classification(0.8, false)), CapabilityTier::Think);
        // simple non-code work → Fast.
        assert_eq!(heuristic_role_tier(TrinityRole::Worker, &classification(0.2, false)), CapabilityTier::Fast);
    }

    #[test]
    fn select_role_tier_classifies_real_objectives() {
        // a code/shell objective routes the Worker to Code.
        assert_eq!(
            select_role_tier(TrinityRole::Worker, "write a bash script to build the project"),
            CapabilityTier::Code
        );
        // a trivial objective routes the Worker to Fast…
        assert_eq!(select_role_tier(TrinityRole::Worker, "say hi"), CapabilityTier::Fast);
        // …while the Thinker always reasons.
        assert_eq!(select_role_tier(TrinityRole::Thinker, "say hi"), CapabilityTier::Think);
    }
}
