# PLAN 1 (PRO) — Agent Surface: 1Code (21st-dev) embedded

**Date:** 2026-07-05 · **Status: CANONICAL DRAFT for the Pro=1Code build** · This is the new
Pro agent-surface plan. **Three builds:** MAS "Workspace" (June + agent_core), **Pro = 1Code
(this)**, Pro-Experimental = OpenChamber (renamed "Experimental", KEPT —
[`PROMPT_PLAN_1_PRO_OPENCHAMBER.md`](PROMPT_PLAN_1_PRO_OPENCHAMBER.md)). **NO goose in 1Code.**

**Verification basis (do not re-litigate without new evidence):** first-hand source reading of
the 1Code clone + 8 parallel research streams (6 code/local + web-verified model & CLI facts),
2026-07-05:
- 1Code clone `.research-clones/1code` @ `9f1bc76` ("Release v0.0.72", 2026-02-24, npm name
  `21st-desktop`). Every architecture/seam claim below is checked in source. [VERIFIED-CODE]
- Epistemos embedding mechanisms re-read first-hand in `Epistemos/ProAgent/*`, `Epistemos/
  JuneAgent/*`, `Epistemos/Work/WorkOpenCodeRuntime.swift`, the June Tauri shim. [VERIFIED-CODE]
- Live model/endpoint/CLI facts web-verified against primary sources (Anthropic/OpenAI/Moonshot/
  Z.ai/Google/OpenCode docs + npm/GitHub). Every stale-fact correction is in §9.

**Raw research corpus (provenance only — contains flagged UNVERIFIED items; never build blind
from it):** [`docs/research/ONECODE_RESEARCH_CORPUS_RAW_2026_07_05.md`](../research/ONECODE_RESEARCH_CORPUS_RAW_2026_07_05.md).

---

## §0 LOCKED OWNER DECISIONS (read first)

1. **PRO build only (Developer ID, NOT sandboxed, NOT MAS).** Subprocesses unrestricted. Ignore
   every MAS/sandbox/entitlement passage; MAS is the separate June track.
2. **1Code is the UI donor, embedded — NOT rebuilt.** Its React renderer runs inside the
   existing WKWebView; its Node backend runs headless under a Swift supervisor. We do NOT
   reimplement 1Code's backend in Swift (that breaks everything). License = **Apache-2.0,
   confirmed** (§9). Vendored fork, overlay-only edits.
3. **Native where it doesn't break the chat (owner 2026-07-05).** The **chat surface stays in the
   WebView** (native chat renderers historically break). Make **as many buttons / sidebars /
   settings / toolbar affordances NATIVE (NSButton/SwiftUI) as safely possible**, driven off the
   same backend, pushing intents into the SPA **without reloading** it. Optimize for maximum
   functionality; never sacrifice a working feature for nativeness. When in doubt, keep the
   donor's web control and skin it.
4. **Six providers, easiest-possible onboarding (owner 2026-07-05).** Prefer each provider's OWN
   CLI + OAuth where it exists; otherwise the simplest key-paste. Enterprise-grade, hardened, no
   fake capability. Matrix in §3.
5. **Fully local, no account, no telemetry.** The 21st.dev login wall, PostHog, Sentry, and the
   auto-updater are stripped (§ Decouple). Core loop runs offline (only the chosen model
   provider's endpoint is contacted).
6. **Model catalog is LIVE, never a hardcoded stale list.** Auto-updates from provider `/models`
   endpoints with `models.dev/api.json` as the backbone (§3.3).
7. **Zero silent feature loss.** The feature ledger (§8) is a shipping gate.
8. **Owner signatures kept:** native macOS toolbar pill, native all-chats sheet, theme-total
   re-skin (§ Native feel), mascot overlay seam (native layer; Plan 5 owns the mascot, Plan 1
   only the hook).

---

## §1 ARCHITECTURE (verified topology)

1Code is Electron: renderer ⇄ main over **tRPC-on-Electron-IPC** (`trpc-electron`), a Drizzle
SQLite backend, node-pty terminal, and two engines (Claude Code SDK + Codex ACP). The embed
**converts the Electron main process into a headless Node server** and hosts the renderer in the
WKWebView — making 1Code topologically identical to the OpenChamber surface Epistemos already
supervises.

```
Epistemos.app (Pro, Developer ID, native Swift shell)
│
├─ Native chrome (over the WebView, never inside donor DOM):
│   toolbar pill · all-chats sheet · as-many-native-buttons-as-safe · mascot overlay seam
│   · theme-total re-skin injected as CSS custom props
│
├─ WKWebView → http://127.0.0.1:<uiPort>/    (1Code renderer SPA, served by the headless backend)
│     │  · tRPC over HTTP(batch) + WebSocket(subscriptions), same-origin, zero CORS
│     │  · onecode-electron-shim.js (WKUserScript @documentStart) fakes window.desktopApi /
│     │    window.electron / ipcRenderer → WKScriptMessageHandler channels
│     ▼
├─ 1Code HEADLESS BACKEND  (forked src/main, run as plain Node — NO Electron)
│   ├─ serves the built renderer (static) + the tRPC server (@trpc/server standalone HTTP + ws)
│   ├─ runs all 21 routers unchanged: db(better-sqlite3) · git(simple-git) · terminal(node-pty) ·
│   │  claude(SDK→bundled `claude` binary) · codex(ACP) · chokidar watchers · worktrees
│   ├─ Electron-API shim (electron-shim-node.js): the 13 API families (app/safeStorage/dialog/
│   │  clipboard/shell/Menu/BrowserWindow-events/…) → Node paths / Keychain / Swift bridge / ws-push
│   └─ supervised by a ProAgentRuntimeSupervisor clone (OneCodeRuntimeSupervisor)
│
├─ Bundled engine binaries (native, Node-free where possible): `claude` · `codex` · `opencode`
│   (+ Node runtime only for gemini-cli; python/uv only for kimi-cli — see §3/§CLI)
└─ macOS Keychain  →  provider keys bridged to the backend + engine child env at spawn
```

**Reuse, don't rewrite:** Epistemos already supervises a Node web server + engine child for
OpenChamber. Extend that family (`ProAgentRuntimeSupervisor` → `OneCodeRuntimeSupervisor`): keep
the off-main spawn box, ephemeral-port allocator (49300–64900, above the WHATWG bad-port
blocklist), env allowlist, time-bounded Keychain bridge, crash-durable child ledger, health-poll
lifecycle. [VERIFIED-CODE: `Epistemos/ProAgent/ProAgentRuntimeSupervisor.swift`]

**Node runtime:** the backend is Node → bundle a pinned Node runtime + pruned prod `node_modules`
(node-pty + better-sqlite3 are native modules — rebuild for the pinned Node ABI, `asarUnpack`
equivalents). This mirrors the OpenChamber Node-bundling exactly.

**1Code source map (verified):** main `src/main/index.ts` (1019 L) + `windows/main.ts` (861 L);
preload `src/preload/index.ts` (`window.desktopApi` + tRPC bridge); renderer React 19 SPA
(`src/renderer`, `features/agents` = the chat); 21 tRPC routers `src/main/lib/trpc/routers/`;
Drizzle schema `src/main/lib/db/schema/index.ts` (`projects`/`chats`/`sub_chats`); state Jotai +
Zustand + React Query. Electron **~39.4.0** (`package.json:134`; the repo's CLAUDE.md "33.4.5" is
stale). Full detail: RAW §A.

---

## §2 THE EMBEDDING SEAM (verified) — THE CRUX

The embed has **two seams**, both bounded and enumerable. Full evidence in RAW §B.

### §2.1 Seam 1 — the tRPC transport swap (~2 lines) [VERIFIED-CODE]
`src/renderer/lib/trpc.ts:15-17` builds the whole renderer↔backend transport from one
`ipcLink({ transformer: superjson })`. Replace with a network link:
```ts
links: [ splitLink({
  condition: op => op.type === 'subscription',
  true:  wsLink({ client: createWSClient({ url:`ws://127.0.0.1:${port}/trpc` }), transformer: superjson }),
  false: httpBatchLink({ url:`http://127.0.0.1:${port}/trpc`, transformer: superjson }),
}) ]
```
`@trpc/client` 11.7.1 already ships these links. Server side: replace `trpc-electron`'s
`createIPCHandler`/`exposeElectronTRPC` with `@trpc/server`'s standalone HTTP adapter +
`applyWSSHandler`. The router **`Context`** only needs `getWindow()` for event push
(`src/main/lib/trpc/index.ts:8-9`) — provide a shim context whose "send to renderer" routes over
the ws channel. Audit `App.tsx` for the React `trpc.Provider client={}` (mirror the same link).

### §2.2 Seam 2 — the `desktopApi`/electron bridge table [VERIFIED-CODE `src/preload/index.ts:25-248`]
~60 channels + `webUtils`. The `onecode-electron-shim.js` WKUserScript (modeled on June's
`tauri-internals-shim.js`) defines `window.desktopApi`/`window.webUtils` and routes each to a
WKScriptMessageHandler with a `callId`-keyed promise round-trip (native replies via
`resolveInvoke(callId, {v:payload})`). Buckets:

| Bucket | Channels (preload line) | Native replacement |
|---|---|---|
| **Native Swift** | window controls `:77-83`, zoom `:104-107` (→WKWebView magnification), devtools `:122-123` (→`isInspectable`), clipboard `:139-140` (→NSPasteboard), `app:show-notification` `:131` (→UNUserNotification), `app:set-badge*` `:129-130` (→Dock tile), `shell:open-external` `:133` (→NSWorkspace, the external-links reroute), `dialog:save-file` `:143` (→NSSavePanel), `vscode:scan/load-theme` `:246-247` (→native FS scan), `webUtils.getPathForFile` `:15-17`, `app:get-api-base-url` `:136` (→the local server URL) | NSWindow / AppKit |
| **Server-push (ws)** | `stream:<id>:*` `:180-194`, `file-changed` `:221`, `git:status-changed`+watcher `:228-243`, `worktree:setup-failed` `:235`, `window:*-change` `:92-99`, `shortcut:*` `:209-214` | ws frames from the backend |
| **STUB / DECOUPLE** | ALL `update:*` `:33-74`, ALL `auth:*` `:147-153,197-205`, `analytics:set-opt-out` `:126`, `api:signed-fetch` `:156`, `api:stream-fetch` `:168` | local no-op / hide |

### §2.3 The headless conversion — the Electron API surface (bounded) [VERIFIED-CODE]
Every `electron` import in `src/main`+`src/preload` (grep): `BrowserWindow, app, safeStorage,
dialog, Menu, nativeImage, session, clipboard, shell, ipcMain, ipcRenderer, contextBridge,
webUtils` + `autoUpdater`. Everything else (better-sqlite3, node-pty, simple-git, chokidar,
child_process, the Claude/Codex SDKs) is **plain Node that runs headless unchanged.** The
`electron-shim-node.js` maps the 13 families:
- `app.getPath/isPackaged/getVersion` → fixed support-dir paths; `safeStorage` → macOS Keychain
  via the Swift bridge (or a Node keytar) — used in `auth-store.ts`, `claude.ts`, `claude-code.ts`,
  `anthropic-accounts.ts`; `dialog.showOpen/SaveDialog` → forward to NSOpenPanel/NSSavePanel;
  `clipboard`/`shell` → Swift bridge; `Menu`/`nativeImage`/`session` → native/no-op;
  `BrowserWindow.webContents.send` → ws push; `ipcMain.handle` → the tRPC/ws handlers;
  `autoUpdater` → dropped (§Decouple).
- **node-pty keeps working headless** → the terminal is NOT a Swift reimplement (owner's worry
  resolved). File dialogs + safeStorage + deep-link OAuth are the only true native-bridge items.

### §2.4 Window / load facts [VERIFIED-CODE]
Renderer prod loads from `file://` (`main/index.ts:162`, `windows/main.ts:821`) → we serve the
built SPA over localhost (same-origin with tRPC). Secure config already present
(`windows/main.ts:639-644`: `contextIsolation:true`, `nodeIntegration:false`, `webSecurity:true`)
→ the renderer is a pure web app, ideal for WKWebView. `titleBarStyle:"hiddenInset"` + custom
traffic-light position (`:631-636`) → native NSWindow chrome the owner wants.

---

## §3 THE 6-PROVIDER ENGINE LAYER (matrix + live catalog + auto-update)

1Code ships **two** engines today (Claude Code SDK + Codex ACP) with **no unified abstraction**
(RAW §C). The plan wires four more behind the SAME seams. **The decisive de-risker:** 1Code
**already has the `ANTHROPIC_BASE_URL` harness wired and user-facing** — `claude.ts:1129-1138`
injects `customConfig.{token,baseUrl}` as `ANTHROPIC_AUTH_TOKEN`/`ANTHROPIC_BASE_URL`; Settings →
Agents/Models exposes "Model name / API token / Base URL" (`agents-models-tab.tsx:752,772,791`).
[VERIFIED-CODE]

### §3.1 Provider matrix
| Provider | Path | Engine work | Onboarding | Model IDs (2026-07-05) |
|---|---|---|---|---|
| **Claude Code** | native (exists) | none | OAuth (`claude` /login) → setup-token → API key | `claude-opus-4-8`, `claude-fable-5`, `claude-sonnet-5`, `claude-haiku-4-5` |
| **Kimi** | **ANTHROPIC_BASE_URL harness** | **zero engine code** | Kimi CLI `/login` OAuth, OR paste `MOONSHOT_API_KEY` | `kimi-k2.7-code`, `kimi-k2.6`, `kimi-k2.5` · base `https://api.moonshot.ai/anthropic` |
| **GLM** | **ANTHROPIC_BASE_URL harness** | **zero engine code** | paste z.ai key (API-key, no OAuth) | `glm-4.7` (default), `glm-5.2` · base `https://api.z.ai/api/anthropic` |
| **Codex** | native ACP (exists) | migrate deprecated bridge | OAuth (`codex login` ChatGPT) → API key | `gpt-5.5` (default), `gpt-5.4`, `gpt-5.4-mini` |
| **Gemini** | **NEW ACP adapter** | new engine (Gemini CLI speaks ACP) | ⚠️ Google OAuth now paid-only → `GEMINI_API_KEY` | `gemini-3.5-flash`, `gemini-3.1-pro-preview` |
| **OpenCode** | **NEW adapter (Zen free only)** | new engine (own CLI/server) | `opencode auth login` → Zen key | free `opencode/*`: `big-pickle`, `grok-code`, `glm-4.7-free`, `kimi-k2.5-free`, … |

**Kimi + GLM (verbatim-confirmed base URLs, RAW §G.3/§G.4):** drop into the existing
`customConfig` harness. **Two gaps to close** (RAW §C.1): (a) the custom token is stored in plain
localStorage (`atoms/index.ts:254-263`) → move to Keychain; (b) one global `customClaudeConfigAtom`
→ switch the transport (`ipc-chat-transport.ts:176`) to the existing `ModelProfile[]` system so
Kimi/GLM/Claude are distinct per-conversation profiles. `.ai`/`.cn` key-domain-bound; GLM
Coding-Plan uses `…/api/coding/paas/v4` (not `/paas/v4`) for the OpenAI-compat path.

**Codex:** native (RAW §C.2). ⚠️ **Migrate the ACP bridge** — 1Code pins the DEPRECATED
`@zed-industries/codex-acp@0.9.3`; current is `@agentclientprotocol/codex-acp@1.1.0`. Default
model is `gpt-5.5` (not gpt-5.3-codex).

**Gemini (NEW):** the Gemini CLI speaks **ACP** (`gemini --acp`, JSON-RPC/stdio) and headless
(`gemini -p … --output-format stream-json`) — so a Gemini engine mirrors the Codex ACP router
shape rather than the Claude SDK. ⚠️ **Onboarding risk:** the 2026-06-18 Gemini-CLI→Antigravity
transition killed free Google-login; require `GEMINI_API_KEY` (250/day free Flash) or Vertex.
This lane is the shakiest — gate it honestly and consider deferring to a later phase.

**OpenCode (NEW, free-Zen-only per owner):** its own CLI/server (like an engine). Restrict to the
free Zen models (`opencode/*` where `cost==0`); auth `opencode auth login` → Zen key
(`OPENCODE_API_KEY`, endpoint `https://opencode.ai/zen/v1`). NOT the 75-provider/local/HF surface.

### §3.2 Model catalog — LIVE, never hardcoded [owner requirement]
1Code's catalog is hardcoded (`lib/models.ts`; RAW §C.5). Replace with a **live catalog service**:
- **Backbone:** poll `GET https://models.dev/api.json` (unauthenticated; aggregates all 6 + 75
  providers with `id`/`limit`/`cost`). Free-detection = `cost.input==0 && cost.output==0` in
  `providers.opencode.models`.
- **Account-scoped refinement:** per active provider, call its own `/models` — Anthropic
  `GET /v1/models` (x-api-key + `anthropic-version: 2023-06-01`, cursor pagination), OpenAI/Moonshot
  `GET /v1/models` (Bearer), Gemini `GET /v1beta/models` (`?key=`, id in `models[].name`). GLM has
  **no documented /models endpoint** → source from models.dev, runtime-verify, graceful fallback.
- One OpenAI-compat parser (`{object:"list",data:[{id}]}`) covers OpenAI/Moonshot/Zhipu; Anthropic
  (cursor) + Gemini (`name`+pageToken) are bespoke. Cache + TTL refresh; surface a health row.

### §3.3 Auth model per provider (easiest-first, RAW §H.1)
OAuth-subscription lanes (best UX): **Claude Code (claude.ai), Codex (ChatGPT), Kimi CLI (Kimi
Code), Gemini (Google — now paid)**. API-key lanes: **GLM, OpenCode-Zen, Kimi/GLM-via-harness.**
For OAuth CLIs: install the CLI, run its login. For harness/key lanes: one Keychain-backed
"paste key" field wired into 1Code's existing `customConfig` UI. **Never store a provider key in
webview JS / localStorage** — Keychain + backend env only (mirror `bridgedProviderEnvironment`).

---

## § DECOUPLE — fully local, no account, no telemetry [VERIFIED-CODE, RAW §D]

**License:** stock **Apache-2.0** confirmed (no non-commercial/SSPL/BUSL/Commons-Clause terms).
Safe to fork + embed commercially. [Dep-tree copyleft scan is a P0 checklist item.]

**Three surgical edits (the whole decouple):**
1. **Login wall:** `windows/main.ts:789` force `isAuth=true` / delete the `else{login.html}`
   branch (`:825-833`). Lands on `BillingMethodPage` (or auto-skips if `ANTHROPIC_API_KEY`
   present, `App.tsx:106-114`). This is the ONE true blocker.
2. **PostHog:** `lib/analytics.ts:13` set the hardcoded fallback key to `""` (it fires in any
   packaged build otherwise). Renderer PostHog + all Sentry are already env-gated → inert.
3. **Auto-updater:** remove the `index.ts:946-954` `if(app.isPackaged){…}` block (feed
   `cdn.21st.dev`).

Optional hardening: point `getBaseUrl()`/`getApiUrl()` offline; tighten CSP `connect-src` to
`'self' + api.anthropic.com + the provider endpoints`; strip bare `Sentry.init()`. `signedFetch`/
`streamFetch` are 100% cloud (require the 21st token, only call 21st.dev) — not on the local path.
**Do NOT touch** `claude/env.ts`, `claude-token.ts`, chat/spawn logic, `codex.ts`,
`ipc-chat-transport.ts`, `db/*`, bundled binaries. Net outbound after decouple: the chosen model
provider only (or nothing under a local model).

---

## § MCP AUTO-INJECT (Epistemos's own servers, zero user setup) [VERIFIED-CODE, RAW §E.A/§F.4]

1Code has **two independent MCP systems** — no shared injection point:
- **Claude engine:** file-based, mirrors the Claude Code CLI. Merge sources `~/.claude.json`,
  `~/.claude/.claude.json`, `~/.claude/mcp.json`, `<project>/.mcp.json`, plugin `.mcp.json`
  (`claude-config.ts`); injected as the in-process SDK option `options.mcpServers`
  (`claude.ts:1746-1761`). **Auto-inject seam:** write `epistemos-vault` into `~/.claude.json`
  `mcpServers` — the app **mtime-caches and re-reads it every message** (`claude.ts:1272-1300`),
  so it appears with no user action.
- **Codex engine:** separate `~/.codex` registry via `codex mcp add <name> …`, injected as ACP
  `session.mcpServers` (`codex.ts:1255-1262`). Auto-inject = run `codex mcp add` at setup.

**Mirror the OpenChamber fusion** (`Epistemos/Work/WorkOpenCodeRuntime.writeMergedFusionConfig`):
a Swift writer that **deep-merges ONLY Epistemos's own entries** (`epistemos-vault` →
`omega_mcp_stdio` with `EPISTEMOS_VAULT_ROOT`; optional `epistemos-native` loopback HTTP MCP for
the full computer-use tool set), preserving all user MCPs, 0600, persistent path. The
`omega_mcp_stdio` binary (newline JSON-RPC; vault read/write/search + wikilink graph +
patch_note) is already built + staged by `build-opencode-runtime.sh §2.5` — reuse it verbatim.
Skills/commands are pure filesystem (SKILL.md), loaded by the SDK's `settingSources` — seed by
writing files, no API (RAW §E.B).

---

## § NATIVE FEEL — theme-total re-skin + native chrome

Owner canon: **Apple-native unified blend; total theme-awareness; pixel-minimalism only in
fonts/accents/palette** (memory: design nativeness canon 2026-06-30; visual specs reused from
OpenChamber/June + `docs/research/GOOSE_NATIVE_WEB_RESKIN_2026_06_29.md`,
`EPISTEMOS_NATIVENESS_DOCTRINE_2026_06_29.md`).

**Mechanism (reuse `ProAgentThemeBridge`):** inject ~60 theme tokens as **inline `!important` CSS
custom props on `documentElement`** at `.atDocumentStart`, pin `.dark`/`.light`, a `MutationObserver`
re-asserts on donor flips; live switch via `page.callJavaScript` on theme change. [VERIFIED-CODE
`ProAgentThemeBridge.swift:123-168`]

**The re-theme spec (owner list):** chunky pixel header font; theme tokens throughout (no
gradient); trimmed toolbar pill = **Epistemos / New Chat / All Chats**; white user-text in light
mode; aligned message bubbles; a real caret in the composer; sidebar toggle **shifts** the chat
(not overlay). 1Code uses Tailwind + Radix + `next-themes` (`package.json`) — map Epistemos tokens
onto its CSS variables; keep 1Code's component behavior, restyle only.

**Native chrome (owner #3 — as native as safe):** native NSWindow (`hiddenInset` + traffic
lights), native toolbar pill + all-chats sheet (mirror `ProAgentNavBar` + `ProAgentAllChatsSheet`,
driven off the backend, intents pushed into the SPA **without reload**). **Progressive native
migration:** where a chrome control (settings toggles, sidebar sections, model picker) can be
driven purely by tRPC reads/writes, render it as native SwiftUI over the WebView; keep the
donor's web control anywhere native risks breaking the live session. **The chat transcript +
composer stay in the WebView.** Read-aloud (native TTS, honest gate), notification bridge,
external-links reroute (origin allowlist → NSWorkspace), mascot overlay seam — all per RAW §F.5.

---

## § CLI DETECT + INSTALL [VERIFIED web + Apple docs, RAW §H]

**Detect:** probe absolute locations (GUI apps get only the launchd PATH `/usr/bin:/bin:…` — no
Homebrew/`~/.local/bin`): `/opt/homebrew/bin`, `/usr/local/bin`, `~/.local/bin`, `~/.bun/bin`,
`~/.codex/bin`, npm-global, nvm dirs → optionally augment via `zsh -ilc 'echo $PATH'` → always
spawn with an **absolute `executableURL` + explicit merged env** (exactly
`ProAgentRuntimeSupervisor.childEnvironment`). Run `<bin> --version` to detect/version.

**Install picker:** native-first — `claude` (`curl …/install.sh`, no Node), `codex` (Rust binary
/ brew), `opencode` (`curl …/install`, native). Node-required: **gemini-cli (Node 20+)**; Python:
**kimi-cli (`uv`)** — detect the runtime and guide if missing. Post-install: verify SHA-256, then
`xattr -d com.apple.quarantine` (curl/tar don't set quarantine, but a quarantined unsigned child
is **hard-killed at exec**).

**Developer-ID spawn (decisive):** **entitlements are per-executable, NOT inherited across
`exec`** → the host needs **none** of `allow-jit`/`allow-unsigned-executable-memory`/
`allow-dyld-environment-variables`/`disable-library-validation` just to spawn these CLIs (Node's
JIT runs under Node's own signature). Ship the minimal hardened set. Child crash ≠ host crash.

---

## § EPISTEMOS-INTEGRATION REPLICATION LIST (every mechanism, RAW §F)

Clone from the Pro/OpenChamber supervisor **verbatim**: off-main `ProAgentSpawnBox` spawn (inline
@MainActor spawn froze the UI on code-sig validation — the #1 instant-open fix); ephemeral-port
allocator + `isLoopbackTCPPortAvailable` (range **49300–64900**, above the WHATWG bad-port
blocklist); `childEnvironment` allowlist; **time-bounded (4s) Keychain→env bridge**
(`bridgedProviderEnvironment` — avoids a first-launch Keychain-ACL hang); `ProAgentChildLedger`
crash-reaper (persists (pid, start-time), sweeps strays at next start); `Status` enum + health
poll (`/health` requires `status:ok`); tarball version-stamp unpack. Reuse the **June Tauri-shim
file** as the exact template for `onecode-electron-shim.js` (invoke→hostInvoke→
`webkit.messageHandlers.<ch>.postMessage({callId,cmd,args})` → `resolveInvoke(callId,{v:…})`;
`__EPISTEMOS_HOST__` gate; patched-WebSocket streaming stand-in; `jsStringLiteral` escaping; no
secret in JS). Every native feature (theme bridge, nav pill, all-chats, read-aloud, notification,
external-links, blank-screen resilience, keep-alive, perf signposts, mascot seam, packaging) has a
file:line in RAW §F.5–F.7.

---

## §7 PHASES (Pro build order)

- **Phase 0 — Vendor + decouple + headless boot.** Fork 1Code (Apache-2.0); dep-tree copyleft
  scan; the 3 decouple edits (login wall / PostHog / updater); convert `main/` to a headless Node
  server (electron-shim-node.js + tRPC HTTP/ws adapter + serve renderer); swap `trpc.ts` link;
  `OneCodeRuntimeSupervisor` (extended Pro family) boots it; WKWebView loads `127.0.0.1:<uiPort>`;
  `onecode-electron-shim.js` provides `desktopApi`. *De-risks the embed first.* Accept: SPA
  renders, tRPC query + a streaming subscription work over ws, terminal (node-pty) works, ZERO
  service worker, no account wall.
- **Phase 1 — Claude Code engine end-to-end.** Bundle `claude` binary; chat/stream/tools/diffs/
  git/worktree all green through the vendored UI, local project, no account. The "everything
  works" baseline.
- **Phase 2 — Native chrome + theme-total re-skin.** NSWindow chrome, toolbar pill, all-chats
  sheet, theme bridge (the owner re-skin spec), progressive native buttons where safe. No engine
  work. Accept: re-skin on ≥3 themes incl. one custom; chat stays live across every native intent
  (no reload).
- **Phase 3 — Providers 2–4 (harness lane).** Kimi + GLM via the `customConfig` harness (close the
  localStorage→Keychain + single-atom→profiles gaps); Codex ACP (migrate to
  `@agentclientprotocol/codex-acp`). Merged model picker, per-conversation engine/profile, honest
  capability. Live model catalog (models.dev backbone + per-provider `/models`).
- **Phase 4 — Providers 5–6 (new adapters) + MCP auto-inject.** Gemini ACP adapter (honest
  onboarding gate) + OpenCode Zen-free adapter; `epistemos-vault` MCP auto-injected into
  `~/.claude.json` (+ `codex mcp add`); CLI detect/install picker. Gemini may defer if its
  onboarding proves too rough.
- **Phase 5 — Lifecycle hardening (NOT MAS).** Crash-restart backoff, zombie/orphan reaping
  (child ledger), port-collision honesty, memory ceilings for the Node backend + engine children
  on 16 GB, launch/quit soak. Reuse the 2026-06-29 hardening-log patterns.

---

## §8 FEATURE LEDGER SEED (shipping gate — close every row)

| Feature | Lives | Risk |
|---|---|---|
| Project → chat → sub-chat sidebar + worktree | donor + Drizzle DB | Med |
| Chat + streaming + tool UIs + diffs (Monaco/git-diff-view) | donor renderer | Med |
| Terminal (node-pty + xterm) | headless backend over ws | Med (server must stay alive) |
| Git worktree per chat (`~/.21st/worktrees`) | donor `worktree.ts` | Med |
| Permissions / plan-vs-agent mode | donor | High (event translation over ws) |
| 6-provider engine + live model catalog | §3 | High |
| MCP auto-inject (epistemos-vault) | §MCP | Med |
| Native chrome (pill / all-chats / native buttons) + re-skin | native Swift | Low–Med |
| CLI detect / install picker | native + §CLI | Med |
| Live preview | ⚠️ donor stub only (CodeSandbox iframe) — **net-new or deferred** | Low (cut) |
| Login wall / PostHog / Sentry / auto-updater | — | **must be stripped** |

---

## §9 CORRECTIONS LOG (brief assumptions / stale facts overruled — do not resurrect)

1. ~~GLM current model is `glm-4.6`~~ → **`glm-4.7` (Claude-Code default) / `glm-5.2` (flagship)**;
   4.6 is a fallback. Ship IDs behind config, never bake 4.6 as "current."
2. ~~Gemini free "login with Google" (1,000/day)~~ → **discontinued 2026-06-18 (Gemini CLI →
   Antigravity CLI)**; now `GEMINI_API_KEY` (250/day free Flash) / Vertex / paid.
3. ~~Codex default `gpt-5.3-codex`~~ → **`gpt-5.5`**. And 1Code's pinned `@zed-industries/codex-acp`
   is **DEPRECATED** → migrate to `@agentclientprotocol/codex-acp`.
4. ~~Kimi model `kimi-k2-thinking`~~ → first-party IDs are **dotted** `kimi-k2.7-code`/`k2.6`/`k2.5`;
   the dashed IDs are open-weights/third-party names.
5. ~~Sonnet is `claude-sonnet-4-x`~~ → **`claude-sonnet-5`**; 4.x is legacy.
6. ~~Reimplement 1Code's terminal/backend natively in Swift~~ → **run the Node backend headless**;
   node-pty/better-sqlite3/git all work unchanged. Only the 13 Electron API families are shimmed.
7. ~~1Code has a live model list~~ → it's **hardcoded** (`lib/models.ts`); the live catalog is
   net-new (models.dev backbone).
8. ~~The `setup-token` OAuth token can call the Messages API~~ → **NO** — it works only with Claude
   Code; a raw `/v1/messages` call is rejected.
9. ~~Electron 33.4.5~~ (1Code's own stale CLAUDE.md) → **~39.4.0** (`package.json:134`).
10. ~~GLM `GET /paas/v4/models` exists~~ → **undocumented/UNVERIFIED**; source GLM from models.dev.

---

## §10 OPEN QUESTIONS (working defaults — build proceeds on defaults)

1. Gemini onboarding (paid-only OAuth) → **default: ship as a key-paste lane, gate honestly, may
   defer to a fast-follow** if the UX is too rough.
2. OpenCode scope → **default: free Zen models only** (owner-locked); not the 75-provider surface.
3. Live-preview → **default: cut in v1** (donor stub is dead); revisit as native or a real local
   dev-server later.
4. Per-conversation profiles vs one global custom config → **default: adopt the donor's
   `ModelProfile[]` system** and switch the transport to it (needed for Kimi/GLM anyway).
5. safeStorage bridge → **default: macOS Keychain via the Swift bridge** (reuse Epistemos Keychain).
6. Codex ACP migration timing → **default: Phase 3** (works today on the deprecated pin; migrate
   before ship).

---

## §11 GUARDRAILS

- Research/read + write docs only in THIS pass — NO app build, NO edits to other lanes.
- Clone only into `.research-clones/` (gitignored `:94`); **never commit it; never `git add -A`;
  no git worktrees, ever.**
- Vendored 1Code fork lives OUTSIDE the Epistemos git tree; overlay edits in NEW files; unavoidable
  in-place edits each get a `docs/PATCH_LEDGER.md` row (seed: the 3 decouple edits + the trpc.ts
  link swap + the electron shims).
- Never modify the bundled engine binaries; provider keys stay in Keychain, bridged to child env
  only — never webview JS.
- Swift changes (when building later): `xcodebuild` on isolated DerivedData,
  `CODE_SIGNING_ALLOWED=NO`, BUILD SUCCEEDED before commit; never two xcodebuilds concurrently
  (16 GB machine). Commit after every coherent change; honest reporting (no "done" without the §8
  ledger).

---

## §12 BUILD RUNBOOK (start here — decisions pre-made)

**R1. Vendor (one-time).** Fork `21st-dev/1code` → clone OUTSIDE this repo; `git remote add
upstream …`; pin the start SHA (`9f1bc76`, v0.0.72). `bun install && bun run build` must pass
UNTOUCHED first. Dep-tree copyleft scan (AGPL/SSPL/BUSL).

**R2. Decouple (the first patch-ledger rows) [VERIFIED-CODE]:** `windows/main.ts:789` (login
wall) · `lib/analytics.ts:13` (PostHog key → `""`) · `index.ts:946-954` (auto-updater).

**R3. Headless conversion:** write `electron-shim-node.js` (the 13 API families → Node/Keychain/
Swift-bridge/ws) · replace `trpc-electron` server adapter with `@trpc/server` standalone HTTP +
`applyWSSHandler` · serve the built renderer statically · swap `src/renderer/lib/trpc.ts:15-17`
to `splitLink[wsLink,httpBatchLink]`.

**R4. Swift host:** `OneCodeRuntimeSupervisor` (clone `ProAgentRuntimeSupervisor` — off-main
spawn, port allocator, env allowlist, Keychain bridge, child ledger, health poll) · WKWebView
loads `127.0.0.1:<uiPort>` · inject `onecode-electron-shim.js` (WKUserScript @documentStart) +
theme bridge + navigation decider · register the WKScriptMessageHandler channels (validate every
payload).

**R5. Env matrix (per-launch):** backend gets `<uiPort>`, the Keychain-bridged provider keys,
`EPISTEMOS_VAULT_ROOT`, `OPENCODE_CONFIG` (the fusion config with `epistemos-vault`); engine
children spawn with absolute paths + the merged PATH env.

**R6. Overlay files to create in the fork:** `src/backend/electron-shim-node.ts`,
`src/backend/trpc-http-server.ts`, the model-catalog service, the Keychain custom-config bridge,
`docs/PATCH_LEDGER.md`.

**R7. Phase acceptance:** per §7 — each phase ends in a commit + owner-visual checkpoint + the
perf/hardening gate.

---

## §13 CARRY-FORWARD — the "instant-open" recipe (owner-loved; PRESERVE exactly)

Same architecture as the goose/OpenChamber surfaces (WKWebView over a supervised localhost
backend) → **port the whole 6-part recipe** (RAW §F.1, `ProAgentRuntimeSupervisor` +
`ProAgentSurfaceView`): (1) eager WebView + instant placeholder in `init()`; (2) **spawn the
backend OFF the main actor** (`ProAgentSpawnBox` — an inline @MainActor spawn froze the UI on
notarized-binary code-sig validation); (3) lazy start on first `.task`; (4) poll `/health` for
readiness, placeholder in parallel; (5) **keep the WebView alive across tab switches** — reloading
the URL reboots the SPA and KILLS the live session, so drive navigation via injected intent
events, never a reload; (6) non-persistent data store + warm backend before load. Escalation:
eager-pre-warm the Node backend at `AppBootstrap` (off-main, `.utility`) since the stack is
heavier than `goose serve`. Web-side perf is equally mandatory — READ-FIRST
`docs/research/AGENT_SURFACE_PERFORMANCE_DOCTRINE_2026_07_03.md` §2; budgets in
`docs/perf-budgets.toml [agent_surface]` (cold 1500 / warm 100 / first-token 1200). Perf is a
phase gate.

---

## §14 HARDENING (baked in, per-phase gate — READ-FIRST `AGENT_SURFACE_HARDENING_DOCTRINE_2026_07_03.md`)

Each phase ends with a bounded hardening pass over what it touched (security · memory-leak ·
data-leak · robustness), reported `N HIGH / N MED / N LOW`, file:line, FIXED/DEFERRED; a HIGH
blocks the phase commit. This surface's specific top risks:
1. **Loopback-origin pinning — NEVER weaken** (the OpenChamber H1): pin the WKWebView to the exact
   registered `127.0.0.1:<uiPort>`; the navigation decider trusts only it; a foreign local page
   inheriting the shim would leak the native bridge.
2. **No secret in webview JS** — provider keys + any backend token live Swift-side + backend env
   only; validate every `WKScriptMessageHandler` payload (untrusted); `jsStringLiteral`-escape
   every reply.
3. **Supervision, not polling** (child ledger + backoff + honest `.failed` + process-group cleanup
   + occupied-port honesty) for the Node backend + engine children.
4. **Instruction-source boundary** on anything an agent reads through a tool (the MCP vault path).
5. **Decouple is a hardening invariant:** SW off, telemetry off, no account, CSP no-external-hosts
   except the chosen provider endpoints. Perf AND hardening HIGHs both block the commit.
