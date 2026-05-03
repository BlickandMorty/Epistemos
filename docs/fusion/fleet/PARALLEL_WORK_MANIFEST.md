# Parallel Work Manifest - refreshed 2026-05-03T15:33Z

## Codex current state
- Slice in flight: phase5-ssm-state-provenance-pr37 finalization
- Round: 75
- Slices reserved (next 3): [phase5-ssm-state-provenance-pr37, graph-event-consumer-projection-guard-pr38, agent-event-next-slice-selection-pr39]
- Anchor heartbeat: ANCHOR: slice=parallel-work-manifest-refresh | round=75 | terminal=session:4012 | claude-side=off | claude-red-team=off | reading=[PARALLEL_WORK_MANIFEST.md,UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md,AGENT_BUILD_WORKCARDS_2026_05_01.md,REGISTRY.md]

## Codex reservation set
- /Users/jojo/Downloads/Epistemos/Epistemos/Bridge/Phase5Bridge.swift
- /Users/jojo/Downloads/Epistemos/EpistemosTests/Phase5BridgeAgentEventTests.swift
- /Users/jojo/Downloads/Epistemos/EpistemosTests/GraphEventConsumerProjectionGuardTests.swift
- /Users/jojo/Downloads/Epistemos/docs/fusion/fleet/phase5-ssm-state-provenance-pr37/
- /Users/jojo/Downloads/Epistemos/docs/fusion/fleet/graph-event-consumer-projection-guard-pr38/
- /Users/jojo/Downloads/Epistemos/docs/fusion/deliberation/phase5_ssm_state_provenance_pr37_deliberation_2026_05_03.md
- /Users/jojo/Downloads/Epistemos/docs/fusion/deliberation/graph_event_consumer_projection_guard_pr38_deliberation_2026_05_03.md
- /Users/jojo/Downloads/Epistemos/docs/fusion/oversight/PREFLIGHT_74_2026_05_03.md
- /Users/jojo/Downloads/Epistemos/docs/fusion/oversight/PREFLIGHT_75_2026_05_03.md
- /Users/jojo/Downloads/Epistemos/docs/fusion/oversight/POST_MERGE_GUARDS_2026_05_02.md
- /Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
- /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
- /Users/jojo/Downloads/Epistemos/docs/fusion/fleet/REGISTRY.md
- /Users/jojo/Downloads/Epistemos/docs/fusion/fleet/PARALLEL_WORK_MANIFEST.md

## Canon / protected no-touch list
- Do not edit: `MASTER_RESEARCH_INDEX_2026_05_02.md`, `EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md`, `UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`, `CODEX_FINAL_EXECUTION_PROMPT_2026_05_01.md`, `CODEX_AGENT_FLEET_PROMPT_2026_05_02.md`, `AGENT_BUILD_WORKCARDS_2026_05_01.md`, current `docs/fusion/deliberation/`, current `docs/fusion/oversight/`, or current `docs/fusion/fleet/<slice>/`.
- Do not touch protected code paths: `Epistemos/Views/Notes/ProseEditor*.swift`, `Epistemos/Views/Graph/MetalGraphView.swift`, `Epistemos/Views/Graph/HologramController.swift`, graph physics/render internals, generated `.rlib`, `DerivedData`, `.xcresult`, `Epistemos.xcodeproj/project.pbxproj`, `Cargo.toml`, `Package.swift`, or build scripts unless explicitly coordinated.

## Parallel work items (open)

### P1 - Hermes Gateway Evidence Contract Tests
**Lane (doctrine §7):** Pro track - Hermes cloud gateway / MCP tunnel preparation
**Effort:** S
**Who:** agent-2-ok
**Status:** open

**What.**
Create a new Swift Testing suite that hardens the Hermes-as-cloud-gateway decision: local substrate/prompt formatting remains direct and in-process; cloud provider surfaces route through Hermes, are not Core/App Store allowed, and require structured evidence provenance.

**Files touched (precise paths, all new unless flagged):**
- /Users/jojo/Downloads/Epistemos/EpistemosTests/HermesGatewayEvidenceContractTests.swift (NEW)

**Why safe.**
This creates a new test file outside the Codex reservation set. It does not edit `HermesGatewayPolicy.swift`, bridge files, current docs, project files, or protected UI/graph paths.

**Why useful now.**
It advances the Pro gateway lane while preserving the "unified but firewalled" architecture: Epistemos remains direct/local; Hermes owns cloud chaos and returns structured evidence.

**Acceptance.**
- New Swift Testing file exists.
- Tests cover every `HermesGatewayPolicy.Surface.cloudProviderSurfaces` entry.
- Tests prove cloud surfaces use `.hermesGateway`, require network, are not Core/App Store allowed, and require structured evidence provenance.
- Tests prove local substrate and local prompt formatting stay direct/in-process.
- No production files are modified.

**If picked by agent-2, paste this prompt:**
```text
You are a parallel coding agent in /Users/jojo/Downloads/Epistemos on the same branch as Codex. Read /Users/jojo/Downloads/Epistemos/AGENTS.md, then read docs/fusion/fleet/PARALLEL_WORK_MANIFEST.md item P1. Do not edit production code or current canon docs. Do not touch Phase5Bridge.swift, Phase5BridgeAgentEventTests.swift, GraphEventConsumerProjectionGuardTests.swift, any current docs/fusion/deliberation or docs/fusion/oversight file, ProseEditor*, MetalGraphView.swift, HologramController.swift, graph physics/render internals, project.pbxproj, Cargo.toml, Package.swift, or build scripts.

Task: create /Users/jojo/Downloads/Epistemos/EpistemosTests/HermesGatewayEvidenceContractTests.swift. Use Swift Testing and @testable import Epistemos. Add coverage for HermesGatewayPolicy: every cloudProviderSurfaces entry must route through .hermesGateway, require network, not require subprocess if policy says so, not be allowed in Core App Store, and require structured evidence provenance. Local deterministic/local-prompt surfaces must remain direct or in-process. Run: xcodebuild -project /Users/jojo/Downloads/Epistemos/Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/HermesGatewayEvidenceContractTests test. If a policy invariant fails, stop and report; do not patch production.
```

### P2 - Tool Surface Behavioral Matrix Tests
**Lane (doctrine §7):** Core open - MAS/Core vs Pro capability symbol separation
**Effort:** S
**Who:** agent-2-ok
**Status:** open

**What.**
Create a new behavioral test matrix for the Core App Store tool-surface gate. This complements the source-guard tests by exercising the actual policy API for Core-safe allowlist tools versus Pro/Research-only tools.

**Files touched (precise paths, all new unless flagged):**
- /Users/jojo/Downloads/Epistemos/EpistemosTests/ToolSurfaceBehavioralMatrixTests.swift (NEW)

**Why safe.**
New test file only. It does not edit `ToolTierBridge.swift`, `ToolSurfacePolicy.swift`, `MCPBridge.swift`, or any current Codex-reserved file.

**Why useful now.**
It reduces App Store/Core leakage risk before more Hermes/Pro surfaces are wired.

**Acceptance.**
- New Swift Testing file exists.
- Tests assert Core-safe tools are surfaced in Core distribution.
- Tests assert `bash`, `shell_exec`, `browser_use`, `computer_use`, `docker`, `mcp_call`, `cli_passthrough`, and `hermes_subprocess` are not Core-surfaced.
- No production files are modified.

**If picked by agent-2, paste this prompt:**
```text
You are a parallel coding agent in /Users/jojo/Downloads/Epistemos. Read AGENTS.md and docs/fusion/fleet/PARALLEL_WORK_MANIFEST.md item P2. Do not edit production code or current canon docs. Do not touch Phase5Bridge.swift, GraphEventConsumerProjectionGuardTests.swift, MCPBridge.swift, ToolTierBridge.swift, ToolSurfacePolicy.swift, current docs/fusion/deliberation files, ProseEditor*, MetalGraphView.swift, HologramController.swift, graph physics/render internals, project.pbxproj, Cargo.toml, or Package.swift.

Task: create /Users/jojo/Downloads/Epistemos/EpistemosTests/ToolSurfaceBehavioralMatrixTests.swift. Use Swift Testing and @testable import Epistemos. Add behavioral tests for the existing Core/App Store tool policy APIs. Assert Core-safe allowlist tools remain surfaced in Core, and Pro/Research-only surfaces such as bash, shell_exec, browser_use, computer_use, docker, mcp_call, cli_passthrough, and hermes_subprocess are not surfaced in Core. Run: xcodebuild -project /Users/jojo/Downloads/Epistemos/Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/ToolSurfaceBehavioralMatrixTests test. If an API name differs, adapt the test to existing APIs; do not patch production.
```

### P3 - Durable GraphEvent Projection Fixture Tests
**Lane (doctrine §7):** Core open - live GraphEvent consumer projection preparation
**Effort:** M
**Who:** agent-2-ok
**Status:** open

**What.**
Create a new test-only fixture suite for existing durable GraphEvent projection folding/reporting with synthetic events. Do not build the live consumer; just lock the semantics Codex will rely on.

**Files touched (precise paths, all new unless flagged):**
- /Users/jojo/Downloads/Epistemos/EpistemosTests/GraphEventProjectionFixtureTests.swift (NEW)

**Why safe.**
This avoids Codex's reserved `GraphEventConsumerProjectionGuardTests.swift` and does not edit graph production, renderer, physics, Halo, or EventStore files.

**Why useful now.**
It reduces risk for the next graph projection slice by giving it a fixture baseline.

**Acceptance.**
- New Swift Testing file exists.
- Tests reuse existing fixture patterns from current GraphEvent projection/audit tests.
- Tests cover empty input, chronological folding/reporting, bounded limit behavior if available, and duplicate/repeated node or edge behavior if supported.
- No production files are modified.

**If picked by agent-2, paste this prompt:**
```text
You are a parallel coding agent in /Users/jojo/Downloads/Epistemos. Read AGENTS.md and docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md Card 8. Do not edit production code. Do not touch Epistemos/Views/Graph/MetalGraphView.swift, Epistemos/Views/Graph/HologramController.swift, graph-engine, graph physics/render internals, EventStore production files, GraphEventAuditProjectionService.swift, GraphEventConsumerProjectionGuardTests.swift, Phase5Bridge.swift, current docs/fusion/deliberation files, project.pbxproj, Cargo.toml, or Package.swift.

Task: create /Users/jojo/Downloads/Epistemos/EpistemosTests/GraphEventProjectionFixtureTests.swift. Use Swift Testing. Read existing GraphEvent projection/audit tests for fixture style, then add synthetic projection tests for empty input, chronological folding/reporting, bounded limit behavior if available, and duplicate/repeated node or edge behavior if current APIs support it. Run: xcodebuild -project /Users/jojo/Downloads/Epistemos/Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/GraphEventProjectionFixtureTests test. If current APIs cannot express an invariant, report it; do not patch production.
```

### P4 - AgentEvent Runtime Coverage Map
**Lane (doctrine §7):** Core open - broader runtime AgentEvent coverage
**Effort:** M
**Who:** agent-2-ok
**Status:** open

**What.**
Create a read-only coverage map of remaining bridge/Omega runtime surfaces that still lack AgentEvent provenance. This is a future-slice selector, not a code patch.

**Files touched (precise paths, all new unless flagged):**
- /Users/jojo/Downloads/Epistemos/docs/fusion/fleet/agent-event-runtime-coverage-map/AGENT_EVENT_RUNTIME_COVERAGE_MAP_2026_05_03.md (NEW)

**Why safe.**
New doc in a future-lane folder. It avoids all current Codex docs and source files.

**Why useful now.**
It turns "what do we build next?" into a concrete, non-duplicative queue after Phase5/GraphEvent.

**Acceptance.**
- New map exists.
- It lists inspected bridge/runtime files, whether they already emit AgentEvents, sensitive payload risk, and smallest safe future slice.
- It marks Phase5Bridge and Phase7Bridge as already/reserved and does not propose editing them.
- No code or existing canon docs are modified.

**If picked by agent-2, paste this prompt:**
```text
You are a parallel research agent in /Users/jojo/Downloads/Epistemos. Read AGENTS.md, docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md Safe Next Build Order item 3, and docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md Card 7. Read-only except for creating one new doc. Do not edit source code or current canon docs. Do not touch Phase5Bridge.swift, Phase7Bridge.swift, current docs/fusion/deliberation files, ProseEditor*, MetalGraphView.swift, HologramController.swift, graph physics/render internals, project.pbxproj, Cargo.toml, or Package.swift.

Task: create /Users/jojo/Downloads/Epistemos/docs/fusion/fleet/agent-event-runtime-coverage-map/AGENT_EVENT_RUNTIME_COVERAGE_MAP_2026_05_03.md. Inspect Epistemos/Bridge/*.swift and obvious Omega runtime files for AgentToolProvenanceRecorder / AgentProvenanceEvent usage. For each surface, record file path, action/tool names, already instrumented yes/no, sensitive payload risk yes/no, and smallest future safe PR slice. Do not modify code.
```

### P5 - R15 Live MLX Memory Preflight Artifact
**Lane (doctrine §7):** Core open - R15 remaining specialized baselines
**Effort:** S
**Who:** either
**Status:** open

**What.**
Capture current machine memory/power/thermal evidence for the blocked live MLX token-throughput lane. Do not run the MLX benchmark.

**Files touched (precise paths, all new unless flagged):**
- /Users/jojo/Downloads/Epistemos/docs/fusion/fleet/r15-live-mlx-memory-preflight/R15_LIVE_MLX_MEMORY_PREFLIGHT_2026_05_03.md (NEW)

**Why safe.**
New artifact only. No code, no current canon edits, no benchmark, no app runtime.

**Why useful now.**
R15 live MLX throughput is blocked on sufficient-memory evidence. This gives Codex the go/no-go data without interrupting build work.

**Acceptance.**
- Artifact includes `date -u`, `sw_vers`, `sysctl hw.memsize`, `vm_stat`, `df -h /`, `pmset -g batt`, and a yes/no/unknown conclusion.
- No benchmark is run.
- No code or existing docs are modified.

**If picked by agent-2, paste this prompt:**
```text
You are a parallel agent in /Users/jojo/Downloads/Epistemos. This task is read-only except for creating one new artifact file. Do not edit code, tests, project files, current canon docs, or current docs/fusion/deliberation files. Do not run any live MLX benchmark.

Task: create /Users/jojo/Downloads/Epistemos/docs/fusion/fleet/r15-live-mlx-memory-preflight/R15_LIVE_MLX_MEMORY_PREFLIGHT_2026_05_03.md. Capture outputs from date -u, sw_vers, sysctl hw.memsize, vm_stat, df -h /, and pmset -g batt. Summarize whether the R15 live MLX tok/s harness should remain blocked or can be attempted later. Do not edit any other files.
```

### P6 - Hermes Prompt Format Guard Tests
**Lane (doctrine §7):** Pro track - Hermes gateway protocol correctness
**Effort:** S
**Who:** agent-2-ok
**Status:** open

**What.**
Create a source-guard test that locks the current Hermes prompt format reality: local Hermes prompt building is plain markdown / repo-native format, not NousResearch ChatML XML, unless a future deliberation deliberately migrates it.

**Files touched (precise paths, all new unless flagged):**
- /Users/jojo/Downloads/Epistemos/EpistemosTests/HermesPromptFormatGuardTests.swift (NEW)

**Why safe.**
New test file only. It does not edit prompt builders, Hermes policy, or current bridge slices.

**Why useful now.**
It protects Master Research Index honest discovery H2 and prevents future agents from wiring the wrong ChatML/XML assumption into Hermes.

**Acceptance.**
- New Swift Testing file exists.
- Tests read `Epistemos/LocalAgent/HermesPromptBuilder.swift` and `agent_core/src/prompts.rs` if present.
- Tests assert no `<|im_start|>` / `<|im_end|>` / ChatML XML markers in the current local Hermes prompt path.
- No production files are modified.

**If picked by agent-2, paste this prompt:**
```text
You are a parallel coding agent in /Users/jojo/Downloads/Epistemos. Read AGENTS.md and docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md §0 honest discovery H2. Do not edit production code or current canon docs. Do not touch Phase5Bridge.swift, GraphEventConsumerProjectionGuardTests.swift, current docs/fusion/deliberation files, project.pbxproj, Cargo.toml, or Package.swift.

Task: create /Users/jojo/Downloads/Epistemos/EpistemosTests/HermesPromptFormatGuardTests.swift. Use Swift Testing. Source-read Epistemos/LocalAgent/HermesPromptBuilder.swift and agent_core/src/prompts.rs if present. Assert the current local Hermes-family prompt path does not use <|im_start|>, <|im_end|>, or XML ChatML markers, and document that changing this requires a future deliberation. Run a focused test if the file is included in the Xcode test target. Do not patch production.
```

### P7 - Sovereign Gate Surface Backlog Map
**Lane (doctrine §7):** Core killer-feature seed work - Sovereign Gate broader Core classes
**Effort:** M
**Who:** agent-2-ok
**Status:** open

**What.**
Create a read-only backlog map of destructive/sensitive app surfaces that may still need Sovereign Gate routing after the existing closed PRs. This should identify future safe slices, not change code.

**Files touched (precise paths, all new unless flagged):**
- /Users/jojo/Downloads/Epistemos/docs/fusion/fleet/sovereign-gate-surface-map/SOVEREIGN_GATE_SURFACE_MAP_2026_05_03.md (NEW)

**Why safe.**
New doc only. It does not edit `SovereignGate.swift`, existing Sovereign tests, app views, settings views, or current Codex docs.

**Why useful now.**
It turns the killer-feature seed lane into a concrete backlog while Codex continues the provenance/GraphEvent queue.

**Acceptance.**
- New map exists.
- It lists candidate destructive/sensitive surfaces, current routing if identifiable, risk level, and smallest future PR slice.
- It explicitly notes already-closed Sovereign Gate PR1-PR16 and avoids duplicating them.
- No source or existing canon docs are modified.

**If picked by agent-2, paste this prompt:**
```text
You are a parallel research agent in /Users/jojo/Downloads/Epistemos. Read AGENTS.md and docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md Card 9. Read-only except for one new doc. Do not edit code or existing canon docs. Do not touch Epistemos/Sovereign/SovereignGate.swift, existing Sovereign tests, current docs/fusion/deliberation files, ProseEditor*, MetalGraphView.swift, HologramController.swift, project.pbxproj, Cargo.toml, or Package.swift.

Task: create /Users/jojo/Downloads/Epistemos/docs/fusion/fleet/sovereign-gate-surface-map/SOVEREIGN_GATE_SURFACE_MAP_2026_05_03.md. Search for destructive/sensitive UI/service actions such as delete, reset, disconnect, revoke, archive, export, credential, keychain, approval, permission. List candidate surfaces, current routing if visible, risk level, and smallest future PR slice. Explicitly note already-closed Sovereign Gate PR1-PR16 and do not duplicate them. Do not modify code.
```

## History (claimed / done / superseded / stale)
| Item | Status | Resolved at | Notes |
|---|---|---|---|
| P1 Core/MAS Boundary Source-Guard Tests | done-uncommitted | 2026-05-03T15:33Z | Parallel agent created `/Users/jojo/Downloads/Epistemos/EpistemosTests/CoreMASBoundarySourceGuardTests.swift`; Codex will not stage it in Phase5 commit. |
| P3 Sovereign Gate Requirement Matrix Tests | done-uncommitted | 2026-05-03T15:33Z | Parallel agent created `/Users/jojo/Downloads/Epistemos/EpistemosTests/SovereignGateRequirementMatrixTests.swift`; Codex will not stage it in Phase5 commit. |
