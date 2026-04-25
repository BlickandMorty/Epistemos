# Phase S -- App Store Hardening Audit

**Date:** 2026-04-24
**Scope:** audit the current App Store (MAS) build hardening state immediately after Phase R closure. This is the first Phase S deliverable. It does not add new hardening; it documents what exists so subsequent sub-phases can target real gaps instead of rehardening things that are already in place.

**Companion code:** `EpistemosTests/AppStoreHardeningTests.swift` (policy-profile FFI drift regression, 2 tests green 2026-04-24).

Master plan section: [AMBIENT_RECALL_HALO_MASTER_PLAN.md §1.7 "App Store First"](AMBIENT_RECALL_HALO_MASTER_PLAN.md).
Plan section: [IMPLEMENTATION_PLAN_FROM_ADVICE.md §Phase S](IMPLEMENTATION_PLAN_FROM_ADVICE.md).

---

## 1. MAS build target wiring

Project `project.yml` defines two app targets:

- `Epistemos` (Pro / default) -- bundle id `com.epistemos.app`, entitlements `Epistemos/Epistemos.entitlements`.
- `Epistemos-AppStore` -- bundle id `com.epistemos.appstore`, entitlements `Epistemos/Epistemos-AppStore.entitlements`, Info.plist `Epistemos-AppStore-Info.plist`, compilation flags `EPISTEMOS_APP_STORE MAS_SANDBOX`.

The MAS binary is kept clean by two independent mechanisms. Both matter; neither alone is sufficient.

### 1a. Source-set exclusions in `project.yml`

The `Epistemos-AppStore` target omits these files from compilation at all:

- `Engine/ClaudeManagedRuntime.swift`
- `Engine/LocalRustRuntime.swift`
- `KnowledgeFusion/Alignment/scripts/**`
- `KnowledgeFusion/MOHAWK/**`
- `KnowledgeFusion/MoLoRA/...` (python training surfaces)
- `Omega/Knowledge/ODIATraceGenerator.swift`
- `Omega/Knowledge/TraceDataMixer.swift`
- `Vault/KnowledgeGraphService.swift`
- `build-rust/swift-bindings/omega_ax.swift` (AXorcist computer-use bindings)

These files do not exist in the MAS compilation unit at all.

### 1b. Compile-condition pruning with App Store stubs

A separate set of Pro-only files remains in the MAS source set but is pruned at compile time with `#if !EPISTEMOS_APP_STORE` / `#if EPISTEMOS_APP_STORE` branches. `Epistemos/AppStore/AppStoreComputerUseStubs.swift` supplies no-op or safe replacements so the Swift type graph still links. Current call sites using this pattern include `AppBootstrap.swift`, `EpistemosApp.swift`, `AppEnvironment.swift`, `Phase4Bridge.swift`, `ComputerUseBridge.swift`, `NightBrainService.swift`, `GhostComputerAgent.swift`, `AXMutationDetector.swift`, `VisualVerifyLoop.swift`.

Practical difference: under (1a) the code genuinely does not exist in the binary, so no re-enable-by-flag risk. Under (1b) the code exists in source and is gated; correctness depends on every gate being written correctly. Phase S drift watch should sample new `#if !EPISTEMOS_APP_STORE` sites when they land and confirm the stub-side path preserves MAS safety.

---

## 2. Entitlements comparison

### MAS (`Epistemos/Epistemos-AppStore.entitlements`)

| Key | Value | Justification |
|---|---|---|
| `com.apple.security.app-sandbox` | true | Required by App Store. No exceptions. |
| `com.apple.security.cs.allow-jit` | true | MLX Metal compute shader JIT. Apple-approved for on-device AI; needs a note in the review submission. |
| `com.apple.security.files.bookmarks.app-scope` | true | Security-scoped bookmarks for vault folder persistence across launches. |
| `com.apple.security.files.user-selected.read-write` | true | User-picked vault folder and attachment files. |
| `com.apple.security.network.client` | true | Cloud model API calls (Anthropic / OpenAI / Perplexity). |

### Pro-only (`Epistemos/Epistemos.entitlements`) -- NOT in MAS

| Pro key | Why it cannot ship to MAS |
|---|---|
| `com.apple.security.cs.allow-unsigned-executable-memory` | Arbitrary dylib loading; blocked by App Review. |
| `com.apple.security.cs.disable-library-validation` | Same. |
| `com.apple.security.automation.apple-events` | AppleScript dispatch to other apps (iMessage, etc.); Pro-only per deployment-profile decision. |
| `com.apple.security.files.bookmarks.document-scope` | Per-document sandbox bookmarks; Pro-only scope. |
| `com.apple.security.temporary-exception.mach-lookup.global-name` | `com.apple.accessibility.api` mach service used by AXorcist for computer use; Pro-only. |

**Audit result:** the MAS plist is a minimal, review-safe entitlement profile. It is NOT a strict subset of the Pro plist -- MAS declares `com.apple.security.app-sandbox` (which Pro omits since Pro is distributed Developer ID outside the sandbox), while omitting all Pro-only entitlements that would trigger App Review blockers (unsigned executable memory, disable library validation, AppleScript automation, document-scope bookmarks, and the accessibility mach-lookup exception used by the computer-use feature). No action required for Phase S.2 entitlements scope.

---

## 3. Privacy manifest

`Epistemos/Resources/PrivacyInfo.xcprivacy` declares:

- `NSPrivacyTracking = false` -- no ad/attribution tracking.
- `NSPrivacyTrackingDomains = []` -- no tracking SDK domains.
- `NSPrivacyCollectedDataTypes = []` -- zero user-data collection categories.
- `NSPrivacyAccessedAPITypes` -- 4 required-reason APIs declared:
  - `NSPrivacyAccessedAPICategoryFileTimestamp` / reason `C617.1` (display timestamps to user).
  - `NSPrivacyAccessedAPICategorySystemBootTime` / reason `35F9.1` (measure elapsed time for a user interaction).
  - `NSPrivacyAccessedAPICategoryDiskSpace` / reason `E174.1` (show storage info to user).
  - `NSPrivacyAccessedAPICategoryUserDefaults` / reason `CA92.1` (read/write app-local defaults).

**Audit result:** manifest is minimal and App-Store-submission-ready. Any future code path that calls a fifth required-reason API must be added here with a valid reason code at the time the call lands.

---

## 4. Rust `mas-sandbox` feature gate coverage

The `mas-sandbox` Cargo feature is the compile-time switch that removes Pro-only tool registrations and runtime behaviors from the shipped binary. Survey:

- 40+ `#[cfg(feature = "mas-sandbox")]` and `#[cfg(not(feature = "mas-sandbox"))]` gates across `agent_core/src/`, concentrated in `tools/registry.rs` (tool registration) and `bridge.rs` (FFI surfaces).
- Three dedicated MAS-runtime helpers live under `#[cfg(feature = "mas-sandbox")]`:
  - `mas_runtime_forbids_tool(&str) -> bool`
  - `mas_allows_bounded_internal_mutation(&str, &Value) -> bool`
  - `mas_runtime_preflight(...)`
- Registry defaults flip for MAS: `enable_bash = !cfg!(feature = "mas-sandbox")`.

### Existing Rust tests (gated to run only under `cargo test --features mas-sandbox`):

- `mas_sandbox_registry_excludes_unbounded_tools`
- `mas_runtime_denies_forbidden_tool_even_if_registered`
- `mas_runtime_denies_destructive_tool_even_if_registered`
- `mas_runtime_denies_unscoped_mutating_tool`

**Audit result:** Rust-side gate coverage is dense and tested. The drift risk is at the LINK boundary, not the code boundary: a Pro-built `libagent_core` accidentally linked into the MAS Xcode target would silently fail the gate. Bootstrap check `AppBootstrap.verifyAgentCorePolicyProfile()` fatals on this at launch; `AppStoreHardeningTests` now also asserts it from Swift Testing so CI catches it before a user can.

---

## 5. Policy-profile FFI

`agent_core/src/bridge.rs:239 agent_core_policy_profile() -> String` returns one of:

- `"direct"` -- built without `--features mas-sandbox` (Pro).
- `"mas_sandbox"` -- built with `--features mas-sandbox` (MAS).

Swift side: `Epistemos/App/AppBootstrap.swift:2686 verifyAgentCorePolicyProfile()` runs at launch and fatalError's if the `EPISTEMOS_APP_STORE || MAS_SANDBOX` build flag and the linked Rust profile disagree. This is the single point that catches the link-mismatch drift case.

`EpistemosTests/AppStoreHardeningTests.swift` replicates the check from Swift Testing with two assertions:

1. `policyProfileReturnsRecognizedValue` -- fails if the FFI returns an unrecognized string (drift catcher for future profile additions).
2. `policyProfileMatchesBuildFlag` -- fails when `EPISTEMOS_APP_STORE || MAS_SANDBOX` is set but the linked profile is not `"mas_sandbox"`, and vice versa. This is the same invariant the bootstrap check enforces.

---

## 6. Phase S exit criteria state (from master plan §1.7 memory note)

The master plan defines 6 hard exit criteria for Phase S. Current state:

| # | Criterion | Status |
|---|---|---|
| 1 | Register issues resolved (master plan phrasing mentions "19"; the register itself tracks 18 live items: I-001..I-017 plus I-019; I-018 was never assigned) | 15/18 FIXED, 3 PARTIAL by design (I-001 write-edge, I-002 sync holdouts, I-003 observer pattern). The 3 PARTIALs are architectural scope-guards with per-issue rationale in [KNOWN_ISSUES_REGISTER.md](KNOWN_ISSUES_REGISTER.md), not correctness regressions. |
| 2 | Full 2,679-test suite + S.4 additions pass in CI | Phase R slice (9 suites, 86 tests) green 2026-04-24. Full suite not yet re-run this session. |
| 3 | `codesign -d --entitlements` on MAS build shows App Sandbox = YES, no `allow-unsigned-executable-memory` | Source plist confirmed minimal (section 2 above). Runtime `codesign` check requires an actual MAS build; see follow-ups. |
| 4 | TestFlight: 10+ testers, 2+ cycles, zero critical open bugs | Not started. Open-ended section per master plan guidance. |
| 5 | App Store Connect: submission accepted, app live on MAS | Not started. |
| 6 | First 48h post-launch: no crash spike, rating >= 4.5 | Not applicable until launch. |

---

## 7. Known follow-ups (non-blocking, scoped by sub-phase)

- **S.1 UX polish:** requires launched-app dogfood time; out of scope for this audit pass.
- **S.2 (this doc):** run `codesign -d --entitlements -` on an actual built `Epistemos-AppStore.app` and attach output. Requires a clean release build, deferred because disk is tight (13 GB free at audit time; `agent_core/target` is 50 GB and another feature-set compile would add 1-3 GB).
- **S.4 tests:**
  - Run the Rust `mas-sandbox` tests under `cargo test --manifest-path agent_core/Cargo.toml --features mas-sandbox -- mas_` (deferred for the same disk reason).
  - Add bounded-agent termination tests for the Swift side (`max_turns` ceiling invariants).
  - Security-scoped bookmark round-trip tests after a sandbox-container write cycle.
- **S.5 perf:** Phase 0 measurement slot already exists with signpost instrumentation landed in `e19037c0`; the Instruments trace capture is the next step.
- **S.6 privacy:** `PrivacyInfo.xcprivacy` is already minimal; the only residual is a Settings -> Privacy transparency pane for the end user.
- **S.7 ASC setup:** pure ops work, not code.
- **S.8 TestFlight:** not started, open-ended per master plan.
- **S.9 submission:** not started.

---

## 8. What this audit explicitly did NOT prove

This audit is source-level inspection plus one Swift Testing regression. It does NOT constitute App Store submission readiness. Explicit non-claims:

- **No actual MAS build was produced.** No `xcodebuild archive` of the `Epistemos-AppStore` scheme was run in this pass. The claims in sections 1 and 2 are from `project.yml` and the plist source files, not from a signed `.app`.
- **No `codesign -d --entitlements -` runtime check was run.** There is no output capturing the real embedded entitlements of a shipped binary. A future Phase S.2 follow-up must archive an MAS build and grep the codesign output against this audit.
- **No `cargo test --features mas-sandbox` was run in this pass.** The Rust MAS-gated tests are known to exist (names listed in section 4); their last recorded green state predates this pass. Disk (13 GB free, 50 GB in `agent_core/target`) was the reason for deferral.
- **No TestFlight, no App Store Connect submission.** Sub-phases S.7, S.8, and S.9 are untouched.
- **No security-scoped bookmark persistence tests across relaunch under a real sandbox container.** Planned for S.4.
- **No stricter Swift 6 concurrency audit under the sandbox.** Planned for S.4.
- **No UX-level dogfood evidence.** S.1 requires human-time using a released build; not started.
- **This is not a release-readiness statement.** It is a baseline audit so subsequent Phase S work has a documented starting point.

When these gaps close, update this doc rather than creating a new one, so the audit history stays single-source.
