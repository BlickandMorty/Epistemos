# Epistemos Release Synthesis for Next Session

Date: 2026-04-08

## North Star

The product goal is not just "an app with chat and models." The goal is a native, sovereign, high-performance AI workspace with:

- instant recall
- instant retrieval
- durable vault memory
- coherent local + cloud model switching
- real agentic tool use
- model-specific strengths actually expressed instead of flattened
- a UI that feels focused rather than overloaded

That is the right target. The remaining work is mostly about closing the gap between that architecture and the live, shippable product.

## Bottom Line

The app is **not release-ready yet**.

The biggest unfinished surface is exactly what you called out:

1. local model correctness, uniqueness, installability, and end-to-end validation
2. cloud model verification under real credentials
3. attachment/reference prompting so models actually use provided context correctly
4. code editor simplification and performance polish
5. graph interaction smoothness under real use
6. finishing Mamba/SSM in a way that is real, not just partially warmed

## What I Verified While Preparing This

I ran a fresh no-signing macOS build from the current branch state:

```bash
xcodebuild -quiet -project /Users/jojo/Downloads/Epistemos/Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO
```

It completed successfully.

That is useful, but it does **not** change the release verdict. The remaining unknowns are runtime behavior, model correctness, UX coherence, and release operations.

## Important Reality Check

Some of the attached notes describe an older or aspirational architecture where all local models run through an Ollama/OpenAI-compatible provider in `agent_core`.

That is **not** the live local path in this branch.

The current live architecture is:

- local models: `MLXInferenceService` + Swift pipeline
- local agent mode: `LocalAgentLoop`
- cloud/agent path: Rust `agent_core`

Relevant files:

- `Epistemos/State/InferenceState.swift`
- `Epistemos/Engine/MLXInferenceService.swift`
- `Epistemos/LocalAgent/LocalAgentLoop.swift`
- `Epistemos/App/ChatCoordinator.swift`

Next session should start from the live architecture, not from the outdated assumption that all local inference still depends on a missing Ollama provider.

## What Is Already There

These parts are meaningfully present in the codebase:

- a large expanded local model catalog in `Epistemos/State/InferenceState.swift`
- install descriptors for local models in `Epistemos/Engine/LocalModelInfrastructure.swift`
- model-specific metadata such as `supportsThinkingMode`, `supportsVision`, `canActAsAgent`, `isSSM`, `maxContextTokens`, temperatures, and tool tiers
- OpenAI as the default cloud provider and a local-only toggle flow
- Mamba visible in the app model surfaces
- SSM runtime metadata in `Epistemos/Engine/SSMRuntimeProfile.swift`
- partial custom Metal Mamba runtime scaffolding:
  - `Epistemos/Engine/Mamba2ForwardPass.swift`
  - `Epistemos/Engine/MetalRuntimeManager.swift`
  - `Epistemos/Shaders/Mamba2/`
- graph render-loop throttling/coalescing work in `Epistemos/Views/Graph/MetalGraphView.swift`
- code editor lifecycle/performance work in `Epistemos/Views/Notes/CodeEditorView.swift`

This matters because next session should not start by re-adding the catalog or rethinking the whole architecture. It should start by verifying, finishing, removing false edges, and simplifying the UX.

## Highest-Risk Remaining Issues

### 1. Local model validation is still not complete

The catalog is broad, but the release question is not "are the enum cases there?" It is:

- can every intended local model install cleanly
- can it load
- can it answer coherently
- does its thinking mode work when advertised
- does vision work when advertised
- does agent mode work when advertised
- does it handle attachments and referenced notes correctly
- does it use the runtime path we think it uses

Right now, that full sweep has not been completed.

### 2. The local model catalog still contains at least one knowingly suspect entry

`Epistemos/State/InferenceState.swift` currently includes:

- `gemma4_12B4Bit = "mlx-community/gemma-4-12b-it-4bit"`

and the code comment itself says:

- `DOES NOT EXIST on HuggingFace — Gemma 4 has no 12B variant`

That is a release blocker for catalog trustworthiness. The model menu cannot advertise entries that are knowingly fake, stale, or unresolvable.

### 3. Mamba/SSM is only partially "real" today

What is true right now:

- Mamba/SSM runtime metadata exists
- the MLX load path can warm custom Metal runtime preparation
- SSM state persistence work exists
- `ConversationPersistence` is partially wired through `ConversationPersistence.shared.bindSSMStatePath(...)` in `AppBootstrap.swift`
- the repo depends on a local MLX fork at `LocalPackages/mlx-swift-lm`
- that fork contains custom `extractKVCache()` / `injectKVCache()` support in `MLXLMCommon/ChatSession.swift`

What is not yet true:

- the custom Metal Mamba path is the sole or primary token-generation backend
- the SSD forward pass is fully integrated end to end
- the Mamba-specific benchmarks and correctness validations are complete

So Mamba is **present**, but the fully custom native path is still unfinished.

### 4. Attachment/reference prompting is still too weak

The current file attachment path in `Epistemos/App/ChatCoordinator.swift` mostly serializes attachments as:

- `Attached file: <name>`
- raw extracted text or a short fallback note

That is not enough for strong reasoning models, especially DeepSeek-style models that need a more explicit instruction contract.

What is still missing:

- a per-attachment "why this is attached" framing
- clear priority between user request and attachment content
- an explicit instruction to actually use attached materials when relevant
- better image/reference semantics for text-only vs vision-capable models
- a clean user-facing way to mark an attachment as required context vs optional context

This is one of the most important product-quality gaps left.

### 5. The code editor is still more complex than the desired product shape

The editor hot paths were improved, but the UI is still carrying a lot of AI surface area:

- insights sidebar
- related-notes sidebar
- AI Partner controls
- popover suggestions
- multiple inline/overlay response concepts

There is also one concrete mismatch already identified:

- the live path shows suggestions through popover UI
- the advertised inline ghost-text path is not clearly wired into the real editor flow

The code shows this clearly in `Epistemos/Views/Notes/CodeEditorView.swift`.

If the desired direction is "less bloated, more focused, less random insights," then the editor still needs a deliberate simplification pass.

### 6. The graph still needs a real feel test

There is meaningful render-loop work in `Epistemos/Views/Graph/MetalGraphView.swift`:

- double buffering
- interaction coalescing
- throttled publishes
- render-needed gating

That is good progress, but it is not equivalent to "the graph no longer stutters on your machine." The graph still needs a real manual zoom/pan/drag pass under live data.

### 7. Cloud validation is incomplete

OpenAI is now the default cloud path in the app, but you said you currently only have real access there.

That means:

- OpenAI can and should be fully tested next session
- Anthropic, Gemini, DeepSeek cloud, Kimi, Minimax, ZAI, and similar providers should be treated as unverified until exercised with live credentials

Release messaging must not overstate cloud readiness beyond what has actually been credential-tested.

### 8. Release operations are still incomplete

Even if models were perfect, release still requires:

- clean worktree freeze
- passing build/test pass from current HEAD
- signing
- notarization
- DMG packaging
- support/privacy metadata verification
- manual runtime smoke pass on the release artifact

This repo is still heavily dirty, with many modified and untracked files, including multiple audit docs and new runtime subsystems. That is not a frozen release state yet.

## Additional Known Audit Notes

- There is still at least one stray `Hermes` reference in `Epistemos/App/ChatCoordinator.swift`
- `Epistemos/Views/Notes/OutlineNavigatorView.swift` still has 6 `try!` regex initializers; they are static constant regexes, so they may be acceptable, but they should be consciously reviewed
- `DispatchQueue.main.sync` currently appears clean in production code; current grep only finds docs/audit references
- The known `TraceEvent` trace-collector collision/scoping issue should be treated as a real release audit item, not waved away

## The Real Pain Points to Focus on Next Session

### A. Local model truth pass

Do a full install-and-verify sweep for every intended local model.

For each model, validate:

1. install succeeds
2. install artifact is valid
3. model appears correctly in picker/settings
4. chat works
5. thinking mode works if advertised
6. agent mode works if advertised
7. tool permissions behave correctly
8. vision works if advertised
9. file attachment works
10. note/chat attachment works
11. long-context behavior is sane
12. output feels like the intended family, not generic mush

### B. Runtime-path truth pass

For each family, confirm the actual runtime path:

- Qwen / Gemma / DeepSeek / Qwopus / Qwen Coder / Devstral / Mistral / SmolLM:
  - expected primary path: MLX transformer path
- LFM / Falcon H1 / Jamba / Mamba:
  - expected primary path: SSM-aware MLX path
- Mamba:
  - currently only partial custom Metal integration; finish or clearly downgrade claims

### C. Attachment and context-contract fix

This should likely become its own explicit implementation pass.

Desired result:

- every attachment can optionally carry intent
- the prompt scaffolding makes the relationship explicit
- models understand whether the file is required, background, or optional
- referenced notes/chats are not just dumped into context without instruction

### D. Code editor simplification

Make a product call:

- if "insights" are core, keep them and make them calmer
- if "insights" are noise, remove or hide them behind advanced mode

The current editor still reads like a feature accretion surface instead of a single, sharp writing/coding tool.

### E. Graph feel pass

Do not rely on code-level optimism here. Open the real graph and test:

- pan latency
- zoom latency
- drag responsiveness
- selection stability
- hover responsiveness
- behavior on dense graphs

If it still drops frames, the render loop needs another focused pass.

### F. Cloud verification pass

Since OpenAI is the main advertised cloud now, validate it first:

- fast
- thinking
- pro
- agent
- file attachment
- note/chat references
- tool permission flow

Then expand only if you actually have credentials for the other providers.

## Concrete Next-Session Order

### Phase 1 — Freeze reality

Before any new feature work:

- remove or replace invalid model entries
- decide which local models are truly in-scope for release
- stop advertising anything that is not installable
- get one fresh build and test baseline from current HEAD

### Phase 2 — Install + validate all release-scope local models

Focus on the real shipping set, not every theoretical future model.

Suggested minimum release set:

- one tiny router-tier model
- one small general model
- one reasoning model
- one coding-specialist model
- one large frontier local model
- one SSM model
- one vision-capable local model

If more models pass, great. But ship quality matters more than raw count.

### Phase 3 — Attachment contract + prompt coherence

Implement the missing context scaffolding and retest:

- DeepSeek R1
- Qwen family
- Gemma family
- coding models

This is likely where a lot of the "the model ignored what I gave it" pain will actually get fixed.

### Phase 4 — Finish or scope down Mamba honestly

Pick one:

- finish the custom Metal Mamba forward path enough to call it real
- or keep MLX as the truth and stop marketing Mamba as fully custom-native

Right now it sits in between, which is the least stable position.

### Phase 5 — Simplify the code editor

Goal:

- fewer random insights
- fewer overlapping AI surfaces
- clearer primary actions
- better default calmness

### Phase 6 — Manual graph performance pass

Use real graphs, not synthetic confidence.

### Phase 7 — Cloud pass

Fully validate the providers you can actually access.

### Phase 8 — Release operations

- sign
- notarize
- package
- run the release artifact
- perform final manual check

## Strategic Big-Picture Work That Matters, But Should Not Block Core Release

These ideas are aligned with the product vision and worth pursuing, but they should not distract from the core release-critical path:

- vault/session-memory architecture
- contradiction detection
- knowledge graph growth across sessions
- skill evolution from traces
- richer NCP/MCP orchestration
- self-evolving model/persona/vault systems

They matter because they support the long-term "instant recall / instant retrieval / super high-powered AI workspace" vision.

But release quality for the current app still depends first on:

- trustworthy model menus
- trustworthy model behavior
- clean context handling
- smooth editor
- smooth graph
- honest release packaging

## Files to Revisit First Next Session

- `Epistemos/State/InferenceState.swift`
- `Epistemos/Engine/LocalModelInfrastructure.swift`
- `Epistemos/Engine/MLXInferenceService.swift`
- `Epistemos/Engine/SSMRuntimeProfile.swift`
- `Epistemos/Engine/Mamba2ForwardPass.swift`
- `Epistemos/Engine/MetalRuntimeManager.swift`
- `Epistemos/App/ChatCoordinator.swift`
- `Epistemos/LocalAgent/LocalAgentLoop.swift`
- `Epistemos/Views/Notes/CodeEditorView.swift`
- `Epistemos/Views/Graph/MetalGraphView.swift`
- `Epistemos/Views/Chat/ChatInputBar.swift`
- `Epistemos/Views/Chat/ComposerReferenceBrowser.swift`
- `Epistemos/Views/Settings/ModelVaultsSettingsView.swift`

## Final Recommendation

Next session should **not** begin with another broad architecture brainstorm.

It should begin with a strict release-focused execution loop:

1. clean the catalog
2. install and validate local models
3. fix attachment/context prompting
4. simplify the editor
5. manually validate graph feel
6. verify OpenAI cloud path
7. finish release packaging

That path is the shortest route from "huge ambitious system" to "shippable app that still points toward the bigger vision."
