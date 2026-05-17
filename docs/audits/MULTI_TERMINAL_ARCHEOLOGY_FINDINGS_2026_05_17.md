---
state: archeology-findings
created_on: 2026-05-17
purpose: Report on the multi-terminal archeology pass — documents which prior cycles were recoverable, which were not, and why. Pairs with the per-cycle punch list(s) produced.
authority: docs/audits/MULTI_TERMINAL_ARCHEOLOGY_PROMPT_2026_05_17.md (the meta-prompt that triggered this archeology)
---

# Multi-Terminal Archeology Findings — 2026-05-17

## §1. TL;DR

The user's hypothesis was **~2 prior multi-terminal (6-terminal-style) cycles**. After full git + doc + worktree archeology:

- **1 prior cycle is fully recoverable**: RUN-B-C-D-E-F + maintenance loop A (2026-05-06 → 2026-05-16). Captured in `docs/audits/POST_RUN_BCDEF_PER_TERMINAL_PUNCH_LIST_2026_05_17.md`.
- **No second 6-terminal cycle exists in the recoverable git/doc history.** Earlier parallel work was at most 2-3 agents (Codex + parallel Codex + Kimi during the late-April audit sprint) and a series of sequential phased handoffs (Phase 4 → 5 → 6 → 6.5 → 7 in mid-April).

The user is **partially correct**: there was significant multi-track parallel work in April + early-May, but it followed a **fleet / 2-agent / phased-handoff** pattern rather than a discrete 6-terminal cycle. The 6-terminal pattern proper appears only twice in the repo's history:

1. **RUN-B-C-D-E-F-A** (May 6 → May 16) — covered in the punch list.
2. **T1-T9** (May 16 → ongoing) — covered in T3's punch list (`UAS_ACS_PER_TERMINAL_PUNCH_LIST_2026_05_17.md`).

The current T-cycle (T1-T9) is what the user is in NOW; the RUN-cycle is what they were in ONE before. So "twice" is best read as "RUN + T-cycle" — and the RUN-cycle is the only prior one needing this archeology pass.

## §2. Methodology — what was searched

Following the discovery commands in `MULTI_TERMINAL_ARCHEOLOGY_PROMPT_2026_05_17.md §"Method — branch + worktree discovery commands"`:

### §2.1 Branch inventory by date

```bash
git for-each-ref --sort=-committerdate refs/heads --format='%(refname:short) %(committerdate:short) %(objectname:short)'
```

Surfaced the following candidate cycles (organized by week):

| Week of | Branches present |
|---|---|
| 2026-05-17 (current) | codex/t{1-9}-*-2026-05-16 (9 branches — current cycle) |
| 2026-05-16 (prior) | run-{b,c,d,e,f}-* + codex/research-snapshot-2026-05-08 (6 branches — RUN cycle) |
| 2026-04-29 | worktree-simulation · claude/vigorous-goldberg-3a2d35 (2 branches; 55 commits divergent) |
| 2026-04-27 | worktree-agent-a0550f9c · lane-A (2 branches) |
| 2026-04-24 | codex/runtime-input-audit (1 branch) |
| 2026-04-15 | 5 claude/* branches ALL at commit 31214a4d4 (0 divergent commits — sibling worktrees that ended in same state) + Phase 6.5/7 sequential handoffs |
| 2026-04-10 | worktree-hermes-parity · claude/serene-wright (2 branches) |
| 2026-04-04 | codex/post-audit-feature-work (1 branch) |

**The April 15 cluster is the closest near-miss to a 6-cycle**: 5 sibling `claude/*` branches at the same commit. But all 5 have **0 commits past** 31214a4d4 — meaning they were Claude Code parallel-worktree slots that never actually produced divergent commits. They are not a true multi-terminal cycle.

### §2.2 Handoff doc archeology

```bash
find docs -name '*HANDOFF*.md' -o -name '*CLOSEOUT*.md' -o -name '*FINAL*.md' -o -name '*TERMINAL*.md'
```

Surfaced ~50 handoff docs. Filtering for "multi-terminal" patterns:

| Doc | Pattern |
|---|---|
| `docs/TERMINAL_HANDOFF_SNAPSHOT_2026_05_16.md` | TC's RUN-cycle closeout (6-terminal cycle) ✅ |
| `docs/TERMINAL_FINAL_TASKS_AND_STOP_2026_05_16.md` | per-terminal final tasks (6-terminal cycle) ✅ |
| `docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_{A,B,C,D,E,F}_2026_05_16.md` | 6 driver prompts (RUN cycle) ✅ |
| `docs/CODEX_HANDOFF_2026_05_16.md` | post-merge consolidation (RUN cycle) ✅ |
| `docs/audits/PARALLEL_AGENT_HANDOFF_2026_04_29.md` | **3-agent** parallel (primary Codex + parallel Codex + Kimi) — NOT 6-terminal |
| `docs/PERF_HANDOFF_TO_CODEX_2026-04-29.md` | **2-agent** parallel (Claude + Codex perf sprint) — NOT 6-terminal |
| `docs/fusion/fleet/CODEX_HANDOFF_2026_05_03.md` (PART 1 + 2) | **Codex + side-fleet** (1 primary + 1-2 parallel-agent slots) — NOT 6-terminal |
| `docs/fusion/CODEX_AGENT_FLEET_PROMPT_2026_05_02.md` | Single Codex with parallel-agent slot fanout — NOT 6-terminal |
| `docs/CODEX_HACKATHON_FINAL_CHECK_2026_05_03.md` | Single-Codex hackathon verification pass — NOT multi-terminal |
| `docs/architecture/PHASE_{4,5,6,6_5,7}_*_HANDOFF*.md` | **Sequential phased** (one Claude/Codex per phase) — NOT parallel |

### §2.3 Worktree archeology

```bash
ls -d /Users/jojo/Downloads/Epistemos-* 2>/dev/null
git worktree list
```

Surfaced 16 worktrees (active + historic). Filtering for parallel-cycle membership:

| Cycle | Worktrees |
|---|---|
| Current T-cycle (May 16-17) | `-t1-trifusion` through `-t9-coord` (9 worktrees) |
| Prior RUN cycle (May 6-16) | `-runB` through `-runF` + `-laneA` (6 worktrees) |
| April scattered | `.claude/worktrees/{hermes-parity, simulation, agent-a0550f9c, inspiring-heisenberg-ea9dc3, kind-panini-0187b4, practical-kapitsa-61a251, quirky-pascal-135a98, serene-ardinghelli-5ab9e6, vigorous-goldberg-3a2d35}` (9 worktrees, but 5 of those are the 0-divergence claude/* sibling slots) |

The April set of 5 sibling claude/* worktrees + claude/vigorous-goldberg-3a2d35 + worktree-simulation + worktree-agent-a0550f9c + worktree-hermes-parity sum to **9 worktrees**, but they were created **over a 3-week span** (April 10 → April 29) and never coordinated into a single round with shared closeout / shared driver prompt set / shared audit conscience. They are independent parallel work, not a 6-terminal cycle.

## §3. Why the April set does not qualify as a 6-terminal cycle

A "6-terminal cycle" in the user's intended sense requires:

| Criterion | RUN cycle (May 16) | T-cycle (May 17) | April set |
|---|---|---|---|
| **Single shared driver prompt set** (one per terminal) | ✅ V3 driver prompts | ✅ T1-T9 driver prompts | ❌ no shared driver-prompt set |
| **Single shared closeout / handoff snapshot** | ✅ TERMINAL_HANDOFF_SNAPSHOT_2026_05_16.md | ✅ UAS_ACS_FINAL_HANDOFF_2026_05_17.md (T3's, others pending) | ❌ no shared closeout |
| **Shared timeline (≤ 2 weeks)** | ✅ May 6 → May 16 (10 days) | ✅ May 16 → ongoing | ❌ April 4 → April 29 (3+ weeks across uncoordinated micro-cycles) |
| **Coordinated audit conscience terminal** | ✅ TC = `run-c-audit` | ✅ T9 = `codex/t9-coord-2026-05-16` | ❌ no audit-conscience role |
| **Per-terminal scope lock + cross-terminal coordination protocol** | ✅ scope-lock docs in §0 of each driver | ✅ scope-lock + coordination matrix per T3's doc | ❌ no scope-lock contract |
| **Shared stop-directive mechanism** | ✅ STOP-ALL-TERMINALS `a18e72d65` + 4 dupes | ✅ "stop T<N>" per-terminal protocol | ❌ no stop directive |

The April set fails 5/6 criteria. It was healthy parallel ad-hoc work, not a multi-terminal cycle in the structured sense the user is asking about.

## §4. What the April work actually was

For completeness, here's what the April parallel work consisted of (NOT structured as a punch list — would invent rows):

### §4.1 Mid-April Phase Sequential (April 10-15)

- **Phase 4 handoff** (`PHASE_4_HANDOFF.md`) — sequential Codex
- **Phase 5 handoff** (`PHASE_5_HANDOFF.md`) — sequential Codex
- **Phase 6 Clark handoff** (`PHASE_6_CLARK_HANDOFF_2026_04_14.md`) — Claude single-session audit
- **Phase 6.5 Claude startup** (`PHASE_6_5_CLAUDE_STARTUP_HANDOFF_2026_04_15.md`) — sequential Claude
- **Phase 7 Codex audit** (`PHASE_7_CODEX_AUDIT_HANDOFF_2026_04_15.md`) — sequential Codex

These are phased sequential handoffs, not parallel cycles.

### §4.2 Late-April 2-3 Agent Parallel Sprints (April 23-29)

- **April 23**: `CLAUDE_CANONICAL_STATE_HANDOFF_2026-04-23.md` — single Claude canonical-state audit task
- **April 24**: `codex/runtime-input-audit` branch — single Codex audit
- **April 27**: `worktree-agent-a0550f9c` + `lane-A` — uncoordinated 2-track work
- **April 29**: `PARALLEL_AGENT_HANDOFF_2026_04_29.md` — **3-agent** (primary Codex + parallel Codex + Kimi) with explicit no-edit zones + small audit tasks
- **April 29**: `PERF_HANDOFF_TO_CODEX_2026-04-29.md` — **2-agent** (Claude perf sprint → Codex consolidation)

These are 2-3 agent cycles, not 6-terminal cycles.

### §4.3 Early-May Fleet / Hackathon (May 1-5)

- **May 1**: `CODEX_FINAL_EXECUTION_PROMPT_2026_05_01.md` — single Codex final-execution pass
- **May 2**: `CODEX_AGENT_FLEET_PROMPT_2026_05_02.md` — **fleet** of agent-2 slots assisting primary Codex
- **May 3**: `fusion/fleet/CODEX_HANDOFF_2026_05_03.md` (PART 1 + 2) — primary Codex + side-fleet of agent-2 slots
- **May 3**: `CODEX_HACKATHON_FINAL_CHECK_2026_05_03.md` — single Codex hackathon verification
- **May 4**: `CODEX_RECOVERY_HANDOFF_2026_05_04.md` — single Codex recovery work
- **May 5**: `SUBSTRATE_V2_FINAL_CLOSEOUT_2026_05_05.md` — single-session V2 closeout

These are primary+fleet patterns (1 primary + N parallel-agent slots), not 6-terminal cycles.

### §4.4 The 5 sibling claude/* branches (mid-April)

`claude/inspiring-heisenberg-ea9dc3`, `kind-panini-0187b4`, `practical-kapitsa-61a251`, `quirky-pascal-135a98`, `serene-ardinghelli-5ab9e6` — all at commit `31214a4d4` with 0 divergent commits past that base.

These appear to be **Claude Code worktree-creation slots** (the auto-generated `<adjective>-<scientist>-<short-hash>` naming pattern is the Claude Code default for `/worktree` skill). They were created but **never produced divergent commits** — meaning they were either:

- Created and immediately abandoned (no work done on them)
- Created and the work was merged back to the parent before push (so no divergence remains)
- Created as placeholder slots that the user never finished

Without divergent commits or a per-branch handoff doc, there's no archeology evidence to reconstruct what was deferred. They are best treated as orphan worktrees rather than a multi-terminal cycle.

## §5. Punch list deliverables

Per the archeology prompt's stopping condition:

1. **`docs/audits/POST_RUN_BCDEF_PER_TERMINAL_PUNCH_LIST_2026_05_17.md`** — per-terminal punch list for the RUN cycle (May 6-16). The single recoverable prior multi-terminal cycle.
2. **This findings doc** — explains why a second 6-terminal cycle is not in the recoverable history.

The current cycle's per-terminal punch list (T3 UAS-ACS) is in `docs/audits/UAS_ACS_PER_TERMINAL_PUNCH_LIST_2026_05_17.md` (not produced by this archeology pass — already authored by T3 itself).

## §6. Cross-cycle interconnection — what carried forward

For completeness, items that the RUN cycle's deferral list flagged AND the current T-cycle picked up:

| Item | Deferred by (RUN cycle) | Picked up by (T-cycle) | Status in T-cycle |
|---|---|---|---|
| Helios kernels — PageGather, SemiseparableBlockScan, LocalRecallIsland, ControllerKernelPack, PacketRouter1bit | TB §3 (declared `canonical_target_not_implemented_here`) | T3 UAS-ACS — substrate-floor PASS for 8/11 §4.G ladder gates | Substrate-floor done; Metal kernels still deferred per T3 punch list §9 Swift/Metal lane |
| Wave J research-tier validation (J1-J9) | TB §3 (research-only, USER must decide promotion) | T3 picked up J1 (ternary substrate harness at iter 58), J2 (SAE observatory iter 61), J6 (hyperdynamic schemas iter 62), J7 (Sherry 3:4 sparse ternary codec iter 59) | 4/9 J-waves now have research-tier harnesses on T3 branch |
| User-decision research → owning-terminal handoff | TE §6 (13 decisions awaiting USER signoff) | T2 + T4 + T6 + T7 work in current cycle is partially driven by decisions that originated in TE's research docs | Each T-terminal's scope inherits answered TE decisions |
| Brain export + Biometric Tamagotchi | TB §3 (Wave G/H deferral) | T8 §4.D (Phase 0 doctrine doc — full 9 sections; Phase B gated) | Doctrine done; implementation gated on T1+T2+T6 PRs landing |
| MCP integration (TD's queue) | TD §5 (cloud providers · MCP servers · CLI passthrough · code execution) | T2 (current cycle, agent runtime) consumes provider grammars TD shipped | T2 builds per-model native grammars on top of TD's provider expansion |
| iMessage full inbound (TF criterion #2) | TF §7 | T2 agent_runtime would consume per K-channel doctrine | NOT YET in current cycle scope; deferred to future |

This carryover-table is itself a punch list pattern that future archeology can extend.

## §7. Anti-rules adherence

Per the archeology prompt's anti-rules:

- ✅ **Did NOT invent deferrals** — every row in `POST_RUN_BCDEF_PER_TERMINAL_PUNCH_LIST` traces to a specific file path / V3 driver §0 criterion / TERMINAL_HANDOFF_SNAPSHOT row / merge commit
- ✅ **Did NOT copy template content** — punch list format follows T3's template but every Item/Where/Why/Acceptance is sourced from RUN-cycle evidence
- ✅ **Did NOT modify T3-cycle docs** — T3's punch list / handoff / coord docs are untouched
- ✅ **Did NOT schedule wakeups** — this is one-shot archeology

## §8. Open Questions

1. **The 5 sibling claude/* branches** at commit `31214a4d4` — were they actually a coordinated cycle that the user is remembering as "6 terminals"? Without divergent commits or a closeout doc, this can't be reconstructed. If the user has off-disk memory of what those branches were FOR, they could write a brief explanation that the archeology could then expand into a punch list. Best resolution: ask the user.

2. **The Fleet round** (early May, `docs/fusion/fleet/`) might be larger than the 2-3 agent pattern I inferred — the `fleet/` directory has ~80 PR-named subdirectories suggesting heavy parallel work. But each subdir is an individual PR, not a per-terminal scope. Could be re-investigated if needed.

3. **`claude/vigorous-goldberg-3a2d35`** has 55 commits past `31214a4d4`, meaning ONE of the 6 April Claude branches did substantial work. This could be a single-Claude-session with its own deferrals worth a mini-punch list. Skipped here for scope; can be added if user wants.

These can be resolved by user input or a future archeology micro-pass.

## §9. Cross-references

- **Meta-prompt that triggered this archeology**: `docs/audits/MULTI_TERMINAL_ARCHEOLOGY_PROMPT_2026_05_17.md` (T3-authored)
- **Template**: `docs/audits/UAS_ACS_PER_TERMINAL_PUNCH_LIST_2026_05_17.md` (T3-authored)
- **Coord doc shape**: `docs/audits/UAS_ACS_T_TERMINAL_COORDINATION_2026_05_17.md` (T3-authored)
- **Current cycle handoff**: `docs/audits/UAS_ACS_FINAL_HANDOFF_2026_05_17.md` (T3-authored)
- **RUN cycle punch list (this archeology's main deliverable)**: `docs/audits/POST_RUN_BCDEF_PER_TERMINAL_PUNCH_LIST_2026_05_17.md`
- **RUN cycle closeout**: `docs/TERMINAL_HANDOFF_SNAPSHOT_2026_05_16.md`
- **9-terminal launch prompts**: `docs/CODEX_9_TERMINAL_PROMPTS_2026_05_16.md`
- **Deep investigation prompt** (current cycle authority): `docs/CODEX_DEEP_INVESTIGATION_PROMPT_2026_05_16.md`

---

*Archeology pass complete. One per-cycle punch list produced (RUN cycle). Second-prior 6-terminal cycle does not exist in recoverable history; alternative interpretations and partial leads documented in §4 + §8 for user resolution.*
