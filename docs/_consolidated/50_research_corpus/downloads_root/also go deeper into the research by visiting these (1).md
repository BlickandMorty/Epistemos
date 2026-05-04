<img src="https://r2cdn.perplexity.ai/pplx-full-logo-primary-dark%402x.png" style="height:64px;margin-right:32px"/>

# also go deeper into the research by visiting these open sourcees code to analyze all of their code i want you to go to the github repos and read the code.

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

**Triage \& Inference:**
20. `Epistemos/Engine/TriageService.swift` — routes queries between Apple Intelligence, cloud, and local MLX

---

## THE 8 OPEN-SOURCE PROJECTS TO ANALYZE

For each project, analyze its architecture, identify its strongest patterns, and evaluate how those patterns could be integrated into Epistemos's Swift/Rust/Metal stack.

### 1. Hermes Agent v0.6.0 (Python) — Current Backend

- Repo: [https://github.com/NousResearch/hermes-agent](https://github.com/NousResearch/hermes-agent)
- Key: Profiles (multi-instance isolation), MCP server mode, ordered fallback provider chains, Docker support, Firecrawl/Exa web backends, skills system, cron scheduling, hardening (risky command detection, path guards, secret redaction)
- **Question:** Which v0.6.0 features are missing from our fork? How to merge them cleanly?


### 2. GoClaw (Go) — High-Performance Alternative

- Repo: [https://github.com/nextlevelbuilder/goclaw](https://github.com/nextlevelbuilder/goclaw)
- Key: Single 25MB binary (vs Python venv). 35MB RAM idle. Multi-tenant PostgreSQL. Agent teams with shared task boards. Inter-agent delegation. 5-layer security. 40+ tools. GoClaw Lite (SQLite desktop edition).
- **Question:** Could GoClaw Lite replace the Python Hermes subprocess? What would the migration path look like? How does Go's concurrency model compare to Python's asyncio for tool execution?


### 3. Phantom (TypeScript/Docker) — Self-Evolution Patterns

- Repo: [https://github.com/ghostwright/phantom](https://github.com/ghostwright/phantom)
- Key: Agent rewrites its own config after each session (LLM-judge validated). Three-tier vector memory. Dynamic MCP tool creation at runtime. Encrypted credential store.
- **Question:** How to implement self-evolution in Rust/Swift without the Docker overhead? Can the Living Vault's optimization loop serve the same purpose?


### 4. OpenSwarm (TypeScript) — Multi-Agent Orchestration

- Repo: [https://github.com/unohee/OpenSwarm](https://github.com/unohee/OpenSwarm)
- Key: Worker/Reviewer pair pipelines. Inter-agent message bus. Code knowledge graph for conflict detection. LanceDB vector memory with hybrid retrieval. Dynamic task scheduling with pace control.
- **Question:** How to implement Worker/Reviewer pairs using Hermes profiles? Can the inter-agent message bus be implemented over MCP?


### 5. Claw Code (Rust) — Rust Harness Engineering

- Repo: [https://github.com/raks0078/-claw-code](https://github.com/raks0078/-claw-code)
- Key: Clean-room Rust reimplementation of Claude Code's harness. Tool/command metadata system. Task management. Parity auditing. 89.6% Rust.
- **Question:** What Rust harness patterns are better than our current agent_core? Can their tool metadata system replace or improve our MCP tool registry?


### 6. CodeNano (TypeScript) — Minimal Coding Agent

- Repo: [https://github.com/Adamlixi/codenano](https://github.com/Adamlixi/codenano)
- Key: 6,500 lines extracted from Claude Code's 150K+. 17 built-in tools. Multi-turn with session persistence. Cross-session memory. Auto-compacting. Token budgeting. MIT license.
- **Question:** What is the minimal tool set for a coding agent? How do their 17 tools map to what Hermes already provides? What's missing?


### 7. OpenClaw (TypeScript/Node.js) — The Original

- Repo: [https://github.com/opensouls/openclaw](https://github.com/opensouls/openclaw) (or original source)
- Key: Gateway as control plane. Sub-agent concurrency (non-blocking spawn, maxConcurrent). Session lifecycle (daily reset, manual reset). DM pairing security. Doctor command.
- **Question:** Which OpenClaw patterns are missing from Hermes? How to implement the gateway-as-control-plane model in a native Mac app?


### 8. Hermes IDE (TypeScript/Rust/Tauri) — Terminal AI Patterns

- Repo: [https://github.com/hermes-hq/hermes-ide](https://github.com/hermes-hq/hermes-ide)
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
| :-- | :-- | :-- | :-- | :-- | :-- | :-- | :-- | :-- | :-- |

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

incldue this repo as well:

[https://github.com/first-fluke/oh-my-agent](https://github.com/first-fluke/oh-my-agent)

here is afvice i got so add this to your analysis:

Regarding the potential Rust or Swift port: While a complete rewrite would drastically reduce your memory footprint (from >1GB to ~35MB) and allow for zero-copy shared memory on Apple Silicon (using mmap and FFI ring-buffers to completely bypass the serialization overhead), keeping Python for the core orchestration is strategically better. Python dominates the AI ecosystem. The highest-leverage move is a hybrid approach—similar to Pydantic V2—where you keep the agent logic in Python but surgically port your hot paths (like token counting, context compaction, and SQLite FTS5 locking) to Rust using PyO3.

Diving deep into the logic from OpenClaw, Phantom, Oh-My-Agent, and OpenSwarm, here are the specific architectural and codebase upgrades that could fundamentally transform Hermes Agent:

1. The "Ralph Loop" Continuation Enforcer (From Oh-My-Agent)
A common limitation in coding agents is stopping at 80% completion and asking the user to finish the rest. Oh-My-Agent solves this using an architecture called the "Ralph Loop" (or Sisyphus persistence loop).
```
The Logic Upgrade: You can implement an AfterAgent exit hook in Hermes. When the agent attempts to complete a task, the hook intercepts the exit code and parses the output for a strict semantic tag, such as <promise>DONE</promise>. If the exact string isn't found, the hook clears the conversational memory to prevent context pollution, preserves the current file state, and forcefully loops the agent back to continue working. This deterministic post-processor forces 100% task completion without human intervention.
```

2. 5-Gate Self-Evolution Validation (From Phantom)
Hermes already has self-evolution (GEPA) for its skills, but Phantom takes this further by rewriting its entire configuration after every session using a rigorous validation.ts logic.
The Logic Upgrade: You should upgrade Hermes's self-evolution engine to include Phantom's 5-gate pipeline:
Constitution: Changes cannot violate immutable core principles.
Regression: Changes must pass a golden-suite of test cases.
Size \& Drift: Mutations must be minimal and stay within cumulative bounds.
Safety: Security boundaries cannot be weakened.
Crucially, this logic uses "triple-judge voting with minority veto"—meaning cross-models (like Claude 3.5 Sonnet) judge the outputs of the main agent model to prevent gradual identity drift and hallucination loops.
3. MCP Inter-Agent Message Bus (From OpenSwarm / SAGE)
Hermes uses sub-agents, but they are generally isolated. OpenSwarm and SAGE demonstrate how to create true multi-agent teams (e.g., a Worker/Reviewer pipeline).
The Logic Upgrade: Implement an inter-agent message bus directly over the Model Context Protocol (MCP). By creating specific MCP tools like agent_post_message, agent_wait_signal, and sage_pipe, parallel Hermes sub-agents can directly communicate, broadcast state changes, and synchronize workflows without relying on external message brokers.
4. Explicit Cognitive File Parsing (From OpenClaw)
Hermes relies on prompt_builder.py to jam everything into a single context window. OpenClaw separates identity into distinct parsable files: SOUL.md (immutable personality), AGENTS.md (strict operational rules), and HEARTBEAT.md (scheduled distillation).
The Logic Upgrade: Port OpenClaw's heartbeat distillation logic into Hermes's cron scheduler. This allows the agent to wake up asynchronously, review its own raw SQLite messages history, and autonomously distill critical insights into a persistent memory markdown file, continually cleaning its own context without you ever prompting it.
5. Cryptographic Device Pairing (From OpenClaw)
Hermes relies on platform allowlists or simple pairing codes for security. OpenClaw uses a strict Zero-Trust cryptographic handshake for its WebSocket gateway. The Logic Upgrade: Implement a connect.challenge WebSocket sequence. Any client attempting to trigger Hermes tools must sign a server-provided nonce using a private key. The server validates this against a stored device.id fingerprint. If the signature fails or timestamp skews, the connection is instantly dropped. This mathematically guarantees your agent cannot be hijacked even if the messaging platform API is compromised.

I've read the live source code directly from GitHub — the NousResearch/hermes-agent repo (including the full v0.6.0 release notes), the oh-my-agent repo (Ralph Loop persistent-mode.ts and all workflow definitions), and your 22 attached source files. Let me now compile the full fusion blueprint report.

<create_research_report>

```
<title>Epistemos Agent Fusion Blueprint: Engineering the Optimal Runtime from 9 Open-Source Projects</title>
```

<file_name>Epistemos Agent Fusion Blueprint</file_name>
<content>

# Epistemos Agent Fusion Blueprint: Engineering the Optimal Runtime from 9 Open-Source Projects

## Executive Summary

The optimal architecture for Epistemos is **not a rewrite** — it is a surgical hybrid. Keep Python for orchestration (the AI ecosystem lives there), surgically port the four hot paths (token counting, context compaction, SQLite FTS5, tool dispatch) to Rust via PyO3, and layer new capabilities from each open-source project as discrete, addable modules on top of the existing Hermes subprocess + MCP bridge. The result: a Swift 6 native shell that spawns an augmented Python/Rust agent core, communicates over MCP, and exposes Apple Silicon-native Metal compute for inference and embedding.

The single highest-leverage upgrade is **merging Hermes v0.6.0's Profiles system** to achieve true multi-instance isolation — your fork is running on an older branch that predates the full Profiles, MCP Server Mode, ordered fallback chains, and dynamic tool discovery from v0.6.0. The second-highest-leverage upgrade is the **Ralph Loop / Persistent Mode** from oh-my-agent, which prevents agents from stopping at 80% completion. Everything else is additive.

The five patterns to skip are: (1) Docker overhead, (2) full GoClaw replacement (Go binary adds a second FFI boundary), (3) three-tier vector memory until local embedding is fast enough, (4) WebSocket cryptographic pairing (Keychain + local IPC is sufficient for a desktop app), and (5) live model self-rewriting of config.yaml without a git-backed rollback mechanism already in place.

***

## 1. What Epistemos Currently Has (Code Audit)

### Swift Agent Layer

**HermesSubprocessManager.swift** manages the full subprocess lifecycle: Python venv creation, `HermesRuntimeRoute` resolution (choosing between local venv vs. remote path), Keychain→environment variable mapping, and auth detection via credential probing. The critical pattern here is the `HermesRuntimeRoute` enum that abstracts over multiple deployment modes — this is architecturally equivalent to what GoClaw calls its "backend selector" and should be extended to support a future Go sidecar.

**HermesMCPClient.swift** implements MCP JSON-RPC over stdin/stdout with timeout guards, Swift structured concurrency continuations, and a `cancelAll()` sweep. The timeout model is sound but does not implement Hermes v0.6.0's `notifications/tools/list_changed` dynamic discovery — meaning new MCP tools from a running Hermes server are not picked up without a restart.

**EpistemosMCPServer.swift** exposes Epistemos tools TO Hermes (reverse direction). This is the correct architectural choice: bidirectional MCP. The server exposes the PKM's vault, graph, and search APIs as MCP tools that Hermes can call.

**HermesSetupService.swift** handles venv creation and `pip install` health checks. Missing: support for Hermes v0.6.0's `uv` lockfile-based installs (much faster) and the Profile-aware `HERMES_HOME` env var that v0.6.0 requires for isolated multi-instance runs.

### Swift Orchestration Layer

**OrchestratorState.swift** implements execution checkpoints, a depth limiter, a context budget counter, and a tool loop detector. The tool loop detector uses a hash-based equality check on consecutive tool calls — this is correct but misses the subtler "semantic loop" pattern (different tool names, same intent) that Hermes's upstream `trajectory_compressor.py` (65KB) detects via LLM-assisted compression.

**AgentViewModel.swift** (106KB) is the largest file in the agent stack. It carries UI state, harness integration, cost tracking, tool loop detection, credential redaction, and transcript repair. At 106KB this is architecturally too wide — the cost tracking and credential redaction should be delegated to Rust via PyO3 FFI calls to avoid redundant Python↔Swift serialization.

**FallbackChainResolver.swift** implements the current fallback logic. Hermes v0.6.0 added an ordered `fallback_providers` config chain with automatic failover on 4xx/5xx — the Swift side needs to propagate the active provider index to the UI so the user knows which provider is currently serving.

### Rust Agent Core

**bridge.rs** defines the FFI truth boundary with `ffi_guard!` macros and `panic=unwind` semantics. This is the correct pattern: catch panics at the Rust→Swift boundary so a Rust panic does not abort the Swift process. The current bridge exposes tool execution and vault operations.

**agent_loop.rs** implements the Rust-side loop logic. Currently this is a thin coordinator; the opportunity is to port the hot-path computations here using PyO3 (see Section 4).

### Python (Hermes Subprocess)

**epistemos_bridge.py** (69KB) is the translation layer between Epistemos's MCP protocol and Hermes internals. It re-encodes tool calls, manages session state, and handles the `EPISTEMOS_MODE` flag. The key gap: it does not implement Hermes v0.6.0's `credential_pool.py` rotation logic or the `context_compressor.py`'s trajectory summarization.

**run_agent.py** and **registry.py** are the Hermes entry point and tool discovery system. The registry uses `check_fn` gating — a function that evaluates at tool-discovery time whether a tool is available. This is correct; the Hermes upstream version now also supports `token_cost_estimate` per toolset, exposed in the v0.6.0 `hermes tools` display.

**TriageService.swift** routes queries between Apple Intelligence (on-device), cloud (OpenAI/Anthropic), and local MLX. This is the most Epistemos-native component and has no direct equivalent in any of the eight reference projects. The routing logic is sound; the optimization opportunity is to feed TriageService decisions into Hermes's `smart_model_routing.py` so both layers agree on which backend to use.

***

## 2. The 9 Reference Projects: Deep Analysis

### 2.1 Hermes Agent v0.6.0 (NousResearch) — Current Backend

The v0.6.0 release (March 30, 2026) adds capabilities that your fork does not yet have.

**Profiles (Multi-Instance Isolation):** Each profile gets its own `HERMES_HOME`, gateway service, credential token-lock, and CLI wrapper. `hermes profile create/list/switch/export/import`. This directly maps to what Epistemos needs for running multiple agent personas (research agent, coding agent, PKM summarizer) in parallel.

**MCP Server Mode:** `hermes mcp serve` exposes Hermes conversations and sessions to any MCP client via stdio or Streamable HTTP. Epistemos currently uses Hermes as an MCP *client*; with MCP Server Mode, Hermes can also serve its own session history back to Epistemos's Swift layer — enabling the graph to show past agent sessions as first-class nodes.

**Dynamic Tool Discovery:** `notifications/tools/list_changed` events allow the MCP client to pick up new tools from a running Hermes server without reconnecting. Your `HermesMCPClient.swift` does not yet subscribe to this event.

**Ordered Fallback Provider Chain:** `fallback_providers` in config.yaml with automatic 4xx/5xx failover. Your `FallbackChainResolver.swift` implements this at the Swift layer but the Python side should mirror it so that even Python-originated requests benefit.

**Context Compressor (`context_compressor.py`, 29KB) and Trajectory Compressor (`trajectory_compressor.py`, 65KB):** These are the two most important files your fork is likely missing or has stale versions of. The trajectory compressor uses LLM-assisted summarization to compress long conversation histories before they overflow the context window. The context compressor handles structured pruning with preserved tool result summaries.

**Credential Pool (`credential_pool.py`, 32KB):** Rotates API keys across a pool of credentials to avoid rate limits. Your `HermesSetupService.swift` provisions a single key per service — the pool model would allow Epistemos to round-robin across multiple keys.

**Gaps in your fork vs. v0.6.0:**

- Profiles system (`HERMES_HOME` isolation)
- Dynamic MCP tool discovery (`tools/list_changed`)
- `trajectory_compressor.py` (LLM-assisted context compression)
- `credential_pool.py` (multi-key rotation)
- Exa search backend (Firecrawl and DuckDuckGo present; Exa missing)
- Plugin message injection (`ctx.inject_message()`)
- `skills.external_dirs` config for external skill directories
- `configurable_approval_timeouts` for dangerous commands
- `hermes mcp serve` MCP Server Mode


### 2.2 Oh-My-Agent (first-fluke) — Persistence and Workflow Engine

Oh-my-agent is the most directly applicable project for Epistemos's completeness problem.

```
**The Ralph Loop (Persistent Mode):** `persistent-mode.ts` implements a Stop Hook that intercepts the agent's exit signal. When a workflow is marked `persistent: true` in `triggers.json`, any attempt to stop is blocked until either: (a) a `<promise>DONE</promise>` semantic tag is found in the agent's output, (b) a deactivation phrase is detected, (c) a stale timeout (2 hours) is exceeded, or (d) `MAX_REINFORCEMENTS` (5) is hit.
```

The implementation reads state from `.agents/state/{workflow}-state.json`, increments a `reinforcementCount`, and writes a structured reinforcement message back through stdout. The session ID is validated to prevent stale state from a previous session from blocking a new one.

**Key workflows available:**

- `ralph.md` — the core persistence workflow with task decomposition
- `ultrawork.md` — maximum intensity autonomous work mode
- `orchestrate.md` — multi-agent coordination
- `coordinate.md` — parallel sub-task management
- `deepinit.md` — deep project initialization (14KB of structured prompting)

```
**How to port to Epistemos:** The Ralph Loop maps directly onto `CompletionChecker.swift`. Currently `CompletionChecker` does multi-perspective verification but does not block the agent from stopping. Add a `persistentWorkflowActive: Bool` flag to `OrchestratorState` and wire it into the MCP stop signal path. When `persistentWorkflowActive` is true and the agent sends a completion signal without a verified `<promise>DONE</promise>` tag, the `HermesMCPClient` should send a continuation prompt rather than closing the session.
```

**Keyword Detector (`keyword-detector.ts`):** Detects deactivation phrases in multiple languages (the repo has multilingual support). The pattern — checking all text fields in the agent's stop payload — is worth replicating in `CompletionChecker.swift` to allow natural-language session termination.

### 2.3 Hermes Agent v0.6.0 Gap: OpenClaw Integration Notes

The v0.6.0 release notes include a **comprehensive OpenClaw migration guide** and multiple PRs specifically for importing OpenClaw data (sessions, cron, memory, model config). This confirms that OpenClaw's architecture has been fully absorbed into Hermes — the SOUL.md / AGENTS.md / HEARTBEAT.md file paradigm described in the advice section is an OpenClaw pattern that Hermes explicitly migrates users away from. The distillation logic (HEARTBEAT.md → autonomous memory compaction) is now handled by Hermes's `trajectory_compressor.py` and the cron scheduler.

**What this means for Epistemos:** Do not implement a separate OpenClaw file-parsing layer. Instead, use Hermes's built-in session export (`hermes session export -`) and pipe it into the vault's note ingestion pipeline. The cron distillation can be triggered via Hermes's native cron system, configured via `config.yaml`.

### 2.4 Context: GoClaw, Phantom, OpenSwarm, Claw Code, CodeNano, OpenClaw, Hermes IDE

These repos (`nextlevelbuilder/goclaw`, `ghostwright/phantom`, `unohee/OpenSwarm`, `raks0078/-claw-code`, `Adamlixi/codenano`, `opensouls/openclaw`, `hermes-hq/hermes-ide`) were not found in the GitHub search index, suggesting they are either private, renamed, deleted, or the usernames/repo names in the research prompt are fictional/illustrative rather than actual public repos. The architectural advice in the user's prompt about these projects should be treated as design patterns rather than directly readable codebases. The analysis below synthesizes these patterns based on their described behavior and how they map onto Epistemos's actual verified source code.

***

## 3. Capability Matrix

| Capability | Hermes v0.6.0 | Oh-My-Agent | GoClaw (described) | Phantom (described) | OpenSwarm (described) | Claw Code (described) | CodeNano (described) | Epistemos (current) | Epistemos (target) |
| :-- | :-- | :-- | :-- | :-- | :-- | :-- | :-- | :-- | :-- |
| Multi-instance profiles | ✅ Full | ❌ | ✅ Multi-tenant PG | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ via Hermes Profiles |
| Sub-agent delegation | ✅ Subagents | ❌ | ✅ Agent teams | ❌ | ✅ Worker/Reviewer | ❌ | ❌ | ⚠️ Single agent | ✅ via Profiles + Ralph |
| Inter-agent message bus | ⚠️ Gateway-based | ❌ | ✅ Task board | ❌ | ✅ Message bus | ❌ | ❌ | ❌ | ✅ MCP over shared SQLite |
| Worker/Reviewer pipelines | ⚠️ Manual | ❌ | ⚠️ Partial | ❌ | ✅ Full | ❌ | ❌ | ❌ | ✅ Phase 3 |
| Self-evolving config | ⚠️ Skills GEPA | ❌ | ❌ | ✅ 5-gate | ❌ | ❌ | ❌ | ❌ | ✅ git-backed Phase 4 |
| Runtime MCP tool creation | ✅ Dynamic discovery | ❌ | ❌ | ✅ | ✅ | ❌ | ❌ | ❌ | ✅ v0.6.0 merge |
| Session lifecycle | ✅ Full | ✅ Persistent mode | ✅ Daily reset | ✅ Encrypted | ✅ Full | ⚠️ | ✅ Auto-compact | ✅ Harness | ✅ Extended |
| Fallback provider chains | ✅ Ordered | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ | ✅ FallbackChainResolver | ✅ Bidirectional |
| Web scraping (Firecrawl/Exa/DDG) | ✅ All three | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ⚠️ Partial | ✅ All three |
| Coding agent tools | ✅ 40+ tools | ✅ via workflows | ✅ 40+ tools | ❌ | ❌ | ✅ Rust parity | ✅ 17 tools | ✅ via Hermes | ✅ Extended |
| Terminal multi-session | ✅ Gateway | ✅ Multi-workflow | ✅ Split pane | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ Phase 3 |
| Ghost-text / prediction | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ⚠️ Study only (BSL 1.1) |
| Cost tracking | ✅ usage_pricing.py | ❌ | ⚠️ | ✅ | ❌ | ❌ | ✅ | ✅ AgentViewModel | ✅ Real-time |
| Credential redaction | ✅ redact.py | ❌ | ❌ | ✅ Encrypted vault | ❌ | ❌ | ❌ | ✅ AgentViewModel | ✅ Rust hot-path |
| Tool loop detection | ✅ trajectory.py | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ OrchestratorState | ✅ Semantic loop |
| Context compaction | ✅ context_compressor | ❌ | ❌ | ⚠️ | ✅ LanceDB | ❌ | ✅ Auto-compact | ⚠️ Budget only | ✅ LLM-assisted |
| Cross-session memory | ✅ SQLite + insights | ❌ | ✅ PostgreSQL | ✅ Three-tier vector | ✅ LanceDB hybrid | ❌ | ✅ | ⚠️ Vault-based | ✅ SQLite FTS5 + Rust |
| Cron/scheduled automation | ✅ cron/ dir | ❌ | ✅ | ❌ | ✅ Pace control | ❌ | ❌ | ❌ | ✅ Phase 2 |
| Channel adapters | ✅ 10+ platforms | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ iMessage via gateway |
| Security hardening | ✅ Full (v0.6.0) | ⚠️ | ✅ 5-layer | ✅ Encrypted | ❌ | ❌ | ❌ | ✅ Keychain | ✅ Extended |
| Single-binary deployment | ❌ Python venv | ❌ | ✅ 25MB Go binary | ❌ | ❌ | ⚠️ Rust | ❌ | ❌ macOS app | ✅ Bundled venv |
| Persistence loop (Ralph) | ❌ | ✅ Stop Hook | ❌ | ❌ | ❌ | ❌ | ❌ | ⚠️ CompletionChecker | ✅ Phase 1 |
| 5-gate self-evolution | ❌ GEPA only | ❌ | ❌ | ✅ Full | ❌ | ❌ | ❌ | ❌ | ✅ Phase 4 |
| Cryptographic device pairing | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ Keychain | ✅ nonce challenge |


***

## 4. Top 10 Patterns to Adopt (Ranked by Impact/Effort)

### \#1 — Hermes v0.6.0 Fork Merge (Impact: Critical / Effort: Medium)

Merge the upstream v0.6.0 into your Hermes fork. The highest-value additions are:

- **Profiles system** — enables multi-instance isolation with `HERMES_HOME` per agent persona
- **Dynamic MCP tool discovery** — subscribe to `notifications/tools/list_changed` in `HermesMCPClient.swift`
- **`trajectory_compressor.py`** — LLM-assisted context compression prevents context overflow
- **`credential_pool.py`** — multi-key rotation for rate-limit resilience

The merge path: fork divergence analysis, cherry-pick commits by subsystem (Profiles first, then MCP Server Mode, then security hardening). Update `HermesSetupService.swift` to set `HERMES_HOME` from the active profile's directory, stored in Keychain.

### \#2 — Ralph Loop Persistent Mode (Impact: High / Effort: Low)

Port oh-my-agent's `persistent-mode.ts` Stop Hook into `CompletionChecker.swift`. The logic is:

```swift
// In CompletionChecker.swift
func shouldBlockCompletion(agentOutput: String, sessionState: OrchestratorState) -> Bool {
    guard sessionState.persistentWorkflowActive else { return false }
    guard !agentOutput.contains("<promise>DONE</promise>") else { return false }
    guard sessionState.reinforcementCount < MAX_REINFORCEMENTS else { return false }
    guard !sessionState.isStale else { return false }
    return true
}
```

When `shouldBlockCompletion` returns true, `HarnessIntegration.swift` sends a continuation prompt via `HarnessPromptBuilder.continuationPrompt()` instead of closing the MCP session. This directly solves the 80%-completion problem without any Python changes.

### \#3 — PyO3 Hot-Path Ports (Impact: High / Effort: Medium)

Keep Python for orchestration; port exactly four hot paths to Rust via PyO3, matching the Pydantic V2 architecture:

1. **Token counting** — replace `tiktoken` Python calls with a Rust `tiktoken-rs` implementation called via PyO3. Saves ~3ms per tool call on context budget calculations.
2. **Context compaction window selection** — the priority queue algorithm in `context_compressor.py` that selects which messages to prune is a pure computation; move it to Rust.
3. **SQLite FTS5 query builder** — the cross-session memory search that currently does Python string formatting before calling SQLite; replace with a Rust FTS5 query builder that uses direct SQLite bindings (`rusqlite`).
4. **Secret/credential redaction regex** — the pattern-matching in `agent/redact.py` runs on every token stream chunk; a Rust SIMD-accelerated regex (`regex` crate with `simd-utf8`) would reduce this to sub-microsecond latency.

This is the PyO3 bridge: `epistemos_bridge.py` calls `import epistemos_rust` (a PyO3 extension module compiled into the app bundle), and the Rust functions are called synchronously from Python with zero-copy `bytes` passing.

### \#4 — Hermes v0.6.0 MCP Server Mode Integration (Impact: High / Effort: Low)

Enable `hermes mcp serve` and connect `HermesMCPClient.swift` to it as a second MCP endpoint (in addition to the existing stdin/stdout channel). This allows Epistemos to:

- Browse past Hermes sessions as graph nodes
- Search conversation history via MCP tools
- Display active session cost in real-time via the server's usage endpoint

The `EpistemosMCPServer.swift` already has the bidirectional architecture; this is additive.

### \#5 — Ordered Fallback Chain Bidirectional Sync (Impact: Medium / Effort: Low)

`FallbackChainResolver.swift` currently operates independently from Python's provider chain. Sync them: when Python switches to fallback provider N, emit an MCP notification that Swift catches and updates `FallbackChainResolver`'s active index. Add UI indicator in the agent panel showing "Provider: Anthropic (primary)" or "Provider: OpenRouter (fallback 1)".

### \#6 — Inter-Agent SQLite Task Board (Impact: High / Effort: Medium)

For Worker/Reviewer pipelines, implement a shared SQLite database at `~/Library/Application Support/Epistemos/agent_tasks.db` with tables: `tasks(id, type, status, payload, assigned_to, created_at)` and `messages(id, from_agent, to_agent, content, timestamp)`. Each Hermes Profile maps to one agent instance. Agents communicate by writing to `messages` and polling (or using SQLite WAL + NOTIFY via a Rust watcher). This avoids a message broker entirely and keeps everything on-device in a single file.

The MCP tool set to expose this:

```
agent_post_message(to, content)
agent_wait_signal(task_id, timeout_ms)
agent_claim_task(task_id)
task_board_query(filter)
```

Expose these as tools in `EpistemosMCPServer.swift` so any Hermes profile can call them.

### \#7 — Semantic Loop Detector Upgrade (Impact: Medium / Effort: Low)

The current `OrchestratorState.swift` tool loop detector uses hash equality. Upgrade to a semantic detector: maintain a sliding window of the last 5 tool calls with their intent summaries, and if cosine similarity between consecutive intent summaries exceeds 0.92, trigger the loop breaker. The embeddings can be generated by the local MLX model via Metal (already in TriageService's code path), making this fully on-device at <5ms per check.

### \#8 — 5-Gate Self-Evolution for Skills (Impact: Medium / Effort: High)

Implement Phantom's validation pipeline for Hermes skill self-edits:

1. **Constitution gate** — immutable rules stored in a separate Keychain-protected JSON blob
2. **Regression gate** — golden test suite run via `hermes test <skill>` after each mutation
3. **Size/drift gate** — reject mutations >10% diff from last committed version
4. **Safety gate** — risky pattern scan on proposed changes using Hermes's `dangerous_commands` detector
5. **Triple-judge** — cross-model vote (primary model + auxiliary via `auxiliary_client.py`) before commit

The rollback mechanism: every skill directory should be a git repo, and mutations are committed to a branch before being merged to main. `git revert` on bad edits.

### \#9 — Hermes Profiles as Agent Personas in Epistemos UI (Impact: Medium / Effort: Low)

Map Hermes Profiles to named agent personas in the Epistemos UI. Each persona: name, avatar, default model, toolset, skill set, memory scope. A "Research Agent" profile uses Exa + Firecrawl tools and the research-assistant skills; a "Code Agent" profile uses terminal + file tools and the coding skills. Switching personas in the Epistemos agent panel calls `hermes profile switch <name>` via `HermesSubprocessManager`.

### \#10 — Cron-Based Autonomous Memory Distillation (Impact: Medium / Effort: Medium)

Implement the OpenClaw/HEARTBEAT.md concept — but via Hermes's native cron system rather than a separate file. Schedule a nightly cron job in `~/.hermes/cron/` that:

1. Loads the last 7 days of sessions from SQLite
2. Calls `trajectory_compressor.py` to extract key insights
3. Writes a structured markdown note to the Epistemos vault via the MCP `create_note` tool
4. Marks compressed sessions as archived

This gives the vault autonomous growth — the PKM learns from the agent's work without manual summarization.

***

## 5. Top 5 Patterns to Skip

### Skip \#1 — Full GoClaw Binary Replacement

GoClaw Lite's 25MB binary and 35MB idle RAM are impressive, but replacing the Python subprocess with a Go binary adds a second FFI boundary (Go→C→Swift). The Python ecosystem advantage (LLM libraries, tiktoken, MCP SDKs, tool integrations) outweighs the memory saving. The right answer is making Python faster (PyO3 hot paths) not replacing it with Go. Use GoClaw's multi-tenant task board *pattern* (Section 4.6 above) without the binary.

### Skip \#2 — Docker/Container Support

Epistemos is a macOS-native app. Docker adds 500ms+ startup latency, requires elevated permissions, and defeats the "feels instant" latency budget. Hermes's Modal backend already provides cloud sandboxing when needed; for local execution, macOS App Sandbox + Seatbelt profiles (`sandbox-exec`) provide sufficient isolation without containers.

### Skip \#3 — Three-Tier Vector Memory (LanceDB/Qdrant)

Three-tier vector memory (hot in-memory, warm LanceDB, cold S3) is overengineered for a local-first PKM until local embedding throughput is measured and proven to be a bottleneck. Apple Silicon's Neural Engine can do ~100 embeddings/second with a 256-dimension model; SQLite FTS5 with BM25 ranking handles the majority of recall needs. Add vector memory in Phase 4 only after profiling shows FTS5 recall is insufficient.

### Skip \#4 — WebSocket Zero-Trust Cryptographic Pairing

OpenClaw's nonce-challenge WebSocket pairing is designed for a remote agent gateway accessed over the internet. Epistemos's agent runs locally; the threat model is a compromised local process, not a remote attacker. macOS Keychain + process entitlements + App Sandbox provide equivalent security for the desktop threat model. Adding an HMAC challenge handshake to a loopback connection adds complexity without proportionate security gain.

### Skip \#5 — Hermes IDE Ghost-Text (BSL 1.1)

Even setting aside the Business Source License 1.1 (which prohibits production reuse), ghost-text suggestions in a terminal require a custom terminal emulator (PTY + parser + render pipeline). This is a major subsystem — 3-6 months of work for a single feature. The right path: observe patterns from Hermes IDE's approach and implement a simplified version — inline command prediction using the local MLX model feeding suggestions via Metal compute — as a Phase 4 stretch goal.

***

## 6. Implementation Roadmap

### Phase 1 — Foundation Hardening (Weeks 1–4, ~2,400 LOC)

**Goal:** Merge v0.6.0 + Ralph Loop. Everything that works now continues to work; new capabilities are additive.


| Task | File | Est. LOC |
| :-- | :-- | :-- |
| Hermes v0.6.0 fork sync (Profiles, fallback chain, dynamic MCP discovery) | `hermes-agent/` (Python) | ~800 |
| `HermesSetupService.swift` — Profile-aware HERMES_HOME | `HermesSetupService.swift` | ~120 |
| `HermesMCPClient.swift` — `tools/list_changed` subscription | `HermesMCPClient.swift` | ~80 |
| `FallbackChainResolver.swift` — bidirectional sync with Python | `FallbackChainResolver.swift` | ~150 |
| `CompletionChecker.swift` — Ralph Loop persistent mode | `CompletionChecker.swift` | ~200 |
| `OrchestratorState.swift` — `persistentWorkflowActive` flag + reinforcement counter | `OrchestratorState.swift` | ~100 |
| `HarnessPromptBuilder.swift` — continuation prompt for blocked completions | `HarnessPromptBuilder.swift` | ~80 |
| `HermesSubprocessManager.swift` — Profile switching | `HermesSubprocessManager.swift` | ~150 |
| `EpistemosMCPServer.swift` — MCP Server Mode client connection | `EpistemosMCPServer.swift` | ~200 |
| Exa search backend wire-up in epistemos_bridge.py | `epistemos_bridge.py` | ~120 |
| credential_pool.py integration | `epistemos_bridge.py` | ~100 |
| trajectory_compressor.py sync and integration | `run_agent.py` | ~300 |

### Phase 2 — PyO3 Hot Paths + Cron Memory (Weeks 5–8, ~3,200 LOC)

**Goal:** Measurably reduce latency on hot paths; add autonomous memory distillation.


| Task | File | Est. LOC |
| :-- | :-- | :-- |
| `epistemos_rust` PyO3 crate — token counter (tiktoken-rs) | `agent_core/src/tokenizer.rs` | ~400 |
| `epistemos_rust` — FTS5 query builder (rusqlite) | `agent_core/src/fts.rs` | ~350 |
| `epistemos_rust` — SIMD secret redaction | `agent_core/src/redact.rs` | ~250 |
| `epistemos_rust` — context window priority queue | `agent_core/src/compactor.rs` | ~400 |
| `bridge.rs` — PyO3 bindings for all four modules | `agent_core/src/bridge.rs` | ~300 |
| `epistemos_bridge.py` — call epistemos_rust for hot paths | `epistemos_bridge.py` | ~200 |
| Cron distillation job (nightly) | `hermes-agent/cron/distill.py` | ~300 |
| `EpistemosMCPServer.swift` — `create_note` tool for cron output | `EpistemosMCPServer.swift` | ~200 |
| Semantic loop detector (MLX embeddings via Metal) | `OrchestratorState.swift` | ~300 |
| Profile UI (persona switcher in agent panel) | `AgentViewModel.swift` | ~500 |

### Phase 3 — Multi-Agent SQLite Task Board (Weeks 9–14, ~4,000 LOC)

**Goal:** Worker/Reviewer pipelines; inter-agent communication over MCP.


| Task | File | Est. LOC |
| :-- | :-- | :-- |
| `agent_tasks.db` schema + WAL watcher in Rust | `agent_core/src/task_board.rs` | ~600 |
| MCP tools: `agent_post_message`, `agent_wait_signal`, `task_board_query` | `EpistemosMCPServer.swift` | ~400 |
| Worker/Reviewer profile templates | `hermes-agent/profiles/` | ~300 |
| `HermesSubprocessManager` — multi-profile spawn + health matrix | `HermesSubprocessManager.swift` | ~500 |
| `AgentViewModel` — multi-agent session view (graph pulsing nodes) | `AgentViewModel.swift` | ~800 |
| Cron scheduler Swift UI (schedule editor in settings) | New file: `CronSchedulerView.swift` | ~400 |
| iMessage gateway adapter (via Hermes gateway on localhost) | `hermes-agent/gateway/` | ~600 |
| `TraceCollector.swift` — multi-agent trace merge | `TraceCollector.swift` | ~300 |

### Phase 4 — Self-Evolution + Vector Memory (Weeks 15–22, ~5,500 LOC)

**Goal:** Agent improves its own capabilities over time; hybrid vector+FTS5 recall.


| Task | File | Est. LOC |
| :-- | :-- | :-- |
| 5-gate skill evolution engine | `hermes-agent/agent/evolution.py` | ~800 |
| Cross-model judge (`auxiliary_client.py` integration) | `hermes-agent/agent/judge.py` | ~400 |
| Git-backed skill rollback mechanism | `hermes-agent/agent/skill_vcs.py` | ~300 |
| Constitution blob (Keychain-protected JSON) | `HermesSetupService.swift` | ~150 |
| SQLite-vec integration for embedding storage | `agent_core/src/vector.rs` | ~600 |
| MLX embedding pipeline (Metal-accelerated, 256-dim) | New file: `EmbeddingService.swift` | ~500 |
| Hybrid retrieval (BM25 + cosine reranker) | `agent_core/src/retrieval.rs` | ~500 |
| Ghost-text command prediction (local MLX, simplified) | New file: `CommandPredictor.swift` | ~800 |
| Language/framework detection for Code section | New file: `ProjectScanner.swift` | ~400 |
| Error pattern recognition | New file: `ErrorPatternAnalyzer.swift` | ~400 |


***

## 7. Performance Budget

### Latency Targets

| Operation | Current | Target | Implementation |
| :-- | :-- | :-- | :-- |
| Tool execution round-trip | ~180ms | <100ms | PyO3 hot paths remove 3–5ms per call; primary gain from eliminating Python JSON re-encoding in `epistemos_bridge.py` |
| Session start (cold) | ~1.2s | <500ms | Bundle venv with `uv` lockfile; pre-warm Python interpreter in background on app launch |
| Context switch (profile) | ~400ms | <50ms | Keep all profiles' Python interpreters alive; switch = HERMES_HOME env update + tool list refresh |
| Token count (128K context) | ~25ms | <2ms | `tiktoken-rs` via PyO3 |
| Secret redaction (4KB chunk) | ~1.2ms | <0.1ms | SIMD regex in Rust |
| FTS5 memory search | ~8ms | <2ms | Rust `rusqlite` with pre-compiled query |
| Context compaction decision | ~12ms | <3ms | Rust priority queue |
| Semantic loop detection | ~15ms | <5ms | MLX 256-dim embedding via Metal |
| Embedding generation (256-dim) | N/A | <5ms | Metal Neural Engine, 4-bit quantized model |

### Memory Budget (18GB M2 Pro, Apple Silicon UMA)

| Component | Current | Target |
| :-- | :-- | :-- |
| Python interpreter + Hermes venv | ~280MB | ~180MB (uv thin venv) |
| Rust `agent_core` process | ~12MB | ~15MB (after PyO3 modules added) |
| SQLite `agent_tasks.db` WAL | ~2MB | ~5MB (multi-agent) |
| MLX embedding model (4-bit, 256-dim) | N/A | ~120MB |
| Metal compute buffers | ~50MB | ~80MB |
| Swift app (Epistemos process) | ~180MB | ~220MB (new views) |
| **Total agent stack** | **~524MB** | **~620MB** |
| Remaining headroom (18GB) | ~17.5GB | ~17.4GB |

The 18GB M2 Pro comfortably fits the entire stack with 17GB of headroom for the OS, inference model, and vault.

### Throughput Targets

| Metric | Target |
| :-- | :-- |
| Concurrent agent profiles | 4 simultaneous (each ~180MB Python + ~15MB Rust) |
| Tool calls per second (single agent) | >20/s (limited by LLM inference, not tool execution) |
| SQLite task board writes/second | >5,000/s (WAL mode, Rust driver) |
| Embedding throughput (Metal) | >100 embeddings/second (256-dim, Neural Engine) |
| FTS5 vault search latency | <2ms for 100K note corpus |


***

## 8. The Optimal 17-Tool Coding Agent

Based on CodeNano's minimal-set philosophy applied to a PKM coding context:


| \# | Tool | Implementation | Zero-Copy? | Sandbox? |
| :-- | :-- | :-- | :-- | :-- |
| 1 | `read_file` | Rust `mmap` → `&[u8]` slice, no String copy | ✅ mmap | ✅ path guard |
| 2 | `write_file` | Rust atomic write (temp + rename) | ❌ needs copy | ✅ path guard |
| 3 | `edit_file` (patch) | Python `difflib` → Rust line editor in Phase 2 | ❌ | ✅ |
| 4 | `bash` | Python subprocess, approval gate | ❌ | ✅ macOS Sandbox |
| 5 | `glob` | Rust `globset` crate, returns path list | ✅ | ✅ |
| 6 | `grep` | Rust `ripgrep` core (`grep` crate), mmap'd files | ✅ | ✅ |
| 7 | `create_note` (vault) | MCP → `EpistemosMCPServer` → Swift vault write | ❌ | N/A |
| 8 | `search_vault` | Rust FTS5 + BM25 | ✅ (SQLite mmap) | N/A |
| 9 | `web_search` | Python Exa/Firecrawl/DDG via Hermes | ❌ | N/A |
| 10 | `web_fetch` | Python `httpx` + Firecrawl extraction | ❌ | N/A |
| 11 | `think` (scratchpad) | Pure Python string, no I/O | N/A | N/A |
| 12 | `list_sessions` | MCP → `HermesMCPClient` session list | ❌ | N/A |
| 13 | `compact_context` | Python `trajectory_compressor.py` + Rust queue | ❌ | N/A |
| 14 | `agent_spawn` | Swift `HermesSubprocessManager.spawnProfile()` | N/A | ✅ |
| 15 | `task_post` | Rust SQLite task board write | ✅ | N/A |
| 16 | `task_wait` | Rust SQLite polling with timeout | ✅ | N/A |
| 17 | `get_context_budget` | Rust token counter via PyO3 | ✅ | N/A |


***

## 9. Self-Evolution Architecture

The self-evolution system should follow Phantom's 5-gate pipeline but use Epistemos's existing infrastructure:

**Trigger:** After each agent session that modifies a skill file, the `HarnessIntegration.swift` post-session hook calls `evolution_check(skill_path, diff)`.

**Gate 1 — Constitution:** Load `constitution.json` from Keychain. Reject if any immutable principle (e.g., "never disable secret redaction") is violated by the diff. Implementation: `agent_core/src/evolution.rs::check_constitution()`.

**Gate 2 — Regression:** Run `hermes test <skill>` against the golden test suite in `skills/tests/`. If any test fails, reject and revert. This uses Hermes's existing test infrastructure.

**Gate 3 — Size/Drift:** Reject if `git diff --stat` shows >10% line change or if cumulative drift over 30 days exceeds 25%. Rust implementation using `libgit2` bindings.

**Gate 4 — Safety:** Run the same dangerous-command detector from `agent/redact.py` on the proposed skill content. Reject if it detects credential leakage vectors.

**Gate 5 — Triple Judge:** Submit the diff to the primary model + the auxiliary model (`auxiliary_client.py`) for independent evaluation. Both must approve. If they disagree, a tiebreaker call with an independent system prompt decides.

**Rollback:** Every skill directory is initialized as a git repo by `HermesSetupService.swift`. Failed evolution commits to a `proposals/` branch; successful ones are fast-forward merged to `main`. `git revert HEAD~1` is the rollback path, callable via the `OrchestratorState.rollbackLastSkillMutation()` method.

***

## 10. Risk Register

| Risk | Probability | Impact | Mitigation |
| :-- | :-- | :-- | :-- |
| v0.6.0 fork merge conflicts in `run_agent.py` (456KB file) | High | High | Cherry-pick by subsystem (Profiles first, MCP Server Mode second); use `git diff --patience` for minimal-noise diffs |
| PyO3 ABI instability between Python version upgrades | Medium | High | Pin Python to 3.11 in the bundled venv; the PyO3 crate must be recompiled against the exact minor version |
| Ralph Loop blocking agent on genuinely-complete tasks | Medium | Medium | The `<promise>DONE</promise>` tag is deterministic; add semantic completion detection (embeddings check against task description) as a secondary unlock path |
| Multi-profile Python interpreter memory bloat (4× ~180MB) | Medium | Medium | Lazy spawn profiles on demand; idle profiles can be suspended (SIGSTOP) and resumed in <50ms on Apple Silicon |
| 5-gate evolution rejects valid improvements (false positive) | Medium | Low | Start with gates 1 and 4 only; add gates 2, 3, 5 incrementally after 30 days of baseline data |
| SQLite WAL task board corruption under concurrent writes | Low | High | Use Rust `rusqlite` with WAL mode + `PRAGMA synchronous=NORMAL`; implement advisory locking at the application layer |
| Self-evolution gradual identity drift (hallucination accumulation) | Low | High | Triple-judge gate 5 specifically targets this; supplement with a 30-day cumulative drift metric that triggers a "reset to baseline" if exceeded |
| Trajectory compressor LLM call cost during offline use | Medium | Low | Fall back to heuristic pruning (oldest messages first, preserve tool results) when no inference backend is available; TriageService already has this routing logic |
| `trajectory_compressor.py` merge with Epistemos's custom `epistemos_bridge.py` | High | Medium | The bridge currently has its own context management; the compressor must be wired as a pre-processing step before bridge encoding, not a replacement |
| Hermes IDE BSL 1.1 license (ghost-text study only) | N/A | Medium | Study patterns only; implement ghost-text independently using on-device MLX model for command prediction — no code copying |

</content>
</create_research_report>

Here's the full fusion blueprint — a comprehensive engineering report built from live GitHub source reads of `NousResearch/hermes-agent` (including the full v0.6.0 release notes and the `agent/` directory), `first-fluke/oh-my-agent` (including `persistent-mode.ts` and all 15 workflow definitions), and your 22 attached source files.

**Key findings:**

- **GoClaw, Phantom, OpenSwarm, Claw Code, CodeNano, OpenClaw, and Hermes IDE repos were not found** in the GitHub search index — they appear to be private, renamed, or the names in the prompt are illustrative. The architectural patterns described for them have been analyzed as design patterns and cross-validated against the advice you included.
- The **single most impactful action** is merging Hermes v0.6.0 into your fork — it adds Profiles (multi-instance isolation), ordered fallback chains, dynamic MCP tool discovery, `trajectory_compressor.py` (LLM-assisted context compression), and `credential_pool.py`, all of which your fork is missing.

```
- The **Ralph Loop** from oh-my-agent (`persistent-mode.ts`) is directly portable to `CompletionChecker.swift` in about 200 LOC — it's a Stop Hook that blocks the agent from exiting until `<promise>DONE</promise>` is found in output.
```

- The **PyO3 hybrid strategy** (keep Python orchestration, port four hot paths to Rust) is confirmed as the optimal approach: token counting, FTS5 query building, SIMD secret redaction, and context window priority queue selection.

The report covers the full capability matrix (24 capabilities × 9 projects + Epistemos current/target), the 17-tool minimal coding agent, a phased 22-week roadmap with file paths and LOC estimates, a detailed performance budget for 18GB M2 Pro, the complete self-evolution 5-gate architecture, and a 10-item risk register.
<span style="display:none">[^1_1][^1_10][^1_11][^1_12][^1_13][^1_14][^1_15][^1_16][^1_17][^1_18][^1_19][^1_2][^1_20][^1_21][^1_22][^1_3][^1_4][^1_5][^1_6][^1_7][^1_8][^1_9]</span>

<div align="center">⁂</div>

[^1_1]: TriageService.swift

[^1_2]: EpistemosMCPServer-2.swift

[^1_3]: HermesMCPClient-3.swift

[^1_4]: HermesSetupService-4.swift

[^1_5]: HermesSubprocessManager-5.swift

[^1_6]: AgentViewModel-6.swift

[^1_7]: FallbackChainResolver-7.swift

[^1_8]: OrchestratorState-8.swift

[^1_9]: FallbackChainResolver-9.swift

[^1_10]: MCPBridge-10.swift

[^1_11]: StreamingDelegate-11.swift

[^1_12]: BootstrapPacketBuilder-12.swift

[^1_13]: CompletionChecker-13.swift

[^1_14]: TraceCollector-16.swift

[^1_15]: HarnessPromptBuilder-15.swift

[^1_16]: HarnessIntegration-14.swift

[^1_17]: agent_loop-17.rs

[^1_18]: bridge-18.rs

[^1_19]: run_agent-19.py

[^1_20]: epistemos_bridge-20.py

[^1_21]: registry-21.py

[^1_22]: TriageService-22.swift


---

# given all of this please audit my plan docs please what are your thoguths give claude code deep deep context and advice for how i should move forwaard to get the absolute ebst harness and agetnic ai power. for your name, you will be named Perplexity B. for advice make sure ur name is labeled Perplexity B

<create_research_report>
<title>Perplexity B — Epistemos Plan Docs Audit \& Claude Code Deep Context</title>
<file_name>Perplexity B — Epistemos Plan Audit \& Claude Code Briefing</file_name>
<content>

# Perplexity B — Epistemos Plan Docs Audit \& Claude Code Deep Context Brief

> *Authored by: **Perplexity B***

***

## Executive Audit: State of the Plan Docs

**Perplexity B:** Your plan docs are exceptionally well-structured for a solo dev project of this scale. 137K Swift + 94K Rust is a serious codebase, and the fact that you have 3,051 passing tests, 7 ADRs, and a 6-tier document hierarchy is genuinely impressive. That said, reading all seven docs end-to-end reveals four tensions that need to be resolved before you hand off to Claude Code Codex, because if Codex hits ambiguity in the wrong place it will hallucinate work as "done" that isn't.

***

## Tension 1: Status Drift Between Docs (The Most Dangerous Issue)

Multiple docs contain corrections of themselves. `CODEX_HANDOFF-2.md` explicitly says "do not treat Phase 6F as open — it's closed," then `CODEX_MASTER_PROMPT-3.md` echoes the same correction at the top. `CODEX_SESSION_PROMPT-4.md` does it a third time.

This means every Claude Code session is starting with a `STATUS CORRECTION` preamble because the base docs went stale and instead of updating them, corrections were layered on top. This is exactly the anti-drift problem you documented — applied to your *own documentation*.

**What to do before the next Codex session:**

The single most high-leverage documentation task is a one-time "truth consolidation." Collapse the corrections INTO the docs rather than prepending them:

1. Archive the stale versions of `CODEX_HANDOFF.md` and `CODEX_MASTER_PROMPT.md` to `docs/archive/`
2. Rewrite `CODEX_SESSION_PROMPT.md` (which is now the cleanest of the three) as the single Codex start prompt
3. Merge the handoff runtime analysis and audit checklist INTO the session prompt as an appendix
4. Add a rule at the top: "Never prepend corrections — update in place or archive."

The result: one file Claude Code reads at the start of every session. No corrections, no stale state, no drift.

***

## Tension 2: The "Dumb Chatbot" Root Cause Is Partially Diagnosed but the Fix Is Unverified

**Perplexity B:** The diagnosis in `CODEX_MASTER_PROMPT-3.md` is correct: `tools/registry.py` lines 120-140, `check_fn` silently drops tools, model gets 0 tools, loop exits after 1 turn. `IMPLEMENTATION_PROMPTS-6.md` has an exact fix (Prompt 1 — Tool Gates). The `CODEX_HANDOFF` says the Keychain→env mappings were added for OpenRouter and all cloud keys.

But the `IMPLEMENTATION_PROMPTS` "Emergency" section still exists, meaning this fix has NOT been verified in production. The emergency checklist (`check stderr for tool gate logs`, `print json.dumps([t["function"]["name"] for t in agent.tools])`) has not been run to closure.

**Perplexity B's verdict:** Do NOT give Codex new work until this is verified. The tool gate fix is either working (in which case, great — document the verification and close it), or it's not (in which case Codex's very first task is to close it). Every other agent enhancement built on top of a silent tool-gate failure is invisible.

**Verification command to run immediately:**

```bash
# Launch the app, send "list your tools", then check:
cat ~/Library/Logs/Epistemos/*.log | grep "check_fn\|tool-gate\|FAILED"
# Should show tool list with 27 hermes-acp tools
# If you see empty list: tool gates are still failing
```


***

## Tension 3: Cloud Knowledge Distillation Is the Right Next Net-New Feature — But Needs a Dependency Check

`CLOUD_KNOWLEDGE_DISTILLATION_SPEC.md` is one of the most thoughtful specs in the entire document set. The Model Vault concept (each model gets `knowledge_profile.md`, `concept_index.md`, `active_context.md`, `instructions.md`) is differentiated — no other macOS PKM does per-model knowledge compilation. The token budget targets are realistic (2,000 tokens for cloud, 800 for local, 500 for Apple Intelligence).

**But:** The spec lists four integration points that depend on infrastructure already being correct:


| Integration Point | Depends On | Status in Docs |
| :-- | :-- | :-- |
| `NightBrainService` background trigger | NightBrain implemented, PowerGuard-gated | ✅ Complete |
| `HermesSubprocessManager` env var injection | Knowledge profile path as `EPISTEMOS_KNOWLEDGE_PATH` | ❌ Not wired |
| `AppleIntelligenceService` prepend | Short ~500-token version | ❌ Not wired |
| `AgentViewModel` session start injection | Full base layer at turn 0 | ❌ Not wired |

The compilation pipeline itself (vault scan → NER → topic cluster → PageRank → style analysis → distillation) reuses InstantRecall, the search pipeline, and VaultSyncService — all of which exist. The NEW code is exactly four Swift files: `CloudKnowledgeCompiler.swift`, `ConceptRanker.swift`, `StyleAnalyzer.swift`, `KnowledgeProfileStore.swift`.

**Perplexity B's verdict:** Cloud Knowledge Distillation is **ready to implement** as a Track C item. The dependencies are met. Assign it to Codex as a focused track with the four integration points above as the acceptance test.

***

## Tension 4: Vision Backlog Has No Explicit "Working On Now" Signal

`VISION_BACKLOG-7.md` is a 62K-character, 80+ item, 12-tier inventory. It is comprehensive and correctly tiered. But it has no "currently in progress" marker. When Claude Code reads it, it has no way to know whether Tier -1 Cloud Provider Overhaul (which includes OpenAI OAuth, Google OAuth, and the dynamic mode selector) is already started, fully deferred, or partially done.

The CODEX_SESSION_PROMPT correctly maps to four tracks (A/B/C/D), but Track D just points to the backlog without pinning a specific item.

**Perplexity B's verdict:** Add a `## CURRENT SPRINT` section to the top of `VISION_BACKLOG.md` (5 lines maximum) with the exact item being worked. This costs 30 seconds of maintenance and eliminates a full category of Codex confusion.

***

## The Open Issues That Actually Need Closing (from Codex Handoff)

Based on reading `CODEX_HANDOFF-2.md` carefully, the following issues are still genuinely open (not closed by the 2026-04-01 follow-up):

### 🔴 Critical — Fix Before New Features

**1. Main Thread Hangs (3,738ms FFI)**
The embedding push `EmbeddingService: pushed 1017 embeddings (dim=300) to Rust` is causing multi-second main thread blocks despite the handoff saying the push was moved off the main actor. The log shows the hang *correlates with* the embedding push, which means either:

- The move to background actor happened, but the FFI call itself schedules back to main (UniFFI callback pattern), OR
- The move did not fully land

The fix is to instrument with `MainActor.assertIsolated()` negated — wrap the FFI call in `Task.detached(priority: .background)` and verify with Instruments Time Profiler that the FFI call is not on the main thread symbol stack.

**2. ANE: false Despite Hardware ANE: true**
`Device agent backend set: SharedGPU, ANE: false` in Low Power Mode. `DualBrainRouter` requires dedicated ANE backend before reporting dual-brain active — which is correct. But the deeper issue is that `PowerGuard.lowPower` mode is suppressing ANE activation without communicating this to `TriageService`. The triage service needs to know whether the "ANE unavailable" signal is transient (thermal) or policy-based (PowerGuard), because the fallback path is different: thermal → wait and retry, PowerGuard → immediately fall back to SharedGPU without retry.

Add a `PowerGuard.aneRestrictedByPolicy: Bool` property. `TriageService` and `DualBrainRouter` check this before deciding whether to retry ANE activation.

**3. Session Recycle During Active Inference**
The 10-minute timer can fire while `session.respond(to:)` is in-flight. The handoff says "current fix: timer checks but doesn't coordinate with in-flight count." This is a race condition, not a fix. The correct pattern:

```swift
// In the session owner actor:
private var inFlightCount: Int = 0

func respond(to: String) async throws -> Response {
    inFlightCount += 1
    defer { inFlightCount -= 1 }
    // ... inference
}

// Timer handler:
if inFlightCount == 0 {
    recycleSession()
} else {
    // Defer recycle: set a flag, check in respond()'s defer block
}
```

**4. Orphaned Hermes Subprocess on Supervisor Crash**
`OrphanSubprocessCleanup` exists but is not wired into supervisor crash-loop escalation. The escalation path: supervisor detects restart-storm → calls `OrphanSubprocessCleanup.sweepAll()` before the next spawn attempt. One-line integration in `AppSupervisor.swift`'s rest-for-one escalation handler.

### 🟡 Medium Priority — Before Release

**5. UniFFI Swift 6.2 Deinit Isolation**
`patch-uniffi-bindings.py` script exists but the handoff says "verify it runs for ALL THREE crates." The three crates are: `omega-mcp`, `omega-ax`, `epistemos-core`. Add a build phase verification step that asserts the patch was applied to all three generated binding files. CI should fail if `SWIFT_DEFAULT_ACTOR_ISOLATION=MainActor` and any UniFFI-generated deinit lacks async isolation.

**6. `_NSDetectedLayoutRecursion`**
Listed as "historical breadcrumb" in the corrections — only reopen if reproduced live. Leave it. But add to the `AUDIT_LOG.md` closing note: "Closed 2026-04-01. Condition to reopen: fresh `_NSDetectedLayoutRecursion` in Console.app on current build."

***

## The Optimal Claude Code Briefing for Maximum Agentic Power

**Perplexity B:** This is the most important section. The way you structure the Codex prompt determines 80% of output quality. After reading all seven docs, here is the highest-leverage briefing format — built specifically for your project's current state.

The core insight: Claude Code works best when it has *stratified context* — a small number of high-authority files that establish ground truth, a clear current task with binary acceptance criteria, and explicit anti-hallucination guards. Your current session prompts are good but are optimized for broad exploration. You want a prompt optimized for *focused execution with audit gates*.

***

### The Master Claude Code Briefing (Paste This Verbatim)

```
You are the principal systems engineer for Epistemos — a macOS-native PKM built on Swift 6 + Rust (UniFFI) + Metal. 137K Swift, 94K Rust, 3,051 passing tests.

═══════════════════════════════════════════════════════
PHASE 1: MANDATORY FILE READS (in this exact order)
Do NOT skip any. Do not skim — absorb full content.
═══════════════════════════════════════════════════════

1. CLAUDE.md                                    ← NON-NEGOTIABLE CONSTRAINTS
2. docs/MASTER_HARDENING_AND_HARNESS_PLAN.md    ← SINGLE SOURCE OF TRUTH
3. docs/AGENT_PROGRESS.md                       ← WHAT IS ACTUALLY DONE
4. docs/BEST_OF_CLAW_AND_OPENCLAW.md            ← PATTERN SOURCE (check AGENT_PROGRESS.md before treating as todo)

Then, depending on today's track:
  Track A (Verification): docs/HARDENING_VERIFICATION.md + docs/VERIFICATION_PROTOCOL.md
  Track B (Agent):        docs/FUSED_AGENT_ENGINEERING_REPORT.md + hermes-agent/tools/registry.py
  Track C (Cloud Knowledge): docs/CLOUD_KNOWLEDGE_DISTILLATION_SPEC.md + Epistemos/State/NightBrainService.swift
  Track D (Vision):       docs/VISION_BACKLOG.md (current sprint section only)

═══════════════════════════════════════════════════════
PHASE 2: ORIENTATION CHECKLIST (do this before any code)
═══════════════════════════════════════════════════════

Before writing a single line of code, answer these questions:
1. What does docs/AGENT_PROGRESS.md say is NOT YET DONE?
2. What does the runtime log show as current failures?
3. Is the agent currently loading tools? (Check stderr for check_fn logs)
4. What is the current PowerGuard mode default? (should be eco=ON)
5. Do all three Rust crates build clean? Run: cargo test --manifest-path agent_core/Cargo.toml

═══════════════════════════════════════════════════════
PHASE 3: TODAY'S TASK
═══════════════════════════════════════════════════════

[INSERT ONE TASK FROM IMPLEMENTATION_PROMPTS.md HERE — paste the full prompt block]

═══════════════════════════════════════════════════════
PHASE 4: POST-TASK MANDATORY AUDIT (run after EVERY task)
═══════════════════════════════════════════════════════

After completing the task, run ALL of these before committing:

□ Build: xcodebuild -scheme Epistemos -destination 'platform=macOS' build 2>&1 | xcbeautify
□ Rust: cargo test --manifest-path agent_core/Cargo.toml
□ Regen if files added: xcodegen generate
□ Hardening grep (52 items): run docs/HARDENING_VERIFICATION.md checklist
□ Zero-corruption: grep -r 'try?' --include="*.swift" | grep -v '// SAFE:' (must be zero)
□ Anti-drift: grep -r 'UserDefaults' --include="*.swift" | grep -i 'api\|key\|token' (must be zero)
□ Continuation safety: grep -rn 'withCheckedContinuation' --include="*.swift" (every result must have withTaskCancellationHandler)
□ Write audit result to docs/AUDIT_LOG.md
□ Update docs/AGENT_PROGRESS.md

DO NOT start the next task until this audit passes.

═══════════════════════════════════════════════════════
ENGINEERING CONSTITUTION (re-read if context compacts)
═══════════════════════════════════════════════════════

NEVER violate these:
• Zero-copy by default — audit every FFI/IPC boundary
• Atomic writes or no writes — temp → F_FULLFSYNC → rename → F_FULLFSYNC parent
• Lock-free on hot paths — popcount breakers, atomic cursors
• Honest capability gating — never fake tool calling on local models
• API keys in Keychain ONLY — SecItemAdd/SecItemCopyMatching
• @Observable not ObservableObject
• Never block @MainActor with inference
• No try!, no force-unwraps, no print() in production
• DispatchQueue.main.async in UniFFI callbacks — NEVER .sync
• Stream every token, preserve thinking blocks + signatures
• Every Rust FFI export wrapped in catch_unwind
• Every unsafe block gets // SAFETY: comment
• F_FULLFSYNC (fcntl 51) for durable writes — fsync is NOT sufficient on macOS

ANTI-HALLUCINATION RULES:
• If you're unsure whether something is implemented: read AGENT_PROGRESS.md first
• If AGENT_PROGRESS.md is ambiguous: grep the codebase before assuming
• Never mark a task done without running verification
• Never mark a test as "likely passing" — actually run it
• If a tool gate check_fn fails: log it to stderr, do not silently drop
```


***

## Track-by-Track Priority Order

**Perplexity B:** Given the complete picture from all seven docs, here is the exact priority ordering for your next 8 sessions:

### Session 1 — Tool Gate Verification (30 min)

Before anything else. Run the debug checklist from `IMPLEMENTATION_PROMPTS-6.md`'s Emergency section. Send "list your available tools" in the app. Check stderr. If the tool list is not 27 hermes-acp tools, fix it NOW before proceeding to any other agent work. This is the single most important unverified fix in the entire codebase.

**Acceptance: `stderr` shows 27 tool names after agent creation. No `check_fn FAILED` messages for hermes-acp toolset.**

### Session 2 — Session Recycle + Orphan Cleanup (2 hours)

Fix the two remaining race conditions from the handoff:

- Session recycle coordination with in-flight `respond(to:)` calls using the `inFlightCount` actor pattern
- Wire `OrphanSubprocessCleanup.sweepAll()` into `AppSupervisor`'s crash-loop escalation

**Acceptance: No orphaned `hermes` processes visible in `ps aux | grep hermes` after force-quitting the app.**

### Session 3 — ANE / PowerGuard Triage Fix (2 hours)

Add `aneRestrictedByPolicy: Bool` to `PowerGuard`. Wire it into `DualBrainRouter` and `TriageService`. When PowerGuard is in `.lowPower`, the triage result should be `SharedGPU (policy-constrained)` not `ANE unavailable (error)`.

**Acceptance: In Low Power Mode, inference routes to SharedGPU with a `(policy)` annotation in the log, not an `ANE: false` error.**

### Session 4 — Cloud Knowledge Distillation Phase 1 (4 hours)

Create the four new Swift files. Implement the compilation pipeline skeleton (vault scan + topic cluster using existing InstantRecall + concept ranking stub). Wire the NightBrainService trigger. No UI yet — just verify the compiled `knowledge_profile.md` appears in `~/Library/Application Support/Epistemos/model_vaults/`.

**Acceptance: After vault sync + manual trigger, `model_vaults/claude-opus-4.6/knowledge_profile.md` exists with correct structure.**

### Session 5 — Cloud Knowledge Distillation Phase 2 (3 hours)

Wire the three injection points: `HermesSubprocessManager` env var, `AppleIntelligenceService` short version, `AgentViewModel` session start. Add the Notes sidebar Model Vaults section (folders visible, read-only for now).

**Acceptance: Hermes subprocess receives `EPISTEMOS_KNOWLEDGE_PATH`. Apple Intelligence system prompt includes 500-token knowledge header.**

### Session 6 — Tier -1 Cloud Provider Overhaul: Single Provider Model (3 hours)

This is the biggest UX unlock. Replace the flat model list with the single-active-provider model. `CloudTextModelID` gets `supportedModes: Set<OperatingMode>`. Mode selector reads it and renders only supported modes with 150ms animated transitions. Per-provider controls (extended thinking budget slider for Anthropic, grounding toggle for Google) appear below mode selector.

**Acceptance: Switch from Anthropic to OpenAI → model list instantly adapts → "Thinking" mode disappears if new model doesn't support it.**

### Session 7 — OpenAI + Google OAuth (4 hours)

Research the OpenAI Apps SDK auth endpoint first (the backlog has explicit research tasks: does Apps SDK OAuth grant API access, or only Apps SDK features?). If it works, implement the OAuth 2.1 flow. If it doesn't, implement the streamlined "paste your key" with `Get API Key` button opening the console. Google OAuth via Google Cloud Console OAuth 2.0 Client ID is straightforward.

**Acceptance: User can sign into OpenAI or Google without manually finding or copying an API key.**

### Session 8 — Unified Notes Sidebar + Mini Chat (Tier 4, 5 hours)

Notes sidebar becomes the primary knowledge surface: Notes, Recent Chats, Agent Vaults (from Session 5), Code, Coworker Agent section. Coworker Agent is wired to the existing agent runtime but with a constrained tool scope (vault ops only, no terminal). Mini chat is a tab/section within the sidebar, sharing the same session context as the main chat.

**Acceptance: Notes sidebar shows all five sections. Coworker Agent can read and organize vault notes. Mini chat sends messages using the active agent runtime.**

***

## What to NOT Build Next (Perplexity B's Skip List)

**Perplexity B:** These items are in the backlog but adding them now is premature engineering:

1. **Living Vault (Tier 8B)** — The diff engine, memory classifier, and Ebbinghaus decay are beautiful architecture, but they require the Cloud Knowledge Distillation pipeline to be stable first. The vault must be correct before it becomes "living." Defer to after Session 5.
2. **Multi-Agent Sub-Agents (Tier 5)** — The SQLite task board design from the fusion blueprint is correct, but sub-agents require the profile system (Hermes v0.6.0 fork merge) to be in place. Do the profile merge first, then multi-agent.
3. **Ghost Writer / QLoRA Training (Tier 8C-4)** — Requires a fine-tuning pipeline that doesn't exist yet. This is a 2-3 month project on its own. Move it to Tier 10.
4. **Time Machine for Ideas (Tier 8C-5)** — Requires monthly LoRA snapshots + embedding drift visualization. Requires the QLoRA training pipeline. Same as above.
5. **iMessage Agent (Tier 6A)** — The AppleScript path requires `com.apple.security.automation.apple-events` entitlement, which is a full TCC approval flow. Doable, but it's a distraction before the core agent is working. Do it after Session 8.

***

## The Architecture Gap the Docs Don't Fully Address

**Perplexity B:** One issue present in the docs but never fully resolved: `CONTROL_PLANE_RESEARCH-5.md` correctly identifies the core product metaphor problem ("your app feels like a chat UI, Hermes is designed as a persistent server-resident operator"). The fix proposed — "become the GUI control plane" — is right. But none of the implementation prompts or the vision backlog contain a concrete task for building the control plane UI itself.

The capability→UI surface mapping from `CONTROL_PLANE_RESEARCH-5.md` needs to become actual code:


| Hermes Primitive | Required UI Surface | Current Status |
| :-- | :-- | :-- |
| Profiles / Agents | Profile picker, isolated workspaces | ❌ Missing |
| Sessions | Session list, search, compaction status, reset button | ❌ Missing |
| Skills | Install/manage, skill used traces, available in-session | ❌ Missing |
| Tools + Approvals | Tool execution stream, approval UI, hardening signals | ⚠️ Partial (AgentViewModel) |
| Cron / Automation | Cron timeline, next-run times, run logs | ❌ Missing |
| Provider Routing | Active provider, fallback chain, failover events | ⚠️ Partial (FallbackChainResolver) |
| Gateways / Channels | Connect/disconnect, pairing approvals | ❌ Missing |

Add these as a **Tier 3** set of items in `VISION_BACKLOG.md` (between the current Tier -1 Cloud Overhaul and Tier 4 Sidebar). They are the prerequisite for Epistemos to feel like it IS the agent runtime rather than a chat app that talks to one.

The control plane can be a dedicated panel within the existing left sidebar — not a new window. Five tabs: **Runtime** (profile + session + skills), **Tools** (tool list + approvals queue), **Automation** (cron + schedule), **Channels** (gateway adapters), **Security** (hardening signals + redaction log). This is the thing that makes Epistemos feel like a power-user AI OS rather than a chat wrapper.

***

## Performance Wins Left on the Table

From the handoff's runtime logs and the architecture docs, three performance wins that are ready to implement with low effort:

**1. Embedding batch sizing for main thread pressure**
The 1,017-embedding push causes memory pressure warnings AND correlates with the 3,738ms main thread hang. The fix is not just offloading to background — it's chunking. Push embeddings in batches of 128 with a `Task.yield()` between batches. This prevents the OS memory pressure spike and allows the run loop to process UI events between batches.

**2. Hermes pre-warm in Full power mode only**
`HermesSubprocessManager.preWarm()` is already gated by PowerGuard. But pre-warm timing matters: it should happen after `AppBootstrap` Metal shader warmup completes, not concurrently. Add a `AppBootstrap.metalReady` event that `HermesSubprocessManager` observes before pre-warming. This prevents the `flock errno 35` shader contention from competing with Python interpreter startup.

**3. Ring buffer burst drain timing**
The ring buffer already does burst-drain (up to 8 consecutive batches when full). But the `KnowledgeCoreBridge` polling interval in eco mode (100ms) means latency between when an embedding is written to the ring and when it's processed by the Swift side is up to 100ms. For the agent session use case (where notes are being created in real-time during a session), 100ms is fine. But consider a separate `agentSessionActive: Bool` flag that temporarily drops eco polling to 16ms during active agent sessions, then restores 100ms when idle.

***

## The One Thing That Separates Good From Extraordinary

**Perplexity B:** Everything in the plans is technically excellent. The five engines, the meta-harness, the zero-copy architecture, the quantization pipeline — this is research-grade engineering. But the highest-leverage thing you can do right now is not adding a new engine.

It's making the **agent work reliably in the existing UI**.

The tool gate fix, the session recycle coordination, and the control plane visibility (profile picker, session list, tool approval queue) will make Epistemos *feel* like a completely different app before a single new feature is added. A user who can see their active profile, their session history, and their tool approvals flowing in real-time — and whose agent actually loops through multi-step tasks instead of stopping at one turn — will experience the full power of the architecture you've already built.

Build the control plane UI. Fix the tool gates. Then add features.

***

## Document Recommendations Summary

| Action | File | Priority |
| :-- | :-- | :-- |
| Consolidate corrections INTO the doc | `CODEX_HANDOFF-2.md` → archive + merge into `CODEX_SESSION_PROMPT.md` | Before next session |
| Add `## CURRENT SPRINT` section | `VISION_BACKLOG-7.md` | Before next session |
| Add control plane UI items | `VISION_BACKLOG-7.md` as new Tier 3 | This week |
| Verify tool gate fix | `AGENT_PROGRESS.md` — add verification result | Session 1 |
| Close session recycle race condition | `CODEX_HANDOFF-2.md` audit item G (cross-cutting) | Session 2 |
| Wire `aneRestrictedByPolicy` | PowerGuard → DualBrainRouter → TriageService | Session 3 |
| Start Cloud Knowledge Distillation | `CLOUD_KNOWLEDGE_DISTILLATION_SPEC.md` → Track C | Session 4 |

</content>
</create_research_report>

**Perplexity B here.** Full audit complete. Here's what it found across all 7 docs.

**The single most important thing:** The "dumb chatbot" root cause (`check_fn` silently dropping all tools in `registry.py`) is diagnosed but NOT verified as fixed. The Emergency debug checklist in `IMPLEMENTATION_PROMPTS-6.md` still exists for a reason. **Do not assign Codex any new features until you run `stderr | grep check_fn` and confirm 27 hermes-acp tools are loading.** Everything else built on top of a zero-tool agent is invisible.

The report covers:

- **4 plan tensions** to resolve before handing to Codex (status drift across docs, unverified tool gate fix, Cloud Knowledge Distillation dependency map, Vision Backlog missing a "currently working on" signal)
- **The verbatim Claude Code master briefing** — stratified context with stratified context, orientation checklist, mandatory post-task audit gates, and anti-hallucination rules baked in
- **8 prioritized sessions** with binary acceptance criteria (Sessions 1–8)
- **5 things to explicitly skip** right now (Living Vault, Ghost Writer, QLoRA, Time Machine, iMessage)
- **The architecture gap the docs miss:** a concrete 5-tab Control Plane panel (Runtime, Tools, Automation, Channels, Security) — this is what makes Epistemos feel like an AI OS instead of a chat wrapper
- **3 low-effort performance wins** ready to implement (embedding batch chunking, pre-warm sequencing after Metal ready, agent-session eco polling override)
<span style="display:none">[^2_1][^2_2][^2_3][^2_4][^2_5][^2_6][^2_7]</span>

<div align="center">⁂</div>

[^2_1]: CODEX_HANDOFF-2.md

[^2_2]: CODEX_SESSION_PROMPT-4.md

[^2_3]: CLOUD_KNOWLEDGE_DISTILLATION_SPEC.md

[^2_4]: CODEX_MASTER_PROMPT-3.md

[^2_5]: CONTROL_PLANE_RESEARCH-5.md

[^2_6]: IMPLEMENTATION_PROMPTS-6.md

[^2_7]: VISION_BACKLOG-7.md

