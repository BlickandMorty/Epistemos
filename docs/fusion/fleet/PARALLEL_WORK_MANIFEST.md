# Parallel Work Manifest - refreshed 2026-05-03T16:40Z

## Codex current state

- Slice in flight: phase4-perceive-agent-event-pr40 setup
- Round: 78
- Slices reserved (next 3): [phase4-perceive-agent-event-pr40, phase4-interact-agent-event-pr41, phase4-screen-watch-agent-event-pr42]
- Anchor heartbeat: ANCHOR: slice=parallel-work-manifest-refresh | round=78 | terminal=session:4012 | claude-side=desktop-app:idle | claude-red-team=off | reading=[PARALLEL_WORK_MANIFEST.md,AGENT_EVENT_RUNTIME_COVERAGE_MAP_2026_05_03.md,UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md,AGENT_BUILD_WORKCARDS_2026_05_01.md,REGISTRY.md]

## Codex reservation set

- /Users/jojo/Downloads/Epistemos/Epistemos/Bridge/Phase4Bridge.swift
- /Users/jojo/Downloads/Epistemos/EpistemosTests/Phase4BridgePerceiveAgentEventTests.swift
- /Users/jojo/Downloads/Epistemos/EpistemosTests/Phase4BridgeInteractAgentEventTests.swift
- /Users/jojo/Downloads/Epistemos/EpistemosTests/Phase4BridgeScreenWatchAgentEventTests.swift
- /Users/jojo/Downloads/Epistemos/docs/fusion/fleet/phase4-perceive-agent-event-pr40/
- /Users/jojo/Downloads/Epistemos/docs/fusion/fleet/phase4-interact-agent-event-pr41/
- /Users/jojo/Downloads/Epistemos/docs/fusion/fleet/phase4-screen-watch-agent-event-pr42/
- /Users/jojo/Downloads/Epistemos/docs/fusion/deliberation/phase4_perceive_agent_event_pr40_deliberation_2026_05_03.md
- /Users/jojo/Downloads/Epistemos/docs/fusion/deliberation/phase4_interact_agent_event_pr41_deliberation_2026_05_03.md
- /Users/jojo/Downloads/Epistemos/docs/fusion/deliberation/phase4_screen_watch_agent_event_pr42_deliberation_2026_05_03.md
- /Users/jojo/Downloads/Epistemos/docs/fusion/oversight/PREFLIGHT_78_2026_05_03.md
- /Users/jojo/Downloads/Epistemos/docs/fusion/oversight/PREFLIGHT_79_2026_05_03.md
- /Users/jojo/Downloads/Epistemos/docs/fusion/oversight/PREFLIGHT_80_2026_05_03.md
- /Users/jojo/Downloads/Epistemos/docs/fusion/oversight/POST_MERGE_GUARDS_2026_05_02.md
- /Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
- /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
- /Users/jojo/Downloads/Epistemos/docs/fusion/fleet/REGISTRY.md
- /Users/jojo/Downloads/Epistemos/docs/fusion/fleet/PARALLEL_WORK_MANIFEST.md

## Canon / protected no-touch list

- Do not edit current canon-in-flight docs: `MASTER_RESEARCH_INDEX_2026_05_02.md`, `EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md`, `UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`, `CODEX_FINAL_EXECUTION_PROMPT_2026_05_01.md`, `CODEX_AGENT_FLEET_PROMPT_2026_05_02.md`, `AGENT_BUILD_WORKCARDS_2026_05_01.md`, current `docs/fusion/deliberation/`, current `docs/fusion/oversight/`, or current `docs/fusion/fleet/<slice>/`.
- Do not touch protected code paths: `Epistemos/Views/Notes/ProseEditor*.swift`, `Epistemos/Views/Graph/MetalGraphView.swift`, `Epistemos/Views/Graph/HologramController.swift`, graph physics/render internals, generated `.rlib`, `DerivedData`, `.xcresult`, `Epistemos.xcodeproj/project.pbxproj`, `Cargo.toml`, `Package.swift`, or build scripts unless explicitly coordinated.
- Do not touch `Epistemos/Bridge/Phase4Bridge.swift` or any Phase4 test file this round. Codex has those reserved.

## Parallel work items (open)

### P1 - ClarifyPromptBridge AgentEvent Provenance

**Lane (doctrine section 7):** Core open - broader runtime AgentEvent coverage
**Effort:** M
**Who:** agent-2-ok
**Status:** open

**What.**
Instrument the existing clarify prompt bridge with bounded AgentEvents. The user-facing answer must not be persisted; record only question/action class, answer length bucket, selected-choice index if present, answered/cancelled status, duration, and bounded failure class.

**Files touched (precise paths, all new unless flagged):**
- /Users/jojo/Downloads/Epistemos/Epistemos/Bridge/ClarifyPromptBridge.swift (EXISTS)
- /Users/jojo/Downloads/Epistemos/EpistemosTests/ClarifyPromptBridgeAgentEventTests.swift (NEW)
- /tmp/epistemos-clarify-prompt-agent-event-pr40-claude.log (NEW log)

**Why safe.**
These files are disjoint from Codex's reserved Phase4 files. This item avoids `Phase4Bridge.swift`, all Phase4 test files, current deliberation/oversight/fleet folders, current canon docs, graph, editor, project, package, and build-script files.

**Why useful now.**
The AgentEvent runtime coverage map identified ClarifyPromptBridge as the next clean bridge after ComputerUse and Phase4. It closes a Core+Pro audit gap while Codex works the high-risk Phase4 bridge.

**Acceptance.**
- `ClarifyPromptBridge.swift` records requested/started/completed-or-failed events around the existing clarify flow.
- Tests prove the user's free-form answer is not persisted in `argumentsJSON`, `resultJSON`, `errorMessage`, or metadata.
- Tests cover answered, cancelled/empty, invalid JSON if applicable, and source guards against raw payload persistence.
- Focused test command is run and log path is reported.

**If picked by agent-2, paste this prompt:**
```text
You are a parallel coding agent in /Users/jojo/Downloads/Epistemos on the same branch as Codex. Read /Users/jojo/Downloads/Epistemos/AGENTS.md, docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md section 2 and section 13, docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md Safe Next Build Order item 3, docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md Card 7, and docs/fusion/fleet/PARALLEL_WORK_MANIFEST.md item P1.

Do not edit Phase4Bridge.swift, Phase4BridgePerceiveAgentEventTests.swift, Phase4BridgeInteractAgentEventTests.swift, Phase4BridgeScreenWatchAgentEventTests.swift, current docs/fusion/deliberation files, current docs/fusion/oversight files, current docs/fusion/fleet/phase4-* folders, ProseEditor*, MetalGraphView.swift, HologramController.swift, graph physics/render internals, project.pbxproj, Cargo.toml, Package.swift, or build scripts.

Task: add bounded AgentEvent provenance to /Users/jojo/Downloads/Epistemos/Epistemos/Bridge/ClarifyPromptBridge.swift and create /Users/jojo/Downloads/Epistemos/EpistemosTests/ClarifyPromptBridgeAgentEventTests.swift. Preserve existing clarify behavior. Persist only sanitized data: question/action class, answer length bucket, selected-choice index if present, answered/cancelled status, duration, and bounded failure class. Never persist the user's raw answer, raw question text, raw JSON payload, localized descriptions, or arbitrary error text in AgentEvent JSON/metadata. Run: xcodebuild -project /Users/jojo/Downloads/Epistemos/Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/ClarifyPromptBridgeAgentEventTests test 2>&1 | tee /tmp/epistemos-clarify-prompt-agent-event-pr40-claude.log. If the bridge cannot be tested without UI seams, add the smallest internal injection seam and stop before touching unrelated code.
```

### P2 - Bridge No-Double-Count Source Guards

**Lane (doctrine section 7):** Core open - AgentEvent provenance hardening
**Effort:** S
**Who:** agent-2-ok
**Status:** open

**What.**
Create a source-only Swift Testing suite that locks the "do not instrument here" conclusions from the runtime coverage map: `StreamingDelegate`, `ChunkedMCPFraming`, `CoTStreamInterceptor`, and Swift-side `ToolTierBridge` must not directly call `recordToolEvent` because they are routing/transport/parser layers.

**Files touched (precise paths, all new unless flagged):**
- /Users/jojo/Downloads/Epistemos/EpistemosTests/AgentEventBridgeNoDoubleCountSourceGuardTests.swift (NEW)

**Why safe.**
New test file only, outside Codex's Phase4 reservation set. It reads source but does not edit production code, current canon, current slice docs, project files, graph, or editor files.

**Why useful now.**
It prevents a future agent from "helpfully" adding duplicate AgentEvents at the wrong layer, which would corrupt the audit timeline and inflate the event table.

**Acceptance.**
- New test file exists.
- Tests assert the four named files do not contain direct `recordToolEvent` / `AgentToolProvenanceRecorder` instrumentation.
- Tests include comments naming where provenance should live instead.
- Focused test runs or the agent reports why the test target cannot discover the new file.

**If picked by agent-2, paste this prompt:**
```text
You are a parallel coding agent in /Users/jojo/Downloads/Epistemos. Read AGENTS.md, docs/fusion/fleet/agent-event-runtime-coverage-map/AGENT_EVENT_RUNTIME_COVERAGE_MAP_2026_05_03.md section 4, and docs/fusion/fleet/PARALLEL_WORK_MANIFEST.md item P2. Do not edit production code or current canon docs. Do not touch Phase4Bridge.swift, any Phase4 test file, current docs/fusion/deliberation or docs/fusion/oversight file, project.pbxproj, Cargo.toml, Package.swift, ProseEditor*, MetalGraphView.swift, HologramController.swift, or graph internals.

Task: create /Users/jojo/Downloads/Epistemos/EpistemosTests/AgentEventBridgeNoDoubleCountSourceGuardTests.swift. Use Swift Testing. Read source files by path and assert `StreamingDelegate.swift`, `ChunkedMCPFraming.swift`, `CoTStreamInterceptor.swift`, and `ToolTierBridge.swift` do not directly call `recordToolEvent` or instantiate `AgentToolProvenanceRecorder`. Add short test comments explaining that AgentEvents belong at downstream tool/bridge execution sites, not transport/parser layers. Run a focused xcodebuild test and report the log path.
```

### P3 - Parallel Test Artifact Verification Bundle

**Lane (doctrine section 7):** Core open - parallel quality gate
**Effort:** M
**Who:** agent-2-ok
**Status:** open

**What.**
Verify the uncommitted parallel-agent test artifacts from the prior manifest without staging or committing them. Run focused tests for each new test file and write a single verification report that says which are green, which need repair, and which should be deferred.

**Files touched (precise paths, all new unless flagged):**
- /Users/jojo/Downloads/Epistemos/docs/fusion/fleet/parallel-test-artifact-verification/PARALLEL_TEST_ARTIFACT_VERIFICATION_2026_05_03.md (NEW)
- Existing uncommitted test files may be edited only if needed to fix compile/test failures: `HermesGatewayEvidenceContractTests.swift`, `ToolSurfaceBehavioralMatrixTests.swift`, `HermesPromptFormatGuardTests.swift`, `GraphEventProjectionFixtureTests.swift`, `CoreMASBoundarySourceGuardTests.swift`, `SovereignGateRequirementMatrixTests.swift`.

**Why safe.**
Codex is not reserving those existing parallel test files in the next three slices. The report is a new docs/fusion/fleet subfolder, and the item does not touch Phase4, production code, current canon, project files, graph, or editor files.

**Why useful now.**
Claude already created several useful guard suites. This converts them from "pile of promising untracked files" into a verified queue Codex can integrate safely later.

**Acceptance.**
- Report lists each artifact, focused command, log path, pass/fail, and integration recommendation.
- If a test file is repaired, the report names the exact change and why it remains test-only.
- No production files are modified.
- No staging or commit is performed.

**If picked by agent-2, paste this prompt:**
```text
You are a parallel verification agent in /Users/jojo/Downloads/Epistemos. Read AGENTS.md and docs/fusion/fleet/PARALLEL_WORK_MANIFEST.md item P3. Do not edit production code, current canon docs, Phase4Bridge.swift, any Phase4 test file, project.pbxproj, Cargo.toml, Package.swift, ProseEditor*, MetalGraphView.swift, HologramController.swift, or graph internals. Do not stage or commit.

Task: verify these uncommitted parallel test artifacts if present: EpistemosTests/HermesGatewayEvidenceContractTests.swift, EpistemosTests/ToolSurfaceBehavioralMatrixTests.swift, EpistemosTests/HermesPromptFormatGuardTests.swift, EpistemosTests/GraphEventProjectionFixtureTests.swift, EpistemosTests/CoreMASBoundarySourceGuardTests.swift, EpistemosTests/SovereignGateRequirementMatrixTests.swift. Run focused xcodebuild tests per file when possible. If a test fails to compile due to test-only API naming or helper placement, you may repair only that test file. Write /Users/jojo/Downloads/Epistemos/docs/fusion/fleet/parallel-test-artifact-verification/PARALLEL_TEST_ARTIFACT_VERIFICATION_2026_05_03.md with commands, log paths, pass/fail, files touched, and recommendation. Do not modify production.
```

### P4 - AgentEvent Coverage Map PR39 Delta

**Lane (doctrine section 7):** Core open - broader runtime AgentEvent coverage
**Effort:** S
**Who:** agent-2-ok
**Status:** open

**What.**
Create a new delta doc that updates the runtime coverage map after `ComputerUseBridge` PR39. Do not edit the original coverage map; write a new addendum that marks CUB-1 closed and re-ranks the remaining bridge gaps.

**Files touched (precise paths, all new unless flagged):**
- /Users/jojo/Downloads/Epistemos/docs/fusion/fleet/agent-event-runtime-coverage-map/AGENT_EVENT_RUNTIME_COVERAGE_MAP_PR39_DELTA_2026_05_03.md (NEW)

**Why safe.**
New doc only. It avoids Codex's Phase4 source/test files and in-flight canon docs.

**Why useful now.**
It gives Codex a clean next-slice selector after the Phase4 trio and prevents us from re-reading stale "ComputerUseBridge is open" guidance.

**Acceptance.**
- New delta doc exists.
- It marks ComputerUseBridge as closed by commit `92b40126`.
- It ranks remaining slices: Phase4 perceive/interact/watch, ClarifyPromptBridge, and explicit no-instrument surfaces.
- No existing docs or code are modified.

**If picked by agent-2, paste this prompt:**
```text
You are a parallel research agent in /Users/jojo/Downloads/Epistemos. Read AGENTS.md, docs/fusion/fleet/agent-event-runtime-coverage-map/AGENT_EVENT_RUNTIME_COVERAGE_MAP_2026_05_03.md, and git show --stat 92b40126. Do not edit code, current canon docs, current docs/fusion/deliberation files, current docs/fusion/oversight files, Phase4Bridge.swift, any Phase4 test file, project.pbxproj, Cargo.toml, or Package.swift.

Task: create /Users/jojo/Downloads/Epistemos/docs/fusion/fleet/agent-event-runtime-coverage-map/AGENT_EVENT_RUNTIME_COVERAGE_MAP_PR39_DELTA_2026_05_03.md. Mark ComputerUseBridge/CUB-1 closed by commit 92b40126, summarize what remains, and re-rank the next safe slices. Do not modify the original map.
```

### P5 - R15 MLX Preflight Decision Note

**Lane (doctrine section 7):** Core open - R15 remaining specialized baselines
**Effort:** S
**Who:** either
**Status:** open

**What.**
Read the existing R15 live MLX memory preflight artifact and write a short go/no-go decision note. Do not run the live MLX benchmark.

**Files touched (precise paths, all new unless flagged):**
- /Users/jojo/Downloads/Epistemos/docs/fusion/fleet/r15-live-mlx-memory-preflight/R15_LIVE_MLX_GO_NO_GO_2026_05_03.md (NEW)

**Why safe.**
New doc only. No code, no benchmark, no current canon edits, no app runtime.

**Why useful now.**
The R15 lane is blocked on sufficient-memory/thermal evidence. This turns the collected machine facts into a clear next decision without interrupting Codex's Phase4 AgentEvent work.

**Acceptance.**
- Decision note exists.
- It cites the existing preflight artifact path.
- It concludes `go`, `no-go`, or `unknown`, with one paragraph of reasoning.
- It explicitly says no live MLX benchmark was run.

**If picked by agent-2, paste this prompt:**
```text
You are a parallel research agent in /Users/jojo/Downloads/Epistemos. Read AGENTS.md and /Users/jojo/Downloads/Epistemos/docs/fusion/fleet/r15-live-mlx-memory-preflight/R15_LIVE_MLX_MEMORY_PREFLIGHT_2026_05_03.md. Do not edit code, current canon docs, current deliberation/oversight docs, project files, package files, or build scripts. Do not run any live MLX benchmark.

Task: create /Users/jojo/Downloads/Epistemos/docs/fusion/fleet/r15-live-mlx-memory-preflight/R15_LIVE_MLX_GO_NO_GO_2026_05_03.md. Summarize the memory/power/storage evidence and conclude go/no-go/unknown for attempting the R15 live MLX tok/s harness later. State clearly that no benchmark was run.
```

### P6 - Sovereign Gate Backlog Workcard Drafts

**Lane (doctrine section 7):** Core killer-feature seed work - Sovereign Gate follow-through
**Effort:** M
**Who:** agent-2-ok
**Status:** open

**What.**
Convert the existing Sovereign Gate surface map into 3-5 future workcard drafts in a new doc. Do not edit the canonical workcards file. Each draft should name the surface, risk, allowed files, forbidden files, tests, and stop triggers.

**Files touched (precise paths, all new unless flagged):**
- /Users/jojo/Downloads/Epistemos/docs/fusion/fleet/sovereign-gate-surface-map/SOVEREIGN_GATE_FUTURE_WORKCARDS_DRAFT_2026_05_03.md (NEW)

**Why safe.**
New doc only. It does not touch SovereignGate code/tests, current canon, Phase4, graph, editor, project, package, or build-script files.

**Why useful now.**
It turns the Sovereign killer-feature seed lane from a broad map into executable future slices while Codex continues the provenance queue.

**Acceptance.**
- New draft doc exists.
- It contains 3-5 narrow future cards, each with allowed/forbidden files and acceptance tests.
- It explicitly says the drafts are not canon until Codex/user approves them.
- No code or existing docs are modified.

**If picked by agent-2, paste this prompt:**
```text
You are a parallel research agent in /Users/jojo/Downloads/Epistemos. Read AGENTS.md, docs/fusion/fleet/sovereign-gate-surface-map/SOVEREIGN_GATE_SURFACE_MAP_2026_05_03.md, and docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md template only. Do not edit existing canon docs, code, tests, Phase4 files, project.pbxproj, Cargo.toml, Package.swift, ProseEditor*, MetalGraphView.swift, HologramController.swift, or graph internals.

Task: create /Users/jojo/Downloads/Epistemos/docs/fusion/fleet/sovereign-gate-surface-map/SOVEREIGN_GATE_FUTURE_WORKCARDS_DRAFT_2026_05_03.md. Draft 3-5 future Sovereign Gate workcards from the map. Each draft must include goal, authority to read first, allowed write set, forbidden write set, tests/logs, acceptance, and stop triggers. Mark the file as draft/non-canonical until approved.
```

## History (claimed / done / superseded / stale)

| Item | Status | Resolved at | Notes |
|---|---|---|---|
| Round 75 P1 Hermes Gateway Evidence Contract Tests | done-uncommitted | 2026-05-03T16:20Z | Claude created `/Users/jojo/Downloads/Epistemos/EpistemosTests/HermesGatewayEvidenceContractTests.swift`; not staged by Codex. |
| Round 75 P2 Tool Surface Behavioral Matrix Tests | done-uncommitted | 2026-05-03T16:20Z | Claude created `/Users/jojo/Downloads/Epistemos/EpistemosTests/ToolSurfaceBehavioralMatrixTests.swift`; not staged by Codex. |
| Round 75 P3 Durable GraphEvent Projection Fixture Tests | done-uncommitted | 2026-05-03T16:20Z | Claude created `/Users/jojo/Downloads/Epistemos/EpistemosTests/GraphEventProjectionFixtureTests.swift`; Codex repaired compile order during PR38 but did not stage it. |
| Round 75 P4 AgentEvent Runtime Coverage Map | done-uncommitted | 2026-05-03T16:20Z | Claude created `/Users/jojo/Downloads/Epistemos/docs/fusion/fleet/agent-event-runtime-coverage-map/AGENT_EVENT_RUNTIME_COVERAGE_MAP_2026_05_03.md`; Codex consumed it for PR39. |
| Round 75 P5 R15 Live MLX Memory Preflight Artifact | done-uncommitted | 2026-05-03T16:20Z | Claude created `/Users/jojo/Downloads/Epistemos/docs/fusion/fleet/r15-live-mlx-memory-preflight/R15_LIVE_MLX_MEMORY_PREFLIGHT_2026_05_03.md`; not staged by Codex. |
| Round 75 P6 Hermes Prompt Format Guard Tests | done-uncommitted | 2026-05-03T16:20Z | Claude created `/Users/jojo/Downloads/Epistemos/EpistemosTests/HermesPromptFormatGuardTests.swift`; not staged by Codex. |
| Round 75 P7 Sovereign Gate Surface Backlog Map | done-uncommitted | 2026-05-03T16:20Z | Claude created `/Users/jojo/Downloads/Epistemos/docs/fusion/fleet/sovereign-gate-surface-map/SOVEREIGN_GATE_SURFACE_MAP_2026_05_03.md`; not staged by Codex. |
| ComputerUseBridge AgentEvent provenance | done-committed | 2026-05-03T16:33Z | Codex closed and committed PR39 as `92b40126 Record ComputerUseBridge AgentEvents`. |
