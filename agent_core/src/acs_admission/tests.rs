#![allow(unused_imports)]

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
        granted_capabilities: Vec::new(),
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
            granted_capabilities: policy.required_for(operation),
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
fn acs_admission_per_operation_threshold_overrides_apply_as_complete_matrix() {
    let mut risk = ACSRiskVector::neutral();
    risk.truth_risk = 0.35;
    let override_thresholds = ACSRiskThresholds {
        warn_at: 0.10,
        defer_at: 0.20,
        quarantine_at: 0.30,
        reject_at: 0.40,
    };
    let override_operations = [
        ACSOperationKind::MemoryWrite,
        ACSOperationKind::ToolAction,
        ACSOperationKind::ActiveAssemblyPacket,
        ACSOperationKind::KernelPromotion,
        ACSOperationKind::ModelAdaptation,
    ];
    let mut policy = ACSPolicy::strict_default(1_000);
    policy.operation_thresholds = override_operations
        .iter()
        .copied()
        .map(|operation| ACSOperationThresholdRule::new(operation, override_thresholds))
        .collect();

    for operation in override_operations {
        let input = ACSAdmissionInput {
            request_id: format!("req-{}-threshold-matrix", operation.code()),
            payload: high_risk_operation_payload(operation),
            submitted_at_ms: 1_001,
            risk,
            granted_capabilities: policy.required_for(operation),
        };

        let decision = admit(&input, &policy, 1_001);

        assert_eq!(
            decision.verdict,
            ACSAdmissionVerdict::Quarantine,
            "matrix override threshold must apply to {}",
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
fn acs_admission_nonfinite_operation_threshold_names_threshold_namespace() {
    let mut policy = ACSPolicy::strict("policy-nonfinite-operation-threshold", 1_000);
    let mut thresholds = ACSRiskThresholds::standard();
    thresholds.warn_at = f32::NAN;
    policy.operation_thresholds = vec![ACSOperationThresholdRule::new(
        ACSOperationKind::ToolAction,
        thresholds,
    )];

    let err = policy.validate_at(1_001).unwrap_err();

    assert_eq!(err.cause(), "malformed_policy");
    assert_eq!(err.field(), Some("operation_thresholds.thresholds.warn_at"));
}

#[test]
fn acs_admission_out_of_order_operation_threshold_names_threshold_namespace() {
    let mut policy = ACSPolicy::strict("policy-out-of-order-operation-threshold", 1_000);
    let mut thresholds = ACSRiskThresholds::standard();
    thresholds.quarantine_at = 0.40;
    thresholds.reject_at = 0.30;
    policy.operation_thresholds = vec![ACSOperationThresholdRule::new(
        ACSOperationKind::ToolAction,
        thresholds,
    )];

    let err = policy.validate_at(1_001).unwrap_err();

    assert_eq!(err.cause(), "malformed_policy");
    assert_eq!(
        err.field(),
        Some("operation_thresholds.thresholds.risk_threshold_order")
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
fn acs_admission_scope_rex_proof_gap_precedes_invalid_signature() {
    let temp_dir = tempfile::tempdir().expect("temporary ACS OpLog directory");
    let db_path = temp_dir
        .path()
        .join("acs-proof-gap-invalid-signature.sqlite");
    let signing_key = crate::effect::receipt::HmacSha256SigningKey::new([7; 32]);
    let mut proof = {
        let run_event_log =
            crate::oplog::OpLog::open_persistent("acs-proof-gap-invalid-signature", &db_path)
                .expect("persistent RunEventLog opens");
        let sink = ACSRunEventLogSink::new(&run_event_log);
        let first_input = ACSAdmissionInput {
            request_id: "req-proof-gap-signature-first".to_string(),
            payload: tool_action_payload(),
            submitted_at_ms: 1_000,
            risk: ACSRiskVector::neutral(),
            granted_capabilities: Vec::new(),
        };
        let second_input = ACSAdmissionInput {
            request_id: "req-proof-gap-signature".to_string(),
            payload: tool_action_payload(),
            submitted_at_ms: 1_001,
            risk: ACSRiskVector::neutral(),
            granted_capabilities: Vec::new(),
        };
        let policy = ACSPolicy::strict("policy-proof-gap-signature", 1_000);
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

    let reopened =
        crate::oplog::OpLog::open_persistent("acs-proof-gap-invalid-signature", &db_path)
            .expect("gapped RunEventLog reopens");
    let report = reopened.verify_chain(None);
    assert!(!report.valid);
    assert_eq!(report.failure_reason.as_deref(), Some("seq_gap"));
    proof.signature = CapabilitySignature::new(" ");

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
fn acs_admission_run_event_log_sink_rejects_existing_corrupt_audit_record() {
    let run_event_log = crate::oplog::OpLog::new("acs-admission-sink-existing-corrupt-record");
    let sink = ACSRunEventLogSink::new(&run_event_log);
    let corrupt = ACSAuditRecord {
        record_id: "acs:req-run-event-corrupt:1000".to_string(),
        request_id: "req-run-event-corrupt".to_string(),
        policy_id: "policy".to_string(),
        policy_version: 1,
        operation: ACSOperationKind::MemoryWrite,
        verdict: ACSAdmissionVerdict::Allow,
        reason: ACSAdmissionVerdict::Allow.code().to_string(),
        risk_max: 1.5,
        emitted_at_ms: 1_000,
    };
    run_event_log.append(crate::oplog::OpPayload::PropSet {
        node_id: corrupt.record_id.clone(),
        key: ACS_AUDIT_RUN_EVENT_KEY.to_string(),
        value: serde_json::to_value(&corrupt).expect("corrupt audit record encodes"),
    });

    let next = ACSAuditRecord {
        record_id: "acs:req-run-event-next:1001".to_string(),
        request_id: "req-run-event-next".to_string(),
        policy_id: "policy".to_string(),
        policy_version: 1,
        operation: ACSOperationKind::MemoryWrite,
        verdict: ACSAdmissionVerdict::Allow,
        reason: ACSAdmissionVerdict::Allow.code().to_string(),
        risk_max: 0.0,
        emitted_at_ms: 1_001,
    };

    let err = sink
        .record(next)
        .expect_err("RunEventLog sink must reject existing corrupt ACS audit record");

    assert_eq!(err.cause(), "corrupt_acs_audit_record");
    assert_eq!(err.field(), Some("risk_max"));
    assert_eq!(err.record_id(), Some(corrupt.record_id.as_str()));
    assert_eq!(run_event_log.len(), 1);
}

#[test]
fn acs_admission_run_event_log_sink_names_existing_corrupt_audit_field() {
    let run_event_log = crate::oplog::OpLog::new("acs-admission-sink-corrupt-field");
    let sink = ACSRunEventLogSink::new(&run_event_log);
    let corrupt = audit_record_fixture(ACSAdmissionVerdict::Allow);
    let mut value = serde_json::to_value(&corrupt).expect("audit record encodes");
    value
        .as_object_mut()
        .expect("audit record encodes as object")
        .remove("request_id");
    run_event_log.append(crate::oplog::OpPayload::PropSet {
        node_id: corrupt.record_id.clone(),
        key: ACS_AUDIT_RUN_EVENT_KEY.to_string(),
        value,
    });

    let next = ACSAuditRecord {
        record_id: "acs:req-run-event-after-corrupt-field:1002".to_string(),
        request_id: "req-run-event-after-corrupt-field".to_string(),
        policy_id: "policy".to_string(),
        policy_version: 1,
        operation: ACSOperationKind::MemoryWrite,
        verdict: ACSAdmissionVerdict::Allow,
        reason: ACSAdmissionVerdict::Allow.code().to_string(),
        risk_max: 0.0,
        emitted_at_ms: 1_002,
    };

    let err = sink
        .record(next)
        .expect_err("RunEventLog sink must name existing corrupt ACS audit field");

    assert_eq!(err.cause(), "corrupt_acs_audit_record");
    assert_eq!(err.field(), Some("request_id"));
    assert_eq!(err.record_id(), Some(corrupt.record_id.as_str()));
    assert_eq!(run_event_log.len(), 1);
}

#[test]
fn acs_admission_run_event_log_sink_rejects_non_monotonic_emitted_at_ms() {
    let run_event_log = crate::oplog::OpLog::new("acs-admission-run-event-emitted-order");
    let sink = ACSRunEventLogSink::new(&run_event_log);
    let first = ACSAuditRecord {
        record_id: "acs:req-run-event-first:2000".to_string(),
        request_id: "req-run-event-first".to_string(),
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
        record_id: "acs:req-run-event-second:1500".to_string(),
        request_id: "req-run-event-second".to_string(),
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
        .expect_err("RunEventLog sink must reject regressing emitted_at_ms");

    assert_eq!(err.cause(), "non_monotonic_acs_audit_log");
    assert_eq!(err.field(), Some("emitted_at_ms"));
    assert_eq!(err.record_id(), Some(regressing.record_id.as_str()));
    assert_eq!(run_event_log.len(), 1);
}

#[test]
fn acs_admission_run_event_log_sink_rejects_record_below_historical_audit_time() {
    let run_event_log = crate::oplog::OpLog::new("acs-admission-run-event-historical-time");
    let sink = ACSRunEventLogSink::new(&run_event_log);
    let first = ACSAuditRecord {
        record_id: "acs:req-run-event-high:2000".to_string(),
        request_id: "req-run-event-high".to_string(),
        policy_id: "policy".to_string(),
        policy_version: 1,
        operation: ACSOperationKind::MemoryWrite,
        verdict: ACSAdmissionVerdict::Allow,
        reason: ACSAdmissionVerdict::Allow.code().to_string(),
        risk_max: 0.0,
        emitted_at_ms: 2_000,
    };
    let second = ACSAuditRecord {
        record_id: "acs:req-run-event-low:1500".to_string(),
        request_id: "req-run-event-low".to_string(),
        policy_id: "policy".to_string(),
        policy_version: 1,
        operation: ACSOperationKind::MemoryWrite,
        verdict: ACSAdmissionVerdict::Allow,
        reason: ACSAdmissionVerdict::Allow.code().to_string(),
        risk_max: 0.0,
        emitted_at_ms: 1_500,
    };
    for record in [first, second] {
        run_event_log.append(crate::oplog::OpPayload::PropSet {
            node_id: record.record_id.clone(),
            key: ACS_AUDIT_RUN_EVENT_KEY.to_string(),
            value: serde_json::to_value(record).expect("audit record encodes"),
        });
    }

    let regressing = ACSAuditRecord {
        record_id: "acs:req-run-event-mid:1750".to_string(),
        request_id: "req-run-event-mid".to_string(),
        policy_id: "policy".to_string(),
        policy_version: 1,
        operation: ACSOperationKind::MemoryWrite,
        verdict: ACSAdmissionVerdict::Allow,
        reason: ACSAdmissionVerdict::Allow.code().to_string(),
        risk_max: 0.0,
        emitted_at_ms: 1_750,
    };

    let err = sink
        .record(regressing.clone())
        .expect_err("RunEventLog sink must reject records below historical audit time");

    assert_eq!(err.cause(), "non_monotonic_acs_audit_log");
    assert_eq!(err.field(), Some("emitted_at_ms"));
    assert_eq!(err.record_id(), Some(regressing.record_id.as_str()));
    assert_eq!(run_event_log.len(), 2);
}

#[test]
fn acs_admission_run_event_log_sink_rejects_same_request_verdict_regression() {
    let run_event_log = crate::oplog::OpLog::new("acs-admission-run-event-verdict-regression");
    let sink = ACSRunEventLogSink::new(&run_event_log);
    let first = ACSAuditRecord {
        record_id: "acs:req-run-event-race:2000".to_string(),
        request_id: "req-run-event-race".to_string(),
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
        record_id: "acs:req-run-event-race:2001".to_string(),
        request_id: "req-run-event-race".to_string(),
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
        .expect_err("RunEventLog sink must reject same-request verdict regression");

    assert_eq!(err.cause(), "non_monotonic_acs_verdict");
    assert_eq!(err.field(), Some("verdict"));
    assert_eq!(err.record_id(), Some(regressing.record_id.as_str()));
    assert_eq!(run_event_log.len(), 1);
}

#[test]
fn acs_admission_run_event_log_sink_accepts_same_request_verdict_escalation() {
    let run_event_log = crate::oplog::OpLog::new("acs-admission-run-event-verdict-escalation");
    let sink = ACSRunEventLogSink::new(&run_event_log);
    let first = ACSAuditRecord {
        record_id: "acs:req-run-event-escalate:2000".to_string(),
        request_id: "req-run-event-escalate".to_string(),
        policy_id: "policy".to_string(),
        policy_version: 1,
        operation: ACSOperationKind::MemoryWrite,
        verdict: ACSAdmissionVerdict::Allow,
        reason: ACSAdmissionVerdict::Allow.code().to_string(),
        risk_max: 0.0,
        emitted_at_ms: 2_000,
    };
    sink.record(first).expect("first record stored");

    let escalating = ACSAuditRecord {
        record_id: "acs:req-run-event-escalate:2001".to_string(),
        request_id: "req-run-event-escalate".to_string(),
        policy_id: "policy".to_string(),
        policy_version: 1,
        operation: ACSOperationKind::MemoryWrite,
        verdict: ACSAdmissionVerdict::Reject,
        reason: ACSAdmissionVerdict::Reject.code().to_string(),
        risk_max: 0.95,
        emitted_at_ms: 2_001,
    };

    sink.record(escalating)
        .expect("same-request verdict escalation records");

    assert_eq!(run_event_log.len(), 2);
    assert!(run_event_log.verify_chain(None).valid);
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
fn acs_admission_run_event_log_gap_precedes_corrupt_record() {
    let temp_dir = tempfile::tempdir().expect("temporary ACS OpLog directory");
    let db_path = temp_dir
        .path()
        .join("acs-run-event-gap-before-corrupt.sqlite");
    let next_record_id = "acs:req-gap-before-corrupt:1003";
    {
        let run_event_log =
            crate::oplog::OpLog::open_persistent("acs-admission-gap-before-corrupt", &db_path)
                .expect("persistent RunEventLog opens");
        let sink = ACSRunEventLogSink::new(&run_event_log);
        sink.record(audit_record_fixture(ACSAdmissionVerdict::Allow))
            .expect("first audit record writes");
        let mut second = audit_record_fixture(ACSAdmissionVerdict::AllowWithWarning);
        second.record_id = "acs:req-gap-before-corrupt-second:1002".to_string();
        second.request_id = "req-gap-before-corrupt-second".to_string();
        second.emitted_at_ms = 1_002;
        sink.record(second).expect("second audit record writes");
    }

    let conn = rusqlite::Connection::open(&db_path).expect("tamper connection opens");
    conn.execute("DELETE FROM epistemos_oplog WHERE seq = 0", [])
        .expect("tamper delete succeeds");
    drop(conn);

    let reopened =
        crate::oplog::OpLog::open_persistent("acs-admission-gap-before-corrupt", &db_path)
            .expect("gapped RunEventLog reopens");
    let sink = ACSRunEventLogSink::new(&reopened);
    let mut corrupt = audit_record_fixture(ACSAdmissionVerdict::Allow);
    corrupt.record_id = next_record_id.to_string();
    corrupt.request_id = "req-gap-before-corrupt".to_string();
    corrupt.reason = " ".to_string();
    corrupt.emitted_at_ms = 1_003;

    let err = sink.record(corrupt).unwrap_err();

    assert_eq!(err.cause(), "acs_audit_log_gap");
    assert_eq!(err.field(), Some("run_event_log"));
    assert_eq!(err.record_id(), Some(next_record_id));
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
fn acs_admission_run_event_log_resolver_names_corrupt_audit_field() {
    let run_event_log = crate::oplog::OpLog::new("acs-admission-resolver-corrupt-field");
    let record = audit_record_fixture(ACSAdmissionVerdict::Allow);
    let record_id = record.record_id.clone();
    let mut value = serde_json::to_value(&record).expect("audit record encodes");
    value
        .as_object_mut()
        .expect("audit record encodes as object")
        .remove("request_id");
    run_event_log.append(crate::oplog::OpPayload::PropSet {
        node_id: record_id.clone(),
        key: ACS_AUDIT_RUN_EVENT_KEY.to_string(),
        value,
    });

    let err = resolve_acs_audit_record(&run_event_log, &AuditRecordId::new(record_id.clone()))
        .expect_err("resolver must name corrupt ACS audit field");

    assert_eq!(err.cause(), "corrupt_acs_audit_record");
    assert_eq!(err.field(), Some("request_id"));
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
fn acs_admission_null_operation_threshold_axis_names_threshold_namespace() {
    let value = serde_json::json!({
        "operation": "tool_action",
        "thresholds": {
            "warn_at": null,
            "defer_at": 0.55,
            "quarantine_at": 0.75,
            "reject_at": 0.90
        }
    });

    let err = serde_json::from_value::<ACSOperationThresholdRule>(value).unwrap_err();
    let message = err.to_string();

    assert!(message.contains("malformed_policy"), "{message}");
    assert!(
        message.contains("operation_thresholds.thresholds.warn_at"),
        "{message}"
    );
}

#[test]
fn acs_admission_typed_operation_threshold_axis_names_threshold_namespace() {
    let value = serde_json::json!({
        "operation": "tool_action",
        "thresholds": {
            "warn_at": 0.35,
            "defer_at": 0.55,
            "quarantine_at": 0.75,
            "reject_at": "0.90"
        }
    });

    let err = serde_json::from_value::<ACSOperationThresholdRule>(value).unwrap_err();
    let message = err.to_string();

    assert!(message.contains("malformed_policy"), "{message}");
    assert!(
        message.contains("operation_thresholds.thresholds.reject_at"),
        "{message}"
    );
}

#[test]
fn acs_admission_out_of_order_operation_threshold_decode_names_threshold_namespace() {
    let value = serde_json::json!({
        "operation": "tool_action",
        "thresholds": {
            "warn_at": 0.35,
            "defer_at": 0.55,
            "quarantine_at": 0.40,
            "reject_at": 0.30
        }
    });

    let err = serde_json::from_value::<ACSOperationThresholdRule>(value).unwrap_err();
    let message = err.to_string();

    assert!(message.contains("malformed_policy"), "{message}");
    assert!(
        message.contains("operation_thresholds.thresholds.risk_threshold_order"),
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
fn acs_admission_l2_rejects_replayed_lower_lane_capabilities() {
    let cases = [
        (
            ACSAdmissionPayload::KernelPromotion {
                request: ACSKernelPromotionRequest {
                    kernel_id: "kernel-1".to_string(),
                    signed_plan_hash: "plan-hash".to_string(),
                    mutation_envelope_id: Some("mutation-1".to_string()),
                },
            },
            named_capability("ToolExec"),
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
            named_capability("Assembly"),
        ),
    ];
    let policy = ACSPolicy::strict("policy-l2-replayed-lower-lane-capability", 1_000);

    for (idx, (payload, replayed_capability)) in cases.into_iter().enumerate() {
        let input = ACSAdmissionInput {
            request_id: format!("req-l2-replayed-lower-lane-capability-{idx}"),
            payload,
            submitted_at_ms: 1_001,
            risk: ACSRiskVector::neutral(),
            granted_capabilities: vec![replayed_capability],
        };
        let mut audit_log = Vec::new();

        let decision = admit_and_log(&input, &policy, 1_001, &mut audit_log);

        assert_eq!(decision.verdict, ACSAdmissionVerdict::Reject);
        assert_eq!(decision.audit_record.reason, "missing_capability");
        assert_eq!(decision.lane(), ACSLane::L2);
        assert_eq!(decision.product_lane_code(), "self_healing_research");
        assert_eq!(audit_log.len(), 1);
        assert!(decision.audit_record.validate().is_ok());
    }
}

#[test]
fn acs_admission_l2_rejects_lower_lane_capability_scope_creep() {
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
            named_capability("ToolExec"),
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
            named_capability("Assembly"),
        ),
    ];
    let policy = ACSPolicy::strict_default(1_000);

    for (idx, (payload, l2_capability, replayed_capability)) in cases.into_iter().enumerate() {
        let input = ACSAdmissionInput {
            request_id: format!("req-l2-capability-scope-creep-{idx}"),
            payload,
            submitted_at_ms: 1_001,
            risk: ACSRiskVector::neutral(),
            granted_capabilities: vec![l2_capability, replayed_capability],
        };
        let mut audit_log = Vec::new();

        let decision = admit_and_log(&input, &policy, 1_001, &mut audit_log);

        assert_eq!(decision.verdict, ACSAdmissionVerdict::Reject);
        assert_eq!(decision.audit_record.reason, "capability_scope_creep");
        assert_eq!(decision.lane(), ACSLane::L2);
        assert_eq!(audit_log.len(), 1);
        assert!(decision.audit_record.validate().is_ok());
    }
}

#[test]
fn acs_admission_l1_rejects_l2_capability_scope_creep() {
    let policy = ACSPolicy::strict_default(1_000);
    let input = ACSAdmissionInput {
        request_id: "req-l1-capability-scope-creep".to_string(),
        payload: tool_action_payload(),
        submitted_at_ms: 1_001,
        risk: ACSRiskVector::neutral(),
        granted_capabilities: vec![
            named_capability("ToolExec"),
            named_capability("KernelPromote"),
        ],
    };
    let mut audit_log = Vec::new();

    let decision = admit_and_log(&input, &policy, 1_001, &mut audit_log);

    assert_eq!(decision.verdict, ACSAdmissionVerdict::Reject);
    assert_eq!(decision.audit_record.reason, "capability_scope_creep");
    assert_eq!(decision.lane(), ACSLane::L1);
    assert_eq!(audit_log.len(), 1);
    assert!(decision.audit_record.validate().is_ok());
}

#[test]
fn acs_admission_rejects_unscoped_granted_capability() {
    let policy = ACSPolicy::strict_default(1_000);
    let input = ACSAdmissionInput {
        request_id: "req-unscoped-granted-capability".to_string(),
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
        granted_capabilities: vec![
            named_capability("VaultWrite"),
            named_capability("AmbientAdmin"),
        ],
    };
    let mut audit_log = Vec::new();

    let decision = admit_and_log(&input, &policy, 1_001, &mut audit_log);

    assert_eq!(decision.verdict, ACSAdmissionVerdict::Reject);
    assert_eq!(decision.audit_record.reason, "capability_scope_creep");
    assert_eq!(decision.lane(), ACSLane::L0);
    assert_eq!(audit_log.len(), 1);
    assert!(decision.audit_record.validate().is_ok());
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
fn acs_admission_shadow_audit_record_field_names_policy_version_namespace() {
    let mut value = serde_json::to_value(audit_record_fixture(ACSAdmissionVerdict::Allow))
        .expect("audit record encodes");
    value["policy_version"] = serde_json::json!("one");

    let err = serde_json::from_value::<ACSAuditRecord>(value).unwrap_err();
    let message = err.to_string();

    assert!(message.contains("corrupt_acs_audit_record"), "{message}");
    assert!(message.contains("audit_record.policy_version"), "{message}");
}

#[test]
fn acs_admission_shadow_audit_record_field_names_risk_max_namespace() {
    let mut value = serde_json::to_value(audit_record_fixture(ACSAdmissionVerdict::Allow))
        .expect("audit record encodes");
    value["risk_max"] = serde_json::json!(2.0);

    let err = serde_json::from_value::<ACSAuditRecord>(value).unwrap_err();
    let message = err.to_string();

    assert!(message.contains("corrupt_acs_audit_record"), "{message}");
    assert!(message.contains("audit_record.risk_max"), "{message}");
}

#[test]
fn acs_admission_shadow_audit_record_field_names_emitted_at_namespace() {
    let mut value = serde_json::to_value(audit_record_fixture(ACSAdmissionVerdict::Allow))
        .expect("audit record encodes");
    value["emitted_at_ms"] = serde_json::json!(-1);

    let err = serde_json::from_value::<ACSAuditRecord>(value).unwrap_err();
    let message = err.to_string();

    assert!(message.contains("corrupt_acs_audit_record"), "{message}");
    assert!(message.contains("audit_record.emitted_at_ms"), "{message}");
}

#[test]
fn acs_admission_shadow_audit_record_field_names_operation_namespace() {
    let mut value = serde_json::to_value(audit_record_fixture(ACSAdmissionVerdict::Allow))
        .expect("audit record encodes");
    value["operation"] = serde_json::json!("memory_wirte");

    let err = serde_json::from_value::<ACSAuditRecord>(value).unwrap_err();
    let message = err.to_string();

    assert!(message.contains("corrupt_acs_audit_record"), "{message}");
    assert!(message.contains("audit_record.operation"), "{message}");
}

#[test]
fn acs_admission_shadow_audit_record_field_names_verdict_namespace() {
    let mut value = serde_json::to_value(audit_record_fixture(ACSAdmissionVerdict::Allow))
        .expect("audit record encodes");
    value["verdict"] = serde_json::json!("alow");

    let err = serde_json::from_value::<ACSAuditRecord>(value).unwrap_err();
    let message = err.to_string();

    assert!(message.contains("corrupt_acs_audit_record"), "{message}");
    assert!(message.contains("audit_record.verdict"), "{message}");
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

#[test]
fn acs_admission_shadow_scope_rex_proof_field_names_proof_namespace() {
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
    assert!(message.contains("proof.shadow_proof"), "{message}");
}

#[test]
fn acs_admission_shadow_scope_rex_proof_field_names_operation_namespace() {
    let record = audit_record_fixture(ACSAdmissionVerdict::Allow);
    let signing_key = crate::effect::receipt::HmacSha256SigningKey::new([7; 32]);
    let proof = SCOPERexAdmissionProof::signed_from_record(&record, &signing_key)
        .expect("valid audit record signs");
    let mut value = serde_json::to_value(proof).expect("proof encodes");
    value["operation"] = serde_json::json!("memory_wirte");

    let err = serde_json::from_value::<SCOPERexAdmissionProof>(value).unwrap_err();
    let message = err.to_string();

    assert!(
        message.contains("malformed_acs_admission_proof"),
        "{message}"
    );
    assert!(message.contains("proof.operation"), "{message}");
}

#[test]
fn acs_admission_shadow_scope_rex_proof_field_names_verdict_namespace() {
    let record = audit_record_fixture(ACSAdmissionVerdict::Allow);
    let signing_key = crate::effect::receipt::HmacSha256SigningKey::new([7; 32]);
    let proof = SCOPERexAdmissionProof::signed_from_record(&record, &signing_key)
        .expect("valid audit record signs");
    let mut value = serde_json::to_value(proof).expect("proof encodes");
    value["verdict"] = serde_json::json!("alow");

    let err = serde_json::from_value::<SCOPERexAdmissionProof>(value).unwrap_err();
    let message = err.to_string();

    assert!(
        message.contains("malformed_acs_admission_proof"),
        "{message}"
    );
    assert!(message.contains("proof.verdict"), "{message}");
}
