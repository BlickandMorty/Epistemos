# Phase 6.5 Claude Startup Handoff

> **Index status**: SUPERSEDED-HISTORICAL — Phase-specific historical reference; superseded by MASTER_FUSION.md.
> Classified in [`docs/_INDEX.md §14`](_INDEX.md).



Status: ready for Claude Code startup

Date: 2026-04-15

Audience: Claude Code / continuation agents

Purpose: give Claude a canonical, plan-anchored startup prompt for the next codeable milestone after Phase 6, without drifting into an invented Phase 7 or editing the plan.

## 0. Top-Level Instruction For Claude

You are continuing Epistemos after the Phase 6 Communication + Media pass.

Do not assume "Phase 7" is next. In the current source-of-truth plan, the next named codeable milestone is:

`PLAN_V2.md` -> `Phase 6.5 — Capture-to-memory launch wedge`

If the operator says "Phase 7", interpret that as shorthand for "the next post-Phase-6 work" unless `docs/architecture/PLAN_V2.md` has been explicitly updated by the human. Do not invent a Phase 7 scope.

The source of truth is:

`/Users/jojo/Downloads/Epistemos/docs/architecture/PLAN_V2.md`

Do not edit `PLAN_V2.md`. If you believe the plan needs to change, stop and ask the operator. You may write a separate handoff, drift ledger, or implementation report, but not a plan edit.

## 1. Canonical Status Snapshot

Current canonical interpretation:

- Phase 6 code surfaces are substantially implemented.
- Phase 6 formal closure is deferred because manual runtime verification is intentionally not being done yet.
- The operator wants to keep coding forward while manual Phase 6 runtime checks remain deferred.
- Image generation is not a Phase 6 closure gate.
- Local MLX image generation is deferred and should not be reopened unless the operator explicitly asks.
- `image_generate` should remain hidden from normal user-visible catalogs until a real local runtime exists.
- The next plan-anchored coding milestone is Phase 6.5: capture -> structure -> memory -> evidence -> trace.

Critical product direction:

- Epistemos is a local-first cognitive operating system for notes, code, graph memory, tools, and agentic execution.
- The launch wedge is not image generation.
- The launch wedge is voice/quick capture -> structured note -> graph/task update -> evidence -> trace/replay.
- MCP remains the integration spine, but the Phase 6.5 slice should not drift into broad marketplace/plugin work.
- BoltFFI is now planned as a later hot-path migration audit, not as the first Phase 6.5 implementation task unless the current slice crosses a high-volume Swift/Rust boundary that needs measurement.

## 2. Non-Negotiable Rules

Plan and authority rules:

- `PLAN_V2.md` is the source of truth.
- Do not edit `PLAN_V2.md`.
- Architecture docs override historical research.
- Current code overrides stale implementation-status claims.
- Historical handoffs are evidence, not authority.
- If code and plan conflict, build a drift ledger before changing code.
- If resolving a drift requires changing the plan, stop and ask the operator.

Control-plane rules:

- Rust remains the sole control-plane authority.
- Swift may parse UI input, resolve UI-local state, and render surfaces.
- Swift must not become a second routing, permission, runtime, or escalation control plane.
- No silent backend rerouting.
- No silent cloud escalation.
- No mid-generation backend switching.
- No fake success for unsupported capabilities.
- No hidden permission expansion.
- Destructive or permission-sensitive actions must be explicit, gated, and auditable.

Phase 6.5 rules:

- Keep the work focused on capture-to-memory.
- Do not reopen local MLX image generation.
- Do not start marketplace/plugin expansion.
- Do not redesign the entire Agent Command Center.
- Do not implement persistent memory v2 unless the Phase 6.5 slice directly needs source-linked artifacts.
- Do not add Python-first orchestration to the hot path.
- No action execution from extracted tasks unless explicitly permission-gated and optional.
- Evidence/provenance must be source-linked, not vague metadata.
- Trace/replay records must be written for workflow steps, not merely logged to console.

## 3. Required Reading Order

Read these before making architectural claims or code changes.

### Tier 0 — Repo Rules

1. `/Users/jojo/Downloads/Epistemos/AGENTS.md`
2. `/Users/jojo/Downloads/Epistemos/CLAUDE.md`

### Tier 1 — Source-Of-Truth Architecture

1. `/Users/jojo/Downloads/Epistemos/docs/architecture/README.md`
2. `/Users/jojo/Downloads/Epistemos/docs/architecture/PLAN_V2.md`
3. `/Users/jojo/Downloads/Epistemos/docs/architecture/CODEX_CONTEXT_PACK.md`
4. `/Users/jojo/Downloads/Epistemos/docs/architecture/RESEARCH_INDEX.md`
5. `/Users/jojo/Downloads/Epistemos/docs/BACKEND_INTERFACE_SPEC_v1.md`
6. `/Users/jojo/Downloads/Epistemos/docs/architecture/COMPUTE_STEERING_SPEC_v1.md`
7. `/Users/jojo/Downloads/Epistemos/docs/architecture/ADAPTATION_SUBSYSTEM_SPEC_v1.md`
8. `/Users/jojo/Downloads/Epistemos/docs/architecture/OVERSEER_AND_AGENT_HIERARCHY.md`

### Tier 2 — Phase State and Canonicalization Context

1. `/Users/jojo/Downloads/Epistemos/docs/architecture/PHASE_5_HANDOFF.md`
2. `/Users/jojo/Downloads/Epistemos/docs/architecture/PHASE_6_PROTOCOL.md`
3. `/Users/jojo/Downloads/Epistemos/docs/architecture/PHASE_6_CLARK_HANDOFF_2026_04_14.md`
4. `/Users/jojo/Downloads/Epistemos/docs/architecture/CLAUDE_CANONICALIZATION_REDO_HANDOFF_2026_04_14.md`
5. `/Users/jojo/Downloads/Epistemos/docs/architecture/PLAN_V2_CANONICALIZATION_MASTER_PROMPT_2026_04_14.md`
6. `/Users/jojo/Downloads/Epistemos/docs/architecture/PLAN_V2_CANONICALIZATION_OPERATOR_PROMPT_2026_04_14.md`

### Tier 3 — Implementation Context

1. `/Users/jojo/Downloads/Epistemos/docs/SKILL_IMPLEMENTATION_PLAN.md`
2. `/Users/jojo/Downloads/Epistemos/docs/CODEX_HANDOFF_2026_04_10.md`
3. `/Users/jojo/Downloads/Epistemos/docs/TOOL_TIER_AND_IMESSAGE_INTEGRATION.md`
4. `/Users/jojo/Downloads/Epistemos/AGENT_COMMAND_CENTER_UX_HANDOFF.md`

### Tier 4 — Advisory Research

These are advisory only. They may not override `PLAN_V2.md`.

Repo-local research:

1. `/Users/jojo/Downloads/Epistemos/docs/UNIFIED_SUBSTRATE_RESEARCH.md`
2. `/Users/jojo/Downloads/Epistemos/docs/HERMES_INTEGRATION_RESEARCH.md`
3. `/Users/jojo/Downloads/Epistemos/docs/CONTROL_PLANE_RESEARCH.md`
4. `/Users/jojo/Downloads/Epistemos/docs/GOOSE_AGENT_RESEARCH.md`
5. `/Users/jojo/Downloads/Epistemos/docs/GOOSE_AGENT_RESEARCH_2.md`
6. `/Users/jojo/Downloads/Epistemos/docs/RESEARCH_TO_APP_TRACEABILITY.md`
7. `/Users/jojo/Downloads/Epistemos/docs/AGENT_INTEGRATION_SESSION_PLAN.md`
8. `/Users/jojo/Downloads/Epistemos/docs/RESEARCH_PROMPT_CLOUD_NATIVE_AGENT_BRIDGE.md`
9. `/Users/jojo/Downloads/Epistemos/docs/MASTER_HARDENING_AND_HARNESS_PLAN.md`

Recent operator research packet, advisory only:

1. `/Users/jojo/Library/Mobile Documents/com~apple~CloudDocs/Perplex op2.md`
2. `/Users/jojo/Library/Mobile Documents/com~apple~CloudDocs/GPT op1.md`
3. `/Users/jojo/Library/Mobile Documents/com~apple~CloudDocs/Perplex op1.md`
4. `/Users/jojo/Library/Mobile Documents/com~apple~CloudDocs/GPT mcp.md`
5. `/Users/jojo/Library/Mobile Documents/com~apple~CloudDocs/Perplex mcp.md`
6. `/Users/jojo/Library/Mobile Documents/com~apple~CloudDocs/Perplex market.md`
7. `/Users/jojo/Library/Mobile Documents/com~apple~CloudDocs/Gemini%20mcp%20.pdf.pdf`
8. `/Users/jojo/Library/Mobile Documents/com~apple~CloudDocs/Gemini%20mcp%202.pdf.pdf`
9. `/Users/jojo/Library/Mobile Documents/com~apple~CloudDocs/Gemini%20mcp%203.pdf.pdf`
10. `/Users/jojo/Library/Mobile Documents/com~apple~CloudDocs/Gemini%20market.pdf.pdf`

Important: `/Users/jojo/Library/Mobile Documents/com~apple~CloudDocs/PLAN V2.md` is outdated and must not be used as authority. The real plan is the repo file `docs/architecture/PLAN_V2.md`.

## 4. What Claude Must Say Before Editing

Before editing code, Claude must report:

- the docs actually read
- the current source-of-truth phase according to `PLAN_V2.md`
- an explicit statement that Phase 6.5, not an invented Phase 7, is the next canonical codeable milestone
- a concise summary of Phase 6.5 scope
- what is already implemented in the repo for capture-to-memory
- a drift matrix showing any mismatch between `PLAN_V2.md` and code
- a proposed first vertical slice
- a verification plan
- confirmation that `PLAN_V2.md` will not be edited

If Claude cannot provide those items, it has not loaded enough context yet.

## 5. Phase 6.5 Scope From PLAN_V2

Phase 6.5 is:

- voice or quick capture
- transcription
- structured note generation
- entity / task extraction
- graph write path
- source spans and evidence links
- trace / replay records
- optional follow-up actions through explicit tool gates

User-facing product goal:

The user should be able to capture a thought quickly, have Epistemos structure it into a useful note, extract tasks/entities, write graph connections, preserve source evidence, and record a replayable trace.

The Phase 6.5 goal is not:

- image generation
- marketplace
- generic agent framework building
- persistent memory v2
- full ambient wearable ecosystem
- Python-first orchestration
- Phase 7 intelligence experiments

## 6. Current Code Reality To Audit First

Do not start from scratch. Audit these current surfaces first:

Capture / structure:

- `/Users/jojo/Downloads/Epistemos/Epistemos/Engine/TextCapturePipeline.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/KnowledgeFusion/DataIngestion/AudioTranscriber.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/State/AmbientCaptureService.swift`

Trace / replay:

- `/Users/jojo/Downloads/Epistemos/Epistemos/Harness/TraceCollector.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Harness/HarnessIntegration.swift`

Persistence / vault / notes:

- `/Users/jojo/Downloads/Epistemos/Epistemos/Sync/NoteFileStorage.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Sync/VaultSyncService.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Models/SDPage.swift`

Graph:

- `/Users/jojo/Downloads/Epistemos/Epistemos/Graph/GraphBuilder.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Graph/GraphStore.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Models/SDGraphNode.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Models/SDGraphEdge.swift`

Agent/command surface integration:

- `/Users/jojo/Downloads/Epistemos/Epistemos/State/AgentCommandCenterState.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Views/AgentCommandCenter/AgentCommandCenterView.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Views/AgentCommandCenter/CommandBarView.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Views/AgentCommandCenter/BrainPickerMenu.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/App/ChatCoordinator.swift`

Bootstrap/environment:

- `/Users/jojo/Downloads/Epistemos/Epistemos/App/AppBootstrap.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/App/AppEnvironment.swift`

Tests to read before editing:

- `/Users/jojo/Downloads/Epistemos/EpistemosTests/TextCapturePipelineTests.swift`
- `/Users/jojo/Downloads/Epistemos/EpistemosTests/DataIngestionTests.swift`
- `/Users/jojo/Downloads/Epistemos/EpistemosTests/HarnessSubsystemTests.swift`
- `/Users/jojo/Downloads/Epistemos/EpistemosTests/PipelineServiceTests.swift`
- `/Users/jojo/Downloads/Epistemos/EpistemosTests/AgentCommandCenterStateTests.swift`
- `/Users/jojo/Downloads/Epistemos/EpistemosTests/RuntimeValidationTests.swift`

Known local scan result as of this handoff:

- `TextCapturePipeline.swift` exists and already has `SourceSpan`, `ExtractedTask`, `ExtractedEntity`, `GraphWriteSummary`, trace-event wiring, and an audio transcription entry point.
- `TraceCollector.swift` already defines capture trace event types including `capture_received`, `structure_generated`, `note_persisted`, `graph_write_attempted`, and `evidence_linked`.
- `AudioTranscriber.swift` exists.
- `AppBootstrap.swift` has a `textCapturePipeline` service slot.
- This means Phase 6.5 is also an audit/verify/extend pass, not a greenfield rewrite.

## 7. Required First Matrix

Before editing, build a Phase 6.5 gap matrix with one row per deliverable:

- quick text capture
- audio capture / transcription
- transcript -> structured note
- title / summary generation
- task extraction
- entity extraction
- note persistence
- graph write path
- graph deduplication
- source spans
- evidence links
- trace/replay events
- optional follow-up action bridge
- Swift UI entry point
- Agent Command Center integration, if relevant

For each row record:

- plan expectation
- current files
- existing tests
- whether live verified
- open risks
- gap type: implementation, verification, safety, UI, docs-only, or product decision
- whether it can be fixed without changing `PLAN_V2.md`

Do not implement until this matrix exists.

## 8. Recommended First Vertical Slice

If the matrix confirms the existing text-first pipeline is real, the safest first code slice is:

1. Audit current `TextCapturePipeline` behavior and tests.
2. Verify it can accept raw text and create:
   - structured title
   - summary
   - extracted tasks
   - extracted entities
   - source spans
   - persisted note/page
   - graph write summary
   - trace events
3. Wire or harden one UI entry point for quick capture if it is missing.
4. Wire audio transcription into the same pipeline only if the existing `AudioTranscriber` path is already safe and testable.
5. Add tests for any missing edge cases before fixing:
   - empty input
   - whitespace-only input
   - unicode input
   - long input
   - duplicate entity/task names
   - graph dedup behavior
   - missing vault path / persistence failure
   - trace write failure
6. Leave follow-up actions extracted but not executed unless explicit tool permission exists.

If a quick-capture UI already exists, do not duplicate it. Improve the existing one.

If the pipeline is already complete, move to verification and UI integration, not a rewrite.

## 9. BoltFFI Placement For This Phase

`PLAN_V2.md` now includes `## 22. BoltFFI Hot-Path Migration Audit`.

Do not start a full BoltFFI migration inside Phase 6.5 unless the selected slice directly exposes a measured hot-path bottleneck.

Allowed in this phase:

- Add TODO-free measurement hooks or microbenchmarks for capture/transcript/evidence payloads if they cross Swift/Rust frequently.
- Record likely BoltFFI candidates in a separate audit note.
- Keep bridge payloads truthful and typed where practical.

Not allowed without explicit operator approval:

- broad UniFFI replacement
- graph-engine bridge rewrite
- agent stream transport rewrite
- plan edits to move BoltFFI earlier

The intended BoltFFI priority order later is:

1. graph data plane
2. agent/tool event streaming
3. capture/transcript/evidence payloads
4. retrieval/embedding batches
5. MCP large local result handoff

## 10. Verification Protocol

Minimum focused verification for Phase 6.5 work:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test \
  -only-testing:EpistemosTests/TextCapturePipelineTests
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test \
  -only-testing:EpistemosTests/PipelineServiceTests
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test \
  -only-testing:EpistemosTests/AgentCommandCenterStateTests
```

If audio or trace code is touched:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test \
  -only-testing:EpistemosTests/DataIngestionTests/AudioTranscriberTests
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test \
  -only-testing:EpistemosTests/HarnessSubsystemTests/TraceCollectorTests
```

If Rust bridges, tool catalogs, or agent-core surfaces are touched:

```bash
cargo test --manifest-path agent_core/Cargo.toml
cargo test --manifest-path epistemos-core/Cargo.toml
cd graph-engine && cargo test
```

Before claiming full readiness, run broader validation:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test
```

Known caveat from prior work:

- Xcode may print vendored CodeEdit SwiftLint "Output folder doesn't exist" build-command noise while focused tests still report `** TEST SUCCEEDED **`. Do not hide it; report it exactly.

## 11. Manual Verification Expectations

The operator deferred Phase 6 manual runtime verification. Do not call Phase 6 formally closed unless the manual matrix is later completed.

For Phase 6.5, if you add or wire a UI path, manual verification should include:

- open the quick-capture surface
- submit a short text capture
- confirm a note/page is created or updated
- confirm extracted tasks/entities are visible or inspectable
- confirm graph write summary exists
- confirm trace events are recorded
- confirm source spans/evidence links point back to captured text
- confirm empty input fails clearly
- confirm no follow-up actions execute without explicit permission

If audio capture is wired:

- verify missing microphone/STT backend fails clearly
- verify an audio file or safe test recording can transcribe
- verify transcription enters the same pipeline as text capture

## 12. Drift Checks Claude Must Perform

Before each implementation batch, run this mental checklist and report results:

- Does this change implement a `PLAN_V2.md` Phase 6.5 deliverable?
- Does it avoid changing `PLAN_V2.md`?
- Does it preserve Rust control-plane sovereignty?
- Does it avoid silent cloud fallback?
- Does it avoid hidden action execution?
- Does every generated structure have provenance/source spans where expected?
- Does every memory/graph write remain inspectable?
- Does every trace/replay event use existing `TraceCollector` patterns?
- Does it avoid broad marketplace, persistent memory v2, image generation, or Phase 7 drift?
- Does it add tests before or with the fix?
- Does it avoid touching unrelated dirty worktree changes?

If any answer is "no", stop and either narrow scope or ask the operator.

## 13. Required Final Deliverables From Claude

Claude must finish with:

- docs read
- current canonical phase
- Phase 6.5 gap matrix
- files changed
- commands run
- exact pass/fail results
- any known pre-existing failures separated from new failures
- manual verification performed or blocked
- direct verdict:
  - `Phase 6.5 slice complete`
  - or `Phase 6.5 slice not complete`
- whether Phase 6 formal closure is still deferred
- whether any plan drift remains
- whether any follow-up requires operator decision

Do not say "Phase 7 complete" unless `PLAN_V2.md` has a real Phase 7 section and the operator explicitly authorizes that scope.

## 14. Copy-Paste Startup Prompt For Claude

Use this exact prompt to start Claude:

```text
Read `/Users/jojo/Downloads/Epistemos/AGENTS.md` and `/Users/jojo/Downloads/Epistemos/CLAUDE.md` first.

Then read the canonical architecture startup bundle in this order:

1. `/Users/jojo/Downloads/Epistemos/docs/architecture/README.md`
2. `/Users/jojo/Downloads/Epistemos/docs/architecture/PLAN_V2.md`
3. `/Users/jojo/Downloads/Epistemos/docs/architecture/CODEX_CONTEXT_PACK.md`
4. `/Users/jojo/Downloads/Epistemos/docs/architecture/RESEARCH_INDEX.md`
5. `/Users/jojo/Downloads/Epistemos/docs/BACKEND_INTERFACE_SPEC_v1.md`
6. `/Users/jojo/Downloads/Epistemos/docs/architecture/COMPUTE_STEERING_SPEC_v1.md`
7. `/Users/jojo/Downloads/Epistemos/docs/architecture/ADAPTATION_SUBSYSTEM_SPEC_v1.md`
8. `/Users/jojo/Downloads/Epistemos/docs/architecture/OVERSEER_AND_AGENT_HIERARCHY.md`
9. `/Users/jojo/Downloads/Epistemos/docs/architecture/PHASE_5_HANDOFF.md`
10. `/Users/jojo/Downloads/Epistemos/docs/architecture/PHASE_6_PROTOCOL.md`
11. `/Users/jojo/Downloads/Epistemos/docs/architecture/PHASE_6_CLARK_HANDOFF_2026_04_14.md`
12. `/Users/jojo/Downloads/Epistemos/docs/architecture/CLAUDE_CANONICALIZATION_REDO_HANDOFF_2026_04_14.md`
13. `/Users/jojo/Downloads/Epistemos/docs/SKILL_IMPLEMENTATION_PLAN.md`
14. `/Users/jojo/Downloads/Epistemos/docs/CODEX_HANDOFF_2026_04_10.md`
15. `/Users/jojo/Downloads/Epistemos/docs/TOOL_TIER_AND_IMESSAGE_INTEGRATION.md`
16. `/Users/jojo/Downloads/Epistemos/docs/architecture/PHASE_6_5_CLAUDE_STARTUP_HANDOFF_2026_04_15.md`

Important: `PLAN_V2.md` is the source of truth. Do not edit it. If you think the plan needs a change, stop and ask me.

Do not assume Phase 7 is next. The current plan's next codeable milestone is `Phase 6.5 — Capture-to-memory launch wedge`. Treat "Phase 7" only as informal shorthand unless the plan has been changed by the human.

Before editing code, audit the existing Phase 6.5 surfaces:

- `Epistemos/Engine/TextCapturePipeline.swift`
- `Epistemos/KnowledgeFusion/DataIngestion/AudioTranscriber.swift`
- `Epistemos/Harness/TraceCollector.swift`
- `Epistemos/App/AppBootstrap.swift`
- `Epistemos/App/AppEnvironment.swift`
- `Epistemos/Graph/GraphBuilder.swift`
- `Epistemos/Graph/GraphStore.swift`
- `Epistemos/Sync/NoteFileStorage.swift`
- `Epistemos/Sync/VaultSyncService.swift`
- `Epistemos/State/AgentCommandCenterState.swift`
- `Epistemos/Views/AgentCommandCenter/AgentCommandCenterView.swift`
- `Epistemos/Views/AgentCommandCenter/CommandBarView.swift`
- `Epistemos/Views/AgentCommandCenter/BrainPickerMenu.swift`
- `Epistemos/App/ChatCoordinator.swift`

Build a Phase 6.5 gap matrix first. Do not implement before the matrix exists.

Phase 6.5 scope is capture -> transcription -> structured note -> entity/task extraction -> graph write -> source spans/evidence -> trace/replay -> optional follow-up actions behind explicit tool gates.

Do not reopen local MLX image generation. Do not start marketplace work. Do not redesign the Agent Command Center. Do not introduce a second Swift control plane. Do not silently execute extracted tasks. Do not silently reroute to cloud. Do not call Phase 6 formally closed unless manual Phase 6 runtime verification is completed later.

After the matrix, fix only the real gaps, one vertical slice at a time, with tests. Prefer extending the existing `TextCapturePipeline`, `AudioTranscriber`, `TraceCollector`, graph, vault, and quick-capture surfaces over rewriting them.

Run focused verification:

`xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build`

`xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/TextCapturePipelineTests`

`xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/PipelineServiceTests`

`xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/AgentCommandCenterStateTests`

If audio or trace code is touched, also run the relevant `AudioTranscriberTests` and `TraceCollectorTests`.

If Rust, tool, graph-engine, or FFI code is touched, run the relevant cargo tests.

Final response must include: docs read, gap matrix, files changed, commands run, exact pass/fail results, manual verification status, remaining blockers, and direct verdict: `Phase 6.5 slice complete` or `Phase 6.5 slice not complete`.
```
