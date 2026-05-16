---
item: RCA13-P0-001
created_on: 2026-05-16
scope: vault reset/add/remove/select runtime proof
status: COMPLETE_RESEARCH_READY
---

# RCA13-P0-001 Vault Smoke User Decision

## Problem Statement

`RCA13-P0-001` is the remaining runtime proof for the vault reset/add/remove/select blocker. The original user report was release-critical: the app did not reliably let the user choose a vault, old notes stayed visible after Settings -> Reset Everything, and vault add/removal is a priority product feature.

The Wave 0 fixes and focused automated tests are already present. Current code clears runtime vault lifecycle state before and after Reset Everything, clears SwiftData note/chat/graph/workspace rows, removes managed note bodies, clears persisted vault selection, resets Notes UI, clears graph/search/Halo/Instant Recall runtime surfaces, and hardens failed vault selection and disconnect behavior.

That is not enough to close the issue. The open decision is how to obtain and interpret the operator proof: disposable vault A with `VAULT_A_ONLY`, Reset Everything, relaunch, disposable vault B with `VAULT_B_ONLY`, then disconnect/remove B. Patch only if that proof fails.

## Options

### Option A - Run isolated audit-app A/B smoke before code changes

Use the already isolated audit-app harness and disposable vaults. Prove A imports cleanly, Reset Everything removes A everywhere, relaunch stays clean, B imports without A contamination, and B disconnect/remove clears B everywhere.

Pros:

- Matches the current source-of-truth queue item.
- Avoids touching production code when the remaining gap is runtime evidence.
- Uses `EPISTEMOS_APPLICATION_SUPPORT_ROOT` so destructive reset proof does not hit normal app state.
- Produces a precise failure surface if any stale state survives.

Cons:

- Requires human UI action in the running app.
- If the smoke fails, a follow-up implementation slice is still required.

### Option B - Run the smoke in normal app state

Use the user's regular app install and real or normal test vaults instead of the isolated audit harness.

Pros:

- Highest fidelity to the user complaint.
- Can catch problems caused by real preferences, bookmarks, or large derived stores.

Cons:

- Higher risk because Reset Everything and vault disconnect are destructive.
- Normal state can make the result harder to interpret.
- Not recommended until the isolated audit-app path passes or produces a narrow failure.

### Option C - Accept automated tests and skip manual runtime proof

Treat the focused reset/selection tests as sufficient and mark the row ready without live UI proof.

Pros:

- Fastest path.
- Current tests cover important reset surfaces: SwiftData rows, managed bodies, graph runtime state, Query history, Halo backend/hits, and failed vault selection preservation.

Cons:

- Leaves the original user-visible complaint unproved.
- Does not test relaunch, UI panels, security-scoped folder selection, graph/search/Halo convergence, or disconnect through the real running app.

### Option D - Authorize implementation now from the complaint, without guided smoke

Assume reset/select is still broken and start patching suspected surfaces immediately.

Pros:

- Appropriate only if the user can reproduce stale vault state right now but cannot run the guided proof.
- May be necessary if the isolated harness itself is broken.

Cons:

- Risks broad churn across reset, graph, search, Halo, SwiftData, bookmarks, and UI state without a current failure trace.
- Can regress the already landed reset/selection hardening.

## Canonical Sources

- `docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_E_2026_05_16.md:133` through `:185` lists `RCA13-P0-001` as the remaining vault smoke user-decision item: user runs the clean-state vault smoke, Terminal E analyzes results.
- `docs/NEW_SESSION_HANDOFF_2026_05_15.md:93` through `:95` defines the required disposable vault A/B proof: connect A with `VAULT_A_ONLY`, Reset Everything, verify Notes/Graph/Search/Halo/Settings have no stale A state, connect B with `VAULT_B_ONLY`, verify only B appears, and patch only if proof fails.
- `docs/RESEARCH_COVERAGE_GAP_AUDIT_PASS2_2026_05_15.md:616` records `RCA13-P0-001 manual vault A/B smoke test` as a manual user action.
- `docs/audits/RECURSIVE_CURRENT_APP_AUDIT_TODO_2026_05_09.md:13259` through `:13338` gives the original P0 problem, patch plan, and test plan for reset/add/remove/select.
- `docs/audits/RECURSIVE_CURRENT_APP_AUDIT_TODO_2026_05_09.md:13340` through `:13386` records Wave 0 implementation evidence and focused test success, while keeping manual runtime smoke open.
- `docs/audits/RECURSIVE_CURRENT_APP_AUDIT_TODO_2026_05_09.md:13388` through `:13430` records the audit harness isolation and the partial A-vault smoke: A selected cleanly, Notes and Graph showed only `VAULT_A_ONLY`, SQLite showed only A, but Reset Everything, relaunch, B selection, and B disconnect remained pending.
- `Epistemos/App/AppBootstrap.swift:3018` through `:3046` implements `clearVaultLifecycleRuntimeState(reason:clearWorkspaceRestore:)` for query tasks, ambient manifests, Query, Halo/Shadow, Instant Recall, Graph, workspace restore, and health rows.
- `Epistemos/App/AppBootstrap.swift:3048` through `:3110` implements `resetAllData()` with lifecycle clears before and after destructive state deletion.
- `Epistemos/Sync/VaultSyncService.swift:2347` through `:2378` shows `switchToVaultAsync` preflighting candidate security-scoped access and keeping the current vault active on candidate access failure.
- `Epistemos/Sync/VaultSyncService.swift:4134` through `:4240` implements disconnect with the RCA13 lifecycle clear, async watcher release, forced derived-state clear fallback, persisted selection clearing, UI reset, and post-teardown lifecycle clear.
- `EpistemosTests/VaultLifecycleResetTests.swift:9` through `:217` covers graph lifecycle reset, Halo reset, Query reset, and Reset Everything clearing SwiftData rows, managed bodies, graph/query/Halo runtime state, and setup flags.
- `EpistemosTests/VaultSyncServiceAuditTests.swift:1147` through `:1193` covers failed vault selection preserving the previous active vault.
- `scripts/launch_audit_app.sh:117` through `:143` prepares the isolated audit app, setting `EPISTEMOS_SKIP_VAULT_RESTORE`, `EPISTEMOS_APPLICATION_SUPPORT_ROOT`, and `EPISTEMOS_AUDIT_ALLOW_SOVEREIGN_GATE`.

## Code Impact Estimate

### Option A impact

Implementation now: docs/runtime proof only.

If the smoke passes:

- Mark the RCA13 runtime proof complete in the relevant audit/MAS rows.
- No production code change required.

If the smoke fails:

- Patch only the failing surface shown by the proof.
- Likely patch areas are `AppBootstrap.resetAllData`, `VaultSyncService.disconnect`, Notes UI reset, graph runtime clear, Search/Query state, Halo/Shadow/Instant Recall state, persisted vault selection/bookmark handling, or workspace restore state.
- Re-run the same isolated A/B smoke after the patch.

### Option B impact

Implementation now: runtime proof only, but on normal app state.

Risk:

- Higher operator risk because the proof uses non-isolated state.
- Failure analysis may be noisier because old production caches, bookmarks, or large vault artifacts can be present.

### Option C impact

Implementation now: docs/status only.

Risk:

- Leaves the manual proof gap in place.
- The issue originated in the running UI, so skipping the running UI proof is a trust risk.

### Option D impact

Estimated implementation: unknown until a current failure is identified.

Risk:

- Potentially broad changes across vault lifecycle, SwiftData, graph/search/Halo derived stores, settings, and onboarding.
- Highest chance of duplicating or regressing the already landed Wave 0 reset hardening.

## Recommendation

Recommend **Option A: run the isolated audit-app A/B smoke before any more code changes**.

Recommended decision record:

> RCA13-P0-001 remains operator-required. Use the isolated audit-app harness and disposable `VAULT_A_ONLY` / `VAULT_B_ONLY` vaults. If the smoke passes, mark the runtime proof complete. If it fails, patch only the failing surface and rerun the same smoke.

Reasoning:

- The current code and focused tests already cover the main reset and failed-selection substrate.
- The remaining gap is explicitly manual/runtime: Reset Everything in the UI, relaunch, B selection, and B disconnect.
- The audit harness was already changed to isolate app support state, which makes destructive reset proof safer than using normal app state.
- A live A/B result will narrow any follow-up patch to the real leaking surface.

## Acceptance Criteria

If the user chooses **Option A**:

- Prepare two throwaway vaults:
  - A contains a unique note titled `VAULT_A_ONLY`.
  - B contains a unique note titled `VAULT_B_ONLY`.
- Launch the isolated audit app through `./scripts/launch_audit_app.sh` or the current prepared audit bundle.
- Confirm the audit app reports or uses an app support root under `build/audit-app-support`.
- Select vault A.
- Confirm only `VAULT_A_ONLY` appears in Notes, Graph, Search/Query, Halo diagnostics or Shadow-derived results if available, Settings active-vault path, and the isolated SwiftData store if inspected.
- Run Settings -> Reset Everything through the destructive confirmation path.
- Before relaunch, confirm `VAULT_A_ONLY` is absent from Notes, Graph, Search/Query, Halo/Shadow surfaces, Settings active-vault state, and the isolated SwiftData store if inspected.
- Relaunch the isolated audit app and confirm `VAULT_A_ONLY` is still absent and no active vault is restored.
- Select vault B.
- Confirm `VAULT_B_ONLY` appears and `VAULT_A_ONLY` does not appear in the same surfaces.
- Disconnect/remove vault B.
- Confirm `VAULT_B_ONLY` disappears everywhere and Settings reports no active vault.
- Capture screenshots, relevant log lines, and optional SQLite row counts for any failed step.
- If any step fails, record the exact surface and stale token before patching.

If the user chooses **Option B**:

- Back up or intentionally choose disposable normal app state before destructive reset.
- Run the same A/B proof.
- Do not close RCA13 unless the normal-state result passes all the same surfaces.

If the user chooses **Option C**:

- Record that manual runtime proof was explicitly waived.
- Keep a residual risk note that the original UI complaint was not reproduced in the running app after Wave 0.

If the user chooses **Option D**:

- Require a current repro note naming the stale token, visible surface, and exact reset/select/disconnect step.
- Patch only that named surface first.
- Still run the A/B smoke after the patch before closing RCA13.

## Decision-Ready Prompt

Choose the RCA13-P0-001 vault proof path:

1. **Recommended:** Run the isolated audit-app A/B smoke now, then send screenshots/log lines/results for analysis.
2. Run the same A/B smoke in normal app state, accepting the destructive-state risk.
3. Accept the focused automated tests and waive the manual runtime proof.
4. Authorize code work from the current complaint without guided smoke, then run the A/B proof after the patch.
