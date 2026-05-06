---
state: canon
canon_promoted_on: 2026-05-05
audit_item: CD-008 (Codex 2026-05-05 drift register — full test closure, manual smoke pending)
---

# CD-008 Full Test Closure — 2026-05-05

> **Codex's CD-008 ask:** "Run the release-audit validation matrix
> before any 'whole app canon' claim." Specifically requires:
> - Full or release-relevant `xcodebuild ... test` pass, not only
>   the LSP focused suite.
> - `cargo test` for `graph-engine`.
> - `cargo test` for `agent_core` feature combinations touched by
>   V2.1, V2.3, V2.4, and CLI passthrough.
> - Doctrine linter and replay verification commands introduced by
>   Phase 8.F/8.G.
> - Source guard that MAS builds do not include live subprocess,
>   cloud, Pro-only, ES, NE, or temporary-exception surfaces.
> - Manual/runtime verification for app bootstrap, settings
>   observability, Halo ledger ribbon, LSP editor flow, and any
>   release-risk UI surface before ship language.

## Partial closure (what landed today)

| Surface | Command | Result | Notes |
|---|---|---|---|
| `agent_core` lib (default features) | `cargo test --lib` | **PASS — 876 / 876** | Validates A2 macaroon-derived dispatch + CD-005 capability binding + dispatch tracing migration + provenance Mutex→RwLock. |
| `agent_core` lib (`lsp-runtime` feature) | `cargo test --lib --features lsp-runtime` | **PASS — 891 / 891** | Validates the in-process LSP kernel (15 lsp-runtime-only tests on top of the 876 default). |
| `graph-engine` | `cargo test --target aarch64-apple-darwin` | **PASS — 2522 / 2522** (8 ignored) | First run had 1 flake under concurrent xcodebuild load; clean rerun green. |
| `omega-mcp` | `cargo test --target aarch64-apple-darwin` | **PASS — 143 / 143** | First run had 4 PTY-test flakes under concurrent xcodebuild load; clean rerun green. |
| `omega-ax` | `cargo test --target aarch64-apple-darwin` | **PASS — 0 / 0** (no lib tests today) | UniFFI binding-only crate; tests live in consumer crates. |
| `epistemos-shadow` | `cargo test --target aarch64-apple-darwin` | **PASS — 0 / 0** (no lib tests at lib level) | (Prior history shows 45 lib tests when run against `--all-targets`; today's run targeted `--lib` which is the 0-test surface.) |
| Xcode `Epistemos` scheme test build | `xcodebuild build-for-testing` | **TEST BUILD SUCCEEDED 2026-05-05 13:30 PDT** | Validates XPC trust spine compiles cleanly. SwiftLint failures noted in third-party CodeEditSourceEditor + CodeEditTextView are pre-existing and unrelated. Full `test-without-building` not run today (Codex's still-required item). |

## Codex continuation closure (same day)

Codex continuation extended the earlier partial closure with the missing Rust
all-targets / Pro feature / replay / doctrine gates and the missing
full Swift app test pass. These are now locally verified by Codex, not
only verified-by-Claude.

| Surface | Command | Result |
|---|---|---|
| `agent_core` default all-targets | `cargo test --manifest-path agent_core/Cargo.toml --all-targets` | **PASS** — default feature all-targets, including lib, bins, integration tests, and example harness. |
| `agent_core` Pro+lsp all-targets | `cargo test --manifest-path agent_core/Cargo.toml --no-default-features --features pro-build,lsp-runtime --all-targets` | **PASS** — 1014/1014 lib tests plus bins/integration tests/examples. |
| `epistemos-core` all-targets | `cargo test --manifest-path epistemos-core/Cargo.toml --all-targets` | **PASS** — 378/378 lib, uniffi bin 0/0, sqlite-vec integration 5/5 with 1 manual ignored baseline. |
| `omega-mcp` all-targets | `cargo test --manifest-path omega-mcp/Cargo.toml --all-targets` | **PASS** — 143/143 lib plus uniffi bin 0/0. |
| `omega-ax` all-targets | `cargo test --manifest-path omega-ax/Cargo.toml --all-targets` | **PASS** — 12/12 lib plus uniffi bin 0/0. |
| `graph-engine` all-targets | `cargo test --manifest-path graph-engine/Cargo.toml --all-targets` | **PASS** — 2522/2522 lib, 8 ignored, graph FFI baseline bench harness succeeded. |
| Doctrine linter | `cargo run --manifest-path agent_core/Cargo.toml --bin epistemos_doctrine_lint -- "$(pwd)"` | **PASS** — ALL GATES PASS, doctrine §5 verified. |
| Replay verification | `generate_sample_epbundle` + `epistemos_trace verify-replay` | **PASS** — v2 fixture verified, DAG merkle `ea2e4ac0c13b04f7a638b4714862fc6536fd9833c305456f28f1473e79d5ba9c`. |
| `.epdoc` visible creation path | focused `EpdocVisibilitySourceGuardTests` + Computer Use runtime smoke | **PASS** — Landing exposes `New Doc`; Notes exposes `New Document (.epdoc)`; click opened an untitled document window. |
| Full Swift app test | `./scripts/xcodebuild_epistemos.sh test -project Epistemos.xcodeproj -scheme Epistemos -destination "platform=macOS,arch=arm64" -derivedDataPath .derived-data-codex-full -clonedSourcePackagesDirPath .spm-cache CODE_SIGNING_ALLOWED=NO -resultBundlePath /tmp/epistemos-codex-full-test-rerun-1778019268.xcresult` | **PASS** — `.xcresult` summary: result `Passed`, 5,739 total tests, 0 failed, 49 skipped. |
| Semantic LSP focused tests | Rust: `cargo test --manifest-path agent_core/Cargo.toml --features lsp-runtime lsp_runtime --lib`; Swift: focused `RustLSPTransportTests` + `LSPClientTests` | **PASS** — Rust 17/17 and Swift 17/17; `RustLSPTransport` returns tree-sitter hover and same-file definition through the in-process `tower-lsp` payload path. |
| Computer Use UI smoke | launched `/Users/jojo/Downloads/Epistemos/.derived-data-codex-full/Build/Products/Debug/Epistemos.app` | **PASS/PARTIAL** — Landing `New Doc`, Notes `New Document (.epdoc)`, editor window, Settings Diagnostics rows, and Authority approval preview rendered and responded. Preview was denied; no permission posture was changed. |

## What CD-008 still needs (manual/runtime)

- **Manual runtime smoke of the live LSP editor affordance**.
  Automated `RustLSPTransport`, tree-sitter hover/definition, and
  full app test coverage are green, but this pass did not drive the
  visual code-editor hover/definition UI.
- **Biometric/Sovereign Gate prompts that require real user approval**.
  The non-destructive Authority approval preview rendered and was
  denied safely; real biometric approval remains user-time only.
- **Source guard** for MAS subprocess discipline — partially closed
  by `docs/MAS_PRO_SOURCE_GUARD_2026_05_05.md` (B5). The source-guard
  finding is canonical; the runtime verification (load MAS build,
  attempt subprocess spawn, observe sandbox refusal) is still
  required.

## Net status

- **Cargo coverage:** 5 primary crates green at full `--all-targets`
  granularity. `agent_core` is also green under
  `--no-default-features --features pro-build,lsp-runtime --all-targets`.
- **Xcode coverage:** full `xcodebuild test` green on macOS arm64:
  5,739 total tests, 0 failed, 49 skipped.
- **Doctrine/replay coverage:** B1 doctrine lint and B2 verify-replay
  both passed locally under Codex continuation.
- **Manual runtime coverage:** `.epdoc`, app bootstrap, Settings
  Diagnostics/Halo/Search Fusion/Cognitive DAG rows, and the Authority
  approval preview are verified by Computer Use. The LSP semantic
  transport is automated-verified; only the live editor UI affordance
  and real biometric approval remain open.

This slice is **full automated-test closure of CD-008.** A final
release-style closure still requires the remaining manual runtime sweep
against the next dogfood build.

The doctrine §10 contract still holds: nothing in this session is
claimed `released`. Everything is `verified-by-Claude / unverified-
by-Codex` no longer applies to these automated gates: Codex has
verified the Rust, doctrine/replay, `.epdoc`, and full Swift app test
surfaces listed above. The CODEX_VERIFICATION_HANDOFF_2026_05_05.md
ask remains authoritative for the remaining manual/runtime gates.

## Cross-refs

- `docs/CODEX_CANONICAL_DRIFT_AUDIT_2026_05_05.md` CD-008
- `docs/MAS_PRO_SOURCE_GUARD_2026_05_05.md` (B5 — source-guard side)
- `docs/MIRROR_DISPATCH_COVERAGE_2026_05_05.md` (CD-006)
- `docs/CANONICAL_SWEEP_CLOSEOUT_2026_05_05.md` (session master ledger)
- `.github/workflows/ci.yml` (B1-B4 enforcement gates)
