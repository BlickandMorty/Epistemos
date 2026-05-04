# W10.12 Sidecar Interpretation Directive Deliberation — 2026-04-30

## Gate

Approved for a minimal Core/MAS-safe sidecar contract repair.

## Classification

Core/MAS-safe.

## Scope

- Add optional `interpretation_directive` storage to `EpistemosSidecar`.
- Preserve dual representation: Markdown/plain-text source remains human-readable and primary; `.epistemos.json` is additive machine-readable state.
- Preserve and test the hard code-file exclusion policy.
- Add an explicit `modelDerived` write flag that marks AFM-generated `.epistemos.json` sidecar files with `com.epistemos.modelDerived = true` so generated sidecars are inspectable/auditable at the file level.
- Add focused tests for schema round-trip, backward-compatible v2 decode, deterministic JSON key, and opt-in xattr marking.

## Explicit Non-Scope

- No ETL crawler, background job queue, AFM generation loop, or vault-wide migration.
- No editor UI/model-derived badge, Quick Look integration, or manual app verification in this slice.
- No protected note editor, graph renderer, graph-engine, Rust, project, entitlement, generated artifact, branch, stash, staging, or commit changes.
- No Markdown replacement and no sidecar writes for code/config/build files.

## Evidence Before Edit

- `EpistemosSidecar` already stores `schema_version`, `entity_id`, `depth`, `parent_domain`, `child_concept`, `derived_from`, `embeddings`, `cognitive_meta`, and `annotations`.
- `EpistemosSidecarPolicy` already excludes programming languages, JSON/config/build files, shader files, and build/source-control directories.
- `EpistemosSidecarStore.sidecarURL(for:)` already writes `<stem>.epistemos.json` next to eligible Markdown/text sources.
- `OntologyClassifier.classifyAndPersist(...)` is the current AFM-derived sidecar writer.
- W10.12 canonical docs require additive dual representation, `interpretation_directive`, and "NEVER apply to code files".
- R16 execution-map telemetry requires generated sidecars to be `xattr`-marked with `com.epistemos.modelDerived = true`.
- Kimi read-only advisory warned that unconditional xattr marking would falsely label generic/user sidecar writes; use an explicit opt-in flag instead.

## Decision

Treat W10.12 as a sidecar contract slice, not a crawler or UI slice. Add the missing field and opt-in file-level generated marker to the existing store, then prove the current exclusion policy still blocks source/config files. Bump the sidecar schema version because the wire contract gains a semantic field, while preserving v2 decode compatibility because the new field is optional.

## Test Plan

- Add failing tests in `EpistemosSidecarTests` proving:
  - `interpretationDirective` round-trips;
  - encoded JSON contains `interpretation_directive`;
  - current schema version is bumped;
  - v2 sidecars without the new field still decode;
  - generic writes stay unmarked;
  - explicit `modelDerived` writes mark the emitted sidecar with `com.epistemos.modelDerived = true`.
- Run:
  `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/EpistemosSidecarTests test`

## Stop Triggers

- Any need to edit protected editor/graph paths, graph-engine/Rust, project files, entitlements, generated artifacts, or build outputs.
- Any implementation that writes sidecars for `.swift`, `.rs`, `.py`, `.json`, `.toml`, `.metal`, build dirs, or source-control dirs.
- Any implementation that replaces or mutates the Markdown source layer.
- xattr marking cannot compile or fails on the macOS test filesystem.
- xattr marking is unconditional rather than explicit for AFM/model-derived writes.

## Result

Passed focused automated verification.

Implemented:

- `EpistemosSidecar` now has optional `interpretationDirective` encoded as `interpretation_directive`.
- Current sidecar schema version is `3`; v2 sidecars without the new optional key still decode.
- `EpistemosSidecarStore.write(..., modelDerived:)` defaults to `false`, preserving generic/user writes.
- Explicit model-derived writes mark the emitted sidecar with `com.epistemos.modelDerived = true`.
- `OntologyClassifier.classifyAndPersist(...)` writes the additive model-facing directive and uses `modelDerived: true`.

Verification:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/EpistemosSidecarTests test
```

- Red log: `/tmp/epistemos-w1012-sidecar-directive-red-20260430.log`
- Red result: `** TEST FAILED **` with expected missing `interpretationDirective`, `modelDerivedAttributeName`, and `modelDerived` write signature failures.
- Green log: `/tmp/epistemos-w1012-sidecar-directive-green-20260430.log`
- Green result: `** TEST SUCCEEDED **`
- Green result bundle:
  `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.04.30_22-08-29--0500.xcresult`
- Swift Testing result: `16` tests passed in `1` suite.

Audits:

- Source audit log: `/tmp/epistemos-w1012-sidecar-directive-source-audit-20260430.log`
- Tracked-source diff check log: `/tmp/epistemos-w1012-diff-check-20260430.log` (`0` bytes).
- Touched-file whitespace audit log: `/tmp/epistemos-w1012-whitespace-audit-20260430.log` (`0` bytes).
- Protected diff audit log: `/tmp/epistemos-w1012-protected-diff-audit-20260430.log`
- Protected diff audit reports pre-existing dirty graph-engine internals: `graph-engine/src/forces.rs`, `graph-engine/src/motion/curl.rs`, `graph-engine/src/motion/waves.rs`, `graph-engine/src/renderer.rs`, and `graph-engine/src/simulation.rs`.
- This slice did not edit protected graph/editor paths, Rust graph-engine paths, project files, entitlements, generated artifacts, branch state, stash state, staging, or commits.

Deferred:

- No vault-wide ETL crawler, migration, or UI badge was implemented in this slice.
- No manual app runtime verification was performed by current autonomous-build instruction; this remains a later release-audit/manual pass item.
- Xcode still reports SwiftLint package command failures for `CodeEditSourceEditor` and `CodeEditTextView` after `** TEST SUCCEEDED **`; this remains unrelated existing plugin/lint debt.
