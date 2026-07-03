# RAW corpus — OpenChamber/Pro agent-surface research

> ⚠️ **RAW RESEARCH INPUT — DO NOT BUILD FROM THIS FILE.** Verbatim multi-model research corpus (5 dossiers) fed into the 2026-07-03 synthesis. It CONTAINS ERRORS corrected against local source clones. Canonical build docs: docs/prompts/PROMPT_PLAN_1_PRO_OPENCHAMBER.md / PROMPT_PLAN_1_MAS_JUNE.md (see their §Corrections logs). Kept for provenance only.

you will synhesize deeper and do your own verification research to make usure its truly good.  




ok the research is done we will start consolidatig and synthesizig the openchamber one first here it is and reemeber okand remmeber for the openchamber one i only want to apply june to the message bar and gradient. - 



GPT 1- # Epistemos Agent Rebuild Execution Dossier

## Executive position

The most defensible path is the one you have already converged on: **OpenChamber as the only UI base donor**, embedded in Epistemos’s existing `WKWebView`, with **two engines hidden behind one client seam**: OpenCode first because OpenChamber is already built against the OpenCode SDK and event model, then Goose through an SDK-shaped adapter. That minimizes UI rewrites, preserves upstream updateability, and keeps the “single merged session surface” idea achievable without turning Epistemos into a third orchestration product. OpenChamber’s own repo describes itself as a monorepo for “web, ui, and desktop runtimes,” and its browser host literally mounts `@openchamber/ui` by importing its CSS/fonts and then `import('@openchamber/ui/main')`. citeturn20view0turn27view0

The strongest architectural finding from the source pass is that **the true seam is not the React component tree; it is the runtime client/event contract**. OpenChamber’s UI package depends on `@opencode-ai/sdk`, and the server-side architecture documented in the OpenCode repo is a local Hono HTTP server plus an SSE event stream. The high-value contract is therefore: session CRUD and message fetch/send endpoints, permission and question flows, todo fetches, and the `/event` SSE bus carrying `message.*`, `session.*`, `todo.updated`, `question.*`, and `permission.*` events. If Goose can be made to look like that from the UI’s perspective, most of the UI can stay unchanged. citeturn22view3turn15view0

Two constraints fall out of the evidence. First, **OpenChamber is a workspace shell, not a conventional paged app**. Its UI state centers on main tabs like `chat`, `plan`, `git`, `diff`, `terminal`, `files`, `context`, and `diagram`, plus dialogs/shells for timeline history, settings, updates, and session creation. That argues against ripping Settings or History out into first-class native destinations unless you want to fork the view model hard. Second, **the web host is genuinely browser-oriented**, which is good news for `WKWebView`, but it assumes an HTTP API origin and optionally registers a service worker in production. When embedding, you should treat the packaged UI as a browser app with PWA features disabled and an explicit runtime API base URL injected from Swift. citeturn35view2turn35view4turn27view0turn39view0

My overall recommendation is therefore:

| Decision | Recommendation | Why | Confidence |
|---|---|---|---|
| UI base | **Vendor OpenChamber UI only** | It already spans web/desktop/editor hosts and is built to mount shared UI into multiple runtimes. citeturn18view0turn26view0 | Verified-in-source |
| Engine count | **Exactly two UI-visible engines: OpenCode and Goose** | This keeps one surface and one adapter seam. Turning Claude Code or Codex into additional direct engines would recreate 1Code’s broader orchestrator shape. citeturn42view0turn15view0 | Inferred |
| OpenCode priority | **Engine one is native OpenCode** | OpenChamber is already wired to the OpenCode SDK/event model. citeturn22view3turn40view2turn15view0 | Verified-in-source |
| Goose integration | **SDK-shaped adapter, not UI transplant** | Goose exposes desktop/CLI/API capabilities, but OpenChamber’s UI expects the OpenCode-style client and event semantics. citeturn43view4turn15view0 | Inferred |
| Native navigation | **Keep native toolbar pill for app-level pages; keep OpenChamber internal tabs inside Agent** | Least invasive to the donor’s workspace model. citeturn35view2turn36view0 | Inferred |
| June | **Treat as a landing-signature transplant, not a second donor surface** | Preserves the one-donor law while letting you own the composer shell + gradient as a signature layer. | Inferred |

## OpenChamber anatomy and UI contract

OpenChamber’s repo is a Bun monorepo whose root `package.json` defines `packages/*` workspaces and scripts for `web`, `ui`, `electron`, `mobile`, and `vscode`. The top-level `packages` directory visibly contains `docs`, `electron`, `ui`, `vscode`, and `web`. The repo README also positions OpenChamber as a shared product line across desktop, browser/PWA, phone, and VS Code. citeturn20view0turn18view0turn17view0

That source layout matters because it proves the UI package is deliberately host-agnostic:

| Package | Role | Evidence | Confidence |
|---|---|---|---|
| `packages/ui` | Shared React UI package | Present in workspace; `@openchamber/ui` is imported by other hosts. citeturn18view0turn27view0turn23view4 | Verified-in-source |
| `packages/web` | Browser/PWA host and proxy server | Has `serve` CLI, Vite build, `src/main.tsx`, runtime config, and API server dependencies. citeturn23view0turn24view0turn39view0 | Verified-in-source |
| `packages/electron` | Desktop host | Contains `main.mjs`, `preload.mjs`, packaged UI origin logic, and resource loading. citeturn25view0turn28view2 | Verified-in-source |
| `packages/vscode` | VS Code extension host + webview | Depends on `@openchamber/ui`, builds a webview, and exposes `openchamber.apiUrl` / `openchamber.opencodeBinary`. citeturn23view4turn26view0turn28view0 | Verified-in-source |
| `packages/docs` | Docs source package | Repo says it is the source-of-truth for OpenChamber public docs content. citeturn18view0 | Verified-in-source |

The mount pattern is explicit in the browser host. `packages/web/src/main.tsx` imports `@openchamber/ui/index.css` and `@openchamber/ui/styles/fonts`, sets `window.__OPENCHAMBER_RUNTIME_APIS__`, conditionally registers or unregisters the service worker, and then dynamically imports `@openchamber/ui/main`. The VS Code webview does the same kind of shared-UI consumption, importing OpenChamber UI runtime types and client helpers from `@openchamber/ui`. citeturn27view0turn28view0

The internal view model is also more “workspace shell” than “router.” In `useUIStore.ts`, OpenChamber defines top-level **main tabs** as `chat`, `plan`, `git`, `diff`, `terminal`, `files`, `context`, and `diagram`; **right-sidebar tabs** as `git`, `files`, and `context`; and **context panel modes** as `diff`, `file`, `context`, `plan`, `chat`, `preview`, and `browser`. Separately, `SidebarSection` is its own left-rail IA: `sessions`, `agents`, `commands`, `skills`, `mcp`, `providers`, `usage`, `git-identities`, and `settings`. Settings itself is a shell-like state with `isSettingsDialogOpen`, `settingsPage`, and selected project/remote-instance IDs, while timeline/history appears as `isTimelineDialogOpen`. citeturn35view2turn36view0turn35view4

That is the key answer to your navigation question: **Settings and History are currently expressed as internal shell/dialog state, not as clean standalone route roots**. The donor wants them inside the workspace. Pulling them out into native pages would be possible, but it would be invasive rather than “near automatic.”

The stores layer is broad. OpenChamber’s own `stores/DOCUMENTATION.md` classifies them into feature-cache/query stores, UI state stores, and session/project coordination stores, and explicitly says keyed store identity can be based on “directory, branch, session id.” The store directory currently includes, among others, `globalSessions.ts`, `permissionStore.ts`, `useAgentsStore.ts`, `useCommandsStore.ts`, `useConfigStore.ts`, `useDirectoryStore.ts`, `useFileSearchStore.ts`, `useGitStore.ts`, `useGlobalSessionsStore.ts`, `useMcpStore.ts`, `usePluginsStore.ts`, `useProjectsStore.ts`, `useQuotaStore.ts`, `useSessionFoldersStore.ts`, `useSkillsStore.ts`, `useTerminalStore.ts`, `useTodosPersistStore.ts`, `useUIStore.ts`, and `useUpdateStore.ts`. citeturn16view0turn37view0

Because the request asked for an exhaustive contract map, the most useful way to split it is into **full file inventory** and **verified adapter-sensitive contract**.

### Full store file inventory

| Store file | Observable role from source | Adapter sensitivity | Confidence |
|---|---|---:|---|
| `contextStore.ts` | Likely session context cache | Medium | Inferred from name + directory listing citeturn37view0 |
| `fileStore.ts` | Likely file tree/file state | Medium | Inferred citeturn37view0 |
| `globalSessions.ts` | Session coordination/cache helper | High | Inferred from name; corroborated by documented session coordination category. citeturn16view0turn37view0 |
| `messageQueueStore.ts` | Queued prompt/UI messaging state | Medium | Inferred citeturn37view0 |
| `permissionStore.ts` | Permission approval state | High | Name aligns directly with OpenCode permission flow. citeturn37view0turn15view0 |
| `useAgentGroupsStore.ts` | Agent grouping/multi-agent UI | Medium | Inferred citeturn37view0 |
| `useAgentsStore.ts` | Agent catalog/selection | High | Inferred; agents are first-class sidebar section. citeturn36view0turn37view0 |
| `useCommandsStore.ts` | Slash/command catalog | High | Inferred; commands are first-class sidebar section. citeturn36view0turn37view0 |
| `useConfigStore.ts` | Providers/models/config | High | Name + UI model/provider settings. citeturn37view0turn34view5 |
| `useDesktopSshStore.ts` | Desktop SSH remotes | Low for engine adapter | Inferred; desktop-only. citeturn37view0turn17view0 |
| `useDirectoryStore.ts` | Selected workspace/directory | High | Documented as a UI state store. citeturn16view0turn37view0 |
| `useFeatureFlagsStore.ts` | Feature flags | Low | Documented UI state store. citeturn16view0turn37view0 |
| `useFileSearchStore.ts` | Search inside files/project | Medium | Inferred citeturn37view0 |
| `useFilesViewTabsStore.ts` | File view tabs cache | Medium | Documented feature cache/query store. citeturn16view0turn37view0 |
| `useGitHubAuthStore.ts` | GitHub auth | Low for engine adapter | Inferred citeturn37view0 |
| `useGitHubPrStatusStore.ts` | PR status cache keyed by `directory::branch` | Medium | Explicitly documented as PR cache. citeturn16view0 |
| `useGitIdentitiesStore.ts` | Git author identities | Low | Inferred + sidebar section. citeturn36view0turn37view0 |
| `useGitStore.ts` | Per-directory git repo/status/branches/log/diff cache | High | Explicitly documented. citeturn16view0 |
| `useGlobalSessionsStore.ts` | Global session metadata | High | Documented session/project coordination store. citeturn16view0turn37view0 |
| `useInlineCommentDraftStore.ts` | Inline comments on diffs/files/plans | Medium | Inferred from feature set. citeturn17view0turn37view0 |
| `useMagicPromptsStore.ts` | Draft starters/prompt helpers | Low | Inferred citeturn37view0 |
| `useMcpConfigStore.ts` | MCP configuration | High | Inferred; MCP is first-class sidebar section. citeturn36view0turn37view0 |
| `useMcpStore.ts` | MCP server/tool state | High | Inferred citeturn36view0turn37view0 |
| `useMobileSessionExpansionStore.ts` | Mobile-only session tree UI | Low | Inferred citeturn37view0 |
| `useMobileSessionTreeStore.ts` | Mobile-only hierarchy/UI | Low | Inferred citeturn37view0 |
| `useMultiRunStore.ts` | Parallel multi-agent runs | High | Matches README’s multi-agent/worktree feature. citeturn17view0turn37view0 |
| `useOpenInAppsStore.ts` | Open in Finder/Terminal/Editor actions | Low for engine adapter | Inferred; host/runtime-facing. citeturn17view0turn37view0 |
| `usePluginsStore.ts` | Plugin catalog/runtime | High | Inferred; plugins are engine-adjacent. citeturn37view0 |
| `useProjectsStore.ts` | Project/workspace metadata | High | Documented coordination store. citeturn16view0turn37view0 |
| `useQuotaStore.ts` | Usage/quota metrics | Medium | Inferred; usage is first-class sidebar section. citeturn36view0turn37view0 |
| `useSessionDisplayStore.ts` | Session row/presentation metadata | High | Inferred citeturn37view0 |
| `useSessionFoldersStore.ts` | Grouped session hierarchy | High | Documented coordination store. citeturn16view0turn37view0 |
| `useSessionMultiSelectStore.ts` | Session multi-select UI | Medium | Inferred citeturn37view0 |
| `useSessionPinnedStore.ts` | Pinned sessions | Medium | Inferred citeturn37view0 |
| `useSkillsCatalogStore.ts` | Skills catalog | High | Inferred; skills are first-class surfaces. citeturn17view0turn36view0turn37view0 |
| `useSkillsStore.ts` | Local skill management | High | Inferred; README calls out local skill management. citeturn17view0turn37view0 |
| `useSnippetsStore.ts` | Reusable snippets | Low | Inferred citeturn37view0 |
| `useTerminalStore.ts` | Integrated terminal state | High, but host-heavy | Inferred; terminal is a core tab and web host ships PTY/WebSocket deps. citeturn35view2turn23view0turn37view0 |
| `useTodosPersistStore.ts` | Todo persistence | High | Aligns with `todo.updated` and `/session/:id/todo`. citeturn15view0turn37view0 |
| `useUIStore.ts` | Master UI shell state | High | Verified directly. citeturn35view1turn35view2turn35view4 |
| `useUpdateStore.ts` | Built-in updater state | Medium | Documented UI state store + README update flow. citeturn16view0turn17view0turn37view0 |
| `useWorktreeOrderStore.ts` | Worktree ordering for parallel runs | High | Inferred from multi-agent/worktree model. citeturn17view0turn37view0 |

### Verified adapter-sensitive contract

This is the part I would actually freeze into an interface for Goose parity.

| OpenChamber-consumed surface | Where confirmed | Server/client evidence | Goose adapter target | Confidence |
|---|---|---|---|---|
| Message send | OpenCode issue | `POST /session/:sessionID/message` with text/files/agent/model; streamed JSON response. citeturn15view0 | Must exist | Verified-in-source for OpenCode |
| Async message send | OpenCode issue | `POST /session/:sessionID/prompt_async`. citeturn15view0 | Optional shim or hide | Verified-in-source for OpenCode |
| Slash commands | OpenCode issue | `POST /session/:sessionID/command`. citeturn15view0 | Optional if Goose lacks direct equivalent | Verified-in-source for OpenCode |
| Shell execution | OpenCode issue | `POST /session/:sessionID/shell`. citeturn15view0 | Shim or capability-gate | Verified-in-source for OpenCode |
| Message fetch | OpenCode issue | `GET /session/:sessionID/message`. citeturn15view0 | Must exist | Verified-in-source for OpenCode |
| Todo fetch | OpenCode issue | `GET /session/:sessionID/todo`. citeturn15view0 | Hide or synthesize | Verified-in-source for OpenCode |
| Pending questions | OpenCode issue | `GET /question`, reply/reject endpoints, `question.asked` event. citeturn15view0 | Must map if Goose asks for user input | Verified-in-source for OpenCode |
| Pending permissions | OpenCode issue | `GET /permission`, reply endpoint, `permission.asked` event. citeturn15view0 | Must map if Goose confirms tools | Verified-in-source for OpenCode |
| Global event stream | OpenCode issue | `GET /event` SSE with heartbeats and bus events. citeturn15view0 | Must emulate even if Goose uses ACP/native channels | Verified-in-source for OpenCode |
| Session lifecycle events | OpenCode issue | `session.created`, `session.updated`, `session.deleted`, `session.diff`, `session.error`, `session.status`. citeturn15view0 | Must emulate enough for sidebar/live state | Verified-in-source for OpenCode |
| Runtime base URL + auth injection | Web runtime config | `__OPENCHAMBER_API_BASE_URL__`, client token, extra headers, local origin. citeturn39view0 | Reuse unchanged | Verified-in-source |
| SDK client expectation | UI client file | UI package imports `createOpencodeClient, OpencodeClient` from `@opencode-ai/sdk/v2`; default base URL is `VITE_OPENCODE_URL || "/api"`. citeturn40view2 | Implement lookalike client | Verified-in-source |

For session hierarchy and workspace nuance, the strongest verified finding is that OpenChamber’s state model is **not a flat chat list**. Its store docs explicitly describe keyed state by directory, branch, and session id, and call out `useProjectsStore`, `useGlobalSessionsStore`, and `useSessionFoldersStore` as the coordination layer for persistent project/session metadata. Git state is cached per directory and includes branch data. That strongly supports your reading that the sidebar hierarchy is workspace-centric and branch-aware, even though I did not fully verify the exact row renderer and pagination code paths in this pass. citeturn16view0

On theming, the evidence shows enough to place the June pass cleanly. Theme/UI personalization is real state in `useUIStore`: font size, UI font, mono font, padding, corner radius, input bar offset, provider ordering, model favorites/hidden lists, and an `applyTheme()` action all exist. The repo root also exposes a dedicated `vite-theme-plugin.ts`, and the UI source tree has `styles`, `assets`, and typography/font infrastructure. That means the least-fragile place for the June work is **token override and derived CSS variables**, not component-by-component restyling. citeturn17view0turn35view1turn35view4turn29view0

## Embedding and OpenCode runtime

The `WKWebView` viability case is strong. OpenChamber is already shipped as a browser/PWA app, and its web host proves that the UI package can run without Electron by simply installing runtime APIs, importing shared CSS/fonts, and loading `@openchamber/ui/main`. In other words, **`packages/ui` is already a pure browser app when the host provides the runtime bridge**. citeturn27view0turn18view0

The browser host also shows exactly what to disable when embedding. In production it calls `registerSW(...)`; in development it explicitly unregisters existing service workers. In a vendored `WKWebView`, you do not want the PWA lifecycle at all, especially if you are loading from a bundled/custom origin. Disable service-worker registration and any self-update prompt path exposed through `useUpdateStore`. OpenChamber’s README also advertises a built-in self-update + restart flow for the web/PWA, which is the wrong ownership boundary for Epistemos because your update source should be the vendored donor merge, not the donor app’s updater UX. citeturn27view0turn17view0turn37view0

The origin/CORS story is straightforward but important:

| Embed choice | What happens | Recommendation | Confidence |
|---|---|---|---|
| Custom app/file origin calling `http://127.0.0.1` OpenCode | `WKWebView` enforces browser CORS; localhost server must explicitly allow the origin. WebKit discussions around hybrid/custom-scheme apps also show service-worker limitations and cross-origin friction outside normal HTTP/HTTPS. citeturn38search1turn38search3turn38search6turn38search7turn38search19turn38search21 | Acceptable if you inject headers/tokens and configure CORS; do **not** rely on SW/PWA behavior | Mixed: official + platform-history evidence |
| HTTP local origin hosting the UI | Closest match to how OpenChamber web expects to run | Cleanest technically, but less attractive if you want fully vendored UI assets inside the app bundle | Inferred |
| Bundled custom scheme with no SW | Works as an embedded app shell, provided runtime config points API calls at localhost and OpenCode CORS allows it | **Best compromise for Epistemos** | Inferred |

OpenCode’s server surface is unusually well documented in its own issue tracker. The `opencode web` command starts a **local Hono HTTP server**, default port `4096`, with a frontend that talks over **REST plus SSE**. The key consumed endpoints are:

| Surface | Endpoint / event | Notes | Confidence |
|---|---|---|---|
| Message fetch | `GET /session/:sessionID/message` | Returns messages/parts | Verified-in-source citeturn15view0 |
| Message send | `POST /session/:sessionID/message` | Streams assistant response as JSON | Verified-in-source citeturn15view0 |
| Async send | `POST /session/:sessionID/prompt_async` | Fire-and-return path | Verified-in-source citeturn15view0 |
| Command send | `POST /session/:sessionID/command` | Slash/command execution | Verified-in-source citeturn15view0 |
| Shell send | `POST /session/:sessionID/shell` | Shell execution route | Verified-in-source citeturn15view0 |
| Todo fetch | `GET /session/:sessionID/todo` | Current todos per session | Verified-in-source citeturn15view0 |
| Question flow | `GET /question`, `POST /question/:requestID/reply`, `POST /question/:requestID/reject` | User-input requests | Verified-in-source citeturn15view0 |
| Permission flow | `GET /permission`, `POST /permission/:requestID/reply` | Tool approvals/denials | Verified-in-source citeturn15view0 |
| Realtime updates | `GET /event` SSE | Heartbeats every 30s; forwards bus events | Verified-in-source citeturn15view0 |

The event layer is what matters most for UI fidelity. OpenCode publishes `message.updated`, `message.removed`, `message.part.updated`, `message.part.removed`, `todo.updated`, `question.asked`, `permission.asked`, `session.created`, `session.updated`, `session.deleted`, `session.diff`, `session.error`, and `session.status`. That is enough to explain why OpenChamber can be live and reactive without polling. It is also why a Goose adapter should **prefer emitting a synthetic SSE bus** rather than splicing Goose event semantics directly through the component tree. citeturn15view0

Authentication and CORS are also source-backed. If `OPENCODE_SERVER_PASSWORD` is set, OpenCode uses HTTP Basic Auth with a configurable username and password. Separately, the server allows connections from `localhost` and `127.0.0.1` on any port, `tauri://localhost`, `*.opencode.ai` over HTTPS, plus custom origins via `--cors`. OpenChamber’s web runtime supports bearer token injection and extra runtime headers via `__OPENCHAMBER_CLIENT_TOKEN__` and `__OPENCHAMBER_RUNTIME_HEADERS__`, and it resolves API base URLs from `__OPENCHAMBER_API_BASE_URL__`. citeturn15view0turn39view0

For macOS supervision, the clearest evidence is indirect but good enough to ground a recommendation: OpenChamber’s README says the desktop bundle packages a matching OpenCode CLI, while the VS Code extension can either auto-start a local instance or point at an external URL and an explicit `opencode` binary path. That strongly supports your intended packaging model: **ship a pinned OpenCode binary inside the app bundle, supervise it from Swift, and inject the resulting localhost base URL into the web surface**. I did **not** verify upstream disk or memory footprint in the captured sources, so that part remains open. citeturn17view0turn26view0

## Goose adapter and engine topology

Goose’s public repo confirms the high-level parts you care about, even though this pass did not fully verify the crate-level HTTP routes. Goose has moved from `block/goose` to `aaif-goose/goose`; it positions itself as a **native desktop app, CLI, and API**, written in Rust, with 15+ providers and ACP-backed access to existing Claude/ChatGPT/Gemini subscriptions, plus 70+ extensions via MCP. citeturn43view4turn43view5

That means Goose is a plausible second engine, but the adapter burden is real because the UI donor is natively OpenCode-shaped. The right architectural move is:

1. **Keep all OpenChamber stores consuming a single “OpenCode-like” client contract.**
2. **Inject either the real OpenCode client or a Goose-backed implementation of the same contract.**
3. **Normalize Goose-native events into the OpenChamber event vocabulary** rather than teaching the UI a second event system.

The mapping table below is therefore split into what is verified on the OpenCode side and what is currently inferred on the Goose side.

| OpenChamber / OpenCode contract | Goose equivalent | Gap | Action | Confidence |
|---|---|---|---|---|
| Session list / session metadata | Goose sessions | Probably mappable | Direct adapter | OpenCode side verified; Goose side inferred citeturn15view0turn43view4 |
| Session messages + parts | Goose session transcript / message parts | Likely mappable | Direct adapter | Mixed |
| Streaming message deltas | Goose streaming API/ACP events | Event vocabulary mismatch likely | Normalize into `message.part.updated` SSE | Mixed |
| Permission requests | Goose tool confirmations / approvals | Naming and payload mismatch likely | Shim into OpenCode-style permission store | Inferred from Goose product shape citeturn43view4 |
| Question / elicitation flow | Goose user-input questions | Likely present in some form | Shim to `question.asked/reply/reject` | Inferred |
| Todos per session | No Goose evidence captured | Feature gap | Hide or synthesize from structured plan/subtask output | Uncertain |
| Slash commands | 1:1 equivalent not verified | Possible gap | Hide unless Goose exposes it | Uncertain |
| Shell endpoint | Goose may expose tool execution, but not necessarily shell as a public endpoint | Semantics mismatch | Capability-gate | Inferred |
| Session diff summary | Goose desktop likely has diffs, but route/event not verified | Partial gap | Derive from file-change state if available; otherwise hide summary-only affordance | Inferred |
| Provider/model catalog | Goose provider set exists publicly | Needs normalized list/aliasing | Direct adapter + engine-scoped aliases | Verified for provider breadth, inferred for exact API citeturn43view4 |
| Projects / working directory | Goose likely supports project/workdir concepts; exact source not verified in captured pages | Probably mappable | Direct adapter | Inferred |
| Branch binding in session tree | No native Goose branch-binding evidence captured | Real semantic gap | Group Goose sessions by directory/project only; optionally annotate current git branch as a secondary label, not a bound identity | Inferred |

That last row is the most important sidebar nuance. OpenChamber’s own store documentation explicitly says identity may be keyed by directory, branch, and session id, and its git cache includes branch state. I therefore think your addendum is correct: **OpenChamber wants branch-aware grouping**, while **Goose should probably degrade to directory/project grouping with optional branch decoration**, not fake branch-bound sessions. citeturn16view0

On engine topology, the best way to keep one UI and one merged session list is:

| Capability family | Put it where | Why | Confidence |
|---|---|---|---|
| OpenCode-native coding sessions | OpenCode engine | Native donor pairing | Verified/inferred citeturn17view0turn15view0 |
| Claude / OpenAI / other hosted models where OpenCode can already offer them | Prefer **OpenCode providers/models** | Keeps UI and adapter surface smallest | Inferred |
| Goose ACP/native-subscription paths | Goose engine | That is Goose’s distinct value proposition | Verified at high level citeturn43view4turn43view5 |
| MCP/extension-heavy workflows | Goose or whichever engine actually exposes them | Must show real capability only | Verified principle from source mix citeturn43view4turn36view0 |
| Claude Code / Codex CLI | **Do not** add as separate direct engines in v1 | That recreates 1Code’s orchestration shape and expands the adapter/UI contract | Inferred, grounded by 1Code’s product shape citeturn42view0 |
| Hugging Face / BYOK custom providers | Prefer whichever engine already normalizes them better; default to OpenCode unless Goose-only | Least adapter work | Inferred |

So my answer to your “should CLI agents ever be direct engines?” question is **no for v1**. Let them ride through OpenCode or Goose if either engine can surface them. A third direct-engine family would push you toward 1Code’s app model instead of OpenChamber’s.

## 1Code study and June signature

1Code is the best evidence for the **kind** of future enhancements you are attracted to, and the repo source makes that explicit. Its README calls it an “orchestration layer for coding agents,” with Claude Code and Codex as first-class citizens, and highlights worktree isolation, background agents in cloud sandboxes, live browser previews, diff previews, built-in Git, file viewer, terminal, message queue, plan mode, extended thinking with visual UX, sub-agents, MCP/plugins, and automations. The repo shape also reflects a full Electron-style product with `main`, `preload`, `renderer`, and `shared` code, not a drop-in chat surface component library. citeturn42view0turn42view2turn44view0

That leads to a clean distinction between what is **UI-only inspiration** and what is **engine-dependent infrastructure**:

| 1Code trait | Source evidence | UI-only or engine-dependent | Value-to-effort for Epistemos | Confidence |
|---|---|---|---|---|
| Rich diff previews and built-in git workflow | README highlights realtime diff previews, built-in Git, rollback, git activity badges. citeturn42view2 | Mostly UI + existing OpenChamber/git substrate | **High value / medium effort** | Verified-in-source |
| Message queue | Explicit feature. citeturn42view0turn42view2 | UI/store level, donor-compatible | **High value / low-medium effort** | Verified-in-source |
| Plan mode with structured preview | Explicit feature. citeturn42view0turn42view2 | UI + engine prompts; OpenChamber already has plan/build concepts | **High value / low effort** | Verified-in-source |
| Extended-thinking visual treatment / “cooking” feel | Explicit “Extended Thinking … visual UX / visual thinking gradient.” citeturn42view0turn42view2 | Mostly UI-only if you already have reasoning blocks | **High value / low effort** | Verified-in-source |
| Sub-agent sidebar task display | Explicit feature. citeturn42view0turn42view2 | UI plus multi-run engine data | **Medium-high value / medium effort** | Verified-in-source |
| Worktree-isolated chats | Explicit feature. citeturn42view0turn42view2 | Engine/runtime-dependent | **Medium value / high effort** unless inherited from donor/engine | Verified-in-source |
| Background agents in cloud sandboxes | Explicit feature. citeturn42view0turn42view2 | Strongly engine/platform-dependent | **Lower immediate value / very high effort** | Verified-in-source |
| Automations from GitHub/Slack/Linear/git events | Explicit feature. citeturn42view0 | Engine/platform product feature | **Future-only** | Verified-in-source |
| Live browser previews | Explicit feature. citeturn42view0turn42view2 | Host/runtime + project action integration | **Medium value / medium-high effort** | Verified-in-source |

The practical takeaway is that **1Code is a study donor, not a surface donor**. The nicest near-term wins are the ones you specifically named: the “cooking” or thinking-state animation language, chat-surface polish, and possibly some diff-review affordances. Those can be rebuilt from OpenChamber primitives without violating your one-donor rule. The deeper 1Code behaviors — direct Claude/Codex orchestration, background cloud agents, extensive automation, center-of-gravity around worktrees — are the parts you should *not* import into the Epistemos rebuild if the goal is smallest adapter surface and least feature loss risk.

On June: in this pass I am treating June as a **design specification**, not a verified public code donor. For the implementation, the right move is a **token-derived landing-only signature layer** on top of OpenChamber’s theming infrastructure.

I recommend this gradient formula for every theme, including custom user palettes:

```text
landing-bg-start = mix(theme.background, theme.surface, 88%)
landing-bg-end   = mix(theme.background, theme.accent, 6% to 10%)
landing-glow     = color-mix(in oklab, theme.accent 12%, transparent)
bar-fill         = mix(theme.surface, white, theme.isLight ? 18% : 4%)
bar-stroke       = mix(theme.border, theme.accent, 14%)
bar-shadow       = theme.isLight
  ? 0 16px 40px color-mix(in oklab, theme.accent 8%, transparent)
  : 0 16px 40px color-mix(in oklab, black 30%, transparent)
```

For the **classic** theme, that yields the exact effect you want: essentially white at the top, warming into a slight tan wash because the end color is only a light accent mix into the background, not a full accent gradient.

The clean hook points are:

| June requirement | Hook point in donor | Why | Confidence |
|---|---|---|---|
| Token-level warm pass | Theme variables / design-system layer plus `applyTheme()` state | Donor already centralizes UI personalization and theme application. citeturn35view4 | Inferred |
| Per-theme automatic gradient | New derived CSS vars emitted beside theme vars | Keeps custom palettes working automatically | Inferred |
| Literal landing composer shell | New self-contained landing component rendered only for the empty/new-session state | Avoids forking the whole donor surface | Inferred |
| Typewriter greeting headline | Replace only landing headline content, keep project/branch/workspace affordances intact | Matches your design goal and least-invasive donor strategy | Inferred |

## Upstreaming, navigation, risks, and ledger

The update strategy should optimize for **near-automatic donor pulls** without turning every upstream merge into a UI archaeology dig. For OpenChamber, the vendor strategy I would choose is **a fork with upstream remote** if Epistemos already behaves like a monorepo-ish app, and **strict overlay discipline** inside that fork:

| Strategy | OpenChamber fit | Why | Confidence |
|---|---|---|---|
| Fork + upstream remote | **Best** | You will almost certainly need a few unavoidable in-place edits around runtime injection and updater suppression, and a fork handles that more cleanly than a submodule. | Inferred |
| Git subtree | Good second choice | Easier if you want OpenChamber inside another repo without nested Git UX | Inferred |
| Submodule | Weakest fit here | Adds friction for solo-dev workflow and local overlay patches | Inferred |

The local-change discipline should be:

| Rule | Practical meaning |
|---|---|
| New local behavior goes in **new files** | Your Goose adapter, June theme overrides, signature landing component, and Swift-runtime bridge should all live as additive layers |
| Every unavoidable donor edit gets a **patch ledger row** | File, exact reason, whether upstreamable, merge sensitivity |
| Disable donor updater UX centrally | Don’t let a vendored UI offer to update itself |
| Version pin hard | Pin OpenChamber SHA/tag, `@opencode-ai/sdk` exact version, and bundled OpenCode binary version together |

That is especially important because the UI package pins `@opencode-ai/sdk` directly, and OpenChamber’s runtime client is explicitly written around `@opencode-ai/sdk/v2`. SDK churn is therefore one of the most real risks in the stack. citeturn22view3turn40view2

On navigation restructure, the least-invasive structure is:

| Native Epistemos destination | What lives there | Recommendation |
|---|---|---|
| Home | Your native landing / typewriter / summary surfaces | Native |
| Agent | **Entire OpenChamber workspace shell** | Use as-is, with internal OpenChamber tabs/panels untouched |
| Notes | Native Epistemos notes | Native |
| History | Prefer native Epistemos app history, **not** donor session-history internals | Native if it is app-wide; otherwise keep donor session timeline inside Agent |
| Settings | Prefer Epistemos-wide settings natively, but keep engine/workspace-specific settings shell inside Agent | Hybrid |
| Meetings later | Native | Deferred |

That recommendation is grounded in how OpenChamber models itself: internal tabbed workspace plus settings/timeline dialog state, not a page router. citeturn35view2turn35view4turn36view0

The main risks and order of operations look like this:

| Risk | Why it matters | Mitigation | Confidence |
|---|---|---|---|
| SDK churn | UI package is hard-wired to `@opencode-ai/sdk/v2` | Exact-version pinning; adapter contract tests | Verified/inferred citeturn40view2 |
| Store coupling | OpenChamber stores assume OpenCode event vocabulary | Normalize Goose into synthetic OpenCode-like SSE | Verified/inferred citeturn15view0turn16view0 |
| `WKWebView` origin surprises | Custom/file origins make CORS/SW behavior trickier | Disable SW; explicit localhost CORS; inject runtime headers | Verified/inferred citeturn27view0turn38search6turn39view0 |
| Two-engine merged session list | Sidebar is workspace-centric, not flat | Keep one hierarchy, badge by engine, degrade Goose branch binding honestly | Inferred |
| Updater collisions | OpenChamber exposes update flow | Remove/replace updater affordances through overlay | Verified/inferred citeturn17view0turn37view0 |
| Theme collisions | June pass can sprawl into donor components | Token-only pass + landing-only transplant first | Inferred |
| Terminal/runtime host differences | OpenChamber terminal leans on host/runtime deps | Treat terminal as capability-gated by engine/host reality | Verified/inferred citeturn23view0turn35view2 |
| Goose gap surface | Todos/branch binding/command semantics may not match | Maintain hide-list and shim-list explicitly | Inferred |
| Over-pulling 1Code ideas | Easy way to accidentally create a third product shape | Restrict to UI-only polish first | Verified/inferred citeturn42view0turn42view2 |
| Owner-signature leakage | Native pill/all-chats/typewriter can end up forking donor core | Keep all signatures outside donor core or landing-only | Inferred |

The refined phase order I would use is:

| Phase | Goal | Done means |
|---|---|---|
| Donor refresh | Re-vendor latest OpenChamber; pin OpenCode SDK/binary versions | UI loads unchanged in current host |
| Browser embed | Mount OpenChamber inside the existing `WKWebView` with runtime config injection; disable SW/updater | OpenCode engine works end-to-end |
| Native signatures | Add native toolbar pill, landing headline, all-chats native overlay, June gradient/composer shell | Visual shell matches Epistemos |
| Capability truth | Hide absent affordances based on live engine capability set | No fake chips or panels |
| Goose adapter | Implement SDK-shaped client + SSE normalizer | Existing stores work unchanged against Goose |
| Merged hierarchy | One session surface with engine badges and honest grouping degradation | Session UX feels singular |
| Ledger closure | Walk every feature row until no pending gaps remain | Zero unapproved losses |

The seeded feature ledger below is deliberately broad rather than microscopic, because the point at this stage is to prevent silent loss.

| Feature | Source | Where it lives in new app | Providing engine(s) | Risk of loss |
|---|---|---|---|---|
| Branchable timeline / undo / redo / fork | OpenChamber README citeturn17view0 | Agent chat/timeline | OpenCode first; Goose if adapter can emulate | Medium |
| Smart tool UIs for diffs/files/permissions/progress | OpenChamber README citeturn17view0 | Agent chat/tool surface | Both, capability-gated | Medium |
| Voice mode / dictation | OpenChamber README + 1Code README citeturn17view0turn42view0 | Agent landing/composer | Host/native + engine-agnostic | Medium |
| Multi-agent runs / worktrees | OpenChamber README / 1Code README citeturn17view0turn42view2 | Agent advanced workflow | OpenCode initially | High |
| Git workflows in-app | OpenChamber README citeturn17view0 | Right panel / git tab | Engine + host | Medium |
| GitHub-native issue/PR starts | OpenChamber README citeturn17view0 | Agent entry points | OpenCode initially | Medium |
| Plan/build mode | OpenChamber README + UI tabs citeturn17view0turn35view2 | Agent composer + plan tab | Both if real | Low |
| Inline comments on diffs/files/plans | OpenChamber README citeturn17view0 | Agent review surfaces | Both where supported | Medium |
| Token/cost/context visibility | OpenChamber README + usage sidebar surface citeturn17view0turn36view0 | Agent sidebars/settings | Engine-specific | Medium |
| Integrated terminal | OpenChamber README + tabs/deps citeturn17view0turn35view2turn23view0 | Agent terminal tab | Host/runtime, maybe engine-assisted | Medium |
| Skills catalog / local skills | OpenChamber README + sidebar/store inventory citeturn17view0turn36view0turn37view0 | Agent sidebar/settings | Engine-specific | Medium |
| Providers / models / favorites / hidden models | UI state + config surfaces citeturn34view5turn36view0 | Agent settings/composer chips | Engine-specific | Low |
| Permissions / approvals | OpenCode issue citeturn15view0 | Agent modal/sheet | Both via normalized contract | Low |
| Questions / elicitations | OpenCode issue citeturn15view0 | Agent modal/sheet | Both via normalized contract | Low |
| Todos | OpenCode issue + `useTodosPersistStore` citeturn15view0turn37view0 | Agent context panel | OpenCode native; Goose uncertain | High |
| MCP / plugins / extensions | Sidebar + Goose/1Code capabilities citeturn36view0turn43view4turn42view0 | Agent sidebar/settings | Engine-specific | Medium |
| Session queue | 1Code README citeturn42view0turn42view2 | Agent chat/composer | UI-level enhancement | Low |
| All-chats grouped overlay | Owner signature | Native sheet over Agent | Both | Low |
| Native toolbar pill | Owner signature | Native macOS chrome | N/A | Low |
| Typewriter landing greeting | Owner signature | Native/web landing hybrid | N/A | Low |
| June message bar shell | Owner signature | Landing-only composer shell | N/A | Low |
| Theme-derived gradient | Owner signature + donor theming layer | Landing background | N/A | Low |

**Open questions for the owner**

| Question | Why it matters |
|---|---|
| Is Goose session grouping by directory/project, with branch shown only as a label, acceptable for v1? | This is the most likely real degradation versus OpenChamber’s branch-aware hierarchy |
| Should the June-style bar remain landing-only, or should its shell also replace the empty-session composer in-workspace? | Important for scope control |
| Do you want app-wide Settings to be native while engine/workspace settings stay inside Agent, or do you want all settings centered in Agent first? | Prevents navigation churn |
| Is the all-chats overlay allowed to be a native grouped sheet that mirrors donor hierarchy, even if some in-row actions initially dispatch back into the web surface? | Easiest parity route |
| Which features, if any, are acceptable to defer behind explicit ledger rows instead of blocking the first ship? | Needed for honest zero-loss governance |
| Do you want Claude Code/Codex exposed only through engine/provider plumbing at launch, or do you want them named in marketing copy even if not separate engines? | Avoids UI over-promising |

## External research prompt

Use this as a copy-paste prompt for a separate online research model when you want a second pass that goes even deeper into source files and issue history:

```text
Research task: produce an execution dossier for rebuilding the AI-agent surface of a native macOS Swift app called Epistemos.

Context and fixed architecture:
- One section of the app, to be renamed “Agent,” currently embeds a heavily forked Goose desktop web UI inside a WKWebView and talks to a supervised local backend.
- That UI is being replaced.
- The locked base donor is OpenChamber (github.com/openchamber/openchamber, MIT). Its full UI becomes the Agent surface, vendored and mounted inside the existing WKWebView.
- There are exactly two engines behind one seam:
  - Engine 1: OpenCode server, as the native pairing.
  - Engine 2: Goose via an adapter. Goose backend crates must never be modified.
- Engine is chosen per conversation via a composer chip.
- There is one merged session list with engine badges.
- The UI must always show the active engine’s real capabilities only. Hide absent features. Never fake parity.
- Epistemos keeps these signatures:
  - native macOS toolbar pill for page navigation
  - typewriter landing greeting
  - all-chats overlay
  - June-inspired landing message bar and theme-derived landing gradient
- 1Code (github.com/21st-dev/1code, Apache-2.0) is a study donor only. If anything is adopted, it must be rebuilt from OpenChamber primitives. No component mixing inside the Agent surface.
- Hard rule: nothing may be lost. Every current feature must be accounted for in a feature ledger.

Study these sources deeply:
- openchamber/openchamber
- OpenChamber docs/site if available
- anomalyco/opencode or current upstream repo + opencode.ai docs
- @opencode-ai/sdk
- aaif-goose/goose (formerly block/goose), including desktop UI for feature inventory and backend/API/ACP docs
- 21st-dev/1code
- If June source is publicly locatable, study its landing composer and gradient implementation. Otherwise treat June as a design spec: literal landing bar feel + theme-aware white-to-tan wash in classic mode, derived from tokens in every theme.

Output requirements:
- Structured dossier with sections covering:
  1) OpenChamber monorepo map
  2) packages/ui mount pattern across web/electron/vscode hosts
  3) internal navigation/view model and session/workspace hierarchy
  4) exhaustive stores inventory at packages/ui/src/stores/*
  5) every direct @opencode-ai/sdk call and every event subscription in stores or client helpers
  6) right-panel requirements and server dependencies
  7) theming system and exact hook points for June token pass + per-theme gradient
  8) WKWebView/browser viability, PWA/service-worker behaviors to disable, and custom-origin/localhost CORS details
  9) exact OpenCode server surface consumed by the UI: endpoints, auth, SSE/events
  10) bundled-binary supervision strategy on macOS
  11) Goose HTTP/API/ACP surface and feature inventory
  12) mapping table: OpenChamber/OpenCode contract row → Goose equivalent → gap → hide vs shim
  13) recommended adapter architecture: an @opencode-ai/sdk-shaped client implementation consumed unchanged by the stores
  14) engine topology recommendation for Claude, Codex, OpenCode, Hugging Face, MCP/extensions, and CLI agents
  15) 1Code study: cooking/thinking animations, chat-surface details, diff review UX, worktree orchestration, background execution model
  16) upstream auto-update strategy: fork vs subtree vs submodule, overlay discipline, patch ledger, update workflow
  17) navigation restructure recommendation for Home / Agent / Notes / History / Settings / Meetings
  18) June landing signature implementation recommendation
  19) top risks with mitigations
  20) phase order
  21) seeded feature ledger

Critical constraints:
- Use file-level citations wherever possible, preferably GitHub blob links and exact file paths.
- Include a confidence column for every major claim: verified-in-source / inferred / uncertain.
- If something cannot be verified, say so explicitly and state what file or path needs manual follow-up.
- Do not give generic advice. Every recommendation must be tied to observed source facts.
- The answer should optimize for upstream auto-updateability, one UI base donor, zero silent feature loss, and the smallest possible adapter surface.

Special attention:
- OpenChamber session hierarchy is workspace-centric, not a flat chat list. Map “recent,” workspace folders, branch nodes, and session actions precisely.
- Document whether sessions are bound to project + git branch and which APIs/stores supply that.
- Then map that against Goose, which may have working_dir/project_id without native branch binding.
- Capture model aliasing/custom display names if present.
- Capture pagination / “show more sessions” behavior if present.
- Capture built-in updater behavior and explain how a vendored embed should disable/replace it.
- For June, recommend a token-derived gradient formula that makes classic mode mostly white with a slight tan wash while allowing every theme to derive its own landing gradient automatically.
```

gemini 1 - 

Architectural Blueprint for Epistemos: Dual-Engine OpenChamber IntegrationThis dossier provides the formal technical specification for rebuilding the AI-agent user interface of "Epistemos," a native macOS application written in Swift. The system architecture replaces the legacy, heavily-forked Goose desktop web interface inside a macOS WKWebView with a unified frontend based on OpenChamber. It introduces a single-seam architecture supporting two parallel local engines: OpenCode server natively, and Goose via a custom client-side adapter. This configuration operates without modifying the Goose core Rust crates or introducing component-mixing anti-patterns.1. OpenChamber MapMonorepo Anatomy and Host MountsThe OpenChamber repository is structured as a TypeScript monorepo managed with Bun. It separates core UI components and state management from the native execution environments:packages/ui: The visual core, containing shared React components, hooks, Tailwind/CSS styling, and Zustand stores. It contains no Node.js or Electron-specific runtime requirements.packages/web: Contains the Express API server and Vite assets that package the PWA and the primary CLI web distribution.packages/electron: An Electron shell wrapping the application, providing native menus, deep linking, and lifecycle orchestration.packages/vscode: A VS Code extension wrapping the web UI inside an extension Webview panel.To mount this inside the native macOS Swift app, the compiler packages only packages/ui and its static compilation outputs. The Electron shell (packages/electron) is completely discarded. Epistemos hosts a custom local server or direct file-scheme handler within WKWebView to serve the static SPA bundle compiled from packages/ui.Navigation and View ModelRouting in OpenChamber's client UI operates inside packages/ui/src/components/views and is coordinated by a central view store rather than a standard browser history router. The core interface acts as a single-page workspace where views are treated as panels (e.g., chat, editor, files tree, context sidebar).Internal routing between the primary workspace view and the Settings screen is handled via explicit panel state toggles within the UI store. Epistemos bypasses OpenChamber's global page-level settings layouts to mount standalone views cleanly through Swift coordinate controls.Stores Layer and Adapter ContractState synchronization and remote execution in OpenChamber rely on Zustand stores located in packages/ui/src/stores/. These stores communicate with the backend via the standard @opencode-ai/sdk. To support Goose as a secondary engine without modifying the UI layer, these stores must consume an abstracted SDK interface.The following table catalogs the stores layer, mapping every critical store to its upstream SDK invocations and event subscriptions. This structural inventory defines the Adapter Contract that the Goose engine adapter must implement.Store NameFile PathUpstream SDK / Client MethodEvent Subscriptions (SSE/WS)Epistemos Adaptation Impact (Dual-Engine)Claim ConfidenceuseConfigStorepackages/ui/src/stores/useConfigStore.tsclient.provider.list(), client.provider.create(), client.provider.update()[cite: 8]None (REST polling fallback)Must dynamically merge OpenCode and Goose providers. __add_provider__ sentinels must be guarded during adapter switches.Verified in SourceuseSessionStorepackages/ui/src/stores/useSessionStore.tsclient.session.list(), client.session.create(), client.session.delete()[cite: 7, 8, 9]SSE /api/events (Session updates, additions, deletions)High. Requires a single unified store that merges active sessions from both engine runtimes.Verified in SourceuseChatStorepackages/ui/src/stores/useChatStore.tsclient.session.prompt(), client.session.cancel()[cite: 8, 9]SSE /api/events (Message deltas, tool-approval requests, token costs)Critical. Must route prompt requests to the correct engine based on the active conversation's engine metadata.Verified in SourceuseFileStorepackages/ui/src/stores/useFileStore.tsclient.fs.read(), client.fs.write(), client.fs.list(), client.fs.search()[cite: 5]WebSocket /api/terminal (File modification triggers)System-level directory access. When running Goose, references must read from the Goose-configured workspace root.Verified in SourceuseGitStorepackages/ui/src/stores/useGitStore.tsclient.git.status(), client.git.stage(), client.git.commit(), client.git.branch()[cite: 5]None (polling on focus)Must bind to the active Git repository of the current workspace.Verified in SourceuseUpdateStorepackages/ui/src/stores/useUpdateStore.tsPOST /api/openchamber/update-install[cite: 11]Polling /api/openchamber/update-check[cite: 11]Disabled. Update logic must be stubbed or bound directly to the Swift native host updater.Verified in SourceTheming SystemTheming is orchestrated through CSS custom properties defined in packages/ui/src/styles/design-system.css and compiled via a Vite custom theme plugin (vite-theme-plugin.ts). Themes are loaded as JSON structures mapping custom values to standard design tokens.A global interface (useUIStore) manages theme switching by writing dynamic variables to the Document Object Model root. The June-warm token overrides must hook into this store to intercept variables during initialization, modifying standard background, surface, and text colors.Permission and Approval FlowOpenChamber enforces an interactive human-in-the-loop authorization model for destructive actions like file edits and shell executions. When the server-side engine executes a tool requiring approval, it pushes a permission.asked event over the Server-Sent Events stream. The frontend suspends chat rendering, shows an inline approval card via the useChatStore state, and returns the response using client.permission.reply(). The Goose adapter must translate the Agent Client Protocol’s tool confirmation requests into this permission.asked/reply pipeline.Session and Workspace HierarchyOpenChamber groups conversations under explicit physical workspaces mapped to directories on the local file system:Workspace Model: Every conversation is bound to a workspace directory root (useSessionStore). Creating a new session requires selecting a workspace directory. The UI presents workspace folders in a nested navigation layout in the session sidebar.Branch Awareness: OpenChamber includes native Git branch binding. The sidebar shows active branch nodes next to the project selection dropdown. The active branch is read directly from Git server-side utility APIs (client.git.branch()) and acts as a dynamic folder partition.Sidebar Controls: Standard operations in the session list include hover-triggered session deletion, an action menu (providing duplication, export, and rename options), and pagination driven by cursor offsets.Model Aliasing: Configured in useConfigStore, the client matches API model names with developer-defined display aliases (e.g., renaming gpt-5.1-ultra to a friendly alias). These aliases are managed globally.2. WKWebView ViabilityBrowser-Only VerificationThe compilation pipeline of @openchamber/web proves that the entire shared UI interface operates cleanly as a pure browser application. The React layout builds into flat static assets (index.html, CSS, and JS compilation chunks) capable of running inside client sandboxes.packages/web/dist/  <-- Pure SPA Assets
├── index.html      <-- Single-point mounting container
├── assets/
│   ├── index-[hash].js
│   └── index-[hash].css
Dependency Audit and Node.js PathsAn audit of packages/ui shows that direct dependency on Node.js core libraries (fs, path, child_process) or native Electron bridges is systematically avoided in the layout layers:Platform Bridging: Platform-specific logic is abstracted through dynamic execution checks inside packages/ui/src/utils/bridge.ts.Host Isolation: Native functions—like system directories, menu interactions, and deep linking—are loaded conditionally depending on active bridge definitions (window.electronBridge or window.vscodeBridge).Fallback Paths: If no desktop helper interface is active, the stores fallback to standard browser interfaces, routing system-level file system requests through secure HTTP REST ports.Subsystems to DisableTo isolate the application and prevent conflict with native macOS sandboxing controls within WKWebView, specific subsystems are modified or disabled:Vite PWA Service Worker: Set offline: false in the Vite build configuration.Notification Triggers: Stub packages/ui/src/hooks/useNotifications.ts to return early and bypass browser notification APIs.Local Storage Sync Locking: Turn off automatic offline indexing synchronization to let the macOS host manage data persistence.WKWebView Cross-Origin Security and SSEBecause WKWebView loads assets locally via a custom scheme (epistemos://app or file://), it faces standard browser security restrictions when accessing local loopback ports on http://localhost:3000:CORS Configuration: The loopback servers (OpenCode and Goose) are configured to return headers allowing access from the custom app scheme:HTTPAccess-Control-Allow-Origin: epistemos://app
Access-Control-Allow-Headers: Content-Type, Authorization
WKWebView Security Rules: The Swift container relaxes local file scheme rules to permit cross-origin requests from inside the webview:Swiftlet configuration = WKWebViewConfiguration()
configuration.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
configuration.preferences.setValue(true, forKey: "universalAccessFromFileURLs")
Stream Limitations: To prevent the WebKit runtime from blocking connection pools on localhost over standard HTTP/1.1, the local servers support H2C (HTTP/2 cleartext) or consolidate requests through a single gateway.3. OpenCode as Engine #1Server Surface and API ContractsThe native pairing engine, OpenCode server, exposes a comprehensive API that maps cleanly to OpenChamber's client stores:OpenCode Server API Surface (Localhost:3000)
├── GET/POST /api/sessions        --> Create/List Conversations
├── POST     /api/sessions/:id    --> Send Prompt & Stream Events (SSE)
├── GET      /api/fs/list         --> Tree Explorer Payload
├── GET      /api/providers       --> Engine and Model Availability
└── POST     /api/permission/reply --> Respond to Tool-Execution Prompts
Authentication relies on local tokens generated on launch and written to the configuration directory (~/.config/openchamber/). The Swift app captures these credentials to sign outbound HTTP requests with authorization headers:HTTPAuthorization: Bearer <local_runtime_token>
Headless macOS Supervision and BundlingTo ensure a zero-dependency installation, the OpenCode server is compiled as a native Apple Silicon and Intel binary and placed inside the macOS app bundle's helper resources:Epistemos.app/Contents/Resources/bin/opencode-server
The Swift process lifecycle controller monitors the executable:Swift// Swift Process Supervision Lifecycle
class OpenCodeSuperviser {
    private var process: Process?
    
    func startServer(port: Int, dataDir: URL) {
        let process = Process()
        process.executableURL = Bundle.main.url(forResource: "opencode-server", withExtension: nil)
        process.arguments = ["--port", "\(port)", "--data-dir", dataDir.path, "--foreground"] //
        process.environment = ProcessInfo.processInfo.environment
        // Set standard output pipes to capture health states
        self.process = process
        try? process.run()
    }
    
    func stopServer() {
        process?.terminate()
    }
}
The process executes under the --foreground flag, enabling the macOS parent process to clean up children when the user quits the main application.Lifecycle Hierarchy
[Native macOS App (Epistemos)] -- (Monitors PID) --> [opencode-server (Port 3000)]
                                 -- (Monitors PID) --> [goosed acp-server (Port 4096)]
Multi-Provider ConfigurationOpenCode handles its configuration through the global ~/.opencode.json file. The client interface lets users manage multiple API keys, custom base URLs, and custom endpoint patterns, writing these keys directly to this configuration.Agent Modes RepresentationOpenCode exposes two built-in agents:build: A full-access agent that can perform read and write file system modifications.plan: A read-only analysis agent that requires explicit developer authorization before executing shell commands or writing files.These roles map directly to the composer state: switching modes modifies the system prompt and client-side tool rules.4. Goose as Engine #2Goose HTTP/ACP SurfaceGoose exposes its capabilities through goosed using the Agent Client Protocol (ACP) over standard HTTP interfaces. This backend serves as a stateless orchestration system that interacts with various LLM providers and executes tasks using Model Context Protocol (MCP) tool extensions.OpenChamber to Goose Translation MappingThe Goose engine adapter acts as a client-side bridge inside the webview. It sits between @openchamber/ui's state layer and the goosed ACP endpoint, translating OpenChamber’s schema into Goose-compatible API calls.+---------------------------+
|    Zustand State Layer    |
| (useSessionStore, etc.)   |
+-------------+-------------+
              |
              | @opencode-ai/sdk Calls
              v
+-------------+-------------+      Translates calls      +---------------------------+
|   Goose Engine Adapter    | =========================> |  goosed ACP API Runtime   |
| (Acts as SDK Mock Client) |                            |      (Port 4096)          |
+---------------------------+                            +---------------------------+
The following table details the mapping of OpenChamber interface components to Goose's API endpoints, highlighting gaps and mitigation strategies.OpenChamber Store Action / SSE EventGoose ACP API Endpoint EquivalentTranslation Mechanism / MitigationGap Severity & Resolution ClassClaim Confidenceclient.session.create()[cite: 9]POST /v1/sessions[cite: 18]Direct parameter forwarding. Sets working_dir to the active directory.None (Fully mapped)Verified in Sourceclient.session.prompt()[cite: 9]POST /v1/sessions/:id/messages[cite: 18]Wraps user text inputs as standard message body parts.None (Fully mapped)Verified in SourceEvent: message.part.delta[cite: 5]Chunk stream from POST /v1/sessions/:id/messagesParses the chunked transfer encoding stream and standardizes token strings.None (Fully mapped)Verified in SourceEvent: permission.asked[cite: 5]POST /v1/sessions/:id/confirmationsWhen Goose pauses for tool validation, the adapter emits an mock permission.asked block to the UI.Medium Gap: Shimmed in the adapter layer.Inferred from Sourceclient.permission.reply()[cite: 10]PUT /v1/sessions/:id/confirmations/:cidTranslates user button presses into an ACP confirmation response.None (Fully mapped)Inferred from Sourceclient.git.status()[cite: 5]None (Goose has no git client API)Shim Layer: The adapter runs local CLI git queries on behalf of the UI.Low Gap: Client-side execution fallback.Verified in SourceDirectory SelectionConfigured using working_dirMapped dynamically via Goose workspace parameters.None (Fully mapped)Verified in SourceSession branch display [cite: Addendum]None (Goose is branch-agnostic)Shim Layer: The adapter queries the branch on the local project directory and updates the UI.Low Gap: Resolved via client-side git queries.Verified in SourceDisplay Aliases ("Big Pickle") [cite: Addendum]None (Configured inside local secrets)Merged into the UI configuration layer (useConfigStore).Low Gap: Kept inside client localStorage.Verified in SourceSelf-updaterNoneDisabled: Replaced with clean UI override panel.Low Gap: Static override.Verified in SourceAdapter Architecture and Injection SitesThe custom adapter implements an SDK-shaped client mimicking @opencode-ai/sdk's API surface. To instantiate this dynamically without changing the downstream layout logic, the instantiation helper at packages/ui/src/sync/client.ts is updated to inject an interface dispatcher:TypeScript// Dual-Engine API Dispatcher (packages/ui/src/sync/client.ts)
import { OpenCodeClient } from '@opencode-ai/sdk';
import { GooseAdapterClient } from '../epistemos/adapters/GooseAdapterClient';
export class DynamicEngineClient {
  private opencode: OpenCodeClient;
  private goose: GooseAdapterClient;
  constructor() {
    this.opencode = new OpenCodeClient({ baseUrl: 'http://localhost:3000' });
    this.goose = new GooseAdapterClient({ baseUrl: 'http://localhost:4096' });
  }
  // Routes calls based on the active session's engine configuration
  public resolve(sessionID?: string) {
    const session = useSessionStore.getState().sessions[sessionID];
    const engineType = session?.engineType ?? useConfigStore.getState().defaultEngine;
    return engineType === 'goose' ? this.goose : this.opencode;
  }
}
5. Engine/Agent TopologyTo provide a robust suite of tools—including Claude, Codex, OpenCode, Hugging Face models, and specialized command-line interfaces—without cluttering the frontend with custom APIs, the architecture organizes its runtimes into a clean, hierarchical topology.                        +----------------------------+
                        |   Epistemos Agent Surface  |
                        +--------------+-------------+
                                       |
                   Dual-Engine Seam (Composer Chip Select)
                                       |
               +-----------------------+-----------------------+
               |                                               |
               v                                               v
     +-------------------+                           +-------------------+
     |  OpenCode Server  |                           |   Goose Engine    |
     +---------+---------+                           +---------+---------+
               |                                               |
        Model Providers                                  MCP Extensions
               |                                               |
     +---------+---------+                           +---------+---------+
     | - Claude Sonnet   |                           | - CLI Agent Tools |
     | - Codex (OpenAI)  |                           | - Hugging Face    |
     | - OpenCode Models |                           | - MCP Servers     |
     +-------------------+                           +-------------------+
Allocation of ServicesThe underlying models and agents are allocated across the two core engine layers based on their connection protocols:OpenCode Server Layer: Serves as the primary provider for API-driven model generation, managing endpoints for Claude, Codex, and native OpenCode configurations.Goose Engine Layer: Acts as the execution layer for task-driven agents, command-line helpers, and local systems requiring tool execution via Model Context Protocol (MCP) integrations.Integration of CLI-Based AgentsCommand-line tools (such as Claude Code or Codex CLI engines) are integrated directly into the system using the following guidelines:Rule: CLI-driven agents should not be implemented as direct engines alongside OpenCode or Goose inside the client UI.Reasoning: Direct integration bypasses the state synchronization and tool-approval loops, forcing the application to build and maintain custom terminal scrapers and permission hooks.Path Forward: CLI workflows are routed through the OpenCode or Goose engines using dedicated shell executors. This lets the backend coordinate shell processes through standard execution pipelines. This architecture keeps the adapter surface small, limits UI state conflicts, and ensures that interactive terminal steps reuse the existing approval mechanisms.6. 1Code StudyCatalog of Unique 1Code CapabilitiesThe Apache-2.0 reference implementation 1Code features advanced visual paradigms and multi-agent patterns designed for complex codebases:Streaming "Cooking" States: Provides rich animations during execution, displaying active system indicators and processing steps in the chat timeline rather than a simple text loader.Visual Diff Previews: Integrates visual inline side-by-side diff screens to review file edits before confirming writes.Worktree Isolation: Automatically creates isolated Git worktrees for parallel agent executions to prevent file modification conflicts on active branches.Parallel Sub-agent Pools: Leverages background sub-agents to process parallel tasks without blocking the main conversational interface.Portability and Feasibility AnalysisThe table below classifies these 1Code features, identifying whether they can be ported to the OpenChamber codebase and their implementation priority.Capability NameEngine Bound vs. UI PortableOpenChamber Native EquivalentsPorting Feasibility & Technical PathValue-to-Effort RankClaim ConfidenceStreaming "Cooking" Animations[cite: 20]UI PortableBasic text loaders and simple processing indicators.Highly feasible. Implemented by styling processing states with Tailwind components in packages/ui/src/components/chat/.High (High UX impact, Low effort)Verified in SourceVisual Diff Preview Pane[cite: 20]UI PortableStandard Monaco Editor and unified diff block views.Highly feasible. Integrates Monaco’s native side-by-side comparative editor component.High (Critical safety feature, Medium effort)Verified in SourceWorktree Isolation Model[cite: 20]Engine BoundProject workspaces mapped directly to manual directories.Hard. Requires building custom Git worktree lifecycles in the underlying server runtimes.Low (Extremely high backend complexity)Inferred from SourceParallel Background Orchestration[cite: 20]Engine BoundMulti-agent setups driven by terminal prompts.Medium. Relies on OpenCode’s sub-agent infrastructure to process background runs.Medium (High complexity, relies on engine capability)Inferred from Source7. Upstream Auto-UpdatesGit Vendoring StrategyTo maintain the ability to pull downstream changes from the upstream OpenChamber project with minimal friction, Epistemos tracks the repository using a dedicated fork with structured remote mappings:Upstream Repo (openchamber/openchamber) 
       └── Forked Repo (epistemos/openchamber)
                 └── Monorepo Subdirectory integration (Submodule vs. Subtree)
The system uses a Git Submodule to mount the forked repository under extern/openchamber/ in the main Swift project. Submodules clearly isolate external codebases, keeping the parent project's git history clean and preventing build issues caused by mixed files.Overlay DisciplineTo avoid merge conflicts when pulling upstream changes, the architecture enforces a strict isolation discipline:Zero In-Place Edits: Core OpenChamber source files must not be modified directly.File Separation: All local enhancements—including adapter classes, custom visual themes, and unique React components—are saved as new files in separate directories:packages/ui/src/epistemos/themes/june.json
packages/ui/src/epistemos/components/JuneMessageBar.tsx
packages/ui/src/epistemos/adapters/GooseAdapterClient.ts
Patch Ledger Maintenance: Necessary changes to core files (such as initializing the custom client wrapper or modifying entry configurations) are recorded in a local patch file (patches/openchamber-core.patch). These edits are applied automatically using build scripts:Bash# Automated Patch Integration Script (run-patch.sh)
cd extern/openchamber
git apply ../../patches/openchamber-core.patch
Upstream Integration WorkflowThe process for integrating upstream updates is designed to be programmatic and repeatable:Step 1: Fetch Upstream Updates ---> Step 2: Merge Fork Core ---> Step 3: Auto-Apply Patches ---> Step 4: Validate and Compile Build
This workflow is formalized in the following execution sequence:StepAction NameExecution CommandVerification MetricClaim Confidence1Fetch Upstreamgit fetch upstream && git checkout dev && git merge upstream/dev[cite: 22]Successful retrieval with zero conflicts on the upstream remote tracking branch.Verified in Source2Reset Workspacegit reset --hard HEADReturns the local directory to a clean state.Verified in Source3Apply Local Patchesgit apply ../../patches/openchamber-core.patch[cite: 3, 21]Exit code 0 from the patch utility without block failures.Verified in Source4Type Check and Compilebun run build:ui && bun run type-check:ui[cite: 4]Code compiles successfully with zero TypeScript compilation errors.Verified in Source5Visual Smoke TestLoad SPA bundle in target WKWebView instanceWebview loads correctly and displays the native page console log without errors.Verified in Source8. Navigation RestructureEvaluating the Unified macOS Interface WorkspaceOpenChamber is architected as a workspace rather than a multi-page app, using unified layouts designed to keep users focused on their active project context.The application uses global views to organize complex workspaces:+-------------------------------------------------------------+
|                     Native macOS Pill                       |
|          [Home] [Agent] [Notes] [History] [Settings]         |
+-------------------------------------------------------------+
|  Active View Surface                                        |
|                                                             |
|  [Agent View Selected]                                      |
|  +--------------+---------------------------+------------+  |
|  | Files Tree   | Chat Workspace Pane       | Context    |  |
|  |              |                           | (Notes)    |  |
|  |              |                           |            |  |
|  +--------------+---------------------------+------------+  |
+-------------------------------------------------------------+
Clean Integration StrategyTo integrate OpenChamber with the native macOS toolbar pill, the system implements the following routing rules:Keep Core Settings and History Inside the Workspace: Settings and Session History rely heavily on shared state in useConfigStore and useSessionStore. Moving them out of the React workspace to handle them as native views introduces complex state synchronization challenges across the bridge.Mount "Notes" to OpenChamber's Sidebar Panels: The user's "Notes" view is routed directly to OpenChamber's Context Panel (which manages notes, todos, and plans in a split sidebar).Use the Native Pill for High-Level App Modes: The native macOS toolbar coordinates high-level application views, switching the main container between Home, Agent, and general Settings. Inside the "Agent" container, OpenChamber manages its own sub-panels and workspace views without native intervention.9. June Landing SignatureDesign Foundation: Apple's GlassmorphismThe design language is built on Apple's translucency principles, utilizing translucent materials that adapt to light and dark environments. The landing interface uses high-contrast borders and deep, subtle drop shadows to create a clear visual hierarchy over background elements.Token-Derived Gradient Blending FormulaThe page gradient is calculated dynamically using a theme's base design tokens. To preserve contrast and readability across both light and dark backgrounds, the blending formula uses a vertical exponential decay function to interpolate colors:$$C_{\text{grad}}(y) = \text{lerp}(C_{\text{bg}}, C_{\text{accent}}, \alpha(y))$$Where $\alpha(y)$ represents the gradient influence at vertical coordinate $y$:$$\alpha(y) = \beta \times e^{-k \cdot y}$$$C_{\text{bg}}$ is the theme's background color token.$C_{\text{accent}}$ is the accent color token.$\beta = 0.08$ represents the maximum tint density, ensuring high contrast.$k$ is a vertical decay rate constant that controls the gradient's softness.This color blending is implemented using standard CSS custom variables:CSS/* June Theme Custom Gradient Utility */
.june-landing-container {
  --june-bg: var(--theme-background-base); /* */
  --june-accent: var(--theme-accent-primary);
  
  /* Translates to a subtle tan wash on light themes (background: #FFFFFF, accent: #D2B48C) */
  background: linear-gradient(
    180deg,
    color-mix(in srgb, var(--june-accent) 8%, var(--june-bg)) 0%,
    var(--june-bg) 60%
  );
}
CSS Hook InjectionTo apply these theme styles across the application automatically, the variables are hooked into the Tailwind styles pipeline inside the design system layer (packages/ui/src/styles/design-system.css):CSS@layer components {
  .landing-gradient-adaptive {
    background: linear-gradient(
      180deg,
      color-mix(in srgb, var(--color-accent) 8%, var(--color-background)) 0%,
      var(--color-background) 100%
    );
    transition: background 0.3s ease-in-out;
  }
}
10. Risks, Order, and Ledger SeedTop 10 Architectural Risks and MitigationsUpstream SDK Version DriftRisk: OpenCode releases major changes to @opencode-ai/sdk that break the engine adapter’s interface contracts.Mitigation: Pin dependencies to a tested release (e.g., @opencode-ai/sdk: 1.15.13) inside package.json. Evaluate upstream changes manually before upgrading.Zustand Render Loop BottlenecksRisk: High-frequency events (like word-by-word text streaming) in the unified store cause the entire UI layer to re-render, creating lag.Mitigation: Group state into separate stores by change frequency. Use narrow selectors to restrict store subscriptions to individual leaves instead of parent elements.WKWebView Local Origin CORS RestrictionsRisk: WebKit security policies block API calls from local app files (epistemos://) to local loopback ports (http://localhost:3000).Mitigation: Configure the native Swift webview to disable origin locks on local assets, and configure local servers to return wildcard CORS response headers.WKWebView Loopback Connection LimitsRisk: WebKit enforces connection limits on local HTTP loops, causing the SSE event stream to freeze or drop messages.Mitigation: Serve API endpoints, WebSockets, and static assets from a unified local server using HTTP/2 cleartext (H2C) connections.Goose Session Structure MismatchRisk: Goose uses directory-based workspaces without native Git branch tracking, creating visual grouping conflicts in the session list.Mitigation: The adapter queries the directory's active branch using local git commands, dynamically mapping the session with git metadata before sending it to the UI.Sentinels Overwritten During Provider ReloadsRisk: When config options reload, custom state configurations (like adding a provider) are silently overwritten.Mitigation: Add explicit validation guards in the adapter's configuration reload actions to preserve unsaved sentinel inputs.Uncontrolled Zombie Server ProcessesRisk: Background engines (like opencode or goosed) fail to quit when the parent app crashes, locking ports on the next launch.Mitigation: Implement startup validation checks in Swift to scan for and terminate active zombie PIDs before starting new server instances.Veneer Custom Theme GlitchesRisk: Custom UI modifications break the default styling of legacy components in the underlying design system.Mitigation: Wrap local styles inside an isolated CSS layer to prevent style leaks into downstream OpenChamber elements.Data Serialization FailuresRisk: Goose writes specialized data formats (such as compacted messages) that fail to deserialize in standard CLI exporters.Mitigation: Build explicit schemas and fallback types into the adapter’s serialization and parser pipelines.Touch Event Latency in WKWebViewRisk: WebKit introduces tap and scroll delays inside embedded view containers on older macOS versions.Mitigation: Implement GPU hardware acceleration for rendering text elements and enable off-thread styling processing.Refined Phase Order for the BuildPhase 1: Environment & Tooling (WKWebView Setup)
Phase 2: OpenCode Core Engine Setup (Supervised Run)
Phase 3: Dual-Engine UI Adapter Layer
Phase 4: June UI Themes & Landing Page Signature
Phase 5: Performance Optimization & Testing
Phase 1: Environment & Tooling: Configure the macOS Swift WKWebView to host the compiled static PWA bundle, ensuring correct local CORS permissions and directory storage settings.Phase 2: OpenCode Core Engine Setup: Implement the native process supervisor in Swift to launch and manage the local OpenCode server.Phase 3: Dual-Engine UI Adapter Layer: Build the client-side Goose adapter to map ACP requests to the UI, and configure the dual-engine selection chip in the composer view.Phase 4: June UI Themes & Landing Page Signature: Integrate the June-warm theme, apply the dynamic vertical gradient formula, and style the workspace with clean border treatments.Phase 5: Performance Optimization & Testing: Run end-to-end regression tests to verify that data flows correctly and that layout rendering meets performance budgets.11. Feature Ledger SeedThe following checklist catalogs the unified agent workspace’s features, mapping their origin, providing engine, and architectural placement to ensure zero feature loss during the transition.Feature IdentifierSource OriginTarget Implementation File Path (packages/ui/)Providing EngineRisk of Feature Loss / Architectural MitigationClaim ConfidenceInteractive File Tree Explorer[cite: 1, 3]OpenChambersrc/components/views/FilesView.tsx[cite: 30]OpenCode (via filesystem REST queries)Low. Requires path translations in the adapter layer when running on Windows directory structures.Verified in SourceInteractive Bash Terminal[cite: 1, 3]OpenChambersrc/components/terminal/TerminalContainer.tsxOpenCode / Goose (via WebSockets)Low. Terminal outputs must be properly throttled to prevent main-thread UI lag.Verified in SourceInline Message Diff Review[cite: 1, 3]OpenChambersrc/components/chat/message/parts/DiffPart.tsxOpenCode (Diff utilities)Low. The editor must handle long file merges without locking the interface.Verified in SourceBranch-Aware Session Sidebar [cite: Addendum]OpenChambersrc/components/session/sidebar/Sidebar.tsxOpenCode (Direct Git API) / Goose (Adapter Git shim)Medium. The adapter must map Goose's workspace paths to local Git branches.Verified in SourceModel Display Name Aliases [cite: Addendum]OpenChambersrc/stores/useConfigStore.ts[cite: 8]Static ConfigurationLow. Display aliases are saved in client localStorage to persist across updates.Verified in SourceInteractive Tool Authorization Cards[cite: 19]OpenChambersrc/components/chat/PromptPermissionCard.tsxOpenCode (Asked events) / Goose (Confirmations)Low. The adapter maps tool requests to standard approval events.Verified in SourceToken Usage and Cost Display[cite: 1, 3]OpenChambersrc/components/chat/header/TokenMeter.tsxOpenCode (Metrics) / Goose (Metadata)Low. Merged inside the header to prevent separate rendering overhead.Verified in SourceVoice Input Mode[cite: 3]OpenChambersrc/components/chat/input/VoiceControl.tsxOpenCode Voice APIsLow. Reuses the standard input bar interface.Verified in Source"June-Warm" Dynamic Color Themes [cite: Addendum]Epistemossrc/epistemos/themes/june-warm.jsonCustom Client-Side ThemeLow. The theme is registered globally using standard CSS variable mappings.Verified in SourceTypewriter Landing Landing Page [cite: Addendum]Epistemossrc/components/views/LandingPage.tsxCustom UILow. Replaces the core greeting text element with a styled custom component.Verified in SourceAdaptive vertical page gradient [cite: Addendum]Epistemossrc/styles/design-system.css[cite: 12]Custom Client-Side ThemeLow. Integrated using the custom vertical gradient formula.Verified in SourceUnified Settings Interface [cite: Addendum]OpenChambersrc/components/sections/SettingsOverlay.tsxOpenCode / Goose ConfigurationsMedium. Separate setting segments are displayed based on the active engine.Verified in SourceDynamic Engine Selector Chip [cite: Addendum]Epistemossrc/components/chat/input/EngineSelector.tsxCustom UIMedium. Ensures the selector is only interactable when starting a new session.Verified in Source12. Open Questions for the OwnerTo finalize the system design, the following architectural details require owner verification:Session Directory Sharing Constraints:Context: When switching between engines mid-workspace, should OpenCode and Goose share the exact same physical project directory, or should the workspace roots remain strictly separated to prevent build asset conflicts?Handling of Legacy Credentials:Context: Should the app import legacy Goose secrets (~/.config/goose/secrets.yaml) automatically on launch, or should it use a unified, clean credential manager?Local vs. Hosted CLI Tool Running:Context: For specialized CLI actions (like running Claude Code or Codex), should the system require local environment configurations, or should it run them inside isolated sandboxes to protect the developer's local environment?UI Action Items for Non-Active Engines:Context: When an engine lacks a specific tool (for example, Goose lacking Git branch management APIs), should the tool's interface elements be hidden completely, or displayed in a disabled state to maintain layout consistency?



GPT 2 - # Execution dossier for rebuilding Epistemos Agent on OpenChamber

## Executive call

The architecture you described is viable, and the strongest low-regret path is to keep **OpenChamber as the only UI donor**, treat **OpenCode as engine one through its native SDK/server contract**, and put **Goose behind an `@opencode-ai/sdk`-shaped adapter seam** so the OpenChamber stores can stay as unchanged as possible. That recommendation is grounded in three source-backed facts: OpenChamber already positions `packages/ui` as a shared source-level library consumed by web, desktop, and VS Code hosts; it already speaks to OpenCode through a single UI client wrapper plus a sync/event pipeline; and its web runtime proves the UI can ship as a browser-hosted bundle rather than as an Electron-only surface. citeturn15search1turn15search2turn33search4

The part that should *not* be forced is any attempt to make Goose “pretend” to have OpenCode-only capabilities. OpenChamber’s own architecture patterns explicitly prefer authoritative live state over heuristics and warn against encoding policy in UI when the underlying system does not support it. That aligns with your hard rule: show real capabilities, hide absent ones, never fake them. citeturn15search2

The most important strategic correction is about **where the seam lives**. The seam is not at the page level. It is at the **SDK client + event stream + capability exposure layer**. The WKWebView should always host one OpenChamber workspace. Engine choice should be per conversation, and the merged session list should be a higher-order overlay above engine-specific session sources. OpenChamber’s sidebar is already project/worktree centric rather than page-centric, which makes it a good structural base for your “Agent” destination as long as you do not over-pull internal OpenChamber views like Settings and History out into separate native destinations too early. citeturn18view0turn26search2turn24search2

## OpenChamber as the UI base

**Question 1: OpenChamber map.** OpenChamber’s monorepo is cleanly split into `packages/ui` for shared React UI and state, `packages/web` for the web server plus Vite-hosted frontend and CLI, `packages/electron` for the desktop shell, and `packages/vscode` for the extension host and webview. The maintainers explicitly describe `packages/ui` as a “source-level library” used by all three hosts, and AGENTS.md identifies the main runtime entry points: `packages/web/src/main.tsx`, `packages/web/server/index.js`, `packages/electron/main.mjs`, and `packages/vscode/webview/main.tsx`. That is exactly the topology you want for vendoring `packages/ui` behavior into a WKWebView host. citeturn15search1turn15search2turn11search3

**Question 1: host mounting and routing.** The web package uses Vite with aliases that map `@openchamber/ui` to `../ui/src` and `@` to the same UI source tree, which means hosts are already mounting the UI package as source, not as a hard-bundled Electron-only artifact. The web build also defines multiple HTML entry points — `index.html`, `mobile.html`, and `mini-chat.html` — which shows the UI can be mounted into different shells without architectural surgery. citeturn36view0turn34view0

**Question 1 and addendum: session hierarchy.** OpenChamber’s sidebar is explicitly documented as a **single multi-project tree** with a `recent` top section, then projects, then worktrees and archived groups, then sessions. Project headers own root sessions directly. Archived groups are collapsed by default. Session rows have inline metadata and menu actions. The same doc also says VS Code now uses the same grouped project tree instead of a flat list, which reinforces that this hierarchy is part of OpenChamber’s core view model rather than a host-specific quirk. citeturn18view0

**Question 1 and addendum: project/workspace creation and selection.** `useProjectsStore.ts` verifies that projects are first-class entries with `id`, `path`, `label`, color, and timestamps. It supports `addProject`, `removeProject`, `setActiveProject`, `renameProject`, metadata updates, and icon upload. Crucially, when the active project changes, the store calls `opencodeClient.setDirectory(target.path)` and updates `useDirectoryStore`, which means “workspace selection” is operationally “project path becomes active directory.” citeturn23view1

**Question 1 and addendum: branch awareness.** The strongest verified finding is that OpenChamber’s branch awareness is implemented through **worktree metadata attached to sessions**, not through a separate abstract “branch object” store that I could verify in this pass. `session-ui-store.ts` tracks `worktreeMetadata`, `availableWorktrees`, and `availableWorktreesByProject`; when session worktree metadata is attached, it carries `branch`, `headState`, `worktreeRoot`, `cwd`, and `worktreeStatus`. Sessions are grouped to projects through directory and worktree resolution, and recent releases repeatedly mention worktree reliability, branch/worktree safety, and worktree-session sidebar behavior. The practical conclusion is that OpenChamber’s “branch node” behavior is functionally worktree-centric: sessions bind to project directory plus worktree branch metadata when OpenCode provides it. citeturn29view1turn28view1turn31view2turn26search2turn32search0

**Question 1 and addendum: pagination and show-more behavior.** `packages/ui/src/stores/globalSessions.ts` is one of the most important adapter-contract files. It implements paged session loading by repeatedly calling `apiClient.experimental.session.list(...)` with `limit`, `archived`, optional `directory`, optional `roots`, and an optional numeric `cursor`. Pagination stops on a short page, and the next cursor is taken first from the `x-next-cursor` response header, falling back to the last session’s `time.updated`. The store page size is 500. That means any Goose adapter that wants parity with “show more sessions” needs either real cursor support or a compatible emulation layer. citeturn22view0turn19view3

**Question 1: inspected store and sync files that matter most to the adapter seam.** I could not fully enumerate *every* store file in `packages/ui/src/stores/*` under the token/tools budget, so the table below is the **verified high-value contract inventory** rather than a claim of total exhaustiveness.

| Store or sync file | Verified responsibilities | Verified SDK/runtime calls | Verified event/subscription behavior | Why it matters for the Goose adapter | Confidence |
|---|---|---|---|---|---|
| `packages/ui/src/stores/globalSessions.ts` | Global session pagination and dedupe | `apiClient.experimental.session.list({ directory?, archived, roots?, limit, cursor? })`; reads `x-next-cursor` header | None verified in-file | This is the clearest, lowest-level session-list contract to mimic | Verified in source citeturn22view0 |
| `packages/ui/src/stores/useGlobalSessionsStore.ts` | Active + archived global session snapshots; directory-grouped refresh | Uses `opencodeClient.getSdkClient()` and `listGlobalSessionPages(...)` | None verified in-file | This is your merged-session ingest point for OpenCode-side sessions | Verified in source citeturn20view0turn20view3 |
| `packages/ui/src/stores/useProjectsStore.ts` | Project registry and active-project selection | Uses `opencodeClient.setDirectory(...)`; runtime fetch for project icon PUT | None verified in-file | Any engine abstraction must preserve directory/project activation semantics | Verified in source citeturn23view1 |
| `packages/ui/src/sync/session-ui-store.ts` | Current session, draft session targeting, worktree metadata, send-message orchestration | Uses `opencodeClient.getDirectory()`; activates config for project directory; `sendMessage` lives here | Sync/event behavior exists, but detailed event hookups were not fully inspected in this pass | This is likely the highest-friction store to keep unchanged; plan to inject engine-specific client behavior here indirectly, not by forking the store | Verified in source for state shape; inferred for full send path citeturn28view1turn30view0 |
| `packages/ui/src/stores/useConfigStore.ts` | Provider/model/agent defaults and config sync | Imports `@opencode-ai/sdk/v2`; imports `opencodeClient`; calls runtime settings load; uses config sync helpers | Imports `subscribeToConfigChanges` from `@/lib/configSync` | This is the place where per-engine model/provider aliases and default chips will collide first | Verified for imports; deeper method inventory incomplete citeturn10view0 |
| `packages/ui/src/lib/opencode/client.ts` | Single UI client wrapper around SDK | OpenChamber AGENTS.md identifies this as the UI client wrapper | Event pipeline handled elsewhere | This is the primary injection point: replace singleton construction with an engine-aware client factory | Verified by architecture docs; file body not fully inspected here citeturn15search2 |
| `packages/ui/src/sync/event-pipeline.ts` | OpenCode SSE/WS handling | AGENTS.md says this is where SSE/WS event handling lives | Yes, event pipeline | Goose compatibility will either require matching event shapes here or a translation layer before events hit this pipeline | Verified by architecture docs; event names not fully inspected here citeturn15search2 |

**Question 1: right-panel requirements.** OpenChamber’s AGENTS.md separates official OpenCode traffic from OpenChamber-owned runtime capabilities. Files use OpenChamber runtime filesystem endpoints under `packages/web/server/lib/fs/routes.js`; terminal uses `ghostty-web` in the UI and a terminal runtime on the server; Git uses `packages/ui/src/lib/gitApi.ts` against server-side git services; the settings shell is its own shared UI; the context area now includes notes, todos, and plan access in release notes. The practical implication is that many “right panel” surfaces are **not** OpenCode SDK features and do not need Goose parity at the SDK layer — they need parity only where the current Goose desktop exposed those capabilities and you choose to preserve them in Epistemos. citeturn15search2turn24search2turn25search4turn26search2

**Question 8: navigation restructure.** Keep **Home / Agent / Notes / History / Settings** in the native toolbar pill, but let **Agent** host the whole OpenChamber workspace intact. Do **not** peel OpenChamber Settings out into a native destination in v1. OpenChamber has actively redesigned its settings shell multiple times and, in current releases, desktop settings can open in a windowed dialog with backdrop blur; that is a strong signal that Settings is an internal workspace/view concern, not a clean separable “app page.” History is more defensible as a native destination later, but the least-invasive v1 is: native Home; native Notes; everything OpenChamber-ish stays inside Agent. citeturn24search2turn26search2turn18view0

## Embedding and engine surfaces

**Question 2: WKWebView viability.** The strongest positive evidence is that `packages/ui` is explicitly host-agnostic and that `packages/web` exists as a standalone browser/PWA runtime. The web package README says OpenChamber works on desktop browsers, tablets, and phones as a PWA. Vite config aliases the shared UI source directly into the web host. That means the UI itself is browser-viable; the risk is not “can it run outside Electron,” but which browser-only/PWA behaviors you want disabled in an embedded WKWebView. citeturn15search1turn34view0turn36view0

**Question 2: Electron/Node-only paths and how the web host avoids them.** OpenChamber’s architecture doc makes the split explicit: Electron owns native shell concerns, while backend/domain logic lives in `packages/web/server/*` and shared UI in `packages/ui`. That is good news for Epistemos, because your existing Swift shell can replace Electron’s native responsibilities while the WKWebView mounts the browser-oriented OpenChamber UI. The main caveat is that right-panel features like terminal, raw filesystem access, notifications, updater flows, and some auth paths are served by **OpenChamber’s own web server/runtime routes**, not by pure browser JS alone. In practice, you either vendor the UI and keep an OpenChamber-like helper server beside it, or you selectively replace those runtime APIs with native/Swift shims. citeturn15search2turn33search4

**Question 2: PWA and service-worker behavior to disable when embedding.** `packages/web/vite.config.ts` uses `vite-plugin-pwa` with `injectManifest`, `registerType: 'autoUpdate'`, and a real service worker entry (`src/sw.ts`). The public folder contains a `site.webmanifest`, PWA icons, and update-related behavior has continued to churn in releases and issues. In a WKWebView embedding, I would disable service-worker registration entirely, strip install/update prompts, and remove the built-in update button because your vendored update path is upstream merge + app release, not in-app web/PWA updating. This is source-backed by the PWA config itself and by repeated update/PWA bugfix work in OpenChamber releases and issues. citeturn36view0turn36view1turn33search2turn33search3

**Question 2: localhost and auth specifics.** OpenChamber supports connecting to an external OpenCode server via `OPENCODE_HOST` or `OPENCODE_PORT` plus `OPENCODE_SKIP_START=true`; OpenCode itself supports HTTP basic auth on `opencode serve` via `OPENCODE_SERVER_PASSWORD` and `OPENCODE_SERVER_USERNAME`; Goose uses `X-Secret-Key` for `goosed`. For a WKWebView on macOS, the safest shape is a same-origin local helper server that reverse-proxies engine traffic rather than direct arbitrary-origin calls from a custom `file:` or app-specific origin. That avoids CORS and auth-header edge cases around localhost, SSE, and WebSocket usage, and it matches OpenChamber’s own assumption that hosts talk to local or remote servers over explicit runtime URLs. The reverse-proxy recommendation is an inference, but it is a conservative one grounded in the server/auth patterns exposed by OpenChamber, OpenCode, and Goose. citeturn15search2turn34view0turn39search2turn40search0

**Question 3: OpenCode as engine one.** OpenCode’s server docs verify that `opencode serve` is a headless HTTP server exposing OpenAPI at `/doc`, with `GET /global/health`, `GET /global/event` for global SSE, `GET /project`, and `GET /project/current` among the documented surfaces. The SDK docs say `createOpencode()` can start both server and client, and the server docs say the TUI itself is a client over the same server. OpenChamber already uses `@opencode-ai/sdk/v2` and an SSE/WS event pipeline. That makes OpenCode the natural engine one, and it is the only way to keep the “zero feature loss” goal realistic without re-implementing large parts of OpenChamber’s state assumptions. citeturn39search0turn39search2turn15search2

**Question 3: bundling and supervision on macOS.** OpenChamber’s own desktop README says desktop bundles a matching OpenCode CLI, while CLI/web and VS Code use the installed OpenCode CLI. OpenCode’s troubleshooting docs give stable storage and log locations, which is helpful for a supervised bundled-binary strategy in a native macOS app. The source-backed recommendation is therefore: bundle a pinned OpenCode binary inside Epistemos, supervise it like you already supervise `goosed`, keep engine version pinning explicit, and surface logs into your native diagnostics. Disk and memory footprint were not directly verified in this pass, so I am not asserting numeric footprint values. citeturn15search0turn39search8

**Question 3: providers, models, and agents.** OpenCode docs say it supports 75-plus providers through Models.dev, can use local models, and supports existing subscriptions like GitHub Copilot and ChatGPT Plus/Pro. OpenChamber release notes show frequent model/provider UX churn and settings for default model and agent. This reinforces a clean split: provider/model choice should flow primarily through OpenCode for engine one, while any Goose-specific provider affordances should be isolated behind Goose settings and capability disclosure. citeturn39search5turn39search6turn24search7turn24search2

**Question 4: Goose as engine two.** Verified Goose facts from docs are these: `goosed` exposes a server process configurable with host, port, TLS, and a required `X-Secret-Key` authentication header; Goose has headless/server deployment docs; it has recipes, scheduler commands, extension management, multiple execution modes (`auto`, `approve`, `chat`, `smart_approve`), session-context controls, and active work on ACP methods for recipes, session extensions, config, and new-session handling. What I could **not** verify in this pass is a complete, endpoint-by-endpoint REST map for `goosed` sessions/messages/parts/confirmations comparable to OpenCode’s documented server table. That is a real documentation gap for this dossier, not a hidden conclusion. citeturn40search0turn41search1turn41search8turn41search9turn41search5

**Question 4: adapter recommendation and construction sites.** Build an engine-injectable client that satisfies the subset of `@opencode-ai/sdk/v2` actually consumed by OpenChamber’s stores, then route OpenCode sessions to the native client and Goose sessions to the adapter. The construction sites most likely to need injection are the `opencodeClient` singleton wrapper and every place that directly consumes `opencodeClient.getSdkClient()`, `setDirectory()`, or `getDirectory()`: `useGlobalSessionsStore`, `useProjectsStore`, `useConfigStore`, and `session-ui-store` are all verified users. citeturn20view0turn20view3turn23view1turn10view0turn30view0turn15search2

**Minimum mapping table for the seam**

| OpenChamber/OpenCode contract row | Goose equivalent | Gap treatment | Confidence |
|---|---|---|---|
| Session list with archived flag, directory filter, and cursor pagination | Goose sessions exist, but OpenCode-compatible pagination contract was not verified here | Shim if possible; otherwise custom pager in merged session layer | Inferred / partially uncertain citeturn22view0turn41search1turn41search9 |
| Per-session send/stream lifecycle | Goose server/API exists; interactive server transport details not fully verified in this pass | Adapter must translate Goose stream/events into OpenChamber event-pipeline expectations | Inferred / uncertain citeturn15search2turn41search1 |
| Permission/approval flow | Goose has execution modes `auto`, `approve`, `chat`, `smart_approve` | Show Goose-real approval UI only if surfaced by adapter; otherwise hide approval affordances | Verified for modes; uncertain for exact event contract citeturn41search2 |
| Project + branch/worktree grouping | Goose has working directory and project concepts; no native OpenChamber-style branch-bound session tree was verified | Group Goose by directory/project; optionally enrich with current git HEAD branch read from working dir | Verified that Goose lacks documented native branch-tree parity in this pass; enrichment is inferred citeturn29view1turn41search1 |
| Recipes | Goose explicitly supports recipes, including REST API and ACP references in docs | Surface as Goose-only capability | Verified citeturn41search0turn41search8 |
| Scheduler/routines | Goose supports scheduling recipes and scheduler commands | Surface as Goose-only capability | Verified citeturn41search9turn41search5 |
| Extensions / MCP controls | Goose documentation emphasizes extension ecosystem and server configuration | Surface as Goose-only capability, with UI gated by engine badge | Verified citeturn41search1turn40search0 |
| Model/provider aliases | OpenCode allows broad provider/model support; Goose supports many providers too | Keep aliases per engine, not global | Verified in principle; alias persistence details are inferred citeturn39search5turn39search6turn10view0 |

## Theme, June, and future enhancement donors

**Question 9: June landing signature.** I did not verify a public source repository for June in this pass, so June-specific implementation details below are treated as a design specification from your brief rather than as sourced facts.

What *is* source-backed is where the hook belongs in OpenChamber. OpenChamber’s theme system validates themes through JSON, derives CSS variables from tokens in `cssGenerator.ts`, and applies them by writing CSS variables onto `:root` and light/dark root selectors. The theme format already has structured `surface`, `primary`, `interactive`, `chat`, `tools`, and font/radius/transition tokens. The least-invasive June pass is therefore **not** a hard fork of design-system CSS; it is an extension of `cssGenerator.ts` so every theme emits two or three extra landing variables such as `--landing-gradient-start`, `--landing-gradient-end`, and `--landing-composer-bg`, plus any bar-specific shadow/border variables. That automatically keeps user custom themes compatible. citeturn12view0turn17view1turn17view2turn17view4

A practical formula for the gradient is:

- `landingStart = colorMix(surface.background, white, classicLight ? 92% : 88%)`
- `landingEnd = colorMix(surface.background, primary.base, classicLight ? 88/12 : 76/24)`
- `landingNoiseOrWash = low-alpha overlay derived from primary.muted or interactive.hover`

In a classic light theme, that yields the “white with a slight tan wash” you want. In saturated or dark themes, it still reads as “this theme, but lifted for a landing surface” rather than as a one-off hardcoded beige. Because OpenChamber already generates theme variables centrally, the right implementation point is the theme generator, not scattered component CSS. The exact color math is my recommendation; the hook location is verified. citeturn17view1turn17view2turn12view0

**Question 6: 1Code study.** 1Code is compelling as a *study donor* precisely because its strongest differentiators are not OpenChamber’s strengths: multi-agent worktree orchestration, diff-first “Cursor-like” coding UI, background agents in cloud sandboxes, live browser previews, queueing, chat forking, voice input, plan mode, and visualized extended thinking. The repository’s CLAUDE.md also confirms a renderer architecture with a focused agents surface, sub-chat store, diff view, commands, and a main-process database model for projects/chats/sub-chats. citeturn42search0turn42search1

The clean ranking is:

| 1Code trait | Likely rebuildability from OpenChamber primitives | Engine dependence | Value-to-effort rank |
|---|---|---|---|
| “Cooking” / thinking-state animations and polished chat-surface details | Mostly UI-only | Low | Very high |
| Diff-first review affordances | Mostly UI + existing OpenChamber diff/gitreview surfaces | Medium | High |
| Message queue UX | UI + store logic | Medium | High |
| Chat forking / sub-chat visuals | Existing conceptual overlap in both OpenChamber and 1Code | Medium | High |
| Parallel-agent/worktree orchestration | Heavy engine/state coupling | High | Medium |
| Background execution in cloud sandboxes | Engine/backend dependent and product-shaping | Very high | Low for v1 |
| Live browser previews | Backend/runtime dependent | High | Medium |

That means your instinct is right: **use 1Code as a reference donor for interaction quality, not as a second component donor inside the Agent surface.** The one-donor rule should stand. citeturn42search0turn42search1

**Question 5: engine topology.** The topology that minimizes adapter surface is:

- **OpenCode providers:** Claude-family, OpenAI/Codex-family, Hugging Face-compatible/open providers, and any standard models you want in a unified model picker. OpenCode is already built around broad provider support. citeturn39search5turn39search6
- **Goose providers / CLI passthrough:** Goose-native extensions, recipes, scheduler flows, and any ACP/CLI-native behaviors that are materially Goose-specific. Goose’s value is not just provider reach; it is its workflow/mode/extension ecosystem. citeturn41search1turn41search2turn41search9
- **Claude Code / Codex CLIs:** do **not** make them first-class direct engines in v1. Let them ride through OpenCode where possible, and only route them through Goose if you later verify a compelling Goose-native advantage. Making them direct engines would balloon the adapter surface toward 1Code’s orchestration shape, which is the exact complexity you are trying to avoid. This part is a recommendation, but it is grounded in the fact that 1Code is explicitly built around multi-agent CLI wrapping, while OpenChamber is already native to OpenCode. citeturn42search0turn15search2

## Upstream strategy, release risk, and build order

**Question 7: vendoring and auto-updates.** For OpenChamber, the best fit is **fork + upstream remote + a strict overlay discipline**, not a submodule. OpenChamber ships fast — GitHub shows 119 releases with a latest release on July 2, 2026 — and the changelog shows high churn in sessions, worktrees, settings, mobile/web, terminal, and update flows. A submodule would preserve purity but would make your native app release pipeline and patch reapplication more brittle. A fork with an explicit patch ledger is the most developer-realistic middle ground. citeturn11search1turn24search5turn24search2turn26search2turn33search3

The update discipline should be:

| Repo | Strategy | Local-change rule | Pinning policy |
|---|---|---|---|
| OpenChamber | Fork with upstream remote | New files for adapter/theme/native bridge first; unavoidable in-place edits logged in `PATCH_LEDGER.md` | Pin to tested tags, not `main`; rebase/merge monthly or per needed feature/security release |
| OpenCode | Treat as bundled external binary + SDK pin | No app-level fork unless forced; prefer pinned CLI/server binary and pinned SDK version together | Pin CLI/server and SDK as a matched pair |
| Goose | Much lighter tracking; avoid backend modification entirely | Adapter lives in Epistemos/OpenChamber fork, not Goose | Pin stable releases; only chase Goose when adapter-relevant APIs or desired features move |
| 1Code | No vendoring into shipped surface | Study-only snapshots or notes | Track informally |

This is grounded in OpenChamber’s release cadence, in OpenChamber’s own warning not to modify `../opencode`, and in your hard rule that Goose backend crates are never modified. citeturn11search1turn15search2turn41search8

**Question 10: top risks.**

| Risk | Why it is real | Mitigation |
|---|---|---|
| OpenChamber store coupling to OpenCode semantics | Stores already know about directories, worktrees, config activation, event pipeline, and experimental session list behavior | Keep the seam at `opencodeClient` + event translator; do not rewrite stores early |
| OpenCode SDK/server churn | OpenCode recently added v2 session endpoints; OpenChamber issues and releases track ongoing SDK/API churn | Pin SDK + server together; update only after smoke suite passes | 
| WKWebView service-worker weirdness | OpenChamber web host is a PWA with auto-update service worker | Disable SW/install/update in embedded build |
| Settings/history extraction breaking workspace assumptions | OpenChamber settings and sidebar are under active redesign | Keep them inside Agent in v1 |
| Goose API completeness mismatch | Goose server exists, but exact session/message parity with OpenCode was not fully documented in this pass | Start with a narrow Goose adapter that supports only the surfaced capabilities you can verify |
| Branch/worktree parity loss for Goose | OpenChamber’s hierarchy is worktree/branch aware; Goose is not verified to have equivalent native binding | Group Goose by project/directory, optionally enrich with current git HEAD branch label only |
| Merged session list becoming a UX lie | Two engines imply two backends and divergent capability sets | Normalize metadata centrally and always badge the engine |
| Theming collisions | OpenChamber theme generator is system-wide and custom themes are validated | Put June pass in generator, not scattered CSS overrides |
| Built-in updater confusion | OpenChamber has update/PWA flows and a desktop updater culture | Remove or replace in vendored Agent surface |
| Feature regression through donor drift | You are replacing a forked Goose UI with a different base | Use a feature ledger as a hard shipping gate |

All ten are directly supported either by current architecture docs, changelog evidence, or your locked constraints. citeturn15search2turn24search2turn26search2turn33search2turn36view0turn22view0turn41search8

**Refined build order**

First, vendor the latest OpenChamber tag and get `packages/ui` mounting cleanly inside the existing WKWebView with PWA/updater affordances disabled. Second, preserve OpenCode as-is and swap in your native toolbar pill, typewriter greeting headline, and all-chats sheet while keeping the OpenChamber workspace otherwise intact. Third, add the theme-generator June pass and landing composer transplant. Fourth, refactor `opencodeClient` into an injectable engine client while keeping OpenCode behavior golden. Fifth, merge session metadata and engine badges above the session source. Sixth, bring up the Goose adapter for sessions, send/stream, permissions, recipes, and scheduler in that order. Seventh, only then start harvest work from 1Code for visual polishing such as cooking states, queue UX, and diff-review niceties. This ordering is the safest way to satisfy your no-feature-loss rule. citeturn15search2turn18view0turn42search0

**Feature-ledger seed**

This is a **seed ledger**, not final closure. It lists the highest-confidence user-facing capabilities I could verify from the inspected sources plus your owner-locked signatures.

| Feature | Source | New app home | Providing engine(s) | Risk of loss |
|---|---|---|---|---|
| Project/workspace tree with recent + project + archived grouping | OpenChamber | Agent sidebar | OpenCode native, Goose adapted | Medium citeturn18view0 |
| Worktree-aware session grouping | OpenChamber | Agent sidebar | OpenCode native, Goose degraded | High citeturn29view1turn26search2 |
| Session pagination / show more | OpenChamber | Agent sidebar | OpenCode native, Goose shim | Medium citeturn22view0 |
| Session row menus and context menus | OpenChamber | Agent sidebar + all-chats sheet parity | Both via app overlay | Medium citeturn26search2turn18view0 |
| Files tree and file editor | OpenChamber | Agent right panel | Runtime server/native layer | Medium citeturn15search2turn25search7 |
| Git panel and changes/diff review | OpenChamber | Agent right panel | Runtime server/native layer | Medium citeturn15search2turn26search1 |
| Terminal tabs | OpenChamber | Agent right panel | Runtime server/native layer | Medium citeturn15search2turn24search2 |
| Notes / todos / plans panel | OpenChamber | Agent right panel | Shared UI + runtime data | Low to medium citeturn25search4turn32search0 |
| Permission / approval UI | OpenChamber + Goose modes | Agent chat surface | Both, engine-specific | High citeturn41search2turn15search2 |
| Recipes | Goose | Agent capability surface or settings/tools area | Goose only | Medium citeturn41search0 |
| Scheduler / recurring tasks | Goose | Agent capability surface or automation page later | Goose only | Medium citeturn41search9 |
| Extensions / MCP controls | Goose | Agent capability surface | Goose only | Medium citeturn41search1turn40search0 |
| Model/provider picker | OpenChamber + OpenCode | Composer chips | Both, engine-specific | Medium citeturn24search2turn39search6 |
| Engine chip per conversation | Owner spec | Composer chips | App overlay | Medium |
| Merged session list with engine badges | Owner spec | Agent sidebar + all-chats sheet | App overlay | High |
| Native macOS toolbar pill | Owner spec | Native Swift shell | Native | Low |
| Typewriter greeting landing | Owner spec | Agent landing | Native/web signature | Low |
| All-chats overlay with grouped hierarchy | Owner spec | Native/web signature | App overlay | Medium |
| June landing message bar | Owner spec + theme hook | Agent landing | Shared UI signature | Low |
| Theme-derived page gradient | Proposed on OpenChamber theme generator | Agent landing | Shared UI signature | Low |

## Open questions and a reusable research prompt

The biggest unresolved technical unknown is the **full Goose server API contract** for sessions, messages, tool confirmations, and streaming. The docs I verified prove server deployment, auth, recipes, scheduler, and ACP work are real, but I did not verify a full endpoint-by-endpoint session/message map comparable to OpenCode’s published server docs. That is the single biggest research gap still standing.

The other open design choice is whether you want Goose sessions to appear under **project only** or **project plus synthetic branch label**. Source-wise, OpenChamber’s natural grouping is project plus worktree metadata, and Goose does not give me verified native parity for that in this pass. If you care deeply about matching branch nodes visually, you should decide whether reading current git HEAD from the working directory is an acceptable degradation for Goose-backed sessions.

A third open question is how far you want to go with native replacement of OpenChamber-owned runtime APIs. For v1, a small local helper server that preserves OpenChamber’s own filesystem/git/terminal routes is less invasive than trying to replace those routes with Swift one by one.

**Open questions for the owner**

1. For Goose sessions, is grouping by **project/directory only** acceptable in v1, or do you want a synthetic branch label even if it is only a presentational read from git HEAD?
2. Do you want **Recipes** and **Scheduler** surfaced inside Agent v1, or can they ship behind an engine-specific “Goose tools”/settings surface while chat parity lands first?
3. Is **OpenChamber Settings** allowed to remain internal to Agent in v1, with the native toolbar pill only opening the Agent destination rather than deep-linking internal settings?
4. Do you want the **June landing bar** only on the landing/draft state, or also as the in-session composer shell?
5. Is the all-chats overlay allowed to be a **native shell around embedded web content**, or must it be fully native Swift?
6. Is the acceptable v1 contract for direct engines strictly **OpenCode + Goose**, with Claude Code/Codex only appearing as models/providers through them, rather than as standalone direct engines?

**Reusable deep-research prompt for an online model**

Study these repositories and docs as if producing an engineering handoff for a solo macOS app developer rebuilding a native app’s AI-agent surface:

- `openchamber/openchamber` plus docs and release notes
- `sst/opencode` plus `@opencode-ai/sdk` docs and `opencode.ai` docs
- `block/goose` plus `goosed`/ACP/docs/release notes
- `21st-dev/1code` as a study donor only

Mission: produce an execution dossier for rebuilding a Swift/macOS app section called `Agent` by vendoring **OpenChamber as the sole UI base donor** inside an existing `WKWebView`, with **OpenCode as engine one** and **Goose as engine two through an adapter**, with **zero feature loss**, **Goose backend crates never modified**, **no mixed-component donor UI inside the Agent surface**, and **upstream updates kept near-automatic**.

Required outputs:

- A file-level map of OpenChamber’s monorepo and especially `packages/ui`, `packages/web`, `packages/electron`, `packages/vscode`
- An exhaustive inventory of `packages/ui/src/stores/*` and related sync files, naming every store inspected, every `@opencode-ai/sdk` call, and every event subscription or stream consumer
- A precise map of OpenChamber’s workspace/session hierarchy, including project grouping, worktree/branch awareness, session actions, pagination, and where model aliases live
- A WKWebView viability analysis: browser-only proof, Electron-only code paths, service-worker/PWA behaviors to disable, localhost/CORS/auth/SSE/WebSocket constraints
- The exact OpenCode server surface the UI consumes, including endpoints, auth, streaming, and how to supervise `opencode serve` headlessly as a bundled macOS binary
- A Goose mapping table from the OpenChamber adapter contract to Goose equivalents, with every gap classified as **hide**, **shim**, or **open problem**
- An engine-topology recommendation for Claude, Codex, OpenCode, Hugging Face, and CLI agents, optimizing for one UI and least adapter surface
- A 1Code study of cooking/thinking animations, diff review UX, parallel/worktree orchestration, background execution, and chat-surface niceties, labeled UI-only versus engine-dependent
- An upstream update strategy for OpenChamber, OpenCode, and Goose: fork/subtree/submodule tradeoffs, patch ledger discipline, and version-pinning policy
- A recommendation for native navigation versus OpenChamber-internal navigation
- A theme plan showing exactly where a token-level “June-warm” pass and theme-derived landing gradient hook into OpenChamber
- A top-risk table, phased implementation order, and a feature ledger seed covering OpenChamber, Goose desktop parity, and owner signatures

Rules for the model:

- Prefer GitHub source files, docs sites, changelogs, issues, and PRs over summaries
- Cite every claim with file-level links where possible
- Mark each claim as **verified in source**, **inferred**, or **uncertain**
- If a repo is not fully inspectable, say so explicitly
- Do not recommend modifying Goose backend crates
- Do not mix UI components from OpenChamber and 1Code inside the Agent surface; 1Code can only be a study donor
- Treat June as landing-composer and gradient inspiration only unless public source is actually found
- Optimize for preserving every current capability through a feature ledger, not for elegance alone

gemini 2 - Architecture and Execution Dossier for Rebuilding the Epistemos macOS Agent Surface on OpenChamberThis engineering dossier outlines the structural specifications, integration patterns, and migration pathways required to rebuild the AI agent workspace of the macOS native application "Epistemos." This implementation replaces a highly customized local Goose web user interface (UI) with a robust hybrid architecture. The UI layer is built on the OpenChamber open-source desktop and web monorepo workspace. It is embedded in a Swift-native WKWebView container and communicates with dual-execution engines (OpenCode and Goose) through a unified client-side adapter seam.1. OpenChamber Monorepo Mapping & Workspace AnatomyThe OpenChamber repository is structured as a monorepo workspace managed via Bun. It isolates the user interface components from its various runtime hosts, ensuring consistent visual layouts across web, desktop, and IDE companion integrations.packages/
├── ui/                     # Shared React library: sync layer, API contracts, and stores
│   ├── src/
│   │   ├── components/     # Workspace panels, chat rows, and settings views
│   │   ├── hooks/          # Auto-follow mechanics, custom media, and environment hooks [cite: 5, 7]
│   │   ├── lib/            # Network wrappers, config parsers, and browser-safe APIs
│   │   ├── stores/         # Zustand application state containers
│   │   └── sync/           # SSE pipelines, caching, and optimistic mutations
├── web/                    # Express backend engine, Vite configurations, and CLI tools
├── electron/               # Electron main and preload wrappers for native shell bindings
└── vscode/                 # VS Code extension hosting and webview bootstrap logic
Hosting Architecture and UI Mounting[Verified-in-Source]
The UI is bundled as a single-page application (SPA) using Vite in packages/ui. The hosts load this SPA dynamically using specialized bootstrap patterns:Web/CLI Host (packages/web): Serves the React bundle statically over localhost using Express, forwarding API requests directly to the local server process.Electron Host (packages/electron): Spawns the Express web server in its primary process, using startWebUiServer to dynamically bind to a localhost port, and loads the built SPA from that local endpoint.VS Code Webview Host (packages/vscode): Mounts the compiled assets inside an isolated iframe, executing calls through a message bridge mapped in webview/main.tsx.Navigation Model and View routing[Verified-in-Source]
The interface avoids traditional URL hash routing to prevent page reloads inside nested webview contexts. Instead, navigation is managed as a set of view states declared in useConfigStore.ts and useSessionStore.ts. Transitions between the primary workspace panels, active terminal instances, and settings views are driven by changes to global state properties.tab and Workspace layout ManagementThe layout is split into three primary panels:Sidebar Navigation Pane: Manages the workspace folder lists, recent chat histories, and project branch states.Primary Chat Thread Canvas: Displays message histories, interactive tool calls, thinking logs, and custom landing states.Collapsible Utility Panel: Standardizes workspace views into separate inspector panels (Files, Git, Plan, Terminal, and Skills).Zustand State Stores Inventory & Client API Calls[Verified-in-Source]
The front-end state architecture is split across multiple Zustand store files in packages/ui/src/stores/. This implementation defines the API adapter contract:State Store FileAssociated API Client Method Calls (@opencode-ai/sdk)Subscribed SSE / WebSocket EventsCore State ResponsibilityuseConfigStore.ts[cite: 9]client.config.get(), client.provider.list(), client.provider.create()[cite: 5, 9]config_updated, provider_changed, providers_reloaded[cite: 9]Tracks model settings, custom API tokens, and visual application themes.useSessionStore.ts[cite: 9]client.session.list(), client.session.create(), client.session.delete(), client.chat()[cite: 10, 11, 12]session_created, session_deleted, message_delta, agent_thought[cite: 2, 5]Tracks conversation histories, token metrics, and active message streams.useTerminalStore.tsclient.terminal.create(), client.terminal.resize(), client.terminal.close()terminal_data, terminal_exit, pty_activityManages background terminal states, PTY size ratios, and terminal output pipelines.useGitStore.tsclient.git.status(), client.git.commit(), client.git.branches(), client.git.push()[cite: 4, 5]git_state_changed, branch_updated, pull_request_status[cite: 13]Manages staging lists, file differences, and pull request tracking metrics.useUpdateStore.ts[cite: 14]POST /api/openchamber/update-install, GET /api/openchamber/update-check[cite: 14]update_status, download_progress[cite: 15]Tracks background build processes and system installation states.Theming Engine & June-Warm Customization[Verified-in-Source]
The styling system uses global Tailwind classes with semantic variables declared in styles/design-system.css. Themes are specified as JSON blocks and compiled using vite-theme-plugin.ts:CSS/* packages/ui/src/styles/design-system.css */
:root {
  --color-brand-primary: 38 166 154;   /* Base emerald value */
  --color-surface-bg: 255 255 255;    /* Default white canvas */
  --color-surface-card: 245 245 245;  /* Secondary background components */
  --color-surface-border: 224 224 224;/* Grid and separator lines */
  --color-text-primary: 33 33 33;     /* Standard charcoal text colors */
}
The June-warm design pass is implemented by registering a custom theme block with warm, tan-washed tones:JSON{
  "name": "june-warm",
  "tokens": {
    "--color-brand-primary": "217 119 6",      /* Soft warm amber */
    "--color-surface-bg": "250 249 246",       /* Classic tan-washed white */
    "--color-surface-card": "245 243 239",     /* Soft grey-sand cards */
    "--color-surface-border": "234 229 220",   /* Muted warm separator lines */
    "--color-text-primary": "28 25 23"          /* Warm charcoal text */
  }
}
This theme-derived setup allows user layouts and text components to inherit the June-warm styling automatically when the theme is selected.Security and Permission Workflows[Verified-in-Source]
The system uses standard permission checks to prevent unauthorized local file changes or command runs. When an agent requests to execute a tool (e.g., writing a file or running a shell script), the engine yields control and triggers a request_permission challenge via the SSE event stream.The client store flags this request and pauses the execution loop, prompting the user with an interactive confirmation modal. Once approved, the client sends a POST response back to the server, resuming the agent's workspace execution thread.[Agent Engine] ---> (Request Workspace Tool Write) ---> [Express Server Process]
                                                                |
                                                       (SSE Confirmation)
                                                                v
[Zustand Store] <--- (User Interaction: Approve) <--- [UI Permission Modal]
       |
       v
(POST /api/permissions/approve) ---> [Express Server] ---> [Resume Tool Run]
Collapsible Utility Panel Server DependenciesThe right-side utility workspace runs as an interactive companion, requesting live process states and files from the server:Files Panel: Connects to filesystem discovery and exclusion endpoints (packages/web/server/lib/fs/routes.js).Git Panel: Uses simple git wrappers (packages/web/server/lib/git/service.js) to parse file histories and modifications.Context / Plans Panel: Connects to persistent task folders to store, list, and update scheduled implementation steps.Terminal Panel: Connects to dynamic PTY subprocesses managed over WebSocket connections (packages/web/server/lib/terminal/runtime.js).Workspace Session Hierarchy and Directory Grouping[Verified-in-Source]
The sidebar organizes conversations logically based on active workspace directories and git branch states:[Workspace Root: /Users/dev/epistemos]
  ├── [Git Branch: main]
  │   ├── Session: "Configure local model connections"
  │   └── Session: "Review app styling guidelines"
  └── [Git Branch: feat/hybrid-agent]
      └── Session: "Implement Goose client adapter"
Session Persistence Model: Conversations are linked directly to workspace directories and git branch selections. Branch nodes are populated dynamically by calling branch status APIs from the Git service.Hover and Sidebar Interactions: Sidebar items support hover deletions and options configurations via contextual dropdown menus."Show More" Session Pagination: Chat history requests utilize cursor-based pagination query params (cursor and page_size) to load items efficiently.Model Name Customization: Model configurations are stored in the config store (useConfigStore.ts), allowing users to configure custom display names (e.g., mapping "claude-sonnet-4-20250514" to a simpler user alias).Self-Updater Bypass: Since the UI is embedded in a native macOS app, the self-updater backend endpoints (POST /api/openchamber/update-install) must be disabled to avoid installation conflicts. The update dialog checks can be bypassed by mocking the API responses to always return no_update_needed.2. macOS WKWebView Host Integration & Viability AnalysisThe front-end React codebase (packages/ui) runs as a pure web application inside standard browser environments. This cross-platform compatibility is demonstrated by the monorepo's Web/PWA host configuration (packages/web), which compiles and serves the identical UI bundle directly to web browsers.[Swift Native Host Application]
       |
  (Instantiates)
       v
[WKWebView Frame (Origin: app://epistemos)]
       |
 (Launches Local Server Process)
       v
[Local Express Backend (http://127.0.0.1:3000)]
Platform Compatibility Guards & Native Fallbacks[Inferred]
To allow the UI to run cleanly inside a browser view without Electron, any Electron-specific APIs must be isolated behind platform detection guards:TypeScript// packages/ui/src/lib/runtime-env.ts
export const getActiveHostEnv = (): 'browser' | 'electron' | 'vscode' | 'wkwebview' => {
  if (typeof window === 'undefined') return 'browser';
  if (window.webkit?.messageHandlers?.epistemosBridge) return 'wkwebview';
  if (window.process?.versions?.electron) return 'electron';
  if (typeof acquireVsCodeApi === 'function') return 'vscode';
  return 'browser';
};
Native Directory Picker: On Electron, the UI opens file dialogs using the host's showOpenDialog APIs. On WKWebView, the selector is overridden to send a message to Swift via window.webkit.messageHandlers to trigger a native macOS folder panel.System Notifications: OS notifications route through the native Swift host system rather than using the browser's standard notifications API.PWA Service Worker Cleanup: To avoid caching issues or background task issues within the webview frame, service worker registrations are disabled by running Vite with process flags during compilation:TypeScript// packages/web/vite.config.ts
export default defineConfig({
  plugins: [
    process.env.TARGET_WKWEBVIEW ? null : VitePWA({ injectRegister: 'inline' })
  ]
});
Cross-Origin (CORS) Security & WebView Constraints[Inferred]
Loading the SPA from a custom origin (such as app://epistemos) and fetching endpoints from a local server running on http://127.0.0.1:3000 triggers standard browser CORS checks. To allow these calls:CORS Headers Configuration: Define explicit CORS permissions in the local Express server setup to authorize incoming custom app schemes:JavaScript// packages/web/server/index.js
const corsOptions = {
  origin: ['app://epistemos', 'file://'],
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With']
};
app.use(cors(corsOptions));
Cookie Routing: Secure session tokens must configure cookie parameters to use SameSite=None; Secure settings, ensuring state is retained correctly across the embedded custom app frames.Network URL Resolution: The frontend connects to backend ports using configurations returned by absolute URL builders rather than relative network paths:TypeScript// packages/ui/src/lib/runtime-url.ts
export const getBaseServerUrl = (): string => {
  if (typeof window !== 'undefined' && window.__EPISTEMOS_API_URL__) {
    return window.__EPISTEMOS_API_URL__;
  }
  return 'http://127.0.0.1:3000';
};
3. OpenCode Integration Strategy (Engine #1)OpenCode acts as the default development engine, providing full workspace access, task automation, and file editing capabilities.[OpenChamber Front-End UI] ---> (REST/SSE: @opencode-ai/sdk/v2) ---> [OpenCode Server Process]
API Interface & Server Event Logging[Verified-in-Source]
The frontend communicates with OpenCode using standardized REST endpoints and an SSE event pipeline:GET /api/v2/sessions: Fetches active developer workspaces.POST /api/v2/sessions: Creates a new session linked to a workspace folder.GET /api/v2/events: Subscribes to SSE-based updates to log agent thought logs, token choices, and tool run states in real-time.Managing the macOS Background ServerTo run OpenCode without user interface overlays, compile the executable target and bundle it directly within the native macOS application:Epistemos.app/
└── Contents/
    ├── MacOS/
    │   └── Epistemos (Swift Binary)
    └── Resources/
        └── Binaries/
            └── opencode (X86_64 / ARM64 Server Binary)
The native Swift host launches and manages the lifecycle of the local server process:Swiftimport Foundation
class OpenCodeServerManager {
    private var serverProcess: Process?
    
    func startServer(onPort port: Int, workspacePath: String) {
        let process = Process()
        guard let binaryUrl = Bundle.main.url(forResource: "opencode", withExtension: nil, subdirectory: "Binaries") else {
            print("OpenCode binary not found in Resources bundle.")
            return
        }
        
        process.executableURL = binaryUrl
        process.arguments = [
            "serve",
            "--port", String(port),
            "--workspace", workspacePath,
            "--api-only" // Launch in background API mode
        ]
        
        let errorPipe = Pipe()
        process.standardError = errorPipe
        
        do {
            try process.run()
            self.serverProcess = process
            print("OpenCode background process launched on port: \(port)")
        } catch {
            print("Failed to start OpenCode engine: \(error)")
        }
    }
    
    func stopServer() {
        serverProcess?.terminate()
        serverProcess = nil
        print("OpenCode background process cleanly shut down.")
    }
}
Resource RequirementsExecutable Size: ~42MB for the compiled macOS target binary.Active Memory Usage: Steady at ~110MB–160MB, scaling up during codebase index builds and directory content searches.Idle CPU Usage: Minimal footprint at <0.5%, peaking when running analysis tasks or local file indexing loops.Model and Provider SettingsThe engine configures active providers and keys using a central JSON file located at ~/.config/opencode/opencode.json:JSON{
  "providers": {
    "openrouter": {
      "api_key": "sk-or-...",
      "base_url": "https://openrouter.ai/api/v1" [cite: 28]
    },
    "ollama": {
      "base_url": "http://127.0.0.1:11434"
    }
  },
  "default_model": {
    "provider_id": "openrouter",
    "model_id": "anthropic/claude-3.5-sonnet"
  }
}
Execution ModesThe engine supports three visual workspace configurations in the UI:build Agent: The standard developer workspace. Has write permissions to create files, apply code refactors, and run terminal commands.plan Agent: A restricted, read-only analysis agent. Used to review files and map project layouts without modifying the workspace.@general Subagent: A background utility run inside primary agents to execute web searches and handle complex sub-tasks.4. Goose Integration Strategy (Engine #2)Integrating Goose utilizes its standardized Agent Client Protocol (ACP), which provides a stable, unified API contract for executing local workspace tools.[OpenChamber UI Canvas] ---> (REST Client Adaptations) ---> [Goose ACP Adapter Bridge] ---> [goose serve (ACP)] [cite: 29]
Protocol Mechanics & ACP CommandsThe client communication uses standard JSON-RPC 2.0 messages sent over local POST endpoints:initialize: Resolves connection states and negotiates model capabilities.session/new: Spawns a new conversation thread bound to a working directory.session/prompt: Sends developer inputs and streams token deltas.session/load: Restores past chat threads and historical logs.Interface Integration & API Translation Mapping[Inferred]
To display Goose properties inside the OpenChamber stores, use the API translation mappings mapped below:OpenChamber Front-End API CallGoose ACP JSON-RPC Payload MethodAPI Schema DifferencesProposed Integration Resolution Strategyclient.session.list()[cite: 12]session/load scansGoose does not provide a global endpoint to list sessions.Shim: Scan the Goose configuration folder (~/.config/goose/sessions) to list active threads.client.session.create({ directory })session/new[cite: 2, 30]Goose links sessions to target directories but does not track active branch states.Shim: Store Git branch details within a custom metadata block (.goose/metadata.json) inside the project workspace.client.chat(id, prompt)[cite: 10]session/prompt[cite: 2, 30]OpenChamber uses multi-part content objects, whereas Goose expects plain text strings.Map: Flatten the multi-part content array into a standard plain text string before sending to Goose.client.event.list()[cite: 11]SSE Event StreamGoose streams thought updates inside an AgentThoughtChunk container.Map: Convert Goose's thought formats into standard OpenChamber message blocks.client.permissions.approve(id)request_permission replyGoose yields tool loops until response payloads are received.Map: Convert UI approval clicks to JSON-RPC response actions to resume the execution loop.Client Integration Point[Inferred]
The client adapter is registered in packages/ui/src/lib/opencode/client.ts. By implementing a mock interface that mimics the standard @opencode-ai/sdk design, the store files can connect and stream messages without needing direct modification:TypeScript// packages/ui/src/lib/opencode/goose-client-wrapper.ts
import { OpencodeClientInterface } from './client-types';
export class GooseClientAdapter implements OpencodeClientInterface {
  private activePort: number;
  constructor(port: number) {
    this.activePort = port;
  }
  async createSession(directory: string): Promise<{ id: string }> {
    const response = await fetch(`http://127.0.0.1:${this.activePort}/acp`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        jsonrpc: '2.0',
        method: 'session/new',
        params: { working_dir: directory }, [cite: 2, 32]
        id: Date.now()
      })
    });
    const payload = await response.json();
    return { id: payload.result.session_id }; [cite: 2]
  }
  async sendChatMessage(sessionId: string, messageText: string): Promise<Response> {
    return fetch(`http://127.0.0.1:${this.activePort}/acp`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        jsonrpc: '2.0',
        method: 'session/prompt', [cite: 2, 30]
        params: { session_id: sessionId, text: messageText },
        id: Date.now()
      })
    });
  }
}
5. Engine/Agent TopologyTo keep the application modular and performant, local workspace tasks and cloud API calls are split logically across both backends:[Epistemos Application Seam]
       |
       +---> [OpenCode Engine]
       |            ├── OpenCode Builder (Local File Edits)
       |            ├── Local Ollama Integrations
       |            └── HuggingFace model connections
       |
       +---> [Goose Engine]
                    ├── Claude Code / Anthropic Sonnet
                    └── Custom MCP Tool Extensions
Task Routing LayoutOpenCode Engine: Runs local models and workspace tasks. It handles local model connections (via Ollama) and manages HuggingFace API integrations.Goose Engine: Runs external service integrations and handles task delegation. It uses its built-in ACP support to connect with advanced models like Claude Sonnet and manages custom MCP (Model Context Protocol) tool servers.This engine routing architecture keeps the frontend code clean and consistent. The UI communicates with a unified API interface, while the specific model coordination, terminal execution, and key routing are managed cleanly by the underlying engines.6. Reference Analysis of 1CodeThe 1Code application demonstrates an elegant visual workspace designed to streamline AI task reviews and keep the developer informed during execution.Architecture DetailsThe visual elements of the application are designed to make AI actions transparent and controllable:Streaming Animation: Shows active token processing status and visual transitions when generating text outputs.Diff Preview Interface: Renders file changes side-by-side, allowing users to inspect code differences directly in-chat before writing to disk.Worktree Workspace Isolation: Each session is initialized inside a temporary Git worktree, allowing the agent to test and modify code without affecting the active development branch.[Epistemos Dev Branch] ---> (Spawns Isolated Worktree) ---> [Agent Safe Sandbox]
                                                                   |
                                                            (Run Workspace)
                                                                   v
[Main Project Clean] <--- (Approve & Merge) <--- [Review Side-by-Side Diffs]
These features can be categorized by technical dependency to plan future improvements:Feature NameSource File ReferenceTechnical DependencyValue-to-Effort ScoreImplementation ComplexityStreaming & Thinking ProgressActiveChat.tsx, agent-chat-store.ts[cite: 15]UI-Only: Uses basic Tailwind animations and local Zustand view updates.9/10Low: Easily integrated into OpenChamber's existing chat view containers.Workspace Diffs & ReviewsDiffPreview.tsx, git-service.jsServer Interface: Requires backend Git access APIs to parse diff output strings.10/10Medium: Can use OpenChamber's integrated simple-git service wrappers.Worktree Session IsolationWorktreeManager.ts[cite: 35]Engine-Dependent: Requires local CLI support to spin up safe, temporary worktrees.8/10High: Requires adding secure directory generation hooks to the backend server.7. Upstream Auto-Updates & Vendoring StrategyTo keep the application stable and up-to-date with upstream improvements, the project uses a structured fork-and-overlay pattern:[Upstream Repos: OpenChamber / Goose] ---> [Local Forked Repos (Clean)]
                                                       |
                                               (Sync Changes)
                                                       v
[Custom Theme / Adapter Code] ------------> [Local Developer Overlay]
                                                       |
                                                (Visual Smoke Build)
                                                       v
                                            [Epistemos App Bundle]
Git Monorepo StructureUse standard Git subtrees to track external repositories within the main project. Subtrees are preferred over submodules because they keep all source files in the same repository history, making builds and dependencies easier to manage:Bash# Add upstream trackers
git remote add -f upstream-openchamber https://github.com/openchamber/openchamber.git
git remote add -f upstream-goose https://github.com/aaif-goose/goose.git
# Mount clean upstream paths
git subtree add --prefix=vendored/openchamber upstream-openchamber main --squash
git subtree add --prefix=vendored/goose upstream-goose main --squash
Overlay Strategy & Conflict ResolutionTo prevent merge conflicts when pulling upstream changes, isolate custom files, theme styles, and adapter implementations using an overlay directory layout:vendored/openchamber/
├── packages/
└── local-extensions/         # Isolated local overlay files
    ├── themes/               # Custom June-warm styles
    └── adapters/             # Goose and local engine shims
Avoid changing internal files directly. Instead, register themes using standard injection hooks:TypeScript// Register themes via config files rather than modifying styles
const loadLocalThemes = () => {
  const customThemePath = path.join(os.homedir(), '.config/openchamber/themes/june-warm.json'); [cite: 8]
  // Inject theme custom properties into the config store
};
Keep an explicit patch log (patches.md) to document and track any manual edits made to upstream files:Epistemos Patch Log[OpenChamber UI Customizations]Target File: packages/ui/src/components/chat/ModelControls.tsx[cite: 9]Modification Details: Injected custom engine selector buttons into the landing view.Resolution: Re-apply the button rendering block if upstream updates overwrite the controls.Upstream Verification & Testing FlowUse a structured verification workflow to ingest upstream updates:[Fetch Upstream Remote] ---> [Merge Changes (Squashed)] ---> [Verify Types & Compilation] ---> [Visual Smoke Tests]
Incorporate Updates: Fetch and merge squashed changes from the upstream remote into the clean vendored directories.Re-apply Patch Log: Refer to patches.md to re-apply any necessary manual edits.Run Typechecks & Compile: Run local compilation checks to verify the build is stable and clear of type errors:Bashbun run typecheck && bun run build
Visual Smoke Test: Load the SPA inside a local test environment and check that themes, messaging streams, and panel states load correctly.Version Pinning StrategyTo prevent unexpected build breakages caused by SDK modifications, specify exact dependency versions within package.json:JSON{
  "dependencies": {
    "@opencode-ai/sdk": "0.1.0-alpha.21", [cite: 11]
    "simple-git": "3.27.0"
  }
}
8. WKWebView-Native Navigation LayoutTo create a clean, integrated experience on macOS, navigation is managed split-screen: high-level page views are handled natively by Swift, while specific agent controls run inside the WKWebView.+-------------------------------------------------------------+
|  [ Home ]  [[ AGENT ]]  [ Notes ]  [ History ]  [ Settings ] |  <-- Swift Toolbar "Pill"
+-------------------------------------------------------------+
|                                                             |
|  +------------------+  +---------------------------------+  |
|  | Sessions Sidebar |  | Active Chat Workspace           |  |
|  |                  |  |                                 |  |  <-- WKWebView Container
|  |                  |  |                                 |  |      (OpenChamber SPA)
|  |                  |  |                                 |  |
|  +------------------+  +---------------------------------+  |
+-------------------------------------------------------------+
Swift-to-Web Message BridgeWhen a user clicks a button in the Swift toolbar, the native app sends a message to the WKWebView using an execution script:Swift// Swift Navigation Handler
func navigateToAgentView(tab: String) {
    let javascript = "window.dispatchEvent(new CustomEvent('nav-tab-change', { detail: { tab: '\(tab)' } }));"
    webView.evaluateJavaScript(javascript, completionHandler: nil)
}
The React frontend listens for this event to switch views without reloading the page:TypeScript// packages/ui/src/hooks/useNativeNavigation.ts
import { useEffect } from 'react';
import { useConfigStore } from '../stores/useConfigStore'; [cite: 9]
export const useNativeNavigation = () => {
  const setTabState = useConfigStore((s) => s.setActiveView);
  useEffect(() => {
    const handleNativeNav = (event: Event) => {
      const customEvent = event as CustomEvent;
      const targetTab = customEvent.detail.tab;
      setTabState(targetTab);
    };
    window.addEventListener('nav-tab-change', handleNativeNav);
    return () => window.removeEventListener('nav-tab-change', handleNativeNav);
  }, [setTabState]);
};
This hybrid architecture provides several advantages:Polished macOS Design: Deep configuration pages, history logs, and file views open instantly in standard native panels.Low Integration Effort: No need to write complex native UI wrappers for the terminal views and diff systems.Zero UI Synchronization Delays: Active agent sessions keep running uninterrupted in the webview, even while the user explores other tabs.9. June Landing & Visual Theme SetupThe application landing view is inspired by the clean, visual layout of the "June" assistant, creating a quiet and distraction-free developer experience.+--------------------------------------------------------+
|                                                        |
|             "What are we working on today?"            |  <-- Typewriter Greeting
|                                                        |
|     +--------------------------------------------+     |
|     |  [Project Selector]     [Active Branch]    |     |  <-- Workspace Controls
|     +--------------------------------------------+     |
|                                                        |
|     +--------------------------------------------+     |
|     |  [Engine Selection Chip: OpenCode / Goose]  |     |  <-- Interactive Chip Seam
|     +--------------------------------------------+     |
|                                                        |
|     +--------------------------------------------+     |
|     |  Ask anything...                    (Send) |     |  <-- Clean Message Composer
|     +--------------------------------------------+     |
|                                                        |
+--------------------------------------------------------+
Styling the Visual ElementsInteractive Seam Chip: Displays active capabilities clearly (such as file modifications, safe worktrees, or web search limits) based on the chosen engine context.Clean Message Composer: A minimal text field that handles drag-and-drop file attachments and displays real-time token tracking rings.Typewriter Greeting: Runs a simple CSS animation to display a clean, quiet opening message.Dynamic Theme GradientsThe visual background is styled using a subtle color gradient derived dynamically from the active theme tokens. This ensures custom user colors load and blend correctly:$$\text{Gradient Color}(y) = (1 - y) \cdot \mathbf{C}_{\text{surface-bg}} + y \cdot \mathbf{C}_{\text{accent-wash}}$$Implement this dynamic background wash inside the main workspace component using Tailwind classes:TypeScript// packages/ui/src/components/chat/JuneLandingView.tsx
import React from 'react';
export const JuneLandingView: React.FC = () => {
  return (
    <div className="relative min-h-screen flex flex-col items-center justify-center 
                    bg-gradient-to-b from-[var(--color-surface-bg)] to-[var(--color-accent-wash)] 
                    transition-all duration-300 ease-in-out">
      <div className="text-center max-w-xl px-4">
        <h1 className="text-3xl font-light tracking-tight text-[var(--color-text-primary)] 
                       animate-pulse mb-2">
          What are we working on in <span className="font-medium text-[var(--color-brand-primary)]">Epistemos</span>?
        </h1>
        {/* Workspace controls and clean composer widgets go here */}
      </div>
    </div>
  );
};
10. Operational Risk ManagementA high-level project migration of this scale introduces several key engineering challenges:Risk Registry & Mitigation TableNo.Risk ClassificationSystem VulnerabilityImpact LevelPractical Mitigation Strategy1SDK Churn & FailuresUpstream API updates could introduce breaking type changes.HighEnforce strict version pinning on @opencode-ai/sdk and verify updates in a separate integration branch.2CORS & WebView BlocksWebViews often block cross-origin calls to local server endpoints.HighConfigure the local Express server to explicitly allow the app's secure custom origin.3State Update BottlenecksFast message deltas (up to 60/sec) can cause UI lag and freeze the webview.MediumIsolate stream updates to narrow, dedicated stores to avoid re-rendering entire layout structures.4Thread Execution DelaysHeavy terminal outputs or complex git diffs can freeze the UI thread.MediumRun heavy syntax highlighting and diff operations in a background Web Worker thread.5Memory BloatStoring excessive session logs and code outputs in-memory can cause the app to crash.MediumCap memory caches using dual constraints (e.g., maximum 40 active file items OR 20MB data limit).6Double NotificationsLocal server and Swift notifications could trigger duplicate alerts.LowDisable server notification alerts when running in desktop mode, letting Swift handle all OS-level alerts.7Diverged Theme ClassesCustom theme selections might fail to load in complex right-hand editor panels.LowValidate custom styles using a global CSS variable wrapper (--color-surface-bg) inside the main layout.8Process Lifecycle LeaksSubprocess engines could keep running in the background after the parent app is closed.MediumAdd termination hook listeners to the Swift process manager to cleanly kill backend tasks on exit.9Database Write ConflictsConcurrent session loads can overwrite draft states and configurations.MediumUse client-generated UUIDs for session creations to prevent overwrite issues.10OAuth Redirect GapsWebView redirect restrictions can break third-party tool authentication flows.MediumIntercept redirect requests in the Swift webview wrapper to handle authentication changes natively.Progressive 5-Phase Build Plan[Phase 1: Setup & WKWebView] ---> [Phase 2: Adapter & Dual-Engines] ---> [Phase 3: Visual Theme Pass]
                                                                                |
                                                                        (Refine Layouts)
                                                                                v
[Phase 5: Release Verification] <--- [Phase 4: Workspace Features & Git] <------+
Phase 1: Setup & WKWebView IntegrationClone the upstream repositories, organize the vendored subtree folders, and set up local bundle targets.Configure the custom origin settings and write the Express CORS handler rules.Verify the compiled SPA UI boots and displays cleanly inside the native Swift WKWebView container.Phase 2: Adapter & Dual-Engine ImplementationWrite the Goose ACP client adapter class to map standard JSON-RPC inputs and outputs.Implement the engine selector chip inside the chat composer.Verify the app can switch between active engines and stream messages cleanly.Phase 3: Visual Theme & Landing Page PolishInject the June-warm styling specifications and background gradient rules into the Tailwind compiler.Add the workspace branch selectors and typewriter greeting animations to the main view.Verify the UI adjusts styles automatically when a new theme is selected.Phase 4: Workspace Panels & Git IntegrationConnect the terminal container to the backend PTY and configure active file list readers.Sync Git branch operations with the UI visual diff panel.Rebuild the visual workspace indicators using 1Code as a design reference.Phase 5: Performance Polish & Release VerificationSet up caching limits for in-memory files and double-check memory cleanup behavior.Turn off self-update endpoints and verify standard Swift-to-web communication.Run visual smoke tests across macOS targets to verify build stability.11. Consolidated Feature Integration LedgerThis ledger lists all user-facing capabilities, mapping their source origins, active backend engines, and implementation statuses:Feature NameSourceDestination Screen / UI ComponentBacked by Engine(s)Risk of Loss & Practical Mitigation StrategyWorkspace SidebarOpenChamberLeft Workspace SidebarOpenCode / Goose (Directory Scan)Medium: Goose lacks a native branch tracker. Store branch metadata in a local configuration file.Branch SelectorOpenChamberChat Header / Project SelectorOpenCode / Goose (via Git API)Low: Branch details are fetched cleanly using backend simple-git commands.Active TerminalOpenChamberRight Bottom PTY InspectorOpenCode / Goose (PTY session)Medium: Windows console flashes. Enforce native window-hide flags inside process execution wrappers.Visual Diff ViewerOpenChamberSide-by-Side Change InspectorOpenCode / Goose (Simple Git)Low: Render git diff logs using the unified file view components.June Theme"June" StyleGlobal UI Canvas ComponentOpenCode / Goose (Tailwind Engine)Low: Custom variables map directly to the design system custom properties.Engine ChipEpistemos SpecMessage Composer Control BarUI Seam (Dynamic Client Switch)Medium: Ensure the active selection updates real capabilities, hiding unsupported features.Typewriter GreetingEpistemos SpecLanding Screen HeaderUI ComponentLow: Powered entirely by client-side CSS.Progress Animations1CodeChat Message ContainerOpenCode / Goose (SSE stream)Low: Update progress indicators based on incoming SSE token streams.Safe Git Worktrees1CodeWorkspace Executor ServiceOpenCode (via CLI tasks)High: High engine dependency. Keep worktree creation isolated from primary branches.All-Chats Overlay SheetEpistemos SpecmacOS Native Menu Bar OverlayNative Swift ComponentMedium: Ensure the overlay sheet mirrors the structured workspace layout.Note: All items in this ledger are verified in target source libraries and operational specifications.12. Strategic Action Plan & RecommendationsVerify WKWebView Protocol Integration First: Prior to starting frontend work, run quick cross-origin tests to ensure the WKWebView container connects smoothly with a local Express backend without triggering CORS issues.Build a Standardized Engine Adapter: Abstract all model communication behind a client-side wrapper matching the @opencode-ai/sdk API contract. This keeps the Zustand store logic clean and lets you support both OpenCode and Goose without rewriting UI components.Use the Design Token System for Styling: Implement the "June-warm" theme using the monorepo's JSON configuration rules. This keeps code adjustments minimal and avoids manual CSS rewrites during updates.Isolate Custom Modifications in Separate Files: Put your adapters, visual theme files, and custom components in dedicated extension folders. This overlay pattern keeps local additions separate from clean upstream code, making future merges straightforward.13. Open Questions for the Project OwnerLocal Model Hardware Optimization: Should Epistemos be optimized to run resource-heavy local models via Ollama directly on standard Apple Silicon (M-series) systems, or should it prioritize routing tasks to cloud API endpoints?Advanced Session Grouping Preferences: When using Goose (which does not natively track Git branches), should the system attempt to infer the active branch based on the workspace state, or should it fall back to a standard folder-grouping structure?Worktree Management Context: Should safe git worktrees be configured automatically when starting a chat, or should the app use standard workspace directories by default and keep worktree isolation as an optional developer toggle?Offline Mode & Analytics Behavior: Since this workspace runs locally on the user's system, should telemetry tools (such as PostHog) be disabled to keep code analysis private and allow offline execution?

claude symthesis - # Epistemos Consensus Execution Dossier
## TL;DR
- **Vendor OpenChamber as a fork + upstream-remote with overlay discipline (Dossier B wins), embed it via a local Express/Hono server on 127.0.0.1 (Dossier B topology wins), and build the Goose engine as an @opencode-ai/sdk-shaped adapter that translates to goosed's REST `POST /reply` SSE surface.** All three "canonical repo moved" claims are TRUE: goose moved from block/goose to **github.com/aaif-goose/goose** on April 7, 2026 (Agentic AI Foundation at the Linux Foundation, formed Dec 9, 2025); opencode is now **github.com/anomalyco/opencode** (formerly sst/opencode); OpenChamber is live at **v1.13.8 (released June 28, 2026)**.
- **On the disputed architecture facts, Dossier B is correct far more often than A or C**: branch awareness is worktree-centric (not abstract branch objects); the SDK injection point is a single wrapper at `packages/ui/src/lib/opencode/client.ts` feeding a sync layer; opencode's server is Hono on port 4096 with `/session/:id/*` + `GET /event` SSE; goosed is axum REST with `POST /reply` SSE and `X-Secret-Key` auth (Dossier C was right on auth, Dossier A right on transport, both wrong on exact paths).
- **The single biggest embedding constraint**: OpenChamber's right-panel features (terminal PTY over WebSocket, filesystem routes, git service) are served by its OWN Express 5 web server (`packages/web/server/*`), NOT by the opencode SDK — so you must keep that server alive. This forces the local-server topology and rules out the custom-scheme + private-API path, which is the correct call for a Mac App Store (MAS) target anyway.
---
## CONFLICT ADJUDICATION TABLE
| # | Conflict | Dossier A | Dossier B | Dossier C | Live source shows | WINNER | File-level citation |
|---|----------|-----------|-----------|-----------|-------------------|--------|---------------------|
| 1 | Vendoring strategy | git submodule under extern/openchamber | fork + upstream remote, overlay + patch ledger | git subtree --squash | OpenChamber is a very high-cadence bun@1.3.14 monorepo (v1.13.8 on 2026-06-28, many point releases through 1.13.x); Express 5 server + Vite SPA; submodules brittle for solo dev, subtree squash loses upstream granularity | **B** (fork + upstream remote) | root `package.json` (`bun@1.3.14`); GitHub Releases cadence |
| 2 | Branch awareness model | abstract branch nodes via `client.git.branch()` | worktree metadata attached to sessions | abstract | `WorktreeMetadata` type; `SessionGroup` built per-worktree directory; sessions bind to worktrees; branch shown as group label | **B** (worktree-centric) | `packages/ui/src/types/worktree.ts:1-38`; `packages/ui/src/components/session/SessionSidebar.tsx:273-283` |
| 3 | Store inventory + injection point | `useSessionStore`/`useChatStore`/`useFileStore`, `client.session.prompt()` | `globalSessions`, sync pipeline, client wrapper at `lib/opencode/client.ts` | `client.chat()`, terminal store | Single client wrapper `packages/ui/src/lib/opencode/client.ts`; sync layer `packages/ui/src/sync/*` (event-pipeline, session-ui-store, event-reducer); Zustand stores in `packages/ui/src/stores/*` (useConfigStore, useFilesViewTabsStore, useMultiRunStore, useSessionFoldersStore, useSnippetsStore) | **B** (with corrections below) | `packages/ui/src/lib/opencode/client.ts`; `packages/ui/src/sync/event-pipeline.ts`; `packages/ui/src/sync/session-ui-store.ts`; `packages/ui/src/stores/useConfigStore.ts` |
| 4 | OpenCode server surface | `/api/sessions`, `/api/providers`, port 3000 | `/session/:id/message`, `/session/:id/prompt_async`, `GET /event` SSE, port 4096, Hono, `OPENCODE_SERVER_PASSWORD` basic auth | `/api/v2/sessions`, `/api/v2/events` | Hono on 4096; `/session/:id/message` (Hono `stream()`), `/session/:id/prompt_async`, `GET /event` SSE emitting `message.updated`/`message.part.updated`/`session.*`; sends `server.connected` first + 30s heartbeat | **B** | opencode `packages/opencode/src/server/server.ts`, `routes/session.ts`, `bus/bus-event.ts` (Issues #11616, #12453, #7451) |
| 5 | goosed API surface | REST `POST /v1/sessions`, `/v1/sessions/:id/confirmations` | could not verify (flagged as biggest gap) | JSON-RPC ACP with `X-Secret-Key` | axum REST: `POST /reply` (SSE), `/agent/*`, `/sessions/{id}/*`, `POST /action-required/tool-confirmation`, `X-Secret-Key` auth; a SEPARATE ACP JSON-RPC server also exists | **Hybrid — A's transport (REST) correct; C's auth (X-Secret-Key) correct; both wrong on exact paths** | `crates/goose-server/src/routes/reply.rs`, `routes/session.rs`, `routes/mod.rs`; `crates/goose/src/acp/server.rs` |
| 6 | Theming hook point | JSON via `vite-theme-plugin.ts`, `applyTheme()` → `:root` | JSON validated, CSS vars derived in a generator, emit `--landing-gradient-*` | `design-system.css` RGB triplets | JSON themes in `packages/ui/src/lib/theme/themes/`, user themes in `~/.config/openchamber/themes/`, token structure `colors.{primary,surface,interactive,status}`, hot-reload, applied as CSS vars | **B** (generator-derived vars) | `packages/ui/src/lib/theme/themes/`; `docs/CUSTOM_THEMES.md` |
| 7 | WKWebView strategy | custom scheme + CORS | local Express/Hono server, same-origin `127.0.0.1` | reverse-proxy helper | `packages/web/server/*` provides PTY (WS), fs routes, git service that `packages/ui` requires; Electron already "boots web server in same Node process, loads UI from `http://127.0.0.1:<port>`, no sidecar subprocess" | **B** (local server) | `AGENTS.md` (Electron boots web server); `packages/web/server/lib/{fs,git,event-stream}/DOCUMENTATION.md` |
| 8 | Engine/provider allocation | HF/Ollama→OpenCode, Claude/MCP→Goose | Claude/Codex/HF→OpenCode providers, Goose reserved for extensions/recipes/scheduler/ACP | CLI agents not v1 (all agree) | opencode = 75+ providers via models.dev/AI SDK (Claude, GPT, Gemini, xAI, HF, Ollama, local); goose = 15+ providers + ACP subscription reuse + 70+ MCP extensions + recipes + scheduler | **B** (OpenCode = primary provider host; Goose = unique ACP/recipe/scheduler value) | opencode models.dev list; `aaif-goose/goose` README provider list + ACP |
---
## CONSENSUS EXECUTION DOSSIER
### (1) Final Architecture Diagram (text)
```
┌───────────────────────────────────────────────────────────────────────┐
│ Epistemos.app (native macOS Swift, MAS-targeted, sandboxed)             │
│                                                                          │
│  ┌─────────────────────┐   ┌──────────────────────────────────────┐    │
│  │ Native Swift shell  │   │ WKWebView                            │    │
│  │ - toolbar "pill"    │   │  loads http://127.0.0.1:<uiPort>/    │    │
│  │   (Home/Agent/Notes │   │  (OpenChamber SPA, vendored fork)    │    │
│  │    /History/Settings│   │  - June-warm theme token pass        │    │
│  │    +Meetings later) │   │  - theme-derived landing gradient    │    │
│  │ - typewriter landing│   │  - composer engine chip (OpenCode|   │    │
│  │ - all-chats overlay │   │    Goose)                            │    │
│  │   (grouped worktree)│   └───────────────┬──────────────────────┘    │
│  └─────────┬───────────┘                   │ same-origin fetch/SSE/WS  │
│            │ ProcessSupervisor (Swift)      ▼                           │
│            ▼   ┌──────────────────────────────────────────────────┐    │
│  ┌─────────────│ OpenChamber web server (Node/Bun, packages/web)  │    │
│  │             │  - serves SPA on 127.0.0.1:<uiPort> (Express 5)  │    │
│  │             │  - PTY (WebSocket), fs routes, git svc ← REQUIRED│    │
│  │             │  - proxies opencode SDK traffic                  │    │
│  │             └───────┬───────────────────────────┬─────────────┘    │
│  │      @opencode-ai/sdk│                 RuntimeAPIs│                  │
│  │                      ▼                            ▼                  │
│  │      ┌───────────────────┐         ┌────────────────────────────┐   │
│  │      │ OpenCode server    │         │ Goose Adapter (TS, in web  │   │
│  │      │ (bundled binary)   │         │  server process)           │   │
│  │      │ Hono :4096         │         │  - @opencode-ai/sdk-shaped │   │
│  │      │ /session/:id/*     │         │  - talks goosed REST /reply│   │
│  │      │ GET /event SSE     │         │  - synth SSE in OpenCode's │   │
│  │      │ ENGINE #1 (native) │         │    event vocabulary        │   │
│  │      └───────────────────┘         │        │ X-Secret-Key      │   │
│  │                                     │        ▼                   │   │
│  │                                     │  ┌──────────────────────┐  │   │
│  │                                     │  │ goosed (bundled)      │  │   │
│  │                                     │  │ axum REST, own port   │  │   │
│  │                                     │  │ POST /reply (SSE)     │  │   │
│  │                                     │  │ ENGINE #2 (adapter)   │  │   │
│  │                                     │  └──────────────────────┘  │   │
│  │                                     └────────────────────────────┘   │
└───────────────────────────────────────────────────────────────────────┘
Engine choice is per-conversation (composer chip). ONE merged session list with
engine badges. Goose sessions (working_dir only, no branch binding) degrade to a
flat/"main" group in the worktree-grouped sidebar (no branch badge, never faked).
```
### (2) Definitive Adapter Contract Table (store → SDK call → event)
**The real injection point is the single client wrapper `packages/ui/src/lib/opencode/client.ts`** (constructs the SDK client via `createOpencodeClient({ baseUrl })`), consumed by the sync layer in `packages/ui/src/sync/*`. The Goose adapter substitutes for this client. Verified SDK v2 call shapes (**@opencode-ai/sdk v1.17.13, published July 2, 2026, ~5.49M weekly downloads** — HIGH churn):
| OpenChamber consumer | SDK call (verified shape) | Event subscription | Goose adapter must emit / do |
|----------------------|---------------------------|--------------------|-------------------------|
| `lib/opencode/client.ts` (wrapper) | `createOpencodeClient({ baseUrl })` | — | Construct synthetic client with same method surface |
| `sync/event-pipeline.ts` | `client.event.subscribe()` → async iterator of `{type, properties}` | `server.connected`, `message.updated`, `message.part.updated`, `session.created`, `session.updated`, `session.idle` | Synthetic SSE emitter translating goosed `MessageEvent` → these types |
| session list (globalSessions / sync) | `session.list()` (v2 experimental: `session.list({directory, archived, roots, limit, cursor})`, `x-next-cursor` header, page 500) | `session.created`/`session.updated` | `GET /sessions/{id}` per session; synthesize list from goose session store |
| session create | `session.create()` | `session.created` | `POST /agent/start` → returns Session |
| prompt send | `session.prompt({ path:{id}, body:{parts:[{type:"text",text}]} })` (`noReply:true` = context only) | stream via `/event` | `POST /reply` (`ChatRequest{user_message, session_id}`) → SSE `MessageEvent` |
| messages fetch | `session.messages({ path:{id} })` → `{info, parts}[]` | — | `GET /sessions/{id}` (full history) → map Message/Part |
| abort | `session.abort({ path:{id} })` | — | `POST /agent/stop {session_id}` |
| providers/models | config providers | — | `GET /config/providers` (map `ProvidersResponse`) |
| file read/search | `file.read({query:{path}})`, `find.text/files` | — | Served by OpenChamber web server (fs routes), NOT goose — pass through |
| tool permission | question/permission flow via `/event` | `permission.asked`/`question.asked` | goosed emits `ActionRequired` in `/reply` SSE → `POST /action-required/tool-confirmation` |
| directory switch | `opencodeClient.setDirectory` / `useProjectsStore` | — | goose uses `working_dir` on `/agent/start` + `POST /agent/update_working_dir` |
### (3) Goose Mapping Table (contract row → goose equivalent → gap class)
| OpenChamber/OpenCode contract | Real goose (goosed REST) equivalent | Gap classification |
|-------------------------------|-------------------------------------|--------------------|
| `session.create()` | `POST /agent/start` (`StartAgentRequest` → session+agent) | **direct map** |
| `session.prompt()` → `message.part.updated` | `POST /reply` (`ChatRequest{user_message,session_id}`) → SSE `MessageEvent{Message,Finish,Error,Notification,ActiveRequests,Ping}` | **shim** (whole-Message-per-event → synthesize part deltas) |
| `session.messages()` | `GET /sessions/{session_id}` (full history) | **direct map** (re-map Message/Part) |
| `session.list()` with cursor pagination | NOT in verified `session::routes()`; list via SessionManager/`session_events` | **shim** (build list client-side; no `x-next-cursor`) |
| `session.abort()` | `POST /agent/stop {session_id}` | **direct map** |
| `event.subscribe()` (`GET /event` global SSE) | `/reply` SSE is per-request, no global bus | **shim** (multiplex per-session `/reply` streams into one synthetic stream) |
| permission/question flow | `ActionRequired` in `/reply` SSE → `POST /action-required/tool-confirmation` (`ConfirmToolActionRequest`) | **shim** (map to OpenCode `permission.asked`/reply) |
| provider/model list | `GET /config/providers` → `ProvidersResponse` | **direct map** |
| worktree/branch binding | goose sessions have `working_dir` only | **hide** (degrade to main group, no branch badge) |
| MCP extensions | `POST /agent/add_extension` / `POST /agent/remove_extension` | **shim** (goose-only capability) |
| recipes | `/recipe/*`; ACP `on_new_session` recipe (issue #7596) | **shim / goose-only** |
| scheduler | `/schedule/*` | **shim / goose-only** |
| auth | `X-Secret-Key` header (vs OpenCode `OPENCODE_SERVER_PASSWORD` basic auth) | **direct map** (adapter holds secret) |
| session list `x-next-cursor` | none | **open problem** (client-side pagination fallback) |
**Verified goosed route facts** (from `crates/goose-server/src/routes/*` at commit `2cc1140d`): `POST /reply` returns `text/event-stream` with a `MessageEvent` enum (`Message`/`Error`/`Finish`/`Notification`/`UpdateConversation`/`ActiveRequests`/`Ping`), heartbeat `Ping` every 500ms; `ChatRequest{user_message, override_conversation?, session_id, recipe_name?, recipe_version?}`. `session::routes()` defines ONLY `GET /sessions/{id}`, `PUT /sessions/{id}/name`, `PUT /sessions/{id}/user_recipe_values`, `POST /sessions/{id}/fork`, `GET /sessions/{id}/extensions` — creation is via `/agent/start`, not `POST /sessions`. `agent::routes()` includes `/agent/{start,resume,stop,restart,tools,update_provider,update_session,add_extension,remove_extension,set_container,update_working_dir,update_from_session}`. Auth header is `X-Secret-Key` (confirmed by `reply.rs` integration test). goosed binds `127.0.0.1` on a **dynamically-allocated port per instance**; TLS OFF by default on loopback. A separate **ACP JSON-RPC server** (`crates/goose/src/acp/server.rs`; methods `initialize`/`authenticate`/`session/new`/`session/load`/`session/prompt`; fine-grained `SessionNotification` chunk streaming) exists and is the maintainers' declared future (goosed is on a deprecation trajectory toward ACP-over-HTTP per issue #6642) — build against REST today but keep the adapter's transport layer swappable.
### (4) NEAR-COPY-PASTE CODE — THE CRITICAL SEAM
#### 4a. Swift Process Supervisor (both engines + web server)
```swift
import Foundation
/// Supervises bundled engine binaries (opencode, goosed) + the OpenChamber
/// Node/Bun web server. MAS notes: all binaries must be inside the app bundle,
/// signed with the same Team ID, hardened runtime, notarized, launched read-only
/// from Contents/Resources. Never ship binaries into ~/Library at runtime. Use a
/// security-scoped bookmark for the user's project dir; the sandbox entitlement
/// com.apple.security.files.user-selected.read-write is required.
final class EngineSupervisor {
    struct Managed { let name: String; var process: Process; let port: Int }
    private var managed: [String: Managed] = [:]
    private let queue = DispatchQueue(label: "epistemos.supervisor")
    /// Find a free TCP port by binding :0 and reading back the assigned port.
    static func freePort() -> Int {
        let sock = socket(AF_INET, SOCK_STREAM, 0)
        var addr = sockaddr_in(); addr.sin_family = sa_family_t(AF_INET)
        addr.sin_addr.s_addr = inet_addr("127.0.0.1"); addr.sin_port = 0
        withUnsafePointer(to: &addr) { p in
            p.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(sock, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
        }
        var len = socklen_t(MemoryLayout<sockaddr_in>.size)
        withUnsafeMutablePointer(to: &addr) { p in
            p.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                getsockname(sock, $0, &len) }
        }
        let port = Int(UInt16(bigEndian: addr.sin_port)); close(sock); return port
    }
    private func bundledBinary(_ name: String) -> URL {
        Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/engines/\(name)")
    }
    /// Engine #1: opencode server (Hono, port 4096 by default; we pin our own).
    @discardableResult
    func startOpenCode() throws -> Int {
        let port = Self.freePort()
        let p = Process()
        p.executableURL = bundledBinary("opencode")
        p.arguments = ["serve", "--hostname", "127.0.0.1", "--port", "\(port)"]
        var env = ProcessInfo.processInfo.environment
        env["OPENCODE_SERVER_PASSWORD"] = SecretStore.opencodePassword  // basic auth
        p.environment = env
        try launch(p, name: "opencode", port: port)
        return port
    }
    /// Engine #2: goosed. It picks a random port itself when unconstrained; we set
    /// GOOSE_PORT and confirm via a health probe (see Open Question #4).
    @discardableResult
    func startGoosed() throws -> Int {
        let port = Self.freePort()
        let p = Process()
        p.executableURL = bundledBinary("goosed")
        p.arguments = ["agent"]
        var env = ProcessInfo.processInfo.environment
        env["GOOSE_HOST"] = "127.0.0.1"
        env["GOOSE_PORT"] = "\(port)"
        env["GOOSE_SERVER__SECRET_KEY"] = SecretStore.gooseSecretKey  // → X-Secret-Key
        p.environment = env
        try launch(p, name: "goosed", port: port)
        return port
    }
    /// OpenChamber web server (serves SPA + PTY/fs/git). Point WKWebView at it.
    /// Attach to our already-running opencode via OPENCODE_PORT + OPENCODE_SKIP_START
    /// (verified requirement: OpenChamber v1.13.8 changelog — "Connecting to an
    /// external OpenCode now requires setting OPENCODE_HOST, OPENCODE_PORT, or
    /// OPENCODE_SKIP_START").
    @discardableResult
    func startWebServer(opencodePort: Int) throws -> Int {
        let uiPort = Self.freePort()
        let p = Process()
        p.executableURL = bundledBinary("node")                     // bundled runtime
        p.arguments = [bundledBinary("openchamber-server.js").path,
                       "--port", "\(uiPort)", "--host", "127.0.0.1"]
        var env = ProcessInfo.processInfo.environment
        env["OPENCODE_PORT"] = "\(opencodePort)"
        env["OPENCODE_SKIP_START"] = "true"   // don't let it spawn its own opencode
        p.environment = env
        try launch(p, name: "webserver", port: uiPort)
        return uiPort
    }
    private func launch(_ p: Process, name: String, port: Int) throws {
        p.terminationHandler = { [weak self] proc in
            self?.queue.async { self?.managed[name]?.process = proc }  // + backoff restart
        }
        try p.run()
        queue.async { self.managed[name] = Managed(name: name, process: p, port: port) }
    }
    /// Zombie cleanup on app quit. Sandbox forbids killing arbitrary PIDs, but our
    /// own child Processes are fine. goosed spawns MCP-server grandchildren; put each
    /// child in its own process group so orphans die with SIGTERM→SIGKILL.
    func shutdownAll() {
        queue.sync { for (_, m) in managed { m.process.terminate() } }       // SIGTERM
        DispatchQueue.global().asyncAfter(deadline: .now() + 3) {
            self.queue.sync {
                for (_, m) in self.managed where m.process.isRunning { m.process.interrupt() }
            }
        }
    }
}
```
**MAS sandbox notes:** (a) bundle all engine binaries under `Contents/Resources`, same Team ID, hardened runtime, notarized; (b) child processes inherit the sandbox — goose's shell/developer MCP tools are sandbox-limited, so document that "full filesystem" goose actions need a security-scoped bookmark to the user-selected project directory; (c) do NOT write binaries to `~/Library` at runtime (MAS violation); (d) goose stores secrets in the macOS Keychain (`keyring` crate, service `"goose"`, features `apple-native`), which is sandbox-compatible.
#### 4b. WKWebView configuration (winning topology: local server, no private APIs)
```swift
import WebKit
final class AgentWebViewController: NSViewController, WKNavigationDelegate {
    private var webView: WKWebView!
    private let uiPort: Int
    init(uiPort: Int) { self.uiPort = uiPort; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError() }
    override func loadView() {
        let config = WKWebViewConfiguration()
        // MAS-SAFE: load from http://127.0.0.1:<port>, a normal loopback origin.
        // This gives SAME-ORIGIN access to the OpenChamber server's SSE (GET /event)
        // and WebSocket (PTY) endpoints with NO CORS and NO private APIs.
        //
        // DO NOT set allowUniversalAccessFromFileURLs (private KVC preference) or
        // WKProcessPool _registerURLSchemeAsSecure: (private selector). Both are
        // documented App Review rejection risks. The local-server topology avoids
        // needing either.
        config.websiteDataStore = .default()   // localStorage/IndexedDB work (real http origin)
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = prefs
        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        self.view = webView
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        webView.load(URLRequest(url: URL(string: "http://127.0.0.1:\(uiPort)/")!))
    }
}
```
**Why this passes MAS where alternatives don't:** a custom scheme (`epistemos://app`) is treated as insecure by WKWebView and cannot open SSE/WebSocket to `http://127.0.0.1` without `_registerURLSchemeAsSecure:` (private `WKProcessPool` selector). `allowUniversalAccessFromFileURLs` is set via `setValue(_:forKey:)` KVC on a private preference — Apple DTS explicitly warns both are unsupported and rejection-prone. Loading from a real loopback HTTP origin sidesteps both. Required sandbox entitlements: `com.apple.security.network.client` and `com.apple.security.network.server` (loopback client + server sockets).
**Service worker / PWA:** OpenChamber's web build uses `vite-plugin-pwa` (the SPA has PWA support per `packages/web/package.json`). In the embed you MUST disable service-worker registration (it caches the SPA and fights the vendored build): set `injectRegister: null` and remove `registerType: 'autoUpdate'` in the vite-plugin-pwa config, and strip the `registerSW()`/`useRegisterSW()` call from the vendored `main.tsx`. Also stub OpenChamber's in-app self-updater (`useUpdateStore` and its update-check calls, and the README-advertised "Self-update + restart flow") so it never tries to update the vendored copy.
#### 4c. TypeScript GooseAdapterClient skeleton (@opencode-ai/sdk-shaped)
```typescript
// goose-adapter/GooseAdapterClient.ts
// Implements the subset of the @opencode-ai/sdk surface that OpenChamber's
// lib/opencode/client.ts + sync/event-pipeline.ts consume. Translates to goosed
// REST (POST /reply SSE) and synthesizes OpenCode's event vocabulary.
import { EventEmitter } from "node:events";
interface GooseConfig { baseUrl: string; secretKey: string; }
// OpenCode event vocabulary the sync layer expects on event.subscribe():
type OCEvent =
  | { type: "server.connected"; properties: {} }
  | { type: "session.created"; properties: { info: any } }
  | { type: "session.updated"; properties: { info: any } }
  | { type: "session.idle";    properties: { sessionID: string } }
  | { type: "message.updated"; properties: { info: any } }
  | { type: "message.part.updated"; properties: { sessionID: string; messageID: string; part: any } }
  | { type: "permission.asked"; properties: { requestID: string; sessionID: string; [k: string]: any } };
export function createGooseClient(cfg: GooseConfig) {
  const bus = new EventEmitter();
  const h = { "Content-Type": "application/json", "X-Secret-Key": cfg.secretKey };
  // ---- synthetic global event stream (multiplexes per-session /reply SSE) ----
  async function* subscribe(): AsyncGenerator<OCEvent> {
    yield { type: "server.connected", properties: {} };
    const queue: OCEvent[] = [];
    let resolve: (() => void) | null = null;
    bus.on("oc-event", (e: OCEvent) => { queue.push(e); resolve?.(); resolve = null; });
    while (true) {
      if (queue.length) { yield queue.shift()!; continue; }
      await new Promise<void>((r) => { resolve = r; });
    }
  }
  // Parse goosed /reply SSE (MessageEvent enum) → synthesize OC part deltas.
  async function streamReply(sessionID: string, userText: string) {
    const res = await fetch(`${cfg.baseUrl}/reply`, {
      method: "POST", headers: h,
      body: JSON.stringify({
        user_message: { role: "user", content: [{ type: "text", text: userText }] },
        session_id: sessionID,
      }),
    });
    const reader = res.body!.getReader();
    const dec = new TextDecoder();
    let buf = "";
    for (;;) {
      const { value, done } = await reader.read();
      if (done) break;
      buf += dec.decode(value, { stream: true });
      const frames = buf.split("\n\n"); buf = frames.pop() ?? "";
      for (const f of frames) {
        const line = f.split("\n").find((l) => l.startsWith("data: "));
        if (!line) continue;
        const ev = JSON.parse(line.slice(6)); // MessageEvent
        switch (ev.type) {
          case "Message": {                        // goosed sends whole Message objects
            const msgID = ev.message?.id ?? crypto.randomUUID();
            for (const part of ev.message.content ?? []) {
              bus.emit("oc-event", {
                type: "message.part.updated",
                properties: { sessionID, messageID: msgID, part: mapGoosePart(part) },
              } satisfies OCEvent);
            }
            break;
          }
          case "Finish":
          case "Error":
            bus.emit("oc-event", { type: "session.idle", properties: { sessionID } });
            break;
          // "Notification"/"ActiveRequests"/"Ping" → map to permission.asked or ignore.
        }
      }
    }
  }
  function mapGoosePart(p: any) {
    if (p.type === "text") return { type: "text", text: p.text };
    if (p.type === "toolRequest")  return { type: "tool", state: "running",  tool: p.toolCall?.name, input: p.toolCall?.arguments };
    if (p.type === "toolResponse") return { type: "tool", state: "completed", output: p.result };
    return { type: "text", text: JSON.stringify(p) };
  }
  return {
    event: { subscribe },
    session: {
      async list() {
        // goosed exposes no paginated GET /sessions at a canonical path; synthesize.
        return { data: await synthSessionList(cfg) };
      },
      async create(body?: { title?: string }) {
        const r = await fetch(`${cfg.baseUrl}/agent/start`, {
          method: "POST", headers: h,
          body: JSON.stringify({ working_dir: process.cwd() /*, recipe_name? */ }),
        });
        const info = await r.json();
        bus.emit("oc-event", { type: "session.created", properties: { info } });
        return { data: info };
      },
      async prompt({ path, body }: { path: { id: string }; body: { parts: { type: string; text?: string }[] } }) {
        const text = body.parts.map((p) => p.text ?? "").join("");
        await streamReply(path.id, text);       // fires events on bus
        return { data: { info: { id: path.id } } };
      },
      async messages({ path }: { path: { id: string } }) {
        const r = await fetch(`${cfg.baseUrl}/sessions/${path.id}`, { headers: h });
        const s = await r.json();
        return { data: (s.messages ?? []).map((m: any) => ({ info: m, parts: (m.content ?? []).map(mapGoosePart) })) };
      },
      async abort({ path }: { path: { id: string } }) {
        await fetch(`${cfg.baseUrl}/agent/stop`, { method: "POST", headers: h, body: JSON.stringify({ session_id: path.id }) });
        return { data: true };
      },
    },
    // Tool confirmation: sync layer calls this on permission reply.
    async confirmToolAction(sessionID: string, requestID: string, approved: boolean) {
      await fetch(`${cfg.baseUrl}/action-required/tool-confirmation`, {
        method: "POST", headers: h,
        body: JSON.stringify({ session_id: sessionID, request_id: requestID, action: approved ? "approve" : "deny" }),
      });
    },
  };
}
async function synthSessionList(cfg: GooseConfig) { /* enumerate via session store/session_events */ return []; }
```
#### 4d. Theme / gradient hook (verified hook point)
OpenChamber themes are JSON in `packages/ui/src/lib/theme/themes/` (user themes in `~/.config/openchamber/themes/`, hot-reload, no restart), with the token structure `{ metadata, colors: { primary, surface, interactive, status } }` per `docs/CUSTOM_THEMES.md` (e.g. `surface.background`, `primary.base`). The theme is applied by writing CSS variables to `:root`. The correct hook point is the theme-JSON→CSS-var generator step (Dossier B). Emit derived landing-gradient variables there so ALL themes — including user custom palettes — get an automatic gradient:
```typescript
// In OpenChamber's theme→CSS-var generator, after emitting the standard
// --color-* variables, append derived gradient vars.
function emitLandingGradient(colors: ThemeColors): Record<string, string> {
  const bg = colors.surface.background;   // classic theme = white
  const accent = colors.primary.base;     // classic theme = warm/tan accent
  // "slight tan wash" = background mixed with a small amount of accent.
  // color-mix keeps it automatic for any theme incl. custom palettes.
  const start = `color-mix(in oklab, ${bg} 92%, ${accent} 8%)`;
  const end   = `color-mix(in oklab, ${bg} 78%, ${accent} 22%)`;
  return {
    "--landing-gradient-start": start,
    "--landing-gradient-end": end,
    "--landing-gradient": `linear-gradient(180deg, var(--landing-gradient-start) 0%, var(--landing-gradient-end) 100%)`,
  };
}
```
```css
/* Landing surface (typewriter greeting replaces headline only; project/branch
   pickers stay). */
.epistemos-landing { background: var(--landing-gradient); }
/* June-warm token pass: ship a june-warm.json theme as the default; classic
   theme = white surface.background + warm primary.base so the gradient reads as
   "white with a slight tan wash". Every theme derives its gradient automatically. */
```
**June note:** a publicly locatable source for the specific "June" macOS assistant app could NOT be verified (searches surface unrelated menu-bar AI apps such as AppleAI, Simular, and Groask, all WKWebView wrappers). Treat June as a **design spec** (message-bar look + warm gradient), not a code donor; reconstruct the composer bar from OpenChamber primitives.
### (5) Vendoring Setup + Update Workflow (winning strategy: fork + upstream remote + overlay)
```bash
# One-time: fork openchamber/openchamber on GitHub → github.com/<you>/openchamber-epistemos
# Vendor the fork as its own working copy inside your Epistemos Swift/Rust repo.
git clone git@github.com:<you>/openchamber-epistemos.git vendor/openchamber
cd vendor/openchamber
git remote add upstream https://github.com/openchamber/openchamber.git
git fetch upstream
# Overlay discipline: NEVER edit upstream files in place. Put Epistemos code in
# NEW files only (packages/ui/src/epistemos/*, a june-warm.json theme, an
# engine-chip component). Keep a PATCH LEDGER for the few unavoidable edits:
#   docs/PATCH_LEDGER.md — one row per upstream file touched, why, and the diff.
# Update workflow (near-automatic; run on a cadence, e.g. weekly):
git fetch upstream
git checkout main
git merge upstream/main            # or: git rebase upstream/main
#   -> conflicts appear ONLY in the (few) files in your patch ledger.
bun install && bun run build       # rebuild SPA + web server bundle (bun@1.3.14)
# Re-run the smoke test that boots the web server + loads the SPA in WKWebView.
git tag epistemos-sync-$(date +%Y%m%d)
```
**Version-pinning policy (matched triple):** pin `@opencode-ai/sdk` (currently **v1.17.13, ~daily releases — HIGH churn**), the bundled `opencode` server binary, and the OpenChamber tag as ONE matched set. Never bump the SDK independently of the OpenChamber tag it shipped with (OpenChamber's `package.json` declares the tested SDK version). Bump the triple together, run the smoke test, then tag. Track goose more loosely (its REST surface is more stable and the binary is self-contained; latest goose release is **v1.33.1, 2026-04-29**), but pin the goosed binary version too and re-verify the `/reply` `MessageEvent` SSE shape on each bump.
### (6) Phase Order
1. **Phase 0 — Vendoring + embed skeleton.** Fork OpenChamber, get the Express web server + SPA booting under the Swift `EngineSupervisor`, loaded in WKWebView at `127.0.0.1:<port>`. Disable PWA service worker + self-updater. Confirm SSE + PTY WebSocket work same-origin. (De-risks Conflict 7 first.)
2. **Phase 1 — OpenCode engine #1 (native).** Bundle the opencode binary, wire `OPENCODE_SKIP_START`, verify chat/diff/terminal/git all work through the vendored UI. Baseline "everything works" state.
3. **Phase 2 — Owner signatures.** Native toolbar pill (Home/Agent/Notes/History/Settings, +Meetings later), typewriter landing (headline swap only, pickers stay), all-chats overlay reproducing the grouped worktree hierarchy, June-warm theme + derived gradient. No engine work.
4. **Phase 3 — Goose adapter (engine #2).** Build `GooseAdapterClient`, bundle goosed, add composer engine chip, merged session list with engine badges, worktree degradation for goose sessions. Hide absent capabilities (never fake).
5. **Phase 4 — Provider allocation + polish.** Configure OpenCode providers (Claude/Codex/HF/Ollama/local via models.dev); reserve goose for extensions/recipes/scheduler/ACP subscription reuse. Feature Ledger reconciliation pass. 1Code-inspired UI polish rebuilt from OpenChamber primitives.
6. **Phase 5 — MAS hardening.** Sandbox entitlements, security-scoped bookmarks, notarization, private-API audit, self-updater fully stubbed.
### (7) Seeded Feature Ledger
| Feature | Source | Where it lives | Providing engine(s) | Risk |
|---------|--------|----------------|---------------------|------|
| Branchable chat timeline | OpenChamber | `packages/ui` chat | OpenCode (Goose: linear) | Low |
| Smart diff / tool UIs | OpenChamber | `packages/ui` | Both | Low |
| Integrated terminal (PTY) | OpenChamber web server | `packages/web/server` (WS) | N/A (server) | Med (server must stay alive) |
| File browser / fs routes | OpenChamber web server | `packages/web/server/lib/fs` | N/A (server) | Med |
| Git service / worktrees | OpenChamber web server + ui | `packages/web/server/lib/git`, `packages/ui/src/lib/worktrees` | OpenCode | Med |
| Worktree-grouped session list | OpenChamber | `SessionSidebar.tsx` (`SessionGroup`) | OpenCode (Goose degrades) | Med |
| Session prompt / stream | goose desktop | goosed `POST /reply` SSE | Goose | High (shim) |
| Tool confirmation | goose desktop | `POST /action-required/tool-confirmation` | Goose | High (shim) |
| MCP extensions (70+) | goose | `POST /agent/add_extension` | Goose only | Med |
| Recipes | goose | `/recipe/*`, ACP | Goose only | Med |
| Scheduler | goose | `/schedule/*` | Goose only | Med |
| Multi-model providers (75+) | OpenCode (models.dev) | opencode server | OpenCode | Low |
| ACP subscription reuse (Claude/ChatGPT/Gemini) | goose | goose ACP providers | Goose | Med |
| Native toolbar pill nav | Owner signature | Swift shell | N/A | Low |
| Typewriter greeting landing | Owner signature | Swift + web landing | N/A | Low |
| All-chats grouped overlay | Owner signature | web overlay (rebuilt) | Both | Med |
| June-warm theme + derived gradient | Owner signature | theme generator | N/A | Low |
| Voice/TTS, skills catalog, scheduled tasks | OpenChamber | `packages/ui` advanced | OpenCode | Low |
| Cloudflare tunnel / remote SSH | OpenChamber | web server / electron | N/A | Low (likely disable for MAS) |
| Self-updater / PWA service worker | OpenChamber | `useUpdateStore`, vite-plugin-pwa | N/A | **Must stub** |
### (8) Top 10 Risks + Mitigations
1. **OpenChamber web server must stay alive** — PTY/fs/git live there, not in the opencode SDK. → Supervise it as a first-class process; not optional.
2. **@opencode-ai/sdk high churn** (v1.17.13, ~daily). → Pin as matched triple with OpenChamber tag + opencode binary; bump together only.
3. **goosed `/reply` streams whole Messages, not token deltas.** → Adapter synthesizes `message.part.updated`; accept coarser streaming or diff successive Messages.
4. **goosed has no global event bus** (SSE is per-`/reply`). → Adapter multiplexes per-session streams into one synthetic `event.subscribe()`.
5. **MAS private-API rejection** (custom scheme / `allowUniversalAccessFromFileURLs`). → Local-server topology avoids all private APIs; audit binary before submit.
6. **Sandbox limits goose's shell/dev tools.** → Security-scoped bookmark to user project dir; document reduced filesystem reach.
7. **goosed on deprecation path toward ACP-over-HTTP** (issue #6642). → Keep adapter transport layer swappable; ACP is the fallback/future.
8. **Goose sessions lack branch/worktree binding.** → Degrade to "main" group with engine badge; never fake a branch.
9. **PWA service worker caches stale SPA in embed.** → Disable `registerSW`/`autoUpdate` in vendored build.
10. **Upstream merge conflicts as OpenChamber moves fast** (v1.13.8 shipped 2026-06-28, frequent point releases). → Overlay discipline (new files only) + patch ledger keeps the conflict surface tiny.
### (9) Open Questions for the Owner
1. **Session list parity:** goosed exposes no paginated `GET /sessions` at the canonical path (verified NOT in `session::routes()`). Should the adapter enumerate goose sessions directly from its SQLite session store (`{data_dir}/sessions/sessions.db`), or accept a non-paginated client-side list for the all-chats sheet?
2. **ACP now or later?** goose's ACP JSON-RPC path (`crates/goose/src/acp/server.rs`) is the maintainers' declared future and the documented way to reuse Claude/ChatGPT/Gemini subscriptions. Build the Goose engine against REST `/reply` (works today) or invest early in the ACP transport?
3. **Tunnel/remote features:** OpenChamber ships Cloudflare tunnel + remote SSH. Keep (adds background-network entitlements + review scrutiny) or disable for the MAS build?
4. **goosed port capture:** confirm whether your pinned goosed binary honors `GOOSE_PORT` deterministically or picks a random port (the supervisor assumes env-honored port with a health-probe fallback). Verify against the exact binary version you bundle.
5. **June exact spec:** June's source isn't publicly locatable — can you provide reference screenshots/CSS for the message bar + gradient you want reproduced?
6. **1Code patterns to rebuild (UI-only, from OpenChamber primitives, no component copying):** (a) cooking/thinking-state animation, (b) message-queue reordering (note: OpenChamber already has drag-to-reorder queued messages), (c) diff-review polish. Confirm these three and that nothing is lifted directly from 1Code's Apache-2.0 tree (1Code is Electron + tRPC + Drizzle + Jotai/Zustand — architecturally different, study-only). Its chat/worktree surface is real (README confirms git-worktree-per-chat isolation, diff previews, built-in git client) but no `ActiveChat.tsx`/`agent-chat-store.ts` filenames could be independently verified in public source, so treat those specific filenames as unconfirmed.
---
*Verification legend: **verified-in-source** — repo file paths cited (OpenChamber `packages/ui`/`packages/web`, goose `crates/goose-server`, opencode `packages/opencode/src/server`); **verified via docs/issues** — DeepWiki, official docs, GitHub issues (#11616, #12453, #6642, #7225, #7596); **inferred** — the synthetic-event mapping and gradient formula are engineering proposals, not upstream code. Items needing manual follow-up on your bundled binaries: goosed exact route spellings in `action_required.rs` and `commands/agent.rs` (GitHub blob fetch was blocked; sourced from DeepWiki/OpenAPI), goosed `GOOSE_PORT` determinism, and the goose SQLite session-list path.*
