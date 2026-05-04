# Performance & Stability Repair Report — 2026-04-21

> **Index status**: SUPERSEDED-HISTORICAL — Phase-specific historical reference; superseded by MASTER_FUSION.md.
> Classified in [`docs/_INDEX.md §14`](_INDEX.md).



Branch: `codex/runtime-input-audit`

## Scope

Continuation of the 2026-04-20 handoff + additional concrete bug fixes
from user-reported runtime symptoms:

- Local models emitting tool-call JSON into plain chat instead of executing
  (fenced ```` ```tool_call ```` blocks not recognized by parser).
- Cloud GPT-5.x acting as if tools aren't available despite the model being
  told so in the manifest.
- Essay / draft requests not consistently promoting into the same
  tool-required note-read contract as explicit `note` wording.
- Mini Chat showing `Thinking` while the runtime was explicitly in `Tools`
  mode on local models, making the UI lie about the actual execution path.
- MLX idle unload keeping Metal working set resident, contributing to the
  ~500 MB idle-memory regression.
- Graph bootstrap eagerly constructing the Apple hybrid embedding lookup,
  front-loading large NLP assets before any semantic graph access.

## Root causes confirmed in code

### 0 · Semantic note lookups were not fully propagated into planner context

`Epistemos/App/ChatCoordinator.swift` already detected semantic vault/note
queries with `queryContainsExplicitNoteContext(query)` and resolved note
bodies into `notesContext`, but it only forwarded **attachment-backed**
context into `buildOverseerExecutionPlan(...)` via `hasAttachedUserContext`.
That meant planner heuristics could still treat a request like
`"read my essay on determinism and summarize it"` as if it were missing
explicit context unless the user had attached a note manually.

Separately, `queryRequiresVerifiedVaultRead(_:)` only recognized
`note`-wording (`read my note`, `summarize the note`, etc.). Equivalent
`essay` / `draft` phrasing was not treated as a required verified read,
which weakened the "don't guess, actually read" contract on the managed
tools path.

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

### 4 · Mini Chat mapped explicit Tools mode into a Thinking pill

`Epistemos/Views/MiniChat/MiniChatView.swift` — the composer pill used
`selectedOperatingMode.capturesReasoningTrace` to decide whether to show
the brain / Thinking affordance. `.agent` also captures reasoning traces,
so an explicit local `Tools` selection (`Tools • Qwen3 4B`) still rendered
as `Thinking` even though the runtime description correctly said
`Tools runs directly on Qwen 3 4B`.

### 5 · Graph bootstrap eagerly loaded the Apple hybrid embedding stack

`Epistemos/Graph/GraphState.swift` initialized
`EmbeddingService(embeddingLookup: AppleHybridEmbeddingLookup())` directly
at launch. On Apple Silicon that can synchronously instantiate
`NLContextualEmbedding` plus the fallback `NLEmbedding` before any graph
semantic query, which is exactly the kind of idle-memory regression the
handoff had narrowed to `GraphState.init()`.

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

### Shared tool routing: essay / draft phrasing now escalates like note reads

Files:
- `Epistemos/Engine/AgentHarness/ChatCapability.swift` — expanded the
  shared agent-signal list so `essay` / `draft` lookup, summarize,
  rewrite, review, analyze, duplicate, and read verbs all classify as
  `.agent` instead of falling through to plain local / cloud chat.
- `Epistemos/App/ChatCoordinator.swift` — planner context and the
  verified-read guard now treat essay / draft phrasing as real note-read
  work instead of letting the model guess.

Regression coverage:
- `EpistemosTests/ChatCapabilityIntentTests.swift`
  (`essay and draft vault lookup verbs predict agent intent`)
- `EpistemosTests/TriageServiceTests.swift`
  (`cloud essay lookup turns escalate to a managed tools session before note resolution`)

### Mini Chat mode honesty: explicit Tools mode now renders as Tools

Files:
- `Epistemos/Views/MiniChat/MiniChatView.swift`
  - model-aware operating-mode list via
    `inference.availableOperatingModes(for:)`
  - mode re-sanitization when the selected model changes
  - explicit `.agent` and `.pro` turns stay on the shared coordinator path
  - composer pill treats only `.thinking` as Thinking and treats
    explicit `.agent` as Tools
- `EpistemosTests/MiniChatViewAuditTests.swift`
  - source-contract coverage for the new Tools-pill behavior

Runtime validation (2026-04-22, rebuilt audit app):
- `Tools • Qwen3 4B` now shows the purple `Tools` pill instead of the old
  `Thinking` pill.
- The prompt `read my essay on determinism and summarize it` returned an
  honest `I couldn't find or read the note in the user's notes.` response
  instead of the old guessed-path / fabricated-read behavior from the
  screenshots.

### Idle-memory hardening: defer Apple hybrid embedding construction

Files:
- `Epistemos/Graph/EmbeddingService.swift` — added
  `DeferredTextEmbeddingLookup`, a locked one-time factory wrapper that
  resolves the real lookup only on first semantic access.
- `Epistemos/Graph/GraphState.swift` — wraps `AppleHybridEmbeddingLookup()`
  in `DeferredTextEmbeddingLookup` so launch no longer eagerly loads the
  contextual + word embedding assets.

Regression coverage:
- `EpistemosTests/BlockEmbeddingTests.swift`
  (`deferred embedding lookup waits until the first semantic access`)

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

```
./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos \
  -destination 'platform=macOS' test \
  -only-testing:EpistemosTests/ChatCapabilityIntentTests \
  -only-testing:EpistemosTests/TriageServiceTests \
  -only-testing:EpistemosTests/MiniChatViewAuditTests
→ 62/62 passed.
Result bundle:
/Users/jojo/Downloads/Epistemos/build/xcode-results/2026-04-22-001150-64378.xcresult
```

```
./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos \
  -destination 'platform=macOS' test \
  -only-testing:EpistemosTests/BlockEmbeddingTests \
  -only-testing:EpistemosTests/Mamba2MetalRuntimeTests
→ 25/25 passed.
Result bundle:
/Users/jojo/Downloads/Epistemos/build/xcode-results/2026-04-22-002422-72623.xcresult
```

Manual/runtime verification:

```
./scripts/launch_audit_app.sh --minimal-home --root-shell-minimal
./scripts/launch_audit_app.sh --no-build
```

- Rebuilt audit bundle from the current worktree and drove Mini Chat with
  Computer Use.
- Verified the old `Tools • Qwen3 4B` + `Thinking` mismatch is gone in the
  rebuilt app.
- Spot-checked resident memory after a local `Qwen3 4B` Tools turn:

```
ps -o pid=,rss=,etime=,command= -p 70373
→ RSS 68464 KB (~67 MB resident)
```

## What changed in user-visible behavior

- A local model that emits a fenced ```` ```tool_call ```` block now
  enters the executor instead of pasting the JSON into the bubble.
- Cloud Fast / Thinking turns no longer see "Tools available: vault_read,
  fs_read, …" in the manifest when the runtime cannot execute those
  tools. Provider-native tools the request really attaches
  (web_search, etc.) still appear. The manifest's existing "No tools
  are available … Answer in plain text only." message now fires in
  the right cases.
- Semantic vault-read requests such as `read my essay on determinism`
  now count as explicit context for planning, even when the user did
  not attach a note manually.
- Essay / draft phrasing now trips the same verified-read guard as
  `read my note`, so the app is less willing to let a tool-capable
  runtime bluff its way through note-reading work.
- Mini Chat no longer shows a Thinking brain when the selected runtime is
  explicitly `Tools`.
- Switching Mini Chat between local models now re-sanitizes invalid modes
  instead of leaving stale `Thinking` / `Tools` combinations attached to
  the wrong model family.
- The graph embedding stack is no longer forced into memory at launch
  before the user does any semantic graph work.
- MLX idle unload returns the Metal runtime's state / heap buffers to
  the system instead of keeping them warm indefinitely.

## Memory regression (500 MB idle) — reduced, not fully closed

The 2026-04-20 handoff (`docs/handoffs/2026-04-20-claude-to-next-session-remaining-work.md`
§ 6) noted that idle memory was ~300 MB at that point and explicitly
flagged this as a *profiling* exercise, not a blind-fix job. The user's
current report of ~500 MB suggests a further regression on top.

### Concrete contributors located in source

1. **NLContextualEmbedding + NLEmbedding** were eagerly constructed in
   `GraphState.init()` via `AppleHybridEmbeddingLookup()`. On Apple
   Silicon with contextual assets present, `NLContextualEmbedding(language: .english)`
   loads a ~40-100 MB CoreML asset; the word fallback loads another
   ~150 MB FastText-style model. Both happen synchronously at
   `AppBootstrap` instantiation (see `Epistemos/App/AppBootstrap.swift:752`,
   `Epistemos/Graph/GraphState.swift:604-613`). Added in commit
   a56d97ab (2026-04-17) — this session now defers that construction
   behind first semantic access.
2. **PreparedModelRegistry manifest** (`preparedModelRegistry.load()`)
   moved to deferred init 250 ms after launch in commit da06929e.
   Post-deferral it's still resident once loaded; the manifest's
   PreparedRetrieval configuration can reach 50-100 MB for a
   populated vault.
3. **MLX ModelContainer** — fixed with the Metal working-set release
   patch above, but the tokenizer vocabulary + weight residency still
   depends on whether a model has ever been loaded in the session.

### Why this still isn't fully resolved

The biggest *safe* eager-load contributor is now patched: the graph no
longer constructs `AppleHybridEmbeddingLookup` until semantic work
actually needs it, and the audit app's resident set after a local Tools
turn was ~67 MB (`ps` RSS) instead of the previously reported
hundreds-of-MB idle footprint. That said, `ps` undercounts unified-memory
pressure, and the audit bundle used an isolated / minimal environment.
PreparedRetrieval manifests, SwiftData caches, and real-user-vault graph
state still need Instruments confirmation in the production app.

### Recommended follow-up

Run `Instruments → Allocations` on an idle-after-launch app, sort by
Persistent, and land targeted lazy-inits in the top 3 owners. Most
likely candidates (prioritized):

1. PreparedRetrieval manifest caches — only hold descriptors for the
   currently-selected model profile.
2. SwiftData `@Query` result caches in `NotesSidebar`, `ChatView`,
   `NoteTabView` — narrow predicates or `.fetchLimit(...)`.
3. Repeat the idle-after-local-model measurement in the user's normal
   app state (non-audit bundle) after a real note-search / tool turn so
   unified-memory pressure can be compared against the earlier ~500 MB
   report.

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
- `Epistemos/Engine/AgentHarness/ChatCapability.swift` — essay / draft
  verbs now classify as agent/tool intent alongside note wording.
- `Epistemos/App/ChatCoordinator.swift` — semantic note-lookups feed
  planner context and verified-read checks consistently.
- `Epistemos/Views/MiniChat/MiniChatView.swift` — model-aware mode
  sanitization, explicit Tools-path routing, and truthful Tools vs
  Thinking composer capability pill.
- `Epistemos/Graph/EmbeddingService.swift` — deferred lookup wrapper for
  large semantic embedding backends.
- `Epistemos/Graph/GraphState.swift` — graph bootstrap now defers Apple
  hybrid embedding construction until first use.
- `Epistemos/State/InferenceState.swift` — added
  `providerNativeCapabilityToolNameList(for:)`.

### Tests

- `EpistemosTests/RuntimeValidationTests.swift` — two new tests for the
  direct-stream manifest fix and the provider-native capability list.
- `EpistemosTests/ChatCapabilityIntentTests.swift` — essay / draft
  prompts now assert `.agent`.
- `EpistemosTests/TriageServiceTests.swift` — cloud note-seeking turns
  with resolved vault context and unresolved essay lookup both assert a
  managed-tools route.
- `EpistemosTests/MiniChatViewAuditTests.swift` — explicit Tools mode in
  Mini Chat now asserts a Tools pill instead of Thinking.
- `EpistemosTests/BlockEmbeddingTests.swift` — deferred embedding lookup
  stays cold until the first semantic access.
- `EpistemosTests/PipelineServiceTests.swift` — verified-read coverage
  for essay / draft phrasing and an updated direct-stream prompt
  expectation that matches the post-fix cloud manifest contract.

### Already-in-place from the prior session (commit blocks noted below)

- `Epistemos/Omega/Inference/ToolCallParser.swift` (fenced tool_call)
- `Epistemos/Engine/MetalRuntimeManager.swift` (releaseWorkingSet)
- `Epistemos/Engine/MLXInferenceService.swift` (async unload)
- `EpistemosTests/OmegaToolCallParserTests.swift`
- `EpistemosTests/LocalAgentLoopTests.swift`
- `EpistemosTests/Mamba2MetalRuntimeTests.swift`

### Additional hardening from the follow-up audit pass

- `Epistemos/App/ChatCoordinator.swift`
  - planner context now uses
    `hasAttachedUserContext || hasRequestedVaultLookup`
    when building the Overseer execution plan
  - `queryRequiresVerifiedVaultRead(_:)` now recognizes essay / draft
    read-rewrite-review phrasing in addition to note-only wording
- `EpistemosTests/TriageServiceTests.swift`
  - added `cloud note-seeking turns with resolved vault context escalate
    to a managed tools session`
- `EpistemosTests/PipelineServiceTests.swift`
  - added verified-read coverage for essay / draft phrasing
  - updated the direct-stream cloud prompt expectation so it matches the
    post-fix contract (capability manifest present, raw overseer JSON absent)
- `EpistemosTests/RuntimeValidationTests.swift`
  - added source-contract coverage for the new
    `plannerHasExplicitContext` wiring

## Additional verification and follow-up fixes (2026-04-22)

### Automated verification

```
./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/epistemos-runtime-finish \
  build
→ BUILD SUCCEEDED
```

```
cd graph-engine && cargo test
→ 2458 passed, 0 failed, 8 ignored
```

```
cd omega-mcp && cargo test
→ 126 passed, 0 failed
```

```
cd omega-ax && cargo test
→ 12 passed, 0 failed
```

```
./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/epistemos-runtime-finish \
  test \
  -only-testing:EpistemosTests/UserFacingModelOutputTests \
  -only-testing:EpistemosTests/LocalAgentLoopTests
→ 53/53 passed
Result bundle:
/Users/jojo/Downloads/Epistemos/build/xcode-results/2026-04-22-124231-16628.xcresult
```

The broader Swift sweep was also started:

```
./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/epistemos-runtime-finish \
  test
```

That run did not go green in the current worktree. Early failures appeared in
`CloudProviderAuthServiceTests` and `TriageServiceTests` before the run
continued through the suite, so the branch still does **not** have a clean
full-suite pass.

### Manual/runtime evidence

Fresh audit-app runtime checks on `Mini Chat` showed the main local blocker
resolved on the primary ship target (`Qwen 3 4B`):

- Prompt:
  `Use write_file to write exactly tool smoke ok to tmp/epistemos_live_tool_smoke_20260422_fix7.txt, then use read_file on that exact same path, and reply with only the file contents.`
- UI showed:
  `Write File … Finished`, `Read File … Finished`, final plain text
  `tool smoke ok`
- Tool DB evidence (`omega_executions.db` rows 15-16) confirmed the real
  `write_file` + `read_file` calls executed successfully on the requested path
- Logs showed the local repair path and synthetic explicit-file steps instead of
  the earlier stalled / unusable turn state

The in-app idle-memory check after local model use also looks materially better:

- `ps` RSS dropped from about `109 MB` to `55 MB` over roughly one minute of
  idle time after the tool run, which supports the MLX unload / deferred graph
  embedding fixes in the real app

Approval-gating verification is partially complete:

- forcing `vault_read` to `ask_first` surfaced the real `Allow read_file?`
  prompt in Mini Chat
- the deny **prompt** is real, but the deny **outcome** was not conclusively
  validated under automation because repeated button-driving attempts still
  ended in successful reads
- the authority file was restored to the original `auto_allow` state after the
  check

Cloud-tool manual validation is currently blocked by environment, not parser or
runtime behavior:

- the Mini Chat model/runtime popover reports `Cloud Provider — OpenAI • Account first`
- no connected cloud account is configured on this validation surface, so a
  truthful live cloud-tool round-trip could not be run here

### Follow-up fix for non-Qwen tool-capable local tiers

A second live manual check on `Gemma 3 4B` surfaced a different but related
coherence bug:

- the runtime selector honestly exposed `Tools` for `Gemma 3 4B`
- the same explicit file round-trip request produced raw fenced `xml` output
  instead of continuing the tool repair path
- logs captured the failure exactly:
  `Local agent repair turn summary — source=one-shot chars=7 visibleChars=6 toolCalls=0 hasFence=true preview=```xml`

Root cause:

- the shared user-facing output sanitizer treated a dangling fenced-language
  marker like `````xml```` as visible answer text, so the local agent loop
  returned that marker instead of treating the turn as still invisible and
  continuing the explicit-file repair / synthetic-step path

Patch:

- `Epistemos/Engine/Extensions.swift`
  - `UserFacingModelOutput.streamingVisibleText(from:)` and
    `finalVisibleText(from:)` now suppress dangling fenced-language markers
    such as `````xml```` / `````tool_call```` / `````json```` before they can
    leak into the visible answer stream
- `EpistemosTests/UserFacingModelOutputTests.swift`
  - added `final text drops dangling fenced-language markers without surfacing
    them raw`
- `EpistemosTests/LocalAgentLoopTests.swift`
  - added `reflex mode treats dangling xml fence repairs as invisible and
    continues the explicit file round-trip`

The focused regression pass above proves the exact live Gemma failure mode now
routes back into the synthetic explicit-file repair path in code/log terms.
However, the post-fix **manual** Gemma rerun could not be completed on the
patched audit bundle because the refreshed `Epistemos Audit` app relaunch did
not present a controllable window (logs showed a startup accessibility/request
oddity and `No windows open yet`), so the launcher/window issue remains a
separate validation blocker.

## Remaining risk

- The main local ship blocker (`Qwen 3 4B` live tool loop / raw output leak)
  now has real app evidence behind it, but the post-fix Gemma manual rerun is
  still blocked by the audit-bundle relaunch/window problem.
- The current worktree still does **not** have a green broad `xcodebuild test`
  pass. The full sweep started, but current-branch failures were already
  observed in `CloudProviderAuthServiceTests` and `TriageServiceTests`.
- Idle memory is profiled by description, not Instruments. The patch
  here is still bounded: `releaseWorkingSet()` plus deferred graph
  embedding construction and an audit-app RSS spot check. Unified-memory
  pressure in the user's real app state still needs Instruments.
- The approval deny-path prompt exists, but the deny result itself still needs
  a trustworthy manual human click-through instead of automation.
- Live cloud-tool validation is blocked on this machine until a cloud account
  is connected on the validation surface.
- The `additionalSystemPrompt` omission in direct-stream paths may hide
  overseer-plan route/summary context from Fast/Thinking turns. Chat
  behavior should stay identical because the manifest already carries
  provider / operating-mode / rules. If the summary is needed, a
  tool-free `additionalSystemPrompt` variant can be added later.
