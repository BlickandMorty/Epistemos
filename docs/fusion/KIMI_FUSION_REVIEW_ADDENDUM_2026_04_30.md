# Kimi Fusion Review Addendum - 2026-04-30

Authorship note: this is a Codex overseer addendum to `KIMI_FUSION_REVIEW_2026_04_30.md`.
Kimi read the required correction inputs in plan mode, but then wrote a forbidden
`.kimi` plan file, so the session was stopped before Kimi could produce this file.

## Status

Use this addendum to correct the Phase 0 review before any further Kimi work.

The original review is still useful for worktree inventory, source-map synthesis,
salvage-map framing, and red-line capture. This addendum supersedes only stale or
missing parts.

## Required Context Omission

`CLAUDE.md` exists and was required by the active overseer prompt if present, but
the original Kimi review did not list it in the sources reviewed.

That omission does not invalidate the whole review, but it does block trusting
Kimi for a next implementation slice until the `CLAUDE.md` constraints are folded
into the gate.

## CLAUDE.md Constraints To Preserve

`CLAUDE.md` strengthens or adds these constraints:

- Inference must not move to a sidecar. In-process Rust FFI or MLX-Swift remain canonical, with only the documented oversized-model exception.
- Hermes/subprocess paths are orchestration only, not inference.
- Cloud integrations must use real APIs only. No fake SDKs, fake features, or guessed endpoints.
- Capability gating must be honest: local models do not get fake cloud-agent capability.
- Thinking blocks must be preserved when a tool-use stop reason occurs.
- Streaming paths should forward tokens immediately and avoid hidden buffering unless a more current canonical doc explicitly overrides it for a specific UI buffer.
- Agent termination follows model/provider stop reasons; `max_turns` is a safety rail.
- API keys belong in macOS Keychain, not `UserDefaults`.
- The Swift SDK reality section is authority for provider integration: Anthropic and OpenAI have no first-party Swift SDK in this project context.
- Subprocess hardening is explicit doctrine: `env_clear`, a small allowlist, a denylist for dynamic-loader and language-startup variables, process-group isolation, and kill-on-drop behavior.
- Provenance ledger, ReplayBundle, and `epistemos-trace` integrity checks are canonical provenance infrastructure.
- Session startup for a fresh coding task must read `docs/APP_ISSUES_AUTO_FIX.md`, `docs/AGENT_PROGRESS.md`, and the current sprint file before opportunistic sprint work.

## Stale Claims In The Original Review

The original review's "Missing Research Or Evidence" item saying no current
`xcodebuild test` or `cargo test` log existed is now stale.

Current raw evidence is recorded in `BUILD_TEST_FLOOR_RESULTS_2026_04_30.md`.
Most importantly:

- Swift full floor passed before the Halo/Contextual tests-only slice: `5021` tests in `563` suites, log `/tmp/epistemos-full-test-after-rrf-fts-20260430.log`.
- Focused Halo/Contextual tests-only slice passed: `72` tests in `6` suites, log `/tmp/epistemos-halo-contextual-tests-only-20260430.log`.
- A default full rerun later failed under a test-host restart with two non-Halo failures, but both failures passed in focused repro.
- Serial full rerun then passed: `5024` tests in `563` suites, log `/tmp/epistemos-full-test-serial-after-halo-contextual-tests-20260430.log`.
- Rust floors remain green: `graph-engine` `2522 passed`; `agent_core` library `774 passed`, with bins/e2e/doc-test set passing.

The original review's "Slice 1: Verify Floor + Produce Required Phase 0 Docs"
is therefore complete as a floor-building step. It is no longer the next slice.

The original review's uncertainty around Contextual Shadows should also be
updated:

- V0 Contextual Shadows is production-mounted in app bootstrap, app environment, notes, chat, and editor recall scheduling.
- V0 currently routes through `InstantRecallService`.
- V1 Halo (`HaloController`, `HaloEditorBridge`, `ShadowPanelController`, `HaloButton`) is scaffolded/tested but not production-instantiated.
- `ShadowSearchService` and the Rust shadow backend exist, but are not the production UI route for V0.

## Revised First Slices

1. **Manual/runtime Contextual Shadows V0 verification.**
   Verify `EPISTEMOS_AMBIENT_RECALL_V0=1` in the app, note typing, chat composer typing, panel open behavior, note hit opening, chat hit opening, and logs. This is required before any product-facing claim.

2. **Implementation deliberation for backend or V1 Halo wiring, if still desired.**
   This must be a separate gate. It must decide whether to keep V0 on `InstantRecallService`, wire V0 to `ShadowSearchService`, or mount V1 Halo. Any `ProseEditor*` change remains protected and requires explicit approval.

3. **Quick Capture capture-to-artifact-to-graph slice.**
   Still viable after a separate deliberation. Treat Quick Capture worktree code as donor evidence only, not merge authority.

## Red Lines Strengthened By CLAUDE.md

- No sidecar inference in Core or MAS. Pro orchestration tunnels do not change the inference boundary.
- No private, fake, or guessed provider APIs.
- No dishonest capability labels or fake local agent capability.
- No dropping thinking blocks from tool-use turns.
- No hidden buffering that contradicts the current streaming contract for the affected path.
- No API-key persistence outside Keychain.
- No subprocess work that bypasses the hardening helpers or leaks unsafe environment variables.
- No claim that the floor is green without citing the current raw logs.
- No Kimi code edits until a fresh implementation deliberation gate is approved.

## Kimi Oversight Note

During the correction attempt, Kimi wrote:

`/Users/jojo/.kimi/plans/swamp-thing-hawkman-magik.md`

That was outside the allowed write scope and triggered the stop rule. The session
was interrupted. Do not resume that session for implementation work.
