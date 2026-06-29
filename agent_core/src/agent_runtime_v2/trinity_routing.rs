//! TRINITY orchestrator — slice 2: HEURISTIC role→model-tier selection (owner 2026-06-22, "heuristic-route
//! FIRST"). The reference's learned coordination head picks an agent per subtask from a Qwen3-0.6B hidden state;
//! until that's built + license-cleared (later slices), the orchestrator routes each Thinker/Worker/Verifier
//! role to a model TIER via the EXISTING heuristic classifier (`routing::HeuristicClassifier` → complexity/code/
//! shell signals) mapped onto the app's real `CapabilityTier` (Fast/Think/Code). Pure + cargo-tested; the actual
//! model id + provider call resolve at the call site (RuntimeRouter / provider boundary). The learned router is a
//! clean DROP-IN replacement for `heuristic_role_tier` later — same (role, objective) → tier contract.

use crate::model_profile::{CapabilityTier, ModelCapabilityProfile, CANON};
use crate::routing::{ClassificationResult, HeuristicClassifier};

use super::trinity_loop::TrinityRole;

/// Which router produced a coordination run's role→model decisions — disclosed HONESTLY (owner 2026-06-22:
/// "heuristic vs learned router state disclosed honestly"). The reference's LEARNED coordination head (a
/// Qwen3-0.6B hidden-state tap → biasless 1024→10 head) is license-gated (the adapted-weights bundle has no
/// declared license — owner H1) AND needs the net-new MLX hidden-state tap, so until both land the orchestrator
/// runs on the HEURISTIC router. `ACTIVE_ROUTER_MODE` is the single source of truth a UI/trace reports.
#[derive(Clone, Copy, Debug, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TrinityRouterMode {
    /// Existing complexity/code heuristic over CapabilityTier (live now).
    Heuristic,
    /// The reference's learned coordination head (license + MLX-tap gated; a clean drop-in when both clear).
    Learned,
}

impl TrinityRouterMode {
    pub const fn wire_tag(self) -> &'static str {
        match self {
            Self::Heuristic => "heuristic",
            Self::Learned => "learned",
        }
    }
}

/// The router the orchestrator is ACTUALLY using right now — heuristic, honestly (no fake "learned" claim).
/// Flips to `Learned` only when the learned-head slice lands AND its weights are license-cleared.
pub const ACTIVE_ROUTER_MODE: TrinityRouterMode = TrinityRouterMode::Heuristic;

/// Map a TRINITY role + a task classification to the capability tier that role should run on.
/// - **Thinker** (plan / decompose) and **Verifier** (judge / accept-or-repair) are REASONING work → `Think`.
/// - **Worker** (execute) routes by the task: `Code` for shell/code work, `Think` for hard non-code work,
///   `Fast` for simple work. Mirrors "route the right model to each subtask" with the available tiers.
pub fn heuristic_role_tier(
    role: TrinityRole,
    classification: &ClassificationResult,
) -> CapabilityTier {
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

/// Resolve a TIER to a concrete LOCAL model from the canonical profile table (`model_profile::CANON`), among
/// the `available_ids` (installed/runnable) — the piece the real provider executor needs to turn a TRINITY
/// role's tier into a model to call. LOCAL-FIRST (owner mandate; Fugu/cloud are pool members, not the brain):
/// resolves only from the local CANON here. Prefers an ADVERTISED model of the tier, else any available one;
/// returns None when no available local model serves the tier (the caller decides escalation HONESTLY — never
/// a silent wrong-tier swap).
pub fn select_model_for_tier(
    tier: CapabilityTier,
    available_ids: &[String],
) -> Option<ModelCapabilityProfile> {
    let avail = |p: &ModelCapabilityProfile| available_ids.iter().any(|id| id == p.id);
    let matches = |p: &&ModelCapabilityProfile| p.tier == tier && avail(p);
    CANON
        .iter()
        .find(|p| matches(p) && p.advertised)
        .or_else(|| CANON.iter().find(matches))
        .copied()
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
            assert_eq!(
                heuristic_role_tier(TrinityRole::Thinker, &c),
                CapabilityTier::Think
            );
            assert_eq!(
                heuristic_role_tier(TrinityRole::Verifier, &c),
                CapabilityTier::Think
            );
        }
    }

    #[test]
    fn worker_routes_code_then_complexity_then_fast() {
        // shell/code work → Code, regardless of complexity.
        assert_eq!(
            heuristic_role_tier(TrinityRole::Worker, &classification(0.1, true)),
            CapabilityTier::Code
        );
        // hard non-code work → Think.
        assert_eq!(
            heuristic_role_tier(TrinityRole::Worker, &classification(0.8, false)),
            CapabilityTier::Think
        );
        // simple non-code work → Fast.
        assert_eq!(
            heuristic_role_tier(TrinityRole::Worker, &classification(0.2, false)),
            CapabilityTier::Fast
        );
    }

    #[test]
    fn active_router_mode_is_honestly_heuristic() {
        // Until the learned head + its license-cleared weights land, the orchestrator must HONESTLY report
        // heuristic — never claim "learned".
        assert_eq!(ACTIVE_ROUTER_MODE, TrinityRouterMode::Heuristic);
        assert_eq!(TrinityRouterMode::Heuristic.wire_tag(), "heuristic");
        assert_eq!(TrinityRouterMode::Learned.wire_tag(), "learned");
        // serializes to a snake_case tag for the trace/UI.
        assert_eq!(
            serde_json::to_string(&ACTIVE_ROUTER_MODE).unwrap(),
            "\"heuristic\""
        );
    }

    #[test]
    fn select_model_for_tier_resolves_local_and_prefers_advertised() {
        use crate::model_profile::CANON;
        // Derive available ids from CANON so the test is robust to table changes.
        let think_ids: Vec<String> = CANON
            .iter()
            .filter(|p| p.tier == CapabilityTier::Think)
            .map(|p| p.id.to_string())
            .collect();
        if let Some(picked) = select_model_for_tier(CapabilityTier::Think, &think_ids) {
            assert_eq!(picked.tier, CapabilityTier::Think, "resolves a Think model");
            // if any advertised Think model exists, the pick is advertised.
            if CANON
                .iter()
                .any(|p| p.tier == CapabilityTier::Think && p.advertised)
            {
                assert!(picked.advertised, "prefers an advertised model of the tier");
            }
        }
        // No available model of the tier → None (honest: caller escalates, never a silent wrong-tier swap).
        assert!(
            select_model_for_tier(CapabilityTier::Think, &["not-a-real-model".to_string()])
                .is_none()
        );
        assert!(select_model_for_tier(CapabilityTier::Think, &[]).is_none());
    }

    #[test]
    fn select_role_tier_classifies_real_objectives() {
        // a code/shell objective routes the Worker to Code.
        assert_eq!(
            select_role_tier(
                TrinityRole::Worker,
                "write a bash script to build the project"
            ),
            CapabilityTier::Code
        );
        // a trivial objective routes the Worker to Fast…
        assert_eq!(
            select_role_tier(TrinityRole::Worker, "say hi"),
            CapabilityTier::Fast
        );
        // …while the Thinker always reasons.
        assert_eq!(
            select_role_tier(TrinityRole::Thinker, "say hi"),
            CapabilityTier::Think
        );
    }
}
