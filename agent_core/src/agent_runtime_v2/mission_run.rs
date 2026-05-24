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
