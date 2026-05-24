//! R5 (2026-05-24): ACS production gate for v2 tool calls.
//!
//! Pins the cross-lane contract: a `MissionRun` tool invocation must
//! pass through `ACSRunEventLogSink::admit_and_record`, carry a
//! SCOPE-Rex admission proof, and reject forged capability signatures
//! at the proof boundary.

use agent_core::acs_admission::{
    snapshot_acs_audit_records, ACSAdmissionVerdict, ACSPolicy, CapabilitySignature,
};
use agent_core::agent_runtime_v2::{
    ACSRunEventLogSink, AgentBlueprintId, AgentEvent, BudgetSpec, MissionRun, RunEventEntry,
    ToolCall, ToolCallAdmissionError,
};
use agent_core::effect::receipt::HmacSha256SigningKey;
use agent_core::oplog::OpLog;

fn budget_spec() -> BudgetSpec {
    BudgetSpec {
        max_tokens: 10_000,
        max_wall_ms: 60_000,
        max_tool_calls: 10,
        max_subprocess_ms: 0,
        max_memory_bytes: 0,
    }
}

fn tool_call() -> ToolCall {
    ToolCall {
        name: "vault.write".to_string(),
        arguments: serde_json::json!({
            "path": "notes/2026/acs.md",
            "body": "ACS admitted write"
        }),
    }
}

fn signing_key() -> HmacSha256SigningKey {
    HmacSha256SigningKey::new([0xA5; 32])
}

#[test]
fn mission_run_tool_call_passes_through_acs_sink_and_carries_scope_rex_proof() {
    let mut run = MissionRun::new(AgentBlueprintId("blueprint-acs-tool".into()), budget_spec());
    let audit_log = OpLog::new("r5-acs-tool-handoff");
    let sink = ACSRunEventLogSink::new(&audit_log);
    let policy = ACSPolicy::strict_default(1_700_000_000_000);
    let key = signing_key();

    let handoff = run
        .admit_and_record_tool_call(tool_call(), &sink, &policy, 1_700_000_000_100, &key)
        .expect("tool call admitted");

    assert_eq!(handoff.event_ordinal, 0);
    assert_eq!(handoff.admission_proof.verdict, ACSAdmissionVerdict::Allow);
    assert_eq!(handoff.audit_record.operation.code(), "tool_action");
    assert_eq!(
        handoff.audit_record.record_id,
        handoff.admission_proof.record_id.0
    );
    handoff
        .admission_proof
        .verify_against_record(&handoff.audit_record, &key)
        .expect("proof verifies against returned audit record");

    let records = snapshot_acs_audit_records(&audit_log).expect("ACS audit snapshot");
    assert_eq!(records, vec![handoff.audit_record.clone()]);
    assert_eq!(run.run_event_log().find_tool_calls().len(), 1);
}

#[test]
fn forged_signature_property_rejects_mutation_at_proof_boundary() {
    let mut run = MissionRun::new(
        AgentBlueprintId("blueprint-acs-forgery".into()),
        budget_spec(),
    );
    let audit_log = OpLog::new("r5-acs-forgery");
    let sink = ACSRunEventLogSink::new(&audit_log);
    let policy = ACSPolicy::strict_default(1_700_000_000_100);
    let key = signing_key();
    let handoff = run
        .admit_and_record_tool_call(tool_call(), &sink, &policy, 1_700_000_000_200, &key)
        .expect("tool call admitted");

    let signature = handoff.admission_proof.capability_signature.0.clone();
    for index in 0..signature.len() {
        let mut forged = handoff.admission_proof.clone();
        let mut chars: Vec<char> = signature.chars().collect();
        chars[index] = if chars[index] == '0' { '1' } else { '0' };
        forged.capability_signature =
            CapabilitySignature::new(chars.into_iter().collect::<String>());

        let err = forged
            .verify_against_record(&handoff.audit_record, &key)
            .expect_err("mutated signature must be rejected");
        assert_eq!(err.cause(), "invalid_capability_signature");
    }
}

#[test]
fn raw_tool_call_event_is_not_recorded_without_acs_admission() {
    let mut run = MissionRun::new(AgentBlueprintId("blueprint-raw-tool".into()), budget_spec());
    let ordinal = run.record_event(AgentEvent::ToolCall { call: tool_call() });

    assert_eq!(ordinal, 0);
    assert!(
        run.run_event_log().find_tool_calls().is_empty(),
        "raw ToolCall rows must not bypass ACS admission"
    );
    match &run.run_event_log().entries()[0] {
        RunEventEntry::Event {
            event: AgentEvent::Error { kind, message },
            ..
        } => {
            assert_eq!(kind.code(), "capability_denied");
            assert!(message.contains("requires ACS admission"));
        }
        other => panic!("expected capability-denied error row, got {other:?}"),
    }
}

#[test]
fn acs_blocked_tool_call_records_verdict_but_does_not_append_tool_event() {
    let mut run = MissionRun::new(
        AgentBlueprintId("blueprint-acs-block".into()),
        budget_spec(),
    );
    let audit_log = OpLog::new("r5-acs-blocked");
    let sink = ACSRunEventLogSink::new(&audit_log);
    let policy = ACSPolicy::strict_default(1_700_000_000_100);
    let key = signing_key();
    let mut call = tool_call();
    call.arguments = serde_json::json!({"target": "notes/2026/acs.md"});

    let err = run
        .admit_and_record_tool_call(call, &sink, &policy, 1_700_000_000_050, &key)
        .expect_err("policy is not valid yet, so ACS blocks the call");
    match err {
        ToolCallAdmissionError::Blocked {
            verdict, reason, ..
        } => {
            assert_eq!(verdict, ACSAdmissionVerdict::Reject);
            assert_eq!(reason, "policy_not_yet_valid");
        }
        other => panic!("expected blocked ACS verdict, got {other:?}"),
    }
    let records = snapshot_acs_audit_records(&audit_log).expect("blocked verdict is still audited");
    assert_eq!(records.len(), 1);
    assert_eq!(records[0].verdict, ACSAdmissionVerdict::Reject);
    assert!(run.run_event_log().find_tool_calls().is_empty());
}
