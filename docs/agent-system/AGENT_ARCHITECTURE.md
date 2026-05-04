# EPISTEMOS AGENT SYSTEM — CLAUDE.md

> **Index status**: CANONICAL-RESEARCH — Agent system architecture (cited from CLAUDE.md). Phase D / K reference.
> Classified in [`docs/_INDEX.md §14`](_INDEX.md). Copy in `docs/_consolidated/20_canonical_research/agent_system/`.


# Unified Build Specification v2.0
# Synthesized from 8 research documents + architectural gap analysis

## WHAT THIS IS

Drop this file at project root. It is the single source of truth for the
Epistemos agent system — replacing all prior specification documents.

**Origin documents** (now superseded by this file):
1. EPISTEMOS_AGENT_ARCHITECTURE_v1.md — Provider matrix, agentic loop theory
2. EPISTEMOS_AGENT_ARCHITECTURE_v1.1_ADDENDUM.md — Tool arsenal, computer use
3. EPISTEMOS_REAL_AGENTS.md — 3,935 lines of implementation code
4. EPISTEMOS_MASTER_BUILD_SPEC.md — Build order and cost targets
5. Production-Grade AI Agents in Swift/Rust — Claude API details
6. Complete Native macOS AI Agent System — 12-part build guide
7. Architecting Autonomous Native macOS AI Agents — BoltFFI, AX pipeline
8. Tool Arsenal Deep Research — 10-category tool catalog

---

## THE DIAGNOSIS

The agent feels dead because it's a request-response pipeline. The fix is a
living `while` loop in Rust where the agent calls provider → parse → execute
tools → feed results back → and the agent decides when to stop.

Three specific failures in the prior system:
1. No interleaved thinking between tool calls
2. No streaming cognition — UI waits for complete responses
3. No dynamic tool composition — DAG pre-plans everything

---

## ARCHITECTURE

```
┌─────────────────────────────────────────────────────────────────┐
│                   SwiftUI (macOS 26 Tahoe)                      │
│   @Observable AgentViewModel  ←  AsyncStream<AgentEvent>        │
│   OmegaPanel: thinking · tool status · response · permission    │
│   Phase-based: idle→thinking→executing→responding→complete      │
└───────────────────────┬─────────────────────────────────────────┘
                        │ UniFFI async delegate callback interface
┌───────────────────────▼─────────────────────────────────────────┐
│              Rust Agent Core  (tokio async runtime)              │
│                                                                  │
│  AgentSession                                                    │
│  ├── ConfidenceRouter  → classifies, picks provider + effort     │
│  ├── ProviderRegistry  → Claude, OpenAI, Perplexity, Local       │
│  ├── ToolRegistry      → vault_search/read/write, bash, web      │
│  ├── VaultStore        → sqlite-vec + tantivy hybrid search      │
│  ├── SessionStore      → JSONL transcripts + GLOBAL_SESSIONS     │
│  ├── RecipeCache       → Voyager-style SHA-256 recipe replay     │
│  └── RetryEngine       → exponential backoff + jitter for HTTP   │
│                                                                  │
│  THE AGENTIC LOOP:                                               │
│  1. Bootstrap: vault_search + AGENTS.md → system prompt          │
│  2. Stream inference: thinking → text → tool_use                 │
│  3. Execute tools concurrently (futures::try_join_all)           │
│  4. PRESERVE thinking blocks in message history (CRITICAL)       │
│  5. Feed tool results back as user message                       │
│  6. Loop until stop_reason == "end_turn" (agent decides)         │
│  7. Context compaction when tokens > threshold                   │
└─────────────────────────────────────────────────────────────────┘
```

---

## RUST / SWIFT BOUNDARY

**Rust owns**: the loop, HTTP streaming, SSE parsing, tool execution,
message history, session persistence, memory search, MCP, retry logic.

**Swift owns**: UI rendering, MLX local inference, macOS APIs (AXUIElement,
ScreenCaptureKit, CGEvent), permission gate UI, settings.

**Wrong split** (what dead agents do):
```
Swift: orchestration loop, HTTP calls, tool execution
Rust: just SQLite reads
```

**Right split** (what this system does):
```
Rust: the loop, HTTP, tools, storage, memory, MCP
Swift: rendering, MLX inference, macOS APIs, permission UI
```

---

## FILE MANIFEST

```
agent_core/src/
├── lib.rs                  Module declarations, UniFFI scaffolding
├── types.rs                Message, ContentBlock, StopReason, TokenUsage
├── provider.rs             AgentProvider trait, MessageStream, StreamEvent
├── agent_loop.rs           run_agent_loop — THE CORE
├── bridge.rs               UniFFI exports, AgentEventDelegate, from_ffi()
├── error.rs                HTTP retry with exponential backoff + jitter
├── prompts.rs              System prompt fragments, TOOL_PREFERENCE_RULES
├── session.rs              GLOBAL_SESSIONS registry, CancellationToken map
├── routing.rs              ConfidenceRouter, HeuristicClassifier
├── providers/
│   ├── claude.rs           ClaudeProvider: SSE state machine, thinking
│   ├── perplexity.rs       PerplexityProvider (Phase 4)
│   └── openai.rs           OpenAIProvider via rig-core (Phase 4)
├── tools/
│   └── registry.rs         ToolRegistry, ToolHandler trait, implementations
└── storage/
    ├── vault.rs            VaultBackend trait, VaultStore (tantivy + sqlite)
    └── recipe_cache.rs     Voyager-style SHA-256 recipe caching

Epistemos/ (Swift)
├── Bridge/
│   └── StreamingDelegate.swift   AsyncStream bridge, permission semaphores
├── ViewModels/
│   └── AgentViewModel.swift      @Observable, phase-based state machine
├── Views/
│   └── OmegaPanel.swift          Agent UI: thinking/tools/response/permission
└── LocalAgent/
    ├── HermesPromptBuilder.swift  Hermes-3 function calling format
    ├── LocalToolGrammar.swift     mlx-swift-structured grammar DSL
    ├── LocalAgentLoop.swift       Grammar-constrained MLX inference
    └── ConfidenceRouter.swift     SLM-default, LLM-fallback routing
```

---

## CRITICAL RULES

### 1. Preserve Thinking Blocks (The #1 Fix)

When stop_reason is "tool_use", the assistant message contains thinking + tool_use
blocks. Pass the ENTIRE content array back. Dropping thinking blocks severs the
reasoning chain — this is the documented cause of dead agents.

```rust
// CORRECT — preserve ALL blocks
messages.push(Message::assistant(response_blocks.clone()));

// WRONG — strips thinking, kills the agent
let text_only = response_blocks.iter()
    .filter(|b| matches!(b, ContentBlock::Text { .. }))
    .cloned().collect();
messages.push(Message::assistant(text_only));
```

### 2. Stream Everything — Never Buffer

Forward every token to the delegate immediately. No accumulating responses.
The UI shows the agent thinking in real-time.

### 3. Let the Agent Decide When to Stop

max_turns is a safety rail (default: 25), not a schedule. The loop terminates
on stop_reason == "end_turn". Trust the agent's judgment.

### 4. Parallel Tool Execution

Use `futures::try_join_all` for independent tool calls. Claude often requests
2-3 tools per turn. Sequential execution wastes time.

### 5. Context Compaction

When estimated tokens exceed the threshold (default: 150K), use the provider's
compact() method. This preserves semantic meaning while reducing history size.

### 6. Permission Gates

- ReadOnly tools (vault_search, vault_read): auto-approve
- Modification tools (vault_write): configurable, default deny
- Destructive tools (file_delete, bash with rm): always require approval
- Permission timeout: 120 seconds, then auto-deny

---

## PROVIDER MATRIX

| Provider | Model | Input $/M | Output $/M | Route For |
|---|---|---|---|---|
| Claude | Haiku 4.5 | $0.80 | $4.00 | Triage, classification |
| Claude | Sonnet 4.6 | $3.00 | $15.00 | 90% of cloud work |
| Claude | Opus 4.6 | $15.00 | $75.00 | Max-difficulty only |
| OpenAI | o4-mini | $1.10 | $4.40 | Fast reasoning |
| Perplexity | Sonar Pro | $3.00 | $15.00 | Deep research |
| Local | MLX/AFM | $0.00 | $0.00 | 60% of all requests |

Target: $5-15/month via intelligent routing.

Claude API endpoint: POST https://api.anthropic.com/v1/messages
Key features: `thinking: { type: "adaptive" }`, `effort` parameter,
server tools (web_search, web_fetch, code_execution), `mcp_servers` parameter.
Beta header: `interleaved-thinking-2025-05-14`

---

## TOOL ARSENAL

### Installed CLI tools (one-command install):
```bash
brew install ast-grep comby tree-sitter difftastic ripgrep fd sd bat \
  fq gron tokei scc dust eza watchexec qsv miller jless yq git-delta \
  git-absorb lazygit gh hyperfine procs bottom mise shellcheck shfmt \
  bacon periphery xcbeautify swiftlint grex zoxide choose semgrep \
  nushell xh hurl websocat caddy
cargo install sad git-branchless cargo-expand cargo-audit
```

### Tool preference rules (in every system prompt):
- Files: `fd` not `find`
- Text search: `rg` not `grep`
- Code structure: `sg` (ast-grep) not regex
- Code rewriting: `comby` not sed for structural changes
- JSON: `jq` or `gron` not Python
- YAML/frontmatter: `yq` not Python
- Diffs: `difftastic` not standard diff
- Binary inspection: `fq` not hexdump
- Git fixup: `git-absorb --and-rebase` not manual squash
- HTTP: `xh` or `hurl` not curl

### Registered agent tools:
| Tool | Risk Level | Description |
|---|---|---|
| vault_search | ReadOnly | Hybrid semantic + keyword search |
| vault_read | ReadOnly | Read full note content |
| vault_write | Modification | Create/update notes |
| vault_list | ReadOnly | List notes under path prefix |
| bash_execute | Destructive | Shell command execution |
| web_search | ReadOnly | Claude server tool (web_search_20250305) |
| web_fetch | ReadOnly | Claude server tool (web_fetch_20250305) |
| ax_query | ReadOnly | AXUIElement accessibility tree query |
| ax_action | Destructive | Accessibility action (click, type) |
| screenshot | ReadOnly | ScreenCaptureKit screen capture |

---

## BUILD ORDER

### PHASE 1: The Living Loop (Week 1)
1. `types.rs` — Message, ContentBlock, StopReason, TokenUsage
2. `provider.rs` — AgentProvider trait, MessageStream, StreamEvent enum
3. `storage/vault.rs` — VaultBackend trait + VaultStore implementation
4. `tools/registry.rs` — ToolRegistry, vault_search/read/write handlers
5. `providers/claude.rs` — ClaudeProvider with full SSE state machine
6. `error.rs` — HTTP retry with exponential backoff
7. `agent_loop.rs` — run_agent_loop (the soul)
8. `session.rs` — GLOBAL_SESSIONS, cancellation registry
9. `bridge.rs` — UniFFI exports, AgentEventDelegate, from_ffi()
10. Swift: StreamingDelegate → AgentViewModel → OmegaPanel

**Test**: Claude Sonnet + vault_search + adaptive thinking → streaming to UI

### PHASE 2: Local Agent (Week 2)
1. HermesPromptBuilder.swift — Hermes-3 function calling format
2. LocalToolGrammar.swift — mlx-swift-structured grammar DSL
3. LocalAgentLoop.swift — Grammar-constrained MLX inference loop
4. ConfidenceRouter — Heuristic classifier + SLM-default/LLM-fallback

**Test**: Simple vault tasks route to local; complex to cloud

### PHASE 3: MCP + Computer Use (Week 3)
1. Vault MCP server (stdio, mcp_rust_sdk)
2. System MCP server (XPC helper, AXUIElement + ScreenCaptureKit)
3. Pass MCP servers to Claude API via `mcp_servers` parameter
4. RecipeCache — Voyager-style SHA-256 recipe caching

**Test**: "Find transformer notes and compare with recent arxiv papers"

### PHASE 4: Multi-Provider + Polish (Week 4)
1. PerplexityProvider (research with citations)
2. OpenAIProvider via rig-core (shell tasks)
3. Full context compaction loop
4. Metal thinking glow shader for OmegaPanel

**Test**: Research → Perplexity; shell → OpenAI; reasoning → Claude

---

## COMPUTER USE PIPELINE

**Architecture**: AX-first with screenshot fallback.

1. Try AXUIElement tree query first (structured, fast, reliable)
2. If AX fails or element not found, fall back to ScreenCaptureKit screenshot
3. CGEvent posting for mouse/keyboard on main run loop of XPC helper
4. TCC permissions: Accessibility + Screen Recording (survive rebuild with stable signing)

**Entitlements required**:
- `com.apple.security.automation.apple-events`
- `com.apple.security.temporary-exception.apple-events` (for specific apps)

**Key constraint**: CGEvent posting from background threads silently fails.
Use an XPC helper process with its own run loop.

---

## LOCAL MODEL VIABILITY

Local models (1-4B) CANNOT run the full agentic loop. They lose coherence
after 2-3 tool calls. Use them as FAST SPECIALISTS:

| Task | Model | Why |
|---|---|---|
| Ghost-writing / CRDT | Qwen-2.5 3B / Phi-4 Mini | Low-latency streaming |
| Semantic embeddings | nomic-embed-text-v1.5 (137M) | Runs on ANE, zero latency |
| Note classification | Apple Foundation Models (~3B) | On-device, private, tool-calling |
| Request triage | Any 1-3B instruct | Simple classification |
| Grammar-constrained dispatch | Hermes-3 8B + EBNF | 99%+ valid JSON schemas |

For grammar-constrained tool calling, use `mlx-swift-structured` to enforce
JSON schema via EBNF logit masking. The model outputs free-form thinking in
`<think>` tags, then the logit processor switches to strict JSON when
`<tool_call>` token is generated.

Apple Foundation Models (macOS 26) is the strongest local path:
- Official tool calling via @Generable schemas
- Runs on ANE — near-zero power, sub-100ms response
- Adapters API for domain fine-tuning (160MB per adapter)
- Private — nothing leaves the device

---

## KNOWN FIXES (from gap analysis)

These bugs were identified in the original REAL_AGENTS.md code and fixed:

1. **VaultBackend trait missing** — Defined in storage/vault.rs
2. **GLOBAL_SESSIONS missing** — Defined in session.rs
3. **AgentConfig::from_ffi() missing** — Defined in bridge.rs
4. **No HTTP retry logic** — Added in error.rs
5. **OmegaPanel missing** — Full implementation in OmegaPanel.swift
6. **Compaction uses Debug format** — Fix: use serde_json::to_string()
7. **AsyncStream unbounded** — Fix: .bufferingNewest(256)
8. **Permission has no timeout** — Fix: 120s auto-deny
9. **Task.detached loses cancellation** — Fix: track session ID, call both
10. **ToolDefinition name collision** — Fix: rename API type to ToolSchema

---

## VALIDATION CHECKLIST

Before declaring any phase complete:

- [ ] Thinking blocks preserved across all tool-use turns
- [ ] Streaming starts within 500ms of first token
- [ ] Parallel tool execution for independent calls
- [ ] Agent decides when to stop (stop_reason == "end_turn")
- [ ] Tool results bounded to 4096 tokens max
- [ ] Context compaction triggers before overflow
- [ ] Memory search runs as first action for multi-turn tasks
- [ ] Session transcripts persist as JSONL
- [ ] Risk-based permission gates with 120s timeout
- [ ] HTTP retry with exponential backoff + jitter
- [ ] Computer use: AX-first with screenshot fallback
- [ ] CGEvent posting on main run loop of XPC helper
- [ ] TCC permissions survive rebuild (stable signing identity)
- [ ] Local models used only for classification/embedding/ghost-writing
- [ ] All CLI tools installed and declared in system prompt

---

## REFERENCES

- Sharma & Mehta, "SLMs for Agentic Systems," arXiv:2510.03847
- Anthropic Messages Streaming API docs
- Anthropic Extended Thinking docs (thinking block preservation)
- NousResearch/Hermes-Function-Calling (Hermes-3 prompt format)
- UniFFI async documentation (Send+Sync, blocking callbacks)
- rig-core 0.9.x (Rust agent framework, used for OpenAI routes)
- mlx-swift-structured (grammar-constrained decoding)
- Voyager paper, arXiv:2305.16291 (recipe caching pattern)
- Wang et al., "ReAct," arXiv:2210.03629 (reasoning + acting loop)
