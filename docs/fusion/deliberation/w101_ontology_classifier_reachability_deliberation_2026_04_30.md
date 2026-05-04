# W10.1 Ontology Classifier Reachability Deliberation — 2026-04-30

## Gate

Approved for a minimal, test-first production wire.

## Scope

- Make `OntologyClassifier` reachable from the existing graph vault scan path.
- Keep Foundation Models availability gated and nonfatal.
- Preserve the existing deterministic `GraphBuilder` output; no graph-render, physics, or note-editor edits.
- Persist structured `parent_domain`, `child_concept`, `depth`, and confidence to eligible markdown/text sidecars.
- Never classify or write sidecars for source-code paths.

## Explicit Non-Scope

- No Kimi code edits.
- No manual UI verification in this slice.
- No `MetalGraphView`, `HologramController`, `ProseEditor*`, Rust renderer, or physics changes.
- No claim that W10.1 quality is ship-ready without the later W11.3 Foundation Models evaluation corpus.

## Evidence Before Edit

- `Epistemos/Graph/OntologyClassifier.swift` already implements the AFM structured-output caller and sidecar write method.
- `Epistemos/Graph/EntityExtractor.swift` did not call `OntologyClassifier.shared`.
- `Epistemos/Engine/EpistemosSidecar.swift` persisted `parent_domain` and `depth`, but not structured `child_concept`.
- Red test log: `/tmp/epistemos-w101-ontology-red-20260430.log`
  - Failed as expected with `Cannot find type 'OntologyClassifying' in scope`.
  - Failed as expected with `Extra argument 'ontologyClassifier' in call`.

## Decision

Wire the classifier through a small `OntologyClassifying` protocol so tests can prove reachability without invoking AFM. During `EntityExtractor.scanVault`, classify only changed pages with eligible `filePath` values. Treat unavailable models, ineligible sources, empty text, and classifier errors as nonfatal so graph scans remain useful on unsupported or model-loading systems.

## Verification

Focused graph-scan red/green:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/GraphBuilderNoteDerivedEntityTests test
```

- Red log: `/tmp/epistemos-w101-ontology-red-20260430.log`
- Green log: `/tmp/epistemos-w101-ontology-green-20260430.log`
- Green exit code: `0`
- Green result bundle:
  `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.04.30_21-39-45--0500.xcresult`
- Result: `** TEST SUCCEEDED **`
- Swift Testing result: `5` tests in `1` suite passed.

Sidecar compatibility:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/EpistemosSidecarTests test
```

- Log: `/tmp/epistemos-w101-sidecar-green-20260430.log`
- Exit code: `0`
- Result bundle:
  `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.04.30_21-42-25--0500.xcresult`
- Result: `** TEST SUCCEEDED **`
- Swift Testing result: `12` tests in `1` suite passed.

Post-slice source guards:

- Source audit: `/tmp/epistemos-w101-ontology-source-audit-20260430.log`
- Diff check: `/tmp/epistemos-w101-diff-check-20260430.log`
- Protected-path audit: `/tmp/epistemos-w101-protected-diff-audit-20260430.log`
