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
use super::audit_sink::*;
use super::common::*;
use super::decision::*;
use super::policy::*;
use super::proof::*;
use super::requests::*;
use super::risk::*;
use super::validation::*;
use super::verdict::*;
use super::wire::*;
use super::*;

/// Data-only ACS request envelope. It carries the caller's declared operation,
/// risk vector, and already-granted capabilities without applying any state.
#[derive(Debug, Clone, PartialEq, Serialize)]
#[serde(deny_unknown_fields)]
pub struct ACSAdmissionInput {
    pub request_id: String,
    pub payload: ACSAdmissionPayload,
    pub submitted_at_ms: i64,
    pub risk: ACSRiskVector,
    #[serde(default)]
    pub granted_capabilities: Vec<Capability>,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct ACSAdmissionInputWire {
    request_id: String,
    payload: ACSAdmissionPayload,
    submitted_at_ms: i64,
    risk: ACSRiskVector,
    #[serde(default)]
    granted_capabilities: Vec<Capability>,
}

impl<'de> Deserialize<'de> for ACSAdmissionInput {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: serde::Deserializer<'de>,
    {
        let value = serde_json::Value::deserialize(deserializer)?;
        require_admission_input_known_fields::<D::Error>(&value)?;
        require_admission_input_field::<D::Error>(
            &value,
            "request_id",
            "admission_input.request_id",
            serde_json::Value::is_string,
        )?;
        require_admission_input_field::<D::Error>(
            &value,
            "payload",
            "admission_input.payload",
            serde_json::Value::is_object,
        )?;
        require_admission_input_payload_kind::<D::Error>(&value)?;
        require_admission_input_field::<D::Error>(
            &value,
            "submitted_at_ms",
            "admission_input.submitted_at_ms",
            serde_json::Value::is_i64,
        )?;
        require_admission_input_field::<D::Error>(
            &value,
            "risk",
            "admission_input.risk",
            serde_json::Value::is_object,
        )?;
        require_admission_input_field::<D::Error>(
            &value,
            "granted_capabilities",
            "admission_input.granted_capabilities",
            serde_json::Value::is_array,
        )?;
        require_granted_capability_envelopes::<D::Error>(&value)?;
        let wire = ACSAdmissionInputWire::deserialize(value).map_err(|err| {
            serde::de::Error::custom(admission_input_wire_decode_error(&err.to_string()))
        })?;
        let input = Self {
            request_id: wire.request_id,
            payload: wire.payload,
            submitted_at_ms: wire.submitted_at_ms,
            risk: wire.risk,
            granted_capabilities: wire.granted_capabilities,
        };
        input
            .validate()
            .map_err(|err| serde::de::Error::custom(acs_admission_input_decode_error(&err)))?;
        Ok(input)
    }
}

pub(crate) fn require_admission_input_known_fields<E>(value: &serde_json::Value) -> Result<(), E>
where
    E: serde::de::Error,
{
    let serde_json::Value::Object(object) = value else {
        return Ok(());
    };
    for field in object.keys() {
        if !matches!(
            field.as_str(),
            "request_id" | "payload" | "submitted_at_ms" | "risk" | "granted_capabilities"
        ) {
            return Err(E::custom(format!(
                "forged_admission_input field=admission_input.{field}"
            )));
        }
    }
    Ok(())
}

pub(crate) fn admission_input_wire_decode_error(message: &str) -> String {
    for prefix in [
        "missing_risk_axis field=risk.",
        "malformed_risk_axis field=risk.",
        "malformed_risk_field field=risk.",
        "risk_axis_out_of_range field=risk.",
        "non_finite_risk_axis field=risk.",
        "malformed_risk_vector field=risk.",
    ] {
        if let Some(field) = message.strip_prefix(prefix) {
            return format!("forged_admission_input field=admission_input.risk.{field}");
        }
    }

    if message == "malformed_risk_vector field=risk" {
        return "forged_admission_input field=admission_input.risk".to_string();
    }

    message.to_string()
}

pub(crate) fn require_admission_input_payload_kind<E>(value: &serde_json::Value) -> Result<(), E>
where
    E: serde::de::Error,
{
    let Some(serde_json::Value::Object(payload)) = value.get("payload") else {
        return Err(E::custom(
            "forged_admission_input field=admission_input.payload",
        ));
    };
    if payload
        .get("kind")
        .and_then(serde_json::Value::as_str)
        .is_some_and(is_canonical_operation_kind_code)
    {
        for field in payload.keys() {
            if !matches!(field.as_str(), "kind" | "envelope" | "packet" | "request") {
                return Err(E::custom(format!(
                    "forged_admission_input field=admission_input.payload.{field}"
                )));
            }
        }
        return Ok(());
    }
    Err(E::custom(
        "forged_admission_input field=admission_input.payload",
    ))
}

pub(crate) fn require_admission_input_field<E>(
    value: &serde_json::Value,
    field: &'static str,
    input_field: &'static str,
    valid_field: fn(&serde_json::Value) -> bool,
) -> Result<(), E>
where
    E: serde::de::Error,
{
    match value {
        serde_json::Value::Object(object) if object.get(field).is_some_and(valid_field) => Ok(()),
        serde_json::Value::Object(_) => Err(E::custom(format!(
            "forged_admission_input field={input_field}"
        ))),
        _ => Err(E::custom("forged_admission_input field=admission_input")),
    }
}

pub(crate) fn require_granted_capability_envelopes<E>(value: &serde_json::Value) -> Result<(), E>
where
    E: serde::de::Error,
{
    let Some(serde_json::Value::Array(capabilities)) = value.get("granted_capabilities") else {
        return Ok(());
    };
    for capability in capabilities {
        let serde_json::Value::Object(capability) = capability else {
            return Err(E::custom(
                "forged_admission_input field=admission_input.granted_capabilities.capability",
            ));
        };
        for field in capability.keys() {
            if !matches!(field.as_str(), "kind" | "value") {
                return Err(E::custom(format!(
                    "forged_admission_input field=admission_input.granted_capabilities.{field}"
                )));
            }
        }
        let Some(kind) = capability.get("kind").and_then(serde_json::Value::as_str) else {
            return Err(E::custom(
                "forged_admission_input field=admission_input.granted_capabilities.capability",
            ));
        };
        let Some(serde_json::Value::Object(capability_value)) = capability.get("value") else {
            return Err(E::custom(
                "forged_admission_input field=admission_input.granted_capabilities.capability",
            ));
        };
        for field in capability_value.keys() {
            if let Some(shadow_field) =
                capability_value_shadow_field(kind, field, GRANTED_CAPABILITY_SHADOW_FIELDS)
            {
                return Err(E::custom(format!(
                    "forged_admission_input field={shadow_field}"
                )));
            }
        }
        let required_field = match kind {
            "vault_path"
                if !capability_value
                    .get("path")
                    .is_some_and(serde_json::Value::is_string) =>
            {
                Some(GRANTED_CAPABILITY_FIELDS.vault_path_path)
            }
            "vault_path"
                if !capability_value
                    .get("verb")
                    .is_some_and(serde_json::Value::is_string) =>
            {
                Some(GRANTED_CAPABILITY_FIELDS.vault_path_verb)
            }
            "vault_path" => None,
            "network_host" => (!capability_value
                .get("host")
                .is_some_and(serde_json::Value::is_string))
            .then_some(GRANTED_CAPABILITY_FIELDS.network_host_host),
            "biometric_session" => capability_value
                .get("ttl_secs")
                .and_then(serde_json::Value::as_u64)
                .is_none_or(|ttl_secs| {
                    ttl_secs == 0 || ttl_secs > MAX_BIOMETRIC_SESSION_TTL_SECS as u64
                })
                .then_some(GRANTED_CAPABILITY_FIELDS.biometric_session_ttl_secs),
            "other" => (!capability_value
                .get("name")
                .is_some_and(serde_json::Value::is_string))
            .then_some(GRANTED_CAPABILITY_FIELDS.other_name),
            _ => Some("admission_input.granted_capabilities.capability"),
        };
        if let Some(field) = required_field {
            return Err(E::custom(format!("forged_admission_input field={field}")));
        }
    }
    Ok(())
}

impl ACSAdmissionInput {
    pub fn validate(&self) -> Result<(), ACSAdmissionInputError> {
        if !is_canonical_audit_token(&self.request_id)
            || is_reserved_request_audit_token(&self.request_id)
        {
            return Err(ACSAdmissionInputError::Forged {
                field: "request_id",
            });
        }
        if self.submitted_at_ms < 0 {
            return Err(ACSAdmissionInputError::Forged {
                field: "submitted_at_ms",
            });
        }
        self.risk
            .validate()
            .map_err(|_| ACSAdmissionInputError::Forged { field: "risk" })?;
        let mut granted_capabilities = Vec::new();
        for capability in &self.granted_capabilities {
            validate_capability_fields(capability, GRANTED_CAPABILITY_FIELDS)
                .map_err(|field| ACSAdmissionInputError::Forged { field })?;
            if granted_capabilities.contains(&capability) {
                return Err(ACSAdmissionInputError::Forged {
                    field: "admission_input.granted_capabilities.duplicate_capability",
                });
            }
            granted_capabilities.push(capability);
        }
        self.payload.validate()
    }

    pub const fn operation(&self) -> ACSOperationKind {
        self.payload.operation()
    }

    pub const fn lane(&self) -> ACSLane {
        self.payload.lane()
    }

    pub const fn product_lane_code(&self) -> &'static str {
        self.lane().product_lane_code()
    }
}

/// Defensive request validation failures.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ACSAdmissionInputError {
    Forged { field: &'static str },
    DurableWriteBypass { field: &'static str },
    KernelPromotionBypass { field: &'static str },
    ModelAdaptationBypass { field: &'static str },
}

impl ACSAdmissionInputError {
    pub const fn cause(&self) -> &'static str {
        match self {
            Self::Forged { .. } => "forged_admission_input",
            Self::DurableWriteBypass { .. } => "durable_write_bypass_attempt",
            Self::KernelPromotionBypass { .. } => "kernel_promotion_bypass_attempt",
            Self::ModelAdaptationBypass { .. } => "model_adaptation_bypass_attempt",
        }
    }

    pub const fn field(&self) -> &'static str {
        match self {
            Self::Forged { field }
            | Self::DurableWriteBypass { field }
            | Self::KernelPromotionBypass { field }
            | Self::ModelAdaptationBypass { field } => field,
        }
    }
}

pub(crate) fn acs_admission_input_decode_error(error: &ACSAdmissionInputError) -> String {
    format!(
        "{} field={}",
        error.cause(),
        acs_admission_input_decode_field(error.field())
    )
}

pub(crate) fn acs_admission_input_decode_field(field: &'static str) -> &'static str {
    match field {
        "request_id" => "admission_input.request_id",
        "submitted_at_ms" => "admission_input.submitted_at_ms",
        "risk" => "admission_input.risk",
        _ => field,
    }
}
