//! Integration smoke test for Terminal C / P5 — verifies the
//! `bridge::system_g_start_run_json` + `bridge::system_g_drain_events_json`
//! FFI surface round-trips a real `MissionPacket` to a terminal
//! `complete` event without exercising the lib-test compile path of
//! unrelated modules (cache/, tools_v2/, skill_discovery/), which are
//! pre-existing red on origin/main per the `system_g_bridge.rs`
//! integration-test sibling.

use std::sync::{Mutex, MutexGuard};

use agent_core::bridge::{
    system_g_drain_events_json, system_g_registry_stats_json, system_g_start_run_json,
};

/// Tests inside one integration-test binary share the process-wide
/// System G registry singleton. cargo runs them in parallel by default;
/// without this lock, the registry-stats test reads counters while
/// another test's run is still in-flight.
fn test_lock() -> MutexGuard<'static, ()> {
    static LOCK: Mutex<()> = Mutex::new(());
    LOCK.lock().unwrap_or_else(|p| p.into_inner())
}

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
    let _guard = test_lock();
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

#[test]
fn full_path_start_run_with_malformed_json_surfaces_typed_ffi_error() {
    let err = system_g_start_run_json("{ this is not valid json".to_string())
        .expect_err("malformed JSON must surface as FFI error");
    let msg = match err {
        agent_core::bridge::AgentErrorFFI::AgentError { message } => message,
    };
    assert!(
        msg.contains("decode") || msg.contains("Decode") || msg.contains("expected"),
        "FFI error must carry decode context, got: {msg}"
    );
}

#[test]
fn full_path_drain_unknown_run_id_surfaces_typed_ffi_error() {
    let err = system_g_drain_events_json("00000000-aaaa-bbbb-cccc-deadbeefdead".to_string())
        .expect_err("unknown run_id must surface as FFI error");
    let msg = match err {
        agent_core::bridge::AgentErrorFFI::AgentError { message } => message,
    };
    assert!(
        msg.contains("unknown") || msg.contains("Unknown") || msg.contains("UnknownRun"),
        "FFI error must name the unknown-run condition, got: {msg}"
    );
}

#[test]
fn full_path_registry_stats_reports_in_flight_and_max_concurrent_runs() {
    // The stats FFI returns total + in_flight + max_concurrent_runs.
    // After a run that drains to terminal, total stays > 0 (entry parked
    // within retention window) but in_flight goes to 0.
    let _guard = test_lock();
    let raw_before = system_g_registry_stats_json();
    let before: serde_json::Value =
        serde_json::from_str(&raw_before).expect("stats JSON must decode");
    let max = before["max_concurrent_runs"]
        .as_u64()
        .expect("max_concurrent_runs is a number");
    assert!(max >= 8, "cap must be at least 8 (currently 64): got {max}");

    let run_id = system_g_start_run_json(good_mission_json()).expect("start");
    let _ = system_g_drain_events_json(run_id).expect("drain");
    let raw_after = system_g_registry_stats_json();
    let after: serde_json::Value =
        serde_json::from_str(&raw_after).expect("stats JSON must decode");
    let in_flight_after = after["in_flight"].as_u64().expect("in_flight number");
    let total_after = after["total"].as_u64().expect("total number");
    assert_eq!(
        in_flight_after, 0,
        "after drain to terminal, in_flight must be 0"
    );
    assert!(
        total_after >= 1,
        "after drain, entry remains parked in retention window: got {total_after}"
    );
}
