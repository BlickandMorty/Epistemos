# PLAN 1 (PRO) — Agent Surface: OpenChamber + Dual Engine

**Date:** 2026-07-03 · **Status: CANONICAL for the Pro build** · Supersedes the retired
`PROMPT_PLAN_1_GOOSE.md` and every pre-2026-07-02 goose-reskin directive.

**Verification basis (do not re-litigate without new evidence):** consolidated from a
5-dossier research corpus (2×GPT, 2×Gemini, 1 Claude consensus adjudication), then
**re-verified against local source clones** on 2026-07-03:

- OpenChamber clone `.research-clones/openchamber` @ `0ee55a1` (2026-07-02) — 15/15 seam
  claims checked in source. [VERIFIED-CODE]
- goose clone `.research-clones/work/goose` @ `8b1d500` (2026-07-02, remote
  `aaif-goose/goose`) — 13/13 API claims checked in source. [VERIFIED-CODE]
- Web-verified repo moves: goose → `github.com/aaif-goose/goose` (AAIF/Linux Foundation,
  2026-04-07); opencode → `github.com/anomalyco/opencode`.

---

## §0 LOCKED OWNER DECISIONS (read first, non-negotiable)

1. **This is the PRO build only (Developer ID, NOT sandboxed, NOT MAS).** Owner
   2026-07-03: "we are not doing mas with the openchamber track." Subprocesses are
   unrestricted. Ignore every MAS/sandbox/entitlement/security-scoped-bookmark passage in
   the research corpus. MAS is a separate track (June + goose-in-process; separate plan).
2. **OpenChamber is the ONLY UI donor.** Vendored fork, whole workspace shell mounted in
   the existing WKWebView as the "Agent" destination. No component mixing. 1Code
   (`21st-dev/1code`, Apache-2.0) is a **study donor only** — anything adopted is rebuilt
   from OpenChamber primitives.
3. **Exactly two engines behind one seam:** OpenCode (engine 1, native pairing) and goose
   (engine 2, via adapter). **goose crates are never modified.** Engine chosen
   per-conversation via a composer chip. One merged session list with engine badges.
4. **June applies ONLY to the message bar and the gradient.** Owner 2026-07-02: "for the
   openchamber one i only want to apply june to the message bar and gradient." Everything
   else keeps stock OpenChamber look/themes. **NO June-warm global theme, NOT the default
   theme** — the consensus dossier's "ship june-warm.json as default" is overruled.
5. **Owner signatures kept:** native macOS toolbar pill (app-level nav), RetroGaming
   typewriter greeting (landing headline swap only), native all-chats sheet, June message
   bar + theme-derived landing gradient, companion/mascot overlay hooks (native layer —
   spec in Plan 5, only the hook is Plan 1 scope).
6. **Capability truth:** show the active engine's real capabilities only. Hide absent
   features. Never fake parity. goose sessions group by directory/project — no fake
   branch badges.
7. **Zero silent feature loss.** The feature ledger (§8) is a shipping gate.

---

## §1 ARCHITECTURE (verified topology)

```
Epistemos.app (Pro, Developer ID, native Swift shell)
│
├─ Native chrome: toolbar pill · typewriter landing headline · all-chats sheet
│  · mascot overlay layer (above the WebView, never inside donor DOM)
│
├─ WKWebView  →  http://127.0.0.1:<uiPort>/        (plain config, no private APIs)
│                 │  same-origin fetch / SSE / WebSocket — zero CORS
│                 ▼
├─ OpenChamber web server (Express, packages/web/server) — supervised child process
│   ├─ serves the vendored SPA (PWA/service-worker + self-updater DISABLED)
│   ├─ OWN runtime routes the UI needs beyond any engine: fs routes, git service,
│   │  terminal PTY over WebSocket (ghostty-web 0.4.0)  ← server must stay alive
│   ├─ /api/*    → proxies to opencode          (existing behavior)
│   └─ /goose/*  → NEW same-origin proxy to goosed (adapter transport; X-Secret-Key
│                   attached server-side — the secret never enters webview JS)
│
├─ opencode server (bundled binary, Hono) — supervised, 127.0.0.1:<port>,
│   OPENCODE_SERVER_PASSWORD basic auth, attach via OPENCODE_PORT+OPENCODE_SKIP_START
└─ goosed (bundled binary, axum REST) — supervised, 127.0.0.1:<port>,
    GOOSE_HOST/GOOSE_PORT env-pinned, GOOSE_TLS=false explicit, X-Secret-Key auth
```

**Reuse, don't rewrite:** Epistemos already supervises goosed today.
`Epistemos/Goose/GooseRuntimeSupervisor.swift` (health-probe lifecycle, occupied-port
honesty, SIGTERM cleanup), `GooseProviderKeyBridge.swift` (Keychain → engine env),
`GooseWebUIResolver.swift` staging lessons (Step-0: never let a stale embedded bundle
shadow the live one). The consensus dossier's greenfield `EngineSupervisor` Swift class is
**reference only** — extend the existing supervisor family to manage three children
(web server, opencode, goosed) instead of one. Keep: dynamic free-port allocation,
per-child process group, SIGTERM→SIGKILL escalation on quit, health-probe before load.

**Node runtime:** the web server is Express → bundle a Node runtime + pruned production
`node_modules` (the terminal PTY uses a native module; don't assume `bun --compile`
works). Pro build = no sandbox/notarization drama beyond normal Developer ID signing.
Investigate single-binary compile later as a size optimization, not a blocker.

---

## §2 THE SEAM (verified in OpenChamber source @ 0ee55a1)

The adapter seam is real and small. A goose engine touches **three files** [VERIFIED-CODE]:

| File | Role | Verified facts |
|---|---|---|
| `packages/ui/src/lib/opencode/client.ts` | THE single SDK wrapper (singleton `opencodeClient`) | imports `createOpencodeClient` from `@opencode-ai/sdk/v2`; `DEFAULT_BASE_URL = VITE_OPENCODE_URL \|\| "/api"`; exposes `getSdkClient()` / `setDirectory()` / `getDirectory()` |
| `packages/ui/src/sync/event-pipeline.ts` | Event normalization boundary | `normalizeEventType` (~lines 127–147); handles `session.status`, `session.updated`, `lsp.updated`, **`message.part.delta`**, `message.part.updated` |
| `packages/web/server/lib/opencode/env-config.js` | Server-side engine endpoint config | reads `OPENCODE_PORT` / `OPENCODE_HOST` (host takes precedence); attach-don't-spawn supported |

Supporting verified contract:

- **Session pagination:** `packages/ui/src/stores/globalSessions.ts` pages via
  `apiClient.experimental.session.list({directory?, archived, roots?, limit, cursor?})`,
  next cursor from the `x-next-cursor` response header.
- **Hierarchy is worktree-centric, not abstract branches:**
  `packages/ui/src/types/worktree.ts` (`WorktreeMetadata { branch, headState,
  worktreeRoot, worktreeStatus }`) + sidebar `SessionGroup { id, label, branch, worktree,
  sessions }` (`components/session/sidebar/types.ts`).
- **SDK pin:** `@opencode-ai/sdk` **1.17.12** at this clone. HIGH churn upstream — pin as
  a matched triple (§6).
- **Right panel is server-owned, not engine-owned:** fs/git/terminal come from the
  OpenChamber web server, NOT the opencode SDK → they work identically regardless of
  which engine a conversation uses. No goose parity needed there.
- **Queue UX already in donor:** `messageQueueStore.ts` exists — do not rebuild.
- **Electron precedent:** `AGENTS.md` states desktop boots the web server in-process and
  loads `http://127.0.0.1:<port>` — our Swift shell replaces Electron 1:1 in that role.
  `AGENTS.md` also warns "Do not modify ../opencode" — honor it.

---

## §3 GOOSE ADAPTER SPEC (verified against goosed source @ 8b1d500)

Shape: an `@opencode-ai/sdk`-shaped client (new file, e.g.
`packages/ui/src/epistemos/gooseClient.ts`) + a same-origin `/goose/*` proxy route in the
web server (new file under `packages/web/server/lib/goose/`). The UI never sees goosed
directly and never holds the secret.

**Verified goosed REST surface** (crates/goose-server/src/routes/):

| Contract row | goosed reality [VERIFIED-CODE] | Gap class |
|---|---|---|
| session create | `POST /agent/start` (creates session; there is NO `POST /sessions`) | direct map |
| prompt + stream | `POST /reply` → SSE `MessageEvent{Message, Error, Finish, Notification, UpdateConversation, ActiveRequests, Ping}`; `Ping` heartbeat every **500ms**; `ChatRequest{user_message, override_conversation?, session_id, recipe_name?, recipe_version?}` | shim (see streaming note) |
| message history | `GET /sessions/{id}` (full session incl. conversation) | direct map |
| rename / fork / extensions | `PUT /sessions/{id}/name`, `POST /sessions/{id}/fork`, `GET /sessions/{id}/extensions` | direct map |
| **session LIST** | **DOES NOT EXIST** (only `GET /schedule/{id}/sessions` for scheduled jobs) | **adapter-owned index** (below) |
| abort | `POST /agent/stop {session_id}` | direct map |
| tool confirmation | `POST /action-required/tool-confirmation` with `{id, principal_type (default Tool), action: Permission enum (AllowOnce/…), session_id}` — NOT `{request_id, approve\|deny}` as the consensus sketched | shim |
| providers | `GET /config/providers` → `ProvidersResponse` | direct map |
| MCP extensions | `POST /agent/add_extension` / `remove_extension` (+ extras: `read_resource`, `call_tool`, `list_apps`, `export_app`, `import_app`) | goose-only capability |
| recipes / scheduler | `/recipes/*` (**plural**) and `/schedule/*` route groups | goose-only capability |
| auth | `X-Secret-Key` header on all routes except `/status`, `/features`, `/mcp-ui-proxy`, `/mcp-app-proxy`, `/mcp-app-guest`; secret from `GOOSE_SERVER__SECRET_KEY` env (random fallback) | proxy attaches it server-side |
| bind | `GOOSE_HOST` (default 127.0.0.1) + `GOOSE_PORT` (default 3000) honored — deterministic, no random port. **TLS defaults ON** (`default_tls()` → true): supervisor MUST set `GOOSE_TLS=false` | direct map |
| storage | SQLite at `{data_dir}/sessions/sessions.db` (WAL) | informational |

**Session list solution (v1):** the adapter created every goose session via
`/agent/start`, so it persists its own session index (id, title, directory, timestamps)
and hydrates rows via `GET /sessions/{id}`. No SQLite spelunking, no pagination
emulation needed at goose's session counts.

**Streaming note:** goosed streams **whole `Message` objects, not token deltas**, while
OpenChamber's pipeline consumes `message.part.delta`. The adapter diffs successive
`Message` payloads per message-id and emits synthetic `message.part.delta` /
`message.part.updated` events; `Finish`/`Error` → `session.idle`. Coarser streaming for
goose conversations is accepted (honest, not faked).

**Transport is swappable:** goosed REST carries a `TODO(acp-migration)`
bridge-pending-removal comment; goose's ACP JSON-RPC server
(`crates/goose/src/acp/server.rs`: `on_initialize`, `on_new_session`, `on_prompt`,
`SessionNotification` chunk streaming) is the declared future and has finer streaming +
session-list capabilities. Build REST now; keep the adapter's transport module isolated
so ACP can replace it without touching the client shape. (Epistemos already has Swift
ACP code — `GooseACPClient.swift` — as protocol reference.)

---

## §4 EMBED RULES (verified)

1. Load the SPA from `http://127.0.0.1:<uiPort>` (the web server). Same-origin for REST,
   SSE, and the PTY WebSocket. Plain `WKWebViewConfiguration` — no
   `allowUniversalAccessFromFileURLs`, no custom-scheme secure registration, no private
   APIs (not because of MAS — because it's the correct topology).
2. **Disable the PWA lifecycle in the vendored build** [VERIFIED-CODE]:
   `packages/web/vite.config.ts` uses `VitePWA({ registerType: 'autoUpdate',
   injectManifest: { filename: 'sw.ts' } })` and `packages/web/src/main.tsx` calls
   `registerSW()`. Strip/flag both. A cached service worker fighting a vendored bundle is
   the Step-0 stale-bundle bug all over again — kill it at the root.
3. **Stub the self-updater** [VERIFIED-CODE]: `useUpdateStore.ts` calls
   `/api/openchamber/update-check`. The proxy answers "no update"; hide the affordance.
   Update path = upstream merge + app release, never in-app.
4. Loopback pinning discipline carries over from the existing goose UI server: bind
   127.0.0.1 only, never weaken origin checks.
5. Keys: engine API keys stay in macOS Keychain, bridged to child-process env at spawn
   (existing `GooseProviderKeyBridge` pattern). `X-Secret-Key` and
   `OPENCODE_SERVER_PASSWORD` are generated per-launch, held by Swift + web server only.

---

## §5 JUNE SIGNATURE — MESSAGE BAR + GRADIENT ONLY

Scope (owner-locked): **the composer/message bar styling + the theme-derived landing
gradient. Nothing else.** Stock OpenChamber themes remain; no global warm pass.

- **Source of truth exists locally:** `.research-clones/june` — measure the bar's real
  geometry/colors (the consensus claim "June source not publicly locatable" is wrong for
  us; we have the clone). Prior June token extraction (oklch values) from the goose-fork
  work is reusable reference.
- **Gradient hook** [VERIFIED-CODE]: extend `packages/ui/src/lib/theme/cssGenerator.ts`
  (`generate(theme)` emits CSS vars from `theme.colors.{primary,surface,interactive,
  status}`) to ALSO emit derived vars for every theme, custom themes included:
  `--landing-gradient-start = color-mix(in oklab, surface.background 92%, primary.base 8%)`,
  `--landing-gradient-end = color-mix(in oklab, surface.background 78%, primary.base 22%)`
  (tune ratios against June side-by-side). Classic light theme → white with a slight tan
  wash. New files/vars only; no scattered component CSS.
- **Message bar:** one styled composer component family (landing + in-session — it's the
  same composer), June geometry/fill/stroke/shadow, OpenChamber behavior untouched
  (chips, queue, attachments all keep working). Engine chip lives here.
- **Typewriter greeting:** landing headline content swap only; project/worktree pickers
  and the rest of the landing stay donor-stock.
- **Native pill / all-chats sheet / mascot overlay:** native Swift layer, zero donor-DOM
  edits. All-chats sheet mirrors the donor's project→worktree→session grouping (goose
  rows: directory grouping + engine badge, no branch).

---

## §6 VENDORING + UPDATE WORKFLOW

- **Fork + upstream remote** (adjudicated winner over submodule/subtree):
  fork `openchamber/openchamber`; the vendored fork is its OWN working copy/repo —
  **never inside the Epistemos git tree** (`.research-clones/` stays git-ignored;
  never `git add -A`; no worktrees — owner law).
- **Overlay discipline:** Epistemos code in NEW files only
  (`packages/ui/src/epistemos/*`, `packages/web/server/lib/goose/*`, June bar component,
  gradient emission). Unavoidable in-place edits (SW/updater strip, client-wrapper
  injection, cssGenerator extension) each get a row in `docs/PATCH_LEDGER.md` in the fork.
- **Matched-triple pinning:** OpenChamber tag/SHA + `@opencode-ai/sdk` (1.17.12 at the
  verified clone) + bundled opencode binary move together, never independently. goosed
  binary pinned separately (surface is stabler); re-verify `/reply` `MessageEvent` shape
  on each goose bump.
- **Update cadence:** fetch upstream → merge (conflicts only in patch-ledger files) →
  `bun install && bun run build` → smoke: boot web server + load in WKWebView → tag.
- Remotes: `github.com/openchamber/openchamber`, `github.com/anomalyco/opencode`,
  `github.com/aaif-goose/goose` (post-move canonical, verified live).

---

## §7 PHASES (Pro build order)

- **Phase 0 — Vendor + boot.** Fork OpenChamber; SW + self-updater disabled; Swift
  supervisor (extended existing family) boots web server; WKWebView loads
  `127.0.0.1:<uiPort>`; SSE + PTY WebSocket verified same-origin. *De-risks the embed
  first.*
- **Phase 1 — OpenCode engine end-to-end.** Bundle opencode binary; attach via
  `OPENCODE_PORT` + `OPENCODE_SKIP_START`; chat/diff/terminal/git/files all green through
  the vendored UI. This is the "everything works" baseline.
- **Phase 2 — Owner signatures.** Native pill, typewriter headline, all-chats sheet,
  June bar + gradient (per §5). No engine work in this phase.
- **Phase 3 — goose engine.** `/goose/*` proxy + `gooseClient` adapter + event
  translation; engine chip; merged session list with badges; directory-grouping
  degradation; capability hiding (todos/branch/commands where goose lacks them).
- **Phase 4 — Allocation + polish.** Providers through OpenCode (Claude/OpenAI/HF/local);
  goose reserved for its unique value (MCP extensions, recipes, scheduler, ACP
  subscription reuse). Feature-ledger reconciliation. 1Code-inspired polish (cooking
  animation, diff-review niceties) rebuilt from donor primitives.
- **Phase 5 — Lifecycle hardening** (NOT MAS): zombie cleanup, port-collision honesty,
  crash-restart backoff, memory ceilings for three child processes on 16 GB, launch/quit
  soak. Reuse the 2026-06-29 hardening-log patterns.

CLI agents (Claude Code / Codex) are **not** direct engines in v1 — they ride through
OpenCode providers or goose. A third engine family recreates 1Code's orchestrator shape.

---

## §8 FEATURE LEDGER SEED (shipping gate — close every row)

| Feature | Lives | Engine(s) | Risk |
|---|---|---|---|
| Project→worktree→session sidebar + pagination | donor stores/sidebar | OpenCode native; goose degraded (dir-only) | Med |
| Chat + streaming + tool UIs + diffs | donor chat | both (goose coarser streaming) | Med |
| Permissions/questions | donor + event translation | both | High (goose shim) |
| Files / git panel / terminal PTY | **web server routes** (engine-independent) | n/a | Med (server must stay alive) |
| Message queue (reorder) | donor `messageQueueStore` | both | Low |
| Providers/models picker | donor config | per-engine | Low |
| MCP extensions / recipes / scheduler | goose-only surfaces, badge-gated | goose | Med |
| Multi-run / worktrees | donor | OpenCode first | High |
| Native pill / typewriter / all-chats / mascot hook | native Swift | n/a | Low |
| June bar + derived gradient | §5 | n/a | Low |
| Self-updater + PWA SW | — | — | **must be stubbed** |

---

## §9 CORRECTIONS LOG (research-corpus claims overruled — do not resurrect)

1. ~~MAS-targeted, sandboxed, Phase "MAS hardening", security-scoped bookmarks~~ →
   **Pro-only** (owner 2026-07-03).
2. ~~Ship june-warm.json as default theme~~ → June = **bar + gradient only**.
3. ~~goosed TLS off by default~~ → **ON by default**; set `GOOSE_TLS=false`.
4. ~~goosed picks a random port~~ → `GOOSE_HOST`/`GOOSE_PORT` honored, default
   `127.0.0.1:3000`.
5. ~~confirmation payload `{request_id, approve|deny}`~~ → `{id, principal_type, action:
   Permission, session_id}`.
6. ~~June source not locatable~~ → local clone at `.research-clones/june`.
7. ~~`/recipe/*`~~ → `/recipes/*` (plural).
8. ~~greenfield Swift EngineSupervisor~~ → extend existing `GooseRuntimeSupervisor`
   family + `GooseProviderKeyBridge`.
9. Event pipeline also consumes **`message.part.delta`** (token deltas) — adapter must
   synthesize deltas, not only `part.updated`.
10. SDK pin at verified clone is **1.17.12** (corpus said 1.17.13 — pin whatever the
    vendored tag declares, as a triple).

## §10 OPEN QUESTIONS (with working defaults — build proceeds on defaults)

1. goose session list → **default: adapter-owned index** (§3). Owner may later approve
   SQLite read.
2. ACP now vs later → **default: REST now, transport swappable** (§3).
3. Cloudflare tunnel / remote SSH donor features → **default: disabled in v1**, revisit.
4. Mascot overlay behavior on the Agent surface → hook only in Plan 1; full spec Plan 5.

## §11 GUARDRAILS

- Never modify goose crates; never modify `../opencode`; donor edits only via patch
  ledger.
- Never `git add -A`; never commit `.research-clones/`; no git worktrees, ever.
- Don't touch the graph, editors (Plan 2), or capabilities plumbing (Plan 3) from this
  track.
- Swift changes: `xcodebuild` on isolated DerivedData, `CODE_SIGNING_ALLOWED=NO`,
  BUILD SUCCEEDED before commit. Never two xcodebuilds concurrently (16 GB machine).
- Commit after every coherent change; report honestly (no "done" without the §8 ledger).
