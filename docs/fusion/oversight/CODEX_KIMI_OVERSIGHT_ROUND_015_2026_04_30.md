# Codex/Kimi Oversight Round 015 — 2026-04-30

## Verdict

W10.12 Sidecar Interpretation Directive passed focused automated verification. Proceed to the next deliberated build slice; do not claim vault-wide sidecar ETL, UI badge coverage, or manual runtime verification until those receive their own gate.

## Scope

- Added optional `interpretationDirective` to `EpistemosSidecar`.
- Encoded the new field as `interpretation_directive` in the JSON sidecar wire format.
- Bumped the current sidecar schema to `3` while preserving v2 decode compatibility.
- Added an explicit `modelDerived` write flag for sidecar writes.
- Marked only explicit model-derived sidecar writes with `com.epistemos.modelDerived = true`.
- Wired `OntologyClassifier.classifyAndPersist(...)` to emit the additive directive and opt into the model-derived xattr.

## Files Touched

- `Epistemos/Engine/EpistemosSidecar.swift`
- `Epistemos/Graph/OntologyClassifier.swift`
- `EpistemosTests/EpistemosSidecarTests.swift`
- `docs/fusion/deliberation/w1012_sidecar_interpretation_directive_deliberation_2026_04_30.md`
- `docs/fusion/BUILD_TEST_FLOOR_RESULTS_2026_04_30.md`
- `docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_015_2026_04_30.md`

## Verification

Red:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/EpistemosSidecarTests test
```

- Log: `/tmp/epistemos-w1012-sidecar-directive-red-20260430.log`
- Result: `** TEST FAILED **`
- Expected failures:
  - missing `EpistemosSidecar.interpretationDirective`;
  - missing `EpistemosSidecarStore.modelDerivedAttributeName`;
  - missing `modelDerived` write argument.

Green:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/EpistemosSidecarTests test
```

- Log: `/tmp/epistemos-w1012-sidecar-directive-green-20260430.log`
- Exit code `0`.
- Result: `** TEST SUCCEEDED **`
- Result bundle:
  `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.04.30_22-08-29--0500.xcresult`
- Swift Testing result: `16` tests passed in `1` suite.

Audits:

```bash
rg -n "interpretationDirective|interpretation_directive|currentSchemaVersion: UInt16 = 3|modelDerivedAttributeName|modelDerived: true|setxattr|com.epistemos.modelDerived|W10.12 Sidecar Interpretation Directive" Epistemos/Engine/EpistemosSidecar.swift Epistemos/Graph/OntologyClassifier.swift EpistemosTests/EpistemosSidecarTests.swift docs/fusion
git diff --check -- Epistemos/Engine/EpistemosSidecar.swift Epistemos/Graph/OntologyClassifier.swift EpistemosTests/EpistemosSidecarTests.swift
rg -n "[[:blank:]]$" Epistemos/Engine/EpistemosSidecar.swift Epistemos/Graph/OntologyClassifier.swift EpistemosTests/EpistemosSidecarTests.swift docs/fusion/deliberation/w1012_sidecar_interpretation_directive_deliberation_2026_04_30.md docs/fusion/BUILD_TEST_FLOOR_RESULTS_2026_04_30.md docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_015_2026_04_30.md
git diff --name-only | rg "^(Epistemos/Views/Notes/ProseEditor|Epistemos/Views/Graph/MetalGraphView\\.swift|Epistemos/Views/Graph/HologramController\\.swift|graph-engine/src/(renderer|physics|forces|simulation|motion)|src-tauri/|\\.\\./Epistemos-RETRO|\\.\\./meta-analytical-pfc)"
```

- Source audit log: `/tmp/epistemos-w1012-sidecar-directive-source-audit-20260430.log`
- Tracked-source diff check log: `/tmp/epistemos-w1012-diff-check-20260430.log` (`0` bytes).
- Touched-file whitespace audit log: `/tmp/epistemos-w1012-whitespace-audit-20260430.log` (`0` bytes).
- Protected diff audit log: `/tmp/epistemos-w1012-protected-diff-audit-20260430.log`
- Protected diff audit reports pre-existing dirty graph-engine internals:
  - `graph-engine/src/forces.rs`
  - `graph-engine/src/motion/curl.rs`
  - `graph-engine/src/motion/waves.rs`
  - `graph-engine/src/renderer.rs`
  - `graph-engine/src/simulation.rs`
- This slice did not edit protected graph-engine internals, protected note editor paths, protected graph renderer/controller paths, project files, entitlements, generated artifacts, stash state, branch state, staging, or commits.

## Residual Risk

- No vault-wide ETL, migration, or generated-sidecar backfill was implemented.
- No UI badge or Quick Look display for `com.epistemos.modelDerived` was implemented.
- No manual app runtime verification was performed in this slice by current autonomous build instruction.
- Existing SwiftLint package script failures for `CodeEditSourceEditor` and `CodeEditTextView` remain unrelated plugin/lint debt after `** TEST SUCCEEDED **`.

## Kimi Boundary

- Kimi provided read-only advisory only.
- Kimi did not edit code, run repo mutations, or control the worktree.
- Future Kimi use should remain read-only unless a fresh explicit deliberation/write gate approves a bounded write scope.
