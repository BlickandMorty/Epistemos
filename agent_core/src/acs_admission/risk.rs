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
use super::validation::*;
use super::verdict::*;
use super::wire::*;
use super::*;

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

pub(crate) fn require_risk_number_field<E>(
    value: &serde_json::Value,
    field: &'static str,
) -> Result<(), E>
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

pub(crate) fn require_risk_bool_field<E>(
    value: &serde_json::Value,
    field: &'static str,
) -> Result<(), E>
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

pub(crate) fn require_risk_vector_known_fields<E>(value: &serde_json::Value) -> Result<(), E>
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

pub(crate) fn acs_risk_vector_decode_error(error: &ACSRiskVectorError) -> String {
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

pub(crate) const ACS_L0_OPERATIONS: [ACSOperationKind; 3] = [
    ACSOperationKind::MutationEnvelope,
    ACSOperationKind::MemoryWrite,
    ACSOperationKind::AnswerPacket,
];
pub(crate) const ACS_L1_OPERATIONS: [ACSOperationKind; 2] = [
    ACSOperationKind::ToolAction,
    ACSOperationKind::ActiveAssemblyPacket,
];
pub(crate) const ACS_L2_OPERATIONS: [ACSOperationKind; 2] = [
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
