# Parallel Work Manifest - refreshed 2026-05-03T15:00Z

## Codex current state
- Slice in flight: phase7-nightbrain-trigger-provenance-pr36
- Round: 73
- Slices reserved (next 3): [phase7-nightbrain-trigger-provenance-pr36, phase5-ssm-state-provenance-pr37, graph-event-consumer-projection-guard-pr38]
- Codex reservation set (files I will touch in next 3 slices):
  - /Users/jojo/Downloads/Epistemos/Epistemos/Bridge/Phase7Bridge.swift
  - /Users/jojo/Downloads/Epistemos/EpistemosTests/Phase7BridgeAgentEventTests.swift
  - /Users/jojo/Downloads/Epistemos/Epistemos/Bridge/Phase5Bridge.swift
  - /Users/jojo/Downloads/Epistemos/EpistemosTests/Phase5BridgeAgentEventTests.swift
  - /Users/jojo/Downloads/Epistemos/EpistemosTests/GraphEventConsumerProjectionGuardTests.swift
  - /Users/jojo/Downloads/Epistemos/docs/fusion/fleet/phase7-nightbrain-trigger-provenance-pr36/
  - /Users/jojo/Downloads/Epistemos/docs/fusion/fleet/phase5-ssm-state-provenance-pr37/
  - /Users/jojo/Downloads/Epistemos/docs/fusion/fleet/graph-event-consumer-projection-guard-pr38/
  - /Users/jojo/Downloads/Epistemos/docs/fusion/deliberation/phase7_nightbrain_trigger_provenance_pr36_deliberation_2026_05_03.md
  - /Users/jojo/Downloads/Epistemos/docs/fusion/deliberation/phase5_ssm_state_provenance_pr37_deliberation_2026_05_03.md
  - /Users/jojo/Downloads/Epistemos/docs/fusion/deliberation/graph_event_consumer_projection_guard_pr38_deliberation_2026_05_03.md
  - /Users/jojo/Downloads/Epistemos/docs/fusion/oversight/PREFLIGHT_73_2026_05_03.md
  - /Users/jojo/Downloads/Epistemos/docs/fusion/oversight/PREFLIGHT_74_2026_05_03.md
  - /Users/jojo/Downloads/Epistemos/docs/fusion/oversight/PREFLIGHT_75_2026_05_03.md
  - /Users/jojo/Downloads/Epistemos/docs/fusion/oversight/POST_MERGE_GUARDS_2026_05_02.md
  - /Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
  - /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
  - /Users/jojo/Downloads/Epistemos/docs/fusion/fleet/REGISTRY.md
- Canon docs currently off-limits for parallel edits: MASTER_RESEARCH_INDEX_2026_05_02.md, EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md, UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md, CODEX_FINAL_EXECUTION_PROMPT_2026_05_01.md, CODEX_AGENT_FLEET_PROMPT_2026_05_02.md, AGENT_BUILD_WORKCARDS_2026_05_01.md, current-slice deliberation/oversight/fleet folders.
- Anchor heartbeat: ANCHOR: slice=phase7-nightbrain-trigger-provenance-pr36 | round=73 | terminal=session:4012 | claude-side=off | claude-red-team=off | reading=[MASTER_RESEARCH_INDEX_2026_05_02.md,UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md,AGENT_BUILD_WORKCARDS_2026_05_01.md,REGISTRY.md,Phase7Bridge.swift]

## Parallel work items (open)

### P1 - Core/MAS Boundary Source-Guard Tests
**Lane (doctrine §7):** Core open - MAS/Core vs Pro capability symbol separation
**Effort:** S
**Who:** agent-2-ok
**Status:** open

**What.**
Create a new Swift Testing source-guard suite that proves the current Core/App Store boundary stays direct and in-process: Hermes external/provider/CLI surfaces stay Pro/Research, `ToolTierBridge` owns the runtime executor gate, and `MCPBridge` policy-denies hidden `tools/call` surfaces before dispatch. This is test-only: do not edit production code.

**Files touched (precise paths, all new unless flagged):**
- /Users/jojo/Downloads/Epistemos/EpistemosTests/CoreMASBoundarySourceGuardTests.swift (NEW)

**Why safe.**
This file is outside the Codex reservation set. It does not touch `Phase7Bridge.swift`, `Phase5Bridge.swift`, GraphEvent guard tests, current deliberation docs, or any protected editor/graph-renderer path. A new test file in `EpistemosTests/` is same-branch safe.

**Why useful now.**
It advances doctrine §7 "Core open / MAS/Core vs Pro capability symbol separation" and gives Codex a guardrail before the next Hermes/Pro tunnel slices. It also reduces the chance that future provider work accidentally leaks subprocess, cloud, browser, or CLI symbols into Core.

**Acceptance.**
- New test file exists and uses Swift Testing.
- Tests read source with `loadMirroredSourceTextFile`.
- Tests assert Core-safe policy/gate strings in `Epistemos/LocalAgent/HermesGatewayPolicy.swift`, `Epistemos/Bridge/ToolTierBridge.swift`, and `Epistemos/Omega/MCPBridge.swift`.
- No production files are modified.
- `xcodebuild -project /Users/jojo/Downloads/Epistemos/Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/CoreMASBoundarySourceGuardTests test` passes, or the agent reports the exact failing invariant without patching production.

**If picked by agent-2, paste this prompt:**
```text
You are a parallel coding agent working in /Users/jojo/Downloads/Epistemos on the same branch as Codex. Read /Users/jojo/Downloads/Epistemos/AGENTS.md, then read /Users/jojo/Downloads/Epistemos/docs/fusion/fleet/PARALLEL_WORK_MANIFEST.md item P1 if present. Do not edit production code. Do not touch Phase7Bridge.swift, Phase5Bridge.swift, docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md, docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md, docs/fusion/fleet/REGISTRY.md, any docs/fusion/deliberation current-slice file, ProseEditor*, MetalGraphView.swift, HologramController.swift, graph physics/render internals, project.pbxproj, Cargo.toml, or Package.swift.

Task: create /Users/jojo/Downloads/Epistemos/EpistemosTests/CoreMASBoundarySourceGuardTests.swift. Use Swift Testing. Add source-guard tests that read Epistemos/LocalAgent/HermesGatewayPolicy.swift, Epistemos/Bridge/ToolTierBridge.swift, and Epistemos/Omega/MCPBridge.swift with loadMirroredSourceTextFile. Assert the Core App Store boundary stays in-process/direct, external provider/CLI/MCP/browser/computer-use surfaces remain Pro/Research or policy-denied, ToolTierBridge owns the executor gate, and MCPBridge still records/denies hidden tools before dispatch. Run: xcodebuild -project /Users/jojo/Downloads/Epistemos/Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/CoreMASBoundarySourceGuardTests test. If a production invariant fails, stop and report it; do not patch production.
```

### P2 - Hermes Gateway Evidence Contract Tests
**Lane (doctrine §7):** Pro track - Hermes subprocess/cloud gateway integration, after Core/MAS separation
**Effort:** S
**Who:** agent-2-ok
**Status:** open

**What.**
Create a new test-only suite around `HermesGatewayPolicy` that hardens the architecture decision the user liked: local substrate work remains direct/in-process, while cloud providers and external tools route through the unified Hermes gateway and require structured evidence provenance.

**Files touched (precise paths, all new unless flagged):**
- /Users/jojo/Downloads/Epistemos/EpistemosTests/HermesGatewayEvidenceContractTests.swift (NEW)

**Why safe.**
This new test file does not overlap Codex's reserved bridge/provenance files and does not edit existing `HermesGatewayPolicyTests.swift`. It is isolated from current AgentEvent implementation slices.

**Why useful now.**
It advances doctrine §7 Pro track "Hermes subprocess integration" and "MCP tunnels" by freezing the cloud-gateway contract before provider routing expands. This prevents direct cloud calls from becoming a second architecture.

**Acceptance.**
- New Swift Testing file exists.
- Tests cover every `HermesGatewayPolicy.Surface.cloudProviderSurfaces` entry.
- Tests prove cloud provider surfaces use `.hermesGateway`, require network, do not require subprocess, are not Core/App Store allowed, and require structured evidence provenance.
- Tests prove `.deterministicLocalSubstrate` and `.localPromptFormatting` stay direct/in-process.
- No production files are modified.
- Focused test command passes or reports a pre-existing invariant failure without patching production.

**If picked by agent-2, paste this prompt:**
```text
You are a parallel coding agent in /Users/jojo/Downloads/Epistemos. Read AGENTS.md and docs/fusion/EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md §7, especially the Pro track and hard forbidden list. Do not edit production code. Do not touch Phase7Bridge.swift, Phase5Bridge.swift, docs/fusion canonical state/workcard files, current docs/fusion/deliberation files, ProseEditor*, MetalGraphView.swift, HologramController.swift, graph physics/render internals, project.pbxproj, Cargo.toml, or Package.swift.

Task: create /Users/jojo/Downloads/Epistemos/EpistemosTests/HermesGatewayEvidenceContractTests.swift. Use Swift Testing and @testable import Epistemos. Add test-only coverage for HermesGatewayPolicy: all cloudProviderSurfaces must route through .hermesGateway, require network, not require subprocess, not be allowed in Core App Store, and require structured evidence provenance. Local deterministic/local-prompt surfaces must remain direct or in-process and require no structured external evidence. Run: xcodebuild -project /Users/jojo/Downloads/Epistemos/Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/HermesGatewayEvidenceContractTests test. If the policy object lacks a needed API or the invariant fails, stop and report; do not patch production.
```

### P3 - Sovereign Gate Requirement Matrix Tests
**Lane (doctrine §7):** Core killer-feature seed work - Sovereign Gate broader Core classes follow-through
**Effort:** S
**Who:** agent-2-ok
**Status:** open

**What.**
Create a new test-only matrix that verifies existing Sovereign Gate helper mappings still route destructive/sensitive app actions through the single shared `SovereignGate` entrypoint and do not duplicate `LAContext` outside `Epistemos/Sovereign/SovereignGate.swift`.

**Files touched (precise paths, all new unless flagged):**
- /Users/jojo/Downloads/Epistemos/EpistemosTests/SovereignGateRequirementMatrixTests.swift (NEW)

**Why safe.**
This creates a new test file only. It does not edit `SovereignGate.swift`, existing `SovereignGateTests.swift`, Phase bridges, or any current Codex docs. It stays away from biometric implementation and only audits existing mappings/source.

**Why useful now.**
It advances doctrine §7 "Sovereign Gate broader Core classes" by turning the single-entrypoint invariant into a repeatable guard before new destructive surfaces are migrated.

**Acceptance.**
- New Swift Testing file exists.
- Tests source-scan for `LAContext()` and prove the only Swift source hit is `Epistemos/Sovereign/SovereignGate.swift`.
- Tests assert at least three existing delete/reset/disconnect helper mappings return `.deviceOwnerAuthentication`.
- No production files are modified.
- Focused test command passes or reports a pre-existing invariant failure without patching production.

**If picked by agent-2, paste this prompt:**
```text
You are a parallel coding agent in /Users/jojo/Downloads/Epistemos. Read AGENTS.md, then docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md §3.2 and docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md Card 9. Do not edit production code. Do not touch Epistemos/Sovereign/SovereignGate.swift, existing EpistemosTests/SovereignGateTests.swift, Phase7Bridge.swift, Phase5Bridge.swift, current docs/fusion/deliberation files, ProseEditor*, MetalGraphView.swift, HologramController.swift, graph physics/render internals, project.pbxproj, Cargo.toml, or Package.swift.

Task: create /Users/jojo/Downloads/Epistemos/EpistemosTests/SovereignGateRequirementMatrixTests.swift. Use Swift Testing. Add tests that source-scan the repo for LAContext() and verify the only Swift source implementation is Epistemos/Sovereign/SovereignGate.swift. Add test-only assertions for existing helper mappings already visible from @testable import Epistemos, such as notes/sidebar delete, settings reset/delete/disconnect, chat delete, model-vault delete, or custom-tool delete, and verify destructive actions map to .deviceOwnerAuthentication. Run: xcodebuild -project /Users/jojo/Downloads/Epistemos/Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/SovereignGateRequirementMatrixTests test. If an expected helper is unavailable, choose another existing helper from SovereignGateTests; do not patch production.
```

### P4 - Durable GraphEvent Projection Fixture Tests
**Lane (doctrine §7):** Core open - live GraphEvent consumer projection preparation
**Effort:** M
**Who:** agent-2-ok
**Status:** open

**What.**
Create a new test-only fixture suite that exercises existing durable GraphEvent projection folding/reporting with synthetic events. The goal is not to build the live graph consumer yet; it is to lock the projection semantics Codex will rely on before touching live consumer surfaces.

**Files touched (precise paths, all new unless flagged):**
- /Users/jojo/Downloads/Epistemos/EpistemosTests/GraphEventProjectionFixtureTests.swift (NEW)

**Why safe.**
This is a new test file and does not edit GraphEvent production code, renderer code, graph physics, `MetalGraphView.swift`, `HologramController.swift`, or Codex's reserved `GraphEventConsumerProjectionGuardTests.swift`.

**Why useful now.**
It advances doctrine §7 "Live GraphEvent consumer projection" by reducing future uncertainty around projection snapshots before any visible graph/Halo/Theater mutation.

**Acceptance.**
- New Swift Testing file exists.
- Tests reuse existing public/internal durable GraphEvent projection APIs from `GraphEventAuditProjectionTests.swift` patterns.
- Tests cover chronological folding, duplicate or repeated node/edge references if supported, bounded limit behavior, and empty input behavior.
- No production files are modified.
- Focused test command passes or reports exact missing API without patching production.

**If picked by agent-2, paste this prompt:**
```text
You are a parallel coding agent in /Users/jojo/Downloads/Epistemos. Read AGENTS.md and docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md Card 8. Do not edit production code. Do not touch Epistemos/Views/Graph/MetalGraphView.swift, Epistemos/Views/Graph/HologramController.swift, graph-engine, graph physics/render internals, Epistemos/Engine/GraphEventAuditProjectionService.swift, Epistemos/State/EventStore.swift, current docs/fusion/deliberation files, Phase7Bridge.swift, Phase5Bridge.swift, project.pbxproj, Cargo.toml, or Package.swift.

Task: create /Users/jojo/Downloads/Epistemos/EpistemosTests/GraphEventProjectionFixtureTests.swift. Use Swift Testing. Read EpistemosTests/GraphEventAuditProjectionTests.swift for existing fixture patterns, then add synthetic durable GraphEvent projection tests that cover empty input, chronological folding/reporting, bounded limit behavior if available, and duplicate/repeated node or edge reference behavior if supported by current APIs. Do not implement missing production APIs. Run: xcodebuild -project /Users/jojo/Downloads/Epistemos/Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/GraphEventProjectionFixtureTests test. If a desired invariant cannot be expressed with current APIs, report it in the test file comments or final note; do not patch production.
```

### P5 - R15 Live MLX Memory Preflight Artifact
**Lane (doctrine §7):** Core open - R15 remaining specialized baselines
**Effort:** S
**Who:** either
**Status:** open

**What.**
Produce the missing machine-state artifact for the blocked live MLX throughput lane. This is not a code change: capture memory/thermal/power preflight output so Codex can decide whether the live tok/s harness is safe to run later.

**Files touched (precise paths, all new unless flagged):**
- /Users/jojo/Downloads/Epistemos/docs/fusion/fleet/r15-live-mlx-memory-preflight/R15_LIVE_MLX_MEMORY_PREFLIGHT_2026_05_03.md (NEW)

**Why safe.**
This creates a new future-lane doc folder outside the current slice and does not edit canon state docs. It touches no code and cannot collide with Codex's bridge/provenance patches.

**Why useful now.**
It advances doctrine §7 "R15 remaining specialized baselines"; the live MLX benchmark is currently blocked on insufficient-memory evidence, so this gives a concrete unblock signal.

**Acceptance.**
- New artifact exists with timestamp, machine model if available, `sysctl hw.memsize`, `vm_stat`, disk free, and whether the machine was on AC power.
- The artifact states "safe to run live MLX harness: yes/no/unknown" with evidence.
- No code or canon docs are edited.

**If picked by agent-2, paste this prompt:**
```text
You are a parallel agent in /Users/jojo/Downloads/Epistemos. This is read-only except for creating one new artifact file. Do not edit code, tests, project files, or existing docs. Do not run the live MLX benchmark. Do not touch current docs/fusion/deliberation files or docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md.

Task: create /Users/jojo/Downloads/Epistemos/docs/fusion/fleet/r15-live-mlx-memory-preflight/R15_LIVE_MLX_MEMORY_PREFLIGHT_2026_05_03.md. Capture outputs from: date -u, sw_vers, sysctl hw.memsize, vm_stat, df -h /, pmset -g batt, and if safe available memory estimates from vm_stat page counts. Summarize whether the R15 live MLX tok/s harness should remain blocked or can be attempted later. Do not run any benchmark. Do not edit any other files.
```

### P6 - AgentEvent Runtime Coverage Map for Remaining Bridges
**Lane (doctrine §7):** Core open - broader runtime AgentEvent coverage
**Effort:** M
**Who:** agent-2-ok
**Status:** open

**What.**
Create a read-only coverage map of remaining `Epistemos/Bridge/*Bridge.swift` and Omega runtime surfaces that still lack AgentEvent provenance. This should not patch code; it should identify safe future slices after Phase7/Phase5.

**Files touched (precise paths, all new unless flagged):**
- /Users/jojo/Downloads/Epistemos/docs/fusion/fleet/agent-event-runtime-coverage-map/AGENT_EVENT_RUNTIME_COVERAGE_MAP_2026_05_03.md (NEW)

**Why safe.**
This creates one new doc outside Codex's current slice folders and does not edit source or canon state docs. It avoids the reserved Phase7/Phase5 files by treating them as "reserved/in-flight" rather than auditing them deeply.

**Why useful now.**
It advances doctrine §7 "broader runtime AgentEvent coverage" by handing Codex the next safe targets after the current bridge slices, with no collision risk.

**Acceptance.**
- New map exists.
- It lists each inspected bridge/runtime file, whether it already emits AgentEvents, and the smallest future safe slice if not.
- It marks Phase7Bridge.swift and Phase5Bridge.swift as reserved/in-flight and does not recommend editing them.
- It names any source that carries sensitive payload risk and should require sanitization tests.
- No code or canon docs are edited.

**If picked by agent-2, paste this prompt:**
```text
You are a parallel research agent in /Users/jojo/Downloads/Epistemos. Read AGENTS.md, docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md Safe Next Build Order item 3, and docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md Card 7. Read-only except for one new doc. Do not edit source code. Do not touch Phase7Bridge.swift, Phase5Bridge.swift, current docs/fusion/deliberation files, docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md, docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md, ProseEditor*, MetalGraphView.swift, HologramController.swift, graph physics/render internals, project.pbxproj, Cargo.toml, or Package.swift.

Task: create /Users/jojo/Downloads/Epistemos/docs/fusion/fleet/agent-event-runtime-coverage-map/AGENT_EVENT_RUNTIME_COVERAGE_MAP_2026_05_03.md. Inspect Epistemos/Bridge/*.swift and obvious Omega runtime files for AgentToolProvenanceRecorder / AgentProvenanceEvent usage. For each surface, record: file path, tool/action names, already instrumented yes/no, sensitive payload risk yes/no, and smallest future safe PR slice. Mark Phase7Bridge.swift and Phase5Bridge.swift reserved/in-flight; do not recommend edits to them. Do not modify code.
```

## History (claimed / done / superseded / stale)
| Item | Status | Resolved at | Notes |
|---|---|---|---|
