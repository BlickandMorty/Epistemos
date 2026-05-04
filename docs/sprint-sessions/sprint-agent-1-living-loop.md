# Sprint Agent-1: The Living Loop

> **Index status**: SUPERSEDED-HISTORICAL — Older sprint plan superseded by MASTER_FUSION.md sprint plan §10.
> Classified in [`docs/_INDEX.md §14`](_INDEX.md).


## Duration: 1-2 sessions | Priority: CRITICAL — everything else depends on this

---

## Pre-Read (do this FIRST)

```bash
cat CLAUDE.md
cat docs/agent-system/AGENT_ARCHITECTURE.md    # Full architecture spec
cat docs/agent-system/GAP_ANALYSIS.md           # What's missing and what's broken
cat docs/PROGRESS.md                             # Current state
```

After reading, confirm: "Architecture read. Building the living loop. First file: agent_core/Cargo.toml."

---

## Tasks (execute in order)

### Task 1: Create agent_core/Cargo.toml
Create the Rust crate manifest. Key dependencies: tokio (full), async-trait, futures, reqwest (json + stream), eventsource-stream, serde/serde_json, uniffi (0.28 with tokio feature), rusqlite (bundled), tantivy, thiserror, anyhow, uuid (v4), chrono (serde), tracing, tokio-util, async-stream, sha2.

Build deps: uniffi 0.28 with build feature.

Crate type: cdylib + staticlib.

### Task 2: Create agent_core/src/lib.rs
Module declarations for: types, provider, agent_loop, bridge, error, prompts, session, routing. Sub-modules: providers (claude), tools (registry), storage (vault, recipe_cache). Include `uniffi::setup_scaffolding!()`.

### Task 3: Create agent_core/src/types.rs
From AGENT_ARCHITECTURE.md Section 1.2. Must include: Message enum (User/Assistant with serde tag), UserContent enum (Text/ToolResult/Image), ContentBlock enum (Thinking with signature field, Text, ToolUse), ToolResult, ToolResultContent, ImageSource, StopReason, TokenUsage. All with Serialize + Deserialize + Clone + Debug.

### Task 4: Create agent_core/src/provider.rs
From AGENT_ARCHITECTURE.md Section 1.2. AgentProvider trait with stream_message(), compact(), capabilities(), name(). StreamEvent enum with ThinkingDelta, TextDelta, InputJsonDelta, ContentBlockComplete, SignatureDelta, MessageStop. MessageStream type alias. ProviderCapabilities struct.

### Task 5: Create agent_core/src/storage/vault.rs
From GAP_ANALYSIS.md. VaultBackend trait with hybrid_search, search, read, write, list, exists, delete. VaultStore implementation using tantivy full-text index + SQLite metadata. Path traversal guard. Frontmatter tag extraction. Excerpt generation. File walking for .md files.

### Task 6: Create agent_core/src/tools/registry.rs
From AGENT_ARCHITECTURE.md Section 4. ToolDefinition struct, ToolHandler trait, RiskLevel enum (ReadOnly/Modification/Destructive), ToolRegistry struct with register, get_definitions, execute, vault_search. Real implementations for vault_search, vault_read, vault_write, bash_execute (with security blocklist).

### Task 7: Create agent_core/src/providers/claude.rs
From AGENT_ARCHITECTURE.md Section 2. ClaudeProvider with SSE state machine. Must handle ALL event types: content_block_start (Text/Thinking/ToolUse/ServerToolUse), content_block_delta (text_delta/thinking_delta/input_json_delta/signature_delta), content_block_stop, message_delta, message_stop, ping, error.

CRITICAL: Use `thinking: { "type": "adaptive" }` with optional effort parameter. Beta header: `interleaved-thinking-2025-05-14`. API version: `2023-06-01`. Support web_search_20250305, web_fetch_20250305, code_execution_20250825 server tools. Support mcp_servers parameter.

### Task 8: Create agent_core/src/error.rs
From GAP_ANALYSIS.md. classify_http_error() for retry classification (429/500/502/503 retryable, 400/401/403 fail). RetryConfig with exponential backoff + decorrelated jitter. with_retry() async executor. HttpStatusError trait.

### Task 9: Create agent_core/src/prompts.rs
From GAP_ANALYSIS.md. TOOL_PREFERENCE_RULES constant, BASE_SYSTEM_PROMPT, RESEARCH_PROMPT, CODE_PROMPT, LOCAL_FALLBACK_NOTICE. build_system_prompt() function with PromptMode enum.

### Task 10: Create agent_core/src/session.rs
From GAP_ANALYSIS.md. GlobalSessions with register/cancel/complete/fail/active_count/list. SessionGuard RAII struct with Drop impl for auto-cleanup. SessionState enum (Running/Completed/Failed). Uses OnceLock<Mutex<SessionRegistry>>.

### Task 11: Create agent_core/src/agent_loop.rs
From AGENT_ARCHITECTURE.md Section 2.2. THE CORE. run_agent_loop() with:
- Context bootstrap via vault_search before first inference
- `loop` with turn counting and max_turns safety rail
- Cancellation check via CancellationToken on every turn AND during streaming
- Stream processing forwarding every token to delegate immediately
- stop_reason handling: EndTurn → return Ok, ToolUse → execute parallel → continue, MaxTokens → compact → continue
- CRITICAL: `messages.push(Message::assistant(response_blocks.clone()))` — preserve ALL blocks
- Parallel tool execution via futures::try_join_all
- Permission gating with risk-level-based auto-approve

### Task 12: Create agent_core/src/bridge.rs
From GAP_ANALYSIS.md. AgentEventDelegate callback interface with all methods. AgentConfig::from_ffi() conversion (THE MISSING PIECE). HttpStatusError impl for AgentError. run_agent_session() UniFFI export with GlobalSessions integration. cancel_agent_session() export. FFI-safe types: ToolConfig, AgentConfigFFI, AgentResultFFI, AgentErrorFFI.

### Task 13: Create agent_core/src/routing.rs
From AGENT_ARCHITECTURE.md Section 3.4/Pattern 7. ConfidenceRouter with classify → route. HeuristicClassifier (pure Rust, no model needed). RoutingDecision enum (Local/LocalWithFallback/Cloud). ClassificationResult with complexity, tool_count_estimate, requires_current_info, privacy_sensitive.

### Task 14: Create Epistemos/Bridge/StreamingDelegate.swift
From GAP_ANALYSIS.md (fixed version). AsyncStream continuation. Permission semaphores with NSLock. 120-second timeout on waitForPermission (auto-deny on timeout). resolvePermission() callable from @MainActor.

### Task 15: Create Epistemos/ViewModels/AgentViewModel.swift
From GAP_ANALYSIS.md (fixed version). @Observable @MainActor. .bufferingNewest(256). Session ID tracking for proper cancellation. Task.detached for Rust call. Phase-based state machine. flushBuffers() for thinking→tool transitions.

### Task 16: Create Epistemos/Views/OmegaPanel.swift
From GAP_ANALYSIS.md. ThinkingBubble (DisclosureGroup with token count, PulsingDot). ToolExecutionRow (with icons per tool type). PermissionGateView (risk-colored, Approve/Deny buttons). ResponseBubble (streaming cursor). ErrorBanner. RenderedBlock enum.

---

## Verification (run ALL after completing)

```bash
echo "=== Sprint Agent-1 Verification ==="

# Rust crate structure
cd agent_core
cargo check 2>&1 | tail -20
echo "---"

# All files exist
for f in Cargo.toml src/lib.rs src/types.rs src/provider.rs src/agent_loop.rs src/bridge.rs src/error.rs src/prompts.rs src/session.rs src/routing.rs src/providers/claude.rs src/tools/registry.rs src/storage/vault.rs; do
  [ -f "$f" ] && echo "✅ $f" || echo "❌ MISSING: $f"
done
cd ..

# Swift files exist
for f in Epistemos/Bridge/StreamingDelegate.swift Epistemos/ViewModels/AgentViewModel.swift Epistemos/Views/OmegaPanel.swift; do
  [ -f "$f" ] && echo "✅ $f" || echo "❌ MISSING: $f"
done

# Critical patterns
echo "--- Critical Pattern Checks ---"
grep -c "response_blocks.clone()" agent_core/src/agent_loop.rs    # Thinking preservation
grep -c "try_join_all" agent_core/src/agent_loop.rs               # Parallel tools
grep -c "is_cancelled" agent_core/src/agent_loop.rs               # Cancellation
grep -c "EndTurn" agent_core/src/agent_loop.rs                    # Agent-decides
grep -c "on_text_delta\|on_thinking_delta" agent_core/src/agent_loop.rs  # Streaming
grep -c "timeout\|120" Epistemos/Bridge/StreamingDelegate.swift    # Permission timeout
grep -c "bufferingNewest" Epistemos/ViewModels/AgentViewModel.swift # Bounded buffer
grep -c "Task.detached" Epistemos/ViewModels/AgentViewModel.swift  # No MainActor deadlock
grep -c "adaptive" agent_core/src/providers/claude.rs              # Thinking config

# Anti-sidecar
echo "Sidecar patterns (MUST be 0):"
grep -rn "Process()\|NSTask\|posix_spawn" --include="*.swift" --include="*.rs" agent_core/ Epistemos/Bridge/ Epistemos/ViewModels/ Epistemos/Views/ 2>/dev/null | wc -l
```

## After Completing

Update docs/PROGRESS.md: mark all Sprint Agent-1 items as ✅ with today's date.
Then proceed to Sprint Agent-2 in a FRESH session.
