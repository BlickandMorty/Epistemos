---
role: claude-red-team
slice: overseer-core-mas-tool-permission-fallback-pr1
brief: docs/fusion/deliberation/overseer_core_mas_tool_permission_fallback_pr1_deliberation_2026_05_03.md
date: 2026-05-03
attacks_total: 1
p0_attacks: 0
p1_attacks: 0
p2_attacks: 1
p3_attacks: 0
verdict: brief-approved
usefulness: +1
usefulness_reason: Codex fallback red-team added one source-guard mitigation; no P0/P1 blockers.
---

## Attacks

### A1 - Helper tested but route wiring can silently drift [P2]

**Surface:** `OverseerComplexityRouter.toolPermissions(for:)`.
**Attack:** The brief's proposed tests exercise the fallback helper directly, but a future edit could leave `toolPermissions(for:)` calling the old literal fallback and still pass helper-only tests. This is not a blocker if the implementation adds either behavior coverage or a shell source guard proving the private route fallback delegates to `fallbackToolPermissions`.
**Evidence:** `/Users/jojo/Downloads/Epistemos/Epistemos/Engine/OverseerProtocol.swift:893`
**Mitigation proposed:** Add a shell source-shape guard that extracts the private `toolPermissions(for:)` body and proves it contains `Self.fallbackToolPermissions(distribution: .currentBuild)` with no direct `OverseerToolPermission(toolName: "run_command"` literal. Do not run this as a Swift Testing source-read because the first green attempt showed that source-shape test can hang the hosted app harness.

## Brief Verdict

Approved after adding the source-guard mitigation. The slice stays inside `OverseerProtocol` and `OverseerProtocolTests`, does not widen Core allow-list policy, and avoids ToolTier/Omega/Rust/runtime/provider work.
