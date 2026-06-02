//! R3 (2026-05-23): integration tests for
//! `agent_core::agent_runtime_v2::MissionRun`.
//!
//! Pins the atomicity contract that justifies the helper's existence:
//! - Budget rejection → NOTHING appended to the run log.
//! - Budget acceptance → BOTH SealedMutation AND LedgerSnapshot
//!   appended, in that order, before returning.
//! - `finalize()` reflects the accumulated ledger + log state into the
//!   resulting AnswerPacket without losing any field.
//!
//! Tests live in `agent_core/tests/` rather than the inline
//! `agent_runtime_v2::mission_run::tests` module because of pre-existing
//! lib-test breakage in `tools_v2`/`cache::mod`/`skill_discovery`
//! documented on PR #37. Same pattern as PRs #39, #41, #43.

use agent_core::agent_runtime_v2::{
    AgentBlueprintId, AgentEvent, BudgetDebit, BudgetError, BudgetLedger, BudgetSpec, Citation,
    MissionRun, StopReason,
};
use agent_core::cognitive_dag::node::Hash;

fn tight_spec() -> BudgetSpec {
    BudgetSpec {
        max_tokens: 100,
        max_wall_ms: 60_000,
        max_tool_calls: 10,
        max_subprocess_ms: 0,
        max_memory_bytes: 0,
    }
}

fn cap() -> Hash {
    Hash::from_bytes([7u8; 32])
}

fn debit_tokens(tokens: u64) -> BudgetDebit {
    BudgetDebit {
        tokens,
        wall_ms: 0,
        tool_calls: 0,
        subprocess_ms: 0,
        memory_bytes: 0,
    }
}

/// Fresh `MissionRun` exposes a zero ledger, empty log, and pinned
/// blueprint id + budget spec.
#[test]
fn mission_run_new_starts_empty_and_carries_blueprint_id_and_spec() {
    let run = MissionRun::new(AgentBlueprintId("blueprint-fresh".into()), tight_spec());
    assert_eq!(run.ledger(), BudgetLedger::default());
    assert_eq!(run.budget_spec(), tight_spec());
    assert_eq!(run.blueprint_id().0, "blueprint-fresh");
    assert!(run.run_event_log().is_empty());
}

/// A successful sealed mutation appends BOTH entries (sealed mutation
/// AND ledger snapshot) in that order, and returns their ordinals.
/// The ledger updates to reflect the debit. Subsequent successful
/// mutations stack the ledger correctly.
#[test]
fn mission_run_gate_success_appends_both_entries_in_order_and_updates_ledger() {
    let mut run = MissionRun::new(AgentBlueprintId("blueprint-success".into()), tight_spec());

    let (sealed_ord, snapshot_ord) = run
        .gate_and_record_sealed_mutation(cap(), debit_tokens(30))
        .expect("first mutation within budget");
    assert_eq!(sealed_ord, 0, "first sealed mutation ordinal");
    assert_eq!(
        snapshot_ord, 1,
        "ledger snapshot immediately follows sealed mutation"
    );
    assert_eq!(run.ledger().tokens_used, 30);

    let (sealed_ord_2, snapshot_ord_2) = run
        .gate_and_record_sealed_mutation(cap(), debit_tokens(40))
        .expect("second mutation within budget");
    assert_eq!(sealed_ord_2, 2);
    assert_eq!(snapshot_ord_2, 3);
    assert_eq!(run.ledger().tokens_used, 70);

    let (events, sealed, snapshots) = run.run_event_log().entry_count_by_kind();
    assert_eq!((events, sealed, snapshots), (0, 2, 2));
}

/// **Atomicity invariant**: a budget rejection MUST leave the run log
/// AND the internal ledger completely untouched. The justification for
/// the entire helper rests on this guarantee — without it, the
/// witness chain could carry a sealed mutation with no ledger snapshot
/// or vice versa.
#[test]
fn mission_run_gate_rejection_writes_nothing_and_does_not_mutate_ledger() {
    let mut run = MissionRun::new(AgentBlueprintId("blueprint-reject".into()), tight_spec());

    // Land one successful mutation so the log + ledger have known state.
    run.gate_and_record_sealed_mutation(cap(), debit_tokens(80))
        .expect("first mutation within budget");
    let log_len_before = run.run_event_log().len();
    let ledger_before = run.ledger();
    assert_eq!(ledger_before.tokens_used, 80);

    // Now propose a mutation that overruns the 100-token cap (80 + 50 > 100).
    let err = run
        .gate_and_record_sealed_mutation(cap(), debit_tokens(50))
        .expect_err("over-budget mutation MUST be rejected");
    let BudgetError::Exhausted { .. } = err;

    // Atomicity: no new log entries, no ledger mutation.
    assert_eq!(
        run.run_event_log().len(),
        log_len_before,
        "rejected mutation MUST NOT append any log entry"
    );
    assert_eq!(
        run.ledger(),
        ledger_before,
        "rejected mutation MUST NOT mutate the ledger"
    );
}

/// `record_event` appends an event row independent of the budget gate
/// (events are not budget-controlled — only sealed mutations are).
#[test]
fn mission_run_record_event_appends_without_touching_budget() {
    let mut run = MissionRun::new(AgentBlueprintId("blueprint-events".into()), tight_spec());
    let o0 = run.record_event(AgentEvent::ReasoningDelta {
        text: "think".into(),
    });
    let o1 = run.record_event(AgentEvent::FinalText {
        text: "answer".into(),
    });
    assert_eq!((o0, o1), (0, 1));
    assert_eq!(run.ledger(), BudgetLedger::default(), "events do not debit");
    let (events, sealed, snapshots) = run.run_event_log().entry_count_by_kind();
    assert_eq!((events, sealed, snapshots), (2, 0, 0));
}

/// `finalize()` emits an AnswerPacket that reflects the accumulated
/// ledger + log state. The `run_event_log_root` in the packet equals
/// the log's root hash at the moment of finalization.
#[test]
fn mission_run_finalize_emits_answer_packet_reflecting_accumulated_state() {
    let mut run = MissionRun::new(AgentBlueprintId("blueprint-finalize".into()), tight_spec());
    run.record_event(AgentEvent::ReasoningDelta {
        text: "think".into(),
    });
    run.record_event(AgentEvent::FinalText {
        text: "answer-body".into(),
    });
    run.gate_and_record_sealed_mutation(cap(), debit_tokens(25))
        .expect("within budget");
    run.record_event(AgentEvent::Stop {
        reason: StopReason::EndTurn,
    });

    let ledger_at_finalize = run.ledger();
    let root_at_finalize = run.run_event_log().root_hash();

    let packet = run.finalize(
        "answer-body".to_string(),
        vec![Citation::from_tuple("vault/a.md", "L1-L10")],
        StopReason::EndTurn,
    );

    assert_eq!(packet.blueprint_id.0, "blueprint-finalize");
    assert_eq!(packet.final_text, "answer-body");
    assert_eq!(packet.citations.len(), 1);
    assert_eq!(packet.stop_reason, StopReason::EndTurn);
    assert_eq!(packet.final_ledger, ledger_at_finalize);
    assert_eq!(packet.run_event_log_root, root_at_finalize);
    assert_eq!(
        packet.thinking_digest,
        Hash::zero(),
        "finalize() (without thinking) MUST default to Hash::zero per AnswerPacket::emit contract"
    );
}

/// `finalize_with_thinking` carries the thinking digest verbatim into
/// the packet — pinning the CLAUDE.md "PRESERVE THINKING BLOCKS"
/// non-negotiable at the composition seam.
#[test]
fn mission_run_finalize_with_thinking_carries_thinking_digest_verbatim() {
    let mut run = MissionRun::new(AgentBlueprintId("blueprint-thinking".into()), tight_spec());
    run.record_event(AgentEvent::FinalText { text: "x".into() });
    let thinking = Hash::from_bytes([0xCD; 32]);

    let packet =
        run.finalize_with_thinking("x".to_string(), Vec::new(), StopReason::EndTurn, thinking);
    assert_eq!(
        packet.thinking_digest, thinking,
        "thinking_digest MUST flow through finalize_with_thinking verbatim"
    );
}
