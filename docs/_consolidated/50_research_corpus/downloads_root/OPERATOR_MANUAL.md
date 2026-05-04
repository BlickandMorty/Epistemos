# EPISTEMOS OMEGA — OPERATOR MANUAL
# The 3 Prompts You Need (and nothing else)

## Setup (do this ONCE, never again)

Drop the omega-build-pack folder contents into your Epistemos project root:

```bash
cd /path/to/Epistemos

# Copy these files (adjust source path to wherever you downloaded them)
cp ~/Downloads/omega-build-pack/CLAUDE.md ./docs/agent-system/CLAUDE_OMEGA.md
cp ~/Downloads/omega-build-pack/.claude/settings.json ./.claude/settings.json
cp ~/Downloads/omega-build-pack/.claude/context-essentials.txt ./.claude/context-essentials.txt
cp ~/Downloads/omega-build-pack/docs/AGENT_PROGRESS.md ./docs/AGENT_PROGRESS.md
mkdir -p docs/sprint-sessions scripts/verify reference-code
cp ~/Downloads/omega-build-pack/docs/sprint-sessions/sprint-omega-1-foundation.md ./docs/sprint-sessions/
cp ~/Downloads/omega-build-pack/scripts/verify/omega_verify.sh ./scripts/verify/
chmod +x ./scripts/verify/omega_verify.sh
cp ~/Downloads/omega-build-pack/reference-code/* ./reference-code/
```

Verify it landed:
```bash
ls CLAUDE.md .claude/settings.json .claude/context-essentials.txt docs/AGENT_PROGRESS.md docs/sprint-sessions/sprint-omega-1-foundation.md scripts/verify/omega_verify.sh reference-code/*.rs
```

That's it. You never do this again.

---

## THE 3 PROMPTS

### PROMPT 1: "FIRST SESSION" (start building)

Use this the VERY FIRST TIME you open Claude Code or Codex on this project.
Both get the same prompt. Copy-paste it exactly.

```
Read these files in order, do not skip any:
1. CLAUDE.md
2. docs/AGENT_PROGRESS.md
3. docs/sprint-sessions/sprint-omega-1-foundation.md
4. .claude/context-essentials.txt

Then merge the Omega upgrades into the project:
- Read docs/agent-system/CLAUDE_OMEGA.md and MERGE its new sections into the existing CLAUDE.md (keep all existing rules, add new Omega sections, stay under 200 lines)
- Verify .claude/settings.json has the compact hook, Stop hook, and write-checking hooks
- Make scripts/verify/omega_verify.sh executable: chmod +x scripts/verify/omega_verify.sh

Then run: ./scripts/verify/omega_verify.sh --quick

If that passes, begin Sprint Omega-1. Execute tasks 1-6 from docs/sprint-sessions/sprint-omega-1-foundation.md in order. After each task run: ./scripts/verify/omega_verify.sh --task N (where N is the task number). Do not skip verification. Reference code for each module is in the reference-code/ folder — read it and adapt to the actual crate structure.

Update docs/AGENT_PROGRESS.md with checkmarks after each task passes verification.
```

### PROMPT 2: "CONTINUE" (resume after stopping mid-work)

Use this EVERY TIME you start a new session after pausing.
Works for both Claude Code and Codex. Copy-paste it exactly.

```
Read these files in order:
1. CLAUDE.md
2. .claude/context-essentials.txt
3. docs/AGENT_PROGRESS.md
4. docs/sprint-sessions/sprint-omega-1-foundation.md

Find the first unchecked task in AGENT_PROGRESS.md. That is where we left off.
Continue from that task. After each task run: ./scripts/verify/omega_verify.sh --task N
Update AGENT_PROGRESS.md with checkmarks after each task passes.

If all Sprint Omega-1 tasks are done, run: ./scripts/verify/omega_verify.sh --recursive
This does 3 consecutive clean passes. Report the result in AGENT_PROGRESS.md.
```

### PROMPT 3: "VERIFY EVERYTHING" (audit what was built)

Use this when you want to CHECK work without building more.
Best for Codex (deeper verification) but works for Claude Code too.

```
Read these files in order:
1. CLAUDE.md
2. .claude/context-essentials.txt
3. docs/AGENT_PROGRESS.md
4. docs/sprint-sessions/sprint-omega-1-foundation.md

Do NOT build anything new. Your job is to VERIFY what exists.

Run: ./scripts/verify/omega_verify.sh --recursive

This executes 7 verification layers across 3 consecutive passes:
- Layer 0: Project structure intact
- Layer 1: 9 non-negotiable constraints (no sidecar, no fake SDKs, Keychain, thinking blocks, streaming, etc.)
- Layer 2: 30+ required files exist with minimum line counts + 40+ critical patterns in correct files
- Layer 3: All Rust crates compile and pass tests + Swift builds + focused agent tests pass
- Layer 4: UniFFI bridge chain, tool execution chain, local agent chain all wired end-to-end
- Layer 5: Runtime health (Python, Hermes, MCP, app binary)

If any pass fails, report EXACTLY what failed and suggest the fix.
If all 3 passes are clean, update AGENT_PROGRESS.md with the verification result and date.

Also manually inspect:
- Are the 4 new Rust modules (prompt_caching.rs, compaction.rs, security.rs, think.rs) wired into agent_core/src/lib.rs?
- Does claude.rs actually call prompt_caching functions?
- Does agent_loop.rs actually call security functions?
- Does the tool registry actually register the think tool?
- Are there any TODO/FIXME/stub functions that claim to be done?

Report findings honestly. Do not trust prior green claims.
```

---

## WHEN TO USE WHICH PROMPT

| Situation | Prompt | Who |
|---|---|---|
| First time ever starting this work | PROMPT 1 | Claude Code or Codex |
| Resuming after closing a session | PROMPT 2 | Claude Code or Codex |
| Checking if the build is actually correct | PROMPT 3 | Codex (preferred) or Claude Code |
| Claude Code built something, want Codex to verify | PROMPT 3 | Codex |
| Codex found issues, want Claude Code to fix | PROMPT 2 | Claude Code |
| Starting a brand new sprint (Omega-2, etc.) | PROMPT 2 | Either (it auto-detects the next sprint) |

## THE TYPICAL WORKFLOW

1. Open Claude Code → paste PROMPT 1 → it merges files and starts building Sprint Omega-1
2. It finishes tasks 1-3, you need to stop → just close the session
3. Later, open Claude Code (or Codex) → paste PROMPT 2 → it reads AGENT_PROGRESS.md, sees tasks 1-3 are done, continues from task 4
4. It finishes all 6 tasks → you want to verify → open Codex → paste PROMPT 3 → it runs the 3-pass recursive check
5. Codex finds an issue → open Claude Code → paste PROMPT 2 → it reads the progress, sees the issue note, fixes it
6. Repeat until clean

## WHY THIS WORKS

The magic is in 4 files that persist across sessions:

**CLAUDE.md** — Claude Code auto-reads this on every session start. It contains all the rules, constraints, and file map. You never need to re-explain the project.

**.claude/settings.json** — Hooks fire automatically. The compact hook re-injects context-essentials.txt after every context compaction (which happens silently in long sessions). The write hooks catch banned patterns in real-time. The Stop hook reminds the agent to verify before claiming done.

**docs/AGENT_PROGRESS.md** — This is the state that carries across sessions. PROMPT 2 reads it to know where to resume. Every task gets a checkmark only after verification passes. This is what prevents "starting over" syndrome.

**scripts/verify/omega_verify.sh** — This is the enforcement. Not a document describing what to check — an actual script that checks. It greps the codebase for violations, runs tests, traces integration chains, and reports pass/fail with evidence. The `--recursive` mode runs 3 consecutive passes with automatic reset on failure.

## WHAT IF THE AGENT GOES OFF-SCRIPT?

If Claude Code or Codex starts doing something you didn't ask for, or ignoring the sprint file, paste this:

```
STOP. Re-read docs/AGENT_PROGRESS.md and docs/sprint-sessions/sprint-omega-1-foundation.md. 
Find the first unchecked task. Do ONLY that task. Run verification after. Nothing else.
```

## WHAT IF YOU WANT TO ADD MORE SPRINTS LATER?

When Sprint Omega-1 is done and verified, you'll want Sprint Omega-2 (Hermes subprocess). The agent already knows what Omega-2 contains because the sprint file has a preview at the bottom. Use PROMPT 2 — the agent will see all Omega-1 tasks are checked, read the Omega-2 preview, and either create the sprint file or ask you to create one.

For Sprint Omega-3 (AXorcist computer use) and Omega-4 (skills + memory + polish), the same pattern applies. PROMPT 2 always works because it reads AGENT_PROGRESS.md to find the next unchecked item.

## EMERGENCY: IF EVERYTHING SEEMS BROKEN

```bash
# Verify the project is intact
./scripts/verify/omega_verify.sh --quick

# If that fails, check git
git status
git log --oneline -5

# If the agent broke something, revert
git stash  # or git checkout -- .

# Then re-paste PROMPT 2 to resume from the last verified state
```
