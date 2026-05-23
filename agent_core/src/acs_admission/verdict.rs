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
use super::admit::*;
use super::audit_sink::*;
use super::common::*;
use super::decision::*;
use super::input::*;
use super::policy::*;
use super::proof::*;
use super::requests::*;
use super::risk::*;
use super::validation::*;
use super::wire::*;

/// Pure-data ACS admission outcome. The caller decides how to render or
/// enforce it; ACS only classifies the request.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ACSAdmissionVerdict {
    Allow,
    AllowWithWarning,
    Defer,
    Quarantine,
    Reject,
}

impl ACSAdmissionVerdict {
    pub fn from_risk(risk: &ACSRiskVector, thresholds: ACSRiskThresholds) -> Self {
        let max_axis = risk.max_axis();
        if max_axis >= thresholds.reject_at {
            Self::Reject
        } else if max_axis >= thresholds.quarantine_at {
            Self::Quarantine
        } else if max_axis >= thresholds.defer_at {
            Self::Defer
        } else if max_axis >= thresholds.warn_at || !risk.evidence_present {
            Self::AllowWithWarning
        } else {
            Self::Allow
        }
    }

    pub const fn allows_durable_commit(self) -> bool {
        matches!(self, Self::Allow | Self::AllowWithWarning)
    }

    pub const fn is_terminal(self) -> bool {
        matches!(self, Self::Quarantine | Self::Reject)
    }

    pub const fn retry_limit(self) -> Option<u8> {
        match self {
            Self::Defer => Some(3),
            Self::Allow | Self::AllowWithWarning | Self::Quarantine | Self::Reject => None,
        }
    }

    pub const fn allows_retry(self, prior_attempts: u8) -> bool {
        match self.retry_limit() {
            Some(limit) => prior_attempts < limit,
            None => false,
        }
    }

    pub const fn severity_rank(self) -> u8 {
        match self {
            Self::Allow => 0,
            Self::AllowWithWarning => 1,
            Self::Defer => 2,
            Self::Quarantine => 3,
            Self::Reject => 4,
        }
    }

    pub const fn code(self) -> &'static str {
        match self {
            Self::Allow => "allow",
            Self::AllowWithWarning => "allow_with_warning",
            Self::Defer => "defer",
            Self::Quarantine => "quarantine",
            Self::Reject => "reject",
        }
    }
}

/// One emitted admission record. This is the audit artifact for ACS verdicts;
/// callers can persist or attach it without ACS mutating durable state itself.
#[derive(Debug, Clone, PartialEq, Serialize)]
#[serde(deny_unknown_fields)]
pub struct ACSAuditRecord {
    pub record_id: String,
    pub request_id: String,
    pub policy_id: String,
    pub policy_version: u32,
    pub operation: ACSOperationKind,
    pub verdict: ACSAdmissionVerdict,
    pub reason: String,
    pub risk_max: f32,
    pub emitted_at_ms: i64,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct ACSAuditRecordWire {
    record_id: String,
    request_id: String,
    policy_id: String,
    policy_version: u32,
    operation: ACSOperationKind,
    verdict: ACSAdmissionVerdict,
    reason: String,
    risk_max: f32,
    emitted_at_ms: i64,
}

impl<'de> Deserialize<'de> for ACSAuditRecord {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: serde::Deserializer<'de>,
    {
        let value = serde_json::Value::deserialize(deserializer)?;
        require_audit_record_known_fields::<D::Error>(&value)?;
        require_audit_record_u32_field::<D::Error>(&value, "policy_version")?;
        require_audit_record_f32_field::<D::Error>(&value, "risk_max")?;
        require_audit_record_i64_field::<D::Error>(&value, "emitted_at_ms")?;
        require_audit_record_enum_field::<D::Error>(
            &value,
            "operation",
            is_canonical_operation_kind_code,
        )?;
        require_audit_record_enum_field::<D::Error>(
            &value,
            "verdict",
            is_canonical_admission_verdict_code,
        )?;
        let wire = ACSAuditRecordWire::deserialize(value).map_err(serde::de::Error::custom)?;
        let record = Self {
            record_id: wire.record_id,
            request_id: wire.request_id,
            policy_id: wire.policy_id,
            policy_version: wire.policy_version,
            operation: wire.operation,
            verdict: wire.verdict,
            reason: wire.reason,
            risk_max: wire.risk_max,
            emitted_at_ms: wire.emitted_at_ms,
        };
        record
            .validate()
            .map_err(|err| serde::de::Error::custom(acs_audit_record_decode_error(&err)))?;
        Ok(record)
    }
}

pub(crate) fn require_audit_record_known_fields<E>(value: &serde_json::Value) -> Result<(), E>
where
    E: serde::de::Error,
{
    let serde_json::Value::Object(object) = value else {
        return Ok(());
    };
    let record_id = object
        .get("record_id")
        .and_then(serde_json::Value::as_str)
        .unwrap_or_default();
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
            return Err(E::custom(format!(
                "corrupt_acs_audit_record field=audit_record.{field} record_id={record_id}"
            )));
        }
    }
    Ok(())
}

pub(crate) fn require_audit_record_u32_field<E>(
    value: &serde_json::Value,
    field: &'static str,
) -> Result<(), E>
where
    E: serde::de::Error,
{
    let serde_json::Value::Object(object) = value else {
        return Err(E::custom("corrupt_acs_audit_record field=record"));
    };
    let record_id = object
        .get("record_id")
        .and_then(serde_json::Value::as_str)
        .unwrap_or_default();
    if object
        .get(field)
        .and_then(serde_json::Value::as_u64)
        .is_some_and(|value| value <= u32::MAX as u64)
    {
        return Ok(());
    }
    Err(E::custom(format!(
        "corrupt_acs_audit_record field=audit_record.{field} record_id={record_id}"
    )))
}

pub(crate) fn require_audit_record_f32_field<E>(
    value: &serde_json::Value,
    field: &'static str,
) -> Result<(), E>
where
    E: serde::de::Error,
{
    let serde_json::Value::Object(object) = value else {
        return Err(E::custom("corrupt_acs_audit_record field=record"));
    };
    let record_id = object
        .get("record_id")
        .and_then(serde_json::Value::as_str)
        .unwrap_or_default();
    if object
        .get(field)
        .and_then(serde_json::Value::as_f64)
        .is_some_and(|value| value.is_finite() && (0.0..=1.0).contains(&value))
    {
        return Ok(());
    }
    Err(E::custom(format!(
        "corrupt_acs_audit_record field=audit_record.{field} record_id={record_id}"
    )))
}

pub(crate) fn require_audit_record_i64_field<E>(
    value: &serde_json::Value,
    field: &'static str,
) -> Result<(), E>
where
    E: serde::de::Error,
{
    let serde_json::Value::Object(object) = value else {
        return Err(E::custom("corrupt_acs_audit_record field=record"));
    };
    let record_id = object
        .get("record_id")
        .and_then(serde_json::Value::as_str)
        .unwrap_or_default();
    if object
        .get(field)
        .and_then(serde_json::Value::as_i64)
        .is_some_and(|value| value >= 0)
    {
        return Ok(());
    }
    Err(E::custom(format!(
        "corrupt_acs_audit_record field=audit_record.{field} record_id={record_id}"
    )))
}

pub(crate) fn require_audit_record_enum_field<E>(
    value: &serde_json::Value,
    field: &'static str,
    valid_code: fn(&str) -> bool,
) -> Result<(), E>
where
    E: serde::de::Error,
{
    let serde_json::Value::Object(object) = value else {
        return Err(E::custom("corrupt_acs_audit_record field=record"));
    };
    let record_id = object
        .get("record_id")
        .and_then(serde_json::Value::as_str)
        .unwrap_or_default();
    if object
        .get(field)
        .and_then(serde_json::Value::as_str)
        .is_some_and(valid_code)
    {
        return Ok(());
    }
    Err(E::custom(format!(
        "corrupt_acs_audit_record field=audit_record.{field} record_id={record_id}"
    )))
}

pub(crate) fn acs_audit_record_decode_error(error: &ACSAuditRecordError) -> String {
    if let Some(record_id) = error.record_id() {
        return format!("{} record_id={}", error.cause(), record_id);
    }
    error.cause().to_string()
}

impl ACSAuditRecord {
    pub const fn lane(&self) -> ACSLane {
        self.operation.lane()
    }

    pub const fn product_lane_code(&self) -> &'static str {
        self.lane().product_lane_code()
    }

    pub fn validate(&self) -> Result<(), ACSAuditRecordError> {
        if self.record_id.trim().is_empty() {
            return Err(self.corrupt("record_id"));
        }
        if !is_canonical_acs_record_id(&self.record_id) {
            return Err(self.corrupt("record_id"));
        }
        if !is_canonical_audit_token(&self.request_id) {
            return Err(self.corrupt("request_id"));
        }
        if is_reserved_malformed_audit_token(&self.request_id, MALFORMED_POLICY_AUDIT_PREFIX) {
            return Err(self.corrupt("request_id"));
        }
        if is_bare_malformed_audit_token(&self.request_id, MALFORMED_REQUEST_AUDIT_PREFIX) {
            return Err(self.corrupt("request_id"));
        }
        if self.verdict.allows_durable_commit()
            && is_reserved_malformed_audit_token(&self.request_id, MALFORMED_REQUEST_AUDIT_PREFIX)
        {
            return Err(self.corrupt("request_id"));
        }
        if !is_canonical_audit_token(&self.policy_id) {
            return Err(self.corrupt("policy_id"));
        }
        if is_reserved_malformed_audit_token(&self.policy_id, MALFORMED_REQUEST_AUDIT_PREFIX) {
            return Err(self.corrupt("policy_id"));
        }
        if is_bare_malformed_audit_token(&self.policy_id, MALFORMED_POLICY_AUDIT_PREFIX) {
            return Err(self.corrupt("policy_id"));
        }
        if self.verdict.allows_durable_commit()
            && is_reserved_malformed_audit_token(&self.policy_id, MALFORMED_POLICY_AUDIT_PREFIX)
        {
            return Err(self.corrupt("policy_id"));
        }
        if self.policy_version == 0 {
            return Err(self.corrupt("policy_version"));
        }
        if !is_canonical_audit_token(&self.reason) {
            return Err(self.corrupt("reason"));
        }
        if self.verdict.allows_durable_commit() && self.reason != self.verdict.code() {
            return Err(self.corrupt("reason"));
        }
        if !self.verdict.allows_durable_commit()
            && matches!(self.reason.as_str(), "allow" | "allow_with_warning")
        {
            return Err(self.corrupt("reason"));
        }
        if !self.risk_max.is_finite() || !(0.0..=1.0).contains(&self.risk_max) {
            return Err(self.corrupt("risk_max"));
        }
        if self.emitted_at_ms < 0 {
            return Err(self.corrupt("emitted_at_ms"));
        }
        if !acs_record_id_binds_request_and_time(
            &self.record_id,
            &self.request_id,
            self.emitted_at_ms,
        ) {
            return Err(self.corrupt("record_id"));
        }
        Ok(())
    }

    fn corrupt(&self, field: &'static str) -> ACSAuditRecordError {
        ACSAuditRecordError::Corrupt {
            field,
            record_id: self.record_id.clone(),
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ACSAuditRecordError {
    Corrupt {
        field: &'static str,
        record_id: String,
    },
}

impl ACSAuditRecordError {
    pub const fn cause(&self) -> &'static str {
        match self {
            Self::Corrupt { .. } => "corrupt_acs_audit_record",
        }
    }

    pub const fn field(&self) -> &'static str {
        match self {
            Self::Corrupt { field, .. } => field,
        }
    }

    pub fn record_id(&self) -> Option<&str> {
        match self {
            Self::Corrupt { record_id, .. } => Some(record_id.as_str()),
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
#[serde(transparent)]
pub struct AuditRecordId(pub String);

impl AuditRecordId {
    pub fn new(value: impl Into<String>) -> Self {
        Self(value.into())
    }

    pub(crate) fn validate(&self) -> Result<(), ACSAdmissionProofError> {
        if self.0.trim().is_empty() {
            Err(ACSAdmissionProofError::MissingRecordId)
        } else if !is_canonical_acs_record_id(&self.0) {
            Err(ACSAdmissionProofError::InvalidRecordId {
                record_id: self.0.clone(),
            })
        } else {
            Ok(())
        }
    }
}

impl<'de> Deserialize<'de> for AuditRecordId {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: serde::Deserializer<'de>,
    {
        let id = Self::new(String::deserialize(deserializer)?);
        id.validate()
            .map_err(|err| serde::de::Error::custom(scope_rex_proof_decode_error(&err)))?;
        Ok(id)
    }
}

pub(crate) fn is_canonical_acs_record_id(value: &str) -> bool {
    parse_canonical_acs_record_id(value).is_some()
}

pub(crate) fn parse_canonical_acs_record_id(value: &str) -> Option<(&str, &str)> {
    if value != value.trim() {
        return None;
    }
    let Some(suffix) = value.strip_prefix("acs:") else {
        return None;
    };
    if suffix.bytes().any(|byte| byte.is_ascii_whitespace()) {
        return None;
    }
    let Some((embedded_request_id, emitted_suffix)) = suffix.rsplit_once(':') else {
        return None;
    };
    if !is_canonical_audit_token(embedded_request_id) || emitted_suffix.is_empty() {
        return None;
    }
    if !emitted_suffix.bytes().all(|byte| byte.is_ascii_digit()) {
        return None;
    }
    if emitted_suffix.len() > 1 && emitted_suffix.starts_with('0') {
        return None;
    }
    Some((embedded_request_id, emitted_suffix))
}

pub(crate) fn acs_record_id_binds_request_and_time(
    record_id: &str,
    request_id: &str,
    emitted_at_ms: i64,
) -> bool {
    let Some((embedded_request_id, emitted_suffix)) = parse_canonical_acs_record_id(record_id)
    else {
        return false;
    };
    embedded_request_id == request_id && emitted_suffix == emitted_at_ms.to_string()
}

pub(crate) fn acs_record_id_embeds_reserved_malformed_audit_token(record_id: &str) -> bool {
    parse_canonical_acs_record_id(record_id)
        .is_some_and(|(request_id, _)| is_reserved_request_audit_token(request_id))
}

pub(crate) fn is_canonical_audit_token(value: &str) -> bool {
    !value.is_empty()
        && value == value.trim()
        && value.bytes().all(|byte| {
            matches!(
                byte,
                b'a'..=b'z' | b'A'..=b'Z' | b'0'..=b'9' | b'-' | b'_' | b'.'
            )
        })
}
