# Claude → next session handoff · April 20 2026

> **Index status**: CANONICAL-HISTORICAL — Session handoff; kept for state recovery (30-day minimum). No copy to _consolidated.
> Classified in [`docs/_INDEX.md §14`](_INDEX.md).



Scope: what landed in commit `da06929e`, what still needs work, and the
concrete priority order for the next session. Built on top of the Codex
handoff from earlier the same day plus three rounds of external research
the user pasted in (two from Gemini, one from Codex review).

## TL;DR

Commit `da06929e` lands three surgical fixes, all scoped to the existing
Codex blocker batch (no extra files):

1. Natural answers no longer get silenced by the cross-provider
   heuristic that watched for reasoning prefixes — `finalVisibleText`
   now fails open with a structured-plan gate.
2. Local model loads pre-flight against real unified-memory
   availability (`host_statistics64`) and refuse up-front when the
   machine doesn't have room — the Qwen-Coder-30B-frozen-laptop case.
3. `preparedModelRegistry.load()` no longer blocks bootstrap init; it
   runs inside the existing deferred-services task 250 ms after
   primary launch. Tests use a new `loadPreparedModelRegistryForTesting()`
   await seam.

The remaining 83 dirty files from the original branch are unchanged and
intentionally NOT committed with this batch, matching the Codex
directive.

## What exactly changed

### `Epistemos/Engine/Extensions.swift` — silent-answer bug
- Restored dangling answer-marker entries (`final answer:`,
  `final response:`, `answer:`, `response:`) in
  `reasoningParagraphPrefixes`. `directAnswerText` / `answerMatch`
  handles the "marker + content" case first; the prefix list now only
  kicks in for the empty-dangling-marker case that the
  `streaming reasoning strips dangling final-answer markers without
  content` test protects.
- Dropped the structured-output field labels (`topic:`, `query:`,
  `comparison:`, `user query:`, `instructions:`). Models legitimately
  use those as output structure in code-review, translation, and
  categorization tasks — flagging them as reasoning was eating real
  answers.
- `bestAnswerCandidate` now short-circuits structured-reasoning plans
  early: when `containsStructuredReasoningPlan` fires AND no explicit
  answer marker appears, return `nil` so the salvage-fallback message
  surfaces instead of leaking the plan's trailing
  "this approach will efficiently…" conclusion line.
- `finalVisibleText` fails open: when `bestAnswerCandidate` returns
  `nil`, surface the cleaned text unless the input looks like a pure
  reasoning dump (explicit prelude / prose opener / structured plan /
  every-paragraph-is-reasoning).

### `Epistemos/Engine/MLXInferenceService.swift` — memory safety
- New `preflightAvailableMemory(for:)` runs right before
  `LLMModelFactory.shared.loadContainer(...)`. Uses
  `host_statistics64(mach_host_self(), HOST_VM_INFO64, …)` (macOS
  equivalent of `os_proc_available_memory()`, which is iOS-only) to
  sum `free + inactive + purgeable` pages, converts to GB, and throws
  `LocalInferenceRoutingError.insufficientMemory(modelID:requiredGB:availableGB:)`
  when available memory is materially below the model's documented
  `minimumRecommendedMemoryGB` (2 GB headroom).
- New `installMemoryPressureListenerIfNeeded()` registers a
  `DispatchSource.makeMemoryPressureSource(eventMask: [.warning,
  .critical], queue: .utility)` on first `beginRequest`. Flattens the
  event to `Bool` pairs on the dispatch queue side before hopping
  into the actor (Swift 6 sending-risk discipline). On `.warning`
  re-applies the shrink-caches policy; on `.critical` unloads the
  resident model.
- Added `import Darwin` / `import Darwin.Mach` for
  `host_statistics64` + `vm_statistics64_data_t`. Page size uses
  `getpagesize()` (concurrency-safe C call) instead of
  `vm_kernel_page_size` (Swift 6 flags it as shared mutable state).

### `Epistemos/Engine/TriageService.swift` — new error case
- Added `LocalInferenceRoutingError.insufficientMemory(modelID:, requiredGB:, availableGB:)`
  with a user-visible message that names the model, the required GB,
  and the currently available GB.

### `Epistemos/Engine/LocalGGUFClient.swift` — switch exhaustiveness
- Extended the `LocalInferenceRoutingError` switch in
  `mapBackendError` to cover the new `.insufficientMemory` case by
  returning `.modelNotLoaded` (same contract bucket as
  `modelLoaderUnavailable` / `modelLoadStalled`).

### `Epistemos/App/AppBootstrap.swift` — deferred registry load
- Removed the synchronous `try preparedModelRegistry.load()` block
  from the `init`. `graphState.applyPreparedRetrievalRuntimeConfiguration(nil)`
  now runs synchronously; downstream clients start with a nil
  generation-runtime configuration and fall back to baseline defaults.
- Added `refreshPreparedRetrievalRuntimeConfigurationIfNeeded()` into
  `startDeferredRuntimeServicesIfNeeded`'s task body, ~250 ms after
  primary launch. This keeps cold-boot and first-foreground-tap
  responsive while still populating the registry before the user
  actually needs cloud/local routing.
- New `loadPreparedModelRegistryForTesting()` async helper kicks the
  refresh and awaits `preparedRetrievalRefreshTask`. Tests that used
  to assert registry state immediately after `AppBootstrap()` init
  now explicitly await this seam.

### `EpistemosTests/RuntimeValidationTests.swift`
- Three registry-bootstrap tests
  (`bootstrapLoadsPreparedModelRegistry`,
  `bootstrapPropagatesPreparedRetrievalAssets`,
  `bootstrapSurfacesThePreparedRetrievalRuntimeStateFromTheLiveAssetLayout`)
  now `await bootstrap.loadPreparedModelRegistryForTesting()` before
  asserting. Full RuntimeValidationTests suite: 224/224 pass.

## Verification evidence

- `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS,arch=arm64' build` → BUILD SUCCEEDED (only the CodeEditSourceEditor/CodeEditTextView SwiftLint phases fail, unchanged from pre-session state).
- `xcodebuild test -only-testing:EpistemosTests/UserFacingModelOutputTests` → 18/18 pass.
- `xcodebuild test -only-testing:EpistemosTests/RuntimeValidationTests` → 224/224 pass.
- Earlier focused-run log showed `Suite "TriageService" passed after 2184 s` (slow but green).
- PipelineServiceTests and AgentChatStateTests were in the first focused
  batch run where only RuntimeValidation reported failures (6), and
  those 6 are now fixed — so those suites should be green but a clean
  repeat run is the next-session's first task.

## What is still open (priority order)

### P0 — next session, start here
1. **Repeat the full focused test run** now that the registry tests
   compile and pass in isolation. Command:
   ```
   xcodebuild -project Epistemos.xcodeproj -scheme Epistemos \
     -destination 'platform=macOS,arch=arm64' \
     -derivedDataPath /tmp/epistemos-verify test \
     -only-testing:EpistemosTests/PipelineServiceTests \
     -only-testing:EpistemosTests/AgentChatStateTests \
     -only-testing:EpistemosTests/TriageServiceTests \
     -only-testing:EpistemosTests/RuntimeValidationTests \
     -only-testing:EpistemosTests/UserFacingModelOutputTests
   ```
2. **Live launched-app verification** of the three P0s from Codex's
   `docs/AGENT_PROGRESS.md §2026-04-20` plus the new ones this commit
   fixes:
   - Fast mode never routes to an always-thinking family.
   - Qwen Coder cold-load EITHER succeeds OR is refused by the new
     pre-flight with the `insufficientMemory` error visible in the
     chat, not a frozen UI.
   - Agent thinking renders only in the thinking popover, never inline
     in the main bubble.
   - Natural answers with openers like "Let me start by…",
     "Final answer: 42", "Answer:" actually surface after the narrowing
     + fail-open. Compare against pre-commit `da06929e` behavior.

### P1 — the architecture follow-throughs from the research pass
3. **MLX generation off `@MainActor`.** `MLXInferenceBridge.swift:10`
   is still `@MainActor`; `LocalAgentLoop.swift:93-118` still wraps
   generation in `MainActor.run`. This is the real fix behind "the app
   freezes while thinking on local models." Use a dedicated
   `@InferenceActor` actor. Don't reach for `Task.detached` — that's
   the symptom-hiding temporary the Codex review flagged. Preserve the
   existing `DispatchSourceMemoryPressure` listener at
   `EpistemosApp.swift:335` and route its events into runtime policy
   alongside the per-service listener this commit added.
4. **FFI multi-turn lift.** `agent_core/src/agent_loop.rs:157` still
   seeds `vec![Message::user_text(&objective)]`; `bridge.rs:508`'s
   `run_agent_session` still has no `prior_messages: Vec<Message>`
   parameter. Swift already holds the canonical `ChatState.messages`.
   Next structural win: add the FFI parameter, keep vault/skills in
   system context, let prompt caching + tool-call continuity recover.

### P2 — NUX the user explicitly asked for
5. **Inline thinking accordion** inside `MessageBubble.swift`. Replace
   the detached `ThinkingPopoverView` with an inline custom accordion
   — NOT `DisclosureGroup` (research flagged layout/perf issues on
   streaming text). Auto-expand during reasoning, auto-collapse on
   first answer token, re-openable after completion.
6. **Submit-path acknowledgement first, enrichment second.**
   `ChatCoordinator.handleQuery()` still does synchronous vault
   semantic search (line 2643) and the full workspace-awareness graph
   walk (lines 2847-2978) before streaming starts. Create the pending
   assistant turn immediately; kick retrieval / workspace context
   concurrently; feed whatever lands in time into the request.
7. **Context X-Ray live inspector.** `ChatBrainPanelView` already
   shows snapshot state. Next: a live mounts list that updates when
   agents call `read_file`, a per-tier memory pulse, reconciled
   token counts (provider `usage` at stream complete), and
   per-message "what was in context" reveal.

### P3 — build hygiene
8. **xcodegen alignment.** `Epistemos.xcodeproj/project.pbxproj` is
   still modified in the dirty tree. The user wants generated-project
   truth; do a regen and commit it as its own scoped change. Consider
   a CI check: `xcodegen generate && git diff --exit-code
   Epistemos.xcodeproj/project.pbxproj`.

## Things to deliberately NOT do

- Don't widen the commit scope. 83 files are still dirty on this
  branch. Each subsequent change should stay scoped.
- Don't revert the fail-open change to chase the (pre-existing and now
  green) structured-plan test failure via brittle heuristics. The
  structured-plan gate in `bestAnswerCandidate` is the right shape.
- Don't replace the thinking UI with `DisclosureGroup`. The user
  showed research specifically pushing back on that; use a custom
  accordion.
- Don't try the inference-actor refactor and the FFI multi-turn lift
  in the same commit. Each is a standalone high-risk change.

## Environment notes

- The Xcode harness in this session was slow (~36 min for the full
  focused run), likely due to a stale `Epistemos.app` process from
  prior DerivedData. If it happens again, check for it with
  `ps aux | grep Epistemos` before blaming the code.
- SwiftLint failures for `CodeEditSourceEditor` and `CodeEditTextView`
  are pre-existing SPM package issues, not regressions.

## Relevant reference material absorbed this session

External research pasted by the user:
- OpenAI Responses API reasoning summaries vs raw CoT:
  https://openai.com/index/new-tools-and-features-in-the-responses-api/
- Anthropic extended thinking adaptive + signatures:
  https://platform.claude.com/docs/en/build-with-claude/extended-thinking
- Apple memory headroom (iOS-only `os_proc_available_memory`, macOS
  uses Mach host stats):
  https://developer.apple.com/documentation/os/os_proc_available_memory

All of that shaped the decisions in commit `da06929e`. The academic
grant-writing research the user also pasted is not relevant to the app
and is noted here only so the next agent doesn't have to re-read it.
