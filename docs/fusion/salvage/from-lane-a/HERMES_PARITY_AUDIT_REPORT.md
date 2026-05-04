# Epistemos agent_core vs Hermes Python — Comprehensive Parity Audit

**Date:** 2026-04-09  
**Auditor:** Kimi Code CLI  
**Hermes Reference:** `tmp/hermes-agent-upstream/` (v0.6.0, ~31K LOC tools + 21 agent modules + 37 CLI modules)  
**Rust Implementation:** `.claude/worktrees/hermes-parity/agent_core/src/` (~8.4K LOC tools + 9 core modules)  

---

## 📊 EXECUTIVE SUMMARY

| Category | Score | Notes |
|----------|-------|-------|
| **Core Agent Loop** | 85% | Streaming, retry, compaction, parallel tools ✅. Missing: smart approval, context compression depth, iterative summary updates |
| **Error Handling** | 90% | 14-class taxonomy with retry/fallback/compress/rotate flags ✅. Parity with Hermes error_classifier.py |
| **Provider Infrastructure** | 75% | 15+ providers wired, but missing: Nous Portal OAuth, Codex OAuth adapter, custom endpoint auto-detection, model metadata resolution |
| **Security** | 65% | Credential redaction + command risk + output scan ✅. Missing: tirith binary integration, smart approval LLM guard, approval persistence |
| **Session Persistence** | 80% | SQLite checkpoint/restore ✅. Missing: FTS5 search, cost tracking, lineage titles, session insights |
| **Tool Ecosystem** | 70% | 22 tools registered ✅. Missing: browser automation, MCP servers, voice/TTS, image generation, delegate subagent, RL training |
| **Context Management** | 70% | Proactive compaction with retry ✅. Missing: structured summary template, iterative updates, token-budget tail protection |
| **Overall Parity** | **76%** | Production-ready core; significant gaps in security depth, context compression quality, and tool breadth |

---

## 1. ✅ AT PARITY WITH HERMES

### 1.1 Core Agent Loop (`agent_loop.rs` vs `run_agent.py` + `cli.py`)

| Feature | Rust Status | Hermes Equivalent | Quality |
|---------|-------------|-------------------|---------|
| Streaming API consumption | ✅ Full | `cli.py:run_conversation()` | Native async/await with tokio timeout (90s) |
| Turn-based execution | ✅ Full | `AIAgent._run_turn()` | Max 25 turns, configurable |
| Parallel tool execution | ✅ Full | `model_tools.py:_run_async()` | `try_join_all` with cancel token |
| Retry with jittered backoff | ✅ Full | `jittered_backoff()` in `run_agent.py` | 5 retries, 2-120s exponential |
| Proactive context compaction | ✅ Full | `ContextCompressor.compress()` | 80% threshold, 3 retry attempts |
| Max tokens truncation | ✅ Full | `StopReason.MaxTokens` handling | Auto-compact on max_tokens |
| Clarification tool | ✅ Full | `clarify_tool.py` | `on_clarification_needed` delegate callback |
| Token budget warnings | ✅ Full | Not explicitly in Hermes | 70% / 90% warning injection |
| Session cancellation | ✅ Full | `KeyboardInterrupt` handling | `CancellationToken` pattern |

**Implementation quality:** The Rust agent loop is architecturally cleaner than Hermes' monolithic `cli.py` (~198K LOC). Hermes mixes CLI UI, TUI, gateway, and agent logic in one file. Rust separates concerns with the `AgentEventDelegate` trait pattern.

### 1.2 Error Classification (`error_classifier.rs` vs `agent/error_classifier.py`)

| Feature | Rust Status | Hermes Equivalent |
|---------|-------------|-------------------|
| 14-class taxonomy | ✅ | `FailoverReason` enum — exact parity |
| Status-code aware | ✅ | 401→Auth, 429→RateLimit, 402→Billing/RateLimit disambiguation |
| Retryable flag | ✅ | `classified.retryable` |
| Should-compress flag | ✅ | Context overflow triggers compaction |
| Should-rotate-credential | ✅ | Auth failures trigger key rotation |
| Should-fallback flag | ✅ | Provider switching on non-retryable errors |
| Provider-specific patterns | ✅ | Anthropic thinking signature, long-context tier |
| Large session heuristic | ✅ | `is_large_session()` — 200K token threshold |
| Chinese provider patterns | ✅ | 上下文长度, 超过最大长度, 令牌超过 |
| Transport error handling | ✅ | Disconnect patterns → ServerError/ContextOverflow |

**Quality note:** Rust implementation has 12 inline tests covering all major classification paths. Hermes' error classifier is embedded in `run_agent.py` without dedicated tests.

### 1.3 Provider Infrastructure

| Provider | Rust (`providers/`) | Hermes (`agent/anthropic_adapter.py`, `hermes_cli/models.py`) |
|----------|---------------------|---------------------------------------------------------------|
| Anthropic Claude native | ✅ `claude.rs` (604 LOC) | ✅ Full Messages API adapter |
| OpenAI native | ✅ `openai.rs` (877 LOC) | ✅ Chat Completions |
| Google Gemini native | ✅ `gemini.rs` (432 LOC) | ✅ via OpenRouter/custom |
| Perplexity native | ✅ `perplexity.rs` (408 LOC) | ✅ Search API |
| OpenRouter gateway | ✅ `openai_compatible.rs` (678 LOC) | ✅ 200+ models |
| Local (Ollama, llama.cpp) | ✅ `openai_compatible.rs` | ✅ Auto-detect in `model_metadata.py` |
| Chinese providers (Z.AI, Kimi, DeepSeek, MiniMax) | ✅ | ✅ via API key providers |
| Western providers (xAI, Mistral, Groq, HF) | ✅ | ✅ via OpenRouter/custom |

**Parity gap:** Rust providers are well-implemented but Hermes has additional adapters:
- **Codex OAuth → Responses API adapter** (`agent/auxiliary_client.py: _CodexCompletionsAdapter`) — 168 LOC of sophisticated translation
- **Anthropic OAuth token refresh** (`agent/anthropic_adapter.py: _refresh_oauth_token`) — auto-refresh Claude Code credentials
- **Nous Portal OAuth flow** — full OAuth integration with token management

### 1.4 Credential Pool (`credential_pool.rs`)

| Feature | Rust | Hermes |
|---------|------|--------|
| Multi-key rotation | ✅ | `credential_manager.py` |
| Per-provider pools | ✅ | `ProviderCredentialPool` equivalent |
| Exhaustion tracking | ✅ | `exhausted` indices |
| Max rotation limit | ✅ | `max_rotations: 3` |
| Passthrough mode (empty pool) | ✅ | Graceful degradation |
| Reset capability | ✅ | `reset_all()` |

**Test coverage:** 8 tests covering rotation, empty pools, single-key pools, reset, manager across providers.

### 1.5 Rate Limit Tracker (`rate_limit_tracker.rs`)

| Feature | Rust | Hermes |
|---------|------|--------|
| Header parsing (x-ratelimit-*) | ✅ | `rate_limit_tracker.py` |
| 429 exponential backoff | ✅ | `2^consecutive_429s` capped at 120s |
| Success resets counter | ✅ | `record_success()` |
| `should_wait()` pre-check | ✅ | Consulted before every API call |
| Duration string parsing ("2m", "60s") | ✅ | `parse_duration_str()` |

### 1.6 Session Persistence (`session_persistence.rs`)

| Feature | Rust | Hermes (`hermes_state.py` SessionDB) |
|---------|------|--------------------------------------|
| SQLite checkpoint storage | ✅ | WAL mode with jitter retry |
| Turn-numbered checkpoints | ✅ | `ON CONFLICT(session_id, turn_number) DO UPDATE` |
| Session metadata (start/complete) | ✅ | `record_session_start/complete()` |
| Load latest checkpoint | ✅ | `load_latest_checkpoint()` |
| List incomplete sessions | ✅ | `list_incomplete_sessions()` |
| Prune old checkpoints | ✅ | Age + per-session limit |
| Delete session checkpoints | ✅ | Post-completion cleanup |
| Resume capability (`can_resume`) | ✅ | `has_checkpoints()` |

**Quality note:** Rust uses rusqlite with structured `SessionCheckpoint` types. Hermes uses raw SQL with 15-write retry jitter logic for concurrency.

### 1.7 Security — Credential Redaction (`security.rs`)

| Feature | Rust | Hermes (`agent/redact.py`) |
|---------|------|----------------------------|
| 15 credential prefix patterns | ✅ | sk-ant-, sk-, ghp_, github_pat_, etc. |
| PEM private key detection | ✅ | -----BEGIN/END PRIVATE KEY----- |
| Zero-alloc fast path (Cow::Borrowed) | ✅ | Python string building (no fast path) |
| Partial masking (first 4 + last 4) | ✅ | Same pattern |
| Tool output scanning | ✅ | Injection, exfiltration, privilege escalation |
| Command risk classification | ✅ | Safe/Moderate/Dangerous/Forbidden |

---

## 2. 🚀 BEYOND HERMES (Rust Superior)

### 2.1 FFI Safety Architecture

**Rust has something Hermes completely lacks:** A production-grade FFI boundary with panic isolation.

```rust
// bridge.rs: catch_unwind guards on every export
macro_rules! ffi_guard_sync {
    ($body:expr) => {{
        match std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| $body)) {
            Ok(v) => v,
            Err(payload) => { /* map to AgentErrorFFI */ }
        }
    }};
}
```

- **panic="unwind"** in release (unlike other Epistemos crates)
- Every `#[uniffi::export]` function has a guard
- Async tasks use `tokio::task::spawn` + `JoinError` handling
- Shared memory cleanup on panic via `ShmPool::cleanup_session()`
- **Hermes has nothing equivalent** — a Python exception crashes the CLI process

### 2.2 Persistent PTY Sessions

**Rust:** Full persistent PTY pool (`pty.rs`) with:
- Shell state persistence (cwd, env, aliases) between commands
- Timeout handling (up to 120s)
- Session-scoped lifecycle (`pty_spawn`/`pty_execute`/`pty_close`)

**Hermes:** Ephemeral subprocess per command (`terminal_tool.py`). No state persistence.

### 2.3 Shared Memory (Zero-Copy) Bridge

**Rust:** `ShmPool` for zero-copy data transfer between Swift and Rust:
- Screen capture pixel data (TCC bypass)
- Large tool outputs (>16KB truncation boundary)
- Session-scoped cleanup

**Hermes:** All data flows through Python memory — no zero-copy mechanism.

### 2.4 Living Vault Memory System

**Rust:** Sophisticated memory management beyond Hermes' simple memory tool:
- **Memory classification** (`classify_vault_memory`): ADD/UPDATE/DELETE/NOOP decisions
- **Ebbinghaus decay** (`decay_memory_nodes`): Strength-based forgetting curve
- **Garbage collection** (`gc_memory_nodes`): Threshold-based pruning
- **Vault-backed persistence**: Facts stored in vault files, not just SQLite

**Hermes:** Simple key-value memory tool with no decay or classification.

### 2.5 Token Savior — AST-Level Code Navigation

**Rust:** 5 symbol-aware tools in `workspace_search.rs`:
- `find_symbol` — AST-level symbol search (not grep)
- `get_function_source` — Extract function bodies
- `get_dependencies` — Import graph analysis
- `get_dependents` — Reverse dependency lookup
- `get_change_impact` — Blast radius estimation

**Hermes:** File operations only (`file_operations.py`) — no code understanding.

### 2.6 PKM-Specific Tools

**Rust has 6 tools Hermes lacks entirely:**
- `graph_query` — Knowledge graph analysis (backlinks, orphans, paths)
- `note_template` — Template-based note creation
- `note_linker` — Wikilink suggestion engine
- `research_digest` — Multi-note aggregation
- `citation_extractor` — Citation formatting (markdown/BibTeX/plain)
- `markdown_table` — JSON/CSV → markdown tables

### 2.7 AgentGraphMemory Integration

**Rust:** `on_execution_recorded` delegate callback wires agent work into the knowledge graph:
- Each turn creates graph nodes for tasks and steps
- Related note IDs are tracked as edges
- **Hermes has no equivalent** — session history is just SQLite rows

---

## 3. ❌ MISSING vs HERMES

### 3.1 Security — Critical Gaps

#### 3.1.1 Tirith Integration (`tools/tirith_security.py`)

**Hermes:** 670 LOC of sophisticated security scanning:
- Auto-downloads tirith binary from GitHub releases
- SHA-256 + cosign provenance verification
- Background install (non-blocking)
- 5-second timeout, fail-open/fail-closed config
- Content-level threat detection (homograph URLs, pipe-to-interpreter, terminal injection)

**Rust:** No tirith integration. Command risk is regex-based only.

#### 3.1.2 Smart Approval (`tools/approval.py`)

**Hermes:** 670 LOC multi-layer approval system:
- **Pattern-based detection:** 25 dangerous patterns (rm -rf, chmod 777, mkfs, etc.)
- **Smart approval:** Uses auxiliary LLM to assess actual risk ("APPROVE/DENY/ESCALATE")
- **Per-session approval state:** Thread-safe with legacy key alias support
- **Permanent allowlist:** Config-persisted patterns
- **Tirith integration:** Combined dangerous-command + content-security approval flow
- **Container bypass:** Docker/singularity/modal/daytona auto-approved
- **YOLO mode:** `--yolo` flag bypasses all approvals

**Rust:** Simple 3-level permission system (`ReadOnly`/`Modification`/`Destructive`) with boolean flags. No LLM guard, no approval persistence, no pattern-based detection.

#### 3.1.3 Checkpoint Manager (`tools/checkpoint_manager.py`)

**Hermes:** 548 LOC of transparent filesystem snapshots:
- Shadow git repos per working directory
- Auto-snapshot before file-mutating operations
- Deduplication (once per turn per directory)
- Rollback to any checkpoint
- Diff preview (`/rollback diff <N>`)
- Single-file restore
- Max 50K files guard, 50 snapshot limit

**Rust:** No filesystem checkpointing. Only conversation checkpointing in session persistence.

### 3.2 Context Compression — Depth Gap

#### 3.2.1 Structured Summary (`agent/context_compressor.py`)

**Hermes:** 676 LOC with rich structured output:
```
## Goal
## Constraints & Preferences  
## Progress
### Done
### In Progress
### Blocked
## Key Decisions
## Relevant Files
## Next Steps
## Critical Context
```

- Iterative updates (preserves previous summary)
- Token-budget tail protection (not fixed message count)
- Tool output pruning pre-pass (cheap, no LLM)
- Scaled summary budget (20% of compressed content, max 12K)
- Tool-call/result pair integrity sanitization
- Boundary alignment (avoids splitting tool groups)

**Rust:** `provider.compact(messages)` is abstracted. No structured template, no iterative updates, no tool pair sanitization. The `ContextCompressor` trait exists but implementations are thin.

### 3.3 Model Metadata Resolution

#### 3.3.1 Context Length Detection (`agent/model_metadata.py`)

**Hermes:** 930 LOC of sophisticated context resolution:
- **10-step resolution chain:** Config override → cache → endpoint metadata → local server → Anthropic API → OpenRouter → Nous → models.dev → hardcoded → default
- Local server auto-detection (Ollama, LM Studio, vLLM, llama.cpp)
- Context probing with step-down tiers (128K → 64K → 32K → 16K → 8K)
- Persistent YAML cache (`context_length_cache.yaml`)
- Error message parsing for actual limits

**Rust:** Hardcoded `context_threshold: 150_000` in `AgentConfig`. No dynamic resolution.

### 3.4 Session Management — Rich Features

#### 3.4.1 FTS5 Search (`hermes_state.py`)

**Hermes:** Full-text search across all session messages:
```sql
CREATE VIRTUAL TABLE messages_fts USING fts5(content, content=messages, content_rowid=id);
```
- Trigger-based FTS sync (insert/update/delete)
- Session search tool (`session_search_tool.py`)

**Rust:** No FTS. Session persistence stores JSON blobs only.

#### 3.4.2 Session Insights (`agent/insights.py`)

**Hermes:** 792 LOC analytics engine:
- Token/cost breakdown by model, platform, tool
- Activity patterns (day of week, hour, streaks)
- Notable sessions (longest, most messages, most tokens)
- Bar chart terminal visualization
- Gateway-compatible formatting

**Rust:** No analytics. Only raw token counts in `AgentResultFFI`.

#### 3.4.3 Session Title Generation (`agent/title_generator.py`)

**Hermes:** Auto-generates titles from first exchange using auxiliary LLM (compression task, 30-token budget, 0.3 temperature). Background thread execution.

**Rust:** No title generation. Sessions use objective string as title.

#### 3.4.4 Session Lineage (`hermes_state.py`)

**Hermes:** Parent-child session chains with auto-numbered titles:
- `resolve_session_by_title()` — prefers latest numbered variant
- `get_next_title_in_lineage()` — "session #2", "session #3"

**Rust:** No lineage tracking. Single-session checkpointing only.

### 3.5 Tool Ecosystem — Missing Tools

| Hermes Tool | LOC | Status in Rust | Gap Severity |
|-------------|-----|----------------|--------------|
| `browser_tool.py` | 1,888 | ❌ Not implemented | **High** — Web automation |
| `mcp_tool.py` | 1,944 | ❌ Not implemented | **High** — MCP server integration |
| `delegate_tool.py` | 1,092 | ❌ Not implemented | **High** — Subagent spawning |
| `vision_tools.py` | 681 | ❌ Not implemented | **Medium** — Image analysis |
| `image_generation_tool.py` | 640 | ❌ Not implemented | **Medium** — Image generation |
| `tts_tool.py` | 695 | ❌ Not implemented | **Medium** — Text-to-speech |
| `voice_mode.py` | 611 | ❌ Not implemented | **Medium** — Voice input |
| `rl_training_tool.py` | 1,142 | ❌ Not implemented | **Low** — RL fine-tuning |
| `mixture_of_agents_tool.py` | 775 | ❌ Not implemented | **Low** — Multi-agent ensemble |
| `cronjob_tools.py` | 573 | ❌ Not implemented | **Low** — Scheduled execution |
| `homeassistant_tool.py` | 481 | ❌ Not implemented | **Low** — Home automation |
| `send_message_tool.py` | 1,071 | ❌ Not implemented | **Low** — External messaging |
| `skills_hub.py` | 3,194 | ❌ Not implemented | **Medium** — Skills marketplace |

### 3.6 Provider Features

#### 3.6.1 Prompt Caching (`agent/prompt_caching.py`)

**Hermes:** Anthropic "system_and_3" strategy:
- 4 cache_control breakpoints (system + last 3 messages)
- Deep copy of messages with cache markers
- TTL support ("5m" / "1h")

**Rust:** No prompt caching implementation.

#### 3.6.2 Cheap Model Routing (`agent/smart_model_routing.py`)

**Hermes:** Keyword-based routing to cheaper models for simple queries:
- Complexity detection (word count, keywords, URLs, code blocks)
- `choose_cheap_model_route()` with conservative filtering
- Configurable cheap model provider

**Rust:** `ConfidenceRouter` has complexity estimation but no cheap-model fallback.

#### 3.6.3 Provider Auto-Detection Chain (`agent/auxiliary_client.py`)

**Hermes:** 7-step auto-resolution for auxiliary tasks:
1. OpenRouter → 2. Nous Portal → 3. Custom endpoint → 4. Codex OAuth → 5. Anthropic → 6. API-key providers → 7. None

**Rust:** Explicit provider selection only. No auto-detection.

### 3.7 Build/Deploy Infrastructure

| Feature | Hermes | Rust |
|---------|--------|------|
| Gateway service (systemd) | ✅ `hermes_cli/gateway.py` | ❌ Not applicable (macOS app) |
| WhatsApp bridge | ✅ `scripts/whatsapp-bridge/` | ❌ Not applicable |
| Batch runner | ✅ `batch_runner.py` (419 LOC) | ❌ Not applicable |
| Docker support | ✅ `docker/` | ❌ Not applicable |
| Nix flake | ✅ `flake.nix` | ❌ Not applicable |
| Skills marketplace | ✅ `skills/` + `skills_hub.py` | ❌ No equivalent |
| CLI TUI | ✅ `cli.py` curses-based | ❌ SwiftUI only |

---

## 4. IMPLEMENTATION QUALITY COMPARISON

### 4.1 Code Organization

| Aspect | Rust | Hermes (Python) |
|--------|------|-----------------|
| Module separation | ✅ Excellent — 9 core + 6 provider + 14 tool modules | ⚠️ Poor — `cli.py` is 198K LOC monolith |
| Trait-based abstraction | ✅ `AgentProvider`, `ToolHandler`, `AgentEventDelegate` | ⚠️ Inheritance + callbacks |
| Type safety | ✅ Full — serde for JSON, thiserror for errors | ⚠️ Runtime typing, lots of `isinstance()` |
| Test coverage | ✅ 40+ inline tests across modules | ⚠️ Sparse — tests/ dir exists but not comprehensive |
| Documentation | ✅ Inline rustdoc + module comments | ⚠️ Sparse docstrings |

### 4.2 Performance Characteristics

| Aspect | Rust | Hermes |
|--------|------|--------|
| Memory safety | ✅ Compile-time guarantees | ⚠️ GC, reference cycles possible |
| Async runtime | ✅ Native tokio | ⚠️ asyncio + thread pools |
| Zero-copy where possible | ✅ Cow, ShmPool | ❌ All data copied |
| Startup time | ✅ Native binary | ⚠️ Python import overhead |
| FFI overhead | ✅ Minimal (UniFFI) | N/A |

### 4.3 Error Handling

| Aspect | Rust | Hermes |
|--------|------|--------|
| Error types | ✅ `thiserror` enums, typed variants | ⚠️ String exceptions, broad try/except |
| Panic isolation | ✅ catch_unwind at FFI boundary | ❌ No isolation |
| Retry logic | ✅ Structured with classification | ⚠️ Ad-hoc in loop |
| Observability | ✅ tracing structured logs | ⚠️ Basic logging |

---

## 5. RECOMMENDATIONS

### 5.1 P0 — Critical for Production

1. **Smart Approval System** — Port Hermes' multi-layer approval (pattern + LLM guard + persistence). Current boolean-only system is insufficient for destructive operations.
2. **Tirith Integration** — Add the tirith binary wrapper for content-level security scanning. 670 LOC of proven security infrastructure.
3. **Context Compression Quality** — Implement structured summary template with iterative updates. Current compaction loses too much context.

### 5.2 P1 — Important for Parity

4. **Model Metadata Resolution** — Port the 10-step context length detection chain. Hardcoded 150K threshold is brittle.
5. **Prompt Caching** — Implement Anthropic system_and_3 strategy for cost reduction.
6. **Session Title Generation** — Auto-generate titles from first exchange using auxiliary LLM.
7. **Browser Automation Tool** — Port `browser_tool.py` (1,888 LOC) for web interaction.

### 5.3 P2 — Nice to Have

8. **MCP Server Integration** — Port `mcp_tool.py` for external tool servers.
9. **Session Insights** — Port analytics engine for usage tracking.
10. **Filesystem Checkpoints** — Port shadow git repo checkpoint manager.
11. **Cheap Model Routing** — Add complexity-based routing to cheaper models.
12. **FTS5 Search** — Add full-text search to session persistence.

### 5.4 Keep — Rust Advantages to Preserve

- ✅ FFI panic isolation (don't compromise this)
- ✅ Persistent PTY sessions
- ✅ Shared memory zero-copy bridge
- ✅ Living Vault memory (decay + classification)
- ✅ Token Savior AST tools
- ✅ PKM-specific tools
- ✅ AgentGraphMemory integration

---

## 6. FINAL SCORE

| Subsystem | Weight | Score | Weighted |
|-----------|--------|-------|----------|
| Agent Loop | 25% | 85% | 21.25 |
| Error Handling | 10% | 90% | 9.00 |
| Provider Infra | 15% | 75% | 11.25 |
| Security | 15% | 65% | 9.75 |
| Session Persistence | 10% | 80% | 8.00 |
| Tool Ecosystem | 15% | 70% | 10.50 |
| Context Management | 10% | 70% | 7.00 |
| **TOTAL** | **100%** | | **76.75%** |

**Overall Parity: ~77%**

The Rust agent_core has a **production-grade foundation** with superior architecture (FFI safety, type safety, async performance) but **significant gaps in security depth, context compression quality, and tool breadth**. The core agent loop is at ~85% parity with Hermes, but the surrounding infrastructure (security, context management, tools) drags the overall score down.

**Key insight:** Rust is ahead where it matters for a macOS-native app (FFI, memory, performance) but behind where Hermes has iterated for years (security patterns, context compression, tool ecosystem). The gaps are all **portable** — they represent missing features, not architectural limitations.
