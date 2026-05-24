//! `system_g_runtime` — FFI-facing seam that round-trips
//! `MissionPacket → SystemGAgentEvent stream → RunEventLog → AnswerPacket`
//! through Rust, exposed to Swift via `bridge::system_g_start_run_json`
//! and `bridge::system_g_drain_events_json`.
//!
//! Terminal C / P5 (2026-05-23). Replaces the `StubSystemGRunSeam`
//! (Swift) `notWired` failure with a real wire path. The runner here
//! is deterministic for V1 — it composes a real `MissionRun` over the
//! canonical `BudgetGate + BudgetLedger + RunEventLog` substrate so the
//! produced `AnswerPacket` carries the byte-equal `run_event_log_root`
//! a replay must reproduce. Real provider hooks (Claude / Perplexity /
//! local MLX) layer above this in W-05 (Active Assembly in
//! agent_runtime) and W-15 (AgentBlueprint end-to-end). The FFI shape
//! is stable; future executors stream events into the same queue.
//!
//! ## Wire shape: `SystemGAgentEvent`
//!
//! Mirrors `Epistemos/SystemG/SystemGRunSeam.swift` exactly. Discriminated
//! by a top-level `kind` field (snake_case). Each variant carries the
//! `turn_id` that groups events from one logical agent turn.

use std::collections::{HashMap, VecDeque};
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::{Mutex, OnceLock};
use std::time::{Duration, Instant};

use serde::{Deserialize, Serialize};
use uuid::Uuid;

/// Maximum concurrent in-flight runs (not yet terminated). A start_run
/// past this cap returns `SystemGRuntimeError::CapacityExhausted`. The
/// V1 deterministic runner emits the full sequence inside `start_run`,
/// so "in-flight" really means "not yet drained to terminal." Future
/// async executors will spend more wall-clock time pre-terminal; the
/// cap protects against a buggy caller spamming starts.
pub const MAX_CONCURRENT_RUNS: usize = 64;

/// Terminated runs are kept in the registry for this long so late-
/// arriving Swift polls still see `[]` (per the seam contract) instead
/// of `UnknownRun`. After the TTL the GC drops them.
pub const TERMINATED_RUN_RETENTION: Duration = Duration::from_secs(60);

use super::answer::AnswerPacket;
use super::budget::BudgetSpec;
use super::mission::{MissionPacket, MissionPromptError};
use super::mission_run::MissionRun;
use super::para::StopReason;

/// Wire-format event mirroring `Epistemos/SystemG/SystemGRunSeam.swift`
/// `SystemGAgentEvent`. Adding a new variant is additive on both
/// sides — Swift's decoder rejects unknown kinds with
/// `SystemGRunSeamError.decode`, so the two mirrors MUST move in lockstep.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "kind", rename_all = "snake_case")]
pub enum SystemGAgentEvent {
    PlanStart {
        turn_id: String,
        plan: String,
    },
    ToolStart {
        turn_id: String,
        tool_name: String,
        args_json: String,
    },
    ToolEnd {
        turn_id: String,
        tool_name: String,
        ok: bool,
        output_json: String,
    },
    TokenChunk {
        turn_id: String,
        text: String,
    },
    Complete {
        turn_id: String,
        answer_packet_id: String,
    },
    Failed {
        turn_id: String,
        error: String,
    },
}

impl SystemGAgentEvent {
    #[must_use]
    pub fn is_terminal(&self) -> bool {
        matches!(self, Self::Complete { .. } | Self::Failed { .. })
    }
}

#[derive(Debug)]
pub enum SystemGRuntimeError {
    Decode(String),
    PromptOversize { size: usize, cap: usize },
    UnknownRun(String),
    /// Registry is at `MAX_CONCURRENT_RUNS` capacity. Callers should
    /// retry after draining or terminating prior runs.
    CapacityExhausted { in_flight: usize, cap: usize },
    Internal(String),
}

impl std::fmt::Display for SystemGRuntimeError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Decode(m) => write!(f, "mission JSON decode: {m}"),
            Self::PromptOversize { size, cap } => {
                write!(f, "mission prompt {size} bytes exceeds cap {cap}")
            }
            Self::UnknownRun(id) => write!(f, "unknown run_id: {id}"),
            Self::CapacityExhausted { in_flight, cap } => write!(
                f,
                "registry at capacity: {in_flight}/{cap} in-flight runs"
            ),
            Self::Internal(m) => write!(f, "internal: {m}"),
        }
    }
}

impl From<MissionPromptError> for SystemGRuntimeError {
    fn from(e: MissionPromptError) -> Self {
        match e {
            MissionPromptError::OversizePrompt { size, cap } => {
                Self::PromptOversize { size, cap }
            }
        }
    }
}

/// Per-run state held inside the registry. `pending` is a queue the
/// runner pushed into during `start_run`; `drain_events` pops it
/// front-to-back. After the terminal event drains, the entry stays
/// in the registry so callers that re-poll get an empty array (per
/// the Swift seam contract) rather than `UnknownRun` — until the GC
/// reaps it `TERMINATED_RUN_RETENTION` after termination.
struct SystemGRunState {
    pending: VecDeque<SystemGAgentEvent>,
    /// `Some(instant)` once the terminal event has been drained; `None`
    /// while events are still pending. Both the cap accounting (only
    /// non-terminated runs count toward `MAX_CONCURRENT_RUNS`) and the
    /// GC eligibility check read this field.
    terminated_at: Option<Instant>,
}

impl SystemGRunState {
    fn new() -> Self {
        Self {
            pending: VecDeque::new(),
            terminated_at: None,
        }
    }
}

/// Process-wide registry of in-flight runs. `OnceLock<Mutex<HashMap>>`
/// keeps the start/drain entry points thread-safe under whatever
/// runtime UniFFI happens to dispatch from.
fn registry() -> &'static Mutex<HashMap<String, SystemGRunState>> {
    static REGISTRY: OnceLock<Mutex<HashMap<String, SystemGRunState>>> = OnceLock::new();
    REGISTRY.get_or_init(|| Mutex::new(HashMap::new()))
}

/// Lifetime counter of runs that ever reached the "inserted into the
/// registry" point. Increments once per successful `start_run` (after
/// the cap check + GC). Never decrements; survives drains, GC reaps,
/// and `reset_for_test()`. Exposed via `registry_stats_full()` so
/// Settings can show "N missions dispatched since launch."
static TOTAL_RUNS_DISPATCHED: AtomicU64 = AtomicU64::new(0);

/// Compose the V1 deterministic event sequence for a MissionPacket.
///
/// V1 emits a 3-event turn: `plan_start` → `token_chunk` (echoes the
/// prompt verbatim) → `complete`. Real provider streaming swaps the
/// middle event for N `token_chunk` deltas from the upstream SSE.
/// The event sequence is recorded inside a real `MissionRun` so the
/// budget ledger debits and the witness-root hash match what a real
/// run would produce — Replay-from-RunEventLog (W-16) reconstructs
/// the same bytes.
fn execute_v1_dispatch(packet: &MissionPacket, turn_id: &str) -> (Vec<SystemGAgentEvent>, String) {
    let run = MissionRun::new(
        packet.blueprint_id.clone(),
        BudgetSpec::new(
            /* max_tokens */ 4_096,
            /* max_wall_ms */ 5_000,
            /* max_tool_calls */ 4,
            /* max_subprocess_ms */ 0,
        ),
    );

    let mut events = Vec::with_capacity(3);
    let plan = format!("Execute mission: {}", packet.user_prompt);
    events.push(SystemGAgentEvent::PlanStart {
        turn_id: turn_id.to_string(),
        plan,
    });
    events.push(SystemGAgentEvent::TokenChunk {
        turn_id: turn_id.to_string(),
        text: packet.user_prompt.clone(),
    });

    // Bind the run log to the synthesized text + emit the AnswerPacket.
    // The packet's `run_event_log_root` is the witness hash; the seam
    // surfaces it (hex-encoded) as the `answer_packet_id` so Swift can
    // resolve the packet through `AnswerPacketEmitter.shared`.
    let answer: AnswerPacket = run.finalize(packet.user_prompt.clone(), Vec::new(), StopReason::EndTurn);
    let answer_packet_id = answer.run_event_log_root.to_hex();
    events.push(SystemGAgentEvent::Complete {
        turn_id: turn_id.to_string(),
        answer_packet_id: answer_packet_id.clone(),
    });
    (events, answer_packet_id)
}

/// Reap terminated runs whose `terminated_at` is at least
/// `TERMINATED_RUN_RETENTION` old. Called opportunistically from
/// `start_run` so the GC is amortised across mission starts (no
/// background thread, no extra FFI surface).
fn gc_stale_terminated(map: &mut HashMap<String, SystemGRunState>, now: Instant) {
    map.retain(|_, state| match state.terminated_at {
        Some(t) => now.duration_since(t) < TERMINATED_RUN_RETENTION,
        None => true,
    });
}

/// Count of runs that have NOT yet drained their terminal event.
/// `MAX_CONCURRENT_RUNS` gates this number, not the total registry size.
fn count_in_flight(map: &HashMap<String, SystemGRunState>) -> usize {
    map.values().filter(|s| s.terminated_at.is_none()).count()
}

/// Start a run for the given JSON-encoded `MissionPacket`. Returns the
/// freshly minted `run_id`. The run is fully composed by the time this
/// call returns; `drain_events` will pop the pending queue. Rejects
/// with `CapacityExhausted` if `MAX_CONCURRENT_RUNS` non-terminated
/// runs are already parked.
pub fn start_run(mission_json: &str) -> Result<String, SystemGRuntimeError> {
    let packet: MissionPacket = serde_json::from_str(mission_json)
        .map_err(|e| SystemGRuntimeError::Decode(e.to_string()))?;
    packet.validate_prompt()?;

    let run_id = Uuid::new_v4().to_string();
    let turn_id = format!("turn-{}", &run_id[..8]);
    let (events, _answer_id) = execute_v1_dispatch(&packet, &turn_id);

    let mut state = SystemGRunState::new();
    state.pending.extend(events);

    let mut guard = registry()
        .lock()
        .map_err(|e| SystemGRuntimeError::Internal(format!("registry poisoned: {e}")))?;
    gc_stale_terminated(&mut guard, Instant::now());
    let in_flight = count_in_flight(&guard);
    if in_flight >= MAX_CONCURRENT_RUNS {
        return Err(SystemGRuntimeError::CapacityExhausted {
            in_flight,
            cap: MAX_CONCURRENT_RUNS,
        });
    }
    guard.insert(run_id.clone(), state);
    TOTAL_RUNS_DISPATCHED.fetch_add(1, Ordering::Relaxed);
    Ok(run_id)
}

/// Drain all pending events for a given `run_id`. Returns them in
/// arrival order. After the terminal event drains, the run entry
/// stays parked (with `terminated_at = Some(now)`) but its queue is
/// empty — subsequent calls return an empty Vec until the next GC pass
/// `TERMINATED_RUN_RETENTION` later reaps it.
pub fn drain_events(run_id: &str) -> Result<Vec<SystemGAgentEvent>, SystemGRuntimeError> {
    let mut guard = registry()
        .lock()
        .map_err(|e| SystemGRuntimeError::Internal(format!("registry poisoned: {e}")))?;
    let Some(state) = guard.get_mut(run_id) else {
        return Err(SystemGRuntimeError::UnknownRun(run_id.to_string()));
    };
    let drained: Vec<SystemGAgentEvent> = state.pending.drain(..).collect();
    if state.terminated_at.is_none() && drained.iter().any(SystemGAgentEvent::is_terminal) {
        state.terminated_at = Some(Instant::now());
    }
    Ok(drained)
}

/// Observability: snapshot of registry size + in-flight count. Used
/// by Settings → System G health row and by tests. Returns
/// `(total_entries, in_flight)`.
#[must_use]
pub fn registry_stats() -> (usize, usize) {
    let Ok(guard) = registry().lock() else {
        return (0, 0);
    };
    (guard.len(), count_in_flight(&guard))
}

/// Observability: full snapshot of registry + lifetime counter.
/// Returns `(total_entries, in_flight, total_dispatched_since_launch)`.
/// `total_dispatched_since_launch` only resets when the process
/// restarts — `reset_for_test()` does NOT clear it (production
/// processes never call `reset_for_test()` so the operator's history
/// view stays honest across testing).
#[must_use]
pub fn registry_stats_full() -> (usize, usize, u64) {
    let (total, in_flight) = registry_stats();
    let dispatched = TOTAL_RUNS_DISPATCHED.load(Ordering::Relaxed);
    (total, in_flight, dispatched)
}

/// Test-only: drop every in-flight run. Production must not call this;
/// the seam is sticky for process lifetime (lets late-arriving Swift
/// polls still see the events). Tests use it to isolate fixtures.
#[doc(hidden)]
pub fn reset_for_test() {
    if let Ok(mut g) = registry().lock() {
        g.clear();
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use super::super::blueprint::AgentBlueprintId;
    use std::sync::{Mutex, MutexGuard};

    /// Serialises tests that mutate the process-wide registry. cargo
    /// runs tests in parallel by default; without this lock, one test's
    /// `start_run` slips between another's `reset_for_test()` + assertion.
    fn test_registry_lock() -> MutexGuard<'static, ()> {
        static LOCK: Mutex<()> = Mutex::new(());
        LOCK.lock().unwrap_or_else(|p| p.into_inner())
    }

    fn good_mission_json() -> String {
        serde_json::to_string(&MissionPacket {
            blueprint_id: AgentBlueprintId("research-assistant".into()),
            user_prompt: "hello world".into(),
            vault_scope: "vault/notes".into(),
        })
        .expect("encode")
    }

    #[test]
    fn agent_event_serialises_with_top_level_kind_field_in_snake_case() {
        // Swift wire-shape pin: discriminator field is `kind` and
        // variant tags are snake_case. Any drift breaks the Swift
        // SystemGAgentEvent decoder.
        let event = SystemGAgentEvent::PlanStart {
            turn_id: "t-1".into(),
            plan: "go".into(),
        };
        let json = serde_json::to_value(&event).expect("encode");
        assert_eq!(json["kind"], "plan_start");
        assert_eq!(json["turn_id"], "t-1");
        assert_eq!(json["plan"], "go");
    }

    #[test]
    fn agent_event_complete_carries_answer_packet_id_field_snake_case() {
        let event = SystemGAgentEvent::Complete {
            turn_id: "t-1".into(),
            answer_packet_id: "abc".into(),
        };
        let json = serde_json::to_value(&event).expect("encode");
        assert_eq!(json["kind"], "complete");
        assert_eq!(json["answer_packet_id"], "abc");
    }

    #[test]
    fn agent_event_is_terminal_only_for_complete_and_failed() {
        assert!(SystemGAgentEvent::Complete {
            turn_id: "t".into(),
            answer_packet_id: "a".into()
        }
        .is_terminal());
        assert!(SystemGAgentEvent::Failed {
            turn_id: "t".into(),
            error: "e".into()
        }
        .is_terminal());
        assert!(!SystemGAgentEvent::PlanStart {
            turn_id: "t".into(),
            plan: "p".into()
        }
        .is_terminal());
        assert!(!SystemGAgentEvent::TokenChunk {
            turn_id: "t".into(),
            text: "x".into()
        }
        .is_terminal());
    }

    #[test]
    fn start_run_rejects_malformed_mission_json() {
        let err = start_run("{ not json").expect_err("must reject");
        assert!(matches!(err, SystemGRuntimeError::Decode(_)));
    }

    #[test]
    fn start_run_rejects_oversize_prompt() {
        let huge = "x".repeat(MissionPacket::MAX_PROMPT_BYTES + 1);
        let packet = serde_json::json!({
            "blueprint_id": "x",
            "user_prompt": huge,
            "vault_scope": "v",
        })
        .to_string();
        let err = start_run(&packet).expect_err("oversize must reject");
        assert!(matches!(err, SystemGRuntimeError::PromptOversize { .. }));
    }

    #[test]
    fn start_run_emits_three_event_v1_turn_terminated_by_complete() {
        let _guard = test_registry_lock();
        reset_for_test();
        let run_id = start_run(&good_mission_json()).expect("start");
        let events = drain_events(&run_id).expect("drain");
        assert_eq!(events.len(), 3, "V1 turn is plan_start + token_chunk + complete");
        assert!(matches!(events[0], SystemGAgentEvent::PlanStart { .. }));
        assert!(matches!(events[1], SystemGAgentEvent::TokenChunk { .. }));
        assert!(matches!(events[2], SystemGAgentEvent::Complete { .. }));
    }

    #[test]
    fn drain_after_terminal_returns_empty_not_unknown_run() {
        let _guard = test_registry_lock();
        reset_for_test();
        let run_id = start_run(&good_mission_json()).expect("start");
        let first = drain_events(&run_id).expect("first drain");
        assert!(!first.is_empty());
        let second = drain_events(&run_id).expect("second drain still ok");
        assert!(second.is_empty(), "after terminal drains, queue is empty");
    }

    #[test]
    fn drain_unknown_run_id_surfaces_typed_error() {
        let _guard = test_registry_lock();
        let err = drain_events("nope-not-a-real-id-uuid").expect_err("must fail");
        assert!(matches!(err, SystemGRuntimeError::UnknownRun(_)));
    }

    #[test]
    fn complete_event_answer_packet_id_is_hex_of_run_event_log_root() {
        // The seam contract: `answer_packet_id` MUST be a stable
        // identifier callers can use to resolve the AnswerPacket. V1
        // uses the hex-encoded BLAKE3 run_event_log_root so replay
        // round-trips: a re-run with identical inputs yields the
        // identical id.
        let _guard = test_registry_lock();
        reset_for_test();
        let json = good_mission_json();
        let run1 = start_run(&json).expect("start 1");
        let events1 = drain_events(&run1).expect("drain 1");
        let id1 = match events1.last() {
            Some(SystemGAgentEvent::Complete { answer_packet_id, .. }) => answer_packet_id.clone(),
            other => panic!("expected Complete, got {other:?}"),
        };
        let run2 = start_run(&json).expect("start 2");
        let events2 = drain_events(&run2).expect("drain 2");
        let id2 = match events2.last() {
            Some(SystemGAgentEvent::Complete { answer_packet_id, .. }) => answer_packet_id.clone(),
            other => panic!("expected Complete, got {other:?}"),
        };
        assert_eq!(id1, id2, "identical missions yield identical answer_packet_id");
        assert!(!id1.is_empty(), "id must be non-empty");
        assert!(id1.chars().all(|c| c.is_ascii_hexdigit()), "must be hex");
    }

    #[test]
    fn token_chunk_text_echoes_user_prompt_in_v1() {
        let _guard = test_registry_lock();
        reset_for_test();
        let run_id = start_run(&good_mission_json()).expect("start");
        let events = drain_events(&run_id).expect("drain");
        match &events[1] {
            SystemGAgentEvent::TokenChunk { text, .. } => assert_eq!(text, "hello world"),
            other => panic!("expected TokenChunk, got {other:?}"),
        }
    }

    #[test]
    fn all_v1_events_share_the_same_turn_id() {
        let _guard = test_registry_lock();
        reset_for_test();
        let run_id = start_run(&good_mission_json()).expect("start");
        let events = drain_events(&run_id).expect("drain");
        let turn_ids: Vec<&str> = events
            .iter()
            .map(|e| match e {
                SystemGAgentEvent::PlanStart { turn_id, .. } => turn_id.as_str(),
                SystemGAgentEvent::TokenChunk { turn_id, .. } => turn_id.as_str(),
                SystemGAgentEvent::Complete { turn_id, .. } => turn_id.as_str(),
                SystemGAgentEvent::ToolStart { turn_id, .. } => turn_id.as_str(),
                SystemGAgentEvent::ToolEnd { turn_id, .. } => turn_id.as_str(),
                SystemGAgentEvent::Failed { turn_id, .. } => turn_id.as_str(),
            })
            .collect();
        assert_eq!(turn_ids[0], turn_ids[1]);
        assert_eq!(turn_ids[1], turn_ids[2]);
    }

    #[test]
    fn distinct_runs_have_distinct_run_ids() {
        let _guard = test_registry_lock();
        reset_for_test();
        let r1 = start_run(&good_mission_json()).expect("start 1");
        let r2 = start_run(&good_mission_json()).expect("start 2");
        assert_ne!(r1, r2);
    }

    #[test]
    fn registry_stats_track_total_and_in_flight_distinctly() {
        // After start_run + drain (which sees the terminal event), the
        // run is "terminated" (in_flight = 0) but still counted in
        // `total` until GC. Pin both counters move correctly so the
        // Settings panel can report honest numbers.
        let _guard = test_registry_lock();
        reset_for_test();
        assert_eq!(registry_stats(), (0, 0));
        let r1 = start_run(&good_mission_json()).expect("start");
        let (total1, in_flight1) = registry_stats();
        assert_eq!(total1, 1);
        assert_eq!(in_flight1, 1, "run is in-flight until terminal drains");
        let _ = drain_events(&r1).expect("drain");
        let (total2, in_flight2) = registry_stats();
        assert_eq!(total2, 1, "entry parked until GC reaps it");
        assert_eq!(in_flight2, 0, "drained terminal → no longer in-flight");
    }

    #[test]
    fn capacity_cap_rejects_starts_past_max_concurrent_runs() {
        // Pin the DoS guard: a buggy caller that spams start_run
        // without draining must hit `CapacityExhausted` rather than
        // exhaust process memory. Past terminated runs do NOT count
        // toward the cap (only in-flight do) — drain immediately to
        // exercise the boundary then verify a fresh start succeeds.
        let _guard = test_registry_lock();
        reset_for_test();
        let json = good_mission_json();
        let mut ids = Vec::with_capacity(MAX_CONCURRENT_RUNS);
        for _ in 0..MAX_CONCURRENT_RUNS {
            ids.push(start_run(&json).expect("start under cap"));
        }
        let err = start_run(&json).expect_err("cap-exceeding start must reject");
        match err {
            SystemGRuntimeError::CapacityExhausted { in_flight, cap } => {
                assert_eq!(cap, MAX_CONCURRENT_RUNS);
                assert_eq!(in_flight, MAX_CONCURRENT_RUNS);
            }
            other => panic!("expected CapacityExhausted, got {other:?}"),
        }
        // Drain one → cap frees up → next start succeeds.
        let _ = drain_events(&ids[0]).expect("drain releases a slot");
        let _ = start_run(&json).expect("start after draining slot");
    }

    #[test]
    fn gc_does_not_reap_terminated_runs_inside_retention_window() {
        // Pin GC discipline: a run that just terminated must remain
        // queryable (drain_events returns []) for at least the
        // retention window. The Swift seam contract depends on this
        // — `[]` means "still polling, nothing yet" if no terminal
        // was seen; "stop polling, already terminated" if seen.
        // UnknownRun would falsely suggest the run never existed.
        let _guard = test_registry_lock();
        reset_for_test();
        let run_id = start_run(&good_mission_json()).expect("start");
        let _ = drain_events(&run_id).expect("drain to terminal");
        // Trigger a GC pass (lazy GC fires inside start_run).
        let _ = start_run(&good_mission_json()).expect("start triggers gc");
        // Original run still drains empty (within retention window).
        let post_gc = drain_events(&run_id).expect("still queryable after GC pass");
        assert!(post_gc.is_empty(), "terminated run drains empty post-GC, not UnknownRun");
    }

    #[test]
    fn terminated_at_is_set_only_on_the_drain_that_sees_terminal() {
        // White-box pin via stats: a fresh start has 1 in-flight; the
        // FIRST drain (which sees the terminal event) sets terminated_at;
        // subsequent drains do not bump in-flight back up.
        let _guard = test_registry_lock();
        reset_for_test();
        let id = start_run(&good_mission_json()).expect("start");
        assert_eq!(registry_stats().1, 1);
        let _ = drain_events(&id).expect("first drain");
        assert_eq!(registry_stats().1, 0);
        let _ = drain_events(&id).expect("second drain");
        assert_eq!(registry_stats().1, 0, "second drain must not flip back to in-flight");
    }

    #[test]
    fn unknown_run_after_reset_for_test_does_not_panic() {
        // Pin that the test hook is safe: any cached run_id from a
        // prior test fixture cleanly surfaces UnknownRun, not panic.
        let _guard = test_registry_lock();
        let r = start_run(&good_mission_json()).expect("start");
        reset_for_test();
        let err = drain_events(&r).expect_err("post-reset run is unknown");
        assert!(matches!(err, SystemGRuntimeError::UnknownRun(_)));
    }

    #[test]
    fn agent_event_field_names_match_swift_coding_keys_byte_equal() {
        // Wire-shape pin keyed to `Epistemos/SystemG/SystemGRunSeam.swift`
        // CodingKeys. Drift here breaks the Swift decoder silently.
        let cases: Vec<(SystemGAgentEvent, Vec<&str>)> = vec![
            (
                SystemGAgentEvent::PlanStart { turn_id: "t".into(), plan: "p".into() },
                vec!["kind", "turn_id", "plan"],
            ),
            (
                SystemGAgentEvent::ToolStart {
                    turn_id: "t".into(),
                    tool_name: "vault.read".into(),
                    args_json: "{}".into(),
                },
                vec!["kind", "turn_id", "tool_name", "args_json"],
            ),
            (
                SystemGAgentEvent::ToolEnd {
                    turn_id: "t".into(),
                    tool_name: "vault.read".into(),
                    ok: true,
                    output_json: "{}".into(),
                },
                vec!["kind", "turn_id", "tool_name", "ok", "output_json"],
            ),
            (
                SystemGAgentEvent::TokenChunk { turn_id: "t".into(), text: "x".into() },
                vec!["kind", "turn_id", "text"],
            ),
            (
                SystemGAgentEvent::Complete {
                    turn_id: "t".into(),
                    answer_packet_id: "a".into(),
                },
                vec!["kind", "turn_id", "answer_packet_id"],
            ),
            (
                SystemGAgentEvent::Failed { turn_id: "t".into(), error: "e".into() },
                vec!["kind", "turn_id", "error"],
            ),
        ];
        for (event, expected_keys) in cases {
            let value = serde_json::to_value(&event).expect("encode");
            let obj = value.as_object().expect("object");
            for key in &expected_keys {
                assert!(
                    obj.contains_key(*key),
                    "event {event:?} missing key {key}; serialised: {obj:?}"
                );
            }
            assert_eq!(
                obj.len(),
                expected_keys.len(),
                "event {event:?} extra/missing keys; expected {expected_keys:?}, got {:?}",
                obj.keys().collect::<Vec<_>>()
            );
        }
    }

    #[test]
    fn total_runs_dispatched_counter_monotonically_increases_per_successful_start() {
        // The lifetime counter increments once per successful start.
        // Cap-rejected + decode-rejected starts must NOT bump it
        // (those never made it into the registry).
        let _guard = test_registry_lock();
        reset_for_test();
        let baseline = registry_stats_full().2;
        let _ = start_run(&good_mission_json()).expect("start 1");
        assert_eq!(registry_stats_full().2, baseline + 1, "successful start bumps counter");
        let _ = start_run(&good_mission_json()).expect("start 2");
        assert_eq!(registry_stats_full().2, baseline + 2);
        // Decode-rejected start: counter unchanged.
        let _ = start_run("{ not json").expect_err("malformed reject");
        assert_eq!(registry_stats_full().2, baseline + 2, "decode reject does not bump");
        // Oversize-prompt-rejected start: counter unchanged.
        let huge = "x".repeat(MissionPacket::MAX_PROMPT_BYTES + 1);
        let oversize = serde_json::json!({
            "blueprint_id": "x",
            "user_prompt": huge,
            "vault_scope": "v",
        })
        .to_string();
        let _ = start_run(&oversize).expect_err("oversize reject");
        assert_eq!(
            registry_stats_full().2,
            baseline + 2,
            "validation reject does not bump"
        );
    }

    #[test]
    fn total_runs_dispatched_survives_reset_for_test() {
        // `reset_for_test` clears the registry HashMap but MUST NOT
        // zero the lifetime counter. Otherwise the operator's
        // "X missions dispatched since launch" view in Settings
        // would lie about lifetime if a test happened to fire in
        // a test-instrumented build.
        let _guard = test_registry_lock();
        let _ = start_run(&good_mission_json()).expect("start");
        let before = registry_stats_full().2;
        reset_for_test();
        let after = registry_stats_full().2;
        assert_eq!(before, after, "reset_for_test must not zero the lifetime counter");
    }

    #[test]
    fn agent_event_kind_discriminator_values_are_pinned_snake_case() {
        // Pin the wire-format `kind` discriminator values exactly.
        // The Swift `Kind` enum uses these literals; any drift breaks
        // round-trip decode.
        let cases: Vec<(SystemGAgentEvent, &str)> = vec![
            (SystemGAgentEvent::PlanStart { turn_id: "t".into(), plan: "p".into() }, "plan_start"),
            (
                SystemGAgentEvent::ToolStart {
                    turn_id: "t".into(),
                    tool_name: "v".into(),
                    args_json: "{}".into(),
                },
                "tool_start",
            ),
            (
                SystemGAgentEvent::ToolEnd {
                    turn_id: "t".into(),
                    tool_name: "v".into(),
                    ok: true,
                    output_json: "{}".into(),
                },
                "tool_end",
            ),
            (
                SystemGAgentEvent::TokenChunk { turn_id: "t".into(), text: "x".into() },
                "token_chunk",
            ),
            (
                SystemGAgentEvent::Complete {
                    turn_id: "t".into(),
                    answer_packet_id: "a".into(),
                },
                "complete",
            ),
            (SystemGAgentEvent::Failed { turn_id: "t".into(), error: "e".into() }, "failed"),
        ];
        for (event, expected_kind) in cases {
            let value = serde_json::to_value(&event).expect("encode");
            assert_eq!(value["kind"], expected_kind, "for event {event:?}");
        }
    }
}
