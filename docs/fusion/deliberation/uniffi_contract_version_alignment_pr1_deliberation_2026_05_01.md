# UniFFI Contract Version Alignment PR1 Deliberation - 2026-05-01

## Scope

Align the hand-written `EpistemosCoreIntegrityBridge` contract check in `Epistemos/Sync/NoteFileStorage.swift` with the generated `epistemos_core` Swift binding.

Allowed files for this slice:
- `Epistemos/Sync/NoteFileStorage.swift`
- `docs/fusion/deliberation/uniffi_contract_version_alignment_pr1_deliberation_2026_05_01.md`

Forbidden for this slice:
- protected editor files (`ProseEditor*`, `ProseTextView2`)
- protected graph/render files (`MetalGraphView`, `HologramController`, `graph-engine` render/physics internals)
- generated UniFFI bindings
- project/package files
- unrelated dirty worktree files

## Evidence

- `build-rust/swift-bindings/epistemos_core.swift` declares `bindings_contract_version = 29`.
- `docs/fusion/BUILD_TEST_FLOOR_RESULTS_2026_04_30.md` records the floor failure as a `NoteFileStorage` UniFFI contract mismatch, with generated bindings at `29` and the hand-written bridge still at `26`.
- `docs/fusion/DIRTY_DIFF_STABILIZATION_AUDIT_2026_04_30.md` records this as a required dirty-diff stabilization repair.
- `docs/fusion/deliberation/verification_blocker_repair_deliberation_2026_04_30.md` names this as a mechanical verification blocker.

## Decision

Set `bindingsContractVersion` from `26` to `29` in `EpistemosCoreIntegrityBridge`.

This is not a behavior expansion. It restores availability of the integrity bridge by making the hand-written preflight match the generated UniFFI binding contract.

## Verification

Command:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/NoteFileStorageTests test | tee /tmp/epistemos-uniffi-contract-version-note-file-storage-20260501.log
```

Result:
- Swift Testing suite `NoteFileStorage` passed.
- 25 tests in 1 suite passed.
- Result bundle: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.01_23-02-50--0500.xcresult`
- Log: `/tmp/epistemos-uniffi-contract-version-note-file-storage-20260501.log`

Observed inherited caveat:
- After `** TEST SUCCEEDED **`, Xcode still printed package-plugin failures for `Running SwiftLint for CodeEditSourceEditor` and `Running SwiftLint for CodeEditTextView`.
- This is the known external package SwiftLint plugin debt and is not introduced by this slice.

## Rollback

Revert the single constant change in `Epistemos/Sync/NoteFileStorage.swift`.

Stop triggers for future work:
- generated `epistemos_core.swift` changes to a different contract version
- `NoteFileStorageTests` reports a real Swift Testing failure
- the bridge starts reporting `UniFFI contract version mismatch` again
