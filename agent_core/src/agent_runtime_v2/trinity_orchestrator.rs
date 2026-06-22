//! TRINITY orchestrator — the single internal entry that composes the loop (slice 1) + heuristic executor
//! (slice 2/2b) + JSONL trace persistence (slice 3) into one callable (owner 2026-06-22; the UNIFICATION verdict
//! "wire trinity_loop in as System G's coordinator core" — this is its pure API surface). The model call is the
//! INJECTED generator `(tier, prompt) -> String`; slice 2c supplies the real OpenAI-compat provider-boundary
//! generator + the heuristic→learned router drop-in, and the System-G/act/work/chat call sites invoke `run_mission`.
//! Kept generator-injected so the whole orchestrator is cargo-testable without a live provider.

use std::path::PathBuf;

use crate::model_profile::CapabilityTier;

use super::trinity_executor::HeuristicTrinityExecutor;
use super::trinity_loop::{run_trinity_loop, TrinityLoopOutcome, DEFAULT_MAX_ROUNDS};
use super::trinity_routing::{TrinityRouterMode, ACTIVE_ROUTER_MODE};
use super::trinity_trace::write_trace_jsonl;

/// Result of one orchestrated TRINITY mission.
#[derive(Debug)]
pub struct TrinityMissionResult {
    /// The loop outcome (accepted / rounds / final answer / in-memory trace).
    pub outcome: TrinityLoopOutcome,
    /// Where the JSONL trace was persisted, if a `trace_dir` was configured (else None).
    pub trace_path: Option<PathBuf>,
    /// Which router produced the role→model decisions — disclosed HONESTLY (heuristic now; learned is
    /// license/MLX-tap gated). A UI/trace surfaces this so the user knows it's the heuristic, not the learned head.
    pub router_mode: TrinityRouterMode,
}

/// Run one TRINITY coordination mission for `objective` using the injected `generate`. Heuristic routing selects
/// each role's tier; the flat ≤`DEFAULT_MAX_ROUNDS` Thinker/Worker/Verifier loop runs to a Verifier ACCEPT (or
/// honest budget-exhaust). When `trace_dir` is Some, the JSONL trace is persisted atomically as
/// `<trace_dir>/trinity-<objective_hash>.jsonl` (honest, replayable provenance). Trace-write failure is HONEST:
/// it surfaces as `Err` rather than silently dropping the provenance trail.
pub fn run_mission<G: FnMut(CapabilityTier, &str) -> String>(
    objective: &str,
    trace_dir: Option<&std::path::Path>,
    generate: G,
) -> Result<TrinityMissionResult, String> {
    let mut exec = HeuristicTrinityExecutor::new(objective, generate);
    let outcome = run_trinity_loop(objective, DEFAULT_MAX_ROUNDS, &mut exec);

    let trace_path = if let Some(dir) = trace_dir {
        let hash = blake3::hash(objective.as_bytes()).to_hex().to_string();
        let path = dir.join(format!("trinity-{}.jsonl", &hash[..16]));
        write_trace_jsonl(&outcome.trace, &path)?;
        Some(path)
    } else {
        None
    };

    Ok(TrinityMissionResult { outcome, trace_path, router_mode: ACTIVE_ROUTER_MODE })
}

#[cfg(test)]
mod tests {
    use super::*;

    /// A generator that accepts immediately (Verifier prompt → "ACCEPT").
    fn accepting() -> impl FnMut(CapabilityTier, &str) -> String {
        |_tier, prompt: &str| {
            if prompt.contains("Reply with exactly") {
                "ACCEPT".into()
            } else if prompt.starts_with("Execute this plan") {
                "final answer".into()
            } else {
                "plan".into()
            }
        }
    }

    #[test]
    fn run_mission_without_trace_dir_runs_to_accept() {
        let result = run_mission("compute 2+2", None, accepting()).unwrap();
        assert!(result.outcome.accepted);
        assert_eq!(result.outcome.rounds, 1);
        assert_eq!(result.outcome.final_answer, "final answer");
        assert!(result.trace_path.is_none());
        // honest router disclosure: heuristic (not the not-yet-built learned head).
        assert_eq!(result.router_mode, super::super::trinity_routing::TrinityRouterMode::Heuristic);
    }

    #[test]
    fn run_mission_persists_the_jsonl_trace_when_a_dir_is_given() {
        let dir = tempfile::tempdir().unwrap();
        let result = run_mission("compute 2+2", Some(dir.path()), accepting()).unwrap();
        let path = result.trace_path.expect("trace persisted");
        assert!(path.exists());
        let body = std::fs::read_to_string(&path).unwrap();
        // the persisted trace is the same events the outcome carries (honest, complete).
        let reparsed = super::super::trinity_trace::trace_from_jsonl(&body).unwrap();
        assert_eq!(reparsed, result.outcome.trace);
    }

    #[test]
    fn run_mission_honestly_budget_exhausts_when_never_accepted() {
        // Verifier never accepts → honest not-accepted after the round cap.
        let never = |_tier: CapabilityTier, prompt: &str| -> String {
            if prompt.contains("Reply with exactly") {
                "REPAIR: still wrong".into()
            } else if prompt.starts_with("Execute this plan") {
                "attempt".into()
            } else {
                "plan".into()
            }
        };
        let result = run_mission("hard problem", None, never).unwrap();
        assert!(!result.outcome.accepted);
        assert_eq!(result.outcome.rounds, DEFAULT_MAX_ROUNDS);
    }
}
