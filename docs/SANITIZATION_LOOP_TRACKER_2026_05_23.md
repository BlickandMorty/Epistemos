# Sanitization Loop Tracker — 2026-05-23

Live doc tracking the autonomous-loop sanitization sweep through ALL preserved work surfaces. User mandate:

> "recurvieyl on loop santitize the stashes wips and all previous work befroe we start the new terminals so bascially this should be all the work including any phase 2 wiring work that needs to be done but on loop i wnat you to truly get into all the previous brnaches and trees work"

## STATUS — LOOP CONVERGED ON SAFE-ADDITIVE SCOPE

11 PRs landed today via this loop (in addition to the original PR wave). Every preserved surface has been classified into one of four buckets:
- **DONE**: Beneficial work extracted onto a salvage branch and merged.
- **SUPERSEDED**: Already present in main via another route.
- **DISCARD-CANDIDATE**: Compiler artifacts / file restructured / already in main.
- **DEFERRED-PER-DOCTRINE**: Conflicts with active doctrine (Hermes purge, MAS-First Pro deferral).

## Surfaces triaged

### A. Stash content (13 stashes) — ALL TRIAGED

| Stash | Status | Outcome |
|-------|--------|---------|
| stash@{0} | **DONE** | 3 PRs: #56 (audio), #57 (chip strip), #58 (openai alias + Rust hardening) |
| stash@{1} | **DONE** | PR #48 (T12 witness precedence test) |
| stash@{2} | **DONE** | PR #48 (T11 macaroon caveat-order test) |
| stash@{3} | **DISCARD-CANDIDATE** | Compiler artifacts only; tag preserved |
| stash@{4} | **DISCARD-CANDIDATE** | Compiler artifacts only; tag preserved |
| stash@{5} | **DONE** | PR #52 (a2ui error introspection) |
| stash@{6} | **DISCARD-CANDIDATE** | `pub mod acs_admission` already in main |
| stash@{7} | **DISCARD-CANDIDATE** | Target file restructured into submodules |
| stash@{8} | **DONE (partial)** | PR #60 surgical (hideAll preset + button); physics preserved in tag |
| stash@{9} | **SUPERSEDED** | W9.21 honest-handle + ChatApprovalQueue all in main |
| stash@{10} | **SUPERSEDED** | Async refactor + tests already in main via other commits |
| stash@{11} | **SUPERSEDED** | FFI + gitignore + bridging header all in main; pbxproj noise |
| stash@{12} | **SUPERSEDED** | XcodeCodeColors + isRichText=false already in main |

### B. T-track branches with novel commits (May-16) — TRIAGED

| Branch | Docs landed | Source code |
|--------|-------------|--------------|
| codex/t1-trifusion | 3 docs → PR #61 | RustTriFusionDocumentClient + tests preserved in branch |
| codex/t2-agent | 5 docs → PR #61 | (no novel source) |
| codex/t3-uasacs | 26 docs → PR #61 | 12 agent_core/tests preserved in branch |
| codex/t4-vault | 3 docs → PR #61 | 3 F_VaultRecall_50_* + agent_core/src/retrieval preserved |
| codex/t5-emlir | 0 missing docs | Source/IR all merged via wrv-rust + other PRs |
| codex/t6-uiux | 17 docs → PR #61 | UIUX_AmbientFrequenciesPersistenceTests preserved |
| codex/t7-eml | 0 missing | All in main |
| codex/t8-biometric | 0 missing | BIOMETRIC_LOCK_DOCTRINE already in main |
| codex/t9-coord | 3 docs → PR #61 | (no novel source) |

### C. Auxiliary worktrees — TRIAGED

- `.claude/worktrees/simulation` (17 commits): **DEFERRED-PER-DOCTRINE** — adds `Epistemos/Hermes/*` files that contradict the 2026-05-05 Hermes namespace purge. CompanionAssets/ (palettes, atlas, effects) are still available in the worktree for explicit-opt-in if you want art assets without the Hermes Swift files.
- `.claude/worktrees/vigorous-goldberg-3a2d35` (55 commits): **DEFERRED-PER-DOCTRINE** — adds Pro-only tools (`action_bash`, `browser_*`, `apple_*`, `system_*`) that MAS-First doctrine explicitly defers. Quick Capture salvage triage memory already classified these as Tier C/D.
- `.claude/worktrees/agent-a0550f9c`: **DONE** — investigation doc landed in PR #46.

### D. wrv-* + Epistemos-t* (May-18) worktrees — VERIFIED ALREADY MERGED

All 0 ahead of main as of this session. Safe to delete or leave for reference.

## PRs produced by this autonomous loop (in order)

| # | Title | Files |
|---|-------|-------|
| 45 | security(omega-mcp/pty): P0 PTY env hardening | 1 |
| 46 | docs(salvage): 7 salvage-track status reports | 7 |
| 47 | docs(chronicle): 2 canonical chronicles | 2 |
| 48 | test(stash-recovery): 2 additive Rust tests | 2 |
| 49 | docs(stash): salvage decision table | 1 |
| 50 | docs(session): what's-left report | 1 |
| 51 | fix(agent_core): test-target compile errors | 5 |
| 52 | feat(a2ui): error introspection helpers | 2 |
| 53 | docs(audits): model gating matrix | 1 |
| 54 | chore(issue-015): investigation log update | 1 |
| 55 | feat(probe): runtime gating probe | 1 |
| 56 | salvage(audio): crash hardening + probe fix | 8 |
| 57 | salvage(verified-floor): chip-strip pattern | 9 |
| 58 | salvage(openai-alias+coord): GPT-5.4→GPT-4o + Rust hardening | 24 |
| 59 | salvage(graph): Filters panel (REVERTED — file-replacement hazard) | — |
| 60 | salvage(graph): hideAll preset + button (surgical re-do of #59) | 3 |
| 61 | salvage(docs): May-16 T-track docs+audits+falsifiers | 57 |

**Total: 16 successful PRs landing 125 files of beneficial work (+ #59 reverted lesson learned).**

## Key lessons learned

1. **NEVER use `git checkout <stash> -- file` to take stash content.** It overwrites main's current version with the stash's OLDER version, deleting any newer changes. PR #59 demonstrated this hazard; PR #60 fixed via surgical Edit.
2. **The autonomous loop converges fast once doctrine is honored.** Stashes 9-12 were all superseded by main; the May-18 wave merged most T-track source work; only docs needed explicit salvage.
3. **Hermes purge + MAS-First doctrine** correctly identify simulation + vigorous-goldberg as defer-don't-land. These are not stale, they're orthogonal to the active product surface.

## Stop conditions reached

All surfaces in the master list have been triaged. Loop is COMPLETE for safe-additive scope. The following items are open for user-judgment-call landing:
- T1 RustTriFusionDocumentClient (Swift bridge + Rust client + tests)
- T3 12 agent_core test files (substrate falsifier tests)
- T4 vault recall test + retrieval source
- T6 UIUX persistence test
- Stash@{8} selected-neighbor expansion physics
- Simulation Mode CompanionAssets (palettes/atlas/effects) without Hermes Swift files
