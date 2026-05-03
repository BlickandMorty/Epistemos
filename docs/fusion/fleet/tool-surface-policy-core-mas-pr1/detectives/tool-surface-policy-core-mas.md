---
role: detective
slice: tool-surface-policy-core-mas-pr1
concept: Core/MAS visible tool surface policy
index_anchor: MASTER_RESEARCH_INDEX_2026_05_02.md §12
tier: Core
canonical_source: /Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
sister_sources:
  - /Users/jojo/Downloads/Epistemos/docs/fusion/EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md
  - /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
code_anchors:
  - /Users/jojo/Downloads/Epistemos/Epistemos/Bridge/ToolTierBridge.swift:4
  - /Users/jojo/Downloads/Epistemos/EpistemosTests/ToolSurfacePolicyTests.swift:4
  - /Users/jojo/Downloads/Epistemos/agent_core/src/tools/registry.rs:37
deliberations_consulted:
  - docs/fusion/deliberation/hermes_provider_surface_policy_pr8_deliberation_2026_05_02.md
quick_capture_consulted: n/a
worktrees_consulted:
  - main
drift:
  detected: true
  canon_says: "external subprocess surfaces cannot leak into the Core/App Store build"
  code_says: "[paraphrase] Swift surfaced-tool policy hides think and unsupported image generation only."
  canon_path: /Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
  code_path: /Users/jojo/Downloads/Epistemos/Epistemos/Bridge/ToolTierBridge.swift
load_bearing_quote: "Keep the Core/App Store path local-first and clean."
verdict: drift
usefulness: +1
usefulness_reason: Opens a tiny Swift planning-surface guard without changing runtime/tool execution.
---

## Findings
- `MASTER_RESEARCH_INDEX_2026_05_02.md §12` points App Store/MAS hardening to the current release split and MAS state.
- `UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md` says Pro tunnels, Hermes, CLI passthrough, browser/computer-use, Docker, and external subprocess surfaces must not leak into Core/App Store.
- `agent_core/src/tools/registry.rs` already carries a `MAS_RUNTIME_FORBIDDEN_TOOLS` list for runtime registration/preflight.
- `Epistemos/Bridge/ToolTierBridge.swift` is the Swift visible-planning filter, but currently blocks only `think` and unsupported `image_generate`.

## Open questions
- Whether every future external provider name should be blocked by prefix remains a later slice; this one should mirror the existing concrete MAS forbidden names only.

## Recommendation
Add a failing Swift policy test proving known Pro/Research gateway and subprocess tools disappear from visible planning surfaces while bounded local/vault tools remain. Implement the smallest static forbidden-name set in `ToolSurfacePolicy`, borrowing names from the existing Rust MAS runtime guard rather than inventing new routing.
