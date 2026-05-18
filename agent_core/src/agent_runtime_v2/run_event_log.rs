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

/// Errors raised by `RunEventLog::validate_ordinal_density`. The
/// `position` is the array index where the violation surfaced; the
/// caller can use it to pinpoint the corrupted row.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum LogValidationError {
    OrdinalMismatch {
        position: usize,
        expected: u64,
        actual: u64,
    },
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

    /// Sum the `tokens` field of every `SealedMutation` debit in the
    /// log. Returns `(total_tokens, count_of_sealed_mutations)` so
    /// the caller can compute averages without a second pass.
    ///
    /// Phase 1 hardening audit helper for the Provenance Console
    /// "tokens debited this run" rollup.
    #[must_use]
    pub fn total_tokens_debited(&self) -> (u64, usize) {
        let mut total: u64 = 0;
        let mut count: usize = 0;
        for entry in &self.entries {
            if let RunEventEntry::SealedMutation { debit, .. } = entry {
                total = total.saturating_add(debit.tokens);
                count += 1;
            }
        }
        (total, count)
    }

    /// Count entries by kind. Returns `(events, sealed_mutations,
    /// ledger_snapshots)` for audit dashboards that surface a
    /// rollup of the log's composition without iterating themselves.
    ///
    /// Phase 1 hardening — boundary helper for the audit / Provenance
    /// Console UI that consumes RunEventLog.
    #[must_use]
    pub fn entry_count_by_kind(&self) -> (usize, usize, usize) {
        let mut events = 0;
        let mut sealed = 0;
        let mut snapshots = 0;
        for entry in &self.entries {
            match entry {
                RunEventEntry::Event { .. } => events += 1,
                RunEventEntry::SealedMutation { .. } => sealed += 1,
                RunEventEntry::LedgerSnapshot { .. } => snapshots += 1,
            }
        }
        (events, sealed, snapshots)
    }

    /// Detect replay-style re-use of a single-use capability. Returns
    /// the number of usages BEYOND the allowed cap: 0 means within
    /// budget; >0 means the capability was used more times than
    /// `max_uses` permits.
    ///
    /// Use `max_uses = 1` for single-use macaroons (the canonical
    /// replay-detect case). Use larger caps for known-multi-use tokens
    /// (e.g. a per-mission tool token granted N tool calls). The
    /// caller decides what the cap is; this just counts.
    #[must_use]
    pub fn detect_capability_reuse(&self, needle: &Hash, max_uses: usize) -> usize {
        let count = self.find_capability_hash(needle).len();
        count.saturating_sub(max_uses)
    }

    /// Return the ordinals of every `SealedMutation` entry whose
    /// `capability_hash` matches `needle`. Used by audit / replay
    /// tooling that wants to find every write authorised by a given
    /// macaroon — e.g. "show me every mutation Capability X
    /// permitted in this run".
    ///
    /// O(n) in log length; replay-tier callers can afford this. If a
    /// future call site needs sub-linear lookup it should build an
    /// index off `entries()`.
    #[must_use]
    pub fn find_capability_hash(&self, needle: &Hash) -> Vec<u64> {
        self.entries
            .iter()
            .filter_map(|e| match e {
                RunEventEntry::SealedMutation {
                    ordinal,
                    capability_hash,
                    ..
                } if capability_hash == needle => Some(*ordinal),
                _ => None,
            })
            .collect()
    }

    /// Validate that every entry's ordinal matches its position in
    /// the log (dense 0..N with no gaps and no out-of-order rows).
    /// Returns `Ok(())` on a clean log; `Err(LogValidationError)`
    /// on the first violation found.
    ///
    /// Phase 1 hardening — user's explicit list: "corrupted log
    /// fails to load; gap detected". Call this after deserialise
    /// (or any time you import a log from external storage) before
    /// trusting the log's ordering.
    pub fn validate_ordinal_density(&self) -> Result<(), LogValidationError> {
        for (idx, entry) in self.entries.iter().enumerate() {
            let expected = idx as u64;
            let actual = entry.ordinal();
            if actual != expected {
                return Err(LogValidationError::OrdinalMismatch {
                    position: idx,
                    expected,
                    actual,
                });
            }
        }
        Ok(())
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
    fn ordinals_are_dense_and_monotonic_under_thousands_of_appends() {
        // Property: across N appends of mixed RunEventEntry kinds,
        // ordinals must be dense (0..N with no gaps) and strictly
        // increasing in the order returned by entries().
        const N: u64 = 2_500;
        let mut log = RunEventLog::new();
        for i in 0..N {
            match i % 3 {
                0 => {
                    log.append_event(AgentEvent::ReasoningDelta {
                        text: format!("delta-{i}"),
                    });
                }
                1 => {
                    log.append_sealed_mutation(
                        Hash::from_bytes([(i % 256) as u8; 32]),
                        BudgetDebit { tokens: i, ..Default::default() },
                    );
                }
                _ => {
                    log.append_ledger_snapshot(BudgetLedger {
                        tokens_used: i,
                        ..Default::default()
                    });
                }
            }
        }
        assert_eq!(log.len() as u64, N);
        let mut last: i64 = -1;
        for entry in log.entries() {
            let o = entry.ordinal() as i64;
            assert!(o == last + 1, "non-dense ordinal at {o} (last was {last})");
            last = o;
        }
        assert_eq!(last as u64 + 1, N);
    }

    #[test]
    fn validate_ordinal_density_accepts_clean_log() {
        let mut log = RunEventLog::new();
        for i in 0..10 {
            log.append_event(AgentEvent::ReasoningDelta {
                text: format!("d{i}"),
            });
        }
        log.validate_ordinal_density().expect("dense log validates");
    }

    #[test]
    fn validate_ordinal_density_catches_gap() {
        // Simulate a tampered log: deserialise normally, then forge
        // a gap by replacing an entry's ordinal. validate must catch
        // the violation at the first bad position.
        let mut log = RunEventLog::new();
        for i in 0..5 {
            log.append_event(AgentEvent::ReasoningDelta {
                text: format!("d{i}"),
            });
        }
        // Round-trip through JSON, then mutate the deserialised
        // structure to introduce a gap.
        let s = serde_json::to_string(&log).expect("serialize");
        // Naive bytes-level tamper: rewrite ordinal `2` to `999`
        // in the JSON, then deserialise. Hand-rolled to keep the
        // test self-contained.
        let tampered_json = s.replacen("\"ordinal\":2", "\"ordinal\":999", 1);
        let tampered: RunEventLog =
            serde_json::from_str(&tampered_json).expect("deserialise tampered");
        let err = tampered
            .validate_ordinal_density()
            .expect_err("tampered log must fail validation");
        assert_eq!(
            err,
            LogValidationError::OrdinalMismatch {
                position: 2,
                expected: 2,
                actual: 999,
            }
        );
    }

    #[test]
    fn merging_two_distinct_logs_produces_a_new_root_hash() {
        // Phase 1 hardening — chained-log invariant: two distinct
        // logs concatenated (or any merge that produces a third
        // log with the union of entries) must yield a NEW
        // root_hash that's not equal to either component's root.
        // This is a guardrail for any future log-merge tooling.
        let mut a = RunEventLog::new();
        a.append_event(AgentEvent::ReasoningDelta { text: "a-only".into() });
        let mut b = RunEventLog::new();
        b.append_event(AgentEvent::ReasoningDelta { text: "b-only".into() });

        // Build a synthetic "merged" log by replaying b's entries
        // into a copy of a (renumbering ordinals).
        let mut merged = RunEventLog::new();
        merged.append_event(AgentEvent::ReasoningDelta { text: "a-only".into() });
        merged.append_event(AgentEvent::ReasoningDelta { text: "b-only".into() });

        let root_a = a.root_hash();
        let root_b = b.root_hash();
        let root_merged = merged.root_hash();
        assert_ne!(root_merged, root_a);
        assert_ne!(root_merged, root_b);
        assert_ne!(root_a, root_b);

        // Reversed-order merge produces yet ANOTHER root (order
        // matters at the BLAKE3-tree level).
        let mut reverse_merged = RunEventLog::new();
        reverse_merged.append_event(AgentEvent::ReasoningDelta { text: "b-only".into() });
        reverse_merged.append_event(AgentEvent::ReasoningDelta { text: "a-only".into() });
        assert_ne!(reverse_merged.root_hash(), root_merged);
    }

    #[test]
    fn empty_log_validates() {
        let log = RunEventLog::new();
        log.validate_ordinal_density().expect("empty log is dense by definition");
    }

    #[test]
    fn total_tokens_debited_sums_sealed_mutation_debits() {
        let mut log = RunEventLog::new();
        // Non-mutation entries must NOT contribute.
        log.append_event(AgentEvent::ReasoningDelta { text: "x".into() });
        // 3 sealed mutations with 25 / 75 / 100 tokens.
        log.append_sealed_mutation(
            Hash::zero(),
            BudgetDebit { tokens: 25, ..Default::default() },
        );
        log.append_sealed_mutation(
            Hash::zero(),
            BudgetDebit { tokens: 75, ..Default::default() },
        );
        log.append_sealed_mutation(
            Hash::zero(),
            BudgetDebit { tokens: 100, ..Default::default() },
        );
        // Snapshot — also doesn't contribute.
        log.append_ledger_snapshot(BudgetLedger::default());

        let (total, count) = log.total_tokens_debited();
        assert_eq!(total, 200);
        assert_eq!(count, 3);
    }

    #[test]
    fn total_tokens_debited_empty_log_returns_zero() {
        let log = RunEventLog::new();
        assert_eq!(log.total_tokens_debited(), (0, 0));
    }

    #[test]
    fn total_tokens_debited_saturates_on_overflow() {
        let mut log = RunEventLog::new();
        log.append_sealed_mutation(
            Hash::zero(),
            BudgetDebit { tokens: u64::MAX - 5, ..Default::default() },
        );
        log.append_sealed_mutation(
            Hash::zero(),
            BudgetDebit { tokens: 100, ..Default::default() },
        );
        let (total, _) = log.total_tokens_debited();
        assert_eq!(total, u64::MAX);
    }

    #[test]
    fn entry_count_by_kind_rolls_up_correctly() {
        let mut log = RunEventLog::new();
        // 3 events
        log.append_event(AgentEvent::ReasoningDelta { text: "a".into() });
        log.append_event(AgentEvent::FinalText { text: "b".into() });
        log.append_event(AgentEvent::Stop { reason: StopReason::EndTurn });
        // 2 sealed mutations
        log.append_sealed_mutation(Hash::zero(), BudgetDebit::default());
        log.append_sealed_mutation(Hash::from_bytes([1u8; 32]), BudgetDebit::default());
        // 1 ledger snapshot
        log.append_ledger_snapshot(BudgetLedger::default());

        let (events, sealed, snapshots) = log.entry_count_by_kind();
        assert_eq!((events, sealed, snapshots), (3, 2, 1));
        assert_eq!(log.len(), events + sealed + snapshots);
    }

    #[test]
    fn entry_count_by_kind_empty_log_returns_zeros() {
        let log = RunEventLog::new();
        assert_eq!(log.entry_count_by_kind(), (0, 0, 0));
    }

    #[test]
    fn detect_capability_reuse_flags_single_use_violation() {
        // Phase 1 hardening — user's explicit list: "replay-detected".
        // Mark a capability as single-use (max_uses=1); the log
        // records two SealedMutation rows under that hash; detect
        // returns 1 (one usage beyond cap).
        let mut log = RunEventLog::new();
        let cap = Hash::from_bytes([5u8; 32]);
        log.append_sealed_mutation(cap, BudgetDebit::default());
        log.append_sealed_mutation(cap, BudgetDebit::default());
        assert_eq!(log.detect_capability_reuse(&cap, 1), 1);
        // Within-cap variant returns 0.
        assert_eq!(log.detect_capability_reuse(&cap, 2), 0);
        // Unrelated cap is always 0.
        let other = Hash::from_bytes([6u8; 32]);
        assert_eq!(log.detect_capability_reuse(&other, 1), 0);
    }

    #[test]
    fn detect_capability_reuse_handles_high_multi_use_caps() {
        let mut log = RunEventLog::new();
        let cap = Hash::from_bytes([7u8; 32]);
        for _ in 0..5 {
            log.append_sealed_mutation(cap, BudgetDebit::default());
        }
        // 5 uses vs cap=3 → overage 2.
        assert_eq!(log.detect_capability_reuse(&cap, 3), 2);
        // cap=5 exact → overage 0.
        assert_eq!(log.detect_capability_reuse(&cap, 5), 0);
        // cap=10 unused budget → overage 0 (saturating_sub).
        assert_eq!(log.detect_capability_reuse(&cap, 10), 0);
    }

    #[test]
    fn find_capability_hash_returns_matching_ordinals_in_order() {
        let mut log = RunEventLog::new();
        let cap_a = Hash::from_bytes([1u8; 32]);
        let cap_b = Hash::from_bytes([2u8; 32]);
        // Interleave events + sealed mutations under both capabilities
        log.append_event(AgentEvent::ReasoningDelta { text: "x".into() });
        let o1 = log.append_sealed_mutation(cap_a, BudgetDebit::default()); // 1
        log.append_event(AgentEvent::ReasoningDelta { text: "y".into() });
        let o3 = log.append_sealed_mutation(cap_b, BudgetDebit::default()); // 3
        let o4 = log.append_sealed_mutation(cap_a, BudgetDebit::default()); // 4
        log.append_ledger_snapshot(BudgetLedger::default());

        let hits_a = log.find_capability_hash(&cap_a);
        assert_eq!(hits_a, vec![o1, o4]);

        let hits_b = log.find_capability_hash(&cap_b);
        assert_eq!(hits_b, vec![o3]);

        let hits_none = log.find_capability_hash(&Hash::zero());
        assert!(hits_none.is_empty());
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
