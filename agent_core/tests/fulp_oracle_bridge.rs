//! Integration smoke test for the Wiring #5 (T12 F-ULP → EML witness
//! emission) FFI `bridge::fulp_oracle_acceptance_witness_json`.
//!
//! The substrate already exposes `acceptance_witness_json()` (Rust JSON
//! IO); this test pins the FFI pass-through and the wire shape.
//!
//! Gated on `features = ["research"]` because the F-ULP oracle is
//! research-feature only on main; MAS builds do not compile it.

#![cfg(feature = "research")]

use agent_core::bridge::fulp_oracle_acceptance_witness_json;

#[test]
fn fulp_oracle_acceptance_witness_json_returns_pass_witness() {
    let raw = fulp_oracle_acceptance_witness_json()
        .expect("FFI must not error when research is on");

    let value: serde_json::Value =
        serde_json::from_str(&raw).expect("witness JSON must decode");
    assert!(value.is_object(), "witness must be a JSON object");

    let pass = value
        .get("pass")
        .and_then(|p| p.as_bool())
        .expect("witness must carry a pass field");
    assert!(pass, "F-ULP acceptance witness must pass on default fixture");

    let schema_version = value
        .get("schema_version")
        .and_then(|s| s.as_u64())
        .expect("schema_version field required");
    assert!(schema_version >= 1);

    let mission = value
        .get("mission")
        .and_then(|m| m.as_str())
        .expect("mission field required");
    assert!(!mission.is_empty());

    let stats = value
        .get("stats")
        .and_then(|s| s.as_array())
        .expect("stats array required");
    assert_eq!(stats.len(), 3, "stats array must be [exp, ln, eml] = 3 entries");
}
