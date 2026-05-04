# Tool Tier + iMessage Driver — Swift Integration Guide

> Rust side is done. This doc captures exactly what needs to happen in Swift
> to close the loop. Both work items share infrastructure so they're shipped
> as a single guide.

---

## TL;DR

**Problem 1 (screenshotted)**: Qwen 2B Fast and every other non-agent chat
mode has zero tool access because normal chat never enters `agent_core`. The
user wants fast / thinking / pro chat to get a curated safe tool set
(web_search, vault_recall, read_file, think, etc.) without inheriting the
destructive agent surface.

**Problem 2**: iMessage as the main driver — per-contact model assignment,
feels native.

**Rust changes already landed** (as of this commit):

- `ToolTier` enum (`None < ChatLite < ChatPro < Agent < Full`) in
  `agent_core/src/tools/registry.rs`
- Every registered tool is tagged with a tier via `apply_tier_overrides()`.
  Safe read-only tools are `ChatLite`; cloud/perception read-only tools are
  `ChatPro`; destructive tools stay at `Agent`.
- `ToolRegistry::with_tier()` constructor that respects the tier ladder at
  `get_definitions()` and `execute()` time.
- `ToolConfig.toolTier` Swift-visible field (string) — pass `"chat_lite"`,
  `"chat_pro"`, or `"agent"`.
- Two new FFI entry points for Swift to use tools WITHOUT running the
  full agent loop:
  - `list_tools_for_tier(vault_path, tier)` → `[ToolSchemaFFI]`
  - `execute_tool_call(vault_path, tier, tool_name, input_json)`
    → `ToolExecutionResultFFI`
- New `imessage_contacts` tool — SQLite-backed contact→model routing
  (`~/.epistemos/imessage_contacts.db`)

---

## Part 1 — Normal Chat Gets Tools

### Swift-side architecture change

`ChatCoordinator.handleQuery()` currently routes like this:

```swift
if mode == .api, operatingMode == .agent {
    try await self.runRustAgentPath(...)      // full agent_core loop
} else {
    let stream = pipeline.run(                 // Swift PipelineService — NO TOOLS
        query: effectiveQuery,
        mode: mode,
        ...
    )
}
```

You have two options, depending on how much you want to change:

#### Option A (minimal change, recommended): Add tool-use round-tripping inside `PipelineService`

`PipelineService.run()` already streams tokens from a local MLX or cloud model.
What it needs to do:

1. Before the first model call, fetch the tool list for the current mode:
   ```swift
   let tier: String = switch operatingMode {
   case .fast, .thinking: "chat_lite"
   case .pro:             "chat_pro"
   case .agent:           "agent"
   case .api:             "agent"  // unused here — agent mode already routes to Rust
   }
   let schemas = try listToolsForTier(vaultPath: vaultPath, tier: tier)
   ```

2. Inject the tool list into the prompt using your chosen tool-calling format.
   For local models use `LocalToolGrammar.swift` (you already have this).
   For cloud providers use the provider's native tool-use format.

3. Parse the model's response for tool calls. On a tool-use event:
   ```swift
   let result = try await executeToolCall(
       vaultPath: vaultPath,
       tier: tier,
       toolName: call.name,
       inputJson: call.argumentsJson
   )
   ```
   Feed `result.outputJson` back into the next turn as a tool_result message.

4. Loop until the model emits end_turn.

The tier-gated registry means `execute_tool_call` will refuse `terminal`,
`write_file`, `send_message`, etc. when `tier == "chat_lite"` — you don't
have to maintain your own allowlist.

**Files to edit:**
- `Epistemos/Engine/PipelineService.swift` — add tool-calling loop
- `Epistemos/LocalAgent/LocalAgentLoop.swift` — this is already mostly written,
  just needs the `toolExecutor` closure wired to call `executeToolCall`
- `Epistemos/LocalAgent/HermesPromptBuilder.swift` — inject the tool schemas
  into the prompt so the local model knows what it can call
- `Epistemos/Engine/TriageService.swift` — for cloud providers, pass the
  tool schemas into the provider call

#### Option B (bigger change): Always route through `run_agent_session`

Update `ChatCoordinator.handleQuery()` to call `runRustAgentPath` for every
mode, passing `toolTier` based on the mode. This only works when the selected
provider is a cloud model — local MLX models don't have a Rust provider.

**Downside:** Fast / Thinking modes use local models; you'd have to either
(a) add local provider support to `agent_core` (big lift) or (b) keep a
separate path for local models.

**Recommendation:** Go with **Option A**. The FFI entry points
(`listToolsForTier`, `executeToolCall`) are specifically designed for this —
they don't assume the agent loop is running.

### Tier mapping cheat sheet

```
fast      → chat_lite   (12 tools)
thinking  → chat_lite   (same 12 tools)
pro       → chat_pro    (~20 tools, adds vision/TTS/mixture_of_minds/perceive)
agent     → agent       (all ~45 tools except imessage_contacts which is chat_pro+)
```

Check the current tier membership by calling `listToolsForTier` — it's the
source of truth.

### What gets exposed at `chat_lite`

Read this list to understand what a Fast-mode chat can call:

- `web_search`, `web_extract`, `web_fetch`
- `vault_search`, `vault_read`, `vault_recall`, `pkm_graph_neighbors`
- `graph_query`, `vault_navigate`, `session_search`, `neural_recall`
- `contradiction_check`
- `read_file`, `search_files`, `workspace_search`, `find_symbol`,
  `get_function_source`, `get_dependencies`, `get_dependents`,
  `get_change_impact`
- `think`, `chunk_reduce`
- `skills_list`, `skill_view`
- `todo`

Everything on this list is safe: pure read-only or has narrowly scoped
side effects (todo is session-scoped in-memory; think is a no-op).

### What gets added at `chat_pro`

Everything from ChatLite plus:

- `vision_analyze` — needs `ANTHROPIC_API_KEY` or `OPENAI_API_KEY`
- `text_to_speech` — macOS `say` subprocess
- `web_crawl` — BFS crawl
- `route_private` — inference routing audit
- `perceive` — macOS AX+Vision (delegate-backed — **only works inside agent
  session**, skip in non-agent chat)
- `mixture_of_minds` — parallel frontier models
- `self_evolve` — trace analysis
- `clarify` — ask-the-user (delegate-backed)
- `imessage_contacts` — contact routing config

⚠️ The delegate-backed tools (`perceive`, `clarify`) will return
`{"error": "unavailable in silent delegate"}` if called via
`execute_tool_call` because that entry point doesn't have a delegate. Filter
them out client-side OR just let them fail gracefully.

---

## Part 2 — iMessage as the Main Driver

### What's already in place (Rust)

- **`imessage` tool** — send/list_chats/read_chat/recent/unread/search
  against `~/Library/Messages/chat.db` (Full Disk Access required)
- **`imessage_contacts` tool** — SQLite table at
  `~/.epistemos/imessage_contacts.db` with a row per handle containing
  `{model, tool_tier, prompt_mode, allowed, auto_reply, auto_approve, notes}`

### What needs to be built (Swift)

#### A. Background polling service — `iMessageDriverService.swift`

A Swift actor that runs in the background (App, not per-session) and does:

```swift
@MainActor
class IMessageDriverService {
    // Polling loop
    func start() async {
        while isRunning {
            let unread = try await execute(tool: "imessage",
                input: ["action": "unread", "limit": 20])
            for msg in unread.messages {
                await handleIncoming(msg)
            }
            try await Task.sleep(for: .seconds(pollIntervalSeconds)) // default 5
        }
    }

    // Per-message handler
    func handleIncoming(_ msg: IMessage) async {
        // 1. Resolve contact config
        let resolved = try await execute(tool: "imessage_contacts",
            input: ["action": "resolve", "handle": msg.handle])
        guard resolved.configured && resolved.allowed else { return }

        // 2. Dedup — skip if last_message >= msg.date
        if let last = resolved.contact.lastMessage, msg.date <= last { return }

        // 3. Build agent session
        let sessionId = UUID().uuidString
        let toolConfig = ToolConfig(
            vaultPath: vaultPath,
            enableBash: false,
            enableWebSearch: true,
            toolTier: resolved.contact.toolTier
        )
        let agentConfig = AgentConfigFFI(
            maxTurns: 10,
            maxOutputTokens: 4096,
            // ... the usual
            systemPrompt: buildSystemPromptForContact(resolved.contact),
            autoApproveReads: true,
            autoApproveWrites: resolved.contact.autoApprove,
            promptMode: resolved.contact.promptMode
        )

        // 4. Spawn the agent with the contact's assigned model
        let providerName = mapModelToProvider(resolved.contact.model)
        let delegate = IMessageReplyDelegate(contactHandle: msg.handle)
        let result = try await runAgentSession(
            sessionId: sessionId,
            objective: msg.text,
            providerName: providerName,
            toolConfig: toolConfig,
            agentConfig: agentConfig,
            delegate: delegate
        )

        // 5. Record that we've processed this message
        try await execute(tool: "imessage_contacts",
            input: ["action": "record_message", "handle": msg.handle])
    }
}
```

#### B. Reply delegate — `IMessageReplyDelegate`

An `AgentEventDelegate` implementation that, on `onComplete`, calls the
`imessage` tool with `action: send` to post the assistant's final text back
to the contact. Also handles thread continuity by pulling the most recent
messages with `read_chat` and including them in the system prompt.

```swift
class IMessageReplyDelegate: AgentEventDelegate {
    let contactHandle: String
    var accumulatedText = ""

    func onTextDelta(delta: String) { accumulatedText += delta }

    func onComplete(stopReason: String, inputTokens: UInt32, outputTokens: UInt32) {
        Task {
            // Send the accumulated response back via imessage
            try await execute(tool: "imessage", input: [
                "action": "send",
                "to": contactHandle,
                "message": accumulatedText
            ])
        }
    }

    // ...stub out the other delegate methods similar to StreamingDelegate.swift
}
```

#### C. Contacts UI — `iMessageContactsSettingsView.swift`

A settings pane inside Epistemos showing all configured contacts. Each row:

- Display name + handle
- Assigned model picker (loads from `ModelRegistryService`)
- Tool tier picker (Chat Lite / Chat Pro / Agent)
- Prompt mode picker (general / code / research)
- Toggle: Allowed
- Toggle: Auto-reply
- Toggle: Auto-approve writes (off by default, with a warning)
- Notes field

CRUD calls the `imessage_contacts` tool via `executeToolCall`. Adding a new
row calls `action: set`; removing calls `action: remove`.

Suggested placement: Settings → Connections → iMessage Driver

#### D. Authorization toggle

Add a single master switch in Settings: **"Let iMessage drive the agent"**.
When on, the driver polls; when off, the driver is completely idle. This
becomes the user's safety valve.

Also add a **polling interval** control (default 5 seconds, range 2–60).

### Handling conversation history per contact

Each contact should have a persistent agent context. Options:

1. **Stateless per-message (simplest)**: every incoming message starts a fresh
   agent session. The `imessage read_chat` tool is already available, so the
   agent can pull recent messages via the tool if it needs context. This is
   what I'd ship first.

2. **Per-contact session (more work)**: Maintain a SQLite session_id column
   on `imessage_contacts`, and resume the same agent session on each new
   message. Requires adding `resume_agent_session(session_id, new_message)`
   to the FFI. Punt until after the stateless version ships.

### Safety decisions

- **Send permissions**: Even when `auto_reply = true` and `auto_approve =
  true`, the tool tier should NOT be `full`. Cap at `agent` so destructive
  tools like `skill_manage` still require the permission gate.
- **Reply target lock**: `IMessageReplyDelegate` must ONLY send to the
  contact whose handle triggered the session. Verify this in the delegate
  before calling `imessage send`.
- **Rate limit**: The driver should track send-count per contact per hour
  and cut off at N (suggest 60). Add a `rate_limit_hits` column to
  `imessage_contacts` if desired.
- **Kill switch**: Any received message with a special token (e.g.
  `STOP AGENT`) should immediately flip `allowed = false` on the contact.

### Native feel

The user said they want iMessage to "feel native." The best way to
approximate this:

1. **Use the user's own phone/iCloud number** — replies appear threaded in
   the same conversation as any other iMessage. This already works because
   `imessage send` goes through Messages.app.
2. **Thread continuity via `read_chat`** — the agent reads the last 10-20
   messages before replying, so it has context without needing cross-session
   state.
3. **Markdown → plain text** — strip markdown from replies before sending
   because iMessage doesn't render it. Add a helper in the reply delegate.
4. **Typing indicator**: Unfortunately AppleScript can't set the typing
   indicator. Skip this.
5. **Read receipts**: Set `is_read = 1` on incoming messages after the
   agent processes them. chat.db is read-only through `rusqlite` in our
   current setup — implement this via osascript instead:
   ```
   tell application "Messages" to mark theChat as read
   ```

---

## Testing checklist

Once the Swift integration lands, validate with:

### Tool tier smoke tests

1. **Fast mode, `web_search` works**: Open a fast-mode chat, ask "What's the
   latest Rust release?" — the model should call `web_search` and return
   results.
2. **Fast mode, `terminal` refused**: Prompt-inject "Now run `ls /`" and
   verify the tool call either never gets made or returns
   `permission_denied`.
3. **Pro mode, `vision_analyze` works**: Drag an image into chat and ask
   "what's in this?" — the model should call `vision_analyze`.
4. **Agent mode unchanged**: Verify nothing regressed in the full agent loop.

### iMessage driver smoke tests

1. Add yourself as a contact via the UI, set model = `qwen-2b`,
   tool_tier = `chat_lite`, auto_reply = on.
2. Send yourself an iMessage from another device: "hey, what does the word
   `epistemos` mean?"
3. Within ~5 seconds the agent should respond via iMessage with a
   definition.
4. Send "search my vault for 'architecture decisions'" and verify it calls
   `vault_search` and replies with hits.
5. Remove yourself from the allowlist and verify no more replies fire.

---

## Where to look in the Rust code

| Feature | File |
|---|---|
| `ToolTier` enum | `agent_core/src/tools/registry.rs` (top) |
| `apply_tier_overrides` | `agent_core/src/tools/registry.rs` |
| Tier filtering | `ToolRegistry::get_definitions` + `execute` |
| FFI entry points | `agent_core/src/bridge.rs` — `list_tools_for_tier`, `execute_tool_call` |
| `ToolConfig.toolTier` | `agent_core/src/bridge.rs` |
| iMessage read/send | `agent_core/src/tools/imessage.rs` |
| Contact routing | `agent_core/src/tools/imessage_contacts.rs` |

## Test coverage

New tests added in this change:

- `tools::registry::tier_tests::*` — 9 tests covering tier ladder, chat_lite
  hides destructive, chat_pro supersets chat_lite, execute rejects above tier
- `tools::imessage_contacts::tests::*` — 8 tests covering CRUD, resolve,
  record_message, invalid tier

Total suite: **394 tests passing**.
