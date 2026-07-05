# RAW corpus — 1Code (21st-dev) Pro agent-surface research

> ⚠️ **RAW RESEARCH INPUT — DO NOT BUILD FROM THIS FILE.** This is the verbatim,
> evidence-backed research corpus for embedding **1Code** (`21st-dev/1code`, npm
> name `21st-desktop`, product "1Code") as Epistemos's **Pro** agent surface. It
> blends (a) first-hand source reading of the cloned repo by the lead agent and
> (b) parallel deep-dive sub-agent reports, each cited to `file:line`. It will
> contain claims later corrected during synthesis. **Canonical build doc:**
> `docs/prompts/PROMPT_PLAN_1_PRO_ONECODE.md` (see its §Corrections log). Kept for
> provenance only.

**Method / provenance:**
- **Clone:** `.research-clones/1code` @ `9f1bc76fa4372c18c565b5a4f8daf38ae3595f0e`
  ("Release v0.0.72", 2026-02-24). GITIGNORED (`.gitignore:94` `.research-clones/`),
  never committed. Re-clone: `git clone --depth 1 https://github.com/21st-dev/1code`.
- **Depth bar:** matched against `docs/research/OPENCHAMBER_RESEARCH_CORPUS_RAW_2026_07_02.md`
  + `docs/prompts/PROMPT_PLAN_1_PRO_OPENCHAMBER.md` (the sibling Pro dossier). This
  corpus is meant to be *at least* as deep, with a harder embedding problem
  (Electron, not a web server).
- **Research cycles:** 6 parallel agents — (1) architecture/seam [lead, first-hand],
  (2) orchestration layer, (3) license + telemetry/account decoupling, (4)
  MCP/plugins/worktree/preview, (5) Epistemos ProAgent/June integration for
  replication, (6+7) live web verification of model catalog + CLI install/auth.
- **Owner answers folded in (2026-07-05):** (1) native where possible, chat itself
  stays in WebView, "as many buttons/sidebars/settings native as possible" without
  breaking things; (2) prefer each provider's OWN CLI + OAuth / easiest-possible
  onboarding, research the most robust enterprise-grade path; (3) single exhaustive
  dossier, multiple deep cycles, weight depth toward the two hardest unknowns (the
  Electron→WKWebView bridge + the live model-catalog auto-update).

---

## THE VISION (owner-locked framing)

Three builds, one codebase:
- **MAS "Workspace"** (was June) — sandboxed, App Store.
- **Pro = 1Code (THIS dossier)** — Developer ID, not sandboxed. 1Code's renderer web
  UI embedded in a WKWebView + native Swift host. **NO goose in 1Code.**
- **Pro-Experimental = OpenChamber** (renamed "Experimental", KEPT — separate dossier).

1Code embeds like the others: renderer web UI in a WKWebView, native Swift chrome
over/around it, a supervised local backend, a JS bridge replacing the Electron API
surface — mirroring how Epistemos already shimmed Tauri for June and hosted
OpenChamber via `Epistemos/ProAgent/*`.

---

# §A — 1Code ARCHITECTURE MAP (first-hand, source-verified)

**Identity / stack** (`package.json`, `CLAUDE.md`, `electron.vite.config.ts`):
- Electron **~39.4.0** (`package.json:134` — NOTE: the repo's own `CLAUDE.md` says
  "33.4.5", which is **stale**; `package.json` is truth), `electron-vite` 3, `electron-builder` 25.
- **Bun** package manager (`bun.lock` / `bun.lockb`). React **19.2.1**, TypeScript 5.4.5,
  Tailwind 3.4.17.
- Build: three entries via `electron-vite` — `main` (`src/main/index.ts`), `preload`
  (`src/preload/index.ts`), `renderer` (`src/renderer/index.html` + `login.html`)
  (`electron.vite.config.ts:9-79`).
- appId `dev.21st.agents`, custom URL scheme **`twentyfirst-agents`** (`package.json:143-153`),
  hardened runtime + notarization (`package.json:205-211`).

**Three-process split** (`src/` tree, 539 files):
- `src/main/` — Electron main process. Entry `index.ts` (1019 lines), `windows/main.ts`
  (861 lines, window creation + IPC handlers), `windows/window-manager.ts`, `auth-manager.ts`,
  `auth-store.ts`, `constants.ts`, and `lib/{claude,db,fs,git,ollama,platform,plugins,terminal,trpc}`.
- `src/preload/index.ts` — the contextBridge (17.5 KB). Exposes the tRPC IPC bridge +
  `window.desktopApi` + `window.webUtils`.
- `src/renderer/` — React 19 SPA. Entry `main.tsx` + `App.tsx`. `features/{agents,sidebar,
  terminal,settings,kanban,automations,mentions,onboarding,layout,changes,file-viewer,
  details-sidebar}`. `features/agents/ui` alone is 57 files. `components/ui` = 36 Radix
  wrappers. State in `lib/{atoms,stores}` + `lib/trpc.ts`.
- `src/shared/` — cross-process types (`changes-types.ts`, `codex-tool-normalizer.ts`,
  `detect-language.ts`, `external-apps.ts`).

**THE IPC CONTRACT — tRPC over Electron IPC (the crux).**
"All backend calls go through tRPC routers, not raw IPC" (`CLAUDE.md`). Concretely:
- Server: `initTRPC.context<Context>().create({ transformer: superjson })` where
  `Context = { getWindow: () => BrowserWindow | null }` (`src/main/lib/trpc/index.ts:8-26`).
- **21 routers** (`src/main/lib/trpc/routers/`): `agents, agent-utils, anthropic-accounts,
  chats, claude, claude-code, claude-settings, codex, commands, debug, external, files,
  index, ollama, plugins, sandbox-import, skills, terminal, voice, worktree-config`.
- Renderer client (`src/renderer/lib/trpc.ts:1-17`):
  ```ts
  export const trpc = createTRPCReact<AppRouter>()
  export const trpcClient = createTRPCProxyClient<AppRouter>({
    links: [ipcLink({ transformer: superjson })],   // ← trpc-electron/renderer
  })
  ```
  Transport = `trpc-electron` v0.1.2 (`package.json:114`). **This single `ipcLink` is the
  entire renderer↔backend transport.**

**Data layer:** Drizzle ORM + `better-sqlite3` at `{userData}/data/agents.db`
(`CLAUDE.md`, `src/main/lib/db/`). Schema `src/main/lib/db/schema/index.ts` — three tables:
`projects(id,name,path,git*)`, `chats(id,name,projectId,worktreePath,branch,baseBranch,
prUrl,prNumber)`, `sub_chats(id,name,chatId,sessionId,streamId,mode,messages JSON)`.
Auto-migrates from `drizzle/` (dev) or `resources/migrations` (packaged).

**State management (renderer):** Jotai (UI state atoms), Zustand (sub-chat tabs,
persisted to localStorage), React Query (`@tanstack/react-query`) via `@trpc/react-query`
for server state. Editor = Monaco (`@monaco-editor/react`). Diff = `@git-diff-view/react`
+ `@pierre/diffs`. Terminal = xterm + node-pty. Markdown = streamdown/shiki/mermaid.

**Two AI engines, no unified abstraction** (each a separate tRPC router + `chat`
subscription): **Claude Code** (`@anthropic-ai/claude-agent-sdk` 0.2.45, in-process,
spawns bundled `claude` binary) and **Codex** (`@zed-industries/codex-acp` 0.9.3 via
`@mcpc-tech/acp-ai-provider` 0.2.4, ACP over stdio, spawned). **Ollama** rides the Claude
SDK by redirecting its base URL. Full mechanics in §C.

---

# §B — THE EMBEDDING SEAM (first-hand, source-verified) — THE CRUX

OpenChamber was easy: an Express web server + a WKWebView pointed at `127.0.0.1:<port>`.
1Code is **Electron**, so there is no HTTP server and the renderer talks to the backend
over Electron IPC. The embedding problem is therefore harder — but it is **bounded and
enumerable**, and it collapses to the same OpenChamber topology once converted.

## B.1 — The liberating thesis: 1Code's "Electron" backend is ~90% plain Node

Every `electron` import across `src/main` + `src/preload` (grep-verified):
`BrowserWindow, app, safeStorage, dialog, Menu, nativeImage, session, clipboard, shell,
ipcMain, ipcRenderer, contextBridge, webUtils` + `autoUpdater`/`log` from `electron-updater`/
`electron-log`. **That is the ENTIRE Electron API surface.** Everything else — `better-sqlite3`,
`node-pty`, `simple-git`, `chokidar`, `child_process`, the Claude/Codex SDKs — is plain Node
that runs headless with no Electron at all. Notably **`node-pty` keeps working in headless
Node**, so the terminal is NOT a native-reimplement problem.

**Conversion target:** fork `main/` into a **headless Node process** that (a) serves the
built renderer SPA over `http://127.0.0.1:<uiPort>`, (b) hosts the tRPC server over
HTTP+WebSocket on the same origin, (c) runs all existing router logic unchanged. Supervise
it with the proven `ProAgentRuntimeSupervisor` pattern. **This makes 1Code topologically
identical to OpenChamber** — which Epistemos already knows how to host.

## B.2 — Seam 1: the tRPC transport swap (~2 lines)

`src/renderer/lib/trpc.ts:15-17` builds the vanilla client from a single
`ipcLink({ transformer: superjson })`. Replace with a network link:
```ts
links: [ splitLink({
  condition: op => op.type === 'subscription',
  true:  wsLink({ client: createWSClient({ url: `ws://127.0.0.1:${port}/trpc` }), transformer: superjson }),
  false: httpBatchLink({ url: `http://127.0.0.1:${port}/trpc`, transformer: superjson }),
}) ]
```
`@trpc/client` 11.7.1 already ships `httpBatchLink`/`wsLink`/`splitLink`. The React hooks
(`createTRPCReact`) reuse whatever provider link the app wires (audit `App.tsx` for the
`trpc.Provider` `client={}` — it likely mirrors `trpcClient`). Server side, replace the
`trpc-electron` main adapter (`exposeElectronTRPC()` in preload, `createIPCHandler` in main)
with `@trpc/server`'s standalone HTTP adapter + `applyWSSHandler`. The router **`Context`**
only needs `getWindow()` for event push (`trpc/index.ts:8-9`) — provide a shim context whose
"window.webContents.send" routes over the WS channel instead. **Bounded, countable touch points.**

## B.3 — Seam 2: the `desktopApi` preload surface (the bridge table)

`src/preload/index.ts:25-248` exposes `window.desktopApi` (~60 channels) + `window.webUtils`.
Every channel, bucketed for the WKScriptMessageHandler shim (mirror of June's
`tauri-internals-shim.js`):

**→ NATIVE Swift replacement (NSWindow / NSPasteboard / NSPanel / NSWorkspace / WKWebView):**
- Window controls `window:minimize|maximize|close|is-maximized|toggle-fullscreen|is-fullscreen`
  (`:77-82`), `window:set-traffic-light-visibility` (`:83`), `window:new|set-title` (`:110-112`).
- Zoom `window:zoom-in|out|reset|get-zoom` (`:104-107`) → WKWebView `magnification`.
- DevTools `window:toggle-devtools|unlock-devtools` (`:122-123`) → WKWebView `isInspectable`.
- Clipboard `clipboard:write|read` (`:139-140`) → NSPasteboard.
- `app:show-notification` (`:131`) → UNUserNotificationCenter. `app:set-badge|set-badge-icon`
  (`:129-130`) → NSApp.dockTile.
- `shell:open-external` (`:133`) → NSWorkspace.open (**this is the external-links reroute**).
- `dialog:save-file` (`:143`) → NSSavePanel. Platform `platform/arch` (`:27-28`),
  `app:version|isPackaged` (`:29-30`), `app:get-api-base-url` (`:136`) → the local server URL.
- `webUtils.getPathForFile` (`:15-17`) → drag-drop native path (WKWebView drag handler).
- `vscode:scan-themes|load-theme` (`:246-247`) → native FS scan of VS Code/Cursor theme dirs.
- Windows-only `window:set-frame-preference|get-frame-state` (`:87-89`) → no-op on macOS.

**→ SERVER-PUSH (over the WS/SSE channel from the headless backend):**
- `stream:<id>:chunk|done|error` (`:180-194`) — chat streaming chunks.
- `file-changed` (`:221`), `git:status-changed` (`:228`), `git:subscribe-watcher|unsubscribe`
  (`:242-243`), `worktree:setup-failed` (`:235`) — chokidar/git watcher pushes.
- `window:fullscreen-change|focus-change` (`:92-99`), `shortcut:new-agent|open-settings`
  (`:209-214`) — native events pushed into the webview.

**→ STUB / DECOUPLE (no-account, no-telemetry, no-cloud — see §D):**
- ALL `update:*` (`:33-74`) — auto-updater → stub "no update".
- ALL `auth:*` (`:147-153`, `:197-205`) — 21st.dev account → local no-account mode.
- `analytics:set-opt-out` (`:126`) — telemetry → no-op.
- `api:signed-fetch` (`:156`), `api:stream-fetch` (`:168`) — 21st.dev cloud proxy → not on
  local path; stub/hide.

## B.4 — Window security config (maps cleanly to WKWebView)

`src/main/windows/main.ts:639-644`: `contextIsolation: true`, `nodeIntegration: false`,
`sandbox: false` (for electron-trpc), `webSecurity: true`, custom preload. **The renderer is
a pure context-isolated web app with no Node access** → ideal WKWebView candidate. macOS
chrome: `titleBarStyle: "hiddenInset"` + custom `trafficLightPosition` + `frame` toggle
(`:631-636`) → native NSWindow with `titlebarAppearsTransparent`/`fullSizeContentView` +
native traffic lights = exactly the native chrome the owner wants. External-link guard:
`window.webContents.setWindowOpenHandler` (`:739`) → WKWebView `decidePolicyFor` + NSWorkspace reroute.

## B.5 — How the renderer is loaded (embed entry point)

Production loads the renderer from **`file://`** (`loadFile(join(__dirname,"../renderer/index.html"))`
— `main/index.ts:162`, `windows/main.ts:821`), NOT a localhost server (dev uses the
electron-vite dev server via `loadURL`). So the embed must **serve the built renderer over
localhost itself** — either a tiny static server in the headless Node process, or a Goose-style
custom WKURLSchemeHandler serving from the app bundle. Same-origin with the tRPC server is the
clean choice (mirror OpenChamber). Trusted-origin list already exists:
`["21st.dev","localhost","127.0.0.1"]` (`windows/main.ts:342`).

## B.6 — The no-clean-native-replacement items (owner's explicit worry)

| Item | Reality | Plan |
|---|---|---|
| **PTY / terminal** | `node-pty` 1.1.0 + xterm; runs in **headless Node** unchanged | Keep server-side; xterm in the webview talks to node-pty over the WS channel. **No Swift PTY reimplement.** |
| **File dialogs** | Electron `dialog.showOpenDialog|showSaveDialog` (`projects.ts`, `index.ts`, preload `dialog:save-file`) | Bridge to native NSOpenPanel/NSSavePanel via WKScriptMessageHandler. Small. |
| **Encrypted creds** | Electron `safeStorage` (`auth-store.ts`, `claude.ts`, `claude-code.ts`, `anthropic-accounts.ts`) | Route to macOS Keychain via bridge (Epistemos already does Keychain). |
| **Deep-link OAuth** | `twentyfirst-agents://` scheme + loopback callback server (`AUTH_SERVER_PORT`) | Reuse Epistemos's own scheme + the existing loopback callback (1Code's OAuth already uses `http://localhost:<port>/callback`, MCP-OAuth-friendly). |
| **Live preview** | Dead CodeSandbox iframe stub (see §E.D) | Nothing to preserve; a local preview is net-new (defer, or native later). |
| **Native menu / Dock / badge** | `Menu`, `nativeImage` | Native Swift menu + Dock tile. |

---

# §C — ORCHESTRATION LAYER (agent report — how 1Code drives its engines)

_First-hand sub-agent read of `routers/{claude,claude-code,codex,ollama,anthropic-accounts,
claude-settings,agents,agent-utils}.ts`, `lib/claude/*`, `lib/ollama/*`, `shared/codex-tool-normalizer.ts`,
`constants.ts`, `auth-manager.ts`, `auth-store.ts`, download scripts._

**No unified "engine" abstraction** — each provider is a separate tRPC router with its own
`chat` subscription. Package pins: `@anthropic-ai/claude-agent-sdk` **0.2.45**,
`@zed-industries/codex-acp` **0.9.3**, `@mcpc-tech/acp-ai-provider` **^0.2.4**, `ai` (Vercel
AI SDK) **^6.0.14** (`package.json:39,76,181-184`).

## C.1 — Claude Code engine
- **SDK, in-process, spawning a bundled binary.** `getClaudeQuery` caches `sdk.query`
  (`claude.ts:248-259`); driven by `query(queryOptions)` (`claude.ts:2019`), iterated
  `for await (const msg of stream)` (`claude.ts:2055`).
- **Bundled binary, not PATH:** `options.pathToClaudeCodeExecutable = getBundledClaudeBinaryPath()`
  (`claude.ts:1977,1443`) → `resources/bin/{platform}-{arch}/claude` (`lib/claude/env.ts:45-105`).
- **Streaming:** tRPC subscription **`claude.chat`** (`claude.ts:795-820`), each SDK message →
  `createTransformer()` (`lib/claude/transform.ts`) → Vercel-AI `UIMessageChunk`s (`claude.ts:2317`).
  `includePartialMessages: true` (`claude.ts:1770`) = token streaming. Renderer subscribes via
  `trpcClient.claude.chat.subscribe` (`ipc-chat-transport.ts:202`).
- **Session resume:** `resume`/`forkSession`+`resumeSessionAt`/`continue:true`
  (`claude.ts:1980-1994`). Per-subChat `CLAUDE_CONFIG_DIR = {userData}/claude-sessions/{subChatId}`
  with `~/.claude/{skills,commands,agents,plugins,settings.json}` symlinked in (`claude.ts:1149-1264`).
- **THE `ANTHROPIC_BASE_URL` HARNESS (already wired, user-facing).** `claude.ts:1129-1138`:
  ```ts
  const claudeEnv = buildClaudeEnv({
    ...(finalCustomConfig && { customEnv: {
      ANTHROPIC_AUTH_TOKEN: finalCustomConfig.token,
      ANTHROPIC_BASE_URL:  finalCustomConfig.baseUrl,
    }}), enableTasks: input.enableTasks ?? true,
  })
  ```
  Input schema `customConfig: { model, token, baseUrl }` (`claude.ts:806-812`). When set,
  `hasExistingApiConfig` suppresses the OAuth token so the custom base URL wins
  (`claude.ts:1390-1410`); model from `finalCustomConfig.model` (`claude.ts:1495`). **UI:**
  Settings → Agents/Models tab with fields literally labeled "Model name" / "API token —
  `ANTHROPIC_AUTH_TOKEN`" / "Base URL — `ANTHROPIC_BASE_URL`" (`agents-models-tab.tsx:752,772,791`,
  placeholder `https://api.anthropic.com` `:800`); same in onboarding (`api-key-onboarding-page.tsx:74-89`).
  **⇒ Kimi + GLM drop into this harness with ZERO new engine code.** Two gaps: the custom token
  is stored in **plain localStorage** (`atoms/index.ts:254-263`), not safeStorage; and there's
  one global `customClaudeConfigAtom` (a `ModelProfile[]` system exists at `atoms/index.ts:273-287`
  but `ipc-chat-transport.ts:176` still reads the single legacy atom) — per-provider profiles
  need the transport switched to the profile system.
- **Model IDs:** short aliases `"opus"|"sonnet"|"haiku"` via `MODEL_ID_MAP` (`atoms/index.ts:346-350`),
  catalog `CLAUDE_MODELS` = opus 4.6 / sonnet 4.6 / haiku 4.5 (`lib/models.ts:1-5`). `ANTHROPIC_MODEL`
  is **never** set as env; model goes via the SDK `model:` option (`claude.ts:1995`). Dead
  `fallbackModel:"claude-opus-4-5-20251101"` commented at `claude.ts:1996`.

## C.2 — Codex engine
- **ACP over spawned binary.** `createACPProvider({ command: resolveCodexAcpBinaryPath(), env,
  authMethodId, session:{cwd,mcpServers}, existingSessionId, persistSession:true })`
  (`codex.ts:1255-1267`). Binary from the npm package's platform bin, asar-unpacked
  (`resolveCodexAcpBinaryPath`, `codex.ts:223-235`). Transport = stdio JSON-RPC (owned by the
  `@mcpc-tech/acp-ai-provider` package; not in-repo, node_modules absent in clone).
- **Bridged to Vercel AI SDK:** `streamText({ model: provider.languageModel(id), tools: provider.tools })`
  (`codex.ts:1764-1774`) → `toUIMessageStream` → chunk loop (`:1838-1861`). Subscription **`codex.chat`**
  (`codex.ts:1558-1579`); renderer `acp-chat-transport.ts:161`. Tool verbs normalized
  `Read/Run/List/Search → Read/Bash/Glob/Grep` (`shared/codex-tool-normalizer.ts:3-14`).
- **Models:** default `DEFAULT_CODEX_MODEL = "gpt-5.3-codex/high"` (`codex.ts:139`); catalog
  `gpt-5.3-codex, gpt-5.2-codex, gpt-5.1-codex-max, gpt-5.1-codex-mini` × thinking `low/medium/high/xhigh`
  (`lib/models.ts:9-30`); model string `` `${id}/${thinking}` `` (`acp-chat-transport.ts:106`).
- **Auth/env:** `buildCodexProviderEnv` overlays shell env + `CODEX_API_KEY` if app-managed
  (`codex.ts:1120-1147`); `authMethodId` `codex-api-key`|`chatgpt`|`openai-api-key`
  (`codex.ts:1149-1163`). Login/status/logout + MCP mgmt spawn a **separate `codex` CLI**
  (`codex login|logout|mcp list|mcp add|mcp remove`, `codex.ts:1289-1507`). Usage tailed from
  `~/.codex/sessions/YYYY/MM/DD/*-{sessionId}.jsonl` (`codex.ts:446-637`).

## C.3 — Bundled binaries
- `scripts/download-claude-binary.mjs` → native **`claude`** binary v**2.1.45** from GCS
  (`storage.googleapis.com/claude-code-dist-…`), SHA-256 verified, 6 platform dirs →
  `resources/bin/{platform}/claude`.
- `scripts/download-codex-binary.mjs` → **`codex`** CLI v**0.98.0** from `openai/codex` GitHub
  releases (tag `rust-v{version}`) → `resources/bin/{platform}/codex`.
- `codex-acp` bundled via `asarUnpack` of `node_modules/@zed-industries/codex-acp*` (`package.json:179-184`).
- Downloads run in the `release` script, not `postinstall` — a fresh `bun i` does NOT fetch them.
- **None are taken from PATH for engine execution** — all spawned from bundled paths.

## C.4 — Ollama
Real local fallback that **rides the Claude SDK** by redirecting base URL to `localhost:11434`
(`lib/ollama/detector.ts:75-85` → the same `customConfig` harness). Direct `/api/generate` used
only for chat-title + commit-message (`routers/ollama.ts:16-58,106,134`). Detection via
`/api/tags` + a hardcoded coding-model preference list (`detector.ts:36-58`). Code warns it
often fails because Ollama may not implement the Anthropic `/v1/messages` shape
(`claude.ts:2448-2466`).

## C.5 — Model catalog: HARDCODED (no live fetch)
Grep for `/models`/`/v1/models` = zero HTTP hits. `CLAUDE_MODELS` + `CODEX_MODELS` are static
lists in `lib/models.ts`; duplicated at `active-chat.tsx:372-374`, `automations/_components/constants.ts:40-42`.
Only Anthropic HTTP calls are the OAuth token endpoint (`claude-token.ts:206`) and a `HEAD
api.anthropic.com` probe (`network-detector.ts:41`). **⇒ the owner's "auto-update from live
provider lists" requirement is net-new design** (see §G for the live `/models` endpoints).

## C.6 — Auth model (two independent scopes)
- **(a) 21st.dev product account:** OAuth deep-link → `POST 21st.dev/api/auth/desktop/exchange`,
  refresh `/desktop/refresh` (`auth-manager.ts:45-111`); stored `{userData}/auth.dat` via
  Electron `safeStorage` (`auth-store.ts:42-64`).
- **(b) Claude Code engine credentials:** default is a **subscription OAuth token** (obtained via
  a 21st-server CodeSandbox dance, `claude-code.ts:174-196`), OR imported from the system keychain
  `security find-generic-password -s "Claude Code-credentials"` (`claude-token.ts:41-63`), used as
  `CLAUDE_CODE_OAUTH_TOKEN`. Shell `ANTHROPIC_API_KEY`/`AUTH_TOKEN`/`BASE_URL` **take precedence**
  when present. **Multi-account** concept: `anthropic-accounts.ts` (list/add/setActive/remove,
  safeStorage-encrypted).
- Codex auth: ChatGPT subscription (`codex login`) or `CODEX_API_KEY`.

---

# §D — LICENSE + DECOUPLING (agent report — fully-local, no-account, no-telemetry)

**LICENSE: stock Apache-2.0, CONFIRMED.** `LICENSE` is the verbatim Apache License 2.0 header
(6 "apache" mentions); grep for `non-commercial|SSPL|Commons Clause|Business Source|no charge`
= zero restrictive terms. `.env.example` states "All variables below are OPTIONAL - the app
works without them." No CLA/non-commercial rider found. Dependency copyleft/poison audit is a
synthesis TODO (deps list in §A / `package.json:37-141`), but the app itself is cleanly
Apache-2.0 — safe to fork + embed commercially. **[VERIFY at synthesis: scan the full dep tree
for any AGPL/SSPL/BUSL transitive.]**

**Headline decouple verdict:** the core loop (create project → open chat → run Claude Code /
Codex locally against a local folder) is **fully self-contained, zero cloud/account at the
engine level**. The ONLY true blocker is a **mandatory 21st.dev login wall at window-creation**;
telemetry has one hardcoded PostHog key. Three surgical edits fix both.

## D.1 — The login wall (the one true blocker)
`src/main/windows/main.ts:783-834`: every window load runs `authManager.isAuthenticated()`
(`:789`); if true → load `index.html` (React app), else → `loadFile(login.html)` (`:825-833`).
`isAuthenticated()` (`auth-store.ts:141-148`) = non-expired 21st.dev token in `auth.dat`. With
no token the app **only ever shows `login.html`** — the chat is unreachable. Logout re-gates
(`main.ts:359-374`).
**Escape hatches proving the local loop needs no account:** `App.tsx:106-114` auto-skips
onboarding if `claudeCode.hasExistingCliConfig` sees `ANTHROPIC_API_KEY`; `BillingMethodPage`
offers `api-key` / `custom-model` / Codex lanes (`billing-method-page.tsx:34-76`), none needing
21st; `claude-code.ts:319-330 importSystemToken` reads a local Claude token from Keychain /
`~/.claude/.credentials.json`; Ollama offline lane (`claude.ts:980-1038`).

## D.2 — Telemetry inventory
- **Main PostHog (the live one):** `lib/analytics.ts:13` **hardcoded fallback key**
  `"phc_wM7gbrJhOLTvynyhnhPkrVGDc5mKRSXsLGQHqM3T3vq"` (fires even with no `.env`), host
  `us.i.posthog.com`. `initAnalytics()` (`:112-130`) only bails when `isDev()` — i.e. **any
  packaged build initializes PostHog.** Gated further by `userOptedOut`.
- **Renderer PostHog:** `VITE_POSTHOG_KEY` with **no fallback** → OFF unless env set.
- **Sentry (main/renderer/preload):** all `Sentry.init()` calls are DSN-gated / bare (no-op
  without `MAIN_VITE_SENTRY_DSN`) — `index.ts:62-78`, `main.tsx:5-9`, `preload/index.ts:5-9`.
- CSP allows `*.posthog.com` (`index.html:6`).

## D.3 — Cloud endpoints (severability)
Only `api.anthropic.com` (Claude) / `api.openai.com` (Codex) are on the local critical path.
Everything with `21st.dev`, `cdn.21st.dev` (auto-update feed), `us.i.posthog.com`, `*.sentry.io`,
`1code.dev` (changelog links) is severable. `signedFetch`/`streamFetch` (`main.ts:410-535`)
**hard-require the 21st token and only call 21st.dev** → 100% cloud, NOT on the local path
(local chat uses `ipc-chat-transport.ts` → `claude.chat` publicProcedure → SDK).

## D.4 — Auto-updater
Feed `cdn.21st.dev/releases/desktop` (`auto-updater.ts:29`, `package.json:256`); triggered only
`if (app.isPackaged)` on startup + window focus (`index.ts:946-954`). Disable = remove that block.

## D.5 — Decoupling plan (3 minimal edits + optional hardening)
1. **Remove the login wall:** `windows/main.ts:789` force `isAuth=true` / delete the
   `else{login.html}` branch → lands on `BillingMethodPage` (or auto-skips with `ANTHROPIC_API_KEY`).
2. **Kill main PostHog:** `lib/analytics.ts:13` set fallback to `""` (or early `return` at `:112`).
3. **Disable updater:** remove the `index.ts:946-954` `if(app.isPackaged){…}` block.
Optional hardening: point `getBaseUrl()`/`getApiUrl()` (`index.ts:83-88`, `config.ts:13-18`)
offline; tighten CSP `connect-src` to `'self' + api.anthropic.com`; strip bare `Sentry.init()`
calls. **Do NOT touch** `claude/env.ts`, `claude-token.ts`, chat/spawn logic, `codex.ts`,
`ipc-chat-transport.ts`, `db/*`, bundled binaries. Net outbound after decouple: `api.anthropic.com`
(+ OpenAI for Codex), or nothing under Ollama.

---

# §E — MCP + PLUGINS + SKILLS + WORKTREE + PREVIEW (agent report)

## E.A — MCP config layer (file-based, mirrors Claude Code CLI; NOT a DB table)
Logic in `src/main/lib/claude-config.ts`. Five sources merged (precedence
`project > global > plugin`, `claude.ts:1338-1343`): `~/.claude.json` (global+project),
`~/.claude/.claude.json`, `~/.claude/mcp.json`, `<projectRoot>/.mcp.json`, plugin `.mcp.json`.
`${VAR}` / `${VAR:-default}` expansion (`claude-config.ts:304-355`). Worktree paths resolve
back to the origin project (`resolveProjectPathFromWorktree`, `:224-293`).
- **Injected into Claude** as the SDK option **`options.mcpServers`** (in-process object, no
  file written for the agent) — assembled `claude.ts:1266-1376`, passed `claude.ts:1746-1761`,
  token-refreshed + working-filtered (`:1346-1365,1558`).
- **Injected into Codex** via ACP **`session.mcpServers`** from a **separate `~/.codex` registry**
  read by `codex mcp list --json` (`codex.ts:810-885`); add/remove via `codex mcp add|remove`
  (`codex.ts:1474-1507`), global-scope only.
- **Lifecycle (Claude):** `trpc.claude.addMcpServer` → `updateMcpServerConfig` →
  `writeClaudeConfig` to `~/.claude.json` (`claude.ts:2927-3006`, mutex `configMutex`); list
  (`:2775-2831`), OAuth (`startMcpOAuth` `:2902`, `getMcpAuthStatus` `:2916`), remove (`:3008`).
- **Marketplace = discovery only, no install mutation** in the desktop app (reads
  `~/.claude/plugins/marketplaces/`, `plugins/index.ts:65-142`); install delegated to the Claude
  Code CLI `/plugin` flow. Plugin-MCP auto-injection currently disabled in the main chat path
  (`active-chat.tsx:5670`).
- **⇒ Auto-inject seam for Epistemos's own MCP servers:** write them into `~/.claude.json`
  `mcpServers` (global) — the app **mtime-caches and re-reads every message** (`claude.ts:1272-1300`);
  for Codex, run `codex mcp add` or seed `~/.codex`. **No unified injection point — target both.**

## E.B — Plugins vs skills vs commands (all filesystem, markdown)
- **Skill = Anthropic Agent Skills (`SKILL.md`) format** — `~/.claude/skills/`, `{cwd}/.claude/skills/`,
  plugin `skills/` (`skills.ts:115-149`), YAML frontmatter via `gray-matter` (`:23-35`).
- **Command = slash command** `.md` in `.claude/commands/`, nested folders namespace
  `git/commit.md → git:commit` (`commands.ts:84-92`).
- **Plugin = bundle** of commands+skills+agents+optional `.mcp.json` under `~/.claude/plugins/marketplaces/`.
- **Loaded into the agent by the SDK's `settingSources: ["project","user"]`** (`claude.ts:1772-1774`),
  NOT by app code — routers only feed the UI pickers. **⇒ seed by writing files, no API needed.**
  Path-traversal guarded (`isValidEntryName`).

## E.C — Session + git-worktree workflow (one worktree per chat, optional)
`trpc.chats.create` with `useWorktree` → `createWorktreeForChat` (`chats.ts:391-410`) →
`git -C <mainRepo> worktree add <path> -b <branch> <commit>` (`worktree.ts:170-183`). Worktrees
at **`~/.21st/worktrees/{projectSlug}/{adjective-landscape}`** (`worktree.ts:930-933`). Background
setup runs `.cursor/worktrees.json` or `.1code/worktree.json` `setup-worktree` commands
(`worktree-config.ts:47,216-223`). DB `chats.{worktreePath,branch,baseBranch}` written
(`chats.ts:414-421`); **local mode** sets `worktreePath = project.path` (`:444-448`). Agent cwd =
worktree via `options.cwd` (Claude, `claude.ts:1750`) / `session.cwd` (Codex, `codex.ts:1260`).
Cleanup `git worktree remove --force` on archive/delete (`worktree.ts:226-245`, `chats.ts:542,652`).

## E.D — Live preview: NO local dev-server
`AgentPreview` embeds a **CodeSandbox-hosted** URL `https://${sandboxId}-${port}.csb.app` in an
iframe; comment says **"Desktop mock"** (`agent-preview.tsx:26-27`); `codesandbox-constants.ts:1-4`
is "Mock … for desktop". Gated behind cloud-only `sandbox_id` (`agents-content.tsx:834`), never set
for local chats. **No `devServer`, no port detection, no `spawn npm/vite dev`.** A real local
preview would be built from scratch (defer / native later). Only `listen()` calls are OAuth
callbacks + HMR.

## E.E — File watching (chokidar)
Watches only `.git/index` + `.git/HEAD` per worktree (FD-efficient, `git-watcher.ts:105-125`),
debounced 100ms, one watcher per worktree. Pushes **`git:status-changed`** to the subscribing
window (`ipc-bridge.ts:50-58`); renderer invalidates React Query diff keys
(`use-file-change-listener.ts:81-108`). No generic `file-changed` channel.

---

# §F — EPISTEMOS ProAgent/June INTEGRATION (first-hand agent read — the replication catalog)

**Two embedding architectures already exist; pick the closer analog per concern:**

| | **Pro / OpenChamber (`ProAgent*`)** | **MAS / June (`JuneAgent*`)** |
|---|---|---|
| Build gate | `#if !EPISTEMOS_APP_STORE` | `#if EPISTEMOS_APP_STORE` |
| Web delivery | **Supervised localhost Node server** (real `http://127.0.0.1:<ephemeral>`) | **Custom `june://` WKURLSchemeHandler** (no server) |
| Backend | Child procs: `node` web server + `opencode` (+ optional `goosed`) | **In-process** Swift `JuneAgentGateway` |
| JS bridge | `window.__OPENCHAMBER_DESKTOP__.invoke` → 1 WK handler | Tauri shim faking `window.__TAURI_INTERNALS__` → 5 WK handlers |
| Keep-alive | App-scoped singleton supervisor + `@State` WebPage | Process-lifetime `JuneAgentSurfaceHolder` singleton WKWebView |

**⇒ For 1Code (Electron, own Node backend): clone the Pro/OpenChamber supervisor pattern for
the backend, and reuse June's Tauri-shim file as the exact template for a
`onecode-electron-shim.js` faking `ipcRenderer`/`window.electron`/`window.desktopApi`.**

## F.1 — Supervisor lifecycle — `Epistemos/ProAgent/ProAgentRuntimeSupervisor.swift`
`@MainActor @Observable`, singleton `static let shared` (L77), gated `#if !EPISTEMOS_APP_STORE`.
- **Status enum** (L68-75): `idle | unavailable(String) | starting | running(ProAgentConnection) |
  failed(String) | stopped`. `ProAgentConnection` (L9-17): `uiBaseURL, uiPort, opencodePort,
  goosePort: Int?` (nil = optional engine absent — capability truth, never faked).
- **API:** `start()` (L121-175), `stop()` (L177-206), `markRuntimeFailed(_:)` (L208-229);
  observable `status`, `lastDiagnostic` (L109-110).
- **Port allocation** (L86, L711-720): ephemeral **`49_300...64_900`** only, 48 attempts. TWO
  documented reasons (L80-86): dodges occupied ports AND sits **above the WHATWG fetch bad-port
  blocklist** — opencode on port 4190 ("sieve") made every SSE proxy hop die with
  `cause: bad port`. Uses `GooseRuntimeSupervisor.isLoopbackTCPPortAvailable(_:)` (raw
  `socket()`+`SO_REUSEADDR`+`bind()` to `127.0.0.1:port`).
- **Env injection** (L728-775): `childEnvironment(...)` allowlist-only inherited env
  `{PATH,HOME,USER,LOGNAME,TMPDIR,LANG,LC_ALL,LC_CTYPE,TERM,TZ}` (L91-93); PATH rebuilt from
  child bin dirs + canonical tool dirs + `~/.local/bin`,`~/bin`. Web server gets
  `OPENCODE_PORT`, `OPENCODE_SKIP_START=true` (attach mode), `EPISTEMOS_EMBED=1`.
- **⭐ Off-main spawn (the #1 instant-open piece)** (L416-455): all children `.run()` inside
  `Task.detached(priority:.userInitiated)`, each `Process` carried across the actor boundary in
  a `ProAgentSpawnBox: @unchecked Sendable` (L27-29). Documented root cause (L20-23): an inline
  `@MainActor` spawn **froze the UI** (hang-trace 2026-07-01) because `run()` blocks hundreds of
  ms–seconds on **OS code-signature validation of notarized binaries**. NEVER spawn on main.
- **Readiness/health** (L467-490, L673-684): poll `healthCheck` every 200ms until `readinessTimeout
  = .seconds(40)`; GET `/health` requires **both** `"status":"ok"` AND `"isOpenCodeReady":true`.
  Optional-engine readiness is OFF the critical path (goose re-emits `.running` when it answers,
  L498-526).
- **Termination**: `installTerminationHandler` (L551-557) + identity-guarded `handleChildExit`
  (L559-605, a prior child's handler can fire post-restart — react only to owned procs);
  `terminateTrackedProcess` (L622-632) → `orphanCleanup.cleanupProcessTree` then `terminate()`.

## F.2 — The JS bridge pattern (the shim template)
- **Pro one-channel** (`ProAgentSurfaceView.swift`, `EpistemosDesktopBridge:
  WKScriptMessageHandler` L64-131): channel `epistemosDesktop`; injects
  `window.__OPENCHAMBER_DESKTOP__.invoke(cmd,args)` →
  `webkit.messageHandlers.epistemosDesktop.postMessage({command,args})` at `.atDocumentStart`
  (L214-252); handler validates + routes `desktop_notify`→UNUserNotification, `speak`→TTS.
- **⭐ June Tauri shim** (`.june-web-stage/tauri-internals-shim.js`, 18 KB — the exact template
  for a bidirectional Electron shim): fakes `window.__TAURI_INTERNALS__ = { invoke,
  transformCallback, ... }` (L460-470). `invoke(cmd,args)` → `hostInvoke` → posts
  `{callId,cmd,args}` to `webkit.messageHandlers.epistemosInvoke.postMessage` and returns a
  Promise keyed by `callId` (L352-373, 30s timeout). Native replies via
  `window.__EPISTEMOS_TAURI_SHIM__.resolveInvoke(callId, {v:payload}, null)`
  (`JuneAgentBridge.swift:137`, `{v:}`-wrapped so scalars survive JSON). **HOST_MODE gate:**
  native injects `window.__EPISTEMOS_HOST__ = true` before the shim. **Streaming stand-in:** the
  shim patches `window.WebSocket` so `epistemos://` URLs become a `GatewaySocket` posting frames
  to `epistemosGateway`; native pushes deltas via `gatewayDeliver(frameJSON)`. **5 WK channels**
  (`JuneAgentBridge.swift` L19-26): `epistemosInvoke, epistemosGateway, epistemosEvents,
  epistemosSpeak, epistemosConsole`.
- **Bridge security discipline (replicate):** every JS→native payload shape-validated + length-
  capped (`JuneAgentBridge.swift:45-103`); every native→JS reply injected via `jsStringLiteral`
  (L349-369) escaping `\ " \n U+2028 U+2029` + control chars — injected content can't break out.
  **No secret ever crosses into JS** (gateway token always `""`).

## F.3 — Provider key bridge (Keychain → child env)
`ProAgentRuntimeSupervisor.bridgedProviderEnvironment` (L943-955), fed into the engine child env
at spawn (L283-296). Bridged keys (L98-102): `ANTHROPIC_API_KEY, OPENAI_API_KEY, GOOGLE_API_KEY,
PERPLEXITY_API_KEY, OPENROUTER_API_KEY, GROQ_API_KEY, MISTRAL_API_KEY, XAI_API_KEY,
DEEPSEEK_API_KEY, HF_TOKEN`. Each mapped env→Keychain key via
`AppBootstrap.agentCoreKeychainKey` (e.g. `ANTHROPIC_API_KEY → epistemos.anthropic.apiKey`),
`Keychain.load`, trimmed/validated (≤4096 bytes, no NUL). Key crosses exactly ONE boundary
(supervisor→child env), never the binary or webview JS. **⭐ Time-bounded (L972-988):** the
sync `SecItemCopyMatching` can block forever on a first-launch Keychain-ACL prompt — the bridge
races reads against a 4s deadline and spawns WITHOUT bridged keys on timeout (engine can auth
interactively) rather than wedging the surface. Replicate this bounding.

## F.4 — MCP auto-inject / vault fusion — `Epistemos/Work/WorkOpenCodeRuntime.swift`
- `writeMergedFusionConfig(stdioServerPath:vaultRoot:nativeMCP:)` (L274-292) — LIVE path. Reads
  the durable `opencode.json` (traversal-safe `O_NOFOLLOW`), **deep-merges ONLY Epistemos's own
  entries**, writes back 0600. Called from `ProAgentRuntimeSupervisor.run()` L308-316.
- `mergedOpenCodeConfigJSON` (L223-268) writes into `"mcp"`: `epistemos-vault` (`type:"local"`,
  `command:[<abs omega_mcp_stdio>]`, `environment:{EPISTEMOS_VAULT_ROOT:<vault>}`, `enabled:true`)
  + optional `epistemos-native` (`type:"remote"`, `url:http://127.0.0.1:<port>/mcp`, bearer). It
  PRESERVES all user-installed MCP servers (merge-preservation is load-bearing — "MCP never
  saved after I quit"). `OPENCODE_CONFIG` → persistent `Application Support/Epistemos/opencode/
  opencode.json`, passed to BOTH the engine child and the web server. Honest no-vault: omit
  `OPENCODE_CONFIG` entirely if no vault / missing server.
- Stdio server `omega-mcp/src/bin/omega_mcp_stdio.rs`: newline JSON-RPC over stdin/stdout,
  vault root via `EPISTEMOS_VAULT_ROOT`; `initialize`/`ping`/`tools/call`→`execute_vault_tool`/
  `tools/list` (honestly scoped to real vault+graph tools). Tools (`omega-mcp/src/vault.rs`
  `is_vault_tool` L962-999): `vault.read/write/list`, `search_notes`, `backlinks/outlinks/
  dangling_links/note_links/orphan_notes`, `patch_note`, graph verbs. Built + staged by
  `build-opencode-runtime.sh §2.5` → `Resources/opencode-runtime/bin/omega_mcp_stdio`.
- Richer optional native MCP: `Epistemos/Work/WorkNativeMCPHost.swift` (in-process loopback HTTP
  MCP, bearer auth, exposes full tool set incl. computer-use), registered `epistemos-native`.

## F.5 — Every native↔surface feature (file:line, to replicate)
| Feature | File:line | How |
|---|---|---|
| Theme bridge (Pro) | `ProAgentThemeBridge.swift:123-168` | ~60 CSS custom props as **inline `!important` on documentElement** + pin `.dark/.light` + `MutationObserver` re-assert; live switch via `page.callJavaScript` on theme change |
| Theme bridge (June) | `JuneAgentSurfaceView.swift:638-725` | override `--brand` + surface tokens (June derives via `color-mix`); pin `webView.appearance` + `underPageBackgroundColor` for pre-paint match |
| Nav pill | `ProAgentNavBar.swift:29-92` / `JuneAgentNavBar.swift:9-67` | native SwiftUI capsule "Epistemos · New Chat · All Chats" in `RootView.rootToolbarControls` (`RootView.swift:467-500`); buttons post NotificationCenter/`JuneAgentIntents` |
| Chrome intents (pill→SPA, NO reload) | `ProAgentSurfaceView.swift:606-619` / `JuneAgentChrome.swift:14-47` | intents → `window.dispatchEvent(new CustomEvent('epistemos-chrome-intent'))` via `callJavaScript`; URL never reloaded (reload kills live session) |
| All-chats sheet | `ProAgentAllChatsSheet.swift` / `JuneAgentChrome.swift:76-204` | native sheet; Pro fetches merged rows from web server, badges + dir-grouping, distinguishes fetch-fail from empty |
| Read-aloud | `ProAgentSurfaceView.swift:92-104` / `JuneAgentBridge.swift:110-121` | native `EpistemosSpeechSynthesizer`, no audio in JS; `window.__EPISTEMOS_TTS_AVAILABLE__` **honest gate** (button not injected unless native TTS ready) |
| Notification bridge | `ProAgentSurfaceView.swift:110-126` | `desktop_notify` → `UNUserNotificationCenter` (title/body capped 120/500) |
| External-links reroute | `ProAgentSurfaceView.swift:32-55` (`ProAgentNavigationDecider`) / `JuneAgentSurfaceView.swift:562-627` | **origin allowlist** (only registered loopback port) → any other http(s) → `NSWorkspace.shared.open` + `.cancel`; June also handles `window.open`/`_blank` via `WKUIDelegate` |
| Blank-screen resilience | `ProAgentSurfaceView.swift:163-190, 454-540` | `.atDocumentStart` error-trap into `window.__epistemosPageErrors`; render probe polls `#root`; bounded backoff reload; circuit breaker `maxRuntimeRetryAttempts=8` |
| Keep-alive across tabs | `ProAgentSurfaceView.swift:194,323-333` / `JuneAgentSurfaceHolder:14-25` | WebView survives tab-away; `.onDisappear` tears down only view-local monitors; `loadedConnectionKey` guards re-load |
| Perf hooks | `ProAgentPerf.swift` / `JuneAgentPerf.swift` | `OSSignposter(subsystem:"io.epistemos.core",category:"agent_surface")` + metrics vs `docs/perf-budgets.toml [agent_surface]` (cold 1500 / warm 100 / first-token 1200) |
| Mascot overlay seam | `ProAgentNavBar.swift:18-24` / `JuneAgentChrome.swift:211-230` | `Color.clear` overlay ABOVE the WebView, `allowsHitTesting(false)` — Plan-5 mascot seam, never in donor DOM |
| Surface mount | `Views/Landing/LandingView.swift:186-195` | `case .agent:` → `JuneAgentSurfaceView()` (MAS) / `ProAgentSurfaceView(theme:)` (Pro) |

## F.6 — Packaging (bundle web + binaries, locate at runtime)
- **Pro** `build-openchamber-web.sh`: pinned **Node 25.8.2** → `Resources/openchamber-runtime/bin/
  node`; pinned **opencode 1.17.12** → `bin/opencode-triple` (NAMED to dodge flattened-resource
  `Multiple commands produce` collision); builds embed dist (`VITE_EPISTEMOS_EMBED=1`, **refuses a
  dist with a service worker**) + pruned prod node_modules + `server/` → **one
  `openchamber-web.tar.gz`** (resource copy flattens dir trees). Native modules built with the
  pinned node's npm (ABI match). Runtime: resolvers with structured + flattened fallbacks;
  **tarball unpack to `Application Support/…`, size+mtime version-stamped so it unpacks once**
  (`ProAgentRuntimeSupervisor.swift:881-938`).
- **June** `build-june-web.sh` → `.june-web-stage/` (dist + shim, OUTSIDE Resources/ to avoid the
  flatten collision); `bundle-app-runtime-assets.sh` rsyncs into `Contents/Resources/JuneWeb/`;
  served via `JuneSchemeHandler` (`june://`, NOT `file://` — WebKit CORS-blocks ES modules on
  file:// origins) with strict CSP + traversal confinement.

## F.7 — Crash-durable orphan reaping — `ProAgent/ProAgentChildLedger.swift`
In-memory trackers die with the app → leaked children on crash (observed: node+opencode+goosed
surviving 3 crashes). Ledger persists child identity **(pid, kernel start time µs)** →
`Application Support/Epistemos/pro-agent-children.json` (L14-40); `record/forget/clear` on
spawn/exit; **`sweepStaleChildren`** (L114-146) runs at NEXT `start()`: TERM matching-identity
strays, 1.5s grace, then KILL. PID reuse defeated by start-time match. **Replicate for 1Code's
Electron-main-replacement Node process + node-pty/git children.**

---

# §G — LIVE MODEL CATALOG + PROVIDER ENDPOINTS (web-verified, all accessed 2026-07-05)

> Every fact below is primary-source verified (provider docs / official GitHub / npm registry).
> **Stale-fact corrections vs the brief's assumptions are flagged ⚠️.** UNVERIFIED items are
> called out — never hardcode them without a runtime check.

## G.1 — Anthropic (Claude) — the harness base
- **Model IDs (CONFIRMED):** `claude-fable-5` (most capable public model; 1M ctx / 128K out;
  $10/$50 per MTok; thinking always-on; GA 2026-06-09, redeployed globally ~2026-07-01),
  `claude-opus-4-8` (current Opus; 1M/128K; $5/$25; adaptive thinking), `claude-sonnet-5`
  (current Sonnet — ⚠️ NOT `sonnet-4-x`; $3/$15, $2/$10 intro thru 2026-08-31),
  `claude-haiku-4-5-20251001` (alias `claude-haiku-4-5`; 200K/64K; $1/$5). `claude-mythos-5`
  exists but invitation-only (Project Glasswing) — do NOT route by default. **4.6+ IDs are
  dateless pinned snapshots** (no date suffix); older ones carry dates.
- **Messages API:** `POST https://api.anthropic.com/v1/messages`, headers `x-api-key` +
  `anthropic-version: 2023-06-01` (version header REQUIRED).
- **Claude Code model env (the harness knobs):** `ANTHROPIC_MODEL` (alias OR full name; per
  session), `ANTHROPIC_DEFAULT_OPUS_MODEL` / `..._SONNET_MODEL` / `..._HAIKU_MODEL` /
  `..._FABLE_MODEL`, `CLAUDE_CODE_SUBAGENT_MODEL`. ⚠️ **`ANTHROPIC_SMALL_FAST_MODEL` is
  DEPRECATED → use `ANTHROPIC_DEFAULT_HAIKU_MODEL`.** `--model` flag > `ANTHROPIC_MODEL` >
  `model` setting. Default alias resolution on the Anthropic API: `opus`→Opus 4.8, `sonnet`→
  Sonnet 5 (Fable 5 is NEVER the default — select via `/model fable` or `best`).
- **Auth precedence (first match wins):** Bedrock/Vertex/Foundry creds > `ANTHROPIC_AUTH_TOKEN`
  (Bearer, for gateways/proxies) > `ANTHROPIC_API_KEY` (x-api-key) > `apiKeyHelper` script >
  `CLAUDE_CODE_OAUTH_TOKEN` (from `claude setup-token`, 1-year, `sk-ant-oat01-` prefix) >
  subscription OAuth via `/login`. **⚠️ CRITICAL: the `setup-token`/`CLAUDE_CODE_OAUTH_TOKEN`
  works ONLY with Claude Code and is REJECTED by the Messages API** — you cannot reuse it for a
  raw `/v1/messages` call. Creds stored in macOS Keychain / `~/.claude/.credentials.json` (0600).
- **List models:** `GET https://api.anthropic.com/v1/models` (x-api-key + anthropic-version;
  **cursor pagination** `after_id`/`before_id`/`limit` (default 20, max 1000); response
  `data[].id` + `has_more`/`first_id`/`last_id` + rich `capabilities`). Genuinely paginated —
  loop on `after_id=last_id` while `has_more`.

## G.2 — OpenAI Codex
- **CLI `codex` v0.142.5** (npm `@openai/codex` + native Rust binary + Homebrew). ⚠️ **Default
  model is `gpt-5.5`** (NOT gpt-5.3-codex). Picker: `gpt-5.5`, `gpt-5.4`, `gpt-5.4-mini`,
  `gpt-5.3-codex-spark` (ChatGPT-Pro-only). ⚠️ `gpt-5.3-codex` is deprecated in the CLI's ChatGPT
  picker but active on the API — plan/account-gated (verify with a live `codex /model`).
- **Auth:** `codex login` (ChatGPT OAuth, default) OR `OPENAI_API_KEY` via
  `printenv OPENAI_API_KEY | codex login --with-api-key`. Headless: `--device-auth`. Known
  conflict: can't switch to API-key while a ChatGPT session is active (logout first).
- **⚠️ ACP: the CLI has NO native ACP** (it exposes `codex app-server` = its own JSON-RPC + `codex
  mcp-server`). ACP is via an external bridge, and **`@zed-industries/codex-acp` (0.16.0) is
  DEPRECATED → superseded by `@agentclientprotocol/codex-acp` (1.1.0)**. ⚠️ **1Code pins the OLD
  deprecated `@zed-industries/codex-acp@0.9.3`** (`package.json:76`) — the fork should migrate.
- **List models:** `GET https://api.openai.com/v1/models` (Bearer, no pagination, `data[].id`).

## G.3 — Moonshot Kimi (via the ANTHROPIC_BASE_URL harness)
- ⚠️ **Current first-party IDs are DOTTED:** `kimi-k2.7-code` (thinking always-on, 256K),
  `kimi-k2.6`, `kimi-k2.5`. The dashed `kimi-k2-thinking`/`kimi-k2-0711-preview` are the
  open-weights/third-party host names — absent from current `platform.kimi.ai` docs; verify via
  live `/v1/models` before use.
- **⭐ Anthropic-compat base URL (CONFIRMED VERBATIM):**
  ```
  ANTHROPIC_BASE_URL=https://api.moonshot.ai/anthropic      # no /v1, no /messages
  ANTHROPIC_AUTH_TOKEN=<MOONSHOT_API_KEY>
  ANTHROPIC_MODEL=kimi-k2.7-code
  ANTHROPIC_DEFAULT_{OPUS,SONNET,HAIKU}_MODEL=kimi-k2.7-code
  CLAUDE_CODE_AUTO_COMPACT_WINDOW=262144
  ```
  China host `https://api.moonshot.cn/anthropic`. **Keys are `.ai`/`.cn` domain-bound** (cross-use → 401).
- **OpenAI-compat:** `https://api.moonshot.ai/v1`. **Official Kimi CLI EXISTS** (MoonshotAI/kimi-cli,
  **Python** — `uv tool install --python 3.13 kimi-cli` or `curl -LsSf https://code.kimi.com/install.sh | bash`;
  `/login` browser OAuth for the "Kimi Code" subscription, or paste API key). Auth: Bearer
  `MOONSHOT_API_KEY`; OAuth is subscription-scoped only.
- **List models:** `GET https://api.moonshot.ai/v1/models` (Bearer, `data[].id`, example id `kimi-k2.5`).

## G.4 — Zhipu GLM (via the ANTHROPIC_BASE_URL harness)
- ⚠️ **STALE-FACT CORRECTION: GLM has moved past 4.6.** Current flagship `glm-5.2` (1M ctx,
  announced 2026-06-13; `glm-5.2[1m]` for the 1M lane); **current Claude Code default `glm-4.7`**;
  `glm-4.6`/`glm-4.5-air` are older-gen fallbacks. Do NOT ship `glm-4.6` as "current."
- **⭐ Anthropic-compat base URL (CONFIRMED):** `ANTHROPIC_BASE_URL=https://api.z.ai/api/anthropic`
  (intl, USD) / `https://open.bigmodel.cn/api/anthropic` (China, CNY). `ANTHROPIC_AUTH_TOKEN=
  <z.ai key>`. **Path has NO `/v1`** (Claude Code appends `/v1/messages`). Default mapping
  `glm-4.7` for all three tiers; recommended override `glm-5.2` for Opus/Sonnet.
- **OpenAI-compat:** general `https://api.z.ai/api/paas/v4`, **Coding-Plan `…/api/coding/paas/v4`**
  (⚠️ using the general endpoint with a Coding Plan silently falls to metered billing; appending
  `/v1` → 404). **No first-party CLI** (ZCode is a GUI); terminal path = the Claude Code harness.
  Auth = **API key (Bearer), NOT OAuth.** Keys: z.ai/manage-apikey (intl) or open.bigmodel.cn (CN),
  region-matched. Coding Plan Lite/Pro/Max (shared model lineup; tiers differ by quota/MCP/priority).
- **List models:** ⚠️ **UNVERIFIED/undocumented** — `GET …/paas/v4/models` is not in official docs
  (`/api-reference/model/list` 404s). Source GLM from models.dev instead, or hardcode w/ config +
  runtime fallback. Do NOT ship a hard dependency on a GLM /models endpoint.

## G.5 — Google Gemini
- ⚠️ **STALE-FACT CORRECTION:** current flagship `gemini-3.5-flash` (GA), current Pro
  `gemini-3.1-pro-preview`; **`gemini-3-pro-preview` is DEPRECATED (shut down 2026-03-09)**;
  `gemini-2.5-pro`/`-flash` still stable but 2 gens old. `gemini-flash-latest` → `gemini-3.5-flash`.
- **⚠️⚠️ BIGGEST OPERATIONAL RISK: On 2026-06-18 Google announced Gemini CLI is transitioning to
  "Antigravity CLI," and the FREE consumer "login with Google" path STOPPED serving Gemini CLI
  requests.** Now needs `GEMINI_API_KEY` (AI Studio; **250 free req/day, Flash-only**), Vertex, or
  paid Gemini Code Assist Standard/Enterprise. The old "free 1,000 req/day via Google login" is
  dead for consumer accounts. **This lane's onboarding story is the shakiest of the six.**
- **CLI `@google/gemini-cli` v0.49/0.50** (`npm i -g` / `brew install gemini-cli` / `npx`). **Node-only
  (Node 20+)** — the one CLI with a hard Node dependency. **ACP: YES** (`gemini --acp`, JSON-RPC/stdio).
  Headless: `gemini -p "…" --output-format json|stream-json`. Auth: Google OAuth (paid only now) /
  `GEMINI_API_KEY` / Vertex (`GOOGLE_GENAI_USE_VERTEXAI=true` + `GOOGLE_CLOUD_PROJECT`).
- **List models:** `GET https://generativelanguage.googleapis.com/v1beta/models` (`?key=` or
  `x-goog-api-key`; ⚠️ id is in **`models[].name`** as `models/gemini-…`, NOT `.id`; paginated
  `pageSize`/`pageToken`).

## G.6 — OpenCode (FREE cloud tier only)
- ⚠️ Repo moved **sst/opencode → `github.com/anomalyco/opencode`** (old URL redirects). CLI:
  `npm i -g opencode-ai@latest` (or `curl -fsSL https://opencode.ai/install | bash` / brew — native binary).
- **Free models via OpenCode Zen** (config format `opencode/<id>`; 21 IDs are `$0` in the live
  catalog, incl. `opencode/big-pickle`, `opencode/grok-code`, `deepseek-v4-flash-free`,
  `glm-4.7-free`, `glm-5-free`, `kimi-k2.5-free`, `minimax-m3-free`, `qwen3.6-plus-free`,
  `nemotron-3-ultra-free`, …). Free promos rotate — re-pull at use time.
- **Access:** `opencode auth login` → "OpenCode Zen" → paste key (`OPENCODE_API_KEY`), endpoint
  `https://opencode.ai/zen/v1` (OpenAI-compatible). ⚠️ **The free tier REQUIRES a Zen account +
  API key — no anonymous/keyless path.** (Exact auth mechanism — GitHub OAuth vs email — and
  whether a card is hard-required for free-only use are UNVERIFIED.)

## G.7 — ⭐ LIVE MODEL-LIST ENDPOINTS (the auto-update backbone)
| Provider | Endpoint | Auth | Pagination | id field |
|---|---|---|---|---|
| **models.dev** | `GET https://models.dev/api.json` | **none** | none (whole DB, ~3 MB) | `providers.<p>.models.<id>.id` + `cost.{input,output}` |
| Anthropic | `GET api.anthropic.com/v1/models` | x-api-key + anthropic-version | cursor (`after_id`) | `data[].id` |
| OpenAI | `GET api.openai.com/v1/models` | Bearer | none | `data[].id` |
| Moonshot | `GET api.moonshot.ai/v1/models` | Bearer | none | `data[].id` |
| Gemini | `GET generativelanguage.googleapis.com/v1beta/models` | `?key=` | `pageToken` | `models[].name` |
| GLM | UNVERIFIED (undocumented) | — | — | use models.dev |

**Auto-update design:** poll **`models.dev/api.json`** (unauthenticated, aggregates all 6 + 75
providers with `id`/`limit`/`cost`) as the primary backbone; free detection =
`cost.input==0 && cost.output==0` within `providers.opencode.models`. Fall back to each provider's
own `/v1/models` (or `/v1beta/models` for Gemini) ONLY for account-scoped availability the
aggregator can't know. OpenAI-compat shape (`{object:"list",data:[{id}]}`) is shared by
OpenAI/Moonshot/(unofficial)Zhipu — one parser; Anthropic (cursor) + Gemini (`name` + pageToken)
need bespoke handling. **Never hardcode a stale list** — this table is the owner's requirement met.

---

# §H — CLI DETECT/INSTALL + AUTH + DEVELOPER-ID SPAWN CONSTRAINTS (web-verified 2026-07-05)

## H.1 — Per-CLI install / detect / auth matrix
| CLI | Install (native-first) | Binary | Detect | Auth (easiest → fallback) |
|---|---|---|---|---|
| **Claude Code** | `curl -fsSL https://claude.ai/install.sh \| bash` (**native, no Node**, → `~/.local/bin/claude`, auto-updates) or npm `@anthropic-ai/claude-code` | `claude` | `claude --version` | **OAuth** (`claude` `/login`, claude.ai subscription) → `claude setup-token` (1-yr `CLAUDE_CODE_OAUTH_TOKEN` for headless) → `ANTHROPIC_API_KEY` |
| **OpenAI Codex** | native Rust binary via installer / `brew install codex`; npm `@openai/codex` (needs Node 22+) | `codex` | `codex --version` | **OAuth** (`codex login`, ChatGPT) → `OPENAI_API_KEY` (`codex login --with-api-key`) |
| **Gemini CLI** | npm `@google/gemini-cli` / `brew install gemini-cli` (**Node 20+ ONLY — no native binary**) | `gemini` | `gemini --version` | ⚠️ Google OAuth now **paid-only**; `GEMINI_API_KEY` (AI Studio, 250/day free Flash) → Vertex |
| **Kimi** | `uv tool install --python 3.13 kimi-cli` OR `curl -LsSf https://code.kimi.com/install.sh \| bash` (**Python**) | `kimi` | `kimi --version` | `/login` browser OAuth (Kimi Code sub) → `MOONSHOT_API_KEY`. **Or NO CLI:** drive via Claude-Code harness (§G.3) |
| **GLM** | **No first-party CLI** (ZCode = GUI) | — | — | drive via Claude-Code harness (§G.4), `ANTHROPIC_AUTH_TOKEN`=z.ai key (API key, not OAuth) |
| **OpenCode** | `curl -fsSL https://opencode.ai/install \| bash` (**native**) / `npm i -g opencode-ai@latest` / brew | `opencode` | `opencode --version` | `opencode auth login` → "OpenCode Zen" → `OPENCODE_API_KEY` |

**Onboarding-ease ranking (owner wants OAuth / easiest):** OAuth-subscription lanes = **Claude Code
(claude.ai), Codex (ChatGPT), Kimi CLI (Kimi Code), Gemini (Google — now paid)**. API-key-only =
**GLM, OpenCode-Zen**. Kimi/GLM through the Claude-Code harness need an API key (no OAuth on that
path). ⇒ Best UX: for a provider with an OAuth CLI, install its CLI and run its login; for
Kimi/GLM-via-harness, a single "paste key" field wired into 1Code's existing `customConfig` UI.

## H.2 — Native-binary vs Node dependency (packaging implication)
- **Node-free native binaries:** `claude`, `codex`, `opencode` → standardize on these, skip Node.
- **Node-required:** **`gemini-cli` (Node 20+)** — the one forcing a Node runtime (bundle Node or
  detect a user install). `kimi-cli` is **Python** (`uv`).
- macOS ships neither Node nor Python — prefer native binaries; treat gemini/kimi as the runtime-
  dependent exceptions.

## H.3 — Developer-ID spawn constraints (primary Apple sources — decisive)
- **⭐ Entitlements are PER-EXECUTABLE and NOT inherited across `exec`.** A spawned child (`node`,
  `claude`, `codex`) runs under ITS OWN signature/entitlements. **The host needs NONE of
  `allow-jit` / `allow-unsigned-executable-memory` / `allow-dyld-environment-variables` /
  `disable-library-validation` merely to spawn CLIs** — those govern only what the host's *own*
  process image does. (Node's V8 JIT runs under Node's signature, not the host's.) Ship the
  minimal hardened set. (Hardened Runtime ≠ App Sandbox; sandbox-inherit is irrelevant to a
  non-sandboxed Developer-ID build.)
- **⭐ GUI apps don't inherit the shell PATH.** A Finder/LaunchServices-launched app gets the
  launchd default `/usr/bin:/bin:/usr/sbin:/sbin` — NO `/opt/homebrew/bin`, `~/.local/bin`,
  nvm, npm-global. Apple's only supported env paths are launch-from-Terminal or Info.plist
  `LSEnvironment`; shell rc files are NOT sourced. **Must:** probe absolute locations
  (`/opt/homebrew/bin`, `/usr/local/bin`, `~/.local/bin`, `~/.bun/bin`, `~/.codex/bin`, npm
  global, nvm dirs) → optionally augment via `zsh -ilc 'echo $PATH'` capture → **always spawn
  with an absolute `executableURL` + explicit merged `environment`.** This is EXACTLY what
  `ProAgentRuntimeSupervisor.childEnvironment` (F.1) already does — reuse it.
- **Quarantine:** `curl`/`scp`/`tar`/`unzip` do NOT set/propagate `com.apple.quarantine`, so a
  CLI fetched via curl or unpacked from a tarball is typically un-quarantined. **But a
  quarantined, unsigned child is HARD-KILLED at `exec`** (Gatekeeper "Terminating process due to
  Gatekeeper rejection" — NOT the friendly double-click "Open Anyway" dialog). For binaries the
  app installs itself: fetch over HTTPS + verify SHA-256/signature, then `xattr -d
  com.apple.quarantine <path>` (only for artifacts you vouch for).
- **Child crash ≠ host crash** (separate process image); a bad child signature blocks only the
  child. No debugger entitlement needed to spawn. Release build must NOT ship `get-task-allow=true`.

## H.4 — CLI auto-detect + install picker (design)
Detect: run each `<binary> --version` against resolved absolute paths (H.3 probe list); parse
version; mark installed/missing/outdated. Install picker: per chosen CLI, run the native installer
(H.1) via a supervised `Process` (off-main, F.1); post-install strip quarantine + re-probe. Prefer
native binaries; for gemini/kimi, detect the Node/Python runtime first and guide the user if
missing. All spawns via absolute path + explicit env (H.3).
