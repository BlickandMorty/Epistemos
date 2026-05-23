#![allow(unused_imports)]

use serde::{Deserialize, Serialize};

use crate::{
    artifacts::ArtifactRef,
    effect::receipt::{Capability, SigningKey},
    mutations::{
        BlockRef, MutationActor, MutationEnvelope, MutationStatus, RelationChange, Reversibility,
        Sensitivity, SourceOp,
    },
    oplog::{OpLog, OpPayload},
    provenance::ledger::{Claim, ClaimKind, ClaimStatus},
    scope_rex::{
        answer_packet::{AnswerPacket, VrmLabel},
        residency::{route as route_residency, Residency},
    },
};

use super::*;
use super::audit_sink::*;
use super::common::*;
use super::decision::*;
use super::input::*;
use super::policy::*;
use super::proof::*;
use super::requests::*;
use super::risk::*;
use super::validation::*;
use super::verdict::*;
use super::wire::*;

pub fn admit_and_log(
    input: &ACSAdmissionInput,
    policy: &ACSPolicy,
    now_ms: i64,
    audit_log: &mut Vec<ACSAuditRecord>,
) -> ACSAdmissionDecision {
    let decision = admit(input, policy, now_ms);
    audit_log.push(decision.audit_record.clone());
    decision
}

pub fn admit_and_record<S: ACSAuditSink + ?Sized>(
    input: &ACSAdmissionInput,
    policy: &ACSPolicy,
    now_ms: i64,
    sink: &S,
) -> Result<ACSAdmissionDecision, ACSAuditError> {
    let decision = admit(input, policy, now_ms);
    sink.record(decision.audit_record.clone())?;
    Ok(decision)
}

pub fn admit(input: &ACSAdmissionInput, policy: &ACSPolicy, now_ms: i64) -> ACSAdmissionDecision {
    if now_ms < 0 {
        return decision(
            input,
            policy,
            0,
            ACSAdmissionVerdict::Reject,
            "invalid_admission_time",
        );
    }

    if let Err(err) = input.validate() {
        return decision(
            input,
            policy,
            now_ms,
            ACSAdmissionVerdict::Reject,
            err.cause(),
        );
    }

    if input.submitted_at_ms > now_ms {
        return decision(
            input,
            policy,
            now_ms,
            ACSAdmissionVerdict::Reject,
            "future_admission_input",
        );
    }

    if let Err(err) = policy.validate_at(now_ms) {
        return decision(
            input,
            policy,
            now_ms,
            ACSAdmissionVerdict::Reject,
            err.cause(),
        );
    }

    if has_missing_required_capability(policy, input.operation(), &input.granted_capabilities) {
        return decision(
            input,
            policy,
            now_ms,
            ACSAdmissionVerdict::Reject,
            "missing_capability",
        );
    }

    if has_capability_scope_creep(policy, input.operation(), &input.granted_capabilities) {
        return decision(
            input,
            policy,
            now_ms,
            ACSAdmissionVerdict::Reject,
            "capability_scope_creep",
        );
    }

    if input.operation().lane() == ACSLane::L2 && !input.risk.evidence_present {
        return decision(
            input,
            policy,
            now_ms,
            ACSAdmissionVerdict::Reject,
            "missing_l2_evidence",
        );
    }

    let verdict =
        ACSAdmissionVerdict::from_risk(&input.risk, policy.thresholds_for(input.operation()));
    decision(input, policy, now_ms, verdict, verdict.code())
}

pub(crate) fn has_missing_required_capability(
    policy: &ACSPolicy,
    operation: ACSOperationKind,
    granted_capabilities: &[Capability],
) -> bool {
    policy
        .required_for(operation)
        .iter()
        .any(|capability| !granted_capabilities.contains(capability))
        || canonical_l2_capability(operation)
            .is_some_and(|capability| !granted_capabilities.contains(&capability))
}

pub(crate) fn has_capability_scope_creep(
    policy: &ACSPolicy,
    operation: ACSOperationKind,
    granted_capabilities: &[Capability],
) -> bool {
    let required_for_operation = policy.required_for(operation);
    granted_capabilities
        .iter()
        .any(|capability| !required_for_operation.contains(capability))
}

pub(crate) fn canonical_l2_capability(operation: ACSOperationKind) -> Option<Capability> {
    match operation {
        ACSOperationKind::KernelPromotion => Some(named_capability("KernelPromote")),
        ACSOperationKind::ModelAdaptation => Some(named_capability("ModelAdapt")),
        ACSOperationKind::MutationEnvelope
        | ACSOperationKind::ActiveAssemblyPacket
        | ACSOperationKind::AnswerPacket
        | ACSOperationKind::MemoryWrite
        | ACSOperationKind::ToolAction => None,
    }
}

pub fn guard_durable_commit(record: Option<&ACSAuditRecord>) -> Result<(), ACSDurableCommitError> {
    let record = record.ok_or(ACSDurableCommitError::MissingAuditRecord)?;
    record
        .validate()
        .map_err(|err| ACSDurableCommitError::CorruptAuditRecord {
            field: err.field(),
            record_id: record.record_id.clone(),
        })?;
    if !record.verdict.allows_durable_commit() {
        return Err(ACSDurableCommitError::BlockedByVerdict {
            verdict: record.verdict,
            record_id: record.record_id.clone(),
        });
    }
    if record.operation.lane() != ACSLane::L0 {
        return Err(ACSDurableCommitError::BlockedByOperation {
            operation: record.operation,
            record_id: record.record_id.clone(),
        });
    }
    Ok(())
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ACSDurableCommitError {
    MissingAuditRecord,
    CorruptAuditRecord {
        field: &'static str,
        record_id: String,
    },
    BlockedByOperation {
        operation: ACSOperationKind,
        record_id: String,
    },
    BlockedByVerdict {
        verdict: ACSAdmissionVerdict,
        record_id: String,
    },
}

impl ACSDurableCommitError {
    pub const fn cause(&self) -> &'static str {
        match self {
            Self::MissingAuditRecord => "missing_acs_audit_record",
            Self::CorruptAuditRecord { .. } => "corrupt_acs_audit_record",
            Self::BlockedByOperation { .. } => "acs_operation_blocks_durable_commit",
            Self::BlockedByVerdict { .. } => "acs_verdict_blocks_durable_commit",
        }
    }

    pub const fn field(&self) -> Option<&'static str> {
        match self {
            Self::CorruptAuditRecord { field, .. } => Some(field),
            Self::BlockedByOperation { .. } => Some("operation"),
            Self::MissingAuditRecord | Self::BlockedByVerdict { .. } => None,
        }
    }

    pub fn record_id(&self) -> Option<&str> {
        match self {
            Self::CorruptAuditRecord { record_id, .. } => Some(record_id.as_str()),
            Self::BlockedByOperation { record_id, .. } => Some(record_id.as_str()),
            Self::BlockedByVerdict { record_id, .. } => Some(record_id.as_str()),
            Self::MissingAuditRecord => None,
        }
    }

    pub const fn verdict(&self) -> Option<ACSAdmissionVerdict> {
        match self {
            Self::BlockedByVerdict { verdict, .. } => Some(*verdict),
            Self::MissingAuditRecord
            | Self::CorruptAuditRecord { .. }
            | Self::BlockedByOperation { .. } => None,
        }
    }

    pub const fn operation(&self) -> Option<ACSOperationKind> {
        match self {
            Self::BlockedByOperation { operation, .. } => Some(*operation),
            Self::MissingAuditRecord
            | Self::CorruptAuditRecord { .. }
            | Self::BlockedByVerdict { .. } => None,
        }
    }

    pub const fn lane(&self) -> Option<ACSLane> {
        match self.operation() {
            Some(operation) => Some(operation.lane()),
            None => None,
        }
    }

    pub const fn product_lane_code(&self) -> Option<&'static str> {
        match self.lane() {
            Some(lane) => Some(lane.product_lane_code()),
            None => None,
        }
    }
}

pub(crate) fn decision(
    input: &ACSAdmissionInput,
    policy: &ACSPolicy,
    now_ms: i64,
    verdict: ACSAdmissionVerdict,
    reason: &str,
) -> ACSAdmissionDecision {
    let request_id = audit_request_id(&input.request_id);
    let policy_id = audit_policy_id(&policy.policy_id);
    ACSAdmissionDecision {
        verdict,
        audit_record: ACSAuditRecord {
            record_id: format!("acs:{}:{}", request_id, now_ms),
            request_id,
            policy_id,
            policy_version: audit_policy_version(policy.version),
            operation: input.operation(),
            verdict,
            reason: reason.to_string(),
            risk_max: audit_risk_max(&input.risk),
            emitted_at_ms: now_ms,
        },
    }
}

pub(crate) fn audit_request_id(value: &str) -> String {
    if is_canonical_audit_token(value) && !is_reserved_request_audit_token(value) {
        value.to_string()
    } else {
        malformed_audit_token(MALFORMED_REQUEST_AUDIT_PREFIX, value)
    }
}

pub(crate) fn audit_policy_id(value: &str) -> String {
    if is_canonical_audit_token(value) && !is_reserved_policy_audit_token(value) {
        value.to_string()
    } else {
        malformed_audit_token(MALFORMED_POLICY_AUDIT_PREFIX, value)
    }
}

pub(crate) fn malformed_audit_token(prefix: &str, value: &str) -> String {
    format!("{}.{}", prefix, blake3::hash(value.as_bytes()).to_hex())
}

pub(crate) fn is_reserved_malformed_audit_token(value: &str, prefix: &str) -> bool {
    value == prefix
        || value
            .strip_prefix(prefix)
            .is_some_and(|suffix| suffix.starts_with('.'))
}

pub(crate) fn is_reserved_request_audit_token(value: &str) -> bool {
    is_reserved_malformed_audit_token(value, MALFORMED_REQUEST_AUDIT_PREFIX)
        || is_reserved_malformed_audit_token(value, MALFORMED_POLICY_AUDIT_PREFIX)
}

pub(crate) fn is_reserved_policy_audit_token(value: &str) -> bool {
    is_reserved_malformed_audit_token(value, MALFORMED_POLICY_AUDIT_PREFIX)
        || is_reserved_malformed_audit_token(value, MALFORMED_REQUEST_AUDIT_PREFIX)
}

pub(crate) fn is_bare_malformed_audit_token(value: &str, prefix: &str) -> bool {
    value == prefix
}

pub(crate) fn audit_policy_version(value: u32) -> u32 {
    if value == 0 {
        1
    } else {
        value
    }
}

pub(crate) fn audit_risk_max(risk: &ACSRiskVector) -> f32 {
    if risk.validate().is_ok() {
        risk.max_axis()
    } else {
        1.0
    }
}
