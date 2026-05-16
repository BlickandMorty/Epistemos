# Autonomous Loop — Universal Invocation Guide (Claude Code + Codex)

**Purpose:** Single guide for invoking any of the 6 parallel terminal prompts (A through F) in either Claude Code or Codex. All 6 prompts are platform-agnostic per `§Universal-Compat` below.

---

## §1. The 6 terminals (run in parallel)

| Terminal | Branch | Mission | Prompt file | Est. runtime |
|---|---|---|---|---|
| **A** | `codex/research-snapshot-2026-05-08` | V1 ship (MAS App Store + Pro Developer ID) | `docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_A_2026_05_16.md` | days-to-weeks |
| **B** | `run-b-post-v1-research` | Post-V1 + research tier (Helios kernels · Wave G/H/I/J minus J4 · 136 NOT-STARTED · Brain export · Tamagotchi · Live Files V1.1+) | `docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_B_2026_05_16.md` | weeks-to-months |
| **C** | `run-c-audit` | Continuous audit + verification (audit-of-audit every 3-5 commits across all terminals · §5.0 re-verification · MASTER_RESEARCH_INDEX maintenance · AGENT_PROGRESS sprint tracking · cross-link auditing) | `docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_C_2026_05_16.md` | indefinite |
| **D** | `run-d-providers` | New cloud providers (Gemini · Kimi · xAI · Codex CLI wrap · Codestral) + new MCP servers + CLI passthrough tools (Pro) + code execution tools (Pro) + tool registry expansion | `docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_D_2026_05_16.md` | weeks |
| **E** | `run-e-decisions` | User-decision item research (~13 items) — prepare full-context options + tradeoffs + recommendations + convert decisions to implementation slices | `docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_E_2026_05_16.md` | ~26-39 iters |
| **F** | `run-f-integrations` | External integrations — Channel Relay full (Telegram/Slack/Discord/WhatsApp/Signal/Email) + iMessage Pro drivers + Apple Events / Computer Use polish + OpenClaw multi-claw MAS (J4) + Calendar/Mail/Reminders/Spotlight integration | `docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_F_2026_05_16.md` | weeks |

**File ownership matrix** (avoid conflicts): each prompt's §2 enumerates owned paths. Cross-check before touching any file. If you find work that touches a sibling's path, SKIP and log.

**Strict scope boundary** (each prompt's §1.5 — READ EVERY ITERATION): every terminal operates ONLY within its own scope. At §0 victory + queue exhaustion, terminals switch to **continuous self-audit mode** (drift / gap / cut-corner / non-canon detection on own commits only) at 600s cadence. They NEVER bleed into sibling scope — not at victory, not "to be helpful", not "because it's only 2 lines". Terminal C is the only exception: it IS the cross-terminal audit terminal — but still read-only across siblings; never modifies sibling code.

---

## §2. Universal-compat — Claude Code vs Codex

The prompts are written runtime-agnostic. Here are the platform-specific equivalents:

| Concept | Claude Code | Codex |
|---|---|---|
| Loop scheduling | `ScheduleWakeup(delaySeconds: 120, prompt: "<body>", reason: "...")` | Re-prompt manually after commit OR use Codex's `--watch`/scheduled-task mechanism if available. If neither: post a follow-up message with the same prompt body. |
| Sub-agents (parallel) | `Agent` tool with `isolation: "worktree"`; multi-Agent calls in one message | Codex doesn't have isolated worktree sub-agents; do the work sequentially OR open another Codex session. |
| Background tasks | `Bash` tool with `run_in_background: true` + Monitor | Codex `bash` shell + standard `&` + `wait` semantics |
| Shell | `Bash` tool | Codex's `bash` |
| File read/write | `Read`/`Edit`/`Write` tools | Codex's editor commands (file ops) |
| Web fetch | `WebFetch`/`WebSearch` | Codex's web search if enabled |
| Commit trailer | `Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>` | `Co-Authored-By: Codex (OpenAI) <codex@openai.com>` OR omit if uncertain |
| Invocation | `/loop $(cat <path-to-prompt> \| sed -n '/^## §1/,$p') every 2 minutes` | Paste prompt body verbatim into Codex terminal; manually re-paste after each commit cycle |

---

## §3. How to invoke each terminal (copy-paste)

**Critical architectural note:** every terminal must run in its **own `git worktree`** to avoid branch-state races. Terminal A owns the main checkout `/Users/jojo/Downloads/Epistemos`. B/C/D/E/F each get sibling worktrees at `/Users/jojo/Downloads/Epistemos-runX/`.

### §3.0 First-time worktree setup (run ONCE by user, outside the loop)

Run this whole block ONCE to create all 5 sibling worktrees. Skip lines for terminals you don't plan to launch.

```bash
cd /Users/jojo/Downloads/Epistemos

# Terminal A: stays in main checkout (no worktree to create)

# Terminal B (post-V1 + research):
git worktree add /Users/jojo/Downloads/Epistemos-runB run-b-post-v1-research  # branch already exists per current session

# Terminal C (audit):
git worktree add /Users/jojo/Downloads/Epistemos-runC -b run-c-audit origin/codex/research-snapshot-2026-05-08

# Terminal D (providers):
git worktree add /Users/jojo/Downloads/Epistemos-runD -b run-d-providers origin/codex/research-snapshot-2026-05-08

# Terminal E (decisions):
git worktree add /Users/jojo/Downloads/Epistemos-runE -b run-e-decisions origin/codex/research-snapshot-2026-05-08

# Terminal F (integrations):
git worktree add /Users/jojo/Downloads/Epistemos-runF -b run-f-integrations origin/codex/research-snapshot-2026-05-08

# Push new branches:
(cd /Users/jojo/Downloads/Epistemos-runC && git push -u origin run-c-audit)
(cd /Users/jojo/Downloads/Epistemos-runD && git push -u origin run-d-providers)
(cd /Users/jojo/Downloads/Epistemos-runE && git push -u origin run-e-decisions)
(cd /Users/jojo/Downloads/Epistemos-runF && git push -u origin run-f-integrations)

# Verify all worktrees registered:
cd /Users/jojo/Downloads/Epistemos && git worktree list
```

### Terminal A — V1 Ship Driver (Claude Code OR Codex)

Stays in `/Users/jojo/Downloads/Epistemos` on `codex/research-snapshot-2026-05-08`.

**Claude Code:**
```bash
cd /Users/jojo/Downloads/Epistemos
git fetch origin
/loop $(cat docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_A_2026_05_16.md | sed -n '/^## §1/,$p') every 2 minutes
```

**Codex:**
```bash
cd /Users/jojo/Downloads/Epistemos
git fetch origin
# Paste body of docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_A_2026_05_16.md starting at §1
# After each commit, re-prompt with the same body (or use Codex's scheduled-task feature)
```

### Terminal B — Post-V1 + Research (in worktree)

```bash
cd /Users/jojo/Downloads/Epistemos-runB
git fetch origin
# Claude Code:
/loop $(cat docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_B_2026_05_16.md | sed -n '/^## §1/,$p') every 2 minutes
# Codex: paste body verbatim starting at §1
```

### Terminal C — Audit + Verification (in worktree)

```bash
cd /Users/jojo/Downloads/Epistemos-runC
git fetch --all
# Claude Code:
/loop $(cat docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_C_2026_05_16.md | sed -n '/^## §1/,$p') every 2 minutes
# Codex: paste body verbatim
```

### Terminal D — Providers + Tools + MCP (in worktree)

```bash
cd /Users/jojo/Downloads/Epistemos-runD
git fetch origin
# Claude Code:
/loop $(cat docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_D_2026_05_16.md | sed -n '/^## §1/,$p') every 2 minutes
# Codex: paste body verbatim
```

### Terminal E — User-Decision Research (in worktree)

```bash
cd /Users/jojo/Downloads/Epistemos-runE
git fetch origin
# Claude Code:
/loop $(cat docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_E_2026_05_16.md | sed -n '/^## §1/,$p') every 2 minutes
# Codex: paste body verbatim
```

### Terminal F — External Integrations (in worktree)

```bash
cd /Users/jojo/Downloads/Epistemos-runF
git fetch origin
# Claude Code:
/loop $(cat docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_F_2026_05_16.md | sed -n '/^## §1/,$p') every 2 minutes
# Codex: paste body verbatim
```

---

## §3.5 Worktree benefits + caveats

**Benefits of worktree separation:**
- No branch-state races — each terminal locked to its own branch via the worktree
- `git checkout` in one worktree can't disturb another
- Each terminal's working tree (untracked files, in-flight mods) is isolated
- Push from any worktree → all worktrees see the change via `git fetch`
- Single `.git/` directory shared — disk-efficient (no duplicate object store)

**Caveats:**
- The same branch can only be checked out in ONE worktree at a time (git enforces). This is what we want — each terminal owns its branch.
- If a terminal's worktree path is deleted manually, run `git worktree prune` to clean refs
- `git worktree remove <path>` to cleanly remove a worktree before deleting

**Verify worktrees set up correctly:**
```bash
cd /Users/jojo/Downloads/Epistemos && git worktree list
```
Expected output (with all 5 sibling worktrees):
```
/Users/jojo/Downloads/Epistemos       <SHA> [codex/research-snapshot-2026-05-08]
/Users/jojo/Downloads/Epistemos-runB  <SHA> [run-b-post-v1-research]
/Users/jojo/Downloads/Epistemos-runC  <SHA> [run-c-audit]
/Users/jojo/Downloads/Epistemos-runD  <SHA> [run-d-providers]
/Users/jojo/Downloads/Epistemos-runE  <SHA> [run-e-decisions]
/Users/jojo/Downloads/Epistemos-runF  <SHA> [run-f-integrations]
```

---

## §4. Coordination protocol (all 6 terminals)

1. **Every iteration**, BEFORE picking slice: `git fetch origin` + `git log --all --oneline -10` to see what siblings landed.
2. **File ownership** per each prompt's §2. Skip + log if work touches sibling-owned files.
3. **Shared files** (APPEND-ONLY): `docs/MAS_COMPLETE_FUSION_IMPLEMENTATION_PLAN_2026_05_14.md §8 Implementation Log` · `docs/MASTER_FUSION_NO_COMPROMISE_2026_05_13.md` · `docs/HERMES_AGENT_CORE_2_0_DESIGN_2026_05_15.md` · `docs/NEW_SESSION_HANDOFF_2026_05_15.md` · `docs/legal/licenses.md`.
4. **Periodic merge**: every 20 iters or phase boundary, merge sibling branches into yours.
5. **Eventual downmerge to main work branch**: when your branch is phase-complete + tests green, surface to user for merge into `codex/research-snapshot-2026-05-08`. Do NOT auto-merge across branches.

---

## §5. Cargo + xcodebuild baselines (verify on first iter)

After the 2026-05-16 wipe:
- `agent_core/target` rebuilt to 2.4 GB during loop run iter verifications
- `.spm-cache` gone; will resolve on next Xcode launch
- `.build` gone; will rebuild
- Cargo baseline: **1190 lib tests** (verify on first iter via `cargo test --manifest-path agent_core/Cargo.toml --lib --quiet 2>&1 | tail -3`)
- Xcodebuild: first full rebuild expected to take 15-30 min

---

## §6. Stopping any terminal

Per each prompt's §10 wind-down conditions. To force-stop manually:
- Claude Code: omit ScheduleWakeup; terminal exits naturally
- Codex: end session; commits already pushed to origin remain canonical

To resume: re-invoke the same prompt; the §3 state-check ritual reconstructs context from git state.

---

## §7. Conflict-resolution decision tree

If two terminals commit conflicting changes to a shared file:
1. The first-pushed commit wins (origin source of truth).
2. The losing terminal: `git pull --rebase` + manually resolve conflict + re-commit + push.
3. If conflict is unresolvable: surface to user. Do NOT force-merge.

Lockstep rules (from `MAS_COMPLETE_FUSION §0`):
- ResidencyLevel changes: doctrine + code together
- ACS changes: doctrine + code together
- New Cargo workspace crates: doctrine + code together + `docs/legal/licenses.md`
- XPC entitlement changes: `.entitlements` + Info.plist + provisioning profile + MAS_APP_REVIEW_NOTES + codesign verify test

---

## §8. Memory state at run start (2026-05-16)

After the wipe, before first terminal fires:
- Cargo baseline: 1190 lib (verify on first iter)
- HEAD: `ab89b0cc8` on `codex/research-snapshot-2026-05-08`, pushed to origin + main
- App state: virgin (Application Support/Epistemos/ empty except Models/; no SwiftData, no event-store, no search index)
- Models cached: 96 GB MLX/HF snapshots intact
- Keychain: API keys intact
- Recovery snapshots: 217 GB intact (rollback safety net)
- External doctrine: `~/Documents/Epistemos-QuickCapture/` intact (10 files)
- Free disk: 227 GB

---

*Universal invocation guide for 6 parallel terminals (A-F). Works in Claude Code + Codex. Coordinate via git fetch + file ownership + lockstep rules. User retains agency for stop, merge, push, App Store submission.*
