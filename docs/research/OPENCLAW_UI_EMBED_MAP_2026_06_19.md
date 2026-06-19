# OpenClaw UI Embedding Map (research, 2026-06-19)

Read-only research deliverable (subagent). Feeds R-OPENCLAW (the SwiftUI/UX ambiguity). NO code/docs were modified.

## Owner's question, answered
*"How do I make OpenClaw a SwiftUI since it's Python/other language — or is that covered since it's already an app?"*

Two premise corrections, then the answer:
1. **OpenClaw is NOT Python** — it's **TypeScript/Node (ESM)**, **MIT** (Peter Steinberger 2025). Verified at `~/Downloads/openclaw-main/{package.json,LICENSE}`.
2. **Not "already an app"** in the shippable-binary sense — it's a **gateway/client** architecture: a Node gateway server (`express`+`hono`+`ws`, `src/gateway/`) plus multiple clients.

**RECOMMENDATION: DO NOT rewrite OpenClaw in SwiftUI.** Host its existing web "control UI" (a static **Lit + Vite** bundle, `ui/`) in a `WKWebView` wrapped by a thin SwiftUI shell — reusing Epistemos's proven **Epdoc/Tiptap** embedding pattern verbatim. Re-point the UI's WebSocket `{method,params}` transport at the **in-process Rust Act engine** via the existing `AgentStreamEventDelegate` FFI + a `WKScriptMessageHandler` bridge — **no Node subprocess on the MAS path**. The Node gateway becomes an optional **Pro/Developer-ID-only** bundled service, gated exactly like `LocalGgufRuntimeBridge`.

> Subtlety to flag: OpenClaw ALREADY ships its own native SwiftUI app (`apps/macos` + `apps/shared/OpenClawKit`) — but that is a hand-written SwiftUI client that spawns Node via `GatewayProcessManager`/`RuntimeLocator`/`LaunchdManager`, signed Developer ID (NOT MAS). "Rewrite in SwiftUI" is the path OpenClaw itself took — and it's exactly what's INCOMPATIBLE with Epistemos's MAS/in-process constraints. WebView-host is the correct path.

## OpenClaw architecture (`~/Downloads/openclaw-main`)
| Concern | Finding |
|---|---|
| Runtime | TypeScript/Node ESM, Node ≥ 22.16.0 (`RuntimeLocator.swift:57`) |
| License | **MIT** (permissive) |
| Web UI | **Lit** + Vite, vanilla TS, `marked`/`dompurify`/`@noble/ed25519`; entry `ui/index.html`→`ui/src/main.ts`→`ui/src/ui/app.ts`; `name: openclaw-control-ui` |
| Backend | long-lived Node "gateway" (`express`+`hono`+`ws`), `src/gateway/server-http.ts` |
| Transport | **WebSocket** carrying JSON `{method,params}` control-plane (+ some HTTP tools-invoke) |
| Existing native clients | SwiftUI macOS + iOS sharing `OpenClawKit` (`OpenClawChatUI`), connect to gateway over WS; `ChatTransport.swift` = `protocol OpenClawChatTransport { events()->AsyncStream; sendMessage; listModels }` |
| Node acquisition | locate user/bundled Node, spawn gateway subprocess, manage via launchd; Developer-ID signed, NOT MAS |

**Embeddable asset = the `ui/` subtree.** Self-contained Lit/Vite (no `src/gateway` needed to build the frontend).

## Epistemos embedding template to copy (Epdoc/Tiptap)
- SwiftUI shell + `NSViewRepresentable` host: `Epistemos/Views/Epdoc/EpdocEditorChromeView.swift` — `EpdocTiptapWebView` (604–649): `WKUserContentController` named handler, injected theme `WKUserScript` `.atDocumentEnd`, `config.setURLSchemeHandler`, loads `epistemos-doc:///editor.html`; `Coordinator: WKScriptMessageHandler` does inbound `handleInbound` + outbound display-link-coalesced `evaluateJavaScript`; `dismantleNSView` (675) tears down to avoid the 40–60 MB leak.
- Custom URL scheme = the bundling mechanism: `Epistemos/Engine/EpdocEditorBridge.swift` — `epdocEditorURLScheme="epistemos-doc"`; `EpdocEditorURLSchemeHandler: WKURLSchemeHandler` (187) maps scheme→`Bundle.main/Resources/Editor/`, **decompresses Brotli `.br` server-side** (258–303, custom scheme doesn't auto-decode `Content-Encoding: br`); comment (176–185) documents why `loadFileURL` is rejected under hardened runtime.
- Build-time bundling (NEVER runtime): `build-tiptap-bundle.sh` — `npm ci`+bundle at Xcode build time, `rsync dist/`→`Epistemos/Resources/Editor/`. Canon (lines 8–11 + CLAUDE.md "JS Bundle"): **NEVER spawn npm at runtime — MAS sandbox + hardened runtime block subprocess.**
- Health-row precedent: `EditorBundleHealthRow` (path/size/last-build).

## Concrete plan
1. **Build-time bundle** `build-openclaw-ui-bundle.sh` (sibling of tiptap script, wired into `project.yml` preBuildScripts): vendor `~/Downloads/openclaw-main/ui`, lock-hash gate, `vite build`→`ui/dist/`, `rsync`→`Epistemos/Resources/OpenClawUI/`, optional Brotli+prune, sanity-check `index.html`. No Node in the shipped app.
2. **SwiftUI shell + WKWebView** mirroring the Epdoc trio: `OpenClawHostView.swift` (window/chrome) + `OpenClawWebView: NSViewRepresentable` (handler named `openclaw`, theme script, scheme `epistemos-openclaw`, loads `:///index.html`) + `OpenClawUIURLSchemeHandler` (copy of Epdoc handler, `assetSubpath="OpenClawUI"`, keep Brotli branch) + Coordinator with `dismantleNSView`. ONE deliberate divergence: OpenClaw UI uses `local-storage.ts` → use a **persistent app-scoped** `websiteDataStore`, not Epdoc's `.nonPersistent()`.
3. **Re-point the transport (the real work):** injected `.atDocumentStart` `WKUserScript` defines `window.openclawBridge.send(method,params)`→`postMessage` and `.emit(event)` for streams; shim the module that does `new WebSocket(...)` (`ui/src/ui/app-gateway.*`/`device-auth.ts`) so `connect()` resolves against the bridge. (Clean seam — `OpenClawChatTransport` already proves non-WS transports are sanctioned.) Swift `handleInbound` decodes `{method,params,id}` → dispatches to the in-process engine via `AgentStreamEventDelegate` (`Epistemos/Bridge/StreamingDelegate.swift`: `onTextDelta/onToolStarted/onToolCompleted/onThinkingDelta/onComplete/onPermissionRequired`). Method map: `chat.send`→agent run on `agent_core::agent_runtime` (stream deltas back via coalesced `evaluateJavaScript`); `models.list`→`InferenceState+RouteProfiles`; `chat.abort/sessions.*`→`agent_core/src/session.rs`; tool/permission prompts→`onPermissionRequired`→Epistemos permission gate + `SovereignGate`.
4. **Pixel-art reskin via CSS injection** (reuse `EpdocEditorThemeStyle.applyScript`): ship `Resources/OpenClawUI/pixel-theme.css`, inject a `<style>` via `WKUserScript`, drive vars from `EpistemosTheme.resolved`, set `data-epistemos-skin="pixel"` at document start. OpenClaw renders via `dompurify`+`marked` (stable DOM) → pure-CSS skin, no render-code fork.
5. **Honest Pro/dev gate for the Node backend** (mirror `Epistemos/Bridge/LocalGgufRuntimeBridge.swift`): web UI + in-process engine need NO Node. OpenClaw's full gateway feature set (multi-channel `src/channels/*`, voice, cron, MCP gateway methods) = bundled Node service → CANNOT run on MAS. Compile launch code under `#if !EPISTEMOS_APP_STORE`, cargo `pro-build` only, ship OFF behind a flag (cf. `EPISTEMOS_LOCAL_GGUF_CLI_RUNTIME_V0`), subprocess (if ever) through `agent_core/src/security.rs` `harden_cli_subprocess`. MAS build shows chat working on in-process engine; gateway-dependent panes render disabled "Pro · Developer build only" (never fake-working). Add `OpenClawGatewayHealthRow` (bundle path/size/last-build, build channel, flag state, Pro Node-detection).

## Rewrite vs WebKit-host — verdict
WebKit-host wins on every axis: days not months (reuse Epdoc), upstream-trackable (`git pull ui/` + rebuild), MAS-legal (static bundle + in-process engine), theming via the CSS mechanism already in use, and a working in-repo precedent. Rewriting discards the MIT UI you're adopting and duplicates OpenClaw's own native-app effort — the effort that forced THEM into non-MAS + Node subprocess. SwiftUI's role is correctly minimized to window + chrome + theme tokens.

## ProvenanceGate
OpenClaw = **MIT** → permissive (one of the 7 accepted classes; trips no copyleft/no-license fixture). `ui/` subtree → **`direct_import`** (verbatim bundle + MUST carry attribution + local tests; preserve MIT `LICENSE`+copyright in `Resources/OpenClawUI/` + `THIRD_PARTY_LICENSES` entry). Node gateway (if vendored, Pro) → `direct_import`/`adapter_wrap` but capability stays `research_only`/Pro-gated until owner approval + MAS/Pro boundary review + no-hidden-fallback proof + RunEventLog/AnswerPacket/rollback witnesses. Consciously avoid the gate's red fixtures: MAS/Live leakage (gateway must never reach MAS build) + product-green promotion (no "done" until T4: compiled-in-scope, reachable, visible, logged, rollback-bound, AnswerPacket-visible). Gate: `docs/falsifiers/F-ProprietaryCompression-ProvenanceGate_2026_06_06.md` + `Tools/falsifiers/f_proprietary_compression_provenance_gate.sh`.

## Key files
OpenClaw: `~/Downloads/openclaw-main/{LICENSE,package.json,ui/package.json,ui/index.html,ui/src/main.ts,ui/src/ui/app-gateway.*,src/gateway/server-http.ts,apps/macos/Sources/OpenClaw/RuntimeLocator.swift,apps/shared/OpenClawKit/Sources/OpenClawChatUI/ChatTransport.swift}`.
Epistemos template: `Epistemos/Views/Epdoc/EpdocEditorChromeView.swift`, `Epistemos/Engine/EpdocEditorBridge.swift`, `build-tiptap-bundle.sh`, `Epistemos/Bridge/StreamingDelegate.swift`, `Epistemos/Bridge/LocalGgufRuntimeBridge.swift`, `Epistemos/Sovereign/SovereignGate.swift`.
