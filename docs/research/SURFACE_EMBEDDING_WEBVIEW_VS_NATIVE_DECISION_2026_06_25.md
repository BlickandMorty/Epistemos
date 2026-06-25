# Epistemos Surface Fusion — DEFINITIVE Plan, Directives & Agent Prompts

**Status:** ✅ DEFINITIVE / LOCKED 2026-06-25. Single source of truth. Zero-contradiction. Research loop CLOSED.
**Question source:** `/Users/jojo/.codex/attachments/ab4fbb0d-28e8-4e34-911c-2c9332d8c3df/goal-objective.md`
**Companion (implementation ladder, reused except where §3/§5 here override it):** `docs/handoffs/EPISTEMOS_SURFACE_HOST_WEBVIEW_FEDERATION_RESEARCH_2026_06_25.md`

> Discipline: this is the ONE doc. If future research changes a fact, **edit it here in place** and add a line to §13. Never fork a second contradicting plan.

---

## §0 TL;DR (the whole decision in 7 lines)
1. **One native shell** (`EpistemosSurfaceHost`) owns Landing, the Chat/Act/Work picker, context, sessions, permissions, tools, theme, recents. **Landing = EXACTLY 3 surfaces: Chat=Swift Agent, Act=Goose, Work=OpenGUI.** The OpenCode TUI is NOT on the landing — it moves to Settings only (see §0.1).
2. **Chat = AgentClone** — native Swift, deepest integration.
3. **Act = Goose** — Goose's **web UI in a macOS 26 `WebView`/`WebPage`**, with the agent driven over **ACP-over-WebSocket** to a supervised `goose serve`/`goosed`; a **narrow** boot/affordance shim (NOT a full Electron-IPC emulation). The **real Goose Electron app stays as the capability baseline/fallback**.
4. **Work = OpenGUI** (the multi-engine **harness runtime** — OpenCode is just *one hidden engine* under it, NOT the brand) — native Work chrome over the OpenGUI runtime **and** the OpenGUI/OpenWork web SPA in `WebView`/`WebPage`. Foreground = **"Epistemos Work"**, never "OpenCode". See §0.1.
5. **"Both WebViews at full capability" = YES** (the OpenGUI Work SPA + the Goose UI), and **ACP is fused in, not chosen instead** — because Goose's WebView already talks ACP.
6. **API = `WebView`/`WebPage`** (the app targets macOS 26.0, so no back-deploy tax; this is the most-native, deep-Apple-integration path — your instinct was right). `WKWebView` only where a specific legacy surface needs it (e.g. Epdoc).
7. **Everything that spawns a process (Goose, OpenCode/Bun) is Pro/Developer-ID; the MAS build degrades honestly** (no hidden sidecar).
8. **Licensing is NOT a constraint** (owner) — vendor + fuse every donor's full source freely; never omit/gate/caveat for license reasons, and don't surface license language. Separate from the MAS subprocess *technical* limit. The full Swift Agent donor set (all 9, already vendored) is §1.1.

---

## §0.1 NAMING POLICY (HARDENED — read this before touching Work)

`[VERIFIED-CODE]` `WorkOpenGUISupervisor.swift:4-5`: *"OpenGUI is the harness/bridge thing… which harnesses MULTIPLE engines (OpenCode, Claude Code, Codex, Pi/Grok Build)."* `WorkEnginesPanelView.swift:18-22` picker = OpenCode, Codex, Claude Code, Pi/OMP (runnable) + Goose (not-yet).

- **OpenGUI = the Work runtime/harness** that hosts many engines. This is the real Work engine and the thing to surface.
- **OpenCode = ONE engine under OpenGUI** (currently the default). It is **not** the Work brand. The bare-`opencode serve` path (`WorkRuntimeSupervisor`) is the **placeholder**; the target is the full OpenGUI multi-harness surface (`WorkOpenGUISupervisor`) with OpenCode as one **hidden-named** engine.

**Three naming tiers — enforce strictly (this is the "hardening" asked for):**
| Tier | Rule | Examples |
|---|---|---|
| **Foreground (user sees)** | Say **"Epistemos Work"**. NEVER "OpenCode", NEVER "OpenGUI" — on landing, surface title, composer, status. | "Epistemos Work", "Ask Epistemos Work…" |
| **Engine picker / diagnostics** | Engine identities are allowed as **selectable / debug** labels only — not as the surface brand. "OpenGUI" may name the runtime in diagnostics. | picker rows: OpenCode · Claude Code · Codex · Pi · Goose |
| **Backend contracts (NEVER rename — renaming breaks execution)** | Keep the real donor/runtime names under the hood. | `opencode.json`, `OPENGUI_OPENCODE_PORT`, `OPENWORK_OPENCODE_BIN`, harness id `"opencode"`, env/protocol/storage keys |

**Verified current leak (located in code):** `RootView.swift:2697-2701` mounts **`WorkTerminalHostView`** (the OpenCode TUI terminal, `WorkTerminalView.swift:120`) for the landing `.work` mode. The REAL OpenGUI Work surface (`WorkEngineSurfaceView` via `WorkEngineSurfaceWindowController`) only opens from `EpistemosApp.swift:1523` (⌘4/menu) — NOT the landing. So today the landing's "Work" literally *is* the OpenCode TUI. That is the confusion to remove.

### The LANDING CONTRACT (clean — exactly 3 surfaces, owner-locked 2026-06-25)
| Mode | Landing surface = | Engine |
|---|---|---|
| **Chat** | Swift Agent (`AgentClone.ContentView()`) | native Swift |
| **Act** | Goose | Goose (web UI + ACP) |
| **Work** | **OpenGUI** (`WorkEngineSurfaceView`, multi-harness) | OpenGUI runtime (OpenCode = default hidden engine) |

- The landing shows **only these three** — no "OpenCode" surface, no bare TUI, no fourth thing. Clean slate.
- **OpenCode's two roles, split (THIS is the key distinction):**
  1. **OpenCode the ENGINE** → keeps working as OpenGUI's default harness. **Do NOT break or delete it.**
  2. **OpenCode the standalone TUI VIEW** (`WorkTerminalHostView`) → **MOVE to Settings only.** It is *already* mounted in Settings (`WorkCloneSettingsView.swift:34`); just **remove it from the landing** (change `RootView.swift:2697-2701` to mount `WorkEngineSurfaceView`). **Do NOT delete** `WorkTerminalHostView`/`WorkTerminalView.swift` — it stays, reachable via Settings.
- **Mode-name hazard (this is what confuses agents):** `WorkspaceModeKind` = the landing surfaces (`.chat/.act/.work`). `CoworkChatMode` (`CoworkChatMode.swift`) = a SEPARATE in-Chat toggle (`.chat` single-turn vs `.act` agentic). They reuse the words "chat"/"act" but are DIFFERENT enums — never conflate landing `WorkspaceModeKind.act` (the Goose surface) with `CoworkChatMode.act` (an agentic toggle inside Chat).
- *(Goose also appears in OpenGUI's engine picker as a not-yet-runnable harness — SEPARATE from Act=Goose. Act=Goose is its own landing surface; the OpenGUI "goose" harness stays deferred. Do not conflate.)*

---

## §1 The Fusion Target (the answer)

```
EpistemosSurfaceHost  (native SwiftUI shell — owns identity, not engines)
├─ Landing / Home  ·  Chat|Act|Work picker  ·  shared recents/sessions/permissions/tools/theme/context
│
├─ CHAT  → AgentClone (LocalPackages/AgentClone, native Swift)        … deepest native surface
├─ ACT   → Goose UI in WebView/WebPage  ⟷  ACP/WebSocket → goose serve … web UI + ACP brain + narrow shim
│            └─ fallback/baseline: REAL Goose Electron app (zero shim, 100% capability)
└─ WORK  → native "Epistemos Work" chrome ⟷ OpenGUI harness (NDJSON)   … strongest, already proven
             ├─ OpenGUI hosts engines: OpenCode(default,hidden-name)/Codex/Claude Code/Pi
             └─ + OpenGUI/OpenWork web SPA in WebView/WebPage (first-class, not just a Settings preview)

Shared contracts (one vocabulary, owned by Epistemos):
  window.epistemos bridge · epistemos.context.snapshot · permission/tool approval ·
  session/recents registry · theme tokens · health/witness rows · ACP client
```

Capability is preserved by default; donor **product identity** is not. Epistemos owns the visible scene + the contracts; donors keep their runtime spine (ACP, sidecar, session stores, MCP, recipes). This is the "Scene-Safe" rule: replace the scene, not the state machine.

---

## §1.1 Swift Agent (Chat) — the no-compromise donor fusion set

Chat is NOT "AgentClone with a skin" — it is the FULL fusion of the entire researched Swift donor set into Epistemos-owned code. **All 9 donors are ALREADY vendored locally** (verified 2026-06-25); keep provenance, fuse the BEST ideas. AgentClone stays the visible foundation, but the product must feel like Epistemos.

| # | Donor | Vendored at | Role to fuse |
|---|---|---|---|
| 1 | AgentClone / macos26 Agent | `LocalPackages/AgentClone` + `.research-clones/swift-act/agent-macos26` | visible native agent foundation |
| 2 | Swarm | `LocalPackages/Swarm` + `.research-clones/swift-act/swarm` | Swift runtime/orchestration/workflow substrate |
| 3 | SwiftedMind SwiftAgent | `.research-clones/swift-act/swiftagent-swiftedmind` | streaming/session/tool ergonomics |
| 4 | 1amageek SwiftAgent | `.research-clones/swift-act/swiftagent-1amageek` | permissions, sandbox, MCP, skills, Foundation Models motifs |
| 5 | MCP Swift SDK | `.research-clones/swift-act/mcp-swift-sdk` | native MCP substrate (tools/resources/prompts/progress/cancel/auth) |
| 6 | AgentSDK-Swift | `.research-clones/swift-act/agentsdk-swift` | typed agents, tools, guardrails, handoffs |
| 7 | AgentKit | `.research-clones/swift-act/agentkit` | retry/window/MCP ergonomics |
| 8 | SwiftAIAgent | `.research-clones/swift-act/swiftaia-agent` | workflow/model-output/tool-call motifs |
| 9 | Foundation Models Framework Example | `.research-clones/swift-act/foundation-models-framework-example` (+ `LocalPackages/LocalLLMClient/.../FoundationModels`) | Apple-native model UX, local/private generation, structured output, tool use |

**No donor is omitted because it is inconvenient.** Vendor/preserve the full useful source, keep provenance, fuse the BEST ideas into Epistemos-owned code. Full directive = §9-A. (Also present: `LocalPackages/EpistemosChatDonorContracts` test package; `.research-clones/agents` additional donor set.)

> **LICENSING IS NOT A CONSTRAINT (owner directive).** Licensing is never a consideration in this fusion — Swift donors, Goose, OpenGUI, or anything else. Vendor + fuse every donor's full source freely; never omit/gate/thin/caveat for license reasons, and do not surface license language in product or plan. This is distinct from the MAS App-Sandbox **technical** limit on spawning subprocesses (a runtime fact, not licensing).

## §2 The fusion insight — why dual-WebView AND ACP are the SAME plan (not a fork)

The apparent fight ("dual-WebView" vs "ACP-native") dissolves on one confirmed fact:

> **Goose's own desktop renderer already drives the agent over ACP-over-WebSocket**, not Electron IPC. `ui/desktop/src/main.ts:804` `buildAcpWebSocketUrl(baseUrl, token)` → `…/acp?token=`; `USE_ACP_CHAT` gates `BaseChat.tsx`, `ChatInput.tsx`, `ToolApprovalButtons.tsx`, `sessions.ts`. `[VERIFIED-CLONE]`

So when we host Goose's **web UI in `WebView`/`WebPage`**, the heavy, capability-bearing traffic (sessions, streaming, thinking, tool calls, permissions, elicitation, MCP, recipes, scheduler) rides **ACP — a stable, versioned, documented wire protocol** (`agent-client-protocol 0.11` / `-schema 0.12`, in the clone's `Cargo.lock`). The only thing the WebView shim must satisfy is **boot + OS affordances** (`getGoosedHostPort`, `getSecretKey`, `getAcpUrl`, settings, dialogs, notifications, window/menu/updater). That is a **bounded, mostly-native-routable** surface — *not* the fragile per-release private-IPC emulation that the "Electron-renderer-in-WebView" framing feared.

Result: you get **the WebView you want** (native macOS 26, deep Apple integration) **and** ACP's stability **and** full Goose capability — simultaneously. The federation doc's 10-step Goose ladder still applies for the **boot/affordance shim**; its assumption that the *agent path* needs IPC emulation is **superseded** here by ACP.

---

## §3 macOS WebView API — RESOLVED

`[VERIFIED-CODE]` `MACOSX_DEPLOYMENT_TARGET = 26.0` (project.pbxproj). `[VERIFIED-CODE]` `Epistemos/Work/WorkWebSurfaceView.swift` already uses `WebPage()` + `WebView(page)`.

- **Primary for all NEW embedded surfaces: SwiftUI `WebView` + `WebPage`.** Because the app is macOS-26-only, the back-deploy advantage of classic `WKWebView` does **not** apply, and `WebView`/`WebPage` is the natively-integrated, observable, SwiftUI-first host — the deepest-Apple-integration option (validates the owner's preference). It supports the full bridge: JS↔native via `WKUserContentController` (reused), user scripts at document-start, custom URL schemes (`urlSchemeHandlers`), `callJavaScript`, `WKWebsiteDataStore.nonPersistent()`.
- **`WKWebView` (via `NSViewRepresentable`) only** where an already-built surface hasn't migrated or a specific API gap forces it (e.g. the Epdoc/Tiptap editor). Do not build new `WKWebView` wrappers.
- Both are the **same WebKit engine** — this is "new SwiftUI host API vs old AppKit host API," not "two browsers." (Supersedes the earlier draft line "default to WKWebView for back-deploy," which assumed a lower deployment target.)

Apple sources: WWDC25 "Meet WebKit for SwiftUI" (developer.apple.com/videos/play/wwdc2025/231), `WebPage`, `WebPage.Configuration`, `WebPage.callJavaScript`, `WKUserContentController`.

---

## §4 Shared bridge contract (`window.epistemos` + ACP client)

One versioned, **denial-first**, schema-validated bridge for every web surface; the same generic commands, surface-specific adapters underneath.

| Command (web→native) | Backed by today | MAS-safe? |
|---|---|---|
| `epistemos.context.snapshot` | `WorkAppContextSnapshot` + Work native MCP (exists) | ✅ |
| `epistemos.session.create` / `.select` | Work session registry / AgentClone bridge | ✅ |
| `epistemos.event.post` (mirror) | event model (§7 families) | ✅ |
| `epistemos.permission.request` | native permission cards (Work has them) | ✅ |
| `epistemos.tool.call` | native MCP tool executor | ✅ |
| `epistemos.note.create/update/delete`, `epistemos.graph.context`, `epistemos.search.vault` | app vault/graph services (wire post-isolation) | ✅ |
| `epistemos.skill.list/run`, `epistemos.runtime.health` | skills catalog / supervisors | ✅ |
| **Goose agent traffic** | **ACP client over `/acp` WebSocket** (separate from the JS bridge) | ⚠️ Pro (subprocess) |

Rules: reject unknown commands + malformed payloads; request ids + session ids; structured errors; RunEvent-style evidence; **never** let web content touch files/Keychain/process-spawn directly — it asks the host bridge, which applies the same permission rules as native. (Transport layers per federation doc §"Bridge Transport Shape": Swift host controller owns the `WebPage`, injects bootstrap, receives messages, calls back via `callJavaScript`; per-surface adapters `GooseWebBridgeAdapter` / `OpenGUIWebBridgeAdapter`.)

---

## §5 Strip / keep + install-update kill-list (owner's explicit ask: "one app, kill their installers/updaters")

**Strip/hide (shell & identity only):** standalone splash/onboarding, donor top-level window chrome, donor app menu/About, **donor updaters + self-install systems**, marketing/branding copy, duplicate landing pages, separate settings islands that fight Epistemos, decorative theme that fights the flat target.

**Never strip (capability):** provider config/auth, dependency/tool install logic, session stores, runtime process contracts, MCP/ACP/extensions/skills/recipes/schedules, approval/permission logic, event-stream semantics, diagnostic names, package/module/import/env/storage/protocol names (unless a tested migration exists).

**Install/update kill-list — replace donor self-update with single Epistemos bundling (MAS forbids runtime npm/subprocess; bundle at build time):**
| Donor system | How it's removed | Replaced by |
|---|---|---|
| Goose Electron `autoUpdater` (7 IPC channels) + `GOOSE_BUNDLE_NAME`/`GITHUB_OWNER`/`GITHUB_REPO` updater lookup | shim disposition = `hidden-shell`; never expose update UI | Epistemos ships a pinned Goose build; app-level versioning |
| OpenCode/Bun self-update + npm/pnpm runtime fetch | not invoked; binaries pre-bundled in `Contents/Resources` (`opencode` 1.17.9 + `bun` 1.3.14 already there) | build-time bundling only |
| Donor onboarding that blocks first run | hidden behind Epistemos onboarding | one Epistemos first-run/setup hub |

---

## §6 Native-feel checklist (the Craft lesson)

Craft feels native because it's **Mac Catalyst + custom-drawn canvas** and kills every browser tell — **native feel ≠ native stack** (Raycast = React→AppKit; Cron = Electron). Apply to every `WebView` surface — feel is **subtraction + local-first**:
1. **Kill the network from the UI path** — local-first/optimistic, **no spinners**; warm-resident `WebPage` for instant first paint.
2. **Native window chrome** — real traffic lights over full-bleed content; never a CSS title bar.
3. **Strip browser tells on the NATIVE side** (so donor CSS can't fight it): disable web context menu, pinch/magnification zoom, overscroll bounce; `windowOcclusionDetectionEnabled = false` (stops WebKit throttling backgrounded views).
4. **Inject look-and-feel via a document-start user script:** font stack, scrollbar stripping, `cursor:default`, `-webkit-font-smoothing:antialiased`, `overscroll-behavior:none`, `:root{color-scheme:light dark}` (dark mode auto-maps from `effectiveAppearance`). **Accent color is the one thing to inject manually** (`NSColor.controlAccentColor` → CSS var).
5. Native menus + command palette + global hotkey; native sheets/popovers, not HTML modals; vibrancy = `NSVisualEffectView` + clear `underPageBackgroundColor` + transparent CSS body.
6. **WKWebView/`WebPage` gotcha:** `-webkit-app-region: drag` does NOT work — use a transparent drag `NSView` overlay (`mouseDownCanMoveWindow=true`, `hitTest→nil` over interactive zones).

---

## §7 Proof gates (don't call any surface "done" until these pass)
**Shared:** Landing opens Chat/Act/Work in one shell; each keeps its own runtime capability (no fallback to old ChatView/Osaurus/MiniChat/GraphChat/NoteChat); theme tokens apply at first paint; draft-prompt handoff from Landing; session shows in shared recents; context snapshot readable by the runtime; tool/permission events in native UI; errors are panel/transcript-visible; closing a surface tears down its processes.
**Event families to mirror BEFORE any unified native transcript:** session created/selected, prompt submitted, thinking started, tool requested, permission requested/answered, tool result, install step, model changed, answer delta, answer finished, error/abstention, cancel, context attached.
**Chat:** native mount; prompt runs through the clone runner (not a parallel fake); host vault/workspace context; side-panel context.
**Act/Goose:** real Goose Electron launches as fallback; `goose serve` ACP WebSocket reachable; ACP client completes new→prompt→stream(thinking/tool/answer)→permission→result; Goose web UI boots in `WebView` via the narrow shim; affordance ledger covers every used `window.electron` call.
**Work:** native Work primary + OpenCode SPA WebView both open; no-model OpenGUI probes pass; prompt queue/permissions/recents/session-reopen pass; `epistemos.context.snapshot` works through native MCP.

---

## §8 GROUND TRUTH — where the three streams are NOW (verified 2026-06-25, not self-report)

| Stream | Where it lives | Actual state | vs target |
|---|---|---|---|
| **Chat/Act = AgentClone** | `LocalPackages/AgentClone` + `RootView.swift` mount | **LIVE**, mounted (`AgentClone.ContentView()`), host-context bridge (`AgentCloneBridge.updateHostContext`) + prompt buffer/recovery working. Mid **Osaurus purge** (Osaurus vendor + `ActOsaurus*` + `ChatCoordinator.swift` deleted). All uncommitted. | On-target as Chat. Also serves as **interim Act host** until Goose-Act lands. |
| **Work = OpenGUI** (harness; OpenCode = one hidden engine) | `Epistemos/Work/*` (untracked!) + `.research-clones/work/opengui` (own git) | **LIVE + PROVEN** (215+ tests, no-model sidecar probes pass). Native chrome over the OpenGUI harness (primary) + OpenGUI/OpenWork web SPA `WebView` (fallback). "Hardened isolation" phase: deep names intact, app integration deferred. Self-report **accurate**. Note: bare-`opencode serve` (`WorkRuntimeSupervisor`) is the placeholder tier; target is the OpenGUI multi-harness (`WorkOpenGUISupervisor`). | On-target; strongest stream. De-foreground "OpenCode" (§0.1) + promote the SPA WebView to first-class. |
| **Goose = Act engine** | `.research-clones/work/goose` (own git, 241 dirty) | **NOT app-wired.** Only an inert stub (`GooseWorkBackend` hostingService=nil) + a non-runnable picker entry `("goose","Goose",false)`. Clone has full ACP (`crates/goose/src/acp/`, `goose serve`, `/acp` WS) + reskin work. No ACP client in Swift yet. | **Needs the §1/§2 re-target** (WebView UI + ACP transport). Biggest course-correction. |

**Naming note that caused confusion:** the status report you labeled "Goose's" actually describes the **AgentClone/Act** agent (it mentions AgentClone bridging). So today **Act runs on AgentClone**, and **Goose is a separate, not-yet-wired clone**. That's expected — Act migrates AgentClone→Goose once the Goose-Act surface is proven.

**Handoff status (2026-06-25):** BOTH active lanes reached clean *scoped* stops and wrote handoffs — Act/AgentClone (`docs/handoffs/ACT_AGENTCLONE_STOPPING_POINT_HANDOFF_2026_06_25.md`) and Work/OpenGUI (`docs/handoffs/WORK_OPENGUI_STOPPING_POINT_HANDOFF_2026_06_25.md`). Each passed only *scoped* checks (swift parse, scoped `swift test`, naming scans) — neither ran a full Xcode build.

**THE shared blocker (ownerless — this is the gate for everything):** the WHOLE app target does NOT compile. Both handoffs explicitly **declined to fix it** ("app-wide deletion/refactor blockers outside our lane"). It is the **Osaurus-purge aftermath**: EventSource/AsyncHTTPClient C-module resolution (CAsyncHTTPClient/CNIO*) + `AgentChatState`/`DisplayPacedTextBuffer` + `CognitiveIntents`/`chatState` + `ChatSidebarView`. This is chat/app-domain → **the Chat/Swift-Agent lane owns it as Phase 0** (§10.1). Until main compiles, NO lane can do full-app verification.

**Execution:** owner runs agents ONE AT A TIME (no worktrees, no parallelism) — the running agent has full file control over the whole tree; see §10. (A stray `Epistemos-cursor` worktree from earlier parallel work may exist; it is not part of this plan.)

---

## §9 PER-AGENT DIRECTIVES + PROMPTS (paste one to each agent)

**Directive summary:** Chat = **CONTINUE**. Work = **CONTINUE**. Goose = **CONTINUE but RE-TARGET to ACP+WebView**. None need to stop; only Goose changes shape.

**LANDING CONTRACT (paste into ALL three agents — owner-locked):**
```
The landing/home window shows EXACTLY three surfaces, nothing else:
  Chat = Swift Agent (AgentClone)   ·   Act = Goose   ·   Work = OpenGUI
- OpenCode is NOT a landing surface. OpenCode the ENGINE keeps running as OpenGUI's default harness;
  OpenCode the standalone TUI VIEW (WorkTerminalHostView) moves to SETTINGS ONLY (already mounted at
  WorkCloneSettingsView.swift:34) and is removed from the landing (RootView.swift:2697-2701). Do NOT
  delete WorkTerminalHostView/WorkTerminalView.swift.
- Foreground mode labels = "Chat"/"Act"/"Work". Engine names (OpenCode/Codex/Claude Code/Pi/Goose) appear
  ONLY in the in-surface engine picker + Settings, never as a surface brand.
- WorkspaceModeKind (.chat/.act/.work = the landing surfaces) is a DIFFERENT enum from CoworkChatMode
  (.chat/.act = an in-Chat single-turn/agentic toggle). Never conflate them.
- ONE AT A TIME, FULL FILE CONTROL: the owner runs agents sequentially, so the running agent owns EVERY
  file — no worktrees, no lane isolation, no shared-file coordination. Edit anything needed for full
  no-compromise integration (RootView.swift, AppBootstrap.swift, packages, routing). The ONLY rule:
  PRESERVE the other surfaces' working behavior — never delete/break Work (OpenGUI), Act (Goose), their
  donor clones, or their committed work; integrate, don't destroy. (Handoff lane-boundaries were for
  parallel safety and no longer bind you.)
- LICENSING IS NOT A CONSTRAINT (owner): vendor + fuse every donor's full source freely (Swift donors,
  Goose, OpenGUI). Never omit/gate/thin/caveat a donor for license reasons; do not surface license
  language. (Separate from the MAS subprocess technical limit.)
- Do NOT hand-edit Epistemos.xcodeproj. Epistemos/ and EpistemosTests/ use file-system SYNCHRONIZED ROOT
  GROUPS — new files auto-include; editing the pbxproj causes conflicts across lanes.
- RESUME from your lane's 2026-06-25 handoff first (Chat/Act: ACT_AGENTCLONE_STOPPING_POINT_HANDOFF +
  ACT_AGENTCLONE_MASTER_GOAL_PROMPT; Work: WORK_OPENGUI_STOPPING_POINT_HANDOFF + WORK_CANON_STATUS). Do
  NOT resume any previous "infinite hardening loop" — work the new directive.
```

### A — Chat / Swift Agent agent → CONTINUE (full no-compromise fusion loop)
```
Continue the Epistemos Swift Agent / AgentClone FULL-FUSION loop in /Users/jojo/Downloads/Epistemos
until the owner explicitly says stop. This is NOT a scaffold task, NOT a contract-only task, and NOT a
donor-app mount. The goal is the no-compromise ideal Epistemos native Swift agent: AgentClone is the
current visible foundation, but EVERY researched Swift donor must be fully included, studied,
vendored/preserved, and strategically fused where it adds real product capability. The final product
must feel like Epistemos, not AgentClone wearing a thin skin.

LICENSING IS NOT A CONSTRAINT (owner directive): do not mention, weigh, gate, omit, thin, or caveat any
donor for license reasons. Vendor and fuse every donor's full source freely. (Separate from MAS sandbox
subprocess limits, which are a technical runtime fact, not licensing.)

FULL SWIFT DONOR SET — all 9 are ALREADY vendored locally; keep provenance, fuse the BEST ideas into
Epistemos-owned code (do not omit any donor because it is inconvenient):
  1. AgentClone / macos26 Agent  — LocalPackages/AgentClone + .research-clones/swift-act/agent-macos26
       — visible native agent foundation
  2. Swarm                       — LocalPackages/Swarm + .research-clones/swift-act/swarm
       — Swift runtime/orchestration/workflow substrate
  3. SwiftedMind SwiftAgent      — .research-clones/swift-act/swiftagent-swiftedmind
       — streaming/session/tool ergonomics
  4. 1amageek SwiftAgent         — .research-clones/swift-act/swiftagent-1amageek
       — permissions, sandboxing, MCP, skills, Foundation Models patterns
  5. MCP Swift SDK               — .research-clones/swift-act/mcp-swift-sdk
       — native MCP tools/resources/prompts/progress/cancel/auth
  6. AgentSDK-Swift              — .research-clones/swift-act/agentsdk-swift
       — typed agents, tools, guardrails, handoffs
  7. AgentKit                    — .research-clones/swift-act/agentkit
       — retry/window/MCP ergonomics
  8. SwiftAIAgent                — .research-clones/swift-act/swiftaia-agent
       — workflow/model-output/tool-call motifs
  9. Foundation Models Framework Example — .research-clones/swift-act/foundation-models-framework-example
       (+ LocalPackages/LocalLLMClient/.../FoundationModels)
       — Apple-native model UX, local/private generation, structured output, tool use

RESUME from docs/handoffs/ACT_AGENTCLONE_STOPPING_POINT_HANDOFF_2026_06_25.md + ACT_AGENTCLONE_MASTER_GOAL_PROMPT_2026_06_25.md
(prior clean stop: RootView mounts AgentCloneChatHostSurface; AgentCloneAppContextSnapshot -> AgentCloneHostContext;
Epistemos-owned session storage; scoped tests pass).

PHASE 0 — YOU OWN THE SHARED BUILD FIX (do this FIRST, on main, before deep fusion). The WHOLE app target does
not compile; BOTH other lanes deferred it as "outside our lane." It is chat/app-domain = yours: resolve
EventSource/AsyncHTTPClient C modules (CAsyncHTTPClient/CNIO*) + AgentChatState/DisplayPacedTextBuffer +
CognitiveIntents/chatState + ChatSidebarView, left by the osaurus purge. Do NOT restore Osaurus to get a compile
pass. Commit a GREEN baseline (app builds) — that unblocks all three lanes — before going deep.

PRIMARY OBJECTIVE: make the new Swift agent as deeply integrated with Epistemos as the OLD chat used to
feel, but WITHOUT preserving the old chat implementation. Landing/Home, main Agent/Chat/Act, MiniChat,
Graph Chat, Note Chat, vault context, app-side note storage, native tools, skills, settings, recents,
sessions, permissions, and transcript history must all become ONE coherent Epistemos-owned
agent/session/context system.

OLD SURFACES — remove/reconceptualize (this supersedes the earlier "defer until isolation lifts" for the
CHAT lane — the owner is lifting isolation here):
- Delete old native ChatView-era logic.
- Delete old MiniChat, Graph Chat, Note Chat backends/surfaces.
- Do NOT revive old ChatState/DialogueChatState/NoteChatState as parallel inference stacks.
- Rebuild those surfaces as AgentClone/Swarm-backed Epistemos PORTALS with typed context + shared
  session identity (NOT separate private engines).

DEEP INTEGRATION REQUIREMENTS:
- Landing is the CONNECTED top-level shell that creates/resumes/routes agent sessions, not a detached launcher.
- MiniChat = compact/floating CHILD portal into the same agent system.
- Graph Chat passes selected nodes, edges, graph route, neighborhood summary, and graph actions in.
- Note Chat passes active note id/title/path, selected text, visible excerpt, backlinks/tags, and
  approved note actions in.
- Vault context is FIRST-CLASS: app vault root, app-side note storage, skills, note
  create/delete/update/search, citations, metadata via Epistemos-owned APIs — never raw file guessing.
- Build real tools+skills fusing the clone's abilities with app features: note create/delete,
  selected-text rewrite, vault search, graph context read, graph mutation WITH APPROVAL, document
  context, session summaries, skill discovery, app-context snapshot.
- Deeper local/backend connections where useful: native MCP, local app services, vault-backed resources,
  app-side storage, model/provider state, local runtime context, safe network/runtime bridges — only
  when explicit and visible.
- Permission/error behavior is native Epistemos behavior: clear approval cards, transcript-visible
  failures, NO silent fake success.

UI: full Epistemos native parity — flat, minimal, theme-aware, integrated with Landing, polished. No
donor labels/empty-states/chrome or generic SwiftUI panels in the foreground. Keep real controls
reachable via rails/panels/popovers/settings/command palettes. Do NOT delete capability to look cleaner.

WORK METHOD — two tracks every loop: (1) product hardening (deepen the live AgentClone foundation,
bridge, UI, prompt receiver, context, tools, panels, routing, app state); (2) deep
research/documentation (document every future deepening seam + each donor's best usable contribution).
Do not stop after documenting — keep moving toward real fused product behavior.

LANDING/LANE: your landing surface = Chat (Swift Agent), one of exactly 3 (Chat/Act/Work). Act's target
engine is Goose; you are only the INTERIM Act host until Goose-Act lands. FULL FILE CONTROL (owner runs
agents ONE AT A TIME): edit ANY file you need — RootView.swift, AppBootstrap.swift, AppCoordinator.swift,
packages, routing, shared state. No worktrees, no lane isolation. The one rule: PRESERVE the Work (OpenGUI)
and Act-Goose surfaces + their clones — integrate, never delete/break their work. Commit a GREEN baseline
after Phase 0, then commit at each clean point.
Guardrails: macOS 26.0; @Observable; no force-unwrap; deep donor/runtime/storage/API identifiers stay
unless a real migration exists; foreground says Epistemos.

SUCCESS STATE: Epistemos launches into a coherent native shell where Landing, main agent, mini, graph,
note, vault, tools, skills, recents, permissions, and app context all feel connected. AgentClone is the
foundation; Swarm + the other 8 donors provide deeper runtime/feature machinery; Epistemos owns the
visible UI, routing, state, permissions, app-side tools, and product identity.

PROOF GATES: app builds; Landing creates/resumes/routes sessions; Mini/Graph/Note work as portals into
the one agent system (no parallel engines); vault/note/graph tools call Epistemos APIs (not raw files);
permissions render as native cards; failures are transcript-visible; recents/sessions are shared
Epistemos identity; foreground shows zero donor chrome.
```

### B — Work / OpenGUI agent → CONTINUE
```
You own WORK = "Epistemos Work", powered by the OpenGUI HARNESS RUNTIME (WorkOpenGUISupervisor),
which hosts multiple engines (OpenCode, Codex, Claude Code, Pi). Native chrome lives in
Epistemos/Work/WorkEngineSurfaceView.swift + WorkEngineSurfaceWindowController; the web SPA in
WorkWebSurfaceView.swift (already on macOS 26 WebView/WebPage). You are the strongest stream —
stay the course.

NAMING (owner-hardened — the headline change): the Work engine is OPENGUI, not OpenCode. OpenCode
is just ONE (default) engine under the OpenGUI picker and its NAME must be de-foregrounded.
- Foreground (landing entry, surface title, composer, status) = "Epistemos Work". NEVER "OpenCode",
  NEVER "OpenGUI". Fix any landing/Work label that currently shows "OpenCode".
- Engine names (OpenCode/Codex/Claude Code/Pi/Goose) appear ONLY in the in-surface engine picker +
  diagnostics — never as the mode/brand.
- DO NOT rename backend contracts (opencode.json, OPENCODE_*, OPENGUI_OPENCODE_PORT,
  OPENWORK_OPENCODE_BIN, harness id "opencode", env/protocol/storage keys) — renaming breaks runtime.
- The bare `opencode serve` path (WorkRuntimeSupervisor) is the PLACEHOLDER; the target surface is the
  OpenGUI multi-harness (WorkOpenGUISupervisor). Keep OpenGUI primary, bare path as fallback.

LANDING + OPENCODE-TUI RELOCATION (owner-locked — do this first):
- Today the landing .work mode mounts WorkTerminalHostView (the OpenCode TUI, WorkTerminalView.swift:120)
  at RootView.swift:2697-2701. CHANGE it to mount the OpenGUI surface (WorkEngineSurfaceView, the one
  WorkEngineSurfaceWindowController.open() opens at EpistemosApp.swift:1523).
- MOVE the OpenCode TUI to SETTINGS ONLY — it is ALREADY mounted there (WorkCloneSettingsView.swift:34);
  just remove it from the landing. DO NOT delete WorkTerminalHostView / WorkTerminalView.swift.
- Keep OpenCode THE ENGINE working as OpenGUI's default harness — the TUI relocation must NOT break the engine.
- Result: landing shows Work = OpenGUI (clean), and the OpenCode TUI is reachable only via Settings.

Then:
1. Keep hardening OpenGUI sidecar routing, session/message edge cases, endpoint input bounds, NDJSON
   stderr drains.
2. Keep the flat OpenCode-TUI-minimal reskin with ALL controls reachable (no capability deleted for
   minimalism).
3. Per the owner's dual-WebView goal, promote the OpenGUI/OpenWork web SPA in WebView/WebPage to a
   FIRST-CLASS Work surface option (not just a Settings preview). Both the native-chrome path and the
   SPA WebView path stay available and full-capability.
4. Keep WorkAppContextSnapshot + epistemos.context.snapshot native MCP — the SHARED context pattern
   other surfaces copy. Defer deep vault/graph/note integration until isolation lifts (document now).
Guardrails: subprocess paths are Pro / #if !EPISTEMOS_APP_STORE; MAS build degrades honestly (no hidden
spawn). FULL FILE CONTROL (owner runs agents ONE AT A TIME) — edit any file needed, but PRESERVE the Chat
(AgentClone) and Act-Goose surfaces; never delete/break their work. Commit at clean points (clone has its
own git). Proof gate: native Work (OpenGUI) + OpenGUI web
SPA both open with foreground "Epistemos Work" (no "OpenCode" leak); no-model OpenGUI probes pass; prompt
queue/permissions/recents/session-reopen pass; Work in shared recents.
RESUME: read docs/handoffs/WORK_OPENGUI_STOPPING_POINT_HANDOFF_2026_06_25.md + WORK_CANON_STATUS_2026_06_25.md +
WORK_POST_ISOLATION_DEEPENING_PLAN_2026_06_25.md first. You're at a clean stop — do NOT resume the old infinite
hardening loop. Full-app verify waits for Phase 0 (Chat lane makes main compile); until then keep scoped checks.
```

### C — Goose / Act agent → CONTINUE but RE-TARGET (ACP transport + WebView UI)
```
You own ACT = Goose — your LANDING surface is Act (one of exactly 3: Chat/Act/Work; see the Landing
Contract). NEW LANE — this has NOT started: Act currently runs on AgentClone (interim), and AgentClone keeps
hosting Act until your Goose surface proves out. You are STARTING this lane. Full-app verify waits for Phase 0
(Chat lane makes main compile); meanwhile vendor/ACP/WebView scaffolding proceeds.
RE-TARGET (owner decision 2026-06-25): integrate Goose as its WEB UI in a
macOS 26 WebView/WebPage, with the AGENT driven over ACP-over-WebSocket to a supervised
goose serve / goosed — NOT a full window.electron IPC emulation. This is how Goose's own renderer
already works (ui/desktop/src/main.ts buildAcpWebSocketUrl -> /acp?token=, USE_ACP_CHAT flag). Do:
1. Keep the REAL Goose Electron app building from .research-clones/work/goose as the capability
   baseline AND fallback. Never lose Goose capability.
2. Stand up a supervised `goose serve` (ACP over HTTP+WebSocket, :3284) or `goosed agent` with the
   /acp router; harden the subprocess per agent_core security.rs harden_cli_subprocess.
3. Build the Epistemos ACP CLIENT (Swift): implement session/request_permission + session/update
   (required), optionally fs/* + terminal/*; render permission + elicitation NATIVELY. The ACP wire
   is stable (agent-client-protocol 0.11), so the agent path will NOT drift.
4. Host Goose's web UI in WebView/WebPage with a NARROW boot/affordance shim: provide
   getGoosedHostPort / getSecretKey / getAcpUrl / getConfig, and native-route or stub the OS-affordance
   window.electron calls (dialogs, notifications, window/menu, UPDATER). Keep a disposition ledger:
   implemented-native | implemented-runtime | hidden-shell | compatibility-preserved | deferred-with-visible-error.
5. Do NOT reverse-engineer the ~52 private IPC channels for the agent path — the agent path is ACP.
Guardrails: Goose MAY be less native than Work (owner-approved). ALL Goose paths are Pro/Developer-ID
(subprocess) — MAS build hides Act-Goose or shows an honest "Pro only", never a hidden spawn. Do not
rename protected Goose env/config/protocol/runtime names. FULL FILE CONTROL (owner runs agents ONE AT A
TIME) — edit any file needed, but PRESERVE the Chat (AgentClone) and Work (OpenGUI) surfaces; never
delete/break their work. Commit at clean points (clone has its own git).
Proof gate: real Goose Electron launches as fallback; goose serve ACP WebSocket reachable; ACP client
completes new->prompt->stream(thinking/tool/answer)->permission->result; Goose web UI boots in WebView
via the narrow shim; nothing lost vs the real app.
```

---

## §10 Execution model — ONE AGENT AT A TIME, full file control (owner decision 2026-06-25)

The owner runs the agents **sequentially, not in parallel**. So there are **NO worktrees, NO lane isolation, and NO shared-file coordination**. The currently-running agent has **FULL CONTROL over every file in the repo** and may make whatever change a no-compromise integration needs — `RootView.swift`, `AppBootstrap.swift`, packages, routing, shared state, or any surface's files. This is the zero-compromise posture: nothing is held back for isolation reasons.

**The one standing rule: PRESERVE the other surfaces' working behavior.** Do not delete or break the Work (OpenGUI) or Act (Goose) surfaces, their donor clones, or their committed work — integrate with them, don't destroy them. (The lane-boundary language in the 2026-06-25 handoffs existed only for parallel safety and no longer binds the running agent.)

**Run order (owner is starting with the Swift agent):**
1. **Chat / Swift Agent (§9-A)** — FIRST, running now. Also owns **Phase 0**: get the WHOLE app target to compile (the §8 Osaurus-aftermath blocker), commit a GREEN baseline, then do the full 9-donor fusion + rebuild Mini/Graph/Note as portals. Full file control.
2. **Act / Goose (§9-C)** — NEW lane (Act is AgentClone-interim today). Stand up the Goose ACP+WebView Act surface.
3. **Work / OpenGUI (§9-B)** — resume from its handoff; deepen.

(Order is the owner's call; the only hard dependency is that Phase 0 lands so later agents inherit a compiling tree.)

**Checkpoint hygiene (still matters):** commit after each agent reaches a green/clean point, so the next agent starts from a known-good tree. Safety nets if anything goes wrong: tags `wip-safety-main-20260625` + `wip-safety-main-20260625-b`, archives `/tmp/epistemos-untracked-safety-20260625*.tgz`. Donor clones (`.research-clones/work/{goose,opengui}`) keep their own git — commit inside those dirs too. **No worktrees needed.**

## §11 Recovery & safety (already in place)
- **Snapshot of tracked modified/deleted work:** git tag `wip-safety-main-20260625` (`git stash apply wip-safety-main-20260625`). Non-destructive; working tree untouched.
- **Archive of 544 untracked NEW files** (all of `Epistemos/Work/`, new docs, LocalPackages): `/tmp/epistemos-untracked-safety-20260625.tgz` (`tar -xzf … -C /Users/jojo/Downloads/Epistemos`).
- Clones recover from their own git: goose @ `eea6989` (+241 dirty), opengui @ `e25cb97` (+13).

## §12 Failure modes to reject
One native ChatView for all three; Goose **agent path** via Electron-IPC emulation (use ACP); replacing the native Work primary with a generic WebView; a broad/unvalidated `window.epistemos` bridge (allowlist + schema only); web content touching raw files/Keychain/spawn; reviving MiniChat/GraphChat/NoteChat/Osaurus as hidden fallbacks; renaming protected donor/runtime contracts for branding; building a unified native transcript before event parity; calling a surface "done" on a screenshot/static shell.

## §13 Condensed research log + sources (supersession trail)
- 2026-06-25 — Doc created; current truth = native Swift Act (AgentClone) + native Work + Goose-clone-deferred; reconciled 4 historical maps.
- 2026-06-25 — P1 first verdict "WKWebView for back-deploy" → **SUPERSEDED** once `MACOSX_DEPLOYMENT_TARGET=26.0` confirmed: primary = `WebView`/`WebPage` (§3).
- 2026-06-25 — P7: Craft = Catalyst/custom-drawn; native-feel = subtraction+local-first (§6).
- 2026-06-25 — P2 RESOLVED: Goose = ACP (Goose ships ACP over stdio `goose acp` AND WebSocket `goose serve`/`/acp`; its own renderer uses `USE_ACP_CHAT`/`buildAcpWebSocketUrl`). Electron-renderer-IPC-emulation rejected for the agent path; narrow boot/affordance shim only. Real Goose Electron = baseline/fallback.
- 2026-06-25 — **Fusion lock:** dual-WebView + ACP unified (§2); deploy-target + Goose-ACP-WS facts verified in code; doc finalized to DEFINITIVE; loop closed; per-agent directives + prompts written (§9); owner checkpoint plan (§10).
- 2026-06-25 — **NAMING HARDENED (§0.1).** Owner correction: the Work surface is **OpenGUI** (multi-engine harness), not OpenCode. Verified in code (`WorkOpenGUISupervisor.swift:4` "OpenGUI is the harness… harnesses MULTIPLE engines"; picker = OpenCode/Codex/Claude Code/Pi + Goose). Earlier draft's "Work = OpenCode" / "OpenCode SPA" foreground naming **SUPERSEDED** → foreground "Epistemos Work", OpenCode = one hidden engine, bare-`opencode serve` = placeholder vs OpenGUI multi-harness target. Backend contract names unchanged. Architecture was correct; only the writeup's foreground naming was loose.
- 2026-06-25 — **LANDING CONTRACT hardened (§0.1).** Owner: landing = exactly 3 surfaces (Chat=Swift / Act=Goose / Work=OpenGUI). Verified `RootView.swift:2697-2701` currently mounts `WorkTerminalHostView` (the OpenCode TUI) for `.work` → must mount `WorkEngineSurfaceView` (OpenGUI). OpenCode TUI → **Settings-only** (already at `WorkCloneSettingsView.swift:34`), **not deleted**; OpenCode **engine** stays under OpenGUI. All 3 agent prompts + a shared Landing-Contract preamble updated. Mode-name hazard documented (`WorkspaceModeKind` vs `CoworkChatMode`).
- 2026-06-25 — **Swift Agent full-fusion directive + no-licensing principle.** §9-A Chat prompt rewritten to the owner's full no-compromise fusion plan (all 9 Swift donors — verified ALL already vendored under `LocalPackages/` + `.research-clones/swift-act/`; §1.1 table). Old ChatView/Mini/Graph/Note backends deleted + rebuilt as AgentClone/Swarm portals with shared session identity (isolation lifted for the CHAT lane only). Added global **LICENSING-IS-NOT-A-CONSTRAINT** principle (§0.8, §1.1, shared prompt preamble). Single source of truth = THIS doc; federation handoff doc = referenced implementation-ladder companion only.
- 2026-06-25 — **Regrounded on the two lane handoffs** (`ACT_AGENTCLONE_STOPPING_POINT_HANDOFF` + `WORK_OPENGUI_STOPPING_POINT_HANDOFF`). Both at clean SCOPED stops; both DECLINED the app-wide compile fix → it's ownerless (the Osaurus-aftermath blocker) and now assigned to the Chat lane as **Phase 0** (§8, §9-A). Added **§10.1 "all three at once"**: Phase-0 build fix on main → 3 git worktrees + separate DerivedData (Act/Goose is a NEW lane; Act currently = AgentClone interim). Added synchronized-root-groups (no pbxproj edits) + resume-from-handoff to the shared preamble + all 3 prompts.
- 2026-06-25 — **FINAL: one-at-a-time, full-file-control posture (owner).** Owner runs agents sequentially (starting with Swift/Chat), so worktrees/lane-isolation are dropped — §10 rewritten (replaces the parallel §10.1) to "running agent owns every file; only rule = preserve the other surfaces' working behavior." All 3 prompts + shared preamble converted from lane-isolation to full-control. Zero-compromise: nothing held back for isolation. Run order Chat(+Phase-0 build fix) → Act/Goose → Work.
- Sources: Apple WWDC25 WebKit-for-SwiftUI / `WebPage` docs; Electron contextBridge/ipcRenderer/IPC tutorial; Agent Client Protocol (agentclientprotocol.com), Zed external-agents + ACP registry, JetBrains ACP, Goose ACP docs; local clones `.research-clones/work/{goose,opengui}`; repo `Epistemos/Work/*`, `LocalPackages/AgentClone`; canon `WORK_CANON_STATUS_2026_06_25.md`, `ACT_IP_PRESERVATION_2026_06_24.md`, `PRIVATE_TRI_SURFACE_…_2026_06_24.md`, federation handoff doc.
