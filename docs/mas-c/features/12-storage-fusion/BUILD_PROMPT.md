# MAS C Build Prompt - Storage Fusion

ID: `MAS-C-F12-STORAGE-FUSION-BUILD-2026-07-08`

```text
Build Storage Fusion for MAS C.

Read:
- docs/mas-c/MAS_C_CONTROL.md
- docs/mas-c/features/12-storage-fusion/PLAN.md
- docs/mas-c/prompts/04_MAS_C_STORAGE_PRUNING_VERDICT.md
- docs/mas-c/features/01-keelstone/PLAN.md

Task:
Evaluate and harden storage deliberately. Start with a map of current vault
truth, atomic writer, provenance stores, indexes, graph rebuild paths, sync
paths, and any old storage architecture the owner points to.

Rules:
- file truth is the default authority
- indexes are rebuildable unless explicitly proven otherwise
- proprietary storage can be additive, not trapping
- migrations need rollback, fixtures, and data-loss tests
- agent writes require approval/provenance/undo

Required proof:
- current storage truth map
- old-storage keep/hybridize/retire table
- one rebuild or recovery fixture
- no-divergence check between vault and derived state
- MAS checkpoint if code changed
```

