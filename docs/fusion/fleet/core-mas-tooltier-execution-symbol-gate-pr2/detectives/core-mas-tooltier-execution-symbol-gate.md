---
role: detective
slice: core-mas-tooltier-execution-symbol-gate-pr2
concept: Core/MAS ToolTier execution symbol gate
index_anchor: MASTER_RESEARCH_INDEX_2026_05_02.md §12
tier: Core
canonical_source: /Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
sister_sources:
  - /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
  - /Users/jojo/Downloads/Epistemos/docs/fusion/deliberation/omega_dispatch_core_execution_gate_pr1_deliberation_2026_05_02.md
  - /Users/jojo/Downloads/Epistemos/docs/fusion/deliberation/command_center_tool_surface_policy_pr1_deliberation_2026_05_02.md
code_anchors:
  - /Users/jojo/Downloads/Epistemos/Epistemos/Bridge/ToolTierBridge.swift:217
  - /Users/jojo/Downloads/Epistemos/Epistemos/Omega/MCPBridge.swift:260
  - /Users/jojo/Downloads/Epistemos/EpistemosTests/ToolSurfacePolicyTests.swift:29
deliberations_consulted:
  - docs/fusion/deliberation/omega_dispatch_core_execution_gate_pr1_deliberation_2026_05_02.md
  - docs/fusion/deliberation/command_center_tool_surface_policy_pr1_deliberation_2026_05_02.md
quick_capture_consulted: n/a
worktrees_consulted: []
drift:
  detected: false
  canon_says: "MAS/Core versus Pro capability symbol separation."
  code_says: "ToolTierBridge filters visible tools but does not preflight execution names before bridged execution."
  canon_path: /Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
  code_path: /Users/jojo/Downloads/Epistemos/Epistemos/Bridge/ToolTierBridge.swift
load_bearing_quote: "Core/App Store path local-first and clean"
verdict: open
usefulness: +1
usefulness_reason: Finds a narrow runtime seam after visible/planning symbol separation was closed.
---

## Findings

- Current state keeps `MAS/Core versus Pro capability symbol separation` open at `UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md:958`.
- Workcard Card 10 says visible/planning surfaces are closed, but runtime/provider routing still needs exact gates at `AGENT_BUILD_WORKCARDS_2026_05_01.md:2159`.
- `MCPBridge.dispatch(_:distribution:)` already has a runtime call-deny pattern before Rust dispatch.
- `ToolTierBridge.toolExecutor()` captures `allowedToolNames` but not a distribution policy, so an explicit stale Pro-only tool name can reach the bridged executor path.

## Open Questions

- None for this slice. Provider routing and Hermes subprocess behavior remain future gates.

## Recommendation

Add `ToolSurfacePolicy.Distribution` to `ToolTierBridge`, use it for both `loadTools()` and `toolExecutor()`, and deny non-surfaced Core/App Store tool names with a local error result before any Rust FFI call.
