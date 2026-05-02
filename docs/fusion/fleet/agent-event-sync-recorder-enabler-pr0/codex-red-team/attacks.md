---
role: codex-red-team
slice: agent-event-sync-recorder-enabler-pr0
brief: docs/fusion/deliberation/agent_event_sync_recorder_enabler_pr0_deliberation_2026_05_02.md
date: 2026-05-02
attacks_total: 2
p0_attacks: 0
p1_attacks: 0
p2_attacks: 2
p3_attacks: 0
verdict: brief-approved
usefulness: +1
usefulness_reason: Approves the enabler but adds two concrete test expectations before implementation.
---

## Attacks

### A1 - Shared construction must preserve existing optional-field semantics [P2]
**Surface:** `Epistemos/Engine/AgentToolProvenanceRecorder.swift`.
**Attack:** Extracting a shared factory can subtly change existing behavior. The current recorder turns empty optional fields into nil, defaults empty `argumentsJSON` to `{}`, and preserves non-empty JSON payload text. If the shared helper trims or rewrites payloads differently, older AgentEvent tests may still pass while privacy/source semantics drift.
**Evidence:** `AgentToolProvenanceRecorder.recordToolEvent(...)` currently routes `traceID`, `argumentsJSON`, `resultJSON`, `approvalID`, and `errorMessage` through `normalizedOptional`.
**Mitigation proposed:** Add focused assertions for empty optional identity rejection, default `{}` arguments, and unchanged non-empty result JSON in the sync recorder tests.

### A2 - Separate recorder instances can collide if callers reuse run IDs [P2]
**Surface:** future PR20 consumer usage.
**Attack:** Both existing and proposed recorders allocate sequences locally. If future code creates two recorder instances for the same run ID, event IDs can collide and EventStore will update the earlier row. This is not new in this slice, but the brief should preserve the existing discipline: one recorder per emitting service or unique run IDs per operation.
**Evidence:** Current event ID shape is `agent-event:<runID>:<sequence>`, and `EventStore.saveAgentEvent(_:)` uses `ON CONFLICT(event_id) DO UPDATE`.
**Mitigation proposed:** Keep this enabler scoped to primitive creation, and add a test that one sync-recorder instance preserves ordered sequences for one run. Leave cross-instance global sequencing out of scope and state PR20 must use a unique run ID per sync operation.

## Brief Verdict

Ship the brief with the two P2 mitigations folded into tests. No P0/P1 blocker remains. The slice stays Core-safe, has no Sovereign touchpoint, and avoids the forbidden PR20 main-actor bridge.
