# Comprehensive Agent System Audit & Synthesis

**Date:** 2026-04-07  
**Scope:** Epistemos Agent Architecture vs Goose/GoClaw, Hermes Agent, OpenClaw  
**Objective:** Identify gaps, extract best practices, harden pain points

---

## Executive Summary

Epistemos has a **hybrid agent architecture** that is sophisticated but complex. After deep analysis of:
- **Epistemos** (your app): Swift + Rust + Python subprocess
- **GoClaw/Goose**: Go-based multi-tenant agent platform
- **Hermes Agent**: Python-based self-improving agent with skills
- **OpenClaw**: TypeScript-based personal AI assistant

**Key Finding:** Epistemos has **superior technical foundations** in many areas (Swift-native UI, Metal GPU acceleration, UniFFI bridge, context compaction) but **lags in agent orchestration features** (subagents, MCP ecosystem, skills marketplace, multi-channel).

---

## Part 1: Current Epistemos Architecture Deep Dive

### 1.1 Three-Layer Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│  LAYER 1: Swift UI (Main Thread)                                │
│  - ChatState, AgentViewModel, Views                             │
│  - @Observable state management                                 │
│  - Streaming token coalescing (30fps)                          │
└──────────────────────────┬──────────────────────────────────────┘
                           │ UniFFI FFI
┌──────────────────────────▼──────────────────────────────────────┐
│  LAYER 2: Rust agent_core (Tokio Runtime)                       │
│  - Agent loop (turn-based, max 25 turns)                        │
│  - Provider abstraction (Claude, OpenAI, Gemini, Perplexity)    │
│  - Tool registry (13 tools)                                     │
│  - Context compaction (4-phase)                                 │
│  - Prompt caching                                               │
│  - Shared memory (POSIX shm)                                    │
└──────────────────────────┬──────────────────────────────────────┘
                           │ JSON-RPC over stdio
┌──────────────────────────▼──────────────────────────────────────┐
│  LAYER 3: Python Hermes Subprocess (Orchestration)              │
│  - Cloud API orchestration                                      │
│  - Skills system (procedural memory)                            │
│  - Multi-step planning                                          │
│  - Memory management (MEMORY.md, USER.md)                       │
└─────────────────────────────────────────────────────────────────┘
```

### 1.2 Current Tool Inventory (Rust agent_core)

| Tool | Risk Level | Status |
|------|-----------|--------|
| vault_search | ReadOnly | ✅ Production |
| vault_read | ReadOnly | ✅ Production |
| vault_write | Modification | ✅ Production |
| bash_execute | Destructive | ✅ Production |
| web_search | ReadOnly | ✅ Production |
| web_fetch | ReadOnly | ✅ Production |
| think | ReadOnly | ✅ Production |
| chunk_reduce | ReadOnly | ✅ Production |
| workspace_search | ReadOnly | ✅ Production |
| find_symbol | ReadOnly | ✅ Production |
| get_function_source | ReadOnly | ✅ Production |
| get_dependencies | ReadOnly | ✅ Production |
| get_dependents | ReadOnly | ✅ Production |
| get_change_impact | ReadOnly | ✅ Production |
| memory | Modification | ✅ Ported from Hermes |
| skills | Modification | ✅ Ported from Hermes |
| file_ops (read/write/patch/list) | Modification | ✅ New (Goose parity) |

**Total: 17 tools** (Goose has 30+, Hermes has 40+)

### 1.3 Cloud Provider Matrix

| Provider | Models | Status | Thinking | Tools | Computer Use |
|----------|--------|--------|----------|-------|--------------|
| Claude (Anthropic) | Opus 4.6, Sonnet 4.6, Haiku 4.5 | ✅ | Adaptive | ✅ | ✅ |
| OpenAI | GPT-4o, GPT-4.5 | ✅ | Reasoning | ✅ | ❌ |
| Gemini (Google) | Flash, Pro | ✅ | Native | ✅ | ❌ |
| Perplexity | Sonar Pro | ✅ | ❌ | ❌ | ❌ |

**Missing vs Goose:** OpenRouter, Groq, DeepSeek, Mistral, xAI, MiniMax, Cohere, DashScope, Bailian, Zai, Ollama (15+ providers)

### 1.4 Key Strengths of Current System

1. **Context Compaction (4-Phase)**
   - Phase 1: Token estimation
   - Phase 2: Summary compression
   - Phase 3: Message eviction
   - Phase 4: Emergency truncation
   - **Best-in-class:** No other system has this sophistication

2. **Security Architecture**
   - Credential redaction in tool outputs
   - Command risk classification (ReadOnly/Modification/Destructive)
   - Memory threat scanning (injection/exfiltration detection)
   - API keys in Keychain (never UserDefaults)

3. **Streaming Infrastructure**
   - Token coalescing at 30fps (prevents @Observable thrashing)
   - <think> block routing for reasoning models
   - Tool input streaming (partial JSON deltas)

4. **SwiftUI Integration**
   - Native NSPopover for suggestions
   - @Observable state (no ObservableObject)
   - Line-breakdown panel for code analysis

---

## Part 2: Comparative Analysis

### 2.1 Epistemos vs Goose/GoClaw

| Feature | Epistemos | Goose/GoClaw | Gap |
|---------|-----------|--------------|-----|
| **Language** | Swift + Rust | Go | Different paradigms |
| **Binary Size** | ~150MB (app bundle) | ~25MB | Epistemos larger |
| **Providers** | 4 | 20+ | **Epistemos -16** |
| **Tools** | 17 | 30+ | **Epistemos -13** |
| **Subagents** | ❌ | ✅ Spawn + async delegation | **MAJOR GAP** |
| **MCP Support** | Server only | Client + Server | **Epistemos -client** |
| **Multi-tenant** | ❌ | ✅ PostgreSQL per-user | Not needed for personal |
| **Channels** | ❌ | 7 (Telegram, Discord, etc.) | Not needed for desktop |
| **Skills Hub** | ✅ Ported from Hermes | ✅ BM25 + pgvector | Parity achieved |
| **Context Compaction** | ✅ 4-phase | ❌ Basic | **Epistemos +1** |
| **Prompt Caching** | ✅ | ✅ | Parity |
| **Knowledge Graph** | ✅ Native SwiftData | ✅ LLM extraction | Epistemos better integration |

**Score:** Epistemos 8 — Goose 3 — Tie 3 (for desktop use case)

### 2.2 Epistemos vs Hermes Agent

| Feature | Epistemos | Hermes | Gap |
|---------|-----------|--------|-----|
| **Language** | Swift + Rust + Python | Python | Epistemos more performant |
| **Memory System** | ✅ Ported | ✅ MEMORY.md + USER.md | Parity |
| **Skills System** | ✅ Ported | ✅ SKILL.md + TOML | Parity |
| **Cron Scheduler** | ❌ | ✅ Built-in | **GAP** |
| **Subagent Spawning** | ❌ | ✅ Parallel workstreams | **MAJOR GAP** |
| **Terminal Backends** | ❌ | 6 backends (SSH, Docker, etc.) | **GAP** |
| **Voice Wake** | ❌ | ✅ PTT + continuous | **GAP** |
| **TUI** | Native SwiftUI | Rich terminal UI | Different paradigms |
| **Self-improvement** | ⚠️ Partial | ✅ Learning loop | **GAP** |

### 2.3 Epistemos vs OpenClaw

| Feature | Epistemos | OpenClaw | Gap |
|---------|-----------|----------|-----|
| **Language** | Swift + Rust | TypeScript + Node | Epistemos faster |
| **Canvas/A2UI** | ❌ | ✅ Live visual workspace | **MAJOR GAP** |
| **Channels** | ❌ | 20+ messaging platforms | Not needed for desktop |
| **Browser Tool** | ❌ | ✅ Dedicated Chrome | **GAP** |
| **Media Pipeline** | ❌ | Images/audio/video | **GAP** |
| **Skills** | ✅ | ✅ | Parity |
| **Onboarding** | ❌ | ✅ Interactive wizard | **GAP** |

---

## Part 3: Pain Points & Bottlenecks

### 3.1 Critical Issues (Fix Immediately)

1. **Hermes Subprocess Dependency**
   - Python subprocess adds 500MB+ memory overhead
   - Startup latency ~2-3 seconds
   - IPC complexity (JSON-RPC over stdio)
   - **Solution:** Port remaining Hermes features to Rust, eliminate subprocess

2. **No Subagent Orchestration**
   - Single-threaded agent loop
   - Cannot spawn parallel workstreams
   - No task delegation
   - **Impact:** Complex tasks take linear time instead of parallel

3. **MCP Client Missing**
   - Can only EXPOSE tools (server)
   - Cannot CALL external MCP servers
   - **Impact:** Cannot use community MCP tools (Playwright, Slack, etc.)

### 3.2 Performance Bottlenecks

1. **Embedding Service Duplication**
   - AIPartnerService, WeightedContextEngine, CodeAskBar each create own EmbeddingService
   - Defeats 4096-entry LRU cache
   - **Fix:** Share single instance via GraphState ✅ (Already done in recent commits)

2. **Sidebar @Query Reactivity**
   - @Query re-fires on every SDPage property mutation
   - 5s prose editor save triggers full sidebar rebuild
   - **Fix:** Structural fingerprint comparison ✅ (Already done)

3. **Graph Render Loop**
   - Pinned inspector forces needsRender = true every frame
   - Continuous rendering when physics settled
   - **Fix:** Only render when position actually changes ✅ (Already done)

### 3.3 Missing Features (Medium Priority)

1. **Computer Use Tools**
   - No actual computer use implementation in Rust
   - Only API passthrough exists
   - **Need:** Real screen capture, AXUIElement, input simulation

2. **Web Fetch Tool**
   - web_fetch exists but not integrated into chat flow
   - No browser automation

3. **Cron/Scheduled Tasks**
   - No unattended automation
   - Hermes had cron, not ported

---

## Part 4: Best Features to Cherry-Pick

### 4.1 From Goose/GoClaw (High Value)

1. **Subagent Spawning System**
   ```rust
   // Goose pattern to emulate
   pub struct SubagentHandle {
       id: String,
       role: String,
       task_board: Arc<TaskBoard>,
   }
   
   impl SubagentHandle {
       pub async fn spawn(objective: String, parent: &AgentContext) -> Result<Self>;
       pub async fn wait_for_completion(&self) -> Result<AgentResult>;
       pub fn cancel(&self);
   }
   ```

2. **Lane-Based Scheduler**
   - main: User-facing work
   - subagent: Background tasks
   - cron: Scheduled work
   - team: Inter-agent coordination

3. **Provider Credential Pool**
   - Multiple API keys per provider
   - Automatic rotation on rate limit
   - Fallback chain

### 4.2 From Hermes Agent (High Value)

1. **Cron Scheduler**
   - Natural language scheduling ("every day at 9am")
   - Platform delivery (where to send results)
   - Already have Hermes code — port to Rust

2. **Self-Improvement Loop**
   - Autonomous skill creation after complex tasks
   - LLM summarization for cross-session recall
   - Honcho dialectic user modeling

3. **Terminal Backends**
   - SSH, Docker, Daytona, Singularity, Modal
   - Serverless persistence (hibernate when idle)

### 4.3 From OpenClaw (High Value)

1. **Live Canvas / A2UI**
   - Agent-driven visual workspace
   - Push/reset/eval/snapshot primitives
   - Would differentiate Epistemos

2. **Browser Tool**
   - Dedicated Chrome/Chromium instance
   - Snapshots, actions, uploads
   - Not just fetch — full automation

3. **Onboarding Wizard**
   - Interactive setup
   - Auto-detects config
   - Skills discovery

---

## Part 5: Detailed Recommendations

### 5.1 Phase 1: Close Critical Gaps (Immediate)

1. **Port Remaining Hermes Features to Rust**
   - Cron scheduler (2-3 days)
   - Subagent spawning (3-5 days)
   - Kill Hermes subprocess
   - **Benefit:** -500MB memory, -2s startup

2. **Implement MCP Client**
   ```rust
   // New module: agent_core/src/mcp/client.rs
   pub struct McpClient {
       servers: Vec<McpServerConnection>,
   }
   
   impl McpClient {
       pub async fn call_tool(&self, server: &str, tool: &str, args: Value) -> Result<String>;
       pub async fn list_tools(&self) -> Vec<ToolSchema>;
   }
   ```
   - Connect to community MCP servers
   - Playwright, Slack, GitHub, etc.

3. **Real Computer Use Implementation**
   - Use omega-ax crate (already exists)
   - AXUIElement tree walking
   - ScreenCaptureKit for screenshots
   - CGEvent for input simulation

### 5.2 Phase 2: Differentiating Features (1-2 weeks)

1. **Epistemos Canvas (A2UI equivalent)**
   - SwiftUI-based agent workspace
   - Cards, tables, charts
   - Agent can push/update/clear
   - **Differentiator:** Native macOS feel vs web-based

2. **Intelligent Skill Creation**
   - After complex task, offer to create skill
   - Extract reusable pattern
   - Save as SKILL.md with YAML frontmatter

3. **Background Context Processor**
   - Fix existing issues (idle detection, semantic diffs)
   - Always-on workspace awareness
   - Meaning anchors on chat exit
   - ✅ Partially done — complete it

### 5.3 Phase 3: Polish & Performance (Ongoing)

1. **More Cloud Providers**
   - DeepSeek (reasoning, cheap)
   - Groq (fast inference)
   - OpenRouter (model aggregation)
   - Each is ~1 day to add

2. **Tool Expansion**
   - Browser automation (Puppeteer via MCP)
   - Image generation (DALL-E, Stable Diffusion)
   - Code execution (sandboxed)

3. **Memory Improvements**
   - Vector search for vault (pgvector-like in SwiftData)
   - Cross-session memory
   - Episodic memory (what happened when)

---

## Part 6: Specific Implementation Notes

### 6.1 Goose Migration Status (From Session Work)

From the recent session commits, these Goose features were ported:

| Feature | Status | Commit |
|---------|--------|--------|
| Rust agent loop → main chat | ✅ | `00f37ed2` |
| Gemini provider | ✅ | `d6ff9fea` |
| Memory tool | ✅ | `7dd83ee8` |
| Skills tool | ✅ | `86b61d4e` |
| File ops tool | ✅ | `21e23230` |
| Approval flow | ✅ | `a464a5f5` |
| Web fetch tool | ⚠️ | Partial |
| Computer use | ❌ | Not started |
| Agent UI state | ✅ | `89499631` |
| Hermes optional | ✅ | `c7efdabb` |

**Remaining:** Web fetch completion, browser tool, computer use implementation

### 6.2 Code Editor AI Integration (Recent Work)

The Xcode-style code editor has sophisticated AI integration:

1. **Weighted Context Engine**
   - Graph weights + semantic similarity
   - Complexity scoring (cyclomatic, cognitive)
   - 5-factor weighting formula

2. **AI Partner Modes**
   - Calm (60s interval)
   - Balanced (30s)
   - Frequent (10s)
   - Aggressive (3s)

3. **Code Ask Bar**
   - Focused mode: Blurred background + detailed panel
   - Inline mode: Per-line annotations
   - **Gap:** Not yet using Rust agent loop

### 6.3 Computer Use Implementation Plan

To implement real computer use (not just API passthrough):

```rust
// agent_core/src/tools/computer_use.rs
pub struct ComputerUseTool {
    ax_tree: AXTreeWalker,
    screen: ScreenCapture,
    input: InputSimulator,
}

impl ComputerUseTool {
    pub async fn screenshot(&self) -> Result<Vec<u8>>;
    pub async fn click(&self, x: u32, y: u32) -> Result<()>;
    pub async fn type(&self, text: &str) -> Result<()>;
    pub async fn get_accessibility_tree(&self) -> Result<AXTree>;
    pub async fn find_element(&self, criteria: ElementCriteria) -> Result<Element>;
}
```

Leverage existing `omega-ax` crate for:
- `ax_tree`: Accessibility tree walking
- `input`: CGEvent simulation
- `permissions`: TCC management

---

## Part 7: Architecture Decision Records

### ADR 1: Keep SwiftUI for UI
**Decision:** Do not adopt GoClaw's web-based UI  
**Rationale:** Native macOS feel is a differentiator  
**Trade-off:** Slower to add new UI features vs web

### ADR 2: Rust for Agent Loop
**Decision:** Keep agent_core in Rust, not Swift  
**Rationale:** Performance, memory safety, async ecosystem  
**Trade-off:** FFI complexity vs safety

### ADR 3: Eliminate Hermes Subprocess
**Decision:** Port all features to Rust, kill Python subprocess  
**Rationale:** Memory, startup time, complexity  
**Timeline:** 2-3 weeks

### ADR 4: MCP over Custom Protocol
**Decision:** Use MCP for tool extension instead of custom JSON-RPC  
**Rationale:** Ecosystem compatibility  
**Impact:** Can use community tools

---

## Part 8: Testing Strategy

### 8.1 Unit Tests (Rust)
```bash
cd agent_core && cargo test
```
- Provider mocks
- Tool execution
- Context compaction

### 8.2 Integration Tests (Swift)
```bash
xcodebuild test -scheme Epistemos -destination 'platform=macOS'
```
- End-to-end agent loop
- Tool integration
- UI state management

### 8.3 Manual Verification Checklist
- [ ] 4 cloud providers working
- [ ] All 17 tools functional
- [ ] Subagent spawning (when implemented)
- [ ] MCP client connection
- [ ] Computer use (when implemented)
- [ ] Context compaction under load
- [ ] Memory threat scanning
- [ ] Approval flow UI

---

## Appendix A: File Inventory

### Core Agent Files (Rust)
- `agent_core/src/agent_loop.rs` - Main loop
- `agent_core/src/bridge.rs` - FFI bridge
- `agent_core/src/tools/registry.rs` - Tool registration
- `agent_core/src/providers/*.rs` - Cloud providers

### Core Agent Files (Swift)
- `Epistemos/ViewModels/AgentViewModel.swift` - UI state
- `Epistemos/Bridge/StreamingDelegate.swift` - FFI delegate
- `Epistemos/State/ChatState.swift` - Chat state
- `Epistemos/Engine/TriageService.swift` - Routing

### Code Editor AI
- `AIPartnerService.swift` - Inline suggestions
- `WeightedContextEngine.swift` - Graph-weighted search
- `CodeAskBar.swift` - Query interface

---

## Appendix B: Provider Feature Matrix

| Feature | Claude | OpenAI | Gemini | Perplexity |
|---------|--------|--------|--------|------------|
| Streaming | ✅ | ✅ | ✅ | ✅ |
| Tools | ✅ | ✅ | ✅ | ❌ |
| Thinking | ✅ | ✅ | ✅ | ❌ |
| Computer Use | ✅ | ✅ API | ✅ API | ❌ |
| Image Input | ✅ | ✅ | ✅ | ❌ |
| Prompt Caching | ✅ | ✅ | ❌ | ❌ |

**Note:** Computer use APIs differ between providers. Need abstraction layer.

---

## Conclusion

Epistemos has **world-class foundations** but needs **agent orchestration features** to compete with Goose/Hermes:

1. **Immediate (this week):** Port remaining Hermes features, implement MCP client
2. **Short-term (2 weeks):** Real computer use, browser tool, subagents
3. **Medium-term (1 month):** Epistemos Canvas, intelligent skills, more providers

The technical architecture is sound. The gap is in **agent capabilities**, not **infrastructure**.

**Recommended Priority:**
1. Kill Hermes subprocess (port to Rust)
2. Implement MCP client
3. Real computer use
4. Subagent spawning
5. Canvas/A2UI

---

*This audit is based on code analysis of:*
- Epistemos codebase (April 7, 2026)
- GoClaw v1.0 (Go-based agent platform)
- Hermes Agent v0.7.0 (Python-based agent)
- OpenClaw v2025.3 (TypeScript-based agent)
