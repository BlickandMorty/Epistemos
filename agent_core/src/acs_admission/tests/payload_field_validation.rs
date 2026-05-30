#![allow(unused_imports)]

use serde::{Deserialize, Serialize};

use super::*;
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
use crate::acs_admission::*;
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
fn acs_admission_input_decode_names_granted_capability_input_namespace() {
    let value = serde_json::json!({
        "request_id": "req-granted-capability-input-namespace",
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
        message.contains("admission_input.granted_capabilities.other.name"),
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
fn acs_admission_input_decode_names_shadow_granted_capability_input_namespace() {
    let value = serde_json::json!({
        "request_id": "req-shadow-granted-capability-input-namespace",
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
        message.contains("admission_input.granted_capabilities.other.shadow_name"),
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
fn acs_admission_input_decode_names_shadow_granted_envelope_input_namespace() {
    let value = serde_json::json!({
        "request_id": "req-shadow-granted-envelope-input-namespace",
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
        message.contains("admission_input.granted_capabilities.shadow_kind"),
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
fn acs_admission_input_decode_names_nonobject_granted_capability_input_namespace() {
    let value = serde_json::json!({
        "request_id": "req-nonobject-granted-capability-input-namespace",
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
        message.contains("admission_input.granted_capabilities.capability"),
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
fn acs_admission_input_decode_names_missing_granted_kind_input_namespace() {
    let value = serde_json::json!({
        "request_id": "req-missing-granted-kind-input-namespace",
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
        message.contains("admission_input.granted_capabilities.capability"),
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
fn acs_admission_input_decode_names_unknown_granted_kind_input_namespace() {
    let value = serde_json::json!({
        "request_id": "req-unknown-granted-kind-input-namespace",
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
        message.contains("admission_input.granted_capabilities.capability"),
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
fn acs_admission_input_decode_names_missing_granted_vault_path_verb_input_namespace() {
    let value = serde_json::json!({
        "request_id": "req-missing-granted-vault-path-verb-input-namespace",
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
        message.contains("admission_input.granted_capabilities.vault_path.verb"),
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
fn acs_admission_input_decode_names_duplicate_granted_capability_input_namespace() {
    let capability = serde_json::json!({
        "kind": "other",
        "value": {
            "name": "ToolExec"
        }
    });
    let value = serde_json::json!({
        "request_id": "req-duplicate-granted-capability-input-namespace",
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
        message.contains("admission_input.granted_capabilities.duplicate_capability"),
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
    let doc = include_str!("../../../../docs/ACS_ADMISSION_FIELD_2026_05_18.md");

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
    let doc = include_str!("../../../../docs/ACS_ADMISSION_FIELD_2026_05_18.md");

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
    let doc = include_str!("../../../../docs/ACS_ADMISSION_FIELD_2026_05_18.md");

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
    let doc = include_str!("../../../../docs/ACS_ADMISSION_FIELD_2026_05_18.md");
    let backlog =
        include_str!("../../../../docs/audits/CROSS_TERMINAL_WIRING_BACKLOG_2026_05_17.md");

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
