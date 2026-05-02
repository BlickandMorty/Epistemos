---
role: detective
slice: sovereign-gate-model-vault-delete-pr9
concept: Sovereign Gate model vault destructive delete migration
index_anchor: MASTER_RESEARCH_INDEX_2026_05_02.md §3.2
tier: Core
canonical_source: /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
sister_sources:
  - /Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
  - /Users/jojo/Downloads/Epistemos/docs/fusion/EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md
code_anchors:
  - /Users/jojo/Downloads/Epistemos/Epistemos/Views/Notes/ModelVaultsSidebarSection.swift:211
  - /Users/jojo/Downloads/Epistemos/Epistemos/Views/Notes/ModelVaultsSidebarSection.swift:539
  - /Users/jojo/Downloads/Epistemos/EpistemosTests/SovereignGateTests.swift:232
deliberations_consulted:
  - docs/fusion/deliberation/sovereign_gate_notes_delete_pr5_deliberation_2026_05_02.md
  - docs/fusion/deliberation/sovereign_gate_chat_delete_pr6_deliberation_2026_05_02.md
  - docs/fusion/deliberation/sovereign_gate_version_delete_pr7_deliberation_2026_05_02.md
  - docs/fusion/deliberation/sovereign_gate_rootview_destructive_pr8_deliberation_2026_05_02.md
quick_capture_consulted: n/a
worktrees_consulted: []
drift:
  detected: false
  canon_says: "Future confirmation-surface migration PRs only after a gate names each exact existing surface"
  code_says: "[paraphrase] Model Vaults sidebar delete alert calls delete(target) directly after alert confirmation."
  canon_path: /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
  code_path: /Users/jojo/Downloads/Epistemos/Epistemos/Views/Notes/ModelVaultsSidebarSection.swift
load_bearing_quote: "Future confirmation-surface migration PRs only after a gate names each exact existing surface"
verdict: open
usefulness: +1
usefulness_reason: Identifies a clean exact destructive surface for the next Sovereign Gate migration.
---

## Findings

- Card 9 allows future confirmation-surface migrations when the exact surface and focused tests are named.
- `ModelVaultsSidebarSection.swift` has existing destructive folder/file delete context-menu flows that set `pendingDeleteTarget`, then the alert primary button calls `delete(target)` directly.
- The production file is clean in the current worktree, unlike the current AgentEvent wrapper, GraphEvent retrieval, and broader graph/runtime candidates.
- Existing Sovereign Gate PR5-PR8 tests use source guards and target-mapping tests that can be mirrored without triggering real Touch ID.

## Open Questions

- None. This is a direct continuation of Card 9's existing destructive-surface migration pattern.

## Recommendation

Proceed with a narrow PR9: add `ModelVaultDeletionSovereignGate`, route the alert primary action through shared `AppBootstrap.sovereignGate.confirm`, preserve `delete(_:)`, and add focused `SovereignGateTests` mapping/source guards.
