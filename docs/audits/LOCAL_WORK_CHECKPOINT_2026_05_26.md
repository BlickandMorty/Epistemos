# Local Work Checkpoint - 2026-05-26

> **2026-06-01 current canon bridge (JUNE1-PATTERNBOOST-LOCK):** This file is preserved as a legacy, planning, research, or witness artifact. For active architecture, route Helios/UAS/ACS/mmap/KV-Direct/70B/NeuralImportance claims through `docs/fusion/RESIDENCY_PATTERNBOOST_DISCOVERY_2026_06_01.md`, `docs/falsifiers/F-RESIDENCY-PATTERNBOOST-BUNDLE_2026_06_01.md`, `docs/fusion/SEMANTIC_WORKING_SET_COMPILER_2026_06_01.md`, and `docs/fusion/COLDSTREAM_RESIDENCY_TRANSPORT_2026_06_01.md`. Legacy claims remain historical until promoted by falsifiers, AnswerPacket evidence, LatticeAbstentionGate, ComputeResumeLease, rollback, and the intentional-copy/zero-copy caveat.

Purpose: make the current repo state recoverable and explicit after the Wave 2 merge
and local-WIP preservation pass. This document is a control surface for future
agents: do not treat stashes or old worktrees as forgotten work.

## Current Main

- Main commit: `c6891ae72e docs: repromote preserved terminal leftovers (#80)`
- Remote: `origin/main` matches local `main`.
- Checkpoint tag: `checkpoint/local-work-repromotion-2026-05-26`
- Previous Wave 2 checkpoint tag: `checkpoint/wave2-main-closed-2026-05-26`
- Open merge-ready PRs at checkpoint time: none.

## Validation

- PASS: `cargo test --manifest-path agent_core/Cargo.toml --lib --quiet`
  - Result: `4036 passed; 0 failed`
- PASS: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=""`
  - Result: `BUILD SUCCEEDED`
- PASS: same Xcode build into the app path used by local app launches:
  - DerivedData path: `/Users/jojo/Downloads/Epistemos/.derived-data-codeeditor-native`
  - Result: `BUILD SUCCEEDED`
- Running app at checkpoint:
  - `/Users/jojo/Downloads/Epistemos/.derived-data-codeeditor-native/Build/Products/Debug/Epistemos.app`
  - Process path verified with `pgrep -fl Epistemos`.

## What Was Preserved

All 20 current stash entries were given fresh remote recovery tags:

- Tag prefix: `recovery/stash-2026-05-26-*`
- Count: 20 tags pushed to `origin`

These tags preserve the stash commits even if local stash indices shift.
Do not rely on `stash@{N}` as a durable identifier; use the recovery tags.

Additional branch-level preservation:

| PR | Branch | Meaning | Merge posture |
|---|---|---|---|
| #81 | `codex/recovery-claude-shadow-handle-2026-05-26` | Preserves Claude `agent-a0550f9c` shadow-handle WIP. | Draft recovery only; audit/rebase before merge. |
| #82 | `codex/recovery-b-prime-uncommitted-followup-2026-05-26` | Preserves the B-prime uncommitted follow-up stash as a remote branch. | Draft recovery only; re-promote selected hunks onto fresh main before merge. |

Already merged from local leftovers:

| PR | Meaning |
|---|---|
| #80 | Repromoted small Terminal D/E leftovers from fresh `origin/main`, validated with cargo + Xcode, then merged. |

## Remaining Local Worktree Notes

These are intentionally not silent-cleaned:

- `Epistemos-terminal-d-r2` and `Epistemos-terminal-d-r3` still show two local
  edits, but their relevant deltas were promoted through PR #80.
- `Epistemos-terminal-e` still shows audit-doc edits, but the relevant deltas
  were promoted through PR #80.
- `Epistemos-wrv-docs` shows `docs/CANONICAL_CHRONICLE_2026_05_23.md` as
  untracked in that old worktree; `origin/main` already contains the document.
- `Epistemos-t2-agent` shows deletion-only churn in an old branch worktree.
  Its branch tracks `origin/codex/t2-agent-2026-05-16`; do not commit the
  deletions as work without a fresh audit.
- Build-output deletion noise under `substrate-core/target`, `syntax-core/target`,
  and reliability artifacts is ignored for product truth. It came from the disk
  cleanup, not feature work.

## Architecture State

Wave 2 floor work is closed on main:

- Verified Floor / Settings Truth
- Runtime Router, with MLX represented as one lane
- Hyperdynamic Schema Loop primitive
- Chat citation/provenance UI
- Substrate Health panel expansion
- Falsifier round 2

The live app is still honest about gaps. Visible "speculative/blocked" and
"trace unavailable" badges are expected when a historical row has no bound
AnswerPacket or stored recall trace.

## Next Architecture Moves

1. Recovery triage, not blind merge:
   - Audit PR #81 shadow-handle WIP against current main.
   - Re-promote PR #82 stash hunks selectively onto a fresh branch from current
     main, then run full cargo + Xcode gate.

2. Wave 3 - agent path closure:
   - AgentBlueprint end-to-end replay UI.
   - Per-model agent metadata badges: `HONEST`, `EXPERIMENTAL`, `OFF`.
   - Deterministic RunEventLog replay into visible AnswerPacket output.

3. Wave 4 - deeper UAS wiring:
   - `hybrid_search` returns typed `Vec<UasAddress>`.
   - `UasKind` appears on agent traces.
   - `AcsAnchor` lands in ClaimLedger.
   - `page_gather` escalates through vault retrieval.
   - Vault Context Contract CI gate remains enforced.

4. Deferred ceiling work remains codeword-gated:
   - `RESUME XPC MASTERY`
   - `RESUME L_SE RESEARCH`
   - `RESUME F-70B`
   - `RESUME LEAN PROOFS`
   - `RESUME PRO TOOLS`
   - `RESUME LIVE FILE COMPILER`
   - `RESUME LEAN AUTHORITY`
   - `RESUME ACS ANCHOR HARNESS`

## Rule For Future Agents

Never stash and walk away. If work is not merge-ready, make one of these durable
surfaces before stopping:

1. A pushed branch.
2. A pushed recovery tag.
3. A draft PR marked recovery-only.
4. A checkpoint ledger entry naming the exact branch/tag/PR and the next command.
