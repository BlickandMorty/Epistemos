---
id: 876B89DE-72D1-4DF0-8467-22A5F3CDB902
title: OpenCode Full-Clone Feasibility — Work-Mode Shell (2026-06-21)
---

# OpenCode Full-Clone Feasibility — Work-Mode Shell (2026-06-21)

**Owner DECISION being studied (verbatim, addendum** `docs/OSAURUS_P3_IMPORT_PLAN_2026_06_21_addendum.md:101-115`**):**  
Fully clone OpenCode as the **WORK-MODE SHELL** of the app — themed to the app's  
pixel-art native look — with **Goose as an engine INSIDE it**, and the owner's  
**IP brain wired in**. Owner is **lenient on Swift/Rust purity** for this. **MAS is**  
**NOT a hard constraint** (app ships notarized direct-distribution, non-sandboxed).

**ANTI-HALLUCINATION.** Every web claim is labeled **[verified web]** (primary/  
official: the GitHub repo, opencode.ai docs, deepwiki, or an OpenCode engineer's  
post) or **[inferred]** (my reasoning over verified facts; not invented). In-repo  
claims cite the file. The convergence research  
(`docs/research/AGENT_STACK_CONVERGENCE_RESEARCH_2026_06_21.md`) and the addendum are  
the standing authority; this doc is the deep-dive the addendum §113 asked for.  
Memory: "PLAN_V2 is authority; fix code to match plan, not the reverse."

---

## 1. WHAT OPENCODE ACTUALLY IS (grounded/cited)

### 1.1 One repo, one engine, MANY front-ends over a headless server

OpenCode (`github.com/sst/opencode`, by SST / Anomaly Innovations) is **MIT-licensed**,  
**TypeScript on the Bun runtime**, a Turbo-orchestrated monorepo. **[verified web]**  
(GitHub repo lists TypeScript ~69%, `bun.lock`/`bunfig.toml`; latest release v1.17.x,  
2026-06-21.)

The defining architectural fact: **OpenCode is a headless client/server system, not a**  
**single UI app.** **[verified web — opencode.ai/docs/server]**

- **Server**: `opencode serve` starts a persistent local **HTTP server** (default  
`127.0.0.1:4096`), built on the **Hono** web framework on Bun. It exposes a  
**headless OpenAPI 3.1** surface published at `/doc`, plus a **Server-Sent Events**  
**(SSE)** stream for global + session-level events. Optional mDNS discovery, CORS  
origins, and HTTP basic auth (`OPENCODE_SERVER_PASSWORD`/`_USERNAME`).  
**[verified web]** Session state persists via **Drizzle ORM**; the agent turn loop is  
`SessionPrompt.loop()`. **[verified web — deepwiki]**
- **Endpoints** group into: **Sessions** (create/list/fork/share), **Messages**  
(send prompt/list history), **Projects &amp; VCS**, **Configuration** (providers/models),  
**Files** (search/read/tracked-status), **Agents &amp; Tools** (list agents, tool  
schemas), **Infrastructure** (LSP servers, formatters, MCP management).  
**[verified web — opencode.ai/docs/server]**
- **SDK**: the OpenAPI spec auto-generates a typed client; an official JS/TS SDK  
(`@opencode-ai/sdk`) ships. *"Running* `opencode serve` *standalone creates a*  
*production-ready backend … the architecture supports custom frontend*  
*implementations."* **[verified web — opencode.ai/docs/server]** This is the single  
most important fact for this study: **any front-end — including a native SwiftUI one**  
**— can drive the same engine over HTTP/SSE.**

### 1.2 The UI is NOT native — it is terminal cells OR web tech. (Two front-ends.)

This is the load-bearing finding for theming. OpenCode has **two official UIs, neither**  
**of which is AppKit/SwiftUI**:

1. **Terminal TUI** (the default, flagship surface). Originally **Go + Bubble Tea**  
 (Elm-style model/update/view); **as of v1.0 it was rewritten onto OpenTUI**, SST/  
 Anomaly's in-house **TypeScript TUI framework with a native Zig rendering core**.  
 **[verified web — opentui.com, anomalyco/opentui, grokipedia/OpenTUI]** It renders  
 **into a terminal grid** (truecolor cells), not into native views.
2. **Desktop app (BETA)**. A web-tech GUI. **It is mid-migration from Tauri 2 (Rust +**  
 **WebView) to Electron (Chromium + Node).** The OpenCode engineer **Brendonovich**  
 wrote the migration post: Tauri's **WebKit on macOS gave worse rendering perf and**  
 **style inconsistencies** vs Chromium, and bundling the Bun CLI hurt startup, so they  
 moved to **Electron with the server running in Electron's Node process**.  
 **[verified web — dev.to/brendonovich/moving-opencode-desktop-to-electron, author is**  
 **OpenCode team]** The frontend is a web framework (**SolidJS**, `@opencode-ai/app`),  
 communicating with the server over HTTP+SSE via the SDK. **[verified web — deepwiki]**

**So "OpenCode's UI" = either (a) a terminal-cell TUI (OpenTUI/Zig) or (b) an HTML/CSS/**  
**JS web app (SolidJS) inside a browser shell (Tauri/Electron).** There is no native  
macOS view layer anywhere in OpenCode. **[verified web]** Keep this fact front-of-mind  
for §4.

### 1.3 Providers, LSP, plugins, agents

- **Providers**: 75+, via the **Vercel AI SDK** + **Models.dev** catalog  
(`@ai-sdk/anthropic`, `@ai-sdk/openai`, `@ai-sdk/amazon-bedrock`, local via Ollama),  
plus managed "OpenCode Zen". **[verified web]**
- **LSP-for-agents**: auto-loads **40+ language servers** and feeds the agent  
diagnostics, hover, symbols, go-to-definition, find-references, call-hierarchy — *no*  
*manual wiring*. **[verified web — deepwiki 5.4]** This is its headline differentiator.
- **Plugins**: `@opencode-ai/plugin`, schemas via **Zod + Effect**. **[verified web]**
- **Agents**: built-in **build** (full-access) + **plan** (read-only); **subagents**  
are invoked by `@mention`, and **delegation creates a CHILD SESSION with fresh**  
**context + scoped instruction + structured result** — *"session-based, resumable,*  
*inspectable."* **Multi-session**: multiple parallel agent sessions on one project.  
**[verified web]**
- **Undo/redo**: `/undo` `/redo` revert AI edits **without Git**. **[verified web]**
- **Session sharing**: explicit opt-in share links. **[verified web]**

---

## 2. ITS REAL CAPABILITY EDGE over Osaurus / Goose (concrete, not vibes)

What OpenCode concretely does that the other two do not:


| Capability                                                                                       | OpenCode                            | Osaurus (act)                                                             | Goose (work)                                                      |
| ------------------------------------------------------------------------------------------------ | ----------------------------------- | ------------------------------------------------------------------------- | ----------------------------------------------------------------- |
| **LSP-for-agents, 40+ servers auto-loaded** into the loop (diagnostics/defs/refs/call-hierarchy) | ✅ headline                          | ❌ (none)                                                                  | ❌ (none)                                                          |
| **Headless server + OpenAPI 3.1 + typed SDK** → swappable front-ends                             | ✅ (the whole shape)                 | ⚠️ has a loopback `LocalModelServer`, not a full multi-client OpenAPI app | ⚠️ `goose-server` exists but Electron desktop is the only rich UI |
| **Session forking + explicit share links**                                                       | ✅                                   | ⚠️ session export                                                         | ⚠️ sessions, no share-link                                        |
| **Multi parallel agent sessions on one project**                                                 | ✅ (called out as unique among CLIs) | ❌                                                                         | ⚠️ subagents, less surfaced                                       |
| **/undo /redo of AI edits without Git**                                                          | ✅                                   | ❌                                                                         | ⚠️ git-based                                                      |
| **Mature, polished WORK UX** (TUI + desktop, 948 contributors, 826 releases)                     | ✅                                   | n/a (act, not a code-work IDE)                                            | ⚠️ Electron desktop, less code-IDE-shaped                         |
| **Subagent delegation = child session, inspectable**                                             | ✅                                   | ⚠️                                                                        | ✅ (`Agent::new()`+`TaskConfig` — Goose's own strength)            |


**The honest edge** (verified): OpenCode's differentiators are **(1) LSP-for-agents**,  
**(2) the headless-server/typed-SDK multi-client architecture**, **(3) the polished**  
**work-IDE UX with multi-session/undo/share**. **[verified web]**

**Critical caveat for the owner.** Two of those three edges Epistemos **can capture**  
**without cloning OpenCode**:

- LSP-for-agents → Epistemos **already has an in-process Rust LSP runtime**  
(`agent_core/src/lsp_runtime/mod.rs`: `LspKernel`, tree-sitter Rust/Swift, FFI  
`lsp_send_message_json`; CLAUDE.md "Swift LSP (V2.3)"). The lift is *wiring its*  
*diagnostics into the work loop as tools* — not importing OpenCode. **[in-repo]**
- Headless-server/one-composer shape → already the owner's stated intent (addendum  
§24-29 "every surface wired to one shared composer/engine"). **[in-repo]**

The edge that is **genuinely OpenCode-only and hard to replicate** is **#3: the**  
**polished, battle-tested WORK UX itself** (multi-session, undo/redo, fork/share, the  
whole code-IDE flow), backed by years of contributor polish. *That* is what the owner  
is really buying when he says "more capable" and "loves the UI/UX." **[inferred, from**  
**verified feature set + owner's stated reason]**

---

## 3. THREE INTEGRATION OPTIONS

For each: how Goose lives inside, how the IP brain wires, theming/native-feel reality,  
MAS/notarization/runtime-bundling, maintenance (upstream tracking), risk.

### OPTION A — Embed OpenCode AS-IS (bundle Bun/Node; run in-app; theme its UI)

**Shape.** Ship the OpenCode server (Bun or, post-migration, Node) **inside the .app**  
**bundle**; on launch, spawn `opencode serve` on loopback; embed its UI — either the  
**OpenTUI terminal** in a terminal view, or the **SolidJS web UI in a WKWebView/embedded**  
**Chromium** — as the Work-mode surface. Theme via OpenCode's JSON themes (TUI) or CSS  
(web).

- **Goose inside.** OpenCode's engine is its *own* TS agent loop (`SessionPrompt.loop()`).  
"Goose inside" means **registering Goose as a provider/tool/MCP-server that OpenCode**  
**calls**, OR running Goose's `goose-server` and bridging — i.e. Goose becomes a  
delegated executor reachable from OpenCode's loop. It does **not** replace OpenCode's  
loop. **[inferred]** This is awkward: you'd run **two agent loops** (OpenCode's TS +  
Goose's Rust), violating "ONE agent-loop of record" unless one is demoted to a tool.
- **IP brain wires** via OpenCode's **plugin system** (`@opencode-ai/plugin`, Zod/Effect)  
and/or **MCP** — the brain (Eidos citation, vault tools, honesty gating, DAG,  
provenance) would have to be **re-exposed as TS plugins / MCP tools** reachable from  
OpenCode's loop. The Rust/Swift brain stays in-process; OpenCode reaches it over a  
local bridge (MCP/HTTP). **[inferred]**
- **Theming / native-feel.** TUI: only terminal-cell theming (JSON: hex/ANSI, diff,  
markdown, syntax) — **truecolor cells in a terminal, never AppKit controls.** Web UI:  
full CSS restyle is possible, but it is **Chromium/WebView-rendered HTML — it will**  
**feel like a themed web app, not a native pixel-art macOS app.** **[verified web →**  
**inferred conclusion]** See §4.
- **MAS / notarization / runtime-bundling.** MAS is off the table anyway, BUT: bundling  
**Bun or Node + spawning** `opencode serve` is a **hot-path subprocess / sidecar** —  
squarely the thing CLAUDE.md's **NO-HIDDEN-SIDECAR** non-negotiable forbids on the  
product path. Notarization *can* sign a bundled runtime + hardened-runtime exception,  
but you now ship a ~80-150 MB Node/Bun + node_modules (and, if web UI, Electron's  
Chromium ~150 MB+) inside the app, with its own auto-update + CVE surface. **[inferred**  
**from CLAUDE.md + Electron/Node footprint facts]**
- **Maintenance.** OpenCode ships **826 releases** and is **actively re-architecting**  
(Go→OpenTUI, Tauri→Electron, Bun→Node *all within recent history*). Tracking upstream  
on a fork is a **standing, heavy** burden. **[verified web]**
- **Risk.** HIGH. Two agent loops, a forbidden-style sidecar runtime, a moving-target  
upstream, and the native-feel is the *weakest* of the three. The "full clone" reads  
maximal but delivers the **least native** result and the **most architectural**  
**conflict** with the in-process doctrine.

### OPTION B — Rebuild OpenCode's best UX NATIVELY in SwiftUI, driven by Goose/your engine (no Bun)

**Shape.** Don't ship any OpenCode code. **Re-implement the work-IDE UX** (multi-session  
sidebar, diff/undo/redo, file tree + LSP diagnostics inline, share/fork affordances,  
the agent transcript) as **native pixel-art SwiftUI**, driven by **Goose (Rust,**  
**in-process via UniFFI)** as the work engine + the existing `lsp_runtime` for code  
intelligence + the IP brain on top.

- **Goose inside.** Goose **is** the engine — exactly the convergence plan's "work =  
Goose (Rust, in-process)." UniFFI → `GooseWorkBackend` (`Epistemos/Work/WorkBackend.swift`  
already has the seam: protocol + `InertWorkBackend` + `GooseWorkBackend` growth point,  
no silent fallback). **[in-repo]**
- **IP brain wires** the cleanest of all three: the brain stays the in-process  
Swift+Rust layer (`LocalAgentLoop` + `agent_core::agent_runtime`) **above** the Goose  
engine — same "brain on top, engine below the closure" pattern already used for Act/  
Osaurus. **[in-repo, convergence research §2]**
- **Theming / native-feel.** **Perfect** — it *is* native SwiftUI, so pixel-art chrome  
is first-class, matches every other Epistemos surface, reuses the shared composer  
(addendum §46-48). **[inferred — trivially true since it's native]**
- **MAS / sidecar.** Zero Bun/Node/Electron. Fully in-process. **Honors NO-SIDECAR.**  
Notarization trivial. **[inferred from CLAUDE.md]**
- **Maintenance.** No OpenCode upstream to track at all. You track **Goose** (already  
being vendored leaf-first) + your own UI. **[inferred]**
- **Risk.** MEDIUM, but **front-loaded effort**: you must *build* the work-IDE UX  
(multi-session, diff/undo, LSP-inline) that OpenCode gives for free. This is real  
SwiftUI work — but it is the work you'd eventually do anyway to make Work feel native,  
and it reuses the existing Note-editor/diff/LSP machinery. The risk is **scope/time**,  
not architecture. **Does NOT honor the literal "full clone OpenCode" instruction** —  
it captures OpenCode's *UX ideas* and *capability edge*, not its code.

### OPTION C — HYBRID: native SwiftUI shell wrapping OpenCode's ENGINE/core (headless server), native UI

**Shape.** Run OpenCode **headless only** (`opencode serve`, no OpenCode UI at all), and  
build a **native pixel-art SwiftUI front-end** that drives it over **HTTP + SSE** using  
a Swift client generated from / written against its **OpenAPI 3.1** spec. OpenCode is  
the *work engine*; the UI is 100% native; OpenCode's own TUI/web UI is never shipped.

- **Goose inside.** Two sub-variants:
  - **C1 (OpenCode engine of record):** OpenCode's loop is the work engine; **Goose**  
  **runs as a provider/MCP-tool/subagent that OpenCode delegates to** ("Goose inside  
  OpenCode," literally honoring the owner's words). The native UI talks only to  
  OpenCode's API; OpenCode talks to Goose. **[inferred — supported by OpenCode's**  
  **provider+MCP+subagent model, verified web]**
  - **C2 (Goose engine of record, OpenCode for LSP/session services):** keep Goose as  
  the Rust in-process engine (convergence plan), and pull only OpenCode's *services*  
  you want (LSP-for-agents, session/fork model). This collapses toward Option B.
- **IP brain wires.** Native shell + brain stay in-process; the brain is exposed to  
OpenCode's loop via **MCP/plugin** (as in Option A) for C1, or stays purely on top of  
Goose for C2. C1 keeps the brain at slight arm's length (over the bridge); C2 keeps it  
in-process. **[inferred]**
- **Theming / native-feel.** **Native** (the UI is SwiftUI). This is the *only* way to  
get **both** "full-clone OpenCode's capability" **and** "truly pixel-art native." The  
cost is you **build the native UI** (same UI lift as Option B) **and** still bundle/run  
the Bun/Node server (the sidecar cost of Option A, minus the UI-theming pain). **[inferred]**
- **MAS / sidecar.** Same sidecar concern as Option A for C1 (bundled Bun/Node +  
`opencode serve`) — NO-SIDECAR tension; MAS-irrelevant but notarization + footprint +  
CVE surface remain. C2 avoids the sidecar (no OpenCode runtime). **[inferred]**
- **Maintenance.** C1: track OpenCode's **OpenAPI surface** (more stable than its UI,  
but the recent Bun→Node and engine churn still ripples). C2: track Goose + selectively  
OpenCode. **[inferred from 826-release churn]**
- **Risk.** C1: MEDIUM-HIGH (sidecar + two loops + upstream churn, but native UI). C2:  
MEDIUM (≈ Option B with a few OpenCode services). C is the **most faithful to "clone**  
**the engine, theme natively"** while sidestepping the un-themeable-UI trap.

---

## 4. THE THEMING REALITY CHECK — can OpenCode's UI feel truly pixel-art NATIVE?

**Evidence-based answer: No — not OpenCode's *actual UI*. Neither of its two UIs can be**  
**made to feel like a native pixel-art macOS app; you can only theme them to look like a**  
**themed terminal or a themed web app.** **[verified web → reasoned conclusion]**

The two UIs and their ceilings:

1. **TUI (OpenTUI / Zig).** Themable via **JSON** — hex/ANSI colors, color refs, dark/  
 light variants, and semantic slots for UI/diff/markdown/**syntax highlighting**.  
 **[verified web — opencode.ai/docs/themes]** But it renders **truecolor character**  
 **cells in a terminal grid**. You can pick a palette that *evokes* pixel-art (it's a  
 grid of cells, after all), but you get **terminal typography, terminal cursors,**  
 **terminal layout** — **no native controls, no AppKit window chrome, no real pixel-art**  
 **sprite assets, no SwiftUI animations.** Requires the host terminal to support  
 truecolor. It will read as "a nicely themed terminal," not "a native app." **[verified**  
 **web → inferred]**
2. **Web UI (SolidJS in Tauri/Electron).** Full CSS control → you can build a genuinely  
 pixel-art *looking* skin (pixel fonts, sprite borders, etc.). **But it is HTML/CSS**  
 **rendered in a browser engine** (WebKit under Tauri, Chromium under Electron). The  
 OpenCode team **abandoned Tauri's WebKit specifically because of rendering**  
 **inconsistencies and perf**, choosing Chromium **[verified web — Brendonovich]** —  
 which tells you the surface is **web-rendered and finicky about exact styling**, the  
 opposite of native fidelity. A WKWebView/Electron skin can *imitate* pixel-art but  
 will carry web-app tells (scroll/focus/selection behavior, font rendering, latency,  
 no native menu/contextual integration) and will **never be byte-for-byte the same as**  
 **the app's SwiftUI pixel-art chrome** used everywhere else. **[verified web → inferred]**

**Conclusion.** "Theme OpenCode's UI to pixel-art native" is achievable as a *look* on  
the **web UI** and a *palette* on the **TUI**, but **"truly native pixel-art feel"**  
**requires rebuilding the UX in SwiftUI** (Option B, or the native shell of Option C).  
The owner's two goals — *"full clone OpenCode"* and *"truly pixel-art native"* — are in  
**direct tension at the UI layer**; they can only both be satisfied by **keeping**  
**OpenCode's engine/services and discarding its UI** (Option C / B), not by theming  
OpenCode's own UI (Option A). **[reasoned from verified facts]**

---

## 5. RECOMMENDATION

**Recommended: OPTION C2, evolving from / converging with OPTION B — "native pixel-art**  
**SwiftUI work shell over an in-process work engine, with OpenCode's *capability edge***  
**(LSP-for-agents + session/fork model) pulled in as services, Goose as the engine, and**  
**OpenCode's headless server available as an optional bundled engine behind a flag for the**  
**features Goose can't yet match."**

**Why this honors the owner's intent** (full clone, work shell, Goose inside, themed,  
lenient on Swift/Rust):

- **Work shell of record** ✅ — Work mode gets a dedicated, polished shell modeled on  
OpenCode's UX (multi-session, undo/redo, fork/share, inline LSP diagnostics).
- **Goose inside** ✅ — Goose is the in-process work engine (`GooseWorkBackend`), exactly  
as the owner pictures Goose doing the work; the shell wraps it.
- **Themed, truly native** ✅ — the only path that yields *real* pixel-art native feel  
(§4 proves theming OpenCode's own UI can't).
- **More capable than Osaurus/Goose** ✅ — we adopt OpenCode's genuine edges  
(LSP-for-agents, session-fork, multi-session, undo) — the capability, captured  
natively, instead of the un-themeable container.
- **Lenient on Swift/Rust** ✅ honored *as an escape hatch*: if a specific OpenCode  
capability proves too costly to re-create natively in the near term, we are *permitted*  
(owner's leniency + MAS-off) to **bundle** `opencode serve` **headless behind a flag** and  
drive it from the native UI (Option C1) for that feature — but we never ship OpenCode's  
UI, and we treat the bundled runtime as a temporary, flagged engine, not the shell.

**Why NOT Option A (the literal full-UI clone):** §4 — its UI can't feel native; it  
forces a forbidden-style Bun/Node/Electron sidecar; it runs two agent loops; and  
upstream churns hard (Go→OpenTUI, Tauri→Electron, Bun→Node). It maximizes the words  
"full clone" while *minimizing* the owner's other stated goal ("truly pixel-art native"

- "things that are already proven to work" wired to real native front-ends, addendum  
§24-29). **The owner's "loves the UI/UX" is best served by reproducing the UX natively,**  
**not by shipping the web/terminal container.** Flag this directly (§6 Q1).

### Concrete first slice + sequencing (fits Osaurus-first = ACT, then WORK)

Per the standing order — **Osaurus-first (act), then work** (addendum §19; convergence  
§4). Do NOT start OpenCode work until the act gates clear.

**Phase 0 (prereq, already the plan): finish ACT.** Dual-MLX consolidation onto
`vmlx-swift` → link `OsaurusCore` → Act turn through Osaurus → "Epistemos Picks" model
section. (Convergence §4 steps 1-3.) **Do not branch into Work-shell work before this.**

**Phase W0 — Work engine spine (Goose, native).** Continue the leaf-first Goose vendor
into `agent_core::work` (next push = provider/message layer, convergence §4 step 5) →
FFI-export `run_work_session` → light up `GooseWorkBackend`. Keep the GUARDRAIL test
(Chat/Act never break). **No OpenCode yet.**

**Phase W1 — FIRST SLICE: native pixel-art Work shell, minimum viable.** A SwiftUI
Work-mode view reusing the **shared Act/Work composer** (addendum §46-48): transcript +
streaming + model picker (incl. "Epistemos Picks") + tools, driven by `GooseWorkBackend`,
with **multi-session sidebar** (OpenCode's most-cited unique edge) backed by the existing
session store. This is the smallest thing that *is* a "work shell," is native, and proves
the pattern.

**Phase W2 — Pull OpenCode's capability edge natively.**
(a) **LSP-for-agents**: wire the existing `agent_core::lsp_runtime` diagnostics/defs/refs
into the work loop as tools + inline in the shell (this is the OpenCode idea, on
Epistemos's own LSP — convergence §4 step 5 / Q2). (b) **/undo /redo** of AI edits and
**session fork** modeled on OpenCode's behavior, native.

**Phase W3 — (only if needed) flagged OpenCode headless engine.** For any work
capability Goose+native can't yet match, bundle `opencode serve` headless behind
`EPISTEMOS_WORK_OPENCODE_ENGINE_V0`, drive it from the native UI via a Swift OpenAPI
client, expose the IP brain to it via MCP. Gated, logged (RunEventLog/AnswerPacket),
honest no-fallback (mirror `WorkBackendError`), retire when native parity lands. This is
where the owner's Swift/Rust leniency is spent — deliberately, narrowly, late.

This sequencing keeps **one agent-loop of record per mode** (Goose for work), keeps the
**brain on top**, gives a **truly native pixel-art** shell, captures **OpenCode's edge**,
and reserves the **literal bundled-OpenCode** path as a flagged fallback — fully within
the owner's leniency without making a forbidden sidecar the default.

---

## 6. OPEN QUESTIONS FOR THE OWNER

1. **The core tension (decide first).** §4 shows OpenCode's *own UI* (terminal cells or
 web/Chromium) **cannot feel truly pixel-art native** — only a themed terminal or
 themed web app. Given that, do you want **(A)** the literal full-UI clone (ship
 OpenCode's web UI themed, accept "web app inside the app" feel + a Node/Electron
 sidecar), or **(C/B)** OpenCode's *engine/capabilities* under a **native SwiftUI**
 pixel-art shell (recommended)? Your two stated goals can't both be fully met by (A).
2. **"Goose inside OpenCode" vs "Goose IS the work engine."** Did you mean OpenCode's
 loop runs and *delegates to* Goose (C1 — literally Goose inside OpenCode), or Goose is
 the in-process engine and the shell merely *looks/feels like* OpenCode (C2/B —
 recommended, honors "one loop of record")? These are very different builds.
3. **Sidecar tolerance.** Bundling `opencode serve` (Bun/Node) — and especially its
 Electron desktop — is exactly the **NO-HIDDEN-SIDECAR** pattern CLAUDE.md forbids on
 the product path. MAS is off, but is a **bundled local Node/Electron runtime**
 acceptable to you *at all* (footprint ~80-300 MB, its own auto-update + CVE surface,
 spawned subprocess), or only as a **flagged temporary engine** (Phase W3)?
4. **Upstream-tracking appetite.** OpenCode re-architects aggressively (Go→OpenTUI,
 Tauri→Electron, Bun→Node — all recent). A clone/fork is a **standing maintenance
 tax**. Are you committing to track it, or do you prefer capturing its *ideas* (which
 don't churn) natively?
5. **LSP edge.** Confirm you're happy capturing OpenCode's flagship **LSP-for-agents**
 via Epistemos's **existing** in-process Rust `lsp_runtime` (no OpenCode import), as
 the convergence research already proposed (its Q2).
6. **Which OpenCode capabilities are must-haves?** Rank: multi-session parallelism,
 /undo-/redo, session fork+share links, LSP-for-agents, 75-provider catalog. The
 must-haves drive whether Phase W3's flagged engine is ever needed or B/C2 suffices.
7. **Provenance.** If any OpenCode code *is* vendored (Phase W3), it is **MIT →
 `direct_import`**, but it's **TypeScript**, so it cannot enter `agent_core` (Rust) — it
 would live as a bundled runtime under its own `Vendor/OpenCode/` with a
 provenance/VENDOR record like Osaurus. Confirm that quarantine shape.

---

## Sources

- **In-repo (read this session):**
`docs/research/AGENT_STACK_CONVERGENCE_RESEARCH_2026_06_21.md`,
`docs/OSAURUS_P3_IMPORT_PLAN_2026_06_21_addendum.md`, `CLAUDE.md`,
`docs/GOOSE_REPLACEMENT_STRATEGY.md`/`GOOSE_S2_EXTRACTION_PLAN_2026_06_19.md` (referenced),
and the code seams they cite (`Epistemos/Work/WorkBackend.swift`,
`agent_core/src/work.rs`, `agent_core/src/lsp_runtime/mod.rs`,
`Epistemos/LocalAgent/LocalAgentLoop.swift`).
- **Web (primary/official):**
[sst/opencode (GitHub)](https://github.com/sst/opencode) ·
[opencode.ai/docs/server](https://opencode.ai/docs/server/) ·
[opencode.ai/docs/themes](https://opencode.ai/docs/themes/) ·
[opencode.ai/docs/agents](https://opencode.ai/docs/agents/) ·
[deepwiki sst/opencode](https://deepwiki.com/sst/opencode) ·
[deepwiki LSP 5.4](https://deepwiki.com/sst/opencode/5.4-language-server-protocol-(lsp)) ·
[OpenTUI (opentui.com)](https://opentui.com/) · [anomalyco/opentui](https://github.com/anomalyco/opentui) ·
[Brendonovich — Moving OpenCode Desktop to Electron (OpenCode team)](https://dev.to/brendonovich/moving-opencode-desktop-to-electron-4hip) ·
[explainx.ai OpenCode guide 2026](https://www.explainx.ai/blog/opencode-open-source-ai-coding-agent-guide-2026).
- **Labels:** all architecture/runtime/UI/provider/LSP facts above are **[verified web]**
from the sources listed; integration-shape and native-feel judgments are **[inferred]**
and labeled as such inline.

  

