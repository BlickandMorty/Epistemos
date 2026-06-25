# Epistemos Surface Fusion — DEFINITIVE Plan, Directives & Agent Prompts

**Status:** ✅ DEFINITIVE / LOCKED 2026-06-25. Single source of truth. Zero-contradiction. Research loop CLOSED.
**Question source:** `/Users/jojo/.codex/attachments/ab4fbb0d-28e8-4e34-911c-2c9332d8c3df/goal-objective.md`
**Companion (implementation ladder, reused except where §3/§5 here override it):** `docs/handoffs/EPISTEMOS_SURFACE_HOST_WEBVIEW_FEDERATION_RESEARCH_2026_06_25.md`

> Discipline: this is the ONE doc. If future research changes a fact, **edit it here in place** and add a line to §13. Never fork a second contradicting plan.

---

## §0 TL;DR (the whole decision in 7 lines)
1. **One native shell** (`EpistemosSurfaceHost`) owns Landing, the Chat/Act/Work picker, context, sessions, permissions, tools, theme, recents.
2. **Chat = AgentClone** — native Swift, deepest integration.
3. **Act = Goose** — Goose's **web UI in a macOS 26 `WebView`/`WebPage`**, with the agent driven over **ACP-over-WebSocket** to a supervised `goose serve`/`goosed`; a **narrow** boot/affordance shim (NOT a full Electron-IPC emulation). The **real Goose Electron app stays as the capability baseline/fallback**.
4. **Work = OpenGUI** (the multi-engine **harness runtime** — OpenCode is just *one hidden engine* under it, NOT the brand) — native Work chrome over the OpenGUI runtime **and** the OpenGUI/OpenWork web SPA in `WebView`/`WebPage`. Foreground = **"Epistemos Work"**, never "OpenCode". See §0.1.
5. **"Both WebViews at full capability" = YES** (the OpenGUI Work SPA + the Goose UI), and **ACP is fused in, not chosen instead** — because Goose's WebView already talks ACP.
6. **API = `WebView`/`WebPage`** (the app targets macOS 26.0, so no back-deploy tax; this is the most-native, deep-Apple-integration path — your instinct was right). `WKWebView` only where a specific legacy surface needs it (e.g. Epdoc).
7. **Everything that spawns a process (Goose, OpenCode/Bun) is Pro/Developer-ID; the MAS build degrades honestly** (no hidden sidecar).

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

**The landing leak to fix:** wherever "OpenCode" (or a bare engine name) shows on the landing / Work entry, change it to **"Work" / "Epistemos Work"**. The engine name belongs ONLY in the in-surface engine picker, never as the mode/brand. *(Note: Goose appears in OpenGUI's picker as a not-yet-runnable engine — that is a SEPARATE possibility from Act=Goose; do not conflate. Act=Goose is its own surface (§1); the OpenGUI "goose" harness stays deferred.)*

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

**Build blocker (assign to Chat/AgentClone agent):** full app build currently fails on **EventSource/AsyncHTTPClient C-module resolution** (CAsyncHTTPClient/CNIO*) — a Package.resolved drift from the Osaurus purge, **not** a logic error (AgentClone compiles alone). Resolve packages before the next "buildable" checkpoint.

**Worktrees:** main (`/Users/jojo/Downloads/Epistemos`, AgentClone+Work+Goose-clone share it) + `Epistemos-cursor` (`cursor-work`, isolated). The shared main worktree is the collision risk — see §10.

---

## §9 PER-AGENT DIRECTIVES + PROMPTS (paste one to each agent)

**Directive summary:** Chat = **CONTINUE**. Work = **CONTINUE**. Goose = **CONTINUE but RE-TARGET to ACP+WebView**. None need to stop; only Goose changes shape.

### A — Chat / AgentClone agent → CONTINUE
```
You own CHAT = the native Swift AgentClone (LocalPackages/AgentClone) mounted in
Epistemos/App/RootView.swift via AgentClone.ContentView(). Target: the deepest-native
Epistemos chat surface. Continue:
1. Finish the Osaurus removal so the APP TARGET COMPILES. Current blocker is package
   resolution on EventSource/AsyncHTTPClient C modules (CAsyncHTTPClient/CNIO*) after the
   osaurus purge — fix Package.resolved / resolve packages. Do NOT restore Osaurus to get a
   compile pass.
2. Keep the host-context bridge (vault/workspace/theme via AgentCloneBridge.updateHostContext)
   and the prompt handoff + buffer/recovery you built.
3. Keep Epistemos-native foreground naming. Deepen note/graph/vault context as TYPED
   attachments ONLY after the owner lifts isolation. Do NOT revive MiniChat/GraphChat/
   NoteChat/ChatView/Osaurus backends.
You are the INTERIM host for the Act route until the Goose-Act surface lands; do not try to
own Goose or Work. Guardrails: macOS 26.0; @Observable; no force-unwrap; Pro behind
#if !EPISTEMOS_APP_STORE. SHARED FILES (RootView.swift, AppBootstrap.swift, AppCoordinator.swift)
are edited by other lanes — coordinate/serialize edits there. Commit only inside your lane.
Proof gate: app builds; Chat mounts; prompt runs through the clone runner (not a parallel fake);
host context visible in side panel; recents persist to SDChat.
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
spawn). Commit inside your lane (clone has its own git). Proof gate: native Work (OpenGUI) + OpenGUI web
SPA both open with foreground "Epistemos Work" (no "OpenCode" leak); no-model OpenGUI probes pass; prompt
queue/permissions/recents/session-reopen pass; Work in shared recents.
```

### C — Goose / Act agent → CONTINUE but RE-TARGET (ACP transport + WebView UI)
```
You own ACT = Goose. RE-TARGET (owner decision 2026-06-25): integrate Goose as its WEB UI in a
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
rename protected Goose env/config/protocol/runtime names. Do UI work inside the clone's own git.
Proof gate: real Goose Electron launches as fallback; goose serve ACP WebSocket reachable; ACP client
completes new->prompt->stream(thinking/tool/answer)->permission->result; Goose web UI boots in WebView
via the narrow shim; nothing lost vs the real app.
```

---

## §10 What the OWNER should do right now (checkpoint sequence)

**You are NOT at risk of losing anything** — tracked changes are snapshotted to tag `wip-safety-main-20260625` and the 544 untracked files (incl. all of `Epistemos/Work/`) are archived at `/tmp/epistemos-untracked-safety-20260625.tgz`. Breathe.

**Do you need to wait? Per lane:**
1. **Work clone & Goose clone have their OWN git** → each can be committed *inside its own dir* the moment that agent pauses. Safe anytime, no waiting, no collision.
2. **Main worktree (the AgentClone + Work + docs pivot)** → the clean checkpoint is **ONE commit once the Chat/AgentClone agent gets the app target COMPILING** (fix the EventSource package blocker first). Committing before that captures a non-building state (recoverable, but messy). **So: wait for "app builds" from the AgentClone agent, then commit the whole pivot as the checkpoint.**
3. **The Work agent is already at a proven (tests-pass) point** — if you want a checkpoint sooner, you (or it) can stage just `Epistemos/Work/*` and commit that subset now; it's the safest subset.

**The real fix so 3 agents never clobber each other** (they currently share the main worktree; only Cursor is isolated): **give each agent its own `git worktree`** —
```
git worktree add ../Epistemos-chat   -b chat-agentclone
git worktree add ../Epistemos-work    -b work-opengui
git worktree add ../Epistemos-goose   -b act-goose
```
Then each commits independently; merge to `main` at proven checkpoints. This removes the `RootView.swift`/`AppBootstrap.swift` collision risk flagged in §8.

**Order of operations:** (a) hand each agent its §9 prompt + this doc; (b) AgentClone agent fixes the build blocker → you commit the main-worktree pivot; (c) move each agent into its own worktree; (d) Goose agent begins the ACP+WebView re-target; (e) checkpoint per lane at each green proof gate.

---

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
- Sources: Apple WWDC25 WebKit-for-SwiftUI / `WebPage` docs; Electron contextBridge/ipcRenderer/IPC tutorial; Agent Client Protocol (agentclientprotocol.com), Zed external-agents + ACP registry, JetBrains ACP, Goose ACP docs; local clones `.research-clones/work/{goose,opengui}`; repo `Epistemos/Work/*`, `LocalPackages/AgentClone`; canon `WORK_CANON_STATUS_2026_06_25.md`, `ACT_IP_PRESERVATION_2026_06_24.md`, `PRIVATE_TRI_SURFACE_…_2026_06_24.md`, federation handoff doc.
