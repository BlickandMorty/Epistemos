# Epistemos Surface Fusion — DEFINITIVE Plan, Directives & Agent Prompts

> 🟡 **PARTIAL-SUPERSEDE 2026-07-02 (OpenChamber pivot).** The WebView-vs-native embedding RESEARCH here is durable (feeds OpenChamber-in-WebView for Pro + June+goose-in-process for MAS). STALE: the goose-specific VERDICT (Option 1, reskin Goose, Goose-as-the-surface). Canon: memory `project_ui_base_pivot_openchamber_2026_07_02`.


**Status:** ✅ DEFINITIVE / LOCKED 2026-06-25. Single source of truth. Zero-contradiction. Research loop CLOSED.
**Question source:** `/Users/jojo/.codex/attachments/ab4fbb0d-28e8-4e34-911c-2c9332d8c3df/goal-objective.md`
**(The former federation "companion ladder" doc was deleted 2026-06-26 — Goose-single. Goose mechanics live in §2–§7 here; reskin-in-progress log = `docs/handoffs/GOOSE_SURFACE_CLAUDE_HANDOFF_2026_06_24.md`.)**

> Discipline: this is the ONE doc. If future research changes a fact, **edit it here in place** and add a line to §13. Never fork a second contradicting plan.
>
> ⛔➡️ **OWNER DECISION 2026-06-26 — GOOSE IS THE SINGLE SURFACE (supersedes the 3-engine federation).** Epistemos ships **one** agent surface — **Goose** (reskinned + strategically fused) — not the Chat=AgentClone / Act=Goose / Work=OpenGUI federation in §0–§12. The separate Chat and Work *surfaces* are retired; their still-wanted capabilities fold **into Goose**: native notes live in the app's markdown data layer (**§16**), and multi-engine "Work" is Goose's existing ACP family (**§15**). **§0–§14 are retained as historical context; where they conflict with §15–§17, the latter win.** In §9, only **§9-C (Goose)** stays active (§9-A Chat / §9-B Work superseded). New canonical sections: **§15** Goose-single + Paseo strategic-fusion roadmap · **§16** Markdown-as-source-of-truth data directive · **§17** the "Goose keeps working as-is" no-break rule.
>
> **Body cleanup 2026-06-26:** §0 rewritten to Goose-single (it doubles as the live/dead doc map); the OpenGUI/Work + Chat=AgentClone content is **tombstoned** — §0.1, §1, §1.1, §8, §9-A, §9-B, §10 carry ⛔ DEAD headers. **Live** sections: §2–§7, §9-C, §11, §14–§17.

---

## §0 TL;DR (Goose-single — revised 2026-06-26)
1. **Epistemos ships ONE agent surface: Goose** — reskinned, embedded, strategically fused with the best of Paseo (§15). **No Chat=AgentClone surface and no Work=OpenGUI surface** — those are retired; their good parts fold into Goose + the markdown data layer (§16).
2. **Goose = its own engine** (`goosed` daemon + its web UI), hosted in a macOS-26 `WebView`/`WebPage`, agent driven over **ACP-over-WebSocket** to a supervised `goose serve`/`goosed` (§2). The real Goose Electron app stays the 100% fallback/baseline.
3. **The Epistemos Swift app is the host shell** — owns identity, theme, recents, and the vault/notes data layer (§16); connects to Goose over ACP/MCP + the `window.epistemos` bridge (§4). It does **not** compile Goose into itself (§17).
4. **WebView API = SwiftUI `WebView`/`WebPage`** (macOS-26-only; deepest Apple integration — §3). `WKWebView` only for a legacy surface (e.g. Epdoc).
5. **Markdown `.md` = source of truth** for notes; DB/indexes are derived caches; non-note data (chats/graph/versions/companions) stays DB-canonical (§16).
6. **Goose stays independently working at all times** — the app's compile state never gates Goose; integration is **add-don't-edit** (§17).
7. **Pro/Developer-ID** (Goose spawns processes). Build Paseo features from the **spec**, never vendor AGPL code (§15.6).
8. **Doc map — LIVE:** §2 (ACP+WebView), §3 (WebView API), §4 (bridge), §5 (strip installers/keep capability), §6 (native-feel), §7 (Goose proof gates), §9-C (Goose directive), §11 (recovery), §14 (fork-maintenance), §15–§17. **DEAD/retired (tombstoned):** §0.1, §1, §1.1, §8, §9-A, §9-B, §10 (the federation / OpenGUI / Chat content).

---

## §0.1 — ⛔ DELETED 2026-06-26 (OpenGUI/Work surface retired; Goose is the single surface — see §0/§15). The OpenGUI/Work naming policy below is DEAD; ignore everything in this section.

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

## §1 — ⛔ SUPERSEDED 2026-06-26 (the Goose-single target is §0 + §15; the 3-surface federation tree below is historical — ignore it).

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

## §1.1 — ⛔ DELETED 2026-06-26 (Chat=AgentClone surface retired; Goose is the single surface — §15). The Swift donor-fusion set below is no longer the plan; ignore it.

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

> *Goose-single 2026-06-26: the OpenGUI/Work/AgentClone references in the table below are historical — apply the bridge pattern to the **Goose** WebView only (`GooseWebBridgeAdapter`).*

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

> *Goose-single 2026-06-26: applies to **Goose** only; the OpenCode/Bun (Work/OpenGUI) row below is moot — Work is retired.*

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
**Goose (the single surface):** real Goose Electron launches as fallback; `goose serve` ACP WebSocket reachable; ACP client completes new→prompt→stream(thinking/tool/answer)→permission→result; Goose web UI boots in `WebView` via the narrow shim; affordance ledger covers every used `window.electron` call. *(Chat/Work proof gates removed 2026-06-26 — single surface.)*

---

## §8 — ⛔ SUPERSEDED 2026-06-26 (3-stream federation ground-truth; historical). Current truth: Goose is the single surface (§0/§15) — only the Goose row below is live; the Chat=AgentClone and Work=OpenGUI rows are retired. The "whole app does not compile" note is an app-side issue that does NOT gate Goose (§17).

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

**Directive summary (revised 2026-06-26):** Goose is the single surface — **only §9-C (Goose) is active.** §9-A (Chat) and §9-B (Work), and the shared 3-surface "Landing Contract" preamble below, are **DELETED / superseded** (retired federation) — ignore them.

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
- GIT MODEL: all three agents work DIRECTLY on `main` — no branches, no worktrees, no merges. COMMIT your work
  on `main` at each clean point; committing is what makes the old-surface DELETIONS permanent. Do NOT merge any
  other branch into `main` (the many stale codex/*, salvage/*, wiring/*, cursor-work branches PREDATE the
  deletions and a merge would RESURRECT deleted files). The donor clones under `.research-clones/*` are separate
  git repos — commit inside them; they never merge into the app repo.
```

### A — ⛔ DELETED 2026-06-26 (Chat=AgentClone surface retired — Goose is the single surface). The prompt below is dead; do not run it.
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

STAGED ROADMAP — do these IN ORDER; confidently stabilize + COMMIT each before the next, do NOT skip ahead:
  STAGE A (RUNNING NOW): bring the current AgentClone hardening to a confident, clean, COMMITTED checkpoint —
    keep hardening EXHAUSTIVELY (that is expected + welcome), just reach a COMMIT so Stage B starts clean. Do
    NOT abandon it mid-flight. (Once it's at a committed checkpoint you're released from "clone-only" scope —
    but deep hardening continues across every later stage; see DEEP HARDENING below.)
  STAGE B — RECONCILE THE BROKEN APP (= Phase 0 below): you are NO LONGER stuck on just the clone; you now have
    FULL APP ACCESS. Fix the app-wide compile blockers so the WHOLE app builds; commit a green baseline.
  STAGE C — DEEP APP-WIDE FUSION: with the app green + full access, RECONCEPTUALIZE the Chat/agent FEATURES
    based on the finished fusion — Landing-as-connected-shell, rebuild Mini/Graph/Note as portals, first-class
    vault/graph/note context, real app tools+skills, native permission/error UI. UI nativize + minimalize.
  STAGE D — 100% ACROSS-THE-BOARD MULTI-REPO DEEP FUSION: every one of the 9 donor repos fully fused by its
    STRATEGIC per-repo capability set (the list above) — not a thin skin, not partial. Each repo contributes
    its specific machinery: AgentClone=foundation, Swarm=orchestration, SwiftedMind=streaming, 1amageek=
    permissions/sandbox/MCP/skills, MCP-Swift-SDK=MCP, AgentSDK-Swift=typed/guardrails/handoffs, AgentKit=
    retry/window, SwiftAIAgent=workflow motifs, FoundationModels=Apple-native UX.
  STAGE E — COMPLETE APP INTEGRATION: the whole coherent native Epistemos shell, 100%, end-to-end.

DEEP HARDENING IS ALWAYS-ON (owner: exhaustive hardening is the standing free bonus for every feature). Harden
each thing you build to the maximum — edge cases, guards, tests, error paths, regression locks — at EVERY stage,
not just Stage A. It is a CONTINUOUS track that runs WITH the staged progression, never a phase you exit. Two
limits so it stays honest: (1) do NOT use "still hardening" to indefinitely defer Stage B — a non-compiling app
makes app-level hardening unverifiable, so fixing the build is what turns hardening into real proof; (2) harden
across the WHOLE app + the full fusion, not one narrow slice forever. Keep hardening exhaustively AND keep
advancing the stages.

ACCESS + BOUNDARY (reconciled): you have FULL access to the APP — shell, build, routing, Chat/Act, the
vault/graph/note/mini portals, AppBootstrap, packages — and you MAY reconceptualize app features freely. But do
NOT modify the OTHER agents' surfaces: leave Epistemos/Work/* (OpenGUI/Work) and the Goose lane +
.research-clones/work/{goose,opengui} alone — they are at clean stops and belong to the Work/Goose terminals.
You own Chat + Act-via-AgentClone + the app shell. Integrate with Work/Goose; never edit or break them.

STAGE B / PHASE 0 — RECONCILE THE BROKEN APP — YOU OWN THE SHARED BUILD FIX (your next step once STAGE A is at a
committed checkpoint; on main, before deep fusion). The WHOLE app target does not compile; BOTH other lanes
deferred it as "outside our lane" — it is chat/app-domain = yours. CURRENT blocker (verified 2026-06-25, after
the chat deletion sweep): the build dies in the EXTERNAL `EventSource` Swift package BEFORE it ever reaches the
Epistemos target — it cannot resolve its transitive C-module deps `CAsyncHTTPClient`, `CNIOLLHTTP`,
`CNIOExtrasZlib`, `CNIOPosix`, `_NumericsShims` (EventSource -> async-http-client -> swift-nio / swift-numerics).
The earlier chat-domain symbols (AgentChatState/DisplayPacedTextBuffer/CognitiveIntents/ChatSidebarView) appear
ALREADY resolved by the deletion sweep — confirm, do NOT re-hunt. Fix the EventSource dependency-graph
resolution: clean + re-resolve packages, repair Package.resolved, pin a compatible EventSource +
async-http-client + swift-nio set, and/or add any missing platform/availability condition. Do NOT restore
Osaurus, and do NOT remove/stub EventSource to fake a pass. Commit a GREEN baseline (the WHOLE app builds) — that
is what makes your deep hardening REAL (app-level, not just package tests) and unblocks all three lanes — before
going deep.

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

### B — ⛔ DELETED 2026-06-26 (Work=OpenGUI surface retired — Goose is the single surface). The prompt below is dead; do not run it.
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

### C — Goose agent → ACTIVE (the single surface; ACP transport + WebView UI) — the only live directive in §9
```
You own the SINGLE Epistemos agent surface = Goose (reskinned). There is NO Chat/Act/Work federation —
Goose is the one surface (§0/§15). This lane is STARTING. FIRST read the canonical plan:
docs/research/SURFACE_EMBEDDING_WEBVIEW_VS_NATIVE_DECISION_2026_06_25.md — §0 (decision + live/dead map),
§2 (ACP+WebView), §3-§7 (mechanics), this §9-C, and §14-§17 (maintenance, fusion roadmap, data, no-break).
Goose must stay independently GREEN at all times (§17): the Epistemos Swift app CONNECTS to Goose; it never
compiles Goose into itself, and the app's build state never gates Goose — you can always launch goosed +
the Goose UI standalone to verify the engine. (Reskin-in-progress log: docs/handoffs/GOOSE_SURFACE_CLAUDE_HANDOFF_2026_06_24.md.)
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
Guardrails: ALL Goose paths are Pro/Developer-ID (subprocess) — MAS build hides Goose or shows an honest
"Pro only", never a hidden spawn. ADD, DON'T EDIT (§14.3/§17): Epistemos<->Goose wiring lives in Epistemos
across the ACP/MCP seam + the reskin overlay — never surgery on Goose's Rust core or agent path; do not
rename protected Goose env/config/protocol/runtime names (keeps upstream merges clean). Build Paseo features
from the SPEC (§15/§15.7), never vendor Paseo's AGPL code (§15.6). Commit at clean points (clone has its own git).
Proof gate: real Goose Electron launches as fallback; goose serve ACP WebSocket reachable; ACP client
completes new->prompt->stream(thinking/tool/answer)->permission->result; Goose web UI boots in WebView
via the narrow shim; nothing lost vs the real app.
NEXT (only after the proof gate passes): layer Paseo features per §15 — (1) engine picker that surfaces the
existing ACP family, (2) multi-tab/split workspace, (3) inline diff + gh PR/merge, (4) worktree-isolated
parallel runs; strategic additions, NOT a Paseo clone (§15.7 has per-feature specs). Notes/vault use the
markdown-source-of-truth data layer (§16).
```

---

## §10 — ⛔ SUPERSEDED 2026-06-26 (3-agent execution model retired; there is ONE surface = Goose = one workstream). §11 recovery/safety still applies; ignore the multi-agent run-order below.

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
- 2026-06-25 — **Deep pass on §9-A (Swift/Chat).** Added the STAGED ROADMAP (A finish current hardening loop → B reconcile broken app/Phase-0 → C deep app-wide fusion + UI nativize/minimalize + reconceptualize features → D 100% across-the-board multi-repo deep fusion by per-repo strategic capability set → E complete app integration) + the ACCESS+BOUNDARY reconciliation (full APP access incl. shell/build/routing/portals; do NOT modify Epistemos/Work/* or the Goose lane/clones). Confirms the chat agent's original plan: AgentClone foundation + each of the 8 other repos fused for its specific capability set; licensing irrelevant. All 3 prompts ready to dispatch.
- 2026-06-25 — **§9-A refinements (from live Swift-agent transcript).** (1) Phase 0/Stage B retargeted to the REAL current blocker: external `EventSource` package C-module resolution (`CAsyncHTTPClient`/`CNIO*`/`_NumericsShims` via async-http-client/swift-nio) — the chat-domain symbols are already resolved by the deletion sweep; the agent had been mislabeling this "external, not my job." (2) Added **DEEP HARDENING IS ALWAYS-ON** (owner: exhaustive hardening is the standing free bonus) — a continuous track across ALL stages, with two honesty limits (can't defer Stage B forever; harden whole-app not one slice). STAGE A reworded to "committed checkpoint, keep hardening exhaustively."
- 2026-06-25 — **GIT MODEL clarified (owner reassurance).** Verified all 3 agents work directly on `main` (no per-agent branches); `cursor-work` has 0 commits main lacks; donor clones are separate gits. Added a GIT MODEL line to the shared preamble: commit on main (locks deletions permanent), NO merges of any other branch (stale codex/*/salvage/*/cursor-work predate the deletions → a merge would resurrect deleted files). No merge is needed or wanted in the one-at-a-time/all-on-main model.
- 2026-06-26 — **Goose source-verified + fork-maintenance doctrine added (§14).** A 2026-06-26 thread re-checked Act=Goose against a fresh `block/goose` clone — ACP-over-WS + self-signed-TLS + `X-Secret-Key`, HuggingFace built-in, in-process MLX (`local_inference`), the external-CLI/ACP engine family, `goose-sdk` = `ping→pong` stub — all **confirm** §0/§2 (WebView UI + ACP, not FFI); nothing in §0 changed. Added §14.2 superseded-docs landmine (ignore the old in-process/UniFFI Goose docs, killed by `GOOSE_FULL_CLONE_INTEGRATION_COST_2026_06_21`), §14.3 "own the skin, rent the engine" (upstream remote + pinned-bump-test cadence; add-don't-edit across the MCP/ACP seam; reskin-as-rules + `git rerere` + codemod), §14.4 Electron→Tauri landmine, §14.5 PARKED note (Goose's ACP family overlaps Work's engines — future-consolidation candidate only, federation unchanged).
- 2026-06-26 — **GOOSE-SINGLE consolidation + fusion roadmap + data directive + no-break rule (owner decision).** Owner chose **one surface = Goose** (reskinned + fused), retiring the 3-engine federation (§0–§12 now historical; §9-C Goose stays, §9-A/§9-B superseded) — this *takes* the §14.5 "parked" consolidation as a deliberate documented decision, not drift. Added **§15** (Paseo strategic-fusion roadmap: what Goose already has → surface; what to build — engine picker, multi-tab/split, inline diff+`gh`, worktree-parallel; AGPL build-from-spec rule), **§16** (markdown `.md` = single source of truth for notes; indexes = derived rebuildable caches; chats/manual-graph/versions/companions stay DB-canonical; vault write-through + FSEvents watcher required for Goose/MCP coexistence), **§17** (Goose stays independently runnable; the Swift app's compile-state never gates Goose; add-don't-edit; verify Goose green standalone first).
- 2026-06-26 — **OpenGUI/Chat surfaces DELETED from the body (contradiction sweep).** Owner confirmed Goose-single + "delete OpenGUI." §0 rewritten to Goose-single (+ live/dead doc map); §0.1 / §1 / §1.1 / §8 / §9-A / §9-B / §10 tombstoned with ⛔ DEAD headers; §7 proof gates reduced to Goose only; §9 summary + §9-C marked Goose-only-active; §15.7 added (per-feature build specs). Federation handoff docs bannered separately. No contradictions remain in this doc.
- 2026-06-26 — **Deleted 13 retired federation/OpenGUI/Chat handoff docs** (tri-surface plan, ACT_AGENTCLONE_*, WORK_OPENGUI_*, WORK_CANON_STATUS, federation-research companion, control-plane). They were already bannered-superseded; now removed (git-recoverable). KEPT bannered (NOT deleted): the 4 in-process/UniFFI Goose research docs — hard-deleting them would dangle ~30 inbound refs across the corpus, so the banners are the safe retirement. In-plan dead sections (§0.1/§1/§1.1/§8/§9-A/§9-B/§10) remain tombstoned ⛔ DEAD (excising the 140-line prompt blocks risks the canonical doc; they can't mislead).
- Sources: Apple WWDC25 WebKit-for-SwiftUI / `WebPage` docs; Electron contextBridge/ipcRenderer/IPC tutorial; Agent Client Protocol (agentclientprotocol.com), Zed external-agents + ACP registry, JetBrains ACP, Goose ACP docs; local clones `.research-clones/work/{goose,opengui}`; repo `Epistemos/Work/*`, `LocalPackages/AgentClone`; canon `WORK_CANON_STATUS_2026_06_25.md`, `ACT_IP_PRESERVATION_2026_06_24.md`, `PRIVATE_TRI_SURFACE_…_2026_06_24.md`, federation handoff doc.

---

## §14 Goose source-verification + fork-maintenance doctrine (added 2026-06-26)

**Why this exists:** a 2026-06-26 thread re-verified the Act=Goose assumptions against a fresh `block/goose` clone and worked out how the reskinned Goose fork stays upstream-current. Folded in here per the §7 discipline. **It does not change the §0 decision — it confirms it and adds the maintenance contract the plan was missing.**

### §14.1 Source-verification — Act=Goose architecture confirmed `[VERIFIED-CLONE 2026-06-26]`
- **Transport = ACP-over-WebSocket** (`/acp?token=`) to a supervised `goose serve`/`goosed`, over self-signed TLS (`goose-server/src/tls.rs`, `rcgen`) + `X-Secret-Key`. Goose's own Electron desktop is itself just an HTTPS+secret-key client of `goosed` — so §2's "host the web UI, drive over ACP" is upstream's *own* architecture, not a hack. (`goosed` also exposes plain HTTP/SSE reply routes, but ACP/WS is the capability-bearing path — keep ACP per §2/§12.)
- **HuggingFace = built-in provider** (`providers/huggingface.rs`, HF OpenAI-router + `HF_TOKEN`). **Local models** four ways: Ollama · OpenAI-compatible base-URL override · declarative JSON providers · **in-process MLX** (`providers/local_inference/mlx.rs`, `local-inference`/`mlx` feature, Block's `mlx-lm` fork). New cloud models from an existing provider are usually just a model-ID string (no code); new model *behavior* or a new *local architecture* needs code that arrives **from upstream** (see §14.3).
- **Multi-CLI "engines" already ship in Goose**: external-CLI providers (`claude_code`, `codex`, `cursor_agent`, `gemini_cli`) + ACP family (`claude_acp`, `codex_acp`, `copilot_acp`, `pi_acp`, `amp_acp`); `opencode` speaks ACP (`opencode acp`) + headless (`opencode run --format json`). Native subagents (`summon`/`delegate async`) + parallel subrecipes exist.
- **In-process UniFFI is NOT the path** — `goose-sdk` is a `ping→pong` stub that does not depend on the agent crate; the core is ~1.5k async fns over `rmcp` enums UniFFI can't express. Confirms §2/§12 (drive over ACP, not FFI).

### §14.2 Superseded-docs landmine (ignore on sight)
`GOOSE_AGENT_RESEARCH.md`, `GOOSE_AGENT_RESEARCH_2.md`, `GOOSE_REPLACEMENT_STRATEGY.md`, `GOOSE_S2_EXTRACTION_PLAN_2026_06_19.md` prescribe vendoring the `goose` crate **in-process via UniFFI** — superseded twice and killed by `GOOSE_FULL_CLONE_INTEGRATION_COST_2026_06_21` (179-dep graph, reqwest major clash, build-red-prone). **Do not revive the in-process FFI plan.** Current truth = §0/§2 only.

### §14.3 Fork-maintenance doctrine — "own the skin, rent the engine"
The Act=Goose lane is a reskinned fork of an actively-developed upstream. Keep it updatable:
- **Rent the engine:** keep Goose's Rust crates / providers / ACP / sessions / security as close to upstream as possible. Add `upstream` as a git remote; pin to a known-good commit; pull on a **deliberate cadence** (when a model/security fix you need lands) → **build + test → ship**. Never blind-auto-merge — the heavy dep graph means every bump needs a test pass. This is how new models + **security patches** + protocol updates arrive for free.
- **Add, don't edit (integration):** Epistemos↔Goose wiring lives in **Epistemos**, across the **MCP / ACP / `goosed` API seam** — never as edits inside Goose's crates. Language (Rust/Swift) is irrelevant; *location* is the rule — code added in Epistemos never conflicts on update, code edited inside Goose conflicts every time. (Already the §2 posture; stated here as the maintenance invariant.)
- **Reskin as rules, not edits:** prefer theme tokens / a CSS-variable override layer / asset swaps / a **codemod** transform (rule-based → re-derives after each pull, survives upstream churn and even a framework swap) over in-place component edits (which conflict on every overlapping upstream change). The §6 document-start injection (fonts/scrollbars/accent) is already this overlay pattern — extend it to carry the brand.
- **Tools:** enable `git rerere` (auto-replays your conflict resolutions); keep unavoidable structural edits as small, single-purpose commits; one-time, sort the *existing* in-place reskin in `.research-clones/work/goose` into (a) mechanical swaps → codemod, (b) pure styling → override stylesheet, (c) true structural edits → small commits. Target ~80% of the reskin reapplies itself; only (c) is ever manual.

### §14.4 Electron→Tauri landmine
Upstream Goose is mid-migration **Electron/React → Tauri** desktop + ACP unification; the current Act reskin targets the **Electron/React** UI. When Tauri lands, in-place structural edits to the old React app are invalidated. **Mitigation:** keep the reskin rule-based (§14.3) so it re-points at the new tree; optionally **freeze the UI** at a known Electron commit while still pulling **engine/provider/security** updates; confirm the upstream Tauri timeline before deeper in-place UI work. The ACP agent path is unaffected (stable wire protocol, §2).

### §14.5 PARKED — not a decision (federation stands)
Because Goose's ACP family already drives codex/claude/opencode/copilot/pi (§14.1), a slice of Work's multi-CLI capability **also lives inside the Act engine**. That is a candidate reason to *consider* collapsing toward fewer engines later — but **only as a deliberate, documented edit to this doc**, weighed against why Work=OpenGUI (`OPENCODE_VS_GOOSE_WORK_ENGINE_2026_06_21`) and Chat=AgentClone were chosen. **As of 2026-06-26 the §0 three-engine federation stands unchanged.** Do not consolidate by drift (§7 anti-fork rule). Logged so the option is neither lost nor acted on accidentally.

---

## §15 Goose as the SINGLE surface + Paseo strategic-fusion roadmap (owner decision 2026-06-26)

**Decision:** Epistemos ships **one** agent surface — **Goose**, reskinned and strategically fused with the best of Paseo. This *executes* the §14.5 "parked" consolidation as a deliberate, documented owner decision (satisfying §14.5's own bar: consolidation by decision, not drift). Do NOT clone Paseo (AGPL, and a full clone is messy) — **rebuild its best features natively in Goose.** Verified against the Goose clone: much of Paseo is **already in Goose**.

### §15.1 Already in Goose — SURFACE it, do not build
- **Multi-CLI / multi-provider** (the top want): ACP family — `claude_acp` / `codex_acp` / `copilot_acp` / `pi_acp` / `amp_acp` + `claude_code` / `codex` / `cursor_agent` / `gemini_cli` providers + OpenCode. → add an **engine picker** in the UI; the backend already drives them.
- **Agents spawning agents** (handoff / worker-verifier loop / committee / advisor): `summon`/`delegate async` + the `orchestrator` extension + recipes → ship Paseo's patterns as **recipes/skills** (prompt design).
- **Cron / scheduled runs:** built-in scheduler → surface a schedule UI.
- **Scriptable CLI + headless `goosed` daemon + session resume/fork:** present.
- **Custom providers (config-only):** declarative JSON providers.
- **Structured output:** recipe `response` JSON schema.
- **MCP:** Goose is MCP-native.

### §15.2 Build first (owner's explicit wants, cheap → hard)
1. **Engine/provider picker** — LOW effort; surfaces the ACP family. Quick win.
2. **Multi-tab / split-pane workspace** (sessions-as-tabs; ⌘D / ⌘⇧D / ⌘1–9) — moderate–hard, UI.
3. **Inline diff review + `gh` PR/merge** — moderate–hard, UI. Diff *data* is free (git / `opencode /session/:id/diff`); reuse Goose's `highlight`.
4. **Git-worktree-isolated parallel runs** — moderate, backend. git worktrees + Goose subrecipes (≤10) + setup/teardown hooks.

### §15.3 Build later
Per-worktree dev-server **port-routing proxy + preview pane**; **goosed-as-MCP-control-surface** (expose session/worktree/terminal API as MCP); **auto-metadata** (titles/branch/commit/PR via a cheap model); in-app **terminal tabs**; **cost/token meter**.

### §15.4 Spec-only / defer · skip
- Defer: **cross-device remote + E2EE relay** (v1 = Tailscale/direct; copy only the NaCl/Curve25519 handshake *design*); **voice** (Apple Speech, or Parakeet+Kokoro ONNX; steal the "hidden agent session + `speak` MCP tool" pattern).
- Skip: theming/minimalism (Goose is already minimal), Docker, Expo mobile clients.

### §15.5 Two leverage insights
1. **ACP-as-client = ~50 agents from one integration** — Goose already does this; it's *why* the multi-provider want is nearly free. Every new agent CLI = one config entry, not a wrapper.
2. **goosed-as-an-MCP-control-surface is the keystone** — expose Goose's own session/worktree/terminal API as MCP and skills, scheduling, and remote control become thin layers, not separate features.

### §15.6 HARD RULE — build from the spec, not Paseo's code
Paseo is **AGPL-3.0**; Goose is **Apache-2.0**. **Never vendor Paseo source into Goose** — it infects the tree and breaks the §14.3 clean-merge model. Reimplement the *ideas* natively (ideas aren't copyrightable).

### §15.7 Per-feature build specs (from the Paseo research — build natively + strategically, not bulldozed)
- **Engine picker:** Goose already drives agents as ACP/provider plugins; surface a switcher over the existing `*_acp` + external-CLI providers. Each engine = one config/catalog entry (ACP adapter), never a bespoke wrapper.
- **Multi-tab / split-pane workspace:** sessions-as-tabs; split panes (⌘D / ⌘⇧D), switch (⌘1–9); pane types = agent / terminal / diff / browser.
- **Inline diff + PR/merge:** diff data from `git diff` (or `opencode /session/:id/diff`); render with Goose's `highlight`; commit / PR / merge via the `gh` CLI; auto-draft commit + PR text with a cheap model.
- **Worktree-isolated parallel runs:** `git worktree add` per run under a Goose-managed dir, each on its own branch off a pinned base; expose hook env (`SOURCE_CHECKOUT` / `WORKTREE_PATH` / `BRANCH_NAME`) + setup/teardown; diff = branch-vs-base; lifecycle create→run→review→merge/archive; fan-out via subrecipes (≤10).
- **Per-worktree dev-server routing:** declare long-running `services` in config; daemon auto-assigns a port (`$PORT`/`$URL` injected) and reverse-proxies a deterministic `*.localhost` host (`<script>--<branch>--<project>.localhost:<daemon-port>`); peers discover each other via `SERVICE_<NAME>_URL` env.
- **goosed-as-MCP-control-surface:** wrap goosed's session / worktree / terminal / permission APIs as MCP tools (create_agent · send_prompt · wait · create_worktree · respond_to_permission …) — makes orchestration skills, schedules, and later remote control thin layers.
- **Orchestration skills (recipes):** handoff (briefing schema), worker-verifier loop (run→verify→repeat to pass/max), read-only committee + advisor — all as Goose recipes/subagents over the spawn primitive above.

---

## §16 Markdown is the source of truth — DB ↔ `.md` data directive (owner decision 2026-06-26)

Governs the app's **note/PKM data layer** (separate from Goose-the-agent). Three tiers — **keep the DB, change its role**:
- **Notes → markdown `.md` is the single truth.** Today there are TWO body copies — the AppSupport sidecar `note-bodies/<pageId>.md` (live editing copy) and the vault `<vault>/*.md` (eventually-consistent export) — plus SwiftData metadata, and **no file watcher**. Target: make the vault `.md` the one **write-through** truth (frontmatter `id` for stable identity across renames), demote/drop the sidecar to a rebuildable cache, and **add an FSEvents watcher** (with echo-suppression) so external edits flow back in.
- **Indexes → derived, rebuildable caches; KEEP them (speed).** SearchIndexService FTS (speed-critical), Halo shadow (tantivy+usearch, already crawls `.md`), Eidos, structural graph. Deleting any loses zero user data. Do NOT go "pure markdown, no index" — it tanks search speed.
- **Non-note data → stays DB-canonical.** Chats/messages, hand-drawn (manual) graph nodes/edges, page version history, companions — not representable in note `.md`; keep them in SwiftData. ("All Markdown" would be wrong for these.)
- **Why this is load-bearing for Goose:** Goose's MCP vault tools already write the vault `.md` directly. Without single-truth + a watcher, Goose/MCP edits and the in-app editor silently overwrite each other — so this directive is **required** for Goose to safely edit notes. Also fix the stale "SwiftData is the source of truth" comments in `SDPage.swift` / `VaultSyncService.swift`.

---

## §17 "Goose keeps working as-is" — the no-break rule (owner requirement 2026-06-26)

Hard requirement: integrating Goose must **never** repeat the "native broke everything" / Phase-0 non-compiling-app failure. Goose stays independently working at all times.
- **Goose runs as its OWN engine** — the `goosed` daemon + its (reskinned) web UI. The Epistemos Swift host **connects** to it (ACP/WS + the `window.epistemos` bridge + MCP). It is **not** compiled into a fragile Swift target.
- **The Swift app's compile state NEVER gates Goose.** You can always launch `goosed` + the Goose UI standalone to confirm the engine works, regardless of the app build. The real Goose Electron app stays the 100% fallback (§0/§7).
- **Add, don't edit (§14.3).** Epistemos-specific features = new code in YOUR layer (Swift host, recipes, MCP tools, config) + the reskin overlay — never surgery on Goose's Rust core or its agent path. Keeps upstream merges clean and Goose green.
- **Two separate gates, in order:** (1) verify Goose green on its own; (2) verify the Epistemos integration. Never let app-brokenness masquerade as Goose-brokenness.
