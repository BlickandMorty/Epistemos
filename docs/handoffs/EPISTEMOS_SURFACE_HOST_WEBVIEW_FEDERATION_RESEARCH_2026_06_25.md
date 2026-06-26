# Epistemos Surface Host / WebView Federation Research - 2026-06-25

## Bottom Line

The practical no-compromise path is not "one giant native chat view" and not
"three unrelated apps." It is one native Epistemos shell that owns identity,
landing, navigation, context, sessions, permissions, app tools, and visual
tokens, with three contained runtime surfaces inside it:

1. Swift Agent native surface: deepest native Epistemos integration.
2. Goose surface: full Goose capability preserved first, then adapted into a
   WebView/browser-compatible surface through a preload/IPC compatibility shim.
3. OpenGUI/OpenWork surface: native Work shell plus embedded web/runtime panes,
   already closest to this architecture in current code.

This keeps the benefits the owner wants:

- one app feeling from the landing/home window;
- no old native ChatView ontology;
- Goose and OpenGUI remain useful instead of being under-cloned;
- Swift Agent becomes the deepest native surface;
- app context, note actions, graph context, skills, tools, permissions, and
  recents are shared by the host, not copied into three fragile chat rewrites.

## Supersession Lock

This doc replaces the earlier loose wording "use WKWebView" with the more exact
current rule:

- For new SwiftUI-hosted web surfaces on macOS 26+, use SwiftUI WebKit
  `WebView` + `WebPage`.
- Keep `WKWebView`/AppKit wrappers only where an existing surface has not been
  migrated or where a specific missing API forces it.
- Keep the bridge concept from `WKUserContentController` / injected JavaScript:
  the product requirement is still a narrow, namespaced JS-to-native command
  bridge, not direct arbitrary renderer power.
- Do not describe macOS 26 `WebView` as a different browser engine from
  `WKWebView`. It is the SwiftUI-facing WebKit integration layer. The practical
  comparison is old host API versus new SwiftUI host API, not WebKit versus
  another engine.

If any future research contradicts a section below, update the relevant section
in place. Do not append a second conflicting architecture.

## Decision

Adopt `EpistemosSurfaceHost` as the organizing product boundary.

Do not try to make Goose, OpenGUI, and Swift Agent all flow through one native
Swift transcript as the first target. That has been the failure pattern: it
makes the app look integrated while silently losing dependency install,
runtime discovery, tool execution, thinking-state rendering, memory/session
behavior, approvals, and provider state.

The first working target is:

- one landing/home shell;
- one mode switch: Chat, Act, Work;
- one shared context/session/permission/tool contract;
- three rendering engines below that contract;
- native Epistemos chrome around all three;
- visual convergence through tokens and layout rules;
- runtime/event convergence through an explicit bridge;
- native transcript convergence only after event parity is proven.

## Why The Old Native Chat Felt Integrated But Broke

The old chat surfaces felt integrated because they were physically attached to
Landing/Home and rendered in Swift. That created visual continuity, but not
runtime truth. The missing pieces were below the UI:

- no reliable provider/runtime discovery;
- incomplete tool-install and dependency-install affordances;
- weak memory/session ownership;
- thinking/tool/answer phases not represented as a real event stream;
- fragile app-specific note/vault actions mixed with generic file actions;
- too many separate chat implementations: main chat, mini chat, graph chat,
  note chat, Act chat, Osaurus chat, transitional ChatView variants.

Therefore, "native" by itself is not the fix. The fix is a real event and tool
contract owned by Epistemos, plus contained surfaces that already know how to
run serious agent flows.

## Current Local Evidence

Local canon read first:

- `docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md`
- `docs/handoffs/CHAT_ACT_WORK_TRI_SURFACE_ENGINE_PLAN_2026_06_24.md`
- `docs/handoffs/WEBVIEW_MIGRATION_LEDGER_2026_06_24.md`
- `docs/handoffs/GOOSE_SURFACE_CLAUDE_HANDOFF_2026_06_24.md`
- `docs/handoffs/WORK_INTEGRATION_SHAPE_RECOMMENDATION_2026_06_24.md`
- `docs/WORK_CANON_STATUS_2026_06_25.md`
- `docs/handoffs/ACT_AGENTCLONE_MASTER_GOAL_PROMPT_2026_06_25.md`

Current repo truth:

- `Epistemos/Work/WorkWebSurfaceView.swift` already uses SwiftUI `WebView(page)`
  with `WebPage`, local SPA serving, OpenWork worker bootstrap, and native MCP
  registration.
- `Epistemos/Engine/EpdocEditorBridge.swift` already proves the app has a
  typed JS to Swift bridge pattern with namespaced `window.epistemos` commands.
- Work already exposes `WorkAppContextSnapshot` and
  `epistemos.context.snapshot`, which is the best current pattern for shared
  app context.
- AgentClone/Swift Agent is the live native foundation for Chat/Act, with
  direct `AgentClone.ContentView()` mounting and host context injection.
- Goose is currently a full Electron/React fork/reskin in
  `.research-clones/work/goose`, with real routes preserved and visual work
  already underway, but not yet deeply connected to Epistemos vault/graph/note
  context.

## Apple/WebKit Facts Checked

Primary Apple sources confirm the macOS 26 direction:

- WWDC25 "Meet WebKit for SwiftUI" introduces SwiftUI `WebView` and
  `WebPage`, local resource loading, observable navigation, JavaScript
  communication, and navigation policies:
  https://developer.apple.com/videos/play/wwdc2025/231/
- `WebPage` is the programmatic object for controlling and managing web
  content:
  https://developer.apple.com/documentation/WebKit/WebPage
- `WebPage.Configuration` configures page behavior:
  https://developer.apple.com/documentation/webkit/webpage/configuration
- `WebPage.NavigationDeciding` is the new navigation policy hook:
  https://developer.apple.com/documentation/webkit/webpage/navigationdeciding
- `WKUserContentController` remains the classic bridge object for injecting
  scripts and receiving JS messages:
  https://developer.apple.com/documentation/webkit/wkusercontentcontroller
- `WebPage.callJavaScript` is the SwiftUI WebKit path for async JS calls:
  https://developer.apple.com/documentation/webkit/webpage/calljavascript%28_%3Aarguments%3Ain%3Acontentworld%3A%29

Conclusion: macOS 26 `WebView`/`WebPage` is the right host API for new embedded
surfaces. Do not invent an AppKit-only WKWebView wrapper for new work unless a
specific API gap forces it. Existing `WKUserContentController` style bridge
concepts still matter because injected JS and message handlers remain the
practical bridge pattern.

## Electron Facts Checked

Primary Electron docs confirm why Goose cannot be treated as a plain webpage:

- Electron `contextBridge.exposeInMainWorld` exposes a controlled API from the
  preload world into the renderer; functions are proxied and non-function data
  is copied/frozen:
  https://www.electronjs.org/docs/latest/api/context-bridge
- Electron `ipcRenderer.invoke` expects matching `ipcMain.handle` handlers and
  serializes arguments through structured-clone rules:
  https://www.electronjs.org/docs/latest/api/ipc-renderer
- Electron's IPC tutorial warns not to expose whole `ipcRenderer.send`,
  `invoke`, or `on` APIs directly to a renderer:
  https://www.electronjs.org/docs/latest/tutorial/ipc

Implication for Epistemos: the Goose WebView bridge must be an allowlisted
facade, not a generic "send any IPC channel" bridge. The correct WebView shim
adapts only the known Goose renderer needs to Epistemos-owned native/runtime
operations.

## Product Shape

### Native Host Owns

- Landing/Home window.
- Chat/Act/Work mode selection.
- Shared recents/session registry.
- Active vault/workspace identity.
- Graph/note/minichat portal routing.
- Permission prompts and tool approval UI.
- App-owned note create/delete/update actions.
- App-owned graph context snapshot.
- App-owned skills/tools registry.
- Model/engine picker vocabulary.
- Window chrome, theme tokens, focus, transitions.
- Process supervision and health diagnostics.

### Swift Agent Native Surface Owns

- Best native Chat/Act experience.
- Deepest SwiftUI polish and fastest app-specific action integration.
- Typed Epistemos context attachments.
- App-owned note/graph/vault tools after clone-contained hardening.
- Native rendering of thinking/tool/answer phases after event model is stable.

### Goose Surface Owns

- Goose sessions, providers, MCP/extensions, ACP, recipes, permissions, skills,
  schedules, memory/config, API/server, desktop plumbing.
- Goose's proven event/UI behaviors until Epistemos has equivalent contracts.
- Act-style autonomous use where Goose is strongest.

### OpenGUI/OpenWork Surface Owns

- Workbench flows: coding sessions, multi-engine work, OpenCode-first runtime,
  prompt queue, permissions/questions, diffs, terminal/workspace flows.
- Existing native MCP and context snapshot path.
- Work engine/provider orchestration.

## What To Strip From Goose And OpenGUI

Strip only shell/identity layers, not capabilities.

Safe to strip or hide:

- standalone splash/onboarding when Epistemos already owns onboarding;
- donor top-level window chrome;
- donor app menu/update/about identity;
- marketing copy and visible donor branding;
- duplicated landing pages;
- separate global settings islands that conflict with Epistemos Settings;
- decorative theme language that fights the flat Epistemos visual target.

Do not strip:

- provider configuration and auth flows;
- dependency/tool installation logic;
- session stores;
- runtime process contracts;
- MCP/ACP/extensions/skills/recipes/schedules;
- approval/permission logic;
- event stream semantics;
- diagnostic/runtime names needed for debugging;
- package/module/import/env/storage/protocol names unless a migration is
  designed and tested.

## Goose WebView Reality Check

Goose is Electron/React. A `WKWebView` cannot run Electron preload APIs or Node
IPC as-is. Therefore, "put Goose in a WebView" requires a compatibility layer,
not just loading the existing Electron renderer.

Current local Goose evidence:

- `.research-clones/work/goose/ui/desktop/src/preload.ts` exposes
  `window.electron` through Electron `contextBridge`.
- `.research-clones/work/goose/ui/desktop/src/renderer.tsx` calls
  `window.electron.getGoosedHostPort()` and `window.electron.getSecretKey()`
  before rendering normal app routes, then configures the generated API client.
- `.research-clones/work/goose/ui/desktop/src/main.ts` registers many
  `ipcMain.handle` / `ipcMain.on` endpoints for settings, secret key, goosed
  host/port, ACP URL, file dialogs, file reads/writes, recent dirs, native
  windows, notifications, app launching, updates, menus, spellcheck,
  wake-lock, and external links.
- Goose's TypeScript SDK is ACP-oriented; the Rust UniFFI crate currently has
  only a `ping -> pong` scaffold, so native Swift library integration is not
  the first reliable route.

Therefore the first WebView target is not "run Goose renderer untouched in
WebView." It is "make a browser-compatible Goose renderer build whose privileged
`window.electron` calls are satisfied by an Epistemos-owned shim."

Correct Goose ladder:

1. Preserve full Goose Electron fork as the capability baseline and fallback.
2. Inventory every renderer call to `window.electron` and `window.appConfig`.
3. Classify each call:
   - app-owned native operation: replace with Epistemos native host behavior;
   - runtime operation: forward to goosed/API/ACP through supervised loopback;
   - shell-only operation: hide/remove because Epistemos owns the shell;
   - compatibility key: preserve behavior/name behind the facade.
4. Build a browser compatibility harness for Goose UI outside Electron.
5. Implement a narrow `window.electron` compatibility facade plus
   `window.epistemos.goose` bridge. The facade exists so current Goose code can
   boot; the Epistemos namespace is where new app-owned bridge functions live.
6. Forward `getGoosedHostPort`, `getSecretKey`, `getAcpUrl`, provider/session
   requests, permission events, and diagnostics to an Epistemos-supervised
   Goose runtime.
7. Stub or native-route app-shell calls such as app updates, window creation,
   menu-bar/dock visibility, open external URL, notifications, file dialogs,
   and settings.
8. Prove browser harness routes: launch, session list, send/stream,
   thinking/tool/answer separation, tool approval, provider/settings,
   skills/recipes/schedules, extension/MCP surfaces, import/export, and
   restart/error states.
9. Only then mount that browser-compatible Goose UI inside macOS 26
   `WebView(page)`.
10. Keep the Electron fork as a fallback until the WebView route passes the same
   route checks.

This is the concrete middle ground. It avoids breaking Goose by pretending it
is already a plain web app, but it still moves toward an embedded Epistemos
surface.

### Goose Shim API Minimum

The first `GooseWebSurface` shim should cover these groups before any native
port is attempted:

- boot: `getConfig`, `getGoosedHostPort`, `getSecretKey`, `getAcpUrl`;
- lifecycle/events: `reactReady`, `on`, `off`, `emit`, `fatal-error`,
  `set-view`, `new-chat`, `focus-input`, `set-initial-message`;
- settings: `getSetting`, `setSetting`, app config reads, theme changes;
- OS affordances: open external URL, show message box, save dialog, directory
  chooser, notifications, file import, allowed extensions;
- session/workspace: recent dirs, git worktrees, selected workspace, session
  import/export;
- runtime diagnostics: binary path lookup, Ollama check, launch/refresh/close
  app where those still map to Goose capability;
- updater/window/menu affordances: hidden or native-routed, not exposed as a
  separate product update system.

Every shim function must have one of these dispositions in a ledger before the
WebView route is called real:

- `implemented-native`
- `implemented-runtime`
- `hidden-shell`
- `compatibility-preserved`
- `deferred-with-visible-error`

## OpenGUI/OpenWork WebView Reality Check

OpenGUI/OpenWork is already closer to the target:

- current Work path already has native Work chrome and an embedded web/runtime
  pattern;
- `WorkWebSurfaceView.swift` already starts a local worker, serves an SPA, and
  registers native MCP;
- `WorkAppContextSnapshot` and `epistemos.context.snapshot` already create the
  shared context seam.

Correct Work ladder:

1. Keep native OpenGUI-backed Work as the primary Work route.
2. Keep OpenWork WebView preview/fallback until owner visual proof allows
   removal.
3. Continue exposing Epistemos context and app tools through native MCP.
4. Do not collapse Work into old ChatView or Swift Agent.
5. Use Work's context snapshot design as the pattern for Goose and Swift Agent.

Important correction: current Work truth has moved beyond "OpenGUI is just a
WebView." The primary Work route is native OpenGUI/OpenCode orchestration with
native MCP and no-model OpenGUI probes. The OpenWork WebView stays as Settings
preview/fallback. Any agent that tries to replace current Work with a new
generic WebView because this document mentions WebView is going backward.

## Shared Bridge Contract

All surfaces should eventually receive the same host bridge shape:

- `epistemos.context.snapshot`
- `epistemos.session.create`
- `epistemos.session.select`
- `epistemos.event.post`
- `epistemos.permission.request`
- `epistemos.tool.call`
- `epistemos.note.create`
- `epistemos.note.update`
- `epistemos.note.delete`
- `epistemos.graph.context`
- `epistemos.search.vault`
- `epistemos.skill.list`
- `epistemos.skill.run`
- `epistemos.runtime.health`

The bridge must be versioned, typed, schema-validated, and denial-first:

- reject unknown commands;
- reject malformed payloads;
- include request ids;
- include session ids;
- return structured errors;
- log RunEvent-style evidence for important actions;
- never silently claim a tool exists if it is not available this turn;
- never allow web content to access arbitrary files directly.

### Bridge Transport Shape

For macOS 26 `WebView`/`WebPage`, define the bridge in two layers:

1. Swift-owned host controller:
   - owns `WebPage`;
   - owns navigation policy;
   - loads local resources or loopback URLs;
   - injects the JS bootstrap;
   - receives JS messages through the chosen WebKit message mechanism;
   - calls back into the page with `WebPage.callJavaScript`.
2. Surface-specific adapter:
   - `GooseWebBridgeAdapter`;
   - `OpenGUIWebBridgeAdapter`;
   - future `SwiftAgentBridgeAdapter` if needed for parity;
   - maps generic Epistemos commands to the surface's runtime/session APIs.

Do not let a web surface directly call note storage, graph mutation, file
system paths, Keychain, or process launch. It must ask the host bridge, and the
host bridge must apply the same permission/tool rules the native Swift surface
uses.

## Event Model First, Native Transcript Later

The strongest anti-drift rule:

Mirror events before re-rendering everything natively.

Minimum shared event families:

- session created/selected;
- prompt submitted;
- assistant thinking/plan started;
- tool call requested;
- permission requested;
- permission answered;
- tool result received;
- dependency/install step requested;
- model/provider changed;
- assistant answer delta;
- assistant answer finished;
- error/abstention;
- cancellation/interruption;
- context snapshot attached.

Once Goose/OpenGUI/Swift Agent all emit enough of this event model, Epistemos
can build a unified native transcript or timeline safely. Doing native
transcript first is how capability gets lost.

## Craft-Like Product Integration Target

The useful lesson from Craft-like apps is product-level containment, not proof
that their internals match this architecture. The target look is:

- no browser chrome;
- no separate donor home page;
- no standalone updater/onboarding taking over the flow;
- native toolbar/rail/session picker outside the web content;
- web content fills the work/chat region like an app-native editor;
- theme variables are injected before first paint;
- loading/error/permission states are native and consistent;
- scrollbars, focus rings, menus, and popovers are flattened to Epistemos
  tokens;
- app-owned operations use native panels, not donor-branded dialogs.

The WebView may remain technically web-rendered, but the product boundary must
feel like one Epistemos surface. That comes from shell ownership, first-paint
theming, bridge discipline, and no duplicate state islands.

## Protected Areas

Do not delete or rename these while pursuing this architecture:

- `LocalPackages/AgentClone`
- `LocalPackages/Swarm`
- `LocalPackages/EpistemosChatDonorContracts`
- `Epistemos/Work`
- `.research-clones/work/goose`
- `.research-clones/work/opengui`
- `.research-clones/work/openwork`
- `.research-clones/work/opencode`
- `.research-clones/work/openchamber`
- donor/runtime compatibility names listed in `docs/WORK_CANON_STATUS_2026_06_25.md`
- AgentClone protected names listed in
  `docs/handoffs/ACT_AGENTCLONE_MASTER_GOAL_PROMPT_2026_06_25.md`

Old native chat surfaces, old Osaurus routes, and old mini/graph/note chat
implementations may be deleted only through route inventory plus buildable
replacement routing. Do not restore them to get a temporary compile pass.

## Implementation Order

### Phase 1 - Stabilize The Shell

- Delete/retire old ChatView, Osaurus, MiniChat, GraphChat, and NoteChat
  backends/routes only after current replacement routes compile.
- Keep Landing/Home as the only top-level entry.
- Route Chat/Act/Work through `EpistemosSurfaceHost`.
- Ensure each route has one owner and one runtime adapter.

### Phase 2 - Preserve Full Donor Capability

- Swift Agent: keep hardening clone-contained native path.
- Goose: keep full Electron fork working while building browser compatibility.
- Work/OpenGUI: keep native Work primary and OpenWork preview gated.

### Phase 3 - Add Shared App Context

- Use Work's `WorkAppContextSnapshot` as the pattern.
- Add equivalent bounded host context for Swift Agent and Goose.
- Add read-only context first: vault, workspace, selected mode, session id,
  graph selection, note selection, available app tools.
- Add write actions later: note create/delete/update, graph attach, vault
  search, skill run.

### Phase 4 - Add Shared Permissions And Tools

- Native host owns permission prompts.
- Web surfaces request permission through the bridge.
- Tool calls become transcript-visible and failure-visible.
- No direct arbitrary file access from WebView content.

### Phase 5 - Visual Convergence

- Share Epistemos tokens.
- Flatten donor UI chrome.
- Use one control rail pattern.
- Use one compact model/engine picker language.
- Keep donor internals visible only in diagnostics/pickers where useful.
- Do not fork hundreds of donor components if token/CSS bridge can do it.

### Phase 6 - Unified Transcript

- Only after event parity, build optional native transcript/timeline.
- Start by mirroring summaries and tool cards.
- Then native-render individual stable event families.
- Do not replace donor rendering until each family has route tests.

## Proof Gates

Do not call the federation "working" until these gates pass for each surface.

### Shared Gates

- Landing/Home opens Chat, Act, and Work inside the same Epistemos shell.
- Each mode preserves its own runtime capability and does not fall back to old
  ChatView/Osaurus/MiniChat/GraphChat/NoteChat code.
- Theme tokens apply before or at first paint.
- Draft prompt handoff works from Landing/Home.
- Session appears in the shared Epistemos recents/session rail.
- Context snapshot is visible to the surface and readable by the model/runtime.
- Tool and permission events appear in Epistemos native process/permission UI.
- Errors are transcript-visible or panel-visible, not console-only.
- Closing the surface tears down or detaches runtime processes cleanly.

### Swift Agent Gates

- Direct native surface mounts.
- Prompt runs through clone runner, not a parallel fake runner.
- Host context includes vault and workspace.
- Side panel exposes Epistemos context.
- Future note/graph/minichat portals use typed context attachments, not old
  chat backends.

### Goose Gates

- Electron fork remains launchable as fallback.
- Browser compatibility harness boots without Electron.
- `window.electron` facade ledger covers all used renderer calls.
- `getGoosedHostPort` / `getSecretKey` boot path works.
- Session list, new session, send, stream, thinking/tool/answer phases, tool
  approval, provider settings, extensions/MCP, recipes, skills, schedules,
  diagnostics, import/export, and error routes are route-tested.
- WebView mount uses macOS 26 `WebView`/`WebPage` after browser harness proof,
  not before.

### OpenGUI/Work Gates

- Native OpenGUI-backed Work remains primary.
- OpenWork WebView remains fallback/preview until owner proof removes it.
- `epistemos.context.snapshot` works through native MCP.
- Skills and note/vault tools are provisioned through app-owned APIs.
- Prompt queue, permissions/questions, recents, session reopen, and no-model
  OpenGUI probes keep passing.

## Failure Modes To Reject

- A surface "works" only because it loads a donor UI screenshot or static shell.
- Goose WebView route skips the preload/IPC inventory.
- OpenGUI WebView route replaces the stronger native OpenGUI primary route.
- Swift Agent gets blocked by trying to own all Goose/OpenGUI UI at once.
- The bridge exposes generic arbitrary IPC.
- Web surfaces call raw files instead of app-owned note/vault APIs.
- Old mini/graph/note chat implementations return as hidden fallbacks.
- Donor provider/session/tool/settings capability is deleted to make UI cleaner.
- Runtime names are renamed in storage/protocol/config paths for branding.
- Native transcript unification starts before event mirroring is complete.

## Agent Prompt Addendum

```text
Use the Epistemos Surface Host / WebView Federation plan as the current
architecture. Do not attempt to force Swift Agent, Goose, and OpenGUI through
one native ChatView. The target is one native Epistemos shell with three
contained runtime surfaces and one shared context/session/permission/tool
contract.

Keep full capability first. Goose and OpenGUI must not be reduced to thin
backends or visually hidden stubs. Strip only standalone shell/branding/chrome
layers, not provider/session/tool/permission/runtime behavior. Preserve deep
runtime names, package names, env vars, storage keys, protocol ids, module
names, and compatibility identifiers unless a tested migration exists.

Build connectedness through:
1. native Landing/Home and Chat/Act/Work routing;
2. a shared Epistemos context snapshot;
3. shared native permission/tool approval surfaces;
4. a versioned JS/native bridge for WebView surfaces;
5. event mirroring for prompts, thinking, tools, approvals, answers, errors,
   cancellations, and context attachment;
6. shared visual tokens and flat Epistemos chrome.

For Goose specifically: do not assume the Electron renderer can simply load in
WKWebView. First inventory preload/IPC calls, build a browser compatibility
harness, add a `window.epistemos.goose` bridge/shim to Goose server/API/ACP/CLI,
prove session/send/stream/tool/provider/skills routes, then mount the browser
compatible surface in macOS 26 WebView/WebPage. Keep the full Goose Electron
fork as fallback until WebView parity is proven.

For OpenGUI/OpenWork: continue the native Work primary route and existing
WebView/runtime pattern. Use `WorkAppContextSnapshot` and
`epistemos.context.snapshot` as the shared context precedent. Do not collapse
Work into old ChatView or Swift Agent.

For Swift Agent: keep it the deepest native Epistemos agent surface. After
clone-contained hardening, add typed context/actions for notes, graph, vault,
skills, and tools. Do not revive old MiniChat, GraphChat, NoteChat, Osaurus, or
ChatView routes; rebuild those as portals into the new surface system.

Definition of done for each step: capability preserved, route tested, visual
state verified, context/tool errors visible, and no protected donor/runtime
contracts renamed or deleted.
```

## Final Consensus

Yes, the owner can still get the "one cohesive app" result without betting the
whole project on one brittle native rewrite. The connectedness should come from
the native Epistemos host and shared contracts, not from pretending every engine
is already the same chat UI.

The final ideal can still become more native over time. But the next buildable,
least-breakable version is a federation:

- Swift Agent is native and deepest.
- Goose stays powerful and becomes WebView-compatible through a shim.
- OpenGUI/OpenWork stays powerful through the existing Work hybrid.
- Epistemos owns the shell, context, tools, permissions, visual language, and
  eventual unified event transcript.
