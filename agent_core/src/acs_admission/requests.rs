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
use super::input::*;
use super::policy::*;
use super::proof::*;
use super::risk::*;
use super::validation::*;
use super::verdict::*;
use super::wire::*;
use super::*;

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
#[serde(deny_unknown_fields)]
pub struct ActiveAssemblyPacket {
    pub assembly_id: String,
    #[serde(default)]
    pub active_support_ids: Vec<String>,
    pub witness_hash: String,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct ActiveAssemblyPacketWire {
    assembly_id: String,
    #[serde(default)]
    active_support_ids: Vec<String>,
    witness_hash: String,
}

impl<'de> Deserialize<'de> for ActiveAssemblyPacket {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: serde::Deserializer<'de>,
    {
        let wire = ActiveAssemblyPacketWire::deserialize(deserializer)?;
        let packet = Self {
            assembly_id: wire.assembly_id,
            active_support_ids: wire.active_support_ids,
            witness_hash: wire.witness_hash,
        };
        packet
            .validate()
            .map_err(|err| serde::de::Error::custom(acs_admission_input_decode_error(&err)))?;
        Ok(packet)
    }
}

impl ActiveAssemblyPacket {
    pub(crate) fn validate(&self) -> Result<(), ACSAdmissionInputError> {
        require_non_empty(&self.assembly_id, "active_assembly.assembly_id")?;
        require_non_empty(&self.witness_hash, "active_assembly.witness_hash")?;
        if self.active_support_ids.is_empty() {
            return Err(ACSAdmissionInputError::Forged {
                field: "active_assembly.active_support_ids",
            });
        }
        for (idx, support_id) in self.active_support_ids.iter().enumerate() {
            require_non_empty(support_id, "active_assembly.active_support_ids")?;
            if self.active_support_ids[..idx]
                .iter()
                .any(|existing| existing == support_id)
            {
                return Err(ACSAdmissionInputError::Forged {
                    field: "active_assembly.active_support_ids",
                });
            }
        }
        Ok(())
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
#[serde(deny_unknown_fields)]
pub struct ACSMemoryWriteRequest {
    pub address: String,
    pub content_hash: String,
    pub durable: bool,
    pub mutation_envelope_id: Option<String>,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct ACSMemoryWriteRequestWire {
    address: String,
    content_hash: String,
    durable: bool,
    #[serde(default, deserialize_with = "deserialize_optional_string_no_null")]
    mutation_envelope_id: Option<String>,
}

impl<'de> Deserialize<'de> for ACSMemoryWriteRequest {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: serde::Deserializer<'de>,
    {
        let value = serde_json::Value::deserialize(deserializer)?;
        require_memory_write_request_known_fields::<D::Error>(&value)?;
        let wire =
            ACSMemoryWriteRequestWire::deserialize(value).map_err(serde::de::Error::custom)?;
        let request = Self {
            address: wire.address,
            content_hash: wire.content_hash,
            durable: wire.durable,
            mutation_envelope_id: wire.mutation_envelope_id,
        };
        request
            .validate()
            .map_err(|err| serde::de::Error::custom(acs_admission_input_decode_error(&err)))?;
        Ok(request)
    }
}

pub(crate) fn require_memory_write_request_known_fields<E>(
    value: &serde_json::Value,
) -> Result<(), E>
where
    E: serde::de::Error,
{
    let serde_json::Value::Object(object) = value else {
        return Ok(());
    };
    for field in object.keys() {
        if !matches!(
            field.as_str(),
            "address" | "content_hash" | "durable" | "mutation_envelope_id"
        ) {
            return Err(E::custom(format!(
                "forged_admission_input field=memory_write.{field}"
            )));
        }
    }
    Ok(())
}

impl ACSMemoryWriteRequest {
    pub(crate) fn validate(&self) -> Result<(), ACSAdmissionInputError> {
        require_non_empty(&self.address, "memory_write.address")?;
        require_non_empty(&self.content_hash, "memory_write.content_hash")?;
        if self.durable && missing_or_noncanonical_ref(self.mutation_envelope_id.as_deref()) {
            return Err(ACSAdmissionInputError::DurableWriteBypass {
                field: "memory_write.mutation_envelope_id",
            });
        }
        if !self.durable {
            require_optional_non_empty(
                self.mutation_envelope_id.as_deref(),
                "memory_write.mutation_envelope_id",
            )?;
        }
        Ok(())
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
#[serde(deny_unknown_fields)]
pub struct ACSToolActionRequest {
    pub tool_name: String,
    pub target: String,
    pub mutation_envelope_id: Option<String>,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct ACSToolActionRequestWire {
    tool_name: String,
    target: String,
    #[serde(default, deserialize_with = "deserialize_optional_string_no_null")]
    mutation_envelope_id: Option<String>,
}

impl<'de> Deserialize<'de> for ACSToolActionRequest {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: serde::Deserializer<'de>,
    {
        let value = serde_json::Value::deserialize(deserializer)?;
        require_tool_action_request_known_fields::<D::Error>(&value)?;
        let wire =
            ACSToolActionRequestWire::deserialize(value).map_err(serde::de::Error::custom)?;
        let request = Self {
            tool_name: wire.tool_name,
            target: wire.target,
            mutation_envelope_id: wire.mutation_envelope_id,
        };
        request
            .validate()
            .map_err(|err| serde::de::Error::custom(acs_admission_input_decode_error(&err)))?;
        Ok(request)
    }
}

pub(crate) fn require_tool_action_request_known_fields<E>(
    value: &serde_json::Value,
) -> Result<(), E>
where
    E: serde::de::Error,
{
    let serde_json::Value::Object(object) = value else {
        return Ok(());
    };
    for field in object.keys() {
        if !matches!(
            field.as_str(),
            "tool_name" | "target" | "mutation_envelope_id"
        ) {
            return Err(E::custom(format!(
                "forged_admission_input field=tool_action.{field}"
            )));
        }
    }
    Ok(())
}

impl ACSToolActionRequest {
    pub(crate) fn validate(&self) -> Result<(), ACSAdmissionInputError> {
        require_non_empty(&self.tool_name, "tool_action.tool_name")?;
        require_non_empty(&self.target, "tool_action.target")?;
        require_optional_non_empty(
            self.mutation_envelope_id.as_deref(),
            "tool_action.mutation_envelope_id",
        )
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
#[serde(deny_unknown_fields)]
pub struct ACSKernelPromotionRequest {
    pub kernel_id: String,
    pub signed_plan_hash: String,
    pub mutation_envelope_id: Option<String>,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct ACSKernelPromotionRequestWire {
    kernel_id: String,
    signed_plan_hash: String,
    #[serde(default, deserialize_with = "deserialize_optional_string_no_null")]
    mutation_envelope_id: Option<String>,
}

impl<'de> Deserialize<'de> for ACSKernelPromotionRequest {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: serde::Deserializer<'de>,
    {
        let value = serde_json::Value::deserialize(deserializer)?;
        require_kernel_promotion_request_known_fields::<D::Error>(&value)?;
        let wire =
            ACSKernelPromotionRequestWire::deserialize(value).map_err(serde::de::Error::custom)?;
        let request = Self {
            kernel_id: wire.kernel_id,
            signed_plan_hash: wire.signed_plan_hash,
            mutation_envelope_id: wire.mutation_envelope_id,
        };
        request
            .validate()
            .map_err(|err| serde::de::Error::custom(acs_admission_input_decode_error(&err)))?;
        Ok(request)
    }
}

pub(crate) fn require_kernel_promotion_request_known_fields<E>(
    value: &serde_json::Value,
) -> Result<(), E>
where
    E: serde::de::Error,
{
    let serde_json::Value::Object(object) = value else {
        return Ok(());
    };
    for field in object.keys() {
        if !matches!(
            field.as_str(),
            "kernel_id" | "signed_plan_hash" | "mutation_envelope_id"
        ) {
            return Err(E::custom(format!(
                "forged_admission_input field=kernel_promotion.{field}"
            )));
        }
    }
    Ok(())
}

impl ACSKernelPromotionRequest {
    pub(crate) fn validate(&self) -> Result<(), ACSAdmissionInputError> {
        require_non_empty(&self.kernel_id, "kernel_promotion.kernel_id")?;
        require_non_empty(&self.signed_plan_hash, "kernel_promotion.signed_plan_hash")?;
        if missing_or_noncanonical_ref(self.mutation_envelope_id.as_deref()) {
            return Err(ACSAdmissionInputError::KernelPromotionBypass {
                field: "kernel_promotion.mutation_envelope_id",
            });
        }
        Ok(())
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
#[serde(deny_unknown_fields)]
pub struct ACSModelAdaptationRequest {
    pub adapter_id: String,
    pub model_id: String,
    pub checkpoint_hash: String,
    pub mutation_envelope_id: Option<String>,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct ACSModelAdaptationRequestWire {
    adapter_id: String,
    model_id: String,
    checkpoint_hash: String,
    #[serde(default, deserialize_with = "deserialize_optional_string_no_null")]
    mutation_envelope_id: Option<String>,
}

impl<'de> Deserialize<'de> for ACSModelAdaptationRequest {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: serde::Deserializer<'de>,
    {
        let value = serde_json::Value::deserialize(deserializer)?;
        require_model_adaptation_request_known_fields::<D::Error>(&value)?;
        let wire =
            ACSModelAdaptationRequestWire::deserialize(value).map_err(serde::de::Error::custom)?;
        let request = Self {
            adapter_id: wire.adapter_id,
            model_id: wire.model_id,
            checkpoint_hash: wire.checkpoint_hash,
            mutation_envelope_id: wire.mutation_envelope_id,
        };
        request
            .validate()
            .map_err(|err| serde::de::Error::custom(acs_admission_input_decode_error(&err)))?;
        Ok(request)
    }
}

pub(crate) fn require_model_adaptation_request_known_fields<E>(
    value: &serde_json::Value,
) -> Result<(), E>
where
    E: serde::de::Error,
{
    let serde_json::Value::Object(object) = value else {
        return Ok(());
    };
    for field in object.keys() {
        if !matches!(
            field.as_str(),
            "adapter_id" | "model_id" | "checkpoint_hash" | "mutation_envelope_id"
        ) {
            return Err(E::custom(format!(
                "forged_admission_input field=model_adaptation.{field}"
            )));
        }
    }
    Ok(())
}

impl ACSModelAdaptationRequest {
    pub(crate) fn validate(&self) -> Result<(), ACSAdmissionInputError> {
        require_non_empty(&self.adapter_id, "model_adaptation.adapter_id")?;
        require_non_empty(&self.model_id, "model_adaptation.model_id")?;
        require_non_empty(&self.checkpoint_hash, "model_adaptation.checkpoint_hash")?;
        if missing_or_noncanonical_ref(self.mutation_envelope_id.as_deref()) {
            return Err(ACSAdmissionInputError::ModelAdaptationBypass {
                field: "model_adaptation.mutation_envelope_id",
            });
        }
        Ok(())
    }
}

pub(crate) fn require_non_empty(
    value: &str,
    field: &'static str,
) -> Result<(), ACSAdmissionInputError> {
    if value.trim().is_empty() || value != value.trim() {
        Err(ACSAdmissionInputError::Forged { field })
    } else {
        Ok(())
    }
}

pub(crate) fn require_optional_non_empty(
    value: Option<&str>,
    field: &'static str,
) -> Result<(), ACSAdmissionInputError> {
    if let Some(value) = value {
        require_non_empty(value, field)?;
    }
    Ok(())
}

pub(crate) fn require_non_negative_ms(
    value: i64,
    field: &'static str,
) -> Result<(), ACSAdmissionInputError> {
    if value < 0 {
        Err(ACSAdmissionInputError::Forged { field })
    } else {
        Ok(())
    }
}

pub(crate) fn require_lowercase_hex_digest(
    value: &str,
    byte_len: usize,
    field: &'static str,
) -> Result<(), ACSAdmissionInputError> {
    require_non_empty(value, field)?;
    if value.len() != byte_len * 2
        || !value
            .bytes()
            .all(|byte| matches!(byte, b'0'..=b'9' | b'a'..=b'f'))
    {
        Err(ACSAdmissionInputError::Forged { field })
    } else {
        Ok(())
    }
}

pub(crate) fn missing_or_noncanonical_ref(value: Option<&str>) -> bool {
    match value {
        Some(value) => value.trim().is_empty() || value != value.trim(),
        None => true,
    }
}
