---
role: detective
slice: mcpbridge-tools-call-denial-provenance-pr35
concept: MCPBridge Core tools/call denial AgentEvent provenance
index_anchor: MASTER_RESEARCH_INDEX_2026_05_02.md §6
tier: Core
canonical_source: /Users/jojo/Downloads/Epistemos/docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md
sister_sources:
  - /Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
  - /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
code_anchors:
  - /Users/jojo/Downloads/Epistemos/Epistemos/Omega/MCPBridge.swift:260
  - /Users/jojo/Downloads/Epistemos/Epistemos/Bridge/ToolTierBridge.swift:38
  - /Users/jojo/Downloads/Epistemos/Epistemos/Engine/AgentToolProvenanceRecorder.swift:26
deliberations_consulted:
  - docs/fusion/deliberation/agent_event_v16_forward_variants_pr34_deliberation_2026_05_03.md
quick_capture_consulted: n/a
worktrees_consulted:
  - none
drift:
  detected: false
  canon_says: "Core/App Store `tools/call` denies terminal/automation/computer-use tools"
  code_says: "[paraphrase] MCPBridge returns JSON-RPC Tool not found before dispatcher dispatch."
  canon_path: /Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
  code_path: /Users/jojo/Downloads/Epistemos/Epistemos/Omega/MCPBridge.swift
load_bearing_quote: "MCP discovery, tool advertisement, capability negotiation"
verdict: open
usefulness: +1
usefulness_reason: Identifies a closed Core denial gate that still lacks durable AgentEvent evidence.
---

## Findings

- `MASTER_RESEARCH_INDEX_2026_05_02.md §6` anchors MCP/omega-mcp as the relevant concept and names discovery, advertisement, and capability negotiation as the domain to preserve.
- `UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md:1116` says Omega Dispatch Core Execution Gate PR1 is code-closed, with `tools/call` denial happening before Rust dispatch.
- `AGENT_BUILD_WORKCARDS_2026_05_01.md:2521` mirrors the workcard state: Core/App Store `tools/call` denies terminal/automation/computer-use tools as "Tool not found."
- `Epistemos/Omega/MCPBridge.swift:260` currently gates `dispatch(_:distribution:)`, but it does not persist AgentEvent requested/denied provenance for policy-denied calls.
- `Epistemos/Engine/AgentToolProvenanceRecorder.swift:26` already provides the bounded recorder API needed for a two-event requested/denied lifecycle.

## Open questions

- None blocking. The slice should avoid raw JSON-RPC request bodies, arguments, results, paths, and arbitrary denial messages in persisted AgentEvent payloads.

## Recommendation

Add an injectable provenance recorder to `MCPBridge`, record only sanitized `.toolCallRequested` and `.toolCallDenied` events for Core policy-denied `tools/call`, and prove Core-safe calls and Pro/Research fallthrough do not emit false denial provenance.
