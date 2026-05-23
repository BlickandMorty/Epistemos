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

