# Full Floor Stale Guard Alignment Deliberation - 2026-04-30

## Verdict

Approved: **minimal test/source-guard alignment slice only**.

This is not approval for product feature work, search/index schema repair, model-vault UI changes, graph inspector changes, protected editor/graph edits, staging, commits, or raw worktree merges.

## Current Evidence

The focused verification-blocker repair passed:

- `NoteFileStorageTests`: `25` tests passed.
- `ArtifactProvenanceParityTests`: `12` tests passed.
- `CargoReleaseProfileTests`: `4` tests passed.

The full Swift floor then improved but remained red:

- Before repair: `5021` tests in `563` suites failed with `100` issues.
- After repair: `5021` tests in `563` suites failed with `30` issues.
- Result bundle:
  `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.04.30_15-07-45--0500.xcresult`
- Raw log:
  `/tmp/epistemos-full-test-after-focused-repair-20260430.log`

Several remaining failures are stale source guards, not new runtime regressions:

- `GRDBPragmaTests` expects the old 1 GiB mmap / 64 MiB cache profile, while `SearchIndexService` now documents the intentional derivative-index trim to 256 MiB mmap / 8 MiB cache.
- `PGOAndArenasTests` still requires `[profile.release-pgo] lto = "thin"`, conflicting with the just-approved canonical release-profile contract and the now-passing `CargoReleaseProfileTests`.
- `LocalModelInfrastructureTests` still assumes the structured tool-calling stack is unavailable, while this build target now links it and `LocalToolGrammar.supportsStructuredToolCalling == true`.
- `AgentCommandCenterStateTests` expects DeepSeek R1 to expose only `.thinking`; current Command Center code exposes `.thinking` plus `.agent` when the structured local agent stack is linked.
- `TriageServiceTests` expects the older 10s normal idle unload floor on an 18 GB machine, while `LocalMLXRuntimeTuning` documents the 2026-04 aggressive memory tuning of 6s normal / 3s low-power for the 16-24 GB tier.

## Approved Files

Allowed edits are limited to these test files:

- `EpistemosTests/AgentCommandCenterStateTests.swift`
- `EpistemosTests/GRDBPragmaTests.swift`
- `EpistemosTests/LocalModelInfrastructureTests.swift`
- `EpistemosTests/PGOAndArenasTests.swift`
- `EpistemosTests/TriageServiceTests.swift`

No production Swift, Rust, project, plist, entitlement, generated, or protected files are approved in this slice.

## Approved Changes

- Update the DeepSeek Command Center expectation to require no `.fast` mode while accepting `.agent` when the structured local agent stack is available.
- Update GRDB pragma expectations and test names to the documented 256 MiB mmap / 8 MiB cache profile.
- Update local model infrastructure wording/assertions so structured tool calling may be available, while still proving the local agent loop stays exposed.
- Update PGO guard wording/assertions to require `[profile.release-pgo]` inherit the canonical release profile and not reintroduce `lto = "thin"`.
- Update the 18 GB local runtime tuning assertion to the documented 6s normal / 3s low-power behavior.

## Forbidden

- no edits to `Epistemos/Views/Notes/ProseEditor*.swift`
- no edits to `Epistemos/Views/Graph/MetalGraphView.swift`
- no edits to `Epistemos/Views/Graph/HologramController.swift`
- no edits to `Epistemos/Sync/SearchIndexService.swift`
- no edits to `Epistemos/Views/Graph/NodeInspectorState.swift` or `PinnedInspector.swift`
- no edits to `Epistemos/App/AppBootstrap.swift`
- no edits to `Epistemos/Views/Landing/*`
- no edits to `agent_core/`, `graph-engine/`, Cargo manifests, project files, plists, entitlements, generated files, DerivedData, or `.xcresult`
- no staging or commits

## Alternatives Considered

- Revert product code to old guard expectations: rejected because the current source comments explicitly document the new memory, local-agent, and runtime-tuning behavior.
- Broaden into runtime fixes for search/index, model-vault, graph inspector, and landing guard failures: rejected for this slice because those need separate evidence and may touch production surfaces.
- Defer all test alignment: rejected because stale guards hide the remaining real blockers and keep the full floor noisier than necessary.

## Tests

Run focused suites after edits:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/AgentCommandCenterStateTests
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/GRDBPragmaTests
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/LocalModelInfrastructureTests
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/PGOAndArenasTests
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/TriageServiceTests
```

Then rerun the full Swift floor and compare issue count.

## Rollback

Revert only the five test-file edits from this slice. Do not revert unrelated dirty changes already present in the worktree.

## Stop Triggers

- Any production file becomes necessary for this slice.
- Any protected path becomes dirty.
- A focused suite fails for a reason outside the allowed stale-guard assertions.
- Full floor issue count increases.
- Kimi or any tool attempts to stage, commit, raw-merge, or edit beyond this file set.
