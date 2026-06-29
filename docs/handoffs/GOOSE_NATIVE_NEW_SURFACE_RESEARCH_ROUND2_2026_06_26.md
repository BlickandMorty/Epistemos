# Goose Native New Surface — Deep Research Round 2

> 🛑 **SUPERSEDED 2026-06-29 (Option 1 + Unification).** §7 GREEN-LIT; Plan 1 on Phase 1. **NO native chat / Gate-7
> flip / `useNativeChatPath` / native transcript** — chat + every Goose feature stays in the reskinned WebView,
> PERMANENTLY (native = frame + Models picker only). Native-chat build steps below are **HISTORICAL — do not build.**
> Canon: `docs/handoffs/GOOSE_NATIVE_UI_DECISION_2026_06_29.md` + `docs/research/EPISTEMOS_NATIVENESS_DOCTRINE_2026_06_29.md`.

**Date:** 2026-06-26
**Branch context:** `feat/goose-surface` (Goose module + interim WebView; native Agent surface not started)
**Mandate:** Research only — **no product code** (this pass is doc-only).
**Builds on:** `docs/handoffs/GOOSE_NATIVE_NEW_SURFACE_RESEARCH_ROUND1_2026_06_26.md`
**AppKit mapping:** `docs/handoffs/GOOSE_APPKIT_SURFACE_MAPPING_2026_06_26.md`
**Owner lock:** Unified **Agent** surface — full AppKit, greenfield 1:1 Goose mapping.

---

## Executive summary

Round 2 closes the highest-risk unknowns from Round 1's gap list:

1. **`goose serve` (Epistemos) ≠ `goosed agent` (Goose Electron).** Epistemos correctly spawns `goose serve` on loopback `:3284` with a **minimal HTTP surface** (ACP + health + MCP-app proxy). Goose Electron still spawns `goosed agent` (HTTPS REST on a random port) for legacy paths — chiefly **MCP Apps sampling**. The native Agent surface must be **ACP-first**; REST is legacy parity, not the v1 contract.

2. **OAuth for native AppKit is mostly delegated to goosed.** Provider auth runs inside the Goose subprocess via ACP `_goose/unstable/providers/config/authenticate`. Epistemos shows progress UI and never reimplements loopback/device-code servers in Swift for v1. Exceptions: paste-token/API-key providers and optional `ASWebAuthenticationSession` only if we later move auth out of goosed.

3. **Session persistence is SQLite under Goose data dir**, exportable as pretty JSON via ACP. Native session browser should call ACP list/load/export/import — not read `sessions.db` directly.

4. **Tool cards:** ACP `tool_call` / `tool_call_update` carry `kind`, `locations`, `rawOutput` (structured JSON), and `content` blocks. Goose **does not emit unified diff hunks** in tool results; native diff expanders must derive from `locations` + argument summaries + optional shell/git text — not assume `metadata.files[].diff`.

5. **`acp-meta.json` → Swift is feasible** by mirroring Goose's own pipeline (`generate_acp_schema.rs` → `acp-schema.json` + `acp-meta.json` → typed client). Recommend a build-phase codegen script pinned to the bundled Goose revision.

6. **Golden ACP fixtures** should be captured from `goose serve` + the existing TS adapter tests as the reducer contract.

---

## 1. goosed REST / API inventory

### 1.1 Two runtime shapes (critical distinction)

| Shape | Binary / command | Transport | Used by |
|-------|------------------|-----------|---------|
| **ACP server (Epistemos)** | `goose serve --host 127.0.0.1 --port 3284` | HTTP + WebSocket ACP | `GooseRuntimeSupervisor`, staged Web UI (ACP mode) |
| **REST server (Goose Electron legacy)** | `goosed agent` (HTTPS, random port) | OpenAPI REST (`goose-server` crate) | Goose Electron `goosed.ts`, MCP Apps sampling fallback |

Epistemos **must not** silently adopt the REST stack to "match Electron." ACP meta methods supersede REST for settings, sessions, recipes, schedules, providers, and extensions. REST remains relevant only for **MCP Apps `/sessions/{id}/sampling/message`** until ACP exposes sampling or Apps are deferred to v3.

**Source:** `crates/goose-cli/src/cli.rs` (`handle_serve_command`), `ui/desktop/src/goosed.ts` (`spawnArgs: ['agent']`), `Epistemos/Goose/GooseRuntimeSupervisor.swift` (`serveArguments`).

### 1.2 `goose serve` HTTP surface (Epistemos contract)

Router: `crates/goose/src/acp/transport/mod.rs` → `create_router`.

| Method | Path | Purpose |
|--------|------|---------|
| `GET` | `/health` | Readiness — body `ok` |
| `GET` | `/status` | Alias of `/health` |
| `GET` | `/acp` | WebSocket upgrade **or** SSE stream (see below) |
| `POST` | `/acp` | JSON-RPC forward (requires `Acp-Connection-Id`; session-scoped methods need `Acp-Session-Id`) |
| `DELETE` | `/acp` | Tear down connection |
| `GET` | `/mcp-app-proxy` | MCP App sandbox HTML shell (query: `secret`, CSP domain allowlists) |
| `POST` | `/mcp-app-guest` | Store guest HTML for MCP Apps (nonce + secret) |

**Auth:** When `GOOSE_SERVER__SECRET_KEY` is set, middleware `check_acp_token` accepts `X-Secret-Key` header **or** `?token=` query param (constant-time compare). WebSocket URL: `ws://127.0.0.1:3284/acp?token=…`.

**ACP transport modes:**
- **WebSocket** (Epistemos `GooseACPClient`) — primary.
- **HTTP POST + SSE GET** (`acp/transport/http.rs`) — batch-not-supported; `initialize` creates connection; notifications stream on GET with `Accept: text/event-stream`. Swift could add this as fallback; not required for v1.

**Scheduler:** `goose serve` lazily creates `Scheduler` inside `AcpServer` (`server_factory.rs`): `data_dir/schedule.json` + in-process cron. **No separate scheduler daemon.** ACP `_goose/unstable/schedules/*` is the native control plane.

**Default builtins:** `goose serve` defaults `builtins = ["developer"]` if none passed (matches Epistemos supervisor).

### 1.3 `goosed agent` REST surface (legacy — do not wire for v1 Agent)

Mounted via `goose-server/src/routes/mod.rs` → `configure()`. Grouped inventory:

| Module | Routes (representative) |
|--------|-------------------------|
| **status** | `GET /status`, `/system_info`, `/diagnostics/{session_id}` |
| **session** | `GET/PUT /sessions/{id}`, `/name`, `/fork`, `/share/nostr`, `/user_recipe_values`, … |
| **session_events** | `GET /sessions/{id}/events` (SSE), `POST /sessions/{id}/reply`, `/cancel` |
| **reply** | `POST /sessions/{id}/reply` (streaming chat — **superseded by ACP**) |
| **agent** | `/agent/start`, `/resume`, `/tools`, `/call_tool`, `/add_extension`, `/stop`, … |
| **config_management** | `/config`, `/config/providers`, `/config/extensions`, `/config/check_provider`, `/config/set_provider`, custom providers CRUD, permissions |
| **recipe** | `/recipes/list`, `/save`, `/parse`, `/scan`, `/schedule`, … |
| **schedule** | `/schedule/create`, `/list`, `/{id}/run_now`, `/pause`, `/kill`, … |
| **setup** | `POST /handle_openrouter`, `/handle_tetrate`, `/handle_nanogpt` (browser PKCE signup) |
| **sampling** | `POST /sessions/{id}/sampling/message` (**MCP Apps only**) |
| **dictation** | Dictation model download/transcribe REST |
| **tunnel** | `GET /tunnel/status` |
| **telemetry** | `POST /telemetry/event` |
| **gateway** | Gateway tunnel helpers |
| **mcp_ui_proxy / mcp_app_proxy** | Parallel to ACP-server proxies |

OpenAPI client: `ui/desktop/src/api/sdk.gen.ts` (generated from goose-server OpenAPI).

**Migration note:** Goose codebase comments (`server_factory.rs`) mark REST scheduler injection as temporary bridge during ACP migration. Epistemos should treat REST as **read-only reference**, not a dependency.

### 1.4 ACP extension RPC (the real Agent API)

From `crates/goose/acp-meta.json` (generated by `generate_acp_schema.rs`):

| Category | Count |
|----------|------:|
| Extension methods | **84** |
| Extension notifications | **1** (`_goose/unstable/session/update`) |
| Agent→client requests | **1** (`_goose/unstable/session/recipe/request-params`) |
| Stable (non-`_goose/unstable`) methods | **1** (`session/delete`) |

Domains (unchanged from Round 1, now counted): sessions, extensions, providers, tools, recipes, schedules, sources/skills, preferences, onboarding, diagnostics, dictation.

Standard ACP (Agent Client Protocol SDK) methods remain on the same WebSocket: `initialize`, `session/new`, `session/prompt`, `session/load`, `session/cancel`, `session/list`, permission + elicitation, etc.

---

## 2. OAuth per provider — native AppKit flows

### 2.1 Canonical native pattern (v1)

**Do not reimplement OAuth in Swift for Goose oauth providers.**

Flow:
1. User taps **Sign in** in Agent Settings › Auth/Models.
2. Swift calls ACP `_goose/unstable/providers/config/authenticate` with `{ providerId }`.
3. **goosed** calls `Provider::configure_oauth()` which:
   - Binds ephemeral localhost HTTP (or device-code polling),
   - Opens system browser (`webbrowser::open`),
   - Writes tokens to Goose config dir / keyring,
   - Returns `ProviderConfigChangeResponse` with refreshed status.

Native UI obligations:
- Show **in-progress** sheet (OAuth may take up to 300s — HF/xAI timeouts).
- Surface **manual URL** copy if browser open fails (goosed logs authorize URL).
- On success, refresh provider list via `_goose/unstable/providers/config/status`.
- **Never** store provider secrets in UserDefaults — Goose owns secret storage; Epistemos Keychain holds only `GOOSE_SERVER__SECRET_KEY` for loopback attestation.

**Implication:** `ASWebAuthenticationSession` is **optional v2** optimization, not v1 blocker. Loopback ports are owned by the goosed process, not the app — embedding ASWebAuthenticationSession without port coordination would race.

### 2.2 Provider-by-provider matrix

| Provider ID | Mechanism | Callback / poll | Token storage (under config dir) | Native UI v1 |
|-------------|-----------|-----------------|----------------------------------|--------------|
| **chatgpt_codex** | Loopback OAuth (OpenAI Codex) | `http://localhost:1455/auth/callback` | `chatgpt_codex/tokens.json` | ACP authenticate + spinner |
| **gemini_oauth** | Loopback OAuth + Code Assist setup | Dynamic `127.0.0.1:{port}/auth/callback` | Gemini OAuth + project id in config | ACP authenticate + spinner |
| **huggingface** | Loopback OAuth (HF CIMD client) | `http://127.0.0.1:17863/oauth/huggingface/callback` | `huggingface/oauth/tokens.json` | ACP authenticate + spinner |
| **xai_oauth** | Loopback → **fallback device code** | `127.0.0.1:56121/callback` or device poll | `xai_oauth/tokens.json` | ACP authenticate; show device code if fallback |
| **githubcopilot** | **Device code** (GitHub) | `https://github.com/login/device/code` | Keyring / `GITHUB_COPILOT_TOKEN` | ACP authenticate; display user-code URL |
| **kimicode** | **Device code** (Kimi) | `{auth_host}/api/oauth/device_authorization` | Kimi token cache JSON | ACP authenticate; display device instructions |
| **openrouter** | API key or **REST** `/handle_openrouter` PKCE (legacy) | localhost callback via setup route | Config key | v1: paste API key via `_goose/.../providers/config/save`; defer REST signup |
| **tetrate** | **REST** `/handle_tetrate` PKCE (legacy) | localhost callback | Config key | Same — prefer declarative API key if user has one |
| **MCP extensions** | OAuth 2.1 (rmcp) | `127.0.0.1:{ephemeral}/oauth_callback` | Goose credential store | Triggered on MCP connect failure — not Settings tab v1 |
| **Declarative gateways** (OpenRouter, Together, Groq, …) | **API key paste** | — | Goose secrets | Native secure field → ACP config save |
| **Anthropic / OpenAI API** | API key | — | Goose secrets | Secure text field |
| **Ollama / local** | None / local URL | — | — | URL + health row |
| **claude-acp / codex-acp / pi / copilot-acp** | External ACP binary auth | — | — | Status row + install docs (v3) |

**OAuth mutex:** Several providers (`xai`, `gemini`, `huggingface`) serialize concurrent OAuth with in-process mutex — UI should disable double-submit on Sign in.

**Port collision risk:** Codex `:1455`, HF `:17863`, xAI `:56121` are fixed. If another app binds the port, goosed returns actionable errors (xAI explicitly suggests device-code fallback).

### 2.3 AppKit UX recommendations

| Pattern | AppKit component | When |
|---------|------------------|------|
| ACP-driven OAuth | `NSProgressIndicator` + `NSAlert` informational sheet | Default for all `oauth_flow` providers |
| Device code | Non-editable `NSTextField` + **Copy** + **Open URL** (`NSWorkspace.open`) | Copilot, Kimi, xAI fallback |
| API key | `NSSecureTextField` in settings panel | Declarative + Anthropic/OpenAI |
| Manual URL | `NSTextField` (selectable) when goosed logs authorize link | Browser open failure |
| Auth failure | Honest error text from ACP JSON-RPC error `message` | Always |

**MAS:** OAuth + tool execution remain Pro/Developer-ID only (unchanged from Round 1).

---

## 3. Session persistence paths

### 3.1 On-disk layout (macOS)

Goose uses `etcetera` with app name **`Block/goose`** (historical — do not rename):

| Kind | Path |
|------|------|
| **Config** | `~/Library/Application Support/Block/goose/` — `config.yaml`, `secrets.yaml`, provider token dirs |
| **Data** | `~/Library/Application Support/Block/goose/` (data_dir) |
| **Sessions DB** | `{data_dir}/sessions/sessions.db` (SQLite WAL, schema v14) |
| **Schedule jobs** | `{data_dir}/schedule.json` |
| **Recipes** | `{data_dir}/recipes/` (scheduled recipe storage) |
| **State** | `{state_dir}` — request logs, ephemeral state |

Override for tests: `GOOSE_PATH_ROOT/{config,data,state}`.

**Source:** `crates/goose/src/config/paths.rs`, `session/session_manager.rs` (`SESSIONS_FOLDER`, `DB_NAME`).

### 3.2 Session record schema (logical)

`Session` struct (JSON export) includes:
- `id`, `name`, `user_set_name`, `session_type` (`user`, `scheduled`, `sub_agent`, …)
- `working_dir`, `provider_name`, `model_config`, `goose_mode`
- `conversation` (full message history when exported with load)
- `extension_data`, `recipe`, `usage`, `archived_at`, `project_id`, `last_message_snippet`, …

### 3.3 Native Agent access pattern

| Operation | Preferred API | Avoid |
|-----------|---------------|-------|
| List recent | ACP `session/list` with `_meta.types: ["user","scheduled"]` | Parsing SQLite |
| Load transcript | ACP `session/load` + replay `session/update` notifications | Reading JSON files |
| Rename / archive / delete | ACP `_goose/unstable/session/rename` etc. + `session/delete` | — |
| Export file | ACP `_goose/unstable/session/export` → JSON string → `NSSavePanel` | — |
| Import file | `NSOpenPanel` → ACP `_goose/unstable/session/import` | — |
| Share deep link | `goose://sessions/{token}` / Nostr (`session/nostr_share.rs`) | v3 |

Import pipeline normalizes foreign formats via `session/import_formats/` (Claude Desktop, Pi, etc.) before insert.

**Epistemos bridge (optional v2):** Mirror session id + title to `SDChat` worker rows for Landing recents — **not** required for v1.

---

## 4. Tool result shapes — diff / git / native cards

### 4.1 ACP wire format (authoritative)

Goose ACP server maps tool lifecycle to:

**`session/update` → `tool_call`** (start):
- `toolCallId`, `title` (LLM summary or deterministic fallback), `kind` (`read` | `edit` | `execute` | `other`), `status`, `rawInput`, `locations[]`, `_meta.goose.toolCall.{extensionName,toolName}`

**`session/update` → `tool_call_update`** (finish):
- `status`: `completed` | `failed`
- `rawOutput`: **`structured_content` JSON** when present (e.g. shell output object)
- `content[]`: `ToolCallContent` → text / image / embedded resource
- `locations[]`: file paths + optional line (from args or meta `tool_locations`)
- `_meta.goose.mcpApp`: MCP App UI attachment (resource URI)

**Permission requests** embed a `tool_call_update` preview in `session/request_permission`.

**Source:** `crates/goose/src/acp/server.rs` (`handle_tool_response`, `build_tool_call_content`, `extract_tool_locations`), `ui/desktop/src/acp/adapter/tools.ts`.

### 4.2 Developer extension (default builtin) — concrete shapes

| Tool | ACP `kind` | Result shape | Native card strategy |
|------|------------|--------------|---------------------|
| `developer__write` | `edit` | Text: `"Created/Wrote path (N lines)"` | Location chip + summary; **no diff hunks** |
| `developer__edit` | `edit` | Text: `"Edited path (N lines -> M lines)"` | Show `before/after` from **`rawInput`** in expander (not in result) |
| `developer__shell` | `execute` | `structured_content`: `{ stdout, stderr, exit_code, timed_out, … }` + text content | Mono block stdout/stderr; exit badge |
| `developer__tree` | `read` | Directory listing text | Collapsible tree summary |
| `developer__read_image` | `read` | Image content block | Thumbnail row |

**Important:** Goose developer tools **do not** populate unified diff strings. For Agent native cards:

1. **v1:** Title + kind icon + `locations` + truncated `content` text / `rawOutput` JSON pretty-print.
2. **v2:** For `edit`/`write`, render **argument diff** (parse `rawInput.before/after` or `path`+`content`) in a mono diff expander when both sides exist.
3. **Git/PR tools** (github MCP, shell): treat as **execute** — show shell output; link out for PR URLs detected in text.

### 4.3 TS adapter reference (golden semantics)

From `sessionNotificationAdapter.test.ts` — the reducer contract AgentTranscript must mirror:

```typescript
// tool_call → assistant message, toolRequest content
{ type: 'toolRequest', id, toolCall: { name, arguments }, metadata: { title, kind, locations, extensionName } }

// tool_call_update (completed) → user message, toolResponse content
{ type: 'toolResponse', id, toolResult: { status, value: { content[], isError, _meta? } }, metadata: { rawOutput, content } }
```

Failed tools: `toolResult.status === 'error'`; error string from `rawOutput` or content text.

### 4.4 MCP App tools

When `_meta.goose.mcpApp` present, Electron renders `McpAppRenderer` (WebView + optional REST sampling). **Native Agent v1:** show honest **"Interactive MCP App (Pro)"** placeholder with resource URI; defer hosted renderer to v3 (matches Round 1 R3).

---

## 5. `acp-meta.json` → Swift client feasibility

### 5.1 Upstream pipeline (already exists)

1. Rust: `cargo run --bin generate_acp_schema` → writes:
   - `crates/goose/acp-schema.json` (JSON Schema `$defs` + ExtRequest/Response anyOf)
   - `crates/goose/acp-meta.json` (method → request/response type names)
2. TS: `ui/sdk/generate-schema.ts` → `@hey-api/openapi-ts` → `types.gen.ts`, `zod.gen.ts`, `client.gen.ts` (`GooseExtClient`).

Types used only by unstable methods gain `_unstable` suffix (e.g. `ListProvidersRequest_unstable`).

### 5.2 Swift strategy (recommended)

| Approach | Verdict |
|----------|---------|
| **A. JSONValue + method table** (manual) | Works but error-prone at 84 methods — current Epistemos partial state |
| **B. Codegen from `acp-schema.json`** | **Recommended** — mirror TS pipeline |
| **C. UniFFI Rust client in app** | **Reject** (Round 1) — sidecar boundary |

**Implementation sketch (Gate 0 completion):**

1. Add `Scripts/generate-goose-acp-swift.sh`:
   - Run Goose `generate_acp_schema` at pinned revision.
   - Feed `acp-schema.json` to a Swift generator (options: `swift-openapi-generator`, quicktype, or custom template driven by `acp-meta.json`).
   - Emit into `Epistemos/Goose/Generated/`:
     - `GooseACPExtTypes.swift` (Codable structs)
     - `GooseACPExtMethod.swift` (enum of 84 method strings)
     - `GooseACPExtClient.swift` (thin wrapper over `GooseACPClient.sendRequest`)
2. Wrapper pattern:

```swift
// Pseudocode — not product code
func unstableListProviders() async throws -> ListProvidersResponse_unstable {
    try await extMethod("_goose/unstable/providers/list", params: ListProvidersRequest_unstable())
}
```

3. Pin generated output to Goose git SHA in manifest (`Resources/goose-revision.txt`).
4. CI: fail if meta hash drifts without regeneration.

### 5.3 Epistemos gap vs TS SDK

| Capability | TS `@aaif/goose-sdk` | Epistemos Swift today |
|------------|----------------------|------------------------|
| Standard ACP | ✅ | ✅ partial (`GooseACPProtocol.swift`) |
| 84 extension methods | ✅ `GooseExtClient` | ❌ |
| `_goose/unstable/session/update` notification | ✅ dispatcher | ❌ (only standard session/update kinds) |
| Recipe param agent request | ✅ | ❌ |
| Zod validation | ✅ | Need `#expect` decode tests instead |

**Client meta:** Swift already advertises `customNotifications` + `recipeParameterRequests` in `GooseACPClientCapabilities.epistemos` — matches TS.

### 5.4 Effort estimate

| Item | Size |
|------|------|
| Codegen script + types | ~1–2 days |
| `GooseACPExtClient` actor wrapper | ~0.5 day |
| Notification + agent-request handlers | ~1 day |
| Tests (decode + round-trip on fixtures) | ~1 day |

**Risk R1 (Round 1):** mitigated by pinning + codegen; manual drift is unsustainable at 84 methods.

---

## 6. Golden ACP fixtures — outline

### 6.1 Purpose

Deterministic **`AgentTranscript`** reducer tests without live goosed or WebView.

### 6.2 Capture procedure

1. Build pinned `goose serve` with mock/fixture provider (pattern: `crates/goose/tests/acp_fixtures/server.rs`).
2. Run scripted session:
   - `initialize` → `session/new` → `session/prompt`
   - Record **every** JSON-RPC message both directions (WebSocket tap or Rust test harness).
3. Redact secrets (token, API keys, home paths → `$HOME`).
4. Store as `EpistemosTests/Fixtures/GooseACP/*.jsonl` (one JSON object per line).

### 6.3 Required fixture set (minimum 5)

| # | Name | Covers |
|---|------|--------|
| **F1** | `simple_qa.jsonl` | User chunk → agent text chunks → `end_turn` |
| **F2** | `thinking_blocks.jsonl` | `agent_thought_chunk` separated from answer prose |
| **F3** | `tool_read_developer.jsonl` | `tool_call`/`tool_call_update`, `kind:read`, `locations` |
| **F4** | `tool_edit_permission.jsonl` | `session/request_permission` → allow once → completed edit |
| **F5** | `cancel_mid_stream.jsonl` | `session/cancel` or transport abort → partial transcript integrity |

**Stretch (v2):**
- **F6** `recipe_params.jsonl` — agent request `_goose/unstable/session/recipe/request-params`
- **F7** `goose_session_notification.jsonl` — custom `_goose/unstable/session/update`
- **F8** `session_load_replay.jsonl` — `session/load` notification burst

### 6.4 Test assertions (per fixture)

```swift
@Test func reducer_F3_toolRead() async throws {
    let events = try GooseACPFixture.load("tool_read_developer")
    var transcript = AgentTranscript()
    for event in events { transcript.reduce(event) }
    #expect(transcript.parts.contains { $0.kind == .tool && $0.toolStatus == .completed })
    #expect(!transcript.parts.contains { $0.kind == .answer && $0.text.contains("tool_call") })
}
```

**Reference tests to port:** `ui/desktop/src/acp/__tests__/sessionNotificationAdapter.test.ts` (tool mapping cases at lines 292–413).

### 6.5 Fixture manifest

```json
{
  "schemaVersion": 1,
  "gooseRevision": "<git-sha>",
  "acpMetaHash": "<blake3 of acp-meta.json>",
  "fixtures": [
    { "id": "F1", "file": "simple_qa.jsonl", "sessionCount": 1, "updateCount": 12 }
  ]
}
```

---

## 7. Round 2 — additional gaps closed

| Round 1 gap | Round 2 finding |
|-------------|-----------------|
| **MCP Apps route required v1?** | **No** — defer to v3; chat loop + developer tools cover v1 |
| **Scheduler daemon?** | In-process inside `goose serve`; ACP schedules API |
| **Extension bundling** | Default `developer` builtin; others user/MCP configured via ACP extensions |
| **Deep links** | `goose://sessions/…` + Nostr share — v3 Epistemos URL handler |
| **TS vs Swift parity** | See §5.3; priority = ext client + custom notification |
| **Git worktrees** | Electron `listGitWorktreeDirs` IPC only — **not** in ACP; native git or defer v3 |
| **Dictation** | ACP dictation methods exist — v3 Pro |
| **Security** | Token in query string: use header when possible; never log URL; Keychain for secret |
| **CI staging Web UI** | Unchanged from Round 1; separate from native Agent |
| **agent_core boundary** | Goose Agent surface ≠ Rust `agent_core` notes agent — document in Agent menu label |
| **Performance** | Cap transcript parts (200k chars per part); drain WS on background actor |
| **Accessibility** | VoiceOver: rail = `NSOutlineView`; tool cards = `NSDisclosureGroup` + labels from `title` |

---

## 8. Gate updates (implementation ladder)

| Gate | Round 2 delta |
|------|----------------|
| **Gate 0** | Add Swift codegen from `acp-meta.json`; golden fixtures F1–F5 |
| **Gate 2** | `AgentToolCardView` uses §4 shapes; no unified diff assumption |
| **Gate 4** | Provider auth via ACP authenticate — no Swift OAuth servers |
| **Gate 7** | WebView fallback only; REST sampling not wired in native |

---

## 9. Key file index (Round 2 additions)

| Topic | Path |
|-------|------|
| `goose serve` router | `.research-clones/work/goose/crates/goose/src/acp/transport/mod.rs` |
| ACP HTTP/SSE | `.research-clones/work/goose/crates/goose/src/acp/transport/http.rs` |
| REST router (legacy) | `.research-clones/work/goose/crates/goose-server/src/routes/mod.rs` |
| Electron goosed spawn | `.research-clones/work/goose/ui/desktop/src/goosed.ts` |
| Schema codegen | `.research-clones/work/goose/crates/goose/src/bin/generate_acp_schema.rs` |
| TS SDK codegen | `.research-clones/work/goose/ui/sdk/generate-schema.ts` |
| acp-meta (84 methods) | `.research-clones/work/goose/crates/goose/acp-meta.json` |
| Session SQLite | `.research-clones/work/goose/crates/goose/src/session/session_manager.rs` |
| Tool → ACP mapping | `.research-clones/work/goose/crates/goose/src/acp/server.rs` |
| TS tool adapter | `.research-clones/work/goose/ui/desktop/src/acp/adapter/tools.ts` |
| Tool adapter tests | `.research-clones/work/goose/ui/desktop/src/acp/__tests__/sessionNotificationAdapter.test.ts` |
| Developer tools | `.research-clones/work/goose/crates/goose/src/agents/platform_extensions/developer/` |
| OAuth HF | `.research-clones/work/goose/crates/goose/src/providers/huggingface_auth.rs` |
| OAuth Codex | `.research-clones/work/goose/crates/goose/src/providers/chatgpt_codex.rs` |
| Scheduler in serve | `.research-clones/work/goose/crates/goose/src/acp/server_factory.rs` |
| Epistemos supervisor | `Epistemos/Goose/GooseRuntimeSupervisor.swift` |
| Epistemos ACP types | `Epistemos/Goose/GooseACPProtocol.swift` |
| AppKit mapping | `docs/handoffs/GOOSE_APPKIT_SURFACE_MAPPING_2026_06_26.md` |

---

## 10. Round 3 candidates

1. Implement `Scripts/generate-goose-acp-swift.sh` + `GooseACPExtClient`.
2. Capture F1–F5 fixtures from local `goose serve` run.
3. Build `AgentTranscript` reducer with tests against fixtures.
4. Native `AgentPermissionSheet` + `AgentElicitationFormView` (already partially in WebView overlays).
5. Provider settings panel calling `_goose/unstable/providers/*` only.

---

*Round 2 complete. Doc-only — no product code modified.*
