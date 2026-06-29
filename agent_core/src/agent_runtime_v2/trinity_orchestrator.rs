//! TRINITY orchestrator — the single internal entry that composes the loop (slice 1) + heuristic executor
//! (slice 2/2b) + JSONL trace persistence (slice 3) into one callable (owner 2026-06-22; the UNIFICATION verdict
//! "wire trinity_loop in as System G's coordinator core" — this is its pure API surface). The model call is the
//! INJECTED generator `(tier, prompt) -> String`; slice 2c supplies the real OpenAI-compat provider-boundary
//! generator + the heuristic→learned router drop-in, and the System-G/act/work/chat call sites invoke `run_mission`.
//! Kept generator-injected so the whole orchestrator is cargo-testable without a live provider.

use std::path::PathBuf;
use std::sync::Arc;

use crate::model_profile::CapabilityTier;
use crate::provider::AgentProvider;
use crate::types::TokenUsage;

use super::trinity_async::run_trinity_loop_async;
use super::trinity_executor::HeuristicTrinityExecutor;
use super::trinity_loop::{run_trinity_loop, TrinityLoopOutcome, DEFAULT_MAX_ROUNDS};
use super::trinity_provider::ProviderTrinityExecutor;
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

    Ok(TrinityMissionResult {
        outcome,
        trace_path,
        router_mode: ACTIVE_ROUTER_MODE,
    })
}

/// Result of one async (real-provider) TRINITY mission — the loop outcome plus the run's honest COST basis.
#[derive(Debug)]
pub struct TrinityAsyncMissionResult {
    pub outcome: TrinityLoopOutcome,
    pub trace_path: Option<PathBuf>,
    pub router_mode: TrinityRouterMode,
    /// Accumulated token usage across all role calls (Thinker/Worker/Verifier × rounds).
    pub total_usage: TokenUsage,
    /// Number of provider requests made (one per role turn) — the `request_count` for per-request pricing.
    pub total_calls: u32,
}

/// Run one TRINITY coordination mission over a REAL async provider boundary — the path System G / act / work /
/// chat invoke (the sync `run_mission` is for the injected-generator pure path). `provider_for_tier` resolves a
/// provider per role tier (the app's model resolution via `select_model_for_tier` + provider construction). The
/// result carries the honest cost basis (`total_usage` / `total_calls`) so callers cost it via
/// `pricing::estimate_session_cost_usd` — no hidden expensive runs. Trace persisted atomically when `trace_dir`
/// is Some (a write failure is an honest Err).
pub async fn run_mission_async<F>(
    objective: &str,
    trace_dir: Option<&std::path::Path>,
    provider_for_tier: F,
) -> Result<TrinityAsyncMissionResult, String>
where
    F: Fn(CapabilityTier) -> Arc<dyn AgentProvider> + Send + Sync,
{
    let mut exec = ProviderTrinityExecutor::new(objective, provider_for_tier);
    let outcome = run_trinity_loop_async(objective, DEFAULT_MAX_ROUNDS, &mut exec).await;

    let trace_path = if let Some(dir) = trace_dir {
        let hash = blake3::hash(objective.as_bytes()).to_hex().to_string();
        let path = dir.join(format!("trinity-{}.jsonl", &hash[..16]));
        write_trace_jsonl(&outcome.trace, &path)?;
        Some(path)
    } else {
        None
    };

    Ok(TrinityAsyncMissionResult {
        outcome,
        trace_path,
        router_mode: ACTIVE_ROUTER_MODE,
        total_usage: exec.total_usage().clone(),
        total_calls: exec.total_calls(),
    })
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
        assert_eq!(
            result.router_mode,
            super::super::trinity_routing::TrinityRouterMode::Heuristic
        );
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

    // --- async (real-provider) orchestrator entry ---

    use crate::agent_loop::{AgentConfig, AgentError};
    use crate::provider::{MessageStream, ProviderCapabilities, StreamEvent};
    use crate::types::{Message, StopReason, ToolSchema};

    struct AcceptMock;
    #[async_trait::async_trait]
    impl AgentProvider for AcceptMock {
        async fn stream_message(
            &self,
            messages: &[Message],
            _t: &[ToolSchema],
            _c: &AgentConfig,
        ) -> Result<MessageStream, AgentError> {
            let reply = if format!("{messages:?}").contains("Reply with exactly") {
                "ACCEPT"
            } else {
                "out"
            };
            let usage = TokenUsage {
                input_tokens: 4,
                output_tokens: 2,
                ..Default::default()
            };
            Ok(Box::pin(futures::stream::iter(vec![
                Ok(StreamEvent::TextDelta {
                    index: 0,
                    text: reply.into(),
                }),
                Ok(StreamEvent::MessageStop {
                    stop_reason: StopReason::EndTurn,
                    usage,
                }),
            ])))
        }
        async fn compact(&self, m: &[Message]) -> Result<Vec<Message>, AgentError> {
            Ok(m.to_vec())
        }
        fn capabilities(&self) -> ProviderCapabilities {
            ProviderCapabilities {
                max_context_tokens: 8192,
                max_output_tokens: 2048,
                supports_thinking: false,
                supports_vision: false,
                supports_web_search: false,
                supports_code_execution: false,
                supports_computer_use: false,
                supports_mcp: false,
                supports_streaming: true,
                supports_compaction: false,
                cost_input_per_million: 0.0,
                cost_output_per_million: 0.0,
            }
        }
        fn name(&self) -> &'static str {
            "accept-mock"
        }
    }

    #[tokio::test]
    async fn run_mission_async_runs_a_real_provider_and_reports_cost() {
        let provider: Arc<dyn AgentProvider> = Arc::new(AcceptMock);
        let provider_for_tier = move |_tier: CapabilityTier| provider.clone();
        let result = run_mission_async("compute 2+2", None, provider_for_tier)
            .await
            .unwrap();
        assert!(result.outcome.accepted);
        assert_eq!(result.outcome.final_answer, "out");
        assert_eq!(result.router_mode, TrinityRouterMode::Heuristic);
        // accept-round-1 = 3 calls × 4in/2out → honest cost basis.
        assert_eq!(result.total_calls, 3);
        assert_eq!(result.total_usage.input_tokens, 12);
        assert_eq!(result.total_usage.output_tokens, 6);
    }
}
