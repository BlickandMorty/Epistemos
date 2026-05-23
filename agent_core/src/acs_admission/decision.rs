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
use super::input::*;
use super::policy::*;
use super::proof::*;
use super::requests::*;
use super::risk::*;
use super::validation::*;
use super::verdict::*;
use super::wire::*;

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
