# Terminal Final Tasks + Hard-Stop Directive — 2026-05-16

**Why this doc exists.** The 7 autonomous loops have been running for many hours. The user has decided it's time to close them. This doc:

1. Assigns each active terminal a **focused final task** (proofs, tests, validations, handoff docs based on everything that's been hardened).
2. Tells each terminal to **omit ScheduleWakeup** after the final task — graceful wind-down per §17 of every prompt.

**Each terminal reads ONLY its own section below.** Do not bleed into sibling scope (per §1.5 SCOPE BOUNDARY).

---

## Terminal A (lane-A — V1 ship driver) — STOP

**Status:** 0 commits ahead of main (already merged). 1 uncommitted edit on `Epistemos/Views/Approval/ApprovalModalView.swift`.

**Final task:**
1. Decide: commit the `ApprovalModalView.swift` edit if it's a complete change, OR `git stash push -m "lane-A in-flight 2026-05-16"` if mid-thought.
2. Commit a final wind-down marker:
   ```
   docs(lane-A-stop): final wind-down per user direction 2026-05-16
   ```
   pointing at this doc.
3. **Omit ScheduleWakeup.** Terminal A is done.

---

## Terminal B (run-b-post-v1-research — research substrate) — FINAL PROOF PASS

**Status:** 435 commits ahead. **1643 cargo tests pass** (+449 vs main). Wave I A2UI 24/24, Wave G + J + B.2 + B.6 all COMPLETE per C's audit pulses. Working tree clean.

**Final task: write `docs/ACCEPTANCE_PROOFS_V6_1_2026_05_16.md` — a single canonical proof-of-acceptance doc covering every wave B shipped this run.**

Required structure (≤800 LOC; one row per shipped wave):

```markdown
# V6.1 Acceptance Proofs — Wave-by-Wave Evidence (2026-05-16)

## How to read

For every wave B shipped this run, this doc enumerates:
- (1) The acceptance bar that was claimed
- (2) The test that asserts it
- (3) The cargo test invocation that proves it
- (4) Primary sources cited

## Waves with proofs

| Wave | Acceptance bar | Test name | Cargo invocation | Source citation |
|---|---|---|---|---|
| B.1 vault.search ladder | ... | ... | `cargo test --lib b1_` | doctrine §4.2 |
| B.2 RULER + BABILong @ 32K | ≤30 min wall-clock M2 Pro | ... | ... | helios v6.2.md §S1.8 |
| B.6 Koopman lift + Bauer-Fike | ... | ... | ... | arXiv link |
| ... (every B-wave shipped) | | | | |
| Wave G G5 50-LoRA hot-swap | DAG doctrine §6 cost spec | ... | ... | cognitive_dag_doctrine §6 |
| Wave I A2UI 24/24 | schemars-derived schemas + Swift mirrors + Validator tests | ... | ... | A2UI catalog row |
| Wave J research tier | RESUME signal pending | (deferred) | — | helios v3.md |

## Total test count proof

`cargo test --manifest-path agent_core/Cargo.toml --lib` output verbatim
on this branch:
  → 1643 passed, 0 failed (vs main baseline 1194; +449 new tests)

## What ISN'T proven (honest caveats)

- Wave J entries 1-9 are research-tier; not yet validated against acceptance bars
- Helios kernels (PageGather, SemiseparableBlockScan, LocalRecallIsland,
  ControllerKernelPack, PacketRouter1bit) remain target-only (V6.1
  KERNEL_IMPLEMENTATION_POSTURE = "canonical_target_not_implemented_here")
- B.0 F-ULP-Oracle has not been gated against the 412k log-sampled fixture
  yet — that's a separate slice
```

**After committing the proof doc:**
1. Final commit message: `docs(B-final-proof): V6.1 acceptance proofs — wave-by-wave evidence`
2. **Omit ScheduleWakeup.** Terminal B is done.

---

## Terminal C (run-c-audit — meta auditor) — FINAL HANDOFF SNAPSHOT

**Status:** 400 commits ahead. Watchdog for B/D/F. Working tree clean.

**Final task: write `docs/TERMINAL_HANDOFF_SNAPSHOT_2026_05_16.md` — the single canonical "what state is each terminal in" doc the user can read in 5 minutes to understand what's mergeable.**

Required structure:

```markdown
# Terminal Handoff Snapshot — 2026-05-16

## Status per terminal (as of C iter ~219)

| Terminal | Branch | Commits ahead | Cargo lib tests | Working tree | Status |
|---|---|---|---|---|---|
| A | lane-A | 0 | — | ... | ... |
| B | run-b-post-v1-research | 435 | 1643 | clean | DONE (proofs in ACCEPTANCE_PROOFS_V6_1_2026_05_16.md) |
| C | run-c-audit | 400 | (audit-only) | clean | DONE (this doc) |
| D | run-d-providers | 297 | 1220 | ... | ... |
| E | run-e-decisions | 253 | — | clean | DONE (13 decision research docs, awaiting USER signoff) |
| F | run-f-integrations | 241 | — | ... | ... |
| codex/research-snapshot | codex/research-snapshot-2026-05-08 | ~303 | 1194 | clean | DONE (maintenance + integration + F-VaultRecall-50 fix + Ambient Frequencies) |

## Merge order (low-conflict-first)

1. ...
2. ...
...

## File-conflict predictions per merge step

- After merging THIS terminal: MAS_COMPLETE_FUSION §8 will need conflict
  resolution (every terminal appends rows; keep all in chronological order)
- After merging B: Cargo.toml + Cargo.lock will conflict with D — resolve
  manually by combining both terminal's dependency additions
- ...

## What needs USER ATTENTION before merge

- A's `ApprovalModalView.swift` in-flight edit — commit or stash
- D's `agent_loop.rs` + `providers/claude.rs` in-flight edits — commit
- F's prompt edit — commit or discard
- E's 13 user-decision research docs — USER must read + answer (the
  decisions cannot auto-implement)

## What's still LOOPING that should be stopped manually if needed

If any terminal is mid-iter and hasn't read this doc yet, the user can
manually kill the Claude Code session for that worktree. The branch state
is preserved either way.

## Audit-of-audit register summary (across all 7 loop runs)

- This terminal C: ~30 audit-of-audit cycles
- Terminal B §7 audit checkpoints: ~20 cleared
- Terminal A §0 victory criteria: 5/15 reached
- Maintenance terminal codex/research-snapshot: 8 audits-of-audit
```

**After committing:**
1. Final commit message: `docs(C-final-snapshot): terminal handoff snapshot — merge-readiness verdict`
2. **Omit ScheduleWakeup.** Terminal C is done.

---

## Terminal D (run-d-providers — providers/MCP) — FINAL HARDENING TESTS

**Status:** 297 commits ahead. **1220 cargo tests pass**. Has uncommitted changes to `agent_core/src/agent_loop.rs` + `agent_core/src/providers/claude.rs`.

**Final task: ship D.1.1 + D.1.2 MCP hardening as a single closing commit with proper tests, then stop.**

Steps:

1. **§5.0 reconciliation**: read the 2 uncommitted files and determine what they actually changed. Are they complete patches or mid-thought?

2. **If complete**: stage + commit them with a clear `fix(D.1.x)` message. Add a corresponding test under `agent_core/tests/mcp_hardening_close.rs` (or extend existing tests) covering:
   - URL MCP connector contract: malformed beta header → error path tested
   - stdio MCP request waits: bounded at 30 s → timeout reachable via test fixture

3. **If incomplete**: stash with `git stash push -m "D-runtime in-flight 2026-05-16"` so the work isn't lost, AND add a row to `docs/MAS_COMPLETE_FUSION_IMPLEMENTATION_PLAN §10 Compromises Recorded` noting the in-flight work for follow-up.

4. **Run cargo**: `cargo test --manifest-path agent_core/Cargo.toml --lib` must stay at 1220 OR grow (no regressions).

5. **Final commit message** for the closing commit: `fix(D-final): D.1.1 + D.1.2 MCP hardening closure tests`

6. **Omit ScheduleWakeup.** Terminal D is done.

---

## Terminal E (run-e-decisions — user-decision research) — STOP

**Status:** 253 commits ahead. All 13 user-decision items have research docs in `docs/audits/user-decisions/`. Working tree clean.

**Final task:** none — E's work is fundamentally done. The user must read + answer to advance.

1. Commit a final wind-down marker:
   ```
   docs(E-stop): final wind-down — 13/13 user-decision research docs surfaced, awaiting user signoff
   ```
   pointing at `docs/audits/user-decisions/` index.
2. **Omit ScheduleWakeup.** Terminal E is done.

---

## Terminal F (run-f-integrations — external integrations) — FINAL TESTS

**Status:** 241 commits ahead. Has uncommitted change to its own prompt file. F.1.3 Pro-gated channel worker CLIs shipped.

**Final task: write integration tests for F.1.3 Pro-gated channel worker CLIs, then commit + stop.**

Steps:

1. **Commit or discard** the in-flight prompt edit. If it's a meaningful clarification, commit it; if it's mid-thought, discard with `git checkout -- docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_F_2026_05_16.md`.

2. **Add tests** for the F.1.3 Pro-gated workers in `agent_core/tests/channel_workers_pro_gated.rs` covering:
   - Each new Pro worker CLI binary builds with `#[cfg(feature = "pro-build")]`
   - Each binary correctly errors when launched without the env vars it requires
   - MAS build correctly EXCLUDES these workers (compile-time exclusion test)

3. **Final commit message**: `feat(F-final): F.1.3 Pro-gated channel worker closure tests`

4. **Omit ScheduleWakeup.** Terminal F is done.

---

## Cross-terminal final-state invariants

After all terminals stop, the user should expect:

| Branch | Commits ahead of main | Working tree | Final commit type |
|---|---|---|---|
| lane-A | 0 or 1 | clean | docs(lane-A-stop) or fix(N1 ApprovalModal) |
| run-b-post-v1-research | 436 | clean | docs(B-final-proof) |
| run-c-audit | 401 | clean | docs(C-final-snapshot) |
| run-d-providers | 298 (or 299 with test) | clean | fix(D-final) |
| run-e-decisions | 254 | clean | docs(E-stop) |
| run-f-integrations | 242 (or 243 with tests) | clean | feat(F-final) |
| codex/research-snapshot-2026-05-08 | 303 (this terminal — already wound-down at iter 83) | clean | already idle |

Total: ~1,936 commits across 7 branches ready to merge to main per the merge order in `TERMINAL_HANDOFF_SNAPSHOT_2026_05_16.md`.

---

## Discipline reminders for the final iter

- **§5.0 reconciliation gate stays non-negotiable** — verify state on disk before writing doctrine, even on the final iter.
- **§1.5 SCOPE BOUNDARY** — each terminal does ONLY its own section above. No bleed.
- **Cargo test baseline must hold or grow** — no regressions on the final commit.
- **Commit message format** stays the same: `<type>(<scope>): <summary>` with HEREDOC body + Co-Authored-By trailer.

*— End of TERMINAL_FINAL_TASKS_AND_STOP. Each terminal reads its own section, executes once, commits, omits ScheduleWakeup. After all 6 active loops stop, the user has 7 stable branches ready to merge.*
