//! Test module for acs_admission.
//!
//! Decomposed by T18B iter 3. Each sub-module covers a topical slice of the
//! 379 unit tests; shared fixture helpers live here so all sub-modules can
//! use them via `super::*`.

#![allow(unused_imports)]

mod admission_basics;
mod audit_record_and_shadows;
mod capability_and_threshold;
mod capability_rule_decode;
mod payload_field_validation;
mod policy_field_decode;
mod proof_and_audit_sink;

use serde::{Deserialize, Serialize};

use super::*;
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
use super::wire::*;
use crate::{
    artifacts::ArtifactRef,
    effect::receipt::{Capability, SigningKey},
    mutations::{
        BlockRef, MutationActor, MutationEnvelope, MutationStatus, RelationChange, Reversibility,
        Sensitivity, SourceOp,
    },
    oplog::{OpLog, OpPayload},
    provenance::ledger::{Claim, ClaimId, ClaimKind, ClaimStatus},
    scope_rex::{
        answer_packet::{
            AnswerPacket, AnswerPacketId, AttentionMode, MutationEnvelopeId, ResidencySignal,
            SemanticDeltaId, VrmLabel, WitnessedStateId,
        },
        residency::{route as route_residency, Residency},
    },
};

#[derive(Default)]
pub(super) struct CountingSigningKey {
    pub(super) sign_count: std::sync::atomic::AtomicUsize,
}

impl CountingSigningKey {
    pub(super) fn sign_count(&self) -> usize {
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

pub(super) fn tool_action_payload() -> ACSAdmissionPayload {
    ACSAdmissionPayload::ToolAction {
        request: ACSToolActionRequest {
            tool_name: "vault.write".to_string(),
            target: "uas://note/1".to_string(),
            mutation_envelope_id: Some("mutation-1".to_string()),
        },
    }
}

pub(super) fn high_risk_operation_payload(operation: ACSOperationKind) -> ACSAdmissionPayload {
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

pub(super) fn mutation_envelope_fixture() -> MutationEnvelope {
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

pub(super) fn assert_mutation_envelope_payload_decode_rejects(envelope: MutationEnvelope) {
    let value = serde_json::json!({
        "kind": "mutation_envelope",
        "envelope": envelope,
    });

    assert!(serde_json::from_value::<ACSAdmissionPayload>(value).is_err());
}

pub(super) fn audit_record_fixture(verdict: ACSAdmissionVerdict) -> ACSAuditRecord {
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
