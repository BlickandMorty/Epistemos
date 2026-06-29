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
use super::blueprint::ProviderPolicy;
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
    /// First event of a turn. `plan` is the executor's high-level
    /// dispatch summary (synthesized in V1; a real planner emits it
    /// once the model commits to a strategy).
    PlanStart { turn_id: String, plan: String },
    /// Executor invoked a tool. `args_json` is the raw JSON payload
    /// the executor sent — opaque to the seam; the Swift UI surfaces
    /// it verbatim for replay.
    ToolStart {
        turn_id: String,
        tool_name: String,
        args_json: String,
    },
    /// Tool invocation returned. `ok=false` means the tool itself
    /// reported failure — the turn may still continue if the executor
    /// has a recovery path.
    ToolEnd {
        turn_id: String,
        tool_name: String,
        ok: bool,
        output_json: String,
    },
    /// Streaming text delta. Concatenation of every `token_chunk`
    /// within a turn reproduces the final answer body.
    TokenChunk { turn_id: String, text: String },
    /// Provider-aware route handoff for local MLX/GGUF generation.
    /// Rust owns route admission and the witnessed provider policy;
    /// the Swift host owns the live local model client. The event is
    /// terminal for the Rust registry (the Rust leg is complete) but
    /// non-terminal for the Swift RunEventLog, which appends live
    /// `token_chunk` events and a final `complete` after generation.
    LocalModelHandoff {
        turn_id: String,
        model_id: String,
        provider_policy_json: String,
    },
    /// Terminal — happy path. `answer_packet_id` is the seam's
    /// stable identifier for the produced `AnswerPacket` (V1 uses
    /// the hex-encoded `run_event_log_root`).
    Complete {
        turn_id: String,
        answer_packet_id: String,
    },
    /// Terminal — unhappy path. `error` carries a human-readable
    /// summary; the Swift seam surfaces it as `SystemGRunSeamError.ffi`.
    Failed { turn_id: String, error: String },
}

impl SystemGAgentEvent {
    #[must_use]
    pub fn is_terminal(&self) -> bool {
        matches!(
            self,
            Self::Complete { .. } | Self::Failed { .. } | Self::LocalModelHandoff { .. }
        )
    }
}

#[derive(Debug)]
pub enum SystemGRuntimeError {
    /// `start_run`: the supplied `mission_json` failed JSON decode.
    /// Carries the serde error message for log triage.
    Decode(String),
    /// Provider-aware start: the supplied `provider_policy_json` failed
    /// JSON decode. Kept distinct from mission decode so the operator can
    /// triage whether the mission envelope or executor selection drifted.
    DecodeProviderPolicy(String),
    /// Provider-aware start: the decoded provider policy is structurally valid
    /// JSON but cannot produce an honest route.
    InvalidProviderPolicy(String),
    /// `start_run`: the mission prompt exceeded
    /// `MissionPacket::MAX_PROMPT_BYTES`. Pre-empts any provider
    /// call so the executor never sees an over-budget input.
    PromptOversize { size: usize, cap: usize },
    /// `drain_events`: the supplied `run_id` is not registered.
    /// Either the run was never started, or its retention window
    /// expired and the GC reaped it.
    UnknownRun(String),
    /// `start_run`: the registry is at `MAX_CONCURRENT_RUNS` capacity.
    /// Callers should retry after draining or terminating prior runs.
    /// Distinct from `PromptOversize` so the operator can tell DoS
    /// pressure apart from a single oversize request.
    CapacityExhausted { in_flight: usize, cap: usize },
    /// Defensive: a mutex poison or other internal invariant violation.
    /// Carries the underlying error description. Should never happen
    /// in production; surface it instead of panicking.
    Internal(String),
}

impl std::fmt::Display for SystemGRuntimeError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Decode(m) => write!(f, "mission JSON decode: {m}"),
            Self::DecodeProviderPolicy(m) => write!(f, "provider policy JSON decode: {m}"),
            Self::InvalidProviderPolicy(m) => write!(f, "provider policy invalid: {m}"),
            Self::PromptOversize { size, cap } => {
                write!(f, "mission prompt {size} bytes exceeds cap {cap}")
            }
            Self::UnknownRun(id) => write!(f, "unknown run_id: {id}"),
            Self::CapacityExhausted { in_flight, cap } => {
                write!(f, "registry at capacity: {in_flight}/{cap} in-flight runs")
            }
            Self::Internal(m) => write!(f, "internal: {m}"),
        }
    }
}

impl From<MissionPromptError> for SystemGRuntimeError {
    fn from(e: MissionPromptError) -> Self {
        match e {
            MissionPromptError::OversizePrompt { size, cap } => Self::PromptOversize { size, cap },
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
            /* max_tokens */ 4_096, /* max_wall_ms */ 5_000, /* max_tool_calls */ 4,
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
    let answer: AnswerPacket =
        run.finalize(packet.user_prompt.clone(), Vec::new(), StopReason::EndTurn);
    let answer_packet_id = answer.run_event_log_root.to_hex();
    events.push(SystemGAgentEvent::Complete {
        turn_id: turn_id.to_string(),
        answer_packet_id: answer_packet_id.clone(),
    });
    (events, answer_packet_id)
}

/// Compose the provider-aware route. Local MLX/GGUF policies are real host
/// handoffs: Rust admits the route and records the exact provider policy, then
/// Swift performs live local generation and appends token chunks to the same
/// RunEventLog. Other provider families remain fail-closed until their
/// executors are bound.
fn execute_provider_policy_route(
    packet: &MissionPacket,
    provider_policy: &ProviderPolicy,
    turn_id: &str,
) -> Vec<SystemGAgentEvent> {
    if let Some((model_id, provider_label)) = match provider_policy {
        ProviderPolicy::LocalMlx { model_id } => Some((model_id, "ProviderPolicy::LocalMlx")),
        ProviderPolicy::LocalGguf { model_id } => Some((model_id, "ProviderPolicy::LocalGguf")),
        _ => None,
    } {
        let provider_policy_json = serde_json::to_string(provider_policy).unwrap_or_else(|_| {
            let fallback_kind = match provider_policy {
                ProviderPolicy::LocalMlx { .. } => "local_mlx",
                ProviderPolicy::LocalGguf { .. } => "local_gguf",
                _ => "local_unknown",
            };
            format!("{{\"kind\":\"{fallback_kind}\",\"model_id\":\"<encode_error>\"}}")
        });
        return vec![
            SystemGAgentEvent::PlanStart {
                turn_id: turn_id.to_string(),
                plan: format!(
                    "Execute mission with {provider_label} model_id={model_id}: {}",
                    packet.user_prompt
                ),
            },
            SystemGAgentEvent::LocalModelHandoff {
                turn_id: turn_id.to_string(),
                model_id: model_id.clone(),
                provider_policy_json,
            },
        ];
    }

    let (plan, error) = match provider_policy {
        ProviderPolicy::LocalMlx { .. } | ProviderPolicy::LocalGguf { .. } => {
            unreachable!("local providers handled above")
        }
        ProviderPolicy::AnthropicMessages { model } => (
            format!(
                "Execute mission with AnthropicMessages model={model}: {}",
                packet.user_prompt
            ),
            "provider_not_bound: AnthropicMessages is not bound in the local System G runtime"
                .to_string(),
        ),
        ProviderPolicy::OpenAIResponses { model } => (
            format!(
                "Execute mission with OpenAIResponses model={model}: {}",
                packet.user_prompt
            ),
            "provider_not_bound: OpenAIResponses is not bound in the local System G runtime"
                .to_string(),
        ),
        ProviderPolicy::OpenAICompatible { base_url, model } => (
            format!(
                "Execute mission with OpenAICompatible base_url={base_url} model={model}: {}",
                packet.user_prompt
            ),
            "provider_not_bound: OpenAICompatible is not bound in the local System G runtime"
                .to_string(),
        ),
        ProviderPolicy::Mcp { server_id } => (
            format!(
                "Execute mission with MCP server_id={server_id}: {}",
                packet.user_prompt
            ),
            "provider_not_bound: MCP provider execution is not bound in the local System G runtime"
                .to_string(),
        ),
        ProviderPolicy::ProCli { adapter, command } => (
            format!(
                "Execute mission with ProCli adapter={adapter:?} command={command}: {}",
                packet.user_prompt
            ),
            "provider_not_bound: ProCli execution is not bound in the local System G runtime"
                .to_string(),
        ),
    };

    vec![
        SystemGAgentEvent::PlanStart {
            turn_id: turn_id.to_string(),
            plan,
        },
        SystemGAgentEvent::Failed {
            turn_id: turn_id.to_string(),
            error,
        },
    ]
}

fn validate_provider_policy_for_system_g(
    provider_policy: &ProviderPolicy,
) -> Result<(), SystemGRuntimeError> {
    match provider_policy {
        ProviderPolicy::LocalMlx { model_id } => {
            validate_provider_policy_field("LocalMlx model_id", model_id)?;
        }
        ProviderPolicy::LocalGguf { model_id } => {
            validate_provider_policy_field("LocalGguf model_id", model_id)?;
        }
        ProviderPolicy::AnthropicMessages { model } => {
            validate_provider_policy_field("AnthropicMessages model", model)?;
        }
        ProviderPolicy::OpenAIResponses { model } => {
            validate_provider_policy_field("OpenAIResponses model", model)?;
        }
        ProviderPolicy::OpenAICompatible { base_url, model } => {
            validate_provider_policy_field("OpenAICompatible base_url", base_url)?;
            validate_provider_policy_field("OpenAICompatible model", model)?;
        }
        ProviderPolicy::Mcp { server_id } => {
            validate_provider_policy_field("MCP server_id", server_id)?;
        }
        ProviderPolicy::ProCli { command, .. } => {
            validate_provider_policy_field("ProCli command", command)?;
        }
    }
    Ok(())
}

fn validate_provider_policy_field(
    label: &'static str,
    value: &str,
) -> Result<(), SystemGRuntimeError> {
    if value.trim().is_empty() {
        return Err(SystemGRuntimeError::InvalidProviderPolicy(format!(
            "{label} is required"
        )));
    }
    if value.trim() != value {
        return Err(SystemGRuntimeError::InvalidProviderPolicy(format!(
            "{label} must not contain leading or trailing whitespace"
        )));
    }
    if value.chars().any(char::is_control) {
        return Err(SystemGRuntimeError::InvalidProviderPolicy(format!(
            "{label} must not contain control characters"
        )));
    }
    Ok(())
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

fn insert_run_events(
    run_id: String,
    events: Vec<SystemGAgentEvent>,
) -> Result<String, SystemGRuntimeError> {
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

    insert_run_events(run_id, events)
}

/// Start a provider-aware System G run. This is the bridge shape the
/// local-agent adapter can hand to System G once it has admitted a route.
/// Local MLX/GGUF emits a `local_model_handoff` for the Swift host to stream
/// through the live local client; other provider paths terminate in `.failed`
/// until their executors are bound.
pub fn start_run_with_provider_policy(
    mission_json: &str,
    provider_policy_json: &str,
) -> Result<String, SystemGRuntimeError> {
    let packet: MissionPacket = serde_json::from_str(mission_json)
        .map_err(|e| SystemGRuntimeError::Decode(e.to_string()))?;
    packet.validate_prompt()?;
    let provider_policy: ProviderPolicy = serde_json::from_str(provider_policy_json)
        .map_err(|e| SystemGRuntimeError::DecodeProviderPolicy(e.to_string()))?;
    validate_provider_policy_for_system_g(&provider_policy)?;

    let run_id = Uuid::new_v4().to_string();
    let turn_id = format!("turn-{}", &run_id[..8]);
    let events = execute_provider_policy_route(&packet, &provider_policy, &turn_id);
    insert_run_events(run_id, events)
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
    use super::super::blueprint::AgentBlueprintId;
    use super::*;
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
    fn agent_event_is_terminal_for_complete_failed_and_local_handoff() {
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
        assert!(SystemGAgentEvent::LocalModelHandoff {
            turn_id: "t".into(),
            model_id: "qwen3".into(),
            provider_policy_json: "{}".into()
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
    fn local_model_handoff_wire_contract_is_frozen() {
        // SUBSTRATE Phase 0 freeze (owner 2026-06-20, SUBSTRATE_BUILD_SEQUENCE): the
        // LocalModelHandoff seam is where Rust hands route admission + the witnessed provider
        // policy to the Swift-hosted local model client (MLX/GGUF today, the new SSM model
        // later, Companion→Osaurus clones via the same contract). Its wire shape is frozen — the
        // Swift decoder rejects unknown kinds, so a `kind`/field rename breaks the handoff
        // silently. A deliberate change must move this test + the Swift mirror in lockstep.
        let event = SystemGAgentEvent::LocalModelHandoff {
            turn_id: "t-freeze".to_string(),
            model_id: "m-freeze".to_string(),
            provider_policy_json: "{}".to_string(),
        };
        let json = serde_json::to_string(&event).unwrap();
        // Frozen discriminator + field names (snake_case; Swift matches kind == this string).
        assert!(json.contains("\"kind\":\"local_model_handoff\""));
        assert!(json.contains("\"turn_id\":\"t-freeze\""));
        assert!(json.contains("\"model_id\":\"m-freeze\""));
        assert!(json.contains("\"provider_policy_json\":"));
        // Round-trips back to the same event (no drift across encode/decode).
        let parsed: SystemGAgentEvent = serde_json::from_str(&json).unwrap();
        assert_eq!(parsed, event);
        // Terminal for the Rust leg — the Swift host continues with token_chunk + complete.
        assert!(event.is_terminal());
    }

    #[test]
    fn system_g_agent_event_wire_tags_are_frozen() {
        // SUBSTRATE Phase 0 (completes the LocalModelHandoff freeze above): the FULL
        // SystemGAgentEvent `kind` discriminator set is the cross-runtime wire contract the Swift
        // decoder matches on (the enum's own doc: "the two mirrors MUST move in lockstep; Swift's
        // decoder rejects unknown kinds"). Renaming/retagging ANY event kind silently breaks the
        // Swift seam — this pins all seven + a full round-trip, so a change must be deliberate.
        let cases: Vec<(SystemGAgentEvent, &str)> = vec![
            (
                SystemGAgentEvent::PlanStart {
                    turn_id: "t".into(),
                    plan: "p".into(),
                },
                "plan_start",
            ),
            (
                SystemGAgentEvent::ToolStart {
                    turn_id: "t".into(),
                    tool_name: "x".into(),
                    args_json: "{}".into(),
                },
                "tool_start",
            ),
            (
                SystemGAgentEvent::ToolEnd {
                    turn_id: "t".into(),
                    tool_name: "x".into(),
                    ok: true,
                    output_json: "{}".into(),
                },
                "tool_end",
            ),
            (
                SystemGAgentEvent::TokenChunk {
                    turn_id: "t".into(),
                    text: "hi".into(),
                },
                "token_chunk",
            ),
            (
                SystemGAgentEvent::LocalModelHandoff {
                    turn_id: "t".into(),
                    model_id: "m".into(),
                    provider_policy_json: "{}".into(),
                },
                "local_model_handoff",
            ),
            (
                SystemGAgentEvent::Complete {
                    turn_id: "t".into(),
                    answer_packet_id: "a".into(),
                },
                "complete",
            ),
            (
                SystemGAgentEvent::Failed {
                    turn_id: "t".into(),
                    error: "e".into(),
                },
                "failed",
            ),
        ];
        for (event, tag) in cases {
            let json = serde_json::to_string(&event).unwrap();
            assert!(
                json.contains(&format!("\"kind\":\"{tag}\"")),
                "frozen wire tag `{tag}` missing from {json}"
            );
            let parsed: SystemGAgentEvent = serde_json::from_str(&json).unwrap();
            assert_eq!(parsed, event, "round-trip drift for `{tag}`");
        }
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
        assert_eq!(
            events.len(),
            3,
            "V1 turn is plan_start + token_chunk + complete"
        );
        assert!(matches!(events[0], SystemGAgentEvent::PlanStart { .. }));
        assert!(matches!(events[1], SystemGAgentEvent::TokenChunk { .. }));
        assert!(matches!(events[2], SystemGAgentEvent::Complete { .. }));
    }

    #[test]
    fn start_run_with_local_mlx_provider_emits_handoff_without_token_chunks() {
        let _guard = test_registry_lock();
        reset_for_test();
        assert_local_provider_handoff(
            ProviderPolicy::LocalMlx {
                model_id: "qwen3-8b-mlx-4bit".into(),
            },
            "qwen3-8b-mlx-4bit",
            "local_mlx",
        );
    }

    #[test]
    fn start_run_with_local_gguf_provider_emits_handoff_without_token_chunks() {
        let _guard = test_registry_lock();
        reset_for_test();
        assert_local_provider_handoff(
            ProviderPolicy::LocalGguf {
                model_id: "google/gemma-4-E2B-it-qat-q4_0-gguf".into(),
            },
            "google/gemma-4-E2B-it-qat-q4_0-gguf",
            "local_gguf",
        );
    }

    #[test]
    fn start_run_with_cloud_provider_fails_honestly_without_fake_handoff() {
        // SUBSTRATE Phase 3 honest-tier (owner 2026-06-20): a cloud provider routed through the
        // LOCAL System G runtime is NOT bound — it must fail HONESTLY (`failed` /
        // "provider_not_bound"), NEVER fake a local handoff, a Complete, or synthesized tokens.
        // This pins "no fake-green": System G never pretends to run a cloud model it can't.
        let _guard = test_registry_lock();
        let cases: Vec<(ProviderPolicy, &str)> = vec![
            (
                ProviderPolicy::AnthropicMessages {
                    model: "claude-opus-4-6".into(),
                },
                "AnthropicMessages",
            ),
            (
                ProviderPolicy::OpenAIResponses {
                    model: "gpt-5".into(),
                },
                "OpenAIResponses",
            ),
        ];
        for (policy, label) in cases {
            reset_for_test();
            let json = serde_json::to_string(&policy).expect("provider encode");
            let run_id = start_run_with_provider_policy(&good_mission_json(), &json)
                .expect("valid cloud policy dispatches (then fails honestly)");
            let events = drain_events(&run_id).expect("drain");
            assert!(
                events.iter().any(|e| matches!(e,
                    SystemGAgentEvent::Failed { error, .. } if error.contains("provider_not_bound"))),
                "{label} must fail honestly with provider_not_bound: {events:?}"
            );
            assert!(
                !events
                    .iter()
                    .any(|e| matches!(e, SystemGAgentEvent::LocalModelHandoff { .. })),
                "{label} must NOT fake a local handoff"
            );
            assert!(
                !events
                    .iter()
                    .any(|e| matches!(e, SystemGAgentEvent::Complete { .. })),
                "{label} must NOT fake a Complete"
            );
            assert!(
                !events
                    .iter()
                    .any(|e| matches!(e, SystemGAgentEvent::TokenChunk { .. })),
                "{label} must NOT synthesize token text for an unbound provider"
            );
        }
    }

    fn assert_local_provider_handoff(
        provider_policy: ProviderPolicy,
        expected_model_id: &str,
        expected_kind: &str,
    ) {
        let provider_policy_json =
            serde_json::to_string(&provider_policy).expect("provider encode");
        let run_id = start_run_with_provider_policy(&good_mission_json(), &provider_policy_json)
            .expect("provider-aware start");
        let events = drain_events(&run_id).expect("drain");
        assert_eq!(
            events.len(),
            2,
            "local provider emits plan_start + local_model_handoff only"
        );
        assert!(matches!(events[0], SystemGAgentEvent::PlanStart { .. }));
        match &events[1] {
            SystemGAgentEvent::LocalModelHandoff {
                model_id,
                provider_policy_json,
                ..
            } => {
                assert_eq!(model_id, expected_model_id);
                assert!(
                    provider_policy_json.contains(&format!("\"kind\":\"{expected_kind}\""))
                        && provider_policy_json
                            .contains(&format!("\"model_id\":\"{expected_model_id}\"")),
                    "handoff must preserve exact provider policy JSON: {provider_policy_json}"
                );
            }
            other => panic!("expected local model handoff, got {other:?}"),
        }
        assert!(
            events
                .iter()
                .all(|event| !matches!(event, SystemGAgentEvent::TokenChunk { .. })),
            "provider-aware Rust path must not synthesize token text before Swift live generation"
        );
        let second = drain_events(&run_id).expect("second drain after handoff still ok");
        assert!(
            second.is_empty(),
            "local_model_handoff terminates the Rust leg and parks an empty queue"
        );
    }

    #[test]
    fn start_run_with_provider_policy_rejects_malformed_provider_json() {
        let err = start_run_with_provider_policy(&good_mission_json(), "{ not provider")
            .expect_err("malformed provider policy must reject");
        assert!(matches!(err, SystemGRuntimeError::DecodeProviderPolicy(_)));
    }

    #[test]
    fn start_run_with_provider_policy_rejects_empty_local_mlx_model_id_without_dispatch() {
        let _guard = test_registry_lock();
        reset_for_test();
        let dispatched_before = registry_stats_full().2;
        let provider_policy = serde_json::to_string(&ProviderPolicy::LocalMlx {
            model_id: "  ".into(),
        })
        .expect("provider encode");

        let err = start_run_with_provider_policy(&good_mission_json(), &provider_policy)
            .expect_err("empty local model id must reject before dispatch");

        let message = err.to_string();
        assert!(
            message.contains("provider policy invalid"),
            "unexpected error message: {message}"
        );
        assert_eq!(
            registry_stats(),
            (0, 0),
            "invalid provider policy must not insert a run"
        );
        assert_eq!(
            registry_stats_full().2,
            dispatched_before,
            "invalid provider policy must not bump the lifetime counter"
        );
    }

    #[test]
    fn start_run_with_provider_policy_rejects_empty_local_gguf_model_id_without_dispatch() {
        let _guard = test_registry_lock();
        reset_for_test();
        let dispatched_before = registry_stats_full().2;
        let provider_policy = serde_json::to_string(&ProviderPolicy::LocalGguf {
            model_id: "  ".into(),
        })
        .expect("provider encode");

        let err = start_run_with_provider_policy(&good_mission_json(), &provider_policy)
            .expect_err("empty local GGUF model id must reject before dispatch");

        let message = err.to_string();
        assert!(
            message.contains("provider policy invalid"),
            "unexpected error message: {message}"
        );
        assert_eq!(
            registry_stats(),
            (0, 0),
            "invalid local GGUF provider policy must not insert a run"
        );
        assert_eq!(
            registry_stats_full().2,
            dispatched_before,
            "invalid local GGUF provider policy must not bump the lifetime counter"
        );
    }

    #[test]
    fn start_run_with_provider_policy_rejects_blank_unsupported_route_fields_without_dispatch() {
        let _guard = test_registry_lock();
        reset_for_test();
        let dispatched_before = registry_stats_full().2;
        let cases = [
            ProviderPolicy::AnthropicMessages { model: " ".into() },
            ProviderPolicy::OpenAIResponses { model: "\t".into() },
            ProviderPolicy::OpenAICompatible {
                base_url: "https://example.invalid/v1".into(),
                model: "".into(),
            },
            ProviderPolicy::OpenAICompatible {
                base_url: " ".into(),
                model: "qwen-compatible".into(),
            },
            ProviderPolicy::Mcp {
                server_id: "".into(),
            },
            ProviderPolicy::ProCli {
                adapter: super::super::blueprint::CliAdapter::Codex,
                command: " ".into(),
            },
        ];

        for provider_policy in cases {
            let provider_json = serde_json::to_string(&provider_policy).expect("provider encode");
            let err = start_run_with_provider_policy(&good_mission_json(), &provider_json)
                .expect_err("blank provider route field must reject before dispatch");

            assert!(
                matches!(err, SystemGRuntimeError::InvalidProviderPolicy(_)),
                "expected InvalidProviderPolicy for {provider_policy:?}, got {err:?}"
            );
        }
        assert_eq!(
            registry_stats(),
            (0, 0),
            "invalid provider route fields must not insert runs"
        );
        assert_eq!(
            registry_stats_full().2,
            dispatched_before,
            "invalid provider route fields must not bump the lifetime counter"
        );
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
            Some(SystemGAgentEvent::Complete {
                answer_packet_id, ..
            }) => answer_packet_id.clone(),
            other => panic!("expected Complete, got {other:?}"),
        };
        let run2 = start_run(&json).expect("start 2");
        let events2 = drain_events(&run2).expect("drain 2");
        let id2 = match events2.last() {
            Some(SystemGAgentEvent::Complete {
                answer_packet_id, ..
            }) => answer_packet_id.clone(),
            other => panic!("expected Complete, got {other:?}"),
        };
        assert_eq!(
            id1, id2,
            "identical missions yield identical answer_packet_id"
        );
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
                SystemGAgentEvent::LocalModelHandoff { turn_id, .. } => turn_id.as_str(),
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
        assert!(
            post_gc.is_empty(),
            "terminated run drains empty post-GC, not UnknownRun"
        );
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
        assert_eq!(
            registry_stats().1,
            0,
            "second drain must not flip back to in-flight"
        );
    }

    #[test]
    fn unknown_run_after_reset_for_test_does_not_panic() {
        // Pin that the test hook is safe: any cached run_id from a
        // prior test fixture cleanly surfaces UnknownRun, not panic.
        let _guard = test_registry_lock();
        reset_for_test();
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
                SystemGAgentEvent::PlanStart {
                    turn_id: "t".into(),
                    plan: "p".into(),
                },
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
                SystemGAgentEvent::TokenChunk {
                    turn_id: "t".into(),
                    text: "x".into(),
                },
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
                SystemGAgentEvent::Failed {
                    turn_id: "t".into(),
                    error: "e".into(),
                },
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
        assert_eq!(
            registry_stats_full().2,
            baseline + 1,
            "successful start bumps counter"
        );
        let _ = start_run(&good_mission_json()).expect("start 2");
        assert_eq!(registry_stats_full().2, baseline + 2);
        // Decode-rejected start: counter unchanged.
        let _ = start_run("{ not json").expect_err("malformed reject");
        assert_eq!(
            registry_stats_full().2,
            baseline + 2,
            "decode reject does not bump"
        );
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
    fn registry_survives_multi_thread_contention_without_panics_or_duplicate_ids() {
        // Stress: 8 threads × 4 missions each (= 32, well under
        // MAX_CONCURRENT_RUNS=64). Pins that the registry's internal
        // Mutex correctly serialises concurrent start_run + drain_events
        // without deadlock, panic, lost insert, or duplicate run_id.
        //
        // Holds the test-fixture lock for the duration so this test
        // doesn't race other registry-mutating tests in the suite.
        use std::collections::HashSet;
        use std::sync::Arc;
        use std::thread;

        let _guard = test_registry_lock();
        reset_for_test();
        let dispatched_before = registry_stats_full().2;

        const THREADS: usize = 8;
        const MISSIONS_PER_THREAD: usize = 4;
        let json = Arc::new(good_mission_json());

        let mut handles = Vec::with_capacity(THREADS);
        for _ in 0..THREADS {
            let json = Arc::clone(&json);
            handles.push(thread::spawn(move || {
                let mut ids = Vec::with_capacity(MISSIONS_PER_THREAD);
                for _ in 0..MISSIONS_PER_THREAD {
                    let id = start_run(&json).expect("start under cap");
                    let events = drain_events(&id).expect("drain");
                    assert_eq!(events.len(), 3, "every run emits the V1 3-event turn");
                    ids.push(id);
                }
                ids
            }));
        }

        let mut all_ids: Vec<String> = Vec::with_capacity(THREADS * MISSIONS_PER_THREAD);
        for h in handles {
            all_ids.extend(h.join().expect("thread must not panic"));
        }

        assert_eq!(all_ids.len(), THREADS * MISSIONS_PER_THREAD);
        let unique: HashSet<&String> = all_ids.iter().collect();
        assert_eq!(
            unique.len(),
            all_ids.len(),
            "every run_id must be unique across threads"
        );

        let dispatched_after = registry_stats_full().2;
        assert_eq!(
            dispatched_after - dispatched_before,
            (THREADS * MISSIONS_PER_THREAD) as u64,
            "lifetime counter must reflect every successful start"
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
        reset_for_test();
        let _ = start_run(&good_mission_json()).expect("start");
        let before = registry_stats_full().2;
        reset_for_test();
        let after = registry_stats_full().2;
        assert_eq!(
            before, after,
            "reset_for_test must not zero the lifetime counter"
        );
    }

    #[test]
    fn agent_event_kind_discriminator_values_are_pinned_snake_case() {
        // Pin the wire-format `kind` discriminator values exactly.
        // The Swift `Kind` enum uses these literals; any drift breaks
        // round-trip decode.
        let cases: Vec<(SystemGAgentEvent, &str)> = vec![
            (
                SystemGAgentEvent::PlanStart {
                    turn_id: "t".into(),
                    plan: "p".into(),
                },
                "plan_start",
            ),
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
                SystemGAgentEvent::TokenChunk {
                    turn_id: "t".into(),
                    text: "x".into(),
                },
                "token_chunk",
            ),
            (
                SystemGAgentEvent::Complete {
                    turn_id: "t".into(),
                    answer_packet_id: "a".into(),
                },
                "complete",
            ),
            (
                SystemGAgentEvent::Failed {
                    turn_id: "t".into(),
                    error: "e".into(),
                },
                "failed",
            ),
        ];
        for (event, expected_kind) in cases {
            let value = serde_json::to_value(&event).expect("encode");
            assert_eq!(value["kind"], expected_kind, "for event {event:?}");
        }
    }
}
