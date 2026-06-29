//! TRINITY orchestrator — slice 2c foundation: the ASYNC loop (owner 2026-06-22). The sync core (trinity_loop)
//! tests the pure logic, but a REAL coordination run calls models over an ASYNC provider boundary — a sync
//! generator can't await. This module mirrors the flat ≤5-round Thinker/Worker/Verifier loop with an ASYNC
//! executor so the real OpenAI-compat provider (AgentProvider, async) plugs in directly. Same roles, same
//! ACCEPT-termination + honest budget-exhaust, same `TrinityEvent` trace — only the role calls are awaited.
//! The streaming-provider→String adapter + RuntimeRouter model resolution are the final wiring (slice 2c).

use async_trait::async_trait;

use super::trinity_loop::{TrinityEvent, TrinityLoopOutcome, VerifierVerdict, DEFAULT_MAX_ROUNDS};

/// Async sibling of `TrinityRoleExecutor` — the role calls await a real model provider.
#[async_trait]
pub trait TrinityRoleExecutorAsync: Send {
    async fn think(&mut self, objective: &str, feedback: &str) -> String;
    async fn work(&mut self, plan: &str) -> String;
    async fn verify(&mut self, work: &str, objective: &str) -> (VerifierVerdict, String);
}

/// Async sibling of `run_trinity_loop`: identical orchestration (Thinker→Worker→Verifier rounds, ACCEPT-
/// terminate, honest budget-exhaust, full JSONL trace) with the role calls awaited so a real async provider can
/// serve them.
pub async fn run_trinity_loop_async(
    objective: &str,
    max_rounds: u32,
    exec: &mut dyn TrinityRoleExecutorAsync,
) -> TrinityLoopOutcome {
    let max_rounds = max_rounds.clamp(1, DEFAULT_MAX_ROUNDS);
    let mut trace = Vec::new();
    trace.push(TrinityEvent::LoopStarted {
        schema_version: 1,
        objective_hash: blake3::hash(objective.as_bytes()).to_hex().to_string(),
        max_rounds,
    });

    let mut feedback = String::new();
    let mut final_answer = String::new();
    let mut round = 0;
    let mut accepted = false;

    while round < max_rounds {
        round += 1;

        trace.push(TrinityEvent::ThinkerTurn { round });
        let plan = exec.think(objective, &feedback).await;

        trace.push(TrinityEvent::WorkerTurn { round });
        final_answer = exec.work(&plan).await;

        trace.push(TrinityEvent::VerifierTurn { round });
        let (verdict, next_feedback) = exec.verify(&final_answer, objective).await;
        match verdict {
            VerifierVerdict::Accept => {
                trace.push(TrinityEvent::VerifierAccept { round });
                accepted = true;
                break;
            }
            VerifierVerdict::Repair => {
                trace.push(TrinityEvent::VerifierRepair { round });
                feedback = next_feedback;
            }
        }
    }

    if !accepted {
        trace.push(TrinityEvent::BudgetExhausted { rounds: round });
    }
    trace.push(TrinityEvent::LoopCompleted {
        accepted,
        rounds: round,
    });

    TrinityLoopOutcome {
        accepted,
        rounds: round,
        final_answer,
        trace,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    struct AsyncScriptedExec {
        accept_on_round: u32,
        round: u32,
    }
    #[async_trait]
    impl TrinityRoleExecutorAsync for AsyncScriptedExec {
        async fn think(&mut self, _o: &str, _f: &str) -> String {
            self.round += 1;
            format!("plan-{}", self.round)
        }
        async fn work(&mut self, plan: &str) -> String {
            format!("work-from-{plan}")
        }
        async fn verify(&mut self, _w: &str, _o: &str) -> (VerifierVerdict, String) {
            if self.round >= self.accept_on_round {
                (VerifierVerdict::Accept, String::new())
            } else {
                (VerifierVerdict::Repair, "fix".into())
            }
        }
    }

    #[tokio::test]
    async fn async_loop_accepts_and_matches_the_sync_semantics() {
        let mut exec = AsyncScriptedExec {
            accept_on_round: 2,
            round: 0,
        };
        let out = run_trinity_loop_async("solve x", DEFAULT_MAX_ROUNDS, &mut exec).await;
        assert!(out.accepted);
        assert_eq!(out.rounds, 2);
        assert_eq!(out.final_answer, "work-from-plan-2");
        assert!(out
            .trace
            .contains(&TrinityEvent::VerifierAccept { round: 2 }));
        assert!(out
            .trace
            .contains(&TrinityEvent::VerifierRepair { round: 1 }));
    }

    #[tokio::test]
    async fn async_loop_budget_exhausts_honestly() {
        let mut exec = AsyncScriptedExec {
            accept_on_round: 99,
            round: 0,
        };
        let out = run_trinity_loop_async("x", DEFAULT_MAX_ROUNDS, &mut exec).await;
        assert!(!out.accepted);
        assert_eq!(out.rounds, DEFAULT_MAX_ROUNDS);
        assert!(out
            .trace
            .contains(&TrinityEvent::BudgetExhausted { rounds: 5 }));
    }

    #[tokio::test]
    async fn async_loop_clamps_max_rounds() {
        let mut exec = AsyncScriptedExec {
            accept_on_round: 99,
            round: 0,
        };
        let out = run_trinity_loop_async("x", 100, &mut exec).await;
        assert_eq!(out.rounds, DEFAULT_MAX_ROUNDS);
    }
}
