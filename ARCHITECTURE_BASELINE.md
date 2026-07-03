# ARCHITECTURE_BASELINE.md — Epistemos (Phase 0)

> Ground truth assembled 2026-07-02 from git + build system + the seven Phase-0 audit sweeps. Non-Goose scope (Goose lane documented at boundaries only). Every claim traces to a sweep in HARDENING_AUDIT.md or a file:line.

## Toolchain + build
- Xcode 26.4.1 (17E202), Swift 6.3.1 toolchain, macOS 26.3.1. Directive targets Swift 6.2+ semantics — toolchain exceeds it.
- Source of truth: **xcodegen `project.yml`** (never edit Epistemos.xcodeproj directly). No xcconfig files.
- Schemes: `Epistemos` (direct-dist, com.epistemos.app), `Epistemos-AppStore` (MAS, com.epistemos.appstore). Launch=Debug, Archive/Profile=Release.
- Build state (this session): Debug `Epistemos` = **GREEN, 10 warnings** (6 in-scope, 2 vendored MarkEdit concurrency, 2 Goose). Release `Epistemos-AppStore` = **was RED (Float16 x86_64, F-0003, fixed), rebuild in flight**.
- Build phases (both app targets, "run every build" — not dependency-gated): Build Rust Engine, Bundle Runtime Assets; AppStore adds Scrub Pro Frameworks (removes libomega_ax.dylib, AXorcist.framework, llama.framework).

## Target / module graph
- **Epistemos (app, SwiftUI lifecycle)** — `@main struct EpistemosApp: App` + `@NSApplicationDelegateAdaptor`, one WindowGroup. 768 non-test Swift files, 500 test files. NOT the AppKit shell the directive assumes — it's a SwiftUI-lifecycle hybrid with AppKit at the edges (NSPanels, 24 NSViewRepresentable + 1 NSViewControllerRepresentable: MetalGraphView, WKWebViews, terminal).
- **Epistemos-AppStore** — same sources minus the Pro/automation lane (ScreenCapture/AX/AppleEvents compiled out via `#if !EPISTEMOS_APP_STORE`; browser-use + computer-use + code-exec + Work terminal gated out).
- **EpistemosWidgets** — app-extension, NO entitlements file, NOT embedded in either app (SEC-6).
- **Local SwiftPM packages (app-owned):** GGUFRuntimeBridge, KokoroPipeline (Plan 3 voice; no swiftSettings/language-mode overrides). Vendored: MarkEdit (+MarkEditKit/Mac/Modules), SwiftTerm, vmlx-swift, plus SPM deps (GRDB, Grape, swift-nio stack, mlx-swift, AXorcist, yyjson, swift-syntax…).
- **Rust: 13 crate roots, no top-level workspace, each own Cargo.lock:** agent_core (in-process agent runtime — the app's own, distinct from Goose), epistemos-core, epistemos-shadow (tantivy+usearch+RRF search), epistemos-vault, epistemos-code-index, epistemos-research, graph-engine (Metal knowledge graph), omega-ax, omega-mcp, substrate-core, substrate-rt, syntax-core, bench. Built via build-rust.sh + build-*.sh; embedded as signed dylibs.

## Actor topology
- **Default actor isolation = MainActor globally** (SWIFT_DEFAULT_ACTOR_ISOLATION), Swift 6.0 language mode, complete strict concurrency — every unannotated declaration is MainActor-isolated; off-main work is explicitly `nonisolated`/actor (drives 3,143 `nonisolated` occurrences).
- Actors present: KnowledgeCoreBridge, LSPClient, ShadowSearchService/ShadowIndexingService, MetalComputeEngine, plus lock-guarded @unchecked-Sendable service singletons (96 `static let shared`).
- AppKit state (NSView/NSWindow/NSViewController: MetalGraphView, ProseTextView2, editors) is MainActor by default + `nonisolated(unsafe)` for deinit plumbing.
- Counts (non-test): 85 @unchecked Sendable, 72 nonisolated(unsafe), 142 Task.detached, ~429 Task{}, 55 AsyncStream, 51 AsyncThrowingStream, 28 checked continuations, 59 assumeIsolated, 1134 @MainActor. Findings → CONC-1..20.

## FFI surface (Swift↔Rust — boundary B4)
- **UniFFI:** agent_core/src/bridge.rs = 96 `#[uniffi::export]` (79 ffi_guard-wrapped: catch_unwind→AgentErrorFFI); epistemos-core, omega-ax, omega-mcp also UniFFI. Generated bindings post-processed by **patch-uniffi-bindings.py** (rewrites to `nonisolated` under default-MainActor — the UniFFI isolation gotcha is already handled as a deterministic build step).
- **Raw extern "C" / @_silgen_name:** graph-engine 168, agent_core 30, epistemos-shadow 18, substrate-core 14, syntax-core 13, substrate-rt 11, epistemos-code-index 5. Swift side: 73 `@_silgen_name` across 9 client files (all Swift→Rust pull calls; no Rust→Swift function-pointer registration).
- **Rust→Swift callbacks** (StreamingDelegate computer-use/askUser): `Task { @MainActor }` + DispatchSemaphore.wait(300s) with `.notOnQueue(.main)` precondition; SCStream frames hop via `DispatchQueue.main.async`. **Zero `DispatchQueue.main.sync`** in scope (repo rule holds).
- Panic-across-FFI: no crate UB-unwinds into Swift (catch_unwind → error sentinel; epistemos-core/omega-mcp/substrate-core documented panic=abort).

## JS bridge catalog (boundary B1 — complete, non-Goose)
All handlers in the **page (default) content world**; every decoder fail-closed.
| Handler | Registered | Webview | Validation |
|---|---|---|---|
| epdoc | EpdocEditorChromeView.swift:717 | Epdoc editor | typed enum, bounded, image→content-hash rename+ext-whitelist |
| epistemosMarkEditCoreEditor | MarkEditCoreEditorView.swift:510 | CoreEditor | isMainFrame + [String:Any] |
| bridge (WithReply) | MarkEditCoreEditorView.swift:514 | CoreEditor | isMainFrame; canned-deny all file/save/open |
| epistemosCodeEditor | WebKitCodeEditorView.swift:54 | code editor | isMainFrame + kind switch |
| htmlWorkspaceSafeAPI | HTMLWorkspacePreviewView.swift:213 | HTML Workspace | gated; fixed allowlist; diagnostic/echo only |
| epistemosWorkspaceConsole | HTMLWorkspacePreviewView.swift:220 | HTML Workspace | gated by console flag |
| epistemosWorkspaceInspector | HTMLWorkspacePreviewView.swift:228 | HTML Workspace | gated by inspector flag |
| bridge (vendored) | EditorViewController.swift:141 | MarkEdit host (default md path) | vendored 7 native modules |
Browser + BrowserUse webviews register **zero** handlers.

## WKWebview instances (10)
Human Browser (BrowserView.swift:416, ephemeral, BrowserURLGuard), KaTeX preview (EpdocKaTeXPreview.swift:78, no nav delegate), Epdoc editor (EpdocEditorChromeView.swift:742, **no decidePolicyFor — WEB-1**), HTML Workspace preview (HTMLWorkspacePreviewView.swift:235, strong CSP), CoreEditor host (MarkEditCoreEditorView.swift:520), legacy code editor (WebKitCodeEditorView.swift:59), MarkEdit vendored host (EditorViewController.swift:154, **isInspectable=true unconditional — WEB-2**, CORS disabled — WEB-3), headless PDF export (WebPage), Work SPA (WebPage), BrowserUse loopback (BrowserUseWebUIView.swift:445, isolated named store, origin-pinned). No process pool set anywhere (EpdocWebViewShared.processPool removed — CLAUDE.md stale). CSP present only on HTML Workspace; missing on editor.html/code-editor.html/CoreEditor index.html (WEB-4).

## Entitlements (3 files)
| Key | Epistemos (direct) | Debug | AppStore (MAS) |
|---|---|---|---|
| app-sandbox | ABSENT | false | **true** |
| cs.allow-unsigned-executable-memory | **true** | true | — |
| cs.disable-library-validation | **true** | true | — |
| cs.allow-jit | true | true | true (MLX Metal JIT) |
| network.client / network.server | true / **true** | — | true / **true** |
| files.user-selected.read-write | true | — | true |
| files.bookmarks.app-scope | true | — | true |
| automation.apple-events | true | — | — |
| temporary-exception.mach-lookup (a11y.api) | true | — | — |
| **com.apple.security.device.audio-input** | **ABSENT** | ABSENT | **ABSENT (MEET-3 — mic dead in all shipped builds)** |
Direct-dist stacking (no-sandbox + disable-library-validation + unsigned-exec-mem + network.server) = SEC-1. MAS entitlements are clean of both dangerous keys.

## Privacy strings + MAS
NSMicrophone/NSSpeechRecognition/NSDocuments/NSDesktop/NSDownloads (MAS plist, honest text); direct plist adds NSAccessibility/NSScreenCapture/NSAppleEvents (Omega, #if-gated out of MAS). ITSAppUsesNonExemptEncryption=false (both). PrivacyInfo.xcprivacy: tracking=false, 0 collected-data types, 4 valid required-reason codes. No analytics/telemetry SDK (only a tracker blocklist).

## Network endpoints
HTTPS only (ATS default, 0 exceptions, 0 cleartext remote). Cloud: api.anthropic.com, api.openai.com (+OAuth), generativelanguage.googleapis.com, api.perplexity.ai, export.arxiv.org, huggingface.co, api.browser-use.com, provider-catalog defaults; Rust adds openrouter/together/groq/mistral/research tools + gateway integrations. Timeouts: Rust 300s+retry, arXiv 15s, Kokoro SHA256-verified; gaps SEC-3 (Swift LLMService), RUST-4 (epistemos-core).

## Local servers / sockets (boundary B8) — VERIFIED
- **Shipped MAS build: ZERO listening sockets** (verified sweep).
- agent_core channel relay (axum 127.0.0.1:8787) — pro-build+channel-relay-tools gated, manual-launch binary only, never started by the in-app dylib.
- browser-use Gradio (python 127.0.0.1:7788) — Dev-ID Pro only, compiled out of MAS, loopback-pinned, no auth token.
- OAuth callback (CloudProviderAuthService.swift:514), VaultMCPServer/WorkNativeMCPServer/WorkSPAServer loopback (pro/work; DNS-rebinding defense present).

## Feature flags (non-Goose)
`EPISTEMOS_ARXIV_PULL_V0` (default ON, kill-switch), `EPISTEMOS_BROWSER_USE_PRO_V0` (default OFF + #if MAS hard-off), `EPISTEMOS_KOKORO_VOICE_PRO_V0` (default OFF), Meetings (no flag — macOS26+mic gate), `EPISTEMOS_APP_STORE`/`MAS_SANDBOX` (compile-time), plus RRF_FUSION_V1/DEEP_RESEARCH_V0/LITEPARSE_PDF_V0/EIDOS_V0/WORK_OPENCODE_V0. All honest both directions (no background work when off; boot constructs only the passive TextCapturePipeline). Goose flags (EPISTEMOS_GOOSE_BACKEND/NATIVE_ROUTES) = out of scope.

## Manual smoke pass
DEFERRED to after the release build + full test suite complete (app not launched this session yet). Feature classifications from static audit: MEETINGS=HALF-WIRED (mic dead outside Debug per MEET-3; 2 data-loss criticals MEET-1/2), ARXIV=WORKING-WIRED, BROWSER=WORKING-WIRED (lifecycle gaps). Recorded here as the Phase-0-exit gap to close once a runnable build exists.

## Phase 0 exit status
Baseline captured ✅ · ARCHITECTURE_BASELINE.md complete ✅ · THREAT_MODEL.md (B1–B8) ✅ · PLAN_AUDIT.md ✅ · failures classified (F-0003 fixed; full-suite-red = pending self-rerun+triage) ✅ · smoke pass = DEFERRED (needs runnable build) ⏳.
