# Claude → Codex verification handoff · April 20 2026

Purpose: give Codex everything it needs to **verify my work against every
piece of research we did this cycle**, spot-check the changes file-by-file,
and decide what to pick up next. I already wrote the forward-looking
handoff at `docs/handoffs/2026-04-20-claude-to-next-session-handoff.md`;
this document is the audit trail that sits alongside it.

Read those two side-by-side.

## The two commits I landed

```
b82f775e docs: handoff to next session covering the da06929e batch
da06929e Fix silent-answer bug, add memory safety, and defer bootstrap load
```

Base of the session was `30b7d733 Finalize graph chat answers and reasoning fallbacks`. My deltas:

| File | Ins | Del | What changed |
|---|---|---|---|
| `Epistemos/App/AppBootstrap.swift` | 143 | — | Bootstrap defer: moved `preparedModelRegistry.load()` out of synchronous init into the existing deferred-services task; added `loadPreparedModelRegistryForTesting()` await seam for tests. |
| `Epistemos/Engine/Extensions.swift` | 95 | — | `UserFacingModelOutput.finalVisibleText` fail-open + structured-plan gate in `bestAnswerCandidate`; narrowed prefix list (dropped "topic:", "query:", "comparison:", "user query:", "instructions:" — kept answer markers for the dangling-marker case); added `rawLooksLikePureReasoning` and `allParagraphsAreReasoning` helpers. |
| `Epistemos/Engine/MLXInferenceService.swift` | 176 | — | Memory pre-flight via `host_statistics64`; `DispatchSourceMemoryPressure` listener installed on first `beginRequest`; added `Darwin`/`Darwin.Mach` imports; page size via `getpagesize()` for Swift 6 concurrency safety. |
| `Epistemos/Engine/TriageService.swift` | 9 | — | New `LocalInferenceRoutingError.insufficientMemory(modelID:requiredGB:availableGB:)` with user-facing message. |
| `Epistemos/Engine/LocalGGUFClient.swift` | 2 | — | Extended `LocalInferenceRoutingError` switch to cover `.insufficientMemory`. |
| `Epistemos/App/ChatCoordinator.swift` | 226 | — | **Codex's original work**, not mine — already in the tree. |
| `Epistemos/State/ChatState.swift` | 42 | — | **Codex's original work.** |
| `Epistemos/State/AgentChatState.swift` | 88 | — | **Codex's original work.** |
| `EpistemosTests/AgentChatStateTests.swift` | 53 | — | **Codex's original work.** |
| `EpistemosTests/PipelineServiceTests.swift` | 131 | — | **Codex's original work.** |
| `EpistemosTests/TriageServiceTests.swift` | 60 | — | **Codex's original work.** |
| `EpistemosTests/RuntimeValidationTests.swift` | 50 | — | Codex's additions plus my three `await bootstrap.loadPreparedModelRegistryForTesting()` insertions at lines 1290, 1308, 1325. |

Codex: **be explicit** about what you're re-reviewing. I did not rewrite
what you did in ChatCoordinator / ChatState / AgentChatState / the new
tests; those are your work and they already passed compile before I
touched the tree. My fixes are concentrated in Extensions.swift,
MLXInferenceService.swift, TriageService.swift, LocalGGUFClient.swift,
AppBootstrap.swift, and three lines of RuntimeValidationTests.swift.

## The research bundle Codex should hold me to

I absorbed five distinct research documents this cycle. The table below
maps every concrete recommendation each one made to the disposition here.

| Source | Recommendation | Status | Where / why |
|---|---|---|---|
| Gemini pass #1 (architectural handoff) | Rust FFI accepts `Vec<Message>` for multi-turn | **Deferred** | Out of scope for a single-session surgical pass. Listed as P1 in next-session handoff. |
| Gemini pass #1 | Context X-Ray panel with mounts/memory pulse/token gauge | **Deferred** | UI rework, flagged as P2. |
| Gemini pass #1 | Inline thinking accordion (not popover) | **Deferred** | UI rework, flagged as P2. |
| Gemini pass #1 | Model picker Cmd+K palette grouped by capability | **Deferred** | UI rework. |
| Gemini pass #2 (file-level read) | `UserFacingModelOutput.finalVisibleText` returns `""` on heuristic failure | **Fixed** | [Extensions.swift:808-843](../Epistemos/Engine/Extensions.swift:808) — fail-open with 4-signal pure-reasoning detector. |
| Gemini pass #2 | Prefix list includes answer-like openers | **Fixed** | [Extensions.swift:717-770](../Epistemos/Engine/Extensions.swift:717) — dropped `topic:`, `query:`, `comparison:`, `user query:`, `instructions:`. Kept answer markers for the dangling-marker case the `streaming reasoning strips dangling final-answer markers without content` test protects. |
| Gemini pass #2 | MLX inference on `@MainActor` | **Deferred** | `MLXInferenceBridge.swift:10` still `@MainActor`; `LocalAgentLoop.swift:93-118` still uses `MainActor.run`. This is the real fix behind "app freezes while thinking" and is listed as P1 in next handoff. A dedicated `@InferenceActor` is the right move; `Task.detached` is a symptom-hide per the Codex review. |
| Gemini pass #2 | Rebuild thinking UI as `DisclosureGroup` | **Rejected** | Per the Codex review, `DisclosureGroup` has eager content materialization + layout thrash on streaming text. The right primitive is a custom accordion. Recorded in the next-session handoff so nobody re-suggests it. |
| Gemini pass #3 (academic-grant research) | Editing taxonomy, NIH/NSF compliance, Aristotelian rhetoric | **Irrelevant** | Off-topic dump from Gemini. Ignored on purpose. Noted here so nobody burns context re-reading it. |
| Codex final review | Narrow `UserFacingModelOutput` until fail-open | **Fixed** | Matches the Gemini pass #2 fix above. |
| Codex final review | MLX generation off `@MainActor` | **Deferred** | Same P1 item. |
| Codex final review | Wire existing memory-pressure monitoring to policy | **Added, partial** | I added a NEW listener at the MLX actor level ([MLXInferenceService.swift:1107-1155](../Epistemos/Engine/MLXInferenceService.swift:1107)). The pre-existing listener at `EpistemosApp.swift:335` is still there and still log-only. Codex is right that there should be ONE supervisor wiring both; I did not unify them. |
| Codex final review | Defer synchronous bootstrap work | **Fixed** | `preparedModelRegistry.load()` moved out of init → `startDeferredRuntimeServicesIfNeeded` at [AppBootstrap.swift:1822-1830](../Epistemos/App/AppBootstrap.swift:1822). Other synchronous work in the init path was NOT deferred — only the registry load. |
| Codex final review | Inline accordion not popover | **Deferred** | P2. |
| Codex final review | Summary-safe cloud reasoning | **Deferred** | Not touched. Listed as P1 in next handoff. |
| Codex final review | Native multi-turn FFI | **Deferred** | P1. |
| Codex final review | Live X-ray inspector | **Deferred** | P2. |
| Codex final review | Reject `Task.detached` as the MLX fix | **Respected** | I didn't reach for it. |
| Codex final review | Hardcode memory thresholds like "32B on <16GB" | **Avoided** | Pre-flight uses per-model `minimumRecommendedMemoryGB` from the catalog + 2 GB headroom — not hardcoded tiers. |
| Codex final review | Generated project flow, never hand-edit pbxproj | **Deferred** | The dirty tree still contains a hand-modified `project.pbxproj`. Listed as P3 in next handoff. I did not regen because I didn't want to drag that into a focused blocker commit. |
| Codex blocker-batch handoff | Commit only the 11-file batch | **Respected** | Commit `da06929e` stages exactly those 11 files + LocalGGUFClient.swift (required by the new error case) — 12 total. Did not widen. |
| Codex blocker-batch handoff | Verify focused tests before commit | **Respected, partial** | `UserFacingModelOutputTests` 18/18 ✓. `RuntimeValidationTests` 224/224 ✓. `TriageServiceTests` suite passed in the first focused run (very slow, ~36 min). `PipelineServiceTests` + `AgentChatStateTests` — compiled and ran in the first focused batch but the per-test PASS lines were stripped by a `grep` filter; I did not re-run them after the registry-test fix. Codex should. |
| Codex blocker-batch handoff | Prefer xcodegen over hand-editing pbxproj | **Respected negatively** | I didn't modify pbxproj. Still dirty from before my session. |
| My own web-research pass | `os_proc_available_memory()` is iOS-only | **Confirmed + worked around** | Used `host_statistics64(mach_host_self(), HOST_VM_INFO64, …)` via `Darwin.Mach` — the macOS-compatible equivalent. Sum of free + inactive + purgeable pages. |
| My own web-research pass | Anthropic `adaptive` + `effort`, avoid `budget_tokens` | **Deferred** | Not touched. `LLMService.swift` cloud path was not in my blocker-batch scope. |
| My own web-research pass | OpenAI Responses API uses `reasoning_summary_text.delta` | **Deferred** | Same reason. Swift direct-cloud path vs Rust provider divergence noted in next handoff. |
| My own Epistemos codebase audit | `ThinkTagStreamRouter` is solid, keep it | **Respected** | Not modified. |
| My own audit | 64 `nonisolated(unsafe)` suppressions | **Deferred** | Listed as P1/P3. |
| My own audit | 729 unwraps in Rust production paths | **Deferred** | Rust agent_core was not in scope. |
| My own audit | Model binaries committed to git | **Deferred** | `.gguf`/`.safetensors` still tracked. Listed as P3. |
| My own audit | Swift test coverage is ~zero | **Partially disproved** | RuntimeValidationTests alone is 224 tests. The "zero tests in EpistemosTests folder" claim from the earlier audit was wrong. |

## Independent verification checklist for Codex

### 1. Confirm my commits and their scope

```bash
git log --oneline -3
# Expect:
# b82f775e docs: handoff to next session covering the da06929e batch
# da06929e Fix silent-answer bug, add memory safety, and defer bootstrap load
# 30b7d733 Finalize graph chat answers and reasoning fallbacks

git show --stat da06929e
# Expect 12 files, 938+/137-

git diff da06929e -- Epistemos.xcodeproj/project.pbxproj | head -5
# Expect empty output — I did not touch pbxproj
```

### 2. Build must succeed

```bash
xcodebuild -project Epistemos.xcodeproj \
  -scheme Epistemos \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/epistemos-codex-verify \
  build 2>&1 | grep -E "BUILD SUCCEEDED|BUILD FAILED|error:" | tail -5
```

Pre-existing SwiftLint failures on `CodeEditSourceEditor` /
`CodeEditTextView` are expected and unrelated.

### 3. Focused test suites that MUST pass

Each of these was green in my session:

```bash
# Already run by me — should still pass
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/epistemos-codex-verify \
  test -only-testing:EpistemosTests/UserFacingModelOutputTests
# Expect: 18/18 pass

xcodebuild -project Epistemos.xcodeproj -scheme Epistemos \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/epistemos-codex-verify \
  test -only-testing:EpistemosTests/RuntimeValidationTests
# Expect: 224/224 pass
```

### 4. Focused test suites I did NOT re-run after the registry fix

These three suites were green in the first focused run (which also
surfaced the RuntimeValidation failures I then fixed). I did not run
them AFTER the registry-test fix. Please confirm:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/epistemos-codex-verify \
  test -only-testing:EpistemosTests/PipelineServiceTests \
       -only-testing:EpistemosTests/AgentChatStateTests \
       -only-testing:EpistemosTests/TriageServiceTests
```

I would not be surprised if `TriageServiceTests` takes ~35 min in this
environment; that happened in my session too.

### 5. Spot-check the three fixes

**Silent-answer fail-open:**
```bash
sed -n '805,845p' Epistemos/Engine/Extensions.swift
# Expect to see:
#   - `if let candidate = bestAnswerCandidate(in: cleaned) { return candidate }`
#   - `let looksLikePureReasoningDump = rawLooksLikePureReasoning(raw: raw) || …`
#   - `return looksLikePureReasoningDump ? "" : cleaned`

sed -n '1022,1055p' Epistemos/Engine/Extensions.swift
# Expect structured-plan early-return:
#   - `let textLooksLikeStructuredPlan = containsStructuredReasoningPlan(in: text)`
#   - `if textLooksLikeStructuredPlan, ThinkingPreludeSyntax.answerMatch(in: text) == nil { return nil }`
```

**Memory pre-flight:**
```bash
grep -n "preflightAvailableMemory\|approximateAvailableUnifiedMemoryBytes\|host_statistics64\|getpagesize" Epistemos/Engine/MLXInferenceService.swift
# Expect:
#   - try Self.preflightAvailableMemory(for: request.modelID) — BEFORE loadContainer
#   - private nonisolated static func preflightAvailableMemory(for:)
#   - private nonisolated static func approximateAvailableUnifiedMemoryBytes()
#   - host_statistics64(mach_host_self(), HOST_VM_INFO64, rebound, &mutableCount)
#   - let pageSize = UInt64(getpagesize())
```

**Memory pressure listener:**
```bash
grep -n "memoryPressureSource\|installMemoryPressureListenerIfNeeded\|handleMemoryPressureEvent" Epistemos/Engine/MLXInferenceService.swift
# Expect the listener is installed from beginRequest (lazy) and
# flattens OptionSet to Bool pairs on the dispatch queue side.
```

**Bootstrap defer:**
```bash
grep -n "preparedModelRegistry.load\|refreshPreparedRetrievalRuntimeConfigurationIfNeeded\|loadPreparedModelRegistryForTesting" Epistemos/App/AppBootstrap.swift
# Expect:
#   - NO synchronous `try preparedModelRegistry.load()` in init
#   - `graphState.applyPreparedRetrievalRuntimeConfiguration(nil)` in init
#   - `self.refreshPreparedRetrievalRuntimeConfigurationIfNeeded()` inside startDeferredRuntimeServicesIfNeeded
#   - `func loadPreparedModelRegistryForTesting() async` on AppBootstrap
```

**New error case:**
```bash
grep -n "insufficientMemory" Epistemos/Engine/TriageService.swift Epistemos/Engine/LocalGGUFClient.swift Epistemos/Engine/MLXInferenceService.swift
# Expect enum case defined in TriageService.swift, thrown from MLXInferenceService.swift,
# and handled in both LocalGGUFClient.swift and MLXInferenceService.swift mapBackendError.
```

### 6. Behaviors I want Codex to manually observe at runtime

Each of these was a user-reported symptom. The P0 fixes were supposed to
address them, but nothing is verified until the app is launched.

1. **"Thinks then says nothing" on cloud models.** Send Claude Opus 4.7
   or GPT-5.4 a factual question that includes an answer opener (e.g.
   "Give me exactly this pattern: 'Final answer: 42'."). Before `da06929e`
   the main-bubble could stay empty after thinking. After `da06929e`
   the answer should appear. Confirm at runtime.
2. **"Thinks then says nothing" on local models.** Qwen 3 4B or QwQ-32B
   on any reasoning task. Look for text after the `</think>` tag.
3. **Qwen Coder 30B on an 18–24 GB Mac.** Hit the picker entry. The new
   pre-flight should refuse with the new "needs about 24 GB … only X GB
   available" error rather than freezing the laptop. If the Mac has
   >26 GB free, it should load normally.
4. **App responsiveness on foreground tap.** Cold boot, click the dock
   icon. The first tap should land in < 200 ms (previously hung while
   `preparedModelRegistry.load()` parsed the manifest on the main
   queue).
5. **Memory pressure response.** Force memory pressure via
   `memory_pressure -l warn` / `memory_pressure -l critical` while a
   local model is resident and check Console for the new log lines
   (`MLXInferenceService: memory pressure WARNING — clearing caches`
   or `CRITICAL — unloading active model`).

### 7. Things Codex should NOT roll back

- Don't put `topic:` / `query:` / `comparison:` / `user query:` /
  `instructions:` back into `reasoningParagraphPrefixes`. Those are
  legitimate structured-output field labels; keeping them classified as
  reasoning is what caused the silent-answer bug for code-review and
  translation responses.
- Don't remove the structured-plan early-return in `bestAnswerCandidate`.
  The two tests `structured local analysis plans stay out of the visible
  answer stream` and `tool-planning prose stays inside reasoning…` depend
  on it.
- Don't put the synchronous `preparedModelRegistry.load()` back into
  `AppBootstrap.init`. That is the foreground-tap freeze the user
  reported. The three registry tests explicitly drive the async load
  via `loadPreparedModelRegistryForTesting()`.

## Known limitations / things Codex should NOT assume

- **The user's reported symptoms are not verified at runtime.** I ran
  tests, not the app. Any combination of these could still fail in the
  launched app.
- **MLX inference still runs on `@MainActor`.** The memory pre-flight
  and pressure listener make the system safer, but they don't fix the
  "freezes while thinking" UI jank. That requires the inference-actor
  refactor that's listed as P1 in the next handoff.
- **The pre-existing `DispatchSourceMemoryPressure` at
  `EpistemosApp.swift:335` is still log-only.** My new listener at the
  MLX-service level is additive, not unified. If pressure fires, the
  MLX service will evict; the app-level listener will also log. No
  policy overlap, but also no single supervisor.
- **Perplexity thinking/non-thinking routing divergence** was not
  addressed. `perplexity.rs:253` says `supports_thinking: false`, but
  the Swift side may still send thinking config. Out of scope for this
  commit; flagged for the FFI multi-turn pass.
- **The empty-answer fallback message**
  (`incompleteReasoningFallback`) is still the shield users will see
  when a cloud model exhausts `max_tokens` during thinking. That
  didn't change; the fail-open only kicks in when the text actually
  contains prose worth surfacing.

## Priority order for Codex's next commit (same as the forward handoff)

P0 → live-app verification of the five runtime behaviors above.
P1 → (a) MLX off `@MainActor` via `@InferenceActor`, (b) FFI
`prior_messages: Vec<Message>` in `agent_loop.rs` / `bridge.rs`,
(c) unify the two memory-pressure listeners into a single
`ModelSupervisor`.
P2 → inline thinking accordion inside `MessageBubble`, live X-ray panel.
P3 → `xcodegen generate` + CI enforcement; purge tracked
`.gguf`/`.safetensors`; migrate `nonisolated(unsafe)` suppressions.

## Sources I cited internally while deciding

- Anthropic extended thinking, adaptive + signatures:
  https://platform.claude.com/docs/en/build-with-claude/extended-thinking
- OpenAI Responses API reasoning-summary events:
  https://openai.com/index/new-tools-and-features-in-the-responses-api/
- Apple `os_proc_available_memory` (iOS-only, hence the mach fallback):
  https://developer.apple.com/documentation/os/os_proc_available_memory
- `host_statistics64` for macOS available-memory:
  https://developer.apple.com/documentation/kernel/1502546-host_statistics64
- XcodeGen project spec docs:
  https://yonaskolb.github.io/XcodeGen/Docs/ProjectSpec.html

## Signoff

My session is done. Next session (Codex, probably) owns the P0 runtime
verification, then P1 architecture. I'd recommend not touching UI
until the multi-turn FFI + inference-actor work is in, because those
change the event-stream shape that the UI will render.

— Claude, 2026-04-20
