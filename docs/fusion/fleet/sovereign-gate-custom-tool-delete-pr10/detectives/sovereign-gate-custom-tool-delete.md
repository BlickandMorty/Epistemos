---
role: detective
slice: sovereign-gate-custom-tool-delete-pr10
concept: Sovereign Gate custom tool destructive delete migration
index_anchor: MASTER_RESEARCH_INDEX_2026_05_02.md §3.2
tier: Core
canonical_source: /Users/jojo/Downloads/Epistemos/docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md
sister_sources:
  - /Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
  - /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
code_anchors:
  - /Users/jojo/Downloads/Epistemos/Epistemos/Views/Settings/AgentControlSettingsView.swift:452
  - /Users/jojo/Downloads/Epistemos/Epistemos/Views/Settings/AgentControlSettingsView.swift:867
  - /Users/jojo/Downloads/Epistemos/Epistemos/Sovereign/SovereignGate.swift:1
  - /Users/jojo/Downloads/Epistemos/EpistemosTests/SovereignGateTests.swift:1
deliberations_consulted:
  - docs/fusion/deliberation/sovereign_gate_model_vault_delete_pr9_deliberation_2026_05_02.md
quick_capture_consulted: n/a
worktrees_consulted: []
drift:
  detected: true
  canon_says: "additional existing confirmation migrations"
  code_says: "[paraphrase] Custom tool delete currently calls deleteCustomTool directly from the destructive button."
  canon_path: /Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
  code_path: /Users/jojo/Downloads/Epistemos/Epistemos/Views/Settings/AgentControlSettingsView.swift
load_bearing_quote: "Single entrypoint (must be): `Epistemos/Sovereign/SovereignGate.swift`"
verdict: open
usefulness: +1
usefulness_reason: Identifies a clean remaining destructive Core confirmation surface not yet routed through the shared gate.
---

## Findings

- `MASTER_RESEARCH_INDEX_2026_05_02.md §3.2` anchors Sovereign Gate as the single native authorization membrane for Touch ID / device-owner auth.
- `UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md` allows exact additional existing confirmation migrations after PR1-PR9.
- `AGENT_BUILD_WORKCARDS_2026_05_01.md` Card 9 requires future confirmation-surface migrations to name the exact surface and focused tests.
- `AgentControlSettingsView.swift` currently exposes `Button("Delete")` for custom tools and calls `deleteCustomTool(named:vaultPath:)` directly.
- The delete target is an external tool spec, so the existing accessibility hint already labels the action as permanent.

## Open Questions

- None for this slice. No web validation is needed because this is local Swift control flow over an existing app-owned gate.

## Recommendation

Add a small custom-tool deletion mapper in `AgentControlSettingsView.swift`, route the existing button through `AppBootstrap.shared?.sovereignGate.confirm(.deviceOwnerAuthentication, reason: ...)`, and keep `deleteCustomTool(named:vaultPath:)` unchanged behind the allowed outcome. Add source-guard tests proving no local biometric APIs appear in the settings view.
