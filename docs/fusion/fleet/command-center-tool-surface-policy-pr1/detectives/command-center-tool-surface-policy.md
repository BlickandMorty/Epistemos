---
role: detective
slice: command-center-tool-surface-policy-pr1
concept: Agent Command Center Core/MAS visible context provider surface
index_anchor: MASTER_RESEARCH_INDEX_2026_05_02.md §12
tier: Core
canonical_source: /Users/jojo/Downloads/Epistemos/docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md
sister_sources:
  - /Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
  - /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
code_anchors:
  - /Users/jojo/Downloads/Epistemos/Epistemos/State/AgentCommandCenterState.swift:298
  - /Users/jojo/Downloads/Epistemos/Epistemos/Bridge/ToolTierBridge.swift:4
  - /Users/jojo/Downloads/Epistemos/EpistemosTests/AgentCommandCenterStateTests.swift:431
deliberations_consulted:
  - docs/fusion/deliberation/tool_surface_policy_core_mas_pr1_deliberation_2026_05_02.md
  - docs/fusion/deliberation/omega_dispatch_core_execution_gate_pr1_deliberation_2026_05_02.md
quick_capture_consulted: n/a
worktrees_consulted:
  - main
drift:
  detected: true
  canon_says: "NO shell, Bash, Docker, CLI, iMessage, background agents."
  code_says: "[paraphrase] ACC context providers always include Safari, Terminal, Notes, Files, and Automation."
  canon_path: /Users/jojo/Downloads/Epistemos/docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md
  code_path: /Users/jojo/Downloads/Epistemos/Epistemos/State/AgentCommandCenterState.swift
load_bearing_quote: "NO shell, Bash, Docker, CLI, iMessage, background agents."
verdict: drift
usefulness: +1
usefulness_reason: Identifies a remaining user-visible Core/MAS surface not covered by the closed Omega dispatch gate.
---

## Findings
- `MASTER_RESEARCH_INDEX_2026_05_02.md §12` defines the App Store profile as bounded execution with no shell/CLI/background-agent surface.
- `UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md §4` says Pro tunnels, Hermes, CLI passthrough, browser/computer-use, Docker, and subprocess surfaces must not leak into Core/App Store.
- `AgentCommandCenterState.refreshContextProviders(...)` still appends `Safari`, `Terminal`, and `Automation` as agent context providers without checking the active distribution.
- The ACC tool catalog itself already uses `ToolTierBridge.loadTools()`, which filters loaded tools through `ToolSurfacePolicy.surfacedTools(...)`; the context-provider list is the narrower remaining gap.

## Open questions
- Whether `Safari` should be treated as web-search or as browser/computer-use automation. The conservative Core/MAS answer is to hide it because it is an agent context provider, not a bounded web-search tool definition.

## Recommendation
Add a tiny distribution-aware context-provider gate inside `AgentCommandCenterState`, defaulting to current build behavior, and keep only `Notes` and `Files` built-in agent mentions visible for `.coreAppStore`. Preserve all Pro/Research agent mentions.
