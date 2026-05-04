# Vault-Based Session Memory System for Your Swift 6 + Rust FFI PKM Agent App

## Executive Summary

After a deep analysis of all 12 repositories, the synthesis is clear: the best path forward is a **layered vault architecture** where every agent session auto-creates a UUID-namespaced folder, every model/provider gets its own persistent vault, and a knowledge graph grows across all sessions over time. This is more robust than Claude's static memory, more structured than Mem0, and directly suited to your local + cloud multi-model setup. The combination of **MemPalace's hierarchical storage**, **llm-wiki's folder-per-session pattern**, **My-Brain-Is-Full-Crew's dispatcher-agent-skill architecture**, and **graphify's AST-aware knowledge graph** gives you a system that genuinely feels alive.

***

## Repo Tier Rankings

| Tier | Repo | What to Cherry-Pick |
|------|------|---------------------|
| **🔥 Critical** | [mempalace](https://github.com/milla-jovovich/mempalace) | Palace hierarchy + ChromaDB verbatim + 96.6% recall + MCP server |
| **🔥 Critical** | [llm-wiki](https://github.com/nvk/llm-wiki) | Hub+topic folder structure, session registry, crash recovery |
| **🔥 Critical** | [My-Brain-Is-Full-Crew](https://github.com/gnekt/My-Brain-Is-Full-Crew) | Dispatcher→skill/agent routing, PARA+Zettelkasten vault layout |
| **🔥 Critical** | [graphify](https://github.com/safishamsi/graphify) | AST knowledge graph (Swift + Rust native), Obsidian vault export, 71.5x token compression |
| **⚡ High** | [open-multi-agent](https://github.com/JackChen-me/open-multi-agent) | SharedMemory across agents, DAG task orchestration, trace observability |
| **⚡ High** | [PraisonAI](https://github.com/MervinPraison/PraisonAI) | Auto-save sessions, shadow git checkpoints, graph memory, doom loop detection |
| **⚡ High** | [hermes-agent-self-evolution](https://github.com/NousResearch/hermes-agent-self-evolution) | GEPA evolutionary skill improvement from session traces |
| **🔧 Supporting** | [metaharness](https://github.com/SuperagenticAI/metaharness) | Filesystem-backed run store, per-proposal artifact manifests |
| **🔧 Supporting** | [claude-code-analysis](https://github.com/thtskaran/claude-code-analysis) | Claude Code internals: swarm IPC, context compaction triggers, dynamic system prompts |
| **🔧 Supporting** | [SciAgent-Skills](https://github.com/jaechang-hits/SciAgent-Skills) | SKILL.md template format, registry.yaml discovery, on-demand skill loading |
| **🔧 Supporting** | [kepano/obsidian-skills](https://github.com/kepano/obsidian-skills) | agentskills.io spec, Obsidian Bases + CLI skill templates |
| **⚙️ Infra** | [llama.cpp-tq3](https://github.com/turbo-tan/llama.cpp-tq3) | TQ3_4S/TQ3_1S quants for your local model (Qwen3.5-27B at 12.9GiB, better PPL than Q3_K_S) |

***

## The Core Idea: What to Build

### Session-Scoped Vault Architecture

Every time the user opens a new agent session in your app, the system automatically:

1. Generates a UUID session ID (e.g., `sess_2026-04-08_abc123`)
2. Creates a folder inside the model's vault: `vaults/<model-id>/sessions/<session-id>/`
3. Writes a `session.json` (metadata), `conversation.md` (verbatim log), `artifacts/` dir, `config.json`
4. On session end, writes a `summary.md` and tags the session in the vault's `_index.md`

This is directly inspired by **llm-wiki's** session registry and crash recovery pattern, and **metaharness's** principle of storing every run's full artifacts including prompts, workspace diffs, and per-candidate manifests.

### Per-Model / Per-Provider Vaults

Each model and provider gets its own vault root. This means Claude 3.7, GPT-4o, and your local Qwen3.5 each accumulate separate memory that grows independently over time. In the sidebar of your app, you can:

- Auto-load vaults from discovered models
- Manually add a vault (point to any folder on disk)
- Show vault health (session count, last activity, size)

This mirrors exactly the **MemPalace palace architecture**: each vault is a palace, sessions are wings, conversation types are rooms (decisions, debugging, architecture debates, preferences), and individual files are the drawers where verbatim content lives.

***

## Detailed Implementation Plan

### Phase 1: Vault & Session Core (Rust + Swift)

Implement the vault engine in Rust (behind your existing FFI boundary) for performance:

```rust
// Vault structure in Rust
pub struct Vault {
    pub id: String,           // "claude-3-7" or "qwen3-local"
    pub provider: Provider,
    pub root_path: PathBuf,   // ~/PKM/vaults/<vault-id>/
    pub index: VaultIndex,    // _index.md equivalent
}

pub struct Session {
    pub id: String,           // UUID + timestamp
    pub vault_id: String,
    pub model: String,
    pub started_at: DateTime<Utc>,
    pub tags: Vec<String>,
    pub artifacts: Vec<Artifact>,
}
```

The folder structure per vault, adapted from **llm-wiki's** topic hierarchy and **My-Brain-Is-Full-Crew's** PARA structure:

```
~/PKM/vaults/
├── _registry.json               # All vault registrations
├── claude-3-7/
│   ├── _index.md                # Master index with session list
│   ├── log.md                   # Append-only activity log
│   ├── knowledge/               # Synthesized articles (compiled from sessions)
│   │   ├── decisions/
│   │   ├── debugging/
│   │   ├── architecture/
│   │   └── preferences/
│   ├── sessions/
│   │   ├── 2026-04-08_abc123/
│   │   │   ├── session.json     # ID, model, timestamps, tags, summary
│   │   │   ├── conversation.md  # VERBATIM full conversation
│   │   │   ├── summary.md       # Agent-generated summary on close
│   │   │   ├── artifacts/       # Code files, generated content
│   │   │   └── config.json      # Model params, temperature, system prompt used
│   └── graph/
│       ├── graph.json           # graphify-style knowledge graph
│       └── GRAPH_REPORT.md      # God nodes, surprising connections
├── qwen3-local/
│   └── ... (same structure)
└── gpt-4o/
    └── ... (same structure)
```

### Phase 2: Verbatim Storage + Semantic Search

Take MemPalace's core insight: **do not summarize, store verbatim, let semantic search find it**. Their 96.6% LongMemEval score comes specifically from raw verbatim mode — every LLM-based summarization approach scores lower because it loses the "why."

For the Rust backend, implement a simple ChromaDB-compatible embedding store or use SQLite with FTS5:

- On session close → chunk `conversation.md` into semantic units → embed → store with session metadata
- On session start → query vault for relevant prior sessions → inject top-K into system prompt context
- Use MemPalace's `wake-up` concept: ~170 tokens of critical vault facts loaded at session start, then semantic search on demand

The MCP server MemPalace ships (19 tools) is directly callable from your Swift app via your existing Rust FFI layer.

### Phase 3: Dispatcher + Agent Skill Routing

Adopt **My-Brain-Is-Full-Crew's dispatcher architecture**: when an agent session starts, a dispatcher evaluates the user's intent and routes to either a **skill** (multi-step conversational workflow) or a **direct agent action** (single-shot task):

```
User opens session → Dispatcher
    → if "new project" → invoke vault-init skill
    → if "resume work" → invoke session-resume skill (load prior context)
    → if "quick question" → invoke agent with vault search context
    → if "code review" → invoke agent with graphify graph context
```

Skills are SKILL.md files (following the **SciAgent-Skills** template format and **kepano/obsidian-skills** spec). Each skill has frontmatter for agent discovery, a quick start, and a troubleshooting section. Your vault system ships with built-in skills:

| Skill | Trigger | What it does |
|-------|---------|-------------|
| `vault-init` | New session, new project | Creates session folder, initializes structure |
| `session-resume` | "Continue from last time" | Loads prior session context, injects into prompt |
| `vault-search` | "What did we decide about X?" | Semantic search across all sessions in vault |
| `knowledge-compile` | On session close | Synthesizes session into `knowledge/` articles |
| `vault-audit` | Weekly/manual | Health check, broken links, orphan sessions |
| `graph-rebuild` | After N sessions | Runs graphify to rebuild cross-session knowledge graph |

### Phase 4: Knowledge Graph Across Sessions

**Graphify** is the most powerful tool in this list for your specific app. It runs in two passes:

1. **Deterministic AST pass** — extracts structure from Swift (`.swift`) and Rust (`.rs`) files via tree-sitter, zero LLM needed. This means your actual codebase becomes part of the knowledge graph.
2. **Semantic pass** — Claude subagents extract concepts and relationships from markdown sessions and artifacts.

Every relationship is tagged `EXTRACTED` (found in source), `INFERRED` (with confidence score 0.0-1.0), or `AMBIGUOUS`. You always know what the graph found vs guessed.

Run graphify on each vault periodically:

```bash
/graphify ~/PKM/vaults/claude-3-7/ --obsidian --update
```

The `--obsidian` flag generates an Obsidian vault at the same path, so the vault becomes viewable in Obsidian with full wikilinks and graph view. The `--wiki` flag generates a `index.md`-based agent-crawlable wiki that your agents can navigate by reading files instead of parsing JSON.

The 71.5x token reduction means your agents can query the knowledge graph instead of re-reading all raw session files — critical for staying under context limits with your local 1B-4B models.

### Phase 5: Agent Self-Evolution from Session History

The **Hermes Agent Self-Evolution** pattern is the long-game feature. After accumulating session history, use DSPy + GEPA to:

1. Read execution traces from your session artifacts
2. Understand *why* certain agent responses were good/bad (not just that they were)
3. Mutate your SKILL.md files toward better variants
4. Run constraint gates (size limits, semantic preservation, test suite)
5. Promote winning variants to your active skill set

This means your vault system gets smarter the more you use it. The skill files evolve from actual session patterns. This is what makes the system "truly perfect memory" — it learns your usage patterns and bakes them into the agent instructions.

### Phase 6: Sidebar Vault Management (Swift UI)

In your app's sidebar:

```
VAULTS
├── 🟢 Claude 3.7 Sonnet         [active]  142 sessions
├── 🔵 GPT-4o                    [active]  38 sessions
├── 🟡 Qwen3.5-27B Local         [active]  67 sessions
├── ⚪ Claude 3 Opus              [paused]  12 sessions
└── [+ Add Vault]
    └── [⚙ Vault Settings]

CURRENT SESSION
├── sess_2026-04-08_abc123
├── Started: 12:27 AM
├── Model: Claude 3.7
├── Tags: [rust] [ffi] [memory]
└── Linked sessions: 3 similar
```

Vault autoload logic: scan `~/PKM/vaults/` on app launch, read `_registry.json`, instantiate VaultManager in Rust, expose to Swift via your existing FFI.

***

## Key Patterns to Cherry-Pick (Surgical Summary)

### From MemPalace
- Store conversation verbatim (never summarize on write, only on query)
- Palace hierarchy: vault → wing (project) → room (topic type) → drawer (individual file)
- AAAK compression for token-dense storage when context is tight
- ~170 token `wake-up` context at session start

### From llm-wiki
- Hub `_registry.json` + per-vault `_index.md` navigation
- `log.md` append-only activity log (grep-friendly)
- Session registry for crash recovery
- Per-topic/session isolated structure (no cross-contamination)
- Configurable hub path (iCloud, Dropbox, local) for sync

### From My-Brain-Is-Full-Crew
- Dispatcher-first routing: check skills before agents
- Agent coordination via `### Suggested next agent` signal in outputs
- PARA + Zettelkasten hybrid: Projects, Areas, Resources, Archive + MOCs
- Conservative by default: never delete, always archive, ask before big decisions
- Any-language responses (relevant if you support multilingual prompts)

### From graphify
- Two-pass extraction: deterministic AST (Swift + Rust native) + semantic
- EXTRACTED/INFERRED/AMBIGUOUS edge tagging with confidence scores
- `--watch` mode: instant graph rebuild on code file saves
- `--neo4j-push` for external graph DB if you scale up
- Git hooks: rebuild graph on every commit and branch switch
- `GRAPH_REPORT.md` as always-on agent context (god nodes, communities, surprising connections)

### From open-multi-agent
- SharedMemory across agent team instances
- Lifecycle hooks `beforeRun`/`afterRun` for vault read/write
- Loop detection to prevent stuck agents in vault operations
- Trace observability: structured spans for every LLM call, correlatable by `runId` → store traces in session artifacts

### From hermes-agent-self-evolution
- Use real session history (not synthetic) for skill evolution
- GEPA reads execution traces → proposes targeted mutations
- Constraint gates before promoting: tests pass, size limits, semantic preservation
- All changes go through human review (PR pattern) → translate to "propose changes" UI in your app

### From metaharness
- Every session stores: prompts used, validation results, workspace diffs, metadata
- Per-session manifests (what files were created/modified)
- `allowed_write_paths` scope enforcement → translate to vault write permissions per agent

### From claude-code-analysis
- Context compaction triggers at 93% pressure — build the same trigger into your session manager
- Multi-agent IPC via file-based mailbox with polling → use for local model ↔ cloud model coordination
- System prompt split: static sections (cached) + dynamic sections (rebuilt per session) → your vault context injection fits in the dynamic sections
- YOLO classifier pattern: lightweight pre-check before expensive tool calls

### From SciAgent-Skills + kepano/obsidian-skills
- SKILL.md format: frontmatter (name, description, license), overview, prerequisites, quick start, workflow, key params, troubleshooting
- `registry.yaml` for agent discovery: agents read only the `description` field during planning, full skill content loaded on demand
- Validate registry before promoting new skills

### From llama.cpp-tq3
- For your local model: TQ3_4S format gives better PPL than Q3_K_S at comparable size (Qwen3.5-27B at 12.9GiB, PPL 6.82 vs 6.86)
- TurboQuant KV-cache: `-ctk tq3_0 -ctv tq3_0` for extended context on your local inference server
- Run `llama-server` on port 8090 → your Rust FFI layer connects to it via `http://localhost:8090/v1`

***

## What Makes This Better Than Claude App / OpenClaw

| Feature | Claude App | OpenClaw | **Your App** |
|---------|-----------|----------|-------------|
| Session persistence | Projects (manual) | Minimal | Auto UUID folders, fully structured |
| Memory search | None | Minimal | Semantic ChromaDB across all vaults |
| Per-model memory | No | No | ✅ Each model has its own growing vault |
| Knowledge graph | No | No | ✅ graphify AST + semantic graph |
| Local + cloud parity | Cloud only | Mostly cloud | ✅ Same vault system for both |
| Memory evolution | No | No | ✅ GEPA skill evolution from session traces |
| Verbatim recall | No (summaries) | No | ✅ 96.6% LongMemEval raw mode |
| Vault Obsidian compat | No | No | ✅ Full wikilinks + graph view |
| Agent skill routing | No | No | ✅ Dispatcher → skill/agent |

***

## Implementation Order

1. **Week 1**: Vault + session folder creation in Rust FFI. `VaultManager`, `SessionManager`, write `session.json` + `conversation.md` on open/close.
2. **Week 2**: Sidebar Swift UI. VaultList view, session display, vault settings. Auto-load from `_registry.json`.
3. **Week 3**: Semantic search. Embed session chunks, SQLite+FTS5 or ChromaDB via Python subprocess. `vault-search` skill.
4. **Week 4**: MemPalace MCP server integration. Wire 19 memory tools into your existing agent tool chain.
5. **Week 5**: graphify integration. Run on vault, generate `GRAPH_REPORT.md`, inject into agent context pre-tool hooks.
6. **Week 6**: Skills system. `registry.yaml`, `vault-init`, `session-resume`, `knowledge-compile`. Dispatcher routing.
7. **Later**: Hermes self-evolution loop. Metaharness-style run store. TQ3 local model optimization.