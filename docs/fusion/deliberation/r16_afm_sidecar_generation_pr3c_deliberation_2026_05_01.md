# R16 AFM Sidecar Generation PR3C Deliberation - 2026-05-01

## Verdict

Approved for a narrow Swift-only PR3C slice that adds AFM-generated sidecar
payload fields and wires them into the existing graph scan path for changed,
eligible note files.

This gate does not approve Rust ETL dispatch, battery/thermal pause logic,
MAS bookmark changes, editor badge UI, generated UniFFI bindings, or any
protected editor/graph renderer/controller path.

## Scope

Add the missing R16 sidecar-generation payload layer without duplicating the
existing ontology classifier:

- `OntologyClassifier` remains the owner of ontology/depth fields.
- New `AFMSidecarGenerator` owns generated summary, tags, entities, and
  suggested-link fields.
- `EpistemosSidecarStore.write(..., modelDerived: true)` remains the single
  xattr marking path.
- `EntityExtractor.scanVault(...)` invokes the generator only for changed,
  eligible notes, preserving the current hash-based skip behavior.

## Authority Evidence

- `docs/plan/03_EXECUTION_MAP.md` R16 requires AFM sidecar generation,
  one-in-flight throttling, code-file exclusion, and `xattr`
  `com.epistemos.modelDerived = true` on generated sidecars.
- `docs/RESEARCH_DOSSIER_TIER_3_4.md` R16 recommends Rust for walk/hash/queue
  and Swift for AFM calls because Foundation Models is Swift-only.
- `Epistemos/Engine/EpistemosSidecar.swift` already owns the sidecar wire
  format, eligibility policy, deterministic write path, cache refresh, and
  model-derived xattr marker.
- `Epistemos/Graph/OntologyClassifier.swift` already writes ontology/depth
  fields and must be reused rather than replaced.
- `Epistemos/Graph/EntityExtractor.swift` already scans changed notes and
  routes eligible note files through AFM-backed ontology classification.

## Allowed Files

- `Epistemos/Engine/EpistemosSidecar.swift`
- `Epistemos/Engine/AFMSidecarGenerator.swift`
- `Epistemos/Graph/EntityExtractor.swift`
- `EpistemosTests/AFMSidecarGeneratorTests.swift`
- `EpistemosTests/GraphBuilderComprehensiveTests.swift`
- `docs/fusion/deliberation/r16_afm_sidecar_generation_pr3c_deliberation_2026_05_01.md`
- `docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_033_2026_05_01.md`
- `docs/fusion/BUILD_TEST_FLOOR_RESULTS_2026_04_30.md`

## Forbidden Files

- `Epistemos/Views/Notes/ProseEditor*.swift`
- `Epistemos/Views/Graph/MetalGraphView.swift`
- `Epistemos/Views/Graph/HologramController.swift`
- `graph-engine/**`
- `epistemos-shadow/**`
- `agent_core/**`
- Xcode project/workspace files, entitlements, generated bindings, generated
  libraries, DerivedData, `.xcresult`, staging, commit, stash, or branch ops.

## Acceptance

- Sidecar schema gains backward-compatible optional fields for generated
  summary, tags, entities, and suggested links.
- `AFMSidecarGenerator` uses Foundation Models when available, shares
  `AFMSessionPool`, and serializes calls so only one generation runs at a time.
- A deterministic persist/merge seam is testable without invoking AFM.
- Generated sidecar writes use `modelDerived: true`, preserving the existing
  `com.epistemos.modelDerived = true` xattr path.
- Code/config/build files remain ineligible.
- `EntityExtractor.scanVault(...)` invokes the generator for changed eligible
  note files only and treats generation failure as nonfatal.

## Tests

- Focused generator tests prove payload persistence, xattr marking, source-file
  exclusion, and preservation of existing ontology fields.
- Existing graph builder tests gain coverage that changed eligible notes route
  through the generator and ineligible source files do not.
- Focused Xcode lanes:
  - `EpistemosTests/AFMSidecarGeneratorTests`
  - `EpistemosTests/GraphBuilderComprehensiveTests`

## Stop Triggers

- Any implementation requires touching protected note editor, graph renderer,
  graph controller, Rust ETL, `epistemos-shadow`, generated bindings, project
  files, or entitlements.
- The generator duplicates ontology/depth logic instead of reusing the current
  sidecar merge surface.
- Generated sidecars are written for `.swift`, `.rs`, `.py`, `.json`, `.toml`,
  build directories, or source-control directories.
- AFM unavailability becomes fatal to graph scanning.
- The focused Swift tests fail.

## WRV

This is not the terminal R16 WRV claim. It is wired into an existing production
graph scan path, reachable whenever the app triggers graph scan/rebuild, and
visible at the file-system/provenance layer through generated sidecar JSON and
the `com.epistemos.modelDerived = true` xattr. The editor badge UI remains a
future PR because protected note editor files are explicitly out of scope.
