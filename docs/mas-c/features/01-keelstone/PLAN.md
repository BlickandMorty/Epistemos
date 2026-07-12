# MAS C Feature Plan - Keelstone

ID: `MAS-C-F01-KEELSTONE-2026-07-08`
Codename: `KEELSTONE`
Status: active first

## Intent

Make the MAS app safe to build on: vault correctness, security-scoped access,
atomic writes, release gates, and archive leak checks before feature expansion.

## Scope

- Vault files remain user-visible truth.
- Atomic write, backup, undo, conflict, and reconcile behavior are release
  infrastructure.
- App Store archive scans must prove parked lanes and helper runtimes do not
  ship accidentally.
- Entitlements, privacy manifest, and App Review notes are part of the feature.

## Fabric Mapping

- F1 vault bus: owns vault write safety, reconcile, conflict fixtures.
- F2 agent capability registry: exposes only approved vault operations to MAS
  June through `agent_core`.
- F3 MAS status/provenance: emits save, reconcile, conflict, and blocked states.
- F4 graph: uses public graph API after durable vault writes.
- F5 provenance: records write source, intent, approval, and undo handle.
- F6 event bus: publishes write/reconcile/conflict events to native and June UI.

## Phases

1. Inventory current vault writers, bookmarks, and release scripts.
2. Prove current atomic write and provenance paths with fixtures.
3. Repair MAS entitlement/privacy/archive blockers.
4. Add parked-lane leak scans to release gates.
5. Create App Review notes for vault access and loopback bridge if retained.

## Parked Or Forbidden

- No Pro git-sync lane.
- No terminal/code-exec agent tool.
- No hidden subprocess or local server that cannot be explained to App Review.
- No DB-as-truth migration.

## Acceptance Evidence

- MAS build/test checkpoint.
- Vault write fixture before/after.
- Security-scoped bookmark proof.
- Entitlement and privacy manifest printouts.
- Release archive symbol/resource scan.
- Updated evidence note listing remaining release blockers.

