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
    use crate::agent_runtime_v2::budget::{BudgetDebit, BudgetSpec};
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
