# Multi-Session Coordination Protocol

> **Index status**: CANONICAL-OPERATIONAL — Cross-session coordination; already in _consolidated.
> Classified in [`docs/_INDEX.md §14`](_INDEX.md). Copy in `docs/_consolidated/30_canonical_operational/`.



Authored 2026-04-27 to answer: "I want this chat dedicated to
critiquing Claude's work; how should I run building sessions in
parallel and have you live-check / nudge them?"

This doc captures my actual capabilities, recommends an architecture,
and lists concrete commands you can paste.

---

## What this session (the "critique session") can and can't do

| Capability | Yes / No | Notes |
| ---------- | -------- | ----- |
| Spawn background subagents that complete async | ✅ | `Agent` tool with `run_in_background: true`. Each subagent is one-shot — no long-running REPL. |
| Receive notifications when those subagents complete | ✅ | I get a `<task-notification>` system-reminder. |
| Run scheduled tasks that wake me up later | ✅ | `mcp__scheduled-tasks__create_scheduled_task` (one-shot) or cron-style recurring. |
| Read git history + diffs at any time | ✅ | Bash + Grep tools. |
| Directly inject prompts into OTHER Claude Code terminals | ❌ | Each Claude Code session is a separate process. I can't push messages to them. |
| Watch another terminal's stdout in real time | ❌ | Same isolation. The user is the bridge. |
| Push notifications to your Mac | ✅ | `PushNotification` tool — useful when a critique flags a blocker. |

So: **I can dispatch subagents and do scheduled critique passes, but
I cannot directly drive parallel Claude Code terminals.** The user
is the message bus between sessions.

---

## Recommended architecture

Three coordinated surfaces:

```
┌────────────────────────────────────────────────────────────┐
│  THIS SESSION  ←── critique + audit + nudge generation     │
│  (the "Conductor")                                         │
└──────────────────────────┬─────────────────────────────────┘
                           │ reads commits/PRs
                           │ posts critique to docs/CRITIQUE_LOG.md
                           ▼
┌────────────────────────────────────────────────────────────┐
│  TERMINAL 1, 2, 3 …  ←── building work                     │
│  (the "Builders")                                          │
│  Each opens with a prompt from docs/plan/prompts/          │
└────────────────────────────────────────────────────────────┘
```

### Builder sessions

You open one Claude Code terminal per task. The opening prompt for
each is one of the files in `docs/plan/prompts/`:

```bash
# Terminal 1 — Phase 0 ship blockers
cd /Users/jojo/Downloads/Epistemos
cat docs/plan/prompts/phase0_ship_blockers.md | pbcopy
# then paste into a new Claude Code session

# Terminal 2 — W9.25 grammar masking wire-up
cat docs/plan/prompts/W9.25_grammar_masking.md | pbcopy
# then paste into a second Claude Code session
```

Every prompt in `docs/plan/prompts/` is bound by:
- The contract in `docs/plan/00_AUTHORITY_AND_ANTI_DRIFT.md`
- The 14 non-negotiables in `docs/plan/01_DOCTRINE.md` (incl. #14 = no orphan scaffolding)
- The WRV gate proof requirement in §4.7
- The Pro/MAS gating in `docs/plan/02_BUILD_MATRIX.md`

So each Builder session is forced to read the doctrine, declare a
WRV plan upfront, and prove the WRV after implementation.

### Conductor session (this one)

This session does no building work. Its only jobs are:

1. **Periodic critique passes** — review recent commits, identify
   WRV violations, scaffolding-without-wire, drift from doctrine,
   Pro/MAS bleed.
2. **Append findings** to `docs/CRITIQUE_LOG.md` with a stable format
   the Builder sessions can read.
3. **Spawn deep-investigation subagents** when a commit needs
   inspection too detailed for inline review.

You drive the Conductor by either:
- Pinging me explicitly: "review the last 5 commits"
- Using `/loop` so I self-pace critique passes
- Setting up a scheduled task (see below)

---

## Critique loop — three modes

### Mode A: on-demand (simplest)

You type into this terminal: `review last N commits` (or any
variant). I run `git log --oneline -N`, `git show <sha>` per
commit, write critique to `docs/CRITIQUE_LOG.md`, summarize key
findings inline. No automation needed.

### Mode B: dynamic /loop pacing (medium)

You start a `/loop` here with no interval. I self-pace using
`ScheduleWakeup` — typically every 20–30 min I wake up, run a
critique pass, append findings, and reschedule. You can interrupt
any time. To start:

```
/loop critique recent commits and append findings to docs/CRITIQUE_LOG.md
```

I'll then auto-pace and you don't have to do anything.

### Mode C: cron-style scheduled task (most autonomous)

I create a scheduled task that wakes me on a fixed cadence (e.g.
every 30 min). The task carries the same critique prompt every
time. To start:

```
schedule a critique pass every 30 minutes
```

I'll create the task and confirm. The task survives even if you
close this terminal — it'll wake a fresh session at the next firing.

---

## Critique format (what gets appended to docs/CRITIQUE_LOG.md)

Each pass appends a dated section. Stable format so Builder sessions
can grep for their own commits:

```markdown
## 2026-04-27 14:30 — pass #7

### Commits reviewed
- `abc1234` ui(quick-capture): add structured-preview chips
- `def5678` w9.25(grammar): wire MLXStructuredGenerator

### WRV violations found
- `def5678`: no call site for MLXStructuredGenerator. Spec says
  ConstrainedDecodingService.setGenerator must be called from
  AppBootstrap. **Fix needed before merge.**

### Scaffolding-without-wire
- (none this pass)

### Pro/MAS bleed
- `abc1234`: VaultSelectorView placement assumes Pro-only
  ModelVaults section. Verify MAS build gates the row.

### Doctrine drift
- (none)

### Recommended next steps
1. Builder of `def5678`: add the AppBootstrap.shared.constrainedDecoding.setGenerator(MLXStructuredGenerator(...)) line.
2. Builder of `abc1234`: add #if !(EPISTEMOS_APP_STORE || MAS_SANDBOX) guard around the ModelVaults adjacency check.
```

Builder sessions watch this log via:

```bash
tail -f docs/CRITIQUE_LOG.md
```

…or just `grep <their-commit-sha> docs/CRITIQUE_LOG.md` when they
land a commit.

---

## My recommended setup for you (for the next ~weeks of building)

1. **Open this Conductor terminal here.** Don't close it.
2. **Open 2–3 Builder terminals**, each with one prompt from
   `docs/plan/prompts/`. Phase 0 first (ship blockers), then
   pick Bucket A items from `docs/V1_5_IMPLEMENTATION_TRACKER.md`.
3. **In this terminal, type**: `start critique loop, every 30 min`
   I'll set up Mode C (scheduled task) and confirm.
4. **Each Builder, when it lands a commit**, runs `cat docs/CRITIQUE_LOG.md | tail -100` to see if its work has been flagged yet (next critique pass picks it up within 30 min).
5. **You ferry blockers manually** — when I flag a blocker, you
   paste my "Recommended next steps" line into the relevant Builder
   terminal.
6. **For deep audits** (e.g., "is the W9.21 honest-FFI rewrite
   really sound?"), ping me here with "spawn an audit agent for X".
   I dispatch a dedicated subagent that returns a deep report.

---

## Pitfalls to avoid

- **Don't run critique + building in the same terminal.** They'll
  step on each other's context. Conductor stays Conductor.
- **Don't have two Builders touch the same files.** Use the
  `docs/PARALLEL_SESSION_PROMPT.md` lane assignments (Lane A UI,
  Lane B JS, Lane C Intents) so they don't collide.
- **Don't skip the WRV proof** in PR descriptions. The Conductor
  will catch it next pass and flag the commit.
- **Don't commit the Conductor's CRITIQUE_LOG.md edits as part of
  Builder commits.** That log is its own thing — let the Conductor
  own it.

---

## Quick-paste commands

```bash
# In any Builder terminal — see open issues against your work
grep -A 20 "$(git rev-parse --short HEAD)" docs/CRITIQUE_LOG.md

# In this Conductor terminal — start the critique loop
# (you say to me): "start critique loop every 30 min"

# In any Builder terminal — push a request for human review
# (echo a marker in your commit message)
git commit -m "feat(W9.x): land foo bar
NEEDS-AUDIT: this touches the FFI boundary; please deep-review"
# I'll see "NEEDS-AUDIT" markers in the next pass and prioritize.
```

---

## When to switch modes

- **Mode A (on-demand)**: when you have ≤1 active builder and want
  fast, focused review.
- **Mode B (/loop)**: when you have 2–3 active builders, want
  continuous review, but might interrupt me to ask questions.
- **Mode C (cron)**: when you have ≥3 active builders, are stepping
  away from the Mac, and want truly autonomous critique while you
  do other work.

---

## TL;DR

1. This session is the Conductor; never builds.
2. New Claude Code terminals are Builders; each takes a
   `docs/plan/prompts/<task>.md` file.
3. Tell me to start the critique loop. I'll do periodic passes and
   append findings to `docs/CRITIQUE_LOG.md`.
4. You ferry blockers from the log to the Builders manually
   (Claude can't message Claude across processes — yet).
5. For deep audits, ping me with "spawn audit agent for X" and I'll
   dispatch a focused subagent.
