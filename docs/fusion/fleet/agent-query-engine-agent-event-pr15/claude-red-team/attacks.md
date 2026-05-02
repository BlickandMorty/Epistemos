---
role: claude-red-team
slice: agent-query-engine-agent-event-pr15
brief: docs/fusion/deliberation/agent_query_engine_agent_event_pr15_deliberation_2026_05_02.md
date: 2026-05-02
attacks_total: 2
p0_attacks: 0
p1_attacks: 0
p2_attacks: 2
p3_attacks: 0
verdict: brief-approved
usefulness: +1
usefulness_reason: Tightens privacy and dirty-tree staging requirements before code begins.
---

## Attacks

### A1 — Backend stream inputs and outputs can leak sensitive data [P2]
**Surface:** `AgentQueryEngine.swift` `.toolUse` and `.toolResult` handling.
**Attack:** Backend `toolUse` input `Data` and `toolResult` output strings may contain prompts, file paths, source snippets, credentials, or model output. If persisted directly, PR15 would become a privacy regression.
**Evidence:** `AgentBackend.swift:41` carries raw `input: Data`; `AgentQueryEngine.swift:225` carries raw `output: String`.
**Mitigation proposed:** Persist only tool call id/name, output byte count, error boolean, turn index, backend id, and model id. Tests must assert prompt, history, cwd, tool input, and output text are absent from all AgentEvents.

### A2 — Whole-worktree dirty scope can make an otherwise clean slice unsafe [P2]
**Surface:** Commit boundary.
**Attack:** The repository has unrelated dirty files under graph, views, Omega, Rust, Xcode, and docs. A broad stage would violate the brief's forbidden write set even if PR15 code is correct.
**Evidence:** Round 10 `git status --short` shows large unrelated dirty state.
**Mitigation proposed:** Exact-stage only PR15 files and run a staged protected-path scan before commit.

## Brief verdict
Ship the brief after enforcing the privacy tests and staged protected-path scan. No P0/P1 blocker remains.
