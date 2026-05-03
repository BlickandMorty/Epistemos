---
role: claude-red-team
slice: phase4-screen-watch-agent-event-pr42
brief: docs/fusion/deliberation/phase4_screen_watch_agent_event_pr42_deliberation_2026_05_03.md
date: 2026-05-03
attacks_total: 1
p0_attacks: 0
p1_attacks: 0
p2_attacks: 1
p3_attacks: 0
verdict: brief-approved
usefulness: +1
usefulness_reason: Confirms the brief is safe if it records only lifecycle events and does not turn the watch loop into telemetry.
---

## Attacks

### A1 - Per-poll telemetry would create hot-loop provenance noise [P2]

**Surface:** `Phase4Bridge.startScreenWatch(watchJson:)` polling loop.
**Attack:** The brief could be misread as permission to emit AgentEvents on every poll iteration. That would create high-volume runtime noise and persist too much operational detail for file/AX watch surfaces.
**Evidence:** `Epistemos/Bridge/Phase4Bridge.swift`; `docs/fusion/deliberation/phase4_screen_watch_agent_event_pr42_deliberation_2026_05_03.md`.
**Mitigation proposed:** Emit lifecycle-only requested, started, and terminal completed/failed events. Persist bounded mode/scope/bucket/result classes only; never persist raw watch JSON, file paths, or per-poll observations.

## Brief verdict

Approved. No P0/P1 attacks remain if implementation preserves existing returned watch payloads, records only terminal lifecycle provenance, and keeps raw path/watch payload data out of AgentEvent arguments/results/errors.
