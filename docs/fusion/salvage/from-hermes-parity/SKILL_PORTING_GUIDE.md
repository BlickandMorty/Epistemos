# Complete Skill Porting Guide: OpenClaw + Hermes → Epistemos Rust

> **Generated:** 2026-04-09  
> **Sources:** `docs/BEST_OF_CLAW_AND_OPENCLAW.md`, `docs/OPENCLAW_FEATURE_SPEC.md`, `docs/FUSED_AGENT_ENGINEERING_REPORT.md`, `docs/HERMES_INTEGRATION_RESEARCH.md`, `docs/COMPREHENSIVE_AGENT_AUDIT_SYNTHESIS.md`, `docs/CONTROL_PLANE_RESEARCH.md`, `docs/AGENT_INTEGRATION_SESSION_PLAN.md`, `docs/AGENT_FUSION_RESEARCH_PROMPT.md`, `tmp/hermes-agent-upstream/` (full codebase), `COMPREHENSIVE_AGENT_AUDIT_SYNTHESIS.md`

---

# Part 1: OpenClaw Skills & Patterns

OpenClaw is a TypeScript/Node.js gateway-centric agent framework. Its "skills" are better understood as **architectural patterns, safety primitives, and orchestration capabilities** rather than discrete MCP-style tools. The actual bundled skills directory (`openclaw-main/skills/`) contains 50+ domain-specific markdown skill files, but their contents are not available in the accessible repo. Below are all the **orchestration primitives, safety features, and architectural capabilities** extracted from the OpenClaw analysis documents.

---

### 1. Tool Loop Detection
- **Description:** Detects when the agent gets stuck calling the same tool with identical arguments repeatedly, or oscillating between two tool calls (ping-pong pattern). Has three escalation levels: warning → critical → circuit breaker.
- **Parameters:** `historySize` (30), `warningThreshold` (5), `criticalThreshold` (10), `circuitBreakerThreshold` (15), `toolName`, `argsHash` (SHA-256 of sorted JSON), `resultHash`
- **Complexity:** Medium
- **Port Difficulty:** Easy
- **Porting Notes:** Pure logic with no external dependencies. Already partially implemented in `Epistemos/Omega/Safety/ToolLoopDetector.swift`. Port the remaining detector kinds: `pollNoProgress` (same args+same result), `pingPong` (alternating patterns), and `circuitBreaker` (global hard stop).

### 2. Context Budget Manager
- **Description:** Tracks cumulative token usage across multi-step plan execution. When approaching the model's context window limit, proactively summarizes earlier steps to free budget. Prevents truncated context hallucinations.
- **Parameters:** `contextWindowTokens`, `compactionThreshold` (0.70), `warningThreshold` (0.90), `safetyMargin` (1.2), `stepIndex`, `toolName`, `promptTokens`, `completionTokens`, `resultSnippet`
- **Complexity:** Medium
- **Port Difficulty:** Easy
- **Porting Notes:** Uses `text.utf8.count / 4` for token estimation (same heuristic as OpenClaw). Calls MLX inference service for summarization. Already in `Epistemos/Omega/Safety/ContextBudgetManager.swift`.

### 3. Execution Checkpoint & Resume
- **Description:** Persists step completion state during plan execution so that if the app crashes or the user force-quits mid-plan, the agent can resume from the last completed step instead of starting over.
- **Parameters:** `planId`, `planDescription`, `steps[]` (with `status`: pending/running/completed/failed/skipped), `lastCompletedIndex`, `createdAt`, `updatedAt`, `resultSnippet`, `error`
- **Complexity:** Medium
- **Port Difficulty:** Easy
- **Porting Notes:** Uses atomic temp-file + rename writes. Stores in `~/Library/Application Support/Epistemos/checkpoints/`. Cleanup of stale checkpoints (>24h). Already in `Epistemos/Omega/Safety/ExecutionCheckpointManager.swift`.

### 4. Agent Depth Limiter
- **Description:** Prevents infinite delegation loops when agents spawn sub-tasks that spawn further sub-tasks. Enforces a maximum recursion depth (default 3).
- **Parameters:** `maxDepth` (3), `currentDepth`, `depthStack` (plan ID stack), `canDelegate`
- **Complexity:** Simple
- **Port Difficulty:** Easy
- **Porting Notes:** Pure stack-based logic. Push on plan start, pop on completion (with `defer`). Already in `Epistemos/Omega/Safety/AgentDepthLimiter.swift`.

### 5. Memory Recall Diversification (MMR)
- **Description:** Re-ranks memory recall results to balance relevance with diversity. Prevents the agent from getting 5 near-duplicate results about the same topic.
- **Parameters:** `lambda` (0.7), `items[]` (with `id`, `score`, `content`), `relevance` (normalized fuzzy score), `similarity` (Jaccard of tokenized content)
- **Complexity:** Medium
- **Port Difficulty:** Easy
- **Porting Notes:** Jaccard similarity on alphanumeric token sets. Over-fetch 2× limit, rerank, trim. Already in `Epistemos/Omega/Safety/MMRReranker.swift`.

### 6. Execution Transcript Repair
- **Description:** When the LLM generates malformed tool calls (missing IDs, orphaned results, duplicated results), repairs the transcript before resuming conversation or persisting.
- **Parameters:** `toolCall` (id, name, args), `toolResult` (toolCallId, content, isError), `repairedMessages[]`, `insertedSyntheticResults`, `droppedDuplicates`, `droppedOrphans`
- **Complexity:** Medium
- **Port Difficulty:** Easy
- **Porting Notes:** Linear scan pairing calls with results. Insert synthetic error for unmatched calls. Drop duplicate/orphan results. Already in `Epistemos/Omega/Safety/TranscriptRepair.swift`.

### 7. Auto-Discovery & Zero-Config (Cascading Defaults)
- **Description:** OpenClaw's core principle: "if you do nothing, everything still works." Auto-discovers available models (Ollama, API keys), auto-enables tools based on environment permissions, and auto-selects best model for task complexity.
- **Parameters:** Model override, task complexity (simple/standard/complex), detected backends (MLX, Anthropic, OpenAI, Ollama), permission states (screen capture, accessibility)
- **Complexity:** Medium
- **Port Difficulty:** Medium
- **Porting Notes:** Requires integration with `KeychainService`, `MLXModelScanner`, `AXIsProcessTrusted()`, `CGPreflightScreenCaptureAccess()`. Needs a new `ModelDiscovery` actor in Swift.

### 8. MCP Tool Bundling (Runtime Discovery)
- **Description:** Discovers external MCP servers at boot, connects via stdio/HTTP, lists their tools, and merges them into the agent's available toolset with namespace prefixing (`mcp__{server}__{tool}`).
- **Parameters:** `mcpServers[]` (command, args, env), `transport` (stdio/HTTP), `toolSchema` (name, description, inputSchema), `namespacePrefix`
- **Complexity:** Complex
- **Port Difficulty:** Medium
- **Porting Notes:** Epistemos already has `MCPBridge.swift` and `omega-mcp`. Needs wiring to merge MCP-discovered tools into the Hermes tool registry before API calls. Use `mcp__server__tool` namespacing to prevent collisions.

### 9. Skills System (Markdown-Based)
- **Description:** Domain-specific instructions in `.md` files with YAML frontmatter. Injected into system prompt so the model knows HOW to use certain tools effectively. Auto-checked requirements via `which/where`.
- **Parameters:** `name`, `description`, `emoji`, `requires.bins[]`, `commands[]` (name, description), `instructions` (markdown body)
- **Complexity:** Medium
- **Port Difficulty:** Easy
- **Porting Notes:** Parse YAML frontmatter from `.md` files in `~/.epistemos/skills/` and app bundle. Filter by `requiredBins` availability. Inject into system prompt. Hermes skills are directly portable since both use the same SKILL.md format.

### 10. Cost Tracking (Invisible)
- **Description:** Side-effect tracking of API costs in integer micro-dollars (1 µ$ = $0.000001). Per-model, per-provider, per-session breakdown with cache read differentiation.
- **Parameters:** `model`, `inputTokens`, `outputTokens`, `cacheReadTokens`, `cacheWriteTokens`, `pricing` (input/output/cache per million), `timestamp`
- **Complexity:** Simple
- **Port Difficulty:** Easy
- **Porting Notes:** March 2026 pricing tables (Claude Sonnet $3/$15/M, Opus $15/$75/M, Haiku $0.80/$4/M). Cache read = 90% discount. Display in agent panel footer.

### 11. Error Recovery & Failover (Classify → Recover → Retry)
- **Description:** Automatic classification of API errors into retryable categories with appropriate recovery actions. User never sees retries unless unrecoverable.
- **Parameters:** `reason` (authError/rateLimited/contextOverflow/timeout/modelUnavailable/serverError), `attempt` (retry count), `delay` (exponential backoff: 250ms → 1.5s)
- **Complexity:** Medium
- **Port Difficulty:** Easy
- **Porting Notes:** Pattern-match error text for classification. Auth → rotate key. Rate limit → exponential backoff. Context overflow → compact and retry (max 3). Timeout → retry.

### 12. Context Compaction (Continuation Message)
- **Description:** When context is too long, summarizes old messages and injects a meta-instruction telling the model to continue naturally without re-summarizing.
- **Parameters:** `summary`, `preserveRecent` (4 messages), `suppressFollowUpQuestions` (flag)
- **Complexity:** Medium
- **Port Difficulty:** Easy
- **Porting Notes:** Already implemented in `agent_core/src/compaction.rs` with 4-phase compression. OpenClaw adds the "continuation message" framing which is a 10-line prompt change.

### 13. iMessage Channel Integration
- **Description:** Bidirectional iMessage via SQLite read (`chat.db`) + AppleScript send. FSEvents monitoring for incoming messages. DM allow-list for security.
- **Parameters:** `chatDbPath`, `lastMessageRowId`, `allowedSenders[]`, `sentMessageCache`, `recipient`, `text`
- **Complexity:** Complex
- **Port Difficulty:** Medium
- **Porting Notes:** Requires Full Disk Access entitlement. Use `sqlite3` C API for reading. `NSAppleScript` for sending. Echo prevention via sent-message cache. Already designed in `BEST_OF_CLAW_AND_OPENCLAW.md §9`.

### 14. Cron & Heartbeat (Always-On)
- **Description:** Timer-based agent wake-up for scheduled tasks. Jobs stored in GRDB with natural language schedule expressions. Heartbeat polls every 5 minutes.
- **Parameters:** `id`, `name`, `schedule` (cron expression), `prompt`, `sessionTarget` (main/isolated), `enabled`, `lastRun`, `nextRun`
- **Complexity:** Medium
- **Port Difficulty:** Easy
- **Porting Notes:** Use Swift `Timer` + GRDB `CronJob` table. Heartbeat collects pending events and wakes agent. Agent can create its own cron jobs via `schedule_task` tool.

### 15. Auth Profile Rotation
- **Description:** Multiple API keys per provider with automatic failover. Supports `ANTHROPIC_API_KEY_1`, `_2`, etc. Cooldown mechanism for failed keys.
- **Parameters:** `provider`, `apiKey`, `cooldownUntil`, `failureReason`, `profileCandidates[]`
- **Complexity:** Simple
- **Port Difficulty:** Easy
- **Porting Notes:** Scan Keychain for numbered keys on launch. First non-cooled-down profile wins. 1-minute cooldown on failure. Already conceptually present in `CredentialPool.swift`.

### 16. Stream Composition (Stackable Interceptors)
- **Description:** Composable stream interceptors: cache trace → thinking block dropper → tool call ID sanitizer → function call downgrader → abort signal wrapper.
- **Parameters:** `interceptors[]`, `AgentStreamEvent` (thinkingDelta, complete, toolStarted, error)
- **Complexity:** Medium
- **Port Difficulty:** Easy
- **Porting Notes:** Protocol-based pipeline in Swift. `StreamPipeline.process()` flatMaps events through each interceptor. Examples: `ThinkingBlockDropper`, `CostTracker`, `ToolLoopGuard`.

### 17. Session Auto-Management
- **Description:** Sessions never require user action. Auto-create on first message, auto-persist after every turn, auto-compact at 80% context limit, auto-resume on app reopen.
- **Parameters:** `sessionId`, `messages[]`, `createdAt`, `updatedAt`, `estimatedTokens`, `modelLimit`
- **Complexity:** Medium
- **Port Difficulty:** Easy
- **Porting Notes:** GRDB persistence. Load last active session on launch. Compact when `estimatedTokens > modelLimit * 0.8`.

### 18. Shadow Git Checkpoints (File Snapshots)
- **Description:** Before any file-mutating tool, creates a git snapshot in a shadow repo at `~/.hermes/checkpoints/{sha256(dir)[:16]}/`. Uses `GIT_DIR` + `GIT_WORK_TREE` separation.
- **Parameters:** `workingDir`, `shadowRepoPath`, `excludes[]` (node_modules, .env, etc.), `timeout` (30s)
- **Complexity:** Medium
- **Port Difficulty:** Easy
- **Porting Notes:** Use `Process` to invoke `git init --bare` + `git add -A` + `git commit`. `GIT_DIR` and `GIT_WORK_TREE` env vars for separation. Provide `vault_rollback` MCP tool.

### 19. Memory Threat Scanning
- **Description:** Scans text for prompt injection patterns, role hijack attempts, exfiltration URLs, invisible unicode, and SSH backdoor insertions before context injection.
- **Parameters:** `text`, threat patterns (role hijack: "you are now", "ignore previous", "system:", "<|im_start|>"; exfiltration: curl|sh, wget|bash; invisible unicode: zero-width joiners, RTL overrides; credentials: -----BEGIN, AKIA, ghp_, sk-)
- **Complexity:** Medium
- **Port Difficulty:** Easy
- **Porting Notes:** ~75 regex patterns across 9 categories. Return `ThreatLevel` enum (safe/suspicious/blocked). Wire into vault_search results before agent context injection.

### 20. Credential Redaction
- **Description:** Before any text enters conversation history, scans for credentials and partially masks them (first 4 + last 4 chars visible, middle replaced with `***`).
- **Parameters:** `text`, patterns (`sk-...`, `ghp_...`, `AKIA...`, `-----BEGIN...KEY-----`, `Bearer ...`, `token=...`)
- **Complexity:** Simple
- **Port Difficulty:** Easy
- **Porting Notes:** Can be part of `MemoryThreatScanner`. Apply to vault_search results and vault_read output before sending to cloud APIs.

### 21. Gateway Daemon Architecture
- **Description:** The "always-on" architecture: WebSocket server (port 18789) + Session Manager + Cron Scheduler + Heartbeat + Webhook Ingress + Channel Router + Agent Runner.
- **Parameters:** `port` (18789), `sessionManager`, `cronScheduler`, `heartbeatInterval`, `webhookRoutes[]`, `channelAdapters[]`
- **Complexity:** Complex
- **Port Difficulty:** Hard
- **Porting Notes:** For Epistemos, use `launchd` user service instead of Node.js server. NIOCore or Vapor-lite for webhook HTTP server. GRDB for persistence. This is the biggest architectural difference — Epistemos is a native Mac app, not a server.

### 22. Browser CDP Control
- **Description:** Dedicated Chrome/Chromium instance with full CDP control. Navigate, click, type, scroll, snapshot accessibility tree, screenshots, console logs.
- **Parameters:** `url`, `cdpUrl`, `headless`, `stealth`, `proxy`, `sessionTimeout`
- **Complexity:** Complex
- **Port Difficulty:** Hard
- **Porting Notes:** OpenClaw uses `agent-browser` CLI (Node.js). For Epistemos, wire AXorcist (Swift/Rust accessibility) or use Browserbase cloud API. Alternatively, port CDP client to Rust using `chromiumoxide` crate.

### 23. Web Fetch/Scrape
- **Description:** General web fetching with LLM summarization for large pages. Multiple backends (Tavily, Exa, Firecrawl, Perplexity).
- **Parameters:** `query`, `urls[]`, `format` (markdown), `maxChars`, `backend` (tavily/exa/firecrawl/parallel)
- **Complexity:** Medium
- **Port Difficulty:** Easy
- **Porting Notes:** Use `URLSession` + `SwiftSoup` for basic fetch. For search, call Tavily/Exa/Firecrawl APIs directly from Swift. Already partially present in `web_fetch` tool.

### 24. Live Canvas / A2UI
- **Description:** Agent-driven visual workspace. Agent can push cards, tables, charts; reset the canvas; evaluate expressions; take snapshots.
- **Parameters:** `action` (push/reset/eval/snapshot), `content` (JSON describing UI elements), `canvasId`
- **Complexity:** Complex
- **Port Difficulty:** Hard
- **Porting Notes:** OpenClaw uses React for rendering. Epistemos would use SwiftUI with a JSON-schema-driven dynamic view builder. This is a major differentiator but requires significant UI work.

### 25. Onboarding Wizard
- **Description:** Interactive setup that walks users through configuration step-by-step. Auto-detects available providers, installs daemon, runs health checks.
- **Parameters:** `steps[]` (provider setup, tool enablement, skill discovery, daemon install), `autoDetectResults`, `userChoices`
- **Complexity:** Medium
- **Port Difficulty:** Medium
- **Porting Notes:** SwiftUI wizard with `OnboardingView`. Check Keychain for API keys. Probe Ollama. Check permissions. Install `launchd` plist for daemon.

### 26. Sub-Agent Concurrency (Non-Blocking Spawn)
- **Description:** `sessions_spawn` returns immediately. `maxConcurrent` is a safety valve. Sub-agents share gateway resources. Context injection is limited (AGENTS.md + TOOLS.md only).
- **Parameters:** `objective`, `context`, `toolsets[]`, `maxConcurrent` (3), `contextScope` (terminal/research/file)
- **Complexity:** Complex
- **Port Difficulty:** Medium
- **Porting Notes:** Use Swift structured concurrency (`TaskGroup`). Limit concurrent children. Restrict toolset for children. Already partially present in Hermes `delegate_tool.py`.

### 27. DM Pairing Security
- **Description:** Inbound DMs treated as untrusted. Default DM pairing requires explicit approval. `doctor` command surfaces risky configs.
- **Parameters:** `senderId`, `allowedSenders[]` (allow-list), `pairingRequired` (bool)
- **Complexity:** Simple
- **Port Difficulty:** Easy
- **Porting Notes:** For iMessage/Telegram channels, maintain allow-list. First message from unknown sender → show pairing prompt in UI. Already designed in `BEST_OF_CLAW_AND_OPENCLAW.md §9`.

### 28. Doctor Command / Runtime Health Checks
- **Description:** `doctor` subcommand runs runtime health checks: dependency presence, credential sanity, channel connectivity, tool-sandbox sanity.
- **Parameters:** `checkCategories[]` (dependencies, credentials, channels, sandbox, disk)
- **Complexity:** Medium
- **Port Difficulty:** Easy
- **Porting Notes:** SwiftUI health check panel. Test each tool's `check_fn`. Verify API key validity with lightweight ping. Check disk usage. Display results with fix suggestions.

### 29. ACP Protocol (Agent Client Protocol)
- **Description:** Bidirectional RPC protocol for editor integration (VS Code, Zed, JetBrains). Session-based routing, tool execution, streaming responses.
- **Parameters:** `sessionId`, `method` (initialize/tools/list/tools/call), `params`, `jsonrpc` (2.0)
- **Complexity:** Complex
- **Port Difficulty:** Medium
- **Porting Notes:** Already present in Hermes (`acp_adapter/`). For Epistemos, the MCP protocol is preferred over ACP. Document for reference only.

### 30. Skill Auto-Discovery & Marketplace
- **Description:** OpenClaw's `skills/` directory has 50+ bundled skills. Skills auto-discover based on available binaries (`gh`, `git`, `xcodebuild`, etc.).
- **Parameters:** `skillDirs[]` (bundled + user-installed), `requiredBins[]`, `isAvailable` (computed)
- **Complexity:** Medium
- **Port Difficulty:** Easy
- **Porting Notes:** Same as Skill System (#9). Hermes skills are directly compatible since both use the same YAML-frontmatter + markdown format.

---

# Part 2: Hermes Agent Skills & Tools

Hermes Agent is a Python-based agent with **46 built-in tools** across 20 toolsets, **27 bundled skills**, and **24 optional skills**. Below is the complete inventory.

## Section 2A: Built-in Tools (46 total)

### `browser` toolset (11 tools)

#### 1. browser_navigate
- **Description:** Navigate to a URL in the browser. Initializes the session and loads the page. Must be called before other browser tools. For simple info retrieval, prefer web_search or web_extract.
- **Parameters:** `url` (string, required), `task_id` (string, optional), `cdp_url` (string, optional — override CDP endpoint)
- **Complexity:** Medium
- **Port Difficulty:** Hard
- **Porting Notes:** Requires `agent-browser` CLI or Browserbase API. For Epistemos, wire AXorcist accessibility as a native macOS alternative, or use Browserbase cloud API. Local headless Chromium requires Node.js deps — avoid in native Mac app.

#### 2. browser_snapshot
- **Description:** Get a text-based snapshot of the current page's accessibility tree. Returns interactive elements with ref IDs (like @e1, @e2) for browser_click and browser_type.
- **Parameters:** `task_id` (string), `full` (boolean, default false — compact vs complete view)
- **Complexity:** Medium
- **Port Difficulty:** Hard
- **Porting Notes:** Depends on browser_navigate's session. Accessibility tree parsing is complex. Consider using native AXUIElement tree walking via `omega-ax` crate instead.

#### 3. browser_click
- **Description:** Click on an element identified by its ref ID from the snapshot (e.g., '@e5').
- **Parameters:** `ref` (string, required), `task_id` (string)
- **Complexity:** Simple
- **Port Difficulty:** Hard
- **Porting Notes:** Requires active browser session. For native macOS, use `omega-ax` + `CGEvent` mouse simulation.

#### 4. browser_type
- **Description:** Type text into an input field identified by its ref ID. Clears the field first, then types the new text.
- **Parameters:** `ref` (string, required), `text` (string, required), `task_id` (string)
- **Complexity:** Simple
- **Port Difficulty:** Hard
- **Porting Notes:** Same as browser_click — requires browser session or native AX input simulation.

#### 5. browser_scroll
- **Description:** Scroll the page in a direction to reveal more content.
- **Parameters:** `direction` (string: up/down/left/right), `amount` (number), `task_id` (string)
- **Complexity:** Simple
- **Port Difficulty:** Hard
- **Porting Notes:** Browser-specific. Not directly applicable to native macOS unless using a browser automation backend.

#### 6. browser_back
- **Description:** Navigate back to the previous page in browser history.
- **Parameters:** `task_id` (string)
- **Complexity:** Simple
- **Port Difficulty:** Hard
- **Porting Notes:** Browser-specific. Skip for native macOS agent unless browser tool is included.

#### 7. browser_press
- **Description:** Press a keyboard key. Useful for submitting forms (Enter), navigating (Tab), or keyboard shortcuts.
- **Parameters:** `key` (string, required), `task_id` (string)
- **Complexity:** Simple
- **Port Difficulty:** Hard
- **Porting Notes:** Browser-specific. For native macOS, `omega-ax` can simulate key events.

#### 8. browser_close
- **Description:** Close the browser session and release resources. Frees up Browserbase session quota.
- **Parameters:** `task_id` (string)
- **Complexity:** Simple
- **Port Difficulty:** Hard
- **Porting Notes:** Cleanup for browser session. Not needed without browser tool.

#### 9. browser_get_images
- **Description:** Get a list of all images on the current page with their URLs and alt text.
- **Parameters:** `task_id` (string)
- **Complexity:** Simple
- **Port Difficulty:** Hard
- **Porting Notes:** Browser-specific. Could be replaced with `web_extract` for most use cases.

#### 10. browser_vision
- **Description:** Take a screenshot of the current page and analyze it with vision AI. Useful for CAPTCHAs, visual verification, complex layouts.
- **Parameters:** `question` (string, required), `task_id` (string)
- **Complexity:** Medium
- **Port Difficulty:** Hard
- **Porting Notes:** Requires vision model + screenshot capability. For native macOS, ScreenCaptureKit can replace browser screenshot.

#### 11. browser_console
- **Description:** Get browser console output and JavaScript errors from the current page.
- **Parameters:** `task_id` (string)
- **Complexity:** Simple
- **Port Difficulty:** Hard
- **Porting Notes:** Browser-specific. Not applicable to native macOS agent.

---

### `clarify` toolset (1 tool)

#### 12. clarify
- **Description:** Ask the user a question when clarification, feedback, or a decision is needed before proceeding. Supports multiple choice (up to 4 choices + "Other") or open-ended modes.
- **Parameters:** `question` (string, required), `choices` (string[], optional), `allow_free_text` (boolean, default true)
- **Complexity:** Simple
- **Port Difficulty:** Easy
- **Porting Notes:** UI-only tool. Needs SwiftUI modal/panel for question display. No Rust work needed. Store response and resume agent loop.

---

### `code_execution` toolset (1 tool)

#### 13. execute_code
- **Description:** Run a Python script that can call Hermes tools programmatically. Use for 3+ tool calls with processing logic, filtering large outputs, conditional branching, or batch operations.
- **Parameters:** `code` (string, required — Python script), `timeout` (number, optional)
- **Complexity:** Complex
- **Port Difficulty:** Hard
- **Porting Notes:** Requires Python sandbox. Options: (1) Skip — not needed for native Mac app, (2) Use Swift `Process` to run Python in sandbox, (3) Replace with Swift script execution via `NSUserScriptTask`. High security risk — careful sandboxing required.

---

### `cronjob` toolset (1 tool)

#### 14. cronjob
- **Description:** Unified scheduled-task manager. Create, list, update, pause, resume, run, or remove jobs. Supports skill-backed jobs. Cron runs happen in fresh sessions with no current-chat context.
- **Parameters:** `action` (enum: create/list/update/pause/resume/run/remove), `name` (string), `schedule` (string — cron expression or natural language), `prompt` (string), `skills` (string[])
- **Complexity:** Medium
- **Port Difficulty:** Easy
- **Porting Notes:** Already designed in `BEST_OF_CLAW_AND_OPENCLAW.md §10`. Use GRDB `CronJob` table + Swift `Timer`. Natural language to cron expression needs an LLM call or pattern matcher.

---

### `delegation` toolset (1 tool)

#### 15. delegate_task
- **Description:** Spawn one or more subagents to work on tasks in isolated contexts. Each subagent gets its own conversation, terminal session, and toolset. Only the final summary is returned — intermediate tool results never enter parent context.
- **Parameters:** `tasks[]` (array of {goal, context, toolsets}), `model` (string, optional), `max_iterations` (number, default 50), `context_scope` (string: terminal/research/file)
- **Complexity:** Complex
- **Port Difficulty:** Medium
- **Porting Notes:** Use Swift `TaskGroup` for parallel execution. Depth limiter prevents recursion. Blocked tools: delegate_task, clarify, memory, send_message, execute_code. Already partially implemented.

---

### `file` toolset (4 tools)

#### 16. read_file
- **Description:** Read a text file with line numbers and pagination. Output format: `LINE_NUM|CONTENT`. Suggests similar filenames if not found.
- **Parameters:** `path` (string, required), `offset` (number, default 1), `limit` (number, default 500), `task_id` (string)
- **Complexity:** Simple
- **Port Difficulty:** Easy
- **Porting Notes:** Native Swift `FileManager` + `String` operations. Already present in Epistemos as `vault_read` and file_ops tools.

#### 17. write_file
- **Description:** Write content to a file, completely replacing existing content. Creates parent directories automatically. Use patch for targeted edits.
- **Parameters:** `path` (string, required), `content` (string, required), `task_id` (string)
- **Complexity:** Simple
- **Port Difficulty:** Easy
- **Porting Notes:** Native Swift `FileManager`. Atomic write via temp + rename. Already present in Epistemos.

#### 18. patch
- **Description:** Targeted find-and-replace edits in files. Uses fuzzy matching (9 strategies) so minor whitespace/indentation differences won't break it. Returns a unified diff. Auto-runs syntax checks after editing code files.
- **Parameters:** `path` (string, required), `old_string` (string, required), `new_string` (string, required), `task_id` (string)
- **Complexity:** Medium
- **Port Difficulty:** Medium
- **Porting Notes:** Fuzzy matching logic needs porting to Rust/Swift. 9 strategies include: exact match, case-insensitive, whitespace-normalized, line-stripped, etc. Already present in `file_operations.py` — study and port.

#### 19. search_files
- **Description:** Search file contents or find files by name. Ripgrep-backed, faster than shell equivalents. Content search (target='content'): regex search inside files. File search (target='files'): find files matching pattern.
- **Parameters:** `query` (string, required), `target` (enum: content/files, default content), `path` (string, optional), `output_mode` (enum: full/paths/count, default full), `task_id` (string)
- **Complexity:** Medium
- **Port Difficulty:** Easy
- **Porting Notes:** Use `ripgrep` binary via `Process` or port to Rust using `grep` crate. Already present in Epistemos as `workspace_search`.

---

### `homeassistant` toolset (4 tools)

#### 20. ha_list_entities
- **Description:** List Home Assistant entities. Optionally filter by domain (light, switch, climate, sensor, etc.) or by area name.
- **Parameters:** `domain` (string, optional), `area` (string, optional)
- **Complexity:** Simple
- **Port Difficulty:** Easy
- **Porting Notes:** HTTP REST API call to Home Assistant. Requires `HASS_TOKEN`.

#### 21. ha_get_state
- **Description:** Get the detailed state of a single Home Assistant entity, including all attributes (brightness, color, temperature, sensor readings, etc.).
- **Parameters:** `entity_id` (string, required)
- **Complexity:** Simple
- **Port Difficulty:** Easy
- **Porting Notes:** HTTP REST API call. Simple GET request.

#### 22. ha_list_services
- **Description:** List available Home Assistant services (actions) for device control. Shows what actions can be performed on each device type and what parameters they accept.
- **Parameters:** `domain` (string, optional)
- **Complexity:** Simple
- **Port Difficulty:** Easy
- **Porting Notes:** HTTP REST API call.

#### 23. ha_call_service
- **Description:** Call a Home Assistant service to control a device. Use ha_list_services to discover available services and their parameters.
- **Parameters:** `domain` (string, required), `service` (string, required), `entity_id` (string, required), `service_data` (object, optional)
- **Complexity:** Simple
- **Port Difficulty:** Easy
- **Porting Notes:** HTTP POST to Home Assistant API.

---

### `honcho` toolset (4 tools)

#### 24. honcho_context
- **Description:** Ask Honcho a natural language question and get a synthesized answer. Uses Honcho's LLM (dialectic reasoning). Higher cost than honcho_profile or honcho_search.
- **Parameters:** `query` (string, required), `peer` (string, default "user")
- **Complexity:** Simple
- **Port Difficulty:** Easy
- **Porting Notes:** Honcho is a cloud API. Simple HTTP wrapper. Gated on Honcho being active.

#### 25. honcho_profile
- **Description:** Retrieve the user's peer card from Honcho — a curated list of key facts (name, role, preferences, communication style, patterns). Fast, no LLM reasoning, minimal cost.
- **Parameters:** `peer` (string, default "user")
- **Complexity:** Simple
- **Port Difficulty:** Easy
- **Porting Notes:** Honcho API call. Returns structured user profile data.

#### 26. honcho_search
- **Description:** Semantic search over Honcho's stored context about the user. Returns raw excerpts ranked by relevance — no LLM synthesis. Cheaper than honcho_context.
- **Parameters:** `query` (string, required), `peer` (string, default "user"), `limit` (number, default 5)
- **Complexity:** Simple
- **Port Difficulty:** Easy
- **Porting Notes:** Honcho API call with vector search backend.

#### 27. honcho_conclude
- **Description:** Write a conclusion about the user back to Honcho's memory. Conclusions are persistent facts that build the user's profile.
- **Parameters:** `conclusion` (string, required), `peer` (string, default "user")
- **Complexity:** Simple
- **Port Difficulty:** Easy
- **Porting Notes:** Honcho API write. For Epistemos, consider using local vault memory instead of Honcho cloud dependency.

---

### `image_gen` toolset (1 tool)

#### 28. image_generate
- **Description:** Generate high-quality images from text prompts using FLUX 2 Pro model with automatic 2x upscaling. Returns a single upscaled image URL.
- **Parameters:** `prompt` (string, required), `negative_prompt` (string, optional), `width` (number, optional), `height` (number, optional)
- **Complexity:** Simple
- **Port Difficulty:** Easy
- **Porting Notes:** Requires `FAL_KEY`. HTTP API call to Fal.ai. Could also support DALL-E, Stable Diffusion via different backends.

---

### `memory` toolset (1 tool)

#### 29. memory
- **Description:** Save important information to persistent memory that survives across sessions. Memory appears in the system prompt at session start.
- **Parameters:** `action` (enum: read/write/append/delete/list), `section` (string, default "general"), `content` (string, required for write/append)
- **Complexity:** Medium
- **Port Difficulty:** Easy
- **Porting Notes:** Already ported to Epistemos via `AgentGraphMemory` and vault integration. Uses `MEMORY.md`-style sectioned storage.

---

### `messaging` toolset (1 tool)

#### 30. send_message
- **Description:** Send a message to a connected messaging platform, or list available targets. Supports Telegram, Discord, Slack, WhatsApp, SMS, Signal, Matrix, email, etc.
- **Parameters:** `action` (enum: send/list), `platform` (string), `target` (string), `message` (string), `attachment` (string, optional)
- **Complexity:** Medium
- **Port Difficulty:** Medium
- **Porting Notes:** Requires gateway to be running. Each platform has its own adapter. For Epistemos, start with iMessage (native macOS) and optionally Telegram/Slack via their APIs.

---

### `moa` toolset (1 tool)

#### 31. mixture_of_agents
- **Description:** Route a hard problem through multiple frontier LLMs collaboratively. Makes 5 API calls (4 reference models + 1 aggregator) with maximum reasoning effort.
- **Parameters:** `query` (string, required), `reference_models` (string[], optional), `aggregator_model` (string, optional)
- **Complexity:** Medium
- **Port Difficulty:** Easy
- **Porting Notes:** Requires `OPENROUTER_API_KEY`. Parallel API calls to multiple models, then synthesis call. Use Swift `TaskGroup` for parallel execution.

---

### `rl` toolset (9 tools)

#### 32. rl_list_environments
- **Description:** List all available RL environments for Tinker-Atropos training.
- **Parameters:** None
- **Complexity:** Simple
- **Port Difficulty:** Easy
- **Porting Notes:** Requires `TINKER_API_KEY`. HTTP API call.

#### 33. rl_select_environment
- **Description:** Select an RL environment for training. Loads default configuration.
- **Parameters:** `environment` (string, required)
- **Complexity:** Simple
- **Port Difficulty:** Easy
- **Porting Notes:** Tinker API call.

#### 34. rl_get_current_config
- **Description:** Get the current environment configuration. Returns modifiable fields.
- **Parameters:** None
- **Complexity:** Simple
- **Port Difficulty:** Easy
- **Porting Notes:** Tinker API call.

#### 35. rl_edit_config
- **Description:** Update a configuration field. Use rl_get_current_config first to see available fields.
- **Parameters:** `field` (string, required), `value` (any, required)
- **Complexity:** Simple
- **Port Difficulty:** Easy
- **Porting Notes:** Tinker API call.

#### 36. rl_start_training
- **Description:** Start a new RL training run with the current environment and config.
- **Parameters:** None
- **Complexity:** Simple
- **Port Difficulty:** Easy
- **Porting Notes:** Tinker API call.

#### 37. rl_check_status
- **Description:** Get status and metrics for a training run. Rate limited: 30-minute minimum between checks.
- **Parameters:** `run_id` (string, optional)
- **Complexity:** Simple
- **Port Difficulty:** Easy
- **Porting Notes:** Tinker API call + WandB metrics.

#### 38. rl_stop_training
- **Description:** Stop a running training job.
- **Parameters:** `run_id` (string, optional)
- **Complexity:** Simple
- **Port Difficulty:** Easy
- **Porting Notes:** Tinker API call.

#### 39. rl_get_results
- **Description:** Get final results and metrics for a completed training run.
- **Parameters:** `run_id` (string, required)
- **Complexity:** Simple
- **Port Difficulty:** Easy
- **Porting Notes:** Tinker API call.

#### 40. rl_list_runs
- **Description:** List all training runs (active and completed) with their status.
- **Parameters:** None
- **Complexity:** Simple
- **Port Difficulty:** Easy
- **Porting Notes:** Tinker API call.

#### 41. rl_test_inference
- **Description:** Quick inference test for any environment. Runs inference + scoring using OpenRouter.
- **Parameters:** `environment` (string, optional)
- **Complexity:** Medium
- **Port Difficulty:** Easy
- **Porting Notes:** Tinker API call + OpenRouter inference.

---

### `session_search` toolset (1 tool)

#### 42. session_search
- **Description:** Search your long-term memory of past conversations. Every past session is searchable, and this tool summarizes what happened.
- **Parameters:** `query` (string, required), `limit` (number, default 5), `time_range` (string, optional)
- **Complexity:** Medium
- **Port Difficulty:** Easy
- **Porting Notes:** Uses SQLite FTS5 in Hermes. For Epistemos, use GRDB FTS or Tantivy. Already partially implemented.

---

### `skills` toolset (3 tools)

#### 43. skills_list
- **Description:** List available skills (name + description). Use skill_view(name) to load full content.
- **Parameters:** `category` (string, optional), `source` (enum: bundled/installed/all, default all)
- **Complexity:** Simple
- **Port Difficulty:** Easy
- **Porting Notes:** Scan `~/.epistemos/skills/` directory. Parse YAML frontmatter. Already partially implemented.

#### 44. skill_view
- **Description:** Load a skill's full content or access its linked files (references, templates, scripts). First call returns SKILL.md content plus a file tree.
- **Parameters:** `name` (string, required), `file` (string, optional — specific file within skill)
- **Complexity:** Simple
- **Port Difficulty:** Easy
- **Porting Notes:** Read markdown file. Progressive disclosure: metadata → instructions → resources.

#### 45. skill_manage
- **Description:** Manage skills (create, update, delete). Actions: create (full SKILL.md content), update (patch), delete, install (from skills.sh/GitHub/LobeHub/ClawHub).
- **Parameters:** `action` (enum: create/update/delete/install), `name` (string), `content` (string), `source` (string, for install)
- **Complexity:** Medium
- **Port Difficulty:** Easy
- **Porting Notes:** File I/O for create/update/delete. For install, fetch from remote registry. Use `skills_hub` for remote discovery.

---

### `terminal` toolset (2 tools)

#### 46. terminal
- **Description:** Execute shell commands. Filesystem persists between calls. 6 backends: local, Docker, Modal, SSH, Singularity, Daytona.
- **Parameters:** `command` (string, required), `background` (boolean, default false), `check_interval` (number, optional), `env_type` (enum: local/docker/modal/ssh/singularity/daytona), `timeout` (number, optional)
- **Complexity:** Complex
- **Port Difficulty:** Medium
- **Porting Notes:** Local execution via `Process` with dangerous command approval. Docker/SSH/Modal backends are less relevant for a native Mac app. Focus on local with sandboxing. PTY pool already exists in Epistemos.

#### 47. process
- **Description:** Manage background processes started with terminal(background=true). Actions: list, poll, log, wait, kill, write (send input).
- **Parameters:** `action` (enum: list/poll/log/wait/kill/write), `pid` (number, optional), `input` (string, for write action)
- **Complexity:** Medium
- **Port Difficulty:** Medium
- **Porting Notes:** Process registry tracking. Already partially present in `OrphanSubprocessCleanup.swift`.

---

### `todo` toolset (1 tool)

#### 48. todo
- **Description:** Manage your task list for the current session. Use for complex tasks with 3+ steps or when the user provides multiple tasks.
- **Parameters:** `todos[]` (array of {id, content, status}), `merge_mode` (enum: replace/append), `task_id` (string)
- **Complexity:** Simple
- **Port Difficulty:** Easy
- **Porting Notes:** In-memory task list per session. No persistence needed across sessions. Simple Swift struct.

---

### `tts` toolset (1 tool)

#### 49. text_to_speech
- **Description:** Convert text to speech audio. Returns a MEDIA path. Providers: Edge TTS (free), ElevenLabs, OpenAI.
- **Parameters:** `text` (string, required), `voice` (string, optional), `provider` (enum: edge/elevenlabs/openai, default edge)
- **Complexity:** Simple
- **Port Difficulty:** Easy
- **Porting Notes:** Use `AVSpeechSynthesizer` for native macOS TTS (free, offline). Or call ElevenLabs/OpenAI APIs for higher quality. Save to `~/voice-memos/`.

---

### `vision` toolset (1 tool)

#### 50. vision_analyze
- **Description:** Analyze images using AI vision. Provides a comprehensive description and answers a specific question about the image content.
- **Parameters:** `image_path` (string, required), `question` (string, optional)
- **Complexity:** Simple
- **Port Difficulty:** Easy
- **Porting Notes:** Use Apple Intelligence for on-device vision analysis when available. Fallback to cloud vision APIs (Claude, GPT-4o). Native `VNImageRequestHandler` for basic analysis.

---

### `web` toolset (2 tools)

#### 51. web_search
- **Description:** Search the web for information on any topic. Returns up to 5 relevant results with titles, URLs, and descriptions.
- **Parameters:** `query` (string, required), `limit` (number, default 5), `backend` (enum: tavily/exa/firecrawl/parallel/duckduckgo)
- **Complexity:** Medium
- **Port Difficulty:** Easy
- **Porting Notes:** Multiple backend support. Tavily/Exa/Firecrawl require API keys. DuckDuckGo is free but less reliable. Already present in Epistemos.

#### 52. web_extract
- **Description:** Extract content from web page URLs. Returns page content in markdown format. Also works with PDF URLs. Large pages are LLM-summarized.
- **Parameters:** `urls[]` (string[], required), `format` (enum: markdown/text, default markdown), `max_chars` (number, optional)
- **Complexity:** Medium
- **Port Difficulty:** Easy
- **Porting Notes:** Use `URLSession` + `SwiftSoup` for HTML→Markdown. For PDF, use PDFKit. Already present in Epistemos.

---

## Section 2B: Bundled Skills (27 categories, 100+ individual skills)

| # | Skill | Category | Description | Port Difficulty |
|---|-------|----------|-------------|-----------------|
| 1 | apple-notes | apple | Manage Apple Notes via memo CLI on macOS | Easy |
| 2 | apple-reminders | apple | Manage Apple Reminders via remindctl CLI | Easy |
| 3 | findmy | apple | Track Apple devices and AirTags via FindMy.app | Easy |
| 4 | imessage | apple | Send/receive iMessages/SMS via imsg CLI | Easy |
| 5 | claude-code | autonomous-ai-agents | Delegate coding tasks to Claude Code CLI | Easy |
| 6 | codex | autonomous-ai-agents | Delegate coding tasks to OpenAI Codex CLI | Easy |
| 7 | hermes-agent-spawning | autonomous-ai-agents | Spawn additional Hermes Agent instances | Easy |
| 8 | opencode | autonomous-ai-agents | Delegate coding tasks to OpenCode CLI | Easy |
| 9 | jupyter-live-kernel | data-science | Use live Jupyter kernel for iterative Python | Medium |
| 10 | ascii-art | creative | Generate ASCII art using pyfiglet, cowsay, etc. | Easy |
| 11 | ascii-video | creative | Production pipeline for ASCII art video | Medium |
| 12 | excalidraw | creative | Create hand-drawn style diagrams (Excalidraw JSON) | Easy |
| 13 | songwriting-and-ai-music | creative | Generate AI music and lyrics | Medium |
| 14 | webhook-subscriptions | devops | Create/manage webhook subscriptions for event-driven activation | Easy |
| 15 | dogfood | dogfood | Systematic exploratory QA testing of web apps | Medium |
| 16 | hermes-agent-setup | dogfood | Help users configure Hermes Agent | Easy |
| 17 | himalaya | email | CLI email management via IMAP/SMTP | Easy |
| 18 | minecraft-modpack-server | gaming | Set up modded Minecraft server | Medium |
| 19 | pokemon-player | gaming | Play Pokemon autonomously via headless emulation | Hard |
| 20 | codebase-inspection | github | Inspect codebases using pygount for LOC counting | Easy |
| 21 | github-auth | github | Set up GitHub authentication for the agent | Easy |
| 22 | github-code-review | github | Review code changes via gh CLI or git + REST API | Easy |
| 23 | github-issues | github | Create, manage, triage GitHub issues | Easy |
| 24 | github-pr-workflow | github | Full PR lifecycle — branches, commits, CI, merge | Easy |
| 25 | github-repo-management | github | Clone, create, fork, configure GitHub repos | Easy |
| 26 | inference-sh-cli | inference-sh | Run 150+ AI apps via inference.sh CLI | Easy |
| 27 | find-nearby | leisure | Find nearby places using OpenStreetMap | Easy |
| 28 | mcporter | mcp | List, configure, auth, and call MCP servers/tools directly | Easy |
| 29 | native-mcp | mcp | Built-in MCP client with auto-discovery and reconnection | Medium |
| 30 | gif-search | media | Search and download GIFs from Tenor | Easy |
| 31 | heartmula | media | Set up and run HeartMuLa music generation model | Medium |
| 32 | songsee | media | Generate spectrograms and audio feature visualizations | Easy |
| 33 | youtube-content | media | Fetch YouTube transcripts and transform to structured content | Easy |
| 34 | huggingface-hub | mlops | Hugging Face Hub CLI — search, download, upload models | Easy |
| 35 | lambda-labs-gpu-cloud | mlops/cloud | Reserved and on-demand GPU cloud instances | Easy |
| 36 | modal-serverless-gpu | mlops/cloud | Serverless GPU cloud platform for ML workloads | Easy |
| 37 | evaluating-llms-harness | mlops/evaluation | Evaluate LLMs across 60+ academic benchmarks | Medium |
| 38 | huggingface-tokenizers | mlops/evaluation | Fast tokenizers (Rust-based, BPE/WordPiece/Unigram) | Easy |
| 39 | nemo-curator | mlops/evaluation | GPU-accelerated data curation for LLM training | Hard |
| 40 | sparse-autoencoder-training | mlops/evaluation | Train and analyze Sparse Autoencoders (SAEs) | Hard |
| 41 | weights-and-biases | mlops/evaluation | Track ML experiments with W&B | Easy |
| 42 | gguf-quantization | mlops/inference | GGUF format and llama.cpp quantization | Medium |
| 43 | guidance | mlops/inference | Control LLM output with regex and grammars | Medium |
| 44 | instructor | mlops/inference | Extract structured data from LLM responses | Easy |
| 45 | llama-cpp | mlops/inference | Runs LLM inference on CPU and Apple Silicon | Medium |
| 46 | obliteratus | mlops/inference | Remove refusal behaviors from open-weight LLMs | Hard |
| 47 | outlines | mlops/inference | Guarantee valid JSON/XML/code during generation | Medium |
| 48 | serving-llms-vllm | mlops/inference | Serve LLMs with vLLM's PagedAttention | Medium |
| 49 | tensorrt-llm | mlops/inference | Optimize LLM inference with NVIDIA TensorRT | Hard |
| 50 | audiocraft-audio-generation | mlops/models | PyTorch audio generation (MusicGen, AudioGen) | Medium |
| 51 | clip | mlops/models | OpenAI's vision-language model for zero-shot classification | Medium |
| 52 | llava | mlops/models | Large Language and Vision Assistant | Medium |
| 53 | segment-anything-model | mlops/models | Foundation model for image segmentation | Medium |
| 54 | stable-diffusion-image-generation | mlops/models | Text-to-image generation with Stable Diffusion | Medium |
| 55 | whisper | mlops/models | OpenAI's speech recognition (99 languages) | Medium |
| 56 | dspy | mlops/research | Build complex AI systems with declarative programming | Medium |
| 57 | axolotl | mlops/training | Fine-tune LLMs with Axolotl (YAML configs, 100+ models) | Medium |
| 58 | distributed-llm-pretraining-torchtitan | mlops/training | PyTorch-native distributed LLM pretraining | Hard |
| 59 | fine-tuning-with-trl | mlops/training | Fine-tune LLMs using TRL (SFT, DPO, PPO, GRPO) | Medium |
| 60 | grpo-rl-training | mlops/training | GRPO/RL fine-tuning with TRL | Hard |
| 61 | hermes-atropos-environments | mlops/training | Build/test/debug Hermes Agent RL environments | Hard |
| 62 | huggingface-accelerate | mlops/training | Simplest distributed training API (4 lines) | Easy |
| 63 | optimizing-attention-flash | mlops/training | Flash Attention for 2-4x speedup | Medium |
| 64 | peft-fine-tuning | mlops/training | Parameter-efficient fine-tuning (LoRA, QLoRA) | Medium |
| 65 | pytorch-fsdp | mlops/training | Fully Sharded Data Parallel training | Hard |
| 66 | pytorch-lightning | mlops/training | High-level PyTorch framework with Trainer class | Easy |
| 67 | simpo-training | mlops/training | Simple Preference Optimization for LLM alignment | Medium |
| 68 | slime-rl-training | mlops/training | LLM post-training with RL using slime framework | Hard |
| 69 | unsloth | mlops/training | Fast fine-tuning with Unsloth (2-5x faster) | Medium |
| 70 | chroma | mlops/vector-databases | Open-source embedding database for AI applications | Easy |
| 71 | faiss | mlops/vector-databases | Facebook's library for similarity search and clustering | Medium |
| 72 | pinecone | mlops/vector-databases | Managed vector database for production AI | Easy |
| 73 | qdrant-vector-search | mlops/vector-databases | High-performance vector similarity search engine | Easy |
| 74 | obsidian | note-taking | Read, search, and create notes in Obsidian vault | Easy |
| 75 | google-workspace | productivity | Gmail, Calendar, Drive, Contacts, Sheets, Docs via OAuth | Medium |
| 76 | linear | productivity | Manage Linear issues, projects, teams via GraphQL API | Easy |
| 77 | nano-pdf | productivity | Edit PDFs with natural-language instructions | Medium |
| 78 | notion | productivity | Notion API for creating/managing pages and databases | Easy |
| 79 | ocr-and-documents | productivity | Extract text from PDFs and scanned documents | Medium |
| 80 | powerpoint | productivity | Create and edit PowerPoint presentations (.pptx) | Medium |
| 81 | arxiv | research | Search and retrieve academic papers from arXiv | Easy |
| 82 | blogwatcher | research | Monitor blogs and RSS/Atom feeds for updates | Easy |
| 83 | domain-intel | research | Passive domain reconnaissance using Python stdlib | Easy |
| 84 | duckduckgo-search | research | Free web search via DuckDuckGo | Easy |
| 85 | ml-paper-writing | research | Write publication-ready ML/AI papers | Easy |
| 86 | polymarket | research | Query Polymarket prediction market data | Easy |
| 87 | godmode | red-teaming | Jailbreak API-served LLMs using G0DM0D3 techniques | Medium |
| 88 | openhue | smart-home | Control Philips Hue lights, rooms, scenes | Easy |
| 89 | xitter | social-media | Interact with X/Twitter via x-cli terminal client | Easy |
| 90 | code-review | software-development | Guidelines for thorough code reviews | Easy |
| 91 | plan | software-development | Inspect context, write a markdown plan, do not execute | Easy |
| 92 | requesting-code-review | software-development | Validate work meets requirements through review | Easy |
| 93 | subagent-driven-development | software-development | Dispatch delegate_task per task with two-stage review | Easy |
| 94 | systematic-debugging | software-development | 4-phase root cause investigation | Easy |
| 95 | test-driven-development | software-development | Enforce RED-GREEN-REFACTOR cycle | Easy |
| 96 | writing-plans | software-development | Create comprehensive implementation plans | Easy |

---

## Section 2C: Optional Skills (24 total)

| # | Skill | Category | Description | Port Difficulty |
|---|-------|----------|-------------|-----------------|
| 97 | blackbox | autonomous-ai-agents | Delegate coding tasks to Blackbox AI CLI agent | Easy |
| 98 | base | blockchain | Query Base (Ethereum L2) blockchain data with USD pricing | Easy |
| 99 | solana | blockchain | Query Solana blockchain data with USD pricing | Easy |
| 100 | one-three-one-rule | communication | Communication framework for structured responses | Easy |
| 101 | blender-mcp | creative | Control Blender directly from agent via MCP | Hard |
| 102 | meme-generation | creative | Generate real meme images with Pillow | Easy |
| 103 | docker-management | devops | Manage Docker containers, images, volumes, networks | Easy |
| 104 | agentmail | email | Give the agent its own dedicated email inbox | Easy |
| 105 | neuroskill-bci | health | Connect to NeuroSkill for real-time cognitive/emotional state | Hard |
| 106 | fastmcp | mcp | Build, test, inspect, install, deploy MCP servers with FastMCP | Easy |
| 107 | openclaw-migration | migration | Migrate OpenClaw customization footprint into Hermes Agent | Easy |
| 108 | canvas | productivity | Agent-driven visual workspace (Canvas/A2UI equivalent) | Medium |
| 109 | memento-flashcards | productivity | Create and manage flashcard decks for spaced repetition | Easy |
| 110 | siyuan | productivity | Note-taking and knowledge management via Siyuan | Easy |
| 111 | telephony | productivity | Give agent phone capabilities via Twilio/Bland.ai/Vapi | Medium |
| 112 | bioinformatics | research | Gateway to 400+ bioinformatics skills from bioSkills | Medium |
| 113 | parallel-cli | research | Parallel CLI operations and distributed computing | Medium |
| 114 | qmd | research | Search personal knowledge bases locally using qmd | Easy |
| 115 | scrapling | research | Web scraping and data extraction framework | Medium |
| 116 | 1password | security | Set up and use 1Password CLI for secrets management | Easy |
| 117 | oss-forensics | security | Supply chain investigation and forensic analysis for GitHub | Medium |
| 118 | sherlock | security | OSINT username search across 400+ social networks | Easy |

---

# Part 3: Porting Strategy Matrix

| # | Tool/Skill | Source | Difficulty | Priority | Notes |
|---|-----------|--------|-----------|----------|-------|
| 1 | Tool Loop Detection | OpenClaw | Easy | P0 | Already implemented in `ToolLoopDetector.swift`. Wire into agent loop. |
| 2 | Context Budget Manager | OpenClaw | Easy | P0 | Already implemented in `ContextBudgetManager.swift`. |
| 3 | Execution Checkpoint & Resume | OpenClaw | Easy | P0 | Already implemented in `ExecutionCheckpointManager.swift`. |
| 4 | Agent Depth Limiter | OpenClaw | Easy | P0 | Already implemented in `AgentDepthLimiter.swift`. |
| 5 | Memory Recall Diversification (MMR) | OpenClaw | Easy | P0 | Already implemented in `MMRReranker.swift`. |
| 6 | Execution Transcript Repair | OpenClaw | Easy | P0 | Already implemented in `TranscriptRepair.swift`. |
| 7 | Credential Redaction | OpenClaw | Easy | P0 | Already implemented in `MemoryThreatScanner.swift`. |
| 8 | Memory Threat Scanning | OpenClaw | Easy | P0 | Already implemented in `MemoryThreatScanner.swift`. |
| 9 | Cost Tracking (Micro-Dollar) | OpenClaw | Easy | P1 | Add pricing table + display in agent panel footer. |
| 10 | Shadow Git Checkpoints | OpenClaw | Easy | P1 | New `ShadowGitCheckpoint.swift`. Call before vault_write. |
| 11 | Auto-Discovery & Zero-Config | OpenClaw | Medium | P1 | New `ModelDiscovery` actor. Probe backends, check permissions. |
| 12 | Stream Composition | OpenClaw | Easy | P1 | Protocol-based pipeline. Add interceptors as needed. |
| 13 | Session Auto-Management | OpenClaw | Easy | P1 | GRDB persistence for sessions. Auto-compact at 80%. |
| 14 | Cron & Heartbeat | OpenClaw | Easy | P1 | GRDB + Swift Timer. Natural language scheduling. |
| 15 | Auth Profile Rotation | OpenClaw | Easy | P2 | Extend existing `CredentialPool.swift`. |
| 16 | DM Pairing Security | OpenClaw | Easy | P2 | Allow-list for iMessage channel. |
| 17 | Doctor Command | OpenClaw | Easy | P2 | SwiftUI health check panel. |
| 18 | iMessage Channel | OpenClaw | Medium | P2 | SQLite + AppleScript. Requires Full Disk Access. |
| 19 | Error Recovery & Failover | OpenClaw | Easy | P1 | Pattern-match errors, exponential backoff, key rotation. |
| 20 | Context Compaction | OpenClaw | Easy | P0 | Already in `agent_core/src/compaction.rs`. |
| 21 | MCP Tool Bundling | OpenClaw | Medium | P1 | Wire `MCPBridge.swift` into Hermes tool registry. |
| 22 | Skills System (Markdown) | OpenClaw | Easy | P1 | Parse YAML frontmatter from `.md` files. Hermes-compatible. |
| 23 | Gateway Daemon Architecture | OpenClaw | Hard | P3 | Use `launchd` + NIOCore instead of Node.js server. |
| 24 | Browser CDP Control | OpenClaw | Hard | P3 | Wire AXorcist as native alternative, or Browserbase API. |
| 25 | Web Fetch/Scrape | OpenClaw | Easy | P1 | Already partially present. Use `URLSession` + `SwiftSoup`. |
| 26 | Live Canvas / A2UI | OpenClaw | Hard | P3 | SwiftUI JSON-schema dynamic views. Major UI project. |
| 27 | Onboarding Wizard | OpenClaw | Medium | P2 | SwiftUI wizard with auto-detection. |
| 28 | Sub-Agent Concurrency | OpenClaw | Medium | P1 | Use `TaskGroup`. Limit concurrent children. |
| 29 | ACP Protocol | OpenClaw | Medium | P3 | MCP preferred over ACP. Document only. |
| 30 | read_file | Hermes | Easy | P0 | Already present in Epistemos (`vault_read`, file_ops). |
| 31 | write_file | Hermes | Easy | P0 | Already present in Epistenos. |
| 32 | patch | Hermes | Medium | P1 | Port fuzzy matching (9 strategies) from Python. |
| 33 | search_files | Hermes | Easy | P0 | Already present as `workspace_search`. |
| 34 | terminal | Hermes | Medium | P1 | Use `Process` with dangerous command approval. |
| 35 | process | Hermes | Medium | P1 | Process registry tracking. Already partially present. |
| 36 | web_search | Hermes | Easy | P0 | Already present. Add Exa backend. |
| 37 | web_extract | Hermes | Easy | P0 | Already present. |
| 38 | vision_analyze | Hermes | Easy | P1 | Use Apple Intelligence or cloud vision APIs. |
| 39 | image_generate | Hermes | Easy | P2 | Fal.ai FLUX 2 Pro API call. |
| 40 | text_to_speech | Hermes | Easy | P2 | Use `AVSpeechSynthesizer` for native TTS. |
| 41 | memory | Hermes | Easy | P0 | Already ported to `AgentGraphMemory`. |
| 42 | session_search | Hermes | Easy | P1 | GRDB FTS5 or Tantivy. Already partially present. |
| 43 | todo | Hermes | Easy | P1 | In-memory task list per session. |
| 44 | clarify | Hermes | Easy | P1 | SwiftUI modal for user questions. |
| 45 | execute_code | Hermes | Hard | P3 | Python sandbox — high security risk. Consider skipping. |
| 46 | delegate_task | Hermes | Medium | P1 | Already partially implemented. Add `TaskGroup` parallelism. |
| 47 | cronjob | Hermes | Easy | P1 | Same as Cron & Heartbeat (#14). |
| 48 | send_message | Hermes | Medium | P2 | Start with iMessage, optionally Telegram/Slack. |
| 49 | mixture_of_agents | Hermes | Easy | P2 | Parallel API calls + synthesis. Use `TaskGroup`. |
| 50 | browser_navigate | Hermes | Hard | P3 | Browser automation — skip or use Browserbase. |
| 51 | browser_snapshot | Hermes | Hard | P3 | Depends on browser tool. |
| 52 | browser_click | Hermes | Hard | P3 | Depends on browser tool. |
| 53 | browser_type | Hermes | Hard | P3 | Depends on browser tool. |
| 54 | browser_scroll | Hermes | Hard | P3 | Depends on browser tool. |
| 55 | browser_back | Hermes | Hard | P3 | Depends on browser tool. |
| 56 | browser_press | Hermes | Hard | P3 | Depends on browser tool. |
| 57 | browser_close | Hermes | Hard | P3 | Depends on browser tool. |
| 58 | browser_get_images | Hermes | Hard | P3 | Depends on browser tool. |
| 59 | browser_vision | Hermes | Hard | P3 | Depends on browser tool. |
| 60 | browser_console | Hermes | Hard | P3 | Depends on browser tool. |
| 61 | skills_list | Hermes | Easy | P1 | Scan skills directory. Already partially present. |
| 62 | skill_view | Hermes | Easy | P1 | Read markdown file with progressive disclosure. |
| 63 | skill_manage | Hermes | Easy | P1 | File I/O for create/update/delete. |
| 64 | ha_list_entities | Hermes | Easy | P3 | Home Assistant REST API. Optional. |
| 65 | ha_get_state | Hermes | Easy | P3 | Home Assistant REST API. Optional. |
| 66 | ha_list_services | Hermes | Easy | P3 | Home Assistant REST API. Optional. |
| 67 | ha_call_service | Hermes | Easy | P3 | Home Assistant REST API. Optional. |
| 68 | honcho_context | Hermes | Easy | P3 | Honcho cloud API. Optional — use local vault instead. |
| 69 | honcho_profile | Hermes | Easy | P3 | Honcho cloud API. Optional. |
| 70 | honcho_search | Hermes | Easy | P3 | Honcho cloud API. Optional. |
| 71 | honcho_conclude | Hermes | Easy | P3 | Honcho cloud API. Optional. |
| 72 | rl_list_environments | Hermes | Easy | P3 | Tinker API. Niche use case. |
| 73 | rl_select_environment | Hermes | Easy | P3 | Tinker API. Niche. |
| 74 | rl_get_current_config | Hermes | Easy | P3 | Tinker API. Niche. |
| 75 | rl_edit_config | Hermes | Easy | P3 | Tinker API. Niche. |
| 76 | rl_start_training | Hermes | Easy | P3 | Tinker API. Niche. |
| 77 | rl_check_status | Hermes | Easy | P3 | Tinker API. Niche. |
| 78 | rl_stop_training | Hermes | Easy | P3 | Tinker API. Niche. |
| 79 | rl_get_results | Hermes | Easy | P3 | Tinker API. Niche. |
| 80 | rl_list_runs | Hermes | Easy | P3 | Tinker API. Niche. |
| 81 | rl_test_inference | Hermes | Easy | P3 | Tinker API. Niche. |
| 82 | apple-notes | Hermes (skill) | Easy | P2 | macOS-only. Use `EventKit` or AppleScript. |
| 83 | apple-reminders | Hermes (skill) | Easy | P2 | macOS-only. Use `EventKit`. |
| 84 | findmy | Hermes (skill) | Easy | P3 | macOS-only. AppleScript + screen capture. |
| 85 | imessage | Hermes (skill) | Easy | P2 | Same as iMessage Channel (#18). |
| 86 | github-* (6 skills) | Hermes (skill) | Easy | P2 | All use `gh` CLI or git + REST API. |
| 87 | google-workspace | Hermes (skill) | Medium | P2 | OAuth2 + Google Python client libs. Port to Swift URLSession. |
| 88 | notion | Hermes (skill) | Easy | P2 | Notion REST API via curl. Straightforward. |
| 89 | linear | Hermes (skill) | Easy | P2 | Linear GraphQL API. |
| 90 | obsidian | Hermes (skill) | Easy | P2 | File I/O in Obsidian vault directory. |
| 91 | arxiv | Hermes (skill) | Easy | P2 | arXiv REST API. No API key. |
| 92 | duckduckgo-search | Hermes (skill) | Easy | P2 | Free search. Can use `ddgs` CLI or DDGS Python lib. |
| 93 | jupyter-live-kernel | Hermes (skill) | Medium | P3 | Requires Jupyter runtime. Consider skipping. |
| 94 | ascii-art | Hermes (skill) | Easy | P3 | Fun but not critical. pyfiglet/cowsay equivalents. |
| 95 | excalidraw | Hermes (skill) | Easy | P3 | Generate `.excalidraw` JSON files. |
| 96 | youtube-content | Hermes (skill) | Easy | P2 | YouTube transcript API. |
| 97 | llama-cpp | Hermes (skill) | Medium | P2 | Already supported via MLX-Swift. Document as skill. |
| 98 | whisper | Hermes (skill) | Medium | P2 | Use `WhisperKit` or MLX Swift whisper. |
| 99 | stable-diffusion | Hermes (skill) | Medium | P2 | Use MLX Diffusers or call API. |
| 100 | vllm | Hermes (skill) | Hard | P3 | Server deployment. Not relevant for desktop app. |
| 101 | tensorrt-llm | Hermes (skill) | Hard | P3 | NVIDIA-only. Skip for macOS. |
| 102 | docker-management | Hermes (opt) | Easy | P3 | Docker CLI wrapper. Optional. |
| 103 | 1password | Hermes (opt) | Easy | P3 | 1Password CLI integration. Optional. |
| 104 | telephony | Hermes (opt) | Medium | P3 | Twilio integration. Optional. |
| 105 | bioinformatics | Hermes (opt) | Medium | P3 | 400+ bioSkills gateway. Very niche. |
| 106 | blackbox | Hermes (opt) | Easy | P3 | Blackbox AI CLI delegation. Optional. |
| 107 | base / solana | Hermes (opt) | Easy | P3 | Blockchain queries. Optional. |
| 108 | blender-mcp | Hermes (opt) | Hard | P3 | Blender socket control. Very niche. |
| 109 | meme-generation | Hermes (opt) | Easy | P3 | Pillow-based meme generator. Fun but optional. |
| 110 | agentmail | Hermes (opt) | Easy | P3 | Agent-owned email inbox. Optional. |
| 111 | neuroskill-bci | Hermes (opt) | Hard | P3 | BCI wearable integration. Extremely niche. |
| 112 | fastmcp | Hermes (opt) | Easy | P3 | FastMCP server building guide. Documentation skill. |
| 113 | qmd | Hermes (opt) | Easy | P3 | Local knowledge base search. Can use vault search instead. |
| 114 | sherlock | Hermes (opt) | Easy | P3 | OSINT username search. Optional. |
| 115 | oss-forensics | Hermes (opt) | Medium | P3 | GitHub forensic analysis. Optional. |

**Priority Legend:**
- **P0** — Already implemented or critical path. Do first.
- **P1** — High value, straightforward port. Do next.
- **P2** — Medium value, requires some work. Do after P1.
- **P3** — Nice to have, niche, or complex. Defer.

---

# Part 4: Unique "Specialty" Skills for Epistemos

These capabilities leverage Epistemos's unique technical stack (Rust + Swift FFI, Metal GPU, macOS-native integrations, knowledge graph) and have **no equivalent in OpenClaw or Hermes**. They are the true differentiators.

---

### 1. Graph-Native Memory Recall
- **Name:** `graph_recall`
- **What it does:** When the agent needs context, it doesn't just search a flat vector database — it queries the living knowledge graph. Follows edges from the current note to connected quotes, sources, wikilinks, and related notes. Returns structured subgraphs with relevance scores, not just text chunks.
- **Why it's unique:** No other agent framework has a GPU-rendered, Metal-accelerated knowledge graph as its native memory substrate. OpenClaw has basic memory. Hermes has MEMORY.md files. Neither has graph traversal as a first-class retrieval primitive.
- **Technical approach:**
  - Rust: `graph-engine` crate exposes `fuzzy_search()` + `subgraph_extract()` via FFI
  - Swift: `AgentGraphMemory.recall()` calls Rust with MMR reranking
  - Metal: Graph weights are visualized in real-time — recalled nodes pulse in the graph view
  - Parameters: `query` (string), `nodeId` (optional seed), `edgeTypes[]` (optional filter), `depth` (default 2), `limit` (default 10)

### 2. Metal-Accelerated Embedding Generation
- **Name:** `metal_embed`
- **What it does:** Generates text embeddings entirely on-device using Metal Performance Shaders. No network call, no API key, no latency. Supports batch embedding of entire vaults.
- **Why it's unique:** Hermes and OpenClaw both use cloud APIs or CPU-bound local models for embeddings. Epistemos can use MLX Swift with Metal GPU kernels for 10-50x faster embedding generation on Apple Silicon.
- **Technical approach:**
  - Use `mlx-swift` with a small embedding model (e.g., `nomic-embed-text-v1.5`)
  - Batch process vault chunks via `MTLCommandBuffer`
  - Store in `sqlite-vec` (SQLite extension with vector support) or Tantivy
  - FFI boundary: Swift passes text chunks → MLX generates vectors → Rust stores in graph

### 3. Screen-Aware Computer Use (AXorcist Integration)
- **Name:** `computer_use`
- **What it does:** The agent can see the user's screen (with permission), query the accessibility tree of any application, and simulate mouse/keyboard input — all natively on macOS. Not browser-based. Any app.
- **Why it's unique:** OpenClaw has browser CDP only. Hermes has no computer use. Epistemos has AXorcist (Swift accessibility framework) and `omega-ax` (Rust AX tree walker) already built. This is the "moat" feature.
- **Technical approach:**
  - `ScreenCaptureKit` for screenshots (with TCC permission gate)
  - `omega-ax` Rust crate for accessibility tree walking via `AXUIElement`
  - `CGEvent` for input simulation
  - SwiftUI permission flow with `AXIsProcessTrusted()` check
  - Tool schema: `screenshot()`, `get_accessibility_tree(appName?)`, `click(x, y)`, `type(text)`, `press(key)`, `find_element(criteria)`

### 4. Note-Aware Inline Agent (ProseEditor Integration)
- **Name:** `note_assist`
- **What it does:** The agent operates directly inside the note editor. It can suggest completions, rewrite selected text, generate summaries of the current note, find related notes, and insert AI-generated content at the cursor — all without leaving the editing context.
- **Why it's unique:** No agent framework has deep integration with a native TextKit 2 editor. The agent understands note structure (headers, lists, code blocks, wikilinks) and respects the user's cursor position.
- **Technical approach:**
  - Coordinator2 (existing) bridges `ProseTextView2` ↔ agent
  - Agent receives: current note body, cursor position, selected text, note metadata
  - Agent can: `suggest_completion(position)`, `rewrite_selection(style)`, `summarize_note()`, `find_related_notes()`, `insert_at_cursor(text)`
  - Streaming tokens appear as ghost text (like Xcode's Code Completion) with accept/reject

### 5. Knowledge Graph Auto-Enrichment
- **Name:** `graph_enrich`
- **What it does:** After any agent interaction, automatically extracts entities, relationships, and concepts from the conversation and adds them to the knowledge graph as new nodes/edges. The graph grows organically from every agent session.
- **Why it's unique:** OpenClaw and Hermes have no persistent knowledge graph. Their "memory" is flat text files. Epistemos can turn every agent conversation into structured, traversable knowledge.
- **Technical approach:**
  - Local NER (Named Entity Recognition) via CoreML or small MLX model
  - Relationship extraction via lightweight local LLM (Qwen 3.5 0.5B)
  - Rust `graph-engine` batch-inserts nodes/edges
  - SwiftUI shows "Graph enriched +3 nodes, +5 edges" toast
  - Runs in background via `NightBrainService` during idle time

### 6. Apple Intelligence Native Routing
- **Name:** `apple_intelligence_route`
- **What it does:** Automatically routes light tasks (rewrites, summaries, simple Q&A) to on-device Apple Intelligence, and complex tasks (coding, analysis, multi-step reasoning) to cloud models or local MLX. Transparent to the user.
- **Why it's unique:** No open-source agent framework has native Apple Intelligence integration. This is only possible on macOS 26+ with the private `IntelligencePlatform` framework.
- **Technical approach:**
  - `TriageService` (existing) already does this for the note editor
  - Extend to agent tool calls: classify intent → route to Apple Intelligence (latency <50ms) or MLX (latency <2s) or cloud
  - Apple Intelligence for: rewrite, summarize, ask (simple)
  - MLX for: continueWriting, outline, expand, analyze
  - Fallback to cloud for: complex coding, multi-turn reasoning

### 7. Real-Time Graph Visualization of Agent Reasoning
- **Name:** `reasoning_graph`
- **What it does:** As the agent thinks and uses tools, a live graph visualization shows the reasoning chain. Each tool call is a node. Results are child nodes. The user can explore the agent's "mind" as a graph.
- **Why it's unique:** No agent framework visualizes its reasoning process in a native GPU graph. This turns opaque AI reasoning into an explorable, interactive structure.
- **Technical approach:**
  - `AgentViewModel` emits `ToolCallEvent` + `ToolResultEvent`
  - `GraphState` (existing) creates ephemeral nodes for each event
  - Metal renderer (`MetalGraphView`) shows real-time graph growth
  - Node colors: thinking (gray), tool call (blue), result (green), error (red)
  - Click a node to see full tool input/output

### 8. FSEvents-Based File Watcher Agent
- **Name:** `file_watcher_agent`
- **What it does:** The agent monitors the vault directory (and optionally other directories) for file changes using macOS FSEvents. When files change, the agent can: suggest related note updates, detect broken wikilinks, propose graph re-connections, or alert the user to conflicts.
- **Why it's unique:** OpenClaw and Hermes have no file system integration beyond basic file tools. They don't proactively watch and react to changes.
- **Technical approach:**
  - `FSEventsStream` on vault directory (recursive)
  - Debounce rapid changes (500ms)
  - `NightBrainService` queues analysis jobs
  - Agent proposes actions via notification or inline suggestion
  - Respects `.epistemosignore` patterns

### 9. MLX-Constrained Tool Calling (XGrammar)
- **Name:** `constrained_tool_call`
- **What it does:** When using local MLX models, ensures the model generates valid tool call JSON by constraining the output grammar with XGrammar. Eliminates malformed tool calls from local models.
- **Why it's unique:** Hermes and OpenClaw don't use grammar-constrained decoding for tool calls with local models. They rely on prompt engineering which fails frequently.
- **Technical approach:**
  - `mlx-swift-structured` for XGrammar integration
  - Build JSON Schema → XGrammar grammar at runtime
  - Apply grammar mask during generation
  - 100% valid JSON output guarantee for tool calls
  - Already partially present in `ConstrainedDecodingService.swift`

### 10. Vault-Aware Code Generation
- **Name:** `vault_code_generate`
- **What it does:** When the agent generates code, it automatically checks the vault for existing code snippets, utility functions, and patterns the user has previously written. Suggests reusing existing code instead of generating new code from scratch.
- **Why it's unique:** No agent framework has a knowledge graph of the user's past code snippets integrated into the code generation pipeline.
- **Technical approach:**
  - Index code blocks in vault notes (markdown fenced code blocks)
  - Extract function signatures via tree-sitter (Rust `tree-sitter` crate)
  - Store in graph as `CodeSnippet` nodes linked to `Note` nodes
  - During code generation, query graph for similar signatures
  - Suggest: "You wrote a similar function in `utils.swift` (note: Programming Tips)"

### 11. Progressive Skill Activation via Graph Similarity
- **Name:** `smart_skill_activate`
- **What it does:** Instead of loading all skills into context (wasteful), the agent queries the knowledge graph for skills whose trigger patterns or descriptions are semantically similar to the current task. Only relevant skills are activated.
- **Why it's unique:** Hermes loads all enabled skills into context. OpenClaw loads all available skills. Epistemos can use graph semantic similarity for precise skill targeting.
- **Technical approach:**
  - Embed skill descriptions at install time
  - Store skill embeddings as graph node attributes
  - At session start, compute similarity between user query and skill embeddings
  - Activate only skills above threshold (e.g., cosine similarity > 0.75)
  - MMR reranking for diversity

### 12. Session-to-Note Auto-Transcription
- **Name:** `session_to_note`
- **What it does:** After an agent session, automatically transcribe the conversation into a structured note in the vault. Includes: user questions, agent reasoning, tool calls with results, final answers, and citations to sources used.
- **Why it's unique:** Hermes has session search (FTS5) but no automatic structured transcription. OpenClaw has no persistent knowledge management at all.
- **Technical approach:**
  - `TraceCollector` (existing) already captures session JSONL
  - Post-session, run lightweight local LLM to structure transcript
  - Generate markdown with collapsible sections for reasoning
  - Auto-link citations to vault notes using wikilink syntax
  - Save to `~/Epistemos/Sessions/YYYY-MM-DD-session-title.md`

---

## Summary: What to Port vs. What to Skip

### Port Immediately (P0 + P1 — ~40 items)
- All OpenClaw safety features (loop detection, budget, checkpoints, depth, MMR, repair, threat scanning, redaction)
- Core Hermes tools: file ops, terminal, web search/extract, vision, memory, session search, todo, skills, delegate, cron
- Cost tracking, auto-discovery, stream composition, session management
- iMessage channel, DM pairing

### Port Soon (P2 — ~25 items)
- Apple/macOS skills (Notes, Reminders, iMessage)
- GitHub skills, Google Workspace, Notion, Linear
- Image generation, TTS
- Onboarding wizard, doctor command
- Optional: Home Assistant, arXiv, YouTube, DuckDuckGo

### Skip or Defer (P3 — ~50 items)
- Browser automation tools (11 tools) — use native computer use instead
- RL training tools (9 tools) — extremely niche
- Docker/SSH/Modal/Singularity/Daytona terminal backends
- Honcho integration — use local vault memory
- Blockchain, BCI, bioinformatics, Blender — very niche
- A2UI/Canvas — major UI project, defer
- Gateway daemon — use `launchd` instead
- ACP protocol — MCP is preferred

### Build as Differentiators (12 specialty skills)
- Graph-native memory recall
- Metal-accelerated embeddings
- Screen-aware computer use (AXorcist)
- Note-aware inline agent
- Knowledge graph auto-enrichment
- Apple Intelligence routing
- Real-time reasoning graph visualization
- FSEvents file watcher agent
- MLX-constrained tool calling
- Vault-aware code generation
- Progressive skill activation
- Session-to-note auto-transcription

---

*End of document — 119 tools/skills from Hermes + 30 patterns from OpenClaw + 12 unique Epistemos specialties = 161 total capabilities analyzed*
