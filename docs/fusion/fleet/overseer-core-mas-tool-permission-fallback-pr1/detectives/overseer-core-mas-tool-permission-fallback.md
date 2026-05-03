---
role: detective
slice: overseer-core-mas-tool-permission-fallback-pr1
concept: Core/MAS Overseer fallback tool permissions
index_anchor: MASTER_RESEARCH_INDEX_2026_05_02.md §12
tier: Core
canonical_source: /Users/jojo/Downloads/Epistemos/docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md
sister_sources:
  - /Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
  - /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
code_anchors:
  - /Users/jojo/Downloads/Epistemos/Epistemos/Engine/OverseerProtocol.swift:893
  - /Users/jojo/Downloads/Epistemos/Epistemos/Bridge/ToolTierBridge.swift:11
  - /Users/jojo/Downloads/Epistemos/EpistemosTests/OverseerProtocolTests.swift:1
deliberations_consulted:
  - docs/fusion/deliberation/core_mas_tooltier_execution_symbol_gate_pr2_deliberation_2026_05_03.md
quick_capture_consulted: n/a
worktrees_consulted:
  - none
drift:
  detected: true
  canon_says: "App Store profile: bounded execution only"
  code_says: "[paraphrase] Overseer fallback permissions include run_command when OmegaToolRegistry yields no live permissions."
  canon_path: /Users/jojo/Downloads/Epistemos/docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md
  code_path: /Users/jojo/Downloads/Epistemos/Epistemos/Engine/OverseerProtocol.swift:917
load_bearing_quote: "Core/App Store path local-first and clean"
verdict: drift
usefulness: +1
usefulness_reason: Surfaces a real degraded-registry fallback leak after ToolTier execution gating was closed.
---

## Findings

- `MASTER_RESEARCH_INDEX_2026_05_02.md` §12 makes the App Store profile bounded execution only and excludes shell/Docker/CLI/background-agent style surfaces.
- `AGENT_BUILD_WORKCARDS_2026_05_01.md` Card 10 says Core/App Store must stay local-first and clean.
- `Epistemos/Bridge/ToolTierBridge.swift:11` already owns `ToolSurfacePolicy.coreAppStoreAllowedToolNames`; the fallback should reuse that policy instead of maintaining a second hand-written Core decision.
- `Epistemos/Engine/OverseerProtocol.swift:917` returns a hardcoded fallback list when live registry-derived permissions are empty; this list includes `search_web`, `open_url`, and `run_command`.

## Open Questions

- None blocking. This is a pure Core policy fallback gate and does not require runtime routing or UI work.

## Recommendation

Add a small `OverseerComplexityRouter.fallbackToolPermissions(distribution:)` helper that preserves the existing fallback in Pro/Research but filters it through `ToolSurfacePolicy` for Core/App Store. Add focused tests proving Core fallback denies `run_command`, `open_url`, and `search_web` while keeping allowed Core names.
