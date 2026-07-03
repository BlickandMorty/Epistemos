# Goose → AppKit Surface Mapping

> 🔴 **SUPERSEDED 2026-07-02 (OpenChamber pivot) — DO NOT BUILD FROM THIS.** Maps Goose routes to a native AppKit reskin surface — the DEAD approach. The agent surface is now OpenChamber (Pro) / June+goose-in-process (MAS); goose = one engine. Historical reference only. Canon: memory `project_ui_base_pivot_openchamber_2026_07_02`.

> 🛑 **SUPERSEDED 2026-06-29 (Option 1 + Unification).** §7 GREEN-LIT; Plan 1 on Phase 1. The chat path is **NOT**
> native after any gate — chat + every Goose feature stays in the reskinned WebView, PERMANENTLY (native = frame +
> Models picker only). Any "chat path must be native / Gate 7" mapping below is **HISTORICAL — do not build it.**
> Canon: `docs/handoffs/GOOSE_NATIVE_UI_DECISION_2026_06_29.md` + `docs/research/EPISTEMOS_NATIVENESS_DOCTRINE_2026_06_29.md`.

**Date:** 2026-06-26
**Mandate:** Whole new **Agent** surface — 1:1 screen-by-screen, component-by-component mapping from Goose Electron/React to native AppKit/SwiftUI.
**Source inventory:** `.research-clones/work/goose/ui/desktop/src/App.tsx` (HashRouter)
**Companion research:** `docs/handoffs/GOOSE_NATIVE_NEW_SURFACE_RESEARCH_ROUND1_2026_06_26.md`
**Hybrid strategy:** `docs/handoffs/GOOSE_AGENT_APPKIT_FOLLOWON_PLAN_2026_06_26.md` § Hybrid-by-route strategy

---

## Summary

| Metric | Count |
|--------|-------|
| React routes mapped | **14** |
| Navigation rail destinations | **8** (+ recent sessions list) |
| Settings tabs | **9** (8 always visible + Local Inference feature-gated) |
| Boot-shim affordances | **69** |

**Proposed native module prefix:** `Agent*` (window: `AgentSurfaceWindowController`; root: `AgentSurfaceRootView`).

---

## Hybrid rendering per route (owner canon)

Epistemos ships **one Agent window** with **native shell + nav rail** always AppKit/SwiftUI. The **content area** is a hybrid slot:

| Rendering | Routes / surfaces |
|-----------|-------------------|
| **Native panel** (v1) | Hub, session canvas, composer, transcript rows, permission/elicitation sheets, session header, Landing entry |
| **Native panel** (Phase 2) | Sessions list, permission settings, configure-providers, proven settings tabs (Models, Chat, Auth, App, Keyboard) |
| **Embedded WebView panel** (until per-route gate) | Skills, Recipes, Extensions, Scheduler, MCP Apps, shared-session, unproven settings tabs (Sharing, Prompts, Local Inference) |
| **Full-window WebView** | Phase 0 proof + Gate 7 **regression compare only** — not long-tail product UI |

**Component:** `AgentRouteContentView` (or equivalent) selects native vs `GooseWebSurfaceView` (route-scoped) from disposition table in follow-on plan. Feature flags: `useNativeChatPath`, `useWebViewForSkills`, etc.

**Mapping priority:** Sections A–E below describe the **target native components** for each route. Long-tail rows remain valid build specs — implement when that route's native gate passes; until then the same Goose React route loads in the embedded WebView panel with **full capability** (no thin native stub).

---

## A. Goose route → AppKit screen map

Every route declared in `ui/desktop/src/App.tsx`. Nested routes under `AppLayout` share the left navigation rail unless noted.

| Goose route/view | Goose visual/behavior | AppKit screen/component | v1 UI | Native tech | Data source |
|------------------|----------------------|-------------------------|-------|-------------|-------------|
| **`/` (index) — `Hub`** | Empty-state landing: large clock + time-of-day greeting + centered narrow `ChatInputCard`. No transcript. Submit creates session → navigates to `/pair`. Auto-focus composer via rAF. Working-dir badge in composer footer. | `AgentHubView` | **Native** | SwiftUI: `VStack` clock/greeting + `AgentComposerBar` in card chrome. `GooseSurfaceStyle.background(.canvas)`. | Local clock; ACP `session/new` on submit; `getInitialWorkingDir` → native cwd default |
| **`/pair` — `BaseChat` + `ChatSessionsContainer`** | Active session canvas: `SessionActionsHeader` (model, cwd, search, share, delete), optional `RecipeHeader`, `ProgressiveMessageList` (user/thinking/answer/tool rows), bottom `ChatInput`. LRU max 10 sessions kept alive (hidden when not on `/pair`). File drop on canvas. In-conversation search overlay. | `AgentSessionCanvasView` hosting `AgentTranscriptView` + `AgentComposerBar` + `AgentSessionHeaderView` | **Native** | SwiftUI shell; transcript rows as SwiftUI or `NSViewRepresentable` (`NSTextView`/`TextKit 2` for markdown); scroll via `ScrollViewReader` | ACP `session/prompt`, `session/update` chunks; `_goose/unstable/session/*` for rename/cwd/delete |
| **`/settings` — `SettingsView`** | Full-panel settings inside `MainPanelLayout`: mono title, horizontal tab bar (9 tabs), scrollable tab content. Escape closes → `/`. Deep-link `?section=` maps to tab. | `AgentSettingsView` | **Hybrid** | SwiftUI shell; proven tabs native `Form`/`List`; unproven tabs → embedded WebView tab panel | ACP `_goose/unstable/providers/*`, `preferences/*`, `defaults/*`; Epistemos Keychain for secrets |
| **`/extensions` — `ExtensionsView`** | Extension/MCP catalog: installed list, enable toggles, add/remove, env vars/headers modals, deeplink install. Back navigates `-1`. | `AgentExtensionsView` | **WebView** | Embedded `GooseWebSurfaceView` until ext gate; then SwiftUI `List` + `AgentExtensionDetailSheet` | ACP `config/extensions/*`, `session/extensions/*`, `extensions/available` |
| **`/apps` — `AppsView`** | Standalone MCP Apps grid (gated when `apps` extension enabled). Launch opens app window. | `AgentAppsView` | **WebView** | Embedded panel until Apps gate; then SwiftUI grid | ACP extension state + app metadata from Goose |
| **`/sessions` — `SessionsView` → `SessionListView`** | Session history browser: filter/search, archive, import/export, open/resume. Nostr import deep link lands here. | `AgentSessionsView` | **Native** (Phase 2) | SwiftUI `Table` or `List` with context menus | ACP `session/list`, `session/archive`, `session/import`, `session/export` + **native** `NSOpenPanel`/`NSSavePanel` |
| **`/schedules` — `SchedulesView`** | Recipe scheduler: list, create/edit modal, pause/unpause, run-now, running-job inspect/kill. Close → `/`. | `AgentSchedulesView` | **WebView** | Embedded panel until scheduler gate | ACP `schedules/*` |
| **`/recipes` — `RecipesView`** | Recipe library: cards/list, run, create/edit YAML, import deeplink, security scan warnings. | `AgentRecipesView` + `AgentRecipeEditorView` | **WebView** | Embedded panel until recipes gate | ACP `recipes/*` |
| **`/skills` — `SkillsView`** | Skills/sources catalog: list, create, export/import. | `AgentSkillsView` | **WebView** | Embedded panel until skills gate | ACP `sources/*`, `agent-mentions/list`, `slash-commands/list` |
| **`/permission` — `PermissionSettingsView`** | Tool permission rules editor (allow/deny patterns). Returns to parent route via `location.state.parentView`. | `AgentPermissionSettingsView` | **Native** (Phase 2) | SwiftUI `Form` with rule rows | ACP preferences + Goose permission store |
| **`/shared-session` — `SharedSessionView`** | Read-only or import preview for `goose://sessions/…` deep links. Loading/error/retry states. | `AgentSharedSessionView` | **WebView** | Embedded panel until share gate | HTTP fetch via Goose + ACP `session/import` |
| **`/launcher` — `LauncherView`** | Separate compact window: optional surface picker in Goose staging (Epistemos uses single Agent only), query field, launches main window with initial message. | `AgentLauncherPanelController` (optional Pro utility) | **Native shell** | SwiftUI floating panel or `NSPanel`; always opens Agent | `AgentSurfaceWindowController.open(draft:)` |
| **`/configure-providers` — `ProviderSettingsPage`** | Full-screen provider onboarding grid (outside rail). Close → `/settings?section=models`. | `AgentProviderSetupView` | **Native** (Phase 2) | SwiftUI full-screen cover inside Agent window | ACP `providers/catalog/list`, `providers/config/*`, OAuth loopback |
| **`/standalone-app` — `StandaloneAppView`** | Dedicated window chrome for a single MCP App extension. | `AgentStandaloneAppView` | **WebView** | Separate `NSWindow` + MCP host panel until gate | Extension runtime via Goose |

**Global chrome (all nested routes except fullscreen outliers):**

| Goose | AppKit |
|-------|--------|
| `AppLayout` collapsible left rail (`NavigationPanel`, 240px spring) | `AgentNavigationRailView` — `NavigationSplitView` column or fixed-width `HStack` |
| Traffic-light inset + nav toggle (`PanelLeft`/`Menu`) | `AgentSurfaceTitlebarAccessory` — respects `WindowThemeStyler`, macOS full-screen detection |
| `ToastContainer` top-right | `AgentToastCenter` — SwiftUI overlay or `UserNotifications` for async |
| `ExtensionInstallModal`, `RecipeParamsModalContainer` | `AgentExtensionInstallSheet`, `AgentRecipeParamsSheet` |
| `OnboardingGuard` | Epistemos first-run gate (optional); skip when ACP ready |
| `AnnouncementModal`, `TelemetryConsentPrompt` | Epistemos honest opt-in rows in Settings › App |

---

## B. Goose component → AppKit control map

### B.1 Navigation rail (`NavigationPanel.tsx`, `useNavigationItems.ts`)

| Goose component | Goose visual/behavior | AppKit component | Native tech | Data source |
|-----------------|----------------------|------------------|-------------|-------------|
| Primary nav rows | 7 `NAV_ITEMS` + Settings pinned bottom (= 8 destinations); mono labels; left border active indicator; Lucide icons | `AgentNavRow` | SwiftUI `Button` + SF Symbol analogs | Static route table |
| New Chat | Navigates `/`, clears to Hub | `AgentNavRow(id: .hub)` | SwiftUI | Local |
| Recipes / Skills / Apps / Scheduler / Extensions / Session History | Route push | Same pattern | SwiftUI | Feature flags (`apps`, `localInference`) |
| Settings | `/settings` | `AgentNavRow(id: .settings)` | SwiftUI | Local |
| Recent sessions (`Chats` section) | Collapsible list; inline rename (`InlineEditText`); streaming dot / error / unread badges | `AgentSessionRailSection` | SwiftUI `DisclosureGroup` + `AgentSessionRow` | ACP session list + `GooseACPEventBridge` stream state |
| Session rename | Inline edit → `acpRenameSession` | `AgentInlineRenameField` | SwiftUI `TextField` on commit | ACP `_goose/unstable/session/rename` |
| `SessionIndicators` | Pulse while streaming | `AgentSessionStatusBadge` | SwiftUI `TimelineView` or `@Observable` flag | ACP session update meta |

### B.2 Hub & session canvas

| Goose component | Goose visual/behavior | AppKit component | Native tech | Data source |
|-----------------|----------------------|------------------|-------------|-------------|
| `Hub` clock | Large time + AM/PM; updates every 30s | `AgentHubClockView` | SwiftUI `TimelineView(.periodic)` | `Date()` |
| `Hub` greeting | Morning/afternoon/evening | `AgentHubGreetingView` | SwiftUI `Text` | Localized string from hour |
| `ChatInputCard` | Rounded card wrapper, drop zone | `AgentComposerCard` | SwiftUI `RoundedRectangle` stroke `theme.border` | Local |
| `ChatInput` | Multi-line composer, send/stop, attachments, @ mentions, / slash menu, mic, dir switcher, model bar, extension toggles, message queue | `AgentComposerBar` | `NSTextView` representable + SwiftUI accessory row | ACP prompt/steer/cancel; autocomplete RPCs |
| `ProgressiveMessageList` | Virtualized scroll; streams tokens into rows | `AgentTranscriptView` | SwiftUI `LazyVStack` or `NSCollectionView` | `AgentTranscript` reducer ← ACP updates |
| `GooseMessage` / user bubble | User markdown left-aligned | `AgentUserMessageRow` | `AttributedString` + markdown render | Transcript state |
| `ThinkingContent` | Collapsible "Thinking" italic block; auto-expand while streaming | `AgentThinkingRow` | SwiftUI `DisclosureGroup` | `agent_thought_chunk` |
| `ToolCallWithResponse` | Tool name, status, expandable I/O | `AgentToolCardView` | SwiftUI card, mono header, disclosure body | `tool_call` / `tool_call_update` |
| `ToolApprovalButtons` | Allow once / always / reject | Inline on tool card **or** modal when ACP requests permission | `AgentPermissionSheet` | ACP `session/request_permission` |
| `EnvironmentBadge` | cwd chip in header | `AgentEnvironmentBadge` | SwiftUI `Label` + click → folder picker | Session cwd + ACP update |
| `SessionActionsHeader` | Model switch, search, share, menu actions | `AgentSessionHeaderView` | SwiftUI toolbar | ACP session meta + actions |
| `RecipeHeader` | Recipe title, activities, param warnings | `AgentRecipeHeaderView` | SwiftUI banner | Recipe meta on session |
| `SearchView` | In-conversation find | `AgentConversationSearchBar` | SwiftUI find bar | Local transcript index |
| `LoadingEpistemos` | Branded loading animation | `AgentLoadingView` | SwiftUI `ProgressView` or custom bird frames | Session load state |
| `MessageQueue` | Queued prompts while streaming | `AgentMessageQueueView` | SwiftUI list above composer | Local queue |
| `MentionPopover` | `@` agent mentions autocomplete | `AgentMentionPopover` | `NSPopover` / SwiftUI popover | ACP `agent-mentions/list` |
| Slash command menu | `/` recipes and commands | `AgentSlashCommandMenu` | SwiftUI popover | ACP `slash-commands/list` |

### B.3 Modals & overlays

| Goose component | Goose visual/behavior | AppKit component | Native tech | Data source |
|-----------------|----------------------|------------------|-------------|-------------|
| `BaseModal` / provider modals | Centered modal, dimmed backdrop | `AgentSheet` | `.sheet` / `NSPanel` | Varies |
| `ParameterInputModal` / `RecipeParamsModalContainer` | Dynamic form from recipe schema | `AgentRecipeParamsFormView` | SwiftUI `Form` from JSON schema | ACP `session/recipe/request-params` |
| `RecipeWarningModal` | Security scan results | `AgentRecipeSecuritySheet` | SwiftUI alert | ACP `recipes/scan` |
| `ToolCallConfirmation` | Pre-run confirm | `AgentToolConfirmSheet` | `NSAlert` | ACP permission |
| Elicitation (via ACP) | JSON schema form or URL mode | `AgentElicitationFormView` | SwiftUI dynamic form | ACP `elicitation/create` |
| `ExtensionInstallModal` | Deeplink extension install | `AgentExtensionInstallSheet` | SwiftUI | ACP `config/extensions/add` |
| `DiagnosticsModal` | Connection/session debug | `AgentDiagnosticsPanel` | SwiftUI scroll log | ACP `diagnostics/get` + supervisor health |
| Permission route | Full-page rules editor | `AgentPermissionSettingsView` | SwiftUI Form | Preferences |

### B.4 Feature views (rail destinations)

| Goose view | AppKit screen | Notes |
|------------|---------------|-------|
| `ExtensionsView` | `AgentExtensionsView` | Matches Goose sections: installed, available, configure |
| `RecipesView` | `AgentRecipesView` | Card grid + run/create |
| `SkillsView` | `AgentSkillsView` | Source list CRUD |
| `SchedulesView` | `AgentSchedulesView` | Cron-style editor |
| `SessionsView` | `AgentSessionsView` | Archive/import/export |
| `AppsView` | `AgentAppsView` | Pro extension-gated |

---

## C. Goose settings tabs → AppKit settings sections (1:1)

From `SettingsView.tsx` — each tab maps to one `AgentSettings*` section inside `AgentSettingsView`.

| Goose tab ID | Goose label | Goose sections (React) | AppKit section | Native tech | Data source |
|--------------|-------------|------------------------|----------------|-------------|-------------|
| `models` | Models | `ModelsSection`, provider grid, bottom bar model switcher | `AgentSettingsModelsSection` | SwiftUI `List` + `AgentProviderRow` | ACP `providers/list`, `providers/catalog/list`, `providers/config/*` |
| `local-inference` | Local Inference | `LocalInferenceSection`, HF search, download progress, model settings panel | `AgentSettingsLocalInferenceSection` | SwiftUI + progress rows | ACP local model RPCs; feature-gated |
| `chat` | Chat | `ChatSettingsSection` → modes (`ModeSection`), approve mode, goosehints, tool toggles | `AgentSettingsChatSection` | SwiftUI `Form` | ACP `preferences/*`, `defaults/*` |
| `sharing` | Session | `SessionSharingSection`, `ExternalBackendSection`, `GatewaySettingsSection` (tunnel) | `AgentSettingsSessionSection` | SwiftUI grouped lists | ACP sharing prefs + tunnel status API |
| `prompts` | Prompts | `PromptsSettingsSection` — template picker, edit, reset | `AgentSettingsPromptsSection` | SwiftUI + `TextEditor` | ACP prompt templates |
| `keyboard` | Keyboard | `KeyboardShortcutsSection` | `AgentSettingsKeyboardSection` | SwiftUI key capture rows | Epistemos shortcut store + Goose overrides |
| `auth` | Auth | `AuthSettingsSection`, HF sign-in, secret store | `AgentSettingsAuthSection` | SwiftUI progress sheet + device-code copy UI; **v1:** ACP `_goose/unstable/providers/config/authenticate` (goosed owns loopback OAuth); **v2 optional:** `ASWebAuthenticationSession` only if auth moves out of goosed | ACP authenticate + Keychain for loopback secret only |
| `app` | App | `ConfigSettings` (YAML), `AppSettingsSection` (updates hidden in Epistemos, dock, notifications, spellcheck, wakelock) | `AgentSettingsAppSection` | SwiftUI | Shim settings + ACP config read/write |

**Deep-link section map** (preserve 1:1):

| Goose `?section=` | AppKit tab |
|-------------------|------------|
| `models` | Models |
| `local-inference` | Local Inference |
| `chat`, `modes`, `styles`, `tools` | Chat |
| `sharing`, `gateway` | Session |
| `prompts` | Prompts |
| `keyboard` | Keyboard |
| `auth` | Auth |
| `app`, `update` | App |

---

## D. Goose Electron affordance → AppKit implementation

From `GooseWebBootShim.dispositionLedger` (69 keys). Native Agent surface **implements directly** — no WebView shim on critical paths.

### D.1 `implemented-native` → Swift host

| Affordance | Goose usage | AppKit implementation |
|------------|-------------|----------------------|
| `appConfig.get`, `appConfig.getAll` | Boot config | `GooseWebBootstrap.appConfigDictionary` / Agent config service |
| `arch`, `platform` | Feature gates | `ProcessInfo`, `#if arch` |
| `broadcastThemeChange` | Dark/light sync | Notification from `UIState.theme` → Agent window |
| `getConfig`, `getSetting`, `setSetting` | UI prefs | UserDefaults or Agent settings store |
| `getVersion` | About/diagnostics | `Bundle.main` + pinned Goose version |

### D.2 `implemented-runtime` → Goose supervisor

| Affordance | AppKit implementation |
|------------|----------------------|
| `getGoosedHostPort` | `GooseRuntimeSupervisor.loopbackBaseURL` |
| `getSecretKey` | Supervisor-generated token (Keychain) |
| `getAcpUrl` | `GooseRuntimeSupervisor.acpWebSocketURL` |

### D.3 `hidden-shell` → intentionally omitted

Updater IPC (`checkForUpdates`, `downloadUpdate`, `installUpdate`, `quitAndInstall`, …) — Epistemos uses app-level Sparkle/versioning; **no UI**.

### D.4 `compatibility-preserved` → native stubs or no-ops

Menu/dock/wakelock/spellcheck IPC, `createChatWindow`, `reactReady`, event bus — Agent surface uses **native window management** instead; stubs return safe defaults where WebView fallback still runs.

### D.5 `deferred-with-visible-error` → **Gate 2 native priority**

| Affordance | AppKit implementation |
|------------|----------------------|
| `showOpenDialog`, `showSaveDialog`, `directoryChooser`, `selectFileOrDirectory`, `selectImportSessionFile` | `NSOpenPanel` / `NSSavePanel` wrappers on `@MainActor` |
| `showMessageBox` | `NSAlert` |
| `openExternal`, `openInChrome` | `NSWorkspace.shared.open` |
| `openDirectoryInExplorer` | `NSWorkspace.selectFile` |
| `readFile`, `writeFile`, `ensureDirectory` | `FileManager` + sandbox bookmarks |
| `getBinaryPath`, `launchApp`, `refreshApp`, `closeApp` | Extension lifecycle via Goose ACP (not raw shell) |
| `openNotificationsSettings` | `NSWorkspace.openNotificationSettings` |

---

## E. Visual parity notes

Fresh Epistemos theme application — **not** inherited from any prior agent UI.

### E.1 Layout & density

| Goose (React/Tailwind) | AppKit target |
|------------------------|---------------|
| Nav width ~240px (`NAV_DIMENSIONS.NAV_WIDTH`) | `AgentNavigationRailView` fixed 240pt |
| Mono nav labels (`font-mono text-xs`) | `GooseSurfaceStyle.bodyFont(11)` / JetBrains Mono |
| Left border active row (`border-l-2 border-border-active`) | 2pt `theme.accent` leading bar on selected row |
| Hub centered column, large clock | `AgentHubView` max width ~480pt centered |
| Composer card rounded border | 1px `theme.border`, `theme.card` fill, 8pt radius |
| Flat TUI tool cards | `AgentToolCardView`: card background, mono title, no glass |
| Settings tab bar horizontal scroll | `Picker` segmented or scrollable `HStack` of tabs |

### E.2 Color tokens (Goose → Epistemos)

| Goose CSS token | Epistemos token |
|-----------------|-----------------|
| `background-primary` | `theme.resolved.background` |
| `background-secondary` | `GooseSurfaceStyle.background(.rail)` ← `theme.card` blend |
| `background-tertiary` | Selected row highlight |
| `chatSurface` / canvas | `GooseSurfaceStyle.background(.canvas)` ← `theme.chatSurface` blend |
| `border-secondary` | `theme.border` |
| `text-primary` / `text-secondary` | `theme.foreground` / `theme.mutedForeground` |
| `border-active` | `theme.accent` |

Apply via `@Environment(UIState.self) var ui` → `ui.theme`; inject into Agent utility window on open (`WindowThemeStyler.themedContentView`).

### E.3 Typography

| Role | Font |
|------|------|
| UI labels, nav, tool headers | JetBrains Mono (`GooseSurfaceStyle.bodyFont`) |
| Markdown transcript body | `ClaudeAppTypography.assistantFont` or system readable default |
| Settings title | Mono 22pt regular (matches Goose `text-2xl font-mono`) |

### E.4 Motion

| Goose | AppKit |
|-------|--------|
| Nav expand spring (framer-motion) | SwiftUI `.spring(response: 0.35, dampingFraction: 0.85)` |
| Page fade-in | `.opacity` transition on route change |
| Streaming cursor | Transcript append without full view reload; coalesce 60ms if needed |
| **Avoid** | `.repeatForever` — gate animations with `windowOccluded` + `accessibilityReduceMotion` |

### E.5 Window chrome

| Goose | AppKit |
|-------|--------|
| `titlebar-drag-region` | Full-size content view with hidden title; drag via `NSWindow.isMovableByWindowBackground` |
| Traffic-light inset (96px) | `AgentSurfaceTitlebarAccessory` padding when not fullscreen |
| Utility window | `AgentSurfaceWindowController` — mirrors `GooseSurfaceWindowController` pattern |

---

## F. Explicit non-goals

1. **No legacy chat recovery** — the Agent surface is a greenfield AppKit implementation. No deleted views, state classes, or landing submission paths are restored or referenced in build work.
2. **Single-surface launcher** — Goose staging `LauncherView` multi-surface picker collapses to a single **Agent** entry in Epistemos.
3. **Hybrid WebView policy** — **Chat path** (hub, session, transcript, composer) must be native after Gate 7. **Long-tail routes** may use embedded `GooseWebSurfaceView` in the Agent content area until per-route native gate — full capability, not stub. Full-window WebView = Phase 0 + regression compare only. See follow-on plan § Hybrid-by-route strategy.
4. **No hidden Goose subprocess** — `goose serve` stays an explicit loopback child process (Pro/Developer-ID); MAS shows honest gate.
5. **No UniFFI embed** — UI is Swift-only; Rust boundary is ACP WebSocket.
6. **No Notes/Graph/Landing mutation** — Agent opens as utility window; vault and graph surfaces unchanged.
7. **No fake agent on MAS** — placeholder copy only; no simulated streaming.

---

## Implementation file plan (new components only)

| Area | Proposed Swift paths |
|------|---------------------|
| Window shell | `Epistemos/Agent/AgentSurfaceWindowController.swift`, `AgentSurfaceRootView.swift`, `AgentRouteContentView.swift` |
| Navigation | `Epistemos/Agent/AgentNavigationRailView.swift`, `AgentSessionRailSection.swift` |
| Hub + canvas | `Epistemos/Agent/AgentHubView.swift`, `AgentSessionCanvasView.swift` |
| Transcript | `Epistemos/Agent/AgentTranscript.swift`, `AgentTranscriptView.swift`, `AgentToolCardView.swift`, `AgentThinkingRow.swift` |
| Composer | `Epistemos/Agent/AgentComposerBar.swift`, `AgentComposerCard.swift` |
| Modals | `Epistemos/Agent/AgentPermissionSheet.swift`, `AgentElicitationFormView.swift`, `AgentRecipeParamsFormView.swift` |
| Settings | `Epistemos/Agent/Settings/AgentSettingsView.swift`, `AgentSettings*Section.swift` |
| Feature views | `Epistemos/Agent/AgentExtensionsView.swift`, `AgentRecipesView.swift`, … |
| Session control | `Epistemos/Agent/AgentSessionController.swift` (actor, wraps `GooseACPClient`) |
| Style | Reuse `GooseSurfaceStyle.swift`; extend if needed as `AgentSurfaceStyle` alias |

---

## Route coverage checklist

- [x] `/` Hub
- [x] `/pair` Session canvas
- [x] `/settings`
- [x] `/extensions`
- [x] `/apps`
- [x] `/sessions`
- [x] `/schedules`
- [x] `/recipes`
- [x] `/skills`
- [x] `/permission`
- [x] `/shared-session`
- [x] `/launcher`
- [x] `/configure-providers`
- [x] `/standalone-app`

**Total: 14 routes**

---

*Mapping complete 2026-06-26 (hybrid-by-route aligned). Build gates: see Round 1 Pass E (Gates 0–7) + follow-on plan § Hybrid-by-route strategy.*
