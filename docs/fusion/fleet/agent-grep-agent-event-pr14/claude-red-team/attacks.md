---
role: claude-red-team
slice: agent-grep-agent-event-pr14
brief: docs/fusion/deliberation/agent_grep_agent_event_pr14_deliberation_2026_05_02.md
date: 2026-05-02
attacks_total: 1
p0_attacks: 0
p1_attacks: 1
p2_attacks: 0
p3_attacks: 0
verdict: brief-revise
usefulness: +1
usefulness_reason: Caught that whole-worktree diff review is unsafe in this dirty branch; exact staged-diff guard is required before commit.
---

## Attacks

### A1 - Whole-worktree diff includes forbidden unrelated surfaces [P1]

**Surface:** `docs/fusion/deliberation/agent_grep_agent_event_pr14_deliberation_2026_05_02.md:21`

**Attack:** The PR14 gate allows only AgentGrepService/tests and fusion docs, but
the whole worktree diff contains pre-existing unrelated changes in forbidden
surfaces such as `agent_core/**`, `graph-engine/**`, `Epistemos/Views/**`,
`Epistemos/Omega/**`, and Xcode project files. A whole-worktree review therefore
cannot approve PR14.

**Evidence:** Red Team reported examples in `agent_core/src/provider.rs`,
`graph-engine/src/lib.rs`, `Epistemos/Views/Graph/HologramOverlay.swift`, and
`Epistemos.xcodeproj/project.pbxproj`.

**Mitigation proposed:** Treat the whole-worktree finding as a process blocker,
not a code blocker. Before commit, exact-stage only the PR14 allowed files and
run `git diff --cached --name-only` against the PR14 forbidden surfaces. The
slice is approved only if the staged protected-path scan is empty.

## Brief verdict

Brief revise until exact staging proves the committed PR14 diff excludes the
unrelated dirty forbidden paths. Red Team found no isolated PR14 privacy leakage:
AgentGrep arguments exclude query/path/snippet/provenance, results are hit count
only, failures use `backend_failure`, and focused tests cover success/failure
sanitization.
