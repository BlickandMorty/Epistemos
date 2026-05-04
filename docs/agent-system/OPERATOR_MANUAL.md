# EPISTEMOS OMEGA — OPERATOR MANUAL

> **Index status**: CANONICAL-RESEARCH — Agent system architecture (cited from CLAUDE.md). Phase D / K reference.
> Classified in [`docs/_INDEX.md §14`](_INDEX.md). Copy in `docs/_consolidated/20_canonical_research/agent_system/`.


# The 3 Prompts You Need (and nothing else)
# Updated: 2026-03-29 (post Sprint Omega-1 completion)

## Setup (do this ONCE, never again)

Drop the omega-build-pack folder contents into your Epistemos project root:

```bash
cd /path/to/Epistemos

# Copy these files (adjust source path to wherever you downloaded them)
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

### PROMPT 1: "FIRST SESSION" (start building a sprint)

Use this the VERY FIRST TIME you start a new sprint.
Both Claude Code and Codex get the same prompt. Copy-paste it exactly.

```
Read these files in order, do not skip any:
1. CLAUDE.md
2. docs/AGENT_PROGRESS.md
3. docs/sprint-sessions/sprint-omega-1-foundation.md
4. .claude/context-essentials.txt

Pre-flight checks:
- Verify .claude/settings.json has the compact hook, Stop hook, and write-checking hooks
- Run: chmod +x scripts/verify/omega_verify.sh
- Run: ./scripts/verify/omega_verify.sh --quick
- If --quick has failures in Layer 2B that are pre-existing (not related to the current sprint's modules), note them and proceed. Only block on Layer 0-1 failures.

Begin the current sprint. Execute tasks in order from the sprint file. After each task run: ./scripts/verify/omega_verify.sh --task N (where N is the task number). Do not skip verification. Reference code for each module is in the reference-code/ folder — read it and adapt to the actual crate structure.

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

If all current sprint tasks are done, run: ./scripts/verify/omega_verify.sh --recursive
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
| First time starting a sprint | PROMPT 1 | Claude Code or Codex |
| Resuming after closing a session | PROMPT 2 | Claude Code or Codex |
| Checking if the build is actually correct | PROMPT 3 | Codex (preferred) or Claude Code |
| Claude Code built something, want Codex to verify | PROMPT 3 | Codex |
| Codex found issues, want Claude Code to fix | PROMPT 2 | Claude Code |
| Starting a brand new sprint (Omega-2, etc.) | PROMPT 1 | Either (update the sprint file path) |

## THE TYPICAL WORKFLOW

1. Open Claude Code -> paste PROMPT 1 -> it reads files and starts building the current sprint
2. It finishes tasks 1-3, you need to stop -> just close the session
3. Later, open Claude Code (or Codex) -> paste PROMPT 2 -> it reads AGENT_PROGRESS.md, sees tasks 1-3 are done, continues from task 4
4. It finishes all tasks -> you want to verify -> open Codex -> paste PROMPT 3 -> it runs the 3-pass recursive check
5. Codex finds an issue -> open Claude Code -> paste PROMPT 2 -> it reads the progress, sees the issue note, fixes it
6. Repeat until clean

## WHY THIS WORKS

The magic is in 4 files that persist across sessions:

**CLAUDE.md** -- Claude Code auto-reads this on every session start. It contains all the rules, constraints, and file map. You never need to re-explain the project.

**.claude/settings.json** -- Hooks fire automatically. The compact hook re-injects context-essentials.txt after every context compaction (which happens silently in long sessions). The write hooks catch banned patterns in real-time. The Stop hook reminds the agent to verify before claiming done.

**docs/AGENT_PROGRESS.md** -- This is the state that carries across sessions. PROMPT 2 reads it to know where to resume. Every task gets a checkmark only after verification passes. This is what prevents "starting over" syndrome.

**scripts/verify/omega_verify.sh** -- This is the enforcement. Not a document describing what to check -- an actual script that checks. It greps the codebase for violations, runs tests, traces integration chains, and reports pass/fail with evidence. The `--recursive` mode runs 3 consecutive passes with automatic reset on failure.

## VERIFY SCRIPT REFERENCE

```bash
# Quick check (layers 0-2, ~30s)
./scripts/verify/omega_verify.sh --quick

# Single task verification
./scripts/verify/omega_verify.sh --task 1    # verify task N from current sprint

# Full suite (layers 0-5)
./scripts/verify/omega_verify.sh

# 3-pass recursive (production-grade audit)
./scripts/verify/omega_verify.sh --recursive

# Single layer
./scripts/verify/omega_verify.sh --layer 0   # orientation
./scripts/verify/omega_verify.sh --layer 1   # non-negotiable constraints
./scripts/verify/omega_verify.sh --layer 2   # files + patterns
./scripts/verify/omega_verify.sh --layer 3   # compilation + tests
./scripts/verify/omega_verify.sh --layer 4   # integration chains
./scripts/verify/omega_verify.sh --layer 5   # runtime health
```

## KNOWN ISSUES FIXED (2026-03-29)

Three bugs were found and fixed in `omega_verify.sh` during Sprint Omega-1:

1. **`set -euo pipefail` killed script early** -- `grep` returns exit code 1 on no-match, which cascaded through pipefail and aborted the script at Layer 1. Fixed by removing `-e` (failures are handled by check_pass/check_fail, not shell exit codes).

2. **ERE regex `\|` bug** -- 15+ `check_pattern` calls used `\|` which is a literal pipe in Extended Regular Expressions (`grep -E`). The intended alternation operator is just `|`. This caused every pattern-OR check to fail. All fixed to use `|`.

3. **`unsafe_with_safety` integer comparison** -- The `grep -B1 | grep -c` pipeline produced multiline output that broke the `[ "$x" -ge "$y" ]` comparison. Cosmetic warning only, not a blocker.

## WHAT IF THE AGENT GOES OFF-SCRIPT?

If Claude Code or Codex starts doing something you didn't ask for, or ignoring the sprint file, paste this:

```
STOP. Re-read docs/AGENT_PROGRESS.md and the current sprint file.
Find the first unchecked task. Do ONLY that task. Run verification after. Nothing else.
```

## WHAT IF YOU WANT TO ADD MORE SPRINTS LATER?

When a sprint is done and verified, create the next sprint file in `docs/sprint-sessions/` following the same format. The sprint preview at the bottom of each sprint file tells you what comes next:

- Sprint Omega-2: Hermes subprocess bridge (spawn/manage/kill via swift-subprocess + MCP stdio)
- Sprint Omega-3: AXorcist computer use (replace raw AXUIElement with chainable queries)
- Sprint Omega-4: Skills + memory + polish (SKILL.md, progressive memory, cost dashboard)

Use PROMPT 1 with the new sprint file path, or PROMPT 2 (it auto-detects the next unchecked item in AGENT_PROGRESS.md).

## SPRINT STATUS

| Sprint | Status | Date |
|---|---|---|
| Agent-1: The Living Loop | Done | -- |
| Agent-2: Local Agent System | Done | -- |
| Agent-3: MCP + Computer Use | Done | -- |
| Agent-4: Multi-Provider + Polish | Partial | -- |
| **Omega-1: Foundation Integration** | **Done** | **2026-03-29** |
| Omega-2: Hermes Subprocess Bridge | Next | -- |
| Omega-3: AXorcist Computer Use | Planned | -- |
| Omega-4: Skills + Memory + Polish | Planned | -- |

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
