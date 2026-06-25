# Surface Embedding — WebView vs Native Decision (single research doc)

**Started:** 2026-06-25 · **Owner question source:** `/Users/jojo/.codex/attachments/ab4fbb0d-28e8-4e34-911c-2c9332d8c3df/goal-objective.md`
**Status:** LIVING — research loop in progress (`/loop 2m`). This is the **one doc** for this research effort.

## ⚠️ Discipline rules for this doc (owner directive)
- **One doc, not a pile.** All research for this question lives here. Do not spawn parallel contradicting docs.
- **Replace, don't accumulate.** When new research supersedes an assumption or finds an inconsistency, **edit the existing claim in place** and note the supersession in §9 Research Log. Never leave two contradictory statements standing.
- **Ground every claim.** Mark each as `[VERIFIED-CODE]`, `[CANON: <doc>]`, `[WEB: <source>]`, or `[ASSUMPTION]`. Downgrade/upgrade as evidence arrives.
- **Priority = do not break Goose / OpenGUI / OpenCode.** Integrate carefully and strategically; preserve donor capability. The visible shell becomes Epistemos; the donor runtime spine stays intact.

---

## §0 The owner's actual question (distilled, not paraphrased away)

The owner wants **one Epistemos app** where Goose and OpenGUI/OpenCode feel like native parts of the app — not three separate products, not a "web app" feel — using **the newest macOS WebView APIs**, while **getting rid of the donors' own install/update systems** (everything is one Epistemos app). Reference point: **Craft** (feels deeply integrated/native, not like a web app).

Two options the owner is weighing, in their words:
- **Option A (the "easier" middle ground):** code Goose + OpenGUI so every surface *looks* like Epistemos and the API is deeply integrated, but each keeps its own runtime, embedded in WebViews. *"probably what I'm gonna do."*
- **Option B (the "hard" way):** truly study them so they are 100% working under **one all-native surface**. *"I want to do the [latter]… the hard thing"* — but *"any little mishap can make the whole thing break and I wanna prevent that… I'm anticipating that it will fail because it usually does."*

The Codex advice bundled in the objective recommends a **third framing (Option C):** one native `EpistemosSurfaceHost` shell + three content engines — Chat = native Swift, Act = Goose **WKWebView**, Work = OpenGUI **WKWebView** — bridged by an injected `window.epistemos` object via `WKScriptMessageHandler`. Explicitly: *do not attempt a one-shot native rewrite.*

**The job of this doc:** give a PROVEN, drift-resistant answer to "WebView-embed vs full-native," grounded in (1) what Epistemos code already does, (2) real macOS 26 WebView API facts, (3) the real donor architectures, (4) owner constraints.

---

## §1 Current ACTUAL architecture (ground truth, 2026-06-25)

This is what the **code already does today** — the most important anti-drift anchor, because the objective's advice was written without it. Source: `docs/WORK_CANON_STATUS_2026_06_25.md` (a verification ledger w/ xcresult proofs) + git log + two repo-survey passes. Items still needing direct code-seam reading are flagged `[CANON]` (verify in pillar work) vs `[VERIFIED-CODE]`.

| Surface | What it is TODAY | Embed mechanism | Runtime |
|---|---|---|---|
| **Chat / Act** | Embedded **`AgentClone`** — a Swift full-clone of the macOS-26 "Agent" app (254 files, `LocalPackages/AgentClone`). RootView mounts `AgentClone.ContentView()` for Chat/Act + injects Epistemos theme tokens. Landing `.act` → `AgentCloneBridge.submitPrompt(...)` via `epistemos.agentclone.*` notifications. `[CANON: WORK_CANON_STATUS §Act/AgentClone]` | **Swift package / SwiftUI-AppKit** (NOT WebView) | In-process Swift agent runtime (donor "Agent"/Swarm), bridged to Epistemos context/vault |
| **Work** | Native Epistemos Work chrome (`WorkEngineSurfaceView` / `WorkEngineSurfaceWindowController`, ⌘4) over the **OpenGUI** harness/runtime, **OpenCode-first**. WebView (`WorkWebSurfaceView`, loopback-HTTP SPA) kept ONLY as a **Settings preview fallback** until owner visual proof. `[CANON]` | **Native chrome + NDJSON-over-stdio sidecar**; WebView fallback = loopback HTTP | `opencode serve` subprocess (bundled `opencode` 1.17.9 + `bun` 1.3.14 in `Contents/Resources`), `Pro`/`#if !EPISTEMOS_APP_STORE` |
| **Goose** | Maintained, **reskinned clone** (`.research-clones/work/goose`, Electron/React UI + Rust `goose` crate). Foreground rebranded to "Epistemos"; nav/recipes/skills/extensions intact; 21 Vitest + Rust tests passing. **Not the live Act surface.** Live wiring **deferred** (was "fuse into Work / Phase-K-deferred"; 06-24 tri-surface doc maps it to Act, but Act shipped as AgentClone instead). `[CANON]` | TBD (clone only) | Rust `goose` + Electron renderer + `goosed` |

**Key takeaways for the decision:**
1. Epistemos has **already chosen native-Swift embedding for Chat/Act** (AgentClone), not WebView. So Codex's "Act = Goose WebView" conflicts with shipped reality.
2. Epistemos has **already chosen native-chrome + subprocess for Work** (OpenGUI/OpenCode), with WebView demoted to a *fallback*. So "Work = OpenGUI WebView as primary" also conflicts with shipped reality.
3. The **proven WebView bridge pattern already exists in-repo** (Epdoc/Tiptap: `WKScriptMessageHandler` named `epdoc`, custom URL scheme, `.atDocumentStart` theme injection, `WKWebsiteDataStore.nonPersistent()`). The loopback-HTTP Work SPA fallback also already works. So a WebView surface is *cheap to stand up* here — the question is whether it should be primary.
4. **No-hidden-sidecar / MAS:** subprocess spawning (OpenCode/Bun, goosed) is **Pro-only** (`#if !EPISTEMOS_APP_STORE`); the MAS build cannot spawn them. Any "embed the running donor" plan must answer the MAS path separately.

---

## §2 Reconciliation of the historical drift (which target map is current?)

The owner's anxiety is justified: there are **four** target maps in the canon. Resolving them is half the value of this doc.

| Map | Chat | Act | Work | Status |
|---|---|---|---|---|
| **A** (06-21) | Epistemos-native | **Osaurus** | OpenCode | **SUPERSEDED.** Osaurus bridge deleted; OpenCode beat Goose in the Work bake-off (`OPENCODE_VS_GOOSE_WORK_ENGINE_2026_06_21.md`). |
| **B** (06-24 `PRIVATE_TRI_SURFACE`) | Swift full-clone | **Goose** full-clone | **OpenGUI** full-clone | **PARTIALLY CURRENT.** Work=OpenGUI is live. Act=Goose is *not* live. Carries owner "isolation-first" correction (below). |
| **C** (06-24 `ACT_IP_PRESERVATION` lock `dd93a2f53` + actual 06-25 code) | AgentClone (Swift) | **AgentClone (Swift)**, native engine; Osaurus removed | OpenCode/OpenGUI | **CURRENT / SHIPPING.** |
| **D** (Codex advice in the objective) | Swift native | **Goose WKWebView** | **OpenGUI WKWebView** | **PROPOSAL under evaluation by this doc.** Conflicts with C on Act mechanism + Work-primary. |

**Current shipping truth = Map C.** Map D (the objective's advice) is a *proposal* that would partly revert C (move Act from Swift-embed back to Goose-WebView, and promote the Work WebView from fallback to primary).

**The binding owner correction that shapes everything** (`PRIVATE_TRI_SURFACE_UNIFICATION_CONTROL_PLANE_2026_06_24.md`, "Isolation First", which **overrides** older "fuse settings into Epistemos" language):
> Do **not** fuse Goose into OpenGUI now. Do **not** make donor settings part of Epistemos Settings now. Keep each donor's settings/config/provider/extension pages **isolated in its own shell** for now. Epistemos provides outer chrome, landing toggles, theme tokens, launch routing, window framing, visual reskinning, health links. **Sequence: (1) reskin each donor's isolated UI to OpenCode-minimal, (2) embed those isolated surfaces in the Epistemos home window, (3) LATER selectively connect settings/features back through explicit probes.**

This is decisive: the owner has **already endorsed "embed the donor's own (reskinned) surface, bridge later"** — which is the *spirit* of Codex's Option C, but the *mechanism* (WebView vs Swift-embed vs subprocess+chrome) is per-donor and is exactly what the pillars below must settle.

---

## §3 The core decision, framed honestly

The real choice is **not** binary "all WebView vs all native." Current code already proves a **per-surface mechanism mix** is the stable answer. The decision reduces to, for each donor, picking the *least-drift* embed mechanism among:

1. **Native Swift package embed** (like AgentClone today) — best fidelity/perf; only viable when the donor is Swift (Agent/Swarm). Not applicable to Goose (Electron) or OpenGUI (TS/web) without a rewrite the owner explicitly forbids ("no blanket SwiftUI rewrite").
2. **WKWebView embed of the donor's web UI** (like Epdoc; like the Work SPA fallback) — donor renderer runs as-is inside a `WKWebView`, themed + bridged via `WKScriptMessageHandler`. Best for web/Electron-renderer donors *if* their UI can run against a reachable backend.
3. **Native chrome + subprocess runtime** (like Work today) — Epistemos draws the UI natively, the donor runs as a headless sidecar over a local protocol. Highest fidelity + MAS-incompatible (Pro-only).

The owner wants Option B (full-native) emotionally but fears breakage. **The evidence-based reframing:** "native feel" is achievable through **shell ownership + theme + bridge + state authority** *without* rewriting donor runtimes (`PRIVATE_TRI_SURFACE` "Scene-Safe Native Strategy": replace the *scene*, not the *state machine/parser/worker/protocol*). That is how you get Craft-like "doesn't feel like a web app" **without** the Option-B breakage risk. The pillars quantify this per donor.

---

## §4 Owner / platform constraints that bound any answer

- `[CANON: CLAUDE.md]` **NO HIDDEN SIDECAR on MAS path.** Subprocess inference/orchestration is Pro-only. MAS build cannot spawn `opencode`/`bun`/`goosed`. → A WebView surface that needs a running donor backend is **Pro-gated** unless the backend is reachable without spawning.
- `[CANON: CLAUDE.md / memory app_native_by_embedding]` **Vendor the REAL source, never wrap-and-shell.** Donors are full-cloned (`.research-clones/`, `LocalPackages/`), not shelled to external binaries. Pro/dev-gate if un-sandboxable, but still embed.
- `[CANON: WORK_CANON_STATUS Naming Law]` **Protected names** (do NOT rename): `OpenGUI`, `OpenCode`, `OpenWork`, `Goose`, `opencode.json`, `EPISTEMOS_WORK_OPENCODE_V0`, `EPISTEMOS_WORK_GOOSE_V0`, `OPENGUI_OPENCODE_PORT`, harness ids, etc. Foreground copy says "Epistemos Work/Act"; donor names survive in pickers/diagnostics/contracts.
- `[CANON: PRIVATE_TRI_SURFACE]` **Isolation-first.** Reskin + embed each donor's own shell now; do NOT collapse donor settings into Epistemos Settings yet; connect later via explicit probed seams. **Preserve capability; prune only by classification** (canonicalize / rebrand / fuse / automate / advanced / debug / alias / remove-with-evidence).
- `[CANON: PRIVATE_TRI_SURFACE]` **No hidden success.** "Ready/green" means the capability is *invokable from Epistemos with a witness*, not that donor files exist on disk (Settings Truth Floor).
- `[CANON: CLAUDE.md]` **Use @Observable, background-actor inference, no force-unwrap, `// SAFETY:` on unsafe, DispatchQueue.main.async (never .sync) in UniFFI callbacks.**

---

## §5 Research pillars (the loop's backbone — fill one per iteration, mark done)

> Each pillar has a precise question + acceptance bar. CLAUDE.md mandates **web validation for current API/OS/package facts** with primary/official sources. Update §1–§6 in place as pillars resolve.

- [x] **P1 — macOS 26 WebView API truth — RESOLVED 2026-06-25.** ✅ **Verdict: classic `WKWebView` via `NSViewRepresentable` (see §6.1).** Compare, with primary Apple sources: (a) classic `WKWebView` (AppKit/`NSViewRepresentable`), (b) the SwiftUI **`WebView` + `WebPage`** API introduced at WWDC25 (macOS 26 "Tahoe"), (c) what the owner used in 2025. Which is the right host for embedding a complex donor SPA in 2026? Questions to answer: Does the new SwiftUI `WebView`/`WebPage` support the message-handler bridge + user-script injection we rely on, or is `WKWebView` still required for `WKScriptMessageHandler` / `WKUserScript` / custom URL schemes? Min macOS deployment target impact? Verdict + citation. **Acceptance:** a recommendation ("use X for the donor surfaces because Y") with ≥2 official Apple citations, written into §6.
- [ ] **P2 — Goose (Electron/React) embed feasibility.** Goose desktop = Electron + React renderer + preload/IPC (`window.electron`, contextBridge) + Rust `goosed`/ACP/REST backend. Determine: can the Goose **renderer** run inside a `WKWebView` (which has NO Electron `ipcRenderer`/preload)? What preload/IPC APIs does it call, and can a `WKScriptMessageHandler` shim satisfy them? Does Goose expose a **REST/ACP** mode that a web UI can talk to *without* Electron (the `CUSTOM_DISTROS.md` REST/ACP path)? MAS implication of `goosed`. **Acceptance:** a "Goose embed mechanism" verdict (WebView-shim / native-chrome-over-ACP / keep-Electron-window-reparented / defer) with the concrete blocker list, into §6 + the table in §1.
- [ ] **P3 — OpenGUI/OpenCode embed feasibility.** OpenGUI = TS runtime/backend/frontend split (ADR 0005: `@opengui/runtime` in-process SDK; backend = queue + HTTP/WS/SSE + token auth). Confirm the **current** Work wiring (native chrome over NDJSON sidecar) vs the WebView SPA fallback: which is more robust, and is the WebView path viable on MAS (loopback HTTP needs a server = subprocess = Pro)? **Acceptance:** confirm/curate §1 Work row with `[VERIFIED-CODE]` from `WorkEngineSurfaceView.swift` / `WorkOpenGUISupervisor.swift` / `WorkWebSurfaceView.swift`; state whether WebView should ever be promoted from fallback.
- [ ] **P4 — The Epistemos bridge.** Map Codex's proposed `window.epistemos` API (`getContextSnapshot/createSession/postAgentEvent/requestTool/requestApproval/searchVault/note CRUD/getGraphContext/listSkills/runSkill`) onto what ALREADY exists: the Epdoc `WKScriptMessageHandler` batch-envelope pattern, the Work `epistemos-native` MCP surface (`epistemos.context.snapshot`, `WorkAppContextSnapshot`), `AgentCloneBridge`. **Acceptance:** a single bridge contract table (method → existing impl or "to build" → MAS-safe?), into a new §7.
- [ ] **P5 — Strip / keep per surface.** Apply the `PRIVATE_TRI_SURFACE` pruning classifier (canonicalize/rebrand/fuse/automate/advanced/debug/alias/remove) to: standalone product shell, donor branding, duplicate landing, **updater/install ownership**, blocking onboarding, top-level chrome. **Acceptance:** a per-donor strip/keep list, into §8.
- [ ] **P6 — Install/update system removal (single-app ownership).** The owner explicitly wants donor install/update systems GONE. Inventory them: Goose updater (`GOOSE_BUNDLE_NAME`/`GITHUB_OWNER`/`GITHUB_REPO`, Electron autoUpdater), OpenCode/Bun self-update, npm/pnpm runtime fetches. For each: how it's disabled and replaced by Epistemos' single bundling (MAS forbids runtime npm/subprocess; bundle at build time). **Acceptance:** kill-list + replacement into §8, with MAS-safety note each.
- [x] **P7 — Reference apps — RESOLVED 2026-06-25.** ✅ **Craft = Catalyst/custom-drawn (not WebView); native feel = subtraction + local-first → checklist in §6.2.** How do apps that embed web/runtime UIs feel native? Study **Craft** (the owner's reference) + others (Linear, Notion, VS Code/Electron-but-feels-native, Warp, Raycast). What specifically makes Craft *not* feel like a web app (native chrome? native window mgmt? typography? no browser affordances?). Extract concrete techniques. **Acceptance:** a short "native-feel checklist" into §6.

---

## §6 Working recommendation (PRELIMINARY — will firm up as P1–P7 land)

> Confidence: medium. Grounded in shipped code + owner corrections; pending web validation (P1, P7) and code-seam verification (P2–P4).

**Do NOT do "all WebView" and do NOT do "all native rewrite."** Both are the failure modes the owner fears. Keep the **per-surface mechanism mix that is already shipping and proven**, and reach "native feel" through shell+theme+bridge, not rewrites:

- **Chat/Act → keep native Swift embed (AgentClone).** It already works, it's the highest-fidelity option, and the donor is Swift so no WebView is needed. *Do not* revert Act to Goose-WebView (Codex Map D) — that's a regression from shipping Map C. (Pending P2: decide whether Goose becomes a *separate* future surface or is retired in favor of AgentClone for Act.)
- **Work → keep native chrome over the OpenGUI/OpenCode sidecar (Pro); keep the WKWebView SPA as the MAS-safe / fallback surface.** This is the strongest path for a multi-harness coding runtime. Promote WebView to primary only if P1/P3 show the native chrome can't keep parity. The loopback-HTTP SPA already works and is the template for any other web-donor surface.
- **WebView, when used, uses classic `WKWebView` via `NSViewRepresentable`** (the in-repo Epdoc pattern: `WKScriptMessageHandler` + custom URL scheme + `.atDocumentStart` theme injection + `nonPersistent` store). **P1 resolved this (§6.1):** the new SwiftUI `WebView`/`WebPage` is capability-equivalent for the bridge but gates to **macOS 26.0-only** with no bridge advantage, so `WKWebView` wins on back-deployment + first-class bridge APIs + existing-repo precedent.
- **Native feel (the Craft goal) comes from:** Epistemos owns the window chrome / titlebar / landing / mode picker / command palette / recents / settings presentation / theme tokens / typography; the donor renders only its *content* scene; no browser affordances (no URL bar, no web context menu, `nonPersistent` store, no donor product chrome). Donor runtime/protocol/state machine stays intact underneath (Scene-Safe Native Strategy). **P7 sharpened this into a concrete checklist — §6.2.**
- **Single-app consolidation:** strip donor updaters/installers (P6); bundle all runtimes at build time into `Contents/Resources` (already done for `opencode`+`bun`); MAS build never spawns — so any surface that *requires* a spawned backend is Pro-gated, and the MAS equivalent is either the native-Swift path (Act) or a no-spawn-needed mode.

**The honest answer to "can I still do this?":** Yes — and you're *already doing it*, more robustly than the WebView-everything plan. The shipping architecture (native Swift Act + native-chrome/subprocess Work + proven WebView fallback) is closer to your "hard/native" wish than Option A, **without** the all-or-nothing breakage of a full Option-B rewrite. The remaining work is finishing the bridge (P4) and the strip/consolidation (P5/P6), not re-architecting.

---

### §6.1 macOS WebView API verdict (P1 — resolved, primary Apple sources)

Answers the owner's "WebKit WebView vs newest 2026 WebView vs the 2025 one." Both APIs expose the **full bridge** we depend on; the choice is **deployment target, not capability**.

| | New SwiftUI `WebView` + `WebPage` (WWDC25 "WebKit for SwiftUI") | Classic `WKWebView` (`NSViewRepresentable`) |
|---|---|---|
| **Min OS** | **macOS 26.0+ ONLY** (hard floor across the whole API) | **macOS 10.10+**, not deprecated in 2026 |
| JS→native messages | ✅ via reused `WKUserContentController` (`add(_:name:)`, `window.webkit.messageHandlers`) | ✅ first-class `WKScriptMessageHandler` |
| User script @ documentStart | ✅ (same reused controller, `addUserScript`) | ✅ `WKUserScript` + `.atDocumentStart` |
| Custom URL scheme (serve bundle) | ✅ new `urlSchemeHandlers: [URLScheme: URLSchemeHandler]` dict | ✅ `setURLSchemeHandler(_:forURLScheme:)` |
| Native→JS + non-persistent store | ✅ `callJavaScript`, `WKWebsiteDataStore.nonPersistent()` | ✅ `evaluateJavaScript`/`callAsyncJavaScript`, `.nonPersistent()` |

**Verdict: ship classic `WKWebView` via `NSViewRepresentable`.** It back-deploys (the new API would drop every pre-Tahoe user), exposes the bridge through **dedicated, well-trodden** APIs (not indirection), and **matches what the repo already does** (`EpdocEditorChromeView` + shared `processPool` + `.nonPersistent()`). The new SwiftUI API has **no bridge advantage** for our needs — adopt it later only if/when the app hard-requires macOS 26+. *(The 2025 community belief that the new API "lacks a JS message bridge" is a misread — the bridge is reached via the reused `WKUserContentController`.)* Citations: `developer.apple.com/documentation/webkit/webkit-for-swiftui`, `/webpage`, `/webpage/configuration/urlschemehandlers`, `/wkwebview`, `/wkscriptmessagehandler`, `/wkwebviewconfiguration/seturlschemehandler(_:forurlscheme:)`.

### §6.2 Native-feel checklist (P7 — resolved)

**The lesson from Craft:** Craft is **Mac Catalyst (UIKit) + a custom-drawn "everything is a canvas"** app, **not** a WebView/Electron app (its *new* "Craft Agents" feature is Electron, but the core is native). Its native feel comes from **owning the render path + killing every browser/stock-control tell + obsessing over transition perf** — not from the stack. Corroboration that **native feel ≠ native stack**: Raycast renders React → AppKit (no HTML), Cron/Notion-Calendar is Electron yet feels native. So a `WKWebView` donor surface *can* read as native if we do the work below. Native feel is mostly **subtraction + local-first**.

**Highest-impact (do these first):**
1. **Kill the network from the UI path** — local-first/optimistic, **no spinners**; warm-resident WebView for instant first paint (extend the repo's shared `processPool`). This separates "instant app" from "web in a window" more than any chrome trick.
2. **Native window chrome** — real macOS traffic lights over full-bleed content; never a CSS title bar.
3. **Strip browser tells on the NATIVE side** (so donor CSS can't fight it): disable the web context menu, pinch/magnification zoom, and overscroll rubber-band; `windowOcclusionDetectionEnabled = false` (Raycast's fix to stop WebKit throttling backgrounded views).
4. **Inject look-and-feel via `WKUserScript` @ `.atDocumentStart`:** font stack, scrollbar stripping (`::-webkit-scrollbar`), `cursor:default`, `-webkit-font-smoothing:antialiased`, `overscroll-behavior:none`, and `:root{color-scheme:light dark}` (dark mode then auto-maps from `effectiveAppearance` — **no Swift bridge needed**). **Accent color is the one exception** — read `NSColor.controlAccentColor` and set a CSS custom property.
5. **Native menus + command palette + global hotkey**; native sheets/popovers instead of HTML modals; native drag-out to Finder.
6. **Vibrancy = 3 layers:** `NSVisualEffectView` behind + clear `underPageBackgroundColor` (public, macOS 12+) + transparent CSS `body`.

**WKWebView-specific gotchas:**
- `-webkit-app-region: drag` does **NOT** work in WKWebView (Electron/Chromium-only). For a draggable custom titlebar zone, use a transparent `NSView` overlay returning `mouseDownCanMoveWindow = true`, with `hitTest(_:) → nil` over interactive regions.
- macOS WKWebView has no `scrollView` bounce toggle — kill bounce via CSS `overscroll-behavior:none`, not the iOS path.

**Split-enforcement rule (matters because our donors are a third-party React SPA + an Electron renderer):** do **affordance removal** (context menu, overscroll, magnification) **natively** so it holds regardless of donor code; inject **look-and-feel overrides** via the `.atDocumentStart` user script. Sources: Pragmatic Engineer (Craft architecture), Raycast engineering posts (native shell over WebKit), Linear `performance.dev` (local-first / no spinners).

## §7 Bridge contract (filled by P4)
_TBD._

## §8 Strip / keep + install-update kill-list (filled by P5/P6)
_TBD._

## §9 Research log (supersession trail — append one line per change)
- 2026-06-25 — Doc created. Established current truth = Map C (native Swift Act via AgentClone; native-chrome+subprocess Work via OpenGUI/OpenCode; Goose = reskinned clone, live wiring deferred). Marked Codex objective advice = Map D (proposal), conflicts with shipping C on Act mechanism + Work-primary. Source: `WORK_CANON_STATUS_2026_06_25.md`, `PRIVATE_TRI_SURFACE_..._2026_06_24.md`, `ACT_IP_PRESERVATION_2026_06_24.md`, git log, 2× repo survey. Pillars P1–P7 defined. P1 (macOS 26 WebView API) + P7 (Craft/reference) flagged NEEDS WEB.
- 2026-06-25 — **P1 RESOLVED.** Verdict = classic `WKWebView` via `NSViewRepresentable` (§6.1). New SwiftUI `WebView`/`WebPage` = macOS-26.0-only, capability-equivalent bridge but no advantage; `WKWebView` back-deploys + first-class + matches repo. Source: Apple DocC (`webkit-for-swiftui`, `webpage`, `wkwebview`, `wkscriptmessagehandler`, `seturlschemehandler`). Supersedes the §6 "default to WKWebView until P1 proves…" placeholder.
- 2026-06-25 — **P7 RESOLVED.** Craft = Mac Catalyst/custom-drawn canvas, NOT WebView/Electron (its new Agents feature is Electron). Native feel ≠ native stack (Raycast React→AppKit; Cron Electron). Added native-feel checklist (§6.2): subtraction + local-first; native-side affordance removal + `.atDocumentStart` look-and-feel injection. Source: Pragmatic Engineer (Craft), Raycast eng, Linear performance.dev.
