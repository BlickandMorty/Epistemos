# Parallel Work Manifest - refreshed 2026-05-03T17:12Z

## Codex current state

- Slice in flight: clarify-prompt-bridge-agent-event-pr43 setup
- Round: 82
- Slices reserved (next 3): [clarify-prompt-bridge-agent-event-pr43, graph-event-live-consumer-selection-pr44, next-provenance-or-security-slice-pr45]
- Anchor heartbeat: ANCHOR: slice=parallel-work-manifest-refresh | round=82 | terminal=session:4012 | claude-side=desktop-app:idle | claude-red-team=off | reading=[CODEX_PARALLEL_WORK_RATIONALE_PROMPT_2026_05_03.md,AGENT_EVENT_RUNTIME_COVERAGE_MAP_2026_05_03.md,UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md,AGENT_BUILD_WORKCARDS_2026_05_01.md]

## Codex reservation set

- /Users/jojo/Downloads/Epistemos/Epistemos/Bridge/ClarifyPromptBridge.swift
- /Users/jojo/Downloads/Epistemos/EpistemosTests/ClarifyPromptBridgeAgentEventTests.swift
- /Users/jojo/Downloads/Epistemos/docs/fusion/fleet/clarify-prompt-bridge-agent-event-pr43/
- /Users/jojo/Downloads/Epistemos/docs/fusion/deliberation/clarify_prompt_bridge_agent_event_pr43_deliberation_2026_05_03.md
- /Users/jojo/Downloads/Epistemos/docs/fusion/oversight/PREFLIGHT_83_2026_05_03.md
- /Users/jojo/Downloads/Epistemos/docs/fusion/fleet/graph-event-live-consumer-selection-pr44/
- /Users/jojo/Downloads/Epistemos/docs/fusion/deliberation/graph_event_live_consumer_selection_pr44_deliberation_2026_05_03.md
- /Users/jojo/Downloads/Epistemos/docs/fusion/oversight/PREFLIGHT_84_2026_05_03.md
- /Users/jojo/Downloads/Epistemos/docs/fusion/fleet/next-provenance-or-security-slice-pr45/
- /Users/jojo/Downloads/Epistemos/docs/fusion/deliberation/next_provenance_or_security_slice_pr45_deliberation_2026_05_03.md
- /Users/jojo/Downloads/Epistemos/docs/fusion/oversight/PREFLIGHT_85_2026_05_03.md
- /Users/jojo/Downloads/Epistemos/docs/fusion/oversight/POST_MERGE_GUARDS_2026_05_02.md
- /Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
- /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
- /Users/jojo/Downloads/Epistemos/docs/fusion/fleet/REGISTRY.md
- /Users/jojo/Downloads/Epistemos/docs/fusion/fleet/PARALLEL_WORK_MANIFEST.md

## Canon / protected no-touch list

- Do not edit current canon-in-flight docs: `MASTER_RESEARCH_INDEX_2026_05_02.md`, `EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md`, `UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`, `CODEX_FINAL_EXECUTION_PROMPT_2026_05_01.md`, `CODEX_AGENT_FLEET_PROMPT_2026_05_02.md`, `AGENT_BUILD_WORKCARDS_2026_05_01.md`, current `docs/fusion/deliberation/`, current `docs/fusion/oversight/`, or current `docs/fusion/fleet/<slice>/`.
- Do not touch protected code paths: `Epistemos/Views/Notes/ProseEditor*.swift`, `Epistemos/Views/Graph/MetalGraphView.swift`, `Epistemos/Views/Graph/HologramController.swift`, graph physics/render internals, generated `.rlib`, `DerivedData`, `.xcresult`, `Epistemos.xcodeproj/project.pbxproj`, `Cargo.toml`, `Package.swift`, or build scripts unless explicitly coordinated.
- Do not touch `ClarifyPromptBridge.swift` or `ClarifyPromptBridgeAgentEventTests.swift`. Codex has those reserved for PR43.
- Do not run broad `xcodebuild test` while Codex is mid-editing PR43. Doc-only tasks are the cleanest parallel lane right now.

## Parallel work items (open)

### P1 - AgentEvent Coverage Map PR42 Delta

**Lane (doctrine section 7):** Core open - broader runtime AgentEvent coverage
**Effort:** S
**Who:** agent-2-ok
**Status:** open

**What.**
Create a new delta doc that updates the runtime coverage map after PR39 through PR42. Do not edit the original coverage map. Mark ComputerUseBridge and the three Phase4 surfaces closed, then re-rank the remaining bridge gap as ClarifyPromptBridge plus explicit no-instrument surfaces.

**Files touched (precise paths, all new unless flagged):**
- /Users/jojo/Downloads/Epistemos/docs/fusion/fleet/agent-event-runtime-coverage-map/AGENT_EVENT_RUNTIME_COVERAGE_MAP_PR42_DELTA_2026_05_03.md (NEW)

**Why safe.**
This is a new doc inside an already-existing fleet subfolder. It avoids Codex's reserved `ClarifyPromptBridge.swift`, PR43 docs, current canon docs, current oversight/deliberation folders, graph/editor/protected paths, project files, package files, and build scripts.

**Why useful now.**
Codex has closed CUB-1 and P4 perceive/interact/watch. This prevents stale guidance from telling the next agent to rebuild already-committed work and makes CPB-1 the obvious next bridge gap.

**Acceptance.**
- New delta doc exists.
- It cites commits `92b40126`, `f41efb05`, `3c9ee48f`, and `29717395`.
- It marks ComputerUseBridge, Phase4 perceive, Phase4 interact, and Phase4 screen_watch closed.
- It re-ranks remaining AgentEvent coverage gaps and explicitly preserves the no-instrument rationale for transport/parser/router layers.
- No existing docs or code are modified.

**If picked by agent-2, paste this prompt:**
```text
You are a parallel research agent in /Users/jojo/Downloads/Epistemos. Read AGENTS.md, docs/fusion/fleet/agent-event-runtime-coverage-map/AGENT_EVENT_RUNTIME_COVERAGE_MAP_2026_05_03.md, and git show --stat 92b40126 f41efb05 3c9ee48f 29717395. Do not edit code, current canon docs, current docs/fusion/deliberation files, current docs/fusion/oversight files, ClarifyPromptBridge.swift, ClarifyPromptBridgeAgentEventTests.swift, project.pbxproj, Cargo.toml, Package.swift, ProseEditor*, MetalGraphView.swift, HologramController.swift, or graph internals.

Task: create /Users/jojo/Downloads/Epistemos/docs/fusion/fleet/agent-event-runtime-coverage-map/AGENT_EVENT_RUNTIME_COVERAGE_MAP_PR42_DELTA_2026_05_03.md. Mark ComputerUseBridge/CUB-1 closed by 92b40126, Phase4 perceive closed by f41efb05, Phase4 interact closed by 3c9ee48f, and Phase4 screen_watch closed by 29717395. Re-rank the remaining safe slices, with ClarifyPromptBridge/CPB-1 as the remaining bridge gap unless current code proves otherwise. Preserve the explicit "do not instrument" rationale for ChunkedMCPFraming, CoTStreamInterceptor, StreamingDelegate, and ToolTierBridge. Do not modify the original map.
```

### P2 - Sovereign Gate Future Workcards Draft

**Lane (doctrine section 7):** Core killer-feature seed work - Sovereign Gate follow-through
**Effort:** M
**Who:** agent-2-ok
**Status:** open

**What.**
Convert the existing Sovereign Gate surface map into 3-5 future workcard drafts in a new doc. Do not edit the canonical workcards file. Each draft should name the surface, risk, allowed files, forbidden files, tests, and stop triggers.

**Files touched (precise paths, all new unless flagged):**
- /Users/jojo/Downloads/Epistemos/docs/fusion/fleet/sovereign-gate-surface-map/SOVEREIGN_GATE_FUTURE_WORKCARDS_DRAFT_2026_05_03.md (NEW)

**Why safe.**
This is a new doc only. It does not touch SovereignGate code/tests, Codex's reserved ClarifyPromptBridge files, current canon, graph, editor, project, package, or build-script files.

**Why useful now.**
It turns the Sovereign killer-feature seed lane from a broad map into executable future slices while Codex continues the provenance queue.

**Acceptance.**
- New draft doc exists.
- It contains 3-5 narrow future cards, each with allowed/forbidden files and acceptance tests.
- It explicitly says the drafts are not canon until Codex/user approves them.
- No code or existing docs are modified.

**If picked by agent-2, paste this prompt:**
```text
You are a parallel research agent in /Users/jojo/Downloads/Epistemos. Read AGENTS.md, docs/fusion/fleet/sovereign-gate-surface-map/SOVEREIGN_GATE_SURFACE_MAP_2026_05_03.md, and the template in docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md without editing it. Do not edit existing canon docs, code, tests, ClarifyPromptBridge.swift, current deliberation/oversight/fleet folders, project.pbxproj, Cargo.toml, Package.swift, ProseEditor*, MetalGraphView.swift, HologramController.swift, or graph internals.

Task: create /Users/jojo/Downloads/Epistemos/docs/fusion/fleet/sovereign-gate-surface-map/SOVEREIGN_GATE_FUTURE_WORKCARDS_DRAFT_2026_05_03.md. Draft 3-5 future Sovereign Gate workcards from the map. Each draft must include goal, authority to read first, allowed write set, forbidden write set, tests/logs, acceptance, and stop triggers. Mark the file as draft/non-canonical until approved.
```

### P3 - R15 MLX Go/No-Go Decision Note

**Lane (doctrine section 7):** Core open - R15 remaining specialized baselines
**Effort:** S
**Who:** either
**Status:** open

**What.**
Read the existing R15 live MLX memory preflight artifact and write a short go/no-go decision note. Do not run the live MLX benchmark.

**Files touched (precise paths, all new unless flagged):**
- /Users/jojo/Downloads/Epistemos/docs/fusion/fleet/r15-live-mlx-memory-preflight/R15_LIVE_MLX_GO_NO_GO_2026_05_03.md (NEW)

**Why safe.**
This is a new doc only. It does not touch code, benchmarks, current canon, Codex's reserved ClarifyPromptBridge files, project files, package files, or build scripts.

**Why useful now.**
The R15 lane remains blocked on sufficient-memory/thermal evidence. This converts Claude's collected machine facts into a clear next decision without interrupting Codex's PR43 code work.

**Acceptance.**
- Decision note exists.
- It cites the existing preflight artifact path.
- It concludes `go`, `no-go`, or `unknown`, with one paragraph of reasoning.
- It explicitly says no live MLX benchmark was run.

**If picked by agent-2, paste this prompt:**
```text
You are a parallel research agent in /Users/jojo/Downloads/Epistemos. Read AGENTS.md and /Users/jojo/Downloads/Epistemos/docs/fusion/fleet/r15-live-mlx-memory-preflight/R15_LIVE_MLX_MEMORY_PREFLIGHT_2026_05_03.md. Do not edit code, current canon docs, current deliberation/oversight docs, ClarifyPromptBridge.swift, project files, package files, or build scripts. Do not run any live MLX benchmark.

Task: create /Users/jojo/Downloads/Epistemos/docs/fusion/fleet/r15-live-mlx-memory-preflight/R15_LIVE_MLX_GO_NO_GO_2026_05_03.md. Summarize the memory/power/storage evidence and conclude go/no-go/unknown for attempting the R15 live MLX tok/s harness later. State clearly that no benchmark was run.
```

### P4 - Lanes 3-6 Workcard Scaffolding Draft

**Lane (doctrine section 7):** Pro track and Research track - future executable cards
**Effort:** M
**Who:** agent-2-ok
**Status:** open

**What.**
Draft future workcards for Lanes 3-6 in a new file without editing the May 1 canonical workcards. Focus on Resonance Gate seed, Pro Developer ID/Notarization, Pro embedded JS/runtime gate, Research ANE gate, and ternary/Sherry scaffolding.

**Files touched (precise paths, all new unless flagged):**
- /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_LANES_3_TO_6_2026_05_03.md (NEW)

**Why safe.**
This creates a new planning file only. It avoids Codex's reserved ClarifyPromptBridge files, current canon docs, current PR43/PR44/PR45 fleet folders, protected source paths, project files, package files, and build scripts.

**Why useful now.**
The current workcards are strong for the Core-open queue, but future Pro/Research substrate lanes need executable cards before agents start building assumptions into code.

**Acceptance.**
- New draft doc exists.
- It contains at least 6 future cards with scope, tier, dependencies, allowed files, forbidden files, tests, rollback, and stop triggers.
- It clearly says the file is draft/non-canonical until approved.
- No existing canon docs or code are modified.

**If picked by agent-2, paste this prompt:**
```text
You are a parallel planning agent in /Users/jojo/Downloads/Epistemos. Read AGENTS.md, docs/fusion/EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md section 7, docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md table of contents, and docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md template only. Do not edit existing canon docs, code, tests, ClarifyPromptBridge.swift, current deliberation/oversight/fleet folders, project.pbxproj, Cargo.toml, Package.swift, ProseEditor*, MetalGraphView.swift, HologramController.swift, graph internals, or build scripts.

Task: create /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_LANES_3_TO_6_2026_05_03.md. Draft at least 6 future cards for Lanes 3-6: Resonance Gate seed, MAS/Core symbol separation closure, Pro Developer ID/Notarization, Pro embedded JS/runtime gate, Research ANE direct-path gate, and Sherry/ternary scaffolding. Each card must include scope, tier, dependencies, allowed files, forbidden files, tests/logs, rollback, and stop triggers. Mark the file as draft/non-canonical until approved.
```

### P5 - AgentEvent Bridge No-Double-Count Source Guards

**Lane (doctrine section 7):** Core open - AgentEvent provenance hardening
**Effort:** S
**Who:** agent-2-ok
**Status:** open

**What.**
Create a source-only Swift Testing suite that locks the "do not instrument here" conclusions from the runtime coverage map: `StreamingDelegate`, `ChunkedMCPFraming`, `CoTStreamInterceptor`, and Swift-side `ToolTierBridge` must not directly call `recordToolEvent` because they are routing/transport/parser layers.

**Files touched (precise paths, all new unless flagged):**
- /Users/jojo/Downloads/Epistemos/EpistemosTests/AgentEventBridgeNoDoubleCountSourceGuardTests.swift (NEW)

**Why safe.**
This creates a new test file only and does not edit production code. It avoids Codex's reserved ClarifyPromptBridge test/source files, current canon, graph/editor/protected paths, project files, package files, and build scripts.

**Why useful now.**
It prevents a future agent from adding duplicate AgentEvents at the wrong layer, which would corrupt the audit timeline and inflate the event table.

**Acceptance.**
- New test file exists.
- Tests assert the four named files do not contain direct `recordToolEvent` or `AgentToolProvenanceRecorder` instrumentation.
- Tests include comments naming where provenance should live instead.
- Run a focused test only after Codex is not mid-editing PR43, or leave the command/log path for Codex to run after commit.

**If picked by agent-2, paste this prompt:**
```text
You are a parallel coding agent in /Users/jojo/Downloads/Epistemos. Read AGENTS.md, docs/fusion/fleet/agent-event-runtime-coverage-map/AGENT_EVENT_RUNTIME_COVERAGE_MAP_2026_05_03.md section 4, and docs/fusion/fleet/PARALLEL_WORK_MANIFEST.md item P5. Do not edit production code or current canon docs. Do not touch ClarifyPromptBridge.swift, ClarifyPromptBridgeAgentEventTests.swift, current docs/fusion/deliberation or docs/fusion/oversight file, project.pbxproj, Cargo.toml, Package.swift, ProseEditor*, MetalGraphView.swift, HologramController.swift, or graph internals.

Task: create /Users/jojo/Downloads/Epistemos/EpistemosTests/AgentEventBridgeNoDoubleCountSourceGuardTests.swift. Use Swift Testing. Read source files by path and assert `StreamingDelegate.swift`, `ChunkedMCPFraming.swift`, `CoTStreamInterceptor.swift`, and `ToolTierBridge.swift` do not directly call `recordToolEvent` or instantiate `AgentToolProvenanceRecorder`. Add short test comments explaining that AgentEvents belong at downstream tool/bridge execution sites, not transport/parser layers. Do not run broad test commands while Codex is mid-editing PR43; either run a focused test after Codex commits PR43 or report the command to run later.
```

### P6 - Parallel Test Artifact Verification Bundle

**Lane (doctrine section 7):** Core open - parallel quality gate
**Effort:** M
**Who:** agent-2-ok
**Status:** open

**What.**
Verify the uncommitted parallel-agent test artifacts from the prior manifest without staging or committing them. Run focused tests for each new test file after Codex finishes PR43, and write a single verification report that says which are green, which need repair, and which should be deferred.

**Files touched (precise paths, all new unless flagged):**
- /Users/jojo/Downloads/Epistemos/docs/fusion/fleet/parallel-test-artifact-verification/PARALLEL_TEST_ARTIFACT_VERIFICATION_2026_05_03.md (NEW)
- Existing uncommitted test files may be edited only if needed to fix compile/test failures: `HermesGatewayEvidenceContractTests.swift`, `ToolSurfaceBehavioralMatrixTests.swift`, `HermesPromptFormatGuardTests.swift`, `GraphEventProjectionFixtureTests.swift`, `CoreMASBoundarySourceGuardTests.swift`, `SovereignGateRequirementMatrixTests.swift`.

**Why safe.**
Codex is not reserving those existing parallel test files in the next three slices. The report is a new docs/fusion/fleet subfolder, and the item does not touch ClarifyPromptBridge, production code, current canon, project files, graph, or editor files.

**Why useful now.**
Claude created useful guard suites. This converts them from promising untracked files into a verified integration queue Codex can consume safely later.

**Acceptance.**
- Report lists each artifact, focused command, log path, pass/fail, and integration recommendation.
- If a test file is repaired, the report names the exact change and why it remains test-only.
- No production files are modified.
- No staging or commit is performed.

**If picked by agent-2, paste this prompt:**
```text
You are a parallel verification agent in /Users/jojo/Downloads/Epistemos. Read AGENTS.md and docs/fusion/fleet/PARALLEL_WORK_MANIFEST.md item P6. Do not edit production code, current canon docs, ClarifyPromptBridge.swift, ClarifyPromptBridgeAgentEventTests.swift, project.pbxproj, Cargo.toml, Package.swift, ProseEditor*, MetalGraphView.swift, HologramController.swift, or graph internals. Do not stage or commit. If Codex is actively editing PR43, wait until Codex reports PR43 committed before running xcodebuild.

Task: verify these uncommitted parallel test artifacts if present: EpistemosTests/HermesGatewayEvidenceContractTests.swift, EpistemosTests/ToolSurfaceBehavioralMatrixTests.swift, EpistemosTests/HermesPromptFormatGuardTests.swift, EpistemosTests/GraphEventProjectionFixtureTests.swift, EpistemosTests/CoreMASBoundarySourceGuardTests.swift, EpistemosTests/SovereignGateRequirementMatrixTests.swift. Run focused xcodebuild tests per file when safe. If a test fails to compile due to test-only API naming or helper placement, you may repair only that test file. Write /Users/jojo/Downloads/Epistemos/docs/fusion/fleet/parallel-test-artifact-verification/PARALLEL_TEST_ARTIFACT_VERIFICATION_2026_05_03.md with commands, log paths, pass/fail, files touched, and recommendation. Do not modify production.
```

## History (claimed / done / superseded / stale)

| Item | Status | Resolved at | Notes |
|---|---|---|---|
| Round 75 P1 Hermes Gateway Evidence Contract Tests | done-uncommitted | 2026-05-03T16:20Z | Claude created `/Users/jojo/Downloads/Epistemos/EpistemosTests/HermesGatewayEvidenceContractTests.swift`; not staged by Codex. |
| Round 75 P2 Tool Surface Behavioral Matrix Tests | done-uncommitted | 2026-05-03T16:20Z | Claude created `/Users/jojo/Downloads/Epistemos/EpistemosTests/ToolSurfaceBehavioralMatrixTests.swift`; not staged by Codex. |
| Round 75 P3 Durable GraphEvent Projection Fixture Tests | done-uncommitted | 2026-05-03T16:20Z | Claude created `/Users/jojo/Downloads/Epistemos/EpistemosTests/GraphEventProjectionFixtureTests.swift`; Codex repaired compile order during PR38 but did not stage it. |
| Round 75 P4 AgentEvent Runtime Coverage Map | done-uncommitted | 2026-05-03T16:20Z | Claude created `/Users/jojo/Downloads/Epistemos/docs/fusion/fleet/agent-event-runtime-coverage-map/AGENT_EVENT_RUNTIME_COVERAGE_MAP_2026_05_03.md`; Codex consumed it for PR39-PR42. |
| Round 75 P5 R15 Live MLX Memory Preflight Artifact | done-uncommitted | 2026-05-03T16:20Z | Claude created `/Users/jojo/Downloads/Epistemos/docs/fusion/fleet/r15-live-mlx-memory-preflight/R15_LIVE_MLX_MEMORY_PREFLIGHT_2026_05_03.md`; not staged by Codex. |
| Round 75 P6 Hermes Prompt Format Guard Tests | done-uncommitted | 2026-05-03T16:20Z | Claude created `/Users/jojo/Downloads/Epistemos/EpistemosTests/HermesPromptFormatGuardTests.swift`; not staged by Codex. |
| Round 75 P7 Sovereign Gate Surface Backlog Map | done-uncommitted | 2026-05-03T16:20Z | Claude created `/Users/jojo/Downloads/Epistemos/docs/fusion/fleet/sovereign-gate-surface-map/SOVEREIGN_GATE_SURFACE_MAP_2026_05_03.md`; not staged by Codex. |
| ComputerUseBridge AgentEvent provenance | done-committed | 2026-05-03T16:33Z | Codex closed and committed PR39 as `92b40126 Record ComputerUseBridge AgentEvents`. |
| Phase4 perceive AgentEvent provenance | done-committed | 2026-05-03T16:44Z | Codex closed and committed PR40 as `f41efb05 Record Phase4 perceive AgentEvents`. |
| Phase4 interact AgentEvent provenance | done-committed | 2026-05-03T16:52Z | Codex closed and committed PR41 as `3c9ee48f Record Phase4 interact AgentEvents`. |
| Phase4 screen_watch AgentEvent provenance | done-committed | 2026-05-03T17:06Z | Codex closed and committed PR42 as `29717395 Record Phase4 screen watch AgentEvents`. |
