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
use super::requests::*;
use super::risk::*;
use super::validation::*;
use super::verdict::*;
use super::*;

#[derive(Debug, Clone, PartialEq, Serialize)]
#[serde(rename_all = "snake_case", tag = "kind", deny_unknown_fields)]
pub enum ACSAdmissionPayload {
    MutationEnvelope { envelope: Box<MutationEnvelope> },
    ActiveAssemblyPacket { packet: ActiveAssemblyPacket },
    AnswerPacket { packet: Box<AnswerPacket> },
    MemoryWrite { request: ACSMemoryWriteRequest },
    ToolAction { request: ACSToolActionRequest },
    KernelPromotion { request: ACSKernelPromotionRequest },
    ModelAdaptation { request: ACSModelAdaptationRequest },
}

struct ACSMutationActorWire(MutationActor);

impl From<ACSMutationActorWire> for MutationActor {
    fn from(actor: ACSMutationActorWire) -> Self {
        actor.0
    }
}

impl<'de> Deserialize<'de> for ACSMutationActorWire {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: serde::Deserializer<'de>,
    {
        let value = serde_json::Value::deserialize(deserializer)?;
        let object = value
            .as_object()
            .ok_or_else(|| serde::de::Error::custom("mutation actor must be an object"))?;
        for field in object.keys() {
            if !matches!(field.as_str(), "kind" | "run_id") {
                return Err(serde::de::Error::unknown_field(
                    field.as_str(),
                    &["kind", "run_id"],
                ));
            }
        }
        let kind = object
            .get("kind")
            .ok_or_else(|| serde::de::Error::missing_field("kind"))?
            .as_str()
            .ok_or_else(|| serde::de::Error::custom("mutation actor kind must be a string"))?;
        match kind {
            "user" => {
                if object.contains_key("run_id") {
                    return Err(serde::de::Error::custom(
                        "user mutation actor must not carry run_id",
                    ));
                }
                Ok(Self(MutationActor::User))
            }
            "agent" => {
                let run_id = match object.get("run_id") {
                    Some(serde_json::Value::String(run_id)) => run_id,
                    Some(serde_json::Value::Null) => {
                        return Err(serde::de::Error::custom(
                            "agent mutation actor run_id must not be null",
                        ));
                    }
                    Some(_) => {
                        return Err(serde::de::Error::custom(
                            "agent mutation actor run_id must be a string",
                        ));
                    }
                    None => return Err(serde::de::Error::missing_field("run_id")),
                };
                Ok(Self(MutationActor::Agent {
                    run_id: run_id.to_string(),
                }))
            }
            "system" => {
                if object.contains_key("run_id") {
                    return Err(serde::de::Error::custom(
                        "system mutation actor must not carry run_id",
                    ));
                }
                Ok(Self(MutationActor::System))
            }
            _ => Err(serde::de::Error::unknown_variant(
                kind,
                &["user", "agent", "system"],
            )),
        }
    }
}

struct ACSMutationSourceOpWire(SourceOp);

impl From<ACSMutationSourceOpWire> for SourceOp {
    fn from(op: ACSMutationSourceOpWire) -> Self {
        op.0
    }
}

impl<'de> Deserialize<'de> for ACSMutationSourceOpWire {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: serde::Deserializer<'de>,
    {
        let value = serde_json::Value::deserialize(deserializer)?;
        let object = value
            .as_object()
            .ok_or_else(|| serde::de::Error::custom("mutation source op must be an object"))?;
        for field in object.keys() {
            if !matches!(
                field.as_str(),
                "kind" | "artifact_id" | "artifact_kind" | "label"
            ) {
                return Err(serde::de::Error::unknown_field(
                    field.as_str(),
                    &["kind", "artifact_id", "artifact_kind", "label"],
                ));
            }
        }
        let kind = json_string_field(object, "kind")?;
        match kind.as_str() {
            "graph_mutation" => {
                reject_json_fields(
                    object,
                    &["artifact_id", "artifact_kind", "label"],
                    "graph mutation source op must not carry payload fields",
                )?;
                Ok(Self(SourceOp::GraphMutation))
            }
            "artifact_create" => {
                reject_json_fields(
                    object,
                    &["label"],
                    "artifact_create source op must not carry label",
                )?;
                Ok(Self(SourceOp::ArtifactCreate {
                    artifact_id: json_string_field(object, "artifact_id")?,
                    artifact_kind: json_string_field(object, "artifact_kind")?,
                }))
            }
            "artifact_update" => {
                reject_json_fields(
                    object,
                    &["artifact_kind", "label"],
                    "artifact_update source op must only carry artifact_id",
                )?;
                Ok(Self(SourceOp::ArtifactUpdate {
                    artifact_id: json_string_field(object, "artifact_id")?,
                }))
            }
            "artifact_delete" => {
                reject_json_fields(
                    object,
                    &["artifact_kind", "label"],
                    "artifact_delete source op must only carry artifact_id",
                )?;
                Ok(Self(SourceOp::ArtifactDelete {
                    artifact_id: json_string_field(object, "artifact_id")?,
                }))
            }
            "other" => {
                reject_json_fields(
                    object,
                    &["artifact_id", "artifact_kind"],
                    "other source op must only carry label",
                )?;
                Ok(Self(SourceOp::Other {
                    label: json_string_field(object, "label")?,
                }))
            }
            _ => Err(serde::de::Error::unknown_variant(
                &kind,
                &[
                    "graph_mutation",
                    "artifact_create",
                    "artifact_update",
                    "artifact_delete",
                    "other",
                ],
            )),
        }
    }
}

pub(crate) fn json_string_field<E: serde::de::Error>(
    object: &serde_json::Map<String, serde_json::Value>,
    field: &'static str,
) -> Result<String, E> {
    match object.get(field) {
        Some(serde_json::Value::String(value)) => Ok(value.clone()),
        Some(serde_json::Value::Null) => Err(E::custom(format!("{field} must not be null"))),
        Some(_) => Err(E::custom(format!("{field} must be a string"))),
        None => Err(E::missing_field(field)),
    }
}

pub(crate) fn reject_json_fields<E: serde::de::Error>(
    object: &serde_json::Map<String, serde_json::Value>,
    fields: &[&'static str],
    message: &'static str,
) -> Result<(), E> {
    for field in fields {
        if object.contains_key(*field) {
            return Err(E::custom(message));
        }
    }
    Ok(())
}

pub(crate) fn deserialize_optional_string_no_null<'de, D>(
    deserializer: D,
) -> Result<Option<String>, D::Error>
where
    D: serde::Deserializer<'de>,
{
    match serde_json::Value::deserialize(deserializer)? {
        serde_json::Value::String(value) => Ok(Some(value)),
        serde_json::Value::Null => Err(serde::de::Error::custom(
            "optional string field must not be null",
        )),
        _ => Err(serde::de::Error::custom(
            "optional string field must be a string",
        )),
    }
}

pub(crate) fn deserialize_optional_i64_no_null<'de, D>(
    deserializer: D,
) -> Result<Option<i64>, D::Error>
where
    D: serde::Deserializer<'de>,
{
    match serde_json::Value::deserialize(deserializer)? {
        serde_json::Value::Number(value) => value
            .as_i64()
            .map(Some)
            .ok_or_else(|| serde::de::Error::custom("optional integer field must be an i64")),
        serde_json::Value::Null => Err(serde::de::Error::custom(
            "optional integer field must not be null",
        )),
        _ => Err(serde::de::Error::custom(
            "optional integer field must be an integer",
        )),
    }
}

pub(crate) fn deserialize_optional_artifact_kind_no_null<'de, D>(
    deserializer: D,
) -> Result<Option<crate::artifacts::ArtifactKind>, D::Error>
where
    D: serde::Deserializer<'de>,
{
    match serde_json::Value::deserialize(deserializer)? {
        serde_json::Value::Null => Err(serde::de::Error::custom(
            "optional artifact kind must not be null",
        )),
        value => crate::artifacts::ArtifactKind::deserialize(value)
            .map(Some)
            .map_err(serde::de::Error::custom),
    }
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct ACSArtifactRefWire {
    id: String,
    #[serde(
        default,
        deserialize_with = "deserialize_optional_artifact_kind_no_null"
    )]
    kind: Option<crate::artifacts::ArtifactKind>,
    #[serde(default, deserialize_with = "deserialize_optional_string_no_null")]
    title: Option<String>,
}

impl From<ACSArtifactRefWire> for ArtifactRef {
    fn from(ref_wire: ACSArtifactRefWire) -> Self {
        Self {
            id: ref_wire.id,
            kind: ref_wire.kind,
            title: ref_wire.title,
        }
    }
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct ACSBlockRefWire {
    artifact_id: String,
    block_id: String,
}

impl From<ACSBlockRefWire> for BlockRef {
    fn from(ref_wire: ACSBlockRefWire) -> Self {
        Self {
            artifact_id: ref_wire.artifact_id,
            block_id: ref_wire.block_id,
        }
    }
}

struct ACSRelationChangeWire(RelationChange);

impl From<ACSRelationChangeWire> for RelationChange {
    fn from(change: ACSRelationChangeWire) -> Self {
        change.0
    }
}

impl<'de> Deserialize<'de> for ACSRelationChangeWire {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: serde::Deserializer<'de>,
    {
        let value = serde_json::Value::deserialize(deserializer)?;
        let object = value
            .as_object()
            .ok_or_else(|| serde::de::Error::custom("relation change must be an object"))?;
        for field in object.keys() {
            if !matches!(
                field.as_str(),
                "op" | "from_id" | "to_id" | "label" | "old_label" | "new_label"
            ) {
                return Err(serde::de::Error::unknown_field(
                    field.as_str(),
                    &["op", "from_id", "to_id", "label", "old_label", "new_label"],
                ));
            }
        }
        let op = json_string_field(object, "op")?;
        match op.as_str() {
            "added" => {
                reject_json_fields(
                    object,
                    &["old_label", "new_label"],
                    "added relation change must not carry update labels",
                )?;
                Ok(Self(RelationChange::Added {
                    from_id: json_string_field(object, "from_id")?,
                    to_id: json_string_field(object, "to_id")?,
                    label: json_string_field(object, "label")?,
                }))
            }
            "removed" => {
                reject_json_fields(
                    object,
                    &["old_label", "new_label"],
                    "removed relation change must not carry update labels",
                )?;
                Ok(Self(RelationChange::Removed {
                    from_id: json_string_field(object, "from_id")?,
                    to_id: json_string_field(object, "to_id")?,
                    label: json_string_field(object, "label")?,
                }))
            }
            "updated" => {
                reject_json_fields(
                    object,
                    &["label"],
                    "updated relation change must not carry label",
                )?;
                Ok(Self(RelationChange::Updated {
                    from_id: json_string_field(object, "from_id")?,
                    to_id: json_string_field(object, "to_id")?,
                    old_label: json_string_field(object, "old_label")?,
                    new_label: json_string_field(object, "new_label")?,
                }))
            }
            _ => Err(serde::de::Error::unknown_variant(
                &op,
                &["added", "removed", "updated"],
            )),
        }
    }
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct ACSMutationEnvelopeWire {
    mutation_id: String,
    #[serde(default, deserialize_with = "deserialize_optional_string_no_null")]
    run_id: Option<String>,
    sequence: u64,
    #[serde(default, deserialize_with = "deserialize_optional_string_no_null")]
    caused_by_event_id: Option<String>,
    actor: ACSMutationActorWire,
    #[serde(default, deserialize_with = "deserialize_optional_string_no_null")]
    approval_id: Option<String>,
    status: MutationStatus,
    created_at_ms: i64,
    #[serde(default, deserialize_with = "deserialize_optional_i64_no_null")]
    committed_at_ms: Option<i64>,
    op: ACSMutationSourceOpWire,
    sensitivity: Sensitivity,
    reversibility: Reversibility,
    integrity_hash: String,
    schema_version: u32,
    #[serde(default)]
    touched_artifacts: Vec<ACSArtifactRefWire>,
    #[serde(default)]
    touched_blocks: Vec<ACSBlockRefWire>,
    #[serde(default)]
    relation_changes: Vec<ACSRelationChangeWire>,
    #[serde(default)]
    affects_summary: bool,
    #[serde(default)]
    affects_outline: bool,
    #[serde(default)]
    affects_backlinks: bool,
    #[serde(default)]
    affects_search_projection: bool,
    #[serde(default)]
    affects_graph: bool,
    #[serde(default)]
    affects_body: bool,
}

impl ACSMutationEnvelopeWire {
    fn into_envelope(self) -> MutationEnvelope {
        MutationEnvelope {
            mutation_id: self.mutation_id,
            run_id: self.run_id,
            sequence: self.sequence,
            caused_by_event_id: self.caused_by_event_id,
            actor: self.actor.into(),
            approval_id: self.approval_id,
            status: self.status,
            created_at_ms: self.created_at_ms,
            committed_at_ms: self.committed_at_ms,
            op: self.op.into(),
            sensitivity: self.sensitivity,
            reversibility: self.reversibility,
            integrity_hash: self.integrity_hash,
            schema_version: self.schema_version,
            touched_artifacts: self.touched_artifacts.into_iter().map(Into::into).collect(),
            touched_blocks: self.touched_blocks.into_iter().map(Into::into).collect(),
            relation_changes: self.relation_changes.into_iter().map(Into::into).collect(),
            affects_summary: self.affects_summary,
            affects_outline: self.affects_outline,
            affects_backlinks: self.affects_backlinks,
            affects_search_projection: self.affects_search_projection,
            affects_graph: self.affects_graph,
            affects_body: self.affects_body,
        }
    }
}

#[derive(Deserialize)]
#[serde(rename_all = "snake_case", tag = "kind", deny_unknown_fields)]
enum ACSAdmissionPayloadWire {
    MutationEnvelope {
        envelope: Box<ACSMutationEnvelopeWire>,
    },
    ActiveAssemblyPacket {
        packet: ActiveAssemblyPacket,
    },
    AnswerPacket {
        packet: Box<AnswerPacket>,
    },
    MemoryWrite {
        request: ACSMemoryWriteRequest,
    },
    ToolAction {
        request: ACSToolActionRequest,
    },
    KernelPromotion {
        request: ACSKernelPromotionRequest,
    },
    ModelAdaptation {
        request: ACSModelAdaptationRequest,
    },
}

impl<'de> Deserialize<'de> for ACSAdmissionPayload {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: serde::Deserializer<'de>,
    {
        let wire = ACSAdmissionPayloadWire::deserialize(deserializer)?;
        let payload = match wire {
            ACSAdmissionPayloadWire::MutationEnvelope { envelope } => Self::MutationEnvelope {
                envelope: Box::new(envelope.into_envelope()),
            },
            ACSAdmissionPayloadWire::ActiveAssemblyPacket { packet } => {
                Self::ActiveAssemblyPacket { packet }
            }
            ACSAdmissionPayloadWire::AnswerPacket { packet } => Self::AnswerPacket { packet },
            ACSAdmissionPayloadWire::MemoryWrite { request } => Self::MemoryWrite { request },
            ACSAdmissionPayloadWire::ToolAction { request } => Self::ToolAction { request },
            ACSAdmissionPayloadWire::KernelPromotion { request } => {
                Self::KernelPromotion { request }
            }
            ACSAdmissionPayloadWire::ModelAdaptation { request } => {
                Self::ModelAdaptation { request }
            }
        };
        payload
            .validate()
            .map_err(|err| serde::de::Error::custom(acs_admission_input_decode_error(&err)))?;
        Ok(payload)
    }
}

impl ACSAdmissionPayload {
    pub const fn operation(&self) -> ACSOperationKind {
        match self {
            Self::MutationEnvelope { .. } => ACSOperationKind::MutationEnvelope,
            Self::ActiveAssemblyPacket { .. } => ACSOperationKind::ActiveAssemblyPacket,
            Self::AnswerPacket { .. } => ACSOperationKind::AnswerPacket,
            Self::MemoryWrite { .. } => ACSOperationKind::MemoryWrite,
            Self::ToolAction { .. } => ACSOperationKind::ToolAction,
            Self::KernelPromotion { .. } => ACSOperationKind::KernelPromotion,
            Self::ModelAdaptation { .. } => ACSOperationKind::ModelAdaptation,
        }
    }

    pub const fn lane(&self) -> ACSLane {
        self.operation().lane()
    }

    pub const fn product_lane_code(&self) -> &'static str {
        self.lane().product_lane_code()
    }

    pub(crate) fn validate(&self) -> Result<(), ACSAdmissionInputError> {
        match self {
            Self::MutationEnvelope { envelope } => validate_mutation_envelope(envelope),
            Self::ActiveAssemblyPacket { packet } => packet.validate(),
            Self::AnswerPacket { packet } => validate_answer_packet(packet),
            Self::MemoryWrite { request } => request.validate(),
            Self::ToolAction { request } => request.validate(),
            Self::KernelPromotion { request } => request.validate(),
            Self::ModelAdaptation { request } => request.validate(),
        }
    }
}
