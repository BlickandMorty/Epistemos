# Codex / Kimi Oversight Round 028 - 2026-05-01

## Slice

R16 PR3A - Background Indexing visible status.

## Scope Decision

Kimi was not invoked for edits on this slice. The user explicitly asked to move
from prolonged Phase 0 gating into feature building, and this PR3A slice was a
small, bounded Settings diagnostic built directly on existing app code:

- `ShadowVaultBootstrapper.progress`
- `AppBootstrap.initializeShadowBackendIfReady()`
- Settings -> General -> Diagnostics

Using Kimi here would have added overhead without improving coverage. Preserve
Kimi for larger advisory/review slices where broad plan comparison or independent
diff review is worth the latency.

## Codex Actions

- Added a `BackgroundIndexingHealthRow` diagnostic row beside the existing editor,
  Halo, and Search Fusion diagnostics.
- Wired `AppBootstrap` shadow initialization to record unavailable, scanning,
  indexing, complete, and failed states.
- Added a focused Swift Testing case for the diagnostic recorder.
- Did not touch protected editor, graph view/controller, graph-engine, generated
  artifact, project, entitlement, staging, or commit surfaces.

## Verification

- Targeted Swift test log:
  `/tmp/epistemos-r16-pr3a-background-indexing-xcode-test-20260501.log`
- Result: `ShadowVaultBootstrapper (Wave 8.7)` ran `6` tests, `0` failures.
- Xcode printed the known CodeEdit SwiftLint script noise after `** TEST SUCCEEDED **`;
  the command exited `0`.

## Guardrails

- Diff check:
  `/tmp/epistemos-r16-pr3a-diff-check-20260501.log`
- Trailing whitespace:
  `/tmp/epistemos-r16-pr3a-trailing-whitespace-20260501.log`
- Source anti-pattern scan:
  `/tmp/epistemos-r16-pr3a-source-antipattern-20260501.log`
- Touched-file scope:
  `/tmp/epistemos-r16-pr3a-touched-file-scope-20260501.log`
- Protected-path scan:
  `/tmp/epistemos-r16-pr3a-protected-diff-name-only-20260501.log`

The protected-path scan lists inherited dirty `graph-engine/**` files already
present on the branch. PR3A did not edit them; do not fold those files into this
slice unless a future graph-engine slice deliberately takes ownership.
