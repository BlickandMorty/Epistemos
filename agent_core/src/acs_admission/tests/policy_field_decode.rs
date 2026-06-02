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
    let mut value =
        serde_json::to_value(ACSPolicy::strict("policy-shadow", 1_000)).expect("policy encodes");
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
