---
role: claude-red-team
slice: mcpbridge-tools-call-denial-provenance-pr35
brief: docs/fusion/deliberation/mcpbridge_tools_call_denial_provenance_pr35_deliberation_2026_05_03.md
date: 2026-05-03
attacks_total: 1
p0_attacks: 0
p1_attacks: 0
p2_attacks: 1
p3_attacks: 0
verdict: brief-approved
usefulness: +1
usefulness_reason: Confirms the brief is safe if implementation records sanitized requested/denied only and tests prove no raw argument leakage.
---

## Attacks

### A1 - Recorder injection could accidentally persist raw MCP payloads [P2]
**Surface:** `Epistemos/Omega/MCPBridge.swift` denied `tools/call` branch.
**Attack:** The policy branch currently sees the full JSON-RPC request. If implementation passes `requestJson`, `params.arguments`, or the serialized denial response into `AgentToolProvenanceRecorder`, Core may persist commands, paths, prompts, or result payloads that the policy gate exists to hide.
**Evidence:** `MCPBridge.swift:304` parses `tools/call`; `MASTER_RESEARCH_INDEX_2026_05_02.md §6` makes this an MCP boundary.
**Mitigation proposed:** Use a fixed sanitized arguments JSON, nil result JSON, generic denial error, and tests that inject secret command/path strings into the denied request and assert the encoded AgentEvents do not contain them.

## Brief verdict

Ship the brief. It has no P0/P1 blockers because the allowed path is a single Swift chokepoint, bounded event emission only, and explicit non-leakage tests before implementation acceptance.
