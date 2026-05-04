# The Complete Vault-Memory Architecture for Your Swift 6 + Rust FFI PKM Agent App

## Executive Summary

After deep analysis of all 12 repositories and synthesis across six research documents, the verdict is unanimous: your Swift 6 + Rust FFI app has every prerequisite to build the most architecturally coherent memory system in any LLM application today — one that structurally outperforms Claude.ai, OpenClaw, and ChatGPT memory by being *built from the ground up* as a sovereign file-based vault, not bolted on as an afterthought. The synthesis across all research sources converges on a single north star: **files are the source of truth, databases are just rebuildable indexes**. Every session gets a UUID folder. Every model gets its own growing vault. Agents auto-populate those vaults with verbatim transcripts, knowledge graphs, skill files, and traces. The system is Obsidian-compatible, MCP-exposed, locally sovereign, and self-evolving.[^1][^2][^3]

***

## The Core Architecture: Files Over Databases

All three frontier models (GPT-5.4 Thinking, Claude Opus 4.6 Thinking, Gemini 3.1 Pro Thinking) reached independent agreement on the fundamental design:[^1]

- Use **per-model vaults** + **per-session folders** with a stable on-disk schema
- Make **files the canonical source of truth**; every DB or vector index must be rebuildable from files alone
- Adopt a **tiered memory model** (identity → facts → patterns → episodes)
- After each session, auto-write transcript, summary, artifacts, and metadata without exception
- Add **validation in Rust** before committing any agent-written files
- Build a **compiled wiki layer** so knowledge compounds across sessions rather than accumulating as noise[^1]

The single most important architectural decision you will make is this: **never summarize on write, only on retrieval**. MemPalace's 96.6% LongMemEval R@5 score — the highest ever published for any memory tool — comes specifically from raw verbatim storage mode. Every LLM-based summarization approach scores lower because it destroys the "why" behind decisions. Store everything verbatim in `conversation.md`, then use semantic search at retrieval time.[^2][^3]

***

## The Complete Vault Directory Structure

This structure synthesizes llm-wiki's hub/topic hierarchy, My-Brain-Is-Full-Crew's PARA+Zettelkasten layout, and MemPalace's palace/wing/room/drawer hierarchy:[^4][^3][^2]

```
~/PKM/vaults/
├── _registry.json                    # Global hub: all vault registrations
├── _index.md                         # Human + agent-readable top-level index
├── shared/
│   ├── user_profile.md               # Cross-model preferences (injected at every start)
│   └── global_knowledge/             # Shared reference docs across all models
│
├── claude-3-7/                       # ONE vault per model + version
│   ├── .vault_config.json            # Provider, API params, skill settings
│   ├── _index.md                     # All sessions list + memory overview
│   ├── SOUL.md                       # Model identity: tone, persona, core rules
│   ├── log.md                        # Append-only activity log (grep-friendly)
│   ├── skills/
│   │   ├── skills_registry.yaml      # Agent discovery: description-only, lazy load
│   │   ├── vault-init/SKILL.md
│   │   ├── session-resume/SKILL.md
│   │   ├── vault-search/SKILL.md
│   │   └── knowledge-compile/SKILL.md
│   ├── memory/                       # Long-term memory (grows forever, never deleted)
│   │   ├── user_profile.md           # Model-specific user preferences
│   │   ├── decisions.md              # Key decisions accumulated across all sessions
│   │   ├── knowledge.md              # Synthesized facts with confidence scores
│   │   └── chroma_db/               # Local vector embeddings (rebuildable)
│   ├── graph/
│   │   ├── graph.json                # Cross-session knowledge graph (graphify)
│   │   └── GRAPH_REPORT.md          # God nodes, community clusters, surprises
│   └── sessions/
│       └── 2026-04-08_abc12345/      # UUID session folder
│           ├── session.json          # ID, model, provider, timestamps, tags, token_count
│           ├── conversation.md       # VERBATIM full conversation (immutable, append-only)
│           ├── summary.md            # 9-section compaction summary (written on close)
│           ├── knowledge.md          # Session-specific insights extracted
│           ├── trace.json            # All tool calls, timings, outcomes
│           ├── context.json          # System prompt snapshot, model params used
│           ├── diffs/                # Agent-made file changes during session
│           ├── manifest.json         # What files were created/modified, performance metrics
│           └── artifacts/            # Code, docs, images generated during session
│
├── gpt-4o/
│   └── ... (same structure)
├── gemini-2-flash/
│   └── ... (same structure)
└── local-qwen3-27b/
    └── ... (same structure)
```

The `_registry.json` hub is a lightweight pointer registry — it contains only vault IDs and paths, never content. The `_index.md` in every directory forces agents to follow a structured navigation pathway rather than blind-scanning, cutting token consumption dramatically.[^3][^4]

***

## Session Lifecycle — What Happens Automatically

### On Session Start

1. `SessionManager` (Rust) generates UUID: `2026-04-08T00-27-00_abc12345`
2. Creates folder at `vaults/{model}/sessions/{session_id}/`
3. Writes `session.json` + `context.json` (system prompt, model params snapshot)
4. Reads `_registry.json` → loads vault → reads `SOUL.md` (Layer 4: permanent identity)
5. Reads `memory/decisions.md` + top-N `memory/knowledge.md` facts (Layer 3: long-term)
6. Runs semantic search in ChromaDB: top-K prior sessions by relevance → injected as Layer 3 context
7. Reads `GRAPH_REPORT.md` → injects "god nodes" as 170-token wake-up context (MemPalace pattern)[^5]
8. Assembles system prompt: static sections (SOUL.md, cached) + dynamic sections (session ID, vault path, relevant memory)[^2]
9. Starts async `TranscriptWriter` in Rust: append-only writes to `conversation.md`

### During Session

- Every turn appended verbatim to `conversation.md` — never summarized, never truncated[^2]
- All tool calls + outcomes appended to `trace.json` in structured JSON spans[^3]
- Files created by agent written to `artifacts/`, tracked in `manifest.json`
- `ContextMonitor` watches token fill percentage — at **80% fill**, triggers background compaction[^2]
- Compaction writes `summary.md` in 9-section format (from claude-code-analysis pattern), older turns replaced in *context* by summary but remain verbatim in `conversation.md`[^4][^1]
- **Doom loop detection**: if agent repeats identical tool calls 3× → surface warning, optionally terminate[^2]

### On Session End

1. Finalizes `session.json` with end timestamp, total tokens, outcome tag
2. Runs **autoDream consolidation** — background process audits session memory: prunes resolved workarounds, merges scattered notes on same topic, restructures for retrieval speed[^4]
3. Runs graphify pipeline on session folder → `graph.json` + `GRAPH_REPORT.md` updated[^3]
4. **Connector agent** merges session insights into `memory/knowledge.md` (one level up, permanent)
5. Updates vault's `_index.md` with new session entry + tags
6. Chunks `conversation.md` → embeds → stores in `memory/chroma_db/` for future semantic search
7. Background: GEPA reads `trace.json` → proposes skill updates in `skills/` if patterns found[^2]

***

## The 5-Tier Memory Model

All three frontier models independently converged on this hierarchy:[^5][^1]

| Tier | Name | Content | Injects At | Survives |
|------|------|---------|-----------|---------|
| **L4** | Identity | `SOUL.md`, `USER.md` | Always, 100% | Forever |
| **L3** | Facts | `memory/knowledge.md`, `decisions.md` | Always, truncated | Forever |
| **L2** | Patterns | `skills/`, `GRAPH_REPORT.md` | Usually | Until evolved |
| **L1** | Episodes | Relevant prior `summary.md` files | On semantic match | Until pruned |
| **L0** | Working | Current `conversation.md` turns | Live in context | Session only |

The rule: **always inject L4+L3, usually inject L2, retrieve L1 only when semantically relevant**. This prevents context saturation on local 1B-4B models while still giving agents meaningful historical context.[^5][^1]

The **decay scoring system** ensures the vault doesn't become noise over time: facts get a confidence score that decays exponentially over time (~69-day half-life) unless reinforced by new sessions. When new information contradicts old facts, the system flags a **contradiction card** — surfaced in the sidebar as a conflict to resolve rather than silently overwriting. This "alive memory" ingredient is what Claude Opus 4.6 Thinking identified as the differentiator between memory that *feels real* and memory that feels robotic.[^6][^1]

***

## The Knowledge Graph System

Graphify delivers the core insight for your app: instead of re-reading raw session files to answer "what did we decide about X?", agents query a compact `graph.json` that delivers a **71.5x token reduction** vs. reading raw files. The graph runs in two passes:[^6][^2]

**Pass 1 — Deterministic AST (no LLM, zero cost, 100% accurate):**
- tree-sitter extracts classes, functions, imports, call graphs from your `.swift` and `.rs` files
- This means your *actual codebase* becomes part of the knowledge graph automatically

**Pass 2 — Semantic LLM pass (vision + text):**
- Claude subagents extract concepts and relationships from session markdown, PDFs, and diagrams
- Every edge tagged: `EXTRACTED` (confidence 1.0), `INFERRED` (0.0–1.0), or `AMBIGUOUS` (flagged for review)[^6]

Leiden community detection clusters the graph by edge density, not just vector similarity — so the agent can hop across the graph and find "surprising connections" that pure embedding search would miss entirely. The `GRAPH_REPORT.md` highlights "god nodes" (highest centrality concepts) and is injected into every new session as a 170-token pre-context brief.[^4][^5]

Run graphify after every session close:
```bash
# Via file-based IPC to your Python agent subprocess
/graphify ~/PKM/vaults/claude-3-7/ --obsidian --update --watch
```

The `--obsidian` flag makes the entire vault viewable in Obsidian with full wikilink graph view — giving you a human-auditable window into exactly what your agents know.[^3]

***

## The Dispatcher + Skill Routing System

When any agent session opens, a **dispatcher evaluates intent first** before sending to a model — this is the My-Brain-Is-Full-Crew pattern:[^4][^3]

```
User → Dispatcher
  → "new project"       → vault-init SKILL.md
  → "continue from X"   → session-resume SKILL.md (injects prior context)
  → "what did we decide"→ vault-search SKILL.md (semantic ChromaDB query)
  → "review my code"    → agent + graphify graph context + code skills
  → "quick question"    → direct agent, minimal vault injection
```

Skills are `SKILL.md` files using the SciAgent-Skills template format: frontmatter with `name`, `description`, `license` → overview → prerequisites → quick start → workflow → key params → troubleshooting. Critically, **agents read only the `description` field during planning** and load the full skill file only when selected — lazy loading means you can have hundreds of skills with zero context cost at planning time.[^2]

The `skills_registry.yaml` in each vault is the agent's phone book. Built-in skills to ship with the vault system:

| Skill | Trigger Condition | Action |
|-------|-------------------|--------|
| `vault-init` | New session / new project | Creates session folder, initializes structure |
| `session-resume` | "Continue last time" / similar prior session found | Loads prior context, injects into system prompt |
| `vault-search` | "What did we decide about X?" | Semantic search across all sessions |
| `knowledge-compile` | On session close | Distills session into `knowledge/` articles |
| `vault-audit` | Weekly / manual trigger | Broken links, orphans, dedup, health report |
| `graph-rebuild` | After N sessions | Runs graphify, updates GRAPH_REPORT.md |
| `contradiction-resolve` | Conflict card detected | Surfaces conflicting facts for user review |
| `skill-evolve` | After N trace analyses | GEPA proposes skill_v2.md for approval |

***

## The Self-Evolution Loop

This is the feature that separates your app from *everything else that exists*. After accumulating session history, the Hermes GEPA (Genetic-Pareto Prompt Evolution) loop reads your `trace.json` files to understand *why* agent calls succeeded or failed — not just that they did:[^5][^4]

```
Sessions accumulate → trace.json files written
         ↓
Background job reads N traces (after each session or nightly)
         ↓
GEPA/DSPy: understands failure modes, proposes mutations to skill files
         ↓
Constraint gates: 100% pytest pass, size ≤ 15KB, semantic preservation
         ↓
Proposes skill_v2.md in vault → you review diff in sidebar → approve/reject
         ↓
Approved skill injected at next session start → better outcomes
         ↓
Better outcomes → better traces → skills evolve further
```

After 50–100 sessions, your model vaults contain *your* custom-evolved skills shaped by your exact usage patterns — something no static memory tool can replicate. The 4-tier evolution target hierarchy from the research: Tier 1 = SKILL.md files (DSPy mutations), Tier 2 = tool JSON schemas (GEPA), Tier 3 = system prompts (MIPROv2), Tier 4 = actual Rust/Swift source (Darwinian Evolver — experimental).[^4][^2]

All evolutions are **human-in-the-loop**: they appear as "proposed changes" in the sidebar, never auto-committed. This keeps the system fully under your control.[^4]

***

## The FFI Performance Architecture

Your Swift 6 + Rust FFI stack maps perfectly to the memory system's requirements:[^5]

### Swift 6 Concurrency Layer (UI + Coordination)
- `SessionManager` as a Swift `Actor` — guarantees isolated mutable state for session tracking
- `VaultManager` reads `_registry.json` on app launch, exposes vault list to SwiftUI sidebar via `@Published`
- `NavigationSplitView` + `LazyVStack` for vault sidebar — handles thousands of sessions efficiently
- `AppCoordinator` for dependency injection: each view only gets the vault service it needs[^6]

### Rust FFI Layer (Performance Core)
- `TranscriptWriter`: async JSONL/MD append writer, handles concurrent writes via Rust ownership, zero data races
- `VaultEngine`: UUID generation, directory creation, file lock management
- `GraphEngine`: petgraph + Leiden community detection (port graphify's NetworkX logic to Rust petgraph)
- `SearchEngine`: SQLite with FTS5 full-text search + fastembed vector embeddings — hybrid retrieval via Reciprocal Rank Fusion (RRF)[^6]

### The Zero-Copy IPC Optimization
Standard UniFFI has ~1,416ns overhead per integer call and ~12,817,000ns for struct generation. For the hot path (streaming transcript writes, real-time token counting), use a **lock-free ring buffer in shared memory** instead: pad atomic indices to 128-byte cache line boundaries to prevent false sharing between Swift's head pointer and Rust's tail pointer. This eliminates all syscall and mutex overhead in the write path.[^5]

### File-Based IPC for Agent Coordination
For Swift ↔ Python agent subprocess communication (graphify, ChromaDB, GEPA), use the Claude Code file-based IPC mailbox pattern: Swift writes task JSON to `~/.pkm/ipc/tasks/`, Python agent polls every 500ms, writes results to `~/.pkm/ipc/results/`. No sockets needed, fully inspectable, easy to debug.[^1][^2]

***

## The Multi-Vault Sidebar UI

```
VAULTS                              SESSION: 2026-04-08_abc12345
──────────────────────────          ──────────────────────────────
🟢 Claude 3.7 Sonnet   142 sess     Model:   Claude 3.7 Sonnet
🔵 GPT-4o               38 sess     Started: 12:27 AM
🟡 Qwen3.5-27B Local    67 sess     Tags:    [rust] [ffi] [memory]
⚪ Claude 3 Opus        12 sess     Context: 43% filled
                                    Linked:  3 similar sessions
[+ Add Vault]
[⚙ Vault Settings]                 CONFLICTS (1)
                                    ⚠ decisions.md: FFI bridge pattern
SKILLS (claude-3-7)                 contradicts session 2026-03-14
─────────────────────────
vault-init       v1.2               GRAPH
session-resume   v2.0    evolved    📊 God nodes: Vault, Session, FFI
vault-search     v1.1               📊 Communities: 4 active
knowledge-compile v1.0              Last built: 2026-04-07
```

**Vault autoload logic**: on app launch, scan `~/PKM/vaults/`, read `_registry.json`, instantiate `VaultManager` in Rust via FFI, expose to SwiftUI as `@EnvironmentObject`.[^3]

**Sidebar sections:**
- **Model Vaults** — auto-loaded from discovered providers, shows session count + last active date, badge 🟢 active / 🔵 new memory / ⚪ idle
- **Custom Vaults** — tap "+" to add any folder on disk (can be an existing Obsidian vault or corpus)
- **Shared Vault** — always present: `user_profile.md`, global knowledge, cross-model preferences
- **Conflict Cards** — surfaced when contradiction detection fires; tap to resolve[^1]
- **Skill Evolution Proposals** — pending GEPA proposals awaiting your approval[^4]

Tapping any vault: split view — file tree left, markdown preview right. Sessions grouped by date. Each session shows `session.json` frontmatter inline (tags, model, token count, duration).[^3]

***

## Where the 12 Repos Map to Your Stack

| Priority | Repo | Exact Integration Point |
|----------|------|------------------------|
| 🔥 Critical | **MemPalace** | Verbatim `conversation.md` + ChromaDB semantic search + 19-tool MCP server via Rust FFI bridge[^2] |
| 🔥 Critical | **llm-wiki** | `_registry.json` hub, `_index.md` per dir, dual `[[wikilink]]`+`(path.md)` format, crash recovery[^3] |
| 🔥 Critical | **My-Brain-Is-Full-Crew** | Dispatcher routing logic, PARA vault structure, 8-agent role mapping, "Suggested next agent" chaining[^2][^4] |
| 🔥 Critical | **graphify** | Post-session AST + semantic graph generation, Leiden clustering, `GRAPH_REPORT.md`, `--obsidian` flag[^2][^6] |
| ⚡ High | **open-multi-agent** | SharedMemory across agents, DAG task orchestration, `onTrace` span format for `trace.json` schema[^2] |
| ⚡ High | **PraisonAI** | `auto_save` + `session_id` pattern, shadow git checkpoints, doom loop detection, context compaction trigger[^2][^6] |
| ⚡ High | **hermes-agent-self-evolution** | GEPA skill evolution from `trace.json`, constraint gates, human-in-loop approval, skill versioning[^2][^4] |
| 🔧 Supporting | **metaharness** | `allowed_write_paths` scope enforcement, per-session `manifest.json`, immutable session folders[^2][^6] |
| 🔧 Supporting | **claude-code-analysis** | 80% context compaction trigger, file-based IPC mailbox, static+dynamic system prompt split with cache optimization[^2] |
| 🔧 Supporting | **SciAgent-Skills** | `SKILL.md` template format, `skills_registry.yaml`, lazy description-first loading[^2][^5] |
| 🔧 Supporting | **obsidian-skills** | Obsidian Flavored Markdown as canonical vault format, YAML frontmatter schema, `json-canvas` for session maps[^2] |
| ⚙️ Infra | **llama.cpp-tq3** | TQ3_4S for local Qwen3.5-27B (PPL 6.82 vs Q3_K_S 6.86 at 12.9GiB), asymmetric KV cache (`q8_0-K + turbo4-V`)[^4][^5] |

***

## Where the Frontier Models Disagreed (And the Reconciliation)

Three meaningful disagreements emerged across the research synthesis, each with a clear resolution:[^1]

**1. Vector store choice:** GPT-5.4 preferred `sqlite-vec` (pure native Rust), Claude Opus preferred SQLite + usearch/qdrant, Gemini focused on schema validation first. **Resolution:** Start with SQLite+FTS5 (already in Rust ecosystem, zero external dependencies) for hybrid RRF retrieval. Migrate to usearch if you need scale beyond ~50K sessions. Never ChromaDB as primary — use it only as the Python-side MCP server for agent tool calls while Rust handles the hot-path search.[^1]

**2. Graph layer timing:** Gemini wanted graph-first as the core. GPT-5.4 and Claude Opus wanted vault stability first. **Resolution:** Build vault/session pipeline first, but design the on-disk schema so graph files are rebuildable indexes — add graphify integration in Phase 3 without any migration.[^1]

**3. GEPA/self-evolution timing:** GPT-5.4 called it a "stretch goal", Claude Opus said it's important but later, Gemini stressed guardrails first. **Resolution:** Implement `trace.json` writing from day one (zero cost), but don't wire GEPA until Phase 4 when you have 50+ sessions of history to learn from.[^1]

***

## The autoDream Consolidation Engine

This is the "sleep cycle" for your vault — a background process borrowed from the Claude Code analysis that runs between sessions:[^4]

```
Session ends → autoDream trigger
     ↓
Audit: review session's trace.json + conversation.md for patterns
     ↓
Prune: remove resolved workarounds, temporary fixes, library calls for removed deps
     ↓
Merge: combine scattered notes on same topic into single coherent knowledge.md entry
     ↓
Restructure: reorder memory/knowledge.md so highest-impact decisions surface first
     ↓
Update: refresh SOUL.md user preferences if new preferences detected
     ↓
Contradiction check: compare new facts against existing memory/knowledge.md
  → if conflict found: write conflict card to sidebar queue
  → if reinforcement: boost fact's decay score, extend half-life
```

This process runs asynchronously in a detached Swift Task backed by your Rust subprocess bridge, never blocking the UI. The result: every new session starts with a consolidated, non-noisy view of what your agents have collectively learned — the vault functions as infrastructure, not just chat history.[^4]

***

## The `session.json` Canonical Schema

Every session folder starts with this file, written by `VaultManager` before the first turn:

```json
{
  "id": "2026-04-08T00-27-00_abc12345",
  "model": "claude-3-7-sonnet",
  "provider": "anthropic",
  "vault_id": "claude-3-7",
  "started_at": "2026-04-08T00:27:00Z",
  "ended_at": null,
  "tags": [],
  "token_count": 0,
  "context_fill_pct": 0.0,
  "compaction_triggered": false,
  "skills_loaded": ["vault-search", "session-resume"],
  "prior_sessions_injected": [],
  "graph_nodes_injected": 12,
  "outcome": null
}
```

The `skills_loaded` array records which SKILL.md files were active, `prior_sessions_injected` records which past sessions were retrieved semantically (giving you a full provenance chain for every session), and `graph_nodes_injected` tracks how many knowledge graph nodes were part of the wake-up context.[^3][^2]

***

## The Phased Implementation Roadmap

### Phase 1 — Vault + Session Core (Week 1–2) ← Start Here
**Goal:** Every session auto-creates its folder and writes files.

- `VaultManager.swift` — loads `_registry.json`, Swift Actor for vault state
- `SessionManager.rs` (Rust via FFI) — UUID generation, `FileManager` equivalent in Rust, writes `session.json` + `context.json`
- `TranscriptWriter.rs` (Rust) — async append-only writer to `conversation.md`
- `VaultList` SwiftUI view — sidebar vault list from `_registry.json`, session display
- `session.json` Codable struct in Swift + `serde` struct in Rust

**Deliverable:** Sessions auto-create folders, write verbatim transcripts, appear in sidebar.

### Phase 2 — Memory Injection + Compaction (Week 3–4)
**Goal:** New sessions start with relevant historical context; long sessions don't hit context walls.

- `MemoryLoader.swift` — reads SOUL.md, skills_registry.yaml (description-only), memory/decisions.md
- `ContextMonitor.swift` — tracks token count / fill%, triggers compaction at 80%
- `MemoryCompactor` — Python subprocess via file-based IPC, reads `conversation.md`, writes 9-section `summary.md`
- `autoDream` consolidation job — runs after every session end as async background task
- Static + dynamic system prompt split (cached sections for SOUL.md, dynamic for session context)[^1]

**Deliverable:** Agents start sessions with meaningful prior context, never hit context walls.

### Phase 3 — Semantic Search + Vault Search Skill (Week 5–6)
**Goal:** "What did we decide about X?" works across all sessions.

- SQLite+FTS5 hybrid search engine in Rust — full-text + semantic RRF fusion
- ChromaDB Python MCP server — 19 memory tools exposed via stdio, callable from agents
- `vault-search` SKILL.md — agent tool that queries vault and returns cited session references
- Session chunking + embedding pipeline — runs on `conversation.md` at session close
- Contradiction detection — compare new knowledge.md entries against existing, surface conflict cards[^1]

**Deliverable:** Agents can semantically query all historical sessions with citations.

### Phase 4 — Graphify Integration (Week 7–8)
**Goal:** Cross-session knowledge graph with Leiden clustering.

- graphify integration — run on vault folder post-session, via file-based IPC subprocess
- `graph.json` + `GRAPH_REPORT.md` auto-generated per vault
- God nodes injected as 170-token wake-up context at session start
- `--watch` mode for auto-update on new session files
- `--obsidian` mode so vault is viewable in Obsidian with full graph view[^2]

**Deliverable:** Agents have topological knowledge of the vault, not just vector similarity.

### Phase 5 — Skills System + Dispatcher (Week 9–10)
**Goal:** Intent-aware routing, lazy skill loading, built-in skills library.

- `skills_registry.yaml` in each vault — description-only for planning, full content on demand
- Built-in SKILL.md files: vault-init, session-resume, vault-search, knowledge-compile, vault-audit
- Dispatcher routing logic integrated into session start (lightweight intent classifier)
- "Suggested next agent" signal parsed from model outputs → next agent pre-loaded[^4]

**Deliverable:** Agents route intelligently; vault feels like a real second brain.

### Phase 6 — GEPA Self-Evolution (Post-session accumulation, Week 11+)
**Goal:** Skills improve from actual usage patterns.

- `trace.json` structured span writing already live from Phase 1 — GEPA reads this
- Background GEPA job (Python/DSPy) — runs after every Nth session, proposes `skill_v2.md`
- Constraint gates: 100% test pass, size ≤ 15KB, semantic preservation check[^4]
- "Proposed skill update" UI in sidebar — diff view, approve/reject
- Skill versioning: `skill_v1.md` → `skill_v2.md` with diff log in session vault[^2]

**Deliverable:** The vault system literally gets smarter the more you use it.

***

## The Compound Feature Comparison

| Feature | Claude.ai | ChatGPT | OpenClaw | **Your App** |
|---------|-----------|---------|---------|-------------|
| Session persistence | Projects (manual) | Threads | Minimal | ✅ Auto UUID folders, fully structured |
| Memory accuracy | Summary-based | Summary-based | Minimal | ✅ 96.6% LongMemEval (verbatim) |
| Per-model vaults | ❌ | ❌ | ❌ | ✅ Each model has its own growing vault |
| Knowledge graph | ❌ | ❌ | ❌ | ✅ graphify AST + Leiden semantic graph |
| Contradiction detection | ❌ | ❌ | ❌ | ✅ Conflict cards surfaced in sidebar |
| Local + cloud parity | Cloud only | Cloud only | Mostly cloud | ✅ Same vault system for both |
| Self-evolving skills | ❌ | ❌ | ❌ | ✅ GEPA from real session traces |
| Obsidian-compatible | ❌ | ❌ | ❌ | ✅ Full wikilinks + graph view |
| autoDream consolidation | Partial | ❌ | ❌ | ✅ Background prune/merge/restructure |
| Agent skill routing | ❌ | ❌ | ❌ | ✅ Dispatcher → SKILL.md lazy load |
| Write-scope enforcement | ❌ | ❌ | ❌ | ✅ allowed_write_paths per session |
| Shadow git checkpoints | ❌ | ❌ | ❌ | ✅ Auto-rollback on agent failure |
| Locally sovereign | ❌ | ❌ | Partial | ✅ Files never leave your machine |

***

## Final Synthesis: The Critical Insight You Must Not Miss

The single finding that every research document and every frontier model agrees on — and what makes this genuinely different from every tool you've used — is this:[^5][^1][^4]

> **Memory is not a feature you add to an agent. It is the substrate the agent lives in.**

When your vault is files on disk — verbatim, Obsidian-readable, git-trackable, grep-able, humanly auditable — you have built something categorically different from systems where memory is an opaque API call to a cloud database. You can open Finder and see *exactly* what your agents know, when they learned it, and why. The vault *is* the agent's mind, made visible. That is what makes it feel real. Every other tool hides the memory behind an abstraction. Yours shows it.

The `SOUL.md`, `decisions.md`, `knowledge.md`, `GRAPH_REPORT.md`, and `skills_registry.yaml` together form an inspectable, editable, evolvable cognitive architecture — one that happens to be persisted as ordinary files your text editor can open. That's the north star. Every architectural decision flows from it.[^6][^5][^3][^2][^1]

---

## References

1. [man3.md](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/attachments/20876755/98f93b43-b36c-4ec0-8bae-2e59c84c8a39/man3.md?AWSAccessKeyId=ASIA2F3EMEYEZAWZYNPJ&Signature=LTn%2FwTQ9LYxYiQTa%2F41oIzNHU4I%3D&x-amz-security-token=IQoJb3JpZ2luX2VjEC4aCXVzLWVhc3QtMSJHMEUCIQD5r8UHIgZRR02L%2FhPUmoOU68w2fJf621n5h1Y0M1at6AIgR6pLHMv7bOSQHYjgzyiU69rI5ZCUIYNHADYG6Yc39Kcq%2FAQI9%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2FARABGgw2OTk3NTMzMDk3MDUiDMxCYndJpPhh8rJQqSrQBKQHpiKJGlWwvxla7il5eaYtVVLWrU1nNkqhT%2BVEFrFhbVuiwF5VQ8iKzU7dljYrFPxum0L5iu2nwpi0qde0FqTnOvnl2LqG0nATYQEXtRMfExuZBGX5VbBgl9hM0vxvjQb921cOUyG8%2BDw477dcHz0us6dXvIOlYgDDltNq%2BZrkyBrwSi4XsGRqWeJe7qI4SuASia%2FEi%2FI4zoPQgMHZzi3d9BF1GSurmX4MTZFaIF8XzIQCrOsW7K4sAkQv2mMlv2jIm51AC02qrwyJ%2BSCYCKJnWgTK0YGliHwsX4lFuDASZmJ5jq0WC9eBz3UKIhxni7PbptQPpJNcvNgsDZZyUZE5fi24p5T1mooTNF9j%2FEaZaccBO%2BUgMy92JdoHqfHy2KTkpLaAwDnXzBqzGcm0EbFy4a0Kx1ZTRuhqkmL1FvxmkAqyEJhmKOtlPTBfipG6Imsl3uS6RIQvC9gUa6JlLrl4Ue9ImIIUQHUDsMv4DWqmeVfGkLnA9bZCT8Pk2FHdc%2BhS6b872eJcdwM7VhhAYmoVmfuzi8oe4x4%2BakPV7zquMyMj8SrI4GLZGkdXvwopnXjI55GEwupf%2FHFqRt3Z0iZqQv1ecSrixD1OAhualTr1LxZipfmqibpNT8O%2FaOoRRlE3qbxoVlpj9APv6COfQzhqWQHKVrW10YNHz561Da58qvZwNib%2B6LJRsNqlFq6pYzTHvhS1EhGHnuApi4n7byPxBaquOOnqF9njb8uHqvrmp08J2TZPiuk%2Bn%2BQeqRB%2F03nXVqwpb%2F8H%2F1inovGy9qUw4NLXzgY6mAFKqTW2Cr120dZ5xvHIWOyNDihkwKLzvVDyj4pQjRUojbsxt%2FFcmkxt9X4P45O61dszHgUR%2B%2F4005A2OTjI4X2jajjGpq8PXh6T0vMRO0VY3OWQHL6NUPZ1uu92XPSOHJg%2FpCBbSYhYNGC3MaFj4N%2BI%2FPJlUxKtiLycxVQPoCDSWRdYKdUJtv5NCd3pDeqPg5gB5BslRl8KoQ%3D%3D&Expires=1775630131) - <img src="https://r2cdn.perplexity.ai/pplx-full-logo-primary-dark%402x.png" style="height:64px;margi...

2. [man4-5.md](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/attachments/20876755/acfe5e5b-2d61-4da3-8fc4-ff3ff4c1259c/man4-5.md?AWSAccessKeyId=ASIA2F3EMEYEZAWZYNPJ&Signature=tluo13ByBJP79JqyrALR6JB6z8c%3D&x-amz-security-token=IQoJb3JpZ2luX2VjEC4aCXVzLWVhc3QtMSJHMEUCIQD5r8UHIgZRR02L%2FhPUmoOU68w2fJf621n5h1Y0M1at6AIgR6pLHMv7bOSQHYjgzyiU69rI5ZCUIYNHADYG6Yc39Kcq%2FAQI9%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2FARABGgw2OTk3NTMzMDk3MDUiDMxCYndJpPhh8rJQqSrQBKQHpiKJGlWwvxla7il5eaYtVVLWrU1nNkqhT%2BVEFrFhbVuiwF5VQ8iKzU7dljYrFPxum0L5iu2nwpi0qde0FqTnOvnl2LqG0nATYQEXtRMfExuZBGX5VbBgl9hM0vxvjQb921cOUyG8%2BDw477dcHz0us6dXvIOlYgDDltNq%2BZrkyBrwSi4XsGRqWeJe7qI4SuASia%2FEi%2FI4zoPQgMHZzi3d9BF1GSurmX4MTZFaIF8XzIQCrOsW7K4sAkQv2mMlv2jIm51AC02qrwyJ%2BSCYCKJnWgTK0YGliHwsX4lFuDASZmJ5jq0WC9eBz3UKIhxni7PbptQPpJNcvNgsDZZyUZE5fi24p5T1mooTNF9j%2FEaZaccBO%2BUgMy92JdoHqfHy2KTkpLaAwDnXzBqzGcm0EbFy4a0Kx1ZTRuhqkmL1FvxmkAqyEJhmKOtlPTBfipG6Imsl3uS6RIQvC9gUa6JlLrl4Ue9ImIIUQHUDsMv4DWqmeVfGkLnA9bZCT8Pk2FHdc%2BhS6b872eJcdwM7VhhAYmoVmfuzi8oe4x4%2BakPV7zquMyMj8SrI4GLZGkdXvwopnXjI55GEwupf%2FHFqRt3Z0iZqQv1ecSrixD1OAhualTr1LxZipfmqibpNT8O%2FaOoRRlE3qbxoVlpj9APv6COfQzhqWQHKVrW10YNHz561Da58qvZwNib%2B6LJRsNqlFq6pYzTHvhS1EhGHnuApi4n7byPxBaquOOnqF9njb8uHqvrmp08J2TZPiuk%2Bn%2BQeqRB%2F03nXVqwpb%2F8H%2F1inovGy9qUw4NLXzgY6mAFKqTW2Cr120dZ5xvHIWOyNDihkwKLzvVDyj4pQjRUojbsxt%2FFcmkxt9X4P45O61dszHgUR%2B%2F4005A2OTjI4X2jajjGpq8PXh6T0vMRO0VY3OWQHL6NUPZ1uu92XPSOHJg%2FpCBbSYhYNGC3MaFj4N%2BI%2FPJlUxKtiLycxVQPoCDSWRdYKdUJtv5NCd3pDeqPg5gB5BslRl8KoQ%3D%3D&Expires=1775630131) - # Session Vault Memory System — Deep Repo Analysis & Implementation Blueprint

## Executive Summary
...

3. [man6-6.md](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/attachments/20876755/fe798652-6021-4087-8dce-ae8b71ac4099/man6-6.md?AWSAccessKeyId=ASIA2F3EMEYEZAWZYNPJ&Signature=vauuTMvD9DmEzqu4XWS6b9qXhXI%3D&x-amz-security-token=IQoJb3JpZ2luX2VjEC4aCXVzLWVhc3QtMSJHMEUCIQD5r8UHIgZRR02L%2FhPUmoOU68w2fJf621n5h1Y0M1at6AIgR6pLHMv7bOSQHYjgzyiU69rI5ZCUIYNHADYG6Yc39Kcq%2FAQI9%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2FARABGgw2OTk3NTMzMDk3MDUiDMxCYndJpPhh8rJQqSrQBKQHpiKJGlWwvxla7il5eaYtVVLWrU1nNkqhT%2BVEFrFhbVuiwF5VQ8iKzU7dljYrFPxum0L5iu2nwpi0qde0FqTnOvnl2LqG0nATYQEXtRMfExuZBGX5VbBgl9hM0vxvjQb921cOUyG8%2BDw477dcHz0us6dXvIOlYgDDltNq%2BZrkyBrwSi4XsGRqWeJe7qI4SuASia%2FEi%2FI4zoPQgMHZzi3d9BF1GSurmX4MTZFaIF8XzIQCrOsW7K4sAkQv2mMlv2jIm51AC02qrwyJ%2BSCYCKJnWgTK0YGliHwsX4lFuDASZmJ5jq0WC9eBz3UKIhxni7PbptQPpJNcvNgsDZZyUZE5fi24p5T1mooTNF9j%2FEaZaccBO%2BUgMy92JdoHqfHy2KTkpLaAwDnXzBqzGcm0EbFy4a0Kx1ZTRuhqkmL1FvxmkAqyEJhmKOtlPTBfipG6Imsl3uS6RIQvC9gUa6JlLrl4Ue9ImIIUQHUDsMv4DWqmeVfGkLnA9bZCT8Pk2FHdc%2BhS6b872eJcdwM7VhhAYmoVmfuzi8oe4x4%2BakPV7zquMyMj8SrI4GLZGkdXvwopnXjI55GEwupf%2FHFqRt3Z0iZqQv1ecSrixD1OAhualTr1LxZipfmqibpNT8O%2FaOoRRlE3qbxoVlpj9APv6COfQzhqWQHKVrW10YNHz561Da58qvZwNib%2B6LJRsNqlFq6pYzTHvhS1EhGHnuApi4n7byPxBaquOOnqF9njb8uHqvrmp08J2TZPiuk%2Bn%2BQeqRB%2F03nXVqwpb%2F8H%2F1inovGy9qUw4NLXzgY6mAFKqTW2Cr120dZ5xvHIWOyNDihkwKLzvVDyj4pQjRUojbsxt%2FFcmkxt9X4P45O61dszHgUR%2B%2F4005A2OTjI4X2jajjGpq8PXh6T0vMRO0VY3OWQHL6NUPZ1uu92XPSOHJg%2FpCBbSYhYNGC3MaFj4N%2BI%2FPJlUxKtiLycxVQPoCDSWRdYKdUJtv5NCd3pDeqPg5gB5BslRl8KoQ%3D%3D&Expires=1775630131) - # Vault-Based Session Memory System for Your Swift 6 + Rust FFI PKM Agent App

## Executive Summary
...

4. [man-2.txt](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/attachments/20876755/4d8430f0-5545-4169-811f-4e2eff44f321/man-2.txt?AWSAccessKeyId=ASIA2F3EMEYEZAWZYNPJ&Signature=QE9INmybLd81l8Th3h0y0ekj3FI%3D&x-amz-security-token=IQoJb3JpZ2luX2VjEC4aCXVzLWVhc3QtMSJHMEUCIQD5r8UHIgZRR02L%2FhPUmoOU68w2fJf621n5h1Y0M1at6AIgR6pLHMv7bOSQHYjgzyiU69rI5ZCUIYNHADYG6Yc39Kcq%2FAQI9%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2FARABGgw2OTk3NTMzMDk3MDUiDMxCYndJpPhh8rJQqSrQBKQHpiKJGlWwvxla7il5eaYtVVLWrU1nNkqhT%2BVEFrFhbVuiwF5VQ8iKzU7dljYrFPxum0L5iu2nwpi0qde0FqTnOvnl2LqG0nATYQEXtRMfExuZBGX5VbBgl9hM0vxvjQb921cOUyG8%2BDw477dcHz0us6dXvIOlYgDDltNq%2BZrkyBrwSi4XsGRqWeJe7qI4SuASia%2FEi%2FI4zoPQgMHZzi3d9BF1GSurmX4MTZFaIF8XzIQCrOsW7K4sAkQv2mMlv2jIm51AC02qrwyJ%2BSCYCKJnWgTK0YGliHwsX4lFuDASZmJ5jq0WC9eBz3UKIhxni7PbptQPpJNcvNgsDZZyUZE5fi24p5T1mooTNF9j%2FEaZaccBO%2BUgMy92JdoHqfHy2KTkpLaAwDnXzBqzGcm0EbFy4a0Kx1ZTRuhqkmL1FvxmkAqyEJhmKOtlPTBfipG6Imsl3uS6RIQvC9gUa6JlLrl4Ue9ImIIUQHUDsMv4DWqmeVfGkLnA9bZCT8Pk2FHdc%2BhS6b872eJcdwM7VhhAYmoVmfuzi8oe4x4%2BakPV7zquMyMj8SrI4GLZGkdXvwopnXjI55GEwupf%2FHFqRt3Z0iZqQv1ecSrixD1OAhualTr1LxZipfmqibpNT8O%2FaOoRRlE3qbxoVlpj9APv6COfQzhqWQHKVrW10YNHz561Da58qvZwNib%2B6LJRsNqlFq6pYzTHvhS1EhGHnuApi4n7byPxBaquOOnqF9njb8uHqvrmp08J2TZPiuk%2Bn%2BQeqRB%2F03nXVqwpb%2F8H%2F1inovGy9qUw4NLXzgY6mAFKqTW2Cr120dZ5xvHIWOyNDihkwKLzvVDyj4pQjRUojbsxt%2FFcmkxt9X4P45O61dszHgUR%2B%2F4005A2OTjI4X2jajjGpq8PXh6T0vMRO0VY3OWQHL6NUPZ1uu92XPSOHJg%2FpCBbSYhYNGC3MaFj4N%2BI%2FPJlUxKtiLycxVQPoCDSWRdYKdUJtv5NCd3pDeqPg5gB5BslRl8KoQ%3D%3D&Expires=1775630131) - ﻿Architectural Optimization for Persistent Agentic Memory: A Multi-Vault Framework for Swift and Rus...

5. [man5-4.txt](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/attachments/20876755/57f21992-6dd3-43f2-b952-b9447a7fc879/man5-4.txt?AWSAccessKeyId=ASIA2F3EMEYEZAWZYNPJ&Signature=y2AJDjsplrU9feh3Fy5zrOsWzzc%3D&x-amz-security-token=IQoJb3JpZ2luX2VjEC4aCXVzLWVhc3QtMSJHMEUCIQD5r8UHIgZRR02L%2FhPUmoOU68w2fJf621n5h1Y0M1at6AIgR6pLHMv7bOSQHYjgzyiU69rI5ZCUIYNHADYG6Yc39Kcq%2FAQI9%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2FARABGgw2OTk3NTMzMDk3MDUiDMxCYndJpPhh8rJQqSrQBKQHpiKJGlWwvxla7il5eaYtVVLWrU1nNkqhT%2BVEFrFhbVuiwF5VQ8iKzU7dljYrFPxum0L5iu2nwpi0qde0FqTnOvnl2LqG0nATYQEXtRMfExuZBGX5VbBgl9hM0vxvjQb921cOUyG8%2BDw477dcHz0us6dXvIOlYgDDltNq%2BZrkyBrwSi4XsGRqWeJe7qI4SuASia%2FEi%2FI4zoPQgMHZzi3d9BF1GSurmX4MTZFaIF8XzIQCrOsW7K4sAkQv2mMlv2jIm51AC02qrwyJ%2BSCYCKJnWgTK0YGliHwsX4lFuDASZmJ5jq0WC9eBz3UKIhxni7PbptQPpJNcvNgsDZZyUZE5fi24p5T1mooTNF9j%2FEaZaccBO%2BUgMy92JdoHqfHy2KTkpLaAwDnXzBqzGcm0EbFy4a0Kx1ZTRuhqkmL1FvxmkAqyEJhmKOtlPTBfipG6Imsl3uS6RIQvC9gUa6JlLrl4Ue9ImIIUQHUDsMv4DWqmeVfGkLnA9bZCT8Pk2FHdc%2BhS6b872eJcdwM7VhhAYmoVmfuzi8oe4x4%2BakPV7zquMyMj8SrI4GLZGkdXvwopnXjI55GEwupf%2FHFqRt3Z0iZqQv1ecSrixD1OAhualTr1LxZipfmqibpNT8O%2FaOoRRlE3qbxoVlpj9APv6COfQzhqWQHKVrW10YNHz561Da58qvZwNib%2B6LJRsNqlFq6pYzTHvhS1EhGHnuApi4n7byPxBaquOOnqF9njb8uHqvrmp08J2TZPiuk%2Bn%2BQeqRB%2F03nXVqwpb%2F8H%2F1inovGy9qUw4NLXzgY6mAFKqTW2Cr120dZ5xvHIWOyNDihkwKLzvVDyj4pQjRUojbsxt%2FFcmkxt9X4P45O61dszHgUR%2B%2F4005A2OTjI4X2jajjGpq8PXh6T0vMRO0VY3OWQHL6NUPZ1uu92XPSOHJg%2FpCBbSYhYNGC3MaFj4N%2BI%2FPJlUxKtiLycxVQPoCDSWRdYKdUJtv5NCd3pDeqPg5gB5BslRl8KoQ%3D%3D&Expires=1775630131) - ﻿Unified Architectural Framework for High-Performance Agentic PKM Systems: A Synthesis of Swift 6 Co...

6. [man2-3.txt](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/attachments/20876755/1a4ace17-be44-427f-a042-d07f45f31a90/man2-3.txt?AWSAccessKeyId=ASIA2F3EMEYEZAWZYNPJ&Signature=arXwuUQ11MKY5wOs6GulDnd9Mgg%3D&x-amz-security-token=IQoJb3JpZ2luX2VjEC4aCXVzLWVhc3QtMSJHMEUCIQD5r8UHIgZRR02L%2FhPUmoOU68w2fJf621n5h1Y0M1at6AIgR6pLHMv7bOSQHYjgzyiU69rI5ZCUIYNHADYG6Yc39Kcq%2FAQI9%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2FARABGgw2OTk3NTMzMDk3MDUiDMxCYndJpPhh8rJQqSrQBKQHpiKJGlWwvxla7il5eaYtVVLWrU1nNkqhT%2BVEFrFhbVuiwF5VQ8iKzU7dljYrFPxum0L5iu2nwpi0qde0FqTnOvnl2LqG0nATYQEXtRMfExuZBGX5VbBgl9hM0vxvjQb921cOUyG8%2BDw477dcHz0us6dXvIOlYgDDltNq%2BZrkyBrwSi4XsGRqWeJe7qI4SuASia%2FEi%2FI4zoPQgMHZzi3d9BF1GSurmX4MTZFaIF8XzIQCrOsW7K4sAkQv2mMlv2jIm51AC02qrwyJ%2BSCYCKJnWgTK0YGliHwsX4lFuDASZmJ5jq0WC9eBz3UKIhxni7PbptQPpJNcvNgsDZZyUZE5fi24p5T1mooTNF9j%2FEaZaccBO%2BUgMy92JdoHqfHy2KTkpLaAwDnXzBqzGcm0EbFy4a0Kx1ZTRuhqkmL1FvxmkAqyEJhmKOtlPTBfipG6Imsl3uS6RIQvC9gUa6JlLrl4Ue9ImIIUQHUDsMv4DWqmeVfGkLnA9bZCT8Pk2FHdc%2BhS6b872eJcdwM7VhhAYmoVmfuzi8oe4x4%2BakPV7zquMyMj8SrI4GLZGkdXvwopnXjI55GEwupf%2FHFqRt3Z0iZqQv1ecSrixD1OAhualTr1LxZipfmqibpNT8O%2FaOoRRlE3qbxoVlpj9APv6COfQzhqWQHKVrW10YNHz561Da58qvZwNib%2B6LJRsNqlFq6pYzTHvhS1EhGHnuApi4n7byPxBaquOOnqF9njb8uHqvrmp08J2TZPiuk%2Bn%2BQeqRB%2F03nXVqwpb%2F8H%2F1inovGy9qUw4NLXzgY6mAFKqTW2Cr120dZ5xvHIWOyNDihkwKLzvVDyj4pQjRUojbsxt%2FFcmkxt9X4P45O61dszHgUR%2B%2F4005A2OTjI4X2jajjGpq8PXh6T0vMRO0VY3OWQHL6NUPZ1uu92XPSOHJg%2FpCBbSYhYNGC3MaFj4N%2BI%2FPJlUxKtiLycxVQPoCDSWRdYKdUJtv5NCd3pDeqPg5gB5BslRl8KoQ%3D%3D&Expires=1775630131) - ﻿Autonomous Personal Knowledge Management: Architecting a High-Fidelity, Multi-Vault Session Memory ...

