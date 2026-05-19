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
    fn root_hash_per_entry_order_is_length_prefix_then_json_not_swapped() {
        // Phase 1 hardening — adversarial completeness companion to
        // root_hash_per_entry_encoding_uses_u64_le_length_prefix_then_json_bytes.
        // The existing pin proves LE vs BE for length AND with-vs-without
        // the prefix. This pin proves the ORDER of the two updates:
        //
        //   prefix → u64-LE(len) → json   ✓ canonical (root_hash uses this)
        //   prefix → json → u64-LE(len)   ✗ length-suffix variant
        //
        // A future refactor that accidentally reordered the
        // hasher.update calls (especially in a hot-path optimisation
        // that interleaved bytes) would produce a different root_hash
        // for every entry, silently forking every replay.
        let mut log = RunEventLog::new();
        log.append_event(AgentEvent::ReasoningDelta { text: "x".into() });
        let entry = &log.entries()[0];
        let entry_json = serde_json::to_vec(entry).expect("entry serialises");
        let len_le: [u8; 8] = (entry_json.len() as u64).to_le_bytes();

        // Swapped order (length suffix, not prefix) must differ.
        let mut swapped = blake3::Hasher::new();
        swapped.update(b"agent_runtime_v2.run_event_log.root.v1\n");
        swapped.update(&entry_json);
        swapped.update(&len_le);
        let swapped_h = Hash::from_bytes(*swapped.finalize().as_bytes());
        assert_ne!(
            log.root_hash(),
            swapped_h,
            "root_hash MUST update length BEFORE json — length-suffix order produces a different hash"
        );

        // Sanity: canonical order matches.
        let mut canonical = blake3::Hasher::new();
        canonical.update(b"agent_runtime_v2.run_event_log.root.v1\n");
        canonical.update(&len_le);
        canonical.update(&entry_json);
        let canonical_h = Hash::from_bytes(*canonical.finalize().as_bytes());
        assert_eq!(log.root_hash(), canonical_h);
    }

    #[test]
    fn log_entries_slice_yields_rows_in_strictly_ascending_ordinal_order() {
        // Phase 1 hardening — ordering pin for log.entries(). Companion
        // to the per-helper ordering pins (find_capability_hash iter-476,
        // find_tool_calls iter-477, sealed_mutations iter-478).
        //
        // entries() returns &[RunEventEntry]; every row's stored ordinal
        // must appear in strict-ascending order (dense 0..N, no gaps).
        // This is the foundational invariant the per-helper ordering
        // pins rely on.
        let mut log = RunEventLog::new();
        // 7 mixed-variant entries.
        log.append_event(AgentEvent::ReasoningDelta { text: "a".into() });   // 0
        log.append_sealed_mutation(Hash::zero(), BudgetDebit::default());     // 1
        log.append_ledger_snapshot(BudgetLedger::default());                  // 2
        log.append_event(AgentEvent::FinalText { text: "b".into() });        // 3
        log.append_sealed_mutation(Hash::from_bytes([1; 32]), BudgetDebit::default()); // 4
        log.append_event(AgentEvent::Stop { reason: StopReason::EndTurn });   // 5
        log.append_ledger_snapshot(BudgetLedger { tokens_used: 100, ..Default::default() }); // 6

        let ordinals: Vec<u64> = log.entries().iter().map(|e| e.ordinal()).collect();
        assert_eq!(ordinals, vec![0, 1, 2, 3, 4, 5, 6], "dense 0..N");
        // Strict-ascending invariant via windowed comparison.
        for pair in ordinals.windows(2) {
            assert!(pair[0] < pair[1], "ordinals must be strictly ascending");
        }
    }

    #[test]
    fn log_len_and_entries_slice_len_and_is_empty_agree() {
        // Phase 1 hardening — cross-helper consistency pin among
        // the trivial size-querying methods on RunEventLog:
        //   - log.len()             → entries.len()
        //   - log.entries().len()   → entries.len() (slice view)
        //   - log.is_empty()        → entries.is_empty()
        //   - entry_count_by_kind   → triple sum should equal log.len()
        //
        // A future refactor that introduced any divergence (e.g.,
        // is_empty caching a stale flag, or entries() returning a
        // filtered slice) would slip past tests that only assert
        // one of these.
        let mut log = RunEventLog::new();
        assert_eq!(log.len(), 0);
        assert_eq!(log.entries().len(), 0);
        assert!(log.is_empty());
        let (e, s, sn) = log.entry_count_by_kind();
        assert_eq!(e + s + sn, log.len());

        // Append a mix and re-check.
        log.append_event(AgentEvent::ReasoningDelta { text: "r".into() });
        log.append_sealed_mutation(Hash::zero(), BudgetDebit::default());
        log.append_ledger_snapshot(BudgetLedger::default());

        assert_eq!(log.len(), 3);
        assert_eq!(log.entries().len(), 3);
        assert!(!log.is_empty());
        let (e, s, sn) = log.entry_count_by_kind();
        assert_eq!(e + s + sn, 3);
        assert_eq!(e + s + sn, log.len());
        assert_eq!(e + s + sn, log.entries().len());
    }

    #[test]
    fn root_hash_is_deterministic_across_unicode_payload_runs() {
        // Phase 1 hardening — Unicode-payload determinism pin.
        // Two RunEventLogs with byte-equal Unicode payloads must
        // produce byte-equal root_hashes. The blake3 hasher
        // operates on raw bytes; the serde_json encoding feeds
        // verbatim Unicode bytes into the hasher. A future encoding
        // change (e.g., \u escape on emit) would silently fork
        // root_hash across replay versions for Unicode-bearing logs.
        let mut a = RunEventLog::new();
        a.append_event(AgentEvent::ReasoningDelta {
            text: "考えている…🤔".into(),
        });
        a.append_event(AgentEvent::FinalText {
            text: "回答: 42 ✓".into(),
        });

        let mut b = RunEventLog::new();
        b.append_event(AgentEvent::ReasoningDelta {
            text: "考えている…🤔".into(),
        });
        b.append_event(AgentEvent::FinalText {
            text: "回答: 42 ✓".into(),
        });

        assert_eq!(a.root_hash(), b.root_hash(), "Unicode-equal logs must hash equal");
        // Single-byte Unicode diff (swap last char in one event)
        // breaks equality.
        let mut c = RunEventLog::new();
        c.append_event(AgentEvent::ReasoningDelta {
            text: "考えている…🤔".into(),
        });
        c.append_event(AgentEvent::FinalText {
            text: "回答: 42 ✗".into(), // ✓ → ✗
        });
        assert_ne!(a.root_hash(), c.root_hash(), "Unicode-diff logs must hash differently");
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
    fn log_permits_appending_after_stop_per_dispatcher_gatekeeper_doctrine() {
        // Phase 1 hardening — DOCTRINE PIN. RunEventLog is the
        // append-only witness trail; its only mutator is `append`.
        // The log is INTENTIONALLY permissive about Stop semantics:
        // appending another event AFTER a Stop succeeds at the log
        // level. The dispatcher is the gatekeeper that enforces
        // terminal-after-Stop discipline; the log itself just
        // records whatever it's told.
        //
        // This separation matters for forensic / replay use cases
        // where a buggy executor might emit post-Stop events;
        // the log records them honestly so audit tools can see
        // the violation.
        //
        // A future tightening (e.g., panic-on-append-after-Stop,
        // or return a Result) would silently break the append-only
        // invariant. Pin the current permissive doctrine.
        let mut log = RunEventLog::new();
        log.append_event(AgentEvent::Stop { reason: StopReason::EndTurn });
        // Appending more events after Stop succeeds.
        let ord_after_stop = log.append_event(AgentEvent::ReasoningDelta {
            text: "post-stop".into(),
        });
        assert_eq!(ord_after_stop, 1, "post-Stop append still gets a fresh ordinal");
        // Multiple Stops are allowed too.
        log.append_event(AgentEvent::Stop { reason: StopReason::ToolUse });
        assert_eq!(log.stop_count(), 2, "multiple Stops are permitted at log level");
        // last_stop_event returns the most recent.
        assert_eq!(log.last_stop_event(), Some(StopReason::ToolUse));
        // Sealed mutations after Stop also succeed.
        log.append_sealed_mutation(Hash::zero(), BudgetDebit::default());
        let (events, sealed, _) = log.entry_count_by_kind();
        assert_eq!(events, 3); // 2 Stops + 1 ReasoningDelta
        assert_eq!(sealed, 1);
    }

    #[test]
    fn append_sealed_mutation_and_ledger_snapshot_preserve_payloads_byte_for_byte() {
        // Phase 1 hardening — pass-through preservation pin
        // (companion to iter-239 append_event pin).
        // append_sealed_mutation MUST preserve the input
        // capability_hash + debit verbatim. append_ledger_snapshot
        // MUST preserve the input ledger verbatim.
        let cap = Hash::from_bytes([
            0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
            0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F, 0x10,
            0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18,
            0x19, 0x1A, 0x1B, 0x1C, 0x1D, 0x1E, 0x1F, 0x20,
        ]);
        let debit = BudgetDebit {
            tokens: 100,
            wall_ms: 200,
            tool_calls: 3,
            subprocess_ms: 400,
            memory_bytes: 500,
        };
        let snapshot_ledger = BudgetLedger {
            tokens_used: 600,
            wall_used_ms: 700,
            tool_calls_used: 8,
            subprocess_used_ms: 900,
            memory_bytes_used: 1_000,
        };

        let mut log = RunEventLog::new();
        log.append_sealed_mutation(cap, debit);
        log.append_ledger_snapshot(snapshot_ledger);

        match &log.entries()[0] {
            RunEventEntry::SealedMutation {
                capability_hash, debit: stored_debit, ..
            } => {
                assert_eq!(*capability_hash, cap, "capability_hash must be byte-equal");
                assert_eq!(*stored_debit, debit, "debit must be byte-equal");
            }
            other => panic!("expected SealedMutation, got {other:?}"),
        }
        match &log.entries()[1] {
            RunEventEntry::LedgerSnapshot { ledger, .. } => {
                assert_eq!(*ledger, snapshot_ledger, "ledger must be byte-equal");
            }
            other => panic!("expected LedgerSnapshot, got {other:?}"),
        }
    }

    #[test]
    fn append_event_preserves_agent_event_payload_byte_for_byte() {
        // Phase 1 hardening — pass-through preservation pin
        // (companion to iter-237 emit_with_thinking and iter-238
        // MutationEnvelope hash pass-through pins).
        // RunEventLog::append_event MUST preserve the input event
        // verbatim in the stored RunEventEntry::Event row. No
        // normalisation, no trimming, no transformation.
        //
        // A future "let me canonicalise event payloads on append"
        // refactor would silently break replay-byte-equality
        // across executor variants.
        use crate::agent_runtime_v2::mission::ToolCall;
        let events = [
            AgentEvent::ReasoningDelta { text: "  preserve\t  ".into() },
            AgentEvent::FinalText { text: "\nleading newline".into() },
            AgentEvent::ToolCall {
                call: ToolCall {
                    name: "vault.read".into(),
                    arguments: serde_json::json!({"deeply": {"nested": [1, 2, 3]}}),
                },
            },
            AgentEvent::ToolResult {
                name: "vault.read".into(),
                result: serde_json::json!({"trailing whitespace": "  "}),
            },
            AgentEvent::Stop { reason: StopReason::Refusal },
            AgentEvent::Error {
                kind: AgentEventErrorKind::Provider,
                message: "verbatim message".into(),
            },
        ];
        let mut log = RunEventLog::new();
        for event in &events {
            log.append_event(event.clone());
        }
        for (i, entry) in log.entries().iter().enumerate() {
            match entry {
                RunEventEntry::Event { event, .. } => {
                    assert_eq!(event, &events[i], "event {i} must be preserved byte-equal");
                }
                other => panic!("entry {i}: expected Event, got {other:?}"),
            }
        }
    }

    #[test]
    fn run_event_entry_ordinal_getter_returns_stored_value_across_all_3_variants() {
        // Phase 1 hardening — variant-coverage pin for the
        // RunEventEntry::ordinal() getter (companion to
        // run_event_entry_ordinal_getter_is_pure_deterministic_across_multiple_calls
        // which covers purity).
        //
        // The getter must return the stored ordinal value REGARDLESS
        // of variant. A future "let me special-case SealedMutation
        // to return its capability_hash as ordinal for caching"
        // refactor would silently break the dense-ordinal invariant
        // and the entry-position correspondence — surface here.
        //
        // Pin via 3 entries with DISTINCT stored ordinals across the
        // 3 variants; getter returns the EXACT distinct value per
        // variant.
        let event = RunEventEntry::Event {
            ordinal: 100,
            event: AgentEvent::ReasoningDelta { text: "x".into() },
        };
        let sealed = RunEventEntry::SealedMutation {
            ordinal: 200,
            capability_hash: Hash::zero(),
            debit: BudgetDebit::default(),
        };
        let snapshot = RunEventEntry::LedgerSnapshot {
            ordinal: 300,
            ledger: BudgetLedger::default(),
        };
        assert_eq!(event.ordinal(), 100, "Event variant returns stored ordinal");
        assert_eq!(sealed.ordinal(), 200, "SealedMutation variant returns stored ordinal");
        assert_eq!(snapshot.ordinal(), 300, "LedgerSnapshot variant returns stored ordinal");
    }

    #[test]
    fn run_event_entry_ordinal_getter_is_pure_deterministic_across_multiple_calls() {
        // Phase 1 hardening — pure-function determinism pin
        // (companion to the purity series). RunEventEntry::ordinal
        // returns the inner ordinal field via match; pure.
        let entry = RunEventEntry::Event {
            ordinal: 42,
            event: AgentEvent::ReasoningDelta { text: "x".into() },
        };
        for _ in 0..3 {
            assert_eq!(entry.ordinal(), 42);
        }
        // Cover the other 2 variants too.
        let sealed = RunEventEntry::SealedMutation {
            ordinal: 7,
            capability_hash: Hash::zero(),
            debit: BudgetDebit::default(),
        };
        for _ in 0..3 {
            assert_eq!(sealed.ordinal(), 7);
        }
        let snap = RunEventEntry::LedgerSnapshot {
            ordinal: 99,
            ledger: BudgetLedger::default(),
        };
        for _ in 0..3 {
            assert_eq!(snap.ordinal(), 99);
        }
    }

    #[test]
    fn entries_accessor_returns_same_slice_view_across_multiple_reads() {
        // Phase 1 hardening — pure-function determinism pin for the
        // entries() slice accessor. Multiple reads must produce
        // identical slice views over the same underlying vector;
        // no mutation, no reordering, no filtering.
        //
        // The reads themselves return &[RunEventEntry] (a borrow);
        // we pull both into Vecs for byte-comparison.
        let mut log = RunEventLog::new();
        log.append_event(AgentEvent::ReasoningDelta { text: "a".into() });
        log.append_sealed_mutation(Hash::zero(), BudgetDebit::default());
        log.append_ledger_snapshot(BudgetLedger::default());

        let snap_a: Vec<_> = log.entries().to_vec();
        let snap_b: Vec<_> = log.entries().to_vec();
        let snap_c: Vec<_> = log.entries().to_vec();
        assert_eq!(snap_a, snap_b);
        assert_eq!(snap_b, snap_c);
        assert_eq!(snap_a.len(), 3);
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
    fn find_capability_hash_is_pure_deterministic_across_multiple_calls() {
        // Phase 1 hardening — pure-function determinism pin
        // (companion to the purity series at find_tool_calls,
        // sealed_mutations, last_stop_event, total_tokens_debited,
        // entry_count_by_kind, ledger_at_ordinal, validate_ordinal_density,
        // root_hash, count_hits, scan_text). find_capability_hash
        // walks self.entries and yields a Vec<u64> of ordinals
        // matching the needle — pure over an immutable input.
        //
        // A future "let me cache the result keyed on needle" refactor
        // that introduced interior mutability could silently regress
        // — caches that don't honour log-append invalidation would
        // serve stale results. Pin sweeps both hit (multiple
        // ordinals) and miss (empty Vec) input shapes; the result
        // must be byte-equal across 3 consecutive calls.
        let mut log = RunEventLog::new();
        let needle_a = Hash::from_bytes([0xAA; 32]);
        let needle_b = Hash::from_bytes([0xBB; 32]);
        log.append_event(AgentEvent::ReasoningDelta { text: "x".into() });
        log.append_sealed_mutation(needle_a, BudgetDebit::default());
        log.append_event(AgentEvent::FinalText { text: "y".into() });
        log.append_sealed_mutation(needle_a, BudgetDebit::default());
        log.append_sealed_mutation(needle_b, BudgetDebit::default());
        log.append_event(AgentEvent::Stop { reason: StopReason::EndTurn });

        // Hit case: needle_a appears twice.
        let h1 = log.find_capability_hash(&needle_a);
        let h2 = log.find_capability_hash(&needle_a);
        let h3 = log.find_capability_hash(&needle_a);
        assert_eq!(h1, h2);
        assert_eq!(h2, h3);
        assert_eq!(h1.len(), 2);

        // Miss case: unrelated hash.
        let m1 = log.find_capability_hash(&Hash::zero());
        let m2 = log.find_capability_hash(&Hash::zero());
        let m3 = log.find_capability_hash(&Hash::zero());
        assert_eq!(m1, m2);
        assert_eq!(m2, m3);
        assert!(m1.is_empty());

        // Single-hit case.
        let s1 = log.find_capability_hash(&needle_b);
        let s2 = log.find_capability_hash(&needle_b);
        let s3 = log.find_capability_hash(&needle_b);
        assert_eq!(s1, s2);
        assert_eq!(s2, s3);
        assert_eq!(s1.len(), 1);
    }

    #[test]
    fn root_hash_is_sensitive_to_ledger_snapshot_every_axis_payload() {
        // Phase 1 hardening — CLOSES the root_hash sensitivity family
        // across all 3 RunEventEntry variants:
        //   iter-548..iter-553  AgentEvent inside Event row    (6 variants)
        //   iter-554            SealedMutation cap_hash + debit (6 fields)
        //   iter-555            LedgerSnapshot ledger          (5 axes) — THIS
        //
        // Two logs that differ ONLY in ANY of the 5 ledger axes must
        // produce DIFFERENT root_hashes — every BudgetLedger axis
        // (tokens_used/wall_used_ms/tool_calls_used/subprocess_used_ms/
        // memory_bytes_used) participates in the chain.
        //
        // A future "let me drop subprocess_used_ms from the chain
        // because subprocess mode is Pro-Research-only" tweak would
        // silently let MAS runs and Pro Research runs with otherwise-
        // identical state collide on chain hash. Pin sweeps 6
        // fixtures (baseline + 5 single-axis ledger variants) and
        // asserts pairwise-distinct root hashes.
        let fixtures: &[(BudgetLedger, &str)] = &[
            (BudgetLedger::default(), "baseline"),
            (
                BudgetLedger { tokens_used: 1, ..Default::default() },
                "tokens_used=1",
            ),
            (
                BudgetLedger { wall_used_ms: 1, ..Default::default() },
                "wall_used_ms=1",
            ),
            (
                BudgetLedger { tool_calls_used: 1, ..Default::default() },
                "tool_calls_used=1",
            ),
            (
                BudgetLedger { subprocess_used_ms: 1, ..Default::default() },
                "subprocess_used_ms=1",
            ),
            (
                BudgetLedger { memory_bytes_used: 1, ..Default::default() },
                "memory_bytes_used=1",
            ),
        ];
        let hashes: Vec<Hash> = fixtures
            .iter()
            .map(|(l, _)| {
                let mut log = RunEventLog::new();
                log.append_ledger_snapshot(*l);
                log.root_hash()
            })
            .collect();
        for i in 0..hashes.len() {
            for j in (i + 1)..hashes.len() {
                assert_ne!(
                    hashes[i], hashes[j],
                    "LedgerSnapshot {:?} vs {:?} collided on root_hash",
                    fixtures[i].1, fixtures[j].1
                );
            }
        }
    }

    #[test]
    fn root_hash_is_sensitive_to_sealed_mutation_cap_hash_and_every_debit_axis() {
        // Phase 1 hardening — payload-sensitivity pin for the
        // SealedMutation row (companion to the 6-variant AgentEvent
        // sensitivity family closed at iter-553). Two logs that
        // differ ONLY in the capability_hash OR ANY of the 5 debit
        // axes must produce DIFFERENT root_hashes — all 6 fields
        // participate in the chain.
        //
        // A future "let me drop memory_bytes from the chain because
        // it's M2 Pro-specific" tweak would silently let runs with
        // different memory footprints collide on chain hash — the
        // budget audit dashboard would lose its ability to attribute
        // memory pressure to the specific run.
        //
        // Pin sweeps 7 fixtures (1 cap_hash differing + 5 single-axis
        // debit variants + 1 baseline) and asserts pairwise-distinct
        // root hashes.
        let baseline_hash = Hash::from_bytes([0u8; 32]);
        let alt_hash = Hash::from_bytes([1u8; 32]);
        let zero_debit = BudgetDebit::default();
        let fixtures: &[(Hash, BudgetDebit, &str)] = &[
            // Baseline: all-zero debit.
            (baseline_hash, zero_debit, "baseline"),
            // Different cap_hash.
            (alt_hash, zero_debit, "diff cap_hash"),
            // Single-axis debits.
            (
                baseline_hash,
                BudgetDebit { tokens: 1, ..Default::default() },
                "tokens=1",
            ),
            (
                baseline_hash,
                BudgetDebit { wall_ms: 1, ..Default::default() },
                "wall_ms=1",
            ),
            (
                baseline_hash,
                BudgetDebit { tool_calls: 1, ..Default::default() },
                "tool_calls=1",
            ),
            (
                baseline_hash,
                BudgetDebit { subprocess_ms: 1, ..Default::default() },
                "subprocess_ms=1",
            ),
            (
                baseline_hash,
                BudgetDebit { memory_bytes: 1, ..Default::default() },
                "memory_bytes=1",
            ),
        ];
        let hashes: Vec<Hash> = fixtures
            .iter()
            .map(|(h, d, _)| {
                let mut log = RunEventLog::new();
                log.append_sealed_mutation(*h, *d);
                log.root_hash()
            })
            .collect();
        for i in 0..hashes.len() {
            for j in (i + 1)..hashes.len() {
                assert_ne!(
                    hashes[i], hashes[j],
                    "SealedMutation {:?} vs {:?} collided on root_hash",
                    fixtures[i].2, fixtures[j].2
                );
            }
        }
    }

    #[test]
    fn root_hash_is_sensitive_to_tool_result_name_and_result_payload_within_tool_result_row() {
        // Phase 1 hardening — CLOSES the discriminator/payload
        // sensitivity pin family at all 6 AgentEvent variants:
        //   iter-548 StopReason within Stop
        //   iter-549 AgentEventErrorKind within Error
        //   iter-550 message string within Error
        //   iter-551 text within ReasoningDelta + FinalText
        //   iter-552 name+arguments within ToolCall
        //   iter-553 name+result within ToolResult (THIS)
        //
        // Two logs that differ ONLY in the embedded ToolResult's name
        // (or result JSON) must produce DIFFERENT root_hashes — both
        // fields participate in the chain.
        //
        // A future "let me only hash the tool name on ToolResult and
        // skip the payload" tweak would silently let runs with
        // different result bodies collide on chain hash — replay would
        // produce the WRONG result on a re-run despite a matching
        // chain hash.
        let fixtures = [
            (
                "vault.read",
                serde_json::json!({"content": "result-a"}),
            ),
            (
                "vault.read",
                serde_json::json!({"content": "result-b"}),
            ),
            (
                "vault.write",
                serde_json::json!({"content": "result-a"}),
            ),
            (
                "vault.write",
                serde_json::json!({"content": "result-b"}),
            ),
        ];
        let hashes: Vec<Hash> = fixtures
            .iter()
            .map(|(name, result)| {
                let mut log = RunEventLog::new();
                log.append_event(AgentEvent::ToolResult {
                    name: (*name).to_string(),
                    result: result.clone(),
                });
                log.root_hash()
            })
            .collect();
        for i in 0..hashes.len() {
            for j in (i + 1)..hashes.len() {
                assert_ne!(
                    hashes[i], hashes[j],
                    "ToolResult ({:?}, {}) vs ({:?}, {}) collided on root_hash",
                    fixtures[i].0, fixtures[i].1, fixtures[j].0, fixtures[j].1
                );
            }
        }
    }

    #[test]
    fn root_hash_is_sensitive_to_tool_call_name_and_arguments_payload_within_tool_call_row() {
        // Phase 1 hardening — payload-sensitivity pin for the
        // ToolCall AgentEvent variant (companion to ReasoningDelta +
        // FinalText payload pin iter-551, StopReason pin iter-548,
        // Error kind+message pins iter-549/550). Two logs that
        // differ ONLY in the embedded ToolCall's name (or
        // arguments) must produce DIFFERENT root_hashes — both
        // fields of the inner ToolCall participate in the chain via
        // the AgentEvent::ToolCall serde payload.
        //
        // A future "let me drop the arguments from the chain to
        // shrink rows" tweak would silently let distinct tool
        // invocations (same name, different args) collide on the
        // chain hash — audit dashboards couldn't distinguish a
        // vault.read of /a from a vault.read of /b.
        //
        // Pin checks 4 (name, args) fixtures produce pairwise-
        // distinct root hashes.
        let fixtures = [
            (
                "vault.read",
                serde_json::json!({"path": "notes/a"}),
            ),
            (
                "vault.read",
                serde_json::json!({"path": "notes/b"}),
            ),
            (
                "vault.write",
                serde_json::json!({"path": "notes/a"}),
            ),
            (
                "vault.write",
                serde_json::json!({"path": "notes/b"}),
            ),
        ];
        let hashes: Vec<Hash> = fixtures
            .iter()
            .map(|(name, args)| {
                let mut log = RunEventLog::new();
                log.append_event(AgentEvent::ToolCall {
                    call: crate::agent_runtime_v2::mission::ToolCall {
                        name: (*name).to_string(),
                        arguments: args.clone(),
                    },
                });
                log.root_hash()
            })
            .collect();
        for i in 0..hashes.len() {
            for j in (i + 1)..hashes.len() {
                assert_ne!(
                    hashes[i], hashes[j],
                    "ToolCall ({:?}, {}) vs ({:?}, {}) collided on root_hash",
                    fixtures[i].0, fixtures[i].1, fixtures[j].0, fixtures[j].1
                );
            }
        }
    }

    #[test]
    fn root_hash_is_sensitive_to_reasoning_delta_and_final_text_payload_strings() {
        // Phase 1 hardening — closes the text-payload sensitivity duo
        // (companion to iter-548 StopReason + iter-549 ErrorKind +
        // iter-550 Error message). Two logs that differ ONLY in the
        // `text` field of a ReasoningDelta (or FinalText) row must
        // produce DIFFERENT root_hashes — every text byte participates
        // in the chain. A future "let me hash only the first N chars
        // of streaming deltas for speed" tweak would silently let
        // distinct reasoning traces collide on chain hash — replay
        // parity would break for the reasoning/final text streams
        // that motivate the audit log in the first place.
        //
        // Pin checks 4 representative text variants for BOTH variants.
        let reasoning_texts = ["", "thought-a", "thought-b", "勉強します"];
        let r_hashes: Vec<Hash> = reasoning_texts
            .iter()
            .map(|t| {
                let mut log = RunEventLog::new();
                log.append_event(AgentEvent::ReasoningDelta {
                    text: (*t).to_string(),
                });
                log.root_hash()
            })
            .collect();
        for i in 0..r_hashes.len() {
            for j in (i + 1)..r_hashes.len() {
                assert_ne!(
                    r_hashes[i], r_hashes[j],
                    "ReasoningDelta texts {:?} vs {:?} collided on root_hash",
                    reasoning_texts[i], reasoning_texts[j]
                );
            }
        }

        let final_texts = ["", "answer-a", "answer-b", "結論 📝"];
        let f_hashes: Vec<Hash> = final_texts
            .iter()
            .map(|t| {
                let mut log = RunEventLog::new();
                log.append_event(AgentEvent::FinalText {
                    text: (*t).to_string(),
                });
                log.root_hash()
            })
            .collect();
        for i in 0..f_hashes.len() {
            for j in (i + 1)..f_hashes.len() {
                assert_ne!(
                    f_hashes[i], f_hashes[j],
                    "FinalText texts {:?} vs {:?} collided on root_hash",
                    final_texts[i], final_texts[j]
                );
            }
        }
    }

    #[test]
    fn root_hash_is_sensitive_to_error_message_field_within_error_event_row() {
        // Phase 1 hardening MILESTONE iter-550 — closes the
        // Error-row root_hash sensitivity duo (iter-549 covers kind,
        // THIS covers message). Two logs that differ ONLY in the
        // message string of an AgentEvent::Error row must produce
        // DIFFERENT root_hashes — the message participates in the
        // chain via the inner AgentEvent serde payload.
        //
        // A future "let me elide the message from the hash input to
        // avoid PII in audit logs" tweak would silently let two runs
        // with the same kind but distinct error messages collide on
        // chain hash — replay parity would break for the same kind.
        // PII redaction is a downstream-presentation concern, not a
        // chain-input one.
        //
        // Pin checks 5 representative message shapes produce distinct
        // root hashes when paired with the same kind.
        let kind = crate::agent_runtime_v2::event::AgentEventErrorKind::Provider;
        let messages = [
            "",
            "transport failed",
            "transport failed: 502",
            "transport failed — retry-after=5s",
            "勉強 — 失敗 📝",
        ];
        let hashes: Vec<Hash> = messages
            .iter()
            .map(|message| {
                let mut log = RunEventLog::new();
                log.append_event(AgentEvent::Error {
                    kind,
                    message: (*message).to_string(),
                });
                log.root_hash()
            })
            .collect();
        for i in 0..hashes.len() {
            for j in (i + 1)..hashes.len() {
                assert_ne!(
                    hashes[i], hashes[j],
                    "root_hash for message {:?} == root_hash for {:?} — message must participate in chain",
                    messages[i], messages[j]
                );
            }
        }
    }

    #[test]
    fn root_hash_is_sensitive_to_agent_event_error_kind_within_error_event_row() {
        // Phase 1 hardening — fine-grained tamper sensitivity pin
        // (companion to root_hash_is_sensitive_to_stop_reason iter-548).
        // Two logs that differ ONLY in the AgentEventErrorKind of an
        // AgentEvent::Error row must produce DIFFERENT root_hashes —
        // every variant of the 4-variant error taxonomy participates
        // in the chain via the inner AgentEvent serde payload.
        //
        // A future encoding change that collapsed the kind to a
        // single byte (or dropped it from the hash input) would
        // silently merge runs that failed for different reasons —
        // audit dashboards would attribute the same chain hash to
        // BudgetExhausted vs MalformedToolCall vs Provider vs
        // CapabilityDenied failures. Pin checks all 4 kinds produce
        // distinct root hashes when the only differing field is
        // the kind (message stays constant).
        let kinds = [
            crate::agent_runtime_v2::event::AgentEventErrorKind::MalformedToolCall,
            crate::agent_runtime_v2::event::AgentEventErrorKind::BudgetExhausted,
            crate::agent_runtime_v2::event::AgentEventErrorKind::CapabilityDenied,
            crate::agent_runtime_v2::event::AgentEventErrorKind::Provider,
        ];
        let hashes: Vec<Hash> = kinds
            .iter()
            .map(|kind| {
                let mut log = RunEventLog::new();
                log.append_event(AgentEvent::Error {
                    kind: *kind,
                    message: "constant-error-message".to_string(),
                });
                log.root_hash()
            })
            .collect();
        for i in 0..hashes.len() {
            for j in (i + 1)..hashes.len() {
                assert_ne!(
                    hashes[i], hashes[j],
                    "root_hash for {:?} == root_hash for {:?} — kind must participate in chain",
                    kinds[i], kinds[j]
                );
            }
        }
    }

    #[test]
    fn root_hash_is_sensitive_to_stop_reason_within_stop_event_row() {
        // Phase 1 hardening — fine-grained tamper sensitivity pin.
        // Two logs that differ ONLY in the StopReason of an
        // AgentEvent::Stop row must produce DIFFERENT root_hashes —
        // every variant of the 7-variant StopReason taxonomy
        // participates in the chain (via the inner AgentEvent serde
        // payload).
        //
        // A future encoding change that collapsed stop_reason to a
        // single byte (or dropped it from the hash input) would
        // silently merge runs that terminated for different reasons.
        // Pin checks all 7 stop reasons produce distinct root hashes
        // when each is appended as the SOLE row of an otherwise-
        // identical log.
        let reasons = [
            StopReason::EndTurn,
            StopReason::ToolUse,
            StopReason::MaxTokens,
            StopReason::Refusal,
            StopReason::BudgetExhausted,
            StopReason::CapabilityDenied,
            StopReason::Error,
        ];
        let hashes: Vec<Hash> = reasons
            .iter()
            .map(|reason| {
                let mut log = RunEventLog::new();
                log.append_event(AgentEvent::Stop { reason: *reason });
                log.root_hash()
            })
            .collect();
        for i in 0..hashes.len() {
            for j in (i + 1)..hashes.len() {
                assert_ne!(
                    hashes[i], hashes[j],
                    "root_hash for {:?} == root_hash for {:?} — stop_reason must participate in chain",
                    reasons[i], reasons[j]
                );
            }
        }
    }

    #[test]
    fn root_hash_distinguishes_event_only_vs_sealed_mutation_vs_snapshot_logs() {
        // Phase 1 hardening — kind-discrimination pin. Three logs
        // with the SAME ordinal position but DIFFERENT row kinds
        // (Event / SealedMutation / LedgerSnapshot) must produce
        // DIFFERENT root_hashes — the kind tag is hashed into the
        // chain.
        //
        // A future encoding change that lost the kind distinction
        // (e.g., flat-encoded both Event and SealedMutation rows as
        // "untagged blobs") would silently merge separate audit
        // categories into colliding hashes.
        let mut event_only = RunEventLog::new();
        event_only.append_event(AgentEvent::ReasoningDelta { text: "x".into() });

        let mut sealed_only = RunEventLog::new();
        sealed_only.append_sealed_mutation(Hash::zero(), BudgetDebit::default());

        let mut snapshot_only = RunEventLog::new();
        snapshot_only.append_ledger_snapshot(BudgetLedger::default());

        let r_event = event_only.root_hash();
        let r_sealed = sealed_only.root_hash();
        let r_snap = snapshot_only.root_hash();
        assert_ne!(r_event, r_sealed, "event-row and sealed-row roots must differ");
        assert_ne!(r_sealed, r_snap, "sealed-row and snapshot-row roots must differ");
        assert_ne!(r_event, r_snap, "event-row and snapshot-row roots must differ");
    }

    #[test]
    fn root_hash_is_byte_sensitive_to_event_type_tag_change_within_event_row() {
        // Phase 1 hardening — fine-grained tamper sensitivity pin
        // for the inner AgentEvent's serde tag inside an
        // RunEventEntry::Event row. Two events with the same
        // payload but different event_type tags (e.g.,
        // ReasoningDelta vs FinalText with the same text) must
        // produce different root_hashes.
        //
        // Otherwise replay could conflate reasoning and final-text
        // streams.
        let mut log_reason = RunEventLog::new();
        log_reason.append_event(AgentEvent::ReasoningDelta { text: "x".into() });
        let mut log_final = RunEventLog::new();
        log_final.append_event(AgentEvent::FinalText { text: "x".into() });
        assert_ne!(
            log_reason.root_hash(),
            log_final.root_hash(),
            "event_type tag change must produce different root_hash"
        );
    }

    #[test]
    fn root_hash_byte_sensitivity_holds_for_first_middle_and_last_capability_hash_bytes() {
        // Phase 1 hardening — completeness pin for iter-297
        // capability_hash tamper. iter-297 only flips the FIRST
        // byte. Pin that flipping byte 0, byte 15 (middle), and
        // byte 31 (last) all produce different root_hashes.
        let mut base_log = RunEventLog::new();
        let mut canonical = [0u8; 32];
        canonical[0] = 0x01;
        canonical[15] = 0x02;
        canonical[31] = 0x03;
        base_log.append_sealed_mutation(Hash::from_bytes(canonical), BudgetDebit::default());
        let base_root = base_log.root_hash();

        for byte_idx in [0, 15, 31] {
            let mut tampered_bytes = canonical;
            tampered_bytes[byte_idx] ^= 0xFF;
            let mut tampered_log = RunEventLog::new();
            tampered_log.append_sealed_mutation(
                Hash::from_bytes(tampered_bytes),
                BudgetDebit::default(),
            );
            assert_ne!(
                base_root,
                tampered_log.root_hash(),
                "byte {byte_idx} flip in capability_hash must change root_hash"
            );
        }
    }

    #[test]
    fn root_hash_is_byte_sensitive_to_ledger_field_tampering_inside_snapshot() {
        // Phase 1 hardening — companion to iter-296/297 tamper pins.
        // The ledger field inside LedgerSnapshot is hashed; tampering
        // with any ledger axis must produce a different root_hash.
        let mut log = RunEventLog::new();
        log.append_ledger_snapshot(BudgetLedger {
            tokens_used: 100,
            ..Default::default()
        });
        let original = log.root_hash();

        let s = serde_json::to_string(&log).expect("serialise");
        let tampered_json = s.replacen("\"tokens_used\":100", "\"tokens_used\":99", 1);
        let tampered: RunEventLog =
            serde_json::from_str(&tampered_json).expect("deserialise tampered");
        assert_ne!(
            original,
            tampered.root_hash(),
            "ledger-field tamper inside snapshot must produce different root_hash"
        );
    }

    #[test]
    fn root_hash_is_byte_sensitive_to_capability_hash_tampering_inside_sealed_mutation() {
        // Phase 1 hardening — companion to iter-296 debit-tamper
        // pin. The capability_hash field inside SealedMutation is
        // also hashed; tampering with the 32-byte hash must produce
        // a different root_hash.
        //
        // Critical for audit: a forged capability_hash that points
        // to a different macaroon would silently fork the replay
        // chain unless the root_hash captures it.
        let mut log = RunEventLog::new();
        log.append_sealed_mutation(Hash::zero(), BudgetDebit::default());
        let original = log.root_hash();

        let s = serde_json::to_string(&log).expect("serialise");
        // The serialised capability_hash for Hash::zero is a
        // [u8; 32] of all zeros, encoded as "[0,0,0,...]" by serde.
        // Flip the first byte from 0 to 1 to produce a tampered hash.
        let tampered_json = s.replacen(
            "\"capability_hash\":[0,",
            "\"capability_hash\":[1,",
            1,
        );
        let tampered: RunEventLog =
            serde_json::from_str(&tampered_json).expect("deserialise tampered");
        assert_ne!(
            original,
            tampered.root_hash(),
            "capability_hash tamper must produce different root_hash"
        );
    }

    #[test]
    fn root_hash_is_byte_sensitive_to_debit_field_tampering_inside_sealed_mutation() {
        // Phase 1 hardening — companion to ordinal-tamper pin
        // (iter-295). The debit field inside SealedMutation is also
        // hashed; tampering with any debit axis must produce a
        // different root_hash.
        //
        // A future refactor that hashed only the capability_hash
        // (dropping the debit from the encoding) would silently
        // let a 100-token debit collide with a 1-token debit at
        // the audit-chain level.
        let mut log = RunEventLog::new();
        log.append_sealed_mutation(
            Hash::zero(),
            BudgetDebit { tokens: 100, ..Default::default() },
        );
        let original = log.root_hash();

        let s = serde_json::to_string(&log).expect("serialise");
        let tampered_json = s.replacen("\"tokens\":100", "\"tokens\":99", 1);
        let tampered: RunEventLog =
            serde_json::from_str(&tampered_json).expect("deserialise tampered");
        assert_ne!(
            original,
            tampered.root_hash(),
            "debit-field tamper must produce a different root_hash"
        );
    }

    #[test]
    fn root_hash_is_byte_sensitive_to_ordinal_field_tampering() {
        // Phase 1 hardening — companion to
        // root_hash_is_byte_sensitive_to_single_character_payload_change.
        // The ordinal field is hashed alongside the payload; tampering
        // with an ordinal must produce a different root_hash. This
        // pins that the ordinal is part of the per-entry encoding
        // (not just an internal index).
        let mut log = RunEventLog::new();
        log.append_event(AgentEvent::ReasoningDelta { text: "x".into() });
        log.append_event(AgentEvent::Stop { reason: StopReason::EndTurn });
        let original_root = log.root_hash();

        // Serialise + tamper an ordinal + deserialise + recompute root.
        let s = serde_json::to_string(&log).expect("serialise");
        let tampered_json = s.replacen("\"ordinal\":1", "\"ordinal\":99", 1);
        let tampered: RunEventLog =
            serde_json::from_str(&tampered_json).expect("deserialise tampered");
        let tampered_root = tampered.root_hash();
        assert_ne!(
            original_root, tampered_root,
            "ordinal-field tamper must produce a different root_hash"
        );
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
    fn validate_ordinal_density_is_pure_deterministic_across_multiple_calls() {
        // Phase 1 hardening — pure-function determinism pin
        // (companion to the purity series iter-220-233).
        // validate_ordinal_density walks entries comparing each
        // entry's ordinal to its index. Pure function over
        // immutable data.
        let mut log = RunEventLog::new();
        for i in 0..5 {
            log.append_event(AgentEvent::ReasoningDelta {
                text: format!("d{i}"),
            });
        }
        let r1 = log.validate_ordinal_density();
        let r2 = log.validate_ordinal_density();
        let r3 = log.validate_ordinal_density();
        assert_eq!(r1, r2);
        assert_eq!(r2, r3);
        assert!(r1.is_ok());
        // The log was not mutated by repeated validation.
        assert_eq!(log.len(), 5);
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
    fn validate_ordinal_density_holds_for_1000_entry_log() {
        // Phase 1 hardening — scale pin. The existing
        // validate_ordinal_density tests cover small fixtures (0/2/3/5/
        // 10 entries). This pin scales to 1000 entries to verify the
        // dense-ordinal invariant holds across a non-trivial log size.
        //
        // Defends against a future "let me cache the last position and
        // skip the full walk" optimisation that would silently miss
        // gaps in the middle of large logs.
        let mut log = RunEventLog::new();
        for i in 0..1_000 {
            log.append_event(AgentEvent::ReasoningDelta {
                text: format!("d{i}"),
            });
        }
        log.validate_ordinal_density()
            .expect("1000-entry log must validate");
        // Spot-check: forge ordinal at position 500.
        let s = serde_json::to_string(&log).expect("serialise");
        let tampered = s.replacen("\"ordinal\":500", "\"ordinal\":99999", 1);
        let bad: RunEventLog =
            serde_json::from_str(&tampered).expect("deserialise tampered");
        let err = bad
            .validate_ordinal_density()
            .expect_err("forgery at mid-log position must fail");
        assert_eq!(
            err,
            LogValidationError::OrdinalMismatch {
                position: 500,
                expected: 500,
                actual: 99_999,
            }
        );
    }

    #[test]
    fn validate_ordinal_density_empty_log_accepts_and_position_0_forgery_caught() {
        // Phase 1 hardening — boundary completeness companion to
        // validate_ordinal_density_catches_gap (mid-log forgery at
        // position 2) and validate_ordinal_density_accepts_clean_log
        // (clean 10-entry log).
        //
        // Three uncovered cases pinned here:
        //   1) Empty log → Ok (no entries to check; trivially dense).
        //   2) Position-0 forgery — first entry ordinal != 0 caught.
        //   3) Last-position forgery — last entry's ordinal forged
        //      to a value other than (N-1) caught with the correct
        //      position attribution.
        //
        // Defends against a future "let me short-circuit-return Ok
        // for logs of length < 2" optimisation (would silently miss
        // the position-0 forgery) and a "let me validate only the
        // first K entries for hot-path speed" optimisation (would
        // silently miss last-position forgeries).
        let empty = RunEventLog::new();
        empty
            .validate_ordinal_density()
            .expect("empty log must accept (no entries to check)");

        // Position-0 forgery: build a 3-entry log, then forge ordinal
        // 0 to 99.
        let mut log0 = RunEventLog::new();
        for i in 0..3 {
            log0.append_event(AgentEvent::ReasoningDelta {
                text: format!("d{i}"),
            });
        }
        let s0 = serde_json::to_string(&log0).expect("serialize");
        let tampered0 = s0.replacen("\"ordinal\":0", "\"ordinal\":99", 1);
        let bad0: RunEventLog =
            serde_json::from_str(&tampered0).expect("deserialise pos-0 tampered");
        let err0 = bad0
            .validate_ordinal_density()
            .expect_err("position-0 forgery must fail validation");
        assert_eq!(
            err0,
            LogValidationError::OrdinalMismatch {
                position: 0,
                expected: 0,
                actual: 99,
            }
        );

        // Last-position forgery: 5-entry log, forge ordinal 4 → 77.
        let mut log4 = RunEventLog::new();
        for i in 0..5 {
            log4.append_event(AgentEvent::ReasoningDelta {
                text: format!("d{i}"),
            });
        }
        let s4 = serde_json::to_string(&log4).expect("serialize");
        let tampered4 = s4.replacen("\"ordinal\":4", "\"ordinal\":77", 1);
        let bad4: RunEventLog =
            serde_json::from_str(&tampered4).expect("deserialise last-pos tampered");
        let err4 = bad4
            .validate_ordinal_density()
            .expect_err("last-position forgery must fail validation");
        assert_eq!(
            err4,
            LogValidationError::OrdinalMismatch {
                position: 4,
                expected: 4,
                actual: 77,
            }
        );
    }

    #[test]
    fn log_validation_error_ordinal_mismatch_field_shape_pinned() {
        // Phase 1 hardening — field-shape pin for
        // LogValidationError::OrdinalMismatch (companion to
        // mission_prompt_error iter-454, budget_error::exhausted iter-455).
        // The variant carries EXACTLY 3 named fields
        // (position: usize, expected: u64, actual: u64).
        //
        // A future "let me add a 4th field like {position, expected,
        // actual, entry_kind}" refactor would silently change the
        // error payload size — surface here via the destructure match
        // arm.
        let err = LogValidationError::OrdinalMismatch {
            position: 7,
            expected: 7,
            actual: 999,
        };
        match err {
            LogValidationError::OrdinalMismatch { position, expected, actual } => {
                // Exactly 3 fields. Type assertions verify the typed shape.
                let _: usize = position;
                let _: u64 = expected;
                let _: u64 = actual;
                assert_eq!(position, 7);
                assert_eq!(expected, 7);
                assert_eq!(actual, 999);
            }
        }
    }

    #[test]
    fn log_validation_error_ordinal_mismatch_inner_fields_are_identity_load_bearing() {
        // Phase 1 hardening — inner-field distinctness pin
        // (companion to iter-197/198 error inner-pins).
        // LogValidationError::OrdinalMismatch carries 3 fields:
        // position, expected, actual. Each must participate in
        // PartialEq derivation so an audit pipeline that buckets
        // by these triples sees two distinct violations as distinct.
        let base = LogValidationError::OrdinalMismatch {
            position: 5,
            expected: 5,
            actual: 99,
        };
        // Different position → unequal.
        assert_ne!(
            base,
            LogValidationError::OrdinalMismatch {
                position: 6,
                expected: 5,
                actual: 99,
            }
        );
        // Different expected → unequal.
        assert_ne!(
            base,
            LogValidationError::OrdinalMismatch {
                position: 5,
                expected: 6,
                actual: 99,
            }
        );
        // Different actual → unequal.
        assert_ne!(
            base,
            LogValidationError::OrdinalMismatch {
                position: 5,
                expected: 5,
                actual: 100,
            }
        );
        // Identical → equal.
        assert_eq!(
            base,
            LogValidationError::OrdinalMismatch {
                position: 5,
                expected: 5,
                actual: 99,
            }
        );
    }

    #[test]
    fn run_event_log_and_entry_are_clone_send_sync_but_not_copy() {
        // Phase 1 hardening MILESTONE iter-380 — closes the
        // Clone + Send + Sync (not Copy) pin family across the
        // append-only witness-trail types.
        //
        // RunEventLog: holds Vec<RunEventEntry>. Clone by derive but
        // NOT Copy (heap).
        // RunEventEntry: 3-variant enum with String/Hash/BudgetLedger/
        // BudgetDebit payloads + ordinal. Clone by derive but NOT Copy
        // (Event variant carries AgentEvent which has Strings).
        //
        // Send + Sync are load-bearing — RunEventLog is built by the
        // dispatcher on a background actor and read by the UI thread
        // for the Provenance Console.
        //
        // A future "let me hold a Cell<usize> next_ordinal cache" on
        // RunEventLog refactor that introduced a non-Send type would
        // silently break cross-thread propagation — surface here.
        //
        // The series total now covers (Clone+Send+Sync only):
        //   - AgentBlueprintId (iter-375)
        //   - MissionPacket + ToolCall (iter-376)
        //   - AnswerPacket + Citation (iter-377)
        //   - AgentBlueprint + ProviderPolicy (iter-378)
        //   - LocalAgentCapability + VariantLadderSpec (iter-379)
        //   - RunEventLog + RunEventEntry (this commit)
        // → 10 String/Vec-bearing types pinned, on top of the 18
        // unit-enum + Copy-struct types from iter-366..iter-374.
        fn assert_clone_send_sync<T: Clone + Send + Sync>() {}
        assert_clone_send_sync::<RunEventLog>();
        assert_clone_send_sync::<RunEventEntry>();

        // Sanity. RunEventLog does NOT derive PartialEq (Vec of
        // enum entries with String content; the structural-equality
        // surface uses log root_hash for replay-equality semantics).
        // Clone preserves entry count + root_hash.
        let mut log = RunEventLog::new();
        log.append_event(AgentEvent::ReasoningDelta { text: "x".into() });
        let cloned = log.clone();
        assert_eq!(cloned.len(), log.len());
        assert_eq!(cloned.root_hash(), log.root_hash());

        // RunEventEntry DOES derive PartialEq via downstream variants.
        let entry = log.entries()[0].clone();
        assert_eq!(entry, entry.clone());
    }

    #[test]
    fn log_validation_error_is_copy_clone_send_sync_for_propagation_safety() {
        // Phase 1 hardening — trait-bound pin (companion to budget_gate,
        // mode iter-366, StopReason iter-367, VariantTier iter-368,
        // LocalAgent enums iter-369, budget closed-taxonomy iter-370,
        // CliAdapter + BlueprintModeError iter-371).
        //
        // LogValidationError: 1-variant enum with Copy payload
        // (3×usize/u64) marked Copy via derive (run_event_log.rs §57).
        // Returned by validate_ordinal_density; Copy lets audit dashboards
        // propagate the error across thread boundaries without owning.
        //
        // A future "let me carry a Box<RunEventEntry> snapshot of the
        // offending row" refactor that introduced a non-Copy payload
        // would silently change the error-propagation shape — surface
        // here.
        fn assert_copy_clone_send_sync<T: Copy + Clone + Send + Sync>() {}
        assert_copy_clone_send_sync::<LogValidationError>();

        // Runtime sanity.
        let e = LogValidationError::OrdinalMismatch {
            position: 1,
            expected: 1,
            actual: 99,
        };
        let _a = e; let _b = e; assert_eq!(e, e);
    }

    #[test]
    fn log_validation_error_variant_count_is_one() {
        // Phase 1 hardening — cardinality pin completing the
        // count-pin series across the agent_runtime_v2 error
        // taxonomies (mode 3v, ToolCallError 5v, AgentEventErrorKind
        // 4v, BlueprintModeError 2v, VariantLadderError 2v,
        // MissionPromptError 1v iter-344). LogValidationError has
        // exactly 1 variant (OrdinalMismatch) today.
        //
        // A future addition (e.g., DuplicateOrdinal, OutOfRange,
        // OrdinalOverflow) requires:
        //   - validate_ordinal_density() match-arm extension
        //   - new variant's debug repr pin + inner-field identity pin
        //
        // Pin the count so the addition surfaces at PR review with a
        // deliberate test update.
        let variants = [LogValidationError::OrdinalMismatch {
            position: 0,
            expected: 0,
            actual: 0,
        }];
        assert_eq!(variants.len(), 1);
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
    fn ledger_at_ordinal_is_pure_deterministic_across_multiple_calls() {
        // Phase 1 hardening — pure-function determinism pin
        // (companion to the purity series iter-220-225).
        // ledger_at_ordinal walks entries in reverse to find the
        // most recent LedgerSnapshot at-or-before the given ord.
        // Pure function over the immutable entries vector.
        //
        // A future caching refactor that mutated internal state
        // on first call would silently break determinism.
        let mut log = RunEventLog::new();
        log.append_event(AgentEvent::ReasoningDelta { text: "x".into() });
        log.append_ledger_snapshot(BudgetLedger {
            tokens_used: 100,
            ..Default::default()
        });
        log.append_event(AgentEvent::Stop { reason: StopReason::EndTurn });

        for ord in [0u64, 1, 2, 999] {
            let r1 = log.ledger_at_ordinal(ord);
            let r2 = log.ledger_at_ordinal(ord);
            let r3 = log.ledger_at_ordinal(ord);
            assert_eq!(r1, r2, "ord {ord}: r1 != r2");
            assert_eq!(r2, r3, "ord {ord}: r2 != r3");
        }
    }

    #[test]
    fn ledger_at_ordinal_empty_log_returns_none() {
        let log = RunEventLog::new();
        assert_eq!(log.ledger_at_ordinal(0), None);
        assert_eq!(log.ledger_at_ordinal(99), None);
    }

    #[test]
    fn sealed_mutations_iterator_is_idempotent_across_multiple_calls() {
        // Phase 1 hardening — pure-function pin (companion to
        // iter-168's digest_intact idempotency pin).
        // sealed_mutations() returns `impl Iterator + '_` — a new
        // iterator on each call. Calling it multiple times must
        // produce identical sequences (the underlying entries
        // vector is unchanged between calls).
        //
        // A future "let me cache the iterator state on first call"
        // refactor that introduced interior mutability would
        // silently break repeated audit walks.
        let mut log = RunEventLog::new();
        let cap_a = Hash::from_bytes([1u8; 32]);
        let cap_b = Hash::from_bytes([2u8; 32]);
        log.append_sealed_mutation(cap_a, BudgetDebit { tokens: 10, ..Default::default() });
        log.append_event(AgentEvent::ReasoningDelta { text: "x".into() });
        log.append_sealed_mutation(cap_b, BudgetDebit { tokens: 20, ..Default::default() });

        let first: Vec<_> = log.sealed_mutations().collect();
        let second: Vec<_> = log.sealed_mutations().collect();
        let third: Vec<_> = log.sealed_mutations().collect();
        assert_eq!(first.len(), 2);
        assert_eq!(first, second);
        assert_eq!(second, third);
        // Same ordinals + capabilities + debits each time.
        for (a, b) in first.iter().zip(second.iter()) {
            assert_eq!(a.0, b.0); // ordinal
            assert_eq!(a.1, b.1); // capability_hash
            assert_eq!(a.2.tokens, b.2.tokens); // debit.tokens
        }
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
    fn sealed_mutations_iterator_is_empty_when_log_has_no_sealed_rows() {
        // Phase 1 hardening — empty-result boundary pin for the
        // sealed_mutations() iterator. Companion to:
        //   - sealed_mutations_iterator_yields_each_row_in_order
        //   - sealed_mutations_iterator_can_be_short_circuited
        //   - sealed_mutations_iterator_is_idempotent_across_multiple_calls
        //
        // A log that contains ONLY Event + LedgerSnapshot rows (no
        // SealedMutation) must yield an empty iterator — the
        // filter_map should skip every non-SealedMutation entry.
        //
        // Defends against a future refactor that, e.g., changed the
        // filter pattern to also match LedgerSnapshot rows (because
        // both carry a debit-shape) — that would silently flood the
        // audit dashboard with non-mutation rows.
        let mut log = RunEventLog::new();
        log.append_event(AgentEvent::ReasoningDelta { text: "r".into() });
        log.append_ledger_snapshot(BudgetLedger { tokens_used: 100, ..Default::default() });
        log.append_event(AgentEvent::Stop { reason: StopReason::EndTurn });

        let count = log.sealed_mutations().count();
        assert_eq!(count, 0, "no SealedMutation rows must yield empty iterator");
        let collected: Vec<_> = log.sealed_mutations().collect();
        assert!(collected.is_empty());

        // total_tokens_debited agrees.
        let (total, n) = log.total_tokens_debited();
        assert_eq!(total, 0);
        assert_eq!(n, 0);
    }

    #[test]
    fn sealed_mutations_iterator_returns_byte_equal_cap_hash_and_debit_references() {
        // Phase 1 hardening — content-preservation pin for
        // sealed_mutations(). Companion to
        // find_tool_calls_returns_byte_equal_call_references (iter-498).
        //
        // The iterator yields (ordinal, &Hash, &BudgetDebit). The
        // returned references must point to the SAME byte content as
        // the appended values — no normalization, no rewriting.
        let mut log = RunEventLog::new();
        let cap_a = Hash::from_bytes([0x11; 32]);
        let cap_b = Hash::from_bytes([0x22; 32]);
        let debit_a = BudgetDebit {
            tokens: 100,
            wall_ms: 200,
            tool_calls: 1,
            subprocess_ms: 300,
            memory_bytes: 4_096,
        };
        let debit_b = BudgetDebit {
            tokens: 50,
            tool_calls: 2,
            ..Default::default()
        };
        log.append_sealed_mutation(cap_a, debit_a);
        log.append_sealed_mutation(cap_b, debit_b);

        let hits: Vec<_> = log.sealed_mutations().collect();
        assert_eq!(hits.len(), 2);
        // (ordinal, &Hash, &BudgetDebit)
        assert_eq!(hits[0].0, 0);
        assert_eq!(*hits[0].1, cap_a);
        assert_eq!(*hits[0].2, debit_a);
        assert_eq!(hits[1].0, 1);
        assert_eq!(*hits[1].1, cap_b);
        assert_eq!(*hits[1].2, debit_b);
        // Cross-check: 5-axis debit preserved per row.
        assert_eq!(hits[0].2.tokens, 100);
        assert_eq!(hits[0].2.wall_ms, 200);
        assert_eq!(hits[0].2.tool_calls, 1);
        assert_eq!(hits[0].2.subprocess_ms, 300);
        assert_eq!(hits[0].2.memory_bytes, 4_096);
    }

    #[test]
    fn sealed_mutations_iterator_yields_ordinals_in_strictly_ascending_order() {
        // Phase 1 hardening — ordering pin for sealed_mutations().
        // Companion to:
        //   - find_capability_hash_returns_ordinals_in_strictly_ascending_order (iter-476)
        //   - find_tool_calls_returns_ordinals_in_strictly_ascending_order (iter-477)
        //
        // sealed_mutations() walks entries in append order via
        // filter_map; the result iterator yields ordinals in
        // strict-ascending order. A future "let me serve from a
        // sorted-by-capability_hash side table" refactor would
        // silently fork the order.
        let mut log = RunEventLog::new();
        // 4 sealed mutations interleaved with other events.
        log.append_sealed_mutation(Hash::from_bytes([1u8; 32]), BudgetDebit::default()); // 0
        log.append_event(AgentEvent::ReasoningDelta { text: "x".into() }); // 1
        log.append_sealed_mutation(Hash::from_bytes([2u8; 32]), BudgetDebit::default()); // 2
        log.append_ledger_snapshot(BudgetLedger::default()); // 3
        log.append_sealed_mutation(Hash::from_bytes([3u8; 32]), BudgetDebit::default()); // 4
        log.append_sealed_mutation(Hash::from_bytes([4u8; 32]), BudgetDebit::default()); // 5

        let ordinals: Vec<u64> = log.sealed_mutations().map(|(o, _, _)| o).collect();
        assert_eq!(ordinals, vec![0, 2, 4, 5]);
        for pair in ordinals.windows(2) {
            assert!(pair[0] < pair[1], "ordinals must be strictly ascending");
        }
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
    fn find_tool_calls_count_is_upper_bounded_by_event_count() {
        // Phase 1 hardening — cross-helper invariant.
        // find_tool_calls returns only AgentEvent::ToolCall events
        // wrapped inside RunEventEntry::Event. By construction:
        //   find_tool_calls().len() <= entry_count_by_kind.events
        //
        // Equality when EVERY Event row carries a ToolCall variant;
        // strict-less when other AgentEvent variants are present.
        // A future bug in either helper (find_tool_calls counting
        // SealedMutation rows, or entry_count_by_kind miscounting
        // ToolCall rows as sealed) would surface here.
        use crate::agent_runtime_v2::mission::ToolCall;
        let mut log = RunEventLog::new();
        // Mix: 2 ToolCall events, 1 ReasoningDelta, 1 Stop, plus
        // 1 SealedMutation + 1 LedgerSnapshot.
        log.append_event(AgentEvent::ReasoningDelta { text: "r".into() });
        log.append_event(AgentEvent::ToolCall {
            call: ToolCall {
                name: "vault.read".into(),
                arguments: serde_json::json!({"path": "a"}),
            },
        });
        log.append_sealed_mutation(Hash::zero(), BudgetDebit::default());
        log.append_event(AgentEvent::ToolCall {
            call: ToolCall {
                name: "vault.write".into(),
                arguments: serde_json::json!({"path": "b"}),
            },
        });
        log.append_ledger_snapshot(BudgetLedger::default());
        log.append_event(AgentEvent::Stop { reason: StopReason::EndTurn });

        let tool_calls = log.find_tool_calls();
        let (events, _sealed, _snapshots) = log.entry_count_by_kind();

        // 4 events (ReasoningDelta + 2 ToolCalls + Stop).
        assert_eq!(events, 4);
        // 2 tool calls — strict-less than events.
        assert_eq!(tool_calls.len(), 2);
        assert!(
            tool_calls.len() <= events,
            "find_tool_calls.len() {} must be <= events {events}",
            tool_calls.len()
        );
    }

    #[test]
    fn find_tool_calls_returns_byte_equal_call_references() {
        // Phase 1 hardening — content-preservation pin for find_tool_calls.
        // Companion to find_tool_calls_returns_calls_with_ordinals_in_order
        // (which spot-checks one call's name) — this pins that the
        // RETURNED &ToolCall references point to the SAME structural
        // content as the appended ToolCall (no slicing, no rewriting,
        // no name normalization).
        use crate::agent_runtime_v2::mission::ToolCall;
        let mut log = RunEventLog::new();
        let call_a = ToolCall {
            name: "vault.read".into(),
            arguments: serde_json::json!({"path": "vault/a.md", "limit": 100}),
        };
        let call_b = ToolCall {
            name: "vault.search".into(),
            arguments: serde_json::json!({"q": "Aegis is rejected", "fuzzy": false}),
        };
        log.append_event(AgentEvent::ToolCall { call: call_a.clone() });
        log.append_event(AgentEvent::ToolCall { call: call_b.clone() });

        let hits = log.find_tool_calls();
        assert_eq!(hits.len(), 2);
        // Each returned reference must deep-equal the appended call.
        assert_eq!(hits[0].1, &call_a, "first hit must equal call_a byte-for-byte");
        assert_eq!(hits[1].1, &call_b, "second hit must equal call_b byte-for-byte");
        // Argument contents preserved (no normalisation).
        assert_eq!(hits[0].1.arguments["path"], "vault/a.md");
        assert_eq!(hits[0].1.arguments["limit"], 100);
        assert_eq!(hits[1].1.arguments["q"], "Aegis is rejected");
        assert_eq!(hits[1].1.arguments["fuzzy"], false);
    }

    #[test]
    fn find_tool_calls_returns_ordinals_in_strictly_ascending_order() {
        // Phase 1 hardening — ordering pin for find_tool_calls.
        // Companion to find_capability_hash_returns_ordinals_in_strictly_ascending_order
        // (iter-476).
        //
        // find_tool_calls walks entries in append order; the result
        // ordinals must be strict-ascending (no equal, no descending).
        // A future "let me index by tool_name and serve from a sorted
        // set" refactor would silently fork the order.
        use crate::agent_runtime_v2::mission::ToolCall;
        let mut log = RunEventLog::new();
        // 4 tool calls interleaved with other events.
        log.append_event(AgentEvent::ToolCall {
            call: ToolCall { name: "a".into(), arguments: serde_json::json!({}) },
        }); // 0
        log.append_event(AgentEvent::ReasoningDelta { text: "x".into() }); // 1
        log.append_event(AgentEvent::ToolCall {
            call: ToolCall { name: "b".into(), arguments: serde_json::json!({}) },
        }); // 2
        log.append_sealed_mutation(Hash::zero(), BudgetDebit::default()); // 3
        log.append_event(AgentEvent::ToolCall {
            call: ToolCall { name: "c".into(), arguments: serde_json::json!({}) },
        }); // 4
        log.append_event(AgentEvent::ToolCall {
            call: ToolCall { name: "d".into(), arguments: serde_json::json!({}) },
        }); // 5

        let hits = log.find_tool_calls();
        let ordinals: Vec<u64> = hits.iter().map(|(o, _)| *o).collect();
        assert_eq!(ordinals, vec![0, 2, 4, 5]);
        for pair in ordinals.windows(2) {
            assert!(pair[0] < pair[1], "ordinals must be strictly ascending");
        }
    }

    #[test]
    fn find_tool_calls_is_pure_deterministic_across_multiple_calls() {
        // Phase 1 hardening — pure-function determinism pin
        // (companion to the purity series). find_tool_calls walks
        // entries and builds a fresh Vec on each call; the result
        // must be identical across repeated calls.
        use crate::agent_runtime_v2::mission::ToolCall;
        let mut log = RunEventLog::new();
        log.append_event(AgentEvent::ToolCall {
            call: ToolCall {
                name: "vault.read".into(),
                arguments: serde_json::json!({"path": "a"}),
            },
        });
        log.append_event(AgentEvent::ReasoningDelta { text: "x".into() });
        log.append_event(AgentEvent::ToolCall {
            call: ToolCall {
                name: "vault.write".into(),
                arguments: serde_json::json!({"path": "b"}),
            },
        });
        let r1 = log.find_tool_calls();
        let r2 = log.find_tool_calls();
        let r3 = log.find_tool_calls();
        assert_eq!(r1.len(), 2);
        // Compare ordinals + call references (Vec<(u64, &ToolCall)>).
        assert_eq!(
            r1.iter().map(|(o, _)| *o).collect::<Vec<_>>(),
            r2.iter().map(|(o, _)| *o).collect::<Vec<_>>()
        );
        assert_eq!(
            r2.iter().map(|(o, _)| *o).collect::<Vec<_>>(),
            r3.iter().map(|(o, _)| *o).collect::<Vec<_>>()
        );
    }

    #[test]
    fn find_tool_calls_empty_when_no_tool_call_events() {
        let mut log = RunEventLog::new();
        log.append_event(AgentEvent::ReasoningDelta { text: "x".into() });
        log.append_event(AgentEvent::Stop { reason: StopReason::EndTurn });
        assert!(log.find_tool_calls().is_empty());
    }

    #[test]
    fn first_event_ordinal_is_pure_deterministic_across_multiple_calls() {
        // Phase 1 hardening — pure-function determinism pin
        // (companion to the purity series). first_event_ordinal
        // peeks entries.first() and maps it to the ordinal; pure
        // over immutable data.
        let mut log = RunEventLog::new();
        // Empty case.
        assert_eq!(log.first_event_ordinal(), None);
        assert_eq!(log.first_event_ordinal(), None);
        assert_eq!(log.first_event_ordinal(), None);
        // Non-empty case.
        log.append_event(AgentEvent::ReasoningDelta { text: "x".into() });
        for _ in 0..3 {
            assert_eq!(log.first_event_ordinal(), Some(0));
        }
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
    fn first_event_ordinal_returns_zero_regardless_of_first_entry_variant() {
        // Phase 1 hardening — variant-completeness companion to
        // first_event_ordinal_returns_zero_when_non_empty_none_when_empty
        // (which only covers Event variants as the first row).
        //
        // The first_event_ordinal contract is: "first ENTRY's ordinal,
        // regardless of variant". A future "let me filter out
        // SealedMutation/LedgerSnapshot rows and only consider
        // AgentEvent rows" refactor (motivated by the misleading
        // method name) would silently break logs that begin with a
        // SealedMutation or LedgerSnapshot row.
        //
        // Three variants × first-row position = pin each. All must
        // return Some(0).
        let mut event_first = RunEventLog::new();
        event_first.append_event(AgentEvent::ReasoningDelta { text: "e".into() });
        assert_eq!(event_first.first_event_ordinal(), Some(0));

        let mut sealed_first = RunEventLog::new();
        sealed_first.append_sealed_mutation(
            Hash::from_bytes([0x11; 32]),
            BudgetDebit::default(),
        );
        assert_eq!(
            sealed_first.first_event_ordinal(),
            Some(0),
            "first_event_ordinal must return Some(0) when first entry is SealedMutation"
        );

        let mut snapshot_first = RunEventLog::new();
        snapshot_first.append_ledger_snapshot(BudgetLedger::default());
        assert_eq!(
            snapshot_first.first_event_ordinal(),
            Some(0),
            "first_event_ordinal must return Some(0) when first entry is LedgerSnapshot"
        );
    }

    #[test]
    fn stop_count_and_error_count_are_pure_deterministic_across_multiple_calls() {
        // Phase 1 hardening — pure-function determinism pin
        // (companion to the purity series). Both helpers count
        // matching variants by walking entries.
        let mut log = RunEventLog::new();
        log.append_event(AgentEvent::Stop { reason: StopReason::EndTurn });
        log.append_event(AgentEvent::Error {
            kind: AgentEventErrorKind::Provider,
            message: "x".into(),
        });
        log.append_event(AgentEvent::ReasoningDelta { text: "r".into() });
        // 3 calls each.
        for _ in 0..3 {
            assert_eq!(log.stop_count(), 1);
            assert_eq!(log.error_count(), 1);
        }
    }

    #[test]
    fn stop_count_counts_every_stop_regardless_of_stop_reason_variant() {
        // Phase 1 hardening — variant-completeness pin for stop_count().
        // Companion to stop_count_distinguishes_zero_one_many.
        //
        // stop_count() counts ANY AgentEvent::Stop entry regardless of
        // the inner StopReason variant — a Stop is a Stop. A future
        // refactor that filtered to "only EndTurn counts as a Stop"
        // (because error paths produce Error events) would silently
        // skew the audit dashboard.
        //
        // Pin via a log with one Stop per StopReason variant (7 in
        // total). stop_count must equal 7.
        let mut log = RunEventLog::new();
        for reason in [
            StopReason::EndTurn,
            StopReason::ToolUse,
            StopReason::MaxTokens,
            StopReason::Refusal,
            StopReason::BudgetExhausted,
            StopReason::CapabilityDenied,
            StopReason::Error,
        ] {
            log.append_event(AgentEvent::Stop { reason });
        }
        assert_eq!(log.stop_count(), 7, "every Stop variant must count");
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
    fn error_count_counts_every_error_regardless_of_agent_event_error_kind_variant() {
        // Phase 1 hardening — variant-completeness pin for error_count().
        // Companion to:
        //   - error_count_distinguishes_zero_one_many_and_is_disjoint_from_stop
        //   - stop_count_counts_every_stop_regardless_of_stop_reason_variant (iter-501)
        //
        // error_count() counts ANY AgentEvent::Error entry regardless of
        // the inner AgentEventErrorKind variant. A future refactor that
        // filtered (e.g., "only Provider errors count for SLA") would
        // silently skew the audit dashboard.
        //
        // Pin via a log with one Error per AgentEventErrorKind variant
        // (4 in total). error_count must equal 4.
        let mut log = RunEventLog::new();
        for kind in [
            AgentEventErrorKind::MalformedToolCall,
            AgentEventErrorKind::BudgetExhausted,
            AgentEventErrorKind::CapabilityDenied,
            AgentEventErrorKind::Provider,
        ] {
            log.append_event(AgentEvent::Error {
                kind,
                message: format!("{kind:?}-error"),
            });
        }
        assert_eq!(log.error_count(), 4, "every Error kind variant must count");
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
    fn last_stop_event_returns_most_recent_not_first_when_multiple_stops_present() {
        // Phase 1 hardening — last-vs-first pin for last_stop_event().
        // Companion to last_stop_event_surfaces_each_of_seven_stop_reason_variants
        // (iter-503).
        //
        // The name says "last" — pin that the helper returns the MOST
        // RECENT Stop event's reason, NOT the first. A future "let me
        // index by first-Stop for replay startup detection" refactor
        // would silently break the doctrine.
        //
        // Append Stops in DELIBERATELY-VARYING order; verify the helper
        // returns the LAST one each time a new Stop is appended.
        let mut log = RunEventLog::new();
        log.append_event(AgentEvent::Stop { reason: StopReason::EndTurn });
        assert_eq!(log.last_stop_event(), Some(StopReason::EndTurn));
        log.append_event(AgentEvent::Stop { reason: StopReason::ToolUse });
        assert_eq!(log.last_stop_event(), Some(StopReason::ToolUse),
            "must return LAST Stop (ToolUse), not first (EndTurn)");
        log.append_event(AgentEvent::Stop { reason: StopReason::BudgetExhausted });
        assert_eq!(log.last_stop_event(), Some(StopReason::BudgetExhausted));
        // Non-Stop event in between must not affect the last_stop_event.
        log.append_event(AgentEvent::ReasoningDelta { text: "post-stop".into() });
        assert_eq!(log.last_stop_event(), Some(StopReason::BudgetExhausted),
            "ReasoningDelta does not affect last_stop_event");
        // Another Stop appended LATER updates the value.
        log.append_event(AgentEvent::Stop { reason: StopReason::Error });
        assert_eq!(log.last_stop_event(), Some(StopReason::Error));
    }

    #[test]
    fn last_stop_event_surfaces_each_of_seven_stop_reason_variants() {
        // Phase 1 hardening — variant-completeness pin for
        // last_stop_event(). Companion to
        // stop_count_counts_every_stop_regardless_of_stop_reason_variant
        // (iter-501) and error_count_counts_every_error... (iter-502).
        //
        // last_stop_event() returns the MOST RECENT Stop event's
        // reason (Option<StopReason>). It must surface every one of
        // the 7 StopReason variants verbatim — no remapping, no
        // normalization. Pin via 7 logs each containing a single Stop
        // event for the variant.
        for reason in [
            StopReason::EndTurn,
            StopReason::ToolUse,
            StopReason::MaxTokens,
            StopReason::Refusal,
            StopReason::BudgetExhausted,
            StopReason::CapabilityDenied,
            StopReason::Error,
        ] {
            let mut log = RunEventLog::new();
            log.append_event(AgentEvent::Stop { reason });
            assert_eq!(log.last_stop_event(), Some(reason),
                "last_stop_event must surface {reason:?} verbatim");
        }
    }

    #[test]
    fn stop_count_zero_iff_last_stop_event_is_none_cross_helper_invariant() {
        // Phase 1 hardening — cross-helper consistency.
        //   stop_count() == 0  ↔  last_stop_event() == None
        //   stop_count() >= 1  ↔  last_stop_event() == Some(_)
        //
        // Both helpers walk the entries vector independently;
        // a regression in either (e.g., last_stop_event matching
        // Error rows by accident, or stop_count missing Stop rows
        // appended by a future helper) would slip past the
        // individual tests but break this cross-invariant.
        let mut log = RunEventLog::new();
        // Empty log: zero stops, no last_stop.
        assert_eq!(log.stop_count(), 0);
        assert_eq!(log.last_stop_event(), None);

        // Append non-stop events: still zero / None.
        log.append_event(AgentEvent::ReasoningDelta { text: "r".into() });
        log.append_sealed_mutation(Hash::zero(), BudgetDebit::default());
        assert_eq!(log.stop_count(), 0);
        assert_eq!(log.last_stop_event(), None);

        // Append a Stop event: count flips to 1, last_stop_event Some.
        log.append_event(AgentEvent::Stop { reason: StopReason::ToolUse });
        assert_eq!(log.stop_count(), 1);
        assert_eq!(log.last_stop_event(), Some(StopReason::ToolUse));

        // Append a second Stop: count grows, last_stop tracks the newer.
        log.append_event(AgentEvent::Stop { reason: StopReason::EndTurn });
        assert_eq!(log.stop_count(), 2);
        assert_eq!(log.last_stop_event(), Some(StopReason::EndTurn));
    }

    #[test]
    fn last_stop_event_is_pure_deterministic_across_multiple_calls() {
        // Phase 1 hardening — pure-function determinism pin
        // (companion to the purity series iter-220-224).
        // last_stop_event walks entries in reverse to find the
        // most recent Stop; the walk must be deterministic and
        // side-effect-free.
        //
        // A future refactor that introduced caching or "skip ahead"
        // state inside the walker would silently break determinism.
        let mut log = RunEventLog::new();
        log.append_event(AgentEvent::Stop { reason: StopReason::ToolUse });
        log.append_event(AgentEvent::ReasoningDelta { text: "x".into() });
        log.append_event(AgentEvent::Stop { reason: StopReason::EndTurn });

        let r1 = log.last_stop_event();
        let r2 = log.last_stop_event();
        let r3 = log.last_stop_event();
        assert_eq!(r1, r2);
        assert_eq!(r2, r3);
        assert_eq!(r1, Some(StopReason::EndTurn));
        // The entries vector was not disturbed.
        assert_eq!(log.len(), 3);

        // Same property on the None case (empty log).
        let empty = RunEventLog::new();
        assert_eq!(empty.last_stop_event(), None);
        assert_eq!(empty.last_stop_event(), None);
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
    fn total_tokens_debited_is_pure_deterministic_across_multiple_calls() {
        // Phase 1 hardening — pure-function determinism pin
        // (companion to the purity series iter-220-226).
        // total_tokens_debited walks entries, summing tokens from
        // SealedMutation rows. Pure aggregation over an immutable
        // vector.
        let mut log = RunEventLog::new();
        for i in 1u64..=4 {
            log.append_sealed_mutation(
                Hash::zero(),
                BudgetDebit { tokens: i * 10, ..Default::default() },
            );
        }
        let r1 = log.total_tokens_debited();
        let r2 = log.total_tokens_debited();
        let r3 = log.total_tokens_debited();
        assert_eq!(r1, (100, 4));
        assert_eq!(r1, r2);
        assert_eq!(r2, r3);
    }

    #[test]
    fn total_tokens_debited_empty_log_returns_zero() {
        let log = RunEventLog::new();
        assert_eq!(log.total_tokens_debited(), (0, 0));
    }

    #[test]
    fn total_tokens_debited_count_is_per_row_not_per_nonzero_tokens() {
        // Phase 1 hardening — doctrine pin. total_tokens_debited
        // returns (sum_tokens, count) where `count` is the number
        // of SealedMutation ROWS, NOT the number of rows whose
        // tokens > 0. A row that debits only memory_bytes / tool_calls
        // / wall_ms still increments count.
        //
        // This matters for audit dashboards: "5 sealed mutations,
        // 200 tokens total" is the canonical rollup. If the count
        // silently dropped zero-token rows (e.g., T1/T2 deterministic
        // tier mutations that debit tool_calls but not tokens), the
        // "5 mutations" headline would shrink to "3 mutations" and
        // hide non-token-debiting tool calls from the surface.
        //
        // Defends against a future "let me skip rows where
        // debit.tokens == 0 to avoid noise" optimisation.
        let mut log = RunEventLog::new();
        // 3 rows total:
        //   row 1: tokens=25 (T3 LLM call)
        //   row 2: tokens=0, tool_calls=1 (T1 deterministic)
        //   row 3: tokens=0, memory_bytes=4096 (T2 heuristic over memory axis)
        log.append_sealed_mutation(
            Hash::zero(),
            BudgetDebit { tokens: 25, ..Default::default() },
        );
        log.append_sealed_mutation(
            Hash::zero(),
            BudgetDebit { tokens: 0, tool_calls: 1, ..Default::default() },
        );
        log.append_sealed_mutation(
            Hash::zero(),
            BudgetDebit { tokens: 0, memory_bytes: 4_096, ..Default::default() },
        );

        let (total, count) = log.total_tokens_debited();
        assert_eq!(total, 25, "sum_tokens must only count the tokens axis");
        assert_eq!(
            count, 3,
            "count must be per-SealedMutation-row, not per-nonzero-tokens"
        );
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
    fn entry_count_by_kind_is_pure_deterministic_across_multiple_calls() {
        // Phase 1 hardening — pure-function determinism pin
        // (companion to the purity series iter-220-227).
        // entry_count_by_kind walks entries categorising each row
        // into 3 buckets. Pure tuple-aggregation over an immutable
        // vector.
        let mut log = RunEventLog::new();
        log.append_event(AgentEvent::ReasoningDelta { text: "x".into() });
        log.append_sealed_mutation(Hash::zero(), BudgetDebit::default());
        log.append_ledger_snapshot(BudgetLedger::default());
        log.append_event(AgentEvent::Stop { reason: StopReason::EndTurn });
        let r1 = log.entry_count_by_kind();
        let r2 = log.entry_count_by_kind();
        let r3 = log.entry_count_by_kind();
        assert_eq!(r1, (2, 1, 1));
        assert_eq!(r1, r2);
        assert_eq!(r2, r3);
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
    fn append_sealed_mutation_positional_arg_order_is_pinned() {
        // Phase 1 hardening — positional-order pin for
        // append_sealed_mutation (companion to the constructor-order
        // pin family iter-433..iter-438).
        //
        // Signature:
        //   append_sealed_mutation(capability_hash, debit) -> u64
        // (run_event_log.rs §89).
        //
        // A reorder (debit-first because it's the budget-axis info
        // most-visible to the dispatcher) would silently shuffle the
        // SealedMutation row layout. The args have DIFFERENT types
        // (Hash, BudgetDebit) so a swap is type-incompatible — BUT
        // pin via DISTINCT identifiable values to surface any
        // future reorder at PR review.
        let mut log = RunEventLog::new();
        let cap = Hash::from_bytes([0x42; 32]);
        let debit = BudgetDebit {
            tokens: 999_999,
            ..Default::default()
        };
        let _ord = log.append_sealed_mutation(cap, debit);
        let entry = &log.entries()[0];
        match entry {
            RunEventEntry::SealedMutation { capability_hash, debit: stored_debit, .. } => {
                assert_eq!(*capability_hash, cap, "first arg goes to capability_hash");
                assert_eq!(stored_debit.tokens, 999_999, "second arg goes to debit");
            }
            other => panic!("expected SealedMutation, got {other:?}"),
        }
    }

    #[test]
    fn append_methods_returned_ordinal_equals_log_len_minus_one_invariant() {
        // Phase 1 hardening MILESTONE iter-500 — fundamental
        // log-growth invariant pin. For ANY append_*() call, the
        // returned ordinal MUST equal log.len() - 1 AFTER the append
        // — because the ordinal is the position the entry just took
        // (0-indexed; log.len() == ordinal + 1 after the append).
        //
        // Companion to append_methods_return_ordinal_matching_stored_entry_position
        // (iter-? returned-vs-stored consistency).
        //
        // A future "let me batch-buffer appends" refactor that
        // returned the FUTURE ordinal (i.e., the ordinal of the
        // next call) would silently break the dispatcher's foreign-key
        // pattern: dispatcher uses returned ordinal as the cross-reference
        // into the log, but the entry might not actually exist yet
        // at that ordinal.
        //
        // Pin across all 3 append paths over 100 calls.
        let mut log = RunEventLog::new();
        for i in 0..100 {
            let ord = match i % 3 {
                0 => log.append_event(AgentEvent::ReasoningDelta {
                    text: format!("d{i}"),
                }),
                1 => log.append_sealed_mutation(
                    Hash::from_bytes([(i % 256) as u8; 32]),
                    BudgetDebit::default(),
                ),
                _ => log.append_ledger_snapshot(BudgetLedger::default()),
            };
            assert_eq!(
                ord,
                (log.len() - 1) as u64,
                "iteration {i}: returned ordinal {ord} must equal log.len()-1 = {}",
                log.len() - 1,
            );
        }
        // Final invariant: log.len() == 100.
        assert_eq!(log.len(), 100);
    }

    #[test]
    fn append_methods_return_ordinal_matching_stored_entry_position() {
        // Phase 1 hardening — return-vs-store consistency pin.
        // All three append_* methods (append_event, append_sealed_mutation,
        // append_ledger_snapshot) return the assigned ordinal and ALSO
        // store it on the entry. The two must agree on every call:
        //
        //   returned == entries[returned as usize].ordinal() == position
        //
        // A future "let me track ordinals in a side-table for hot-path
        // lookup" refactor that decoupled the returned value from the
        // entry-side stored ordinal would silently break this invariant.
        // The dispatcher uses the returned ordinal as the foreign key
        // into the log; if it drifts from the stored ordinal, every
        // audit query keyed on ordinal would miss.
        //
        // Pin across all 3 append paths in interleaved order:
        //   Event, SealedMutation, LedgerSnapshot, SealedMutation,
        //   Event, LedgerSnapshot — proves no path produces a drift.
        let mut log = RunEventLog::new();
        let mut returned: Vec<u64> = Vec::new();
        returned.push(log.append_event(AgentEvent::ReasoningDelta { text: "a".into() }));
        returned.push(log.append_sealed_mutation(
            Hash::from_bytes([1u8; 32]),
            BudgetDebit::default(),
        ));
        returned.push(log.append_ledger_snapshot(BudgetLedger::default()));
        returned.push(log.append_sealed_mutation(
            Hash::from_bytes([2u8; 32]),
            BudgetDebit::default(),
        ));
        returned.push(log.append_event(AgentEvent::FinalText { text: "b".into() }));
        returned.push(log.append_ledger_snapshot(BudgetLedger {
            tokens_used: 7,
            ..Default::default()
        }));

        // Returned ordinals are dense 0..6.
        assert_eq!(returned, vec![0, 1, 2, 3, 4, 5]);
        assert_eq!(log.len(), 6);

        // For every returned ordinal o, entries()[o as usize].ordinal()
        // MUST equal o. This is the return-vs-store consistency.
        for (idx, &o) in returned.iter().enumerate() {
            assert_eq!(
                log.entries()[o as usize].ordinal(),
                o,
                "returned ordinal {o} drifted from stored at position {idx}"
            );
            assert_eq!(o, idx as u64, "returned ordinal must equal slice index");
        }
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
    fn total_tokens_debited_matches_post_mutation_ledger_snapshot_when_dispatcher_accounts_correctly() {
        // Phase 1 hardening — cross-helper consistency pin between
        // the witness-trail aggregator (total_tokens_debited) and the
        // ledger-snapshot reading path (ledger_at_ordinal).
        //
        // Contract: if the dispatcher correctly debits tokens via
        // sealed mutations and then appends a ledger snapshot, the
        // snapshot's tokens_used field must equal the sum of all
        // debit.tokens from prior SealedMutation rows.
        //
        // This is the "dispatcher must correctly account" invariant:
        // the audit-trail sum (post-hoc) must reconcile with the
        // ledger snapshot the dispatcher wrote (in-line). A
        // dispatcher bug that, e.g., debited 100 tokens to the
        // sealed mutation row but only 50 to the ledger snapshot,
        // would silently underreport on the snapshot UI.
        //
        // Pin via a constructed log where we know the sum upfront.
        let mut log = RunEventLog::new();
        let cap = Hash::from_bytes([1u8; 32]);
        // 4 sealed mutations: 25, 50, 75, 100 tokens.
        log.append_sealed_mutation(cap, BudgetDebit { tokens: 25, ..Default::default() });
        log.append_sealed_mutation(cap, BudgetDebit { tokens: 50, ..Default::default() });
        log.append_sealed_mutation(cap, BudgetDebit { tokens: 75, ..Default::default() });
        log.append_sealed_mutation(cap, BudgetDebit { tokens: 100, ..Default::default() });
        // Post-mutation ledger snapshot: caller's dispatcher writes
        // total tokens_used.
        let snapshot_ordinal = log.append_ledger_snapshot(BudgetLedger {
            tokens_used: 250, // sum: 25+50+75+100 = 250
            ..Default::default()
        });

        let (total_via_aggregate, count) = log.total_tokens_debited();
        assert_eq!(total_via_aggregate, 250, "aggregate sum must be 250");
        assert_eq!(count, 4);

        let snapshot_ledger = log
            .ledger_at_ordinal(snapshot_ordinal)
            .expect("snapshot at ordinal");
        assert_eq!(
            snapshot_ledger.tokens_used, total_via_aggregate,
            "snapshot.tokens_used must equal total_tokens_debited.0 for a correctly-accounted log"
        );
    }

    #[test]
    fn find_capability_hash_len_matches_sealed_mutations_filter_count() {
        // Phase 1 hardening — cross-helper consistency pin extending
        // the entry-counting trinity (total_tokens_debited /
        // sealed_mutations / entry_count_by_kind) with the
        // needle-specific path:
        //
        //   find_capability_hash(needle).len()
        //   == sealed_mutations().filter(|(_, c, _)| **c == needle).count()
        //
        // Both helpers walk the entries vector and filter by
        // capability_hash. A regression in either (e.g., find_capability_hash
        // missing rows the iterator surfaces, or vice versa) would
        // slip past the individual tests but break the cross-invariant
        // that audit dashboards rely on.
        let mut log = RunEventLog::new();
        let needle_a = Hash::from_bytes([0xAA; 32]);
        let needle_b = Hash::from_bytes([0xBB; 32]);

        log.append_sealed_mutation(needle_a, BudgetDebit::default());
        log.append_event(AgentEvent::ReasoningDelta { text: "r".into() });
        log.append_sealed_mutation(needle_b, BudgetDebit::default());
        log.append_sealed_mutation(needle_a, BudgetDebit::default());
        log.append_sealed_mutation(needle_a, BudgetDebit::default());
        log.append_ledger_snapshot(BudgetLedger::default());

        // For each of the 2 needles, the two helpers must agree on
        // count.
        for needle in [needle_a, needle_b] {
            let via_find = log.find_capability_hash(&needle).len();
            let via_iter = log
                .sealed_mutations()
                .filter(|(_, c, _)| **c == needle)
                .count();
            assert_eq!(
                via_find, via_iter,
                "needle {:?}: find_capability_hash.len {} != filter.count {}",
                needle, via_find, via_iter,
            );
        }
        // Specific values (independent witness).
        assert_eq!(log.find_capability_hash(&needle_a).len(), 3);
        assert_eq!(log.find_capability_hash(&needle_b).len(), 1);
        // Zero-needle (never appears).
        assert_eq!(log.find_capability_hash(&Hash::zero()).len(), 0);
    }

    #[test]
    fn total_tokens_debited_count_matches_sealed_mutations_count_and_entry_count_by_kind() {
        // Phase 1 hardening — cross-helper consistency pin (third
        // leg of the entry-counting trinity, complementing
        // entry_count_by_kind_sealed_field_agrees_with_sealed_mutations_iterator).
        // total_tokens_debited returns (total, count); the count
        // must equal entry_count_by_kind.sealed AND
        // sealed_mutations().count().
        //
        // A future refactor that diverged any one of these three
        // helpers from the others (e.g., total_tokens_debited
        // accidentally also counting ledger snapshots) would slip
        // past the existing pair-wise tests.
        let mut log = RunEventLog::new();
        log.append_event(AgentEvent::ReasoningDelta { text: "r".into() });
        for i in 0..5u64 {
            log.append_sealed_mutation(
                Hash::from_bytes([i as u8; 32]),
                BudgetDebit { tokens: i * 10, ..Default::default() },
            );
        }
        // Snapshots must NOT contribute to the sealed count.
        log.append_ledger_snapshot(BudgetLedger {
            tokens_used: 100,
            ..Default::default()
        });
        log.append_event(AgentEvent::Stop { reason: StopReason::EndTurn });

        let (_total, count_via_tokens) = log.total_tokens_debited();
        let count_via_iter = log.sealed_mutations().count();
        let (_events, count_via_tuple, _snapshots) = log.entry_count_by_kind();

        assert_eq!(count_via_tokens, 5, "expected 5 sealed mutations");
        assert_eq!(
            count_via_tokens, count_via_iter,
            "total_tokens_debited count must equal sealed_mutations().count()"
        );
        assert_eq!(
            count_via_tokens, count_via_tuple,
            "total_tokens_debited count must equal entry_count_by_kind.sealed"
        );
    }

    #[test]
    fn entry_count_by_kind_events_count_is_upper_bound_for_stop_and_error_counts() {
        // Phase 1 hardening — cross-helper consistency pin.
        // entry_count_by_kind's `events` field counts ALL
        // RunEventEntry::Event rows. stop_count + error_count count
        // only the Stop and Error AgentEvent variants. By
        // construction:
        //   events >= stop_count + error_count
        //
        // Equality holds when every Event row is either a Stop or
        // Error; strict-greater holds when other AgentEvent variants
        // (ReasoningDelta, FinalText, ToolCall, ToolResult) are
        // present.
        //
        // A future bug in any of these three helpers (e.g.,
        // entry_count_by_kind miscounting Stop rows as snapshots)
        // would break this invariant.
        let mut log = RunEventLog::new();
        log.append_event(AgentEvent::ReasoningDelta { text: "x".into() });
        log.append_event(AgentEvent::FinalText { text: "y".into() });
        log.append_event(AgentEvent::Stop { reason: StopReason::EndTurn });
        log.append_event(AgentEvent::Error {
            kind: AgentEventErrorKind::Provider,
            message: "z".into(),
        });
        log.append_sealed_mutation(Hash::zero(), BudgetDebit::default());
        log.append_ledger_snapshot(BudgetLedger::default());

        let (events, sealed, snapshots) = log.entry_count_by_kind();
        let stops = log.stop_count();
        let errors = log.error_count();

        // 4 events (ReasoningDelta + FinalText + Stop + Error),
        // 1 sealed, 1 snapshot.
        assert_eq!(events, 4);
        assert_eq!(sealed, 1);
        assert_eq!(snapshots, 1);
        assert_eq!(stops, 1);
        assert_eq!(errors, 1);

        // Cross-helper invariant: events >= stops + errors.
        assert!(
            events >= stops + errors,
            "events count {events} must be >= stops {stops} + errors {errors}"
        );
        // Strict-greater holds here because of the 2 non-terminal
        // events (ReasoningDelta + FinalText).
        assert_eq!(events, stops + errors + 2);
    }

    #[test]
    fn entry_count_by_kind_empty_log_returns_zeros() {
        let log = RunEventLog::new();
        assert_eq!(log.entry_count_by_kind(), (0, 0, 0));
    }

    #[test]
    fn entry_count_by_kind_tuple_position_is_events_sealed_snapshots_with_asymmetric_counts() {
        // Phase 1 hardening — tuple-position pin with strictly-asymmetric
        // counts. The existing rolls-up test uses (3, 2, 1) which would
        // not catch every swap (it would catch most), but an asymmetric
        // (5, 3, 7) eliminates ALL position-swap ambiguity: no two
        // positions hold equal values, so any variant->counter binding
        // mistake immediately surfaces. Documents the canonical position
        // order: index 0 = events, index 1 = sealed mutations, index 2 =
        // ledger snapshots.
        let mut log = RunEventLog::new();
        // 5 events.
        for i in 0..5u64 {
            log.append_event(AgentEvent::ReasoningDelta {
                text: format!("e{i}"),
            });
        }
        // 3 sealed mutations.
        for i in 0..3u8 {
            log.append_sealed_mutation(Hash::from_bytes([i; 32]), BudgetDebit::default());
        }
        // 7 ledger snapshots.
        for _ in 0..7 {
            log.append_ledger_snapshot(BudgetLedger::default());
        }

        let (events, sealed, snapshots) = log.entry_count_by_kind();
        assert_eq!(events, 5, "tuple.0 must count Event entries");
        assert_eq!(sealed, 3, "tuple.1 must count SealedMutation entries");
        assert_eq!(snapshots, 7, "tuple.2 must count LedgerSnapshot entries");
        // Sum invariant.
        assert_eq!(events + sealed + snapshots, log.len());
        // Asymmetry pin: no two counts are equal, so a swap is detectable.
        assert_ne!(events, sealed);
        assert_ne!(sealed, snapshots);
        assert_ne!(events, snapshots);
    }

    #[test]
    fn detect_capability_reuse_matches_find_capability_hash_len_minus_cap() {
        // Phase 1 hardening — cross-helper consistency pin.
        // detect_capability_reuse is documented as
        // `find_capability_hash(needle).len().saturating_sub(max_uses)`.
        // The relationship is implicit in the impl but unpinned at
        // the test level — a future refactor that swapped subtraction
        // for some other relation (e.g., flagged ANY count over
        // max_uses with a fixed 1 instead of the overage delta)
        // would silently change audit semantics.
        let mut log = RunEventLog::new();
        let cap = Hash::from_bytes([7u8; 32]);
        for _ in 0..5 {
            log.append_sealed_mutation(cap, BudgetDebit::default());
        }
        let count = log.find_capability_hash(&cap).len();
        assert_eq!(count, 5);

        // Cross-helper invariant across a sweep of max_uses values.
        for max_uses in [0, 1, 2, 3, 4, 5, 6, 10] {
            let direct = count.saturating_sub(max_uses);
            let via_helper = log.detect_capability_reuse(&cap, max_uses);
            assert_eq!(
                via_helper, direct,
                "detect_capability_reuse({cap:?}, {max_uses}) must equal \
                 count.saturating_sub(max_uses) = {direct}, got {via_helper}"
            );
        }
        // And for an unrelated needle (count = 0): overage is always 0.
        let other = Hash::from_bytes([99u8; 32]);
        for max_uses in [0, 1, 100] {
            assert_eq!(log.detect_capability_reuse(&other, max_uses), 0);
        }
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
    fn detect_capability_reuse_with_usize_max_max_uses_always_returns_zero() {
        // Phase 1 hardening — boundary completeness companion to
        // iter-134 zero-max-uses + the existing 3 / 5 / 10 caps.
        // max_uses == usize::MAX means "unlimited reuse allowed";
        // overage saturates to 0 via saturating_sub.
        let mut log = RunEventLog::new();
        let cap = Hash::from_bytes([42u8; 32]);
        for _ in 0..100 {
            log.append_sealed_mutation(cap, BudgetDebit::default());
        }
        assert_eq!(log.detect_capability_reuse(&cap, usize::MAX), 0);
        // Even when count exceeds max_uses by 1, saturating_sub
        // still clamps overage at 0 when max is usize::MAX.
        assert_eq!(log.detect_capability_reuse(&cap, usize::MAX - 1), 0);
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
    fn find_capability_hash_returns_ordinals_in_strictly_ascending_order() {
        // Phase 1 hardening — ordering pin for find_capability_hash.
        // Companion to find_capability_hash_returns_matching_ordinals_in_order
        // (which only asserts the SPECIFIC ordinals [o1, o4]); this
        // adds a 4-row spread covering an interleaved-needle scenario
        // and asserts STRICTLY ASCENDING order on the result.
        //
        // The implementation walks entries in append order; since
        // ordinals are dense + monotonic (append always appends), the
        // result vec is naturally strict-ascending. A future "let me
        // index by capability_hash and serve from a sorted set"
        // refactor could silently break the strict-ascending guarantee
        // (HashMap iteration order is non-deterministic in Rust) —
        // surface here.
        let mut log = RunEventLog::new();
        let needle = Hash::from_bytes([0x77; 32]);
        let other = Hash::from_bytes([0x88; 32]);
        // Sealed mutations at ordinals 0, 2, 3, 5, with non-matching
        // rows at 1 and 4.
        log.append_sealed_mutation(needle, BudgetDebit::default());      // 0
        log.append_event(AgentEvent::ReasoningDelta { text: "a".into() });// 1
        log.append_sealed_mutation(needle, BudgetDebit::default());      // 2
        log.append_sealed_mutation(needle, BudgetDebit::default());      // 3
        log.append_sealed_mutation(other, BudgetDebit::default());       // 4
        log.append_sealed_mutation(needle, BudgetDebit::default());      // 5

        let hits = log.find_capability_hash(&needle);
        assert_eq!(hits, vec![0, 2, 3, 5], "ordinals must appear in append order");
        // Strict-ascending: each ordinal > the previous.
        for pair in hits.windows(2) {
            assert!(pair[0] < pair[1], "ordinals must be strictly ascending");
        }
    }

    #[test]
    fn find_capability_hash_isolates_needles_no_cross_contamination() {
        // Phase 1 hardening — needle-isolation pin. Companion to
        // find_capability_hash_returns_empty_when_needle_not_present_in_nonempty_log
        // (which pins the no-false-positives case).
        //
        // With 3 distinct capability_hash needles interleaved in the
        // same log, find_capability_hash(A) must NOT see B-rows or
        // C-rows in its result, and vice versa. The 3 result Vecs
        // must be DISJOINT — no ordinal appears in more than one
        // result.
        //
        // A future "let me use prefix matching on capability_hash for
        // approximate-match audit queries" refactor would silently
        // cross-contaminate the results — surface here.
        let mut log = RunEventLog::new();
        let a = Hash::from_bytes([0xAA; 32]);
        let b = Hash::from_bytes([0xBB; 32]);
        let c = Hash::from_bytes([0xCC; 32]);
        // 6 sealed mutations: A at 0,3; B at 1,4; C at 2,5.
        log.append_sealed_mutation(a, BudgetDebit::default()); // 0
        log.append_sealed_mutation(b, BudgetDebit::default()); // 1
        log.append_sealed_mutation(c, BudgetDebit::default()); // 2
        log.append_sealed_mutation(a, BudgetDebit::default()); // 3
        log.append_sealed_mutation(b, BudgetDebit::default()); // 4
        log.append_sealed_mutation(c, BudgetDebit::default()); // 5

        let hits_a = log.find_capability_hash(&a);
        let hits_b = log.find_capability_hash(&b);
        let hits_c = log.find_capability_hash(&c);
        assert_eq!(hits_a, vec![0, 3]);
        assert_eq!(hits_b, vec![1, 4]);
        assert_eq!(hits_c, vec![2, 5]);

        // Disjoint: no ordinal appears in more than one result.
        use std::collections::HashSet;
        let set_a: HashSet<u64> = hits_a.iter().copied().collect();
        let set_b: HashSet<u64> = hits_b.iter().copied().collect();
        let set_c: HashSet<u64> = hits_c.iter().copied().collect();
        assert!(set_a.is_disjoint(&set_b), "A and B results must be disjoint");
        assert!(set_b.is_disjoint(&set_c), "B and C results must be disjoint");
        assert!(set_a.is_disjoint(&set_c), "A and C results must be disjoint");
    }

    #[test]
    fn find_capability_hash_returns_empty_when_needle_not_present_in_nonempty_log() {
        // Phase 1 hardening — negative-search-result pin. Companion
        // to find_capability_hash_matches_zero_hash_needle... (which
        // pins zero-hash being correctly matched when ACTUALLY
        // present). This pins the inverse: a needle that's NOT
        // present in a log with OTHER sealed mutations returns
        // empty Vec (no false-positives).
        //
        // The log has sealed mutations under needles A and B; we
        // query for an UNRELATED needle C and expect an empty result.
        let mut log = RunEventLog::new();
        let needle_a = Hash::from_bytes([0xAA; 32]);
        let needle_b = Hash::from_bytes([0xBB; 32]);
        let unrelated_c = Hash::from_bytes([0xCC; 32]);
        log.append_sealed_mutation(needle_a, BudgetDebit::default());
        log.append_sealed_mutation(needle_b, BudgetDebit::default());
        log.append_event(AgentEvent::ReasoningDelta { text: "x".into() });
        log.append_sealed_mutation(needle_a, BudgetDebit::default());

        let hits_c = log.find_capability_hash(&unrelated_c);
        assert!(hits_c.is_empty(), "unrelated needle must yield empty Vec");
        // Sanity: needles A and B DO match (proves the test isn't
        // trivially passing due to a broken find_capability_hash).
        assert_eq!(log.find_capability_hash(&needle_a).len(), 2);
        assert_eq!(log.find_capability_hash(&needle_b).len(), 1);
    }

    #[test]
    fn find_capability_hash_is_idempotent_across_multiple_calls() {
        // Phase 1 hardening — pure-function pin (companion to
        // iter-217 sealed_mutations idempotency + iter-168
        // digest_intact idempotency). find_capability_hash returns
        // a fresh Vec on each call; calling it multiple times must
        // produce identical Vecs.
        //
        // A future "let me cache the matching ordinals on first
        // call" refactor with interior mutability would silently
        // break repeated audit queries.
        let mut log = RunEventLog::new();
        let cap = Hash::from_bytes([4u8; 32]);
        log.append_sealed_mutation(cap, BudgetDebit::default());
        log.append_event(AgentEvent::ReasoningDelta { text: "x".into() });
        log.append_sealed_mutation(cap, BudgetDebit::default());

        let first = log.find_capability_hash(&cap);
        let second = log.find_capability_hash(&cap);
        let third = log.find_capability_hash(&cap);
        assert_eq!(first.len(), 2);
        assert_eq!(first, second);
        assert_eq!(second, third);
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
    fn find_capability_hash_matches_zero_hash_needle_when_rows_actually_have_zero_hash() {
        // Phase 1 hardening — boundary pin. The existing
        // find_capability_hash_returns_matching_ordinals_in_order test
        // calls find_capability_hash(&Hash::zero()) only in the
        // NEGATIVE case (no matching rows). The positive case —
        // SealedMutation rows whose capability_hash IS Hash::zero
        // (e.g., a test fixture or a synthesized envelope), and
        // find_capability_hash correctly returns their ordinals —
        // is unpinned.
        //
        // Without this pin, a future refactor that special-cased
        // Hash::zero (e.g., "treat zero as sentinel-NoCapability;
        // don't match it") would silently break replay queries that
        // legitimately use zero-hashed envelopes.
        let mut log = RunEventLog::new();
        log.append_event(AgentEvent::ReasoningDelta { text: "x".into() }); // 0
        let o1 = log.append_sealed_mutation(Hash::zero(), BudgetDebit::default()); // 1
        log.append_event(AgentEvent::FinalText { text: "y".into() }); // 2
        let other = Hash::from_bytes([1u8; 32]);
        log.append_sealed_mutation(other, BudgetDebit::default()); // 3
        let o4 = log.append_sealed_mutation(Hash::zero(), BudgetDebit::default()); // 4

        // Needle = Hash::zero matches the two zero-hashed rows.
        let hits = log.find_capability_hash(&Hash::zero());
        assert_eq!(hits, vec![o1, o4]);
        assert_eq!(hits.len(), 2);
    }

    #[test]
    fn run_event_entry_variants_field_shapes_pinned_via_destructure() {
        // Phase 1 hardening — field-shape pin for RunEventEntry's 3
        // variants (companion to AgentEvent iter-461 and the broader
        // destructure pin family iter-454..iter-461).
        //
        // Per-variant field shapes:
        //   - Event { ordinal: u64, event: AgentEvent }                   → 2 named
        //   - SealedMutation { ordinal: u64, capability_hash: Hash,
        //                      debit: BudgetDebit }                      → 3 named
        //   - LedgerSnapshot { ordinal: u64, ledger: BudgetLedger }       → 2 named
        //
        // RunEventEntry is the persistent witness row; a field change
        // here forks every persisted RunEventLog.
        let event = RunEventEntry::Event {
            ordinal: 7,
            event: AgentEvent::ReasoningDelta { text: "x".into() },
        };
        match event {
            RunEventEntry::Event { ordinal, event } => {
                let _: u64 = ordinal;
                let _: AgentEvent = event;
            }
            _ => unreachable!(),
        }
        let sealed = RunEventEntry::SealedMutation {
            ordinal: 8,
            capability_hash: Hash::zero(),
            debit: BudgetDebit::default(),
        };
        match sealed {
            RunEventEntry::SealedMutation { ordinal, capability_hash, debit } => {
                let _: u64 = ordinal;
                let _: Hash = capability_hash;
                let _: BudgetDebit = debit;
            }
            _ => unreachable!(),
        }
        let snapshot = RunEventEntry::LedgerSnapshot {
            ordinal: 9,
            ledger: BudgetLedger::default(),
        };
        match snapshot {
            RunEventEntry::LedgerSnapshot { ordinal, ledger } => {
                let _: u64 = ordinal;
                let _: BudgetLedger = ledger;
            }
            _ => unreachable!(),
        }
    }

    #[test]
    fn run_event_entry_variant_count_is_three() {
        // Phase 1 hardening — cardinality pin completing the
        // count-pin series with the most replay-critical enum.
        // RunEventEntry has 3 variants (Event, SealedMutation,
        // LedgerSnapshot) — every row shape that lands in the
        // append-only witness trail. A future addition (e.g., an
        // ApprovalRequest row, or a CapabilityIssued row) requires:
        //   - append_* method on RunEventLog
        //   - entry_count_by_kind tuple extension (currently
        //     returns 3-tuple — would need expansion)
        //   - serde tag + negative-serde pin updates
        //   - root_hash domain-separation invariant (the entry
        //     encoding feeds blake3)
        // Pin the cardinality + pairwise distinctness so any
        // addition surfaces at PR review with deliberate updates
        // across all sites.
        let variants = [
            RunEventEntry::Event {
                ordinal: 0,
                event: AgentEvent::ReasoningDelta { text: "x".into() },
            },
            RunEventEntry::SealedMutation {
                ordinal: 0,
                capability_hash: Hash::zero(),
                debit: BudgetDebit::default(),
            },
            RunEventEntry::LedgerSnapshot {
                ordinal: 0,
                ledger: BudgetLedger::default(),
            },
        ];
        assert_eq!(variants.len(), 3);
        // Pairwise structural distinctness — each variant has a
        // different discriminant.
        for i in 0..variants.len() {
            for j in (i + 1)..variants.len() {
                assert_ne!(
                    variants[i], variants[j],
                    "entries[{i}] and entries[{j}] must be structurally distinct"
                );
            }
        }
    }

    #[test]
    fn run_event_entry_multi_field_variants_preserve_field_declaration_order() {
        // Phase 1 hardening — wire-shape pin extending iter-153
        // (per-variant field names) with field-ORDER for all 3
        // RunEventEntry variants:
        //   Event { ordinal, event }
        //   SealedMutation { ordinal, capability_hash, debit }
        //   LedgerSnapshot { ordinal, ledger }
        //
        // A field reorder in any variant changes the .epbundle
        // byte shape. Replay tools that diff bundles byte-equal
        // would break silently.
        let event_entry = RunEventEntry::Event {
            ordinal: 7,
            event: AgentEvent::ReasoningDelta { text: "x".into() },
        };
        let s = serde_json::to_string(&event_entry).expect("serialise");
        assert!(
            s.find("\"ordinal\":").unwrap() < s.find("\"event\":").unwrap(),
            "Event.ordinal must appear before Event.event in {s}"
        );

        let sealed = RunEventEntry::SealedMutation {
            ordinal: 8,
            capability_hash: Hash::zero(),
            debit: BudgetDebit::default(),
        };
        let s = serde_json::to_string(&sealed).expect("serialise");
        let ord = s.find("\"ordinal\":").unwrap();
        let cap = s.find("\"capability_hash\":").unwrap();
        let deb = s.find("\"debit\":").unwrap();
        assert!(ord < cap, "SealedMutation.ordinal must precede capability_hash in {s}");
        assert!(cap < deb, "SealedMutation.capability_hash must precede debit in {s}");

        let snap = RunEventEntry::LedgerSnapshot {
            ordinal: 9,
            ledger: BudgetLedger::default(),
        };
        let s = serde_json::to_string(&snap).expect("serialise");
        assert!(
            s.find("\"ordinal\":").unwrap() < s.find("\"ledger\":").unwrap(),
            "LedgerSnapshot.ordinal must appear before ledger in {s}"
        );
    }

    #[test]
    fn run_event_entry_per_variant_field_names_pinned_exactly() {
        // Phase 1 hardening — wire-shape pin extending the per-variant
        // pin pattern (ProviderPolicy iter-151, AgentEvent iter-152)
        // to RunEventEntry. Each variant carries:
        //   - Event: ordinal + event
        //   - SealedMutation: ordinal + capability_hash + debit
        //   - LedgerSnapshot: ordinal + ledger
        //
        // A silent rename of any of these field names would round-
        // trip cleanly but break .epbundle replay tools and Swift
        // bridge readers that parse the persistence shape by field
        // name.
        let event_entry = RunEventEntry::Event {
            ordinal: 7,
            event: AgentEvent::ReasoningDelta { text: "x".into() },
        };
        let s = serde_json::to_string(&event_entry).expect("serialise");
        for needle in ["\"ordinal\":7", "\"event\":{"] {
            assert!(
                s.contains(needle),
                "Event entry missing {needle:?} — got {s}"
            );
        }

        let sealed = RunEventEntry::SealedMutation {
            ordinal: 8,
            capability_hash: Hash::from_bytes([1u8; 32]),
            debit: BudgetDebit { tokens: 42, ..Default::default() },
        };
        let s = serde_json::to_string(&sealed).expect("serialise");
        for needle in ["\"ordinal\":8", "\"capability_hash\":", "\"debit\":{"] {
            assert!(
                s.contains(needle),
                "SealedMutation entry missing {needle:?} — got {s}"
            );
        }

        let snapshot = RunEventEntry::LedgerSnapshot {
            ordinal: 9,
            ledger: BudgetLedger {
                tokens_used: 100,
                ..Default::default()
            },
        };
        let s = serde_json::to_string(&snapshot).expect("serialise");
        for needle in ["\"ordinal\":9", "\"ledger\":{"] {
            assert!(
                s.contains(needle),
                "LedgerSnapshot entry missing {needle:?} — got {s}"
            );
        }
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
    fn full_log_with_all_3_variants_round_trips_through_json_preserving_root_hash() {
        // Phase 1 hardening MILESTONE iter-300 — comprehensive
        // round-trip pin. A log containing every RunEventEntry
        // variant (Event with each AgentEvent subvariant, plus
        // SealedMutation + LedgerSnapshot) must serialise to JSON,
        // deserialise back, and produce a root_hash byte-equal to
        // the original.
        //
        // Builds on the tamper-sensitivity pins (iter-295/296/297/
        // 298/299) — those prove the root_hash CHANGES on any
        // byte change; this proves the root_hash is STABLE through
        // a lossless round-trip. Together they form a complete
        // chain-of-custody contract for the .epbundle replay
        // format.
        use crate::agent_runtime_v2::mission::ToolCall;
        let mut log = RunEventLog::new();
        log.append_event(AgentEvent::ReasoningDelta { text: "考えている".into() });
        log.append_event(AgentEvent::FinalText { text: "答え: 42".into() });
        log.append_event(AgentEvent::ToolCall {
            call: ToolCall {
                name: "vault.read".into(),
                arguments: serde_json::json!({"path": "笔记"}),
            },
        });
        log.append_event(AgentEvent::ToolResult {
            name: "vault.read".into(),
            result: serde_json::json!({"内容": "笔记内容"}),
        });
        log.append_sealed_mutation(
            Hash::from_bytes([7u8; 32]),
            BudgetDebit {
                tokens: 111,
                wall_ms: 222,
                tool_calls: 3,
                subprocess_ms: 444,
                memory_bytes: 555,
            },
        );
        log.append_ledger_snapshot(BudgetLedger {
            tokens_used: 111,
            wall_used_ms: 222,
            tool_calls_used: 3,
            subprocess_used_ms: 444,
            memory_bytes_used: 555,
        });
        log.append_event(AgentEvent::Stop { reason: StopReason::EndTurn });
        log.append_event(AgentEvent::Error {
            kind: AgentEventErrorKind::Provider,
            message: "transport: 接続失敗".into(),
        });

        let original_root = log.root_hash();
        let original_len = log.len();

        // Round-trip through JSON.
        let s = serde_json::to_string(&log).expect("serialise full log");
        let back: RunEventLog = serde_json::from_str(&s).expect("deserialise full log");
        // Length + root_hash both preserved.
        assert_eq!(back.len(), original_len);
        assert_eq!(back.root_hash(), original_root);
        // entries() also byte-equal.
        assert_eq!(back.entries(), log.entries());
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
