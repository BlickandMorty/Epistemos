---
state: canon
canon_promoted_on: 2026-05-05
audit_item: CD-008 (Codex 2026-05-05 drift register — partial closure)
---

# CD-008 Partial Closure — 2026-05-05

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

## What CD-008 still needs (NOT closed by this slice)

- **Full `xcodebuild test` pass** (not just `build-for-testing`) for
  the `Epistemos` scheme on `platform=macOS,arch=arm64`. Today's
  Xcode work was build-only; the actual Swift Testing suite of 346
  test files was not exercised in this session. CI runs it.
- **Full `cargo test --all-targets`** for every crate (today targeted
  `--lib` for speed). Integration tests + bins + examples not run.
- **Pro feature surface tests**:
  `cargo test --no-default-features --features pro-build,lsp-runtime`
  (CI gate B3 enforces this on every push, but the local sign-off
  for this session did not re-run it).
- **Doctrine linter** (`epistemos_doctrine_lint`) — CI gate B1 runs
  it on every push; not re-run locally today.
- **Replay verification** (`epistemos-trace verify-replay`) — CI gate
  B2 runs it on every push against the deterministic
  `/tmp/epistemos-ci-sample.epbundle` fixture; not re-run locally
  today.
- **Manual runtime smoke** of: app bootstrap, Settings → Diagnostics
  panels (Cognitive DAG stats, Halo ledger ribbon, Search Fusion
  health row), LSP editor flow, Sovereign Gate prompts. None of
  these were exercised today; this session was code + doc only.
- **Source guard** for MAS subprocess discipline — partially closed
  by `docs/MAS_PRO_SOURCE_GUARD_2026_05_05.md` (B5). The source-guard
  finding is canonical; the runtime verification (load MAS build,
  attempt subprocess spawn, observe sandbox refusal) is still
  required.

## Net status

- **Cargo coverage:** 6 of 6 crates green at `--lib` granularity on
  clean reruns. agent_core covered for both default + `lsp-runtime`
  feature combos.
- **Xcode coverage:** test-build green; Swift Testing suite NOT
  exercised in this session.
- **CI coverage:** all 4 enforcement gates (B1 doctrine lint, B2
  verify-replay, B3 Pro-build feature matrix, B4 lsp-runtime feature)
  remain green on `feature/landing-liquid-wave` per the most recent
  push.
- **Manual runtime coverage:** ZERO this session. Codex's
  manual-runtime-verification ask remains open.

This slice is **partial closure of CD-008.** A full closure requires
either (a) running the manual runtime sweep + full xcodebuild test +
all-targets cargo test in a dedicated verification session, or (b)
trusting CI's B1-B4 enforcement + a focused manual smoke pass against
the next dogfood build.

The doctrine §10 contract still holds: nothing in this session is
claimed `released`. Everything is `verified-by-Claude / unverified-
by-Codex / build-clean-on-arm64-macOS-26`. The CODEX_VERIFICATION
_HANDOFF_2026_05_05.md ask remains the authoritative gate.

## Cross-refs

- `docs/CODEX_CANONICAL_DRIFT_AUDIT_2026_05_05.md` CD-008
- `docs/MAS_PRO_SOURCE_GUARD_2026_05_05.md` (B5 — source-guard side)
- `docs/MIRROR_DISPATCH_COVERAGE_2026_05_05.md` (CD-006)
- `docs/CANONICAL_SWEEP_CLOSEOUT_2026_05_05.md` (session master ledger)
- `.github/workflows/ci.yml` (B1-B4 enforcement gates)
