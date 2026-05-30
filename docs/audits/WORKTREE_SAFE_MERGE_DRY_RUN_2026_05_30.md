---
state: dry_run_merge_audit
created_on: 2026-05-30
checkpoint_commit: 5849ea0305
checkpoint_tag: checkpoint/pre-worktree-salvage-2026-05-30
posture: no wholesale merge; port one surface at a time
---

# Worktree Safe Merge Dry Run - 2026-05-30

## Checkpoint

Before this audit, the current dirty worktree was preserved as:

```text
5849ea0305 checkpoint: preserve architecture work before salvage
checkpoint/pre-worktree-salvage-2026-05-30
```

This is the recovery point for any later salvage mistake.

## Rule

Do not wholesale-merge old worktree branches into current Epistemos. The current
tree has moved far enough that even clean branches can reintroduce stale project
settings, old UI surfaces, or pre-checkpoint runtime assumptions.

Safe salvage shape:

```text
branch comparison
  -> file-level conflict scan
  -> read donor file
  -> port one narrow surface
  -> run lightweight relevant guard
  -> commit
```

## Clean Branch Dry-Run Results

The following checks used Git merge-tree/diff analysis only. No branch was
merged and no cherry-pick was run.

| Branch | Status | Safe action |
|---|---|---|
| `wiring/app-systemg-run-seam-2026-05-23` | already ancestor of checkpoint; diff none | no merge needed; removal candidate after approval |
| `wiring/rust-r3-system-g-minimal-slice` | already ancestor of checkpoint; diff none | no merge needed; removal candidate after approval |
| `salvage/t6-uiux-status-2026-05-23` | docs-only status already present | no code mining; keep T6 deferred |
| `phase2-terminal-t1-runtime-router-2026-05-24` | conflicts: changed/added in both, including Xcode project and settings surface | port RuntimeExecutor/RuntimeRouter concepts manually; do not merge branch |
| `phase2-terminal-f-prime-falsifiers-r2-2026-05-24` | conflicts: changed/added in both around falsifier binaries, artifacts, docs | compare against current falsifier set; port missing harnesses only |
| `codex/wave4-page-gather-vault-escalation-2026-05-26` | conflicts across VaultRecall/SearchIndex/chat/settings/Rust storage | port only trace fields or caller-policy deltas that current PageGather lacks |
| `phase2-terminal-d-prime-health-rows-2026-05-24` | conflicts across health rows and bridge | port only missing health-row truth-floor fields |
| `codex/wave4-uas-typed-retrieval-2026-05-26` | conflicts across AnswerPacket, bridge, provenance, storage, UAS | port only missing typed-address fields after current UAS docs/tests agree |
| `codex/repromote-ui-wip-2026-05-26` | broad conflicts across app bootstrap, Epdoc, landing, settings, tests, HTML workspace | do not merge; mine only isolated UI fixes with manual review |

## Current Cleanup Classification

Allowed after explicit user approval:

```text
/Users/jojo/Downloads/Epistemos-wrv-app
/Users/jojo/Downloads/Epistemos-wrv-rust
```

Not automatically removable:

```text
/Users/jojo/Downloads/Epistemos-wrv-audit
```

It is clean and graph-merged, but detached worktrees are easier to misread.
Inspect its exact purpose before removal.

Preserve-first:

```text
T5 EML/IR
T17b lattice/WBO
T18b ACS admission
Terminal S hyperdynamic loop
Terminal C System G
Terminal T1 runtime router
T2 local agent
T4 VaultRecall
Wave4 PageGather vault escalation
```

## Next Safe Port Target

The best next code-facing target is **not** a branch merge. It is a small
manual comparison of Terminal T1:

```text
RuntimeExecutor.swift
RuntimeRouter.swift
RuntimeRouterHealthRow.swift
FLocalToolUseTests.swift
RuntimeRouterTests.swift
```

Reason: local agents and model mixtures are core to the app, but this branch
touches Xcode project files and settings surfaces, so the branch itself is too
stale to merge wholesale.

Exit condition for a T1 port:

```text
no Xcode project rollback
no legacy settings overwrite
provider policy remains fail-closed until live MLX/GGUF is bound
AnswerPacket provenance remains required
lightweight Swift/Rust checks only unless user allows app build
```
