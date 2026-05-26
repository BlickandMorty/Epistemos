//! `MissionRun` — minimal-slice composition helper for the canonical
//! `AgentBlueprint → MissionPacket → AgentEvent stream → MutationEnvelope
//! → RunEventLog → AnswerPacket` flow.
//!
//! R3 (2026-05-23): the v2 substrate ships every piece in isolation —
//! [`super::budget::BudgetGate`], [`super::budget::BudgetLedger`],
//! [`super::run_event_log::RunEventLog`], [`super::answer::AnswerPacket`] —
//! but no public helper bundles them together. Callers therefore open-code
//! the 5-step "check budget → debit → append sealed mutation → append
//! ledger snapshot → finalize" incantation per mutation, which means a bug
//! at any one step (e.g. updating the local ledger but forgetting the
//! snapshot) silently corrupts the witness chain.
//!
//! `MissionRun` collapses the incantation into atomic calls so the
//! witness invariants hold by construction:
//! - Budget rejection → NOTHING written (no sealed mutation, no snapshot).
//! - Budget acceptance → BOTH sealed mutation AND ledger snapshot
//!   appended, in that order, before returning.
//!
//! This is the **minimum** safe seam. Real executors (model adapter,
//! tool runner) live above this and stream `AgentEvent`s via
//! [`MissionRun::record_event`].

use super::answer::{AnswerPacket, Citation};
use super::blueprint::AgentBlueprintId;
use super::budget::{BudgetDebit, BudgetError, BudgetGate, BudgetLedger, BudgetSpec};
use super::event::{AgentEvent, AgentEventErrorKind};
use super::mission::{ToolCall, ToolCallError};
use super::para::StopReason;
use super::run_event_log::RunEventLog;
use crate::acs_admission::{
    ACSAdmissionInput, ACSAdmissionPayload, ACSAdmissionProofError, ACSAdmissionVerdict,
    ACSAuditError, ACSAuditRecord, ACSOperationKind, ACSPolicy, ACSRiskVector, ACSRunEventLogSink,
    ACSToolActionRequest,
};
use crate::cognitive_dag::node::Hash;
use crate::effect::receipt::SigningKey;
use crate::scope_rex::admission_proof::SCOPERexAdmissionProof;

#[derive(Debug, Clone, PartialEq)]
pub struct ToolCallAdmissionHandoff {
    pub event_ordinal: u64,
    pub call: ToolCall,
    pub admission_proof: SCOPERexAdmissionProof,
    pub audit_record: ACSAuditRecord,
}

#[derive(Debug, Clone, PartialEq)]
pub enum ToolCallAdmissionError {
    MalformedToolCall(ToolCallError),
    Audit(ACSAuditError),
    Proof(ACSAdmissionProofError),
    Blocked {
        verdict: ACSAdmissionVerdict,
        record_id: String,
        reason: String,
    },
}

impl ToolCallAdmissionError {
    #[must_use]
    pub const fn cause(&self) -> &'static str {
        match self {
            Self::MalformedToolCall(_) => "malformed_tool_call",
            Self::Audit(error) => error.cause(),
            Self::Proof(error) => error.cause(),
            Self::Blocked { .. } => "acs_verdict_blocks_tool_call",
        }
    }
}

impl From<ToolCallError> for ToolCallAdmissionError {
    fn from(error: ToolCallError) -> Self {
        Self::MalformedToolCall(error)
    }
}

impl From<ACSAuditError> for ToolCallAdmissionError {
    fn from(error: ACSAuditError) -> Self {
        Self::Audit(error)
    }
}

impl From<ACSAdmissionProofError> for ToolCallAdmissionError {
    fn from(error: ACSAdmissionProofError) -> Self {
        Self::Proof(error)
    }
}

fn tool_call_request_id(call: &ToolCall, submitted_at_ms: i64, audit_len: usize) -> String {
    let mut bytes = Vec::new();
    bytes.extend_from_slice(call.name.as_bytes());
    bytes.push(0);
    bytes.extend_from_slice(&serde_json::to_vec(&call.arguments).unwrap_or_default());
    let digest = blake3::hash(&bytes).to_hex().to_string();
    format!("tool.{}.{}.{}", submitted_at_ms, audit_len, &digest[..16])
}

fn tool_call_target(call: &ToolCall) -> String {
    for key in ["target", "path", "address"] {
        if let Some(target) = call.arguments.get(key).and_then(serde_json::Value::as_str) {
            let target = target.trim();
            if !target.is_empty() {
                return target.to_string();
            }
        }
    }
    format!("tool.{}", call.name)
}

/// Composition helper that bundles [`BudgetGate`] + [`BudgetLedger`] +
/// [`RunEventLog`] for a single mission run. See module doc.
#[derive(Debug)]
pub struct MissionRun {
    blueprint_id: AgentBlueprintId,
    gate: BudgetGate,
    ledger: BudgetLedger,
    log: RunEventLog,
}

impl MissionRun {
    /// Start a new mission run under the supplied blueprint + budget.
    /// Ledger starts at zero; log is empty.
    #[must_use]
    pub fn new(blueprint_id: AgentBlueprintId, spec: BudgetSpec) -> Self {
        Self {
            blueprint_id,
            gate: BudgetGate::new(spec),
            ledger: BudgetLedger::default(),
            log: RunEventLog::new(),
        }
    }

    /// Append a non-tool typed `AgentEvent` to the run log. Returns
    /// the assigned ordinal.
    ///
    /// Tool calls must use [`Self::admit_and_record_tool_call`] so
    /// every invocation receives an ACS admission verdict and proof
    /// before it can enter the typed RunEventLog.
    pub fn record_event(&mut self, event: AgentEvent) -> u64 {
        match event {
            AgentEvent::ToolCall { call } => self.log.append_event(AgentEvent::Error {
                kind: AgentEventErrorKind::CapabilityDenied,
                message: format!(
                    "tool call {} requires ACS admission via admit_and_record_tool_call",
                    call.name
                ),
            }),
            event => self.log.append_event(event),
        }
    }

    /// ACS-admit a tool call, write the ACS verdict to the audit
    /// OpLog, sign a SCOPE-Rex admission proof, then append the typed
    /// `AgentEvent::ToolCall` row. If ACS blocks the call, the audit
    /// record remains in the OpLog and no tool row is appended.
    pub fn admit_and_record_tool_call<K: SigningKey>(
        &mut self,
        call: ToolCall,
        sink: &ACSRunEventLogSink<'_>,
        policy: &ACSPolicy,
        now_ms: i64,
        signing_key: &K,
    ) -> Result<ToolCallAdmissionHandoff, ToolCallAdmissionError> {
        call.validate()?;
        let submitted_at_ms = now_ms.max(0);
        let input = ACSAdmissionInput {
            request_id: tool_call_request_id(&call, submitted_at_ms, sink.recorded_event_count()),
            payload: ACSAdmissionPayload::ToolAction {
                request: ACSToolActionRequest {
                    tool_name: call.name.clone(),
                    target: tool_call_target(&call),
                    mutation_envelope_id: None,
                },
            },
            submitted_at_ms,
            risk: ACSRiskVector::neutral(),
            granted_capabilities: policy.required_for(ACSOperationKind::ToolAction),
        };
        let decision = sink.admit_and_record(&input, policy, now_ms)?;
        if !decision.verdict.allows_durable_commit() {
            return Err(ToolCallAdmissionError::Blocked {
                verdict: decision.verdict,
                record_id: decision.audit_record.record_id,
                reason: decision.audit_record.reason,
            });
        }

        let admission_proof =
            SCOPERexAdmissionProof::signed_from_record(&decision.audit_record, signing_key)?;
        admission_proof.verify_against_record(&decision.audit_record, signing_key)?;
        let event_ordinal = self
            .log
            .append_event(AgentEvent::ToolCall { call: call.clone() });
        Ok(ToolCallAdmissionHandoff {
            event_ordinal,
            call,
            admission_proof,
            audit_record: decision.audit_record,
        })
    }

    /// Atomic budget gate + sealed-mutation record. On success, BOTH
    /// `RunEventEntry::SealedMutation` AND `RunEventEntry::LedgerSnapshot`
    /// are appended (in that order). On budget rejection, NEITHER is
    /// appended and the internal ledger is left untouched.
    ///
    /// Returns `(sealed_mutation_ordinal, ledger_snapshot_ordinal)` so
    /// callers can cross-reference the pair in audit code.
    pub fn gate_and_record_sealed_mutation(
        &mut self,
        capability_hash: Hash,
        debit: BudgetDebit,
    ) -> Result<(u64, u64), BudgetError> {
        let next_ledger = self.gate.check_and_debit(self.ledger, debit)?;
        // Only after the gate accepts do we mutate state. If
        // `append_sealed_mutation` or `append_ledger_snapshot` ever
        // become fallible, this function should roll back the ledger
        // update before returning — currently both are infallible.
        self.ledger = next_ledger;
        let sealed_ord = self.log.append_sealed_mutation(capability_hash, debit);
        let snapshot_ord = self.log.append_ledger_snapshot(self.ledger);
        Ok((sealed_ord, snapshot_ord))
    }

    /// Read-only view of the current ledger. Useful for progress UI
    /// before `finalize` is called.
    #[must_use]
    pub fn ledger(&self) -> BudgetLedger {
        self.ledger
    }

    /// Read-only view of the active gate's spec.
    #[must_use]
    pub fn budget_spec(&self) -> BudgetSpec {
        self.gate.spec()
    }

    /// Read-only view of the run log. For replay / audit / inspection.
    #[must_use]
    pub fn run_event_log(&self) -> &RunEventLog {
        &self.log
    }

    /// Borrowed view of the blueprint id this run was started under.
    #[must_use]
    pub const fn blueprint_id(&self) -> &AgentBlueprintId {
        &self.blueprint_id
    }

    /// Terminal: produce the [`AnswerPacket`] for this run. Consumes
    /// `self` so a finalized run cannot be appended to (the executor
    /// gatekeeper that enforces "no events after Stop" lives one layer
    /// above; this just ensures the packet captures the log's final
    /// state).
    #[must_use]
    pub fn finalize(
        self,
        final_text: String,
        citations: Vec<Citation>,
        stop_reason: StopReason,
    ) -> AnswerPacket {
        AnswerPacket::emit(
            self.blueprint_id,
            final_text,
            citations,
            stop_reason,
            self.ledger,
            &self.log,
        )
    }

    /// Terminal with explicit `thinking_digest`. Mirrors
    /// [`AnswerPacket::emit_with_thinking`] — callers whose executor
    /// preserved thinking bytes use this path so the digest flows into
    /// the packet.
    #[must_use]
    pub fn finalize_with_thinking(
        self,
        final_text: String,
        citations: Vec<Citation>,
        stop_reason: StopReason,
        thinking_digest: Hash,
    ) -> AnswerPacket {
        AnswerPacket::emit_with_thinking(
            self.blueprint_id,
            final_text,
            citations,
            stop_reason,
            self.ledger,
            &self.log,
            thinking_digest,
        )
    }
}

// ─── Terminal S — Hyperdynamic Schema Loop hook ─────────────────────
//
// Per `docs/PHASE_2_TERMINAL_PROMPTS_2026_05_23.md` §Terminal S, every
// typed model output must pass through ≥ 1 loop kind before reaching
// `RunEventLog`. The minimal hook is two free helpers that the model
// adapter (one layer above `MissionRun`) calls BEFORE invoking
// `record_event` / `admit_and_record_tool_call`:
//
// - `gate_admission_draft_through_loop` — wraps the existing
//   `AdmissionRepairLoop` with the `RepairBudget::DEFAULT` budget so
//   tool-call drafts whose ACS verdict is `Defer` get a bounded
//   number of `re_emit` retries before being quarantined.
//
// - `gate_witness_draft_through_loop` — same shape, generic over the
//   witness payload. Today the F-ULP backend lowers into
//   `WitnessState::{Verified, RepairableMismatch, Invalid}`; tomorrow
//   any future proof backend (weight-bit replay, etc.) lowers into
//   the same enum.
//
// These helpers intentionally do NOT change `MissionRun`'s surface —
// the existing `admit_and_record_tool_call` / `record_event` paths
// remain the only writers to `RunEventLog`. The Terminal S contract
// is that the adapter MUST call exactly one of these helpers before
// the existing writers, and the falsifier
// `F-HyperdynamicLoop-Bounded` (`agent_core/src/bin/
// falsify_hyperdynamic_loop_bounded.rs`) proves the bounded-retry
// invariant under the strongest adversarial shape.
//
// The `_through_loop` suffix is the canonical marker so a future
// `cargo doc` or `grep` pass can confirm every adapter call site is
// gated. Quarantine outcomes flow into the same `RunEventEntry`
// channel ACS terminal verdicts already populate — the Provenance
// Console renders them without further changes.

use crate::hyperdynamic_loop::{
    run_loop, AdmissionDraft, AdmissionRepairLoop, LoopCounters, RepairBudget, RepairOutcome,
    WitnessDraft, WitnessRepairLoop, WitnessState,
};

/// Gate a tool-call admission draft through `AdmissionRepairLoop`.
/// `re_emit` is the adapter's "rerun the ACS admission with tightened
/// risk parameters" closure — on `Defer` the loop calls it up to
/// `budget.max_retries` times; on `Allow / AllowWithWarning` it
/// accepts; on `Quarantine / Reject` it terminates without invoking
/// `re_emit`.
///
/// The returned `RepairOutcome` is the canonical input shape the
/// adapter pattern-matches against to decide whether to call
/// `MissionRun::admit_and_record_tool_call` (Accept) or to surface
/// a quarantine reason into the Provenance Console (Quarantined /
/// QuarantinedBudgetExhausted).
pub fn gate_admission_draft_through_loop<F>(
    initial: AdmissionDraft,
    budget: RepairBudget,
    counters: &mut LoopCounters,
    re_emit: F,
) -> RepairOutcome<AdmissionDraft>
where
    F: FnMut(&AdmissionDraft, &str) -> AdmissionDraft,
{
    let loop_impl = AdmissionRepairLoop::new();
    // AdmissionRepairLoop carries `Error = Infallible`, so `run_loop`
    // is total — the `expect` documents (and is enforced by the
    // type system) that this path can never return Err.
    run_loop(&loop_impl, initial, budget, counters, re_emit)
        .expect("AdmissionRepairLoop::check is Infallible")
}

/// Gate a witness draft through `WitnessRepairLoop<T>`. The proof
/// backend lowers its replay error into `WitnessState` before
/// invoking this helper, so the loop body remains agnostic to the
/// concrete proof shape (F-ULP today, weight-bit replay tomorrow).
pub fn gate_witness_draft_through_loop<T, F>(
    initial: WitnessDraft<T>,
    budget: RepairBudget,
    counters: &mut LoopCounters,
    re_emit: F,
) -> RepairOutcome<WitnessDraft<T>>
where
    T: Clone,
    F: FnMut(&WitnessDraft<T>, &str) -> WitnessDraft<T>,
{
    let loop_impl = WitnessRepairLoop::<T>::new();
    run_loop(&loop_impl, initial, budget, counters, re_emit)
        .expect("WitnessRepairLoop::check is Infallible")
}

#[cfg(test)]
mod hyperdynamic_loop_hook_tests {
    use super::{
        gate_admission_draft_through_loop, gate_witness_draft_through_loop,
    };
    use crate::acs_admission::ACSAdmissionVerdict;
    use crate::hyperdynamic_loop::{
        AdmissionDraft, LoopCounters, RepairBudget, RepairOutcome, WitnessDraft, WitnessState,
    };

    #[test]
    fn admission_hook_accepts_allow_verdict_without_re_emit() {
        let mut counters = LoopCounters::new();
        let mut re_emit_calls = 0;
        let outcome = gate_admission_draft_through_loop(
            AdmissionDraft::new(ACSAdmissionVerdict::Allow, "allow"),
            RepairBudget::DEFAULT,
            &mut counters,
            |prev, _hint| {
                re_emit_calls += 1;
                prev.clone()
            },
        );
        assert!(matches!(outcome, RepairOutcome::Accepted { .. }));
        assert_eq!(re_emit_calls, 0);
        assert_eq!(counters.accepted, 1);
    }

    #[test]
    fn admission_hook_repairs_defer_then_allow() {
        let mut counters = LoopCounters::new();
        let outcome = gate_admission_draft_through_loop(
            AdmissionDraft::new(ACSAdmissionVerdict::Defer, "stuck"),
            RepairBudget::DEFAULT,
            &mut counters,
            |_prev, _hint| AdmissionDraft::new(ACSAdmissionVerdict::Allow, "repaired"),
        );
        match outcome {
            RepairOutcome::Accepted { packet, repairs } => {
                assert_eq!(packet.verdict, ACSAdmissionVerdict::Allow);
                assert_eq!(repairs, 1);
            }
            other => panic!("expected accepted, got {other:?}"),
        }
        assert_eq!(counters.accepted, 1);
        assert_eq!(counters.repaired, 1);
    }

    #[test]
    fn admission_hook_quarantines_persistent_defer_at_budget() {
        let mut counters = LoopCounters::new();
        let outcome = gate_admission_draft_through_loop(
            AdmissionDraft::new(ACSAdmissionVerdict::Defer, "stuck"),
            RepairBudget::tightened(2, std::time::Duration::from_millis(500), 64),
            &mut counters,
            |prev, _hint| prev.clone(),
        );
        assert!(matches!(
            outcome,
            RepairOutcome::QuarantinedBudgetExhausted { repairs: 2, .. }
        ));
        assert_eq!(counters.quarantined, 1);
    }

    #[test]
    fn admission_hook_terminates_immediately_on_reject() {
        let mut counters = LoopCounters::new();
        let mut re_emit_calls = 0;
        let outcome = gate_admission_draft_through_loop(
            AdmissionDraft::new(ACSAdmissionVerdict::Reject, "policy"),
            RepairBudget::DEFAULT,
            &mut counters,
            |prev, _hint| {
                re_emit_calls += 1;
                prev.clone()
            },
        );
        match outcome {
            RepairOutcome::Quarantined { reason, repairs } => {
                assert!(reason.starts_with("acs_terminal:reject"));
                assert_eq!(repairs, 0);
            }
            other => panic!("expected explicit quarantine, got {other:?}"),
        }
        assert_eq!(re_emit_calls, 0);
        assert_eq!(counters.quarantined, 1);
    }

    #[test]
    fn witness_hook_accepts_verified_draft() {
        let mut counters = LoopCounters::new();
        let outcome = gate_witness_draft_through_loop::<u32, _>(
            WitnessDraft::new(42u32, WitnessState::verified()),
            RepairBudget::DEFAULT,
            &mut counters,
            |prev, _hint| prev.clone(),
        );
        match outcome {
            RepairOutcome::Accepted { packet, repairs } => {
                assert_eq!(packet.payload, 42);
                assert_eq!(repairs, 0);
            }
            other => panic!("expected accepted, got {other:?}"),
        }
    }

    #[test]
    fn witness_hook_quarantines_invalid_witness_with_zero_repairs() {
        let mut counters = LoopCounters::new();
        let outcome = gate_witness_draft_through_loop::<u32, _>(
            WitnessDraft::new(0u32, WitnessState::invalid("hardware_pin_mismatch")),
            RepairBudget::DEFAULT,
            &mut counters,
            |prev, _hint| prev.clone(),
        );
        match outcome {
            RepairOutcome::Quarantined { reason, repairs } => {
                assert!(reason.contains("hardware_pin_mismatch"));
                assert_eq!(repairs, 0);
            }
            other => panic!("expected explicit quarantine, got {other:?}"),
        }
        assert_eq!(counters.total_repair_attempts, 0);
    }

    #[test]
    fn witness_hook_repairs_then_verifies_within_budget() {
        let mut counters = LoopCounters::new();
        let outcome = gate_witness_draft_through_loop::<u32, _>(
            WitnessDraft::new(
                1u32,
                WitnessState::repairable("budget_wall_clock_ms_exceeded"),
            ),
            RepairBudget::DEFAULT,
            &mut counters,
            |prev, _hint| {
                let mut next = prev.clone();
                next.state = WitnessState::verified();
                next.payload += 1;
                next
            },
        );
        match outcome {
            RepairOutcome::Accepted { packet, repairs } => {
                assert_eq!(packet.payload, 2);
                assert_eq!(packet.state, WitnessState::verified());
                assert_eq!(repairs, 1);
            }
            other => panic!("expected accepted, got {other:?}"),
        }
    }

    #[test]
    fn hook_helpers_carry_through_loop_suffix_for_grep() {
        // Cross-surface invariant: the hook helpers' names end in
        // `_through_loop` so an auditor's grep covers every adapter
        // call site that gates a typed packet through the
        // Hyperdynamic Schema Loop.
        let admission_name = stringify!(gate_admission_draft_through_loop);
        let witness_name = stringify!(gate_witness_draft_through_loop);
        assert!(admission_name.ends_with("_through_loop"));
        assert!(witness_name.ends_with("_through_loop"));
    }
}
