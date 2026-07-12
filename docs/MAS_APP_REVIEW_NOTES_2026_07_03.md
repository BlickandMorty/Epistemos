# Epistemos — Mac App Store Review Notes (MAS June / KEELSTONE)

**Draft for App Review submission. Adapt at submission time.** The product
description below reflects the MAS-only `Epistemos-AppStore` source boundary
(`EPISTEMOS_APP_STORE` + `MAS_SANDBOX`) on July 10, 2026. Replace the
verification section with the exact distribution-signed archive and App Store
Connect build before submission.

## What the app is

Epistemos is a self-contained, sandboxed research-and-writing assistant. It
has one active Mac App Store product surface:

- **MAS June chat/agent surface.** A native Swift/AppKit/SwiftUI experience
  with an in-process Rust `agent_core` policy profile compiled for
  `mas_sandbox`. June can use a user-selected OpenAI or Anthropic model over
  direct HTTPS, Apple Intelligence when available, or one of the app's three
  selected local GGUF chat models.
- **Vault, notes, graph, and writing tools.** User-created vault files remain
  ordinary user-selected files/folders accessed through the macOS open panel
  and security-scoped bookmarks. Derived indexes and caches are not the source
  of truth.
- **Optional local model data.** Users may explicitly download a verified GGUF
  language-model file or checked Kokoro Core ML voice package into the app's
  Application Support container. The native inference runtimes are compiled
  into the app; downloaded model files are data and cannot add executable code.

## Guideline 2.5.2 — self-contained, no downloaded/executed code

- All agent logic and every tool are compiled into the app. It does **not**
  download or install executable code and cannot load a native plug-in or add
  agent/tool authority at runtime. User-authored HTML workspace documents may
  render only inside the app's bundled, policy-restricted WKWebView preview;
  they do not become native extensions, subprocesses, or tools.
- The pinned b9870 llama.cpp framework and Kokoro Swift/Core ML loader are
  bundled, signed native code. Optional GGUF and Kokoro packages are model data, not executable code. Downloads use HTTPS, stay in the app container,
  and must pass declared byte-count and SHA-256 checks before use.
- June's local GGUF catalog is limited to Qwen3 4B, Qwen3 8B, and Qwen2.5 7B.
  The app does **not** download a runtime, load a plug-in, JIT-compile model
  code, or start a model server.
- The App Store build excludes MLX/JIT inference, Python/Pyodide,
  terminal/code-execution tools, browser automation, Chromium,
  OpenCode/Codex command-line runtimes, stdio MCP bridges, and local-server
  sidecars.
- The app spawns **no subprocesses**, runs **no shell**, opens **no listening
  ports / runs no local server**, uses **no AppleScript/Apple Events**, and
  does not use the Accessibility API. Parked development-lane source is
  compile-excluded and its runtime assets are removed from the MAS bundle.
- The MAS June tool set is a fixed, in-binary allowlist: vault read/write (via
  the standard open panel + security-scoped bookmarks), in-app document and
  knowledge search flows, and a fixed set of remote HTTPS services. There is no
  "add MCP server", no extension installer, and no deep-link installer.

## Guideline 5.1.2(i) — third-party AI consent (Nov-2025)

Provider-specific cloud consent is off by default. MAS Settings names OpenAI or
Anthropic, the destination host, the content categories June may send, and the
Keychain boundary. The user must explicitly enable the provider toggle; the
final June cloud-admission seam checks that preference before constructing the
`agent_core` provider stream. Consent is revocable in Settings, and an absent
consent produces a visible "Nothing was sent" error. Local Apple/GGUF/Kokoro
operations do not transmit prompt or vault content to a cloud provider. The
standard OpenAI and Anthropic API policies may retain inputs/outputs for up to
30 days unless the user's provider organization has separate retention
controls; the disclosure does not assume zero-data-retention status.

Policy sources checked July 10, 2026: [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/),
[Apple App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/),
[OpenAI API data controls](https://platform.openai.com/docs/models/default-usage-policies-by-endpoint), and
[Anthropic commercial data retention](https://privacy.anthropic.com/en/articles/7996866-how-long-do-you-store-my-organization-s-data).

## Guideline 2.4.5 — self-contained, no background persistence

Sandboxed; no auto-launch; no background daemon. The active MAS June cloud path
does not require an Epistemos subscription/proxy. The user-supplied OpenAI and Anthropic API keys are stored in macOS Keychain and are used only for direct
requests to the selected provider. No provider key is embedded in the binary
or exposed to June JavaScript, and no app telemetry is sent to an
Epistemos-operated server.

## Entitlements (this build)

- `com.apple.security.app-sandbox` — yes
- `com.apple.security.network.client` — yes (OpenAI/Anthropic requests plus
  explicit optional model-data downloads from Hugging Face)
- `com.apple.security.files.user-selected.read-write` +
  `com.apple.security.files.bookmarks.app-scope` — yes (the vault folder)
- `com.apple.security.application-groups` — yes (`group.com.epistemos.shared`,
  used for app-group state shared by the main app surface)
- `com.apple.security.device.audio-input` — yes (user-initiated dictation,
  quick capture, and meeting transcription; `NSMicrophoneUsageDescription` and
  `NSSpeechRecognitionUsageDescription` are present)
- `com.apple.security.network.server` — **not set** (native UI needs no
  loopback)
- JIT / unsigned-executable-memory / disable-library-validation — **none**
  (local inference uses bundled signed native code and requires no JIT)
- `Info.plist: ITSAppUsesNonExemptEncryption` = false (standard HTTPS via
  URLSession is export-exempt)
- `Info.plist: LSApplicationCategoryType` =
  `public.app-category.productivity`
- `PrivacyInfo.xcprivacy` declares required-reason APIs for file timestamp,
  system boot time, disk space, and user defaults; tracking is false, tracking
  domains are empty, and the optional cloud lane declares linked Other User
  Content plus provider User ID for App Functionality, both non-tracking.

## Current verification boundary (replace before submission)

- Low-memory source evidence on July 10: Swift source/test parsing, pinned
  llama artifact verification, Xcode project/package linkage comparison,
  App Review source audit, and the complete KEELSTONE source gate pass.
- The current June web stage was rebuilt with TypeScript/Vite, contains the
  visible `June models` label, and passes the staged Prompt Forge/Hermes and
  forbidden-asset scans.
- The retained July 10 privacy-manifest archive predates the restored GGUF
  linkage, cloud-consent enforcement, and current June web stage. It is useful
  historical evidence only and must not be cited as the submission build.
- **Still required:** a fresh resource-bounded `Epistemos-AppStore` Release
  archive, exact bundle scan, codesign/entitlement inspection, local framework
  slice/signing proof, visible consent grant/revoke proof, a blocked-no-consent
  network witness, matching App Store Connect privacy answers, and final App
  Store distribution signing/upload checks.

## Open-ended AI behavior

June is private embedded functionality for the app's user, not a public feed,
social network, or user-generated-content marketplace. Cloud responses remain
subject to the selected provider's terms and safety behavior. Do not claim a
production report/block or app-owned moderation feature unless that surface is
implemented and verified in the submission build; choose the App Store age
rating from the behavior of that exact build.
