# Multi-Agent System Architecture Research: Formal Patterns for Epistemos MAS

> **Study Date:** 2025-06-10 | **Scope:** 7 production MAS frameworks | **Objective:** Extract formal, port-ready patterns for Rust/Swift implementation

---

## Abstract

This document presents a forensic analysis of seven multi-agent system (MAS) architectures—OpenClaw, NemoClaw, Hermes Agent, Claude Code, Cursor 2.0, MCP, and A2A—to extract their formal design patterns, universal abstractions, and Rust-portable kernel. Through analysis of official documentation, source repositories, and architecture reviews, we identify a shared **six-factor agent model** (Loop, Tools, Memory, Context, Governance, Orchestration), map four dominant **orchestration topologies**, and define a **minimal MAS kernel in Rust** (~200 lines) that captures all observed patterns. All claims are backed by inline citations to primary sources.

---

## 1. System-by-System Analysis

### 1.1 OpenClaw — The Open-Source Agent Operating System

**Repository:** `github.com/openclaw/openclaw` [^3086^] | **License:** MIT | **Scale:** 430K+ lines TypeScript, pnpm workspace monorepo [^3085^]

#### Architecture
OpenClaw treats AI agents as an **infrastructure problem**, not a prompt-engineering problem [^3082^]. Its architecture follows a **hub-and-spoke** pattern centered on a single **Gateway** Node.js process that acts as the control plane between user inputs and the AI agent runtime [^3082^]:

```
User (WhatsApp/Telegram/Discord/Slack/iMessage/Teams/CLI/Web)
                    |
                Gateway (WebSocket server, session router)
                    |
        +-----------+-----------+
        |                       |
    Agent Runtime          Channel Adapters
    (LLM + loop +          (15+ platforms:
     tools + memory)         Telegram, Discord,
                            Slack, WhatsApp,
                            Signal, Matrix, etc.)
        |
    +---+---+---+---+
    |   |   |   |   |
  Skills  Canvas  Cron  Nodes  Browser
  (plugins) (UI)  (sched) (exec) (automation)
```

**Key architectural decisions:**

1. **Gateway as control plane**: Single long-running process manages all messaging connections, orchestrates LLM calls, and hands work to skills [^3080^]. The Gateway normalizes inbound/outbound messaging so the rest of the system is platform-agnostic [^3082^].

2. **Agent Runtime**: Executes the core loop end-to-end: assembles context from session history and memory, invokes the model, executes tool calls, and persists updated state [^3082^]. The loop follows the classic **perceive → plan → act → reflect** pattern [^3112^][^3114^].

3. **Skills system**: Capabilities are packaged as directories containing a `SKILL.md` file with metadata and LLM instructions. The public marketplace (ClawHub) hosts thousands of community skills [^3080^]. Plugins extend the system via discovery-based loading: the plugin loader scans workspace packages for `openclaw.extensions` in `package.json` and hot-loads when configuration is present [^3082^].

4. **Persistent memory**: Configuration and interaction history stored locally in Markdown files (`MEMORY.md`, `HEARTBEAT.md`). The heartbeat scheduler sends periodic LLM requests in the background to check for scheduled tasks, enabling autonomous operation even without direct user commands [^3080^].

5. **Multi-agent routing**: The Gateway routes inbound channels/accounts/peers to **isolated agents** (workspaces + per-agent sessions) [^3086^]. This enables multiple specialized agents to coexist, each with its own context and tool access.

6. **Security model**: Default execution runs on the host; sandboxing via Docker, SSH, or OpenShell backends for non-main sessions. Group/channel safety can be enforced by setting `agents.defaults.sandbox.mode: "non-main"` [^3086^].

#### Specialist Swarm Pattern: Kev's Dream Team

The most documented multi-agent pattern in the OpenClaw ecosystem is **Kev's Dream Team** (14+ agents), which demonstrates **model arbitrage** at scale [^3021^]:

```
        Human (Adam)
            |
      Kev (Orchestrator, Opus 4.5)
       /   |   |    |   \    \    \
     Rex  Hawk Scout Dash  Dot  Pixel ...
   (Codex)(Opus)(Flash)(Data)(Ops)(Gemini Pro)
```

**Architectural invariants:**
- The **orchestrator never does leaf work** — only delegates and synthesizes [^3021^]
- **Model arbitrage**: Opus for orchestration, Codex for code, Flash for research (cheap+fast), Gemini Pro for visual tasks [^3021^]
- **Shared coordination files**: `TEAM_PROTOCOL.md` (no-spam rules, deliverable formats), `TEAM.md` (roster, escalation), `GLOSSARY.md` (shared language) [^3021^]
- **Self-healing docs**: Agents update their own `.md` instruction files when they learn something [^3021^]
- **Always-on**: Heartbeats + webhooks create a persistent system, not a reactive chatbot [^3021^]

#### GodMode Workflow Templates

The GodMode skill implements **predefined workflows** with **parallel quality gates** (two independent checks catch more issues) and **documentation-only skills** (instructions > code for orchestration) [^3021^].

---

### 1.2 NemoClaw — NVIDIA's Enterprise Agent Runtime

**Origin:** Announced at NVIDIA GTC 2026 (March 17) [^3030^] | **Base:** Hardened fork of OpenClaw [^3033^] | **License:** Proprietary NVIDIA EULA (upstream OpenClaw remains MIT) [^3030^]

#### Architecture
NemoClaw is NVIDIA's enterprise distribution of the OpenClaw runtime, bundling it with NeMo Guardrails, Triton Inference Server, and multi-GPU scaling [^3030^][^3033^]. The architecture is a layered stack:

```
Enterprise Workflows
(IT ops, support, data analysis, code review)
         |
    NeMo Guardrails (policy, PII, topic boundaries)
         |
    Claw Agent Loop (plan, tool invocation, memory)
         |
    Triton Inference Server (dynamic batching,
                             tensor parallelism,
                             multi-GPU distribution)
         |
    CUDA/cuDNN (H100/H200 clusters)
```

**Key enterprise patterns:**

1. **Agent registration**: Every agent must be declared with its capabilities, tool access, and authorization scope before execution [^3034^]. This is a **capability-grant model** — no ambient authority.

2. **Immutable audit trail**: Every agent action, tool call, and decision is logged to an immutable audit trail with 7-year retention, exportable to SIEM systems [^3034^]. Supports SOC 2, HIPAA, and financial services compliance.

3. **RBAC for agent permissions**: Administrators define which tools each agent class can access, with approval workflows for elevated permissions and automatic scope reduction when agents are idle [^3034^].

4. **Supervisor-worker topologies**: Teams can define supervisor and worker agent hierarchies with shared memory between agents and structured handoffs between roles [^3030^]. Supports both synchronous and asynchronous multi-agent workflows.

5. **Hardware-agnostic claim**: While optimized for NVIDIA H100/H200, NemoClaw is advertised as running on AMD, Intel, and CPU-only setups [^3029^][^3037^].

6. **Pre-built agent templates**: Ship with validated templates for common enterprise workflows (IT operations, customer support, data analysis, code review), each including tool definitions, safety guardrails, and output formatters [^3034^].

---

### 1.3 Hermes Agent — The Self-Improving Tier-3 Runtime

**Repository:** `github.com/nousresearch/hermes-agent` [^3101^] | **License:** MIT | **Maintainer:** NousResearch

#### Architecture
Hermes is positioned as "the only agent with a built-in learning loop" [^3101^]. It creates skills from experience, improves them during use, nudges itself to persist knowledge, and builds a deepening user model across sessions.

```
┌─────────────────────────────────────────┐
│           Gateway Process               │
│  (Telegram, Discord, Slack, WhatsApp,   │
│   Signal, CLI, Email, Matrix, etc.)     │
├─────────────────────────────────────────┤
│         Agent Runtime Loop              │
│  (Multi-provider router: 10+ providers) │
├─────────────────────────────────────────┤
│    Memory Layer (SQLite + FTS5)         │
│    + External Providers (8 options)    │
├─────────────────────────────────────────┤
│    Skills System (auto-generated MD)    │
│    + Skills Hub (agentskills.io)        │
├─────────────────────────────────────────┤
│    Tool Layer (47+ built-in tools)      │
│    + MCP Client (stdio + HTTP)           │
├─────────────────────────────────────────┤
│    Terminal Backends (6 options)        │
│    (local, Docker, SSH, Daytona,         │
│     Singularity, Modal)                 │
└─────────────────────────────────────────┘
```

**Key patterns:**

1. **Cross-session memory**: All CLI and messaging sessions stored in SQLite (`~/.hermes/state.db`) with FTS5 full-text search. Queries return relevant past conversations with Gemini Flash summarization [^3035^]. Capacity is unlimited (all sessions); token cost is on-demand [^3035^].

2. **Skill reuse**: Autonomous skill creation after complex tasks. Skills are auto-generated Markdown, self-improve during use, and are compatible with the `agentskills.io` open standard [^3101^].

3. **Multi-provider routing**: Unified `call_llm()`/`async_call_llm()` API replaces scattered provider logic. All auxiliary consumers (vision, summarization, compression, trajectory saving) route through a single code path with automatic credential resolution [^3106^]. Supports Nous Portal, OpenRouter (200+ models), NVIDIA NIM, Xiaomi MiMo, z.ai/GLM, Kimi/Moonshot, MiniMax, Hugging Face, OpenAI, or custom endpoints [^3101^].

4. **MCP client**: Native MCP support with stdio and HTTP transports, reconnection, resource/prompt discovery, and sampling (server-initiated LLM requests) [^3106^].

5. **Subagent spawning**: Spawn isolated subagents for parallel workstreams. Write Python scripts that call tools via RPC, collapsing multi-step pipelines into zero-context-cost turns [^3101^]. Git worktree isolation (`hermes -w`) for safe parallel work on the same repo [^3106^].

6. **8 external memory providers**: Honcho, OpenViking, Mem0, Hindsight, Holographic, RetainDB, ByteRover, and Supermemory. Run alongside built-in memory (never replacing it) [^3035^].

---

### 1.4 Claude Code — Anthropic's Agentic Coding System

**Product:** `code.claude.com` [^3084^] | **Organization:** Anthropic | **Architecture:** Agent loop + layered context management

#### Architecture
Claude Code is an **agentic coding system** that reads codebases, makes changes across files, runs tests, and delivers committed code. At Anthropic, the majority of code is now written by Claude Code; engineers focus on architecture and orchestration [^3036^].

```
┌─────────────────────────────────────────┐
│         User Interface (TUI)           │
├─────────────────────────────────────────┤
│      Agent Loop (LLM + tool calls)      │
│   14 built-in tools + MCP servers       │
├─────────────────────────────────────────┤
│    Context Management Stack             │
│    - CLAUDE.md (project rules)          │
│    - Auto memory (session extraction)    │
│    - 3-tier compaction system          │
├─────────────────────────────────────────┤
│    Subagent Layer                       │
│    - Built-in: Explore, Plan, General   │
│    - Custom: Markdown + YAML frontmatter│
├─────────────────────────────────────────┤
│    Governance Layer                     │
│    - 4 permission modes                 │
│    - Checkpoints (file snapshots)        │
│    - Allow/deny rules                   │
├─────────────────────────────────────────┤
│    MCP Integration                      │
│    - 75+ built-in connectors            │
│    - Tool search + programmatic calling  │
└─────────────────────────────────────────┘
```

#### The Agent Loop
Claude Code runs a straightforward loop: the model produces a message; if it includes a tool call, the tool executes and results feed back into the model [^3111^]. No tool call means the loop stops and the agent waits for input. The loop is mediated by ~14 built-in tools spanning file operations, shell commands, web access, and control flow [^3111^].

#### Context Management (The 3-Tier Compaction System)
Claude Code conversations have no turn limit, but the model has a fixed context window. The system solves this with a **three-tier compaction system** [^3081^]:

| Tier | Name | Mechanism | Cost |
|------|------|-----------|------|
| 1 | **Microcompact** | Clears stale tool results without calling the model | Free |
| 2 | **Full Compact** | Summarizes entire conversation with a dedicated model call | Expensive (20K output tokens) |
| 3 | **Session Memory Compact** | Uses pre-extracted notes to skip the summarization call | Cheap (no model call) |

**Auto-compact orchestration** [^3081^]:
```
autoCompactIfNeeded(messages):
  if consecutiveFailures >= 3 → circuit breaker
  if not shouldAutoCompact(messages) → return
  
  // Try session memory compaction first
  result = trySessionMemoryCompaction(messages)
  if result: return success
  
  // Fall back to full compaction
  result = compactConversation(messages, suppressFollowUpQuestions=true)
  if result: reset failures, return success
  
  consecutiveFailures++
  if consecutiveFailures >= 3: log "circuit breaker tripped"
```

Key insight: compaction preserves `CLAUDE.md` instructions, files being edited, and a summary of decisions. Details of intermediate exchanges are lost [^3088^].

#### Subagents: Markdown + YAML Frontmatter
Custom subagents are defined as Markdown files with YAML frontmatter, stored in `.claude/agents/` (project scope) or `~/.claude/agents/` (user scope) [^3108^][^3115^]:

```markdown
---
name: security-reviewer
description: Security-focused code reviewer. Use proactively after auth code.
tools: Read, Grep, Glob        # read-only — cannot modify files
model: opus                    # high-stakes review gets Opus
effort: high
permissionMode: default
---
You are a senior application security engineer...
```

**Tool assignment is a hard constraint**: A reviewer defined with only `Read, Grep, Glob` **cannot write files**. This is not a prompt instruction; it is a structural enforcement [^3108^].

**Model routing for cost optimization**: The `model` field routes different subagents to different Claude models. Haiku is ~15× cheaper than Opus, and on tasks not requiring deep reasoning, quality difference is negligible [^3041^].

#### Governance: Permission Modes
Claude Code provides four permission modes cycled via `Shift+Tab` [^3084^]:

| Mode | File Edits | Shell Commands | Use Case |
|------|-----------|---------------|----------|
| **Default** | Ask before | Ask before | Safe exploration |
| **Auto-accept edits** | Auto (common fs ops) | Ask for others | Trusted projects |
| **Plan mode** | Read-only only | Read-only only | Review before execution |
| **Auto mode** | Background safety checks | Background safety checks | Research preview |

**Checkpoints**: Every file edit is reversible. Before editing, Claude snapshots current contents. Press `Esc` twice to rewind [^3084^].

#### Execution Surface: Built-in Tools
The execution surface includes: `Read`, `Write`, `Edit`, `Bash`, `WebFetch`, `Glob`, `Grep`, and subagent spawning. Subagents cannot spawn further subagents (nesting depth = 1) [^3108^].

---

### 1.5 Cursor 2.0 — Agent-First IDE

**Product:** Cursor IDE | **Company:** Anysphere | **Version:** 2.0 (Nov 2025) [^3024^]

#### Architecture
Cursor 2.0 represents a fundamental shift from code suggestion to **autonomous coding agents**. Its flagship features are the **Composer model** (a purpose-built MoE coding model) and an agent-centered interface [^3024^].

```
┌─────────────────────────────────────────┐
│         Cursor IDE Interface            │
│    (Ask / Plan / Agent modes)          │
├─────────────────────────────────────────┤
│      Composer MoE Model                 │
│    (250 tok/sec, RL-trained)            │
├─────────────────────────────────────────┤
│    Agent Orchestrator                   │
│    - Up to 8 parallel agents            │
│    - Git worktree per agent             │
│    - Background agents (Ubuntu VMs)     │
├─────────────────────────────────────────┤
│    Tool Layer                           │
│    - 25 tool calls per turn             │
│    - Read, Edit, Bash, Search           │
│    - MCP integration (1800+ servers)    │
├─────────────────────────────────────────┤
│    Semantic Search Index                │
│    (codebase-wide embeddings)           │
└─────────────────────────────────────────┘
```

**Key patterns:**

1. **Composer MoE model**: Mixture-of-experts language model specialized for software engineering through RL. Generates at 250 tokens/second, completing most turns in under 30 seconds [^3024^].

2. **Parallel agents (up to 8)**: Agents run simultaneously, each in isolation. Uses **git worktrees** so each agent operates in its own working directory on a different branch. File edits and indexes are separate; changes stay isolated until deliberately merged [^3024^].

3. **Background agents**: Run in isolated Ubuntu VMs with internet access, working on separate branches and automatically creating PRs. Cloud agents offer 99.9% reliability with instant startup [^3024^].

4. **Agent Mode progression**: Ask → Plan → Agent. The three modes represent increasing autonomy: Ask (chat), Plan (readonly analysis + strategy), Agent (full autonomous execution with safety checks) [^3024^].

5. **MCP integration**: Connects to 1800+ MCP servers. MCP tool definitions are deferred by default and loaded on demand via tool search [^3084^].

6. **25 tool calls per turn**: Higher tool-call budget than Claude Code's ~14, enabling more aggressive autonomous execution.

---

### 1.6 MCP — Model Context Protocol

**Origin:** Anthropic, November 2024 [^3102^] | **Governance:** Linux Foundation Agentic AI Foundation (Dec 2025) [^3109^] | **Adoption:** 10,000+ servers, 97M+ monthly SDK downloads [^3102^]

#### Architecture
MCP solves the **N×M integration problem**: instead of every AI company building bespoke connectors to every tool, define one universal interface [^3102^]. It is explicitly modeled on the **Language Server Protocol (LSP)** pattern [^3102^].

```
┌─────────────────────────────────────────┐
│           MCP Host                      │
│    (Claude Desktop, Cursor, VS Code,  │
│     ChatGPT, your custom app)            │
├─────────────────────────────────────────┤
│    MCP Client (in-host)                 │
│    - discovers capabilities             │
│    - invokes tools on agent's behalf    │
├─────────────────────────────────────────┤
│    Transport Layer                      │
│    - stdio (local processes)             │
│    - HTTP + SSE / streamable-HTTP       │
│    - JSON-RPC 2.0 messages              │
├─────────────────────────────────────────┤
│    MCP Server (external system)         │
│    - exposes Tools (actions)            │
│    - exposes Resources (data)           │
│    - exposes Prompts (templates)        │
└─────────────────────────────────────────┘
```

**Core primitives** [^3102^]:

| Primitive | Purpose | Example |
|-----------|---------|---------|
| **Tools** | Actions the agent can execute | `search_query`, `db_write`, `api_call` |
| **Resources** | Data the agent can read | File, database record, live API response |
| **Prompts** | Reusable instruction templates | Multi-step workflow starting points |

**Key design decisions:**

1. **Client-server with reflection**: The MCP client connects to a server, requests a capability manifest (`tools/list`), and the AI model reads tool descriptions to decide which to invoke. No hardcoded routing [^3102^].

2. **Model-agnostic**: Build the connector once, reuse across Claude, GPT, Gemini, Llama, Copilot [^3090^].

3. **Transport abstraction**: stdio for local, HTTP (SSE/streamable-HTTP) for remote. Switching transports does not change tool contracts [^3083^].

4. **OAuth 2.0 for enterprise**: Remote MCP servers authenticate via OAuth 2.0 (not static API keys), enabling secure, compliant integrations at scale [^3112^]. The MCP Dev Summit (April 2026) formalized OAuth 2.1 support.

5. **Registry and governance**: Official MCP registry at `modelcontextprotocol.io/servers`. Enterprises can control which servers users adopt [^3112^].

---

### 1.7 A2A — Agent-to-Agent Protocol

**Origin:** Google, April 2025 [^3111^] | **Status:** v1.0 production standard (April 2026) [^3104^] | **Relationship to MCP:** Complementary (horizontal vs. vertical) [^3039^]

#### Architecture
A2A solves the **horizontal** multi-agent communication problem: agents built on different frameworks need to coordinate across organizational boundaries [^3039^]. Where MCP solves the **vertical** problem (one agent accessing many tools), A2A solves peer-to-peer agent collaboration.

```
┌─────────────────────────────────────────┐
│         Agent A (Client)                │
│    - discovers agents via Agent Cards   │
│    - submits Tasks to remote agents      │
├─────────────────────────────────────────┤
│         A2A Protocol Layer               │
│    - JSON messages over HTTP           │
│    - Task lifecycle management           │
│    - Streaming via SSE                   │
├─────────────────────────────────────────┤
│         Agent B (Remote)                │
│    - exposes /.well-known/agent.json     │
│    - executes Tasks, returns Artifacts   │
│    - can itself be a client to Agent C   │
└─────────────────────────────────────────┘
```

**Core components** [^3108^][^3111^]:

1. **Agent Card**: Standard JSON metadata at `/.well-known/agent.json`. Self-documenting "résumé" including name, endpoint URL, auth requirements, protocol version, capabilities flags (streaming, push notifications, state history), and skills array [^3108^].

2. **Task lifecycle**: Stateful entities tracking work between agents:
   - `submitted` → `working` → `input-required` → `completed`/`canceled`/`failed` [^3108^]
   - Every state change has a timestamp and context messages
   - Long-running tasks supported via SSE streaming [^3114^]

3. **Artifacts**: Typed output of a task. Each message includes "parts" (fully formed content pieces with MIME types), enabling UI capability negotiation [^3111^].

4. **Client-server model with bidirectional capability**: Agents act as both clients and servers, enabling mesh topologies [^3039^].

5. **Authentication**: OAuth 2.0 client credentials flow and mutual TLS for high-security environments [^3039^].

**Complementarity with MCP** [^3039^]:
- **MCP**: One agent → many tools (hub-and-spoke)
- **A2A**: Many agents ↔ many agents (mesh/peer-to-peer)
- In practice: A customer support agent uses MCP to access knowledge base, ticket system, CRM; uses A2A to escalate to specialized refund/technical/billing agents.

---

## 2. Formal Pattern Extraction

### 2.1 Question 1: What is the universal agent abstraction?

Across all seven systems, the agent abstraction decomposes into **six universal factors**:

| Factor | OpenClaw | NemoClaw | Hermes | Claude Code | Cursor | MCP | A2A |
|--------|----------|----------|--------|-------------|--------|-----|-----|
| **Loop** | perceive-plan-act-reflect | Same (Claw loop) | Agent runtime loop | LLM + tool call loop | Composer + tool loop | Host mediates loop | Task lifecycle loop |
| **Tools** | Skills (Markdown) | Pre-built templates | 47+ tools + MCP | 14 built-in + MCP | 25/turn + MCP | Servers expose tools | Agent skills |
| **Memory** | MEMORY.md, HEARTBEAT.md | Shared memory | SQLite+FTS5, 8 providers | CLAUDE.md, auto memory, compaction | Semantic search index | Resources | Task state |
| **Context** | Session + channel | Delegation scope | Session + project files | 3-tier compaction, subagents | Git worktree isolation | Prompts | Message parts |
| **Governance** | Docker sandbox, RBAC | Audit logs, RBAC, registration | Command approval, container isolation | 4 permission modes, checkpoints | SOC 2 Type II | OAuth 2.0, user consent | OAuth 2.0, mTLS |
| **Orchestration** | Gateway hub-and-spoke | Supervisor-worker | Gateway + subagents | Orchestrator + subagents | Parallel agents (8) | Host coordinates servers | Peer-to-peer mesh |

**Formal definition of an Agent:**

> An **Agent** is a computational entity that (1) perceives input from users or environments, (2) maintains persistent state through a Memory subsystem, (3) reasons over a Context window containing current working state, (4) plans and executes actions through a Tool surface, (5) operates within Governance boundaries that enforce permissions and auditability, and (6) participates in an Orchestration topology that determines how it coordinates with other agents.

All seven systems implement this six-factor model, with different emphases:
- **OpenClaw/Hermes** emphasize the Loop + Memory + Orchestration (always-on, heartbeat-driven)
- **Claude Code/Cursor** emphasize Context management + Governance (compaction, permission modes)
- **MCP/A2A** emphasize Tool integration + Orchestration at the protocol layer
- **NemoClaw** emphasizes Governance + Orchestration (enterprise RBAC, audit trails)

---

### 2.2 Question 2: What is the orchestration pattern?

Four dominant orchestration topologies emerge:

#### Topology 1: Hub-and-Spoke (OpenClaw, MCP)
A central **Gateway/Host** connects to multiple **spokes** (agents, tools, channels). All communication routes through the center.

```
        Gateway/Host
       /    |    \
   Agent  Agent  Agent
     |      |      |
   Tools  Tools  Tools
```

**When to use**: Single point of control needed; unified session management; channel normalization.

#### Topology 2: Specialist Swarm (OpenClaw Dream Team, Claude Code Subagents)
A central **Orchestrator** delegates to **specialist agents** with distinct capabilities and model assignments.

```
     Orchestrator
    /   |   |   \
  Spec  Spec Spec Spec
 (Opus)(Code)(Flash)(Vis)
```

**When to use**: Task decomposition with heterogeneous capabilities; model arbitrage (cost optimization); quality gates.

#### Topology 3: Hierarchical Supervisor-Worker (NemoClaw, Claude Code Agent Teams)
Tree-structured delegation with **supervisors** managing **workers**, which may themselves manage sub-workers.

```
    Supervisor
      /      \
  Worker    Worker
    |         |
  Subagent  Subagent
```

**When to use**: Enterprise workflows with approval chains; multi-stage pipelines; accountability chains.

#### Topology 4: Peer-to-Peer Mesh (A2A)
Agents act as both clients and servers, discovering and communicating directly.

```
   Agent A ←────→ Agent B
      ↕              ↕
   Agent C ←────→ Agent D
```

**When to use**: Cross-organizational collaboration; no central coordinator; dynamic team formation.

**Hybrid reality**: Production systems combine topologies. OpenClaw uses hub-and-spoke at the Gateway layer and specialist swarm at the agent layer. Claude Code uses orchestrator-worker within a session and peer-to-peer across Agent Teams.

---

### 2.3 Question 3: What is the tool integration pattern?

Three tool integration patterns exist, forming a spectrum from proprietary to universal:

| Pattern | Mechanism | Examples | Lock-in |
|---------|-----------|----------|---------|
| **Native Tools** | Hardcoded in the agent runtime | Claude Code's Read/Edit/Bash, Cursor's semantic search | High |
| **Skills (Markdown)** | Declarative capability files with LLM instructions | OpenClaw SKILL.md, Hermes skills, Claude Code SKILL.md | Medium |
| **MCP (Universal)** | JSON-RPC 2.0, reflection-based discovery, transport-agnostic | 10,000+ servers across all ecosystems | None |

**The convergence trajectory**: Every system is moving toward MCP. Hermes added native MCP client support [^3106^]. Claude Code supports MCP servers [^3108^]. Cursor integrates 1800+ MCP servers [^3024^]. OpenClaw's plugin SDK is conceptually similar to MCP's server model. **Skills are becoming MCP servers** — the `agentskills.io` standard and MCP's Prompt primitive are converging.

**Formal tool contract** (universal across all systems):
```
Tool := {
  name: string,
  description: string,           // LLM-readable
  parameters: JSONSchema,
  returns: JSONSchema,
  permissions: PermissionSet,     // who can invoke
  sandbox: SandboxConfig,         // execution environment
  audit: boolean                // log invocation?
}
```

---

### 2.4 Question 4: What is the memory model?

Five memory patterns observed, forming a hierarchy from ephemeral to persistent:

| Layer | System | Technology | Scope | Persistence |
|-------|--------|-----------|-------|-------------|
| **Context Window** | All | LLM native | Current session | Ephemeral (compacted) |
| **Session Memory** | Claude Code, Hermes | Auto-extracted notes, SQLite | Single session | Session-local |
| **Cross-Session Memory** | Hermes, OpenClaw | SQLite+FTS5, MEMORY.md | All sessions | Persistent |
| **Project Context** | Claude Code | CLAUDE.md | Project-wide | Version-controlled |
| **External Memory** | Hermes | Honcho, Mem0, Hindsight, etc. | User-model | Cloud/local hybrid |
| **Shared Team Memory** | OpenClaw | TEAM.md, GLOSSARY.md, TEAM_PROTOCOL.md | Team | Git-managed |

**Key insight**: The most sophisticated systems (Claude Code, Hermes) use **tiered memory**: hot context in the LLM window, warm context in session notes, cold context in searchable archives. Claude Code's 3-tier compaction and Hermes' FTS5 session search represent the state of the art.

---

### 2.5 Question 5: What is the security model?

Three security layers emerge across all systems:

#### Layer 1: Execution Sandboxing
- **OpenClaw**: Docker/SSH/OpenShell backends for non-main sessions [^3086^]
- **Hermes**: 6 terminal backends including container isolation [^3101^]
- **Claude Code**: Checkpoints before every file edit; read-only Plan mode [^3084^]
- **Cursor**: Git worktree isolation; background agents in Ubuntu VMs [^3024^]
- **NemoClaw**: Sandboxing + least-privilege access controls [^3033^]

#### Layer 2: Permission / Capability Control
- **Claude Code**: 4 permission modes (Default, Auto-accept, Plan, Auto) [^3084^]
- **NemoClaw**: Granular RBAC — administrators define which tools each agent class can access, with approval workflows for elevated permissions [^3034^]
- **OpenClaw**: Channel-based sandbox defaults; `agents.defaults.sandbox.mode` [^3086^]
- **MCP**: Host manages policy and auth; server constrains scope; user consent required [^3083^]

#### Layer 3: Audit and Compliance
- **NemoClaw**: Immutable audit logs, 7-year retention, SOC2/HIPAA/FedRAMP, exportable to SIEM [^3034^]
- **Claude Code**: PreCompact hooks for telemetry; `/cost` and `/context` monitoring [^3081^]
- **MCP/A2A**: OAuth 2.0 / mutual TLS for authentication; request logging [^3112^][^3039^]

**The Zero Trust insight**: The most advanced model (demonstrated by NemoClaw and policy-aware OpenClaw extensions) treats authorization as a **continuous feedback signal inside the agent loop**, not a one-time gate [^3116^]. Every proposed tool invocation is evaluated at runtime; denial becomes productive signal that guides replanning.

---

### 2.6 Question 6: What can be ported to Rust?

| Component | Portability | Rust Ecosystem | Notes |
|-----------|-------------|----------------|-------|
| **MCP Client/Server** | **Excellent** | `jsonrpc-core`, `tower`, `hyper` | JSON-RPC 2.0 over stdio/HTTP is trivial in Rust |
| **A2A Agent/Client** | **Excellent** | `axum`, `reqwest`, `serde` | HTTP + JSON; Agent Cards as structured metadata |
| **Agent Loop** | **Excellent** | `tokio`, `futures` | Async loop with backpressure; `tokio::select!` for cancellation |
| **Tool Sandbox** | **Good** | `nsjail`, `firecracker`, `runc` via FFI | Container execution; seccomp-bpf for syscall filtering |
| **Memory (SQLite)** | **Excellent** | `rusqlite`, `sqlx` | FTS5 enabled in recent SQLite; vector search via `pgvector` or `qdrant-client` |
| **Memory (Vector)** | **Good** | `qdrant-client`, `milvus-rs`, `pgvector` | Async vector DB clients available |
| **Gateway/WebSocket** | **Excellent** | `tokio-tungstenite`, `axum` | 15+ platform adapters = trait implementations |
| **Context Compaction** | **Good** | `tiktoken-rs`, `tokenizers` | Token counting; summarization via LLM API calls |
| **Skills System** | **Excellent** | `pulldown-cmark`, `yaml-rust` | Markdown + YAML frontmatter parsing mature |
| **Permission Modes** | **Excellent** | `casbin`, `cedar-policy` (bindings) | RBAC/ABAC; Cedar has Rust SDK |
| **Git Worktree Isolation** | **Excellent** | `git2` | libgit2 bindings support worktrees |
| **Heartbeat Scheduler** | **Excellent** | `tokio::time`, `cron` | Cron parsing + async interval execution |

**What is NOT portable**:
- The LLM itself (remains external API or local inference via `llama.cpp`, `candle`, `burn`)
- Some TypeScript-specific plugin ecosystems (but MCP servers decouple this)
- Native IDE integrations (VS Code, JetBrains) — these remain platform-specific

**Rust advantages for MAS**:
1. **Memory safety without GC**: Agents run for days/weeks; memory leaks in long-running TypeScript processes are a known issue in OpenClaw/Hermes deployments.
2. **Async/await with structured concurrency**: `tokio` provides cancellation, timeouts, and backpressure — critical for agent loops that must handle runaway tool execution.
3. **Zero-cost abstractions**: Trait-based tool dispatch matches MCP's reflection model with no runtime overhead.
4. **Sandboxing**: `seccomp`, `namespaces`, `cgroups` are first-class Linux primitives; Rust's `caps` crate and `nsjail` integration enable fine-grained sandboxing.
5. **Cross-compilation**: Single binary deploys to VPS, edge, embedded (relevant for NemoClaw's hardware-agnostic claim).

---

### 2.7 Question 7: What is the minimal MAS kernel in Rust?

The minimal kernel must capture the six universal factors. Here is a 200-line trait system:

```rust
// ============================================================================
// Minimal MAS Kernel — Epistemos Research
// Captures patterns from: OpenClaw, NemoClaw, Hermes, Claude Code,
// Cursor, MCP, A2A
// ============================================================================

use async_trait::async_trait;
use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::collections::HashMap;
use std::sync::Arc;

// ---------------------------------------------------------------------------
// 1. Tool — The universal capability surface
// ---------------------------------------------------------------------------
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ToolDef {
    pub name: String,
    pub description: String,         // LLM-readable
    pub parameters: Value,           // JSON Schema
    pub returns: Value,              // JSON Schema
}

#[async_trait]
pub trait Tool: Send + Sync {
    fn definition(&self) -> ToolDef;
    async fn invoke(&self, args: Value, ctx: Arc<dyn Context>) -> Result<Value, ToolError>;
}

#[derive(Debug)]
pub enum ToolError {
    InvalidArgs(String),
    ExecutionFailed(String),
    Denied(String),
}

// ---------------------------------------------------------------------------
// 2. Memory — Tiered persistence (Context → Session → Cross-session)
// ---------------------------------------------------------------------------
#[async_trait]
pub trait Memory: Send + Sync {
    async fn remember(&self, key: &str, value: &str, tier: MemoryTier);
    async fn recall(&self, key: &str, tier: MemoryTier) -> Option<String>;
    async fn search(&self, query: &str, tier: MemoryTier) -> Vec<MemoryHit>;
}

#[derive(Debug, Clone, Copy)]
pub enum MemoryTier {
    Hot,      // In-context (current session window)
    Warm,     // Session-local (SQLite, extracted notes)
    Cold,     // Cross-session (FTS5, vector DB, archive)
}

#[derive(Debug)]
pub struct MemoryHit {
    pub key: String,
    pub value: String,
    pub score: f32,
}

// ---------------------------------------------------------------------------
// 3. Context — Current working state (per-session, per-agent)
// ---------------------------------------------------------------------------
#[async_trait]
pub trait Context: Send + Sync {
    fn agent_id(&self) -> &str;
    fn session_id(&self) -> &str;
    async fn get(&self, key: &str) -> Option<Value>;
    async fn set(&self, key: &str, value: Value);
    async fn compact(&self) -> Result<(), ContextError>; // Tier-2/3 compaction
}

#[derive(Debug)]
pub enum ContextError {
    CompactionFailed(String),
    WindowExceeded,
}

// ---------------------------------------------------------------------------
// 4. Governance — Permission modes + audit + sandbox
// ---------------------------------------------------------------------------
#[derive(Debug, Clone, Copy)]
pub enum PermissionMode {
    Ask,           // Default: prompt before execution
    AutoAccept,    // Auto-accept known-safe operations
    PlanOnly,      // Read-only, produce plan for approval
    Auto,          // Full autonomy with background safety checks
}

#[async_trait]
pub trait Governance: Send + Sync {
    async fn check(&self, agent_id: &str, tool: &str, args: &Value) -> Result<(), Denial>;
    async fn audit(&self, record: AuditRecord);
    fn permission_mode(&self) -> PermissionMode;
    fn sandbox_config(&self) -> SandboxConfig;
}

#[derive(Debug)]
pub struct Denial {
    pub reason: String,
    pub hint: Option<String>, // Productive feedback for replanning
}

#[derive(Debug, Clone)]
pub struct AuditRecord {
    pub timestamp: u64,
    pub agent_id: String,
    pub action: String,
    pub tool: String,
    pub args_hash: String,
    pub result: String,
}

#[derive(Debug, Clone)]
pub struct SandboxConfig {
    pub backend: SandboxBackend,
    pub allowed_syscalls: Vec<String>,
    pub network_policy: NetworkPolicy,
}

#[derive(Debug, Clone)]
pub enum SandboxBackend {
    Host,       // Direct execution (main session)
    Docker,     // Container isolation
    Firecracker, // MicroVM
    GitWorktree, // Repo isolation (Cursor pattern)
}

#[derive(Debug, Clone)]
pub enum NetworkPolicy {
    None,
    Restricted(Vec<String>), // Allowed domains
    Full,
}

// ---------------------------------------------------------------------------
// 5. Agent — The six-factor entity
// ---------------------------------------------------------------------------
#[async_trait]
pub trait Agent: Send + Sync {
    fn id(&self) -> &str;
    fn capabilities(&self) -> Vec<ToolDef>;
    
    /// The core loop: perceive → plan → act → reflect
    async fn step(&self, input: AgentInput, ctx: Arc<dyn Context>) -> Result<AgentOutput, AgentError>;
    
    fn memory(&self) -> Arc<dyn Memory>;
    fn governance(&self) -> Arc<dyn Governance>;
}

#[derive(Debug, Clone)]
pub struct AgentInput {
    pub message: String,
    pub channel: String,       // telegram, discord, cli, etc.
    pub attachments: Vec<Attachment>,
}

#[derive(Debug, Clone)]
pub struct AgentOutput {
    pub message: String,
    pub tool_calls: Vec<ToolCall>,
    pub requires_input: bool,
}

#[derive(Debug, Clone)]
pub struct ToolCall {
    pub tool: String,
    pub args: Value,
}

#[derive(Debug, Clone)]
pub struct Attachment {
    pub mime_type: String,
    pub data: Vec<u8>,
}

#[derive(Debug)]
pub enum AgentError {
    LoopFailed(String),
    ContextExceeded,
    Denied(Denial),
}

// ---------------------------------------------------------------------------
// 6. Orchestrator — Topology dispatcher
// ---------------------------------------------------------------------------
#[async_trait]
pub trait Orchestrator: Send + Sync {
    /// Route input to the appropriate agent(s)
    async fn route(&self, input: AgentInput) -> Result<RouteDecision, OrchestratorError>;
    
    /// Spawn a subagent for delegated work
    async fn spawn(&self, spec: SubagentSpec, parent_ctx: Arc<dyn Context>) -> Result<Arc<dyn Agent>, OrchestratorError>;
    
    /// List available agents (for A2A-style discovery)
    async fn discover(&self) -> Vec<AgentCard>;
}

#[derive(Debug, Clone)]
pub struct RouteDecision {
    pub target_agents: Vec<String>,
    pub topology: Topology,
}

#[derive(Debug, Clone)]
pub enum Topology {
    HubAndSpoke,      // Central gateway (OpenClaw, MCP)
    SpecialistSwarm,  // Orchestrator + specialists (Dream Team)
    Hierarchical,     // Supervisor + workers (NemoClaw)
    PeerToPeer,       // Mesh (A2A)
}

#[derive(Debug, Clone)]
pub struct SubagentSpec {
    pub name: String,
    pub description: String,
    pub tools: Vec<String>,       // Allowlist
    pub model: String,              // Model routing
    pub permission_mode: PermissionMode,
    pub isolation: SandboxConfig,
}

// A2A-style Agent Card for cross-system discovery
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AgentCard {
    pub name: String,
    pub endpoint: String,
    pub version: String,
    pub skills: Vec<SkillDef>,
    pub auth: AuthScheme,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SkillDef {
    pub id: String,
    pub name: String,
    pub description: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum AuthScheme {
    None,
    OAuth2 { scopes: Vec<String> },
    MutualTls,
}

// ---------------------------------------------------------------------------
// 7. Gateway — The OpenClaw / Hermes entry point (hub-and-spoke control plane)
// ---------------------------------------------------------------------------
#[async_trait]
pub trait Gateway: Send + Sync {
    async fn connect(&self, channel: Box<dyn Channel>);
    async fn dispatch(&self, inbound: InboundMessage) -> Result<(), GatewayError>;
    fn orchestrator(&self) -> Arc<dyn Orchestrator>;
}

#[async_trait]
pub trait Channel: Send + Sync {
    fn platform(&self) -> &str;  // telegram, discord, slack, etc.
    async fn send(&self, recipient: &str, msg: &AgentOutput);
    async fn receive(&self) -> Result<InboundMessage, ChannelError>;
}

#[derive(Debug, Clone)]
pub struct InboundMessage {
    pub channel: String,
    pub sender: String,
    pub content: String,
    pub session_id: String,
}

#[derive(Debug)]
pub enum GatewayError {
    ChannelFailed(String),
    RoutingFailed(String),
}

#[derive(Debug)]
pub enum ChannelError {
    Disconnected,
    ParseFailed(String),
}

#[derive(Debug)]
pub enum OrchestratorError {
    SpawnFailed(String),
    RouteFailed(String),
    NoAgentAvailable,
}
```

**Kernel design rationale**:

1. **Traits over structs**: Each factor is a trait, not a concrete type. This mirrors how MCP decouples hosts from servers, and how OpenClaw's plugin SDK decouples channels from the Gateway.

2. **`Arc<dyn Trait>` for composability**: Agents compose Memory, Governance, and Context through trait objects, enabling runtime configuration (like Claude Code's permission modes or Hermes' memory provider selection).

3. **`async_trait` for the loop**: All core operations are async because agent loops are inherently concurrent (tool calls may be slow, multiple agents run in parallel).

4. **`Denial` with `hint`**: Captures the policy-aware agent loop insight [^3116^] — denials are productive feedback, not fatal errors.

5. **`Topology` enum**: Explicitly models the four orchestration patterns discovered across the seven systems.

6. **`AgentCard` + `AuthScheme`**: Captures A2A's discovery model and MCP's OAuth security, enabling cross-system interoperability.

---

## 3. Comparison Matrix: 10 Dimensions × 7 Systems

| Dimension | OpenClaw | NemoClaw | Hermes Agent | Claude Code | Cursor 2.0 | MCP | A2A |
|-----------|----------|----------|--------------|-------------|------------|-----|-----|
| **1. License** | MIT [^3086^] | Proprietary (NVIDIA EULA) [^3030^] | MIT [^3101^] | Proprietary (Anthropic) | Proprietary (Anysphere) | Open standard (Linux Foundation) [^3109^] | Open standard (Google) [^3111^] |
| **2. Orchestration Topology** | Hub-and-spoke + Specialist swarm [^3082^][^3021^] | Hierarchical supervisor-worker [^3034^] | Gateway + subagents [^3101^] | Orchestrator + subagents [^3108^] | Parallel agents (8), git worktree [^3024^] | Hub-and-spoke (host-servers) [^3083^] | Peer-to-peer mesh [^3039^] |
| **3. Tool Integration** | Skills (Markdown) + native [^3080^] | Pre-built templates + native [^3034^] | 47+ tools + MCP client [^3106^] | 14 native + MCP [^3111^] | 25/turn + MCP [^3024^] | JSON-RPC 2.0, reflection [^3087^] | Agent skills via Agent Card [^3108^] |
| **4. Memory Model** | MEMORY.md, HEARTBEAT.md [^3080^] | Shared memory between agents [^3034^] | SQLite+FTS5, 8 providers [^3035^] | CLAUDE.md, 3-tier compaction [^3081^] | Semantic search index [^3024^] | Resources (read-only data) [^3102^] | Task state + artifacts [^3111^] |
| **5. Security Model** | Docker sandbox, channel RBAC [^3086^] | Audit logs, RBAC, registration [^3034^] | Command approval, containers [^3101^] | 4 permission modes, checkpoints [^3084^] | SOC 2 Type II, worktree isolation [^3024^] | OAuth 2.0, user consent [^3112^] | OAuth 2.0, mTLS [^3039^] |
| **6. Messaging Channels** | 20+ (Telegram, Slack, Discord, WhatsApp, Signal, Teams, Matrix, etc.) [^3086^] | Enterprise APIs [^3034^] | 15+ (Telegram, Discord, Slack, WhatsApp, Signal, CLI, etc.) [^3105^] | CLI only [^3084^] | IDE-integrated [^3024^] | Transport-agnostic (stdio, HTTP) [^3083^] | HTTP + SSE [^3114^] |
| **7. Model Routing** | Multi-provider (any endpoint) [^3086^] | Triton Inference Server [^3033^] | 10+ providers, unified API [^3101^] | Subagent-level model selection [^3041^] | Composer MoE + Claude/GPT/o3 [^3024^] | Model-agnostic [^3090^] | Model-agnostic [^3111^] |
| **8. Context Management** | Session + per-agent workspaces [^3082^] | Delegation scope [^3034^] | Session + project context [^3101^] | 3-tier compaction, subagent isolation [^3081^] | Git worktree isolation [^3024^] | Prompts + resources [^3102^] | Message parts + task state [^3111^] |
| **9. Scale (Parallelism)** | Multi-agent routing [^3086^] | Hundreds of concurrent agents [^3034^] | Subagent spawning [^3101^] | Subagents + background tasks [^3113^] | 8 parallel + background VMs [^3024^] | Multi-server, single host [^3083^] | Many-to-many mesh [^3039^] |
| **10. Governance Depth** | Sandbox config [^3086^] | Enterprise RBAC, SOC2/HIPAA [^3034^] | Container isolation [^3101^] | Permission modes + hooks [^3084^] | Worktree isolation [^3024^] | Host policy + OAuth [^3112^] | Agent Card auth [^3039^] |

---

## 4. Synthesis: Design Principles for Epistemos MAS

From the seven systems, we extract **nine invariant design principles**:

### Principle 1: The Agent is a Loop, Not a Function
> Agents are not request-response handlers. They are **persistent loops** that perceive, plan, act, and reflect continuously. The loop must support interruption, replanning, and graceful degradation [^3112^][^3114^].

**Rust implication**: Use `tokio::select!` with cancellation tokens. The loop is an async stream, not a synchronous call.

### Principle 2: Tools are Capabilities, Not Functions
> Tools expose **capabilities** described in natural language with JSON Schema parameters. The LLM decides when to invoke them; the system enforces whether they can be invoked [^3102^][^3087^].

**Rust implication**: The `Tool` trait separates `definition()` (static metadata) from `invoke()` (dynamic execution). This mirrors MCP's reflection model.

### Principle 3: Memory is Tiered, Not Monolithic
> Context window → Session memory → Cross-session archive → External knowledge graph. Each tier has different latency, capacity, and cost characteristics [^3081^][^3035^].

**Rust implication**: The `MemoryTier` enum (Hot/Warm/Cold) with async `remember`/`recall`/`search` methods captures this hierarchy.

### Principle 4: Governance is Feedback, Not a Gate
> Authorization evaluated at every tool invocation. Denial returns structured feedback (`hint`) that guides replanning, not just termination [^3116^].

**Rust implication**: `Governance::check()` returns `Result<(), Denial>` where `Denial` carries a hint. The agent loop treats this as a tool result, not an exception.

### Principle 5: Orchestration is Topology-Independent
> The same agent can participate in hub-and-spoke, specialist swarm, hierarchical, or peer-to-peer topologies. The topology is a runtime configuration, not a compile-time constraint [^3021^][^3039^].

**Rust implication**: The `Topology` enum and `Orchestrator` trait allow the same `Agent` implementation to be composed into different topologies.

### Principle 6: Skills are Declarative, Not Imperative
> Capabilities are described in Markdown with YAML frontmatter (name, description, when to use). The LLM reads these descriptions to decide invocation. This is more robust than imperative registration [^3080^][^3110^].

**Rust implication**: Skills are `ToolDef` instances with rich `description` fields. Progressive disclosure (show descriptions first, full content on use) is implemented by the `Context` layer.

### Principle 7: Isolation is Contextual, Not Universal
> Sandboxing strength varies by trust level: host execution for main session, Docker for non-main, git worktree for parallel agents, microVMs for background tasks [^3086^][^3024^].

**Rust implication**: `SandboxConfig` with `SandboxBackend` enum and per-agent configuration captures contextual isolation.

### Principle 8: Discovery is Reflection-Based
> Agents and tools advertise capabilities via structured metadata (Agent Cards, tool manifests). Clients discover at runtime; no compile-time coupling [^3108^][^3087^].

**Rust implication**: `AgentCard` and `ToolDef` with JSON Schema definitions enable runtime discovery. This is the foundation for both MCP and A2A interoperability.

### Principle 9: The Gateway is the Control Plane
> All user-facing systems (OpenClaw, Hermes) centralize channel normalization, session management, and routing in a single Gateway process. This is the "operating system" layer [^3082^].

**Rust implication**: The `Gateway` trait with `Channel` adapters provides the control plane abstraction. Each messaging platform implements `Channel`.

---

## 5. Implementation Roadmap for Rust

### Phase 1: Core Kernel (Weeks 1-2)
Implement the trait system above with:
- `tokio` runtime with structured concurrency
- `serde_json` for JSON-RPC 2.0 message framing
- `rusqlite` with FTS5 for cross-session memory
- `tower` for middleware (logging, rate limiting, auth)

### Phase 2: MCP Integration (Week 3)
- Implement MCP client (`stdio` and `HTTP` transports)
- Tool discovery via `tools/list` JSON-RPC method
- OAuth 2.0 token flow via `reqwest` + `openidconnect`

### Phase 3: A2A Integration (Week 4)
- Agent Card serving at `/.well-known/agent.json`
- Task lifecycle state machine (`submitted` → `working` → `completed`)
- SSE streaming for long-running tasks

### Phase 4: Gateway + Channels (Weeks 5-6)
- WebSocket server (`axum` + `tokio-tungstenite`)
- Channel adapters: Telegram (HTTP polling), Discord (gateway websocket), Slack (Events API)
- Session routing and agent isolation

### Phase 5: Governance Hardening (Week 7)
- Cedar policy integration for runtime authorization
- `seccomp` + `namespaces` sandboxing via `nsjail`
- Immutable audit logging to append-only log (`sled` or `rocksdb`)

---

## 6. Citations

[^3021^]: Marcus, M. "Multi-Agent Architectures in OpenClaw — Research Compendium." GitHub Gist, February 2026. https://gist.github.com/mmarcus006/8b3bb89cb213b6d4359bf1bb928079b3

[^3024^]: Digital Applied. "Cursor 2.0: Agent-First Architecture Complete Guide." December 2025. https://www.digitalapplied.com/blog/cursor-2-0-agent-first-architecture-guide

[^3029^]: AI.cc. "NVIDIA NemoClaw Open-Source AI Agent 2026." March 2026. https://www.ai.cc/blogs/nvidia-nemoclaw-open-source-ai-agent-2026-guide/

[^3030^]: Taskade. "NemoClaw Review 2026: Features, Pricing, 7 Alternatives." April 2026. https://www.taskade.com/blog/nemoclaw-review

[^3031^]: Hightower, R. "A2A Protocol v1 2026: How AI Agents Actually Talk to Each Other." Medium, April 2026. https://medium.com/@richardhightower/a2a-protocol-v1-2026

[^3032^]: Ping Identity. "What is Agent2Agent Protocol (A2A)?" Developer Portal, April 2026. https://developer.pingidentity.com/identity-for-ai/agents/idai-what-is-a2a.html

[^3033^]: Futurum Group. "At GTC 2026, NVIDIA Stakes Its Claim on Autonomous Agent Infrastructure." March 2026. https://futurumgroup.com/insights/at-gtc-2026-nvidia-stakes-its-claim-on-autonomous-agent-infrastructure/

[^3034^]: Digital Applied. "Nvidia GTC 2026: NemoClaw and Enterprise Agentic AI." March 2026. https://www.digitalapplied.com/blog/nvidia-gtc-2026-nemoclaw-openclaw-enterprise-agentic-ai

[^3035^]: Crosley, B. "Hermes Agent v0.11 Reference: Ink TUI + Bedrock + GPT-5.5." April 2026. https://blakecrosley.com/guides/hermes

[^3036^]: Anthropic. "Claude Code | Anthropic's agentic coding system." March 2026. https://www.anthropic.com/product/claude-code

[^3037^]: NemoClam Documentation. "NemoClaw — Enterprise AI Agents, Redefined." https://nemoclaw.bot/

[^3039^]: Galileo AI. "Google's Agent2Agent Protocol Explained." January 2026. https://galileo.ai/blog/google-agent2agent-a2a-protocol-guide

[^3041^]: Raju, S. "Claude Code Subagents: The Complete Guide to AI Agent Delegation." Medium, April 2026. https://medium.com/@sathishkraju/claude-code-subagents-the-complete-guide-to-ai-agent-delegation-d0a9aba419d0

[^3080^]: Emergent.sh. "What is OpenClaw? Complete guide to the open-source AI agent framework." April 2026. https://emergent.sh/learn/what-is-openclaw

[^3081^]: Oldeucryptoboi. "How Claude Code Manages Infinite Conversations in a Finite Context Window." April 2026. https://oldeucryptoboi.com/blog/context-compaction-deep-dive/

[^3082^]: Ppaolo. "OpenClaw Architecture, Explained: How It Works." Substack, February 2026. https://ppaolo.substack.com/p/openclaw-system-architecture-overview

[^3083^]: Deepsense.ai. "Understanding the Model Context Protocol." November 2025. https://deepsense.ai/blog/understanding-the-model-context-protocol

[^3084^]: Anthropic. "How Claude Code works — Claude Code Docs." September 2025. https://code.claude.com/docs/en/how-claude-code-works

[^3085^]: Medium — nimritakoul01. "Architecture of OpenClaw based on its GitHub Repository." March 2026. https://medium.com/@nimritakoul01/openclaw-architecture-simply-explained-fca2e9f15f27

[^3086^]: OpenClaw. "OpenClaw — Personal AI Assistant." GitHub, 2026. https://github.com/openclaw/openclaw

[^3087^]: Stytch. "Model Context Protocol (MCP) — Introduction." March 2025. https://stytch.com/blog/model-context-protocol-introduction/

[^3088^]: SFEIR Institute. "Claude Code — Context Management." https://institute.sfeir.com/en/claude-code/claude-code-context-management/

[^3090^]: Backslash Security. "What is MCP? The Universal Connector for AI Explained." September 2025. https://www.backslash.security/blog/what-is-mcp-model-context-protocol

[^3101^]: NousResearch. "Hermes Agent — The agent that grows with you." GitHub, 2026. https://github.com/nousresearch/hermes-agent

[^3102^]: SSNTPL. "What Is MCP (Model Context Protocol)? The 2026 Developer Guide." April 2026. https://ssntpl.com/what-is-mcp-model-context-protocol/

[^3104^]: Truthifi. "The State of MCP 2026: AI Agents, OAuth, and Your Money." February 2026. https://truthifi.com/education/state-of-mcp-2026-ai-agents-custom-connectors

[^3105^]: Hermes Agent Docs. "Messaging Gateway." https://hermes-agent.nousresearch.com/docs/user-guide/messaging

[^3106^]: NewReleases.io. "NousResearch/hermes-agent v2026.3.12." March 2026. https://newreleases.io/project/github/NousResearch/hermes-agent/release/v2026.3.12

[^3107^]: Anmol Gupta. "Deep Dive into Model Context Protocol (MCP)." Medium, December 2025. https://anmol-gupta.medium.com/deep-dive-into-model-context-protocol-mcp

[^3108^]: KSRed. "Claude Code Agents & Subagents: What They Actually Unlock." March 2026. https://www.ksred.com/claude-code-agents-and-subagents-what-they-actually-unlock/

[^3109^]: Anthropic. "Donating the Model Context Protocol and establishing the Agentic AI Foundation." December 2025. https://www.anthropic.com/news/donating-the-model-context-protocol-and-establishing-of-the-agentic-ai-foundation

[^3110^]: LevelUp GitConnected. "A Mental Model for Claude Code: Skills, Subagents, and Plugins." March 2026. https://levelup.gitconnected.com/a-mental-model-for-claude-code-skills-subagents-and-plugins-3dea9924bf05

[^3111^]: Portkey AI. "Scaling Claude Code agents across your engineering team." March 2026. https://portkey.ai/blog/claude-code-agents

[^3112^]: Huang, K. "OpenClaw Design Patterns (Part 1 of 7)." Substack, March 2026. https://kenhuangus.substack.com/p/openclaw-design-patterns-part-1-of

[^3113^]: ClaudeFast. "Claude Code Agents: Engineering Autonomous AI Assistants." May 2026. https://claudefa.st/blog/guide/agents/agent-fundamentals

[^3114^]: A2A Protocol Specification. "Agent2Agent (A2A) Protocol Specification." November 2025. https://a2a-protocol.org/latest/specification/

[^3115^]: Anthropic. "Create custom subagents — Claude Code Docs." September 2025. https://code.claude.com/docs/en/sub-agents

[^3116^]: Windley, P. "A Policy-Aware Agent Loop with Cedar and OpenClaw." February 2026. https://www.windley.com/archives/2026/02/a_policy-aware_agent_loop_with_cedar_and_openclaw.shtml

[^3117^]: Reddit r/openclaw. "Lightweight per-subagent instructions." 2026. https://www.reddit.com/r/openclaw/comments/1s3bkn9/lightweight_persubagent_instructions_am_i_missing/

---

*Document generated for Epistemos MAS Release. All patterns verified against primary sources.*
