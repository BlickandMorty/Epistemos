//! `MutationEnvelope` — the only path through which a v2 executor may
//! emit a side-effect.
//!
//! Every write (vault create/update/delete, graph edge insert, tool
//! invocation that has external effect) MUST be wrapped in a
//! `MutationEnvelope`. The envelope binds three witnesses:
//!
//! 1. **capability_hash** — BLAKE3 over the issuing macaroon's signature
//!    chain (`Macaroon::capability_hash()`). Any later inspector can
//!    cross-reference back to the `RunEventLog` row that authorised the
//!    write.
//! 2. **debit** — the resource debit that was applied to the
//!    `BudgetLedger`. Replay can recompute the post-write ledger
//!    deterministically.
//! 3. **payload** — the serialisable description of what the write does.
//!
//! `Sealer::seal_and_apply` is the gate: it verifies the capability
//! against the runtime context, debits the budget, then (and only
//! then) hands the payload to the `MutationWriter`. Either rejection
//! short-circuits before any writer call — proving the §4 T11
//! "denied mutation does not write" invariant.
//!
//! Acceptance bar references (§4 T11):
//! - MutationEnvelope output wrapping (here)
//! - Test: denied mutation does not write (here)

use serde::{Deserialize, Serialize};

use crate::cognitive_dag::macaroons::RuntimeContext;
use crate::cognitive_dag::node::Hash;

use super::budget::{BudgetDebit, BudgetError, BudgetGate, BudgetLedger};
use super::capability::{AgentRuntimeV2Capability, CapabilityError};

/// Witness-bearing wrapper around any mutation payload `P`. Constructed
/// by the executor; verified + applied by the `Sealer`.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct MutationEnvelope<P> {
    /// BLAKE3 over the issuing macaroon's signature chain. Bound at
    /// envelope-construction time; never recomputed by the writer.
    pub capability_hash: Hash,
    /// Resource debit that will be applied when the envelope is sealed.
    pub debit: BudgetDebit,
    /// The mutation payload itself. Opaque to the envelope — only the
    /// `MutationWriter` interprets it.
    pub payload: P,
}

impl<P> MutationEnvelope<P> {
    /// Recommended maximum serialised payload size. Above this, the
    /// `RunEventLog` row + downstream replay become wall-clock
    /// expensive without proportional value. The runtime DOES NOT
    /// enforce this — it surfaces a soft signal via
    /// [`Self::exceeds_recommended_payload_size`] for callers that
    /// can choose to chunk or stream instead.
    ///
    /// Phase 1 hardening boundary doc; iter-23.
    pub const MAX_RECOMMENDED_PAYLOAD_BYTES: usize = 4 * 1024 * 1024;

    /// Construct a fresh envelope. Callers must obtain the
    /// `capability_hash` from the macaroon backing the capability they
    /// verified for this write.
    #[must_use]
    pub fn new(capability_hash: Hash, debit: BudgetDebit, payload: P) -> Self {
        Self {
            capability_hash,
            debit,
            payload,
        }
    }
}

impl<P> MutationEnvelope<P> {
    /// Hash-only summary string for log lines that touch sensitive
    /// payloads. Returns
    /// `"envelope{cap=<hex8>, tokens=N, tool_calls=N}"` — never
    /// prints the payload, never prints the full hash. Use this in
    /// place of `{:?}` when the run logs to a place the payload
    /// must not appear (audit dashboards, public logs).
    ///
    /// Phase 1 hardening — secrets-hygiene surface.
    #[must_use]
    pub fn log_summary(&self) -> String {
        let hex = self.capability_hash.to_hex();
        let short = if hex.len() >= 8 { &hex[..8] } else { hex.as_str() };
        format!(
            "envelope{{cap={}, tokens={}, tool_calls={}}}",
            short, self.debit.tokens, self.debit.tool_calls
        )
    }
}

impl<P: Serialize> MutationEnvelope<P> {
    /// Estimate the serialised JSON byte size of the payload. Pure
    /// computation; the runtime never persists this number, so a
    /// caller may call it freely without affecting witness state.
    /// Returns `None` if the payload itself fails to serialise (in
    /// which case the envelope was unusable anyway).
    #[must_use]
    pub fn estimate_payload_bytes(&self) -> Option<usize> {
        serde_json::to_vec(&self.payload).ok().map(|b| b.len())
    }

    /// True iff the payload serialises to more bytes than
    /// [`Self::MAX_RECOMMENDED_PAYLOAD_BYTES`]. Returns `false` for
    /// unserialisable payloads (the dispatcher will surface the
    /// real serialisation error elsewhere).
    #[must_use]
    pub fn exceeds_recommended_payload_size(&self) -> bool {
        self.estimate_payload_bytes()
            .map_or(false, |n| n > Self::MAX_RECOMMENDED_PAYLOAD_BYTES)
    }
}

/// Side-effect surface — the writer the envelope ultimately calls when
/// (and only when) the envelope clears every gate. Implementors are
/// vault writers, graph mutators, tool side-effect adapters.
pub trait MutationWriter<P>: Send + Sync {
    type Receipt;
    type WriteError;
    fn write(&mut self, payload: &P) -> Result<Self::Receipt, Self::WriteError>;
}

/// Errors raised by `Sealer::seal_and_apply`. Distinct from
/// `MutationWriter::WriteError` because every variant here is a
/// pre-write gate failure — by construction, none of them touch the
/// writer.
#[derive(Debug, Clone, PartialEq)]
pub enum SealError<W> {
    Capability(CapabilityError),
    Budget(BudgetError),
    /// The writer itself failed AFTER all gates cleared. Only this
    /// variant can carry the writer's own error type.
    Write(W),
}

/// Verifies + applies envelopes. Stateless; the caller owns the
/// capability, gate, and current ledger.
pub struct Sealer<'a, C: AgentRuntimeV2Capability + ?Sized> {
    pub capability: &'a C,
    pub gate: BudgetGate,
}

impl<'a, C: AgentRuntimeV2Capability + ?Sized> Sealer<'a, C> {
    /// Verify-then-debit-then-write. The three steps are sequenced so
    /// that either rejection short-circuits BEFORE the writer is
    /// touched. Returns the advanced ledger + writer receipt on success.
    pub fn seal_and_apply<P, W>(
        &self,
        ctx: &RuntimeContext,
        ledger: BudgetLedger,
        envelope: MutationEnvelope<P>,
        writer: &mut W,
    ) -> Result<(BudgetLedger, W::Receipt), SealError<W::WriteError>>
    where
        W: MutationWriter<P>,
    {
        // Gate 1: capability verification.
        self.capability.verify(ctx).map_err(SealError::Capability)?;
        // Gate 2: budget debit. The new ledger is held until the write
        // succeeds; on writer failure the caller keeps the original
        // ledger (the BudgetGate has already proven the debit is
        // affordable — but we only consider it spent once the side
        // effect lands).
        let advanced_ledger = self
            .gate
            .check_and_debit(ledger, envelope.debit)
            .map_err(SealError::Budget)?;
        // Gate 3: write. Only reached if both prior gates cleared.
        let receipt = writer.write(&envelope.payload).map_err(SealError::Write)?;
        Ok((advanced_ledger, receipt))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::agent_runtime_v2::budget::{BudgetDebit, BudgetSpec, BudgetTerm};
    use crate::agent_runtime_v2::capability::MacaroonCapability;
    use crate::cognitive_dag::macaroons::{issue, RuntimeContext, VerifyError};
    use crate::cognitive_dag::node::{CapabilityKind, CapabilityScope};

    /// Recording writer used by the denied-mutation test. Counts the
    /// number of `write` invocations so the assertion can prove no
    /// writer call ever fired when a gate denied.
    struct RecordingWriter {
        writes: usize,
        receipt: u64,
    }

    impl RecordingWriter {
        fn new() -> Self {
            Self {
                writes: 0,
                receipt: 0,
            }
        }
    }

    impl MutationWriter<String> for RecordingWriter {
        type Receipt = u64;
        type WriteError = std::convert::Infallible;
        fn write(&mut self, payload: &String) -> Result<u64, Self::WriteError> {
            self.writes += 1;
            self.receipt = payload.len() as u64;
            Ok(self.receipt)
        }
    }

    fn root_key() -> [u8; 32] {
        let mut k = [0u8; 32];
        k[0..6].copy_from_slice(b"keyZ__");
        k
    }

    fn valid_capability(now_relative_expiry: Option<u64>) -> MacaroonCapability {
        let m = issue(
            "session-iter4",
            CapabilityKind::ToolInvoke("vault.write".to_string()),
            CapabilityScope("vault".to_string()),
            now_relative_expiry,
            &root_key(),
        );
        MacaroonCapability::new(m, root_key())
    }

    fn ctx() -> RuntimeContext {
        RuntimeContext {
            now_ms: 1_000,
            scope_path: "vault/notes/2026".to_string(),
            tool_name: "vault.write".to_string(),
            additional: Default::default(),
        }
    }

    #[test]
    fn mutation_writer_and_sealer_carry_send_sync_bounds_compile_pin() {
        // Phase 1 hardening — compile-time Send+Sync pin (companion
        // to iter-136's capability pin). MutationWriter must be
        // Send+Sync so the executor pool can hand writer instances
        // across worker threads; without that, the dispatcher
        // cannot share a vault writer / graph mutator across the
        // executor fleet.
        //
        // A future refactor dropping the bound would compile-fail
        // here. assert_send_sync is a no-op probe enforced by trait
        // bounds at instantiation time.
        fn assert_send_sync<T: Send + Sync + ?Sized>() {}
        // Trait surface: dyn MutationWriter<String> (the form the
        // dispatcher sees behind a trait object).
        assert_send_sync::<dyn MutationWriter<String, Receipt = u64, WriteError = std::convert::Infallible>>();
        // Concrete implementor from the test suite.
        assert_send_sync::<RecordingWriter>();
    }

    #[test]
    fn denied_mutation_does_not_write() {
        // §4 T11 acceptance: "denied mutation does not write".
        // Wrong key → capability verify fails → writer never called.
        let m = issue(
            "session-iter4",
            CapabilityKind::ToolInvoke("vault.write".to_string()),
            CapabilityScope("vault".to_string()),
            None,
            &root_key(),
        );
        let mut wrong_key = root_key();
        wrong_key[0] ^= 0xFF;
        let cap = MacaroonCapability::new(m, wrong_key);
        let sealer = Sealer {
            capability: &cap,
            gate: BudgetGate::new(BudgetSpec::default()),
        };
        let envelope = MutationEnvelope::new(
            cap.macaroon().capability_hash(),
            BudgetDebit::default(),
            "would-write-this".to_string(),
        );
        let mut writer = RecordingWriter::new();
        let err = sealer
            .seal_and_apply(&ctx(), BudgetLedger::default(), envelope, &mut writer)
            .expect_err("denied mutation must not be applied");
        assert!(
            matches!(err, SealError::Capability(_)),
            "expected SealError::Capability, got {err:?}"
        );
        assert_eq!(
            writer.writes, 0,
            "writer must not be invoked when capability verify denies"
        );
        assert_eq!(writer.receipt, 0);
    }

    #[test]
    fn sealer_capability_denial_does_not_taint_subsequent_valid_apply() {
        // Phase 1 hardening — capability-gate partial-failure
        // companion to iter-? `sealer_writer_failure_does_not_advance_caller_ledger`.
        // The writer-failure pin proved that a 3rd-gate failure doesn't
        // leak budget through the gate. This pins the symmetric truth
        // for the 1st gate: a capability denial does NOT taint the
        // BudgetGate (no internal counter advance), so a fresh sealer
        // built from a VALID capability and the SAME pre-denial ledger
        // lands at single-debit state.
        //
        // Defends against a future "let me prefetch the budget reservation
        // before capability verify" refactor that would silently
        // double-debit on retry-after-denial flows.
        let m = issue(
            "session-iter4",
            CapabilityKind::ToolInvoke("vault.write".to_string()),
            CapabilityScope("vault".to_string()),
            Some(10_000),
            &root_key(),
        );
        let mut wrong_key = root_key();
        wrong_key[0] ^= 0xFF;
        let bad_cap = MacaroonCapability::new(m.clone(), wrong_key);
        let bad_sealer = Sealer {
            capability: &bad_cap,
            gate: BudgetGate::new(BudgetSpec::new(1_000, 0, 5, 0)),
        };
        let envelope = MutationEnvelope::new(
            bad_cap.macaroon().capability_hash(),
            BudgetDebit { tokens: 25, tool_calls: 1, ..Default::default() },
            "post-denial-retry".to_string(),
        );

        let ledger_before = BudgetLedger::default();
        let mut writer = RecordingWriter::new();
        let err = bad_sealer
            .seal_and_apply(&ctx(), ledger_before, envelope.clone(), &mut writer)
            .expect_err("forged-key denial must surface as Err");
        assert!(
            matches!(err, SealError::Capability(_)),
            "expected SealError::Capability, got {err:?}"
        );
        assert_eq!(writer.writes, 0, "writer must not run on capability denial");

        // Now retry with a VALID-keyed sealer (BudgetGate must be a
        // fresh instance — Sealer is single-use by ownership, mirroring
        // the writer-failure test). Land at single-debit state.
        let good_cap = MacaroonCapability::new(m, root_key());
        let good_sealer = Sealer {
            capability: &good_cap,
            gate: BudgetGate::new(BudgetSpec::new(1_000, 0, 5, 0)),
        };
        let good_envelope = MutationEnvelope::new(
            good_cap.macaroon().capability_hash(),
            BudgetDebit { tokens: 25, tool_calls: 1, ..Default::default() },
            "post-denial-retry".to_string(),
        );
        let mut good_writer = RecordingWriter::new();
        let (ledger_after, _) = good_sealer
            .seal_and_apply(&ctx(), ledger_before, good_envelope, &mut good_writer)
            .expect("valid retry must apply");
        assert_eq!(good_writer.writes, 1);
        assert_eq!(ledger_after.tokens_used, 25, "single debit, not double");
        assert_eq!(ledger_after.tool_calls_used, 1, "single debit, not double");
        // Pre-call ledger remained zero — Sealer never mutated it
        // through the capability-denial path.
        assert_eq!(ledger_before, BudgetLedger::default());
    }

    #[test]
    fn sealer_budget_rejection_does_not_taint_subsequent_apply_with_budget_room() {
        // Phase 1 hardening — 2nd-gate companion to the writer-failure
        // (3rd-gate) and capability-denial (1st-gate) retry pins.
        // Completes the 3-leg gate-isolation pin pattern.
        //
        // A budget-exhaustion denial does NOT secretly debit the
        // caller's ledger nor invoke the writer. A retry on a fresh
        // Sealer with a generous budget cap (and the SAME pre-call
        // ledger) lands at single-debit state.
        //
        // Defends against a future "let me debit speculatively before
        // checking the cap" refactor that would leak budget through
        // the budget gate.
        let cap = valid_capability(Some(10_000));
        // Tight tokens=10 cap — debit=25 MUST fail at Gate 2 on
        // first attempt. (0 in the spec means UNBOUNDED per doctrine,
        // so we use a low positive cap instead.)
        let tight_sealer = Sealer {
            capability: &cap,
            gate: BudgetGate::new(BudgetSpec::new(10, 0, 5, 0)),
        };
        let envelope = MutationEnvelope::new(
            cap.macaroon().capability_hash(),
            BudgetDebit { tokens: 25, tool_calls: 1, ..Default::default() },
            "post-budget-denial-retry".to_string(),
        );

        let ledger_before = BudgetLedger::default();
        let mut writer = RecordingWriter::new();
        let err = tight_sealer
            .seal_and_apply(&ctx(), ledger_before, envelope.clone(), &mut writer)
            .expect_err("tokens=10 cap vs 25-token debit must surface as Err");
        assert!(
            matches!(err, SealError::Budget(_)),
            "expected SealError::Budget(_), got {err:?}"
        );
        assert_eq!(writer.writes, 0, "writer must not run on budget denial");

        // Retry on a fresh sealer with a generous tool_calls cap
        // (BudgetGate is a fresh instance — Sealer is single-use by
        // ownership). Land at single-debit state.
        let generous_sealer = Sealer {
            capability: &cap,
            gate: BudgetGate::new(BudgetSpec::new(1_000, 0, 5, 0)),
        };
        let mut good_writer = RecordingWriter::new();
        let (ledger_after, _) = generous_sealer
            .seal_and_apply(&ctx(), ledger_before, envelope, &mut good_writer)
            .expect("retry with generous cap must apply");
        assert_eq!(good_writer.writes, 1);
        assert_eq!(ledger_after.tokens_used, 25, "single debit, not double");
        assert_eq!(ledger_after.tool_calls_used, 1, "single debit, not double");
        // Pre-call ledger remained zero.
        assert_eq!(ledger_before, BudgetLedger::default());
    }

    #[test]
    fn sealer_budget_rejection_attributes_term_to_tool_calls_axis() {
        // Phase 1 hardening — error attribution. The existing
        // over-budget test only confirms SealError::Budget(_) shape;
        // this pins that when the tool_calls axis is the one that
        // trips, the inner BudgetError::Exhausted carries
        // term: BudgetTerm::ToolCalls (not Tokens or another axis).
        // Audit dashboards rely on this attribution to identify
        // which budget axis the offending capability exhausted.
        let cap = valid_capability(Some(10_000));
        // Generous token cap but a tool_calls cap of 2.
        let sealer = Sealer {
            capability: &cap,
            gate: BudgetGate::new(BudgetSpec::new(100_000, 0, 2, 0)),
        };
        // Initial ledger already at the 2-tool-call cap.
        let starting_ledger = BudgetLedger {
            tool_calls_used: 2,
            ..Default::default()
        };
        let envelope = MutationEnvelope::new(
            cap.macaroon().capability_hash(),
            BudgetDebit { tokens: 5, tool_calls: 1, ..Default::default() },
            "tool-overflow".to_string(),
        );
        let mut writer = RecordingWriter::new();
        let err = sealer
            .seal_and_apply(&ctx(), starting_ledger, envelope, &mut writer)
            .expect_err("must trip tool_calls cap");
        match err {
            SealError::Budget(BudgetError::Exhausted { term, .. }) => {
                assert_eq!(
                    term,
                    BudgetTerm::ToolCalls,
                    "expected ToolCalls attribution, got {term:?}",
                );
            }
            other => panic!("expected Budget(Exhausted), got {other:?}"),
        }
        assert_eq!(writer.writes, 0);
    }

    #[test]
    fn over_budget_mutation_does_not_write() {
        // Budget rejection is the second gate; it must also short-circuit
        // BEFORE the writer is touched.
        let cap = valid_capability(Some(10_000));
        let sealer = Sealer {
            capability: &cap,
            gate: BudgetGate::new(BudgetSpec::new(100, 0, 0, 0)),
        };
        let envelope = MutationEnvelope::new(
            cap.macaroon().capability_hash(),
            BudgetDebit { tokens: 500, ..Default::default() },
            "payload".to_string(),
        );
        let mut writer = RecordingWriter::new();
        let err = sealer
            .seal_and_apply(&ctx(), BudgetLedger::default(), envelope, &mut writer)
            .expect_err("over-budget mutation must not be applied");
        assert!(matches!(err, SealError::Budget(_)), "got {err:?}");
        assert_eq!(writer.writes, 0);
    }

    #[test]
    fn sealer_advanced_ledger_equals_budget_gate_direct_call_on_same_inputs() {
        // Phase 1 hardening — cross-helper consistency pin.
        // Sealer::seal_and_apply (when both gates clear) returns the
        // advanced ledger produced by BudgetGate::check_and_debit.
        // The two paths must produce byte-equal ledgers for the same
        // (ledger, debit) inputs — the Sealer doesn't add or remove
        // any axis adjustments beyond the canonical gate path.
        //
        // A future "let me bill an overhead axis on Sealer write"
        // refactor would silently diverge the sealer-advanced ledger
        // from the bare-gate ledger.
        let cap = valid_capability(Some(10_000));
        let spec = BudgetSpec::new(10_000, 60_000, 100, 30_000).with_memory_bytes(1_000_000);
        let gate = BudgetGate::new(spec);
        let sealer = Sealer { capability: &cap, gate };
        let envelope = MutationEnvelope::new(
            cap.macaroon().capability_hash(),
            BudgetDebit {
                tokens: 111,
                wall_ms: 222,
                tool_calls: 3,
                subprocess_ms: 444,
                memory_bytes: 555,
            },
            "payload".to_string(),
        );
        let starting_ledger = BudgetLedger {
            tokens_used: 50,
            wall_used_ms: 100,
            ..Default::default()
        };

        // Direct call.
        let direct = gate
            .check_and_debit(starting_ledger, envelope.debit)
            .expect("direct gate accepts");
        // Sealer path.
        let mut writer = RecordingWriter::new();
        let (via_sealer, _receipt) = sealer
            .seal_and_apply(&ctx(), starting_ledger, envelope, &mut writer)
            .expect("sealer accepts");

        // The two ledgers must be byte-equal across all 5 axes.
        assert_eq!(direct, via_sealer);
    }

    #[test]
    fn approved_mutation_applies_and_advances_ledger() {
        let cap = valid_capability(Some(10_000));
        let sealer = Sealer {
            capability: &cap,
            gate: BudgetGate::new(BudgetSpec::new(1_000, 0, 5, 0)),
        };
        let envelope = MutationEnvelope::new(
            cap.macaroon().capability_hash(),
            BudgetDebit { tokens: 25, tool_calls: 1, ..Default::default() },
            "hello world".to_string(),
        );
        let mut writer = RecordingWriter::new();
        let (ledger, receipt) = sealer
            .seal_and_apply(&ctx(), BudgetLedger::default(), envelope, &mut writer)
            .expect("approved mutation must apply");
        assert_eq!(writer.writes, 1);
        assert_eq!(receipt, "hello world".len() as u64);
        assert_eq!(ledger.tokens_used, 25);
        assert_eq!(ledger.tool_calls_used, 1);
    }

    #[test]
    fn sealer_apply_then_append_sealed_mutation_matches_envelope_field_for_field() {
        // Phase 1 hardening MILESTONE iter-350 — §4 T11 acceptance
        // chain integration pin. Exercises the dispatcher's canonical
        // post-Sealer flow:
        //
        //   Sealer::seal_and_apply(...) succeeds
        //       → caller calls RunEventLog::append_sealed_mutation(
        //             envelope.capability_hash, envelope.debit)
        //       → SealedMutation row in the log matches the envelope
        //         field-for-field
        //       → root_hash captures the row (downstream replay can
        //         verify the chain end-to-end)
        //
        // The existing approved_mutation_applies_and_advances_ledger
        // pin only proves the LEDGER side of Sealer success. The
        // existing canonical_flow_end_to_end_pin_with_full_field_coverage
        // (iter-250) exercises a full chain but builds the
        // SealedMutation row by HAND, not from a real Sealer success.
        //
        // This pin bridges the two: actually run Sealer::seal_and_apply,
        // then append_sealed_mutation FROM the envelope, then verify
        // the stored row equals (envelope.capability_hash, envelope.debit)
        // byte-for-byte. Defends against a future refactor that changed
        // append_sealed_mutation's parameter order or silently dropped
        // a debit axis on store.
        let cap = valid_capability(Some(10_000));
        let sealer = Sealer {
            capability: &cap,
            gate: BudgetGate::new(
                BudgetSpec::new(1_000, 10_000, 5, 30_000).with_memory_bytes(1_048_576),
            ),
        };
        let envelope = MutationEnvelope::new(
            cap.macaroon().capability_hash(),
            BudgetDebit {
                tokens: 33,
                wall_ms: 222,
                tool_calls: 1,
                subprocess_ms: 444,
                memory_bytes: 8_192,
            },
            "milestone-payload".to_string(),
        );
        let mut writer = RecordingWriter::new();

        // Sealer success.
        let pre_envelope_cap = envelope.capability_hash;
        let pre_envelope_debit = envelope.debit;
        let (ledger, _receipt) = sealer
            .seal_and_apply(&ctx(), BudgetLedger::default(), envelope, &mut writer)
            .expect("approved mutation must apply");
        assert_eq!(writer.writes, 1);

        // Append SealedMutation row using the (pre-clone) envelope fields.
        use crate::agent_runtime_v2::run_event_log::{RunEventEntry, RunEventLog};
        let mut log = RunEventLog::new();
        let returned_ord = log.append_sealed_mutation(pre_envelope_cap, pre_envelope_debit);
        assert_eq!(returned_ord, 0, "first sealed row gets ordinal 0");
        let (events, sealed, snapshots) = log.entry_count_by_kind();
        assert_eq!((events, sealed, snapshots), (0, 1, 0));

        // Inspect the stored row: must equal (envelope.capability_hash,
        // envelope.debit) byte-for-byte.
        {
            let stored_entry = &log.entries()[0];
            match stored_entry {
                RunEventEntry::SealedMutation {
                    ordinal,
                    capability_hash,
                    debit,
                } => {
                    assert_eq!(*ordinal, 0);
                    assert_eq!(*capability_hash, pre_envelope_cap, "cap_hash must round-trip");
                    assert_eq!(*debit, pre_envelope_debit, "5-axis debit must round-trip");
                }
                other => panic!("expected SealedMutation row, got {other:?}"),
            }
        }

        // sealed_mutations() iterator surfaces exactly one (ordinal, cap, debit) tuple.
        {
            let mut iter = log.sealed_mutations();
            let (o, c, d) = iter.next().expect("one sealed row");
            assert_eq!(o, 0);
            assert_eq!(*c, pre_envelope_cap);
            assert_eq!(*d, pre_envelope_debit);
            assert!(iter.next().is_none());
        }

        // Append ledger snapshot post-mutation, then emit packet.
        use crate::agent_runtime_v2::event::AgentEvent;
        use crate::agent_runtime_v2::para::StopReason as PStopReason;
        log.append_ledger_snapshot(ledger);
        log.append_event(AgentEvent::Stop { reason: PStopReason::EndTurn });

        let root = log.root_hash();
        let packet = crate::agent_runtime_v2::answer::AnswerPacket::emit(
            crate::agent_runtime_v2::AgentBlueprintId("milestone-iter-350".into()),
            String::new(),
            vec![],
            PStopReason::EndTurn,
            ledger,
            &log,
        );
        // root_hash captures the SealedMutation row + snapshot + stop event.
        assert_eq!(packet.run_event_log_root, root);
        assert_eq!(packet.final_ledger, ledger);
    }

    #[test]
    fn sealer_success_advances_ledger_field_for_field_across_all_five_axes() {
        // Phase 1 hardening — Sealer ledger-advance must apply the
        // FULL 5-axis debit, not just the headline (tokens / tool_calls)
        // pair already covered. A regression that forgot to copy
        // wall_ms / subprocess_ms / memory_bytes through the gate
        // would silently leak budget for those axes — the existing
        // success test wouldn't catch it.
        let cap = valid_capability(Some(10_000));
        // Spec must accept the full 5-axis debit; cap each axis
        // generously.
        let sealer = Sealer {
            capability: &cap,
            gate: BudgetGate::new(
                BudgetSpec::new(10_000, 60_000, 100, 30_000).with_memory_bytes(1_000_000),
            ),
        };
        let envelope = MutationEnvelope::new(
            cap.macaroon().capability_hash(),
            BudgetDebit {
                tokens: 111,
                wall_ms: 222,
                tool_calls: 3,
                subprocess_ms: 444,
                memory_bytes: 555,
            },
            "5-axis payload".to_string(),
        );
        let mut writer = RecordingWriter::new();
        let (ledger, _receipt) = sealer
            .seal_and_apply(&ctx(), BudgetLedger::default(), envelope, &mut writer)
            .expect("approved 5-axis mutation must apply");
        assert_eq!(ledger.tokens_used, 111);
        assert_eq!(ledger.wall_used_ms, 222);
        assert_eq!(ledger.tool_calls_used, 3);
        assert_eq!(ledger.subprocess_used_ms, 444);
        assert_eq!(ledger.memory_bytes_used, 555);
        assert_eq!(writer.writes, 1);
    }

    #[test]
    fn sealer_does_not_dedupe_idempotency_is_writer_responsibility() {
        // Phase 1 hardening — boundary documentation: the Sealer
        // gates capability + budget + writes via the writer. It does
        // NOT dedupe envelopes. Applying the same envelope twice
        // results in TWO writer.write calls + TWO budget debits.
        // Idempotency, when needed, is the writer's responsibility
        // (e.g. via an envelope_id + seen-set inside the writer).
        // This test pins the boundary so a future change must own
        // up to who carries the dedupe burden.
        let cap = valid_capability(Some(10_000));
        let sealer = Sealer {
            capability: &cap,
            gate: BudgetGate::new(BudgetSpec::new(1_000, 0, 5, 0)),
        };
        let envelope = MutationEnvelope::new(
            cap.macaroon().capability_hash(),
            BudgetDebit { tokens: 25, tool_calls: 1, ..Default::default() },
            "idempotency-payload".to_string(),
        );
        let mut writer = RecordingWriter::new();
        let mut ledger = BudgetLedger::default();
        let (after_first, _) = sealer
            .seal_and_apply(&ctx(), ledger, envelope.clone(), &mut writer)
            .expect("first apply");
        ledger = after_first;
        let (after_second, _) = sealer
            .seal_and_apply(&ctx(), ledger, envelope, &mut writer)
            .expect("second apply (no dedupe in Sealer)");
        ledger = after_second;
        assert_eq!(writer.writes, 2, "Sealer must invoke writer twice");
        assert_eq!(ledger.tokens_used, 50);
        assert_eq!(ledger.tool_calls_used, 2);
    }

    #[test]
    fn envelope_log_summary_is_idempotent_across_multiple_calls() {
        // Phase 1 hardening — pure-function pin (companion to
        // iter-217 sealed_mutations / iter-218 find_capability_hash /
        // iter-168 digest_intact idempotency pins). log_summary
        // takes &self and must be side-effect-free; calling it
        // many times must yield identical strings.
        //
        // A future "let me memoise on first call" refactor with
        // interior mutability would break the &self contract.
        let envelope = MutationEnvelope::new(
            Hash::from_bytes([0xCD; 32]),
            BudgetDebit { tokens: 42, tool_calls: 7, ..Default::default() },
            "payload".to_string(),
        );
        let first = envelope.log_summary();
        let second = envelope.log_summary();
        let third = envelope.log_summary();
        assert_eq!(first, second);
        assert_eq!(second, third);
        // Also: payload itself wasn't disturbed.
        assert_eq!(envelope.payload, "payload");
    }

    #[test]
    fn envelope_log_summary_hex_prefix_reflects_first_4_bytes_of_capability_hash() {
        // Phase 1 hardening — boundary pin. log_summary uses
        // hex.to_hex()[..8] (8 hex chars = first 4 bytes). The
        // existing tests use 0xAB repeated and 0 — pin specific
        // first-4-byte patterns to prove the hex prefix actually
        // reflects the leading bytes, not some hash of the hash.
        for (bytes, expected_prefix) in [
            ([0x01u8; 32], "01010101"),
            ([0xDEu8; 32], "dededede"),
            ([0xFFu8; 32], "ffffffff"),
        ] {
            let envelope = MutationEnvelope::new(
                Hash::from_bytes(bytes),
                BudgetDebit { tokens: 1, tool_calls: 0, ..Default::default() },
                "p".to_string(),
            );
            let s = envelope.log_summary();
            assert!(
                s.contains(&format!("cap={expected_prefix}")),
                "expected cap={expected_prefix} in {s}"
            );
        }
    }

    #[test]
    fn envelope_log_summary_hex_prefix_is_lowercase_per_canonical_hex_doctrine() {
        // Phase 1 hardening — case-sensitivity pin. log_summary uses
        // capability_hash.to_hex(), which calls hex_lower() (cognitive_dag/
        // node.rs §30-32) — so the cap=<8hex> prefix MUST be lowercase
        // hexadecimal (e.g., "ab12cd34", never "AB12CD34").
        //
        // The existing envelope_log_summary_wrapper_shape_is_parseable_for_audit_tools
        // pin only asserts is_ascii_hexdigit() — which would still pass
        // if a future refactor swapped to_hex() to to_hex_upper(). Audit
        // tools that grep for /cap=[a-f0-9]{8}/ would silently miss
        // hits if the hex flipped to upper.
        //
        // Defends against a future "let me uppercase the hex for
        // visual scanning" refactor that would silently break
        // lowercase regex audit pipelines.
        let envelope = MutationEnvelope::new(
            Hash::from_bytes([0xAB; 32]),
            BudgetDebit::default(),
            "payload".to_string(),
        );
        let summary = envelope.log_summary();
        // Extract the cap=<hex8> portion.
        let inside = summary
            .strip_prefix("envelope{cap=")
            .expect("starts with envelope{cap=");
        let cap_hex: String = inside.chars().take(8).collect();
        assert_eq!(cap_hex.len(), 8);
        // Lowercase invariant: must equal its own to_ascii_lowercase form.
        assert_eq!(
            cap_hex,
            cap_hex.to_ascii_lowercase(),
            "cap hex must be lowercase, got {cap_hex}"
        );
        // The 0xAB byte serialises as "ab" specifically.
        assert_eq!(cap_hex, "abababab");
    }

    #[test]
    fn envelope_log_summary_tokens_and_tool_calls_reflect_debit_values() {
        // Phase 1 hardening — log_summary semantic pin (companion to
        // the Display semantic-pin family iter-488..iter-491).
        //
        // MutationEnvelope::log_summary format includes:
        //   "envelope{{cap=<8hex>, tokens={}, tool_calls={}}}"
        // (envelope.rs §86) where tokens and tool_calls track
        // self.debit.tokens and self.debit.tool_calls respectively.
        //
        // Pin that the rendered values match the underlying debit
        // fields across representative inputs. A future "let me
        // also include wall_ms in the summary" refactor would
        // shuffle the field order; pin via value-content matching
        // (separately from the shape pins).
        let cases = [
            (0u64, 0u64),
            (1, 1),
            (1_000, 5),
            (999_999, 100),
            (u64::MAX, u64::MAX),
        ];
        for (tokens, tool_calls) in cases {
            let envelope = MutationEnvelope::new(
                Hash::zero(),
                BudgetDebit { tokens, tool_calls, ..Default::default() },
                "payload".to_string(),
            );
            let summary = envelope.log_summary();
            assert!(
                summary.contains(&format!("tokens={tokens}")),
                "log_summary must show tokens={tokens}, got: {summary}"
            );
            assert!(
                summary.contains(&format!("tool_calls={tool_calls}")),
                "log_summary must show tool_calls={tool_calls}, got: {summary}"
            );
        }
    }

    #[test]
    fn envelope_log_summary_field_order_is_cap_tokens_tool_calls() {
        // Phase 1 hardening — log_summary field-ORDER pin (companion to
        // answer_packet_display_field_order iter-494 +
        // mission_packet_display_field_order iter-495).
        //
        // log_summary format (envelope.rs §86):
        //   "envelope{{cap={}, tokens={}, tool_calls={}}}"
        //
        // The 3 fields appear in EXACTLY this order:
        //   1. cap (hex-prefix)
        //   2. tokens
        //   3. tool_calls
        //
        // A future reorder would silently shuffle the audit-log
        // layout — surface here via find-position comparison.
        let envelope = MutationEnvelope::new(
            Hash::from_bytes([0xAB; 32]),
            BudgetDebit { tokens: 42, tool_calls: 7, ..Default::default() },
            "payload".to_string(),
        );
        let summary = envelope.log_summary();
        let cap_pos = summary.find("cap=").expect("cap field");
        let tokens_pos = summary.find("tokens=").expect("tokens field");
        let tool_calls_pos = summary.find("tool_calls=").expect("tool_calls field");
        assert!(cap_pos < tokens_pos, "cap must precede tokens");
        assert!(tokens_pos < tool_calls_pos, "tokens must precede tool_calls");
    }

    #[test]
    fn envelope_log_summary_starts_with_literal_envelope_brace_prefix() {
        // Phase 1 hardening — wire-shape pin (companion to
        // answer_packet_display_starts_with_literal_struct_name_prefix
        // iter-451 + mission_packet_display_starts_with_literal_struct_name_prefix
        // iter-452). MutationEnvelope::log_summary format string is
        //   "envelope{{cap={}, tokens={}, tool_calls={}}}"
        // (envelope.rs §86). The literal "envelope{" prefix is
        // load-bearing for grep-based audit pipelines that filter
        // payload-redacted envelope log lines.
        //
        // A future "let me use 'mut{...}' as a shorthand for mutation"
        // refactor would silently break the grep contract.
        let envelope = MutationEnvelope::new(
            Hash::from_bytes([0xAB; 32]),
            BudgetDebit { tokens: 42, tool_calls: 7, ..Default::default() },
            "payload".to_string(),
        );
        let summary = envelope.log_summary();
        assert!(summary.starts_with("envelope{"),
            "log_summary must start with literal 'envelope{{', got: {summary}");
        assert!(summary.ends_with('}'),
            "log_summary must end with literal '}}', got: {summary}");
    }

    #[test]
    fn envelope_log_summary_wrapper_shape_is_parseable_for_audit_tools() {
        // Phase 1 hardening — pin the exact wrapper format so log
        // parsers / audit dashboards that scrape this line can rely
        // on the shape. Format: "envelope{cap=<8hex>, tokens=N, tool_calls=N}".
        // The opening "envelope{" + closing "}" + three comma-
        // separated key=value pairs are the load-bearing surface.
        let envelope = MutationEnvelope::new(
            Hash::from_bytes([0xAB; 32]),
            BudgetDebit { tokens: 42, tool_calls: 7, ..Default::default() },
            "payload".to_string(),
        );
        let summary = envelope.log_summary();
        assert!(summary.starts_with("envelope{"), "must start with envelope{{: {summary}");
        assert!(summary.ends_with('}'), "must end with }}: {summary}");
        // Three comma-separated fields between the braces (cap,
        // tokens, tool_calls).
        let inside = summary
            .strip_prefix("envelope{")
            .and_then(|s| s.strip_suffix('}'))
            .expect("wrapper braces");
        let fields: Vec<&str> = inside.split(", ").collect();
        assert_eq!(fields.len(), 3, "expected 3 fields, got {fields:?}");
        assert!(fields[0].starts_with("cap="));
        assert!(fields[1].starts_with("tokens="));
        assert!(fields[2].starts_with("tool_calls="));
        // Specific field values.
        assert_eq!(fields[1], "tokens=42");
        assert_eq!(fields[2], "tool_calls=7");
        // cap hex prefix is exactly 8 chars.
        let cap_hex = fields[0].strip_prefix("cap=").expect("cap=");
        assert_eq!(cap_hex.len(), 8, "cap hex prefix should be 8 chars");
        assert!(cap_hex.chars().all(|c| c.is_ascii_hexdigit()));
    }

    #[test]
    fn envelope_log_summary_surfaces_only_tokens_and_tool_calls_omits_other_3_axes() {
        // Phase 1 hardening — doctrine pin (companion to iter-212
        // AnswerPacket Display tokens-only pin).
        // MutationEnvelope::log_summary intentionally surfaces ONLY
        // tokens and tool_calls from the 5-axis BudgetDebit; the
        // other 3 axes (wall_ms, subprocess_ms, memory_bytes) are
        // omitted from the audit-log shorthand to keep it short.
        //
        // A future maintainer who added wall_ms or memory_bytes to
        // log_summary would silently inflate every secrets-hygiene
        // log line. Pin the headline-pair-only doctrine.
        let envelope = MutationEnvelope::new(
            Hash::from_bytes([0xAB; 32]),
            BudgetDebit {
                tokens: 42,
                wall_ms: 9_999,
                tool_calls: 7,
                subprocess_ms: 12_345,
                memory_bytes: 1_000_000,
            },
            "payload".to_string(),
        );
        let summary = envelope.log_summary();
        // tokens + tool_calls headlines are present.
        assert!(summary.contains("tokens=42"));
        assert!(summary.contains("tool_calls=7"));
        // The 3 omitted axes' values are NOT in the summary.
        assert!(!summary.contains("9999"), "wall_ms must not appear in {summary}");
        assert!(!summary.contains("12345"), "subprocess_ms must not appear in {summary}");
        assert!(!summary.contains("1000000"), "memory_bytes must not appear in {summary}");
        // Exact shape preserved.
        assert_eq!(
            summary,
            "envelope{cap=abababab, tokens=42, tool_calls=7}"
        );
    }

    #[test]
    fn envelope_log_summary_handles_zero_capability_hash_edge_case() {
        // Phase 1 hardening — defensive boundary. capability_hash
        // can be Hash::zero() in synthetic / test contexts (forged
        // or uninitialised envelope). log_summary must not panic
        // on the zero hash and must produce a recognisable
        // "all zeros" hex prefix a reader can spot.
        let envelope = MutationEnvelope::new(
            Hash::zero(),
            BudgetDebit { tokens: 0, tool_calls: 0, ..Default::default() },
            "payload".to_string(),
        );
        let summary = envelope.log_summary();
        assert!(
            summary.contains("cap=00000000"),
            "zero hash must produce cap=00000000 prefix; got {summary}"
        );
        assert!(summary.contains("tokens=0"));
        assert!(summary.contains("tool_calls=0"));
    }

    #[test]
    fn envelope_log_summary_never_prints_payload() {
        // Phase 1 hardening — secrets-hygiene surface. log_summary
        // must NOT include the payload string, the full hash, or
        // any byte that could leak sensitive content.
        let cap = valid_capability(None);
        let envelope = MutationEnvelope::new(
            cap.macaroon().capability_hash(),
            BudgetDebit { tokens: 100, tool_calls: 3, ..Default::default() },
            "TOP_SECRET_PAYLOAD_DO_NOT_LEAK".to_string(),
        );
        let summary = envelope.log_summary();
        assert!(
            !summary.contains("TOP_SECRET"),
            "payload must NOT appear in log_summary: {summary}"
        );
        assert!(summary.contains("tokens=100"));
        assert!(summary.contains("tool_calls=3"));
        assert!(summary.starts_with("envelope{cap="));
        // 8-char hex prefix only — full hash is 64 chars; assert
        // we're not leaking the full thing.
        let full_hex = envelope.capability_hash.to_hex();
        assert!(full_hex.len() > 8);
        assert!(
            !summary.contains(&full_hex),
            "full hash must NOT appear in log_summary"
        );
    }

    #[test]
    fn sealer_error_attribution_capability_wins_over_write() {
        // Phase 1 hardening — completes the 3-gate priority chain
        // (Capability ≻ Budget ≻ Write). The existing
        // capability_wins_over_budget pin and iter-242's
        // budget_wins_over_write pin handle adjacent pairs; this
        // pins the transitive case where capability beats writer
        // directly (skipping budget).
        let key = [13u8; 32];
        let m = issue(
            "transitive-attribution",
            CapabilityKind::ToolInvoke("vault.write".into()),
            CapabilityScope("vault".into()),
            None,
            &key,
        );
        // Wrong-key capability (Forged rejection).
        let mut wrong_key = key;
        wrong_key[0] ^= 0xFF;
        let cap = MacaroonCapability::new(m, wrong_key);
        // Generous budget — would NOT trip.
        let sealer = Sealer {
            capability: &cap,
            gate: BudgetGate::new(BudgetSpec::new(10_000, 0, 100, 0)),
        };
        let envelope = MutationEnvelope::new(
            cap.macaroon().capability_hash(),
            BudgetDebit { tokens: 10, ..Default::default() },
            "under-cap".to_string(),
        );
        // Always-failing writer — would trip if reached.
        struct AlwaysFailWriter {
            calls: usize,
        }
        #[derive(Debug, Clone, PartialEq, Eq)]
        struct LocalErr;
        impl MutationWriter<String> for AlwaysFailWriter {
            type Receipt = ();
            type WriteError = LocalErr;
            fn write(&mut self, _payload: &String) -> Result<(), LocalErr> {
                self.calls += 1;
                Err(LocalErr)
            }
        }
        let mut writer = AlwaysFailWriter { calls: 0 };
        let err = sealer
            .seal_and_apply(&ctx(), BudgetLedger::default(), envelope, &mut writer)
            .expect_err("capability fails first");
        assert!(matches!(err, SealError::Capability(_)));
        // Writer never reached.
        assert_eq!(writer.calls, 0);
    }

    #[test]
    fn sealer_error_attribution_budget_wins_over_write() {
        // Phase 1 hardening — error-attribution chain pin
        // (companion to sealer_error_attribution_capability_wins_over_budget).
        // When BOTH the budget gate AND the writer would reject the
        // envelope, the Sealer surfaces SealError::Budget first
        // because budget.check_and_debit is sequenced BEFORE
        // writer.write.
        //
        // This pins the gate ordering: capability → budget → writer.
        // Flipping the order would silently change which error
        // dashboards see when both apply.
        let cap = valid_capability(Some(10_000));
        let sealer = Sealer {
            capability: &cap,
            gate: BudgetGate::new(BudgetSpec::new(10, 0, 0, 0)),
        };
        let envelope = MutationEnvelope::new(
            cap.macaroon().capability_hash(),
            BudgetDebit { tokens: 100, ..Default::default() }, // > 10 cap
            "would-fail-via-budget".to_string(),
        );
        // Use an always-failing writer; budget rejects first, so the
        // writer is NEVER invoked.
        struct AlwaysFailWriter;
        #[derive(Debug, Clone, PartialEq, Eq)]
        struct LocalErr;
        impl MutationWriter<String> for AlwaysFailWriter {
            type Receipt = ();
            type WriteError = LocalErr;
            fn write(&mut self, _payload: &String) -> Result<(), LocalErr> {
                Err(LocalErr)
            }
        }
        let mut writer = AlwaysFailWriter;
        let err = sealer
            .seal_and_apply(&ctx(), BudgetLedger::default(), envelope, &mut writer)
            .expect_err("both budget and write would reject");
        // Budget runs first → Budget variant wins.
        assert!(
            matches!(err, SealError::Budget(_)),
            "expected Budget(_) (sequenced before writer), got {err:?}"
        );
    }

    #[test]
    fn sealer_error_attribution_capability_wins_over_budget() {
        // Phase 1 hardening — error attribution ordering: when
        // BOTH the capability gate AND the budget gate would
        // independently reject the envelope, the Sealer surfaces
        // SealError::Capability first because capability.verify is
        // sequenced before budget check. This test pins the
        // ordering; flipping it would silently change which error
        // dashboards see when both apply.
        use crate::cognitive_dag::macaroons::issue;

        // Wrong-key capability (always denies via Forged).
        let key = [13u8; 32];
        let m = issue(
            "attribution-session",
            CapabilityKind::ToolInvoke("vault.write".into()),
            CapabilityScope("vault".into()),
            None,
            &key,
        );
        let mut wrong_key = key;
        wrong_key[0] ^= 0xFF;
        let cap = MacaroonCapability::new(m, wrong_key);

        // Budget cap that would also reject (debit exceeds cap).
        let sealer = Sealer {
            capability: &cap,
            gate: BudgetGate::new(BudgetSpec::new(10, 0, 0, 0)),
        };
        let envelope = MutationEnvelope::new(
            cap.macaroon().capability_hash(),
            BudgetDebit { tokens: 100, ..Default::default() }, // 100 > 10 cap
            "double-denied".to_string(),
        );
        let mut writer = RecordingWriter::new();
        let err = sealer
            .seal_and_apply(&ctx(), BudgetLedger::default(), envelope, &mut writer)
            .expect_err("both gates would reject");
        // Capability check runs first → Capability variant wins.
        assert!(
            matches!(err, SealError::Capability(_)),
            "expected Capability(_) (sequenced first), got {err:?}"
        );
        assert_eq!(writer.writes, 0);
    }

    #[test]
    fn seal_error_budget_variant_distinguishes_all_five_inner_term_axes() {
        // Phase 1 hardening — inner-term distinctness pin for
        // SealError::Budget (companion to iter-194's
        // SealError::Capability inner-variant distinctness).
        // BudgetError::Exhausted carries a BudgetTerm enum naming
        // which axis tripped: Tokens, WallMs, ToolCalls, SubprocessMs,
        // MemoryBytes. Each axis surfaces a different audit-dashboard
        // category — collapsing them via PartialEq would lose
        // attribution.
        use crate::agent_runtime_v2::BudgetTerm;
        let mk = |term: BudgetTerm| -> SealError<std::convert::Infallible> {
            SealError::Budget(BudgetError::Exhausted {
                term,
                attempted_total: 1,
                cap: 0,
            })
        };
        let variants = [
            mk(BudgetTerm::Tokens),
            mk(BudgetTerm::WallMs),
            mk(BudgetTerm::ToolCalls),
            mk(BudgetTerm::SubprocessMs),
            mk(BudgetTerm::MemoryBytes),
        ];
        assert_eq!(variants.len(), 5);
        for i in 0..variants.len() {
            for j in (i + 1)..variants.len() {
                assert_ne!(
                    variants[i], variants[j],
                    "Budget inner term {i} and {j} must be distinct"
                );
            }
        }
    }

    #[test]
    fn seal_error_capability_variant_distinguishes_forged_vs_violated_inner_kind() {
        // Phase 1 hardening — inner-variant distinctness pin for
        // SealError::Capability. The wrapping variant is the same
        // (Capability), but the INNER CapabilityError carries
        // either Forged(VerifyError) or Violated(CaveatViolation).
        // These two cases surface DIFFERENT incident-response paths:
        //   - Forged: cryptographic-grade rejection, no recovery
        //   - Violated: recoverable in principle (issue a new token)
        //
        // PartialEq on SealError must distinguish them. The
        // seal_error_variant_count_is_three test only proves the
        // outer 3 variants are distinct; this pins inner-distinctness
        // for the Capability variant specifically.
        let forged: SealError<std::convert::Infallible> =
            SealError::Capability(CapabilityError::Forged(VerifyError::SignatureMismatch));
        use crate::cognitive_dag::macaroons::CaveatViolation;
        let violated: SealError<std::convert::Infallible> =
            SealError::Capability(CapabilityError::Violated(CaveatViolation::Expired {
                until_ts_ms: 100,
                now_ms: 200,
            }));
        assert_ne!(forged, violated, "Forged and Violated inner variants must be distinct");
    }

    #[test]
    fn seal_error_variants_field_shapes_pinned_via_destructure() {
        // Phase 1 hardening MILESTONE iter-460 — field-shape pin for
        // SealError<W>'s 3 tuple variants (companion to the destructure
        // pin family iter-454..iter-459).
        //
        // Variants:
        //   - Capability(CapabilityError) — tuple, 1 field
        //   - Budget(BudgetError) — tuple, 1 field
        //   - Write(W) — tuple, 1 field of generic W
        //
        // The 3-variant shape is load-bearing — extending to 4 variants
        // would require updating Sealer::seal_and_apply's match arms
        // + the error attribution chain. Pin via destructure compile-fail.
        use crate::cognitive_dag::macaroons::VerifyError;
        let cap_err: SealError<std::convert::Infallible> =
            SealError::Capability(CapabilityError::Forged(VerifyError::SignatureMismatch));
        match cap_err {
            SealError::Capability(inner) => {
                let _: CapabilityError = inner;
            }
            _ => unreachable!(),
        }
        let bud_err: SealError<std::convert::Infallible> =
            SealError::Budget(BudgetError::Exhausted {
                term: BudgetTerm::Tokens,
                attempted_total: 100,
                cap: 50,
            });
        match bud_err {
            SealError::Budget(inner) => {
                let _: BudgetError = inner;
            }
            _ => unreachable!(),
        }
        #[derive(Debug, Clone, PartialEq, Eq)]
        struct LocalErr;
        let write_err: SealError<LocalErr> = SealError::Write(LocalErr);
        match write_err {
            SealError::Write(inner) => {
                let _: LocalErr = inner;
            }
            _ => unreachable!(),
        }
    }

    #[test]
    fn seal_error_variant_count_is_three() {
        // Phase 1 hardening — cardinality pin. SealError<W> has 3
        // variants (Capability, Budget, Write). Each surfaces a
        // different gate's rejection in Sealer::seal_and_apply:
        //   - Capability: macaroon verify failed
        //   - Budget: BudgetGate exhausted
        //   - Write: writer's own error surface after both gates clear
        //
        // A future addition (e.g., SealError::PolicyDenied for a new
        // gate between capability and budget) requires updates across:
        //   - Sealer::seal_and_apply branch
        //   - Debug-repr pin update
        //   - error attribution test update (iter for sealer_error_attribution_capability_wins_over_budget)
        // Pin cardinality + pairwise distinctness so the addition
        // surfaces at PR review.
        #[derive(Debug, Clone, PartialEq, Eq)]
        struct LocalErr;
        let variants: [SealError<LocalErr>; 3] = [
            SealError::Capability(CapabilityError::Forged(VerifyError::SignatureMismatch)),
            SealError::Budget(BudgetError::Exhausted {
                term: crate::agent_runtime_v2::BudgetTerm::Tokens,
                attempted_total: 1,
                cap: 0,
            }),
            SealError::Write(LocalErr),
        ];
        assert_eq!(variants.len(), 3);
        for i in 0..variants.len() {
            for j in (i + 1)..variants.len() {
                assert_ne!(
                    variants[i], variants[j],
                    "errors[{i}] and errors[{j}] must be distinct"
                );
            }
        }
    }

    #[test]
    fn seal_error_debug_repr_is_stable_for_log_persistence() {
        // Phase 1 hardening — Debug repr is what audit dashboards
        // print for SealError variants. A maintainer rename would
        // silently change the printed form and break log greps. Pin
        // the leading discriminant for each variant.
        let cap_err = SealError::Capability::<std::convert::Infallible>(
            CapabilityError::Forged(VerifyError::SignatureMismatch),
        );
        let dbg = format!("{cap_err:?}");
        assert!(dbg.starts_with("Capability("), "got {dbg}");
        let bud_err = SealError::Budget::<std::convert::Infallible>(BudgetError::Exhausted {
            term: crate::agent_runtime_v2::BudgetTerm::Tokens,
            attempted_total: 1,
            cap: 0,
        });
        let dbg = format!("{bud_err:?}");
        assert!(dbg.starts_with("Budget("), "got {dbg}");
        // Write variant requires a concrete error type; use the
        // DiskFull fixture from the fixtures module via a local stub.
        #[derive(Debug, Clone, PartialEq, Eq)]
        struct LocalErr;
        let write_err: SealError<LocalErr> = SealError::Write(LocalErr);
        let dbg = format!("{write_err:?}");
        assert!(dbg.starts_with("Write("), "got {dbg}");
    }

    #[test]
    fn mutation_envelope_fields_are_pub_per_field_visibility_doctrine() {
        // Phase 1 hardening MILESTONE iter-510 — field-visibility pin
        // for MutationEnvelope<P>. Closes the field-visibility pin
        // family across user-facing structs (ParaFeedback iter-505,
        // ParaOutput iter-506, AnswerPacket iter-507, AgentBlueprint
        // iter-508, MissionPacket+ToolCall iter-509).
        //
        // MutationEnvelope<P>: 3 pub fields
        //   - capability_hash: Hash
        //   - debit: BudgetDebit
        //   - payload: P
        //
        // A future "let me hide capability_hash behind a getter for
        // tamper safety" refactor would silently break SealedMutation
        // row appending which reads envelope.capability_hash directly.
        let envelope = MutationEnvelope::new(
            Hash::from_bytes([0x42; 32]),
            BudgetDebit { tokens: 100, ..Default::default() },
            "payload".to_string(),
        );
        assert_eq!(envelope.capability_hash, Hash::from_bytes([0x42; 32]));
        assert_eq!(envelope.debit.tokens, 100);
        assert_eq!(envelope.payload, "payload");
    }

    #[test]
    fn mutation_envelope_struct_field_shape_pinned_via_destructure() {
        // Phase 1 hardening — struct-field-shape pin for
        // MutationEnvelope<P> (companion to AnswerPacket iter-464,
        // AgentBlueprint iter-465, MissionPacket + ToolCall iter-466).
        //
        // MutationEnvelope<P>: EXACTLY 3 fields
        //   - capability_hash: Hash
        //   - debit: BudgetDebit
        //   - payload: P (generic)
        //
        // A future "let me add a `created_at` timestamp" extension
        // would silently change the on-disk JSON shape for every
        // SealedMutation row — surface here via destructure
        // compile-fail + per-field type assertions.
        let envelope = MutationEnvelope::new(
            Hash::zero(),
            BudgetDebit::default(),
            "payload".to_string(),
        );
        let MutationEnvelope {
            capability_hash,
            debit,
            payload,
        } = envelope;
        let _: Hash = capability_hash;
        let _: BudgetDebit = debit;
        let _: String = payload;
    }

    #[test]
    fn every_mutation_envelope_field_is_identity_load_bearing() {
        // Phase 1 hardening — fifth leg of the identity-pin pattern
        // (AgentBlueprint 5 / AnswerPacket 7 / MissionPacket 3 /
        // ToolCall 2 fields). MutationEnvelope<String> has 3 fields
        // (capability_hash, debit, payload); each must participate
        // in PartialEq derivation. RunEventLog SealedMutation rows
        // capture envelope contents, and a future #[serde(skip)] /
        // PartialEq override that dropped any field would silently
        // let two distinct mutations compare equal and break
        // replay parity (the existing clone_equals_original test
        // proves SAME=SAME but not DIFFERENT≠DIFFERENT).
        let base = MutationEnvelope::new(
            Hash::from_bytes([7u8; 32]),
            BudgetDebit { tokens: 25, tool_calls: 1, ..Default::default() },
            "base-payload".to_string(),
        );

        let mut diff_hash = base.clone();
        diff_hash.capability_hash = Hash::from_bytes([8u8; 32]);
        assert_ne!(diff_hash, base, "capability_hash must participate in PartialEq");

        let mut diff_debit = base.clone();
        diff_debit.debit.tokens += 1;
        assert_ne!(diff_debit, base, "debit must participate in PartialEq");

        let mut diff_payload = base.clone();
        diff_payload.payload = "OTHER-payload".to_string();
        assert_ne!(diff_payload, base, "payload must participate in PartialEq");

        // Sanity preserved.
        assert_eq!(base.clone(), base);
    }

    #[test]
    fn seal_error_is_clone_send_sync_when_w_is_clone_send_sync() {
        // Phase 1 hardening — trait-bound pin for SealError<W>.
        // Companion to ToolCallError iter-385 et al.
        //
        // SealError<W>: 3-variant enum (Capability + Budget + Write).
        // The first two carry their own concrete error types
        // (CapabilityError, BudgetError) — both already pinned
        // Clone + Send + Sync. The Write variant carries the writer's
        // own W::WriteError; the overall enum is Clone + Send + Sync
        // IFF W is.
        //
        // Pinned for the canonical W = std::convert::Infallible (the
        // pure type-level witness) — proves the derive bounds are
        // intact. Send + Sync are load-bearing because SealError
        // surfaces from Sealer::seal_and_apply on a background actor
        // and the dispatcher surfaces it to the UI thread.
        fn assert_clone_send_sync<T: Clone + Send + Sync>() {}
        assert_clone_send_sync::<SealError<std::convert::Infallible>>();
        // Also for a typical concrete writer error: a unit struct.
        #[derive(Debug, Clone, PartialEq)]
        struct DiskFullErr;
        assert_clone_send_sync::<SealError<DiskFullErr>>();
    }

    #[test]
    fn mutation_envelope_is_clone_send_sync_but_not_copy_for_propagation_safety() {
        // Phase 1 hardening — trait-bound pin for the mutation request
        // envelope. Companion to AgentBlueprintId iter-375 through
        // AgentEvent iter-381 (the Clone + Send + Sync — NOT Copy —
        // variant of the sweep).
        //
        // MutationEnvelope<P>: 3 fields (capability_hash + debit +
        // payload: P). Generic over P; the typical concrete instance
        // MutationEnvelope<String> is Clone by derive but NOT Copy
        // (String allocates).
        //
        // Send + Sync are load-bearing — MutationEnvelopes ride across
        // the dispatcher's writer boundary; a non-Send payload would
        // pin them to a single thread and break the batch-write path
        // the Sealer feeds.
        //
        // Pin for both String (the canonical payload type covered by
        // most tests) and Vec<u8> (the binary-payload future).
        //
        // A future "let me hold a !Send AsyncMutex<P>" wrapper inside
        // MutationEnvelope refactor would silently break the
        // cross-thread writer path — surface here.
        fn assert_clone_send_sync<T: Clone + Send + Sync>() {}
        assert_clone_send_sync::<MutationEnvelope<String>>();
        assert_clone_send_sync::<MutationEnvelope<Vec<u8>>>();

        let e = MutationEnvelope::new(
            Hash::zero(),
            BudgetDebit::default(),
            "payload".to_string(),
        );
        assert_eq!(e.clone(), e);
    }

    #[test]
    fn mutation_envelope_clone_equals_original() {
        // Phase 1 hardening — Clone preserves PartialEq. A future
        // refactor that swaps Vec for SmallVec (or similar) must
        // keep this invariant; pin it now.
        let cap = valid_capability(None);
        let original = MutationEnvelope::new(
            cap.macaroon().capability_hash(),
            BudgetDebit { tokens: 25, tool_calls: 1, ..Default::default() },
            "payload".to_string(),
        );
        let cloned = original.clone();
        assert_eq!(cloned, original);
        assert_eq!(cloned.capability_hash, original.capability_hash);
        assert_eq!(cloned.debit, original.debit);
        assert_eq!(cloned.payload, original.payload);
    }

    #[test]
    fn mutation_envelope_new_is_deterministic_and_serialises_byte_equal_for_idempotent_retry() {
        // Phase 1 hardening — partial-failure idempotency completion
        // (user's explicit example "MutationEnvelope idempotency on
        // partial failure"). Two MutationEnvelopes built from the SAME
        // (capability_hash, debit, payload) must:
        //   1) Compare PartialEq-equal.
        //   2) Serialise to BYTE-EQUAL JSON.
        //
        // This is THE invariant that makes retry-after-partial-failure
        // safe: the caller may rebuild the envelope from-scratch on
        // retry, and the audit/replay trail still produces byte-equal
        // RunEventLog entries. Pre-iter the writer-failure pin proved
        // the LEDGER is intact after retry; this pin proves the
        // ENVELOPE itself is reconstructable byte-for-byte.
        //
        // Defends against a future "let me stamp envelope with an
        // auto-incrementing serial / timestamp / random nonce" field
        // refactor that would silently break replay byte-equality.
        let cap_hash = Hash::from_bytes([0x42; 32]);
        let debit = BudgetDebit {
            tokens: 25,
            wall_ms: 30,
            tool_calls: 1,
            subprocess_ms: 100,
            memory_bytes: 4_096,
        };
        let payload = "post-failure-retry-payload".to_string();
        let e1 = MutationEnvelope::new(cap_hash, debit, payload.clone());
        let e2 = MutationEnvelope::new(cap_hash, debit, payload.clone());
        // 1) Struct equality.
        assert_eq!(e1, e2, "MutationEnvelope::new must be deterministic");
        // 2) JSON byte-equality.
        let j1 = serde_json::to_string(&e1).expect("serialise e1");
        let j2 = serde_json::to_string(&e2).expect("serialise e2");
        assert_eq!(
            j1, j2,
            "MutationEnvelope JSON must be byte-equal across retries with same inputs"
        );
        // 3) And clone equals original — for completeness, since
        //    callers might retry via either path.
        let cloned = e1.clone();
        let j_clone = serde_json::to_string(&cloned).expect("serialise clone");
        assert_eq!(j_clone, j1, "Clone must serialise byte-equal to original");
    }

    #[test]
    fn sealer_seal_and_apply_positional_arg_order_is_pinned() {
        // Phase 1 hardening MILESTONE iter-440 — positional-order pin
        // for Sealer::seal_and_apply (the most-args-bearing dispatcher
        // entry point in agent_runtime_v2). Closes the constructor /
        // dispatcher entry-order pin family iter-433..iter-439.
        //
        // Signature:
        //   seal_and_apply(ctx, ledger, envelope, writer)
        //     -> Result<(BudgetLedger, W::Receipt), SealError<W::WriteError>>
        // (envelope.rs §148).
        //
        // A reorder would silently shuffle every dispatcher call site.
        // The args have DIFFERENT types (RuntimeContext, BudgetLedger,
        // MutationEnvelope, MutationWriter), so a swap is
        // type-incompatible — BUT pin via DISTINCT identifiable values
        // to surface any future reorder at PR review.
        //
        // Pin verifies the ledger advance matches envelope.debit AND
        // the writer is invoked once — both invariants depend on the
        // args reaching the correct internal handlers.
        let cap = valid_capability(Some(10_000));
        let sealer = Sealer {
            capability: &cap,
            gate: BudgetGate::new(BudgetSpec::new(1_000_000, 0, 100, 0)),
        };
        let pre_ledger = BudgetLedger {
            tokens_used: 7, // DISTINCTIVE pre-call value
            ..Default::default()
        };
        let envelope = MutationEnvelope::new(
            cap.macaroon().capability_hash(),
            BudgetDebit { tokens: 100, tool_calls: 1, ..Default::default() },
            "DISTINCT-PAYLOAD".to_string(),
        );
        let mut writer = RecordingWriter::new();
        let (post_ledger, _receipt) = sealer
            .seal_and_apply(&ctx(), pre_ledger, envelope, &mut writer)
            .expect("approved seal");
        // ledger param was second: pre.tokens_used (7) + envelope.debit (100) = 107.
        assert_eq!(
            post_ledger.tokens_used, 107,
            "ledger param (2nd arg) + envelope.debit (3rd arg) → 7+100=107"
        );
        // envelope param was third: writer recorded the DISTINCT payload.
        assert_eq!(writer.receipt, "DISTINCT-PAYLOAD".len() as u64);
        assert_eq!(writer.writes, 1);
    }

    #[test]
    fn mutation_envelope_new_constructor_positional_arg_order_is_pinned() {
        // Phase 1 hardening — positional-order pin for
        // MutationEnvelope::new (companion to BudgetSpec::new iter-433,
        // MissionPacket::new iter-434).
        // The signature is:
        //   new(capability_hash, debit, payload)
        // (envelope.rs §64). Each arg maps to the same-named field.
        //
        // A future reorder (e.g., payload-first because it's the
        // user-visible content) would silently shuffle every call
        // site. The 3 args have DIFFERENT types (Hash, BudgetDebit, P)
        // so a type-incompatible swap would surface as a compile
        // error — BUT a swap between args that share a Copy bound
        // (like Hash and a future Hash-like wrapper) could become
        // type-compatible and silent.
        //
        // Pin via DISTINCT identifiable values per field.
        let cap_hash = Hash::from_bytes([0x42; 32]);
        let debit = BudgetDebit {
            tokens: 999_999, // distinctively large
            ..Default::default()
        };
        let payload = "DISTINCT-PAYLOAD-CONTENT".to_string();
        let envelope = MutationEnvelope::new(cap_hash, debit, payload.clone());
        assert_eq!(envelope.capability_hash, cap_hash);
        assert_eq!(envelope.debit.tokens, 999_999);
        assert_eq!(envelope.payload, "DISTINCT-PAYLOAD-CONTENT");
    }

    #[test]
    fn mutation_envelope_new_accepts_triple_zero_inputs_per_doctrine() {
        // Phase 1 hardening — minimum-boundary pin. MutationEnvelope::new
        // accepts ANY (capability_hash, debit, payload) tuple including
        // the all-zero baseline:
        //   - Hash::zero() capability_hash
        //   - BudgetDebit::default() (all 5 axes zero)
        //   - empty payload (String::new())
        //
        // No existing test covers all three zero baselines at once.
        // A future "let me reject obviously-empty envelopes at
        // construction time" tightening would silently break the
        // synthetic-fixture path that tests + the dispatcher's
        // null-mutation probe rely on.
        //
        // Pin the all-zero acceptance + verify the round-trip
        // serialise/deserialise still works.
        let envelope = MutationEnvelope::new(
            Hash::zero(),
            BudgetDebit::default(),
            String::new(),
        );
        assert_eq!(envelope.capability_hash, Hash::zero());
        assert_eq!(envelope.debit, BudgetDebit::default());
        assert_eq!(envelope.payload, "");
        // Round-trip preserves the zero-baseline shape.
        let s = serde_json::to_string(&envelope).expect("serialise zero envelope");
        let back: MutationEnvelope<String> =
            serde_json::from_str(&s).expect("deserialise zero envelope");
        assert_eq!(back, envelope);
        // log_summary produces a parseable string even for zero inputs.
        let summary = envelope.log_summary();
        assert!(summary.starts_with("envelope{cap=00000000"));
        assert!(summary.contains("tokens=0"));
        assert!(summary.contains("tool_calls=0"));
    }

    #[test]
    fn payload_size_constant_is_4_mib() {
        assert_eq!(MutationEnvelope::<String>::MAX_RECOMMENDED_PAYLOAD_BYTES, 4 * 1024 * 1024);
    }

    #[test]
    fn payload_size_constant_is_identical_across_payload_types() {
        // Phase 1 hardening — completeness pin. The
        // MAX_RECOMMENDED_PAYLOAD_BYTES constant lives on
        // `impl<P> MutationEnvelope<P>` (envelope.rs §49) — meaning
        // it's the SAME for every payload type P. The existing
        // payload_size_constant_is_4_mib pin only exercises
        // String. A future refactor that moved the constant onto a
        // per-P trait impl (so each payload type could pick its own
        // cap) would silently fork the value across types.
        //
        // Pin that the constant resolves to the same 4 MiB for
        // String / Vec<u8> / serde_json::Value / a custom struct.
        // No new types declared — just exercises the existing impl.
        let s_cap = MutationEnvelope::<String>::MAX_RECOMMENDED_PAYLOAD_BYTES;
        let bytes_cap = MutationEnvelope::<Vec<u8>>::MAX_RECOMMENDED_PAYLOAD_BYTES;
        let json_cap = MutationEnvelope::<serde_json::Value>::MAX_RECOMMENDED_PAYLOAD_BYTES;
        let u64_cap = MutationEnvelope::<u64>::MAX_RECOMMENDED_PAYLOAD_BYTES;

        assert_eq!(s_cap, bytes_cap, "cap must match for String and Vec<u8>");
        assert_eq!(bytes_cap, json_cap, "cap must match for Vec<u8> and Value");
        assert_eq!(json_cap, u64_cap, "cap must match for Value and u64");
        assert_eq!(s_cap, 4 * 1024 * 1024, "all caps must equal 4 MiB");
    }

    #[test]
    fn estimate_payload_bytes_is_pure_deterministic_across_multiple_calls() {
        // Phase 1 hardening — pure-function determinism pin
        // (companion to the purity series). estimate_payload_bytes
        // calls serde_json::to_vec(&payload).ok().map(|b| b.len());
        // pure function over immutable &self.
        let envelope = MutationEnvelope::new(
            Hash::zero(),
            BudgetDebit::default(),
            "deterministic".to_string(),
        );
        let r1 = envelope.estimate_payload_bytes();
        let r2 = envelope.estimate_payload_bytes();
        let r3 = envelope.estimate_payload_bytes();
        assert_eq!(r1, r2);
        assert_eq!(r2, r3);
        assert!(r1.is_some());
    }

    #[test]
    fn estimate_payload_bytes_matches_serde_size_for_string() {
        let envelope =
            MutationEnvelope::new(Hash::zero(), BudgetDebit::default(), "hello-world".to_string());
        let bytes = envelope.estimate_payload_bytes().expect("serialises");
        let independent = serde_json::to_vec(&"hello-world".to_string()).unwrap().len();
        assert_eq!(bytes, independent);
    }

    #[test]
    fn exceeds_recommended_payload_size_is_pure_deterministic_across_multiple_calls() {
        // Phase 1 hardening — pure-function determinism pin
        // (companion to iter-268 estimate_payload_bytes determinism).
        // exceeds_recommended_payload_size delegates to
        // estimate_payload_bytes + a constant comparison; pure.
        let envelope = MutationEnvelope::new(
            Hash::zero(),
            BudgetDebit::default(),
            "small".to_string(),
        );
        for _ in 0..3 {
            assert!(!envelope.exceeds_recommended_payload_size());
        }
        // Same property on the over-cap path.
        let huge = "x".repeat(5 * 1024 * 1024);
        let over = MutationEnvelope::new(Hash::zero(), BudgetDebit::default(), huge);
        for _ in 0..3 {
            assert!(over.exceeds_recommended_payload_size());
        }
    }

    #[test]
    fn exceeds_recommended_payload_size_flags_oversize_string() {
        // 5 MiB payload trips the 4 MiB cap.
        let huge = "x".repeat(5 * 1024 * 1024);
        let envelope = MutationEnvelope::new(Hash::zero(), BudgetDebit::default(), huge);
        assert!(envelope.exceeds_recommended_payload_size());
    }

    #[test]
    fn exceeds_recommended_payload_size_at_exact_cap_boundary_does_not_flag() {
        // Phase 1 hardening — boundary completeness. The existing
        // exceeds_recommended_payload_size_flags_oversize_string
        // test uses 5 MiB > 4 MiB cap. The
        // under_cap_payload_does_not_flag test uses a tiny string
        // far below the cap. The AT-cap boundary (exactly
        // MAX_RECOMMENDED_PAYLOAD_BYTES) was unpinned.
        //
        // The function uses `> Self::MAX_RECOMMENDED_PAYLOAD_BYTES`
        // (strict greater), so at-cap → false, over-by-one → true.
        // Pin the boundary precisely.
        //
        // Note: estimate_payload_bytes counts the SERIALISED JSON
        // length, which includes the surrounding quotes for a String
        // payload. The serialised length of `"x".repeat(N)` is N + 2
        // (the two quote chars). So to produce a payload that
        // SERIALISES to exactly MAX bytes, we use N = MAX - 2.
        let cap = MutationEnvelope::<String>::MAX_RECOMMENDED_PAYLOAD_BYTES;
        let at_cap = "x".repeat(cap - 2);
        let envelope_at = MutationEnvelope::new(
            Hash::zero(),
            BudgetDebit::default(),
            at_cap,
        );
        assert_eq!(envelope_at.estimate_payload_bytes(), Some(cap));
        assert!(!envelope_at.exceeds_recommended_payload_size());

        // One byte over → trips.
        let over = "x".repeat(cap - 1);
        let envelope_over = MutationEnvelope::new(
            Hash::zero(),
            BudgetDebit::default(),
            over,
        );
        assert_eq!(envelope_over.estimate_payload_bytes(), Some(cap + 1));
        assert!(envelope_over.exceeds_recommended_payload_size());
    }

    #[test]
    fn empty_payload_does_not_flag_and_estimates_to_two_bytes_for_string_quotes() {
        // Phase 1 hardening — boundary completeness companion to
        // exceeds_recommended_payload_size_at_exact_cap_boundary_does_not_flag.
        // The existing tests cover at-cap and over-by-one. The OTHER
        // boundary — empty payload — is unpinned:
        //
        //   - estimate_payload_bytes("") → Some(2) because the JSON
        //     serialisation of an empty String is `""` (2 bytes, just
        //     the quotes).
        //   - exceeds_recommended_payload_size("") → false (2 < 4 MiB).
        //
        // Defends against a future "let me return None for empty
        // payloads instead of Some(2)" or "let me flag empty payloads
        // as oversize for some reason" refactor that would silently
        // change the audit-surface contract for capability-denial-
        // before-any-bytes scenarios.
        let envelope_empty = MutationEnvelope::new(
            Hash::zero(),
            BudgetDebit::default(),
            String::new(),
        );
        // String "" serialises to 2 bytes: the open + close quote.
        assert_eq!(
            envelope_empty.estimate_payload_bytes(),
            Some(2),
            "empty string payload must estimate to 2 bytes (the surrounding quotes)"
        );
        assert!(
            !envelope_empty.exceeds_recommended_payload_size(),
            "empty payload must not flag as oversize"
        );
    }

    #[test]
    fn under_cap_payload_does_not_flag() {
        let small = "small-payload".to_string();
        let envelope = MutationEnvelope::new(Hash::zero(), BudgetDebit::default(), small);
        assert!(!envelope.exceeds_recommended_payload_size());
    }

    #[test]
    fn mutation_envelope_new_preserves_arbitrary_capability_hash_byte_for_byte() {
        // Phase 1 hardening — companion to iter-237 (emit_with_thinking
        // hash pass-through pin). MutationEnvelope::new surfaces the
        // caller's capability_hash verbatim into the envelope. The
        // constructor MUST NOT normalise, mask, or replace the hash
        // with a synthesised value.
        //
        // A future "let me derive capability_hash from the payload"
        // refactor would silently break the cross-reference between
        // SealedMutation rows in RunEventLog and their authorising
        // macaroon.
        for h in [
            Hash::zero(),
            Hash::from_bytes([0xFF; 32]),
            Hash::from_bytes([0x42; 32]),
            Hash::from_bytes([
                0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
                0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F, 0x10,
                0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18,
                0x19, 0x1A, 0x1B, 0x1C, 0x1D, 0x1E, 0x1F, 0x20,
            ]),
        ] {
            let envelope = MutationEnvelope::new(
                h,
                BudgetDebit::default(),
                "payload".to_string(),
            );
            assert_eq!(envelope.capability_hash, h, "capability_hash must be byte-equal for {h:?}");
        }
    }

    #[test]
    fn capability_hash_in_envelope_matches_macaroon() {
        let cap = valid_capability(None);
        let hash = cap.macaroon().capability_hash();
        let envelope =
            MutationEnvelope::new(hash, BudgetDebit::default(), "payload".to_string());
        assert_eq!(envelope.capability_hash, hash);
        assert_eq!(envelope.capability_hash, cap.macaroon().capability_hash());
    }

    #[test]
    fn sealer_does_not_verify_envelope_cap_hash_matches_capability_macaroon() {
        // Phase 1 hardening — DOCTRINE PIN. The Sealer verifies the
        // CAPABILITY (via cap.verify(ctx)) and applies the BUDGET
        // (via gate.check_and_debit) but does NOT cross-check that
        // envelope.capability_hash equals cap.macaroon().capability_hash().
        //
        // This is by design: the dispatcher is the producer that
        // populates envelope.capability_hash and is trusted to use
        // the same capability it presents to the Sealer. The Sealer
        // doesn't re-verify the link; it would be expensive (BLAKE3
        // recompute on every seal) and the envelope→cap relationship
        // is documented as a producer-side invariant.
        //
        // Pin the current behaviour so a future "let me belt-and-
        // suspenders the cap hash" tightening surfaces at PR review
        // as a deliberate doctrine change. Currently, an envelope with
        // a DIFFERENT capability_hash than the cap's macaroon hash
        // STILL seals successfully (the cap verifies; the budget
        // applies; the write lands).
        //
        // The audit-trail downstream of the seal (SealedMutation row
        // appended by the caller) records ENVELOPE.capability_hash,
        // not the cap's actual hash — so the producer-side invariant
        // is what audit dashboards rely on. This pin documents that
        // contract.
        let cap = valid_capability(Some(10_000));
        let sealer = Sealer {
            capability: &cap,
            gate: BudgetGate::new(BudgetSpec::new(1_000, 0, 5, 0)),
        };
        // Envelope carries an INTENTIONALLY-WRONG capability_hash
        // (zero) while the cap's macaroon hash is non-zero.
        let actual_cap_hash = cap.macaroon().capability_hash();
        assert_ne!(actual_cap_hash, Hash::zero());
        let envelope = MutationEnvelope::new(
            Hash::zero(),
            BudgetDebit { tokens: 25, tool_calls: 1, ..Default::default() },
            "payload".to_string(),
        );
        let mut writer = RecordingWriter::new();
        let (ledger, _) = sealer
            .seal_and_apply(&ctx(), BudgetLedger::default(), envelope, &mut writer)
            .expect("envelope cap_hash mismatch does NOT block seal — producer-side invariant");
        assert_eq!(writer.writes, 1);
        assert_eq!(ledger.tokens_used, 25);
    }

    #[test]
    fn sealer_is_reusable_for_multiple_seal_and_apply_calls() {
        // Phase 1 hardening — Sealer doctrine pin. The Sealer struct
        // (envelope.rs §137) is documented as "Stateless; the caller
        // owns the capability, gate, and current ledger." Its
        // seal_and_apply method takes `&self`, not `self` — so the
        // same Sealer instance can drive MULTIPLE envelope applications.
        //
        // No existing test pins this. A future "let me track call
        // count in Sealer to detect double-use" or "let me make
        // seal_and_apply take `self` (consume)" refactor would break
        // any caller that currently relies on reuse (e.g., a batch
        // dispatch loop that builds one Sealer and applies N envelopes).
        //
        // Pin that 3 consecutive seal_and_apply calls on the SAME
        // Sealer instance all succeed and advance the ledger
        // monotonically.
        let cap = valid_capability(Some(10_000));
        let sealer = Sealer {
            capability: &cap,
            gate: BudgetGate::new(BudgetSpec::new(1_000, 0, 5, 0)),
        };
        let mut writer = RecordingWriter::new();
        let mut ledger = BudgetLedger::default();
        let debit_each = BudgetDebit { tokens: 100, tool_calls: 1, ..Default::default() };

        for i in 1..=3 {
            let envelope = MutationEnvelope::new(
                cap.macaroon().capability_hash(),
                debit_each,
                format!("payload-{i}"),
            );
            let (new_ledger, _) = sealer
                .seal_and_apply(&ctx(), ledger, envelope, &mut writer)
                .unwrap_or_else(|e| panic!("call {i} must succeed on reusable sealer: {e:?}"));
            ledger = new_ledger;
            // Ledger advances by exactly 100 tokens + 1 tool_call per call.
            assert_eq!(ledger.tokens_used, 100 * i as u64);
            assert_eq!(ledger.tool_calls_used, i as u64);
        }
        // Writer recorded 3 distinct writes.
        assert_eq!(writer.writes, 3);
    }

    #[test]
    fn capability_replay_envelope_round_trip_still_seals() {
        // Capability replay: serialize a MutationEnvelope to JSON
        // (persisting it via RunEventLog or .epbundle), drop the
        // in-memory state, deserialize, and re-verify via a fresh
        // Sealer. The macaroon embedded behind the capability_hash
        // remains valid, and the writer must still apply the payload.
        let cap = valid_capability(Some(10_000));
        let gate = BudgetGate::new(BudgetSpec::new(1_000, 0, 5, 0));
        let envelope = MutationEnvelope::new(
            cap.macaroon().capability_hash(),
            BudgetDebit { tokens: 50, tool_calls: 1, ..Default::default() },
            "replay-payload".to_string(),
        );

        // Persist + reload.
        let s = serde_json::to_string(&envelope).expect("serialize");
        let replayed: MutationEnvelope<String> =
            serde_json::from_str(&s).expect("deserialize");
        assert_eq!(replayed, envelope);

        // Re-verify with a fresh Sealer reading the replayed envelope.
        let sealer = Sealer {
            capability: &cap,
            gate,
        };
        let mut writer = RecordingWriter::new();
        let (ledger, _receipt) = sealer
            .seal_and_apply(&ctx(), BudgetLedger::default(), replayed, &mut writer)
            .expect("replayed envelope must seal");
        assert_eq!(writer.writes, 1);
        assert_eq!(ledger.tokens_used, 50);
        assert_eq!(ledger.tool_calls_used, 1);
    }

    #[test]
    fn sealer_writer_failure_does_not_advance_caller_ledger() {
        // Phase 1 hardening — partial-failure idempotency. Sealer
        // doctrine (envelope.rs §Gate 2 comment): "on writer failure
        // the caller keeps the original ledger ... we only consider
        // it spent once the side effect lands." This invariant is
        // currently UNPROVEN by a behavioral test. Pin it.
        //
        // Setup: an always-failing writer. Capability + budget gates
        // pass; the third (writer) gate trips. On Err the function
        // returns SealError::Write with no advanced ledger — and the
        // caller's `BudgetLedger` (Copy) is intact. A second call
        // with a SUCCEEDING writer starting from the same ledger
        // must land at the single-debit-applied state, proving the
        // failed first attempt left no hidden state in the gate.
        #[derive(Debug, PartialEq, Eq)]
        struct DiskFull;
        struct FailingWriter {
            attempts: usize,
        }
        impl MutationWriter<String> for FailingWriter {
            type Receipt = ();
            type WriteError = DiskFull;
            fn write(&mut self, _payload: &String) -> Result<(), DiskFull> {
                self.attempts += 1;
                Err(DiskFull)
            }
        }

        let cap = valid_capability(Some(10_000));
        let sealer = Sealer {
            capability: &cap,
            gate: BudgetGate::new(BudgetSpec::new(1_000, 0, 5, 0)),
        };
        let envelope = MutationEnvelope::new(
            cap.macaroon().capability_hash(),
            BudgetDebit { tokens: 25, tool_calls: 1, ..Default::default() },
            "partial-failure-payload".to_string(),
        );

        let ledger_before = BudgetLedger::default();
        let mut failing = FailingWriter { attempts: 0 };
        let err = sealer
            .seal_and_apply(&ctx(), ledger_before, envelope.clone(), &mut failing)
            .expect_err("writer failure must surface as Err");
        match err {
            SealError::Write(DiskFull) => {}
            other => panic!("expected SealError::Write(DiskFull), got {other:?}"),
        }
        // Writer was invoked exactly once (capability + budget already
        // cleared; the third gate is where we failed).
        assert_eq!(failing.attempts, 1);

        // Caller's ledger is intact (Copy semantics + Err carries no
        // advanced ledger). Subsequent successful apply from the SAME
        // pre-failure ledger lands at single-debit state — no hidden
        // double-debit from the failed first attempt.
        let mut succeeding = RecordingWriter::new();
        let (ledger_after, _receipt) = sealer
            .seal_and_apply(&ctx(), ledger_before, envelope, &mut succeeding)
            .expect("retry with succeeding writer must apply");
        assert_eq!(succeeding.writes, 1);
        // Exactly one debit applied — not two — proving the failed
        // first attempt did not leak budget through the gate.
        assert_eq!(ledger_after.tokens_used, 25);
        assert_eq!(ledger_after.tool_calls_used, 1);
        // And the pre-call ledger snapshot still reads as the zero
        // ledger — Sealer never mutated it through the failure path.
        assert_eq!(ledger_before, BudgetLedger::default());
    }

    #[test]
    fn sealer_n_consecutive_writer_failures_before_success_apply_single_debit() {
        // Phase 1 hardening — work-queue item E: MutationEnvelope
        // idempotency on partial failure (replay-safe re-application).
        // Companion to sealer_writer_failure_does_not_advance_caller_ledger
        // which proves the 1-failure-then-1-success case. THIS pin
        // extends to N consecutive failures (N=5) followed by 1
        // success.
        //
        // The retry chain proves the failed attempts NEVER leak
        // budget into the gate — even when stacked. After 5 failures
        // + 1 success, exactly ONE debit must be applied to the
        // ledger (not 6, not 0). The writer must have been invoked
        // EXACTLY 6 times across the 6 calls (5 failures + 1 success).
        //
        // Defends against a future "let me keep a retry-counter
        // inside the gate to bound flapping" optimisation that
        // could silently allocate budget on the first attempt and
        // refund partially, leaving a residual debit. THIS pin
        // catches both directions: hidden debit accumulation AND
        // refund-overshoot.
        //
        // The "flapping" scenario (failure → success → failure) is
        // realistic: a writer might be a remote service whose
        // intermittent failures the dispatcher transparently retries.

        // Toggle-able writer: fails K times, then succeeds. Mirrors
        // the production retry loop without a real network.
        struct ToggleWriter {
            failures_remaining: usize,
            writes: usize,
        }
        #[derive(Debug, PartialEq, Eq)]
        struct Transient;
        impl MutationWriter<String> for ToggleWriter {
            type Receipt = u64;
            type WriteError = Transient;
            fn write(&mut self, payload: &String) -> Result<u64, Transient> {
                self.writes += 1;
                if self.failures_remaining > 0 {
                    self.failures_remaining -= 1;
                    Err(Transient)
                } else {
                    Ok(payload.len() as u64)
                }
            }
        }

        let cap = valid_capability(Some(10_000));
        let envelope_template = || {
            MutationEnvelope::new(
                cap.macaroon().capability_hash(),
                BudgetDebit { tokens: 30, tool_calls: 1, ..Default::default() },
                "retry-payload".to_string(),
            )
        };
        let ledger_pre = BudgetLedger::default();

        // 5 consecutive failure attempts. Each on a FRESH Sealer
        // (Sealer is single-use by ownership of BudgetGate). Each
        // must surface SealError::Write(Transient) and leave the
        // pre-call ledger intact.
        let mut writer = ToggleWriter {
            failures_remaining: 5,
            writes: 0,
        };
        let mut total_failed = 0usize;
        for attempt in 0..5 {
            let fresh_gate = BudgetGate::new(BudgetSpec::new(1_000, 0, 10, 0));
            let sealer = Sealer {
                capability: &cap,
                gate: fresh_gate,
            };
            let err = sealer
                .seal_and_apply(&ctx(), ledger_pre, envelope_template(), &mut writer)
                .expect_err(&format!("attempt {attempt} must fail"));
            assert!(
                matches!(err, SealError::Write(Transient)),
                "attempt {attempt}: expected SealError::Write(Transient), got {err:?}"
            );
            total_failed += 1;
        }
        assert_eq!(total_failed, 5, "5 attempts must have failed");
        // After 5 failures, the writer's failures_remaining is 0
        // and `writes` is exactly 5 (one per attempt).
        assert_eq!(writer.writes, 5, "writer invoked once per failure");
        assert_eq!(
            writer.failures_remaining, 0,
            "ToggleWriter must have exhausted its failure budget"
        );

        // 6th attempt — now succeeds. Land at single-debit state.
        let success_sealer = Sealer {
            capability: &cap,
            gate: BudgetGate::new(BudgetSpec::new(1_000, 0, 10, 0)),
        };
        let (ledger_after, receipt) = success_sealer
            .seal_and_apply(&ctx(), ledger_pre, envelope_template(), &mut writer)
            .expect("6th attempt must succeed");
        // Writer was invoked one more time (total 6 across the chain).
        assert_eq!(writer.writes, 6, "writer invoked exactly 6 times across chain");
        // Single debit applied (30 tokens + 1 tool_call), NOT 6×.
        assert_eq!(ledger_after.tokens_used, 30, "single debit, not 6× accumulation");
        assert_eq!(ledger_after.tool_calls_used, 1, "single tool_call debit");
        // Pre-call ledger remained zero.
        assert_eq!(ledger_pre, BudgetLedger::default());
        // Receipt reflects payload length (sanity: writer got the
        // SAME byte-equal envelope payload across all 6 calls).
        assert_eq!(receipt, "retry-payload".len() as u64);
    }

    #[test]
    fn mutation_envelope_serde_tolerates_unknown_extra_fields_per_current_doctrine() {
        // Phase 1 hardening — fourth leg of the unknown-fields
        // tolerance pattern (AgentBlueprint iter-121, AnswerPacket
        // iter-122, MissionPacket iter-123, MutationEnvelope here).
        // MutationEnvelope<P> persists inside RunEventLog
        // SealedMutation row payloads + .epbundle replays; a v3
        // envelope with an extra audit annotation field must still
        // deserialise under v2 readers.
        //
        // No #[serde(deny_unknown_fields)] on MutationEnvelope, so
        // the default lenient behaviour applies. Pin it.
        let base = MutationEnvelope::new(
            Hash::from_bytes([3u8; 32]),
            BudgetDebit { tokens: 50, tool_calls: 1, ..Default::default() },
            "forward-compat-payload".to_string(),
        );
        let s = serde_json::to_string(&base).expect("serialise");
        let augmented = s
            .trim_end_matches('}')
            .to_string()
            + r#","future_audit_annotation":"v3-experimental"}"#;
        let parsed: MutationEnvelope<String> =
            serde_json::from_str(&augmented).expect("unknown field tolerated");
        assert_eq!(parsed, base);
    }

    #[test]
    fn mutation_envelope_serde_json_preserves_struct_field_declaration_order() {
        // Phase 1 hardening — wire-shape pin extending iter-156
        // (presence + count) with field-order. MutationEnvelope<P>
        // declares: capability_hash, debit, payload. A future
        // reorder breaks byte-equal cache keys + diff tools.
        let envelope = MutationEnvelope::new(
            Hash::from_bytes([1u8; 32]),
            BudgetDebit::default(),
            "payload".to_string(),
        );
        let s = serde_json::to_string(&envelope).expect("serialise");
        let expected_keys_in_order = [
            "\"capability_hash\":",
            "\"debit\":",
            "\"payload\":",
        ];
        let mut last_idx: Option<usize> = None;
        for key in expected_keys_in_order {
            let pos = s.find(key).unwrap_or_else(|| panic!("key {key} not found in {s}"));
            if let Some(prev) = last_idx {
                assert!(
                    pos > prev,
                    "field {key} at byte {pos} must appear after previous field at {prev}"
                );
            }
            last_idx = Some(pos);
        }
    }

    #[test]
    fn mutation_envelope_serde_json_contains_all_three_canonical_top_level_keys() {
        // Phase 1 hardening — wire-shape pin matching the pattern
        // (AgentBlueprint 5 keys, MissionPacket 3 keys iter-154,
        // AnswerPacket 7 keys iter-155). MutationEnvelope<P> has
        // 3 top-level fields (capability_hash, debit, payload); a
        // silent rename would round-trip but break replay tools
        // and the SealedMutation row consumers that parse by field
        // name.
        let envelope = MutationEnvelope::new(
            Hash::from_bytes([1u8; 32]),
            BudgetDebit::default(),
            "payload".to_string(),
        );
        let json = serde_json::to_value(&envelope).expect("serialise");
        let obj = json.as_object().expect("envelope serialises as JSON object");
        for key in ["capability_hash", "debit", "payload"] {
            assert!(
                obj.contains_key(key),
                "missing top-level key {key:?} in {json:?}"
            );
        }
        assert_eq!(
            obj.len(),
            3,
            "expected exactly 3 top-level keys, got {} ({:?})",
            obj.len(),
            obj.keys().collect::<Vec<_>>()
        );
    }

    #[test]
    fn mutation_envelope_serde_value_payload_round_trips_through_serde() {
        // Phase 1 hardening — generic-payload pin for
        // MutationEnvelope<serde_json::Value>. Companion to
        // MutationEnvelope<String> (mission_envelope_serde_preserves_unicode...)
        // and MutationEnvelope<Vec<u8>> (iter-446).
        //
        // Value payloads carry arbitrary JSON shapes — the dispatcher's
        // general-purpose mutation surface for tool calls that emit
        // structured output that doesn't fit a String. Pin that the
        // Value round-trips deep-equal through serde without loss.
        let value_payload = serde_json::json!({
            "nested": {
                "deep": {
                    "array": [1, 2.5, "string", null, true, false],
                    "unicode": "笔记 🚀"
                }
            },
            "scalar": 42
        });
        let envelope = MutationEnvelope::new(
            Hash::from_bytes([0x11; 32]),
            BudgetDebit { tokens: 25, ..Default::default() },
            value_payload.clone(),
        );
        let s = serde_json::to_string(&envelope).expect("serialise");
        let back: MutationEnvelope<serde_json::Value> =
            serde_json::from_str(&s).expect("deserialise");
        assert_eq!(back.payload, value_payload, "Value payload must round-trip deep-equal");
        assert_eq!(back, envelope);
        // Independent walk to catch any silent type coercion.
        assert_eq!(back.payload["scalar"], 42);
        assert_eq!(back.payload["nested"]["deep"]["unicode"], "笔记 🚀");
        assert_eq!(back.payload["nested"]["deep"]["array"][0], 1);
        assert_eq!(back.payload["nested"]["deep"]["array"][5], false);
    }

    #[test]
    fn mutation_envelope_vec_u8_payload_round_trips_through_serde_byte_for_byte() {
        // Phase 1 hardening — binary-payload pin for MutationEnvelope<Vec<u8>>.
        // Companion to the String-payload Unicode + JSON-special pins.
        //
        // serde_json's default Vec<u8> serialise is as a JSON ARRAY of
        // numbers (e.g., [0, 1, 255, 254]), NOT a base64 string —
        // pin this lossless representation.
        //
        // Binary payloads cover: thinking-block bytes serialised into
        // an envelope, image bytes for vision tools, raw protobuf
        // bytes, etc. A future #[serde(with = "...")] base64 escape
        // would silently change the on-disk representation.
        let payload: Vec<u8> = (0..=255u8).collect();
        let envelope = MutationEnvelope::new(
            Hash::zero(),
            BudgetDebit::default(),
            payload.clone(),
        );
        let s = serde_json::to_string(&envelope).expect("serialise");
        let back: MutationEnvelope<Vec<u8>> =
            serde_json::from_str(&s).expect("deserialise");
        assert_eq!(back.payload.len(), 256);
        assert_eq!(back.payload, payload, "Vec<u8> payload must round-trip byte-equal");
        assert_eq!(back, envelope);

        // Serialised form contains the JSON-array literal (no base64).
        // Spot-check: 0 + 255 + 128 all appear as bare numerals.
        assert!(s.contains("0"));
        assert!(s.contains("255"));
        assert!(s.contains("128"));
    }

    #[test]
    fn mutation_envelope_preserves_json_special_chars_in_payload_through_serde() {
        // Phase 1 hardening — adversarial JSON pin for MutationEnvelope<String>
        // (companion to mission_packet iter-413, answer_packet iter-414,
        // citation iter-415).
        //
        // Mutation payloads carry arbitrary user content: file
        // contents being written, JSON-serialised state, command
        // strings with embedded quotes. Serde must escape these
        // correctly through round-trip without lossy sanitisation.
        let adversarial = [
            r#"{"json": "in payload", "nested": {"k": [1, 2, 3]}}"#,
            "multi\nline\npayload",
            r#"backslash \ quote " tab \t escape"#,
            "control\x01char\x02survives",
        ];
        for payload in adversarial {
            let envelope = MutationEnvelope::new(
                Hash::zero(),
                BudgetDebit::default(),
                payload.to_string(),
            );
            let s = serde_json::to_string(&envelope).expect("serialise");
            let back: MutationEnvelope<String> =
                serde_json::from_str(&s).expect("deserialise");
            assert_eq!(back.payload, payload, "payload must round-trip byte-equal");
            assert_eq!(back, envelope);
        }
    }

    #[test]
    fn mutation_envelope_serde_preserves_unicode_in_string_payload() {
        // Phase 1 hardening — Unicode safety pin for
        // MutationEnvelope<String> serde (companion to the cross-
        // structure Unicode-preservation series). The payload field
        // is generic over P; for P=String, the JSON encoding must
        // preserve Unicode byte-equal.
        //
        // RunEventLog SealedMutation rows quote envelope payloads
        // verbatim. A future #[serde(default)] or custom serialiser
        // that escaped non-ASCII would skew the on-disk byte form.
        let envelope = MutationEnvelope::new(
            Hash::from_bytes([1u8; 32]),
            BudgetDebit::default(),
            "保存: ノート 📝🌸".to_string(),
        );
        let s = serde_json::to_string(&envelope).expect("serialise");
        let back: MutationEnvelope<String> =
            serde_json::from_str(&s).expect("deserialise");
        assert_eq!(back, envelope);
        assert_eq!(back.payload, "保存: ノート 📝🌸");
        // Literal multi-byte chars appear in the JSON.
        assert!(s.contains("保存: ノート 📝🌸"));
    }

    #[test]
    fn envelope_round_trips_through_json() {
        // Required because envelopes get persisted into RunEventLog.
        let cap = valid_capability(None);
        let envelope = MutationEnvelope::new(
            cap.macaroon().capability_hash(),
            BudgetDebit { tokens: 10, ..Default::default() },
            "json-payload".to_string(),
        );
        let s = serde_json::to_string(&envelope).expect("serialize");
        let back: MutationEnvelope<String> = serde_json::from_str(&s).expect("deserialize");
        assert_eq!(back, envelope);
    }

    #[test]
    fn sealer_fields_are_pub_per_field_visibility_doctrine() {
        // Sealer<'a, C> has 2 pub fields: capability (&'a C) and gate
        // (BudgetGate). Direct .capability / .gate access is part of the
        // construction contract — callers build a Sealer via struct-literal
        // syntax with named fields, and any narrowing to getter-only
        // accessors would force a breaking-change rewrite of every call
        // site. Pin guards against that accidental narrowing.
        let cap = valid_capability(Some(10_000));
        let spec = BudgetSpec::new(1_000, 100, 0, 0);
        let gate = BudgetGate::new(spec);
        let sealer = Sealer { capability: &cap, gate };
        let _cap_ref: &MacaroonCapability = sealer.capability;
        let _gate_ref: &BudgetGate = &sealer.gate;
    }

    #[test]
    fn mutation_envelope_new_equals_struct_literal_byte_for_byte() {
        // Phase 1 hardening — thin-wrapper equivalence pin (companion
        // to the equivalence-pin family at iter-518/519/520/521).
        // MutationEnvelope::new is the canonical ergonomic constructor;
        // it MUST produce an envelope byte-equal to the direct
        // struct-literal form across representative payload shapes.
        // A future "let me canonicalise the payload" or "let me hash
        // it pre-storage" tweak in the helper that diverged from
        // struct construction would silently introduce two distinct
        // envelope byte forms depending on call site — breaking
        // RunEventLog row equality + replay parity downstream.
        //
        // Sweep: empty, minimal, Unicode, special chars, multi-byte.
        let cap_hash = Hash::from_bytes([0x77; 32]);
        let payloads: &[&str] = &[
            "",
            "p",
            "Hello, world",
            "勉強します 📝",
            "with\nnewline",
            "with\"quote\"",
        ];
        for &p in payloads {
            let debit = BudgetDebit {
                tokens: p.len() as u64,
                ..Default::default()
            };
            let via_new = MutationEnvelope::new(cap_hash, debit, p.to_string());
            let via_struct: MutationEnvelope<String> = MutationEnvelope {
                capability_hash: cap_hash,
                debit,
                payload: p.to_string(),
            };
            assert_eq!(via_new, via_struct, "new vs struct for payload {p:?}");
            let j_new = serde_json::to_string(&via_new).expect("serialize new");
            let j_struct = serde_json::to_string(&via_struct).expect("serialize struct");
            assert_eq!(j_new, j_struct);
        }
    }
}
