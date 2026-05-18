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
    scope_rex::answer_packet::AnswerPacket,
};

pub const ACS_AUDIT_RUN_EVENT_KEY: &str = "acs.audit.record";
const SCOPE_REX_ADMISSION_PROOF_DOMAIN: &[u8] = b"epistemos.acs.scope_rex_admission_proof.v1";
const CAPABILITY_SIGNATURE_BYTES: usize = 32;
const MUTATION_INTEGRITY_HASH_BYTES: usize = 32;

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
        let wire = ACSRiskVectorWire::deserialize(deserializer)?;
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
            .map_err(|err| serde::de::Error::custom(err.cause()))?;
        Ok(risk)
    }
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
    ACSOperationKind::AnswerPacket,
    ACSOperationKind::MemoryWrite,
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

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct ACSMutationEnvelopeWire {
    mutation_id: String,
    #[serde(default)]
    run_id: Option<String>,
    sequence: u64,
    #[serde(default)]
    caused_by_event_id: Option<String>,
    actor: MutationActor,
    #[serde(default)]
    approval_id: Option<String>,
    status: MutationStatus,
    created_at_ms: i64,
    #[serde(default)]
    committed_at_ms: Option<i64>,
    op: SourceOp,
    sensitivity: Sensitivity,
    reversibility: Reversibility,
    integrity_hash: String,
    schema_version: u32,
    #[serde(default)]
    touched_artifacts: Vec<ArtifactRef>,
    #[serde(default)]
    touched_blocks: Vec<BlockRef>,
    #[serde(default)]
    relation_changes: Vec<RelationChange>,
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
            actor: self.actor,
            approval_id: self.approval_id,
            status: self.status,
            created_at_ms: self.created_at_ms,
            committed_at_ms: self.committed_at_ms,
            op: self.op,
            sensitivity: self.sensitivity,
            reversibility: self.reversibility,
            integrity_hash: self.integrity_hash,
            schema_version: self.schema_version,
            touched_artifacts: self.touched_artifacts,
            touched_blocks: self.touched_blocks,
            relation_changes: self.relation_changes,
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
    MutationEnvelope { envelope: Box<ACSMutationEnvelopeWire> },
    ActiveAssemblyPacket { packet: ActiveAssemblyPacket },
    AnswerPacket { packet: Box<AnswerPacket> },
    MemoryWrite { request: ACSMemoryWriteRequest },
    ToolAction { request: ACSToolActionRequest },
    KernelPromotion { request: ACSKernelPromotionRequest },
    ModelAdaptation { request: ACSModelAdaptationRequest },
}

impl<'de> Deserialize<'de> for ACSAdmissionPayload {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: serde::Deserializer<'de>,
    {
        let wire = ACSAdmissionPayloadWire::deserialize(deserializer)?;
        let payload = match wire {
            ACSAdmissionPayloadWire::MutationEnvelope { envelope } => {
                Self::MutationEnvelope {
                    envelope: Box::new(envelope.into_envelope()),
                }
            }
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
            .map_err(|err| serde::de::Error::custom(err.cause()))?;
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

    fn validate(&self) -> Result<(), ACSAdmissionInputError> {
        match self {
            Self::MutationEnvelope { envelope } => validate_mutation_envelope(envelope),
            Self::ActiveAssemblyPacket { packet } => packet.validate(),
            Self::AnswerPacket { packet } => {
                require_non_empty(&packet.id.0, "answer_packet.id")?;
                require_non_empty(
                    &packet.witnessed_state_ref.0,
                    "answer_packet.witnessed_state_ref",
                )?;
                require_optional_non_empty(
                    packet.semantic_delta_ref.as_ref().map(|id| id.0.as_str()),
                    "answer_packet.semantic_delta_ref",
                )?;
                require_non_empty(
                    &packet.mutation_envelope_ref.0,
                    "answer_packet.mutation_envelope_ref",
                )
            }
            Self::MemoryWrite { request } => request.validate(),
            Self::ToolAction { request } => request.validate(),
            Self::KernelPromotion { request } => request.validate(),
            Self::ModelAdaptation { request } => request.validate(),
        }
    }
}

fn validate_mutation_envelope(envelope: &MutationEnvelope) -> Result<(), ACSAdmissionInputError> {
    require_non_empty(&envelope.mutation_id, "mutation_envelope.mutation_id")?;
    require_optional_non_empty(envelope.run_id.as_deref(), "mutation_envelope.run_id")?;
    require_optional_non_empty(
        envelope.caused_by_event_id.as_deref(),
        "mutation_envelope.caused_by_event_id",
    )?;
    require_optional_non_empty(envelope.approval_id.as_deref(), "mutation_envelope.approval_id")?;
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
    validate_mutation_source_op(&envelope.op)?;
    validate_mutation_touched_artifacts(&envelope.touched_artifacts)?;
    validate_mutation_touched_blocks(&envelope.touched_blocks)?;
    validate_mutation_relation_changes(&envelope.relation_changes)?;
    Ok(())
}

fn validate_mutation_touched_artifacts(
    artifacts: &[ArtifactRef],
) -> Result<(), ACSAdmissionInputError> {
    for artifact in artifacts {
        require_non_empty(
            &artifact.id,
            "mutation_envelope.touched_artifacts.artifact_id",
        )?;
    }
    Ok(())
}

fn validate_mutation_touched_blocks(blocks: &[BlockRef]) -> Result<(), ACSAdmissionInputError> {
    for block in blocks {
        require_non_empty(
            &block.artifact_id,
            "mutation_envelope.touched_blocks.artifact_id",
        )?;
        require_non_empty(&block.block_id, "mutation_envelope.touched_blocks.block_id")?;
    }
    Ok(())
}

fn validate_mutation_relation_changes(
    changes: &[RelationChange],
) -> Result<(), ACSAdmissionInputError> {
    for change in changes {
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
            }
        }
    }
    Ok(())
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
            .map_err(|err| serde::de::Error::custom(err.cause()))?;
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
        for support_id in &self.active_support_ids {
            require_non_empty(support_id, "active_assembly.active_support_ids")?;
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
    mutation_envelope_id: Option<String>,
}

impl<'de> Deserialize<'de> for ACSMemoryWriteRequest {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: serde::Deserializer<'de>,
    {
        let wire = ACSMemoryWriteRequestWire::deserialize(deserializer)?;
        let request = Self {
            address: wire.address,
            content_hash: wire.content_hash,
            durable: wire.durable,
            mutation_envelope_id: wire.mutation_envelope_id,
        };
        request
            .validate()
            .map_err(|err| serde::de::Error::custom(err.cause()))?;
        Ok(request)
    }
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
    mutation_envelope_id: Option<String>,
}

impl<'de> Deserialize<'de> for ACSToolActionRequest {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: serde::Deserializer<'de>,
    {
        let wire = ACSToolActionRequestWire::deserialize(deserializer)?;
        let request = Self {
            tool_name: wire.tool_name,
            target: wire.target,
            mutation_envelope_id: wire.mutation_envelope_id,
        };
        request
            .validate()
            .map_err(|err| serde::de::Error::custom(err.cause()))?;
        Ok(request)
    }
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
    mutation_envelope_id: Option<String>,
}

impl<'de> Deserialize<'de> for ACSKernelPromotionRequest {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: serde::Deserializer<'de>,
    {
        let wire = ACSKernelPromotionRequestWire::deserialize(deserializer)?;
        let request = Self {
            kernel_id: wire.kernel_id,
            signed_plan_hash: wire.signed_plan_hash,
            mutation_envelope_id: wire.mutation_envelope_id,
        };
        request
            .validate()
            .map_err(|err| serde::de::Error::custom(err.cause()))?;
        Ok(request)
    }
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
    mutation_envelope_id: Option<String>,
}

impl<'de> Deserialize<'de> for ACSModelAdaptationRequest {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: serde::Deserializer<'de>,
    {
        let wire = ACSModelAdaptationRequestWire::deserialize(deserializer)?;
        let request = Self {
            adapter_id: wire.adapter_id,
            model_id: wire.model_id,
            checkpoint_hash: wire.checkpoint_hash,
            mutation_envelope_id: wire.mutation_envelope_id,
        };
        request
            .validate()
            .map_err(|err| serde::de::Error::custom(err.cause()))?;
        Ok(request)
    }
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
        let wire = ACSAdmissionInputWire::deserialize(deserializer)?;
        let input = Self {
            request_id: wire.request_id,
            payload: wire.payload,
            submitted_at_ms: wire.submitted_at_ms,
            risk: wire.risk,
            granted_capabilities: wire.granted_capabilities,
        };
        input
            .validate()
            .map_err(|err| serde::de::Error::custom(err.cause()))?;
        Ok(input)
    }
}

impl ACSAdmissionInput {
    pub fn validate(&self) -> Result<(), ACSAdmissionInputError> {
        if !is_canonical_audit_token(&self.request_id) {
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
        let wire = ACSAuditRecordWire::deserialize(deserializer)?;
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
            .map_err(|err| serde::de::Error::custom(err.cause()))?;
        Ok(record)
    }
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
            return Err(ACSAuditRecordError::Corrupt { field: "record_id" });
        }
        if !is_canonical_acs_record_id(&self.record_id) {
            return Err(ACSAuditRecordError::Corrupt { field: "record_id" });
        }
        if !is_canonical_audit_token(&self.request_id) {
            return Err(ACSAuditRecordError::Corrupt {
                field: "request_id",
            });
        }
        if !is_canonical_audit_token(&self.policy_id) {
            return Err(ACSAuditRecordError::Corrupt { field: "policy_id" });
        }
        if self.policy_version == 0 {
            return Err(ACSAuditRecordError::Corrupt {
                field: "policy_version",
            });
        }
        if !is_canonical_audit_token(&self.reason) {
            return Err(ACSAuditRecordError::Corrupt { field: "reason" });
        }
        if self.verdict.allows_durable_commit() && self.reason != self.verdict.code() {
            return Err(ACSAuditRecordError::Corrupt { field: "reason" });
        }
        if !self.verdict.allows_durable_commit()
            && matches!(self.reason.as_str(), "allow" | "allow_with_warning")
        {
            return Err(ACSAuditRecordError::Corrupt { field: "reason" });
        }
        if !self.risk_max.is_finite() || !(0.0..=1.0).contains(&self.risk_max) {
            return Err(ACSAuditRecordError::Corrupt { field: "risk_max" });
        }
        if self.emitted_at_ms < 0 {
            return Err(ACSAuditRecordError::Corrupt {
                field: "emitted_at_ms",
            });
        }
        if !acs_record_id_binds_request_and_time(
            &self.record_id,
            &self.request_id,
            self.emitted_at_ms,
        ) {
            return Err(ACSAuditRecordError::Corrupt { field: "record_id" });
        }
        Ok(())
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ACSAuditRecordError {
    Corrupt { field: &'static str },
}

impl ACSAuditRecordError {
    pub const fn cause(&self) -> &'static str {
        match self {
            Self::Corrupt { .. } => "corrupt_acs_audit_record",
        }
    }

    pub const fn field(&self) -> &'static str {
        match self {
            Self::Corrupt { field } => field,
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
            Err(ACSAdmissionProofError::InvalidRecordId)
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
            .map_err(|err| serde::de::Error::custom(err.cause()))?;
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
            return Err(ACSAdmissionProofError::MissingCapabilitySignature);
        }
        if self.0 != self.0.trim()
            || self.0.len() != CAPABILITY_SIGNATURE_BYTES * 2
            || !self
                .0
                .bytes()
                .all(|byte| matches!(byte, b'0'..=b'9' | b'a'..=b'f'))
        {
            return Err(ACSAdmissionProofError::InvalidCapabilitySignature);
        }
        let Some(bytes) = hex_decode_signature(&self.0) else {
            return Err(ACSAdmissionProofError::InvalidCapabilitySignature);
        };
        if bytes.len() != CAPABILITY_SIGNATURE_BYTES {
            return Err(ACSAdmissionProofError::InvalidCapabilitySignature);
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
    record_id: AuditRecordId,
    signature: CapabilitySignature,
}

impl<'de> Deserialize<'de> for SCOPERexAdmissionProof {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: serde::Deserializer<'de>,
    {
        let wire = SCOPERexAdmissionProofWire::deserialize(deserializer)?;
        let proof = Self {
            verdict: wire.verdict,
            operation: wire.operation,
            record_id: wire.record_id,
            signature: wire.signature,
        };
        proof
            .validate()
            .map_err(|err| serde::de::Error::custom(err.cause()))?;
        Ok(proof)
    }
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
        self.record_id.validate()?;
        if !self.verdict.allows_durable_commit() {
            return Err(ACSAdmissionProofError::VerdictBlocksScopeRex);
        }
        self.signature.validate()
    }

    pub fn signed_from_record<K: SigningKey>(
        record: &ACSAuditRecord,
        key: &K,
    ) -> Result<Self, ACSAdmissionProofError> {
        record
            .validate()
            .map_err(|err| ACSAdmissionProofError::CorruptAuditRecord { field: err.field() })?;
        if !record.verdict.allows_durable_commit() {
            return Err(ACSAdmissionProofError::VerdictBlocksScopeRex);
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
            .map_err(|err| ACSAdmissionProofError::CorruptAuditRecord { field: err.field() })?;
        if self.record_id.0 != record.record_id {
            return Err(ACSAdmissionProofError::RecordIdMismatch);
        }
        if self.verdict != record.verdict {
            return Err(ACSAdmissionProofError::VerdictMismatch);
        }
        if self.operation != record.operation {
            return Err(ACSAdmissionProofError::OperationMismatch);
        }
        if !self.verify_signature(key) {
            return Err(ACSAdmissionProofError::InvalidCapabilitySignature);
        }
        Ok(())
    }

    pub fn verify_against_run_event_log<K: SigningKey>(
        &self,
        run_event_log: &OpLog,
        key: &K,
    ) -> Result<ACSAuditRecord, SCOPERexAdmissionProofVerificationError> {
        if !run_event_log.verify_chain(None).valid {
            return Err(SCOPERexAdmissionProofVerificationError::Lookup(
                ACSAuditLookupError::InvalidRunEventLogChain,
            ));
        }
        self.validate()
            .map_err(SCOPERexAdmissionProofVerificationError::Proof)?;
        let record = resolve_acs_audit_record(run_event_log, &self.record_id)
            .map_err(SCOPERexAdmissionProofVerificationError::Lookup)?;
        self.verify_against_record(&record, key)
            .map_err(SCOPERexAdmissionProofVerificationError::Proof)?;
        Ok(record)
    }

    pub fn from_record(
        record: &ACSAuditRecord,
        signature: CapabilitySignature,
    ) -> Result<Self, ACSAdmissionProofError> {
        record
            .validate()
            .map_err(|err| ACSAdmissionProofError::CorruptAuditRecord { field: err.field() })?;
        Self::new(
            record.verdict,
            record.operation,
            AuditRecordId::new(record.record_id.clone()),
            signature,
        )
    }
}

fn scope_rex_proof_payload(
    verdict: ACSAdmissionVerdict,
    operation: ACSOperationKind,
    record_id: &str,
) -> Vec<u8> {
    let mut payload =
        Vec::with_capacity(96 + SCOPE_REX_ADMISSION_PROOF_DOMAIN.len() + record_id.len());
    push_proof_field(
        &mut payload,
        b"domain",
        SCOPE_REX_ADMISSION_PROOF_DOMAIN,
    );
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

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ACSAdmissionProofError {
    MissingRecordId,
    InvalidRecordId,
    MissingCapabilitySignature,
    InvalidCapabilitySignature,
    VerdictBlocksScopeRex,
    RecordIdMismatch,
    OperationMismatch,
    VerdictMismatch,
    CorruptAuditRecord { field: &'static str },
}

impl ACSAdmissionProofError {
    pub const fn cause(&self) -> &'static str {
        match self {
            Self::MissingRecordId => "missing_audit_record_id",
            Self::InvalidRecordId => "invalid_audit_record_id",
            Self::MissingCapabilitySignature => "missing_capability_signature",
            Self::InvalidCapabilitySignature => "invalid_capability_signature",
            Self::VerdictBlocksScopeRex => "proof_verdict_blocks_scope_rex",
            Self::RecordIdMismatch => "proof_record_id_mismatch",
            Self::OperationMismatch => "proof_operation_mismatch",
            Self::VerdictMismatch => "proof_verdict_mismatch",
            Self::CorruptAuditRecord { .. } => "corrupt_acs_audit_record",
        }
    }

    pub const fn field(&self) -> Option<&'static str> {
        match self {
            Self::CorruptAuditRecord { field } => Some(field),
            Self::InvalidCapabilitySignature => Some("signature"),
            Self::VerdictBlocksScopeRex => Some("verdict"),
            Self::RecordIdMismatch => Some("record_id"),
            Self::OperationMismatch => Some("operation"),
            Self::VerdictMismatch => Some("verdict"),
            Self::MissingRecordId | Self::InvalidRecordId => Some("record_id"),
            Self::MissingCapabilitySignature => None,
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SCOPERexAdmissionProofVerificationError {
    Lookup(ACSAuditLookupError),
    Proof(ACSAdmissionProofError),
}

impl SCOPERexAdmissionProofVerificationError {
    pub const fn cause(&self) -> &'static str {
        match self {
            Self::Lookup(err) => err.cause(),
            Self::Proof(err) => err.cause(),
        }
    }

    pub const fn field(&self) -> Option<&'static str> {
        match self {
            Self::Lookup(err) => err.field(),
            Self::Proof(err) => err.field(),
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
        decision
            .validate()
            .map_err(serde::de::Error::custom)?;
        Ok(decision)
    }
}

impl ACSAdmissionDecision {
    fn validate(&self) -> Result<(), &'static str> {
        self.audit_record
            .validate()
            .map_err(|err| err.cause())?;
        if self.verdict != self.audit_record.verdict {
            return Err("mismatched_decision_verdict");
        }
        Ok(())
    }
}

pub trait ACSAuditSink {
    fn record(&self, record: ACSAuditRecord) -> Result<(), ACSAuditError>;
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ACSAuditError {
    SinkUnavailable,
    EncodeRecord,
    InvalidRunEventLogChain,
    DuplicateRecord,
    CorruptRecord { field: &'static str },
}

impl ACSAuditError {
    pub const fn cause(&self) -> &'static str {
        match self {
            Self::SinkUnavailable => "acs_audit_sink_unavailable",
            Self::EncodeRecord => "acs_audit_record_encode_failed",
            Self::InvalidRunEventLogChain => "invalid_run_event_log_chain",
            Self::DuplicateRecord => "duplicate_acs_audit_record",
            Self::CorruptRecord { .. } => "corrupt_acs_audit_record",
        }
    }

    pub const fn field(&self) -> Option<&'static str> {
        match self {
            Self::InvalidRunEventLogChain => Some("run_event_log"),
            Self::DuplicateRecord => Some("record_id"),
            Self::CorruptRecord { field } => Some(field),
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
        if !self.run_event_log.verify_chain(None).valid {
            return Err(ACSAuditError::InvalidRunEventLogChain);
        }
        record
            .validate()
            .map_err(|err| ACSAuditError::CorruptRecord { field: err.field() })?;
        let node_id = record.record_id.clone();
        if run_event_log_contains_acs_record(self.run_event_log, &node_id) {
            return Err(ACSAuditError::DuplicateRecord);
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

fn run_event_log_contains_acs_record(run_event_log: &OpLog, record_id: &str) -> bool {
    run_event_log
        .iter_all()
        .into_iter()
        .any(|op| match op.payload {
            OpPayload::PropSet { node_id, key, .. } => {
                node_id == record_id && key == ACS_AUDIT_RUN_EVENT_KEY
            }
            _ => false,
        })
}

pub fn resolve_acs_audit_record(
    run_event_log: &OpLog,
    record_id: &AuditRecordId,
) -> Result<ACSAuditRecord, ACSAuditLookupError> {
    if !run_event_log.verify_chain(None).valid {
        return Err(ACSAuditLookupError::InvalidRunEventLogChain);
    }
    record_id
        .validate()
        .map_err(|_| ACSAuditLookupError::InvalidRecordId)?;

    let mut resolved = None;
    for op in run_event_log.iter_all().into_iter().rev() {
        let OpPayload::PropSet {
            node_id,
            key,
            value,
        } = op.payload
        else {
            continue;
        };
        if node_id != record_id.0 || key != ACS_AUDIT_RUN_EVENT_KEY {
            continue;
        }
        if resolved.is_some() {
            return Err(ACSAuditLookupError::DuplicateRecord);
        }

        let record: ACSAuditRecord = serde_json::from_value(value)
            .map_err(|_| ACSAuditLookupError::CorruptRecord { field: "record" })?;
        record
            .validate()
            .map_err(|err| ACSAuditLookupError::CorruptRecord { field: err.field() })?;
        if record.record_id != record_id.0 {
            return Err(ACSAuditLookupError::CorruptRecord { field: "record_id" });
        }
        resolved = Some(record);
    }

    resolved.ok_or(ACSAuditLookupError::NotFound)
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ACSAuditLookupError {
    InvalidRecordId,
    InvalidRunEventLogChain,
    NotFound,
    DuplicateRecord,
    DecodeRecord,
    CorruptRecord { field: &'static str },
}

impl ACSAuditLookupError {
    pub const fn cause(&self) -> &'static str {
        match self {
            Self::InvalidRecordId => "invalid_audit_record_id",
            Self::InvalidRunEventLogChain => "invalid_run_event_log_chain",
            Self::NotFound => "acs_audit_record_not_found",
            Self::DuplicateRecord => "duplicate_acs_audit_record",
            Self::DecodeRecord => "acs_audit_record_decode_failed",
            Self::CorruptRecord { .. } => "corrupt_acs_audit_record",
        }
    }

    pub const fn field(&self) -> Option<&'static str> {
        match self {
            Self::InvalidRunEventLogChain => Some("run_event_log"),
            Self::InvalidRecordId | Self::NotFound | Self::DuplicateRecord => Some("record_id"),
            Self::DecodeRecord => Some("record"),
            Self::CorruptRecord { field } => Some(field),
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
        record
            .validate()
            .map_err(|err| ACSAuditError::CorruptRecord { field: err.field() })?;
        let mut records = self
            .records
            .lock()
            .map_err(|_| ACSAuditError::SinkUnavailable)?;
        if records
            .iter()
            .any(|existing| existing.record_id == record.record_id)
        {
            return Err(ACSAuditError::DuplicateRecord);
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

    if let Err(err) = policy.validate_at(now_ms) {
        return decision(
            input,
            policy,
            now_ms,
            ACSAdmissionVerdict::Reject,
            err.cause(),
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

    if policy
        .required_for(input.operation())
        .iter()
        .any(|capability| !input.granted_capabilities.contains(capability))
    {
        return decision(
            input,
            policy,
            now_ms,
            ACSAdmissionVerdict::Reject,
            "missing_capability",
        );
    }

    let verdict =
        ACSAdmissionVerdict::from_risk(&input.risk, policy.thresholds_for(input.operation()));
    decision(input, policy, now_ms, verdict, verdict.code())
}

pub fn guard_durable_commit(record: Option<&ACSAuditRecord>) -> Result<(), ACSDurableCommitError> {
    let record = record.ok_or(ACSDurableCommitError::MissingAuditRecord)?;
    record
        .validate()
        .map_err(|err| ACSDurableCommitError::CorruptAuditRecord { field: err.field() })?;
    if record.verdict.allows_durable_commit() {
        Ok(())
    } else {
        Err(ACSDurableCommitError::BlockedByVerdict {
            verdict: record.verdict,
        })
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ACSDurableCommitError {
    MissingAuditRecord,
    CorruptAuditRecord { field: &'static str },
    BlockedByVerdict { verdict: ACSAdmissionVerdict },
}

impl ACSDurableCommitError {
    pub const fn cause(&self) -> &'static str {
        match self {
            Self::MissingAuditRecord => "missing_acs_audit_record",
            Self::CorruptAuditRecord { .. } => "corrupt_acs_audit_record",
            Self::BlockedByVerdict { .. } => "acs_verdict_blocks_durable_commit",
        }
    }

    pub const fn field(&self) -> Option<&'static str> {
        match self {
            Self::CorruptAuditRecord { field } => Some(field),
            Self::MissingAuditRecord | Self::BlockedByVerdict { .. } => None,
        }
    }

    pub const fn verdict(&self) -> Option<ACSAdmissionVerdict> {
        match self {
            Self::BlockedByVerdict { verdict } => Some(*verdict),
            Self::MissingAuditRecord | Self::CorruptAuditRecord { .. } => None,
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
    if is_canonical_audit_token(value) {
        value.to_string()
    } else {
        "malformed_request".to_string()
    }
}

fn audit_policy_id(value: &str) -> String {
    if is_canonical_audit_token(value) {
        value.to_string()
    } else {
        "malformed_policy".to_string()
    }
}

fn audit_policy_version(value: u32) -> u32 {
    if value == 0 { 1 } else { value }
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
        let wire = ACSRiskThresholdsWire::deserialize(deserializer)?;
        let thresholds = Self {
            warn_at: wire.warn_at,
            defer_at: wire.defer_at,
            quarantine_at: wire.quarantine_at,
            reject_at: wire.reject_at,
        };
        thresholds
            .validate()
            .map_err(|err| serde::de::Error::custom(err.cause()))?;
        Ok(thresholds)
    }
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
        let wire = ACSCapabilityRuleWire::deserialize(deserializer)?;
        let rule = Self {
            operation: wire.operation,
            capability: wire.capability,
        };
        rule.validate()
            .map_err(|err| serde::de::Error::custom(err.cause()))?;
        Ok(rule)
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
            if *ttl_secs == 0 {
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
#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ACSOperationThresholdRule {
    pub operation: ACSOperationKind,
    pub thresholds: ACSRiskThresholds,
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
        let wire = ACSPolicyWire::deserialize(deserializer)?;
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
            .map_err(|err| serde::de::Error::custom(err.cause()))?;
        Ok(policy)
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
        if !is_canonical_audit_token(&self.policy_id) {
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
            if required_capabilities
                .iter()
                .any(|(operation, capability)| {
                    *operation == rule.operation && capability == &rule.capability
                })
            {
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
        self.required_capabilities
            .iter()
            .filter(|rule| rule.operation == operation)
            .map(|rule| rule.capability.clone())
            .collect()
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
        scope_rex::answer_packet::{
            AnswerPacketId, MutationEnvelopeId, SemanticDeltaId, WitnessedStateId,
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
                ACSOperationKind::AnswerPacket,
                ACSOperationKind::MemoryWrite,
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
        assert!(serde_json::from_value::<ACSPolicy>(value).is_err());
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
        assert_eq!(decision.audit_record.request_id, "malformed_request");
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
        assert_eq!(decision.audit_record.request_id, "malformed_request");
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
                packet: Box::new(AnswerPacket::new(
                    AnswerPacketId::new("answer-1"),
                    WitnessedStateId::new("state-1"),
                    MutationEnvelopeId::new("mutation-1"),
                )),
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

        assert!(serde_json::from_value::<ACSAdmissionPayload>(value).is_err());
    }

    #[test]
    fn acs_admission_payload_rejects_shadow_mutation_envelope_field_on_decode() {
        let mut envelope =
            serde_json::to_value(mutation_envelope_fixture()).expect("mutation envelope serializes");
        envelope["shadow_integrity_hash"] = serde_json::json!("hash-shadow");
        let value = serde_json::json!({
            "kind": "mutation_envelope",
            "envelope": envelope,
        });

        assert!(serde_json::from_value::<ACSAdmissionPayload>(value).is_err());
    }

    #[test]
    fn acs_admission_payload_rejects_boundary_spaced_mutation_hash_on_decode() {
        let mut envelope =
            serde_json::to_value(mutation_envelope_fixture()).expect("mutation envelope serializes");
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

        assert!(serde_json::from_value::<ACSMemoryWriteRequest>(value).is_err());
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
            "mutation_envelope_id": null,
        });

        assert!(serde_json::from_value::<ACSToolActionRequest>(value).is_err());
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
            "mutation_envelope_id": null,
        });

        assert!(serde_json::from_value::<ACSKernelPromotionRequest>(value).is_err());
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
            "mutation_envelope_id": null,
        });

        assert!(serde_json::from_value::<ACSModelAdaptationRequest>(value).is_err());
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

        let err = SCOPERexAdmissionProof::new(
            ACSAdmissionVerdict::Allow,
            ACSOperationKind::MemoryWrite,
            AuditRecordId::new("run-event:external-record"),
            CapabilitySignature::new("capability-signature"),
        )
        .unwrap_err();
        assert_eq!(err.cause(), "invalid_audit_record_id");
    }

    #[test]
    fn acs_admission_audit_record_id_decode_rejects_boundary_spaced_refs() {
        let decoded = serde_json::from_value::<AuditRecordId>(serde_json::json!(
            " acs:req:1001 "
        ));

        assert!(decoded.is_err());
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
        let signing_key = crate::effect::receipt::HmacSha256SigningKey::new([7; 32]);

        let err = SCOPERexAdmissionProof::signed_from_record(&record, &signing_key).unwrap_err();
        assert_eq!(err.cause(), "proof_verdict_blocks_scope_rex");
        assert_eq!(err.field(), Some("verdict"));

        let counting_key = CountingSigningKey::default();
        let err =
            SCOPERexAdmissionProof::signed_from_record(&record, &counting_key).unwrap_err();
        assert_eq!(err.cause(), "proof_verdict_blocks_scope_rex");
        assert_eq!(counting_key.sign_count(), 0);

        let err = SCOPERexAdmissionProof::from_record(
            &record,
            CapabilitySignature::new("capability-signature"),
        )
        .unwrap_err();
        assert_eq!(err.cause(), "proof_verdict_blocks_scope_rex");
        assert_eq!(err.field(), Some("verdict"));

        let err = SCOPERexAdmissionProof::new(
            ACSAdmissionVerdict::Reject,
            ACSOperationKind::MemoryWrite,
            AuditRecordId::new(record.record_id),
            CapabilitySignature::new("capability-signature"),
        )
        .unwrap_err();
        assert_eq!(err.cause(), "proof_verdict_blocks_scope_rex");
        assert_eq!(err.field(), Some("verdict"));
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

        let err = SCOPERexAdmissionProof::from_record(
            &record,
            CapabilitySignature::new("00".repeat(31)),
        )
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

        let mut wrong_verdict = record.clone();
        wrong_verdict.verdict = ACSAdmissionVerdict::Reject;
        wrong_verdict.reason = "reject".to_string();
        let err = proof
            .verify_against_record(&wrong_verdict, &signing_key)
            .unwrap_err();
        assert_eq!(err.cause(), "proof_verdict_mismatch");
        assert_eq!(err.field(), Some("verdict"));

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
        let proof = SCOPERexAdmissionProof::signed_from_record(&decision.audit_record, &signing_key)
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

        let missing_record = SCOPERexAdmissionProof::new(
            ACSAdmissionVerdict::Allow,
            ACSOperationKind::ToolAction,
            AuditRecordId::new("acs:req:404"),
            CapabilitySignature::new("00".repeat(32)),
        )
        .expect("syntactically valid proof");
        let err = missing_record
            .verify_against_run_event_log(&run_event_log, &signing_key)
            .unwrap_err();
        assert_eq!(err.cause(), "acs_audit_record_not_found");
        assert_eq!(err.field(), Some("record_id"));
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
            let decision = admit_and_record(&input, &policy, 1_001, &sink)
                .expect("RunEventLog sink records");
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

        sink.record(record.clone()).expect("first record is stored");
        let err = sink.record(record).unwrap_err();

        assert_eq!(err.cause(), "duplicate_acs_audit_record");
        assert_eq!(err.field(), Some("record_id"));
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

        let err = sink.record(decision.audit_record).unwrap_err();

        assert_eq!(err.cause(), "duplicate_acs_audit_record");
        assert_eq!(err.field(), Some("record_id"));
        assert_eq!(run_event_log.len(), 1);
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

        let reopened = crate::oplog::OpLog::open_persistent("acs-admission-sink-chain-test", &db_path)
            .expect("tampered RunEventLog reopens");
        assert!(!reopened.verify_chain(None).valid);
        let sink = ACSRunEventLogSink::new(&reopened);
        let mut record = audit_record_fixture(ACSAdmissionVerdict::AllowWithWarning);
        record.record_id = "acs:req:1002".to_string();
        record.emitted_at_ms = 1_002;
        record.policy_id = "policy forged".to_string();

        let err = sink.record(record).unwrap_err();

        assert_eq!(err.cause(), "invalid_run_event_log_chain");
        assert_eq!(err.field(), Some("run_event_log"));
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
        let decision = admit_and_record(&input, &policy, 1_001, &sink)
            .expect("RunEventLog sink records");
        let proof = SCOPERexAdmissionProof::signed_from_record(&decision.audit_record, &signing_key)
            .expect("audit record signs");

        let resolved = resolve_acs_audit_record(&run_event_log, &proof.record_id)
            .expect("record id resolves from RunEventLog");

        assert_eq!(resolved, decision.audit_record);
        assert!(proof
            .verify_against_record(&resolved, &signing_key)
            .is_ok());

        let err = resolve_acs_audit_record(&run_event_log, &AuditRecordId::new("acs:req:404"))
            .unwrap_err();
        assert_eq!(err.cause(), "acs_audit_record_not_found");
        assert_eq!(err.field(), Some("record_id"));
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
        let decision = admit_and_record(&input, &policy, 1_001, &sink)
            .expect("RunEventLog sink records");
        let duplicate_value =
            serde_json::to_value(decision.audit_record.clone()).expect("audit record encodes");
        run_event_log.append(crate::oplog::OpPayload::PropSet {
            node_id: decision.audit_record.record_id.clone(),
            key: ACS_AUDIT_RUN_EVENT_KEY.to_string(),
            value: duplicate_value,
        });

        let err = resolve_acs_audit_record(
            &run_event_log,
            &AuditRecordId::new(decision.audit_record.record_id),
        )
        .unwrap_err();

        assert_eq!(err.cause(), "duplicate_acs_audit_record");
        assert_eq!(err.field(), Some("record_id"));
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
        let decision = admit_and_record(&input, &policy, 1_001, &sink)
            .expect("RunEventLog sink records");
        let mut unaudited_value =
            serde_json::to_value(decision.audit_record.clone()).expect("audit record encodes");
        unaudited_value["shadow_reason"] = serde_json::json!("allow");
        run_event_log.append(crate::oplog::OpPayload::PropSet {
            node_id: decision.audit_record.record_id.clone(),
            key: ACS_AUDIT_RUN_EVENT_KEY.to_string(),
            value: unaudited_value,
        });

        let err = resolve_acs_audit_record(
            &run_event_log,
            &AuditRecordId::new(decision.audit_record.record_id),
        )
        .unwrap_err();

        assert_eq!(err.cause(), "corrupt_acs_audit_record");
        assert_eq!(err.field(), Some("record"));
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
            let decision = admit_and_record(&input, &policy, 1_001, &sink)
                .expect("RunEventLog sink records");
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

        let err = resolve_acs_audit_record(
            &reopened,
            &AuditRecordId::new("run-event:external-record"),
        )
        .unwrap_err();

        assert_eq!(err.cause(), "invalid_run_event_log_chain");
        assert_eq!(err.field(), Some("run_event_log"));
    }

    #[test]
    fn acs_admission_in_memory_audit_sink_rejects_corrupt_records() {
        let sink = InMemoryACSAuditSink::default();
        let mut record = audit_record_fixture(ACSAdmissionVerdict::Allow);
        record.record_id = " ".to_string();

        let err = sink.record(record).unwrap_err();

        assert_eq!(err.cause(), "corrupt_acs_audit_record");
        assert_eq!(err.field(), Some("record_id"));
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
    fn acs_admission_shadow_risk_axis_is_rejected_on_decode() {
        let mut value =
            serde_json::to_value(ACSRiskVector::neutral()).expect("risk vector encodes");
        value["shadow_risk"] = serde_json::json!(1.0);

        let decoded = serde_json::from_value::<ACSRiskVector>(value);

        assert!(decoded.is_err());
    }

    #[test]
    fn acs_admission_out_of_range_risk_axis_is_rejected_on_decode() {
        let mut value =
            serde_json::to_value(ACSRiskVector::neutral()).expect("risk vector encodes");
        value["safety_risk"] = serde_json::json!(1.01);

        let decoded = serde_json::from_value::<ACSRiskVector>(value);

        assert!(decoded.is_err());
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
    fn acs_admission_nonmonotonic_thresholds_are_rejected_on_decode() {
        let mut value =
            serde_json::to_value(ACSRiskThresholds::standard()).expect("thresholds encode");
        value["quarantine_at"] = serde_json::json!(0.4);

        let decoded = serde_json::from_value::<ACSRiskThresholds>(value);

        assert!(decoded.is_err());
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

        let decoded = serde_json::from_value::<ACSCapabilityRule>(value);

        assert!(decoded.is_err());
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
    fn acs_admission_shadow_policy_field_is_rejected_on_decode() {
        let mut value =
            serde_json::to_value(ACSPolicy::strict("policy-shadow", 1_000))
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

        assert!(decoded.is_err());
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
        assert_eq!(decision.audit_record.policy_id, "malformed_policy");
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
        assert_eq!(decision.audit_record.policy_id, "malformed_policy");
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
        assert_eq!(decision.audit_record.policy_id, "malformed_policy");
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
        }
    }

    #[test]
    fn acs_admission_durable_commit_guard_rejects_corrupt_audit_record() {
        let mut record = audit_record_fixture(ACSAdmissionVerdict::Allow);
        record.risk_max = f32::NAN;

        let err = guard_durable_commit(Some(&record)).unwrap_err();

        assert_eq!(err.cause(), "corrupt_acs_audit_record");
        assert_eq!(err.field(), Some("risk_max"));
    }

    #[test]
    fn acs_admission_audit_record_rejects_blank_reason() {
        let mut record = audit_record_fixture(ACSAdmissionVerdict::Allow);
        record.reason = " ".to_string();

        let err = record.validate().unwrap_err();

        assert_eq!(err.cause(), "corrupt_acs_audit_record");
        assert_eq!(err.field(), "reason");
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
    fn acs_admission_audit_record_rejects_noncanonical_policy_id() {
        let mut record = audit_record_fixture(ACSAdmissionVerdict::Allow);
        record.policy_id = "policy forged".to_string();

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
}
