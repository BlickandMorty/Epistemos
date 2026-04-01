# Best of claw-code + OpenClaw → Epistemos Integration Guide
## Zero-Setup, Maximum Automation Agent Engineering

> **Philosophy**: Users should never touch a config file. Everything auto-discovers,
> auto-connects, auto-recovers. If something fails, the app fixes it silently.
> Manual setup is a bug.

---

## TABLE OF CONTENTS

1. [Immediate Fix: Why Tools Don't Load](#1-immediate-fix)
2. [Auto-Discovery & Zero-Config Patterns](#2-auto-discovery)
3. [Agent Loop Hardening](#3-agent-loop-hardening)
4. [MCP Tool Bundling (Direct API Connection)](#4-mcp-tool-bundling)
5. [Skills System (Markdown-Based)](#5-skills-system)
6. [Cost Tracking (Invisible)](#6-cost-tracking)
7. [Error Recovery & Failover](#7-error-recovery)
8. [Context Compaction](#8-context-compaction)
9. [iMessage Channel Integration](#9-imessage)
10. [Cron & Heartbeat (Always-On)](#10-cron-heartbeat)
11. [Auth Profile Rotation](#11-auth-rotation)
12. [Tool Loop Detection](#12-tool-loop-detection)
13. [Stream Composition](#13-stream-composition)
14. [Session Auto-Management](#14-session-management)
15. [Architecture Overview](#15-architecture)

---

## 1. IMMEDIATE FIX: WHY TOOLS DON'T LOAD {#1-immediate-fix}

### Problem

Every tool in hermes-agent has a `check_fn` gate. When it returns False, the tool
is **silently dropped** from the API request. The model receives zero tools, produces
plain text, and the loop exits after one turn.

### The Silent Killer

```python
# tools/registry.py:123-131
if entry.check_fn:
    if entry.check_fn not in check_results:
        try:
            check_results[entry.check_fn] = bool(entry.check_fn())
        except Exception:
            check_results[entry.check_fn] = False  # SILENT FAILURE
    if not check_results[entry.check_fn]:
        continue  # TOOL SILENTLY DROPPED
```

### Fix: Make check_fn Failures Visible

In `hermes-agent/tools/registry.py`, around line 126, add logging:

```python
try:
    result = bool(entry.check_fn())
    check_results[entry.check_fn] = result
    if not result:
        import sys
        print(f"[tool-gate] {entry.name}: check_fn FAILED — tool unavailable", file=sys.stderr)
except Exception as exc:
    check_results[entry.check_fn] = False
    import sys
    print(f"[tool-gate] {entry.name}: check_fn EXCEPTION: {exc}", file=sys.stderr)
```

### Fix: Ensure Core Tool Gates Pass

The dependency chain for hermes-acp tools:

```
check_terminal_requirements() → requires local env type
  ↓ (gates)
check_file_requirements() → delegates to terminal check
  ↓ (gates)
read_file, write_file, patch, search_files — ALL file tools

check_web_api_key() → requires TAVILY_API_KEY or EXA_API_KEY or FIRECRAWL_API_KEY
  ↓ (gates)
web_search, web_extract

check_browser_requirements() → requires agent-browser binary on PATH
  ↓ (gates)
ALL 11 browser tools
```

**In HermesSubprocessManager.swift**, ensure the subprocess environment includes:

```swift
// Required for terminal/file tools to pass check_fn
process.environment["HERMES_ENV_TYPE"] = "local"

// Required for web tools
process.environment["TAVILY_API_KEY"] = KeychainService.get("tavily_api_key") ?? ""

// Or use EXA (free tier available)
process.environment["EXA_API_KEY"] = KeychainService.get("exa_api_key") ?? ""
```

**Verify fix**: After launching, check stderr for `[tool-gate]` lines. You should see
tools passing, not failing.

### The Auto-Setup Philosophy

Don't ask users for API keys in a settings panel. Instead:

1. On first launch, check if keys exist in Keychain
2. If missing, show a **one-time onboarding card** in the agent panel:
   "To enable web search, paste your Tavily API key (free at tavily.com)"
3. Store in Keychain via `SecItemAdd`
4. Auto-pass to hermes subprocess environment on every launch
5. Tools auto-enable. User never thinks about it again.

---

## 2. AUTO-DISCOVERY & ZERO-CONFIG PATTERNS {#2-auto-discovery}

### Source: OpenClaw `src/plugins/discovery.ts`, `src/config/plugin-auto-enable.ts`

### Pattern: Cascading Defaults with Silent Fallback

OpenClaw's core principle: **if you do nothing, everything still works.**

```
User config (explicit)
  → Plugin auto-enable (detects configured channels/providers)
    → Model auto-discovery (queries local Ollama, cloud APIs)
      → Hardcoded defaults (anthropic/claude-opus-4-6)
```

### How to Port to Epistemos

#### Auto-Detect Available Models

```swift
// On app launch, probe available backends silently
actor ModelDiscovery {
    func discoverAvailableModels() async -> [DiscoveredModel] {
        var models: [DiscoveredModel] = []

        // 1. Check for local MLX models (always available)
        models += MLXModelScanner.scan(directory: mlxModelDirectory)

        // 2. Check for Anthropic API key
        if let key = KeychainService.get("anthropic_api_key") {
            models.append(.cloud(provider: .anthropic, model: "claude-sonnet-4-6", key: key))
        }

        // 3. Check for OpenAI API key
        if let key = KeychainService.get("openai_api_key") {
            models.append(.cloud(provider: .openai, model: "gpt-4.1", key: key))
        }

        // 4. Probe local Ollama (5s timeout, silent failure)
        if let ollamaModels = try? await probeOllama(timeout: 5) {
            models += ollamaModels
        }

        return models
    }
}
```

#### Auto-Enable Tools Based on Environment

```swift
// Don't ask "which tools do you want?" — detect what's available
func resolveAvailableTools() -> [String] {
    var tools = ["read_file", "write_file", "patch", "search_files", "terminal", "process"]

    // Web tools: auto-enable if ANY web API key exists
    if hasAnyKey(["TAVILY_API_KEY", "EXA_API_KEY", "FIRECRAWL_API_KEY"]) {
        tools += ["web_search", "web_extract"]
    }

    // Vision: auto-enable if screen recording permission granted
    if CGPreflightScreenCaptureAccess() {
        tools += ["vision_analyze"]
    }

    // Browser: auto-enable if AXorcist accessibility permission granted
    if AXIsProcessTrusted() {
        tools += ["browser_navigate", "browser_snapshot", "browser_click", ...]
    }

    return tools
}
```

#### Auto-Select Best Model for Task

```swift
// OpenClaw pattern: multilayer fallback, never fail
func selectModel(for task: AgentTask) -> ModelRef {
    // 1. User override (if they explicitly chose a model)
    if let override = task.modelOverride { return override }

    // 2. Task-appropriate model
    switch task.complexity {
    case .simple: return cheapestAvailable()    // Haiku, local Qwen
    case .standard: return defaultModel()       // Sonnet
    case .complex: return bestAvailable()       // Opus
    }
}

func defaultModel() -> ModelRef {
    // Cascade: configured → detected → hardcoded
    if let configured = EpistemosConfig.shared.defaultModel { return configured }
    if let anthropic = KeychainService.get("anthropic_api_key") {
        return .cloud(provider: .anthropic, model: "claude-sonnet-4-6")
    }
    if let localModel = MLXModelScanner.bestAvailable() { return .local(localModel) }
    // Final fallback — prompt user for API key
    return .needsSetup
}
```

---

## 3. AGENT LOOP HARDENING {#3-agent-loop-hardening}

### Source: claw-code `runtime/conversation.rs`, OpenClaw `pi-embedded-runner/run.ts`

### Pattern: Generic Trait-Based Loop (claw-code)

Your `agent_core` should use swappable backends:

```rust
// agent_core/src/traits.rs (new file)
pub trait ApiClient: Send {
    fn stream(&mut self, request: ApiRequest)
        -> Result<Vec<AssistantEvent>, AgentError>;
}

pub trait ToolExecutor: Send {
    fn execute(&mut self, tool_name: &str, input: &str)
        -> Result<String, ToolError>;
}

// agent_core/src/agent_loop.rs (refactor)
pub struct AgentLoop<C: ApiClient, T: ToolExecutor> {
    client: C,
    executor: T,
    max_iterations: usize,
    permission_policy: PermissionPolicy,
}
```

This lets you swap Claude ↔ OpenAI ↔ local MLX without touching the loop.

### Pattern: Retry Outer Loop (OpenClaw)

OpenClaw wraps the agent loop in a RETRY loop for auth/rate-limit recovery:

```
OUTER LOOP (max 24 + 8*profiles retries):
  try:
    INNER LOOP (agent turn — tool calls until done):
      stream response
      execute tools
      continue until no tool calls
  catch auth_error:
    rotate to next API key profile
    retry
  catch rate_limit:
    exponential backoff (250ms → 1500ms)
    retry
  catch context_overflow:
    compact session
    retry (max 3 compaction attempts)
  catch timeout:
    log, surface to user
```

### Pattern: Tool Result Truncation (OpenClaw)

Prevent context overflow from large tool outputs:

```rust
// agent_core/src/tools/truncation.rs (new)
const MAX_TOOL_RESULT_CHARS: usize = 30_000;

pub fn truncate_tool_result(result: &str) -> String {
    if result.len() <= MAX_TOOL_RESULT_CHARS {
        return result.to_string();
    }
    let keep = MAX_TOOL_RESULT_CHARS / 2;
    format!(
        "{}\n\n[... truncated {} chars ...]\n\n{}",
        &result[..keep],
        result.len() - MAX_TOOL_RESULT_CHARS,
        &result[result.len() - keep..]
    )
}
```

---

## 4. MCP TOOL BUNDLING (DIRECT API CONNECTION) {#4-mcp-tool-bundling}

### Source: OpenClaw `pi-bundle-mcp-tools.ts`, claw-code `runtime/mcp.rs`

### How It Works

MCP servers are external processes that expose tools via the Model Context Protocol.
Your app connects to them, discovers their tools, and merges those tools into the
agent's available tool set — so the LLM can call them like native tools.

### The Flow

```
App startup
  → Read MCP config (~/.epistemos/mcp.json or in-app settings)
  → For each server:
      1. Spawn subprocess (command + args)
      2. Connect via StdioClientTransport
      3. Call client.listTools() — get tool schemas
      4. Namespace tools: mcp__{server}__{tool}
      5. Merge into agent's tool array
  → Pass merged tools to hermes-agent
  → When model calls mcp__server__tool:
      Route to MCP client → client.callTool(name, args)
      Return result to agent loop
```

### Implementation for Epistemos

Your MCP bridge already exists (`Epistemos/Omega/MCPBridge.swift`). Wire it:

```swift
// In HermesSubprocessManager, before sending "start" command:
let mcpTools = await mcpBridge.discoverAllTools()
let mergedToolSchemas = hermsAcpTools + mcpTools.map { tool in
    [
        "type": "function",
        "function": [
            "name": "mcp__\(tool.serverName)__\(tool.name)",
            "description": tool.description,
            "parameters": tool.inputSchema
        ]
    ]
}
// Pass merged tools to hermes subprocess
```

### Tool Namespacing (claw-code pattern)

```rust
// Prevents collisions between MCP servers and native tools
pub fn mcp_tool_name(server_name: &str, tool_name: &str) -> String {
    format!("mcp__{}__{}",
        normalize(server_name),  // alphanumeric + underscore only
        normalize(tool_name)
    )
}
```

### Zero-Setup MCP

Don't make users edit JSON config. Auto-discover MCP servers:

1. Scan `~/.epistemos/mcp-servers/` for server configs
2. Check if popular MCP servers are installed (filesystem, git, etc.)
3. Auto-register discovered servers
4. Show installed servers in Settings → MCP (read-only, informational)

---

## 5. SKILLS SYSTEM (MARKDOWN-BASED) {#5-skills-system}

### Source: OpenClaw `skills/` (50+ bundled skills), `src/agents/skills/`

### What Skills Are

Skills are `.md` files with YAML frontmatter that give the agent domain-specific
instructions. They're injected into the system prompt so the model knows HOW to
use certain tools effectively.

### Skill File Format

```markdown
---
name: github
description: "GitHub operations via gh CLI"
emoji: "🐙"
requires:
  bins: ["gh"]
commands:
  - name: /github
    description: "Run GitHub operations"
---

# GitHub Skill

When the user asks about GitHub repositories, PRs, or issues:

1. Use `terminal` tool to run `gh` CLI commands
2. Always check `gh auth status` before operations
3. For PR reviews: `gh pr view <number> --comments`
4. For creating PRs: `gh pr create --title "..." --body "..."`

## Common Patterns

- List open PRs: `gh pr list --state open`
- View PR diff: `gh pr diff <number>`
- Merge PR: `gh pr merge <number> --squash`
```

### How to Load Skills in Epistemos

```swift
// Epistemos/Agent/SkillLoader.swift (new)
struct Skill {
    let name: String
    let description: String
    let instructions: String  // The markdown body
    let requiredBins: [String]
    let isAvailable: Bool     // Auto-checked via which/where
}

actor SkillLoader {
    private let skillDirs = [
        Bundle.main.resourcePath! + "/skills",           // Bundled
        NSHomeDirectory() + "/.epistemos/skills",         // User-installed
    ]

    func loadAvailableSkills() -> [Skill] {
        var skills: [Skill] = []
        for dir in skillDirs {
            for file in (try? FileManager.default.contentsOfDirectory(atPath: dir)) ?? [] {
                guard file.hasSuffix(".md") else { continue }
                let path = "\(dir)/\(file)"
                guard let content = try? String(contentsOfFile: path) else { continue }
                guard let skill = parseSkill(content) else { continue }

                // Auto-check requirements
                let available = skill.requiredBins.allSatisfy { bin in
                    FileManager.default.isExecutableFile(atPath: "/usr/local/bin/\(bin)")
                    || FileManager.default.isExecutableFile(atPath: "/opt/homebrew/bin/\(bin)")
                }
                skills.append(Skill(
                    name: skill.name,
                    description: skill.description,
                    instructions: skill.instructions,
                    requiredBins: skill.requiredBins,
                    isAvailable: available
                ))
            }
        }
        return skills
    }
}
```

### Inject Skills into System Prompt

```swift
// When building hermes "start" command:
let availableSkills = await skillLoader.loadAvailableSkills()
    .filter(\.isAvailable)
let skillsPrompt = availableSkills
    .map { "## Skill: \($0.name)\n\($0.instructions)" }
    .joined(separator: "\n\n---\n\n")

// Append to system prompt or pass as separate field
startPayload["skills_context"] = skillsPrompt
```

### Bundled Skills for Epistemos

Ship these skills with the app:

| Skill | Description | Requires |
|-------|-------------|----------|
| `github.md` | PR management, issues, code review | `gh` |
| `git.md` | Branch management, commits, rebasing | `git` |
| `xcode.md` | Build, test, archive, simulator management | `xcodebuild` |
| `swift-package.md` | SPM dependency management | `swift` |
| `homebrew.md` | Package installation and management | `brew` |
| `finder.md` | File management, Spotlight search | (built-in) |
| `notes.md` | Apple Notes integration | (built-in) |
| `calendar.md` | Calendar event management | (built-in) |
| `reminders.md` | Apple Reminders integration | (built-in) |
| `web-research.md` | Multi-source research patterns | web tools |

---

## 6. COST TRACKING (INVISIBLE) {#6-cost-tracking}

### Source: OpenClaw `ui/usage-helpers.ts`, claw-code `runtime/usage.rs`

### Pattern: Side-Effect Tracking

Cost tracking should be a **side effect** of agent execution, never a separate system.

```swift
// Epistemos/State/AgentCostTracker.swift
@Observable
final class AgentCostTracker {
    private(set) var sessions: [SessionCost] = []
    private(set) var totalCost: Double = 0

    struct SessionCost {
        let sessionId: String
        let model: String
        let inputTokens: Int
        let outputTokens: Int
        let cacheReadTokens: Int
        let cacheWriteTokens: Int
        let cost: Double
        let timestamp: Date
    }

    // Called automatically by AgentViewModel on each "complete" event
    func record(model: String, usage: TokenUsage) {
        let pricing = Self.pricing(for: model)
        let cost = Double(usage.inputTokens) * pricing.inputPerMillion / 1_000_000
                 + Double(usage.outputTokens) * pricing.outputPerMillion / 1_000_000
                 + Double(usage.cacheReadTokens) * pricing.cacheReadPerMillion / 1_000_000
        let session = SessionCost(/* ... */)
        sessions.append(session)
        totalCost += cost
    }

    static func pricing(for model: String) -> ModelPricing {
        switch model {
        case let m where m.contains("haiku"):  return .init(input: 1.0, output: 5.0)
        case let m where m.contains("sonnet"): return .init(input: 3.0, output: 15.0)
        case let m where m.contains("opus"):   return .init(input: 15.0, output: 75.0)
        default: return .init(input: 3.0, output: 15.0)  // Safe default
        }
    }
}
```

### Show in UI Without Asking

Display cost in the agent panel footer — always visible, never a separate settings page:

```
Session: $0.12 | Today: $2.34 | This month: $18.50
```

---

## 7. ERROR RECOVERY & FAILOVER {#7-error-recovery}

### Source: OpenClaw `run.ts`, `model-fallback.ts`, claw-code `api/error.rs`

### Pattern: Classify → Recover → Retry (Invisible to User)

```swift
// Epistemos/Agent/AgentErrorRecovery.swift
enum FailoverReason {
    case authError          // → rotate API key
    case rateLimited        // → exponential backoff
    case contextOverflow    // → compact session, retry
    case timeout            // → retry with shorter context
    case modelUnavailable   // → fallback to next model
    case serverError        // → retry after delay
}

func classifyError(_ error: Error, responseBody: String?) -> FailoverReason {
    if responseBody?.contains("authentication") == true { return .authError }
    if responseBody?.contains("rate_limit") == true { return .rateLimited }
    if responseBody?.contains("context_length") == true
       || responseBody?.contains("too many tokens") == true { return .contextOverflow }
    if error is URLError { return .timeout }
    return .serverError
}

func recover(from reason: FailoverReason, attempt: Int) async -> RecoveryAction {
    switch reason {
    case .authError:
        return .rotateApiKey
    case .rateLimited:
        let delay = min(0.25 * pow(2.0, Double(attempt)), 1.5)  // 250ms → 1.5s
        try? await Task.sleep(for: .seconds(delay))
        return .retry
    case .contextOverflow:
        guard attempt < 3 else { return .surfaceError("Context too large") }
        return .compactAndRetry
    case .timeout:
        return .retry
    case .modelUnavailable:
        return .fallbackModel
    case .serverError:
        guard attempt < 3 else { return .surfaceError("API unavailable") }
        try? await Task.sleep(for: .seconds(1))
        return .retry
    }
}
```

### User Never Sees Retries

The agent panel should show a subtle spinner change — "Retrying..." for 1-2 seconds —
then continue as if nothing happened. Only surface errors that are truly unrecoverable.

---

## 8. CONTEXT COMPACTION {#8-context-compaction}

### Source: claw-code `runtime/compact.rs`, OpenClaw `compaction.ts`

### The Continuation Message Pattern

When context is too long, summarize old messages but inject a meta-instruction:

```
"This session continues from a previous conversation.
Summary of prior context: {summary}
The most recent messages are preserved below.
Continue naturally. Do not re-summarize or ask follow-up questions about
the summary — treat it as background context and focus on the current task."
```

### Auto-Trigger Compaction

```swift
// Before each API call, check if compaction needed
func shouldCompact(messages: [Message], modelContextLimit: Int) -> Bool {
    let estimatedTokens = messages.reduce(0) { $0 + $1.text.count / 4 }
    return estimatedTokens > (modelContextLimit * 80 / 100)  // 80% threshold
}
```

### Tool Result Truncation (Prevent Overflow)

```swift
// After every tool execution, before adding to messages
func truncateIfNeeded(_ result: String, maxChars: Int = 30_000) -> String {
    guard result.count > maxChars else { return result }
    let keep = maxChars / 2
    let start = result.prefix(keep)
    let end = result.suffix(keep)
    return "\(start)\n\n[... truncated \(result.count - maxChars) chars ...]\n\n\(end)"
}
```

---

## 9. iMESSAGE CHANNEL INTEGRATION {#9-imessage}

### Source: OpenClaw `extensions/imessage/`, `extensions/bluebubbles/`

### Recommended Approach: Hybrid (SQLite Read + AppleScript Send)

This is what OpenClaw's `imsg` CLI does internally. For a native Swift app,
you can do it directly without external tools.

### Architecture

```
┌─────────────────────────────────────┐
│  iMessage Channel (Swift)           │
│                                     │
│  ┌─────────────┐  ┌──────────────┐ │
│  │ chat.db      │  │ AppleScript  │ │
│  │ SQLite reader│  │ sender       │ │
│  │ (incoming)   │  │ (outgoing)   │ │
│  └──────┬──────┘  └──────┬───────┘ │
│         │                │          │
│  ┌──────┴────────────────┴───────┐ │
│  │   iMessageChannel actor       │ │
│  │   - FSEvents monitor          │ │
│  │   - Echo cache (sent msg IDs) │ │
│  │   - DM allow-list             │ │
│  └──────────────┬────────────────┘ │
└─────────────────┼───────────────────┘
                  │
                  ↓
          Agent receives message
          → runs turn with tools
          → sends reply via AppleScript
```

### Implementation

```swift
// Epistemos/Channels/iMessageChannel.swift (new)
import SQLite3
import Foundation

actor iMessageChannel {
    private let chatDbPath = NSHomeDirectory() + "/Library/Messages/chat.db"
    private var lastMessageRowId: Int64 = 0
    private var sentMessageCache: Set<String> = []  // Prevent echo
    private var allowedSenders: Set<String> = []     // DM policy

    // MARK: - Incoming (SQLite polling via FSEvents)

    func startMonitoring(onMessage: @escaping (IncomingMessage) -> Void) {
        // Watch chat.db for changes
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: open(chatDbPath, O_EVTONLY),
            eventMask: .write,
            queue: .global()
        )
        source.setEventHandler { [weak self] in
            Task { await self?.pollNewMessages(handler: onMessage) }
        }
        source.resume()
    }

    private func pollNewMessages(handler: (IncomingMessage) -> Void) {
        var db: OpaquePointer?
        guard sqlite3_open_v2(chatDbPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else { return }
        defer { sqlite3_close(db) }

        let query = """
            SELECT m.ROWID, m.text, m.date, m.is_from_me,
                   h.id as sender, c.chat_identifier
            FROM message m
            JOIN chat_message_join cmj ON cmj.message_id = m.ROWID
            JOIN chat c ON c.ROWID = cmj.chat_id
            LEFT JOIN handle h ON h.ROWID = m.handle_id
            WHERE m.ROWID > ? AND m.is_from_me = 0
            ORDER BY m.ROWID ASC
            LIMIT 50
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else { return }
        sqlite3_bind_int64(stmt, 1, lastMessageRowId)
        defer { sqlite3_finalize(stmt) }

        while sqlite3_step(stmt) == SQLITE_ROW {
            let rowId = sqlite3_column_int64(stmt, 0)
            let text = String(cString: sqlite3_column_text(stmt, 1))
            let sender = String(cString: sqlite3_column_text(stmt, 4))
            let chat = String(cString: sqlite3_column_text(stmt, 5))

            lastMessageRowId = rowId

            // DM policy: only process from allowed senders
            guard allowedSenders.isEmpty || allowedSenders.contains(sender) else { continue }

            handler(IncomingMessage(text: text, sender: sender, chatId: chat))
        }
    }

    // MARK: - Outgoing (AppleScript)

    func sendMessage(text: String, to recipient: String) async throws {
        let script = """
        tell application "Messages"
            set targetService to 1st account whose service type = iMessage
            set targetBuddy to participant "\(recipient)" of targetService
            send "\(text.replacingOccurrences(of: "\"", with: "\\\""))" to targetBuddy
        end tell
        """
        var error: NSDictionary?
        NSAppleScript(source: script)?.executeAndReturnError(&error)
        if let error { throw iMessageError.sendFailed(error.description) }

        // Cache to prevent echo processing
        sentMessageCache.insert(text.prefix(100).description)
    }

    // MARK: - Configuration

    func addAllowedSender(_ sender: String) {
        allowedSenders.insert(sender)
    }
}
```

### Wiring to Agent

```swift
// In AgentViewModel or a new ChannelRouter
func setupiMessageChannel() {
    let channel = iMessageChannel()

    // Set allowed senders from stored config
    for sender in EpistemosConfig.shared.imessageAllowedSenders {
        await channel.addAllowedSender(sender)
    }

    await channel.startMonitoring { [weak self] message in
        Task { @MainActor in
            // Create agent turn from iMessage
            let response = await self?.runAgentTurn(
                prompt: message.text,
                context: "iMessage from \(message.sender)"
            )
            // Send reply
            if let reply = response?.text {
                try? await channel.sendMessage(text: reply, to: message.sender)
            }
        }
    }
}
```

### Permissions Required

```xml
<!-- Epistemos.entitlements -->
<key>com.apple.security.automation.apple-events</key>
<true/>
<!-- Send to Messages.app -->

<!-- Info.plist -->
<key>NSAppleEventsUsageDescription</key>
<string>Epistemos needs to send iMessages on your behalf</string>
```

Full Disk Access is required for reading `chat.db` — the app should detect this
and show a one-time permission card if not granted.

### Auto-Setup

1. On first launch, check if Full Disk Access is granted
2. If not, show card: "Enable iMessage? Grant Full Disk Access in System Settings"
3. Once granted, auto-start monitoring
4. First incoming message from unknown sender: show pairing prompt
5. User approves sender → added to allow-list → future messages auto-processed

---

## 10. CRON & HEARTBEAT (ALWAYS-ON) {#10-cron-heartbeat}

### Source: OpenClaw `src/cron/`, `src/auto-reply/heartbeat.ts`

### Pattern: Timer-Based Agent Wake-Up

No gateway server needed. Use macOS-native timers + GRDB persistence.

```swift
// Epistemos/Automation/CronScheduler.swift (new)
@Observable
final class CronScheduler {
    private var jobs: [CronJob] = []
    private var timers: [String: Timer] = []

    struct CronJob: Codable, Identifiable {
        let id: String
        let name: String
        let schedule: CronSchedule
        let prompt: String              // What to tell the agent
        let sessionTarget: SessionTarget // .main or .isolated(name)
        let enabled: Bool
        let lastRun: Date?
        let nextRun: Date?
    }

    enum SessionTarget: Codable {
        case main           // Run in user's main chat session
        case isolated(String) // Run in dedicated named session
    }

    // Load from GRDB on app launch
    func loadJobs() {
        jobs = try! GRDBManager.shared.read { db in
            try CronJob.fetchAll(db)
        }
        for job in jobs where job.enabled {
            scheduleTimer(for: job)
        }
    }

    // When timer fires
    private func executeJob(_ job: CronJob) async {
        let response = await AgentRunner.shared.runTurn(
            prompt: job.prompt,
            session: job.sessionTarget
        )
        // Store result
        try? GRDBManager.shared.write { db in
            var j = job
            j.lastRun = Date()
            j.nextRun = job.schedule.nextFireDate()
            try j.update(db)
        }
    }
}
```

### Heartbeat (Periodic Check-In)

```swift
// Simple timer-based heartbeat — no server needed
actor HeartbeatService {
    private var timer: Timer?
    private let interval: TimeInterval = 300  // 5 minutes

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { await self?.beat() }
        }
    }

    private func beat() async {
        // Collect pending system events
        var events: [String] = []
        if let newMessages = await iMessageChannel.shared?.unreadCount(), newMessages > 0 {
            events.append("\(newMessages) new iMessages")
        }
        if let cronResults = CronScheduler.shared.pendingResults() {
            events.append(cronResults)
        }

        guard !events.isEmpty else { return }

        // Wake agent with events
        let prompt = "System heartbeat. Events since last check:\n" + events.joined(separator: "\n")
        await AgentRunner.shared.runTurn(prompt: prompt, session: .main)
    }
}
```

### The Agent Can Create Its Own Cron Jobs

Expose cron as a tool to the agent:

```json
{
    "name": "schedule_task",
    "description": "Create a recurring scheduled task. The task will run automatically.",
    "parameters": {
        "type": "object",
        "properties": {
            "name": { "type": "string", "description": "Task name" },
            "schedule": { "type": "string", "description": "Cron expression (e.g., '0 9 * * *' for daily 9am)" },
            "prompt": { "type": "string", "description": "What to do when the task runs" }
        },
        "required": ["name", "schedule", "prompt"]
    }
}
```

Now the user can say "remind me to check PRs every morning at 9am" and the agent
creates the cron job itself.

---

## 11. AUTH PROFILE ROTATION {#11-auth-rotation}

### Source: OpenClaw `run.ts`, claw-code `api/client.rs`

### Pattern: Multiple API Keys with Automatic Failover

```swift
// Epistemos/State/AuthProfileManager.swift (new)
actor AuthProfileManager {
    struct Profile {
        let id: String
        let provider: String
        let apiKey: String
        var cooldownUntil: Date?
        var failureReason: String?
    }

    private var profiles: [String: [Profile]] = [:]  // provider → profiles

    func bestKey(for provider: String) -> String? {
        guard let candidates = profiles[provider] else { return nil }
        // Return first non-cooled-down profile
        let now = Date()
        return candidates.first(where: { ($0.cooldownUntil ?? .distantPast) < now })?.apiKey
    }

    func markFailed(provider: String, key: String, reason: String) {
        guard let idx = profiles[provider]?.firstIndex(where: { $0.apiKey == key }) else { return }
        profiles[provider]![idx].cooldownUntil = Date().addingTimeInterval(60)  // 1 min cooldown
        profiles[provider]![idx].failureReason = reason
    }
}
```

### Auto-Discover Keys from Keychain

```swift
// On launch, scan Keychain for all API keys
func discoverApiKeys() {
    let providers = ["anthropic", "openai", "perplexity", "tavily", "exa"]
    for provider in providers {
        // Check for numbered keys: anthropic_api_key_1, _2, _3...
        for i in 1...5 {
            if let key = KeychainService.get("\(provider)_api_key_\(i)") {
                authManager.addProfile(provider: provider, key: key)
            }
        }
        // Also check the base key
        if let key = KeychainService.get("\(provider)_api_key") {
            authManager.addProfile(provider: provider, key: key)
        }
    }
}
```

---

## 12. TOOL LOOP DETECTION {#12-tool-loop-detection}

### Source: OpenClaw `tool-loop-detection.ts`, your existing `OPENCLAW_FEATURE_SPEC.md`

### Pattern: Sliding Window Hash Comparison

```swift
// Epistemos/Agent/ToolLoopDetector.swift
@Observable
final class ToolLoopDetector {
    private var history: [(name: String, argsHash: String, resultHash: String?)] = []
    private let windowSize = 30
    private let warningThreshold = 5
    private let criticalThreshold = 10

    enum Detection {
        case ok
        case warning(String)     // Inject warning into next prompt
        case critical(String)    // Abort agent loop
    }

    func record(toolName: String, args: [String: Any]) {
        let hash = stableHash(args)
        history.append((toolName, hash, nil))
        if history.count > windowSize { history.removeFirst() }
    }

    func recordResult(toolName: String, args: [String: Any], result: String) {
        let argsHash = stableHash(args)
        if let idx = history.lastIndex(where: { $0.name == toolName && $0.argsHash == argsHash && $0.resultHash == nil }) {
            history[idx].resultHash = SHA256.hash(data: Data(result.utf8)).description
        }
    }

    func check(toolName: String, args: [String: Any]) -> Detection {
        let hash = stableHash(args)

        // Generic repeat: same tool + same args N times
        let repeatCount = history.filter { $0.name == toolName && $0.argsHash == hash }.count
        if repeatCount >= criticalThreshold { return .critical("Tool \(toolName) called \(repeatCount) times with same args") }
        if repeatCount >= warningThreshold { return .warning("You've called \(toolName) \(repeatCount) times with identical arguments. Try a different approach.") }

        // Ping-pong: alternating between two patterns
        if history.count >= 6 {
            let last6 = history.suffix(6)
            let unique = Set(last6.map { "\($0.name):\($0.argsHash)" })
            if unique.count == 2 {
                return .warning("You're oscillating between two tool calls. Break the cycle.")
            }
        }

        return .ok
    }

    func reset() { history.removeAll() }
}
```

### Wire into Agent Loop

When `check()` returns `.warning`, inject the warning text into the next user message.
When it returns `.critical`, abort the loop and tell the user.

---

## 13. STREAM COMPOSITION {#13-stream-composition}

### Source: OpenClaw `attempt.ts` stream wrapper chain, your `CoTStreamInterceptor.swift`

### Pattern: Stackable Stream Interceptors

```swift
// Epistemos/Bridge/StreamPipeline.swift (new)
protocol StreamInterceptor {
    func intercept(_ event: AgentStreamEvent) -> [AgentStreamEvent]
}

// Chain interceptors
struct StreamPipeline {
    private var interceptors: [StreamInterceptor] = []

    mutating func add(_ interceptor: StreamInterceptor) {
        interceptors.append(interceptor)
    }

    func process(_ event: AgentStreamEvent) -> [AgentStreamEvent] {
        var events = [event]
        for interceptor in interceptors {
            events = events.flatMap { interceptor.intercept($0) }
        }
        return events
    }
}

// Example interceptors:

struct ThinkingBlockDropper: StreamInterceptor {
    func intercept(_ event: AgentStreamEvent) -> [AgentStreamEvent] {
        if case .thinkingDelta = event { return [] }  // Drop thinking
        return [event]
    }
}

struct CostTracker: StreamInterceptor {
    func intercept(_ event: AgentStreamEvent) -> [AgentStreamEvent] {
        if case .complete(let usage) = event {
            AgentCostTracker.shared.record(usage: usage)
        }
        return [event]  // Pass through
    }
}

struct ToolLoopGuard: StreamInterceptor {
    let detector: ToolLoopDetector
    func intercept(_ event: AgentStreamEvent) -> [AgentStreamEvent] {
        if case .toolStarted(let name, let args) = event {
            let check = detector.check(toolName: name, args: args)
            if case .critical(let msg) = check {
                return [.error(msg)]  // Abort
            }
        }
        return [event]
    }
}
```

Usage:
```swift
var pipeline = StreamPipeline()
pipeline.add(CostTracker())
pipeline.add(ToolLoopGuard(detector: loopDetector))
// pipeline.add(ThinkingBlockDropper())  // Only if user wants to hide thinking
```

---

## 14. SESSION AUTO-MANAGEMENT {#14-session-management}

### Source: OpenClaw `session-manager-init.ts`, claw-code `runtime/session.rs`

### Pattern: Sessions Create, Persist, Compact Automatically

```swift
// Sessions should never require user action
actor SessionManager {
    // Auto-create on first message
    func getOrCreate(id: String) -> AgentSession {
        if let existing = loadFromGRDB(id: id) { return existing }
        return AgentSession(id: id, messages: [], createdAt: Date())
    }

    // Auto-persist after every turn
    func save(_ session: AgentSession) {
        try? GRDBManager.shared.write { db in
            try session.save(db)
        }
    }

    // Auto-compact when context exceeds 80% of model limit
    func compactIfNeeded(_ session: inout AgentSession, modelLimit: Int) {
        let estimatedTokens = session.messages.reduce(0) { $0 + $1.content.count / 4 }
        guard estimatedTokens > (modelLimit * 80 / 100) else { return }

        let preserveRecent = 4
        let oldMessages = session.messages.dropLast(preserveRecent)
        let summary = buildSummary(from: Array(oldMessages))

        session.messages = [
            .system(content: "Prior context summary: \(summary)\nContinue naturally."),
        ] + Array(session.messages.suffix(preserveRecent))
    }

    // Auto-resume: when user reopens agent, load last session
    func lastActiveSession() -> AgentSession? {
        try? GRDBManager.shared.read { db in
            try AgentSession.order(Column("updatedAt").desc).fetchOne(db)
        }
    }
}
```

---

## 15. ARCHITECTURE OVERVIEW {#15-architecture}

```
┌─────────────────────────────────────────────────────────┐
│                    Epistemos.app                         │
│                                                          │
│  ┌────────────┐  ┌─────────┐  ┌───────────────────────┐│
│  │ Graph View │  │ Notes   │  │ Agent Panel            ││
│  │ (Metal)    │  │ (TextKit)│  │ - Chat UI              ││
│  │            │  │         │  │ - Tool execution cards  ││
│  │            │  │         │  │ - Cost footer            ││
│  └────────────┘  └─────────┘  └──────────┬────────────┘│
│                                           │              │
│  ┌────────────────────────────────────────┴────────────┐│
│  │              AgentViewModel                         ││
│  │  - StreamPipeline (composable interceptors)         ││
│  │  - ToolLoopDetector                                 ││
│  │  - AgentCostTracker (invisible)                     ││
│  │  - SessionManager (auto-create/persist/compact)     ││
│  │  - ErrorRecovery (classify → recover → retry)       ││
│  └─────────────────────┬──────────────────────────────┘│
│                        │                                │
│  ┌─────────────────────┴──────────────────────────────┐│
│  │         HermesSubprocessManager                     ││
│  │  - Launches hermes-acp subprocess                   ││
│  │  - Content-Length framing + SHM                      ││
│  │  - MCP server (Swift tools → hermes)                 ││
│  │  - Environment setup (API keys from Keychain)        ││
│  │  - Skill injection (system prompt augmentation)      ││
│  └─────────────────────┬──────────────────────────────┘│
│                        │ stdio                          │
│  ┌─────────────────────┴──────────────────────────────┐│
│  │  Auto-Discovery Layer                               ││
│  │  - ModelDiscovery (probe Ollama, check Keychain)     ││
│  │  - SkillLoader (scan bundled + user skills)          ││
│  │  - MCP auto-connect (discover + bundle tools)        ││
│  │  - AuthProfileManager (multi-key rotation)           ││
│  │  - ToolAvailabilityChecker (auto-enable by env)      ││
│  └────────────────────────────────────────────────────┘│
│                                                          │
│  ┌────────────────────────────────────────────────────┐│
│  │  Automation Layer (no server needed)                ││
│  │  - CronScheduler (GRDB-backed timer jobs)           ││
│  │  - HeartbeatService (periodic agent wake)            ││
│  │  - iMessageChannel (SQLite read + AppleScript send) ││
│  │  - Future: Telegram, Slack channels                  ││
│  └────────────────────────────────────────────────────┘│
│                                                          │
│  ┌────────────────────────────────────────────────────┐│
│  │  Existing Strengths (keep as-is)                    ││
│  │  - MLX on-device inference                          ││
│  │  - Metal compute shaders                             ││
│  │  - AXorcist accessibility                            ││
│  │  - ScreenCaptureKit                                  ││
│  │  - GRDB + FTS                                        ││
│  │  - PTY pool                                          ││
│  │  - Graph memory                                      ││
│  └────────────────────────────────────────────────────┘│
└──────────────────────────────────────────────────────────┘
```

---

## IMPLEMENTATION PRIORITY

### Week 1: Make It Work
- [ ] Add check_fn debug logging to hermes-agent registry
- [ ] Fix environment variables in HermesSubprocessManager
- [ ] Verify tools load and model receives them
- [ ] Test multi-turn tool loop (ask agent to read a file and explain it)

### Week 2: Make It Robust
- [ ] Add error recovery (classify → retry → fallback)
- [ ] Add tool result truncation (30K char limit)
- [ ] Add tool loop detection
- [ ] Add cost tracking (invisible, in agent panel footer)

### Week 3: Make It Smart
- [ ] Add skill loader (bundled .md files)
- [ ] Add auto-model selection with fallback chain
- [ ] Add context compaction with continuation message
- [ ] Add stream pipeline (composable interceptors)

### Week 4: Make It Always-On
- [ ] Add CronScheduler (GRDB-backed)
- [ ] Add HeartbeatService
- [ ] Add schedule_task as agent tool
- [ ] Add session auto-management

### Month 2: Make It Connected
- [ ] Add iMessage channel (SQLite + AppleScript)
- [ ] Add MCP tool auto-bundling
- [ ] Add auth profile rotation
- [ ] Wire AXorcist as browser-like agent tool
- [ ] Wire ScreenCapture as vision tool

### Month 3: Expand Channels
- [ ] Add Telegram bot channel
- [ ] Add Slack integration
- [ ] Add more bundled skills
- [ ] Add user skill marketplace/sharing
