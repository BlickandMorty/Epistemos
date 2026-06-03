# Main-Only Worktree Reconciliation - 2026-06-03

Purpose: close the worktree/regression loop after the June 1 architecture merge
and UI repair pass. Future architecture work should run from the single active
worktree at `/Users/jojo/Downloads/Epistemos` on `main`.

## Checkpoint

- Main commit: `8f0b65ad24c2a62f994168556ce9110bd6e8bf13`
- Commit message: `Checkpoint merge regression reconciliation`
- Checkpoint tag: `checkpoint/main-only-worktree-reconciliation-2026-06-03`
- Registered worktrees after cleanup: exactly one, `/Users/jojo/Downloads/Epistemos`
- Active branch: `main`

## What Was Fixed Before Cleanup

- HTML Workspace code editor crash from out-of-range regex capture access.
- HTML Workspace blank code-pane layout regression.
- Graph inspector raw editor removal and preview scroll truncation.
- Classic theme Matrix Type Bold regression.
- Latest-build editor bundle/font feel alignment.
- Stale backend/doc guard drift in `agent_core`.

Verification before this cleanup:

- Focused Swift/Xcode preservation suite passed.
- `graph-engine` cargo tests passed.
- `agent_core` cargo tests passed.
- Latest app font resources and compressed code editor CSS matched the
  `Epistemos-Latest.app` bundle.

## Worktree Cleanup Result

All non-main worktrees were removed with `git worktree remove --force` after
the current main checkpoint was committed. Branch refs were intentionally kept
as historical recovery refs; the filesystem no longer has parallel checked-out
Epistemos worktrees.

The old Claude lock at `.claude/worktrees/agent-a0550f9c` was stale: the lock
named PID `86005`, and no matching active process was found before unlock and
removal.

The following source/doc fragments were stashed before removing their old
worktrees:

- `preserve-terminal-d-r2-actionable-fragments-before-worktree-removal-2026-06-03`
- `preserve-terminal-d-r3-actionable-fragments-before-worktree-removal-2026-06-03`
- `preserve-terminal-e-actionable-doc-fragments-before-worktree-removal-2026-06-03`
- `preserve-wrv-docs-chronicle-before-worktree-removal-2026-06-03`

Those stashes preserve the remaining uncommitted fragments. Current main was
already newer or equivalent for the live Eidos isolation fix, blocker/decision
docs, and canonical chronicle.

## Why Branches Were Not Wholesale Merged

Several branches still listed as "not merged" are patch-equivalent to current
main or contain old trees that would remove newer app surfaces if merged raw.
This is the observed regression mechanism: a merge can be mechanically clean
while still rolling product reality backward.

Examples from the dry run:

- `backup/main-cherrypick-integration-20260602` had no unique patch-id commits
  left, but its tree diff would delete current fonts and the restored code
  editor bundle.
- `salvage/t6-uiux-status-2026-05-23` looked like a small docs branch by name,
  but its tree diff would delete HTML Workspace files, June 1 docs, fonts,
  editor assets, guard tests, and other current surfaces.
- Wave/T/Terminal donor branches commonly diff against old project structure
  and would delete newer RuntimeRouter, HTML Workspace, editor, font, June 1,
  or falsifier surfaces if merged raw.

## Branch Status

Patch-equivalent / absorbed by main patch-id:

- `backup/main-cherrypick-integration-20260602`
- `codex/repromote-ui-wip-2026-05-26`
- `codex/research-snapshot-2026-05-08`
- `codex/w49-imessage-appstore-guard-2026-05-26`
- `codex/w53-model-download-sha256-2026-05-26`
- `codex/wave3-agent-metadata-badges-2026-05-26`
- `codex/wave3-agentblueprint-replay-ui-2026-05-26`
- `codex/wave4-uas-typed-retrieval-2026-05-26`
- `phase2-terminal-d-prime-health-rows-2026-05-24`
- `phase2-terminal-e-acs-gate-2026-05-24`
- `phase2-terminal-f-falsifiers-m2pro-2026-05-23`
- `phase2-terminal-g-t14-uas-no-orphan-2026-05-24`
- `phase2-terminal-t0-verified-floor-2026-05-24`

Current-code newer or manually represented; do not raw-merge:

- `terminal/a-eidos-bridge-2026-05-23`
- `terminal/c-system-g-full-path-2026-05-23`
- `phase2-terminal-d-substrate-health-wrv-2026-05-24`
- `phase2-terminal-f-prime-falsifiers-r2-2026-05-24`
- `phase2-terminal-s-hyperdynamic-loop-2026-05-24`
- `phase2-terminal-t1-runtime-router-2026-05-24`
- `phase2-terminal-b-prime-chat-citations-2026-05-24`
- `codex/recovery-b-prime-uncommitted-followup-2026-05-26`
- `codex/recovery-claude-shadow-handle-2026-05-26`
- `codex/wave4-page-gather-vault-escalation-2026-05-26`

Historical donor / deferred architecture refs:

- `codex/t1-trifusion-2026-05-16`
- `codex/t2-agent-2026-05-16`
- `codex/t3-uasacs-2026-05-16`
- `codex/t4-vault-2026-05-16`
- `codex/t5-emlir-2026-05-16`
- `codex/t6-uiux-2026-05-16`
- `codex/t7-eml-2026-05-16`
- `codex/t8-biometric-2026-05-16`
- `codex/t9-coord-2026-05-16`
- `claude/vigorous-goldberg-3a2d35`
- `salvage/T4-superseded-by-T21-2026-05-23`
- `salvage/agent-a0550f9c-inspection-2026-05-23`
- `salvage/auxiliary-branch-salvage-ledger-2026-05-23`
- `salvage/quick-capture-mining-status-2026-05-23`
- `salvage/simulation-donor-status-2026-05-23`
- `salvage/t5-lean-custody-status-2026-05-23`
- `salvage/t6-uiux-status-2026-05-23`
- `worktree-simulation`

These refs remain useful for targeted archaeology, but they are not safe merge
targets. Any future extraction must compare a named missing field against
current main and port only the narrow hunk with a guard.

## Current Architecture Truth

June 1 canon is present on main and remains the current architecture authority:

- `JUNE1-CANON-FUSION-LOCK`
- `JUNE1-PATTERNBOOST-LOCK`
- Residency PatternBoost
- Semantic Working Set Compiler
- ColdStream residency transport
- mmap/hot-path cure atlas
- AcsAnchor / SCOPE-Rex / SovereignGate naming discipline

The merge did not make those impossible to recover. The bad regressions came
from stale UI/editor/theme/worktree state being allowed to coexist with current
main, not from the June 1 canon itself being unrecoverable.

## Next Architecture Target

Use `docs/audits/UNFINISHED_ARCHITECTURE_AND_BEST_COMBO_MANIFEST_2026_05_30.md`
and `docs/audits/TURBOAGENT_FULL_ARCHITECTURE_CONTINUATION_2026_06_02.md` as
the next-work gate.

Preferred next work, from current main:

1. T21 retrieval contract unification over Eidos, VaultRecall, and PageGather.
2. `F-SourceSignalGraph-Intake`, `F-TaskWorkingSetQuery-Determinism`, and
   `F-SemanticWorkingSetPlan-Budget` are now present as primary witnesses on
   main:
   `artifacts/falsifiers/source_signal_graph_intake/result.json`,
   `artifacts/falsifiers/task_working_set_query_determinism/result.json`, and
   `artifacts/falsifiers/semantic_working_set_plan_budget/result.json`.
3. Metadata-only falsifier fixture still needed next:
   `F-ResidencyPageTable-Addressability`.
4. T25 naming cleanup only as current-main source/doc guard work: ColdStore for
   dormant residency, AcsAnchor for coordinate/provenance anchoring, and
   SCOPE-Rex/SovereignGate for admission.

Do not resume by checking out a donor worktree. Resume from main.
