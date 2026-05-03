---
role: codex-red-team
slice: agent-event-local-gguf-generate-pr24
brief: docs/fusion/deliberation/agent_event_local_gguf_generate_pr24_deliberation_2026_05_03.md
date: 2026-05-03
attacks_total: 1
p0_attacks: 0
p1_attacks: 0
p2_attacks: 1
p3_attacks: 0
verdict: brief-approved
usefulness: +1
usefulness_reason: Tightened the privacy boundary to exclude model IDs from persisted GGUF AgentEvents.
---

## Attacks

### A1 - Model IDs should be treated like model paths for this provenance slice [P2]
**Surface:** `Acceptance` and `Stop triggers` in the PR24 brief.
**Attack:** The brief originally excluded model URLs and artifact IDs but did not explicitly exclude model IDs. Prior PR23 excluded model IDs, and local model IDs can still reveal a private prepared model choice. This is not a blocker if the implementation keeps `AgentProvenanceActor.agent(..., modelID: nil)` and records only bounded runtime/provider categories.
**Evidence:** `docs/fusion/deliberation/agent_event_local_gguf_generate_pr24_deliberation_2026_05_03.md`; `docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md` PR23 closure says persisted provenance excludes model id.
**Mitigation proposed:** Revise the brief before implementation to explicitly forbid model ID persistence in arguments, results, errors, actor model ID, and metadata.

## Brief Verdict

Approved after mitigation. No P0/P1 issues remain: the slice is Core-only, has no Sovereign Gate touchpoint, stays in a clean local runtime file, avoids stream semantics, and does not authorize Hermes, MCP, subprocess, graph, Rust, generated binding, EventStore schema, or UI work.

CLAUDE-RETURN: role=RED-TEAM | slice=agent-event-local-gguf-generate-pr24 | round=55 | artifact=docs/fusion/fleet/agent-event-local-gguf-generate-pr24/claude-red-team/attacks.md | usefulness=+1 | p0=0 | p1=0
