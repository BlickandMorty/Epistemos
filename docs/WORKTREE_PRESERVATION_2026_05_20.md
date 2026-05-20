# Worktree Preservation Snapshot — 2026-05-20

All in-flight Cohort A T-track work, the simulation worktree, and the
Quick Capture (vigorous-goldberg) branch are preserved as of this date.
Every branch is now pushed to `origin` AND tagged with a permanent
preservation tag so even if the branch is later deleted, deleted via
prune, or the local clone is lost, the work is recoverable from GitHub.

## How recovery works
- **Branch on origin**: clone the repo and `git checkout <branch>` —
  immediate working tree.
- **Preservation tag**: every snapshot is also addressable by SHA via
  `git checkout preserve/<label>-2026-05-20-snapshot`. Tags do not
  expire and are not pruned. Even if Codex's session gc deletes the
  branch ref, the tag still points at the commit.

## Snapshot map

| Track | Branch | HEAD SHA | Preservation tag |
|---|---|---|---|
| T2 agent | `codex/t2-agent-2026-05-16` | `b187813cf6` | `preserve/T2-agent-2026-05-20-snapshot` |
| T4 vault | `codex/t4-vault-2026-05-16` | `8cff8701fc` | `preserve/T4-vault-2026-05-20-snapshot` |
| T5 EML-IR | `codex/t5-emlir-2026-05-16` | `2ba7142e28` | `preserve/T5-emlir-2026-05-20-snapshot` |
| T6 UI/UX | `codex/t6-uiux-2026-05-16` | `775137b831` | `preserve/T6-uiux-2026-05-20-snapshot` |
| T09 product ledger | `codex/t09-product-ledger-2026-05-18` | `4e2930cd4a` | `preserve/T09-product-ledger-2026-05-20-snapshot` |
| T10 eidos v0 | `codex/t10-eidos-v0-2026-05-18` | `4df955180a` | `preserve/T10-eidos-2026-05-20-snapshot` |
| T11 agent runtime v2 | `codex/t11-agent-runtime-v2-2026-05-18` | `16e4264383` | `preserve/T11-agent-runtime-v2-2026-05-20-snapshot` |
| T12 f-ULP oracle | `codex/t12-f-ulp-oracle-2026-05-18` | `5f6c69ff1a` | `preserve/T12-f-ulp-oracle-2026-05-20-snapshot` |
| T17b lattice/WBO | `codex/t17b-lattice-wbo-register-2026-05-18` | `a3762d9333` | `preserve/T17b-lattice-wbo-2026-05-20-snapshot` |
| T18b ACS admission | `codex/t18b-acs-admission-field-2026-05-18` | `af78e4bfb5` | `preserve/T18b-acs-admission-2026-05-20-snapshot` |
| T21 vault recall | `codex/t21-vault-recall-contract-2026-05-18` | `60b035b837` | `preserve/T21-vault-recall-2026-05-20-snapshot` |
| T23b M2 falsifier | `codex/t23b-m2pro-falsifier-handbook-2026-05-18` | `c6d45e8ed6` | `preserve/T23b-m2pro-falsifier-2026-05-20-snapshot` |
| Simulation | `worktree-simulation` | `3163b170d0` | `preserve/simulation-2026-05-20-snapshot` |
| Quick Capture | `claude/vigorous-goldberg-3a2d35` | `0e0234d9f1` | `preserve/quick-capture-2026-05-20-snapshot` |

## What's safe / not at risk

These three "dirty" worktrees that the audit flagged are NOT lost work:

- **T2 agent (26,122 dirty files)**: all `D` (working-tree deletions).
  The work IS committed on the branch HEAD `b187813cf6`. The dirty
  state is just "working tree missing files that exist on branch HEAD"
  — likely from a stale `git checkout` after main's Hermes purge.
  Resume work by running `git -C /Users/jojo/Downloads/Epistemos-t2-agent
  reset --hard HEAD` to restore the working tree to match the branch.
- **T6 UI/UX (95 dirty files)**: all `syntax-core/target/.../*.rcgu.o`
  — Cargo build artifacts. Not user work. Should be in `.gitignore`.
  Run `git restore syntax-core/target/` to clean.
- **T4 vault (1 dirty file)**: `libsyntax_core.d`, same as T6 — build
  artifact. Same fix.

## What was pushed today

Eleven branches were pushed to origin for the first time:
- T5 (27 new commits since last push)
- T09, T10, T11, T12, T17b, T18b, T21, T23b (all 8 2026-05-18-series tracks were local-only)
- `worktree-simulation` (S0-S11 commits, 17 ahead of main)
- `claude/vigorous-goldberg-3a2d35` (Quick Capture, 55 commits ahead, full 12-phase plan)

T2, T4, T6 were already in-sync with origin (verified pre-tag).

## What's NOT yet on main (worth digging through later)

- **Simulation worktree**: 17 commits with CompanionRegistry, Theater
  Metal, Hermes graph faculty, S11 Mailroom adapter. None on main yet.
  3 weeks stale but review-ready.
- **Quick Capture**: 55 commits. Recent salvage commits on main
  (`53b2ee3b`, `2bd11bc7`) brought in tools_v2 + variant runner +
  circuit breaker, but **Phases 7, 8, 8-cont, 11, 12.5 + Wave 6
  BrowserEngine + D1 ExecutionReceipt + skill discovery are NOT on
  main**. Worth a fresh salvage triage pass.

## Phase status (per audit a000b094a26822e46)

- **Ready for phase 2**: T4 only
- **Phase 1 hardening, still active (let cook)**: T10, T11, T12, T17b, T18b, T21, T23b, T5
- **Decide if converging**: T09 (docs-only loop, 720 commits)
- **Stale, needs intervention**: T2 (working-tree mismatch), T6 (build artifacts), simulation (3wk), Quick Capture (3wk)
