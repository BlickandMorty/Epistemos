# SS-J — Browser-use in ALL surfaces (Act / Work / Osaurus + Chat) (2026-06-19)

Read-only research (subagent), code-grounded. Feeds SETTINGS_SIMPLIFICATION_HUB + the BROWSER-USE-EVERYWHERE
ledger item. Owner: *"the actual github browser-use — available across Act/Work/Osaurus + chat; make the app
useful in those locations."* Extends prior `COMPUTER_BROWSER_USE_2026_06_19.md`. Doctrine: APP-NATIVE BY
EMBEDDING (clone source, never run the foreign program/sidecar), local-first, honest gating, engine-isolation.

## Headline
**~70% of the primitive already exists; the honest local-first piece is designed but NOT built.** Epistemos
ships a real, hardened, Pro-gated **11-tool `browser.*` family** + a mature **computer-use AX/vision stack**
(`DeviceAgentService`) whose core loop *is* browser-use's loop (AX-tree + intent → action). The clean
`BrowserEngine` trait exists with **MockEngine only** — the WebKit (MAS-safe) + Obscura (Pro) adapters are doc
comments, not code. So "browser-use everywhere" is **wiring + one new in-process WebKit adapter**, not
greenfield. **Honesty flag for the owner:** the current `browser.rs` path **spawns the foreign `agent-browser`
CLI** → violates no-sidecar; the app-native-by-embedding answer is the **WebKit adapter**, not the CLI.

## Already REAL
- **`browser.*` — 11 tools, hardened, Pro-gated.** `agent_core/src/tools/browser.rs`: navigate/snapshot/click/
  type/scroll/back/press/close/get_images/vision/console (`BrowserAction` `:168-181`; schemas `:878-1036`).
  Drives `agent-browser` CLI over a per-session Unix socket (`run_agent_browser_command:644`). Hardened spawn
  `:546-559` via `security::harden_cli_subprocess_extending` (HTTP_PROXY allowlist + FAKE_BROWSER_LOG fixture;
  helper `security.rs:942`). SSRF guard `validate_url:220`; secret redaction `:811-840`; output caps `:772-792`;
  test blocks 127.0.0.1 `:1296`. `browser_vision` requires `allow_cloud_external_requests` ack `:378-384`.
- **Registration (ONE site, shared registry)** `registry.rs:2672-2753` under `#[cfg(feature="pro-build")]`, all
  `ToolTier::Agent`; click/type/press=Destructive, navigate/scroll/back=Modification, snapshot/get_images/
  vision/console=ReadOnly.
- **`BrowserEngine` trait = the canonical clean interface, adapter-starved.** `browser_engine/mod.rs:84-105`
  (`open_session/navigate/snapshot/click/type_text/scroll/close`); `AxNode` (ref+role+text `:60`) + `PageSnapshot`
  (`:69`) = the portable AX-tree shape. Intended adapters `WebKitBrowserEngine`(AppStoreSafe)/`ObscuraBrowser
  Engine`(Pro)/`Mock`/`Remote` (`:8-14`); **only Mock implemented (`:115`).** Legacy CLI "gets replaced by Wave-6
  BrowserEngine adapters" (`:16-17`).
- **v2 catalog browser specs** (`tools_v2/v2_catalog/browser_*.rs`) all `Profile::ProOnly`, `small_model_safe:
  false`; header names the planned WebKit-baseline + Obscura adapters (`browser_navigate.rs:5-10`).
- **Computer-use stack = browser-use's loop, already wired.** `DeviceAgentService.swift`:
  `resolveUIAction(axTreeJson:intent:)` `:72` → deterministic `AppleContextualActionResolver.resolve` `:479` →
  LLM fallback `:174`; `DeviceActionType` `:428` (axPress/cgClick/keyInject); `verifyAction:118` closes act→verify.
  `Screen2AXFusion.swift` = AX + Vision-OCR fusion. Live: `agent_loop.rs:982` intercepts `name=="computer"` →
  `delegate.execute_computer_action`; non-pro hard-deny `:974`.
- **MAS-safe web primitives shipped:** `web.fetch/search/extract/crawl` = `Profile::AppStoreSafe`
  (`web_fetch.rs:37`, `web_crawl.rs:49`), on the Core allowlist (`ToolTierBridge.swift:214-218`), HTTPS-via-
  URLSession, no subprocess.
- **WKWebView host kit to reuse:** `Views/Epdoc/EpdocEditorChromeView.swift` (shared `WKProcessPool` + JS bridge
  + `evaluateJavaScript`), `Views/Notes/WebKitCodeEditorView.swift`, `Views/HTMLWorkspace/HTMLWorkspacePreview
  View.swift`. (`EpistemosWebTheme` symbol **unverified** — the real hosts are these Epdoc/WebKit views.)
- **Gateway classification correct:** `LocalAgentGatewayPolicy.swift:31` `case browserComputerUse` → `.proResearch`
  "external side-effect surfaces" (`:163-171`).

## Portable algorithm vs un-portable
**Portable (clean-room, half-present):** loop = compact interactive-element snapshot with stable ref indices →
LLM picks `action(ref_id,args)` from a small DSL (click/type/scroll/press/navigate/extract) → execute →
re-snapshot; vision fallback via screenshot. Epistemos already has BOTH halves: `browser_snapshot` returns
`@e5`-style refs (`browser.rs:233-260`) + `DeviceAgentService` does AX-tree→action selection. The lift =
browser-use's `ClickableElementDetector` heuristics + numeric-index↔selector_map (re-implement clean-room);
browser-use v0.13 is Rust-cored + MIT, so liftable. **Un-portable (forbidden):** its Playwright/Chromium/CDP
subprocess backend — the current `agent-browser` CLI spawn (`browser.rs:644`) is exactly the part to replace.

## Native embedding path (honest local-first) — three options, honesty order
- **(a) WKWebView + JS evaluation — THE MAS-safe path (BUILD THIS).** In-process WKWebView (reuse Epdoc host),
  DOM via `evaluateJavaScript`/`callAsyncJavaScript` → build `PageSnapshot`/`AxNode`, dispatch synthetic events
  (`element.click()`, input value + `dispatchEvent`) in-page. = the documented `WebKitBrowserEngine`
  (AppStoreSafe). No subprocess, no entitlements, MAS-clean. **The only browser path that ships on the App
  Store build.**
- **(b) Computer-use AX/vision driving a real browser app** — `DeviceAgentService` + AXorcist + CGEvent driving
  Safari/Chrome via `AXUIElement`. Real + mature but Pro-only (Accessibility + screen-recording entitlements;
  deny `agent_loop.rs:974`). For sites WKWebView can't host; not default.
- **(c) CDP against user's own Chrome** (`BROWSER_CDP_URL` `browser.rs:121,670`) or `ObscuraBrowserEngine`
  (V8/deno_core, stealth) — Pro-only, subprocess-hardened. Obscura is doctrine-landed, **never built**.

**Design:** make `BrowserEngine` (`mod.rs:84`) the single seam; implement `WebKitBrowserEngine` for AppStoreSafe;
keep Obscura/CDP as Pro adapters; retire the `agent-browser` CLI to a Pro `RemoteBrowserEngine` fallback only.

## Everywhere (one tool, all engines)
Engine-isolation already satisfied by construction: `browser.*` registers ONCE in `register_default_tools`
(`registry.rs:2672`) into the shared `ToolRegistry`; Chat/Act(Osaurus)/Work(Goose) each bind it via the tier
ladder + `ToolTierBridge` (`:375`, mode→tier `:361`, exec via `execute_tool_call` FFI `:608`) — shared
registration+memory, independent binding, no cross-engine logic import. **To reach MAS Chat:** the WebKit
adapter's tools must be added to `coreAppStoreAllowedToolNames` (`ToolTierBridge.swift:194-235`) — today
`browser_*` are NOT on it.

## Honest gating
- **MAS-safe (App Store):** in-process `WebKitBrowserEngine` DOM read + synthetic events; `web.fetch/search/
  extract/crawl` (already AppStoreSafe). Needs the adapter + allowlist entry.
- **Pro-only:** current `agent-browser` CLI (`#[cfg(pro-build)]`), CDP-against-Chrome, Obscura, computer-use AX
  driving external apps (hard-deny non-pro `agent_loop.rs:974` + `AppStoreComputerUseStubs.swift`), `browser_
  vision` cloud egress (explicit ack `:378`).
- **No-fake enforced:** `ComputerUseTool` deliberately errors + a test asserts it's NEVER registered
  (`registry.rs:4458`).

## Ordered plan
1. **[S]** Surface the existing Pro `browser.*` family to Chat as a first-class approval-required skill
   (registration exists, just unsurfaced) + an engine-isolation guardrail test. (Prereq: the SS-H keystone
   "chats never enter the tool loop" — same gate.)
2. **[M]** Implement `WebKitBrowserEngine` against the trait (`browser_engine/mod.rs:84`): WKWebView host (reuse
   `EpdocEditorChromeView`), `evaluateJavaScript` DOM→`PageSnapshot`, synthetic-event execute; re-route
   `browser.*` through the trait instead of CLI; lift `ClickableElementDetector` (clean-room); add to
   `coreAppStoreAllowedToolNames`.
3. **[M]** Widen `DeviceActionType` (`DeviceAgentService.swift:428`) to the cua/browser-use action union
   (DoubleClick/Drag/Move/Wait) so the AX driver shares the DSL.
4. **[L]** `ObscuraBrowserEngine` (Pro, V8/deno_core, stealth) + the Sandbox seam (host/Lume-VM/Apple-container)
   for Work; per-host network allowlist + proof-of-execution receipts. All Pro/Research-gated.

## Unverified
`EpistemosWebTheme` symbol not found (real hosts = Epdoc/WebKit views). The S4 "chats never enter the tool loop"
blocker is cited from prior research (= SS-H keystone), not re-verified here. `computer_use.rs` not opened.

Key files: `agent_core/src/tools/browser.rs` (spawn+harden `:546-559`, SSRF `:220`, redact `:811-840`, CDP
`:121,670`) · `agent_core/src/browser_engine/mod.rs` (trait `:84-105`, `AxNode:60`, `PageSnapshot:69`, Mock-only
`:115`) · `agent_core/src/tools/registry.rs` (tier `:242`, browser reg `:2672-2753`) · `tools_v2/v2_catalog/
browser_navigate.rs` (`:5-10,38`) · `agent_core/src/security.rs` (`:942`) · `agent_core/src/agent_loop.rs`
(`:974-983`) · `Bridge/ToolTierBridge.swift` (`:361,375,194-235`) · `Omega/Inference/DeviceAgentService.swift`
(`:72,118,174,428,479`) · `Omega/Vision/Screen2AXFusion.swift` · `LocalAgent/LocalAgentGatewayPolicy.swift`
(`:31,163-171`) · `Views/Epdoc/EpdocEditorChromeView.swift` + `Views/Notes/WebKitCodeEditorView.swift` ·
`docs/research/COMPUTER_BROWSER_USE_2026_06_19.md` + `docs/B3_OBSCURA_BROWSER_LIFT_TARGETS_2026_05_05.md`.
