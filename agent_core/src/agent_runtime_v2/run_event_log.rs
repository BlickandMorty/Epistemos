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

    /// Return the most recent `LedgerSnapshot` at-or-before the
    /// given ordinal. Replay-scrubbing UI uses this to reconstruct
    /// the budget state at any point in the run. O(n) reverse walk
    /// up to `ord`; returns `None` if no snapshot has been recorded
    /// at-or-before ord.
    #[must_use]
    pub fn ledger_at_ordinal(&self, ord: u64) -> Option<crate::agent_runtime_v2::budget::BudgetLedger> {
        for entry in self.entries.iter().rev() {
            if entry.ordinal() > ord {
                continue;
            }
            if let RunEventEntry::LedgerSnapshot { ledger, .. } = entry {
                return Some(*ledger);
            }
        }
        None
    }

    /// Iterate over every `SealedMutation` row, yielding `(ordinal,
    /// &capability_hash, &debit)`. Lazy — no Vec allocation. Audit
    /// callers can collect, filter, or short-circuit as needed.
    pub fn sealed_mutations(
        &self,
    ) -> impl Iterator<
        Item = (
            u64,
            &Hash,
            &crate::agent_runtime_v2::budget::BudgetDebit,
        ),
    > + '_ {
        self.entries.iter().filter_map(|e| match e {
            RunEventEntry::SealedMutation {
                ordinal,
                capability_hash,
                debit,
            } => Some((*ordinal, capability_hash, debit)),
            _ => None,
        })
    }

    /// Return every `(ordinal, &ToolCall)` pair from `AgentEvent::
    /// ToolCall` rows in the log, in order. Audit / replay tooling
    /// uses this to build a tool-call timeline without walking
    /// the full log. O(n) walk; caller may collect into a Vec for
    /// random access.
    pub fn find_tool_calls(
        &self,
    ) -> Vec<(u64, &crate::agent_runtime_v2::mission::ToolCall)> {
        let mut hits = Vec::new();
        for entry in &self.entries {
            if let RunEventEntry::Event {
                ordinal,
                event: crate::agent_runtime_v2::event::AgentEvent::ToolCall { call },
            } = entry
            {
                hits.push((*ordinal, call));
            }
        }
        hits
    }

    /// Return the ordinal of the first entry, or `None` if the log
    /// is empty. Convenience for UI / audit code that wants to know
    /// "where does this run start" without reaching into `entries`.
    /// Always 0 for non-empty logs (ordinals are dense from 0).
    #[must_use]
    pub fn first_event_ordinal(&self) -> Option<u64> {
        self.entries.first().map(|e| e.ordinal())
    }

    /// Count how many `AgentEvent::Stop` events appear in the log.
    /// Well-formed runs append exactly one (terminal); 0 means the
    /// run is still in flight; 2+ flags a replay anomaly. Phase 1
    /// hardening helper for the audit surface.
    #[must_use]
    pub fn stop_count(&self) -> usize {
        self.entries
            .iter()
            .filter(|e| {
                matches!(
                    e,
                    RunEventEntry::Event {
                        event: crate::agent_runtime_v2::event::AgentEvent::Stop { .. },
                        ..
                    }
                )
            })
            .count()
    }

    /// Count how many `AgentEvent::Error` events appear in the log.
    /// Distinct from `stop_count` — error events terminate with a
    /// typed error kind rather than a typed stop reason. A well-formed
    /// happy run has 0; a run that errored out has ≥1. Phase 1
    /// hardening helper for the audit surface.
    #[must_use]
    pub fn error_count(&self) -> usize {
        self.entries
            .iter()
            .filter(|e| {
                matches!(
                    e,
                    RunEventEntry::Event {
                        event: crate::agent_runtime_v2::event::AgentEvent::Error { .. },
                        ..
                    }
                )
            })
            .count()
    }

    /// Return the StopReason of the most recent `AgentEvent::Stop`
    /// in the log, or `None` if no stop event has been appended.
    /// O(n) walk; replay-tier callers can afford this. Phase 1
    /// hardening helper — gives the UI a quick "did this run end?"
    /// answer without walking the full log themselves.
    #[must_use]
    pub fn last_stop_event(&self) -> Option<crate::agent_runtime_v2::para::StopReason> {
        for entry in self.entries.iter().rev() {
            if let RunEventEntry::Event {
                event: crate::agent_runtime_v2::event::AgentEvent::Stop { reason },
                ..
            } = entry
            {
                return Some(*reason);
            }
        }
        None
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
    use crate::agent_runtime_v2::event::AgentEventErrorKind;
    use crate::agent_runtime_v2::para::StopReason;

    #[test]
    fn run_event_log_default_produces_empty_log_indistinguishable_from_new() {
        // Phase 1 hardening — RunEventLog derives Default; pin
        // that the Default::default() instance is bytewise
        // equivalent to RunEventLog::new(): same len (0), same
        // root_hash, same entries(). A future override of Default
        // (or new()) that diverged would silently produce two
        // empty-log root values and break replay parity for
        // logs serialised from different construction paths.
        let via_default: RunEventLog = Default::default();
        let via_new = RunEventLog::new();
        assert_eq!(via_default.len(), 0);
        assert_eq!(via_default.len(), via_new.len());
        assert_eq!(via_default.root_hash(), via_new.root_hash());
        assert!(via_default.entries().is_empty());
        assert!(via_new.entries().is_empty());
    }

    #[test]
    fn root_hash_domain_separation_prefix_is_pinned_for_replay_parity() {
        // Phase 1 hardening — replay-parity-critical domain-separation
        // prefix. RunEventLog::root_hash feeds an exact byte string
        // into blake3 before any entries: "agent_runtime_v2.run_event_log.root.v1\n".
        // A silent typo or version bump (.v1 → .v2) would silently
        // fork every replay root and break cross-version compatibility.
        // Independently compute the empty-log root and compare to
        // pin the exact prefix.
        let empty = RunEventLog::new();
        let mut hasher = blake3::Hasher::new();
        hasher.update(b"agent_runtime_v2.run_event_log.root.v1\n");
        let expected = Hash::from_bytes(*hasher.finalize().as_bytes());
        assert_eq!(
            empty.root_hash(),
            expected,
            "empty-log root_hash must equal blake3(prefix) exactly — \
             prefix drift breaks replay parity",
        );
    }

    #[test]
    fn root_hash_per_entry_encoding_uses_u64_le_length_prefix_then_json_bytes() {
        // Phase 1 hardening — pin the EXACT per-entry encoding the
        // root hasher uses (companion to root_hash_domain_separation_prefix).
        // The empty-log test only pins the prefix; this pins the
        // entry encoding shape:
        //
        //   blake3(prefix || u64-LE(len(json)) || json) for each entry
        //
        // Silent regressions this catches:
        //   - u64 → u32 length prefix shift (every replay forked)
        //   - little-endian → big-endian shift (every replay forked)
        //   - varint encoding swap (every replay forked)
        //   - dropped length prefix entirely (concatenation collision
        //     attack surface opens up)
        //   - prefix-or-suffix length encoding swap
        //
        // Single-entry log + manual recompute = forensic proof of
        // the exact byte sequence the hasher consumes.
        let mut log = RunEventLog::new();
        log.append_event(AgentEvent::ReasoningDelta { text: "x".into() });
        // Independently recompute using the documented encoding.
        let entry = &log.entries()[0];
        let entry_json = serde_json::to_vec(entry).expect("entry serialises");
        let mut hasher = blake3::Hasher::new();
        hasher.update(b"agent_runtime_v2.run_event_log.root.v1\n");
        // Specifically: u64 little-endian, 8 bytes.
        let len_le_bytes: [u8; 8] = (entry_json.len() as u64).to_le_bytes();
        hasher.update(&len_le_bytes);
        hasher.update(&entry_json);
        let expected = Hash::from_bytes(*hasher.finalize().as_bytes());
        assert_eq!(
            log.root_hash(),
            expected,
            "per-entry encoding (u64-LE length prefix + JSON bytes) drift"
        );

        // Negative-direction: an INDEPENDENT recompute with the WRONG
        // length encoding (big-endian instead of little-endian) must
        // produce a DIFFERENT hash. Surfaces a future endianness flip.
        let mut wrong_endian = blake3::Hasher::new();
        wrong_endian.update(b"agent_runtime_v2.run_event_log.root.v1\n");
        wrong_endian.update(&(entry_json.len() as u64).to_be_bytes());
        wrong_endian.update(&entry_json);
        let wrong = Hash::from_bytes(*wrong_endian.finalize().as_bytes());
        assert_ne!(
            log.root_hash(),
            wrong,
            "root_hash MUST use little-endian — big-endian recompute differs"
        );

        // Also: a recompute that DROPS the length prefix entirely must
        // produce a different hash. Pins the prefix's load-bearing
        // role in collision-resistance.
        let mut no_prefix = blake3::Hasher::new();
        no_prefix.update(b"agent_runtime_v2.run_event_log.root.v1\n");
        no_prefix.update(&entry_json);
        let dropped = Hash::from_bytes(*no_prefix.finalize().as_bytes());
        assert_ne!(
            log.root_hash(),
            dropped,
            "root_hash MUST include length prefix — dropped recompute differs"
        );
    }

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
    fn root_hash_is_byte_sensitive_to_single_character_payload_change() {
        // Phase 1 hardening — replay parity. Two logs that differ
        // by ONE byte in a single event's text payload must produce
        // distinct roots. order_sensitive proves order changes; this
        // proves CONTENT changes do too. A regression where the
        // root only hashes some fields (e.g. ordinals + kinds but
        // not text) would surface here as identical roots.
        let mut a = RunEventLog::new();
        a.append_event(AgentEvent::ReasoningDelta { text: "hello".into() });
        a.append_event(AgentEvent::Stop { reason: StopReason::EndTurn });

        let mut b = RunEventLog::new();
        b.append_event(AgentEvent::ReasoningDelta { text: "hellO".into() }); // ONE-byte diff
        b.append_event(AgentEvent::Stop { reason: StopReason::EndTurn });

        assert_ne!(a.root_hash(), b.root_hash(), "single-byte payload change must change root");
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
    fn log_validation_error_ordinal_mismatch_debug_repr_is_stable_for_audit_persistence() {
        // Phase 1 hardening — audit-log surface. LogValidationError
        // is the only failure mode of validate_ordinal_density; its
        // Debug repr lands in incident reports and CI failure
        // output. Pin the exact format so any future refactor
        // (e.g. switching to a tuple variant) surfaces at PR
        // review rather than silently breaking grep-based audit
        // dashboards.
        let err = LogValidationError::OrdinalMismatch {
            position: 7,
            expected: 7,
            actual: 999,
        };
        let dbg = format!("{err:?}");
        assert_eq!(
            dbg,
            "OrdinalMismatch { position: 7, expected: 7, actual: 999 }"
        );
        // Field-order sensitivity: position before expected before actual.
        let p_idx = dbg.find("position").expect("position field");
        let e_idx = dbg.find("expected").expect("expected field");
        let a_idx = dbg.find("actual").expect("actual field");
        assert!(p_idx < e_idx, "position must appear before expected");
        assert!(e_idx < a_idx, "expected must appear before actual");
    }

    #[test]
    fn validate_ordinal_density_catches_first_position_mismatch() {
        // Phase 1 hardening — boundary completeness for replay
        // validation. The existing "gap" test catches a mid-log
        // ordinal swap (position 2 → 999). This one catches the
        // first-position regression: a tampered log where the
        // VERY FIRST entry's ordinal isn't 0. Without this gate
        // a replay could silently start mid-stream.
        let mut log = RunEventLog::new();
        log.append_event(AgentEvent::ReasoningDelta { text: "a".into() });
        log.append_event(AgentEvent::ReasoningDelta { text: "b".into() });
        let s = serde_json::to_string(&log).expect("serialise");
        // Mutate the FIRST ordinal: 0 → 5.
        let tampered_json = s.replacen("\"ordinal\":0", "\"ordinal\":5", 1);
        let tampered: RunEventLog =
            serde_json::from_str(&tampered_json).expect("deserialise tampered");
        let err = tampered
            .validate_ordinal_density()
            .expect_err("first-position tampered log must fail validation");
        assert_eq!(
            err,
            LogValidationError::OrdinalMismatch {
                position: 0,
                expected: 0,
                actual: 5,
            }
        );
    }

    #[test]
    fn root_hash_unaffected_by_appending_then_reading_in_any_order() {
        // Phase 1 hardening — RunEventLog::root_hash() must be a
        // pure function of the entries vector. Reading entries() in
        // any order, calling root_hash() repeatedly, etc. must not
        // alter the hash. Pins the no-side-effect contract.
        let mut log = RunEventLog::new();
        log.append_event(AgentEvent::ReasoningDelta { text: "a".into() });
        log.append_event(AgentEvent::ReasoningDelta { text: "b".into() });
        let r1 = log.root_hash();
        // Read entries forward, backward, by index — none of these
        // touch the log's state.
        let _forward: Vec<u64> = log.entries().iter().map(|e| e.ordinal()).collect();
        let _backward: Vec<u64> = log.entries().iter().rev().map(|e| e.ordinal()).collect();
        let _by_index = log.entries().get(0).map(|e| e.ordinal());
        let r2 = log.root_hash();
        let r3 = log.root_hash();
        assert_eq!(r1, r2);
        assert_eq!(r2, r3);
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
    fn corrupted_log_recovered_by_discard_and_rebuild() {
        // Phase 1 hardening — recovery contract: when validate
        // detects a gap, the caller's only correct response is to
        // discard the log and rebuild from a trusted source
        // (e.g. an earlier snapshot or live replay). validate
        // returning Err is the SIGNAL — there is no in-place
        // repair API. This test pins the contract by showing the
        // discard-and-rebuild path produces a valid log.
        let mut original = RunEventLog::new();
        for i in 0..3 {
            original.append_event(AgentEvent::ReasoningDelta {
                text: format!("e{i}"),
            });
        }
        original.validate_ordinal_density().expect("original valid");

        // Simulate corruption via JSON tamper.
        let s = serde_json::to_string(&original).expect("serialise");
        let tampered = s.replacen("\"ordinal\":1", "\"ordinal\":42", 1);
        let corrupted: RunEventLog =
            serde_json::from_str(&tampered).expect("deserialise tampered");
        assert!(corrupted.validate_ordinal_density().is_err());

        // Recovery = discard + rebuild from authoritative entries.
        // We model this by appending the same logical events to a
        // FRESH log; validate passes.
        let mut recovered = RunEventLog::new();
        for i in 0..3 {
            recovered.append_event(AgentEvent::ReasoningDelta {
                text: format!("e{i}"),
            });
        }
        recovered
            .validate_ordinal_density()
            .expect("recovered log valid");
        // Root hash equals the original (same canonical entries).
        assert_eq!(recovered.root_hash(), original.root_hash());
    }

    #[test]
    fn empty_log_validates() {
        let log = RunEventLog::new();
        log.validate_ordinal_density().expect("empty log is dense by definition");
    }

    #[test]
    fn ledger_at_ordinal_returns_most_recent_snapshot_at_or_before() {
        let mut log = RunEventLog::new();
        log.append_event(AgentEvent::ReasoningDelta { text: "a".into() }); // ord 0
        let _o1 = log.append_ledger_snapshot(BudgetLedger {
            tokens_used: 100,
            ..Default::default()
        }); // ord 1
        log.append_event(AgentEvent::ReasoningDelta { text: "b".into() }); // ord 2
        let _o3 = log.append_ledger_snapshot(BudgetLedger {
            tokens_used: 250,
            ..Default::default()
        }); // ord 3
        log.append_event(AgentEvent::Stop { reason: StopReason::EndTurn }); // ord 4

        // At ord 0 — before any snapshot — returns None.
        assert_eq!(log.ledger_at_ordinal(0), None);
        // At ord 1 — first snapshot row — returns its ledger.
        assert_eq!(log.ledger_at_ordinal(1).unwrap().tokens_used, 100);
        // At ord 2 — between snapshots — still returns ord-1's
        // snapshot (most recent at-or-before).
        assert_eq!(log.ledger_at_ordinal(2).unwrap().tokens_used, 100);
        // At ord 3 — second snapshot — returns its ledger.
        assert_eq!(log.ledger_at_ordinal(3).unwrap().tokens_used, 250);
        // At ord 4 — after second snapshot — still ord-3's ledger.
        assert_eq!(log.ledger_at_ordinal(4).unwrap().tokens_used, 250);
        // At ord 999 — beyond log — still ord-3's ledger.
        assert_eq!(log.ledger_at_ordinal(999).unwrap().tokens_used, 250);
    }

    #[test]
    fn ledger_at_ordinal_empty_log_returns_none() {
        let log = RunEventLog::new();
        assert_eq!(log.ledger_at_ordinal(0), None);
        assert_eq!(log.ledger_at_ordinal(99), None);
    }

    #[test]
    fn sealed_mutations_iterator_yields_each_row_in_order() {
        let mut log = RunEventLog::new();
        log.append_event(AgentEvent::ReasoningDelta { text: "x".into() }); // 0
        let cap_a = Hash::from_bytes([1u8; 32]);
        let cap_b = Hash::from_bytes([2u8; 32]);
        let _o1 = log.append_sealed_mutation(
            cap_a,
            BudgetDebit { tokens: 10, ..Default::default() },
        ); // 1
        log.append_event(AgentEvent::FinalText { text: "y".into() }); // 2
        let _o3 = log.append_sealed_mutation(
            cap_b,
            BudgetDebit { tokens: 20, ..Default::default() },
        ); // 3
        log.append_ledger_snapshot(BudgetLedger::default()); // 4

        let hits: Vec<_> = log.sealed_mutations().collect();
        assert_eq!(hits.len(), 2);
        assert_eq!(hits[0].0, 1);
        assert_eq!(hits[0].1, &cap_a);
        assert_eq!(hits[0].2.tokens, 10);
        assert_eq!(hits[1].0, 3);
        assert_eq!(hits[1].1, &cap_b);
        assert_eq!(hits[1].2.tokens, 20);
    }

    #[test]
    fn sealed_mutations_preserves_all_five_debit_axes_field_for_field() {
        // Phase 1 hardening — replay-shape integrity. The existing
        // iterator test only checks `tokens`. This pins that every
        // BudgetDebit field (tokens, wall_ms, tool_calls, subprocess_ms,
        // memory_bytes) survives the RunEventEntry encoding round-trip
        // when read back through sealed_mutations(). A silent field
        // drop in the entry encoding (e.g. forgetting to serialise
        // memory_bytes) would surface here.
        let mut log = RunEventLog::new();
        let cap = Hash::from_bytes([9u8; 32]);
        let debit = BudgetDebit {
            tokens: 111,
            wall_ms: 222,
            tool_calls: 3,
            subprocess_ms: 444,
            memory_bytes: 555_555,
        };
        log.append_sealed_mutation(cap, debit);

        let hits: Vec<_> = log.sealed_mutations().collect();
        assert_eq!(hits.len(), 1);
        assert_eq!(hits[0].1, &cap);
        let d = hits[0].2;
        assert_eq!(d.tokens, 111);
        assert_eq!(d.wall_ms, 222);
        assert_eq!(d.tool_calls, 3);
        assert_eq!(d.subprocess_ms, 444);
        assert_eq!(d.memory_bytes, 555_555);
    }

    #[test]
    fn ledger_snapshot_round_trips_all_five_ledger_axes_through_serde() {
        // Phase 1 hardening — symmetric companion to
        // sealed_mutations_preserves_all_five_debit_axes_field_for_field.
        // BudgetLedger has 5 axes (tokens_used, wall_used_ms,
        // tool_calls_used, subprocess_used_ms, memory_bytes_used). The
        // existing log_round_trips_through_json only populates 2 of
        // them. A silent field drop in the RunEventEntry::LedgerSnapshot
        // encoding (e.g. forgetting to serialise memory_bytes_used)
        // would silently truncate replay-state and skew every
        // ledger_at_ordinal lookup downstream. Pin all 5 axes
        // surviving the JSON round-trip + the ledger_at_ordinal read
        // path.
        let mut log = RunEventLog::new();
        let snapshot = BudgetLedger {
            tokens_used: 111,
            wall_used_ms: 222,
            tool_calls_used: 3,
            subprocess_used_ms: 444,
            memory_bytes_used: 555_555,
        };
        let snap_ord = log.append_ledger_snapshot(snapshot);

        // Round-trip via JSON.
        let s = serde_json::to_string(&log).expect("serialise");
        let back: RunEventLog = serde_json::from_str(&s).expect("deserialise");

        // Read through the canonical replay path (ledger_at_ordinal).
        let recovered = back
            .ledger_at_ordinal(snap_ord)
            .expect("snapshot present after round-trip");
        assert_eq!(recovered.tokens_used, 111);
        assert_eq!(recovered.wall_used_ms, 222);
        assert_eq!(recovered.tool_calls_used, 3);
        assert_eq!(recovered.subprocess_used_ms, 444);
        assert_eq!(recovered.memory_bytes_used, 555_555);
        // And byte-equal to the original.
        assert_eq!(recovered, snapshot);
        // Root hashes match — full witness chain intact.
        assert_eq!(back.root_hash(), log.root_hash());
    }

    #[test]
    fn sealed_mutations_iterator_can_be_short_circuited() {
        let mut log = RunEventLog::new();
        for i in 0..10u64 {
            log.append_sealed_mutation(
                Hash::from_bytes([(i % 256) as u8; 32]),
                BudgetDebit { tokens: i, ..Default::default() },
            );
        }
        // .take(3) avoids walking the full 10-entry log — proves
        // laziness of the iterator surface.
        let first_three: Vec<_> = log.sealed_mutations().take(3).collect();
        assert_eq!(first_three.len(), 3);
        assert_eq!(first_three[0].2.tokens, 0);
        assert_eq!(first_three[2].2.tokens, 2);
    }

    #[test]
    fn find_tool_calls_returns_calls_with_ordinals_in_order() {
        use crate::agent_runtime_v2::mission::ToolCall;
        let mut log = RunEventLog::new();
        log.append_event(AgentEvent::ReasoningDelta { text: "x".into() });
        let o1 = log.append_event(AgentEvent::ToolCall {
            call: ToolCall {
                name: "vault.read".into(),
                arguments: serde_json::json!({"path": "a"}),
            },
        });
        log.append_event(AgentEvent::FinalText { text: "y".into() });
        let o3 = log.append_event(AgentEvent::ToolCall {
            call: ToolCall {
                name: "vault.write".into(),
                arguments: serde_json::json!({"path": "b"}),
            },
        });
        log.append_event(AgentEvent::Stop { reason: StopReason::EndTurn });

        let hits = log.find_tool_calls();
        assert_eq!(hits.len(), 2);
        assert_eq!(hits[0].0, o1);
        assert_eq!(hits[0].1.name, "vault.read");
        assert_eq!(hits[1].0, o3);
        assert_eq!(hits[1].1.name, "vault.write");
    }

    #[test]
    fn find_tool_calls_empty_when_no_tool_call_events() {
        let mut log = RunEventLog::new();
        log.append_event(AgentEvent::ReasoningDelta { text: "x".into() });
        log.append_event(AgentEvent::Stop { reason: StopReason::EndTurn });
        assert!(log.find_tool_calls().is_empty());
    }

    #[test]
    fn first_event_ordinal_returns_zero_when_non_empty_none_when_empty() {
        let mut log = RunEventLog::new();
        assert_eq!(log.first_event_ordinal(), None);
        log.append_event(AgentEvent::ReasoningDelta { text: "first".into() });
        assert_eq!(log.first_event_ordinal(), Some(0));
        // Adding more entries doesn't shift the first ordinal.
        log.append_event(AgentEvent::Stop { reason: StopReason::EndTurn });
        assert_eq!(log.first_event_ordinal(), Some(0));
    }

    #[test]
    fn stop_count_distinguishes_zero_one_many() {
        let mut log = RunEventLog::new();
        assert_eq!(log.stop_count(), 0);
        log.append_event(AgentEvent::ReasoningDelta { text: "a".into() });
        assert_eq!(log.stop_count(), 0);
        log.append_event(AgentEvent::Stop { reason: StopReason::EndTurn });
        assert_eq!(log.stop_count(), 1);
        // Anomalous: a second Stop after the first (replay anomaly /
        // partial-write recovery). The helper counts it so the audit
        // surface can flag the run.
        log.append_event(AgentEvent::Stop { reason: StopReason::Error });
        assert_eq!(log.stop_count(), 2);
    }

    #[test]
    fn error_count_distinguishes_zero_one_many_and_is_disjoint_from_stop() {
        // Phase 1 hardening — audit-surface helper. Error events
        // terminate with a typed kind rather than a stop reason;
        // a clean run has 0 errors; a failed run has >=1. Helper
        // counts cleanly regardless of how many Stop events follow.
        let mut log = RunEventLog::new();
        assert_eq!(log.error_count(), 0);
        log.append_event(AgentEvent::ReasoningDelta { text: "a".into() });
        assert_eq!(log.error_count(), 0);
        log.append_event(AgentEvent::Error {
            kind: AgentEventErrorKind::Provider,
            message: "transport".into(),
        });
        assert_eq!(log.error_count(), 1);
        // Stop after Error is the typical terminal sequence; error
        // count must not be affected by Stop events.
        log.append_event(AgentEvent::Stop { reason: StopReason::Error });
        assert_eq!(log.error_count(), 1);
        assert_eq!(log.stop_count(), 1);
        // Anomalous double-error case.
        log.append_event(AgentEvent::Error {
            kind: AgentEventErrorKind::BudgetExhausted,
            message: "ran out".into(),
        });
        assert_eq!(log.error_count(), 2);
        assert_eq!(log.stop_count(), 1);
    }

    #[test]
    fn last_stop_event_returns_most_recent_stop() {
        let mut log = RunEventLog::new();
        // No stop yet.
        assert_eq!(log.last_stop_event(), None);
        // Add a Stop, then non-stop events. Latest Stop should still
        // surface even if other events follow (defensive: in practice
        // Stop is terminal so nothing should follow, but the helper
        // shouldn't assume that).
        log.append_event(AgentEvent::Stop { reason: StopReason::ToolUse });
        assert_eq!(log.last_stop_event(), Some(StopReason::ToolUse));
        log.append_event(AgentEvent::ReasoningDelta { text: "x".into() });
        // Most recent Stop is still ToolUse.
        assert_eq!(log.last_stop_event(), Some(StopReason::ToolUse));
        // Add a fresher Stop with different reason.
        log.append_event(AgentEvent::Stop { reason: StopReason::EndTurn });
        assert_eq!(log.last_stop_event(), Some(StopReason::EndTurn));
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
    fn append_ledger_snapshot_increments_snapshot_count_not_sealed_count() {
        // Phase 1 hardening — entry-kind disambiguation. A common
        // refactor bug would be lumping snapshots and sealed
        // mutations into one counter (both involve BudgetLedger /
        // BudgetDebit shapes). This pins that append_ledger_snapshot
        // produces a LedgerSnapshot entry, NOT a SealedMutation:
        //   - sealed count stays at 0
        //   - snapshot count goes 0 → 3
        //   - sealed_mutations() iterator yields nothing
        let mut log = RunEventLog::new();
        let (events_0, sealed_0, snap_0) = log.entry_count_by_kind();
        assert_eq!((events_0, sealed_0, snap_0), (0, 0, 0));

        for _ in 0..3 {
            log.append_ledger_snapshot(BudgetLedger {
                tokens_used: 100,
                ..Default::default()
            });
        }
        let (events_1, sealed_1, snap_1) = log.entry_count_by_kind();
        assert_eq!(
            (events_1, sealed_1, snap_1),
            (0, 0, 3),
            "snapshot must NOT bump sealed count",
        );
        // sealed_mutations iterator agrees: zero hits.
        assert_eq!(log.sealed_mutations().count(), 0);
        // total_tokens_debited only counts SealedMutation entries,
        // not snapshots. 3 snapshots with tokens_used=100 each
        // must NOT contribute to the debited total.
        let (total, count) = log.total_tokens_debited();
        assert_eq!(total, 0);
        assert_eq!(count, 0);
    }

    #[test]
    fn entry_count_by_kind_sealed_field_agrees_with_sealed_mutations_iterator() {
        // Phase 1 hardening — cross-helper consistency. The (events,
        // sealed, snapshots) tuple returned by entry_count_by_kind
        // must agree with sealed_mutations().count() for the sealed
        // axis. A future refactor that switches the entry-encoding
        // shape without updating one helper would surface here.
        let mut log = RunEventLog::new();
        log.append_event(AgentEvent::ReasoningDelta { text: "r".into() });
        for i in 0..7u64 {
            log.append_sealed_mutation(
                Hash::from_bytes([(i as u8) ^ 0x5C; 32]),
                BudgetDebit { tokens: i, ..Default::default() },
            );
        }
        log.append_ledger_snapshot(BudgetLedger::default());
        log.append_event(AgentEvent::Stop { reason: StopReason::EndTurn });

        let (events, sealed_tuple, snapshots) = log.entry_count_by_kind();
        let sealed_iter = log.sealed_mutations().count();
        assert_eq!(
            sealed_tuple, sealed_iter,
            "entry_count_by_kind.sealed must equal sealed_mutations().count()",
        );
        assert_eq!(sealed_tuple, 7);
        assert_eq!(events, 2);
        assert_eq!(snapshots, 1);
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
    fn detect_capability_reuse_handles_zero_max_uses_revoked_capability_case() {
        // Phase 1 hardening — boundary completeness. The existing
        // tests pin max_uses ∈ {1, 2, 3, 5, 10}. The max_uses=0
        // boundary (capability is REVOKED — any usage is overage)
        // is unpinned. This case matters for the audit surface:
        // detecting any usage of a revoked-after-the-fact capability.
        let mut log = RunEventLog::new();
        let revoked = Hash::from_bytes([42u8; 32]);

        // No uses + max_uses=0 → overage 0 (saturating_sub(0,0)).
        assert_eq!(log.detect_capability_reuse(&revoked, 0), 0);

        // 1 use + max_uses=0 → overage 1.
        log.append_sealed_mutation(revoked, BudgetDebit::default());
        assert_eq!(log.detect_capability_reuse(&revoked, 0), 1);

        // 5 uses + max_uses=0 → overage 5.
        for _ in 0..4 {
            log.append_sealed_mutation(revoked, BudgetDebit::default());
        }
        assert_eq!(log.detect_capability_reuse(&revoked, 0), 5);

        // Other capability untouched.
        let other = Hash::from_bytes([99u8; 32]);
        assert_eq!(log.detect_capability_reuse(&other, 0), 0);
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
    fn run_event_entry_unknown_kind_tag_fails_to_deserialise() {
        // Phase 1 hardening — seventh leg of the closed-taxonomy
        // guardrail (mode iter-71, AgentEvent event_type iter-73,
        // StopReason iter-74, AgentEventErrorKind iter-75, VariantTier
        // iter-78, CliAdapter iter-80). RunEventEntry is the
        // single MOST replay-critical enum in v2: it drives the
        // entire RunEventLog persistence shape. A future #[serde(other)]
        // catch-all or case-insensitive shim could absorb a stray
        // row from a tampered / cross-version log and route it to
        // a default kind — corrupting replay deterministically AND
        // silently (root_hash recomputes fine on the wrong kind).
        //
        // 3 valid tag values: event, sealed_mutation, ledger_snapshot.
        // Anything else must fail to deserialise.
        for bad in [
            // Unknown vocab (adjacent terms)
            r#"{"kind":"witness","ordinal":0}"#,
            r#"{"kind":"audit","ordinal":0}"#,
            r#"{"kind":"snapshot","ordinal":0}"#,
            r#"{"kind":"mutation","ordinal":0,"capability_hash":"00","debit":{}}"#,
            // Case variants of valid tags
            r#"{"kind":"Event","ordinal":0}"#,
            r#"{"kind":"EVENT","ordinal":0}"#,
            r#"{"kind":"sealedMutation","ordinal":0}"#,
            r#"{"kind":"Ledger_Snapshot","ordinal":0}"#,
            // Kebab-case drift
            r#"{"kind":"sealed-mutation","ordinal":0}"#,
            r#"{"kind":"ledger-snapshot","ordinal":0}"#,
            // Missing kind entirely
            r#"{"ordinal":0}"#,
        ] {
            let r: Result<RunEventEntry, _> = serde_json::from_str(bad);
            assert!(
                r.is_err(),
                "unknown kind tag in {bad} must fail to deserialise"
            );
        }
        // Positive sanity: a valid event tag still deserialises.
        let ok: RunEventEntry = serde_json::from_str(
            r#"{"kind":"event","ordinal":42,"event":{"event_type":"final_text","text":"x"}}"#,
        )
        .expect("valid kind tag still deserialises");
        match ok {
            RunEventEntry::Event { ordinal, .. } => assert_eq!(ordinal, 42),
            other => panic!("expected Event variant, got {other:?}"),
        }
    }

    #[test]
    fn run_event_entry_serde_tolerates_unknown_extra_fields_per_current_doctrine() {
        // Phase 1 hardening — fifth leg of the unknown-fields
        // tolerance series (AgentBlueprint iter-121, AnswerPacket
        // iter-122, MissionPacket iter-123, MutationEnvelope iter-124,
        // RunEventEntry here). RunEventEntry is the row shape
        // persisted in .epbundle replay artifacts; a v3 row with
        // an extra audit annotation must still deserialise under
        // a v2 reader (forward-compat for cross-version replay).
        //
        // The internally-tagged enum (#[serde(tag = "kind")]) uses
        // serde's default lenient behaviour — unknown fields
        // alongside the known ones in a variant's payload are
        // dropped, not rejected.
        let event_json = r#"{
            "kind": "event",
            "ordinal": 7,
            "event": {"event_type":"final_text","text":"x"},
            "future_audit_field": "v3-experimental",
            "another_unknown": 42
        }"#;
        let parsed: RunEventEntry =
            serde_json::from_str(event_json).expect("unknown fields tolerated on event row");
        match parsed {
            RunEventEntry::Event { ordinal, event } => {
                assert_eq!(ordinal, 7);
                match event {
                    AgentEvent::FinalText { text } => assert_eq!(text, "x"),
                    other => panic!("expected FinalText, got {other:?}"),
                }
            }
            other => panic!("expected Event variant, got {other:?}"),
        }
        // Same tolerance on the SealedMutation variant. Build a
        // real entry first to capture the correct Hash JSON shape
        // (byte array, not hex string), then inject an extra field.
        let sealed = RunEventEntry::SealedMutation {
            ordinal: 9,
            capability_hash: Hash::from_bytes([1u8; 32]),
            debit: BudgetDebit { tokens: 5, ..Default::default() },
        };
        let sealed_s = serde_json::to_string(&sealed).expect("serialise sealed");
        // Insert before the FINAL closing brace (not trim_end_matches,
        // which strips consecutive `}}` and breaks nested objects).
        let last_brace = sealed_s.rfind('}').expect("JSON ends with }");
        let mut augmented = String::with_capacity(sealed_s.len() + 64);
        augmented.push_str(&sealed_s[..last_brace]);
        augmented.push_str(r#","v3_provenance_tag":"experimental"}"#);
        let parsed_sealed: RunEventEntry =
            serde_json::from_str(&augmented).expect("unknown field tolerated on sealed row");
        assert_eq!(parsed_sealed, sealed);
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
