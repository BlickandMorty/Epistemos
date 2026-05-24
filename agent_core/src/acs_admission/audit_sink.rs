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

use super::admit::*;
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
use super::*;

pub trait ACSAuditSink {
    fn record(&self, record: ACSAuditRecord) -> Result<(), ACSAuditError>;
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ACSAuditError {
    SinkUnavailable,
    EncodeRecord,
    InvalidRunEventLogChain {
        record_id: String,
    },
    AuditLogGap {
        record_id: String,
    },
    NonMonotonicAuditLog {
        field: &'static str,
        record_id: String,
    },
    NonMonotonicVerdict {
        field: &'static str,
        record_id: String,
    },
    DuplicateRecord {
        record_id: String,
    },
    CorruptRecord {
        field: &'static str,
        record_id: String,
    },
}

impl ACSAuditError {
    pub const fn cause(&self) -> &'static str {
        match self {
            Self::SinkUnavailable => "acs_audit_sink_unavailable",
            Self::EncodeRecord => "acs_audit_record_encode_failed",
            Self::InvalidRunEventLogChain { .. } => "invalid_run_event_log_chain",
            Self::AuditLogGap { .. } => "acs_audit_log_gap",
            Self::NonMonotonicAuditLog { .. } => "non_monotonic_acs_audit_log",
            Self::NonMonotonicVerdict { .. } => "non_monotonic_acs_verdict",
            Self::DuplicateRecord { .. } => "duplicate_acs_audit_record",
            Self::CorruptRecord { .. } => "corrupt_acs_audit_record",
        }
    }

    pub const fn field(&self) -> Option<&'static str> {
        match self {
            Self::InvalidRunEventLogChain { .. } | Self::AuditLogGap { .. } => {
                Some("run_event_log")
            }
            Self::NonMonotonicAuditLog { field, .. } => Some(field),
            Self::NonMonotonicVerdict { field, .. } => Some(field),
            Self::DuplicateRecord { .. } => Some("record_id"),
            Self::CorruptRecord { field, .. } => Some(field),
            Self::SinkUnavailable | Self::EncodeRecord => None,
        }
    }

    pub fn record_id(&self) -> Option<&str> {
        match self {
            Self::DuplicateRecord { record_id } => Some(record_id.as_str()),
            Self::NonMonotonicAuditLog { record_id, .. } => Some(record_id.as_str()),
            Self::NonMonotonicVerdict { record_id, .. } => Some(record_id.as_str()),
            Self::CorruptRecord { record_id, .. } => Some(record_id.as_str()),
            Self::AuditLogGap { record_id } => Some(record_id.as_str()),
            Self::InvalidRunEventLogChain { record_id } => Some(record_id.as_str()),
            Self::SinkUnavailable | Self::EncodeRecord => None,
        }
    }
}

#[derive(Debug)]
pub struct ACSRunEventLogSink<'a> {
    run_event_log: &'a OpLog,
}

impl<'a> ACSRunEventLogSink<'a> {
    pub const fn new(run_event_log: &'a OpLog) -> Self {
        Self { run_event_log }
    }

    pub fn admit_and_record(
        &self,
        input: &ACSAdmissionInput,
        policy: &ACSPolicy,
        now_ms: i64,
    ) -> Result<ACSAdmissionDecision, ACSAuditError> {
        super::admit::admit_and_record(input, policy, now_ms, self)
    }

    pub fn recorded_event_count(&self) -> usize {
        self.run_event_log.len()
    }
}

impl ACSAuditSink for ACSRunEventLogSink<'_> {
    fn record(&self, record: ACSAuditRecord) -> Result<(), ACSAuditError> {
        let chain_report = self.run_event_log.verify_chain(None);
        if !chain_report.valid {
            return Err(acs_audit_chain_error(record.record_id, &chain_report));
        }
        let record_id = record.record_id.clone();
        record
            .validate()
            .map_err(|err| ACSAuditError::CorruptRecord {
                field: err.field(),
                record_id: record_id.clone(),
            })?;
        let node_id = record.record_id.clone();
        if let Some(error) = run_event_log_corrupt_acs_record(self.run_event_log) {
            return Err(error);
        }
        if run_event_log_contains_acs_record(self.run_event_log, &node_id) {
            return Err(ACSAuditError::DuplicateRecord { record_id: node_id });
        }
        if run_event_log_contains_stricter_same_request_verdict(self.run_event_log, &record) {
            return Err(ACSAuditError::NonMonotonicVerdict {
                field: "verdict",
                record_id: node_id,
            });
        }
        if run_event_log_max_acs_emitted_at_ms(self.run_event_log)
            .is_some_and(|emitted_at_ms| record.emitted_at_ms < emitted_at_ms)
        {
            return Err(ACSAuditError::NonMonotonicAuditLog {
                field: "emitted_at_ms",
                record_id: node_id,
            });
        }
        let value = serde_json::to_value(record).map_err(|_| ACSAuditError::EncodeRecord)?;
        self.run_event_log.append(OpPayload::PropSet {
            node_id,
            key: ACS_AUDIT_RUN_EVENT_KEY.to_string(),
            value,
        });
        Ok(())
    }
}

pub(crate) fn acs_audit_chain_error(
    record_id: String,
    report: &crate::oplog::OpLogChainVerificationReport,
) -> ACSAuditError {
    if report.failure_reason.as_deref() == Some("seq_gap") {
        ACSAuditError::AuditLogGap { record_id }
    } else {
        ACSAuditError::InvalidRunEventLogChain { record_id }
    }
}

pub(crate) fn run_event_log_contains_acs_record(run_event_log: &OpLog, record_id: &str) -> bool {
    run_event_log
        .iter_all()
        .into_iter()
        .any(|op| match op.payload {
            OpPayload::PropSet {
                node_id,
                key,
                value,
            } => {
                key == ACS_AUDIT_RUN_EVENT_KEY
                    && (node_id == record_id
                        || audit_record_value_id(&value)
                            .is_some_and(|value_id| value_id == record_id))
            }
            _ => false,
        })
}

pub(crate) fn run_event_log_corrupt_acs_record(run_event_log: &OpLog) -> Option<ACSAuditError> {
    run_event_log
        .iter_all()
        .into_iter()
        .find_map(|op| match op.payload {
            OpPayload::PropSet {
                node_id,
                key,
                value,
            } if key == ACS_AUDIT_RUN_EVENT_KEY => {
                let fallback_record_id = audit_record_value_id(&value)
                    .unwrap_or(&node_id)
                    .to_string();
                let malformed_field = audit_record_value_malformed_field(&value);
                let record = match serde_json::from_value::<ACSAuditRecord>(value) {
                    Ok(record) => record,
                    Err(_) => {
                        return Some(ACSAuditError::CorruptRecord {
                            field: malformed_field.unwrap_or("record"),
                            record_id: fallback_record_id,
                        });
                    }
                };
                record
                    .validate()
                    .err()
                    .map(|err| ACSAuditError::CorruptRecord {
                        field: err.field(),
                        record_id: err.record_id().unwrap_or(&fallback_record_id).to_string(),
                    })
            }
            _ => None,
        })
}

pub(crate) fn audit_record_value_malformed_field(
    value: &serde_json::Value,
) -> Option<&'static str> {
    let serde_json::Value::Object(object) = value else {
        return Some("record");
    };
    for field in object.keys() {
        if !matches!(
            field.as_str(),
            "record_id"
                | "request_id"
                | "policy_id"
                | "policy_version"
                | "operation"
                | "verdict"
                | "reason"
                | "risk_max"
                | "emitted_at_ms"
        ) {
            return Some("record");
        }
    }
    if !object
        .get("record_id")
        .is_some_and(serde_json::Value::is_string)
    {
        return Some("record_id");
    }
    if !object
        .get("request_id")
        .is_some_and(serde_json::Value::is_string)
    {
        return Some("request_id");
    }
    if !object
        .get("policy_id")
        .is_some_and(serde_json::Value::is_string)
    {
        return Some("policy_id");
    }
    if !object
        .get("policy_version")
        .and_then(serde_json::Value::as_u64)
        .is_some_and(|value| value <= u32::MAX as u64)
    {
        return Some("policy_version");
    }
    if !object
        .get("operation")
        .and_then(serde_json::Value::as_str)
        .is_some_and(is_canonical_operation_kind_code)
    {
        return Some("operation");
    }
    if !object
        .get("verdict")
        .and_then(serde_json::Value::as_str)
        .is_some_and(is_canonical_admission_verdict_code)
    {
        return Some("verdict");
    }
    if !object
        .get("reason")
        .is_some_and(serde_json::Value::is_string)
    {
        return Some("reason");
    }
    if !object
        .get("risk_max")
        .and_then(serde_json::Value::as_f64)
        .is_some_and(|value| value.is_finite() && (0.0..=1.0).contains(&value))
    {
        return Some("risk_max");
    }
    if !object
        .get("emitted_at_ms")
        .and_then(serde_json::Value::as_i64)
        .is_some_and(|value| value >= 0)
    {
        return Some("emitted_at_ms");
    }
    None
}

pub(crate) fn run_event_log_max_acs_emitted_at_ms(run_event_log: &OpLog) -> Option<i64> {
    run_event_log
        .iter_all()
        .into_iter()
        .filter_map(|op| match op.payload {
            OpPayload::PropSet { key, value, .. } if key == ACS_AUDIT_RUN_EVENT_KEY => {
                serde_json::from_value::<ACSAuditRecord>(value)
                    .ok()
                    .map(|record| record.emitted_at_ms)
            }
            _ => None,
        })
        .max()
}

pub(crate) fn run_event_log_contains_stricter_same_request_verdict(
    run_event_log: &OpLog,
    record: &ACSAuditRecord,
) -> bool {
    run_event_log
        .iter_all()
        .into_iter()
        .any(|op| match op.payload {
            OpPayload::PropSet { key, value, .. } if key == ACS_AUDIT_RUN_EVENT_KEY => {
                serde_json::from_value::<ACSAuditRecord>(value)
                    .ok()
                    .is_some_and(|existing| {
                        existing.request_id == record.request_id
                            && existing.verdict.severity_rank() > record.verdict.severity_rank()
                    })
            }
            _ => false,
        })
}

/// R4 (2026-05-23): walk every ACS admission verdict in `run_event_log`
/// and return them in oplog (chronological by `seq`) order.
///
/// The diagnostics-facing read counterpart to `admit_and_record` +
/// [`ACSRunEventLogSink::record`]. A Settings → Diagnostics row that
/// wants to surface "last N admission verdicts" calls this and then
/// sorts / filters / pages in caller-owned code without
/// re-implementing the oplog walk.
///
/// **Atomicity**: the walk bails on the first malformed or invalid
/// record so the diagnostics surface cannot render a half-truth.
/// Callers that want best-effort enumeration (skip-bad-records mode)
/// should filter at their own seam — the public contract here is
/// "every record or nothing."
///
/// Errors mirror [`resolve_acs_audit_record`]:
/// - `InvalidRunEventLogChain` / `AuditLogGap` on chain failure
/// - `CorruptRecord` on a malformed audit payload
///
/// The `record_id` field on chain errors is the empty string because
/// the snapshot has no single "target" record — the failure is at
/// the log-chain level, not at any one entry.
pub fn snapshot_acs_audit_records(
    run_event_log: &OpLog,
) -> Result<Vec<ACSAuditRecord>, ACSAuditLookupError> {
    let chain_report = run_event_log.verify_chain(None);
    if !chain_report.valid {
        return Err(acs_audit_lookup_chain_error(String::new(), &chain_report));
    }
    let mut records: Vec<ACSAuditRecord> = Vec::new();
    for op in run_event_log.iter_all() {
        let OpPayload::PropSet {
            node_id,
            key,
            value,
        } = op.payload
        else {
            continue;
        };
        if key != ACS_AUDIT_RUN_EVENT_KEY {
            continue;
        }
        let fallback_record_id = audit_record_value_id(&value)
            .map(str::to_string)
            .unwrap_or_else(|| node_id.clone());
        let malformed_field = audit_record_value_malformed_field(&value);
        let record: ACSAuditRecord =
            serde_json::from_value(value).map_err(|_| ACSAuditLookupError::CorruptRecord {
                field: malformed_field.unwrap_or("record"),
                record_id: fallback_record_id.clone(),
            })?;
        record
            .validate()
            .map_err(|err| ACSAuditLookupError::CorruptRecord {
                field: err.field(),
                record_id: err.record_id().unwrap_or(&fallback_record_id).to_string(),
            })?;
        records.push(record);
    }
    Ok(records)
}

pub fn resolve_acs_audit_record(
    run_event_log: &OpLog,
    record_id: &AuditRecordId,
) -> Result<ACSAuditRecord, ACSAuditLookupError> {
    let chain_report = run_event_log.verify_chain(None);
    if !chain_report.valid {
        return Err(acs_audit_lookup_chain_error(
            record_id.0.clone(),
            &chain_report,
        ));
    }
    if record_id.validate().is_err() {
        return Err(ACSAuditLookupError::InvalidRecordId {
            record_id: record_id.0.clone(),
        });
    }

    let mut matched_count = 0usize;
    let mut aliased_count = 0usize;
    let mut newest_value = None;
    for op in run_event_log.iter_all().into_iter().rev() {
        let OpPayload::PropSet {
            node_id,
            key,
            value,
        } = op.payload
        else {
            continue;
        };
        if key != ACS_AUDIT_RUN_EVENT_KEY {
            continue;
        }
        if node_id != record_id.0 {
            if audit_record_value_id(&value).is_some_and(|value_id| value_id == record_id.0) {
                aliased_count += 1;
            }
            continue;
        }
        matched_count += 1;
        if newest_value.is_none() {
            newest_value = Some(value);
        }
    }

    let value = match newest_value {
        Some(value) => value,
        None if aliased_count > 0 => {
            return Err(ACSAuditLookupError::DuplicateRecord {
                record_id: record_id.0.clone(),
            });
        }
        None => {
            return Err(ACSAuditLookupError::NotFound {
                record_id: record_id.0.clone(),
            });
        }
    };
    if !value.is_object() {
        if matched_count > 1 {
            return Err(ACSAuditLookupError::DuplicateRecord {
                record_id: record_id.0.clone(),
            });
        }
        return Err(ACSAuditLookupError::DecodeRecord {
            record_id: record_id.0.clone(),
        });
    }
    let malformed_field = audit_record_value_malformed_field(&value);
    let record: ACSAuditRecord =
        serde_json::from_value(value).map_err(|_| ACSAuditLookupError::CorruptRecord {
            field: malformed_field.unwrap_or("record"),
            record_id: record_id.0.clone(),
        })?;
    record
        .validate()
        .map_err(|err| ACSAuditLookupError::CorruptRecord {
            field: err.field(),
            record_id: record_id.0.clone(),
        })?;
    if record.record_id != record_id.0 {
        return Err(ACSAuditLookupError::CorruptRecord {
            field: "record_id",
            record_id: record_id.0.clone(),
        });
    }
    if aliased_count > 0 {
        return Err(ACSAuditLookupError::DuplicateRecord {
            record_id: record_id.0.clone(),
        });
    }
    if matched_count > 1 {
        return Err(ACSAuditLookupError::DuplicateRecord {
            record_id: record_id.0.clone(),
        });
    }
    Ok(record)
}

pub(crate) fn acs_audit_lookup_chain_error(
    record_id: String,
    report: &crate::oplog::OpLogChainVerificationReport,
) -> ACSAuditLookupError {
    if report.failure_reason.as_deref() == Some("seq_gap") {
        ACSAuditLookupError::AuditLogGap { record_id }
    } else {
        ACSAuditLookupError::InvalidRunEventLogChain { record_id }
    }
}

pub(crate) fn audit_record_value_id(value: &serde_json::Value) -> Option<&str> {
    value.get("record_id").and_then(serde_json::Value::as_str)
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ACSAuditLookupError {
    InvalidRecordId {
        record_id: String,
    },
    InvalidRunEventLogChain {
        record_id: String,
    },
    NotFound {
        record_id: String,
    },
    DuplicateRecord {
        record_id: String,
    },
    DecodeRecord {
        record_id: String,
    },
    CorruptRecord {
        field: &'static str,
        record_id: String,
    },
    AuditLogGap {
        record_id: String,
    },
}

impl ACSAuditLookupError {
    pub const fn cause(&self) -> &'static str {
        match self {
            Self::InvalidRecordId { .. } => "invalid_audit_record_id",
            Self::InvalidRunEventLogChain { .. } => "invalid_run_event_log_chain",
            Self::NotFound { .. } => "acs_audit_record_not_found",
            Self::DuplicateRecord { .. } => "duplicate_acs_audit_record",
            Self::DecodeRecord { .. } => "acs_audit_record_decode_failed",
            Self::CorruptRecord { .. } => "corrupt_acs_audit_record",
            Self::AuditLogGap { .. } => "acs_audit_log_gap",
        }
    }

    pub const fn field(&self) -> Option<&'static str> {
        match self {
            Self::InvalidRunEventLogChain { .. } | Self::AuditLogGap { .. } => {
                Some("run_event_log")
            }
            Self::InvalidRecordId { .. } | Self::NotFound { .. } | Self::DuplicateRecord { .. } => {
                Some("record_id")
            }
            Self::DecodeRecord { .. } => Some("record"),
            Self::CorruptRecord { field, .. } => Some(field),
        }
    }

    pub fn record_id(&self) -> Option<&str> {
        match self {
            Self::InvalidRecordId { record_id } => Some(record_id.as_str()),
            Self::NotFound { record_id } => Some(record_id.as_str()),
            Self::DuplicateRecord { record_id } => Some(record_id.as_str()),
            Self::DecodeRecord { record_id } => Some(record_id.as_str()),
            Self::CorruptRecord { record_id, .. } => Some(record_id.as_str()),
            Self::InvalidRunEventLogChain { record_id } => Some(record_id.as_str()),
            Self::AuditLogGap { record_id } => Some(record_id.as_str()),
        }
    }
}

#[derive(Debug, Default)]
pub struct InMemoryACSAuditSink {
    records: std::sync::Mutex<Vec<ACSAuditRecord>>,
}

impl InMemoryACSAuditSink {
    pub fn records(&self) -> Result<Vec<ACSAuditRecord>, ACSAuditError> {
        self.records
            .lock()
            .map(|records| records.clone())
            .map_err(|_| ACSAuditError::SinkUnavailable)
    }
}

impl ACSAuditSink for InMemoryACSAuditSink {
    fn record(&self, record: ACSAuditRecord) -> Result<(), ACSAuditError> {
        let record_id = record.record_id.clone();
        record
            .validate()
            .map_err(|err| ACSAuditError::CorruptRecord {
                field: err.field(),
                record_id,
            })?;
        let mut records = self
            .records
            .lock()
            .map_err(|_| ACSAuditError::SinkUnavailable)?;
        if records
            .iter()
            .any(|existing| existing.record_id == record.record_id)
        {
            return Err(ACSAuditError::DuplicateRecord {
                record_id: record.record_id,
            });
        }
        if records.iter().any(|existing| {
            existing.request_id == record.request_id
                && existing.verdict.severity_rank() > record.verdict.severity_rank()
        }) {
            return Err(ACSAuditError::NonMonotonicVerdict {
                field: "verdict",
                record_id: record.record_id,
            });
        }
        if records
            .last()
            .is_some_and(|existing| record.emitted_at_ms < existing.emitted_at_ms)
        {
            return Err(ACSAuditError::NonMonotonicAuditLog {
                field: "emitted_at_ms",
                record_id: record.record_id,
            });
        }
        records.push(record);
        Ok(())
    }
}
