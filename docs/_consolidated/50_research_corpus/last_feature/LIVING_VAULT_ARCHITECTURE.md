# LIVING VAULT ARCHITECTURE
# Epistemos Omega — Phase 2: The Vault Becomes a Mind

Date: 2026-03-29
Status: Architecture finalized, implementation deferred until Sprint Omega-4 complete
Predecessors: Sprint Omega-1 (foundation), Omega-2 (Hermes), Omega-3 (AXorcist), Omega-4 (skills/memory/polish)

## The Core Insight

The vault stops being a knowledge store and becomes a living cognitive substrate. Every memory change is a diff, not an overwrite or append. When you or an agent sends a message to the vault chat, the system reads the current file state, generates a +/- patch, shows it like a code review, and commits it atomically to git. The vault's git log becomes the agent's intellectual history — `git log` shows every belief change, when it happened, and why.

This is not RAG. This is not fine-tuning. This is context compilation — a deterministic DAG engine that dynamically assembles optimized context for each API call from a structured, self-improving vault. The empirical case is strong: EMNLP 2024 demonstrated that optimized in-context learning outperforms fine-tuning for implicit pattern tasks. Stanford 2025 showed ICL generalizes better. The vault doesn't approximate fine-tuning — it accesses the same capability space through a different mechanism.

## System Overview

Five interlocking subsystems, each buildable independently:

```
┌─────────────────────────────────────────────────────────┐
│                    EPISTEMOS OMEGA                       │
│                                                          │
│  ┌──────────────┐  ┌──────────────┐  ┌───────────────┐ │
│  │ Living Vault  │  │ Chat-Driven  │  │ Context       │ │
│  │ Memory Engine │  │ Mutation     │  │ Compiler      │ │
│  │ (diff/decay)  │◄─┤ Interface    │──┤ (prompt DAG)  │ │
│  └──────┬───────┘  └──────────────┘  └───────┬───────┘ │
│         │                                      │         │
│  ┌──────▼───────┐                     ┌───────▼───────┐ │
│  │ Multi-Vault   │                     │ Agent Graph   │ │
│  │ Registry      │─────────────────────┤ Visualizer    │ │
│  │ (per-model)   │                     │ (Metal/Grape) │ │
│  └──────────────┘                     └───────────────┘ │
└─────────────────────────────────────────────────────────┘
```

## Subsystem 1: Living Vault Memory Engine

### The Self-Editing Memory Loop

Every vault file has a lifecycle. It's born from a conversation, grows through use, decays through neglect, and dies when it's no longer true. The memory engine manages this lifecycle through four mechanisms.

**The Four-Operation Classifier** — borrowed from Mem0's architecture. Before every write, the engine classifies the incoming information against existing vault state:

- ADD: New fact not present in any vault file. Create a new node or append to the appropriate file.
- UPDATE: Existing fact with changed details. Generate a diff patch that modifies the specific section.
- DELETE: Incoming fact contradicts an existing belief. Issue a DELETE patch on the old fact, then ADD the new one. Both patches land in one atomic commit.
- NOOP: Incoming fact is redundant with existing knowledge. Do nothing. Log the duplicate detection for debugging.

The classifier runs as a Rust function in `agent_core/src/storage/memory_classifier.rs`. It uses embedding similarity (sqlite-vec cosine distance) to find candidate matches, then a lightweight LLM call (local Qwen or Haiku) to classify the operation. The LLM prompt is structured:

```
Existing fact: "Claude Opus 4.6 costs $15/M input tokens"
Incoming fact: "Claude Opus 4.6 costs $12/M input tokens as of March 2026"
Classify: ADD, UPDATE, DELETE, or NOOP?
Output JSON: {"operation": "UPDATE", "target_file": "model-vaults/claude-opus/profile.json", "target_section": "pricing", "reason": "Price reduction"}
```

**Ebbinghaus Decay** — every vault node carries a `strength` field (0.0 to 1.0) that decays exponentially when unused. The decay formula:

```
strength(t) = strength(t₀) × e^(-λ × (t - t₀))
```

Where λ (decay rate) is inversely proportional to the node's importance score. High-importance facts (marked by user or by frequency of retrieval) decay slowly (λ = 0.01/day). Noise decays fast (λ = 0.1/day). When strength drops below 0.15, the node is flagged for garbage collection. A background sweep (Night Brain pattern from existing Epistemos architecture) runs daily, generating DELETE diffs for decayed nodes and committing them as a batch.

The user can pin nodes (strength = 1.0, λ = 0), boost nodes (reset strength to 1.0), or manually delete. The graph view shows strength as node opacity — fading nodes are literally fading from the agent's memory.

**Cross-File Propagation** — when one vault file is patched, a scanner checks every other vault file for references to the changed entity and generates secondary patches. All patches land as one atomic git commit. No belief drift between files. Implementation uses tantivy full-text search to find references, then the classifier to determine if each reference needs UPDATE or NOOP.

**Git as the Cognitive Journal** — every vault mutation is a git commit with a structured message:

```
[MEMORY:UPDATE] model-vaults/claude-opus/profile.json
  - pricing.input_per_million: $15.00 → $12.00
  - source: user correction via vault chat
  - strength: 1.0 (freshly confirmed)
```

The git log IS the agent's intellectual history. You can `git log --oneline model-vaults/claude-opus/` and see every belief change. You can `git diff HEAD~5 model-vaults/` and see how the agent's understanding evolved over the last 5 interactions. You can `git revert` a bad memory.

### Vault Node Schema

Every piece of knowledge in the vault is a node with metadata stored as YAML frontmatter:

```yaml
---
id: mem_2026-03-29_001
created: 2026-03-29T14:30:00Z
updated: 2026-03-29T16:45:00Z
strength: 0.92
importance: high
source: chat/main/2026-03-29-agent-research.md
tags: [claude, pricing, api]
references: [mem_2026-03-15_042, mem_2026-03-20_017]
decay_rate: 0.01
access_count: 7
last_accessed: 2026-03-29T16:45:00Z
---

Claude Opus 4.6 costs $12/M input tokens and $60/M output tokens as of March 2026.
Prompt caching reduces input costs by 90% for cached reads.
```

### Diff Engine

The diff engine generates patches, not rewrites. Two implementation paths:

**For text/markdown content**: Use the `similar` Rust crate (unified diff format, already pure Rust, no new dependencies). Generate a unified diff, apply with a custom patcher that handles fuzzy matching for shifted content.

**For structured data (JSON/YAML)**: Use `serde_json::Value` tree diffing. Walk both trees simultaneously, emit ADD/REMOVE/CHANGE operations on specific paths. This is more precise than text diffing for structured data and produces cleaner commit messages.

The diff is rendered in the UI as a staging area (like `git add -p`):

```diff
  ## Pricing
- Input: $15.00 per million tokens
+ Input: $12.00 per million tokens
  Output: $60.00 per million tokens
+ Cache read: $1.20 per million tokens (90% discount)
```

The user can approve individual hunks, discard them, or edit them before committing. In auto mode (for agent-driven mutations), hunks are committed immediately with the agent's reasoning logged in the commit message.

## Subsystem 2: Chat-Driven Mutation Interface

Every chat interaction can mutate the vault. The system distinguishes three mutation triggers:

**Explicit mutation** — user sends a message like "Update Claude's pricing to $12/M input" in the vault chat. The system generates a diff, shows it, and commits on approval.

**Implicit mutation** — during a normal conversation, the agent learns something new. The memory flush (triggered at 50% context fill or on session end) extracts durable facts and generates diffs against the relevant vault files.

**Programmatic mutation** — a tool call (`vault_patch`) generates diffs programmatically. Used by agents during autonomous work.

### Auto-Documenting Conversations

Every conversation automatically persists as dual-format: JSONL for machine parsing, companion markdown for human reading.

```
vault/
├── chats/
│   ├── main/
│   │   └── 2026-03-29-agent-research.md
│   ├── mini/
│   │   └── 2026-03-29-vault-query.md
│   └── agentic/
│       └── 2026-03-29-sprint-omega-1-task-3.md
├── sessions/
│   └── <uuid>.jsonl          # Machine-parseable, append-only
└── memory/
    ├── MEMORY.md              # Global persistent facts (~2200 chars)
    ├── USER.md                # User preferences (~1375 chars)
    └── extracted/
        └── entities.jsonl     # Extracted entities for graph
```

The JSONL schema per turn:

```json
{
  "id": "turn_uuid",
  "parent_id": "parent_turn_uuid",
  "timestamp": "2026-03-29T14:30:00Z",
  "role": "assistant",
  "content": "...",
  "model": "claude-opus-4-6",
  "tokens": {"input": 1200, "output": 450, "cache_read": 800},
  "tool_calls": [{"name": "vault_search", "args": {...}, "result": "..."}],
  "vault_mutations": ["diff_commit_hash_1", "diff_commit_hash_2"],
  "latency_ms": 2340
}
```

The `parent_id` field enables conversation trees — edited messages, regenerations, and branching explorations all preserve their lineage.

## Subsystem 3: Context Compiler (Prompt DAG)

This is the engine that makes cloud models feel fine-tuned. When the app calls any cloud API, the context compiler reads the model's vault and assembles an optimized prompt.

### The Compilation Pipeline

```
1. TRIGGER: User sends message or agent needs API call
2. ROUTE: ProviderRouter selects the model (claude-opus, gpt-5, etc.)
3. LOAD: Context Compiler reads that model's vault directory
4. CLASSIFY: Classify the query to select relevant skills
5. RETRIEVE: Pull relevant few-shot examples from the example bank
6. COMPRESS: Apply compression to fit within context budget
7. ASSEMBLE: Order content for maximum attention (U-curve aware)
8. CACHE: Place cache_control breakpoints on stable prefix
9. EMIT: Send to API
```

### Vault-Per-Model Registry

```
model-vaults/
├── claude-opus-4.6/
│   ├── profile.json          # Capabilities, pricing, context window, benchmarks
│   ├── SYSTEM.md             # Base system prompt (stable, cached)
│   ├── MEMORY.md             # Model-specific persistent facts
│   ├── skills/               # SKILL.md files (agentskills.io format)
│   │   ├── code-review/SKILL.md
│   │   ├── research/SKILL.md
│   │   └── writing/SKILL.md
│   ├── few-shot-bank/
│   │   ├── examples.jsonl    # {input, output, embedding, quality, task_type}
│   │   └── index.bin         # sqlite-vec embedding index
│   ├── tool-protocols/
│   │   ├── tools.json        # Tool definitions optimized for this model
│   │   └── preferences.md    # "This model works best with X tool format"
│   └── optimization/
│       ├── trajectory.jsonl  # {instruction, score, timestamp}
│       └── test-suite.yaml   # Regression tests
├── claude-sonnet-4.6/
│   └── ... (same structure, different content)
├── perplexity-sonar/
│   └── ...
├── local-qwen-3.5/
│   └── ...
└── agents/
    ├── researcher/
    │   ├── SOUL.md            # Agent persona + instructions
    │   ├── MEMORY.md          # Agent-specific learned facts
    │   └── skills/
    └── coder/
        └── ...
```

The user can toggle between vaults in the graph view. Selecting "Research Agent" shows that agent's knowledge graph. Selecting "Claude Opus 4.6" shows everything attached to that model. Selecting "All APIs" shows the entire constellation.

### Assembly Order (Cache-Optimal, U-Curve Aware)

The "Lost in the Middle" paper showed models attend best to the beginning and end of context. The compiler exploits this:

```
[CACHED STATIC PREFIX — cache_control breakpoint 1]
  1. Tool/function definitions (most stable, rarely changes)
  2. Base system prompt from SYSTEM.md
  3. Active skills (selected by embedding similarity to query)
  4. Core MEMORY.md content (always present)
[CACHED SLIDING WINDOW — cache_control breakpoint 2]
  5. Proven few-shot examples (retrieved from bank, best example LAST)
[DYNAMIC SUFFIX — changes every request]
  6. RAG-retrieved vault context (knowledge graph fragments)
  7. Conversation history (compactable)
  8. Current user message (always at the very end, highest attention)
```

Breakpoint placement follows Anthropic's rules: minimum 1,024 tokens for Sonnet, 4,096 for Haiku. Cache reads cost 10% of base input price. Cache writes cost 25% premium for 5-minute TTL. The static prefix should be large and stable to maximize cache hits.

### Self-Improving Optimization Loop

After every successful interaction (user didn't regenerate, no negative feedback), the system:

1. Extracts the (query, context_used, response, success_signal) tuple
2. Stores it in `optimization/trajectory.jsonl`
3. Periodically (nightly or on-demand) runs an optimization pass:
   - DSPy MIPROv2 style: collect traces, generate candidate instructions, Bayesian search over combinations
   - OPRO style: use the LLM itself to propose better prompts given scored history
   - EvoPrompt style: genetic crossover/mutation on prompt populations
4. Evaluates candidates against `test-suite.yaml` (regression tests)
5. Deploys improved vault content only when all regression tests pass
6. Commits the change as a git diff with the optimization score

This means the vault literally gets smarter over time. The system prompt you're using for Claude in March is measurably better than the one from February, because the optimization loop refined it based on 500 interactions.

### Compression for Context Budget Management

When the assembled context exceeds the model's effective window, compression kicks in:

- **Level 1 (lossless)**: Remove whitespace, collapse empty lines, strip markdown formatting from non-essential sections
- **Level 2 (near-lossless)**: Summarize old conversation turns, replace verbose tool results with excerpts
- **Level 3 (lossy)**: Apply LLMLingua-2 style token-level compression (achievable locally with a small model). Microsoft's research shows 20x compression with only 1.5% performance loss
- **Level 4 (aggressive)**: Drop low-strength memory nodes, reduce few-shot examples from 5 to 2, truncate skills to metadata-only

The vault stores knowledge at multiple compression ratios so the compiler can select the right level without re-compressing at query time.

## Subsystem 4: Multi-Vault Registry

The registry maps identities to vault directories. An identity can be:

- **A model**: `claude-opus-4.6` → `model-vaults/claude-opus-4.6/`
- **An agent role**: `researcher` → `model-vaults/agents/researcher/`
- **A team**: `sprint-team` → union of `coder` + `researcher` + `reviewer` vaults
- **A use case**: `research`, `coding`, `writing` — user-defined labels that map to vault dirs
- **The user**: `personal` → the main Epistemos vault (notes, journal, PKM)

Switching vaults in the UI changes what knowledge the context compiler draws from. In the graph view, selecting a vault highlights its nodes and dims everything else.

### Vault Attachment Rules

When the user selects a model in the chat interface, the system automatically attaches:
1. The model's vault (model-specific instructions, skills, memory)
2. The user's personal vault (personal context, preferences)
3. The active agent's vault (if running an agent session)

These three vaults are merged by the context compiler with priority: agent > model > personal. Conflicts are resolved by recency (most recently updated fact wins).

## Subsystem 5: Agent Graph Visualizer

### Data Model

Every vault node becomes a graph node. Every reference between nodes becomes an edge. The graph is rendered using Metal (via Grape for Phase 1, custom Metal compute for Phase 2).

Node types and their visual encoding:

- **Memory nodes**: Circle, opacity = strength, size = access_count
- **Skill nodes**: Hexagon, color = category (code = blue, research = teal, writing = coral)
- **Model nodes**: Large rounded rect, color = provider (Anthropic = purple, OpenAI = green)
- **Agent nodes**: Diamond, pulsing animation when active
- **Chat nodes**: Small circle, connected to the memory nodes they spawned
- **Tool nodes**: Square, connected to models that can use them

### Zoom Levels

- **Level 1 (cosmic)**: Provider clouds (Anthropic, OpenAI, Local). Each cloud's size = total knowledge attached.
- **Level 2 (constellation)**: Models within each provider. Edges show which models share skills.
- **Level 3 (solar system)**: One model selected. Its skills, memory, tools, and active agents orbit it.
- **Level 4 (planet)**: One agent or skill selected. Individual memory nodes, their strengths, their connections.
- **Level 5 (surface)**: One memory node selected. Full content shown. Edit in place. Diff history timeline.

### Live State Rendering

When an agent is running, its graph node pulses. Edges to active tools flash. The context window fills as a radial progress indicator around the model node. Token flow animates as particles along edges. Memory mutations flash the affected nodes.

### Implementation: Grape → Metal Pipeline

Phase 1 (up to 2K nodes): Use SwiftGraphs/Grape library. Force-directed simulation with SIMD-accelerated KD-tree (22x faster than Apple's GKQuadtree). Renders in SwiftUI directly.

Phase 2 (2K-10K nodes): Metal instanced rendering. Compute shader runs ForceAtlas2 with Barnes-Hut quadtree approximation. Render shader draws all nodes in one `drawIndexedPrimitives` call. Zero CPU↔GPU transfer because compute writes directly to the render buffer.

Phase 3 (10K+ nodes): Full Metal compute pipeline. Semantic zoom with Louvain community detection for automatic clustering. Edge bundling to reduce visual clutter. LOD (level of detail) reduces distant nodes to colored dots.

## File Map — Where Everything Lives

### Rust (agent_core crate — new modules)

```
agent_core/src/storage/memory_classifier.rs  — ADD/UPDATE/DELETE/NOOP classifier
agent_core/src/storage/memory_decay.rs       — Ebbinghaus strength decay + GC
agent_core/src/storage/diff_engine.rs        — Unified diff generation + patching
agent_core/src/storage/cross_propagation.rs  — Cross-file reference scanner
agent_core/src/context_compiler.rs           — Prompt DAG assembly
agent_core/src/context_compiler/assembler.rs — Cache-optimal ordering
agent_core/src/context_compiler/compressor.rs— Multi-level compression
agent_core/src/context_compiler/skill_router.rs — Embedding-based skill selection
agent_core/src/context_compiler/example_bank.rs — Few-shot retrieval + ranking
agent_core/src/vault_registry.rs             — Multi-vault identity mapping
```

### Rust (omega-mcp crate — new tools)

```
omega-mcp/src/tools/vault_patch.rs    — MCP tool for programmatic vault diffs
omega-mcp/src/tools/vault_query.rs    — MCP tool for structured vault queries
omega-mcp/src/tools/memory_manage.rs  — MCP tool for pin/boost/delete operations
```

### Swift (new files)

```
Epistemos/Vault/LiveVaultEngine.swift         — Coordinates memory loop
Epistemos/Vault/DiffRenderer.swift            — SwiftUI staging area view
Epistemos/Vault/VaultChatMutator.swift        — Chat→diff pipeline
Epistemos/Vault/VaultRegistry.swift           — Multi-vault switching
Epistemos/Vault/ContextCompilerBridge.swift    — Swift bridge to Rust compiler
Epistemos/Views/Graph/AgentGraphView.swift     — Main graph canvas
Epistemos/Views/Graph/GraphRenderer.swift      — Grape → Metal rendering
Epistemos/Views/Graph/SemanticZoomController.swift — Zoom level management
Epistemos/Views/Graph/NodeDetailPanel.swift    — Node inspector sidebar
Epistemos/Views/Vault/VaultSwitcher.swift      — Vault selection UI
Epistemos/Views/Vault/DiffApprovalSheet.swift  — Hunk-by-hunk approval
```

### Vault Structure (on disk)

```
~/Library/Application Support/Epistemos/
├── vaults/
│   ├── personal/              — User's main PKM vault
│   ├── model-vaults/          — Per-model knowledge
│   │   ├── claude-opus-4.6/
│   │   ├── claude-sonnet-4.6/
│   │   ├── perplexity-sonar/
│   │   └── local-qwen-3.5/
│   ├── agent-vaults/          — Per-agent knowledge
│   │   ├── researcher/
│   │   ├── coder/
│   │   └── reviewer/
│   └── shared/                — Cross-cutting knowledge
│       ├── MEMORY.md
│       └── USER.md
├── chats/
│   ├── main/
│   ├── mini/
│   └── agentic/
├── sessions/
│   └── *.jsonl
└── .git/                      — Git repo for the entire tree
```

## Non-Negotiable Design Rules

1. Every vault mutation is a git commit. No exceptions.
2. The diff engine generates patches, never rewrites entire files.
3. The context compiler assembles prompts in cache-optimal order every time.
4. Decay runs as a background sweep, never during user interaction.
5. Cross-file propagation is atomic — all secondary patches commit together.
6. The classifier MUST check for contradictions before every ADD.
7. The graph visualizer reads vault state — it never mutates it.
8. Vault switching changes context source, not UI layout.
9. Few-shot examples are ranked by embedding similarity, not recency.
10. Compression is a last resort — cache-optimal assembly comes first.

## Performance Targets

| Operation | Target | Notes |
|---|---|---|
| Diff generation (text) | <50ms | Using `similar` crate |
| Diff generation (JSON) | <20ms | Tree walk + serde |
| Classification (local) | <200ms | Local Qwen classifier |
| Classification (cloud) | <800ms | Haiku fallback |
| Context compilation | <100ms | Cached prefix + dynamic suffix |
| Vault switch | <50ms | Registry lookup + graph filter |
| Graph render (1K nodes) | 120fps | Grape + SwiftUI |
| Graph render (10K nodes) | 60fps | Metal instanced |
| Graph render (50K nodes) | 30fps | Metal compute + LOD |
| Decay sweep (10K nodes) | <1s | Batch exponential calc |
| Cross-propagation scan | <500ms | Tantivy FTS lookup |

## Dependencies (new, beyond current stack)

| Dependency | Type | Purpose |
|---|---|---|
| `similar` | Rust crate | Unified diff generation |
| `Grape` | Swift SPM | Graph visualization (Phase 1) |
| `libgit2` / `git2-rs` | Rust crate | Programmatic git commits |

Everything else uses existing Epistemos infrastructure: tantivy for search, sqlite-vec for embeddings, GRDB for metadata, Metal for rendering, MLX-Swift for local inference.
