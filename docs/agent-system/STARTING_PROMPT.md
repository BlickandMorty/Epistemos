# EPISTEMOS OMEGA — STARTING PROMPT FOR CLAUDE CODE

> **Index status**: CANONICAL-RESEARCH — Agent system architecture (cited from CLAUDE.md). Phase D / K reference.
> Classified in [`docs/_INDEX.md §14`](_INDEX.md). Copy in `docs/_consolidated/20_canonical_research/agent_system/`.



## Copy-paste this ENTIRE block into Claude Code:

---

I'm upgrading the Epistemos agent system to "Epistemos Omega" — a fused architecture combining the existing Rust living loop (agent_core) with Hermes-agent integration, enhanced security, prompt caching, 4-phase context compaction, and AX-first computer use.

## STEP 1: MERGE THE BUILD PACK INTO THIS PROJECT

I've placed new files in the project. Do these merges carefully:

### CLAUDE.md — MERGE, don't replace
Read the existing `CLAUDE.md` and the new version at `docs/agent-system/CLAUDE_OMEGA.md` (or wherever I placed it). Merge them by:
1. Keep ALL existing constraints, file maps, and build commands
2. ADD the new Omega-specific sections: Hermes subprocess rules, MCP architecture, AXorcist references, new Rust modules (prompt_caching, compaction, security, think tool)
3. ADD the new provider matrix entries and Sprint Omega sections
4. Keep it under 200 lines total — use pointer files for details
5. Verify no existing rule was dropped

### .claude/settings.json — MERGE hooks
Read existing `.claude/settings.json`. Merge by:
1. Keep ALL existing hooks
2. ADD the compact hook (context-essentials re-injection) if not present
3. ADD the Stop hook (verification reminder) if not present
4. Keep existing permissions

### .claude/context-essentials.txt — REPLACE
This file should be replaced with the new version. It's the post-compaction lifeline.

### docs/AGENT_PROGRESS.md — MERGE progress
Read existing progress. Merge by:
1. Keep all existing completed sprint checkmarks
2. ADD the Sprint Omega-1 through Omega-4 sections with unchecked items
3. Preserve all audit notes

### scripts/verify/omega_verify.sh — ADD
Make this executable: `chmod +x scripts/verify/omega_verify.sh`

## STEP 2: VERIFY THE MERGE

Run the quick verification to make sure existing code still works:
```bash
chmod +x scripts/verify/omega_verify.sh
./scripts/verify/omega_verify.sh --quick
```

This checks Layer 0 (project intact), Layer 1 (constraints), and Layer 2 (file existence + patterns). If anything fails, fix the merge before proceeding.

## STEP 3: READ THE SPRINT

Read `docs/sprint-sessions/sprint-omega-1-foundation.md` — this is the active sprint.

## STEP 4: BUILD

Execute all 6 tasks in sprint-omega-1-foundation.md in order. For EACH task:

1. Read the task requirements
2. Check if reference code exists in `reference-code/` folder — use it as a starting point, adapt to fit the actual crate structure
3. Implement the task
4. Run the task-specific verification:
   ```bash
   ./scripts/verify/omega_verify.sh --task N
   ```
   where N is the task number (1-6)
5. Only proceed to the next task if verification passes

## STEP 5: FINAL VERIFICATION

After all 6 tasks, run the full suite:
```bash
./scripts/verify/omega_verify.sh all
```

Then update `docs/AGENT_PROGRESS.md` — mark each completed task with ✅ and today's date.

## KEY RULES (these override everything else)

- Thinking blocks MUST be preserved. `response_blocks.clone()` in agent_loop.rs is sacred.
- Stream every token immediately. No buffering.
- Agent decides termination. Trust stop_reason == "end_turn".
- DispatchQueue.main.async in UniFFI callbacks, NEVER .sync.
- Anthropic has NO Swift SDK. OpenAI has NO Swift SDK. Use raw URLSession.
- API keys in Keychain, never UserDefaults.
- The Hermes subprocess is for ORCHESTRATION, not inference. No sidecar for inference.
- Run verification after EVERY task. Do not skip verification.

---

## FOR SUBSEQUENT SESSIONS

If the sprint isn't done, start the next session with:

```
Read docs/AGENT_PROGRESS.md. Continue Sprint Omega-1 from the first unchecked task. 
Read docs/sprint-sessions/sprint-omega-1-foundation.md for task details.
After each task, run: ./scripts/verify/omega_verify.sh --task N
```

## FOR POST-SPRINT AUDIT

After Sprint Omega-1 completes, run the recursive 3-pass verification:

```
Run ./scripts/verify/omega_verify.sh --recursive
This executes 3 consecutive clean passes. If any pass fails, fix the issue and the counter resets to 0.
Only after 3 clean passes is the sprint verified.
Report the results in docs/AGENT_PROGRESS.md.
```
