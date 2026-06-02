# Stash Salvage Decision Table — 2026-05-23

> **2026-06-01 current canon bridge (JUNE1-PATTERNBOOST-LOCK):** This file is preserved as a legacy, planning, research, or witness artifact. For active architecture, route Helios/UAS/ACS/mmap/KV-Direct/70B/NeuralImportance claims through `docs/fusion/RESIDENCY_PATTERNBOOST_DISCOVERY_2026_06_01.md`, `docs/falsifiers/F-RESIDENCY-PATTERNBOOST-BUNDLE_2026_06_01.md`, `docs/fusion/SEMANTIC_WORKING_SET_COMPILER_2026_06_01.md`, and `docs/fusion/COLDSTREAM_RESIDENCY_TRANSPORT_2026_06_01.md`. Legacy claims remain historical until promoted by falsifiers, AnswerPacket evidence, LatticeAbstentionGate, ComputeResumeLease, rollback, and the intentional-copy/zero-copy caveat.

This doc enumerates every entry in `git stash list` as of 2026-05-23 and
records the disposition: **cherry-picked**, **preserved as recovery tag**,
or **discarded**. The user said in this session:

> "i was waiting the wips and stashes as well but of course cherry picking
> because i think some are overlapping with canon but theres a reason i
> built just need to know why same for all other non T terminal work."

So *every* stash is preserved as a recovery tag in addition to whatever
action is taken. **No stash content is destroyed.** Tags are at
`refs/tags/recovery/stash-N-<slug>` and pushed to origin.

## Summary

| Stash | Source branch | Title | Files (non-target) | Disposition |
|-------|--------------|-------|--------------------|-------------|
| `stash@{0}` | `master` | `auto-stash for ff pull 160254` | **47 source files** (Swift + Rust), 729+/326- | **PRESERVE-ONLY** — too big to autoland; user WIP from before today's wave PRs; many files overlap with merged canon. Needs user-eyes triage. |
| `stash@{1}` | `codex/t12-f-ulp-oracle-2026-05-18` | `WIP a279fe2a38 test(t12)` | 1 file (`witness.rs`), +23 LOC | **CHERRY-PICKED** → PR #48 |
| `stash@{2}` | `codex/t11-agent-runtime-v2-2026-05-18` | `PRE-CURSOR-HANDOFF-1779175040` | 1 file (`capability.rs`), +62 LOC | **CHERRY-PICKED** → PR #48 |
| `stash@{3}` | `codex/t2-agent-2026-05-16` | `PRE-REMOVAL-STASH-t2-agent` | 0 source files (only `.rcgu.o` binaries) | **DISCARD-CANDIDATE** (tag preserved) — compiler artifacts only |
| `stash@{4}` | `codex/t1-trifusion-2026-05-16` | `PRE-REMOVAL-STASH-t1-trifusion` | 0 source files (only `.rcgu.o` binaries) | **DISCARD-CANDIDATE** (tag preserved) — compiler artifacts only |
| `stash@{5}` | `run-b-post-v1-research` | `PRE-REMOVAL-STASH-runB` | 2 files (`a2ui/accordion.rs` +130, `a2ui/carousel.rs` +60) | **PRESERVE-ONLY** — substantive Pro Research additions; needs check against merged a2ui canon before reapply |
| `stash@{6}` | `master` | `wip-multi-terminal-recovery: lib.rs + acs_admission/ + docs/falsifiers/` | 1 file (`lib.rs` +1 line `pub mod acs_admission;`) | **DISCARD-CANDIDATE** (tag preserved) — already present in main at line 2 |
| `stash@{7}` | `master` | `codex-preserve-t17b-lattice-format-before-t12` | 1 file (`lattice_wbo/mod.rs`, formatting tweak only) | **DISCARD-CANDIDATE** (tag preserved) — original file was decomposed into 7 submodules in T17B; target test now lives at `lattice_wbo/tests/serde_roundtrip.rs:794`; formatting tweak no longer applies |
| `stash@{8}` | `master` | `wip-codex-graph-filters-selected-expansion` | 7 files (Swift + graph-engine), 404+/18- | **PRESERVE-ONLY** — substantive graph filter UX work; user said "i didnt need u messing with the physcsi spring stuff" earlier, so safest to leave behind tag until user decides |
| `stash@{9}` | `master` | `session-stash-2026-04-27: W9.21 PR4 (X salvaged) + W9.8 wire-up partial` | 8 source files (incl. `CRITIQUE_LOG.md` +618 LOC, `honest_handle.rs` +632 LOC) | **PRESERVE-ONLY** — 27 days old (from W9 sprint cycle); honest-handle work likely superseded by the doctrine that landed since; needs explicit user sign-off |
| `stash@{10}` | `master` | `codex-wip-parallel-during-landing-wave-session` | 15 source files (LandingWave family + Notes + Graph node inspector), 664+/145- | **PRESERVE-ONLY** — LandingWave family files overlap with `feature/landing-liquid-wave` work; risk of regressing already-shipped landing UX |
| `stash@{11}` | `main` `31214a4d` | `Update progress and mark three runtime issues as patched` | 50+ Swift source files + `project.pbxproj` (3172-line change) + 920 build artifacts | **PRESERVE-ONLY — HIGH RISK** — project.pbxproj reorganisation can break Xcode build; do not autoland; needs explicit user review of pbxproj diff first |
| `stash@{12}` | `main` `29c0ca83` | `Fix: Invisible text in code editor — isRichText must be true` | 2 files (`EpistemosTheme.swift` +90 LOC XcodeCodeColors plist extraction, `CodeEditorView.swift` refactor) | **PRESERVE-ONLY** — substantive Xcode-default-theme color extraction; current main has `isRichText = false` at lines 2990 + 3357 (stash would revert that intentionally as part of a larger plain-text simplification refactor); user should decide direction before applying |

## Recovery tags (all 13)

All stashes preserved as annotated tags pushed to origin:

```
recovery/stash-0-On_master__auto-stash_for_ff_pull_160254_
recovery/stash-1-WIP_on_codex_t12-f-ulp-oracle-2026-05-18__a279fe2a38_test_t1
recovery/stash-2-On_codex_t11-agent-runtime-v2-2026-05-18__PRE-CURSOR-HANDOFF
recovery/stash-3-On_codex_t2-agent-2026-05-16__PRE-REMOVAL-STASH-t2-agent-202
recovery/stash-4-On_codex_t1-trifusion-2026-05-16__PRE-REMOVAL-STASH-t1-trifu
recovery/stash-5-On_run-b-post-v1-research__PRE-REMOVAL-STASH-runB-20260518-2
recovery/stash-6-On_master__wip-multi-terminal-recovery-2026-05-18__lib_rs___
recovery/stash-7-On_master__codex-preserve-t17b-lattice-format-before-t12_
recovery/stash-8-On_master__wip-codex-graph-filters-selected-expansion_
recovery/stash-9-On_master__session-stash-2026-04-27__W9_21_PR4__X_salvaged__
recovery/stash-10-On_master__codex-wip-parallel-during-landing-wave-session_
recovery/stash-11-WIP_on_main__31214a4d_Update_progress_and_mark_three_runtime
recovery/stash-12-WIP_on_main__29c0ca83_Fix__Invisible_text_in_code_editor____
```

To restore any tag's contents into a working tree:

```sh
git checkout -b recover/<name> recovery/stash-N-<slug>
```

To drop a stash from `git stash list` once you've confirmed its recovery
tag is sufficient:

```sh
git stash drop stash@{N}
```

(The recovery tag survives stash drops.)

## What's actually landed as a result of this triage

| PR | Title | State |
|----|-------|-------|
| [#48](https://github.com/BlickandMorty/Epistemos/pull/48) | `test(stash-recovery): 2 additive Rust tests from preserved stashes` | OPEN — 2 cherry-picks (stash 1 + 2) |

## Open questions for the user

1. **stash@{0}** is 47-file user-WIP from before today's wave PRs. The audio crash work, voice features, Settings shape, provider updates may or may not still be wanted. Want me to do a per-file diff against current main and surface only the still-novel pieces?
2. **stash@{9}** (2026-04-27) and **stash@{11}** (project.pbxproj) are 27+ days old. Probably stale, but the user said "there's a reason I built." Want a per-file value triage on these too?
3. **stash@{12}** (XcodeCodeColors extraction) is a substantive piece of code-editor-theming work that's orthogonal to the no-compromise architecture push. Worth landing? Or defer until verified floor is closed?

Until the user signals which of those to pick up, the safe posture is:
**recovery tags preserved, working tree clean, PR #48 carries the only
two autoland-safe additive pieces.**
