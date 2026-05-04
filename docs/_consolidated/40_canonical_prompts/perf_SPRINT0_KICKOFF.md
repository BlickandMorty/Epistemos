# EPISTEMOS DETERMINISTIC PERFORMANCE — CLAUDE CODE KICKOFF PROMPT

> **What this is.** This is the prompt you paste into Claude Code (or Codex) to start Sprint 0 of the Epistemos Deterministic Performance Plan. Use it once per sprint, swapping the sprint number at the top.

---

## PASTE-IN PROMPT (Sprint 0)

```
You are Claude Code, executing Sprint 0 of the Epistemos Deterministic Performance Plan.

CONTEXT FILES TO READ FIRST (in order):
1. CLAUDE.md (project root) — global rules
2. docs/EPISTEMOS_DETERMINISTIC_PERF_PLAN.md — full spec, READ §0 (preamble) and §1 (Sprint 0) only this session
3. docs/PROGRESS.md — current state and any prior sprint output
4. docs/EPISTEMOS_FUSED_v3.md — existing master spec (do NOT touch agent_core/, it has its own migration)

SCOPE OF THIS SESSION: Sprint 0 only. §1.1 Tasks 0.1 through 0.6.
DO NOT START SPRINT 1 IN THIS SESSION.

THE FIVE CONSTRAINTS (violations = build failure):
1. NO HOT-PATH SERIALIZATION — repr(C) ring or it doesn't ship
2. NO MAIN-THREAD METAL COMPILATION — pre-compiled .metallib + binary archive
3. NO STRING-KEYED DISPATCH IN INNER LOOPS — phf or compile-time enum
4. NO ALLOCATION IN RENDER FRAMES — bumpalo::Bump arenas, reset per frame
5. EVERY OPTIMIZATION SHIPS WITH A SIGNPOST — os_signpost interval + CI assertion

RULES OF EXECUTION:
- Announce the task at the top of every turn: "Sprint 0 / Task 0.X — <name>"
- Build incrementally: after every file change, run the smallest verification (cargo check -p substrate-core, swift build, sqlite3 PRAGMA query)
- Use ast-grep, ripgrep, comby — never plain regex on Swift or Rust source for structural changes
- Every unsafe block gets a // SAFETY: comment with the invariant
- No try!, no force-unwraps, no print() in production code
- If a task requires something not in the plan, STOP and ask. Do not invent.
- Never touch crates/agent_core/ — that's Phase I's territory
- Do not modify any code under crates/agent_core/, Sources/Agent/, or Sources/MLX/

DELIVERABLES FOR THIS SESSION:
- Sources/Telemetry/Sig.swift (new, with OSSignposter wrapper)
- crates/epistemos-trace/ (new shim crate for Rust signposts)
- Sources/Storage/DatabaseManager.swift (modified, canonical pragma block)
- Cargo.toml (workspace root, modified release profile)
- docs/perf-budgets.toml (new)
- bench/morning-session.swift (new, the synthetic workload spec)
- Tools/Performance.instrpkg (new — generate via Xcode → Instruments → Custom)

WIRE THE SIGNPOSTS AT (minimum):
- Every UniFFI call site in Sources/ (use ast-grep to find them)
- Every renderFrame() / drawableSizeWillChange() in Metal views
- Every db.execute / fetch in Sources/Storage/Hot/
- Every MCP tool invocation in Sources/MCP/

VERIFICATION BLOCK (run at the END, paste output to PROGRESS.md):
echo "=== Sprint 0 Verification ==="
sqlite3 ~/Library/Application\ Support/Epistemos/vault.db \
    "PRAGMA journal_mode; PRAGMA mmap_size; PRAGMA synchronous; PRAGMA cache_size;"
ls -lh target/release/libepistemos_core.dylib
grep -rc "OSSignposter\|Sig.interval" Sources/ | grep -v ":0$" | wc -l
grep -rc "signpost_begin\|signpost_end" crates/ | grep -v ":0$" | wc -l
test -f Tools/Performance.instrpkg && echo "instrpkg exists" || echo "MISSING"
test -f docs/perf-budgets.toml && echo "budgets exist" || echo "MISSING"

ACCEPTANCE (all must be true to mark Sprint 0 complete):
- sqlite3 returns journal_mode=wal, mmap_size=1073741824, synchronous=normal
- Release dylib is at least 30% smaller than baseline
- Signpost call counts are non-zero in both Sources/ and crates/
- Tools/Performance.instrpkg and docs/perf-budgets.toml exist
- bench/morning-session.swift compiles

WHEN THE SESSION ENDS:
1. Run the verification block.
2. Paste output to docs/PROGRESS.md under a new heading: ## Sprint 0 — DONE (date).
3. Propose the first task of Sprint 1 in a single sentence.
4. STOP. Do not start Sprint 1.

If you encounter ambiguity, ask. Conservatism wins this sprint.

Begin with Task 0.1.
```

---

## HOW TO USE THIS PROMPT

1. **Open Claude Code in your project root.**
2. **Paste the prompt above.** Claude Code will read the context files and announce Task 0.1.
3. **Let it run.** Approve diffs as they come; the constraints prevent it from drifting.
4. **At session end,** verify the PROGRESS.md update, commit, tag `v-perf-0`.
5. **Open a NEW session for Sprint 1.** Do not chain.

## SUBSEQUENT SPRINTS

For each subsequent sprint, copy this file, change the sprint number at the top, and update:
- The `SCOPE OF THIS SESSION` line
- The `DELIVERABLES FOR THIS SESSION` list
- The `VERIFICATION BLOCK` (lift from §X.3 of the plan)
- The `ACCEPTANCE` list (lift from §X.2 of the plan)

Everything else stays identical. The five constraints, the rules of execution, the agent contract — those are stable across all sprints.

## WHAT NOT TO DO

- Do not start two sprints in the same Claude Code session.
- Do not paste the full plan into the prompt; reference the file. Long prompts get compacted; the plan does not.
- Do not skip the verification block. Without it, the next sprint can't trust the foundation.
- Do not let Claude Code "fix things it noticed" outside the sprint scope. That's drift.
- Do not approve any diff that touches `crates/agent_core/`. Phase I is independent.

---

*This prompt is the on-ramp. The plan is the road.*
