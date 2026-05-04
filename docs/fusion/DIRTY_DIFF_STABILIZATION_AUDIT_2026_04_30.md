# Dirty-Diff Stabilization Audit - 2026-04-30

## Gate

This audit is the documentation-only output approved by `docs/fusion/deliberation/dirty_diff_stabilization_deliberation_2026_04_30.md`.

No source edits, cleanup, stash application, staging, commits, branch changes, or generated-file deletion were approved for this item.

## Baseline

The build/test floor is green at the time of this checkpoint.

Evidence recorded in `docs/fusion/BUILD_TEST_FLOOR_RESULTS_2026_04_30.md`:

- Full Swift test floor passed: `5021` tests in `563` suites passed after `380.956` seconds.
- Full Swift test log: `/tmp/epistemos-full-test-after-rrf-fts-20260430.log`.
- Full Swift result bundle: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.04.30_16-56-20--0500.xcresult`.
- `graph-engine cargo test` passed: `2522` passed, `0` failed, `8` ignored.
- `agent_core cargo test` passed: library `774` passed, bin/e2e/doc-test set passed, doc-tests `2` ignored.
- Xcode still reports SwiftLint command failures for `CodeEditSourceEditor` and `CodeEditTextView` after `** TEST SUCCEEDED **`; this remains lint/build-script debt, not a current test-floor blocker.

## Main Worktree State

Command:

```bash
git status --short -uall | ruby -ne 'BEGIN{h=Hash.new(0);n=0}; h[$_.byteslice(0,2)] += 1; n += 1; END{h.sort.each{|k,v| puts "#{k.inspect} #{v}"}; puts "TOTAL #{n}"}'
```

Result:

- `" M"`: `516`
- `"??"`: `801`
- Total status entries: `1317`

Post-output self-check:

- Writing this audit added one expected untracked file.
- Current status after this audit exists is `" M" 516`, `"??" 802`, total `1318`.

Command:

```bash
git diff --stat
```

Result:

- `516` tracked files changed.
- `17645` insertions.
- `3012` deletions.

Interpretation:

- The worktree is intentionally and heavily dirty.
- A green floor exists in this dirty state.
- The dirty state must not be normalized automatically while the user is away.
- Any cleanup, deletion, stash application, or raw donor merge requires a separate explicit gate.

## Protected-Path Guardrail

Command:

```bash
git diff -- Epistemos/Views/Notes/ProseEditor\*.swift Epistemos/Views/Graph/MetalGraphView.swift Epistemos/Views/Graph/HologramController.swift
```

Result:

- No diff output.

Protected paths remain clean for this gate:

- `Epistemos/Views/Notes/ProseEditor*.swift`
- `Epistemos/Views/Graph/MetalGraphView.swift`
- `Epistemos/Views/Graph/HologramController.swift`

Policy:

- Do not edit these paths during the current fusion lane.
- `Epistemos/Views/Notes/ProseEditor*.swift` remains especially guarded because the note editor is a data-loss-risk surface.
- `Epistemos/Views/Graph/MetalGraphView.swift` and `Epistemos/Views/Graph/HologramController.swift` remain guarded because graph rendering and overlay behavior are high-risk runtime surfaces.

## Codex-Owned Changes In This Session

The following changes are deliberate, narrow repairs made under prior deliberation gates. They are not staged or committed.

- `Epistemos/Sync/NoteFileStorage.swift`: aligned the hand-written UniFFI contract version with generated bindings.
- `Epistemos/Models/ArtifactKind.swift`: restored lower-snake-case wire encoding while tolerating legacy numeric decode.
- `agent_core/Cargo.toml`: removed the manual `release-pgo` thin-LTO override from the canonical release-profile contract.
- `EpistemosTests/CargoReleaseProfileTests.swift`: realigned release-profile and `catch_unwind` source audits.
- `EpistemosTests/ArtifactKindParityTests.swift`, `EpistemosTests/ArtifactProvenanceParityTests.swift`, `EpistemosTests/MutationEnvelopeParityTests.swift`: repaired source-mirror parity guards.
- `Epistemos.xcodeproj/project.pbxproj`: added the bundled Rust audit source mirror phase used by source guards.
- `Epistemos/KnowledgeFusion/CloudKnowledgeDistillationService.swift` and `Epistemos/App/AppBootstrap.swift`: fixed stale startup model-vault target snapshotting by injecting a live main-actor target provider.
- `EpistemosTests/HarnessSubsystemTests.swift`, `EpistemosTests/NonAgentPruningValidationTests.swift`, `EpistemosTests/RuntimeValidationTests.swift`, `EpistemosTests/ThemePairTests.swift`, and related source-guard tests: realigned stale guards to current behavior.
- `EpistemosTests/SearchIndexServiceFusionTests.swift` and `EpistemosTests/RRFFusionQueryTests.swift`: repaired FTS-sensitive fixtures and kept Rust RRF constant parity active everywhere.
- `docs/fusion/BUILD_TEST_FLOOR_RESULTS_2026_04_30.md`: updated the verification record to the final green floor.
- `docs/fusion/deliberation/sqlite_fts_fusion_floor_deliberation_2026_04_30.md`: recorded the approved SQLite/FTS floor repair gate.
- `docs/fusion/deliberation/dirty_diff_stabilization_deliberation_2026_04_30.md`: recorded this documentation-only gate.

## Unapproved Dirty Work

The remaining dirty state includes broad donor work, generated artifacts, research documents, App Store/distribution files, Rust backend changes, and UI/feature lanes. These changes are not automatically approved by the green test floor.

High-risk categories:

- `graph-engine/` dirty implementation diff. It currently passes `cargo test`, but broad graph-engine behavior is not approved for merge.
- `agent_core/` dirty implementation diff. It currently passes `cargo test`, but broad agent behavior is not approved for merge.
- `substrate-core/target/` generated Rust artifacts. Do not delete or reset without a cleanup gate.
- `Epistemos.xcodeproj/project.pbxproj`, App Store scheme/plist, and distribution scripts. These can affect release packaging and must be reviewed explicitly.
- Pro/MAS/App Store boundary files and sandbox feature gates. These must be audited against the current distribution target.
- Large untracked and modified documentation/research corpus. Preserve as context; do not bulk-delete or reflow.

## Stash Inventory And Policy

Command:

```bash
git stash list --stat
```

Observed stashes:

| Stash | Summary | Stat | Decision |
| --- | --- | --- | --- |
| `stash@{0}` | `session-stash-2026-04-27: W9.21 PR4 (X salvaged) + W9.8 wire-up partial; restart-fresh per user` | `10` files, `1511` insertions, `191` deletions | Do not pop. Contains high-risk runtime/UI/Rust work and binary artifact drift. |
| `stash@{1}` | `codex-wip-parallel-during-landing-wave-session` | `16` files, `664` insertions, `145` deletions | Do not pop. Extract only through future focused gates if needed. |
| `stash@{2}` | `WIP on main: 31214a4d Update progress and mark three runtime issues as patched` | `972` files, `2258` insertions, `9021` deletions | Do not pop. This stash contains project-file mass deletion risk and protected-path drift. |
| `stash@{3}` | `29c0ca83 Fix: Invisible text in code editor - isRichText must be true` | `2` files, `157` insertions, `90` deletions | Do not pop without a dedicated code-editor visibility gate. |

Stash policy:

- No `git stash pop`.
- No `git stash apply`.
- No `git stash drop`.
- No selective checkout from stash without a deliberation gate naming exact files and verification.

## Worktree Inventory And Decisions

Command:

```bash
git worktree list
```

Observed worktrees:

| Worktree | Head | Branch | Decision |
| --- | --- | --- | --- |
| `/Users/jojo/Downloads/Epistemos` | `ac8c6d28` | `feature/landing-liquid-wave` | Active dirty main worktree. Keep as current floor baseline. |
| `/Users/jojo/Downloads/Epistemos-laneA` | `12183f29` | `lane-A` | Donor only. Dirty `ApprovalModalView.swift` observed. No raw merge. |
| `/Users/jojo/Downloads/Epistemos/.claude/worktrees/agent-a0550f9c` | `6cd47481` | `worktree-agent-a0550f9c` locked | Donor only. Dirty Rust shadow/lockfile changes observed. No raw merge. |
| `/Users/jojo/Downloads/Epistemos/.claude/worktrees/hermes-parity` | `465a3c30` | `worktree-hermes-parity` | Donor only. Clean at last sample. No raw merge. |
| `/Users/jojo/Downloads/Epistemos/.claude/worktrees/inspiring-heisenberg-ea9dc3` | `31214a4d` | `claude/inspiring-heisenberg-ea9dc3` | Donor only. Clean at last sample. No raw merge. |
| `/Users/jojo/Downloads/Epistemos/.claude/worktrees/simulation` | `3163b170` | `worktree-simulation` | Donor only. Clean at last sample. No raw merge. |
| `/Users/jojo/Downloads/Epistemos/.claude/worktrees/vigorous-goldberg-3a2d35` | `0e0234d9` | `claude/vigorous-goldberg-3a2d35` | Donor only. Clean at last sample. No raw merge. |

Worktree policy:

- Do not raw-merge donor worktrees.
- Do not delete worktrees.
- Use donor worktrees only for conceptual inspection or narrow patch extraction after a deliberation gate.
- If a donor worktree contains a desirable fix, re-derive it in the active worktree with tests instead of applying wholesale.

## Kimi And Antigravity Boundary

Kimi remains source-edit locked.

Current policy:

- Kimi may review, audit, and report.
- Kimi may not write source code.
- Kimi may not apply stashes, clean files, stage, commit, or branch.
- If Kimi produces a useful plan, Codex must still perform a shell audit and deliberation gate before source edits.
- If Kimi attempts source edits or broad cleanup, stop the Kimi lane and preserve the current green floor.

## Next Allowed Gate

The next reasonable autonomous gate is a Halo live-loop audit and minimal V1 proof.

Allowed before source edits:

- Read existing Halo, ambient recall, shadow panel, live-loop, and related test files.
- Audit current behavior and existing dirty diffs.
- Create a deliberation document naming exact files, tests, expected behavior, and stop triggers.
- Keep `ProseEditor*`, `MetalGraphView.swift`, and `HologramController.swift` off-limits unless a separate protected-path gate is approved.

Not allowed without another gate:

- Implement Halo code changes.
- Modify protected editor or graph files.
- Apply donor worktree or stash content.
- Clean generated artifacts.
- Stage or commit.

## Stop Triggers

Stop the autonomous lane and preserve evidence if any of the following occur:

- A source edit is needed before an explicit deliberation gate exists.
- A stash pop/apply, raw worktree merge, cleanup, deletion, reset, or checkout is suggested.
- Protected-path drift appears in `ProseEditor*`, `MetalGraphView.swift`, or `HologramController.swift`.
- The green Swift or Rust floor regresses.
- App Store, MAS sandbox, or distribution behavior is touched without an explicit distribution gate.
- Kimi attempts to edit source or overwrite audit documents with stale context.

## Decision

Dirty-diff stabilization is complete for this documentation-only gate.

The current floor is green but fragile. The repository should proceed only through narrow, named deliberation gates with exact file ownership and test evidence.
