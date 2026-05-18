---
state: v2-progress-master-plan
created_on: 2026-05-18
purpose: Continuity-of-knowledge doc. Hand this to ANY future Claude/Codex session and they can pick up the V2 substrate program without context.
---

# V2 Architecture — Master Progress Plan

This is the durable map of the Epistemos V2 substrate program as of 2026-05-18. If Jojo loses
contact with the current Claude session, hand this doc to any new session and they can:
- See what each running terminal owns
- See what phase each terminal is in
- See what's not yet staffed
- See the prior cohort's stopped-with-handoff state
- Continue forever-loop work without losing canon

## Top-line numbers

- **Total commits across all Cohort A + T5: ~1,400+**
- **Total commits from prior cohort (T1-T9 stopped 22-24h ago): 433**
- **Cohort A substrate phase: ~65% complete**
- **Full V2 architecture: ~10-15% complete (substrate foundation laid; runtime + product wiring untouched)**

## Cohort A — 9 active terminals (as of 2026-05-18)

Each terminal has ~3 phases. The launch-order priority is set in `docs/NO_COMPROMISE_ENDGAME_PROMPT_DECK_2026_05_18.md` §3.

| Terminal | Worktree | Tool | Phases | Current phase | Acceptance bar status |
|----------|----------|------|--------|---------------|------------------------|
| T09 Product Architecture Ledger | Epistemos-t09-product-ledger | Claude | 1: classify surfaces · 2: cross-link to W-rows · 3: falsifier verification audit | 3 (iter-109+) | doc-only; ledger growing |
| T10 Eidos V0 | Epistemos-t10-eidos | Claude | 1: retrieval modes + RRF · 2: closed-citation validators · 3: Swift mirror + Eidos wiring | 2→3 transition | 7 retrieval modes shipped |
| T11 Agent Runtime v2 / System G | Epistemos-t11-agent-runtime-v2 | Claude | 1: substrate primitives · 2: FUSION (absorb LocalAgent + cloud + CLI + MCP) · 3: witnessed pipeline end-to-end | **1 — Phase 2 fusion NOT STARTED** | 80 commits Phase 1 substrate |
| T12 F-ULP Oracle | Epistemos-t12-f-ulp | Codex | 1: harness + fixtures + ladder · 2: NaN/subnormal hardening · 3: live Metal GPU evidence | 2 | 52 commits, full witness pipeline |
| T17B Lattice/WBO Register | Epistemos-t17b-lattice-wbo-register | Codex | 1: types + register + codecs · 2: validators + cross-links · 3: falsifier hooks + adversarial | 3 (iter-200+) | 200+ commits — furthest along |
| T18B ACS Admission Field | Epistemos-t18b-acs-admission-field | Codex | 1: types + policy matrix · 2: ACSAuditSink → RunEventLog wire (DEPENDS ON T11) · 3: multi-agent ACS | **1 — Phase 2 blocked by T11 fusion** | 68 commits, policy types shipped |
| T21 Vault Recall Contract | Epistemos-t21-vault | Claude | 1: Fix-B + Fix-C · 2: 50 adversarial fixtures · 3: deep hardening | 2 (iter-83 of target ~83+) | 84 commits, 5 fixture classes |
| T23B M2 Pro Falsifier Handbook | Epistemos-t23b-m2pro-falsifier-handbook | Codex | 1: handbook + falsifier rows · 2: artifact schema (Q5) · 3: validator harness + negative catalog | 2→3 transition | 125+ commits, Q5 schema 2026-05-18.2 |
| T5 EML-IR + Lean | Epistemos-t5-emlir | Codex | 1: primitive IR stack (500 commits) · 2: LEAN-FIRST PIVOT (just started) · 3: real lake build + closed sorries | **1→2 just pivoted** | 500 commits Rust; Lean side ~5% |

## V2 Architecture — 8 meta-phases (the bigger map)

| # | Phase | Status | Owner |
|---|-------|--------|-------|
| 1 | Substrate primitives | ~65% — Cohort A running | 8 T-terminals + T5 |
| 2 | Merge phase (T-branches → main, W-row priority order) | 0% | Manual, user-authorized |
| 3 | Integration phase (T10B, T22B, T14, T18, T22) | 0% | Post-merge new terminals |
| 4 | Falsifier evidence phase (actual M2 Pro runs producing artifacts) | 0% | Post-merge benchmark terminal |
| 5 | Product wiring (substrate → MAS app shell, user-visible surfaces) | 0% | T27 WRV surfacing terminal |
| 6 | Maturity / deep hardening | partial within Cohort A | All terminals continue forever-loop |
| 7 | Research/Vault tier (T23 F-70B-Cocktail, XPC Mastery, multi-agent ACS runtime, Simulation v1.7+) | 0% | Gated, separate cohorts |
| 8 | Endgame: Active-Support Verified Cognitive Runtime | 0% — north star | All phases convergence |

**Total V2 progress: ~10-15% of canonical endgame.**

## Launch order from prompt deck §3 (verbatim)

1. T09 Product Architecture Ledger
2. T21 Vault Recall Contract / F-VaultRecall-50
3. T10 Eidos V0
4. T10B Eidos Form Layer (read-only substrate slice) — **NOT STAFFED**
5. T22B Brain Panel closed citations — **NOT STAFFED**
6. T11 Agent Runtime v2 / System G
7. T14 / T17B / T18B (UAS/UASA wiring, Lattice/WBO, ACS admission)
8. T18 Residency Governor + T22 Substrate Health Panel — **NOT STAFFED**
9. T12 F-ULP + T13 F-KV-Direct + T23 F-70B-Cocktail + T23B M2 Pro Handbook — **T13 + T23 NOT STAFFED**
10. T27 WRV product surfacing — **NOT STAFFED**

**Staffed: T09, T21, T10, T11, T17B, T18B, T12, T23B + T5 (separate lane). 9 of 24 T-prompts.**

**Unstaffed and needed for V2 completion (priority order):**

| T-ID | What it does | Blocking dependency |
|------|--------------|---------------------|
| T10B | Eidos Form Layer (canonical object identity) | T10 acceptance bar met |
| T22B | Brain Panel closed citations (visible source trace) | T10 + T10B |
| T13 | F-KV-Direct falsifier (Qwen3-8B MLX 4-bit at 128K) | Merge phase + benchmark hardware |
| T14 | Five-plane UAS-ACS wiring | T17B + T18B merged into main |
| T18 | Residency Governor (memory tier governance) | T17B merged |
| T22 | Substrate Health Panel (visibility surface) | All substrate merged |
| T23 | F-70B-Cocktail falsifier (Research/Vault tier) | Merge phase + larger model artifacts |
| T27 | WRV product surfacing (first 3 P0 W-rows visible) | All substrate merged + integration done |

## Prior cohort (T1-T9 from 2026-05-16) — stopped with handoff

These ran for ~24 hours and stopped intentionally with explicit handoff commits. NOT zombies.

| Branch | Commits | Final commit | Status |
|--------|---------|--------------|--------|
| codex/t1-trifusion-2026-05-16 | 69 | "mark T1 loop stopped" | ✅ handoff |
| codex/t2-agent-2026-05-16 | 38 | "track T2 gated after-merge work" | ✅ handoff |
| codex/t3-uasacs-2026-05-16 | 64 | "multi-terminal archeology prompt" | ✅ handoff |
| codex/t4-vault-2026-05-16 | 144 | "require token fallback evidence" | ✅ stopped pre-completion |
| codex/t6-uiux-2026-05-16 | 38 | "Gain vs Master volume" | ✅ stopped |
| codex/t7-eml-2026-05-16 | 30 | "T7 iter 30 — final close-out for next-Claude" | ✅ handoff |
| codex/t8-biometric-2026-05-16 | 11 | "coordination audit hooks" | ✅ stopped early |
| codex/t9-coord-2026-05-16 | 39 | "disk-capacity handoff note" | ✅ handoff |

**Total prior cohort: 433 commits, waiting for merge phase.** Most reached ~1-2 of their 3 phases before stopping.

## Critical dependencies between terminals

- **T11 Phase 2 fusion blocks T18B Phase 2 wiring.** ACSAuditSink → RunEventLog cannot complete until T11 absorbs LocalAgent + cloud + CLI into agent_runtime_v2.
- **T5 Lean Phase 2 blocks proof-carrying claims.** `elan`/`lean`/`lake` are not in PATH. Until that's installed, T5 is stuck saying "Lean source emitted" not "lake build passed."
- **T17B merge blocks T18 + T22 + T14.** Tier vocabulary must canonicalize first.
- **All merge phase work blocked on user-authorized merge order.** T-branches DO NOT MERGE without explicit Jojo approval per the W-row priority in CROSS_TERMINAL_WIRING_BACKLOG_2026_05_17.md.

## Estimated time to V2 architecture canonical-done

At current parallel forever-loop pace, assuming credits hold and no major rewrite:

- **Cohort A substrate fully canonical** (all acceptance bars met + deep hardening exhausted): **~1-2 weeks**
- **Merge phase + first integration**: **3-5 days of careful W-row ordered merges (manual)**
- **T10B + T22B + T13 + T14 + T18 + T22 + T27 second-wave terminals**: **~2-3 weeks after merge**
- **First real F-* runtime evidence on actual M2 Pro**: gated on merge + a benchmark terminal that doesn't yet exist
- **V2 finished as canon**: **~6-10 weeks of disciplined work from 2026-05-18**

## What to do if you lose contact with the current Claude session

1. **Hand this doc to a new Claude or Codex session.** Tell them: "Read docs/V2_PROGRESS_MASTER_PLAN_2026_05_18.md, then read docs/CLAUDE_NO_COMPROMISE_SUBSTRATE_HANDOFF_2026_05_18.md, then audit Cohort A terminals via `git log`."

2. **Check each terminal's commit cadence:**
   ```bash
   for wt in t09-product-ledger t10-eidos t11-agent-runtime-v2 t12-f-ulp t17b-lattice-wbo-register t18b-acs-admission-field t21-vault t23b-m2pro-falsifier-handbook t5-emlir; do
     age=$(git -C "/Users/jojo/Downloads/Epistemos-$wt" log -1 --format='%cr' 2>/dev/null)
     echo "$wt: $age"
   done
   ```
   Anything not committing in 10+ minutes is stalled.

3. **Restart any stalled terminal** with its continuation prompt. The continuation prompts are inline in the conversation history; key shape is:
   - `cd /Users/jojo/Downloads/Epistemos-tXX-... && codex-yolo` (or `claude`)
   - Paste a prompt that says: confirm pwd + branch + read prior commits + forever-loop discipline + scope lock + canon read order + anti-summary rules (for Codex).

4. **Disk watch:**
   ```bash
   df -h / | awk 'NR==2 {print $4 " free"}'
   ```
   If under 10 GB free: kill agents, nuke Cohort A `target/` directories (preserving T5's 67 GB), restart. Cohort A `target/` dirs rebuild in ~3-5 min each.

5. **Merge phase is user-authorized only.** Do NOT merge T-branches without Jojo's explicit go.

## Forever-loop discipline pointer

Every terminal runs a build-first / test-later forever loop documented in
`docs/CODEX_AND_CLAUDE_TERMINAL_DISPATCH_2026_05_18.md` §3.5. Key invariants:
- WRV: Wired + Reachable + Visible + Verified.
- Acceptance bar is the FLOOR, never the ceiling.
- Commit after every meaningful change. Never batch.
- Narrow tests only (`cargo test -p agent_core <module>`). NEVER `--workspace`. NEVER `xcodebuild`
  on Rust-only iterations.
- For Codex: NEVER print "Completed iterations N-M" summary blocks — Codex CLI interprets them as
  task completion and goes idle. Use iteration markers only.

## North star

**Active-Support Verified Cognitive Runtime.** The system selects the smallest active support,
checks authority and error budget, executes through governed runtime paths, and leaves a
visible/replayable witness. Cohort A is laying the foundation. The integration, merge, and
product-wiring phases turn the foundation into a running app.

Preserve wide, build narrow. Current-app value first. WRV is the floor, never the ceiling.
The loop never ends.
