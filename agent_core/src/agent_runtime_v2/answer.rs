//! `AnswerPacket` — the terminal artifact of a v2 mission run.
//!
//! Closes the canonical flow:
//!
//! ```text
//! AgentBlueprint → MissionPacket → AgentEvent stream → approval →
//! MutationEnvelope → RunEventLog → AnswerPacket
//! ```
//!
//! The packet binds the user-visible answer to its witness trail (the
//! `RunEventLog` root) and the stop reason so downstream callers can
//! tell `EndTurn` from `BudgetExhausted` etc. without re-walking the
//! event stream.

use serde::{Deserialize, Serialize};

use crate::cognitive_dag::node::Hash;

use super::blueprint::AgentBlueprintId;
use super::budget::BudgetLedger;
use super::para::StopReason;
use super::run_event_log::RunEventLog;

/// One citation row. Kept opaque on purpose so different executors can
/// supply different evidence shapes without expanding this struct.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Citation {
    pub source: String,
    pub locator: String,
}

/// Terminal artifact of a mission run.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct AnswerPacket {
    pub blueprint_id: AgentBlueprintId,
    /// Concatenation of every `AgentEvent::FinalText` delta from the
    /// stream. Producer-owned — we do not validate the text content,
    /// only that the stop reason and witness root accompany it.
    pub final_text: String,
    pub citations: Vec<Citation>,
    pub stop_reason: StopReason,
    /// Final budget ledger after every debit. Lets the caller display
    /// `tokens_used / max_tokens` without rebuilding from the log.
    pub final_ledger: BudgetLedger,
    /// BLAKE3 root over the `RunEventLog` at packet-emit time. Replay
    /// must reproduce this hash bit-for-bit.
    pub run_event_log_root: Hash,
}

impl AnswerPacket {
    /// Build an `AnswerPacket` from the final state of a run.
    /// `run_event_log_root` is captured here (callers pass the log so
    /// the hash is computed against the final state — never half-way).
    #[must_use]
    pub fn emit(
        blueprint_id: AgentBlueprintId,
        final_text: String,
        citations: Vec<Citation>,
        stop_reason: StopReason,
        final_ledger: BudgetLedger,
        run_event_log: &RunEventLog,
    ) -> Self {
        Self {
            blueprint_id,
            final_text,
            citations,
            stop_reason,
            final_ledger,
            run_event_log_root: run_event_log.root_hash(),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::agent_runtime_v2::budget::{BudgetDebit, BudgetLedger};
    use crate::agent_runtime_v2::event::AgentEvent;

    #[test]
    fn answer_packet_emitted_with_typed_stop_reason() {
        // §4 T11 acceptance: "AnswerPacket emitted". Run a mock flow,
        // append events to the log, emit the packet, and assert the
        // stop reason + witness root are present and consistent.
        let mut log = RunEventLog::new();
        log.append_event(AgentEvent::ReasoningDelta { text: "think".into() });
        log.append_event(AgentEvent::FinalText { text: "the answer".into() });
        log.append_sealed_mutation(
            Hash::from_bytes([3u8; 32]),
            BudgetDebit { tokens: 25, ..Default::default() },
        );
        log.append_ledger_snapshot(BudgetLedger {
            tokens_used: 25,
            ..Default::default()
        });
        log.append_event(AgentEvent::Stop { reason: StopReason::EndTurn });

        let packet = AnswerPacket::emit(
            AgentBlueprintId("research-assistant".to_string()),
            "the answer".to_string(),
            vec![Citation {
                source: "vault/notes/2026/may/a.md".into(),
                locator: "L42-L57".into(),
            }],
            StopReason::EndTurn,
            BudgetLedger {
                tokens_used: 25,
                ..Default::default()
            },
            &log,
        );

        assert_eq!(packet.stop_reason, StopReason::EndTurn);
        assert_eq!(packet.final_text, "the answer");
        assert_eq!(packet.citations.len(), 1);
        assert_eq!(packet.final_ledger.tokens_used, 25);
        assert_eq!(packet.run_event_log_root, log.root_hash());
    }

    #[test]
    fn answer_packet_distinguishes_budget_exhausted_from_end_turn() {
        // Two runs with the same final_text but different stop_reasons
        // must produce distinguishable packets. This is what makes
        // StopReason load-bearing.
        let log = RunEventLog::new();
        let p_end = AnswerPacket::emit(
            AgentBlueprintId("a".into()),
            "partial".into(),
            vec![],
            StopReason::EndTurn,
            BudgetLedger::default(),
            &log,
        );
        let p_budget = AnswerPacket::emit(
            AgentBlueprintId("a".into()),
            "partial".into(),
            vec![],
            StopReason::BudgetExhausted,
            BudgetLedger::default(),
            &log,
        );
        assert_ne!(p_end, p_budget);
        assert_eq!(p_end.run_event_log_root, p_budget.run_event_log_root);
        assert_ne!(p_end.stop_reason, p_budget.stop_reason);
    }

    #[test]
    fn answer_packet_witness_root_changes_when_log_changes() {
        let mut log_a = RunEventLog::new();
        log_a.append_event(AgentEvent::Stop { reason: StopReason::EndTurn });
        let p_a = AnswerPacket::emit(
            AgentBlueprintId("a".into()),
            "x".into(),
            vec![],
            StopReason::EndTurn,
            BudgetLedger::default(),
            &log_a,
        );

        let mut log_b = RunEventLog::new();
        log_b.append_event(AgentEvent::ReasoningDelta { text: "extra".into() });
        log_b.append_event(AgentEvent::Stop { reason: StopReason::EndTurn });
        let p_b = AnswerPacket::emit(
            AgentBlueprintId("a".into()),
            "x".into(),
            vec![],
            StopReason::EndTurn,
            BudgetLedger::default(),
            &log_b,
        );

        assert_ne!(p_a.run_event_log_root, p_b.run_event_log_root);
    }

    #[test]
    fn answer_packet_round_trips_through_json() {
        let log = RunEventLog::new();
        let packet = AnswerPacket::emit(
            AgentBlueprintId("a".into()),
            "hello".into(),
            vec![Citation {
                source: "src".into(),
                locator: "loc".into(),
            }],
            StopReason::EndTurn,
            BudgetLedger::default(),
            &log,
        );
        let s = serde_json::to_string(&packet).expect("serialize");
        let back: AnswerPacket = serde_json::from_str(&s).expect("deserialize");
        assert_eq!(back, packet);
    }
}
