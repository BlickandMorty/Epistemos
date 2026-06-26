# Chat Donor Fusion — Agent! vs Swarm Decision + Clone/Fusion Map

> **VERIFIED READ-ONLY against main 2026-06-24** — Epistemos macOS 26.0 / Swift 6.0 (language mode) / 6.2 (compiler/tools). No files mutated; donor paths under `/Users/jojo/Downloads/Epistemos/.research-clones/swift-act/`; Epistemos seams confirmed in-tree (`Epistemos/App/RootView.swift`, `Epistemos/Views/Approval/ApprovalModalView.swift`, `Epistemos/Views/Chat/ChatView.swift`, `Package.resolved` swift-syntax 600.0.1 / swift-sdk 0.12.1, four existing `XCLocalSwiftPackageReference` local refs in `Epistemos.xcodeproj/project.pbxproj`).

## 1. Purpose

This ledger is the **final donor-fusion authority** for building Epistemos's new **Chat** route from two primary Swift donors — **Agent!** (`agent-macos26`, MIT app shell) and **Swarm** (`swarm`, MIT Swift-6.2 agent/workflow framework) — plus four secondary donors. It records the **foundation decision** (visible shell vs engine substrate), an honest **clone/fusion map** for every fuse/defer/prune capability, the **prune list**, **alignment with the deletion-inventory ledger**, the **build order** for the new Chat route, and **open risks + license/trademark notes**. It does not authorize deletion of any existing Chat surface; deletion is gated by the replacement-proof checks in §6.

---

## 2. Honest Agent! vs Swarm comparison

| Aspect | **Agent!** (`agent-macos26`) | **Swarm** (`swarm`) |
|---|---|---|
| **Role we assign** | VISIBLE foundation (Chat app shell/chrome) + tool handlers + operational heuristics | ENGINE/substrate (agent loop, streaming events, tools, memory, guardrails, in-process provider seam) |
| **What it actually is** | Full native macOS 26 SwiftUI app — 166 Swift files, 9,874 LOC in `Views/`; single `WindowGroup` → flat `VStack` chat spine | Non-UI Swift-6.2 package, `.macOS(.v26)`, MIT (© 2025 Christopher Karani); 164 core files; ships **zero** app shell |
| **Strengths** | Already-flat native chrome (`.toolbar`/`ToolbarItemGroup`, `.popover`, `Color(nsColor:)`, `controlSize(.small)`, capsules); composition is verbatim a chat spine; rich capability surfaces (providers, MCP UI, tools, usage, rollback) | Typed `Sendable` `Agent`+`AgentRuntime.run()/stream()`; 5-namespace `AgentEvent` UI vocabulary; macro-free `FunctionTool`; clean one-type in-process seam `InferenceProvider` (`Core/AgentRuntime.swift:221`, methods `:228/:235/:244`); `SWARM_CORE_ONLY` excludes all cloud |
| **What we TAKE** | The scene + `ContentView` `VStack` spine + `InputSectionView` composer + toolbar/popover pattern + clean widgets (status pips, search bar, attachment tray, ToolSteps), reskinned; operational heuristics clean-room | The loop, `AgentEvent`, `InferenceProvider` seam + `EpistemosInProcessProvider`, `FunctionTool`/`@ToolBuilder`, integration-free Memory/Guardrails/Resilience/Observability |
| **What we DON'T** | Its `executeTask` loop (welded to a 37 KB `@MainActor AgentViewModel` god-object; untyped `[[String:Any]]` dicts; typed-tool/provider IP lives in **closed remote** `github.com/macOS26/Agent*` SPM packages **not MIT-granted**); CRT/phosphor HUD; launchd/XPC/iMessage/web-automation; cloud URLSession clients | Conduit cloud providers; FoundationModels fallback; `SwarmMCP`/`swift-sdk` stdio export; `SwarmOpenTelemetry`; durable Workflow (HiveCore); ContextCore/Wax default memory |

**Why the split (not Agent!-for-both, not Swarm-first-shell):** For the **visible** layer Agent! is a real, already-App-Store-shaped flat app whose only off-brief aesthetic is two CRT files — cheaper to reskin than to hand-build a shell on a UI-less Swarm. For the **engine** layer Agent!'s loop fails three structural tests (god-object coupling, untyped dicts, closed remote IP), while Swarm's loop is typed/`Sendable`/MIT-in-tree with a one-type seam that enforces NO-HIDDEN-SIDECAR. Rejected: (a) *Agent!-as-substrate* — its best engine IP is closed and its loop is inseparable from SwiftUI; it would also spawn a second Swift agentic loop beside Epistemos's Rust `agent_core`. (b) *Swarm-first native shell* — Swarm has no shell to clone; building one is pure cost.

---

## 3. FOUNDATION DECISION

### Visible foundation — Agent! shell, reskinned
Clone the `AgentApp` scene + `ContentView` `VStack` spine + `InputSectionView` composer + toolbar/popover pattern (`.research-clones/swift-act/agent-macos26/Agent/AgentApp.swift`, `Agent/Views/ContentView/ContentView.swift`, `Agent/Views/Input/InputSectionView.swift`, `Agent/Views/Header/HeaderSectionView.swift`). Reskin to Epistemos/OpenCode-minimal: shrink the 15-button toolbar to ~6–8 buttons, recolor tints to theme tokens, **drop the CRT/phosphor/scanline output look** (concentrated in `Agent/Views/Output/ThinkingIndicatorView.swift` `LLMOutputBox` + `Agent/Views/Output/LLMOutputTextView.swift`), keep the collapsible-thinking + `ToolStepsView` + context-budget-bar **mechanics** as flat components, rebrand every `Agent!`/`toddbruss` identity string, and rebind every view off `AgentViewModel` onto an Epistemos `ChatViewModel` driven by the engine below.

> **Superseding owner correction (2026-06-25):** The old ChatView visual language
> is the target feel, but the old Epistemos chat renderer/backend is not a
> reusable implementation. Deleted ChatView-era surfaces such as
> `MessageBubble`, `ChatInputBar`, `AssistantInlineTranscriptView`,
> `ProcessDisclosureViews`, `LiveActivityStrip`, `ThinkingPopoverView`, and
> `ThinkingTrailView`, plus dead wrappers like `AnswerPacketBadge` and
> `ChatBrainPickerMenu`, must not be restored. Rebuild the ChatView-2 feel from
> scratch inside the AgentClone/new Swift-agent foundation while preserving
> provider/tool/MCP/settings/session/history/rollback/usage reachability.

### Engine / substrate foundation — Swarm core-only
Adopt Swarm's typed loop/provider/tool spine: `Agent` + `AgentRuntime.run()/stream()` (`swarm/Sources/Swarm/Agents/Agent.swift`, `swarm/Sources/Swarm/Core/AgentRuntime.swift`), the 5-namespace `AgentEvent` vocabulary (`swarm/Sources/Swarm/Core/AgentEvent.swift`), macro-free `FunctionTool` closures (`swarm/Sources/Swarm/Tools/Tool.swift:1110`), `ParallelToolExecutor`, integration-free Memory/Guardrails/Resilience/Observability. Agent! contributes **tools + UI + operational heuristics only**, clean-room ported onto Swarm types — never its loop.

### The in-process `InferenceProvider` seam — NO HIDDEN SIDECAR
The seam is one type. Epistemos writes a single:

```
struct EpistemosInProcessProvider: InferenceProvider, CapabilityReportingInferenceProvider
```

whose `generate(prompt:options:)` + `stream(prompt:options:) -> AsyncThrowingStream<String,Error>` forward to `MLXInferenceService` (Swift) / `agent_core` Rust-FFI, advertising `capabilities = [.privateInference, .conversationMessages]`. Let `generateWithToolCalls` fall to the prompt-emulation default (`swarm/Sources/Swarm/Providers/TextOnlyConversationInferenceProviderAdapter.swift:42`) **or** override with Epistemos `LocalToolGrammar`. Register via the **explicit per-Agent `inferenceProvider` init** (preferred over `Swarm.configure(provider:)` to avoid cross-surface leakage).

**Honest NO-HIDDEN-SIDECAR statement (critic correction):** Core-only **excludes** the FoundationModels fallback (`#if SWARM_INTEGRATIONS`-gated in `DefaultInferenceProviderFactory.swift:13`, nil core-only) and all Conduit cloud providers, so Agent provider-resolution ends in `throw AgentError.inferenceProviderUnavailable` (`Agent.swift:1013/1053`) with **no FoundationModels default**. However, **`Swarm.cloudProvider` is a GLOBAL, not integration-gated** (checked at `Agent.swift:998/:1047`); it is nil **only if the app never sets it**. So NO-HIDDEN-SIDECAR holds **by construction *only if* we also leave `cloudProvider`/`defaultProvider` nil and always inject the explicit in-process provider** (see §8 risk). This is the precise, non-overclaimed guarantee.

### Concrete Swarm integration approach
- **Vendor core-only as a LOCAL package** `LocalPackages/Swarm` wired as `XCLocalSwiftPackageReference` + `XCSwiftPackageProductDependency` by **hand-editing `project.pbxproj`**, mirroring the four existing local refs (GGUFRuntimeBridge / OsaurusCore / SwiftTerm / vmlx-swift — verified at `pbxproj:715-718`). **Do NOT run xcodegen** (wipes `DEVELOPMENT_TEAM=3BNL2669SL` + dev signing); synchronized folders (12 `PBXFileSystemSynchronizedRootGroup`) auto-include new files.
- **Trim the vendored sources:** copy `Sources/Swarm` **minus** the 22 core-only-excluded files (Providers/Conduit, Integration/Wax+Membrane, Internal/GraphRuntime, `ContextCoreMemory.swift`, `DefaultAgentMemory.swift`, Workflow durable engine+checkpoint files, Tools/Web) + `Sources/SwarmMacros`, with a **trimmed `Package.swift` that hard-locks core-only**: delete the Wax/Conduit/ContextCore/Membrane deps **and remove the `integrationTrait`** — which is what transitively excludes **Hive** (critic gap: Hive is **not** in `swarmCoreOnlyExcludes`; it is gated behind `integrationTrait` at `Package.swift:58/78`, so dropping the trait is the correct concrete action). Also delete the Anthropic/OpenAI/Conduit provider source files so no cloud provider can ever be a hidden default.
- **macOS-26 match:** exact — Swarm `.macOS(.v26)` == Epistemos 12-site `MACOSX_DEPLOYMENT_TARGET = 26.0`.
- **Swift 6.0 app consuming 6.2-tools package:** proven — OsaurusCore (`swift-tools-version: 6.2`) already builds in this graph; tools-version governs the package build, not the app language mode.
- **swift-syntax / SwarmMacros (UNAVOIDABLE):** core itself uses `@Tool` (`Tools/ZoniSearchTool.swift:29`, `Tools/SemanticCompactorTool.swift:17`) so `SwarmMacros` → swift-syntax compiles even core-only; you cannot `FunctionTool`-your-way-out. Vendor as a stable local package that builds-once-and-caches.
- **MCP swift-sdk version collision = NONE:** workspace already resolves `swift-sdk 0.12.1` (verified via OsaurusCore); Swarm pins `from 0.12.1` — compatible. **STRIP the `SwarmMCP` product** (the **only** thing pulling the `MCP` module into Swarm's subgraph — `import MCP` appears solely in `Sources/SwarmMCP/*`, sole `.product(name:"MCP",…)` at `Package.swift:142`). Epistemos already hosts MCP via the Rust `omega-mcp` crate (`-lomega_mcp`) and Swarm-core ships a Foundation-only MCP client; do not introduce a third MCP stack. Also strip `SwarmOpenTelemetry`.
- **swift-syntax 600.0.1 prebuilt landmine:** Swarm's `Package.swift:21-34` warns 600.0.1 ships a broken MacroSupport prebuilt; Epistemos resolves **exactly** 600.0.1 (verified `Package.resolved` swift-syntax 600.0.1). Do a clean SPM resolve+build **before committing**; if `Unable to find module dependency: SwiftSyntax` appears, bump the shared floor to 601.x (Swarm's `600.0.0..<603.0.0` allows it — verify OsaurusCore tolerates 601).
- **Stream-buffer reskin:** apply `.unbounded` → `.bufferingNewest(256)` at `Agent.swift:535` and `Workflow.swift:495` (`StreamHelper.makeStream` already supports the bounded policy at `:51`) per CLAUDE.md.
- **FFI Sendable discipline:** `EpistemosInProcessProvider` must be `Sendable`; marshal UniFFI callbacks via `DispatchQueue.main.async`, **never `.sync`**.

---

## 4. CLONE/FUSION MAP

> Status for every row starts **`inventoried`**. Lifecycle: `inventoried → cloned → reskinned → wired → verified`. Donor roots abbreviated: `agent-macos26 = .research-clones/swift-act/agent-macos26`, `swarm = .research-clones/swift-act/swarm`.

### VISIBLE — Agent! shell/UI

| Donor feature | Donor file(s) | Epistemos destination | Reusability | Status | F/D/P | Gaps / risks |
|---|---|---|---|---|---|---|
| App scene + menu commands | `agent-macos26/Agent/AgentApp.swift` | Chat root scene + Epistemos main-menu commands | reskin | inventoried | fuse | Rebrand bundleID `Agent.app.toddbruss` + drop `Agents` NSMenu; **REMOVE** `.task` MCP auto-start + FoundationModels prewarm (hidden-sidecar) |
| `ContentView` `VStack` spine | `agent-macos26/Agent/Views/ContentView/ContentView.swift` | Chat container/spine ordering | reskin | inventoried | fuse | Tightly bound to `AgentViewModel`; rebind to `ChatViewModel`; dedupe duplicate Cmd+B/D handlers |
| Keyboard shortcut layer | `…/Views/ContentView/ContentView.swift`, `…/KeyboardShortcuts.swift` | Chat keymap (run/cancel/search/new-tab/clear/history) | adapt | inventoried | fuse | Hard-coded keyCodes brittle; dead-code dup blocks; prefer `.onKeyPress` on macOS 26 |
| Toolbar (left status + right popover group) | `…/Views/Header/HeaderSectionView.swift` | Trimmed Chat toolbar (~6–8 buttons) | reskin | inventoried | fuse | Each button drags a subview+service tree; pick minimal subset; recolor to theme |
| Status pips (dot + pulse ring) | `…/Views/Header/StatusDotView.swift`, `…/Views/Shared/PulseRingView.swift` | Reusable status pip | direct-reuse | inventoried | fuse | Recolor only |
| Running-task banner | `…/Views/Header/TaskBannerView.swift` | Streaming strip above transcript | reskin | inventoried | fuse | Recolor; drop Apple-AI sub-row |
| Input composer | `…/Views/Input/InputSectionView.swift` | Chat composer (field/run/clear/cancel/drop/paste-chips/suggestions) | reskin | inventoried | fuse | Rewire dictation+screenshot to Epistemos services; **drop `Agent!` wake word**; flatten rounded cards; **Epistemos-side reuse target `ChatInputBar` is shared-in-flux — reuse READ-ONLY until Work commits** |
| Search bar (find-in-transcript) | `…/Views/Input/SearchBarView.swift` | Cmd+F find bar | direct-reuse | inventoried | fuse | None significant |
| Screenshot/attachment tray | `…/Views/Output/ScreenshotPreviewView.swift` | Multimodal attachment tray | direct-reuse | inventoried | fuse | Only when vision input enabled |
| Shimmer + ToolSteps (flat) | `…/Views/Shared/ShimmerText.swift`, `…/Views/Output/ThinkingIndicatorView.swift` | Flat "agent working" / tool timeline | reskin | inventoried | fuse | Re-type `ToolStep` onto Epistemos tool events; **drop CRT** |
| Tab bar (capsule tabs) | `…/Views/Tabs/TabBarView.swift` | Multi-session tabs | reskin | inventoried | fuse | Detach from 17-provider enum; keep drag/close/select/tint |
| Project-folder / CWD selector | `…/Views/Input/ProjectFolderSectionView.swift`, `…/ProjectFolderField.swift` | Vault/CWD selector | adapt | inventoried | defer | Only when Chat drives a code/work agent; respect MAS sandbox + security-scoped bookmarks |
| Token badge + 7-day usage popover | `…/Views/Header/TokenBadge.swift` | Chat token/cost meter | reskin | inventoried | defer | Back with Epistemos usage store; depends on donor `TokenUsageStore` |
| History popover (rerun) | `…/Views/Tools/HistoryView.swift` | Recent-prompt rerun | reskin | inventoried | defer | Re-source from Epistemos chat store |
| Dependency/readiness splash | `…/DependencyChecker/DependencyOverlayView.swift`, `…/DependencyChecker.swift` | First-run/engine-readiness splash | reskin | inventoried | defer | Swap checks to MLX/engine/vault readiness; rebrand + drop startup sound |
| New-provider sheet | `…/Views/Tabs/NewMainTabSheet.swift` | "New chat with model" sheet | reskin | inventoried | defer | Collapse 17-cloud enum → in-process MLX + owner-gated providers |
| Tools toggle UI | `…/Views/Tools/ToolsView.swift` | Tool-enablement UI | adapt | inventoried | defer | Reuse `FlowLayout`/group UI; remap catalog to Epistemos Rust tool registry |
| Activity-log transcript | `…/Views/ActivityLog/ActivityLogView.swift` (+8 siblings) | Transcript renderer | adapt | inventoried | defer | **HIGH**: depends on missing `AgentTerminalNeo`/`AgentColorSyntax`; xcode:// shells out (MAS-hostile); **prefer Epistemos-native NSTextView/Halo stack** |

### ENGINE — Swarm substrate

| Donor feature | Donor file(s) | Epistemos destination | Reusability | Status | F/D/P | Gaps / risks |
|---|---|---|---|---|---|---|
| `Agent` + `AgentRuntime` loop | `swarm/Sources/Swarm/Agents/Agent.swift`, `…/Core/AgentRuntime.swift` | Chat engine core | adapt | inventoried | fuse | Strip FoundationModels fallback; leave `cloudProvider` nil; 3,109-line audit surface |
| `AgentEvent` 5-namespace stream | `swarm/Sources/Swarm/Core/AgentEvent.swift` | UI source of truth | direct-reuse | inventoried | fuse | `.thinking`→reasoning block; default-case `.handoff` |
| `InferenceProvider` seam + `EpistemosInProcessProvider` | `swarm/Sources/Swarm/Core/AgentRuntime.swift:221` (`:228/:235/:244`) | In-process MLX/Rust bridge | direct-reuse | inventoried | fuse | Forward stream tokens immediately; advertise `.privateInference` |
| Prompt-emulation tool-call adapter | `swarm/Sources/Swarm/Providers/TextOnlyConversationInferenceProviderAdapter.swift:42` | Template for provider | reskin | inventoried | fuse | Prefer `LocalToolGrammar` override for robustness |
| `FunctionTool` + `@ToolBuilder` | `swarm/Sources/Swarm/Tools/Tool.swift:1110`, `…/Tools/ToolParameterBuilder.swift` | Chat tools (macro-free) | direct-reuse | inventoried | fuse | Handlers call Epistemos services; macro avoided for app tools |
| `ParallelToolExecutor` | `swarm/Sources/Swarm/Tools/ParallelToolExecutor.swift` | Parallel tool calls | direct-reuse | inventoried | fuse | Cancellation-aware |
| `AgentConfiguration` + observer/StreamHelper | `swarm/Sources/Swarm/Core/AgentConfiguration.swift`, `…/Core/StreamHelper.swift` | Loop config + stream bridge | direct-reuse | inventoried | fuse | `enableStreaming=true` REQUIRED; `.unbounded`→`.bufferingNewest(256)` at `Agent.swift:535` |
| Integration-free Memory + `Session` | `swarm/Sources/Swarm/Memory/{ConversationMemory,SlidingWindowMemory,Session}.swift` | Transcript/session bridged to GRDB/SDChat | direct-reuse | inventoried | fuse | Bridge `any Session` to Epistemos persistence |
| Guardrails pipeline | `swarm/Sources/Swarm/Guardrails/*` | Input/output/tool guard layer | direct-reuse | inventoried | fuse | Pure Foundation; pull Core types alongside |
| Resilience (CircuitBreaker/Retry/Fallback/RateLimiter) | `swarm/Sources/Swarm/Resilience/*` | Inference + tool resilience | direct-reuse | inventoried | fuse | Constrain fallback to owner-approved providers only |
| Observability (Tracer/Metrics/OSLogTracer) | `swarm/Sources/Swarm/Observability/*` | Run telemetry rows | direct-reuse | inventoried | fuse | Keep OSLogTracer; drop SwiftLogTracer for zero extra dep |
| Workflow DAG (`.step/.parallel/.route/.repeatUntil/.fallback`) | `swarm/Sources/Swarm/Workflow/Workflow.swift` | Agent pipelines | adapt | inventoried | defer | Major capability, off first Chat screen |
| Durable Workflow checkpoint/resume | `swarm/Sources/Swarm/Workflow/Workflow+Durable.swift`, `…/WorkflowDurableEngine.swift` | Resumable runs | adapt | inventoried | defer | Re-home onto GRDB/provenance, NOT HiveCore/Wax |
| Vector/Hybrid/Summarizer RAG | `swarm/Sources/Swarm/Memory/{VectorMemory,HybridMemory,Summarizer}.swift` | RAG over vault | adapt | inventoried | defer | Wire to Halo/Shadow embeddings + in-process summarizer, never cloud |
| `PersistentMemory` backend protocol | `swarm/Sources/Swarm/Memory/PersistentMemoryBackend.swift` | `GRDBMemoryBackend` | adapt | inventoried | defer | Implement GRDB conformance; do NOT ship SwiftDataBackend |
| MultiProvider prefix routing | `swarm/Sources/Swarm/Providers/MultiProvider.swift` | Model selection | adapt | inventoried | defer | Only once >1 owner-gated provider exists |
| ToolCallStreaming providers | `swarm/Sources/Swarm/Providers/ToolCallStreamingInferenceProvider.swift` | Live tool-arg deltas | study-only | inventoried | defer | Needs local engine partial-tool-call surface |
| `AgentWorkspace` AGENTS.md/SKILL.md | `swarm/Sources/Swarm/Workspace/AgentWorkspace.swift` | Swift-side skills layout | adapt | inventoried | defer | Only if distinct from Rust skill path |

### HEURISTICS — Agent! → clean-room onto Swarm/Rust types

| Donor feature | Donor file(s) | Epistemos destination | Reusability | Status | F/D/P | Gaps / risks |
|---|---|---|---|---|---|---|
| `action_not_performed` false-action guard | `agent-macos26/Agent/AgentViewModel/TaskExecution/TaskExecution.swift:326-341` | Turn-finalize honesty guard | clean-room | inventoried | fuse | Inject as **text** block, NOT synthetic `tool_result` (Anthropic 400s) |
| Tiered on-device compaction + circuit breaker | `…/AgentViewModel/Messages/Compression.swift` | Compaction pre-pass | clean-room | inventoried | defer | `SystemLanguageModel.tokenCount` macOS-26.4-gated; ~4 chars/token fallback; don't double-compact vs Rust `compaction.rs` |
| Overnight coding guards | `…/TaskExecution/Guards.swift` | Long-run guard layer | clean-room | inventoried | defer | Generalize Xcode-build specifics |
| Token-budget diminishing-returns | `…/TaskExecution/TaskExecution.swift`, `…/Services/TokenUsageStore.swift` | Loop budget rail | clean-room | inventoried | defer | Source live pricing |
| Sub-agent mailbox + notification XML | `…/AgentViewModel/Features/SubAgent.swift` | Multi-agent fan-out | adapt | inventoried | defer | Re-home onto Swarm Handoff/`Workflow.parallel` |
| Parallel read-only batching | `…/TaskExecution/ToolBatch.swift` | Tool executor partition | adapt | inventoried | defer | Route shell through hardened subprocess (Rust `security.rs`), never raw `Process` |
| FallbackChain recover-to-primary | `…/Services/FallbackChainService.swift` | Onto Swarm Resilience | clean-room | inventoried | defer | Respect owner-gated provider rule |
| `SFSpeechRecognizer` dictation | `…/AgentViewModel/Features/Speech.swift` | Composer mic button | reskin | inventoried | defer | Configurable wake word (not `Agent!`); needs usage-string entitlement |

### SECONDARY donors (A7)

| Donor feature | Donor file(s) | Epistemos destination | Reusability | Status | F/D/P | Gaps / risks |
|---|---|---|---|---|---|---|
| `ContentFragmentBuffer` + `TokenUsage` value types | `swiftagent-swiftedmind/Sources/SwiftAgent/Helpers/ContentFragmentBuffer.swift`, `…/Models/TokenUsage.swift` | Token accumulation + usage meter | direct-reuse | inventoried | fuse | MIT clean; near dependency-free |
| `Adapter` protocol seam | `swiftagent-swiftedmind/Sources/SwiftAgent/Protocols/Adapter.swift` | Alt provider seam | reskin | inventoried | defer | Swarm `InferenceProvider` already covers MVP; prune bundled cloud adapters |
| Transcript/ToolRun/AgentSnapshot model | `swiftagent-swiftedmind/Sources/SwiftAgent/Models/{Transcript,ToolRun,AgentSnapshot}.swift` | Transcript domain model | adapt | inventoried | defer | FoundationModels-coupled; only if decoupling worth it |
| Foundation Lab on-device chat patterns | `foundation-models-framework-example/Foundation Lab/ViewModels/ChatViewModel.swift` | Study-only UX (gating/sampling/voice) | study-only | inventoried | defer | Uses FoundationModels, not MLX/Rust |
| MCP swift-sdk | `mcp-swift-sdk/Sources/MCP/*` | Already pinned 0.12.1 | direct-reuse | inventoried | prune | Reference only; do NOT vendor a second copy |
| 1amageek permission grammar / Skills | `swiftagent-1amageek/Sources/SwiftAgent/Security/*`, `…/SwiftAgentSkills/*` | Act/Work motif | study-only | inventoried | defer | **LICENSE GATE FAILURE — no LICENSE file; study-only/clean-room** |

---

## 5. PRUNE list (with reasons)

| Pruned | Donor file(s) | Reason |
|---|---|---|
| Root+user XPC LaunchDaemon/LaunchAgent shell-exec | `agent-macos26/AgentHelper/*`, `AgentUser/*`, `Shared/DaemonCore.swift` | **App-Store-FATAL**: SMAppService root daemon + `/bin/zsh -c` violates MAS sandbox + hardened runtime + no-subprocess |
| iMessage send + monitor | `…/AgentViewModel/NativeToolHandlers/Conversation.swift`, `…/SDEFs/Messages.json` | Automation + Full-Disk-Access to `chat.db`; MAS-incompatible; Epistemos has Pro-side `IMessageDriverService` |
| Green-phosphor CRT/scanline HUD | `…/Views/Output/ThinkingIndicatorView.swift` (`LLMOutputBox`/`ScanlineOverlay`), `…/LLMOutputTextView.swift` | Exactly the off-brief stock chrome the reskin forbids (keep ToolSteps/context-bar mechanics only) |
| xcode:// link + in-app compile queue | `…/Views/ActivityLog/ActivityLogView.swift`, `…/Services/ScriptService.*` | `NSAppleScript`+`Process(/usr/bin/xed)` subprocess/automation conflicts with MAS/hardened-runtime |
| Services/Messages popover surfaces | `…/Views/Header/ServicesPopover.swift`, `…/Views/Output/MessagesView.swift` | launchd lifecycle + iMessage allowlist; out of Chat scope (keep popover-shape as template only) |
| Selenium/AppleScript web automation | `…/Services/WebAutomationService.*`, `…/TabHandlers/Selenium.swift` | Automation + external WebDriver subprocess; Epistemos owns AX via AXorcist/DeviceAgentService |
| Closed remote SPM packages | `AgentTools/AgentLLM/AgentMCP/AgentD1F/AgentAccess/AgentTerminalNeo/AgentColorSyntax` (github.com/macOS26/*) | **NOT MIT-granted** by the clone; provider enum/registry/tool-schema/renderer are study-only; clean-room only |
| Cloud URLSession clients | `…/Services/{ClaudeService,OpenAICompatibleService,OllamaService,CodexService}.swift` | Hidden-cloud-default forbidden; Epistemos owns Claude SSE+caching in Rust `agent_core/providers/claude.rs` (study edge-cases only) |
| md/JSONL Memory+Skills+Session + Swift sub-agents | `…/Services/{MemoryStore,SkillsService,SessionStore}.swift` | Would FORK Epistemos's richer Rust `agent_core` memory/skills; keep only user-editable-md UX idea |
| AppleIntelligence/FoundationModels as provider | `…/Services/{AppleIntelligenceMediator,FoundationModelService}.swift` | First local lane is MLX/Rust, not FoundationModels; avoid parallel inference path |
| Swarm Providers/Conduit | `swarm/Sources/Swarm/Providers/Conduit/*` | External Conduit package + network defaults; delete provider source so no cloud can be hidden default |
| Swarm `SwarmMCP` product + stdio export | `swarm/Sources/SwarmMCP/*` | Sidecar-shaped + redundant with Rust `omega-mcp` + Swarm-core Foundation-only MCP; sole swift-sdk MCP puller — strip target (lift only ToolMapper/ValueMapper if ever needed) |
| Swarm `SwarmOpenTelemetry` | `swarm/Sources/SwarmOpenTelemetry/*` | Avoids opentelemetry-swift pull; OSLogTracer/MetricsCollector cover telemetry |
| FoundationModels fallback + `cloudProvider` seam | `swarm/Sources/Swarm/Providers/DefaultInferenceProviderFactory.swift` | Hidden-default risk; leave `cloudProvider` nil, always pass explicit provider |
| mcp-swift-sdk as separate donor | `mcp-swift-sdk/*` | Already pinned 0.12.1; second copy = version-skew; reference-only |
| 1amageek source verbatim | `swiftagent-1amageek/*` | **LICENSE GATE FAILURE** (README claims MIT, no LICENSE file); study-only/clean-room |
| swiftedmind OpenAI/Anthropic sessions | `swiftagent-swiftedmind/Sources/.../OpenAISession`, `AnthropicSession` | Cloud URLSession sidecars (`api.anthropic.com`); fuse only Adapter protocol + value types |

---

## 6. Alignment with the deletion-inventory ledger (new-chat-target seams)

The new Chat route must land on the seams the deletion-inventory ledger (`CHAT_DELETION_INVENTORY_AND_NEW_ROUTE_PLAN_2026_06_24.md`) already identified. Verified against main:

- **`WorkspaceModeKind .chat`** — the landing → mode entry point lives in `Epistemos/App/RootView.swift`, `Epistemos/Views/Landing/WorkspaceModeSelection.swift`, `Epistemos/Views/Landing/ModeEntryTransition.swift`. The new Chat route is the `.chat` mode target.
- **`HomeRouter`** — routing in `Epistemos/App/RootView.swift`; the Chat scene mounts behind `HomeRouter`, replacing the old `ChatView`/v1/v2 dispatch.
- **Recents/history persistence** — the old `ChatCoordinator.persistChatCompletion`
  seam is deleted. The rebuilt AgentClone/fusion Chat must provide a new
  Epistemos-owned persistence bridge to `SDChat`/recents without restoring the
  old coordinator.
- **`InferenceProvider` adapter** — `EpistemosInProcessProvider` (the §3 seam) is the single adapter mapping Swarm's loop onto the in-process MLX/Rust engine; no Swift Anthropic/OpenAI SDK is introduced.

**Superseded historical blockers from the pre-deletion ledger:**
1. **`RustAgentBridge.resolveApproval`** referenced at `Epistemos/Views/Approval/ApprovalModalView.swift` is **comment-only / does not exist** — the new approval flow must wire to the real `onResolve`/`PendingApproval` resolver.
2. **ACT migration block** — superseded. `ChatView`/`ChatState` are deleted and
   Chat/Act route through the protected AgentClone/fusion surface.
3. **Shared-in-flux files** — `EpistemosApp.swift`, `ChatTypes.swift`,
   `ThreadState.swift`, `ComposerCurrentAccessPlan.swift`, and
   `VaultSyncService.swift` may still have live uncommitted edits; protected
   `Epistemos/Work/**` remains out of scope. `ChatInputBar.swift` is now a
   deleted old surface and must not be restored.

---

## 7. Build order for the new Chat route (maps to owner implementation loop 5–6)

**Loop step 5 — landing → new Chat (scene up, engine wired):**
1. Vendor `LocalPackages/Swarm` (core-only, trimmed `Package.swift` with `integrationTrait` removed → excludes Wax/Conduit/ContextCore/Membrane/Hive); hand-edit `project.pbxproj` (mirror existing local refs). Clean SPM resolve+build **before commit** (swift-syntax 600.0.1 landmine check).
2. Implement `EpistemosInProcessProvider: InferenceProvider, CapabilityReportingInferenceProvider` forwarding `generate`/`stream` to MLX/Rust-FFI; `capabilities=[.privateInference,.conversationMessages]`; leave `Swarm.cloudProvider`/`defaultProvider` nil; inject per-Agent.
3. Add `WorkspaceModeKind .chat` → `HomeRouter` route mounting the new Chat scene (clone `AgentApp` scene + `ContentView` `VStack` spine, rebound to `ChatViewModel`). Remove Agent! `.task` MCP auto-start + FoundationModels prewarm.
4. Apply `.bufferingNewest(256)` reskin at `Agent.swift:535` / `Workflow.swift:495`.

**Loop step 6 — prompt / stream / transcript / cancel / tool-events / picker / recents:**
5. **Prompt**: wire composer (reskinned `InputSectionView` shape, but reuse Epistemos `ChatInputBar` READ-ONLY) → `agent.stream(input, session:)` with `enableStreaming=true`.
6. **Stream + transcript**: subscribe to `AgentEvent` — `.output(.token)`→bubble, `.output(.thinking)`→reasoning block, `.lifecycle(.completed)`→finalize; render via **Epistemos-native transcript stack** (not Agent! `ActivityLogView`).
7. **Cancel**: bind cancel button → `agent.cancel()` (run-scoped UUID/Task).
8. **Tool-events**: render `.tool(.started/.completed/.failed)` as flat ToolSteps chips (reskinned from `ToolStepsView`); register Chat tools as `FunctionTool` closures.
9. **Picker**: collapse `NewMainTabSheet` to in-process MLX + owner-gated providers.
10. **Recents**: persist via `persistChatCompletion`; read `recentChatsDescriptor`.
11. **Then delete old** — only after the new surface is live AND the §6 blockers clear: resolve the comment-only `RustAgentBridge.resolveApproval`, migrate ACT off `ChatView(actUsesOsaurus:true)`, extract private primitives, confirm shared-in-flux Work files are committed. Run the replacement-proof gate before removing `ChatView`/v1/v2.

---

## 8. Open risks + license / trademark notes

**Build / integration risks**
- **swift-syntax 600.0.1 prebuilt landmine** (highest build-blocking risk): Epistemos resolves exactly 600.0.1 (`Package.resolved` verified); Swarm core's `@Tool` forces `SwarmMacros`→swift-syntax. Clean resolve+build before commit; if `Unable to find module dependency: SwiftSyntax`, bump shared floor to 601.x (Swarm range allows; verify OsaurusCore tolerates).
- **Macro-plugin build cost** on disk-capacity-constrained machine: `SwarmMacros` compiles swift-syntax from source (minutes, memory-heavy). Vendor as stable local package so it caches; avoid re-resolves.
- **`NO HIDDEN SIDECAR` is conditional, not absolute**: holds only if the app leaves `Swarm.cloudProvider`/`defaultProvider` nil (global, not integration-gated at `Agent.swift:998/:1047`) and always injects the explicit in-process provider. Verify no `#if SWARM_INTEGRATIONS` path is accidentally enabled by the trimmed `Package.swift`; consider patching `resolvedInferenceProvider` to throw.
- **Double-loop / double-compaction**: Epistemos already runs Rust `agent_core::agent_runtime` + `LocalAgentLoop` + `compaction.rs`. Define the boundary — Swift loop drives UI/tools, Rust owns inference + heavy compaction — so we don't ship two orchestrations or compact twice.
- **Strict-concurrency at FFI seam**: `EpistemosInProcessProvider` must be `Sendable`; UniFFI callbacks via `DispatchQueue.main.async` never `.sync`. Agent! `@MainActor`/`[[String:Any]]` heuristics rewritten against Sendable typed state, not ported verbatim.
- **Transcript renderer unresolved**: Agent! `ActivityLogView` depends on missing `AgentTerminalNeo`/`AgentColorSyntax`; Epistemos already has a streaming NSTextView/Halo/ProseEditor stack likely the better base. Evaluate fuse-Epistemos-native vs reskin before committing — do NOT assume `ActivityLogView` is droppable-in.
- **tiered-compaction macOS gate**: `SystemLanguageModel.tokenCount`/FoundationModels gated to macOS 26.4+; deploy floor is 26.0 — ensure graceful ~4 chars/token fallback.
- **Old-Chat deletion replacement-proof**: gated on the §6 blockers (comment-only `resolveApproval`, ACT migration, shared-in-flux Work files). Check the topic ledger + `git status` first.

**License / trademark notes**
- **`Agent!` name is RESERVED** — reuse **MIT SOURCE only**, never the name/logo. Full identity sweep before shipping: `Agent!` strings, `Agents` NSMenu, `AgentIcon`, bundleID `Agent.app.toddbruss`, startup sound, `AGENT! >` prompt, the hardcoded `Speech.swift` wake word, and plist/Mach-service labels. Easy to miss the wake word and Mach-service labels.
- **Closed-package IP gap**: `AgentTools.claudeFormat`/`Tool.Group`/`APIProvider`/`AgentLLM`/`AgentMCP` are NOT in the checkout and NOT MIT-granted (closed `github.com/macOS26/Agent*`). Any heuristic/tool-schema port is **clean-room** against Epistemos's Rust tool registry — never lifted.
- **Swarm** = MIT (© 2025 Christopher Karani), no `Agent!` branding; keep the MIT LICENSE+copyright in the vendored copy. **swiftedmind** = MIT (clean), fuse Adapter protocol + value types only. **mcp-swift-sdk** = Apache-2.0 (clean), already pinned — do not re-vendor. **Foundation Lab** = MIT (clean), study-only. **1amageek** = **LICENSE GATE FAILURE** (README claims MIT, no LICENSE file) — study-only/clean-room, do not copy source verbatim.

---

## 9. CURRENT-STATE GAP DELTA — deep check 2026-06-25 (Chat = full Agent! clone, owner re-tasking)

Owner direction strengthened (2026-06-25): Agent! = the FULL visible Chat clone, made Epistemos (rebrand + flat OpenCode/Epistemos reskin, theme-aware multi-theme + custom tokens), PRESERVE ALL capabilities, integrate ALL non-Agent! Swift donors, HARDEN streaming/parsing + the "what it's doing" activity UI. Forever loop. Read-only inventory (workflow wym2x1v5k, 5 finders) result:

REALITY: `LocalPackages/AgentClone` is a VERBATIM full-source copy of Agent! (166 donor files 1:1 + EpistemosReskin.swift), mounted at `Epistemos/App/RootView.swift:3855` (`AgentClone.ContentView()` for `.chat`, behind `#if !EPISTEMOS_APP_STORE`). The full shell renders + streams — but it is the RAW donor running its own engine on closed deps with MAS-fatal/sidecar surfaces intact and a cosmetic, UNCONFIGURED reskin. Gaps, by priority:

- **[BLOCKER] 10 closed `github.com/macOS26/Agent*` SPM deps** (AgentAccess/Audit/ColorSyntax/D1F/EventBridges/LLM/MCP/Swift/TerminalNeo/Tools), `Package.swift:29-38`, **154 import sites**. NOT MIT-granted; resolve ONLY from cached DerivedData → license-blocked + non-portable (clean machine fails). Path: clean-room each used Agent* type onto Swarm/Rust/Epistemos equivalents (preserve capability, drop closed IP) OR honest-disable the surface.
- **[BLOCKER] wrong engine**: `ContentView.swift:9` drives `AgentViewModel()` (840-line god-object) — ZERO Swarm/InferenceProvider/EpistemosInProcessProvider. Pulls closed Agent* IP + spawns OWN cloud (ClaudeService/CodexService/OllamaService/OpenAICompatibleService → api.anthropic/openai/perplexity = the Ollama 401 + gpt-5.5 seen) + 6 FoundationModels sites → NO-HIDDEN-SIDECAR violation + double-loop beside Rust agent_core. Target: Swarm substrate + EpistemosInProcessProvider (in-process MLX/Rust), explicit injection, cloudProvider nil.
- **[HIGH] reskin dead**: `AgentSkin` wired into ~28 views but `AgentSkin.configure()` NEVER called from the mount → native-semantic fallback, not Epistemos tokens. Mount only sets `.preferredColorScheme(.dark)`+`.tint`. CRT/scanline still in `Views/Output/ThinkingIndicatorView.swift` + `LLMOutputTextView.swift`. FIX (cheap, highest visible leverage): call `AgentSkin.configure(<Epistemos theme tokens>)` at the Chat mount + flat (no outline/shadow) + strip CRT.
- **[HIGH] streaming/parse**: reasoning leaks into the answer as prose (owner bug paste "**Clarifying tool usage**"); thinking not separated; user can't see tool activity → harden the parse (separate thinking/answer/tool like the Work transcript reducer) + a rich activity UI.
- **[HIGH] tools not Epistemos**: agent can't see Epistemos tools ("no visible Epistemos tool") — its tools are Agent!'s NativeToolHandlers/closed AgentMCP, not the Epistemos Rust tool registry/omega-mcp. Wire Epistemos tools into the Chat agent.
- **[MED] MAS-fatal verbatim**: LaunchDaemons/LaunchAgents root daemon (the "plist not found → rebuild and reinstall Agent" error + register/retry loop), iMessage Conversation.swift, ~28 Process/zsh/NSAppleScript, Xcode shell-out → honest "unavailable/advanced" states per owner directive #4 (don't ship root daemon; don't leave broken install button).
- **[MED] identity**: ~50 files carry Agent!/toddbruss/Twentieth; bundleID `Agent.app.toddbruss`; "Agents" NSMenu; `Agent!` wake word (`InputSectionView.swift:509-510`) → full rebrand to Epistemos (keep functionally-coupled IDs consistent).
- **[done] library adaptation**: `@main` stripped, `ContentView` made `public struct`+`public init()` (mount seam) ✓.

EXECUTION ORDER (this loop): (0) green baseline build [bbts2ealh]; (1) reskin wiring — AgentSkin.configure(theme tokens) at mount + flat + strip CRT [highest visible leverage]; (2) streaming/parse hardening — separate thinking/answer/tool + activity UI; (3) honest-state the MAS-fatal daemon (clears the visible plist error); (4) engine swap → Swarm + EpistemosInProcessProvider (kills the cloud sidecars; "works with my app"); (5) clean-room the closed Agent* deps (portability/license) — the biggest multi-fire effort; (6) rebrand sweep; (7) deeper donor integration + exhaustive endpoint verification. Each slice: read-before-edit, fresh build, no xcodegen, preserve other agents' edits.

### Log 2026-06-25 (Chat = Agent! full-clone, made-Epistemos program)
- Baseline build bbts2ealh ** BUILD SUCCEEDED ** — the full verbatim AgentClone compiles + mounts in-app (closed Agent* deps resolve from cached DerivedData; portability/license still a blocker — task #6).
- SLICE 1 (task #1) IMPLEMENTED: RootView.chatModeSurface now calls `AgentClone.AgentSkin.configure(bg:ui.theme.chatSurface, surface:resolved.card, border:.border, text:.textPrimary, textDim:.mutedForeground, accent:.uiAccent)` before mounting ContentView() — injects the ACTIVE Epistemos theme into the clone's reskin layer (the ~28 AgentSkin views were falling back to native-semantic colors because configure() was never called). Re-runs on theme change (body re-eval) → live multi-theme/custom-token awareness. Build bui9ura5b verifying.
- Program tracked as 8 tasks: (1) reskin wiring [doing] (2) flat/no-outline/no-shadow + strip CRT (3) streaming/parse hardening + activity UI (4) honest-state MAS-fatal daemon (5) engine swap → Swarm + EpistemosInProcessProvider + Epistemos tools (6) clean-room closed Agent* deps (7) rebrand (skip if breaks) (8) donor integration + exhaustive endpoint verify.
- SLICE 2 (task #2) flat pass: scanLinesEnabled default true→false (AgentViewModel:714 — CRT/scanline OFF by default, toggle kept); removed `.shadow` on the composer-suggestion popover (InputSectionView:327) + recent-folders dropdown (ProjectFolderField:280) keeping the flat theme hairline; removed the hard terminal-box `.stroke` outline on the thinking HUD (ThinkingIndicatorView:678, flat termBg fill delineates). Build bctoqsghu verifying. (deeper inline-flat HUD rework folds into slice 3 activity UI.)
- SLICE 3 diagnosis (task #3 ↔ #5 coupling): the reasoning-leak ("**Clarifying tool usage**" in the answer) is because `appendStreamDelta` (Logging.swift:564) appends EVERY provider delta to rawLLMOutput→displayed answer with NO thinking/tool split — and this is the OLD god-object engine on the closed-dep cloud providers (claude/codex/ollama). A heuristic inline-reasoning splitter here is fragile + THROWAWAY (dies at the engine swap). DECISION: the durable streaming/parse/activity fix IS the Swarm engine swap (task #5) — Swarm AgentEvent separates .output(.thinking)/.tool/.output(.token) by construction. So slice #3 folds into #5; do NOT harden the doomed parse. NEAR-TERM non-throwaway visible wins first: #4 honest-state the daemon (clears the visible plist error) + #7 rebrand (Epistemos identity persists across the swap), THEN the deep #5 engine swap + #6 closed-dep clean-room where streaming/activity is done right.
- SLICE 2 re-build: first attempt (bctoqsghu) FAILED on a sibling-agent DerivedData DB-lock (not my code) → re-bundled with task 4.
- SLICE 4 (task #4) honest-state daemon: gated the SMAppService user-agent/daemon ping→mend→register flow in AgentViewModel/Core/Init.swift (startupPingWarmup) + RunStop.swift (testConnection) behind `if UserService.userAgentPlistExists()`. The plists aren't bundled (root-shell-exec daemon is MAS-fatal), so instead of the "no response → mending → still NOT responding → Click Register" spam (the screenshot), it now logs ONE honest line: "Background agent: unavailable (advanced) — Epistemos runs in-process." Capability preserved (bundle plists + install helper → block re-engages). Build bkdzj1xmd verifying slice 2 + task 4 together.
- SLICE 2+4 build bkdzj1xmd FAILED: `UserService.userAgentPlistExists` — that static lives on enum `SafeSMAppService` (UserService.swift:7), not UserService. Fixed both gates (Init.swift + RunStop.swift) → `SafeSMAppService.userAgentPlistExists()`. Rebuild bdtjgpjpm.
- BUILD CONTENTION: slices 2+4 build hit the shared-DerivedData "database is locked" 3× (sibling Work/Act agents build concurrently on the same DerivedData). Can't use a separate -derivedDataPath — the closed Agent* deps exist ONLY as cached checkouts in the shared DerivedData (a fresh DD would try to fetch the private github.com/macOS26/Agent* and fail). Mitigation: a self-retrying xcodebuild (retry on "database is locked", 30s backoff, up to 5×) in one background task → waits out the lock window without burning loop fires. Build bie5etncq. Code is parse-clean (only prior error was the SafeSMAppService type, fixed).

### Owner clarification 2026-06-25 — KEEP ALL CAPABILITIES (major plan revision)
Owner: "I DO want the hugging face and all the online things — they all work, give agent capabilities + model selection. Don't get rid of any capability/usefulness. Just make the app part of my app and continue; don't remove any capabilities." ⇒ REVISED:
- Task #5: do NOT kill the cloud/online providers (HF/Claude/Codex/Ollama/OpenAI/model-selection) — KEEP them all. Optional LATER: ADD Epistemos in-process (MLX/Rust) as an EXTRA model option (capability add, not swap). The "NO HIDDEN SIDECAR" Work-canon does NOT apply to the Chat=Agent! surface per the owner's explicit keep-everything direction.
- Task #6: closed Agent* deps STAY (they give capability + work from cache); do NOT rip out (breakage/capability risk). License/clean-machine-portability = a SEPARATE owner ship-time decision, flagged not actioned.
- Task #3 (streaming/parse + activity UI) is now the TOP real work AND non-throwaway (engine stays) — harden the existing parse: split inline reasoning from the answer + show live tool activity. Reverses the earlier "fold into engine swap" call.
Net program = INTEGRATE + Epistemos-ify (reskin/flat/rebrand) + HARDEN streaming/activity, NOT a capability-stripping rewrite.
- TASK #3 scoped (top task, engine stays → durable). Two sub-fixes: (3a CHEAP/high-value) the thinking + tool-activity UI EXISTS (ToolStep/ToolStepsView in ThinkingIndicatorView) but is COLLAPSED by default — thinkingExpanded(72)/thinkingOutputExpanded(75)/toolStepsExpanded(80) all default false → flip to true (auto-show "what it's doing"); no capability change. (3b DEEPER) the reasoning-leak: CodexService:884-895 pipes reasoning_*.delta via onDelta INTO the visible answer (intentional anti-blank-screen) AND into a thinking block → route reasoning to a SEPARATE thinking sink (add onReasoning callback) so the answer stays clean + reasoning shows in the thinking HUD distinctly. Capability-preserving (enhances providers, removes nothing).
- NEXT EDIT BATCH (one build, after slices 2+4 land): (a) flip the 3 visibility defaults → true [3a]; (b) flat-broaden DependencyOverlayView shadows :34 (blue glow) + :104; (c) rebrand splash DependencyOverlayView :38 "Agent!"→"Epistemos" + :42 tagline + HeaderSectionView :21 "Agent!"→"Epistemos". All low-risk (defaults/strings/modifier-removals). Then 3b reasoning-sink as a focused follow-on.

### ===== HANDOFF (owner-requested STOP) 2026-06-25 — Chat = Agent! full-clone, made-Epistemos =====
ASSIGNMENT: Chat surface = the FULL Agent! clone (LocalPackages/AgentClone, mounted RootView.swift:3855 for .chat), made Epistemos: reskin flat OpenCode-minimal + theme-aware, rebrand (don't break), HARDEN streaming/activity UI, integrate non-Agent! Swift donors — PRESERVE ALL CAPABILITIES (incl. HuggingFace + all cloud providers + model selection; remove nothing). Forever loop.

DONE + WHOLE-APP-GREEN:
- Deep-check inventory (workflow wym2x1v5k) → gap-delta in §9 above. AgentClone is a full verbatim clone, mounted, builds (closed deps from DerivedData cache).
- Slice 1 (task#1) reskin wiring: AgentSkin.configure(Epistemos tokens) at the mount → ~28 skinned views now theme-aware, reactive on theme change. GREEN.
- Slice 2 (task#2) flat pass (PARTIAL): CRT/scanline default off (toggle kept); shadows removed on InputSectionView + ProjectFolderField popovers; terminal-box outline removed on thinking HUD. GREEN. (More shadows found OUTSIDE Views/ — see next batch.)
- Slice 4 (task#4) daemon honest-state: gated user-agent/daemon ping→mend→register behind SafeSMAppService.userAgentPlistExists() (Init.swift + RunStop.swift) → one honest "Background agent: unavailable (advanced) — Epistemos runs in-process" line instead of the "plist not found / still NOT responding / Click Register" spam. GREEN. Capability preserved (toggle).

PREPPED, NOT YET APPLIED (next edit batch, one build):
- (3a) flip thinkingExpanded(AgentViewModel:72) + toolStepsExpanded(:80) defaults false→true → SHOW the agent's thinking + tool activity (it exists — ToolStep/ToolStepsView — but is collapsed by default = why "it doesn't show what it's doing"). Leave thinkingOutputExpanded(:75) false (avoid raw-reasoning noise).
- flat-broaden: remove DependencyOverlayView.swift shadows :34 (blue glow) + :104.
- rebrand (visible only): DependencyOverlayView :38 "Agent!"→"Epistemos" + :42 tagline; HeaderSectionView :21 "Agent!"→"Epistemos".

LEFT (remaining program):
- Task#3 (TOP): 3a above (cheap) THEN 3b — reasoning-leak: CodexService:884-895 pipes reasoning via onDelta INTO the answer (intentional anti-blank-screen). Route reasoning to a SEPARATE thinking sink (add onReasoning callback across providers) → clean answer + reasoning in the thinking HUD. Capability-preserving.
- Task#7 rebrand: finish visible strings (wake-word, settings labels); SKIP functional IDs (bundleID Agent.app.toddbruss, plist names, Mach labels, codesign id) — renaming breaks SMAppService/signing.
- Task#5: KEEP all providers (HF/Claude/Codex/Ollama/OpenAI + model selection); OPTIONAL later — ADD Epistemos in-process (MLX/Rust) as an EXTRA picker model (add, not swap).
- Task#6: closed Agent* deps KEEP (work + give capability). License + clean-machine portability = a SEPARATE SHIP-TIME owner decision (they only build from cache; a clean machine fails to fetch the private github.com/macOS26/Agent*). NOT actioned by design.
- Task#8: integrate beneficial non-Agent! Swift donors (swiftedmind ContentFragmentBuffer/TokenUsage, agentsdk/agentkit typed abstractions — license-clean) + EXHAUSTIVE endpoint/capability verification (every feature/tool/provider/setting works end-to-end — the owner's "deep check it all works").

GOTCHAS: shared DerivedData → frequent DB-locks from sibling Work/Act builds → use a self-retrying xcodebuild (retry-on-"database is locked", 30s backoff). Can't use a separate -derivedDataPath (closed deps only cached in the shared one). Read-before-edit; never xcodegen (wipes signing); preserve sibling edits.
FOOTPRINT: LocalPackages/AgentClone/Sources/AgentClone/* ; Epistemos/App/RootView.swift (Chat mount + AgentSkin.configure) ; this ledger ; memory project_chat_agent_clone_assignment_2026_06_25.md. Tasks tracked #1-8.

### Codex continuation 2026-06-25 — Task #3 first hardening slice

Owner direction reaffirmed: preserve the full Agent! clone and every provider /
online capability. Do not strip HuggingFace, Claude, Codex, Ollama, OpenAI, model
selection, or the closed Agent* packages just to simplify. Make the full clone
visible, Epistemos-styled, and easier to understand first; then integrate other
Swift donors and verify every endpoint/tool/provider/setting.

Implemented:

- Task #3a visibility: `AgentViewModel.thinkingExpanded` now defaults to true
  and `toolStepsExpanded` now defaults to true. `ScriptTab` uses the same
  defaults. This makes the existing thinking HUD and tool-step list visible by
  default instead of hiding the features the clone already had.
- Task #3b Codex reasoning split: `CodexService.sendStreaming` now accepts an
  `onReasoning` sink. `response.reasoning_summary_text.delta`,
  `response.reasoning_text.delta`, and hosted `web_search` status events route
  to that thinking sink instead of `onDelta`, so they no longer pollute the
  assistant answer stream.
- Added `reasoningOutput` state on `AgentViewModel` and `ScriptTab`, plus
  `appendReasoningDelta` helpers and clear/reset wiring for new main/tab tasks
  and clear-output paths.
- Added a compact `ReasoningOutputBox` inside `ThinkingIndicatorView` so live
  Codex reasoning appears as a separate "Thinking" lane above normal LLM
  output. Normal answer deltas still use the existing typewriter/drip output
  path.

Verification:

- `swift build --package-path LocalPackages/AgentClone` completed successfully.
  The build resolved the closed `github.com/macOS26/Agent*` packages from cache,
  which confirms the local-capability path still works and also confirms the
  clean-machine portability risk remains real.

Still open:

- App-level `xcodebuild` checkpoint on the current commingled tree.
- Visible rebrand: wake word, settings/splash/header labels, and stock copy.
  Do not rename functional IDs, bundle IDs, plist names, Mach labels, or
  signing-coupled identifiers.
- Deep feature visibility inventory: expose or preserve every Agent! provider,
  tool, setting, endpoint, MCP surface, session surface, and model picker path.
- Beneficial Swift donor integration: SwiftedMind value types/session ideas,
  AgentSDK/AgentKit abstractions, MCP Swift reference, Foundation Lab UX
  motifs, and license-gated study-only donors.
- Exhaustive endpoint/capability verification remains unproven.

### Codex continuation 2026-06-25 — Task #2/#7 minimalism + visible rebrand slice

Owner clarification during this slice: minimalism means reducing visible
manual-control noise, not deleting capability. Controls may be flattened,
collapsed, automated, or moved behind a quiet entry point, but every provider,
tool, MCP surface, permission surface, setting, session path, and model picker
must remain reachable until an explicit replacement is proven.

Implemented:

- App build checkpoint before the visual pass: `xcodebuild -project
  Epistemos.xcodeproj -scheme Epistemos -configuration Debug -destination
  'platform=macOS' build` completed with `** BUILD SUCCEEDED **` after the
  reasoning-sink/rebrand-first slice.
- AgentClone visual-shell pass, capability-preserving:
  - `ContentView` now presents the activity log as a centered native chat
    transcript region with the thinking/tool HUD overlaid, instead of a
    full-width terminal pane.
  - `ActivityLogView` now uses system text and tighter AppKit insets rather
    than a JetBrains/terminal default for the main transcript.
  - `InputSectionView` now uses the old-main-chat ontology: text row on top,
    compact control strip underneath. Screenshot, paste-image, dictation,
    hotword, clear/stop, and send all remain wired to the original clone
    actions.
  - `ThinkingIndicatorView` no longer shows scanlines or a fake
    `EPISTEMOS >` shell prompt in the live-output pane. Reasoning and LLM
    output still stream through their existing sinks.
  - `HeaderToolbarButtons` are flattened with plain small icon controls; no
    top capability button was removed.
  - `ProjectFolderField` now hides browse/home/clear controls until
    hover/focus while preserving folder tree, browse, home, clear, recent
    folders, and typed path support.
- Visible rebrand, safe-only:
  - Alerts now say "Quit Epistemos?" / "Epistemos Task Failed".
  - The options row now says "Epistemos Scripts".
  - Shell safety/TCC user-facing messages now say Epistemos.
  - Functional IDs remain unchanged: bundle ID, plist labels, Mach labels,
    keychain service names, environment variables, and `~/Documents/AgentScript`
    paths were intentionally not renamed.

Capability inventory snapshot from this slice:

- Provider setup remains broad: Claude, OpenAI, Codex, DeepSeek, Hugging Face,
  OpenRouter, MiniMax, Z.ai, BigModel, Qwen, Gemini, Grok, Mistral, Codestral,
  Mistral Vibe, Ollama, Local Ollama, vLLM, LM Studio, and Apple Intelligence.
- Tool names still include task completion, native tool listing, web search,
  project folder, conversation, send message, Swift AgentScripts, plan mode,
  index, git, batch commands, batch tools, file manager, Xcode, shell,
  AppleScript, accessibility, JavaScript, user shell, root daemon, Safari,
  Selenium, memory, skill, sub-agents, ask-user, and web fetch.
- Visible/advanced surfaces still present: Services, Messages, Accessibility,
  MCP Servers, Coding Preferences, Tools, LLM Settings, Apple Intelligence,
  Options, Fallback Chain, HUD, LLM Usage, Rollback, History, and Clear Log.

Verification:

- `swift build --package-path LocalPackages/AgentClone` passed after the
  composer/transcript pass.
- `swift build --package-path LocalPackages/AgentClone` passed after the
  reasoning/HUD flattening pass.
- `swift build --package-path LocalPackages/AgentClone` passed after visible
  rebrand + minimized working-folder/top-toolbar pass.

Still open:

- Fresh app-level `xcodebuild` after this latest visual/minimalism slice.
- Manual screenshot/readback of the Chat route in the running app.
- Deeper capability verification: every provider/settings endpoint, MCP install
  persistence, Messages/iMessage path, permissions, folder/workspace paths,
  script install/update paths, web/browser automation, Selenium, and tool
  toggles need end-to-end proof.
- UI minimization pass #2: move advanced top controls into a quiet side
  panel/command center only after the same controls are proven reachable there.

### Codex continuation 2026-06-25 — owner status checkpoint, Swift donor fusion reality

Owner asked for an honest status of the "full clone plus every Swift donor"
program. Current reality:

- **AgentClone / Agent! foundation:** implemented as the actual full visible
  clone in `LocalPackages/AgentClone` and mounted from `RootView` as the Chat
  surface. It package-builds after the latest flat/OpenCode-minimal start
  surface and side-control-panel work. It is therefore the only Swift donor that
  is currently a live, buildable Chat foundation.
- **AgentClone limitations:** it still runs the donor `AgentViewModel` and the
  donor capability stack. That preserves many capabilities, but it also means
  it is not yet fully fused with Epistemos tools, recents, MCP persistence, or
  an Epistemos-owned in-process provider. The closed `github.com/macOS26/Agent*`
  package dependency risk remains.
- **Swarm:** vendored locally as `LocalPackages/Swarm` and wired into the Xcode
  project as a local package. It is the main Swift robustness donor for
  typed events, tool execution, memory/session, resilience, guardrails, MCP
  ideas, and observability. It is not yet the live Chat engine. The app still
  reaches Chat through `AgentClone.ContentView()`, not a Swarm-backed
  `EpistemosInProcessProvider`.
- **Other Swift donor repos:** the full research clones exist under
  `.research-clones/swift-act/`: `agent-macos26`, `swiftagent-1amageek`,
  `swiftagent-swiftedmind`, `swarm`, `agentsdk-swift`, `mcp-swift-sdk`,
  `swiftaia-agent`, `agentkit`, and
  `foundation-models-framework-example`. They are research/candidate donors,
  not yet deeply integrated live product code.
- **What has actually landed from non-Agent donors:** only Swarm is present in
  the app workspace. SwiftedMind/AgentSDK/AgentKit/MCP Swift/Foundation Lab
  contributions are inventoried but still pending implementation or
  clean-room adaptation.
- **Latest visual work:** Chat now has a flat start surface with centered
  Epistemos/OpenCode-style title/composer and a toggled side panel for advanced
  controls. This follows the owner's instruction to hide complexity without
  deleting capabilities.

Status labels:

- Full Agent! clone: **live foundation, package-build green, still needs
  app-level visual readback and end-to-end capability proof**.
- Swarm: **vendored/wired, not yet driving Chat**.
- Other Swift repos: **cloned/studied/inventoried, not yet fused**.
- Deep integration: **not complete**. Remaining work is the actual bridge from
  Chat to Epistemos-owned tools/recents/MCP/session/provider seams plus
  endpoint-by-endpoint proof.

### Owner priority 2026-06-25 — all Swift donors must earn usefulness

Owner clarified that the Swift Chat lane is the most complex branch of the
three-toggle mission and must optimize for **maximum usability**, not just
"AgentClone is mounted." Treat every Swift donor as a required usefulness
source. A donor can finish only in one of three honest states: implemented,
clean-room adapted, or explicitly rejected with source-backed rationale. Do not
drop a donor silently.

Required donor harvest map:

- `agent-macos26` / `LocalPackages/AgentClone`: visible full-clone foundation,
  provider/model/settings/tool surfaces, native macOS automation affordances,
  and current Chat shell. Keep iterating visual minimalism without removing
  provider/tool capability.
- `swarm`: typed event stream, tool execution, provider seam, memory/session,
  resilience, guardrails, MCP patterns, workflow/handoff concepts, and
  observability. It should become the main robustness donor where it can add
  real capability without breaking the working clone.
- `swiftagent-swiftedmind`: compact streaming/session/tool-call models,
  `ContentFragmentBuffer`, `TokenUsage`, transcript/tool-run value types, and
  adapter seams.
- `mcp-swift-sdk`: canonical Swift MCP client/server semantics, cancellation,
  progress, auth, sampling, resources/prompts/tools, and elicitation. Reference
  or reuse through the existing dependency path; do not vendor duplicate MCP
  stacks without proof.
- `agentsdk-swift`: typed agent abstraction and OpenAI-style agent interface
  motifs for cleaner bridge boundaries.
- `agentkit`: lightweight agent API ideas and minimal model-centric control
  surface patterns.
- `foundation-models-framework-example`: Apple-native local/private model UX,
  guided generation, structured output, streaming, and tool-calling motifs.
  Sample/reference only until license/API fit is rechecked.
- `swiftagent-1amageek`: permission grammar, sandbox execution, skills/MCP,
  approval bridging, timeout, cancellation, and hardening motifs. Study-only or
  clean-room until license is resolved.
- `swiftaia-agent`: secondary model-selection and tools motifs; use to fill
  gaps that AgentClone/Swarm/SwiftedMind do not cover.

Implementation rule:

- Every future Chat donor pass must update this ledger with a per-donor
  harvest row: feature, source path, integration path, status, build result,
  and capability proof. This is the anti-drift guardrail for the owner's
  "all nine donors should be useful where they fit" requirement.

### Owner clarification 2026-06-25 — donor engines, not AgentClone monopoly

AgentClone is the visible full-clone foundation, not the authority that absorbs
or replaces every other Swift donor. Each donor repo needs its own bounded
contract before implementation:

- **Keep full donor clones for provenance/study.** Full clones can live as
  read-only research/vendor sources so future agents can inspect exact upstream
  behavior and licenses.
- **Product code uses Epistemos-owned adapters/engines.** Do not rely on an
  agent manually remembering which files to copy. For every donor, define the
  Epistemos destination seam first: provider adapter, permission engine, MCP
  bridge, transcript model, event stream, settings panel, command palette,
  tool registry, or visual component.
- **No silent donor loss.** A donor contribution is complete only when its
  assigned feature is implemented/adapted, reachable in the app, build-green,
  visually/procedurally verified, and recorded here with source path and proof.
- **No overreach by AgentClone.** AgentClone may provide shell/runtime
  continuity while Chat is being transformed into the Epistemos old-chat
  ontology, but it must not hide, duplicate, or block Swarm, SwiftedMind,
  MCP Swift, AgentSDK, AgentKit, Foundation Models sample, 1amageek, or
  swiftaia-agent contributions.
- **Recommended repo shape:** keep full clones under `.research-clones/` or a
  clearly named vendor/source snapshot, then expose harvested parts through
  `LocalPackages/<DonorName>Bridge` or Epistemos-native modules with tests.
  Use git submodules only if the owner wants upstream update tracking; for this
  app's fusion work, pinned snapshots plus explicit adapter code are safer than
  product logic depending directly on submodule layout.

Current enforcement:

- Codex spawned read-only donor-contract explorers on 2026-06-25 to map every
  Swift donor repo to exact contribution, source files/APIs, license signal,
  implementation target, and proof requirement before deeper integration.

Read-only donor-contract pass returned 2026-06-25:

| Donor | Repo path / license signal | Assigned contribution | Exact harvest targets | 100% contract / proof |
|---|---|---|---|---|
| AgentClone / Agent! live fork | `LocalPackages/AgentClone`; no local license file; copied from Agent! lineage but currently depends on closed `github.com/macOS26/Agent*` packages | Full visible Chat foundation, provider/model/settings/tool surfaces, current live route | `ContentView`, `AgentViewModel`, `LLMProviderSetup`, `LLMServices`, `CodexService`, `MCPService`, `ToolNames`, `ToolPreferencesService`, `InputSectionView`, `ActivityLogView`, `ReasoningOutputBox` | Preserve full capability, keep Epistemos skin, keep reasoning split, wire Epistemos-native recents/session/tool policy. Prove package/app build, Chat readback, provider picker, tool toggles, MCP, Codex reasoning. Do not let closed `Agent*` deps become unquestioned architecture. |
| Agent! upstream baseline | `.research-clones/swift-act/agent-macos26`; MIT signal | Provenance and diff baseline for AgentClone | `AgentApp.swift`, `Views/ContentView/*`, `Services/*`, `MCP/*`, `AgentViewModel/*` | Compare before future harvest. Do not overwrite Epistemos reskin/reasoning/local fixes with wholesale upstream copy. |
| Swarm | `LocalPackages/Swarm` and `.research-clones/swift-act/swarm`; MIT | Typed runtime/event substrate, provider seam, tools, guardrails, memory/session, resilience, observability, workflows | `Core/AgentRuntime.swift`, `Agents/Agent.swift`, `Core/AgentEvent.swift`, `Tools/Tool.swift`, `ParallelToolExecutor.swift`, `Core/StreamHelper.swift`, `Memory/*`, `Guardrails/*`, `Resilience/*`, `Observability/*`, `Workflow/*`, `MCP/*` | Compile as bounded local package, expose typed events/tool calls/provider adapters without taking over AgentClone UI/provider picker. Prove stream backpressure, no global `Swarm.defaultProvider/cloudProvider` leak, no duplicate MCP truth. |
| swiftagent-swiftedmind | `.research-clones/swift-act/swiftagent-swiftedmind`; MIT | Compact streaming/session/tool-call value model | `ContentFragmentBuffer`, `TokenUsage`, `Transcript`, `ToolRun`, `AgentSnapshot`, `AgentResponse`, `TranscriptResolver`, `LanguageModelProvider`, `@SessionSchema`, `DecodableTool` | Use for value-type/parser inspiration, transcript reconstruction, token accounting, and replayable stream tests. Do not import its OpenAI/Anthropic provider stack. |
| agentsdk-swift | `.research-clones/swift-act/agentsdk-swift`; MIT-style | Typed agent abstractions, tools, guardrails, handoffs, model interface motifs | `Agent<Context>`, `AgentRunner`, `Tool`, `functionTool`, `ModelInterface`, `ModelStreamEvent`, `RunContext`, `Guardrail`, `Handoff`, `Usage` | Translate useful type boundaries into Epistemos Chat contracts/tests. Prove tool enablement, guardrail rejection, handoff event mapping. Do not add another live provider layer. |
| mcp-swift-sdk | `.research-clones/swift-act/mcp-swift-sdk`; Apache-2.0/new-spec plus docs CC-BY-4.0 and older MIT contributions | Canonical Swift MCP semantics | `Client`, `Server`, `Messages`, transports, `Tools`, `Prompts`, `Resources`, `Sampling`, `Elicitation`, `Roots`, progress/cancellation/auth validators | Pick one canonical MCP bridge for Chat. Prove tools/resources/prompts/progress/cancel/auth against Epistemos MCP. Do not leave closed `AgentMCP` as sole truth. |
| agentkit | `.research-clones/swift-act/agentkit`; MIT | Lightweight agent API, streaming callbacks, conversation windowing, retry/backoff, MCP ergonomics | `Agent`, `Agent+StreamAsync`, `AgentCallbackEvent`, `ConversationManager`, sliding/summarizing managers, `RetryStrategy`, `ExponentialBackoff`, `MCPClient`, `MCPServer`, `MCPTool`, `@Tool` | Harvest only complexity-reducing callback/windowing/retry/MCP motifs. Prove retry/backoff, window trimming, callback ordering. Do not absorb Bedrock/Hummingbird/service lifecycle wholesale. |
| foundation-models-framework-example | `.research-clones/swift-act/foundation-models-framework-example`; MIT | Apple-native local/private model UX motifs | `Foundation Lab/ViewModels/ChatViewModel.swift`, availability checks, streaming, multiple sessions, context window, generation options, basic tool use, `FoundationModelsKit`, `FoundationModelsTools` | Use as gated Apple Intelligence/FoundationModels reference. Prove availability-gated behavior on supported macOS. Do not make FoundationModels default or silently prewarm. |
| swiftagent-1amageek | `.research-clones/swift-act/swiftagent-1amageek`; no LICENSE found | Permission grammar, sandbox execution, approvals, cancellation, skills/MCP hardening motifs | `PermissionMode`, `PermissionRule`, `PermissionConfiguration`, `PermissionHandler`, `PermissionMiddleware`, `SandboxExecutor`, `SecurityConfiguration`, `ApprovalBridgeHandler`, `TurnCancellationToken`, `RunEvent`, `TimedStep`, `RetryStep`, `Skills/*`, `SwiftAgentMCP/*` | Clean-room only unless license resolves. Recreate approval/sandbox/cancel concepts in Epistemos style. Prove allow/deny grammar, timeout/cancel, approval bridging. Do not copy source. |
| swiftaia-agent | `.research-clones/swift-act/swiftaia-agent`; no LICENSE found | Secondary motifs for multi-output models, goal/workflow loop, Gemini/Google tool UX, MCP bridging | `AIAgent`, `AIAgentOutput`, `AIAgentModel`, `AIAgentConfiguration`, `MCPServer`, `Workflow`, `GoalManager`, `AITools/*`, `GeminiSDK/*`, `@AITool`, schema macros | Study-only unless license resolves. Harvest clean-room output values, max tool iterations, goal/workflow UX. Prove output normalization and max-iteration stopping. Do not absorb Google SDK/Gemini client/MCP 0.10/macros. |

Highest-risk donor gaps from the pass:

- AgentClone is live but still carries closed `macOS26/Agent*` dependency risk.
- Swarm is vendored but not the Chat engine; its event/provider/runtime value
  is still mostly unimplemented.
- Stream safety is not finished; bounded backpressure proof is required before
  leaning on Swarm streaming.
- MCP truth is split across AgentClone, Swarm, `mcp-swift-sdk`, and Epistemos'
  existing MCP layer. One canonical bridge contract must be selected.
- `swiftagent-1amageek` and `swiftaia-agent` are license-unknown and therefore
  clean-room/study-only unless resolved.

Repository/layout pass returned 2026-06-25:

- There is no root `Package.swift`; the relevant build-facing donor manifests
  are `LocalPackages/AgentClone/Package.swift` and
  `LocalPackages/Swarm/Package.swift`.
- `.gitmodules` is empty. `.research-clones/` is ignored through local
  `.git/info/exclude`, so those clones are useful locally but not durable repo
  truth unless the owner intentionally commits/submodules a provenance layer.
- `Epistemos.xcodeproj/project.pbxproj` references `LocalPackages/Swarm` and
  `LocalPackages/AgentClone`, but `project.yml` does not. Do not run xcodegen
  until that truth mismatch is reconciled.
- Recommended committed structure for anti-loss donor governance:
  `docs/donor-contracts/swift-chat/INDEX.md`,
  `docs/donor-contracts/swift-chat/<donor-id>/<feature-id>.contract.md`,
  `docs/donor-contracts/swift-chat/<donor-id>/provenance.json`,
  `LocalPackages/EpistemosChatDonorContracts/`,
  `Epistemos/Chat/DonorAdapters/<DonorId>/`, and
  `EpistemosTests/ChatDonorContracts/`.
- Naming convention:
  `ChatDonor<DonorId><FeatureId>Contract`,
  `ChatDonor<DonorId><FeatureId>Adapter`,
  `ChatDonor<DonorId><FeatureId>Receipt`, and
  `ChatDonor<DonorId><FeatureId>Tests`.
- Every direct copy or vendored package must carry upstream URL, exact commit,
  fetch date, license path, source-file manifest, import mode, modification
  log, build proof, and dependency risk.
- Add `VENDOR.md` to `LocalPackages/AgentClone` before calling that package
  complete; its manifest pins exact Agent* package versions but there is no
  top-level provenance file.

AgentClone capability-to-ontology pass returned 2026-06-25:

- Keep provider/model picker in the composer as a compact chip; full accounts,
  endpoints, keys, temperature, max tokens, and web-search keys belong in the
  right panel.
- Composer remains home for text input, send/stop/clear, screenshots, paste
  image, dictation, hotword, long-text chips, drag/drop, and attachment tray.
- Toolbar should stay sparse: search, new session/tab, run/stop status, and
  side-panel toggle. Services, Messages, Accessibility, MCP, Coding Prefs,
  Tools, LLM Settings, Apple Intelligence, Options, Fallback, HUD, Usage,
  Rollback, History, and Clear belong in the right panel or command palette.
- Right side panel is the authoritative home for providers, MCP, tools,
  permissions, coding prefs, fallback, history, rollback, usage, Messages,
  services, and diagnostics.
- Tools should appear as active capability chips in the composer and full
  enable/disable groups in the side panel/command palette.
- MCP should be managed in the right panel, with approved auto-start hidden
  behind explicit settings/audit.
- Permissions should live under a right-panel "Permissions & Privacy" area;
  point-of-use tool execution should request approval contextually.
- Streaming/thinking should become inline message disclosure first; detailed
  steps, tokens, raw stream, and reasoning can live in the right panel.

Newly identified bug/risk queue from the ontology pass:

- Direct Epistemos mount of `AgentClone.ContentView()` likely skips `AgentApp`
  startup work: chat history migration, Apple Intelligence prewarm, and MCP
  auto-start servers.
- Two toolbar buttons currently toggle the same side panel; capability is
  preserved but toolbar ontology remains too icon-heavy.
- Side-panel layout still has a narrow-width risk: app min width, reserved
  panel width, and chat min-width can overconstrain the window.
- Start surface advertises `cmd+p commands`, but current key handling only
  implements `cmd+shift+p` for settings.
- Send disabling only checks Claude auth; other providers can fail late with
  missing auth/endpoints.
- Drag/drop currently reads whole UTF-8 files into the prompt; it should become
  bounded resource chips.
- Task loop may send every user-enabled tool each turn without mode filtering;
  User/Root/MCP/AppleScript/Accessibility tools need clearer consent/audit.
- `NSEvent.addLocalMonitorForEvents` and menu observers are added on appear
  without retained tokens/removal.
- Activity log redraw can skip same-length text replacements.
- MCP JSON editor has an empty `updateNSView`, so external binding changes may
  not sync.

### Codex continuation 2026-06-25 — responsive old-chat ontology slice

Capability-preserving UI work landed in `LocalPackages/AgentClone`:

- `ContentView.swift` now splits the giant Chat body into named surfaces:
  `mainChatShell`, `headerStack`, `transcriptStack`, `attachmentStrip`, and
  keyboard/action helpers. This keeps the full AgentClone runtime underneath
  while making the frontend ontology editable as Epistemos Chat surfaces rather
  than a terminal-style donor page.
- The Chat content area now computes side-panel-aware layout metrics. When the
  control side panel is open, the transcript/composer column reserves that
  width instead of sliding underneath it.
- Transcript, thinking HUD, attachment strip, start surface, and composer now
  share the same bounded chat column (`min 320`, `max 880`) so the message bar
  stays inside the window and resizes with the page.
- `InputSectionView.swift` now includes a compact model/settings badge inside
  the composer that opens the existing AgentClone `SettingsView`, preserving
  provider/model capabilities while moving them toward the old Epistemos
  compose-toolbar ontology.
- Composer tools still preserve screenshot, paste image, dictation, hotword,
  clear/stop, and send. At narrow widths, the auxiliary tools collapse into a
  compact menu instead of overflowing the window.
- `ContentView.swift` keyboard shortcuts were extracted out of `body` into
  helpers. Behavior is preserved, and the SwiftUI body is now small enough for
  the compiler.

Verification:

- `swift build --package-path LocalPackages/AgentClone` passed after the
  responsive ontology/composer slice.
- Full app build and fresh visual readback are still owed for this latest
  slice.

### Codex continuation 2026-06-25 — donor contracts are now build-facing

Owner clarified that the Swift donors must become real project surfaces with
native threading, memory, and capability proofs, not just research notes.

Implemented:

- Added `LocalPackages/EpistemosChatDonorContracts`, a dependency-free Swift
  package that records the required donor contracts as code.
- The package defines donor IDs, import modes, license dispositions,
  destination seams, capability status, threading policy, memory policy, proof
  requirements, and validation failures.
- Runtime-facing donor seams now require MainActor UI updates, off-main
  provider/tool/MCP/session work, structured concurrency, explicit
  cancellation, bounded stream buffers, resource-chip handling for large
  inputs, and hot-buffer preallocation.
- The catalog covers every current Swift Chat donor:
  AgentClone, Agent upstream baseline, Swarm, SwiftedMind, MCP Swift SDK,
  AgentSDK Swift, AgentKit, Foundation Models example, swiftagent-1amageek,
  and swiftaia-agent.
- License-unknown donors (`swiftagent-1amageek`, `swiftaia-agent`) are encoded
  as clean-room study contracts only.
- Added `docs/donor-contracts/swift-chat/INDEX.md` plus per-donor
  `provenance.json` records with local paths, upstream URLs, pinned study
  commits, license posture, role, and product rule.
- Added `LocalPackages/AgentClone/VENDOR.md` to pin AgentClone provenance and
  keep its closed `github.com/macOS26/Agent*` dependency risk visible.

Verification:

- `swift test --package-path LocalPackages/EpistemosChatDonorContracts` passed:
  5 tests, 0 failures.
- Visual readback artifact captured at
  `/tmp/epistemos-chat-donor-contract-readback-20260625-0847.png`.
  It shows the Chat start surface, bounded composer, and right controls panel,
  but is obstructed by a macOS crash/open alert.
- The newest crash report,
  `/Users/jojo/Library/Logs/DiagnosticReports/Epistemos-2026-06-25-084659.ips`,
  identifies a stale `/Users/jojo/Downloads/.../Epistemos.app` launch failure:
  dyld could not load `@rpath/Epistemos.debug.dylib` because the copied debug
  dylib was unsigned or missing from the expected debug path. This is separate
  from the previously verified DerivedData app build, whose log contains
  `** BUILD SUCCEEDED **`.

Next implementation rule:

- Future Chat donor work should add or update a
  `ChatDonorFeatureContract` before feature work begins, then update the
  matching `docs/donor-contracts/swift-chat/<donor>/provenance.json` and this
  ledger with the build/visual/endpoint proof. This makes donor usefulness
  testable instead of relying on an agent remembering which repo had which
  feature.

### Codex continuation 2026-06-25 — bounded runtime guard layer

Owner clarified that donor surfaces must become real native project systems
with threading, memory, and performance discipline, not just a list of cloned
repos.

Implemented in `LocalPackages/EpistemosChatDonorContracts`:

- Added `ChatDonorRuntimeGuards.swift`.
- Added `ChatDonorBoundedStream<Event>`, a bounded `AsyncStream` wrapper that
  uses each feature contract's `memory.maxBufferedEvents` and therefore gives
  Swarm/MCP/provider/tool adapters a concrete non-unbounded event path.
  It uses Swift's native `AsyncStream.makeStream` API, not an unsafe
  continuation-capture shim.
- Added `ChatDonorRuntimeRecorder`, an actor-owned receipt recorder for
  enqueued, dropped, and terminated yields, cancellation observation,
  termination state, buffer budget, attachment byte budget, and contract
  validation failures.
- Added `ChatDonorRuntimeReceipt`, a codable/sendable proof object that future
  donor adapters can write into build or endpoint evidence.
- Added `.gitignore` inside the package so SwiftPM `.build` output does not
  become accidental repo bloat.

Tests added:

- Producer outruns consumer → stream keeps the newest bounded events and the
  receipt records drops instead of allowing unbounded growth.
- Cancellation → receipt records `.cancelled` and `cancellationObserved`.
- Runtime receipt codable round-trip.
- Unbounded stream policy → contract validation failure.

Verification:

- `swift test --package-path LocalPackages/EpistemosChatDonorContracts` passed:
  9 tests, 0 failures.

Next implementation rule:

- New Swarm, MCP Swift SDK, AgentSDK, AgentKit, SwiftedMind, permission, or
  workflow adapters should use the bounded stream/receipt layer instead of
  raw unbounded `AsyncStream`/string append loops. This is the native
  performance rail for the full Chat clone: it preserves donor capabilities
  while preventing Agent!/Osaurus-style stream leakage, layout lag, and
  unbounded memory behavior.

### Codex continuation 2026-06-25 — SwiftedMind value-model donor adapted

Owner clarified that each donor must keep its exact assigned use and become a
real project feature. The first non-AgentClone donor slice is now implemented
for the SwiftedMind contract.

Source read:

- `.research-clones/swift-act/swiftagent-swiftedmind/Sources/SwiftAgent/Helpers/ContentFragmentBuffer.swift`
- `.research-clones/swift-act/swiftagent-swiftedmind/Sources/SwiftAgent/Models/TokenUsage.swift`
- `.research-clones/swift-act/swiftagent-swiftedmind/Sources/SwiftAgent/Models/Transcript.swift`
- `.research-clones/swift-act/swiftagent-swiftedmind/Sources/SwiftAgent/Models/AgentSnapshot.swift`
- `.research-clones/swift-act/swiftagent-swiftedmind/Sources/SwiftAgent/Models/AgentResponse.swift`

Implemented:

- Added `ChatDonorTranscriptValues.swift` as an Epistemos-owned adaptation of
  the SwiftedMind value-model contribution. It intentionally does not import
  SwiftedMind's OpenAI/Anthropic provider stack or FoundationModels-dependent
  transcript types.
- Added `ChatDonorContentFragmentBuffer`, a bounded sparse fragment buffer for
  indexed streaming content. It preserves order, supports append/assign, and
  rejects negative indices, fragment-budget overflow, and character-budget
  overflow.
- Added `ChatDonorTokenUsage`, a sendable/codable/hashable token accounting
  model with sparse-counter merge, resolved total fallback, and saturating
  overflow behavior.
- Added lightweight `ChatDonorTranscriptEntry` and `ChatDonorTranscript`
  upsert semantics so future donor adapters can update streaming transcript
  rows without changing row order.
- Updated `ChatDonorCapabilityStatus` with `adapted-with-tests`; marked
  `swiftedmind.transcript-stream-values` as adapted with implementation path
  `LocalPackages/EpistemosChatDonorContracts/Sources/EpistemosChatDonorContracts/ChatDonorTranscriptValues.swift`.
- Updated `docs/donor-contracts/swift-chat/swiftedmind/provenance.json` with
  the implementation path and proof command.

Tests added:

- Adapted contracts must declare implementation paths.
- Sparse fragment buffering preserves order across out-of-order indexed
  fragments.
- Fragment buffer rejects negative indices, too many fragments, and excessive
  character growth.
- Token usage merges sparse counters and saturates overflow to `Int.max`.
- Transcript upsert replaces a streaming response in place without moving its
  row.

Verification:

- `swift test --package-path LocalPackages/EpistemosChatDonorContracts` passed:
  15 tests, 0 failures.

Next implementation rule:

- The next donor slices should follow the same pattern: read exact donor source,
  implement an Epistemos-owned bounded/value/adapter layer, mark that donor
  contract with implementation paths, then prove it with focused tests before
  wiring it into the live AgentClone UI.

### Codex continuation 2026-06-25 — AgentKit retry/window/callback donor adapted

Owner clarified that AgentClone must not monopolize the Swift Chat stack. The
next safe donor slice stayed inside `LocalPackages/EpistemosChatDonorContracts`
and adapted AgentKit's lightweight ergonomics without importing its Bedrock,
MCP, macro, or service-lifecycle stack.

Source read:

- `.research-clones/swift-act/agentkit/Sources/AgentKit/InvokeWithRetry/RetryStrategy.swift`
- `.research-clones/swift-act/agentkit/Sources/AgentKit/InvokeWithRetry/ExponentialBackoff.swift`
- `.research-clones/swift-act/agentkit/Sources/AgentKit/InvokeWithRetry/JitterBackoff.swift`
- `.research-clones/swift-act/agentkit/Sources/AgentKit/InvokeWithRetry/InvokeWithRetry.swift`
- `.research-clones/swift-act/agentkit/Sources/AgentKit/ConversationManager/ConversationManager.swift`
- `.research-clones/swift-act/agentkit/Sources/AgentKit/ConversationManager/SlidingWindowConversationManager.swift`
- `.research-clones/swift-act/agentkit/Sources/AgentKit/Agent+Callback.swift`
- `.research-clones/swift-act/agentkit/Sources/AgentKit/Agent+StreamAsync.swift`
- `.research-clones/swift-act/agentkit/Tests/AgentKitTests/ConversationManagerTests.swift`

Implemented:

- Added `ChatDonorAgentKitErgonomics.swift` as an Epistemos-owned adaptation of
  AgentKit's useful retry/backoff, sliding conversation window, and callback
  stream-order motifs.
- Added `ChatDonorAgentKitRetryPolicy`, `ChatDonorAgentKitRetrier`, and
  `ChatDonorAgentKitRetryReceipt` for capped exponential backoff, deterministic
  jitter proofs, cancellation-aware retry runs, non-retryable failure handling,
  and codable receipt evidence.
- Added `ChatDonorAgentKitConversationWindow` to remove dangling transcript
  entries, keep recent transcript windows, reduce context by a bounded stride,
  and truncate oversized tool-output text instead of allowing unbounded prompt
  growth.
- Added `ChatDonorAgentKitCallbackLog` to assign stable callback sequence
  numbers and reject events after `.end`, mirroring AgentKit's callback-stream
  shape while keeping ordering auditable.
- Added a separate `agentkit.retry-window-callbacks` feature contract with
  exact AgentKit source paths and implementation path. The broader
  `agentkit.lightweight-agent-ergonomics` contract remains pending for MCP
  ergonomics so the ledger does not overclaim completion.
- Updated `docs/donor-contracts/swift-chat/agentkit/provenance.json` and the
  donor index with the partial adapted-with-tests status.

Tests added:

- Retry policy caps exponential backoff and supports deterministic jitter.
- Retrier records retry delays and a success receipt.
- Retrier stops immediately on a non-retryable failure.
- Conversation window drops dangling entries and keeps the recent transcript.
- Context reduction removes a bounded stride and truncates large tool output.
- Callback log preserves sequence order and rejects events after `.end`.

Verification:

- `git -C .research-clones/swift-act/agentkit rev-parse HEAD` returned
  `dd6cc989cf266ae1764c6b400c462a367ba7f128`.
- `swift test --package-path LocalPackages/EpistemosChatDonorContracts` passed:
  21 tests, 0 failures.

Next implementation rule:

- AgentKit retry/window/callback values are now available for future Chat
  runtime and transcript adapters. Do not claim AgentKit complete until its
  MCP ergonomics contribution is either adapted into the chosen canonical MCP
  bridge or explicitly rejected with endpoint proof.

### Codex continuation 2026-06-25 — AgentSDK typed-boundary donor adapted

Owner clarified that each Swift donor must earn a real, source-backed role.
The AgentSDK Swift donor is now adapted as a dependency-free Epistemos value
and decision layer for typed agent/tool/guardrail/handoff boundaries. This does
not import AgentSDK's OpenAI provider, model client, or runner implementation.

Source read:

- `.research-clones/swift-act/agentsdk-swift/Sources/AgentSDK-Swift/Agent.swift`
- `.research-clones/swift-act/agentsdk-swift/Sources/AgentSDK-Swift/AgentRunner.swift`
- `.research-clones/swift-act/agentsdk-swift/Sources/AgentSDK-Swift/Tool.swift`
- `.research-clones/swift-act/agentsdk-swift/Sources/AgentSDK-Swift/RunContext.swift`
- `.research-clones/swift-act/agentsdk-swift/Sources/AgentSDK-Swift/Guardrail.swift`
- `.research-clones/swift-act/agentsdk-swift/Sources/AgentSDK-Swift/Handoff.swift`
- `.research-clones/swift-act/agentsdk-swift/Sources/AgentSDK-Swift/Run.swift`
- `.research-clones/swift-act/agentsdk-swift/Sources/AgentSDK-Swift/Usage.swift`
- `.research-clones/swift-act/agentsdk-swift/Sources/AgentSDK-Swift/ModelSettings.swift`
- `.research-clones/swift-act/agentsdk-swift/Sources/AgentSDK-Swift/Models/ModelInterface.swift`
- `.research-clones/swift-act/agentsdk-swift/Tests/AgentSDK-SwiftTests/AgentSDK_SwiftTests.swift`

Implemented:

- Added `ChatDonorAgentSDKBoundaries.swift` as an Epistemos-owned adaptation of
  AgentSDK's typed boundary concepts.
- Added typed tool descriptors and parameters with AgentSDK-like JSON parameter
  types and run-context capability filtering.
- Added run context and usage values, including request/token aggregation and
  saturating merge behavior.
- Added guardrail rules and a guardrail pipeline that map input/output
  validation to explicit allow/reject decisions with scope and reason.
- Added keyword handoff rules and handoff decisions that record target agent
  and matched keywords.
- Added tool-use behavior values for `runLLMAgain`, `stopOnFirstTool`, and
  `stopAtTools`, matching the AgentSDK runner decision points.
- Added model settings values covering model name, sampling, max tokens,
  tool choice, parallel tool calls, and reasoning effort.
- Updated the `agentsdk.typed-agent-boundaries` contract to
  `adapted-with-tests` with exact source paths and implementation path.
- Updated `docs/donor-contracts/swift-chat/agentsdk-swift/provenance.json`
  and the donor index with the implementation proof.

Tests added:

- Typed tool descriptors filter enabled tools by run-context capabilities and
  preserve required parameter metadata.
- Guardrail pipeline maps input length, blocked output content, and required
  output content to scoped decisions.
- Handoff rules emit the target agent and matched keywords, including
  case-sensitive non-match behavior.
- Tool-use behavior resolves final output for stop-on-first and stop-at-tools.
- Usage aggregation merges request/token counters.
- Full AgentSDK agent descriptor codable round-trip.

Verification:

- `git -C .research-clones/swift-act/agentsdk-swift rev-parse HEAD` returned
  `bfa06f61c3cdf31b615f2fbae4ccd221d59a8565`.
- `swift test --package-path LocalPackages/EpistemosChatDonorContracts` passed:
  26 tests, 0 failures.

Next implementation rule:

- AgentSDK's typed boundaries are now available for the future Chat runtime,
  tool registry, permission policy, and workflow/handoff adapters. Do not add
  AgentSDK's provider layer as a competing live model stack; map provider work
  through the chosen Epistemos/AgentClone/Swarm seams.

### Codex continuation 2026-06-25 - MCP Swift SDK semantic-values donor adapted

Owner clarified that MCP truth must not remain split across AgentClone,
Swarm, the MCP Swift SDK, and Epistemos without a source-backed contract. This
slice adapts the MCP Swift SDK's canonical semantics as dependency-free
Epistemos-owned values and policy helpers. It does not claim the live
Epistemos MCP endpoint bridge is complete.

Source read:

- `.research-clones/swift-act/mcp-swift-sdk/Sources/MCP/Server/Tools.swift`
- `.research-clones/swift-act/mcp-swift-sdk/Sources/MCP/Server/Resources.swift`
- `.research-clones/swift-act/mcp-swift-sdk/Sources/MCP/Server/Prompts.swift`
- `.research-clones/swift-act/mcp-swift-sdk/Sources/MCP/Base/Utilities/Progress.swift`
- `.research-clones/swift-act/mcp-swift-sdk/Sources/MCP/Base/Utilities/Cancellation.swift`
- `.research-clones/swift-act/mcp-swift-sdk/Sources/MCP/Client/Elicitation.swift`
- `.research-clones/swift-act/mcp-swift-sdk/Sources/MCP/Base/Authorization/OAuthURLValidator.swift`
- `.research-clones/swift-act/mcp-swift-sdk/Sources/MCP/Base/Authorization/OAuthModels.swift`
- MCP Swift SDK tests for tools, resources, prompts, progress, cancellation,
  elicitation, and OAuth URL validation.

Implemented:

- Added `ChatDonorMCPSemantics.swift` as the implementation path for the new
  `mcp-swift-sdk.semantic-values` feature contract.
- Added `ChatDonorMCPValue`, a codable recursive JSON value for MCP schemas
  and metadata.
- Added tool descriptors/results with annotations, display-name resolution,
  and explicit-approval policy hints.
- Added resource descriptors, resource content, resource templates, and
  priority clamping.
- Added prompt descriptors/messages and required-argument validation.
- Added progress tokens, notifications, monotonic progress tracking, and
  token-mismatch rejection.
- Added cancellation notices that support specific request and global cancel
  semantics.
- Added elicitation request/schema/result values with accept/decline/cancel
  behavior.
- Added OAuth URL validation and token expiry helpers.
- Added the separate `mcp-swift-sdk.semantic-values` contract as
  `adapted-with-tests`. The broader `mcp-swift-sdk.canonical-mcp-bridge`
  contract remains `contracted-pending` until endpoint proof exists.
- Updated `docs/donor-contracts/swift-chat/mcp-swift-sdk/provenance.json` and
  the donor index with the partial adapted-with-tests status.

Tests added:

- Tool descriptors preserve schemas, metadata, annotations, display names, and
  approval policy hints.
- Resources encode text/binary content and clamp annotation priority.
- Prompts track required arguments and encode prompt messages.
- Progress tracking rejects wrong tokens and non-monotonic updates.
- Cancellation notices match specific request IDs and global cancellation.
- Elicitation schemas validate required fields and decline/cancel clears
  accepted content.
- OAuth URL policy validates HTTPS/loopback rules, private-host detection, and
  token expiry.

Verification:

- `git -C .research-clones/swift-act/mcp-swift-sdk rev-parse HEAD` returned
  `a0ae212ebf6eab5f754c3129608bc5557637e605`.
- `swift test --package-path LocalPackages/EpistemosChatDonorContracts` passed:
  33 tests, 0 failures.

Next implementation rule:

- MCP semantic values are now available for the future Chat MCP bridge,
  permission policy, and tool registry. Do not claim canonical MCP complete
  until the live endpoint bridge is proven against Epistemos MCP with tools,
  resources, prompts, progress, cancellation, auth, and elicitation behavior.

### Codex continuation 2026-06-25 - swiftagent-1amageek permission clean-room donor adapted

Owner clarified that license-unknown donors must still earn usefulness, but
only through clean-room recreation unless the license resolves. This slice
uses `swiftagent-1amageek` as a source-backed study donor for permission,
approval, sandbox, timeout, and cancellation motifs without importing or
copying its source.

Source read:

- `.research-clones/swift-act/swiftagent-1amageek/Docs/SECURITY.md`
- `.research-clones/swift-act/swiftagent-1amageek/Sources/SwiftAgent/Security/PermissionRule.swift`
- `.research-clones/swift-act/swiftagent-1amageek/Sources/SwiftAgent/Security/PermissionConfiguration.swift`
- `.research-clones/swift-act/swiftagent-1amageek/Sources/SwiftAgent/Security/PermissionMiddleware.swift`
- `.research-clones/swift-act/swiftagent-1amageek/Sources/SwiftAgent/Security/PermissionMode.swift`
- `.research-clones/swift-act/swiftagent-1amageek/Sources/SwiftAgent/Security/SecurityConfiguration.swift`
- `.research-clones/swift-act/swiftagent-1amageek/Sources/SwiftAgent/Security/SandboxExecutor.swift`
- `.research-clones/swift-act/swiftagent-1amageek/Sources/SwiftAgent/IO/ApprovalHandler.swift`
- `.research-clones/swift-act/swiftagent-1amageek/Sources/SwiftAgent/IO/ApprovalBridgeHandler.swift`
- `.research-clones/swift-act/swiftagent-1amageek/Sources/SwiftAgent/IO/TurnCancellationToken.swift`
- `.research-clones/swift-act/swiftagent-1amageek/Sources/SwiftAgent/Race.swift`
- `.research-clones/swift-act/swiftagent-1amageek/Sources/SwiftAgentPlugins/PluginToolPermission.swift`
- `.research-clones/swift-act/swiftagent-1amageek/Sources/SwiftAgentSkills/SkillPermissions.swift`
- 1amageek security, plugin-permission, and turn-cancellation tests.

Implemented:

- Added the separate `swiftagent-1amageek.permission-policy-cleanroom`
  contract as `adapted-with-tests`; the broad
  `swiftagent-1amageek.permissions-sandbox-cleanroom` contract remains
  `clean-room-pending` for skills/MCP hardening and real sandbox execution.
- Added `ChatDonorPermissionCleanroom.swift` as an Epistemos-owned clean-room
  implementation.
- Added `ChatDonorPermissionRule` with tool, shell, file-path, MCP, wildcard,
  prefix-token, and path-normalization matching.
- Added `ChatDonorPermissionPolicy` with final-deny, session-memory,
  override, deny, dynamic-allow, allow, permission-mode, and default
  allow/deny/ask evaluation.
- Added approval requests, approval receipts, risk levels, and
  `ChatDonorPermissionSession` actor-owned session memory.
- Added plugin permission-mode escalation values for read-only,
  workspace-write, danger-full-access, prompt, and allow behavior.
- Added sandbox policy/requirement values for network policy, file policy,
  subprocess allowance, enabled state, and timeout validation.
- Added `ChatDonorTurnCancellationToken`, an actor-owned cancellation token
  with cancellation receipts.

Tests added:

- Permission rules match `prefix:*` separators, reject prefix smuggling,
  normalize path traversal, match MCP server wildcards, and parse rule lists.
- Permission policy preserves final-deny precedence, override behavior,
  dynamic allow, and default approval requests.
- Approval session memory records `alwaysAllow` and still cannot bypass
  final-deny.
- Plugin permission-mode escalation denies workspace writes in read-only mode,
  prompts for danger-full-access from standard mode, and allows in allow mode.
- Sandbox policy validates restrictive sandbox settings, disabled sandbox
  state, non-positive timeout, and over-maximum timeout.
- Turn cancellation token records cancellation, preserves first reason, and
  codable round-trips its receipt.

Verification:

- `git -C .research-clones/swift-act/swiftagent-1amageek rev-parse HEAD`
  returned `7b4db2fa3b36add8d6314cb365e3e20f3e6e703b`.
- `swift test --package-path LocalPackages/EpistemosChatDonorContracts`
  passed: 39 tests, 0 failures.

Next implementation rule:

- The clean-room permission values can now inform Chat's tool registry,
  permission surface, and MCP approval policy. Do not claim the 1amageek donor
  complete until skills/MCP hardening and real sandbox execution are either
  clean-room adapted with tests or explicitly rejected with source-backed
  rationale.

### Codex continuation 2026-06-25 - swiftaia-agent workflow/model clean-room donor adapted

Owner clarified that every Swift donor must become useful where it fits.
`swiftaia-agent` has no license file in provenance, so this slice is
clean-room only. It adapts the assigned workflow/model-output/max-iteration
motifs into dependency-free Epistemos-owned values and receipts without
importing Gemini SDK, Google tools, MCP client code, or macros.

Source read:

- `.research-clones/swift-act/swiftaia-agent/README.md`
- `.research-clones/swift-act/swiftaia-agent/Sources/SwiftAIAgent/Agent/AIAgent.swift`
- `.research-clones/swift-act/swiftaia-agent/Sources/SwiftAIAgent/Agent/AIAgentOutput.swift`
- `.research-clones/swift-act/swiftaia-agent/Sources/SwiftAIAgent/Agent/AIAgentOutput+File.swift`
- `.research-clones/swift-act/swiftaia-agent/Sources/SwiftAIAgent/Agent/Model/AIAgentConfiguration.swift`
- `.research-clones/swift-act/swiftaia-agent/Sources/SwiftAIAgent/Agent/Model/ToolCallingValue.swift`
- `.research-clones/swift-act/swiftaia-agent/Sources/SwiftAIAgent/Agents/Workflow.swift`
- `.research-clones/swift-act/swiftaia-agent/Sources/SwiftAIAgent/Agents/GoalManager.swift`
- `.research-clones/swift-act/swiftaia-agent/Sources/SwiftAIAgent/Agents/GoalManagerConfiguration.swift`
- `.research-clones/swift-act/swiftaia-agent/Sources/SwiftAIAgent/Agents/GoalManagerExecutionState.swift`
- `.research-clones/swift-act/swiftaia-agent/Sources/SwiftAIAgent/Agents/GoalManagerError.swift`
- `.research-clones/swift-act/swiftaia-agent/Sources/SwiftAIAgent/Models/AITask.swift`
- `.research-clones/swift-act/swiftaia-agent/Sources/SwiftAIAgent/Models/AIGoalClarification.swift`
- `.research-clones/swift-act/swiftaia-agent/Sources/SwiftAIAgent/Models/AIStrategy.swift`
- swiftaia workflow, tool-call, output-file, and function-calling tests.

Implemented:

- Added `ChatDonorSwiftAIAgentCleanroom.swift` as the implementation path for
  `swiftaia-agent.workflow-model-cleanroom`.
- Added `ChatDonorSwiftAIAgentOutput` and
  `ChatDonorSwiftAIAgentOutputBatch` for text, function calls, structured
  values, image/audio placeholders, transcript normalization, and extraction
  of text/function/structured values.
- Added `ChatDonorSwiftAIToolCall` for clean-room JSON tool-call parsing and
  stable argument JSON.
- Added `ChatDonorSwiftAIAgentConfiguration`, loop receipts, and
  `ChatDonorSwiftAIAgentLoopRunner` with explicit `maxToolIterations`, tool
  execution delay, tool-result prompt folding, and final no-tools model call
  when the tool loop hits the cap.
- Added `ChatDonorSwiftAIWorkflowStep` for single, sequence, parallel, and
  conditional workflow composition.
- Added `ChatDonorSwiftAIGoalPlan`, subtask values, configuration, plan
  validation failures, goal state, and goal receipt values.
- Updated the donor contract, provenance JSON, and donor index to mark the
  swiftaia workflow/model contract as clean-room adapted with tests.

Tests added:

- Mixed output normalization extracts first/all texts, function-call strings,
  structured JSON, media placeholders, parsed tool-call names, arguments, and
  stable argument JSON.
- Tool loop completes immediately when no function calls are returned.
- Tool loop stops at `maxToolIterations`, records tool-call counts, makes a
  final model call with tools disabled, and stores the folded final prompt.
- Workflow step values execute sequence, parallel, and conditional shapes with
  the same prompt-forwarding semantics as the donor motif.
- Goal plans validate empty/fatal failures, retain non-fatal temperature
  warnings, produce agent setup text, choose parallel vs sequence workflow
  shape, and codable round-trip goal receipts.

Verification:

- `git -C .research-clones/swift-act/swiftaia-agent rev-parse HEAD` returned
  `1bce237a31d79c4bb5ffcc2bb5ef81a01245fcc5`.
- `swift test --package-path LocalPackages/EpistemosChatDonorContracts`
  passed: 44 tests, 0 failures.

Next implementation rule:

- swiftaia's output/workflow/max-iteration motifs are now available for future
  Chat workflow and model-output normalization. Do not add its Gemini SDK,
  Google tools, MCP client, or macro layer unless the license is resolved and
  an endpoint-specific contract proves the value over existing Epistemos
  seams.

### Codex continuation 2026-06-25 - Foundation Models availability/options values adapted

Foundation Models was still only a broad visual UX contract. This slice adds a
separate, testable value-layer adapter for Apple-native local/private model UX
motifs without claiming the live Chat UI has implemented the visual treatment.
The broad `foundation-models.apple-native-model-ux` contract remains pending
until provider picker/settings UI readback exists.

Source read:

- `.research-clones/swift-act/foundation-models-framework-example/FoundationLabCore/Sources/FoundationLabCore/Capabilities/CheckModelAvailabilityUseCase.swift`
- `.research-clones/swift-act/foundation-models-framework-example/FoundationLabCore/Sources/FoundationLabCore/Capabilities/InspectModelRuntimeUseCase.swift`
- `.research-clones/swift-act/foundation-models-framework-example/FoundationLabCore/Sources/FoundationLabCore/Capabilities/GenerateStructuredDataUseCase.swift`
- `.research-clones/swift-act/foundation-models-framework-example/FoundationLabCore/Sources/FoundationLabCore/Results/ModelAvailabilityResult.swift`
- `.research-clones/swift-act/foundation-models-framework-example/FoundationLabCore/Sources/FoundationLabCore/Results/ModelRuntimeStatusResult.swift`
- `.research-clones/swift-act/foundation-models-framework-example/FoundationLabCore/Sources/FoundationLabCore/Models/FoundationLabModelRuntime.swift`
- `.research-clones/swift-act/foundation-models-framework-example/FoundationLabCore/Sources/FoundationLabCore/Models/FoundationLabReasoningLevel.swift`
- `.research-clones/swift-act/foundation-models-framework-example/FoundationLabCore/Sources/FoundationLabCore/Models/FoundationLabGenerationOptions.swift`
- `.research-clones/swift-act/foundation-models-framework-example/FoundationLabCore/Sources/FoundationLabCore/Models/FoundationLabExperimentConfiguration.swift`
- `.research-clones/swift-act/foundation-models-framework-example/FoundationLabCore/Sources/FoundationLabCore/Providers/FoundationModelsRuntimeInspector.swift`
- `.research-clones/swift-act/foundation-models-framework-example/Foundation Lab/Views/Playground/PlaygroundInspectorView.swift`
- `.research-clones/swift-act/foundation-models-framework-example/Foundation Lab/Views/Runs/RunConfigurationSection.swift`
- `.research-clones/swift-act/foundation-models-framework-example/Foundation Lab/Views/ModelUnavailableView.swift`
- `.research-clones/swift-act/foundation-models-framework-example/Tools/AFMCLI/Sources/AFMCLI/Commands/AvailableCommand.swift`
- `.research-clones/swift-act/foundation-models-framework-example/Tools/AFMCLI/Sources/AFMCLI/Commands/ModelRuntimePresentation.swift`

Implemented:

- Added `ChatDonorFoundationModelUX.swift` as the implementation path for the
  new `foundation-models.availability-options-values` feature contract.
- Added on-device and Private Cloud Compute runtime values with display names,
  model identifiers, system images, new-session selection semantics, and
  status descriptions.
- Added runtime status projection that distinguishes supported, available,
  authorized, and runnable states, including PCC entitlement-derived reasons.
- Added picker-ready options and availability notices with settings-action
  hints for disabled Apple Intelligence.
- Added generation options for default, greedy, top-k, top-p, fixed seed,
  temperature, and max response tokens, including donor-matched normalization
  and run-summary presentation.
- Added reasoning-level gating so on-device runtime clears reasoning and PCC
  can retain light/moderate/deep reasoning.
- Added session configuration normalization, selected-tool de-duplication,
  run-summary rows, text/structured output modes, and structured request
  validation.
- Updated the donor contract catalog, donor index, and Foundation Models
  provenance JSON to record the partial adapted-with-tests status.

Tests added:

- Runtime statuses build picker options, preserve disabled settings hints,
  distinguish PCC missing entitlement from runnable PCC, and require new
  sessions on runtime selection.
- Configuration normalization clears on-device reasoning, de-duplicates tools,
  repairs modified dates, clamps top-k/top-p/temperature, and removes invalid
  token limits.
- Generation option descriptions and Codable round-trip cover top-p, seed,
  temperature, max tokens, and system defaults.
- Structured run requests validate empty prompts/schema names and preserve
  runtime/model/reasoning/generation/output summary rows through Codable.

Verification:

- `git -C .research-clones/swift-act/foundation-models-framework-example rev-parse HEAD`
  returned `715d1d96f7024ebeab2615a6053754b6ebc422e2`.
- `swift test --package-path LocalPackages/EpistemosChatDonorContracts`
  passed: 48 tests, 0 failures.

Next implementation rule:

- Foundation Models values are now available for the future Chat model picker
  and settings surface. Do not mark the broader Apple-native model UX complete
  until the live Epistemos Chat UI shows the availability-gated picker/options
  behavior with visual readback, and do not silently make Foundation Models the
  default provider or prewarm it without explicit user-facing policy.

### Codex continuation 2026-06-25 - AgentKit MCP ergonomics donor adapted

AgentKit's retry/window/callback slice was already adapted, but the donor
ledger still correctly showed MCP ergonomics as pending. This slice adapts
AgentKit's practical MCP configuration, routing, tool-wrapper, and server
assembly motifs as dependency-free Epistemos-owned values. It deliberately does
not launch MCP processes, connect HTTP transports, or claim the live Epistemos
MCP endpoint bridge is complete.

Source read:

- `.research-clones/swift-act/agentkit/Sources/MCPClientKit/MCPCLient.swift`
- `.research-clones/swift-act/agentkit/Sources/MCPClientKit/MCPClient+Configuration.swift`
- `.research-clones/swift-act/agentkit/Sources/MCPClientKit/MCPClient+Stdio.swift`
- `.research-clones/swift-act/agentkit/Sources/MCPClientKit/MCPClient+HTTP.swift`
- `.research-clones/swift-act/agentkit/Sources/MCPClientKit/MCPClient+ToolProtocol.swift`
- `.research-clones/swift-act/agentkit/Sources/MCPClientKit/Array+MCPClient.swift`
- `.research-clones/swift-act/agentkit/Sources/MCPShared/MCPTransport.swift`
- `.research-clones/swift-act/agentkit/Sources/MCPShared/ToolProtocol.swift`
- `.research-clones/swift-act/agentkit/Sources/MCPShared/ToolProtocol+MCP.swift`
- `.research-clones/swift-act/agentkit/Sources/MCPShared/MCPServerError.swift`
- `.research-clones/swift-act/agentkit/Sources/MCPServerKit/MCPServer.swift`
- `.research-clones/swift-act/agentkit/Sources/MCPServerKit/MCPServer+Tools.swift`
- `.research-clones/swift-act/agentkit/Sources/MCPServerKit/MCPServer+Resources.swift`
- `.research-clones/swift-act/agentkit/Sources/MCPServerKit/MCPServer+Prompts.swift`
- `.research-clones/swift-act/agentkit/Sources/MCPServerKit/MCPTool.swift`
- `.research-clones/swift-act/agentkit/Sources/MCPServerKit/MCPResource.swift`
- `.research-clones/swift-act/agentkit/Sources/MCPServerKit/MCPPrompt.swift`
- AgentKit MCP configuration, server, and tool-protocol tests.

Implemented:

- Added `ChatDonorAgentKitMCPErgonomics.swift` as the implementation path for
  the new `agentkit.mcp-ergonomics` feature contract.
- Added mixed `mcp.json` decoding for stdio and HTTP server configurations,
  including disabled flags, timeout validation, active-server filtering, and
  Codable round-trip.
- Added client catalog values for listing tool names, routing tool calls to
  the owning client, and building AgentKit-style MCP tool wrappers.
- Added tool-input decoding that first tries the full JSON object and then
  falls back to the donor's `input` parameter extraction motif.
- Added MCP server descriptor values that assemble tool/resource/prompt
  capabilities without starting a server lifecycle.
- Added in-memory text/binary resource helpers, URI lookup, prompt templates,
  placeholder validation, prompt rendering, and donor-shaped error values.
- Updated the contract catalog, donor index, and AgentKit provenance JSON to
  mark `agentkit.mcp-ergonomics` adapted with tests.

Tests added:

- Mixed stdio/http `mcp.json` decoding preserves command/args/env/url data,
  filters active servers, rejects disabled and invalid-timeout configurations,
  and round-trips through Codable.
- Client catalogs list tools, route tool calls by name, build wrappers, expose
  stable input-schema JSON, and reject unknown tools.
- Tool input decoding supports whole-object decoding and `input` fallback,
  including missing-parameter failure.
- Server descriptors expose tools/resources/prompts capabilities, resource URI
  lookup, binary content encoding, prompt rendering, missing prompt values,
  prompt placeholder validation, and Codable round-trip.

Verification:

- `git -C .research-clones/swift-act/agentkit rev-parse HEAD` returned
  `dd6cc989cf266ae1764c6b400c462a367ba7f128`.
- `swift test --package-path LocalPackages/EpistemosChatDonorContracts`
  passed: 52 tests, 0 failures.

Next implementation rule:

- AgentKit's MCP ergonomics are now available for the future Chat MCP bridge
  and tool registry. Do not claim MCP complete until the live endpoint bridge
  proves tools/resources/prompts/progress/cancel/auth/elicitation behavior
  against Epistemos runtime and permission surfaces.

### Codex continuation 2026-06-25 - Foundation Models picker live readback

The Foundation Models value layer already existed in the donor-contract
package, but it had not yet touched live app picker code. This slice wires the
Apple-native runtime availability/readback motifs into the existing Epistemos
runtime picker without importing the donor contract package into the app target
or claiming the broad visual UX contract complete.

Source read:

- `LocalPackages/EpistemosChatDonorContracts/Sources/EpistemosChatDonorContracts/ChatDonorFoundationModelUX.swift`
- `Epistemos/Engine/EpistemosRuntimePicker.swift`
- `Epistemos/Views/Chat/InlineRuntimePickerPanel.swift`
- `Epistemos/App/RootView.swift`
- `Epistemos/Views/Settings/EpistemosPicksSectionView.swift`
- `EpistemosTests/EpistemosRuntimePickerTests.swift`
- `EpistemosTests/InlineRuntimePickerPanelTests.swift`

Implemented:

- Added `foundation-models.runtime-picker-live-readback` as a partial live
  contract. The broader `foundation-models.apple-native-model-ux` contract
  remains pending until fresh visual readback exists.
- Extended `EpistemosRuntimePicker.Option` with runtime kind, system image,
  availability summary, settings-action recommendation, and
  new-session-on-runtime-switch metadata.
- Threaded `InferenceState.appleIntelligenceUnavailableReason` into the live
  picker environments for the inline composer picker, legacy popover, and
  Settings Epistemos Picks section.
- Rendered Apple Intelligence with Foundation Models-style availability
  readback, a settings icon when the unavailable reason is settings-actionable,
  and a compact `NEW CHAT` cue for runtime switches.
- Updated the Foundation Models provenance JSON and donor index.

Tests added:

- `EpistemosRuntimePickerTests.appleIntelligenceCarriesFoundationModelsRuntimeMetadata`
  proves runtime kind, system image, availability summary, settings hint, and
  new-session metadata for available and disabled Apple Intelligence states.
- `InlineRuntimePickerPanelTests.panelRendersFoundationModelsRuntimeReadback`
  source-guards the live row rendering and shared unavailable-reason mapping.

Verification:

- `swift test --package-path LocalPackages/EpistemosChatDonorContracts`
  passed: 52 tests, 0 failures.
- `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -configuration Debug -destination 'platform=macOS' test -only-testing:EpistemosTests/EpistemosRuntimePickerTests -only-testing:EpistemosTests/InlineRuntimePickerPanelTests`
  passed: Swift Testing reported 25 tests across 2 suites, 0 failures. XCTest
  also reported 0 selected legacy XCTest tests, 0 failures.

Next implementation rule:

- The live picker now carries Foundation Models runtime readback for Apple
  Intelligence, but this is still not full visual proof. Do not close
  `foundation-models.apple-native-model-ux` until the app is freshly launched,
  the picker is visually captured/read, and the availability-gated row is
  confirmed in the actual UI.

### Codex continuation 2026-06-25 - AgentClone capability preservation manifest

This slice makes the "do not delete Agent! capabilities while simplifying the
surface" rule executable. It does not change live UI behavior and does not
claim the AgentClone full foundation complete; it adds source-backed tests that
future Chat simplification work must pass before hiding, moving, or replacing
capability surfaces.

Source read:

- `LocalPackages/AgentClone/Sources/AgentClone/Services/LLMProviderSetup.swift`
- `LocalPackages/AgentClone/Sources/AgentClone/Views/Settings/SettingsView.swift`
- `LocalPackages/AgentClone/Sources/AgentClone/Models/ToolNames.swift`
- `LocalPackages/AgentClone/Sources/AgentClone/Services/ToolPreferencesService.swift`
- `LocalPackages/AgentClone/Sources/AgentClone/MCP/MCPConfig.swift`
- `LocalPackages/AgentClone/Sources/AgentClone/MCP/MCPService.swift`
- `LocalPackages/AgentClone/Sources/AgentClone/MCP/MCPServersView.swift`
- `LocalPackages/AgentClone/Sources/AgentClone/Services/SessionStore.swift`
- `LocalPackages/AgentClone/Sources/AgentClone/Services/TokenUsageStore.swift`
- `LocalPackages/AgentClone/Sources/AgentClone/Services/FileBackupService.swift`
- `LocalPackages/AgentClone/Sources/AgentClone/Services/ShellSafetyService.swift`
- `LocalPackages/AgentClone/Package.swift`
- `LocalPackages/AgentClone/VENDOR.md`

Implemented:

- Added `ChatDonorAgentCloneCapabilityManifest`, an Epistemos-owned manifest
  that tracks 20 provider IDs, 28 native tool/tool-family names, 8 major
  surfaces, and the known closed `Agent*` package risk.
- Added the contract `agent-clone.capability-preservation-manifest` with
  `adapted-with-tests` status. This is a preservation proof layer, not a
  replacement for live endpoint or visual proof.
- Added source-anchor tests that read the current AgentClone files and require
  every provider/tool/surface/risk marker to exist in source.
- Updated the Swift Chat donor index and AgentClone provenance JSON.

Tests added:

- Provider coverage: Claude, OpenAI, Codex, DeepSeek, Hugging Face, Z.ai,
  BigModel, MiniMax, OpenRouter, Qwen, Gemini, Grok, Mistral, Codestral,
  Mistral Vibe, Ollama Cloud, Local Ollama, vLLM, LM Studio, and Apple
  Intelligence.
- Tool coverage: task completion, tool listing, web search/fetch, project
  folder, conversation/send message, agent script, plan, index, git, batch
  commands/tools, file manager, Xcode, shell, AppleScript, Accessibility,
  JavaScript, user/root shell, Safari, Selenium, memory, skills, sub-agents,
  and ask-user.
- Surface coverage: MCP, sessions/history/recents, settings, permissions and
  approvals, rollback, usage, automation, Messages, and the closed package risk
  owner-approval gate.

Verification:

- `swift test --package-path LocalPackages/EpistemosChatDonorContracts`
  passed: 55 tests, 0 failures.

Next implementation rule:

- Future visual minimization may move controls into the side panel or group
  them behind progressive disclosure, but this manifest must keep passing.
  Removing a provider/tool/MCP/session/history/rollback/usage/permission/
  settings/Messages/automation capability requires a source-backed contract
  update and owner approval, not a quiet UI deletion.

### Codex continuation 2026-06-25 - Swarm in-process Chat substrate

This slice hardens the existing Epistemos-owned Chat module that was already
constructed and injected, without changing the visible Chat route away from the
AgentClone foundation. It makes the Swarm substrate real and bounded while
keeping the broader "Swarm drives live Chat" milestone open.

Source read:

- `LocalPackages/Swarm/Sources/Swarm/Core/StreamHelper.swift`
- `Epistemos/Chat/EpistemosInProcessProvider.swift`
- `Epistemos/Chat/EpistemosChatSession.swift`
- `Epistemos/Chat/EpistemosChatAgentFactory.swift`
- `Epistemos/Chat/ChatTranscript.swift`
- `Epistemos/Chat/ChatViewModel.swift`
- `Epistemos/Chat/EpistemosChatEngineProvider.swift`
- `Epistemos/App/AppBootstrap.swift`
- `Epistemos/App/AppEnvironment.swift`

Implemented:

- Added `swarm.in-process-chat-substrate` as an adapted-with-tests contract.
- Bounded the `EpistemosInProcessProvider` bridge stream with
  `.bufferingNewest(256)` and explicit task cancellation on stream
  termination.
- Bounded the `EpistemosChatSession` `AgentEvent` projection stream with
  `.bufferingNewest(256)`, existing consumer-task cancellation, and
  `agent.cancel()` on cancelled termination.
- Added source-anchor tests proving explicit in-process provider injection,
  streaming enablement, max-iteration guardrail, conversation memory windowing,
  typed event projection, coordinator construction, and SwiftUI environment
  injection.
- Updated the Swift Chat donor index and Swarm provenance JSON.

Verification:

- `swift test --package-path LocalPackages/EpistemosChatDonorContracts`
  passed: 56 tests, 0 failures.
- `jq empty docs/donor-contracts/swift-chat/swarm/provenance.json`
  passed.
- `git diff --check -- <touched files>` passed for the tracked diff check,
  but these donor/Chat lane files are currently untracked in the dirty
  workspace, so the main proof is the package test and source-anchor test.
- App build attempt:
  `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -configuration Debug -destination 'platform=macOS' build`
  failed before compilation because the shared DerivedData `build.db` was
  locked by another build.
- Retried with isolated DerivedData:
  `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/EpistemosCodexBuild-SwarmSubstrate build`.
  It was stopped after several minutes still compiling third-party package
  dependencies and before reaching a useful Epistemos app compile diagnostic.

Next implementation rule:

- This is a substrate proof only. Do not treat it as visual completion, endpoint
  completion, or permission to replace AgentClone's visible capability stack.
  Any future route swap still needs capability preservation, endpoint proof, app
  build proof, and fresh visual readback.

### Codex continuation 2026-06-25 - AgentClone visible ontology chrome

Owner clarified that the Chat UI still looked like the Swift Agent donor
surface because the previous slices were mostly substrate/composer work. This
slice targets the mounted route directly: `AgentClone.ContentView()` remains the
capability foundation, but the recurring chat shell now has visible Epistemos
chrome instead of only the donor transcript/composer stack.

Implemented:

- Added `agent-clone.visible-ontology-chrome` as an adapted-with-tests contract
  for the mounted AgentClone visible shell.
- Added `EpistemosChatChromeBar` to `ContentView.swift`, with persistent
  Epistemos title/context status, active provider/model display, and icon
  controls for context panel, new chat, search, history, and settings.
- Kept provider/model settings reachable through both the existing composer
  model badge and the new top model control.
- Renamed the right drawer from generic `Controls` to `Context` while keeping
  the existing `HeaderToolbarButtons` capability surface intact.
- Restored monospaced user/composer/tool chrome tokens in `EpistemosReskin`
  while leaving assistant prose in the transcript renderer.
- Added source-anchor tests proving the mounted chrome, model/settings/history/
  new-session/search/context controls, composer tool menu, and monospaced
  chrome tokens are present.
- Updated the Swift Chat donor index and AgentClone provenance JSON.

Verification:

- `swift test --package-path LocalPackages/EpistemosChatDonorContracts`
  passed: 57 tests, 0 failures.
- `swift build --package-path LocalPackages/AgentClone` passed after the
  visible ontology chrome patch.
- `swift build --package-path /tmp/AgentCloneVisualHost` passed for a
  temporary SwiftPM host that imports the local `AgentClone` package and mounts
  `AgentClone.ContentView()` directly.
- Direct package-host visual readback captured and inspected:
  `docs/handoffs/evidence/chat-agentclone-visible-ontology-chrome-2026-06-25.png`
  and
  `docs/handoffs/evidence/chat-agentclone-visible-ontology-chrome-window-2026-06-25.png`.
  The window-only PNG shows the new `Epistemos` title chrome, provider/model
  pill, context/new-chat/search/history/settings icon row, transcript renderer,
  and composer model badge/tool controls.
- `jq empty docs/donor-contracts/swift-chat/agent-clone/provenance.json`
  passed.
- `git diff --check -- <touched files>` passed.
- Full app build attempt:
  `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/EpistemosCodexBuild-VisibleChrome build`
  was manually interrupted after several minutes still compiling clean
  third-party dependency targets (`mlx-swift`, `swift-crypto`, `SwiftMath`,
  etc.) and before reaching a useful Epistemos app compile diagnostic.
- Fresh app visual readback is still required before closing the broader
  `agent-clone.visible-foundation` contract; the screenshots above prove the
  package-mounted visible shell, not the full Epistemos app route.

### Codex continuation 2026-06-25 - AgentClone start/message-bar ontology

Owner confusion was valid: the earlier donor slices mostly proved substrate and
capability preservation, so the mounted Chat could still read visually as the
Swift Agent donor surface. This slice continues the visible ontology rebuild in
the mounted `AgentClone.ContentView()` package surface.

Implemented:

- Added `agent-clone.start-message-bar-ontology` as an adapted-with-tests
  contract.
- Removed the donor empty-state instruction row (`tab agents`, `cmd+p
  commands`, `esc stop`) and the donor `Tip` copy from `ChatStartSurface`.
- Changed composer placeholders from generic `Ask anything...` copy to
  Epistemos message-bar language: `Message Epistemos...`, `Message
  recipient...`, and script-specific message placeholders.
- Added bootstrap-status filtering to the start-surface decision so AgentClone's
  startup/warmup status lines do not immediately displace the Epistemos empty
  message-bar surface into a transcript-first donor view.
- Preserved provider/model settings, composer tool buttons, and top chrome
  controls.
- Updated the Swift Chat donor index and AgentClone provenance JSON.

Verification:

- `swift test --package-path LocalPackages/EpistemosChatDonorContracts`
  passed: 58 tests, 0 failures.
- `swift build --package-path LocalPackages/AgentClone` passed.
- `swift build --package-path /tmp/AgentCloneVisualHost` passed for the
  temporary SwiftPM host mounting `AgentClone.ContentView()` directly.
- Direct package-host visual readback captured with `CFFIXED_USER_HOME`
  redirected to `/tmp/AgentCloneVisualHome` so SwiftData history did not use the
  owner's real app-support store:
  `docs/handoffs/evidence/chat-agentclone-start-message-bar-filtered-window-2026-06-25.png`.
  The PNG shows the large `epistemos` start mark, `Message Epistemos...`
  composer, preserved provider/model chrome, preserved composer tool controls,
  and no donor hint/tip copy.
- `jq empty docs/donor-contracts/swift-chat/agent-clone/provenance.json`
  passed after the visual-evidence entry.

Remaining:

- This is still package-host visual proof, not final full Epistemos app route
  proof. The broad `agent-clone.visible-foundation` contract remains open until
  the real app route builds, launches, and reads back visually with the same
  preserved capability stack.

### Codex continuation 2026-06-25 - AgentClone full-app chat route proof

Owner confusion was again the right forcing function: package-host proof can
show the transformed AgentClone surface while the real Epistemos app still might
mount a different old or donor-looking route. This slice verified the actual app
route instead of relying on package inference.

Implemented:

- Added `agent-clone.full-app-chat-route-start-proof` as an adapted-with-tests
  contract.
- Added source-anchor coverage proving:
  - `WorkspaceModeSelection.current()` persists the selected workspace mode via
    `epistemos.workspace.mode`;
  - `RootView.chatModeSurface` configures `AgentClone.AgentSkin` from the active
    Epistemos theme tokens;
  - `.chat` mode mounts `AgentClone.ContentView()` and transitions through
    `chatModeSurface.transition(.blurFade())`;
  - the mounted AgentClone start surface still carries the large `epistemos`
    mark, `Message Epistemos...` composer placeholder, model settings button,
    and composer tools, with donor hint copy removed.
- Updated the Swift Chat donor index and AgentClone provenance JSON.

Verification:

- Full app build passed:
  `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/EpistemosCodexBuild-ChatRouteProof build`
  returned `** BUILD SUCCEEDED **`.
- Launched the exact derived-data app binary with temp user state:
  `CFFIXED_USER_HOME=/tmp/EpistemosChatRouteProofHome`,
  `HOME=/tmp/EpistemosChatRouteProofHome`,
  `CFPREFERENCES_USER_HOME=/tmp/EpistemosChatRouteProofHome`, and
  `epistemos.workspace.mode=chat`.
- Full app visual readback captured:
  `docs/handoffs/evidence/chat-epistemos-app-route-agentclone-start-message-bar-2026-06-25.png`
  and
  `docs/handoffs/evidence/chat-epistemos-app-route-agentclone-start-message-bar-cleaner-2026-06-25.png`.
  The screenshots show the real `Epistemos.app` window, large `epistemos`
  start mark, `Message Epistemos...` composer, preserved model/provider chrome,
  and preserved composer tool controls. A first-run vault-import overlay is
  visible; it does not obscure the start/message-bar evidence but should be
  avoided or allowed to finish for future polish screenshots.
- The temporary proof process was stopped cleanly after capture.

Remaining:

- This closes the specific app-route proof gap for the start/message-bar slice.
  It does not close the broad `agent-clone.visible-foundation` contract because
  provider picker traversal, tool toggles, MCP surface reachability, live endpoint
  proof, and Codex reasoning separation still need full-app verification.

### Codex continuation 2026-06-25 - AgentClone message-bar layout parity

Owner feedback was that the visible Chat still read too much like the Swift
Agent donor surface. This slice makes a concrete visible composer change while
leaving the donor capability controls reachable.

Implemented:

- Added `agent-clone.message-bar-layout-parity` as an adapted-with-tests
  contract.
- Added `EpistemosMessageBarLayout` inside AgentClone's
  `InputSectionView.swift`, sourced from the existing Epistemos chat/mini-chat
  composer geometry:
  - 620pt max message-bar width;
  - 11/9/7 horizontal/top/bottom padding;
  - 4pt control-row spacing and 6pt control-row top gap.
- Wrapped the AgentClone composer in a centered message-bar container so it no
  longer stretches to the wider donor chat column on the start surface.
- Tightened the composer shell/control-row rhythm and slightly flattened the
  shell opacity.
- Preserved provider/model settings, screenshot attachment, paste-image
  attachment, dictation, hotword, stop/clear, and send controls.
- Updated the Swift Chat donor index and AgentClone provenance JSON.

Verification:

- `swift test --package-path LocalPackages/EpistemosChatDonorContracts`
  passed: 60 tests, 0 failures.
- `jq empty docs/donor-contracts/swift-chat/agent-clone/provenance.json`
  passed.
- `git diff --check -- <touched files>` passed.
- `swift build --package-path LocalPackages/AgentClone` passed.
- `swift build --package-path /tmp/AgentCloneVisualHost` passed.
- Direct package-host visual readback captured with `CFFIXED_USER_HOME`
  redirected to `/tmp/AgentCloneMessageBarVisualHome`:
  `docs/handoffs/evidence/chat-agentclone-message-bar-layout-parity-window-2026-06-25.png`.
  The window-only PNG shows the centered 620pt-style message bar under the
  `epistemos` start mark, with `Message Epistemos...`, provider/model chrome,
  composer tool buttons, clear, and send controls still visible.

Remaining:

- This is a scoped composer geometry/style pass. It does not finish transcript
  typography, side-panel behavior, provider picker traversal, live endpoint
  proof, or the complete old Epistemos Chat ontology rebuild.

### Codex continuation 2026-06-25 - ChatView 2 route ontology

Owner correction: the visible target is not an AgentClone-looking shell that
gets slowly themed. The target is ChatView 2: an Epistemos-owned rebuild that
tracks the old `Epistemos/Views/Chat/ChatView.swift` ontology closely, while
wiring through the new fused Chat substrate instead of restoring the old view.

Implemented:

- Replaced the real `.chat` route mount in `Epistemos/App/RootView.swift` so it
  now presents `ChatRouteView()` instead of `AgentClone.ContentView()`.
- Rebuilt `Epistemos/Chat/ChatRouteView.swift` as the first ChatView 2 surface:
  old-style split layout, centered transcript/composer lane, native top chrome,
  history/sidebar popover, model/status control, new chat, settings, and a right
  context panel.
- Kept the original `ChatInputBar` composer primitive in the route so the
  message-bar ontology starts from the old Epistemos chat surface rather than a
  donor composer.
- Added `agent-clone.chatview2-route-ontology` as an adapted-with-tests donor
  contract. AgentClone remains the inventoried capability foundation to re-home
  providers, tools, MCP, permissions, settings, sessions, rollback, usage, and
  endpoints behind this new surface; it is no longer the direct visible shell
  for this slice.
- Updated the Swift Chat donor index and AgentClone provenance JSON.

Verification:

- `swift test --package-path LocalPackages/EpistemosChatDonorContracts`
  passed: 60 tests, 0 failures.
- Full app build passed:
  `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/EpistemosCodexBuild-ChatRouteProof build`
  returned `** BUILD SUCCEEDED **`.
- Full app visual readback captured with temp user state:
  `docs/handoffs/evidence/chat-epistemos-chatview2-route-ontology-2026-06-25.png`.
  The screenshot shows the real `Epistemos.app` in `.chat`, the ChatView-like
  split surface, Epistemos title mark, old composer lane, right context panel,
  model/status controls, new chat, and settings. A first-run vault import banner
  is visible because the proof used a fresh temporary home.
- `jq empty docs/donor-contracts/swift-chat/agent-clone/provenance.json`
  passed.
- `git diff --check -- <touched files>` passed.

Remaining:

- This is the first route-ontology correction, not the finished chat. Provider
  picker traversal, live tool/MCP execution, settings/session/history/rollback/
  usage reachability, endpoint proof, richer transcript bubble parity, mini
  session behavior, and a clean post-import polish screenshot are still open.

### Codex continuation 2026-06-25 - ChatView 2 brain-panel parity

Next owner-corrected ontology slice: the right panel in ChatView 2 was still a
thin placeholder (`Session`, `Model`, `Runtime`). This moves it toward the old
`ChatBrainPanelView` shape without restoring or mounting old `ChatView`.

Implemented:

- Replaced `ChatView2ContextPanel` in `Epistemos/Chat/ChatRouteView.swift` with
  `ChatView2BrainPanel`.
- Added old-chat style collapsible uppercase sections via
  `ChatView2BrainPanelSection` and flat 4pt card chrome.
- Wired the panel to existing app state:
  - `chat.pendingContextAttachments` and `chat.pendingAttachments` for
    `READY TO SEND`;
  - `chat.latestBrainSnapshot` for `ROUTING`, `REQUEST`, explicit attachments,
    loaded notes, tools-this-turn, and dynamic sections;
  - `chat.latestCapturedModelInput` for `MODEL INPUT`;
  - `chat.currentCapability`, context budget, message count, active model, new
    chat, and settings for the always-visible empty-context state.
- Added copy affordances using `NSPasteboard` so model/request/tool details stay
  inspectable from the panel.
- Added `agent-clone.chatview2-brain-panel-parity` as an adapted-with-tests
  contract and updated the Swift Chat donor index + AgentClone provenance JSON.

Verification:

- `swift test --package-path LocalPackages/EpistemosChatDonorContracts`
  passed: 61 tests, 0 failures.
- Full app build passed:
  `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/EpistemosCodexBuild-ChatRouteProof build`
  returned `** BUILD SUCCEEDED **`.
- Full app visual readback captured with temp user state:
  `docs/handoffs/evidence/chat-epistemos-chatview2-brain-panel-parity-2026-06-25.png`.
  The screenshot shows the real `Epistemos.app` in `.chat`, the ChatView 2 right
  panel with state/messages/context/model rows, copy icons, `MODEL CONTEXT`, and
  `ACTIONS` sections. A first-run vault import banner is visible because the
  proof used a fresh temporary home.
- `jq empty docs/donor-contracts/swift-chat/agent-clone/provenance.json`
  passed.
- `git diff --check -- <touched files>` passed.

Remaining:

- This proves the empty-context brain-panel shape. It does not yet prove a
  populated turn with `ROUTING`, `REQUEST`, `TOOLS THIS TURN`, or `MODEL INPUT`
  visible, and it does not close provider picker traversal, live tool/MCP
  execution, settings/session/history/rollback/usage reachability, endpoint
  proof, richer transcript bubble parity, mini-session behavior, or the clean
  post-import polish screenshot.

### Codex continuation 2026-06-25 - targeted old chat / Osaurus deletion pass

Owner directive changed: stop preserving the old Epistemos native chat path,
MiniChat, NoteChat, GraphChat, and Osaurus. Protected Work/OpenGUI/Goose and
AgentClone/fusion work stayed untouched except for donor guard metadata.

Implemented:

- Deleted the old native chat surface family: `ChatView`, `ChatInputBar`,
  `ChatSidebarView`, `MessageBubble`, old `ChatCoordinator` files,
  `ChatState`, `DialogueChatState`, `NoteChatState`, MiniChat windows/views,
  note chat sidebar/code-ask/inline response panels, graph chat request, and
  the old Act/Osaurus bridge files.
- Removed `LocalPackages/osaurus`, `Epistemos/ActOsaurus`, and
  `Epistemos/Vendor/Osaurus`.
- Removed remaining live old route bridges from `RootView`, `EpistemosApp`,
  and `LandingView`; Act landing submissions now go directly through
  `AgentChatState` instead of an Osaurus compatibility notification.
- Removed graph inspector chat state/streaming loops while preserving graph
  inspection/summarization.
- Removed MiniChat thread/session state and MiniChat workspace snapshot fields.
- Tightened donor deletion guards so `.submitActOsaurusPrompt`,
  `ActOsaurusPromptRequest`, MiniChat, NoteChat, and graph-chat deleted symbols
  cannot be reintroduced silently.

Verification:

- `swift test --package-path LocalPackages/EpistemosChatDonorContracts`
  passed: 64 tests, 0 failures.
- Deletion scan passed for the high-risk live symbols across app Swift sources:
  `submitActOsaurus`, `ActOsaurusPromptRequest`, `OsaurusCore`,
  `MiniChatWindowController`, `OpenMiniChatIntent`, `GraphChatRequest`,
  `MainChatSubmissionRouter`, `FocusedCodeResponse`,
  `InlineResponseAnnotation`, `CodeAskBarResponseMode`, `InspectorChatMessage`,
  and `NoteChatInlineResponse`.
- Path check confirmed these are gone: `Epistemos/Views/Chat/ChatView.swift`,
  `Epistemos/App/ChatCoordinator.swift`, `Epistemos/State/ChatState.swift`,
  `Epistemos/State/NoteChatState.swift`, `Epistemos/State/DialogueChatState.swift`,
  `Epistemos/Views/MiniChat`, `Epistemos/ActOsaurus`,
  `Epistemos/Vendor/Osaurus`, and `LocalPackages/osaurus`.

Build status:

- Full app build was attempted after the deletion pass but remains blocked by
  protected `Epistemos/Work/**` errors that this pass intentionally did not
  edit: `WorkOpenWorkSupervisor.swift` / `WorkRuntimeSupervisor.swift` actor
  isolation around `state.resume(...)`, plus missing `harnessID` arguments in
  `WorkPermissionCardView.swift` and `WorkQuestionCardView.swift` previews.
  No non-Work deletion fallout was visible in the filtered diagnostics.

Remaining:

- Do not mark the fusion complete. The old surfaces are removed, but the
  replacement ChatView-2 feel still has to be rebuilt on the AgentClone/fusion
  foundation with provider/tool/MCP/settings/session/history/rollback/usage
  reachability proven.

### Codex continuation 2026-06-25 - native agent cleanup and mascot preservation

Owner clarification: delete the old native Epistemos agent/chat backend and
surface logic, but do not delete the landing-page companion mascots. The mascots
should remain as visual/landing entities only; they must not inject prompts,
model routes, tools, or old runtime preferences into the new AgentClone/fusion
chat path.

Implemented:

- Deleted old native AgentBlueprint/System G files, settings rows, and tests:
  `Epistemos/LocalAgent/AgentBlueprint.swift`, `Epistemos/SystemG/**`,
  `AgentBlueprintSettingsView`, `SystemGHealthRow`, and related System G test
  coverage.
- Removed System G registration/wiring from `AppBootstrap`, settings, substrate
  health surfaces, diagnostics wording, localized strings, and old local-agent
  status breadcrumbs.
- Preserved landing companion mascot creation/editing, but removed provider,
  model, tool, scope, approval, advanced system-prompt, output-schema, and
  runtime-preference routing from the companion path.
- Removed companion prompt injection from `PipelineService`/`AppBootstrap`, and
  made the RootView companion switcher inert so landing mascots are not mounted
  as in-chat runtime selectors.
- Deleted remaining old native chat residue: `ChatTranscriptVaultWriter`, the
  System sidebar `Chat Transcripts` section, and unused old `Views/Chat`
  component files `ContextWindowIndicator`, `DiffPreviewView`,
  `EditorSkillChips`, and `TodoSnapshotCard`.
- Kept the generic `SDChat` SwiftData model because it is not solely the old
  native chat surface: current non-deleted use includes Work worker rows,
  knowledge/intents, vault/history tests, and AI-partner audit persistence.

Verification:

- `swift test --package-path LocalPackages/EpistemosChatDonorContracts`
  passed: 66 tests, 0 failures.
- `Epistemos/Resources/Localizable.xcstrings` parsed successfully with
  `JSONSerialization`.
- Product source scans outside protected `Epistemos/Work/**` returned no hits
  for old native chat/MiniChat/NoteChat/GraphChat route symbols, AgentBlueprint,
  System G symbols, or Osaurus symbols.
- `Epistemos.xcodeproj/project.pbxproj` scan returned no stale references to
  deleted chat, Osaurus, AgentBlueprint, System G, transcript-writer, or unused
  old component files.

Build status:

- Full app build was attempted:
  `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/EpistemosCodexBuild-DeleteOldNativeAgent build`
- The build reached the app target and failed in the `Build Rust Engine` script,
  not in Swift compilation:
  `error: lipo: can't move temporary file: ../build-rust/libgraph_engine.a to file: ../build-rust/libgraph_engine.a.lipo (No such file or directory)`.
  This is recorded as a Rust build artifact/script blocker, not deletion-slice
  Swift fallout.

Remaining:

- The old native backend/surface confusion is now guarded against, but the
  actual ChatView-2 rebuild still has to be implemented on AgentClone/fusion:
  same old ChatView feel, new AgentClone/fusion backend, and full provider/tool/
  MCP/settings/session/history/rollback/usage reachability preserved.

### Codex continuation 2026-06-25 - Rust build script stabilization

Owner clarification remains active: landing companion mascots stay as visual
entities only, while old native chat/backend/Osaurus/System G paths stay
deleted. This slice did not touch protected `Epistemos/Work/**`, AgentClone,
OpenGUI, Goose, OpenCode, MCP/native tool code, or the mascot visuals.

Implemented:

- Fixed the previous full-app build blocker in `build-rust.sh` by writing the
  universal `libgraph_engine.a` to a unique temporary output first, then
  atomically moving it into the stable Xcode path.
- Applied the same temp-output pattern to `build-syntax-core.sh` for
  `libsyntax_core.a`, matching the safer pattern already used by newer Rust
  build scripts.

Verification:

- `CONFIGURATION=Debug ./build-rust.sh` passed.
- `CONFIGURATION=Debug bash ./build-syntax-core.sh` passed.
- `swift test --package-path LocalPackages/EpistemosChatDonorContracts`
  passed: 66 tests, 0 failures.
- Product scans outside protected `Epistemos/Work/**` returned no hits for old
  native chat/MiniChat/NoteChat/GraphChat route symbols, AgentBlueprint/System
  G symbols, or Osaurus symbols.
- `Epistemos.xcodeproj/project.pbxproj` scan returned no stale references to
  deleted old chat, Osaurus, AgentBlueprint/System G, transcript-writer, or old
  component files.

Build status:

- Full app build was retried:
  `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/EpistemosCodexBuild-DeleteOldNativeAgent2 build`
- The Rust build phases completed, including graph-engine, syntax-core,
  omega-mcp, omega-ax, epistemos-core, agent-core, epistemos-shadow, Tiptap, and
  OpenCode runtime staging.
- The build is now blocked later in protected MCP/Work code:
  `Epistemos/Work/WorkNativeMCPServer.swift:75:65: error: main actor-isolated property 'snapshot' can not be referenced from a Sendable closure`.
- Classification: not deletion fallout. `WorkNativeMCPServer.swift` and
  `WorkAppContextSnapshot.swift` were unmodified in git. The issue comes from
  Swift 6 `default-isolation=MainActor` treating `WorkAppContextStore.snapshot`
  as main-actor isolated while `WorkNativeMCPServer` passes it through a
  `@Sendable` context provider. It was left untouched because Work/MCP/native
  tool code is protected by the current directive.

Remaining:

- Resolve the protected Work/MCP actor-isolation blocker with owner-approved
  MCP/native-tool edits, then rerun the full app build.
- Continue the ChatView-2 rebuild on AgentClone/fusion after the build is green:
  old ChatView feel, no old Epistemos chat backend, and full provider/tool/MCP/
  settings/session/history/rollback/usage reachability preserved.

### Codex continuation 2026-06-25 - old chat/Osaurus test guard cleanup

Owner clarification remains active: landing companion/tamagotchi mascots stay
visual, but old native chat, MiniChat, NoteChat, GraphChat, Osaurus, System G,
AgentBlueprint, and pre-fusion native-agent paths must not remain as live chat
requirements. Protected Work/MCP/native skills, AgentClone, OpenGUI, Goose,
OpenCode, and mascot visuals were not edited.

Implemented:

- Removed stale positive source guards and behavioral tests that still required
  deleted old chat files or routes, especially `ChatCoordinator`, `ChatState`,
  `DialogueChatState`, `NoteChatState`, `MiniChat`, `NoteChatSidebar`,
  `CodeAskBar`, `GraphChatRequest`, old `ChatView`, and old `MessageBubble`.
- Deleted old MiniChat and note/graph chat parity tests:
  `EpistemosTests/ThreadStateTests.swift`,
  `EpistemosTests/SSVISNoteSkillRunTests.swift`, and
  `EpistemosTests/SSVISGraphSkillRunTests.swift`.
- Reframed reusable tests to current non-chat behavior where appropriate:
  workspace snapshots now cover notes/live documents/graph route only, HTML
  workspace tests keep parser/security coverage without MiniChat target
  metadata, and local model no-model classification no longer references
  Osaurus.
- Removed test-only `NoteChatInlineResponse` compatibility scaffolding after
  product source no longer contained that native note-chat type.

Verification:

- `swift test --package-path LocalPackages/EpistemosChatDonorContracts`
  passed: 68 tests, 0 failures.
- `git diff --check -- EpistemosTests LocalPackages/EpistemosChatDonorContracts docs/handoffs/CHAT_DONOR_FUSION_DECISION_AND_MAP_2026_06_24.md`
  passed.
- Product source scan outside protected `Epistemos/Work/**` returned no hits
  for `MiniChat`, `NoteChat`, `GraphChat`, `ChatCoordinator`, `Osaurus`,
  `ActOsaurus`, `SystemG`, or `AgentBlueprint`.
- Direct deleted-path scan across `EpistemosTests` returned no hits for old
  native chat/Osaurus source files such as `ChatCoordinator.swift`,
  `ChatState.swift`, `NoteChatState.swift`, `MiniChatView.swift`,
  `NoteChatSidebar.swift`, `CodeAskBar.swift`, `ChatView.swift`,
  `MessageBubble.swift`, `GraphChatRequest.swift`, or old settings rows.
- Remaining old-symbol mentions in tests are negative guard assertions only
  (for example, tests proving Osaurus/MiniChat/ChatCoordinator strings are not
  mounted in product source).

Build status:

- Full app build was not rerun in this slice. The last known full build blocker
  remains the protected Work/MCP actor-isolation error at
  `Epistemos/Work/WorkNativeMCPServer.swift:75`; that area is explicitly
  protected by the current directive.

Remaining:

- If the owner approves MCP/native-tool edits, resolve the protected Work/MCP
  blocker and rerun the full app build.
- Continue with the actual ChatView-2 UI rebuild on the AgentClone/fusion
  backend. This cleanup removes stale old-backend test pressure; it is not the
  visual rebuild finish line.

### Codex continuation 2026-06-25 - landing mascots disconnected from chat/runtime setup

Owner clarification applied: keep the landing companion/tamagotchi mascots as
visual objects, but delete the hidden old setup that made them chat launchers,
per-mascot prompts, model routes, tools, MCP config, approvals, adapter hot-swap
scaffolds, or runtime preferences. Protected `Epistemos/Work/**`, AgentClone,
OpenGUI, Goose, OpenCode, MCP/native skills/tools, and foundational inference
assets were not deleted.

Implemented:

- Removed the landing mascot chat launch path:
  `onStartChat`, `startFarmAgentChat`, the active mascot `CHAT` button, and the
  context-menu "Chat with ..." action are gone from Landing/Farm product code.
- Made `CompanionModel` visual-only. Removed per-companion backend/setup fields:
  prompt/persona, LoRA adapter path, AgentBlueprint model route/display label,
  tool names, scope, approval mode, custom system prompt, output structure, MCP
  server config, memory pinning, tool-selection mode, and autonomous exec config.
- Removed `CompanionState` prompt/runtime helpers and the landing search
  placeholder dependency on the active mascot name.
- Removed the deferred `CompanionAdapterView` hot-swap scaffold and renamed the
  remaining MLX adapter resolver test to generic request-adapter coverage
  (`MLXAdapterOverrideResolutionTests`).
- Deleted the scaffold-only `Epistemos/AgentRuntimeV2/README.md` System
  G/AgentBlueprint marker.
- Updated source guards so the old mascot runtime/setup fields must stay absent
  while mascot create/edit/delete/restore and visual activation remain.

Verification:

- `swift test --package-path LocalPackages/EpistemosChatDonorContracts` passed:
  68 tests, 0 failures.
- `git diff --check` passed for the changed mascot, landing, MLX adapter,
  deleted scaffold, and guard-test files.
- Product scans outside protected `Epistemos/Work/**` returned no hits for old
  native route symbols (`MiniChat`, `NoteChat`, `GraphChat`,
  `ChatCoordinator`, `MainChatSubmissionRouter`, `ActOsaurus`, `Osaurus`,
  `SystemG`, `AgentBlueprint`, `DialogueChatState`).
- Mascot-runtime scan now has only negative guard-test hits for deleted strings
  such as `onStartChat`, `startFarmAgentChat`, `personaPrompt`,
  `agentModelRoutingID`, and `CompanionAdapterView`.

Build status:

- Focused Xcode test attempted:
  `xcodebuild test -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/CompanionAvatarGrammarSourceGuardTests -only-testing:EpistemosTests/Stash17LandingWaveCloseoutTests -only-testing:EpistemosTests/MLXAdapterOverrideResolutionTests`
- It failed before compiling Epistemos tests in dependency target `EventSource`
  with unresolved generated shim modules: `CAsyncHTTPClient`, `CNIOLLHTTP`,
  `CNIOExtrasZlib`, `CNIOPosix`, and `_NumericsShims`. Classification: package
  build/module-cache issue, not mascot deletion fallout.

Remaining:

- Clear the external Xcode package/module-cache blocker, then rerun the focused
  source guards.
- Continue the actual ChatView-2 visual rebuild on AgentClone/fusion. This slice
  deletes the old mascot/native-agent confusion, but it is not the rebuilt chat
  surface.

### Codex continuation 2026-06-25 - deleted unmounted old Chat renderer remnants

Owner clarification applied: the old ChatView look remains the visual language,
but old ChatView-era renderer/backend files must not survive as reusable source.
Protected Work/MCP/native skills/tools, AgentClone, OpenGUI, Goose, OpenCode,
and landing mascot visuals were not edited.

Implemented:

- Deleted unmounted old native chat renderer/remnant files:
  `AgentRunTimelineView`, `AssistantInlineTranscriptView`, `LiveActivityStrip`,
  `ProcessDisclosureViews`, `ThinkingPopoverView`, `ThinkingTrailView`,
  `ContextWindowCompactBadge`, `VaultRecallProvenanceCard`,
  `EidosRetrievedSection`, `VRMLabelView`, `BTMView`, `AnswerPacketBadge`,
  and `ChatBrainPickerMenu`.
- Deleted the old inline transcript renderer unit tests that required the
  removed `AssistantInlineTranscriptBuilder`.
- Removed stale app test pressure that still loaded the already-deleted
  `ChatInputBar.swift`; standalone model/state tests remain where they still
  exercise live code.
- Reframed source guards so those old files are now expected to stay absent,
  including donor-contract deletion guards.
- Kept non-surface primitives still used by newer code, including
  `ToolActivityNarrator`, `TaggedMarkdownTextView`, `ArtifactBlockView`, and
  the model/tool picker primitives.
- Split `MainChatOperatingModePreference` into its own non-surface helper before
  deleting `ChatBrainPickerMenu`, because Landing/settings still need the mode
  preference key and sanitizer.
- Current `Epistemos/Views/Chat/**` survivors are classified KEEP/REVIEW, not
  old ChatView surface: `AgentToolTogglePanel` (Landing capability/MCP/skills
  panel), `ArtifactBlockView`/`TaggedMarkdownTextView` (GenUI/markdown
  rendering), `ComposerCurrentAccessPlan` and `ComposerReferenceBrowser`
  (resource grants/notes browse model), `ComposerMicButton` and
  `ComposerVoiceInputService` (Landing input mic), `InlineRuntimePickerPanel`
  and `MainChatOperatingModePreference` (Landing/settings runtime picker),
  `ModelAboutSheet` (RootView/settings model details), `NotesMentionDropdown`
  (notes/reference picker), `SlashCommandPopover` (Landing slash commands), and
  `ToolActivityNarrator` (tool event labels). These must be revisited only when
  the AgentClone/fusion UI replaces their current callers.

Verification:

- `swift test --package-path LocalPackages/EpistemosChatDonorContracts` passed:
  69 tests, 0 failures.
- `git diff --check` passed for the changed `Views/Chat`, app tests, and donor
  contract test files.
- Reference scans found no product Swift references to the deleted renderer
  symbols outside negative guard tests and historical docs.
- Focused Xcode test was attempted for the touched guard suites. Xcode removed
  stale DerivedData objects for the deleted files, then failed before Epistemos
  test execution in external target `EventSource` with unresolved shim modules:
  `CAsyncHTTPClient`, `CNIOLLHTTP`, `CNIOExtrasZlib`, `CNIOPosix`, and
  `_NumericsShims`. Classification: existing package/module-cache blocker, not
  deletion-slice fallout.

Remaining:

- The actual ChatView-2 surface still needs to be rebuilt inside AgentClone/new
  Swift-agent UI. Do not restore the deleted old renderer files to get there.

### Codex continuation 2026-06-25 - stale donor-audit route references neutralized

Owner guardrail carried forward: old ChatView visual language remains the target
feel, but old native chat/backend route names must not appear in product source
as live implementation guidance.

Implemented:

- Updated `docs/audits/STASH18_AGENT_COMMAND_CENTER_DONOR_SYNTHESIS_2026_05_26.md`
  so the donor audit no longer tells future work to use `ChatCoordinator`,
  `ChatState`, `ChatInputBar`, `MessageBubble`, `MiniChat`, `ChatBrainSnapshot`,
  or `MainChatSubmissionRouter` as current architecture targets.
- Updated `EpistemosTests/Stash18AgentCommandCenterDonorSynthesisTests.swift`
  so it now asserts the audit points at AgentClone/fusion and rejects the stale
  `routes through MainChatSubmissionRouter` wording.
- Removed the final product-source old-route symbol comments from
  `Epistemos/Models/AnswerPacket.swift`.
- Cleaned two stale app-test comments that referred to `ChatState` as a live
  follow-up path.

Verification:

- Product scan outside protected `Epistemos/Work/**` returned no hits for old
  route/surface symbols: `ChatView`, `ChatRouteView`, `ChatSurfaceCoordinator`,
  `ChatCoordinator`, `ChatState`, `DialogueChatState`, `NoteChatState`,
  `MiniChat`, `NoteChat`, `GraphChat`, `MainChatSubmissionRouter`, `Osaurus`,
  `ActOsaurus`, `EpistemosOsaurus`, `SystemG`, `AgentBlueprint`,
  `SharedActInference`, or `ActTurnStreamCore`.
- Remaining app-test hits for those symbols are negative guard assertions only.
- `swift test --package-path LocalPackages/EpistemosChatDonorContracts` passed:
  69 tests, 0 failures.
- `git diff --check` passed for the touched product model, donor audit, tests,
  donor contracts, and handoff files.

### Codex continuation 2026-06-25 - AgentClone host shell and stale chatState anchor removed

Owner correction preserved: the target is still the old ChatView feel, rebuilt
from scratch on the AgentClone/new Swift-agent foundation. This slice does not
restore old ChatView/backend code and does not complete the visual rebuild.

Implemented:

- Added/kept the hosted route shape in `Epistemos/Views/AgentFusion/`:
  `AgentCloneAppContextSnapshot.swift` carries bounded app context, and
  `AgentCloneChatHostSurface.swift` embeds `AgentClone.ContentView()` with
  Epistemos-owned session/context rails, compact rail toggles, and no standard
  Chat `Overseer`/`Execution Plan` diagnostic panel.
- `RootView.chatModeSurface` now mounts `AgentCloneChatHostSurface(context:
  agentCloneContextSnapshot, onSyncHostContext: syncAgentCloneHostContext)`
  after `AgentClone.AgentSkin.configure(...)`. `syncAgentCloneHostContext()`
  derives `AgentCloneHostContext` from the snapshot instead of from old native
  chat state.
- Removed the stale `AppBootstrap.chatState` anchor from
  `CaptureBrainDumpIntent`; raw-thought capture now anchors to the active note
  or to `AgentChatState.activeSessionId` as `agent-session`.
- Updated app source-guard tests that still required deleted `chatState`
  behavior, and tightened donor-contract guards/provenance around the snapshot
  host shell.
- Preserved landing companion mascot visuals and avoided `Epistemos/Work/**`,
  OpenGUI/Goose/OpenCode/OpenWork clone work, MCP/native skills/tools, and
  `LocalPackages/AgentClone/**` internals.

Verification:

- `swift test --package-path LocalPackages/EpistemosChatDonorContracts` passed:
  70 tests, 0 failures.
- `jq empty docs/donor-contracts/swift-chat/agent-clone/provenance.json`
  passed.
- `git diff --check` passed for the touched host shell, intent, app tests,
  donor contracts, donor provenance, and Work canon doc.
- Live `bootstrap.chatState` scan now has only negative app-test assertions.
- Full app build was rerun:
  `xcodebuild build -project Epistemos.xcodeproj -scheme Epistemos -destination
  'platform=macOS' -derivedDataPath /tmp/EpistemosCodexBuild-AgentCloneHostShell
  -quiet`. It progressed through dependencies, AgentClone, Rust asset scripts,
  and Epistemos Swift compilation, then failed in protected Work code:
  `Epistemos/Work/WorkSPASchemeHandler.swift:97:9: error: missing return in
  static method expected to return 'HTTPURLResponse'`. This was not edited
  because `Epistemos/Work/**` is protected for this deletion/chat route pass.

Remaining:

- Fix or have the Work/OpenGUI lane fix `WorkSPASchemeHandler.makeResponse`
  before the full app build can be used as end-to-end proof.
- Continue the actual ChatView-feel rebuild inside the hosted AgentClone/fusion
  surface: native title/toolbar, old-style side/session flow, message
  bar/composer rhythm, model picker, transcript feel, mini-session behavior,
  and provider/tool/MCP/settings/history/rollback/usage reachability. Do not
  restore deleted old chat backend files to get there.

### Codex continuation 2026-06-25 - note chat and vault chat hooks removed

Owner correction carried forward: delete the old native chat engines and
surfaces, but preserve landing companion/mascot visuals as visual assets. This
slice did not touch `Epistemos/Work/**`, MCP/native skills, AgentClone internals,
OpenGUI/Goose/OpenCode/OpenWork clone work, or the landing mascot views/assets.

Implemented:

- Removed the stale vault-disconnect call to
  `AppBootstrap.shared?.chatState.clearMessages()` from
  `Epistemos/Sync/VaultSyncService.swift`.
- Removed the old NotesSidebar "Summary" and "Deep Dive" actions that inserted
  note ids into `chatState.loadedNoteIds` and submitted prompts through the
  deleted native chat route. Notes organization, editor opening, and Graph
  reveal actions remain intact.
- Tightened donor guard tests so `VaultSyncService` cannot regain the old
  `AppBootstrap.shared?.chatState` hook and `NotesSidebar` cannot regain the
  deleted note-chat prompt actions.

Verification:

- Non-protected product-source scan returned no hits for word-boundary
  `ChatState`, `ChatView(`, `ChatRouteView(`, `ChatSurfaceCoordinator`,
  `ChatCoordinator(`, `DialogueChatState`, `NoteChatState`, `MiniChat`,
  `GraphChatRequest`, `NoteChatSidebar`, `ActOsaurus`, `EpistemosOsaurus`,
  `OsaurusCore`, `AgentBlueprint`, or `SystemG`.
- Focused scan of the touched vault/sidebar files returned no hits for
  `AppBootstrap.shared?.chatState`, `chatState.loadedNoteIds`,
  `chatState.submitQuery`, `@Environment(ChatState.self)`, `case summarize(`, or
  `case deepDive(`.
- `swift test --package-path LocalPackages/EpistemosChatDonorContracts` passed:
  70 tests, 0 failures.
- `git diff --check` passed for the touched vault/sidebar/donor-test files.
- Full app build was attempted with
  `xcodebuild build -project Epistemos.xcodeproj -scheme Epistemos -destination
  'platform=macOS' -derivedDataPath
  /tmp/EpistemosCodexBuild-OldChatDeletionSlice -quiet`. It failed in protected
  Work code at `Epistemos/Work/WorkSPASchemeHandler.swift:97:9`: missing
  `return` in a static method expected to return `HTTPURLResponse`. This was
  left untouched because `Epistemos/Work/**` is protected for this pass.

Remaining:

- The visual ChatView-2 rebuild still needs to happen inside the hosted
  AgentClone/fusion surface. Do not restore old Notes/Mini/Graph chat surfaces or
  old Epistemos chat backend glue to achieve that look.

### Codex continuation 2026-06-25 - Epistemos agent portal context spine

Owner target carried forward: Landing, main agent, Mini, Graph, Note, Vault,
tools, skills, recents, sessions, and permissions should become one Epistemos
agent/session/context system on the AgentClone/new Swift-agent foundation. This
slice starts that product substrate; it is not the final visual ChatView-2
rebuild.

Implemented:

- Added `AgentPortalContextSnapshot` as bounded Epistemos-owned value data for
  `main`, `landing`, `mini`, `note`, `graph`, and `vault` portals. It carries
  session id, prompt preview, typed note/graph/vault context, approved actions,
  deterministic JSON/summary strings, and live `ContextAttachment` handles for
  app-owned resources.
- Extended `AgentChatState` with `activePortalContext`, session seeding via
  `startNewSession(portalContext:)`, portal-aware `submitAgentQuery`, and reset
  cleanup. User messages now carry bounded context attachments from the active
  portal instead of relying on old `ChatState`/note-chat glue.
- Extended `AgentCloneAppContextSnapshot` with `portalContext`,
  `bridgePresentation`, and a shared `defaultAppSupportPath(appName:)` helper so
  both RootView and Landing keep AgentClone sessions under Epistemos app-support
  storage.
- Updated Landing submission to create a `.landing` portal context, seed
  `AgentChatState`, publish AgentClone host context with portal/session/action
  metadata, then submit the prompt through `AgentCloneBridge`.
- Updated `AgentCloneChatHostSurface` rails to expose the active portal,
  session, and approved-action summary without showing old Overseer/diagnostic
  panels.
- Updated donor contracts, source guard tests, and AgentClone provenance so the
  portal context spine is tracked as part of the AgentClone route work.

Verification:

- `swift test --package-path LocalPackages/EpistemosChatDonorContracts` passed:
  70 tests, 0 failures.
- Source scans of the touched non-Work product files found no restored old
  `ChatRouteView`, `ChatSurfaceCoordinator`, `DialogueChatState`,
  `NoteChatState`, `GraphChatRequest`, `NoteChatSidebar`, Osaurus, SystemG, or
  AgentBlueprint route symbols; remaining hits are current `AgentChatState` or
  negative guard assertions.
- `git diff --check` passed for the touched portal/context/app/test files.

Remaining:

- Wire `.note`, `.graph`, and `.mini` portal creation from their future rebuilt
  surfaces into the same `AgentPortalContextSnapshot` path. Do not reintroduce
  old NoteChat, GraphChat, MiniChat, or old ChatView backend files.

### Codex continuation 2026-06-25 - old portal deletion guard tightened

Owner correction carried forward: the desired UI language is ChatView-2, but
the old native ChatView-era backend/surface path is not allowed back. Mini,
Graph, Note, Landing, and Vault should become portals into the new
AgentClone/Swift-agent fusion route through Epistemos-owned context, not private
old engines.

Implemented:

- Added an app source guard in
  `EpistemosTests/ActSurfaceOsaurusUIDirectionGuardTests.swift` that asserts the
  old native portal files stay deleted: `ChatCoordinator`, `ChatState`,
  `DialogueChatState`, `NoteChatState`, old `ChatView`, `ChatInputBar`,
  `ChatSidebarView`, old `MiniChat`, old `GraphChatRequest`, old
  `NoteChatSidebar`/`CodeAskBar`, Osaurus bridge/vendor files,
  `AgentBlueprint`, and `SystemG`.
- The same guard scans Root/App/Landing/Graph/Notes/Settings/project wiring for
  stale launch symbols while allowing the new `AgentChatState` and
  `AgentPortalContextSnapshot` route.
- Verified `AgentPortalContextSnapshot` remains the allowed bridge point for
  `main`, `landing`, `mini`, `note`, `graph`, and `vault` portal kinds with
  bounded context attachments.

Verification:

- Mirrored the new guard with a shell source scan: the deleted files are absent,
  the routed source/project files have no old route symbols, and the new portal
  context still exposes the expected portal cases and context attachments.
- `swift test --package-path LocalPackages/EpistemosChatDonorContracts` passed:
  70 tests, 0 failures.
- App-level Swift Testing could not be run independently with `swift test`
  because the app is Xcode-backed, not a root SwiftPM package.
- Full app build was rerun with
  `xcodebuild build -project Epistemos.xcodeproj -scheme Epistemos -destination
  'platform=macOS' -derivedDataPath /tmp/EpistemosCodexBuild-AgentPortalContext
  -quiet`. It failed in protected Work/OpenWork code:
  `Epistemos/Work/WorkOpenWorkSupervisor.swift:177:39` and `:180:53`
  reference main-actor-isolated static `port` from a nonisolated context. This
  was left untouched because `Epistemos/Work/**` and OpenGUI/OpenWork work are
  protected for this chat-fusion pass.

Remaining:

- Continue the visible ChatView-2 rebuild in the AgentClone/fusion host:
  replicate the old Epistemos chat feel from scratch while preserving the new
  runtime/provider/tool/MCP/session foundation.
- Build future `.mini`, `.graph`, and `.note` portals against
  `AgentPortalContextSnapshot`; do not restore old MiniChat, GraphChat,
  NoteChat, ChatState, ChatCoordinator, Osaurus, AgentBlueprint, or SystemG.

### Codex continuation 2026-06-25 - stale corpus and note portal identity cleanup

Owner correction carried forward: old MiniChat, GraphChat, and NoteChat are not
allowed to survive as hidden engines. The target remains a rebuilt ChatView-2
visual language on the AgentClone/Swift-agent foundation, with mini/note/graph
as future portals into the unified agent system.

Implemented:

- Renamed the remaining live local-selection surface identity from
  `noteChat` to `noteAgentPortal` in `LocalModelSelectionSurface` and
  `TriageService`, preserving note-operation routing while removing the old
  NoteChat surface name from app code.
- Updated `TriageServiceTests` to target `.noteAgentPortal` instead of the old
  `.noteChat` case.
- Tightened the donor deletion guard so app source and MOHAWK assets reject
  generic `NoteChat`/`noteChat` tokens, not only deleted `NoteChatState` and
  `NoteChatSidebar` files.
- Cleaned stale generated MOHAWK training data that still taught deleted old
  surfaces and methods:
  `composed_training_data/train.jsonl` removed 2 rows,
  `epistemos_training_data` removed 54 rows across code graph/symbol/eval/train,
  `epistemos_training_data_validated` removed 42 rows, and
  `embodied_data/app_code_graph.json` removed 24 stale nodes plus 30 edges.

Verification:

- Source scans found no banned old native chat or Osaurus symbols in app source
  outside protected `Epistemos/Work/**`, `LocalPackages/AgentClone/**`,
  MOHAWK generated assets, and docs.
- MOHAWK generated-asset scan found no banned old native chat or Osaurus tokens
  across `*.py`, `*.jsonl`, and `*.json`.
- JSON validation passed for 49 MOHAWK `jsonl` files and 5 `json` files.
- `swift test --package-path LocalPackages/EpistemosChatDonorContracts` passed:
  71 tests, 0 failures.
- Full app build was rerun with
  `xcodebuild build -project Epistemos.xcodeproj -scheme Epistemos -destination
  'platform=macOS' -derivedDataPath /tmp/EpistemosCodexBuild-DeletedChatGuard
  -quiet`. It still fails in protected Work/OpenWork code at
  `Epistemos/Work/WorkOpenWorkSupervisor.swift:177:39` and `:180:53`
  because `Self.port` is main-actor-isolated and referenced from a nonisolated
  context. This was left untouched because Work/OpenGUI/OpenWork are protected
  for this pass.

Remaining:

- The next visible-product slice should rebuild the main AgentClone chat host
  toward the old ChatView-2 feel, not mount old ChatView or revive old backend
  glue.
- Future mini/note/graph entry points should be new
  `AgentPortalContextSnapshot` portals and must not reintroduce private
  MiniChat, NoteChat, GraphChat, ChatState, or ChatCoordinator stacks.

### Codex continuation 2026-06-25 - standard chat host opens chat-first

Owner correction carried forward: the standard Chat view must not foreground
Overseer/routing/request/execution-plan diagnostics. The old ChatView-2 feel is
the target visual language, but the implementation remains the protected
AgentClone/Swift-agent foundation inside an Epistemos-owned host.

Implemented:

- Updated `Epistemos/Views/AgentFusion/AgentCloneChatHostSurface.swift` so the
  desktop session and context rails default closed:
  `showSessionRail = false` and `showContextRail = false`.
- Kept the rail toggle buttons mounted, so session/context/model/vault/action
  details remain reachable through progressive disclosure instead of occupying
  the primary standard-chat surface.
- Changed the on-demand grounding row from `Snapshot` to `Model`, keeping the
  rail oriented around model/context inspection rather than old diagnostic panel
  language.
- Strengthened the donor guard test so standard Chat asserts the rails default
  closed, the Model/Vault/Actions details remain reachable, and `ROUTING`,
  `REQUEST`, `Execution Plan`, and `Overseer` do not appear in the host source.

Verification:

- Source scan across `Epistemos/Views/AgentFusion`, `RootView`, and
  `LandingView` found no old diagnostics or old chat/Osaurus route tokens:
  `ROUTING`, `REQUEST`, `Execution Plan`, `Overseer`, `ChatRouteView(`,
  `ChatSurfaceCoordinator`, `ChatCoordinator`, `NoteChat`, `MiniChat`,
  `GraphChat`, `ActOsaurus`, `EpistemosOsaurus`, `Osaurus`, `AgentBlueprint`,
  or `SystemG`.
- `git diff --check` passed for the touched host and guard files.
- `swift test --package-path LocalPackages/EpistemosChatDonorContracts` passed:
  71 tests, 0 failures.
- Full app build was not rerun for this small host-default slice because the
  previous verification in this same continuation already reproduced the
  protected Work/OpenWork actor-isolation blocker at
  `Epistemos/Work/WorkOpenWorkSupervisor.swift:177:39` and `:180:53`; that
  file remains out of scope for this chat-fusion pass.

Remaining:

- Continue rebuilding the visible AgentClone chat shell toward old ChatView-2
  parity: native title/toolbar feel, side-panel behavior, transcript/message
  rhythm, model picker, recents/session flow, and composer polish, all without
  reviving old ChatView/backend code.

### Codex continuation 2026-06-25 - native title toolbar host band

Owner correction carried forward: the target is the old Epistemos Chat feel
rebuilt from scratch on the AgentClone/Swift-agent foundation. This slice adds
an Epistemos-owned native title/toolbar frame around the protected clone
content instead of editing `LocalPackages/AgentClone/**` or restoring old
ChatView.

Implemented:

- Added `chatHostToolbar(compact:)` to
  `Epistemos/Views/AgentFusion/AgentCloneChatHostSurface.swift`.
- The host now starts with an Epistemos title/status band (`Epistemos` from the
  app context plus `ready`) above the embedded `AgentClone.ContentView()`.
- Moved the model/context affordance into that native host band with a
  `model` button that opens the context rail through `toggleContextRail`.
- Kept session/context rail icon controls in the toolbar, so side/session
  details remain reachable while the primary chat surface stays clean.
- Kept the rails default closed and left AgentClone internals untouched.
- Strengthened the donor guard to require the native host toolbar, model button,
  toolbar-mounted rail controls, and the absence of old diagnostic strings.

Verification:

- Source scan across `Epistemos/Views/AgentFusion`, `RootView`, and
  `LandingView` found no old diagnostics or old chat/Osaurus route tokens:
  `ROUTING`, `REQUEST`, `Execution Plan`, `Overseer`, `ChatRouteView(`,
  `ChatSurfaceCoordinator`, `ChatCoordinator`, `NoteChat`, `MiniChat`,
  `GraphChat`, `ActOsaurus`, `EpistemosOsaurus`, `Osaurus`, `AgentBlueprint`,
  or `SystemG`.
- `git diff --check` passed for the touched host, guard, and handoff files.
- `swift test --package-path LocalPackages/EpistemosChatDonorContracts` passed:
  71 tests, 0 failures.

Remaining:

- Continue the visible rebuild by tightening transcript/message rhythm and the
  composer/model-picker surface around the protected AgentClone runtime, still
  without restoring old ChatView/backend files.

### Codex continuation 2026-06-25 - toolbar session control

Owner correction carried forward: old ChatView is the visual language target,
not the implementation source. The backend foundation remains the protected
AgentClone/Swift-agent fusion path, with old native ChatView, MiniChat,
GraphChat, NoteChat, Osaurus, AgentBlueprint, and SystemG routes kept deleted
or guarded away.

Implemented:

- Added `sessionControlButton(compact:)` to
  `Epistemos/Views/AgentFusion/AgentCloneChatHostSurface.swift`.
- The Epistemos-owned host toolbar now exposes a `session` control with the
  clipped `context.portalContext.sessionId`, making session identity visible in
  the primary chrome without opening an old recents/session backend.
- Added `toggleSessionRail(compact:)` so the toolbar session control drives the
  existing AgentFusion session rail on desktop and compact layouts.
- Kept the model/context button beside the session control and left
  `LocalPackages/AgentClone/**`, `Epistemos/Work/**`, OpenGUI, Goose, and
  OpenCode paths untouched.
- Strengthened the donor guard tests to require the session toolbar control,
  clipped portal session id, and session rail toggle while continuing to reject
  old diagnostics and legacy chat routes in the live host.

Verification:

- Source scan across `Epistemos/Views/AgentFusion`, `RootView`, and
  `LandingView` found no old diagnostics or old chat/Osaurus route tokens:
  `ROUTING`, `REQUEST`, `Execution Plan`, `Overseer`, `ChatRouteView(`,
  `ChatSurfaceCoordinator`, `ChatCoordinator`, `NoteChat`, `MiniChat`,
  `GraphChat`, `ActOsaurus`, `EpistemosOsaurus`, `Osaurus`, `AgentBlueprint`,
  or `SystemG`.
- `git diff --check` passed for the touched host, guard, and handoff files.
- `swift test --package-path LocalPackages/EpistemosChatDonorContracts` passed:
  71 tests, 0 failures.

Remaining:

- Continue the visible rebuild toward ChatView-2 parity by replacing the donor
  foreground rhythm with Epistemos-owned transcript, composer, model picker,
  and recents/session affordances backed by AgentClone/fusion state only.

### Codex continuation 2026-06-25 - bridge composer dock

Owner correction carried forward: the old ChatView composer is a visual
language target only. This slice does not restore old ChatView, old
`ChatState`, old native Mini/Graph/Note chat, Osaurus, AgentBlueprint, or
SystemG. It keeps the protected AgentClone runtime mounted and adds an
Epistemos-owned foreground composer that submits into the current fusion path.

Implemented:

- Added an Epistemos-owned bottom `bridgeComposerDock(compact:)` overlay in
  `Epistemos/Views/AgentFusion/AgentCloneChatHostSurface.swift`.
- The dock uses the flat ChatView-2-like message bar rhythm: vault/context chip,
  monospaced prompt field, plus/new-session control, model/session chips, and
  an icon send button.
- The dock does not create a private backend. Submit now:
  - starts/updates the current `AgentChatState` portal session,
  - records the user query in the new agent-session spine,
  - updates `AgentCloneBridge` host context with Epistemos workspace/vault/app
    support paths,
  - calls `AgentCloneBridge.submitPrompt(trimmed)` so AgentClone remains the
    execution foundation.
- Added `startNewBridgeSession()` for the composer plus button, backed by
  `AgentChatState.startNewSession(portalContext:)` and bridge context sync.
- Left `LocalPackages/AgentClone/**`, `Epistemos/Work/**`, OpenGUI, Goose, and
  OpenCode untouched.
- Strengthened donor guard tests so the host must keep the bridge composer,
  AgentChatState session spine, AgentClone bridge submission, and flat non-glass
  styling while still rejecting old diagnostics/routes.

Verification:

- Source scan across `Epistemos/Views/AgentFusion`, `RootView`, and
  `LandingView` found no old diagnostics or old chat/Osaurus route tokens:
  `ROUTING`, `REQUEST`, `Execution Plan`, `Overseer`, `ChatRouteView(`,
  `ChatSurfaceCoordinator`, `ChatCoordinator`, `NoteChat`, `MiniChat`,
  `GraphChat`, `ActOsaurus`, `EpistemosOsaurus`, `Osaurus`, `AgentBlueprint`,
  or `SystemG`.
- `git diff --check` passed for the touched host, guard, and handoff files.
- `swift test --package-path LocalPackages/EpistemosChatDonorContracts` passed:
  71 tests, 0 failures.
- `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -configuration Debug
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build` was attempted
  twice and failed before the Epistemos target on package module resolution in
  `EventSource`: `CAsyncHTTPClient`, `CNIOLLHTTP`, `CNIOExtrasZlib`,
  `CNIOPosix`, and `_NumericsShims`.

Remaining:

- Continue replacing foreground donor rhythm with Epistemos-owned transcript
  and model/session controls, but do not fake assistant output until AgentClone
  exposes a safe public transcript/event facade or an equivalent fused runtime
  bridge exists.

### Codex continuation 2026-06-25 - real-state transcript runway

Owner correction carried forward: the target is the old Epistemos Chat feel
rebuilt on the new AgentClone/fusion foundation. This slice adds visible
ChatView-2-like transcript rhythm without restoring old ChatView, old
`ChatState`, old MiniChat/GraphChat/NoteChat, Osaurus, AgentBlueprint, or
SystemG.

Implemented:

- Added `bridgeTranscriptRunway(compact:)` above the Epistemos-owned composer in
  `Epistemos/Views/AgentFusion/AgentCloneChatHostSurface.swift`.
- The runway renders only real `AgentChatState` data:
  `agentChat.messages.suffix(4)`, `message.effectiveText`, `message.isError`,
  `agentChat.streamingText`, `agentChat.activeToolName`, and runtime flags.
- The runway shows compact user/assistant/live rows with monospaced user chrome
  and a plain assistant text style, moving the foreground toward old ChatView
  ontology while preserving the protected AgentClone runtime under the host.
- No simulated assistant output was added. If AgentClone has not exposed a safe
  public response stream yet, the runway shows only the app-owned prompt/session
  state and live fields already present in `AgentChatState`.
- Kept `LocalPackages/AgentClone/**`, `Epistemos/Work/**`, OpenGUI, Goose, and
  OpenCode untouched.
- Strengthened donor guard tests so the host must keep the transcript runway
  backed by `AgentChatState` and must not add simulated/fake responses or old
  diagnostics/routes.

Verification:

- Source scan across `Epistemos/Views/AgentFusion`, `RootView`, and
  `LandingView` found no old diagnostics or old chat/Osaurus route tokens:
  `ROUTING`, `REQUEST`, `Execution Plan`, `Overseer`, `ChatRouteView(`,
  `ChatSurfaceCoordinator`, `ChatCoordinator`, `NoteChat`, `MiniChat`,
  `GraphChat`, `ActOsaurus`, `EpistemosOsaurus`, `Osaurus`, `AgentBlueprint`,
  or `SystemG`.
- `git diff --check` passed for the touched host, guard, and handoff files.
- `swift test --package-path LocalPackages/EpistemosChatDonorContracts` passed:
  71 tests, 0 failures.
- Full app build was not re-run for this handoff entry. The prior attempt in
  this continuation still failed before the Epistemos target on package module
  resolution in `EventSource`: `CAsyncHTTPClient`, `CNIOLLHTTP`,
  `CNIOExtrasZlib`, `CNIOPosix`, and `_NumericsShims`.

Remaining:

- Continue the foreground rebuild by exposing a real AgentClone/fusion
  transcript/event facade into Epistemos-owned UI. Do not fake assistant
  responses and do not restore the old native chat backend.

### Codex continuation 2026-06-25 - persisted AgentClone session mirror

Owner correction carried forward: ChatView-2 is the visual/ontology target, not
the backend. This slice keeps AgentClone/fusion as the execution foundation and
adds a bounded Epistemos-owned readback path for real AgentClone persisted
output without restoring old ChatView, old `ChatState`, MiniChat/GraphChat/
NoteChat engines, Osaurus, AgentBlueprint, or SystemG.

Implemented:

- Added a persisted-session mirror to
  `Epistemos/Views/AgentFusion/AgentCloneChatHostSurface.swift`.
- On bridge composer submit, the host now starts a bounded 120-second mirror
  task that reads real AgentClone JSONL session files from the Epistemos
  app-support `sessions` directory after the submit timestamp.
- The mirror scans on a detached utility task, caps candidate files at 1 MB,
  reads only recent `*.jsonl` files, keeps the newest bounded messages, and
  updates SwiftUI state from a view-owned main-actor task.
- The transcript runway now renders mirrored assistant/tool output rows from
  persisted AgentClone session data when available. No simulated assistant
  output or fake success path was added.
- The host still submits prompts through `AgentCloneBridge.submitPrompt(trimmed)`
  and still keeps Epistemos `AgentChatState` as the app-owned portal/session
  spine.
- Left `LocalPackages/AgentClone/**`, `Epistemos/Work/**`, OpenGUI, Goose,
  OpenCode, MCP/native skills, and landing mascots untouched.
- Strengthened donor guard tests so the host must keep the bounded
  app-support `sessions/*.jsonl` mirror, off-main scan, main-actor UI update,
  and no old diagnostics/routes.

Verification:

- Source scan across `Epistemos/Views/AgentFusion`, `RootView`, and
  `LandingView` found no old diagnostics or old chat/Osaurus route tokens:
  `ROUTING`, `REQUEST`, `Execution Plan`, `Overseer`, `ChatRouteView(`,
  `ChatSurfaceCoordinator`, `ChatCoordinator`, `NoteChat`, `MiniChat`,
  `GraphChat`, `ActOsaurus`, `EpistemosOsaurus`, `Osaurus`, `AgentBlueprint`,
  or `SystemG`.
- `git diff --check` passed for the touched host and guard files.
- `swift test --package-path LocalPackages/EpistemosChatDonorContracts` passed:
  71 tests, 0 failures.
- `xcodebuild -list -project Epistemos.xcodeproj` resolved the project and
  confirmed the `Epistemos` scheme.
- `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -configuration Debug
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build` was attempted and
  failed before the Epistemos target in `EventSource`: unable to resolve module
  dependencies `CAsyncHTTPClient`, `CNIOLLHTTP`, `CNIOExtrasZlib`, `CNIOPosix`,
  and `_NumericsShims`.

Remaining:

- Replace the persisted JSONL mirror with a stronger public AgentClone/fusion
  event facade when available, so transcript streaming no longer depends on
  polling session files.
- Continue rebuilding the foreground toward true ChatView-2 parity: Epistemos
  transcript, composer, model picker, recents/session rail, mini/graph/note
  portals, and vault tools all backed by the unified AgentClone/fusion system,
  not the deleted native chat engines.

### Codex continuation 2026-06-25 - host composer model and voice controls

Owner correction carried forward: delete old native chat engines/surfaces, but
do not delete current Epistemos feature controls merely because they live under
`Views/Chat` or contain `Chat` in the name. In this pass, the remaining
`Views/Chat` files were classified by references before editing. The old route
files (`ChatView`, `ChatInputBar`, `ChatSidebarView`, old MiniChat, old
NoteChat, graph-chat request) are deleted, while the still-referenced controls
are shared feature controls: inline model picker, voice button, slash menu,
vault mention/reference browser, tool panel, artifact renderer, and tool
narration.

Implemented:

- Added the same persisted Epistemos operating-mode preference used by Landing
  to `Epistemos/Views/AgentFusion/AgentCloneChatHostSurface.swift` via
  `@AppStorage(MainChatOperatingModePreference.defaultsKey)`.
- Added `InferenceState` and `openSettings` environment access to the
  AgentClone-backed host so it can mount the existing `InlineRuntimePickerPanel`
  without creating a second private model picker.
- Added a ChatView-2-like model chip to the bridge composer. It expands the flat
  inline runtime picker inside the host composer and collapses after a pick.
- Added `ComposerMicButton` beside send; voice transcription appends into the
  AgentClone-bound prompt field through `appendBridgeVoiceTranscript(_:)`.
- Kept prompt execution unchanged: submit still records the Epistemos
  `AgentChatState` portal turn, syncs `AgentCloneBridge` host context, starts
  the bounded session mirror, and calls `AgentCloneBridge.submitPrompt(trimmed)`.
- Left `LocalPackages/AgentClone/**`, `Epistemos/Work/**`, OpenGUI, Goose,
  OpenCode, MCP/native skills, and landing mascots untouched.
- Strengthened donor guard tests so the host must keep `InlineRuntimePickerPanel`,
  `ComposerMicButton`, the shared operating-mode preference, and the AgentClone
  submit path while still rejecting old diagnostics/routes.

Verification:

- Source scan across `Epistemos/Views/AgentFusion`, `RootView`, and
  `LandingView` found no old diagnostics or old chat/Osaurus route tokens:
  `ROUTING`, `REQUEST`, `Execution Plan`, `Overseer`, `ChatRouteView(`,
  `ChatSurfaceCoordinator`, `ChatCoordinator`, `NoteChat`, `MiniChat`,
  `GraphChat`, `ActOsaurus`, `EpistemosOsaurus`, `Osaurus`, `AgentBlueprint`,
  or `SystemG`.
- `git diff --check` passed for the touched host and guard files.
- `swift test --package-path LocalPackages/EpistemosChatDonorContracts` passed:
  71 tests, 0 failures.
- `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -configuration Debug
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build` still failed
  before the Epistemos target in `EventSource`: unable to resolve module
  dependencies `CAsyncHTTPClient`, `CNIOLLHTTP`, `CNIOExtrasZlib`, `CNIOPosix`,
  and `_NumericsShims`. No `AgentCloneChatHostSurface` diagnostic was reached.

Remaining:

- Add the next ChatView-2 foreground control slice to the AgentClone host:
  slash command/skill priming and vault mention attachment, again backed by
  `AgentChatState` + `AgentCloneBridge`, not the deleted native chat backend.
- Eventually move or rename shared `Views/Chat` helper controls into an
  AgentFusion/shared-controls namespace if doing so can be done without breaking
  Landing/Settings/GenUI feature reachability.

### Codex continuation 2026-06-25 - host slash and vault context controls

Owner correction carried forward: the old ChatView is a visual/ontology
reference only. This slice keeps execution on the protected AgentClone/fusion
route and adds ChatView-2-style context controls to that host, without
restoring old `ChatView`, old native chat coordinators, MiniChat/GraphChat/
NoteChat engines, Osaurus, AgentBlueprint, or SystemG.

Implemented:

- Added bounded `additionalContextAttachments` to
  `Epistemos/Views/AgentFusion/AgentPortalContextSnapshot.swift`, including a
  `withAdditionalContextAttachments(_:)` helper and deduped attachment
  projection into `contextAttachments`, `bridgePresentation`, and
  `modelVisibleSummary`.
- Added slash/skill priming to
  `Epistemos/Views/AgentFusion/AgentCloneChatHostSurface.swift` via the shared
  `SlashCommandPopover` and `AgentCommandCenterState` skill catalog.
- Added `@` note/vault mention search using `ComposerReferencePopover`,
  `ComposerReferenceSearchState`, `VaultSyncService`, and SwiftData
  `modelContext`, with selected references turned into app-owned
  `ContextAttachment` values.
- Added an all-notes vault context toggle and removable attachment chips to the
  bridge composer dock.
- Submit now derives a `bridgePortalContext` from
  `context.portalContext.withAdditionalContextAttachments(bridgeContextAttachments)`
  and passes it through `AgentChatState.submitAgentQuery`; runtime execution
  remains `AgentCloneBridge.submitPrompt(trimmed)`.
- The submit path now explicitly syncs
  `agentChat.activePortalContext ?? portalContext` into `AgentCloneHostContext`
  before posting `AgentCloneBridge.submitPrompt(trimmed)`, so the exact
  selected vault/skill context reaches AgentClone's prompt prefix path instead
  of existing only as UI chrome.
- `onAppear` now syncs the AgentClone host context and refreshes the skill
  catalog, so slash controls are backed by current app skills.
- Left `LocalPackages/AgentClone/**`, `Epistemos/Work/**`, OpenGUI, Goose,
  OpenCode, MCP/native skills, and landing mascots untouched.
- Strengthened donor guard tests so the host must keep slash/skill controls,
  vault mention controls, removable context chips, additional portal
  attachments, and the AgentClone submit path while still rejecting old
  diagnostics/routes.

Verification:

- Source scan across `Epistemos/Views/AgentFusion`, `RootView`, and
  `LandingView` found no old diagnostics or old chat/Osaurus route tokens:
  `ROUTING`, `REQUEST`, `Execution Plan`, `Overseer`, `ChatRouteView(`,
  `ChatSurfaceCoordinator`, `ChatCoordinator`, `NoteChat`, `MiniChat`,
  `GraphChat`, `ActOsaurus`, `EpistemosOsaurus`, `Osaurus`, `AgentBlueprint`,
  or `SystemG`.
- `git diff --check` passed for the touched host, portal snapshot, and guard
  files before this handoff entry was appended.
- `swift test --package-path LocalPackages/EpistemosChatDonorContracts` passed
  after the slash/context slice and again after the explicit submit-order sync:
  71 tests, 0 failures.
- `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -configuration Debug
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build` was attempted
  and still failed before the Epistemos target in `EventSource`: unable to
  resolve module dependencies `CAsyncHTTPClient`, `CNIOLLHTTP`,
  `CNIOExtrasZlib`, `CNIOPosix`, and `_NumericsShims`. No
  `AgentCloneChatHostSurface` or `AgentPortalContextSnapshot` diagnostic was
  reached in the filtered output.

Remaining:

- Keep moving foreground parity toward real ChatView-2 feel on top of
  AgentClone/fusion: transcript stream facade, recents/session rail, and
  Mini/Graph/Note portals as shared agent-session portals, not separate old
  engines.

### Codex continuation 2026-06-25 - Mini/Note/Graph portal context values

Owner correction carried forward: MiniChat, Graph Chat, and Note Chat should
not come back as old Epistemos-native engines. They need typed context portals
into the shared AgentClone/fusion session system. This slice adds the bounded
value-layer seam for those portals without touching protected Work/OpenGUI/
Goose/OpenCode/AgentClone/MCP code and without restoring old chat surfaces.

Implemented:

- Added `ContextAttachmentKind.graph` in `Epistemos/Models/ChatTypes.swift`
  with a graph-specific symbol.
- Updated `ComposerCurrentAccessPlan.detail(for:)` so graph attachments show
  as selected graph context instead of being unsupported.
- Added `AgentPortalContextSnapshot.mini(...)`,
  `AgentPortalContextSnapshot.note(...)`, and
  `AgentPortalContextSnapshot.graph(...)` constructors in
  `Epistemos/Views/AgentFusion/AgentPortalContextSnapshot.swift`.
- The note portal constructor carries note id/title/path, selected text,
  visible excerpt, backlinks, tags, vault root, workspace path, and approved
  note/vault/session/skill actions.
- The graph portal constructor carries graph route, selected node ids,
  selected edge ids, neighborhood summary, vault root, workspace path, and
  approved graph read/neighborhood/mutate-with-approval actions.
- `bridgePresentation` and `modelVisibleSummary` now include bounded note and
  graph details so AgentClone's host-context prompt prefix receives more than a
  generic portal label.
- `contextAttachments` now emits a live `epistemos://graph/context`
  attachment for graph portals, with graph-approved capabilities.
- Strengthened donor guard tests so the shared AgentClone route must keep the
  new Mini/Note/Graph portal constructors, graph attachment resource, and graph
  access-plan detail while still rejecting old ChatView/Osaurus/native-agent
  routes.

Verification:

- `swift test --package-path LocalPackages/EpistemosChatDonorContracts` passed:
  71 tests, 0 failures.
- Source scan across `Epistemos/Views/AgentFusion`, `RootView`,
  `LandingView`, `GraphWorkspaceContainer`, and `NoteDetailWorkspaceView` found
  no old diagnostics or old chat/Osaurus route tokens: `ROUTING`, `REQUEST`,
  `Execution Plan`, `Overseer`, `ChatRouteView(`, `ChatSurfaceCoordinator`,
  `ChatCoordinator`, `NoteChat`, `MiniChat`, `GraphChat`, `ActOsaurus`,
  `EpistemosOsaurus`, `Osaurus`, `AgentBlueprint`, or `SystemG`.
- `git diff --check` passed for the touched model, portal snapshot, host,
  access-plan, guard, and handoff files.
- `xcrun swiftc -parse` passed for the touched Swift files:
  `ChatTypes.swift`, `ComposerCurrentAccessPlan.swift`,
  `AgentPortalContextSnapshot.swift`, and `AgentCloneChatHostSurface.swift`.
- `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -configuration Debug
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build` was attempted
  and still failed before the Epistemos target in `EventSource`: unable to
  resolve module dependencies `CAsyncHTTPClient`, `CNIOLLHTTP`,
  `CNIOExtrasZlib`, `CNIOPosix`, and `_NumericsShims`. No diagnostics for
  `AgentCloneChatHostSurface`, `AgentPortalContextSnapshot`, `ChatTypes`, or
  `ComposerCurrentAccessPlan` appeared in the filtered output.

Remaining:

- Wire visible Note and Graph entry points to these portal values and the
  AgentClone host route. Do not recreate `NoteChatSidebar`,
  `GraphChatRequest`, old MiniChat windows, or any separate inference engine.

### Codex continuation 2026-06-25 - visible Note and Graph portal handoff

Owner correction carried forward: the old Note Chat and Graph Chat surfaces
must stay deleted as independent engines. Their replacement is a typed
Epistemos portal request into the shared AgentClone/fusion session, preserving
the app context while avoiding any old `NoteChatState`, `NoteChatSidebar`, or
`GraphChatRequest` route.

Implemented:

- Added `Epistemos/Views/AgentFusion/AgentPortalRouteRequest.swift` as the
  app-local notification seam for surfaces that need to open the shared
  AgentClone/fusion agent with an `AgentPortalContextSnapshot`.
- Updated `HomeRouter` in `Epistemos/App/RootView.swift` to receive
  `.openAgentPortal`, select `.act`, surface the home window, and call
  `agentChat.startNewSession(portalContext:)` with the typed portal context.
- Added an `Open in Agent` note quick action in
  `Epistemos/Views/Notes/NoteDetailWorkspaceView.swift`. It builds a
  `.note` portal context from the active page id, title, path, selected text,
  visible excerpt, tags, vault root, and workspace path, then posts it through
  `AgentPortalRouteRequest`.
- Added a graph `Agent` button in
  `Epistemos/Views/Graph/GraphWorkspaceContainer.swift`. It builds a `.graph`
  portal context from route id, selected node ids, selected edge ids, and a
  bounded neighborhood summary, then posts it through the same request seam.
- Updated the `agent-clone.chatview2-route-ontology` donor contract so the
  new portal request file plus Note/Graph workspace seams are implementation
  paths for the replacement route.
- Strengthened donor guard tests so Note/Graph visible entry points must route
  through `AgentPortalContextSnapshot.note(...)` and `.graph(...)`, while still
  rejecting old `NoteChatState`, `NoteChatSidebar`, and `GraphChatRequest`.
- Left `Epistemos/Work/**`, OpenGUI, Goose, OpenCode, `LocalPackages/AgentClone/**`,
  MCP/native skills, and landing mascot assets untouched.

Verification:

- `swift test --package-path LocalPackages/EpistemosChatDonorContracts` passed:
  71 tests, 0 failures.
- `xcrun swiftc -parse` passed for the touched portal route, `RootView`,
  `NoteDetailWorkspaceView`, and `GraphWorkspaceContainer` Swift files.
- Targeted stale-route scan across `Epistemos/Views/AgentFusion`,
  `RootView`, `LandingView`, `GraphWorkspaceContainer`, and
  `NoteDetailWorkspaceView` found no old route/diagnostic tokens:
  `ROUTING`, `REQUEST`, `Execution Plan`, `Overseer`, `ChatRouteView(`,
  `ChatSurfaceCoordinator`, `ChatCoordinator`, `NoteChat`, `MiniChat`,
  `GraphChat`, `ActOsaurus`, `EpistemosOsaurus`, `Osaurus`,
  `AgentBlueprint`, or `SystemG`.
- `git diff --check` passed for the touched portal route, `RootView`,
  Note/Graph workspace, donor contract, and guard test files.
- Full build probe:
  `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -configuration Debug
  -destination 'platform=macOS' -derivedDataPath
  /tmp/EpistemosCodexBuild-AgentPortalProof build` reached the Epistemos app
  target and failed in protected Work code, not this portal slice:
  `Epistemos/Work/WorkSPASchemeHandler.swift:97:9: error: missing return in
  static method expected to return 'HTTPURLResponse'`. The follow-up quiet
  filtered rerun confirmed the same Work-only error. This was not fixed here
  because `Epistemos/Work/**`, OpenGUI, and Goose are protected from this
  deletion/rebuild pass.

Remaining:

- Next chat-side slice should continue toward Mini portal recreation on the
  same `AgentPortalRouteRequest` path, then move the visible AgentClone host
  closer to the old ChatView feel without restoring old chat backend files.

### Codex continuation 2026-06-25 - compact Agent portal replacement

Owner correction carried forward: the old MiniChat surface and engine should
not return. The replacement is a compact/floating Agent portal backed by the
same `AgentChatState`, `AgentPortalContextSnapshot`, and `AgentCloneBridge`
path as the main Agent surface.

Implemented:

- Added `Epistemos/Views/AgentFusion/AgentCompactPortalView.swift` as a new
  compact Epistemos-owned Agent surface. It shows the shared agent session
  transcript, provides a small composer, starts a typed `.mini` portal context,
  syncs AgentClone host context, and submits through `AgentCloneBridge`.
- Added a neutral `.agent` utility panel in
  `Epistemos/App/UtilityWindowManager.swift` with its own window chrome and
  `AgentCompactPortalView()` content. This does not recreate
  `MiniChatView` or `MiniChatWindowController`.
- Added a `Show Agent` command in `Epistemos/App/EpistemosApp.swift` that
  opens the `.agent` utility panel.
- Updated the `agent-clone.chatview2-route-ontology` donor contract so the
  compact portal and utility/menu seams are implementation paths for the
  replacement route.
- Strengthened donor guard tests so the compact portal must use
  `AgentPortalContextSnapshot.mini(...)`, `AgentChatState`, `AgentCloneBridge`,
  and `AgentPortalRouteRequest`, while still rejecting old MiniChat and
  `ChatCoordinator` names in the compact portal path.
- Left `Epistemos/Work/**`, OpenGUI, Goose, OpenCode, `LocalPackages/AgentClone/**`,
  MCP/native skills, and landing mascot assets untouched.

Verification:

- `swift test --package-path LocalPackages/EpistemosChatDonorContracts` passed:
  71 tests, 0 failures.
- `xcrun swiftc -parse` passed for `AgentCompactPortalView.swift`,
  `UtilityWindowManager.swift`, and `EpistemosApp.swift`.
- Targeted stale-route scan across `Epistemos/Views/AgentFusion`,
  `UtilityWindowManager`, `EpistemosApp`, `RootView`,
  `GraphWorkspaceContainer`, and `NoteDetailWorkspaceView` found no old route
  tokens: `MiniChat`, `miniChat`, `MiniChatView`,
  `MiniChatWindowController`, `NoteChatState`, `NoteChatSidebar`,
  `GraphChatRequest`, `ChatCoordinator`, `ChatSurfaceCoordinator`,
  `ActOsaurus`, `EpistemosOsaurus`, `Osaurus`, `AgentBlueprint`, or `SystemG`.
- `git diff --check` passed for the compact portal, utility/menu wiring, donor
  contract, and guard test files.
- Full build probe:
  `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -configuration Debug
  -destination 'platform=macOS' -derivedDataPath
  /tmp/EpistemosCodexBuild-AgentPortalProof -quiet build` reached the app
  target and failed in protected Work code, not this portal slice:
  `Epistemos/Work/WorkOpenWorkSupervisor.swift:177:39` and `:180:53`
  report `main actor-isolated static property 'port' can not be referenced
  from a nonisolated context`. This was not fixed here because
  `Epistemos/Work/**`, OpenGUI, and Goose are protected from this pass.

Remaining:

- Continue moving the visible AgentClone host and compact portal toward the
  old ChatView feel: flatter transcript typography, tighter title/toolbar,
  session rail polish, and shared recents/history behavior, without restoring
  old native chat backend files.

### Codex continuation 2026-06-25 - shared agent portal recents

Owner correction carried forward: Mini, Note, Graph, Landing, and main Chat
must not own separate old native chat engines. They are portals into the new
AgentClone/fusion agent session system.

Implemented:

- Added `AgentPortalSessionSummary` to `Epistemos/State/AgentChatState.swift`
  and a bounded `recentPortalSessions` list capped at 12 entries.
- `AgentChatState` now records shared portal recents on new session start,
  user submit, successful completion, interrupted completion, and surfaced
  error. The summary carries portal kind, title, detail, prompt preview,
  message count, timestamp, and the typed `AgentPortalContextSnapshot`.
- The main `AgentCloneChatHostSurface` session rail now shows up to six recent
  portal sessions from the shared state.
- The compact Agent portal empty state now shows up to four recent portal
  sessions from the same shared state.
- Updated the `agent-clone.chatview2-route-ontology` donor contract to include
  `AgentChatState` as the app-owned shared recents/session spine.
- Strengthened donor guard tests so recents must stay on `AgentChatState` and
  the new `AgentFusion` surfaces, while old MiniChat, GraphChat, NoteChat,
  ChatCoordinator, Osaurus, AgentBlueprint, and SystemG routes remain rejected.
- Left `Epistemos/Work/**`, OpenGUI, Goose, OpenCode, `LocalPackages/AgentClone/**`,
  MCP/native skills, and landing mascot assets untouched.

Verification:

- `swift test --package-path LocalPackages/EpistemosChatDonorContracts` passed:
  71 tests, 0 failures.
- `xcrun swiftc -parse Epistemos/State/AgentChatState.swift
  Epistemos/Views/AgentFusion/AgentCloneChatHostSurface.swift
  Epistemos/Views/AgentFusion/AgentCompactPortalView.swift` passed.
- Targeted stale-route scan across the touched new-agent files found no old
  route tokens: `MiniChat`, `miniChat`, `MiniChatView`,
  `MiniChatWindowController`, `NoteChatState`, `NoteChatSidebar`,
  `GraphChatRequest`, `ChatCoordinator`, `ChatSurfaceCoordinator`,
  `ActOsaurus`, `EpistemosOsaurus`, `Osaurus`, `AgentBlueprint`, or `SystemG`.
- `git diff --check` passed for the touched tracked files.
- Full build probe:
  `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -configuration Debug
  -destination 'platform=macOS' -derivedDataPath
  /tmp/EpistemosCodexBuild-AgentPortalRecents build` reached the Epistemos app
  target and failed in protected Work code, not this recents slice. Quiet
  rerun confirmed `Epistemos/Work/WorkOpenWorkSupervisor.swift:177:39` and
  `:180:53` report `main actor-isolated static property 'port' can not be
  referenced from a nonisolated context`. This was not fixed here because
  `Epistemos/Work/**`, OpenGUI, and Goose are protected from this pass.

Remaining:

- Continue moving the visible AgentClone host toward ChatView 2 visual parity:
  native title/toolbar rhythm, flatter transcript rows, tighter composer, and
  real recents/session actions, still without restoring any old native chat
  backend or private Mini/Graph/Note chat engine.

### Codex continuation 2026-06-25 - idle Epistemos landing mark

Owner correction carried forward: ChatView is the visual language target only.
The idle Chat/Agent surface should read like the old Epistemos chat, but the
live foundation must remain AgentClone/new Swift-agent fusion.

Implemented:

- Added `shouldShowBridgeEmptyLandingMark` and `bridgeEmptyLandingMark(compact:)`
  to `Epistemos/Views/AgentFusion/AgentCloneChatHostSurface.swift`.
- The new mark renders centered `Epistemos`/portal-ready text from
  `AgentCloneAppContextSnapshot` and `AgentChatState` while idle, then hides
  as soon as the shared new-agent state has messages, streaming, running tools,
  or mirrored AgentClone output.
- The mark is hit-test disabled and sits above `AgentClone.ContentView()` inside
  the Epistemos-owned host shell, so it changes foreground ontology without
  replacing AgentClone providers, tools, MCP, sessions, or runtime behavior.
- Updated the `agent-clone.chatview2-route-ontology` donor contract to record
  this as an Epistemos-owned idle-state shell proof.
- Strengthened donor guard tests so the idle mark must live in
  `AgentCloneChatHostSurface`, must be gated by `AgentChatState`, and old
  ChatView/MiniChat/GraphChat/NoteChat/Osaurus/AgentBlueprint/SystemG routes
  remain rejected.
- Left `Epistemos/Work/**`, OpenGUI, Goose, OpenCode, `LocalPackages/AgentClone/**`,
  MCP/native skills, and landing mascot assets untouched.

Verification:

- `swift test --package-path LocalPackages/EpistemosChatDonorContracts` passed:
  71 tests, 0 failures.
- `xcrun swiftc -parse Epistemos/Views/AgentFusion/AgentCloneChatHostSurface.swift
  Epistemos/State/AgentChatState.swift
  Epistemos/Views/AgentFusion/AgentCompactPortalView.swift` passed.
- Targeted stale-route scan across the touched new-agent files found no old
  route tokens: `MiniChat`, `miniChat`, `MiniChatView`,
  `MiniChatWindowController`, `NoteChatState`, `NoteChatSidebar`,
  `GraphChatRequest`, `ChatCoordinator`, `ChatSurfaceCoordinator`,
  `ActOsaurus`, `EpistemosOsaurus`, `Osaurus`, `AgentBlueprint`, or `SystemG`.
- `git diff --check` passed for the touched tracked files.
- Full build probe:
  `xcodebuild -quiet -project Epistemos.xcodeproj -scheme Epistemos
  -configuration Debug -destination 'platform=macOS' -derivedDataPath
  /tmp/EpistemosCodexBuild-AgentPortalRecents build` reached the app target and
  failed in protected Work code, not this idle-mark slice:
  `Epistemos/Work/WorkOpenWorkSupervisor.swift:177:39` and `:180:53` report
  `main actor-isolated static property 'port' can not be referenced from a
  nonisolated context`. This was not fixed here because `Epistemos/Work/**`,
  OpenGUI, and Goose are protected from this pass. No fresh visual screenshot
  was captured because the app build is still blocked at that protected Work
  compile error.

Remaining:

- Continue the ChatView-2 visual rebuild inside AgentFusion: transcript row
  rhythm, top toolbar density, composer polish, real recents actions, and
  session resume behavior, without restoring old native chat or private
  Mini/Graph/Note chat engines.

### Codex continuation 2026-06-25 - foreground donor chrome mask and recent activation

Owner correction carried forward: AgentClone is the live foundation, but
standard Chat must look and behave like an Epistemos-owned ChatView-2 surface.
AgentClone or old Epistemos local-chat diagnostics must not leak foreground
panels such as routing/request/Overseer/execution-plan chrome.

Implemented:

- `AgentCloneChatHostSurface` now keeps `AgentClone.ContentView()` mounted as
  the runtime foundation but masks it with `.opacity(0.001)`,
  `.allowsHitTesting(false)`, and `.accessibilityHidden(true)`.
- Added `bridgeConversationCanvas(compact:)` as the Epistemos-owned foreground
  canvas. It renders the idle `Epistemos` mark or the bridge transcript runway
  above the composer, so the visible surface moves toward ChatView-2 without
  restoring the old ChatView/backend route.
- Added `AgentChatState.activatePortalSession(_:)` for bounded recent portal
  context activation. It intentionally does not fake transcript persistence:
  selecting an older recent restores typed portal context and clears transient
  streaming/tool state unless that transcript is already loaded.
- Main session rail recents and compact portal recents are now buttons that
  activate the shared portal context and resync `AgentCloneBridge` host context.
- Updated the `agent-clone.chatview2-route-ontology` donor contract and guard
  tests to require masked donor chrome, the Epistemos-owned foreground canvas,
  and recent-context activation while continuing to reject old ChatView,
  MiniChat, GraphChat, NoteChat, ChatCoordinator, Osaurus, AgentBlueprint, and
  SystemG routes.
- Left `Epistemos/Work/**`, OpenGUI, Goose, OpenCode, `LocalPackages/AgentClone/**`,
  MCP/native skills, and landing mascot assets untouched.

Verification:

- `swift test --package-path LocalPackages/EpistemosChatDonorContracts` passed:
  71 tests, 0 failures.
- `xcrun swiftc -parse Epistemos/Views/AgentFusion/AgentCloneChatHostSurface.swift
  Epistemos/State/AgentChatState.swift
  Epistemos/Views/AgentFusion/AgentCompactPortalView.swift` passed.
- Targeted stale-route scan across the touched new-agent files found no old
  route or debug foreground tokens: `MiniChat`, `miniChat`, `MiniChatView`,
  `MiniChatWindowController`, `NoteChatState`, `NoteChatSidebar`,
  `GraphChatRequest`, `ChatCoordinator`, `ChatSurfaceCoordinator`,
  `ActOsaurus`, `EpistemosOsaurus`, `Osaurus`, `AgentBlueprint`, `SystemG`,
  `Execution Plan`, `ROUTING`, `OVERSEER`, or `Overseer`.
- Trailing whitespace scan across the touched files returned no matches.
- Full build probe:
  `xcodebuild -quiet -project Epistemos.xcodeproj -scheme Epistemos
  -configuration Debug -destination 'platform=macOS' -derivedDataPath
  /tmp/EpistemosCodexBuild-AgentFusionForeground build` reached the app target
  and failed in protected Work code, not this AgentFusion slice:
  `Epistemos/Work/WorkSPASchemeHandler.swift:97:9` reports `missing return in
  static method expected to return 'HTTPURLResponse'`. This was not fixed here
  because `Epistemos/Work/**`, OpenGUI, and Goose are protected from this pass.

Remaining:

- Continue ChatView-2 visual parity inside `Epistemos/Views/AgentFusion/**`:
  flatten transcript rows, reduce composer carding/shadow, align toolbar
  density with the old Epistemos chat feel, and keep moving runtime/provider/
  tool details into rails or popovers rather than foreground debug panels.

### Codex continuation 2026-06-25 - flat ChatView-2 transcript and composer rhythm

Owner correction carried forward: the old `ChatView` is a visual/ontology
reference only. The foreground should keep moving toward that exact native
Epistemos feel, while the backend remains AgentClone/new Swift fusion and the
old native chat family stays deleted.

Implemented:

- Read the deleted `ChatView.swift` and `ChatInputBar.swift` from git history
  as visual reference only. No old ChatView files, `ChatState`, `ChatCoordinator`,
  or old chat backend code were restored.
- Added `AgentFusionChatLayout` to `AgentCloneChatHostSurface` with the old
  chat's key visible rhythm: 760px message column, 860px composer width, 28px
  transcript spacing, and the old stacked composer padding pattern.
- Changed the AgentFusion transcript foreground from a framed diagnostics card
  into a flat `LazyVStack` conversation column. Removed the visible
  `transcript` label/status strip and the `bridgeRuntimeStatus` foreground path.
- Reordered the composer toward the old stacked message bar: text input first,
  inline runtime picker in-flow, compact control row below. The previous
  shadowed composer card and extra transcript card opacity were removed.
- Kept provider/model/slash/vault/mic/session/new-session controls reachable in
  the new flat row; capability was not hidden to make the UI cleaner.
- Updated the `agent-clone.chatview2-route-ontology` donor contract and guard
  tests so future loops must preserve the flat ChatView-derived layout and must
  not reintroduce foreground routing/request/Overseer/transcript-diagnostics
  chrome.
- Left `Epistemos/Work/**`, OpenGUI, Goose, OpenCode, `LocalPackages/AgentClone/**`,
  MCP/native skills, and landing mascot assets untouched.

Verification:

- `xcrun swiftc -parse Epistemos/Views/AgentFusion/AgentCloneChatHostSurface.swift
  Epistemos/State/AgentChatState.swift
  Epistemos/Views/AgentFusion/AgentCompactPortalView.swift` passed.
- `swift test --package-path LocalPackages/EpistemosChatDonorContracts` passed:
  71 tests, 0 failures.
- Targeted stale-route/debug scan across touched new-agent files found no
  banned old-route or foreground-debug tokens: `MiniChat`, `miniChat`,
  `MiniChatView`, `MiniChatWindowController`, `NoteChatState`,
  `NoteChatSidebar`, `GraphChatRequest`, `ChatCoordinator`,
  `ChatSurfaceCoordinator`, `ActOsaurus`, `EpistemosOsaurus`, `Osaurus`,
  `AgentBlueprint`, `SystemG`, `Execution Plan`, `ROUTING`, `REQUEST`,
  `OVERSEER`, or `Overseer`.
- Trailing whitespace scan across the touched files returned no matches.
- Full app `xcodebuild` was not rerun for this smaller visual slice. The most
  recent full app probe already reached the app target and failed in protected
  Work code (`Epistemos/Work/WorkSPASchemeHandler.swift:97:9`, missing
  `HTTPURLResponse` return), which remains outside this pass by directive.

Remaining:

- Continue ChatView-2 visual parity inside `AgentFusion`: message row typography,
  assistant answer font treatment, toolbar density, side-rail polish, and a real
  visual screenshot once protected Work build blockers are cleared or a narrower
  run target is available.

### Codex continuation 2026-06-25 - role-specific ChatView-2 message rows

Owner correction carried forward: ChatView is the visual language target only.
The old native chat backend, coordinators, MiniChat, Graph Chat, Note Chat,
Osaurus, AgentBlueprint, and SystemG stay deleted. AgentClone/new Swift fusion
remains the live foundation.

Implemented:

- Read the old `MessageBubble.swift` visual language and the current shared
  `AssistantResponseChrome.swift` before editing. They were used as visual/current
  chrome references only; no old chat backend route was restored.
- Replaced the generic icon-led bridge transcript row in
  `AgentCloneChatHostSurface` with role-specific rows:
  user rows are right-reserved ChatView-style bubbles using
  `TaggedMarkdownTextView`, `.user` typography, and
  `theme.userBubbleBg`/`theme.userBubbleText`.
- Assistant rows now use retained shared `AssistantResponseChrome` with
  `TaggedMarkdownTextView`, `.assistant` typography,
  `theme.assistantBubbleForeground`, and
  `UserFacingModelOutput.finalVisibleText(from:)` so visible answers read like
  Epistemos output rather than donor diagnostics.
- Error rows now render as native red transcript failures instead of the old
  generic runtime/debug row treatment.
- Updated the `agent-clone.chatview2-route-ontology` donor contract and guard
  tests to require these ChatView-2 role rows while continuing to reject old
  ChatView/backend/Osaurus/native-agent routes.
- Left `Epistemos/Work/**`, OpenGUI, Goose, OpenCode,
  `LocalPackages/AgentClone/**`, MCP/native skills, and landing mascot assets
  untouched.

Verification:

- `xcrun swiftc -parse Epistemos/Views/AgentFusion/AgentCloneChatHostSurface.swift
  Epistemos/State/AgentChatState.swift
  Epistemos/Views/AgentFusion/AgentCompactPortalView.swift` passed.
- `swift test --package-path LocalPackages/EpistemosChatDonorContracts` passed:
  71 tests, 0 failures.
- Targeted stale-route/debug scan across touched new-agent files found no banned
  old-route or foreground-debug tokens: `MiniChat`, `miniChat`, `MiniChatView`,
  `MiniChatWindowController`, `NoteChatState`, `NoteChatSidebar`,
  `GraphChatRequest`, `ChatCoordinator`, `ChatSurfaceCoordinator`,
  `ActOsaurus`, `EpistemosOsaurus`, `Osaurus`, `AgentBlueprint`, `SystemG`,
  `Execution Plan`, `ROUTING`, `REQUEST`, `OVERSEER`, `Overseer`,
  `bridgeRuntimeStatus`, or `Text("transcript")`.
- Trailing whitespace scan across the touched files returned no matches.
- Full app `xcodebuild` was not rerun for this smaller visual slice. The most
  recent full app probe already reached the app target and failed in protected
  Work code (`Epistemos/Work/WorkSPASchemeHandler.swift:97:9`, missing
  `HTTPURLResponse` return), which remains outside this pass by directive.

Remaining:

- Continue ChatView-2 visual parity inside `AgentFusion`: toolbar density,
  side-rail polish, composer fine tuning, model/session affordances, and visual
  evidence once the protected Work build blocker is cleared or a narrower run
  target is available.

### Codex continuation 2026-06-25 - Epistemos foreground rail language

Owner correction carried forward: the live foundation is still AgentClone/new
Swift fusion, but the visible shell should not explain itself as a foundation,
backend, bridge, or donor runtime. Those details stay in code/contracts, not the
foreground chat surface.

Implemented:

- Replaced visible session rail details that said `Swift agent foundation` and
  `Swift agent fusion` with Epistemos-facing `ready` and `native agent` labels.
- Replaced the context rail `Backend`/`Epistemos bridge` row with a `Source` row
  whose visible detail is `App context`.
- Flattened the toolbar and both rails onto `theme.chatSurface` backgrounds and
  added `AgentFusionChatLayout.toolbarMinHeight` so the density is stable and
  less donor-panel-like.
- Updated the `agent-clone.chatview2-route-ontology` donor contract and guard
  tests so the foreground rails must keep Epistemos language while preserving
  the underlying provider/tool/MCP foundation.
- Left `Epistemos/Work/**`, OpenGUI, Goose, OpenCode,
  `LocalPackages/AgentClone/**`, MCP/native skills, and landing mascot assets
  untouched.

Verification:

- `xcrun swiftc -parse Epistemos/Views/AgentFusion/AgentCloneChatHostSurface.swift
  Epistemos/State/AgentChatState.swift
  Epistemos/Views/AgentFusion/AgentCompactPortalView.swift` passed.
- `swift test --package-path LocalPackages/EpistemosChatDonorContracts` passed:
  71 tests, 0 failures.
- Targeted host scan found no foreground debug/backend tokens in
  `AgentCloneChatHostSurface`: `Swift agent foundation`, `Swift agent fusion`,
  `Epistemos bridge`, `Backend", detail:`, `ROUTING`, `REQUEST`, `OVERSEER`,
  `Overseer`, `bridgeRuntimeStatus`, or `Text("transcript")`.
- Trailing whitespace scan across the touched source and contract/test files
  returned no matches.
- Full app `xcodebuild` was not rerun for this smaller visual slice. The most
  recent full app probe already reached the app target and failed in protected
  Work code (`Epistemos/Work/WorkSPASchemeHandler.swift:97:9`, missing
  `HTTPURLResponse` return), which remains outside this pass by directive.

Remaining:

- Continue ChatView-2 visual parity inside `AgentFusion`: composer polish,
  model/session affordance placement, side-rail contents, and visual evidence
  once the protected Work build blocker is cleared or a narrower run target is
  available.

### Codex continuation 2026-06-25 - ChatView-2 composer context strip

Owner correction carried forward: the composer should keep moving toward the
old Epistemos ChatView message bar feel, but all submission/runtime behavior
must remain on the new AgentClone/fusion path.

Implemented:

- Added `bridgeComposerContextBar` above the prompt field in
  `AgentCloneChatHostSurface`, restoring the old top-strip rhythm for
  `Read + Search vault`.
- Kept the same `toggleBridgeAllNotesContext()` behavior and all context
  attachment plumbing, so this is not a fake visual pill or a disconnected
  surface.
- Moved the slash/model/session/mic/new-session controls into the lower control
  row and kept them reachable.
- Updated the prompt placeholder to `Ask anything... Type @ for notes or chats`
  to better match the old ChatView composer language without restoring the old
  backend.
- Updated the `agent-clone.chatview2-route-ontology` donor contract and guard
  tests so the top context strip is required as part of the rebuilt composer
  ontology.
- Left `Epistemos/Work/**`, OpenGUI, Goose, OpenCode,
  `LocalPackages/AgentClone/**`, MCP/native skills, and landing mascot assets
  untouched.

Verification:

- `xcrun swiftc -parse Epistemos/Views/AgentFusion/AgentCloneChatHostSurface.swift
  Epistemos/State/AgentChatState.swift
  Epistemos/Views/AgentFusion/AgentCompactPortalView.swift` passed.
- `swift test --package-path LocalPackages/EpistemosChatDonorContracts` passed:
  71 tests, 0 failures.
- Targeted stale-route/debug scan across touched new-agent files found no
  banned old-route or foreground-debug tokens: `MiniChat`, `miniChat`,
  `MiniChatView`, `MiniChatWindowController`, `NoteChatState`,
  `NoteChatSidebar`, `GraphChatRequest`, `ChatCoordinator`,
  `ChatSurfaceCoordinator`, `ActOsaurus`, `EpistemosOsaurus`, `Osaurus`,
  `AgentBlueprint`, `SystemG`, `Execution Plan`, `ROUTING`, `REQUEST`,
  `OVERSEER`, `Overseer`, `bridgeRuntimeStatus`, `Text("transcript")`,
  `Swift agent foundation`, `Swift agent fusion`, `Epistemos bridge`, or
  `Backend", detail:`.
- Trailing whitespace scan across the touched source and contract/test files
  returned no matches.
- Full app `xcodebuild` was not rerun for this smaller visual slice. The most
  recent full app probe already reached the app target and failed in protected
  Work code (`Epistemos/Work/WorkSPASchemeHandler.swift:97:9`, missing
  `HTTPURLResponse` return), which remains outside this pass by directive.

Remaining:

- Continue ChatView-2 visual parity inside `AgentFusion`: exact toolbar/segmented
  mode rhythm, richer session recents, model picker placement, and visual
  evidence once the protected Work build blocker is cleared or a narrower run
  target is available.

### Codex continuation 2026-06-25 - top model picker affordance

Owner correction carried forward: the ChatView-2 toolbar should feel like
Epistemos, but the live route remains AgentClone/new Swift fusion. The existing
HomeRouter mode segment already owns Act/Work/Chat selection, so this slice did
not add a duplicate mode control inside AgentFusion.

Implemented:

- Changed the top `model` affordance in `AgentCloneChatHostSurface` so it opens
  the inline runtime/model picker directly via `showBridgeRuntimePicker.toggle()`.
- Kept context reachable through the right rail button, and rewired both rail
  buttons through `toggleSessionRail(compact:)` and `toggleContextRail(compact:)`
  so the session/context affordances remain explicit and guarded.
- Updated the toolbar label to include the old-style `model` text plus an
  `arrow.up.right` affordance, matching the visual intent without restoring the
  old ChatView backend.
- Updated the `agent-clone.chatview2-route-ontology` donor contract and guard
  tests to require this model-picker placement while continuing to reject old
  ChatView/backend/Osaurus/native-agent routes.
- Left `Epistemos/Work/**`, OpenGUI, Goose, OpenCode,
  `LocalPackages/AgentClone/**`, MCP/native skills, and landing mascot assets
  untouched.

Verification:

- `xcrun swiftc -parse Epistemos/Views/AgentFusion/AgentCloneChatHostSurface.swift
  Epistemos/State/AgentChatState.swift
  Epistemos/Views/AgentFusion/AgentCompactPortalView.swift` passed.
- `swift test --package-path LocalPackages/EpistemosChatDonorContracts` passed:
  71 tests, 0 failures.
- Targeted stale-route/debug scan across touched new-agent files found no
  banned old-route or foreground-debug tokens: `MiniChat`, `miniChat`,
  `MiniChatView`, `MiniChatWindowController`, `NoteChatState`,
  `NoteChatSidebar`, `GraphChatRequest`, `ChatCoordinator`,
  `ChatSurfaceCoordinator`, `ActOsaurus`, `EpistemosOsaurus`, `Osaurus`,
  `AgentBlueprint`, `SystemG`, `Execution Plan`, `ROUTING`, `REQUEST`,
  `OVERSEER`, `Overseer`, `bridgeRuntimeStatus`, `Text("transcript")`,
  `Swift agent foundation`, `Swift agent fusion`, `Epistemos bridge`, or
  `Backend", detail:`.
- Trailing whitespace scan across the touched source and contract/test files
  returned no matches.
- Full app `xcodebuild` was not rerun for this smaller visual slice. The most
  recent full app probe already reached the app target and failed in protected
  Work code (`Epistemos/Work/WorkSPASchemeHandler.swift:97:9`, missing
  `HTTPURLResponse` return), which remains outside this pass by directive.

Remaining:

- Continue ChatView-2 visual parity inside `AgentFusion`: denser toolbar polish,
  richer session recents, visible app-context/tool affordances, and visual
  evidence once the protected Work build blocker is cleared or a narrower run
  target is available.

### Codex continuation 2026-06-25 - active recent-session rail rows

Owner correction carried forward: session history should feel like Epistemos
ChatView-2, but it must not fake old transcript persistence. Recent rows
reactivate typed AgentClone/fusion portal context only.

Implemented:

- Added a dedicated `AgentFusionRecentSessionRow` in
  `AgentCloneChatHostSurface` for the session rail instead of reusing the
  generic settings-style rail row.
- Recent rows now show title, prompt/detail, portal label, clipped session id,
  message count, portal icon, and an `active` badge when the row matches the
  current `AgentChatState.activeSessionId`.
- Kept activation behavior on the new shared route:
  `activateRecentPortalSession(_:)` still clears transient composer/dropdown
  state, calls `agentChat.activatePortalSession(summary)`, syncs
  `AgentCloneBridge`, and focuses the composer.
- Kept the explicit limitation from `AgentChatState`: selecting an older recent
  context does not pretend to restore an old transcript unless that transcript
  is already loaded.
- Updated the `agent-clone.chatview2-route-ontology` donor contract and guard
  tests to require dedicated recent-session rows with active state and
  portal/session/message metadata.
- Left `Epistemos/Work/**`, OpenGUI, Goose, OpenCode,
  `LocalPackages/AgentClone/**`, MCP/native skills, and landing mascot assets
  untouched.

Verification:

- `xcrun swiftc -parse Epistemos/Views/AgentFusion/AgentCloneChatHostSurface.swift
  Epistemos/State/AgentChatState.swift
  Epistemos/Views/AgentFusion/AgentCompactPortalView.swift` passed.
- `swift test --package-path LocalPackages/EpistemosChatDonorContracts` passed:
  71 tests, 0 failures.
- Targeted stale-route/debug scan across touched new-agent files found no
  banned old-route or foreground-debug tokens: `MiniChat`, `miniChat`,
  `MiniChatView`, `MiniChatWindowController`, `NoteChatState`,
  `NoteChatSidebar`, `GraphChatRequest`, `ChatCoordinator`,
  `ChatSurfaceCoordinator`, `ActOsaurus`, `EpistemosOsaurus`, `Osaurus`,
  `AgentBlueprint`, `SystemG`, `Execution Plan`, `ROUTING`, `REQUEST`,
  `OVERSEER`, `Overseer`, `bridgeRuntimeStatus`, `Text("transcript")`,
  `Swift agent foundation`, `Swift agent fusion`, `Epistemos bridge`, or
  `Backend", detail:`.
- Trailing whitespace scan across the touched source and contract/test files
  returned no matches.
- Full app `xcodebuild` was not rerun for this smaller visual slice. The most
  recent full app probe already reached the app target and failed in protected
  Work code (`Epistemos/Work/WorkSPASchemeHandler.swift:97:9`, missing
  `HTTPURLResponse` return), which remains outside this pass by directive.

Remaining:

- Continue ChatView-2 visual parity inside `AgentFusion`: app-context/tool
  affordances, tighter toolbar grouping, more complete session restore once a
  real shared transcript store exists, and visual evidence once the protected
  Work build blocker is cleared or a narrower run target is available.

### Codex continuation 2026-06-25 - context rail capability counts

Owner correction carried forward: capability preservation is non-negotiable,
but standard Chat must not show donor/debug panels as its foreground. The
visible surface should expose Epistemos-owned capability affordances instead.

Implemented:

- Added a `Capabilities` section to the AgentFusion context rail in
  `AgentCloneChatHostSurface`.
- The rail now shows visible counts/status for `Tools`, `Skills`, `Commands`,
  and `MCP` from existing `AgentCommandCenterState` and slash-command state.
- Added local summary helpers:
  `bridgeToolCapabilitySummary`, `bridgeSkillCapabilitySummary`,
  `bridgeCommandCapabilitySummary`, `bridgeMCPCapabilitySummary`, and
  `capabilityCountLabel`.
- This does not launch MCP, mutate protected Work/OpenGUI/Goose code, or mount
  old chat diagnostics. It only makes preserved capabilities visible in the
  Epistemos-owned context rail.
- Updated the `agent-clone.chatview2-route-ontology` donor contract and guard
  tests to require these capability affordances while continuing to reject old
  ChatView/backend/Osaurus/native-agent routes.
- Left `Epistemos/Work/**`, OpenGUI, Goose, OpenCode,
  `LocalPackages/AgentClone/**`, MCP/native skills, and landing mascot assets
  untouched.

Verification:

- `xcrun swiftc -parse Epistemos/Views/AgentFusion/AgentCloneChatHostSurface.swift
  Epistemos/State/AgentChatState.swift
  Epistemos/Views/AgentFusion/AgentCompactPortalView.swift` passed.
- `swift test --package-path LocalPackages/EpistemosChatDonorContracts` passed:
  71 tests, 0 failures.
- Targeted stale-route/debug scan across touched new-agent files found no
  banned old-route or foreground-debug tokens: `MiniChat`, `miniChat`,
  `MiniChatView`, `MiniChatWindowController`, `NoteChatState`,
  `NoteChatSidebar`, `GraphChatRequest`, `ChatCoordinator`,
  `ChatSurfaceCoordinator`, `ActOsaurus`, `EpistemosOsaurus`, `Osaurus`,
  `AgentBlueprint`, `SystemG`, `Execution Plan`, `ROUTING`, `REQUEST`,
  `OVERSEER`, `Overseer`, `bridgeRuntimeStatus`, `Text("transcript")`,
  `Swift agent foundation`, `Swift agent fusion`, `Epistemos bridge`, or
  `Backend", detail:`.
- Trailing whitespace scan across the touched source and contract/test files
  returned no matches.
- Full app `xcodebuild` was not rerun for this smaller visual slice. The most
  recent full app probe already reached the app target and failed in protected
  Work code (`Epistemos/Work/WorkSPASchemeHandler.swift:97:9`, missing
  `HTTPURLResponse` return), which remains outside this pass by directive.

Remaining:

- Continue ChatView-2 visual parity and integration inside `AgentFusion`: tighter
  toolbar grouping, stronger app-context portal summaries, permission/tool
  failure visibility, and visual evidence once the protected Work build blocker
  is cleared or a narrower run target is available.

### Codex continuation 2026-06-25 - transcript-visible active tool row

Owner correction carried forward: capability preservation is not enough if the
user cannot see what the agent is doing. Tool activity should appear as native
Epistemos transcript activity, not as hidden runtime state or donor debug chrome.

Implemented:

- Added `bridgeActiveToolRow(name:inputJson:)` to `AgentCloneChatHostSurface`.
- The AgentFusion transcript runway now renders that row whenever
  `agentChat.isAgentExecuting` is true, using `agentChat.activeToolName` and
  `agentChat.activeToolInputJson`.
- The row reuses `ToolActivityNarrator.surface(name:)` and
  `ToolActivityNarrator.phrase(name:inputJson:)` so tool activity uses the
  existing Epistemos user-facing narration layer instead of raw tool ids.
- The visible row shows a native symbol, lowered badge title, `running` state,
  and a clipped activity phrase. It does not mount old transcript diagnostics,
  Overseer panels, or old ChatView backend code.
- Updated the `agent-clone.chatview2-route-ontology` donor contract and guard
  tests to require transcript-visible active tool execution.
- Left `Epistemos/Work/**`, OpenGUI, Goose, OpenCode,
  `LocalPackages/AgentClone/**`, MCP/native skills, and landing mascot assets
  untouched.

Verification:

- `xcrun swiftc -parse Epistemos/Views/AgentFusion/AgentCloneChatHostSurface.swift
  Epistemos/State/AgentChatState.swift
  Epistemos/Views/AgentFusion/AgentCompactPortalView.swift` passed.
- `swift test --package-path LocalPackages/EpistemosChatDonorContracts` passed:
  71 tests, 0 failures.
- Targeted stale-route/debug scan across touched new-agent files found no
  banned old-route or foreground-debug tokens: `MiniChat`, `miniChat`,
  `MiniChatView`, `MiniChatWindowController`, `NoteChatState`,
  `NoteChatSidebar`, `GraphChatRequest`, `ChatCoordinator`,
  `ChatSurfaceCoordinator`, `ActOsaurus`, `EpistemosOsaurus`, `Osaurus`,
  `AgentBlueprint`, `SystemG`, `Execution Plan`, `ROUTING`, `REQUEST`,
  `OVERSEER`, `Overseer`, `bridgeRuntimeStatus`, `Text("transcript")`,
  `Swift agent foundation`, `Swift agent fusion`, `Epistemos bridge`, or
  `Backend", detail:`.
- Trailing whitespace scan across the touched source and contract/test files
  returned no matches.
- Full app `xcodebuild` was not rerun for this smaller visual slice. The most
  recent full app probe already reached the app target and failed in protected
  Work code (`Epistemos/Work/WorkSPASchemeHandler.swift:97:9`, missing
  `HTTPURLResponse` return), which remains outside this pass by directive.

Remaining:

- Continue ChatView-2 visual parity and integration inside `AgentFusion`:
  permission/failure cards, richer app-context portal summaries, tighter toolbar
  grouping, and visual evidence once the protected Work build blocker is cleared
  or a narrower run target is available.

### Codex continuation 2026-06-25 - typed portal context rail rows

Owner correction carried forward: MiniChat, Graph Chat, and Note Chat are not
separate old chat engines anymore. They are portals into the new AgentClone /
Swift-fusion agent system, and the standard Chat surface must make that typed
context visible without restoring the deleted old surface-specific stacks.

Implemented:

- Added a conditional `Portal Context` section to the AgentFusion context rail.
- The rail resolves `agentChat.activePortalContext ?? context.portalContext` and
  summarizes the active portal instead of reading old route-specific chat state.
- Note portal context now surfaces note title/path/tags/backlink count plus
  selected text or visible excerpt.
- Graph portal context now surfaces route, selected node/edge counts, and
  neighborhood summary.
- Additional composer/context attachments now surface as an `Attached` row.
- Updated the `agent-clone.chatview2-route-ontology` donor contract and guard
  tests to require these typed portal rows.
- Did not touch `Epistemos/Work/**`, OpenGUI, Goose, OpenCode,
  `LocalPackages/AgentClone/**`, MCP/native skills, or landing mascot assets.

Verification:

- `xcrun swiftc -parse Epistemos/Views/AgentFusion/AgentCloneChatHostSurface.swift
  Epistemos/State/AgentChatState.swift
  Epistemos/Views/AgentFusion/AgentCompactPortalView.swift` passed.
- `swift test --package-path LocalPackages/EpistemosChatDonorContracts` passed:
  71 tests, 0 failures.
- Targeted stale-route/debug scan across touched new-agent files found no
  banned old-route or foreground-debug tokens: `MiniChat`, `miniChat`,
  `MiniChatView`, `MiniChatWindowController`, `NoteChatState`,
  `NoteChatSidebar`, `GraphChatRequest`, `ChatCoordinator`,
  `ChatSurfaceCoordinator`, `ActOsaurus`, `EpistemosOsaurus`, `Osaurus`,
  `AgentBlueprint`, `SystemG`, `Execution Plan`, `ROUTING`, `REQUEST`,
  `OVERSEER`, `Overseer`, `bridgeRuntimeStatus`, `Text("transcript")`,
  `Swift agent foundation`, `Swift agent fusion`, `Epistemos bridge`, or
  `Backend", detail:`.
- Trailing whitespace scan across the touched source and contract/test files
  returned no matches.
- Full app `xcodebuild` was not rerun for this small AgentFusion slice. The
  known protected Work blocker remains outside this pass by directive:
  `Epistemos/Work/WorkSPASchemeHandler.swift:97:9`, missing
  `HTTPURLResponse` return.

Remaining:

- Continue ChatView-2 parity inside `AgentFusion`: permission/failure cards,
  tighter toolbar grouping, richer session restore behavior, and visual evidence
  once the protected Work build blocker is cleared or a narrower runnable target
  is available.

### Codex continuation 2026-06-25 - typed transcript failure rows

Owner correction carried forward: standard Chat must not expose raw old
diagnostic panels, but failures and permissions cannot disappear. The new
AgentClone/fusion surface should render user-facing recovery state inside the
transcript, using the app's typed error model.

Implemented:

- Reworked `bridgeErrorTranscriptRow(_:)` so it reads
  `ChatMessage.errorKind`.
- Added `bridgeErrorTone(for:)` to map `UserFacingChatErrorKind` to a compact
  native label, symbol, tint, and recovery hint.
- Auth, rate limit, provider unreachable, timeout, context overflow, model-not-
  ready, cancelled, and generic failures now get distinct transcript chrome.
- Cancelled turns render as `stopped` with neutral styling instead of the old
  generic red `error` label.
- Updated the `agent-clone.chatview2-route-ontology` donor contract and guard
  tests to require typed recovery rows.
- Did not touch `Epistemos/Work/**`, OpenGUI, Goose, OpenCode,
  `LocalPackages/AgentClone/**`, MCP/native skills, or landing mascot assets.

Verification:

- `xcrun swiftc -parse Epistemos/Views/AgentFusion/AgentCloneChatHostSurface.swift
  Epistemos/State/AgentChatState.swift
  Epistemos/Views/AgentFusion/AgentCompactPortalView.swift` passed.
- `swift test --package-path LocalPackages/EpistemosChatDonorContracts` passed:
  71 tests, 0 failures.
- Targeted stale-route/debug scan across touched new-agent files found no
  banned old-route or foreground-debug tokens: `MiniChat`, `miniChat`,
  `MiniChatView`, `MiniChatWindowController`, `NoteChatState`,
  `NoteChatSidebar`, `GraphChatRequest`, `ChatCoordinator`,
  `ChatSurfaceCoordinator`, `ActOsaurus`, `EpistemosOsaurus`, `Osaurus`,
  `AgentBlueprint`, `SystemG`, `Execution Plan`, `ROUTING`, `REQUEST`,
  `OVERSEER`, `Overseer`, `bridgeRuntimeStatus`, `Text("transcript")`,
  `Swift agent foundation`, `Swift agent fusion`, `Epistemos bridge`, or
  `Backend", detail:`.
- Trailing whitespace scan across the touched source and contract/test/handoff
  files returned no matches.
- Full app `xcodebuild` was not rerun for this small AgentFusion slice. The
  known protected Work blocker remains outside this pass by directive:
  `Epistemos/Work/WorkSPASchemeHandler.swift:97:9`, missing
  `HTTPURLResponse` return.

Remaining:

- Continue ChatView-2 parity inside `AgentFusion`: tighter toolbar grouping,
  richer session restore behavior, app-context tool affordances, and visual
  evidence once the protected Work build blocker is cleared or a narrower
  runnable target is available.

### Codex continuation 2026-06-25 - approved portal action chips

Owner correction carried forward: Note, Graph, Vault, Mini, and Landing should
feel like portals into one Epistemos-owned agent/session/context system. Their
approved actions should be visible and usable in the new AgentClone/fusion
composer without reviving old surface-specific chat engines.

Implemented:

- Added `bridgePortalActionChips` below the AgentFusion composer context strip.
- Added `bridgeApprovedActionChips`, a bounded deduped action list sourced from
  `AgentPortalContextSnapshot.approvedActions`, note context, graph context, and
  vault context.
- Chips are capped at six actions and use portal-aware symbols for note, graph,
  vault, skill, session, route, and generic actions.
- Clicking a chip appends a plain composer intent through
  `appendBridgeActionIntent(_:)`; it does not directly invoke old NoteChat,
  GraphChat, MiniChat, or any old portal backend.
- Updated the `agent-clone.chatview2-route-ontology` donor contract and guard
  tests to require the bounded approved-action chip row.
- Did not touch `Epistemos/Work/**`, OpenGUI, Goose, OpenCode,
  `LocalPackages/AgentClone/**`, MCP/native skills, or landing mascot assets.

Verification:

- `xcrun swiftc -parse Epistemos/Views/AgentFusion/AgentCloneChatHostSurface.swift
  Epistemos/State/AgentChatState.swift
  Epistemos/Views/AgentFusion/AgentCompactPortalView.swift` passed.
- `swift test --package-path LocalPackages/EpistemosChatDonorContracts` passed:
  71 tests, 0 failures.
- Targeted stale-route/debug scan across touched new-agent files found no
  banned old-route or foreground-debug tokens: `MiniChat`, `miniChat`,
  `MiniChatView`, `MiniChatWindowController`, `NoteChatState`,
  `NoteChatSidebar`, `GraphChatRequest`, `ChatCoordinator`,
  `ChatSurfaceCoordinator`, `ActOsaurus`, `EpistemosOsaurus`, `Osaurus`,
  `AgentBlueprint`, `SystemG`, `Execution Plan`, `ROUTING`, `REQUEST`,
  `OVERSEER`, `Overseer`, `bridgeRuntimeStatus`, `Text("transcript")`,
  `Swift agent foundation`, `Swift agent fusion`, `Epistemos bridge`, or
  `Backend", detail:`.
- Trailing whitespace scan across the touched source and contract/test/handoff
  files returned no matches.
- Full app `xcodebuild` was not rerun for this small AgentFusion slice. The
  known protected Work blocker remains outside this pass by directive:
  `Epistemos/Work/WorkSPASchemeHandler.swift:97:9`, missing
  `HTTPURLResponse` return.

Remaining:

- Continue ChatView-2 parity inside `AgentFusion`: tighter toolbar grouping,
  richer session restore behavior, stronger app-context execution wiring, and
  visual evidence once the protected Work build blocker is cleared or a narrower
  runnable target is available.

### Codex continuation 2026-06-25 - MotionTitle idle/session marks

Owner correction carried forward: the target ontology includes the old polished
Epistemos feel, including blur + ASCII/typewriter transition language, but it
must be rebuilt inside the new AgentClone/fusion surface rather than by
restoring old ChatView code.

Implemented:

- Replaced the static idle title with the existing Epistemos `MotionTitle`
  component.
- Replaced the reactivated-session mark title with `MotionTitle` as well.
- This reuses the app's established reduce-motion-safe ASCII/typewriter + blur
  title motion instead of introducing a new animation loop or old ChatView
  dependency.
- Updated the `agent-clone.chatview2-route-ontology` donor contract and guard
  tests to require the MotionTitle use on idle and reactivated-session marks.
- Did not touch `Epistemos/Work/**`, OpenGUI, Goose, OpenCode,
  `LocalPackages/AgentClone/**`, MCP/native skills, or landing mascot assets.

Verification:

- `xcrun swiftc -parse Epistemos/Views/AgentFusion/AgentCloneChatHostSurface.swift
  Epistemos/State/AgentChatState.swift
  Epistemos/Views/AgentFusion/AgentCompactPortalView.swift` passed.
- `swift test --package-path LocalPackages/EpistemosChatDonorContracts` passed:
  71 tests, 0 failures.
- Targeted stale-route/debug scan across touched new-agent files found no
  banned old-route or foreground-debug tokens: `MiniChat`, `miniChat`,
  `MiniChatView`, `MiniChatWindowController`, `NoteChatState`,
  `NoteChatSidebar`, `GraphChatRequest`, `ChatCoordinator`,
  `ChatSurfaceCoordinator`, `ActOsaurus`, `EpistemosOsaurus`, `Osaurus`,
  `AgentBlueprint`, `SystemG`, `Execution Plan`, `ROUTING`, `REQUEST`,
  `OVERSEER`, `Overseer`, `bridgeRuntimeStatus`, `Text("transcript")`,
  `Swift agent foundation`, `Swift agent fusion`, `Epistemos bridge`, or
  `Backend", detail:`.
- Trailing whitespace scan across the touched source and contract/test/handoff
  files returned no matches.
- Full app `xcodebuild` was not rerun for this small AgentFusion slice. The
  known protected Work blocker remains outside this pass by directive:
  `Epistemos/Work/WorkSPASchemeHandler.swift:97:9`, missing
  `HTTPURLResponse` return.

Remaining:

- Continue ChatView-2 parity inside `AgentFusion`: tighter toolbar grouping,
  richer session restore behavior, app-context tool affordances, and visual
  evidence once the protected Work build blocker is cleared or a narrower
  runnable target is available.

### Codex continuation 2026-06-25 - recent-session continuity mark

Owner correction carried forward: recents and sessions should feel like one
connected Epistemos chat system, but the new AgentClone/fusion surface must not
fake transcript restore or fall back to old ChatView-era persistence.

Implemented:

- Added `bridgeActiveRecentPortalSession` and
  `shouldShowBridgeSessionResumeMark` to identify an honestly reactivated recent
  session whose transcript is not currently loaded.
- The conversation canvas now shows `bridgeSessionResumeMark(_:compact:)`
  instead of the generic empty `ready` mark when such a recent session is active.
- The mark displays `Session ready`, the portal/session detail, prompt preview,
  message/session metadata, and a `Continue` action that focuses the composer.
- This keeps the previous non-restoring activation rule intact while giving the
  user visible context continuity after selecting a recent session.
- Updated the `agent-clone.chatview2-route-ontology` donor contract and guard
  tests to require this reactivated-session mark.
- Did not touch `Epistemos/Work/**`, OpenGUI, Goose, OpenCode,
  `LocalPackages/AgentClone/**`, MCP/native skills, or landing mascot assets.

Verification:

- `xcrun swiftc -parse Epistemos/Views/AgentFusion/AgentCloneChatHostSurface.swift
  Epistemos/State/AgentChatState.swift
  Epistemos/Views/AgentFusion/AgentCompactPortalView.swift` passed.
- `swift test --package-path LocalPackages/EpistemosChatDonorContracts` passed:
  71 tests, 0 failures.
- Targeted stale-route/debug scan across touched new-agent files found no
  banned old-route or foreground-debug tokens: `MiniChat`, `miniChat`,
  `MiniChatView`, `MiniChatWindowController`, `NoteChatState`,
  `NoteChatSidebar`, `GraphChatRequest`, `ChatCoordinator`,
  `ChatSurfaceCoordinator`, `ActOsaurus`, `EpistemosOsaurus`, `Osaurus`,
  `AgentBlueprint`, `SystemG`, `Execution Plan`, `ROUTING`, `REQUEST`,
  `OVERSEER`, `Overseer`, `bridgeRuntimeStatus`, `Text("transcript")`,
  `Swift agent foundation`, `Swift agent fusion`, `Epistemos bridge`, or
  `Backend", detail:`.
- Trailing whitespace scan across the touched source and contract/test/handoff
  files returned no matches.
- Full app `xcodebuild` was not rerun for this small AgentFusion slice. The
  known protected Work blocker remains outside this pass by directive:
  `Epistemos/Work/WorkSPASchemeHandler.swift:97:9`, missing
  `HTTPURLResponse` return.

Remaining:

- Continue ChatView-2 parity inside `AgentFusion`: tighter toolbar grouping,
  richer session restore behavior, app-context tool affordances, and visual
  evidence once the protected Work build blocker is cleared or a narrower
  runnable target is available.

### Codex continuation 2026-06-25 - inline shared approval card

Owner correction carried forward: permission behavior must be native Epistemos
behavior and visible in the new AgentClone/fusion surface. It must not become a
second private approval engine and must not depend on old ChatView-era routes.

Implemented:

- Injected the existing shared `ChatApprovalQueue` into
  `AgentCloneChatHostSurface`.
- The transcript runway now renders a compact inline approval row when
  `chatApprovalQueue.pendingApproval` matches the active agent session.
- The card shows approval category, tool name, summary/arguments, and native
  Allow / Always / Deny actions.
- Inline actions call `chatApprovalQueue.resolve(approval, decision:)`, so this
  remains the app's existing approval queue rather than a duplicate AgentFusion
  backend.
- Updated the `agent-clone.chatview2-route-ontology` donor contract and guard
  tests to require the shared-queue inline card.
- Did not touch `Epistemos/Work/**`, OpenGUI, Goose, OpenCode,
  `LocalPackages/AgentClone/**`, MCP/native skills, or landing mascot assets.

Verification:

- `xcrun swiftc -parse Epistemos/Views/AgentFusion/AgentCloneChatHostSurface.swift
  Epistemos/State/AgentChatState.swift
  Epistemos/Views/AgentFusion/AgentCompactPortalView.swift` passed.
- `swift test --package-path LocalPackages/EpistemosChatDonorContracts` passed:
  71 tests, 0 failures.
- Targeted stale-route/debug scan across touched new-agent files found no
  banned old-route or foreground-debug tokens: `MiniChat`, `miniChat`,
  `MiniChatView`, `MiniChatWindowController`, `NoteChatState`,
  `NoteChatSidebar`, `GraphChatRequest`, `ChatCoordinator`,
  `ChatSurfaceCoordinator`, `ActOsaurus`, `EpistemosOsaurus`, `Osaurus`,
  `AgentBlueprint`, `SystemG`, `Execution Plan`, `ROUTING`, `REQUEST`,
  `OVERSEER`, `Overseer`, `bridgeRuntimeStatus`, `Text("transcript")`,
  `Swift agent foundation`, `Swift agent fusion`, `Epistemos bridge`, or
  `Backend", detail:`.
- Trailing whitespace scan across the touched source and contract/test/handoff
  files returned no matches.
- Full app `xcodebuild` was not rerun for this small AgentFusion slice. The
  known protected Work blocker remains outside this pass by directive:
  `Epistemos/Work/WorkSPASchemeHandler.swift:97:9`, missing
  `HTTPURLResponse` return.

Remaining:

- Continue ChatView-2 parity inside `AgentFusion`: tighter toolbar grouping,
  richer session restore behavior, app-context tool affordances, and visual
  evidence once the protected Work build blocker is cleared or a narrower
  runnable target is available.

### Codex continuation 2026-06-25 - transcript-visible completed tool failures

Owner correction carried forward: the new AgentClone/fusion surface must not hide
runtime behavior behind donor chrome or old diagnostic panels. Tool failures
should remain visible after a turn completes, not disappear when the live
`running` row clears.

Implemented:

- Reworked `bridgeAssistantTranscriptRow(_:)` so it keeps the ChatView-2
  assistant text chrome but also reads completed `message.contentBlocks`.
- Added `bridgeFailedToolResults(from:)` to extract only failed
  `MessageContentBlock.toolResult` entries and map them back to the prior
  `toolUse` name when available.
- Added `bridgeToolFailureResultRow(_:)`, a compact transcript-native `tool
  failed` row that shows the tool surface label and clipped failure summary.
- Added `AgentFusionToolFailureSummary` as the small Sendable value carried by
  those rows.
- Updated the `agent-clone.chatview2-route-ontology` donor contract and guard
  tests to require completed tool failures to remain transcript-visible.
- Did not touch `Epistemos/Work/**`, OpenGUI, Goose, OpenCode,
  `LocalPackages/AgentClone/**`, MCP/native skills, or landing mascot assets.

Verification:

- `xcrun swiftc -parse Epistemos/Views/AgentFusion/AgentCloneChatHostSurface.swift
  Epistemos/State/AgentChatState.swift
  Epistemos/Views/AgentFusion/AgentCompactPortalView.swift` passed.
- `swift test --package-path LocalPackages/EpistemosChatDonorContracts` passed:
  71 tests, 0 failures.
- Targeted stale-route/debug scan across touched new-agent files found no
  banned old-route or foreground-debug tokens: `MiniChat`, `miniChat`,
  `MiniChatView`, `MiniChatWindowController`, `NoteChatState`,
  `NoteChatSidebar`, `GraphChatRequest`, `ChatCoordinator`,
  `ChatSurfaceCoordinator`, `ActOsaurus`, `EpistemosOsaurus`, `Osaurus`,
  `AgentBlueprint`, `SystemG`, `Execution Plan`, `ROUTING`, `REQUEST`,
  `OVERSEER`, `Overseer`, `bridgeRuntimeStatus`, `Text("transcript")`,
  `Swift agent foundation`, `Swift agent fusion`, `Epistemos bridge`, or
  `Backend", detail:`.
- Trailing whitespace scan across the touched source and contract/test/handoff
  files returned no matches.
- Full app `xcodebuild` was not rerun for this small AgentFusion slice. The
  known protected Work blocker remains outside this pass by directive:
  `Epistemos/Work/WorkSPASchemeHandler.swift:97:9`, missing
  `HTTPURLResponse` return.

Remaining:

- Continue ChatView-2 parity inside `AgentFusion`: tighter toolbar grouping,
  richer session restore behavior, app-context tool affordances, and visual
  evidence once the protected Work build blocker is cleared or a narrower
  runnable target is available.

### Codex continuation 2026-06-25 - live toolbar and session status

Owner correction carried forward: the foreground shell must feel like the
rebuilt Epistemos ChatView-2 surface on top of AgentClone/fusion, not a static
donor diagnostic console. The toolbar and rail should report live native agent
state without restoring old chat backend state.

Implemented:

- Replaced the static toolbar `ready` subtitle in
  `AgentCloneChatHostSurface` with `bridgeAgentStatusLabel`.
- Added `bridgeAgentStatusLabel` and `bridgeAgentStatusSymbol`, derived from
  `ChatApprovalQueue` and `AgentChatState`: approval, running, thinking, live,
  session ready, or ready.
- Updated the current-session rail row to use the same live label/symbol so
  the side rail reflects the active turn instead of static chrome.
- Updated the session control and rail session label to prefer
  `agentChat.activeSessionId` before the portal fallback session id.
- Updated the `agent-clone.chatview2-route-ontology` donor contract and source
  guard tests to require the live status bridge and reject static `ready`
  foreground status as the proof point.
- Did not touch `Epistemos/Work/**`, OpenGUI, Goose, OpenCode,
  `LocalPackages/AgentClone/**`, MCP/native skills, or landing mascot assets.

Verification:

- `xcrun swiftc -parse Epistemos/Views/AgentFusion/AgentCloneChatHostSurface.swift
  Epistemos/State/AgentChatState.swift
  Epistemos/Views/AgentFusion/AgentCompactPortalView.swift` passed.
- `swift test --package-path LocalPackages/EpistemosChatDonorContracts` passed:
  71 tests, 0 failures.
- Targeted stale-route/debug scan across touched new-agent files found no
  banned old-route or foreground-debug tokens: `MiniChat`, `miniChat`,
  `MiniChatView`, `MiniChatWindowController`, `NoteChatState`,
  `NoteChatSidebar`, `GraphChatRequest`, `ChatCoordinator`,
  `ChatSurfaceCoordinator`, `ActOsaurus`, `EpistemosOsaurus`, `Osaurus`,
  `AgentBlueprint`, `SystemG`, `Execution Plan`, `ROUTING`, `REQUEST`,
  `OVERSEER`, `Overseer`, `bridgeRuntimeStatus`, `Text("transcript")`,
  `Swift agent foundation`, `Swift agent fusion`, `Epistemos bridge`, or
  `Backend", detail:`.
- Trailing whitespace scan across the touched source and contract/test/handoff
  files returned no matches.
- Full app `xcodebuild` was not rerun for this small AgentFusion slice. The
  known protected Work blocker remains outside this pass by directive:
  `Epistemos/Work/WorkSPASchemeHandler.swift:97:9`, missing
  `HTTPURLResponse` return.

Remaining:

- Continue ChatView-2 parity inside `AgentFusion`: restore the old-feel
  interaction rhythm from scratch on the AgentClone/fusion backend, including
  session continuity, context-aware portals, app-context tools, and visual
  evidence when a runnable target is available.

### Codex continuation 2026-06-25 - active-session display continuity

Owner correction carried forward: the surface can borrow the old ChatView feel,
but session identity must come from the new AgentClone/fusion state, not old
native chat state or stale portal wiring.

Implemented:

- Added `bridgeVisibleSessionId` to resolve visible session chrome from
  `AgentChatState.activeSessionId` before falling back to
  `context.portalContext.sessionId`.
- Switched the toolbar session button, composer session control, and context
  rail `Session` row to display `clippedSession(bridgeVisibleSessionId)`.
- Updated the `agent-clone.chatview2-route-ontology` donor contract and guard
  tests to require active-session-first display continuity across the host
  surface.
- Did not touch `Epistemos/Work/**`, OpenGUI, Goose, OpenCode,
  `LocalPackages/AgentClone/**`, MCP/native skills, or landing mascot assets.

Verification:

- `xcrun swiftc -parse Epistemos/Views/AgentFusion/AgentCloneChatHostSurface.swift
  Epistemos/State/AgentChatState.swift
  Epistemos/Views/AgentFusion/AgentCompactPortalView.swift` passed.
- `swift test --package-path LocalPackages/EpistemosChatDonorContracts` passed:
  71 tests, 0 failures.
- Targeted stale-route/debug scan across touched new-agent files found no
  banned old-route or foreground-debug tokens: `MiniChat`, `miniChat`,
  `MiniChatView`, `MiniChatWindowController`, `NoteChatState`,
  `NoteChatSidebar`, `GraphChatRequest`, `ChatCoordinator`,
  `ChatSurfaceCoordinator`, `ActOsaurus`, `EpistemosOsaurus`, `Osaurus`,
  `AgentBlueprint`, `SystemG`, `Execution Plan`, `ROUTING`, `REQUEST`,
  `OVERSEER`, `Overseer`, `bridgeRuntimeStatus`, `Text("transcript")`,
  `Swift agent foundation`, `Swift agent fusion`, `Epistemos bridge`, or
  `Backend", detail:`.
- Trailing whitespace scan across the touched source and contract/test/handoff
  files returned no matches.
- Full app `xcodebuild` was not rerun for this small AgentFusion slice. The
  known protected Work blocker remains outside this pass by directive:
  `Epistemos/Work/WorkSPASchemeHandler.swift:97:9`, missing
  `HTTPURLResponse` return.

Remaining:

- Continue ChatView-2 parity inside `AgentFusion`: make recent-session
  activation carry more visible context and preserve all AgentClone/provider/
  tool/MCP controls while the foreground surface becomes Epistemos-native.

### Codex continuation 2026-06-25 - resume mark portal context readback

Owner correction carried forward: reactivated sessions should feel like
Epistemos Chat returning to the right place, but the context must come from the
new AgentClone/fusion session spine rather than old Mini/Note/Graph chat
engines.

Implemented:

- Added a bounded `recentPortalSessionContextLine(_:compact:)` formatter in
  `AgentCloneChatHostSurface`.
- The reactivated-session mark now reads `AgentPortalSessionSummary.portalContext`
  and displays compact portal context for note title/selection or excerpt,
  graph route/node/edge counts, attached context, and approved actions.
- The resume mark still avoids fake transcript restoration; it only makes the
  active typed context visible before the user continues the session.
- Updated the `agent-clone.chatview2-route-ontology` donor contract and guard
  tests to require this typed portal context readback.
- Did not touch `Epistemos/Work/**`, OpenGUI, Goose, OpenCode,
  `LocalPackages/AgentClone/**`, MCP/native skills, or landing mascot assets.

Verification:

- `xcrun swiftc -parse Epistemos/Views/AgentFusion/AgentCloneChatHostSurface.swift
  Epistemos/State/AgentChatState.swift
  Epistemos/Views/AgentFusion/AgentCompactPortalView.swift` passed.
- `swift test --package-path LocalPackages/EpistemosChatDonorContracts` passed:
  71 tests, 0 failures.
- Targeted stale-route/debug scan across touched new-agent files found no
  banned old-route or foreground-debug tokens: `MiniChat`, `miniChat`,
  `MiniChatView`, `MiniChatWindowController`, `NoteChatState`,
  `NoteChatSidebar`, `GraphChatRequest`, `ChatCoordinator`,
  `ChatSurfaceCoordinator`, `ActOsaurus`, `EpistemosOsaurus`, `Osaurus`,
  `AgentBlueprint`, `SystemG`, `Execution Plan`, `ROUTING`, `REQUEST`,
  `OVERSEER`, `Overseer`, `bridgeRuntimeStatus`, `Text("transcript")`,
  `Swift agent foundation`, `Swift agent fusion`, `Epistemos bridge`, or
  `Backend", detail:`.
- Trailing whitespace scan across the touched source and contract/test/handoff
  files returned no matches.
- Full app `xcodebuild` was not rerun for this small AgentFusion slice. The
  known protected Work blocker remains outside this pass by directive:
  `Epistemos/Work/WorkSPASchemeHandler.swift:97:9`, missing
  `HTTPURLResponse` return.

Remaining:

- Continue ChatView-2 parity inside `AgentFusion`: deepen session restore
  affordances and native app-context tools while preserving the AgentClone/
  provider/tool/MCP capability stack.

### Codex continuation 2026-06-25 - resume mark context rail action

Owner correction carried forward: the resume state should expose detailed
Epistemos context through the new shared AgentFusion shell, not through old
Note/Graph/Mini chat sidebars.

Implemented:

- Added a `Context` action to the reactivated-session mark in
  `AgentCloneChatHostSurface`.
- The action calls `toggleContextRail(compact:)`, reusing the existing shared
  Epistemos context rail on desktop and compact layouts.
- Updated the `agent-clone.chatview2-route-ontology` donor contract and guard
  tests to require this shared context-rail affordance.
- Did not touch `Epistemos/Work/**`, OpenGUI, Goose, OpenCode,
  `LocalPackages/AgentClone/**`, MCP/native skills, or landing mascot assets.

Verification:

- `xcrun swiftc -parse Epistemos/Views/AgentFusion/AgentCloneChatHostSurface.swift
  Epistemos/State/AgentChatState.swift
  Epistemos/Views/AgentFusion/AgentCompactPortalView.swift` passed.
- `swift test --package-path LocalPackages/EpistemosChatDonorContracts` passed:
  71 tests, 0 failures.
- Targeted stale-route/debug scan across touched new-agent files found no
  banned old-route or foreground-debug tokens: `MiniChat`, `miniChat`,
  `MiniChatView`, `MiniChatWindowController`, `NoteChatState`,
  `NoteChatSidebar`, `GraphChatRequest`, `ChatCoordinator`,
  `ChatSurfaceCoordinator`, `ActOsaurus`, `EpistemosOsaurus`, `Osaurus`,
  `AgentBlueprint`, `SystemG`, `Execution Plan`, `ROUTING`, `REQUEST`,
  `OVERSEER`, `Overseer`, `bridgeRuntimeStatus`, `Text("transcript")`,
  `Swift agent foundation`, `Swift agent fusion`, `Epistemos bridge`, or
  `Backend", detail:`.
- Trailing whitespace scan across the touched source and contract/test/handoff
  files returned no matches.
- Full app `xcodebuild` was not rerun for this small AgentFusion slice. The
  known protected Work blocker remains outside this pass by directive:
  `Epistemos/Work/WorkSPASchemeHandler.swift:97:9`, missing
  `HTTPURLResponse` return.

Remaining:

- Continue ChatView-2 parity inside `AgentFusion`: connect deeper native
  app-context tools and session affordances while preserving the AgentClone/
  provider/tool/MCP capability stack.

### Codex continuation 2026-06-25 - shared app-context snapshot action

Owner correction carried forward: Epistemos-native app context should become
usable inside the AgentClone/fusion composer without resurrecting old chat
backends, old portal-specific sidebars, or donor foreground chrome.

Implemented:

- Added a `Use Context` action to the shared Epistemos context rail in
  `AgentCloneChatHostSurface`.
- Added `bridgeAppContextSnapshotText`, a bounded app-context snapshot sourced
  from the active `AgentPortalContextSnapshot`, visible session id, model
  summary, vault/workspace paths, note/selection, graph route/neighborhood,
  attachments, approved actions, and tool/skill/command/MCP capability counts.
- Added `appendBridgeAppContextSnapshotIntent()` to insert that snapshot into
  the AgentClone-backed composer and focus the composer for the next turn.
- Updated the `agent-clone.chatview2-route-ontology` donor contract and guard
  tests to require this shared context-rail snapshot affordance.
- Did not touch `Epistemos/Work/**`, OpenGUI, Goose, OpenCode,
  `LocalPackages/AgentClone/**`, MCP/native skills, or landing mascot assets.

Verification:

- `xcrun swiftc -parse Epistemos/Views/AgentFusion/AgentCloneChatHostSurface.swift
  Epistemos/State/AgentChatState.swift
  Epistemos/Views/AgentFusion/AgentCompactPortalView.swift` passed.
- `swift test --package-path LocalPackages/EpistemosChatDonorContracts` passed:
  71 tests, 0 failures.
- Targeted stale-route/debug scan across touched new-agent files found no
  banned old-route or foreground-debug tokens: `MiniChat`, `miniChat`,
  `MiniChatView`, `MiniChatWindowController`, `NoteChatState`,
  `NoteChatSidebar`, `GraphChatRequest`, `ChatCoordinator`,
  `ChatSurfaceCoordinator`, `ActOsaurus`, `EpistemosOsaurus`, `Osaurus`,
  `AgentBlueprint`, `SystemG`, `Execution Plan`, `ROUTING`, `REQUEST`,
  `OVERSEER`, `Overseer`, `bridgeRuntimeStatus`, `Text("transcript")`,
  `Swift agent foundation`, `Swift agent fusion`, `Epistemos bridge`, or
  `Backend", detail:`.
- Trailing whitespace scan across the touched source and contract/test/handoff
  files returned no matches.
- Full app `xcodebuild` was not rerun for this small AgentFusion slice. The
  known protected Work blocker remains outside this pass by directive:
  `Epistemos/Work/WorkSPASchemeHandler.swift:97:9`, missing
  `HTTPURLResponse` return.

Remaining:

- Continue ChatView-2 parity inside `AgentFusion`: turn more native context
  affordances into real shared AgentClone/fusion actions while preserving the
  provider/tool/MCP capability stack.

### Codex continuation 2026-06-25 - deleted-route project metadata guard

Owner correction carried forward: deleting the old native chat and Osaurus
files is not enough if project metadata can still mount or resolve them. The
deletion proof now covers build metadata as well as Swift sources.

Implemented:

- Added `testProjectMetadataDoesNotMountDeletedNativeChatOrOsaurus` to the
  donor-contract guard suite.
- The guard scans `Epistemos.xcodeproj/project.pbxproj` and
  `Epistemos.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`
  for old native chat, MiniChat, NoteChat, GraphChat, Osaurus, AgentBlueprint,
  and SystemG tokens.
- Updated the `agent-clone.chatview2-route-ontology` donor contract proof to
  record that Xcode project metadata and SwiftPM resolution no longer mount
  deleted native chat, Osaurus, AgentBlueprint, or SystemG paths.
- Did not touch `Epistemos/Work/**`, OpenGUI, Goose, OpenCode,
  `LocalPackages/AgentClone/**`, MCP/native skills, or landing mascot assets.

Verification:

- `swift test --package-path LocalPackages/EpistemosChatDonorContracts` passed:
  72 tests, 0 failures.
- Direct metadata scan found no banned deleted-route tokens in
  `Epistemos.xcodeproj/project.pbxproj` or SwiftPM `Package.resolved`.
- Trailing whitespace scan across the touched contract/test/handoff files
  returned no matches.
- Full app `xcodebuild` was not rerun for this metadata-only guard slice. The
  known protected Work blocker remains outside this pass by directive:
  `Epistemos/Work/WorkSPASchemeHandler.swift:97:9`, missing
  `HTTPURLResponse` return.

Remaining:

- Continue both tracks: keep hardening the new AgentClone/fusion ChatView-2
  surface, and keep widening deletion/metadata guards where old native chat or
  Osaurus routes could otherwise return.

### Codex continuation 2026-06-25 - explicit landing portal submission

Owner correction carried forward: Landing/search must not behave like a hidden
old native chat launcher. It should create a typed AgentClone/fusion portal
context and submit the first prompt through that same new context.

Implemented:

- Updated `LandingView.submitLandingSearch()` so the first landing prompt calls
  `agentChat.submitAgentQuery(trimmed, portalContext: portalContext)` after
  creating `AgentPortalContextSnapshot.landing`.
- Tightened the donor route guard to require explicit portal-context submission
  and reject the older implicit `agentChat.submitAgentQuery(trimmed)` handoff.
- Updated the `agent-clone.chatview2-route-ontology` donor contract proof to
  record this Landing/search route behavior.
- Did not touch `Epistemos/Work/**`, OpenGUI, Goose, OpenCode,
  `LocalPackages/AgentClone/**`, MCP/native skills, or landing mascot assets.

Verification:

- `xcrun swiftc -parse Epistemos/Views/Landing/LandingView.swift
  Epistemos/Views/AgentFusion/AgentPortalContextSnapshot.swift
  Epistemos/State/AgentChatState.swift` passed.
- `swift test --package-path LocalPackages/EpistemosChatDonorContracts` passed:
  72 tests, 0 failures.
- Targeted stale-route scan across `LandingView`, `RootView`,
  `GraphWorkspaceContainer`, and `NoteDetailWorkspaceView` found no old native
  chat or Osaurus route tokens and no implicit
  `agentChat.submitAgentQuery(trimmed)` landing handoff.
- Trailing whitespace scan across the touched route/contract/test/handoff files
  returned no matches.
- Full app `xcodebuild` was not rerun for this small route slice. The known
  protected Work blocker remains outside this pass by directive:
  `Epistemos/Work/WorkSPASchemeHandler.swift:97:9`, missing
  `HTTPURLResponse` return.

Remaining:

- Continue both tracks: keep hardening the new AgentClone/fusion ChatView-2
  surface, and keep widening route/deletion guards around Landing, Note, Graph,
  Mini, and build metadata without touching protected Work/OpenGUI/Goose/MCP
  surfaces.

### Codex continuation 2026-06-25 - Note and Graph portal workspace context

Owner correction carried forward: Note and Graph should be portals into the
new AgentClone/fusion context system, not separate old chat engines. Their
portal context should carry the real app vault root and a distinct app
workspace path.

Implemented:

- Updated `GraphWorkspaceContainer.openGraphAgentPortal()` so
  `AgentPortalContextSnapshot.graph` receives `vaultRootPath:
  vaultSync.vaultURL?.path` and `workspacePath:
  FileManager.default.homeDirectoryForCurrentUser.path` instead of duplicating
  the vault path into both fields.
- Updated `NoteDetailWorkspaceView.openNoteAgentPortal()` the same way for
  `AgentPortalContextSnapshot.note`.
- Tightened the donor route guard to require distinct vault/workspace values
  for both Note and Graph portal contexts.
- Updated the `agent-clone.chatview2-route-ontology` donor contract proof to
  record that Note and Graph keep vault root distinct from app workspace path.
- Did not touch `Epistemos/Work/**`, OpenGUI, Goose, OpenCode,
  `LocalPackages/AgentClone/**`, MCP/native skills, or landing mascot assets.

Verification:

- `xcrun swiftc -parse Epistemos/Views/Graph/GraphWorkspaceContainer.swift
  Epistemos/Views/Notes/NoteDetailWorkspaceView.swift
  Epistemos/Views/AgentFusion/AgentPortalContextSnapshot.swift` passed.
- `swift test --package-path LocalPackages/EpistemosChatDonorContracts` passed:
  72 tests, 0 failures.
- Targeted stale-route scan across the touched Note/Graph route files found no
  old native chat or Osaurus route tokens and no duplicate
  `workspacePath: vaultSync.vaultURL?.path`.
- Trailing whitespace scan across the touched route/contract/test/handoff files
  returned no matches.
- Full app `xcodebuild` was not rerun for this small route slice. The known
  protected Work blocker remains outside this pass by directive:
  `Epistemos/Work/WorkSPASchemeHandler.swift:97:9`, missing
  `HTTPURLResponse` return.

Remaining:

- Continue both tracks: keep hardening the new AgentClone/fusion ChatView-2
  surface, and keep widening route/deletion guards around Landing, Note, Graph,
  Mini, and build metadata without touching protected Work/OpenGUI/Goose/MCP
  surfaces.

### Codex continuation 2026-06-25 - compact portal workspace context

Owner correction carried forward: old MiniChat is deleted, and the compact
portal must be a child portal into the same AgentClone/fusion context system.
It should carry distinct app vault and workspace roots just like the Note and
Graph portals.

Implemented:

- Updated `AgentCompactPortalView.compactPortalContext` so
  `AgentPortalContextSnapshot.mini` receives `vaultRootPath:
  vaultSync.vaultURL?.path` and `workspacePath:
  FileManager.default.homeDirectoryForCurrentUser.path` instead of duplicating
  the vault path.
- Updated `AgentCompactPortalView.syncAgentCloneHostContext` so
  `AgentCloneHostContext.workspaceRootPath` also uses the app workspace path
  while `vaultRootPath` remains the active vault root.
- Tightened the donor route guard to require distinct vault/workspace values
  for the compact portal snapshot and AgentClone host context.
- Updated the `agent-clone.chatview2-route-ontology` donor contract proof to
  record the compact portal vault/workspace split.
- Did not touch `Epistemos/Work/**`, OpenGUI, Goose, OpenCode,
  `LocalPackages/AgentClone/**`, MCP/native skills, or landing mascot assets.

Verification:

- `xcrun swiftc -parse Epistemos/Views/AgentFusion/AgentCompactPortalView.swift
  Epistemos/Views/AgentFusion/AgentPortalContextSnapshot.swift
  Epistemos/State/AgentChatState.swift` passed.
- `swift test --package-path LocalPackages/EpistemosChatDonorContracts` passed:
  72 tests, 0 failures.
- Targeted stale-route scan across `AgentCompactPortalView` found no old
  MiniChat/native-chat/Osaurus route tokens and no duplicate
  `workspacePath: vaultSync.vaultURL?.path` or `workspaceRootPath:
  vaultSync.vaultURL?.path`.
- Trailing whitespace scan across the touched compact portal/contract/test/
  handoff files returned no matches.
- Full app `xcodebuild` was not rerun for this small route slice. The known
  protected Work blocker remains outside this pass by directive:
  `Epistemos/Work/WorkSPASchemeHandler.swift:97:9`, missing
  `HTTPURLResponse` return.

Remaining:

- Continue both tracks: keep hardening the new AgentClone/fusion ChatView-2
  surface, and keep widening route/deletion guards around Landing, Note, Graph,
  Mini, and build metadata without touching protected Work/OpenGUI/Goose/MCP
  surfaces.

### Codex continuation 2026-06-25 - compact portal context composer

Owner correction carried forward: MiniChat must stay deleted as an old native
surface, but the compact agent window still has to behave like a first-class
Epistemos portal into the shared AgentClone/fusion session system.

Implemented:

- Added a compact portal context strip to `AgentCompactPortalView`, sourced from
  `AgentPortalContextSnapshot` / `AgentChatState.activePortalContext`, so the
  floating portal shows whether it is carrying main, landing, note, graph,
  vault, attachment, or session context.
- Added bounded approved-action chips in the compact composer. The chips are
  derived from portal, note, graph, and vault approved actions and append an
  explicit action intent into the composer instead of invoking an old surface
  engine.
- Added a compact `Use Context` path that inserts a bounded Epistemos app
  context snapshot into the compact composer, including portal, session, vault,
  workspace, note, graph, attachments, and approved actions.
- Tightened compact submission so an activated Note or Graph recent session
  preserves its typed portal context instead of being downgraded to a generic
  compact context before submission.
- Tightened donor route guards and the `agent-clone.chatview2-route-ontology`
  proof text to require this compact context/action/snapshot behavior.
- Did not touch `Epistemos/Work/**`, OpenGUI, Goose, OpenCode,
  `LocalPackages/AgentClone/**`, MCP/native skills, or landing mascot assets.

Verification:

- `xcrun swiftc -parse Epistemos/Views/AgentFusion/AgentCompactPortalView.swift
  Epistemos/Views/AgentFusion/AgentPortalContextSnapshot.swift
  Epistemos/State/AgentChatState.swift` passed.
- `swift test --package-path LocalPackages/EpistemosChatDonorContracts` passed:
  72 tests, 0 failures.
- Targeted stale-route scan across `AgentCompactPortalView` found no old
  MiniChat/native-chat/Osaurus/GraphChat/NoteChat route tokens.
- Trailing whitespace scan across the touched compact portal/contract/test files
  returned no matches.
- Full app `xcodebuild` was not rerun for this small route slice. The known
  protected Work blocker remains outside this pass by directive:
  `Epistemos/Work/WorkSPASchemeHandler.swift:97:9`, missing
  `HTTPURLResponse` return.

### Codex continuation 2026-06-25 - main host portal submission context

Owner correction carried forward: Note, Graph, Vault, Landing, and compact
portals must all submit through the same new AgentClone/fusion session spine.
The main host must not display one portal context and then submit from a stale
root context.

Implemented:

- Updated `AgentCloneChatHostSurface.bridgePortalContext` to start from
  `bridgeResolvedPortalContext`, then add current composer attachments.
- Preserved `bridgePromptText` as the prompt preview on that resolved context
  and carried the visible session id through `withSessionId`.
- Tightened donor guards so the source must use resolved active portal context
  with attachments, prompt preview, and session identity before
  `agentChat.submitAgentQuery(trimmed, portalContext: portalContext)`.
- Updated the `agent-clone.chatview2-route-ontology` proof to record that the
  main host submission path preserves active Note/Graph/Vault portal context.
- Did not touch `Epistemos/Work/**`, OpenGUI, Goose, OpenCode,
  `LocalPackages/AgentClone/**`, MCP/native skills, or landing mascot assets.

Verification:

- `xcrun swiftc -parse Epistemos/Views/AgentFusion/AgentCloneChatHostSurface.swift
  Epistemos/Views/AgentFusion/AgentCompactPortalView.swift
  Epistemos/Views/AgentFusion/AgentPortalContextSnapshot.swift
  Epistemos/State/AgentChatState.swift` passed.
- `swift test --package-path LocalPackages/EpistemosChatDonorContracts` passed:
  72 tests, 0 failures.
- Targeted stale-route scan across `AgentCloneChatHostSurface` and
  `AgentCompactPortalView` found no old MiniChat/native-chat/Osaurus/GraphChat/
  NoteChat route tokens.
- Trailing whitespace scan across the touched host/compact portal/contract/test/
  handoff files returned no matches.
- Full app `xcodebuild` was not rerun for this small route slice. The known
  protected Work blocker remains outside this pass by directive:
  `Epistemos/Work/WorkSPASchemeHandler.swift:97:9`, missing
  `HTTPURLResponse` return.

Remaining:

- Continue both tracks: keep hardening the new AgentClone/fusion ChatView-2
  surface, and keep widening route/deletion guards around Landing, Note, Graph,
  Mini, and build metadata without touching protected Work/OpenGUI/Goose/MCP
  surfaces.

### Codex continuation 2026-06-25 - AgentClone portal prompt envelope

Owner correction carried forward: the old Epistemos chat backend must remain
deleted, but the AgentClone foundation still needs real Epistemos context at
runtime. The transcript can stay raw; the clone prompt handoff should carry a
bounded portal envelope.

Implemented:

- Added `AgentPortalContextSnapshot.agentClonePromptEnvelope(userPrompt:
  capabilityLines:)`, which builds a bounded prompt envelope with portal,
  session, vault, workspace, note, graph, attachments, approved actions, and
  optional capability lines. It caps prompt/context growth and avoids raw file
  dumps.
- Updated `AgentCloneChatHostSurface.submitBridgePromptFromDock()` so
  `AgentChatState` still records the raw user prompt, while
  `AgentCloneBridge.submitPrompt` receives the bounded portal-context envelope
  plus model/tool/skill/command/MCP capability summaries.
- Updated `AgentCompactPortalView.submitCompactPrompt()` to send the same
  bounded envelope into AgentClone from the compact portal replacement for old
  MiniChat.
- Updated `LandingView.submitLandingSearch()` so Landing-created Act sessions
  also enter AgentClone through the portal envelope instead of a detached raw
  prompt launcher.
- Updated the AgentClone donor provenance JSON, route guards, and
  `agent-clone.chatview2-route-ontology` proof text to require
  `portalContext.agentClonePromptEnvelope`.
- Did not touch `Epistemos/Work/**`, OpenGUI, Goose, OpenCode,
  `LocalPackages/AgentClone/**`, MCP/native skills, or landing mascot assets.

Verification:

- `xcrun swiftc -parse Epistemos/Views/AgentFusion/AgentPortalContextSnapshot.swift
  Epistemos/Views/AgentFusion/AgentCloneChatHostSurface.swift
  Epistemos/Views/AgentFusion/AgentCompactPortalView.swift
  Epistemos/Views/Landing/LandingView.swift
  Epistemos/State/AgentChatState.swift` passed.
- `jq empty docs/donor-contracts/swift-chat/agent-clone/provenance.json`
  passed.
- `swift test --package-path LocalPackages/EpistemosChatDonorContracts` passed:
  72 tests, 0 failures.
- Targeted stale-route scan across the touched AgentFusion/Landing files found
  no old MiniChat/native-chat/Osaurus/GraphChat/NoteChat route tokens.
- Trailing whitespace scan across the touched portal/host/compact/Landing/
  contract/test/provenance files returned no matches.
- Full app `xcodebuild` was not rerun for this small route slice. The known
  protected Work blocker remains outside this pass by directive:
  `Epistemos/Work/WorkSPASchemeHandler.swift:97:9`, missing
  `HTTPURLResponse` return.

Remaining:

- Continue both tracks: keep hardening the new AgentClone/fusion ChatView-2
  surface, and keep widening route/deletion guards around Landing, Note, Graph,
  Mini, and build metadata without touching protected Work/OpenGUI/Goose/MCP
  surfaces.

### Codex continuation 2026-06-25 - portal action catalog

Owner correction carried forward: the new AgentClone-backed chat needs
Epistemos app capabilities, not just a skinned prompt box. The old native chat
engines stay deleted, but portal context should declare the app actions the new
runtime may request and which ones require native approval.

Implemented:

- Added `AgentPortalContextSnapshot.ActionDescriptor` and a bounded
  `actionCatalog` covering app context snapshots, vault search, note
  read/create/update/rewrite/delete, selected-text rewrite, graph read/
  neighborhood/mutate, session resume/summary, skill discovery, and Landing
  route-to-agent.
- Marked mutating actions such as note create/update/delete/rewrite and graph
  mutation with `requiresApproval: true` and `mutatesAppState: true`.
- Added `actionDescriptors` so each portal exposes the relevant app-action
  descriptors from its approved action ids, note context, graph context, vault
  context, and attachments.
- Updated the AgentClone prompt envelope so it includes bounded action
  descriptor lines with approval/mutation metadata instead of only opaque action
  ids.
- Updated route guards, the AgentClone donor provenance JSON, and the
  `agent-clone.chatview2-route-ontology` proof text to require the action
  catalog.
- Did not touch `Epistemos/Work/**`, OpenGUI, Goose, OpenCode,
  `LocalPackages/AgentClone/**`, MCP/native skills, or landing mascot assets.

Verification:

- `xcrun swiftc -parse Epistemos/Views/AgentFusion/AgentPortalContextSnapshot.swift
  Epistemos/Views/AgentFusion/AgentCloneChatHostSurface.swift
  Epistemos/Views/AgentFusion/AgentCompactPortalView.swift
  Epistemos/Views/Landing/LandingView.swift
  Epistemos/State/AgentChatState.swift` passed.
- `jq empty docs/donor-contracts/swift-chat/agent-clone/provenance.json`
  passed.
- `swift test --package-path LocalPackages/EpistemosChatDonorContracts` passed:
  72 tests, 0 failures.
- Targeted stale-route scan across the touched AgentFusion/Landing files found
  no old MiniChat/native-chat/Osaurus/GraphChat/NoteChat route tokens.
- Trailing whitespace scan across the touched portal/host/compact/Landing/
  contract/test/provenance files returned no matches.
- Full app `xcodebuild` was not rerun for this small route slice. The known
  protected Work blocker remains outside this pass by directive:
  `Epistemos/Work/WorkSPASchemeHandler.swift:97:9`, missing
  `HTTPURLResponse` return.

Remaining:

- Continue both tracks: keep hardening the new AgentClone/fusion ChatView-2
  surface, and keep widening route/deletion guards around Landing, Note, Graph,
  Mini, and build metadata without touching protected Work/OpenGUI/Goose/MCP
  surfaces.

### Codex continuation 2026-06-25 - visible portal action descriptors

Owner correction carried forward: the standard chat surface must not expose
overseer/debug diagnostics as the primary panel. Epistemos actions should be
native visible affordances in the rebuilt AgentClone/fusion surface, not hidden
raw strings or resurrected Mini/Note/Graph chat engines.

Implemented:

- Updated `AgentCloneChatHostSurface` so the composer chips and the context
  rail render `AgentPortalContextSnapshot.ActionDescriptor` values directly,
  including title, icon, help text, approval requirement, and mutation/read-only
  detail.
- Added a visible `Portal Actions` rail section that lists descriptor-backed
  actions with native approval/mutation cues.
- Updated `appendBridgeActionIntent` and `appendCompactActionIntent` to carry
  action id/title and explicitly request native approval before mutating app
  state.
- Updated `AgentCompactPortalView` so compact action chips also render
  descriptor-backed titles, icons, approval shields, and help text.
- Tightened the icon helpers to accept the full `ActionDescriptor` rather than
  falling back to raw action-id strings.
- Updated donor guard tests, AgentClone proof text, and provenance so this
  remains part of the ChatView-2 route ontology.
- Did not touch `Epistemos/Work/**`, OpenGUI, Goose, OpenCode,
  `LocalPackages/AgentClone/**`, MCP/native skills, or landing mascot assets.

Verification:

- `xcrun swiftc -parse Epistemos/Views/AgentFusion/AgentCloneChatHostSurface.swift
  Epistemos/Views/AgentFusion/AgentCompactPortalView.swift
  Epistemos/Views/AgentFusion/AgentPortalContextSnapshot.swift
  Epistemos/Views/Landing/LandingView.swift
  Epistemos/State/AgentChatState.swift` passed.
- `swift test --package-path LocalPackages/EpistemosChatDonorContracts` passed:
  72 tests, 0 failures.
- `jq empty docs/donor-contracts/swift-chat/agent-clone/provenance.json`
  passed.
- Targeted stale-route scan across the touched AgentFusion/Landing files found
  no old MiniChat/native-chat/Osaurus/GraphChat/NoteChat route tokens.
- Trailing whitespace scan across the touched portal/host/compact/Landing/
  contract/test/provenance/handoff files returned no matches.
- Full app `xcodebuild` was not rerun for this small route slice. The known
  protected Work blocker remains outside this pass by directive:
  `Epistemos/Work/WorkSPASchemeHandler.swift:97:9`, missing
  `HTTPURLResponse` return.

Remaining:

- Continue both tracks: keep hardening the new AgentClone/fusion ChatView-2
  surface, keep deleting old native chat surfaces/routes where still present,
  and keep widening route/deletion guards without touching protected
  Work/OpenGUI/Goose/MCP surfaces.

### Codex continuation 2026-06-25 - project yml Osaurus metadata removal

Owner correction carried forward: deleting source files is not enough if a
canon project manifest can still restore an old native chat, Osaurus, or native
agent route. `project.yml` is not to be regenerated, but it also must not keep
stale deleted-route package mounts.

Implemented:

- Extended `testProjectMetadataDoesNotMountDeletedNativeChatOrOsaurus` so
  `project.yml` is scanned alongside the generated Xcode project and SwiftPM
  resolution metadata.
- Removed the stale `OsaurusCore` dependency from the app target dependency
  list in `project.yml`.
- Removed the stale `OsaurusCore` local package entry pointing at
  `LocalPackages/osaurus/Packages/OsaurusCore`.
- Reworded remaining vmlx comments in `project.yml` so they describe neutral
  local MLX consolidation without Osaurus route language.
- Updated the AgentClone route-ontology proof text to name `project.yml` as
  guarded metadata.
- Did not touch `Epistemos/Work/**`, OpenGUI, Goose, OpenCode,
  `LocalPackages/AgentClone/**`, MCP/native skills, or landing mascot assets.

Verification:

- `rg -n "OsaurusCore|LocalPackages/osaurus|ActOsaurus|EpistemosOsaurus|\\bOsaurus\\b|\\bosaurus\\b|ChatRouteView|ChatSurfaceCoordinator|ChatCoordinator|MiniChatWindowController|MiniChatView|GraphChatRequest|NoteChatState|NoteChatSidebar|AgentBlueprint|SystemG" project.yml Epistemos.xcodeproj/project.pbxproj Epistemos.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`
  returned no matches.
- `swift test --package-path LocalPackages/EpistemosChatDonorContracts --filter ChatDonorContractsTests/testProjectMetadataDoesNotMountDeletedNativeChatOrOsaurus`
  passed.
- `swift test --package-path LocalPackages/EpistemosChatDonorContracts` passed:
  72 tests, 0 failures.
- `xcrun swiftc -parse Epistemos/Views/AgentFusion/AgentCloneChatHostSurface.swift
  Epistemos/Views/AgentFusion/AgentCompactPortalView.swift
  Epistemos/Views/AgentFusion/AgentPortalContextSnapshot.swift
  Epistemos/Views/Landing/LandingView.swift
  Epistemos/State/AgentChatState.swift` passed.
- Trailing whitespace scan across `project.yml` and the touched donor contract
  test returned no matches.
- Full app `xcodebuild` was not rerun. The known protected Work blocker remains
  outside this pass by directive:
  `Epistemos/Work/WorkSPASchemeHandler.swift:97:9`, missing
  `HTTPURLResponse` return.

Remaining:

- Continue both tracks: keep hardening the new AgentClone/fusion ChatView-2
  surface, keep deleting old native chat surfaces/routes where still present,
  and keep widening route/deletion guards without touching protected
  Work/OpenGUI/Goose/MCP surfaces.
