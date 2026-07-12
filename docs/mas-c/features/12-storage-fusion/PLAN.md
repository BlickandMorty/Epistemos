# MAS C Feature Plan - Storage Fusion

ID: `MAS-C-F12-STORAGE-FUSION-2026-07-08`
Codename: `STORAGE-FUSION`
Status: active after Keelstone baseline proof

## Intent

Design the best durable storage architecture without drifting away from the
user-visible vault. The target is a proprietary-feeling, high-integrity storage
system that still respects MAS sandboxing and file truth.

## Scope

- File-truth vault.
- Append-only provenance/op-log.
- Rebuildable GRDB/search/graph indexes.
- Conflict and recovery model.
- Evaluation of old storage architecture as source material.
- Optional proprietary acceleration/witness layer, never silent divergence.

## Fabric Mapping

- F1 vault bus: owns truth contract and artifact manifests.
- F2 agent capability registry: tools read/write through storage APIs with
  approval and provenance.
- F3 MAS status/provenance: shows indexing, reconciling, recovering, conflict.
- F4 graph: graph is derived or explicitly rebuildable from vault/provenance.
- F5 provenance: op-log and editor provenance join into one witness model.
- F6 event bus: storage events feed all MAS surfaces.

## Phases

1. Map current storage truth, indexes, provenance, and recovery paths.
2. Map old storage architecture and identify reusable ideas.
3. Decide keep/hybridize/retire for each storage component.
4. Implement one additive hardening unit: op-log, manifest, index rebuild, or
   recovery proof.
5. Prove no silent divergence between vault files and derived state.

## Parked Or Forbidden

- No rollback to old DB-as-truth without a lossless export/reconstruction proof.
- No proprietary black box that traps user data.
- No silent index authority.
- No data-loss migration.

## Acceptance Evidence

- Storage truth map.
- Old architecture verdict table.
- Rebuild fixture.
- Conflict/recovery fixture.
- Migration/rollback proof if any schema changes.
- MAS sandbox and file-permission proof.

