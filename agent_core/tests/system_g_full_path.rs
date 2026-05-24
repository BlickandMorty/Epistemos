//! Integration smoke test for Terminal C / P5 — verifies the
//! `bridge::system_g_start_run_json` + `bridge::system_g_drain_events_json`
//! FFI surface round-trips a real `MissionPacket` to a terminal
//! `complete` event without exercising the lib-test compile path of
//! unrelated modules (cache/, tools_v2/, skill_discovery/), which are
//! pre-existing red on origin/main per the `system_g_bridge.rs`
//! integration-test sibling.

use agent_core::bridge::{system_g_drain_events_json, system_g_start_run_json};

fn good_mission_json() -> String {
    serde_json::json!({
        "blueprint_id": "research-assistant",
        "user_prompt": "Summarize the Five Plane Formalism",
        "vault_scope": "vault/notes/canon",
    })
    .to_string()
}

#[test]
fn full_path_mission_round_trips_to_complete_event_through_ffi() {
    let run_id = system_g_start_run_json(good_mission_json()).expect("start_run FFI must succeed");
    assert!(!run_id.is_empty(), "run_id must be non-empty");

    let raw = system_g_drain_events_json(run_id.clone()).expect("drain_events FFI must succeed");
    let events: serde_json::Value = serde_json::from_str(&raw).expect("drain JSON must decode");
    let arr = events.as_array().expect("drain JSON must be an array");
    assert_eq!(arr.len(), 3, "V1 turn emits 3 events");
    assert_eq!(arr[0]["kind"], "plan_start", "first event is plan_start");
    assert_eq!(arr[1]["kind"], "token_chunk", "second event is token_chunk");
    assert_eq!(arr[2]["kind"], "complete", "terminal event is complete");

    let answer_id = arr[2]["answer_packet_id"].as_str().expect("answer_packet_id field");
    assert!(!answer_id.is_empty(), "answer_packet_id must be non-empty");
    assert!(
        answer_id.chars().all(|c| c.is_ascii_hexdigit()),
        "answer_packet_id must be hex (BLAKE3 run_event_log_root)"
    );

    // Second drain after terminal must return an empty array, not
    // UnknownRun — the seam contract Swift relies on for stop-condition.
    let raw2 = system_g_drain_events_json(run_id).expect("second drain still ok");
    let events2: serde_json::Value = serde_json::from_str(&raw2).expect("second drain JSON");
    assert_eq!(
        events2.as_array().expect("array").len(),
        0,
        "post-terminal drain returns empty array"
    );
}
