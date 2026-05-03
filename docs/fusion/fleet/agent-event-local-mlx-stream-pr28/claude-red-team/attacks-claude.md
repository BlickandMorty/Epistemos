---
role: claude-red-team
slice: agent-event-local-mlx-stream-pr28
brief: docs/fusion/deliberation/agent_event_local_mlx_stream_pr28_deliberation_2026_05_03.md
date: 2026-05-03
attacks_total: 8
p0_attacks: 2
p1_attacks: 6
p2_attacks: 0
p3_attacks: 0
verdict: brief-revise
usefulness: +1
usefulness_reason: Caught missing file-scope and cancellation-provenance requirements before code.
---

## Attacks

### A1 - Missing explicit file scope [P0]

**Surface:** Deliberation brief scope.
**Attack:** The brief had non-goals but no explicit allowed/forbidden file list. A builder could touch AppBootstrap, EventStore, generated bindings, or UI and still claim compliance.
**Evidence:** `docs/fusion/deliberation/agent_event_local_mlx_stream_pr28_deliberation_2026_05_03.md`
**Mitigation proposed:** Add an allowed-files section limited to `MLXInferenceService.swift`, `LocalBackendLLMClientTests.swift`, and PR28 docs; explicitly forbid UI, graph, Rust, generated bindings, schema, Hermes/MCP, browser/computer-use, LocalAuthentication, ANE/private API, routing, model loading, and AppBootstrap remounting.

### A2 - Cancellation terminal state was under-specified [P0]

**Surface:** `LocalMLXClient.stream(...)` cancellation branch.
**Attack:** The stream method has a distinct cancellation path via `continuation.onTermination` and `finishCancelled`. Without acceptance/tests, cancellation could be mislabeled failed/completed or dropped from AgentEvent provenance.
**Evidence:** `/Users/jojo/Downloads/Epistemos/Epistemos/Engine/MLXInferenceService.swift:818`
**Mitigation proposed:** Require cancelled AgentEvents with `status=failed`, `failure_class=cancelled`, bounded error text, and cancellation-focused test coverage.

### A3 - AppBootstrap injection ambiguity [P1]

**Surface:** Brief non-goals.
**Attack:** PR27 already injected the recorder; PR28 should clarify that AppBootstrap must not be edited.
**Evidence:** `docs/fusion/deliberation/agent_event_local_mlx_stream_pr28_deliberation_2026_05_03.md`
**Mitigation proposed:** State no AppBootstrap edits are allowed because PR27 already mounted the recorder.

### A4 - Tool identity could drift [P1]

**Surface:** Tool naming.
**Attack:** The brief used `local_stream.mlx` and `local-mlx-stream:N` without explaining that one is tool name and one is tool call id.
**Evidence:** `docs/fusion/fleet/agent-event-local-mlx-stream-pr28/aggregator.md`
**Mitigation proposed:** Declare `toolName=local_stream.mlx`, `toolCallID=local-mlx-stream:N`, and `runID=local-mlx-stream-...`.

### A5 - Failure result should include partial counts [P1]

**Surface:** Failure provenance.
**Attack:** A stream can fail after yielding chunks. Persisting bounded `chunk_count` and `output_char_count` helps diagnose without leaking text.
**Evidence:** `/Users/jojo/Downloads/Epistemos/Epistemos/Engine/MLXInferenceService.swift:804`
**Mitigation proposed:** Include `chunk_count` and `output_char_count` on completed, failed, and cancelled terminal results.

### A6 - Zero-chunk completion undefined [P1]

**Surface:** Completion provenance.
**Attack:** A stream may complete with zero chunks. The result should record `chunk_count=0`, not omit it.
**Evidence:** `/Users/jojo/Downloads/Epistemos/Epistemos/Engine/MLXInferenceService.swift:804`
**Mitigation proposed:** Always include `chunk_count`.

### A7 - Consumer-drop semantics undefined [P1]

**Surface:** `continuation.onTermination`.
**Attack:** Consumer drop cancels the stream task. The brief needs this to map to bounded cancelled provenance.
**Evidence:** `/Users/jojo/Downloads/Epistemos/Epistemos/Engine/MLXInferenceService.swift:865`
**Mitigation proposed:** Treat consumer drop as the same cancelled terminal AgentEvent path.

### A8 - Test-count guard too vague [P1]

**Surface:** Failure-proof guardrails.
**Attack:** The old "12 tests" line was not tied to the new cancellation requirement and could pass after silently losing a test.
**Evidence:** `docs/fusion/fleet/agent-event-local-mlx-stream-pr28/aggregator.md`
**Mitigation proposed:** Update the guard to the expected focused suite count after adding success, failure, and cancellation tests.

## Brief verdict

The brief needed revision before implementation. All attacks are actionable within the same narrow slice.
