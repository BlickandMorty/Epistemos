# MAS C Build Prompt - Sync

ID: `MAS-C-F08-SYNC-BUILD-2026-07-08`

```text
Build Sync for MAS C.

Read:
- docs/mas-c/MAS_C_CONTROL.md
- docs/mas-c/features/08-sync/PLAN.md
- docs/mas-c/features/01-keelstone/PLAN.md
- docs/mas-c/prompts/03_MAS_C_LEGALITY_MATRIX.md

Task:
Design or implement the next MAS-safe sync unit. Read current sync docs/code,
entitlements, vault writer, conflict handling, provenance storage, and any
CloudKit/iCloud assumptions before editing.

Rules:
- vault files stay truth
- no silent conflict loss
- no git/subprocess sync lane
- user controls cloud behavior
- June can assist conflict resolution but cannot silently merge

Required proof:
- add/update/delete/conflict fixture or source-level guard
- entitlement/privacy notes
- manual conflict UI evidence when UI changes
- MAS build/test checkpoint at phase boundary
```

