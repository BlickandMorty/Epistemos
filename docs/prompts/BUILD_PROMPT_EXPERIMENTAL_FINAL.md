# Build Prompt — Experimental Agent Surface (1Code embedded)

> OWNER OVERRIDE — 2026-07-07, `MAS-ONLY-SHIP-LOCK-2026-07-07`: this prompt is
> parked. Do not start, resume, or reprompt Experimental/1Code work while
> MAS-only is active. Preserve this file as historical provenance and salvage
> useful ideas only through MAS-June/App Store-safe architecture.

> HISTORICAL 1Code UI NOTE — parked by the MAS-only lock. The older "Keep 1Code's UI" language below
> means preserve the working chat behavior, engine, transport, and information
> layout. It does **not** mean preserve donor 1Code/Goose visible components.
> If Experimental/1Code is ever explicitly reopened, replace visible donor component
> language with Epistemos-owned high-quality components or owned CSS surfaces:
> shell, workspace rail, sidebar rows, composer, status strip, command palette,
> buttons, cards, popovers, transcript viewport, and tool/action surfaces. No
> wrapper-only, skin-only, or token/package-only pass satisfies this. See
> `docs/plans/1code-v2/BUILD_PROMPT_1CODE_V2.md`.

**Read this once, fully, before writing code.** It is self-contained. Every load-bearing claim
carries its evidence inline as `file:line` (read first-hand in the pinned clone) or a trust tag.
You do **not** need to open any research corpus — the nuance is folded in here. Where a fact is
tagged `[UNVERIFIED]`, treat it as needing a runtime check; never hardcode it as truth.

Clone pin: `1code @ 9f1bc76` ("Release v0.0.72", 2026-02-24). Live provider facts verified 2026-07-05.

**Audit 2026-07-05 (capstone-integrated — final):** restored decouple edit #4 (hosted-URL excision);
Gemini refined to API-key-first with a transport-agnostic seam; MCP upgraded to router-level injection
(primary) + file-write fallback; OpenCode free-tier data-use notice; harness env extras; §16 build
schema + packaging pipeline added. Everything else verified correct and untouched.

---

## THE ONE RULE THAT OVERRIDES EVERYTHING

**If something will break when moved to native Swift, do not move it.** "More native" applies to
*chrome that is purely tRPC-drivable* — settings toggles, provider/model pickers, sidebars, window
controls, folder pickers, notifications. It does **not** apply to the engine, the agent loop, the
transcript, or the terminal. Maximum functionality wins over nativeness, every time. This was
confirmed by two adversarial verification passes on the source; do not relitigate it.

The governing test for "can this go native?": **can it be driven purely by tRPC reads/writes, with
its intent pushed into the running SPA via an injected `CustomEvent` (never a URL reload — a reload
reboots the SPA and kills the live agent session)?** If yes → safe to lift. If its state lives in
the renderer's Jotai/Zustand/React Query tree or the live agent stream → it stays web.

---

## §0 What this builds

The **Experimental** agent surface. Epistemos embeds **1Code** (`21st-dev/1code`, Apache-2.0,
Electron): its React renderer runs inside a native `WKWebView`; its Node backend runs **headless**
(Electron dropped) as a supervised local process under the Swift host; chrome is lifted to native
AppKit/SwiftUI progressively, but only where the rule above allows. The 1Code chat experience is
kept intact — that is the entire reason for choosing it.

Surface name is **Experimental** (not "Pro" — that verbiage is reserved elsewhere).
Distribution: **Developer-ID, non-sandboxed, notarized, hardened runtime.**

---

## §1 Locked decisions (do not reopen)

1. **Keep 1Code's UI; embed it, don't rebuild it.** The React renderer is the chat surface, in a
   `WKWebView`. License is **stock Apache-2.0** `[VERIFIED-CODE: LICENSE verbatim; grep for
   non-commercial|SSPL|BUSL|Commons-Clause = 0]` — safe for a paid, closed-source, Developer-ID app.
   Retain LICENSE/NOTICE, state changes.
2. **Backend = headless Node helper, verbatim.** Run 1Code's engine (its 21 tRPC routers +
   Claude-SDK + Codex-ACP + node-pty + better-sqlite3) as a supervised local Node process. A native
   rewrite of the agent loop is exactly where it breaks. `src/main` is ~90% plain Node already
   `[VERIFIED-CODE + ADVERSARIALLY-CONFIRMED]`.
3. **Native where safe, chat + terminal stay web.** Lift chrome per the §0 rule. The **transcript
   and the terminal live view stay in the WebView.** node-pty runs headless unchanged — the terminal
   is NOT a native reimplement `[VERIFIED-CODE: terminal/session.ts:4,94; manager.ts emits
   'data:…' at :55 — zero Electron coupling]`.
4. **Six providers, easiest onboarding.** Claude Code + Codex native; Kimi + GLM through the
   already-wired `ANTHROPIC_BASE_URL` harness; Gemini API-key-first behind a transport-agnostic
   seam; OpenCode restricted to its free Zen models. Prefer each provider's own CLI + OAuth where it
   exists; otherwise one Keychain-backed key-paste field.
5. **Fully local, no account, no telemetry.** Four surgical edits (§4). The core loop runs offline
   — only the chosen model provider is contacted.
6. **Model catalog is LIVE.** Auto-update from provider `/models` with `models.dev/api.json` as the
   backbone and a pinned fallback. Never hardcode a stale list.
7. **Reuse Epistemos's proven embedding infrastructure (§8-refs in §9).** The supervisor,
   script-message bridge, Keychain→env bridge, MCP config writer, theme injector — these encode
   real, already-paid bug fixes. Do not reinvent them.
8. **Harden beyond upstream (§9).** This is an enterprise build. The embedded 1Code must ship
   *more* robust than the OSS baseline — a real tool-approval policy layer with audit logging,
   guaranteed process/worktree reaping, crash-safe persistence, Keychain credentials. This is a
   named deliverable, not a cleanup afterthought.

---

## §2 Architecture (topology)

```
Epistemos.app (Developer ID, not sandboxed, native Swift shell)
│
├─ Native chrome over the WebView: toolbar/pill · settings · sidebars · pickers · notifications
│   · theme tokens injected as CSS custom props · mascot overlay seam
│
├─ WKWebView → http://127.0.0.1:<uiPort>/   (1Code renderer SPA, served by the headless backend)
│     │  · tRPC over HTTP(batch) + WebSocket(subscriptions), same-origin
│     │  · onecode-shim.js (WKUserScript @documentStart) fakes window.desktopApi / ipcRenderer
│     ▼
├─ 1Code HEADLESS BACKEND (forked src/main run as plain Node — Electron dropped)
│   ├─ serves the built renderer + the tRPC server (@trpc/server HTTP + applyWSSHandler)
│   ├─ runs the 21 routers unchanged: db(better-sqlite3) · git(simple-git) · terminal(node-pty) ·
│   │  claude(SDK→bundled `claude`) · codex(ACP) · chokidar watchers · worktrees
│   └─ electron-shim-node.js: the countable Electron families → Node paths / Keychain / bridge / ws-push
│
├─ Bundled engine binaries: claude · codex · opencode (native, Node-free where possible)
│   (+ a Node runtime for gemini-cli; python/uv for kimi-cli)
└─ macOS Keychain → provider keys bridged into the backend + engine child env at spawn (never into JS)
```

The renderer is a **pure context-isolated web app with no Node access** `[VERIFIED-CODE:
windows/main.ts:639-644 — contextIsolation:true, nodeIntegration:false, webSecurity:true]` → an
ideal WKWebView candidate.

**Stack (pinned):** Electron ~39.4.0, React 19.2.1, TypeScript 5.4.5, Tailwind 3.4.17,
tRPC v11.7.1 + `trpc-electron` 0.1.2, Drizzle + better-sqlite3, node-pty 1.1.0,
`@anthropic-ai/claude-agent-sdk` 0.2.45, `@zed-industries/codex-acp` 0.9.3, Jotai/Zustand/React Query.

**Data model** `[VERIFIED-CODE]`: Drizzle + better-sqlite3 at `{userData}/data/agents.db`; three
tables — `projects(id,name,path)`, `chats(id,name,projectId,worktreePath,branch,baseBranch,prUrl,
prNumber)`, `sub_chats(id,name,chatId,sessionId,streamId,mode,messages JSON)`. Auto-migrates from
`drizzle/` (dev) / `resources/migrations` (packaged).

---

## §3 The embedding seam + bridge table (adversarially verified — trust this)

### Seam 1 — transport swap (THE LINCHPIN)

The renderer talks to the backend through a `TRPCLink`. Swap it to a network link and the whole UI
works against a localhost tRPC server. Server yields via **standard** tRPC observables
(`claude.ts:820-821`, `codex.ts:1579-1611`); the renderer consumes the **transport-agnostic**
`.subscribe({onData,onError,onComplete})` contract (`ipc-chat-transport.ts:202`,
`acp-chat-transport.ts:161`) → **zero renderer lines change** under the swap. `superjson` is
symmetric on both ends.

```ts
links: [ splitLink({
  condition: op => op.type === 'subscription',
  true:  wsLink({ client: createWSClient({ url:`ws://127.0.0.1:${port}/trpc` }), transformer: superjson }),
  false: httpBatchLink({ url:`http://127.0.0.1:${port}/trpc`, transformer: superjson }),
}) ]
```

- **Apply at BOTH client sites** `[ADVERSARIALLY-CONFIRMED — there are two, not one]`:
  `src/renderer/lib/trpc.ts:15-17` **and** `src/renderer/contexts/TRPCProvider.tsx:39-44` (wired
  `<trpc.Provider client={…}>` at `:47`). A third client, `remote-trpc.ts:59-67`, points at the
  21st.dev cloud — out of scope, leave it.
- **Carry all FOUR subscriptions** `[ADVERSARIALLY-CONFIRMED — four, not two]`: `claude.chat`,
  `codex.chat`, `terminal.stream` (`terminal.ts:200`), `files.watchChanges` (`files.ts:418`). All
  ride the WS link automatically.
- **Server:** replace `trpc-electron`'s `createIPCHandler` (`windows/main.ts:661`) with
  `@trpc/server`'s standalone HTTP adapter + `applyWSSHandler`, same `superjson`.
- **Set a generous WS `maxPayload`** — multi-MB base64 image attachments ride subscription inputs as
  large WS text frames (`ipc-chat-transport.ts:218`). `[verify at build]`

### Seam 2 — the `desktopApi`/electron shim (`onecode-shim.js`, a WKUserScript @documentStart)

~60 channels `[VERIFIED-CODE: src/preload/index.ts:25-248]`. A `WKScriptMessageHandler` + injected
user script replaces the preload. Buckets:

- **→ Native Swift:** window controls (`:77-83`), zoom (`:104-107` → WKWebView magnification),
  devtools (`:122-123`), clipboard (`:139-140` → NSPasteboard), `app:show-notification` (`:131` →
  **UNUserNotificationCenter** — NOT the deprecated NSUserNotification the old dossiers show),
  `app:set-badge*` (`:129-130` → Dock tile), `shell:open-external` (`:133` → NSWorkspace reroute),
  `dialog:save-file` (`:143` → **NSSavePanel**), `vscode:scan/load-theme` (`:246-247`),
  `webUtils.getPathForFile` (`:15-17`), `app:get-api-base-url` (`:136`).
- **→ Server-push (ws):** the bounded **~13 channels** `[ADVERSARIALLY-CONFIRMED — no broadcast bus]`:
  `auth:success/error`, `update:*` (via `sendToAllRenderers`), `shortcut:open-settings`/`new-agent`,
  `mcp-auth-completed`, `worktree:setup-failed` (`chats.ts:56`), `file-changed` (`claude.ts:2407`),
  `git:status-changed` (`git/watcher/ipc-bridge.ts:55`), `window:fullscreen-change` (`main.ts:687`),
  `window:focus-change` (`main.ts:698`).
- **→ Stub/decouple (cloud-only, off the local path):** all `update:*` (`:33-74`), all `auth:*`
  (`:147-153,197-205`), `analytics:set-opt-out` (`:126`), `api:signed-fetch` (`:156`),
  `api:stream-fetch` (`:168`).

### Headless conversion — bounded `[VERIFIED-CODE + ADVERSARIALLY-CONFIRMED]`

An adversarial pass tried to find Electron coupling that resists a shim and **could not**.

- **Drop headless:** `Menu` (`index.ts:623-867` — role items + shortcut pushes), `nativeImage`,
  `nativeTheme`, `autoUpdater`, `session` (only sets the remote-page auth cookie — severable with the
  account decouple), the `twentyfirst-agents://` protocol (`index.ts:189-256` — 100% OAuth
  deep-linking; the loopback server already handles the same callbacks), multi-window.
- **Trivial fixed-path shims:** `app.getPath('userData')` for the DB (`db/index.ts:16`) + migrations
  path (`:32-37`) + history + binary paths.
- **Runs headless UNCHANGED:** node-pty and better-sqlite3/Drizzle. Do not touch them.
- **⚠️ THE ONE SHARP EDIT — do not get this wrong** `[ADVERSARIALLY-CONFIRMED]`: `ctx.getWindow` is
  used by **5** procedures. **Four** of them (`projects.ts:49,367,455,493`) call native
  `dialog.showOpenDialog(window)` + `window.focus()`, **NOT** `webContents.send`. So "stub getWindow
  to null" is **WRONG** — it silently breaks the folder pickers. **Rewire those 4 sites + the
  `showSaveDialog` at `main.ts:314` to the native NSOpenPanel/NSSavePanel bridge (Seam 2).** The 5th
  site (`chats.ts:318`) only reads `.id` for a push target → ws-shimmable. `safeStorage` → Keychain
  (it already has a fallback branch). `shell.openExternal` → one-line native bridge.

**Load:** prod renderer loads from `file://` today (`index.ts:162`, `main.ts:821`) → serve the built
SPA over `127.0.0.1:<uiPort>`, same-origin with the tRPC server. `titleBarStyle:"hiddenInset"` +
custom traffic-light position (`main.ts:631-636`) → native NSWindow chrome.

---

## §4 Decouple — fully local (four surgical edits, nothing more)

`[VERIFIED-CODE]` — each edit gets a `PATCH_LEDGER.md` row:

1. **`windows/main.ts:789`** — force `isAuth=true` / delete the `else{login.html}` branch. This
   mandatory 21st.dev login wall is **the ONE true blocker**. The local loop needs no account
   (`App.tsx:106-114` auto-skips onboarding when `ANTHROPIC_API_KEY` is present; `BillingMethodPage`
   offers api-key/custom-model lanes; `importSystemToken` reads a local Claude token).
2. **`lib/analytics.ts:13`** — empty the **hardcoded PostHog fallback key**. It fires in *any*
   packaged build regardless of env, so leaving env unset is not enough — this needs a code edit.
   (Renderer PostHog has no fallback and all Sentry is DSN-gated → both already inert.)
3. **`index.ts:946-954`** — remove the auto-updater block.
4. **Excise the hardcoded hosted URLs** — point `getBaseUrl()` (`index.ts:83-88`) / `getApiUrl()`
   (`config.ts:13-18`) offline and neutralize the packaged `https://21st.dev` default. Defense in
   depth: renderer fallbacks hardcode `"https://21st.dev"` (`remote-api.ts:12`, `remote-trpc.ts:17`,
   `api-fetch.ts:13`) but all read via `desktopApi.getApiBaseUrl()` → `getBaseUrl()`
   (`windows/main.ts:150`), so fixing `getBaseUrl` covers them centrally — otherwise hosted
   assumptions leak back through the side door.

Optional hardening: tighten CSP `connect-src` to `'self'` + the active provider endpoints; strip any
bare `Sentry.init()`. **Do not touch the engine/chat/db paths.**

**⚠️ Never vendor the AGPL siblings** `21st-extension` and `magic-mcp` — exclude at the build
boundary. Bundled `claude`/`codex` binaries ship under their vendor EULAs (Anthropic/OpenAI) or are
user-installed; they are downloaded at build, not part of the Apache tree. Run `osv-scanner` /
`license-checker` with a fail-the-build deny-list (`GPL-*`, `AGPL-*`, `LGPL-*`, `SSPL`, `BUSL-1.1`,
`Commons-Clause`, `CC-BY-NC-*`) on every dependency bump — the SBOM gate is the real enforcement.

---

## §5 Six-provider matrix + live catalog

1Code already ships the **`ANTHROPIC_BASE_URL` harness, user-facing** `[VERIFIED-CODE:
claude.ts:1129-1138 injects customConfig.{token,baseUrl} as ANTHROPIC_AUTH_TOKEN/ANTHROPIC_BASE_URL;
input schema {model,token,baseUrl} at :806-812; suppresses the OAuth token when a custom base URL is
set at :1390-1410; UI Settings→Agents/Models at agents-models-tab.tsx:752,772,791]` → **Kimi + GLM
need ZERO new engine code.**

| Provider | Path | Onboarding (easiest → hardened) | Current model IDs `[VERIFIED-WEB 2026-07-05]` |
|---|---|---|---|
| **Claude Code** | native (exists) | OAuth (`claude` /login) → `setup-token` → API key | `claude-opus-4-8`, `claude-fable-5`, `claude-sonnet-5`, `claude-haiku-4-5` |
| **Codex** | native ACP; **migrate the deprecated bridge** | OAuth (`codex login`) → `OPENAI_API_KEY` | `gpt-5.5` (default), `gpt-5.4`, `gpt-5.4-mini` |
| **Kimi** | `ANTHROPIC_BASE_URL` harness (zero engine code) | Kimi CLI `/login` OAuth (Python/uv) or paste `MOONSHOT_API_KEY` | `kimi-k2.7-code` · base `https://api.moonshot.ai/anthropic` (no `/v1`) |
| **GLM** | `ANTHROPIC_BASE_URL` harness (zero engine code) | paste z.ai key (**API-key only — Z.ai ships NO OAuth**; no first-party CLI) | `glm-4.7` (default), `glm-5.2` · base `https://api.z.ai/api/anthropic` (no `/v1`) |
| **Gemini** | **API-key adapter FIRST behind a transport-agnostic seam** — direct `generativelanguage` API is the durable path (capstone rec); `gemini --acp` (ACP, mirror the Codex router) = optional-advanced only, runtime-verify the CLI post-Antigravity (`agy`) transition — **NOT a base-URL redirect** | `GEMINI_API_KEY`/Vertex. **NEVER proxy the CLI's OAuth** (banned; enforcement 2026-03-25; permanent-ban policy). Consumer CLI login ended 2026-06-18; the paid API-key CLI lane continues | `gemini-3.5-flash`, `gemini-3.1-pro-preview` |
| **OpenCode** | **NEW adapter, free Zen only (whitelist `cost==0`)** | `opencode auth login` → Zen key. **UI must show the free-tier data-use notice** (Zen docs verbatim: Big Pickle — "collected data may be used to improve the model"; Nemotron 3 Ultra Free — "Trial use only — do not submit personal or confidential data") | `opencode/big-pickle`, `opencode/grok-code`, `opencode/glm-4.7-free`, … (`cost==0` only) |

**Base URLs are `[VERIFIED-WEB verbatim]`.** The old dossiers' variants
(`moonshot.cn/v1/anthropic-compat`, `bigmodel.cn/api/paas/v4/anthropic`, a Google "anthropic-compat"
endpoint) are **wrong** — do not use them. There is no Gemini base-URL path.

**Harness env extras (per provider docs):** Kimi `CLAUDE_CODE_AUTO_COMPACT_WINDOW=262144`; GLM
`API_TIMEOUT_MS=3000000` + default map `ANTHROPIC_DEFAULT_{SONNET,OPUS}_MODEL=glm-4.7`,
`ANTHROPIC_DEFAULT_HAIKU_MODEL=glm-4.5-air` (override to `glm-5.2` for the flagship lane).

**⚠️ Codex ACP migration (required early edit, `PATCH_LEDGER` row):** `@zed-industries/codex-acp@0.9.3`
(what 1Code pins) is **deprecated** → migrate to `@agentclientprotocol/codex-acp`. A deprecated ACP
bridge is the kind of thing that works in dev and breaks under load — do this in the Codex phase, not
later.

**Two harness gaps to close** `[VERIFIED-CODE]`: (1) the custom token is stored in **plain
localStorage** (`atoms/index.ts:254-263`) → move to Keychain; (2) one global `customClaudeConfigAtom`
→ switch the transport (`ipc-chat-transport.ts:176`) to the existing `ModelProfile[]` system so
Kimi/GLM/Claude become per-conversation profiles.

**Live catalog (never hardcode)** `[VERIFIED-WEB]`: 1Code's catalog is currently **hardcoded**
(`lib/models.ts`; nothing hits a `/models` endpoint) — the live catalog is net-new. Design: poll
`models.dev/api.json` (unauthenticated backbone; `providers.<p>.models.<id>` + `cost`, free = cost 0)
→ refine per active provider via its own `/models` for account-scoped availability → pinned fallback
→ flag any ID not confirmable from a live call as "unverified."

| Provider | `/models` endpoint | Auth | id field |
|---|---|---|---|
| **models.dev** | `GET https://models.dev/api.json` | none | `providers.<p>.models.<id>` + `cost` |
| Anthropic | `GET api.anthropic.com/v1/models` | x-api-key + `anthropic-version:2023-06-01` | `data[].id` (cursor) |
| OpenAI | `GET api.openai.com/v1/models` | Bearer | `data[].id` |
| Moonshot | `GET api.moonshot.ai/v1/models` | Bearer | `data[].id` |
| Gemini | `GET generativelanguage.googleapis.com/v1beta/models` | `?key=` | `models[].name` (paginated) |
| OpenCode Zen | `GET https://opencode.ai/zen/v1/models` | Bearer (Zen key) | OpenAI-compat list; cross-check free set vs models.dev `cost==0` |
| GLM | **`[UNVERIFIED]` — undocumented** | — | source from models.dev; runtime-verify, graceful fallback |

One OpenAI-compat parser covers OpenAI/Moonshot/GLM/Zen; Anthropic (cursor) + Gemini (`name`) are
bespoke. `[note]` `setup-token` tokens work ONLY with Claude Code and are rejected by the Messages
API — don't reuse them for `/models` calls. `[note]` Fable 5 had a brief mid-June export-control
pause, redeployed ~July 1 — verify availability via a live `/models` call, don't assume.

---

## §6 MCP auto-inject (Epistemos vault, zero user setup)

`[VERIFIED-CODE]` — **two independent MCP systems, no unified injection point; target both.**

**PRIMARY mechanism — router-level augmentation (capstone rec: reversible, non-destructive, immune
to on-disk schema drift).** We own the forked backend, so append `epistemos-vault` at the two
in-process injection points:
- **Claude:** the `options.mcpServers` assembly (`claude.ts:1266-1376`, passed to the SDK at
  `claude.ts:1746-1761`) — append the vault server object there.
- **Codex:** `session.mcpServers` handed to `createACPProvider` (`codex.ts:1259-1262`) — append there.
This covers both engines at the exact point of use and surfaces in the donor's MCP UI (which lists
via the same handlers).

**FALLBACK/compat (so external `claude`/`codex` runs outside Epistemos also see the vault):** the
file-write path. Claude config is file-based, merging `~/.claude.json`, `~/.claude/.claude.json`,
`~/.claude/mcp.json`, `<project>/.mcp.json`, plugin `.mcp.json` (`claude-config.ts`). Write via a
**read-modify-write deep-merge** into `~/.claude.json` `mcpServers` — that file also holds
OAuth/session data, so **never clobber it wholesale**. The app **mtime-caches + re-reads every
message** (`claude.ts:1272-1300`), so injected servers appear live. Cleanest per-project path: drop a
`.mcp.json` into each new worktree. Codex: `codex mcp add` into the separate `~/.codex` registry.

**Reuse the Epistemos MCP config writer (§9)** — the deep-merge discipline, 0600 perms, and the
`omega_mcp_stdio` vault server (already built + staged; newline JSON-RPC, vault read/write/search +
wikilink graph). Skills/commands are pure filesystem (SKILL.md format, `~/.claude/skills`,
`.claude/commands`, loaded via the SDK's `settingSources`) — **seed by writing files, no API.**

---

## §7 Native feel + native-migration surface

**Re-theme:** inject Epistemos theme tokens as **inline `!important` CSS custom properties on
`:root`/documentElement** via a WKUserScript at document start (+ a `MutationObserver` that
re-asserts); live-switch via `page.callJavaScript`. Because 1Code is **Tailwind + Radix +
next-themes** (token-variable driven), overriding the `:root` variables re-themes most of the UI in
one shot — only hardcoded hex + the header font need explicit overrides. Spec: chunky pixel header
font (**landmarks/headers only — never dense chat/editor body text; Monaco/xterm must stay
legible**), theme tokens (no gradient), trimmed pill (Epistemos / New Chat / All Chats), white
user-text in light mode, aligned bubbles, real caret, a sidebar that **shifts** (not overlays) the
chat. Also set the WebView `underPageBackgroundColor` for a pre-paint blend.

**Native-migration surface (the owner's "as native as safe"):** progressively lift a chrome control
to native SwiftUI **only when it can be driven purely by tRPC reads/writes** — settings toggles,
provider/model picker, sidebar sections, folder picker, notifications, window controls. Keep the
donor's web control wherever native risks breaking the live session. **The transcript + terminal
stay web.** Native controls push intents into the SPA via injected `CustomEvent`s — **never a URL
reload** (that kills the session).

---

## §8 CLI detect / install

`[VERIFIED-WEB, primary Apple docs]`
- **Detect:** GUI apps get only the launchd PATH — probe absolute locations (`/opt/homebrew/bin`,
  `/usr/local/bin`, `~/.local/bin`, `~/.bun/bin`, npm global, nvm dirs) → optionally augment via
  `zsh -ilc 'echo $PATH'` → **always spawn with an absolute `executableURL` + explicit merged env**
  (reuse §9's env allowlist). Run `<bin> --version`. 1Code's own `hasExistingCliConfig` checks
  `ANTHROPIC_API_KEY || ANTHROPIC_AUTH_TOKEN || ANTHROPIC_BASE_URL` in the shell env — reuse it.
  Auth-state files per CLI: Codex `~/.codex/auth.json` (+ `config.toml`), OpenCode
  `~/.local/share/opencode/auth.json`, Claude `~/.claude/` + Keychain.
- **Install (native-first, show the exact command, never silent `curl|bash`):** `claude`
  (`curl -fsSL https://claude.ai/install.sh | bash`, no Node), `codex` (Rust binary / brew),
  `opencode` (`curl -fsSL https://opencode.ai/install | bash`, native); Node-required: **gemini-cli
  (Node 20+)**; Python: **kimi-cli (uv)**. Prefer local-prefix installs (no sudo). For binaries the
  app installs, verify SHA-256 then `xattr -d com.apple.quarantine`.
- **⭐ Developer-ID spawn (the non-obvious truth):** **entitlements are per-executable, NOT inherited
  across `exec`.** The host needs **NONE** of `allow-jit` / `allow-unsigned-executable-memory` /
  `allow-dyld-environment-variables` / `disable-library-validation` merely to spawn these CLIs
  (Node's JIT runs under Node's *own* signature). Ship the minimal hardened set. The bundled Node
  helper needs the JIT entitlement on *its own* signature if it JITs. A quarantined unsigned child
  is hard-killed at exec; a child crash ≠ a host crash.

---

## §9 HARDENING beyond upstream (the enterprise differentiator — a named deliverable)

Upstream 1Code is thin in a few places. This surface must ship harder. Each item below is a
shipping-gate row, not optional polish.

**Reuse Epistemos's neutral AgentSurface infrastructure (it encodes real, already-paid bug fixes)** `[VERIFIED-CODE]`:
Do **not** import or preserve `Epistemos/ProAgent/*`; KEELSTONE deletes it. If a needed pattern still
exists only under a ProAgent name, extract/rename it to neutral `AgentSurface*` or Experimental-owned
code first, then delete the branded source.
- **Runtime supervisor pattern** (`Epistemos/AgentSurface/AgentSurfaceRuntimeSupport.swift` plus
  Experimental supervisor code): `Status` enum +
  `start()`/`stop()` + health poll; **off-main process spawn** (an inline `@MainActor` spawn froze
  the UI on notarized-binary code-sig validation — spawn inside `Task.detached`, carry each `Process`
  across the actor boundary in an `@unchecked Sendable` box); **ephemeral ports 49300–64900** (above
  the WHATWG fetch bad-port blocklist — a low port made every SSE hop die with `cause: bad port`);
  an **env allowlist** for children; a **time-bounded (4s) Keychain→env bridge** (a sync Keychain
  read can hang forever on a first-launch ACL prompt — race it, spawn without keys on timeout). Model
  the 1Code backend supervisor on this.
- **Crash-durable child ledger** (`Epistemos/AgentSurface/AgentSurfaceChildLedger.swift`): persist `(pid, kernel start-time)`;
  sweep strays at next `start()` (TERM → 1.5s grace → KILL). Reuse for the Node backend + node-pty /
  git children.
- **Script-message bridge discipline** (neutral AgentSurface/Experimental WKWebView shim): validate every payload (shape
  + length caps); reply by injecting a JSON string literal escaped for `\ " \n U+2028 U+2029` +
  control chars; promise/`callId` round-trip; **no secret ever crosses into JS.** This is the
  template for `onecode-shim.js`.
- **Theme injector, origin-allowlist navigation reroute, MCP vault-fusion writer, perf discipline**
  (extract any still-useful ProAgent-derived behavior into neutral `AgentSurface*`/Experimental
  helpers; `WorkOpenCodeRuntime.writeMergedFusionConfig` + `omega_mcp_stdio`; `docs/perf-budgets.toml`).
  The instant-open recipe:
  eager WebView + placeholder, off-main spawn, keep the WebView alive across tab switches.

**New hardening this surface must add (beyond what upstream ships):**
- **Tool-approval policy layer + audit log** `[the least-guarded upstream surface]`. The Codex ACP
  approval path relays `PermissionRequest` events to the renderer and back; interpose a policy engine
  in the backend between the tool-call events (both Codex ACP and claude-agent-sdk) and the renderer:
  default-deny shell/network/file-writes outside the worktree, allow-list per project, with
  **append-only NDJSON audit logging** (tool, args-hash, decision, timestamp). Run spawned CLIs with
  the Codex sandbox (`workspace-write`, network off) where possible.
- **Guaranteed cleanup / process reaping.** On chat delete / abort / crash: `git worktree remove
  --force` + prune the branch, and kill the PTY process tree (`pidtree` is already a dep). Startup
  sweep for orphaned worktrees and processes. (Upstream already ships `hasActiveClaudeSessions` /
  `abortAllClaudeSessions` / `hasActiveCodexStreams` / `abortAllCodexStreams` + quit/reload guards —
  build on them; they signal process-liveness is a known concern, but children can still leak on a
  hard crash.)
- **Crash-safe persistence.** Enable SQLite **WAL** + periodic checkpoint; write session state
  transactionally. The stock store is not obviously WAL-hardened against a mid-write crash.
- **Agent-loop error boundaries.** Wrap each turn in try/catch with retry-with-backoff on transient
  provider/network errors; surface structured errors instead of silent stream death. **Regression-test
  session-resume edge cases** — the `chats.ts` fork fallback around `cutoffIndex`/`messageIndex` can
  desync on fork/rollback resume; cover resume, fork-resume, and rollback-resume explicitly.
- **Security posture.** Credentials in macOS **Keychain**, not the app DB / safeStorage blob; CSP
  locks renderer outbound to the custom scheme + localhost backend + active provider endpoints only.
- **Resource limits.** Cap concurrent sessions, PTY memory, and a per-session token/cost budget.
- **Observability upgrade (optional, high value):** productize the dev-only structured NDJSON debug
  server into a redacted local log viewer; per-provider rate-limit + cost tracking in the UI.

---

## §10 Live preview — cut for v1 (hold this consciously)

`[VERIFIED-CODE]` 1Code's live preview is a **dead CodeSandbox stub** — `AgentPreview` embeds a
`https://${sandboxId}-${port}.csb.app` URL, comment "Desktop mock" (`agent-preview.tsx:26-27`), gated
behind a cloud-only `sandbox_id`. **There is NO local dev-server preview** (no port detection, no
`spawn vite dev`). Upstream's preview never worked locally — the README markets it, the code stubs
it. **Cut it for v1** (donor stub only). A real local preview is a separate net-new project — do not
burn a day discovering the stub.

---

## §11 Phases

- **P0 — Vendor + decouple + headless boot** (build pipeline per §16). Fork 1Code (Apache-2.0; dep
  copyleft scan, exclude the AGPL siblings); the 4 decouple edits (§4); convert `src/main` → headless
  Node (electron-shim-node + tRPC HTTP/ws adapter + serve renderer + **the 4 dialog rewires + save
  dialog**); swap both tRPC client links; supervise the backend; WKWebView loads `127.0.0.1:<uiPort>`
  with `onecode-shim.js`. **Accept:** SPA renders; a streaming subscription + the terminal work over
  ws; no login wall; zero service workers; the 4 native pickers work via the bridge.
- **P1 — Claude Code end-to-end.** Bundle `claude`; chat/stream/tools/diffs/git/worktree green,
  local, no account.
- **P2 — Native chrome + re-theme.** NSWindow chrome, toolbar pill, native settings/pickers where
  pure-tRPC-drivable, theme injection. **Accept:** re-skin on ≥3 themes; chat stays live across every
  native intent (no reload).
- **P3 — Providers 2–4 (harness lane).** Kimi + GLM via the harness (close the localStorage→Keychain
  + single-atom→profiles gaps); Codex ACP (**migrate the deprecated bridge**). Live model catalog.
- **P4 — Providers 5–6 + MCP auto-inject.** Gemini adapter (transport per §5 — direct API or ACP,
  decided by the then-current CLI state; honest onboarding gate) + OpenCode Zen-free adapter
  (whitelist + data-use notice); vault MCP auto-injected (router-level primary + file fallback);
  CLI detect/install picker.
- **P5 — Lifecycle + security hardening (§9).** Tool-approval policy + audit log; child-ledger
  reaping + worktree cleanup; SQLite WAL; crash-restart backoff; Keychain credentials; CSP lockdown;
  resource ceilings; launch/quit soak on 16 GB.

---

## §12 Feature ledger (shipping gate — close every row)

Project→chat→sub-chat sidebar + worktree · chat + streaming + tool UIs + diffs · terminal (node-pty
over ws) · git worktree per chat · plan/agent mode + permissions · 6-provider engine + live catalog ·
MCP auto-inject (router-level + file fallback, both systems) · native chrome + re-skin · CLI
detect/install · **tool-approval policy + audit log** · **process/worktree reaping** · **SQLite WAL**
· **Keychain credentials** · **free-Zen data-use notice** · live preview = **cut** (donor stub only)
· login wall / PostHog / Sentry / updater / hosted URLs = **stripped**.

---

## §13 Verification bar

- **P0:** SPA renders in WKWebView; a `.subscription()` streams + the terminal works over ws; no
  login wall; Web Inspector shows zero service workers; the 4 native pickers work via the bridge.
- **Per phase:** ends in a commit + an owner-visual checkpoint + a bounded hardening pass (security /
  memory-leak / data-leak / robustness, reported as `N HIGH/MED/LOW` with `file:line`; a HIGH blocks
  the commit) + a perf gate (cold-open / first-token budgets per §16).
- **Decouple proof:** with the network limited to the provider endpoint, the full loop (create
  project → chat → run an engine against a local folder) works.
- **Honest capability:** never fake a provider or a feature. If a provider's onboarding can't be
  verified end-to-end, gate it honestly rather than shipping a dead button.

---

## §14 Guardrails

- The vendored 1Code fork lives **OUTSIDE** the Epistemos git tree; clone only into
  `.research-clones/` (gitignored) — never commit it, never `git add -A`, no git worktrees in this
  repo. Overlay edits in NEW files; each unavoidable in-place edit gets a `PATCH_LEDGER.md` row.
  **Seed ledger:** the 4 decouple edits + the 2 tRPC link swaps + the electron shim + the 4 dialog
  rewires + the save-dialog rewire + the Codex-ACP migration + the 2 harness-gap edits
  (localStorage→Keychain, single-atom→profiles) + the MCP router-level augmentation points.
- **Provider keys stay in Keychain, bridged to the child env only — never into webview JS.**
- Commit after every coherent change; report honestly (no "done" without the §12 ledger row closed).
- **The §0 rule is absolute: if moving something to native Swift will break it, do not move it.**

---

## §15 Trust ledger (what to trust vs. runtime-check)

- **Trust as verified-verbatim:** the base URLs (`api.moonshot.ai/anthropic`, `api.z.ai/api/anthropic`,
  both no `/v1`); the transport-swap being two client sites + four subscriptions; the getWindow /
  four-folder-picker sharp edit; the four decouple edit sites; the hardcoded-PostHog-key fact; the
  live-preview-is-a-dead-stub fact; the `ANTHROPIC_BASE_URL` harness already existing and being
  user-facing; Gemini having NO base-URL path; the MCP injection points (`claude.ts:1266-1376`,
  `codex.ts:1259-1262`); the AGPL-sibling exclusion (prophylactic — the SBOM deny-list is the real
  gate).
- **Runtime-check, never hardcode:** all model IDs (auto-update from `models.dev` + live `/models`);
  Fable 5 availability; the **GLM `/models` endpoint** (`[UNVERIFIED]` — source from models.dev,
  graceful fallback); OpenCode Zen's exact auth mechanism and whether a card is required for free-only
  (`[UNVERIFIED]`); the WS `maxPayload` needed for multi-MB image attachments; **the Gemini CLI's
  post-Antigravity state** (`agy` transition — verify `gemini --acp` viability before choosing the
  ACP transport).
- **Modernize any old-dossier code you reference:** `NSUserNotification` → `UNUserNotificationCenter`;
  the wrong Kimi/GLM base-URL paths → the verified ones above; Gemini-via-base-URL → API/ACP; 2025-era
  model IDs → current.

---

## §16 Build schema, packaging + optimization (the Experimental tier build)

**Xcode integration (xcodegen-managed — never hand-edit the pbxproj):**
- Add an **`Epistemos-Experimental` scheme + build configuration** defining `EPISTEMOS_EXPERIMENTAL`
  in `SWIFT_ACTIVE_COMPILATION_CONDITIONS` — the exact mechanism the MAS split already uses
  (`project.yml:228,233` sets `"$(inherited) EPISTEMOS_APP_STORE MAS_SANDBOX …"` per config; existing
  schemes: `Epistemos.xcscheme`, `Epistemos-AppStore.xcscheme`).
- Gate all surface code `#if EPISTEMOS_EXPERIMENTAL` in a new `Epistemos/ExperimentalAgent/` group
  (mirror the neutral AppSurface compile-time gating pattern, not ProAgent). Experimental is a Developer-ID lane:
  add a compile-time assert that `EPISTEMOS_EXPERIMENTAL` and `EPISTEMOS_APP_STORE` never coexist
  (`#if EPISTEMOS_EXPERIMENTAL && EPISTEMOS_APP_STORE` → `#error`).

**Donor artifact pipeline — `build-experimental-web.sh` (standalone; do not depend on `build-openchamber-web.sh`):**
- **Content-hash gate** on the fork's lockfile → unchanged checkouts skip npm + build entirely.
- Build the renderer dist with the embed flag; **REFUSE any dist containing a service worker** (the
  stale-bundle guard — this must live in the Experimental script because OpenChamber packaging is deleted).
- Bundle the headless backend (esbuild/bun) + prune to production `node_modules`; include the
  drizzle migrations.
- **⚠️ Rebuild native modules (better-sqlite3, node-pty) against the PINNED NODE ABI** — plain
  `npm rebuild` with the bundled node, **NOT `electron-rebuild`** (upstream's postinstall targets
  Electron's ABI; an ABI mismatch crashes the headless fork at the first DB/PTY touch).
- Stage EVERYTHING as **one tarball** (`experimental-web.tar.gz`) — the Xcode resource copy flattens
  directory trees (proven `Multiple commands produce` collision). Unpack once at runtime to
  Application Support, **size+mtime version-stamped** (supervisor precedent).
- **Use a neutral pinned Node 25.8.2 runtime resource** for Experimental/1Code. Do not reference
  `openchamber-runtime`; KEELSTONE renames/removes that path as part of deletion.

**Signing / notarization:**
- Individually sign every `.node`, the bundled `node`, and each CLI binary with Developer ID +
  hardened runtime. The **node binary's OWN signature** carries `com.apple.security.cs.allow-jit`
  (per-executable entitlements — §8); the Swift host ships the minimal set.
- Notarize + staple; verify in-script: `codesign --verify --deep --strict` + `spctl -a -t exec`.
  A quarantined unsigned child is hard-killed at exec — never ship one.

**Size + memory optimization (16 GB machine):**
- arm64-first artifact (universal later if needed); strip sourcemaps + dev deps from the tarball.
- **Cap the backend heap explicitly** — upstream launches with `--max-old-space-size=8192`
  (`index.ts`), oversized beside Epistemos + engine children on 16 GB. Start at **2048–4096** and
  tune under soak.
- WKWebView non-persistent data store; register the backend with the existing memory-pressure
  relief path; child memory ceilings per §9 resource limits.

**Perf gates (a regression blocks the phase commit):**
- Add an **`[experimental_surface]`** block to `docs/perf-budgets.toml` mirroring the proven
  agent-surface budgets (`[agent_surface]` at `perf-budgets.toml:55`): cold-open ≤1500 ms, warm
  reopen ≤100 ms, first-token ≤1200 ms; OSSignposter metrics.
- The §9 instant-open recipe is the mechanism: eager WebView + placeholder, off-main spawn,
  keep-alive across tab switches, optional pre-warm at app bootstrap (off-main, `.utility`).

**CI gates:** SBOM (`@cyclonedx/cyclonedx-npm`) + license deny-list on every dependency bump (§4);
`bun run ts:check` on the fork; never two concurrent xcodebuilds on the 16 GB machine.
