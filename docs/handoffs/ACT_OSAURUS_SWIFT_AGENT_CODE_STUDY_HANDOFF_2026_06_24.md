# Act / Osaurus / Swift Agent Code Study Handoff - 2026-06-24

## Purpose

This handoff captures the source-grounded research pass requested by the owner:
compare the current Epistemos Act/Osaurus integration against the new native
Swift agent repos, with a visual-first implementation bias.

Owner intent, reduced:

- The visible Act chat must be Epistemos' polished native/pixel chat, not
  Osaurus UI and not another app's UI.
- Osaurus should remain an engine/capability layer unless explicitly replaced
  after parity proof.
- Every Osaurus capability that remains must be re-expressed through Epistemos
  UI: model picker, tools, skills, MCP, permissions, popovers, privacy review,
  sandbox/dependency setup, computer use, streaming, stats, and settings.
- Mini Chat, Graph Chat, and Note Chat should not drift into separate chat
  ontologies. They should mount or route through the same Act contract.
- Visual parity should come first enough to see what exists and what is
  missing; hardening follows under the same UI contract.

## Sources Read

Local owner/canon:

- `/Users/jojo/.codex/attachments/6b80a1ff-41ce-471b-9106-7db75c8260c3/goal-objective.md`
- `docs/CODEX_BUILD_GOAL_2026_06_22.md`
- `docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md`
- `docs/OSAURUS_P3_IMPORT_PLAN_2026_06_21_addendum.md`

Current Epistemos/Osaurus code:

- `Epistemos/Views/Chat/ChatView.swift`
- `Epistemos/Views/Chat/ChatInputBar.swift`
- `Epistemos/Views/Landing/LandingView.swift`
- `Epistemos/ActOsaurus/ActOsaurusBridge.swift`
- `Epistemos/ActOsaurus/ActOsaurusStreamingHandler.swift`
- `Epistemos/Views/Settings/ActCloneSettingsView.swift`
- `LocalPackages/osaurus/Packages/OsaurusCore/Epistemos/EpistemosOsaurusChatSessionBridge.swift`
- `LocalPackages/osaurus/Packages/OsaurusCore/Epistemos/EpistemosOsaurusManagementPresenter.swift`
- `LocalPackages/osaurus/Packages/OsaurusCore/Tools/ToolRegistry.swift`
- `Epistemos/Views/MiniChat/MiniChatView.swift`
- `Epistemos/Views/Notes/NoteDetailWorkspaceView.swift`
- `Epistemos/Views/Graph/HologramSearchSidebar.swift`

Cloned/read under `/tmp/epistemos-swift-agent-donor-audit`:

- `agent`: https://github.com/macos26/Agent.git at `fc07409`, MIT source license, trademark caveat in README.
- `1amageek-SwiftAgent`: https://github.com/1amageek/SwiftAgent.git at `7b4db2f`, no LICENSE file found in quick clone; README claims/indicates package use, license needs verification before vendoring.
- `SwiftedMind-SwiftAgent`: https://github.com/SwiftedMind/SwiftAgent.git at `48bfda9`, MIT.
- `Swarm`: https://github.com/christopherkarani/Swarm.git at `c771f18`, MIT.
- `SwiftAIAgent`: https://github.com/ShenghaiWang/SwiftAIAgent.git at `1bce237`, no LICENSE file found in quick clone; treat as study-only until verified.
- `AgentSDK-Swift`: https://github.com/fumito-ito/AgentSDK-Swift.git at `bfa06f6`, MIT.

## Current Epistemos Findings

### Owner UI already exists

`ChatView` is the real Act visual owner surface. It already has an Act/Osaurus
mode seam:

- `actUsesOsaurus` is defined in `ChatView.swift:185`.
- `composerMode: ChatInputComposerMode` is defined in `ChatView.swift:190`.
- Act constrains supported modes to `.agent` in `ChatView.swift:235-243`.
- Live assistant text is filtered through `UserFacingModelOutput` in
  `ChatView.swift:20`, `ChatView.swift:541`, and `ChatView.swift:1726-1752`.
- `ChatInputComposerMode.osaurusAct` exists in `ChatInputBar.swift:51-53`.
- The Act placeholder lives in `ChatInputBar.swift:169`.
- Landing already has Act search copy in `LandingView.swift:187-203`.

Conclusion: do not replace the visible chat with Agent!, Osaurus, OpenChamber,
or any WebKit app. The visual baseline is the Epistemos chat/landing/input
system.

### Osaurus already has a usable headless bridge

`EpistemosOsaurusChatSessionBridge` is the strongest current Act seam:

- Event enum at `EpistemosOsaurusChatSessionBridge.swift:64` includes:
  `textDelta`, `thinkingDelta`, `toolStarted`, `toolCompleted`, and
  `generationStats`.
- Native secret and clarify presenter hooks exist at
  `EpistemosOsaurusChatSessionBridge.swift:84` and `:91`.
- `streamTurnEvents(...)` starts at `EpistemosOsaurusChatSessionBridge.swift:127`.
- It registers runnable sandbox tools before each turn at
  `EpistemosOsaurusChatSessionBridge.swift:198`.
- Tool events are emitted in `emitAssistantToolEvents` at
  `EpistemosOsaurusChatSessionBridge.swift:326`.
- Visible assistant text is emitted in `emitVisibleAssistantDelta` at
  `EpistemosOsaurusChatSessionBridge.swift:355`.
- Generation stats are emitted at `EpistemosOsaurusChatSessionBridge.swift:403`.

Conclusion: the Osaurus protocol/UI leakage problem should be solved by
rendering these events correctly in Epistemos chrome. Do not render raw prefill,
stats, tool JSON, or Osaurus-side panels into the chat transcript.

### Osaurus native management surface is already broad

`EpistemosOsaurusManagementPresenter` exposes many native management APIs:

- `actSettingsSnapshot()` at `:813`
- `systemPermissionRows()` at `:952`
- `toolPermissionRows()` at `:1005`
- `skillRows()` at `:1089`
- `pluginRows()` at `:1148`
- `agentRows()` at `:1168`
- native tool permission presenter at `:1188`
- privacy review presenter at `:1209`
- `computerUsePolicySnapshot()` at `:1251`
- `providerRuntimeSnapshot()` at `:1283`
- `connectMCPProviders()` at `:1343`
- `privacyFilterSnapshot()` at `:1353`
- `dependencySnapshot()` at `:1415`
- `repairSandboxPluginDependencies()` at `:1435`
- `setCurrentModel()` and `modelPicks()` at `:1458` and `:1463`

Conclusion: Act settings should not be a new Osaurus page. It should be the
existing Epistemos settings tab completing this presenter map.

### Mini, Note, and Graph are still separate surfaces

Mini Chat is a large standalone implementation:

- `MiniChatView` starts at `MiniChatView.swift:33`.
- `MiniChatInputBar` starts at `MiniChatView.swift:737`.
- It has its own Act routing and stream handling around `MiniChatView.swift:2456`.

Note and Graph are partial route/escalation paths:

- Note's Act mode routes to main via `submitActOsaurusPrompt` around
  `NoteDetailWorkspaceView.swift:2537-2594`.
- Graph has its own operating-mode/sidebar composer and posts Act prompts in
  `HologramSearchSidebar.swift`.

Conclusion: parity will keep drifting until there is one shared Act chat
contract for main, mini, graph, and note. The shared unit can still render
differently by container size, but it must share composer semantics, event
rendering, model/tools/settings surfaces, and session identity.

## Swift Repo Assessment

### Agent! (`macos26/Agent`)

What it is:

- Full native macOS SwiftUI app.
- Actual UI shell, toolbar, input, activity log, settings popovers.
- Capability claims include macOS automation, Accessibility, AppleScript,
  ScriptingBridge, Safari automation, Xcode tools, MCP, privileged helper,
  file diffs/rollback, memory, subagents, fallback chain, and provider routing.

Source facts read:

- `Agent/Views/ContentView/ContentView.swift`
- `Agent/Views/Header/HeaderSectionView.swift`
- `Agent/Views/Input/InputSectionView.swift`
- `Agent/AgentViewModel/Core/RunStop.swift`
- `Agent/AgentViewModel/TabTask/ToolLoop.swift`
- `Agent/AgentViewModel/TaskExecution/MCPTools.swift`

Useful code motifs:

- Real app lifecycle/run/stop/queue pattern in `RunStop.swift`.
- Tool loop processing in `ToolLoop.swift:21`.
- MCP tool execution path in `MCPTools.swift:11`.
- Native toolbar/popover capability inventory.

Fit:

- Best visual app donor only in the sense that it is an app, but visually it is
  not Epistemos. It is utility/default macOS chrome, not the polished
  Epistemos Act chat.
- Good capability checklist and possible macOS automation/XPC/tool-loop donor.
- Do not transplant the shell. Harvest only after mapping each capability into
  Epistemos UI.

### 1amageek SwiftAgent

What it is:

- Pure Swift agent framework, not a visible app.
- Built around FoundationModels with optional OpenFoundationModels provider lane.
- Strongest Swift-native permission/sandbox/MCP/skills donor.

Source facts read:

- `Sources/SwiftAgent/IO/AgentTurnExecutor.swift:12` and `:33`
- `Sources/SwiftAgent/Security/PermissionMiddleware.swift:80`, `:150`, `:353`
- `Sources/SwiftAgent/Security/SandboxExecutor.swift:27`, `:185`
- `Sources/SwiftAgentMCP/MCPClientManager.swift:47`
- `Sources/SwiftAgentSkills/SkillDiscovery.swift:21`, `:64`

Useful code motifs:

- `AgentTurnExecutor` emits run lifecycle events, handles timeout,
  cancellation, and approval bridging.
- Permission evaluation order is explicit: final deny, session memory,
  overrides, deny, authorization middleware, allow, minimum permission mode,
  default action.
- `SandboxExecutor` wraps macOS `sandbox-exec` with network/file policy.
- `MCPClientManager` loads `.mcp.json`, connects/disconnects, enables/disables,
  discovers tools, and exposes SwiftAgent tool adapters.
- `SkillDiscovery` searches project ancestors and home/config roots including
  `.agents`, `.codex`, `.claude`, `.claw`, and `.omc`.

Fit:

- Best candidate for a future native Act engine lane or hardening donor.
- Not a visual donor.
- License must be verified before vendoring because no LICENSE file was found
  in the quick clone.

### Swarm

What it is:

- Pure Swift agent/multi-agent/workflow framework.
- Broadest hardening/reliability donor.

Source facts read:

- `Sources/Swarm/Core/AgentRuntime.swift:31`
- `Sources/Swarm/Core/AgentRuntime.swift:221`
- `Sources/Swarm/Core/AgentEvent.swift:31-48`
- `Sources/Swarm/Resilience/FallbackChain.swift:115`, `:234`
- `Sources/Swarm/Workflow/Workflow+Durable.swift:4-57`

Useful code motifs:

- Event model separates lifecycle, tool, output, handoff, and observation.
- `InferenceProvider` abstracts Foundation Models, cloud, Ollama, MLX-style
  lanes.
- Resilience includes fallback chains, circuit breakers, and rate limiting.
- Durable workflow checkpoint/resume is first-class.
- Memory, MCP, guardrails, observability, and provider selection are all
  present.

Fit:

- Best donor for "harden eventually": durable workflows, memory, fallback,
  guardrails, observation, provider abstraction.
- Not a visual donor and likely too broad to vendor wholesale into Act now.
- Best used as a later framework or motif source after the Epistemos Act UI
  contract is stable.

### SwiftedMind SwiftAgent

What it is:

- Native Swift agent SDK focused on OpenAI/Anthropic sessions, transcripts,
  typed tools, streaming, and structured output.

Source facts read:

- `Sources/OpenAISession/OpenAIAdapter+Streaming.swift:9`
- Internal streaming loop uses `allowedSteps = 20` at `:75`.
- Queued tool calls execute after response completion at `:243` and
  `executeQueuedToolCalls` starts at `:550`.

Fit:

- Best clean reference for transcript/streaming adapter design and tests.
- Useful if Epistemos wants a cloud-adapter lane independent of Osaurus.
- Not a replacement for Osaurus capabilities or visible UI.

### SwiftAIAgent

What it is:

- Early Gemini-centric Swift agent/workflow/MCP package.
- README and examples show workflow/tool/MCP intent, but it says it is early.

Fit:

- Study-only for now.
- License was not found in quick clone; do not vendor until verified.
- Not a primary Act replacement.

### AgentSDK-Swift

What it is:

- Small early Swift implementation of OpenAI Agents SDK concepts.
- MIT.

Fit:

- Tertiary reference for guardrail/handoff/tool abstractions.
- Too small/early to replace Act or Osaurus.

## Recommendation

### Owner clarification: why "full port + reskin" may be necessary

The owner clarified an important implementation reality after this first pass:
in previous attempts, "just use my app shell and native chrome" was too
underspecified for agents. They would keep the shell native but fail to surface
all donor capabilities because the donor app's feature topology was no longer
visible. That creates silent omissions: missing buttons, missing permission
flows, missing settings, missing MCP/skills, missing popovers, and missing
stream states.

So the robust strategy is not a thin adapter. The robust strategy is a **full
parity port/reskin**:

- Clone or keep the donor source complete enough that every capability remains
  discoverable.
- Treat donor UI/source as the exhaustive feature inventory.
- Rebuild or reskin each visible surface into Epistemos-native components.
- Keep an explicit parity ledger so every donor surface has an Epistemos
  surface, an engine hook, and proof.
- Do not expose donor chrome to the user except as an internal debugging
  fallback while parity is being built.

This gives the "fail-safe" property the owner wants: the donor app stays whole
as a capability map, but Epistemos owns the final ontology and visual language.
The agent should not summarize this as "just use Epistemos UI"; that loses the
exhaustiveness constraint. The correct summary is:

> Full donor capability port, Epistemos-native reskin, with exhaustiveness
> gates. No donor UI leakage in the final product.

### Best path now

1. Keep the Epistemos Act UI as the visual source of truth.
2. Keep Osaurus complete as the current capability donor/engine while
   completing the native surface map.
3. Use the new Swift repos as hardening donors:
   - 1amageek SwiftAgent for permissions, sandbox, MCP, skills, and a possible
     future native engine lane.
   - Swarm for durable workflows, memory, fallback, guardrails, observation,
     provider abstraction.
   - Agent! for macOS automation/XPC/tool-loop capability examples only.
   - SwiftedMind SwiftAgent for transcript/streaming adapter tests.
4. Do not replace Act visually with Agent!, Swarm demos, Osaurus views, WebKit,
   OpenChamber, or OpenWork.

Interpretation: "do not replace visually" does not mean "do a thin adapter." It
means do a full parity port where the donor's feature graph is exhaustively
represented in Epistemos chrome.

### Why not clone Agent! first as the visible Act?

Agent! is the only full native Swift app among the new Swift repos, but its
visual ontology is not the owner Epistemos Act chat. Cloning it first would
repeat the same failure mode as Osaurus UI: a second app surface inside
Epistemos. It is useful as a capability checklist, not as the chrome.

### Why not replace Osaurus immediately with SwiftAgent or Swarm?

Osaurus already has:

- in-process Act stream events,
- tools,
- skills,
- agents,
- plugins,
- MCP,
- model picker,
- sandbox lifecycle,
- computer use,
- privacy review,
- system/tool permissions,
- dependency repair,
- prompt/secret presenters,
- generation stats.

SwiftAgent and Swarm are promising but would require a new parity buildout.
Use them to harden the architecture and to prototype a future native engine
behind a protocol, not to rip out Osaurus before the UI and capability ledger
are green.

## Visual-First Implementation Order

0. Freeze the donor surface inventory.

   Before touching visible UI, create an inventory from the donor:

   - chat states,
   - toolbar buttons,
   - slash commands,
   - model picker rows,
   - tool registry rows,
   - MCP/provider rows,
   - permission prompts,
   - secret prompts,
   - privacy review prompts,
   - sandbox/dependency flows,
   - computer-use flows,
   - settings tabs,
   - streaming/progress/tool-call states,
   - recents/session surfaces.

   This inventory is the anti-omission mechanism. Every item needs:
   donor source file/line, Epistemos target file/component, state mapping,
   proof status, and screenshot/proof requirement.

1. Define one Act chat contract.

   The contract should be engine-neutral but Osaurus-backed today:
   `send(prompt, attachments, model, sessionID) -> AsyncStream<ActEvent>`.
   Events should match the existing Osaurus bridge shape: visible text,
   hidden thinking, tool started/completed, generation stats, secret prompt,
   clarify prompt, permission prompt, privacy review.

2. Make main chat the canonical renderer.

   `ChatView` + `ChatInputBar` + `LandingView` are the visual owners. Fix the
   raw-event leakage and render:

   - visible text in assistant bubbles,
   - thinking hidden/collapsible outside normal transcript,
   - tool calls as native chips or side/detail rows,
   - stats as metadata, not text,
   - permission/secret/clarify prompts as native Epistemos popovers/sheets.

3. Collapse mini/graph/note drift.

   Do not keep implementing three separate chat engines. Make Mini Chat,
   Graph Chat, and Note Chat either mount the shared Act contract or route
   into the same session with a compact renderer. Current code shows they are
   still distinct enough to drift.

4. Complete native settings surfaces from Osaurus presenter.

   Build the settings tab from `EpistemosOsaurusManagementPresenter` rather
   than from Osaurus views:

   - model picks,
   - current model,
   - agents,
   - plugins,
   - skills,
   - MCP connect/disconnect,
   - computer-use policy,
   - privacy filter,
   - system permissions,
   - tool permission rows,
   - sandbox lifecycle,
   - dependency repair.

5. Add donor ledger before replacing any engine.

   Create a capability matrix where every Osaurus capability has a native
   Epistemos surface and an engine hook. Only after that should a SwiftAgent or
   Swarm-backed lane be tested against the same UI contract.

6. If a new donor is chosen, port it the same way.

   For OpenWork/OpenChamber/Agent!/SwiftAgent/Swarm, do not cherry-pick only the
   obvious UI. First import or study enough of the donor to preserve its full
   capability map, then reskin into Epistemos. This prevents the repeated
   failure where the visible shell looks native but half the donor app is gone.

## Claude Directive

Continue from the current worktree, not memory. Do not import another visible
chat app. The visual invariant is:

`Epistemos LandingView + ChatView + ChatInputBar + owner pixel/native chrome`.

The engine invariant is:

`ActEvent` streams are hidden behind native Epistemos rendering. Osaurus is
allowed underneath today; SwiftAgent/Swarm can be added only as engine lanes or
hardening donors.

Concrete next work:

1. Build the donor surface inventory/parity ledger first.
2. Build or identify the single shared Act event renderer used by main chat.
3. Make Mini Chat, Graph Chat, and Note Chat use that renderer/session contract
   instead of parallel chat implementations.
4. Map every `EpistemosOsaurusChatSessionEvent` into native UI.
5. Wire every `EpistemosOsaurusManagementPresenter` capability into Epistemos
   settings/model/tool UI.
6. Keep a visible gap ledger: capability, source API, Epistemos surface,
   verified state, screenshot/proof needed.
7. Do not claim parity from builds alone; visual proof is required when coding
   resumes.
