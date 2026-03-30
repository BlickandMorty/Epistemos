# Sprint Omega-1: Foundation Integration
## Duration: 1-2 sessions | Priority: CRITICAL — everything else depends on this

---

## Pre-Read (do this FIRST, do NOT skip)

```bash
cat CLAUDE.md
cat docs/AGENT_PROGRESS.md
cat docs/HERMES_INTEGRATION_RESEARCH.md | head -200
```

After reading, confirm: "Architecture read. Sprint Omega-1: Foundation. First task: integrate prompt_caching.rs."

---

## What This Sprint Does

Integrates 4 new Rust modules into agent_core (prompt caching, think tool, 4-phase compaction, security) and wires the MCP stdio transport layer so omega-mcp can communicate with external processes. This sprint does NOT yet spawn Hermes — it prepares the Rust/Swift infrastructure that Hermes will connect to.

## Prerequisite Check

Before starting, verify the existing codebase compiles:

```bash
cargo check --manifest-path agent_core/Cargo.toml 2>&1 | tail -5
cargo test --manifest-path agent_core/Cargo.toml 2>&1 | tail -5
cargo test --manifest-path omega-mcp/Cargo.toml 2>&1 | tail -5
```

If any of these fail, FIX THEM before proceeding. Do not build on a broken foundation.

---

## Tasks (execute in order)

### Task 1: Add prompt_caching.rs to agent_core

**Create:** `agent_core/src/prompt_caching.rs`

This module places Anthropic `cache_control` breakpoints on the system prompt and strategic message positions. It cuts input token costs by ~85%.

**Implementation requirements:**
- `cache_system_prompt(system_text: &str) -> Value` — wraps system text in structured block with `cache_control: { type: "ephemeral" }`
- `apply_message_cache_breakpoints(messages: &mut [Value])` — stamps breakpoints on: first message (objective), third-to-last, and last message
- Helper `stamp_last_content_block(message: &mut Value)` — adds cache_control to the last content block of a message
- Maximum 4 breakpoints total (1 system + 3 messages)
- No new crate dependencies

**Wire into agent_core/src/lib.rs:**
```rust
pub mod prompt_caching;
```

**Wire into agent_core/src/providers/claude.rs:**
Replace the `MessagesRequest` struct body construction with `json!` macro that supports structured system format. Apply `prompt_caching::cache_system_prompt()` and `prompt_caching::apply_message_cache_breakpoints()` before sending.

**Tests required:** system prompt gets cache_control, single message gets breakpoint, 8-message conversation gets strategic breakpoints, empty messages doesn't panic.

**Verify:**
```bash
grep -c "cache_control" agent_core/src/prompt_caching.rs
grep -c "cache_system_prompt\|apply_message_cache" agent_core/src/providers/claude.rs
cargo test --manifest-path agent_core/Cargo.toml -- prompt_caching 2>&1 | tail -5
```

### Task 2: Add think.rs to agent_core tools

**Create:** `agent_core/src/tools/think.rs`

The "think" tool is Anthropic's documented zero-cost reasoning tool. It returns its input unchanged but gives the model a sanctioned way to pause and plan.

**Implementation requirements:**
- `THINK_TOOL_NAME: &str = "think"`
- `THINK_TOOL_DESCRIPTION` — instructs model to use for planning, analysis, error recovery
- `THINK_TOOL_SCHEMA` — JSON schema with required `thought` string field
- `execute_think(input: &Value) -> String` — returns thought text unchanged, handles missing/invalid input gracefully
- `think_tool_schema() -> ToolSchema` — for registration

**Wire into agent_core/src/tools/registry.rs:**
- Import think module
- Add think tool to `get_definitions()` — always include it
- Handle `"think"` in `execute()` match arm
- Classify as `RiskLevel::ReadOnly` in `get_risk_level()`

**Wire into agent_core/src/lib.rs** (if tools module doesn't already declare think):
```rust
pub mod tools {
    pub mod registry;
    pub mod think;
}
```

**Verify:**
```bash
grep -c "think" agent_core/src/tools/think.rs
grep "think" agent_core/src/tools/registry.rs | head -3
cargo test --manifest-path agent_core/Cargo.toml -- think 2>&1 | tail -5
```

### Task 3: Add compaction.rs to agent_core

**Create:** `agent_core/src/compaction.rs`

4-phase context compaction replacing the naive compact() in claude.rs.

**Implementation requirements:**
- Phase 1: BOUNDARY PROTECTION — never discard first message or last N messages
- Phase 2: TOOL RESULT REPLACEMENT — replace verbose old tool results with bounded excerpts (200 char limit)
- Phase 3: STRUCTURED SUMMARIZATION — compress middle into Goal/Progress/Tool Actions/Key Decisions format
- Phase 4: ITERATIVE FOLDING — detect and fold prior compaction summaries (marker prefix: `[Compacted Context]\n`)
- `compact_messages(messages: &[Message], recent_window: usize, max_context_chars: usize) -> Vec<Message>`
- Strip thinking blocks from compacted region (they served their purpose)
- Fix role alternation after compaction (merge consecutive same-role messages)
- Clean up orphaned tool results that reference compacted-away tool_use blocks

**Wire into agent_core/src/providers/claude.rs:**
Replace `compact()` method body:
```rust
async fn compact(&self, messages: &[Message]) -> Result<Vec<Message>, AgentError> {
    Ok(crate::compaction::compact_messages(messages, 8, 16_384))
}
```

**Wire into agent_core/src/lib.rs:**
```rust
pub mod compaction;
```

**Verify:**
```bash
grep -c "compact_messages" agent_core/src/compaction.rs
grep "compaction::compact" agent_core/src/providers/claude.rs
cargo test --manifest-path agent_core/Cargo.toml -- compaction 2>&1 | tail -5
```

### Task 4: Add security.rs to agent_core

**Create:** `agent_core/src/security.rs`

Credential redaction, dangerous command detection, tool output scanning.

**Implementation requirements:**
- `redact_credentials(text: &str) -> Cow<'_, str>` — prefix-matching for 16 known token formats (sk-ant-, sk-, ghp_, xoxb-, etc.) + PEM private key detection. Returns Cow::Borrowed when no credentials found (zero-alloc fast path).
- `classify_command_risk(command: &str) -> CommandRisk` — returns Safe/Moderate/Dangerous/Forbidden with reasons. Dangerous patterns: rm -rf, dd if=, mkfs, chmod -R 777, security dump-keychain. Forbidden: pipe-to-shell (curl|bash).
- `scan_tool_output(output: &str) -> ScanResult` — detects prompt injection markers, data exfiltration patterns, privilege escalation.
- `ApprovalScope` enum: Auto/Once/Session/Always/Deny
- No regex crate dependency — use prefix matching and string contains

**Wire into agent_core/src/agent_loop.rs:**
- Before bash/shell tool execution: `classify_command_risk()`, block if Forbidden, force approval if Dangerous
- After tool execution: `redact_credentials()` on output, `scan_tool_output()` and log warnings for High+ severity

**Wire into agent_core/src/lib.rs:**
```rust
pub mod security;
```

**Verify:**
```bash
grep -c "redact_credentials\|classify_command_risk\|scan_tool_output" agent_core/src/security.rs
grep "security::" agent_core/src/agent_loop.rs | head -3
cargo test --manifest-path agent_core/Cargo.toml -- security 2>&1 | tail -5
```

### Task 5: Add MCP stdio transport to omega-mcp

**Create:** `omega-mcp/src/transport.rs`

Add a newline-delimited JSON-RPC stdio transport layer so omega-mcp can communicate with external processes (preparation for Hermes bridge).

**Implementation requirements:**
- `StdioTransport` struct wrapping `tokio::io::BufReader<ChildStdout>` + `ChildStdin`
- `send(request: &str) -> Result<(), TransportError>` — write JSON + newline to stdin
- `receive() -> Result<String, TransportError>` — read one JSON line from stdout
- `StdioServer` that accepts incoming JSON-RPC on its own stdin/stdout (for when Epistemos IS the MCP server)
- Log all messages to the existing ExecutionLogger for auditability
- Never write non-JSON to stdout (preserve transport cleanliness)

**Wire into omega-mcp/src/lib.rs:**
```rust
pub mod transport;
```

**Tests required:** round-trip JSON-RPC encode/decode, newline delimiting, malformed JSON handling.

**Verify:**
```bash
[ -f omega-mcp/src/transport.rs ] && echo "✅ transport.rs exists" || echo "❌ MISSING"
grep -c "StdioTransport\|StdioServer" omega-mcp/src/transport.rs
cargo test --manifest-path omega-mcp/Cargo.toml 2>&1 | tail -5
```

### Task 6: Full compilation + test sweep

Run the complete verification suite. Everything must pass.

```bash
echo "=== Sprint Omega-1 Full Verification ==="

echo "--- Rust agent_core ---"
cargo check --manifest-path agent_core/Cargo.toml 2>&1 | tail -3
cargo test --manifest-path agent_core/Cargo.toml 2>&1 | tail -5

echo "--- Rust omega-mcp ---"
cargo check --manifest-path omega-mcp/Cargo.toml 2>&1 | tail -3
cargo test --manifest-path omega-mcp/Cargo.toml 2>&1 | tail -5

echo "--- Rust omega-ax ---"
cargo test --manifest-path omega-ax/Cargo.toml 2>&1 | tail -5

echo "--- New modules exist ---"
for f in \
  agent_core/src/prompt_caching.rs \
  agent_core/src/compaction.rs \
  agent_core/src/security.rs \
  agent_core/src/tools/think.rs \
  omega-mcp/src/transport.rs; do
  [ -f "$f" ] && echo "✅ $f" || echo "❌ MISSING: $f"
done

echo "--- New modules wired ---"
grep "prompt_caching\|compaction\|security" agent_core/src/lib.rs
grep "think" agent_core/src/tools/registry.rs | head -2
grep "transport" omega-mcp/src/lib.rs

echo "--- Critical integrations ---"
grep -c "cache_system_prompt\|apply_message_cache" agent_core/src/providers/claude.rs
grep -c "compaction::compact" agent_core/src/providers/claude.rs
grep -c "security::" agent_core/src/agent_loop.rs
grep -c "execute_think\|THINK_TOOL" agent_core/src/tools/registry.rs

echo "--- No regressions ---"
echo "agent_core tests:" && cargo test --manifest-path agent_core/Cargo.toml 2>&1 | grep -E "test result|FAILED"
echo "omega-mcp tests:" && cargo test --manifest-path omega-mcp/Cargo.toml 2>&1 | grep -E "test result|FAILED"
echo "omega-ax tests:" && cargo test --manifest-path omega-ax/Cargo.toml 2>&1 | grep -E "test result|FAILED"

echo "--- Swift build ---"
xcodebuild -quiet -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build 2>&1 | tail -5
```

If ANY check fails, fix it before marking Sprint Omega-1 complete.

---

## After Completing

1. Update docs/AGENT_PROGRESS.md — mark all Sprint Omega-1 tasks as ✅ with today's date
2. Commit with message: `feat(agent): Sprint Omega-1 — prompt caching, think tool, 4-phase compaction, security, MCP transport`
3. Proceed to Sprint Omega-2 (Hermes subprocess bridge) in a FRESH session

---

## Sprint Omega-2 Preview (next session)

Sprint Omega-2 adds the Hermes subprocess lifecycle:
- `Epistemos/Agent/HermesSubprocessManager.swift` — spawn/manage/kill hermes-agent via swift-subprocess
- `Epistemos/Agent/HermesMCPClient.swift` — MCP stdio client connecting to Hermes
- `Epistemos/Agent/EpistemosMCPServer.swift` — MCP stdio server exposing macOS tools to Hermes
- Pipe-based watchdog heartbeat for zombie prevention
- Process group management for clean shutdown
- Integration with AppBootstrap lifecycle

Sprint Omega-3 adds AXorcist-powered computer use:
- Replace raw AXUIElement code with AXorcist chainable queries
- Ghost OS-style MCP tool exposure (ghost_see, ghost_click, ghost_type patterns)
- ScreenCaptureKit pipeline with strict buffer dropping for <200ms latency
- TCC permission management UI

Sprint Omega-4 adds skills + memory + polish:
- SKILL.md progressive disclosure (metadata → instructions → resources)
- Post-task auto-skill creation
- 3-layer progressive memory retrieval
- Usage cost dashboard
- Slash-command palette (/plan, /research, /review)
