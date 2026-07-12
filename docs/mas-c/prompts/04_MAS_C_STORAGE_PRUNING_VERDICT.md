# MAS C Prompt 04 - Storage And Pruning Verdict

ID: `MAS-C-PROMPT-04-STORAGE-PRUNING-2026-07-08`

Use this when deciding whether to keep current storage, revive old storage, or
prune base-app lanes.

```text
Produce a storage and pruning verdict for MAS C.

Read the current code before advising. Compare:
- current vault-file truth
- current atomic writer and provenance stores
- append-only op-log/provenance journal options
- derived GRDB/search/graph indexes
- any older storage architecture the owner asks about

Verdict format:
1. keep / hybridize / retire / research-only
2. what owns truth
3. what is derived and rebuildable
4. data-loss and conflict risks
5. migration and rollback path
6. MAS sandbox implications
7. tests and fixtures required
8. release-gate checks

Default to file truth plus additive hardening unless the alternative proves a
lossless, user-visible, MAS-safe authority with export/reconstruction and
rollback.
```

