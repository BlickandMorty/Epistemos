# CODEX/KIMI Oversight Round 053 - R16 MAS Bookmark Enforcement PR3F

## Scope

R16 PR3F closes the MAS/security-scoped bookmark prerequisite for any future
production ETL worker that reads vault files.

## Kimi Input

Kimi was invoked read-only for the R16 worker execution design advisory:

- `/tmp/epistemos-r16-worker-execution-kimi-design-20260501.log`

Kimi recommended against no-op ETL worker drains and identified MAS bookmark
enforcement as a production prerequisite. Codex applied that advice by choosing
the bookmark gate before any ETL worker execution wiring.

## Change Summary

- `VaultSyncService` now has a compile-time MAS/sandbox vault-access policy:
  `EPISTEMOS_APP_STORE || MAS_SANDBOX` requires security-scoped vault access.
- Direct-distribution behavior remains unchanged: plain bookmark fallback is
  still allowed outside the sandbox policy.
- MAS policy rejects plain bookmark fallback when security-scoped bookmark
  creation fails.
- MAS policy rejects automatic restore when a saved bookmark resolves only as a
  plain bookmark.
- MAS policy refuses vault watching when security-scoped access was not already
  acquired and cannot be acquired.
- Focused tests cover MAS strict validation, MAS persistence refusal, watch
  start policy, and the existing direct plain fallback.

## Evidence

Red-first summary:

- `/tmp/epistemos-r16-mas-bookmark-pr3f-red-summary-20260501.log`

Green focused Swift suite:

- `/tmp/epistemos-r16-mas-bookmark-pr3f-green-xcode-20260501-r2.log`
- `/tmp/epistemos-r16-mas-bookmark-pr3f-green-summary-20260501.log`

Result:

- `44` tests in `VaultSyncService Audit` passed.
- Xcode reported `** TEST SUCCEEDED **`.

Guardrails:

- `git diff --check` passed for the PR3F code/test/gate files.
- Policy grep found no `run_worker` or `etl_` additions.
- Targeted protected-path scan found no protected editor, graph,
  `graph-engine/**`, `epistemos-shadow/**`, project, entitlement, or plist
  paths in this slice.

## Non-Claims

- No ETL production worker execution is added.
- No queue drain or job completion semantics are claimed.
- No editor badge UI is added.
- No App Store entitlement or project-file edit is made.

## Remaining R16 Work

- ETL worker execution must use a real completion contract. Do not implement a
  no-op drain.
- Model-derived sidecar badge visibility remains protected editor work.
- Full R16 WRV is still open until those remaining surfaces are reachable.
