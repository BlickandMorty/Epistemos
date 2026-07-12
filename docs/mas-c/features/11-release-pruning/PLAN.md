# MAS C Feature Plan - Release Pruning

ID: `MAS-C-F11-RELEASE-PRUNING-2026-07-08`
Codename: `RELEASE-PRUNING`
Status: active immediately after Keelstone inventory

## Intent

Prune the MAS target without destroying useful historical research. The goal is
a clean App Store archive, not a rushed deletion spree.

## Scope

- Target membership and `project.yml` source/resource inclusion.
- App Store compile flags and surface guards.
- Release archive scans for parked lanes and helper runtimes.
- Removal, exclusion, or quarantine of obsolete MAS target inputs.
- Documentation of retained legacy names that are temporarily wire-compatible.

## Fabric Mapping

- F1 vault bus: no direct vault changes unless test fixtures need update.
- F2 agent capability registry: only MAS June registry ships.
- F3 MAS status/provenance: no parked presence runtime ships.
- F4 graph: no direct graph changes.
- F5 provenance: release notes record what was pruned and why.
- F6 event bus: only MAS event streams ship.

## Phases

1. Map MAS target source/resource membership.
2. Classify every suspicious path/name as active MAS, parked provenance,
   forbidden runtime, or legacy name.
3. Exclude or remove only proven forbidden release inputs.
4. Add release scans and source guards.
5. Update App Review notes for retained in-process bridge behavior.

## Parked Or Forbidden

- No wholesale deletes without ownership map.
- No reverting other agents' in-flight work.
- No hiding symbols by renaming while behavior remains forbidden.
- No deleting historical docs just because they mention parked lanes.

## Acceptance Evidence

- Target membership diff.
- Classification table.
- MAS build/test checkpoint.
- Release archive scan.
- App Review note for any retained legacy bridge name.

