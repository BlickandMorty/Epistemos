# MAS C Feature Plan - Sync

ID: `MAS-C-F08-SYNC-2026-07-08`
Codename: `SYNC`
Status: active after Keelstone storage truth

## Intent

Make vault sync durable, user-visible, and App Store-safe. Sync should preserve
file truth, conflicts, provenance, and offline work without relying on Pro-only
git or hidden helper processes.

## Scope

- iCloud/CloudKit or MAS-approved sync lanes.
- Local vault reconcile and conflict UX.
- Sync status and failure visibility.
- Provenance continuity across devices where possible.
- Clear user control and rollback.

## Fabric Mapping

- F1 vault bus: sync reconciles vault files and artifacts.
- F2 agent capability registry: June can explain conflicts and prepare merges
  only after user approval.
- F3 MAS status/provenance: shows syncing, conflict, offline, retrying.
- F4 graph: rebuilds links from synced vault truth.
- F5 provenance: preserves edit/source records across sync where possible.
- F6 event bus: publishes sync lifecycle events.

## Phases

1. Inventory existing sync plan/code and MAS entitlements.
2. Decide active MAS sync lane with official-source validation.
3. Prove one add/update/delete/conflict fixture.
4. Add visible conflict resolution and provenance preservation.
5. Wire June explain/merge helper behind approval.

## Parked Or Forbidden

- No Pro git-sync lane.
- No background helper subprocess.
- No silent conflict overwrite.
- No cloud sync without disclosure and user control.

## Acceptance Evidence

- Sync fixture with conflict case.
- User-visible conflict resolution proof.
- Offline/retry proof.
- Entitlement/privacy notes.
- MAS build/test checkpoint.

