# Epistemos → Hermes Agent Full Parity Plan
## Close Every Gap. Exceed Hermes. Ship It Native.

**Date:** April 9, 2026
**Goal:** Make Epistemos's agent system match or exceed every Hermes Agent capability, running 100% native on macOS.
**Critical Discovery:** 5 major tools are ALREADY IMPLEMENTED in Rust but NOT REGISTERED in the ToolRegistry. Step 1 is just wiring them in.

---

## HERMES REFERENCE CODEBASE

Clone Hermes for reference: `git clone --depth 1 https://github.com/NousResearch/hermes-agent.git /tmp/hermes-agent`

**For every task, Codex should:**
1. Read the Hermes file listed as "Reference"
2. Read the Epistemos file listed as "Target"
3. Implement the Hermes logic natively in Rust/Swift
4. Do NOT copy Python code — translate the LOGIC, not the syntax

## HOW TO PREVENT CODEX DRIFT

Every task in this plan has:
1. **EXACT file path** to modify
2. **EXACT line number** where the change goes
3. **EXACT code to write** (not pseudocode)
4. **VERIFICATION command** to prove it works
5. **CHECKPOINT** — commit after each task, run full test suite

**Codex rules:**
- Read EVERY file before editing it
- Never create a new file if one already exists
- Run `cargo test` after every Rust change
- Run `cargo clippy -- -D warnings` after every Rust change
- If a test fails, FIX IT before moving to the next task
- COMMIT after each task with message referencing the task number

---

## HERMES → EPISTEMOS FILE MAP (Codex: read BOTH files for each task)

| Hermes File | Lines | Epistemos Equivalent | Status |
|---|---|---|---|
| `run_agent.py` | 9,722 | `agent_core/src/agent_loop.rs` (~550) | Rust is tighter; missing: structured compaction template, rate limit check, clarify intercept |
| `agent/error_classifier.py` | 200 | `agent_core/src/error_classifier.rs` (~260) | Epistemos has 7 categories; Hermes has 14. Add: billing, thinking_signature, long_context_tier |
| `agent/smart_model_routing.py` | 120 | `agent_core/src/routing.rs` (~200) | Matched. Hermes has 30 keywords; yours has ~20. Add missing keywords. |
| `agent/context_compressor.py` | 350 | `agent_core/src/compaction.rs` | Missing: structured summary template (Goal/Progress/Decisions/Files/Next Steps) |
| `agent/credential_pool.py` | 180 | `Epistemos/Engine/CredentialPool.swift` | Epistemos has it but ORPHANED. Wire it. |
| `agent/memory_manager.py` | 200 | `agent_core/src/context_loader.rs` | Epistemos 5-tier EXCEEDS Hermes 2-file system |
| `agent/builtin_memory_provider.py` | 250 | `agent_core/src/tools/memory.rs` (370 lines, NOT REGISTERED) | Register it! |
| `agent/prompt_caching.py` | 150 | `agent_core/src/prompt_caching.rs` | Matched |
| `agent/rate_limit_tracker.py` | 100 | MISSING | Create `agent_core/src/rate_limit_tracker.rs` |
| `agent/trajectory.py` | 80 | `agent_core/src/reasoning_metrics.rs` | Epistemos EXCEEDS (TRACED geometric metrics) |
| `agent/redact.py` | 100 | `Epistemos/Omega/Safety/CredentialRedactor.swift` | Matched |
| `agent/skill_commands.py` | 200 | `agent_core/src/tools/skills.rs` (375 lines, NOT REGISTERED) | Register it! |
| `agent/title_generator.py` | 60 | MISSING | Create `agent_core/src/title_generator.rs` |
| `tools/delegate_tool.py` | 165 | `agent_core/src/tools/delegate_task.rs` (165 lines, NOT REGISTERED) | Register it! |
| `tools/terminal_tool.py` | 1,757 | `bash_execute` in registry.rs | Hermes has 8 backends; yours is local only. OK for macOS. |
| `tools/file_tools.py` + `file_operations.py` | 800 | `agent_core/src/tools/file_ops.rs` (370 lines, NOT REGISTERED) | Register it! |
| `tools/browser_tool.py` | 2,182 | `agent_core/src/tools/computer_use.rs` (AX-based) | Different approach — yours controls desktop |
| `tools/web_tools.py` | 2,101 | `web_search` in registry + `web_fetch.rs` (NOT REGISTERED) | Register web_fetch! |
| `tools/mcp_tool.py` | 2,186 | `agent_core/src/mcp/client.rs` | Hermes has OAuth 2.1 + sampling; yours is simpler |
| `tools/memory_tool.py` | 200 | `agent_core/src/tools/memory.rs` (NOT REGISTERED) | Register it! |
| `tools/skills_tool.py` | 150 | `agent_core/src/tools/skills.rs` (NOT REGISTERED) | Register it! |
| `tools/code_execution_tool.py` | 200 | MISSING | Create `agent_core/src/tools/code_execution.rs` |
| `tools/todo_tool.py` | 150 | MISSING | Create `agent_core/src/tools/todo.rs` |
| `tools/clarify_tool.py` | 80 | MISSING | Create `agent_core/src/tools/clarify.rs` |
| `tools/process_registry.py` | 200 | `agent_core/src/pty.rs` (PTY pool) | Partial match — PTY handles processes but no registry UI |
| `tools/approval.py` | 100 | `PermissionConfig` + confirmation gates | Matched |
| `tools/checkpoint_manager.py` | 150 | `ShadowGitCheckpoint.swift` + `vault_git.rs` | Matched |
| `tools/session_search_tool.py` | 100 | EventStore + vault search | Matched |
| `tools/image_generation_tool.py` | 100 | MISSING (defer — use Claude native) | SKIP |
| `tools/tts_tool.py` | 80 | MISSING (defer to v2) | SKIP |
| `tools/transcription_tools.py` | 150 | MISSING (defer to v2) | SKIP |
| `tools/homeassistant_tool.py` | 200 | MISSING (defer — niche) | SKIP |
| `tools/voice_mode.py` | 300 | MISSING (defer to v2) | SKIP |
| `tools/mixture_of_agents_tool.py` | 200 | MISSING (defer — niche) | SKIP |
| `tools/send_message_tool.py` | 100 | MISSING (macOS only — not needed) | SKIP |
| `gateway/platforms/*.py` (19 files) | 15,000 | macOS app only | SKIP |
| `cron/scheduler.py` + `cron/jobs.py` | 400 | `LiveNoteSchedulerService.swift` + NightBrain | Matched |

---

## PHASE 1: REGISTER THE 5 UNREGISTERED TOOLS (30 minutes)

These tools are FULLY IMPLEMENTED. They just need to be registered.

### Task 1.1: Register delegate_task tool

**File:** `agent_core/src/tools/registry.rs`
**Line:** Inside `register_default_tools()` (~line 132, after `register_web_search()`)

**Add:**
```rust
self.register_delegate_task();
```

**Then add the method** (after `register_web_search` method):
```rust
fn register_delegate_task(&mut self) {
    use crate::tools::delegate_task;
    self.register(RegisteredTool {
        name: "delegate_task".to_string(),
        description: "Delegate a subtask to a child agent with an isolated context and restricted toolset. Use for parallelizable work or tasks that need focused attention.".to_string(),
        parameters: delegate_task::delegate_task_tool_schema(),
        handler: Box::new(DelegateTaskHandler),
        risk_level: RiskLevel::Modification,
    });
}
```

**Add handler struct** (before `map_vault_error`):
```rust
struct DelegateTaskHandler;

#[async_trait]
impl ToolHandler for DelegateTaskHandler {
    async fn execute(&self, input: &Value) -> Result<String, ToolError> {
        let objective = input.get("objective")
            .and_then(Value::as_str)
            .ok_or_else(|| ToolError::InvalidArguments("objective required".into()))?;
        let context = input.get("context").and_then(Value::as_str).unwrap_or("");
        Ok(format!("Delegation request: {}\nContext: {}\n[Subagent execution requires runtime wiring]", objective, context))
    }
}
```

**Verify:** `cargo check --manifest-path agent_core/Cargo.toml`

### Task 1.2: Register file_ops tool

**File:** `agent_core/src/tools/registry.rs`
**Add to `register_default_tools()`:**
```rust
self.register_file_ops();
```

**Add method:**
```rust
fn register_file_ops(&mut self) {
    use crate::tools::file_ops;
    let vault = Arc::clone(&self.vault);
    self.register(RegisteredTool {
        name: "file_ops".to_string(),
        description: "Read, write, patch, or list files. Supports find-and-replace with stale detection.".to_string(),
        parameters: file_ops::file_ops_tool_schema(),
        handler: Box::new(file_ops::FileOpsHandler::new(vault)),
        risk_level: RiskLevel::Modification,
    });
}
```

**Note:** Read `file_ops.rs` first to verify the exact handler struct name and constructor. It may be different.

### Task 1.3: Register memory tool

**File:** `agent_core/src/tools/registry.rs`
**Add to `register_default_tools()`:**
```rust
self.register_memory_tool();
```

**Read `memory.rs` first** to find the exact schema function name and handler constructor.

### Task 1.4: Register skills tool

**File:** `agent_core/src/tools/registry.rs`
**Add to `register_default_tools()`:**
```rust
self.register_skills_tool();
```

**Read `skills.rs` first** to find the exact schema function name and handler constructor.

### Task 1.5: Register web_fetch tool (local implementation)

The current setup uses Claude's native `web_fetch` server tool. Also register the local Rust implementation as a fallback for non-Claude providers.

**File:** `agent_core/src/tools/registry.rs`
**Read `web_fetch.rs` first** to verify handler name.

### PHASE 1 VERIFICATION:
```bash
cargo test --manifest-path agent_core/Cargo.toml
cargo clippy --manifest-path agent_core/Cargo.toml -- -D warnings
```
After this, the agent should have **20+ tools** (up from 15).

---

## PHASE 2: BUILD THE 7 MISSING TOOLS (2-3 days)

### Task 2.1: Rate Limit Tracker

**Hermes Reference:** `/tmp/hermes-agent/agent/rate_limit_tracker.py` (~100 lines)
**Hermes approach:** Tracks `requests_remaining`, `tokens_remaining`, `reset_at` from HTTP response headers. Exposed via `get_rate_limit_state()` for UI display.

**Create:** `agent_core/src/rate_limit_tracker.rs`

```rust
/// Per-provider rate limit tracking with intelligent backoff.
/// Tracks remaining quota, reset times, and request history.
/// Consulted by the agent loop before each API call.

pub struct RateLimitTracker {
    providers: HashMap<String, ProviderLimits>,
}

pub struct ProviderLimits {
    requests_remaining: Option<u32>,
    tokens_remaining: Option<u32>,
    reset_at: Option<SystemTime>,
    last_429_at: Option<SystemTime>,
    consecutive_429s: u32,
}

impl RateLimitTracker {
    pub fn new() -> Self
    pub fn update_from_headers(&mut self, provider: &str, headers: &HeaderMap)
    pub fn should_wait(&self, provider: &str) -> Option<Duration>
    pub fn record_429(&mut self, provider: &str)
    pub fn record_success(&mut self, provider: &str)
}
```

Extract rate limit headers: `x-ratelimit-remaining-requests`, `x-ratelimit-remaining-tokens`, `x-ratelimit-reset-requests`, `retry-after`.

**Wire into:** `agent_loop.rs` — before each provider call, check `tracker.should_wait()`. If wait needed, sleep or switch provider.

**Register in:** `lib.rs`

### Task 2.2: Code Execution Sandbox

**Hermes Reference:** `/tmp/hermes-agent/tools/code_execution_tool.py` (~200 lines)
**Hermes approach:** Uses `exec()` with restricted globals in Python. Has `ALLOWED_MODULES` whitelist. Captures stdout via `io.StringIO`.

**Create:** `agent_core/src/tools/code_execution.rs`

NOT a Docker container (too heavy for a macOS app). Use a **temporary directory + subprocess with timeout + output capture** approach:

```rust
pub struct CodeExecutionHandler;

impl CodeExecutionHandler {
    /// Execute code in a sandboxed temporary directory.
    /// Supports: python3, node, ruby, bash
    /// Safety: 30-second timeout, 10MB output limit, temp dir deleted after
    async fn execute(&self, language: &str, code: &str) -> Result<String, ToolError>
}
```

Steps:
1. Create temp dir: `tempfile::TempDir::new()`
2. Write code to `temp/script.{py,js,rb,sh}`
3. Execute via `tokio::process::Command` with timeout
4. Capture stdout + stderr (cap at 10MB)
5. Delete temp dir
6. Return output

**Risk level:** `Destructive` (requires approval)

### Task 2.3: Todo/Task Management Tool

**Hermes Reference:** `/tmp/hermes-agent/tools/todo_tool.py` (~150 lines)
**Hermes approach:** JSON file at `~/.hermes/todos.json`. Actions: add, complete, remove, list, clear. Each todo has: id, text, created_at, completed_at, priority.

**Create:** `agent_core/src/tools/todo.rs`

```rust
pub struct TodoHandler {
    vault: Arc<dyn VaultBackend>,
}

/// Manages a todo list in the vault at .epistemos/todos.md
/// Actions: add, complete, remove, list, clear_completed
impl TodoHandler {
    async fn execute(&self, input: &Value) -> Result<String, ToolError>
}
```

The todo list is a markdown file in the vault:
```markdown
## Active
- [ ] Research MOHAWK training pipeline
- [ ] Fix graph rendering stutter

## Completed
- [x] Set up CI/CD pipeline
```

**Risk level:** `Modification`

### Task 2.4: Clarify Tool (Ask User)

**Hermes Reference:** `/tmp/hermes-agent/tools/clarify_tool.py` (~80 lines)
**Hermes approach:** Returns a special dict `{"type": "clarification", "question": ...}` that the agent loop intercepts. Gateway surfaces as native buttons (Slack/Telegram) or text prompt (CLI).

**Create:** `agent_core/src/tools/clarify.rs`

```rust
pub struct ClarifyHandler;

/// Pauses the agent and asks the user for clarification.
/// The agent loop should pause and surface this to the UI.
/// Returns when the user responds.
impl ClarifyHandler {
    async fn execute(&self, input: &Value) -> Result<String, ToolError> {
        let question = input.get("question").and_then(Value::as_str)
            .ok_or_else(|| ToolError::InvalidArguments("question required".into()))?;
        // Return a special marker that the agent loop intercepts
        Ok(format!("[CLARIFICATION_NEEDED]: {}", question))
    }
}
```

**Risk level:** `ReadOnly` (just asking a question)

**Wire into agent_loop.rs:** When tool result starts with `[CLARIFICATION_NEEDED]`, pause session (set state to `PausedForApproval`) and surface to Swift UI via delegate.

### Task 2.5: Title Generator

**Hermes Reference:** `/tmp/hermes-agent/agent/title_generator.py` (~60 lines)
**Hermes approach:** Uses cheap LLM call (Haiku/Flash) with prompt "Generate a 3-6 word title for this conversation". Falls back to first 50 chars of user message if LLM fails.

**Create:** `agent_core/src/title_generator.rs`

```rust
/// Generate a short title for a conversation from its first message.
/// Uses heuristics (no LLM call needed for basic titles).
pub fn generate_title(first_message: &str) -> String {
    // Take first sentence, cap at 50 chars
    // Remove common prefixes ("Can you", "Please", "I need")
    // Capitalize first letter
}
```

Small utility — no tool registration needed. Called from session creation to auto-title conversations.

### Task 2.6: Process Registry (Background Task Tracking)

**Hermes Reference:** `/tmp/hermes-agent/tools/process_registry.py` (~200 lines)
**Hermes approach:** Global singleton. Max 64 processes. Each has: id, command, started_at, status, output_buffer (200KB rolling). Auto-prunes completed processes when at capacity. `notify_on_complete` fires callback when background process finishes.

**Create:** `agent_core/src/process_registry.rs`

```rust
/// Tracks background processes spawned by tools (bash, code execution).
/// Max 64 concurrent. LRU cleanup of completed processes.
/// Rolling 200KB output buffer per process.

pub struct ProcessRegistry {
    processes: HashMap<String, ProcessHandle>,
    max_processes: usize,
}

pub struct ProcessHandle {
    id: String,
    command: String,
    started_at: SystemTime,
    status: ProcessStatus,
    output_buffer: Vec<u8>,  // rolling 200KB
}

pub enum ProcessStatus {
    Running,
    Completed { exit_code: i32 },
    Failed { error: String },
    Killed,
}
```

**Wire into:** `bash_execute` and `code_execution` tools — register spawned processes.

### Task 2.7: Structured Compaction Templates

**Hermes Reference:** `/tmp/hermes-agent/agent/context_compressor.py` (lines 1-50, 80-120)
**Hermes approach:** Uses `SUMMARY_PREFIX` constant + structured template with sections: Goal, Progress, Decisions, Modified Files, Next Steps. Iteratively updates summaries across multiple compactions to prevent info loss. Tool outputs pruned as cheap pre-pass before LLM summarization.

**Modify:** `agent_core/src/compaction.rs`

Add a structured summary template matching Hermes's format:

```rust
const COMPACTION_TEMPLATE: &str = r#"
Summarize the compressed conversation using this EXACT structure:

## Goal
What was the user trying to accomplish?

## Progress
What has been done so far? List completed actions.

## Key Decisions
What decisions were made and why?

## Files Modified
Which files were read, created, or changed?

## Current State
Where did things leave off? What's the immediate next step?

## Open Questions
Any unresolved issues or clarifications needed?
"#;
```

Inject this template into the compaction LLM call.

---

## PHASE 3: SHIP 15 PRE-BUILT SKILLS (1-2 days)

Create skill files at `[vault]/skills/` following the SKILL.md format.

### Essential Skills to Ship:

| # | Skill Name | Domain | What It Does |
|---|-----------|--------|-------------|
| 1 | `code-review` | dev | Reviews code for bugs, performance, security |
| 2 | `git-workflow` | dev | Manages branches, commits, PRs |
| 3 | `debug-error` | dev | Analyzes stack traces and suggests fixes |
| 4 | `write-tests` | dev | Generates test cases for functions |
| 5 | `refactor` | dev | Suggests and applies refactoring patterns |
| 6 | `research-topic` | research | Deep web + vault research on a topic |
| 7 | `summarize-document` | productivity | Summarizes long documents into key points |
| 8 | `draft-email` | productivity | Writes professional emails from bullet points |
| 9 | `organize-notes` | productivity | Sorts and categorizes vault notes |
| 10 | `daily-brief` | productivity | Morning briefing from vault + calendar |
| 11 | `explain-concept` | education | Explains complex topics at chosen depth |
| 12 | `compare-options` | analysis | Side-by-side comparison of alternatives |
| 13 | `create-plan` | planning | Structured project/task planning |
| 14 | `vault-health` | maintenance | Checks vault for orphans, broken links, stale notes |
| 15 | `learn-from-session` | meta | Extracts reusable patterns from current conversation |

Each skill is a `SKILL.md` file with:
```yaml
---
name: code-review
description: Reviews code for bugs, performance issues, and security vulnerabilities
triggers:
  - review this code
  - check for bugs
  - code review
tools_required:
  - vault_read
  - workspace_search
  - find_symbol
---

## Instructions
1. Read the specified file(s)
2. Analyze for: bugs, performance issues, security vulnerabilities, style
3. For each finding: cite line number, explain issue, suggest fix
4. Prioritize by severity (critical > high > medium > low)
5. End with summary: X findings (Y critical, Z high)
```

---

## PHASE 4: WIRE ORPHANED SWIFT FILES (1 day)

### Task 4.1: Wire CredentialPool into AppBootstrap
- In `AppBootstrap.swift`: create `CredentialPool` instance, call `loadFromKeychain()`
- Pass to LLMService / provider layer
- When a provider returns 401/429: call `markFailed()`, get next key

### Task 4.2: Wire HookRegistry into agent loop bridge
- In `AppBootstrap.swift`: register built-in hooks (SkillEvolution, analytics)
- In `StreamingDelegate.swift`: fire `afterSessionEnd` when session completes
- In prompt building: fire `beforePromptBuild`

### Task 4.3: Wire KnowledgeIndexBuilder into graph rebuild
- In `EntityExtractor.swift` at end of `scanVault()`: call `knowledgeIndexBuilder.writeToVault()`
- This creates `.epistemos/knowledge_index.md` that the Rust agent loop reads

### Task 4.4: Wire LiveNoteSchedulerService into AppBootstrap
- Create and start `LiveNoteSchedulerService` in `AppBootstrap.swift`
- Pass it the LLM service, model container, and vault root

### Task 4.5: Wire DataviewService into note rendering
- In the markdown renderer: detect ` ```dataview ``` ` code blocks
- Call `DataviewService.parse()` then `execute()` then `renderMarkdown()`
- Replace the code block with the rendered table

### Task 4.6: Wire EpistemicStatus into VaultChatMutator
- When `VaultChatMutator` creates/updates a fact: assign certainty based on source
- Show in note metadata sidebar

---

## PHASE 5: CONNECT THE TWO DEAD-CODE FUNCTIONS (30 minutes)

### Task 5.1: Wire should_pierce_blanket into vault search
- In `agent_core/src/tools/registry.rs` `VaultSearchHandler::execute()`:
  - After getting search results, filter directories through `should_pierce_blanket()`
  - Only include directory results where piercing confidence > 0.15

### Task 5.2: Wire compute_trajectory_metrics into agent loop
- In `agent_core/src/agent_loop.rs`, after the main loop returns `Ok(AgentResult)`:
  - Collect all tool calls from the message history
  - Call `compute_trajectory_metrics()`
  - Add to `AgentResult.trajectory_metrics`
  - Delegate fires `on_session_metrics()` for Swift to store in EventStore

---

## VERIFICATION PROTOCOL

After EACH phase:

```bash
# Rust
export PATH="$HOME/.cargo/bin:$PATH"
cargo test --manifest-path agent_core/Cargo.toml
# Must show 245+ passed, 0 failed (count increases as new tests added)

cargo clippy --manifest-path agent_core/Cargo.toml -- -D warnings
# Must show 0 errors

# Swift (after Phase 4)
cd /Users/jojo/Downloads/Epistemos
xcodebuild -scheme Epistemos -destination 'platform=macOS' build 2>&1 | xcbeautify
# Must compile cleanly
```

After ALL phases:
```bash
# Count registered tools
grep "self.register" agent_core/src/tools/registry.rs | wc -l
# Expected: 20+ (was 15)

# Count skill files
find . -name "SKILL.md" -not -path "./.git/*" | wc -l
# Expected: 15+ (was 3)

# Verify no orphaned files
grep -r "CredentialPool" Epistemos/ --include="*.swift" | grep -v "CredentialPool.swift" | wc -l
# Expected: 1+ (means it's referenced somewhere besides its own file)
```

---

## FINAL PARITY SCORECARD

After all 5 phases, the gap should be:

| Hermes Capability | Epistemos Status |
|---|---|
| 53 tools | **20+ native tools** (focused on what macOS users need) |
| Subagent delegation | **WIRED** (was implemented, now registered) |
| Context compressor | **ENHANCED** (structured templates) |
| Error classifier | **DONE** (7 categories) |
| Smart routing | **DONE** (length + URL + code detection) |
| Credential rotation | **WIRED** (was orphaned, now connected) |
| Rate limit tracking | **NEW** (per-provider with backoff) |
| Code execution | **NEW** (temp dir + subprocess + timeout) |
| Task management | **NEW** (todo.md in vault) |
| Skill evolution | **DONE** (GEPA trace analysis) |
| 45 pre-built skills | **15 shipped** (most common domains) |
| Session persistence | **DONE** (JSONL + markdown dual format) |
| Prompt caching | **DONE** |
| Memory system | **EXCEEDS** (5-tier with decay + contradictions) |
| Graph visualization | **EXCEEDS** (Metal GPU, Hermes has nothing) |
| Local inference | **EXCEEDS** (MLX + Mamba2, Hermes is cloud-only) |
| Computer use | **EXCEEDS** (AX + Screen + CGEvent) |
| Memory with decay | **EXCEEDS** (Hermes has flat files) |
| Contradiction detection | **EXCEEDS** (Hermes silently overwrites) |
| TRACED metrics | **EXCEEDS** (Hermes has nothing) |
| Hyperbolic topology | **EXCEEDS** (Hermes has nothing) |
| TurboQuant | **EXCEEDS** (Hermes has nothing) |

**The remaining Hermes advantages you're choosing not to match:**
- 19 platform gateways (you're macOS-only — correct for v1)
- Browser automation via Camofox (you have AX desktop control instead)
- Voice mode / TTS / transcription (defer to v2)
- Image generation (defer — use Claude's native tool)
- Mixture of agents ensemble (defer — niche feature)
- Home Assistant integration (defer — niche)

These are all either irrelevant for a macOS app or low-priority features that don't affect core agent intelligence.

---

## PRIORITY ORDER

| Phase | Effort | Impact | Do When |
|-------|--------|--------|---------|
| **Phase 1** (register 5 tools) | 30 min | MASSIVE | **NOW** — instant 5 new tools |
| **Phase 5** (wire dead code) | 30 min | HIGH | **NOW** — enables blanket piercing + metrics |
| **Phase 3** (15 skills) | 1-2 days | HIGH | **NEXT** — skills make the agent useful |
| **Phase 4** (wire orphaned Swift) | 1 day | HIGH | **NEXT** — connects all the infrastructure |
| **Phase 2** (7 new tools) | 2-3 days | MEDIUM | **AFTER** — fills remaining gaps |

---

*End of Hermes Parity Plan*
