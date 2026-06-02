//! R4 (2026-05-23): integration tests for
//! `agent_core::acs_admission::snapshot_acs_audit_records`.
//!
//! These tests live in `agent_core/tests/` rather than the inline
//! `acs_admission::tests` module because the lib-test build on this
//! HEAD has pre-existing unrelated breakage in `tools_v2`,
//! `cache::mod`, and `skill_discovery`. Same pattern as PR #37 / PR #39.
//!
//! Cross-ref:
//! - `agent_core/src/acs_admission/audit_sink.rs::snapshot_acs_audit_records`
//! - `agent_core/src/acs_admission/audit_sink.rs::resolve_acs_audit_record`
//! - `docs/audits/CROSS_TERMINAL_WIRING_BACKLOG_2026_05_17.md` W-46/W-47

use agent_core::acs_admission::{
    admit_and_record, snapshot_acs_audit_records, ACSAdmissionInput, ACSAdmissionPayload,
    ACSAuditLookupError, ACSPolicy, ACSRiskVector, ACSRunEventLogSink, ACSToolActionRequest,
    ACS_AUDIT_RUN_EVENT_KEY,
};
use agent_core::oplog::{OpLog, OpPayload};

fn fresh_oplog() -> OpLog {
    OpLog::new("acs-audit-snapshot-helper-test")
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

fn input(request_id: &str, submitted_at_ms: i64) -> ACSAdmissionInput {
    ACSAdmissionInput {
        request_id: request_id.to_string(),
        payload: tool_action_payload(),
        submitted_at_ms,
        risk: ACSRiskVector::neutral(),
        granted_capabilities: Vec::new(),
    }
}

/// Empty oplog → empty record list. No chain failure (genesis chain is
/// trivially valid).
#[test]
fn snapshot_acs_audit_records_returns_empty_for_fresh_oplog() {
    let oplog = fresh_oplog();
    let records = snapshot_acs_audit_records(&oplog).expect("fresh oplog snapshot");
    assert!(records.is_empty(), "fresh oplog must produce zero records");
}

/// A single `admit_and_record` produces a single snapshotted record
/// that equals the decision's audit_record.
#[test]
fn snapshot_acs_audit_records_returns_one_record_per_admission() {
    let oplog = fresh_oplog();
    let sink = ACSRunEventLogSink::new(&oplog);
    let policy = ACSPolicy::strict("policy-snapshot-1", 1_000);
    let decision = admit_and_record(&input("req-snapshot-1", 1_001), &policy, 1_001, &sink)
        .expect("admit_and_record records");

    let records = snapshot_acs_audit_records(&oplog).expect("snapshot after one admission");
    assert_eq!(
        records.len(),
        1,
        "exactly one ACS record after one admission"
    );
    assert_eq!(
        records[0], decision.audit_record,
        "snapshotted record must equal the decision's audit_record"
    );
}

/// Multiple admissions appear in oplog (append) order. The snapshot
/// MUST NOT reorder them — diagnostics rendering depends on
/// chronological order.
#[test]
fn snapshot_acs_audit_records_preserves_oplog_order() {
    let oplog = fresh_oplog();
    let sink = ACSRunEventLogSink::new(&oplog);
    let policy = ACSPolicy::strict("policy-snapshot-order", 1_000);

    let d1 = admit_and_record(&input("req-A", 1_001), &policy, 1_001, &sink).expect("a");
    let d2 = admit_and_record(&input("req-B", 1_002), &policy, 1_002, &sink).expect("b");
    let d3 = admit_and_record(&input("req-C", 1_003), &policy, 1_003, &sink).expect("c");

    let records = snapshot_acs_audit_records(&oplog).expect("snapshot three admissions");
    let actual_ids: Vec<&str> = records.iter().map(|r| r.record_id.as_str()).collect();
    let expected_ids: Vec<&str> = vec![
        d1.audit_record.record_id.as_str(),
        d2.audit_record.record_id.as_str(),
        d3.audit_record.record_id.as_str(),
    ];
    assert_eq!(
        actual_ids, expected_ids,
        "snapshot order MUST match oplog append order"
    );
}

/// Non-ACS `PropSet` entries in the oplog MUST NOT pollute the snapshot.
/// The helper filters by `key == ACS_AUDIT_RUN_EVENT_KEY`.
#[test]
fn snapshot_acs_audit_records_filters_non_acs_propset_entries() {
    let oplog = fresh_oplog();
    let sink = ACSRunEventLogSink::new(&oplog);
    let policy = ACSPolicy::strict("policy-snapshot-filter", 1_000);

    // Pollute the oplog with an unrelated PropSet before AND after the
    // ACS record so the helper has to filter on both sides.
    oplog.append(OpPayload::PropSet {
        node_id: "unrelated-node".to_string(),
        key: "some.other.key".to_string(),
        value: serde_json::json!({"hello": "world"}),
    });
    let decision = admit_and_record(&input("req-filter", 1_001), &policy, 1_001, &sink)
        .expect("admit_and_record records");
    oplog.append(OpPayload::PropSet {
        node_id: "unrelated-node-2".to_string(),
        key: "yet.another.key".to_string(),
        value: serde_json::json!({"more": "noise"}),
    });

    let records = snapshot_acs_audit_records(&oplog).expect("snapshot with pollution");
    assert_eq!(
        records.len(),
        1,
        "non-ACS PropSet entries MUST NOT appear in snapshot"
    );
    assert_eq!(records[0], decision.audit_record);
}

/// A malformed audit-record payload appended directly under
/// `ACS_AUDIT_RUN_EVENT_KEY` MUST surface as `CorruptRecord` — NOT
/// silently filtered. The diagnostics surface needs to know its data
/// is corrupted, not just receive a quietly-truncated list.
#[test]
fn snapshot_acs_audit_records_surfaces_corrupt_payload_as_error() {
    let oplog = fresh_oplog();
    let sink = ACSRunEventLogSink::new(&oplog);
    let policy = ACSPolicy::strict("policy-snapshot-corrupt", 1_000);

    // One valid record first so the chain is non-trivially populated.
    let _ = admit_and_record(&input("req-good", 1_001), &policy, 1_001, &sink).expect("good");

    // Then append a malformed ACS PropSet — missing required fields.
    oplog.append(OpPayload::PropSet {
        node_id: "acs:req-bad:1002".to_string(),
        key: ACS_AUDIT_RUN_EVENT_KEY.to_string(),
        value: serde_json::json!({"record_id": "acs:req-bad:1002"}),
    });

    let err = snapshot_acs_audit_records(&oplog)
        .expect_err("malformed ACS PropSet must surface as CorruptRecord");
    match err {
        ACSAuditLookupError::CorruptRecord { record_id, .. } => {
            assert_eq!(
                record_id, "acs:req-bad:1002",
                "CorruptRecord MUST carry the malformed entry's record_id"
            );
        }
        other => panic!("expected CorruptRecord; got {:?}", other),
    }
}
