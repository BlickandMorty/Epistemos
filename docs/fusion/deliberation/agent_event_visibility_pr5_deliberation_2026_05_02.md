# AgentEvent Visibility PR5 Deliberation - 2026-05-02

```text
Slice:          AgentEvent PR5 - read-only Settings visibility diagnostic
Tier:           Core
Files touched:
- Epistemos/State/EventStore.swift
- Epistemos/Views/Settings/AgentEventVisibilityRow.swift
- Epistemos/Views/Settings/SettingsView.swift
- EpistemosTests/AgentEventVisibilityTests.swift
- docs/fusion/CODEX_FINAL_EXECUTION_PROMPT_2026_05_01.md
- docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
- docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
- docs/fusion/deliberation/agent_event_visibility_pr5_deliberation_2026_05_02.md
Protected paths:
- Epistemos/Views/Notes/ProseEditor*.swift
- Epistemos/Views/Notes/ProseTextView2.swift
- Epistemos/Views/Graph/MetalGraphView.swift
- Epistemos/Views/Graph/HologramController.swift
- graph-engine/**
- agent_core/**
- epistemos-shadow/**
- omega-mcp/**
- epistemos-core/**
- substrate-core/**
Gate:           SovereignGate touchpoint? none
Risks:          P1 risk if SettingsView's existing unrelated dirty diagnostics edits are staged accidentally; P1 risk if the row mutates EventStore or opens Rust OpLog/projection handles from UI.
Verification:   focused Swift test logs under /tmp/epistemos-agent-event-visibility-pr5-*-20260502.log; diff-only invariant greps; protected-path staged-set audit.
Rollback:       Remove the diagnostic API, the row file, the Settings mount line, the focused test, and the state/workcard doc status lines.
Stop triggers:
- SettingsView mount requires staging unrelated dirty diagnostics hunks.
- The row needs schema migration, repair/retry controls, Rust/OpLog access, Graph renderer/Halo/retrieval writes, or auth prompts.
- Any LAContext/biometric, inference subprocess, tensor-copy, protected editor, protected graph, Rust kernel, or generated artifact diff appears.
```

## Authority Read

- `docs/fusion/EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md` §2.2 and §7: Core substrate work must preserve zero-copy, single-binary, tiered determinism, and no protected graph/editor jumps.
- `docs/fusion/CODEX_FINAL_EXECUTION_PROMPT_2026_05_01.md` §3.1-§3.6: tier classification, Sovereign Gate leakage checks, report-before-code, and invariant greps.
- `docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`: AgentEvent PR1-PR4 are closed; Settings diagnostics already expose OpLog and GraphEvent read-only visibility.
- `Epistemos/State/EventStore.swift`: owns `agent_events`, bounded AgentEvent read APIs, and `graphEventDiagnostics()`.
- `Epistemos/Views/Settings/GraphEventVisibilityRow.swift`: sibling read-only diagnostic shape.
- `Epistemos/Views/Settings/OpLogProjectionHealthRow.swift`: sibling projection-health row shape currently present in the worktree.

## Implementation Contract

- Add one bounded read-only `EventStore.AgentEventDiagnostics` snapshot with total rows, distinct run count, distinct tool count, and latest decoded `AgentProvenanceEvent`.
- Add `AgentEventVisibilityRow` as a Settings diagnostic-only view. It must read through `EventStore.shared`, show honest empty-state copy, and expose latest event metadata without repair controls.
- Mount `AgentEventVisibilityRow()` next to the existing GraphEvent diagnostic row. Because `SettingsView.swift` is already dirty from unrelated diagnostics work, only the AgentEvent mount hunk may be staged.
- Do not change AgentEvent persistence schema, emission sites, HookRegistry, PipelineService, ChatCoordinator, OpLog projection, graph renderer, retrieval, Halo, Rust, generated bindings, entitlements, or project files.

## Verification

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/AgentEventVisibilityTests test 2>&1 | tee /tmp/epistemos-agent-event-visibility-pr5-red-20260502.log
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/AgentEventVisibilityTests test 2>&1 | tee /tmp/epistemos-agent-event-visibility-pr5-green-20260502.log
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/EventStoreSchemaTests test 2>&1 | tee /tmp/epistemos-agent-event-visibility-pr5-eventstore-regression-20260502.log
git diff --check -- Epistemos/State/EventStore.swift Epistemos/Views/Settings/AgentEventVisibilityRow.swift Epistemos/Views/Settings/SettingsView.swift EpistemosTests/AgentEventVisibilityTests.swift docs/fusion
git diff -- Epistemos/State/EventStore.swift Epistemos/Views/Settings/AgentEventVisibilityRow.swift Epistemos/Views/Settings/SettingsView.swift EpistemosTests/AgentEventVisibilityTests.swift | rg -n 'LAContext|canEvaluatePolicy|evaluatePolicy|deviceOwnerAuthentication|TouchID|biometric|Process\(\)|swift-subprocess|Foundation\.Process|std::process::Command|memcpy|memmove|\.copyMemory|Data\(bytes:|storageModeManaged|storageModePrivate|z3|kani|kissat|lean|cvc5|alloy' || true
```

## Acceptance

- AgentEvent durable provenance has parity with GraphEvent visibility through a read-only Settings row.
- Focused tests prove the diagnostic snapshot counts rows, distinct runs, distinct tools, and latest event metadata.
- No protected paths, Rust kernel, generated artifacts, auth prompts, inference subprocesses, tensor hot-path copies, schema migrations, repair actions, or behavior-changing emission edits are included.
