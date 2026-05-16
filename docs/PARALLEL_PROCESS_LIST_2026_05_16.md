# Parallel Process List — 2026-05-16

**Purpose:** Living inventory of every process running across the user's machine + cloud, in service of the 6-terminal parallel autonomous loop run. Pin status (running / stopped / scheduled / pending), where to start/stop each, memory cost.

**Status:** LIVING — update when processes start/stop. Cross-reference: `docs/PARALLEL_FLOW_DOCTRINE_2026_05_16.md`.

---

## §1. Active local processes (M2 Pro 16 GB)

### 1a. Terminal sessions (autonomous loop drivers)

| # | Terminal | Worktree path | Branch | Process | Memory | Status |
|---|---|---|---|---|---|---|
| 1 | A — V1 ship | `/Users/jojo/Downloads/Epistemos` | `codex/research-snapshot-2026-05-08` | Claude Code or Codex | 1.5-2 GB | running |
| 2 | B — post-V1 + research | `/Users/jojo/Downloads/Epistemos-runB` | `run-b-post-v1-research` | Claude Code or Codex | 1.5-2 GB | running |
| 3 | C — audit | `/Users/jojo/Downloads/Epistemos-runC` | `run-c-audit` | Claude Code or Codex | 1.5-2 GB | running |
| 4 | D — providers | `/Users/jojo/Downloads/Epistemos-runD` | `run-d-providers` | Claude Code or Codex | 1.5-2 GB | running |
| 5 | E — decisions | `/Users/jojo/Downloads/Epistemos-runE` | `run-e-decisions` | Claude Code or Codex | 1.5-2 GB | running |
| 6 | F — integrations | `/Users/jojo/Downloads/Epistemos-runF` | `run-f-integrations` | Claude Code or Codex | 1.5-2 GB | running |

**Total terminal memory:** ~9-12 GB at peak.

### 1b. Background build watchers (optional)

| Process | Path | Memory | Start | Stop |
|---|---|---|---|---|
| `cargo-watch` on Terminal A | `cd /Users/jojo/Downloads/Epistemos && cargo watch -x build` | 500MB-1GB | one-time install: `cargo install cargo-watch` then run command | Ctrl+C |
| `cargo-watch` on B/C/D/E/F | same command in respective worktree | 500MB-1GB each | (skip these; too much memory cost on 16GB) | — |

**Recommendation:** only run one `cargo-watch` (Terminal A's worktree). Others share `.git/` so incremental compilation benefits propagate via cargo cache.

### 1c. Other potential local processes

| Process | Purpose | Memory | Recommended? |
|---|---|---|---|
| Xcode (when building) | Build Pro + MAS bundles | 4-6 GB | only when iterating UI |
| MLX inference (active) | Local agent for narrow tasks (formatting · doc proofing) | 4-12 GB | on-demand only; unload when done |
| Aider / Cursor / Cline | Other coding agents | 500MB-3GB each | only if specific narrow task |
| Browser (Chrome/Safari) | Heavy research tabs (Claude.ai · Perplexity Pro · GPT browser) | 2-4 GB | yes — offloads compute to cloud |

### 1d. macOS native processes (overhead)

- macOS kernel + window server + helper processes: ~2 GB baseline
- Spotlight indexing: occasional spikes during heavy file changes (deferred to night)
- mds + mdsworker: background indexing

---

## §2. Cloud / external processes

### 2a. GitHub Actions (free tier — should not require paid plan)

| Workflow | Trigger | Cost | Status |
|---|---|---|---|
| `.github/workflows/ci.yml` | push/PR to main | free tier | active |
| `.github/workflows/ci-parallel-branches.yml` | push/PR to run-* branches + codex | free tier | active (new 2026-05-16) |
| `.github/workflows/drift-detection.yml` | every 6h cron + push to main | free tier | active (new 2026-05-16) |
| `.github/workflows/lint.yml` | push | free tier | active |
| `.github/workflows/release.yml` | push of `v[0-9]*` tags only | free tier | active (defensive guard added 2026-05-16) |

**GitHub Actions free tier on private repos:** 2,000 min/month. macos-15 runners count 10× (each minute = 10 min from quota). Watch for high-cost workflows.

### 2b. Browser tabs (compute-offloaded research)

- Claude.ai web tab — heavy reasoning research
- Perplexity Pro tab — fact-finding + citation
- GPT-5 / o1-pro browser tab — architecture review
- Codex CLI in browser (if used) — secondary coding agent

Cost: minimal local memory (per-tab ~50-200 MB).

### 2c. Apple Developer Program

- **Active** (confirmed 2026-05-16)
- Enables App Store Connect submission (Phase E.3) + Developer ID signing (Phase G.2) + Notarization (Phase G.4)

---

## §3. Scheduled / cron tasks

| Job | Cadence | Where | Status |
|---|---|---|---|
| Each terminal's loop iter | every 120-300s (per terminal's `ScheduleWakeup` or cron) | Claude Code internal scheduling | running |
| `drift-detection.yml` | every 6h | GitHub Actions | active |
| (Future) nightly `cargo clean && cargo build --release` | nightly | launchd | not set up |

---

## §4. Start / stop commands

### Start a sibling terminal (after worktree setup)
```bash
# Terminal C (audit) example
cd /Users/jojo/Downloads/Epistemos-runC
git fetch --all
/loop $(cat docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_C_2026_05_16.md | sed -n '/^## §1/,$p') every 3 minutes
```

### Stop a terminal cleanly
- Send Ctrl+C in that terminal session
- Each terminal's own `ScheduleWakeup` chain ends naturally on next iter

### Force-stop all parallel work (emergency)
```bash
# From any terminal:
touch /Users/jojo/Downloads/Epistemos-runB/STOP
touch /Users/jojo/Downloads/Epistemos-runC/STOP
touch /Users/jojo/Downloads/Epistemos-runD/STOP
touch /Users/jojo/Downloads/Epistemos-runE/STOP
touch /Users/jojo/Downloads/Epistemos-runF/STOP
# (Each terminal's §3.0 reading order checks for STOP and exits if present)
```

Terminal A's emergency stop in `/Users/jojo/Downloads/Epistemos/STOP`.

### Start cargo-watch (recommended one-time)
```bash
cargo install cargo-watch
cd /Users/jojo/Downloads/Epistemos
cargo watch -x build
# (background process; runs until Ctrl+C)
```

---

## §5. Process monitoring

### Check terminal status (which is running)
```bash
ps aux | grep -E "(claude-code|codex)" | grep -v grep
```

### Check git worktree state
```bash
cd /Users/jojo/Downloads/Epistemos && git worktree list
```

### Check disk usage
```bash
du -sh /Users/jojo/Downloads/Epistemos /Users/jojo/Downloads/Epistemos-run*
```

### Check memory pressure
```bash
vm_stat | head -10
top -l 1 -s 0 | head -20
```

### Check GitHub Actions runs
```bash
gh run list --limit 20  # most recent across all workflows
gh run list --branch run-c-audit --limit 5  # per-branch
```

---

## §6. Resource budget (M2 Pro 16 GB practical ceiling)

| Component | Memory | Notes |
|---|---|---|
| 6 Claude Code terminals (peak) | ~10-12 GB | dominant |
| macOS overhead | ~2 GB | baseline |
| Xcode (when building) | 4-6 GB | only run during builds |
| 1 cargo-watch (Terminal A) | ~1 GB | continuous |
| Browser (2-4 tabs) | ~2-3 GB | research |
| **Theoretical max** | **~22-28 GB** | swaps heavily on 16 GB |

**Practical max:** 6 terminals + 1 cargo-watch + 2-3 browser tabs + occasional Xcode. Beyond that, beachballs.

If pushing the limit:
- Drop one terminal (e.g., F if not actively integrating channels)
- Stop cargo-watch when not actively iterating
- Close browser tabs not in active use

---

## §7. Process inventory updates

Update this doc when:
- A new terminal is launched / stopped
- A new background process is added / removed
- A new GitHub Actions workflow is added
- Hardware constraints change (e.g., user upgrades to M3 Max 64 GB)

Per `PARALLEL_FLOW_DOCTRINE §5 lockstep rule 5`: when a process changes, the same commit should update this doc.

---

*Living inventory. Owner: Terminal C primary; all terminals append when starting/stopping side processes.*
