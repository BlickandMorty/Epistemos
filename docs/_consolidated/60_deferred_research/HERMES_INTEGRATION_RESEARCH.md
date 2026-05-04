# Hermes Agent Integration Research

## Current Plan File Base (2026-03-29)

Use these files as the current planning stack before changing the agent architecture again.

### Read First
1. `CLAUDE.md` — repo rules, non-negotiable constraints, current agent file map
2. `docs/HERMES_INTEGRATION_RESEARCH.md` — Hermes integration brief, research prompt, roadmap
3. `docs/AGENT_PROGRESS.md` — what has actually been built and verified so far
4. `docs/AGENT_DEEP_VERIFICATION_MANUAL.md` — canonical deep verification, manual runtime audit, screenshot evidence, and recursive 3-pass workflow
5. `AGENT_REPLACEMENT_PLAN.md` — honest replacement/cutover sequence
6. `AGENT_RUNTIME_ARCHITECTURE.md` — target ownership split and runtime module layout
7. `AGENT_MIGRATION_MATRIX.md` — KEEP / MIGRATE / REPLACE / DELETE map for current Omega surfaces
8. `AGENT_SOURCE_SYNTHESIS.md` — source-document consensus and non-negotiable architecture rules
9. `AGENT_TEST_PLAN.md` — required runtime validation coverage
10. `AGENT_BENCHMARKS.md` — latency and throughput targets
11. `docs/agent-system/AGENT_ARCHITECTURE.md` — deeper architecture/background reference

### Read When Touching Current Omega or App Wiring
1. `docs/PROGRESS.md` — older Omega/Knowledge Fusion work and prior app wiring
2. `docs/sprint-sessions/sprint-agent-3-mcp.md` — MCP + computer-use sprint seam
3. `Epistemos/App/AppBootstrap.swift` — app bootstrap seam
4. `Epistemos/Omega/Orchestrator/OrchestratorState.swift` — legacy/live Omega control path still in tree
5. `Epistemos/Omega/Orchestrator/OmegaLiveRuntimeState.swift` — transitional runtime UI shim

## Current Epistemos Research Packs

If you only want 10 files, use the fast pack below.
If you want a fuller pass, use the 30-file pack.
If you want the complete Hermes deep dive, use the 40-file Hermes list that follows.

### Fast Pack (10 files)
1. `agent_core/src/agent_loop.rs` — current Rust living loop
2. `agent_core/src/providers/claude.rs` — real provider path, SSE, thinking/tool continuity
3. `agent_core/src/bridge.rs` — UniFFI boundary into Swift
4. `omega-mcp/src/dispatcher.rs` — authoritative MCP dispatch and execution logging seam
5. `omega-mcp/src/catalog.rs` — built-in tool catalog used by Swift
6. `Epistemos/Omega/MCPBridge.swift` — current Swift bridge over `omega-mcp`
7. `Epistemos/LocalAgent/LocalAgentLoop.swift` — in-process local agent loop
8. `Epistemos/LocalAgent/ConfidenceRouter.swift` — local/cloud routing heuristics
9. `Epistemos/Omega/Inference/DeviceAgentService.swift` — device/computer-use execution seam
10. `hermes-agent/run_agent.py` — Hermes orchestration source of truth

### Deep Pack (30 files)

#### Plan + Architecture
1. `CLAUDE.md`
2. `docs/HERMES_INTEGRATION_RESEARCH.md`
3. `docs/AGENT_PROGRESS.md`
4. `AGENT_REPLACEMENT_PLAN.md`
5. `AGENT_RUNTIME_ARCHITECTURE.md`
6. `AGENT_MIGRATION_MATRIX.md`
7. `AGENT_TEST_PLAN.md`

#### Rust Runtime + MCP
8. `agent_core/src/agent_loop.rs`
9. `agent_core/src/providers/claude.rs`
10. `agent_core/src/bridge.rs`
11. `agent_core/src/routing.rs`
12. `agent_core/src/storage/vault.rs`
13. `omega-mcp/src/dispatcher.rs`
14. `omega-mcp/src/catalog.rs`
15. `omega-mcp/src/vault.rs`
16. `omega-ax/src/ax_tree.rs`
17. `omega-ax/src/input.rs`

#### Swift App + Local Agent
18. `Epistemos/Omega/MCPBridge.swift`
19. `Epistemos/Omega/Inference/DeviceAgentService.swift`
20. `Epistemos/Omega/Vision/VisualVerifyLoop.swift`
21. `Epistemos/Omega/Inference/DualBrainRouter.swift`
22. `Epistemos/Omega/Inference/ConstrainedDecodingService.swift`
23. `Epistemos/LocalAgent/HermesPromptBuilder.swift`
24. `Epistemos/LocalAgent/LocalToolGrammar.swift`
25. `Epistemos/LocalAgent/LocalAgentLoop.swift`
26. `Epistemos/LocalAgent/ConfidenceRouter.swift`
27. `Epistemos/ViewModels/AgentViewModel.swift`
28. `Epistemos/Views/Omega/OmegaPanel.swift`
29. `Epistemos/Views/OmegaPanel.swift`

#### Hermes Internals
30. `hermes-agent/run_agent.py`

## The 40 Files to Study (in priority order)

### Tier 1: Core Agent Loop (understand how it ACTUALLY works)
1. `hermes-agent/run_agent.py` — 8,283 lines. THE agent. `AIAgent` class, `run_conversation()`, tool dispatch, streaming, parallel execution. This is the soul.
2. `hermes-agent/agent/context_compressor.py` — 4-phase context compression (boundary protection, tool result replacement, structured summarization, iterative updates)
3. `hermes-agent/agent/prompt_builder.py` — System prompt assembly: identity + platform hints + skills index + context files + memory snapshots
4. `hermes-agent/agent/prompt_caching.py` — Anthropic cache_control breakpoints (system + last 3 messages = 85% input cost cut)
5. `hermes-agent/agent/smart_model_routing.py` — Route simple → cheap model, complex → primary model
6. `hermes-agent/agent/anthropic_adapter.py` — 1,034 lines. OpenAI-format → Anthropic Messages API conversion. Thinking block handling (adaptive for 4.6+, budget_tokens for older). OAuth credential management.

### Tier 2: Tool System (the 46 tools that make it an agent, not a chatbot)
7. `hermes-agent/tools/registry.py` — Tool registration, schema normalization, availability checks
8. `hermes-agent/tools/terminal_tool.py` — 1,356 lines. Shell execution across 6 backends
9. `hermes-agent/tools/file_tools.py` — read_file, write_file, search_files (ripgrep-backed)
10. `hermes-agent/tools/file_operations.py` — 1,164 lines. patch (fuzzy find-replace), move, copy, directory ops
11. `hermes-agent/tools/browser_tool.py` — 1,955 lines. agent-browser CLI, accessibility tree DOM, screenshots
12. `hermes-agent/tools/web_tools.py` — 1,843 lines. Web search + extraction with LLM summarization
13. `hermes-agent/tools/mcp_tool.py` — 1,895 lines. MCP server bridge (stdio + HTTP/StreamableHTTP). OAuth 2.1 PKCE. Reconnection with backoff.
14. `hermes-agent/tools/delegate_tool.py` — Sub-agent spawning (up to 3 concurrent, depth-limited)
15. `hermes-agent/tools/code_execution_tool.py` — Python sandboxed execution with UDS RPC for tool callbacks
16. `hermes-agent/tools/memory_tool.py` — MEMORY.md + USER.md atomic writes, section-delimited, char-bounded
17. `hermes-agent/tools/session_search_tool.py` — FTS5 across past sessions with LLM summarization
18. `hermes-agent/tools/skill_manager_tool.py` — Create/edit/patch/delete skills with SKILL.md + supporting files
19. `hermes-agent/tools/cronjob_tools.py` — JSON-file scheduling, gateway-ticked, natural language schedule expressions
20. `hermes-agent/tools/mixture_of_agents_tool.py` — 2-layer MoA (4 frontier models parallel, then synthesis)
21. `hermes-agent/tools/todo_tool.py` — In-memory task list with merge modes
22. `hermes-agent/tools/vision_tools.py` — Image analysis via multi-provider vision APIs

### Tier 3: Security (the patterns that keep it safe)
23. `hermes-agent/tools/approval.py` — 4-scope approval (once/session/always/deny). Pattern-based dangerous command detection. LLM risk assessment option.
24. `hermes-agent/tools/tirith_security.py` — External binary scanner for homograph URLs, terminal injection, pipe-to-interpreter
25. `hermes-agent/tools/skills_guard.py` — 1,105 lines. 75+ regex rules across 9 categories (exfiltration, injection, destructive, persistence, supply chain, etc.)
26. `hermes-agent/agent/redact.py` — Secret redaction (API keys, tokens, private keys, DB passwords). Partial masking.
27. `hermes-agent/tools/url_safety.py` — SSRF protection, private IP blocking

### Tier 4: Skills System (procedural memory)
28. `hermes-agent/tools/skills_tool.py` — 1,344 lines. skills_list, skill_view progressive disclosure
29. `hermes-agent/tools/skills_hub.py` — 2,621 lines. Multi-registry: GitHub, skills.sh, LobeHub, ClawHub. Quarantine + scanning.
30. `hermes-agent/skills/` (directory) — 27 built-in skill categories. YAML frontmatter + markdown.

### Tier 5: Gateway + Persistence (the runtime that keeps it alive)
31. `hermes-agent/gateway/run.py` — 5,924 lines. The gateway daemon. Session management, cron ticking, platform routing.
32. `hermes-agent/gateway/session.py` — 1,061 lines. Session lifecycle, message queuing, interrupt handling.
33. `hermes-agent/hermes_state.py` — 1,274 lines. SQLite-backed state: sessions, messages, FTS5 search.
34. `hermes-agent/cron/scheduler.py` — Cron scheduler ticked by gateway.
35. `hermes-agent/cron/jobs.py` — Job serialization, natural language schedule parsing.

### Tier 6: Adapters + Configuration
36. `hermes-agent/agent/model_metadata.py` — Dynamic model resolution from OpenRouter, provider APIs, local servers. Context windows, pricing.
37. `hermes-agent/agent/trajectory.py` — ShareGPT-format JSONL trajectory collection for RL training.
38. `hermes-agent/toolsets.py` — Tool grouping and restriction for different agent modes.
39. `hermes-agent/toolset_distributions.py` — Statistical analysis of which tools get used most.
40. `hermes-agent/AGENTS.md` — The bootstrap file that loads at every session start. Tool decision tree, context rules, response style.

---

## Deep Research Prompt

Give this to Perplexity Deep Research, Google Gemini Deep Research, or Claude with web search:

---

**RESEARCH PROMPT:**

I am building a native macOS AI agent app called Epistemos using Swift 6 + Rust (UniFFI FFI) + Metal + MLX-Swift. The app is a Personal Knowledge Management system with a living agentic loop. I want to integrate NousResearch/hermes-agent (16.2K stars, MIT, Python 3.11+, 248K lines) as either:

**(A) Option B: Managed subprocess** — Spawn hermes-agent as a managed Python process, connect via MCP stdio transport, kill on app quit. Hermes handles cloud API calls + tool execution + memory + skills. My app handles UI + local MLX inference + macOS native APIs (AXUIElement, ScreenCaptureKit, CGEvent). This is NOT inference sidecar — Hermes calls cloud APIs, not local models.

**(B) Option D: Hybrid** — Run Hermes as subprocess for orchestration, but port the data layer (MEMORY.md, SKILL.md, session SQLite, security patterns) to Rust so my app owns persistence. Hermes reads/writes through my app's vault.

Research the following with extreme depth:

### 1. Subprocess Management for macOS Native Apps
- What is the highest-performance, most reliable way for a native Swift macOS app to spawn and manage a long-running Python subprocess?
- How do apps like Docker Desktop, VS Code (with Python extension), Cursor, and Claude Code manage their subprocess lifecycles?
- What are the failure modes? (zombie processes, orphaned children, signal handling, crash recovery)
- Should I use Process (Foundation), posix_spawn, or XPC?
- How to bundle Python + hermes-agent inside a .app bundle for distribution? (py2app? pyinstaller? embedded Python framework? Nix?)
- What about App Store restrictions on subprocesses?

### 2. MCP stdio Transport Optimization
- What is the maximum throughput of JSON-RPC over stdio pipes on macOS?
- How does hermes-agent's MCP implementation (tools/mcp_tool.py) handle reconnection, schema normalization, and credential stripping?
- What are the latency characteristics of stdio vs HTTP+SSE vs Unix domain sockets for MCP on localhost?
- How do Ghost OS, Goose (Block), and Claude Code implement their MCP stdio bridges?
- Can I use the official Swift MCP SDK (modelcontextprotocol/swift-sdk) StdioTransport to connect to Hermes?

### 3. Zero-Copy Data Sharing Between Swift and Python
- What are the fastest IPC mechanisms between a Swift process and a Python subprocess on macOS?
- Compare: stdio pipes, Unix domain sockets, mmap shared memory, XPC, gRPC (via tonic + grpcio)
- For large payloads (vault search results, screenshot images, AX trees), what avoids serialization overhead?
- How does BoltFFI compare to stdio JSON-RPC for cross-process communication?
- Can I use Arrow IPC or Cap'n Proto for zero-copy schema-typed message passing?

### 4. Extending Hermes with Native macOS Tools
- Hermes has no native macOS computer-use (it uses agent-browser for Chromium). How do I add:
  - AXUIElement accessibility tree queries (via AXorcist Swift library or omega-ax Rust crate)
  - ScreenCaptureKit screen capture
  - CGEvent input simulation
  - Apple Shortcuts integration
  - Native file system watcher (FSEvents)
- Should these be MCP servers that Hermes connects to, or should they be tools registered in Hermes's Python registry?
- How does Ghost OS (ghostwright/ghost-os) expose its 29 macOS tools as MCP servers?

### 5. Making Hermes Better Than Stock
- What tools/capabilities from these projects should be added on top of Hermes:
  - Ghost OS (AX-first computer use, recipe replay, AXorcist)
  - Goose by Block (Rust agent core, MCP-native tools)
  - Aider (Architect/Editor dual-model split)
  - Plandex (cumulative diff sandbox, tree-sitter project maps)
  - Agent S3/Simular (Behavior Best-of-N rollouts, flat agent architecture)
  - Fazm (ScreenCaptureKit pipeline, WhisperKit voice, adaptive capture)
  - mlx-swift-structured (grammar-constrained local decoding with XGrammar)
  - AXorcist (chainable fuzzy AX queries)
  - MCP Swift SDK (official client + server)
  - Crush (mid-session model hot-swap)
- What patterns from Claude Code's architecture are worth replicating?
- What about the "think" tool (zero-cost reasoning tool) from Anthropic's agent documentation?

### 6. Security Hardening
- Hermes has 75+ skill-scanning regex patterns, Tirith binary scanner, SSRF protection, secret redaction, and 4-scope approval. What else should be added for a macOS native app?
- How to sandbox the Python subprocess (App Sandbox, Process sandboxing, seccomp-bpf equivalent on macOS)?
- How to prevent the Python subprocess from accessing the Keychain, user documents, or other apps' data?
- What are the TCC (Transparency, Consent, Control) implications of spawning a subprocess?

### 7. Distribution
- How to distribute a macOS app that bundles a Python runtime + hermes-agent?
- App Store vs direct distribution (notarization, Gatekeeper)?
- Size optimization: can hermes-agent be trimmed (remove gateway, messaging platforms, Docker/SSH backends)?
- How to auto-update Hermes independently of the app?

### 8. Performance Benchmarks
- What are realistic latency numbers for: stdio pipe round-trip, MCP tool call, Hermes agent turn, context compression?
- How does Hermes compare to Goose, OpenClaw, Claude Code on SWE-bench, TerminalBench, OSWorld?
- What are the memory/CPU costs of running a Python 3.11 subprocess alongside a Metal-accelerated Swift app?

Provide concrete code examples, architecture diagrams, and specific library recommendations. Cite GitHub repos, benchmarks, and documentation. Prioritize production-ready solutions over theoretical approaches.

---

## Option B Architecture Sketch

```
┌──────────────────────────────────────────────────────────┐
│                    Epistemos.app (Swift 6)                 │
│                                                            │
│  ┌─────────────────┐  ┌──────────────────────────────┐    │
│  │  SwiftUI Views   │  │  MLX-Swift Local Inference    │    │
│  │  OmegaPanel      │  │  (Qwen 3.5, Hermes-3)        │    │
│  │  AgentViewModel   │  │  ConstrainedDecoding (XGrammar)│   │
│  └────────┬─────────┘  └──────────────────────────────┘    │
│           │                                                 │
│  ┌────────▼─────────────────────────────────────────────┐  │
│  │  MCP Client (modelcontextprotocol/swift-sdk)          │  │
│  │  StdioTransport → hermes-agent subprocess             │  │
│  │  + Ghost OS MCP server (29 macOS tools)               │  │
│  │  + Custom MCP server (vault, AX, screenshots)         │  │
│  └────────┬─────────────────────────────────────────────┘  │
│           │ stdio JSON-RPC                                  │
│  ┌────────▼─────────────────────────────────────────────┐  │
│  │  omega-ax (Rust/UniFFI) — AXUIElement + CGEvent       │  │
│  │  omega-mcp (Rust/UniFFI) — Tool catalog + vault       │  │
│  │  agent_core (Rust/UniFFI) — Fallback loop if no Hermes│  │
│  └──────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────┘
           │ stdio pipe (managed subprocess)
┌──────────▼──────────────────────────────────────────────┐
│              hermes-agent (Python 3.11+)                   │
│                                                            │
│  ┌────────────┐ ┌────────────┐ ┌───────────────────┐     │
│  │ Agent Loop   │ │ 46 Tools    │ │ Skills (27 cats)   │    │
│  │ run_agent.py │ │ tools/*.py  │ │ skills/*/SKILL.md  │    │
│  └──────┬──────┘ └──────┬─────┘ └───────────────────┘     │
│         │               │                                   │
│  ┌──────▼───────────────▼──────────────────────────────┐  │
│  │  Memory (MEMORY.md + USER.md + SQLite FTS5)          │  │
│  │  Security (skills_guard + approval + tirith + redact) │  │
│  │  Cron (scheduler + jobs)                              │  │
│  │  MCP Client (connects back to Epistemos's MCP servers)│  │
│  │  Anthropic/OpenRouter/OpenAI cloud API calls          │  │
│  └──────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────┘

FLOW:
1. User types in OmegaPanel
2. Swift decides: local (MLX) or cloud (Hermes)?
3. If cloud: sends objective to Hermes via MCP stdio
4. Hermes runs its full agent loop (tools, memory, skills, security)
5. Hermes calls Epistemos's MCP servers for macOS-native operations
6. Results stream back to Swift via MCP notifications
7. Swift renders in OmegaPanel

KEY INSIGHT: Hermes and Epistemos are PEERS over MCP.
Hermes calls Epistemos for macOS tools.
Epistemos calls Hermes for cloud agent orchestration.
Both speak MCP. Neither is subordinate.
```

---

## Feature Roadmap (from open-source repo analysis)

Sources: everything-claude-code, claude-mem, awesome-claude-code, anthropics/skills, continue, autogen, awesome-hermes-agent, superpowers, get-shit-done, n8n-mcp

### Sprint F1: Toolbox UI + Core Features (HIGH priority)

**Task F1.1: Slash-Command Palette (Toolbox)**
- Sources: everything-claude-code (116k stars), get-shit-done (44k stars)
- File: `Epistemos/Views/Omega/ToolboxPanel.swift`
- Native NSPanel with fuzzy search (like Spotlight). User types `/plan`, `/research`, `/review`, `/brainstorm`, `/quick`
- Each command dispatches a preconfigured system prompt + tool subset + workflow mode
- Searchable over: built-in commands, installed skills, automation workflows, specialist agents
- Keyboard shortcut: Cmd+K
- SwiftUI SearchableList with sections: Quick Actions, Skills, Automations, Specialists
- Bottom bar shows: session token count + cost estimate

**Task F1.2: Task Decomposition with Checkpoints**
- Sources: superpowers (122k stars), get-shit-done (44k stars)
- File: `Epistemos/Views/Omega/TaskPlanView.swift`
- Before any multi-step execution, agent generates an editable task plan
- Each step has a checkpoint level: green (auto-proceed), yellow (pause + show results), red (require explicit approval)
- User can edit step descriptions, reorder, delete, or add steps before execution begins
- During execution, completed steps show checkmarks; current step pulses
- 2-5 minute time estimates per task (from superpowers pattern)
- "Skip planning" toggle for quick one-shot tasks

**Task F1.3: Phase Workflow State Machine**
- Sources: get-shit-done (44k stars)
- File: `Epistemos/State/WorkflowPhaseState.swift`
- Four phases: Discussion -> Planning -> Execution -> Verification
- Visual sidebar indicator showing current phase with transitions
- Agent refuses to execute until planning phase approved by user
- Each phase has its own context window: Discussion sees full chat, Planning sees goal + constraints, Execution sees plan + tools, Verification sees output + original goal
- Phase transitions are explicit user actions (not auto-advanced)

**Task F1.4: Usage Cost Dashboard**
- Sources: claude-mem (42k stars), awesome-claude-code (34k stars), everything-claude-code
- File: `Epistemos/Views/Settings/UsageDashboardView.swift`
- Real-time token count + dollar cost per session in OmegaPanel footer
- Preferences panel: daily/weekly/monthly spend with per-model breakdown
- Per-model pricing from agent_core's ProviderCapabilities (already has cost_per_million fields)
- Data source: accumulate from StreamingDelegate token events (already streamed)
- Budget alerts: user sets monthly cap, warning at 80%, hard stop at 100%

### Sprint F2: Memory + Skills (HIGH priority)

**Task F2.1: 3-Layer Progressive Memory Retrieval**
- Source: claude-mem (42k stars)
- Files: `agent_core/src/storage/progressive_recall.rs`, `Epistemos/Views/Omega/MemoryTimelineView.swift`
- Layer 1: Compact indexed results (~50 tokens each) — always shown
- Layer 2: Timeline view with timestamps and session grouping — on expand
- Layer 3: Full observation with all context — on demand
- 10x token savings vs loading full memories into context
- SwiftUI: expandable cards that grow from title → summary → full content
- Token count badges on each result so user sees context cost before expanding

**Task F2.2: Privacy Tags**
- Source: claude-mem
- `@private` annotation in vault notes excludes chunks from embedding index and agent context
- Implementation: chunker skips `@private` blocks, GRDB/tantivy index filters them
- UI: visual indicator in note editor showing which sections are agent-visible vs private

**Task F2.3: SKILL.md Format (Anthropic Canonical)**
- Source: anthropics/skills (official)
- Files: `Epistemos/Agent/SkillManifest.swift`, `agent_core/src/skills/manifest.rs`
- 3-level progressive disclosure:
  - Metadata (~100 words, always in context): name, description, trigger patterns
  - Instructions (<500 lines, loaded on activation): full system prompt, tool config, constraints
  - Resources (unbounded, loaded per-tool-call): scripts, templates, reference docs
- Skill trigger = embedding similarity between user intent and skill description
- "Test Skill Trigger" panel: user types sample queries, sees which skills would activate
- Import Hermes Agent's 27 skill categories as seed content

**Task F2.4: Post-Task Auto-Skill Creation**
- Sources: everything-claude-code, awesome-hermes-agent
- After completing a multi-step task, offer "Save as Skill?"
- Serialize: the objective, system prompt modifications, tool call sequence, successful patterns
- User edits the draft skill name/description, then saves to vault as SKILL.md
- Next time a similar task appears, the skill auto-activates

### Sprint F3: Multi-Agent + Automation (HIGH priority)

**Task F3.1: Agent-as-Tool Composition**
- Source: autogen (56k stars)
- File: `agent_core/src/tools/agent_tool.rs`
- Any registered agent becomes a callable tool for other agents
- `use_agent(name: "researcher", query: "find sources on X")` returns structured results
- Implements the `ToolHandler` trait in agent_core
- Depth-limited (max 2 levels) to prevent recursive loops
- Each sub-agent gets restricted tool subset (no delegation, no send_message)

**Task F3.2: Roundtable Mode (Group Chat)**
- Source: autogen (56k stars)
- File: `Epistemos/Views/Omega/RoundtableView.swift`
- User poses a question, 2-3 specialist agents take turns responding
- Coordinator agent decides who speaks next based on conversation flow
- Roles: Devil's Advocate, Supporter, Synthesizer (or user-defined)
- Final synthesis agent produces a combined recommendation
- UI: chat bubbles color-coded per agent with role badges

**Task F3.3: n8n MCP Integration (Workflow Automation)**
- Source: n8n-mcp (17k stars)
- File: `Epistemos/Agent/N8NMCPClient.swift`
- Connect to user's n8n instance as an MCP server
- Exposes 1,396 automation nodes as agent-callable tools
- Agent can: send emails, post to Slack, update Google Sheets, create Notion pages
- "Automations" section in Toolbox palette showing available workflows
- "Dry Run" mode shows what would happen without executing
- USE as MCP server — no porting needed, just connect via MCP Swift SDK

**Task F3.4: Scheduled Agent Tasks (Cron)**
- Sources: awesome-hermes-agent, hermes-agent cron system
- File: `Epistemos/Agent/AgentScheduler.swift`
- "Scheduled Tasks" panel in preferences
- Natural language: "Every morning at 9am, summarize my inbox"
- Cron expression under the hood (from hermes-agent/cron/)
- Cost guardrails: estimated cost per run, monthly budget cap
- Results delivered to: vault note, notification, or Omega panel
- Runs via: Hermes subprocess if available, agent_core fallback if not

### Sprint F4: Polish + Secondary Features (MEDIUM priority)

**Task F4.1: Session Full-Text Search**
- Source: awesome-claude-code
- File: `Epistemos/Views/Omega/SessionSearchView.swift`
- Spotlight-like search across all past agent conversations
- FTS5 index on session transcripts (hermes_state.py pattern)
- Results show: session date, matched excerpt, token cost of that session
- Tappable to reopen the full conversation

**Task F4.2: Brainstorm Mode (Socratic)**
- Source: superpowers (122k stars)
- Toggle in Omega panel input bar
- When enabled: agent asks 3-5 clarifying questions before doing any work
- Each question refines the plan iteratively
- User answers inline; agent incorporates answers into final plan
- Auto-disables after planning phase completes

**Task F4.3: Two-Stage Review Subagent**
- Source: superpowers (122k stars)
- After any multi-step task completes, auto-spawn a fresh "Reviewer" agent
- Reviewer has NO access to the original agent's reasoning — only sees output + original goal
- Flags: missing requirements, quality issues, hallucinations
- UI: review results appear as annotations on the output

**Task F4.4: Policy Notes as Review Agents**
- Source: continue (32k stars)
- Vault notes tagged `#policy` become active review agents
- When agent processes a document, it checks against all active policies
- Example: "Writing Style" policy applied when reviewing drafts
- Inline suggestions (green additions, red removals) in note editor

**Task F4.5: Observation Citations**
- Source: claude-mem
- When agent recalls a past memory, it cites `[memory:abc123]`
- UI renders as tappable link back to source note in vault
- Builds trust: user can verify what the agent "remembers"

### Sprint F5: Infrastructure (supports all above)

**Task F5.1: Add SwiftPM Dependencies**
- `mlx-swift-structured` — XGrammar constrained decoding (flips isFullyConstraining to true)
- `AXorcist` — Fuzzy AX queries (replaces raw AXUIElement code)
- `modelcontextprotocol/swift-sdk` — Official MCP client + server
- Verify all three build with current Xcode target

**Task F5.2: Port Hermes Security Patterns to Rust**
- File: `agent_core/src/security.rs`
- 75+ skill-scanning regex patterns from `hermes-agent/tools/skills_guard.py`
- Credential redaction patterns from `hermes-agent/agent/redact.py`
- 4-scope approval model (once/session/always/deny) from `hermes-agent/tools/approval.py`
- Dangerous command patterns for the bash tool

**Task F5.3: Prompt Caching Breakpoints**
- File: modify `agent_core/src/providers/claude.rs`
- Place `cache_control` on system prompt + last 3 messages
- ~85% reduction in Anthropic input token costs
- 20-line change in the request builder

**Task F5.4: 4-Phase Context Compression**
- File: modify `agent_core/src/providers/claude.rs` `compact()` method
- Phase 1: Protect head N + tail N messages (boundary preservation)
- Phase 2: Replace old tool results with `[tool_result placeholder]`
- Phase 3: Structured summary (Goal/Progress/Decisions/Files/NextSteps)
- Phase 4: Fold previous summaries into new ones (iterative)
- Sanitize orphaned tool-call/result pairs

---

## Verification Checklist (run after each sprint)

```bash
echo "=== Feature Sprint Verification ==="

# Rust builds
cargo test --manifest-path agent_core/Cargo.toml
cargo test --manifest-path omega-mcp/Cargo.toml
cargo test --manifest-path omega-ax/Cargo.toml

# Swift build
xcodebuild -quiet -project Epistemos.xcodeproj -scheme Epistemos \
  -destination 'platform=macOS' build

# Focused tests
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos \
  -destination 'platform=macOS' test-without-building \
  -only-testing:EpistemosTests/HermesPromptBuilderTests \
  -only-testing:EpistemosTests/LocalAgentLoopTests \
  -only-testing:EpistemosTests/ConfidenceRouterTests

# Hermes subprocess health (if Task 2 done)
python3 -c "import hermes_cli; print('Hermes importable')" 2>/dev/null

# MCP connectivity (if Task 3 done)
echo '{"jsonrpc":"2.0","method":"initialize","id":1}' | \
  python3 -m hermes_cli.main --mcp 2>/dev/null | head -1
```
