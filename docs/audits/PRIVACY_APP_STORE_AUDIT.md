# Privacy + App Store + Entitlements Audit

Date: 2026-04-25
Authority: PolicyProfile compile-time gating; PrivacyInfo.xcprivacy; AppStoreHardeningTests.

## Feature classification

| Feature | App Store safe? | Entitlement needed | Privacy disclosure needed | Recommended action |
|---|---|---|---|---|
| Local model inference (MLX) | YES with JIT entitlement | `com.apple.security.cs.allow-jit` (present in MAS plist) | none beyond standard | KEEP; document JIT for App Review |
| Cloud API client (Anthropic/OpenAI/Google/Perplexity) | YES | `com.apple.security.network.client` | API key handling — already Keychain-only | KEEP |
| Vault file access (user-selected) | YES | `com.apple.security.files.user-selected.read-write` + `com.apple.security.files.bookmarks.app-scope` | `NSDocumentsFolderUsageDescription`, `NSDesktopFolderUsageDescription`, `NSDownloadsFolderUsageDescription` | KEEP |
| FTS5 / SwiftData / GRDB | YES | none | none | KEEP |
| Instant Recall HNSW | YES | none | none | KEEP |
| Microphone / dictation | YES | none beyond plist | `NSMicrophoneUsageDescription` (present) | KEEP |
| Speech recognition | YES | none beyond plist | `NSSpeechRecognitionUsageDescription` (present) | KEEP |
| MCP local tools | YES (subset) | none | none | KEEP for safe tools (vault_read/write/search). EXCLUDE bash_execute / shell / docker from MAS profile. |
| Accessibility (`omega-ax`) | NO (Pro-only) | `com.apple.security.automation.apple-events`, `com.apple.security.temporary-exception.mach-lookup.global-name` (`com.apple.accessibility.api`) | `NSAccessibilityUsageDescription` | EXCLUDE from MAS via post-build scrub (already done) |
| Screen capture (Omega VisualVerify) | NO (Pro-only) | (Pro-only entitlement) | `NSScreenCaptureUsageDescription` (Pro plist only) | EXCLUDE from MAS (stub returns denied) |
| Apple Events automation | NO (Pro-only) | `com.apple.security.automation.apple-events` | `NSAppleEventsUsageDescription` (Pro plist only) | EXCLUDE from MAS |
| iMessage outbound (existing) | TBD | per-helper entitlement if used | TBD | KEEP if inbound is gated; verify before MAS submission |
| iMessage inbound (Phase K) | NO (Pro-only) | broader entitlement | privacy disclosure | DEFER to Pro |
| Bash / shell / Docker | NO (Pro-only) | none allowed in MAS | n/a | EXCLUDE — gated behind `#if !EPISTEMOS_APP_STORE` per `Epistemos/Harness/HarnessLab.swift` |
| WebFetch | YES (HTTP only) | `com.apple.security.network.client` | none beyond cloud API disclosure | KEEP if scoped to chat-context only |
| MultiEdit | TBD | none | none | VERIFY scope; if it edits multiple files atomically, KEEP for MAS |
| Computer use bridge | NO (Pro-only) | many | many | EXCLUDE from MAS (stubbed via `AppStoreComputerUseStubs.swift:1-184`) |

## Entitlements summary

| Profile | File | Risky entitlements | Notes |
|---|---|---|---|
| Pro Release | `Epistemos/Epistemos.entitlements` | `cs.allow-jit`, `cs.allow-unsigned-executable-memory`, `cs.disable-library-validation`, `automation.apple-events`, `temporary-exception.mach-lookup.global-name → com.apple.accessibility.api` | Direct distribution; Developer ID signed |
| Pro Debug | `Epistemos/Epistemos-Debug.entitlements` | `app-sandbox: false`, same JIT/dylib exceptions | Sandbox off for Knowledge Fusion / Python dev |
| MAS Release | `Epistemos/Epistemos-AppStore.entitlements` | `app-sandbox: true`, `cs.allow-jit` only | clean subset; no automation, no library validation disable, no AX bypass, no document bookmarks |

## Privacy manifest (`PrivacyInfo.xcprivacy`)

- `NSPrivacyTracking: false` ✓
- `NSPrivacyTrackingDomains: []` ✓
- `NSPrivacyCollectedDataTypes: []` ✓
- `NSPrivacyAccessedAPITypes`: FileTimestamp (C617.1), SystemBootTime (35F9.1), DiskSpace (E174.1), UserDefaults (CA92.1) ✓
- Microphone / Speech / Screen Capture do NOT require declared reasons in xcprivacy (user-facing prompts only).

Drift detection: `EpistemosTests/AppStoreHardeningTests.swift:74-85` enforces manifest at test time.

## Info.plist usage descriptions

**Pro plist** (`Epistemos-Info.plist`): `NSAccessibilityUsageDescription`, `NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription`, `NSScreenCaptureUsageDescription`, `NSAppleEventsUsageDescription`, `NSDocumentsFolderUsageDescription`, `NSDesktopFolderUsageDescription`, `NSDownloadsFolderUsageDescription`, `ITSAppUsesNonExemptEncryption: false`.

**MAS plist** (`Epistemos-AppStore-Info.plist`): correctly REMOVES `NSAccessibilityUsageDescription`, `NSScreenCaptureUsageDescription`, `NSAppleEventsUsageDescription`. KEEPS Microphone + Speech (in-sandbox local models). NARROWS file folder copy ("only for vaults and files you explicitly choose").

## TCC discipline

All TCC prompts originate from sandboxed frontend (Swift/AppKit), never from helper. Verified call sites:
- `Epistemos/KnowledgeFusion/DataIngestion/AudioRecorder.swift:24` — `AVCaptureDevice.requestAccess(for: .audio)`
- `Epistemos/Engine/ComposerVoiceInputService.swift:144` — same
- `Epistemos/KnowledgeFusion/DataIngestion/AudioTranscriber.swift:179-184` — `SFSpeechRecognizer.requestAuthorization()`
- `Epistemos/Omega/OmegaPermissions.swift:25-29` — Accessibility check via Rust FFI off-main; does NOT prompt
- `Epistemos/Omega/OmegaPermissions.swift:83-100` — ScreenCaptureKit check; does NOT prompt
- `Epistemos/Omega/OmegaPermissions.swift:102-115` — Apple Events `AEDeterminePermissionToAutomateTarget`

## Sandbox + double-helper

- Single-app conditional compilation, NOT XPC double-helper.
- This is acceptable for MAS submission; functionally equivalent (Pro-only features stripped at compile time).
- Future Pro-only XPC helper deferred.

## Bundle size + storage

- Bundled resources: `sdf_labels.png` (122 KB), `sdf_labels.json` (21 KB), Fonts/ (small), `PrivacyInfo.xcprivacy` (1.5 KB), `Localizable.xcstrings` (1.4 KB) — all small.
- Models: `config/model_manifest.json` declares external models; status: missing — downloaded to `~/Library/Application Support/Epistemos/PreparedModels/` on first run.
- Bundled dylibs: `graph_engine`, `syntax_core`, `omega_mcp`, `omega_ax` (Pro-only, scrubbed in MAS), `epistemos_core`, `agent_core`.
- No bundled `.gguf`/`.safetensors`/`.mlx` (per CLAUDE.md DO NOT commit).
- **Recommend**: add bundle-size CI gate (target ≤80 MB binary, ≤500 MB total app bundle). Currently unmonitored. **MEDIUM (P2)**.

## Risky Rust crate features

- `agent_core/Cargo.toml`: features `default = []`, `mas-sandbox = []`. Deps include `nix` (process/term/signal/fs).
- **MEDIUM**: Verify `nix::process::*` call sites in `agent_core/src/` are wrapped with `#[cfg(not(feature = "mas-sandbox"))]` or routed only through tools that are tier-gated. Spot-check during patch queue work.
- `omega-ax/Cargo.toml`: minimal, all crates excluded from MAS post-build.
- `omega-mcp/Cargo.toml`: deps include `nix` for PTY. Same `#[cfg]` discipline required.

## Audit verdicts

**(a) Is the App Store profile shippable today?** SHIPPABLE WITH CAVEATS. Entitlements clean; code correctly gated; privacy pane built; tests guard drift. JIT entitlement requires App Review documentation justifying MLX inference (no user code execution).

**(b) PolicyProfile + double-helper**: SCAFFOLDED ARCHITECTURALLY (single-app gating); compile-time strip is sound for MAS.

**(c) Bundle size**: SMALL but UNMONITORED. Add CI gate.

**(d) Critical entitlement / privacy gaps**: NONE BLOCKING.

## P0/P1 actions for V1 ship

| # | Action | Priority | File / surface |
|---|---|---|---|
| A1 | Document JIT entitlement justification in App Review submission notes | P0 | (submission process) |
| A2 | Verify `nix::process::*` and similar are gated with `#[cfg(not(feature = "mas-sandbox"))]` in agent_core, omega-mcp | P1 | agent_core, omega-mcp Rust source |
| A3 | Add CI step measuring `Epistemos-AppStore.app` bundle size; alert if > 600 MB | P2 | `.github/workflows/ci.yml` |
| A4 | Verify MAS build excludes ALL bash/shell/docker tool registrations from `agent_core/src/tools/registry.rs` (currently relies on Swift-side `#if !EPISTEMOS_APP_STORE` for harness; double-check Rust tool registry under `mas-sandbox` feature) | P0 | `agent_core/src/tools/registry.rs` |
| A5 | TestFlight first; gather telemetry on JIT/sandbox interaction | P1 | submission process |

Confidence: HIGH on entitlement and code-gating audit; MEDIUM on Rust-side `mas-sandbox` feature coverage (needs spot-check).
