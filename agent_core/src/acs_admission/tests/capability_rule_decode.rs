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

