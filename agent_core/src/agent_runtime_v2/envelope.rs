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
    fn payload_size_constant_is_4_mib() {
        assert_eq!(MutationEnvelope::<String>::MAX_RECOMMENDED_PAYLOAD_BYTES, 4 * 1024 * 1024);
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
    fn exceeds_recommended_payload_size_flags_oversize_string() {
        // 5 MiB payload trips the 4 MiB cap.
        let huge = "x".repeat(5 * 1024 * 1024);
        let envelope = MutationEnvelope::new(Hash::zero(), BudgetDebit::default(), huge);
        assert!(envelope.exceeds_recommended_payload_size());
    }

    #[test]
    fn under_cap_payload_does_not_flag() {
        let small = "small-payload".to_string();
        let envelope = MutationEnvelope::new(Hash::zero(), BudgetDebit::default(), small);
        assert!(!envelope.exceeds_recommended_payload_size());
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
}
