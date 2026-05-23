# Sanitization Loop Tracker — 2026-05-23

Live doc tracking the autonomous-loop sanitization sweep through ALL preserved work surfaces. User mandate:

> "recurvieyl on loop santitize the stashes wips and all previous work befroe we start the new terminals so bascially this should be all the work including any phase 2 wiring work that needs to be done but on loop i wnat you to truly get into all the previous brnaches and trees work"

## Surfaces to triage (master list)

### A. Stash content (13 stashes)
- [x] **stash@{0}** — 47 user-WIP files. Walking by group:
  - [x] Group A: Voice/Audio (7 files) → PR landing (audio-crash-hardening branch + probe fix)
  - [ ] Group B: Settings/Verified-floor rows (9 files)
  - [ ] Group C: App-level chrome (5 files)
  - [ ] Group D: State/data (2 files)
  - [ ] Group E: Notes/Models (3 files)
  - [ ] Group F: Rust agent_core (12 files)
  - [ ] Group G: Test additions (7 files)
  - [ ] Group H: Local settings (1 file) — noise, skip
- [x] **stash@{1,2}** — cherry-picked → PR #48 ✅ merged
- [x] **stash@{5}** — a2ui salvage → PR #52 ✅ merged
- [x] **stash@{3,4,6,7}** — discard-candidates (binaries / already-in-main / file restructured)
- [ ] **stash@{8}** — graph filters (404 LOC, user previously said don't touch physics)
- [ ] **stash@{9}** — 2026-04-27 W9.21 PR4 (1,511 LOC, 27 days old, likely stale)
- [ ] **stash@{10}** — codex-wip-parallel (664 LOC, LandingWave overlap)
- [ ] **stash@{11}** — `project.pbxproj` 3,172-line nightmare + 50+ Swift files (HIGH RISK)
- [ ] **stash@{12}** — XcodeCodeColors (patch no longer applies cleanly to main)

### B. T-track branches with novel commits (May 16 cycle)
| Branch | Commits ahead | Files changed | Status |
|--------|---------------|----------------|--------|
| codex/t8-biometric-2026-05-16 | 11 | 527 | pending |
| codex/t7-eml-2026-05-16 | 30 | 516 | pending |
| codex/t6-uiux-2026-05-16 | 38 | 521 | pending |
| codex/t2-agent-2026-05-16 | 38 | n/a | pending |
| codex/t9-coord-2026-05-16 | 39 | 521 | pending |
| codex/t3-uasacs-2026-05-16 | 64 | 554 | pending |
| codex/t1-trifusion-2026-05-16 | 69 | 522 | pending |
| codex/t4-vault-2026-05-16 | 144 | n/a | pending |
| **codex/t5-emlir-2026-05-16** | **961** | n/a | **HUGE — pending** |

### C. Auxiliary worktrees with novel commits
- [ ] `.claude/worktrees/simulation` — 17 commits ahead (`worktree-simulation` branch)
- [ ] `.claude/worktrees/vigorous-goldberg-3a2d35` — 55 commits ahead (`claude/vigorous-goldberg-3a2d35` branch)

### D. wrv-* + Epistemos-t* (May 18) worktrees — VERIFIED ALREADY MERGED
- All 0 ahead of main as of this session
- Safe to delete or leave for reference

## Loop methodology

For each item, the bot follows:

1. **Enumerate**: list every file the surface changes vs current main.
2. **Per-file vs-main triage**:
   - Show what stash/branch has that main doesn't.
   - Classify: TAKE (clear benefit, no regression), HYBRID (partial), SKIP (already-in-main or superseded), DISCARD (compiler artifacts only).
3. **Verify**: per-file `cargo check` / `xcodebuild` between batches.
4. **Bundle**: group related TAKEs into one salvage branch + PR.
5. **Update tracker**: this doc, per surface.

## Open PRs queue (autonomous-loop-produced)

| PR | Title | Status |
|----|-------|--------|
| pending | salvage(audio): crash hardening from stash@{0} Group A + probe type fix | building |

(more rows appended as the loop progresses)

## Stop conditions
1. User explicitly says STOP.
2. All surfaces in the master list above are triaged (in flight or closed).
3. A surface fails verification 3 consecutive attempts — pause and ask user.
