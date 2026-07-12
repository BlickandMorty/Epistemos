# MAS C Feature Index

ID: `MAS-C-FEATURE-INDEX-2026-07-08`

This is the quick dashboard for the MAS C feature stack. It does not replace
the individual feature plans; it tells an agent which file to open, which
feature depends on which prior work, and what evidence proves the feature is
really moving toward MAS C.

## Feature Dashboard

| Order | Feature | Feature ID | Plan | Build prompt | Depends on | First proof |
|---|---|---|---|---|---|---|
| 1 | Keelstone | `MAS-C-F01-KEELSTONE` | `features/01-keelstone/PLAN.md` | `features/01-keelstone/BUILD_PROMPT.md` | MAS lock, vault writers, release scripts | vault fixture plus MAS entitlement/privacy/archive scan |
| 2 | Release Pruning | `MAS-C-F11-RELEASE-PRUNING` | `features/11-release-pruning/PLAN.md` | `features/11-release-pruning/BUILD_PROMPT.md` | Keelstone inventory | target membership classification plus release archive scan |
| 3 | MAS June | `MAS-C-F02-MAS-JUNE` | `features/02-mas-june/PLAN.md` | `features/02-mas-june/BUILD_PROMPT.md` | Keelstone, Release Pruning | one active agent registry plus approval/cancel/rollback proof |
| 4 | Epdoc Assist | `MAS-C-F05-EPDOC-ASSIST` | `features/05-epdoc-assist/PLAN.md` | `features/05-epdoc-assist/BUILD_PROMPT.md` | MAS June, LumenLens seams | selected-note assist flow plus approved write/undo proof |
| 5 | LumenLens | `MAS-C-F03-LUMENLENS` | `features/03-lumenlens/PLAN.md` | `features/03-lumenlens/BUILD_PROMPT.md` | Keelstone, MAS June | minimal-diff note write plus provenance and undo |
| 6 | Storage Fusion | `MAS-C-F12-STORAGE-FUSION` | `features/12-storage-fusion/PLAN.md` | `features/12-storage-fusion/BUILD_PROMPT.md` | Keelstone, LumenLens | storage truth map plus rebuild/recovery fixture |
| 7 | Reckoner | `MAS-C-F04-RECKONER` | `features/04-reckoner/PLAN.md` | `features/04-reckoner/BUILD_PROMPT.md` | Storage Fusion, LumenLens, MAS June | vault dataset fixture plus calc/provenance/undo |
| 8 | Embercatch | `MAS-C-F06-EMBERCATCH` | `features/06-embercatch/PLAN.md` | `features/06-embercatch/BUILD_PROMPT.md` | Keelstone | capture note fixture plus privacy/permission evidence |
| 9 | Sync | `MAS-C-F08-SYNC` | `features/08-sync/PLAN.md` | `features/08-sync/BUILD_PROMPT.md` | Keelstone, Storage Fusion | add/update/delete/conflict fixture |
| 10 | Lodestar | `MAS-C-F07-LODESTAR` | `features/07-lodestar/PLAN.md` | `features/07-lodestar/BUILD_PROMPT.md` | MAS June, Storage Fusion, legality matrix | legal source table plus saved source card/note |
| 11 | Capabilities | `MAS-C-F09-CAPABILITIES` | `features/09-capabilities/PLAN.md` | `features/09-capabilities/BUILD_PROMPT.md` | MAS June, Release Pruning | capability classification plus one safe end-to-end tool |
| 12 | Sigilry | `MAS-C-F10-SIGILRY` | `features/10-sigilry/PLAN.md` | `features/10-sigilry/BUILD_PROMPT.md` | core surfaces visible | screenshot evidence plus state-to-symbol mapping |

## Why This Order Exists

- Keelstone and Release Pruning come first because no feature is trustworthy if
  the MAS archive can still ship parked lanes, hidden runtime inputs, or
  unreviewed entitlements.
- MAS June comes before agent-facing features because every active agent action
  must use the same `agent_core` registry, event stream, approval path, and
  provenance trail.
- Epdoc Assist and LumenLens come before Reckoner/Lodestar because the app needs
  a durable note/editor workspace before datasets and research objects become
  deeply useful.
- Storage Fusion comes before Sync and broad data workflows because sync and
  datasets need a settled truth/rebuild/recovery contract.
- Sigilry is last as a release-polish checkpoint, but it can run small asset or
  status-symbol audits earlier when a feature changes visible UI.

## Feature Read Template

For any feature, read in this order:

1. `README.md`
2. `MAS_C_CONTROL.md`
3. `MAS_C_FEATURE_INDEX.md`
4. `MAS_C_ANTI_DRIFT_GUARD.md`
5. The feature `PLAN.md`
6. The feature `BUILD_PROMPT.md`
7. `MAS_C_RELEASE_EVIDENCE_GATE.md`
8. Any linked local source files and tests

## Feature Completion Minimum

A feature is not complete at the packet level unless:

- its plan and build prompt exist
- its dependency row in this index is still correct
- its F1-F6 mapping has no contradiction with `INTEGRATION_FABRIC.md`
- its acceptance proof names a real source/runtime/release check
- any new research is recorded in `MAS_C_TRACEABILITY_MATRIX.md`
- the zip has been rebuilt after edits

