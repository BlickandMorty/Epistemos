# Agent Fusion Research Prompt
## Engineering the Optimal Agent Runtime from 8 Open-Source Projects

**Purpose:** Deep research to engineer the most optimized, highest-performance fusion of the best patterns from Hermes Agent, GoClaw, Phantom, OpenSwarm, Claw Code, CodeNano, OpenClaw, and Hermes IDE — integrated into the Epistemos Swift 6 + Rust + Metal stack.

**Paste this into a deep research session (Perplexity, Claude, Gemini Deep Research, etc.)**

---

## CONTEXT: What Epistemos Already Has

Epistemos is a macOS-native PKM + AI agent app. Swift 6 + Rust (UniFFI FFI) + Metal compute shaders. 137K lines Swift, 94K lines Rust. The agent system currently uses a forked NousResearch Hermes Agent (Python subprocess) communicating via MCP over stdin/stdout.

### Files to Read (the current agent system — 20 files)

**Swift Agent Layer:**
1. `Epistemos/Agent/HermesSubprocessManager.swift` — subprocess lifecycle, auth detection, keychain→env mapping, HermesRuntimeRoute resolution
2. `Epistemos/Agent/HermesMCPClient.swift` — MCP JSON-RPC client with timeout, continuation safety, cancelAll
3. `Epistemos/Agent/EpistemosMCPServer.swift` — MCP server exposing Epistemos tools TO Hermes
4. `Epistemos/Agent/HermesSetupService.swift` — Python venv creation, dependency install, health check

**Swift Orchestration Layer:**
5. `Epistemos/ViewModels/AgentViewModel.swift` — agent UI state, harness integration, cost tracking, tool loop detection, credential redaction, transcript repair
6. `Epistemos/Omega/Orchestrator/OrchestratorState.swift` — execution checkpoints, depth limiter, context budget, tool loop detector
7. `Epistemos/Omega/Orchestrator/FallbackChainResolver.swift` — current fallback logic
8. `Epistemos/Omega/MCPBridge.swift` — built-in tool registry from Rust catalog
9. `Epistemos/Bridge/StreamingDelegate.swift` — token streaming from agent to UI

**Swift Harness Layer (Meta-Harness production runtime):**
10. `Epistemos/Harness/HarnessIntegration.swift` — wires bootstrap, traces, progress, completion into agent flow
11. `Epistemos/Harness/BootstrapPacketBuilder.swift` — environment snapshot injected at session start
12. `Epistemos/Harness/TraceCollector.swift` — JSONL trace logging
13. `Epistemos/Harness/CompletionChecker.swift` — multi-perspective task verification
14. `Epistemos/Harness/HarnessPromptBuilder.swift` — initializer vs continuation prompt split

**Rust Agent Core:**
15. `agent_core/src/bridge.rs` — FFI truth boundary, ffi_guard macros, panic=unwind
16. `agent_core/src/agent_loop.rs` — Rust-side agent loop logic

**Python (Hermes subprocess):**
17. `hermes-agent/epistemos_bridge.py` — bridge between Epistemos and Hermes internals
18. `hermes-agent/tools/registry.py` — tool discovery with check_fn gating
19. `hermes-agent/run_agent.py` — Hermes entry point

**Triage & Inference:**
20. `Epistemos/Engine/TriageService.swift` — routes queries between Apple Intelligence, cloud, and local MLX

---

## THE 8 OPEN-SOURCE PROJECTS TO ANALYZE

For each project, analyze its architecture, identify its strongest patterns, and evaluate how those patterns could be integrated into Epistemos's Swift/Rust/Metal stack.

### 1. Hermes Agent v0.6.0 (Python) — Current Backend
- Repo: https://github.com/NousResearch/hermes-agent
- Key: Profiles (multi-instance isolation), MCP server mode, ordered fallback provider chains, Docker support, Firecrawl/Exa web backends, skills system, cron scheduling, hardening (risky command detection, path guards, secret redaction)
- **Question:** Which v0.6.0 features are missing from our fork? How to merge them cleanly?

### 2. GoClaw (Go) — High-Performance Alternative
- Repo: https://github.com/nextlevelbuilder/goclaw
- Key: Single 25MB binary (vs Python venv). 35MB RAM idle. Multi-tenant PostgreSQL. Agent teams with shared task boards. Inter-agent delegation. 5-layer security. 40+ tools. GoClaw Lite (SQLite desktop edition).
- **Question:** Could GoClaw Lite replace the Python Hermes subprocess? What would the migration path look like? How does Go's concurrency model compare to Python's asyncio for tool execution?

### 3. Phantom (TypeScript/Docker) — Self-Evolution Patterns
- Repo: https://github.com/ghostwright/phantom
- Key: Agent rewrites its own config after each session (LLM-judge validated). Three-tier vector memory. Dynamic MCP tool creation at runtime. Encrypted credential store.
- **Question:** How to implement self-evolution in Rust/Swift without the Docker overhead? Can the Living Vault's optimization loop serve the same purpose?

### 4. OpenSwarm (TypeScript) — Multi-Agent Orchestration
- Repo: https://github.com/unohee/OpenSwarm
- Key: Worker/Reviewer pair pipelines. Inter-agent message bus. Code knowledge graph for conflict detection. LanceDB vector memory with hybrid retrieval. Dynamic task scheduling with pace control.
- **Question:** How to implement Worker/Reviewer pairs using Hermes profiles? Can the inter-agent message bus be implemented over MCP?

### 5. Claw Code (Rust) — Rust Harness Engineering
- Repo: https://github.com/raks0078/-claw-code
- Key: Clean-room Rust reimplementation of Claude Code's harness. Tool/command metadata system. Task management. Parity auditing. 89.6% Rust.
- **Question:** What Rust harness patterns are better than our current agent_core? Can their tool metadata system replace or improve our MCP tool registry?

### 6. CodeNano (TypeScript) — Minimal Coding Agent
- Repo: https://github.com/Adamlixi/codenano
- Key: 6,500 lines extracted from Claude Code's 150K+. 17 built-in tools. Multi-turn with session persistence. Cross-session memory. Auto-compacting. Token budgeting. MIT license.
- **Question:** What is the minimal tool set for a coding agent? How do their 17 tools map to what Hermes already provides? What's missing?

### 7. OpenClaw (TypeScript/Node.js) — The Original
- Repo: https://github.com/opensouls/openclaw (or original source)
- Key: Gateway as control plane. Sub-agent concurrency (non-blocking spawn, maxConcurrent). Session lifecycle (daily reset, manual reset). DM pairing security. Doctor command.
- **Question:** Which OpenClaw patterns are missing from Hermes? How to implement the gateway-as-control-plane model in a native Mac app?

### 8. Hermes IDE (TypeScript/Rust/Tauri) — Terminal AI Patterns
- Repo: https://github.com/hermes-hq/hermes-ide
- Key: Ghost-text command suggestions. Project scanning (language/framework detection). Error pattern recognition. Cost tracking. Multi-session terminal.
- **Question:** What terminal/IDE AI patterns should Epistemos adopt for its Code section? (Study only — BSL 1.1 license prevents code reuse)

---

## RESEARCH OBJECTIVES

### A. Architecture Fusion Blueprint
Design a unified agent architecture that combines:
- Hermes's tool ecosystem and skills system (Python, mature)
- GoClaw's efficiency and single-binary deployment (Go, performant)
- Phantom's self-evolution and runtime tool creation
- OpenSwarm's Worker/Reviewer pipelines and inter-agent coordination
- Claw Code's Rust harness patterns
- CodeNano's minimal tool set clarity
- OpenClaw's control plane model and session lifecycle
- Hermes IDE's ghost-text and project awareness

All integrated into Epistemos's Swift 6 + Rust + Metal stack. The result must be:
- Zero-copy where possible (Apple Silicon UMA, shared memory, mmap)
- Lock-free on hot paths (atomic cursors, popcount breakers)
- Native macOS (NSPanel floating panels, Metal rendering, Keychain secrets)
- Local-first (all computation on-device, cloud opt-in)

### B. Gap Analysis Matrix
Create a capability matrix:

| Capability | Hermes | GoClaw | Phantom | OpenSwarm | Claw Code | CodeNano | OpenClaw | Epistemos (current) | Epistemos (target) |
|---|---|---|---|---|---|---|---|---|---|

Capabilities to evaluate:
- Multi-instance agent profiles
- Sub-agent delegation (sync + async)
- Inter-agent message bus
- Worker/Reviewer verification pipelines
- Self-evolving configuration
- Runtime MCP tool creation
- Session lifecycle (create/reset/compact/expire)
- Fallback provider chains with auto-failover
- Web scraping (Firecrawl/Exa/DuckDuckGo)
- Coding agent tools (file read/write/edit, bash, grep, glob)
- Terminal management (multi-session, split pane)
- Ghost-text / command prediction
- Cost tracking and budget enforcement
- Credential redaction
- Tool loop detection
- Context window management and compaction
- Cross-session memory (vector + structured)
- Cron/scheduled automation
- Channel adapters (iMessage, Telegram, Slack, email)
- Security (sandbox, path guards, risky command detection, DM pairing)
- Docker/container support
- Single-binary deployment

### C. Performance Engineering Recommendations
For each adopted pattern, provide:
1. **Why it matters** for a native Mac app on Apple Silicon
2. **Zero-copy implementation path** (avoid serialization, use shared memory/mmap)
3. **Concurrency model** (Swift structured concurrency vs Rust tokio vs Go goroutines)
4. **Memory budget** on 18GB M2 Pro (what fits, what doesn't)
5. **Benchmark targets** (latency, throughput, memory)

### D. Migration Strategy
If recommending GoClaw Lite as a Hermes companion or replacement:
1. What's the FFI path? (Go → C → Swift, or Go binary over stdin/stdout like Hermes?)
2. What Hermes features would be lost?
3. What GoClaw features would be gained?
4. Can both run simultaneously (Hermes for skills/memory, GoClaw for multi-agent)?
5. Timeline estimate for the migration

### E. The Optimal 17-Tool Coding Agent
Based on CodeNano's minimal set and Hermes's full registry:
1. What are the essential tools for a coding agent in a PKM context?
2. Map each tool to: Rust implementation (agent_core), Python (Hermes), or MCP (omega-mcp)
3. Which tools should be zero-copy (file read → mmap, not String)?
4. Which tools need sandbox isolation?

### F. Self-Evolution Architecture
Based on Phantom's approach + Living Vault:
1. How should the agent rewrite its own vault after each session?
2. What validation gates prevent bad self-edits? (Phantom uses LLM judges)
3. How does this map to the Living Vault's diff engine + memory classifier?
4. What's the rollback mechanism? (git revert on the vault)

### G. Inter-Agent Communication
Based on OpenSwarm + GoClaw:
1. MCP as the message bus? (Hermes already speaks MCP)
2. Shared task board in SQLite vs in-memory?
3. Worker/Reviewer pairs: same model or different models?
4. Concurrency limits and resource isolation between agents
5. How to visualize agent communication in the graph (pulsing nodes, particle trails)

---

## OUTPUT FORMAT

1. **Executive summary** (1 page): the recommended fusion architecture in plain English
2. **Capability matrix** (table): every capability across all 8 projects + Epistemos current + target
3. **Top 10 patterns to adopt** (ranked by impact/effort ratio)
4. **Top 5 patterns to skip** (and why — overengineering risk)
5. **Implementation roadmap** (phased, with file paths and estimated LOC per phase)
6. **Performance budget** (memory, latency, throughput targets per component)
7. **Risk register** (what could go wrong, mitigation for each)

---

## CONSTRAINTS

- The result MUST run on macOS with Swift 6 + Rust + Metal. No Electron. No Node.js in production.
- The result MUST be local-first. All agent computation on-device. Cloud is opt-in for inference only.
- The result MUST maintain the existing Hermes integration (don't break what works) while adding new capabilities.
- Zero-copy, lock-free, cache-aligned where it matters. This is Apple Silicon — use the hardware.
- API keys in macOS Keychain, never UserDefaults. OAuth tokens treated as bearer tokens.
- The agent runtime must feel instant — tool execution <100ms, session start <500ms, context switch <50ms.
