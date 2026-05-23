//! ACS admission field.
//!
//! ACS (Anchored Cognitive Substrate / Autopoietic Cognitive Stack)
//! admission is a policy boundary above SCOPE-Rex. It is intentionally
//! pure-data: it does not call cloud providers, run inference, or apply
//! durable state changes directly.

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

pub const ACS_AUDIT_RUN_EVENT_KEY: &str = "acs.audit.record";
const SCOPE_REX_ADMISSION_PROOF_DOMAIN: &[u8] = b"epistemos.acs.scope_rex_admission_proof.v1";
const CAPABILITY_SIGNATURE_BYTES: usize = 32;
const MUTATION_INTEGRITY_HASH_BYTES: usize = 32;
const MALFORMED_REQUEST_AUDIT_PREFIX: &str = "malformed_request";
const MALFORMED_POLICY_AUDIT_PREFIX: &str = "malformed_policy";

/// Risk vector evaluated by ACS admission before a request can become
/// durable or promote into a stronger runtime lane.
#[derive(Debug, Clone, Copy, PartialEq, Serialize)]
#[serde(deny_unknown_fields)]
pub struct ACSRiskVector {
    pub truth_risk: f32,
    pub safety_risk: f32,
    pub privacy_risk: f32,
    pub capability_risk: f32,
    pub durability_risk: f32,
    pub scope_rex_risk: f32,
    pub kernel_promotion_risk: f32,
    pub model_adaptation_risk: f32,
    pub evidence_present: bool,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct ACSRiskVectorWire {
    truth_risk: f32,
    safety_risk: f32,
    privacy_risk: f32,
    capability_risk: f32,
    durability_risk: f32,
    scope_rex_risk: f32,
    kernel_promotion_risk: f32,
    model_adaptation_risk: f32,
    evidence_present: bool,
}

impl<'de> Deserialize<'de> for ACSRiskVector {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: serde::Deserializer<'de>,
    {
        let value = serde_json::Value::deserialize(deserializer)?;
        require_risk_vector_known_fields::<D::Error>(&value)?;
        require_risk_number_field::<D::Error>(&value, "truth_risk")?;
        require_risk_number_field::<D::Error>(&value, "safety_risk")?;
        require_risk_number_field::<D::Error>(&value, "privacy_risk")?;
        require_risk_number_field::<D::Error>(&value, "capability_risk")?;
        require_risk_number_field::<D::Error>(&value, "durability_risk")?;
        require_risk_number_field::<D::Error>(&value, "scope_rex_risk")?;
        require_risk_number_field::<D::Error>(&value, "kernel_promotion_risk")?;
        require_risk_number_field::<D::Error>(&value, "model_adaptation_risk")?;
        require_risk_bool_field::<D::Error>(&value, "evidence_present")?;
        let wire = ACSRiskVectorWire::deserialize(value).map_err(serde::de::Error::custom)?;
        let risk = Self {
            truth_risk: wire.truth_risk,
            safety_risk: wire.safety_risk,
            privacy_risk: wire.privacy_risk,
            capability_risk: wire.capability_risk,
            durability_risk: wire.durability_risk,
            scope_rex_risk: wire.scope_rex_risk,
            kernel_promotion_risk: wire.kernel_promotion_risk,
            model_adaptation_risk: wire.model_adaptation_risk,
            evidence_present: wire.evidence_present,
        };
        risk.validate()
            .map_err(|err| serde::de::Error::custom(acs_risk_vector_decode_error(&err)))?;
        Ok(risk)
    }
}

fn require_risk_number_field<E>(value: &serde_json::Value, field: &'static str) -> Result<(), E>
where
    E: serde::de::Error,
{
    match value {
        serde_json::Value::Object(object)
            if object.get(field).is_some_and(serde_json::Value::is_number) =>
        {
            Ok(())
        }
        serde_json::Value::Object(object) if object.contains_key(field) => {
            Err(E::custom(format!("malformed_risk_axis field=risk.{field}")))
        }
        serde_json::Value::Object(_) => {
            Err(E::custom(format!("missing_risk_axis field=risk.{field}")))
        }
        _ => Err(E::custom("malformed_risk_vector field=risk")),
    }
}

fn require_risk_bool_field<E>(value: &serde_json::Value, field: &'static str) -> Result<(), E>
where
    E: serde::de::Error,
{
    match value {
        serde_json::Value::Object(object)
            if object.get(field).is_some_and(serde_json::Value::is_boolean) =>
        {
            Ok(())
        }
        serde_json::Value::Object(object) if object.contains_key(field) => Err(E::custom(format!(
            "malformed_risk_field field=risk.{field}"
        ))),
        serde_json::Value::Object(_) => {
            Err(E::custom(format!("missing_risk_axis field=risk.{field}")))
        }
        _ => Err(E::custom("malformed_risk_vector field=risk")),
    }
}

fn require_risk_vector_known_fields<E>(value: &serde_json::Value) -> Result<(), E>
where
    E: serde::de::Error,
{
    let serde_json::Value::Object(object) = value else {
        return Err(E::custom("malformed_risk_vector field=risk"));
    };
    for field in object.keys() {
        if !matches!(
            field.as_str(),
            "truth_risk"
                | "safety_risk"
                | "privacy_risk"
                | "capability_risk"
                | "durability_risk"
                | "scope_rex_risk"
                | "kernel_promotion_risk"
                | "model_adaptation_risk"
                | "evidence_present"
        ) {
            return Err(E::custom(format!(
                "malformed_risk_vector field=risk.{field}"
            )));
        }
    }
    Ok(())
}

impl ACSRiskVector {
    pub const fn neutral() -> Self {
        Self {
            truth_risk: 0.0,
            safety_risk: 0.0,
            privacy_risk: 0.0,
            capability_risk: 0.0,
            durability_risk: 0.0,
            scope_rex_risk: 0.0,
            kernel_promotion_risk: 0.0,
            model_adaptation_risk: 0.0,
            evidence_present: true,
        }
    }

    pub fn validate(&self) -> Result<(), ACSRiskVectorError> {
        for (field, value) in self.fields() {
            if !value.is_finite() {
                return Err(ACSRiskVectorError::NonFinite { field });
            }
            if !(0.0..=1.0).contains(&value) {
                return Err(ACSRiskVectorError::OutOfRange { field });
            }
        }
        Ok(())
    }

    pub fn max_axis(&self) -> f32 {
        self.fields()
            .into_iter()
            .map(|(_, value)| value)
            .fold(0.0, f32::max)
    }

    fn fields(&self) -> [(&'static str, f32); 8] {
        [
            ("truth_risk", self.truth_risk),
            ("safety_risk", self.safety_risk),
            ("privacy_risk", self.privacy_risk),
            ("capability_risk", self.capability_risk),
            ("durability_risk", self.durability_risk),
            ("scope_rex_risk", self.scope_rex_risk),
            ("kernel_promotion_risk", self.kernel_promotion_risk),
            ("model_adaptation_risk", self.model_adaptation_risk),
        ]
    }
}

/// Defensive validation failures for [`ACSRiskVector`].
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ACSRiskVectorError {
    NonFinite { field: &'static str },
    OutOfRange { field: &'static str },
}

impl ACSRiskVectorError {
    pub const fn cause(&self) -> &'static str {
        match self {
            Self::NonFinite { .. } => "non_finite_risk_axis",
            Self::OutOfRange { .. } => "risk_axis_out_of_range",
        }
    }

    pub const fn field(&self) -> &'static str {
        match self {
            Self::NonFinite { field } | Self::OutOfRange { field } => field,
        }
    }
}

fn acs_risk_vector_decode_error(error: &ACSRiskVectorError) -> String {
    format!("{} field=risk.{}", error.cause(), error.field())
}

/// Admission operation family used by policy capability rules.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ACSOperationKind {
    MutationEnvelope,
    ActiveAssemblyPacket,
    AnswerPacket,
    MemoryWrite,
    ToolAction,
    KernelPromotion,
    ModelAdaptation,
}

impl ACSOperationKind {
    pub const fn lane(self) -> ACSLane {
        match self {
            Self::MutationEnvelope | Self::AnswerPacket | Self::MemoryWrite => ACSLane::L0,
            Self::ToolAction | Self::ActiveAssemblyPacket => ACSLane::L1,
            Self::KernelPromotion | Self::ModelAdaptation => ACSLane::L2,
        }
    }

    pub const fn code(self) -> &'static str {
        match self {
            Self::MutationEnvelope => "mutation_envelope",
            Self::ActiveAssemblyPacket => "active_assembly_packet",
            Self::AnswerPacket => "answer_packet",
            Self::MemoryWrite => "memory_write",
            Self::ToolAction => "tool_action",
            Self::KernelPromotion => "kernel_promotion",
            Self::ModelAdaptation => "model_adaptation",
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ACSLane {
    L0,
    L1,
    L2,
}

const ACS_L0_OPERATIONS: [ACSOperationKind; 3] = [
    ACSOperationKind::MutationEnvelope,
    ACSOperationKind::MemoryWrite,
    ACSOperationKind::AnswerPacket,
];
const ACS_L1_OPERATIONS: [ACSOperationKind; 2] = [
    ACSOperationKind::ToolAction,
    ACSOperationKind::ActiveAssemblyPacket,
];
const ACS_L2_OPERATIONS: [ACSOperationKind; 2] = [
    ACSOperationKind::KernelPromotion,
    ACSOperationKind::ModelAdaptation,
];

impl ACSLane {
    pub const fn operations(self) -> &'static [ACSOperationKind] {
        match self {
            Self::L0 => &ACS_L0_OPERATIONS,
            Self::L1 => &ACS_L1_OPERATIONS,
            Self::L2 => &ACS_L2_OPERATIONS,
        }
    }

    pub const fn product_lane_code(self) -> &'static str {
        match self {
            Self::L0 => "event_governance",
            Self::L1 => "agent_tool_loops",
            Self::L2 => "self_healing_research",
        }
    }
}

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

fn json_string_field<E: serde::de::Error>(
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

fn reject_json_fields<E: serde::de::Error>(
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

fn deserialize_optional_string_no_null<'de, D>(deserializer: D) -> Result<Option<String>, D::Error>
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

fn deserialize_optional_i64_no_null<'de, D>(deserializer: D) -> Result<Option<i64>, D::Error>
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

fn deserialize_optional_artifact_kind_no_null<'de, D>(
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

    fn validate(&self) -> Result<(), ACSAdmissionInputError> {
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

fn validate_answer_packet(packet: &AnswerPacket) -> Result<(), ACSAdmissionInputError> {
    require_non_empty(&packet.id.0, "answer_packet.id")?;
    for (idx, claim) in packet.claims.iter().enumerate() {
        require_non_empty(&claim.id.0, "answer_packet.claims.id")?;
        require_non_empty(&claim.text, "answer_packet.claims.text")?;
        require_non_negative_ms(claim.created_at_ms, "answer_packet.claims.created_at_ms")?;
        if packet.claims[..idx]
            .iter()
            .any(|existing| existing.id == claim.id)
        {
            return Err(ACSAdmissionInputError::Forged {
                field: "answer_packet.claims.id",
            });
        }
    }
    for signal in &packet.residency_signals {
        require_normalized_signal(
            signal.safety_risk,
            "answer_packet.residency_signals.safety_risk",
        )?;
        require_normalized_signal(signal.privacy, "answer_packet.residency_signals.privacy")?;
        require_normalized_signal(
            signal.verification_score,
            "answer_packet.residency_signals.verification_score",
        )?;
        require_finite_signal(signal.gain, "answer_packet.residency_signals.gain")?;
        require_normalized_signal(
            signal.forgetting,
            "answer_packet.residency_signals.forgetting",
        )?;
    }
    require_answer_packet_label_consistency(packet)?;
    require_non_empty(
        &packet.witnessed_state_ref.0,
        "answer_packet.witnessed_state_ref",
    )?;
    require_optional_non_empty(
        packet.semantic_delta_ref.as_ref().map(|id| id.0.as_str()),
        "answer_packet.semantic_delta_ref",
    )?;
    if !packet.attention_mode_claims_are_consistent() {
        return Err(ACSAdmissionInputError::Forged {
            field: "answer_packet.attention_mode",
        });
    }
    require_non_empty(
        &packet.mutation_envelope_ref.0,
        "answer_packet.mutation_envelope_ref",
    )
}

fn require_answer_packet_label_consistency(
    packet: &AnswerPacket,
) -> Result<(), ACSAdmissionInputError> {
    let has_quarantine_signal = packet
        .residency_signals
        .iter()
        .any(|signal| route_residency(signal) == Residency::Quarantine);

    if packet.ui_label == VrmLabel::Blocked && !has_quarantine_signal {
        return Err(ACSAdmissionInputError::Forged {
            field: "answer_packet.ui_label",
        });
    }

    if packet.ui_label == VrmLabel::Blocked
        && packet.claims.iter().any(is_active_positive_answer_claim)
    {
        return Err(ACSAdmissionInputError::Forged {
            field: "answer_packet.ui_label",
        });
    }

    if packet.ui_label != VrmLabel::Blocked && has_quarantine_signal {
        return Err(ACSAdmissionInputError::Forged {
            field: "answer_packet.ui_label",
        });
    }

    if packet.ui_label == VrmLabel::Speculative
        && !packet.claims.iter().any(is_active_speculative_answer_claim)
    {
        return Err(ACSAdmissionInputError::Forged {
            field: "answer_packet.ui_label",
        });
    }

    if packet.ui_label == VrmLabel::Speculative
        && packet
            .claims
            .iter()
            .any(is_active_non_speculative_answer_claim)
    {
        return Err(ACSAdmissionInputError::Forged {
            field: "answer_packet.ui_label",
        });
    }

    if packet.ui_label == VrmLabel::Speculative
        && packet.claims.iter().any(is_non_active_gap_answer_claim)
    {
        return Err(ACSAdmissionInputError::Forged {
            field: "answer_packet.ui_label",
        });
    }

    if packet.ui_label == VrmLabel::PlausibleButUnverified {
        if !packet.claims.iter().any(is_active_plausible_answer_claim) {
            return Err(ACSAdmissionInputError::Forged {
                field: "answer_packet.ui_label",
            });
        }
        if packet
            .claims
            .iter()
            .any(is_active_non_plausible_answer_claim)
        {
            return Err(ACSAdmissionInputError::Forged {
                field: "answer_packet.ui_label",
            });
        }
        if packet.claims.iter().any(is_non_active_gap_answer_claim) {
            return Err(ACSAdmissionInputError::Forged {
                field: "answer_packet.ui_label",
            });
        }
    }

    if packet.ui_label != VrmLabel::Verified {
        return Ok(());
    }

    if packet
        .residency_signals
        .iter()
        .any(|signal| signal.verification_score < 0.5)
    {
        return Err(ACSAdmissionInputError::Forged {
            field: "answer_packet.ui_label",
        });
    }

    if packet.claims.iter().any(is_active_unverified_answer_claim) {
        return Err(ACSAdmissionInputError::Forged {
            field: "answer_packet.ui_label",
        });
    }

    if packet.claims.iter().any(is_non_active_gap_answer_claim) {
        return Err(ACSAdmissionInputError::Forged {
            field: "answer_packet.ui_label",
        });
    }

    if packet
        .claims
        .iter()
        .any(is_non_active_verifying_answer_claim)
    {
        return Err(ACSAdmissionInputError::Forged {
            field: "answer_packet.ui_label",
        });
    }

    if packet.claims.iter().any(is_active_verifying_answer_claim) {
        Ok(())
    } else {
        Err(ACSAdmissionInputError::Forged {
            field: "answer_packet.ui_label",
        })
    }
}

fn is_active_verifying_answer_claim(claim: &Claim) -> bool {
    is_active_answer_claim(claim)
        && matches!(
            claim.kind,
            ClaimKind::Empirical | ClaimKind::Mathematical | ClaimKind::CodeInvariant
        )
}

fn is_non_active_verifying_answer_claim(claim: &Claim) -> bool {
    !is_active_answer_claim(claim)
        && matches!(
            claim.kind,
            ClaimKind::Empirical | ClaimKind::Mathematical | ClaimKind::CodeInvariant
        )
}

fn is_active_positive_answer_claim(claim: &Claim) -> bool {
    is_active_answer_claim(claim)
        && matches!(
            claim.kind,
            ClaimKind::Empirical
                | ClaimKind::Mathematical
                | ClaimKind::CodeInvariant
                | ClaimKind::Causal
                | ClaimKind::Speculative
        )
}

fn is_active_speculative_answer_claim(claim: &Claim) -> bool {
    is_active_answer_claim(claim) && claim.kind == ClaimKind::Speculative
}

fn is_active_plausible_answer_claim(claim: &Claim) -> bool {
    is_active_answer_claim(claim) && matches!(claim.kind, ClaimKind::Empirical | ClaimKind::Causal)
}

fn is_active_non_speculative_answer_claim(claim: &Claim) -> bool {
    is_active_answer_claim(claim)
        && matches!(
            claim.kind,
            ClaimKind::Empirical
                | ClaimKind::Mathematical
                | ClaimKind::CodeInvariant
                | ClaimKind::Causal
        )
}

fn is_active_non_plausible_answer_claim(claim: &Claim) -> bool {
    is_active_answer_claim(claim)
        && matches!(
            claim.kind,
            ClaimKind::Mathematical | ClaimKind::CodeInvariant | ClaimKind::Speculative
        )
}

fn is_non_active_gap_answer_claim(claim: &Claim) -> bool {
    !is_active_answer_claim(claim)
        && matches!(
            claim.kind,
            ClaimKind::Empirical
                | ClaimKind::Mathematical
                | ClaimKind::CodeInvariant
                | ClaimKind::Causal
                | ClaimKind::Speculative
        )
}

fn is_active_unverified_answer_claim(claim: &Claim) -> bool {
    is_active_answer_claim(claim)
        && matches!(claim.kind, ClaimKind::Causal | ClaimKind::Speculative)
}

fn is_active_answer_claim(claim: &Claim) -> bool {
    claim.status == ClaimStatus::Active
}

fn require_finite_signal(value: f32, field: &'static str) -> Result<(), ACSAdmissionInputError> {
    if value.is_finite() {
        Ok(())
    } else {
        Err(ACSAdmissionInputError::Forged { field })
    }
}

fn require_normalized_signal(
    value: f32,
    field: &'static str,
) -> Result<(), ACSAdmissionInputError> {
    require_finite_signal(value, field)?;
    if (0.0..=1.0).contains(&value) {
        Ok(())
    } else {
        Err(ACSAdmissionInputError::Forged { field })
    }
}

fn validate_mutation_envelope(envelope: &MutationEnvelope) -> Result<(), ACSAdmissionInputError> {
    require_non_empty(&envelope.mutation_id, "mutation_envelope.mutation_id")?;
    require_optional_non_empty(envelope.run_id.as_deref(), "mutation_envelope.run_id")?;
    require_optional_non_empty(
        envelope.caused_by_event_id.as_deref(),
        "mutation_envelope.caused_by_event_id",
    )?;
    require_optional_non_empty(
        envelope.approval_id.as_deref(),
        "mutation_envelope.approval_id",
    )?;
    require_non_negative_ms(envelope.created_at_ms, "mutation_envelope.created_at_ms")?;
    if let Some(committed_at_ms) = envelope.committed_at_ms {
        require_non_negative_ms(committed_at_ms, "mutation_envelope.committed_at_ms")?;
        if committed_at_ms < envelope.created_at_ms {
            return Err(ACSAdmissionInputError::Forged {
                field: "mutation_envelope.committed_at_ms",
            });
        }
    }
    if matches!(
        envelope.status,
        MutationStatus::Pending | MutationStatus::Failed
    ) && envelope.committed_at_ms.is_some()
    {
        return Err(ACSAdmissionInputError::Forged {
            field: "mutation_envelope.committed_at_ms",
        });
    }
    if matches!(
        envelope.status,
        MutationStatus::Committed | MutationStatus::Reverted
    ) && envelope.committed_at_ms.is_none()
    {
        return Err(ACSAdmissionInputError::Forged {
            field: "mutation_envelope.committed_at_ms",
        });
    }
    if envelope.status == MutationStatus::Reverted
        && envelope.reversibility == Reversibility::Irreversible
    {
        return Err(ACSAdmissionInputError::Forged {
            field: "mutation_envelope.reversibility",
        });
    }
    if envelope.status != MutationStatus::Pending && envelope.integrity_hash.is_empty() {
        return Err(ACSAdmissionInputError::Forged {
            field: "mutation_envelope.integrity_hash",
        });
    }
    if !envelope.integrity_hash.is_empty() {
        require_lowercase_hex_digest(
            &envelope.integrity_hash,
            MUTATION_INTEGRITY_HASH_BYTES,
            "mutation_envelope.integrity_hash",
        )?;
    }
    if envelope.schema_version == 0 {
        return Err(ACSAdmissionInputError::Forged {
            field: "mutation_envelope.schema_version",
        });
    }
    validate_mutation_actor(&envelope.actor)?;
    if let MutationActor::Agent {
        run_id: actor_run_id,
    } = &envelope.actor
    {
        match envelope.run_id.as_deref() {
            Some(envelope_run_id) if envelope_run_id == actor_run_id => {}
            _ => {
                return Err(ACSAdmissionInputError::Forged {
                    field: "mutation_envelope.run_id",
                });
            }
        }
    }
    validate_mutation_source_op(&envelope.op)?;
    validate_mutation_touched_artifacts(&envelope.touched_artifacts)?;
    validate_mutation_touched_blocks(&envelope.touched_blocks)?;
    validate_mutation_relation_changes(&envelope.relation_changes)?;
    Ok(())
}

fn validate_mutation_touched_artifacts(
    artifacts: &[ArtifactRef],
) -> Result<(), ACSAdmissionInputError> {
    for (idx, artifact) in artifacts.iter().enumerate() {
        require_non_empty(
            &artifact.id,
            "mutation_envelope.touched_artifacts.artifact_id",
        )?;
        require_optional_non_empty(
            artifact.title.as_deref(),
            "mutation_envelope.touched_artifacts.title",
        )?;
        if artifacts[..idx]
            .iter()
            .any(|existing| existing.id == artifact.id)
        {
            return Err(ACSAdmissionInputError::Forged {
                field: "mutation_envelope.touched_artifacts.artifact_id",
            });
        }
    }
    Ok(())
}

fn validate_mutation_touched_blocks(blocks: &[BlockRef]) -> Result<(), ACSAdmissionInputError> {
    for (idx, block) in blocks.iter().enumerate() {
        require_non_empty(
            &block.artifact_id,
            "mutation_envelope.touched_blocks.artifact_id",
        )?;
        require_non_empty(&block.block_id, "mutation_envelope.touched_blocks.block_id")?;
        if blocks[..idx].iter().any(|existing| {
            existing.artifact_id == block.artifact_id && existing.block_id == block.block_id
        }) {
            return Err(ACSAdmissionInputError::Forged {
                field: "mutation_envelope.touched_blocks.block_id",
            });
        }
    }
    Ok(())
}

fn validate_mutation_relation_changes(
    changes: &[RelationChange],
) -> Result<(), ACSAdmissionInputError> {
    for (idx, change) in changes.iter().enumerate() {
        match change {
            RelationChange::Added {
                from_id,
                to_id,
                label,
            }
            | RelationChange::Removed {
                from_id,
                to_id,
                label,
            } => {
                validate_mutation_relation_endpoints(from_id, to_id)?;
                require_non_empty(label, "mutation_envelope.relation_changes.label")?;
            }
            RelationChange::Updated {
                from_id,
                to_id,
                old_label,
                new_label,
            } => {
                validate_mutation_relation_endpoints(from_id, to_id)?;
                require_non_empty(old_label, "mutation_envelope.relation_changes.old_label")?;
                require_non_empty(new_label, "mutation_envelope.relation_changes.new_label")?;
                if old_label == new_label {
                    return Err(ACSAdmissionInputError::Forged {
                        field: "mutation_envelope.relation_changes.new_label",
                    });
                }
            }
        }
        if changes[..idx].iter().any(|existing| {
            relation_change_matches(existing, change) || relation_change_conflicts(existing, change)
        }) {
            return Err(ACSAdmissionInputError::Forged {
                field: "mutation_envelope.relation_changes",
            });
        }
    }
    Ok(())
}

fn relation_change_matches(left: &RelationChange, right: &RelationChange) -> bool {
    match (left, right) {
        (
            RelationChange::Added {
                from_id: left_from_id,
                to_id: left_to_id,
                label: left_label,
            },
            RelationChange::Added {
                from_id: right_from_id,
                to_id: right_to_id,
                label: right_label,
            },
        )
        | (
            RelationChange::Removed {
                from_id: left_from_id,
                to_id: left_to_id,
                label: left_label,
            },
            RelationChange::Removed {
                from_id: right_from_id,
                to_id: right_to_id,
                label: right_label,
            },
        ) => {
            left_from_id == right_from_id && left_to_id == right_to_id && left_label == right_label
        }
        (
            RelationChange::Updated {
                from_id: left_from_id,
                to_id: left_to_id,
                old_label: left_old_label,
                new_label: left_new_label,
            },
            RelationChange::Updated {
                from_id: right_from_id,
                to_id: right_to_id,
                old_label: right_old_label,
                new_label: right_new_label,
            },
        ) => {
            left_from_id == right_from_id
                && left_to_id == right_to_id
                && left_old_label == right_old_label
                && left_new_label == right_new_label
        }
        _ => false,
    }
}

fn relation_change_conflicts(left: &RelationChange, right: &RelationChange) -> bool {
    match (left, right) {
        (
            RelationChange::Added {
                from_id: left_from_id,
                to_id: left_to_id,
                label: left_label,
            },
            RelationChange::Removed {
                from_id: right_from_id,
                to_id: right_to_id,
                label: right_label,
            },
        )
        | (
            RelationChange::Removed {
                from_id: left_from_id,
                to_id: left_to_id,
                label: left_label,
            },
            RelationChange::Added {
                from_id: right_from_id,
                to_id: right_to_id,
                label: right_label,
            },
        ) => {
            left_from_id == right_from_id && left_to_id == right_to_id && left_label == right_label
        }
        (
            RelationChange::Updated {
                from_id: left_from_id,
                to_id: left_to_id,
                old_label: left_old_label,
                new_label: left_new_label,
            },
            RelationChange::Added {
                from_id: right_from_id,
                to_id: right_to_id,
                label: right_label,
            },
        ) => {
            left_from_id == right_from_id
                && left_to_id == right_to_id
                && (left_new_label == right_label || left_old_label == right_label)
        }
        (
            RelationChange::Added {
                from_id: left_from_id,
                to_id: left_to_id,
                label: left_label,
            },
            RelationChange::Updated {
                from_id: right_from_id,
                to_id: right_to_id,
                old_label: right_old_label,
                new_label: right_new_label,
            },
        ) => {
            left_from_id == right_from_id
                && left_to_id == right_to_id
                && (left_label == right_new_label || left_label == right_old_label)
        }
        (
            RelationChange::Updated {
                from_id: left_from_id,
                to_id: left_to_id,
                old_label: left_old_label,
                new_label: left_new_label,
            },
            RelationChange::Removed {
                from_id: right_from_id,
                to_id: right_to_id,
                label: right_label,
            },
        ) => {
            left_from_id == right_from_id
                && left_to_id == right_to_id
                && (left_old_label == right_label || left_new_label == right_label)
        }
        (
            RelationChange::Removed {
                from_id: left_from_id,
                to_id: left_to_id,
                label: left_label,
            },
            RelationChange::Updated {
                from_id: right_from_id,
                to_id: right_to_id,
                old_label: right_old_label,
                new_label: right_new_label,
            },
        ) => {
            left_from_id == right_from_id
                && left_to_id == right_to_id
                && (left_label == right_old_label || left_label == right_new_label)
        }
        (
            RelationChange::Updated {
                from_id: left_from_id,
                to_id: left_to_id,
                old_label: left_old_label,
                new_label: left_new_label,
            },
            RelationChange::Updated {
                from_id: right_from_id,
                to_id: right_to_id,
                old_label: right_old_label,
                new_label: right_new_label,
            },
        ) => {
            left_from_id == right_from_id
                && left_to_id == right_to_id
                && (left_old_label == right_old_label
                    || left_new_label == right_old_label
                    || left_old_label == right_new_label
                    || left_new_label == right_new_label)
        }
        _ => false,
    }
}

fn validate_mutation_relation_endpoints(
    from_id: &str,
    to_id: &str,
) -> Result<(), ACSAdmissionInputError> {
    require_non_empty(from_id, "mutation_envelope.relation_changes.from_id")?;
    require_non_empty(to_id, "mutation_envelope.relation_changes.to_id")
}

fn validate_mutation_actor(actor: &MutationActor) -> Result<(), ACSAdmissionInputError> {
    match actor {
        MutationActor::Agent { run_id } => {
            require_non_empty(run_id, "mutation_envelope.actor.run_id")?;
        }
        MutationActor::User | MutationActor::System => {}
    }
    Ok(())
}

fn validate_mutation_source_op(op: &SourceOp) -> Result<(), ACSAdmissionInputError> {
    match op {
        SourceOp::ArtifactCreate {
            artifact_id,
            artifact_kind,
        } => {
            require_non_empty(artifact_id, "mutation_envelope.op.artifact_id")?;
            require_non_empty(artifact_kind, "mutation_envelope.op.artifact_kind")?;
        }
        SourceOp::ArtifactUpdate { artifact_id } | SourceOp::ArtifactDelete { artifact_id } => {
            require_non_empty(artifact_id, "mutation_envelope.op.artifact_id")?;
        }
        SourceOp::Other { label } => {
            require_non_empty(label, "mutation_envelope.op.label")?;
        }
        SourceOp::GraphMutation => {}
    }
    Ok(())
}

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
    fn validate(&self) -> Result<(), ACSAdmissionInputError> {
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

fn require_memory_write_request_known_fields<E>(value: &serde_json::Value) -> Result<(), E>
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
    fn validate(&self) -> Result<(), ACSAdmissionInputError> {
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

fn require_tool_action_request_known_fields<E>(value: &serde_json::Value) -> Result<(), E>
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
    fn validate(&self) -> Result<(), ACSAdmissionInputError> {
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

fn require_kernel_promotion_request_known_fields<E>(value: &serde_json::Value) -> Result<(), E>
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
    fn validate(&self) -> Result<(), ACSAdmissionInputError> {
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

fn require_model_adaptation_request_known_fields<E>(value: &serde_json::Value) -> Result<(), E>
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
    fn validate(&self) -> Result<(), ACSAdmissionInputError> {
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

fn require_non_empty(value: &str, field: &'static str) -> Result<(), ACSAdmissionInputError> {
    if value.trim().is_empty() || value != value.trim() {
        Err(ACSAdmissionInputError::Forged { field })
    } else {
        Ok(())
    }
}

fn require_optional_non_empty(
    value: Option<&str>,
    field: &'static str,
) -> Result<(), ACSAdmissionInputError> {
    if let Some(value) = value {
        require_non_empty(value, field)?;
    }
    Ok(())
}

fn require_non_negative_ms(value: i64, field: &'static str) -> Result<(), ACSAdmissionInputError> {
    if value < 0 {
        Err(ACSAdmissionInputError::Forged { field })
    } else {
        Ok(())
    }
}

fn require_lowercase_hex_digest(
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

fn missing_or_noncanonical_ref(value: Option<&str>) -> bool {
    match value {
        Some(value) => value.trim().is_empty() || value != value.trim(),
        None => true,
    }
}

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

fn require_admission_input_known_fields<E>(value: &serde_json::Value) -> Result<(), E>
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

fn admission_input_wire_decode_error(message: &str) -> String {
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

fn require_admission_input_payload_kind<E>(value: &serde_json::Value) -> Result<(), E>
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

fn require_admission_input_field<E>(
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

fn require_granted_capability_envelopes<E>(value: &serde_json::Value) -> Result<(), E>
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

fn acs_admission_input_decode_error(error: &ACSAdmissionInputError) -> String {
    format!(
        "{} field={}",
        error.cause(),
        acs_admission_input_decode_field(error.field())
    )
}

fn acs_admission_input_decode_field(field: &'static str) -> &'static str {
    match field {
        "request_id" => "admission_input.request_id",
        "submitted_at_ms" => "admission_input.submitted_at_ms",
        "risk" => "admission_input.risk",
        _ => field,
    }
}

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

fn require_audit_record_known_fields<E>(value: &serde_json::Value) -> Result<(), E>
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

fn require_audit_record_u32_field<E>(
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

fn require_audit_record_f32_field<E>(
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

fn require_audit_record_i64_field<E>(
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

fn require_audit_record_enum_field<E>(
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

fn acs_audit_record_decode_error(error: &ACSAuditRecordError) -> String {
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

    fn validate(&self) -> Result<(), ACSAdmissionProofError> {
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

fn is_canonical_acs_record_id(value: &str) -> bool {
    parse_canonical_acs_record_id(value).is_some()
}

fn parse_canonical_acs_record_id(value: &str) -> Option<(&str, &str)> {
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

fn acs_record_id_binds_request_and_time(
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

fn acs_record_id_embeds_reserved_malformed_audit_token(record_id: &str) -> bool {
    parse_canonical_acs_record_id(record_id)
        .is_some_and(|(request_id, _)| is_reserved_request_audit_token(request_id))
}

fn is_canonical_audit_token(value: &str) -> bool {
    !value.is_empty()
        && value == value.trim()
        && value.bytes().all(|byte| {
            matches!(
                byte,
                b'a'..=b'z' | b'A'..=b'Z' | b'0'..=b'9' | b'-' | b'_' | b'.'
            )
        })
}

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

fn scope_rex_proof_wire_text(value: Option<serde_json::Value>, invalid_sentinel: &str) -> String {
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

fn require_scope_rex_proof_known_fields<E>(value: &serde_json::Value) -> Result<(), E>
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

fn require_scope_rex_proof_field<E>(value: &serde_json::Value, field: &'static str) -> Result<(), E>
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

fn is_canonical_admission_verdict_code(value: &str) -> bool {
    matches!(
        value,
        "allow" | "allow_with_warning" | "defer" | "quarantine" | "reject"
    )
}

fn scope_rex_proof_decode_error(error: &ACSAdmissionProofError) -> String {
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

fn corrupt_audit_record_proof_error(error: ACSAuditRecordError) -> ACSAdmissionProofError {
    ACSAdmissionProofError::CorruptAuditRecord {
        field: error.field(),
        record_id: error.record_id().unwrap_or("").to_string(),
    }
}

fn scope_rex_proof_payload(
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

fn push_proof_field(payload: &mut Vec<u8>, field: &[u8], value: &[u8]) {
    payload.extend_from_slice(&(field.len() as u32).to_le_bytes());
    payload.extend_from_slice(field);
    payload.extend_from_slice(&(value.len() as u32).to_le_bytes());
    payload.extend_from_slice(value);
}

fn hex_encode_signature(bytes: &[u8]) -> String {
    const HEX: &[u8; 16] = b"0123456789abcdef";
    let mut out = String::with_capacity(bytes.len() * 2);
    for byte in bytes {
        out.push(HEX[(byte >> 4) as usize] as char);
        out.push(HEX[(byte & 0x0f) as usize] as char);
    }
    out
}

fn hex_decode_signature(value: &str) -> Option<Vec<u8>> {
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

fn hex_value(byte: u8) -> Option<u8> {
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

#[derive(Debug, Clone, PartialEq, Serialize)]
#[serde(deny_unknown_fields)]
pub struct ACSAdmissionDecision {
    pub verdict: ACSAdmissionVerdict,
    pub audit_record: ACSAuditRecord,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct ACSAdmissionDecisionWire {
    verdict: ACSAdmissionVerdict,
    audit_record: ACSAuditRecord,
}

impl<'de> Deserialize<'de> for ACSAdmissionDecision {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: serde::Deserializer<'de>,
    {
        let wire = ACSAdmissionDecisionWire::deserialize(deserializer)?;
        let decision = Self {
            verdict: wire.verdict,
            audit_record: wire.audit_record,
        };
        decision.validate().map_err(serde::de::Error::custom)?;
        Ok(decision)
    }
}

impl ACSAdmissionDecision {
    pub const fn lane(&self) -> ACSLane {
        self.audit_record.lane()
    }

    pub const fn product_lane_code(&self) -> &'static str {
        self.lane().product_lane_code()
    }

    fn validate(&self) -> Result<(), String> {
        self.audit_record
            .validate()
            .map_err(|err| acs_audit_record_decode_error(&err))?;
        if self.verdict != self.audit_record.verdict {
            return Err(format!(
                "mismatched_decision_verdict record_id={}",
                self.audit_record.record_id
            ));
        }
        Ok(())
    }
}

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

fn acs_audit_chain_error(
    record_id: String,
    report: &crate::oplog::OpLogChainVerificationReport,
) -> ACSAuditError {
    if report.failure_reason.as_deref() == Some("seq_gap") {
        ACSAuditError::AuditLogGap { record_id }
    } else {
        ACSAuditError::InvalidRunEventLogChain { record_id }
    }
}

fn run_event_log_contains_acs_record(run_event_log: &OpLog, record_id: &str) -> bool {
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

fn run_event_log_corrupt_acs_record(run_event_log: &OpLog) -> Option<ACSAuditError> {
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

fn audit_record_value_malformed_field(value: &serde_json::Value) -> Option<&'static str> {
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

fn run_event_log_max_acs_emitted_at_ms(run_event_log: &OpLog) -> Option<i64> {
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

fn run_event_log_contains_stricter_same_request_verdict(
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

fn acs_audit_lookup_chain_error(
    record_id: String,
    report: &crate::oplog::OpLogChainVerificationReport,
) -> ACSAuditLookupError {
    if report.failure_reason.as_deref() == Some("seq_gap") {
        ACSAuditLookupError::AuditLogGap { record_id }
    } else {
        ACSAuditLookupError::InvalidRunEventLogChain { record_id }
    }
}

fn audit_record_value_id(value: &serde_json::Value) -> Option<&str> {
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

fn has_missing_required_capability(
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

fn has_capability_scope_creep(
    policy: &ACSPolicy,
    operation: ACSOperationKind,
    granted_capabilities: &[Capability],
) -> bool {
    let required_for_operation = policy.required_for(operation);
    granted_capabilities
        .iter()
        .any(|capability| !required_for_operation.contains(capability))
}

fn canonical_l2_capability(operation: ACSOperationKind) -> Option<Capability> {
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

fn decision(
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

fn audit_request_id(value: &str) -> String {
    if is_canonical_audit_token(value) && !is_reserved_request_audit_token(value) {
        value.to_string()
    } else {
        malformed_audit_token(MALFORMED_REQUEST_AUDIT_PREFIX, value)
    }
}

fn audit_policy_id(value: &str) -> String {
    if is_canonical_audit_token(value) && !is_reserved_policy_audit_token(value) {
        value.to_string()
    } else {
        malformed_audit_token(MALFORMED_POLICY_AUDIT_PREFIX, value)
    }
}

fn malformed_audit_token(prefix: &str, value: &str) -> String {
    format!("{}.{}", prefix, blake3::hash(value.as_bytes()).to_hex())
}

fn is_reserved_malformed_audit_token(value: &str, prefix: &str) -> bool {
    value == prefix
        || value
            .strip_prefix(prefix)
            .is_some_and(|suffix| suffix.starts_with('.'))
}

fn is_reserved_request_audit_token(value: &str) -> bool {
    is_reserved_malformed_audit_token(value, MALFORMED_REQUEST_AUDIT_PREFIX)
        || is_reserved_malformed_audit_token(value, MALFORMED_POLICY_AUDIT_PREFIX)
}

fn is_reserved_policy_audit_token(value: &str) -> bool {
    is_reserved_malformed_audit_token(value, MALFORMED_POLICY_AUDIT_PREFIX)
        || is_reserved_malformed_audit_token(value, MALFORMED_REQUEST_AUDIT_PREFIX)
}

fn is_bare_malformed_audit_token(value: &str, prefix: &str) -> bool {
    value == prefix
}

fn audit_policy_version(value: u32) -> u32 {
    if value == 0 {
        1
    } else {
        value
    }
}

fn audit_risk_max(risk: &ACSRiskVector) -> f32 {
    if risk.validate().is_ok() {
        risk.max_axis()
    } else {
        1.0
    }
}

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

fn require_threshold_field<E>(value: &serde_json::Value, field: &'static str) -> Result<(), E>
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

fn require_threshold_known_fields<E>(value: &serde_json::Value) -> Result<(), E>
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

fn acs_policy_decode_error(error: &ACSPolicyError) -> String {
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

fn require_capability_rule_field<E>(
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

fn require_capability_rule_known_fields<E>(value: &serde_json::Value) -> Result<(), E>
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

fn require_capability_rule_capability_envelope<E>(value: &serde_json::Value) -> Result<(), E>
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
struct CapabilityShadowFieldNames {
    vault_path_shadow_path: &'static str,
    vault_path_shadow_verb: &'static str,
    network_host_shadow_host: &'static str,
    biometric_session_shadow_ttl_secs: &'static str,
    other_shadow_name: &'static str,
    generic_capability: &'static str,
}

const REQUIRED_CAPABILITY_SHADOW_FIELDS: CapabilityShadowFieldNames = CapabilityShadowFieldNames {
    vault_path_shadow_path: "required_capabilities.vault_path.shadow_path",
    vault_path_shadow_verb: "required_capabilities.vault_path.shadow_verb",
    network_host_shadow_host: "required_capabilities.network_host.shadow_host",
    biometric_session_shadow_ttl_secs: "required_capabilities.biometric_session.shadow_ttl_secs",
    other_shadow_name: "required_capabilities.other.shadow_name",
    generic_capability: "required_capabilities.capability",
};

const GRANTED_CAPABILITY_SHADOW_FIELDS: CapabilityShadowFieldNames = CapabilityShadowFieldNames {
    vault_path_shadow_path: "admission_input.granted_capabilities.vault_path.shadow_path",
    vault_path_shadow_verb: "admission_input.granted_capabilities.vault_path.shadow_verb",
    network_host_shadow_host: "admission_input.granted_capabilities.network_host.shadow_host",
    biometric_session_shadow_ttl_secs:
        "admission_input.granted_capabilities.biometric_session.shadow_ttl_secs",
    other_shadow_name: "admission_input.granted_capabilities.other.shadow_name",
    generic_capability: "admission_input.granted_capabilities.capability",
};

fn capability_value_shadow_field(
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

fn validate_required_capability(capability: &Capability) -> Result<(), ACSPolicyError> {
    validate_capability_fields(capability, REQUIRED_CAPABILITY_FIELDS)
        .map_err(|field| ACSPolicyError::Malformed { field })
}

#[derive(Debug, Clone, Copy)]
struct CapabilityFieldNames {
    vault_path_path: &'static str,
    vault_path_verb: &'static str,
    network_host_host: &'static str,
    biometric_session_ttl_secs: &'static str,
    other_name: &'static str,
}

const REQUIRED_CAPABILITY_FIELDS: CapabilityFieldNames = CapabilityFieldNames {
    vault_path_path: "required_capabilities.vault_path.path",
    vault_path_verb: "required_capabilities.vault_path.verb",
    network_host_host: "required_capabilities.network_host.host",
    biometric_session_ttl_secs: "required_capabilities.biometric_session.ttl_secs",
    other_name: "required_capabilities.other.name",
};

const GRANTED_CAPABILITY_FIELDS: CapabilityFieldNames = CapabilityFieldNames {
    vault_path_path: "admission_input.granted_capabilities.vault_path.path",
    vault_path_verb: "admission_input.granted_capabilities.vault_path.verb",
    network_host_host: "admission_input.granted_capabilities.network_host.host",
    biometric_session_ttl_secs: "admission_input.granted_capabilities.biometric_session.ttl_secs",
    other_name: "admission_input.granted_capabilities.other.name",
};

const MAX_BIOMETRIC_SESSION_TTL_SECS: u32 = 300;

fn validate_capability_fields(
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

fn operation_threshold_decode_error(message: &str) -> String {
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

fn is_operation_kind_wire_value(value: &serde_json::Value) -> bool {
    value.as_str().is_some_and(is_canonical_operation_kind_code)
}

fn is_canonical_operation_kind_code(value: &str) -> bool {
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

fn require_operation_threshold_rule_field<E>(
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

fn require_operation_threshold_rule_known_fields<E>(value: &serde_json::Value) -> Result<(), E>
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

fn is_i64_or_null(value: &serde_json::Value) -> bool {
    value.is_i64() || value.is_null()
}

fn require_policy_known_fields<E>(value: &serde_json::Value) -> Result<(), E>
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

fn is_u32_value(value: &serde_json::Value) -> bool {
    value
        .as_u64()
        .is_some_and(|number| number <= u32::MAX as u64)
}

fn require_policy_field<E>(
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

fn operation_threshold_policy_error(error: ACSPolicyError) -> ACSPolicyError {
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

fn named_capability(name: impl Into<String>) -> Capability {
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

#[cfg(test)]
mod tests;
