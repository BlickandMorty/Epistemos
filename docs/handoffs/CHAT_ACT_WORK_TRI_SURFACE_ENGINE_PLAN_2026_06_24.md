> ⛔ SUPERSEDED 2026-06-26 — Goose is the SINGLE surface. The 3-engine federation (Chat=AgentClone / Work=OpenGUI) described here is RETIRED. Canonical plan: `docs/research/SURFACE_EMBEDDING_WEBVIEW_VS_NATIVE_DECISION_2026_06_25.md` (§0, §15). Do not follow the federation / OpenGUI directives below.

# Chat / Act / Work Tri-Surface Engine Plan - 2026-06-24

## Purpose

This is the dedicated current plan for the next Epistemos agent architecture
decision. It supersedes older donor-choice assumptions that treated Work as an
OpenWork/OpenChamber-only embed problem or Act as an Osaurus-only repair
problem.

Owner intent:

- Keep at most three main user-facing surfaces.
- Preserve Epistemos visual IP and native chrome.
- Use full donor clones for study so hidden features are not missed.
- Do not let any donor UI become the app's identity by accident.
- Prefer native Swift where it materially helps, but do not sacrifice actual
  agent capability.
- Prune means real removal, not hiding. Old Chat, old main ChatView,
  ChatView-v1/v2 detours, old Act-as-chat/Osaurus chrome, and duplicate
  mini/graph/note chat implementations are not fallback product surfaces.
  Inventory them, detach routes to them, and delete/retire their backend/view
  code as soon as the replacement surface slice keeps the app buildable.
- Preserve the landing page shell, but simplify it into the only top-level
  entry for the three new surfaces: Chat, Act, and Work. Do not keep the old
  "tap anywhere to start a conversation" behavior as the default ontology.
- Preserve only proven Epistemos primitives from the old chat era: theme
  tokens, compact model/engine picker language, recents/session identity,
  native permission/tool surfaces, and blur/typewriter/ASCII motion where they
  still work.

The three surfaces are now:

1. **Chat** - Swift-heavy regular chat, most App-Store-shaped.
2. **Act** - Goose-powered native action surface.
3. **Work** - OpenGUI-style multi-engine workbench.

Hermes is not removed. It enters Work first as an engine and can later become a
full Companion surface if it proves central enough to deserve a fourth mental
category.

## Agent Assignments

This plan is the single shared coordination document for the three
implementation agents. Do not create new competing architecture plans unless
the owner explicitly asks.

Current assignment:

- **Work agent / Claude** owns only Work: OpenGUI-style multi-engine workbench,
  OpenCode first, later Goose/Codex/Claude Code/Pi/OMP/Hermes engines.
- **Chat agent** owns only Chat: Swarm-first Swift native regular chat.
- **Act agent** owns only Act: Goose-powered native action surface.

Each agent may read all docs and donor clones, but should only edit its owned
surface unless it must introduce a small shared contract. Shared contract edits
must be minimal, named generically, and usable by all three surfaces.

If multiple agents work on `main`, avoid overlapping files. Before touching a
shared file such as app routing, recents, settings, model picker, or common
chat types, inspect current changes and keep the edit as small as possible.

## Shared Visual Target

All three surfaces should visually converge on the same Epistemos-native
interpretation of the OpenCode TUI:

- flat, minimal, high-contrast, no gradients as a primary surface language
- compact monospaced/pixel-coded controls where appropriate
- native macOS chrome and focus behavior
- theme-aware rendering using Epistemos tokens, not generic SwiftUI defaults
- restrained toolbar density, clear icon affordances, no marketing-style cards
- model/engine picker visible and compact
- sessions/recents feel like one app, not three apps
- permission prompts and tool cards rendered as native Epistemos UI
- blur reveal, typewriter/ASCII motion, and Epistemos transitions preserved as
  reusable primitives in the new surfaces, not as a reason to keep old chat
  routes

Do not copy donor visual chrome as the product identity. Donor UI is reference
material; Epistemos owns the final look. Also do not preserve broken
Epistemos chrome just because it is old. If a current surface does not work or
fights the new architecture, prune it and rebuild the behavior through the
assigned surface.

## Landing And Legacy Chat Deletion Rule

The landing page is the retained app shell. It should become the plain,
deliberate chooser for:

1. Chat
2. Act
3. Work

The landing page should not route through a generic "tap anywhere to start a
conversation" mode, an old main ChatView, an old ChatView-v1/v2 destination, or
the current Act-as-chat/Osaurus surface. Those were transitional or broken
ontologies.

Deletion sequence for each owned surface:

1. inventory the old routes, views, state objects, stores, and backend services
   that still make the old chat reachable;
2. identify which primitives are worth keeping: theme tokens, model picker
   vocabulary, recents/session identity, permission/tool card patterns, and
   blur/typewriter/ASCII motion;
3. build the smallest new Chat/Act/Work-owned replacement route;
4. reroute the landing page and any mini/graph/note portals to the replacement;
5. remove the old destination and old backend wiring once the replacement keeps
   the app compiling;
6. leave no duplicate "old chat" surface as a hidden fallback unless the owner
   explicitly asks for an archival/debug flag.

Mini Chat, Graph Chat, and Note Chat should not keep private chat
implementations. They should become portals into the new Chat, Act, or Work
session identity after the relevant replacement route exists.

## Research Sources Read

Local canon and current docs:

- `docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md`
- `docs/handoffs/RESEARCH_CLONES_CANON_RATIONALE_2026_06_24.md`
- `docs/handoffs/RESEARCH_CLONES_INVENTORY_2026_06_24.md`
- `docs/handoffs/WORK_INTEGRATION_SHAPE_RECOMMENDATION_2026_06_24.md`
- `docs/handoffs/ACT_OSAURUS_SWIFT_AGENT_CODE_STUDY_HANDOFF_2026_06_24.md`

Work and engine clones:

- `.research-clones/work/opengui/README.md`
- `.research-clones/work/opengui/docs/adr/0005-opengui-runtime-backend-split-and-sdk.md`
- `.research-clones/work/opengui/packages/runtime/README.md`
- `.research-clones/work/opencode/README.md`
- `.research-clones/work/openwork/README.md`
- `.research-clones/work/openchamber/README.md`
- `.research-clones/work/paseo/README.md`
- `.research-clones/work/paseo/packages/protocol/src/provider-manifest.ts`
- `.research-clones/work/goose/README.md`
- `.research-clones/work/goose/crates/goose-sdk/README.md`
- `.research-clones/work/goose/ui/sdk/README.md`
- `.research-clones/work/goose/ui/desktop/README.md`
- `.research-clones/work/goose/Cargo.toml`
- `.research-clones/agents/hermes-agent/README.md`
- `.research-clones/agents/hermes-agent/apps/desktop/package.json`
- `.research-clones/agents/pi/README.md`
- `.research-clones/agents/oh-my-pi/README.md`

Swift Chat / Act candidates:

- `.research-clones/swift-act/agent-macos26/README.md`
- `.research-clones/swift-act/swarm/README.md`
- `.research-clones/swift-act/swarm/Package.swift`
- `.research-clones/swift-act/swiftagent-swiftedmind/README.md`
- `.research-clones/swift-act/swiftagent-swiftedmind/Package.swift`
- `.research-clones/swift-act/swiftagent-1amageek/README.md`
- `.research-clones/swift-act/swiftagent-1amageek/Package.swift`
- `.research-clones/swift-act/agentsdk-swift/README.md`
- `.research-clones/swift-act/agentkit/README.md`
- `.research-clones/swift-act/swiftaia-agent/README.md`
- `.research-clones/swift-act/foundation-models-framework-example/README.md`
- `.research-clones/swift-act/mcp-swift-sdk/README.md`

## Current Research Facts

### OpenGUI

OpenGUI is not the final engine. It is the best current adapter/workbench
substrate because it explicitly separates Runtime, Backend, Frontend, and
Shell.

The key local evidence is OpenGUI ADR 0005:

- Runtime owns harness adapters, normalized events, inventory, and sends.
- Backend owns HTTP/SSE/WebSocket, queue, arbitration, auth, and queue
  persistence.
- Frontend owns presentation.
- SDK v1 is in-process `@opengui/runtime`.
- Runtime operations are scoped by directory + harness + session.

Epistemos should use this shape, not necessarily OpenGUI's visible React UI.

### Goose

Goose is a serious Act/Work engine candidate:

- Apache-2.0.
- Rust workspace.
- Desktop, CLI, API, server, ACP, MCP, providers, recipes, security, sessions.
- Local clone: `.research-clones/work/goose`, HEAD `eea6989`.
- Local size: about 661 MB.

Important correction: Goose has a `goose-sdk` crate with a UniFFI feature, but
the current UniFFI surface is only a `ping -> pong` scaffold. Therefore the
first practical Epistemos integration should be process/API/ACP based. UniFFI
is a later hardening path after a stable Rust library boundary is identified or
created.

### OpenCode

OpenCode remains the first Work coding engine and source-of-truth reference
for coding sessions. It is not displaced until Goose wins on real Epistemos
flows:

- repo editing
- sessions
- streaming
- permissions
- model/provider routing
- TUI expert mode
- tool behavior

### Paseo

Paseo is not rejected. It is a Work orchestration donor:

- daemon + clients
- `run`, `attach`, `send`
- Claude Code, Codex, Copilot, OpenCode, Pi
- mobile/desktop/web/CLI
- handoff, loop, advisor, committee workflows

Because it overlaps with Work instead of defining a new surface, it should not
be the third visible chat. It can later replace or augment parts of the Work
backend if its daemon model proves better than OpenGUI's runtime/backend split.

License posture: AGPL-3.0. Treat as study/clean-room unless the owner accepts
AGPL obligations for the relevant product scope.

### Hermes

Hermes is broad and valuable, but dense:

- Python core.
- Electron desktop.
- TUI.
- gateway and messaging platforms.
- memory, skills, cron, profiles.
- plugins, providers, MCP/security/config.

Hermes should enter in rings:

1. Work engine first: prompt, stream, sessions, tool events, model state if
   possible.
2. Native Epistemos companion capabilities: memory, skills, cron, profiles,
   messaging, gateway.
3. Full Hermes Desktop recode/reskin only after rings 1 and 2 prove value.

Do not full-port Hermes Desktop as the first task. It is too likely to repeat
the Osaurus/OpenWork failure mode: another full app that leaks its ontology
into Epistemos.

### Swift Candidates For Chat

Recommended Chat substrate: **Swarm first**.

Why:

- MIT.
- Pure Swift.
- Swift 6.2 strict concurrency.
- agents, tools, streaming, memory, guardrails, provider selection.
- durable workflow checkpoint/resume.
- MCP integration via `SwarmMCP`.
- observability and fallback/resilience patterns.
- enough capability to grow without becoming a whole foreign app UI.

Secondary donors:

- **SwiftedMind SwiftAgent**: compact OpenAI/Anthropic session, transcript,
  typed tools, streaming, and structured output. Good for Chat ergonomics and
  testable session design.
- **Agent! macOS26**: strong full-app native capability donor, not the Chat
  foundation. Harvest automation, provider picker, Accessibility, AppleScript,
  Xcode, rollback, hotword, remote control, and helper patterns. Do not
  transplant its visible shell.
- **1amageek SwiftAgent**: promising FoundationModels/OpenFoundationModels,
  MCP, skills, sandbox, permission, actor/distributed-agent ideas. Because the
  quick local license sweep did not find a root LICENSE file even though README
  badges indicate MIT, verify license before vendoring source.
- **Foundation Lab**: best Apple Foundation Models workbench/evidence donor,
  not a main Chat engine.
- **MCP Swift SDK**: official MCP Swift substrate for native MCP client/server.
- **AgentSDK-Swift**: early OpenAI Agents SDK port; study-only unless it
  matures.
- **AgentKit**: useful Bedrock/MCP reference, but AWS-shaped.
- **SwiftAIAgent**: early Gemini/workflow reference; no clear license in quick
  sweep, study-only until verified.

## Final Surface Plan

### 1. Chat

Role:

- regular polished native conversation surface.
- most App-Store-shaped.
- smallest visible blast radius.
- completely replaces the old general chat destination and its backend wiring.
- app-native model picker, recents, settings, transcripts, permissions,
  animation, blur/typewriter/ASCII reveal.
- new code-minimal/pixel-flat visual treatment around the Swift substrate,
  not generic SwiftUI panels or donor app chrome.

Foundation:

- Swarm-first native Swift substrate.
- SwiftedMind SwiftAgent as a compact session/tool/streaming donor.
- Foundation Lab for Apple Foundation Models recipes, run evidence, and
  Playground/Runs inspiration.
- MCP Swift SDK for native MCP.

Do not:

- make Agent! the visible Chat app.
- embed a web/Electron chat.
- force Goose/Hermes into Chat.
- inherit the current broken Act-as-chat UI or generic Swift-looking controls.
- preserve the old main ChatView, old ChatView-v1/v2 route, or old chat backend
  as the product Chat. They are deletion targets after the new route compiles.

### 2. Act

Role:

- action/execution chat.
- broader than regular Chat.
- local agent body with tools, permissions, MCP, recipes, desktop automation,
  and stronger task execution.
- complete replacement for the current Act-as-chat/Osaurus surface. The current
  Act UI and old Osaurus chat wiring are deletion targets, not preservation
  targets.

Foundation:

- Goose first as the engine candidate.
- SwiftUI front end remains Epistemos.
- Start with Goose server/API/ACP/process integration.
- Later create or use Goose UniFFI only for stable core pieces after proof.

Why not UniFFI first:

- Current Goose UniFFI is only a stub.
- Direct Rust-Swift binding too early risks fighting Goose internals.
- Process/API first proves sessions, prompts, streaming, permissions, MCP,
  cancellation, logs, and tool events without committing to a brittle FFI.

Do not:

- preserve the current Act-as-chat UI for visual parity.
- treat Goose Desktop UI as the Act UI.
- replace Chat with Goose.
- claim App Store friendliness until helper/process/sandbox behavior is
  verified.
- keep old Act chat backend/view code as hidden fallback after the Goose-backed
  Act route is buildable.

### 3. Work

Role:

- coding/project/multi-engine workbench.
- repo sessions, terminal, diffs, worktrees, multi-agent orchestration, MCP,
  skills, engine-specific panels, and expert TUI access.

Foundation:

- OpenGUI-style runtime/backend/harness layer.
- Epistemos owns all visible chrome and primary identity.
- Engine picker includes:
  - OpenCode
  - Goose
  - Codex
  - Claude Code
  - Pi / OMP
  - Hermes

Donor roles:

- OpenGUI: runtime/adapter shape.
- OpenCode: first coding engine and source-of-truth backend reference.
- Goose: general local agent engine candidate.
- Hermes: personal-agent engine first, full native companion later.
- Paseo: daemon/orchestration/session lifecycle donor.
- OpenWork: fallback/reference for OpenCode cowork features, MCP/skills,
  permissions, templates, debug, and setup.
- OpenChamber: UX donor for mini chat, session switching, diffs, worktrees,
  branchable timelines.
- OpenCowork: tool/sandbox/computer-use/document skills donor.
- Pi/OMP: additional coding engines, especially OMP as high-capability Pi
  challenger.

Do not:

- make each engine a separate user-facing chat.
- make OpenGUI's React UI the app identity.
- delete current OpenWork fallback before OpenGUI/OpenCode proof passes.

## Implementation Order

### Phase 0 - Coordination Lock

- Use this document as the current north star.
- Landing is the only retained top-level shell. It should expose Chat, Act, and
  Work deliberately, not through "tap anywhere to start a conversation."
- Each surface owner must begin with a deletion inventory for old chat routes,
  backend wiring, stores, and duplicate mini/graph/note chat implementations
  that fall under its surface.
- Claude continues Work/OpenGUI only.
- The Chat agent starts Chat/Swarm only.
- The Act agent starts Act/Goose only.
- Treat older Work/Act docs as useful history but superseded where they
  conflict with this tri-surface split.
- Treat current Act-as-chat/Osaurus UI as pruneable legacy once Act/Goose
  replacement proof exists. Do not preserve it as the target.
- Treat old ChatView/main chat/chat-v1/v2 destinations as pruneable legacy once
  Chat/Swarm replacement proof exists. Do not preserve them as fallback UX.
- Do not rip out current Work/OpenWork/OpenCode code while Claude is mid-loop.

### Phase 1 - Work Proof Through OpenGUI

Owner: Work agent / Claude.

Prove one native Epistemos Work input can:

1. list engines/harnesses,
2. open or create an OpenCode session,
3. send a prompt,
4. stream events back,
5. render tool events and assistant text in Epistemos UI,
6. preserve native recents/session identity.

Keep OpenWork as fallback.

### Phase 2 - Goose Adapter Spike

Owner: Work agent / Claude for Work; Act agent only reads results.

After OpenGUI/OpenCode proof:

1. add Goose as a Work engine,
2. compare startup, session creation, streaming, permission behavior, MCP,
   cancellation, logs, and tool events,
3. test whether Goose should also power Act.

### Phase 3 - Chat Swift Substrate Spike

Owner: Chat agent.

Start Chat with Swarm:

1. inventory and detach the old general chat destination, old ChatView-v1/v2
   routes, old chat backend services, and duplicate mini/graph/note chat
   implementations that still point to the old stack,
2. create a minimal Epistemos-native Chat engine adapter,
3. support prompt, stream, tool event, transcript, cancellation,
4. add MCP Swift SDK path,
5. compare SwiftedMind SwiftAgent for simpler session ergonomics,
6. remove old chat code once the replacement route compiles and the landing
   page opens the new Chat surface.

Agent! remains a capability donor, not the shell.

### Phase 4 - Act Goose Surface

Owner: Act agent.

Build Act as:

- Epistemos SwiftUI.
- Goose process/API/ACP bridge.
- native permissions.
- native model/engine picker.
- native tool cards.
- native recents.
- native settings.

Start by inventorying and detaching old Act-as-chat/Osaurus routes, view code,
and backend wiring. Only after the Goose-backed Act route works should UniFFI
be explored for stable Goose core pieces or old Act code be fully deleted.

### Phase 5 - Hermes In Work

Owner: Work agent / Claude.

Add Hermes as a Work engine:

- start via CLI/TUI/gateway-compatible bridge,
- stream into Work,
- expose model/status/sessions where possible,
- render tool/memory/cron/skill affordances as native advanced panels.

Do not begin full Hermes Desktop recode until this engine layer proves useful.

### Phase 6 - Companion Decision

Only after Hermes Work engine is stable:

- decide whether Hermes deserves a fourth mental category,
- or fold memory/cron/messaging into Work advanced panels,
- or expose "Companion" as a mode rather than a top-level chat.

## Non-Negotiables

- Epistemos owns visible chrome.
- OpenCode TUI minimalism is the shared visual target, translated into
  Epistemos-native Swift/AppKit/WebKit surfaces.
- Preserve working Epistemos IP primitives, not broken surface implementations.
- Delete/retire old chat destinations and backend wiring after replacement
  proof; do not keep old Chat/Act chat stacks as hidden product surfaces.
- Claude only owns Work unless the owner reassigns it.
- Chat and Act agents must not rework Work/OpenGUI.
- Work agent must not rework Chat/Swarm or Act/Goose except for shared
  contracts explicitly needed by Work.
- One native recents/session identity system.
- Mini Chat, Graph Chat, and Note Chat are portals into Chat, Act, or Work, not
  separate old chat implementations.
- Landing page is the only top-level shell and should expose Chat, Act, and
  Work directly. No default "tap anywhere to start a conversation" ontology.
- Permission prompts are native Epistemos surfaces.
- Raw donor JSON, prefill logs, stats, and terminal debris must not appear as
  assistant prose.
- Current donor clones are research assets, not automatic product code.
- License review is required before vendoring any code.
- AGPL/GPL/no-license code is study-only unless the owner explicitly accepts
  obligations or a clean-room rewrite is used.

## Current Recommendation

The most stable plan is:

```text
Chat = Swarm-first Swift native chat
Act  = Goose-powered native action surface
Work = OpenGUI-style multi-engine workbench
```

With engines/donors:

```text
Work engines:
  OpenCode
  Goose
  Codex
  Claude Code
  Pi / OMP
  Hermes

Work donors:
  OpenGUI for adapter shape
  OpenChamber for UX
  OpenWork for current fallback/cowork parity
  Paseo for orchestration
  OpenCowork for sandbox/browser/computer-use/document tools

Chat donors:
  Swarm primary
  SwiftedMind SwiftAgent secondary
  Foundation Lab for Apple FM workbench/evidence
  MCP Swift SDK for native MCP
  Agent! for app capability motifs

Act donors:
  Goose primary
  1amageek SwiftAgent for permission/sandbox/MCP/skills motifs after license check
  Agent! for macOS automation motifs
```

## 2026-06-25 Owner Correction - Goose Surface Full Clone

This section supersedes the earlier Act/Goose SwiftUI/process-bridge direction
for Goose surface work.

Continuation handoff for Claude:

- `docs/handoffs/GOOSE_SURFACE_CLAUDE_HANDOFF_2026_06_24.md`

The Goose owner directive is now:

- Work on Goose only.
- Treat `.research-clones/work/goose` as the real app substrate.
- Make a full Goose clone/fork/reskin, not a Swift shell, egui replacement,
  Tauri conversion, UniFFI-first spike, or backend-only adapter.
- Keep Goose's Electron/React desktop/frontend stack and recode/reskin the
  visible UI directly.
- Preserve Goose sessions, providers, MCP/extensions, ACP, recipes,
  permissions/tool approval, schedules, memory/config, API/server/desktop
  plumbing, and hidden/advanced surfaces unless explicitly proven unnecessary.
- Remove Goose donor branding and stock visual identity from the final surface.
- Translate OpenCode TUI minimalism into a flat, compact Epistemos GUI while
  keeping Goose behavior underneath.

### Goose Desktop Inventory

Source files inventoried:

- `.research-clones/work/goose/README.md`
- `.research-clones/work/goose/ui/desktop/README.md`
- `.research-clones/work/goose/ui/sdk/README.md`
- `.research-clones/work/goose/ui/desktop/package.json`
- `.research-clones/work/goose/ui/desktop/src/App.tsx`
- `.research-clones/work/goose/ui/desktop/src/hooks/useNavigationItems.ts`
- `.research-clones/work/goose/ui/desktop/src/components`
- `.research-clones/work/goose/ui/desktop/src/acp`
- `.research-clones/work/goose/ui/desktop/src/api`
- `.research-clones/work/goose/ui/desktop/src/theme`

Top-level routes and retained surfaces:

| Goose surface | Primary files | Capability to retain | Epistemos/OpenCode treatment | Status |
| --- | --- | --- | --- | --- |
| Launcher | `src/App.tsx`, `components/LauncherView.tsx` | App entry and launch flow | Flat launcher with Epistemos naming, no donor chrome | Reskinned and live verified |
| Hub / new chat | `src/App.tsx`, `components/Hub.tsx` | New session creation and entry prompts | Compact command-like start view | Reskinned and live verified |
| Pair / active session | `src/App.tsx`, `components/BaseChat.tsx`, `ChatSessionsContainer.tsx`, `ProgressiveMessageList.tsx`, `ChatInput.tsx` | Real session, send, stream, hidden active sessions, SSE continuity | Dense chat, minimal rails, compact model/tool state | Reskinned; send path preserved by code, credentials-backed send still needs owner run |
| Sidebar / recents | `components/Layout/AppLayout.tsx`, `NavigationPanel.tsx`, `hooks/useNavigationItems.ts` | Navigation, recent sessions, streaming session status | Tight sessions rail, mono labels, no rounded SaaS shell | Reskinned and live verified |
| Provider setup | `components/settings/providers/*`, `components/settings/models/*`, `components/onboarding/*`, `ModelAndProviderContext.tsx` | Provider credentials, model lists, model switching, onboarding | Compact provider/model picker and settings panels | Reskinned and live verified |
| MCP/extensions | `components/extensions/ExtensionsView.tsx`, `components/settings/extensions/*`, `built-in-extensions.json`, `components/bottom_menu/*` | Extension install/config/deeplinks/session extension selection | Tight extension tables/panels, preserve install/config flows | Reskinned and live verified |
| MCP apps | `components/apps/*`, `components/McpApps/*`, `components/MCPUIResourceRenderer.tsx`, `theme/theme-tokens.ts` | MCP app launching/rendering and host theme bridge | Flat app list and embedded app chrome using Epistemos tokens | Route live verified |
| ACP chat plumbing | `src/acp/*`, `hooks/useChatSession.ts`, `hooks/useAcpChatSession.ts` | ACP sessions, permissions, elicitations, prompt, diagnostics, schedules | Preserve behavior; only reskin surrounding UI | Inventoried |
| Recipes | `components/recipes/*`, `recipe/*`, `RecipeHeader.tsx`, `RecipeActivities.tsx`, `RecipeParamsModalContainer.tsx` | Create/edit/import/run recipes, parameters, sub-recipes, model/extension selectors | Minimal editor forms and activity blocks | Route live verified |
| Permissions/tool approval | `ToolCallConfirmation.tsx`, `ToolApprovalButtons.tsx`, `ToolCallWithResponse.tsx`, `components/settings/permission/*`, `acp/permissionRequests.ts` | Runtime approvals, permission rules/settings, tool request/response rendering | Minimal action-required panels with terse state labels | Reskinned; needs live approval event sample |
| Tool calls/results | `ToolCallWithResponse.tsx`, `ToolCallArguments.tsx`, `ToolCallStatusIndicator.tsx`, `components/icons/toolcalls/*` | Tool request/result/progress/log display, MCP UI resources | Compact terminal-like panels with readable arguments/results | Reskinned; needs live tool-call sample |
| Sessions/history/share | `components/sessions/*`, `sessions.ts`, `sharedSessions.ts`, `sessionLinks.ts` | Session history, import/export/share/deeplinks, shared sessions | Dense session list and transcript viewer | Route live verified |
| Settings/config | `components/settings/SettingsView.tsx`, `components/settings/app/*`, `components/settings/config/*`, `ConfigContext.tsx` | App settings, config file surface, external backend, updates, telemetry | Tabbed compact settings, no stock card-heavy styling | Route live verified |
| Schedules | `components/schedule/*`, `acp/schedules.ts` | Schedule list/detail/create/edit, cron picker | Compact schedule grid/detail | Route live verified |
| Skills | `components/skills/SkillsView.tsx` | Skill/library surface | Minimal list/editor treatment | Reskinned and live verified |
| Chat settings | `components/settings/chat/*`, `components/settings/mode/*`, `components/settings/response_styles/*`, `components/settings/security/*` | mode, response style, conversation limits, tool/mode security, hints, spellcheck | Compact toggles/selectors | Inventoried |
| Local inference | `components/settings/localInference/*`, `hooks/useAudioRecorder.ts` | Local model settings/search and related feature flag | Dense model manager with status-first layout | Inventoried |
| Dictation | `components/settings/dictation/*`, `hooks/useAudioRecorder.ts` | Voice provider, microphone, local dictation model management | Compact input/device settings | Inventoried |
| Auth/gateway/sharing | `components/settings/auth/*`, `components/settings/gateways/*`, `components/settings/sessions/*` | Auth state, Hugging Face sign-in, gateway/tunnel, session sharing | Flat settings sections | Inventoried |
| Error/loading/toasts | `ErrorBoundary.tsx`, `LoadingGoose.tsx`, `toasts.tsx`, `GroupedExtensionLoadingToast.tsx`, `AnnouncementModal.tsx`, `TelemetryConsentPrompt.tsx` | Fatal/load/extension/progress/consent/update notifications | Replace donor animation/branding with Epistemos status language | Inventoried |
| Electron/server plumbing | `main.ts`, `preload.ts`, `goosed.ts`, `serverHealth.ts`, `ipc`, `api/*` | Desktop IPC, goosed lifecycle, API client, windows, notifications | Preserve plumbing; only brand/visual pass where visible | Inventoried |

### First Implementation Slice

Start with the real main Goose chat/session surface:

1. flatten `AppLayout` and `NavigationPanel`;
2. remove visible donor logo/chrome from `BaseChat`;
3. reskin `ChatInputCard`, user/assistant messages, tool calls, and approval
   panels into compact Epistemos/OpenCode style;
4. preserve `ChatInput`, `useChatSession`, ACP/SSE, model/provider selector,
   extension selector, context/cost indicators, dictation, queued messages, and
   session continuity;
5. verify with Goose desktop typecheck/build/dev command and screenshots when
   the local desktop surface can run.

### 2026-06-25 Goose Reskin Evidence

Implementation status:

- The Goose desktop fork now keeps the Electron/React stack and reskins the
  visible app shell directly.
- Root app chrome is scoped with `goose-epistemos` theme tokens in
  `ui/desktop/src/styles/main.css`.
- Main hub/chat, navigation rail, messages, input card, tool calls,
  permissions, onboarding/provider setup, settings, sessions/history, recipes,
  schedules, extensions/MCP, apps, skills, loading/error/telemetry, and shared
  UI primitives have been flattened toward the Epistemos/OpenCode-minimal
  target.
- Visible app/package naming was changed to Epistemos in desktop metadata,
  menu/window title paths, updater defaults, notifications, and HTML title.
  Compatibility protocol/config names are preserved where changing them would
  break existing Goose behavior.
- Legacy visible logo/splash assets were removed from the desktop UI export
  path after replacement with Epistemos status marks.

Landing/launcher update:

- `ui/desktop/src/components/LauncherView.tsx` now renders a compact
  three-toggle landing shell for Chat, Act, and Work.
- The Act toggle is wired to the real Goose-derived Act surface.
- Selecting Open Act performs a blur transition and opens Act in a dedicated
  Electron window through the existing `createChatWindow` IPC path.
- `ui/desktop/src/main.ts` launcher bounds were expanded from a prompt strip to
  a 760x340 transition window.
- `ui/desktop/src/preload.ts` and `ui/desktop/src/main.ts` now support
  `forceNewWindow` and `initialMessageNoAutoSubmit` for explicit transition
  launches.
- Button launches open the Act window without auto-submitting text. Enter in
  the launcher prompt can carry text as a draft/no-auto-submit handoff.

Verification:

- `source ./bin/activate-hermit && pnpm --dir ui/desktop run typecheck` passed.
- `source ./bin/activate-hermit && pnpm --dir ui/desktop run i18n:extract`
  passed and recompiled messages after launcher copy changes.
- `source ./bin/activate-hermit && pnpm --dir ui/desktop run start-gui` launches
  Electron from the updated main/preload bundles.
- Live Electron verification:
  - window title is `Epistemos`;
  - hub renders the reskinned dense command surface;
  - quick launcher opens with Chat / Act / Work toggles;
  - Act launch closes the launcher and opens a separate Act window with no
    prompt submitted.
- Screenshot evidence:
  - `ui/desktop/epistemos-launcher.png`
  - `ui/desktop/epistemos-launcher-transition.png`
  - `ui/desktop/epistemos-launcher-final.png`
  - `ui/desktop/epistemos-act-window-final.png`

2026-06-25 continuation evidence:

- Rebuilt and copied refreshed debug binaries into the desktop bundle:
  `source ./bin/activate-hermit && cargo build -p goose-server --bin goosed -p goose-cli --bin goose && just copy-binary debug`.
- Validation passed after backend/provider metadata changes:
  - `source ./bin/activate-hermit && cargo check -p goose`
  - `source ./bin/activate-hermit && pnpm --dir ui/desktop run typecheck`
- Relaunched the real Electron/React desktop with:
  `source ./bin/activate-hermit && pnpm --dir ui/desktop run start-gui`.
  The active renderer is `http://localhost:5173/`; the refreshed `goosed`
  process was launched from `ui/desktop/src/bin/goosed`.
- Live route verification after the refreshed backend:
  - Main hub/new chat: compact rail, dense input card, model/provider/directory,
    context, cost, extension, attachment, and send controls still render.
  - Provider/model settings: `Settings -> Models -> Configure providers`
    opens the real provider catalog with compact cards and configured provider
    status marks.
  - Provider metadata cleanup: ACP provider descriptions for Amp, Claude Code,
    Codex CLI, GitHub Copilot CLI, and Pi were neutralized from donor-language
    copy while keeping provider IDs, config keys, and adapter behavior intact.
  - Extensions/MCP: route verified against the refreshed backend; bundled
    extension descriptions now use Epistemos-neutral copy while install/config
    controls remain present.
  - Skills: route verified; the compatibility builtin
    `goose-doc-guide` remains as the backend/source ID, but the visible surface
    remaps it to `epistemos-act-guide` with Epistemos-neutral description text.
  - Apps: navigation entry is always visible again so MCP app surfaces are not
    hidden by extension-gating.
  - Recipes, Scheduler, Session History, Local Inference, and Settings tabs load
    from the reskinned shell with their retained real controls.
- Additional screenshot evidence:
  - `ui/desktop/epistemos-extensions-final.png`
  - `ui/desktop/epistemos-providers-final.png`
- Remaining `goose` source hits are compatibility identifiers, protocol/config
  contracts, tests/snapshots, or backend package/crate names. Do not rename them
  blindly; visible UI should keep translating those at render boundaries.
- Follow-up visible-copy scan narrowed to UI `defaultMessage` text. It is clean
  except the intentional `.goose/skills/` compatibility path shown in the Skills
  empty state. Localized external-backend helper strings were updated to say
  "compatible backend" instead of naming the backend binary directly.
- HMR recovered after the i18n reload; the live provider catalog still rendered
  under `Epistemos` and showed neutral ACP provider copy for Amp, Claude Code,
  Codex CLI, GitHub Copilot CLI, and Pi.

Known limitations:

- Send/stream behavior is preserved by code path and was observed in the live
  app, but a deliberate credentials-backed send test should be run by the owner
  before treating provider billing/network behavior as fully verified.
- Chat and Work toggles are visible as landing handoff targets, but only Act is
  wired by this Goose-owned pass. Chat/Work owners should wire their native
  routes from the retained Epistemos landing shell.

### 2026-06-25 Runtime Token Hardening Evidence

Continuation after the 11-unit visual pass found one remaining source-level
contradiction: `ui/desktop/src/theme/theme-tokens.ts`, the runtime semantic
token source and MCP host-style bridge, still exported donor defaults even though
`main.css` visually overrode them.

Files changed in this unit:

- `.research-clones/work/goose/ui/desktop/src/theme/theme-tokens.ts`
- `.research-clones/work/goose/ui/desktop/src/styles/main.css`
- `docs/handoffs/GOOSE_SURFACE_CLAUDE_HANDOFF_2026_06_24.md`
- `docs/handoffs/CHAT_ACT_WORK_TRI_SURFACE_ENGINE_PLAN_2026_06_24.md`

What changed:

- Runtime `--font-sans` now uses local system fonts instead of `'Cash Sans'`.
- MCP host `css.fonts` no longer injects remote `cash-f.squarecdn.com`
  `@font-face` rules into sandboxed app surfaces.
- Runtime radius tokens are `0`; runtime shadow tokens are `none`.
- Runtime light/dark semantic color tokens now match the Epistemos
  cool-neutral / Platinum-Violet surface, including status tokens.
- CSS legacy `--shadow-default` values are `none`.
- Search-current highlighting no longer uses `box-shadow`.
- Tailwind `drop-shadow-*` utilities are neutralized through
  `[class*='drop-shadow'] { filter: none !important; }`, without disabling the
  launcher blur transition.

Verification:

- `source ./bin/activate-hermit && pnpm --dir ui/desktop exec prettier --write src/theme/theme-tokens.ts src/styles/main.css`
- `source ./bin/activate-hermit && pnpm --dir ui/desktop run typecheck` passed.
- `source ./bin/activate-hermit && pnpm --dir ui/desktop exec vite build --config vite.renderer.config.mts` passed.
- Source + compiled output scan for `squarecdn|Cash Sans|cashsans` was clean.
- Compiled bundle confirmed the new token maps and local bundled Epistemos pixel
  font assets.
- Generated `ui/desktop/dist/` was removed after verification.

No new live Electron screenshot was captured in this unit. The next visual QA
pass should run the desktop and sample MCP app embeds/tool approvals against
these runtime host tokens.

### 2026-06-25 Tailwind Primitive Palette Evidence

Continuation after runtime token hardening found one more build-time visual leak:
Tailwind primitive color families in `ui/desktop/src/styles/main.css` still
allowed default/donor utility colors to compile when components used hardcoded
classes such as `text-gray-500`, `dark:bg-gray-900`, `bg-slate-900`,
`text-purple-700`, `text-emerald-700`, and status utilities.

Files changed in this unit:

- `.research-clones/work/goose/ui/desktop/src/styles/main.css`
- `docs/handoffs/GOOSE_SURFACE_CLAUDE_HANDOFF_2026_06_24.md`
- `docs/handoffs/CHAT_ACT_WORK_TRI_SURFACE_ENGINE_PLAN_2026_06_24.md`

What changed:

- Removed unused donor `--color-block-teal` and `--color-block-orange`
  primitives.
- Replaced primitive ramps for neutral, gray, slate, red, blue, cyan, green,
  emerald, yellow, amber, orange, purple, indigo, and pink with
  Epistemos-aligned cool-neutral, Platinum-Violet, code-teal, and semantic status
  values.
- Kept backend/protocol compatibility intact by not renaming ACP method names,
  provider IDs, package names, config keys, or wire-format identifiers.

Verification:

- `source ./bin/activate-hermit && pnpm --dir ui/desktop exec prettier --write src/styles/main.css`
- `source ./bin/activate-hermit && pnpm --dir ui/desktop run typecheck` passed.
- `source ./bin/activate-hermit && pnpm --dir ui/desktop exec vite build --config vite.renderer.config.mts` passed.
- Source + compiled output scan for `squarecdn|Cash Sans|cashsans` was clean.
- Source + compiled output scan found no gray/slate/purple/indigo/emerald/cyan/pink
  primitive CSS variables compiling from Tailwind default `oklch(...)` ramps.
- Generated `ui/desktop/dist/` was removed after verification.

No new live Electron screenshot was captured in this unit. The next pass should
continue visible-branding and endpoint/config audits while preserving compatibility
identifiers that keep the Goose-derived backend and ACP bridge functional.

### 2026-06-25 Epistemos Tool Surface / Compatibility Copy Evidence

Continuation after the visual and palette hardening addressed a functional
integration regression: the model could tell the user it did not have
"Epistemos-specific tools" even when generic, MCP, extension, or
compatibility-prefixed tools were available. The fix teaches the Goose-derived
Act agent to treat connected tools as Epistemos app capabilities, while keeping
wire-compatible names intact.

Files changed in this unit:

- `.research-clones/work/goose/crates/goose/src/prompts/system.md`
- `.research-clones/work/goose/crates/goose/src/prompts/subagent_system.md`
- `.research-clones/work/goose/crates/goose/src/prompts/apps_create.md`
- `.research-clones/work/goose/crates/goose/src/prompts/apps_iterate.md`
- `.research-clones/work/goose/crates/goose/src/prompts/tiny_model_system.md`
- `.research-clones/work/goose/crates/goose/src/agents/moim.rs`
- `.research-clones/work/goose/crates/goose/src/agents/prompt_manager.rs`
- `.research-clones/work/goose/crates/goose/src/agents/mcp_client.rs`
- `.research-clones/work/goose/crates/goose/src/agents/platform_extensions/apps.rs`
- `.research-clones/work/goose/crates/goose/src/agents/platform_extensions/ext_manager.rs`
- `.research-clones/work/goose/crates/goose/src/providers/provider_test.rs`
- `.research-clones/work/goose/crates/goose/src/agents/snapshots/goose__agents__prompt_manager__tests__basic.snap`
- `.research-clones/work/goose/crates/goose/src/agents/snapshots/goose__agents__prompt_manager__tests__one_extension.snap`
- `.research-clones/work/goose/crates/goose/src/agents/snapshots/goose__agents__prompt_manager__tests__typical_setup.snap`
- `.research-clones/work/goose/ui/desktop/src/components/settings/chat/GoosehintsModal.tsx`
- `.research-clones/work/goose/ui/desktop/src/components/settings/chat/GoosehintsSection.tsx`
- `.research-clones/work/goose/ui/desktop/src/components/recipes/ImportRecipeForm.tsx`
- `.research-clones/work/goose/ui/desktop/src/components/sessions/SessionListView.tsx`
- `.research-clones/work/goose/ui/desktop/src/components/settings/app/ExternalBackendSection.tsx`
- `.research-clones/work/goose/ui/desktop/src/components/settings/app/UpdateSection.tsx`
- `.research-clones/work/goose/ui/desktop/src/components/settings/extensions/deeplink.ts`
- `.research-clones/work/goose/ui/desktop/src/recipe/index.ts`
- `.research-clones/work/goose/ui/desktop/src/sessionLinks.ts`
- `.research-clones/work/goose/ui/desktop/src/components/ui/Diagnostics.tsx`
- `.research-clones/work/goose/ui/desktop/src/i18n/messages/*.json`
- `.research-clones/work/goose/ui/desktop/src/i18n/compiled/*.json`
- `docs/handoffs/GOOSE_SURFACE_CLAUDE_HANDOFF_2026_06_24.md`
- `docs/handoffs/CHAT_ACT_WORK_TRI_SURFACE_ENGINE_PLAN_2026_06_24.md`

What changed:

- The system prompt identity is now Epistemos inside the Epistemos app.
- Active tools, MCP resources, app surfaces, extension tools, and project context
  are described as Epistemos capabilities even when internal names are generic
  or compatibility-prefixed.
- The no-extension fallback now distinguishes "this session has no active
  connected tools" from "Epistemos lacks tools."
- Subagent, app-create/app-iterate, tiny-model, MCP sampling, MOIM turn-context,
  provider-test, and platform-extension prompts/tool descriptions were rebranded
  to Epistemos runtime/app language.
- Desktop visible copy now treats `.goosehints`, `goose://`, `.goose/skills`,
  and `GOOSE_*` as compatibility surfaces rather than primary brand names.
- Non-English locale messages were normalized for the affected keys and compiled
  so stale translated Goose wording cannot return at runtime.
- Compatibility identifiers were intentionally preserved:
  `goose://`, `.goosehints`, `.goose/skills`, `GOOSE_*`, ACP `client.goose`
  calls, provider IDs, crate/package names, and wire-format identifiers remain
  unchanged.

Verification:

- `source ./bin/activate-hermit && cargo fmt --package goose` passed.
- `INSTA_UPDATE=always cargo test -p goose agents::prompt_manager -- --nocapture`
  updated prompt snapshots. The broad filter still reaches an existing
  `test_all_platform_extensions` sqlx feature panic unrelated to the prompt
  text; the snapshot-bearing tests updated and passed.
- Focused prompt snapshot tests passed individually:
  `test_basic`, `test_one_extension`, and `test_typical_setup`.
- `source ./bin/activate-hermit && cargo check -p goose` passed.
- `source ../../bin/activate-hermit && pnpm run i18n:check` passed for all
  shipped locales (`1585 messages`).
- `source ../../bin/activate-hermit && pnpm run i18n:compile` passed.
- `source ../../bin/activate-hermit && pnpm run typecheck` passed.
- `source ../../bin/activate-hermit && pnpm exec vite build --config vite.renderer.config.mts`
  passed with existing Vite warnings.
- Catalog/source scans show remaining `goose://`, `.goosehints`,
  `.goose/skills`, and `GOOSE_*` strings only as compatibility literals.
- Targeted donor/regression phrase scans are clean except the deliberate prompt
  instruction saying not to claim the agent lacks an Epistemos-specific tool.
- Generated `ui/desktop/dist/` was removed after verification.

No new live Electron screenshot was captured in this unit. The next pass should
continue endpoint/provider copy audits, visual density checks, and live Act route
verification from the Epistemos app shell.

### 2026-06-25 Provider Attribution / Endpoint Identity Evidence

Continuation after the tool-surface integration pass audited external endpoint
attribution and runtime telemetry. The goal was to remove old clone identity from
safe attribution fields without renaming compatibility contracts that keep the
Goose-derived backend, ACP bridge, OAuth clients, and config paths working.

Files changed in this unit:

- `.research-clones/work/goose/crates/goose/src/providers/openrouter.rs`
- `.research-clones/work/goose/crates/goose/src/providers/tetrate.rs`
- `.research-clones/work/goose/crates/goose/src/providers/declarative/orcarouter.json`
- `.research-clones/work/goose/crates/goose/src/providers/declarative/vercel_ai_gateway.json`
- `.research-clones/work/goose/crates/goose/src/providers/snowflake.rs`
- `.research-clones/work/goose/crates/goose/src/providers/nanogpt.rs`
- `.research-clones/work/goose/crates/goose/src/config/signup_nanogpt/mod.rs`
- `.research-clones/work/goose/crates/goose/src/config/signup_tetrate/mod.rs`
- `.research-clones/work/goose/crates/goose/src/providers/chatgpt_codex.rs`
- `.research-clones/work/goose/crates/goose/src/providers/xai_oauth.rs`
- `.research-clones/work/goose/crates/goose/src/oauth/mod.rs`
- `.research-clones/work/goose/crates/goose/src/providers/huggingface_auth.rs`
- `.research-clones/work/goose/crates/goose/src/providers/local_inference/hf_models.rs`
- `.research-clones/work/goose/crates/goose/src/providers/formats/google.rs`
- `.research-clones/work/goose/crates/goose/src/agents/extension_manager.rs`
- `.research-clones/work/goose/crates/goose/src/agents/extension_malware_check.rs`
- `.research-clones/work/goose/crates/goose/src/agents/platform_extensions/developer/image.rs`
- `.research-clones/work/goose/crates/goose/src/agents/agent.rs`
- `.research-clones/work/goose/crates/goose/src/otel/otlp.rs`
- `.research-clones/work/goose/crates/goose/src/bin/build_canonical_models.rs`
- `.research-clones/work/goose/crates/goose/src/config/base.rs`
- `.research-clones/work/goose/crates/goose/src/config/declarative_providers.rs`
- `.research-clones/work/goose/crates/goose/src/skills/builtins/goose_doc_guide.md`
- `.research-clones/work/goose/crates/goose/src/agents/snapshots/goose__agents__prompt_manager__tests__all_platform_extensions.snap`
- `.research-clones/work/goose/crates/goose/tests/acp_fixtures/server.rs`
- `docs/handoffs/GOOSE_SURFACE_CLAUDE_HANDOFF_2026_06_24.md`
- `docs/handoffs/CHAT_ACT_WORK_TRI_SURFACE_ENGINE_PLAN_2026_06_24.md`

What changed:

- Provider attribution headers for OpenRouter, Tetrate, OrcaRouter, and Vercel
  AI Gateway now identify the app as Epistemos.
- Snowflake, NanoGPT, local Hugging Face model queries, extension HTTP clients,
  OSV checks, image fetching, and the canonical-model builder use Epistemos
  client/User-Agent strings.
- ChatGPT Codex `originator`, xAI `referrer`, generic MCP OAuth display name,
  and NanoGPT signup `client_name` now use Epistemos.
- Google-format action-required prompt text now names Epistemos.
- OTel defaults use `service.name = epistemos`, `service.namespace = epistemos`,
  and an `epistemos` tracer.
- The built-in compatibility docs skill now describes itself as an Epistemos Act
  compatibility-docs guide, while preserving exact legacy literals when a config
  key, URL, path, command, or protocol requires them.

Compatibility intentionally preserved:

- `goose-docs.ai` OAuth client metadata URLs stayed in place because changing
  them would require replacement registered OAuth clients.
- Keyring service, config paths, `.goose` directories, `GOOSE_*`, ACP metadata
  key `goose`, Docker `goose mcp`, provider IDs, crate/package names, and shell
  compatibility env vars were not renamed.

Verification:

- `source ./bin/activate-hermit && cargo fmt --package goose` passed.
- Focused tests passed for Vercel declarative-provider header expectations and
  xAI OAuth URL parameters.
- Attempted OTel resource test filters matched zero tests under this build
  configuration, so they were not counted as assertion coverage.
- `source ./bin/activate-hermit && cargo check -p goose` passed.
- Targeted provider/endpoint regression scan returned no hits for old
  attribution strings such as `goose docs`, `goose would like`,
  `goose-ai-agent`, `originator=goose`, `referrer=goose`,
  `X-Title.*goose`, `User-Agent.*goose`, or `x-client.*goose`.
- `git diff --check` passed in both the clone and parent docs repo.

No new live Electron screenshot was captured in this unit. Continue with live
Act route verification and visual density/theme audits; do not rename the
remaining compatibility IDs without an explicit aliasing/migration plan.

### 2026-06-25 Live Electron Surface Evidence

Continuation after source/build verification launched Electron through Playwright
CDP with isolated temporary `GOOSE_PATH_ROOT` directories. The process group was
killed after each run and verified not to leave Electron/goosed processes behind.

Evidence:

- `.research-clones/work/goose/ui/desktop/epistemos-live-launcher-2026-06-25.png`
  captures the no-provider onboarding/setup state.
- `.research-clones/work/goose/ui/desktop/epistemos-live-configured-2026-06-25.png`
  captures the configured Act chat shell using dummy isolated config.

Runtime findings:

- Setup state title/text says `Epistemos agent setup`; body text did not contain
  visible `Goose`/`goose`.
- Configured Act shell reached the main chat surface with
  `data-testid="chat-input"` present; body text did not contain visible
  `Goose`/`goose`.
- Runtime `.goose-epistemos` tokens in both runs:
  `--color-primary #7b68ee`,
  `--color-background-primary #16161b`,
  `--border-radius-md 0`,
  `--shadow-default none`.
- Visual inspection found no obvious text overlap, clipped controls, rounded
  donor cards, or shadow-heavy surfaces in the captured desktop viewport.
- The configured run used dummy `GOOSE_PROVIDER: openai`, `GOOSE_MODEL: gpt-4o`,
  telemetry off, and a dummy `OPENAI_API_KEY`; it did not send a model request.

Known dev-mode log noise:

- Electron extension deprecation warnings.
- Node package sourcemap warnings.
- Transient SSL handshake warnings.
- Auto-updater reports dev/unpackaged mode.

These did not prevent backend startup, React readiness, or rendering. No code
changed in this live-verification unit.

### 2026-06-25 Desktop Package Documentation Identity Evidence

Continuation after live Electron verification audited desktop package identity
files: `package.json`, Forge config, HTML title, Linux desktop entries, README,
public assets, and announcements.

What changed:

- `.research-clones/work/goose/ui/desktop/README.md` now documents the app as
  Epistemos Desktop App.
- The README explicitly identifies `goosed`, `GOOSE_*`, `goose-server`,
  package names, and `goose://` as compatibility contracts rather than primary
  branding.
- Donor clone/setup wording and donor bundle output examples were removed from
  the desktop README.

Verification:

- Package identity scan for
  `Goose|goose|Block|Agentic|AAIF|Cash|squarecdn|goose-docs` now returns only
  compatibility/package hits: `goose-app`, `@aaif/goose-sdk`, `goosed`,
  `goose-server`, and `goose://` scheme registration.
- `git diff --check` passed in both the clone and parent docs repo.

### 2026-06-25 Research Clone Inventory Evidence

Continuation checked the parent `.research-clones` tree so the tri-surface plan
tracks the real clone set being integrated.

Inventory:

- 23 top-level research clones under `.research-clones/{agents,swift-act,work}`.
- Work clones present:
  `goose`, `opencode`, `opengui`, `openwork`, `open-cowork`, `openchamber`,
  `opencode-mini-session`, and `paseo`.
- Size check:
  - `work/goose`: `34G` including target/build artifacts.
  - `work/opencode`: `400M`.
  - `work/opengui`: `1.1G`.
  - `work/openwork`: `321M`.
  - `work/open-cowork`: `98M`.
  - `work/openchamber`: `100M`.
  - `work/opencode-mini-session`: `7.7M`.
- Goose-derived Act/Work clone entry points verified:
  `.git`, `Cargo.toml`, `ui/desktop/package.json`, and executable
  `bin/activate-hermit`.
- Epistemos evidence assets verified in the clone:
  bundled display fonts and the live setup/configured Electron screenshots.

No code changed in this inventory unit.
