# Phase7 NightBrain Trigger Provenance PR36 Deliberation - 2026-05-03

## Classification
- Tier: Core.
- Slice: `phase7-nightbrain-trigger-provenance-pr36`.
- Workcard: `AGENT_BUILD_WORKCARDS_2026_05_01.md` Card 7 - AgentEvent Tool Provenance.
- Sovereign Gate touchpoint: none.
- Killer-feature dependency: none.

## Intent
Add bounded AgentEvent provenance to the existing `Phase7Bridge.triggerNightbrainJob(jobType:priority:)` runtime surface without changing NightBrain scheduler policy, job semantics, UI, Rust bindings, EventStore schema, graph, Sovereign, Hermes, MCP, subprocess, or ANE/private API surfaces.

## Allowed Files
- `Epistemos/Bridge/Phase7Bridge.swift`
- `EpistemosTests/Phase7BridgeAgentEventTests.swift`
- Slice docs under `docs/fusion/fleet/phase7-nightbrain-trigger-provenance-pr36/`
- This deliberation brief and oversight/registry updates.

## Forbidden Files
- `Epistemos/Views/Notes/ProseEditor*.swift`
- `Epistemos/Views/Graph/MetalGraphView.swift`
- `Epistemos/Views/Graph/HologramController.swift`
- Graph physics/render internals.
- Rust generated bindings and build artifacts.
- EventStore schema, Rust, UI, Hermes/MCP/provider routing, Sovereign, ANE/private API.

## Implementation Order
1. Add an injectable `BootstrapProvider` and `AgentToolProvenanceRecorder` to `Phase7Bridge`.
2. Emit `.toolCallRequested` for every `nightbrain_trigger` call with fixed run id and per-call tool id.
3. Reject unsupported jobs before `AppBootstrap.shared` lookup and emit `.toolCallFailed` with `failure_class=unsupported_job_type`.
4. For supported jobs with no bootstrap or disabled agents, emit bounded failed events.
5. For live supported jobs, emit started then completed/failed after `runPipelineForTesting`.
6. Persist only canonical supported `NightBrainService.Job.rawValue`, bounded `priority_class`, `requested_job_supported`, and bounded result/failure classes.
7. Add focused tests that prove unsupported/bootstrap-unavailable paths emit sanitized AgentEvents and do not run real NightBrain jobs.

## Acceptance
- `Phase7BridgeAgentEventTests` passes.
- Existing supported aliases remain intact.
- Unsupported job tests prove bootstrap is not consulted.
- Encoded AgentEvents do not contain raw unknown job names, raw priority strings, filesystem paths, private note names, localized descriptions, or AppBootstrap error text.
- Guard greps show no Hermes/MCP/subprocess/browser/computer-use/LocalAuthentication/ANE/private API/formal-solver/hot-path memory symbols in touched source.

## Canon anchors
- `MASTER_RESEARCH_INDEX_2026_05_02.md` §4
- `MASTER_RESEARCH_INDEX_2026_05_02.md` §22.1
- `UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md` Safe Next Build Order item 3
- `AGENT_BUILD_WORKCARDS_2026_05_01.md` Card 7

## Workcard match
- `AGENT_BUILD_WORKCARDS_2026_05_01.md` card: Card 7 - AgentEvent Tool Provenance.
- Deviation: none.

## Failure-proof guardrails (post-merge)
- grep: `rg -n "recordNightBrainTriggerEvent|phase7-nightbrain-trigger|failure_class" Epistemos/Bridge/Phase7Bridge.swift EpistemosTests/Phase7BridgeAgentEventTests.swift`
- log: `Test run with 4 tests in 1 suite passed`
- test: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/Phase7BridgeAgentEventTests test`

## Fleet evidence packet
- `docs/fusion/fleet/phase7-nightbrain-trigger-provenance-pr36/aggregator.md`
- `docs/fusion/fleet/phase7-nightbrain-trigger-provenance-pr36/claude-red-team/attacks.md`

## Usefulness
usefulness: +1
usefulness_reason: Closes a real live bridge provenance gap while preserving safe test isolation.
