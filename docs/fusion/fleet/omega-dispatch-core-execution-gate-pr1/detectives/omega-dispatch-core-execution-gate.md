---
role: detective
slice: omega-dispatch-core-execution-gate-pr1
concept: Omega dispatch Core execution gate
index_anchor: MASTER_RESEARCH_INDEX_2026_05_02.md §6, §12, §22.1
tier: Core
canonical_source: /Users/jojo/Downloads/Epistemos/docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md
sister_sources:
  - /Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
  - /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
code_anchors:
  - /Users/jojo/Downloads/Epistemos/Epistemos/Omega/MCPBridge.swift:261
  - /Users/jojo/Downloads/Epistemos/omega-mcp/src/dispatcher.rs:207
  - /Users/jojo/Downloads/Epistemos/EpistemosTests/OmegaToolSchemaGrammarTests.swift:186
deliberations_consulted:
  - docs/fusion/deliberation/omega_tool_registry_core_planning_pr1_deliberation_2026_05_02.md
quick_capture_consulted: n/a
worktrees_consulted:
  - none
drift:
  detected: true
  canon_says: "runtime MCP registration and dispatch remain untouched"
  code_says: "[paraphrase] dispatch still forwards all JSON-RPC calls to the Rust dispatcher"
  canon_path: /Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
  code_path: /Users/jojo/Downloads/Epistemos/Epistemos/Omega/MCPBridge.swift
load_bearing_quote: "MCP / omega-mcp crate"
verdict: open
usefulness: +1
usefulness_reason: Converts the approved planning-surface follow-on into a concrete runtime dispatch gate.
---

## Findings
- `MASTER_RESEARCH_INDEX_2026_05_02.md §6` maps Hermes/MCP/Omega code anchors and keeps MCP gateway surfaces out of Core unless explicitly gated.
- `MASTER_RESEARCH_INDEX_2026_05_02.md §12` names MAS hardening as canonical state, so Core/App Store must fail closed on Pro execution surfaces.
- `MCPBridge.dispatch(_:)` currently forwards every JSON-RPC request to `McpDispatcher.dispatch` with no distribution-aware policy check.
- `omega-mcp/src/dispatcher.rs` treats `tools/list` and `tools/call` as registry-level operations; Swift can gate those methods before runtime execution without touching Rust.

## Open questions
- Should runtime dispatch unregister tools per distribution? No: that would mutate runtime registration and exceed this slice. Gate the Swift entrypoint only.

## Recommendation
Add a Swift-side distribution parameter to `MCPBridge.dispatch`, defaulting to `.currentBuild`. For Core/App Store, return a filtered `tools/list` response and a JSON-RPC "Tool not found" error for disallowed `tools/call` names before the Rust dispatcher sees the request. Keep Pro/Research behavior unchanged and add focused tests for Core deny/allow/list behavior.
