# Epistemos — Paste-Ready Implementation Prompts

**Created:** 2026-03-31
**Usage:** Copy-paste one prompt per session. Work top-to-bottom. Each prompt is self-contained.

---

## Prompt 0: Session Start (ALWAYS paste this first)

```
Read these files in this exact order:
1. CLAUDE.md
2. docs/MASTER_SESSION_PROMPT_v2.md
3. docs/AGENT_PROGRESS.md
4. docs/BEST_OF_CLAW_AND_OPENCLAW.md

Then tell me what's next on the tier list and start working.

Rules for this session:
- Always read files before editing them
- Search online between phases for insight about what you're implementing
- Run verification after each completed task
- Update docs/AGENT_PROGRESS.md after each item
```

---

## Prompt 1: Fix Tool Gates (THE ROOT CAUSE)

```
The agent feels like a dumb chatbot because tools silently fail to load. Fix this NOW.

Read these files first:
- hermes-agent/tools/registry.py (focus on lines 120-140, the check_fn gate)
- hermes-agent/toolsets.py (the hermes-acp toolset definition)
- hermes-agent/tools/terminal_tool.py (check_terminal_requirements)
- hermes-agent/tools/file_tools.py (check_file_requirements)
- hermes-agent/tools/web_tools.py (check_web_api_key)
- Epistemos/Agent/HermesSubprocessManager.swift (subprocess environment setup)
- hermes-agent/epistemos_bridge.py (bridge configuration)

Tasks:
1. In registry.py (~line 126), add stderr logging when check_fn fails or throws:
   - Print tool name + "check_fn FAILED" or "check_fn EXCEPTION: {exc}"
   - This makes silent failures visible

2. In epistemos_bridge.py, add debug print of loaded tool names after agent creation:
   - print(json.dumps([t["function"]["name"] for t in agent.tools]), file=sys.stderr)

3. In HermesSubprocessManager.swift, ensure subprocess environment includes:
   - HERMES_ENV_TYPE=local
   - TAVILY_API_KEY from Keychain (or EXA_API_KEY)
   - PATH that includes /usr/local/bin (for any CLI tools)
   - HOME set correctly
   - Ensure ~/.hermes/ directory exists (create if missing)

4. Trace the check_terminal_requirements() function — what exactly does it check?
   If it checks for env_type == "local", make sure that's set.
   If it checks for something else, fix it.

5. Test: launch the app, send a message, check stderr for tool gate logs.
   Expected: all 27 hermes-acp tools should appear in the tool list.

After fixing, update docs/AGENT_PROGRESS.md with the fix.
```

---

## Prompt 2: Auto-Discovery & Zero-Config

```
Read docs/BEST_OF_CLAW_AND_OPENCLAW.md section 2 (Auto-Discovery).
Read Epistemos/State/EpistemosConfig.swift.
Read Epistemos/App/AppBootstrap.swift.

Search online for: "macOS keychain SecItemCopyMatching swift best practices 2026"

Implement cascading auto-discovery so the app NEVER requires manual config:

1. API Key Discovery Chain (in AppBootstrap or a new AutoDiscovery service):
   - Check macOS Keychain (SecItemCopyMatching) for each provider key
   - Check environment variables (ANTHROPIC_API_KEY, TAVILY_API_KEY, etc.)
   - Check ~/.config/epistemos/config.toml
   - Check ~/.epistemos/config.toml
   - If no key found: show a SINGLE onboarding sheet (not per-key, one sheet for all)

2. Tool Dependency Discovery:
   - Check if agent-browser is on PATH (for browser tools)
   - Check if ~/.hermes/ exists (create if not)
   - Check if tavily/exa key exists (for web tools)
   - Log what's available vs missing at startup (INFO level, not errors)

3. Model Discovery:
   - Scan ~/Library/Application Support/Epistemos/models/ for .mlx directories
   - Scan HuggingFace cache (~/.cache/huggingface/)
   - Auto-select best available model for each role (router, embedder, reasoner)

4. The principle: if something is missing, degrade gracefully. Never crash.
   Missing web key? Web tools unavailable but file/terminal tools still work.
   Missing browser? Browser tools unavailable but everything else works.

Verify: app launches without any config files and tools still load (minus web/browser).
```

---

## Prompt 3: Agent Loop Hardening

```
Read docs/BEST_OF_CLAW_AND_OPENCLAW.md section 3 (Agent Loop Hardening).
Read docs/FUSED_AGENT_ENGINEERING_REPORT.md Part 2 (Engineering Patterns).
Read hermes-agent/run_agent.py (the main agent loop, around line 6302).
Read hermes-agent/epistemos_bridge.py.

Search online for: "anthropic api rate limit handling exponential backoff 2026"

Implement these hardening patterns in the hermes-agent loop:

1. Retryable Error Classification:
   - 429 (rate limit) → exponential backoff with jitter, max 5 retries
   - 529 (overloaded) → back off 30s, retry 3x
   - 500/502/503 → retry 3x with 2s base
   - 400 (bad request) → DO NOT retry, log and surface error
   - Network timeout → retry 3x with increasing timeout

2. Context Overflow Recovery:
   - When API returns "context too long" error
   - Auto-compact: summarize oldest 60% of turns into a continuation message
   - Retry with compacted context
   - Pattern from claw-code: insert "[Earlier conversation summarized]" + summary + recent turns

3. Thinking Block Preservation:
   - When stop_reason is "tool_use", the ENTIRE content array (including thinking blocks + signatures) must be passed back
   - Verify this is happening in epistemos_bridge.py
   - If thinking blocks are being stripped, fix it

4. Tool Result Truncation:
   - When a tool returns a massive result (e.g., reading a huge file)
   - Keep first 4K chars + last 1K chars, insert "[truncated]" marker
   - Prevents context overflow from greedy tool results
   - Pattern from OpenClaw: sessionLikelyHasOversizedToolResults() → truncate

5. Max-Turns Safety Rail:
   - max_turns=30 is a SAFETY rail, not a schedule
   - The agent decides when to stop (stop_reason == "end_turn")
   - Verify the loop doesn't force-exit early

Verify: send a multi-step task ("search for X, then create a note about it, then summarize")
and confirm the agent loops through all steps.
```

---

## Prompt 4: Skills System

```
Read docs/BEST_OF_CLAW_AND_OPENCLAW.md section 5 (Skills System).
Read hermes-agent/toolsets.py.

Search online for: "markdown yaml frontmatter python parser 2026"

Implement a markdown-based skills system:

1. Skill File Format (~/.epistemos/skills/*.md):
   ```yaml
   ---
   name: summarize-paper
   description: Summarize an academic paper into key findings
   trigger: "summarize paper|paper summary|tldr paper"
   category: research
   version: 1
   ---

   ## Instructions
   You are summarizing an academic paper. Follow these steps:
   1. Extract the title, authors, and publication venue
   2. Identify the core thesis/contribution
   3. List key findings (3-5 bullet points)
   4. Note methodology and limitations
   5. Rate relevance to user's knowledge graph

   ## Output Format
   Use this structure for the summary note...
   ```

2. Skill Loader (in hermes-agent or epistemos_bridge.py):
   - Scan ~/.epistemos/skills/ on agent startup
   - Parse YAML frontmatter + markdown body
   - Register as system prompt injections when trigger matches user input
   - Hot-reload: watch directory for changes (watchdog or polling)

3. Bundle Default Skills:
   - summarize-paper, extract-citations, compare-papers (research)
   - daily-review, weekly-digest (productivity)
   - code-review, explain-code (development)
   - web-research, fact-check (verification)

4. Skill Discovery MCP Tool:
   - Already have skill_discover in EpistemosMCPServer
   - Wire it to actually scan the skills directory
   - Return skill metadata for the agent to choose from

Verify: create a test skill, send a matching message, confirm skill injects into prompt.
```

---

## Prompt 5: iMessage Integration

```
Read docs/BEST_OF_CLAW_AND_OPENCLAW.md section 9 (iMessage).

Search online for: "macos chat.db sqlite schema 2026 imessage"
Search online for: "applescript send imessage swift 2026"

Implement iMessage as a communication channel:

1. Read Path (SQLite, read-only):
   - Open ~/Library/Messages/chat.db (requires Full Disk Access TCC)
   - Query: message JOIN chat_message_join JOIN chat JOIN handle
   - Extract: text, date, is_from_me, handle_id, chat_identifier
   - Poll for new messages (every 5s when active, 30s background)
   - TCC check: if no access, show permission request UI

2. Send Path (AppleScript):
   ```swift
   func sendMessage(_ text: String, to handle: String) async throws {
       let script = """
       tell application "Messages"
           set targetService to 1st account whose service type = iMessage
           set targetBuddy to participant "\(handle)" of targetService
           send "\(text)" to targetBuddy
       end tell
       """
       // Execute via NSAppleScript
   }
   ```
   - Requires com.apple.security.automation.apple-events entitlement
   - Sanitize input to prevent AppleScript injection

3. Agent Integration:
   - New hermes-acp tool: imessage_read (recent messages from contact)
   - New hermes-acp tool: imessage_send (send message to contact)
   - Permission gate: user must explicitly approve iMessage access

4. Alternative: BlueBubbles REST API
   - If user has BlueBubbles server running
   - REST calls to localhost:1234
   - No TCC needed
   - Auto-detect which path is available

Verify: read recent messages from a test contact, send a test message.
```

---

## Prompt 6: NightBrain & Cron

```
Read docs/BEST_OF_CLAW_AND_OPENCLAW.md section 10 (Cron & Heartbeat).
Read docs/MASTER_SESSION_PROMPT_v2.md (NightBrain section).
Read Epistemos/State/EpistemosConfig.swift (nightBrainMenuBarAgent setting).
Read agent_core/src/storage/vault.rs (Living Vault decay/GC).

Search online for: "NSBackgroundActivityScheduler swift 2026 best practices"

Implement NightBrain background processing:

1. Heartbeat Service (Swift):
   - NSBackgroundActivityScheduler with 15-minute interval
   - Only runs on AC power + idle + good thermal state
   - Tasks: memory decay, GC weak nodes, classify untagged vault entries
   - Calls Rust FFI: decay_memory_nodes(), gc_memory_nodes(), classify_vault_memory()

2. Memory Distillation:
   - During idle: scan vault for notes accessed >3 times
   - Generate compressed summaries (371→38 tokens via distillation)
   - Store summaries as "crystallized" vault entries
   - Update knowledge graph edges with new summary nodes

3. Cron Scheduler (Python side):
   - hermes-agent/cron/scheduler.py already exists
   - Wire it to run scheduled skills (daily-review, weekly-digest)
   - Cron expressions stored in ~/.epistemos/cron.toml
   - Bridge: Swift heartbeat triggers Python cron check

4. Menu Bar Mode:
   - When nightBrainMenuBarAgent is enabled
   - App hides main window, runs as menu bar agent
   - Status icon shows: idle / processing / error
   - Click to see recent distillation activity

Verify: enable NightBrain, wait for idle trigger, confirm decay/GC runs.
```

---

## Prompt 7: Stream Composition & Cost Tracking

```
Read docs/BEST_OF_CLAW_AND_OPENCLAW.md sections 6 (Cost Tracking) and 13 (Stream Composition).
Read Epistemos/Omega/Safety/CostTracker.swift.
Read Epistemos/Bridge/CoTStreamInterceptor.swift.

Search online for: "anthropic claude api pricing march 2026 per token"

Implement stream composition pipeline:

1. Stream Wrapper Chain (in order):
   Raw SSE → Thinking Extraction → Cost Accumulation → Credential Redaction → UI Rendering

2. Cost Tracker Enhancement:
   - Update CostTracker.swift with current March 2026 pricing
   - Track per-session and cumulative costs
   - Budget alert: warn user at $1, $5, $10 thresholds (configurable)
   - Store cost history in GRDB for analytics

3. Credential Redaction (already exists):
   - Verify CredentialRedactor catches all 9 patterns
   - Add: base64-encoded keys, JWT tokens, OAuth bearer tokens
   - Apply to BOTH outgoing (user→API) and incoming (API→user) streams

4. Thinking Block UI:
   - CoTStreamInterceptor extracts thinking blocks
   - Display as collapsible "Thinking..." section in chat UI
   - Preserve signatures for multi-turn conversations

Verify: send a message, confirm cost accumulates, thinking blocks display, no credentials leak.
```

---

## Prompt 8: Release Preparation

```
Read docs/MASTER_SESSION_PROMPT_v2.md (Distribution section).
Read docs/handoffs/2026-03-28-jojo-manual-release-checklist.md.
Read docs/handoffs/2026-03-28-final-claude-release-master-handoff.md.

Search online for: "xcode notarization stapled dmg 2026 command line"

Release preparation tasks:

1. DMG Packaging Script:
   - Build universal binary (arm64 + x86_64)
   - Codesign with Developer ID Application certificate
   - Create DMG with drag-to-Applications layout
   - Notarize via xcrun notarytool
   - Staple notarization ticket

2. Sparkle 2 Update Feed:
   - Generate appcast.xml with EdDSA signatures
   - SUFeedURL in Info.plist
   - Auto-update check on launch (configurable)

3. Legal Documents:
   - Privacy policy (required for notarization)
   - Open-source attribution page (GRDB MIT, MLX MIT, tantivy MIT, etc.)
   - Terms of service

4. Fresh-Machine Verification:
   - Launch on clean macOS (no dev tools)
   - Confirm: dylibs load, models download, Keychain prompt appears
   - Confirm: agent loop works after API key entry
   - Confirm: no crash on missing ~/.epistemos/

Verify: codesign --verify --deep --strict Epistemos.app passes.
```

---

## Emergency: If Agent Stops Looping

```
The agent is back to one-shot text responses. Debug checklist:

1. Check stderr for tool gate logs:
   - If you see "[tool-gate] X: check_fn FAILED" → fix that check_fn
   - If you see no tool gate logs → the logging patch isn't applied

2. Print loaded tools:
   - In epistemos_bridge.py after agent creation:
     print(json.dumps([t["function"]["name"] for t in agent.tools]), file=sys.stderr)
   - If list is empty: ALL check_fn gates are failing

3. Common failures:
   - HERMES_ENV_TYPE not set → terminal/file tools fail
   - No TAVILY/EXA key → web tools fail
   - ~/.hermes/ doesn't exist → session tools fail
   - agent-browser not on PATH → browser tools fail (this is OK, optional)

4. Verify the loop structure:
   - hermes-agent/run_agent.py line ~6302
   - while api_call_count < max_iterations:
   -   if response.tool_calls: continue  ← MUST loop
   -   else: break  ← only on final text

5. Verify thinking blocks aren't stripped:
   - When stop_reason == "tool_use", the FULL content array must go back
   - If thinking blocks are dropped, the agent loses context and degrades
```

---

## Session Workflow

1. **Always start with Prompt 0** (context restoration)
2. **Pick the next numbered prompt** based on what's not done
3. **Research online** before each phase
4. **Read files** before editing them
5. **Verify** after each task
6. **Update** `docs/AGENT_PROGRESS.md`
7. **Commit** when a prompt's tasks are complete
