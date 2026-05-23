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
