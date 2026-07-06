# Experimental R — Research corpus for the Experimental agent surface (1Code)

**What this is.** The single reference corpus for building the **Experimental** agent surface:
Epistemos embedding **1Code** (`github.com/21st-dev/1code`, npm name `21st-desktop`, Apache-2.0,
Electron) — its React UI inside a native WKWebView, its Node backend supervised by the Swift host.
It houses (1) first-hand source reading of the 1Code clone, (2) live web-verified provider facts,
(3) adversarial verification of the load-bearing claims, and (4) the owner's external research
dossiers — all reconciled. The build plan that consumes this is
[`PROMPT_PLAN_10_EXPERIMENTAL.md`](../prompts/PROMPT_PLAN_10_EXPERIMENTAL.md). Every research cycle
appends here (Part 4) and updates the plan.

**How to read it (trust levels).** Each claim carries a tag so an implementing agent knows what to
trust:
- **[VERIFIED-CODE]** — read first-hand in the clone at the cited `file:line`.
- **[VERIFIED-WEB]** — confirmed against a primary/official source (provider docs / npm / GitHub), 2026-07-05.
- **[ADVERSARIALLY-CONFIRMED]** — a verification pass actively tried to refute it and could not.
- **[EXTERNAL]** — from an owner-supplied dossier; cross-checked and tagged confirmed / corrected / superseded.
- **[UNVERIFIED]** — plausible but not confirmed from a primary source; never hardcode without a runtime check.

**Provenance.** Clone `.research-clones/1code` @ `9f1bc76` ("Release v0.0.72", 2026-02-24) —
GITIGNORED, never committed. 1Code stack: Electron ~39.4.0, React 19.2.1, TypeScript 5.4.5,
Tailwind 3.4.17, tRPC v11.7.1 + `trpc-electron` 0.1.2, Drizzle + better-sqlite3, node-pty 1.1.0,
`@anthropic-ai/claude-agent-sdk` 0.2.45, `@zed-industries/codex-acp` 0.9.3, Jotai/Zustand/React Query.

---

# PART 1 — VERIFIED FOUNDATION (the spine — trust this layer)

## 1.1 Architecture map [VERIFIED-CODE]
- **Process split:** Electron main (`src/main/index.ts` 1019 L + `windows/main.ts` 861 L, window +
  IPC handlers) ↔ React 19 renderer (`src/renderer/`, entry `main.tsx`/`App.tsx`). Preload
  (`src/preload/index.ts`) exposes `window.desktopApi` + the tRPC bridge under context isolation
  (`windows/main.ts:639-644`: `contextIsolation:true`, `nodeIntegration:false`, `webSecurity:true`).
- **The IPC contract = tRPC over Electron IPC via `trpc-electron`.** "All backend calls go through
  tRPC routers, not raw IPC." Server `initTRPC.context<{getWindow: () => BrowserWindow|null}>()`
  (`src/main/lib/trpc/index.ts:8-26`). **21 routers** (`src/main/lib/trpc/routers/`): agents,
  agent-utils, anthropic-accounts, chats, claude, claude-code, claude-settings, codex, commands,
  debug, external, files, index, ollama, plugins, sandbox-import, skills, terminal, voice,
  worktree-config.
- **State:** Jotai (transient UI — selected chat, sidebar, popovers, per-feature atoms like
  `selectedAgentChatIdAtom`), Zustand (persistent layout/tabs/pins → localStorage), TanStack React
  Query (server state via tRPC, auto-cache/refetch). **No React Router** — a feature-folder single
  window with resizable panels.
- **Data:** Drizzle + better-sqlite3 at `{userData}/data/agents.db`; three tables —
  `projects(id,name,path)`, `chats(id,name,projectId,worktreePath,branch,baseBranch,prUrl,prNumber)`,
  `sub_chats(id,name,chatId,sessionId,streamId,mode,messages JSON)`. Auto-migrates from `drizzle/`
  (dev) / `resources/migrations` (packaged).
- **Two engines, no unified abstraction** (separate routers + `chat` subscriptions): **Claude Code**
  (`@anthropic-ai/claude-agent-sdk` in-process → spawns bundled `claude` binary v2.1.45) and
  **Codex** (`@zed-industries/codex-acp` via `@mcpc-tech/acp-ai-provider`, ACP JSON-RPC/stdio,
  spawned binary). Full orchestration in §1.4.
- **Editor/diff/terminal:** Monaco (`@monaco-editor/react`), `@git-diff-view/react` + `@pierre/diffs`,
  node-pty + xterm.

## 1.2 The embedding seam — the crux [VERIFIED-CODE + ADVERSARIALLY-CONFIRMED]
OpenChamber was easy (a web server + WKWebView). 1Code is Electron, but the seam is bounded and
was **actively stress-tested** by two adversarial passes that tried and failed to refute it.

**(A) Transport swap — the linchpin.** The renderer talks to the backend through a `TRPCLink`;
swapping it to a network link makes the whole UI work against a localhost tRPC server.
- Server yields via **standard** tRPC observables: `claude.ts:820-821`
  `.subscription(() => observable<UIMessageChunk>((emit)=>…))`; `codex.ts:1579-1611` identical.
- Renderer consumes the **transport-agnostic** `.subscribe({onData,onError,onComplete})`/`unsubscribe()`
  API (`ipc-chat-transport.ts:202`, `acp-chat-transport.ts:161`) — **zero lines change** under a
  `splitLink([wsLink, httpBatchLink])` swap. `superjson` is symmetric on both ends.
- **CORRECTION (adversarial):** there are **TWO** `ipcLink` client sites, not one — the vanilla
  client `src/renderer/lib/trpc.ts:15-17` AND the React-Query provider client
  `src/renderer/contexts/TRPCProvider.tsx:39-44` (wired `<trpc.Provider client={…}>` at `:47`).
  Both take the same one-line swap. (A third client, `remote-trpc.ts:59-67`, uses `httpLink` to the
  21st.dev cloud — out of scope.)
- **CORRECTION (adversarial):** there are **FOUR** subscription procedures, not two —
  `claude.chat`, `codex.chat`, `terminal.stream` (`terminal.ts:200`), `files.watchChanges`
  (`files.ts:418`). All ride the WS link automatically; a "carry the subscriptions" plan must
  include all four.
- Server side: replace `trpc-electron`'s `createIPCHandler` (`windows/main.ts:661`) with
  `@trpc/server`'s standalone HTTP adapter + `applyWSSHandler`, same `superjson`.
- Minor risk: multi-MB base64 image attachments travel inside subscription inputs as large WS text
  frames (`ipc-chat-transport.ts:218`) — set no restrictive WS `maxPayload`.

**(B) The `desktopApi` bridge table** [VERIFIED-CODE `src/preload/index.ts:25-248`] — ~60 channels;
a `WKScriptMessageHandler` + injected `WKUserScript` replaces the preload. Buckets:
- **Native Swift:** window controls (`:77-83`), zoom (`:104-107` → WKWebView magnification), devtools
  (`:122-123`), clipboard (`:139-140` → NSPasteboard), `app:show-notification` (`:131` →
  UNUserNotificationCenter — NOTE: use UNUserNotification, not the deprecated NSUserNotification the
  dossiers show), `app:set-badge*` (`:129-130` → Dock tile), `shell:open-external` (`:133` →
  NSWorkspace, the external-links reroute), `dialog:save-file` (`:143` → NSSavePanel),
  `vscode:scan/load-theme` (`:246-247`), `webUtils.getPathForFile` (`:15-17`), `app:get-api-base-url`
  (`:136`).
- **Server-push (ws):** `stream:<id>:*` (`:180-194`), `file-changed` (`:221`),
  `git:status-changed` + watcher (`:228-243`), `worktree:setup-failed` (`:235`),
  `window:*-change` (`:92-99`), `shortcut:*` (`:209-214`).
- **Stub/decouple:** all `update:*` (`:33-74`), all `auth:*` (`:147-153,197-205`),
  `analytics:set-opt-out` (`:126`), `api:signed-fetch` (`:156`), `api:stream-fetch` (`:168`).

**(C) The backend→renderer push surface is BOUNDED — the definitive ~13 channels** [ADVERSARIALLY-CONFIRMED]:
`auth:success` (`index.ts:150`), `auth:error` (`index.ts:179`, `main.ts:385`),
`update:manual-check` (`index.ts:642`), `shortcut:open-settings` (`index.ts:660`),
`shortcut:new-agent` (`index.ts:746`), `mcp-auth-completed` (`mcp-auth.ts:285`),
`update:checking|available|not-available|progress|downloaded|error` (`auto-updater.ts` via
`sendToAllRenderers`), `worktree:setup-failed` (`chats.ts:56`), `file-changed` (`claude.ts:2407`),
`git:status-changed` (`git/watcher/ipc-bridge.ts:55`), `window:fullscreen-change` (`main.ts:687`),
`window:focus-change` (`main.ts:698`). No `broadcast` bus. The ws-push shim carries exactly these.

## 1.3 Headless conversion — bounded [VERIFIED-CODE + ADVERSARIALLY-CONFIRMED]
1Code's `src/main` is ~90% plain Node; only a countable Electron shell needs handling. An adversarial
pass tried to find coupling that resists a shim and **could not**. Verdict per family:
- **`Menu`** (`index.ts:623-867`) — trivial; role items + `shortcut:*` pushes. **Drop headless.**
- **`session`** (`index.ts:124,915`, `main.ts:363`) — ONLY sets the `x-desktop-token` cookie for the
  remote 21st.dev page; **no** onHeadersReceived/webRequest/CSP/protocol. **Severable** with account decouple.
- **`twentyfirst-agents://`** (`index.ts:189-256`) — 100% OAuth deep-linking; the loopback server
  (below) already handles the same callbacks. **Severable.**
- **Multi-window** (`windows/window-manager.ts`, chat-ownership `chats.ts`) — collapses to a no-op
  for a single webview. **Droppable.**
- **node-pty** (`terminal/session.ts:4,94`, `manager.ts` `extends EventEmitter`, `:55` `emit('data:…')`)
  — **ZERO Electron coupling; runs headless unchanged.** The terminal is NOT a native reimplement.
- **better-sqlite3/Drizzle** (`db/index.ts`) — only `app.getPath('userData')` (`:16`) + migrations
  path (`:32-37`). **Trivial fixed-path shim.**
- **OAuth loopback** (`index.ts:292-474`, `oauth.ts:848`, `mcp-auth.ts`) — plain Node
  `http.createServer` + PKCE; only Electron touch is `shell.openExternal` (one line). **Severable.**
- **Engine spawn** — Claude SDK `pathToClaudeCodeExecutable` (`claude.ts:1977`, resolver `env.ts:45-105`);
  Codex `spawn` from `node:child_process` (`codex.ts:367`, resolver `:223-260`). Plain Node; only
  path-resolution coupling. **Trivial.**
- Nothing else forces Electron alive (no globalShortcut/Tray/powerMonitor/desktopCapturer/screen).
- **THE SHARP NUANCE** [ADVERSARIALLY-CONFIRMED]: `ctx.getWindow` is used by **5** procedures; **4**
  of them (`projects.ts:49,367,455,493`) call native **`dialog.showOpenDialog(window)` +
  `window.focus()`**, NOT `webContents.send`. So "stub getWindow to null" is WRONG — it would break
  the folder pickers. **Resolution:** rewire those 4 sites (+ the `showSaveDialog` at `main.ts:314`)
  to the **native NSOpenPanel/NSSavePanel bridge** (already in the bridge table §1.2B). The 5th site
  (`chats.ts:318`) only reads `.id` for a push target → ws-shimmable. Bounded, known edit sites.
- Hardest single item = the transport swap (the linchpin). The "13 API families" list is accurate
  and over-counts (Menu/nativeImage/nativeTheme/autoUpdater/session get dropped, not shimmed).

**Load facts:** prod renderer loads from `file://` (`index.ts:162`, `main.ts:821`) → serve the built
SPA over localhost, same-origin with the tRPC server. `titleBarStyle:"hiddenInset"` + custom
traffic-light position (`main.ts:631-636`) → native NSWindow chrome.

## 1.4 Orchestration — how 1Code drives its engines [VERIFIED-CODE]
- **Claude Code:** SDK cached (`claude.ts:248-259`), driven by `query(queryOptions)` (`:2019`),
  iterated `for await` (`:2055`); bundled binary via `pathToClaudeCodeExecutable`
  (`:1977`→`env.ts:45-105`). Streaming = tRPC subscription `claude.chat` (`:795-820`) → transformer
  (`lib/claude/transform.ts`) → Vercel-AI `UIMessageChunk`s, `includePartialMessages:true` (`:1770`).
  Resume via `resume`/`forkSession`/`resumeSessionAt`/`continue` (`:1980-1994`), per-subChat
  `CLAUDE_CONFIG_DIR` isolation (`:1149-1264`). Modes: plan (read-only) / agent
  (`allowDangerouslySkipPermissions`-style full write, tool approvals captured by the UI).
- **⭐ THE `ANTHROPIC_BASE_URL` HARNESS (already wired + user-facing)** — `claude.ts:1129-1138`
  injects `customConfig.{token,baseUrl}` as `ANTHROPIC_AUTH_TOKEN`/`ANTHROPIC_BASE_URL`; input schema
  `{model,token,baseUrl}` (`:806-812`); when set it suppresses the OAuth token so the custom base URL
  wins (`:1390-1410`). UI: Settings → Agents/Models with fields "Model name / API token
  (ANTHROPIC_AUTH_TOKEN) / Base URL (ANTHROPIC_BASE_URL)" (`agents-models-tab.tsx:752,772,791`).
  **⇒ Kimi + GLM drop into this harness with zero new engine code.** Two gaps to close: the custom
  token is stored in **plain localStorage** (`atoms/index.ts:254-263`) → move to Keychain; one global
  `customClaudeConfigAtom` → switch the transport (`ipc-chat-transport.ts:176`) to the existing
  `ModelProfile[]` system for per-conversation profiles.
- **Codex:** ACP via `createACPProvider({command: resolveCodexAcpBinaryPath(), env, session:{cwd,
  mcpServers}, …})` (`codex.ts:1255-1267`), stdio JSON-RPC, bridged to Vercel AI SDK `streamText`
  (`:1764-1774`); subscription `codex.chat` (`:1558`). Tool verbs normalized (`shared/codex-tool-normalizer.ts:3-14`).
  Login/status/MCP via a separate `codex` CLI binary.
- **Model catalog is HARDCODED** (`lib/models.ts`; nothing hits a `/models` endpoint) — the live
  catalog is net-new (§1.6).
- **Auth:** two scopes — (a) 21st.dev product account (safeStorage `auth.dat`), (b) engine creds
  (Claude OAuth subscription token via a 21st CodeSandbox dance OR imported from the system keychain
  `security find-generic-password -s "Claude Code-credentials"`; multi-account `anthropic-accounts.ts`).

## 1.5 Decouple — license + telemetry + account [VERIFIED-CODE]
- **License: stock Apache-2.0** [VERIFIED-CODE + VERIFIED-WEB] — the `LICENSE` is verbatim Apache 2.0;
  grep for `non-commercial|SSPL|BUSL|Commons Clause` = zero. Direct deps are MIT/Apache
  (React/Radix/Jotai/Zustand/tRPC/better-sqlite3/node-pty/xterm/Drizzle/the two SDKs). **Safe for a
  paid, closed-source, Developer-ID app** (retain LICENSE/NOTICE, state changes). ⚠️ **Sibling repos
  are AGPL** (`21st-extension`, `magic-mcp`) — **never vendor them**; exclude at the build boundary.
  The bundled `claude`/`codex` binaries are separately licensed (Anthropic/OpenAI EULAs), downloaded
  at build — ship under their EULAs or have users install their own. Run a lockfile-level
  `osv-scanner`/`license-checker` at build to catch transitive surprises.
- **Telemetry:** env-gated OFF, BUT `lib/analytics.ts:13` has a **hardcoded PostHog fallback key**
  that fires in any packaged build → **decouple requires a code edit**, not just leaving env unset.
  Renderer PostHog (`VITE_POSTHOG_KEY`, no fallback) + all Sentry (DSN-gated) are already inert.
- **Account:** the ONE true blocker is a **mandatory 21st.dev login wall** at window creation
  (`windows/main.ts:789` → `login.html` unless a token exists). The local loop needs NO account:
  `App.tsx:106-114` auto-skips onboarding if `ANTHROPIC_API_KEY` present; `BillingMethodPage` offers
  api-key/custom-model lanes; `importSystemToken` reads a local Claude token. `signedFetch`/`streamFetch`
  are 100% cloud (require the 21st token, only call 21st.dev) — NOT on the local path.
- **The surgical decouple edits:** (1) `windows/main.ts:789` force `isAuth=true` / delete the
  `else{login.html}` branch; (2) `lib/analytics.ts:13` empty the hardcoded PostHog key; (3)
  `index.ts:946-954` remove the auto-updater block; (4) **excise the hardcoded hosted URLs** — point
  `getBaseUrl`/`getApiUrl` (`https://21st.dev`) offline + neutralize the packaged app URL
  `https://21st.dev/agents` (Cycle-2/GPT: donor defaults, not requirements, else hosted assumptions
  leak back). Net outbound after: the chosen model provider only. Backend heap: carry an equivalent of
  the donor's `--max-old-space-size=8192` into the headless Node backend.

## 1.6 Six-provider live catalog + endpoints [VERIFIED-WEB, 2026-07-05]
**Current model IDs (use these; the auto-updater keeps them fresh):**
- **Anthropic:** `claude-opus-4-8`, `claude-fable-5` (most capable public; $10/$50; thinking always-on),
  `claude-sonnet-5`, `claude-haiku-4-5`. 4.6+ IDs are dateless pinned snapshots. ⚠️ Fable 5 had a
  brief export-control pause mid-June 2026, redeployed ~July 1 — verify at runtime.
- **Codex:** default `gpt-5.5`; also `gpt-5.4`, `gpt-5.4-mini`. CLI `codex` v0.142.5.
- **Kimi:** `kimi-k2.7-code`, `kimi-k2.6`, `kimi-k2.5` (256K; dotted IDs — the dashed
  `kimi-k2-thinking` are open-weights/third-party names).
- **GLM:** `glm-4.7` (current Claude-Code default), `glm-5.2` (flagship); `glm-4.6`/`glm-4.5-air` fallbacks.
- **Gemini:** `gemini-3.5-flash` (GA flagship), `gemini-3.1-pro-preview`; `gemini-2.5-*` legacy;
  `gemini-3-pro-preview` DEPRECATED.
- **OpenCode (free Zen only):** `opencode/big-pickle`, `opencode/grok-code`, `opencode/glm-4.7-free`,
  `opencode/kimi-k2.5-free`, `opencode/minimax-m3-free`, `opencode/nemotron-3-ultra-free`, … (21 IDs
  with `cost==0`; promos rotate).

**Anthropic-compatible base URLs (for the Claude harness) [VERIFIED-WEB verbatim]:**
- Kimi: `ANTHROPIC_BASE_URL=https://api.moonshot.ai/anthropic` + `ANTHROPIC_AUTH_TOKEN=<moonshot key>`
  + `ANTHROPIC_MODEL=kimi-k2.7-code` (no `/v1`; Claude Code appends `/v1/messages`). `.ai`/`.cn` domain-bound.
- GLM: `ANTHROPIC_BASE_URL=https://api.z.ai/api/anthropic` (intl) / `https://open.bigmodel.cn/api/anthropic`
  (China) + `ANTHROPIC_AUTH_TOKEN=<z.ai key>` (no `/v1`). Default map `glm-4.7`; override `glm-5.2`.

**Live `/models` endpoints (the auto-update backbone):**
| Provider | Endpoint | Auth | id field |
|---|---|---|---|
| **models.dev** | `GET https://models.dev/api.json` | none | `providers.<p>.models.<id>` + `cost` (free = cost 0) |
| Anthropic | `GET api.anthropic.com/v1/models` | x-api-key + `anthropic-version:2023-06-01` | `data[].id` (cursor pagination) |
| OpenAI | `GET api.openai.com/v1/models` | Bearer | `data[].id` |
| Moonshot | `GET api.moonshot.ai/v1/models` | Bearer | `data[].id` |
| Gemini | `GET generativelanguage.googleapis.com/v1beta/models` | `?key=` | `models[].name` (paginated) |
| GLM | UNVERIFIED (undocumented) | — | source from models.dev |

**Design:** poll `models.dev/api.json` as the backbone; refine with each active provider's own
`/models` for account-scoped availability; ship a pinned fallback catalog (the IDs above); flag any
ID not confirmable from a live call as "unverified." One OpenAI-compat parser covers OpenAI/Moonshot/GLM;
Anthropic (cursor) + Gemini (`name`) are bespoke.

## 1.7 Six-provider engine matrix + auth [VERIFIED-WEB]
| Provider | Path | Auth (easiest → hardened) | Notes |
|---|---|---|---|
| **Claude Code** | native (exists) | OAuth (`claude` /login) → `setup-token` → API key | `setup-token` token works ONLY with Claude Code, rejected by the Messages API |
| **Codex** | native ACP (exists) | OAuth (`codex login` ChatGPT) → `OPENAI_API_KEY` | ⚠️ migrate the deprecated `@zed-industries/codex-acp@0.9.3` → `@agentclientprotocol/codex-acp` |
| **Kimi** | ANTHROPIC_BASE_URL harness | Kimi CLI `/login` OAuth, OR paste `MOONSHOT_API_KEY` | official Kimi CLI is **Python** (`uv tool install --python 3.13 kimi-cli`) |
| **GLM** | ANTHROPIC_BASE_URL harness | paste z.ai key (**API-key only — Z.ai ships NO OAuth**) | no first-party CLI (ZCode is a GUI) |
| **Gemini** | **API-key-first (`GEMINI_API_KEY`/Vertex), own adapter** | ⚠️ **NEVER proxy the CLI's OAuth** (Google banned 3rd-party reuse, enforced 2026-03-25, suspended accounts) | or the user's own `gemini` CLI as an independent process under their own login; `gemini --acp` (ACP) is an optional advanced mode only (Cycle-2 refinement) |
| **OpenCode** | ACP/own-CLI (NEW), free-Zen-only | `opencode auth login` → Zen key (`OPENCODE_API_KEY`) | whitelist to free `opencode/*`; endpoint `https://opencode.ai/zen/v1` |

Kimi/GLM onboarding refinement (Cycle 2): **prefer the native Kimi CLI `/login`** (managed OAuth, no
key handling = easiest) with `MOONSHOT_API_KEY` + base-URL as fallback; GLM stays base-URL (no
first-party OAuth). Harness model discovery: `CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY=1` (v2.1.129)
lists `{base_url}/v1/models`; Kimi alias `kimi-for-coding` auto-maps newest.

## 1.8 CLI detect/install + Developer-ID spawn [VERIFIED-WEB, primary Apple docs]
- **Detect:** GUI apps get only the launchd PATH (`/usr/bin:/bin:…`) — probe absolute locations
  (`/opt/homebrew/bin`, `/usr/local/bin`, `~/.local/bin`, `~/.bun/bin`, npm global, nvm dirs) →
  optionally augment via `zsh -ilc 'echo $PATH'` → **always spawn with an absolute `executableURL` +
  explicit merged env.** Run `<bin> --version`.
- **Install (native-first):** `claude` (`curl -fsSL https://claude.ai/install.sh | bash`, no Node),
  `codex` (Rust binary / brew), `opencode` (`curl -fsSL https://opencode.ai/install | bash`, native).
  Node-required: **gemini-cli (Node 20+)**; Python: **kimi-cli (uv)**. Prefer local-prefix installs
  (no sudo); show the exact command, never silent `curl|bash`.
- **⭐ Developer-ID spawn:** **entitlements are per-executable, NOT inherited across `exec`** → the
  host needs NONE of `allow-jit`/`allow-unsigned-executable-memory`/`allow-dyld-environment-variables`/
  `disable-library-validation` merely to spawn these CLIs (Node's JIT runs under Node's own signature).
  Ship the minimal hardened set. A **child** that bundles a Node helper DOES need those on its own
  signature if it JITs. Quarantine: `curl`/`tar` don't set it, but a quarantined unsigned child is
  **hard-killed at exec** — for binaries the app installs, verify SHA-256 then `xattr -d com.apple.quarantine`.
  Child crash ≠ host crash.

## 1.9 MCP + skills + worktree + preview [VERIFIED-CODE]
- **MCP config is file-based** (mirrors the Claude Code CLI): merge `~/.claude.json`,
  `~/.claude/.claude.json`, `~/.claude/mcp.json`, `<project>/.mcp.json`, plugin `.mcp.json`
  (`claude-config.ts`); injected as the in-process SDK option `options.mcpServers` (`claude.ts:1746-1761`).
  **Auto-inject seam:** write `mcpServers` into `~/.claude.json` — the app **mtime-caches + re-reads
  every message** (`claude.ts:1272-1300`). Codex has a **separate** `~/.codex` registry via
  `codex mcp add`, injected as ACP `session.mcpServers`. **No unified injection point — target both.**
  Read-modify-write merge (`~/.claude.json` also holds OAuth/session data — never clobber wholesale);
  a project `.mcp.json` in each new worktree is the cleanest zero-config path.
- **Skills/commands** are pure filesystem (SKILL.md format, `~/.claude/skills`, `.claude/commands`),
  loaded by the SDK's `settingSources` — **seed by writing files, no API.**
- **Worktree per chat** at `~/.21st/worktrees/{projectSlug}/{name}` (`worktree.ts:170-183,930-933`);
  agent cwd = worktree via `options.cwd` (Claude) / `session.cwd` (Codex); "local mode" sets
  `worktreePath = project.path`; cleanup `git worktree remove --force`.
- **⚠️ Live preview is a DEAD stub** [VERIFIED-CODE] — `AgentPreview` embeds a CodeSandbox URL
  (`https://${sandboxId}-${port}.csb.app`), comment "Desktop mock" (`agent-preview.tsx:26-27`), gated
  behind cloud-only `sandbox_id`. **There is NO local dev-server preview** (no port detection, no
  `spawn vite dev`). A real local preview is net-new. (This contradicts an external-dossier
  assumption — see Part 3.)

## 1.10 Epistemos native-embedding infrastructure to reuse (the build-critical connection hardening) [VERIFIED-CODE]
Epistemos already ships hardened infrastructure for exactly this shape — a web UI in a WKWebView over
a supervised local backend. Reuse these proven patterns (they encode real bug fixes); the 1Code
surface is the same shape.
- **Runtime supervisor** (`Epistemos/ProAgent/ProAgentRuntimeSupervisor.swift`): a `@MainActor
  @Observable` singleton with a `Status` enum (`idle/unavailable/starting/running(conn)/failed/stopped`),
  `start()`/`stop()`, a health-poll lifecycle, and — critical — **off-main process spawn** (all
  `.run()` inside `Task.detached`, carrying each `Process` across the actor boundary in an
  `@unchecked Sendable` box; an inline `@MainActor` spawn froze the UI on notarized-binary
  code-signature validation, `:416-455,20-23`), **ephemeral ports 49300–64900** (above the WHATWG
  fetch bad-port blocklist — a low port made every SSE hop die with `cause: bad port`, `:80-86`), an
  **env allowlist** for child processes, and a **time-bounded (4s) Keychain→env bridge** (a sync
  Keychain read can block forever on a first-launch ACL prompt; race it, spawn without keys on
  timeout, `:943-988`).
- **Crash-durable orphan reaping** (`ProAgentChildLedger.swift`): persist child identity `(pid,
  kernel start-time)` to disk; sweep strays at next `start()` (TERM → 1.5s grace → KILL). Reuse for
  the 1Code Node backend + node-pty/git children.
- **The JS bridge discipline** (`ProAgentSurfaceView.swift` + the shim pattern): a `WKUserScript` at
  `.atDocumentStart` defines the web-facing API and routes to `webkit.messageHandlers.<channel>.postMessage`;
  a `WKScriptMessageHandler` validates every payload (shape + length caps) and replies by
  injecting a **JSON string literal escaped for `\ " \n U+2028 U+2029` + control chars** so injected
  content can't break out; a promise/`callId` round-trip pattern (post `{callId,cmd,args}` → resolve
  `resolveInvoke(callId,{v:payload})`) — the correct template for the 1Code `desktopApi`/`electron`
  polyfill (the owner dossiers independently arrived at the same `pendingRequests`/`webkitResponseHandler`
  shape). **No secret ever crosses into JS.**
- **Theme injection** (`ProAgentThemeBridge.swift:123-168`): inject theme tokens as **inline
  `!important` CSS custom properties on `documentElement`** at document start + a `MutationObserver`
  that re-asserts; live-switch via `page.callJavaScript`. Overriding `:root` variables re-themes the
  Tailwind/Radix token system in one shot.
- **MCP vault-fusion writer** (`Epistemos/Work/WorkOpenCodeRuntime.writeMergedFusionConfig`): a
  **deep-merge** config writer that injects ONLY Epistemos's own MCP entries (the vault stdio server
  `omega_mcp_stdio` + an optional loopback native-tools MCP), preserving all user MCPs, 0600, at a
  persistent path — the exact read-modify-write discipline needed for `~/.claude.json`. The
  `omega_mcp_stdio` binary (newline JSON-RPC; vault read/write/search + wikilink graph) is already
  built + staged.
- **Navigation reroute** (`ProAgentNavigationDecider`): an **origin allowlist** (only the registered
  loopback port) → any other http(s) → `NSWorkspace.shared.open` + `.cancel`.
- **Perf discipline** (`ProAgentPerf.swift` + `docs/perf-budgets.toml`): `OSSignposter` metrics
  (cold-open/spa-ready/warm-reopen/first-token) with budgets; the "instant open" recipe (eager
  WebView + placeholder, off-main spawn, keep the WebView alive across tab switches — reloading the
  URL reboots the SPA and kills the live session, so drive nav via injected intents).

---

## 1.11 Native-migration surface — which chrome lifts to native [VERIFIED-CODE, cycle 3]
**Governing fact: two data planes decide it, not the visual layout.** (1) **tRPC plane** (SQLite/Drizzle
+ on-disk config `~/.claude`, `.mcp.json`, …) → **NATIVE-SAFE**: a Swift shell calls the same
main-process procedures / reads the same files. (2) **Renderer plane** (Jotai `atomWithStorage` =
localStorage, Zustand, the live streaming subscription) → invisible to native → **SPA-COUPLED**. **The
trap:** the send path reads model/mode/thinking/customConfig **live from the Jotai `appStore` inside the
transport at send time** (`ipc-chat-transport.ts:164-192`, `acp-chat-transport.ts:83-138`) — so a
control that looks like config but whose truth is a localStorage atom silently desyncs the running chat
if nativised with native-only state.

- **NATIVE-SAFE (easy wins — pure tRPC/DB CRUD):** MCP-Servers tab (`agents-mcp-tab.tsx` + `mcp/*`,
  `claude/codex.*McpServer`; keep the MCP-OAuth deep-link callback web/bridged), Skills (`skills.*`),
  Custom-Agents (`agents.*`), Plugins (`plugins.*`/`claudeSettings.*`), Projects/Worktrees
  (`projects.*`/`worktreeConfig.*`), Account/Profile (already `desktopApi.getUser/updateUser`), Debug,
  the sidebar chat list + archive/rename (`chats.list/listArchived/archive/rename/restore`), window
  chrome / traffic-lights / fullscreen / folder-dialog (already IPC), settings navigation itself
  (`desktopViewAtom`/`activeTabAtom`).
- **INTENT-BRIDGE (native control works ONLY if it writes the exact renderer atoms the transport reads):**
  model → `subChatModelIdAtomFamily(subChatId)` + `lastSelectedModelIdAtom`; mode → **DUAL-write**
  `subChatModeAtomFamily` + Zustand `updateSubChatMode` (`chat-input-area.tsx:697-698`);
  provider/thinking/Codex-thinking/Ollama → their atoms; Preferences & Beta toggles (localStorage atoms
  the transport reads, e.g. `extendedThinkingEnabledAtom`, `historyEnabledAtom`, `defaultAgentModeAtom`);
  **sidebar selection → the 5-atom tuple** (`selectedAgentChatIdAtom`, `selectedChatIsRemoteAtom`,
  `chatSourceModeAtom`, `showNewChatFormAtom=false`, `desktopViewAtom=null`) + the `claimChat/releaseChat`
  protocol (omit `chatSourceModeAtom` → transcript loads from the wrong backend); the Models-tab
  custom-config / Codex-key / hidden-models atoms.
- **MUST-STAY-WEB:** transcript/streaming (`@ai-sdk/react useChat` + the subscription — to send from
  native call the web `sendMessage` via `useChatActions`, don't rebuild the subscription), terminal
  (xterm+pty), tool renderers, appearance/theme (drives the WebView + xterm via `theme-provider.tsx:199-203`),
  keyboard/hotkeys, the live-session MCP indicator, drafts, the prompt/mentions/voice editor.
- **⭐ THE REQUIRED BRIDGE PRIMITIVE:** every INTENT-BRIDGE control needs ONE thing — a native→WebView
  call that **sets a named Jotai atom (or runs a Zustand action) in the renderer's shared `appStore`
  (`lib/jotai-store.ts`), keyed by the active `subChatId`**. Build that single bridge (native writes atom
  → web reacts; composes with the §1.10 WKScriptMessageHandler round-trip) and the model picker, mode,
  preferences, theme, and sidebar selection all become safe to nativise. Without it, those are exactly
  where nativising silently breaks the live chat.

---

# PART 2 — EXTERNAL RESEARCH DOSSIERS (owner-supplied cycle-1 input, synthesized + trust-tagged)

Three external dossiers were supplied. Their architecture/license/embedding conclusions **[EXTERNAL:
confirmed]** independently match Part 1 (strong corroboration). Below = each dossier's UNIQUE
contributions (kept) and its corrected/superseded claims (flagged), so nuance is preserved without
re-printing the redundant restatement.

## 2.1 Dossier A ("Claude") — the strongest external pass
**Confirmed-and-valuable [EXTERNAL: confirmed]:**
- The **two PTY-architecture options**, articulated cleanly: (i) fully-native Swift spawn+PTY vs
  (ii) **a thin local Node helper running 1Code's engine verbatim**, Swift proxying tRPC. Its
  recommendation — **(ii) for v1** (reuse vendor SDKs + tested orchestration, far less rework) —
  matches Part 1's headless-Node-backend thesis. Adopt.
- The **AGPL-sibling warning** (`magic-mcp` is AGPL; do not vendor AGPL siblings). Adopt.
- **Gemini = ACP harness** (Zed integrated Gemini CLI as the ACP reference impl; registry name
  `gemini`), and the **Google OAuth-reuse ban** (~March 2026) → use the user's own key/login. Matches
  Part 1.7; adopt (supersedes Dossiers B/C's Gemini-via-base-URL — see Part 3).
- Correct **base URLs** for GLM (`api.z.ai/api/anthropic`) and Kimi (`api.moonshot.ai/anthropic`) —
  matches Part 1.6.
- The **safe-to-native vs must-stay-web boundary**: chrome (settings, pickers, sidebars, git surface,
  MCP UI) → native; transcript + xterm live view → web; PTY/spawn → native/helper. Matches owner intent.

**Corrected [EXTERNAL: corrected]:** its model IDs are mostly current (Fable 5/Opus 4.8/Sonnet 5/Haiku
4.5) but it lists `gpt-5.2-codex`/`gpt-5.3-codex` for Codex where Part 1.6 has `gpt-5.5` default; use
Part 1.6 + live auto-update.

## 2.2 Dossier B ("Gem 1") — concrete Swift + risk framing
**Valuable [EXTERNAL: confirmed]:** ready-to-adapt Swift code — a `WKURLSchemeHandler`
(`EpistemosWorkspaceSchemeHandler`) with **path-traversal confinement** (sandbox-prefix check) +
MIME resolution; a `WKScriptMessageHandler` bridge; an `NSOpenPanel` folder-picker round-trip via a
`CustomEvent`; a CLI detector; an MCP `MCPInjectionManager` doing read-modify-write on `~/.claude.json`;
a CSP `<meta>` locking `connect-src` to loopback. Its **risk matrix** (PTY IO lag → native PTY;
sandboxed file perms → security-scoped bookmarks; code-modification watch loops → ignore `.git`/lockfiles;
native-rebuild failures → native SQLite) is a useful hardening checklist. Keep the code as implementation
references; **modernize** `NSUserNotification` → `UNUserNotificationCenter`.

**Superseded [EXTERNAL: superseded]:** (a) its model table (`claude-3-7-sonnet`, `gpt-4o`, `o1-pro`,
`gemini-2.5-pro`, `kimi-k2`, `glm-4-plus`, `deepseek-r1`) is ~2025-stale → use Part 1.6. (b) its
**Kimi/GLM base URLs** (`api.moonshot.cn/v1/anthropic-compat/`, `open.bigmodel.cn/api/paas/v4/anthropic-compat/`)
are **wrong paths** → use Part 1.6's verified `api.moonshot.ai/anthropic` and `api.z.ai/api/anthropic`.
(c) **Gemini-via-ANTHROPIC_BASE_URL** (a Google "anthropic-compat" endpoint) — no such endpoint;
Gemini is an ACP harness (Part 1.7). (d) OpenCode routed to a generic `deepseek-r1` free model → use
the actual Zen free IDs (Part 1.6).

## 2.3 Dossier C ("Gem 2") — deepest embedding detail + the promise/callback bridge
**Valuable [EXTERNAL: confirmed]:** the cleanest **bidirectional bridge pattern** — an injected shim
with a `pendingRequests` Map + `window.webkitResponseHandler(requestId,success,payload,error)` and a
Swift `resolveJSCallback`/`rejectJSCallback` that `evaluateJavaScript` the reply — which **matches
Epistemos's existing `resolveInvoke(callId,{v:…})` round-trip** (Part 1.10); use it. Also: the
worktree `git worktree add --detach` detail, the `allowDangerouslySkipPermissions` agent-mode note,
a live `fetchLiveModels` implementation (Anthropic/OpenAI `/models` + fallback) that matches Part 1.6's
design, and a `CLIDetector` that augments PATH with common dirs before `which` (matches Part 1.8).
Its dependency-audit adds `@mcpc-tech/acp-ai-provider` (MIT).

**Superseded/corrected [EXTERNAL: superseded]:** (a) same stale model IDs
(`claude-3-7-sonnet-20250219`, `gpt-4o`, `glm-4-plus`, `kimi-k2`, `deepseek-chat`) → Part 1.6. (b)
Kimi/GLM base URLs `…/v1/anthropic`, `…/paas/v4/anthropic` → use Part 1.6's paths. (c) it assumes a
**working local-dev-server live preview** ("spawns a local dev server on a random port… iframe") —
**Part 1.9 verified this is a dead CodeSandbox stub**; a local preview is net-new. (d) the
`osascript … with administrator privileges` global-install path — prefer the local-prefix install
(no sudo) it also lists. (e) `NSUserNotification` → modernize to `UNUserNotificationCenter`.

---

# PART 3 — SYNTHESIS & CORRECTIONS LEDGER

## 3.1 Consensus (all four sources agree — highest confidence)
Electron main/renderer + tRPC-over-IPC (`trpc-electron`) · Jotai/Zustand/React Query · Drizzle SQLite
(projects/chats/sub_chats) · git-worktree-per-chat · Claude-SDK + Codex-ACP engines · **Apache-2.0,
commercially safe** · WKWebView + `WKScriptMessageHandler` bridge + `WKURLSchemeHandler` + native
NSOpenPanel/PTY/clipboard replacements · telemetry env-gated (strip anyway) · Kimi/GLM via
`ANTHROPIC_BASE_URL` · live `/models` + pinned fallback · MCP via read-modify-write into `~/.claude.json`
+ project `.mcp.json` · native theme via `:root` CSS-variable override injected as a user script.

## 3.2 Corrections ledger (do not resurrect the stale facts)
1. **Model IDs:** external dossiers B/C carry 2025-era IDs (`claude-3-7-sonnet`, `gpt-4o`, `gemini-2.5-pro`,
   `glm-4-plus`, `kimi-k2`, `deepseek-*`). **Current verified:** `claude-opus-4-8`/`fable-5`/`sonnet-5`/`haiku-4-5`,
   `gpt-5.5`, `gemini-3.5-flash`/`3.1-pro-preview`, `glm-4.7`/`5.2`, `kimi-k2.7-code`, `opencode/*` free. Auto-update, never hardcode.
2. **Kimi/GLM base URLs:** verified = `https://api.moonshot.ai/anthropic` and `https://api.z.ai/api/anthropic`
   (no `/v1`). Dossier B/C variants (`moonshot.cn/v1/anthropic-compat`, `bigmodel.cn/api/paas/v4/anthropic`) are wrong.
3. **Gemini:** NOT a base-URL redirect — it's an **ACP harness** (`gemini --acp`). Auth is `GEMINI_API_KEY`
   (Google's free consumer login for the CLI ended 2026-06-18 / Antigravity transition + the OAuth-reuse ban).
4. **Codex ACP package:** `@zed-industries/codex-acp` (what 1Code pins, 0.9.3) is **deprecated** →
   `@agentclientprotocol/codex-acp`. Default model `gpt-5.5`.
5. **Live preview:** 1Code's is a **dead CodeSandbox stub**, not a working local dev-server. A local preview is net-new.
6. **PostHog:** a **hardcoded fallback key** (`analytics.ts:13`) fires in packaged builds → needs a code edit, not just empty env.
7. **The transport swap is TWO client sites** (`trpc.ts:15-17` + `TRPCProvider.tsx:39-44`) and **FOUR
   subscriptions** (claude/codex/terminal/files), and the **4 `projects.ts` folder-picker procedures**
   must be rewired to the native NSOpenPanel bridge (not a getWindow stub).
8. **Notifications:** use `UNUserNotificationCenter` (dossiers show the deprecated `NSUserNotification`).

## 3.3 Resolved design forks
- **Backend: headless Node helper (v1) vs native Swift rewrite.** → **Headless Node helper** running
  1Code's engine verbatim, supervised by the Swift host (Part 1.10). Reason: reuse the tested
  orchestration + vendor SDKs; a native rewrite of the agent loop is exactly where it breaks. Owner's
  "more Swift native = easy win" applies to **chrome/buttons/settings** (lift those native
  progressively), NOT the engine.
- **Terminal transport: separate WebSocket vs the tRPC channel.** → Ride the same localhost tRPC-ws
  channel (node-pty runs in the helper, `terminal.stream` is already a tRPC subscription). No separate socket.
- **Gemini: base-URL vs ACP vs direct API.** → **API-key-first; NEVER proxy the CLI's OAuth** (banned,
  enforced 2026-03-25, permanent-ban policy — Discussion #20632 verbatim). Build the Gemini engine seam
  **transport-agnostic** so either the ACP CLI (`gemini --acp` under the user's own API key) or a
  direct `generativelanguage` API adapter can back it; decide at build time from the then-current CLI
  state (consumer lane ended 2026-06-18; Antigravity `agy` transition underway; the paid API-key CLI
  lane continues). Claude-3 (capstone) recommends the direct API as the durable path. There is NO
  Google "anthropic-compat" base-URL — that remains hallucination.
- **OpenCode: full vs free.** → free Zen only (whitelist by `cost==0`); Zen-native live list
  `GET https://opencode.ai/zen/v1/models`; **surface the free-tier data-use notice in the UI**
  (Zen docs verbatim: Big Pickle "collected data may be used to improve the model"; Nemotron 3 Ultra
  Free "Trial use only — do not submit personal or confidential data").
- **MCP injection mechanism.** → **Router-level augmentation PRIMARY (Claude-3 capstone):** we own the
  forked backend, so append `epistemos-vault` at the two in-process injection points — Claude: the
  `options.mcpServers` assembly (`claude.ts:1266-1376` → passed `:1746-1761`); Codex:
  `session.mcpServers` (`codex.ts:1259-1262`). Reversible, non-destructive, immune to on-disk schema
  drift, covers both engines, and surfaces in the donor's MCP UI (which lists via the same handlers).
  The file-write path (deep-merge `~/.claude.json` / worktree `.mcp.json` / `codex mcp add`) stays as
  the compatibility fallback so external `claude`/`codex` runs outside Epistemos also see the vault.

## 3.4 Open items (working defaults; verify at build)
- GLM `/models` endpoint undocumented → source GLM from models.dev; runtime-verify, graceful fallback.
- OpenCode Zen exact auth mechanism (GitHub OAuth vs email) + whether a card is required for free-only — UNVERIFIED.
- Fable 5 runtime availability (export-control history) — verify via a live `/models` call.
- WS `maxPayload` for multi-MB base64 image attachments — set generous, confirm.

---

# PART 4 — CYCLE LOG (append each research cycle)

**Cycle 1 (2026-07-05) — foundation + owner dossier set 1.**
- Owner-supplied: 3 external dossiers (A/Claude, B/Gem1, C/Gem2) — absorbed in Part 2, reconciled in Part 3.
- Agent-run: full source read of the clone (Parts 1.1–1.9), web-verified live provider facts (1.6–1.8),
  Epistemos-infra map (1.10), and **two adversarial verification passes** that confirmed the
  transport-swap and headless-conversion theses with the corrections now in Part 3.2 (#7).
- Status: architecture + embedding seam + decouple + providers + MCP + native-feel + CLI = mapped and
  cross-verified. Deliverable plan drafted (`PROMPT_PLAN_10_EXPERIMENTAL.md`).

**Cycle 2 (2026-07-05) — owner research batch 2 (Claude-1, Claude-2 [re-send of batch-1 Claude,
already integrated], GPT). ⏳ Claude-3 PENDING** — the owner flagged Claude-3 as the highest-authority,
most-synthesized report; integrate it as the **capstone** when provided and let it **take precedence on
any conflict**. This batch strongly CORROBORATES Part 1 (headless Node sidecar, Apache-2.0 + no AGPL
siblings, Kimi/GLM via ANTHROPIC_BASE_URL, live catalog + fallback, MCP read-modify-write, CSS-variable
re-theme, current model IDs). New/refined nuances (each folded into the cited Part):

1. **[EXTERNAL → refines Part 1.7] Gemini = API-key-first; NEVER proxy the CLI's OAuth.** Both
   high-authority sources (Claude-1, GPT) converge: Google **banned third-party reuse of Gemini CLI
   OAuth tokens** (announced Feb 2026, enforcement from **2026-03-25**), suspending accounts incl.
   paying Ultra subscribers. ToS verbatim (Claude-1): *"Directly accessing the services powering Gemini
   CLI … using third-party software, tools, or services … is a violation of applicable terms and
   policies."* ⇒ ship Gemini as **`GEMINI_API_KEY`/Vertex (own adapter)**, or the user's own `gemini`
   CLI run as an **independent process under their own login**; the app must never proxy/reuse the
   token. Supersedes the earlier "ACP harness by default" (the ACP/CLI path is an optional advanced
   mode under the user's own auth).
2. **[EXTERNAL → refines Part 1.7] Kimi — prefer the native CLI `/login`** (managed OAuth, no key
   handling) as the **easiest onboarding** (owner priority); keep `MOONSHOT_API_KEY` + the base-URL
   harness as the one-code-path fallback. GLM stays base-URL (no first-party OAuth). Kimi stable alias
   **`kimi-for-coding`** auto-maps to the newest coding model.
3. **[EXTERNAL → adds to Part 1.5 decouple] Excise the hardcoded hosted URLs.** GPT: `src/main/index.ts`
   hardcodes `https://21st.dev` as the packaged prod base and points the packaged app at
   **`https://21st.dev/agents`** — "donor defaults, not product requirements"; excise or hosted
   assumptions leak back "through the side door." Decouple **edit #4**: point `getBaseUrl`/`getApiUrl`
   offline + neutralize the packaged app URL.
4. **[EXTERNAL → enriches Part 1.6 auto-update] Harness model discovery.** Claude-1: Claude Code has
   **`CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY=1`** (since v2.1.129) → queries `{base_url}/v1/models`,
   populates the picker (only `claude*`/`anthropic*` IDs; cached `~/.claude/cache/gateway-models.json`)
   — same-day discovery for GLM/Kimi through the harness. Optional third catalog layer: a
   **developer-controlled remote-config JSON refreshed at launch** (push new IDs without an app update)
   atop models.dev + per-provider `/models` + pinned fallback.
5. **[EXTERNAL → enriches Part 1.9 MCP] Extra surfaces.** Claude-1: plugins declare MCP in their
   manifest under a **`1code.mcp-servers`** block (stdio + HTTP); `.env` loads in order **project
   `.env` → `~/.1code/.env` → system env**, values can reference `${VAR}`; Codex MCP is TOML at
   `~/.codex/config.toml` (global) + `<project>/.codex/config.toml` (project), via `codex mcp
   add/list/remove/login`.
6. **[EXTERNAL → refines Part 1.8 entitlements] Sidecar signature.** Claude-1: the **Node sidecar's OWN
   signature** needs `com.apple.security.cs.allow-jit` (V8 JIT) + hardened runtime; prefer to AVOID
   `allow-unsigned-executable-memory`; add `disable-library-validation` only if bundling third-party
   native libs; **individually sign every `.node` + CLI binary** + asarUnpack. Consistent with Part
   1.8's per-executable rule — the Swift host stays minimal; the sidecar carries JIT on its own signature.
7. **[EXTERNAL → config note] Main-process heap.** Claude-1: `index.ts` launches with
   `--max-old-space-size=8192`; carry an equivalent heap ceiling into the headless backend.
8. **[RESOLVES GPT's flagged doc inconsistencies via first-hand source]:** README markets "Git Worktree
   Isolation" as present while the donor CLAUDE.md lists it "Planned" → **source confirms worktrees ARE
   implemented** (Part 1.9, `worktree.ts`/`createWorktreeForChat`/`chats.ts`). Live preview "verified at
   product level, implementation unclear" → **source confirms a dead CodeSandbox stub** (Part 1.9). Our
   source read is the tie-breaker over the donor's stale docs.

Minor: Claude-1 cites 1Code's bundled Codex runtime default as `gpt-5.4` (its v0.0.84 changelog) while
the live Codex CLI default is `gpt-5.5` — the live catalog resolves this (1Code pins a version; the
picker follows the live list). Repo markers: created 2026-01-14, ~4,972★.

**Cycle 3 (2026-07-05, agent-run) — native-migration surface (Part 1.11).** Mapped every renderer
chrome control to NATIVE-SAFE / INTENT-BRIDGE / MUST-STAY-WEB via the two-data-planes rule; identified
the single bridge primitive (native→shared-Jotai-`appStore` write, keyed by `subChatId`) that unlocks
the whole INTENT-BRIDGE tier; flagged the hidden-SPA-state traps (model/mode/theme/sidebar-selection
look native-safe but the live transport reads their atoms at send time). Folded into Plan 10 §6.

**Cycle 4 (2026-07-05) — CLAUDE-3 CAPSTONE (owner-flagged highest authority) + finalization.**
Claude-3 corroborates the entire spine (host swap, headless sidecar, Apache-2.0, seam table, decouple,
six providers, hybrid catalog) and its Objective-B hardening plan was already absorbed into the final
build prompt §9. Integration outcomes:
1. **Adopted (recommendation upgrades):** (a) **MCP router-level augmentation** as the primary
   injection mechanism (see 3.3 — reversible, schema-drift-immune, both engines); (b) **Gemini
   direct-API-first**, ACP CLI as optional-advanced behind a transport-agnostic engine seam (see 3.3).
2. **New facts folded [EXTERNAL: confirmed]:** upstream session-lifecycle exports + quit/reload guards
   to build on (`hasActiveClaudeSessions`/`abortAllClaudeSessions`, `hasActiveCodexStreams`/
   `abortAllCodexStreams`); `claude-sonnet-5` default on Free/Pro since 2026-06-30; `claude-fable-5`
   restored 2026-07-01 (post export-pause); `claude-mythos-5` trusted-access only; `gpt-5.3-codex-spark`
   (Pro research preview); GLM enrichments (ZCode lists GLM-5.2 + GLM-5-Turbo; Claude Code default map
   `ANTHROPIC_DEFAULT_{SONNET,OPUS}_MODEL=glm-4.7`, `HAIKU=glm-4.5-air`; `API_TIMEOUT_MS=3000000`;
   GLM-5.2 metered at a 0.67 factor through 2026-07-31; plans from ~$18/mo); Kimi
   `CLAUDE_CODE_AUTO_COMPACT_WINDOW=262144`; OpenCode Zen-native list endpoint
   `https://opencode.ai/zen/v1/models` + the **free-tier data-use caveats** (UI notice required);
   Gemini OAuth-ban verbatim + permanent-ban policy + Antigravity CLI binary name **`agy`**; auth-state
   file locations (Codex `~/.codex/auth.json`, OpenCode `~/.local/share/opencode/auth.json`, Claude
   `~/.claude/`).
3. **Conflicts resolved in favor of the first-hand clone read** (Claude-3's own caveats defer these to
   direct source inspection — which our corpus IS): live preview = **dead CodeSandbox stub** (Claude-3's
   "local port-detection preview" came from README marketing and was self-flagged unverifiable);
   worktrees = implemented; every item on Claude-3's flagged-unverified list (the `desktopApi` method
   surface, `exposeElectronTRPC()` at `preload/index.ts:12`, codex/claude router internals, PostHog
   gating) is already [VERIFIED-CODE] in Part 1 — its known-unknowns are our knowns.
4. **Precision notes:** no `21st-extension` repo exists in the 21st-dev org (AGPL-sibling naming
   partially unsubstantiated — keep the do-not-vendor guard, but the **SBOM + license deny-list CI
   gate is the real enforcement**); official Kimi CLI install is **`uv`** (not `pip`); the Gemini CLI
   is not fully retired — the paid API-key lane continues (Claude-3 compressed this; our primary-source
   pass stands).
5. **Final build prompt audited + augmented** → `docs/prompts/BUILD_PROMPT_EXPERIMENTAL_FINAL.md`
   (+ the owner's Downloads copy, kept byte-identical). Audit findings applied: restored decouple
   **edit #4** (hosted-URL excision — a compression casualty; renderer fallbacks hardcode
   `https://21st.dev` but read via `getApiBaseUrl()` → fixing `getBaseUrl()` covers them centrally);
   Gemini row aligned to API-first; MCP §6 upgraded to router-level primary; OpenCode data-use notice;
   harness env extras (Kimi auto-compact window, GLM timeout + default map); session-resume edge-case
   test target (the `chats.ts` fork `cutoffIndex`/`messageIndex` fallback can desync); §16 build
   schema added (Cycle 5). Everything else in the owner's prompt was verified correct and left intact —
   including the absolute §0 rule ("if it breaks when moved to native Swift, do not move it").

**Cycle 5 (2026-07-05) — build schema + build/runtime optimization (owner request; repo-grounded).**
Recon [VERIFIED-CODE]: xcodegen `project.yml` sets the MAS split via per-config
`SWIFT_ACTIVE_COMPILATION_CONDITIONS: "$(inherited) EPISTEMOS_APP_STORE MAS_SANDBOX …"`
(`project.yml:228,233`); schemes = `Epistemos.xcscheme` + `Epistemos-AppStore.xcscheme`;
`docs/perf-budgets.toml:55` has `[agent_surface]`; `build-openchamber-web.sh` pins **Node 25.8.2**
("native-ABI anchor"), refuses service-worker dists, stages ONE tarball, and uses version stamps.
Design (full text in the build prompt §16 / Plan 10 §14):
- **Scheme/flag:** add `Epistemos-Experimental` scheme + config defining `EPISTEMOS_EXPERIMENTAL`
  (same mechanism as the MAS flag); gate surface code `#if EPISTEMOS_EXPERIMENTAL` in
  `Epistemos/ExperimentalAgent/`; compile-time assert it never coexists with `EPISTEMOS_APP_STORE`.
- **Artifact pipeline (`build-experimental-web.sh`, mirror the proven script):** lockfile
  content-hash gate; renderer dist w/ embed flag + **SW refusal**; esbuild/bun-bundled headless
  backend + pruned prod node_modules + drizzle migrations; **rebuild better-sqlite3 + node-pty against
  the PINNED NODE ABI (plain `npm rebuild` with the bundled node — NOT `electron-rebuild`; upstream's
  postinstall targets Electron's ABI, which crashes the headless fork at first DB/PTY touch)**; ONE
  tarball (resource-copy flattening collision is proven); version-stamped runtime unpack; **share the
  pinned Node 25.8.2 with the OpenChamber runtime** (one binary serves both — size win).
- **Signing:** individually sign every `.node` + `node` + CLI with Developer ID + hardened runtime;
  JIT entitlement on the node binary's OWN signature; notarize + staple; in-script
  `codesign --verify --deep --strict` + `spctl -a`.
- **Memory/perf (16 GB):** cap the backend heap (`--max-old-space-size=2048–4096`; upstream's 8192 is
  oversized beside Epistemos + engines); arm64-first; strip sourcemaps/dev-deps; non-persistent
  WKWebView store; wire the backend into the existing memory-pressure relief; add
  `[experimental_surface]` budgets (cold ≤1500 ms / warm ≤100 ms / first-token ≤1200 ms) — a perf
  regression blocks the phase commit; instant-open recipe is the mechanism.
- **CI:** SBOM + license deny-list per dep bump; `ts:check` on the fork; never two concurrent
  xcodebuilds.

**STATUS: RESEARCH COMPLETE (owner stop, 2026-07-05).** Final artifacts: this corpus ·
`PROMPT_PLAN_10_EXPERIMENTAL.md` (robust standalone plan) ·
`docs/prompts/BUILD_PROMPT_EXPERIMENTAL_FINAL.md` (the agent-facing ultimate prompt — self-contained;
agents need not read this corpus). Remaining runtime-checks live in the prompt's §15 trust ledger.

---

**Cycle 5 (2026-07-05, agent-run) — THE EMBEDDED-AGENT FRONTIER, Cycle 1 of the forever-loop.**
New owner directive: no native SwiftUI; extend the 1Code web renderer + backend fork; make the
surface the best agent app that exists by embedding it in the Epistemos knowledge substrate.

- **Phase A — DEEP RESEARCH (committed).** `docs/research/AGENT_APP_FIELD_STUDY.md` (3 parallel agents
  read Codex/opencode/goose/zed/cline/aider/continue/Claude-Desktop at HEAD, cited file:line +
  web-verified) and `docs/research/EXPERIMENTAL_DEEP_AUDIT.md` (7-layer self-audit, verdict per seam).
  **The decisive finding:** exhaustive negative grep across all eight frontier apps — NONE has semantic
  retrieval from a personal knowledge base, a concept graph, or provenance write-back; all are
  session-cold and repo-scoped. Their "memory" features prove the gap (goose flat-text dump; Cline's
  in-repo markdown Memory Bank; Zed's manual @mention recall; Codex distills its own rollouts). The
  moat is structural, not a backlog item.
- **Phase C1 — provenance write-back + vault-grounded citation SHIPPED.** The "Save to vault" button
  (`SaveToVaultButton` on the assistant action bar → native `vault:create-note` → `<vault>/notes/*.md`)
  and the earlier read-aloud/selection fusions. **DoD-C citation half PROVEN LIVE** (screenshot): the
  agent ran the vault MCP (4 steps) and cited the user's real notes — `AETHERLINK_MASTER_PACKET.md`,
  `GRAND_UNIFICATION_SWEEP_2026_06_22.md` — grounding the answer in the user's own knowledge. The
  write-back button renders + handler committed/compiled; the file-write click was blocked by a
  machine-wide macOS Keychain-prompt storm (below), not a defect.
- **CRYSTALLIZE.** New skill `.claude/skills/experimental-provenance-writeback/` — the reusable CLASS:
  web-UI → native reply-capable `epistemos` handler → Epistemos substrate (no SwiftUI, no shim edit).
  Indexed in `EXPERIMENTAL_SKILLS_INDEX.md`.
- **Hardening findings for Phase E:** (1) a **Keychain-prompt storm** — `app.epistemos` reads fire one
  modal per provider slot without an always-allow ACL, intercepting UI clicks (machine-wide across
  lanes today); set the ACL / batch reads. (2) Codex tool-policy `deny` is audit-only. (3) The
  two-`xcodebuild` DB-lock collision corrupts intermediates + the Rust dylib (rebuild `build-agent-core.sh`).

**THE RAISED BAR (Cycle 2 crux):** the agent's vault search is naive substring grep
(`omega_mcp_stdio` `vault.rs:854`) while Epistemos owns a BM25+HNSW **RRF index**
(`epistemos-shadow`/`RRFFusionQuery`) the agent cannot reach. Expose **RRF-ranked graph/vault
retrieval** to the agent's context assembly — the context axis the field study proves no standalone
app can build — composing the Cycle-1 write-back round-trip skill to reach the Shadow index.

**Thesis (why this now exceeds Codex / Claude Desktop, grounded in shipped features):** those apps
boot cold and grep a repo; this one boots into the user's vault, runs six engines, injects the vault
MCP into the engine, and — proven live — grounds its answers in the user's own notes with citations,
with a one-click path to write results back as durable notes. The citation + write-back loop is
*structurally impossible* for a standalone agent because it has no knowledge base to cite or write to.
Cycle 2 widens the lead on the context-assembly axis (RRF retrieval), which the field cannot follow.

---

**Cycle 6 (2026-07-05, agent-run) — Cycle 2 of the forever-loop: RRF GRAPH-AWARE CONTEXT ASSEMBLY.**
FORGE the frontier named by Cycle 1's raised bar. SCOUT confirmed (research-first): the agent's vault
search (`omega-mcp/src/vault.rs:854` `search_notes`) is naive substring mmap-grep; `graph.search_semantic`
is only a trigram-cosine backstop (`graph_search_backend.rs:140` — the real HNSW/Tantivy is a "future"
seam); the REAL RRF index (`epistemos-shadow`: tantivy BM25 + usearch HNSW + RRF fusion at
`<vault>/.epcache/shadow`) is opened by the Swift app but was unreachable from the agent surface.

- **Built (composes the Cycle-1 skill `experimental-provenance-writeback`):** native `vault:search-ranked`
  handler → `AppBootstrap.shared.contextualShadowsState.haloSearchService.search(.notes)` (the live
  `ShadowSearchServicing` RRF backend) → ranked `{title,snippet,score,source}`; NEW fork overlays
  `lib/epistemos-vault-grounding.ts` + `ui/epistemos-vault-ground-button.tsx`; a "Vault" composer button
  (both new-chat-form + chat-input-area) reads the prompt via the editor handle, retrieves the top-K
  notes, and rewrites the composer with a `> [[title]] — snippet` grounded-context block + a cite
  instruction. Honest-gated on the native host; empty (not faked) when recall isn't live. Fork `ec77b67`
  (PATCH_LEDGER row 36); gate=110, de-brand=0.
- **CRYSTALLIZE:** `experimental-vault-context-assembly` — the CLASS of routing Epistemos RRF/graph
  retrieval into the agent's context (web prompt → native handler → app RRF → ranked cited context).
  Indexed. This is the first cycle that COMPOSED a prior skill (the invariant from Cycle 2 on).

**THE RAISED BAR (Cycle 3 crux):** cross-session memory. Swap the `.notes` retrieval for the GRAPH
(`graph.traverse` / `graph.search_semantic` / the cognitive DAG) so the agent recalls "what we decided
last time," keyed by concept not directory — composing `experimental-vault-context-assembly` (retrieval)
+ `experimental-provenance-writeback` (write the decision back). This is the recall the field's
`LIKE`/list/id-lookup memory (goose flat dump, Cline in-repo markdown, Zed manual @mention) cannot do.

**Thesis update:** with Cycle 2, the surface not only cites the vault but ASSEMBLES the agent's context
from RRF-ranked personal knowledge before the turn runs — the context-assembly axis Aider's PageRank
repo-map and Continue's workspace LanceDB index cannot reach, because their corpus is one repo/session
and ours is the durable personal graph.

---

**Cycle 7 (2026-07-06, agent-run) — PROMPT FORGE (submission-time upgrader) + owner asks.**
Owner set a new PACING rule (code more, build as infrequent checkpoints) + two direct asks (ALL free
Zen models; thinking for all engines). FORGE composed the Cycle-2 vault-context-assembly skill.

- **Prompt Forge SHIPPED + PROVEN (backend, deterministic).** "Forge" composer button → renderer
  grounds via `rankedVaultSearch` (Cycle 2) → backend `epistemosPromptForge.enhance` one-shot haiku
  through the Claude SDK (real auth) with the full pipeline (intent → clarity/voice → task-matched
  technique → vault-grounding+[[cite]] → budget → clarify) → Accept/Retry/Revert diff popover.
  Proven vs a headless backend: "make the login better" → structured upgrade citing [[AUTH_DESIGN_2026]],
  5 changes, grounded=true. **Two load-bearing bugs caught by deterministic verification, not assumption:**
  (1) the enhance omitted `pathToClaudeCodeExecutable` → the SDK couldn't spawn the user's claude CLI →
  silent fallback to the original (looked shipped, did nothing) — FIXED; (2) bare Zen ids (`big-pickle`)
  from the live catalog misrouted to Codex (engine-detection keys on the `opencode/` prefix) — FIXED +
  deduped; 24 free Zen models verified.
- **Owner ask — ALL Zen models: DONE.** The composer picker now pulls every cost==0 Zen model from the
  live catalog (was 2 pinned); routing normalized to `opencode/`.
- **Owner ask — thinking: DIAGNOSED (infra fully wired).** Extended thinking defaults ON for
  Claude/Kimi/GLM (`maxThinkingTokens=32k` via the IPC transport); Codex has effort levels; reasoning
  blocks render (expanded while streaming, `AgentThinkingTool`). Needs live per-engine evidence of the
  actual gap before any change (won't blind-fix working paths). NEXT.
- **CRYSTALLIZE:** `experimental-submission-enhance` — the reusable CLASS (renderer trigger → tRPC → SDK
  one-shot small-model transform, MUST pass the binary path, compose vault grounding → diff/accept UX).

**THE RAISED BAR (next):** (a) close the thinking gap live per-engine; (b) System Prompt Forge + Pattern
Library (composes experimental-submission-enhance again — the system-prompt layer); (c) cross-session
memory via the graph (recall "what we decided last time" keyed by concept). The deterministic-headless-
verify habit (catch silent-fallback bugs before the app build) is now standard.

---

**Cycle 8 (2026-07-06) — LIVE VERIFICATION PASS (the DoD proof the loop kept deferring).**
Built the arm64-only checkpoint + discovered the fast web-UI iteration path (bun run build →
build-experimental-web.sh → cp tarball into the app bundle → relaunch; the app unpacks to
~/Library/Application Support/Epistemos/ExperimentalWeb keyed by a size-mtime stamp). Caught + fixed a
duplicate-button regex-collision bug (two Forge, no Persona) by VERIFYING LIVE, not assuming. Then
proved the whole stack in the RUNNING app (screenshots live4-live10):
- **Prompt Forge — DoD-Foundation MET live.** "make the login better" → a structured upgrade (top 2-3
  friction points; UX/security/performance dimensions) + a WHAT-CHANGED list + Accept/Retry/Revert popover.
- **System Prompt Forge + Pattern Library — LIVE.** The Persona popover shows all 3 Epistemos-authored
  Patterns (Vault Librarian / Careful Refactorer / Research Analyst) + the custom-system-prompt upgrade flow.
- **Vault MCP — LIVE.** A transcript where the agent called `list_files` on the `epistemos-vault` MCP and
  returned real vault note titles (FUGU_ORCHESTRATION…, GOOSE_MAS_BUILD_CANON…, APPLE_INTELLIGENCE…).
- **Foundation confirmed live:** de-branded ("E Epistemos"), the one native "Home" pill, Epistemos theme
  tokens (--epistemos-workspace-bg) in the CSS, cloud default (Opus 4.8), composer = Vault·Forge·Persona.
- **Thinking Gap-B** committed (hide OpenCode's inert effort knob); all-Zen picker + thinking per-engine =
  next live check.

**THE RAISED BAR (next):** with the UI stack proven, wire the DETERMINISTIC SUBSTRATE (Finalization
Mandate) — all native-heavy (agent_core FFI → Swift handlers), so batch into ONE Swift change: EML recall
rerank flag (EPISTEMOS_EML_RERANK_RECALL_V0=1, read in EmlRecallRerank.swift) to upgrade vault:search-ranked
+ Prompt Forge grounding; RunEventLog capture of CLI tool-calls; the ReplayBundle export FFI (net-new,
provenance/replay.rs:228 + a bridge.rs entry) → run.export-bundle. record_skill_outcome/recall_procedure
FFIs already exist (bridge.rs:2911/2931); observe_composition is the one missing wire.

---

**Cycle 9 (2026-07-06) — vault CITE-CHECK shipped + live, and a REAL runtime bug found.**
FORGE (composing Cycles 1+2): a `CiteCheckButton` on assistant replies verifies each `[[wiki]]` citation
against the user's real vault via the native RRF handler; honest verdict, never a fake pass. Skill
`experimental-substrate-verification` crystallized (the trust axis: verify agent OUTPUT vs substrate).
Deployed via the fast tarball path; PROVEN live.

- **Cite-check LIVE.** Asked the agent to cite real goose notes as [[wikilinks]] (it did — and twice
  REFUSED to fabricate a fake `[[NONEXISTENT_TEST_NOTE_ZZZ]]`, a nice honest-capability demo). Clicked
  cite-check → toast "0/7 citations verified. Not found in vault: [[GOOSE_FULL_CLONE_INTEGRATION_COST…]]…".
  The feature RAN correctly (extract → query → honest report, no fake pass).
- **⚠️ REAL BUG (the crux for next cycle).** Those 7 notes ARE real, yet cite-check + the agent's own
  MCP search both got ZERO hits — the agent's reply: "Content search is down (search_notes/file_search
  returned connection errors, graph full-text index returned zero hits), so I searched by directory
  listing instead." So the SHADOW/RRF vault SEARCH (haloSearchService, which vault:search-ranked +
  Prompt-Forge grounding + Vault button + cite-check all depend on) is returning empty this session.
  Vault ACCESS works (list_files returned real notes in Cycle 8); vault SEARCH is degraded. This is
  invisible to a compile/headless test — only live verification caught it.

**THE RAISED BAR (next crux — SCOUT it first):** why does the shadow/RRF search return zero for this
vault? Candidates: the shadow index (`<vault>/.epcache/shadow`) isn't built/opened for this vault
session, OR `ContextualShadowsState.haloSearchService` isn't installed (recall not live), OR
`omega_mcp_stdio` search_notes hit a connection error. This is the FOUNDATION of the whole retrieval
moat — every vault-grounded feature silently degrades to empty when it's down. Diagnose live
(ShadowSearchDiagnostics / the unpack + index-build path), fix, and re-run cite-check → expect N/N
verified. Until then, the vault-search features are HONEST-BUT-EMPTY, not broken-faking — which is the
right failure mode, but not the DoD bar.

---

**Cycle 10 (2026-07-06) — WHOLE-VAULT retrieval; corrected Cycle-9's misdiagnosis.**
SCOUT diagnosed Cycle-9's "shadow search broken" and found it was a MISDIAGNOSIS: the app vault is
`AETHERLINK_APPLICATION_PROJECT` (20 md files, NO goose notes); omega_mcp search WORKS ("aetherlink"→5);
cite-check's "0/7 not found" CORRECTLY caught the agent HALLUCINATING goose citations that don't exist in
the vault. The real gap: cite-check + grounding used the SHADOW index (notes/+chats/ scope, ~1 doc for this
vault) while the whole vault has 20 docs across docs/, root, etc.

- **FORGE (composing Cycles 2 + 5):** NEW read-only backend `epistemos-vault-fs.ts` + `epistemosVault`
  router (`noteExists` + `search`) scanning EPISTEMOS_VAULT_ROOT (the same root the agent's MCP sees).
  cite-check now verifies against the WHOLE vault; `rankedVaultSearch` (Vault button + Prompt Forge
  grounding) falls back to whole-vault search when the shadow returns <2 hits. NEVER touches the vault
  engine (read-only fs). PROVEN headless vs the live AETHERLINK vault: [[AETHERLINK_MASTER_PACKET]] +
  [[Architecture Specification]] (in docs/, which the shadow index MISSED) → verified; [[GOOSE_*]]
  (hallucination) + [[NONEXISTENT_ZZZ]] → not-found; search "architecture" → 3 real hits.
- **CRYSTALLIZE:** extended `experimental-vault-context-assembly` with the two-mechanism rule (shadow RRF
  vs whole-vault fs, pick by layout) + the diagnosis tip — honest compounding, not a trophy duplicate.
- **Honesty:** corrected the Cycle-9 record + memory (the "shadow broken" claim was wrong).

**THE RAISED BAR (next):** the shadow index nearly-empty for this vault is a CORE crawl-scope/vault-layout
matter (out of lane — don't touch it). In-lane next: (a) verify the whole-vault cite-check + grounding
LIVE in the app (re-run cite-check → real notes now verify); (b) resume the Finalization substrate
(RunEventLog capture of CLI tool-calls — now easy since I have read-only vault-fs + the epistemos channel).

---

**Cycle 11 (2026-07-06) — RUN PROVENANCE (web-side RunEventLog) + vault-fs hardening.**
TEMPER: hardened the whole-vault scan (15s-TTL file-list cache — cite-check's N-per-reply noteExists
calls no longer re-walk the tree, 5 calls = 5ms; + a 24MB scan budget so a rare query can't read the
whole vault). FORGE (composing Cycle 1): `epistemos-run-audit.ts` + a Provenance button — extract the
agent turn's tool-call sequence → a SHA-256 hash-chained, tamper-evident audit → write it back to the
vault as a provenance note. Makes an opaque agent run AUDITABLE + KB-persisted (no standalone app can).
PROVEN deterministic (Node crypto.subtle): 3 events (Thinking skipped, ACP `vault.search_notes` name
resolved), reorder→different root, same input→same root. CRYSTALLIZE: `experimental-run-provenance` (the
trust axis for ACTIONS, complementing `experimental-substrate-verification` for CLAIMS).

**THE RAISED BAR (next):** the extractor already takes a message ARRAY, so a WHOLE-RUN provenance/
observability console (all turns' tool-calls + running hash + per-provider cost) is one UI away. And
when the agent_core RunEventLog/ReplayBundle FFI lands (`provenance/replay.rs` + `bin/epistemos_trace`),
swap the SHA chain for BLAKE3 + export a verifiable `.epbundle` → `run.export-bundle` (Finalization #2),
same shape, stronger guarantee. Also still open: live re-verify of whole-vault cite-check (blocked by
desktop focus contention, not code); Persona for Codex/OpenCode (ACP transport).

---

**Cycle 12 (2026-07-06) — TEMPER: adversarial multi-agent review of the whole overlay stack.**
Ran a focused adversarial reviewer over all 12 Experimental overlays (backend + renderer) for the four
lenses. Verdict: path-traversal + secret-leak + prompt-injection-escalation surfaces CLEAN (the backend
forge calls use allowedTools:[]/maxTurns:1; the vault-fs never joins user strings onto paths; symlinks
not followed; tRPC inputs zod-bounded; no secrets returned/logged). Found + FIXED **1 HIGH + 2 MED**:
- **HIGH (correctness, self-inflicted):** `noteTitleExists` used substring containment
  (`want.includes(base) || base.includes(want)`) → a hallucinated `[[Project Roadmap 2027]]`
  false-verified against a real `Roadmap.md`, silently defeating cite-check's ENTIRE anti-hallucination
  purpose. Fixed to EXACT normalized-title equality. PROVEN: "MANIFEST DELUXE EDITION 2027" (superset of
  real MANIFEST) now rejected; exact real notes still verify.
- **MED:** run-audit hash now JSON-encodes the event tuple (delimiter-collision resistant; re-verified
  reorder→diff + deterministic) + honest "integrity hash" wording (was overclaiming "tamper-evident
  guarantee"); cite-check caps at 40 citations (no serial-call fan-out).
Zero open HIGH. Deployed. This is why TEMPER exists: a fast feature pass introduced a false-verify in the
very feature meant to catch fakes; an adversarial review caught it.

**THE RAISED BAR (next):** the stack is now reviewed-clean. Resume feature frontier — whole-run
observability console (the run-audit extractor already takes a message ARRAY) OR the agent_core
RunEventLog/ReplayBundle FFI for a signed `.epbundle` (run.export-bundle). Also standing: live re-verify
(desktop-contention-permitting) + Persona for Codex/OpenCode (ACP prompt-preamble, fiddly).

---

**Cycle 13 (2026-07-06) — WHOLE-RUN provenance (extends Cycle 8/11).** The Provenance button now
audits the ENTIRE session, not one turn: imperative read of every sub-chat message from the global jotai
store (`appStore.get(messageIdsPerChatAtom(subChatId))` → `messageAtomFamily`+`getPerChatMessageKey`) →
`buildRunAudit(allMessages)` → one whole-run provenance note; falls back to the single message if the
store isn't reachable. Composes `experimental-run-provenance` (extractor already took an array); technique
noted in that skill (no trophy duplicate). Deployed (full 50s renderer rebuild, verified in tarball).
**RAISED BAR unchanged:** the whole-run events now feed cleanly into either a live observability console
or the agent_core ReplayBundle `.epbundle` export (run.export-bundle) when that FFI lands.

---

**Cycle 14 (2026-07-06) — GRAPH-AWARE context assembly (extends Cycle 2/10).** Grounding now expands the
top vault hit with its `[[wikilink]]` outlink neighbors (resolved to real notes; dangling links skipped),
tagged "(linked from X)". Backend-only (no new UI — the owner likes the current surface), read-only +
bounded. The personal-concept-graph moat the field study says standalone apps structurally lack — done
with zero graph engine (the graph IS the wikilinks). PROVEN headless on a fixture (alpha → Alpha + Beta +
Gamma via graph). Technique noted in experimental-vault-context-assembly. Deployed (verified in tarball).
**RAISED BAR:** backlinks (notes that link TO the hit) as a second graph signal; and multi-hop when the
budget allows. The retrieval axis is now: shadow RRF → whole-vault fs → graph-neighbor expansion.

---

**Cycle 15 (2026-07-06) — BACKLINKS (bidirectional graph retrieval).** Extended the Cycle-14 graph
expansion with backlinks: after outlinks, scan the vault (bounded 12MB) for notes that reference the top
hit via `[[title]]` — "what cites this concept," often a stronger signal than outlinks. PROVEN headless:
search "networking" → Gamma Service (base) + Omega Plan (via "references Gamma Service") even though Omega
lacks the query term. The retrieval axis is now DEEP + bidirectional: shadow RRF → whole-vault fs →
graph outlinks + backlinks. Backend-only, no UI, read-only + bounded.

**HONEST STATE / RAISED BAR:** the web-side moat is now broad and reviewed-clean (retrieve from KB +
graph, ground, verify claims, verify actions, persona, provenance write-back — all deterministically
proven, several live). Further pure-web retrieval refinement (multi-hop, semantic) has diminishing
returns. The two genuinely-next frontiers both require stepping outside pure-web overlays:
(a) **live re-verification** of the accumulated stack in the running app (DoD debt, blocked mainly by
shared-desktop focus contention — do when the machine is quiet); (b) the **agent_core ReplayBundle FFI**
for a signed `.epbundle` (run.export-bundle) — the one high-value NATIVE item, correctly deferred under
the "build less / no risky Rust FFI mid-stream" discipline until an owner-sanctioned native checkpoint.

---

**Cycle 16 (2026-07-06) — TEMPER/consolidation: a re-runnable backend regression WITNESS.**
15 cycles of endpoints deserve a durable proof. NEW `scripts/experimental-backend-witness.sh` boots the
headless backend against a THROWAWAY fixture vault (never the user's) and asserts the load-bearing
behaviors in one deterministic run: noteExists exact-match (incl. an explicit **H1 false-verify guard** —
"Gamma Service Enterprise Edition 2027" must be rejected, so that critical fix can't silently regress),
fabricated-note rejection, whole-vault search, graph OUTLINK + BACKLINK expansion. Optional live Prompt
Forge enhance gated behind WITNESS_FORGE=1 + EPISTEMOS_CLAUDE_BINARY (default run stays offline+free).
ALL 6 CHECKS PASS. Re-runnable after any change — robust, no flaky UI, no cross-lane contention.
Chosen deliberately: app wasn't running + another lane (Codex) was frontmost, so a live UI pass would be
high-cost/contention-prone, and pure-web feature refinement is at diminishing returns.
**RAISED BAR unchanged:** live re-verify when the desktop is quiet; the native ReplayBundle FFI on an
owner-sanctioned native checkpoint. The witness now backstops every future backend change.
