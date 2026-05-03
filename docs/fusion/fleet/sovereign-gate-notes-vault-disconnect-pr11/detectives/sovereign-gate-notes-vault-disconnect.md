---
role: detective
slice: sovereign-gate-notes-vault-disconnect-pr11
concept: Sovereign Gate Notes Sidebar vault disconnect migration
index_anchor: MASTER_RESEARCH_INDEX_2026_05_02.md §3.2
tier: Core
canonical_source: /Users/jojo/Downloads/Epistemos/docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md
sister_sources:
  - /Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
  - /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
code_anchors:
  - /Users/jojo/Downloads/Epistemos/Epistemos/Views/Notes/NotesSidebar.swift:2778
  - /Users/jojo/Downloads/Epistemos/Epistemos/Sync/VaultSyncService.swift:3463
  - /Users/jojo/Downloads/Epistemos/EpistemosTests/SovereignGateTests.swift:1
deliberations_consulted:
  - docs/fusion/deliberation/sovereign_gate_rootview_destructive_pr8_deliberation_2026_05_02.md
  - docs/fusion/deliberation/sovereign_gate_custom_tool_delete_pr10_deliberation_2026_05_02.md
quick_capture_consulted: n/a
worktrees_consulted: []
drift:
  detected: true
  canon_says: "additional existing confirmation migrations"
  code_says: "[paraphrase] Notes sidebar vault disconnect currently calls VaultConnectionActions.disconnect directly."
  canon_path: /Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
  code_path: /Users/jojo/Downloads/Epistemos/Epistemos/Views/Notes/NotesSidebar.swift
load_bearing_quote: "Single entrypoint (must be): `Epistemos/Sovereign/SovereignGate.swift`"
verdict: open
usefulness: +1
usefulness_reason: Finds a clean remaining destructive Core vault-disconnect control outside the already-gated RootView recovery flow.
---

## Findings

- `MASTER_RESEARCH_INDEX_2026_05_02.md §3.2` anchors shared device-owner auth for destructive actions.
- `UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md` leaves exact additional confirmation migrations open after PR1-PR10.
- `NotesSidebar.swift` has a `Button("Disconnect Vault", role: .destructive)` in `VaultConnectionButton` that directly calls `VaultConnectionActions.disconnect(notesUI:vaultSync:)`.
- `VaultConnectionActions.disconnect` clears the selected vault, resets UI, and moves the app home; this is a destructive local-state transition even though it does not delete vault files.

## Open Questions

- None for this slice. The migration is local Swift UI control flow over an existing app-owned gate.

## Recommendation

Extend the existing Notes Sidebar gate mapper for a vault-disconnect target, route the sidebar menu action through shared `SovereignGate.confirm`, and check that the captured vault URL still matches the current vault after async authorization before calling the original disconnect action.
