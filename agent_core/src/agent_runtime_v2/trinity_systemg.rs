//! TRINITY ↔ System G reconciliation (owner 2026-06-22, "GO BACK + HARDEN + UNIFY the already-started TRINITY/
//! System G code with the unification verdict"). The verdict: System G is the ONE orchestrator and the TRINITY
//! loop is its coordinator core. This bridge maps a TRINITY coordination run onto the EXISTING System G wire
//! events (`SystemGAgentEvent`) — so a future TRINITY-mode `start_run` emits the same event stream the Swift
//! `SystemGRunSeam` already decodes. CRITICAL (hardened + additive-safe): it uses ONLY existing variants — the
//! Rust/Swift event mirrors move in LOCKSTEP, and a new variant would break the Swift decoder; mapping onto the
//! current set keeps the reconciliation additive (no Swift change, no break to the hardened seam). This module
//! is the tested reconciliation primitive; wiring it into the live `start_run` behind the TRINITY flag is the
//! integration step (harden-before-integrate: built + tested here first).

use super::system_g_runtime::SystemGAgentEvent;
use super::trinity_orchestrator::TrinityAsyncMissionResult;

/// Map a completed TRINITY mission to the System G event sequence for `turn_id`:
/// `PlanStart` (coordination summary) → `TokenChunk` (the final answer, if any) → terminal `Complete`
/// (accepted) or `Failed` (honest budget-exhaust). HONEST: a not-accepted run is `Failed`, never a fake
/// `Complete` — the user sees the coordination didn't converge. `answer_packet_id` is a stable BLAKE3 of the
/// final answer (the V1 seam likewise uses a content-derived id).
pub fn trinity_to_system_g_events(
    result: &TrinityAsyncMissionResult,
    turn_id: &str,
) -> Vec<SystemGAgentEvent> {
    let rounds = result.outcome.rounds;
    let plan = format!(
        "TRINITY coordination ({} router, {} round{})",
        result.router_mode.wire_tag(),
        rounds,
        if rounds == 1 { "" } else { "s" }
    );
    let mut events = vec![SystemGAgentEvent::PlanStart {
        turn_id: turn_id.to_string(),
        plan,
    }];

    if !result.outcome.final_answer.is_empty() {
        events.push(SystemGAgentEvent::TokenChunk {
            turn_id: turn_id.to_string(),
            text: result.outcome.final_answer.clone(),
        });
    }

    if result.outcome.accepted {
        let answer_packet_id = blake3::hash(result.outcome.final_answer.as_bytes())
            .to_hex()
            .to_string();
        events.push(SystemGAgentEvent::Complete {
            turn_id: turn_id.to_string(),
            answer_packet_id,
        });
    } else {
        events.push(SystemGAgentEvent::Failed {
            turn_id: turn_id.to_string(),
            error: format!(
                "TRINITY budget exhausted after {rounds} rounds without a verifier ACCEPT"
            ),
        });
    }
    events
}

#[cfg(test)]
mod tests {
    use super::super::trinity_loop::TrinityLoopOutcome;
    use super::super::trinity_routing::TrinityRouterMode;
    use super::*;
    use crate::types::TokenUsage;

    fn result(accepted: bool, rounds: u32, answer: &str) -> TrinityAsyncMissionResult {
        TrinityAsyncMissionResult {
            outcome: TrinityLoopOutcome {
                accepted,
                rounds,
                final_answer: answer.to_string(),
                trace: vec![],
            },
            trace_path: None,
            router_mode: TrinityRouterMode::Heuristic,
            total_usage: TokenUsage::default(),
            total_calls: rounds * 3,
        }
    }

    #[test]
    fn accepted_run_maps_to_planstart_tokenchunk_complete() {
        let events = trinity_to_system_g_events(&result(true, 2, "the answer"), "turn-1");
        assert_eq!(events.len(), 3);
        match &events[0] {
            SystemGAgentEvent::PlanStart { plan, turn_id } => {
                assert_eq!(turn_id, "turn-1");
                assert!(plan.contains("heuristic") && plan.contains("2 rounds"));
            }
            other => panic!("expected PlanStart, got {other:?}"),
        }
        assert!(
            matches!(&events[1], SystemGAgentEvent::TokenChunk { text, .. } if text == "the answer")
        );
        assert!(matches!(&events[2], SystemGAgentEvent::Complete { .. }));
        assert!(events.last().unwrap().is_terminal());
    }

    #[test]
    fn budget_exhausted_run_is_failed_not_a_fake_complete() {
        let events = trinity_to_system_g_events(&result(false, 5, "best effort"), "t");
        // honest: terminal event is Failed, never Complete.
        assert!(matches!(
            events.last(),
            Some(SystemGAgentEvent::Failed { .. })
        ));
        assert!(!events
            .iter()
            .any(|e| matches!(e, SystemGAgentEvent::Complete { .. })));
        if let Some(SystemGAgentEvent::Failed { error, .. }) = events.last() {
            assert!(error.contains("5 rounds"));
        }
    }

    #[test]
    fn empty_answer_omits_the_token_chunk() {
        let events = trinity_to_system_g_events(&result(true, 1, ""), "t");
        // PlanStart + Complete only (no empty TokenChunk).
        assert_eq!(events.len(), 2);
        assert!(matches!(events[0], SystemGAgentEvent::PlanStart { .. }));
        assert!(matches!(events[1], SystemGAgentEvent::Complete { .. }));
        assert_eq!(
            events
                .iter()
                .filter(|e| matches!(e, SystemGAgentEvent::TokenChunk { .. }))
                .count(),
            0
        );
    }

    #[test]
    fn rounds_singular_plural_grammar() {
        let one = trinity_to_system_g_events(&result(true, 1, "a"), "t");
        assert!(
            matches!(&one[0], SystemGAgentEvent::PlanStart { plan, .. } if plan.contains("1 round)"))
        );
    }
}
