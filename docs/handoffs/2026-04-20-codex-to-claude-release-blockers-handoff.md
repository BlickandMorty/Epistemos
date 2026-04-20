# Codex → Claude handoff · April 20 2026 · release blockers + research fusion

This handoff is the current source of truth for the next agent. It
merges:

- the live repo state on `codex/runtime-input-audit`
- the uncommitted blocker batch currently in progress
- the user's newly supplied external research
- the release-audit rule from `.agents/skills/epistemos_release_audit/SKILL.md`
- the user's explicit preference to keep the Xcode project generated, not manually edited

Do not treat older handoffs as authoritative if they conflict with this
document.

---

## 0 · Read this first

1. `/Users/jojo/Downloads/Epistemos/AGENTS.md`
2. `/Users/jojo/Downloads/Epistemos/.agents/skills/epistemos_release_audit/SKILL.md`
3. `/Users/jojo/Downloads/Epistemos/docs/architecture/MASTER_PLAN_2026-04-19.md`
4. `/Users/jojo/Downloads/Epistemos/docs/AGENT_PROGRESS.md`
5. This file

Branch:
- `codex/runtime-input-audit`

Project file rule:
- The user explicitly wants the app project to stay aligned with the actual source tree via generation, not hand-edited drift.
- If project structure needs to change, prefer `xcodegen` / generated project flow.
- Do not hand-maintain `Epistemos.xcodeproj/project.pbxproj` unless there is no alternative.

Current directive from user:
- Finish the remaining release blockers.
- Keep auditing in small batches.
- Verify after every phase.
- Use outside research before editing.
- Write/maintain a handoff for the next agent.

---

## 1 · Biggest verified findings from the new research

These are the highest-value additions from the user's latest research
bundle. They matter because they align with the symptoms the user is
still seeing in the live app.

### A. `UserFacingModelOutput.finalVisibleText()` is a real silent-answer bug

Verified against current tree:
- `Epistemos/Engine/Extensions.swift:792-806`
- `reasoningParagraphPrefixes` at `Extensions.swift:717-765`

Problem:
- `finalVisibleText(from:)` can return `""` when its heuristics decide
  the cleaned text "looks like reasoning" but fail to extract a clean
  answer.
- The prefix list includes answer-like starters such as:
  - `"answer:"`
  - `"final answer:"`
  - `"response:"`
  - `"let me start by"`
  - `"i'll begin by"`
- This is a direct root cause for the user's "it thinks and then says
  nothing" complaint across providers.

Important nuance:
- `ThinkTagStreamRouter` is not the weak link. The downstream
  user-facing answer extractor is.

### B. MLX/local freeze is still fundamentally a runtime-architecture issue

Verified + reinforced by the research:
- `Epistemos/KnowledgeFusion/MLXInferenceBridge.swift:10` is still
  `@MainActor`
- local send path still pays too much synchronous work before the user
  sees the turn settle

This matches the user's repeated "freeze while thinking" and
"sending is the slowest part" reports.

### C. Rust/FFI multi-turn gap is still real

Still true:
- `agent_core/src/agent_loop.rs:157`
- `agent_core/src/bridge.rs:508`

The loop still starts from:

```rust
let mut messages = vec![Message::user_text(&objective)];
```

Swift holds real history, but Rust does not receive a native
multi-turn message array. This remains an architecture-level issue, not
yet fixed.

### D. Xcode project generation matters

The user explicitly asked that the project reflect the actual file tree
through generation instead of direct edits. Carry this forward:

- prefer generated-project workflow
- if new files need project inclusion, use the generator path
- do not leave the repo in a state where the project file drifts from
  the real source list

---

## 2 · Current repo reality

The worktree is still very dirty. Do not broadly stage.

Snapshot at handoff time:
- `git status --short | wc -l` = `94`
- treat this as a multi-cluster dirty tree, not one giant batch

At the time of this handoff, the important in-flight release-blocker
batch is confined to these files:

- `/Users/jojo/Downloads/Epistemos/Epistemos/App/AppBootstrap.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/App/ChatCoordinator.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Engine/Extensions.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Engine/MLXInferenceService.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Engine/TriageService.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/State/AgentChatState.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/State/ChatState.swift`
- `/Users/jojo/Downloads/Epistemos/EpistemosTests/AgentChatStateTests.swift`
- `/Users/jojo/Downloads/Epistemos/EpistemosTests/PipelineServiceTests.swift`
- `/Users/jojo/Downloads/Epistemos/EpistemosTests/RuntimeValidationTests.swift`
- `/Users/jojo/Downloads/Epistemos/EpistemosTests/TriageServiceTests.swift`

Do not mix unrelated dirty files into this batch.

There are still many other modified/untracked files in graph, intents,
KnowledgeFusion, Omega, views, Rust, docs, etc. Those are not part of
this blocker batch.

Broad dirty clusters still outside this batch:
- graph: `EntityExtractor.swift`, `GraphBuilder.swift`,
  `SDFLabelAtlas.swift`
- intents / shortcuts: multiple files under `Epistemos/Intents/`
- KnowledgeFusion: `DocumentChunker.swift`,
  `InstantRecallService.swift`, `PythonEnvironmentManager.swift`,
  `SkillManifest.swift`, synthetic-data / training files
- Omega: permissions, vision, iMessage driver
- notes / landing / mini chat UI: multiple views under
  `Epistemos/Views/`
- state / models / sync / vault support files
- Rust: `agent_core/src/bridge.rs`, `channel_relay.rs`, `tirith.rs`,
  `tools/media.rs`, plus graph-engine files
- repo hygiene: untracked docs, scripts, `.swiftpm/`, and new source
  files

Do not let Claude accidentally stage these wider clusters while trying
to finish the blocker batch.

---

## 3 · What is already changed in the current uncommitted blocker batch

This section is important: these changes are present in the working tree
already, but were not committed at the time of this handoff because the
focused test signal was still noisy.

### 3.1 Stream-salvage / no-final-answer fixes

Files:
- `ChatState.swift`
- `AgentChatState.swift`
- `ChatCoordinator.swift`
- `MLXInferenceService.swift`
- `Extensions.swift`
- related tests

What was changed:

1. `ChatState.completeCancelledProcessing(...)`
- flushes `ThinkTagStreamRouter`
- flushes buffered tokens
- salvages final answer from `streamingThinking` via
  `UserFacingModelOutput.finalVisibleText(...)`
- falls back to
  `UserFacingModelOutput.incompleteReasoningFallback(...)`
- persists thinking trace / duration / cache hit / model label

2. `AgentChatState.completeInterruptedProcessing(...)`
- same salvage logic for agent flows

3. `MLXInferenceService`
- now yields any trailing postprocessed final suffix if the raw
  streaming deltas never emitted it
- this was specifically for local flows that "thought" and then ended
  without visible final text

4. `Extensions.swift`
- `ThinkingTagSyntax` now supports:
  - `<thinking>`
  - `<think>`
  - `<thought>`
  - `<reasoning>`
- `bestAnswerCandidate(in:)` no longer immediately discards structured
  plan-shaped output
- new `bestStructuredPlanLineCandidate(in:)` attempts to salvage the
  final real prose line after structured reasoning output

5. `ChatState.completeProcessing(...)`
- now clears active thinking state after success finalization

### 3.2 Rust/cloud completion-gap fixes

This was the newest code patch before this handoff.

The explorer audit found two real completion holes:

1. In the Command Center Rust/cloud path, `.complete` only updated
   diagnostics and never finalized the assistant transcript.
2. In the main Rust agent path, a stream could end without `.complete`
   or `.error`, and the loop would just fall off the end after
   reasoning/tool activity.

What was patched in `ChatCoordinator.swift`:

- `thinkingDelta` now counts as received content in both Rust/cloud
  paths
- Command Center Rust/cloud `.complete` now calls
  `agentChat.completeProcessing(...)`
- Command Center Rust/cloud silent stream endings now attempt
  `agentChat.completeInterruptedProcessing(...)`
- Main Rust agent path now tracks `finalizedAssistantMessage`
- Main Rust agent path `.complete` now finalizes once and persists the
  turn through a shared helper
- Main Rust agent path silent stream endings now attempt
  `chatState.completeCancelledProcessing(...)`
- If salvage still fails after received content, the user gets a
  concrete error instead of a silent drop

### 3.3 Send-path responsiveness fix

In `ChatCoordinator.handleQuery(...)`:

- `AppleIntelligenceService.shared.checkAvailability()` was previously
  called synchronously before the async task
- that availability probe was moved inside the async task so tapping
  Send does less synchronous work on the main path

### 3.4 Foreground/activation deferral work already present

In `AppBootstrap.swift`:

- activation-triggered local-runtime refresh work is already deferred
  through `localRuntimeActivationTask`
- a `150ms` async delay was introduced before refresh/sync on
  `didBecomeActive`

This is already in the working tree, but it is probably not the final
perf answer yet.

---

## 4 · What is still not finished

### A. The blocker batch is not committed yet

Reason:
- focused build/test verification was noisy and partially blocked by the
  Xcode environment
- I chose not to fake a green result

### B. Focused test state is still imperfect

What is verified:
- warmed `xcodebuild build` on
  `/tmp/epistemos-blocker-batch-3` completed successfully against the
  current code

What is not fully resolved:
- focused `xcodebuild test` runs have been noisy / unreliable in this
  environment
- `test-without-building` failed because the plugin bundle was not
  staged in the built app bundle
- there is a stubborn stale `Epistemos.app` process from an old
  DerivedData run that may be contributing to Xcode weirdness:
  - historical pid observed repeatedly: `86188`

Important:
- do not claim this batch is green until you get a real focused `test`
  pass or an equivalent trustworthy signal

### C. The user’s biggest live pain points are still not fully closed

Still needs live verification and/or more fixes:

1. Thinking still sometimes appears as if it "finished and stopped"
   without a final answer
2. Thinking UI is still not ChatGPT-style inline accordion during
   streaming
3. App still feels slow/hangy on send and on foreground
4. Local large-model freeze / coder freeze still needs a proper RAM
   pre-flight and clearer refusal path
5. App crash-on-tap/foreground still has no fresh `.ips` crash log
6. User reports the app can still crash just by tapping/focusing it
7. User reports local and cloud flows can still freeze while thinking,
   then show "No response received" / empty-stream style failures
8. User explicitly worries the "overseer" is the RAM culprit; current
   research says the heuristic overseer/router is not the real memory
   sink, so Claude should optimize send-path + model residency before
   ripping out the overseer

---

## 5 · Highest-priority next actions for Claude

Do these in order.

### 5.1 Finish verification and commit the current blocker batch

Goal:
- get a trustworthy focused test signal for the 11-file blocker batch
- if green, commit only that batch

Recommended focused checks:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/epistemos-blocker-batch-3 \
  build

xcodebuild -project Epistemos.xcodeproj -scheme Epistemos \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/epistemos-blocker-batch-3 \
  test \
  -only-testing:EpistemosTests/PipelineServiceTests/pipelineKeepsFinalAnswerAfterStructuredReasoningPlan \
  -only-testing:EpistemosTests/PipelineServiceTests/completeProcessingClearsThinkingState \
  -only-testing:EpistemosTests/AgentChatStateTests/completeProcessingOnEmptyStreamEmitsError \
  -only-testing:EpistemosTests/RuntimeValidationTests/workspaceAndAttachmentHeavyChatsKeepLightweightWorkspaceContextOnTheDefaultPath \
  -only-testing:EpistemosTests/RuntimeValidationTests/rustAgentPathsFinalizeCompletedTurnsAndSalvageSilentStreamEndings
```

If the Xcode harness still behaves badly:
- treat it as an environment blocker, not proof the code is bad
- document exactly what happened
- do not silently broaden the commit scope

### 5.2 Fix the still-synchronous prepared-model registry load in bootstrap

This is the next likely foreground/launch stall.

Verified hot path:
- `AppBootstrap.swift:1047-1055`

Current state:
- bootstrap constructor still does synchronous `preparedModelRegistry.load()`
- later async refresh path already exists

Likely minimal next fix:
- defer the initial synchronous load
- use the existing async refresh path to populate the state
- keep a safe empty/default snapshot until the async refresh lands

This likely helps:
- foreground tap/activation hang feel
- cold startup feel

### 5.3 Start the generated-project cleanup path

The user explicitly wants generated project management.

Do:
- inspect project generation config
- find the canonical generator source (`project.yml` / xcodegen config)
- if the source tree and Xcode project are out of sync, fix through the
  generator path
- run `xcodegen generate` when project membership changes need to land
- document whether `xcodegen generate` is now required before build
  verification

Do not:
- silently hand-edit `project.pbxproj`

### 5.4 Keep the research priorities in mind

The user’s supplied research materially shifts priorities:

1. Fix `UserFacingModelOutput` before assuming providers are the main
   culprit
2. Stop returning `""` silently when heuristic extraction fails
3. Treat the inline thinking accordion as a real UX requirement, not a
   nice-to-have
4. Keep moving toward native FFI multi-turn later, but do not let that
   derail Phase 0 / Phase 1 runtime fixes

---

## 6 · Specific code-level follow-ups suggested by the research

### A. `UserFacingModelOutput` should be revisited again

Even after the structured-plan salvage fix, the heuristic is still too
aggressive overall.

Recommended next audit target:
- `Epistemos/Engine/Extensions.swift`

Concrete direction:
- narrow `reasoningParagraphPrefixes`
- stop classifying answer-like openers as reasoning
- when split heuristics fail, prefer returning cleaned visible text over
  empty string

This is likely the biggest remaining cross-model improvement after the
current batch.

### B. Inline thinking UI is still a product requirement

Current reality:
- thinking persists and is renderable
- but live streaming still does not feel like ChatGPT / Claude inline
  reasoning

The user explicitly wants:
- thinking in a panel/box tied to the assistant bubble
- then the real answer streaming underneath

Treat this as a real follow-up, not cosmetic polish.

### C. MLX / local model safety still needs real system-level fixes

Still missing:
- `os_proc_available_memory()` pre-flight
- memory pressure listener
- honest refusal for oversized models on undersized machines
- moving actual inference off the main actor path

Those are Phase 1 runtime safety items, not optional cleanup.

---

## 7 · Validation evidence from this session

### Successful

- Warmed build completed on current blocker batch:
  - `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/epistemos-blocker-batch-3 build`
- Direct source checks confirmed expected new strings and guards in
  `ChatCoordinator.swift`

### Failed / noisy / inconclusive

- early focused tests hit real compile errors from test assertions and
  missing scope state
- those compile errors were fixed
- later focused `test` runs remained environment-noisy
- `test-without-building` failed because the test bundle was not present
  in the built app bundle
- stale old `Epistemos.app` process kept reappearing in process checks

Interpretation:
- code moved forward
- compile is verified
- focused behavioral test pass still needs to be nailed down by the next
  agent before commit

---

## 8 · Commit boundary for the current blocker batch

If Claude gets a satisfactory focused test result, stage and commit only:

- `Epistemos/App/AppBootstrap.swift`
- `Epistemos/App/ChatCoordinator.swift`
- `Epistemos/Engine/Extensions.swift`
- `Epistemos/Engine/MLXInferenceService.swift`
- `Epistemos/Engine/TriageService.swift`
- `Epistemos/State/AgentChatState.swift`
- `Epistemos/State/ChatState.swift`
- `EpistemosTests/AgentChatStateTests.swift`
- `EpistemosTests/PipelineServiceTests.swift`
- `EpistemosTests/RuntimeValidationTests.swift`
- `EpistemosTests/TriageServiceTests.swift`

Do not stage the wider dirty tree with it.

---

## 9 · User intent to preserve

These are not optional preferences; they are core requirements from the
user:

- The app must feel simple like Perplexity / ChatGPT even if the engine
  is sophisticated
- Thinking should be visible in a dedicated panel tied to the message,
  not typed into the main answer stream
- The final answer must always appear under the thinking, not just stop
  after thinking
- The app should not freeze when sending or foregrounding
- Large local models must fail honestly and safely instead of freezing
  the machine
- The project should be generated / kept aligned with the real source
  tree instead of drifting through direct Xcode project edits

Operational preference:
- if Claude needs to sync the Xcode project, prefer the auto-generated
  project path so the project reflects the real files in the repo
  without manual drift

---

## 10 · Operational cautions from this session

- Unified exec saturation was repeatedly hit during this session.
  Prefer reusing existing shells/sessions and avoid opening a swarm of
  new background processes.
- A stale historical `Epistemos.app` process from old DerivedData kept
  showing up during validation; treat the local Xcode environment as
  slightly suspect until a clean focused test pass is re-established.
- Do not interpret noisy or empty filtered Xcode test runs as success.
  Use real Swift Testing suite/test names and confirm actual execution.

---

## 11 · One-line summary for Claude

Finish verifying and committing the current 11-file blocker batch that
fixes Rust/cloud silent endings, send-path sync work, and answer
salvage; then move immediately to deferring the synchronous prepared
model registry bootstrap load and the generated-project/xcodegen cleanup,
with the user's new research treated as the priority map for the next
release-hardening wave.
