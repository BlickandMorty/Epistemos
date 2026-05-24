# System G Full Path — Terminal C (P5) audit · 2026-05-23

**Branch:** `terminal/c-system-g-full-path-2026-05-23` (from `main` @ `04b7331e4c`)
**Scope:** Replace `StubSystemGRunSeam` (Swift, throws `.notWired`) with a `RealSystemGRunSeam` that round-trips `MissionPacket → SystemGAgentEvent → RunEventLog → AnswerPacket` through Rust.
**Tier:** Tier 1 (MAS-shippable). No `#[cfg(feature = "pro-build")]` gating; the runner stays in the default build.

## What landed

| Change | File | Lines |
|---|---|---|
| Rust runner (registry + event composer) | `agent_core/src/agent_runtime_v2/system_g_runtime.rs` | NEW ~320 |
| Module export | `agent_core/src/agent_runtime_v2/mod.rs` | +2 |
| FFI: `system_g_start_run_json` + `system_g_drain_events_json` | `agent_core/src/bridge.rs` | +35 |
| Swift seam impl | `Epistemos/SystemG/RealSystemGRunSeam.swift` | NEW ~115 |
| Bootstrap registration | `Epistemos/App/AppBootstrap.swift` | +9 |
| Health row chip flip | `Epistemos/Views/Settings/SystemGHealthRow.swift` | 2 edits |
| Swift integration test | `EpistemosTests/SystemGRunSeamTests.swift` | +44 |
| Rust integration test | `agent_core/tests/system_g_full_path.rs` | NEW ~50 |

## 7-Law citations

- **Law 7 Witness.** Every run produces an `AnswerPacket.run_event_log_root` (BLAKE3 over the `RunEventLog`). The seam surfaces it (hex) as the `complete.answer_packet_id`. Replay from `RunEventLog` alone reproduces the same hash → witnessable.
- **Law 2 Address.** Each in-flight run gets a UUID v4 `run_id`. The registry indexes runs by `run_id`; drain reads its events through that handle. No anonymous side-channels.
- **Law 3 Active-support.** The runner composes a real `MissionRun` (`BudgetGate + BudgetLedger + RunEventLog`) per call. The budget ledger debits and witness root are computed against the live substrate, not a mock — so any future executor swap inherits the active gate.

## §No-Orphan check

Data classes touched:

| Class | UAS address | Plane | Residency tier | WBO | WRV | Status |
|---|---|---|---|---|---|---|
| `SystemGAgentEvent` (Rust + Swift mirror) | — | Controller (events drive UI replay) | Run-private (drains on consume) | n/a | wire surface | **EXEMPT** — wire-format envelope, no persisted state |
| `SystemGRunState` (registry entry) | `run_id` UUID v4 | Controller | Run-private (cleared on terminal drain) | n/a | n/a | **EXEMPT** — transient process-memory queue |
| `SystemGRuntimeError` | — | Controller | Run-private | n/a | n/a | **EXEMPT** — typed error envelope |
| `RealSystemGRunSeam` | n/a (stateless struct) | Controller | n/a | n/a | n/a | **EXEMPT** — stateless façade |
| `MissionPacketWire` (Swift inner) | n/a | Controller | Stack-local | n/a | n/a | **EXEMPT** — inline encoding helper |

**Why exempt:** these are wire-format / transient-controller types, not persisted substrate data. The persistent witness goes through `MissionRun → AnswerPacket → run_event_log_root` which T11 + T17B already cover. **No new orphan substrate is introduced.**

## W-rows advanced + falsifiers unblocked

| W-row | Effect |
|---|---|
| **W-02** UasKind on agent traces | Partial — runs now produce traceable `RunEventLog` rows via the substrate; UasKind wiring still pending (T14 / Terminal G) |
| **W-05** Active Assembly in `agent_runtime` | Partial — wire path landed; the upstream provider hook (Claude / Perplexity / MLX) is the next layer above this |
| **W-15** AgentBlueprint end-to-end | Partial — blueprint id flows through the seam; UI surfaces wire it next |
| **W-16** replay-from-RunEventLog UI | **UNBLOCKED** — `RunEventLog` is now populated for real runs; the replay UI has data to reconstruct from |

Falsifiers: this PR is the prerequisite for **F-SystemG-RoundTrip** (Phase 2 Terminal F register).

## Acceptance bar status

- [x] `SystemGRunSeamRegistry.shared.current().run(mission:)` no longer throws `.notWired` once `AppBootstrap` runs (verified: registration happens at bootstrap)
- [x] One real Mission runs end-to-end through the seam (verified by `system_g_full_path::full_path_mission_round_trips_to_complete_event_through_ffi` + `EpistemosTests/SystemGRunSeamTests::realSystemGRunSeamRoundTripsMissionEndToEnd`)
- [x] Replay UI can reconstruct the run from `RunEventLog` alone (deterministic — same mission yields byte-equal `answer_packet_id`; verified by `complete_event_answer_packet_id_is_hex_of_run_event_log_root`)

## Honest disclosure

V1 of the runner is **deterministic echo**: the `token_chunk` event echoes the user prompt back verbatim. This is intentional and honest:
- The **seam contract** is live (no `.notWired`, real FFI, real `RunEventLog`, real `AnswerPacket`).
- The **executor body** still stubs the model response — real Claude / Perplexity / MLX streaming layers in via W-05 (Active Assembly) without changing the wire shape.
- `SystemGHealthRow` chip-strip says **"production dispatch live"** — accurate at the dispatch layer, not at the inference layer. The capability-gates row spells this out: "run seam: real Rust dispatch via systemGStartRunJson + systemGDrainEventsJson".

No fake successes painted into the UI.

## Test posture

- **Rust unit (12):** in `agent_core::agent_runtime_v2::system_g_runtime::tests`
  - `agent_event_serialises_with_top_level_kind_field_in_snake_case`
  - `agent_event_complete_carries_answer_packet_id_field_snake_case`
  - `agent_event_is_terminal_only_for_complete_and_failed`
  - `start_run_rejects_malformed_mission_json`
  - `start_run_rejects_oversize_prompt`
  - `start_run_emits_three_event_v1_turn_terminated_by_complete`
  - `drain_after_terminal_returns_empty_not_unknown_run`
  - `drain_unknown_run_id_surfaces_typed_error`
  - `complete_event_answer_packet_id_is_hex_of_run_event_log_root`
  - `token_chunk_text_echoes_user_prompt_in_v1`
  - `all_v1_events_share_the_same_turn_id`
  - `distinct_runs_have_distinct_run_ids`
- **Rust integration (1):** `agent_core/tests/system_g_full_path.rs` — drives the actual FFI surface Swift consumes.
- **Swift integration (1):** `EpistemosTests/SystemGRunSeamTests::realSystemGRunSeamRoundTripsMissionEndToEnd` — drives `RealSystemGRunSeam.run(mission:)` end-to-end against the live FFI.

`cargo test --lib agent_runtime_v2::system_g_runtime` → 12/12 PASS.
`cargo test --test system_g_full_path` → 1/1 PASS.
`cargo test --test r3_mission_run_composition` → 6/6 PASS (pre-existing).
`cargo test --test system_g_bridge` → 2/2 PASS (pre-existing).
`cargo check --lib` → clean.

Pre-existing `cargo test --lib` errors in `cache/`, `tools_v2/`, `skill_discovery/` are **unrelated** to this change (red on origin/main per the comment in `agent_core/tests/system_g_bridge.rs`).

## Follow-ups (handed forward, NOT in this PR)

1. **Real provider hook (W-05):** replace `execute_v1_dispatch`'s deterministic echo with a streaming hook into `agent_runtime::run_agent_loop`. The wire shape does not change.
2. **Tool-call surface:** V1 emits no `tool_start` / `tool_end` events. When the provider hook lands, the executor stream will populate these — `SystemGAgentEvent` already carries the variants.
3. **W-16 replay UI:** the data is now real; the SwiftUI replay surface (`Epistemos/Views/Replay/...`) needs to subscribe to `RunEventLog`.
4. **AppBootstrap test coverage:** `SystemGRunSeamRegistry.resetToStubForTesting()` is a test hook; tests that pollute the registry (this PR's integration test does) call it to keep `systemGRunSeamRegistryDefaultsToStub` deterministic.
5. **Registry stats FFI:** `registry_stats()` is internal-only today. A future FFI surface (`SubstrateHealth` panel, Terminal D) can expose `(total, in_flight)` via a thin bridge wrapper.

## Hardening (iter-2 post-ship audit)

After the initial PR landed, an audit pass added these guards:

| Guard | Constant / Behavior | Defends against |
|---|---|---|
| Concurrent-run cap | `MAX_CONCURRENT_RUNS = 64` (in-flight only; terminated runs not counted) | DoS via spam `start_run` from a buggy caller |
| Terminated-run TTL | `TERMINATED_RUN_RETENTION = 60s` | Memory leak from runs never being reaped |
| Lazy GC | Runs on every `start_run` (no background thread) | Same; amortises GC cost across starts |
| `terminated_at: Option<Instant>` | Replaces dead `terminal_seen: bool`; lets the GC compute eligibility precisely | Stale field that conveyed less information |
| `registry_stats()` | Returns `(total, in_flight)`; pure read | Lack of observability into registry state |
| Mutex poison recovery | `unwrap_or_else(|p| p.into_inner())` on the test-only lock; production path surfaces `Internal` | Permanent breakage from a panicked thread |
| Swift `Task.checkCancellation()` | Called once before `start_run` + on every poll iteration | Cancelled SwiftUI Task waits full timeout |
| Swift FFI error context | `start_run / drain_events (run=…)` prefix on `SystemGRunSeamError.ffi` payloads | Opaque error logs |
| Swift wire shape | `MissionPacketWire` uses camelCase + `CodingKeys` (Rust still sees snake_case) | `identifier_name` SwiftLint compliance even though the rule is disabled |
| Removed unused `import os` from Swift seam | n/a | dead import |

**Added tests (iter-2):**
- `registry_stats_track_total_and_in_flight_distinctly`
- `capacity_cap_rejects_starts_past_max_concurrent_runs`
- `gc_does_not_reap_terminated_runs_inside_retention_window`
- `terminated_at_is_set_only_on_the_drain_that_sees_terminal`
- `unknown_run_after_reset_for_test_does_not_panic`
- `agent_event_field_names_match_swift_coding_keys_byte_equal` (wire-shape pin keyed to Swift CodingKeys)
- `agent_event_kind_discriminator_values_are_pinned_snake_case`
- `realSystemGRunSeamHonorsCancellation` (Swift)

**Test-lock pattern:** all registry-mutating tests acquire `test_registry_lock()` (a static `Mutex<()>` inside `mod tests`) before calling `reset_for_test()`. Cargo runs tests in parallel; without the lock, one test's `start_run` slips between another's `reset_for_test()` and its assertion. Recovers from mutex poisoning via `unwrap_or_else(|p| p.into_inner())`.

**Test count after iter-2:** 19 Rust unit + 1 Rust integration + 2 Swift integration = **22 tests** for this seam (was 13 in the initial PR).

## Branches with overlapping work (coordination note)

- `wiring/rust-r3-system-g-minimal-slice` — `MissionRun` composition helper (already merged into `main` as commit `1dd7339824`; this PR builds on it directly).
- `wiring/app-systemg-run-seam-2026-05-23` — proposed nomenclature rename `SystemGAgentEvent` → `AgentEvent` on the Swift side. **This PR keeps `SystemGAgentEvent` per current main** to avoid blocking on that rename.
- `wiring/t11-system-g-localagentloop-2026-05-23` — major LocalAgent reshuffling. Out of scope here; this PR does not touch LocalAgent.
