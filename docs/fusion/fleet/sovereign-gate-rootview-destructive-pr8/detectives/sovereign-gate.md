---
role: detective
slice: sovereign-gate-rootview-destructive-pr8
concept: Sovereign Gate destructive confirmation
index_anchor: MASTER_RESEARCH_INDEX_2026_05_02.md §3.2
tier: Core
canonical_source: /Users/jojo/Downloads/Epistemos/docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md
sister_sources:
  - /Users/jojo/Downloads/Epistemos/docs/fusion/EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md
  - /Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
  - /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
code_anchors:
  - /Users/jojo/Downloads/Epistemos/Epistemos/Sovereign/SovereignGate.swift
  - /Users/jojo/Downloads/Epistemos/Epistemos/App/AppBootstrap.swift
  - /Users/jojo/Downloads/Epistemos/Epistemos/App/RootView.swift:52
  - /Users/jojo/Downloads/Epistemos/EpistemosTests/SovereignGateTests.swift:318
deliberations_consulted:
  - docs/fusion/deliberation/sovereign_gate_version_delete_pr7_deliberation_2026_05_02.md
quick_capture_consulted: n/a
worktrees_consulted:
  - main
drift:
  detected: true
  canon_says: "Destructive (every time + passcode)"
  code_says: "[paraphrase] RootView reset/disconnect destructive buttons called direct closures before this slice."
  canon_path: /Users/jojo/Downloads/Epistemos/docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md
  code_path: /Users/jojo/Downloads/Epistemos/Epistemos/App/RootView.swift
load_bearing_quote: "Destructive (every time + passcode)"
verdict: drift
usefulness: +1
usefulness_reason: Identifies RootView destructive controls as exact Core surfaces that must pass through the shared gate.
---

## Findings
- `MASTER_RESEARCH_INDEX_2026_05_02.md` §3.2 requires Destructive-class actions to authenticate every time.
- [SovereignGate.swift](/Users/jojo/Downloads/Epistemos/Epistemos/Sovereign/SovereignGate.swift) remains the single native authorization entrypoint.
- [AppBootstrap.swift](/Users/jojo/Downloads/Epistemos/Epistemos/App/AppBootstrap.swift) owns the shared `sovereignGate` used by migrated Core surfaces.
- [RootView.swift](/Users/jojo/Downloads/Epistemos/Epistemos/App/RootView.swift:271) exposes an existing destructive database reset button.
- [RootView.swift](/Users/jojo/Downloads/Epistemos/Epistemos/App/RootView.swift:1794) exposes an existing destructive vault disconnect button.

## Open questions
- None for this slice. Generated Rust transport, Secure Enclave, and Sovereign-class routes remain out of scope.

## Recommendation
Gate the two RootView destructive controls through the existing shared `AppBootstrap` `SovereignGate` with `.deviceOwnerAuthentication`, preserving the original closures and adding source-level tests that prove the buttons no longer call those closures directly.
