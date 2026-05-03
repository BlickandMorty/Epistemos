---
role: claude-red-team
slice: phase7-nightbrain-trigger-provenance-pr36
brief: docs/fusion/deliberation/phase7_nightbrain_trigger_provenance_pr36_deliberation_2026_05_03.md
date: 2026-05-03
attacks_total: 1
p0_attacks: 0
p1_attacks: 0
p2_attacks: 1
p3_attacks: 0
verdict: brief-approved
usefulness: +1
usefulness_reason: Catches the main sanitization risk and confirms it is covered by acceptance tests.
---

## Attacks

### A1 - Raw request strings could leak into AgentEvent payloads [P2]
**Surface:** `Phase7Bridge.triggerNightbrainJob(jobType:priority:)`
**Attack:** The bridge receives raw agent-provided `jobType` and `priority` strings. If those are copied into AgentEvent arguments/results/errors, a malicious or accidental request can persist paths, note names, or prompt text.
**Evidence:** `MASTER_RESEARCH_INDEX_2026_05_02.md` §22.1 local-first validation protocol; Card 7 sanitization requirements.
**Mitigation proposed:** Persist only canonical supported job enum raw values, bounded priority classes, boolean supported flags, and bounded failure classes. Tests should encode captured events and assert raw unsupported job strings and path-like priority text are absent.

## Brief verdict
Approved. No P0/P1 attacks remain if the implementation keeps raw response text separate from persisted AgentEvent fields and tests prove the persisted event payloads are sanitized.
