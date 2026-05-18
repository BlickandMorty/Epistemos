//! `RunEventLog` — append-only typed witness trail for a single
//! mission run.
//!
//! Every `AgentEvent` the executor emits and every `MutationEnvelope`
//! the `Sealer` clears is appended here. The log's BLAKE3 root hash
//! becomes part of the `AnswerPacket` so a replay can verify the
//! witness chain end-to-end.
//!
//! Append-only invariant: there is no `pop`, no `truncate`, no
//! `clear`. The only mutator is `append`. Replay reads from
//! `entries()` and rebuilds state deterministically.

use serde::{Deserialize, Serialize};

use crate::cognitive_dag::node::Hash;

use super::budget::{BudgetDebit, BudgetLedger};
use super::event::AgentEvent;

/// A single typed row in the run event log.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(tag = "kind", rename_all = "snake_case")]
pub enum RunEventEntry {
    /// An executor-stream event (reasoning delta, final text, tool
    /// call, tool result, stop, error).
    Event { ordinal: u64, event: AgentEvent },
    /// A sealed mutation that cleared the capability + budget gates
    /// and was applied by a `MutationWriter`. We record the
    /// capability_hash + debit (not the payload — the payload may be
    /// large or sensitive; the writer is responsible for its own
    /// audit trail).
    SealedMutation {
        ordinal: u64,
        capability_hash: Hash,
        debit: BudgetDebit,
    },
    /// Snapshot of the budget ledger after a sealed mutation. Lets a
    /// replay rebuild the ledger curve without replaying every
    /// debit.
    LedgerSnapshot { ordinal: u64, ledger: BudgetLedger },
}

impl RunEventEntry {
    /// Ordinal of this entry — monotonically assigned by `RunEventLog`.
    pub fn ordinal(&self) -> u64 {
        match self {
            Self::Event { ordinal, .. }
            | Self::SealedMutation { ordinal, .. }
            | Self::LedgerSnapshot { ordinal, .. } => *ordinal,
        }
    }
}

/// Append-only typed witness trail.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct RunEventLog {
    entries: Vec<RunEventEntry>,
}

impl RunEventLog {
    #[must_use]
    pub fn new() -> Self {
        Self {
            entries: Vec::new(),
        }
    }

    /// Append a typed event. Returns the assigned ordinal.
    pub fn append_event(&mut self, event: AgentEvent) -> u64 {
        let ordinal = self.entries.len() as u64;
        self.entries.push(RunEventEntry::Event { ordinal, event });
        ordinal
    }

    /// Record a sealed mutation. Called by the dispatcher AFTER the
    /// `Sealer` accepts an envelope and the writer succeeds.
    pub fn append_sealed_mutation(
        &mut self,
        capability_hash: Hash,
        debit: BudgetDebit,
    ) -> u64 {
        let ordinal = self.entries.len() as u64;
        self.entries.push(RunEventEntry::SealedMutation {
            ordinal,
            capability_hash,
            debit,
        });
        ordinal
    }

    /// Snapshot the post-mutation ledger.
    pub fn append_ledger_snapshot(&mut self, ledger: BudgetLedger) -> u64 {
        let ordinal = self.entries.len() as u64;
        self.entries
            .push(RunEventEntry::LedgerSnapshot { ordinal, ledger });
        ordinal
    }

    /// Read access for replay and assertions. No mutator surface.
    pub fn entries(&self) -> &[RunEventEntry] {
        &self.entries
    }

    /// Number of entries (replay length).
    pub fn len(&self) -> usize {
        self.entries.len()
    }

    /// Convenience.
    pub fn is_empty(&self) -> bool {
        self.entries.is_empty()
    }

    /// BLAKE3 root over canonical JSON of every entry in order.
    /// Becomes part of the `AnswerPacket` so replay can verify the
    /// witness chain end-to-end.
    pub fn root_hash(&self) -> Hash {
        let mut hasher = blake3::Hasher::new();
        hasher.update(b"agent_runtime_v2.run_event_log.root.v1\n");
        for entry in &self.entries {
            let bytes = serde_json::to_vec(entry).expect("serializable entry");
            hasher.update(&(bytes.len() as u64).to_le_bytes());
            hasher.update(&bytes);
        }
        Hash::from_bytes(*hasher.finalize().as_bytes())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::agent_runtime_v2::budget::BudgetDebit;
    use crate::agent_runtime_v2::para::StopReason;

    #[test]
    fn empty_log_has_stable_root() {
        let log = RunEventLog::new();
        assert_eq!(log.len(), 0);
        let h1 = log.root_hash();
        let h2 = log.root_hash();
        assert_eq!(h1, h2, "root_hash must be deterministic");
    }

    #[test]
    fn append_assigns_monotonic_ordinals() {
        let mut log = RunEventLog::new();
        let o0 = log.append_event(AgentEvent::ReasoningDelta { text: "a".into() });
        let o1 = log.append_event(AgentEvent::FinalText { text: "b".into() });
        let o2 = log.append_sealed_mutation(Hash::zero(), BudgetDebit::default());
        let o3 = log.append_ledger_snapshot(BudgetLedger::default());
        assert_eq!((o0, o1, o2, o3), (0, 1, 2, 3));
        assert_eq!(log.len(), 4);
        for (i, e) in log.entries().iter().enumerate() {
            assert_eq!(e.ordinal(), i as u64);
        }
    }

    #[test]
    fn root_hash_changes_on_append() {
        let mut log = RunEventLog::new();
        let before = log.root_hash();
        log.append_event(AgentEvent::Stop { reason: StopReason::EndTurn });
        let after = log.root_hash();
        assert_ne!(before, after);
    }

    #[test]
    fn root_hash_order_sensitive() {
        // Different ordering of equivalent events → different root.
        let mut a = RunEventLog::new();
        a.append_event(AgentEvent::ReasoningDelta { text: "x".into() });
        a.append_event(AgentEvent::FinalText { text: "y".into() });

        let mut b = RunEventLog::new();
        b.append_event(AgentEvent::FinalText { text: "y".into() });
        b.append_event(AgentEvent::ReasoningDelta { text: "x".into() });

        assert_ne!(a.root_hash(), b.root_hash());
    }

    #[test]
    fn log_round_trips_through_json() {
        let mut log = RunEventLog::new();
        log.append_event(AgentEvent::ReasoningDelta { text: "think".into() });
        log.append_sealed_mutation(
            Hash::from_bytes([7u8; 32]),
            BudgetDebit { tokens: 25, tool_calls: 1, ..Default::default() },
        );
        log.append_ledger_snapshot(BudgetLedger {
            tokens_used: 25,
            tool_calls_used: 1,
            ..Default::default()
        });
        log.append_event(AgentEvent::Stop { reason: StopReason::EndTurn });

        let s = serde_json::to_string(&log).expect("serialize");
        let back: RunEventLog = serde_json::from_str(&s).expect("deserialize");
        assert_eq!(back.len(), log.len());
        assert_eq!(back.root_hash(), log.root_hash());
    }
}
