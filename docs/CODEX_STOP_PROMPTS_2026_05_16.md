# Codex STOP Prompts — paste any of these into the matching Codex terminal

These prompts replace whatever the autonomous loop is currently doing. Each
one is self-contained — Codex doesn't need to read other docs to execute.
Each ends by telling Codex to exit (no further scheduling).

After Codex executes a prompt below, that terminal stops. You can then close
the Codex session safely.

If you don't know which terminal is on which Codex window, glance at the
git log — the commit-message prefix tells you (`docs(T-A-...)` = Terminal A,
`feat(b1)` or `research/a2ui` = Terminal B, `docs(status pulse iter ...)` =
Terminal C, `fix(D.1.x)` = Terminal D, `research(L-2)` / `research(B-3)` =
Terminal E, `feat(F.1.x)` = Terminal F).

---

## ▌ Terminal A — codex/research-snapshot-2026-05-08 — STOP

```
STOP DIRECTIVE — user has decided to close all autonomous loops.

Your final task: NONE — Terminal A's work is done (V1 ship gates closed,
N1 Prompt Tree shipped, recursive audit pass log on streak).

Steps:
1. `git status --short` — list any uncommitted files
2. If anything is uncommitted: `git stash push -m "Terminal A stop stash 2026-05-16"`
   to preserve it without committing.
3. Run `cargo test --manifest-path agent_core/Cargo.toml --lib` once
   to confirm baseline holds. Report the test count.
4. Commit a wind-down marker:
   ```
   git commit --allow-empty -m "$(cat <<'EOF'
   docs(T-A-stop): final wind-down per user direction 2026-05-16

   Terminal A closes here. V1 ship gates met (RECURSIVE_TODO zero
   CONFIRMED + zero TODO V1-blocking, APP_ISSUES_AUTO_FIX zero Open,
   Phase E.1 streak on track, cargo baseline holds).

   User: close all 6 terminals 2026-05-16.

   Co-Authored-By: Codex Loop <noreply@anthropic.com>
   EOF
   )"
   ```
5. **DO NOT schedule another iteration.** Exit. The Codex window can be
   closed.

That's it. After step 5, this terminal is done.
```

---

## ▌ Terminal B — run-b-post-v1-research — FINAL PROOFS + STOP

```
STOP DIRECTIVE — user has decided to close all autonomous loops.

Your final task BEFORE stopping: write a single canonical V6.1 acceptance-
proofs doc covering every wave you shipped this run.

Steps:

1. Verify cargo baseline holds:
   `cargo test --manifest-path agent_core/Cargo.toml --lib`
   Expect ~1643 tests passing. If different, note it.

2. Create `docs/ACCEPTANCE_PROOFS_V6_1_2026_05_16.md` with this structure
   (fill in the gaps from your actual shipped work — keep total < 600 LOC):

   ```markdown
   # V6.1 Acceptance Proofs — Wave-by-Wave Evidence (2026-05-16)

   Each row: claimed acceptance bar · asserting test name · cargo
   invocation that proves it · primary source citation.

   ## Wave B (V6.1 floor)
   | Wave | Acceptance bar | Test | Cargo invocation | Source |
   | B.1 vault.search variant ladder | T1 lexical-only via lexical_search method | `tests::variant_ladder::vault_search_*` | `cargo test --lib vault_search_ladder` | doctrine §4.2 + B.1 2/N spec |
   | B.2 RULER + BABILong @ 32K | ≤30 min wall-clock M2 Pro | (fill in actual test name) | ... | helios v6.2.md §S1.8 |
   | B.6 Koopman lift + Bauer-Fike | bauer_fike_bound holds | ... | ... | (arXiv ref) |
   | B.7 brain_export | ... | ... | ... | ... |
   | (every other B-wave you shipped) | | | | |

   ## Wave G (Simulation)
   | Wave | Acceptance bar | Test | Cargo invocation | Source |
   | G4 Hermes Snake z+1 plane substrate | ... | ... | ... | ... |
   | G5 50-LoRA hot-swap | DAG doctrine §6 cost spec | ... | ... | cognitive_dag_doctrine §6 |

   ## Wave I (A2UI)
   - Total components: 24 base + N expansions
   - Per-component invariants pinned
   - Schemars schemas + Swift mirrors + Validator tests
   | Component | Test count | Invariants |
   | ConfidenceBadge | ... | doctrine threshold constants |
   | CapabilityChip | ... | ... |
   | (the full catalog) | | |

   ## Wave J (research-tier, gated)
   J1 ternary core (sub-components shipped: pack/gemv/residual_island/...)
   J2 KV implantation (status: ...)
   J3 continual learning (SEAL-DoRA shipped)
   J4 NeMoCLAW/OpenCLAW
   J5 ACS recursive governance (Kuramoto + Notch-Delta + autopoiesis +
      VSM shipped)
   J6 ... J9 paper registry

   ## Total test-count proof
   `cargo test --manifest-path agent_core/Cargo.toml --lib` returns:
   1643 passed, 0 failed (vs main baseline 1194; +449 new tests from
   this run).

   ## Honest caveats
   - Helios kernels (PageGather/SemiseparableBlockScan/LocalRecallIsland/
     ControllerKernelPack/PacketRouter1bit) remain target-only per
     V6.1 KERNEL_IMPLEMENTATION_POSTURE = "canonical_target_not_implemented_here"
   - B.0 F-ULP-Oracle 412k log-sampled fixture not yet gated against
     ≤2 ULP fp16 tolerance — separate slice
   - (any other things you didn't actually finish)
   ```

3. Commit:
   ```
   git add docs/ACCEPTANCE_PROOFS_V6_1_2026_05_16.md
   git commit -m "$(cat <<'EOF'
   docs(B-final-proof): V6.1 acceptance proofs — wave-by-wave evidence

   User: close all 6 terminals 2026-05-16. Final proof pass before stop.

   Co-Authored-By: Codex Loop <noreply@anthropic.com>
   EOF
   )"
   ```

4. **DO NOT schedule another iteration.** Exit. The Codex window can be
   closed.
```

---

## ▌ Terminal C — run-c-audit — FINAL HANDOFF SNAPSHOT + STOP

```
STOP DIRECTIVE — user has decided to close all autonomous loops.

Your final task BEFORE stopping: write the canonical "merge-readiness
verdict per terminal" doc so the user can decide what to merge.

Steps:

1. `git status --short` — confirm clean working tree.

2. For each of the 7 branches (lane-A, run-b-post-v1-research, run-c-audit,
   run-d-providers, run-e-decisions, run-f-integrations, codex/research-
   snapshot-2026-05-08), gather:
   - Commits ahead of origin/main: `git rev-list --count origin/main..<branch>`
   - Cargo test count (if applicable)
   - Dirty file count: `git status --short | wc -l`

3. Create `docs/TERMINAL_HANDOFF_SNAPSHOT_2026_05_16.md` with:

   ```markdown
   # Terminal Handoff Snapshot — 2026-05-16

   ## Status per terminal

   | Terminal | Branch | Commits ahead of main | Cargo lib tests | Working tree | Status |
   | A | codex/research-snapshot-2026-05-08 | (fill in) | (fill in) | (fill in) | DONE / IN-FLIGHT |
   | B | run-b-post-v1-research | ... | 1643 | clean | DONE (proofs in ACCEPTANCE_PROOFS_V6_1) |
   | C | run-c-audit | ... | (audit-only) | clean | DONE (this doc) |
   | D | run-d-providers | ... | 1220 | ... | ... |
   | E | run-e-decisions | ... | — | clean | DONE (13 decision docs, USER signoff needed) |
   | F | run-f-integrations | ... | — | ... | ... |
   | lane-A | lane-A | 0 | (stale) | ... | ARCHIVE — work salvaged 3 weeks ago |

   ## Recommended merge order (lowest-conflict-first)

   1. codex/research-snapshot-2026-05-08 → main (mostly already pushed)
   2. run-e-decisions → main (research docs only)
   3. run-c-audit → main (audit pulses; conflicts on MAS_COMPLETE_FUSION §8)
   4. run-f-integrations → main (Pro-gated new files)
   5. run-d-providers → main (Cargo.toml + agent_core/src/providers)
   6. run-b-post-v1-research → main (largest; +449 tests; touches Cargo.toml)
   7. lane-A → DO NOT MERGE (3-week-old divergent state)

   ## Known conflicts per step

   - Step 3 (C): MAS_COMPLETE_FUSION §8 Implementation Log — every
     terminal appended rows. Resolution: combine in chronological order
     (mechanical, not a value judgment).
   - Step 5 (D): agent_core/src/providers/claude.rs — D modified for
     authenticated URL MCP + stdio timeout. Verify against main's tip.
   - Step 6 (B): agent_core/Cargo.toml — B added new research crates;
     combine with whatever main has.

   ## Audit-of-audit register summary

   - Terminal C audits run: ~(fill in count)
   - Terminal B §7 audit checkpoints cleared: ~(fill in)
   - Terminal A self-audits: ~(fill in)
   - Maintenance terminal codex/research-snapshot AoA cycles: 8 (#1-#8)

   ## What needs USER attention before merging

   - E's 13 user-decision research docs in docs/audits/user-decisions/
     — user must read + answer to advance (research doesn't auto-implement)
   - F's in-flight prompt edit (if still present) — commit or discard
   ```

4. Commit:
   ```
   git add docs/TERMINAL_HANDOFF_SNAPSHOT_2026_05_16.md
   git commit -m "$(cat <<'EOF'
   docs(C-final-snapshot): terminal handoff snapshot — merge-readiness verdict

   User: close all 6 terminals 2026-05-16. Final audit pass before stop.

   Co-Authored-By: Codex Loop <noreply@anthropic.com>
   EOF
   )"
   ```

5. **DO NOT schedule another iteration.** Exit. The Codex window can be
   closed.
```

---

## ▌ Terminal D — run-d-providers — FINAL HARDENING + STOP

```
STOP DIRECTIVE — user has decided to close all autonomous loops.

Your final task BEFORE stopping: finalize the D.1.1 + D.1.2 MCP hardening
work so it's mergeable, then stop.

Steps:

1. `git status --short` — list uncommitted files. You may have changes
   to `agent_core/src/agent_loop.rs` and `agent_core/src/providers/claude.rs`.

2. For each modified file:
   - Run `cargo check --manifest-path agent_core/Cargo.toml` to confirm
     it compiles.
   - If it's a complete patch: `git add <file>` and proceed to step 3.
   - If it's mid-thought: `git stash push -m "D-runtime in-flight 2026-05-16 <file>"`
     and add a TODO note in a doc file noting the in-flight work.

3. Add a test under `agent_core/tests/` covering D.1.1 and D.1.2:
   - D.1.1: authenticated URL MCP — verify the Authorization header is
     forwarded correctly
   - D.1.2: stdio MCP — verify request wait is bounded at 30s (use a
     test fixture that never responds; assert the wait returns within
     30.5s ± 0.5s)

4. Verify all tests pass:
   `cargo test --manifest-path agent_core/Cargo.toml --lib`
   Expect ~1220+ tests passing.

5. Commit:
   ```
   git commit -m "$(cat <<'EOF'
   fix(D-final): D.1.1 + D.1.2 MCP hardening closure tests

   - D.1.1 authenticated URL MCP servers: header-forwarding test
   - D.1.2 stdio MCP request wait bound: 30s timeout test

   User: close all 6 terminals 2026-05-16. Final closure tests before stop.

   Co-Authored-By: Codex Loop <noreply@anthropic.com>
   EOF
   )"
   ```

6. **DO NOT schedule another iteration.** Exit. The Codex window can be
   closed.
```

---

## ▌ Terminal E — run-e-decisions — STOP

```
STOP DIRECTIVE — user has decided to close all autonomous loops.

Your final task: NONE — Terminal E's work is fundamentally done. All 13
user-decision research docs are already in `docs/audits/user-decisions/`.
Only the user can advance from here by reading the docs and answering.

Steps:

1. `git status --short` — confirm clean (should be).

2. Verify `docs/audits/user-decisions/` (or wherever you placed them)
   has 13 docs:
   `ls docs/audits/user-decisions/ | wc -l`
   If less than 13, list which decisions are still missing in the
   wind-down commit message.

3. Commit an empty wind-down marker:
   ```
   git commit --allow-empty -m "$(cat <<'EOF'
   docs(E-stop): final wind-down — N/13 user-decision research docs surfaced, awaiting user signoff

   13 user-decision items per MAS_COMPLETE_FUSION §10:
     B-1 Live Files · B-2 Brain Export · B-3 Confidence Meter ·
     B-4 Pixel/Tactical · H-3/B2-H6 EditPage macaroon ·
     B2-M5 HardwareProfile budget · L-2 V6.2 per-bubble VRMLabelView ·
     L-3 Graph Toolbar buttons · §10.4 WASMExecJIT entitlement ·
     B-3 Undo (V1.1 scope) · B2-H16 Chatterbox voice ·
     ORPHAN-HERMES-SALVAGE-001 · RCA13-P0-001 vault lifecycle

   Each has a research doc under docs/audits/user-decisions/. User
   must read + answer to advance.

   User: close all 6 terminals 2026-05-16.

   Co-Authored-By: Codex Loop <noreply@anthropic.com>
   EOF
   )"
   ```

4. **DO NOT schedule another iteration.** Exit. The Codex window can be
   closed.
```

---

## ▌ Terminal F — run-f-integrations — FINAL TESTS + STOP

```
STOP DIRECTIVE — user has decided to close all autonomous loops.

Your final task BEFORE stopping: add tests for F.1.3 Pro-gated channel
worker CLIs and clean up any in-flight edits.

Steps:

1. `git status --short` — list uncommitted files.

2. If `docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_F_2026_05_16.md`
   is dirty:
   - If the edit is a meaningful clarification: commit it.
   - If mid-thought or accidental: `git checkout -- <file>` to discard.

3. Add tests for the F.1.3 Pro-gated channel workers in
   `agent_core/tests/channel_workers_pro_gated.rs` covering:
   - Each new Pro worker CLI binary builds with `#[cfg(feature = "pro-build")]`
   - Each binary correctly errors when launched without required env vars
     (e.g. TELEGRAM_BOT_TOKEN, SLACK_WEBHOOK_URL, etc.)
   - MAS build (default features, no `pro-build`) EXCLUDES these workers
     (a compile-time exclusion test using `#[cfg(not(feature = "pro-build"))]`)

4. Verify cargo test:
   `cargo test --manifest-path agent_core/Cargo.toml --lib`
   The Pro-gated tests will skip on default features; run with
   `cargo test --features pro-build` to exercise them.

5. Commit:
   ```
   git commit -m "$(cat <<'EOF'
   feat(F-final): F.1.3 Pro-gated channel worker closure tests

   Tests confirm:
   - Each Pro worker binary builds with pro-build feature
   - Each binary errors without required env vars
   - MAS default-feature build excludes the workers

   User: close all 6 terminals 2026-05-16. Final closure tests before stop.

   Co-Authored-By: Codex Loop <noreply@anthropic.com>
   EOF
   )"
   ```

6. **DO NOT schedule another iteration.** Exit. The Codex window can be
   closed.
```

---

## How to use these

1. **Identify each Codex terminal's branch** — look at the most recent commit
   message in its window. The prefix tells you which terminal it is.

2. **Copy the entire code block** from the matching section above (between
   the triple-backticks).

3. **Paste it into the Codex window** as a new user message. Codex will:
   - Read the directive
   - Execute the final task
   - Commit the result
   - Stop scheduling new iterations

4. **Close the Codex session window** after it acknowledges the final
   commit. The branch state is preserved.

5. **Verify each terminal stopped** by checking that no new commits arrive
   on its branch over a 5-10 minute window after the final commit.

## If a terminal won't stop

Just close the Claude Code or Codex session window externally. The branch
state on disk is preserved regardless. The cherry-picked STOP commit
(`a18e72d65` on this branch; matching SHA on others) remains in the git
history.
