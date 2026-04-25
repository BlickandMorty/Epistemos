# Epistemos — Mac App Store Review Notes

Date: 2026-04-25
Bundle: `Epistemos-AppStore.app`
Build profile: MAS (sandboxed, `EPISTEMOS_APP_STORE` + `MAS_SANDBOX` compile flags)

This document explains entitlement choices for App Review. Attach to the
submission notes field in App Store Connect.

## 1. JIT entitlement (`com.apple.security.cs.allow-jit`)

**Why we use it**: Epistemos performs **on-device machine-learning inference** using Apple's MLX framework (mlx-swift, mlx-swift-lm). MLX compiles GPU compute pipelines (Metal shaders) at runtime when a local model is first loaded. This requires `allow-jit` because Metal's shader compiler emits executable code into a Mach-O code page allocated by the runtime.

**What we do NOT do with it**:
- We do NOT compile or execute user-supplied code, scripts, or expressions.
- We do NOT load remote code or web content into a JIT-capable surface.
- We do NOT use a JavaScript engine or general-purpose interpreter that compiles user input.
- We do NOT use the entitlement to bypass code signing or to load unsigned dylibs.

**What we use the entitlement for**:
- MLX shader compilation for on-device LLM inference.
- Metal Performance Shaders graph compilation for graph-engine rendering on Apple Silicon.

**References**:
- Apple Developer Documentation: "Allowing JIT Compilation for ARM-Based Apps".
- MLX-Swift package: https://github.com/ml-explore/mlx-swift
- MLX-LM package: https://github.com/ml-explore/mlx-swift-examples

## 2. Sandbox (`com.apple.security.app-sandbox = true`)

We are fully sandboxed in the App Store profile. All file access goes through user-selected files and folders, persisted via `com.apple.security.files.bookmarks.app-scope`. No general filesystem access. No automation entitlements. No accessibility bypass.

## 3. File access entitlements

- `com.apple.security.files.user-selected.read-write` — for vault folders the user explicitly opens via the system picker.
- `com.apple.security.files.bookmarks.app-scope` — to remember the user's chosen vault across app launches.
- We do NOT use `com.apple.security.files.bookmarks.document-scope` in the App Store build.

## 4. Network entitlement (`com.apple.security.network.client`)

For optional cloud AI providers (Anthropic, OpenAI, Google, Perplexity). All API requests are user-initiated. API keys are stored in the macOS Keychain (never in `UserDefaults`) and are scoped to the matching provider only. Users can opt out of cloud entirely and use local models.

## 5. What is NOT in the App Store build

The following are excluded at compile time (`#if !EPISTEMOS_APP_STORE`) AND at link time (post-build scrub of `libomega_ax.dylib` + `AXorcist.framework`):

- Accessibility tree walking (`omega-ax`).
- Apple Events / AppleScript automation.
- Screen capture (ScreenCaptureKit).
- Bash / shell / Docker subprocess tools.
- iMessage inbound integration.
- Computer-use stack (Phase 4 bridge, VisualVerifyLoop, AXMutationDetector).
- Python virtual environment / pip operations.
- External DCC integration via Apple Events.

These features only exist in our direct-distribution Pro build, never in the App Store binary.

## 6. Privacy

- `PrivacyInfo.xcprivacy` declares: file timestamp (display), system boot time (elapsed time), disk space (storage info), user defaults (app-local settings).
- No user tracking. No tracking domains. No data collection categories declared.
- All user notes, embeddings, and chat history stay on the user's Mac. The app contacts our servers only if the user enables a cloud AI provider, and then only that provider's published endpoint.
- We have a built-in **Privacy** pane in Settings that surfaces all of this transparency to the user.

## 7. Verification

- The Swift app calls `verifyAgentCorePolicyProfile()` at startup (`Epistemos/App/AppBootstrap.swift:2686-2704`). The MAS build will fatal if the linked Rust agent core is not the `mas_sandbox`-feature variant.
- Drift detection: `EpistemosTests/AppStoreHardeningTests.swift` (16-test suite) enforces every entitlement and Info.plist key on every CI run.
- Privacy manifest drift: `AppStoreHardeningTests.swift:74-85` enforces the `PrivacyInfo.xcprivacy` shape on every CI run.

## 8. Reviewer-facing demo flow

To exercise the local-only path (no JIT triggered):
1. Launch the app.
2. Create a vault.
3. Create a note. Type. Save.
4. Search for the note (FTS5).
5. Open the graph view. Pan + zoom.
6. Open Settings → Privacy. Verify the transparency content matches this document.

To exercise the JIT path:
1. Open Settings → AI → Local Models.
2. Enable a small local model (e.g., a 1B parameter model).
3. The first message in chat triggers MLX shader compilation (the JIT use).
4. All subsequent messages reuse the compiled shaders.

No user input is ever compiled or executed.

---

Contact for App Review questions: (developer email).
