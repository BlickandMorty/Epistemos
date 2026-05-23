#![allow(unused_imports)]

use serde::{Deserialize, Serialize};

use super::*;
use crate::acs_admission::*;
use crate::acs_admission::admit::*;
use crate::acs_admission::audit_sink::*;
use crate::acs_admission::common::*;
use crate::acs_admission::decision::*;
use crate::acs_admission::input::*;
use crate::acs_admission::policy::*;
use crate::acs_admission::proof::*;
use crate::acs_admission::requests::*;
use crate::acs_admission::risk::*;
use crate::acs_admission::validation::*;
use crate::acs_admission::verdict::*;
use crate::acs_admission::wire::*;
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
fn acs_admission_nonobject_input_risk_names_input_namespace() {
    let value = serde_json::json!({
        "request_id": "req-nonobject-risk",
        "payload": {
            "kind": "tool_action",
            "request": {
                "tool_name": "vault.write",
                "target": "uas://note/1",
                "mutation_envelope_id": "mutation-1"
            }
        },
        "submitted_at_ms": 1_001,
        "risk": "neutral",
        "granted_capabilities": []
    });

    let err = serde_json::from_value::<ACSAdmissionInput>(value).unwrap_err();
    let message = err.to_string();

    assert!(message.contains("forged_admission_input"), "{message}");
    assert!(message.contains("admission_input.risk"), "{message}");
}

#[test]
fn acs_admission_partial_input_risk_names_input_risk_namespace() {
    let mut risk = serde_json::to_value(ACSRiskVector::neutral()).expect("risk encodes");
    risk.as_object_mut()
        .expect("risk encodes as object")
        .remove("safety_risk");
    let value = serde_json::json!({
        "request_id": "req-partial-risk",
        "payload": {
            "kind": "tool_action",
            "request": {
                "tool_name": "vault.write",
                "target": "uas://note/1",
                "mutation_envelope_id": "mutation-1"
            }
        },
        "submitted_at_ms": 1_001,
        "risk": risk,
        "granted_capabilities": []
    });

    let err = serde_json::from_value::<ACSAdmissionInput>(value).unwrap_err();
    let message = err.to_string();

    assert!(message.contains("forged_admission_input"), "{message}");
    assert!(
        message.contains("admission_input.risk.safety_risk"),
        "{message}"
    );
}

#[test]
fn acs_admission_shadow_input_risk_axis_names_input_risk_namespace() {
    let mut risk = serde_json::to_value(ACSRiskVector::neutral()).expect("risk encodes");
    risk["shadow_risk"] = serde_json::json!(1.0);
    let value = serde_json::json!({
        "request_id": "req-shadow-input-risk",
        "payload": {
            "kind": "tool_action",
            "request": {
                "tool_name": "vault.write",
                "target": "uas://note/1",
                "mutation_envelope_id": "mutation-1"
            }
        },
        "submitted_at_ms": 1_001,
        "risk": risk,
        "granted_capabilities": []
    });

    let err = serde_json::from_value::<ACSAdmissionInput>(value).unwrap_err();
    let message = err.to_string();

    assert!(message.contains("forged_admission_input"), "{message}");
    assert!(
        message.contains("admission_input.risk.shadow_risk"),
        "{message}"
    );
}

#[test]
fn acs_admission_forged_input_request_id_decode_names_input_namespace() {
    let value = serde_json::json!({
        "request_id": " req-forged ",
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
        "granted_capabilities": []
    });

    let err = serde_json::from_value::<ACSAdmissionInput>(value).unwrap_err();
    let message = err.to_string();

    assert!(message.contains("forged_admission_input"), "{message}");
    assert!(message.contains("admission_input.request_id"), "{message}");
}

#[test]
fn acs_admission_negative_submitted_time_decode_names_input_namespace() {
    let value = serde_json::json!({
        "request_id": "req-negative-submitted-time-namespace",
        "payload": {
            "kind": "tool_action",
            "request": {
                "tool_name": "vault.write",
                "target": "uas://note/1",
                "mutation_envelope_id": "mutation-1"
            }
        },
        "submitted_at_ms": -1,
        "risk": ACSRiskVector::neutral(),
        "granted_capabilities": []
    });

    let err = serde_json::from_value::<ACSAdmissionInput>(value).unwrap_err();
    let message = err.to_string();

    assert!(message.contains("forged_admission_input"), "{message}");
    assert!(
        message.contains("admission_input.submitted_at_ms"),
        "{message}"
    );
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

