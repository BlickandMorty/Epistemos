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

### Terminal A — V1 Ship Driver (Claude Code OR Codex)

**Claude Code:**
```bash
cd /Users/jojo/Downloads/Epistemos
git checkout codex/research-snapshot-2026-05-08
git pull
/loop $(cat docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_A_2026_05_16.md | sed -n '/^## §1/,$p') every 2 minutes
```

**Codex:**
```bash
cd /Users/jojo/Downloads/Epistemos
git checkout codex/research-snapshot-2026-05-08
git pull
# Paste body of docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_A_2026_05_16.md starting at §1
# After each commit, re-prompt with the same body (or use Codex's scheduled-task feature)
```

### Terminal B — Post-V1 + Research

**Setup (run once):**
```bash
cd /Users/jojo/Downloads/Epistemos
git fetch origin
git checkout codex/research-snapshot-2026-05-08
git pull
git checkout -b run-b-post-v1-research
git push -u origin run-b-post-v1-research
```

**Then invoke (Claude Code):**
```bash
/loop $(cat docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_B_2026_05_16.md | sed -n '/^## §1/,$p') every 2 minutes
```

**Codex:** paste body verbatim starting at §1.

### Terminal C — Audit + Verification

**Setup:**
```bash
git fetch origin
git checkout codex/research-snapshot-2026-05-08
git pull
git checkout -b run-c-audit
git push -u origin run-c-audit
```

**Invoke:**
```bash
# Claude Code
/loop $(cat docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_C_2026_05_16.md | sed -n '/^## §1/,$p') every 2 minutes
# Codex: paste body verbatim
```

### Terminal D — Providers + Tools + MCP

**Setup:**
```bash
git fetch origin
git checkout codex/research-snapshot-2026-05-08
git pull
git checkout -b run-d-providers
git push -u origin run-d-providers
```

**Invoke:**
```bash
# Claude Code
/loop $(cat docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_D_2026_05_16.md | sed -n '/^## §1/,$p') every 2 minutes
# Codex: paste body verbatim
```

### Terminal E — User-Decision Research

**Setup:**
```bash
git fetch origin
git checkout codex/research-snapshot-2026-05-08
git pull
git checkout -b run-e-decisions
git push -u origin run-e-decisions
```

**Invoke:**
```bash
# Claude Code
/loop $(cat docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_E_2026_05_16.md | sed -n '/^## §1/,$p') every 2 minutes
# Codex: paste body verbatim
```

### Terminal F — External Integrations

**Setup:**
```bash
git fetch origin
git checkout codex/research-snapshot-2026-05-08
git pull
git checkout -b run-f-integrations
git push -u origin run-f-integrations
```

**Invoke:**
```bash
# Claude Code
/loop $(cat docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_F_2026_05_16.md | sed -n '/^## §1/,$p') every 2 minutes
# Codex: paste body verbatim
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
