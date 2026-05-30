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
fn acs_admission_scope_rex_proof_carries_verdict_record_ref_and_signature() {
    let record = audit_record_fixture(ACSAdmissionVerdict::AllowWithWarning);
    let signature = "11".repeat(CAPABILITY_SIGNATURE_BYTES);

    let proof =
        SCOPERexAdmissionProof::from_record(&record, CapabilitySignature::new(signature.clone()))
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

    let err =
        SCOPERexAdmissionProof::from_record(&record, CapabilitySignature::new(" ")).unwrap_err();
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
    let err = serde_json::from_value::<AuditRecordId>(serde_json::json!(record_id)).unwrap_err();
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
        let run_event_log = crate::oplog::OpLog::open_persistent("acs-proof-chain-test", &db_path)
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
        let run_event_log = crate::oplog::OpLog::open_persistent("acs-proof-gap-test", &db_path)
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

    let decision = admit_and_record(&input, &policy, 1_001, &sink).expect("in-memory sink records");

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
