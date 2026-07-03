# APP_REVIEW_NOTES.md — Epistemos (Mac App Store)

> For Apple App Review + internal MAS-readiness. Written 2026-07-02 during the enterprise-hardening pass. Two entitlement files ship: `Epistemos.entitlements` (direct-distribution / Developer-ID lane) and `Epistemos-AppStore.entitlements` (the MAS submission — this is the file Review sees). "PENDING FIX" items are tracked in HARDENING_AUDIT.md and will be applied in Phase 4 before submission.

## What the MAS build is
- App Sandbox: **ON** (`com.apple.security.app-sandbox = true`). Hardened Runtime ON, no `disable-library-validation`, no `allow-unsigned-executable-memory` in the MAS entitlements (verified — both dangerous keys are absent from Epistemos-AppStore.entitlements).
- Cloud-only LLM inference over HTTPS; on-device Apple SpeechAnalyzer for dictation/meeting transcription; local Metal-rendered knowledge graph; WKWebView UI surfaces.
- The MAS build **compiles out** the automation/Pro lane: ScreenCaptureKit, Accessibility automation, AppleEvents, browser-use (Python subprocess), computer-use, code-execution, and the Work terminal are all behind `#if !EPISTEMOS_APP_STORE` / `#if EPISTEMOS_APP_STORE || MAS_SANDBOX` and are removed from the submitted binary. A "Scrub Pro Frameworks" build phase additionally strips libomega_ax.dylib / AXorcist.framework / llama.framework.

## Entitlement justifications (MAS build — Epistemos-AppStore.entitlements)

| Entitlement | Present | Why it is needed | Review note |
|-------------|---------|------------------|-------------|
| `com.apple.security.app-sandbox` | ✅ true | Required for MAS. | — |
| `com.apple.security.files.user-selected.read-write` | ✅ true | The user picks a vault folder (notes/research) via NSOpenPanel; the app reads/writes markdown + PDFs there. | User-initiated folder selection only. |
| `com.apple.security.files.bookmarks.app-scope` | ✅ true | Persist access to the chosen vault across launches (security-scoped bookmark). | Start/stop access is paired (audited). |
| `com.apple.security.network.client` | ✅ true | Outbound HTTPS to cloud LLM providers (Anthropic/OpenAI/etc.), arXiv, HuggingFace model downloads. | HTTPS only; no ATS exceptions. |
| `com.apple.security.network.server` | ✅ true | Loopback listeners used by in-app features (OAuth sign-in callback; loopback MCP/Work surfaces). **No non-loopback bind; no listening socket in the default runtime path.** | See "Local servers" below. Confirm still required for the MAS feature set in Phase 4; if only the OAuth callback needs it, keep it, else remove. |
| `com.apple.security.cs.allow-jit` | ✅ true | MLX / Metal shader JIT compilation for on-device compute (graph + any local model work). | Standard for Metal-compute apps. |
| `com.apple.security.application-groups` (`group.com.epistemos.shared`) | ✅ | Shared container for the app + (future) widget. | **PENDING VERIFY (SEC-8):** confirm the group ID is registered to the team, or prefix with TeamID, before submission. |
| **`com.apple.security.device.audio-input`** | ❌ **MISSING** | **REQUIRED** — the app ships dictation + meeting-note capture (mic → on-device SpeechAnalyzer). Without it the sandbox denies the mic and the feature is silently dead. | **PENDING FIX (SEC-2 / MEET-3):** add `= true`. NSMicrophoneUsageDescription + NSSpeechRecognitionUsageDescription are already present. |

Removed / absent by design (least privilege): no `files.all`, no `files.downloads`, no `device.camera`, no `personal-information.*`, no `cs.disable-library-validation`, no `cs.allow-unsigned-executable-memory`, no temporary exceptions.

## Direct-distribution lane (Epistemos.entitlements) — NOT the MAS build
This Developer-ID lane is more permissive (no sandbox; `cs.disable-library-validation`; `cs.allow-unsigned-executable-memory`; `automation.apple-events`; a `temporary-exception.mach-lookup` for the accessibility API) because it hosts the Pro automation features. **SEC-1 (HIGH)** tracks tightening it (drop the two dangerous code-signing exceptions — the MAS build proves MLX runs without them). **SEC-5** tracks removing the inert temporary-exception + sandbox-scoped keys that don't belong in a no-sandbox file. None of this affects the MAS submission.

## Privacy usage strings (accurate + human)
- NSMicrophoneUsageDescription — "…dictate quick captures using local models."
- NSSpeechRecognitionUsageDescription — "…transcribe voice input into your notes and chats."
- NSDocumentsFolder / NSDesktopFolder / NSDownloadsFolder — "only for vaults and files you explicitly choose."
- (Direct lane only, compiled out of MAS: NSAccessibility, NSScreenCapture, NSAppleEvents.)
All strings map to a real, user-initiated feature. Permissions are requested at the moment of use (mic access is requested inside record-start, not at launch — verified).

## Encryption (export compliance)
`ITSAppUsesNonExemptEncryption = false` in both Info.plists. The app uses only HTTPS (system TLS) and CryptoKit hashing (SHA-256/BLAKE3) — no proprietary or non-exempt encryption. Answer stands.

## Private API / KVC note
`BRW-3` (LOW): the browser + browser-use webviews set `drawsBackground` via private KVC on WKWebView (`setValue(false, forKey:"drawsBackground")`). Flagged for Phase 4 as an App Review / OS-update risk; will be replaced with a supported approach (`underPageBackgroundColor` / layer background) or removed before submission.

## Local servers (sandbox + trust)
Verified fact from the Rust audit: **the shipped MAS build opens zero listening sockets.** The only HTTP server in the codebase (agent_core channel relay, 127.0.0.1:8787) is compiled only into a `pro-build` binary that MAS never includes and that the in-app dylib never launches. browser-use's local Gradio server (127.0.0.1:7788) is Dev-ID-only and compiled out of MAS. The `network.server` entitlement in the MAS build covers loopback OAuth-callback / local MCP surfaces only.

## Data handling
- API keys / OAuth tokens: **macOS Keychain only** (kSecUseDataProtectionKeychain, AfterFirstUnlockThisDeviceOnly, non-synchronizable). Never in UserDefaults/plists/logs. Verified — zero real secrets in the repo.
- Meeting audio is transient (never written to disk); transcripts/notes live in the user's chosen vault, in-container, with the standard note-delete affordance.
- No third-party analytics/telemetry SDK; PrivacyInfo.xcprivacy declares tracking=false, zero collected-data types, and four correctly-coded required-reason APIs.

## Known items being fixed before submission (see HARDENING_AUDIT.md)
1. SEC-2 / MEET-3 — add `device.audio-input` (mic feature currently non-functional in the sandboxed build).
2. SEC-8 — verify the app-group identifier is team-registered.
3. SEC-4 — stop logging user search queries / note filenames at `.public`.
4. BRW-3 — remove the private `drawsBackground` KVC.
5. MEET-1 / MEET-2 — meeting-transcript truncation + persistence-failure data-loss (MEET-2 fixed; MEET-1 in Phase 9).
6. WEB-2 — ensure `isInspectable` is false in release on the notes editor webview.
