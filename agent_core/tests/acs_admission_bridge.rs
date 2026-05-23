//! Integration smoke test for the Wiring #6 (T18B ACS dispatch
//! admission gate) FFI `bridge::acs_admission_strict_policy_summary_json`.
//!
//! HIGH RISK wiring per the mission spec: this PR ships **status read
//! only** — the FFI exposes the strict policy's summary without
//! exercising the gate. Production admission hooks land in a follow-up
//! once the surface is validated.

use agent_core::bridge::acs_admission_strict_policy_summary_json;

#[test]
fn acs_admission_strict_policy_summary_json_returns_canonical_shape() {
    let raw = acs_admission_strict_policy_summary_json()
        .expect("FFI must not error on a status read");

    let value: serde_json::Value = serde_json::from_str(&raw)
        .expect("summary JSON must decode");
    assert!(value.is_object());

    let policy_id = value
        .get("policy_id")
        .and_then(|s| s.as_str())
        .expect("policy_id must be a string");
    assert_eq!(policy_id, "acs-strict-default");

    let version = value
        .get("version")
        .and_then(|v| v.as_u64())
        .expect("version must be a u64");
    assert!(version >= 1);

    let cap_count = value
        .get("capability_rules_count")
        .and_then(|v| v.as_u64())
        .expect("capability_rules_count required");
    assert!(
        cap_count >= 5,
        "strict default must require at least 5 capabilities (got {cap_count})"
    );

    let verdicts = value
        .get("canonical_verdicts")
        .and_then(|v| v.as_array())
        .expect("canonical_verdicts array required");
    assert_eq!(verdicts.len(), 5);
    let verdict_strs: Vec<&str> = verdicts.iter().filter_map(|v| v.as_str()).collect();
    assert!(verdict_strs.contains(&"allow"));
    assert!(verdict_strs.contains(&"allow_with_warning"));
    assert!(verdict_strs.contains(&"defer"));
    assert!(verdict_strs.contains(&"quarantine"));
    assert!(verdict_strs.contains(&"reject"));
}
