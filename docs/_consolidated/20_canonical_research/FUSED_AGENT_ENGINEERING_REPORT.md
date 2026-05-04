# Fused Agent Engineering Report

> **Index status**: CANONICAL-RESEARCH — Fusion of claw-code+OpenClaw+Hermes diagnosis; root-cause for tool-load failures (check_fn silent failures across 7 tool types).
> Classified in [`docs/_INDEX.md §14`](_INDEX.md). Copy in `docs/_consolidated/20_canonical_research/`.


## claw-code + OpenClaw + Hermes Diagnosis → Epistemos Upgrade Path

**Date:** 2026-03-31
**Sources analyzed:**
- `claw-code` (Rust reimplementation, 18K lines Rust)
- `openclaw-main` (Production gateway, TypeScript)
- `hermes-agent` (Your Python agent subprocess)
- `agent_core` (Your Rust agent crate)
- Epistemos Swift app (bridge, VM, subprocess manager)

---

## PART 1: WHY YOUR APP FEELS DUMB — ROOT CAUSE

### The Loop Works. The Tools Don't Load.

The hermes-agent loop at `run_agent.py:6302` IS correctly structured:
```
while api_call_count < max_iterations:
    response = api_call()
    if response.tool_calls:
        execute_tools()
        continue    # ← LOOPS CORRECTLY
    else:
        break       # ← Final text response
```

**The problem is upstream of the loop.** Tools are gated by `check_fn` callbacks:

| Tool | check_fn | Gate |
|------|----------|------|
| `read_file`, `write_file`, `patch`, `search_files` | `check_file_requirements()` | Requires `check_terminal_requirements()` to pass |
| `terminal`, `process` | `check_terminal_requirements()` | Requires local env OR remote SSH config |
| `web_search`, `web_extract` | `check_web_api_key()` | Requires `EXA_API_KEY` or `TAVILY_API_KEY` or `FIRECRAWL_API_KEY` |
| `browser_*` (11 tools) | `check_browser_requirements()` | Requires `agent-browser` CLI binary on PATH |
| `vision_analyze` | `check_vision_requirements()` | Requires vision model client |
| `execute_code` | `check_sandbox_requirements()` | Requires POSIX sandbox |
| `session_search` | `check_session_search_requirements()` | Requires `~/.hermes/` state DB |

**If `check_fn()` returns False, the tool is silently removed from the API request.**

The registry at `tools/registry.py:123-131`:
```python
if entry.check_fn:
    if entry.check_fn not in check_results:
        try:
            check_results[entry.check_fn] = bool(entry.check_fn())
        except Exception:
            check_results[entry.check_fn] = False  # ← SILENT FAILURE
    if not check_results[entry.check_fn]:
        continue  # ← TOOL SILENTLY DROPPED
```

### Most Likely Failure Chain

1. `check_terminal_requirements()` fails because the hermes subprocess environment doesn't have the expected env config
2. This causes `check_file_requirements()` to also fail (it delegates to terminal check)
3. ALL file tools + terminal tools are silently dropped
4. `check_web_api_key()` fails because no EXA/TAVILY/FIRECRAWL key is set
5. Web tools dropped
6. `check_browser_requirements()` fails because `agent-browser` isn't installed
7. Browser tools dropped
8. **Result: Model receives ZERO tools → produces plain text → loop breaks after 1 turn**

### How to Verify

Add this debug line to `epistemos_bridge.py` right after agent creation:
```python
import json
print(json.dumps([t["function"]["name"] for t in agent.tools], indent=2), file=sys.stderr)
```

If the list is empty or near-empty, that's your answer.

### How to Fix

1. **Set environment variables** before launching hermes subprocess:
   - `ANTHROPIC_API_KEY` (already handled via Keychain)
   - `TAVILY_API_KEY` or `EXA_API_KEY` for web search
   - Ensure `~/.hermes/` directory exists

2. **Ensure terminal check passes**: The `check_terminal_requirements()` at `terminal_tool.py:1186` checks `env_type == "local"` which should return True on macOS. If it's failing, the env config at `_get_env_config()` may be returning wrong values.

3. **Or bypass check_fn for core tools**: Register file/terminal tools without check_fn when running in ACP mode.

---

## PART 2: ENGINEERING PATTERNS TO STEAL

### From claw-code (Rust)

#### Pattern 1: Generic Trait-Based Agent Loop
**Source:** `claw-code/rust/crates/runtime/src/conversation.rs`

```rust
pub trait ApiClient {
    fn stream(&mut self, request: ApiRequest) -> Result<Vec<AssistantEvent>, RuntimeError>;
}
pub trait ToolExecutor {
    fn execute(&mut self, tool_name: &str, input: &str) -> Result<String, ToolError>;
}
pub struct ConversationRuntime<C: ApiClient, T: ToolExecutor> {
    session: Session,
    api_client: C,
    tool_executor: T,
    permission_policy: PermissionPolicy,
    max_iterations: usize,
}
```

**Why it's better:** Your `agent_core/src/agent_loop.rs` hardcodes the provider. This pattern lets you swap Claude/OpenAI/local without touching the loop.

**Port to:** `agent_core/src/agent_loop.rs` — extract traits for ApiClient and ToolExecutor.

#### Pattern 2: Standalone SSE Parser
**Source:** `claw-code/rust/crates/api/src/sse.rs` (~100 lines)

```rust
pub struct SseParser { buffer: Vec<u8> }
impl SseParser {
    pub fn push(&mut self, chunk: &[u8]) -> Result<Vec<StreamEvent>, ApiError> {
        // Handles partial frames, multi-event chunks, ping skipping
    }
}
```

**Why it's better:** Handles edge cases (partial frames split across TCP chunks, Windows line endings, [DONE] sentinel). Your SSE parsing is inline in the provider — extract it.

**Port to:** `agent_core/src/sse_parser.rs` (new file, ~100 lines)

#### Pattern 3: Context Compaction with Continuation Message
**Source:** `claw-code/rust/crates/runtime/src/compact.rs` (~350 lines)

Key innovation — the continuation message:
```
"This session is being continued from a previous conversation.
Here is a summary of what was discussed: {summary}
The most recent messages are preserved below.
Please continue naturally without re-summarizing."
```

Plus a `suppress_follow_up_questions` flag that prevents the model from asking "Is there anything else?" after compaction.

**Port to:** `agent_core/src/compaction.rs` — add continuation message pattern.

#### Pattern 4: Permission Prompter Trait
**Source:** `claw-code/rust/crates/runtime/src/permissions.rs` (~110 lines)

```rust
pub trait PermissionPrompter {
    fn decide(&mut self, request: &PermissionRequest) -> PermissionPromptDecision;
}
pub fn authorize(
    &self, tool_name: &str, input: &str,
    prompter: Option<&mut dyn PermissionPrompter>,
) -> PermissionOutcome
```

**Why it's better:** Same runtime works in interactive (REPL) and headless (daemon) mode via `Option<prompter>`.

**Port to:** `agent_core/src/security.rs` — add PermissionPrompter trait.

#### Pattern 5: Retryable Error Classification
**Source:** `claw-code/rust/crates/api/src/error.rs`

```rust
pub enum ApiError {
    Api { status, error_type, message, body, retryable: bool },
    RetriesExhausted { attempts, last_error: Box<ApiError> },
}
impl ApiError {
    pub fn is_retryable(&self) -> bool { ... }
}
```

**Why it's better:** Exponential backoff with retryability flags. Your provider just fails on first error.

**Port to:** `agent_core/src/providers/claude.rs` — add retry logic.

---

### From OpenClaw (TypeScript)

#### Pattern 6: Auth Profile Rotation with Cooldown
**Source:** `openclaw-main/src/agents/pi-embedded-runner/run.ts`

```
profileCandidates = resolveAuthProfileOrder(provider)
while profileIndex < candidates.length:
    try: applyApiKeyInfo(candidate); break
    catch: markCooldown(candidate, reason); profileIndex++
```

**Why it matters:** When you hit rate limits on one API key, automatically rotate to the next. Supports `ANTHROPIC_API_KEY_1`, `_2`, etc.

**Port to:** `agent_core/src/providers/` — add multi-key support.

#### Pattern 7: Context Overflow Detection + Auto-Compaction
**Source:** `openclaw-main/src/agents/pi-embedded-runner/run.ts` + `run/attempt.ts`

```
1. Detect: isLikelyContextOverflowError(errorText)
2. Compact: compactEmbeddedPiSession()
3. Truncate: truncateOversizedToolResultsInSession()
4. Retry with same model (max 3 attempts)
```

Pattern-matches error text for overflow indicators, then automatically compacts and retries.

**Port to:** `agent_core/src/agent_loop.rs` — catch overflow errors, trigger compaction, retry.

#### Pattern 8: MCP Tool Bundling at Runtime
**Source:** `openclaw-main/src/agents/pi-bundle-mcp-tools.ts`

```
for each mcpServer in config:
    transport = new StdioClientTransport(command, args, env)
    client = new Client().connect(transport)
    tools = await client.listTools()
    // Merge into agent's tool set with namespace prefix
    agentTools.push(...tools.map(t => wrapMcpTool(serverName, t)))
```

**Why it matters:** MCP servers discovered at boot, tools merged into agent's available set, executed via MCP protocol when called.

**Port to:** Your MCP bridge already exists — wire it into the tool registry so hermes-agent sees MCP tools.

#### Pattern 9: Gateway Daemon Architecture
**Source:** `openclaw-main/src/gateway/`

The "always-on" architecture:
```
Gateway (WebSocket server, port 18789)
├── Session Manager (named sessions, persistence)
├── Cron Scheduler (jobs.json, periodic agent runs)
├── Heartbeat (polling loop for monitoring)
├── Webhook Ingress (HTTP POST triggers agent)
├── Channel Router (WhatsApp/Telegram/Slack/etc)
└── Agent Runner (isolated or main-session turns)
```

**Port to Epistemos as:**
- `launchd` user service for always-on operation
- GRDB table for cron jobs
- Timer-based heartbeat in Swift
- Local HTTP server for webhooks (NIOCore or Vapor-lite)

#### Pattern 10: Skill Loading via Markdown
**Source:** `openclaw-main/skills/` + `openclaw-main/src/agents/skills/`

Skills are `.md` files with YAML frontmatter:
```yaml
---
name: github
description: "GitHub operations via gh CLI"
requires:
  bins: ["gh"]
---
# When the user asks about GitHub...
[domain-specific instructions for the LLM]
```

Loaded at boot, injected into system prompt. Agent uses them as context for tool decisions.

**Port to:** Store skill `.md` files in `~/.epistemos/skills/`. Parse frontmatter, inject into system prompt.

#### Pattern 11: Stream Wrapper Chain
**Source:** `openclaw-main/src/agents/pi-embedded-runner/run/attempt.ts`

```
streamFn
  → cache trace wrapper
  → thinking block dropper (if policy says drop)
  → tool call ID sanitizer
  → function call downgrader (for legacy APIs)
  → abort signal wrapper
  → back to session
```

Composable stream interceptors. Your `CoTStreamInterceptor.swift` does one layer — this pattern stacks multiple.

**Port to:** Make your stream pipeline composable in the Rust layer.

#### Pattern 12: Tool Result Truncation
**Source:** `openclaw-main/src/agents/pi-embedded-runner/`

When a tool returns a massive result (e.g., reading a huge file):
```
sessionLikelyHasOversizedToolResults() → true
truncateOversizedToolResultsInSession()
  → Keep first N chars + last N chars
  → Insert "[truncated]" marker
```

Prevents context overflow from greedy tool results.

**Port to:** `agent_core/src/tools/registry.rs` — add max_result_size parameter to tool execution.

---

### From Hermes-Agent (Python — your own codebase)

#### Pattern 13: Iteration Budget with Refunds
**Source:** `hermes-agent/run_agent.py:185-213`

```python
class IterationBudget:
    def consume(self) -> bool:  # Returns False if exhausted
    def refund(self):           # Give back iteration for cheap tools
```

`execute_code` gets refunded (cheap), but `terminal` does not (expensive). Prevents budget exhaustion on simple operations.

**Already in your codebase** — just make sure it's configured correctly.

#### Pattern 14: Tool Call Deduplication
**Source:** `hermes-agent/run_agent.py:7670-7675`

```python
assistant_message.tool_calls = self._cap_delegate_task_calls(tool_calls)
assistant_message.tool_calls = self._deduplicate_tool_calls(tool_calls)
```

Prevents the model from calling the same tool with same args twice in one turn.

**Already in your codebase** — working correctly.

---

## PART 3: THE FULL UPGRADE STACK

### Priority 0 — Make It Work (Hours, Not Days)

| Task | What | Why |
|------|------|-----|
| **Debug tool loading** | Add stderr logging to `get_tool_definitions()` to see which tools pass `check_fn` | You can't fix what you can't see |
| **Fix terminal check** | Ensure `check_terminal_requirements()` returns True in ACP mode | Unlocks ALL file tools + terminal |
| **Set web API keys** | Add `TAVILY_API_KEY` to hermes subprocess environment | Unlocks web_search + web_extract |
| **Verify tools reach API** | Log `len(self.tools)` before API call at `run_agent.py:6495` | Confirm tools are in the request |

### Priority 1 — Robust Agent (1-2 Weeks)

| Task | Source | Target |
|------|--------|--------|
| Retry with backoff | claw-code `error.rs` | `agent_core/src/providers/claude.rs` |
| Context overflow recovery | OpenClaw `run.ts` | `agent_core/src/agent_loop.rs` |
| Tool result truncation | OpenClaw `attempt.ts` | `agent_core/src/tools/` |
| Continuation compaction | claw-code `compact.rs` | `agent_core/src/compaction.rs` |
| Permission prompter trait | claw-code `permissions.rs` | `agent_core/src/security.rs` |

### Priority 2 — Always-On Daemon (2-3 Weeks)

| Task | Source | Target |
|------|--------|--------|
| launchd service | OpenClaw gateway | `Epistemos/Daemon/` |
| Cron scheduler | OpenClaw cron | GRDB `CronJob` table + timer |
| Heartbeat polling | OpenClaw heartbeat | Timer fires agent turn |
| Webhook ingress | OpenClaw webhooks | Local HTTP server |
| Named sessions | OpenClaw session manager | GRDB session persistence |

### Priority 3 — Tool Ecosystem (3-4 Weeks)

| Task | Source | Target |
|------|--------|--------|
| MCP tool bundling | OpenClaw `pi-bundle-mcp-tools.ts` | Wire MCP bridge → hermes tool registry |
| Skill markdown loading | OpenClaw `skills/` | `~/.epistemos/skills/*.md` |
| Browser CDP control | OpenClaw `browser-tool.ts` | Wire AXorcist as agent tool |
| Web fetch/scrape | OpenClaw `web-fetch` | URLSession + SwiftSoup tool |
| Auth profile rotation | OpenClaw `run.ts` | Multi-key support in providers |

### Priority 4 — Channel Integrations (4+ Weeks)

| Channel | Complexity | Value |
|---------|-----------|-------|
| iMessage (AppleScript) | Low | High for macOS users |
| Telegram bot | Medium | Universal, easy setup |
| Slack | Medium | Work automation |
| WhatsApp (Baileys) | High | Highest reach |

---

## PART 4: WHAT OPENCLAW CAN DO THAT YOU CAN'T (YET)

| Capability | OpenClaw | Epistemos | Gap |
|---|---|---|---|
| Multi-turn tool loop | Yes (30+ iterations) | Tools don't load → no loop | Fix check_fn gates |
| 24/7 daemon | Yes (systemd/launchd) | No daemon | Add launchd service |
| Cron jobs | Yes (persistent scheduler) | None | Add GRDB cron table |
| 23 messaging channels | Yes | None | Start with iMessage/Telegram |
| Browser automation | Yes (CDP) | AXorcist exists but unwired | Wire as agent tool |
| Phone calls | Via Twilio/VoIP integrations | None | Requires Twilio API |
| Video parsing | Via vision_analyze + frame extraction | ScreenCapture exists | Wire as tool |
| Web search | Tavily/Perplexity/Brave | Perplexity provider exists | Expose as tool |
| MCP servers | Runtime discovery + bundling | Bridge exists but disconnected | Wire to tool registry |
| Skills system | 50+ markdown skills | None | Add skill loader |
| Canvas/A2UI | Agent-driven React UI | Metal graph view (different) | Different paradigm |
| Device nodes | iOS/Android companion apps | macOS only | Future |
| Auth rotation | Multi-key failover | Single key | Add rotation |
| Context overflow recovery | Auto-compact + retry | Crash | Add recovery |

---

## PART 5: WHAT YOU HAVE THAT OPENCLAW DOESN'T

| Capability | Epistemos | OpenClaw |
|---|---|---|
| On-device LLM inference (MLX) | Yes | No |
| Metal compute shaders | Yes | No |
| Knowledge graph with GPU rendering | Yes | No |
| AXUIElement accessibility fusion | Yes (AXorcist) | Browser CDP only |
| ScreenCaptureKit integration | Yes | No |
| GRDB persistence with FTS | Yes | JSON files |
| PTY pool for sub-second execution | Yes | Child process per command |
| Rust FFI for performance-critical paths | Yes | Pure TypeScript |
| Note editor with TextKit | Yes | No |
| Graph memory with semantic search | Yes | Basic memory tool |

**You have the harder stuff built. You're missing the plumbing.**

---

## PART 6: RECOMMENDED ARCHITECTURE

```
┌─────────────────────────────────────────────────┐
│                 Epistemos App                    │
│  ┌──────────┐  ┌──────────┐  ┌──────────────┐  │
│  │  Graph    │  │  Notes   │  │  Agent Panel │  │
│  │  View     │  │  Editor  │  │  (chat UI)   │  │
│  └────┬─────┘  └────┬─────┘  └──────┬───────┘  │
│       │              │               │           │
│  ┌────┴──────────────┴───────────────┴───────┐  │
│  │         AgentViewModel (Swift)             │  │
│  │  - Routes user input to hermes subprocess  │  │
│  │  - Streams responses to UI                 │  │
│  │  - Handles permission dialogs              │  │
│  └─────────────────┬─────────────────────────┘  │
│                    │ stdio JSON-RPC              │
│  ┌─────────────────┴─────────────────────────┐  │
│  │     HermesSubprocessManager (Swift)        │  │
│  │  - Launches hermes-acp Python process      │  │
│  │  - Content-Length framing + SHM fallback   │  │
│  │  - MCP server for Swift-side tools         │  │
│  └─────────────────┬─────────────────────────┘  │
└────────────────────┼─────────────────────────────┘
                     │
┌────────────────────┴─────────────────────────────┐
│           hermes-agent (Python subprocess)        │
│  ┌────────────────────────────────────────────┐  │
│  │  Agent Loop (run_agent.py)                 │  │
│  │  while api_call_count < max_iterations:    │  │
│  │    response = stream_api_call(tools=...)   │  │
│  │    if response.tool_calls:                 │  │
│  │      results = execute_tools(tool_calls)   │  │
│  │      continue  ← MUST REACH HERE           │  │
│  │    else: break                             │  │
│  └────────────────┬───────────────────────────┘  │
│                   │                               │
│  ┌────────────────┴───────────────────────────┐  │
│  │  Tool Registry (tools/registry.py)         │  │
│  │  ┌─────────┐ ┌──────────┐ ┌────────────┐  │  │
│  │  │ terminal │ │ file ops │ │ web search │  │  │
│  │  │ process  │ │ read/    │ │ web extract│  │  │
│  │  │          │ │ write/   │ │            │  │  │
│  │  │          │ │ patch/   │ │            │  │  │
│  │  │          │ │ search   │ │            │  │  │
│  │  └─────────┘ └──────────┘ └────────────┘  │  │
│  │  ┌─────────┐ ┌──────────┐ ┌────────────┐  │  │
│  │  │ browser │ │ vision   │ │ MCP tools  │  │  │
│  │  │ (CDP)   │ │ analyze  │ │ (runtime)  │  │  │
│  │  └─────────┘ └──────────┘ └────────────┘  │  │
│  └────────────────────────────────────────────┘  │
│                                                   │
│  ┌────────────────────────────────────────────┐  │
│  │  NEW: Daemon Layer                         │  │
│  │  - Cron scheduler (GRDB-backed)            │  │
│  │  - Heartbeat timer                         │  │
│  │  - Webhook HTTP server                     │  │
│  │  - Session persistence                     │  │
│  └────────────────────────────────────────────┘  │
└───────────────────────────────────────────────────┘
```

---

## PART 7: IMMEDIATE ACTION CHECKLIST

### Today (30 minutes)

- [ ] Add debug logging to `hermes-agent/tools/registry.py:get_definitions()` — print which tools pass/fail check_fn to stderr
- [ ] Run Epistemos, send a prompt, check stderr for tool loading output
- [ ] Verify `check_terminal_requirements()` result in ACP mode

### This Week

- [ ] Fix tool check_fn failures (likely terminal env config)
- [ ] Set `TAVILY_API_KEY` or `EXA_API_KEY` in subprocess environment
- [ ] Verify model receives tools (log `len(self.tools)` before API call)
- [ ] Test multi-turn loop: ask agent to "read this file and summarize it"

### Next Week

- [ ] Port claw-code retry logic to agent_core providers
- [ ] Add context overflow recovery (detect + compact + retry)
- [ ] Add tool result truncation
- [ ] Wire MCP bridge tools into hermes tool registry

### Month 1

- [ ] Add launchd daemon for always-on operation
- [ ] Add GRDB-backed cron scheduler
- [ ] Add heartbeat timer
- [ ] Add skill markdown loader
- [ ] Add iMessage channel (AppleScript)

### Month 2

- [ ] Add webhook HTTP ingress
- [ ] Add Telegram bot channel
- [ ] Wire AXorcist as browser-like agent tool
- [ ] Add auth profile rotation
- [ ] Wire ScreenCapture as vision tool
