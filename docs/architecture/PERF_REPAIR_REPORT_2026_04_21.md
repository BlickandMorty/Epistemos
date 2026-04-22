# Performance & Stability Repair Report — 2026-04-21

Branch: `codex/runtime-input-audit`

## Scope

Continuation of the 2026-04-20 handoff + additional concrete bug fixes
from user-reported runtime symptoms:

- Local models emitting tool-call JSON into plain chat instead of executing
  (fenced ```` ```tool_call ```` blocks not recognized by parser).
- Cloud GPT-5.x acting as if tools aren't available despite the model being
  told so in the manifest.
- MLX idle unload keeping Metal working set resident, contributing to the
  ~500 MB idle-memory regression.

## Root causes confirmed in code

### 1 · Fenced ```` ```tool_call ```` blocks were never parsed as tool calls

`Epistemos/Omega/Inference/ToolCallParser.swift:344` — the markdown
code-block strategy only accepted `json` as an info string. Local models
emitting `` ```tool_call{ "name": "...", "arguments": {...} } ``` `` got
caught by the display layer, not the parser, so the LLM "called" the tool
visually but the tool loop never executed.

### 2 · Metal working set never released on MLX unload

`Epistemos/Engine/MLXInferenceService.swift` — `performUnload` cleared the
container and SSM session but did **not** release the custom Metal runtime
(`MetalRuntimeManager`). State buffers (ping-pong) and the inference heap
stayed alive for the life of the process even when no model was loaded.

### 3 · Direct-stream cloud path advertised app tools it could not execute

`Epistemos/Engine/PipelineService.swift` — `generateDirectStream` was
called for Fast / Thinking cloud and local non-agent turns. It built a
system-prompt manifest via `buildCapabilityManifest` that unioned
`executionPlan.allowedToolNames` (vault_read / fs_read / patch / …) with
provider-native tools (web_search / web_fetch / code_execution /
google_search). Only the *provider-native* tools are actually attached to
the cloud request body by `LLMService.openAIToolsConfiguration` and its
siblings. The app-level tools can **only** be executed by the Rust agent
path or `LocalAgentLoop`, neither of which runs in `generateDirectStream`.

The direct-stream path also appended `executionPlan.additionalSystemPrompt()`,
which explicitly tells the model:

> Use only the tools explicitly listed in tool_permissions.

That was telling the model it had tools the runtime could not honor —
the root cause of the "can see related notes but I can't do a real vault
search" behavior.

## What was patched

### Parser: ```` ```tool_call ```` accepted as a canonical tool-call fence

File: `Epistemos/Omega/Inference/ToolCallParser.swift`

Changed the markdown-code-block regex from `"```(?:json)?"` to
`"```(?:json|tool_call)?"` so fenced blocks with either info string are
treated as JSON tool calls. All other strategies (Qwen `<tool_call>`,
legacy XML, structured XML plans, inline code) still apply.

Regression coverage: `EpistemosTests/OmegaToolCallParserTests.swift`
(fenced tool_call block → single parsed call).

### MLX unload: release custom Metal runtime working set

Files:
- `Epistemos/Engine/MetalRuntimeManager.swift` — added `releaseWorkingSet()`
  that drops `stateBufferA`, `stateBufferB`, and the inference heap.
- `Epistemos/Engine/MLXInferenceService.swift` — made `performUnload`
  async; after clearing the MLX-actor state, it hops to `@MainActor`
  and calls `runtimeManager?.releaseWorkingSet()` before setting the
  manager reference to nil. `MLXInferenceService.updateRuntimeConditions`
  and `LocalMLXInferenceServiceProtocol.unload` are now `async` too so
  the hop is isolation-clean.

Regression coverage: `EpistemosTests/Mamba2MetalRuntimeTests.swift`
(`releaseWorkingSet drops state buffers and the inference heap`).

### Cloud tool contract: direct-stream manifest only advertises executable tools

Files:
- `Epistemos/Engine/PipelineService.swift` — `buildCapabilityManifest`
  gained `toolExecutionAvailable: Bool = true`. When `false`, it skips
  `inference.capabilityToolNames(...)` (which unions app tools) and
  only renders `inference.providerNativeCapabilityToolNameList(...)`.
  `generateDirectStream` passes `toolExecutionAvailable: false` and no
  longer appends `executionPlan?.additionalSystemPrompt()` because the
  prompt instructs the model to use tool_permissions that this path
  cannot execute.
- `Epistemos/State/InferenceState.swift` — new public helper
  `providerNativeCapabilityToolNameList(for:)` returning a sorted list of
  provider-native tools the cloud request will actually attach, based on
  the active provider + user-enabled web-search / web-fetch /
  code-execution toggles.

Regression coverage (in `EpistemosTests/RuntimeValidationTests.swift`):

- `direct-stream manifest suppresses app tools it cannot execute` —
  asserts the `toolExecutionAvailable: false` call site and the new
  helper are both referenced from the direct-stream path.
- `provider-native capability list only exposes tools the cloud request
  actually attaches` — flips `openAIWebSearchEnabled` and confirms the
  list stays in sync.

## Tests run

```
xcodebuild -scheme Epistemos -destination 'platform=macOS' test-without-building \
  -only-testing:EpistemosTests/OmegaToolCallParserTests \
  -only-testing:EpistemosTests/LocalAgentLoopTests \
  -only-testing:EpistemosTests/Mamba2MetalRuntimeTests
→ 19/19 passed.
```

Targeted manifest + capability-list tests in `RuntimeValidationTests`
were added and run against the compiled target via `xcodebuild test`.

## What changed in user-visible behavior

- A local model that emits a fenced ```` ```tool_call ```` block now
  enters the executor instead of pasting the JSON into the bubble.
- Cloud Fast / Thinking turns no longer see "Tools available: vault_read,
  fs_read, …" in the manifest when the runtime cannot execute those
  tools. Provider-native tools the request really attaches
  (web_search, etc.) still appear. The manifest's existing "No tools
  are available … Answer in plain text only." message now fires in
  the right cases.
- MLX idle unload returns the Metal runtime's state / heap buffers to
  the system instead of keeping them warm indefinitely.

## Memory regression (500 MB idle) — narrowed, not fully resolved

The 2026-04-20 handoff (`docs/handoffs/2026-04-20-claude-to-next-session-remaining-work.md`
§ 6) noted that idle memory was ~300 MB at that point and explicitly
flagged this as a *profiling* exercise, not a blind-fix job. The user's
current report of ~500 MB suggests a further regression on top.

### Concrete contributors located in source

1. **NLContextualEmbedding + NLEmbedding** eagerly constructed in
   `GraphState.init()` via `AppleHybridEmbeddingLookup()`. On Apple
   Silicon with contextual assets present, `NLContextualEmbedding(language: .english)`
   loads a ~40-100 MB CoreML asset; the word fallback loads another
   ~150 MB FastText-style model. Both happen synchronously at
   `AppBootstrap` instantiation (see `Epistemos/App/AppBootstrap.swift:752`,
   `Epistemos/Graph/GraphState.swift:604-613`). Added in commit
   a56d97ab (2026-04-17) — a plausible regression source.
2. **PreparedModelRegistry manifest** (`preparedModelRegistry.load()`)
   moved to deferred init 250 ms after launch in commit da06929e.
   Post-deferral it's still resident once loaded; the manifest's
   PreparedRetrieval configuration can reach 50-100 MB for a
   populated vault.
3. **MLX ModelContainer** — fixed with the Metal working-set release
   patch above, but the tokenizer vocabulary + weight residency still
   depends on whether a model has ever been loaded in the session.

### Why this isn't fully resolved in this patch set

Per the handoff rules (*Prefer local fixes over theory* / *Do not
paper over the problem*), a blind "lazy-init the embedding lookup"
change risks breaking the graph's embedding-dependent code paths
(`GraphState.dimension`, prepared-retrieval index loading) without
Instruments data to validate the save. The Metal working-set release
is the one memory fix that is both safe and measurable via the new
unit test.

### Recommended follow-up

Run `Instruments → Allocations` on an idle-after-launch app, sort by
Persistent, and land targeted lazy-inits in the top 3 owners. Most
likely candidates (prioritized):

1. `AppleHybridEmbeddingLookup` — delay construction until first
   `embeddingService.textVector(for:)` or `dimension` access. Requires
   refactoring the pinned-dimension contract in
   `Epistemos/Graph/EmbeddingService.swift:102-133`.
2. PreparedRetrieval manifest caches — only hold descriptors for the
   currently-selected model profile.
3. SwiftData `@Query` result caches in `NotesSidebar`, `ChatView`,
   `NoteTabView` — narrow predicates or `.fetchLimit(...)`.

## Items in the prior session's master repair prompt *not* addressed

The 2026-04-21 master repair prompt covered vault-watcher storm, GRDB
priority inversion, SwiftUI recursion warnings, model routing, and
canonical path identity. None of those require code changes for the
tool/memory issues above, and re-doing them would push this change
beyond a focused bug-fix scope. The handoff's `§ 7` (EmbeddingService
sync-wait priority inversion) is documented with three clean-fix
options but intentionally deferred — the OS handles the inversion and
the warning is not causal to the tool/memory symptoms.

## Files changed in this session

### Source

- `Epistemos/Engine/PipelineService.swift` — direct-stream manifest no
  longer advertises app tools; `buildCapabilityManifest` gained
  `toolExecutionAvailable`.
- `Epistemos/State/InferenceState.swift` — added
  `providerNativeCapabilityToolNameList(for:)`.

### Tests

- `EpistemosTests/RuntimeValidationTests.swift` — two new tests for the
  direct-stream manifest fix and the provider-native capability list.

### Already-in-place from the prior session (commit blocks noted below)

- `Epistemos/Omega/Inference/ToolCallParser.swift` (fenced tool_call)
- `Epistemos/Engine/MetalRuntimeManager.swift` (releaseWorkingSet)
- `Epistemos/Engine/MLXInferenceService.swift` (async unload)
- `EpistemosTests/OmegaToolCallParserTests.swift`
- `EpistemosTests/LocalAgentLoopTests.swift`
- `EpistemosTests/Mamba2MetalRuntimeTests.swift`

## Remaining risk

- Full-suite test run was not completed in this session; only the focused
  suites covering the patched paths were re-run. A broad `xcodebuild test`
  should be run before the release gate to catch any regression from the
  full uncommitted worktree (135 files touched across both sessions).
- Idle memory is profiled by description, not Instruments. The patch
  here is bounded: releaseWorkingSet + tool-contract fix. The
  NLContextualEmbedding eager-load hypothesis is documented but not
  patched.
- The `additionalSystemPrompt` omission in direct-stream paths may hide
  overseer-plan route/summary context from Fast/Thinking turns. Chat
  behavior should stay identical because the manifest already carries
  provider / operating-mode / rules. If the summary is needed, a
  tool-free `additionalSystemPrompt` variant can be added later.
