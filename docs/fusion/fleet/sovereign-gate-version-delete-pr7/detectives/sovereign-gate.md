---
role: detective
slice: sovereign-gate-version-delete-pr7
concept: Sovereign Gate destructive confirmation
index_anchor: MASTER_RESEARCH_INDEX_2026_05_02.md §3.2
tier: Core
canonical_source: /Users/jojo/Downloads/Epistemos/docs/fusion/EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md
sister_sources:
  - /Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
  - /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
code_anchors:
  - /Users/jojo/Downloads/Epistemos/Epistemos/Sovereign/SovereignGate.swift
  - /Users/jojo/Downloads/Epistemos/Epistemos/Views/Notes/DiffSheetView.swift:218
deliberations_consulted:
  - docs/fusion/deliberation/sovereign_gate_core_pr1_deliberation_2026_05_02.md
  - docs/fusion/deliberation/sovereign_gate_notes_delete_pr5_deliberation_2026_05_02.md
  - docs/fusion/deliberation/sovereign_gate_chat_delete_pr6_deliberation_2026_05_02.md
quick_capture_consulted: n/a
worktrees_consulted:
  - main
drift:
  detected: true
  canon_says: "Every confirmation surface in the app"
  code_says: "[paraphrase] DiffSheet destructive version delete currently calls deleteSelectedVersion directly."
  canon_path: /Users/jojo/Downloads/Epistemos/docs/fusion/EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md:138
  code_path: /Users/jojo/Downloads/Epistemos/Epistemos/Views/Notes/DiffSheetView.swift:218
load_bearing_quote: "Every confirmation surface in the app"
verdict: drift
usefulness: +1
usefulness_reason: Identifies one exact existing destructive confirmation surface still bypassing the shared gate.
---

## Findings
- `MASTER_RESEARCH_INDEX_2026_05_02.md` §3.2 points Sovereign Gate work to doctrine §4.2 and Annex A.7.
- [EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md](/Users/jojo/Downloads/Epistemos/docs/fusion/EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md:138) says confirmation surfaces route through one biometric gate.
- [EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md](/Users/jojo/Downloads/Epistemos/docs/fusion/EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md:149) classifies Destructive as every-time device-owner authentication in Core.
- [AGENT_BUILD_WORKCARDS_2026_05_01.md](/Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md:1267) permits future confirmation-surface migrations only after naming the exact surface.

## Open questions
- None for this slice; generated Rust-to-Swift transport remains out of scope.

## Recommendation
Gate only the existing DiffSheet "Delete This Version" destructive menu action through `AppBootstrap.shared?.sovereignGate.confirm(.deviceOwnerAuthentication, reason:)`, preserving the current deletion/save/rollback behavior.
