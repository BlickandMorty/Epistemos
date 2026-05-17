# T9 Initial Inventory - 2026-05-17

**Terminal:** T9 coordination / drift-catch  
**Worktree:** `/Users/jojo/Downloads/Epistemos-t9-coord`  
**Branch:** `codex/t9-coord-2026-05-16`  
**Inventory time:** 2026-05-17 06:49:56 CDT  
**Seed commit:** `86f0ec84f docs(codex-9-terminals): paste-ready prompts for 9 parallel sub-mission terminals`

## Scope Lock

T9 remains docs-only. No `.swift`, `.rs`, `.metal`, `.h`, or `.c` file was edited in this iteration.

Allowed write set for this iteration:
- `docs/coordination/T9_initial_inventory_2026_05_17.md`
- `docs/APP_ISSUES_AUTO_FIX.md`

## Read-In Completed

Read / spot-checked the required T9 doctrine and ledgers:
- `docs/CODEX_9_TERMINAL_PROMPTS_2026_05_16.md`, including every terminal map and the T9 scope lock.
- `docs/CODEX_DEEP_INVESTIGATION_PROMPT_2026_05_16.md`, including section 0 immutable rules, section 2 phase loop, Phase C audit-of-audit pattern, section 6 anti-rules, and section 9 escalation.
- `docs/MASTER_FUSION_NO_COMPROMISE_2026_05_13.md` start + section 3 atlas framing.
- `docs/APP_ISSUES_AUTO_FIX.md`.
- `docs/CANONICAL_AUDIT_LOG.md`.
- `docs/CRITIQUE_LOG.md`.
- `docs/RESEARCH_COVERAGE_GAP_AUDIT_PASS2_2026_05_15.md` section 9 pattern and recent Lesson #17 carry-forward.

Carry-forward discipline from PASS-2 section 9: verify actual diffs and file state, not only commit messages.

## Main Baseline

Main worktree: `/Users/jojo/Downloads/Epistemos`

- Branch: `main...origin/main`
- HEAD: `86f0ec84f`
- Dirty state: clean in `git status --short --branch`
- `cargo test --manifest-path agent_core/Cargo.toml --lib`: **PASS**, `1671 passed; 0 failed; 0 ignored`
- xcodebuild command:
  `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO`
- xcodebuild result: **BUILD SUCCEEDED**
- Non-blocking warnings observed:
  - Cargo test warning: unused test helper functions in `resonance/mod.rs` and `scope_rex/retrieval/hopfield.rs`.
  - xcodebuild Rust bridge warning: unused `SCHEMA_V1`, unused `MCP_CONNECTOR_BETA_HEADER`, unused `gemini_request_body`.

No main blocker. No push freeze required.

## T1-T8 Worktree Inventory

All eight new terminal worktrees exist and are currently at the seed commit with no dirty files shown by `git status --short --branch`.

| Term | Worktree | Branch | HEAD | State |
|---|---|---|---|---|
| T1 | `/Users/jojo/Downloads/Epistemos-t1-trifusion` | `codex/t1-trifusion-2026-05-16` | `86f0ec84f` | Clean, no terminal-specific commits yet |
| T2 | `/Users/jojo/Downloads/Epistemos-t2-agent` | `codex/t2-agent-2026-05-16` | `86f0ec84f` | Clean, no terminal-specific commits yet |
| T3 | `/Users/jojo/Downloads/Epistemos-t3-uasacs` | `codex/t3-uasacs-2026-05-16` | `86f0ec84f` | Clean, no terminal-specific commits yet |
| T4 | `/Users/jojo/Downloads/Epistemos-t4-vault` | `codex/t4-vault-2026-05-16` | `86f0ec84f` | Clean, no terminal-specific commits yet |
| T5 | `/Users/jojo/Downloads/Epistemos-t5-emlir` | `codex/t5-emlir-2026-05-16` | `86f0ec84f` | Clean, no terminal-specific commits yet |
| T6 | `/Users/jojo/Downloads/Epistemos-t6-uiux` | `codex/t6-uiux-2026-05-16` | `86f0ec84f` | Clean, no terminal-specific commits yet |
| T7 | `/Users/jojo/Downloads/Epistemos-t7-eml` | `codex/t7-eml-2026-05-16` | `86f0ec84f` | Clean, no terminal-specific commits yet |
| T8 | `/Users/jojo/Downloads/Epistemos-t8-biometric` | `codex/t8-biometric-2026-05-16` | `86f0ec84f` | Clean, gated on T1 + T2 + T6 |

Branch tracking note: `git branch -vv` shows the T1-T9 `codex/t*` branches as local branches without upstream tracking at inventory time. T9 will set upstream on first push.

## Existing Product Worktrees Also Present

The repository still has older active/handoff worktrees outside the new T1-T9 set:

| Worktree | Branch | HEAD | Dirty state |
|---|---|---|---|
| `/Users/jojo/Downloads/Epistemos-laneA` | `lane-A` | `12183f29a` | Clean |
| `/Users/jojo/Downloads/Epistemos-runB` | `run-b-post-v1-research` | `28385bdea` | **Dirty:** `agent_core/src/research/a2ui/accordion.rs`, `agent_core/src/research/a2ui/carousel.rs` |
| `/Users/jojo/Downloads/Epistemos-runC` | `run-c-audit` | `8085deafd` | Clean |
| `/Users/jojo/Downloads/Epistemos-runD` | `run-d-providers` | `9c83757d8` | Clean |
| `/Users/jojo/Downloads/Epistemos-runE` | `run-e-decisions` | `6bbb475c4` | Clean |
| `/Users/jojo/Downloads/Epistemos-runF` | `run-f-integrations` | `4726720fd` | Clean |

T9 action: do not touch `runB`'s dirty code files. If a merge/audit touches `run-b-post-v1-research`, verify those two file diffs explicitly before any scope or merge verdict.

Additional `.claude/worktrees/*` exist under `/Users/jojo/Downloads/Epistemos/.claude/worktrees/`; they were listed by `git worktree list --porcelain` but were not in the T1-T8 per-iter scope pattern.

## Cross-PR Review

`gh pr list --state open --json number,title,headRefName,baseRefName,isDraft,author,updatedAt,url --limit 50` returned `[]`.

No open PRs and no draft PRs are currently visible, so no scope-lock diff review was possible in iteration 1.

## Ledger Sync Findings

### APP_ISSUES

`ISSUE-2026-05-16-015` was still marked `Status: Open`, but main includes `15cc2ced4 feat(model-gating): power-user mode override + runtime gate probe (section 4.E Phase B.5 + Phase A.2 quick-wins)`.

Verified via `git show --stat --name-status 15cc2ced4`:
- `Epistemos/App/AppBootstrap.swift`
- `Epistemos/Engine/LocalModelInfrastructure.swift`

Truthful status is **Investigating**, not Patched:
- Partial quick-wins landed: power-user threshold override and runtime gate probe.
- Remaining work still open: full gating matrix, Settings toggle, per-model badges, cloud/local agent capability honesty, strict grammar resolution, and real substrate-bound ternary / lattice / KV-Direct work.

T9 updates `docs/APP_ISSUES_AUTO_FIX.md` in this iteration to bump `Open` -> `Investigating` and append the verification note.

### MASTER_FUSION

No T1-T8 slice has landed yet, no draft PRs are open, and main remains at the seed commit. No `MASTER_FUSION` row state change is warranted in iteration 1.

## Watch List For Iteration 2

1. Re-run T1-T8 status/log sweep and catch the first terminal-specific commit.
2. Watch T2 closely for `ISSUE-2026-05-16-015`: no `Patched` status until UI toggle / capability badges / grammar status / routing honesty are actually wired and verified.
3. Watch T4 for vault retrieval work; reject any "first N notes" drift.
4. Keep T8 gated until T1 + T2 + T6 have shipped their prerequisites.
5. Watch `runB` dirty A2UI files if any old branch merge path resumes.
6. Keep Lesson #17 active: every audit-of-audit verifies commit diff content with `git show --stat` and path-specific diff, not just the commit title.

## Iteration 1 Verdict

- Main: green.
- T1-T8: initialized, clean, dormant.
- Open PRs: none.
- Scope violations: none observed in T1-T8.
- Coordination drift caught: `APP_ISSUES` stale status for ISSUE-2026-05-16-015.
