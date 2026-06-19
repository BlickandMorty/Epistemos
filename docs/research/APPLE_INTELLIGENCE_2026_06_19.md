# APPLE INTELLIGENCE retention + foundational features (S18, 2026-06-19)

Read-only research (subagent), code-grounded. Feeds DEEP_PLAN_AUDIT_HUB. Owner: "keep it, maybe
for other foundational features." **Verdict: already substantially honored — Apple Intelligence is
NOT a stub; it's real, wired, availability-gated. The one honest gap is the RuntimeRouter lane.**

## What exists today (REAL + wired)
`AppleIntelligenceService.swift` (516-line `@MainActor` actor, `static shared`): real framework
(`#if canImport(FoundationModels)`, `SystemLanguageModel.default`, `LanguageModelSession`,
`session.respond`). **Honestly availability-gated** (`checkAvailability:477` → device-not-eligible /
not-enabled ["Turn it on in Settings"] / model-downloading / pre-macOS-26 throws). Production-hardened:
thermal gate, dedicated circuit breaker (`BreakerRegistry.foundationModels`), 10-min session recycle,
token-budget guard w/ summarize-and-recycle, context-window catch-retry, 30s timeouts, provenance
events; `AppleIntelligenceError` is breaker-neutral so unavailability never trips the breaker.
`AFMSerialGate` serializes all AFM generation (FoundationModels traps on concurrent respond). A 2nd
subsystem `AFMSessionPool` (actor) keeps warm sessions keyed by use-case for guided generation +
classifiers (`SystemLanguageModel(useCase:.contentTagging)`).

**Wired into real features (not just chat):** ontology classification (`OntologyClassifier` via
`@Generable`/`@Guide`), note summarize/weave-rewrite (NoteDetail), graph node summaries (inspectors +
local fallback), title/tag/entity/link sidecar (`AFMSidecarGenerator` `@Generable`), triage routing
(`.appleIntelligence` is a first-class TriageService route w/ trim + retry-with-local fallback), code-
editor transforms, **native macOS Writing Tools** (`WritingToolsBridge`), `LLMService` provider (+ the
default fallback when no usable local model), DeviceAgentService, and classifiers (IntakeValve,
ConversationStateClassifier, SessionTelemetryClassifier). Availability plumbed to
`InferenceState.appleIntelligenceAvailable`/`UnavailableReason` → RootView/TriageService.

## The one honest GAP: the RuntimeRouter lane is a stub-with-a-flag
`RuntimeLane.appleIntelligence` is in EVERY preferred-lane chain (first for `.quick`/`.trivial`,
`RuntimeRouter.swift:458-468`), capability deliberately narrow (`defaultStubCapability`: tier
`.currentApp`, contextWindow 4096, grammar [], toolCall `.none`, cost free, latency local). **But NO
real `RuntimeExecutor` is bound — only `StubRuntimeExecutor` (`:813-817`)** — the comment says "the
honest 'lane exists' signal." So AppleIntelligence is reached via `LLMService`/`TriageService` direct
calls, NOT the RuntimeRouter `execute()` path. The router gates it (escalates on tools/grammar/ceiling)
but can't actually RUN it. **This is the blue/L1-vs-T4-green gap: "lane exists" but "lane doesn't run."**

## Honest fit (2026 AFM 3 reality)
On-device = AFM 3 Core Advanced (~20B sparse, 1-4B active/req, **4096-token context**, on-device, free,
private) + guided generation (`@Generable`) + `Tool` protocol + `UseCase` adapters + new multimodal
image input. Frontier reasoner = Private Cloud Compute (32K, separate surface). **Honest fit: a fast,
free, private, ZERO-RAM short-context worker for summarize/extract/classify/title-gen/Writing-Tools +
guided structured output + small tool calls. NOT a frontier reasoner, NOT large context.** Epistemos
already maps onto this almost perfectly.

## Recommended foundational uses (✓=present, ○=gap)
✓ note/section summarization · ✓ title/tag/entity/link suggestion (@Generable) · ✓ quick classification
for routing/triage (.contentTagging) · ✓ Writing-Tools transforms. ○ **zero-RAM always-available lane**
(only lane consuming NO app model RAM — the correct cold-start free default; already LLMService fallback
but should be a real ROUTER executor) · ○ composer affordances (rephrase/concise/quick-reply) · ○
capture triage (classify QuickCapture intent on-device) · ○ multimodal image input (AFM 3) for graph
node/screenshot description (gated `#available` + eligibility).

## Composition + gating
Keep it ONE lane among MLX/GGUF/cloud — first for `.quick`/`.trivial`, late fallback for heavier roles
(free + zero-RAM but 4K/no-grammar). It's the zero-footprint FLOOR of the model stack (when
`hasUsableLocalTextModel==false`, LLMService falls to it = "always something local"). Gating already
correct (device/enabled/downloading/pre-26 distinguished; TriageService only routes when available;
breaker+thermal+serial gates make it safe; no fake capability exposed).

## NEVER route to it (no-fake/honest-routing)
Frontier reasoning / long agentic loops (1-4B worker, not Opus); large context (hard 4096 window —
router escalates on `estimatedInputTokens>contextWindow`); `agent`/`liveAgent` (local lane → never fake
agent capability — CLAUDE.md); anything needing guaranteed availability (keep local/cloud fallback at
every call site). For frontier/long-context the right answer is Private Cloud Compute (separate cloud-
tier lane, gated explicitly, NEVER silently behind the on-device lane).

## Ordered plan
1. **(S) Bind a real executor** `AppleIntelligenceRuntimeExecutor: RuntimeExecutor` wrapping
   `AppleIntelligenceService.shared.generate`, replacing the `.appleIntelligence` stub (`:813-817`) + an
   `F-AppleIntelligenceLane` falsifier → promotes blue/L1 → T4-green. *Highest leverage; everything else works.*
2. **(S)** Verify capability surface vs AFM 3 (read `SystemLanguageModel.contextSize` at boot vs the 4096 literal); keep `toolCallMode:.none` until a real Tool path.
3. **(M)** Add the `Tool` protocol path for small on-device tool calls (search-note/create-task) so `.quick`/`.trivial` micro-tasks stay local; bump to `.softGuidance` honestly (NOT `.native` agent).
4. **(M)** Composer + capture affordances via `@Generable`/AFMSessionPool (additive).
5. **(M-L)** Multimodal image input (AFM 3) for graph/screenshot description (gated). Lowest priority.
6. **(continuous)** Honesty audit — no UI advertises AI as agent-capable; lane escalates not fakes on ceiling/tool/long-context (per memory "audit existing claims first" — most already PASSes).

**Bottom line:** RETAIN it — already real, gated, wired into summarization/classification/title-gen/
Writing-Tools. Single honest gap = the RuntimeRouter lane is a stub-with-a-flag; bind a real executor
(step 1) and the owner's "foundational features" vision is largely already shipped.

Key files: `Engine/AppleIntelligenceService.swift` · `Engine/AFMSessionPool.swift` · `Engine/AFMSidecarGenerator.swift` · `Graph/OntologyClassifier.swift` · `Engine/TriageService.swift:1315/1529/2067` · `Engine/LLMService.swift:300-313/407-414` · `LocalAgent/RuntimeRouter.swift:452-468/813-850/925-933` · `Views/Notes/WritingToolsBridge.swift` · `State/InferenceState.swift:3334/3560`. Sources: Apple ML Research (AFM 2025 updates + 3rd-gen), WWDC26 sessions 241/339, SystemLanguageModel docs, 9to5Mac/MacStories (AFM 3 Core Advanced).
