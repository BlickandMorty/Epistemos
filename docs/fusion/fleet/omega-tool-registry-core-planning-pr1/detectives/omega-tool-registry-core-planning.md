---
role: detective
slice: omega-tool-registry-core-planning-pr1
concept: Omega planner schema Core/MAS visibility
index_anchor: MASTER_RESEARCH_INDEX_2026_05_02.md §12
tier: Core
canonical_source: /Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
sister_sources:
  - /Users/jojo/Downloads/Epistemos/docs/fusion/EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md
  - /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
code_anchors:
  - /Users/jojo/Downloads/Epistemos/Epistemos/Omega/MCPBridge.swift:69
  - /Users/jojo/Downloads/Epistemos/Epistemos/Bridge/ToolTierBridge.swift:4
  - /Users/jojo/Downloads/Epistemos/EpistemosTests/OmegaToolSchemaGrammarTests.swift:156
deliberations_consulted:
  - docs/fusion/deliberation/tool_surface_policy_core_mas_pr1_deliberation_2026_05_02.md
quick_capture_consulted: n/a
worktrees_consulted:
  - main
drift:
  detected: true
  canon_says: "external subprocess surfaces cannot leak into the Core/App Store build"
  code_says: "[paraphrase] Omega planning schemas and prompt block are built from the full MCP catalog."
  canon_path: /Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
  code_path: /Users/jojo/Downloads/Epistemos/Epistemos/Omega/MCPBridge.swift
load_bearing_quote: "Keep the Core/App Store path local-first and clean."
verdict: drift
usefulness: +1
usefulness_reason: Finds a second visible-planning surface after the ToolSurfacePolicy guard landed.
---

## Findings
- `OmegaToolRegistry.planningSchemasJson` and `planningPromptBlock()` currently derive from `OmegaToolRegistry.all`.
- The full Omega catalog includes terminal, automation, and computer-use agents such as `run_command`, `get_ui_tree`, and `see`.
- Round 39 added `ToolSurfacePolicy` as the canonical Swift visible-surface filter, but Omega planner helpers do not yet call it.

## Open questions
- None for this slice; runtime registration/execution remains out of scope.

## Recommendation
Add distribution-aware Omega planning helpers that route through `ToolSurfacePolicy.surfacedTools`, then keep the legacy default current-build helpers while adding explicit Core/App Store tests for prompt and JSON schema filtering.
