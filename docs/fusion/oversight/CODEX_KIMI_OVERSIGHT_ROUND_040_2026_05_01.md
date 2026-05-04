# Codex/Kimi Oversight Round 040 - Halo V0 Shadow Backend Route PR1

Date: 2026-05-01

## Scope

Halo Live Loop Card 5 PR1 only: route the existing production Contextual
Shadows V0 recall surface through the newer Shadow backend when the active
vault backend is ready, while preserving the InstantRecall fallback.

Approved write set:

- `Epistemos/State/ContextualShadowsState.swift`
- `Epistemos/Views/Recall/ContextualShadowsPanel.swift`
- `Epistemos/App/AppBootstrap.swift`
- `EpistemosTests/ContextualShadowsStateTests.swift`
- `docs/fusion/**`

Forbidden for this round:

- `Epistemos/Views/Notes/ProseEditor*.swift`
- `Epistemos/Views/Graph/MetalGraphView.swift`
- `Epistemos/Views/Graph/HologramController.swift`
- `graph-engine/**`
- production FFI replacement code
- generated Swift/header bindings or generated libraries
- project files, entitlement files, DerivedData, `.xcresult`, stash, staging,
  commit, branch, or destructive git operations

## Codex Verification

Red log:

- `/tmp/epistemos-halo-v0-shadow-route-red-20260501.log`
- Expected failure before implementation: missing Shadow backend routing,
  source provenance, and supporting test contracts.

Green log:

- `/tmp/epistemos-halo-v0-shadow-route-green-20260501.log`
- `ContextualShadowsStateTests`: `17` tests passed, `0` failed.
- Xcode emitted `** TEST SUCCEEDED **`.

Guardrails:

- `git diff --check -- Epistemos/State/ContextualShadowsState.swift Epistemos/Views/Recall/ContextualShadowsPanel.swift Epistemos/App/AppBootstrap.swift EpistemosTests/ContextualShadowsStateTests.swift docs/fusion` passed.
- Source grep found no `loadBody()` in the touched Halo route path.
- Source grep found no `HaloController` reference in
  `ContextualShadowsState.swift`, preserving the V0 route.
- Protected-path scan still lists inherited dirty `graph-engine/**` paths from
  the existing worktree, but this PR1 slice did not edit graph-engine,
  protected editor, protected graph view/controller, generated, project,
  entitlement, stash, staging, commit, or branch state.
- Kimi before/after status comparison was empty; Kimi made no file changes.

## Kimi Advisory

Logs:

- `/tmp/epistemos-halo-v0-shadow-route-kimi-advisory-20260501.log`
- `/tmp/epistemos-halo-v0-shadow-route-kimi-delta-advisory-20260501.log`
- `/tmp/epistemos-halo-v0-shadow-route-kimi-final-advisory-20260501.log`

Kimi result:

- P0 blockers: none.
- P1 blockers: none.
- Verdict: Halo V0 Shadow Backend Route PR1 can close.

Kimi follow-up handling:

- Initial Kimi P2 flagged stale Shadow backend risk during vault switches.
  Codex hardened `AppBootstrap.initializeShadowBackendIfReady()` to clear stale
  search state and install `ShadowSearchService` only for the still-current
  active vault.
- Kimi delta then flagged stale page-reindex use of `shadowIndexer`.
  Codex hardened `enqueueShadowPageReindexIfReady(pageId:)` to verify the
  active vault path before reading the indexer, before enqueueing page inserts,
  and before writing final progress/completion records.
- Final Kimi audit found no material P2 follow-up for PR1. It suggested future
  telemetry for Shadow versus InstantRecall hit-rate split after the V0 flag
  goes wide.

## Gate Decision

Close Halo V0 Shadow Backend Route PR1.

Do not claim full V1 Halo completion. The full V1 editor mount, trailing-edge
editor glyphs, inline Halo editor work, and manual runtime ship verification
remain separate gates.
