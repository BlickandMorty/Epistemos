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
        let wire = ACSAdmissionInputWire::deserialize(value).map_err(serde::de::Error::custom)?;
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
                "forged_admission_input field=granted_capabilities.capability",
            ));
        };
        for field in capability.keys() {
            if !matches!(field.as_str(), "kind" | "value") {
                return Err(E::custom(format!(
                    "forged_admission_input field=granted_capabilities.{field}"
                )));
            }
        }
        let Some(kind) = capability.get("kind").and_then(serde_json::Value::as_str) else {
            return Err(E::custom(
                "forged_admission_input field=granted_capabilities.capability",
            ));
        };
        let Some(serde_json::Value::Object(capability_value)) = capability.get("value") else {
            return Err(E::custom(
                "forged_admission_input field=granted_capabilities.capability",
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
            _ => Some("granted_capabilities.capability"),
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
                    field: "granted_capabilities.duplicate_capability",
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
    format!("{} field={}", error.cause(), error.field())
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
        "corrupt_acs_audit_record field={field} record_id={record_id}"
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
        "corrupt_acs_audit_record field={field} record_id={record_id}"
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
        "corrupt_acs_audit_record field={field} record_id={record_id}"
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
        "corrupt_acs_audit_record field={field} record_id={record_id}"
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
                "malformed_acs_admission_proof field={field} record_id={record_id}"
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
        "malformed_acs_admission_proof field={field} record_id={record_id}"
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
        if run_event_log_contains_acs_record(self.run_event_log, &node_id) {
            return Err(ACSAuditError::DuplicateRecord { record_id: node_id });
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
    let record: ACSAuditRecord =
        serde_json::from_value(value).map_err(|_| ACSAuditLookupError::CorruptRecord {
            field: "record",
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
    vault_path_shadow_path: "granted_capabilities.vault_path.shadow_path",
    vault_path_shadow_verb: "granted_capabilities.vault_path.shadow_verb",
    network_host_shadow_host: "granted_capabilities.network_host.shadow_host",
    biometric_session_shadow_ttl_secs: "granted_capabilities.biometric_session.shadow_ttl_secs",
    other_shadow_name: "granted_capabilities.other.shadow_name",
    generic_capability: "granted_capabilities.capability",
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
    vault_path_path: "granted_capabilities.vault_path.path",
    vault_path_verb: "granted_capabilities.vault_path.verb",
    network_host_host: "granted_capabilities.network_host.host",
    biometric_session_ttl_secs: "granted_capabilities.biometric_session.ttl_secs",
    other_name: "granted_capabilities.other.name",
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
        let wire =
            ACSOperationThresholdRuleWire::deserialize(value).map_err(serde::de::Error::custom)?;
        Ok(Self {
            operation: wire.operation,
            thresholds: wire.thresholds,
        })
    }
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
            rule.thresholds.validate()?;
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
mod tests {
    use super::*;
    use crate::{
        mutations::types::{MutationActor, Reversibility, Sensitivity, SourceOp},
        provenance::ledger::ClaimId,
        scope_rex::answer_packet::{
            AnswerPacketId, AttentionMode, MutationEnvelopeId, ResidencySignal, SemanticDeltaId,
            WitnessedStateId,
        },
    };

    #[test]
    fn acs_admission_forged_risk_vector_is_rejected() {
        let mut forged = ACSRiskVector::neutral();
        forged.durability_risk = f32::NAN;

        let err = forged.validate().unwrap_err();
        assert_eq!(err.cause(), "non_finite_risk_axis");
        assert_eq!(err.field(), "durability_risk");

        forged.durability_risk = 1.01;
        let err = forged.validate().unwrap_err();
        assert_eq!(err.cause(), "risk_axis_out_of_range");
        assert_eq!(err.field(), "durability_risk");
    }

    #[test]
    fn acs_admission_neutral_risk_vector_is_well_formed() {
        let risk = ACSRiskVector::neutral();
        assert!(risk.validate().is_ok());
        assert_eq!(risk.max_axis(), 0.0);
        assert!(risk.evidence_present);
    }

    #[test]
    fn acs_admission_expired_policy_is_denied() {
        let policy = ACSPolicy::strict("policy-expired", 1_000);
        let err = policy.validate_at(61_001).unwrap_err();

        assert_eq!(err.cause(), "expired_policy");
        assert_eq!(err.field(), None);
    }

    #[test]
    fn acs_admission_policy_time_bounds_are_inclusive() {
        let policy = ACSPolicy::strict("policy-bounds", 1_000);

        assert!(policy.validate_at(1_000).is_ok());
        assert!(policy.validate_at(61_000).is_ok());
    }

    #[test]
    fn acs_admission_strict_default_policy_matches_operation_matrix() {
        let policy = ACSPolicy::strict_default(1_000);
        let cases = [
            (
                ACSOperationKind::MemoryWrite,
                "VaultWrite",
                ("quarantine_at", 0.75),
            ),
            (
                ACSOperationKind::ToolAction,
                "ToolExec",
                ("quarantine_at", 0.65),
            ),
            (
                ACSOperationKind::ActiveAssemblyPacket,
                "Assembly",
                ("defer_at", 0.55),
            ),
            (
                ACSOperationKind::KernelPromotion,
                "KernelPromote",
                ("reject_at", 0.6),
            ),
            (
                ACSOperationKind::ModelAdaptation,
                "ModelAdapt",
                ("reject_at", 0.5),
            ),
        ];

        for (operation, capability_name, (threshold_field, expected_value)) in cases {
            assert!(policy
                .required_for(operation)
                .contains(&named_capability(capability_name)));
            let thresholds = policy.thresholds_for(operation);
            let actual_value = match threshold_field {
                "defer_at" => thresholds.defer_at,
                "quarantine_at" => thresholds.quarantine_at,
                "reject_at" => thresholds.reject_at,
                _ => unreachable!("test fixture only names supported fields"),
            };
            assert_eq!(actual_value, expected_value);
        }

        assert!(ACSAdmissionVerdict::Reject.is_terminal());
        assert!(ACSAdmissionVerdict::Quarantine.is_terminal());
        assert_eq!(ACSAdmissionVerdict::Defer.retry_limit(), Some(3));
    }

    #[test]
    fn acs_admission_lanes_map_operations_and_l2_requires_strict_capabilities() {
        let policy = ACSPolicy::strict_default(1_000);
        let lane_cases = [
            (ACSOperationKind::MutationEnvelope, ACSLane::L0),
            (ACSOperationKind::MemoryWrite, ACSLane::L0),
            (ACSOperationKind::AnswerPacket, ACSLane::L0),
            (ACSOperationKind::ToolAction, ACSLane::L1),
            (ACSOperationKind::ActiveAssemblyPacket, ACSLane::L1),
            (ACSOperationKind::KernelPromotion, ACSLane::L2),
            (ACSOperationKind::ModelAdaptation, ACSLane::L2),
        ];

        for (operation, expected_lane) in lane_cases {
            assert_eq!(operation.lane(), expected_lane);
        }

        let lower_lane_operations = [
            ACSOperationKind::MutationEnvelope,
            ACSOperationKind::MemoryWrite,
            ACSOperationKind::AnswerPacket,
            ACSOperationKind::ToolAction,
            ACSOperationKind::ActiveAssemblyPacket,
        ];
        let l2_cases = [
            (
                ACSOperationKind::KernelPromotion,
                named_capability("KernelPromote"),
            ),
            (
                ACSOperationKind::ModelAdaptation,
                named_capability("ModelAdapt"),
            ),
        ];

        for (operation, l2_capability) in l2_cases {
            assert_eq!(operation.lane(), ACSLane::L2);
            assert!(policy.required_for(operation).contains(&l2_capability));

            for lower_lane_operation in lower_lane_operations {
                assert_ne!(lower_lane_operation.lane(), ACSLane::L2);
                assert!(!policy
                    .required_for(lower_lane_operation)
                    .contains(&l2_capability));
                assert!(
                    policy.thresholds_for(operation).reject_at
                        < policy.thresholds_for(lower_lane_operation).reject_at
                );
            }
        }
    }

    #[test]
    fn acs_admission_lanes_expose_canonical_operations() {
        assert_eq!(
            ACSLane::L0.operations(),
            &[
                ACSOperationKind::MutationEnvelope,
                ACSOperationKind::MemoryWrite,
                ACSOperationKind::AnswerPacket,
            ]
        );
        assert_eq!(
            ACSLane::L1.operations(),
            &[
                ACSOperationKind::ToolAction,
                ACSOperationKind::ActiveAssemblyPacket,
            ]
        );
        assert_eq!(
            ACSLane::L2.operations(),
            &[
                ACSOperationKind::KernelPromotion,
                ACSOperationKind::ModelAdaptation,
            ]
        );
    }

    #[test]
    fn acs_admission_lanes_expose_product_lane_contract() {
        assert_eq!(ACSLane::L0.product_lane_code(), "event_governance");
        assert_eq!(ACSLane::L1.product_lane_code(), "agent_tool_loops");
        assert_eq!(ACSLane::L2.product_lane_code(), "self_healing_research");
    }

    #[test]
    fn acs_admission_input_exposes_product_lane_contract() {
        let input = ACSAdmissionInput {
            request_id: "req-lane-product".to_string(),
            payload: tool_action_payload(),
            submitted_at_ms: 1_001,
            risk: ACSRiskVector::neutral(),
            granted_capabilities: Vec::new(),
        };

        assert_eq!(input.payload.lane(), ACSLane::L1);
        assert_eq!(input.payload.product_lane_code(), "agent_tool_loops");
        assert_eq!(input.lane(), ACSLane::L1);
        assert_eq!(input.product_lane_code(), "agent_tool_loops");
    }

    #[test]
    fn acs_admission_decision_exposes_product_lane_contract() {
        let input = ACSAdmissionInput {
            request_id: "req-decision-lane-product".to_string(),
            payload: tool_action_payload(),
            submitted_at_ms: 1_001,
            risk: ACSRiskVector::neutral(),
            granted_capabilities: Vec::new(),
        };
        let policy = ACSPolicy::strict("policy-decision-lane-product", 1_000);

        let decision = admit(&input, &policy, 1_001);

        assert_eq!(decision.lane(), ACSLane::L1);
        assert_eq!(decision.product_lane_code(), "agent_tool_loops");
    }

    #[test]
    fn acs_admission_policy_exposes_required_capabilities_by_lane() {
        let policy = ACSPolicy::strict_default(1_000);
        let l2_required = policy.required_for_lane(ACSLane::L2);

        assert_eq!(l2_required.len(), 2);
        assert!(l2_required.contains(&named_capability("KernelPromote")));
        assert!(l2_required.contains(&named_capability("ModelAdapt")));

        assert!(!policy
            .required_for_lane(ACSLane::L0)
            .contains(&named_capability("KernelPromote")));
        assert!(!policy
            .required_for_lane(ACSLane::L1)
            .contains(&named_capability("ModelAdapt")));
    }

    #[test]
    fn acs_admission_policy_required_for_lane_includes_l2_canonical_floor() {
        let policy = ACSPolicy::strict("policy-l2-floor", 1_000);

        assert_eq!(
            policy.required_for(ACSOperationKind::KernelPromotion),
            vec![named_capability("KernelPromote")]
        );
        assert_eq!(
            policy.required_for(ACSOperationKind::ModelAdaptation),
            vec![named_capability("ModelAdapt")]
        );
        assert_eq!(
            policy.required_for_lane(ACSLane::L2),
            vec![
                named_capability("KernelPromote"),
                named_capability("ModelAdapt"),
            ]
        );
        assert!(policy.required_for_lane(ACSLane::L0).is_empty());
        assert!(policy.required_for_lane(ACSLane::L1).is_empty());
    }

    #[test]
    fn acs_admission_policy_exposes_strictest_thresholds_by_lane() {
        let policy = ACSPolicy::strict_default(1_000);

        assert_eq!(
            policy.strictest_thresholds_for_lane(ACSLane::L0).reject_at,
            0.9
        );
        assert_eq!(
            policy.strictest_thresholds_for_lane(ACSLane::L1).defer_at,
            0.55
        );
        assert_eq!(
            policy.strictest_thresholds_for_lane(ACSLane::L2).reject_at,
            0.5
        );
        assert!(
            policy.strictest_thresholds_for_lane(ACSLane::L2).reject_at
                < policy.strictest_thresholds_for_lane(ACSLane::L0).reject_at
        );
    }

    #[test]
    fn acs_admission_defer_retry_budget_is_only_retryable_path() {
        for verdict in [
            ACSAdmissionVerdict::Allow,
            ACSAdmissionVerdict::AllowWithWarning,
            ACSAdmissionVerdict::Quarantine,
            ACSAdmissionVerdict::Reject,
        ] {
            assert_eq!(verdict.retry_limit(), None);
            assert!(!verdict.allows_retry(0));
            assert!(!verdict.allows_retry(3));
        }

        assert_eq!(ACSAdmissionVerdict::Defer.retry_limit(), Some(3));
        assert!(ACSAdmissionVerdict::Defer.allows_retry(0));
        assert!(ACSAdmissionVerdict::Defer.allows_retry(1));
        assert!(ACSAdmissionVerdict::Defer.allows_retry(2));
        assert!(!ACSAdmissionVerdict::Defer.allows_retry(3));
    }

    #[test]
    fn acs_admission_malformed_policy_is_denied() {
        let mut policy = ACSPolicy::strict("policy-malformed", 1_000);
        policy.thresholds.quarantine_at = 0.4;
        policy.thresholds.reject_at = 0.3;

        let err = policy.validate_at(1_001).unwrap_err();
        assert_eq!(err.cause(), "malformed_policy");
        assert_eq!(err.field(), Some("risk_threshold_order"));
    }

    #[test]
    fn acs_admission_blank_required_capability_makes_policy_malformed() {
        let policy = ACSPolicy::strict("policy-blank-capability", 1_000).require_capability(
            ACSOperationKind::ToolAction,
            Capability::Other {
                name: " ".to_string(),
            },
        );

        let err = policy.validate_at(1_001).unwrap_err();

        assert_eq!(err.cause(), "malformed_policy");
        assert_eq!(err.field(), Some("required_capabilities.other.name"));
    }

    #[test]
    fn acs_admission_noncanonical_required_capability_makes_policy_malformed() {
        let policy = ACSPolicy::strict("policy-symbol-capability", 1_000).require_capability(
            ACSOperationKind::ToolAction,
            Capability::Other {
                name: "Tool Exec".to_string(),
            },
        );

        let err = policy.validate_at(1_001).unwrap_err();

        assert_eq!(err.cause(), "malformed_policy");
        assert_eq!(err.field(), Some("required_capabilities.other.name"));
    }

    #[test]
    fn acs_admission_noncanonical_vault_path_verb_required_is_malformed_policy() {
        let policy = ACSPolicy::strict("policy-symbol-vault-verb", 1_000).require_capability(
            ACSOperationKind::MemoryWrite,
            Capability::VaultPath {
                path: "/vault/a.md".to_string(),
                verb: "read write".to_string(),
            },
        );

        let err = policy.validate_at(1_001).unwrap_err();

        assert_eq!(err.cause(), "malformed_policy");
        assert_eq!(err.field(), Some("required_capabilities.vault_path.verb"));
    }

    #[test]
    fn acs_admission_boundary_space_vault_path_required_is_malformed_policy() {
        let policy = ACSPolicy::strict("policy-space-vault-path", 1_000).require_capability(
            ACSOperationKind::MemoryWrite,
            Capability::VaultPath {
                path: " /vault/a.md".to_string(),
                verb: "write".to_string(),
            },
        );

        let err = policy.validate_at(1_001).unwrap_err();

        assert_eq!(err.cause(), "malformed_policy");
        assert_eq!(err.field(), Some("required_capabilities.vault_path.path"));
    }

    #[test]
    fn acs_admission_noncanonical_network_host_required_is_malformed_policy() {
        let policy = ACSPolicy::strict("policy-symbol-network-host", 1_000).require_capability(
            ACSOperationKind::ToolAction,
            Capability::NetworkHost {
                host: "api example.com".to_string(),
            },
        );

        let err = policy.validate_at(1_001).unwrap_err();

        assert_eq!(err.cause(), "malformed_policy");
        assert_eq!(err.field(), Some("required_capabilities.network_host.host"));
    }

    #[test]
    fn acs_admission_overlong_biometric_session_required_is_malformed_policy() {
        let policy = ACSPolicy::strict("policy-overlong-biometric-session", 1_000)
            .require_capability(
                ACSOperationKind::KernelPromotion,
                Capability::BiometricSession { ttl_secs: 301 },
            );

        let err = policy.validate_at(1_001).unwrap_err();

        assert_eq!(err.cause(), "malformed_policy");
        assert_eq!(
            err.field(),
            Some("required_capabilities.biometric_session.ttl_secs")
        );
    }

    #[test]
    fn acs_admission_blank_granted_capability_is_forged_input() {
        let input = ACSAdmissionInput {
            request_id: "req-blank-granted-capability".to_string(),
            payload: tool_action_payload(),
            submitted_at_ms: 1_001,
            risk: ACSRiskVector::neutral(),
            granted_capabilities: vec![Capability::Other {
                name: " ".to_string(),
            }],
        };
        let policy = ACSPolicy::strict("policy-blank-granted-capability", 1_000);
        let mut audit_log = Vec::new();

        let decision = admit_and_log(&input, &policy, 1_001, &mut audit_log);

        assert_eq!(decision.verdict, ACSAdmissionVerdict::Reject);
        assert_eq!(decision.audit_record.reason, "forged_admission_input");
        assert_eq!(audit_log.len(), 1);
        assert!(decision.audit_record.validate().is_ok());
    }

    #[test]
    fn acs_admission_noncanonical_granted_capability_is_forged_input() {
        let input = ACSAdmissionInput {
            request_id: "req-symbol-granted-capability".to_string(),
            payload: tool_action_payload(),
            submitted_at_ms: 1_001,
            risk: ACSRiskVector::neutral(),
            granted_capabilities: vec![Capability::Other {
                name: "Tool Exec".to_string(),
            }],
        };
        let policy = ACSPolicy::strict("policy-symbol-granted-capability", 1_000);
        let mut audit_log = Vec::new();

        let decision = admit_and_log(&input, &policy, 1_001, &mut audit_log);

        assert_eq!(decision.verdict, ACSAdmissionVerdict::Reject);
        assert_eq!(decision.audit_record.reason, "forged_admission_input");
        assert_eq!(audit_log.len(), 1);
        assert!(decision.audit_record.validate().is_ok());
    }

    #[test]
    fn acs_admission_noncanonical_vault_path_verb_granted_is_forged_input() {
        let input = ACSAdmissionInput {
            request_id: "req-symbol-granted-vault-verb".to_string(),
            payload: ACSAdmissionPayload::MemoryWrite {
                request: ACSMemoryWriteRequest {
                    address: "uas://note/1".to_string(),
                    content_hash: "content-hash".to_string(),
                    durable: false,
                    mutation_envelope_id: None,
                },
            },
            submitted_at_ms: 1_001,
            risk: ACSRiskVector::neutral(),
            granted_capabilities: vec![Capability::VaultPath {
                path: "/vault/a.md".to_string(),
                verb: "read write".to_string(),
            }],
        };
        let policy = ACSPolicy::strict("policy-symbol-granted-vault-verb", 1_000);
        let mut audit_log = Vec::new();

        let decision = admit_and_log(&input, &policy, 1_001, &mut audit_log);

        assert_eq!(decision.verdict, ACSAdmissionVerdict::Reject);
        assert_eq!(decision.audit_record.reason, "forged_admission_input");
        assert_eq!(audit_log.len(), 1);
        assert!(decision.audit_record.validate().is_ok());
    }

    #[test]
    fn acs_admission_duplicate_granted_capability_is_forged_input() {
        let capability = Capability::Other {
            name: "ToolExec".to_string(),
        };
        let input = ACSAdmissionInput {
            request_id: "req-duplicate-granted-capability".to_string(),
            payload: tool_action_payload(),
            submitted_at_ms: 1_001,
            risk: ACSRiskVector::neutral(),
            granted_capabilities: vec![capability.clone(), capability],
        };
        let policy = ACSPolicy::strict("policy-duplicate-granted-capability", 1_000);
        let mut audit_log = Vec::new();

        let decision = admit_and_log(&input, &policy, 1_001, &mut audit_log);

        assert_eq!(decision.verdict, ACSAdmissionVerdict::Reject);
        assert_eq!(decision.audit_record.reason, "forged_admission_input");
        assert_eq!(audit_log.len(), 1);
        assert!(decision.audit_record.validate().is_ok());
    }

    #[test]
    fn acs_admission_boundary_space_vault_path_granted_is_forged_input() {
        let input = ACSAdmissionInput {
            request_id: "req-space-granted-vault-path".to_string(),
            payload: ACSAdmissionPayload::MemoryWrite {
                request: ACSMemoryWriteRequest {
                    address: "uas://note/1".to_string(),
                    content_hash: "content-hash".to_string(),
                    durable: false,
                    mutation_envelope_id: None,
                },
            },
            submitted_at_ms: 1_001,
            risk: ACSRiskVector::neutral(),
            granted_capabilities: vec![Capability::VaultPath {
                path: " /vault/a.md".to_string(),
                verb: "write".to_string(),
            }],
        };
        let policy = ACSPolicy::strict("policy-space-granted-vault-path", 1_000);
        let mut audit_log = Vec::new();

        let decision = admit_and_log(&input, &policy, 1_001, &mut audit_log);

        assert_eq!(decision.verdict, ACSAdmissionVerdict::Reject);
        assert_eq!(decision.audit_record.reason, "forged_admission_input");
        assert_eq!(audit_log.len(), 1);
        assert!(decision.audit_record.validate().is_ok());
    }

    #[test]
    fn acs_admission_noncanonical_network_host_granted_is_forged_input() {
        let input = ACSAdmissionInput {
            request_id: "req-symbol-granted-network-host".to_string(),
            payload: tool_action_payload(),
            submitted_at_ms: 1_001,
            risk: ACSRiskVector::neutral(),
            granted_capabilities: vec![Capability::NetworkHost {
                host: "api example.com".to_string(),
            }],
        };
        let policy = ACSPolicy::strict("policy-symbol-granted-network-host", 1_000);
        let mut audit_log = Vec::new();

        let decision = admit_and_log(&input, &policy, 1_001, &mut audit_log);

        assert_eq!(decision.verdict, ACSAdmissionVerdict::Reject);
        assert_eq!(decision.audit_record.reason, "forged_admission_input");
        assert_eq!(audit_log.len(), 1);
        assert!(decision.audit_record.validate().is_ok());
    }

    #[test]
    fn acs_admission_per_operation_threshold_overrides_global_thresholds_for_that_operation() {
        let mut policy = ACSPolicy::strict("policy-per-operation-override", 1_000);
        policy.operation_thresholds = vec![ACSOperationThresholdRule::new(
            ACSOperationKind::ToolAction,
            ACSRiskThresholds {
                warn_at: 0.10,
                defer_at: 0.20,
                quarantine_at: 0.30,
                reject_at: 0.40,
            },
        )];

        let mut risk = ACSRiskVector::neutral();
        risk.truth_risk = 0.35;

        let mut tool_action_audit = Vec::new();
        let tool_action_input = ACSAdmissionInput {
            request_id: "req-tool-action-override".to_string(),
            payload: ACSAdmissionPayload::ToolAction {
                request: ACSToolActionRequest {
                    tool_name: "vault.write".to_string(),
                    target: "uas://note/1".to_string(),
                    mutation_envelope_id: Some("mutation-1".to_string()),
                },
            },
            submitted_at_ms: 1_001,
            risk,
            granted_capabilities: vec![
                Capability::VaultPath {
                    path: "uas://note/1".to_string(),
                    verb: "write".to_string(),
                },
                Capability::Other {
                    name: "ToolExec".to_string(),
                },
            ],
        };
        let tool_action_decision =
            admit_and_log(&tool_action_input, &policy, 1_001, &mut tool_action_audit);
        assert_eq!(
            tool_action_decision.verdict,
            ACSAdmissionVerdict::Quarantine,
            "per-operation threshold must escalate ToolAction at 0.35 risk"
        );

        let mut memory_write_audit = Vec::new();
        let memory_write_input = ACSAdmissionInput {
            request_id: "req-memory-write-default".to_string(),
            payload: ACSAdmissionPayload::MemoryWrite {
                request: ACSMemoryWriteRequest {
                    address: "uas://note/concurrent".to_string(),
                    content_hash: "content-hash".to_string(),
                    durable: false,
                    mutation_envelope_id: None,
                },
            },
            submitted_at_ms: 1_001,
            risk,
            granted_capabilities: Vec::new(),
        };
        let memory_write_decision =
            admit_and_log(&memory_write_input, &policy, 1_001, &mut memory_write_audit);
        assert_eq!(
            memory_write_decision.verdict,
            ACSAdmissionVerdict::AllowWithWarning,
            "global thresholds must still apply to operations without overrides"
        );
    }

    #[test]
    fn acs_admission_per_operation_threshold_overrides_cover_high_risk_operations() {
        let mut risk = ACSRiskVector::neutral();
        risk.truth_risk = 0.35;
        let override_thresholds = ACSRiskThresholds {
            warn_at: 0.10,
            defer_at: 0.20,
            quarantine_at: 0.30,
            reject_at: 0.40,
        };
        let granted_capabilities = vec![
            named_capability("VaultWrite"),
            named_capability("ToolExec"),
            named_capability("Assembly"),
            named_capability("KernelPromote"),
            named_capability("ModelAdapt"),
        ];

        for operation in [
            ACSOperationKind::MemoryWrite,
            ACSOperationKind::ToolAction,
            ACSOperationKind::ActiveAssemblyPacket,
            ACSOperationKind::KernelPromotion,
            ACSOperationKind::ModelAdaptation,
        ] {
            let mut policy = ACSPolicy::strict_default(1_000);
            policy.operation_thresholds = vec![ACSOperationThresholdRule::new(
                operation,
                override_thresholds,
            )];
            let input = ACSAdmissionInput {
                request_id: format!("req-{}-threshold-override", operation.code()),
                payload: high_risk_operation_payload(operation),
                submitted_at_ms: 1_001,
                risk,
                granted_capabilities: granted_capabilities.clone(),
            };

            let decision = admit(&input, &policy, 1_001);

            assert_eq!(
                decision.verdict,
                ACSAdmissionVerdict::Quarantine,
                "override threshold must apply to {}",
                operation.code()
            );
        }
    }

    #[test]
    fn acs_admission_duplicate_operation_threshold_is_malformed_policy() {
        let mut policy = ACSPolicy::strict("policy-duplicate-threshold", 1_000);
        policy.operation_thresholds = vec![
            ACSOperationThresholdRule::new(
                ACSOperationKind::ToolAction,
                ACSRiskThresholds::standard(),
            ),
            ACSOperationThresholdRule::new(
                ACSOperationKind::ToolAction,
                ACSRiskThresholds::standard(),
            ),
        ];

        let err = policy.validate_at(1_001).unwrap_err();

        assert_eq!(err.cause(), "malformed_policy");
        assert_eq!(
            err.field(),
            Some("operation_thresholds.duplicate_operation")
        );

        let value = serde_json::to_value(&policy).expect("policy encodes");
        let err = serde_json::from_value::<ACSPolicy>(value).unwrap_err();
        let message = err.to_string();

        assert!(message.contains("malformed_policy"), "{message}");
        assert!(
            message.contains("operation_thresholds.duplicate_operation"),
            "{message}"
        );
    }

    #[test]
    fn acs_admission_duplicate_required_capability_is_malformed_policy() {
        let capability = Capability::Other {
            name: "ToolExec".to_string(),
        };
        let policy = ACSPolicy::strict("policy-duplicate-required-capability", 1_000)
            .require_capability(ACSOperationKind::ToolAction, capability.clone())
            .require_capability(ACSOperationKind::ToolAction, capability);

        let err = policy.validate_at(1_001).unwrap_err();

        assert_eq!(err.cause(), "malformed_policy");
        assert_eq!(
            err.field(),
            Some("required_capabilities.duplicate_capability")
        );

        let value = serde_json::to_value(&policy).expect("policy encodes");
        let err = serde_json::from_value::<ACSPolicy>(value).unwrap_err();
        let message = err.to_string();

        assert!(message.contains("malformed_policy"), "{message}");
        assert!(
            message.contains("required_capabilities.duplicate_capability"),
            "{message}"
        );
    }

    #[test]
    fn acs_admission_malformed_policy_window_is_denied() {
        let mut policy = ACSPolicy::strict("policy-window", 1_000);
        policy.expires_at_ms = Some(1_000);

        let err = policy.validate_at(1_000).unwrap_err();

        assert_eq!(err.cause(), "malformed_policy");
        assert_eq!(err.field(), Some("expires_at_ms"));
    }

    #[test]
    fn acs_admission_negative_policy_start_is_malformed() {
        let policy = ACSPolicy::strict("policy-negative-start", -1);

        let err = policy.validate_at(0).unwrap_err();

        assert_eq!(err.cause(), "malformed_policy");
        assert_eq!(err.field(), Some("valid_from_ms"));
    }

    #[test]
    fn acs_admission_policy_strict_saturates_max_expiration_window() {
        let policy = ACSPolicy::strict("policy-max-window", i64::MAX);

        assert_eq!(policy.expires_at_ms, None);
        assert!(policy.validate_at(i64::MAX).is_ok());
    }

    #[test]
    fn acs_admission_high_risk_rejects() {
        let mut risk = ACSRiskVector::neutral();
        risk.safety_risk = 0.95;

        let verdict = ACSAdmissionVerdict::from_risk(&risk, ACSRiskThresholds::standard());

        assert_eq!(verdict, ACSAdmissionVerdict::Reject);
    }

    #[test]
    fn acs_admission_threshold_boundaries_are_inclusive() {
        let thresholds = ACSRiskThresholds::standard();
        let cases = [
            (thresholds.warn_at, ACSAdmissionVerdict::AllowWithWarning),
            (thresholds.defer_at, ACSAdmissionVerdict::Defer),
            (thresholds.quarantine_at, ACSAdmissionVerdict::Quarantine),
            (thresholds.reject_at, ACSAdmissionVerdict::Reject),
        ];

        for (axis_value, expected) in cases {
            let mut risk = ACSRiskVector::neutral();
            risk.safety_risk = axis_value;

            assert_eq!(ACSAdmissionVerdict::from_risk(&risk, thresholds), expected);
        }
    }

    #[test]
    fn acs_admission_verdict_wire_format_is_snake_case() {
        let cases = [
            (ACSAdmissionVerdict::Allow, "\"allow\""),
            (
                ACSAdmissionVerdict::AllowWithWarning,
                "\"allow_with_warning\"",
            ),
            (ACSAdmissionVerdict::Defer, "\"defer\""),
            (ACSAdmissionVerdict::Quarantine, "\"quarantine\""),
            (ACSAdmissionVerdict::Reject, "\"reject\""),
        ];

        for (verdict, expected_json) in cases {
            assert_eq!(serde_json::to_string(&verdict).unwrap(), expected_json);
        }
    }

    #[test]
    fn acs_admission_operation_kind_wire_format_is_snake_case() {
        let cases = [
            (ACSOperationKind::MutationEnvelope, "\"mutation_envelope\""),
            (
                ACSOperationKind::ActiveAssemblyPacket,
                "\"active_assembly_packet\"",
            ),
            (ACSOperationKind::AnswerPacket, "\"answer_packet\""),
            (ACSOperationKind::MemoryWrite, "\"memory_write\""),
            (ACSOperationKind::ToolAction, "\"tool_action\""),
            (ACSOperationKind::KernelPromotion, "\"kernel_promotion\""),
            (ACSOperationKind::ModelAdaptation, "\"model_adaptation\""),
        ];

        for (operation, expected_json) in cases {
            assert_eq!(serde_json::to_string(&operation).unwrap(), expected_json);
        }
    }

    #[test]
    fn acs_admission_forged_input_is_rejected() {
        let input = ACSAdmissionInput {
            request_id: "   ".to_string(),
            payload: tool_action_payload(),
            submitted_at_ms: 1_000,
            risk: ACSRiskVector::neutral(),
            granted_capabilities: Vec::new(),
        };

        let err = input.validate().unwrap_err();

        assert_eq!(err.cause(), "forged_admission_input");
        assert_eq!(err.field(), "request_id");
    }

    #[test]
    fn acs_admission_forged_request_id_logs_valid_audit() {
        let input = ACSAdmissionInput {
            request_id: " ".to_string(),
            payload: tool_action_payload(),
            submitted_at_ms: 1_001,
            risk: ACSRiskVector::neutral(),
            granted_capabilities: Vec::new(),
        };
        let policy = ACSPolicy::strict("policy-forged-request", 1_000);
        let mut audit_log = Vec::new();

        let decision = admit_and_log(&input, &policy, 1_001, &mut audit_log);

        assert_eq!(decision.verdict, ACSAdmissionVerdict::Reject);
        assert_eq!(decision.audit_record.reason, "forged_admission_input");
        assert!(decision
            .audit_record
            .request_id
            .starts_with("malformed_request."));
        assert!(decision.audit_record.validate().is_ok());
    }

    #[test]
    fn acs_admission_input_rejects_reserved_malformed_request_namespace() {
        let input = ACSAdmissionInput {
            request_id: audit_request_id(" "),
            payload: tool_action_payload(),
            submitted_at_ms: 1_001,
            risk: ACSRiskVector::neutral(),
            granted_capabilities: Vec::new(),
        };

        let err = input.validate().unwrap_err();

        assert_eq!(err.cause(), "forged_admission_input");
        assert_eq!(err.field(), "request_id");
    }

    #[test]
    fn acs_admission_input_rejects_reserved_malformed_policy_request_namespace() {
        let input = ACSAdmissionInput {
            request_id: audit_policy_id(" "),
            payload: tool_action_payload(),
            submitted_at_ms: 1_001,
            risk: ACSRiskVector::neutral(),
            granted_capabilities: Vec::new(),
        };
        let policy = ACSPolicy::strict("policy-cross-reserved-request", 1_000);
        let mut audit_log = Vec::new();

        let err = input.validate().unwrap_err();
        let decision = admit_and_log(&input, &policy, 1_001, &mut audit_log);

        assert_eq!(err.cause(), "forged_admission_input");
        assert_eq!(err.field(), "request_id");
        assert_eq!(decision.verdict, ACSAdmissionVerdict::Reject);
        assert_eq!(decision.audit_record.reason, "forged_admission_input");
        assert!(decision
            .audit_record
            .request_id
            .starts_with("malformed_request."));
        assert!(decision.audit_record.validate().is_ok());
    }

    #[test]
    fn acs_admission_noncanonical_request_id_logs_valid_audit() {
        let input = ACSAdmissionInput {
            request_id: "req forged".to_string(),
            payload: tool_action_payload(),
            submitted_at_ms: 1_001,
            risk: ACSRiskVector::neutral(),
            granted_capabilities: Vec::new(),
        };
        let policy = ACSPolicy::strict("policy-forged-request", 1_000);
        let mut audit_log = Vec::new();

        let err = input.validate().unwrap_err();
        assert_eq!(err.cause(), "forged_admission_input");
        assert_eq!(err.field(), "request_id");

        let decision = admit_and_log(&input, &policy, 1_001, &mut audit_log);

        assert_eq!(decision.verdict, ACSAdmissionVerdict::Reject);
        assert_eq!(decision.audit_record.reason, "forged_admission_input");
        assert!(decision
            .audit_record
            .request_id
            .starts_with("malformed_request."));
        assert!(decision.audit_record.validate().is_ok());
    }

    #[test]
    fn acs_admission_forged_risk_still_emits_valid_audit_record() {
        let mut risk = ACSRiskVector::neutral();
        risk.durability_risk = 1.01;
        let input = ACSAdmissionInput {
            request_id: "req-forged-risk".to_string(),
            payload: tool_action_payload(),
            submitted_at_ms: 1_001,
            risk,
            granted_capabilities: Vec::new(),
        };
        let policy = ACSPolicy::strict("policy-forged-risk", 1_000);
        let mut audit_log = Vec::new();

        let decision = admit_and_log(&input, &policy, 1_001, &mut audit_log);

        assert_eq!(decision.verdict, ACSAdmissionVerdict::Reject);
        assert_eq!(decision.audit_record.reason, "forged_admission_input");
        assert_eq!(decision.audit_record.risk_max, 1.0);
        assert!(decision.audit_record.validate().is_ok());
    }

    #[test]
    fn acs_admission_missing_capability_is_denied_and_logged() {
        let required = Capability::Other {
            name: "vault.write".to_string(),
        };
        let policy = ACSPolicy::strict("policy-capability", 1_000)
            .require_capability(ACSOperationKind::ToolAction, required);
        let input = ACSAdmissionInput {
            request_id: "req-tool-1".to_string(),
            payload: tool_action_payload(),
            submitted_at_ms: 1_001,
            risk: ACSRiskVector::neutral(),
            granted_capabilities: Vec::new(),
        };
        let mut audit_log = Vec::new();

        let decision = admit_and_log(&input, &policy, 1_001, &mut audit_log);

        assert_eq!(decision.verdict, ACSAdmissionVerdict::Reject);
        assert_eq!(decision.audit_record.reason, "missing_capability");
        assert_eq!(audit_log.len(), 1);
        assert_eq!(audit_log[0].verdict, ACSAdmissionVerdict::Reject);
    }

    #[test]
    fn acs_admission_requires_every_policy_capability() {
        let write = Capability::Other {
            name: "vault.write".to_string(),
        };
        let sign = Capability::Other {
            name: "witness.sign".to_string(),
        };
        let policy = ACSPolicy::strict("policy-two-capabilities", 1_000)
            .require_capability(ACSOperationKind::ToolAction, write.clone())
            .require_capability(ACSOperationKind::ToolAction, sign);
        let input = ACSAdmissionInput {
            request_id: "req-two-capabilities".to_string(),
            payload: tool_action_payload(),
            submitted_at_ms: 1_001,
            risk: ACSRiskVector::neutral(),
            granted_capabilities: vec![write],
        };
        let mut audit_log = Vec::new();

        let decision = admit_and_log(&input, &policy, 1_001, &mut audit_log);

        assert_eq!(decision.verdict, ACSAdmissionVerdict::Reject);
        assert_eq!(decision.audit_record.reason, "missing_capability");
        assert_eq!(audit_log.len(), 1);
    }

    #[test]
    fn acs_admission_matching_capability_allows_and_logs() {
        let required = Capability::Other {
            name: "vault.write".to_string(),
        };
        let policy = ACSPolicy::strict("policy-capability-allow", 1_000)
            .require_capability(ACSOperationKind::ToolAction, required.clone());
        let input = ACSAdmissionInput {
            request_id: "req-tool-allow".to_string(),
            payload: tool_action_payload(),
            submitted_at_ms: 1_001,
            risk: ACSRiskVector::neutral(),
            granted_capabilities: vec![required],
        };
        let mut audit_log = Vec::new();

        let decision = admit_and_log(&input, &policy, 1_001, &mut audit_log);

        assert_eq!(decision.verdict, ACSAdmissionVerdict::Allow);
        assert_eq!(audit_log.len(), 1);
        assert_eq!(audit_log[0].reason, "allow");
    }

    #[test]
    fn acs_admission_all_policy_capabilities_present_allows() {
        let write = Capability::Other {
            name: "vault.write".to_string(),
        };
        let sign = Capability::Other {
            name: "witness.sign".to_string(),
        };
        let policy = ACSPolicy::strict("policy-all-capabilities", 1_000)
            .require_capability(ACSOperationKind::ToolAction, write.clone())
            .require_capability(ACSOperationKind::ToolAction, sign.clone());
        let input = ACSAdmissionInput {
            request_id: "req-all-capabilities".to_string(),
            payload: tool_action_payload(),
            submitted_at_ms: 1_001,
            risk: ACSRiskVector::neutral(),
            granted_capabilities: vec![sign, write],
        };
        let mut audit_log = Vec::new();

        let decision = admit_and_log(&input, &policy, 1_001, &mut audit_log);

        assert_eq!(decision.verdict, ACSAdmissionVerdict::Allow);
        assert_eq!(audit_log[0].reason, "allow");
    }

    #[test]
    fn acs_admission_broader_vault_path_grant_does_not_satisfy_narrow_policy_scope() {
        let required = Capability::VaultPath {
            path: "/vault/project-a/note.md".to_string(),
            verb: "write".to_string(),
        };
        let replayed_broader_scope = Capability::VaultPath {
            path: "/vault".to_string(),
            verb: "write".to_string(),
        };
        let policy = ACSPolicy::strict("policy-vault-scope-creep", 1_000)
            .require_capability(ACSOperationKind::MemoryWrite, required);
        let input = ACSAdmissionInput {
            request_id: "req-vault-scope-creep".to_string(),
            payload: ACSAdmissionPayload::MemoryWrite {
                request: ACSMemoryWriteRequest {
                    address: "uas://note/1".to_string(),
                    content_hash: "content-hash".to_string(),
                    durable: false,
                    mutation_envelope_id: None,
                },
            },
            submitted_at_ms: 1_001,
            risk: ACSRiskVector::neutral(),
            granted_capabilities: vec![replayed_broader_scope],
        };
        let mut audit_log = Vec::new();

        let decision = admit_and_log(&input, &policy, 1_001, &mut audit_log);

        assert_eq!(decision.verdict, ACSAdmissionVerdict::Reject);
        assert_eq!(decision.audit_record.reason, "missing_capability");
        assert_eq!(audit_log.len(), 1);
    }

    #[test]
    fn acs_admission_capability_rules_are_operation_scoped() {
        let promotion_capability = Capability::Other {
            name: "kernel.promote".to_string(),
        };
        let policy = ACSPolicy::strict("policy-operation-scope", 1_000)
            .require_capability(ACSOperationKind::KernelPromotion, promotion_capability);
        let input = ACSAdmissionInput {
            request_id: "req-tool-operation-scope".to_string(),
            payload: tool_action_payload(),
            submitted_at_ms: 1_001,
            risk: ACSRiskVector::neutral(),
            granted_capabilities: Vec::new(),
        };
        let mut audit_log = Vec::new();

        let decision = admit_and_log(&input, &policy, 1_001, &mut audit_log);

        assert_eq!(decision.verdict, ACSAdmissionVerdict::Allow);
        assert_eq!(audit_log[0].operation, ACSOperationKind::ToolAction);
    }

    #[test]
    fn acs_admission_input_accepts_all_canonical_payloads() {
        let payloads = vec![
            ACSAdmissionPayload::MutationEnvelope {
                envelope: Box::new(mutation_envelope_fixture()),
            },
            ACSAdmissionPayload::ActiveAssemblyPacket {
                packet: ActiveAssemblyPacket {
                    assembly_id: "assembly-1".to_string(),
                    active_support_ids: vec!["note-1".to_string()],
                    witness_hash: "witness-hash".to_string(),
                },
            },
            ACSAdmissionPayload::AnswerPacket {
                packet: Box::new(
                    AnswerPacket::new(
                        AnswerPacketId::new("answer-1"),
                        WitnessedStateId::new("state-1"),
                        MutationEnvelopeId::new("mutation-1"),
                    )
                    .push_claim(Claim::new(
                        ClaimId::new("claim-1"),
                        "plausible support",
                        1_001,
                    )),
                ),
            },
            ACSAdmissionPayload::MemoryWrite {
                request: ACSMemoryWriteRequest {
                    address: "uas://note/1".to_string(),
                    content_hash: "content-hash".to_string(),
                    durable: false,
                    mutation_envelope_id: None,
                },
            },
            tool_action_payload(),
            ACSAdmissionPayload::KernelPromotion {
                request: ACSKernelPromotionRequest {
                    kernel_id: "kernel-1".to_string(),
                    signed_plan_hash: "plan-hash".to_string(),
                    mutation_envelope_id: Some("mutation-1".to_string()),
                },
            },
            ACSAdmissionPayload::ModelAdaptation {
                request: ACSModelAdaptationRequest {
                    adapter_id: "adapter-1".to_string(),
                    model_id: "local-helper-1".to_string(),
                    checkpoint_hash: "checkpoint-hash".to_string(),
                    mutation_envelope_id: Some("mutation-1".to_string()),
                },
            },
        ];
        let expected = [
            ACSOperationKind::MutationEnvelope,
            ACSOperationKind::ActiveAssemblyPacket,
            ACSOperationKind::AnswerPacket,
            ACSOperationKind::MemoryWrite,
            ACSOperationKind::ToolAction,
            ACSOperationKind::KernelPromotion,
            ACSOperationKind::ModelAdaptation,
        ];

        for (idx, payload) in payloads.into_iter().enumerate() {
            let input = ACSAdmissionInput {
                request_id: format!("req-{idx}"),
                payload,
                submitted_at_ms: 1_001,
                risk: ACSRiskVector::neutral(),
                granted_capabilities: Vec::new(),
            };
            assert!(input.validate().is_ok());
            assert_eq!(input.operation(), expected[idx]);
        }
    }

    #[test]
    fn acs_admission_payload_rejects_boundary_spaced_mutation_id_on_decode() {
        let mut envelope = mutation_envelope_fixture();
        envelope.mutation_id = " mutation-1".to_string();
        let value = serde_json::json!({
            "kind": "mutation_envelope",
            "envelope": envelope,
        });

        let err = serde_json::from_value::<ACSAdmissionPayload>(value).unwrap_err();
        let message = err.to_string();

        assert!(message.contains("forged_admission_input"), "{message}");
        assert!(message.contains("mutation_id"), "{message}");
    }

    #[test]
    fn acs_admission_payload_rejects_shadow_mutation_envelope_field_on_decode() {
        let mut envelope = serde_json::to_value(mutation_envelope_fixture())
            .expect("mutation envelope serializes");
        envelope["shadow_integrity_hash"] = serde_json::json!("hash-shadow");
        let value = serde_json::json!({
            "kind": "mutation_envelope",
            "envelope": envelope,
        });

        assert!(serde_json::from_value::<ACSAdmissionPayload>(value).is_err());
    }

    #[test]
    fn acs_admission_payload_rejects_shadow_mutation_actor_field_on_decode() {
        let mut envelope = serde_json::to_value(mutation_envelope_fixture())
            .expect("mutation envelope serializes");
        envelope["actor"]["shadow_run_id"] = serde_json::json!("run-shadow");
        let value = serde_json::json!({
            "kind": "mutation_envelope",
            "envelope": envelope,
        });

        assert!(serde_json::from_value::<ACSAdmissionPayload>(value).is_err());
    }

    #[test]
    fn acs_admission_payload_rejects_null_mutation_user_actor_run_id_on_decode() {
        let mut envelope = serde_json::to_value(mutation_envelope_fixture())
            .expect("mutation envelope serializes");
        envelope["actor"] = serde_json::json!({
            "kind": "user",
            "run_id": null,
        });
        let value = serde_json::json!({
            "kind": "mutation_envelope",
            "envelope": envelope,
        });

        assert!(serde_json::from_value::<ACSAdmissionPayload>(value).is_err());
    }

    #[test]
    fn acs_admission_payload_rejects_shadow_mutation_source_op_field_on_decode() {
        let mut envelope = serde_json::to_value(mutation_envelope_fixture())
            .expect("mutation envelope serializes");
        envelope["op"]["shadow_artifact_id"] = serde_json::json!("artifact-shadow");
        let value = serde_json::json!({
            "kind": "mutation_envelope",
            "envelope": envelope,
        });

        assert!(serde_json::from_value::<ACSAdmissionPayload>(value).is_err());
    }

    #[test]
    fn acs_admission_payload_rejects_null_mutation_source_op_extra_field_on_decode() {
        let mut envelope = serde_json::to_value(mutation_envelope_fixture())
            .expect("mutation envelope serializes");
        envelope["op"] = serde_json::json!({
            "kind": "artifact_update",
            "artifact_id": "artifact-1",
            "label": null,
        });
        let value = serde_json::json!({
            "kind": "mutation_envelope",
            "envelope": envelope,
        });

        assert!(serde_json::from_value::<ACSAdmissionPayload>(value).is_err());
    }

    #[test]
    fn acs_admission_payload_rejects_shadow_mutation_touched_artifact_field_on_decode() {
        let mut envelope = serde_json::to_value(mutation_envelope_fixture())
            .expect("mutation envelope serializes");
        envelope["touched_artifacts"] = serde_json::json!([
            {
                "id": "artifact-1",
                "shadow_id": "artifact-shadow"
            }
        ]);
        let value = serde_json::json!({
            "kind": "mutation_envelope",
            "envelope": envelope,
        });

        assert!(serde_json::from_value::<ACSAdmissionPayload>(value).is_err());
    }

    #[test]
    fn acs_admission_payload_rejects_shadow_mutation_touched_block_field_on_decode() {
        let mut envelope = serde_json::to_value(mutation_envelope_fixture())
            .expect("mutation envelope serializes");
        envelope["touched_blocks"] = serde_json::json!([
            {
                "artifact_id": "artifact-1",
                "block_id": "block-1",
                "shadow_block_id": "block-shadow"
            }
        ]);
        let value = serde_json::json!({
            "kind": "mutation_envelope",
            "envelope": envelope,
        });

        assert!(serde_json::from_value::<ACSAdmissionPayload>(value).is_err());
    }

    #[test]
    fn acs_admission_payload_rejects_shadow_mutation_relation_change_field_on_decode() {
        let mut envelope = serde_json::to_value(mutation_envelope_fixture())
            .expect("mutation envelope serializes");
        envelope["relation_changes"] = serde_json::json!([
            {
                "op": "added",
                "from_id": "artifact-1",
                "to_id": "artifact-2",
                "label": "cites",
                "shadow_label": "supports"
            }
        ]);
        let value = serde_json::json!({
            "kind": "mutation_envelope",
            "envelope": envelope,
        });

        assert!(serde_json::from_value::<ACSAdmissionPayload>(value).is_err());
    }

    #[test]
    fn acs_admission_payload_rejects_null_mutation_relation_extra_field_on_decode() {
        let mut envelope = serde_json::to_value(mutation_envelope_fixture())
            .expect("mutation envelope serializes");
        envelope["relation_changes"] = serde_json::json!([
            {
                "op": "added",
                "from_id": "artifact-1",
                "to_id": "artifact-2",
                "label": "cites",
                "old_label": null
            }
        ]);
        let value = serde_json::json!({
            "kind": "mutation_envelope",
            "envelope": envelope,
        });

        assert!(serde_json::from_value::<ACSAdmissionPayload>(value).is_err());
    }

    #[test]
    fn acs_admission_payload_rejects_boundary_spaced_mutation_hash_on_decode() {
        let mut envelope = serde_json::to_value(mutation_envelope_fixture())
            .expect("mutation envelope serializes");
        envelope["integrity_hash"] = serde_json::json!(" hash-1");
        let value = serde_json::json!({
            "kind": "mutation_envelope",
            "envelope": envelope,
        });

        assert!(serde_json::from_value::<ACSAdmissionPayload>(value).is_err());
    }

    #[test]
    fn acs_admission_payload_rejects_boundary_spaced_mutation_artifact_id_on_decode() {
        let mut envelope = mutation_envelope_fixture();
        envelope.op = SourceOp::ArtifactUpdate {
            artifact_id: " artifact-1".to_string(),
        };
        let value = serde_json::json!({
            "kind": "mutation_envelope",
            "envelope": envelope,
        });

        assert!(serde_json::from_value::<ACSAdmissionPayload>(value).is_err());
    }

    #[test]
    fn acs_admission_payload_rejects_boundary_spaced_mutation_source_kind_on_decode() {
        let mut envelope = mutation_envelope_fixture();
        envelope.op = SourceOp::ArtifactCreate {
            artifact_id: "artifact-1".to_string(),
            artifact_kind: " document".to_string(),
        };
        let value = serde_json::json!({
            "kind": "mutation_envelope",
            "envelope": envelope,
        });

        assert!(serde_json::from_value::<ACSAdmissionPayload>(value).is_err());
    }

    #[test]
    fn acs_admission_payload_rejects_boundary_spaced_mutation_source_label_on_decode() {
        let mut envelope = mutation_envelope_fixture();
        envelope.op = SourceOp::Other {
            label: " migration".to_string(),
        };
        let value = serde_json::json!({
            "kind": "mutation_envelope",
            "envelope": envelope,
        });

        assert!(serde_json::from_value::<ACSAdmissionPayload>(value).is_err());
    }

    #[test]
    fn acs_admission_payload_rejects_boundary_spaced_mutation_agent_run_id_on_decode() {
        let mut envelope = mutation_envelope_fixture();
        envelope.actor = MutationActor::Agent {
            run_id: " run-1".to_string(),
        };
        let value = serde_json::json!({
            "kind": "mutation_envelope",
            "envelope": envelope,
        });

        assert!(serde_json::from_value::<ACSAdmissionPayload>(value).is_err());
    }

    #[test]
    fn acs_admission_payload_rejects_boundary_spaced_mutation_run_id_on_decode() {
        let mut envelope = mutation_envelope_fixture();
        envelope.run_id = Some(" run-1".to_string());
        let value = serde_json::json!({
            "kind": "mutation_envelope",
            "envelope": envelope,
        });

        assert!(serde_json::from_value::<ACSAdmissionPayload>(value).is_err());
    }

    #[test]
    fn acs_admission_payload_rejects_mismatched_mutation_agent_run_id_on_decode() {
        let mut envelope = mutation_envelope_fixture();
        envelope.run_id = Some("run-1".to_string());
        envelope.actor = MutationActor::Agent {
            run_id: "run-2".to_string(),
        };

        assert_mutation_envelope_payload_decode_rejects(envelope);
    }

    #[test]
    fn acs_admission_payload_rejects_missing_mutation_agent_run_id_on_decode() {
        let mut envelope = mutation_envelope_fixture();
        envelope.actor = MutationActor::Agent {
            run_id: "run-1".to_string(),
        };

        assert_mutation_envelope_payload_decode_rejects(envelope);
    }

    #[test]
    fn acs_admission_payload_rejects_null_mutation_run_id_on_decode() {
        let mut envelope = serde_json::to_value(mutation_envelope_fixture())
            .expect("mutation envelope serializes");
        envelope["run_id"] = serde_json::json!(null);
        let value = serde_json::json!({
            "kind": "mutation_envelope",
            "envelope": envelope,
        });

        assert!(serde_json::from_value::<ACSAdmissionPayload>(value).is_err());
    }

    #[test]
    fn acs_admission_payload_rejects_boundary_spaced_mutation_event_ref_on_decode() {
        let mut envelope = mutation_envelope_fixture();
        envelope.caused_by_event_id = Some(" event-1".to_string());
        let value = serde_json::json!({
            "kind": "mutation_envelope",
            "envelope": envelope,
        });

        assert!(serde_json::from_value::<ACSAdmissionPayload>(value).is_err());
    }

    #[test]
    fn acs_admission_payload_rejects_boundary_spaced_mutation_approval_id_on_decode() {
        let mut envelope = mutation_envelope_fixture();
        envelope.approval_id = Some(" approval-1".to_string());
        let value = serde_json::json!({
            "kind": "mutation_envelope",
            "envelope": envelope,
        });

        assert!(serde_json::from_value::<ACSAdmissionPayload>(value).is_err());
    }

    #[test]
    fn acs_admission_payload_rejects_negative_mutation_created_at_on_decode() {
        let mut envelope = mutation_envelope_fixture();
        envelope.created_at_ms = -1;

        assert_mutation_envelope_payload_decode_rejects(envelope);
    }

    #[test]
    fn acs_admission_payload_rejects_negative_mutation_committed_at_on_decode() {
        let mut envelope = mutation_envelope_fixture();
        envelope.committed_at_ms = Some(-1);

        assert_mutation_envelope_payload_decode_rejects(envelope);
    }

    #[test]
    fn acs_admission_payload_rejects_mutation_commit_before_creation_on_decode() {
        let mut envelope = mutation_envelope_fixture();
        envelope.created_at_ms = 1_000;
        envelope.committed_at_ms = Some(999);

        assert_mutation_envelope_payload_decode_rejects(envelope);
    }

    #[test]
    fn acs_admission_payload_rejects_pending_mutation_committed_at_on_decode() {
        let mut envelope = mutation_envelope_fixture();
        envelope.status = MutationStatus::Pending;
        envelope.committed_at_ms = Some(envelope.created_at_ms);

        assert_mutation_envelope_payload_decode_rejects(envelope);
    }

    #[test]
    fn acs_admission_payload_rejects_null_mutation_committed_at_on_decode() {
        let mut envelope = serde_json::to_value(mutation_envelope_fixture())
            .expect("mutation envelope serializes");
        envelope["committed_at_ms"] = serde_json::json!(null);
        let value = serde_json::json!({
            "kind": "mutation_envelope",
            "envelope": envelope,
        });

        assert!(serde_json::from_value::<ACSAdmissionPayload>(value).is_err());
    }

    #[test]
    fn acs_admission_payload_rejects_failed_mutation_committed_at_on_decode() {
        let mut envelope = mutation_envelope_fixture();
        envelope.status = MutationStatus::Failed;
        envelope.committed_at_ms = Some(envelope.created_at_ms);

        assert_mutation_envelope_payload_decode_rejects(envelope);
    }

    #[test]
    fn acs_admission_payload_rejects_committed_mutation_missing_committed_at_on_decode() {
        let mut envelope = mutation_envelope_fixture();
        envelope.status = MutationStatus::Committed;
        envelope.committed_at_ms = None;

        assert_mutation_envelope_payload_decode_rejects(envelope);
    }

    #[test]
    fn acs_admission_payload_rejects_reverted_mutation_missing_committed_at_on_decode() {
        let mut envelope = mutation_envelope_fixture();
        envelope.status = MutationStatus::Reverted;
        envelope.committed_at_ms = None;

        assert_mutation_envelope_payload_decode_rejects(envelope);
    }

    #[test]
    fn acs_admission_payload_rejects_committed_mutation_empty_hash_on_decode() {
        let mut envelope = mutation_envelope_fixture();
        envelope.status = MutationStatus::Committed;
        envelope.committed_at_ms = Some(envelope.created_at_ms);
        envelope.integrity_hash = String::new();

        assert_mutation_envelope_payload_decode_rejects(envelope);
    }

    #[test]
    fn acs_admission_payload_rejects_reverted_irreversible_mutation_on_decode() {
        let mut envelope = mutation_envelope_fixture();
        envelope.status = MutationStatus::Reverted;
        envelope.reversibility = Reversibility::Irreversible;
        envelope.committed_at_ms = Some(envelope.created_at_ms);
        envelope.integrity_hash = "ab".repeat(32);

        assert_mutation_envelope_payload_decode_rejects(envelope);
    }

    #[test]
    fn acs_admission_payload_rejects_short_mutation_hash_on_decode() {
        let mut envelope = mutation_envelope_fixture();
        envelope.integrity_hash = "abc123".to_string();

        assert_mutation_envelope_payload_decode_rejects(envelope);
    }

    #[test]
    fn acs_admission_payload_rejects_uppercase_mutation_hash_on_decode() {
        let mut envelope = mutation_envelope_fixture();
        envelope.integrity_hash = "AA".repeat(32);

        assert_mutation_envelope_payload_decode_rejects(envelope);
    }

    #[test]
    fn acs_admission_payload_rejects_zero_mutation_schema_version_on_decode() {
        let mut envelope = mutation_envelope_fixture();
        envelope.schema_version = 0;

        assert_mutation_envelope_payload_decode_rejects(envelope);
    }

    #[test]
    fn acs_admission_payload_rejects_boundary_spaced_mutation_touched_artifact_id_on_decode() {
        let mut envelope = mutation_envelope_fixture();
        envelope
            .touched_artifacts
            .push(ArtifactRef::new(" artifact-1"));
        let value = serde_json::json!({
            "kind": "mutation_envelope",
            "envelope": envelope,
        });

        assert!(serde_json::from_value::<ACSAdmissionPayload>(value).is_err());
    }

    #[test]
    fn acs_admission_payload_rejects_null_mutation_touched_artifact_title_on_decode() {
        let mut envelope = serde_json::to_value(mutation_envelope_fixture())
            .expect("mutation envelope serializes");
        envelope["touched_artifacts"] = serde_json::json!([
            {
                "id": "artifact-1",
                "title": null
            }
        ]);
        let value = serde_json::json!({
            "kind": "mutation_envelope",
            "envelope": envelope,
        });

        assert!(serde_json::from_value::<ACSAdmissionPayload>(value).is_err());
    }

    #[test]
    fn acs_admission_payload_rejects_boundary_spaced_mutation_touched_artifact_title_on_decode() {
        let mut envelope = mutation_envelope_fixture();
        envelope.touched_artifacts.push(ArtifactRef::full(
            "artifact-1",
            crate::artifacts::ArtifactKind::Document,
            " Document 1",
        ));

        assert_mutation_envelope_payload_decode_rejects(envelope);
    }

    #[test]
    fn acs_admission_payload_rejects_duplicate_mutation_touched_artifact_on_decode() {
        let mut envelope = mutation_envelope_fixture();
        envelope
            .touched_artifacts
            .push(ArtifactRef::new("artifact-1"));
        envelope
            .touched_artifacts
            .push(ArtifactRef::new("artifact-1"));

        assert_mutation_envelope_payload_decode_rejects(envelope);
    }

    #[test]
    fn acs_admission_payload_rejects_duplicate_mutation_touched_block_on_decode() {
        let mut envelope = mutation_envelope_fixture();
        envelope
            .touched_blocks
            .push(BlockRef::new("artifact-1", "block-1"));
        envelope
            .touched_blocks
            .push(BlockRef::new("artifact-1", "block-1"));

        assert_mutation_envelope_payload_decode_rejects(envelope);
    }

    #[test]
    fn acs_admission_payload_rejects_boundary_spaced_mutation_touched_block_artifact_id_on_decode()
    {
        let mut envelope = mutation_envelope_fixture();
        envelope
            .touched_blocks
            .push(BlockRef::new(" artifact-1", "block-1"));
        let value = serde_json::json!({
            "kind": "mutation_envelope",
            "envelope": envelope,
        });

        assert!(serde_json::from_value::<ACSAdmissionPayload>(value).is_err());
    }

    #[test]
    fn acs_admission_payload_rejects_boundary_spaced_mutation_touched_block_id_on_decode() {
        let mut envelope = mutation_envelope_fixture();
        envelope
            .touched_blocks
            .push(BlockRef::new("artifact-1", " block-1"));
        let value = serde_json::json!({
            "kind": "mutation_envelope",
            "envelope": envelope,
        });

        assert!(serde_json::from_value::<ACSAdmissionPayload>(value).is_err());
    }

    #[test]
    fn acs_admission_payload_rejects_boundary_spaced_mutation_relation_from_id_on_decode() {
        let mut envelope = mutation_envelope_fixture();
        envelope.relation_changes.push(RelationChange::Added {
            from_id: " artifact-1".to_string(),
            to_id: "artifact-2".to_string(),
            label: "cites".to_string(),
        });
        let value = serde_json::json!({
            "kind": "mutation_envelope",
            "envelope": envelope,
        });

        assert!(serde_json::from_value::<ACSAdmissionPayload>(value).is_err());
    }

    #[test]
    fn acs_admission_payload_rejects_boundary_spaced_mutation_relation_to_id_on_decode() {
        let mut envelope = mutation_envelope_fixture();
        envelope.relation_changes.push(RelationChange::Added {
            from_id: "artifact-1".to_string(),
            to_id: " artifact-2".to_string(),
            label: "cites".to_string(),
        });
        let value = serde_json::json!({
            "kind": "mutation_envelope",
            "envelope": envelope,
        });

        assert!(serde_json::from_value::<ACSAdmissionPayload>(value).is_err());
    }

    #[test]
    fn acs_admission_payload_rejects_boundary_spaced_mutation_relation_label_on_decode() {
        let mut envelope = mutation_envelope_fixture();
        envelope.relation_changes.push(RelationChange::Added {
            from_id: "artifact-1".to_string(),
            to_id: "artifact-2".to_string(),
            label: " cites".to_string(),
        });

        assert_mutation_envelope_payload_decode_rejects(envelope);
    }

    #[test]
    fn acs_admission_payload_rejects_duplicate_mutation_relation_change_on_decode() {
        let mut envelope = mutation_envelope_fixture();
        envelope.relation_changes.push(RelationChange::Added {
            from_id: "artifact-1".to_string(),
            to_id: "artifact-2".to_string(),
            label: "cites".to_string(),
        });
        envelope.relation_changes.push(RelationChange::Added {
            from_id: "artifact-1".to_string(),
            to_id: "artifact-2".to_string(),
            label: "cites".to_string(),
        });

        assert_mutation_envelope_payload_decode_rejects(envelope);
    }

    #[test]
    fn acs_admission_payload_rejects_contradictory_mutation_relation_change_on_decode() {
        let mut envelope = mutation_envelope_fixture();
        envelope.relation_changes.push(RelationChange::Added {
            from_id: "artifact-1".to_string(),
            to_id: "artifact-2".to_string(),
            label: "cites".to_string(),
        });
        envelope.relation_changes.push(RelationChange::Removed {
            from_id: "artifact-1".to_string(),
            to_id: "artifact-2".to_string(),
            label: "cites".to_string(),
        });

        assert_mutation_envelope_payload_decode_rejects(envelope);
    }

    #[test]
    fn acs_admission_payload_rejects_duplicate_mutation_relation_update_add_on_decode() {
        let mut envelope = mutation_envelope_fixture();
        envelope.relation_changes.push(RelationChange::Updated {
            from_id: "artifact-1".to_string(),
            to_id: "artifact-2".to_string(),
            old_label: "cites".to_string(),
            new_label: "supports".to_string(),
        });
        envelope.relation_changes.push(RelationChange::Added {
            from_id: "artifact-1".to_string(),
            to_id: "artifact-2".to_string(),
            label: "supports".to_string(),
        });

        assert_mutation_envelope_payload_decode_rejects(envelope);
    }

    #[test]
    fn acs_admission_payload_rejects_mutation_relation_update_add_old_label_on_decode() {
        let mut envelope = mutation_envelope_fixture();
        envelope.relation_changes.push(RelationChange::Updated {
            from_id: "artifact-1".to_string(),
            to_id: "artifact-2".to_string(),
            old_label: "cites".to_string(),
            new_label: "supports".to_string(),
        });
        envelope.relation_changes.push(RelationChange::Added {
            from_id: "artifact-1".to_string(),
            to_id: "artifact-2".to_string(),
            label: "cites".to_string(),
        });

        assert_mutation_envelope_payload_decode_rejects(envelope);
    }

    #[test]
    fn acs_admission_payload_rejects_duplicate_mutation_relation_update_remove_on_decode() {
        let mut envelope = mutation_envelope_fixture();
        envelope.relation_changes.push(RelationChange::Updated {
            from_id: "artifact-1".to_string(),
            to_id: "artifact-2".to_string(),
            old_label: "cites".to_string(),
            new_label: "supports".to_string(),
        });
        envelope.relation_changes.push(RelationChange::Removed {
            from_id: "artifact-1".to_string(),
            to_id: "artifact-2".to_string(),
            label: "cites".to_string(),
        });

        assert_mutation_envelope_payload_decode_rejects(envelope);
    }

    #[test]
    fn acs_admission_payload_rejects_mutation_relation_update_remove_new_label_on_decode() {
        let mut envelope = mutation_envelope_fixture();
        envelope.relation_changes.push(RelationChange::Updated {
            from_id: "artifact-1".to_string(),
            to_id: "artifact-2".to_string(),
            old_label: "cites".to_string(),
            new_label: "supports".to_string(),
        });
        envelope.relation_changes.push(RelationChange::Removed {
            from_id: "artifact-1".to_string(),
            to_id: "artifact-2".to_string(),
            label: "supports".to_string(),
        });

        assert_mutation_envelope_payload_decode_rejects(envelope);
    }

    #[test]
    fn acs_admission_payload_rejects_chained_mutation_relation_update_on_decode() {
        let mut envelope = mutation_envelope_fixture();
        envelope.relation_changes.push(RelationChange::Updated {
            from_id: "artifact-1".to_string(),
            to_id: "artifact-2".to_string(),
            old_label: "cites".to_string(),
            new_label: "supports".to_string(),
        });
        envelope.relation_changes.push(RelationChange::Updated {
            from_id: "artifact-1".to_string(),
            to_id: "artifact-2".to_string(),
            old_label: "supports".to_string(),
            new_label: "extends".to_string(),
        });

        assert_mutation_envelope_payload_decode_rejects(envelope);
    }

    #[test]
    fn acs_admission_payload_rejects_forked_mutation_relation_update_on_decode() {
        let mut envelope = mutation_envelope_fixture();
        envelope.relation_changes.push(RelationChange::Updated {
            from_id: "artifact-1".to_string(),
            to_id: "artifact-2".to_string(),
            old_label: "cites".to_string(),
            new_label: "supports".to_string(),
        });
        envelope.relation_changes.push(RelationChange::Updated {
            from_id: "artifact-1".to_string(),
            to_id: "artifact-2".to_string(),
            old_label: "cites".to_string(),
            new_label: "extends".to_string(),
        });

        assert_mutation_envelope_payload_decode_rejects(envelope);
    }

    #[test]
    fn acs_admission_payload_rejects_convergent_mutation_relation_update_on_decode() {
        let mut envelope = mutation_envelope_fixture();
        envelope.relation_changes.push(RelationChange::Updated {
            from_id: "artifact-1".to_string(),
            to_id: "artifact-2".to_string(),
            old_label: "cites".to_string(),
            new_label: "supports".to_string(),
        });
        envelope.relation_changes.push(RelationChange::Updated {
            from_id: "artifact-1".to_string(),
            to_id: "artifact-2".to_string(),
            old_label: "extends".to_string(),
            new_label: "supports".to_string(),
        });

        assert_mutation_envelope_payload_decode_rejects(envelope);
    }

    #[test]
    fn acs_admission_payload_rejects_noop_mutation_relation_update_on_decode() {
        let mut envelope = mutation_envelope_fixture();
        envelope.relation_changes.push(RelationChange::Updated {
            from_id: "artifact-1".to_string(),
            to_id: "artifact-2".to_string(),
            old_label: "cites".to_string(),
            new_label: "cites".to_string(),
        });

        assert_mutation_envelope_payload_decode_rejects(envelope);
    }

    #[test]
    fn acs_admission_payload_rejects_boundary_spaced_mutation_relation_old_label_on_decode() {
        let mut envelope = mutation_envelope_fixture();
        envelope.relation_changes.push(RelationChange::Updated {
            from_id: "artifact-1".to_string(),
            to_id: "artifact-2".to_string(),
            old_label: " cites".to_string(),
            new_label: "supports".to_string(),
        });

        assert_mutation_envelope_payload_decode_rejects(envelope);
    }

    #[test]
    fn acs_admission_payload_rejects_boundary_spaced_mutation_relation_new_label_on_decode() {
        let mut envelope = mutation_envelope_fixture();
        envelope.relation_changes.push(RelationChange::Updated {
            from_id: "artifact-1".to_string(),
            to_id: "artifact-2".to_string(),
            old_label: "cites".to_string(),
            new_label: " supports".to_string(),
        });

        assert_mutation_envelope_payload_decode_rejects(envelope);
    }

    #[test]
    fn acs_admission_payload_rejects_shadow_answer_packet_field_on_decode() {
        let mut packet = serde_json::to_value(AnswerPacket::new(
            AnswerPacketId::new("answer-1"),
            WitnessedStateId::new("state-1"),
            MutationEnvelopeId::new("mutation-1"),
        ))
        .expect("answer packet serializes");
        packet["shadow_mutation_envelope_ref"] = serde_json::json!("mutation-shadow");
        let value = serde_json::json!({
            "kind": "answer_packet",
            "packet": packet,
        });

        assert!(serde_json::from_value::<ACSAdmissionPayload>(value).is_err());
    }

    #[test]
    fn acs_admission_answer_packet_rejects_shadow_residency_signal_field_on_decode() {
        let mut packet = serde_json::to_value(
            AnswerPacket::new(
                AnswerPacketId::new("answer-1"),
                WitnessedStateId::new("state-1"),
                MutationEnvelopeId::new("mutation-1"),
            )
            .push_residency_signal(ResidencySignal::neutral()),
        )
        .expect("answer packet serializes");
        packet["residency_signals"][0]["shadow_privacy"] = serde_json::json!(0.0);
        let value = serde_json::json!({
            "kind": "answer_packet",
            "packet": packet,
        });

        assert!(serde_json::from_value::<ACSAdmissionPayload>(value).is_err());
    }

    #[test]
    fn acs_admission_input_round_trips_with_payload_operation() {
        let input = ACSAdmissionInput {
            request_id: "req-round-trip".to_string(),
            payload: ACSAdmissionPayload::MemoryWrite {
                request: ACSMemoryWriteRequest {
                    address: "uas://note/round-trip".to_string(),
                    content_hash: "content-hash".to_string(),
                    durable: true,
                    mutation_envelope_id: Some("mutation-1".to_string()),
                },
            },
            submitted_at_ms: 1_001,
            risk: ACSRiskVector::neutral(),
            granted_capabilities: Vec::new(),
        };

        let json = serde_json::to_string(&input).expect("input must serialize");
        let decoded: ACSAdmissionInput =
            serde_json::from_str(&json).expect("input must deserialize");

        assert_eq!(decoded.operation(), ACSOperationKind::MemoryWrite);
        assert_eq!(decoded, input);

        let mut extra_field =
            serde_json::to_value(&input).expect("admission input must encode to JSON object");
        extra_field["shadow_policy_id"] = serde_json::json!("policy-smuggled");
        assert!(serde_json::from_value::<ACSAdmissionInput>(extra_field).is_err());

        let mut extra_payload_field =
            serde_json::to_value(&input).expect("admission input must encode to JSON object");
        extra_payload_field["payload"]["shadow_request"] = serde_json::json!("smuggled");
        assert!(serde_json::from_value::<ACSAdmissionInput>(extra_payload_field).is_err());

        let mut extra_memory_write_field =
            serde_json::to_value(&input).expect("admission input must encode to JSON object");
        extra_memory_write_field["payload"]["request"]["shadow_address"] =
            serde_json::json!("uas://note/smuggled");
        assert!(serde_json::from_value::<ACSAdmissionInput>(extra_memory_write_field).is_err());

        let mut forged_request_id =
            serde_json::to_value(&input).expect("admission input must encode to JSON object");
        forged_request_id["request_id"] = serde_json::json!(" req-round-trip ");
        assert!(serde_json::from_value::<ACSAdmissionInput>(forged_request_id).is_err());
    }

    #[test]
    fn acs_admission_missing_input_risk_names_forged_admission_input_field() {
        let value = serde_json::json!({
            "request_id": "req-missing-risk",
            "payload": {
                "kind": "tool_action",
                "request": {
                    "tool_name": "vault.write",
                    "target": "uas://note/1",
                    "mutation_envelope_id": "mutation-1"
                }
            },
            "submitted_at_ms": 1_001,
            "granted_capabilities": []
        });

        let err = serde_json::from_value::<ACSAdmissionInput>(value).unwrap_err();
        let message = err.to_string();

        assert!(message.contains("forged_admission_input"), "{message}");
        assert!(message.contains("admission_input.risk"), "{message}");
    }

    #[test]
    fn acs_admission_unknown_input_payload_kind_names_forged_admission_input_field() {
        let value = serde_json::json!({
            "request_id": "req-unknown-payload-kind",
            "payload": {
                "kind": "quantum_commit",
                "request": {
                    "tool_name": "vault.write",
                    "target": "uas://note/1",
                    "mutation_envelope_id": "mutation-1"
                }
            },
            "submitted_at_ms": 1_001,
            "risk": ACSRiskVector::neutral(),
            "granted_capabilities": []
        });

        let err = serde_json::from_value::<ACSAdmissionInput>(value).unwrap_err();
        let message = err.to_string();

        assert!(message.contains("forged_admission_input"), "{message}");
        assert!(message.contains("admission_input.payload"), "{message}");
    }

    #[test]
    fn acs_admission_shadow_input_payload_field_names_forged_admission_input_field() {
        let value = serde_json::json!({
            "request_id": "req-shadow-payload-field",
            "payload": {
                "kind": "tool_action",
                "request": {
                    "tool_name": "vault.write",
                    "target": "uas://note/1",
                    "mutation_envelope_id": "mutation-1"
                },
                "shadow_request": {
                    "tool_name": "vault.delete",
                    "target": "uas://note/1"
                }
            },
            "submitted_at_ms": 1_001,
            "risk": ACSRiskVector::neutral(),
            "granted_capabilities": []
        });

        let err = serde_json::from_value::<ACSAdmissionInput>(value).unwrap_err();
        let message = err.to_string();

        assert!(message.contains("forged_admission_input"), "{message}");
        assert!(
            message.contains("admission_input.payload.shadow_request"),
            "{message}"
        );
    }

    #[test]
    fn acs_admission_shadow_memory_write_field_names_forged_admission_input_field() {
        let value = serde_json::json!({
            "address": "uas://note/1",
            "content_hash": "blake3:abc",
            "durable": false,
            "shadow_address": "uas://note/smuggled"
        });

        let err = serde_json::from_value::<ACSMemoryWriteRequest>(value).unwrap_err();
        let message = err.to_string();

        assert!(message.contains("forged_admission_input"), "{message}");
        assert!(message.contains("memory_write.shadow_address"), "{message}");
    }

    #[test]
    fn acs_admission_shadow_tool_action_field_names_forged_admission_input_field() {
        let value = serde_json::json!({
            "tool_name": "vault.write",
            "target": "uas://note/1",
            "mutation_envelope_id": "mutation-1",
            "shadow_tool": "vault.delete"
        });

        let err = serde_json::from_value::<ACSToolActionRequest>(value).unwrap_err();
        let message = err.to_string();

        assert!(message.contains("forged_admission_input"), "{message}");
        assert!(message.contains("tool_action.shadow_tool"), "{message}");
    }

    #[test]
    fn acs_admission_shadow_kernel_promotion_field_names_forged_admission_input_field() {
        let value = serde_json::json!({
            "kernel_id": "kernel-1",
            "signed_plan_hash": "blake3:abc",
            "mutation_envelope_id": "mutation-1",
            "shadow_kernel": "kernel-smuggled"
        });

        let err = serde_json::from_value::<ACSKernelPromotionRequest>(value).unwrap_err();
        let message = err.to_string();

        assert!(message.contains("forged_admission_input"), "{message}");
        assert!(
            message.contains("kernel_promotion.shadow_kernel"),
            "{message}"
        );
    }

    #[test]
    fn acs_admission_shadow_model_adaptation_field_names_forged_admission_input_field() {
        let value = serde_json::json!({
            "adapter_id": "adapter-1",
            "model_id": "model-1",
            "checkpoint_hash": "blake3:abc",
            "mutation_envelope_id": "mutation-1",
            "shadow_adapter": "adapter-smuggled"
        });

        let err = serde_json::from_value::<ACSModelAdaptationRequest>(value).unwrap_err();
        let message = err.to_string();

        assert!(message.contains("forged_admission_input"), "{message}");
        assert!(
            message.contains("model_adaptation.shadow_adapter"),
            "{message}"
        );
    }

    #[test]
    fn acs_admission_shadow_input_field_names_forged_admission_input_field() {
        let value = serde_json::json!({
            "request_id": "req-shadow",
            "payload": {
                "kind": "memory_write",
                "request": {
                    "address": "uas://note/1",
                    "content_hash": "blake3:abc",
                    "durable": false
                }
            },
            "submitted_at_ms": 1_001,
            "risk": ACSRiskVector::neutral(),
            "granted_capabilities": [],
            "shadow_policy_id": "policy-smuggled"
        });

        let err = serde_json::from_value::<ACSAdmissionInput>(value).unwrap_err();
        let message = err.to_string();

        assert!(message.contains("forged_admission_input"), "{message}");
        assert!(
            message.contains("admission_input.shadow_policy_id"),
            "{message}"
        );
    }

    #[test]
    fn acs_admission_input_decode_names_malformed_granted_capability() {
        let value = serde_json::json!({
            "request_id": "req-granted-capability-field",
            "payload": {
                "kind": "tool_action",
                "request": {
                    "tool_name": "vault.write",
                    "target": "uas://note/1",
                    "mutation_envelope_id": "mutation-1"
                }
            },
            "submitted_at_ms": 1_001,
            "risk": ACSRiskVector::neutral(),
            "granted_capabilities": [
                {
                    "kind": "other",
                    "value": {
                        "name": "Tool Exec"
                    }
                }
            ]
        });

        let err = serde_json::from_value::<ACSAdmissionInput>(value).unwrap_err();
        let message = err.to_string();

        assert!(message.contains("forged_admission_input"), "{message}");
        assert!(
            message.contains("granted_capabilities.other.name"),
            "{message}"
        );
    }

    #[test]
    fn acs_admission_input_decode_names_shadow_granted_capability_field() {
        let value = serde_json::json!({
            "request_id": "req-shadow-granted-capability-field",
            "payload": {
                "kind": "tool_action",
                "request": {
                    "tool_name": "vault.write",
                    "target": "uas://note/1",
                    "mutation_envelope_id": "mutation-1"
                }
            },
            "submitted_at_ms": 1_001,
            "risk": ACSRiskVector::neutral(),
            "granted_capabilities": [
                {
                    "kind": "other",
                    "value": {
                        "name": "ToolExec",
                        "shadow_name": "KernelPromote"
                    }
                }
            ]
        });

        let err = serde_json::from_value::<ACSAdmissionInput>(value).unwrap_err();
        let message = err.to_string();

        assert!(message.contains("forged_admission_input"), "{message}");
        assert!(
            message.contains("granted_capabilities.other.shadow_name"),
            "{message}"
        );
    }

    #[test]
    fn acs_admission_input_decode_names_shadow_granted_capability_envelope_field() {
        let value = serde_json::json!({
            "request_id": "req-shadow-granted-capability-envelope-field",
            "payload": {
                "kind": "tool_action",
                "request": {
                    "tool_name": "vault.write",
                    "target": "uas://note/1",
                    "mutation_envelope_id": "mutation-1"
                }
            },
            "submitted_at_ms": 1_001,
            "risk": ACSRiskVector::neutral(),
            "granted_capabilities": [
                {
                    "kind": "other",
                    "value": {
                        "name": "ToolExec"
                    },
                    "shadow_kind": "network_host"
                }
            ]
        });

        let err = serde_json::from_value::<ACSAdmissionInput>(value).unwrap_err();
        let message = err.to_string();

        assert!(message.contains("forged_admission_input"), "{message}");
        assert!(
            message.contains("granted_capabilities.shadow_kind"),
            "{message}"
        );
    }

    #[test]
    fn acs_admission_input_decode_names_nonobject_granted_capability() {
        let value = serde_json::json!({
            "request_id": "req-nonobject-granted-capability",
            "payload": {
                "kind": "tool_action",
                "request": {
                    "tool_name": "vault.write",
                    "target": "uas://note/1",
                    "mutation_envelope_id": "mutation-1"
                }
            },
            "submitted_at_ms": 1_001,
            "risk": ACSRiskVector::neutral(),
            "granted_capabilities": ["ToolExec"]
        });

        let err = serde_json::from_value::<ACSAdmissionInput>(value).unwrap_err();
        let message = err.to_string();

        assert!(message.contains("forged_admission_input"), "{message}");
        assert!(
            message.contains("granted_capabilities.capability"),
            "{message}"
        );
    }

    #[test]
    fn acs_admission_input_decode_names_missing_granted_capability_kind() {
        let value = serde_json::json!({
            "request_id": "req-missing-granted-capability-kind",
            "payload": {
                "kind": "tool_action",
                "request": {
                    "tool_name": "vault.write",
                    "target": "uas://note/1",
                    "mutation_envelope_id": "mutation-1"
                }
            },
            "submitted_at_ms": 1_001,
            "risk": ACSRiskVector::neutral(),
            "granted_capabilities": [
                {
                    "value": {
                        "name": "ToolExec"
                    }
                }
            ]
        });

        let err = serde_json::from_value::<ACSAdmissionInput>(value).unwrap_err();
        let message = err.to_string();

        assert!(message.contains("forged_admission_input"), "{message}");
        assert!(
            message.contains("granted_capabilities.capability"),
            "{message}"
        );
    }

    #[test]
    fn acs_admission_input_decode_names_unknown_granted_capability_kind() {
        let value = serde_json::json!({
            "request_id": "req-unknown-granted-capability-kind",
            "payload": {
                "kind": "tool_action",
                "request": {
                    "tool_name": "vault.write",
                    "target": "uas://note/1",
                    "mutation_envelope_id": "mutation-1"
                }
            },
            "submitted_at_ms": 1_001,
            "risk": ACSRiskVector::neutral(),
            "granted_capabilities": [
                {
                    "kind": "root_access",
                    "value": {
                        "name": "ToolExec"
                    }
                }
            ]
        });

        let err = serde_json::from_value::<ACSAdmissionInput>(value).unwrap_err();
        let message = err.to_string();

        assert!(message.contains("forged_admission_input"), "{message}");
        assert!(
            message.contains("granted_capabilities.capability"),
            "{message}"
        );
    }

    #[test]
    fn acs_admission_input_decode_names_missing_granted_vault_path_verb() {
        let value = serde_json::json!({
            "request_id": "req-missing-granted-vault-path-verb",
            "payload": {
                "kind": "tool_action",
                "request": {
                    "tool_name": "vault.write",
                    "target": "uas://note/1",
                    "mutation_envelope_id": "mutation-1"
                }
            },
            "submitted_at_ms": 1_001,
            "risk": ACSRiskVector::neutral(),
            "granted_capabilities": [
                {
                    "kind": "vault_path",
                    "value": {
                        "path": "uas://note/1"
                    }
                }
            ]
        });

        let err = serde_json::from_value::<ACSAdmissionInput>(value).unwrap_err();
        let message = err.to_string();

        assert!(message.contains("forged_admission_input"), "{message}");
        assert!(
            message.contains("granted_capabilities.vault_path.verb"),
            "{message}"
        );
    }

    #[test]
    fn acs_admission_input_decode_names_duplicate_granted_capability() {
        let capability = serde_json::json!({
            "kind": "other",
            "value": {
                "name": "ToolExec"
            }
        });
        let value = serde_json::json!({
            "request_id": "req-duplicate-granted-capability",
            "payload": {
                "kind": "tool_action",
                "request": {
                    "tool_name": "vault.write",
                    "target": "uas://note/1",
                    "mutation_envelope_id": "mutation-1"
                }
            },
            "submitted_at_ms": 1_001,
            "risk": ACSRiskVector::neutral(),
            "granted_capabilities": [capability.clone(), capability]
        });

        let err = serde_json::from_value::<ACSAdmissionInput>(value).unwrap_err();
        let message = err.to_string();

        assert!(message.contains("forged_admission_input"), "{message}");
        assert!(
            message.contains("granted_capabilities.duplicate_capability"),
            "{message}"
        );
    }

    #[test]
    fn acs_admission_memory_write_request_rejects_missing_durable_ref_on_decode() {
        let value = serde_json::json!({
            "address": "uas://note/1",
            "content_hash": "content-hash",
            "durable": true,
            "mutation_envelope_id": null,
        });

        assert!(serde_json::from_value::<ACSMemoryWriteRequest>(value).is_err());
    }

    #[test]
    fn acs_admission_memory_write_request_rejects_boundary_spaced_nondurable_ref_on_decode() {
        let value = serde_json::json!({
            "address": "uas://note/1",
            "content_hash": "content-hash",
            "durable": false,
            "mutation_envelope_id": " mutation-1",
        });

        let err = serde_json::from_value::<ACSMemoryWriteRequest>(value).unwrap_err();
        let message = err.to_string();

        assert!(message.contains("forged_admission_input"), "{message}");
        assert!(
            message.contains("memory_write.mutation_envelope_id"),
            "{message}"
        );
    }

    #[test]
    fn acs_admission_tool_action_request_rejects_unknown_fields() {
        let value = serde_json::json!({
            "tool_name": "local-tool",
            "target": "note-1",
            "mutation_envelope_id": null,
            "shadow_tool": "remote-tool",
        });

        assert!(serde_json::from_value::<ACSToolActionRequest>(value).is_err());
    }

    #[test]
    fn acs_admission_tool_action_request_rejects_boundary_spaced_tool_name_on_decode() {
        let value = serde_json::json!({
            "tool_name": " local-tool",
            "target": "note-1",
        });

        let err = serde_json::from_value::<ACSToolActionRequest>(value).unwrap_err();
        let message = err.to_string();

        assert!(message.contains("forged_admission_input"), "{message}");
        assert!(message.contains("tool_action.tool_name"), "{message}");
    }

    #[test]
    fn acs_admission_forged_payload_reason_precedes_malformed_policy() {
        let input = ACSAdmissionInput {
            request_id: "req-forged-payload-policy-mask".to_string(),
            payload: ACSAdmissionPayload::ToolAction {
                request: ACSToolActionRequest {
                    tool_name: " local-tool".to_string(),
                    target: "note-1".to_string(),
                    mutation_envelope_id: None,
                },
            },
            submitted_at_ms: 1_001,
            risk: ACSRiskVector::neutral(),
            granted_capabilities: Vec::new(),
        };
        let mut policy = ACSPolicy::strict("policy-forged-payload-policy-mask", 1_000);
        policy.thresholds.warn_at = f32::NAN;
        let mut audit_log = Vec::new();

        let decision = admit_and_log(&input, &policy, 1_001, &mut audit_log);

        assert_eq!(decision.verdict, ACSAdmissionVerdict::Reject);
        assert_eq!(decision.audit_record.reason, "forged_admission_input");
        assert_eq!(audit_log.len(), 1);
        assert!(decision.audit_record.validate().is_ok());
    }

    #[test]
    fn acs_admission_tool_action_request_rejects_boundary_spaced_mutation_ref_on_decode() {
        let value = serde_json::json!({
            "tool_name": "local-tool",
            "target": "note-1",
            "mutation_envelope_id": " mutation-1",
        });

        assert!(serde_json::from_value::<ACSToolActionRequest>(value).is_err());
    }

    #[test]
    fn acs_admission_tool_action_request_rejects_null_mutation_ref_on_decode() {
        let value = serde_json::json!({
            "tool_name": "local-tool",
            "target": "note-1",
            "mutation_envelope_id": null,
        });

        assert!(serde_json::from_value::<ACSToolActionRequest>(value).is_err());
    }

    #[test]
    fn acs_admission_kernel_promotion_request_rejects_unknown_fields() {
        let value = serde_json::json!({
            "kernel_id": "kernel-1",
            "signed_plan_hash": "plan-hash",
            "mutation_envelope_id": "mutation-1",
            "unsigned_plan_hash": "plan-shadow",
        });

        assert!(serde_json::from_value::<ACSKernelPromotionRequest>(value).is_err());
    }

    #[test]
    fn acs_admission_kernel_promotion_request_rejects_missing_ref_on_decode() {
        let value = serde_json::json!({
            "kernel_id": "kernel-1",
            "signed_plan_hash": "plan-hash",
        });

        let err = serde_json::from_value::<ACSKernelPromotionRequest>(value).unwrap_err();
        let message = err.to_string();

        assert!(
            message.contains("kernel_promotion_bypass_attempt"),
            "{message}"
        );
        assert!(
            message.contains("kernel_promotion.mutation_envelope_id"),
            "{message}"
        );
    }

    #[test]
    fn acs_admission_model_adaptation_request_rejects_unknown_fields() {
        let value = serde_json::json!({
            "adapter_id": "adapter-1",
            "model_id": "local-helper-1",
            "checkpoint_hash": "checkpoint-hash",
            "mutation_envelope_id": "mutation-1",
            "shadow_checkpoint_hash": "checkpoint-shadow",
        });

        assert!(serde_json::from_value::<ACSModelAdaptationRequest>(value).is_err());
    }

    #[test]
    fn acs_admission_model_adaptation_request_rejects_missing_ref_on_decode() {
        let value = serde_json::json!({
            "adapter_id": "adapter-1",
            "model_id": "local-helper-1",
            "checkpoint_hash": "checkpoint-hash",
        });

        let err = serde_json::from_value::<ACSModelAdaptationRequest>(value).unwrap_err();
        let message = err.to_string();

        assert!(
            message.contains("model_adaptation_bypass_attempt"),
            "{message}"
        );
        assert!(
            message.contains("model_adaptation.mutation_envelope_id"),
            "{message}"
        );
    }

    #[test]
    fn acs_admission_active_assembly_packet_rejects_unknown_fields() {
        let value = serde_json::json!({
            "assembly_id": "assembly-1",
            "active_support_ids": ["note-1"],
            "witness_hash": "witness-hash",
            "shadow_witness_hash": "witness-shadow",
        });

        assert!(serde_json::from_value::<ActiveAssemblyPacket>(value).is_err());
    }

    #[test]
    fn acs_admission_active_assembly_packet_rejects_boundary_spaced_support_on_decode() {
        let value = serde_json::json!({
            "assembly_id": "assembly-1",
            "active_support_ids": [" note-1"],
            "witness_hash": "witness-hash",
        });

        let err = serde_json::from_value::<ActiveAssemblyPacket>(value).unwrap_err();
        let message = err.to_string();

        assert!(message.contains("forged_admission_input"), "{message}");
        assert!(
            message.contains("active_assembly.active_support_ids"),
            "{message}"
        );
    }

    #[test]
    fn acs_admission_active_assembly_packet_rejects_duplicate_support_on_decode() {
        let value = serde_json::json!({
            "assembly_id": "assembly-1",
            "active_support_ids": ["note-1", "note-1"],
            "witness_hash": "witness-hash",
        });

        assert!(serde_json::from_value::<ActiveAssemblyPacket>(value).is_err());
    }

    #[test]
    fn acs_admission_property_no_durable_write_bypasses_acs() {
        for mutation_envelope_id in [
            None,
            Some(String::new()),
            Some("  ".to_string()),
            Some(" mutation-1".to_string()),
            Some("mutation-1 ".to_string()),
        ] {
            let input = ACSAdmissionInput {
                request_id: "req-durable-write".to_string(),
                payload: ACSAdmissionPayload::MemoryWrite {
                    request: ACSMemoryWriteRequest {
                        address: "uas://note/1".to_string(),
                        content_hash: "content-hash".to_string(),
                        durable: true,
                        mutation_envelope_id,
                    },
                },
                submitted_at_ms: 1_001,
                risk: ACSRiskVector::neutral(),
                granted_capabilities: Vec::new(),
            };
            let policy = ACSPolicy::strict("policy-durable-write", 1_000);
            let mut audit_log = Vec::new();

            let decision = admit_and_log(&input, &policy, 1_001, &mut audit_log);

            assert_eq!(decision.verdict, ACSAdmissionVerdict::Reject);
            assert_eq!(decision.audit_record.reason, "durable_write_bypass_attempt");
            assert_eq!(audit_log.len(), 1);
        }
    }

    #[test]
    fn acs_admission_durable_write_bypass_reason_precedes_malformed_policy() {
        let input = ACSAdmissionInput {
            request_id: "req-durable-write-policy-mask".to_string(),
            payload: ACSAdmissionPayload::MemoryWrite {
                request: ACSMemoryWriteRequest {
                    address: "uas://note/1".to_string(),
                    content_hash: "content-hash".to_string(),
                    durable: true,
                    mutation_envelope_id: None,
                },
            },
            submitted_at_ms: 1_001,
            risk: ACSRiskVector::neutral(),
            granted_capabilities: Vec::new(),
        };
        let mut policy = ACSPolicy::strict("policy-durable-write-policy-mask", 1_000);
        policy.thresholds.warn_at = f32::NAN;
        let mut audit_log = Vec::new();

        let decision = admit_and_log(&input, &policy, 1_001, &mut audit_log);

        assert_eq!(decision.verdict, ACSAdmissionVerdict::Reject);
        assert_eq!(decision.audit_record.reason, "durable_write_bypass_attempt");
        assert_eq!(audit_log.len(), 1);
        assert!(decision.audit_record.validate().is_ok());
    }

    #[test]
    fn acs_admission_kernel_promotion_bypass_attempt_is_rejected() {
        for mutation_envelope_id in [
            None,
            Some(String::new()),
            Some("  ".to_string()),
            Some(" mutation-1".to_string()),
            Some("mutation-1 ".to_string()),
        ] {
            let input = ACSAdmissionInput {
                request_id: "req-kernel-promotion".to_string(),
                payload: ACSAdmissionPayload::KernelPromotion {
                    request: ACSKernelPromotionRequest {
                        kernel_id: "kernel-1".to_string(),
                        signed_plan_hash: "plan-hash".to_string(),
                        mutation_envelope_id,
                    },
                },
                submitted_at_ms: 1_001,
                risk: ACSRiskVector::neutral(),
                granted_capabilities: Vec::new(),
            };
            let policy = ACSPolicy::strict("policy-kernel-promotion", 1_000);
            let mut audit_log = Vec::new();

            let decision = admit_and_log(&input, &policy, 1_001, &mut audit_log);

            assert_eq!(decision.verdict, ACSAdmissionVerdict::Reject);
            assert_eq!(
                decision.audit_record.reason,
                "kernel_promotion_bypass_attempt"
            );
            assert_eq!(audit_log.len(), 1);
        }
    }

    #[test]
    fn acs_admission_doc_pins_scope_rex_placement_and_layers() {
        let doc = include_str!("../../../docs/ACS_ADMISSION_FIELD_2026_05_18.md");

        for needle in [
            "ACS (Anchored Cognitive Substrate",
            "Autopoietic Cognitive Stack",
            "above SCOPE-Rex",
            "MutationEnvelope",
            "pure-data verdict",
            "No ACS admission path calls cloud services",
            "runs model inference",
            "applies durable state directly",
            "guard_durable_commit",
            "ACS-L0",
            "ACS-L1",
            "ACS-L2",
            "MASTER_FUSION §3.8",
        ] {
            assert!(doc.contains(needle), "missing doc anchor: {needle}");
        }
    }

    #[test]
    fn acs_admission_doc_pins_all_verdicts_logged() {
        let doc = include_str!("../../../docs/ACS_ADMISSION_FIELD_2026_05_18.md");

        for needle in [
            "allow",
            "allow-with-warning",
            "defer",
            "quarantine",
            "reject",
            "ACSAuditRecord",
            "Every ACSAdmissionVerdict emits",
        ] {
            assert!(doc.contains(needle), "missing doc verdict anchor: {needle}");
        }
    }

    #[test]
    fn acs_admission_doc_pins_default_policy_matrix() {
        let doc = include_str!("../../../docs/ACS_ADMISSION_FIELD_2026_05_18.md");

        for needle in [
            "Strict default policy matrix",
            "MemoryWrite",
            "VaultWrite",
            "quarantine_at=0.75",
            "ToolAction",
            "ToolExec",
            "quarantine_at=0.65",
            "ActiveAssemblyPacket",
            "Assembly",
            "defer_at=0.55",
            "KernelPromotion",
            "KernelPromote",
            "reject_at=0.60",
            "ModelAdaptation",
            "ModelAdapt",
            "reject_at=0.50",
        ] {
            assert!(doc.contains(needle), "missing doc matrix anchor: {needle}");
        }
    }

    #[test]
    fn acs_admission_doc_pins_phase2_doc_only_contracts() {
        let doc = include_str!("../../../docs/ACS_ADMISSION_FIELD_2026_05_18.md");
        let backlog =
            include_str!("../../../docs/audits/CROSS_TERMINAL_WIRING_BACKLOG_2026_05_17.md");

        for needle in [
            "Phase 2 doc-only contracts",
            "ACSAuditSink trait shape",
            "InMemoryACSAuditSink for testing",
            "SCOPERexAdmissionProof shape",
            "T11 owns RunEventLog wire",
        ] {
            assert!(doc.contains(needle), "missing doc-only anchor: {needle}");
        }

        assert!(
            backlog.contains("T11 owns RunEventLog wire"),
            "missing W-row T11 wire ownership anchor"
        );
    }

    #[test]
    fn acs_admission_all_verdict_paths_are_logged() {
        let cases = [
            (0.1, ACSAdmissionVerdict::Allow),
            (0.4, ACSAdmissionVerdict::AllowWithWarning),
            (0.6, ACSAdmissionVerdict::Defer),
            (0.8, ACSAdmissionVerdict::Quarantine),
            (0.95, ACSAdmissionVerdict::Reject),
        ];
        let policy = ACSPolicy::strict("policy-verdicts", 1_000);

        for (idx, (risk_value, expected)) in cases.into_iter().enumerate() {
            let mut risk = ACSRiskVector::neutral();
            risk.truth_risk = risk_value;
            let input = ACSAdmissionInput {
                request_id: format!("req-verdict-{idx}"),
                payload: tool_action_payload(),
                submitted_at_ms: 1_001,
                risk,
                granted_capabilities: Vec::new(),
            };
            let mut audit_log = Vec::new();

            let decision = admit_and_log(&input, &policy, 1_001, &mut audit_log);

            assert_eq!(decision.verdict, expected);
            assert_eq!(audit_log.len(), 1);
            assert_eq!(audit_log[0].verdict, expected);
            assert_eq!(audit_log[0].reason, expected.code());
        }
    }

    #[test]
    fn acs_admission_emitted_audit_records_validate() {
        let policy = ACSPolicy::strict("policy-audit-validity", 1_000);

        for risk_value in [0.0, 0.4, 0.6, 0.8, 0.95] {
            let mut risk = ACSRiskVector::neutral();
            risk.safety_risk = risk_value;
            let input = ACSAdmissionInput {
                request_id: format!("req-audit-validity-{risk_value}"),
                payload: tool_action_payload(),
                submitted_at_ms: 1_001,
                risk,
                granted_capabilities: Vec::new(),
            };
            let mut audit_log = Vec::new();

            let decision = admit_and_log(&input, &policy, 1_001, &mut audit_log);

            assert!(decision.audit_record.validate().is_ok());
            assert!(audit_log[0].validate().is_ok());
        }
    }

    #[test]
    fn acs_admission_audit_record_preserves_max_risk_axis() {
        let mut risk = ACSRiskVector::neutral();
        risk.truth_risk = 0.2;
        risk.privacy_risk = 0.64;
        risk.durability_risk = 0.41;
        let input = ACSAdmissionInput {
            request_id: "req-risk-max".to_string(),
            payload: tool_action_payload(),
            submitted_at_ms: 1_001,
            risk,
            granted_capabilities: Vec::new(),
        };
        let policy = ACSPolicy::strict("policy-risk-max", 1_000);
        let mut audit_log = Vec::new();

        let decision = admit_and_log(&input, &policy, 1_001, &mut audit_log);

        assert_eq!(decision.audit_record.risk_max, 0.64);
        assert_eq!(audit_log[0].risk_max, 0.64);
    }

    #[test]
    fn acs_admission_audit_record_preserves_policy_version() {
        let mut policy = ACSPolicy::strict("policy-versioned", 1_000);
        policy.version = 7;
        let input = ACSAdmissionInput {
            request_id: "req-policy-version".to_string(),
            payload: tool_action_payload(),
            submitted_at_ms: 1_001,
            risk: ACSRiskVector::neutral(),
            granted_capabilities: Vec::new(),
        };
        let mut audit_log = Vec::new();

        let decision = admit_and_log(&input, &policy, 1_001, &mut audit_log);

        assert_eq!(decision.audit_record.policy_version, 7);
        assert_eq!(audit_log[0].policy_version, 7);
    }

    #[test]
    fn acs_admission_audit_record_preserves_request_and_policy_ids() {
        let policy = ACSPolicy::strict("policy-identity", 1_000);
        let input = ACSAdmissionInput {
            request_id: "req-identity".to_string(),
            payload: tool_action_payload(),
            submitted_at_ms: 1_001,
            risk: ACSRiskVector::neutral(),
            granted_capabilities: Vec::new(),
        };
        let mut audit_log = Vec::new();

        let decision = admit_and_log(&input, &policy, 1_001, &mut audit_log);

        assert_eq!(decision.audit_record.request_id, "req-identity");
        assert_eq!(decision.audit_record.policy_id, "policy-identity");
        assert_eq!(audit_log[0].request_id, "req-identity");
        assert_eq!(audit_log[0].policy_id, "policy-identity");
    }

    #[test]
    fn acs_admission_audit_record_exposes_product_lane() {
        let mut record = audit_record_fixture(ACSAdmissionVerdict::Allow);
        record.operation = ACSOperationKind::ToolAction;

        assert_eq!(record.lane(), ACSLane::L1);
        assert_eq!(record.product_lane_code(), "agent_tool_loops");
    }

    #[test]
    fn acs_admission_audit_record_round_trips() {
        let record = audit_record_fixture(ACSAdmissionVerdict::AllowWithWarning);

        let json = serde_json::to_string(&record).expect("audit record must serialize");
        let decoded: ACSAuditRecord =
            serde_json::from_str(&json).expect("audit record must deserialize");

        assert_eq!(decoded, record);
        assert_eq!(decoded.operation, ACSOperationKind::MemoryWrite);
        assert_eq!(decoded.verdict, ACSAdmissionVerdict::AllowWithWarning);
        assert!(decoded.validate().is_ok());

        let mut extra_field =
            serde_json::to_value(&record).expect("audit record must encode to JSON object");
        extra_field["scope_rex_proof"] = serde_json::json!("smuggled");
        assert!(serde_json::from_value::<ACSAuditRecord>(extra_field).is_err());

        let mut corrupt_request_id =
            serde_json::to_value(&record).expect("audit record must encode to JSON object");
        corrupt_request_id["request_id"] = serde_json::json!(" req ");
        assert!(serde_json::from_value::<ACSAuditRecord>(corrupt_request_id).is_err());

        let mut corrupt_reason =
            serde_json::to_value(&record).expect("audit record must encode to JSON object");
        corrupt_reason["reason"] = serde_json::json!(" ");
        let err = serde_json::from_value::<ACSAuditRecord>(corrupt_reason).unwrap_err();
        let message = err.to_string();

        assert!(message.contains("corrupt_acs_audit_record"), "{message}");
        assert!(message.contains(record.record_id.as_str()), "{message}");
    }

    #[test]
    fn acs_admission_scope_rex_proof_carries_verdict_record_ref_and_signature() {
        let record = audit_record_fixture(ACSAdmissionVerdict::AllowWithWarning);
        let signature = "11".repeat(CAPABILITY_SIGNATURE_BYTES);

        let proof = SCOPERexAdmissionProof::from_record(
            &record,
            CapabilitySignature::new(signature.clone()),
        )
        .expect("valid audit record and signature produce proof");

        assert_eq!(proof.verdict, ACSAdmissionVerdict::AllowWithWarning);
        assert_eq!(proof.operation, ACSOperationKind::MemoryWrite);
        assert_eq!(proof.record_id.0, record.record_id);
        assert_eq!(proof.signature.0, signature);
        assert!(proof.validate().is_ok());

        let json = serde_json::to_string(&proof).expect("proof must serialize");
        let decoded: SCOPERexAdmissionProof =
            serde_json::from_str(&json).expect("proof must deserialize");
        assert!(decoded.validate().is_ok());

        let extra_field = serde_json::json!({
            "verdict": "allow_with_warning",
            "operation": "memory_write",
            "record_id": record.record_id,
            "signature": signature,
            "audit_record": record,
        });
        assert!(serde_json::from_value::<SCOPERexAdmissionProof>(extra_field).is_err());

        let non_allowing = serde_json::json!({
            "verdict": "reject",
            "operation": "memory_write",
            "record_id": "acs:req:1001",
            "signature": "00".repeat(CAPABILITY_SIGNATURE_BYTES),
        });
        assert!(serde_json::from_value::<SCOPERexAdmissionProof>(non_allowing).is_err());

        let err = SCOPERexAdmissionProof::from_record(&record, CapabilitySignature::new(" "))
            .unwrap_err();
        assert_eq!(err.cause(), "missing_capability_signature");
        assert_eq!(err.field(), Some("signature"));

        let mut corrupt_record = record.clone();
        corrupt_record.reason = " ".to_string();
        let err = SCOPERexAdmissionProof::from_record(
            &corrupt_record,
            CapabilitySignature::new(signature.clone()),
        )
        .unwrap_err();
        assert_eq!(err.cause(), "corrupt_acs_audit_record");
        assert_eq!(err.field(), Some("reason"));
        assert_eq!(err.record_id(), Some(corrupt_record.record_id.as_str()));

        let invalid_record_id = "run-event:external-record";
        let err = SCOPERexAdmissionProof::new(
            ACSAdmissionVerdict::Allow,
            ACSOperationKind::MemoryWrite,
            AuditRecordId::new(invalid_record_id),
            CapabilitySignature::new("capability-signature"),
        )
        .unwrap_err();
        assert_eq!(err.cause(), "invalid_audit_record_id");
        assert_eq!(err.field(), Some("record_id"));
        assert_eq!(err.record_id(), Some(invalid_record_id));
    }

    #[test]
    fn acs_admission_audit_record_id_decode_rejects_boundary_spaced_refs() {
        let decoded = serde_json::from_value::<AuditRecordId>(serde_json::json!(" acs:req:1001 "));

        assert!(decoded.is_err());
    }

    #[test]
    fn acs_admission_audit_record_id_decode_errors_preserve_record_ref() {
        let record_id = "run-event:external-record";
        let err =
            serde_json::from_value::<AuditRecordId>(serde_json::json!(record_id)).unwrap_err();
        let message = err.to_string();

        assert!(message.contains("invalid_audit_record_id"), "{message}");
        assert!(message.contains(record_id), "{message}");
    }

    #[test]
    fn acs_admission_capability_signature_decode_rejects_noncanonical_hex() {
        let decoded = serde_json::from_value::<CapabilitySignature>(serde_json::json!(
            "AA".repeat(CAPABILITY_SIGNATURE_BYTES)
        ));

        assert!(decoded.is_err());
    }

    #[test]
    fn acs_admission_scope_rex_proof_requires_allowing_verdict() {
        let record = audit_record_fixture(ACSAdmissionVerdict::Reject);
        let record_id = record.record_id.clone();
        let signing_key = crate::effect::receipt::HmacSha256SigningKey::new([7; 32]);

        let err = SCOPERexAdmissionProof::signed_from_record(&record, &signing_key).unwrap_err();
        assert_eq!(err.cause(), "proof_verdict_blocks_scope_rex");
        assert_eq!(err.field(), Some("verdict"));
        assert_eq!(err.record_id(), Some(record_id.as_str()));

        let counting_key = CountingSigningKey::default();
        let err = SCOPERexAdmissionProof::signed_from_record(&record, &counting_key).unwrap_err();
        assert_eq!(err.cause(), "proof_verdict_blocks_scope_rex");
        assert_eq!(counting_key.sign_count(), 0);

        let err = SCOPERexAdmissionProof::from_record(
            &record,
            CapabilitySignature::new("capability-signature"),
        )
        .unwrap_err();
        assert_eq!(err.cause(), "proof_verdict_blocks_scope_rex");
        assert_eq!(err.field(), Some("verdict"));
        assert_eq!(err.record_id(), Some(record_id.as_str()));

        let err = SCOPERexAdmissionProof::new(
            ACSAdmissionVerdict::Reject,
            ACSOperationKind::MemoryWrite,
            AuditRecordId::new(record_id.clone()),
            CapabilitySignature::new("capability-signature"),
        )
        .unwrap_err();
        assert_eq!(err.cause(), "proof_verdict_blocks_scope_rex");
        assert_eq!(err.field(), Some("verdict"));
        assert_eq!(err.record_id(), Some(record_id.as_str()));
    }

    #[test]
    fn acs_admission_scope_rex_proof_verdict_precedes_malformed_record_ref() {
        let err = SCOPERexAdmissionProof::new(
            ACSAdmissionVerdict::Reject,
            ACSOperationKind::MemoryWrite,
            AuditRecordId::new("run-event:external-record"),
            CapabilitySignature::new("00".repeat(CAPABILITY_SIGNATURE_BYTES)),
        )
        .unwrap_err();

        assert_eq!(err.cause(), "proof_verdict_blocks_scope_rex");
        assert_eq!(err.field(), Some("verdict"));
    }

    #[test]
    fn acs_admission_scope_rex_proof_decode_verdict_precedes_malformed_record_ref() {
        let encoded = serde_json::json!({
            "verdict": "reject",
            "operation": "memory_write",
            "record_id": "run-event:external-record",
            "signature": "00".repeat(CAPABILITY_SIGNATURE_BYTES),
        });

        let err = serde_json::from_value::<SCOPERexAdmissionProof>(encoded).unwrap_err();

        assert!(
            err.to_string().contains("proof_verdict_blocks_scope_rex"),
            "{err}"
        );
    }

    #[test]
    fn acs_admission_scope_rex_proof_decode_verdict_precedes_missing_refs() {
        let encoded = serde_json::json!({
            "verdict": "reject",
            "operation": "memory_write",
        });

        let err = serde_json::from_value::<SCOPERexAdmissionProof>(encoded).unwrap_err();

        assert!(
            err.to_string().contains("proof_verdict_blocks_scope_rex"),
            "{err}"
        );
    }

    #[test]
    fn acs_admission_scope_rex_proof_decode_verdict_precedes_typed_ref_forgery() {
        let encoded = serde_json::json!({
            "verdict": "reject",
            "operation": "memory_write",
            "record_id": 1001,
            "signature": true,
        });

        let err = serde_json::from_value::<SCOPERexAdmissionProof>(encoded).unwrap_err();

        assert!(
            err.to_string().contains("proof_verdict_blocks_scope_rex"),
            "{err}"
        );
    }

    #[test]
    fn acs_admission_scope_rex_proof_decode_errors_preserve_record_ref() {
        let record_id = "acs:req:1001";
        let encoded = serde_json::json!({
            "verdict": "allow",
            "operation": "memory_write",
            "record_id": record_id,
            "signature": "AA".repeat(CAPABILITY_SIGNATURE_BYTES),
        });

        let err = serde_json::from_value::<SCOPERexAdmissionProof>(encoded).unwrap_err();
        let message = err.to_string();

        assert!(
            message.contains("invalid_capability_signature"),
            "{message}"
        );
        assert!(message.contains(record_id), "{message}");
    }

    #[test]
    fn acs_admission_scope_rex_proof_missing_operation_names_malformed_proof_field() {
        let encoded = serde_json::json!({
            "verdict": "allow",
            "record_id": "acs:req:1001",
            "signature": "00".repeat(CAPABILITY_SIGNATURE_BYTES),
        });

        let err = serde_json::from_value::<SCOPERexAdmissionProof>(encoded).unwrap_err();
        let message = err.to_string();

        assert!(
            message.contains("malformed_acs_admission_proof"),
            "{message}"
        );
        assert!(message.contains("operation"), "{message}");
    }

    #[test]
    fn acs_admission_scope_rex_proof_typed_verdict_names_malformed_proof_field() {
        let encoded = serde_json::json!({
            "verdict": true,
            "operation": "memory_write",
            "record_id": "acs:req:1001",
            "signature": "00".repeat(CAPABILITY_SIGNATURE_BYTES),
        });

        let err = serde_json::from_value::<SCOPERexAdmissionProof>(encoded).unwrap_err();
        let message = err.to_string();

        assert!(
            message.contains("malformed_acs_admission_proof"),
            "{message}"
        );
        assert!(message.contains("verdict"), "{message}");
    }

    #[test]
    fn acs_admission_scope_rex_proof_unknown_operation_names_malformed_proof_field() {
        let encoded = serde_json::json!({
            "verdict": "allow",
            "operation": "quantum_commit",
            "record_id": "acs:req:1001",
            "signature": "00".repeat(CAPABILITY_SIGNATURE_BYTES),
        });

        let err = serde_json::from_value::<SCOPERexAdmissionProof>(encoded).unwrap_err();
        let message = err.to_string();

        assert!(
            message.contains("malformed_acs_admission_proof"),
            "{message}"
        );
        assert!(message.contains("operation"), "{message}");
    }

    #[test]
    fn acs_admission_scope_rex_proof_rejects_reserved_malformed_request_ref() {
        let err = SCOPERexAdmissionProof::new(
            ACSAdmissionVerdict::Allow,
            ACSOperationKind::MemoryWrite,
            AuditRecordId::new(format!("acs:{}:1001", audit_request_id(" "))),
            CapabilitySignature::new("00".repeat(CAPABILITY_SIGNATURE_BYTES)),
        )
        .unwrap_err();

        assert_eq!(err.cause(), "invalid_audit_record_id");
        assert_eq!(err.field(), Some("record_id"));
    }

    #[test]
    fn acs_admission_scope_rex_proof_rejects_reserved_malformed_policy_ref() {
        let err = SCOPERexAdmissionProof::new(
            ACSAdmissionVerdict::Allow,
            ACSOperationKind::MemoryWrite,
            AuditRecordId::new(format!("acs:{}:1001", audit_policy_id(" "))),
            CapabilitySignature::new("00".repeat(CAPABILITY_SIGNATURE_BYTES)),
        )
        .unwrap_err();

        assert_eq!(err.cause(), "invalid_audit_record_id");
        assert_eq!(err.field(), Some("record_id"));
    }

    #[test]
    fn acs_admission_scope_rex_proof_rejects_malformed_signature_text() {
        let record = audit_record_fixture(ACSAdmissionVerdict::Allow);

        let err = SCOPERexAdmissionProof::from_record(
            &record,
            CapabilitySignature::new("capability-signature"),
        )
        .unwrap_err();
        assert_eq!(err.cause(), "invalid_capability_signature");
        assert_eq!(err.field(), Some("signature"));
        assert_eq!(err.record_id(), Some(record.record_id.as_str()));

        let err =
            SCOPERexAdmissionProof::from_record(&record, CapabilitySignature::new("00".repeat(31)))
                .unwrap_err();
        assert_eq!(err.cause(), "invalid_capability_signature");
        assert_eq!(err.field(), Some("signature"));
    }

    #[test]
    fn acs_admission_scope_rex_proof_rejects_noncanonical_signature_text() {
        let record = audit_record_fixture(ACSAdmissionVerdict::Allow);

        let err = SCOPERexAdmissionProof::from_record(
            &record,
            CapabilitySignature::new("AA".repeat(CAPABILITY_SIGNATURE_BYTES)),
        )
        .unwrap_err();
        assert_eq!(err.cause(), "invalid_capability_signature");
        assert_eq!(err.field(), Some("signature"));

        let err = SCOPERexAdmissionProof::from_record(
            &record,
            CapabilitySignature::new(format!(" {} ", "00".repeat(CAPABILITY_SIGNATURE_BYTES))),
        )
        .unwrap_err();
        assert_eq!(err.cause(), "invalid_capability_signature");
        assert_eq!(err.field(), Some("signature"));
    }

    #[test]
    fn acs_admission_scope_rex_proof_signature_binds_verdict_and_record_id() {
        let record = audit_record_fixture(ACSAdmissionVerdict::AllowWithWarning);
        let signing_key = crate::effect::receipt::HmacSha256SigningKey::new([7; 32]);

        let proof = SCOPERexAdmissionProof::signed_from_record(&record, &signing_key)
            .expect("valid audit record signs");

        assert!(proof.verify_signature(&signing_key));
        assert_eq!(proof.signature.0.len(), 64);
        assert!(proof
            .signature
            .0
            .bytes()
            .all(|byte| matches!(byte, b'0'..=b'9' | b'a'..=b'f')));

        let mut tampered_verdict = proof.clone();
        tampered_verdict.verdict = ACSAdmissionVerdict::Reject;
        assert!(!tampered_verdict.verify_signature(&signing_key));

        let mut tampered_record = proof.clone();
        tampered_record.record_id = AuditRecordId::new("acs:req:1002");
        assert!(!tampered_record.verify_signature(&signing_key));
    }

    #[test]
    fn acs_admission_scope_rex_proof_signature_binds_operation() {
        let record = audit_record_fixture(ACSAdmissionVerdict::Allow);
        let signing_key = crate::effect::receipt::HmacSha256SigningKey::new([7; 32]);
        let proof = SCOPERexAdmissionProof::signed_from_record(&record, &signing_key)
            .expect("valid audit record signs");

        assert_eq!(proof.operation, ACSOperationKind::MemoryWrite);

        let mut tampered_proof = proof.clone();
        tampered_proof.operation = ACSOperationKind::ToolAction;
        assert!(!tampered_proof.verify_signature(&signing_key));

        let mut tampered_record = record.clone();
        tampered_record.operation = ACSOperationKind::ToolAction;
        let err = proof
            .verify_against_record(&tampered_record, &signing_key)
            .unwrap_err();
        assert_eq!(err.cause(), "proof_operation_mismatch");
        assert_eq!(err.field(), Some("operation"));
    }

    #[test]
    fn acs_admission_scope_rex_proof_exposes_product_lane() {
        let mut record = audit_record_fixture(ACSAdmissionVerdict::Allow);
        record.operation = ACSOperationKind::ToolAction;
        let signing_key = crate::effect::receipt::HmacSha256SigningKey::new([7; 32]);

        let proof = SCOPERexAdmissionProof::signed_from_record(&record, &signing_key)
            .expect("valid audit record signs");

        assert_eq!(proof.lane(), ACSLane::L1);
        assert_eq!(proof.product_lane_code(), "agent_tool_loops");
    }

    #[test]
    fn acs_admission_scope_rex_proof_signature_is_domain_separated() {
        let record = audit_record_fixture(ACSAdmissionVerdict::Allow);
        let signing_key = crate::effect::receipt::HmacSha256SigningKey::new([7; 32]);
        let mut legacy_payload = Vec::with_capacity(64 + record.record_id.len());
        push_proof_field(
            &mut legacy_payload,
            b"verdict",
            record.verdict.code().as_bytes(),
        );
        push_proof_field(
            &mut legacy_payload,
            b"record_id",
            record.record_id.as_bytes(),
        );
        let legacy_signature =
            CapabilitySignature::new(hex_encode_signature(&signing_key.sign(&legacy_payload)));
        let proof =
            SCOPERexAdmissionProof::from_record(&record, legacy_signature).expect("proof builds");

        assert!(!proof.verify_signature(&signing_key));
    }

    #[test]
    fn acs_admission_scope_rex_proof_rejects_mismatched_audit_record() {
        let record = audit_record_fixture(ACSAdmissionVerdict::AllowWithWarning);
        let signing_key = crate::effect::receipt::HmacSha256SigningKey::new([7; 32]);
        let proof = SCOPERexAdmissionProof::signed_from_record(&record, &signing_key)
            .expect("valid audit record signs");

        assert!(proof.verify_against_record(&record, &signing_key).is_ok());

        let mut wrong_record_id = record.clone();
        wrong_record_id.record_id = "acs:req:1002".to_string();
        wrong_record_id.emitted_at_ms = 1_002;
        let err = proof
            .verify_against_record(&wrong_record_id, &signing_key)
            .unwrap_err();
        assert_eq!(err.cause(), "proof_record_id_mismatch");
        assert_eq!(err.field(), Some("record_id"));
        assert_eq!(err.record_id(), Some(proof.record_id.0.as_str()));

        let mut wrong_verdict = record.clone();
        wrong_verdict.verdict = ACSAdmissionVerdict::Reject;
        wrong_verdict.reason = "reject".to_string();
        let err = proof
            .verify_against_record(&wrong_verdict, &signing_key)
            .unwrap_err();
        assert_eq!(err.cause(), "proof_verdict_mismatch");
        assert_eq!(err.field(), Some("verdict"));
        assert_eq!(err.record_id(), Some(proof.record_id.0.as_str()));

        let mut wrong_operation = record.clone();
        wrong_operation.operation = ACSOperationKind::ToolAction;
        let err = proof
            .verify_against_record(&wrong_operation, &signing_key)
            .unwrap_err();
        assert_eq!(err.cause(), "proof_operation_mismatch");
        assert_eq!(err.field(), Some("operation"));
        assert_eq!(err.record_id(), Some(proof.record_id.0.as_str()));

        let mut wrong_signature = proof.clone();
        wrong_signature.signature = CapabilitySignature::new("00".repeat(32));
        let err = wrong_signature
            .verify_against_record(&record, &signing_key)
            .unwrap_err();
        assert_eq!(err.cause(), "invalid_capability_signature");
        assert_eq!(err.field(), Some("signature"));
    }

    #[test]
    fn acs_admission_scope_rex_proof_verifies_from_run_event_log() {
        let run_event_log = crate::oplog::OpLog::new("acs-admission-proof-log-test");
        let sink = ACSRunEventLogSink::new(&run_event_log);
        let signing_key = crate::effect::receipt::HmacSha256SigningKey::new([7; 32]);
        let input = ACSAdmissionInput {
            request_id: "req-scope-rex-proof-log".to_string(),
            payload: tool_action_payload(),
            submitted_at_ms: 1_001,
            risk: ACSRiskVector::neutral(),
            granted_capabilities: Vec::new(),
        };
        let policy = ACSPolicy::strict("policy-scope-rex-proof-log", 1_000);
        let decision =
            admit_and_record(&input, &policy, 1_001, &sink).expect("RunEventLog sink records");
        let proof =
            SCOPERexAdmissionProof::signed_from_record(&decision.audit_record, &signing_key)
                .expect("audit record signs");

        let resolved = proof
            .verify_against_run_event_log(&run_event_log, &signing_key)
            .expect("proof verifies against RunEventLog");
        assert_eq!(resolved, decision.audit_record);

        let mut wrong_signature = proof.clone();
        wrong_signature.signature = CapabilitySignature::new("00".repeat(32));
        let err = wrong_signature
            .verify_against_run_event_log(&run_event_log, &signing_key)
            .unwrap_err();
        assert_eq!(err.cause(), "invalid_capability_signature");
        assert_eq!(err.field(), Some("signature"));
        assert_eq!(err.record_id(), Some(proof.record_id.0.as_str()));

        let missing_record_id = "acs:req:404";
        let missing_record = SCOPERexAdmissionProof::new(
            ACSAdmissionVerdict::Allow,
            ACSOperationKind::ToolAction,
            AuditRecordId::new(missing_record_id),
            CapabilitySignature::new("00".repeat(32)),
        )
        .expect("syntactically valid proof");
        let err = missing_record
            .verify_against_run_event_log(&run_event_log, &signing_key)
            .unwrap_err();
        assert_eq!(err.cause(), "acs_audit_record_not_found");
        assert_eq!(err.field(), Some("record_id"));
        assert_eq!(err.record_id(), Some(missing_record_id));

        let record_id = decision.audit_record.record_id.clone();
        let duplicate_value =
            serde_json::to_value(decision.audit_record).expect("audit record encodes");
        run_event_log.append(crate::oplog::OpPayload::PropSet {
            node_id: record_id.clone(),
            key: ACS_AUDIT_RUN_EVENT_KEY.to_string(),
            value: duplicate_value,
        });
        let err = proof
            .verify_against_run_event_log(&run_event_log, &signing_key)
            .unwrap_err();
        assert_eq!(err.cause(), "duplicate_acs_audit_record");
        assert_eq!(err.field(), Some("record_id"));
        assert_eq!(err.record_id(), Some(record_id.as_str()));
    }

    #[test]
    fn acs_admission_scope_rex_proof_invalid_log_precedes_invalid_proof() {
        let temp_dir = tempfile::tempdir().expect("temporary ACS OpLog directory");
        let db_path = temp_dir.path().join("acs-proof-log-chain.sqlite");
        let signing_key = crate::effect::receipt::HmacSha256SigningKey::new([7; 32]);
        let mut proof = {
            let run_event_log =
                crate::oplog::OpLog::open_persistent("acs-proof-chain-test", &db_path)
                    .expect("persistent RunEventLog opens");
            let sink = ACSRunEventLogSink::new(&run_event_log);
            let input = ACSAdmissionInput {
                request_id: "req-proof-chain".to_string(),
                payload: tool_action_payload(),
                submitted_at_ms: 1_001,
                risk: ACSRiskVector::neutral(),
                granted_capabilities: Vec::new(),
            };
            let policy = ACSPolicy::strict("policy-proof-chain", 1_000);
            let decision =
                admit_and_record(&input, &policy, 1_001, &sink).expect("RunEventLog sink records");
            SCOPERexAdmissionProof::signed_from_record(&decision.audit_record, &signing_key)
                .expect("audit record signs")
        };

        let conn = rusqlite::Connection::open(&db_path).expect("tamper connection opens");
        conn.execute(
            "UPDATE epistemos_oplog SET prev_hash = ? WHERE seq = 0",
            rusqlite::params![vec![7u8; 32]],
        )
        .expect("tamper write succeeds");
        drop(conn);

        let reopened = crate::oplog::OpLog::open_persistent("acs-proof-chain-test", &db_path)
            .expect("tampered RunEventLog reopens");
        assert!(!reopened.verify_chain(None).valid);
        proof.signature = CapabilitySignature::new(" ");

        let err = proof
            .verify_against_run_event_log(&reopened, &signing_key)
            .unwrap_err();

        assert_eq!(err.cause(), "invalid_run_event_log_chain");
        assert_eq!(err.field(), Some("run_event_log"));
        assert_eq!(err.record_id(), Some(proof.record_id.0.as_str()));
    }

    #[test]
    fn acs_admission_scope_rex_proof_reports_audit_log_gap() {
        let temp_dir = tempfile::tempdir().expect("temporary ACS OpLog directory");
        let db_path = temp_dir.path().join("acs-proof-log-gap.sqlite");
        let signing_key = crate::effect::receipt::HmacSha256SigningKey::new([7; 32]);
        let proof = {
            let run_event_log =
                crate::oplog::OpLog::open_persistent("acs-proof-gap-test", &db_path)
                    .expect("persistent RunEventLog opens");
            let sink = ACSRunEventLogSink::new(&run_event_log);
            let first_input = ACSAdmissionInput {
                request_id: "req-proof-gap-first".to_string(),
                payload: tool_action_payload(),
                submitted_at_ms: 1_000,
                risk: ACSRiskVector::neutral(),
                granted_capabilities: Vec::new(),
            };
            let second_input = ACSAdmissionInput {
                request_id: "req-proof-gap".to_string(),
                payload: tool_action_payload(),
                submitted_at_ms: 1_001,
                risk: ACSRiskVector::neutral(),
                granted_capabilities: Vec::new(),
            };
            let policy = ACSPolicy::strict("policy-proof-gap", 1_000);
            admit_and_record(&first_input, &policy, 1_000, &sink)
                .expect("first RunEventLog sink record writes");
            let second_decision = admit_and_record(&second_input, &policy, 1_001, &sink)
                .expect("second RunEventLog sink record writes");
            SCOPERexAdmissionProof::signed_from_record(&second_decision.audit_record, &signing_key)
                .expect("audit record signs")
        };

        let conn = rusqlite::Connection::open(&db_path).expect("tamper connection opens");
        conn.execute("DELETE FROM epistemos_oplog WHERE seq = 0", [])
            .expect("tamper delete succeeds");
        drop(conn);

        let reopened = crate::oplog::OpLog::open_persistent("acs-proof-gap-test", &db_path)
            .expect("gapped RunEventLog reopens");
        let report = reopened.verify_chain(None);
        assert!(!report.valid);
        assert_eq!(report.failure_reason.as_deref(), Some("seq_gap"));

        let err = proof
            .verify_against_run_event_log(&reopened, &signing_key)
            .unwrap_err();

        assert_eq!(err.cause(), "acs_audit_log_gap");
        assert_eq!(err.field(), Some("run_event_log"));
        assert_eq!(err.record_id(), Some(proof.record_id.0.as_str()));
    }

    #[test]
    fn acs_admission_in_memory_audit_sink_records_decisions() {
        let sink = InMemoryACSAuditSink::default();
        let input = ACSAdmissionInput {
            request_id: "req-sink".to_string(),
            payload: tool_action_payload(),
            submitted_at_ms: 1_001,
            risk: ACSRiskVector::neutral(),
            granted_capabilities: Vec::new(),
        };
        let policy = ACSPolicy::strict("policy-sink", 1_000);

        let decision =
            admit_and_record(&input, &policy, 1_001, &sink).expect("in-memory sink records");

        assert_eq!(decision.verdict, ACSAdmissionVerdict::Allow);
        assert_eq!(sink.records().unwrap(), vec![decision.audit_record]);
    }

    #[test]
    fn acs_admission_in_memory_audit_sink_rejects_duplicate_record_ids() {
        let sink = InMemoryACSAuditSink::default();
        let record = audit_record_fixture(ACSAdmissionVerdict::Allow);
        let record_id = record.record_id.clone();

        sink.record(record.clone()).expect("first record is stored");
        let err = sink.record(record).unwrap_err();

        assert_eq!(err.cause(), "duplicate_acs_audit_record");
        assert_eq!(err.field(), Some("record_id"));
        assert_eq!(err.record_id(), Some(record_id.as_str()));
        assert_eq!(sink.records().unwrap().len(), 1);
    }

    #[test]
    fn acs_admission_in_memory_audit_sink_rejects_non_monotonic_emitted_at_ms() {
        let sink = InMemoryACSAuditSink::default();
        let first = ACSAuditRecord {
            record_id: "acs:req-first:2000".to_string(),
            request_id: "req-first".to_string(),
            policy_id: "policy".to_string(),
            policy_version: 1,
            operation: ACSOperationKind::MemoryWrite,
            verdict: ACSAdmissionVerdict::Allow,
            reason: ACSAdmissionVerdict::Allow.code().to_string(),
            risk_max: 0.0,
            emitted_at_ms: 2_000,
        };
        sink.record(first).expect("first record stored");

        let regressing = ACSAuditRecord {
            record_id: "acs:req-second:1500".to_string(),
            request_id: "req-second".to_string(),
            policy_id: "policy".to_string(),
            policy_version: 1,
            operation: ACSOperationKind::MemoryWrite,
            verdict: ACSAdmissionVerdict::Allow,
            reason: ACSAdmissionVerdict::Allow.code().to_string(),
            risk_max: 0.0,
            emitted_at_ms: 1_500,
        };
        let err = sink
            .record(regressing.clone())
            .expect_err("regressing emitted_at_ms must be rejected");

        assert_eq!(err.cause(), "non_monotonic_acs_audit_log");
        assert_eq!(err.field(), Some("emitted_at_ms"));
        assert_eq!(err.record_id(), Some(regressing.record_id.as_str()));
        assert_eq!(sink.records().unwrap().len(), 1);
    }

    #[test]
    fn acs_admission_in_memory_audit_sink_rejects_same_request_verdict_regression() {
        let sink = InMemoryACSAuditSink::default();
        let first = ACSAuditRecord {
            record_id: "acs:req-race:2000".to_string(),
            request_id: "req-race".to_string(),
            policy_id: "policy".to_string(),
            policy_version: 1,
            operation: ACSOperationKind::MemoryWrite,
            verdict: ACSAdmissionVerdict::Reject,
            reason: ACSAdmissionVerdict::Reject.code().to_string(),
            risk_max: 0.95,
            emitted_at_ms: 2_000,
        };
        sink.record(first).expect("first record stored");

        let regressing = ACSAuditRecord {
            record_id: "acs:req-race:2001".to_string(),
            request_id: "req-race".to_string(),
            policy_id: "policy".to_string(),
            policy_version: 1,
            operation: ACSOperationKind::MemoryWrite,
            verdict: ACSAdmissionVerdict::Allow,
            reason: ACSAdmissionVerdict::Allow.code().to_string(),
            risk_max: 0.0,
            emitted_at_ms: 2_001,
        };
        let err = sink
            .record(regressing.clone())
            .expect_err("same-request verdict regression must be rejected");

        assert_eq!(err.cause(), "non_monotonic_acs_verdict");
        assert_eq!(err.field(), Some("verdict"));
        assert_eq!(err.record_id(), Some(regressing.record_id.as_str()));
        assert_eq!(sink.records().unwrap().len(), 1);
    }

    #[test]
    fn acs_admission_in_memory_audit_sink_names_verdict_regression_before_race_timestamp() {
        let sink = InMemoryACSAuditSink::default();
        let first = ACSAuditRecord {
            record_id: "acs:req-race-order:2000".to_string(),
            request_id: "req-race-order".to_string(),
            policy_id: "policy".to_string(),
            policy_version: 1,
            operation: ACSOperationKind::MemoryWrite,
            verdict: ACSAdmissionVerdict::Reject,
            reason: ACSAdmissionVerdict::Reject.code().to_string(),
            risk_max: 0.95,
            emitted_at_ms: 2_000,
        };
        sink.record(first).expect("first record stored");

        let regressing = ACSAuditRecord {
            record_id: "acs:req-race-order:1999".to_string(),
            request_id: "req-race-order".to_string(),
            policy_id: "policy".to_string(),
            policy_version: 1,
            operation: ACSOperationKind::MemoryWrite,
            verdict: ACSAdmissionVerdict::Allow,
            reason: ACSAdmissionVerdict::Allow.code().to_string(),
            risk_max: 0.0,
            emitted_at_ms: 1_999,
        };
        let err = sink
            .record(regressing.clone())
            .expect_err("same-request verdict regression must be classified before race timestamp");

        assert_eq!(err.cause(), "non_monotonic_acs_verdict");
        assert_eq!(err.field(), Some("verdict"));
        assert_eq!(err.record_id(), Some(regressing.record_id.as_str()));
        assert_eq!(sink.records().unwrap().len(), 1);
    }

    #[test]
    fn acs_admission_run_event_log_sink_records_decisions() {
        let run_event_log = crate::oplog::OpLog::new("acs-admission-test");
        let sink = ACSRunEventLogSink::new(&run_event_log);
        let input = ACSAdmissionInput {
            request_id: "req-run-event-log-sink".to_string(),
            payload: tool_action_payload(),
            submitted_at_ms: 1_001,
            risk: ACSRiskVector::neutral(),
            granted_capabilities: Vec::new(),
        };
        let policy = ACSPolicy::strict("policy-run-event-log-sink", 1_000);

        let decision =
            admit_and_record(&input, &policy, 1_001, &sink).expect("RunEventLog sink records");

        assert_eq!(decision.verdict, ACSAdmissionVerdict::Allow);
        assert_eq!(run_event_log.len(), 1);
        assert!(run_event_log.verify_chain(None).valid);

        let ops = run_event_log.iter_all();
        match &ops[0].payload {
            crate::oplog::OpPayload::PropSet {
                node_id,
                key,
                value,
            } => {
                assert_eq!(node_id, &decision.audit_record.record_id);
                assert_eq!(key, ACS_AUDIT_RUN_EVENT_KEY);
                let persisted: ACSAuditRecord =
                    serde_json::from_value(value.clone()).expect("audit JSON must decode");
                assert_eq!(persisted, decision.audit_record);
            }
            other => panic!("expected ACS audit PropSet payload, got {other:?}"),
        }
    }

    #[test]
    fn acs_admission_run_event_log_sink_rejects_duplicate_record_ids() {
        let run_event_log = crate::oplog::OpLog::new("acs-admission-sink-duplicate-test");
        let sink = ACSRunEventLogSink::new(&run_event_log);
        let input = ACSAdmissionInput {
            request_id: "req-run-event-log-sink-duplicate".to_string(),
            payload: tool_action_payload(),
            submitted_at_ms: 1_001,
            risk: ACSRiskVector::neutral(),
            granted_capabilities: Vec::new(),
        };
        let policy = ACSPolicy::strict("policy-run-event-log-sink-duplicate", 1_000);
        let decision =
            admit_and_record(&input, &policy, 1_001, &sink).expect("RunEventLog sink records");
        let record_id = decision.audit_record.record_id.clone();

        let err = sink.record(decision.audit_record).unwrap_err();

        assert_eq!(err.cause(), "duplicate_acs_audit_record");
        assert_eq!(err.field(), Some("record_id"));
        assert_eq!(err.record_id(), Some(record_id.as_str()));
        assert_eq!(run_event_log.len(), 1);
    }

    #[test]
    fn acs_admission_run_event_log_sink_rejects_aliased_duplicate_record_ids() {
        let run_event_log = crate::oplog::OpLog::new("acs-admission-sink-aliased-duplicate-test");
        let sink = ACSRunEventLogSink::new(&run_event_log);
        let record = audit_record_fixture(ACSAdmissionVerdict::Allow);
        let record_id = record.record_id.clone();
        let aliased_value = serde_json::to_value(record.clone()).expect("audit record encodes");
        run_event_log.append(crate::oplog::OpPayload::PropSet {
            node_id: "acs:req-shadow:1001".to_string(),
            key: ACS_AUDIT_RUN_EVENT_KEY.to_string(),
            value: aliased_value,
        });

        let err = sink.record(record).unwrap_err();

        assert_eq!(err.cause(), "duplicate_acs_audit_record");
        assert_eq!(err.field(), Some("record_id"));
        assert_eq!(err.record_id(), Some(record_id.as_str()));
        assert_eq!(run_event_log.len(), 1);
    }

    #[test]
    fn acs_admission_run_event_log_sink_records_distinct_malformed_requests_same_tick() {
        let run_event_log = crate::oplog::OpLog::new("acs-admission-sink-malformed-request-test");
        let sink = ACSRunEventLogSink::new(&run_event_log);
        let policy = ACSPolicy::strict("policy-run-event-log-malformed-request", 1_000);
        let first_input = ACSAdmissionInput {
            request_id: " ".to_string(),
            payload: tool_action_payload(),
            submitted_at_ms: 1_001,
            risk: ACSRiskVector::neutral(),
            granted_capabilities: Vec::new(),
        };
        let second_input = ACSAdmissionInput {
            request_id: "\t".to_string(),
            payload: tool_action_payload(),
            submitted_at_ms: 1_001,
            risk: ACSRiskVector::neutral(),
            granted_capabilities: Vec::new(),
        };

        let first = admit_and_record(&first_input, &policy, 1_001, &sink)
            .expect("first malformed request records");
        let second = admit_and_record(&second_input, &policy, 1_001, &sink)
            .expect("second malformed request records");

        assert_ne!(first.audit_record.record_id, second.audit_record.record_id);
        assert!(first.audit_record.validate().is_ok());
        assert!(second.audit_record.validate().is_ok());
        assert_eq!(run_event_log.len(), 2);
    }

    #[test]
    fn acs_admission_run_event_log_sink_records_reserved_malformed_request_without_collision() {
        let run_event_log =
            crate::oplog::OpLog::new("acs-admission-sink-reserved-malformed-request-test");
        let sink = ACSRunEventLogSink::new(&run_event_log);
        let policy = ACSPolicy::strict("policy-run-event-log-reserved-malformed-request", 1_000);
        let first_input = ACSAdmissionInput {
            request_id: " ".to_string(),
            payload: tool_action_payload(),
            submitted_at_ms: 1_001,
            risk: ACSRiskVector::neutral(),
            granted_capabilities: Vec::new(),
        };
        let second_input = ACSAdmissionInput {
            request_id: audit_request_id(" "),
            payload: tool_action_payload(),
            submitted_at_ms: 1_001,
            risk: ACSRiskVector::neutral(),
            granted_capabilities: Vec::new(),
        };

        let first = admit_and_record(&first_input, &policy, 1_001, &sink)
            .expect("first malformed request records");
        let second = admit_and_record(&second_input, &policy, 1_001, &sink)
            .expect("reserved malformed request records");

        assert_ne!(first.audit_record.record_id, second.audit_record.record_id);
        assert!(first.audit_record.validate().is_ok());
        assert!(second.audit_record.validate().is_ok());
        assert_eq!(run_event_log.len(), 2);
    }

    #[test]
    fn acs_admission_run_event_log_sink_requires_valid_chain() {
        let temp_dir = tempfile::tempdir().expect("temporary ACS OpLog directory");
        let db_path = temp_dir.path().join("acs-run-event-sink-chain.sqlite");
        {
            let run_event_log =
                crate::oplog::OpLog::open_persistent("acs-admission-sink-chain-test", &db_path)
                    .expect("persistent RunEventLog opens");
            let sink = ACSRunEventLogSink::new(&run_event_log);
            sink.record(audit_record_fixture(ACSAdmissionVerdict::Allow))
                .expect("initial audit record writes");
            assert!(run_event_log.verify_chain(None).valid);
        }

        let conn = rusqlite::Connection::open(&db_path).expect("tamper connection opens");
        conn.execute(
            "UPDATE epistemos_oplog SET prev_hash = ? WHERE seq = 0",
            rusqlite::params![vec![7u8; 32]],
        )
        .expect("tamper write succeeds");
        drop(conn);

        let reopened =
            crate::oplog::OpLog::open_persistent("acs-admission-sink-chain-test", &db_path)
                .expect("tampered RunEventLog reopens");
        assert!(!reopened.verify_chain(None).valid);
        let sink = ACSRunEventLogSink::new(&reopened);
        let mut record = audit_record_fixture(ACSAdmissionVerdict::AllowWithWarning);
        record.record_id = "acs:req:1002".to_string();
        record.emitted_at_ms = 1_002;
        record.policy_id = "policy forged".to_string();
        let record_id = record.record_id.clone();

        let err = sink.record(record).unwrap_err();

        assert_eq!(err.cause(), "invalid_run_event_log_chain");
        assert_eq!(err.field(), Some("run_event_log"));
        assert_eq!(err.record_id(), Some(record_id.as_str()));
    }

    #[test]
    fn acs_admission_run_event_log_sink_rejects_sequence_gaps() {
        let temp_dir = tempfile::tempdir().expect("temporary ACS OpLog directory");
        let db_path = temp_dir.path().join("acs-run-event-sink-gap.sqlite");
        let second_record_id = {
            let run_event_log =
                crate::oplog::OpLog::open_persistent("acs-admission-sink-gap-test", &db_path)
                    .expect("persistent RunEventLog opens");
            let sink = ACSRunEventLogSink::new(&run_event_log);
            sink.record(audit_record_fixture(ACSAdmissionVerdict::Allow))
                .expect("first audit record writes");
            let mut second = audit_record_fixture(ACSAdmissionVerdict::AllowWithWarning);
            second.record_id = "acs:req-second:1002".to_string();
            second.request_id = "req-second".to_string();
            second.emitted_at_ms = 1_002;
            sink.record(second.clone())
                .expect("second audit record writes");
            second.record_id
        };

        let conn = rusqlite::Connection::open(&db_path).expect("tamper connection opens");
        conn.execute("DELETE FROM epistemos_oplog WHERE seq = 0", [])
            .expect("tamper delete succeeds");
        drop(conn);

        let reopened =
            crate::oplog::OpLog::open_persistent("acs-admission-sink-gap-test", &db_path)
                .expect("gapped RunEventLog reopens");
        let report = reopened.verify_chain(None);
        assert!(!report.valid);
        assert_eq!(report.failure_reason.as_deref(), Some("seq_gap"));

        let sink = ACSRunEventLogSink::new(&reopened);
        let mut next = audit_record_fixture(ACSAdmissionVerdict::Allow);
        next.record_id = "acs:req-next:1003".to_string();
        next.request_id = "req-next".to_string();
        next.emitted_at_ms = 1_003;
        let next_record_id = next.record_id.clone();

        let err = sink.record(next).unwrap_err();

        assert_eq!(err.cause(), "acs_audit_log_gap");
        assert_eq!(err.field(), Some("run_event_log"));
        assert_eq!(err.record_id(), Some(next_record_id.as_str()));

        let lookup_err =
            resolve_acs_audit_record(&reopened, &AuditRecordId::new(second_record_id.clone()))
                .unwrap_err();
        assert_eq!(lookup_err.cause(), "acs_audit_log_gap");
        assert_eq!(lookup_err.field(), Some("run_event_log"));
        assert_eq!(lookup_err.record_id(), Some(second_record_id.as_str()));
    }

    #[test]
    fn acs_admission_run_event_log_resolves_proof_record_refs() {
        let run_event_log = crate::oplog::OpLog::new("acs-admission-resolve-test");
        let sink = ACSRunEventLogSink::new(&run_event_log);
        let signing_key = crate::effect::receipt::HmacSha256SigningKey::new([7; 32]);
        let input = ACSAdmissionInput {
            request_id: "req-run-event-log-resolve".to_string(),
            payload: tool_action_payload(),
            submitted_at_ms: 1_001,
            risk: ACSRiskVector::neutral(),
            granted_capabilities: Vec::new(),
        };
        let policy = ACSPolicy::strict("policy-run-event-log-resolve", 1_000);
        let decision =
            admit_and_record(&input, &policy, 1_001, &sink).expect("RunEventLog sink records");
        let proof =
            SCOPERexAdmissionProof::signed_from_record(&decision.audit_record, &signing_key)
                .expect("audit record signs");

        let resolved = resolve_acs_audit_record(&run_event_log, &proof.record_id)
            .expect("record id resolves from RunEventLog");

        assert_eq!(resolved, decision.audit_record);
        assert!(proof.verify_against_record(&resolved, &signing_key).is_ok());

        let missing_record_id = "acs:req:404";
        let err = resolve_acs_audit_record(&run_event_log, &AuditRecordId::new(missing_record_id))
            .unwrap_err();
        assert_eq!(err.cause(), "acs_audit_record_not_found");
        assert_eq!(err.field(), Some("record_id"));
        assert_eq!(err.record_id(), Some(missing_record_id));

        let invalid_record_id = "run-event:external-record";
        let err = resolve_acs_audit_record(&run_event_log, &AuditRecordId::new(invalid_record_id))
            .unwrap_err();
        assert_eq!(err.cause(), "invalid_audit_record_id");
        assert_eq!(err.field(), Some("record_id"));
        assert_eq!(err.record_id(), Some(invalid_record_id));
    }

    #[test]
    fn acs_admission_run_event_log_rejects_duplicate_record_refs() {
        let run_event_log = crate::oplog::OpLog::new("acs-admission-duplicate-ref-test");
        let sink = ACSRunEventLogSink::new(&run_event_log);
        let input = ACSAdmissionInput {
            request_id: "req-run-event-log-duplicate".to_string(),
            payload: tool_action_payload(),
            submitted_at_ms: 1_001,
            risk: ACSRiskVector::neutral(),
            granted_capabilities: Vec::new(),
        };
        let policy = ACSPolicy::strict("policy-run-event-log-duplicate", 1_000);
        let decision =
            admit_and_record(&input, &policy, 1_001, &sink).expect("RunEventLog sink records");
        let duplicate_value =
            serde_json::to_value(decision.audit_record.clone()).expect("audit record encodes");
        run_event_log.append(crate::oplog::OpPayload::PropSet {
            node_id: decision.audit_record.record_id.clone(),
            key: ACS_AUDIT_RUN_EVENT_KEY.to_string(),
            value: duplicate_value,
        });
        let record_id = decision.audit_record.record_id.clone();

        let err = resolve_acs_audit_record(&run_event_log, &AuditRecordId::new(record_id.clone()))
            .unwrap_err();

        assert_eq!(err.cause(), "duplicate_acs_audit_record");
        assert_eq!(err.field(), Some("record_id"));
        assert_eq!(err.record_id(), Some(record_id.as_str()));
    }

    #[test]
    fn acs_admission_run_event_log_rejects_aliased_duplicate_record_refs() {
        let run_event_log = crate::oplog::OpLog::new("acs-admission-aliased-duplicate-ref-test");
        let sink = ACSRunEventLogSink::new(&run_event_log);
        let input = ACSAdmissionInput {
            request_id: "req-run-event-log-aliased-duplicate".to_string(),
            payload: tool_action_payload(),
            submitted_at_ms: 1_001,
            risk: ACSRiskVector::neutral(),
            granted_capabilities: Vec::new(),
        };
        let policy = ACSPolicy::strict("policy-run-event-log-aliased-duplicate", 1_000);
        let decision =
            admit_and_record(&input, &policy, 1_001, &sink).expect("RunEventLog sink records");
        let duplicate_value =
            serde_json::to_value(decision.audit_record.clone()).expect("audit record encodes");
        run_event_log.append(crate::oplog::OpPayload::PropSet {
            node_id: "acs:req-run-event-log-aliased-duplicate-shadow:1001".to_string(),
            key: ACS_AUDIT_RUN_EVENT_KEY.to_string(),
            value: duplicate_value,
        });
        let record_id = decision.audit_record.record_id.clone();

        let err = resolve_acs_audit_record(&run_event_log, &AuditRecordId::new(record_id.clone()))
            .unwrap_err();

        assert_eq!(err.cause(), "duplicate_acs_audit_record");
        assert_eq!(err.field(), Some("record_id"));
        assert_eq!(err.record_id(), Some(record_id.as_str()));
    }

    #[test]
    fn acs_admission_run_event_log_rejects_alias_only_record_refs() {
        let run_event_log = crate::oplog::OpLog::new("acs-admission-alias-only-ref-test");
        let record = audit_record_fixture(ACSAdmissionVerdict::Allow);
        let record_id = record.record_id.clone();
        let aliased_value = serde_json::to_value(record).expect("audit record encodes");
        run_event_log.append(crate::oplog::OpPayload::PropSet {
            node_id: "acs:req-shadow:1001".to_string(),
            key: ACS_AUDIT_RUN_EVENT_KEY.to_string(),
            value: aliased_value,
        });

        let err = resolve_acs_audit_record(&run_event_log, &AuditRecordId::new(record_id.clone()))
            .unwrap_err();

        assert_eq!(err.cause(), "duplicate_acs_audit_record");
        assert_eq!(err.field(), Some("record_id"));
        assert_eq!(err.record_id(), Some(record_id.as_str()));
    }

    #[test]
    fn acs_admission_run_event_log_rejects_unaudited_record_fields_as_corrupt() {
        let run_event_log = crate::oplog::OpLog::new("acs-admission-extra-field-test");
        let sink = ACSRunEventLogSink::new(&run_event_log);
        let input = ACSAdmissionInput {
            request_id: "req-run-event-log-extra".to_string(),
            payload: tool_action_payload(),
            submitted_at_ms: 1_001,
            risk: ACSRiskVector::neutral(),
            granted_capabilities: Vec::new(),
        };
        let policy = ACSPolicy::strict("policy-run-event-log-extra", 1_000);
        let decision =
            admit_and_record(&input, &policy, 1_001, &sink).expect("RunEventLog sink records");
        let mut unaudited_value =
            serde_json::to_value(decision.audit_record.clone()).expect("audit record encodes");
        unaudited_value["shadow_reason"] = serde_json::json!("allow");
        run_event_log.append(crate::oplog::OpPayload::PropSet {
            node_id: decision.audit_record.record_id.clone(),
            key: ACS_AUDIT_RUN_EVENT_KEY.to_string(),
            value: unaudited_value,
        });
        let record_id = decision.audit_record.record_id.clone();

        let err = resolve_acs_audit_record(&run_event_log, &AuditRecordId::new(record_id.clone()))
            .unwrap_err();

        assert_eq!(err.cause(), "corrupt_acs_audit_record");
        assert_eq!(err.field(), Some("record"));
        assert_eq!(err.record_id(), Some(record_id.as_str()));
    }

    #[test]
    fn acs_admission_run_event_log_rejects_malformed_record_values_as_decode_failures() {
        let run_event_log = crate::oplog::OpLog::new("acs-admission-malformed-record-test");
        let record_id = AuditRecordId::new("acs:req-run-event-log-malformed:1001");
        run_event_log.append(crate::oplog::OpPayload::PropSet {
            node_id: record_id.0.clone(),
            key: ACS_AUDIT_RUN_EVENT_KEY.to_string(),
            value: serde_json::json!("not-an-audit-record"),
        });

        let err = resolve_acs_audit_record(&run_event_log, &record_id).unwrap_err();

        assert_eq!(err.cause(), "acs_audit_record_decode_failed");
        assert_eq!(err.field(), Some("record"));
        assert_eq!(err.record_id(), Some(record_id.0.as_str()));
    }

    #[test]
    fn acs_admission_run_event_log_rejects_malformed_duplicate_record_refs_as_duplicates() {
        let run_event_log = crate::oplog::OpLog::new("acs-admission-malformed-duplicate-test");
        let sink = ACSRunEventLogSink::new(&run_event_log);
        let input = ACSAdmissionInput {
            request_id: "req-run-event-log-malformed-duplicate".to_string(),
            payload: tool_action_payload(),
            submitted_at_ms: 1_001,
            risk: ACSRiskVector::neutral(),
            granted_capabilities: Vec::new(),
        };
        let policy = ACSPolicy::strict("policy-run-event-log-malformed-duplicate", 1_000);
        let decision =
            admit_and_record(&input, &policy, 1_001, &sink).expect("RunEventLog sink records");
        run_event_log.append(crate::oplog::OpPayload::PropSet {
            node_id: decision.audit_record.record_id.clone(),
            key: ACS_AUDIT_RUN_EVENT_KEY.to_string(),
            value: serde_json::json!("not-an-audit-record"),
        });
        let record_id = decision.audit_record.record_id.clone();

        let err = resolve_acs_audit_record(&run_event_log, &AuditRecordId::new(record_id.clone()))
            .unwrap_err();

        assert_eq!(err.cause(), "duplicate_acs_audit_record");
        assert_eq!(err.field(), Some("record_id"));
        assert_eq!(err.record_id(), Some(record_id.as_str()));
    }

    #[test]
    fn acs_admission_run_event_log_resolver_requires_valid_chain() {
        let temp_dir = tempfile::tempdir().expect("temporary ACS OpLog directory");
        let db_path = temp_dir.path().join("acs-run-event-chain.sqlite");
        {
            let run_event_log =
                crate::oplog::OpLog::open_persistent("acs-admission-chain-test", &db_path)
                    .expect("persistent RunEventLog opens");
            let sink = ACSRunEventLogSink::new(&run_event_log);
            let input = ACSAdmissionInput {
                request_id: "req-run-event-log-chain".to_string(),
                payload: tool_action_payload(),
                submitted_at_ms: 1_001,
                risk: ACSRiskVector::neutral(),
                granted_capabilities: Vec::new(),
            };
            let policy = ACSPolicy::strict("policy-run-event-log-chain", 1_000);
            let decision =
                admit_and_record(&input, &policy, 1_001, &sink).expect("RunEventLog sink records");
            assert!(run_event_log.verify_chain(None).valid);
            assert!(decision.audit_record.validate().is_ok());
        }

        let conn = rusqlite::Connection::open(&db_path).expect("tamper connection opens");
        conn.execute(
            "UPDATE epistemos_oplog SET prev_hash = ? WHERE seq = 0",
            rusqlite::params![vec![7u8; 32]],
        )
        .expect("tamper write succeeds");
        drop(conn);

        let reopened = crate::oplog::OpLog::open_persistent("acs-admission-chain-test", &db_path)
            .expect("tampered RunEventLog reopens");
        assert!(!reopened.verify_chain(None).valid);

        let record_id = AuditRecordId::new("run-event:external-record");
        let err = resolve_acs_audit_record(&reopened, &record_id).unwrap_err();

        assert_eq!(err.cause(), "invalid_run_event_log_chain");
        assert_eq!(err.field(), Some("run_event_log"));
        assert_eq!(err.record_id(), Some(record_id.0.as_str()));
    }

    #[test]
    fn acs_admission_in_memory_audit_sink_rejects_corrupt_records() {
        let sink = InMemoryACSAuditSink::default();
        let mut record = audit_record_fixture(ACSAdmissionVerdict::Allow);
        record.record_id = " ".to_string();
        let record_id = record.record_id.clone();

        let err = sink.record(record).unwrap_err();

        assert_eq!(err.cause(), "corrupt_acs_audit_record");
        assert_eq!(err.field(), Some("record_id"));
        assert_eq!(err.record_id(), Some(record_id.as_str()));
        assert!(sink.records().unwrap().is_empty());
    }

    #[test]
    fn acs_admission_verdict_monotonicity_property() {
        let thresholds = ACSRiskThresholds::standard();

        for lower in 0..=100 {
            for higher in lower..=100 {
                let mut lower_risk = ACSRiskVector::neutral();
                let mut higher_risk = ACSRiskVector::neutral();
                lower_risk.truth_risk = lower as f32 / 100.0;
                higher_risk.truth_risk = higher as f32 / 100.0;

                let lower_verdict = ACSAdmissionVerdict::from_risk(&lower_risk, thresholds);
                let higher_verdict = ACSAdmissionVerdict::from_risk(&higher_risk, thresholds);

                assert!(
                    higher_verdict.severity_rank() >= lower_verdict.severity_rank(),
                    "{higher_verdict:?} must not be weaker than {lower_verdict:?}"
                );
            }
        }
    }

    #[test]
    fn acs_admission_verdict_monotonicity_property_across_every_risk_axis() {
        let thresholds = ACSRiskThresholds::standard();
        let axes: [fn(&mut ACSRiskVector, f32); 8] = [
            |risk, value| risk.truth_risk = value,
            |risk, value| risk.safety_risk = value,
            |risk, value| risk.privacy_risk = value,
            |risk, value| risk.capability_risk = value,
            |risk, value| risk.durability_risk = value,
            |risk, value| risk.scope_rex_risk = value,
            |risk, value| risk.kernel_promotion_risk = value,
            |risk, value| risk.model_adaptation_risk = value,
        ];

        for axis in axes {
            for lower in 0..=100 {
                for higher in lower..=100 {
                    let mut lower_risk = ACSRiskVector::neutral();
                    let mut higher_risk = ACSRiskVector::neutral();
                    axis(&mut lower_risk, lower as f32 / 100.0);
                    axis(&mut higher_risk, higher as f32 / 100.0);

                    let lower_verdict = ACSAdmissionVerdict::from_risk(&lower_risk, thresholds);
                    let higher_verdict = ACSAdmissionVerdict::from_risk(&higher_risk, thresholds);

                    assert!(
                        higher_verdict.severity_rank() >= lower_verdict.severity_rank(),
                        "{higher_verdict:?} must not be weaker than {lower_verdict:?} on axis {axis:?}"
                    );
                }
            }
        }
    }

    #[test]
    fn acs_admission_concurrent_admissions_are_deterministic() {
        let policy = ACSPolicy::strict("policy-concurrent", 1_000);
        let input = ACSAdmissionInput {
            request_id: "req-concurrent".to_string(),
            payload: ACSAdmissionPayload::MemoryWrite {
                request: ACSMemoryWriteRequest {
                    address: "uas://note/concurrent".to_string(),
                    content_hash: "content-hash".to_string(),
                    durable: false,
                    mutation_envelope_id: None,
                },
            },
            submitted_at_ms: 1_001,
            risk: ACSRiskVector::neutral(),
            granted_capabilities: Vec::new(),
        };

        let handles: Vec<_> = (0..16)
            .map(|_| {
                let policy = policy.clone();
                let input = input.clone();
                std::thread::spawn(move || {
                    let mut audit_log = Vec::new();
                    let decision = admit_and_log(&input, &policy, 1_001, &mut audit_log);
                    (decision, audit_log)
                })
            })
            .collect();

        for handle in handles {
            let (decision, audit_log) = handle.join().expect("admission thread must not panic");
            assert_eq!(decision.verdict, ACSAdmissionVerdict::Allow);
            assert_eq!(audit_log.len(), 1);
            assert_eq!(audit_log[0].record_id, "acs:req-concurrent:1001");
        }
    }

    #[test]
    fn acs_admission_concurrent_admissions_do_not_cross_pollinate_verdicts() {
        let policy = ACSPolicy::strict("policy-concurrent-distinct", 1_000);
        let payload = ACSAdmissionPayload::MemoryWrite {
            request: ACSMemoryWriteRequest {
                address: "uas://note/concurrent".to_string(),
                content_hash: "content-hash".to_string(),
                durable: false,
                mutation_envelope_id: None,
            },
        };

        let cases: Vec<(&'static str, f32, ACSAdmissionVerdict)> = vec![
            ("req-allow", 0.0, ACSAdmissionVerdict::Allow),
            ("req-warn", 0.4, ACSAdmissionVerdict::AllowWithWarning),
            ("req-defer", 0.6, ACSAdmissionVerdict::Defer),
            ("req-quarantine", 0.8, ACSAdmissionVerdict::Quarantine),
            ("req-reject", 0.95, ACSAdmissionVerdict::Reject),
        ];

        let handles: Vec<_> = cases
            .iter()
            .map(|(request_id, axis, expected)| {
                let policy = policy.clone();
                let payload = payload.clone();
                let request_id = (*request_id).to_string();
                let axis_value = *axis;
                let expected = *expected;
                std::thread::spawn(move || {
                    let mut risk = ACSRiskVector::neutral();
                    risk.safety_risk = axis_value;
                    let input = ACSAdmissionInput {
                        request_id: request_id.clone(),
                        payload,
                        submitted_at_ms: 1_001,
                        risk,
                        granted_capabilities: Vec::new(),
                    };
                    let mut audit_log = Vec::new();
                    let decision = admit_and_log(&input, &policy, 1_001, &mut audit_log);
                    (request_id, decision, audit_log, expected)
                })
            })
            .collect();

        for handle in handles {
            let (request_id, decision, audit_log, expected) =
                handle.join().expect("admission thread must not panic");
            assert_eq!(decision.verdict, expected, "request_id={request_id}");
            assert_eq!(audit_log.len(), 1, "request_id={request_id}");
            assert_eq!(
                audit_log[0].record_id,
                format!("acs:{request_id}:1001"),
                "request_id={request_id}"
            );
            assert_eq!(
                audit_log[0].request_id, request_id,
                "verdict for {request_id} must reference its own request_id"
            );
        }
    }

    #[test]
    fn acs_admission_missing_risk_axis_is_rejected_on_decode() {
        let malformed = serde_json::json!({
            "truth_risk": 0.0,
            "safety_risk": 0.0,
            "privacy_risk": 0.0,
            "capability_risk": 0.0,
            "durability_risk": 0.0,
            "scope_rex_risk": 0.0,
            "kernel_promotion_risk": 0.0,
            "evidence_present": true
        });

        let decoded = serde_json::from_value::<ACSRiskVector>(malformed);

        assert!(decoded.is_err());
    }

    #[test]
    fn acs_admission_missing_risk_axis_names_decode_field() {
        let mut value =
            serde_json::to_value(ACSRiskVector::neutral()).expect("risk vector encodes");
        value
            .as_object_mut()
            .expect("risk vector encodes as object")
            .remove("model_adaptation_risk");

        let err = serde_json::from_value::<ACSRiskVector>(value).unwrap_err();
        let message = err.to_string();

        assert!(message.contains("missing_risk_axis"), "{message}");
        assert!(message.contains("model_adaptation_risk"), "{message}");
    }

    #[test]
    fn acs_admission_missing_risk_axis_names_risk_namespace() {
        let mut value =
            serde_json::to_value(ACSRiskVector::neutral()).expect("risk vector encodes");
        value
            .as_object_mut()
            .expect("risk vector encodes as object")
            .remove("model_adaptation_risk");

        let err = serde_json::from_value::<ACSRiskVector>(value).unwrap_err();
        let message = err.to_string();

        assert!(message.contains("missing_risk_axis"), "{message}");
        assert!(message.contains("risk.model_adaptation_risk"), "{message}");
    }

    #[test]
    fn acs_admission_null_risk_axis_names_decode_field() {
        let mut value =
            serde_json::to_value(ACSRiskVector::neutral()).expect("risk vector encodes");
        value["truth_risk"] = serde_json::json!(null);

        let err = serde_json::from_value::<ACSRiskVector>(value).unwrap_err();
        let message = err.to_string();

        assert!(message.contains("malformed_risk_axis"), "{message}");
        assert!(message.contains("truth_risk"), "{message}");
    }

    #[test]
    fn acs_admission_typed_risk_axis_names_decode_field() {
        let mut value =
            serde_json::to_value(ACSRiskVector::neutral()).expect("risk vector encodes");
        value["privacy_risk"] = serde_json::json!("0.1");

        let err = serde_json::from_value::<ACSRiskVector>(value).unwrap_err();
        let message = err.to_string();

        assert!(message.contains("malformed_risk_axis"), "{message}");
        assert!(message.contains("privacy_risk"), "{message}");
    }

    #[test]
    fn acs_admission_nonobject_risk_vector_names_decode_field() {
        let err = serde_json::from_value::<ACSRiskVector>(serde_json::json!([
            0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, true
        ]))
        .unwrap_err();
        let message = err.to_string();

        assert!(message.contains("malformed_risk_vector"), "{message}");
        assert!(message.contains("risk"), "{message}");
    }

    #[test]
    fn acs_admission_typed_evidence_field_names_decode_field() {
        let mut value =
            serde_json::to_value(ACSRiskVector::neutral()).expect("risk vector encodes");
        value["evidence_present"] = serde_json::json!("true");

        let err = serde_json::from_value::<ACSRiskVector>(value).unwrap_err();
        let message = err.to_string();

        assert!(message.contains("malformed_risk_field"), "{message}");
        assert!(message.contains("evidence_present"), "{message}");
    }

    #[test]
    fn acs_admission_shadow_risk_axis_is_rejected_on_decode() {
        let mut value =
            serde_json::to_value(ACSRiskVector::neutral()).expect("risk vector encodes");
        value["shadow_risk"] = serde_json::json!(1.0);

        let decoded = serde_json::from_value::<ACSRiskVector>(value);

        assert!(decoded.is_err());
    }

    #[test]
    fn acs_admission_shadow_risk_axis_names_malformed_risk_vector_field() {
        let mut value =
            serde_json::to_value(ACSRiskVector::neutral()).expect("risk vector encodes");
        value["shadow_risk"] = serde_json::json!(1.0);

        let err = serde_json::from_value::<ACSRiskVector>(value).unwrap_err();
        let message = err.to_string();

        assert!(message.contains("malformed_risk_vector"), "{message}");
        assert!(message.contains("shadow_risk"), "{message}");
    }

    #[test]
    fn acs_admission_shadow_risk_axis_names_risk_namespace() {
        let mut value =
            serde_json::to_value(ACSRiskVector::neutral()).expect("risk vector encodes");
        value["shadow_risk"] = serde_json::json!(1.0);

        let err = serde_json::from_value::<ACSRiskVector>(value).unwrap_err();
        let message = err.to_string();

        assert!(message.contains("malformed_risk_vector"), "{message}");
        assert!(message.contains("risk.shadow_risk"), "{message}");
    }

    #[test]
    fn acs_admission_out_of_range_risk_axis_is_rejected_on_decode() {
        let mut value =
            serde_json::to_value(ACSRiskVector::neutral()).expect("risk vector encodes");
        value["safety_risk"] = serde_json::json!(1.01);

        let err = serde_json::from_value::<ACSRiskVector>(value).unwrap_err();
        let message = err.to_string();

        assert!(message.contains("risk_axis_out_of_range"), "{message}");
        assert!(message.contains("safety_risk"), "{message}");
    }

    #[test]
    fn acs_admission_out_of_range_risk_axis_names_risk_namespace() {
        let mut value =
            serde_json::to_value(ACSRiskVector::neutral()).expect("risk vector encodes");
        value["safety_risk"] = serde_json::json!(1.01);

        let err = serde_json::from_value::<ACSRiskVector>(value).unwrap_err();
        let message = err.to_string();

        assert!(message.contains("risk_axis_out_of_range"), "{message}");
        assert!(message.contains("risk.safety_risk"), "{message}");
    }

    #[test]
    fn acs_admission_shadow_threshold_axis_is_rejected_on_decode() {
        let mut value =
            serde_json::to_value(ACSRiskThresholds::standard()).expect("thresholds encode");
        value["escalate_at"] = serde_json::json!(0.95);

        let decoded = serde_json::from_value::<ACSRiskThresholds>(value);

        assert!(decoded.is_err());
    }

    #[test]
    fn acs_admission_shadow_threshold_axis_names_malformed_policy_field() {
        let mut value =
            serde_json::to_value(ACSRiskThresholds::standard()).expect("thresholds encode");
        value["escalate_at"] = serde_json::json!(0.95);

        let err = serde_json::from_value::<ACSRiskThresholds>(value).unwrap_err();
        let message = err.to_string();

        assert!(message.contains("malformed_policy"), "{message}");
        assert!(message.contains("escalate_at"), "{message}");
    }

    #[test]
    fn acs_admission_shadow_threshold_axis_names_threshold_namespace() {
        let mut value =
            serde_json::to_value(ACSRiskThresholds::standard()).expect("thresholds encode");
        value["escalate_at"] = serde_json::json!(0.95);

        let err = serde_json::from_value::<ACSRiskThresholds>(value).unwrap_err();
        let message = err.to_string();

        assert!(message.contains("malformed_policy"), "{message}");
        assert!(message.contains("thresholds.escalate_at"), "{message}");
    }

    #[test]
    fn acs_admission_missing_threshold_axis_names_malformed_policy_field() {
        let mut value =
            serde_json::to_value(ACSRiskThresholds::standard()).expect("thresholds encode");
        value
            .as_object_mut()
            .expect("thresholds encode as object")
            .remove("defer_at");

        let err = serde_json::from_value::<ACSRiskThresholds>(value).unwrap_err();
        let message = err.to_string();

        assert!(message.contains("malformed_policy"), "{message}");
        assert!(message.contains("defer_at"), "{message}");
    }

    #[test]
    fn acs_admission_missing_threshold_axis_names_threshold_namespace() {
        let mut value =
            serde_json::to_value(ACSRiskThresholds::standard()).expect("thresholds encode");
        value
            .as_object_mut()
            .expect("thresholds encode as object")
            .remove("defer_at");

        let err = serde_json::from_value::<ACSRiskThresholds>(value).unwrap_err();
        let message = err.to_string();

        assert!(message.contains("malformed_policy"), "{message}");
        assert!(message.contains("thresholds.defer_at"), "{message}");
    }

    #[test]
    fn acs_admission_null_threshold_axis_names_malformed_policy_field() {
        let mut value =
            serde_json::to_value(ACSRiskThresholds::standard()).expect("thresholds encode");
        value["warn_at"] = serde_json::json!(null);

        let err = serde_json::from_value::<ACSRiskThresholds>(value).unwrap_err();
        let message = err.to_string();

        assert!(message.contains("malformed_policy"), "{message}");
        assert!(message.contains("warn_at"), "{message}");
    }

    #[test]
    fn acs_admission_typed_threshold_axis_names_malformed_policy_field() {
        let mut value =
            serde_json::to_value(ACSRiskThresholds::standard()).expect("thresholds encode");
        value["reject_at"] = serde_json::json!("0.9");

        let err = serde_json::from_value::<ACSRiskThresholds>(value).unwrap_err();
        let message = err.to_string();

        assert!(message.contains("malformed_policy"), "{message}");
        assert!(message.contains("reject_at"), "{message}");
    }

    #[test]
    fn acs_admission_nonobject_thresholds_name_malformed_policy() {
        let err =
            serde_json::from_value::<ACSRiskThresholds>(serde_json::json!([0.35, 0.55, 0.75, 0.9]))
                .unwrap_err();
        let message = err.to_string();

        assert!(message.contains("malformed_policy"), "{message}");
        assert!(message.contains("thresholds"), "{message}");
    }

    #[test]
    fn acs_admission_missing_policy_thresholds_names_malformed_policy_field() {
        let mut value = serde_json::to_value(ACSPolicy::strict("policy-missing-thresholds", 1_000))
            .expect("policy encodes");
        value
            .as_object_mut()
            .expect("policy encodes as object")
            .remove("thresholds");

        let err = serde_json::from_value::<ACSPolicy>(value).unwrap_err();
        let message = err.to_string();

        assert!(message.contains("malformed_policy"), "{message}");
        assert!(message.contains("thresholds"), "{message}");
    }

    #[test]
    fn acs_admission_missing_policy_id_names_malformed_policy_field() {
        let mut value = serde_json::to_value(ACSPolicy::strict("policy-missing-id", 1_000))
            .expect("policy encodes");
        value
            .as_object_mut()
            .expect("policy encodes as object")
            .remove("policy_id");

        let err = serde_json::from_value::<ACSPolicy>(value).unwrap_err();
        let message = err.to_string();

        assert!(message.contains("malformed_policy"), "{message}");
        assert!(message.contains("policy_id"), "{message}");
    }

    #[test]
    fn acs_admission_missing_policy_version_names_malformed_policy_field() {
        let mut value = serde_json::to_value(ACSPolicy::strict("policy-missing-version", 1_000))
            .expect("policy encodes");
        value
            .as_object_mut()
            .expect("policy encodes as object")
            .remove("version");

        let err = serde_json::from_value::<ACSPolicy>(value).unwrap_err();
        let message = err.to_string();

        assert!(message.contains("malformed_policy"), "{message}");
        assert!(message.contains("version"), "{message}");
    }

    #[test]
    fn acs_admission_oversized_policy_version_names_malformed_policy_field() {
        let mut value = serde_json::to_value(ACSPolicy::strict("policy-oversized-version", 1_000))
            .expect("policy encodes");
        value["version"] = serde_json::json!(u64::MAX);

        let err = serde_json::from_value::<ACSPolicy>(value).unwrap_err();
        let message = err.to_string();

        assert!(message.contains("malformed_policy"), "{message}");
        assert!(message.contains("version"), "{message}");
    }

    #[test]
    fn acs_admission_missing_policy_valid_from_names_malformed_policy_field() {
        let mut value = serde_json::to_value(ACSPolicy::strict("policy-missing-valid-from", 1_000))
            .expect("policy encodes");
        value
            .as_object_mut()
            .expect("policy encodes as object")
            .remove("valid_from_ms");

        let err = serde_json::from_value::<ACSPolicy>(value).unwrap_err();
        let message = err.to_string();

        assert!(message.contains("malformed_policy"), "{message}");
        assert!(message.contains("valid_from_ms"), "{message}");
    }

    #[test]
    fn acs_admission_missing_policy_expires_at_names_malformed_policy_field() {
        let mut value = serde_json::to_value(ACSPolicy::strict("policy-missing-expires-at", 1_000))
            .expect("policy encodes");
        value
            .as_object_mut()
            .expect("policy encodes as object")
            .remove("expires_at_ms");

        let err = serde_json::from_value::<ACSPolicy>(value).unwrap_err();
        let message = err.to_string();

        assert!(message.contains("malformed_policy"), "{message}");
        assert!(message.contains("expires_at_ms"), "{message}");
    }

    #[test]
    fn acs_admission_missing_policy_required_capabilities_names_malformed_policy_field() {
        let mut value = serde_json::to_value(ACSPolicy::strict("policy-missing-required", 1_000))
            .expect("policy encodes");
        value
            .as_object_mut()
            .expect("policy encodes as object")
            .remove("required_capabilities");

        let err = serde_json::from_value::<ACSPolicy>(value).unwrap_err();
        let message = err.to_string();

        assert!(message.contains("malformed_policy"), "{message}");
        assert!(message.contains("required_capabilities"), "{message}");
    }

    #[test]
    fn acs_admission_missing_policy_operation_thresholds_names_malformed_policy_field() {
        let mut value = serde_json::to_value(ACSPolicy::strict(
            "policy-missing-operation-thresholds",
            1_000,
        ))
        .expect("policy encodes");
        value
            .as_object_mut()
            .expect("policy encodes as object")
            .remove("operation_thresholds");

        let err = serde_json::from_value::<ACSPolicy>(value).unwrap_err();
        let message = err.to_string();

        assert!(message.contains("malformed_policy"), "{message}");
        assert!(message.contains("operation_thresholds"), "{message}");
    }

    #[test]
    fn acs_admission_shadow_policy_field_names_malformed_policy_field() {
        let mut value = serde_json::to_value(ACSPolicy::strict("policy-shadow-field", 1_000))
            .expect("policy encodes");
        value["shadow_policy"] = serde_json::json!("allow");

        let err = serde_json::from_value::<ACSPolicy>(value).unwrap_err();
        let message = err.to_string();

        assert!(message.contains("malformed_policy"), "{message}");
        assert!(message.contains("shadow_policy"), "{message}");
    }

    #[test]
    fn acs_admission_nonmonotonic_thresholds_are_rejected_on_decode() {
        let mut value =
            serde_json::to_value(ACSRiskThresholds::standard()).expect("thresholds encode");
        value["quarantine_at"] = serde_json::json!(0.4);

        let err = serde_json::from_value::<ACSRiskThresholds>(value).unwrap_err();
        let message = err.to_string();

        assert!(message.contains("malformed_policy"), "{message}");
        assert!(message.contains("risk_threshold_order"), "{message}");
    }

    #[test]
    fn acs_admission_shadow_operation_threshold_rule_field_is_rejected_on_decode() {
        let rule = ACSOperationThresholdRule::new(
            ACSOperationKind::KernelPromotion,
            ACSRiskThresholds::standard(),
        );
        let mut value = serde_json::to_value(rule).expect("threshold rule encodes");
        value["shadow_operation"] = serde_json::json!("model_adaptation");

        let decoded = serde_json::from_value::<ACSOperationThresholdRule>(value);

        assert!(decoded.is_err());
    }

    #[test]
    fn acs_admission_shadow_operation_threshold_rule_field_names_malformed_policy_field() {
        let rule = ACSOperationThresholdRule::new(
            ACSOperationKind::KernelPromotion,
            ACSRiskThresholds::standard(),
        );
        let mut value = serde_json::to_value(rule).expect("threshold rule encodes");
        value["shadow_operation"] = serde_json::json!("model_adaptation");

        let err = serde_json::from_value::<ACSOperationThresholdRule>(value).unwrap_err();
        let message = err.to_string();

        assert!(message.contains("malformed_policy"), "{message}");
        assert!(message.contains("shadow_operation"), "{message}");
    }

    #[test]
    fn acs_admission_shadow_operation_threshold_rule_field_names_threshold_namespace() {
        let rule = ACSOperationThresholdRule::new(
            ACSOperationKind::KernelPromotion,
            ACSRiskThresholds::standard(),
        );
        let mut value = serde_json::to_value(rule).expect("threshold rule encodes");
        value["shadow_operation"] = serde_json::json!("model_adaptation");

        let err = serde_json::from_value::<ACSOperationThresholdRule>(value).unwrap_err();
        let message = err.to_string();

        assert!(message.contains("malformed_policy"), "{message}");
        assert!(
            message.contains("operation_thresholds.shadow_operation"),
            "{message}"
        );
    }

    #[test]
    fn acs_admission_missing_operation_threshold_operation_names_malformed_policy_field() {
        let value = serde_json::json!({
            "thresholds": ACSRiskThresholds::standard()
        });

        let err = serde_json::from_value::<ACSOperationThresholdRule>(value).unwrap_err();
        let message = err.to_string();

        assert!(message.contains("malformed_policy"), "{message}");
        assert!(
            message.contains("operation_thresholds.operation"),
            "{message}"
        );
    }

    #[test]
    fn acs_admission_missing_operation_threshold_thresholds_names_malformed_policy_field() {
        let value = serde_json::json!({
            "operation": "tool_action"
        });

        let err = serde_json::from_value::<ACSOperationThresholdRule>(value).unwrap_err();
        let message = err.to_string();

        assert!(message.contains("malformed_policy"), "{message}");
        assert!(
            message.contains("operation_thresholds.thresholds"),
            "{message}"
        );
    }

    #[test]
    fn acs_admission_unknown_operation_threshold_operation_names_malformed_policy_field() {
        let value = serde_json::json!({
            "operation": "quantum_commit",
            "thresholds": ACSRiskThresholds::standard()
        });

        let err = serde_json::from_value::<ACSOperationThresholdRule>(value).unwrap_err();
        let message = err.to_string();

        assert!(message.contains("malformed_policy"), "{message}");
        assert!(
            message.contains("operation_thresholds.operation"),
            "{message}"
        );
    }

    #[test]
    fn acs_admission_shadow_capability_rule_field_is_rejected_on_decode() {
        let rule = ACSCapabilityRule::new(
            ACSOperationKind::ToolAction,
            Capability::Other {
                name: "ToolExec".to_string(),
            },
        );
        let mut value = serde_json::to_value(rule).expect("capability rule encodes");
        value["shadow_capability"] = serde_json::json!("KernelPromote");

        let decoded = serde_json::from_value::<ACSCapabilityRule>(value);

        assert!(decoded.is_err());
    }

    #[test]
    fn acs_admission_shadow_capability_rule_field_names_malformed_policy_field() {
        let rule = ACSCapabilityRule::new(
            ACSOperationKind::ToolAction,
            Capability::Other {
                name: "ToolExec".to_string(),
            },
        );
        let mut value = serde_json::to_value(rule).expect("capability rule encodes");
        value["shadow_capability"] = serde_json::json!("KernelPromote");

        let err = serde_json::from_value::<ACSCapabilityRule>(value).unwrap_err();
        let message = err.to_string();

        assert!(message.contains("malformed_policy"), "{message}");
        assert!(message.contains("shadow_capability"), "{message}");
    }

    #[test]
    fn acs_admission_shadow_capability_rule_field_names_required_namespace() {
        let rule = ACSCapabilityRule::new(
            ACSOperationKind::ToolAction,
            Capability::Other {
                name: "ToolExec".to_string(),
            },
        );
        let mut value = serde_json::to_value(rule).expect("capability rule encodes");
        value["shadow_capability"] = serde_json::json!("KernelPromote");

        let err = serde_json::from_value::<ACSCapabilityRule>(value).unwrap_err();
        let message = err.to_string();

        assert!(message.contains("malformed_policy"), "{message}");
        assert!(
            message.contains("required_capabilities.shadow_capability"),
            "{message}"
        );
    }

    #[test]
    fn acs_admission_missing_capability_rule_operation_names_malformed_policy_field() {
        let value = serde_json::json!({
            "capability": {
                "kind": "other",
                "value": {
                    "name": "ToolExec"
                }
            }
        });

        let err = serde_json::from_value::<ACSCapabilityRule>(value).unwrap_err();
        let message = err.to_string();

        assert!(message.contains("malformed_policy"), "{message}");
        assert!(
            message.contains("required_capabilities.operation"),
            "{message}"
        );
    }

    #[test]
    fn acs_admission_null_capability_rule_capability_names_malformed_policy_field() {
        let value = serde_json::json!({
            "operation": "tool_action",
            "capability": null
        });

        let err = serde_json::from_value::<ACSCapabilityRule>(value).unwrap_err();
        let message = err.to_string();

        assert!(message.contains("malformed_policy"), "{message}");
        assert!(
            message.contains("required_capabilities.capability"),
            "{message}"
        );
    }

    #[test]
    fn acs_admission_typed_capability_rule_operation_names_malformed_policy_field() {
        let value = serde_json::json!({
            "operation": 7,
            "capability": {
                "kind": "other",
                "value": {
                    "name": "ToolExec"
                }
            }
        });

        let err = serde_json::from_value::<ACSCapabilityRule>(value).unwrap_err();
        let message = err.to_string();

        assert!(message.contains("malformed_policy"), "{message}");
        assert!(
            message.contains("required_capabilities.operation"),
            "{message}"
        );
    }

    #[test]
    fn acs_admission_unknown_capability_rule_operation_names_malformed_policy_field() {
        let value = serde_json::json!({
            "operation": "quantum_commit",
            "capability": {
                "kind": "other",
                "value": {
                    "name": "ToolExec"
                }
            }
        });

        let err = serde_json::from_value::<ACSCapabilityRule>(value).unwrap_err();
        let message = err.to_string();

        assert!(message.contains("malformed_policy"), "{message}");
        assert!(
            message.contains("required_capabilities.operation"),
            "{message}"
        );
    }

    #[test]
    fn acs_admission_missing_capability_rule_capability_kind_names_malformed_policy_field() {
        let value = serde_json::json!({
            "operation": "tool_action",
            "capability": {
                "value": {
                    "name": "ToolExec"
                }
            }
        });

        let err = serde_json::from_value::<ACSCapabilityRule>(value).unwrap_err();
        let message = err.to_string();

        assert!(message.contains("malformed_policy"), "{message}");
        assert!(
            message.contains("required_capabilities.capability"),
            "{message}"
        );
    }

    #[test]
    fn acs_admission_missing_capability_rule_other_name_names_malformed_policy_field() {
        let value = serde_json::json!({
            "operation": "tool_action",
            "capability": {
                "kind": "other",
                "value": {}
            }
        });

        let err = serde_json::from_value::<ACSCapabilityRule>(value).unwrap_err();
        let message = err.to_string();

        assert!(message.contains("malformed_policy"), "{message}");
        assert!(
            message.contains("required_capabilities.other.name"),
            "{message}"
        );
    }

    #[test]
    fn acs_admission_oversized_capability_rule_biometric_ttl_names_malformed_policy_field() {
        let value = serde_json::json!({
            "operation": "kernel_promotion",
            "capability": {
                "kind": "biometric_session",
                "value": {
                    "ttl_secs": u64::MAX
                }
            }
        });

        let err = serde_json::from_value::<ACSCapabilityRule>(value).unwrap_err();
        let message = err.to_string();

        assert!(message.contains("malformed_policy"), "{message}");
        assert!(
            message.contains("required_capabilities.biometric_session.ttl_secs"),
            "{message}"
        );
    }

    #[test]
    fn acs_admission_shadow_capability_value_field_is_rejected_on_decode() {
        let value = serde_json::json!({
            "operation": "tool_action",
            "capability": {
                "kind": "other",
                "value": {
                    "name": "ToolExec",
                    "shadow_name": "KernelPromote"
                }
            }
        });

        let decoded = serde_json::from_value::<ACSCapabilityRule>(value);

        assert!(decoded.is_err());
    }

    #[test]
    fn acs_admission_shadow_capability_value_field_names_malformed_policy_field() {
        let value = serde_json::json!({
            "operation": "tool_action",
            "capability": {
                "kind": "other",
                "value": {
                    "name": "ToolExec",
                    "shadow_name": "KernelPromote"
                }
            }
        });

        let err = serde_json::from_value::<ACSCapabilityRule>(value).unwrap_err();
        let message = err.to_string();

        assert!(message.contains("malformed_policy"), "{message}");
        assert!(
            message.contains("required_capabilities.other.shadow_name"),
            "{message}"
        );
    }

    #[test]
    fn acs_admission_noncanonical_capability_rule_is_rejected_on_decode() {
        let value = serde_json::json!({
            "operation": "tool_action",
            "capability": {
                "kind": "other",
                "value": {
                    "name": "Tool Exec"
                }
            }
        });

        let err = serde_json::from_value::<ACSCapabilityRule>(value).unwrap_err();
        let message = err.to_string();

        assert!(message.contains("malformed_policy"), "{message}");
        assert!(
            message.contains("required_capabilities.other.name"),
            "{message}"
        );
    }

    #[test]
    fn acs_admission_shadow_capability_envelope_field_is_rejected_on_decode() {
        let value = serde_json::json!({
            "operation": "tool_action",
            "capability": {
                "kind": "other",
                "value": {
                    "name": "ToolExec"
                },
                "shadow_kind": "network_host"
            }
        });

        let decoded = serde_json::from_value::<ACSCapabilityRule>(value);

        assert!(decoded.is_err());
    }

    #[test]
    fn acs_admission_shadow_capability_envelope_field_names_malformed_policy_field() {
        let value = serde_json::json!({
            "operation": "tool_action",
            "capability": {
                "kind": "other",
                "value": {
                    "name": "ToolExec"
                },
                "shadow_kind": "network_host"
            }
        });

        let err = serde_json::from_value::<ACSCapabilityRule>(value).unwrap_err();
        let message = err.to_string();

        assert!(message.contains("malformed_policy"), "{message}");
        assert!(
            message.contains("required_capabilities.shadow_kind"),
            "{message}"
        );
    }

    #[test]
    fn acs_admission_shadow_policy_field_is_rejected_on_decode() {
        let mut value = serde_json::to_value(ACSPolicy::strict("policy-shadow", 1_000))
            .expect("policy encodes");
        value["shadow_valid_until_ms"] = serde_json::json!(i64::MAX);

        let decoded = serde_json::from_value::<ACSPolicy>(value);

        assert!(decoded.is_err());
    }

    #[test]
    fn acs_admission_shadow_decision_field_is_rejected_on_decode() {
        let decision = ACSAdmissionDecision {
            verdict: ACSAdmissionVerdict::Allow,
            audit_record: audit_record_fixture(ACSAdmissionVerdict::Allow),
        };
        let mut value = serde_json::to_value(decision).expect("decision encodes");
        value["shadow_verdict"] = serde_json::json!("allow");

        let decoded = serde_json::from_value::<ACSAdmissionDecision>(value);

        assert!(decoded.is_err());
    }

    #[test]
    fn acs_admission_mismatched_decision_verdict_is_rejected_on_decode() {
        let decision = ACSAdmissionDecision {
            verdict: ACSAdmissionVerdict::Allow,
            audit_record: audit_record_fixture(ACSAdmissionVerdict::Reject),
        };
        let value = serde_json::to_value(decision).expect("decision encodes");

        let decoded = serde_json::from_value::<ACSAdmissionDecision>(value);
        let message = decoded.unwrap_err().to_string();

        assert!(message.contains("mismatched_decision_verdict"), "{message}");
        assert!(message.contains("acs:req:1001"), "{message}");
    }

    #[test]
    fn acs_admission_audit_corruption_rejects_unknown_verdict() {
        let record = ACSAuditRecord {
            record_id: "acs:req:1001".to_string(),
            request_id: "req".to_string(),
            policy_id: "policy".to_string(),
            policy_version: 1,
            operation: ACSOperationKind::ToolAction,
            verdict: ACSAdmissionVerdict::Allow,
            reason: "allow".to_string(),
            risk_max: 0.0,
            emitted_at_ms: 1_001,
        };
        let mut value = serde_json::to_value(record).expect("audit record must serialize");
        value["verdict"] = serde_json::json!("silently_allow");

        let decoded = serde_json::from_value::<ACSAuditRecord>(value);

        assert!(decoded.is_err());
    }

    #[test]
    fn acs_admission_audit_corruption_unknown_verdict_names_corrupt_record_field() {
        let record = audit_record_fixture(ACSAdmissionVerdict::Allow);
        let record_id = record.record_id.clone();
        let mut value = serde_json::to_value(record).expect("audit record must serialize");
        value["verdict"] = serde_json::json!("silently_allow");

        let err = serde_json::from_value::<ACSAuditRecord>(value).unwrap_err();
        let message = err.to_string();

        assert!(message.contains("corrupt_acs_audit_record"), "{message}");
        assert!(message.contains("verdict"), "{message}");
        assert!(message.contains(record_id.as_str()), "{message}");
    }

    #[test]
    fn acs_admission_audit_corruption_oversized_policy_version_names_corrupt_record_field() {
        let record = audit_record_fixture(ACSAdmissionVerdict::Allow);
        let record_id = record.record_id.clone();
        let mut value = serde_json::to_value(record).expect("audit record must serialize");
        value["policy_version"] = serde_json::json!(u64::MAX);

        let err = serde_json::from_value::<ACSAuditRecord>(value).unwrap_err();
        let message = err.to_string();

        assert!(message.contains("corrupt_acs_audit_record"), "{message}");
        assert!(message.contains("policy_version"), "{message}");
        assert!(message.contains(record_id.as_str()), "{message}");
    }

    #[test]
    fn acs_admission_audit_corruption_typed_risk_max_names_corrupt_record_field() {
        let record = audit_record_fixture(ACSAdmissionVerdict::Allow);
        let record_id = record.record_id.clone();
        let mut value = serde_json::to_value(record).expect("audit record must serialize");
        value["risk_max"] = serde_json::json!("0.25");

        let err = serde_json::from_value::<ACSAuditRecord>(value).unwrap_err();
        let message = err.to_string();

        assert!(message.contains("corrupt_acs_audit_record"), "{message}");
        assert!(message.contains("risk_max"), "{message}");
        assert!(message.contains(record_id.as_str()), "{message}");
    }

    #[test]
    fn acs_admission_audit_corruption_typed_emitted_at_names_corrupt_record_field() {
        let record = audit_record_fixture(ACSAdmissionVerdict::Allow);
        let record_id = record.record_id.clone();
        let mut value = serde_json::to_value(record).expect("audit record must serialize");
        value["emitted_at_ms"] = serde_json::json!("1001");

        let err = serde_json::from_value::<ACSAuditRecord>(value).unwrap_err();
        let message = err.to_string();

        assert!(message.contains("corrupt_acs_audit_record"), "{message}");
        assert!(message.contains("emitted_at_ms"), "{message}");
        assert!(message.contains(record_id.as_str()), "{message}");
    }

    #[test]
    fn acs_admission_malformed_policy_rejects_and_logs() {
        let mut policy = ACSPolicy::strict("policy-nonfinite", 1_000);
        policy.thresholds.warn_at = f32::NAN;
        let input = ACSAdmissionInput {
            request_id: "req-malformed-policy".to_string(),
            payload: tool_action_payload(),
            submitted_at_ms: 1_001,
            risk: ACSRiskVector::neutral(),
            granted_capabilities: Vec::new(),
        };
        let mut audit_log = Vec::new();

        let decision = admit_and_log(&input, &policy, 1_001, &mut audit_log);

        assert_eq!(decision.verdict, ACSAdmissionVerdict::Reject);
        assert_eq!(decision.audit_record.reason, "malformed_policy");
        assert_eq!(audit_log.len(), 1);
    }

    #[test]
    fn acs_admission_zero_policy_version_rejects_and_logs_valid_audit() {
        let mut policy = ACSPolicy::strict("policy-zero-version", 1_000);
        policy.version = 0;
        let input = ACSAdmissionInput {
            request_id: "req-zero-policy-version".to_string(),
            payload: tool_action_payload(),
            submitted_at_ms: 1_001,
            risk: ACSRiskVector::neutral(),
            granted_capabilities: Vec::new(),
        };
        let mut audit_log = Vec::new();

        let decision = admit_and_log(&input, &policy, 1_001, &mut audit_log);

        assert_eq!(decision.verdict, ACSAdmissionVerdict::Reject);
        assert_eq!(decision.audit_record.reason, "malformed_policy");
        assert_eq!(decision.audit_record.policy_version, 1);
        assert!(decision.audit_record.validate().is_ok());
        assert_eq!(audit_log.len(), 1);
    }

    #[test]
    fn acs_admission_empty_policy_id_rejects_and_logs_valid_audit() {
        let policy = ACSPolicy::strict(" ", 1_000);
        let input = ACSAdmissionInput {
            request_id: "req-empty-policy".to_string(),
            payload: tool_action_payload(),
            submitted_at_ms: 1_001,
            risk: ACSRiskVector::neutral(),
            granted_capabilities: Vec::new(),
        };
        let mut audit_log = Vec::new();

        let decision = admit_and_log(&input, &policy, 1_001, &mut audit_log);

        assert_eq!(decision.verdict, ACSAdmissionVerdict::Reject);
        assert_eq!(decision.audit_record.reason, "malformed_policy");
        assert!(decision.audit_record.validate().is_ok());
        assert!(decision
            .audit_record
            .policy_id
            .starts_with("malformed_policy."));
        assert_eq!(audit_log.len(), 1);
    }

    #[test]
    fn acs_admission_distinct_malformed_policy_ids_remain_distinct_in_audit() {
        let input = ACSAdmissionInput {
            request_id: "req-distinct-malformed-policy".to_string(),
            payload: tool_action_payload(),
            submitted_at_ms: 1_001,
            risk: ACSRiskVector::neutral(),
            granted_capabilities: Vec::new(),
        };
        let first = admit(&input, &ACSPolicy::strict(" ", 1_000), 1_001);
        let second = admit(&input, &ACSPolicy::strict("\t", 1_000), 1_001);

        assert_ne!(first.audit_record.policy_id, second.audit_record.policy_id);
        assert!(first
            .audit_record
            .policy_id
            .starts_with("malformed_policy."));
        assert!(second
            .audit_record
            .policy_id
            .starts_with("malformed_policy."));
        assert!(first.audit_record.validate().is_ok());
        assert!(second.audit_record.validate().is_ok());
    }

    #[test]
    fn acs_admission_reserved_malformed_policy_id_remains_distinct_in_audit() {
        let first_input = ACSAdmissionInput {
            request_id: "req-reserved-malformed-policy-1".to_string(),
            payload: tool_action_payload(),
            submitted_at_ms: 1_001,
            risk: ACSRiskVector::neutral(),
            granted_capabilities: Vec::new(),
        };
        let second_input = ACSAdmissionInput {
            request_id: "req-reserved-malformed-policy-2".to_string(),
            payload: tool_action_payload(),
            submitted_at_ms: 1_001,
            risk: ACSRiskVector::neutral(),
            granted_capabilities: Vec::new(),
        };

        let first = admit(&first_input, &ACSPolicy::strict(" ", 1_000), 1_001);
        let second = admit(
            &second_input,
            &ACSPolicy::strict(audit_policy_id(" "), 1_000),
            1_001,
        );

        assert_ne!(first.audit_record.policy_id, second.audit_record.policy_id);
        assert!(first
            .audit_record
            .policy_id
            .starts_with("malformed_policy."));
        assert!(second
            .audit_record
            .policy_id
            .starts_with("malformed_policy."));
        assert!(first.audit_record.validate().is_ok());
        assert!(second.audit_record.validate().is_ok());
    }

    #[test]
    fn acs_admission_policy_rejects_reserved_malformed_policy_namespace() {
        let policy = ACSPolicy::strict(audit_policy_id(" "), 1_000);

        let err = policy.validate_at(1_001).unwrap_err();

        assert_eq!(err.cause(), "malformed_policy");
        assert_eq!(err.field(), Some("policy_id"));
    }

    #[test]
    fn acs_admission_policy_rejects_reserved_malformed_request_policy_namespace() {
        let policy = ACSPolicy::strict(audit_request_id(" "), 1_000);
        let input = ACSAdmissionInput {
            request_id: "req-cross-reserved-policy".to_string(),
            payload: tool_action_payload(),
            submitted_at_ms: 1_001,
            risk: ACSRiskVector::neutral(),
            granted_capabilities: Vec::new(),
        };
        let mut audit_log = Vec::new();

        let err = policy.validate_at(1_001).unwrap_err();
        let decision = admit_and_log(&input, &policy, 1_001, &mut audit_log);

        assert_eq!(err.cause(), "malformed_policy");
        assert_eq!(err.field(), Some("policy_id"));
        assert_eq!(decision.verdict, ACSAdmissionVerdict::Reject);
        assert_eq!(decision.audit_record.reason, "malformed_policy");
        assert!(decision
            .audit_record
            .policy_id
            .starts_with("malformed_policy."));
        assert!(decision.audit_record.validate().is_ok());
        assert_eq!(audit_log.len(), 1);
    }

    #[test]
    fn acs_admission_noncanonical_policy_id_logs_valid_audit() {
        let policy = ACSPolicy::strict("policy forged", 1_000);
        let input = ACSAdmissionInput {
            request_id: "req-policy-with-space".to_string(),
            payload: tool_action_payload(),
            submitted_at_ms: 1_001,
            risk: ACSRiskVector::neutral(),
            granted_capabilities: Vec::new(),
        };
        let mut audit_log = Vec::new();

        let err = policy.validate_at(1_001).unwrap_err();
        assert_eq!(err.cause(), "malformed_policy");
        assert_eq!(err.field(), Some("policy_id"));

        let decision = admit_and_log(&input, &policy, 1_001, &mut audit_log);

        assert_eq!(decision.verdict, ACSAdmissionVerdict::Reject);
        assert_eq!(decision.audit_record.reason, "malformed_policy");
        assert!(decision
            .audit_record
            .policy_id
            .starts_with("malformed_policy."));
        assert!(decision.audit_record.validate().is_ok());
        assert_eq!(audit_log.len(), 1);
    }

    #[test]
    fn acs_admission_symbol_policy_id_logs_valid_audit() {
        let policy = ACSPolicy::strict("policy$forged", 1_000);
        let input = ACSAdmissionInput {
            request_id: "req-policy-with-symbol".to_string(),
            payload: tool_action_payload(),
            submitted_at_ms: 1_001,
            risk: ACSRiskVector::neutral(),
            granted_capabilities: Vec::new(),
        };
        let mut audit_log = Vec::new();

        let err = policy.validate_at(1_001).unwrap_err();
        assert_eq!(err.cause(), "malformed_policy");
        assert_eq!(err.field(), Some("policy_id"));

        let decision = admit_and_log(&input, &policy, 1_001, &mut audit_log);

        assert_eq!(decision.verdict, ACSAdmissionVerdict::Reject);
        assert_eq!(decision.audit_record.reason, "malformed_policy");
        assert!(decision
            .audit_record
            .policy_id
            .starts_with("malformed_policy."));
        assert!(decision.audit_record.validate().is_ok());
        assert_eq!(audit_log.len(), 1);
    }

    #[test]
    fn acs_admission_future_policy_rejects_and_logs() {
        let policy = ACSPolicy::strict("policy-future", 2_000);
        let input = ACSAdmissionInput {
            request_id: "req-future-policy".to_string(),
            payload: tool_action_payload(),
            submitted_at_ms: 1_001,
            risk: ACSRiskVector::neutral(),
            granted_capabilities: Vec::new(),
        };
        let mut audit_log = Vec::new();

        let decision = admit_and_log(&input, &policy, 1_001, &mut audit_log);

        assert_eq!(decision.verdict, ACSAdmissionVerdict::Reject);
        assert_eq!(decision.audit_record.reason, "policy_not_yet_valid");
        assert_eq!(audit_log.len(), 1);
    }

    #[test]
    fn acs_admission_future_input_rejects_and_logs() {
        let input = ACSAdmissionInput {
            request_id: "req-future-input".to_string(),
            payload: tool_action_payload(),
            submitted_at_ms: 2_000,
            risk: ACSRiskVector::neutral(),
            granted_capabilities: Vec::new(),
        };
        let policy = ACSPolicy::strict("policy-future-input", 1_000);
        let mut audit_log = Vec::new();

        let decision = admit_and_log(&input, &policy, 1_001, &mut audit_log);

        assert_eq!(decision.verdict, ACSAdmissionVerdict::Reject);
        assert_eq!(decision.audit_record.reason, "future_admission_input");
        assert_eq!(audit_log.len(), 1);
    }

    #[test]
    fn acs_admission_future_input_reason_precedes_malformed_policy() {
        let input = ACSAdmissionInput {
            request_id: "req-future-input-policy-mask".to_string(),
            payload: tool_action_payload(),
            submitted_at_ms: 2_000,
            risk: ACSRiskVector::neutral(),
            granted_capabilities: Vec::new(),
        };
        let mut policy = ACSPolicy::strict("policy-future-input-policy-mask", 1_000);
        policy.thresholds.warn_at = f32::NAN;
        let mut audit_log = Vec::new();

        let decision = admit_and_log(&input, &policy, 1_001, &mut audit_log);

        assert_eq!(decision.verdict, ACSAdmissionVerdict::Reject);
        assert_eq!(decision.audit_record.reason, "future_admission_input");
        assert_eq!(audit_log.len(), 1);
        assert!(decision.audit_record.validate().is_ok());
    }

    #[test]
    fn acs_admission_negative_submission_time_rejects_and_logs() {
        let input = ACSAdmissionInput {
            request_id: "req-negative-input-time".to_string(),
            payload: tool_action_payload(),
            submitted_at_ms: -1,
            risk: ACSRiskVector::neutral(),
            granted_capabilities: Vec::new(),
        };
        let policy = ACSPolicy::strict("policy-negative-input-time", 1_000);
        let mut audit_log = Vec::new();

        let decision = admit_and_log(&input, &policy, 1_001, &mut audit_log);

        assert_eq!(decision.verdict, ACSAdmissionVerdict::Reject);
        assert_eq!(decision.audit_record.reason, "forged_admission_input");
        assert_eq!(audit_log.len(), 1);
        assert!(decision.audit_record.validate().is_ok());
    }

    #[test]
    fn acs_admission_negative_admission_clock_rejects_with_valid_audit() {
        let input = ACSAdmissionInput {
            request_id: "req-negative-clock".to_string(),
            payload: tool_action_payload(),
            submitted_at_ms: 0,
            risk: ACSRiskVector::neutral(),
            granted_capabilities: Vec::new(),
        };
        let policy = ACSPolicy::strict("policy-negative-clock", 0);
        let mut audit_log = Vec::new();

        let decision = admit_and_log(&input, &policy, -1, &mut audit_log);

        assert_eq!(decision.verdict, ACSAdmissionVerdict::Reject);
        assert_eq!(decision.audit_record.reason, "invalid_admission_time");
        assert_eq!(decision.audit_record.emitted_at_ms, 0);
        assert_eq!(audit_log.len(), 1);
        assert!(decision.audit_record.validate().is_ok());
    }

    #[test]
    fn acs_admission_missing_evidence_warns_and_logs() {
        let mut risk = ACSRiskVector::neutral();
        risk.evidence_present = false;
        let input = ACSAdmissionInput {
            request_id: "req-missing-evidence".to_string(),
            payload: tool_action_payload(),
            submitted_at_ms: 1_001,
            risk,
            granted_capabilities: Vec::new(),
        };
        let policy = ACSPolicy::strict("policy-missing-evidence", 1_000);
        let mut audit_log = Vec::new();

        let decision = admit_and_log(&input, &policy, 1_001, &mut audit_log);

        assert_eq!(decision.verdict, ACSAdmissionVerdict::AllowWithWarning);
        assert_eq!(decision.audit_record.reason, "allow_with_warning");
        assert_eq!(audit_log.len(), 1);
    }

    #[test]
    fn acs_admission_l2_missing_evidence_rejects_and_logs() {
        let mut risk = ACSRiskVector::neutral();
        risk.evidence_present = false;
        let cases = [
            (
                ACSAdmissionPayload::KernelPromotion {
                    request: ACSKernelPromotionRequest {
                        kernel_id: "kernel-1".to_string(),
                        signed_plan_hash: "plan-hash".to_string(),
                        mutation_envelope_id: Some("mutation-1".to_string()),
                    },
                },
                named_capability("KernelPromote"),
            ),
            (
                ACSAdmissionPayload::ModelAdaptation {
                    request: ACSModelAdaptationRequest {
                        adapter_id: "adapter-1".to_string(),
                        model_id: "local-helper-1".to_string(),
                        checkpoint_hash: "checkpoint-hash".to_string(),
                        mutation_envelope_id: Some("mutation-1".to_string()),
                    },
                },
                named_capability("ModelAdapt"),
            ),
        ];
        let policy = ACSPolicy::strict_default(1_000);

        for (idx, (payload, capability)) in cases.into_iter().enumerate() {
            let input = ACSAdmissionInput {
                request_id: format!("req-l2-missing-evidence-{idx}"),
                payload,
                submitted_at_ms: 1_001,
                risk,
                granted_capabilities: vec![capability],
            };
            let mut audit_log = Vec::new();

            let decision = admit_and_log(&input, &policy, 1_001, &mut audit_log);

            assert_eq!(decision.verdict, ACSAdmissionVerdict::Reject);
            assert_eq!(decision.audit_record.reason, "missing_l2_evidence");
            assert_eq!(audit_log.len(), 1);
            assert!(decision.audit_record.validate().is_ok());
        }
    }

    #[test]
    fn acs_admission_l2_requires_canonical_capability_even_when_policy_omits_rule() {
        let cases = [
            (
                ACSAdmissionPayload::KernelPromotion {
                    request: ACSKernelPromotionRequest {
                        kernel_id: "kernel-1".to_string(),
                        signed_plan_hash: "plan-hash".to_string(),
                        mutation_envelope_id: Some("mutation-1".to_string()),
                    },
                },
                named_capability("KernelPromote"),
            ),
            (
                ACSAdmissionPayload::ModelAdaptation {
                    request: ACSModelAdaptationRequest {
                        adapter_id: "adapter-1".to_string(),
                        model_id: "local-helper-1".to_string(),
                        checkpoint_hash: "checkpoint-hash".to_string(),
                        mutation_envelope_id: Some("mutation-1".to_string()),
                    },
                },
                named_capability("ModelAdapt"),
            ),
        ];
        let policy = ACSPolicy::strict("policy-l2-omits-capability", 1_000);

        for (idx, (payload, required_capability)) in cases.into_iter().enumerate() {
            let input = ACSAdmissionInput {
                request_id: format!("req-l2-omits-capability-{idx}"),
                payload,
                submitted_at_ms: 1_001,
                risk: ACSRiskVector::neutral(),
                granted_capabilities: Vec::new(),
            };
            let mut audit_log = Vec::new();

            let decision = admit_and_log(&input, &policy, 1_001, &mut audit_log);

            assert_eq!(decision.verdict, ACSAdmissionVerdict::Reject);
            assert_eq!(decision.audit_record.reason, "missing_capability");
            assert_eq!(audit_log.len(), 1);

            let admitted = ACSAdmissionInput {
                request_id: format!("req-l2-canonical-capability-{idx}"),
                payload: input.payload,
                submitted_at_ms: 1_001,
                risk: ACSRiskVector::neutral(),
                granted_capabilities: vec![required_capability],
            };
            let mut admitted_log = Vec::new();

            let admitted_decision = admit_and_log(&admitted, &policy, 1_001, &mut admitted_log);

            assert_eq!(admitted_decision.verdict, ACSAdmissionVerdict::Allow);
            assert_eq!(admitted_log.len(), 1);
        }
    }

    #[test]
    fn acs_admission_malformed_active_assembly_rejects_and_logs() {
        let input = ACSAdmissionInput {
            request_id: "req-bad-assembly".to_string(),
            payload: ACSAdmissionPayload::ActiveAssemblyPacket {
                packet: ActiveAssemblyPacket {
                    assembly_id: "assembly-1".to_string(),
                    active_support_ids: Vec::new(),
                    witness_hash: "witness-hash".to_string(),
                },
            },
            submitted_at_ms: 1_001,
            risk: ACSRiskVector::neutral(),
            granted_capabilities: Vec::new(),
        };
        let policy = ACSPolicy::strict("policy-bad-assembly", 1_000);
        let mut audit_log = Vec::new();

        let decision = admit_and_log(&input, &policy, 1_001, &mut audit_log);

        assert_eq!(decision.verdict, ACSAdmissionVerdict::Reject);
        assert_eq!(decision.audit_record.reason, "forged_admission_input");
        assert_eq!(audit_log.len(), 1);
    }

    #[test]
    fn acs_admission_malformed_active_assembly_support_id_rejects_and_logs() {
        let input = ACSAdmissionInput {
            request_id: "req-bad-assembly-support".to_string(),
            payload: ACSAdmissionPayload::ActiveAssemblyPacket {
                packet: ActiveAssemblyPacket {
                    assembly_id: "assembly-1".to_string(),
                    active_support_ids: vec![" note-1".to_string()],
                    witness_hash: "witness-hash".to_string(),
                },
            },
            submitted_at_ms: 1_001,
            risk: ACSRiskVector::neutral(),
            granted_capabilities: Vec::new(),
        };
        let policy = ACSPolicy::strict("policy-bad-assembly-support", 1_000);
        let mut audit_log = Vec::new();

        let decision = admit_and_log(&input, &policy, 1_001, &mut audit_log);

        assert_eq!(decision.verdict, ACSAdmissionVerdict::Reject);
        assert_eq!(decision.audit_record.reason, "forged_admission_input");
        assert_eq!(audit_log.len(), 1);
    }

    #[test]
    fn acs_admission_boundary_space_required_payload_field_is_forged_input() {
        let input = ACSAdmissionInput {
            request_id: "req-space-tool-name".to_string(),
            payload: ACSAdmissionPayload::ToolAction {
                request: ACSToolActionRequest {
                    tool_name: " vault.write".to_string(),
                    target: "uas://note/1".to_string(),
                    mutation_envelope_id: Some("mutation-1".to_string()),
                },
            },
            submitted_at_ms: 1_001,
            risk: ACSRiskVector::neutral(),
            granted_capabilities: Vec::new(),
        };
        let policy = ACSPolicy::strict("policy-space-tool-name", 1_000);
        let mut audit_log = Vec::new();

        let decision = admit_and_log(&input, &policy, 1_001, &mut audit_log);

        assert_eq!(decision.verdict, ACSAdmissionVerdict::Reject);
        assert_eq!(decision.audit_record.reason, "forged_admission_input");
        assert_eq!(audit_log.len(), 1);
    }

    #[test]
    fn acs_admission_answer_packet_requires_mutation_reference() {
        let input = ACSAdmissionInput {
            request_id: "req-answer-packet".to_string(),
            payload: ACSAdmissionPayload::AnswerPacket {
                packet: Box::new(AnswerPacket::new(
                    AnswerPacketId::new("answer-1"),
                    WitnessedStateId::new("state-1"),
                    MutationEnvelopeId::new("  "),
                )),
            },
            submitted_at_ms: 1_001,
            risk: ACSRiskVector::neutral(),
            granted_capabilities: Vec::new(),
        };
        let policy = ACSPolicy::strict("policy-answer-packet", 1_000);
        let mut audit_log = Vec::new();

        let decision = admit_and_log(&input, &policy, 1_001, &mut audit_log);

        assert_eq!(decision.verdict, ACSAdmissionVerdict::Reject);
        assert_eq!(decision.audit_record.reason, "forged_admission_input");
        assert_eq!(audit_log.len(), 1);
    }

    #[test]
    fn acs_admission_answer_packet_requires_witnessed_state_reference() {
        let input = ACSAdmissionInput {
            request_id: "req-answer-packet-witness".to_string(),
            payload: ACSAdmissionPayload::AnswerPacket {
                packet: Box::new(AnswerPacket::new(
                    AnswerPacketId::new("answer-1"),
                    WitnessedStateId::new(" state-1"),
                    MutationEnvelopeId::new("mutation-1"),
                )),
            },
            submitted_at_ms: 1_001,
            risk: ACSRiskVector::neutral(),
            granted_capabilities: Vec::new(),
        };
        let policy = ACSPolicy::strict("policy-answer-packet-witness", 1_000);
        let mut audit_log = Vec::new();

        let decision = admit_and_log(&input, &policy, 1_001, &mut audit_log);

        assert_eq!(decision.verdict, ACSAdmissionVerdict::Reject);
        assert_eq!(decision.audit_record.reason, "forged_admission_input");
        assert_eq!(audit_log.len(), 1);
    }

    #[test]
    fn acs_admission_answer_packet_rejects_boundary_spaced_semantic_delta_ref() {
        let input = ACSAdmissionInput {
            request_id: "req-answer-packet-semantic-delta".to_string(),
            payload: ACSAdmissionPayload::AnswerPacket {
                packet: Box::new(
                    AnswerPacket::new(
                        AnswerPacketId::new("answer-1"),
                        WitnessedStateId::new("state-1"),
                        MutationEnvelopeId::new("mutation-1"),
                    )
                    .with_semantic_delta(SemanticDeltaId::new(" semantic-delta-1")),
                ),
            },
            submitted_at_ms: 1_001,
            risk: ACSRiskVector::neutral(),
            granted_capabilities: Vec::new(),
        };
        let policy = ACSPolicy::strict("policy-answer-packet-semantic-delta", 1_000);
        let mut audit_log = Vec::new();

        let decision = admit_and_log(&input, &policy, 1_001, &mut audit_log);

        assert_eq!(decision.verdict, ACSAdmissionVerdict::Reject);
        assert_eq!(decision.audit_record.reason, "forged_admission_input");
        assert_eq!(audit_log.len(), 1);
    }

    #[test]
    fn acs_admission_answer_packet_rejects_unacknowledged_static_fallback() {
        let packet = AnswerPacket::new(
            AnswerPacketId::new("answer-1"),
            WitnessedStateId::new("state-1"),
            MutationEnvelopeId::new("mutation-1"),
        )
        .with_attention_mode(AttentionMode::StaticFallback);
        let value = serde_json::json!({
            "kind": "answer_packet",
            "packet": packet,
        });

        assert!(serde_json::from_value::<ACSAdmissionPayload>(value).is_err());
    }

    #[test]
    fn acs_admission_answer_packet_rejects_retracted_static_fallback_acknowledgement() {
        let value = serde_json::json!({
            "kind": "answer_packet",
            "packet": {
                "id": "answer-1",
                "claims": [{
                    "id": "claim-1",
                    "text": "static fallback acknowledged",
                    "status": "retracted",
                    "created_at_ms": 1_001,
                    "kind": "static_fallback_acknowledged"
                }],
                "residency_signals": [],
                "ui_label": "plausible_but_unverified",
                "attention_mode": "static_fallback",
                "witnessed_state_ref": "state-1",
                "semantic_delta_ref": null,
                "mutation_envelope_ref": "mutation-1"
            }
        });

        assert!(serde_json::from_value::<ACSAdmissionPayload>(value).is_err());
    }

    #[test]
    fn acs_admission_answer_packet_rejects_shadow_claim_fields() {
        let value = serde_json::json!({
            "kind": "answer_packet",
            "packet": {
                "id": "answer-1",
                "claims": [{
                    "id": "claim-1",
                    "text": "verified claim",
                    "status": "active",
                    "created_at_ms": 1_001,
                    "kind": "code_invariant",
                    "shadow_kind": "speculative"
                }],
                "residency_signals": [],
                "ui_label": "verified",
                "attention_mode": "dynamic",
                "witnessed_state_ref": "state-1",
                "semantic_delta_ref": null,
                "mutation_envelope_ref": "mutation-1"
            }
        });

        assert!(serde_json::from_value::<ACSAdmissionPayload>(value).is_err());
    }

    #[test]
    fn acs_admission_answer_packet_rejects_boundary_spaced_claim_id() {
        let value = serde_json::json!({
            "kind": "answer_packet",
            "packet": {
                "id": "answer-1",
                "claims": [{
                    "id": " claim-1",
                    "text": "verified claim",
                    "status": "active",
                    "created_at_ms": 1_001,
                    "kind": "code_invariant"
                }],
                "residency_signals": [],
                "ui_label": "verified",
                "attention_mode": "dynamic",
                "witnessed_state_ref": "state-1",
                "semantic_delta_ref": null,
                "mutation_envelope_ref": "mutation-1"
            }
        });

        assert!(serde_json::from_value::<ACSAdmissionPayload>(value).is_err());
    }

    #[test]
    fn acs_admission_answer_packet_rejects_duplicate_claim_ids() {
        let value = serde_json::json!({
            "kind": "answer_packet",
            "packet": {
                "id": "answer-1",
                "claims": [
                    {
                        "id": "claim-1",
                        "text": "verified claim",
                        "status": "active",
                        "created_at_ms": 1_001,
                        "kind": "code_invariant"
                    },
                    {
                        "id": "claim-1",
                        "text": "contradictory claim",
                        "status": "active",
                        "created_at_ms": 1_002,
                        "kind": "speculative"
                    }
                ],
                "residency_signals": [],
                "ui_label": "verified",
                "attention_mode": "dynamic",
                "witnessed_state_ref": "state-1",
                "semantic_delta_ref": null,
                "mutation_envelope_ref": "mutation-1"
            }
        });

        assert!(serde_json::from_value::<ACSAdmissionPayload>(value).is_err());
    }

    #[test]
    fn acs_admission_answer_packet_rejects_verified_label_without_verifying_claim() {
        let value = serde_json::json!({
            "kind": "answer_packet",
            "packet": {
                "id": "answer-1",
                "claims": [{
                    "id": "claim-1",
                    "text": "unverified hypothesis",
                    "status": "active",
                    "created_at_ms": 1_001,
                    "kind": "speculative"
                }],
                "residency_signals": [],
                "ui_label": "verified",
                "attention_mode": "dynamic",
                "witnessed_state_ref": "state-1",
                "semantic_delta_ref": null,
                "mutation_envelope_ref": "mutation-1"
            }
        });

        assert!(serde_json::from_value::<ACSAdmissionPayload>(value).is_err());
    }

    #[test]
    fn acs_admission_answer_packet_rejects_verified_label_with_retracted_basis() {
        let value = serde_json::json!({
            "kind": "answer_packet",
            "packet": {
                "id": "answer-1",
                "claims": [{
                    "id": "claim-1",
                    "text": "verified by test",
                    "status": "retracted",
                    "created_at_ms": 1_001,
                    "kind": "code_invariant"
                }],
                "residency_signals": [],
                "ui_label": "verified",
                "attention_mode": "dynamic",
                "witnessed_state_ref": "state-1",
                "semantic_delta_ref": null,
                "mutation_envelope_ref": "mutation-1"
            }
        });

        assert!(serde_json::from_value::<ACSAdmissionPayload>(value).is_err());
    }

    #[test]
    fn acs_admission_answer_packet_rejects_verified_label_with_refuted_claim() {
        let value = serde_json::json!({
            "kind": "answer_packet",
            "packet": {
                "id": "answer-1",
                "claims": [
                    {
                        "id": "claim-1",
                        "text": "verified by test",
                        "status": "active",
                        "created_at_ms": 1_001,
                        "kind": "code_invariant"
                    },
                    {
                        "id": "claim-2",
                        "text": "refuted empirical basis",
                        "status": "retracted",
                        "created_at_ms": 1_002,
                        "kind": "empirical"
                    }
                ],
                "residency_signals": [],
                "ui_label": "verified",
                "attention_mode": "dynamic",
                "witnessed_state_ref": "state-1",
                "semantic_delta_ref": null,
                "mutation_envelope_ref": "mutation-1"
            }
        });

        assert!(serde_json::from_value::<ACSAdmissionPayload>(value).is_err());
    }

    #[test]
    fn acs_admission_answer_packet_rejects_verified_label_with_retracted_causal_claim() {
        let value = serde_json::json!({
            "kind": "answer_packet",
            "packet": {
                "id": "answer-1",
                "claims": [
                    {
                        "id": "claim-1",
                        "text": "verified by test",
                        "status": "active",
                        "created_at_ms": 1_001,
                        "kind": "code_invariant"
                    },
                    {
                        "id": "claim-2",
                        "text": "stale causal support",
                        "status": "retracted",
                        "created_at_ms": 1_002,
                        "kind": "causal"
                    }
                ],
                "residency_signals": [],
                "ui_label": "verified",
                "attention_mode": "dynamic",
                "witnessed_state_ref": "state-1",
                "semantic_delta_ref": null,
                "mutation_envelope_ref": "mutation-1"
            }
        });

        assert!(serde_json::from_value::<ACSAdmissionPayload>(value).is_err());
    }

    #[test]
    fn acs_admission_answer_packet_rejects_verified_label_with_active_speculative_claim() {
        let value = serde_json::json!({
            "kind": "answer_packet",
            "packet": {
                "id": "answer-1",
                "claims": [
                    {
                        "id": "claim-1",
                        "text": "verified by test",
                        "status": "active",
                        "created_at_ms": 1_001,
                        "kind": "code_invariant"
                    },
                    {
                        "id": "claim-2",
                        "text": "unverified hypothesis in the same answer",
                        "status": "active",
                        "created_at_ms": 1_002,
                        "kind": "speculative"
                    }
                ],
                "residency_signals": [],
                "ui_label": "verified",
                "attention_mode": "dynamic",
                "witnessed_state_ref": "state-1",
                "semantic_delta_ref": null,
                "mutation_envelope_ref": "mutation-1"
            }
        });

        assert!(serde_json::from_value::<ACSAdmissionPayload>(value).is_err());
    }

    #[test]
    fn acs_admission_answer_packet_rejects_verified_label_with_quarantine_signal() {
        let value = serde_json::json!({
            "kind": "answer_packet",
            "packet": {
                "id": "answer-1",
                "claims": [{
                    "id": "claim-1",
                    "text": "verified by test",
                    "status": "active",
                    "created_at_ms": 1_001,
                    "kind": "code_invariant"
                }],
                "residency_signals": [{
                    "safety_risk": 0.71,
                    "privacy": 0.0,
                    "verification_score": 1.0,
                    "repeat_count": 3,
                    "gain": 0.0,
                    "forgetting": 0.0
                }],
                "ui_label": "verified",
                "attention_mode": "dynamic",
                "witnessed_state_ref": "state-1",
                "semantic_delta_ref": null,
                "mutation_envelope_ref": "mutation-1"
            }
        });

        assert!(serde_json::from_value::<ACSAdmissionPayload>(value).is_err());
    }

    #[test]
    fn acs_admission_answer_packet_rejects_verified_label_with_unverified_signal() {
        let value = serde_json::json!({
            "kind": "answer_packet",
            "packet": {
                "id": "answer-1",
                "claims": [{
                    "id": "claim-1",
                    "text": "verified by test",
                    "status": "active",
                    "created_at_ms": 1_001,
                    "kind": "code_invariant"
                }],
                "residency_signals": [{
                    "safety_risk": 0.0,
                    "privacy": 0.0,
                    "verification_score": 0.49,
                    "repeat_count": 3,
                    "gain": 0.0,
                    "forgetting": 0.0
                }],
                "ui_label": "verified",
                "attention_mode": "dynamic",
                "witnessed_state_ref": "state-1",
                "semantic_delta_ref": null,
                "mutation_envelope_ref": "mutation-1"
            }
        });

        assert!(serde_json::from_value::<ACSAdmissionPayload>(value).is_err());
    }

    #[test]
    fn acs_admission_answer_packet_rejects_blocked_label_without_gate_signal() {
        let value = serde_json::json!({
            "kind": "answer_packet",
            "packet": {
                "id": "answer-1",
                "claims": [{
                    "id": "claim-1",
                    "text": "safe claim",
                    "status": "active",
                    "created_at_ms": 1_001,
                    "kind": "code_invariant"
                }],
                "residency_signals": [{
                    "safety_risk": 0.0,
                    "privacy": 0.0,
                    "verification_score": 1.0,
                    "repeat_count": 3,
                    "gain": 0.0,
                    "forgetting": 0.0
                }],
                "ui_label": "blocked",
                "attention_mode": "dynamic",
                "witnessed_state_ref": "state-1",
                "semantic_delta_ref": null,
                "mutation_envelope_ref": "mutation-1"
            }
        });

        assert!(serde_json::from_value::<ACSAdmissionPayload>(value).is_err());
    }

    #[test]
    fn acs_admission_answer_packet_rejects_blocked_label_with_positive_claim() {
        let value = serde_json::json!({
            "kind": "answer_packet",
            "packet": {
                "id": "answer-1",
                "claims": [{
                    "id": "claim-1",
                    "text": "blocked output still asserts a verified fact",
                    "status": "active",
                    "created_at_ms": 1_001,
                    "kind": "code_invariant"
                }],
                "residency_signals": [{
                    "safety_risk": 0.71,
                    "privacy": 0.0,
                    "verification_score": 1.0,
                    "repeat_count": 3,
                    "gain": 0.0,
                    "forgetting": 0.0
                }],
                "ui_label": "blocked",
                "attention_mode": "dynamic",
                "witnessed_state_ref": "state-1",
                "semantic_delta_ref": null,
                "mutation_envelope_ref": "mutation-1"
            }
        });

        assert!(serde_json::from_value::<ACSAdmissionPayload>(value).is_err());
    }

    #[test]
    fn acs_admission_answer_packet_rejects_nonblocked_label_with_quarantine_signal() {
        let value = serde_json::json!({
            "kind": "answer_packet",
            "packet": {
                "id": "answer-1",
                "claims": [{
                    "id": "claim-1",
                    "text": "causal claim behind a safety gate",
                    "status": "active",
                    "created_at_ms": 1_001,
                    "kind": "causal"
                }],
                "residency_signals": [{
                    "safety_risk": 0.71,
                    "privacy": 0.0,
                    "verification_score": 1.0,
                    "repeat_count": 3,
                    "gain": 0.0,
                    "forgetting": 0.0
                }],
                "ui_label": "plausible_but_unverified",
                "attention_mode": "dynamic",
                "witnessed_state_ref": "state-1",
                "semantic_delta_ref": null,
                "mutation_envelope_ref": "mutation-1"
            }
        });

        assert!(serde_json::from_value::<ACSAdmissionPayload>(value).is_err());
    }

    #[test]
    fn acs_admission_answer_packet_rejects_speculative_label_without_speculative_claim() {
        let value = serde_json::json!({
            "kind": "answer_packet",
            "packet": {
                "id": "answer-1",
                "claims": [{
                    "id": "claim-1",
                    "text": "causal but not speculative",
                    "status": "active",
                    "created_at_ms": 1_001,
                    "kind": "causal"
                }],
                "residency_signals": [],
                "ui_label": "speculative",
                "attention_mode": "dynamic",
                "witnessed_state_ref": "state-1",
                "semantic_delta_ref": null,
                "mutation_envelope_ref": "mutation-1"
            }
        });

        assert!(serde_json::from_value::<ACSAdmissionPayload>(value).is_err());
    }

    #[test]
    fn acs_admission_answer_packet_rejects_speculative_label_with_non_speculative_claim() {
        let value = serde_json::json!({
            "kind": "answer_packet",
            "packet": {
                "id": "answer-1",
                "claims": [
                    {
                        "id": "claim-1",
                        "text": "unverified conjecture",
                        "status": "active",
                        "created_at_ms": 1_001,
                        "kind": "speculative"
                    },
                    {
                        "id": "claim-2",
                        "text": "causal but not speculative",
                        "status": "active",
                        "created_at_ms": 1_002,
                        "kind": "causal"
                    }
                ],
                "residency_signals": [],
                "ui_label": "speculative",
                "attention_mode": "dynamic",
                "witnessed_state_ref": "state-1",
                "semantic_delta_ref": null,
                "mutation_envelope_ref": "mutation-1"
            }
        });

        assert!(serde_json::from_value::<ACSAdmissionPayload>(value).is_err());
    }

    #[test]
    fn acs_admission_answer_packet_rejects_speculative_label_with_refuted_empirical_claim() {
        let value = serde_json::json!({
            "kind": "answer_packet",
            "packet": {
                "id": "answer-1",
                "claims": [
                    {
                        "id": "claim-1",
                        "text": "unverified conjecture",
                        "status": "active",
                        "created_at_ms": 1_001,
                        "kind": "speculative"
                    },
                    {
                        "id": "claim-2",
                        "text": "refuted empirical basis",
                        "status": "retracted",
                        "created_at_ms": 1_002,
                        "kind": "empirical"
                    }
                ],
                "residency_signals": [],
                "ui_label": "speculative",
                "attention_mode": "dynamic",
                "witnessed_state_ref": "state-1",
                "semantic_delta_ref": null,
                "mutation_envelope_ref": "mutation-1"
            }
        });

        assert!(serde_json::from_value::<ACSAdmissionPayload>(value).is_err());
    }

    #[test]
    fn acs_admission_answer_packet_rejects_speculative_label_with_retracted_speculative_claim() {
        let value = serde_json::json!({
            "kind": "answer_packet",
            "packet": {
                "id": "answer-1",
                "claims": [
                    {
                        "id": "claim-1",
                        "text": "active conjecture",
                        "status": "active",
                        "created_at_ms": 1_001,
                        "kind": "speculative"
                    },
                    {
                        "id": "claim-2",
                        "text": "stale conjecture",
                        "status": "retracted",
                        "created_at_ms": 1_002,
                        "kind": "speculative"
                    }
                ],
                "residency_signals": [],
                "ui_label": "speculative",
                "attention_mode": "dynamic",
                "witnessed_state_ref": "state-1",
                "semantic_delta_ref": null,
                "mutation_envelope_ref": "mutation-1"
            }
        });

        assert!(serde_json::from_value::<ACSAdmissionPayload>(value).is_err());
    }

    #[test]
    fn acs_admission_answer_packet_rejects_plausible_label_with_only_speculative_claims() {
        let value = serde_json::json!({
            "kind": "answer_packet",
            "packet": {
                "id": "answer-1",
                "claims": [{
                    "id": "claim-1",
                    "text": "unverified conjecture",
                    "status": "active",
                    "created_at_ms": 1_001,
                    "kind": "speculative"
                }],
                "residency_signals": [],
                "ui_label": "plausible_but_unverified",
                "attention_mode": "dynamic",
                "witnessed_state_ref": "state-1",
                "semantic_delta_ref": null,
                "mutation_envelope_ref": "mutation-1"
            }
        });

        assert!(serde_json::from_value::<ACSAdmissionPayload>(value).is_err());
    }

    #[test]
    fn acs_admission_answer_packet_rejects_plausible_label_without_plausible_claim() {
        let value = serde_json::json!({
            "kind": "answer_packet",
            "packet": {
                "id": "answer-1",
                "claims": [],
                "residency_signals": [],
                "ui_label": "plausible_but_unverified",
                "attention_mode": "dynamic",
                "witnessed_state_ref": "state-1",
                "semantic_delta_ref": null,
                "mutation_envelope_ref": "mutation-1"
            }
        });

        assert!(serde_json::from_value::<ACSAdmissionPayload>(value).is_err());
    }

    #[test]
    fn acs_admission_answer_packet_rejects_plausible_label_with_refuted_empirical_claim() {
        let value = serde_json::json!({
            "kind": "answer_packet",
            "packet": {
                "id": "answer-1",
                "claims": [
                    {
                        "id": "claim-1",
                        "text": "causal support",
                        "status": "active",
                        "created_at_ms": 1_001,
                        "kind": "causal"
                    },
                    {
                        "id": "claim-2",
                        "text": "refuted empirical basis",
                        "status": "retracted",
                        "created_at_ms": 1_002,
                        "kind": "empirical"
                    }
                ],
                "residency_signals": [],
                "ui_label": "plausible_but_unverified",
                "attention_mode": "dynamic",
                "witnessed_state_ref": "state-1",
                "semantic_delta_ref": null,
                "mutation_envelope_ref": "mutation-1"
            }
        });

        assert!(serde_json::from_value::<ACSAdmissionPayload>(value).is_err());
    }

    #[test]
    fn acs_admission_answer_packet_rejects_plausible_label_with_retracted_causal_claim() {
        let value = serde_json::json!({
            "kind": "answer_packet",
            "packet": {
                "id": "answer-1",
                "claims": [
                    {
                        "id": "claim-1",
                        "text": "empirical support",
                        "status": "active",
                        "created_at_ms": 1_001,
                        "kind": "empirical"
                    },
                    {
                        "id": "claim-2",
                        "text": "stale causal support",
                        "status": "retracted",
                        "created_at_ms": 1_002,
                        "kind": "causal"
                    }
                ],
                "residency_signals": [],
                "ui_label": "plausible_but_unverified",
                "attention_mode": "dynamic",
                "witnessed_state_ref": "state-1",
                "semantic_delta_ref": null,
                "mutation_envelope_ref": "mutation-1"
            }
        });

        assert!(serde_json::from_value::<ACSAdmissionPayload>(value).is_err());
    }

    #[test]
    fn acs_admission_answer_packet_rejects_plausible_label_with_retracted_code_invariant_claim() {
        let value = serde_json::json!({
            "kind": "answer_packet",
            "packet": {
                "id": "answer-1",
                "claims": [
                    {
                        "id": "claim-1",
                        "text": "empirical support",
                        "status": "active",
                        "created_at_ms": 1_001,
                        "kind": "empirical"
                    },
                    {
                        "id": "claim-2",
                        "text": "stale code invariant",
                        "status": "retracted",
                        "created_at_ms": 1_002,
                        "kind": "code_invariant"
                    }
                ],
                "residency_signals": [],
                "ui_label": "plausible_but_unverified",
                "attention_mode": "dynamic",
                "witnessed_state_ref": "state-1",
                "semantic_delta_ref": null,
                "mutation_envelope_ref": "mutation-1"
            }
        });

        assert!(serde_json::from_value::<ACSAdmissionPayload>(value).is_err());
    }

    #[test]
    fn acs_admission_answer_packet_rejects_plausible_label_with_code_invariant_claim() {
        let value = serde_json::json!({
            "kind": "answer_packet",
            "packet": {
                "id": "answer-1",
                "claims": [{
                    "id": "claim-1",
                    "text": "code path is invariant",
                    "status": "active",
                    "created_at_ms": 1_001,
                    "kind": "code_invariant"
                }],
                "residency_signals": [],
                "ui_label": "plausible_but_unverified",
                "attention_mode": "dynamic",
                "witnessed_state_ref": "state-1",
                "semantic_delta_ref": null,
                "mutation_envelope_ref": "mutation-1"
            }
        });

        assert!(serde_json::from_value::<ACSAdmissionPayload>(value).is_err());
    }

    #[test]
    fn acs_admission_answer_packet_rejects_nonfinite_residency_signal() {
        let input = ACSAdmissionInput {
            request_id: "req-answer-packet-residency".to_string(),
            payload: ACSAdmissionPayload::AnswerPacket {
                packet: Box::new(
                    AnswerPacket::new(
                        AnswerPacketId::new("answer-1"),
                        WitnessedStateId::new("state-1"),
                        MutationEnvelopeId::new("mutation-1"),
                    )
                    .push_residency_signal(ResidencySignal {
                        safety_risk: f32::NAN,
                        ..ResidencySignal::neutral()
                    }),
                ),
            },
            submitted_at_ms: 1_001,
            risk: ACSRiskVector::neutral(),
            granted_capabilities: Vec::new(),
        };
        let policy = ACSPolicy::strict("policy-answer-packet-residency", 1_000);
        let mut audit_log = Vec::new();

        let decision = admit_and_log(&input, &policy, 1_001, &mut audit_log);

        assert_eq!(decision.verdict, ACSAdmissionVerdict::Reject);
        assert_eq!(decision.audit_record.reason, "forged_admission_input");
        assert_eq!(audit_log.len(), 1);
    }

    #[test]
    fn acs_admission_answer_packet_rejects_out_of_range_residency_risk() {
        let input = ACSAdmissionInput {
            request_id: "req-answer-packet-residency-range".to_string(),
            payload: ACSAdmissionPayload::AnswerPacket {
                packet: Box::new(
                    AnswerPacket::new(
                        AnswerPacketId::new("answer-1"),
                        WitnessedStateId::new("state-1"),
                        MutationEnvelopeId::new("mutation-1"),
                    )
                    .push_residency_signal(ResidencySignal {
                        safety_risk: 1.01,
                        ..ResidencySignal::neutral()
                    }),
                ),
            },
            submitted_at_ms: 1_001,
            risk: ACSRiskVector::neutral(),
            granted_capabilities: Vec::new(),
        };
        let policy = ACSPolicy::strict("policy-answer-packet-residency-range", 1_000);
        let mut audit_log = Vec::new();

        let decision = admit_and_log(&input, &policy, 1_001, &mut audit_log);

        assert_eq!(decision.verdict, ACSAdmissionVerdict::Reject);
        assert_eq!(decision.audit_record.reason, "forged_admission_input");
        assert_eq!(audit_log.len(), 1);
    }

    #[test]
    fn acs_admission_mutation_envelope_requires_mutation_id() {
        let mut envelope = mutation_envelope_fixture();
        envelope.mutation_id = " ".to_string();
        let input = ACSAdmissionInput {
            request_id: "req-mutation-envelope".to_string(),
            payload: ACSAdmissionPayload::MutationEnvelope {
                envelope: Box::new(envelope),
            },
            submitted_at_ms: 1_001,
            risk: ACSRiskVector::neutral(),
            granted_capabilities: Vec::new(),
        };
        let policy = ACSPolicy::strict("policy-mutation-envelope", 1_000);
        let mut audit_log = Vec::new();

        let decision = admit_and_log(&input, &policy, 1_001, &mut audit_log);

        assert_eq!(decision.verdict, ACSAdmissionVerdict::Reject);
        assert_eq!(decision.audit_record.reason, "forged_admission_input");
        assert_eq!(audit_log.len(), 1);
    }

    #[test]
    fn acs_admission_model_adaptation_bypass_attempt_is_rejected() {
        for mutation_envelope_id in [
            None,
            Some(String::new()),
            Some("  ".to_string()),
            Some(" mutation-1".to_string()),
            Some("mutation-1 ".to_string()),
        ] {
            let input = ACSAdmissionInput {
                request_id: "req-model-adaptation".to_string(),
                payload: ACSAdmissionPayload::ModelAdaptation {
                    request: ACSModelAdaptationRequest {
                        adapter_id: "adapter-1".to_string(),
                        model_id: "local-helper-1".to_string(),
                        checkpoint_hash: "checkpoint-hash".to_string(),
                        mutation_envelope_id,
                    },
                },
                submitted_at_ms: 1_001,
                risk: ACSRiskVector::neutral(),
                granted_capabilities: Vec::new(),
            };
            let policy = ACSPolicy::strict("policy-model-adaptation", 1_000);
            let mut audit_log = Vec::new();

            let decision = admit_and_log(&input, &policy, 1_001, &mut audit_log);

            assert_eq!(decision.verdict, ACSAdmissionVerdict::Reject);
            assert_eq!(
                decision.audit_record.reason,
                "model_adaptation_bypass_attempt"
            );
            assert_eq!(audit_log.len(), 1);
        }
    }

    #[test]
    fn acs_admission_durable_commit_guard_requires_allowing_audit_record() {
        assert_eq!(
            guard_durable_commit(None).unwrap_err().cause(),
            "missing_acs_audit_record"
        );

        for verdict in [
            ACSAdmissionVerdict::Allow,
            ACSAdmissionVerdict::AllowWithWarning,
        ] {
            let record = audit_record_fixture(verdict);
            assert!(guard_durable_commit(Some(&record)).is_ok());
        }

        for verdict in [
            ACSAdmissionVerdict::Defer,
            ACSAdmissionVerdict::Quarantine,
            ACSAdmissionVerdict::Reject,
        ] {
            let record = audit_record_fixture(verdict);
            let err = guard_durable_commit(Some(&record)).unwrap_err();
            assert_eq!(err.cause(), "acs_verdict_blocks_durable_commit");
            assert_eq!(err.verdict(), Some(verdict));
            assert_eq!(err.record_id(), Some(record.record_id.as_str()));
        }
    }

    #[test]
    fn acs_admission_durable_commit_guard_rejects_corrupt_audit_record() {
        let mut record = audit_record_fixture(ACSAdmissionVerdict::Allow);
        record.risk_max = f32::NAN;

        let err = guard_durable_commit(Some(&record)).unwrap_err();

        assert_eq!(err.cause(), "corrupt_acs_audit_record");
        assert_eq!(err.field(), Some("risk_max"));
        assert_eq!(err.record_id(), Some(record.record_id.as_str()));
    }

    #[test]
    fn acs_admission_durable_commit_guard_rejects_l1_l2_audit_records() {
        for operation in [
            ACSOperationKind::ToolAction,
            ACSOperationKind::ActiveAssemblyPacket,
            ACSOperationKind::KernelPromotion,
            ACSOperationKind::ModelAdaptation,
        ] {
            let mut record = audit_record_fixture(ACSAdmissionVerdict::Allow);
            record.operation = operation;

            let err = guard_durable_commit(Some(&record)).unwrap_err();

            assert_eq!(err.cause(), "acs_operation_blocks_durable_commit");
            assert_eq!(err.field(), Some("operation"));
            assert_eq!(err.operation(), Some(operation));
            assert_eq!(err.lane(), Some(operation.lane()));
            assert_eq!(
                err.product_lane_code(),
                Some(operation.lane().product_lane_code())
            );
            assert_eq!(err.record_id(), Some(record.record_id.as_str()));
        }
    }

    #[test]
    fn acs_admission_durable_commit_guard_prioritizes_blocking_verdicts() {
        let mut record = audit_record_fixture(ACSAdmissionVerdict::Reject);
        record.operation = ACSOperationKind::ToolAction;

        let err = guard_durable_commit(Some(&record)).unwrap_err();

        assert_eq!(err.cause(), "acs_verdict_blocks_durable_commit");
        assert_eq!(err.verdict(), Some(ACSAdmissionVerdict::Reject));
        assert_eq!(err.operation(), None);
    }

    #[test]
    fn acs_admission_audit_record_rejects_blank_reason() {
        let mut record = audit_record_fixture(ACSAdmissionVerdict::Allow);
        record.reason = " ".to_string();

        let err = record.validate().unwrap_err();

        assert_eq!(err.cause(), "corrupt_acs_audit_record");
        assert_eq!(err.field(), "reason");
        assert_eq!(err.record_id(), Some(record.record_id.as_str()));
    }

    #[test]
    fn acs_admission_audit_record_rejects_noncanonical_reason() {
        let mut record = audit_record_fixture(ACSAdmissionVerdict::Reject);
        record.reason = "malformed policy".to_string();

        let err = record.validate().unwrap_err();

        assert_eq!(err.cause(), "corrupt_acs_audit_record");
        assert_eq!(err.field(), "reason");
    }

    #[test]
    fn acs_admission_audit_record_rejects_noncanonical_request_id() {
        let mut record = audit_record_fixture(ACSAdmissionVerdict::Allow);
        record.request_id = "req forged".to_string();

        let err = record.validate().unwrap_err();

        assert_eq!(err.cause(), "corrupt_acs_audit_record");
        assert_eq!(err.field(), "request_id");
    }

    #[test]
    fn acs_admission_audit_record_rejects_allowing_reserved_malformed_request_id() {
        let mut record = audit_record_fixture(ACSAdmissionVerdict::Allow);
        record.request_id = audit_request_id(" ");
        record.record_id = format!("acs:{}:{}", record.request_id, record.emitted_at_ms);

        let err = record.validate().unwrap_err();

        assert_eq!(err.cause(), "corrupt_acs_audit_record");
        assert_eq!(err.field(), "request_id");
    }

    #[test]
    fn acs_admission_audit_record_rejects_bare_malformed_request_sentinel() {
        let mut record = audit_record_fixture(ACSAdmissionVerdict::Reject);
        record.request_id = MALFORMED_REQUEST_AUDIT_PREFIX.to_string();
        record.record_id = format!("acs:{}:{}", record.request_id, record.emitted_at_ms);

        let err = record.validate().unwrap_err();

        assert_eq!(err.cause(), "corrupt_acs_audit_record");
        assert_eq!(err.field(), "request_id");
    }

    #[test]
    fn acs_admission_audit_record_rejects_malformed_policy_request_namespace() {
        let mut record = audit_record_fixture(ACSAdmissionVerdict::Reject);
        record.request_id = audit_policy_id(" ");
        record.record_id = format!("acs:{}:{}", record.request_id, record.emitted_at_ms);

        let err = record.validate().unwrap_err();

        assert_eq!(err.cause(), "corrupt_acs_audit_record");
        assert_eq!(err.field(), "request_id");
    }

    #[test]
    fn acs_admission_audit_record_rejects_noncanonical_policy_id() {
        let mut record = audit_record_fixture(ACSAdmissionVerdict::Allow);
        record.policy_id = "policy forged".to_string();

        let err = record.validate().unwrap_err();

        assert_eq!(err.cause(), "corrupt_acs_audit_record");
        assert_eq!(err.field(), "policy_id");
    }

    #[test]
    fn acs_admission_audit_record_rejects_allowing_reserved_malformed_policy_id() {
        let mut record = audit_record_fixture(ACSAdmissionVerdict::Allow);
        record.policy_id = audit_policy_id(" ");

        let err = record.validate().unwrap_err();

        assert_eq!(err.cause(), "corrupt_acs_audit_record");
        assert_eq!(err.field(), "policy_id");
    }

    #[test]
    fn acs_admission_audit_record_rejects_bare_malformed_policy_sentinel() {
        let mut record = audit_record_fixture(ACSAdmissionVerdict::Reject);
        record.policy_id = MALFORMED_POLICY_AUDIT_PREFIX.to_string();

        let err = record.validate().unwrap_err();

        assert_eq!(err.cause(), "corrupt_acs_audit_record");
        assert_eq!(err.field(), "policy_id");
    }

    #[test]
    fn acs_admission_audit_record_rejects_malformed_request_policy_namespace() {
        let mut record = audit_record_fixture(ACSAdmissionVerdict::Reject);
        record.policy_id = audit_request_id(" ");

        let err = record.validate().unwrap_err();

        assert_eq!(err.cause(), "corrupt_acs_audit_record");
        assert_eq!(err.field(), "policy_id");
    }

    #[test]
    fn acs_admission_audit_record_rejects_allowing_verdict_with_mismatched_reason() {
        let mut record = audit_record_fixture(ACSAdmissionVerdict::Allow);
        record.reason = "missing_capability".to_string();

        let err = guard_durable_commit(Some(&record)).unwrap_err();

        assert_eq!(err.cause(), "corrupt_acs_audit_record");
        assert_eq!(err.field(), Some("reason"));
    }

    #[test]
    fn acs_admission_audit_record_rejects_non_allowing_verdict_with_allowing_reason() {
        let mut record = audit_record_fixture(ACSAdmissionVerdict::Reject);
        record.reason = "allow".to_string();

        let err = record.validate().unwrap_err();

        assert_eq!(err.cause(), "corrupt_acs_audit_record");
        assert_eq!(err.field(), "reason");
    }

    #[test]
    fn acs_admission_audit_record_rejects_non_acs_record_id() {
        let mut record = audit_record_fixture(ACSAdmissionVerdict::Allow);
        record.record_id = "run-event:external-record".to_string();

        let err = record.validate().unwrap_err();

        assert_eq!(err.cause(), "corrupt_acs_audit_record");
        assert_eq!(err.field(), "record_id");
    }

    #[test]
    fn acs_admission_audit_record_rejects_noncanonical_record_id() {
        for record_id in ["acs: ", "acs:req", "acs:req:allow", "acs:req:allow "] {
            let mut record = audit_record_fixture(ACSAdmissionVerdict::Allow);
            record.record_id = record_id.to_string();

            let err = record.validate().unwrap_err();

            assert_eq!(err.cause(), "corrupt_acs_audit_record");
            assert_eq!(err.field(), "record_id");
        }

        for record_id in [
            "acs: ",
            "acs:req",
            "acs:req:allow",
            "acs:req:allow ",
            "acs:req:01001",
            "acs:req$:1001",
        ] {
            let err = SCOPERexAdmissionProof::new(
                ACSAdmissionVerdict::Allow,
                ACSOperationKind::MemoryWrite,
                AuditRecordId::new(record_id),
                CapabilitySignature::new("00".repeat(CAPABILITY_SIGNATURE_BYTES)),
            )
            .unwrap_err();

            assert_eq!(err.cause(), "invalid_audit_record_id");
            assert_eq!(err.field(), Some("record_id"));
        }
    }

    #[test]
    fn acs_admission_audit_record_rejects_request_record_id_mismatch() {
        let mut record = audit_record_fixture(ACSAdmissionVerdict::Allow);
        record.record_id = "acs:other:allow".to_string();

        let err = record.validate().unwrap_err();

        assert_eq!(err.cause(), "corrupt_acs_audit_record");
        assert_eq!(err.field(), "record_id");
    }

    #[test]
    fn acs_admission_audit_record_rejects_emitted_time_record_id_mismatch() {
        let mut record = audit_record_fixture(ACSAdmissionVerdict::Allow);
        record.record_id = "acs:req:1002".to_string();

        let err = record.validate().unwrap_err();

        assert_eq!(err.cause(), "corrupt_acs_audit_record");
        assert_eq!(err.field(), "record_id");
    }

    #[test]
    fn acs_admission_audit_record_rejects_negative_emitted_time() {
        let mut record = audit_record_fixture(ACSAdmissionVerdict::Allow);
        record.emitted_at_ms = -1;

        let err = record.validate().unwrap_err();

        assert_eq!(err.cause(), "corrupt_acs_audit_record");
        assert_eq!(err.field(), "emitted_at_ms");
    }

    #[derive(Default)]
    struct CountingSigningKey {
        sign_count: std::sync::atomic::AtomicUsize,
    }

    impl CountingSigningKey {
        fn sign_count(&self) -> usize {
            self.sign_count.load(std::sync::atomic::Ordering::Relaxed)
        }
    }

    impl SigningKey for CountingSigningKey {
        fn sign(&self, _payload: &[u8]) -> Vec<u8> {
            self.sign_count
                .fetch_add(1, std::sync::atomic::Ordering::Relaxed);
            vec![0; CAPABILITY_SIGNATURE_BYTES]
        }

        fn verify(&self, _payload: &[u8], _signature: &[u8]) -> bool {
            false
        }
    }

    fn tool_action_payload() -> ACSAdmissionPayload {
        ACSAdmissionPayload::ToolAction {
            request: ACSToolActionRequest {
                tool_name: "vault.write".to_string(),
                target: "uas://note/1".to_string(),
                mutation_envelope_id: Some("mutation-1".to_string()),
            },
        }
    }

    fn high_risk_operation_payload(operation: ACSOperationKind) -> ACSAdmissionPayload {
        match operation {
            ACSOperationKind::MemoryWrite => ACSAdmissionPayload::MemoryWrite {
                request: ACSMemoryWriteRequest {
                    address: "uas://note/1".to_string(),
                    content_hash: "content-hash".to_string(),
                    durable: false,
                    mutation_envelope_id: None,
                },
            },
            ACSOperationKind::ToolAction => tool_action_payload(),
            ACSOperationKind::ActiveAssemblyPacket => ACSAdmissionPayload::ActiveAssemblyPacket {
                packet: ActiveAssemblyPacket {
                    assembly_id: "assembly-1".to_string(),
                    active_support_ids: vec!["note-1".to_string()],
                    witness_hash: "witness-hash".to_string(),
                },
            },
            ACSOperationKind::KernelPromotion => ACSAdmissionPayload::KernelPromotion {
                request: ACSKernelPromotionRequest {
                    kernel_id: "kernel-1".to_string(),
                    signed_plan_hash: "plan-hash".to_string(),
                    mutation_envelope_id: Some("mutation-1".to_string()),
                },
            },
            ACSOperationKind::ModelAdaptation => ACSAdmissionPayload::ModelAdaptation {
                request: ACSModelAdaptationRequest {
                    adapter_id: "adapter-1".to_string(),
                    model_id: "local-helper-1".to_string(),
                    checkpoint_hash: "checkpoint-hash".to_string(),
                    mutation_envelope_id: Some("mutation-1".to_string()),
                },
            },
            ACSOperationKind::MutationEnvelope | ACSOperationKind::AnswerPacket => {
                panic!("test helper only supports shipped high-risk operations")
            }
        }
    }

    fn mutation_envelope_fixture() -> MutationEnvelope {
        MutationEnvelope::pending(
            "mutation-1".to_string(),
            1,
            MutationActor::User,
            SourceOp::ArtifactUpdate {
                artifact_id: "artifact-1".to_string(),
            },
            Sensitivity::Internal,
            Reversibility::Reversible,
            1_000,
        )
    }

    fn assert_mutation_envelope_payload_decode_rejects(envelope: MutationEnvelope) {
        let value = serde_json::json!({
            "kind": "mutation_envelope",
            "envelope": envelope,
        });

        assert!(serde_json::from_value::<ACSAdmissionPayload>(value).is_err());
    }

    fn audit_record_fixture(verdict: ACSAdmissionVerdict) -> ACSAuditRecord {
        ACSAuditRecord {
            record_id: "acs:req:1001".to_string(),
            request_id: "req".to_string(),
            policy_id: "policy".to_string(),
            policy_version: 1,
            operation: ACSOperationKind::MemoryWrite,
            verdict,
            reason: verdict.code().to_string(),
            risk_max: 0.0,
            emitted_at_ms: 1_001,
        }
    }

    #[test]
    fn acs_admission_shadow_audit_record_field_names_corrupt_acs_audit_record_field() {
        let mut value = serde_json::to_value(audit_record_fixture(ACSAdmissionVerdict::Allow))
            .expect("audit record encodes");
        value["shadow_record"] = serde_json::json!("smuggled");

        let err = serde_json::from_value::<ACSAuditRecord>(value).unwrap_err();
        let message = err.to_string();

        assert!(message.contains("corrupt_acs_audit_record"), "{message}");
        assert!(message.contains("shadow_record"), "{message}");
    }

    #[test]
    fn acs_admission_shadow_audit_record_field_names_audit_record_namespace() {
        let mut value = serde_json::to_value(audit_record_fixture(ACSAdmissionVerdict::Allow))
            .expect("audit record encodes");
        value["shadow_record"] = serde_json::json!("smuggled");

        let err = serde_json::from_value::<ACSAuditRecord>(value).unwrap_err();
        let message = err.to_string();

        assert!(message.contains("corrupt_acs_audit_record"), "{message}");
        assert!(message.contains("audit_record.shadow_record"), "{message}");
    }

    #[test]
    fn acs_admission_shadow_scope_rex_proof_field_names_malformed_acs_admission_proof_field() {
        let record = audit_record_fixture(ACSAdmissionVerdict::Allow);
        let signing_key = crate::effect::receipt::HmacSha256SigningKey::new([7; 32]);
        let proof = SCOPERexAdmissionProof::signed_from_record(&record, &signing_key)
            .expect("valid audit record signs");
        let mut value = serde_json::to_value(proof).expect("proof encodes");
        value["shadow_proof"] = serde_json::json!("smuggled");

        let err = serde_json::from_value::<SCOPERexAdmissionProof>(value).unwrap_err();
        let message = err.to_string();

        assert!(
            message.contains("malformed_acs_admission_proof"),
            "{message}"
        );
        assert!(message.contains("shadow_proof"), "{message}");
    }
}
