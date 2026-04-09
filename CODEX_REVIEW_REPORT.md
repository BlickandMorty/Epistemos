# Codex Review Report — Hermes Parity + PKM Tools

**Branch:** `worktree-hermes-parity`
**Commits:** 5 (on top of main)
**Date:** 2026-04-09
**Author:** Claude Opus 4.6 (1M context)

---

## Summary

This branch brings the `agent_core` Rust crate to full Hermes-agent parity for core agent infrastructure, then extends it with 6 PKM-specific tools that no general-purpose agent framework provides.

**Stats:**
- **+2,667 lines** added, **-16 lines** removed (19 files changed)
- **9 new files** created, **10 existing files** modified
- **190 tests pass** (3/3 consecutive runs, 0 failures)
- **0 clippy warnings** in new code
- **28 tools** registered in the agent (was 15 before this branch)

---

## Commits (oldest → newest)

### 1. `1aded627` — Phase 1: Register 4 previously-unregistered tools
**What:** 4 tools (`file_ops`, `web_fetch`, `memory`, `skills`) were fully implemented in `agent_core/src/tools/` but never registered in `register_default_tools()`. This commit wires them in.
**Why:** Dead code — the implementations were complete (370+ lines each) but unreachable.
**Also:** Added `root_path()` method to `VaultBackend` trait + implemented on `VaultStore`.

### 2. `b110c3a0` — Phase 2: Add 3 new tools + register all (22 total)
**New files:**
- `tools/todo.rs` (166 lines) — Persistent todo list at `.epistemos/todos.md`
- `tools/clarify.rs` (57 lines) — Ask user for clarification, returns `[CLARIFICATION_NEEDED]` marker
- `tools/code_execution.rs` (105 lines) — Sandboxed code runner (python3/node/ruby/bash/swift)

**Dependency:** Added `tempfile = "3.14"` to `agent_core/Cargo.toml` (for sandboxed execution).

### 3. `58020e66` — Phase 3: Rate limit tracker
**New file:** `rate_limit_tracker.rs` (230 lines, 5 tests)
- Per-provider quota tracking from HTTP headers
- Exponential backoff on consecutive 429s (2^n seconds, capped at 120s)
- `should_wait(provider)` → `Option<Duration>` consulted before each API call
- `update_from_headers()` / `record_429()` / `record_success()` API

### 4. `20c83b2d` — Phase 3-6: Error classifier, title generator, process registry, loop wiring
**New files:**
- `error_classifier.rs` (290 lines, 14 tests) — 14-category Hermes-parity taxonomy
- `title_generator.rs` (140 lines, 10 tests) — Heuristic title from first user message
- `process_registry.rs` (280 lines, 7 tests) — Background process tracking

**Modified files:**
- `agent_loop.rs` — Wired rate_limit_tracker (should_wait + record_429/success before/after provider calls) and clarify tool (detects `[CLARIFICATION_NEEDED]` marker, calls delegate)
- `bridge.rs` — Added `on_clarification_needed(question, options_json) -> String` to `AgentEventDelegate` trait
- `compaction.rs` — Upgraded to 8-section Hermes-style structured template
- `delegate_task.rs` — Added `on_clarification_needed` to `SilentDelegate`

### 5. `5463759d` — Phase 7: Add 6 PKM-specific tools
**New files:**
- `tools/graph_query.rs` (276 lines) — Knowledge graph traversal
- `tools/note_tools.rs` (523 lines) — 5 note-centric tools

---

## Full Tool Inventory (28 tools)

### Pre-existing (15 tools, unchanged)
| Tool | Risk | Source |
|------|------|--------|
| `vault_search` | ReadOnly | registry.rs (inline) |
| `vault_read` | ReadOnly | registry.rs (inline) |
| `vault_write` | Modification | registry.rs (inline) |
| `think` | ReadOnly | tools/think.rs |
| `chunk_reduce` | ReadOnly | tools/chunk_reduce.rs |
| `workspace_search` | ReadOnly | tools/workspace_search.rs |
| `find_symbol` | ReadOnly | registry.rs (token-savior) |
| `get_function_source` | ReadOnly | registry.rs (token-savior) |
| `get_dependencies` | ReadOnly | registry.rs (token-savior) |
| `get_dependents` | ReadOnly | registry.rs (token-savior) |
| `get_change_impact` | ReadOnly | registry.rs (token-savior) |
| `bash_execute` | Destructive | registry.rs (conditional) |
| `web_search` | ReadOnly | registry.rs (inline) |
| `computer_use` | Destructive | tools/computer_use.rs |
| `delegate_task` | Modification | tools/delegate_task.rs (not in registry — needs provider at runtime) |

### Newly registered (was implemented, now wired — 4 tools)
| Tool | Risk | Source |
|------|------|--------|
| `file_ops` | Modification | tools/file_ops.rs (370 lines) |
| `web_fetch` | ReadOnly | tools/web_fetch.rs (264 lines) |
| `memory` | Modification | tools/memory.rs (370 lines) |
| `skills` | Modification | tools/skills.rs (375 lines) |

### New Hermes-parity tools (3 tools)
| Tool | Risk | Source |
|------|------|--------|
| `todo` | Modification | tools/todo.rs (166 lines) |
| `clarify` | ReadOnly | tools/clarify.rs (57 lines) |
| `execute_code` | Destructive | tools/code_execution.rs (105 lines) |

### New PKM-specific tools (6 tools)
| Tool | Risk | Source |
|------|------|--------|
| `graph_query` | ReadOnly | tools/graph_query.rs (276 lines) |
| `note_template` | Modification | tools/note_tools.rs |
| `note_linker` | ReadOnly | tools/note_tools.rs |
| `research_digest` | ReadOnly | tools/note_tools.rs |
| `citation_extractor` | ReadOnly | tools/note_tools.rs |
| `markdown_table` | ReadOnly | tools/note_tools.rs |

---

## New Infrastructure Modules (4 modules)

### error_classifier.rs
- **14 FailoverReason variants:** Auth, AuthPermanent, Billing, RateLimit, Overloaded, ServerError, Timeout, ContextOverflow, PayloadTooLarge, ModelNotFound, FormatError, ThinkingSignature, LongContextTier, Unknown
- **ClassifiedError struct** with actionable flags: `retryable`, `should_compress`, `should_rotate_credential`, `should_fallback`
- **Classification pipeline:** provider-specific patterns → HTTP status → message patterns → context overflow heuristics → fallback
- **402 disambiguation:** distinguishes genuine billing exhaustion from transient rate limits
- **14 tests** covering all categories

### title_generator.rs
- Heuristic title from first user message (no LLM call)
- Strips common prefixes ("Can you", "Please", "Help me", etc.)
- Takes first sentence, capitalizes, truncates at word boundary (50 chars max)
- **10 tests**

### process_registry.rs
- Tracks background processes from bash/code_execution tools
- **Max 64** concurrent tracked processes with LRU eviction of oldest finished
- **200KB** rolling output buffer per process (auto-truncates oldest content)
- **30-minute TTL** for finished processes (kept for polling)
- Thread-safe (`Mutex<HashMap>`)
- **7 tests**

### rate_limit_tracker.rs (from previous session)
- Per-provider quota tracking from HTTP headers
- Exponential backoff: 2^(min(consecutive_429s, 6)) seconds, capped at 120s
- `should_wait(provider)` → `Option<Duration>` for agent loop
- **5 tests**

---

## Agent Loop Changes

### Rate Limit Integration
```
Before each provider.stream_message() call:
  → rate_tracker.should_wait(provider_name) → sleep if throttled

After stream succeeds:
  → rate_tracker.record_success(provider_name)

On 429 error:
  → rate_tracker.record_429(provider_name)
```

### Clarification Integration
```
After tool execution, before pushing results:
  → Scan each tool result for "[CLARIFICATION_NEEDED]" marker
  → If found: extract question + options
  → Call delegate.on_clarification_needed(question, options_json)
  → Replace tool result with "User responded: {response}"
  → Continue loop with user's answer in context
```

### Compaction Template (8 sections)
```
[Compacted Context]
## Prior Context (if re-compacting)
## Goal
## Constraints & Preferences
## Progress
### Done
## Key Decisions
## Files Modified
## Tool Actions
## Next Steps
## Open Questions
```

---

## Hermes Parity Assessment

### PARITY (35+ features)
- Core tool categories: file ops, memory, skills, todo, clarify, code execution, web search, web fetch
- Agent loop: rate limiting, error classification, context compaction, thinking block preservation, parallel tools
- Session management: global registry, cancel tokens, completion metrics
- Provider abstraction: Claude, OpenAI, Gemini, Perplexity, OpenAI-compatible

### BEYOND Hermes (12 features)
1. **Proactive compaction** — fires at 80% threshold BEFORE API call (Hermes is reactive only)
2. **graph_query** — knowledge graph traversal (backlinks, orphans, paths, tag clusters)
3. **note_template** — template instantiation with variable interpolation
4. **note_linker** — auto-suggest wikilinks for unlinked mentions
5. **research_digest** — aggregate vault notes into structured summary
6. **citation_extractor** — parse URLs, DOIs, parenthetical refs
7. **markdown_table** — generate tables from JSON/CSV
8. **memory_decay** — Ebbinghaus forgetting curve (pre-existing)
9. **memory_classifier** — ML-based fact categorization (pre-existing)
10. **vault_git** — formal git integration for vault (pre-existing)
11. **cross_propagation** — cross-session memory synthesis (pre-existing)
12. **Heuristic title generation** — no API call needed (faster, cheaper)

### Known GAPs (not in scope for this branch)
- Browser automation (9 Hermes tools) — covered by Swift computer_use
- Vision/image analysis — covered by Swift MLX
- Session search — not yet implemented
- delegate_task registration — needs provider at runtime (already implemented, architectural constraint)

---

## Merge Strategy

```bash
cd /Users/jojo/Downloads/Epistemos
git merge worktree-hermes-parity
```

**Expected conflicts in 2 files:**
1. `agent_core/src/tools/registry.rs` — both branches modified `register_default_tools()`
2. `agent_core/src/lib.rs` — both branches added modules

**Resolution:** Take all module additions from both branches. The worktree adds tool registrations; main adds other infrastructure modules. They're additive and compatible.

**Files that must NOT conflict (only modified in worktree):**
- `agent_loop.rs`, `bridge.rs`, `compaction.rs`, `delegate_task.rs`
- All 9 new files

---

## Test Verification

```
=== PASS 1 === 190 passed; 0 failed
=== PASS 2 === 190 passed; 0 failed
=== PASS 3 === 190 passed; 0 failed
```

Clippy: 0 warnings in new code (54 pre-existing warnings in unchanged files).

---

*End of report.*
