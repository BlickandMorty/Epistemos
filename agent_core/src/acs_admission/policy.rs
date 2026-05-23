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
use super::proof::*;
use super::requests::*;
use super::risk::*;
use super::validation::*;
use super::verdict::*;
use super::wire::*;

/// Risk thresholds for policy verdict selection.
#[derive(Debug, Clone, Copy, PartialEq, Serialize)]
#[serde(deny_unknown_fields)]
pub struct ACSRiskThresholds {
    pub warn_at: f32,
    pub defer_at: f32,
    pub quarantine_at: f32,
    pub reject_at: f32,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct ACSRiskThresholdsWire {
    warn_at: f32,
    defer_at: f32,
    quarantine_at: f32,
    reject_at: f32,
}

impl<'de> Deserialize<'de> for ACSRiskThresholds {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: serde::Deserializer<'de>,
    {
        let value = serde_json::Value::deserialize(deserializer)?;
        require_threshold_known_fields::<D::Error>(&value)?;
        require_threshold_field::<D::Error>(&value, "warn_at")?;
        require_threshold_field::<D::Error>(&value, "defer_at")?;
        require_threshold_field::<D::Error>(&value, "quarantine_at")?;
        require_threshold_field::<D::Error>(&value, "reject_at")?;
        let wire = ACSRiskThresholdsWire::deserialize(value).map_err(serde::de::Error::custom)?;
        let thresholds = Self {
            warn_at: wire.warn_at,
            defer_at: wire.defer_at,
            quarantine_at: wire.quarantine_at,
            reject_at: wire.reject_at,
        };
        thresholds
            .validate()
            .map_err(|err| serde::de::Error::custom(acs_policy_decode_error(&err)))?;
        Ok(thresholds)
    }
}

pub(crate) fn require_threshold_field<E>(value: &serde_json::Value, field: &'static str) -> Result<(), E>
where
    E: serde::de::Error,
{
    match value {
        serde_json::Value::Object(object)
            if object.get(field).is_some_and(serde_json::Value::is_number) =>
        {
            Ok(())
        }
        serde_json::Value::Object(_) => Err(E::custom(format!(
            "malformed_policy field=thresholds.{field}"
        ))),
        _ => Err(E::custom(acs_policy_decode_error(
            &ACSPolicyError::Malformed {
                field: "thresholds",
            },
        ))),
    }
}

pub(crate) fn require_threshold_known_fields<E>(value: &serde_json::Value) -> Result<(), E>
where
    E: serde::de::Error,
{
    let serde_json::Value::Object(object) = value else {
        return Err(E::custom(acs_policy_decode_error(
            &ACSPolicyError::Malformed {
                field: "thresholds",
            },
        )));
    };
    for field in object.keys() {
        if !matches!(
            field.as_str(),
            "warn_at" | "defer_at" | "quarantine_at" | "reject_at"
        ) {
            return Err(E::custom(format!(
                "malformed_policy field=thresholds.{field}"
            )));
        }
    }
    Ok(())
}

impl ACSRiskThresholds {
    pub const fn standard() -> Self {
        Self {
            warn_at: 0.35,
            defer_at: 0.55,
            quarantine_at: 0.75,
            reject_at: 0.9,
        }
    }

    fn validate(&self) -> Result<(), ACSPolicyError> {
        for (field, value) in [
            ("warn_at", self.warn_at),
            ("defer_at", self.defer_at),
            ("quarantine_at", self.quarantine_at),
            ("reject_at", self.reject_at),
        ] {
            if !value.is_finite() || !(0.0..=1.0).contains(&value) {
                return Err(ACSPolicyError::Malformed { field });
            }
        }

        if !(self.warn_at <= self.defer_at
            && self.defer_at <= self.quarantine_at
            && self.quarantine_at <= self.reject_at)
        {
            return Err(ACSPolicyError::Malformed {
                field: "risk_threshold_order",
            });
        }

        Ok(())
    }
}

pub(crate) fn acs_policy_decode_error(error: &ACSPolicyError) -> String {
    match error.field() {
        Some(field) => format!("{} field={field}", error.cause()),
        None => error.cause().to_string(),
    }
}

/// One capability requirement bound to an ACS operation family.
#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
#[serde(deny_unknown_fields)]
pub struct ACSCapabilityRule {
    pub operation: ACSOperationKind,
    pub capability: Capability,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct ACSCapabilityRuleWire {
    operation: ACSOperationKind,
    capability: Capability,
}

impl<'de> Deserialize<'de> for ACSCapabilityRule {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: serde::Deserializer<'de>,
    {
        let value = serde_json::Value::deserialize(deserializer)?;
        require_capability_rule_known_fields::<D::Error>(&value)?;
        require_capability_rule_field::<D::Error>(
            &value,
            "operation",
            "required_capabilities.operation",
            is_operation_kind_wire_value,
        )?;
        require_capability_rule_field::<D::Error>(
            &value,
            "capability",
            "required_capabilities.capability",
            serde_json::Value::is_object,
        )?;
        require_capability_rule_capability_envelope::<D::Error>(&value)?;
        let wire = ACSCapabilityRuleWire::deserialize(value).map_err(serde::de::Error::custom)?;
        let rule = Self {
            operation: wire.operation,
            capability: wire.capability,
        };
        rule.validate()
            .map_err(|err| serde::de::Error::custom(acs_policy_decode_error(&err)))?;
        Ok(rule)
    }
}

pub(crate) fn require_capability_rule_field<E>(
    value: &serde_json::Value,
    field: &'static str,
    policy_field: &'static str,
    valid_field: fn(&serde_json::Value) -> bool,
) -> Result<(), E>
where
    E: serde::de::Error,
{
    match value {
        serde_json::Value::Object(object) if object.get(field).is_some_and(valid_field) => Ok(()),
        serde_json::Value::Object(_) => Err(E::custom(acs_policy_decode_error(
            &ACSPolicyError::Malformed {
                field: policy_field,
            },
        ))),
        _ => Err(E::custom(acs_policy_decode_error(
            &ACSPolicyError::Malformed {
                field: "required_capabilities",
            },
        ))),
    }
}

pub(crate) fn require_capability_rule_known_fields<E>(value: &serde_json::Value) -> Result<(), E>
where
    E: serde::de::Error,
{
    let serde_json::Value::Object(object) = value else {
        return Err(E::custom(acs_policy_decode_error(
            &ACSPolicyError::Malformed {
                field: "required_capabilities",
            },
        )));
    };
    for field in object.keys() {
        if !matches!(field.as_str(), "operation" | "capability") {
            return Err(E::custom(format!(
                "malformed_policy field=required_capabilities.{field}"
            )));
        }
    }
    Ok(())
}

pub(crate) fn require_capability_rule_capability_envelope<E>(value: &serde_json::Value) -> Result<(), E>
where
    E: serde::de::Error,
{
    let serde_json::Value::Object(rule) = value else {
        return Err(E::custom(acs_policy_decode_error(
            &ACSPolicyError::Malformed {
                field: "required_capabilities",
            },
        )));
    };
    let Some(serde_json::Value::Object(capability)) = rule.get("capability") else {
        return Err(E::custom(acs_policy_decode_error(
            &ACSPolicyError::Malformed {
                field: "required_capabilities.capability",
            },
        )));
    };
    for field in capability.keys() {
        if !matches!(field.as_str(), "kind" | "value") {
            return Err(E::custom(format!(
                "malformed_policy field=required_capabilities.{field}"
            )));
        }
    }

    let Some(kind) = capability.get("kind").and_then(serde_json::Value::as_str) else {
        return Err(E::custom(acs_policy_decode_error(
            &ACSPolicyError::Malformed {
                field: "required_capabilities.capability",
            },
        )));
    };
    let Some(serde_json::Value::Object(capability_value)) = capability.get("value") else {
        return Err(E::custom(acs_policy_decode_error(
            &ACSPolicyError::Malformed {
                field: "required_capabilities.capability",
            },
        )));
    };
    for field in capability_value.keys() {
        if let Some(shadow_field) =
            capability_value_shadow_field(kind, field, REQUIRED_CAPABILITY_SHADOW_FIELDS)
        {
            return Err(E::custom(acs_policy_decode_error(
                &ACSPolicyError::Malformed {
                    field: shadow_field,
                },
            )));
        }
    }

    let required_field = match kind {
        "vault_path"
            if !capability_value
                .get("path")
                .is_some_and(serde_json::Value::is_string) =>
        {
            Some(REQUIRED_CAPABILITY_FIELDS.vault_path_path)
        }
        "vault_path"
            if !capability_value
                .get("verb")
                .is_some_and(serde_json::Value::is_string) =>
        {
            Some(REQUIRED_CAPABILITY_FIELDS.vault_path_verb)
        }
        "vault_path" => None,
        "network_host" => (!capability_value
            .get("host")
            .is_some_and(serde_json::Value::is_string))
        .then_some(REQUIRED_CAPABILITY_FIELDS.network_host_host),
        "biometric_session" => capability_value
            .get("ttl_secs")
            .and_then(serde_json::Value::as_u64)
            .is_none_or(|ttl_secs| {
                ttl_secs == 0 || ttl_secs > MAX_BIOMETRIC_SESSION_TTL_SECS as u64
            })
            .then_some(REQUIRED_CAPABILITY_FIELDS.biometric_session_ttl_secs),
        "other" => (!capability_value
            .get("name")
            .is_some_and(serde_json::Value::is_string))
        .then_some(REQUIRED_CAPABILITY_FIELDS.other_name),
        _ => Some("required_capabilities.capability"),
    };
    if let Some(field) = required_field {
        return Err(E::custom(acs_policy_decode_error(
            &ACSPolicyError::Malformed { field },
        )));
    };

    Ok(())
}

#[derive(Debug, Clone, Copy)]
pub(crate) struct CapabilityShadowFieldNames {
    pub(crate) vault_path_shadow_path: &'static str,
    pub(crate) vault_path_shadow_verb: &'static str,
    pub(crate) network_host_shadow_host: &'static str,
    pub(crate) biometric_session_shadow_ttl_secs: &'static str,
    pub(crate) other_shadow_name: &'static str,
    pub(crate) generic_capability: &'static str,
}

pub(crate) const REQUIRED_CAPABILITY_SHADOW_FIELDS: CapabilityShadowFieldNames = CapabilityShadowFieldNames {
    vault_path_shadow_path: "required_capabilities.vault_path.shadow_path",
    vault_path_shadow_verb: "required_capabilities.vault_path.shadow_verb",
    network_host_shadow_host: "required_capabilities.network_host.shadow_host",
    biometric_session_shadow_ttl_secs: "required_capabilities.biometric_session.shadow_ttl_secs",
    other_shadow_name: "required_capabilities.other.shadow_name",
    generic_capability: "required_capabilities.capability",
};

pub(crate) const GRANTED_CAPABILITY_SHADOW_FIELDS: CapabilityShadowFieldNames = CapabilityShadowFieldNames {
    vault_path_shadow_path: "admission_input.granted_capabilities.vault_path.shadow_path",
    vault_path_shadow_verb: "admission_input.granted_capabilities.vault_path.shadow_verb",
    network_host_shadow_host: "admission_input.granted_capabilities.network_host.shadow_host",
    biometric_session_shadow_ttl_secs:
        "admission_input.granted_capabilities.biometric_session.shadow_ttl_secs",
    other_shadow_name: "admission_input.granted_capabilities.other.shadow_name",
    generic_capability: "admission_input.granted_capabilities.capability",
};

pub(crate) fn capability_value_shadow_field(
    kind: &str,
    field: &str,
    fields: CapabilityShadowFieldNames,
) -> Option<&'static str> {
    match kind {
        "vault_path" if matches!(field, "path" | "verb") => None,
        "vault_path" if field == "shadow_path" => Some(fields.vault_path_shadow_path),
        "vault_path" if field == "shadow_verb" => Some(fields.vault_path_shadow_verb),
        "network_host" if field == "host" => None,
        "network_host" if field == "shadow_host" => Some(fields.network_host_shadow_host),
        "biometric_session" if field == "ttl_secs" => None,
        "biometric_session" if field == "shadow_ttl_secs" => {
            Some(fields.biometric_session_shadow_ttl_secs)
        }
        "other" if field == "name" => None,
        "other" if field == "shadow_name" => Some(fields.other_shadow_name),
        _ => Some(fields.generic_capability),
    }
}

impl ACSCapabilityRule {
    pub fn new(operation: ACSOperationKind, capability: Capability) -> Self {
        Self {
            operation,
            capability,
        }
    }

    fn validate(&self) -> Result<(), ACSPolicyError> {
        validate_required_capability(&self.capability)
    }
}

pub(crate) fn validate_required_capability(capability: &Capability) -> Result<(), ACSPolicyError> {
    validate_capability_fields(capability, REQUIRED_CAPABILITY_FIELDS)
        .map_err(|field| ACSPolicyError::Malformed { field })
}

#[derive(Debug, Clone, Copy)]
pub(crate) struct CapabilityFieldNames {
    pub(crate) vault_path_path: &'static str,
    pub(crate) vault_path_verb: &'static str,
    pub(crate) network_host_host: &'static str,
    pub(crate) biometric_session_ttl_secs: &'static str,
    pub(crate) other_name: &'static str,
}

pub(crate) const REQUIRED_CAPABILITY_FIELDS: CapabilityFieldNames = CapabilityFieldNames {
    vault_path_path: "required_capabilities.vault_path.path",
    vault_path_verb: "required_capabilities.vault_path.verb",
    network_host_host: "required_capabilities.network_host.host",
    biometric_session_ttl_secs: "required_capabilities.biometric_session.ttl_secs",
    other_name: "required_capabilities.other.name",
};

pub(crate) const GRANTED_CAPABILITY_FIELDS: CapabilityFieldNames = CapabilityFieldNames {
    vault_path_path: "admission_input.granted_capabilities.vault_path.path",
    vault_path_verb: "admission_input.granted_capabilities.vault_path.verb",
    network_host_host: "admission_input.granted_capabilities.network_host.host",
    biometric_session_ttl_secs: "admission_input.granted_capabilities.biometric_session.ttl_secs",
    other_name: "admission_input.granted_capabilities.other.name",
};

pub(crate) const MAX_BIOMETRIC_SESSION_TTL_SECS: u32 = 300;

pub(crate) fn validate_capability_fields(
    capability: &Capability,
    fields: CapabilityFieldNames,
) -> Result<(), &'static str> {
    match capability {
        Capability::VaultPath { path, verb } => {
            if path.trim().is_empty() || path != path.trim() {
                return Err(fields.vault_path_path);
            }
            if !is_canonical_audit_token(verb) {
                return Err(fields.vault_path_verb);
            }
        }
        Capability::NetworkHost { host } => {
            if !is_canonical_audit_token(host) {
                return Err(fields.network_host_host);
            }
        }
        Capability::BiometricSession { ttl_secs } => {
            if *ttl_secs == 0 || *ttl_secs > MAX_BIOMETRIC_SESSION_TTL_SECS {
                return Err(fields.biometric_session_ttl_secs);
            }
        }
        Capability::Other { name } => {
            if !is_canonical_audit_token(name) {
                return Err(fields.other_name);
            }
        }
    }

    Ok(())
}

/// Operation-specific threshold override for default ACS policy matrices.
#[derive(Debug, Clone, Copy, PartialEq, Serialize)]
#[serde(deny_unknown_fields)]
pub struct ACSOperationThresholdRule {
    pub operation: ACSOperationKind,
    pub thresholds: ACSRiskThresholds,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct ACSOperationThresholdRuleWire {
    operation: ACSOperationKind,
    thresholds: ACSRiskThresholds,
}

impl<'de> Deserialize<'de> for ACSOperationThresholdRule {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: serde::Deserializer<'de>,
    {
        let value = serde_json::Value::deserialize(deserializer)?;
        require_operation_threshold_rule_known_fields::<D::Error>(&value)?;
        require_operation_threshold_rule_field::<D::Error>(
            &value,
            "operation",
            "operation_thresholds.operation",
            is_operation_kind_wire_value,
        )?;
        require_operation_threshold_rule_field::<D::Error>(
            &value,
            "thresholds",
            "operation_thresholds.thresholds",
            serde_json::Value::is_object,
        )?;
        let wire = ACSOperationThresholdRuleWire::deserialize(value).map_err(|err| {
            serde::de::Error::custom(operation_threshold_decode_error(&err.to_string()))
        })?;
        Ok(Self {
            operation: wire.operation,
            thresholds: wire.thresholds,
        })
    }
}

pub(crate) fn operation_threshold_decode_error(message: &str) -> String {
    let message = message.replacen(
        "malformed_policy field=thresholds.",
        "malformed_policy field=operation_thresholds.thresholds.",
        1,
    );
    message.replacen(
        "malformed_policy field=risk_threshold_order",
        "malformed_policy field=operation_thresholds.thresholds.risk_threshold_order",
        1,
    )
}

pub(crate) fn is_operation_kind_wire_value(value: &serde_json::Value) -> bool {
    value.as_str().is_some_and(is_canonical_operation_kind_code)
}

pub(crate) fn is_canonical_operation_kind_code(value: &str) -> bool {
    matches!(
        value,
        "mutation_envelope"
            | "active_assembly_packet"
            | "answer_packet"
            | "memory_write"
            | "tool_action"
            | "kernel_promotion"
            | "model_adaptation"
    )
}

pub(crate) fn require_operation_threshold_rule_field<E>(
    value: &serde_json::Value,
    field: &'static str,
    policy_field: &'static str,
    valid_field: fn(&serde_json::Value) -> bool,
) -> Result<(), E>
where
    E: serde::de::Error,
{
    match value {
        serde_json::Value::Object(object) if object.get(field).is_some_and(valid_field) => Ok(()),
        serde_json::Value::Object(_) => Err(E::custom(acs_policy_decode_error(
            &ACSPolicyError::Malformed {
                field: policy_field,
            },
        ))),
        _ => Err(E::custom(acs_policy_decode_error(
            &ACSPolicyError::Malformed {
                field: "operation_thresholds",
            },
        ))),
    }
}

pub(crate) fn require_operation_threshold_rule_known_fields<E>(value: &serde_json::Value) -> Result<(), E>
where
    E: serde::de::Error,
{
    let serde_json::Value::Object(object) = value else {
        return Err(E::custom(acs_policy_decode_error(
            &ACSPolicyError::Malformed {
                field: "operation_thresholds",
            },
        )));
    };
    for field in object.keys() {
        if !matches!(field.as_str(), "operation" | "thresholds") {
            return Err(E::custom(format!(
                "malformed_policy field=operation_thresholds.{field}"
            )));
        }
    }
    Ok(())
}

impl ACSOperationThresholdRule {
    pub const fn new(operation: ACSOperationKind, thresholds: ACSRiskThresholds) -> Self {
        Self {
            operation,
            thresholds,
        }
    }
}

/// Policy carried into ACS admission. It is data-only and request-scoped.
#[derive(Debug, Clone, PartialEq, Serialize)]
#[serde(deny_unknown_fields)]
pub struct ACSPolicy {
    pub policy_id: String,
    pub version: u32,
    pub valid_from_ms: i64,
    pub expires_at_ms: Option<i64>,
    pub thresholds: ACSRiskThresholds,
    #[serde(default)]
    pub required_capabilities: Vec<ACSCapabilityRule>,
    #[serde(default)]
    pub operation_thresholds: Vec<ACSOperationThresholdRule>,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct ACSPolicyWire {
    policy_id: String,
    version: u32,
    valid_from_ms: i64,
    expires_at_ms: Option<i64>,
    thresholds: ACSRiskThresholds,
    #[serde(default)]
    required_capabilities: Vec<ACSCapabilityRule>,
    #[serde(default)]
    operation_thresholds: Vec<ACSOperationThresholdRule>,
}

impl<'de> Deserialize<'de> for ACSPolicy {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: serde::Deserializer<'de>,
    {
        let value = serde_json::Value::deserialize(deserializer)?;
        require_policy_known_fields::<D::Error>(&value)?;
        require_policy_field::<D::Error>(
            &value,
            "policy_id",
            "policy_id",
            serde_json::Value::is_string,
        )?;
        require_policy_field::<D::Error>(&value, "version", "version", is_u32_value)?;
        require_policy_field::<D::Error>(
            &value,
            "valid_from_ms",
            "valid_from_ms",
            serde_json::Value::is_i64,
        )?;
        require_policy_field::<D::Error>(&value, "expires_at_ms", "expires_at_ms", is_i64_or_null)?;
        require_policy_field::<D::Error>(
            &value,
            "thresholds",
            "thresholds",
            serde_json::Value::is_object,
        )?;
        require_policy_field::<D::Error>(
            &value,
            "required_capabilities",
            "required_capabilities",
            serde_json::Value::is_array,
        )?;
        require_policy_field::<D::Error>(
            &value,
            "operation_thresholds",
            "operation_thresholds",
            serde_json::Value::is_array,
        )?;
        let wire = ACSPolicyWire::deserialize(value).map_err(serde::de::Error::custom)?;
        let policy = Self {
            policy_id: wire.policy_id,
            version: wire.version,
            valid_from_ms: wire.valid_from_ms,
            expires_at_ms: wire.expires_at_ms,
            thresholds: wire.thresholds,
            required_capabilities: wire.required_capabilities,
            operation_thresholds: wire.operation_thresholds,
        };
        policy
            .validate_shape()
            .map_err(|err| serde::de::Error::custom(acs_policy_decode_error(&err)))?;
        Ok(policy)
    }
}

pub(crate) fn is_i64_or_null(value: &serde_json::Value) -> bool {
    value.is_i64() || value.is_null()
}

pub(crate) fn require_policy_known_fields<E>(value: &serde_json::Value) -> Result<(), E>
where
    E: serde::de::Error,
{
    let serde_json::Value::Object(object) = value else {
        return Err(E::custom(acs_policy_decode_error(
            &ACSPolicyError::Malformed { field: "policy" },
        )));
    };
    for field in object.keys() {
        if !matches!(
            field.as_str(),
            "policy_id"
                | "version"
                | "valid_from_ms"
                | "expires_at_ms"
                | "thresholds"
                | "required_capabilities"
                | "operation_thresholds"
        ) {
            return Err(E::custom(format!("malformed_policy field={field}")));
        }
    }
    Ok(())
}

pub(crate) fn is_u32_value(value: &serde_json::Value) -> bool {
    value
        .as_u64()
        .is_some_and(|number| number <= u32::MAX as u64)
}

pub(crate) fn require_policy_field<E>(
    value: &serde_json::Value,
    field: &'static str,
    policy_field: &'static str,
    valid_field: fn(&serde_json::Value) -> bool,
) -> Result<(), E>
where
    E: serde::de::Error,
{
    match value {
        serde_json::Value::Object(object) if object.get(field).is_some_and(valid_field) => Ok(()),
        serde_json::Value::Object(_) => Err(E::custom(acs_policy_decode_error(
            &ACSPolicyError::Malformed {
                field: policy_field,
            },
        ))),
        _ => Err(E::custom(acs_policy_decode_error(
            &ACSPolicyError::Malformed { field: "policy" },
        ))),
    }
}

impl ACSPolicy {
    pub fn strict(policy_id: impl Into<String>, valid_from_ms: i64) -> Self {
        Self {
            policy_id: policy_id.into(),
            version: 1,
            valid_from_ms,
            expires_at_ms: valid_from_ms.checked_add(60_000),
            thresholds: ACSRiskThresholds::standard(),
            required_capabilities: Vec::new(),
            operation_thresholds: Vec::new(),
        }
    }

    pub fn strict_default(valid_from_ms: i64) -> Self {
        let mut policy = Self::strict("acs-strict-default", valid_from_ms)
            .require_capability(
                ACSOperationKind::MemoryWrite,
                named_capability("VaultWrite"),
            )
            .require_capability(ACSOperationKind::ToolAction, named_capability("ToolExec"))
            .require_capability(
                ACSOperationKind::ActiveAssemblyPacket,
                named_capability("Assembly"),
            )
            .require_capability(
                ACSOperationKind::KernelPromotion,
                named_capability("KernelPromote"),
            )
            .require_capability(
                ACSOperationKind::ModelAdaptation,
                named_capability("ModelAdapt"),
            );

        policy.operation_thresholds = vec![
            ACSOperationThresholdRule::new(
                ACSOperationKind::MemoryWrite,
                ACSRiskThresholds {
                    quarantine_at: 0.75,
                    ..ACSRiskThresholds::standard()
                },
            ),
            ACSOperationThresholdRule::new(
                ACSOperationKind::ToolAction,
                ACSRiskThresholds {
                    quarantine_at: 0.65,
                    ..ACSRiskThresholds::standard()
                },
            ),
            ACSOperationThresholdRule::new(
                ACSOperationKind::ActiveAssemblyPacket,
                ACSRiskThresholds {
                    defer_at: 0.55,
                    ..ACSRiskThresholds::standard()
                },
            ),
            ACSOperationThresholdRule::new(
                ACSOperationKind::KernelPromotion,
                ACSRiskThresholds {
                    quarantine_at: 0.6,
                    reject_at: 0.6,
                    ..ACSRiskThresholds::standard()
                },
            ),
            ACSOperationThresholdRule::new(
                ACSOperationKind::ModelAdaptation,
                ACSRiskThresholds {
                    defer_at: 0.5,
                    quarantine_at: 0.5,
                    reject_at: 0.5,
                    ..ACSRiskThresholds::standard()
                },
            ),
        ];
        policy
    }

    pub fn validate_at(&self, now_ms: i64) -> Result<(), ACSPolicyError> {
        self.validate_identity_and_window_shape()?;
        if now_ms < self.valid_from_ms {
            return Err(ACSPolicyError::NotYetValid);
        }
        if self
            .expires_at_ms
            .is_some_and(|expires_at_ms| now_ms > expires_at_ms)
        {
            return Err(ACSPolicyError::Expired);
        }
        self.validate_rule_shape()
    }

    fn validate_shape(&self) -> Result<(), ACSPolicyError> {
        self.validate_identity_and_window_shape()?;
        self.validate_rule_shape()
    }

    fn validate_identity_and_window_shape(&self) -> Result<(), ACSPolicyError> {
        if !is_canonical_audit_token(&self.policy_id)
            || is_reserved_policy_audit_token(&self.policy_id)
        {
            return Err(ACSPolicyError::Malformed { field: "policy_id" });
        }
        if self.version == 0 {
            return Err(ACSPolicyError::Malformed { field: "version" });
        }
        if self.valid_from_ms < 0 {
            return Err(ACSPolicyError::Malformed {
                field: "valid_from_ms",
            });
        }
        if self
            .expires_at_ms
            .is_some_and(|expires_at_ms| expires_at_ms <= self.valid_from_ms)
        {
            return Err(ACSPolicyError::Malformed {
                field: "expires_at_ms",
            });
        }
        Ok(())
    }

    fn validate_rule_shape(&self) -> Result<(), ACSPolicyError> {
        self.thresholds.validate()?;
        let mut threshold_operations = std::collections::HashSet::new();
        for rule in &self.operation_thresholds {
            if !threshold_operations.insert(rule.operation) {
                return Err(ACSPolicyError::Malformed {
                    field: "operation_thresholds.duplicate_operation",
                });
            }
            rule.thresholds
                .validate()
                .map_err(operation_threshold_policy_error)?;
        }
        let mut required_capabilities = Vec::new();
        for rule in &self.required_capabilities {
            rule.validate()?;
            if required_capabilities.iter().any(|(operation, capability)| {
                *operation == rule.operation && capability == &rule.capability
            }) {
                return Err(ACSPolicyError::Malformed {
                    field: "required_capabilities.duplicate_capability",
                });
            }
            required_capabilities.push((rule.operation, rule.capability.clone()));
        }
        Ok(())
    }

    pub fn require_capability(
        mut self,
        operation: ACSOperationKind,
        capability: Capability,
    ) -> Self {
        self.required_capabilities
            .push(ACSCapabilityRule::new(operation, capability));
        self
    }

    pub fn required_for(&self, operation: ACSOperationKind) -> Vec<Capability> {
        let mut capabilities: Vec<Capability> = self
            .required_capabilities
            .iter()
            .filter(|rule| rule.operation == operation)
            .map(|rule| rule.capability.clone())
            .collect();
        if let Some(capability) = canonical_l2_capability(operation) {
            if !capabilities.contains(&capability) {
                capabilities.push(capability);
            }
        }
        capabilities
    }

    pub fn required_for_lane(&self, lane: ACSLane) -> Vec<Capability> {
        let mut capabilities = Vec::new();
        for operation in lane.operations() {
            for capability in self.required_for(*operation) {
                if !capabilities.contains(&capability) {
                    capabilities.push(capability);
                }
            }
        }
        capabilities
    }

    pub fn strictest_thresholds_for_lane(&self, lane: ACSLane) -> ACSRiskThresholds {
        let mut strictest = self.thresholds;
        for operation in lane.operations() {
            let thresholds = self.thresholds_for(*operation);
            strictest.warn_at = strictest.warn_at.min(thresholds.warn_at);
            strictest.defer_at = strictest.defer_at.min(thresholds.defer_at);
            strictest.quarantine_at = strictest.quarantine_at.min(thresholds.quarantine_at);
            strictest.reject_at = strictest.reject_at.min(thresholds.reject_at);
        }
        strictest
    }

    pub fn thresholds_for(&self, operation: ACSOperationKind) -> ACSRiskThresholds {
        self.operation_thresholds
            .iter()
            .find(|rule| rule.operation == operation)
            .map(|rule| rule.thresholds)
            .unwrap_or(self.thresholds)
    }
}

pub(crate) fn operation_threshold_policy_error(error: ACSPolicyError) -> ACSPolicyError {
    match error.field() {
        Some("warn_at") => ACSPolicyError::Malformed {
            field: "operation_thresholds.thresholds.warn_at",
        },
        Some("defer_at") => ACSPolicyError::Malformed {
            field: "operation_thresholds.thresholds.defer_at",
        },
        Some("quarantine_at") => ACSPolicyError::Malformed {
            field: "operation_thresholds.thresholds.quarantine_at",
        },
        Some("reject_at") => ACSPolicyError::Malformed {
            field: "operation_thresholds.thresholds.reject_at",
        },
        Some("risk_threshold_order") => ACSPolicyError::Malformed {
            field: "operation_thresholds.thresholds.risk_threshold_order",
        },
        _ => error,
    }
}

pub(crate) fn named_capability(name: impl Into<String>) -> Capability {
    Capability::Other { name: name.into() }
}

/// Defensive policy validation failures.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ACSPolicyError {
    Expired,
    NotYetValid,
    Malformed { field: &'static str },
}

impl ACSPolicyError {
    pub const fn cause(&self) -> &'static str {
        match self {
            Self::Expired => "expired_policy",
            Self::NotYetValid => "policy_not_yet_valid",
            Self::Malformed { .. } => "malformed_policy",
        }
    }

    pub const fn field(&self) -> Option<&'static str> {
        match self {
            Self::Malformed { field } => Some(field),
            Self::Expired | Self::NotYetValid => None,
        }
    }
}

