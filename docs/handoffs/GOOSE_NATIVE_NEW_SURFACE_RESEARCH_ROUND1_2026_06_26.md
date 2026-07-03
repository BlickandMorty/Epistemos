# Goose Native New Surface — Deep Research Round 1

> 🔴 **SUPERSEDED 2026-07-02 (OpenChamber pivot) — DO NOT BUILD FROM THIS.** Research for the DEAD "native/reskin Goose surface" approach. The agent surface is now OpenChamber (Pro) / June+goose-in-process (MAS); goose = one engine. Historical reference only. Canon: memory `project_ui_base_pivot_openchamber_2026_07_02`.

> 🛑 **SUPERSEDED 2026-06-29 (Option 1 + Unification).** §7 GREEN-LIT; Plan 1 on Phase 1. **NO native chat, NO
> Gate-7 flip, NO `useNativeChatPath`, NO native transcript/hub/composer** — chat + every Goose feature stays in
> the **reskinned WebView, PERMANENTLY** (native = frame + Models picker only). Everything below describing native
> chat / Gates 0–7 as a build plan is **HISTORICAL — do not build it.** Canon:
> `docs/handoffs/GOOSE_NATIVE_UI_DECISION_2026_06_29.md` + `docs/research/EPISTEMOS_NATIVENESS_DOCTRINE_2026_06_29.md`.

**Date:** 2026-06-26
**Branch context:** `feat/goose-surface` (uncommitted Goose module + `EpistemosApp` menu wiring)
**Mandate:** Exhaustive research only — **no product code changes in this pass.**
**Owner lock:** Design a **whole new unified native AppKit Agent surface** that maps every Goose capability 1:1. See `docs/handoffs/GOOSE_APPKIT_SURFACE_MAPPING_2026_06_26.md` for screen-by-screen mapping.

**Supersedes for planning:** `docs/research/SURFACE_EMBEDDING_WEBVIEW_VS_NATIVE_DECISION_2026_06_25.md` §0–§14 federation tree (historical). Live canon: Goose-single + this Round 1 native-new-surface plan.

**Build authority (owner 2026-06-26):** Round 1 proves native *feasibility*; **`GOOSE_AGENT_APPKIT_FOLLOWON_PLAN` § Hybrid-by-route strategy** is the shipping shape — native chat path first, long-tail routes in embedded WebView until per-route gates. “100% native AppKit” here means capability parity via ACP, not all routes AppKit on day one.

---

## Executive summary

Goose is a **Rust agent runtime** (`goose serve` / `goosed`) exposing **ACP over WebSocket** (`/acp?token=…`) plus minimal **HTTP** (`/health`, `/status`). Its desktop UI is **Electron/React**, but the renderer already uses **`USE_ACP_CHAT`** — all agent traffic is ACP, not Electron IPC. Epistemos on `feat/goose-surface` has wired:

- `GooseRuntimeSupervisor` — spawns pinned `goose serve` on loopback `:3284`
- `GooseACPClient` / `GooseACPProtocol` — Swift ACP JSON-RPC types + WebSocket transport
- `GooseWebSurfaceView` — interim **WebView** host with boot shim + native permission/elicitation overlays
- `GooseWebBootShim.dispositionLedger` — 69 Electron affordances classified

**Round 1 conclusion:** A **100% native AppKit surface** is feasible because Goose's capability plane is **ACP-first**. The WebView path is a **transitional shell** (Gates 0–3); native parity (Gates 4–7) means replicating Goose's **navigation + settings + transcript reducer** in Swift while keeping **`goosed` subprocess forever** on Pro/Developer-ID builds. **UniFFI embedding of Goose into the app binary is rejected** — subprocess + ACP is the stable boundary (matches project no-hidden-sidecar doctrine).

**Proposed new surface name:** **Agent** (working title). Role: Epistemos's single agent command center — chat loop, tools, providers, extensions, recipes, schedules, sessions — native AppKit chrome over Goose ACP.

---

## Pass A — Goose source & docs

### A.1 Clone location & layout

| Path | Role |
|------|------|
| `.research-clones/work/goose/` | Full Goose monorepo (Rust + Electron UI + SDK) |
| `crates/goose/` | Agent core, ACP server, providers, extensions, recipes |
| `ui/desktop/` | Electron desktop app (React, HashRouter) |
| `ui/sdk/` | `@aaif/goose-sdk` TypeScript ACP client |
| `crates/goose/acp-meta.json` | Goose-specific ACP extensions (80+ methods) |
| `crates/goose/acp-schema.json` | Standard ACP schema |

### A.2 Desktop routes (`ui/desktop/src/App.tsx`)

Goose desktop uses **HashRouter** with nested routes under `/`:

| Route | Component | Purpose |
|-------|-----------|---------|
| `/` (index) | `Hub` | Empty-chat landing: clock + greeting + `ChatInput`; submit → `/pair` |
| `/pair` | `PairRouteWrapper` + `BaseChat` (via `AppLayout`) | Active chat session(s), LRU max 10 |
| `/settings` | `SettingsView` | 9-tab settings hub |
| `/extensions` | `ExtensionsView` | MCP/extension management |
| `/apps` | `AppsView` | Apps extension surface (gated by `apps` extension) |
| `/sessions` | `SessionsView` | Session history, import/export, archive |
| `/schedules` | `SchedulesView` | Recipe scheduler |
| `/recipes` | `RecipesView` | Recipe library + editor |
| `/skills` | `SkillsView` | Skills catalog |
| `/permission` | `PermissionSettingsView` | Tool permission rules |
| `/shared-session` | `SharedSessionView` | Deep-link shared sessions |
| `/launcher` | `LauncherView` | Quick launcher window |
| `/configure-providers` | `ProviderSettingsPage` | Full-screen provider setup |
| `/standalone-app` | `StandaloneAppView` | Standalone app chrome |

**Navigation rail** (`NavigationPanel.tsx`, `useNavigationItems.ts`):

1. New Chat (`/`)
2. Recipes (`/recipes`)
3. Skills (`/skills`)
4. Apps (`/apps`) — if extension enabled
5. Scheduler (`/schedules`)
6. Extensions (`/extensions`)
7. Session History (`/sessions`)
8. Settings (pinned bottom, `/settings`)

**Count:** 7 `NAV_ITEMS` + Settings pinned = **8 rail destinations** (matches mapping doc).

Recent chats list with inline rename (`acpRenameSession`), streaming/error/unread indicators.

### A.3 Settings tabs (9 visible)

From `SettingsView.tsx`:

| Tab ID | Label | Sections |
|--------|-------|----------|
| `models` | Models | Provider picker, model config (`ModelsSection`) |
| `local-inference` | Local Inference | HF/Ollama local models (feature-gated `localInference`) |
| `chat` | Chat | Modes, styles, tools, goosehints (`ChatSettingsSection`) |
| `sharing` | Session | Session sharing, external backend, gateway tunnel |
| `prompts` | Prompts | System prompt templates |
| `keyboard` | Keyboard | Shortcut editor |
| `auth` | Auth | OAuth/API key flows |
| `app` | App | Config YAML, updates, dock/menu, notifications, spellcheck, wakelock |

Deep-link sections map via `viewOptions.section` → tab (`models`, `chat`, `sharing`, `gateway`, `local-inference`, etc.).

### A.4 ACP transport (canonical agent path)

**Server** (`crates/goose/src/acp/transport/mod.rs`):

- `POST/GET/DELETE /acp` — ACP JSON-RPC over WebSocket upgrade
- `GET /health`, `GET /status` — readiness (`ok`)

**Desktop client** (`ui/desktop/src/acp/acpConnection.ts`):

- `window.electron.getAcpUrl()` → WebSocket URL
- `@aaif/goose-sdk` `GooseClient` with callbacks:
  - `requestPermission` → `permissionRequests.ts`
  - `unstable_createElicitation` → `elicitationRequests.ts`
  - `unstable_sessionRecipeRequestParams` → `recipeParamRequests.ts`
  - `sessionUpdate` / `unstable_sessionUpdate` → `chatNotifications.ts`

**Epistemos Swift mirror** (`Epistemos/Goose/GooseACPProtocol.swift`):

Standard methods: `initialize`, `session/new`, `session/prompt`, `session/update`, `session/request_permission`, `elicitation/create`.

Session update kinds: `user_message_chunk`, `agent_message_chunk`, `agent_thought_chunk`, `tool_call`, `tool_call_update`, `session_info_update`, `usage_update`.

Client meta advertises: `customNotifications: true`, `recipeParameterRequests: true`.

### A.5 Goose ACP extensions (`acp-meta.json` — grouped)

Beyond standard ACP, Goose adds **80+ `_goose/unstable/*` methods**. Round 1 inventory by domain:

| Domain | Example methods |
|--------|-----------------|
| **Sessions** | `session/delete`, `session/rename`, `session/archive`, `session/export`, `session/import`, `session/steer`, `session/info`, `session/conversation/truncate`, `session/working-dir/update` |
| **Extensions/MCP** | `config/extensions/list|add|remove|set-enabled`, `session/extensions/list|add|remove`, `extensions/available` |
| **Providers** | `providers/list`, `providers/catalog/list`, `providers/config/read|save|authenticate`, `providers/custom/create|read|update|delete`, `providers/inventory/refresh` |
| **Tools** | `tools/list`, `tools/call`, `resources/read` |
| **Recipes** | `recipes/list|save|delete|scan|parse|encode|decode|schedule|slash-command|to-yaml` |
| **Schedules** | `schedules/list|create|update|delete|pause|unpause|run-now`, `schedules/running-job/kill|inspect`, `schedules/sessions/list` |
| **Skills/Sources** | `sources/list|create|update|delete|export|import`, `agent-mentions/list`, `slash-commands/list` |
| **Preferences** | `preferences/read|save|remove`, `defaults/read|save` |
| **Onboarding** | `onboarding/import/scan|apply` |
| **Diagnostics** | `diagnostics/get` |
| **Dictation** | `dictation/transcribe|config`, model download/select/delete |
| **Notifications** | `_goose/unstable/session/update` (GooseSessionNotification) |
| **Agent requests** | `session/recipe/request-params` |

**REST beyond ACP:** OAuth callback routers per provider (Claude, Codex, HF, Gemini, xAI, etc.) — ephemeral localhost HTTP during auth flows, not general product REST.

### A.6 Provider catalog (first-class + declarative)

**ACP catalog providers** (`providers/*/claude_acp.rs`, `codex_acp.rs`, `copilot_acp.rs`, `pi_acp.rs`, `amp_acp.rs`): route through external ACP agent binaries.

**Native providers** (Rust `crates/goose/src/providers/`): Anthropic, OpenAI, Ollama, OpenRouter, Tetrate, Bedrock, LiteLLM, local inference (HF GGUF), GitHub Copilot, Gemini OAuth, xAI, Kimi, Snowflake, SageMaker, etc.

**Declarative JSON** (`providers/declarative/*.json`): 32+ third-party gateways (Together, Groq, DeepSeek, Mistral, LM Studio, Ollama Cloud, …).

Settings UI: `ModelsSection`, `ProviderSettingsPage`, `LocalInferenceSection`, `AuthSettingsSection`.

### A.7 Chat UI feature surface (`BaseChat.tsx`, `ChatInput.tsx`)

- Session load/replay, progressive message list
- Thinking blocks (separate from answer prose)
- Tool call cards + approval buttons (`ToolApprovalButtons.tsx`)
- Recipe header, parameter modals, security scan warnings
- File drop on composer
- Steer/cancel streaming (`useAcpChatSession`, `acpSteerSession`)
- Environment badge (working dir), session actions header
- Search within conversation (`SearchView`)
- MCP UI resource renderer (`MCPUIResourceRenderer.tsx`)
- Mention popover (`@` agent mentions, `/` slash commands via ACP autocomplete)

### A.8 `stage-goose-web-ui.sh` patches (Epistemos staging)

Build pipeline for **file-loadable** Goose Web UI artifact:

1. Rsync `ui/desktop` to temp work dir; symlink `node_modules`
2. Force `USE_ACP_CHAT = true` via `acpChatFeatureFlag.ts`
3. **OnboardingGuard bypass** when ACP chat enabled (skip Goose onboarding)
4. **Native bridge injection** into `permissionRequests.ts` + `elicitationRequests.ts`:
   - Calls `window.epistemos.goose.requestPermission` / `requestElicitation`
   - Falls back to Electron/modal path if bridge missing
5. Vite `base: './'` for relative asset paths
6. Manifest: `.epistemos-goose-webui.json` `{ schemaVersion: 1, acpMode: true }`
7. Output: `~/Library/Application Support/Epistemos/GooseWebUI/`

### A.9 `GooseWebBootShim.dispositionLedger` — full affordance list

69 keys in `Epistemos/Goose/GooseWebBootShim.swift`:

| Disposition | Affordances |
|-------------|-------------|
| **implemented-native** | `appConfig.get`, `appConfig.getAll`, `arch`, `broadcastThemeChange`, `getConfig`, `getSetting`, `setSetting`, `platform`, `getVersion` |
| **implemented-runtime** | `getGoosedHostPort`, `getSecretKey`, `getAcpUrl` |
| **hidden-shell** | `getUpdateState`, `isUsingGitHubFallback`, `getAutoDownloadDisabled`, `onUpdaterEvent`, `checkForUpdates`, `downloadUpdate`, `installUpdate`, `quitAndInstall` |
| **compatibility-preserved** | `reactReady`, `on`, `off`, `emit`, `logInfo`, `hideWindow`, `createChatWindow`, `closeWindow`, `showNotification`, `setWindowTitle`, `reloadApp`, `checkForOllama`, `getAllowedExtensions`, `getPathForFile`, `listFiles`, `addRecentDir`, `listRecentDirs`, `listGitWorktreeDirs`, menu/dock/wakelock/spellcheck/focus/back-button/recipe-hash stubs |
| **deferred-with-visible-error** | `showOpenDialog`, `showSaveDialog`, `showMessageBox`, `directoryChooser`, `selectFileOrDirectory`, `selectImportSessionFile`, `openExternal`, `openInChrome`, `openDirectoryInExplorer`, `getBinaryPath`, `readFile`, `writeFile`, `ensureDirectory`, `launchApp`, `refreshApp`, `closeApp`, `openNotificationsSettings` |

**Gap:** All file/dialog/OS affordances throw visible errors today — blocks recipes import, working-dir picker, session file import, external links until native `NSOpenPanel`/`NSSavePanel`/`NSWorkspace` wiring.

### A.10 Epistemos Goose module inventory (`Epistemos/Goose/`)

| File | Role |
|------|------|
| `GooseRuntimeSupervisor.swift` | Spawn `goose serve`, health gate, MAS unavailable |
| `GooseACPProtocol.swift` | ACP types (mirror of `@agentclientprotocol/sdk`) |
| `GooseACPClient.swift` | WebSocket transport + JSON-RPC loop |
| `GooseACPEventBridge.swift` | `@Observable` session updates + permission/elicitation prompts |
| `GooseWebBootShim.swift` | `window.electron` + `window.epistemos.goose` injection |
| `GooseWebNativePromptBridge.swift` | WKScriptMessageHandler for permission/elicitation |
| `GooseWebSurfaceView.swift` | SwiftUI `WebView`/`WebPage` host + diagnostics panel |
| `GooseWebUIResolver.swift` | Staged UI artifact discovery |
| `GooseSurfaceStyle.swift` | Theme tokens for Goose chrome |
| `GooseSurfaceWindowController.swift` | Standalone utility window (`WindowThemeStyler`) |

**Entry:** `EpistemosApp.swift` menu "Open Epistemos Goose" → `GooseSurfaceWindowController.shared.open()` (Pro gate on MAS).

**Tests:** `GooseRuntimeSupervisorTests.swift`, `GooseACPClientTests.swift`.

---

## Pass B — Epistemos native assets

### B.1 Theme system

**`EpistemosTheme`** (`Epistemos/Theme/EpistemosTheme.swift`):

- 12 themes (Platinum Violet default pair, OLED/OLED-soft, ember, nocturne, …)
- `ResolvedTheme` semantic tokens: `background`, `card`, `chatSurface`, `border`, `accent`, `mutedForeground`, …
- `surfaceVariant(.landing | .mainChat | .other)` — per-surface overrides
- `ClaudeAppTypography.monoFont` (JetBrains Mono) + `assistantFont` (Anthropic Sans)

**`WindowThemeStyler`** (`Epistemos/App/UtilityWindowManager.swift`):

- `themedContentView(host:uiState:)` — NSVisualEffectView backdrop when `usesNativeWindowBlur`
- Applied by `GooseSurfaceWindowController`, note windows, Work surfaces

**`GooseSurfaceStyle`** (`Epistemos/Goose/GooseSurfaceStyle.swift`):

- Maps `EpistemosTheme` → canvas/rail backgrounds (card/chatSurface blend)
- `bodyFont` → JetBrains Mono for Goose-native diagnostics/overlays

**Pattern for new surface:** Read `@Environment(UIState.self) var ui` → `ui.theme.surfaceVariant(.mainChat)`; flat `theme.card` + 1px `theme.border` (OpenCode-minimal per handoffs); **no default `.glassEffect`** on agent chrome.

### B.2 Transcript reducer pattern (new Agent surface components)

Build **`AgentTranscript`** (new type) as a pure deterministic reducer of **ACP `session/update` notifications** (`GooseACPSessionUpdate`) → `@Observable` parts:

- Part kinds: `.user`, `.answer`, `.thinking`, `.tool`, `.error`
- Tool cards: name + status + summary (never raw tool I/O as prose)
- `seenSeq` de-dupe, bounded text
- `replay(history:)` for session restore
- Separation discipline: thinking ≠ answer, tool cards ≠ prose

See `GOOSE_APPKIT_SURFACE_MAPPING_2026_06_26.md` §B.2 for row-level component names.

### B.3 LandingView & shell (`Epistemos/Views/Landing/LandingView.swift`)

- Deliberate command tiles (not "tap anywhere → chat")
- Farm/companion overlays, daily brief, workspace switcher
- `LandingViewStateSync.reassertHomeSurface` — home tab authority
- Theme: `ui.theme.surfaceVariant(.landing)`
- **Integration point for new surface:** Landing tile or keyboard shortcut → open **Agent** surface (utility window or embedded panel), passing optional draft prompt — **not** auto-submit

### B.4 Note editor AppKit patterns (`ProseTextView2`)

Reference for **native text fidelity** in agent surface composer/transcript:

- `ProseTextView2: NSTextView` + TextKit 2 (`NSTextLayoutManager`)
- `MarkdownContentStorage` delegate for structural styling
- Theme-aware solid backgrounds (`editorBackgroundColor`, no accidental blur bleed)
- `ScrollWorkCoalescer` — debounced scroll work
- Coordinator debounce 300ms for binding sync
- **Applicable to Agent surface:** Use `NSTextView`/`NSTextField` for composer; `AttributedString` or custom `NSTextLayoutManager` for markdown transcript; avoid WKWebView for message list in native target

### B.5 Current feat/goose-surface state

| Asset | Status |
|-------|--------|
| Goose subprocess supervisor | ✅ Implemented + tested |
| ACP client (Swift) | ✅ Core loop; no Goose extended methods yet |
| WebView interim surface | ✅ With native permission/elicitation overlays |
| Boot shim disposition ledger | ✅ 69/69 keys classified |
| Staged Goose Web UI script | ✅ `stage-goose-web-ui.sh` |
| Native AppKit Agent surface | ❌ Not started |
| Landing → Agent entry | ❌ Menu only (`Open Epistemos Goose`) |
| MAS build | ❌ Goose blocked (`#if EPISTEMOS_APP_STORE`) |

---

## Pass C — Complete capability matrix

Legend: **Priority** v1 = ship native feel MVP, v2 = full parity, v3 = polish/advanced. **Auto/Manual** = whether Goose/goosed can run unattended vs needs native UI.

| Feature group | Feature | Data source | Native AppKit component | New surface placement | Priority | Auto vs manual |
|---------------|---------|-------------|-------------------------|----------------------|----------|----------------|
| **Chat loop** | New session | ACP `session/new` | `AgentSessionController` actor | Rail → New | v1 | Auto |
| | Prompt + stream | ACP `session/prompt` + `session/update` chunks | `AgentTranscript` + `AgentTranscriptView` (NSTableView/ScrollView) | Center canvas | v1 | Auto |
| | Steer mid-run | ACP `_goose/.../session/steer` | Composer send while streaming | Composer bar | v2 | Auto |
| | Cancel/stop | ACP cancel + client abort | Stop button → transport close / cancel RPC | Composer trailing | v1 | Manual |
| | Multi-session LRU | ACP session list + local cache | `AgentSessionRail` (NSOutlineView/SwiftUI List) | Left rail | v2 | Auto |
| **Thinking** | Thought chunks | ACP `agent_thought_chunk` | Collapsible `AgentThinkingRow` (disclosure) | Transcript | v1 | Auto |
| | Preserve in history | Session load meta | Same row, persisted | Transcript | v2 | Auto |
| **Tools** | Tool call cards | ACP `tool_call` / `tool_call_update` | `AgentToolCardView` (flat mono card) | Transcript | v1 | Auto |
| | Tool kinds (read/edit/execute/…) | ACP `kind` enum | Icon + label map | Tool card | v1 | Auto |
| | MCP tool execution | Goose agent + MCP | Cards only — no raw JSON | Transcript | v1 | Auto |
| **Permissions** | Tool approval | ACP `session/request_permission` | `AgentPermissionSheet` (NSAlert/NSPanel) | Modal overlay | v1 | Manual |
| | Allow once/always/reject | ACP permission options | Four-button sheet | Modal | v1 | Manual |
| | Permission rules UI | Settings + ACP extensions | `AgentPermissionSettingsView` | Settings tab | v2 | Manual |
| **Elicitation** | Form elicitation | ACP `elicitation/create` | `AgentElicitationFormView` (dynamic fields from JSON schema) | Modal | v1 | Manual |
| | Recipe params | ACP `session/recipe/request-params` | Same form engine | Modal | v2 | Manual |
| | URL mode | ACP elicitation `mode: url` | `SFSafariViewController` / open URL | External | v3 | Manual |
| **Providers** | Provider list | ACP `_goose/.../providers/list` | `AgentProviderListView` | Settings › Models | v2 | Manual |
| | HF inference | Provider config + OAuth | `AgentProviderAuthFlow` (OAuth loopback) | Settings sheet | v2 | Manual |
| | Ollama/local | `LocalInferenceSection` parity | Native settings + health row | Settings › Local | v2 | Manual |
| | Claude ACP | `claude-acp` provider | Provider row + external binary status | Settings | v3 | Manual |
| | Codex ACP | `codex-acp` provider | Same | Settings | v3 | Manual |
| | ACP catalog (Pi, Copilot, Amp) | Declarative providers | Catalog list + configure | Settings | v3 | Manual |
| | OpenRouter/Tetrate/… | Declarative JSON providers | Template-driven form | Settings | v3 | Manual |
| **Model picker** | Session model | Session meta `modelId` | `AgentModelPickerPopover` (NSPopover) | Composer header | v1 | Manual |
| | Switch mid-session | ACP session update / config | Picker + confirm | Composer | v2 | Manual |
| **Extensions** | Global extensions | ACP `config/extensions/*` | `AgentExtensionsView` | Rail › Extensions | v2 | Manual |
| | Session extensions | ACP `session/extensions/*` | Toggle list in session header | Session chrome | v2 | Manual |
| | Install modal | Deep link + ACP | `AgentExtensionInstallSheet` | Modal | v3 | Manual |
| **MCP** | Server lifecycle | Goose `extension_manager.rs` | Status rows only in UI | Extensions | v2 | Auto |
| | MCP UI resources | Goose renderer widget | **v3:** native placeholder or hosted panel | Side panel | v3 | Manual |
| **Skills** | Skills list | ACP `sources/list` (skills) | `AgentSkillsView` | Rail › Skills | v2 | Manual |
| | Slash commands | ACP `slash-commands/list` | Composer `/` menu | Composer | v2 | Auto |
| **Recipes** | Recipe library | ACP `recipes/list` | `AgentRecipesView` | Rail › Recipes | v2 | Manual |
| | Create/edit | ACP `recipes/save`, YAML editor | `AgentRecipeEditorView` (NSTextView) | Modal/window | v3 | Manual |
| | Run recipe | Session create w/ recipe meta | Hub-style start | Rail › New | v2 | Manual |
| | Recipe security scan | ACP `recipes/scan` | Warning sheet | Pre-run | v2 | Auto |
| **Schedules** | List/create/edit | ACP `schedules/*` | `AgentSchedulesView` | Rail › Scheduler | v3 | Manual |
| | Run now / kill job | ACP `run-now`, `kill` | Buttons + status | Scheduler detail | v3 | Manual |
| **Sessions** | Recent list | ACP list + `_meta` | `AgentSessionRail` | Left rail | v1 | Auto |
| | Rename | ACP `session/rename` | Inline edit (like NavigationPanel) | Rail | v2 | Manual |
| | Archive/delete | ACP archive/delete | Context menu | Rail | v2 | Manual |
| | Import/export | ACP + **native file dialog** | `NSOpenPanel`/`NSSavePanel` | Sessions view | v2 | Manual |
| | Shared/deep link | Session sharing config | Epistemos URL scheme handler | External | v3 | Manual |
| **Diff/git/PR** | Working dir badge | Session `cwd` | `AgentEnvironmentBadge` | Session header | v1 | Auto |
| | Git worktrees | Shim `listGitWorktreeDirs` (stub) | Native git scan or ACP extension | Settings/debug | v3 | Manual |
| | File diffs in tool cards | Tool result content | Diff rows in tool card expander | Tool card expand | v2 | Auto |
| | PR creation | Goose tools (if extension) | Tool card + link out | Transcript | v3 | Auto |
| **Settings** | Models tab | ACP providers | Native tab view | Settings | v2 | Manual |
| | Local inference tab | ACP + HF | Native tab | Settings | v2 | Manual |
| | Chat tab | Preferences ACP | Native tab | Settings | v2 | Manual |
| | Session/sharing tab | Preferences + tunnel | Native tab | Settings | v3 | Manual |
| | Prompts tab | ACP defaults | Native tab | Settings | v3 | Manual |
| | Keyboard tab | Epistemos keychain | `Settings` + local override store | Settings | v2 | Manual |
| | Auth tab | OAuth flows | WebAuth/paste token | Settings | v2 | Manual |
| | App tab | Shim settings + goose config | Native tab | Settings | v2 | Manual |
| **Onboarding** | First-run | ACP `onboarding/import/*` | Epistemos setup assistant | App onboarding | v3 | Manual |
| | Claude Desktop import | Onboarding scan | One-shot wizard | Onboarding | v3 | Manual |
| **Terminal** | Embedded terminal | Not in Goose UI core | **Optional v3:** `WorkTerminalView` pattern or omit | Bottom drawer | v3 | Manual |
| **Worktrees** | Recent dirs | Shim + ACP cwd update | `NSOpenPanel` + `acpUpdateWorkingDir` | Session header | v2 | Manual |
| **Notifications** | Agent complete | ACP custom notifications + `UNUserNotificationCenter` | Native notification | Background | v2 | Auto |
| | Recipe complete | Schedule webhook/internal | Same | Background | v3 | Auto |
| **File dialogs** | Open/save/import | **Native only** (shim deferred) | `NSOpenPanel`/`NSSavePanel` | System | v1 | Manual |
| | Open external URL | **Native** `NSWorkspace.open` | System browser | System | v1 | Manual |
| **Custom notifications meta** | Session update meta | `_goose/unstable/session/update` | Transcript side-effects (title, token counts) | Status bar | v2 | Auto |
| **Hub/home** | Empty state | Local | `AgentHubView` (clock + greeting + composer) | Default route | v1 | Manual |
| **Apps extension** | Standalone apps | Goose Apps route | Separate window controller | Rail › Apps | v3 | Manual |
| **Diagnostics** | Health/report | ACP `diagnostics/get` + `/health` | Settings debug row | Settings › App | v2 | Auto |
| **Dictation** | Voice input | ACP dictation methods | Composer mic + model download UI | Composer | v3 | Manual |
| **Telemetry** | Consent/analytics | Goose telemetry modules | Honest opt-in row or strip | Settings | v3 | Manual |
| **Updater** | Self-update | **Hidden** in Epistemos | None — app-level versioning | N/A | N/A | N/A |

---

## Pass D — NEW surface architecture

### D.1 Name and role

**Name:** **Agent** (internal: `AgentSurface`; user-visible: "Agent" or "Epistemos Agent")

**Role:** The single post-landing agent command center for Epistemos. It owns:

- Conversational agent loop (Goose via ACP)
- Provider/model configuration surfaces
- Extensions, skills, recipes, schedules
- Session history and working directory context
- Permission/elicitation UX

It does **not** own: note editing (Notes/Epdoc), graph physics (Graph), vault sync (Sync), or local MLX inference (removed from main app — Goose handles cloud/local inference via its providers).

### D.2 Navigation model

```
┌─────────────────────────────────────────────────────────────┐
│  Epistemos main window (Landing / Notes / Graph — unchanged) │
│  [Landing] [Notes] [Graph] …                    [Open Agent]  │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  Agent Surface (utility window OR embedded inspector)        │
│ ┌──────────┬──────────────────────────────────────────────┐ │
│ │ Rail     │  Hub / Transcript canvas                      │ │
│ │          │  ┌────────────────────────────────────────┐ │ │
│ │ • Hub    │  │ AgentTranscriptView (native)           │ │ │
│ │ • Recipes│  │  user / thinking / answer / tool rows  │ │ │
│ │ • Skills │  └────────────────────────────────────────┘ │ │
│ │ • Sched  │  ┌────────────────────────────────────────┐ │ │
│ │ • Ext    │  │ AgentComposerBar (NSTextView + attachments)│ │
│ │ • History│  └────────────────────────────────────────┘ │ │
│ │          │  Status: model · cwd · stream · tokens       │ │
│ │ ──────── │                                               │ │
│ │ Settings │                                               │ │
│ └──────────┴──────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

**Modes:** Optional **session mode** (Goose `GooseMode`) is a **per-session** attribute, not a global landing mode.

**Implementation shape:** `AgentSurfaceWindowController` (mirror `GooseSurfaceWindowController`) hosting `AgentSurfaceRootView` — pure SwiftUI + AppKit representables, **no React**.

### D.3 Relationship to Landing, Notes, Graph

| Shell area | Relationship |
|------------|--------------|
| **Landing** | Primary entry: "Agent" tile opens surface with optional draft; no auto-submit. Recents may show agent sessions (future: bridge Goose session IDs ↔ `SDChat` worker rows if desired). |
| **Notes** | `@` mention → attach vault paths via Epistemos bridge (`epistemos.context.snapshot`); open note in separate window. |
| **Graph** | Optional context attach (selected node → prompt attachment). |
| **Settings** | Epistemos Settings keeps vault/models health; Agent Settings owns Goose provider/auth (in-surface tab). |

### D.4 Transitional WebView & non-goals

| Asset | Role |
|-------|------|
| **Goose WebView** (`GooseWebSurfaceView`) | **Transitional** (Gate 0–3) for full-window proof. Post Gate 7: **chat path native**; long-tail routes use **embedded WebView panel** in Agent window until per-route flip; full-window copy = regression compare only. See follow-on plan § Hybrid-by-route strategy. |
| **New Agent surface** | Greenfield AppKit components per `GOOSE_APPKIT_SURFACE_MAPPING_2026_06_26.md`. |

### D.5 MAS vs Pro honest gating

| Capability | MAS | Pro / Developer-ID |
|------------|-----|---------------------|
| Agent surface visible | ❌ Hidden or "Pro only" placeholder | ✅ |
| `goose serve` subprocess | ❌ `#if EPISTEMOS_APP_STORE` blocks | ✅ |
| Tool execution (shell, MCP servers) | ❌ | ✅ |
| Cloud providers (API keys) | ❌ or read-only docs | ✅ Keychain |
| Local inference (HF/Ollama) | ❌ | ✅ |
| External URL / file dialogs | Limited sandbox | ✅ Full panels |

**Honesty rule:** MAS build shows explicit "Agent requires Epistemos Pro" — never fake streaming or stub tools.

---

## Pass E — Implementation ladder (Gates 0–7, new surface only)

### Gate 0 — Runtime proof (✅ mostly done)

- [x] `goose serve` on loopback `:3284`, `/health` == `ok`
- [x] ACP WebSocket URL with token
- [x] Swift `GooseACPClient.initialize/newSession/prompt`
- [x] Receive `session/update` notifications
- [ ] Wire **Goose extended ACP** RPC wrapper (meta methods) — Round 2

### Gate 1 — Transitional WebView (✅ current feat/goose-surface)

- [x] Stage Goose UI (`stage-goose-web-ui.sh`)
- [x] Boot shim + disposition ledger
- [x] Native permission/elicitation overlays
- [ ] Implement **deferred** shim affordances (file dialogs, openExternal)

### Gate 2 — Native feel MVP (v1 target)

Build first for **native feel**:

1. **`AgentTranscript`** — ACP event reducer (new Agent surface component)
2. **`AgentTranscriptView`** — scrollable native transcript (SwiftUI + AppKit text)
3. **`AgentComposerBar`** — mono composer, send/stop, model badge
4. **`AgentPermissionSheet` / `AgentElicitationFormView`** — port from `GooseWebSurfaceView` panels
5. **`AgentSessionController`** — owns `GooseACPClient`, session id, stream task
6. **`AgentSurfaceWindowController`** — utility window, `WindowThemeStyler`, theme injection
7. **Landing entry** — tile + ⌘⇧A (or similar) opening Agent with draft handoff
8. **File dialogs** — replace shim stubs for cwd picker + session import

**Can stay WebView until Gate 4:** Recipes editor YAML, Apps extension, MCP UI resource renderer, full provider OAuth web flows (use temporary embedded web sheet).

### Gate 3 — Navigation parity

- Rail: Hub, History, Extensions, Settings (subset)
- Session rail with rename/archive
- Hub empty state (clock + greeting)

### Gate 4 — Settings & providers (v2)

- Native Models/Auth/Chat/App tabs calling ACP `_goose/unstable/providers/*` + preferences
- Keychain storage for secrets (never UserDefaults)

### Gate 5 — Recipes, skills, schedules (v2–v3)

- Recipes list/run; schedule viewer
- Skills/sources management

### Gate 6 — Epistemos bridge

- `epistemos.context.snapshot` — vault note attachments, graph selection
- Optional: persist session index to `SDChat` worker rows for Landing recents

### Gate 7 — Native chat primary (hybrid long-tail)

- Feature flag `AgentSurface.useNativeChatPath = true` — native hub + session + transcript + composer + permission/elicitation as default
- **Per-route WebView flags** remain for long-tail (Skills, Recipes, Extensions, Scheduler, Apps, shared-session, unproven settings tabs) until each route earns native gate
- Full-window WebView fallback kept for **regression compare only** — not long-tail product UI

> **Owner canon (2026-06-26):** Gate 7 retires WebView as **primary for chat only**. Embedded WebView in the Agent content area for unflipped long-tail routes is **intentional hybrid UI**, not Phase 0 debt. See `docs/handoffs/GOOSE_AGENT_APPKIT_FOLLOWON_PLAN_2026_06_26.md` § Hybrid-by-route strategy.

### What stays `goosed` subprocess forever

| Component | Rationale |
|-----------|-----------|
| **`goose serve` binary** | Rust agent loop, tool execution, MCP, providers — **not** compiled into app |
| **Provider SDK calls** | Claude/OpenAI/HF inside Goose |
| **MCP server processes** | Extension model |
| **Recipe scheduler** | Background jobs in Goose |
| **OAuth callback servers** | Ephemeral localhost in Goose |

### UniFFI: reject / accept

| Approach | Verdict |
|----------|---------|
| **UniFFI embed `goose` crate in app** | **REJECT** — violates no-hidden-sidecar, balloons binary, MAS-impossible tool spawn |
| **Subprocess + ACP WebSocket** | **ACCEPT** — matches Goose desktop architecture, tested in Epistemos |
| **UniFFI for transcript/settings only** | **REJECT** — no Rust FFI needed; Swift owns UI |
| **Rust `agent_core` for Epistemos notes agent** | **Out of scope** — separate from Goose Agent surface |

---

## Pass F — Parity proof contract

### Definition of done — "100% native Goose in Epistemos Agent surface"

1. **Runtime:** Pro build spawns `goose serve`; MAS shows honest gate — no silent failure.
2. **Transport:** All agent operations use ACP (standard + required `_goose/unstable/*` subset); no Electron IPC; no hidden HTTP to non-loopback.
3. **UI:** Zero React/Electron in Agent surface window — AppKit/SwiftUI only.
4. **Loop:** new session → prompt → stream (thinking + answer + tools) → permission → result → end_turn; cancel mid-stream.
5. **Coverage:** Every row in Pass C matrix marked v1–v2 is implemented or explicitly deferred with visible UI message.
6. **Shim:** No `deferred-with-visible-error` affordance on critical paths (file dialogs, external links, cwd).
7. **Theme:** Agent surface respects `EpistemosTheme` at first paint; mono labels; flat borders.
8. **Isolation:** Notes/Graph/Landing unchanged; Agent surface is greenfield AppKit only.
9. **Tests:** Swift tests for transcript reducer, ACP client, permission round-trip; witness tests for disposition.
10. **Fallback:** Goose WebView path still opens for regression compare.

### WRV script outline

```bash
#!/bin/bash
# WRV: Agent native surface — Goose parity
set -euo pipefail

# 1. Build
xcodebuild -scheme Epistemos -destination 'platform=macOS' build 2>&1 | xcbeautify

# 2. Unit tests (Agent module)
xcodebuild -scheme Epistemos -destination 'platform=macOS' \
  -only-testing:EpistemosTests/AgentTranscriptTests \
  -only-testing:EpistemosTests/GooseACPClientTests \
  -only-testing:EpistemosTests/GooseRuntimeSupervisorTests test 2>&1 | xcbeautify

# 3. Stage Goose UI (fallback path)
bash stage-goose-web-ui.sh

# 4. Manual runtime checklist (Pro build)
# - Open Landing → Agent tile
# - Verify goose serve health in Settings debug
# - New session, send prompt, observe native transcript streaming
# - Trigger tool → permission sheet → allow once
# - Change working directory via native folder picker
# - Open Settings › Models — provider list loads
# - Rename session in rail
# - Compare same flow in Goose WebView fallback — output parity

# 5. MAS build smoke — Agent gate visible, no subprocess spawn
# xcodebuild ... CODE_SIGN_IDENTITY=... EPISTEMOS_APP_STORE=1
```

### Risk register

| ID | Risk | Severity | Mitigation |
|----|------|----------|------------|
| R1 | Goose ACP meta methods diverge from Swift client | High | Generate Swift stubs from `acp-meta.json`; pin Goose revision |
| R2 | OAuth provider flows assume Electron browser | Medium | **v1:** delegate to goosed via ACP `providers/config/authenticate` (Round 2); optional `ASWebAuthenticationSession` only if auth moves out of goosed |
| R3 | MCP UI resources require web renderer | Medium | Defer to v3; show tool text fallback |
| R4 | File dialog shim gaps block recipes/sessions | High | Gate 2 priority — native panels |
| R5 | MAS cannot spawn goose — user confusion | Medium | Honest Pro gate copy; no fake agent |
| R6 | Session store mismatch (Goose vs SDChat) | Low | Optional mirror layer; don't block v1 |
| R7 | WebView team continues on shim while native lags | Medium | Hybrid-by-route: native chat on schedule; long-tail WebView per-route flags with dated flip criteria (follow-on plan) |
| R8 | Owner scope creep beyond Goose 1:1 mapping | High | Agent surface mapping doc + code review gate |
| R9 | ACP protocol version drift (`agent-client-protocol 0.11/0.12`) | Medium | Pin Cargo.lock; integration test on bump |
| R10 | Transcript reducer bugs (thinking merged into answer) | High | Golden ACP fixtures + `AgentTranscript` unit tests |

---

## Round 2 gaps — explicit investigation list

1. **Generate Swift ACP meta client** from `crates/goose/acp-meta.json` — full RPC surface area + type mapping.
2. **OAuth flow map** per provider (Claude, Codex, HF, Gemini, OpenRouter, Tetrate) — which need web sheet vs device code vs paste token.
3. **Goose session persistence format** on disk — path, schema, import/export bytes for native session browser without WebView.
4. **Tool result payload shapes** — sample ACP traces for diff/git/PR tools to design `AgentToolCardView` expanders.
5. **MCP Apps extension** — is Apps route required for v1 parity or Pro-only optional?
6. **Scheduler daemon lifecycle** — does `goose serve` alone run schedules or separate process?
7. **Extension binary bundling** — which MCP servers ship with Epistemos Pro bundle vs user-installed.
8. **Deep link / session sharing** — `goose://sessions/…` handling in Epistemos URL scheme.
9. **Compare `@aaif/goose-sdk` TypeScript** vs Swift client — identify missing callback parity (`chatNotifications`, `recipeParamRequests`, custom notifications).
10. **Performance budget** — transcript row count limits, WebSocket backpressure, main-actor isolation audit.
11. **Accessibility** — VoiceOver map for Agent rail + tool cards + permission sheets.
12. **Landing recents integration** — whether to revive `SDChat` worker rows for Agent sessions or Goose-native list only.
13. **Git worktree UX** — does Goose expose worktrees via ACP or only Electron shim `listGitWorktreeDirs`?
14. **Dictation/local Whisper** — Pro scope assessment.
15. **Security review** — token in WebSocket query string logging, Keychain secret storage for `GOOSE_SERVER__SECRET_KEY`.
16. **CI staging** — automate `stage-goose-web-ui.sh` in release pipeline; pin UI hash.
17. **Owner naming confirmation** — "Agent" vs "Forge" vs "Goose" user-visible branding.
18. **Epistemos `agent_core` boundary** — confirm zero overlap/confusion with Goose Agent surface in docs + menu.
19. **Regression corpus** — capture 5 golden ACP session transcripts from real Goose Electron for native reducer tests.
20. **feat/goose-surface merge checklist** — pbxproj, MAS gate, menu shortcuts, bootstrap lifecycle (start/stop supervisor with window).

---

## Key file index (quick navigation)

| Topic | Path |
|-------|------|
| Goose routes | `.research-clones/work/goose/ui/desktop/src/App.tsx` |
| Goose nav | `.research-clones/work/goose/ui/desktop/src/hooks/useNavigationItems.ts` |
| Goose settings | `.research-clones/work/goose/ui/desktop/src/components/settings/SettingsView.tsx` |
| Goose ACP client (TS) | `.research-clones/work/goose/ui/desktop/src/acp/acpConnection.ts` |
| Goose ACP meta | `.research-clones/work/goose/crates/goose/acp-meta.json` |
| Goose ACP server routes | `.research-clones/work/goose/crates/goose/src/acp/transport/mod.rs` |
| Epistemos ACP Swift | `Epistemos/Goose/GooseACPProtocol.swift`, `GooseACPClient.swift` |
| Boot shim ledger | `Epistemos/Goose/GooseWebBootShim.swift` |
| WebView surface | `Epistemos/Goose/GooseWebSurfaceView.swift` |
| Runtime supervisor | `Epistemos/Goose/GooseRuntimeSupervisor.swift` |
| UI staging script | `stage-goose-web-ui.sh` |
| AppKit mapping | `docs/handoffs/GOOSE_APPKIT_SURFACE_MAPPING_2026_06_26.md` |
| Theme | `Epistemos/Theme/EpistemosTheme.swift`, `Epistemos/App/UtilityWindowManager.swift` |
| Landing | `Epistemos/Views/Landing/LandingView.swift` |
| Root shell | `Epistemos/App/RootView.swift` |
| Canon/decision | `docs/research/SURFACE_EMBEDDING_WEBVIEW_VS_NATIVE_DECISION_2026_06_25.md` |

---

*Round 1 complete. No product code was modified. Round 2 should begin with ACP meta client generation + OAuth flow map + golden ACP transcript fixtures.*
