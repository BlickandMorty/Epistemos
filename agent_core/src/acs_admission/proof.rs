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
use super::requests::*;
use super::risk::*;
use super::validation::*;
use super::verdict::*;
use super::wire::*;

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
#[serde(transparent)]
pub struct CapabilitySignature(pub String);

impl CapabilitySignature {
    pub fn new(value: impl Into<String>) -> Self {
        Self(value.into())
    }

    fn validate(&self) -> Result<(), ACSAdmissionProofError> {
        if self.0.trim().is_empty() {
            return Err(ACSAdmissionProofError::MissingCapabilitySignature { record_id: None });
        }
        if self.0 != self.0.trim()
            || self.0.len() != CAPABILITY_SIGNATURE_BYTES * 2
            || !self
                .0
                .bytes()
                .all(|byte| matches!(byte, b'0'..=b'9' | b'a'..=b'f'))
        {
            return Err(ACSAdmissionProofError::InvalidCapabilitySignature { record_id: None });
        }
        let Some(bytes) = hex_decode_signature(&self.0) else {
            return Err(ACSAdmissionProofError::InvalidCapabilitySignature { record_id: None });
        };
        if bytes.len() != CAPABILITY_SIGNATURE_BYTES {
            return Err(ACSAdmissionProofError::InvalidCapabilitySignature { record_id: None });
        }
        Ok(())
    }
}

impl<'de> Deserialize<'de> for CapabilitySignature {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: serde::Deserializer<'de>,
    {
        let signature = Self::new(String::deserialize(deserializer)?);
        signature
            .validate()
            .map_err(|err| serde::de::Error::custom(err.cause()))?;
        Ok(signature)
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
#[serde(deny_unknown_fields)]
pub struct SCOPERexAdmissionProof {
    pub verdict: ACSAdmissionVerdict,
    pub operation: ACSOperationKind,
    pub record_id: AuditRecordId,
    pub signature: CapabilitySignature,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct SCOPERexAdmissionProofWire {
    verdict: ACSAdmissionVerdict,
    operation: ACSOperationKind,
    record_id: Option<serde_json::Value>,
    signature: Option<serde_json::Value>,
}

pub(crate) fn scope_rex_proof_wire_text(value: Option<serde_json::Value>, invalid_sentinel: &str) -> String {
    match value {
        Some(serde_json::Value::String(value)) => value,
        Some(_) => invalid_sentinel.to_string(),
        None => String::new(),
    }
}

impl<'de> Deserialize<'de> for SCOPERexAdmissionProof {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: serde::Deserializer<'de>,
    {
        let value = serde_json::Value::deserialize(deserializer)?;
        require_scope_rex_proof_known_fields::<D::Error>(&value)?;
        require_scope_rex_proof_field::<D::Error>(&value, "verdict")?;
        require_scope_rex_proof_field::<D::Error>(&value, "operation")?;
        let wire =
            SCOPERexAdmissionProofWire::deserialize(value).map_err(serde::de::Error::custom)?;
        let proof = Self {
            verdict: wire.verdict,
            operation: wire.operation,
            record_id: AuditRecordId::new(scope_rex_proof_wire_text(
                wire.record_id,
                "invalid_audit_record_id",
            )),
            signature: CapabilitySignature::new(scope_rex_proof_wire_text(
                wire.signature,
                "invalid_capability_signature",
            )),
        };
        proof
            .validate()
            .map_err(|err| serde::de::Error::custom(scope_rex_proof_decode_error(&err)))?;
        Ok(proof)
    }
}

pub(crate) fn require_scope_rex_proof_known_fields<E>(value: &serde_json::Value) -> Result<(), E>
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
            "verdict" | "operation" | "record_id" | "signature"
        ) {
            return Err(E::custom(format!(
                "malformed_acs_admission_proof field=proof.{field} record_id={record_id}"
            )));
        }
    }
    Ok(())
}

pub(crate) fn require_scope_rex_proof_field<E>(value: &serde_json::Value, field: &'static str) -> Result<(), E>
where
    E: serde::de::Error,
{
    let serde_json::Value::Object(object) = value else {
        return Err(E::custom("malformed_acs_admission_proof field=proof"));
    };
    if object.get(field).is_some_and(|value| {
        value.as_str().is_some_and(|text| match field {
            "operation" => is_canonical_operation_kind_code(text),
            "verdict" => is_canonical_admission_verdict_code(text),
            _ => true,
        })
    }) {
        return Ok(());
    }
    let record_id = object
        .get("record_id")
        .and_then(serde_json::Value::as_str)
        .unwrap_or_default();
    Err(E::custom(format!(
        "malformed_acs_admission_proof field=proof.{field} record_id={record_id}"
    )))
}

pub(crate) fn is_canonical_admission_verdict_code(value: &str) -> bool {
    matches!(
        value,
        "allow" | "allow_with_warning" | "defer" | "quarantine" | "reject"
    )
}

pub(crate) fn scope_rex_proof_decode_error(error: &ACSAdmissionProofError) -> String {
    if let Some(record_id) = error.record_id() {
        return format!("{} record_id={}", error.cause(), record_id);
    }
    error.cause().to_string()
}

impl SCOPERexAdmissionProof {
    pub const fn lane(&self) -> ACSLane {
        self.operation.lane()
    }

    pub const fn product_lane_code(&self) -> &'static str {
        self.lane().product_lane_code()
    }

    pub fn new(
        verdict: ACSAdmissionVerdict,
        operation: ACSOperationKind,
        record_id: AuditRecordId,
        signature: CapabilitySignature,
    ) -> Result<Self, ACSAdmissionProofError> {
        let proof = Self {
            verdict,
            operation,
            record_id,
            signature,
        };
        proof.validate()?;
        Ok(proof)
    }

    pub fn validate(&self) -> Result<(), ACSAdmissionProofError> {
        if !self.verdict.allows_durable_commit() {
            return Err(ACSAdmissionProofError::VerdictBlocksScopeRex {
                record_id: self.record_id.0.clone(),
            });
        }
        self.record_id.validate()?;
        if acs_record_id_embeds_reserved_malformed_audit_token(&self.record_id.0) {
            return Err(ACSAdmissionProofError::InvalidRecordId {
                record_id: self.record_id.0.clone(),
            });
        }
        self.signature
            .validate()
            .map_err(|error| error.with_record_id(&self.record_id.0))
    }

    pub fn signed_from_record<K: SigningKey>(
        record: &ACSAuditRecord,
        key: &K,
    ) -> Result<Self, ACSAdmissionProofError> {
        record
            .validate()
            .map_err(corrupt_audit_record_proof_error)?;
        if !record.verdict.allows_durable_commit() {
            return Err(ACSAdmissionProofError::VerdictBlocksScopeRex {
                record_id: record.record_id.clone(),
            });
        }
        let record_id = AuditRecordId::new(record.record_id.clone());
        let payload = scope_rex_proof_payload(record.verdict, record.operation, &record_id.0);
        let signature = CapabilitySignature::new(hex_encode_signature(&key.sign(&payload)));
        Self::new(record.verdict, record.operation, record_id, signature)
    }

    pub fn verify_signature<K: SigningKey>(&self, key: &K) -> bool {
        if self.validate().is_err() {
            return false;
        }
        let Some(signature) = hex_decode_signature(&self.signature.0) else {
            return false;
        };
        let payload = scope_rex_proof_payload(self.verdict, self.operation, &self.record_id.0);
        key.verify(&payload, &signature)
    }

    pub fn verify_against_record<K: SigningKey>(
        &self,
        record: &ACSAuditRecord,
        key: &K,
    ) -> Result<(), ACSAdmissionProofError> {
        self.validate()?;
        record
            .validate()
            .map_err(corrupt_audit_record_proof_error)?;
        if self.record_id.0 != record.record_id {
            return Err(ACSAdmissionProofError::RecordIdMismatch {
                record_id: self.record_id.0.clone(),
            });
        }
        if self.verdict != record.verdict {
            return Err(ACSAdmissionProofError::VerdictMismatch {
                record_id: self.record_id.0.clone(),
            });
        }
        if self.operation != record.operation {
            return Err(ACSAdmissionProofError::OperationMismatch {
                record_id: self.record_id.0.clone(),
            });
        }
        if !self.verify_signature(key) {
            return Err(ACSAdmissionProofError::InvalidCapabilitySignature {
                record_id: Some(self.record_id.0.clone()),
            });
        }
        Ok(())
    }

    pub fn verify_against_run_event_log<K: SigningKey>(
        &self,
        run_event_log: &OpLog,
        key: &K,
    ) -> Result<ACSAuditRecord, SCOPERexAdmissionProofVerificationError> {
        let chain_report = run_event_log.verify_chain(None);
        if !chain_report.valid {
            return Err(self.lookup_verification_error(acs_audit_lookup_chain_error(
                self.record_id.0.clone(),
                &chain_report,
            )));
        }
        self.validate()
            .map_err(|err| self.proof_verification_error(err))?;
        let record = resolve_acs_audit_record(run_event_log, &self.record_id)
            .map_err(|err| self.lookup_verification_error(err))?;
        self.verify_against_record(&record, key)
            .map_err(|err| self.proof_verification_error(err))?;
        Ok(record)
    }

    fn lookup_verification_error(
        &self,
        error: ACSAuditLookupError,
    ) -> SCOPERexAdmissionProofVerificationError {
        let needs_fallback_record_id = error.record_id().is_none();
        SCOPERexAdmissionProofVerificationError::Lookup {
            error,
            record_id: needs_fallback_record_id.then(|| self.record_id.0.clone()),
        }
    }

    fn proof_verification_error(
        &self,
        error: ACSAdmissionProofError,
    ) -> SCOPERexAdmissionProofVerificationError {
        SCOPERexAdmissionProofVerificationError::Proof {
            error,
            record_id: self.record_id.0.clone(),
        }
    }

    pub fn from_record(
        record: &ACSAuditRecord,
        signature: CapabilitySignature,
    ) -> Result<Self, ACSAdmissionProofError> {
        record
            .validate()
            .map_err(corrupt_audit_record_proof_error)?;
        Self::new(
            record.verdict,
            record.operation,
            AuditRecordId::new(record.record_id.clone()),
            signature,
        )
    }
}

pub(crate) fn corrupt_audit_record_proof_error(error: ACSAuditRecordError) -> ACSAdmissionProofError {
    ACSAdmissionProofError::CorruptAuditRecord {
        field: error.field(),
        record_id: error.record_id().unwrap_or("").to_string(),
    }
}

pub(crate) fn scope_rex_proof_payload(
    verdict: ACSAdmissionVerdict,
    operation: ACSOperationKind,
    record_id: &str,
) -> Vec<u8> {
    let mut payload =
        Vec::with_capacity(96 + SCOPE_REX_ADMISSION_PROOF_DOMAIN.len() + record_id.len());
    push_proof_field(&mut payload, b"domain", SCOPE_REX_ADMISSION_PROOF_DOMAIN);
    push_proof_field(&mut payload, b"verdict", verdict.code().as_bytes());
    push_proof_field(&mut payload, b"operation", operation.code().as_bytes());
    push_proof_field(&mut payload, b"record_id", record_id.as_bytes());
    payload
}

pub(crate) fn push_proof_field(payload: &mut Vec<u8>, field: &[u8], value: &[u8]) {
    payload.extend_from_slice(&(field.len() as u32).to_le_bytes());
    payload.extend_from_slice(field);
    payload.extend_from_slice(&(value.len() as u32).to_le_bytes());
    payload.extend_from_slice(value);
}

pub(crate) fn hex_encode_signature(bytes: &[u8]) -> String {
    const HEX: &[u8; 16] = b"0123456789abcdef";
    let mut out = String::with_capacity(bytes.len() * 2);
    for byte in bytes {
        out.push(HEX[(byte >> 4) as usize] as char);
        out.push(HEX[(byte & 0x0f) as usize] as char);
    }
    out
}

pub(crate) fn hex_decode_signature(value: &str) -> Option<Vec<u8>> {
    let trimmed = value.trim();
    if trimmed.len() % 2 != 0 {
        return None;
    }

    let mut out = Vec::with_capacity(trimmed.len() / 2);
    for pair in trimmed.as_bytes().chunks_exact(2) {
        let high = hex_value(pair[0])?;
        let low = hex_value(pair[1])?;
        out.push((high << 4) | low);
    }
    Some(out)
}

pub(crate) fn hex_value(byte: u8) -> Option<u8> {
    match byte {
        b'0'..=b'9' => Some(byte - b'0'),
        b'a'..=b'f' => Some(byte - b'a' + 10),
        b'A'..=b'F' => Some(byte - b'A' + 10),
        _ => None,
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ACSAdmissionProofError {
    MissingRecordId,
    InvalidRecordId {
        record_id: String,
    },
    MissingCapabilitySignature {
        record_id: Option<String>,
    },
    InvalidCapabilitySignature {
        record_id: Option<String>,
    },
    VerdictBlocksScopeRex {
        record_id: String,
    },
    RecordIdMismatch {
        record_id: String,
    },
    OperationMismatch {
        record_id: String,
    },
    VerdictMismatch {
        record_id: String,
    },
    CorruptAuditRecord {
        field: &'static str,
        record_id: String,
    },
}

impl ACSAdmissionProofError {
    pub const fn cause(&self) -> &'static str {
        match self {
            Self::MissingRecordId => "missing_audit_record_id",
            Self::InvalidRecordId { .. } => "invalid_audit_record_id",
            Self::MissingCapabilitySignature { .. } => "missing_capability_signature",
            Self::InvalidCapabilitySignature { .. } => "invalid_capability_signature",
            Self::VerdictBlocksScopeRex { .. } => "proof_verdict_blocks_scope_rex",
            Self::RecordIdMismatch { .. } => "proof_record_id_mismatch",
            Self::OperationMismatch { .. } => "proof_operation_mismatch",
            Self::VerdictMismatch { .. } => "proof_verdict_mismatch",
            Self::CorruptAuditRecord { .. } => "corrupt_acs_audit_record",
        }
    }

    pub const fn field(&self) -> Option<&'static str> {
        match self {
            Self::CorruptAuditRecord { field, .. } => Some(field),
            Self::MissingCapabilitySignature { .. } | Self::InvalidCapabilitySignature { .. } => {
                Some("signature")
            }
            Self::VerdictBlocksScopeRex { .. } => Some("verdict"),
            Self::RecordIdMismatch { .. } => Some("record_id"),
            Self::OperationMismatch { .. } => Some("operation"),
            Self::VerdictMismatch { .. } => Some("verdict"),
            Self::MissingRecordId | Self::InvalidRecordId { .. } => Some("record_id"),
        }
    }

    pub fn record_id(&self) -> Option<&str> {
        match self {
            Self::CorruptAuditRecord { record_id, .. } => Some(record_id.as_str()),
            Self::VerdictBlocksScopeRex { record_id } => Some(record_id.as_str()),
            Self::InvalidRecordId { record_id } => Some(record_id.as_str()),
            Self::RecordIdMismatch { record_id } => Some(record_id.as_str()),
            Self::OperationMismatch { record_id } => Some(record_id.as_str()),
            Self::VerdictMismatch { record_id } => Some(record_id.as_str()),
            Self::MissingCapabilitySignature { record_id }
            | Self::InvalidCapabilitySignature { record_id } => record_id.as_deref(),
            Self::MissingRecordId => None,
        }
    }

    fn with_record_id(self, record_id: &str) -> Self {
        match self {
            Self::MissingCapabilitySignature { .. } => Self::MissingCapabilitySignature {
                record_id: Some(record_id.to_string()),
            },
            Self::InvalidCapabilitySignature { .. } => Self::InvalidCapabilitySignature {
                record_id: Some(record_id.to_string()),
            },
            other => other,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum SCOPERexAdmissionProofVerificationError {
    Lookup {
        error: ACSAuditLookupError,
        record_id: Option<String>,
    },
    Proof {
        error: ACSAdmissionProofError,
        record_id: String,
    },
}

impl SCOPERexAdmissionProofVerificationError {
    pub const fn cause(&self) -> &'static str {
        match self {
            Self::Lookup { error, .. } => error.cause(),
            Self::Proof { error, .. } => error.cause(),
        }
    }

    pub const fn field(&self) -> Option<&'static str> {
        match self {
            Self::Lookup { error, .. } => error.field(),
            Self::Proof { error, .. } => error.field(),
        }
    }

    pub fn record_id(&self) -> Option<&str> {
        match self {
            Self::Lookup { error, record_id } => error.record_id().or(record_id.as_deref()),
            Self::Proof { record_id, .. } => Some(record_id.as_str()),
        }
    }
}
