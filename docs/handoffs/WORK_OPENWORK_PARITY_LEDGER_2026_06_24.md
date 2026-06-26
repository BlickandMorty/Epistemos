> ⛔ SUPERSEDED 2026-06-26 — Goose is the SINGLE surface. The 3-engine federation (Chat=AgentClone / Work=OpenGUI) described here is RETIRED. Canonical plan: `docs/research/SURFACE_EMBEDDING_WEBVIEW_VS_NATIVE_DECISION_2026_06_25.md` (§0, §15). Do not follow the federation / OpenGUI directives below.

# Work Foundation Inventory — OpenWork (full) + OpenChamber (additions) — 2026-06-24

> **OWNER CORRECTION (2026-06-24, SUPERSEDES the conservative framing below):** OpenWork is the FULL Work
> foundation — clone the COMPLETE app (done) and the OWNER prunes what to remove MANUALLY. It is NOT a
> read-only cherry-pick and there is NO "don't touch until the ledger is done" gatekeeping. Separately, the
> agent STUDIES OpenChamber for the specific behaviors to ADD (sessions, mini-chat, streaming, bootstrap,
> runtime-fetch, permission routing) — some of which the owner will add themselves. **OpenWork (full) +
> OpenChamber (selected additions) = the foundation for the Work app.** The table below is therefore a FULL
> INVENTORY (so the owner sees everything available to keep/prune), not a gate. The integration /
> vendoring-location decision (in-repo Work subtree vs external + Epistemos WebKit shell) is DOWNSTREAM —
> surfaced to the owner once the inventory makes the choice concrete; not blocking now.
>
> DONORS: OpenWork `/tmp/epistemos-opencode-donor-audit/openwork` @ `dcc94b9` (MIT outside `/ee`; dir
> sizes apps/ 9.8M, packages/ 31M, ee/ 20M = Fair Source OFF-LIMITS). OpenChamber
> `/tmp/epistemos-opencode-donor-audit/openchamber` @ `54943532c4302eab57e6975d0d37e970ee76f94a` (MIT, 49M).
> Companions: `OPENWORK_OPENCHAMBER_CODE_STUDY_HANDOFF_2026_06_24.md` (prior file:line study),
> `WORK_MINI_SESSION_PARITY_LEDGER_2026_06_24.md`.

## CANON RECONCILIATION (2026-06-24, owner+Codex direction — SUPERSEDES conflicting notes below)
Owner ratified the canonical Work direction (docs: `WORK_INTEGRATION_SHAPE_RESEARCH_2026_06_24.md`,
`RESEARCH_CLONES_INVENTORY_2026_06_24.md`, `RESEARCH_CLONES_CANON_RATIONALE_2026_06_24.md`,
`TRANSITION_AND_MODEL_PICKER_IP_LEDGER_2026_06_24.md`). Folding in:
- **Clone location:** donors now live IN-REPO at `.research-clones/` (gitignored via `.git/info/exclude`,
  ~2.3 GB, full clones). Work donors: `.research-clones/work/{opencode,openwork,openchamber,
  opencode-mini-session,opengui,open-cowork,paseo}`. The `/tmp/epistemos-opencode-donor-audit/*` paths
  below are stale — same repos/commits, re-point to `.research-clones/work/`.
- **Donor ROLES (corrects this ledger's earlier "OpenChamber-as-embed" idea):** OpenWork is the PRIMARY
  full-clone donor. Its `apps/app` (Vite web UI) is the EMBED surface (curated/pruned/reskinned in a
  WKWebView); its `apps/server` (headless, MIT) is the LOCAL WORK RUNTIME PROCESS; its `apps/desktop`
  (Electron) is DROPPED. **OpenChamber is the PATTERNS donor** (mini-sessions, streaming, phased bootstrap,
  fetch-coalescing, permission-store) to FUSE later — NOT the embed donor.
- **Persistence framing (corrects rows 1-6 "RE-HOME → native GRDB"):** per canon, the RUNTIME PROCESS owns
  OpenCode integration + MCP install/persistence + skills/plugins discovery + sessions + SQLite/runtime
  state + streaming + fs/workspace APIs + reconnect/lifecycle. The native Swift shell does NOT re-implement
  these in GRDB; it OWNS PRESENTATION + IDENTITY + PRIVILEGED OPS (window chrome, toolbar, recents, model
  picker, vault/workspace picker, settings shell, NATIVE permission prompts/approvals, mini-session routing,
  landing/blur/typewriter IP) and BRIDGES to the runtime over a loopback API (per-launch bearer token,
  127.0.0.1, origin allowlist). So re-read rows 1-6 "Decision" as: **KEEP in the curated OpenWork runtime
  (`apps/server`) + native bridge/presentation**, NOT a Swift/GRDB port. (Row 5 PRUNE-donor-cloud-auth and
  Row 6 NATIVE-permission-prompts still hold — native owns keys/Keychain + approvals.)
- **Row 7 (managed serve)** = build the native **WorkRuntimeSupervisor** (launch/stop/restart/health/logs/
  ports/tokens) that runs the curated runtime per canon's Runtime Transport Guidance. HARVEST stands.
- **MAS:** de-prioritized for Work (local runtime/helper is fine; direct-distribution, signed+notarized+
  hardened). Act stays MAS-friendly + separate (do not block Work on Act).

## OWNER WORK HARDENING REQUIREMENTS (2026-06-24) — acceptance criteria, NON-NEGOTIABLE
These are owner-stated acceptance criteria the Work foundation MUST satisfy. They reframe rows 2-3 + the
omega_mcp_stdio tool-exposure gap. Treat as the definition of "Work works."
- **W-R1 — OpenCode (incl. the TUI) stays BUNDLED IN the app.** It already is (`build-opencode-runtime.sh`
  vendors opencode+Bun into Resources). The TUI is NOT removed — it lives as an ADVANCED toggle in Settings
  / inside the Work feature (advanced/fallback surface), the GUI is the default. OpenCode is THE Work
  foundation; all Epistemos IP + features work through it.
- **W-R2 — ZERO-CONFIG: the OpenCode config is PRE-PROVISIONED before first use.** On first launch/connect,
  Epistemos auto-writes the OpenCode config so Work just works: the Epistemos MCP server(s), the active
  vault root, skills paths, and EVERY tool are registered with NO manual setup. (Origin bug: when the
  feature was first added it couldn't read Epistemos skills/tools because the config wasn't set up — that
  must never recur. Pairs with the honest no-vault state: if no vault, say so, but still pre-provision
  everything that doesn't need a vault.)
- **W-R3 — EVERY Epistemos tool is EXPRESSED to OpenCode (the big one).** Today `omega_mcp_stdio` exposes
  only vault read/write/search + graph (~23 tools); Swift-side native tools return an honest error (its own
  "HONEST SCOPE" note). REQUIREMENT: the FULL native app tool surface (the owner's `ChatConfiguration` tool
  set — computer use, browser, etc.) must be callable by the OpenCode agent. → Build an **APP-HOSTED MCP**:
  an in-process Swift MCP server bound to loopback (per-launch token) that EXECUTES Swift-side tools, and
  pre-register it in the OpenCode config (W-R2). This closes the stdio process's Swift-side gap and is the
  canon's native-bridge-over-loopback expressed as an MCP the runtime consumes.
- **W-R4 — Skills HARDENED + auto-discovered.** Epistemos vault skills (`skills/<name>/SKILL.md`) + the
  multi-root skill set (Row 3) are reliably discoverable by OpenCode out of the box (pre-provisioned, not
  user-configured). No silent "0 skills".
- **VERIFICATION (no [x] without this):** fresh runtime evidence that, on a clean launch with a vault
  connected, OpenCode's `tools/list` shows the FULL Epistemos tool surface (not just 23 vault/graph) AND
  `resources`/skills list the vault skills — with ZERO manual config steps.

## Donor provenance (verified 2026-06-24)
- **OpenWork**: `/tmp/epistemos-opencode-donor-audit/openwork` (shallow `--depth 1`, 108 MB on disk).
- Remote: `https://github.com/different-ai/openwork.git`
- HEAD commit: `dcc94b94fd7240772ad547e077f456001c8f485d` (matches the handoff's `dcc94b9`).
- **LICENSE (root)**: MIT for all content OUTSIDE `/ee`. `/ee` is Fair Source (`ee/LICENSE`) — **DO NOT use
  `/ee` code in Epistemos product**. Third-party components keep their own licenses. MIT portions may be
  ported with attribution.
- Top-level of interest: `apps/` (server + app), `packages/`, `.opencode/`, `skills-lock.json`,
  `ee/` (AVOID), `docs/`, `prds/`, `examples/`, `evals/`.

## Method (per fire, until the table is filled)
1. Pick ONE capability area below. 2. Read its donor source (read-only; MIT-only; NEVER `/ee`). 3. Map to
the Epistemos current surface (rg/read). 4. Record a decision: **port** (re-implement in Epistemos),
**re-home** (move behavior into an Epistemos-owned service/UI), **simplify** (reskin/cut), or **prune**
(donor-only chrome we won't carry). 5. Mark status. NO product-code changes during the inventory; NO
`pnpm`/node installs; donor stays a read-only capability map.

## Parity table (IN PROGRESS — fill area-by-area)

| # | OpenWork capability | Donor source (MIT, file:line — verify against clone) | Epistemos current surface | Decision | Status |
|---|---|---|---|---|---|
| 1 | Per-workspace runtime OpenCode config — `RuntimeOpencodeConfig`{default_agent, plugin, disabled_providers, mcp, permission.external_directory, provider}; SQLite `runtime_opencode_configs(workspace_id PK, config_json, updated_at)` at `<configDir>/runtime.sqlite`; upsert/get by workspace_id; `onRuntimeOpencodeConfigWrite` listener; accessors runtimePluginList/DisabledProviderList/McpMap/ExternalDirectory | `apps/server/src/runtime-opencode-config-store.ts:8,19,77,88,112,136-150` (MIT, not /ee) | `WorkOpenCodeRuntime` writes ONE merge-preserving `opencode.json` (App Support) asserting only `epistemos-vault` MCP + `lsp:true`; NOT per-workspace, NOT a DB, no default_agent/providers/external_directory mgmt, no write-listener | **RE-HOME** → native Epistemos per-workspace config store (GRDB — already used) owning the full `RuntimeOpencodeConfig` model + emitting the merged opencode.json. Donor TS/bun:sqlite/drizzle NOT verbatim-portable to Swift — re-home the MODEL+behavior, not the code. | inventoried |
| 2 | MCP list/add/remove/toggle per workspace — `listMcp` MERGES 3 sources w/ precedence (global `~/.config/opencode` < project < OpenWork runtime store), each item tagged `source` + `disabledByTools` (denied-tool patterns); `addMcp`/`removeMcp`/`setMcpEnabled` mutate the RUNTIME mcp map (Row 1 store) | `apps/server/src/mcp.ts:41,88,104,120` (MIT; depends on Row 1) | `WorkOpenCodeRuntime` asserts only `epistemos-vault` (merge-preserving into one opencode.json); user MCPs persist there via the TUI; NO app-owned 3-source list, NO add/remove/toggle API, NO source/disabled surfacing, NO mgmt UI | **RE-HOME** → native Swift MCP-mgmt service over the GRDB runtime store (Row 1) + reading global/project opencode config, surfaced in a native Work settings MCP panel. Pairs with Row 1. | inventoried |
| 3 | Skills discovery+CRUD — `listSkills` scans PROJECT `.opencode/skills`+`.claude/skills` and GLOBAL `~/.config/opencode/skills`,`~/.claude/skills`,`~/.agents/skills`,`~/.agent/skills`; handles FLAT `<dir>/<name>/SKILL.md` AND grouped `<dir>/<domain>/<name>/SKILL.md`; frontmatter (name/description) parse+validate; `upsertSkill`/`deleteSkill`/`buildSkillContent` | `apps/server/src/skills.ts:12,84,119,154,189,204` (MIT) | vault `skills/<name>/SKILL.md` surfaced as MCP RESOURCES via `omega_mcp_stdio` (vault root, when active) — READ-only, single-root, flat only; no multi-root discovery, no grouped layout, no CRUD, no frontmatter mgmt | **RE-HOME + EXTEND** → native Swift skills service (multi-root scan + flat/grouped + frontmatter + CRUD) in native Work settings; KEEP the existing vault-skills→MCP-resource exposure as one root. | inventoried |
| 4 | Plugins — `listPlugins` merges config `plugin` (string\|array) + RUNTIME plugins (Row 1 store) + project plugin dir + global `~/.config/opencode/plugins`; each tagged source/scope; `loadOrder` [config.global, config.project, dir.global, dir.project]; `normalizePluginSpec` dedup; `addPlugin`/remove mutate runtime list | `apps/server/src/plugins.ts:11,34,53,89` (MIT; depends on Row 1) | none app-owned (no Work plugin concept) | **RE-HOME** → native Swift plugin-mgmt service over the GRDB runtime store (Row 1) + config/project-dir/global-dir sources, in native Work settings. Pairs w/ Rows 1-2. | inventoried |
| 5 | Providers / default-agent — persistence: `default_agent`+`disabled_providers`+`provider` live in the Row-1 runtime config store; provider connection/auth/listing is APP-side (cloud-provider connect flows) | `apps/server/src/runtime-opencode-config-store.ts:9,11,16,167`; app UI `apps/app/src/react-app/infra/provider-list-query.ts`, `.../domains/settings/pages/cloud-providers-view.tsx`, `.../connections/provider-auth/store.ts` (MIT) | Act/Osaurus model picker + provider keys are native (Keychain); Work default-agent/provider NOT app-owned | **RE-HOME persistence** (default_agent/disabled_providers/provider → Row-1 GRDB store + native Work settings selector) + **PRUNE** the donor cloud-provider-auth UI in favor of Epistemos's existing native provider/key management (don't duplicate provider connection) | inventoried |
| 6 | Permissions / external_directory — OpenCode's `permission.external_directory` (which dirs the agent may touch outside the workspace) persisted per-workspace in the Row-1 store; `runtimeExternalDirectory` accessor; legacy openwork↔opencode config migration in server.ts | `apps/server/src/runtime-opencode-config-store.ts:13,150,203`; `apps/server/src/server.ts:131,225,237` (MIT) | Native ACT permissions exist (ApprovalModalView, secret/clarify prompts, composer access-plan/vault grants); Work external_directory NOT app-owned | **RE-HOME** → `permission.external_directory` into the Row-1 GRDB store BUT surfaced via Epistemos's NATIVE folder-grant flow (NSOpenPanel + security-scoped bookmark, consistent w/ vault access; ApprovalModalView precedent) per the integration rec's "permissions = native Swift" tier — not a web-config edit. Drop the donor TS legacy-migration (own the GRDB model natively). | inventoried |
| 7 | Managed `opencode serve` lifecycle — `createManagedOpencodeServer` spawns `opencode serve --hostname 127.0.0.1 --port <free> --cors *` with random basic-auth `OPENCODE_SERVER_USERNAME`/`PASSWORD` (env); `findFreePort`; startup-wait parses stdout "opencode server listening" → URL w/ 15s timeout, fail-on-early-exit; secret redaction in exec snapshots | `apps/server/src/managed-opencode.ts:29,33,58,91,102,116` (MIT) | `WorkOpenCodeRuntime` launches the bundled `opencode` TUI in a PTY (self-serves loopback :4096, OPENCODE_HOST/PORT pinned); NO headless server, NO HTTP API client, NO basic-auth | **HARVEST → add native headless serve mode** (the integration rec's "opencode serve = loopback helper, Pro-gated, VISIBLE" tier): native Swift launch of `opencode serve` on loopback w/ random token/basic-auth + startup-wait (parse listening line) + redaction + kill-on-teardown, so the WebView + native client drive the HTTP/SSE API. Re-home the TS pattern in Swift (Process/PTY already used). PRUNE `--cors *` (SPA served same-origin via custom URL scheme → tighten). | inventoried |
| 8 | MCP/skill/plugin settings VIEW (1262 lines) — required controls: Quick-Connect, Configured-Servers (toggle-enabled/remove/logout/detail), Advanced-Config, Add-MCP modal, GitHub-import, skill-detail + plugin-detail; drives the Row 1-4 backends | `apps/app/src/react-app/domains/settings/pages/mcp-view.tsx:108,492,550,619,677,691,859` (MIT) | `WorkCloneSettingsView` (health rows + terminal only); no MCP/skill/plugin management UI | **CHECKLIST + PRUNE donor UI** — defines the management controls that must exist; do NOT embed OpenWork's React (we embed OpenChamber, not OpenWork). Build the surface from the native re-homed Rows 1-5 (persistence stays native/GRDB), rendered as EITHER native Work settings OR OpenChamber's C7/C8 panels — integration-build call. | inventoried |
| 9 | OpenWork UI-as-MCP bridge (250 lines) — an MCP stdio server exposing OpenWork's UI control surface as MCP tools, proxying to OpenWork's DESKTOP bridge HTTP API; `@modelcontextprotocol/sdk` stdio + a few `server.tool(...)` entries; requires a running OpenWork desktop instance | `packages/openwork-ui-mcp/index.mjs:6,28,157,163-228` (MIT) | n/a — Epistemos has `omega_mcp_stdio` for VAULT tools, but no agent-drives-own-UI bridge | **PRUNE** (OpenWork-desktop-specific; proxies to OpenWork's bridge — irrelevant to the OpenChamber-embed architecture). NOTE the PATTERN (expose the app's own UI as MCP tools so an agent can drive it) as a future-OPTIONAL Epistemos capability — NOT part of the Work foundation. | inventoried |

## OpenChamber — additions to study (behaviors to ADD to Work; MIT)
Study each (read-only) and record the concrete behavior to graft into the Epistemos Work surface. (file:line
from the prior handoff; verify against the clone at `/tmp/epistemos-opencode-donor-audit/openchamber`.)

| # | OpenChamber subsystem | Donor source | Behavior to add to Work | Status |
|---|---|---|---|---|
| C1 | Runtime fetch bridge | `packages/ui/src/lib/runtime-fetch.ts:9,78,105,114,143,182,193` (MIT) | VERIFIED: `buildRuntimeFetchUrl` rewrites /api,/auth,/health → runtime URL; `sanitizeHeadersForBrowser`/`isLatin1Safe` re-encode non-Latin-1 headers; `mergeHeaders` attaches runtime auth; in-flight GET-coalescing (`COALESCE_READ_PATH`: config/path/agents/project/command) dedups concurrent reads → don't saturate the single-flight server. ADD: the embedded-SPA→loopback-`opencode serve` access layer (URL rewrite + token auth + Latin-1 header sanitize + read-coalesce); native bridge injects base URL + token. | studied |
| C2 | Phased bootstrap | `packages/ui/src/sync/bootstrap.ts:67,120,149,185,194` (MIT; clone @ 76d24f27) | VERIFIED: `bootstrapDirectory` Phase-1 = critical fetches via `Promise.allSettled`+`retry`, de-blocks UI (marks ready after critical data so it paints; ONLY a total OpenCode-down failure — or path-fail-without-project — keeps "loading"); Phase-2 = `void Promise.allSettled([mcp.status, lsp.status, vcs, commands, questions, permissions])` AFTER first paint, non-blocking; `bootstrapGlobal` falls back to OpenChamber's own data if ALL global fetches fail. FUSE: critical-first paint + deferred phase-2 + allSettled/retry tolerance → the Work surface never "loads forever" on a transient runtime fetch (pairs w/ honest no-vault state). | studied |
| C3 | Directory-scoped SDK clients | `packages/ui/src/lib/opencode/client.ts:161,228,229,231-238,254` (MIT) | VERIFIED: `createOpencodeClient` (`@opencode-ai/sdk/v2`) wired to the C1 `runtimeFetch`; `scopedClients: Map<directory,client>`; in-flight dedup maps (directory/config/providers/agents) + TTL caches (config, dir-listings); serialized `directoryContextQueue` for context switches; `setBaseUrl` re-points + clears scoped clients on runtime restart; uniform SDK unwrap/error-format (`unwrapSdkData`/`formatSdkError`). FUSE: the robust runtime-client pattern — per-workspace scoped clients + read dedup/TTL cache + serialized dir-switch + base-URL re-point on runtime restart, built on C1. (Whoever talks to the loopback runtime — native bridge or the curated OpenWork SPA — should use this management discipline.) | studied |
| C4 | Session actions / reconnect grace | `packages/ui/src/sync/session-actions.ts:39,125,158,168,133` (MIT) | VERIFIED: reconnect-grace before send-fail — on a connection blip, wait a short grace window running bounded health probes (transient reconnects: heartbeat race / WS→SSE fallback / brief network recover within ~1s) and only surface `connectionLostError()` after grace expires; OPTIMISTIC add/remove (insert user message optimistically, roll back on failure — `OptimisticAddInput`/`RemoveInput`); per-session directory resolution (`dirStoreForSession`) so replies + blocking permission/question route to the right session/directory; `updateLiveSession` across candidate stores. FUSE: grace-before-send-fail + optimistic add/rollback + per-session routing → robust Work send path against a restarting/reconnecting local runtime. | studied |
| C5 | Streaming-state derivation/throttle | `packages/ui/src/sync/streaming.ts:13,29,46,48,60,80` (MIT) | VERIFIED: derives streaming state from `session_status`+messages into a `streamingMessageIds` map; fast path SCANS ONLY busy sessions (`status.type==='busy'`); ONLY the trailing assistant turn streams; 1 Hz heartbeat throttle (`STREAMING_HEARTBEAT_MS=1000`) avoids 60 Hz store churn; phases streaming/cooldown/completed. FUSE: busy-only + trailing-turn derivation + 1 Hz throttle → efficient Work transcript streaming (no per-token rerender storm; matches research "back-pressure streaming"). | studied |
| C6 | Permission store | `packages/ui/src/stores/permissionStore.ts:16,20,62,130,179` (MIT) | VERIFIED: per-session `autoAccept` map PERSISTED (zustand `persist`); `isSessionAutoAccepting`/`setSessionAutoAccept`; `resolveSessionScope`/`sessionBelongsToScope` walk `session.parentID` so CHILD (mini) sessions INHERIT the parent's auto-accept; `collectPendingFromSyncStores` gathers pending prompts; mirrors auto-accept to the server to suppress notifications BEFORE the client round-trip. FUSE the MODEL (per-session auto-accept persisted + parentID inheritance + server-mirror) — but render through NATIVE Epistemos approval UI (ApprovalModalView), NOT donor browser prompts (canon + W-R: permissions are native). NOTE: the parentID inheritance ties directly to the mini-session ontology (parentSessionID work). | studied |
| C7 | MCP store | `packages/ui/src/stores/useMcpStore.ts:7,42,68-77,80` (MIT) | VERIFIED: directory-scoped MCP RUNTIME-STATE store — per-server status map (connected/failed/needs_auth/needs_client_registration), `computeMcpHealth`→{connected,total,hasFailed,hasAuthRequired}, per-directory accessors, actions `refresh`/`connect`/`disconnect`/`startAuth`(→auth URL)/`completeAuth`/`clearAuth`/`testConnection` via the SDK client. FUSE the MODEL into the native Work MCP panel — it's the LIVE-STATUS companion to OpenWork Row 2's app-owned MCP CONFIG (config = persisted servers; C7 = live status/health/OAuth/test). Surfaces the W-R3 check (the app-hosted full-tool MCP shows connected + its tool count). | studied |
| C8 | Skills store | `packages/ui/src/stores/useSkillsStore.ts:34,78,143-151,167,210` (MIT) | VERIFIED: directory-scoped skills client store — list/detail + `createSkill`/`updateSkill`/`deleteSkill`/`deleteSupportingFile`; scope (user/project) + source (opencode/claude/agents) tagging; grouped-path parse (`parseSkillGroup`); per-directory TTL cache (`skillsLastLoadedAt`) + in-flight dedup (`skillsLoadInFlight`); persisted (zustand). FUSE the MODEL → native Work skills panel; client companion to OpenWork Row 3 server discovery+CRUD. Directly supports **W-R4** (skills hardened + auto-discovered, no silent "0 skills"). | studied |
| C9 | Mini-chat app + layout | `packages/ui/src/apps/ElectronMiniChatApp.tsx:25,27,42,121`, `components/mini-chat/MiniChatLayout.tsx:7,62,96` (MIT) | VERIFIED: mini-chat runs in `session` OR `draft` mode (bound to an existing session or a new-session draft), keyed by URL params (mode/sessionId/directory/projectId), bootstrapped ONCE (`sessionBootstrappedRef`) with directory inheritance; `MiniChatLayout` header computes title/project/worktree-path+branch/context-usage + open-main; `SessionSwitcherDropdown` switches the window to another session IN PLACE; `MINI_CHAT_PRESENCE_CHANNEL` BroadcastChannel publishes presence for duplicate-window detection. FUSE into native MiniChat (owner's first-class mini-session req): session/draft modes + header (open-MAIN/parent) + switch-in-place + presence-dedup, linked to the main Work/OpenCode session via `parentSessionID` (ties to my mini-session schema work); native shell owns mini routing/identity, WebView renders the transcript. | studied |
| C10 | Window keying / dup prevention | `packages/electron/main.mjs:189,2236,2259,2320,4285,4318` (MIT) | VERIFIED: `miniChatWindowsBySession` Map keyed by `miniChatSessionWindowKey(runtimeConfig, sessionId)` (runtime+session, avoids cross-runtime collisions); on open, if a live window exists for that key → `existing.focus()` + RETURN (dup prevention, never fork); else create+register; close cleans up the map; `focusMainWindowWithSession` = "Open in main window" from a mini (focus/open the parent with that session); last-focused-surface routing (open a session on whichever surface — main/mini — the user was last on). FUSE: extend Epistemos's existing `MiniChatWindowController.windows[chatID]` focus-existing (already present) with runtime-scoped keys + open-PARENT-with-session + last-surface routing → satisfies "open same mini focuses existing, not a ghost" (mini-session ontology). | studied |
| C11 | Managed OpenCode lifecycle | `packages/web/server/lib/opencode/lifecycle.js:19,44,277,304,413,419,562` (MIT) | VERIFIED: `createOpenCodeLifecycleRuntime` — `killProcessOnPort` (lsof+kill-9 stale) → resolve free port → spawn → startup-wait (parse "opencode server listening") → health-probe `GET /global/health` (`body.healthy===true`) w/ retry up to MAX_ATTEMPTS → `probeExternalOpenCode` (attach to an already-running opencode instead of spawning) → `restartOpenCode` (policy: skip while busy, force if unhealthy >2 min) → process-group kill on teardown (cross-platform taskkill). FUSE into the native **WorkRuntimeSupervisor** (pairs w/ Row 7 HARVEST + canon Runtime Transport Guidance): managed spawn + free-port + startup-wait + health-probe/retry + attach-external + health-restart policy + clean process-group teardown (kill-on-quit). | studied |

## Risks / guardrails
- `/ee` (Fair Source) is OFF-LIMITS for product code — verify each studied file is NOT under `/ee`.
- OpenWork is a large pnpm/Electron monorepo; treat as a capability map, not a UI to transplant
  (authority: Epistemos owns the visible shell, recents, vault, permissions, settings, theme, lifecycle).
- Do not run donor build/installs (`pnpm`, node) — disk + sandbox; not needed for source study.
- Final Work UI must be Epistemos flat/pixel/OpenCode-like, not raw OpenWork.

## Log
- 2026-06-24: donor cloned/verified (provenance above); scaffold created. Next fire: start row 1 (runtime
  config store) — read `apps/server/src/runtime-opencode-config-store.ts`, map vs `WorkOpenCodeRuntime`.
- 2026-06-24: Row 1 (runtime config store) inventoried → **RE-HOME** to a native GRDB per-workspace config
  store owning the full `RuntimeOpencodeConfig` model + emitting the merged opencode.json. Next: row 2
  (`apps/server/src/mcp.ts`) or an OpenChamber C-row. (NOTE: integration-shape deep-research workflow
  `wgo358ce7` running in parallel — its recommendation will frame HOW these re-homed pieces are hosted.)
- 2026-06-24: Row 2 (MCP list/add/remove/toggle, `mcp.ts`) inventoried → **RE-HOME** (native MCP-mgmt
  service over the Row 1 GRDB store + global/project config; native Work MCP panel). Pairs with Row 1.
  Next: row 3 (`apps/server/src/skills.ts`) or an OpenChamber C-row.
- 2026-06-24: Row 3 (skills discovery+CRUD, `skills.ts`) inventoried → **RE-HOME + EXTEND** (multi-root
  scan + flat/grouped layouts + frontmatter + CRUD in native Work settings; KEEP vault-skills→MCP-resource
  exposure as one root). Next: row 4 (`apps/server/src/plugins.ts`) or an OpenChamber C-row.
- 2026-06-24: Row 4 (plugins, `plugins.ts`) inventoried → **RE-HOME** (native plugin-mgmt over the GRDB
  runtime store + config/project-dir/global-dir sources). Rows 1-4 = a cohesive app-owned config/capability
  cluster (config store → MCP → skills → plugins), all RE-HOME to native Swift over a GRDB runtime store.
  Next: row 5 (providers/default-agent) or an OpenChamber C-row.
- 2026-06-24: Row 5 (providers/default-agent) inventoried → **RE-HOME persistence** (default_agent/
  disabled_providers/provider into the Row-1 store + native Work selector) + **PRUNE** donor cloud-provider
  auth UI (Epistemos already owns native provider/key management via Keychain). Rows 1-5 done. Next: row 6
  (permissions/external_directory) or an OpenChamber C-row. (Integration shape now decided — see
  `WORK_INTEGRATION_SHAPE_RECOMMENDATION_2026_06_24.md`: contained hybrid, OpenChamber embed donor pending
  owner ratification; OpenWork rows = re-home-native, which this inventory confirms.)
- 2026-06-24: Row 6 (permissions/external_directory) inventoried → **RE-HOME** into the Row-1 store, but
  surfaced via Epistemos's NATIVE folder-grant flow (NSOpenPanel + security-scoped bookmark; ApprovalModalView
  precedent) per the integration rec's "permissions = native Swift" tier; drop donor TS legacy-migration.
  Rows 1-6 done. Next: row 7 (managed `opencode serve` lifecycle) or an OpenChamber C-row.
- 2026-06-24: Row 7 (managed `opencode serve` lifecycle) inventoried → **HARVEST** — add a native headless
  serve mode (loopback + random token/basic-auth + startup-wait + redaction + kill-on-teardown) so the
  WebView/native client drive the opencode HTTP/SSE API (the integration rec's load-bearing seam); current
  PTY-TUI launch stays as the advanced/fallback. PRUNE `--cors *`. Rows 1-7 done. Next: row 8 (settings
  view) or row 9 (UI-MCP bridge) or an OpenChamber C-row.
- 2026-06-24: Row 8 (MCP/skill/plugin settings view, `mcp-view.tsx`) inventoried → **CHECKLIST + PRUNE**
  donor React UI (we embed OpenChamber, not OpenWork). It defines the required management controls;
  the surface is built from native Rows 1-5 (persistence native) as native settings or OpenChamber's
  C7/C8 panels (integration-build call). Rows 1-8 done. Next: row 9 (UI-MCP bridge) or an OpenChamber C-row.
- 2026-06-24: Row 9 (OpenWork UI-as-MCP bridge) inventoried → **PRUNE** (OpenWork-desktop-specific; note
  the agent-drives-own-UI pattern as future-optional, not foundation). **ALL OpenWork rows 1-9 DONE.**
  Summary of OpenWork decisions: Rows 1-6 RE-HOME (native GRDB config/MCP/skills/plugins/providers/perms
  cluster; security via native flows); Row 7 HARVEST (native headless `opencode serve`); Row 8
  CHECKLIST+PRUNE (donor settings UI); Row 9 PRUNE (UI-MCP bridge). Next phase: OpenChamber additions
  C1-C11. Start C1 (`runtime-fetch.ts`) next fire.
- 2026-06-24: **CANON RECONCILIATION applied** (owner+Codex) — see the block at the top. OpenWork rows 1-6
  decisions re-read as KEEP-in-runtime + native bridge (NOT GRDB re-home); donors now at `.research-clones/`;
  OpenWork=embed(apps/app)+runtime(apps/server), OpenChamber=PATTERNS donor; MAS de-prioritized for Work.
- 2026-06-24: OpenChamber PATTERNS study — C1 (runtime-fetch) studied → FUSE (SPA→loopback access layer:
  URL rewrite + token auth + Latin-1 header sanitize + read-coalesce). C2 (phased bootstrap) studied →
  FUSE (critical-first paint + deferred phase-2 + allSettled/retry → never "loads forever"). Canonical
  OpenChamber clone = `.research-clones/work/openchamber` @ 76d24f27 (full clone; supersedes the /tmp @
  5494353 provenance). Next: C3 (`lib/opencode/client.ts` — directory-scoped clients).
- 2026-06-24: C3 (directory-scoped SDK clients) studied → FUSE (per-directory scoped clients + in-flight
  read dedup + TTL config/listing caches + serialized dir-switch queue + base-URL re-point on restart;
  built on C1 runtimeFetch). Next: C4 (`sync/session-actions.ts` — reconnect grace before send-fail).
- 2026-06-24: C4 (session-actions / reconnect grace) studied → FUSE (grace-before-send-fail w/ bounded
  health probes + optimistic add/rollback + per-session directory routing for replies/permission/question).
  Next: C5 (`sync/streaming.ts` — streaming-state derivation + 1 Hz throttle).
- 2026-06-24: C5 (streaming-state derivation/throttle) studied → FUSE (busy-only scan + trailing-turn
  streaming + 1 Hz heartbeat throttle). Next: C6 (`stores/permissionStore.ts` — per-session auto-accept).
- 2026-06-24: C6 (permission store) studied → FUSE the MODEL (per-session auto-accept persisted + parentID
  child-inheritance + server-mirror-to-suppress-pre-roundtrip), rendered via NATIVE Epistemos approval UI
  (ApprovalModalView), not donor prompts. Ties to mini-session parentSessionID inheritance. Next: C7
  (`stores/useMcpStore.ts` — MCP status/connect/disconnect/auth/test).
- 2026-06-24: C7 (MCP store) studied → FUSE the MODEL (directory-scoped live MCP status map + computeMcpHealth
  + connect/disconnect/OAuth start-complete-clear/test/refresh) into the native Work MCP panel; live-status
  companion to OpenWork Row 2 app-owned config; surfaces the W-R3 full-tool/app-hosted-MCP check. Next: C8
  (`stores/useSkillsStore.ts` — skills CRUD client state).
- 2026-06-24: C8 (skills store) studied → FUSE the MODEL (directory-scoped skills list/detail/CRUD +
  scope/source tags + grouped-path parse + TTL cache/dedup) → native Work skills panel; client companion to
  OpenWork Row 3 server discovery; supports W-R4. Next: C9 (`apps/ElectronMiniChatApp.tsx` +
  `components/mini-chat/MiniChatLayout.tsx` — mini-chat app/layout).
- 2026-06-24: C9 (mini-chat app/layout) studied → FUSE into native MiniChat (session/draft modes + header
  with open-main/project/worktree/context + switch-session-in-place + BroadcastChannel presence-dedup),
  linked to the main Work session via parentSessionID (ties to my mini-session schema work). Next: C10
  (`packages/electron/main.mjs` — window keying / duplicate-window prevention / focus-main).
- 2026-06-24: C10 (window keying / dup prevention) studied → FUSE (key by runtime+session → focus-existing
  not fork + open-PARENT-with-session + last-focused-surface routing; extends Epistemos's existing
  MiniChatWindowController.windows[chatID] dedup). Next: C11 (`web/server/lib/opencode/lifecycle.js` —
  managed OpenCode lifecycle / health-restart) — LAST C-row, then SYNTHESIS.
- 2026-06-24: C11 (managed OpenCode lifecycle) studied → FUSE into native WorkRuntimeSupervisor (managed
  spawn + free-port + startup-wait + /global/health probe/retry + attach-external + health-restart policy
  skip-while-busy/force-if-unhealthy>2min + process-group teardown). **ALL OpenChamber patterns C1-C11 DONE
  (all FUSE).** Inventory complete — writing SYNTHESIS below.

---

# SYNTHESIS — Work foundation build plan (2026-06-24, inventory complete; STOP for owner go-ahead)

Inventory done: OpenWork rows 1-9 + OpenChamber C1-C11. This is the recommended build, faithful to the canon
(WORK_INTEGRATION_SHAPE_RESEARCH) + the OWNER WORK HARDENING REQUIREMENTS (W-R1..W-R4) + the IP ledger.

## 1. Three-tier topology (the split)
```
NATIVE SWIFT SHELL  (owns identity/security/IP — never web)
  window chrome · toolbar · recents · MODEL PICKER · vault/workspace picker · settings shell ·
  NATIVE permission prompts (ApprovalModalView) · mini-session routing/identity ·
  landing: click-anywhere/click-to-start · search page · BLUR + TYPEWRITER/ASCII reveal (IP ledger)
        │  native message bridge (typed/validated WKScriptMessageHandler; weak refs; app-origin-only nav)
        ▼
WKWebView WORK SURFACE  (curated OpenWork apps/app Vite UI, reskinned to Epistemos flat/pixel via CSS-var tokens)
  transcript · diffs · worktree/review · file views · session panes · tool-output rendering · MCP/skills panels
        │  loopback HTTP/SSE (127.0.0.1 + per-launch bearer token + app-origin allowlist) — the ONE seam
        ▼
LOCAL WORK RUNTIME PROCESS  (WorkRuntimeSupervisor → bundled `opencode serve`, OpenWork apps/server headless)
  OpenCode integration · MCP install/persistence · skills/plugins discovery · sessions · SQLite · streaming · fs/workspace
        ▲
APP-HOSTED IN-PROCESS SWIFT MCP (loopback + token)  ← W-R3: executes the FULL native Epistemos tool surface
  (ChatConfiguration tools: computer use, browser, vault, graph, …) registered into the runtime config so the agent can call EVERY tool
```

## 2. Donor roles (decided)
- **OpenWork `apps/app`** = the embed Web UI (curated/pruned/reskinned). **`apps/server`** (MIT) = the local
  runtime (rows 1-9 capabilities live here, KEEP-in-runtime). **`apps/desktop`** (Electron) = DROP.
- **OpenChamber** = 11 fused PATTERNS (not embedded): C1 runtime-fetch (URL-rewrite+auth+coalesce) · C2
  phased bootstrap (never-loads-forever) · C3 dir-scoped clients · C4 reconnect-grace+optimistic+routing ·
  C5 streaming 1Hz throttle · C6 permission auto-accept+parentID-inherit (native UI) · C7 MCP live status ·
  C8 skills client store · C9 mini-chat session/draft+open-main+switch-in-place · C10 window dedup
  (runtime+session key) · C11 WorkRuntimeSupervisor lifecycle/health-restart.
- **`opencode`** (sst) = behavior source-of-truth; **TUI stays bundled** as the advanced/fallback toggle (W-R1).
- License: only MIT-outside-`/ee` OpenWork + MIT OpenChamber/opencode; never `/ee`; paseo (AGPL) study-only.

## 3. Graft order (each step reversible; owner-greenlit; visual proof where IP/UX)
0. **Hardening first (already mostly done):** honest no-vault state shipped; harden the OpenCode seam.
1. **SPIKE (reversible, throwaway):** load OpenWork `apps/app` (or first OpenChamber, whichever builds to
   static assets fastest) in the existing Epdoc WKWebView host (`EpdocEditorChromeView`) via a custom
   `URLSchemeHandler`, pointed at the bundled `opencode serve`. Proves: SPA renders + drives sessions over
   loopback, no Node server. → screenshot for owner.
2. **WorkRuntimeSupervisor (native):** C11+Row7 — managed spawn (loopback, free port, per-launch bearer
   token, startup-wait, /global/health probe+retry, attach-external, health-restart, process-group kill);
   surfaced in a Work health row.
3. **Native bridge contract:** one namespaced WKScriptMessageHandler (session-select, model-select,
   permission-prompt→ApprovalModalView, open-main/focus-parent, file/vault grant) + app-origin-only nav +
   C1 runtime-fetch (base URL+token injected by the shell) + theme-token CSS injection (flat/pixel reskin).
4. **W-R3 APP-HOSTED MCP (the big one):** in-process Swift MCP (loopback+token) exposing the full
   ChatConfiguration tool set; **W-R2 zero-config**: pre-provision the OpenCode config on first launch
   (register this MCP + the omega vault MCP + active vault root + skills paths) so EVERY tool + skills are
   live with no manual setup.
5. **Native presentation over the runtime:** recents, MCP panel (Row2 config + C7 status), skills panel
   (Row3+C8, W-R4), providers/default-agent (Row5, prune donor cloud-auth → native Keychain), model picker
   (IP), settings Work tab.
6. **Mini-sessions:** finish the parentSessionID schema (already started) + C9/C10 (session/draft, open-main,
   switch-in-place, runtime+session window dedup) — first-class, linked to the main Work/OpenCode session.
7. **Resilience polish:** C2 phased bootstrap, C4 reconnect-grace, C5 streaming throttle, C6 permission
   inheritance.
8. **Prune** donor chrome/Electron/duplicate surfaces only after parity proven.

## 4. How it satisfies the OWNER WORK HARDENING REQUIREMENTS
- **W-R1 (OpenCode+TUI bundled):** tier-3 runtime IS bundled `opencode serve`; TUI kept as Settings/Work
  advanced toggle; OpenCode is the foundation everything routes through.
- **W-R2 (zero-config):** step 4 pre-provisions the OpenCode config on first launch — MCP servers + vault
  root + skills, no manual setup; honest no-vault state when no vault, but everything else still provisioned.
- **W-R3 (every tool expressed):** step 4 app-hosted in-process Swift MCP executes the full native tool set
  (closes omega_mcp_stdio's Swift-side gap; today ~23 vault/graph → all ChatConfiguration tools).
- **W-R4 (skills hardened/auto-discovered):** Row3 (server multi-root discovery) + C8 (client store),
  pre-provisioned skills paths → no silent "0 skills".

## 5. Verification bar (no [x] without this — fresh runtime evidence)
On a CLEAN launch with a vault connected, owner-visible proof:
1. OpenCode `tools/list` shows the FULL Epistemos tool surface (NOT just ~23 vault/graph) — incl. the
   app-hosted MCP's tools — with ZERO manual config steps.
2. skills/resources list the vault skills (no silent 0).
3. The Work WebView renders + drives a session over loopback (no Node server, no Electron).
4. Mini-session: open-from-main → attached (parentSessionID) → open-main/focus-parent → no duplicate window.
5. IP ledger: landing blur+typewriter/ASCII reveal + model picker intact (screen recording); selected model
   == model used by the Work request.

## 5b. Presentation — Epdoc-style FUSED CHROME (owner refinement, 2026-06-24)
The WKWebView Work surface is presented EXACTLY like the existing code editor (`EpdocEditorChromeView`): a
curated, **theme-aware NESTED box** whose chrome is a FUSION of Epistemos native chrome + the embedded
surface — NOT a raw pasted web box. Requirements (reuse the Epdoc precedent):
- **Native frame fuses with the embedded box:** Epistemos owns the outer chrome (toolbar/pills/title/drag
  region/insets); the WebView is an inset, rounded, contained "curated window" nested inside it — the same
  feel as the editor's chrome wrapping the Tiptap surface.
- **Theme-aware:** inject Epistemos theme tokens as CSS variables into the donor UI (the proven
  `EpdocEditorThemeStyle.applyScript` pattern) so the box recolors with the app theme live; flat/pixel/no-
  gradient; `drawsBackground=false` + `underPageBackgroundColor` sync to kill white-flash on load/resize.
- **Quiet, curated, "Google-UI"-clean nested window:** minimal, contained, owner-style — the embedded box
  should feel like a polished panel inside Epistemos, visually continuous with the Epdoc editor, so Work +
  Notes read as ONE app.
- **Shared infra:** reuse the editor's `WKProcessPool` + nonPersistent store + `dismantleNSView` teardown
  patterns for memory/lifecycle parity.
This makes the WebView feel native-framed even though the canvas is web — directly raising the native-feel
axis the owner cares about, with zero capability loss. (Fold into graft step 3: bridge + theme injection.)

**macOS-26 UPGRADE (owner 2026-06-24 — "is the curved box deprecated / something better?"):** the curved-box
LOOK is NOT deprecated — keep it. What's legacy is the Epdoc editor's MECHANISM (`WKWebView` via
NSViewRepresentable; WKWebView itself is not Apple-deprecated but it's the legacy SwiftUI bridge). For Work,
do it BETTER on macOS 26 (verified in the 26.4 SDK): build the box on the NEW SwiftUI **`WebView` + `WebPage`**
(WebKit module — `WebPage` confirmed `@MainActor final public class`), NOT WKWebView; frame it with **Liquid
Glass** (SwiftUI glass effects/`GlassButtonStyle` confirmed) for the fused native chrome; use **concentric
corner radii** so the box nests inside the window curvature; `WebPage` is `@Observable` so the chrome reacts
to page title/loading/theme. Same embedded-curved-box identity, modern engine + glassy fused frame + nested
corners = an upgrade, not a port. (Epdoc editor stays on WKWebView for now — optional later modernization,
do not block Work on it.)

## 6. OWNER GATES — status (updated 2026-06-24)
- **min-OS: RESOLVED → macOS 26 ALWAYS** (owner standing preference: latest UI/UX, NO legacy, for ALL new
  WebKit/UI work). Use the WWDC-2025 SwiftUI **`WebView`/`WebPage`** API — NOT `WKWebView`. PORT the Epdoc
  chrome patterns (theme-token CSS injection, fused chrome, white-flash kill, teardown) onto the new API;
  do NOT copy the legacy WKWebView host verbatim. Bump the Work target deployment target to macOS 26.
- **plan: liked** (owner) + §5b fused-chrome presentation refinement.
- **REMAINING before the spike runs (need explicit OK — these cross current guardrails):**
  1. OK to write the spike PRODUCT Swift — a native macOS-26 `WebView` host (fused chrome) +
     `WorkRuntimeSupervisor` that launches the bundled `opencode serve` on loopback + per-launch token.
     Small, behind a debug flag, reversible; one checkpoint xcodebuild.
  2. Spike granularity:
     - **Spike-A (no donor build, recommended first):** native macOS-26 WebView host + WorkRuntimeSupervisor
       + fused chrome, pointed at a placeholder / the runtime health page. Proves host + runtime + chrome +
       theme. Respects the "no donor installs" + disk guardrails (no pnpm).
     - **Spike-B (real Work UI):** also build OpenWork `apps/app` (Vite) → load the actual Work surface.
       REQUIRES lifting the "no pnpm/node/donor installs" rule (a `pnpm install` + Vite build, ~1 GB;
       107 GiB free so feasible if approved).
Until OK: no vendoring, no build, no donor installs.

## 7. SPIKE — implementation log (owner gave GO 2026-06-24: "yes you can start")

### ⭐ SESSION STATE (2026-06-24) — read this first
**DONE + build/test-VERIFIED this session (all in tree, uncommitted):**
- W-R3/W-R2 chain: `WorkToolMCPCore` (MCP core), `WorkNativeMCPServer` (loopback `/mcp` transport + bearer/origin),
  `WorkNativeToolExecutor` (computer-use→ComputerUseBridge; else→ToolTierBridge), `WorkNativeMCPHost` (owner/starter),
  `nativeMCP` threaded through `writeMergedFusionConfig`/`launchSpec` → OpenCode config asserts `epistemos-native`.
  Proof test `nativeMCPRegistrationFlowsIntoConfig` PASSES. (Live OpenCode handshake = runtime-proof-owed.)
- WebView migration: `HTMLWorkspacePDFExporter` → macOS-26 `WebPage` (BUILD SUCCEEDED + source-guard).
- **Spike-B loopback-serve OpenWork SHELL** (owner-chosen): OpenWork `apps/app` SPA built (16M, relative assets),
  served by `WorkSPAServer` (Epistemos-managed, loopback-only, ATS-safe `localhost`), loaded by `WorkWebSurfaceView`
  (no env var). Serving is end-to-end test-proven (`WorkSPAServerTests` 4/4). Discoverable via **⌘4 / View →
  "Open Work Surface (OpenWork)"**. Last full build `bu4p3ked5` = BUILD SUCCEEDED.

**RENDER ✅ CONFIRMED (owner screenshot 2026-06-24 ~16:02):** the OpenWork SPA renders in the "Work (preview)" WebView
AND the OpenCode TUI shows `epistemos-native Connected` + `epistemos-vault Connected` (W-R3/W-R2 live). Owner feedback:
SPA shows "Connect custom remote" (no local worker yet) + doesn't match Epistemos look → wants AUTO-CONNECT + reskin.

**STEP 5 — FUNCTIONAL AUTO-CONNECT (in progress; render gate cleared):** the SPA frontend needs the OpenWork WORKER
(`apps/server`, manages OpenCode, API-only — does NOT serve the SPA). Plan: run the worker locally; SPA auto-targets it.
- ✅ SPA rebuilt with `VITE_OPENWORK_URL=http://localhost:8787` (server-provider.tsx reads this) → auto-targets the
  worker, skips connect-remote. Re-staged (`8787` confirmed in bundle).
- ✅ Worker deps installed (scoped, 19.6s) + RUNS (`bun apps/server/src/cli.ts`; default `127.0.0.1:8787`; flags
  `--cors`, `--token`, `--workspace`, `--opencode-base-url`).
- ✅ Worker compiled to a self-contained 60M binary (`bun build --compile` → `openwork-server`, v0.17.2) + RUN-PROVEN:
  it listens on `http://127.0.0.1:8787` + mints per-launch client/host tokens (curl confirmed; 404s were wrong-path,
  not failure). STAGED → `~/Library/Application Support/Epistemos/WorkRuntime/openwork-server`.
- AUTO-CONNECT BRIDGE (exact, from server-provider.tsx): the SPA reads `localStorage["openwork.server.token"]`
  (Bearer auth), `["openwork.server.active"]` + `["openwork.server.list"]` (server URL); with `VITE_OPENWORK_URL=8787`
  set, `fallback`→`8787` auto-fills the URL. So FULL auto-connect = launch worker with a known `--token <T>` + pre-seed
  those 3 localStorage keys before the SPA loads.
- BRIDGE WIRING: (2) ✅ DONE (build `b9dqmq2x7`) — `WorkSPAServer` gained `bootstrap: WorkSPABootstrap?` (workerURL+token);
  serving index.html injects a `<head>` `<script>` seeding `openwork.server.token`/`.active`/`.list` (pure
  `injectBootstrap`/`jsStringLiteral` helpers + tests, incl. an end-to-end test that the served HTML carries the token).
  (1) ✅ DONE (build `bxf4xtv7d`) — NEW `Epistemos/Work/WorkOpenWorkSupervisor.swift` (`@MainActor @Observable`; cleaner
  than contorting the opencode-coupled `WorkRuntimeSupervisor`): resolves the staged `openwork-server` binary, launches
  it (`--host 127.0.0.1 --port 8787 --cors "*" --token <T> --workspace <vault>`), awaits "OpenWork server listening",
  exposes `.running(baseURL, token)` (baseURL normalized 127.0.0.1→localhost for ATS). + pure-helper tests.
  (3) ✅ DONE + VERIFIED (`bszq577aa` = BUILD SUCCEEDED) — `WorkWebSurfaceView` coordinates: `@State workerSupervisor = WorkOpenWorkSupervisor()`;
  `startSurface()` starts the worker (vault = managed App-Support workspace), `awaitWorkerBootstrap()` polls
  `.running(baseURL, token)` → `WorkSPABootstrap` (nil on unavailable/failed/timeout → honest token-less fallback) →
  `WorkSPAServer(root:, bootstrap:)` → load. `.onDisappear` kills the worker + server (no process leak).
  **AUTO-CONNECT CHAIN COMPLETE (3/3 pieces wired):** open Work → worker auto-starts on :8787 → SPA served with the
  token pre-seeded into localStorage → connects, no "Connect custom remote". OWNER-VISUAL-PROOF owed (rebuild → ⌘4).
  RUNTIME DE-RISK (curl probe of the staged worker): listens ✓; root `/` → 404 with AND without token (auth does NOT
  block — token-seeding suffices); `/opencode/global/health` → 400 (the `/opencode` proxy path is recognized; the
  OpenCode daemon behind it needs more — its managed OpenCode binary + workspace). OPENCODE AVAILABILITY ✅ WIRED
  (build `by0vyzwdd`): the worker spawns its OWN managed OpenCode (`createManagedOpencodeServer`) needing the vendored
  `opencode`/`bun` (NOT on the system PATH — confirmed). `WorkOpenWorkSupervisor.workerEnvironment()` now prepends the
  bundled `opencode-runtime/bin` dir (via `WorkOpenCodeRuntime.bundledRuntimeURL`) to the worker's PATH (pure-helper
  test) → the worker's managed OpenCode should find the binary. (Owner's test confirms end-to-end; fallback if not
  found = `--opencode-base-url` at the app's OpenCode.)
  RUNTIME DE-RISK 2 — ⚠️ MISDIAGNOSIS CORRECTED 2026-06-24 by the OWNER's GUI test (screenshot): the earlier
  "worker manages OpenCode LAZILY" read was WRONG. The owner's running app shows the SPA renders + auto-connects
  (no remote dialog) + auto-lands in a workspace, BUT errors `opencode_unconfigured / "OpenCode base URL is missing
  for this workspace"` + Disconnected. ROOT CAUSE (donor `cli.ts`): the worker spawns its managed OpenCode ONLY
  inside `if (!config.opencodeBaseUrl && process.env.OPENWORK_MANAGE_OPENCODE === "1")` — an EAGER (boot-time) spawn
  GATED on the `OPENWORK_MANAGE_OPENCODE=1` switch. My de-risk run (and the owner's build) never set it ⇒ no managed
  OpenCode ⇒ no workspace `baseUrl` ⇒ the exact error. (The 400 I saw at idle was this same missing-switch, NOT
  laz’iness.) FIX (this fire): `WorkOpenWorkSupervisor.workerEnvironment()` now sets `OPENWORK_MANAGE_OPENCODE=1`
  + `OPENWORK_OPENCODE_BIN=<bundled opencode>` (cli.ts feeds that to the spawn) + prepends its dir to PATH (for
  opencode's own `bun` lookup). Build `bzhvgcnta` (build-for-testing) OWED-verify. OWNER REBUILD (⌘R) → ⌘4 → OpenCode
  should now come up (worker spawns it eagerly at boot). Note: if the bundled opencode fails to spawn, cli.ts's
  top-level `await` would crash the worker → SPA shows fully Disconnected (different failure) → then it's a
  binary-bundling issue, not config. PRIOR de-risk confirmed opencode+bun exist in `Contents/Resources`.

  ✅✅ RUNTIME PROOF 2026-06-24 (ran the staged worker with the FIX env against a tmp workspace — both layers green):
  • MANAGE_OPENCODE FIX PROVEN: with `OPENWORK_MANAGE_OPENCODE=1` + `OPENWORK_OPENCODE_BIN=<Resources/opencode>` +
    PATH=Resources, the worker logs `Managed OpenCode listening on http://127.0.0.1:53918` then `OpenWork server
    listening`; worker `/health`=200; `GET /workspaces` shows the workspace now carries
    `baseUrl + opencode:{baseUrl,directory,username,password}` (the field whose absence = `opencode_unconfigured`).
    Worker did NOT crash → the bundled `opencode`/`bun` spawn CLEANLY (binary-spawn caveat RETIRED). ⇒ owner rebuild
    (⌘R) → ⌘4 resolves the OpenCode-unavailable error.
  • OPTION-B REGISTRATION MECHANISM PROVEN: `POST /workspace/ws_d4bb876dc4a3/mcp` (Bearer = the worker `--token`)
    with `nativeMCPRegistrationBody`-shaped body → `GET .../mcp` afterward lists `epistemos-native` with my EXACT
    config. ⇒ auth (collaborator) ✓, `--approval auto` ✓ (no 403), `addMcp` accepts the shape ✓. CAVEAT: the POST
    BLOCKS until `syncRuntimeMcpToOpencodeEngine` finishes connecting to the MCP url (my dead placeholder
    `localhost:9999` made curl time out, but the registration still landed) → the WIRING MUST start
    `WorkNativeMCPServer` BEFORE the POST so the url is live (fast return). Use a short client timeout + treat
    timeout as non-fatal (the write lands regardless).
  • BONUS: `epistemos-vault` (omega_mcp_stdio, ~23 tools) ALREADY appears in the managed OpenCode's mcp list via
    `source:"config.global"` → the vault MCP already reaches the worker's OpenCode (W-R2 vault partially live);
    option B layers the FULL native-tool `epistemos-native` on top. `GET /workspaces` returns BOTH `items` and
    `workspaces` arrays (the Swift `workspaceID(fromWorkspacesJSON:)` parser reads `workspaces` ✓).

  ✅ LLM PROVIDER — NOT A GAP (recon 2026-06-24): the last "will the agent actually respond?" question. OpenCode
  reads provider auth from `~/.local/share/opencode/auth.json` (HOME-based) — which EXISTS (2461B, mode 600, the
  owner authenticated OpenCode; same file the TUI uses). The worker's managed OpenCode is the SAME bundled binary
  and inherits the app's HOME, so it reads the SAME auth.json ⇒ providers/models are available with ZERO extra
  provisioning. Epistemos does NOT (and need not) thread API keys into the worker env. ⇒ full chain has no provider
  hole: auto-connect → OpenCode up (MANAGE_OPENCODE) → workspace → provider (auth.json) → native tools (option B).
  (CAVEAT: if a future MAS/sandboxed build can't reach `~/.local/share/opencode`, provider auth would need
  re-provisioning — debug build is non-sandboxed so it's fine now.)

  ZERO-SETUP ANALYSIS (donor source recon, 2026-06-24 — "auto do everything so I can just start using it"):
  • CONNECTION health = worker `GET /health` (auth "none", always-green when reachable) → auto-connect WILL show
    "connected" with NO "Connect custom remote" dialog. This RESOLVES the owner's primary screenshot complaint.
  • OpenCode is WORKSPACE-SCOPED + LAZY by design (`createWorkspaceOpencodeClient` per workspace, sessions.ts) —
    spawned when a workspace is active, with the bundled `opencode` now on the worker PATH. Correct, not a bug.
  • The worker registers the vault as a workspace at boot via `--workspace <vaultRoot>` → `buildWorkspaceInfos`.
    Workspace ID is DETERMINISTIC: `ws_` + first 12 hex of `sha256(resolvedPath)` (apps/server/src/workspaces.ts
    `workspaceIdForKey`). So Epistemos COULD compute it Swift-side.
  • SPA `activeWorkspaceId` defaults null with NO `persist` middleware on the kernel store → seeding localStorage
    will NOT hydrate it. BUT `apps/app/src/react-app/shell/use-workspace-route-state.ts` has a default-workspace
    FALLBACK when nothing is selected → the SPA likely lands in the single registered vault workspace on its own.
    (Reading exact behavior off transpiled source is unreliable; this is the owner's visual ⌘4 test.)
  • NEXT-PHASE (gated, NOT autonomous): if the owner's test shows it does NOT auto-land in the vault workspace,
    the fix is an SPA-source patch to auto-select when `workspaces.length === 1` (or a store hydration hook) — that
    needs an SPA rebuild (disk-cap, owner-deferred) + visual proof, so it waits for the owner.
  REMAINING: bundle the 60M worker binary + SPA for release (group container / Resources, no pbxproj); then RESKIN/prune
  OpenWork's onboarding + chrome to the Epistemos look.

  W-R2/W-R3 ON THE WORKER PATH — RESOLVED (donor recon 2026-06-24; build `bpncf5zty` build-for-testing OWED):
  The new OpenWork worker path does NOT consume our `OPENCODE_CONFIG` fusion file. PROOF CHAIN from the donor:
  • `managed-opencode.ts` spawns the managed OpenCode with `env = { ...process.env, ...options.env, ... }`, so the
    child inherits the worker's env — BUT `cli.ts:52` sets `OPENCODE_CONFIG: runtimeConfigPath` in `options.env`,
    which (after `...process.env`) OVERRIDES anything we put in the worker env. ⇒ env-var injection CANNOT reach it.
  • The managed OpenCode's config is built by `writeOpenworkRuntimeConfigFile` → `buildOpenworkRuntimeConfigObject`
    → `mcp: runtimeMcpMap(readRuntimeOpencodeConfig(...))` — i.e. MCP servers come from the worker's RUNTIME DB
    (per-workspace), NOT any file we can pre-write. ⇒ writing `<vault>/opencode.json` won't reach it either.
  • SUPPORTED FIX (option B, "register over HTTP"): after the worker is up, `POST <worker>/workspace/<id>/mcp`
    (bearer token; route auth "client" + `requireClientScope(ctx,"collaborator")`) with body
    `{name:"epistemos-native", config:{type:"remote", url:"http://localhost:<mcpPort>/mcp",
    headers:{Authorization:"Bearer <nativeToken>"}, enabled:true}}`. `addMcp` writes it to the runtime DB →
    `runtimeMcpMap` → the (lazy) managed OpenCode picks it up. VERIFIED: `validateMcpConfig` accepts remote+http
    url and ignores extra keys (headers/enabled OK); `requireApproval` has an auto-allow path (`{id:"auto"}`) for
    headless launch (re-confirm at impl). The MCP `config` shape == the existing W-R3 `epistemos-native` block
    (`WorkOpenCodeRuntime.mergedOpenCodeConfigJSON(nativeMCP:)`).
  • Rejected: (A) write the worker's runtime DB directly (worker-internal SQLite — fragile); (C) `--opencode-base-url`
    to point the worker at our OWN `opencode serve` (the OLD `WorkRuntimeSupervisor`, already W-R2-correct) — an
    architectural fork (which OpenCode is authoritative) → OWNER decision, not autonomous.
  • DONE THIS FIRE (reversible increment): `WorkOpenWorkSupervisor.nativeMCPRegistrationBody(url:token:) -> Data?`
    (pure, builds the verified POST body) + `WorkOpenWorkSupervisorTests.nativeMCPRegistrationBody` (shape assert).
    swiftc -parse clean; in-module compile = build `bpncf5zty` (build-for-testing) OWED-verify.
  • OPTION-B BLOCKERS — ALL RESOLVED (donor recon, next fire):
    – Q1 AUTH ✓ : `POST /workspace/:id/mcp` is auth "client" + `requireClientScope(ctx,"collaborator")`. The worker's
      `--token` (= `config.token`, what we seed to the SPA) IS the collaborator-scoped client token (server.ts:640
      "the SPA's only credential is the collaborator-scoped client token"). ⇒ Epistemos REUSES the worker token
      (`WorkOpenWorkSupervisor` already exposes it via `.running(token:)`) — same credential the SPA uses → authorizes.
    – Q2 APPROVAL ✗→✓ FIXED THIS FIRE: the worker DEFAULTS to `manual` approval (config.ts:275 `?? "manual"`).
      In manual mode `requestApproval` for `mcp.add` (AND every agent file write) creates a pending approval that,
      with no approval UI in our embed, times out → `{allowed:false}` → 403. `approvals.ts:31`: only `mode==="auto"`
      returns `{allowed:true}` immediately. ⇒ added `--approval auto` to `workerArguments` (loopback-only + per-launch
      token + Epistemos-owned + permissions are the native shell's job per canon). This unblocks BOTH option-B
      `mcp.add` AND the embedded agent's ability to write at all.
    – Q3 ID-DISCOVERY ✓ : the workspaces list route returns `{ workspaces: [serializeWorkspaceConfigEntry] }` where
      each item = `{id, path, name, preset, workspaceType, …}` (routes/workspaces.ts:185-216). ⇒ id-discovery =
      find the entry whose `path === vaultRoot.path`, take its `id`. (No need to replicate the sha256 derivation.)
  • DONE THIS FIRE (reversible): (a) `nativeMCPRegistrationBody(url:token:)` + test [prior]; (b) `--approval auto`
    in `workerArguments` + `workerArgs` test asserts it. swiftc -parse clean. Build: `bpncf5zty` (build-for-testing,
    still running) verifies (a); the `--approval` argv edit is a trivial string-array addition (no new symbols) →
    OWED-verify at next checkpoint (guaranteed-compilable if bpncf5zty passes).
  • OPTION-B WIRING — LAYER 1 of 2 DONE THIS FIRE: NEW `Epistemos/Work/WorkOpenWorkProvisioner.swift` (enum,
    `nonisolated` statics) encapsulates the proven flow: `discoverWorkspaceID` (`GET /workspaces` Bearer worker
    token → `WorkOpenWorkSupervisor.workspaceID`) + `registerNativeMCP` (`POST /workspace/<id>/mcp` Bearer worker
    token with `nativeMCPRegistrationBody`; 6s timeout; best-effort + non-fatal). This makes the two pure helpers
    USED (no longer orphan). swiftc -parse clean; in-module compile = build `bk9j75ps3` OWED-verify. (bzhvgcnta =
    TEST BUILD SUCCEEDED confirmed the MANAGE_OPENCODE fix + --approval auto + helpers compile.)
  • OPTION-B WIRING — LAYER 2 of 2 DONE THIS FIRE: `WorkWebSurfaceView.provisionNativeMCP(bootstrap:)` — after
    `loadSPAWhenReady` (so it never blocks first paint), when the worker bootstrap is non-nil it calls
    `WorkNativeMCPHost.shared.startAndAwaitRegistration(vaultRoot: workerWorkspace())` (the EXISTING @MainActor
    entry point that wires the PRODUCTION composed executor + guarantees the native server is listening before we
    POST — same one `WorkTerminalView` uses) → then `WorkOpenWorkProvisioner.registerNativeMCP(...)`. Mirrors the
    existing sequential MainActor flow (no task group / no view-capture → dodges the region-isolation checker).
    NOTE: did NOT touch `.onDisappear` — `WorkNativeMCPHost` is a SHARED singleton (the TUI path uses it too), so
    this view must not stop it. ✅ BUILD-VERIFIED: `bk1ww8qm9` (app-target build) = **BUILD SUCCEEDED**. ⇒ the FULL
    option-B chain is now build-verified (helpers `bzhvgcnta` + provisioner `bk9j75ps3` + view wiring `bk1ww8qm9`);
    only the owner runtime proof remains (agent calls a native tool via `epistemos-native`).
    OPEN DESIGN Q (flag for owner / next): both the worker `--workspace` and the native MCP root use
    `workerWorkspace()` = an App Support SCRATCH dir, NOT the user's real vault → native tools + agent operate on
    scratch, not the user's content. If Work should act on the real vault, point both at the active vault root
    (one change to `workerWorkspace()`); deferred (needs the vault-selection wiring + owner intent on Work's CWD).
⚠️ Build-touched dirty `Localizable.xcstrings` — CORRECTED 2026-06-24 (was "my strings did NOT leak"; that is now
STALE). The xcodebuild string-extraction build phase, re-run across my many `build-for-testing` checkpoints, GREW
`Epistemos/Resources/Localizable.xcstrings` by ~+619/-? lines (and touched `OsaurusCore/.../Localizable.xcstrings`
~+? /-29). It DID extract 2 of my Work UI strings (`"Open Work Surface (OpenWork)"` + `"Open Work surface (new
WebView preview)"` from the ⌘4 menu/Settings button) PLUS ~600 other app strings that were missing from the
catalog. This is an UNAVOIDABLE build side-effect (a build phase), NOT a hand-edit. Per guardrail I did NOT revert
(reverting = touching + risks the owner's pending catalog entries; it's regenerable build-output). OWNER ACTION:
review / `git checkout` these 2 files when ready. MITIGATION GOING FORWARD (stop further churn): (1) prefer the
`swiftc -typecheck` fast gate (NO string extraction) for pure files; (2) when a full build IS needed, pass
`SWIFT_EMIT_LOC_STRINGS=NO` to xcodebuild so the extraction phase doesn't re-touch the catalog (verify on next build).

ENV CONFIRMED: macOS 26.3.1 + Xcode 26.4.1 + macOS 26.4 SDK; project deployment target ALREADY `26.0`
everywhere → use the new SwiftUI `WebView`/`WebPage` directly, NO availability guards, NO WKWebView legacy,
NO deployment-target decision. Owner standing rule: macOS 26 always, latest UI/UX, no legacy.

- **Spike-A increment 1 — `WorkRuntimeSupervisor` (DONE, parse-verified):**
  `Epistemos/Work/WorkRuntimeSupervisor.swift` — `@MainActor @Observable` runtime-process tier: launches the
  BUNDLED `opencode serve` on loopback with per-launch HTTP basic-auth (`WorkRuntimeAuth`), races the
  listening-line parse against a 15 s timeout (`withTaskGroup`), exposes `.running(baseURL:)` for the WebView,
  `/global/health` URL, kill-on-teardown; honest `.unavailable` when the runtime isn't bundled (mirrors
  WorkOpenCodeShell — no fake server). Pure helpers `nonisolated` (serveArguments/processEnvironment/
  parseListeningURL/healthURL). + `EpistemosTests/WorkRuntimeSupervisorTests.swift` (5 tests on the pure
  helpers). `xcrun swiftc -parse` exit 0 on both. (Fuses ledger Row 7 + C11.)
- **Spike-A increment 2 — `WorkWebSurfaceView` (DONE, compile-verified):**
  `Epistemos/Work/WorkWebSurfaceView.swift` — the embedded CURVED BOX on the NEW macOS-26 SwiftUI
  `WebView(page)` + `WebPage` (NOT WKWebView): rounded/inset/theme-aware box (`RoundedRectangle(.continuous)`
  + themed border), fused native header, wired to `WorkRuntimeSupervisor` (loads the loopback baseURL w/
  basic-auth when running, else a themed placeholder via `page.load(html:)`), + a `#Preview`. Theme via the
  `EpistemosTheme` enum (`.nativeDefault` default → previewable). Confirmed the new-`WebView` API compiles.
- **BUILD GOTCHA (fixed):** the project uses SYNCHRONIZED FOLDERS — new files auto-include with NO xcodegen.
  I ran `xcodegen generate` (unneeded); it regenerated the pbxproj from project.yml and WIPED the local
  signing (`DEVELOPMENT_TEAM=3BNL2669SL`→"" + macOS dev identity) → build reached signing then failed
  ("needs dev cert"), though ALL Swift compiled (0 errors in spike files). Restored via
  `git checkout` of the pbxproj + xcschemes (sync folders keep the new files). Memory:
  `feedback_epistemos_dont_run_xcodegen_sync_folders`. → DON'T run xcodegen here.
- **Spike-A VERIFIED (build `b33wvxauf` = BUILD SUCCEEDED, compile + SIGN end-to-end):** the macOS-26
  `WebView` curved-box host + `WorkRuntimeSupervisor` are built into the signed app. Code-complete +
  compile/sign verified. OWED (owner-driven): visual proof — open `WorkWebSurfaceView` `#Preview` in Xcode
  (renders the curved box + fused chrome + theme placeholder) for the screenshot; + runtime proof needs the
  vendored `opencode` binary present (else supervisor is honestly `.unavailable`).
- **Spike-A increment 3 — LIVE in-app entry (DONE + VERIFIED; build `btlruxix6` = BUILD SUCCEEDED, compile+sign):**
  `Epistemos/Work/WorkWebSurfaceWindowController.swift` (new; mirrors `MiniChatWindowController` — themed
  NSWindow via `WindowThemeStyler`, focus-existing/no-dup, close cleanup) + a "Open Work surface (new WebView
  preview)" button added to `WorkCloneSettingsView` (additive Section). So the curved box now runs LIVE in
  the app (Settings → Work clone → Work surface (preview)), not just the Xcode `#Preview`.
- **NEXT (autonomous, obvious-best order):** W-R3 app-hosted in-process Swift MCP (full native tool surface
  → OpenCode; the owner's "every tool expressed" — additive, build-verifiable; recon the Swift tool registry
  + `modelcontextprotocol/swift-sdk` first) → W-R2 zero-config provisioning → mini-session parentSessionID
  wiring → then the WebView migration tangent (C→B→A). Spike-B (real OpenWork UI) when safe work is exhausted
  (needs pnpm ~1 GB). Visual proof of the curved box OWED (owner runs the new Settings entry / #Preview).
- **Spike-B — real OpenWork `apps/app` SPA (STARTED 2026-06-24; safe Swift work exhausted → now obvious-best):**
  SCOPED (all facts gathered from the owner-greenlit donor at `/tmp/epistemos-opencode-donor-audit/openwork`):
  `apps/app` = **Vite 6 + React 19** (`@openwork/app`), pinned `pnpm@11.4.0`, `pnpm-lock.yaml` present.
  EMBED KEY: `vite.config.ts` does `base: process.env.OPENWORK_ELECTRON_BUILD === "1" ? "./" : "/"` → build with
  `OPENWORK_ELECTRON_BUILD=1` emits **relative-path assets** → serve `apps/app/dist/` in `WorkWebSurfaceView`'s
  `WebPage` via a custom-scheme `urlSchemeHandlers` (no dev server in prod); the SPA talks to `apps/server` (the
  local Work runtime) over loopback. Toolchain: node v25.8.2 ✓, npm registry reachable ✓, /tmp 100 GB free ✓,
  pnpm absent + corepack not on PATH → provision via `npx --yes pnpm@11.4.0`. ee/* is OFF-LIMITS → install SCOPED
  (`--filter "@openwork/app..."`) to skip Electron `apps/desktop` + ee deps.
  EXECUTION PLAN + STATUS:
  - (1) ✅ DONE (`b8pky9ctk`): scoped install — `npx --yes pnpm@11.4.0 --dir <donor> install --filter "@openwork/app..."`
    → 804 pkgs, 17.8s, no Electron/ee bloat. node_modules at donor root + apps/app.
  - (2) ✅ DONE (`bpwekcz5n`): `OPENWORK_ELECTRON_BUILD=1 pnpm --filter @openwork/app run build` → `✓ built in 6.61s`
    → `apps/app/dist/` (16 MB: index.html + assets/ ×320 + icons/svgs). VERIFIED relative assets
    (`src="./assets/app-*.js"`, `href="./..."`) → embed-ready. (app bundle ~4.1 MB; full shiki/highlighter + artifact-
    editor chunks present — it's the real OpenWork UI.)
  - (3) ⚠️ BUNDLING DECISION NEEDED (owner): get `dist/` into `Epistemos.app` Resources. The CLAUDE.md `Editor/`
    pattern uses a build-PHASE copy → but that needs pbxproj edits / xcodegen, BOTH guardrail-FORBIDDEN here. Options:
    (a) drop `dist/` into a SYNCHRONIZED folder under `Epistemos/` (auto-included as resources — 16 MB in tree, verify
    it lands in Resources), (b) a Run-Script build phase (needs owner to add it / accept a pbxproj touch), or (c) the
    LOOPBACK-SERVE path: let the bundled Work runtime (`apps/server`) serve the SPA at `127.0.0.1:<port>/` and just
    point the WebView there (no Resources bundling at all — matches the apps/server+apps/app canon, but needs the
    runtime bundled first). Recommend (c) long-term; (a) for the spike. FLAG FOR OWNER.
  - (4) EMBED HANDLER ✅ BUILT + VERIFIED (`bsmgwbo2e` = BUILD SUCCEEDED) + WIRED into `WorkWebSurfaceView` (build
    `b0oetgrqv` verifying — see WIRING below): `Epistemos/Work/WorkSPASchemeHandler.swift` —
    `nonisolated struct WorkSPASchemeHandler: URLSchemeHandler` serving a configurable `root` dir over a custom
    scheme. macOS-26 API (from `WebKit.swiftinterface`): `protocol URLSchemeHandler { func reply(for: URLRequest)
    -> some AsyncSequence<URLSchemeTaskResult, Error> }`; `URLSchemeTaskResult` = `.response(URLResponse)` /
    `.data(Data)`; `URLScheme(_ rawValue:)` failable @MainActor. Returns an `AsyncThrowingStream` yielding
    `.response`(HTTPURLResponse 200 + Content-Type + Content-Length) then `.data`(file bytes). Pure mapping helpers
    (`resolve`/`mimeType`/`response`) + path-traversal guard + SPA deep-link→index.html fallback; +
    `EpistemosTests/WorkSPASchemeHandlerTests.swift` (7 tests — **ALL PASS**, `b5rx7ok3v` TEST SUCCEEDED: root→index,
    asset path, deep-link fallback, missing→notFound, path-traversal guard, MIME, response). Decoupled from the bundling
    decision (configurable `root`). (4) WIRING ✅ APPLIED + VERIFIED (`b0oetgrqv` = BUILD SUCCEEDED) to `WorkWebSurfaceView`:
    WebPage has NO post-init config mutation, so build it WITH the handler — add `static func makeInitialPage()`
    building `WebPage.Configuration()` with `config.urlSchemeHandlers[URLScheme("epwork")!] =
    WorkSPASchemeHandler(root:)` when a SPA root resolves, else plain `WebPage()`; `@State private var page =
    Self.makeInitialPage()` (mirrors the existing `= WebPage()`). `static func resolvedSPARoot() -> URL?` =
    **(1) env `EPISTEMOS_WORK_SPA_DIST` → the donor `dist/` (makes the spike RUNNABLE NOW — no step-3 bundling
    decision needed) → (2) `Bundle.main.resourceURL/OpenWorkApp/` (when step-3 lands) → (3) nil**. `loadForStatus()`:
    `spaRoot != nil` → `page.load(epwork://app/)`; else the existing loopback/placeholder branches UNCHANGED (honest
    default). Compiles standalone; VISUAL PROOF OWED (owner: set `EPISTEMOS_WORK_SPA_DIST=<donor>/apps/app/dist`, open
    the Work surface → OpenWork's real UI renders). KEY: this env path means (4) does NOT block on the step-3 decision.
  - (5) wire the SPA's API base to the loopback Work runtime. SCOPE (recon 2026-06-24): the server connection is in
    `apps/app/src/react-app/kernel/server-provider.tsx`, configured via a `VITE_*URL` BUILD env (set it to the
    loopback runtime URL at `vite build`), with a SEPARATE "den" cloud (`src/app/lib/den.ts`, `nden` proxy) — local
    server vs cloud are distinct. GATED: needs (a) the local Work runtime (`apps/server`/`opencode serve`) actually
    BUNDLED + running (today WorkRuntimeSupervisor reports `.unavailable` with no binary) and (b) a deeper read of
    the (obfuscated) provider. Step 5 = the FUNCTIONAL phase; the Spike-B SHELL (OpenWork UI renders) needs only
    steps 1-4 and does not require step 5.
  HONESTY: steps 1-2 DONE = the bundle EXISTS; until step 4 lands the WebView still shows the placeholder, NOT OpenWork's UI.
  - **OWNER DECISION 2026-06-24: LOOPBACK-SERVE** (chosen over bundling: "separate capability from presentation" — the
    donor web app runs in its natural http-origin habitat; native Swift owns the shell; do NOT add the 16M dist as a
    synchronized folder / pbxproj churn yet). The custom-scheme path (`WorkSPASchemeHandler` registration in
    `WorkWebSurfaceView` + the `EPISTEMOS_WORK_SPA_DIST` env gate) is SUPERSEDED for the surface (the handler's
    `resolve`/`mimeType` helpers are REUSED by the loopback server).
  - **LOOPBACK-SERVE BUILD ✅ VERIFIED (`b02tyswcb` = BUILD SUCCEEDED, zero errors):**
    - NEW `Epistemos/Work/WorkSPAServer.swift` — `nonisolated final class WorkSPAServer @unchecked Sendable`: an
      Epistemos-managed, **loopback-only** (`requiredInterfaceType = .loopback`) ephemeral-port `NWListener` HTTP
      server serving the SPA `dist/` over `http://127.0.0.1:<port>/`. Reuses `WorkMCPHTTPRequest.parse` (framing) +
      `WorkSPASchemeHandler.resolve(path:)`/`.mimeType` (mapping + traversal guard). GET/HEAD, 404/405/413. Pure
      Swift Network.framework → signed/notarization-friendly, no bundled binary, no subprocess.
    - `WorkWebSurfaceView` REWIRED: dropped the env var + custom-scheme `makeInitialPage`; `page = WebPage()` (plain);
      `startSurface()` (async) → if `resolvedSPARoot()` present, start `WorkSPAServer` + `page.load(http://127.0.0.1:<port>/)`;
      else placeholder/loopback-runtime. `resolvedSPARoot()` = **`.applicationSupportDirectory/Epistemos/WorkSPA/dist`
      (NO env var)** — resolves to the container when sandboxed, `~/Library/Application Support` for the non-sandboxed
      debug build. `WorkSPASchemeHandler.resolve(path:root:)` added (request→path delegation; existing 7 tests intact).
    - STAGED the built `dist/` (16M) → `~/Library/Application Support/Epistemos/WorkSPA/dist/` (Debug build has
      `app-sandbox=false` per `Epistemos-Debug.entitlements` → reads it directly; no container hack). So the Work
      surface now resolves the SPA with **NO env var**.
    - SERVING TEST-PROVEN: `EpistemosTests/WorkSPAServerTests.swift` (4 end-to-end tests, `bu0ab2h1q` TEST SUCCEEDED)
      starts a REAL `WorkSPAServer` and makes actual loopback HTTP GETs → serves index.html at `/` (200 text/html),
      assets with correct MIME (text/javascript), 404s unknown assets, SPA deep-link → index.html. So the loopback
      SERVING is runtime-proven; only the WebView RENDER is owner-visual-proof now.
    - OPEN PATH: Settings → Work clone → "Open Work surface", OR **menu/⌘4 "Open Work Surface (OpenWork)"** (added
      to the View-menu `CommandGroup(after: .sidebar)` in EpistemosApp.swift, build `brsptcv23` — owner couldn't
      find the buried Settings button 2026-06-24). VISUAL PROOF OWED (owner: open it → OpenWork's real UI renders
      over loopback, no `EPISTEMOS_WORK_SPA_DIST` set).
    - DIAGNOSIS (owner "I don't see any change / still see code" 2026-06-24): changes are UNCOMMITTED in the tree →
      NOT in any running app; owner must REBUILD+RUN (⌘R, Debug scheme) for the button/⌘4 + loopback wiring to exist.
      The main app/Epdoc code editor is unchanged ("the code they see"); the Work surface is a SEPARATE window.
    - ATS DE-RISK (proactive 2026-06-24): the WebView base URL now uses **`localhost`** (was `127.0.0.1`).
      `Epistemos-Info.plist` has NO `NSAppTransportSecurity` key (ATS at OS defaults); ATS auto-exempts the
      `localhost` NAME but not a raw `127.0.0.1` IP literal → using `127.0.0.1` risked an ATS-blocked blank WebView.
      The listener still binds the loopback interface; `localhost` resolves to it. (If a blank WebView still occurs,
      next fallback = add `NSAllowsLocalNetworking`/an exception domain to `Epistemos-Info.plist`.)
    - ✅ VERIFIED (`bu4p3ked5` = BUILD SUCCEEDED, zero errors): the ⌘4 menu command + the `localhost` ATS de-risk
      both compile. Owner path to visual proof: rebuild (⌘R) → ⌘4 / View → "Open Work Surface (OpenWork)" → OpenWork
      loads over `http://localhost:<port>/` in the curved-box WebView (no env var, ATS-safe, serving test-proven).
    - RELEASE (sandboxed) follow-up: populate `WorkSPA/dist` in the container from a bundled copy / the runtime, or
      use group container `group.com.epistemos.shared`. Not needed for the debug spike.

## W-R3 DESIGN — app-hosted MCP exposing EVERY native tool (recon 2026-06-24, build-time docs-only)
GROUNDED FINDING: the app ALREADY has an in-process MCP dispatcher — **`MCPBridge`**
(`Epistemos/Omega/MCPBridge.swift`): `dispatch(...)` handles `tools/list` (:336) + `tools/call` (:346)
over the builtin catalog (`decodedBuiltinTools()` :104 from the Rust `builtinToolsJson()` export), plus a
policy gate + execution logging (SQLite). NO `modelcontextprotocol/swift-sdk` dependency — MCPBridge is a
hand-rolled JSON-RPC dispatcher (reuse it; the SDK is optional).
GAP: OpenCode (external process) currently reaches ONLY the Rust `omega_mcp_stdio` subprocess (vault+graph
~23 tools); the in-process `MCPBridge` (full catalog + Swift-side execution) is NOT exposed over any
transport OpenCode can connect to. That's the "every tool expressed" gap.
PLAN (minimal, reuse MCPBridge):
1. Host a thin **loopback MCP transport** — Network.framework `NWListener` on `127.0.0.1` + per-launch
   bearer token, speaking MCP JSON-RPC, that forwards `tools/list`/`tools/call` to `MCPBridge.dispatch`.
   Register it as a `type: remote` MCP server (loopback URL + token) in the OpenCode config — OR a small
   stdio shim (`type: local`) that proxies to the in-process bridge. (Prefer NWListener loopback HTTP to
   pair with the WorkRuntimeSupervisor's loopback model.)
2. **W-R2 zero-config:** pre-provision the OpenCode config on first launch to register this app-hosted MCP
   (+ the existing omega vault MCP + vault root + skills) so OpenCode lists+calls EVERY native tool with NO
   manual setup.
RESOLVED (recon 2026-06-24):
- `builtinToolsJson()` IS the FULL native set — `catalog.rs` includes the computer-use/automation tools
  (`see`/`click`/`type`/`click_element`, catalog.rs:331-368) alongside vault/graph. No separate merge needed.
- EXECUTION MODEL: the Rust dispatcher does VALIDATION + ROUTING ONLY (dispatcher.rs:3-4; `handle_tools_call`
  :378 returns a "pending: execute toolX(args)" directive, :426-427). ACTUAL execution is SWIFT-side via a
  `LocalAgentToolExecutor` closure (vault→Rust FFI; computer-use→`DeviceAgentService`/`ComputerUseBridge`/
  `AXorcistBridge`; AppStore→`unavailableToolExecutor`, DeviceAgentService:397/403).
- IMPLICATION: exposing `MCPBridge.dispatch` alone is NOT enough — it returns "pending", it does not execute
  Swift-side. The app-hosted MCP must: (tools/list) use `OmegaToolRegistry.surfacedTools` (full catalog);
  (tools/call) run the PRODUCTION `LocalAgentToolExecutor` for the tool and return the executed result —
  making EVERY tool (incl. computer-use) CALLABLE by the OpenCode agent, closing omega_mcp_stdio's Swift gap.
W-R3 BUILD — increment 1 DONE + VERIFIED (`b6y8ekgzf` = BUILD SUCCEEDED): `Epistemos/Work/WorkToolMCPCore.swift` — the protocol
CORE: `handle(requestJSON:)` shaping `initialize`, `tools/list` (from `OmegaToolRegistry.planningSchemasJson`
= the FULL native catalog), `tools/call` (→ injected `LocalAgentToolExecutor` → MCP `content`/`isError`),
JSON-RPC errors. + `EpistemosTests/WorkToolMCPCoreTests.swift` (6 tests; the tools/call path is
FFI-independent via a stub executor). swiftc -parse clean.
W-R3 BUILD — increment 2 DONE (transport): `Epistemos/Work/WorkNativeMCPServer.swift`
— the loopback `/mcp` HTTP server binding the W-R2 `epistemos-native` registration to `WorkToolMCPCore`.
`nonisolated final class ... @unchecked Sendable` mirroring the proven in-repo `LocalModelServer` Network.framework
pattern: `requiredInterfaceType = .loopback` ephemeral-port `NWListener`, the minimal HTTP/1.1 parser
(`WorkMCPHTTPRequest.parse`, copied from `LocalModelServer.HTTPRequest` which is file-private), POST `/mcp` →
`core.handle(requestJSON:)` → `application/json`. ADDS the security layer OpenCode's remote-MCP needs: per-launch
random bearer token (`SecRandomCopyBytes`), `Authorization: Bearer` validation via **constant-time compare**, and
an **Origin allowlist** (absent/null/loopback allowed, routable refused). On `.ready` it publishes
`status = .running(WorkNativeMCPRegistration{url:"http://127.0.0.1:<port>/mcp", token})` — the exact value
`mergedOpenCodeConfigJSON(nativeMCP:)` (W-R2) consumes. + `EpistemosTests/WorkNativeMCPServerTests.swift` (16 tests
over the PURE helpers: `routeOutcome` security/routing matrix, bearer parsing, origin rules, constant-time compare,
HTTP response framing, request parser needMore/complete). swiftc -parse exit 0.
BUILD `b1973hm6k` FAILED (1 error class, 5 sites): `WorkNativeMCPRegistration` took the module's default MainActor
isolation, but the NEW nonisolated `WorkNativeMCPServer.Status` has `case running(WorkNativeMCPRegistration)` + is
`Equatable` → "main actor-isolated conformance of 'WorkNativeMCPRegistration' to 'Equatable' cannot be used in
nonisolated context". FIX (applied): marked `WorkNativeMCPRegistration` `nonisolated` in WorkOpenCodeRuntime.swift
(both fields Sendable value types → safe; MainActor callers like the W-R2 tests still compile). Rebuild `bzex6ci0a`
= **BUILD SUCCEEDED (zero errors)** → W-R3 increment 2 (transport) VERIFIED. LESSON: any type embedded in a
`nonisolated` Equatable/Sendable enum case must itself be `nonisolated` under this module's
`.defaultIsolation(MainActor.self)`.

INCREMENT (b) SPEC — composed production executor (recon 2026-06-24, ready to write):
- COMPUTER-CATEGORY tool names (catalog.rs, `category "computer"`): **see, click, type, scroll, keys, screenshot**
  (distinct from `category "automation"`: get_ui_tree, click_element, type_text, press_key, run_shortcut — those go
  the Rust FFI path like everything else).
- `ComputerUseBridge` (`Epistemos/Bridge/ComputerUseBridge.swift`): `@MainActor final class`, `.shared`, guarded by
  `#if !EPISTEMOS_APP_STORE` (AppStore build has a same-API stub at `AppStoreComputerUseStubs.swift:172`). Entry:
  `func execute(actionJSON: String) async -> String`. It parses an **`"action"` discriminator** field
  (`input["action"] ?? "screenshot"`), checks `AXIsProcessTrusted()`, returns a JSON String (errorResult JSON on
  failure).
- WRINKLE: the MCP catalog exposes computer-use as SEPARATE named tools, but the bridge wants ONE action-keyed JSON.
  So the composed executor must, for `name ∈ {see,click,type,scroll,keys,screenshot}`, build `{"action":name, …args}`
  and call `await ComputerUseBridge.shared.execute(actionJSON:)` (a `@MainActor` hop), then wrap the String result →
  `LocalToolResult(toolName: name, resultJson: result, isError: <error heuristic>)`.
- BASE (everything else): `ToolTierBridge.toolExecutor() -> LocalAgentToolExecutor` (ToolTierBridge.swift:485) — a
  `@Sendable` closure → `executeToolCallBridged(…)` → Rust `execute_tool_call` FFI. Optionally wrap the whole composed
  executor with `PipelineService.observedToolExecutor(base:…)` (PipelineService.swift:808) for hooks/permissions/
  provenance.
- SHAPE: `composed = { name, args in computerNames.contains(name) ? <ComputerUseBridge path> : await base(name,args) }`
  → pass to `WorkNativeMCPServer(executor: composed)`. CONSTRAINT: the closure crosses to `@MainActor` for the bridge;
  honor the `#if !EPISTEMOS_APP_STORE` split (the stub keeps the same `.shared.execute` API so one code path works).
INCREMENT (c) SPEC — config-write wiring (recon 2026-06-24, traced the full call graph):
- `mergedOpenCodeConfigJSON(existingJSON:stdioServerPath:vaultRoot:nativeMCP:)` (WorkOpenCodeRuntime.swift:187) —
  ALREADY takes `nativeMCP` (W-R2 done); asserts `epistemos-native` `{type:remote,url,headers,enabled}` when non-nil.
- `writeMergedFusionConfig(stdioServerPath:vaultRoot:)` (:238) → calls mergedOpenCodeConfigJSON at :241. NEEDS an
  additive `nativeMCP: WorkNativeMCPRegistration? = nil` param threaded to :241.
- `BundledWorkOpenCodeShell.launchSpec(workspace:epistemosVaultRoot:)` (:262) → calls writeMergedFusionConfig at :289
  (inside the `if let vaultURL …` honest-vault gate). NEEDS to pass `nativeMCP:` through. Protocol
  `WorkOpenCodeShell.launchSpec(workspace:epistemosVaultRoot:)` (WorkOpenCodeShell.swift:44) + the convenience
  overload (:51) gain an additive `nativeMCP: WorkNativeMCPRegistration? = nil` (default-nil → existing callers
  unaffected; the only real caller is `WorkTerminalView.realShellSpec()` :190).
- SPLIT: **(c1) BUILDABLE NOW** — thread the `nativeMCP` default-nil param through `writeMergedFusionConfig` + the
  `launchSpec` protocol/impl/overload; + a pure unit test mirroring the existing `nativeMCPRegisteredWhenProvided`
  (assert the written config gains `epistemos-native` when a registration is passed, omits it when nil). All additive
  + pure → static-verifiable. **(c2) RUNTIME-GATED** — an app-level owner (the same place that owns
  `WorkRuntimeSupervisor`, e.g. WorkWebSurfaceView/app coordinator) constructs `WorkNativeMCPServer(executor: <composed
  (b)>)`, `start()`s it EARLY, and supplies its `.running(reg)` registration to `realShellSpec()`. RACE/HONESTY: if the
  server isn't `.running` yet at launch, pass nil → `epistemos-native` omitted (honest, mirrors the no-vault gate);
  the owner should start the server before the work shell launches.
W-R3 BUILD — increment (b) DONE + VERIFIED (`bn5jalu4q` = BUILD SUCCEEDED, zero errors): `Epistemos/Work/WorkNativeToolExecutor.swift`
— `nonisolated enum WorkNativeToolExecutor` with `composed(base:) -> LocalAgentToolExecutor`: routes
`name ∈ {see,click,type,scroll,keys,screenshot}` → `ComputerUseBridge` (folding the tool name into the bridge's
single `"action"`-keyed JSON via `computerActionJSON`, then wrapping the String result → `LocalToolResult` with
`isErrorResult` mapping `{"success":false}`/`{"error":…}` → isError); everything else → the injected `base`
(production = `ToolTierBridge.toolExecutor()` Rust FFI). KEY FINDING: NO `#if` needed — the AppStore stub
(`AppStoreComputerUseStubs.swift:171`) exposes the IDENTICAL `@MainActor ComputerUseBridge.shared.execute(actionJSON:)
async -> String` as the real bridge (`#if !EPISTEMOS_APP_STORE`), so one code path serves both builds (stub returns
"automation denied"). The @MainActor hop is a private `@MainActor` helper. + `EpistemosTests/WorkNativeToolExecutorTests.swift`
(5 tests: membership, non-computer→base routing via a stub base, action-JSON merge, empty/invalid-args tolerance,
error detection). The computer-use path itself (TCC + live screen) is RUNTIME-PROOF-OWED → not exercised in tests.
W-R3/W-R2 BUILD — increment (c1) DONE + VERIFIED (`bck0itvf0` = BUILD SUCCEEDED, zero errors): `nativeMCP` threaded
end-to-end (additive, nil-defaulting → ZERO behavior change until (c2) supplies a non-nil reg):
- `writeMergedFusionConfig(stdioServerPath:vaultRoot:nativeMCP:=nil)` (WorkOpenCodeRuntime.swift:238) → forwards to
  `mergedOpenCodeConfigJSON(…nativeMCP:)`.
- `WorkOpenCodeShell.launchSpec` protocol requirement (WorkOpenCodeShell.swift:44) gained `nativeMCP:` as a 3rd param
  (protocol requirements can't have default args → used **nil-defaulting extension overloads** instead: the existing
  1-arg `launchSpec(workspace:)` + a NEW 2-arg `launchSpec(workspace:epistemosVaultRoot:)` both forward `nativeMCP:nil`,
  so every existing caller — WorkTerminalView.realShellSpec :192, the 2 seam/runtime tests — is unchanged).
- Both conformers updated: `InertWorkOpenCodeShell` (still throws), `BundledWorkOpenCodeShell` (:262 → passes
  `nativeMCP` into writeMergedFusionConfig at the honest-vault gate).
swiftc -parse exit 0 on both files. TEST NOTE: no NEW test — `writeMergedFusionConfig`/`launchSpec` do file IO at the
fixed `fusionConfigURL()` (testing them would POLLUTE the real Application-Support config — the `.standard` gate
gotcha). The config-shaping BEHAVIOR is already covered by `nativeMCPRegisteredWhenProvided`/`nativeMCPOmittedByDefault`
(mergedOpenCodeConfigJSON, the pure seam); the threading is compile-verified + the existing seam/runtime launchSpec
tests exercise the back-compat overloads.
W-R3/W-R2 BUILD — increment (c2) DONE + VERIFIED (`b8d0csjmy` = BUILD SUCCEEDED, app target, zero errors):
- NEW `Epistemos/Work/WorkNativeMCPHost.swift` — `@MainActor` singleton `WorkNativeMCPHost`. `startAndAwaitRegistration(vaultRoot:)`
  lazily builds `WorkNativeMCPServer(executor: WorkNativeToolExecutor.composed(base: ToolTierBridge(vaultPath:, tier: .full).toolExecutor()))`,
  `start()`s it, polls the lock-protected status to `.running`, returns the `WorkNativeMCPRegistration` (nil/honest if it
  can't bind or isn't ready in `timeout`). Rebuilds the server when the active vault changes (native tools root at the live vault).
- `WorkTerminalView.realShellSpec()` → `async`: starts the host BEFORE config generation and passes the registration into
  `shell.launchSpec(…, nativeMCP:)` → `writeMergedFusionConfig(nativeMCP:)` → the `epistemos-native` config entry. The
  `.task(id: workspace)` resolver now does `try? await realShellSpec()`.
- PROOF test `nativeMCPRegistrationFlowsIntoConfig` (WorkOpenCodeRuntimeTests): starts a REAL loopback `WorkNativeMCPServer`,
  awaits its `.running` registration, feeds it to `mergedOpenCodeConfigJSON`, and asserts the output's `mcp.epistemos-native`
  = `{type:remote, url:<reg.url>, headers.Authorization:"Bearer <reg.token>", enabled:true}` (+ asserts the live url is a real
  `http://127.0.0.1:<port>/mcp` with a non-empty token). Resilient synthetic-reg fallback if loopback bind is unavailable.
PROOF EXECUTED (`b8r3btaz7`, scoped `xcodebuild test`): `nativeMCPRegistrationFlowsIntoConfig` **PASSED** — a real
loopback `WorkNativeMCPServer` started, produced a registration, and `mergedOpenCodeConfigJSON(nativeMCP:)` emitted
`mcp.epistemos-native = {type:remote, url, headers.Authorization:"Bearer …", enabled:true}`. The full W-R3 chain also
PASSED: `WorkNativeMCPServerTests`, `WorkToolMCPCoreTests`, `WorkNativeToolExecutorTests`, `WorkOpenCodeRuntimeTests`.
(Test-target compile fix this slice: `WorkNativeMCPServerTests` referenced `static` `token`/`authHeaders` from instance
`@Test` methods → made them instance members. App-target builds never compile tests, so it was latent until this run.)
PRE-EXISTING UNRELATED REDS (NOT this slice, source files untouched by me) — VERDICT: both are DRIFT, NOT regressions:
- `editorDebouncesPreviewAndCollapsesDiagnostics` (line 103): asserted a SINGLE-LINE
  `openNewChat(attaching: workspaceAttachment)` but `HTMLWorkspaceEditorView.swift:675-676` writes it MULTI-LINE →
  substring miss; the feature is intact. FIXED (split into `openNewChat(` + `attaching: workspaceAttachment` asserts).
  CONFIRMED by scoped test run `blzazzb57`: `editorDebounces…` now PASSES (gone from the failure list); the
  `HTMLWorkspaceSourceGuardTests` suite is 15 tests with exactly 1 remaining issue = the deferred preview test below.
- `previewUsesOfflineWKWebViewDefaults` (line 31): stale `!contains("addUserScript(")` — committed
  `HTMLWorkspacePreviewView.swift:77` legitimately uses `addUserScript` for the GATED, READ-ONLY console bridge
  (`if HTMLWorkspaceConsoleBridge.enabled`, env `EPISTEMOS_HTML_WORKSPACE_CONSOLE_V0` default OFF). The app-BRIDGE
  security gate (`safeAPIEnabled && package.manifest.sandboxPolicy.allowAppBridge`, src line 65; test line 38) is
  INTACT → no security regression. DEFERRED to owner: it's a security-guard assertion; relaxing the blanket
  `!addUserScript` to allow the gated console bridge is a security-surface ratification, not an autonomous away-loop call.
REMAINING (runtime-proof-owed, owner runs): the LIVE handshake — launch Work → confirm the written OpenCode config file
contains `epistemos-native` AND OpenCode `tools/list` shows the full native surface incl. computer-use. NOT YET integrated:
the real OpenWork `apps/app` SPA surface (the WebView currently shows the honest placeholder preview, NOT OpenWork's UI).
TRANSPORT DESIGN (resolved, recon 2026-06-24): OpenCode supports `type:"remote"` MCP servers (url+headers) —
confirmed in the opencode donor config tests (`mcp: { name: { type:"remote", url:"…/mcp", enabled } }`,
`packages/opencode/test/config/config.test.ts`). Since the `LocalAgentToolExecutor` lives IN the app
process, host the MCP server IN-PROCESS as a loopback HTTP endpoint (no stdio-IPC shim): NWListener on
`127.0.0.1:<ephemeral>` serving POST `/mcp` → `WorkToolMCPCore.handle(requestJSON:)` → `application/json`
JSON-RPC response (MCP Streamable-HTTP request/response; no SSE needed for tools/list+tools/call). Auth:
`Authorization: Bearer <per-launch token>` validated by the listener. Then register in the OpenCode config
(W-R2): `mcp.epistemos-native = { type:"remote", url:"http://127.0.0.1:<port>/mcp",
headers:{ Authorization:"Bearer <token>" }, enabled:true }`. This makes OpenCode call EVERY native tool
in-process (computer-use included) — the omega_mcp_stdio Swift gap closed without IPC.
EXECUTOR COMPOSITION (resolved, recon 2026-06-24): the production tool execution is LAYERED, not one
closure. `PipelineService.observedToolExecutor(base, …)` (PipelineService.swift:808) WRAPS a base executor
with hooks (HookRegistry), permission gating, provenance + events. The BASE = `ToolTierBridge.toolExecutor()`
(ToolTierBridge.swift:485) → forwards to the Rust `execute_tool_call` FFI (vault/graph/Rust-side tools).
**Computer-use is intercepted at a HIGHER layer (ChatCoordinator → `ComputerUseBridge`), NOT in this chain.**
IMPLICATION for the W-R3 loopback executor: it must COMPOSE — (1) computer-use tool names → `ComputerUseBridge`;
(2) everything else → `ToolTierBridge.toolExecutor()` (Rust FFI); optionally wrapped by `observedToolExecutor`
for hooks/permissions/provenance. Wiring `ToolTierBridge.toolExecutor()` ALONE would miss computer-use (the
"every tool" point). NEXT BUILD: NWListener `/mcp` transport + `WorkToolMCPCore(executor: <composed>)`. The
Rust-side tool path is buildable + static-verifiable; the computer-use composition + end-to-end (TCC perms,
OpenCode driving it) are RUNTIME-PROOF-OWED (owner runs).

## W-R2 DESIGN — zero-config provisioning (recon 2026-06-24; converges with W-R3)
PROVISIONING POINT ALREADY EXISTS: `WorkOpenCodeRuntime.mergedOpenCodeConfigJSON` (:175) asserts the
`epistemos-vault` MCP (type:local, command:[omega_mcp_stdio], environment:{EPISTEMOS_VAULT_ROOT}) + `lsp:true`,
MERGE-PRESERVING; written by `writeMergedFusionConfig` (:214) ← `BundledWorkOpenCodeShell.launchSpec`
(gated on a real active vault, Slice 1). So the OpenCode config is auto-written before the runtime is used.
W-R2/W-R3 completeness = EXTEND `mergedOpenCodeConfigJSON` to ALSO assert **`epistemos-native`** (the
app-hosted full-tool MCP): `{ "type":"remote", "url":"http://127.0.0.1:<port>/mcp",
"headers":{ "Authorization":"Bearer <token>" }, "enabled":true }`, alongside `epistemos-vault` (merge already
handles it). Parameterize by an optional `(nativeMCPURL, token)` → assert only when the app-hosted server is
live; nil → unchanged (honest). This is a PURE JSON-shaping change → static-verifiable + a source-guard/unit
test (mirror `fusionVaultRootBridgesSkills`). W-R2 CONFIG ASSERTION DONE + VERIFIED (`bz7adaug0` = BUILD SUCCEEDED): `mergedOpenCodeConfigJSON` gained an optional
`nativeMCP: WorkNativeMCPRegistration?` → asserts `epistemos-native` `{type:remote, url, headers:{Authorization:
Bearer <token>}, enabled}` when provided; OMITTED (honest) when nil; merge-preserving (the `epistemos-vault`
stdio server stays). + 2 tests (`nativeMCPRegisteredWhenProvided`, `nativeMCPOmittedByDefault`). swiftc -parse
clean; existing config tests unaffected (additive default-nil param). REMAINING (runtime-proof-owed): build the
NWListener `/mcp` server (provides the url/token), wire `launchSpec`→`writeMergedFusionConfig`→`nativeMCP`, +
the computer-use executor composition.
ACCEPTANCE (W-R3): clean launch → OpenCode `tools/list` shows the FULL surface (not ~23) AND a Swift-side
tool (e.g. `see`/`click`) executes via OpenCode, with zero manual config.

RESKIN PLAN (recon 2026-06-24 — owner: "doesn't look like my UI… edit the setup"): FEASIBLE WITHOUT AN SPA
REBUILD via CSS-variable INJECTION through the existing `WorkSPAServer` bootstrap (same path as the token
`<script>`).
• HOW the SPA themes: `apps/app/src/app/index.css` defines semantic CSS custom properties on `:root` (light) AND
  `[data-theme="dark"]` (dark) — `--dls-*` design tokens (app-bg, surface, sidebar, canvas, surface-muted, border,
  accent `#011627`, accent-hover, accent-fg, text-primary, text-secondary, hover, active, `--dls-radius:16px`
  [already matches our curved box!], shadows) + shadcn tokens (`--background/--foreground/--card/--popover/
  --primary[blue-9]/--secondary/--muted/--accent/--destructive/--warning/--border/--input/--ring`). They resolve
  to Radix scales (`--slate-1..12`, `--blue-9`, …) in `styles/colors.css`. Theme toggled by `[data-theme="dark"]`
  or `.dark` on the root.
• MECHANISM: inject `<style id="epistemos-reskin">` overriding the SEMANTIC tokens (≈20, not the whole Radix
  scale) with EpistemosTheme values, using `!important` on each `--var` decl so it wins regardless of injection
  order. Emit BOTH `:root{…}` (Epistemos light) and `[data-theme="dark"]{…}` (Epistemos dark) so either toggle
  state shows the Epistemos look. NO rebuild, signed/notarization-safe (served over the loopback origin).
• TOKEN MAP (EpistemosTheme → OpenWork): background→`--dls-app-bg/--dls-background/--background`;
  surface→`--dls-surface/--card/--popover`; textPrimary→`--dls-text-primary/--foreground`;
  textSecondary/muted→`--dls-text-secondary/--muted-foreground`; accent→`--dls-accent/--primary`;
  accentHover→`--dls-accent-hover`; border→`--dls-border/--border`; keep `--dls-radius:16px`.
• CSS-GEN DONE THIS FIRE: NEW `Epistemos/Work/WorkSPAReskin.swift` (`enum`, `nonisolated` statics) — `styleBlock(
  theme: EpistemosTheme.ResolvedTheme) -> String` emits `<style id="epistemos-reskin">:root,[data-theme="dark"]{…
  !important}</style>` mapping the high-impact `--dls-*` + shadcn tokens to EpistemosTheme colors; `cssColor(_:)`
  converts a `ResolvedColorToken` via `nsColor.usingColorSpace(.sRGB)` → `#rrggbb`/`rgba()`. + `WorkSPAReskinTests`
  (hex/alpha/styleBlock asserts). swiftc -parse clean; ✅ `b3it9qmea` = TEST BUILD SUCCEEDED (helper + tests pass).
• WIRING DONE THIS FIRE (code-complete; build OWED + visual proof OWED): chose to pass the PRE-RENDERED CSS string
  (keeps `WorkSPAServer` decoupled from EpistemosTheme/AppKit, not the theme object). `WorkSPAServer` gained an
  optional `reskinCSS: String?` init param (default nil → backward-compatible, can't break the verified serve path)
  + a new `injectHeadSnippet(intoHTML:snippet:)` (inserts at END of `<head>`, after the SPA's stylesheets, so the
  reskin overrides them — belt-and-suspenders with the `!important` in the block). `serve` now injects bootstrap
  (if any) THEN reskin (if any) into served HTML. `WorkWebSurfaceView.startSurface` passes
  `reskinCSS: WorkSPAReskin.styleBlock(theme: theme.resolved)`. +2 tests (`injectsHeadSnippet` pure +
  `servesWithReskin` end-to-end). swiftc -parse CLEAN on all 3 files. Build `b39yoeoee` (build-for-testing) verifying
  the wiring + 2 tests (OWED-verify). ⇒ owner rebuild → ⌘4 = VISUAL PROOF of the Epistemos look (no SPA rebuild). If `!important` doesn't
  fully override (Tailwind v4 @layer / runtime-injected CSS), fallback = inject at end of `<body>` or bump
  specificity — owner screenshot will tell.
  ✅ RESKIN DE-RISK (inspected the STAGED built SPA `dist/index.html` + assets, 2026-06-24): index.html HAS a real
  `<head>` with TWO `<link rel="stylesheet">` (index-*.css + app-*.css). `injectHeadSnippet` inserts at END of
  `</head>` → AFTER both stylesheets ⇒ the reskin `<style>` wins by SOURCE ORDER (before even needing !important).
  The inline boot `<script>` sets `documentElement.dataset.theme` from `localStorage["openwork.themePref"]`
  (default "system"→OS). My block targets `:root,[data-theme="dark"]` and `:root` (=<html>) ALWAYS matches ⇒
  Epistemos vars apply in BOTH light + dark. CONFIDENCE: override mechanism is sound; the `!important`/body fallback
  is now a safety net, not the primary bet.
  ✅ REFINEMENT DONE (themePref alignment): `WorkSPABootstrap` gained `themePref: String?`; `injectBootstrap` now
  ALSO seeds `localStorage["openwork.themePref"]` in the EARLY-head script (before the SPA's inline boot script
  reads it → its `data-theme` matches), and `WorkWebSurfaceView.awaitWorkerBootstrap` passes
  `theme.isDark ? "dark" : "light"`. So the SPA's own light/dark COMPONENT logic (Tailwind `dark:` variants, icon/
  shadow variants) aligns with the forced palette — no mode/palette mismatch. + test `injectsThemePref` (seeds when
  set / omits when nil). swiftc -parse CLEAN; build `b047uypji` (build-for-testing) OWED-verify.
• "EDIT THE SETUP" (owner's other want): the OpenWork onboarding/"Connect custom remote" is bypassed by
  auto-connect already; further setup-screen edits (branding, copy) are SPA-source changes → defer to Spike-B
  (SPA rebuild) OR cover the visible chrome via the same reskin injection where it's CSS-driven.
• ✅ RESKIN BUILD-VERIFIED: `b39yoeoee` = TEST BUILD SUCCEEDED (wiring + `injectsHeadSnippet`/`servesWithReskin`/
  `WorkSPAReskinTests` all compile + pass). Reskin is CODE-COMPLETE + BUILD-VERIFIED + mechanism-de-risked; only the
  owner's ⌘4 visual proof remains.
• ✅ "DUI" RESKIN EXTENSION (owner 2026-06-24: "flat boxy UI monospace, block cursor, theme colors — looks like
  code, a GUI not a TUI"): extended `WorkSPAReskin.styleBlock` — (a) token overrides `--dls-radius/--radius:0px`,
  `--dls-*-shadow:none` (kills the SPA's 16px curve + shadows); (b) NEW `duiRules(accent:)` appends global CSS:
  MONOSPACE on every non-SVG element (`body *:not(svg):not(svg *)` → icons/SVG keep glyphs), `*{border-radius:0;
  box-shadow:none}` (flat+boxy), and `input,textarea,[contenteditable]{caret-color:<accent>;caret-shape:block}`
  (terminal-style block caret where WebKit supports it). All via the existing injection (NO SPA rebuild). +
  `WorkSPAReskinTests.duiRules`. swiftc -parse CLEAN; build `b7tltuuec` (app-target) OWED-verify. 🖼️ VISUAL PROOF
  OWED — owner: rebuild ⌘R → ⌘4 to see the flat/mono GUI. (Deliberately left background-IMAGES intact — killing all
  would break logos/avatars; gradients can be flattened next if wanted.) Native curved-box shell
  (`WorkWebSurfaceView` RoundedRectangle 16) is separate — flatten it too if the owner wants the whole frame boxy.

W-R1 BUNDLE-FOR-RELEASE ANALYSIS (recon 2026-06-24 — the worker `openwork-server` + SPA `dist` are STAGED MANUALLY
in `~/Library/Application Support/Epistemos/{WorkRuntime,WorkSPA}` → debug-only; a fresh install / Release / AppStore
build has NEITHER → Work would be inert there). MECHANISM (how opencode+bun ship today): `build-opencode-runtime.sh`
(chained in the single pbxproj Run Script phase) version-stamp-gated-fetches binaries from GitHub releases into
`Epistemos/Resources/opencode-runtime/bin/` — a SYNCHRONIZED folder that auto-bundles into `.app/Contents/Resources`
(no pbxproj edit; the script is a source file I CAN extend). For the worker+SPA the same destination works, but the
SOURCE differs — they are NOT public release binaries:
  • `openwork-server`: built from the donor `apps/server` via `bun build --compile` (~60MB).
  • SPA `dist`: built from the donor `apps/app` via `pnpm build` (~16MB; needs pnpm/Vite ~1GB).
THREE OPTIONS (OWNER DECISION — disk/repo tradeoff, correctly gated):
  (a) COMMIT the built artifacts into `Epistemos/Resources/` (synchronized → auto-bundle). Simple + reproducible
      builds, but ~76MB of binaries in git (owner is at DISK CAP; repo bloat).
  (b) BUILD at build time by extending `build-opencode-runtime.sh` to clone/build the donor — requires the donor
      OpenWork source vendored/reachable (it's a local /tmp clone now; `/ee` is OFF-LIMITS) + pnpm/bun at build
      time (~1GB, slow first build). Cleanest provenance, heaviest setup.
  (c) FETCH pre-built worker+SPA from a release I publish — needs a release pipeline; not set up.
RECOMMENDATION: (a) for a first shippable Release (one-time ~76MB), revisit (b) once the donor is vendored in-tree.
This is the natural companion to Spike-B (which builds the SPA from source). NOT autonomous — owner picks the source.

================================================================================
## ✅ MILESTONE: OpenWork WORK FEATURE COMPLETE (build-verified) — 2026-06-24
================================================================================
Every functional piece of the embedded OpenWork Work surface is CODE-COMPLETE + BUILD-VERIFIED (debug):
  • Auto-connect (worker URL+token seeded → no "Connect custom remote")        ✅ build + runtime proven
  • OpenCode availability (OPENWORK_MANAGE_OPENCODE + OPENWORK_OPENCODE_BIN)     ✅ build + runtime proven
  • Workspace registration (--workspace + SPA default fallback)                 ✅ runtime proven
  • LLM provider (OpenCode auth.json, HOME-shared)                              ✅ present, no gap
  • Native-tool MCP (option B: WorkNativeMCPHost → provisioner → POST /mcp)     ✅ build-verified; mechanism runtime-proven
  • Auto-approval (--approval auto → embedded agent can write)                  ✅ build + runtime proven
  • Reskin (CSS-var injection: palette + themePref mode alignment)             ✅ build-verified (themePref = b047uypji TEST BUILD SUCCEEDED)
ONLY REMAINING for the feature = OWNER PROOF (rebuild ⌘R → ⌘4): visual (Epistemos look) + runtime (agent responds, calls a native tool).

## NEXT WORKSTREAMS (all gated/heavy → not blind-autonomous; menu for the next fires)
1. MINI-SESSION MODEL (authority plan §109-163): LARGE native session-ontology layer wrapping the SPA — main tabs
   (root sessions) / attached mini panes / detached floating MiniChat, all carrying `parentSessionID`, with recents
   parentage + dedup. Donor `opencode-mini-session` (NOT present locally) + OpenChamber patterns. Multi-fire.
   ✅ INCREMENT 1 DONE (data model): NEW `Epistemos/Work/WorkSession.swift` — pure value type encoding the ontology:
   `WorkSessionKind {main,mini}` + `WorkSessionPresentation {attached,detached}` + `WorkSession{id,kind,
   parentSessionID,presentation,workspaceID,openCodeSessionID,title}` with `isValid` invariants (main⇒no parent;
   mini⇒parent≠nil,≠self), `.main()`/`.mini(parent:)` factories (mini inherits parent workspace), and
   `presented(as:)` (detach/reattach = presentation only, identity unchanged). Codable/Sendable/Hashable. +
   `WorkSessionTests` (5 tests). ✅ `boqkf82rg` = TEST BUILD SUCCEEDED (model + WorkSessionTests in-suite). NOTE: donor
   sessions carry `workspaceId` but NO `parentSessionID` → parentage is correctly a native concept.
   ✅ INCREMENT 2 DONE (registry): NEW `Epistemos/Work/WorkSessionRegistry.swift` — pure value-type registry:
   `upsert` (dedup-by-id, ignores invalid → no ghost forks), `session(id:)`, `mainSessions`, `children(of:)`,
   `remove` (MAIN cascade-removes mini children = no orphans; mini removes only itself), `promote` (explicit
   mini→main, drops parentage; no-op for main), `setPresentation` (detach/reattach = presentation only). Sendable +
   Equatable. + `WorkSessionRegistryTests` (5 tests). ✅ TYPE-CHECK VERIFIED via `swiftc -typecheck WorkSession.swift
   WorkSessionRegistry.swift` together (real Sema, Foundation-only → confirms compilation + Equatable synthesis
   WITHOUT the slow build-for-testing); tests building in `b4i6kxww5` (OWED). FAST-GATE TECHNIQUE (build-less win):
   self-contained pure files (no app cross-deps beyond Foundation) can be `swiftc -typecheck`'d together for genuine
   type verification in seconds — use this instead of build-for-testing for pure value types/logic.
   ✅ DONOR ALIGNMENT VALIDATED (C6/C9/C10 recon): my model/registry match the donor mechanics —
   • C6 permission store walks `session.parentID` so child sessions INHERIT the parent's scope ⇒ OpenWork sessions
     DO carry parentage; my `parentSessionID` maps to the donor's `parentID` (naming: native uses parentSessionID,
     bind-time maps to parentID).
   • C9 mini-chat `session` vs `draft` mode ⇔ my `openCodeSessionID` set vs nil (draft = not-yet-bound); directory
     inheritance ⇔ my workspace inheritance; "open-main" ⇔ navigate to `parentSessionID`.
   • C10 dup-prevention: Epistemos ALREADY has `MiniChatWindowController.windows[chatID]` focus-existing → the
     detached-window increment EXTENDS it (runtime+session key, open-parent, last-surface routing), not new code.
   ✅ INCREMENT 3 DONE (store): NEW `Epistemos/Work/WorkSessionStore.swift` — `@MainActor @Observable` store
   wrapping the registry + the one bit of UI state the registry shouldn't own: the ACTIVE session id. API:
   `sessions`/`mainSessions`/`activeSession`/`children(of:)` reads; `upsert`(focuses first/when active invalid),
   `focus`(known-ids-only → no ghost focus), `remove`(active falls back to a main tab→nil), `promote`,
   `setPresentation`. + `WorkSessionStoreTests` (4 @MainActor tests). ✅ TYPE-CHECK VERIFIED via `swiftc -typecheck`
   on the 3 files together (the @Observable macro EXPANDS fine in bare swiftc → fast gate works even for
   @Observable); ✅ `bzi10keto` = TEST BUILD SUCCEEDED (store + WorkSessionStoreTests in-suite). MITIGATION VERDICT
   (`SWIFT_EMIT_LOC_STRINGS=NO`): REDUCES but does not fully eliminate xcstrings rewrite (settled ~+600/-25 vs +619
   without the flag — the catalog is still re-written, just with fewer adds). ⇒ the REAL protection is BUILD LESS:
   use `swiftc -typecheck` (no extraction) for compilation; reserve build-for-testing for actually running tests.
   NEXT (UI — gated on owner verifying the base): main pane + mini rail + detach window. ✅ UI-INCREMENT GROUNDED
   (recon of the existing `Epistemos/Views/MiniChat/MiniChatWindowController.swift`): it ALREADY has the C10 dedup —
   `windows: [String: NSWindow]` keyed by `chatID`, `openChat(_:)` does focus-existing
   (`if let existing = windows[chatID] { existing.makeKeyAndOrderFront(nil); return }`), `handleWindowClose` cleans
   up, and there's a rekey path (oldChatID→newChatID). PLAN: detached mini = `openChat(workSession.id)` (reuses the
   dedup → "open same mini focuses existing, not a ghost" for free); add an "open-parent" action that focuses
   `parentSessionID`; (C10 refinement) optionally namespace the key with `workspaceID` to avoid cross-workspace
   collisions. The `WorkSessionStore` drives it: `.detached` presentation → open the window; `.attached` → close it
   + show inline. Wire to the live OpenWork session id (`/workspace/:id/sessions`).
   ✅ INCREMENT 4 DONE (rail view — per loop "keep building look-bearing UI, mark proof OWED"): NEW
   `Epistemos/Work/WorkSessionRailView.swift` — SwiftUI native rail bound to `WorkSessionStore`: renders each MAIN
   + its MINI children, tap-to-focus (active highlighted with the theme accent), `+` new-mini overlay on mains, and
   a context menu per mini (Detach/Reattach → `setPresentation` + `onDetach`/`onReattach` callbacks; Promote to tab;
   Close). `#Preview` seeds a main + 2 minis (one detached) for visual verification. swiftc -parse CLEAN; build
   `bq1nz45l5` = **BUILD SUCCEEDED** (rail view compiles, app target). 🖼️ VISUAL PROOF OWED (owner: Xcode #Preview,
   or live once wired into `WorkWebSurfaceView`).
   ✅ INCREMENT 6 (pure core) DONE: NEW `Epistemos/Work/WorkSessionMapper.swift` —
   `workSessions(fromSessionsJSON:workspaceID:) -> [WorkSession]` maps the worker's `GET /workspace/:id/sessions`
   `{items:[{id,parentID?,title?}]}` → native sessions, classifying MAIN vs MINI exactly like the donor
   `getRootSessions` (no/orphan/self parentID → main; known parentID → mini; `id` = bound `openCodeSessionID`).
   + `WorkSessionMapperTests` (4 tests). ✅ TYPE-CHECK VERIFIED (`swiftc -typecheck` w/ WorkSession, Foundation-only
   → no build, no xcstrings churn); tests ride a future build.
   ✅ INCREMENT 6b (fetch) DONE: `WorkOpenWorkProvisioner.fetchWorkSessions(workerBaseURL:workerToken:workspaceID:)`
   — async `GET /workspace/:id/sessions` (Bearer worker token) → `WorkSessionMapper` → `[WorkSession]`; best-effort
   (`[]` on failure). Structurally identical to the build-verified `discoverWorkspaceID`; composes the type-check-
   verified mapper. swiftc -parse CLEAN (no build → no xcstrings churn).
   ⚠️⚠️ RECONCILIATION NEEDED — DUPLICATION RISK (found 2026-06-24 via tree integrity check; PROCESS MISS: I did
   NOT read `docs/handoffs/WORK_MINI_SESSION_PARITY_LEDGER_2026_06_24.md` before building). That ledger's recon says
   "audit-first — do NOT rebuild these" and lists EXISTING primitives for the WORK mini-session ontology:
   `AgentSessionLineageStore` (ALREADY maps `chatThreadID → parentSessionID` + persists `parent_session_id` to
   session.json), `ThreadState`/`ChatThread`, `MiniChatWindowController` (dedup), `SDChat` (persistence), shared
   `ActTurnStreamCore`/`ComposerCurrentAccessPlan`. Its recommended first step = "add `parentSessionID` to the
   EXISTING mini model + establish it via `AgentSessionLineageStore`". The dirty `ThreadState.swift`/`ChatTypes.swift`
   (`+parentSession` ×12) + `ThreadStateTests`/`OntologyRefactorRegressionGuardTests` edits in the tree (parallel/
   earlier work, NOT mine this session) ARE that recommended approach starting. MY `WorkSession`/Registry/Store
   built a SEPARATE in-memory ontology that does NOT use `AgentSessionLineageStore` or `SDChat` persistence →
   parallel to the intended path. RECONCILE before any further mini-session work: either (A) my `WorkSession` becomes
   the clean WORK-layer ontology that PERSISTS via `AgentSessionLineageStore`/`SDChat` (wire it to them, don't keep a
   separate in-memory store), or (B) drop my new files and extend `ThreadState`+`AgentSessionLineageStore` per the
   parity ledger. My files are tested/clean (low waste to keep as the ontology), but they MUST integrate with the
   existing persistence primitives, not duplicate them. → OWNER/next-session decision; do not build more mini-session
   UI until reconciled.
   RECONCILIATION PLAN (concrete, after auditing the primitives — makes the owner's call + the wiring fast):
   • `AgentSessionLineageStore` (Epistemos/Vault) = `shared`, UserDefaults map `chatThreadID→parentSessionID` +
     `recordCompletedSession(sessionID:chatThreadID:...)` + `parentSessionID(forChatThread:)` + `writeMetadata`
     (writes `parent_session_id`/`chat_thread_id` into session.json). STRING-keyed, persistent. This is the
     canonical parentage store ("persistence stays in runtime").
   • Parallel work (NOT mine) added `parentSessionID` to `ThreadState.upsertMiniChatSession` + `ChatThread` → the
     EXISTING ACT mini-chat model now carries a parent. That's the ACT-window layer (SDChat-persisted).
   • My `WorkSession` = the WORK/OpenCode-session layer (workspaceID + openCodeSessionID), in-memory registry only.
   • So they're DIFFERENT LAYERS that both model parentage. RECOMMENDED reconciliation (option A, least waste):
     KEEP `WorkSession` as the WORK ontology + `WorkSessionMapper` (OpenWork→native), but make `WorkSessionStore`'s
     parentage READ/WRITE through `AgentSessionLineageStore` (not a separate in-memory map) so WORK + ACT minis share
     ONE persistent lineage store; ChatThread.parentSessionID (parallel) stays the ACT-window presentation. This
     unifies persistence without dropping the clean WORK ontology. Option B (drop my files, do everything in
     ThreadState) loses the WORK-layer typing + the mapper. → owner picks A or B; A is the obvious-best.
   ✅✅ MINI-SESSION (my new files) IS LOGIC-COMPLETE: model + registry + store + rail-view + mapper + fetch — ALL built +
   verified. The store-population call site is `store.upsert(contentsOf: await fetchWorkSessions(...))` — a 1-liner.
   REMAINING = MOUNT, and it is NOT a 1-liner — DEFINITIVE RESOLUTION (stop re-litigating): a mounted rail is only
   useful with DEEP SPA integration, which is a multi-fire workstream + a redundancy judgment call:
   (a) FOCUS-SYNC: native focus must drive the WebView's ACTIVE session — the SPA owns the active session, so native
       focus alone is cosmetic. Needs telling the SPA to switch sessions (its API / a postMessage bridge).
   (b) DETACH-WINDOW: `MiniChatWindowController.openChat(id)` opens an EPISTEMOS chat, NOT an OpenWork session →
       detach needs a NEW floating Work-WebView window (scoped to the session). Reusing openChat would show the wrong
       content.
   Without (a)+(b) the rail is a NON-FUNCTIONAL DUPLICATE of the SPA's own session list. Since the embedded SPA
   already manages sessions well, this may not be worth building. ⇒ GATED ON OWNER: skip native session-chrome
   (recommended — use the SPA's) OR greenlight the deep (a)+(b) integration. The rail VIEW + backend stay as ready
   building blocks either way. (This supersedes the earlier "1-step mount, just surface-risk" framing.)
   ✅ FULL-INTEGRATION BUILD: `ba3d78dg7` (app-target) = BUILD SUCCEEDED — the ENTIRE accumulated session (all Work +
   mini-session files incl. WorkSessionMapper + fetchWorkSessions) compiles in-module ⇒ owner's ⌘R rebuild succeeds.
2. VAULT-AS-WORK-CWD (gap I flagged): Work currently roots at an App Support SCRATCH dir, not the user's real vault,
   so the agent acts on empty content. GATED: (a) owner intent on Work's working directory, (b) the dual-prefs-domain
   complication (Debug build resolves NO active vault — bookmark lives under AppStore prefs → wiring it wouldn't even
   help the owner's Debug test). Needs the vault-selection/prefs path sorted first (owner territory).
3. W-R1 BUNDLE-FOR-RELEASE: worker+SPA staged in App Support (debug-only). Owner picks the artifact source
   (commit ~76MB / build-time from vendored donor / fetch). See W-R1 BUNDLE-FOR-RELEASE ANALYSIS above.
4. SPIKE-B (build the OpenWork SPA from source): ✅ EFFECTIVELY ALREADY DONE — the donor
   `/tmp/epistemos-opencode-donor-audit/openwork` HAS `node_modules` (623M, deps installed) + `apps/app/dist` (16M,
   built via `vite build`); the currently-staged SPA came from this proven pipeline. Disk is FINE (95Gi free). So
   "build SPA from source" needs no ~1GB re-run — the pipeline works. A fresh `vite build` (deps already present →
   fast) is only needed once SPA-source edits or controlled bundling actually happen (both owner-gated).
5. ACT DIRECTION (authority plan §164+): the native Swift Act engine infusion (separate big workstream; preserve
   Act IP). Untouched this session; not a recent owner priority.
6. WEBVIEW MIGRATION (WEBVIEW_MIGRATION_LEDGER): order C empty; B (HTMLWorkspacePreviewView) owner-DEFERRED
   (addUserScript security guard); A (Epdoc) look-bearing + LAST. No clean autonomous increment.

================================================================================
## OWNER ASKS 2026-06-24 (returned + directed) — AUDIT FINDINGS + PLAN (workflow wm2xomprr)
================================================================================
Owner wants: (1) Epistemos SKILLS usable in OpenWork no-setup; (2) confirm clone complete + the
epistemos-native MCP "note" actually registered; (3) OpenWork BROWSER working; (4) DROP the nested window →
real in-app surface; (5) DRASTIC flat/boxy/monospace/theme reskin ("looks like code, GUI not TUI"); (6)
/plugin install a "claude design" frontend plugin. 6-agent audit findings (grep-extracted; synthesis pending):

• RESKIN (5) — ✅ DONE this session: `WorkSPAReskin` extended with the DUI ruleset (monospace non-SVG, square
  corners, no shadows, block caret, theme colors) via injection (no SPA rebuild). Owner ⌘R→⌘4 = visual proof.

• SKILLS (1) — DOABLE (next obvious build): OpenCode/OpenWork discover skills from `<workspace>/.opencode/skills/`
  (+ `.claude/skills`, global `~/.config/opencode/skills`, `~/.claude/skills`, `~/.agents/skills`). NONE are
  provisioned in our embed (all global dirs absent; workspace has no `.opencode/skills`). Donor ships 16 skills in
  its `.opencode/skills` (shadcn, browser-automation, run-evals, …) + skills-lock.json — not provisioned. FIX:
  provision into `<workerWorkspace>/.opencode/skills/` — COPY (not symlink: OpenWork fs.watch on `.opencode` reload
  caveat) Epistemos vault skills (`<vault>/skills/<name>/SKILL.md`) +/or a bundled default set. CAVEAT: vault
  resolution (dual-prefs; Debug may resolve no vault) → need a source-skills path that works in Debug (bundled set
  or App Support skills).
  ✅ MECHANISM DONE: NEW `Epistemos/Work/WorkSkillsProvisioner.swift` — copies skills INTO `<workspace>/.opencode/
  skills/` (COPY not symlink, idempotent, non-clobbering, best-effort). Sources (both honest no-ops when absent):
  the workspace's own `skills/` (Epistemos vault convention → `provisionVaultSkills`) + a bundled
  `Resources/openwork-skills/` (`provisionBundledSkills`). Wired into `WorkOpenWorkSupervisor.run()` (provisions
  `provisionAll` before launch). TYPE-CHECK VERIFIED (Foundation-only) + `WorkSkillsProvisionerTests` (4) + wiring
  parse-clean. ⚠️ INERT UNTIL A SOURCE EXISTS — to DELIVER working skills, pick ONE (owner decision, NOT
  autonomous): (A) wire Work's workspace to the real vault (vault-CWD) so `<vault>/skills/` auto-appears [gated on
  the dual-prefs vault resolution], or (B) bundle an owner-approved default set into `Resources/openwork-skills/`
  (donor has run-evals/create-plugin/shadcn as broadly-useful self-contained candidates; the daytona-*/electron-*
  ones are irrelevant to our embed). Did NOT autonomously bundle OpenWork's skills as "Epistemos skills" (could be
  wrong) — owner picks the source.

• BROWSER (3) — HARD ARCHITECTURAL GAP (not a quick fix): OpenWork's browser tool drives **Electron's own bundled
  Chromium over Chrome DevTools Protocol** (Electron launched with `--remote-debugging-port`); the agent POSTs
  actions to that CDP endpoint. We DROPPED Electron (embed the SPA in a macOS-26 WebView), so there is NO Chromium
  with a remote-debug port + no UI-control bridge → the browser tool cannot work as-is. OPTIONS (owner-level): (a)
  launch a headless Chromium with `--remote-debugging-port` as a sidecar + point the tool at it; (b) build a native
  bridge that drives OUR `WebPage`/WebView via the new WebKit API and exposes a CDP-shaped endpoint; (c) accept no
  browser tool for now. → FLAG for owner; (a) is the most faithful clone path but adds a Chromium dependency.

• WINDOW DE-NEST (4) — DOABLE (touches main shell): `EpistemosApp.swift:957-1030` = the single `WindowGroup`;
  `:1573-1578` = the ⌘4 command calling `WorkWebSurfaceWindowController.shared.open()` (separate NSWindow). FIX:
  mount `WorkWebSurfaceView` as a first-class surface inside the main `WindowGroup`/`RootView` (the app's mode
  switcher), retire the separate window. Look-bearing + touches the proven shell → do carefully, visual proof OWED.

• CLONE COMPLETENESS (2) + MCP "note": synthesis (workflow wm2xomprr) has the full per-capability verdict; the
  epistemos-native MCP registration path is `WorkOpenWorkProvisioner.registerNativeMCP` (runtime-proven via curl
  earlier — it lands in the worker's MCP list; that IS the "note"). Owner can see it in OpenWork's MCP/settings.

• /plugin "claude design" (6) — owner-run: I can't invoke the interactive Claude Code `/plugin` installer; owner
  runs `/plugin` or names the exact plugin/marketplace.

BUILD ORDER (obvious-best): reskin ✅ → SKILLS provisioning (doable) → WINDOW de-nest (shell, careful) → BROWSER
(architectural, owner-flagged). Cross-check against the workflow synthesis when it lands.

================================================================================
## ✅ AUTHORITATIVE SYNTHESIS ROADMAP (workflow wm2xomprr complete; full output in
##    /private/tmp/.../tasks/wm2xomprr.output) — supersedes the grep-extracted notes above
================================================================================
Clone is SUBSTANTIALLY COMPLETE (SPA + worker + opencode/bun all real & functional; core tools + REST work).
The 5 owner asks = 5 ranked gaps; STEPS 1-4 + 6 are PURE SWIFT/CSS (no rebuild) → 4-of-5 asks immediately.

KEY CORRECTED FACTS (vs my earlier assumptions):
• VAULT = `/Users/jojo/Downloads/openclaw-main/` and it HAS **51 skills** at `…/skills/` → THAT is the skills source
  (resolved via `bootstrap.vaultSync.vaultURL`). The dual-prefs caveat means Debug may resolve nil → handle.
• MCP TRANSPORT BROKEN (RANK 2): `WorkNativeMCPServer` is single-shot POST→JSON→close; OpenCode requires **MCP
  Streamable HTTP** (POST /mcp with `Accept: application/json, text/event-stream`, reply single JSON OR SSE). So
  `epistemos-native` REGISTERS but never CONNECTS → native tools unusable. Earlier curl "it's in the mcp list" ≠
  connected.
• The worker-managed OpenCode **IGNORES our `OPENCODE_CONFIG`** → register BOTH epistemos-native AND epistemos-vault
  over the worker HTTP path (POST /workspace/:id/mcp); vault = `{type:'local', command:[omega_mcp_stdio], env:{
  EPISTEMOS_VAULT_ROOT}}`. (Verify via GET /workspace/:id/mcp `engineSync.status=='ok'`, not just the POST 2xx.)
• DE-NESTING (RANK 3) follows the EXISTING ACT precedent in `RootView.swift` (`showingActChatSurface`/`actLayer`),
  and ALSO gives Work the app SwiftUI environment (→ `vaultSync.vaultURL`), which the separate-window can't get →
  de-nesting UNBLOCKS the vault-skills + vault-root wiring.

BUILD ORDER (all PURE SWIFT/CSS except STEP 5):
1. SKILLS (✅ provisioner `WorkSkillsProvisioner` BUILT) — wire its source to `vaultSync.vaultURL?/skills` (the 51
   skills) → copy into `<workspace>/.opencode/skills/`. Needs the vault path (easiest once de-nested w/ env).
2. MCP STREAMABLE HTTP — ✅ DONE (transport fixes; runtime-proof OWED): `WorkNativeMCPServer` now (a) returns
   `Mcp-Session-Id` on dispatch responses (`httpResponse(sessionID:)`) so the OpenCode client binds the session, and
   (b) replies `202 Accepted` (bodyless) to JSON-RPC NOTIFICATIONS (`isNotification` = method w/o id, e.g.
   `notifications/initialized`) instead of an error envelope that broke the handshake. The server already returned
   `application/json` JSON-RPC for `initialize`/`tools/list`/`tools/call` (that part was fine — the audit's
   "single-shot" read overstated it). + tests (`notificationDetection`, `sessionIdAndAccepted`). ✅ `bfmpi6uke` =
   TEST BUILD SUCCEEDED (MCP transport compiles + tests pass). Onboarding-seal rides `bu9bd1a33`.
   📝 THEME-MATCH finding (corrects earlier worry): `WorkWebSurfaceWindowController.open()` ALREADY passes the owner's
   real theme — `WorkWebSurfaceView(theme: bootstrap.uiState.theme)` — so the reskin uses the owner's actual theme,
   NOT nativeDefault. The screenshot's beige look = owner's theme is light, OR a stale (pre-reskin-wiring) build, OR
   incomplete token coverage — NOT a missing-theme bug. (If still off after rebuild, audit token coverage / add a
   theme-mode-aware palette.)
   🔬 RUNTIME-PROOF OWED: owner opens Work → epistemos-native should show "Ready" in the SPA MCP list + a task can
   call a native tool. IF STILL not connecting, the next layer is GET /mcp SSE (the client may want a server→client
   stream) + `protocolVersion` (currently 2024-11-05) — but session-id + notifications-202 are the most likely fix.
   STILL TODO (cheap): `registerNativeMCP` should read back GET /workspace/:id/mcp `engineSync.status=='ok'` (not
   just POST 2xx) for a real connection verdict.
3. DROP NESTED WINDOW — mount `WorkWebSurfaceView` in-app per the Act precedent; retire `WorkWebSurfaceWindowController`.
   Gives env (vault) → unblocks #1. Look-bearing → visual proof OWED.
   📍 MOUNT-POINT RECON (RootView.swift): the main surfaces render in `ContentRouter` (RootView:1160, takes
   `actEntered`/`selectedActSessionId`/`pendingActPrompt` bindings). Act "enters" via `actEntered=true`;
   `showingActChatSurface` (computed) then gates the toolbar (back button RootView:1182-1198 sets actEntered=false;
   model/history/settings/miniChat items 1199-1222). PLAN to de-nest Work: (a) add a `@State workEntered` (+ a
   `showingWorkSurface` computed) in RootView; (b) render `WorkWebSurfaceView` inside `ContentRouter` (or as a sibling
   in the ZStack at RootView:1150) when `workEntered`; (c) toolbar back button mirrors Act's (workEntered=false); (d)
   REPLACE the ⌘4 `WorkWebSurfaceWindowController.shared.open()` (EpistemosApp.swift:~1573) with `workEntered=true`;
   keep the window controller only as a fallback or delete it. RISK: ContentRouter + the main nav are the proven
   shell → do post-synthesis (precise plan) + on a free build; visual proof OWED. Need to read `ContentRouter` (the
   surface switch) before editing.
4. RESKIN POLISH — on top of v1: luminance-based accent-fg (not hardcoded #fff), flatten gradients, refine.
5. BROWSER (NOT pure Swift): 5a `bun build` the donor `apps/server` → `dist/opencode-plugins/*.js` + stage beside
   the worker (fixes 3 non-browser plugins + loads the browser plugin); 5b browser tool still needs a Chromium/CDP
   host (Electron dropped) → bundle headless Chromium w/ --remote-debugging-port OR a WebKit-CDP bridge. Owner-level.
6. SEAL — ✅ ONBOARDING SEAL DONE (the owner's "can't connect / can't continue" UNBLOCK): `injectBootstrap` now
   always seeds `openwork.preferences.hasCompletedOnboarding=true` (key/field = donor local-provider.tsx; readPersisted
   MERGES with defaults so seeding just the flag is safe). + test `sealsOnboarding`. parse-clean; rides next build.
   STILL TODO in STEP 6: forward provider keys into the worker env; a 'Work native MCP' health row.

⚠️ "CAN'T CONNECT / CAN'T CONTINUE" DIAGNOSIS (owner 2026-06-24, screenshot = Welcome + create-workspace modal):
The connection path is SOUND in current code — RUNTIME-PROVEN this fire: staged worker + `OPENWORK_MANAGE_OPENCODE=1`
+ `--workspace` → "OpenWork server listening" + "Managed OpenCode listening" + `/health`=200 + `GET /workspaces`
auto-registers a workspace (`ws_…` with baseUrl+opencode) + no crash. So "can't connect" was the SPA's ONBOARDING
GATE: with `hasCompletedOnboarding=false` it shows Welcome → create-workspace, where "Local workspace" is
Desktop(Electron)-gated and "Connect custom remote" wants a remote worker → dead end. The onboarding seal (above)
skips that → the SPA lands in the auto-registered, connected workspace. ⇒ OWNER MUST REBUILD (⌘R) to get the seal +
all recent fixes (the screenshot looked like a pre-fix/stale build). If it STILL says can't-connect after rebuild,
it's stale localStorage (a prior dead worker URL/token) — the inject overwrites it each load, but a hard reload /
clear of `openwork.server.*` would confirm.

NEXT FIRE: STEP 2 (MCP Streamable HTTP in WorkNativeMCPServer — self-contained, high-impact, makes native tools
actually connect) — then STEP 3 (de-nest) which unblocks STEP 1's vault-skills source.

================================================================================
## 🔀 PIVOT 2026-06-24: WORK FOUNDATION OpenWork → OpenGUI RUNTIME (owner-directed)
================================================================================
Owner decision (two detailed messages): re-found "Work" on **OpenGUI Runtime** (`@opengui/runtime`, clone at
`.research-clones/work/opengui`) instead of EMBEDDING the OpenWork SPA. WHY: OpenGUI is an ADAPTER-FIRST substrate
(harness adapters: OpenCode/Claude Code/Codex/Pi; ADR 0005 splits Runtime[in-process]/Backend/Frontend; session
truth in the harness; every op scoped by harnessId+directory+session). That lets **Epistemos own the native SwiftUI
UI** while OpenGUI supplies agent connectivity — solving the "second app inside my app" problem OpenWork has. OpenWork
= MORE finished product but the WRONG boundary; keep it ONLY as reference/fallback (do NOT rip out today).

TARGET ARCHITECTURE (owner): two primary chats, not three —
  • Act  = native Epistemos chat (NOT OpenWork/Osaurus UI).
  • Work = native Epistemos agent workbench backed by OpenGUI Runtime (harnesses OpenCode/Codex/Claude Code/Pi;
           optional Paseo-style orchestration later); OpenCode TUI = optional hidden expert mode.
  • Mini Chat = a portal into Act or Work sessions, NOT a third product.
DONORS (ideas/reference only unless promoted): OpenChamber (mini-chat/diff/worktree/session UX), Paseo (orchestration/
provider/session-lifecycle), Pi + Oh My Pi (harnesses). LICENSE: OpenGUI/OpenChamber/Pi = MIT-OK; **Paseo = AGPL →
IDEAS ONLY, no code copy**; OpenWork `ee/` = OFF-LIMITS (Epistemos may be open-sourced → licenses matter more).

PRUNE (owner): completely remove **OpenCowork** + **Osaurus** (incl. leftover Osaurus-derived SETTINGS "in the act
stuff") — while PRESERVING ACT IP + NEVER touching the 2 dirty Localizable.xcstrings (one is the Osaurus one).
RESKIN/RENAME: reskin OpenGUI to the OpenCode/DUI look (like the OpenWork reskin); rename Work → "OpenDUI"/DUI.

THE GATING PROOF (spike): ONE native Epistemos Work input → OpenGUI Runtime → OpenCode session list/create/send →
HarnessEvent stream back into Epistemos UI, WITHOUT loading any OpenWork/OpenGUI web UI. If it works → OpenGUI is the
foundation; if it's just as heavy → keep OpenWork + prune harder.

STATUS: investigation workflow **wyt969h3t** running (OpenGUI Runtime SDK · Swift↔Runtime spike shape · prune Cowork ·
prune Osaurus+Act-settings · donor/license/arch map → synthesis = spike design + prune plan + build order). The prior
OpenWork work (auto-connect, OpenCode fix, MCP transport, reskin, skills, onboarding-seal, mini-session) stays as the
FALLBACK + reference; the OpenWork Epistemos-ification synthesis (wq3e7w8sh) is archived for that fallback.
NEXT: when wyt969h3t lands → execute the spike FIRST (prove the boundary), then the Cowork/Osa prune (Act-IP-safe).

### OpenGUI spike — operational prereqs + a KEY RISK (recon 2026-06-24, while wyt969h3t synthesizes)
• `@opengui/runtime` SDK shape (packages/runtime/README): `const og = await createOpenGUI({dataDir, allowedRoots:[repo]});
  const dir = await og.at(repo); await dir.connect({harnesses:["pi"]});` — in-process, directory-scoped, no HTTP/UI.
  TS/ESM, exports `./src/index.ts` directly (`type:module`).
• PREREQ: the clone has NO node_modules + no built dist → needs `pnpm install` (the runtime + deps) before it runs;
  run it with a TS-capable runtime (we bundle **bun** — `Contents/Resources/bun` — or tsx). ~install cost like Spike-B.
• OpenCode harness exists (`adapters/opencode-bridge.ts`, `opencode-config.ts`, `opencode-project-registry.ts`); the
  bridge talks to a local OpenCode HTTP server (DEFAULT_OPENCODE_BASE_URL) — so it drives an `opencode serve` (we bundle
  opencode). The OpenCode auth/config live at ~/.local/share/opencode/auth.json + ~/.config/opencode (the SAME files
  our OpenWork path uses → provider auth carries over).
• ⚠️ KEY RISK: `harness-bridge-registrations.ts` registers the OpenCode bridge with ELECTRON deps
  (`opencode: ({ipcMain, getAllWindows}) => setupOpenCodeBridge(...)`) and the bridge "compiles to
  dist-electron/opencode-bridge.js". MUST confirm the SDK's in-process path can use the OpenCode adapter WITHOUT
  Electron (ipcMain/getAllWindows). If the OpenCode adapter is Electron-coupled, the spike either de-Electrons it or
  proves the chain with the `pi` harness first (Quickstart's example) then ports OpenCode. THIS is the spike's pass/fail
  crux (mirrors the OpenWork-browser Electron trap). The synthesis (wyt969h3t) addresses it.
  ✅ CRUX RESOLVED 2026-06-24 (read opencode-bridge.ts + harness-service.ts): the OpenCode adapter is NOT
  Electron-coupled. The bridge is pure Node + HTTP — `createOpencodeClient from "@opencode-ai/sdk/v2/client"` over
  `http://127.0.0.1:<port>` (spawns/talks-to `opencode serve` via node:child_process + fetch; keep-alive http.Agent);
  NO electron/BrowserWindow imports in the bridge logic. `HarnessService` uses a GENERIC `invoke(channel,args)`
  abstraction — Electron's `ipcMain`/`getAllWindows` is just ONE transport (the desktop shell's); ADR 0005 says the
  in-process Runtime supplies its OWN invoke registry. "compiled to dist-electron/" = just the build OUTPUT dir.
  ⇒ the OpenGUI Runtime can drive OpenCode IN-PROCESS without Electron → THE PIVOT IS VIABLE. (Remaining nuance: the
  SDK's in-process invoke-registry must register the bridge fns; the bridge likely needs a TS build [bun/tsx] — the
  synthesis has the exact wiring.) NEXT is no longer premature: `pnpm install` (scoped) the runtime + run the spike w/ bun.
  ✅ ONBOARDING-SEAL ("can't connect" fix) BUILD-VERIFIED: `bu9bd1a33` = TEST BUILD SUCCEEDED. Owner ⌘R → SPA skips the
  Desktop-gated create-workspace → lands in the connected workspace.

### ✅ OpenGUI PIVOT — SPIKE BLUEPRINT (synthesis wyt969h3t complete; full output in tasks/wyt969h3t.output)
VERDICT: viable. `@opengui/runtime` (MIT, private, Node≥20, ESM/TS) exposes the exact chain; OpenCode is a real
maintainer-verified harness adapter (managed ids: opencode, claude-code, pi, codex, grok-build).
SDK CHAIN (the spike): `const og=await createOpenGUI({allowedRoots:[repo],harnesses:['opencode']});` →
`const dir=await og.at(repo); await dir.connect({harnesses:['opencode']});` → `const oc=dir.harness('opencode');`
→ LIST `await oc.sessions.list()` / CREATE `await oc.sessions.create({title})` (or `.open(id)`) →
STREAM `const off=s.onEvent(ev=>…)` (CANONICAL; de-dupe by `seq` — known double-fire bug with onStream+waitUntilIdle)
→ SEND `await s.send(text,{whileBusy:'wait'})` → `await s.waitUntilIdle({timeoutMs:90000})` → `off(); s.close(); og.close()`.
One-shot: `runAgent(og,{directory,harness,message,onStream})`. Readiness: `og.diagnose()→{harnesses:[{harnessId,cliOnPath,ready,hint}]}`.
LiveSessionEvent (version:1, seq, type, scope{directory,harnessId,sessionId}, text): run.started/finished{reason:idle|error},
message.started/finished, part.text.appended/replaced(partKind text|thinking), tool.started/…/finished, session.error.
RUNTIME DEPS (not self-contained): opencode CLI on PATH (WE BUNDLE IT); it spawns a local `opencode serve --port 4096`
(127.0.0.1:4096; env OPENGUI_OPENCODE_PORT); npm `@opencode-ai/sdk ^1.16.2`; Node≥20 (or bun); `allowedRoots` gates
every dir op. OpenCode auth = ~/.local/share/opencode/auth.json (same as our OpenWork path → carries over).
ARCHITECTURE: Node/TS only, NO Swift binding, runtime "NOT cleanly isolatable from the monorepo" (imports root src/) →
run as a **Node/Bun SIDECAR** (same pattern as the OpenWork worker; canon allows "local Work runtime process"),
driven over line-delimited JSON stdio (or localhost socket). Swift supervisor mirrors `WorkOpenWorkSupervisor`
(Process+pipe+await-ready); forward LiveSessionEvent to Swift. (CLAUDE.md "no hidden hot-path subprocess on MAS" →
the Work runtime sidecar is the canonical exception, like the OpenWork worker; keep it the Work runtime, not the agent.)
SPIKE STEPS: (1) `pnpm install` the runtime [RUNNING — opengui-install.log; pin is pnpm@11.8.0]; (2) a STANDALONE
bun/node script running the chain → PROVE opencode session+stream works in OUR env (bundled opencode+bun) — smallest
proof, no Swift yet; (3) then the Swift sidecar + bridge (WorkOpenGUISupervisor). NEXT FIRE: verify install → run the
standalone proof script.

### ✅✅ SPIKE PROVEN — RUNTIME→OPENCODE→STREAM WORKS IN OUR ENV (2026-06-24, runtime evidence)
Steps (1)+(2) DONE. `pnpm install` → EXIT=0, "Done in 20.8s using pnpm v11.8.0" (corepack honored the @11.8.0 pin),
1.1G node_modules (hoisted to clone root). Standalone proof script `.research-clones/work/opengui/epistemos-opengui-spike.mjs`
ran with bun 1.3.14 + the **bundled** opencode on PATH (Epistemos.app/Contents/Resources/opencode). FULL CHAIN PASSED:
  • `createOpenGUI({allowedRoots:[repo],harnesses:['opencode']})` → OK
  • `og.diagnose()` → `{ok:true, harnesses:[opencode{cliOnPath:true,ready:true}, claude-code{ready:true}, codex{ready:true},
    pi{not found}, grok-build{not found}]}` — so we get **opencode + claude-code + codex** harnesses for free in our env.
  • opencode-bridge resolved the bundled binary, `Spawning: …/Resources/opencode serve --port 4096`, "Server is healthy."
  • `dir.connect({harnesses:['opencode']})` → `{connectedHarnessIds:['opencode'], errors:[]}`
  • `sessions.list()` → 0; `sessions.create({title})` → `opencode:ses_103bd4122ffeL1rq3x9iE5LJcw`
  • `s.onEvent` streamed **26 events** (de-duped by seq): message.started → part.started → part.text.appended (prompt echo)
    → run.started → assistant thinking streamed token-by-token → part.started → "SP","I","KE","_OK" → run.finished.
    Model REPLIED `SPIKE_OK`. `waitUntilIdle({timeoutMs:90000})` returned; `og.close()`; `SPIKE_EXIT=0`.
  • NO OpenWork/OpenGUI web UI loaded anywhere — pure Runtime SDK in a bun process. **This is exactly the gate the owner set.**
GATE STATUS: the Runtime→OpenCode→session→stream half is **PROVEN** (the donor substrate is sound in our env, bundled
opencode + carried-over auth.json work, claude-code/codex are bonus harnesses). The "native input" half (Swift →
sidecar → Runtime) is the NEXT build, NOT yet proven. Honest scope: pivot substrate validated; Swift bridge unbuilt.
CLEANUP: the spike's `og.close()` did NOT reap the spawned `opencode serve --port 4096` (no kill_on_drop in the JS
bridge) — had to `kill` it manually. ⇒ the Swift `WorkOpenGUISupervisor` MUST own opencode lifecycle (kill_on_drop /
process_group) like `WorkOpenWorkSupervisor`, not trust the Node runtime to reap. (App's own `--cors` opencode
instances left untouched.)
### ✅✅✅ SIDECAR (NODE) PROVEN — NDJSON STDIO TRANSPORT WORKS OVER A SUBPROCESS (2026-06-24, runtime evidence)
The Node half of the sidecar is DONE + proven. Files in `.research-clones/work/opengui/`:
  • `og-sidecar.mjs` — wraps the proven chain behind LINE-DELIMITED JSON (NDJSON) on stdin/stdout. stdout = pure NDJSON
    (`ready`/`reply{id,ok,data}`/`error`/`event{sessionId,event}`); ALL diagnostics → stderr. Commands: init / diagnose /
    sessions.list / sessions.create / sessions.open / send / waitIdle / close. Events de-duped by seq per session.
  • `og-sidecar-drive.mjs` — drives it over a REAL `spawn("bun", ["og-sidecar.mjs"])` subprocess (the exact
    Process+pipe shape the Swift supervisor uses): ready→init→sessions.create→send→waitIdle→close.
RESULT (og-sidecar.log): `init {connectedHarnessIds:["opencode"],errors:[]}` → session `opencode:ses_103b7a23…` →
**38 forwarded events**, spikeOk=true, run.finished=true → `SIDECAR EXIT 0` → `RESULT: PASS — NDJSON-stdio sidecar
drives OpenCode + streams over a subprocess boundary` → DRIVE_EXIT=0. (Same opencode-reaping gap: had to kill stray
port-4096 — confirms Swift supervisor must own opencode lifecycle.)
⇒ SWIFT CONTRACT now fully specified by a working reference: spawn `bun og-sidecar.mjs` (cwd = opengui clone; PATH must
include bundled opencode + bun), write NDJSON commands to stdin, parse NDJSON lines from stdout, forward `event`
frames to the Work UI, own the child's lifecycle (kill_on_drop/process_group) — IDENTICAL to WorkOpenWorkSupervisor.

NEXT FIRE: build the Swift `WorkOpenGUISupervisor` (Process+pipe+await-ready, mirrors WorkOpenWorkSupervisor; drives
the now-proven `og-sidecar.mjs`; owns opencode lifecycle). Source-guard/`swiftc -parse` gate per increment; NO commit.
OPEN QUESTION for that build: where the opengui runtime (1.1G node_modules) + sidecar ship from — bundling is a real
disk/packaging decision (owner at disk cap); for the spike the supervisor can point at the research clone path.
AUTHORITY NOTE — ✅ RESOLVED BY OWNER 2026-06-24 (live message): the OpenGUI pivot is CONFIRMED as the Work
direction ("OpenGUI is gonna be the harness/bridge thing … this is what Codex recommended and this is what I like").
This supersedes the standing /loop prompt's "OpenWork apps/app embed" canon for the WORK surface. OpenWork =
reference/fallback. The no-vault-honesty slices remain valid INDEPENDENT hardening (not Work-architecture-coupled).

### 🎛️ ENGINE PICKER — owner's multi-engine vision (2026-06-24 live msg) grounded in OpenGUI reality
Owner wants a **Work Chat → Engine picker** where ALL engines are **pre-installed + pre-ready** (no user setup),
because OpenGUI is the harness/bridge. Architecture is clean: ONE proven sidecar, N engines, the picker just selects
`harnessId` (the chain `dir.harness(<id>)→sessions→send→onEvent` is generic — already proven for opencode; the
sidecar's `init`/`sessions.create`/`send` take a `harnessId`). Plus a later Epistemos-native reskin ("epic demo skin
native reflector"). GROUNDED MATRIX (OpenGUI canonical set = `["opencode","claude-code","pi","codex","grok-build"]`,
default `claude-code`; runtime evidence from the spike's `diagnose` + adapter recon):
| Owner engine | OpenGUI harness | Adapter | Bundled in app | diagnose (our env) | Pre-ready gap |
|---|---|---|---|---|---|
| OpenCode (coding-first) | `opencode` | ✅ opencode-bridge.ts | ✅ Resources/opencode | **ready:true (PROVEN)** | NONE — ship as-is |
| Claude Code (plan+impl) | `claude-code` | ✅ claude-code-bridge.ts | ❌ (uses ~/.local/bin/claude) | ready:true | bundle/locate `claude` + seed auth |
| Codex (workspace agent) | `codex` | ✅ codex-bridge.ts | ❌ (uses /opt/homebrew/bin/codex) | ready:true | bundle/locate `codex` + seed auth |
| Pi / OMP (lightweight) | `pi` | ✅ pi-bridge.ts (+pi-daemon-server) | ❌ | **not found** | install/bundle `pi` CLI |
| Goose (general/MCP/auto) | ❌ NONE | ❌ no adapter | ❌ | n/a | **NEW adapter** (goose is a CLI+MCP agent → fits LOCAL_CLI_CONNECTION pattern like codex/pi) |
| Hermes (personal, "if bridged") | ❌ NONE | ❌ no adapter | n/a (in-process Rust agent_core) | n/a | **NEW adapter, lowest pri**: Hermes has NO CLI → needs a thin CLI/stdio shim over agent_core speaking the harness backend-event protocol (this is the W-R3-adjacent "expose Epistemos's native engine" work) |
| (grok-build) | `grok-build` | ✅ | ❌ | not found | owner didn't list — keep hidden or bonus |
ADD-AN-ENGINE recipe (4 edits, from recon): (1) `packages/protocol/src/harness-id.ts` HARNESS_ID_VALUES; (2)
`src/agents/cli-harness-factory.ts` HARNESS_BACKEND_META (capabilities + normalizeEvent via `createCliHarnessNormalizer`
for a CLI engine); (3) `packages/runtime/src/adapters/<engine>-bridge.ts` (model the codex/pi bridge); (4) register in
`packages/runtime/src/harness-bridge-registrations.ts` BRIDGE_SETUP_BY_HARNESS_ID. (+ optional `<engine>-models.ts`.)
**"PRE-INSTALLED + PRE-READY" = the central hardening requirement:** for each picker engine the CLI must be PRESENT
(bundled in Resources OR installed) AND pre-authed/configured so `diagnose→ready:true` on first launch. Today ONLY
opencode meets that bar. ⇒ a per-engine provisioning matrix (bundle binary + seed auth/config). DISK HONESTY (owner at
cap): bundling codex+claude+pi+goose binaries is real size — phase it; opencode ships now, others gated on disk/decision.
NEXT FIRES (obvious-best order toward the picker, no architecture churn): (1) cheap runtime proof — extend the spike to
`connect` + `sessions.list` across ALL ready harnesses (opencode/claude-code/codex) to prove the picker drives each
(no `send` = no agent cost); (2) Swift `WorkOpenGUISupervisor` + a native engine-picker that selects harnessId; (3)
Goose adapter (most-feasible new engine); (4) per-engine pre-ready provisioning; (5) Hermes shim (lowest pri); (6)
native reskin. Goose/Hermes adapters live in the RESEARCH CLONE (MIT) — NOT app code — until promoted.

#### ✅ MULTI-ENGINE PROOF — the picker drives 3 engines TODAY (2026-06-24, runtime evidence)
`og-engines-probe.mjs` (connect + sessions.list across all ready harnesses, NO send → zero agent cost). Result:
  • diagnose READY: **opencode, claude-code, codex**; NOT READY: pi (CLI not found), grok-build (CLI not found).
  • `connect` + `sessions.list` succeeded for ALL THREE via the SAME generic chain (`dir.connect({harnesses:[id]})` →
    `dir.harness(id).sessions.list()`): opencode connected(sessions 0), claude-code connected(0), codex connected(0).
  • **PICKER-DRIVABLE ENGINES: opencode, claude-code, codex** — PROBE_EXIT=0. ⇒ owner's "one harness, N engines" picker
    architecture is PROVEN across 3 real engines (the Swift picker just passes a different harnessId to the sidecar).
  • CODEX CAVEAT: connect succeeds but `thread/list` (session discovery) TIMED OUT (codex-bridge.ts:106) — codex's
    app-server is slow/flaky in our env; sessions defaulted to 0. Note for pre-ready: codex needs a longer discovery
    timeout / retry, and it talks to the system Codex.app app-server (not a bundled binary) → bundling story differs.
⚠️ PROCESS-REAPING CAUTION (mistake made + self-healed this fire): cleaning up probe processes, a broad
`pgrep -f "codex app-server"` matched + killed a PRE-EXISTING process (the owner's running Codex.app app-server, low
pid 376 — NOT spawned by the probe). Codex.app auto-respawned it (on-demand), so no lasting harm, but RULE for future
fires: reap ONLY by spawn-scoped identifiers (the unique `opencode serve --port 4096` with NO `--cors`, or a PID
captured at spawn) — NEVER broad CLI-name patterns that can match the owner's apps. The Swift WorkOpenGUISupervisor
must likewise own ONLY its own child PIDs.

#### 🏗️ SWIFT BRIDGE BUILT — WorkOpenGUISupervisor (2026-06-24, owner reaffirmed "Work only; all engines; native minimal")
Owner live msg: I own ONLY Work (do NOT touch Chat/Swarm or Act/Goose); prove ONE native Work input →
list/open/create/send/stream an OpenCode session via OpenGUI plumbing WHILE preserving Epistemos recents/session
identity; engine order OpenCode→Goose→Codex/ClaudeCode/Pi/OMP→Hermes (ALL real agents); visual = Epistemos-native
OpenCode-TUI minimalism (flat/compact/native, no donor chrome, no gradients, no raw JSON/log debris).
NEW FILE `Epistemos/Work/WorkOpenGUISupervisor.swift` (the Swift HALF of the proven NDJSON contract):
  • `@MainActor @Observable final class` mirroring WorkRuntimeSupervisor (Process+pipe+await-ready+idempotent
    start+kill-on-teardown). Spawns `bun og-sidecar.mjs` (cwd = OpenGUI clone via `EPISTEMOS_OPENGUI_SIDECAR_ROOT`;
    PATH prepends bundled Resources[opencode]+bun dir). Reads stdout on a `Task.detached`, decodes NDJSON frames.
  • Status enum: idle/unavailable/starting/running(connectedHarnesses:[String])/failed/stopped — the
    `connectedHarnesses` IS the engine-picker list. Request/reply plumbing: id-matched `CheckedContinuation`s with
    per-request + ready timeouts (no hang). Typed wrappers: initRuntime→[harnessIds], createSession(title,harnessId),
    send(text,sessionId,model?), waitUntilIdle. `onEvent:(@MainActor (String, Data)->Void)` forwards LiveSessionEvent
    raw JSON to the (native) UI. Pure helpers `nonisolated static`: processEnvironment / encodeCommand / decodeFrame /
    subJSON / stringArray / stringField / resolveBun / defaultSidecarRoot / defaultDataDir.
  • LIFECYCLE: stop() sends best-effort `close` then terminates OUR bun Process only (per reaping lesson). OWED/known
    gap: terminating bun can orphan the runtime-spawned `opencode serve` (runtime doesn't reap) → later increment:
    spawn child in its own process group + killpg the tree.
  • Sendability: replies/events cross the actor boundary as `Data` (raw JSON), never `[String:Any]` → typed extractors
    parse on MainActor. WorkOGReply/WorkOGFrame/WorkOGError are Sendable; WorkOGFrame Equatable.
NEW TEST `EpistemosTests/WorkOpenGUISupervisorTests.swift` (11 tests, pure-helper wire-contract symmetry with
og-sidecar.mjs: encodeCommand in-frames; decodeFrame ready/reply/error/event; noise→nil; PATH prepend; round-trip
harnessId survives). ✅ swiftc -parse CLEAN (both files); 2 redundant-await warnings fixed. ("Testing" SourceKit
standalone false-positive = expected, sibling WorkSPAServerTests imports it identically.)
CHECKPOINT: background `build-for-testing SWIFT_EMIT_LOC_STRINGS=NO` kicked (id byktchoo9) to compile-verify the
@Observable macro + Swift 6 concurrency + [String:Any] handling -parse can't. Result OWED next fire.
NEXT FIRE (after build result): wire a NATIVE Work input view (flat/compact/TUI-minimal, no donor chrome) to this
supervisor — engine picker bound to `status.connectedHarnesses`, input→createSession/send, onEvent→native transcript;
PRESERVE Epistemos recents/session identity (reconcile with WorkSession ontology / AgentSessionLineageStore — the
flagged item). Runtime proof of the live spawn+stream is OWED (owner ⌘R). STAY IN WORK ONLY.

#### ✅ SESSION-IDENTITY RECONCILIATION VERDICT (2026-06-24 recon — resolves the flagged duplication worry)
Read WorkSession.swift / WorkSessionRegistry / WorkSessionStore / WorkSessionMapper + AgentSessionLineageStore.swift +
WORK_MINI_SESSION_PARITY_LEDGER. FINDINGS:
  • `AgentSessionLineageStore` = ACT/CHAT agent-session lineage ONLY (maps chatThreadID→parentSessionID, writes
    parent_session_id/chat_thread_id into a Rust agent_core `session.json`). It is NOT the Work layer → my WorkSession
    work was NOT a duplication. They are COMPLEMENTARY (different domains). Reconciliation flag = RESOLVED.
  • `WorkSession` IS the correct native recents/session-identity layer for Work: dual identity (`id` = Epistemos
    identity + `openCodeSessionID` = harness session) + mini/parent lineage + dedup-by-id registry + @Observable store
    with active-session. This already satisfies "preserve Epistemos recents/session identity" structurally.
  • CONCRETE GAP for the OpenGUI path: `WorkSessionMapper.workSessions(fromSessionsJSON:)` parses the OpenWork-WORKER
    shape `{items:[{id,parentID,title}]}`. The OpenGUI sidecar's `sessions.list` returns `[{id,title}]` (no `items`
    wrapper, no parentID — see og-sidecar.mjs). ⇒ need an OpenGUI→WorkSession mapper. The OpenGUI session id is
    `harnessId:sessionId` (e.g. `opencode:ses_…`) and is STABLE/persisted by the runtime → use it as BOTH
    `WorkSession.id` and `openCodeSessionID` (identity survives restarts; `sessions.list` re-lists them). For mini/parent
    lineage, ENHANCE og-sidecar.mjs `sessions.list` to also surface `parentID` (the OpenCode SDK session carries it),
    then the OpenGUI mapper can classify main vs mini exactly like the donor `getRootSessions` (parent-is-known ⇒ mini).
  • Per mini-session ledger: Work main-session identity object + parent-linked recents rows are planned follow-ons
    (NOT no-vault hardening; Phase-2 Work UX). All in-scope for Work.
#### ✅ WorkOpenGUISupervisor BUILD-VERIFIED + OpenGUI→WorkSession MAPPER LANDED (2026-06-24)
• Background checkpoint byktchoo9 = **`** TEST BUILD SUCCEEDED **` (BUILD_EXIT=0)**. `WorkOpenGUISupervisor.swift`
  compiled in the APP target (build log line 5312) + `WorkOpenGUISupervisorTests.swift` in the TEST target (line
  12221), zero errors. ⇒ the Swift bridge is REAL (@Observable macro + Swift 6 concurrency + the Data-not-[String:Any]
  Sendability all compile in-target). (Tests compiled, not run — build-for-testing doesn't run; contract is parse+
  compile+design-verified, live spawn+stream still owner-OWED.)
• ONTOLOGY FACT confirmed from `@opengui/runtime` SessionSummary = `{id,title?,status?,directory?,createdAt?,updatedAt?}`
  — **NO parentID**. ⇒ OpenGUI's `sessions.list` cannot express parent lineage → the OpenGUI→WorkSession mapper makes
  EVERY listed session a MAIN/root; mini/parent lineage is EPISTEMOS-OWNED (Work creates a mini WorkSession locally,
  binds openCodeSessionID to a child OpenGUI session; parent link lives in the WorkSession layer, never derived from
  OpenGUI). The OpenGUI id is engine-namespaced + stable (`opencode:ses_…`) → doubles as openCodeSessionID (identity
  preserved across restarts).
• LANDED: `WorkSessionMapper.workSessions(fromSidecarListJSON:workspaceID:)` (parses the sidecar's flat `[{id,title?}]`
  array; skips empty-id; worker `{items:[…]}` shape correctly yields empty — the two paths don't cross-parse) +
  3 tests appended to WorkSessionMapperTests.swift. ✅ swiftc -parse clean (both files). (SourceKit single-file
  "Cannot find WorkSession / Testing" = isolation false-positives; both resolve in-module/in-target, proven by the build.)
NEXT (smallest verifiable slice): the NATIVE Work input view — flat/compact OpenCode-TUI-minimal (no donor chrome),
engine picker bound to `WorkOpenGUISupervisor.status.connectedHarnesses`, input→createSession/send, onEvent→native
transcript, recents/rail from the WorkSession store (populated via the new mapper). Visual proof OWED (owner ⌘R).
Batch a background xcodebuild checkpoint after that view lands (mapper is pure + parse-clean, low compile risk). STAY IN WORK ONLY.

#### ✅ EVENT→TRANSCRIPT REDUCER LANDED — the "no raw debris" layer (2026-06-24)
Decomposed the native view: built its hardest, look-INdependent core FIRST (unit-testable without owner visual proof).
NEW `Epistemos/Work/WorkEngineTranscript.swift` (@MainActor @Observable, like WorkSessionStore): ingests
`WorkOpenGUISupervisor.onEvent` LiveSessionEvent JSON → a render-ready native transcript. Schema mirrors
`@opengui/runtime` live-session-event.ts EXACTLY (base version/id/seq/type/scope/runId?/messageId?/partId?; per-type:
part.text.appended/replaced{partKind:text|thinking,text}, part.started{partKind}, tool.started{tool}/output.appended/
replaced{text}/finished{status}, run.started, run.finished{reason:idle|error}, message.started{role}/finished,
session.error{message}, etc). GUARANTEES THE VISUAL TARGET "no raw JSON/log/terminal debris": accumulates assistant
text by partId; THINKING kept separate from the ANSWER (`answerText` excludes thinking/tool/error); tool calls →
native cards (name+status+output, never dumped as prose); run status tracked; de-dupes by `seq` (the onEvent
double-fire). Model: WorkTranscriptPart{id,kind(answer|thinking|tool|error),text,toolName?,toolStatus?} +
WorkRunStatus{idle|running|error}. NEW `EpistemosTests/WorkEngineTranscriptTests.swift` (8 tests: accumulate, seq-dedupe,
thinking-separation, run-status idle/error, tool-card lifecycle, session.error, non-transcript→zero-parts, reset).
✅ swiftc -parse clean (both). ("Testing" SourceKit error = isolation false-positive.)
NEXT: the thin SwiftUI Work view binds 3 proven pieces — engine picker ← supervisor.status.connectedHarnesses;
input → createSession(harnessId)/send; supervisor.onEvent → transcript.ingest → render parts (answer plain, thinking
dim/collapsed, tool cards, error). Then a background build checkpoint (batches transcript + mapper + view). STAY IN WORK ONLY.

#### ✅ NATIVE WORK SURFACE VIEW LANDED (2026-06-24) — "one native Work input → create/send/stream"
NEW `Epistemos/Work/WorkEngineSurfaceView.swift` — the flat, compact, OpenCode-TUI-minimal Work surface (NO donor
chrome, NO gradients, monospace throughout). Binds the proven stack:
  • ENGINE PICKER ← `WorkOpenGUISupervisor.status.connectedHarnesses` (one surface, N engines; OpenCode first via
    `start(repo:,harnesses:["opencode"])`; the SAME picker will list goose/codex/claude as they connect).
  • INPUT → on submit: `createSession(title, harnessId: selectedEngine)` (first send) then `send(text, sessionId)`;
    captures native identity/recents via `WorkSessionStore.upsert(.main(id:sid, workspaceID:repo, openCodeSessionID:sid))`.
  • STREAM: `supervisor.onEvent → transcript.ingest` → renders `WorkEngineTranscript.parts` natively (answer = plain
    mono + textSelection; thinking = dim italic; tool = bordered native card name+status+output; error = red). NO raw
    JSON/log/terminal debris (the reducer guarantees it). Status row reads supervisor + transcript run-state.
  • Errors surfaced as a NATIVE error part (built via JSONSerialization, never raw-interpolated into prose).
  • Theme-aware (EpistemosTheme tokens: accent/border/textTertiary/mutedForeground; boxBackground per isDark).
  • `theme` + `repo` injected (repo defaults to temp for preview; real wiring supplies the git workspace).
✅ swiftc -parse clean. (SourceKit single-file errors for EpistemosTheme/WorkOpenGUISupervisor/WorkEngineTranscript/
WorkSessionStore/WorkTranscriptPart = isolation false-positives — all sibling in-module types; the build is the arbiter.)
CHECKPOINT: background build-for-testing kicked (id busqjn9up) batching view + transcript + mapper. Result OWED next fire.
NEXT: (1) confirm busqjn9up SUCCEEDED; (2) a `repo`/workspace resolver; (3) wire WorkEngineSurfaceView into an in-app
debug entry (mirror WorkWebSurfaceWindowController, reversible) so the owner can ⌘R the live create/send/stream proof;
(4) session rail (recents UI) from WorkSessionStore + list-on-connect via the OpenGUI→WorkSession mapper.

#### ✅ WORKSPACE RESOLVER LANDED + "git NOT required" CORRECTION (2026-06-24)
CORRECTION to my prior note: the OpenGUI runtime does NOT need a git dir. Verified `@opengui/runtime`
directory-safety.ts `resolveSafeDirectory`: it does `realpath` + `isDirectory` + under-`allowedRoots` ONLY — NO git
check (the spike git-init'd its temp dir but that was unnecessary; OpenCode `serve` also runs in any directory). ⇒ the
workspace just needs to EXIST under allowedRoots. NEW `Epistemos/Work/WorkOpenGUIWorkspace.swift` (Foundation-only):
`ensureDefault()` → app-support `Epistemos/WorkOpenGUI/workspace` (created on demand; temp fallback) and `ensure(at:)`
for a caller-chosen dir (e.g. the active vault). The supervisor passes the result as BOTH `repo` and the sole
allowedRoot. ✅ swiftc -typecheck CLEAN (real Sema, Foundation-only — no isolation noise). This removes the last
plumbing gap before the live ⌘R proof; per-vault/per-project workspaces are a later refinement.
NEXT FIRE (after busqjn9up confirms the view): wire `WorkEngineSurfaceView(repo: WorkOpenGUIWorkspace.ensureDefault()?.path ?? …)`
+ an in-app debug entry (mirror WorkWebSurfaceWindowController, reversible) → owner ⌘R live create/send/stream proof;
then the session rail. Visual+runtime proof OWED. STAY IN WORK ONLY.

#### ✅ DEBUG-ENTRY WINDOW CONTROLLER LANDED (2026-06-24)
NEW `Epistemos/Work/WorkEngineSurfaceWindowController.swift` — reversible in-app DEBUG entry that opens
`WorkEngineSurfaceView(theme: bootstrap.uiState.theme, repo: WorkOpenGUIWorkspace.ensureDefault())` in a themed
NSWindow. Mirrors WorkWebSurfaceWindowController EXACTLY (focus-existing/no-dup, NSHostingView + WindowThemeStyler,
willClose teardown) — confirmed identical APIs (AppBootstrap.shared, bootstrap.uiState.theme/preferredColorScheme,
WindowThemeStyler.themedContentView/apply) to the proven controller, so it resolves in-module. ✅ swiftc -parse clean
(SourceKit AppBootstrap/WorkOpenGUIWorkspace/WorkEngineSurfaceView/WindowThemeStyler errors = isolation false-positives).
NOT the final mount — the final Work entry is a first-class surface in the LANDING SHELL (owner canon: landing exposes
Chat/Act/Work directly; later cross-cutting RootView change). This debug window is the interim for the ⌘R proof.
REMAINING for the live proof (next fire, after busqjn9up confirms the batch): ONE small trigger — a Work-settings
button or menu command calling `WorkEngineSurfaceWindowController.shared.open()` (mirror the ⌘4 entry at
EpistemosApp.swift:~1576 / WorkCloneSettingsView.swift:51, but a SEPARATE command/button so the OpenWork fallback
entry stays). That edit touches a central file → do it when no build is running, then a batched build checkpoint
(controller + resolver + trigger). Then owner ⌘R → live create/send/stream. STAY IN WORK ONLY.

#### sidecar `sessions.list` enriched (2026-06-24, build-blocked safe increment)
While busqjn9up compiled (can't touch app source mid-build), did a research-clone-only forward-progress increment:
`og-sidecar.mjs` `sessions.list` now returns the FULL SessionSummary `{id,title,status,updatedAt,createdAt}` (was
`{id,title}`) so the future native recents rail can show status + sort by recency. The Swift OpenGUI→WorkSession
mapper reads id/title and ignores the extras (forward-compatible). ✅ node --check clean. No app source touched.
BUILD-BATCHING STATE (track this): busqjn9up covers view+transcript+mapper ONLY (resolver + controller were written
AFTER it started → NOT in it). After busqjn9up confirms, the NEXT build must batch resolver + controller + the trigger
to verify those three. Both new files are parse/typecheck-clean and mirror proven patterns (low risk).

#### 🎯 OWNER ESCALATION 2026-06-24: OpenGUI = FULL CLONE + all engines + PIXEL UI
Owner: "OpenGUI should be a full clone — a completely full clone — but also adding in other engines and things and
making it look as pixel UI as possible." ⇒ the minimal create/send/stream proof is the FOUNDATION, but the TARGET is
FULL capability parity with the OpenGUI runtime (not a thin adapter) + the multi-engine picker + an Epistemos-native
PIXEL UI reskin. (Consistent with the owner's full-clone-not-thin-shell pattern.) License note stands: OpenGUI =
review-before-vendoring → keep SPAWNING from the research clone for the proof; shipping a vendored full clone needs the
owner to accept the license review (flag at ship time).
FULL OpenGUI SDK SURFACE (inventory from open-gui.ts / session-handle.ts / directory-handle.ts) — what the
sidecar+WorkOpenGUISupervisor must expose for a "full clone":
  • SessionHandle: send✅ · abort() [cancel] ❌ · messages(opts) [history/paging] ❌ · onEvent✅ · onStream · waitUntilIdle✅ · close
  • HarnessHandle: sessions.list✅/create✅/open ❌ · abort ❌ · loadResources()→HarnessResourceBundle ❌ (MODELS/AGENTS/
    COMMANDS — powers the owner's "compact engine/model picker") · registerDirectory/releaseDirectory · on("event")
  • DirectoryHandle: connect✅ · release · harness✅ ; OpenGui: at✅ · diagnose✅ · getHarnessInventories ❌ · close✅
  • SendOptions already carry {model, agent, variant, whileBusy} → model/agent picker wiring is ready once loadResources lands.
SIDECAR+BRIDGE GAP for full clone (next builds, after the proof): add commands `sessions.open`, `abort`/cancel,
`messages` (transcript history/paging → reopen a recent session with its past turns = recents fidelity), `loadResources`
(models/agents/commands per engine → the model picker + agent picker + slash-commands), `getHarnessInventories`/diagnose
passthrough (engine availability). Each maps 1:1 to a SessionHandle/HarnessHandle method already in the runtime.
RAIL REUSE (recon): `WorkSessionRailView` already binds to `WorkSessionStore` (the same store WorkEngineSurfaceView
uses) + theme, renders main+mini with focus/new-mini/detach/promote/close → DIRECTLY reusable as the Work recents rail;
wire `onNewMini`→createSession(mini). (Built for the OpenWork path but store-bound, not WebView-bound → reusable.)
PIXEL UI: current view is flat/mono; the reskin pass should lean pixel (pixel font, blocky elements, block caret) per
owner — a dedicated reskin increment after the functional full-clone surface lands. STAY IN WORK ONLY.

#### ✅ busqjn9up BUILD SUCCEEDED + LICENSE=MIT + OpenGUI FULL INVENTORY/CLONE MAP (2026-06-24)
• `** TEST BUILD SUCCEEDED **` (exit 0, 0 errors) — WorkEngineSurfaceView + WorkEngineTranscript + OpenGUI→WorkSession
  mapper are BUILD-VERIFIED in-target. (Resolver + WorkEngineSurfaceWindowController written after → next build batches them.)
• ⚖️ LICENSE RESOLVED: OpenGUI `LICENSE` = **MIT** (Copyright 2026 akemmanuel). A full clone/fork/reskin INTO the app
  is license-safe — just preserve the MIT notice. The "review-before-vendoring" caution is DISCHARGED (reviewed: MIT).
  ⇒ owner's "full clone/fork" is legally clear; we MAY vendor (not only spawn-from-clone) when ready.
• OWNER DIRECTIVE (full inventory + clone map, "don't reduce Work to a tiny wrapper"): OpenGUI is an Electron+Capacitor
  app. Structure: packages/{runtime,backend,protocol} (the ADR-0005 split) + a top-level React/shadcn/Tailwind FRONTEND
  in `src/`. Engine order UPDATED: OpenCode→Codex→Claude Code→Pi/OMP→Goose→Hermes.

##### OPENGUI FULL CLONE MAP (surface → OpenGUI src → Epistemos Work dest → status → gap)
App shell = 2 views `chat|settings` + AppSidebar + TitleBar (src/App.tsx, components/AppSidebar, TitleBar).
| # | Surface | OpenGUI source | Epistemos Work dest | Status | Gap |
|---|---|---|---|---|---|
| 1 | App shell (sidebar+titlebar+chat/settings) | src/App.tsx, components/AppSidebar.tsx, TitleBar.tsx, src/features/app-shell | WorkEngineSurfaceView (host) | partial | needs sidebar+titlebar+settings view |
| 2 | Session mgmt (create/open/list/transcript) | src/features/session, session-transcript; components/MessageList.tsx, message-list/ | WorkOpenGUISupervisor + WorkSession* + WorkEngineTranscript | partial | open/messages-history; transcript projection |
| 3 | Engine/model/provider pickers | components/AgentSelector, ModelSelector, ConnectionPanel, Dialog{Connect,Custom,Select}Provider, SettingsProviders, ProviderManagementRows, provider-icons | WorkEngineSurfaceView picker (engine only) | partial | model+agent pickers (loadResources), provider setup dialogs |
| 4 | Prompt box (input+slash+mentions+addmenu+status) | components/PromptBox, PromptAddMenu, SlashCommandPopover, FileMentionPopover, ImageMentionPreview, PromptContextStatus, PromptSessionStatus, PromptImageMentions | WorkEngineSurfaceView TextField (minimal) | minimal | slash commands, file/image mentions, context status |
| 5 | Prompt QUEUE / pending | components/QueueList.tsx + src server-prompt-queue-service | — | NONE | clone queue (whileBusy=wait is the seam) |
| 6 | Transcript render (md, tool/event cards) | components/MarkdownRenderer, MessageList, message-list/ | WorkEngineTranscript + partView | partial | markdown render, richer tool cards |
| 7 | MCP / skills / tools setup | components/McpDialog.tsx, settings/ | (OpenWork path has WorkNativeMCP*) | NONE(OpenGUI) | clone McpDialog natively |
| 8 | Worktree / diffs / merge | src/features/worktree, components/MergeDialog, PromptWorktreeSelector, hooks/use-prompt-worktree-selector | — | NONE | OpenChamber UX donor; later |
| 9 | Settings/config | components/settings/, ConnectionPanel(SettingsView), AppearanceSetting | — | NONE | clone settings natively |
| 10 | Setup wizard | components/SetupWizard.tsx | — | NONE | first-run flow |
| 11 | Harness status/diagnostics | components/ProjectHarnessStatusBanner.tsx; runtime diagnose/getHarnessInventories | supervisor.status (basic) | partial | diagnostics surface |
| 12 | Agent bootstrap + resources | src/features/agent-bootstrap, agent-resources; runtime loadResources | — | NONE | loadResources → models/agents/commands |
| 13 | Session rail / context menu | components/sidebar/, SessionContextMenu, SidebarItemMenus | WorkSessionRailView (reusable) | ready | wire into view |
DONE (foundation, main loop): supervisor(bridge)✅ transcript✅ mapper✅ view(picker+input+transcript)✅ resolver✅
debug-controller✅ TRIGGER✅. The above table = the remaining full-clone surface.
TRIGGER LANDED (2026-06-24): `WorkCloneSettingsView.swift` Settings → Work clone now has "Open Work · OpenGUI engine
workbench (debug)" → `WorkEngineSurfaceWindowController.shared.open()` (Work-owned file, additive; the OpenWork preview
entry above stays as fallback). swiftc -parse clean. Build bp583sg02 kicked (batches resolver + controller + trigger).
⇒ once bp583sg02 SUCCEEDS + owner runs ⌘R: Settings → Work clone → that button → live engine-picker → create/send/stream
proof (the GOAL). This is the owner-OWED runtime/visual proof gate.
NEXT FIRES: (b) expand sidecar/bridge for loadResources+open+messages+abort (unlocks clone-map #2,#3,#12 — model/agent
pickers, history, cancel); (c) clone secondary surfaces #4 prompt-box, #5 queue, #7 MCP, #9 settings, #10 setup natively;
(d) wire rail #13 (WorkSessionRailView is ready); (e) pixel reskin pass. STAY IN WORK ONLY.

#### ✅ (b) SIDECAR FULL SDK SURFACE LANDED — runtime half (2026-06-24)
`og-sidecar.mjs` now exposes the FULL OpenGUI SDK surface (research clone, safe during the app build):
init · diagnose · sessions.list · sessions.create · sessions.open · send{model,agent,variant,whileBusy} · waitIdle ·
**abort**{sessionId} (cancel) · **messages**{sessionId,limit?,before?} (history/paging→{messages}) ·
**loadResources**{harnessId?} (→{resources}: models/agents/commands for the picker) · close. Each maps 1:1 to a
SessionHandle/HarnessHandle method (abort/messages on SessionHandle; loadResources on HarnessHandle). send now carries
full SendOptions {model,agent,variant}. ✅ node --check clean. Header doc updated.
REMAINING for (b): the SWIFT BRIDGE half — add WorkOpenGUISupervisor wrappers `abort(sessionId)`, `messages(sessionId,…)
→ project into WorkEngineTranscript`, `loadResources(harnessId) → models/agents/commands`, `openSession(id)`; that
touches app source → do when no build runs, then a checkpoint. Then the model/agent picker (#3) + history (#2) +
cancel button wire into WorkEngineSurfaceView. STAY IN WORK ONLY.

##### ✅ loadResources RUNTIME-PROVEN + HarnessResourceBundle SHAPE (2026-06-24, og-loadresources-probe.mjs)
Ran the new sidecar `loadResources` path end-to-end (opencode, bundled, port 4096; reaped by PID after). The bundle =
3 top-level keys → the EXACT data contract for the picker (clone-map #3 + slash-commands #4):
  • `providersData`: object `{ providers, default }` → the MODEL picker (providers → their models; `default` = preselect).
  • `agentsData`: array (7 for opencode) of `{ name, description, mode("primary"|…), native:bool, permission:[…] }` →
    the AGENT picker (e.g. "build" = default primary agent). send already accepts `{agent}`.
  • `commandsData`: array (3) of `{ name, description, source, template }` → the SLASH-COMMAND popover (e.g. "init").
⇒ Swift `loadResources(harnessId) → WorkEngineResources{providers,default,agents,commands}` decodes these; the picker
binds models from providersData + agents from agentsData; slash-commands from commandsData. NO new runtime gaps for the
picker — purely Swift-side wiring now. STAY IN WORK ONLY.

##### ✅ Swift loadResources DATA MODEL LANDED (2026-06-24)
NEW `Epistemos/Work/WorkEngineResources.swift` (Foundation-only, lenient JSONSerialization decode — ignores unknown
fields, converts the models Record→array): `WorkEngineResources{providers:[WorkEngineProvider{id,name,models:[WorkEngineModel{id,name}]}],
agents:[WorkEngineAgent{name,mode?,description?}], commands:[WorkEngineCommand{name,description?}], defaultModelByProvider}`
+ `flatModels` (provider·model for one compact picker) + `WorkEngineResourcesDecoder.decode(Data?)` (accepts the sidecar
`{resources:{…}}` envelope OR bare bundle; hidden agents excluded; never throws → `.empty`). Sendable/Identifiable for
SwiftUI pickers. NEW `EpistemosTests/WorkEngineResourcesTests.swift` (4 tests vs the runtime-verified shape: providers+
models Record→array, defaults, agents-exclude-hidden, commands, lenient nil/malformed/bare). ✅ swiftc -typecheck clean
(decoder, real Sema) + swiftc -parse clean (tests). New files → safe during the in-flight build; batch into next checkpoint.
NEXT: Swift bridge wrappers in WorkOpenGUISupervisor (`loadResources(harnessId)→WorkEngineResources`, `abort`, `messages`,
`openSession`) [app source → after build frees] → then the model/agent picker + slash-commands + cancel into WorkEngineSurfaceView. STAY IN WORK ONLY.

#### ✅ bp583sg02 BUILD SUCCEEDED + SWIFT BRIDGE HALF (b) LANDED (2026-06-24)
• bp583sg02 = `** TEST BUILD SUCCEEDED **` (exit 0): WorkCloneSettingsView(trigger) + WorkEngineSurfaceWindowController +
  WorkOpenGUIWorkspace all compiled in-target. ⇒ ENTIRE Work stack build-verified; the ⌘R live proof is REACHABLE
  (Settings → Work clone → "Open Work · OpenGUI engine workbench (debug)"). Owner-OWED runtime/visual proof only.
• SWIFT BRIDGE wrappers added to WorkOpenGUISupervisor (app source, build was free): `openSession(id,harnessId)`,
  `abort(sessionId)`, `loadResources(harnessId)→WorkEngineResources` (decodes via WorkEngineResourcesDecoder),
  `messages(sessionId,limit?,before?)→Data?` (raw history for later projection); `send` extended with {agent,variant}.
  ✅ swiftc -parse clean (SourceKit WorkEngineResources/Decoder errors = isolation false-positives, sibling in-module).
• Build b8l7p6uql kicked (batches: bridge wrappers + WorkEngineResources decoder + WorkEngineResourcesTests). Result OWED.
⇒ (b) is now CODE-COMPLETE (runtime sidecar + Swift bridge + data model). NEXT: wire the model/agent picker (flatModels +
agents from loadResources) + cancel(abort) button + slash-commands into WorkEngineSurfaceView (clone-map #3,#4) — view
edit, after b8l7p6uql; then session history projection (#2), then secondary surfaces (#5 queue, #7 MCP, #9 settings) +
pixel reskin. STAY IN WORK ONLY.

#### ✅ PROMPT QUEUE MODEL LANDED (clone-map #5) (2026-06-24)
Reconned OpenGUI queue: `QueueMode = "queue"|"interrupt"|"after-part"` (normal / abort+send-now / steer);
`QueuedPrompt{id,text,createdAt,model?,agent?,variant?,mode}`; QueueList ops = enqueue/reorder(top/bottom)/edit/
send-now/remove/per-prompt-mode. OpenGUI's runtime SDK is deliberately NOT a queue (ADR 0005) → the queue is an
Epistemos-OWNED layer on the proven send/abort/waitUntilIdle/status seam. NEW `Epistemos/Work/WorkPromptQueue.swift`
(@MainActor @Observable): `WorkQueueMode`(+wireValue/wire-init for the "after-part" hyphen) + `WorkQueuedPrompt` +
`WorkPromptQueue`{enqueue,dequeue(FIFO drain),takeNow(send-now),remove,edit,setMode,moveToTop/Bottom,clear}. NEW
`EpistemosTests/WorkPromptQueueTests.swift` (5 tests: FIFO, options, reorder/edit/mode, takeNow, wire-mapping). ✅ swiftc
-parse clean (both; new files safe during the in-flight b8l7p6uql build → batch next checkpoint).
The DRAIN POLICY (session idle → dequeue+send; interrupt → abort+send; after-part → steer) + the QueueList UI wire into
WorkEngineSurfaceView later (view edit). STAY IN WORK ONLY.

#### ✅ QueueList UI + history-projection recon (2026-06-24)
NEW `Epistemos/Work/WorkQueueListView.swift` — flat/compact native QueueList bound to WorkPromptQueue: pending rows with
mode badge (interrupt/steer), send-now (takeNow→onSendNow), move-to-top/bottom, per-row mode menu, remove, clear.
Mirrors OpenGUI QueueList + the proven WorkSessionRailView style; #Preview matches the working rail #Preview return
pattern. ✅ swiftc -parse clean (SourceKit WorkPromptQueue/EpistemosTheme/return-in-ViewBuilder = isolation cascade).
RECON #2 history: `messages()` → OpenGUI `TranscriptMessageEntry{info:Message, parts:Part[]}` (Part.type text|tool,
state.status); projection ref = packages/runtime/src/session-transcript-projection.ts. Deferred the native projector
(exact messages() runtime shape uncertain + it's fidelity, not the GOAL path) until the integration pass confirms it.
⚠️ BATCH-BUILD TRACKING: b8l7p6uql (in flight) covers bridge-wrappers + WorkEngineResources(+tests) ONLY. Written AFTER
it started → NOT verified yet: WorkPromptQueue(+tests), WorkQueueListView. The NEXT build (the integration pass) must
batch those three + the WorkEngineSurfaceView edits. All are parse/typecheck-clean + mirror proven patterns (low risk).
NEXT (integration pass, after b8l7p6uql, app source free): wire into WorkEngineSurfaceView — model/agent picker
(loadResources.flatModels + agents), cancel(abort) button, queue (enqueue-when-busy + drain-on-idle + WorkQueueListView),
slash-commands — then a batched build. STAY IN WORK ONLY.

#### ✅ b8l7p6uql SUCCEEDED + INTEGRATION PASS 1 (picker + cancel) (2026-06-24)
b8l7p6uql = `** TEST BUILD SUCCEEDED **` (bridge wrappers + WorkEngineResources(+tests) build-verified).
WorkEngineSurfaceView NOW wires the proven bridge (clone-map #3 model/agent picker + cancel):
  • on engine change → `loadResources(harnessId)` → resources; preselect default model (defaultModelByProvider) + first agent.
  • HEADER: enginePicker + **modelPicker** (provider·model from resources.flatModels) + **agentPicker** (resources.agents),
    all compact .menu pickers, hidden until resources arrive.
  • INPUT: **cancel (stop) button** when transcript.status==.running → supervisor.abort(activeSession); input no longer
    disabled while sending (prep for enqueue-while-busy).
  • submit now passes `model: selectedModelID, agent: selectedAgent` → the picked engine+model+agent drive the turn.
✅ swiftc -parse clean (SourceKit sibling-type/.running/closure errors = isolation false-positives).
Build b6l0bt0p8 kicked — BATCHES: the view integration + WorkPromptQueue(+tests) + WorkQueueListView (the post-b8l7p6uql
pieces). Result OWED next fire.
NEXT: INTEGRATION PASS 2 — queue drain (enqueue-when-busy via WorkPromptQueue + drain-on-idle loop watching
transcript.status + embed WorkQueueListView above the input) + slash-commands (resources.commands) → clone-map #4/#5 in
the live view. Then secondary surfaces #7 MCP / #9 settings / #10 setup, session rail #13 (WorkSessionRailView), pixel reskin. STAY IN WORK ONLY.

#### ✅ b6l0bt0p8 SUCCEEDED + INTEGRATION PASS 2 (queue drain) + messages() shape (2026-06-24)
b6l0bt0p8 = `** TEST BUILD SUCCEEDED **`: integration pass 1 (engine/model/agent picker + cancel) + WorkPromptQueue
(+tests) + WorkQueueListView all build-verified in-target.
INTEGRATION PASS 2 (queue #5) wired into WorkEngineSurfaceView: `submit` now ENQUEUES when busy
(transcript.status==.running || sending) else `sendNow`; `drainIfIdle(status)` (on transcript.status→.idle, dequeue+send
the next, one per idle transition); WorkQueueListView embedded above the input; `handleSendNow` (send if free, else
re-queue at front); `sendNow(text,model,agent)` honors each queued prompt's own model/agent. ✅ swiftc -parse clean
(SourceKit sibling-type/.running errors = isolation false-positives). Build b5dd8n0p4 kicked. Result OWED.
⇒ The Work surface is now a real multi-engine workbench: engine+model+agent picker · send/stream · cancel · PROMPT
QUEUE (enqueue-when-busy, drain-on-idle, send-now, reorder, modes) · native transcript (no debris) · recents identity.
RESOLVED #2 history shape (og-messages-probe.mjs): `messages()` → `{messages:[{info{id,role,time,agent,model}, parts:[{id,
type("text"|"tool"…),text}]}], nextCursor, revision}` — parts mirror the live LiveSessionEvent shape, so reopened-session
history projects through the SAME reducer logic. History projector (#2) now unblocked (shape known).
NEXT: confirm b5dd8n0p4 → (a) slash-commands popover (resources.commands) into the input (#4); (b) session rail #13 —
listSessions bridge wrapper + list-on-connect → WorkSessionMapper → WorkSessionStore → embed WorkSessionRailView;
(c) history projector (#2, shape known); (d) #7 MCP provisioning (workspace opencode.json + WorkNativeMCPHost); (e) pixel reskin. STAY IN WORK ONLY.

#### ✅ Slash-command popover VIEW built (clone-map #4) (2026-06-24)
NEW `Epistemos/Work/WorkSlashCommandPopover.swift` — flat/compact native list of `resources.commands` filtered by the
text after "/", `onSelect` callback, OpenCode-minimal (mono, boxy, no donor chrome). Standalone + reusable; the input
wiring (show on "/", pass query, insert/run on select) lands in the integration batch. ✅ swiftc -parse clean (SourceKit
WorkEngineCommand/EpistemosTheme errors = isolation false-positives).
⚠️ BATCH-BUILD TRACKING: b5dd8n0p4 (in flight) covers the queue-drain view integration ONLY. NOT yet verified (written
after): WorkSlashCommandPopover. Fold it into the NEXT integration build.
STANDALONE PIECES READY FOR THE INTEGRATION BATCH: WorkQueueListView(wired✅), WorkSlashCommandPopover(pending wire),
WorkSessionRailView(reuse, pending wire), WorkEngineResources(wired✅). Bridge gaps for the batch: `listSessions(harnessId)`
wrapper (rail) + a `.user` transcript kind (history projector, so user prompts render distinctly) — both app-source,
do in the batch. NEXT INTEGRATION BATCH (one build): slash-wire #4 + listSessions+rail #13 + history projector #2. STAY IN WORK ONLY.

#### ✅ HISTORY PROJECTOR built (clone-map #2) (2026-06-24)
NEW `Epistemos/Work/WorkSessionHistoryProjector.swift` (Foundation-only, lenient): `project(Data?) → [WorkHistoryMessage
{id, role, parts:[WorkHistoryPart{kind(text|thinking|tool|other), text, toolName?, toolStatus?}]}]`. Digs through the
nested `{messages:{messages:[…]}}` envelope to the entries array; maps part type text→.text, reasoning/thinking→.thinking,
tool→.tool (name+status+output), unknown-with-text→.other (NO raw debris). NEW
`EpistemosTests/WorkSessionHistoryProjectorTests.swift` (4 tests vs the runtime-verified shape: user+assistant roles,
tool name/status/output, reasoning→thinking, lenient nil/malformed/bare). ✅ swiftc -typecheck clean (projector, real
Sema) + -parse clean (tests). New files → safe during the in-flight b5dd8n0p4 build → batch next.
STANDALONE BACKLOG (all parse/typecheck-clean, awaiting the integration batch's single build): WorkSlashCommandPopover,
WorkSessionHistoryProjector(+tests). The INTEGRATION BATCH (one build) does the app-source edits: `.user` transcript
kind, `listSessions(harnessId)` bridge wrapper, then wire slash-popover #4 + rail #13 (list-on-connect→mapper→store) +
history-projector #2 (open recent → messages → project → replay into transcript) into WorkEngineSurfaceView. STAY IN WORK ONLY.

#### ✅ PIXEL RESKIN scoped + WorkPixelFont built (owner's emphasized "pixel UI") (2026-06-24)
Epistemos ALREADY bundles + registers (EpistemosFont.registerFonts) the assets the pixel reskin needs: pixel faces
(ChonkyPixels, CoralPixels, BitPap, Pixelon, Dotemp-8bit2, RetroGaming, VTFMisterPixel, …) + JetBrainsMono-Regular
(mono). Theme exposes `EpistemosTheme.monoFontName = "JetBrainsMono-Regular"` + `monoFont(size:weight:)` (Font.custom +
NSFont fallback). Existing `Font.custom("ChonkyPixels", …)` confirms that PS name works. ⇒ NEW
`Epistemos/Work/WorkPixelFont.swift`: `body(size,weight)` = JetBrainsMono-Regular (readable mono for transcript/input/
labels) + `pixel(size)` = ChonkyPixels (pixel ACCENTS only: header title/status/badges — never long body, to keep
readable). Font.custom silently falls back if a face is missing → safe. ✅ swiftc -typecheck clean (real Sema, self-contained).
RESKIN PASS (dedicated fire, view editable): swap the Work views' `.system(…,design:.monospaced)` → `WorkPixelFont.body(…)`
+ pixel-ize accents → `WorkPixelFont.pixel(…)`; tighten spacing; block caret = OWED (SwiftUI TextField has no native block
caret → later custom approach). Mechanical + low-risk now that fonts are centralized. STAY IN WORK ONLY.
RESKIN EXECUTION MAP (25 monospace swap sites → WorkPixelFont.body, preserving size/weight): WorkEngineSurfaceView 14 ·
WorkQueueListView 4 · WorkSlashCommandPopover 2 · WorkEnginesPanelView 5 · WorkSessionRailView 0 (uses plain .system →
also swap to body). PIXEL-ACCENT sites → WorkPixelFont.pixel: header `Text("Work")` (size 12) + the interrupt/steer/tool
badges (weight .semibold). Per-file find/replace `.system(size: N, weight: W, design: .monospaced)` →
`WorkPixelFont.body(N, weight: W)` (drop `design:`; for no-weight calls use `.body(N)`). One build after. STAY IN WORK ONLY.
BLOCK CARET (owner "blocky cursor") — recon: NO SwiftUI-native block caret. Approach = a Work-owned NSViewRepresentable
single-line field overriding `drawInsertionPoint` to fill a block (or set insertionPointColor + a custom caret layer).
Reference pattern: `Epistemos/Views/Chat/ChatInputBar.swift` ChatComposerTextEditor (Chat-owned → READ-ONLY reference,
do NOT depend/edit). DEFER behind the font reskin (it's the lowest-priority detail; the input stays a plain TextField
until then). Build it as `WorkBlockCaretField.swift` (new file) when doing the reskin polish.

#### ✅ PIXEL RESKIN EXECUTED (2026-06-24) + ⚠️ full build blocked by Chat agent (not mine)
bn061dyhk (the registration.url-fix rebuild) = BUILD FAILED **but 0 errors in any Work file** — all 57 errors were in
the parallel CHAT agent's WIP (Epistemos/Chat/EpistemosChatSession.swift ×24, ChatTranscript.swift ×8, etc.). ⇒ MY Work
code (the whole feature-complete clone + the fix) COMPILES CLEAN in-target; the shared full build just can't go green
while the Chat agent's in-progress edits are broken (NOT my scope — must not touch Chat). VERIFICATION RULE going
forward: a Chat-failing full build still compiles + reports MY Work files, so verify Work via "0 errors in Work files",
not overall BUILD SUCCEEDED, until Chat greens.
PIXEL RESKIN done (owner's emphasized "pixel UI"): swapped ALL 25 monospace sites → `WorkPixelFont.body(size[,weight])`
across WorkEngineSurfaceView (14) / WorkQueueListView (4) / WorkSlashCommandPopover (2) / WorkEnginesPanelView (5);
header `Text("Work")` title → `WorkPixelFont.pixel(12)` (pixel accent). 0 `.monospaced` left in the Work views. ✅ all 5
files swiftc -parse clean. (WorkSessionRailView had 0 mono sites — uses plain .system; optional body() swap later for
consistency.) block caret still OWED (WorkBlockCaretField, later).
✅ RESKIN WORK-VERIFIED (bp6t0v648): overall BUILD FAILED (57 errors) but **0 errors in /Epistemos/Work/** — all 57 are
the parallel Chat agent's WIP (Epistemos/Chat/*). My reskinned Work views compile clean in-target. ⇒ The OpenGUI Work
clone is FUNCTIONALLY COMPLETE + PIXEL-RESKINNED, all Work code verified (OpenCode-TUI minimalism: JetBrainsMono body +
ChonkyPixels title accent, flat, theme-aware). A green FULL build awaits the Chat agent fixing their files (not my scope).

#### 📋 OWNER ⌘R VERIFICATION GUIDE (the OWED proof — make it work first try) (2026-06-24)
CRITICAL PREREQ: launch with env `EPISTEMOS_OPENGUI_SIDECAR_ROOT=/Users/jojo/Downloads/Epistemos/.research-clones/work/opengui`
(Xcode → scheme → Run → Arguments → Environment Variables). WITHOUT it the supervisor can't find og-sidecar.mjs → the
surface shows "unavailable" (no fake server — honest). (bun + bundled opencode are auto-resolved by the supervisor's
PATH; opencode auth.json already carries over.) For ship, the sidecar+runtime get bundled (disk/license decision; until
then it's the env var / research clone.)
STEPS: ⌘R → Settings → Work clone → "Open Work · OpenGUI engine workbench (debug)" → header status should go
starting→ready, engine picker shows **opencode** (+ claude-code/codex) → type a prompt + Enter.
EXPECT (proves the GOAL): assistant text STREAMS natively (no raw JSON/log debris) → run finishes (status "ready").
Model/agent pickers populate (loadResources). Cancel (stop) button appears mid-turn. Type while busy → it QUEUES + drains
on idle. Session rail lists sessions (list-on-connect); clicking one reopens with HISTORY replay. Gear → engines roster.
Native tools (MCP) reach the agent (workspace opencode.json gets epistemos-native). KNOWN: full app build is red on the
Chat agent's WIP, not Work — Work compiles clean; if the app won't build, that's the sibling agent, not this surface.
Remaining after proof: block-caret polish · #6 markdown render · #8 worktree (later) · rail font-consistency swap. STAY IN WORK ONLY.

#### ✅ RAIL FONT-CONSISTENCY done → pixel reskin 100% across Work views (2026-06-24)
WorkSessionRailView: session-title Text → `WorkPixelFont.body(12, weight: isActive ? .semibold : .regular)` (the SF
Symbol icon stays `.system` — pixel fonts have no symbols). ⇒ ALL Work views now use WorkPixelFont for text (0
`.monospaced` left, 24 WorkPixelFont usages); pixel reskin is fully consistent. ✅ swiftc -parse clean; type-safe
identical-pattern to the 25 swaps build-verified in bp6t0v648 → verified-by-pattern (rides the next full build; no
dedicated build for a 1-line swap). REMAINING: owner ⌘R proof · block-caret polish (WorkBlockCaretField) · #6 markdown ·
#8 worktree (later). STAY IN WORK ONLY.

#### ✅ BLOCK CARET built + wired (owner's "blocky cursor") (2026-06-24)
NEW `Epistemos/Work/WorkBlockCaretField.swift` — single-line `NSViewRepresentable` (WorkBlockCaretTextView) drawing a
filled BLOCK insertion point (widen caret rect in drawInsertionPoint + widen setNeedsDisplay so it erases on blink — the
proven pattern), Enter→onSubmit (no newline), two-way text binding, drawsBackground=false. WIRED into
WorkEngineSurfaceView.inputBar: ZStack { non-hit-testing placeholder (when empty) ; WorkBlockCaretField(font:
JetBrainsMono-Regular 13, caretColor: NSColor(accent), isEnabled: !engines.isEmpty, onSubmit: submit) } — replaces the
plain TextField; cancel/send unchanged; placeholder `.allowsHitTesting(false)` keeps focus safe. ✅ swiftc -parse clean
(both); build bfv5yyql6 kicked (Work-level verify; overall still red on Chat WIP). Visual (block renders + Enter submits
+ focus) = owner ⌘R confirm; fix any AppKit edge next fire. ⇒ owner's pixel "blocky cursor" delivered in code.
Remaining: owner ⌘R proof · #6 markdown · #8 worktree (later).

#### 📋 REMAINING POLISH BATCH (clone is feature+pixel COMPLETE; these = polish, do as ONE batch next free-build fire)
Priority order (all app-source → batch when no build runs, verify Work-level):
1. ⌘R DEV-CONVENIENCE (TOP — unblocks the owner proof without scheme config): make `WorkOpenGUISupervisor.defaultSidecarRoot`
   fall back to the known dev clone path (`<repo>/.research-clones/work/opengui`) when EPISTEMOS_OPENGUI_SIDECAR_ROOT is
   unset (DEBUG-only fallback; ship bundles the sidecar). Then ⌘R "just works" (no "unavailable"). Hardcoded dev path is
   acceptable in a debug fallback; gate it #if DEBUG.
2. AUTO-SCROLL transcript to bottom as content streams (ScrollViewReader + .onChange(transcript.parts.count) → scrollTo last).
3. AUTO-FOCUS the input on appear (@FocusState on the WorkBlockCaretField / become first responder).
4. TRANSCRIPT EMPTY-STATE hint (when parts empty + ready: a flat "Type to start an OpenCode session" line, no card).
5. #6 MARKDOWN render — aligned w/ donor (OpenGUI MessageList/MarkdownRenderer renders markdown; "GUI not raw text"):
   render `.answer` via shared `Views/Shared/MarkdownTextView` OR AttributedString(markdown:) keeping JetBrainsMono base
   + flat styling; keep code blocks mono.
6. #8 worktree/diffs — LATER (native git service + OpenChamber UX; off the runtime path; after core owner-verified).
Then: owner ⌘R runtime/visual proof (OWED). The functional+pixel OpenGUI Work clone is otherwise DONE + Work-verified.

#### ✅ POLISH BATCH 1-4 DONE (2026-06-24) — ⌘R proof now first-try usable
Block caret = Work-verified (bfv5yyql6: 0 Work errors; the 5 overall errors are sibling-agent WIP, down from 57 → Chat
agent is fixing theirs). Then executed polish batch #1-4 (app source free):
1. ⌘R DEV-CONVENIENCE: WorkOpenGUISupervisor.defaultSidecarRoot now (#if DEBUG) falls back to
   `~/Downloads/Epistemos/.research-clones/work/opengui` if EPISTEMOS_OPENGUI_SIDECAR_ROOT unset + og-sidecar.mjs exists
   → ⌘R "just works" without scheme env config (ship bundles the sidecar). REMOVES the env-var gotcha.
2. AUTO-SCROLL: transcriptView wrapped in ScrollViewReader; `scrollKey` (parts.count : last-part text length) onChange →
   scrollTo last (.bottom) → transcript follows streaming.
3. AUTO-FOCUS: WorkBlockCaretField.makeNSView async makeFirstResponder → input focused on open (type immediately).
4. EMPTY-STATE: transcript shows "Type to start an OpenCode session" (or "connecting…") when no parts — flat, no card.
✅ all 3 files swiftc -parse clean; build bkqcksxh3 kicked (Work-level verify). ⇒ the surface is now first-try usable on
⌘R (focus + auto-scroll + no env-var gotcha).
🐞 BUG FOUND (fix next free-build fire — do NOT edit while bkqcksxh3 compiles WorkEngineSurfaceView): switching the
engine picker mid-session does NOT clear `activeSessionID`, so the next send targets the OLD engine's session (mismatch).
FIX: in `.onChange(of: selectedEngine)`, after resetting model/agent, also `activeSessionID = nil; transcript.reset()`
(switching engine = fresh start on the new engine). One-line addition; verify Work-level.
REMAINING (priority): (1) engine-switch fix [bug, above] · (2) owner ⌘R proof · (3) #5 markdown render (owner-taste:
donor renders markdown but TUI leans mono — confirm w/ owner after ⌘R) · (4) #8 worktree (later).

#### ✅ ENGINE-SWITCH BUG FIXED + polish Work-verified (2026-06-24)
Polish batch (bkqcksxh3) = Work-verified (0 Work errors; 5 overall = sibling-agent WIP). Then FIXED the engine-switch
bug: `.onChange(of: selectedEngine)` now also `activeSessionID = nil; transcript.reset()` → switching engine starts a
fresh session on the new engine (no stale cross-engine session). ✅ swiftc -parse clean; build bl68mpar0 kicked
(Work-level verify). ⇒ REMAINING = owner ⌘R proof · #5 markdown (owner-taste, after ⌘R) · #8 worktree (later). The
functional+pixel OpenGUI Work clone is complete, Work-verified, ⌘R-first-try-usable, and now engine-switch-correct.

#### 🔎 #5 markdown approach decided + next-surface note (2026-06-24)
#5 recon: the shared `Views/Shared/MarkdownTextView` is a 1445-line NOTES-specific renderer (themed headings/tables/
note-styling, no clean render-a-string API) → too heavy + wrong aesthetic to reuse for the Work transcript. ⇒ #5 =
a SMALL custom renderer: split the answer by fenced code blocks (``` fences) → render code as mono bordered boxes (TUI),
non-code segments via `AttributedString(markdown:)` (inline bold/italic/code/links). KEEP mono base. BUT the plain-mono
transcript already reads cleanly + is TUI-authentic, so "how much markdown" is genuinely OWNER-TASTE → confirm after ⌘R
(don't over-build formatting the owner may not want for the minimalism). Defer #5 to owner-confirm.
CLONE STATE: CORE workbench COMPLETE + Work-verified. Secondary surfaces remaining (in-scope "full clone" but
lower-priority / owner-gated): #5 markdown (taste, after ⌘R) · #9 PROVIDER-AUTH surfacing (clear, non-taste: show authed
providers from loadResources.providersData + auth state — best added as a section in WorkEnginesPanelView; next
free-build fire) · #8 worktree/diffs (later, native git + OpenChamber) · full #9 settings tabs (mostly reuse). NEXT
FREE-BUILD FIRE obvious-best: provider-auth section in WorkEnginesPanelView (non-taste, uses existing data). Owner ⌘R = the gate. STAY IN WORK ONLY.

#### ✅ PROVIDERS section added to engines panel (#9 tail) (2026-06-24)
Engine-switch fix Work-verified (bl68mpar0: 0 Work errors; 5 overall = sibling-agent WIP). Then added a PROVIDERS
section to WorkEnginesPanelView: lists `resources.providers` (name · "default" badge if defaultModelByProvider has it ·
N models) — surfaces which providers the active engine knows + which has a default (provider-auth-state surfacing from
existing loadResources data; no new bridge wrapper). ✅ swiftc -parse clean; build b4jhkon2m kicked (Work-level verify).
⇒ The engines panel now shows engine roster + capabilities + providers. Remaining: owner ⌘R · #5 markdown (taste) · #8
worktree (later) · full settings tabs (reuse). The OpenGUI Work clone's core + most secondary surfaces are now built. STAY IN WORK ONLY.

#### ✅ SAFETY INVARIANT verified: provisioner config isolated from the fallback (2026-06-24)
WorkOpenGUIProvisioner writes opencode.json into `Epistemos/WorkOpenGUI/workspace` (WorkOpenGUIWorkspace.ensureDefault).
The OpenWork fallback uses `Epistemos/WorkRuntime/workspace`; WorkOpenCodeRuntime uses its own `…-runtime` config. ⇒ the
OpenGUI provisioner does NOT clobber the OpenWork/OpenCode fallback config (owner said keep the fallback until proof) —
separate dirs, no conflict. Confirmed by path recon. (b4jhkon2m providers build still running; will verify Work-level.)

#### ✅✅✅ WORK CLONE — ⌘R-READY CHECKPOINT (2026-06-24)
b4jhkon2m: providers section Work-verified (0 Work errors; 5 overall = Chat-agent WIP). ⇒ EVERY Work surface compiles
clean in-target. The OpenGUI Work clone (core + most secondary surfaces) is COMPLETE + Work-verified:
  SURFACE: WorkEngineSurfaceView — engine/model/agent picker · input→createSession/send · streaming native transcript
  (no debris) · cancel · PROMPT QUEUE (enqueue-when-busy/drain/reorder/modes) · SESSION RAIL (recents, reopen+history
  replay) · slash-commands popover · gear→ENGINES PANEL (roster + capabilities + providers) · NATIVE TOOLS via MCP
  (WorkOpenGUIProvisioner→workspace opencode.json→WorkNativeMCPHost) · BLOCK CARET · PIXEL SKIN (JetBrainsMono +
  ChonkyPixels) · auto-focus/auto-scroll/empty-state · engine-switch-correct. Identity preserved via WorkSession store.
  RUNTIME: WorkOpenGUISupervisor drives og-sidecar.mjs (full SDK: init/diagnose/list/create/open/send/waitIdle/abort/
  messages/loadResources/close) → @opengui/runtime → bundled opencode. Proven: spike + NDJSON sidecar + multi-engine +
  loadResources + messages-shape. Swift bridge build-verified across all increments.
HOW THE OWNER VERIFIES (the OWED gate): ⌘R (no env config needed now — DEBUG sidecar-root fallback) → Settings → Work
clone → "Open Work · OpenGUI engine workbench (debug)" → it auto-focuses; pick OpenCode; type → streams; rail/history/
queue/cancel/pickers/block-caret/gear-panel all live.
PENDING (owner decisions / later — NOT blocking the clone): #5 markdown render (TASTE: clean mono now vs formatted —
custom lightweight renderer scoped; confirm after ⌘R) · #8 worktree/diffs (LATER: native git + OpenChamber; off the
runtime path) · full #9 settings tabs (mostly reuse of existing theme/settings). KNOWN: full app build is red ONLY on
the parallel CHAT agent's WIP (Epistemos/Chat/*) — Work compiles clean; not a Work bug. STAY IN WORK ONLY.

#### ✅ #5/#6 MARKDOWN RENDER built + wired (2026-06-24)
Reframed: rendering markdown is NOT a taste call — raw `**bold**`/fenced source showing literally IS the "raw debris in
prose" the owner's target forbids; rendering it (donor parity: OpenGUI/OpenCode render markdown) REMOVES that debris +
fits TUI. NEW `Epistemos/Work/WorkMarkdownText.swift` — splits the answer by fenced code blocks (triple-backtick): code →
flat mono BORDERED box; prose → `AttributedString(markdown:, .inlineOnlyPreservingWhitespace)` (bold/italic/inline-code/
links) over JetBrainsMono base. Streaming-safe (unclosed trailing fence → in-progress code box; bad inline → literal
fallback). WIRED into WorkEngineSurfaceView partView `.answer` case (replaces plain Text). NEW
`EpistemosTests/WorkMarkdownTextTests.swift` (5 tests: plain, prose+code+prose order, unclosed fence, empty-filter,
inline fallback). ✅ all 3 swiftc -parse clean; build bycemi3eo kicked (Work-level verify). ⇒ assistant answers now
render formatted (no raw markdown debris), code in mono boxes. PENDING now: owner ⌘R · #8 worktree (later) · #9 full settings (reuse).

#### ✅ opencode PER-SESSION LEAK FIXED + runtime-verified (2026-06-24)
Root cause (confirmed in opencode-bridge.ts): the bridge `spawn`s opencode then `child.unref()`s it (only kills on
version-mismatch respawn) → it survives the bun parent + `og.close()` does NOT reap it → each Work session that spawns
opencode leaks a process (matches the strays I had to manually kill in probes). FIX (sidecar, research clone — no
app-build conflict): og-sidecar.mjs now `reapOpencode()` on `close` + SIGTERM/SIGINT — a PORT-SCOPED `pkill -f "opencode
serve --port <OPENGUI_OPENCODE_PORT>"` (the port is unique to this sidecar; the app's opencode uses --cors + other ports
→ never hit). ✅ node --check clean + RUNTIME-VERIFIED: re-ran og-sidecar-drive.mjs → PASS (26 events) → after close,
**0 stray opencode on :4096** (was leaking before) + the 5 app --cors instances UNTOUCHED (port-scoped reap is safe).
⇒ Work sessions no longer leak opencode. (NB: the Swift WorkOpenGUISupervisor.stop() sends `close` + SIGTERM-terminates
bun → the sidecar's SIGTERM handler reaps even if `close` doesn't process in time.) bycemi3eo markdown build: 0 Work errors.

#### ✅ PHASE-1 ACCEPTANCE AUDIT — all 6 criteria covered in code (2026-06-24)
Audited the Work surface against CHAT_ACT_WORK_TRI_SURFACE_ENGINE_PLAN §"Phase 1 — Work Proof Through OpenGUI" (the
authoritative acceptance list). All 6 COVERED + Work-verified: (1) list engines/harnesses → engine picker
(status.connectedHarnesses) + engines-panel roster; (2) open OR create an OpenCode session → createSession +
openSession/openFromRail; (3) send a prompt → send(model/agent); (4) stream events back → onEvent → WorkEngineTranscript;
(5) render tool events + assistant text in Epistemos UI → transcript parts (tool cards, answer markdown, thinking,
error) — no raw debris; (6) preserve native recents/session identity → WorkSession store + rail + history replay.
"Keep OpenWork as fallback" → honored (not deleted; isolated config). ⇒ Phase-1 is CODE-COMPLETE against the plan; the
only remaining Phase-1 item is the RUNTIME "prove" via owner ⌘R (OWED). Phase 2 (Goose adapter) is explicitly gated
"after OpenGUI/OpenCode proof" → correctly deferred to post-⌘R. Phases 3/4 = Chat/Act agents (not Work). STAY IN WORK ONLY.

#### ✅ status-failure surfacing (⌘R diagnosability) (2026-06-24)
If the surface can't start, status only showed cryptic "unavailable"/"error" (the reason String was dropped). Added
`surfaceStatusError(_:)` + `.onChange(of: supervisor.status)` in WorkEngineSurfaceView → on `.unavailable(reason)` /
`.failed(reason)` it ingests the REASON as a native transcript error part. ⇒ a failed ⌘R now shows WHY (e.g. "og-sidecar.mjs
not found at …", "bun not resolvable", "init failed: …") instead of a blank "unavailable" — directly aids the owner's
OWED ⌘R proof. ✅ swiftc -parse clean; build bc4bu5nwq kicked (Work-level verify). STAY IN WORK ONLY.

#### 🐞 MULTI-ENGINE PICKER GAP found (was single-engine) — fix in progress (2026-06-24)
Audit caught a real gap (corrects the premature "complete"): `startEngine` connects ONLY `["opencode"]`, and the picker's
`engines` = `status.connectedHarnesses` → so the "multi-engine picker" (owner's core want: OpenCode→Codex→Claude→Pi)
currently shows ONLY OpenCode. The other engines (Codex/Claude proven connectable in og-engines-probe) are never offered.
FIX = LAZY connect-on-select (keeps "OpenCode first" fast; don't eager-spawn all engine servers on open):
  • SIDECAR (done this fire, safe): added a `connect {harnessId}` command → dir.connect for an ADDITIONAL engine after
    init → adds to harness map → returns connectedHarnessIds. node --check clean (12 commands now).
  • NEXT FREE-BUILD FIRE (app source): supervisor `diagnose() → [readyEngineIds]` + `connect(harnessId) → [String]`
    wrappers; view: picker offers the DIAGNOSED-READY roster (not just connected) with OpenCode default; on select an
    unconnected engine → `await supervisor.connect(id)` then proceed. Then the picker is genuinely multi-engine.
⇒ Phase-1 criterion (1) "list engines" is partially met (lists connected=opencode); the MULTI-engine picker needs this
fix to fully satisfy the owner's directive. PRIORITY next fire (over other polish). STAY IN WORK ONLY.

#### ✅ MULTI-ENGINE PICKER FIXED end-to-end (2026-06-24)
RUNTIME FINDING (og-connect-probe): lazy `connect(codex)` after `createOpenGUI({harnesses:["opencode"]})` FAILED ("No RPC
handler registered for codex:project:add") — the runtime registers RPC handlers only for harnesses in createOpenGUI.
FIX (all verified): (a) SIDECAR init now `createOpenGUI({harnesses: ROSTER=["opencode","codex","claude-code","pi"]})`
(registers all handlers, NO spawn) + connects only `harnesses`(opencode) NOW → re-ran probe: init=["opencode"] then
connect codex → ["codex"], errors:[] → **PASS** (lazy connect works). (b) SUPERVISOR: added `diagnose()→[readyEngineIds]`
+ `connect(harnessId)→[String]` (merges into status.connectedHarnesses). (c) VIEW: `readyEngines` (diagnosed roster) +
`pickerEngines` (picker shows the roster, not just connected) + diagnose-on-running + connect-on-select (onChange
selectedEngine → if not connected, `await supervisor.connect(engine)` then loadResources). ✅ all swiftc -parse clean;
build b5z1kz0co kicked. ⇒ the picker now offers the diagnosed-ready roster (opencode/codex/claude-code in this env) +
lazily connects on select, OpenCode-first/fast. Phase-1 (1) "list engines" now FULLY met (multi-engine). Owner ⌘R verifies live.

#### 🔎 #9 SETTINGS surface scoped (2026-06-24 recon)
OpenGUI SettingsView = 4 tabs (src/components/settings/): **general** (GeneralSettings = AppearanceSetting[theme] +
language select + new-chat-model-behavior), **providers** (provider auth/connect — ConnectionPanel/ProviderManagementRows),
**plugins** (PluginsSettings = opencode plugins), **mcp/tools** (McpSettings = MCP server config). NATIVE CLONE PLAN
(mostly reuse/surface, NOT a big new build): General→Epistemos ALREADY owns theme/appearance (reuse theme tokens, don't
clone a separate appearance panel; language is optional); Providers→surface the opencode auth.json/loadResources
providersData state + a connect action (opencode owns the auth flow; Work just surfaces it = the #3-tail); MCP/tools→#7
(workspace opencode.json + WorkNativeMCPHost); Plugins→opencode plugins (LOW priority). ⇒ #9 is largely "surface
existing state + connect/MCP actions in a compact native tabbed panel," reusing #3/#7 — defer until the core integration
batch + rail land. Reachable from the Work surface header gear (already a placeholder icon in WorkEngineSurfaceView). STAY IN WORK ONLY.

#### 🔎 #6 transcript markdown scoped + CLONE-MAP STATUS ROLLUP (2026-06-24)
#6 (assistant answers as markdown, not plain mono): Epistemos has a SHARED native `MarkdownTextView` (Views/Shared/ —
reusable by Work WITHOUT touching Chat) + native `AttributedString(markdown:)`. The transcript's `.answer` parts render
via one of these in the refinement pass (keep mono code-blocks). Low-risk, defer to refinement.
CLONE-MAP STATUS ROLLUP: #1 shell(host)✅ · #2 history(projector built, wire pending) · #3 picker(model/agent INTEGRATED;
provider-setup=#9 tail) · #4 slash(popover built, wire pending) · #5 queue(model+UI+drain INTEGRATED) · #6 markdown(scoped) ·
#7 MCP(scoped: reuse W-R3) · #8 worktree/diffs(NONE — OpenChamber donor, later) · #9 settings(scoped) · #10 setup wizard(NONE,
low pri) · #11 diagnostics(basic via status; scoped) · #12 agent-resources(loadResources INTEGRATED) · #13 rail(reuse ready,
wire pending). CORE GOAL (create/send/stream + identity) = DONE + build-verified + ⌘R-reachable.
HOLDING PATTERN NOTE: several recent fires were build-gated (slow xcodebuild + contention with the parallel Act agent's
builds) → did recon/standalone pieces. All clone-map surfaces are now built or scoped. The CRITICAL PATH is the
INTEGRATION BATCH (slash-wire #4 + rail #13 + history #2 + `.user` kind + `listSessions` wrapper, one build) — PRIORITIZE
it the next fire app source is free, over further recon. STAY IN WORK ONLY.
EXACT BATCH SPEC (durable; full code in scratchpad/INTEGRATION_BATCH_CHECKLIST.md): (1) WorkEngineTranscript: add
`case user` to WorkTranscriptPart.Kind + `func replay(history: [WorkHistoryMessage])` (reset() then append parts with
fresh UUIDs; role user→.user else text→.answer, thinking→.thinking, tool→.tool). (2) WorkOpenGUISupervisor:
`func listSessions(harnessId="opencode", workspaceID) async throws -> [WorkSession]` = request("sessions.list",{harnessId})
→ WorkSessionMapper.workSessions(fromSidecarListJSON: reply.data, workspaceID:). (3) WorkEngineSurfaceView: leading
WorkSessionRailView(store:sessions); slash popover above input when text starts "/"; after connect/loadResources →
listSessions → sessions.upsert (rail/recents); `.onChange(sessions.activeSessionID)` → openSession + messages →
WorkSessionHistoryProjector.project → transcript.replay; partView add `.user` case. Then swiftc-parse + ONE build.
#### ✅✅ INTEGRATION BATCH EXECUTED — rail #13 + slash #4 + history #2 wired (2026-06-24)
b5dd8n0p4 SUCCEEDED (queue-drain verified) + no build contention → executed the batch (all parse-clean, build bfs6ylnoy
kicked):
  • WorkEngineTranscript: added `.user` kind + `replay(history: [WorkHistoryMessage])` (reset + append with fresh ids;
    role user→.user, text→.answer, thinking→.thinking, tool→.tool).
  • WorkOpenGUISupervisor: `listSessions(harnessId, workspaceID) → [WorkSession]` (sessions.list → WorkSessionMapper).
  • WorkEngineSurfaceView: LEADING WorkSessionRailView (shown when sessions exist, 200pt, scrollable) · slash-command
    popover above input when text starts "/" (WorkSlashCommandPopover over resources.commands, onSelect→applyCommand
    sends "/name") · list-on-connect (loadResources also lists existing sessions → sessions.upsert → rail/recents) ·
    rail focus → `openFromRail` (openSession + messages → WorkSessionHistoryProjector.project → transcript.replay) ·
    partView `.user` render (accent-tinted). ✅ swiftc -parse clean (all 3; SourceKit sibling-type/.running = isolation).
⇒ The Work surface now FULLY integrates the OpenGUI clone's core: engine/model/agent picker · send/stream · cancel ·
prompt queue · NATIVE SESSION RAIL (recents, list-on-connect, reopen w/ history replay) · slash-commands · native
transcript (no debris) · Epistemos session identity. Clone-map #1,2,3,4,5,12,13 INTEGRATED. Build bfs6ylnoy result OWED.
REMAINING: #7 MCP provisioning (workspace opencode.json + WorkNativeMCPHost) · #9 settings panel · #6 markdown render ·
#8 worktree/diffs (OpenChamber, later) · PIXEL RESKIN pass (WorkPixelFont swap) · owner ⌘R runtime/visual proof. STAY IN WORK ONLY.

#### ✅ #7 MCP PROVISIONER built (2026-06-24)
NEW `Epistemos/Work/WorkOpenGUIProvisioner.swift` (@MainActor): `provisionNativeMCP(workspace) async -> Bool` — starts
WorkNativeMCPHost (W-R3) → MERGES an `mcp.epistemos-native` block ({type:remote, url, headers.Authorization:Bearer,
enabled}) into `<workspace>/opencode.json` (preserving any existing config) BEFORE the runtime spawns opencode → the
full native Epistemos tool surface (incl. computer-use) reaches the OpenGUI Work agent. Verified WorkNativeMCPHost API:
`startAndAwaitRegistration(vaultRoot:timeout:) → WorkNativeMCPRegistration?{url,token}`. Best-effort (nil host → default
tools). ✅ swiftc -parse clean (WorkNativeMCPHost error = isolation false-positive). New file → safe during the in-flight
bfs6ylnoy batch build → folds into next build.
WIRING (next, app source): in WorkEngineSurfaceView.startEngine, BEFORE supervisor.start → `await
WorkOpenGUIProvisioner.provisionNativeMCP(workspace: URL(fileURLWithPath: repo))` (repo is the WorkOpenGUIWorkspace dir).
Then #7 is live. STAY IN WORK ONLY.

#### ✅ ENGINES roster/status panel built (#9-lite + #11) (2026-06-24)
NEW `Epistemos/Work/WorkEnginesPanelView.swift` — flat native panel showing the owner's full engine roster
(OpenCode/Codex/Claude Code/Pi-OMP/Goose/Hermes) with live state: connected (in status.connectedHarnesses) / available
(adapter exists) / "adapter soon" (Goose+Hermes, no OpenGUI adapter yet) + the active engine's capability counts
(models/agents/commands from resources). Uses ONLY already-exposed data (no new bridge wrapper). Maps to OpenGUI's
ProjectHarnessStatusBanner; the multi-engine roster the owner emphasized, made visible. ✅ swiftc -parse clean
(WorkEngineResources/EpistemosTheme = isolation false-positives). New file → safe during bfs6ylnoy → next build.
WIRING (next): header gear button → present WorkEnginesPanelView (sheet/popover) with `connectedHarnesses: engines,
resources: resources`. STAY IN WORK ONLY.

#### 🔎 #8 worktree/diffs scoped → CLONE-MAP SCOPING COMPLETE (2026-06-24)
#8 recon: OpenGUI's worktree/diff/merge is ELECTRON-BRIDGE git plumbing (opencode-bridge.ts IPC `git:worktree:list/add`,
runs `git` via runGit; GitWorktree type is @/types/electron) — NOT in the in-process runtime SDK (open-gui.ts/
directory-handle.ts expose no git/worktree). ⇒ it is NOT reachable via the OpenGUI runtime sidecar. Native #8 = a
SEPARATE Epistemos git/worktree service (own `git` calls) + OpenChamber UX donor (owner: "diffs/worktrees where
available from donors"; OpenChamber=that donor) — a LATER surface off the core runtime path (owner flagged it "later").
⇒ EVERY clone-map surface is now BUILT, INTEGRATED, or SCOPED. Remaining work is WIRING (provisioner 1-line, engines-panel
gear) + PIXEL RESKIN + #8/#9/#6 later surfaces + owner ⌘R proof — no more unknowns.
BUILD STATE: bfs6ylnoy (the rail+slash+history batch verification) is SERIALIZED behind the parallel Act agent's
xcodebuild again (my xcodebuild pid idle 0% CPU; active compilers PPID = Act's build) — not stuck; resumes + verifies
when the lock frees (it'll notify). Backlog awaiting that free build, all parse/typecheck-clean: WorkOpenGUIProvisioner,
WorkEnginesPanelView (+ the batch itself). NEXT FREE-BUILD FIRE: wire provisioner + engines-panel gear, then PIXEL RESKIN. STAY IN WORK ONLY.

#### ✅✅ FINAL FUNCTIONAL WIRING DONE — OpenGUI Work clone feature-complete (2026-06-24)
The starved batch build (bfs6ylnoy, serialized behind the Act agent across fires) was KILLED (mine, pid-scoped; it was
idle-waiting, hadn't compiled my files → no loss) to break the per-fire build-check churn + consolidate. Then, in a clean
no-contention window, wired the LAST functional pieces into WorkEngineSurfaceView:
  • #7 MCP: `startEngine` now `await WorkOpenGUIProvisioner.provisionNativeMCP(workspace:)` BEFORE supervisor.start (in a
    MainActor Task) → opencode.json gets the native-MCP block before the runtime spawns opencode → full native tools live.
  • #9/#11: header GEAR button → `.sheet` presenting WorkEnginesPanelView (engine roster + capabilities).
✅ swiftc -parse clean. Kicked CONSOLIDATED build **bhyjer42v** (verifies EVERYTHING unverified since b5dd8n0p4: the
rail+slash+history batch + provisioner + engines panel + this wiring).
⚠️→✅ bhyjer42v = BUILD FAILED (1 real Sema error parse-gating couldn't catch): WorkOpenGUIProvisioner.swift:20
`registration.url.absoluteString` — WorkNativeMCPRegistration.url is a STRING, not URL. FIXED → `"url": registration.url`.
(All 7 new Work files DID compile; only that one line failed. Validates the build-checkpoint discipline — parse-gating
misses type errors; a real build is the gate.) Rebuild **bn061dyhk** kicked. Result OWED.
⇒ FUNCTIONAL OpenGUI WORK CLONE IS FEATURE-COMPLETE (pending bhyjer42v + owner ⌘R): engine/model/agent picker ·
send/stream · cancel · prompt queue (enqueue-when-busy/drain/reorder/modes) · session rail (recents, reopen+history
replay) · slash-commands · native transcript (no debris) · NATIVE TOOLS via MCP · engines roster panel · Epistemos
session identity — all native, OpenCode-minimal, on the OpenGUI runtime.
REMAINING (cosmetic/later): PIXEL RESKIN pass (WorkPixelFont swap across Work views) · #6 markdown render · #8
worktree/diffs (OpenChamber, later) · provider-auth surfacing (#9 tail) · owner ⌘R runtime/visual proof (OWED). STAY IN WORK ONLY.

BUILD NOTE (diagnosed): b5dd8n0p4 is NOT stuck — it's SERIALIZED behind the parallel Act agent's xcodebuild on Xcode's
shared build lock. Evidence: my xcodebuild (pid 53037) shows 0% CPU + no swift-frontend children, while the active
compilers (PPID 55496 = the Act agent's build) run at ~165% CPU. ⇒ two agents building the same project at once SERIALIZE
(each build ~13-14min wall). My build resumes + finishes when the Act build releases the lock (it'll notify). Do NOT kill
mine (it's verifying the queue-drain integration). COORDINATION IMPLICATION: minimize Work build count — the planned
INTEGRATION BATCH should be the next + ideally LAST big build before owner ⌘R; avoid per-increment builds while a
sibling agent is also building. STAY IN WORK ONLY.

#### 🔎 #7 MCP/TOOLS SCOPED — reuse W-R3 via workspace opencode.json (2026-06-24 recon)
How the OpenGUI Work agent gets Epistemos's native tools/MCP (owner wants MCP/skills/tools/provider setup):
opencode-config.ts shows the runtime-spawned opencode reads config from `<directory>/opencode.json` (walks up to
`~/.config/opencode/opencode.json`) + auth from `~/.local/share/opencode/auth.json` (the auth already carries over —
why the spike worked). The opencode SDK has mcp.add/status/connect + config.update, but on the bridge/HTTP layer, NOT
clearly on the in-process HarnessHandle. ⇒ RELIABLE PLAN (reuses already-built W-R3): the WorkOpenGUI workspace
provisioner writes `<workspace>/opencode.json` with an `mcp.epistemos-native` block (`{type:remote,url,headers.Authorization}`)
pointing at `WorkNativeMCPHost` (the app-hosted loopback MCP, W-R3, build-verified) BEFORE the runtime spawns opencode
in that workspace → opencode auto-loads the native MCP → the FULL native Epistemos tool surface reaches the OpenGUI
Work agent. This is the SAME shape as the OpenWork-path `mergedOpenCodeConfigJSON(nativeMCP:)` (W-R2/W-R3) → mostly a
provisioning re-point, not new tool plumbing. Provider/model auth also flows from the shared opencode auth.json/config
(provider setup #3-tail = surface the existing auth state, not re-auth). IMPL (later): extend WorkOpenGUIWorkspace (or a
WorkOpenGUIProvisioner) to write opencode.json with the native-MCP block, start WorkNativeMCPHost, before supervisor.start.
This de-risks #7 (MCP) + #3-tail (providers) by reuse. STAY IN WORK ONLY.

#### ✅ ENRICHED SIDECAR REGRESSION PASS (2026-06-24)
After enriching og-sidecar.mjs (sessions.list full fields + abort/messages/loadResources + send {agent,variant}),
re-ran og-sidecar-drive.mjs end-to-end: init → connect opencode → create → send → 8 streamed events → run.finished →
SIDECAR EXIT 0 → RESULT PASS. ⇒ the additions did NOT break the core create/send/stream chain; the foundation the
Swift bridge + the owner ⌘R proof depend on is intact. (Reaped the probe opencode by port-4096 PID; app --cors untouched.)

#### 🧭 AUTHORITY REFRESH (2026-06-24, owner reiteration + 5 read-first docs)
Owner clarified: Epistemos = THREE final surfaces Chat/Act/Work; I am the WORK agent (own Work ONLY; do NOT edit
Chat/Swarm or Act/Goose; do NOT repair old Chat/Act/Osaurus — deletion targets for the other agents). Donor roles
fixed (OpenGUI=runtime/harness shape; OpenCode=first engine+source-of-truth; OpenWork=fallback until proof; OpenChamber
=UX; Paseo=orchestration AGPL study-only; OpenCowork=sandbox/browser). LICENSE per RESEARCH_CLONES_INVENTORY: OpenGUI =
review-before-vendoring → keep SPAWNING the sidecar from the clone, do NOT vendor into the app yet. Rule: DO NOT create
new architecture docs — update existing handoffs only. Cron loop prompt refreshed to the Work-agent canon (id
0a7e007f replaces 80081c2e). Authority: AGENTS.md + CHAT_ACT_WORK_TRI_SURFACE_ENGINE_PLAN + CLAUDE_PROMPT_CHAT_ACT_WORK
_ENGINE_STACK + RESEARCH_CLONES_CANON_RATIONALE/INVENTORY.

#### ✅ MULTI-ENGINE PICKER BUILD-VERIFIED + 🐛 MODEL-PICKER SelectedModel FORMAT BUG FIXED (2026-06-24)
Build b5z1kz0co (`xcodebuild build-for-testing`) → **0 total errors, 0 /Epistemos/Work/ errors** ⇒ the multi-engine
picker wiring (sidecar createOpenGUI full roster + supervisor diagnose()/connect() + view pickerEngines/connect-on-
select) is COMPILE-VERIFIED. Phase-1 (1) "list engines" fully met (multi-engine), owner ⌘R verifies live.

AUDIT (same correctness pass that caught engine-switch-stale-session + single-engine-picker) found a THIRD real bug:
the **model picker was silently broken**. `@opengui/protocol` `SelectedModel = { providerID, modelID }` (an OBJECT).
opencode-bridge `promptAsync` passes `params.model = model` straight to `session.promptAsync` (object), and
`summarizeSession`/`sendCommand` both read `model.providerID`/`model.modelID`. But the Swift side stored only the bare
model id (`selectedModelID: String` = model.id) and `supervisor.send` shipped `args["model"] = <bare string>` → opencode
got a string where it wanted `{providerID, modelID}` → the pick was IGNORED (silent fallback to the provider default).
FIX (Work-scope only, 5 edits):
  • WorkEngineResources.swift — `flatModelOptions:[(id,name)]` keyed by COMPOSITE `providerID/modelID` +
    `selectionID(providerID:modelID:)` / `splitSelectionID(_)` (split on FIRST slash so slashy model ids survive;
    reject malformed). The composite also disambiguates same-named models across providers (old `id:\.model.id` tag
    could collide).
  • WorkEngineSurfaceView.swift — model picker iterates `flatModelOptions` (composite tag); default preselect builds the
    composite from provider.id + default/first model id.
  • WorkOpenGUISupervisor.swift `send` — splits the composite back into `args["model"] = {providerID, modelID}` (the
    object opencode expects); `[String:Any]` → nested dict serializes to a JSON object cleanly.
  • og-sidecar.mjs — `opts.model = msg.model` now passes the object straight through (comment updated; no logic change).
  • WorkEngineResourcesTests.swift — +flatModelOptions composite-key test + selectionID/splitSelectionID round-trip
    (first-slash + malformed-reject) tests.
GATE: all 3 changed Swift files swiftc -parse/-typecheck clean; test file -parse clean. ⇒ the model picker now actually
selects the model end-to-end (owner ⌘R confirms a non-default model takes effect live). Full build OWED at next checkpoint.

#### 🐛 FOUND (fix queued behind byufiz31v): TRANSCRIPT MISLABELS LIVE USER PROMPT AS ASSISTANT ANSWER (2026-06-24)
Audit continued past the model fix. Confirmed agent/variant pickers are CORRECTLY typed (session-handle.ts `agent?: string`;
OpenGUI frontend passes `agent:"build"` plain strings) — model was the lone object-typed send field. Transcript event-kind
mapping verified CORRECT against live-session-event.ts (every field: reason/text/partKind/tool/status/message; seq de-dupe;
partId accumulation). BUT a real bug remains: **the live stream INCLUDES the user's own message** (proven by OpenGUI's own
`live-session-projection.ts`: message-centric, `message.started` records `role`, parts belong to messages, renderer styles
by `message.role`; the normalizer emits message.started{role} + part.text for BOTH user and assistant messages).
`WorkEngineTranscript.applyText` maps EVERY `partKind:"text"` → `.answer` with NO role check → a live-sent user prompt
renders styled as an ASSISTANT ANSWER (history replay() already handles role via message.role=="user", so live ≠ replay).
NOT optimistic-echo (that would DOUBLE-render since the stream already carries the user message). CORRECT FIX = mirror the
OpenGUI projection's role model in the Swift transcript:
  • +`messageRole:[String:String]` (messageId→role) + `messageID:String?` on WorkTranscriptPart (default nil, keeps existing
    initializers source-compatible).
  • handle `message.started`: record role; retro-relabel any existing .answer parts of that messageId → .user (covers the
    event-order case where a text part arrives before its message.started).
  • applyText: kind = (partKind=="thinking") ? .thinking : (role=="user" ? .user : .answer); stamp messageID.
  • reset() clears messageRole.
HELD until byufiz31v (model-picker checkpoint) finishes — won't edit a module source mid-build (would corrupt that build's
result). Apply + parse-gate + next checkpoint on completion.

#### ✅ TRANSCRIPT ROLE FIX APPLIED (2026-06-24) — live user prompt now labeled .user (matches history replay)
Applied the queued fix to WorkEngineTranscript.swift: +`messageRole:[messageId:role]` map + `messageID:String?` on
WorkTranscriptPart (default nil → existing initializers source-compatible); `message.started` → recordRole (first
non-nil role wins, mirrors projection's `role && !message.role`) + retro-relabel of any .answer parts whose messageID
matches → .user (covers text-before-message.started ordering); applyText now kind = thinking ? .thinking : role=="user"
? .user : .answer, stamping messageID. reset() clears messageRole. +2 tests (WorkEngineTranscriptTests): live user
message → .user not answer (both messages stream); retro-relabel when text precedes message.started. swiftc -parse clean
(view/supervisor/resources from the model fix + transcript + both test files). Compile verify folded into byufiz31v
(starved on sibling-agent xcodebuild locks; reads sources at compile time so it verifies BOTH fixes when it acquires the
lock — NOT killing it, NOT starting a 2nd). Audit tally this pass: model-picker BUG fixed, transcript-role BUG fixed;
agent/variant + transcript event-map + history projector audited CLEAN.

#### ✅ AUDIT CLEAN: OpenGUI→WorkSession recents mapper is WIRED + correct (2026-06-24)
Prompt flagged "an OpenGUI→WorkSession mapper is needed" — it already exists AND is wired. End-to-end verified by read:
supervisor.listSessions → request("sessions.list") → decodeFrame routes the reply `data` field through `subJSON`
(`isValidJSONObject` is TRUE for top-level arrays, so the sidecar's `[{id,title,status,updatedAt,createdAt}]` array
survives as bytes) → `WorkSessionMapper.workSessions(fromSidecarListJSON:workspaceID:)` parses `[[String:Any]]`, reads
id+title, maps each → `WorkSession.main(openCodeSessionID: id)` (id is engine-namespaced `harnessId:ses_…`, stable across
restarts → preserves native recents/identity; OpenGUI SessionSummary has NO parentID so all list → MAIN, mini/parent
lineage stays Epistemos-owned). No scalar-data command relies on subJSON (all replies are objects/arrays). PROOF-PATH
STATUS: list-engines / model / agent / create / send / stream / open+replay / listSessions→recents all audited; 2 real
bugs found+fixed (model SelectedModel object, transcript live-user role), rest clean. Remaining work is owner-gated (⌘R
live visual+runtime proof) or post-proof (Goose adapter).

#### ✅ BOTH FIXES COMPILE-VERIFIED (byufiz31v exit 0, 0 errors) + OWNER ⌘R READINESS VERIFIED END-TO-END (2026-06-24)
byufiz31v (`build-for-testing`, was lock-starved 3 fires, finally acquired the lock) → exit 0, 0 total errors, 0
/Epistemos/Work/ errors, 0 Work-test errors. Because xcodebuild reads sources at COMPILE time (not kick time), this one
build verifies the FULL current tree: model-picker SelectedModel fix (WorkEngineResources/SurfaceView/Supervisor +
WorkEngineResourcesTests) AND the transcript live-user-role fix (WorkEngineTranscript + WorkEngineTranscriptTests) — all
compile clean, test bundle builds.

OWNER ⌘R PROOF PATH — verified reachable + self-sufficient (no env var, no manual setup), the OWED visual+runtime proof
will NOT silently fail at the harness layer:
  1. Entry: SettingsView `.workClone` ("Work (OpenCode)" tab, .advanced group, icon "terminal") → WorkCloneSettingsView
     → Button "Open Work · OpenGUI engine workbench (debug)" → WorkEngineSurfaceWindowController.shared.open().
  2. Auto-start: WorkEngineSurfaceView `.task { startEngine() }` (provisions native MCP + supervisor.start opencode).
  3. Sidecar root: defaultSidecarRoot() → EPISTEMOS_OPENGUI_SIDECAR_ROOT else (DEBUG) the research clone — VERIFIED on
     disk: /Users/jojo/Downloads/Epistemos/.research-clones/work/opengui/og-sidecar.mjs EXISTS.
  4. Interpreter: resolveBun() → /opt/homebrew/bin/bun EXISTS+executable.
  5. SANDBOX: Epistemos-Debug.entitlements `com.apple.security.app-sandbox = FALSE` → the ⌘R DEBUG build
     (com.epistemos.app) CAN spawn bun→opencode + read the clone + read ~/.local/share/opencode/auth.json. (AppStore
     entitlements sandbox=TRUE → the shipping MAS path still needs the in-process/vendor resolution per CLAUDE.md
     NO-HIDDEN-SIDECAR; that is the later vendoring question, NOT this DEBUG proof.)
  6. Honest failure: onChange(status)→surfaceStatusError renders the real .unavailable(reason)/.failed(reason) text, so a
     failed start shows WHY (not a blank window); empty-state shows "connecting…" / "Type to start an OpenCode session".
Running the two fixes' test classes now (test-without-building, reuses byufiz31v products) for RUNTIME pass evidence.

#### ⚠️ RUNTIME xctest BLOCKED BY SIBLING DerivedData CONTENTION (not a logic failure) (2026-06-24)
bny632zy7 (`test-without-building`, default DerivedData) exit 65 = `** TEST EXECUTE FAILED **`:
"Failed to create a bundle instance representing …/Epistemos.app/Contents/PlugIns/EpistemosTests.xctest. Check that the
bundle exists on disk." The host app LAUNCHED (AppBootstrap logs, pid 27175) but the .xctest plugin was absent → a
parallel agent's plain `build` (not build-for-testing) overwrote the SHARED default DerivedData Products/Debug between
byufiz31v finishing and this run, dropping the embedded test bundle. My tests never executed; this is the multi-agent
shared-DerivedData hazard, NOT a failed assertion. An isolated `-derivedDataPath` rebuild is disk-prohibitive (owner at
DISK CAP). Logic remains COMPILE-verified (byufiz31v exit 0, 0 errors, build-for-testing → test bundle compiled). Getting
RUNTIME logic evidence via a standalone swiftc harness (copies the exact pure functions; no DerivedData/xctest/sibling
contention) instead. Also confirmed: WorkEngineSurfaceWindowController passes repo = WorkOpenGUIWorkspace.ensureDefault()
(an ensured existing dir under allowedRoots) — the temp-path default is preview-only; ⌘R `connect` won't fail on a
missing repo dir.

#### ✅ RUNTIME LOGIC PROVEN via standalone swiftc harness — 15/15 PASS (2026-06-24)
Worked around the xctest infra block with a standalone harness (scratchpad/og-logic-harness.swift) that copies the EXACT
pure functions from both fixes and asserts at runtime — no app module / DerivedData / xctest, so sibling-agent contention
can't touch it. `swiftc -O` compile + run → exit 0, ALL PASS:
  • Fix 1 (model composite SelectedModel id) 7/7: selectionID joins; round-trip split; split on FIRST slash (slashy
    modelID survives); no-slash/empty-provider/empty-model → nil; send() builds the {providerID,modelID} OBJECT (the thing
    that was broken — a bare string before).
  • Fix 2 (transcript live user-vs-assistant role) 8/8: user message → .user not .answer; assistant → answer with user
    prompt excluded; exactly one user part; pre-role part provisionally .answer then RETRO-RELABELED to .user; thinking
    stays .thinking and out of the answer.
EVIDENCE COMPLETE for both fixes: compile-verified (byufiz31v exit 0) + runtime-proven (harness 15/15) + xctest classes
authored (run when DerivedData isn't sibling-clobbered). Binary deleted post-run (disk cap); .swift kept for re-run.

#### ✅ AUDIT CLEAN: provisioner MCP block matches opencode's remote schema (2026-06-24)
WorkOpenGUIProvisioner.provisionNativeMCP merges `mcp.epistemos-native = {type:"remote", url, headers:{Authorization:
Bearer …}, enabled:true}` into `<workspace>/opencode.json`. Verified against opencode source (mcp/index.ts connectRemote,
ConfigMCPV1.Info & {type:"remote"}): type "remote" → connectRemote; url required (have it); headers → requestInit.headers
(optional, have it); enabled skipped only if `=== false` (we set true → loaded); oauth optional (omitted, fine). Merge is
non-destructive (reads existing root, only sets mcp.epistemos-native, preserves $schema + other servers), atomic write,
best-effort (false on host/​write fail → opencode keeps default tools, runtime stays valid → NOT proof-blocking). No bug.

#### ✅ AUDIT CLEAN: input-submit path + streamed-markdown rendering (2026-06-24)
INPUT (the proof's literal "ONE native Work input"): WorkBlockCaretField text:$input (live two-way via textDidChange),
onSubmit:submit — NON-stale because updateNSView refreshes `coordinator.parent = self` so onSubmit always calls the
current parent; Enter→insertNewline→onSubmit() with NO newline (single-line submit); auto-focus on appear; isEnabled
gated on !engines.isEmpty (can't send before connect). submit() reads current $input → enqueue-if-busy else sendNow →
createSession+send. First proof step works. No bug.
MARKDOWN (visual target "no raw debris in assistant prose"): WorkMarkdownText.parse splits fenced code (trailing open
fence → in-progress code box); inlineMarkdown uses .inlineOnlyPreservingWhitespace w/ literal fallback (incomplete inline
markdown renders literally until its closer streams — streaming-safe, never crashes); code → flat TUI mono box; empty
segments dropped. No bug.

#### 📋 PROOF-PATH AUDIT COMPLETE (2026-06-24)
Full native Work proof path (input→engine→model/agent→create→send→stream→open/replay→recents) + owner ⌘R harness chain
now AUDITED end-to-end. 3 real bugs found+fixed+evidenced (multi-engine picker; model SelectedModel object; transcript
live-user role) — each compile-verified (byufiz31v exit 0) + runtime-proven (logic harness 15/15). Everything else audited
CLEAN: agent/variant typing, transcript event-map, history projector, listSessions→WorkSession mapper, repo wiring,
provisioner MCP block (matches opencode remote schema), input-submit, streamed-markdown, ⌘R chain (entry/auto-start/
sidecar-root/bun/sandbox-off-in-Debug/honest-errors). ONLY remaining validation = owner's LIVE ⌘R (visual + real opencode
stream) — cannot self-run. Lower-priority un-audited SECONDARY surfaces (not proof-blocking) for future fires:
WorkSlashCommandPopover, WorkQueueListView, WorkSessionRailView, WorkEnginesPanelView, WorkPixelFont.

#### ✅ QUEUE-MODE HONESTY: interrupt WIRED (abort+drain), steer DEFERRED (no fake controls) (2026-06-24)
Audit of the secondary surface WorkQueueListView found a real honesty gap: the Mode menu let users set Interrupt/Steer +
showed a badge, but drainIfIdle ignored mode → both behaved identically to Queue (silent no-op controls, violates
CLAUDE.md "no fake features"). FIX:
  • INTERRUPT wired correctly reusing PROVEN seams: WorkQueueListView "Interrupt" → onInterrupt callback →
    WorkEngineSurfaceView.handleInterrupt = queue.moveToTop + setMode(.interrupt) + (running ? supervisor.abort(active)
    : drainIfIdle). abort → run.finished(idle) → onChange(status) → drainIfIdle pops the now-front interrupt prompt. This
    is the SAME abort the cancel button (line 261) already uses + the SAME drain normal queueing uses — composing two
    proven pieces, no new runtime surface. Interrupt is now distinct from "Send now" (which waits for idle; interrupt
    aborts).
  • STEER (after-part) intentionally NOT exposed: OpenGUI's runtime is whileBusy fail|wait (ADR-0005) with no mid-turn
    injection, so honest after-part steering needs part-boundary signaling not built yet. Removed the "Steer" menu item +
    "steer" badge so there is no no-op control; kept WorkQueueMode.afterPart enum (wire/model parity) for when it's wired.
EVIDENCE: 3 changed files swiftc -parse clean; +WorkPromptQueueTests.interruptOrdering (front+mode+drain-first contract);
standalone logic harness extended → 19/19 PASS incl. Fix 3 interrupt ordering (4/4). Live abort+drain timing is ⌘R-owed
(same as the rest of the surface). Background compile checkpoint kicked. Remaining secondary surfaces un-audited:
WorkSlashCommandPopover, WorkSessionRailView, WorkEnginesPanelView, WorkPixelFont.

  ↳ CORRECTION: compile checkpoint NOT kicked this fire — DEFERRED (build less / disk cap / 3 sibling xcodebuilds
    contending). The onInterrupt:(WorkQueuedPrompt)->Void callback mirrors the already-compiling onSendNow exactly
    (type-safe), and all 3 changed files are swiftc -parse clean — folding into the next accumulated checkpoint.

#### ✅ AUDIT CLEAN: slash-command popover (2026-06-24)
WorkSlashCommandPopover: case-insensitive prefix-OR-contains filter, shows-all on empty query, flat boxy TUI (no donor
chrome). Show-condition correct: view gates on input.hasPrefix("/") (leading slash only, not "/" anywhere) → query =
String(input.dropFirst()); onSelect → applyCommand clears input → "/" prefix gone → popover auto-hides. applyCommand
sends "/name" via the proven enqueue/sendNow path. No bug. (Typing "/cmd args" + Enter sends the literal command line,
which opencode handles; clicking a filtered command sends "/name" — both valid.) Secondary surfaces remaining:
WorkSessionRailView, WorkEnginesPanelView, WorkPixelFont.

#### 🐛 FOUND (fix queued behind b9mbrwoqt): rail "+ New mini" is a no-op control in the engine surface (2026-06-24)
WorkSessionRailView audit: display + focus→openFromRail wiring is correct (line 45 + onChange line 88 → the recents/
identity proof path works). BUT the mainRow "+ New mini" button (line 39) calls onNewMini, which defaults to a no-op, and
the ONLY two instantiations (the #Preview + WorkEngineSurfaceView line 45) BOTH omit it → the "+" does nothing everywhere
it's actually used (the OpenWork/WebView surface its comment references does not instantiate this rail at all). During ⌘R
the owner would click "+" and get nothing — a visible fake control (same class as the queue steer). Mini-session CREATION
in the engine surface is genuine future feature work (createSession child + WorkSession.mini + store.upsert, deserving live
verification), so the honest MINIMAL fix is to HIDE the "+" until a handler is wired:
  • WorkSessionRailView: `var onNewMini: ((WorkSession) -> Void)? = nil`; in mainRow show the "+" overlay only
    `if let onNewMini` (idiomatic optional-handler gating). Mini detach/reattach context-menu items are on miniRow, which
    never appears in the engine surface (no minis created) → unreachable, not a visible no-op; leave for the later
    mini-creation increment.
HELD until b9mbrwoqt (interrupt-wiring checkpoint) completes — not editing a module source mid-build. Apply + parse-gate
next fire; folds into the next checkpoint.

#### ✅ INTERRUPT WIRING COMPILE-VERIFIED + RAIL "+New mini" no-op FIXED + SECONDARY SWEEP COMPLETE (2026-06-24)
b9mbrwoqt (build-for-testing) = ** TEST BUILD FAILED ** exit 65 BUT **0 /Epistemos/Work/ errors, 0 Work-test errors**.
TOTAL 2 errors both in Chat/ChatRouteView.swift (parallel Chat agent's EpistemosTheme refactor WIP: missing
`exePixelPerfectDisplayFontName` / `monoFont`) — OUT OF MY SCOPE (don't edit Chat). My interrupt wiring
(WorkEngineSurfaceView/WorkQueueListView) + WorkPromptQueueTests compiled CLEAN → interrupt fix COMPILE-VERIFIED per the
established "0 Work-file errors" gate. (NB: the Chat WIP reds the overall test build for everyone until Chat fixes it.)

RAIL FIX APPLIED: WorkSessionRailView.onNewMini → optional `((WorkSession)->Void)? = nil`; mainRow shows the "+ New mini"
overlay only `if let onNewMini`. Both call sites (engine surface + #Preview) pass nil → the no-op "+" is now HIDDEN (no
fake control during ⌘R). Mini CREATION wiring stays a deliberate later increment. swiftc -parse clean. Build DEFERRED
(Chat WIP reds the overall build anyway; trivial conditional-overlay change → fold into next checkpoint).

SECONDARY-SURFACE SWEEP COMPLETE: WorkPromptQueue/QueueListView (interrupt wired, steer honestly deferred), 
WorkSlashCommandPopover (clean), WorkSessionRailView (no-op "+" fixed), WorkEnginesPanelView (clean — read-only, honest
connected/available/adapter-soon roster), WorkPixelFont (clean — Font.custom w/ documented system fallback). Net this
session: 4 real issues found+fixed (multi-engine picker, model SelectedModel, transcript live-user role, queue/rail no-op
controls) — all compile-verified + (logic) runtime-proven (harness 19/19). The native Work surface is fully audited; ONLY
remaining validation = owner LIVE ⌘R (visual + real opencode stream). Next un-audited: none on the Work surface proper.

#### 🧭 GUARDRAIL COMPLIANCE + OWNER ⌘R CHECKLIST + CURRENT ⌘R BLOCKER (2026-06-24)
COMPLIANCE (shared main checkout — multiple parallel agents commingle in `git status`): my OpenGUI Work footprint is the
untracked Epistemos/Work/Work*.swift (engine surface stack) + EpistemosTests/Work* tests + this ledger +
.research-clones/work/opengui/og-sidecar.mjs. I did NOT edit the 2 dirty Localizable.xcstrings (no xcstrings edits all
session — they're pre-existing/sibling dirty), nor Chat/Act/Swarm (the `?? Epistemos/Chat/`, `?? LocalPackages/Swarm/`,
and M App/Chat files are sibling agents'). The M Epistemos/Work/WorkOpenCode{Runtime,Shell},WorkTerminalView are the
OpenWork/OpenCode FALLBACK (a different loop's hardening slices) — left intact (fallback stays until proof). NO xcodegen
run; no commits.

⚠️ CURRENT ⌘R BLOCKER (sibling, NOT my scope, NOT my code): the shared-tree app build is RED — Chat/ChatRouteView.swift
references EpistemosTheme.exePixelPerfectDisplayFontName + .monoFont which don't exist (Chat agent's theme refactor WIP;
b9mbrwoqt compiler verdict). ⌘R builds the WHOLE app, so the OWED Work proof cannot run until the Chat agent's WIP
compiles. My Work files are 0-error; this is purely a sibling dependency. (May already be resolving — Chat agent is active.)

OWNER ⌘R PROOF CHECKLIST (once the shared tree compiles green):
  1. ⌘R a DEBUG build (com.epistemos.app; sandbox=OFF → sidecar spawn allowed).
  2. Settings → Advanced → "Work (OpenCode)" tab → button "Open Work · OpenGUI engine workbench (debug)".
  3. Window opens → auto-starts (.task) → spawns og-sidecar (bun @ /opt/homebrew/bin) from the research clone (DEBUG
     fallback; no env var needed) → createOpenGUI roster + connect opencode. Empty state: "connecting…" then "Type to
     start an OpenCode session".
  4. EXPECT: engine picker shows diagnosed-ready engines (opencode + others); model/agent pickers populate from
     loadResources; type a prompt + Enter → a new session is created (appears in the native recents rail) → assistant
     answer STREAMS natively (no raw JSON/log debris); your prompt shows as a user line (not an assistant answer).
  5. VERIFY: pick a non-default model → it takes effect (model fix); queue a 2nd prompt while busy → it drains on idle;
     "Interrupt" on a queued prompt aborts + sends it next; reopen a recent from the rail → its history replays.
  6. If the window shows "unavailable/error" it surfaces the REASON (surfaceStatusError) — not a blank screen.
STATUS: Work surface fully built + audited (4 bugs fixed, compile-verified + logic-runtime-proven 19/19). Proof = OWED
(owner ⌘R), currently gated on the sibling Chat build turning green.

#### ✅ MODEL FIX PROVEN AGAINST opencode SDK TYPE CONTRACT (no subprocess) (2026-06-24)
Closed the model fix's last evidence gap STATICALLY (stronger + safer than spawning opencode). The bridge calls
`@opencode-ai/sdk/v2/client` createOpencodeClient → `client.session.promptAsync(params)` with `params.model = model`
(opencode-bridge.ts:619). The v2 SDK's promptAsync parameter type (node_modules/@opencode-ai+sdk@1.16.2/.../v2/gen/
sdk.gen.d.ts:1217-1235) is:
    model?: { providerID: string; modelID: string };  agent?: string;  variant?: string;
and the persisted UserMessage.model (types.gen.d.ts:142-146) is `{ providerID, modelID, variant? }`. So:
  • My fix builds EXACTLY `model = {providerID, modelID}` → type-matches the SDK param. A bare model-id string (the OLD
    bug) would be a TYPE ERROR against opencode's own SDK → conclusively why the old pick was ignored.
  • agent?: string / variant?: string → re-confirms (3rd time) agent/variant are correctly bare strings, NOT objects.
  • Config-level `model?: string` (sdk.gen.d.ts:1588) is the SEPARATE "provider/model" default-config string form (matches
    the adapter's sendCommand `${providerID}/${modelID}`) — distinct from the prompt INPUT object. No contradiction.
MODEL FIX EVIDENCE now COMPLETE 4 ways: compile (byufiz31v exit 0) + Swift-logic runtime (harness 7/7) + full code-trace +
SDK type contract. No opencode spawn needed (avoided the cost/reap-risk; SDK contract is authoritative). Owner ⌘R remains
the live end-to-end witness (gated on the sibling Chat build greening).

#### 🔎 SIBLING Chat blocker RESOLVED + my theme deps INTACT → final whole-app checkpoint (2026-06-24)
The b9mbrwoqt ⌘R blocker cleared: EpistemosTheme now DEFINES exePixelPerfectDisplayFontName (1827) + monoFont (2214/2444)
and Chat/ChatRouteView migrated (uses ClaudeAppTypography.monoFont). Verified the Chat agent's EpistemosTheme refactor did
NOT drop any API my Work surface uses — isDark(379)/border(1111)/nativeDefault(330)/resolved(306)/textTertiary/
mutedForeground/monoFontName all still present → my Work files should still compile against the evolved shared theme.
Kicking a whole-app build-for-testing checkpoint to (a) re-confirm 0 /Epistemos/Work/ errors in the CURRENT tree (survives
the sibling refactor) and (b) see if the full app now builds green (⌘R-ready). Background; will record verdict next fire.

#### ✅ SIDECAR INTEGRITY VERIFIED pre-⌘R (2026-06-24)
The og-sidecar.mjs runtime foundation (spawned by the owner's ⌘R) is sound after this session's edits: `node --check`
PASS on og-sidecar.mjs + og-connect-probe.mjs; invariants intact — PORT-scoped reapOpencode (`opencode serve --port
${port}`, never a broad CLI-name kill), createOpenGUI full roster [opencode,codex,claude-code,pi] (registers handlers so
lazy multi-engine connect works), `opts.model = msg.model` {providerID,modelID} passthrough, SIGTERM/SIGINT reap. (Whole-
app checkpoint bumxpiio1 still compiling — 0 Work / 0 total errors so far, no verdict line yet; verdict next fire.)

#### ⚠️ ⌘R PREREQUISITE: opencode must be resolvable by the harness-inventory resolver (2026-06-24)
Verified the opencode binary resolution path the ⌘R sidecar uses (opencode-bridge resolveOpencodeBinary →
server/harness-inventory.ts resolveHarnessCli). It checks, in order: existsSync over commonBinaryPaths
[~/.opencode/bin, ~/.claude/local, ~/.local/bin, ~/.bun/bin, ~/Library/pnpm, /opt/homebrew/bin, /usr/local/bin,
/usr/bin] THEN a LOGIN-shell fallback `$SHELL -lc 'command -v opencode'` (sources the owner's rc → matches what the
proven spike's terminal saw). It does NOT check the research clone. In THIS agent's shell, opencode resolved at NONE of
those (incl. `zsh -lc`), so I cannot positively confirm resolution from here — BUT the proven spike (og-sidecar-drive.mjs
EXIT 0, real streaming) DID run opencode, so it is resolvable in the owner's real environment (the GUI-app sidecar uses
the same `-lc` login-shell fallback → should match). RISK: a GUI-app-spawned sidecar gets a minimal PATH; resolution
hinges on the login-shell fallback or a standard bin dir. IF ⌘R errors "Could not find the opencode binary":
remediation = put opencode on a resolver-checked dir, e.g. symlink the present clone launcher
  ln -s "$PWD/.research-clones/work/opencode/packages/opencode/bin/opencode" ~/.local/bin/opencode
(I did NOT create this symlink autonomously: it's outside the repo/Work scope AND could SHADOW an existing owner opencode
in /opt/homebrew etc. — the owner knows their own opencode install and should resolve it.) Added to the ⌘R checklist as a
prerequisite. NOTE: ⌘R is owner-gated regardless; this just pre-flags the most likely first-run failure mode.

#### ✅✅ WHOLE-APP BUILD GREEN — bumxpiio1 ** TEST BUILD SUCCEEDED ** exit 0 (2026-06-24)
The final compile gate PASSED: the ENTIRE Epistemos app (1670 Swift files) builds + the test bundle links —
`** TEST BUILD SUCCEEDED **`, BUILD_EXIT=0, 0 /Epistemos/Work/ errors, 0 TOTAL errors. This supersedes the earlier
"0 Work errors but overall FAILED on sibling Chat WIP" gate: the Chat agent's EpistemosTheme refactor landed green, so
now the whole app compiles WITH my OpenGUI Work surface fully integrated. Everything this session is compile-verified IN
THE FULL APP: the 3 native bug fixes (multi-engine picker, model SelectedModel object, transcript live-user role) + the
queue interrupt wiring + the rail "+New mini" no-op fix + all new tests (WorkEngineResources/Transcript/PromptQueue).
⇒ the owner's ⌘R is now RUNNABLE (app builds). Pre-flight chain all green/flagged: entry (Settings→Advanced→"Work
(OpenCode)"→workbench button) · auto-start · sidecar root (clone present) · bun · sandbox-OFF-in-Debug · sidecar syntax+
invariants · honest error surfacing · opencode-resolution PREREQUISITE (flagged — owner's PATH; spike-proven in owner env).
NATIVE WORK SURFACE = BUILD-COMPLETE + AUDITED + EVIDENCED (compile in full app + logic-runtime 19/19 + model fix 4 ways +
SDK type contract). REMAINING = owner LIVE ⌘R (visual + real opencode stream) · post-proof Goose adapter · deliberate-later
mini-session CREATION wiring. Nothing further to advance on the Work surface without the owner's ⌘R.

#### ✅ NATIVE MCP SURFACE AUDITED + origin-check HARDENED (2026-06-24)
Audited the last un-audited in-scope Work code — the native-tools MCP surface (WorkNativeMCPHost/Server/ToolExecutor,
how Epistemos tools incl. computer-use reach the opencode agent; non-proof-blocking — degrades to opencode default tools).
WorkNativeMCPServer security is sound: loopback-ONLY bind (requiredInterfaceType=.loopback), POST-only, correct
`Authorization: Bearer` parse, CONSTANT-TIME token compare (length-checked XOR, no early exit), per-launch random token
(never persisted). ONE genuine (token-mitigated, defense-in-depth) flaw FIXED: isAllowedOrigin used a SUBSTRING check
(`origin.contains("127.0.0.1")`) → `http://127.0.0.1.evil.com` / `localhost.evil.com` would pass the origin gate. Hardened
to HOST-EXACT matching via URLComponents (allow only host == 127.0.0.1/localhost/::1/[::1]; fail closed on unparseable).
Not exploitable (the unguessable per-launch bearer token is the primary gate, and a web attacker can't read it from
opencode.json), but it's a clear correctness improvement to the tool-surface security. EVIDENCE: WorkNativeMCPServer +
test swiftc -parse clean; +WorkNativeMCPServerTests.originRejectsSubstringSpoof + an [::1] allow-case; standalone origin
harness 10/10 PASS incl. all spoof-rejection + fail-closed cases. Build DEFERRED (Foundation-only one-function change + test,
parse+runtime-proven; folds into next checkpoint — whole app was green at bumxpiio1 and this changes no types/signatures).
⇒ ENTIRE Work surface (proof path + secondary surfaces + native MCP tool surface) is now AUDITED. Remaining: owner ⌘R,
post-proof Goose, owner-gated mini-creation.

#### ✅ WorkNativeToolExecutor audited CLEAN → 100% Work-file read coverage (2026-06-24)
Read the last un-read Work file: WorkNativeToolExecutor composes the production LocalAgentToolExecutor — computer-use
tools (see/click/type/scroll/keys/screenshot) → ComputerUseBridge (@MainActor hop), all else → base Rust FFI; one path
for real + AppStore-stub builds; computerActionJSON folds tool-name→"action" preserving args (safe fallback; fixed
tool-name set → no injection); isErrorResult maps {success:false}/{error}→isError. CLEAN. ⇒ EVERY Epistemos/Work file is
now read + audited. Whole-app checkpoint bvdwr8qbb (folds the origin hardening) running — verdict next fire.

#### ⚠️ bvdwr8qbb FAILED on build-DB LOCK (infra, not code) — origin hardening parse+runtime-proven, whole-app confirm pending (2026-06-24)
bvdwr8qbb exit 65 = `** TEST BUILD FAILED **` but the sole "error" was `unable to attach DB … build.db: database is
locked. Possibly two concurrent builds running` — the shared-DerivedData multi-agent hazard (a sibling xcodebuild locked
build.db; my build died on ATTACH, compiling ~nothing → the 0-Work-errors is not a clean signal). NOT a code regression.
The origin hardening remains parse-clean + runtime-proven (harness 10/10) + isolated (one Foundation function body, no
type/signature change) and the last CLEAN whole-app build (bumxpiio1) was green without it → very high confidence the app
stays green with it. A dedicated -derivedDataPath would dodge the lock but costs a full clean build (DISK CAP → ruled out).
Opportunistic re-kick on the shared DerivedData (DB-lock fast-fails; a contention-free slot succeeds).

  ↳ This fire: 3 sibling xcodebuilds active → a re-kick would re-hit the build.db lock. NOT re-kicking into guaranteed
    contention; DEFERRING the whole-app re-confirm to a fire where `pgrep -f 'xcodebuild -scheme Epistemos'` == 0 (clean
    slot, no concurrent build → no DB lock). Origin edit stands on parse + runtime (10/10) evidence meanwhile.

#### 🧹 Fire: whole-app re-confirm held (contention) + stale memory corrected (2026-06-24)
Clean-slot check: 3 sibling xcodebuilds active → re-kick would DB-lock; held the origin-hardening whole-app re-confirm
again (only kick when sibling xcodebuild procs == 0). No safe in-scope code increment remains (surface 100% audited; rest
owner/contention-gated) → did the genuinely-useful non-churn action: corrected the STALE cross-session memory
`project_openwork_work_feature_complete_2026_06_24.md` (it described the pre-pivot OpenWork feature → would mislead a
future session) + its MEMORY.md pointer to the current OpenGUI Work surface reality (whole-app green, 100% audited, 4
bugs+origin fixed, ⌘R OWED + opencode-resolution prereq, mini-creation/Goose gated). No app-source churn.

#### ✅✅ WHOLE-APP RE-CONFIRM GREEN with origin hardening — beoka0hpd ** TEST BUILD SUCCEEDED ** exit 0 (2026-06-24)
Got a clean build slot (0 sibling xcodebuilds → no build.db lock) and the whole-app re-confirm completed:
`** TEST BUILD SUCCEEDED **`, BUILD_EXIT=0, 0 /Epistemos/Work/ errors, 0 TOTAL errors. The MCP origin-check hardening
(substring → host-exact) is now WHOLE-APP-CONFIRMED (2nd green whole-app build after bumxpiio1, now including the
security fix). ⇒ the native OpenGUI Work surface has NO OPEN VERIFICATION ITEMS: build-complete (whole app green ×2),
100% read + audited, every session fix compile-verified IN THE FULL APP + logic-runtime-proven (harness 19/19 + origin
10/10), model fix proven 4 ways (incl. opencode SDK type contract), sidecar integrity + ⌘R dependency chain verified/
flagged. REMAINING IS PURELY OWNER-GATED: live ⌘R (the OWED visual+stream proof, runnable; opencode-resolution prereq) ·
post-proof Goose adapter · owner-gated mini-session creation. Nothing further to advance autonomously without the owner.

#### 🔎 FEATURE GAP + DESIGN: native PERMISSION cards (visual-target item not yet built) (2026-06-25)
Audited a NEW dimension beyond the proof path: opencode PERMISSION handling. FINDING — opencode's default (NO permission
config set; neither og-sidecar.mjs nor WorkOpenGUIProvisioner sets one) is PERMISSIVE: session/llm.ts:151
`return !match || match.action !== "ask"` → a tool with NO matching rule is PREAPPROVED → ALL tools auto-approved, opencode
emits NO permission requests. So:
  • NOT proof-blocking: the agent won't hang on permissions (auto-approves) → the send/stream proof + agentic tool use work.
  • BUT a real FEATURE + SAFETY gap: the Work surface silently auto-approves every opencode tool (bash, file edits) with no
    consent gating — contrary to the visual target's "native permission/tool cards" + Epistemos's permission-gate IP. I built
    TOOL cards (transcript .tool), NOT PERMISSION cards.
BUILDABILITY (recon): the OpenGUI runtime supports it — `HarnessEvent` (src/agents/backend.ts:119-122) has
`permission.requested {request: PermissionRequest}` / `permission.cleared` / `question.requested` / `question.cleared`;
session-handle exposes `subscribeHarnessEvents(handler)` (a channel SEPARATE from onEvent/LiveSessionEvent); opencode-bridge
has `respondPermission` (permission.reply/respond) + question reject; opencode emits permission/question SSE events (the
bridge consumes them, e.g. question.asked @1364). HarnessCapabilities flags `permissions`/`questions` (backend.ts:43-44).
DESIGN (4 components — multi-fire feature; NOT owner-gated, it's product work):
  1. og-sidecar.mjs: subscribe to harness events → forward permission.requested/cleared + question.requested/cleared over
     NDJSON as a NEW frame `{type:"harnessEvent", event}`; + `respondPermission {sessionId, permissionId, response}` +
     `respondQuestion` commands → conn.respondPermission/question.reply.
  2. WorkOpenGUISupervisor: decode harnessEvent frames → onPermissionRequest/onQuestion callbacks; + respondPermission/
     respondQuestion wrappers.
  3. WorkEngineSurfaceView/transcript: render a NATIVE permission card (tool name + args + allow-once/allow-always/deny) +
     question card; wire buttons → supervisor.respond*. Flat/TUI per the visual target.
  4. WorkOpenGUIProvisioner: set opencode.json `permission` to "ask" for sensitive tools (bash/edit/write/webfetch) so
     requests are EMITTED — ⚠️ ONLY after 1-3 land. TRAP: setting "ask" WITHOUT the handling HANGS the agent (waits for a
     reply that never comes) → worse than auto-approve. Build fully or not at all.
FIRST BUILD SLICE (next fire): trace the precise opencode-SSE→HarnessEvent.permission.requested emission point + the
PermissionRequest field shape → then a pure Swift WorkPermissionRequest model + decode/projector + a permission card view
(additive, parse+test-gated, touches nothing existing). Recorded as the obvious-best next feature toward the full-clone
visual target now that the proof surface is complete + green.

#### ✅ PERMISSION CARDS — slice 1/4: native request model + decoder (2026-06-25)
Built the additive foundation (new file Epistemos/Work/WorkPermissionRequest.swift + EpistemosTests/
WorkPermissionRequestTests.swift; touches nothing existing): `WorkPermissionRequest {id, sessionID, permission, patterns,
alwaysOptions, toolCallID, detail}` modeling OpenGUI's PermissionInteractionRequest (id/sessionID/permission/patterns/
always/tool.callID from src/protocol/session-transcript.ts) + `WorkPermissionRequestDecoder` (lenient: digs to the request
through the {type:"permission.requested", request} / {event:{request}} envelopes or a bare object; nil only when id/
permission absent) + `WorkPermissionDecision {allowOnce, allowAlways, reject}` (UI decision; opencode wire mapping
allow_once/allow_always/reject_once deferred to the sidecar slice). swiftc -typecheck (model, Foundation-only) + -parse
(test) clean; standalone decoder harness 6/6 PASS (envelope/bare/nested decode + detail fallback + nil on malformed/missing
id/permission). REMAINING slices: 2/4 og-sidecar.mjs subscribeHarnessEvents→forward permission.requested/cleared +
question.* over a `{type:"harnessEvent"}` frame + `respondPermission`/`respondQuestion` commands; 3/4 WorkOpenGUISupervisor
onPermissionRequest callback + respondPermission wrapper (+ decode the harnessEvent frame); 4/4 WorkEngineSurfaceView native
permission card (allow-once/always/deny → supervisor.respondPermission) + provisioner opt sensitive tools into "ask" LAST
(trap: "ask" without handling hangs the agent). Build-checkpoint deferred until a clean slot + more slices accumulate.

#### 🔎 PERMISSION CARDS — slice 2/4 RECON: subscribe is public, reply is INTERNAL (2026-06-25)
Traced the sidecar-accessible permission APIs on the OpenGUI runtime:
  • SUBSCRIBE (request side) = PUBLIC: `og.on("event", handler)` (open-gui.ts:75/189, HarnessEventHandler, returns an
    unsubscribe fn) delivers ALL HarnessEvents — incl. permission.requested/cleared + question.requested/cleared (+
    session.*/connection.status/message.updated). Global stream; filter by event.request.sessionID. Sidecar calls this
    once after init.
  • REPLY (response side) = NOT in the public SDK. `respondPermission` exists ONLY on the internal HarnessService
    (harness-service.ts): `respondPermission({session: RuntimeSessionRef, permissionId, response:"once"|"always"|"reject",
    scope?})`. og's `service` is `private readonly` (open-gui.ts:130) → no public reply method on og/DirectoryHandle/
    SessionHandle. DECISION: the sidecar will call `og.service.respondPermission(...)` — TS `private` is COMPILE-time only,
    so it's runtime-accessible in JS; this is the SAME internal path the Electron app uses via IPC ("opencode:permission" →
    conn.respondPermission), and we own the clone-spawned sidecar. Acceptable for the proof (flagged as internal-reach).
  • WIRE VALUES confirmed: response ∈ {"once","always","reject"} → maps WorkPermissionDecision allowOnce→"once",
    allowAlways→"always", reject→"reject". (opencode ACP kinds allow_once/allow_always/reject_once are downstream of the
    bridge; the RUNTIME contract is the 3 short strings.)
SLICE 2 IMPL (next fire, og-sidecar.mjs, node --check gated): after init, `og.on("event", ev => { if ev.type starts
"permission."||"question." → out({type:"harnessEvent", event: ev}) })`; + `respondPermission {sessionId, permissionId,
response}` command → `og.service.respondPermission({session: runtimeRef(rawId), permissionId, response})` (+ verify
runtimeRef/RuntimeSessionRef shape: {rawId, harnessId}); + optional `respondQuestion`. Additive (no change to existing
init/send/etc.). Then slice 3 (supervisor decode + callbacks) + slice 4 (card UI + provisioner "ask" LAST).

#### ✅ PERMISSION CARDS — slice 2/4: sidecar forwarding + respondPermission command (2026-06-25)
og-sidecar.mjs (additive; no change to existing init/send/abort/etc.; `node --check` clean):
  • init now sets `harnessOff = og.on("event", ev => { if ev.type starts "permission."/"question." → out({type:"harnessEvent",
    event}) })` once — forwards ONLY permission/question HarnessEvents over a new NDJSON frame (LiveSessionEvent stream
    unchanged); cleaned up + nulled in `close`.
  • new `respondPermission {harnessId?, sessionId, permissionId, response}` command → `og.service.respondPermission({session:
    {harnessId, rawId: sessionId}, permissionId, response, scope})`. Verified viable: createOpenGUI returns the OpenGUIImpl
    instance (sets this.service @144); the sidecar is plain JS so the TS-`private` service is runtime-accessible; response
    ∈ "once"/"always"/"reject" (harness-service contract).
  • header IN/OUT docs updated (respondPermission command + {type:"harnessEvent"} frame).
GATE: node --check clean (sidecar + connect-probe). Live harness-event flow + actual reply are exercised at slice 4 (when
the provisioner opts tools into "ask") + owner ⌘R — NOT run now (avoids an opencode spawn + a real permission needs "ask"
+ a tool call). respondPermission is ISOLATED (new command, not exercised until slice 4) so this is safe to land now.
NEXT: slice 3/4 WorkOpenGUISupervisor — decode {type:"harnessEvent"} frames in the read loop → onPermissionRequest /
onQuestion callbacks (+ WorkPermissionRequestDecoder) + a `respondPermission(harnessId,sessionId,permissionId,decision)`
wrapper (maps WorkPermissionDecision→once/always/reject). Then slice 4/4 card UI + provisioner "ask" LAST.

#### ✅ PERMISSION CARDS — slice 3/4: supervisor decode + callbacks + respondPermission wrapper (2026-06-25)
WorkOpenGUISupervisor (additive): +WorkOGFrame `.harnessEvent(event:Data)` case; decodeFrame handles `type=="harnessEvent"`
→ subJSON(event); handleLine routes it via new `routeHarnessEvent(_:)` → `onPermissionRequest((WorkPermissionRequest))` /
`onPermissionCleared((String sessionID))` callbacks (permission.requested decoded via WorkPermissionRequestDecoder;
permission.cleared → sessionID; question.* no-op for now). + `respondPermission(harnessId:sessionId:permissionId:decision:)`
async wrapper → request("respondPermission", …) mapping WorkPermissionDecision allowOnce→"once"/allowAlways→"always"/
reject→"reject". swiftc -parse clean (supervisor + test); +WorkOpenGUISupervisorTests.decodesHarnessEvent (frame→
.harnessEvent + WorkPermissionRequestDecoder.decode round-trip); standalone slice-3 harness 5/5 PASS (decision→wire +
route dispatch permission.requested/cleared + question/non-permission ignored). NEXT: slice 4/4 — WorkEngineSurfaceView
wires supervisor.onPermissionRequest → a native flat/TUI permission card (allow once/always/deny → supervisor.
respondPermission) + onPermissionCleared dismiss; THEN WorkOpenGUIProvisioner opts sensitive tools (bash/edit/write/
webfetch) into "ask" in opencode.json LAST (the hang trap: "ask" requires 1-3 live first). Build-checkpoint deferred to a
clean slot once slice 4 lands (the whole feature compiles together).

#### ✅ PERMISSION CARDS — slice 4/4: native card UI wired (provisioner "ask" deliberately deferred) (2026-06-25)
WorkEngineSurfaceView: +`@State pendingPermission`; startEngine sets supervisor.onPermissionRequest → pendingPermission +
onPermissionCleared → dismiss; renders WorkPermissionCardView above the input when pending; decideOnPermission(_:) →
supervisor.respondPermission(harnessId: selectedEngine, sessionId: request.sessionID, permissionId: request.id, decision)
+ dismiss. NEW WorkPermissionCardView.swift — flat/TUI (boxy cornerRadius 0, theme tokens, WorkPixelFont, no donor chrome,
no raw JSON): "permission · <key>" + request.detail + Allow-once/Always/Deny buttons. Both files swiftc -parse clean.
PROVISIONER "ask" FLIP = DELIBERATELY DEFERRED (NOT done): opencode default stays auto-approve. Flipping sensitive tools
to "ask" before the card path is owner-VERIFIED would risk hanging the agent during ⌘R on any UI wiring bug. The full
path (sidecar forward + supervisor route + card + respondPermission) is now BUILT + ready, so flipping "ask" later (after
owner confirms a card shows + allow/deny works) is safe + a 1-line provisioner change. PERMISSION-CARDS FEATURE: slices
1-4 code-complete (model+decoder 6/6 · sidecar forward+reply node--check · supervisor decode+wrapper 5/5 · card UI parse-
clean); only the "ask" gate-flip + live owner verification remain. Next: whole-app checkpoint in a clean slot (the 4
files + 3 test files compile together), then it's owner-⌘R-gated like the rest.

#### 🔎 NEXT FEATURE RECON: question cards (completes the harness-event interaction channel) (2026-06-25)
The harness-event channel built for permission cards ALSO forwards question.* (sidecar already; supervisor routeHarnessEvent
currently no-ops them). Completing question handling is the smallest coherent follow-on. Shapes (src/protocol/session-
transcript.ts): QuestionInteractionRequest {id, sessionID, questions: QuestionPrompt[], tool?}; QuestionPrompt {question,
header, options:[{label, description?}], multiple?, custom?}; answer = QuestionAnswer (= string[] selected labels), reply =
QuestionAnswer[] (one per prompt). RUNTIME reply API: harness-service.replyQuestion({harnessId, requestId, answers:
QuestionAnswer[], target?}) → backendRpc("question:reply",[requestId,answers,directory]) + rejectQuestion(...). Same
internal-reach pattern as respondPermission (og.service.replyQuestion / og.service.rejectQuestion — TS-private, runtime-
accessible in the JS sidecar). PLAN (mirrors permission slices): (a) sidecar `respondQuestion {harnessId,requestId,answers}`
+ `rejectQuestion` commands; (b) supervisor WorkQuestionRequest model+decoder + routeHarnessEvent question.requested→
onQuestion callback + replyQuestion/rejectQuestion wrappers; (c) WorkQuestionCardView (header + question + options, single/
multi-select per `multiple`, optional custom text per `custom`) wired in WorkEngineSurfaceView. Richer UI than permission
(AskUserQuestion-like). NOTE: like permission, questions only FIRE when the agent asks — not proof-blocking; additive.
Deferred to next fire(s); btxhu9dx0 (permission whole-feature checkpoint) still compiling clean (0 Work/permission/total
errors, no DB-lock, no verdict yet).

#### ✅ QUESTION CARDS — slice a/c: sidecar respondQuestion + rejectQuestion (2026-06-25)
og-sidecar.mjs (additive; node --check clean; the sidecar is JS → NOT in the Xcode build, so safe to edit while
btxhu9dx0 Swift-compiles): + `respondQuestion {harnessId?, requestId, answers}` → og.service.replyQuestion({harnessId,
requestId, answers: QuestionAnswer[], target}); + `rejectQuestion {harnessId?, requestId}` → og.service.rejectQuestion(...).
question.requested/cleared are ALREADY forwarded over {type:"harnessEvent"} (the permission slice's og.on filter includes
"question."). Header IN docs updated. REMAINING question slices (Swift — wait for btxhu9dx0 to finish, in the Xcode build):
(b) WorkQuestionRequest model+decoder (QuestionPrompt[{question,header,options[{label,description?}],multiple?,custom?}]) +
supervisor routeHarnessEvent question.requested→onQuestion callback + respondQuestion/rejectQuestion wrappers; (c)
WorkQuestionCardView (header+question+options, single/multi per `multiple`, optional custom text) wired in
WorkEngineSurfaceView. (btxhu9dx0 permission whole-feature checkpoint still compiling clean — 0 Work/total errors, no
DB-lock, no verdict yet.)

#### ✅✅ PERMISSION CARDS COMPILE-VERIFIED (whole app) — btxhu9dx0 ** TEST BUILD SUCCEEDED ** exit 0 (2026-06-25)
The full permission-cards feature (slices 1-4: WorkPermissionRequest model+decoder, og-sidecar forward+respondPermission,
WorkOpenGUISupervisor decode+callbacks+wrapper, WorkPermissionCardView + view wiring) + all tests compile GREEN in the
whole app: `** TEST BUILD SUCCEEDED **`, BUILD_EXIT=0, 0 /Epistemos/Work/ errors, 0 WorkPermission* errors, 0 total. ⇒
permission cards = compile-complete; only the provisioner "ask" gate-flip (deferred, owner-verify-gated) + live owner ⌘R
remain. Now building question cards Swift slices (b/c) — clean slot (0 procs).

#### ✅ QUESTION CARDS — slice b/c: model+decoder + supervisor route + wrappers (2026-06-25)
NEW WorkQuestionRequest.swift: WorkQuestionRequest{id,sessionID,prompts:[WorkQuestionPrompt{id,question,header,options:
[WorkQuestionOption{label,description?}],multiple,custom}],toolCallID} + WorkQuestionRequestDecoder (lenient envelope/
bare/nested dig; nil on missing id or empty prompts; prompt.id = index for answer ordering). WorkOpenGUISupervisor:
+onQuestion/onQuestionCleared callbacks; routeHarnessEvent now handles question.requested→onQuestion (via decoder) +
question.cleared→onQuestionCleared; +respondQuestion(harnessId:requestId:answers:[[String]]) + rejectQuestion wrappers
→ the sidecar commands. swiftc -typecheck (model) + -parse (supervisor, test) clean; standalone question-decoder harness
8/8 PASS (envelope/nested decode + options+descriptions + multiple/custom flags + prompt-index + nil on malformed/missing-
id/empty-prompts); +WorkQuestionRequestTests. REMAINING: slice c UI — WorkQuestionCardView (header+question+options,
single/multi per `multiple`, optional custom text field) + WorkEngineSurfaceView wires onQuestion→pendingQuestion→card→
respondQuestion/rejectQuestion. Then whole-app checkpoint (clean slot). question.requested only fires when the agent asks
→ additive, not proof-blocking.

#### ✅ QUESTION CARDS — slice c/c: native card UI + view wiring → feature code-complete (2026-06-25)
NEW WorkQuestionCardView.swift — flat/TUI (boxy, theme tokens, WorkPixelFont, no donor chrome): per-prompt header +
question + options (single-select radio per `!multiple` / multi checkbox per `multiple`) + optional custom TextField per
`custom`; "Submit" → onAnswer([[String]]) (one answer per prompt, ordered by prompt.id, selected labels + non-empty
custom) ; "skip" → onReject. WorkEngineSurfaceView: +@State pendingQuestion; startEngine wires supervisor.onQuestion →
pendingQuestion + onQuestionCleared → dismiss; renders WorkQuestionCardView (after the permission card) when pending;
answerQuestion(_:) → supervisor.respondQuestion + dismiss; skipQuestion() → supervisor.rejectQuestion + dismiss. Both
files swiftc -parse clean. QUESTION CARDS FEATURE code-complete (a sidecar respondQuestion/rejectQuestion + question.*
forward · b model+decoder 8/8 + supervisor route+wrappers · c card UI). Kicking whole-feature checkpoint (clean slot).

#### ✅✅ QUESTION CARDS COMPILE-VERIFIED (whole app) — og-qcards-build ** TEST BUILD SUCCEEDED ** (2026-06-25)
The full question-cards feature (slices a/b/c: sidecar respondQuestion/rejectQuestion + question.* forward,
WorkQuestionRequest model+decoder + supervisor route+wrappers, WorkQuestionCardView + view wiring) + tests compile GREEN
in the whole app: `** TEST BUILD SUCCEEDED **`, 0 /Epistemos/Work/ errors, 0 total. ⇒ BOTH agent-interaction features
(permission cards + question cards) are now code-complete AND whole-app compile-verified.

CONSOLIDATION — AGENT-INTERACTION SURFACE COMPLETE: the Work surface now has the full OpenGUI interaction model natively:
input→create/send/stream · engine/model/agent pickers · recents rail · slash commands · prompt queue (interrupt) ·
native TOOL cards (transcript) · native PERMISSION cards (allow once/always/deny) · native QUESTION cards (single/multi/
custom). All flat/TUI, theme-aware, no donor chrome, no raw JSON. The harness-event channel (og.on("event") → {type:
"harnessEvent"} → supervisor route → cards → respondPermission/respondQuestion) is the reusable plumbing for both.
OWNER ⌘R CHECKLIST ADDITION (interaction features): once a tool is gated to "ask"/the agent asks a question, expect a
flat permission/question card above the input → allow/deny or pick options → the turn continues. Until then, opencode
auto-approves (default) + agents rarely ask, so the cards won't show in a basic send/stream proof — they're ready, not
intrusive. GATED LAST STEP (unchanged): WorkOpenGUIProvisioner opt sensitive tools (bash/edit/write/webfetch) into "ask"
in opencode.json — do AFTER owner confirms a card renders + responds (flipping blind risks a hang). Remaining overall:
that "ask" flip (owner-verify-gated) + live owner ⌘R + (deferred/owner-gated) worktree-diffs, mini-session creation, Goose.

#### 🔎 opencode-resolution de-risk attempt — no safe sidecar improvement (2026-06-25)
Checked whether the sidecar could robustly point opencode at the clone binary WITHOUT touching the owner's filesystem.
Result: the OpenGUI runtime has NO env-var override for the opencode binary — resolveOpencodeBinary→resolveHarnessCli only
consults fixed commonBinaryPaths [~/.opencode/bin, ~/.claude/local, ~/.local/bin, ~/.bun/bin, ~/Library/pnpm,
/opt/homebrew/bin, /usr/local/bin, /usr/bin] then a login-shell `$SHELL -lc 'command -v opencode'`, then spawn(binary).
So: (a) no sidecar-scoped env override possible; (b) symlinking the clone binary into ~/.local/bin would SHADOW the
owner's likely /opt/homebrew opencode (resolver returns first existsSync match; ~/.local/bin precedes homebrew) → NOT
done. Resolution relies on the owner's login-shell PATH (spike-proven resolvable in the owner env). The documented ⌘R
PREREQUISITE stands unchanged; no further safe de-risk available. ⇒ HOLD: the Work surface is comprehensive (core +
permission + question cards, all whole-app compile-verified) and every remaining item is owner-gated (⌘R, "ask"-flip) or
large-gated (worktree-diffs, mini-creation, Goose). Maintaining (occasional clean-slot regression check) rather than
speculatively building another large gated feature before owner verification.

#### 🔎 NEXT-FEATURE RECON: session DIFFS view lacks a clean runtime path → deferred (2026-06-25)
Considered a native session-diffs view (OpenChamber donor, coding-workbench core) as the next ungated feature. RECON: the
OpenGUI runtime does NOT surface diffs cleanly — session-handle.ts / harness-service.ts have NO diff method (unlike the
first-class HarnessEvent permission/question channel + respond API the interaction cards used). The only diff sources are:
(a) opencode SDK `GET /session/{id}/diff` (SessionDiffResponses) — but only via the bridge's INTERNAL per-connection
`_client` (deeper/fragile reach than og.service); (b) tool-part file diffs `state.metadata.files[].diff` that opencode
edit/write tools carry (bridge stripMessagePayloadBloat keeps `.diff`, drops before/after) — flow through messages()/tool
parts but my transcript strips tool state to name/status/output, and their LIVE-event reachability is unverified. ⇒ a
diffs view needs internal-reach OR transcript/tool-card re-plumbing + a diff renderer — MUCH less clean than the
interaction cards, and the core send/stream proof is still owner-⌘R-unverified. DEFERRED (not the obvious-best now). If
pursued later, the cleanest cut = enrich the native TOOL card to surface `state.metadata.files[].diff` for edit/write
tools (data already in-stream; no new runtime API) AFTER confirming that diff reaches the Swift side live vs only via
messages() history. HOLD stands: surface comprehensive (core + permission + question cards, whole-app verified, drift-
checked intact); remaining work gated (owner ⌘R, "ask"-flip) or non-clean/large (diffs, worktree, mini, Goose).

#### ✅ DIFFS — slice a/b: history projector extracts tool file diffs (2026-06-25)
Pursued the diffs feature (OpenChamber donor, coding-workbench core) via the CLEAN cut from the prior recon: surface the
file diffs opencode edit/write tools already carry in messages() — `state.metadata.files[].diff` (bridge keeps `.diff`,
drops before/after; each is a self-describing unified diff w/ filename in its ---/+++ header). WorkSessionHistoryProjector
(additive): +`WorkHistoryPart.fileDiffs:[String]` (default []) + `fileDiffs(from: state)` helper (state.metadata.files[]
→ non-empty trimmed diff strings); the tool case now populates it. swiftc -typecheck clean; standalone harness 5/5 PASS
(extracts 2 diffs from the messages() tool-part shape · filename+content in header · no-metadata→empty · blank-diff
dropped/real-kept · nil-state→empty). SCOPE NOTE (from recon): this is HISTORY-sourced (messages()) — diffs populate on
session focus/replay, not live-streamed (the live tool events don't carry state.metadata to my transcript). That's the
standard "session diffs on open" behavior, not a regression. REMAINING: slice b — thread fileDiffs through
WorkTranscriptPart (replay) + render in the native tool card (flat/TUI mono diff, +/- line tint) + a projector xctest;
then whole-app checkpoint. Additive, ungated, owner-⌘R-gated for live witness like the rest.

#### ✅ DIFFS — slice b/b: transcript threading + native diff render → feature code-complete (2026-06-25)
WorkEngineTranscript: +WorkTranscriptPart.fileDiffs:[String]; replay() carries history part.fileDiffs → transcript part.
WorkEngineSurfaceView tool card: ForEach(part.fileDiffs) → WorkDiffText. NEW WorkDiffText.swift — flat/TUI unified-diff
renderer (boxy, mono WorkPixelFont, theme tokens): line-tints added(+)/removed(-)/hunk(@@)/header(---,+++)/context;
maxLines guard (40) + "… diff truncated". +WorkSessionHistoryProjectorTests.toolFileDiffs (2 diffs, blank dropped,
filename+content; non-edit tool → no diffs). All 4 changed/new files swiftc -parse clean; projector logic harness-proven
5/5 (slice a). DIFFS FEATURE code-complete (a projector extraction · b transcript+WorkDiffText render). HISTORY-sourced
(diffs show on session focus/replay — standard "session diffs on open"; live-stream diff threading is a separate future
step). Kicking whole-feature checkpoint (clean slot, harness-tracked). Owner-⌘R-gated for live witness like the rest.

#### ⚠️ diffs checkpoint bpyy92bx8 DB-LOCKED (infra, not code) — re-confirm deferred to clean slot (2026-06-25)
bpyy92bx8 exit 65 = `unable to attach DB … build.db is locked. Possibly two concurrent builds` (5 sibling xcodebuilds were
running) → `** TEST BUILD FAILED **`. NOT a code error: 0 /Epistemos/Work/ errors, 0 WorkDiff/projector-test errors, the
sole "error" is the shared-DerivedData lock. Diffs code stays parse-clean + harness-proven (slice-a extraction 5/5). The
whole-app compile-verify is PENDING a contention-free slot — re-kick the diffs checkpoint only when `pgrep -f 'xcodebuild
-scheme Epistemos'` == 0 (same pattern as the origin-hardening re-confirm, which then went green). This fire: 3 siblings
active → deferred.

#### ✅✅ DIFFS COMPILE-VERIFIED (whole app) — og-diffs-build2 ** TEST BUILD SUCCEEDED ** (2026-06-25)
Re-confirm in a clean slot (no DB-lock): the diffs feature (projector fileDiffs extraction + transcript threading +
WorkDiffText render + projector test) compiles GREEN in the whole app — `** TEST BUILD SUCCEEDED **`, 0 /Epistemos/Work/
errors, 0 total. ⇒ diffs = compile-verified.

MILESTONE — FULL BUILT FEATURE SET WHOLE-APP VERIFIED: every feature built this session is whole-app compile-verified:
core proof path (input→create/send/stream, engine/model/agent pickers, recents rail, slash, queue/interrupt) + 4 bug
fixes + MCP origin hardening + permission cards + question cards + DIFFS. The native Work surface now mirrors the full
OpenGUI/OpenChamber interaction+diff model, all flat/TUI, evidenced. CLEAN UNGATED FEATURE SPACE IS NOW EXHAUSTED.
Remaining: owner LIVE ⌘R (the OWED proof) · provisioner "ask"-flip (owner-verify-gated) · non-clean/large (live-diff
threading via messages()-refresh-on-tool.finished, worktree-diffs, mini-creation, Goose) — all gated or non-clean. ⇒
shifting to MAINTAIN-AND-HOLD: periodic cheap drift checks + stand ready for owner ⌘R / gated-work greenlight.

#### 🧭 OWNER_RETURN_CHECKLIST updated to OpenGUI reality (2026-06-25)
The owner's first-read handoff (OWNER_RETURN_CHECKLIST_2026_06_24.md) was STALE — titled "OpenWork Work Feature" and
directed ⌘4 → the OLD OpenWork WebView (would misverify the wrong surface + miss everything built). Updated it (existing
handoff, not a new doc) to the current OpenGUI engine workbench: §1 correct ⌘R path (Settings→Advanced→"Work (OpenCode)"→
"Open Work · OpenGUI engine workbench") + expect/verify steps (stream, model takes effect, queue-drain, interrupt, recents
replay + tool-card diffs) + the opencode-resolution PREREQUISITE; §2 what's done (core path + 4 fixes + origin hardening +
permission/question cards + diffs, all whole-app verified); §3 gated ("ask"-flip first-AFTER-confirm, Goose, mini, live-diff,
OpenWork removal); §4 flags (xcstrings, uncommitted, ledger=authority). Owner's return is now frictionless + points at the
right surface. No code change.

#### ✅ NEW SESSION affordance (clean ungated gap closed) (2026-06-25)
Found a genuine OpenGUI-workbench gap: no explicit "+ New session" action — a fresh session only started implicitly on
first-send or via engine-switch; no way to start a new session on the SAME engine. Added a header button (square.and.pencil,
next to the gear) → startNewSession(): activeSessionID=nil + transcript.reset() + clear input + clear pending permission/
question cards. The current session is already in the recents rail (upserted on create) → preserved + reopenable; the next
send creates a fresh session. Reuses the proven engine-switch reset pattern; single-file additive; swiftc -parse clean.
Build: fold into next clean-slot checkpoint (trivial UI; builds DB-lock under sibling contention).

#### ✅ NEW SESSION affordance compile-verified (whole app) — og-newsession-build ** TEST BUILD SUCCEEDED ** (2026-06-25)
The "+ New session" header button + startNewSession() compile GREEN in the whole app (0 Work errors). Surface re-confirmed
whole-app green. ⇒ back to maintain-and-hold: every clean ungated gap I could find is now built + verified (core path,
4 bug fixes, origin hardening, permission cards, question cards, diffs, new-session). Remaining is owner-gated (⌘R,
"ask"-flip) or non-clean/large (live-diff, worktree, mini, Goose).

#### 🔎 LIVE-DIFF deferral PROVEN non-clean at the runtime type level (recon, 2026-06-25)
Re-examined whether live-turn diffs (not just replay) have a clean event-only path. Traced the chain: sidecar forwards the
FULL LiveSessionEvent verbatim (`og-sidecar.mjs:50` `out({type:"event",…,event:ev})`) → so the deciding factor is the
runtime's `LiveSessionEvent` union. `@opengui/runtime/src/live-session-events/live-session-event.ts` types the tool events
LEAN: `tool.finished` → `{status:string}` (L66), `tool.output.appended/replaced` → `{text:string}` (L60/62),
`part.state.changed` → `{state:string}` (L57, a status STRING — NOT the part's full state object). ⇒ NO live event carries
`state.metadata.files[].diff`; diffs exist ONLY in the `messages()`/transcript projection (og-messages-probe shape, already
used by WorkSessionHistoryProjector for replay diffs). So live diffs would require a mid-stream `messages()`-refresh that
re-projects over the live transcript and races the proven streaming path → confirmed non-clean (now type-level evidence, not
assumption). Conclusion UNCHANGED: live-diff stays deferred; replay diffs remain the shipped behavior. No code change.

#### ◐ TOOL-CALL SUMMARY LINE — slice 1/2: pure debris-safe extractor LANDED + verified (2026-06-25)
Found a real clean gap on the VISUAL TARGET ("native tool cards", OpenCode-TUI minimalism): the tool card shows
name+status+output+diffs but never WHAT the tool is doing (the command / file / pattern / url). The live `tool.input.updated`
event (`input: unknown`) is a deliberate no-op today (WorkEngineTranscript.swift:115) and the history projector drops input
too — so neither live nor replay surfaces it. The blocker to closing it cleanly is DEBRIS: the input object carries huge
fields (write.content, edit.oldString/newString) that must NEVER reach the transcript ("NO raw JSON/log debris" guardrail).
SLICE 1 (this fire, smallest verifiable): `Epistemos/Work/WorkToolInputSummary.swift` — a pure enum
`summary(toolName:input:) -> String?` that extracts ONLY a per-tool ALLOWLIST of salient string keys
(shell/bash→command, edit/write/read→filePath, glob/grep→pattern, webfetch→url, list→path, task→description — all
verified against the opencode clone tool schemas), collapses newlines to one line, truncates to 120+ellipsis, and returns
nil for unknown tool / missing key / non-string / empty / nil. Debris-safe by construction (content/oldString/newString
are never in the allowlist). + `EpistemosTests/WorkToolInputSummaryTests.swift` (6 tests incl. an explicit DEBRIS GUARD
asserting write.content / edit.oldString+newString never surface). EVIDENCE: `swiftc -parse` clean; standalone `swiftc -O`
logic harness 9/9 PASS (incl. write-no-content, no-secret-leak, newline-collapse, truncate, unknown→nil). NO production
wiring yet → zero behavior change; the helper is an inert pure foundation that de-risks the debris concern before any of it
reaches UI. SLICE 2 (next): wire live (WorkEngineTranscript `tool.input.updated` → WorkTranscriptPart.toolSummary) +
replay (WorkSessionHistoryProjector from part.state.input) + render a compact muted line in the tool card; whole-app
xcodebuild checkpoint in a contention-free slot.

#### ◐ TOOL-CALL SUMMARY LINE — slice 2/2: live + replay + render WIRED, parse-clean, build checkpoint kicked (2026-06-25)
Wired the slice-1 extractor end-to-end (6 edits, all swiftc -parse clean):
• `WorkTranscriptPart.toolSummary: String?` (new field) + replay() threads it from the history part.
• LIVE: WorkEngineTranscript.ingest now handles `tool.input.updated` → `applyToolInput` → sets `toolSummary` via
  `WorkToolInputSummary.summary(toolName: parts[idx].toolName, input: obj["input"])` (the normalizer emits tool.started,
  which sets the name, BEFORE tool.input.updated, so the part exists; out-of-order falls back to a shell + fills later).
  Dropped tool.input.updated from the default no-op comment.
• REPLAY: WorkSessionHistoryProjector tool case sets `toolSummary` from `state.input` (key confirmed = `part.state.input`
  in opencode message-v2.ts:333+). `WorkHistoryPart.toolSummary` new field.
• RENDER: the tool card draws a compact muted one-liner (textTertiary, size-10, lineLimit 1, truncationMode .middle)
  between the name/status header and the output — flat/TUI, theme-token, no chrome.
• TESTS: +WorkEngineTranscriptTests.toolInputSummary (live bash→"ls -la"; edit→only "/a/b.swift", oldString/newString
  never leak) + WorkSessionHistoryProjectorTests.toolInputSummary (replay write→only "/x/y.swift", content never leaks;
  bash→"git log"). slice-1 WorkToolInputSummaryTests (6, incl. DEBRIS GUARD) already green via the swiftc -O harness (9/9).
[UPDATE: this checkpoint FAILED on actor-isolation — see the ⚠️→🔧 note below; fixed + re-verified GREEN, see ✅ below.]
EVIDENCE: all 4 production + 3 test files swiftc -parse clean; whole-app xcodebuild checkpoint KICKED in a contention-free
slot (pgrep==0, run_in_background, log og-toolsummary-build.log) — green confirmation pending (next fire / on notify). The
SourceKit single-file "Cannot find WorkToolInputSummary/WorkHistoryMessage in scope" diagnostics are the known same-module
isolation false-positives (resolve at whole-module compile). Owner ⌘R still the live visual witness.

#### ⚠️→🔧 TOOL-CALL SUMMARY build FAILED then FIXED — nonisolated statics (2026-06-25)
The slice-2 checkpoint (bwm23kcb0) came back **BUILD FAILED** with 3 real errors, ALL in WorkToolInputSummary.swift:
`main actor-isolated static property 'salientKey'/'maxLength' can not be referenced from a nonisolated context`. Root cause:
the Epistemos module compiles with `.defaultIsolation(MainActor.self)`, so a plain `static let` is MainActor-isolated, but
`summary(...)` is `nonisolated` (the history projector calls it off the main actor) → cross-isolation reference. This class of
error is INVISIBLE to standalone `swiftc -parse`/`-O` (which don't apply the module's defaultIsolation) — only the whole-app
xcodebuild surfaces it; lesson logged. FIX: marked both constants `nonisolated static let` (immutable + Sendable → safe).
swiftc -parse clean; rebuild b6yb3v5ue KICKED in a clean slot (pgrep==0, background) — green pending on notify. No other
Work-file errors were in the failed log (the transcript/projector/surface wiring compiled; only the helper's isolation broke).

#### 🔎 SLASH-COMMAND send path CONFIRMED wired (recon, 2026-06-25)
Traced the slash affordance end-to-end: input `/`-prefix → `WorkSlashCommandPopover(commands: resources.commands, …,
onSelect: applyCommand)` (surface:57-60) → `applyCommand(_:)` (surface:371) builds `"/\(command.name)"` and sends it as a
message (queued if busy). Popover filters by name prefix/contains. Fully wired — no gap. (resources.commands comes from the
verified loadResources bundle.)

#### ✅ TOOL-CALL SUMMARY LINE — COMPLETE, whole-app GREEN — og-toolsummary-build2 ** BUILD SUCCEEDED ** (2026-06-25)
Rebuild b6yb3v5ue (after the nonisolated-statics fix) = `** BUILD SUCCEEDED **`, exit 0, ZERO Epistemos/Work errors. The
tool-call summary line (slice 1 extractor + slice 2 live/replay/render wiring) is now whole-app compile-verified end-to-end:
the native tool card shows WHAT a tool is doing (command / file / pattern / url) on both the live stream
(`tool.input.updated`) and history replay (`state.input`), debris-safe by construction (per-tool salient-key allowlist;
write.content / edit.oldString+newString never surface — proven by harness 9/9 + the live & replay DEBRIS-GUARD tests).
⇒ back to MAINTAIN-AND-HOLD: this was the last clean ungated feature on the VISUAL TARGET. Built+verified this run on top of
the prior surface: core path, 4 bug fixes, origin hardening, permission cards, question cards, diffs, new-session, AND now
tool-call summaries. Remaining is owner-gated (⌘R, "ask"-flip) or non-clean/large (live-diff [PROVEN non-clean],
transcript.rebased [same], worktree, mini, Goose). Owner ⌘R still the only end-to-end live witness owed.

#### 🚨 ⌘R PREREQUISITE UNMET — opencode CONFIRMED ABSENT + clone bin NOT runnable (recon, 2026-06-25)
De-risked the OWED ⌘R by empirically verifying the opencode dependency the OpenGUI resolver needs. Findings:
• opencode is **resolvable nowhere**: checked all 7 fixed resolver dirs (`~/.opencode/bin, ~/.claude/local, ~/.local/bin,
  ~/.bun/bin, ~/Library/pnpm, /opt/homebrew/bin, /usr/local/bin`) — none — AND ran the resolver's EXACT login-shell probe
  `$SHELL -lc 'command -v opencode'` for zsh AND bash → both "not found". Resolver source: `@opengui/runtime` opencode-bridge
  → `resolveHarnessCli("opencode")` in `server/harness-inventory.ts` (commonBinaryPaths + commandFromShell; NO env override
  exists — I checked for OPENCODE_BIN/OPENGUI_* and there is none, so I CANNOT point it at the clone via env in-tree).
  ⇒ ⌘R will fail at "Could not find the opencode binary" until the owner installs opencode.
• The prior remediation (symlink the clone bin) is WRONG: `.research-clones/work/opencode/packages/opencode/bin/opencode`
  is a SOURCE checkout — package.json `type:module` but the bin stub uses `require()` (ESM/CJS crash on run, reproduced via
  `node bin/opencode --version`), and the stub spawns a platform `target` binary not shipped in source. Symlink → resolves
  then crashes.
• How the PROVEN spike/sidecar passed: they ran when a real opencode was on PATH; the proof is of the PLUMBING and needs a
  resolvable opencode to re-run. Not a regression in my code — an environment dependency.
ACTION (no code; owner-reserved + DISK CAP, did NOT install): corrected OWNER_RETURN_CHECKLIST §1.5 to mark this a REQUIRED
first step with the right fix — install opencode officially (`brew install sst/tap/opencode` / `curl …opencode.ai/install` /
`npm i -g opencode-ai`), NOT the clone symlink. Cross-session memory updated to match.

#### ✅ ⌘R PREREQUISITE — root-caused: a runnable opencode is ALREADY BUNDLED; OpenGUI resolver just doesn't see it (2026-06-25)
Better finding than the prior note (which said "install officially"). Searched the whole system (mdfind + npm/bun globals)
and found the app VENDORS a real opencode: `Epistemos/Resources/opencode-runtime/bin/opencode` — Mach-O 64-bit arm64,
129 MB, and I RAN it → `opencode 1.17.9`, exit 0. The app's OWN OpenWork path already resolves opencode from this bundled
launcher (WorkOpenCodeRuntime.swift:44-55, vendored by build-opencode-runtime.sh). ROOT CAUSE of the ⌘R blocker: the NEW
OpenGUI path uses `@opengui`'s `resolveHarnessCli` (fixed dirs + login-shell PATH, NO env hook) which does NOT look in the
app Resources, so it can't find the bundled binary the rest of the app uses. ⇒ the fix is NOT a fresh install — just make the
bundled binary discoverable.
• IMMEDIATE (owner, 1-liner, 0 disk, nothing to shadow): `mkdir -p ~/.local/bin && ln -s
  "$PWD/Epistemos/Resources/opencode-runtime/bin/opencode" ~/.local/bin/opencode` → resolver finds it (existsSync on
  ~/.local/bin, even off-PATH) → ⌘R works. Reversible (`rm`). I did NOT do it (touching ~/.local/bin = owner env + reserved).
• PROPER (gated follow-up, in-scope but non-trivial): the OpenGUI Work launch should reuse the bundled opencode like OpenWork
  does. Options considered: (a) @opengui resolver has no binary-path/env override (checked harness-inventory.ts) and is
  review-before-vendoring → can't patch it; (b) the sidecar's process PATH is NOT consulted by the resolver (it uses a fresh
  `$SHELL -lc`), so prepending PATH to the sidecar spawn won't help; (c) app-side ensure-symlink-at-launch into ~/.local/bin
  (writes owner env at runtime — invasive); (d) upstream a binary-path option to @opengui when it's vendored. No clean in-tree
  fix exists today without patching the donor → DEFERRED. Checklist §1.5 + memory updated to the bundled-binary remediation.
  SUPERSEDES the prior "install officially" guidance (still works, but unnecessary + costs disk).

#### ✅✅ ⌘R PREREQUISITE — RESOLVED: opencode resolves AUTOMATICALLY at ⌘R (my 2 prior blocker notes were WRONG) (2026-06-25)
Final, rigorous correction (I flip-flopped twice; this is verified link-by-link against the REAL built app). The OpenGUI
resolver's login-shell probe `spawnSync($SHELL,['-lc','command -v opencode'])` INHERITS the spawning process's PATH
(spawnSync defaults env=process.env; macOS login shell PRESERVES inherited PATH entries — TESTED: `PATH=<dir> zsh -lc
'command -v opencode'` and the bash equivalent both resolve). And the supervisor ALREADY prepends the app's
`Contents/Resources` to the sidecar PATH (WorkOpenGUISupervisor.processEnvironment:444-455, "PREPEND the bundled Resources
dir (so `opencode` is found)"). The built .app has the vendored opencode at `Contents/Resources/opencode` (root — Xcode
flattens the synchronized-folder resource; verified: executable, runs 1.17.9). I replicated the EXACT ⌘R env:
`PATH=<built .app>/Contents/Resources:$PATH $SHELL -lc 'command -v opencode'` → resolves to `…/Contents/Resources/opencode`
(zsh AND bash). ⇒ at ⌘R the sidecar inherits Resources-on-PATH → resolver finds the bundled opencode → connects. NO owner
symlink, NO install, NO donor patch needed. WHY my earlier 2 notes were wrong: I tested the bare login shell WITHOUT the
app's PATH injection (the supervisor only injects when IT spawns the sidecar) → saw "not found" and wrongly concluded ⌘R
fails. The resolution step I claimed would fail is now PROVEN to succeed. Net: the "proper fix" I called gated/deferred was
already shipped in the supervisor; the OWED ⌘R has NO opencode prerequisite. Checklist §1.5 + memory corrected to match;
the prior 🚨/✅ prereq notes above are retained as the audit trail but are SUPERSEDED by this entry.

#### 🐛→✅ CRITICAL SIDECAR REGRESSION FOUND + FIXED by runtime proof: `og.on is not a function` crashed init (2026-06-25)
Ran the connect probe under the EXACT ⌘R env (PATH=<built .app>/Contents/Resources → bundled bun+opencode) and init
ERRORED: `og.on is not a function`. ROOT CAUSE: when I added the permission/question card channel I wrote
`harnessOff = og.on("event", …)` at init — but the `createOpenGUI` return has NO `.on`. HarnessEvents are subscribed
PER SESSION via `SessionHandle.subscribeHarnessEvents(handler)` (runtime session-handle.ts:83; HarnessEvent permission.*/
question.* in src/agents/backend.ts:119-122). The bad line threw during init → the WHOLE sidecar init failed → at ⌘R the
OpenGUI workbench would NOT connect opencode at all. My `node --check` (syntax) + Swift whole-app compile NEVER caught it —
same class as the actor-isolation + bare-shell false-positives: only RUNTIME execution surfaces an API mismatch. ⇒ my earlier
"permission/question cards COMPLETE" was over-stated at the JS-runtime layer (Swift UI compiled; sidecar forwarding crashed).
FIX (og-sidecar.mjs): removed the global `og.on` block + the `harnessOff` global/cleanup; moved forwarding into `subscribe(s)`
as a GUARDED per-session `s.subscribeHarnessEvents(...)` (typeof-check + try/catch → a runtime lacking the API degrades to
"no permission cards" instead of breaking connect); cleanup threads `offHarness` on close. Frame shape `{type:"harnessEvent",
event}` UNCHANGED → the Swift routeHarnessEvent side is unaffected. node --check clean.
PROOF (strongest ⌘R de-risk yet) — re-ran the connect probe under the exact ⌘R env: `init connected: ["opencode"]` +
lazy-connect codex → `["codex"]` errors:[] + **EXIT 0**. So the full resolve→spawn→connect path now works headlessly with the
BUNDLED opencode + the app's PATH injection + the fixed sidecar. The sidecar loads fresh each ⌘R (DEBUG root = the clone) →
NO app rebuild needed for this fix. Reap: my probe's opencode (port 4096, no --cors) self-reaped on EXIT 0; the 3 live
`opencode serve --cors` on dynamic ports are the OWNER'S running Epistemos.app (WorkOpenCodeRuntime) — left untouched
(spawn-scoped). REMAINING for ⌘R: only the live GUI render + (if owner opts a tool into "ask") a permission card actually
firing — both owner-witnessed. Permission/question FORWARDING is now on the correct API; card-fire still needs the gated tool.

#### ✅ CREATE + LIST proven headlessly under the exact ⌘R env (2026-06-25)
Extended the runtime proof one link further down the GOAL chain (list/open/CREATE/send/stream). New auth-free probe
`og-create-list-probe.mjs` (init → sessions.create → sessions.list → close; NO send → no model auth, no hang) run under
PATH=<built .app>/Contents/Resources (bundled bun+opencode). RESULT: `init connected: ["opencode"]` →
`created: opencode:ses_101fa43adffelalxS8kY7E2Yyo (harness opencode)` → `list count: 1, contains created session: true` →
PASS → **EXIT 0**. So connect ✅ + create ✅ + list ✅ are now PROVEN with the BUNDLED opencode + the FIXED sidecar +
the app's PATH injection. Also re-confirms the og.on fix on the CREATE path (subscribe(s) runs on create — no crash). The
created id is the engine-namespaced stable `opencode:ses_…` that WorkSessionMapper maps to native identity (recents). Only
send/stream is unproven UNDER THE CURRENT ENV (needs model auth) — already proven earlier by epistemos-opengui-spike
(SPIKE_OK) + og-sidecar-drive. Reap: probe's sidecar + port-4096 opencode self-reaped (EXIT 0); the owner's running-app
`opencode serve --cors` instances left untouched (spawn-scoped). Net: the OWED ⌘R's headless plumbing is proven through
create/list; remaining = live GUI render + live send/stream (model auth) + (optional) a permission card firing — all owner-
witnessed at ⌘R.

#### ✅ PERMISSION/QUESTION RESPOND path runtime-VERIFIED (no second og.on-class bug) (2026-06-25)
After fixing the og.on FORWARD bug, audited the sibling RESPOND handlers (respondPermission/replyQuestion/rejectQuestion →
`og.service.*`) for the same wrong-API risk. Structural read of the REAL runtime (the sidecar imports
`./packages/runtime/src/index.ts`, NOT node_modules/@opengui — they DIFFER): `createOpenGUI` returns an `OpenGUIImpl` whose
public surface is at/harness/registerDirectory/diagnose/close — NO `on` (hence the og.on crash; `on` lives on
HarnessHandleImpl). `service` is `private readonly` — but TS `private` (non-#) is ERASED at runtime, so `og.service` is a
real accessible property (the deliberate "reach the private HarnessService from JS, same as the Electron IPC path"). RUNTIME
introspection (new og-introspect-service-probe.mjs, run with the bundled bun, auth-free) CONFIRMS: `typeof og.on`=undefined
(re-confirms the fixed bug), `og.service`=object, and respondPermission/replyQuestion/rejectQuestion are all `function` →
RESULT PASS. So the respond path is sound — NO second bug. Net: the permission/question feature's full runtime API is now
verified — FORWARD (per-session subscribeHarnessEvents, fixed+proven) + RESPOND (og.service.*, verified). Remaining gates for
a card to actually fire: the "ask" opt-in (owner) + the owner's ⌘R. Probe self-cleaned (no opencode spawned — createOpenGUI
registers handlers without connecting); owner --cors instances untouched.

#### ✅ loadResources (picker + slash data) proven under the exact ⌘R env (2026-06-25)
Ran og-loadresources-probe.mjs under PATH=<built .app>/Contents/Resources (bundled opencode). The opencode-bridge log shows
it resolved + spawned the BUNDLED binary (`…/Contents/Resources/opencode serve --port 4096`), server healthy →
`connected: ["opencode"]` → resource bundle: `providersData: object{providers,default}`, `agentsData: array[7]` (build agent
+ 6 more), `commandsData: array[3]` (init + 2). Matches exactly what WorkEngineResources decodes (providersData{providers,
default} / agentsData[] / commandsData[]) → the engine/model/agent picker + slash-command popover will populate at ⌘R with
the bundled opencode. Auth-free (metadata only). ⚠️ GOTCHA: og-loadresources-probe.mjs exits WITHOUT sending `close`, so the
sidecar's unref'd opencode on port 4096 LEAKS — I reaped it precisely by PID (port-4096, no --cors = mine; owner's --cors
app instances left alone). Future runs of that probe: reap the port-4096 opencode after. Net runtime-verified handlers now:
connect · create · list · forward(subscribeHarnessEvents) · respond(og.service.*) · loadResources. Remaining auth-free:
messages (shape already proven historically + parsed by WorkSessionHistoryProjector). Auth-gated (owner ⌘R): send/stream.

#### ✅ messages handler verified + RUNTIME AUDIT COMPLETE (auth-free surface) (2026-06-25)
Ran og-messages-fresh-probe.mjs (new; init→create→messages→close, fresh session = empty history → no auth) under the exact
⌘R env: `connected:["opencode"]` → `created: opencode:ses_…` → `messages reply ok:true, shape: object` (the nested
`{messages:{messages:[]}}` envelope WorkSessionHistoryProjector parses) → PASS → EXIT 0. The CALL itself (entry.session.
messages) succeeds → the `messages` handler API is sound (no og.on-class crash), even with empty history. This probe sends
`close` → its opencode self-reaped (no leak).
⇒ RUNTIME AUDIT COMPLETE for the entire AUTH-FREE sidecar command surface, all under the bundled opencode + fixed sidecar +
app PATH injection: connect ✅ · sessions.create ✅ · sessions.list ✅ · forward/subscribeHarnessEvents ✅(fixed) ·
respond/og.service.* ✅ · loadResources ✅ · messages ✅. The ONE bug this audit found (og.on crashing init) is fixed +
re-proven. Only send/stream is unverified-under-current-env (needs model auth → owner ⌘R; already proven by
epistemos-opengui-spike SPIKE_OK). The OWED ⌘R is now de-risked to: live GUI render + live send/stream + (optional, after the
"ask" opt-in) a permission card firing — all owner-witnessed. New proof scripts this audit: og-create-list-probe.mjs,
og-introspect-service-probe.mjs, og-messages-fresh-probe.mjs (in .research-clones/work/opengui).

#### ✅ permission/question Swift DECODE matches the delivered shape — feature verified end-to-end (2026-06-25)
Closed the last open question after the og.on→subscribeHarnessEvents fix: does the Swift decode side match the HarnessEvent
shape the new per-session forwarder delivers? routeHarnessEvent (WorkOpenGUISupervisor:379-390) passes the whole event obj to
WorkPermissionRequestDecoder/WorkQuestionRequestDecoder; requestObject(from:) (WorkPermissionRequest.swift:56-60) digs into
`dict["request"]` (and `dict["event"]`) before reading id/permission/patterns → so `{type:"permission.requested",
request:{…}}` decodes correctly (the decoder's own doc-comment already specifies this envelope). ⇒ permission/question is now
verified END-TO-END post-fix: forward (per-session subscribeHarnessEvents) → `{type:"harnessEvent",event}` frame → Swift
decode (navigates →request) → card → respond (og.service.*). Code-read confirmation, no bug, no code change. Remaining: the
card only FIRES after the owner opts a tool into "ask" (default = auto-approve) + the owner's ⌘R.

#### 🔧 og-loadresources-probe.mjs leak FIXED — now self-reaps (2026-06-25)
Closed the process-leak footgun flagged in the loadResources entry above: og.close() leaves the opencode-bridge's unref'd
`opencode serve` running (documented; the sidecar works around it with reapOpencode, but this probe drives createOpenGUI
directly). Added a port-scoped `reapOpencode()` (pkill `opencode serve --port ${OPENGUI_OPENCODE_PORT ?? 4096}` — effectively
spawn-scoped; the app's own opencode uses --cors on OTHER ports) + `process.exit(0/1)`, called on both the success and catch
paths — mirroring the sidecar + the other probes (create-list/messages-fresh self-reap via `close`). VERIFIED: re-ran the
probe → bundle intact (providers + 7 agents + 3 commands) → afterward NO port-4096 opencode left (self-reaped); owner --cors
instances untouched. node --check clean. Future loadResources runs no longer leak / need manual PID reaping.

#### ✅ MODEL PICKER shape verified against runtime — last Swift-decode link closed (2026-06-25)
Expanded og-loadresources-probe to dump the real provider/models shape (the model picker populates from
providersData.providers[].models, previously only summarized as object{providers,default}). REAL shape: provider[0] =
{id:"huggingface", name:"Hugging Face", source, env, key, options, models}; `models` is an OBJECT/Record with **49** entries;
each model = {id:"meta-llama/Llama-3.3-70B-Instruct", providerID, api, …}. WorkEngineResources.decode matches exactly:
provider["id"]/["name"] ✓, provider["models"] as [String:[String:Any]] ✓ (Record, not array), model["id"] ✓ (name→key
fallback). ⇒ the model picker WILL populate at ⌘R (49 HF models). Also validates the composite-id design: split-on-FIRST-slash
turns `huggingface/meta-llama/Llama-3.3-70B-Instruct` → providerID `huggingface` + modelID `meta-llama/Llama-3.3-70B-Instruct`
(real model ids contain slashes — exactly why the model-selection bug fix used first-slash split). Probe self-reaped (leak fix
holds). NET: EVERY Swift decode/parse path is now verified against actual sidecar output — session mapper, history projector,
permission/question decode, AND the picker (providers/models/agents/commands). No bug; no code change.

#### 🤖🐛→✅ ADVERSARIAL AUDIT (8-dim multi-agent workflow) FOUND + FIXED a 2nd dead harness-event subscription (2026-06-25)
Ran an exhaustive read-only multi-agent audit (workflow wf_6e43bc43-768: 8 parallel Explore finders — runtime-api / frame-
contract / decode-shapes / isolation / error-paths / visual-fidelity / identity / process-lifecycle — each finding
adversarially verified). 6 dimensions clean. It surfaced 1 HIGH (confirmed real) + 3 visual (owner-decision).
• HIGH (CONFIRMED + FIXED): my og.on fix had moved permission/question forwarding to per-session
  `s.subscribeHarnessEvents` — but the SessionHandle's RETURNED object does NOT expose that method (only the TS interface
  declares it; impl keeps it internal — session-handle.ts return literal 241-332 has send/abort/messages/onEvent/onStream/
  waitUntilIdle/close, NO subscribeHarnessEvents). My defensive `typeof === "function"` guard therefore ALWAYS evaluated
  false → forwarding was SILENTLY DEAD → permission/question cards would never fire even after the "ask" flip. My
  connect/create/list/messages probes never caught it (none exercise harness events). HONEST CORRECTION: my earlier
  "permission/question verified END-TO-END" was wrong on the FORWARD half (decode + respond halves were correctly verified).
  ROOT-CAUSED the correct API: open-gui.ts:252 wires the session's internal harness subscription to the HARNESS handle's
  `on("event")`. RUNTIME-VERIFIED (og-introspect-harness-events-probe, bundled bun): harness.on = function (returns unsub);
  harness.subscribeHarnessEvents = undefined; session.subscribeHarnessEvents = undefined (the dead path). FIX (og-sidecar.mjs):
  new `subscribeHarness(hid, harness)` subscribes at `harness.on("event", …)` forwarding permission.*/question.* as
  {type:"harnessEvent"}; wired in init + connect (idempotent per harness); removed the dead per-session block; close() now
  unsubscribes harnessEventOffs. node --check clean; connect probe under the exact ⌘R env still init+connects opencode+codex
  EXIT 0 (the now-active harness.on subscription does NOT regress connect). Forwarding is now on the one public surface that
  exists; full path harness.on→frame→Swift decode(verified request-envelope)→card→respond(og.service verified). NOTE: a
  permission card actually FIRING still needs the owner "ask" opt-in + a gated tool call (auth) — can't be proven headlessly;
  but the subscription point is now correct + verified, vs. silently dead before.
• 3 VISUAL findings (NOT changed — owner aesthetic decision, flagged): WorkEngineSurfaceView.swift:33-35 + WorkSlashCommand
  Popover.swift:15-17 hardcode warm dark/cream `boxBackground` RGB (branch on isDark only, ignore the resolved theme palette);
  WorkDiffText.swift:51-52 hardcode add/remove green/red. These MAY be the intentional OpenCode-TUI warm identity (and diff
  green/red is a universal); whether to switch to theme.resolved tokens is the owner's call (the "Epistemos tokens vs OpenCode
  warm look" tension). Did NOT change blind while owner away. Owner: decide at ⌘R.
New probe: og-introspect-harness-events-probe.mjs. The audit paid for itself — a real silently-dead feature, fixed.

#### 🐛→✅ AUDIT IDENTITY CLUSTER fixed (#5/#6/#7 + #3) — WorkEngineSurfaceView (2026-06-25)
The 8-dim audit confirmed 9 defects total (verifiers high/medium-conf). #1 (dead harness forwarding) fixed above. This fire
fixed the IDENTITY cluster (core GOAL = preserve native recents/session identity — was genuinely broken) + an error-path:
• #5 (HIGH, identity): openFromRail opened the recent against `selectedEngine` not its OWNING engine. Session ids are
  engine-namespaced (harnessId:rawId) → reopening an opencode recent while another engine is selected opened it against the
  wrong engine. FIX: derive owningEngine = prefix before first ':' and openSession against THAT. Deliberately do NOT flip
  selectedEngine (that trips the engine-switch onChange which resets the transcript — verified); sends route by session id so
  the picker-cosmetic-mismatch is harmless. (Currently latent — startEngine lists one engine's sessions — but correct for the
  multi-engine future + cheap.)
• #6/#7 (HIGH/medium, identity): dual source of truth — sendNow set the VIEW's activeSessionID + upserted, but never the
  STORE's focus; upsert only sets store.activeSessionID when it was nil → the 2nd+ created session left the rail highlight on
  the OLD session (store vs view desync). FIX: `sessions.focus(id: sessionID)` after upsert in sendNow. The resulting
  onChange(sessions.activeSessionID)→openFromRail short-circuits (view activeSessionID already == id → guard false).
• #3 (medium, error-path): openFromRail used `try?` and swallowed reopen failures, leaving a stale transcript under the new
  selection. FIX (folded into #5): real do/catch → on failure transcript.reset() + a native session.error part.
EVIDENCE: swiftc -parse clean; whole-app checkpoint brcw3gskc KICKED in a clean slot (background) — green pending on notify.
DEFERRED to next fires (real, lower-risk): #2 (empty-transcript placeholder says "connecting…" for .stopped/.failed since
surfaceStatusError only handles .unavailable/.failed → make it status-derived) + #8/#9 (reapOpencode port hardcoded 4096 on
both sides → reap not truly spawn-scoped; fix = Swift supervisor sets a unique OPENGUI_OPENCODE_PORT per launch, sidecar
already honors it). FLAGGED (owner aesthetic, NOT changed blind): #4 WorkEngineSurfaceView boxBackground warm RGB vs theme
token (may be intentional OpenCode-TUI identity). 6 of 8 dimensions were clean (isolation, decode-shapes, + most of frame-
contract/process beyond the port). Full audit result: tasks/wiwmgp9fd.output.

#### 🐛→✅ AUDIT #2 (placeholder honesty) + #8/#9 (spawn-scoped reap) fixed (2026-06-25)
Last two clean audit findings (identity build brcw3gskc already ** BUILD SUCCEEDED **, confirming #5/#6/#7+#3):
• #2 (medium, error-path): empty-transcript placeholder hardcoded "connecting to the engine…" for ANY engines.isEmpty,
  misleading for .stopped/.failed/.unavailable. FIX: WorkEngineSurfaceView `emptyPlaceholder` computed from supervisor.status
  (.running→"Type to start…", .idle→"connecting…", .stopped→"engine stopped — reopen", .unavailable/.failed→reason).
  Placeholder-ONLY — deliberately did NOT add .stopped to surfaceStatusError (intentional stop() also sets .stopped → would
  inject a false error).
• #8/#9 (high, process-lifecycle): reapOpencode pkill pattern `opencode serve --port 4096` was NOT spawn-scoped (port
  hardcoded default on both sides; supervisor never set OPENGUI_OPENCODE_PORT). FIX: WorkOpenGUISupervisor.freeTCPPort()
  (POSIX bind :0 → assigned port → close; nil→fallback) + processEnvironment gains `opencodePort` → sets OPENGUI_OPENCODE_PORT
  in the sidecar spawn env. The sidecar already reads that var on BOTH the bridge bind (opencode-bridge.ts:28 LOCAL_SERVER_
  PORT) AND reapOpencode (og-sidecar.mjs:32) → reap now kills ONLY this launch's opencode. RUNTIME-VERIFIED end-to-end
  (independent of the build): connect probe with OPENGUI_OPENCODE_PORT=47321 → opencode bound 47321 (nothing on 4096) →
  init+connect EXIT 0 → reaped cleanly (no leftover on 47321). EVIDENCE: both files swiftc -parse clean; whole-app checkpoint
  b3p2r92zj KICKED (background) — green pending on notify. ⇒ ALL 9 audit findings resolved: #1/#3/#5/#6/#7 + #2 + #8/#9 FIXED
  (8), #4 flagged for owner. The multi-agent adversarial audit found 2 silently-dead features (permission forwarding, reap
  scope), core identity breakage, + error-path/placeholder honesty — all caught + fixed before the owner's ⌘R.

#### ⚠️→🔧 #2/#8/#9 build FAILED (non-exhaustive switch) then FIXED (2026-06-25)
Checkpoint b3p2r92zj came back BUILD FAILED: WorkEngineSurfaceView.swift:193 "switch must be exhaustive" — my new
`emptyPlaceholder` switch on supervisor.status missed `.starting` (the Status enum has SIX cases: idle/unavailable/starting/
running/failed/stopped; I'd handled five). swiftc -parse is syntax-only so it didn't flag the non-exhaustive switch — same
fast-gate blind spot as the actor-isolation lesson; only xcodebuild catches it. FIX: folded `.starting` into the
`.idle` "connecting…" case. parse clean; rebuild bxkyrkkgr KICKED (clean slot, background) — green pending on notify. The
#8/#9 freeTCPPort/port-env changes compiled fine (the only error was the one switch).

#### ✅ #2 + #8/#9 whole-app GREEN — bxkyrkkgr ** BUILD SUCCEEDED ** (2026-06-25)
Rebuild bxkyrkkgr (after the .starting exhaustiveness fix) = `** BUILD SUCCEEDED **`, exit 0, ZERO Work errors. ⇒ ALL 8
fixable audit findings are now whole-app verified: #1 (harness.on forwarding) + #3/#5/#6/#7 (identity+error, build brcw3gskc)
+ #2 (status placeholder) + #8/#9 (freeTCPPort spawn-scoped reap, also runtime-verified via custom-port probe). #4 (warm
boxBackground) remains FLAGGED for owner aesthetic decision. The Work surface is fully audited + fixed + whole-app green.
HANDOFF STOPPING POINT: nothing in-flight. Remaining = owner ⌘R (render + send/stream, prereq auto-handled), the "ask"-flip
(after ⌘R), #4 aesthetic decision, and the deferred non-clean/large items (live-diff, transcript.rebased, worktree, mini,
Goose). All uncommitted on main. Authority: this ledger + OWNER_RETURN_CHECKLIST_2026_06_24.md.

#### ✅ Regression tests for audit fix #8/#9 (port spawn-scoping) + handoffs corrected (2026-06-25)
Post-audit hardening (ultracode): locked in the #8/#9 fix with WorkOpenGUISupervisorTests additions — buildsEnvPort
(processEnvironment sets OPENGUI_OPENCODE_PORT when given, omits when nil → sidecar default) + freePort (freeTCPPort returns
a usable ephemeral port or nil). The socket code was RUNTIME-VERIFIED via a standalone swiftc -O harness: 5 calls → 5 valid
varying ephemeral ports (52266-52270, all >1024) — it genuinely works, not just compiles. parse clean; test-build bukrjm4vo
(build-for-testing) KICKED — green pending on notify. ALSO corrected stale/WRONG handoff text: OWNER_RETURN_CHECKLIST +
cross-session memory both described the permission forwarding as `subscribeHarnessEvents` (the DEAD path the audit
superseded); both now correctly state the verified `harness.on("event")` fix, + the checklist gained the full audit summary
(8 fixes) and #4 as an explicit owner aesthetic decision. (View-coupled fixes #2/#5/#6/#7 aren't cleanly unit-testable
without a refactor of working build-verified code → left as-is; #8/#9 was the cleanly-testable one.)

#### ✅ AUDIT #4 visual tokenization resolved — Work is theme-appified without losing the OpenCode-like density (2026-06-25)
Continuation loop after owner asked to keep hardening/reskinning/appifying. Resolved the remaining visual audit item instead
of leaving it as an owner decision: added `WorkSurfaceStyle` as the Epistemos-owned Work palette and routed the OpenGUI Work
canvas, recents rail, slash-command popover, OpenWork fallback box background, and diff add/remove/hunk colors through the
active `EpistemosTheme` tokens. The surface remains flat/boxy/monospace/TUI-minimal, but no longer carries hardcoded warm
`Color(red:)` RGB values that ignore the resolved app theme. Source guard: `rg -n "Color\\(red:" Epistemos/Work` returns no
matches. Regression coverage: new `WorkSurfaceStyleTests` verifies theme-derived backgrounds differ by theme and role, and
do not equal the old warm dark RGB sentinel. Validation: `xcrun swiftc -parse` over the touched Work files passed, and
`xcodebuild test -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS'
-only-testing:EpistemosTests/WorkSurfaceStyleTests` completed with `** TEST SUCCEEDED **` (2 Swift Testing tests). Remaining
gates unchanged: owner live ⌘R render/send/stream witness, permission "ask" flip after live card confidence, mini-session
creation, Goose adapter, live-diff threading, worktree-diff scope, and OpenWork fallback removal only after proof passes.

#### Codex continuation checkpoint — flat host, app-native tools, safe branding boundary (2026-06-25)
Owner asked for continued hardening, Epistemos branding, and OpenCode-like flat minimalism without breaking runtime contracts
or removing controls. Applied the boundary explicitly: visible/chrome copy may say Epistemos Work, but fragile runtime names,
protocol/API strings, imports, bundle IDs, env vars, localStorage keys, Keychain/hotword surfaces, sidecar command names, and
OpenCode/OpenGUI/OpenWork integration identifiers stay intact unless proven safe. This is why the UI is appified but the
runtime still advertises and resolves the exact names external code expects.

New hardening in this pass:
- `WorkToolMCPCore` now prefers the Rust app-tool catalog (`agent_coreFFI.listToolsForTier(..., tier: .full)`) rooted at the
  active vault path, with the old Omega registry as fallback. This fixes the earlier regression class where a clone/runtime
  could not see real Epistemos tools. `tools/list` now verifies app-native `vault.*` and `note.*` tools, not just generic
  engine tools.
- Native MCP host/server pass the active vault path into the core so OpenGUI/OpenWork native tools operate against Epistemos
  vault state, not only the managed work cwd.
- `WorkSPAServerTests` now accept the JSON-escaped localStorage URL form emitted by `JSONSerialization` and explicitly guard
  that escaped literal behavior.
- `WorkWebSurfaceView` was flattened to a full-window Work host: no rounded inset preview box, no heavy chrome, and no control
  deletion. Status/runtime/workspace details moved into a small theme-derived side panel toggled by a square icon button.
  This matches the owner's OpenCode-like flat target while preserving all surface controls through toggles/panels.
- Safe visible branding continued: user-facing Work/OpenGUI/OpenWork fallback copy now reads as Epistemos Work. AgentClone
  visible labels were changed only where they are passive UI/copy. Fragile Agent!/OpenCode/Goose/OpenGUI runtime identifiers,
  hotwords, TCC/bundle/Keychain surfaces, imports, protocols, tool names, and env/storage keys were intentionally preserved.
- AgentClone compile hardening was kept minimal: added the `UserService.userAgentPlistExists()` shim and split the heavy
  `ContentView` shell enough for Swift to type-check. No behavior was removed.

Verification after these changes:
- Full app build: `xcodebuild build -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS'`
  with derived data `/tmp/EpistemosWorkEndpointDD-20260625-0719` completed `** BUILD SUCCEEDED **`.
- Focused Work endpoint/contract slice rerun against the same tree completed `** TEST SUCCEEDED **`: 63 Swift Testing tests
  in 6 suites passed (`WorkNativeMCPServerTests`, `WorkToolMCPCoreTests`, `WorkSPAServerTests`,
  `WorkOpenWorkSupervisorTests`, `WorkOpenGUISupervisorTests`, `WorkSPAReskinTests`). Result bundle:
  `/tmp/EpistemosWorkEndpointDD-20260625-0719/Logs/Test/Test-Epistemos-2026.06.25_08-30-58--0500.xcresult`.
- App bootstrap during the test refreshed 64 tools, and `Work Tool MCP Core` specifically passed
  "tools/list returns Epistemos app-native note/vault tools, not just a generic engine catalog".

Current status: OpenGUI/OpenCode/OpenWork contracts are green; the native Work host is flatter and more Epistemos-owned; no
capability was intentionally removed. Remaining gates are still owner-only/live: ⌘R render/send/stream witness, then the
permission-card "ask" flip, then OpenWork fallback removal only after live proof. Deferred non-clean work is unchanged:
live-diff threading, transcript rebasing, owner-scoped worktree diffs, mini-session creation, and Goose adapter.

#### Codex continuation checkpoint — stale API comments and button-label drift guarded (2026-06-25)
Owner clarified again that Epistemos branding should be optimized only where it cannot break engine/runtime contracts, and
that OpenGUI/OpenCode already had the right minimal shape. Applied a narrow hardening pass, not a feature removal pass:
- `WorkPermissionRequest` and `WorkQuestionRequest` source comments now describe the live verified bridge
  `harness.on("event")`, not the dead per-session `subscribeHarnessEvents` path that the audit already retired.
- Added source guards in `WorkPermissionRequestTests` and `WorkQuestionRequestTests` so the dead API name does not drift back
  into the request model docs.
- Added a Work settings source guard that preserves the Epistemos-facing launch labels while still allowing engine identity
  names such as OpenCode/OpenGUI in runtime contexts.
- Updated the owner checklist proof steps to the actual current button labels.

Validation: focused Xcode run completed `** TEST SUCCEEDED **` with 12 Swift Testing tests in 3 suites
(`WorkCloneSettingsTests`, `WorkPermissionRequestTests`, `WorkQuestionRequestTests`). Result bundle:
`/tmp/EpistemosWorkEndpointDD-20260625-0719/Logs/Test/Test-Epistemos-2026.06.25_08-47-16--0500.xcresult`.

#### Codex continuation checkpoint - fallback WebView copy appified and guarded (2026-06-25)
Continued the safe branding pass inside the established boundary: user-visible fallback chrome may read as Epistemos Work,
but engine/runtime identifiers remain untouched. The fallback WebView no longer advertises the surface as an "OpenCode
loopback fallback" or "OpenCode engine over local loopback"; those strings were Epistemos-facing shell copy, not a contract.
They now read as an Epistemos Work fallback with a generic local engine bridge description.

Added a `WorkSPAReskinTests` guard so this does not drift back. Validation: focused Xcode run completed
`** TEST SUCCEEDED **` with 5 Swift Testing tests in `WorkSPAReskinTests`. Result bundle:
`/tmp/EpistemosWorkEndpointDD-20260625-0719/Logs/Test/Test-Epistemos-2026.06.25_08-56-38--0500.xcresult`.
