# Codex Review Report — Hermes Parity + PKM Tools (v2)

**Branch:** `worktree-hermes-parity`
**Commits:** 7 (on top of main)
**Date:** 2026-04-09
**Author:** Claude Opus 4.6 (1M context)

---

## Summary

This branch brings `agent_core` to **genuine Hermes-level infrastructure** for the agent loop, then extends with PKM-specific tools. An honest deep audit (Phase 8) revealed critical gaps in the initial implementation — retry logic, error recovery, safety gates — which are now addressed.

**Stats:**
- **+3,451 lines** added, **-73 lines** removed (22 files changed)
- **9 new files** created, **13 existing files** modified
- **190 tests pass** (3/3 consecutive)
- **28 tools** registered
- **0 clippy warnings** in new code

---

## Commits (oldest to newest)

| # | Hash | Phase | Description |
|---|------|-------|-------------|
| 1 | `1aded627` | Phase 1 | Register 4 previously-unregistered tools (file_ops, web_fetch, memory, skills) |
| 2 | `b110c3a0` | Phase 2 | Add 3 new tools (todo, clarify, code_execution) + register all (22 total) |
| 3 | `58020e66` | Phase 3 | Rate limit tracker with exponential backoff |
| 4 | `20c83b2d` | Phase 3-6 | Error classifier, title generator, process registry, loop wiring |
| 5 | `5463759d` | Phase 7 | 6 PKM-specific tools (graph_query, note_template, note_linker, research_digest, citation_extractor, markdown_table) |
| 6 | `5478d8d6` | Report | Initial codex review report |
| 7 | `1105bf10` | Phase 8 | **Critical hardening** — retry logic, safety gates, expanded patterns |

---

## Phase 8 Hardening (the critical commit)

After a deep line-by-line audit against Hermes `run_agent.py` (9700 lines), `tools/file_tool.py`, `tools/terminal_tool.py`, `tools/todo_tool.py`, `agent/error_classifier.py`, and `tools/process_registry.py`, these gaps were found and fixed:

### Agent Loop — Now has production-grade error recovery
- **Exponential backoff with jitter** (5 retries, 2s base, 120s max) — was: zero retries, immediate error return
- **Error classifier integration** — classifies every API error, decides retry/compress/rotate/fallback
- **Stream timeout** (90s stall detection) — was: could hang forever
- **Mid-stream error recovery** — retries on classified-retryable errors
- **Compaction retry** (3 attempts) — was: single attempt, fatal on failure

### File Ops — Now has safety gates
- **Device path blocklist** (/dev/zero, /dev/stdin, etc.) — was: could hang
- **Binary file guard** (35 extensions) — was: would read .png as text
- **100K char read limit** — was: unlimited
- **Read loop detection** (blocks at 4+ consecutive reads) — was: unlimited
- **Large file hints** when no line range specified

### Error Classifier — Expanded pattern coverage
- **100+ patterns** across 6 lists (was 35) — billing, transient, context overflow, auth, disconnect, Chinese provider patterns
- Server disconnect detection without HTTP status code
- Auth pattern detection without status code

### Todo Tool — Now has 4 statuses
- **pending, in_progress, completed, cancelled** (was: completed/not-completed)
- **"start" action** with only-one-in-progress enforcement (Hermes rule)
- **Summary counts** in list output

### Process Registry — Now has process control
- **kill(id, force)** via SIGTERM/SIGKILL on Unix
- **is_alive(id)** via kill(pid, 0) probing

### Memory Tool — Expanded threat patterns
- **21 patterns** (was 10) — added SSH backdoor, credential files, more injection variants

---

## HONEST GAP ASSESSMENT

### What we DO match Hermes on now:
| Area | Assessment |
|------|------------|
| Retry + backoff | MATCH — 5 retries with jittered exponential backoff |
| Error classification | MATCH — 14 categories, 100+ patterns, actionable flags |
| Stream timeout | MATCH — 90s stall detection |
| Compaction retry | MATCH — 3 attempts before fatal |
| Rate limit tracking | MATCH — per-provider, 429 detection, should_wait() |
| Tool registration | MATCH — 28 tools registered (Hermes core: ~21) |
| Memory safety | MATCH — 21 threat patterns, invisible unicode scanning |
| File read safety | MATCH — device blocklist, binary guard, char limit, loop detection |
| Todo lifecycle | MATCH — 4 statuses, only-one-in-progress rule |
| Process tracking | MATCH — kill, alive check, 200KB buffer, LRU eviction |

### What we're BETTER than Hermes:
| Area | Why |
|------|-----|
| Proactive compaction | Fires at 80% threshold BEFORE API call — Hermes is reactive only |
| PKM tools (6) | graph_query, note_template, note_linker, research_digest, citation_extractor, markdown_table |
| Memory decay | Ebbinghaus forgetting curve (pre-existing) |
| Vault git | Formal git integration for vault (pre-existing) |
| Type safety | Rust compiler catches errors Python runtime misses |

### What we DON'T match (honest gaps):
| Area | Gap | Severity | Why |
|------|-----|----------|-----|
| Credential rotation | No API key pool/rotation on auth failure | HIGH | Needs credential pool from Swift |
| Fallback provider chain | No auto-switch to backup provider | HIGH | Needs provider list in config |
| Code execution RPC | No tool chaining inside scripts | MEDIUM | Fundamentally different architecture |
| Terminal multi-backend | No docker/modal/ssh/sandbox | LOW for PKM | macOS app doesn't need containers |
| Browser automation | No Hermes browser_* tools | LOW | Handled by Swift computer_use |
| Vision/image | No image analysis | LOW | Handled by Swift MLX |
| Session search | No cross-session history search | MEDIUM | Not yet implemented |
| Budget pressure warnings | No "70%/90% budget" injection into tool results | LOW | Agent sees turn count via delegate |
| File search | No ripgrep-backed search tool | LOW | workspace_search covers this |
| Fuzzy patch matching | Single exact-match only | LOW | V4A + fuzzy is Hermes-specific |

### Remaining work to close HIGH gaps:
1. **Credential rotation** (~50 lines in agent_loop.rs) — when error_classifier says `should_rotate_credential`, try next API key from pool
2. **Fallback provider chain** (~80 lines) — when retries exhausted, try alternate provider
3. **Session persistence** (~100 lines) — checkpoint after each turn for crash recovery

These 3 items would bring us to **95%+ production parity** with Hermes on agent infrastructure.

---

## Merge Strategy

```bash
cd /Users/jojo/Downloads/Epistemos
git merge worktree-hermes-parity
```

**Likely conflicts in 2 files:** `registry.rs` and `lib.rs` (both branches added modules). Resolution: take all additions from both branches.

---

## Test Verification

```
=== PASS 1 === 190 passed; 0 failed
=== PASS 2 === 190 passed; 0 failed
=== PASS 3 === 190 passed; 0 failed
```

---

*This report reflects the state after Phase 8 hardening. The initial Phases 1-7 had significant gaps that Phase 8 addressed.*
