# Plan 10 — Experimental agent surface (1Code embedded)

**What this builds.** The **Experimental** agent surface: Epistemos embeds **1Code**
(`21st-dev/1code`, Apache-2.0, Electron) — its React UI runs inside a native WKWebView, its Node
backend runs headless under the Swift host, and as much chrome as safely possible becomes native
AppKit/SwiftUI. The 1Code chat experience is kept intact (that is the whole point of choosing it);
everything around it is nativised where it's a clean win.

**Status:** CANONICAL DRAFT · **Evidence base:** [`EXPERIMENTAL_R.md`](../research/EXPERIMENTAL_R.md)
(every claim here is cited there to `file:line` / a primary source, and the two load-bearing theses
were adversarially verified). Clone at `.research-clones/1code@9f1bc76` (gitignored). This plan is
self-contained; read Experimental R for the deep detail.

---

## §0 Locked decisions
1. **Keep 1Code's UI; embed it, don't rebuild it.** The React renderer is the chat surface, shown in
   a WKWebView. License is Apache-2.0 (safe for a paid, closed-source, Developer-ID app).
2. **Native where safe, chat stays web.** Lift chrome — sidebars, settings, buttons, pickers, window
   controls, the model/provider picker — to native AppKit/SwiftUI progressively, driven off the same
   backend, pushing intents into the SPA **without reloading it**. The **transcript + terminal live
   view stay in the WebView** (that's where native reimplementation breaks). Maximum functionality
   first; never trade a working feature for nativeness.
3. **Backend = headless Node helper, not a Swift rewrite.** Run 1Code's engine (its tRPC routers +
   Claude-SDK + Codex-ACP + node-pty + SQLite) verbatim as a supervised local Node process. A native
   rewrite of the agent loop is exactly where it breaks; "more native" applies to chrome, not the engine.
4. **Six providers, easiest-possible onboarding.** Claude Code + Codex native; Kimi + GLM through the
   Claude Code harness (`ANTHROPIC_BASE_URL`); Gemini as an ACP harness; OpenCode restricted to its
   free Zen models. Prefer each provider's own CLI + OAuth where it exists; otherwise one Keychain-backed
   key-paste field.
5. **Fully local, no account, no telemetry.** Strip the login wall, the hardcoded analytics key, and
   the updater. The core loop runs offline (only the chosen model provider is contacted).
6. **Model catalog is LIVE.** Auto-update from provider `/models` endpoints with `models.dev/api.json`
   as the backbone and a pinned fallback. Never hardcode a stale list.
7. **Reuse Epistemos's proven embedding infrastructure** (§8) — the supervisor, the script-message
   bridge, the Keychain→env bridge, the MCP config writer, the theme injector. These encode real bug
   fixes; don't reinvent them.

---

## §1 Architecture (topology)
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
│   └─ electron-shim-node.js: the countable Electron families → Node paths / Keychain / native bridge / ws-push
│
├─ Bundled engine binaries (native, Node-free where possible): claude · codex · opencode
│   (+ a Node runtime for gemini-cli; python/uv for kimi-cli)
└─ macOS Keychain → provider keys bridged into the backend + engine child env at spawn
```
Full architecture map with `file:line`: Experimental R §1.1. The renderer is a pure context-isolated
web app (no Node access) → an ideal WKWebView candidate.

---

## §2 Embedding seam + bridge table  (Experimental R §1.2–1.3 — adversarially verified)

**Seam 1 — transport swap (the linchpin).** Swap the tRPC link to a network link:
```ts
links: [ splitLink({
  condition: op => op.type === 'subscription',
  true:  wsLink({ client: createWSClient({ url:`ws://127.0.0.1:${port}/trpc` }), transformer: superjson }),
  false: httpBatchLink({ url:`http://127.0.0.1:${port}/trpc`, transformer: superjson }),
}) ]
```
- Apply at **BOTH** client sites: `src/renderer/lib/trpc.ts:15-17` **and**
  `src/renderer/contexts/TRPCProvider.tsx:39-44`. The renderer's subscription-consumer code changes
  zero lines (it uses the transport-agnostic `observable.subscribe` contract).
- Server: replace `trpc-electron`'s `createIPCHandler` (`windows/main.ts:661`) with `@trpc/server`
  standalone HTTP + `applyWSSHandler`, same `superjson`. It carries all **four** subscriptions
  (`claude.chat`, `codex.chat`, `terminal.stream`, `files.watchChanges`). Set a generous WS `maxPayload`
  (base64 images ride subscription inputs).

**Seam 2 — the `desktopApi`/electron shim** (`onecode-shim.js`, a `WKUserScript`). Buckets (full list
Experimental R §1.2B):
- **Native Swift:** window controls, zoom, clipboard, notification (UNUserNotificationCenter),
  badge, `shell:open-external` (NSWorkspace reroute), **`dialog:save-file` → NSSavePanel**, VS Code
  theme scan.
- **Server-push (ws):** the bounded **~13 channels** (`file-changed`, `git:status-changed`,
  `worktree:setup-failed`, `shortcut:*`, `window:*-change`, `auth:*`, `update:*`, `mcp-auth-completed`).
- **Stub/decouple:** `update:*`, `auth:*`, `analytics:*`, `api:signed-fetch`, `api:stream-fetch` (cloud-only).

**Headless conversion (Experimental R §1.3 — bounded).** `src/main` is ~90% plain Node.
- **Drop headless:** `Menu`, `nativeImage`, `nativeTheme`, `autoUpdater`, `session` (only set the
  remote-page auth cookie), the `twentyfirst-agents://` protocol (OAuth-only; loopback covers it),
  multi-window.
- **Trivial path shims:** `app.getPath` (db + history + binary paths), migrations path.
- **node-pty + better-sqlite3 run headless unchanged** — the terminal is NOT a native reimplement.
- **⚠️ The one sharp edit:** the **4 `projects.ts` folder-picker procedures** (`:49,367,455,493`) +
  the `main.ts:314` save dialog call native `dialog.showOpenDialog(window)` — **rewire them to the
  native NSOpenPanel/NSSavePanel bridge** (Seam 2), do NOT leave them as Electron dialogs and do NOT
  just stub `getWindow`. `safeStorage` → Keychain (it already has a fallback branch). `shell.openExternal`
  → one-line native bridge.

**Load:** serve the built renderer over `127.0.0.1:<uiPort>` (prod loads `file://` today); same-origin
with the tRPC server. `titleBarStyle:"hiddenInset"` + traffic lights → native NSWindow chrome.

---

## §3 Six-provider matrix + live model catalog  (Experimental R §1.6–1.7)

1Code already ships the **`ANTHROPIC_BASE_URL` harness, user-facing** (`claude.ts:1129-1138`, Settings
→ Agents/Models) → Kimi + GLM need **zero new engine code**.

| Provider | Path | Onboarding | Current model IDs |
|---|---|---|---|
| **Claude Code** | native (exists) | OAuth (`claude` /login) → setup-token → API key | `claude-opus-4-8`, `claude-fable-5`, `claude-sonnet-5`, `claude-haiku-4-5` |
| **Codex** | native ACP; migrate deprecated bridge → `@agentclientprotocol/codex-acp` | OAuth (`codex login`) → `OPENAI_API_KEY` | `gpt-5.5`, `gpt-5.4`, `gpt-5.4-mini` |
| **Kimi** | ANTHROPIC_BASE_URL harness (zero engine code) | **prefer native Kimi CLI `/login`** (managed OAuth, easiest) → fallback `MOONSHOT_API_KEY` | `kimi-k2.7-code` · base `https://api.moonshot.ai/anthropic` |
| **GLM** | ANTHROPIC_BASE_URL harness (zero engine code) | paste z.ai key (API-key only, no OAuth) | `glm-4.7`, `glm-5.2` · base `https://api.z.ai/api/anthropic` |
| **Gemini** | **API-key-first, own adapter** (`GEMINI_API_KEY`/Vertex) | ⚠️ **NEVER proxy the CLI's OAuth** — Google banned 3rd-party reuse (enforced 2026-03-25, suspended accounts); or run the user's OWN `gemini` login as an independent process. `gemini --acp` is optional-advanced only | `gemini-3.5-flash`, `gemini-3.1-pro-preview` |
| **OpenCode** | **NEW adapter, free Zen only** (whitelist) | `opencode auth login` → Zen key | `opencode/big-pickle`, `opencode/grok-code`, `opencode/glm-4.7-free`, … |

**Two harness gaps to close:** move the custom token from plain localStorage (`atoms/index.ts:254-263`)
to Keychain; switch the transport (`ipc-chat-transport.ts:176`) to the existing `ModelProfile[]` system
so Kimi/GLM/Claude are per-conversation profiles.

**Live catalog (never hardcode):** poll `models.dev/api.json` (unauthenticated backbone) → refine per
active provider via its own `/models` (Anthropic `GET /v1/models` cursor + `anthropic-version`, OpenAI/
Moonshot Bearer, Gemini `/v1beta/models` `models[].name`; GLM undocumented → models.dev; harness
providers Kimi/GLM also via `CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY=1` → `{base_url}/v1/models`) →
pinned fallback → optional developer-controlled remote-config JSON refreshed at launch → flag any ID
not confirmable from a live call as "unverified." Endpoint table: Experimental R §1.6.

---

## §4 Decouple — fully local (Experimental R §1.5)
Surgical edits: (1) `windows/main.ts:789` force `isAuth=true` / delete the `else{login.html}` branch
(the one true blocker); (2) `lib/analytics.ts:13` empty the **hardcoded PostHog fallback key** (fires in
packaged builds otherwise); (3) `index.ts:946-954` remove the auto-updater block; (4) **excise the
hardcoded hosted URLs** — point `getBaseUrl`/`getApiUrl` (`https://21st.dev`) offline + neutralize the
packaged app URL `https://21st.dev/agents` (else hosted assumptions leak back through the side door).
Optional:
tighten CSP `connect-src` to `'self' + the provider endpoints`; strip bare `Sentry.init()`. Don't touch
the engine/chat/db paths. **⚠️ Never vendor the AGPL siblings** (`21st-extension`, `magic-mcp`); exclude
at the build boundary. Bundled `claude`/`codex` binaries ship under their vendor EULAs or user-installed.

---

## §5 MCP auto-inject (Epistemos vault, zero user setup)  (Experimental R §1.9 + §8)
Two independent MCP systems — target both. **Claude:** write Epistemos's servers into `~/.claude.json`
`mcpServers` via a **read-modify-write deep-merge** (the file also holds OAuth/session data — never
clobber), or drop a project `.mcp.json` into each new worktree (cleanest zero-config). The app
mtime-caches + re-reads every message (`claude.ts:1272-1300`). **Codex:** `codex mcp add` into `~/.codex`.
Reuse the Epistemos MCP config writer + the `omega_mcp_stdio` vault server (§8). Skills/commands are
filesystem — seed by writing SKILL.md / `.md` files, no API.

---

## §6 Native feel + native-migration surface  (Experimental R §1.10)
**Re-theme:** inject Epistemos theme tokens as **inline `!important` CSS custom properties on `:root`/
documentElement** via a `WKUserScript` at document start (+ a `MutationObserver` re-assert); live-switch
via `page.callJavaScript`. Because 1Code is Tailwind + Radix + `next-themes` (token-variable driven),
overriding the `:root` variables re-themes most of the UI in one shot; only hardcoded hex + the header
font need explicit overrides. Spec: chunky pixel header font, theme tokens (no gradient), trimmed pill
(Epistemos / New Chat / All Chats), white user-text in light mode, aligned bubbles, real caret, sidebar
that shifts (not overlays) the chat. Also set the WebView `underPageBackgroundColor` for pre-paint blend.

**Native-migration surface (owner's "as native as safe" — full classification in Experimental R §1.11).**
The split is decided by 1Code's **two data planes**: controls backed by the **tRPC/DB/config-file plane
are NATIVE-SAFE**; controls whose truth is a **renderer localStorage atom / Zustand / the live stream
are SPA-coupled**.
- **NATIVE-SAFE easy wins (pure tRPC CRUD — lift first):** the MCP-Servers, Skills, Custom-Agents,
  Plugins, Projects/Worktrees, Account/Profile, Debug tabs; the sidebar chat list + archive/rename;
  window chrome / traffic-lights / fullscreen / folder-dialog (already IPC); settings navigation.
- **INTENT-BRIDGE (native control MUST write the exact renderer atoms the send-transport reads live):**
  model picker (`subChatModelIdAtomFamily(subChatId)` + `lastSelectedModelIdAtom`), mode (**dual-write**
  the atom + Zustand `updateSubChatMode`), provider/thinking/Ollama, Preferences & Beta toggles, and
  sidebar selection (the **5-atom tuple** + `claimChat/releaseChat` — omit `chatSourceModeAtom` → the
  transcript loads from the wrong backend).
- **MUST-STAY-WEB:** transcript/streaming (send from native via the web `sendMessage`, don't rebuild the
  subscription), terminal, tool renderers, theme/appearance (drives WebView + xterm), hotkeys, the
  prompt editor.
- **⭐ The one primitive that unlocks the INTENT-BRIDGE tier:** a native→WebView call that sets a named
  Jotai atom / runs a Zustand action in the renderer's shared `appStore` (`lib/jotai-store.ts`), keyed by
  the active `subChatId` (composes with the §8 bridge). Build it once; model/mode/preferences/theme/
  sidebar-selection all become safe. Native controls push via this bridge (or injected `CustomEvent`s) —
  **never a URL reload** (kills the session).

---

## §7 CLI detect / install  (Experimental R §1.8)
**Detect:** probe absolute locations (GUI apps get only the launchd PATH) → optionally `zsh -ilc 'echo $PATH'`
→ spawn with an absolute `executableURL` + explicit merged env (reuse §8's env allowlist). **Install
(native-first, show the exact command):** `claude` (curl install.sh, no Node), `codex` (native/brew),
`opencode` (curl install, native); `gemini-cli` (npm, needs Node 20+), `kimi-cli` (uv, Python). Verify
SHA-256 then `xattr -d com.apple.quarantine` on binaries the app installs. **Developer-ID:** entitlements
are per-executable — the host needs none of the JIT/dyld/library-validation entitlements just to spawn
these CLIs; ship the minimal hardened set (the Node helper's own signature carries JIT entitlements if it JITs).

---

## §8 Epistemos embedding infrastructure to reuse (build-critical connection hardening)  (Experimental R §1.10)
Epistemos already ships hardened infrastructure for this exact shape — reuse the patterns verbatim:
- **Runtime supervisor** (`Epistemos/ProAgent/ProAgentRuntimeSupervisor.swift`): `Status` enum +
  `start()`/`stop()` + health poll; **off-main process spawn** (inline @MainActor spawn froze the UI on
  notarized-binary code-sig validation); **ephemeral ports 49300–64900** (above the WHATWG bad-port
  blocklist); **env allowlist**; **time-bounded (4s) Keychain→env bridge** (a sync Keychain read can
  hang on a first-launch ACL prompt). Model the 1Code backend supervisor on this.
- **Crash-durable child ledger** (`ProAgentChildLedger.swift`): persist `(pid, start-time)`, sweep
  strays at next start (TERM→grace→KILL). Reuse for the Node backend + node-pty/git children.
- **Script-message bridge discipline** (`ProAgentSurfaceView.swift` + the shim pattern): validate every
  payload (shape + length), reply by injecting a JSON string literal escaped for `\ " \n U+2028 U+2029`
  + control chars, promise/`callId` round-trip, **no secret ever crosses into JS**. This is the template
  for `onecode-shim.js`.
- **Theme injector** (`ProAgentThemeBridge.swift:123-168`), **origin-allowlist navigation reroute**
  (`ProAgentNavigationDecider`), **MCP vault-fusion writer** (`Epistemos/Work/WorkOpenCodeRuntime.writeMergedFusionConfig`
  + `omega_mcp_stdio`), and the **perf discipline** (`ProAgentPerf.swift` + `docs/perf-budgets.toml` —
  the instant-open recipe: eager WebView + placeholder, off-main spawn, keep the WebView alive across
  tab switches). Keychain→env bridge mirrors the provider-key flow.

---

## §9 Phases
- **P0 — Vendor + decouple + headless boot.** Fork 1Code (Apache-2.0; dep copyleft scan, exclude AGPL
  siblings); the 3 decouple edits; convert `src/main` → headless Node (electron-shim-node + tRPC HTTP/ws
  adapter + serve renderer + the 4 dialog rewires); swap both tRPC client links; supervise it; WKWebView
  loads `127.0.0.1:<uiPort>` with `onecode-shim.js`. **Accept:** SPA renders, a streaming subscription +
  the terminal work over ws, no login wall, zero service worker.
- **P1 — Claude Code end-to-end.** Bundle `claude`; chat/stream/tools/diffs/git/worktree green, local, no account.
- **P2 — Native chrome + re-theme.** NSWindow chrome, toolbar pill, native settings/pickers where
  pure-tRPC-drivable, theme injection. **Accept:** re-skin on ≥3 themes; chat stays live across every native intent.
- **P3 — Providers 2–4 (harness lane).** Kimi + GLM via the harness (close the localStorage→Keychain +
  single-atom→profiles gaps); Codex ACP (migrate the bridge). Live model catalog.
- **P4 — Providers 5–6 + MCP auto-inject.** Gemini ACP adapter (honest onboarding gate) + OpenCode Zen-free
  adapter; vault MCP auto-injected; CLI detect/install picker.
- **P5 — Lifecycle hardening.** Crash-restart backoff, child-ledger reaping, port-collision honesty,
  memory ceilings on 16 GB, launch/quit soak.

---

## §10 Feature ledger (shipping gate — close every row)
Project→chat→sub-chat sidebar + worktree · chat + streaming + tool UIs + diffs · terminal (node-pty over
ws) · git worktree per chat · plan/agent mode + permissions · 6-provider engine + live catalog · MCP
auto-inject · native chrome + re-skin · CLI detect/install · **live preview = cut/net-new (donor stub
only)** · login wall / PostHog / Sentry / updater = **stripped**.

---

## §11 Verification bar
- **P0:** SPA renders in WKWebView; a `.subscription()` streams + the terminal works over ws; no login
  wall; Web Inspector shows zero service workers; the 4 native pickers work via the bridge.
- **Per phase:** ends in a commit + an owner-visual checkpoint + a bounded hardening pass (security /
  memory-leak / data-leak / robustness, reported `N HIGH/MED/LOW` with file:line; a HIGH blocks the commit)
  + a perf gate (cold-open / first-token budgets). Honest capability — never fake a provider/feature.
- **Decouple proof:** with the network limited to the provider endpoint, the full loop (create project →
  chat → run an engine against a local folder) works.

---

## §12 Guardrails
- Research/read + write docs only in this pass — NO app build, NO edits to unrelated code. Clone only into
  `.research-clones/` (gitignored); never commit it; never `git add -A`; no git worktrees.
- The vendored 1Code fork lives OUTSIDE the Epistemos git tree; overlay edits in NEW files; unavoidable
  in-place edits each get a `PATCH_LEDGER.md` row (seed: 3 decouple edits + 2 link swaps + the electron
  shim + the 4 dialog rewires + the Codex-ACP migration).
- Provider keys stay in Keychain, bridged to the child env only — never webview JS. Commit after every
  coherent change; report honestly (no "done" without the §10 ledger).
