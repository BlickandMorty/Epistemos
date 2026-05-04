# Session Vault Memory System — Deep Repo Analysis & Implementation Blueprint

## Executive Summary

After deep analysis of all 12 repositories, the core insight is this: your app has the opportunity to implement the most architecturally coherent memory system in any LLM app today — one that beats Claude.ai, OpenClaw, and ChatGPT's memory layers by being *structural from the ground up*, not bolted on. Every session gets its own folder with a UUID, every model gets its own growing vault, and agents auto-populate those vaults with verbatim transcripts, summaries, knowledge graphs, tool traces, and skill files. The system is Obsidian-compatible, MCP-exposed, locally sovereign, and self-evolving.

***

## Repo-by-Repo Analysis

### 1. MemPalace — The Crown Jewel for Raw Storage

MemPalace (milla-jovovich/mempalace) scored **96.6% on LongMemEval R@5** in raw verbatim mode — the highest ever published, free or paid — by doing the opposite of what most memory systems do: it stores everything without summarization and makes it findable through semantic search on ChromaDB. The palace metaphor maps directly to your use case: wings = model vaults, halls = session categories, rooms = individual sessions.

The critical architectural lesson: **do not burn LLM tokens deciding what is "worth" remembering**. Store the full verbatim transcript, index it semantically, retrieve with semantic search later. The AAAK compression dialect (84.2% vs raw 96.6%) is honest about being lossy — only use it when you need to pack context at scale, not as the default.

The MCP server exposing 19 tools is directly usable in your Swift app via the existing Rust FFI bridge. The Python API (`from mempalace.searcher import search_memories`) can be called from your local model process.

**What to cherry-pick:** Raw verbatim JSONL transcript storage per session + ChromaDB semantic search + `mempalace mine --mode convos` pattern for session ingestion. Do not use AAAK by default.

***

### 2. graphify — Knowledge Graph per Session

Graphify (safishamsi/graphify) runs in two passes: a deterministic AST pass over code (no LLM, 19 languages via tree-sitter including Swift and Rust) and parallel Claude subagents over docs/images to extract concepts and relationships. The result is a NetworkX graph with Leiden community detection and output as interactive HTML, queryable JSON, and Obsidian vault.

The **71.5x token reduction** at scale (52 files including papers and images) is the headline number that matters for your app: instead of re-reading a session's raw files to answer "what did we decide about X?", you query the compact `graph.json`. Every relationship is tagged EXTRACTED / INFERRED / AMBIGUOUS with confidence scores.

For your app, run `/graphify` on each session folder after the session ends. It produces `graphify-out/graph.json` and `GRAPH_REPORT.md` that become the session's persistent knowledge index. The `--obsidian` flag writes an Obsidian-compatible vault directly into the session folder.

**What to cherry-pick:** Post-session graphification pipeline. The `--watch` mode for auto-sync as session files accumulate. The `--wiki` flag to generate agent-navigable markdown articles per session community. MCP stdio server mode for exposing session graphs to your agents.

***

### 3. llm-wiki — Hub/Topic/Article Hierarchy = Your Vault Architecture

nvk/llm-wiki provides the cleanest structural template for the vault architecture. The hub (`~/wiki/`) is just a registry — it contains `wikis.json` and `_index.md` but no content. All content lives in topic sub-wikis with isolated `.obsidian/` configs, `raw/` (immutable sources), `wiki/` (compiled articles), and `output/` (generated artifacts).

Map this directly to your app:
- `~/AppVaults/` = hub (registry only)
- `models/claude-opus/` = topic wiki (has its own vault config)
- `sessions/2026-04-08_abc123/` = article directory

The **dual-link format** — `[[wikilinks]]` AND `(relative/path.md)` on every cross-reference — means your session files work in Obsidian's graph view, in your Swift app's file browser, in any markdown viewer, and in agent context. The `_index.md` navigation pattern means agents never scan blindly; they read the index first.

**What to cherry-pick:** Hub/registry architecture. `_index.md` in every directory. Dual-link format for all cross-references. The research modes (5/8/10 parallel agents) for deep session research on demand. The `/wiki:query` pattern for semantic Q&A against accumulated vault content.

***

### 4. My-Brain-Is-Full-Crew — Dispatcher + Agent Crew Pattern

gnekt/My-Brain-Is-Full-Crew provides the most battle-tested multi-agent dispatch architecture. The dispatcher checks skills first (complex multi-step: onboarding, triage, audits), falls through to agents if no skill matches (quick reactive: capture, search, create). The crew coordinates via "Suggested next agent" in output — no hard-coded chains, emergent coordination.

The 8-agent/13-skill breakdown maps perfectly to your app's agent session lifecycle:

| Their Agent | Your App Role |
|-------------|--------------|
| Scribe | Session transcript writer |
| Sorter | Session folder router / auto-tagger |
| Seeker | Vault semantic search across sessions |
| Connector | Cross-session knowledge linker |
| Librarian | Vault health checks, broken links, dedup |
| Architect | New model vault setup + folder structure |
| Transcriber | Audio/voice session → structured notes |

The PARA + Zettelkasten structure (00-Inbox → 07-Daily + MOC + Meta) inside each model vault gives agents a mental model for where to file things.

**What to cherry-pick:** Dispatcher routing logic (skill-first, then agent). Agent chaining via "Suggested next agent." The PARA structure inside each model vault. The `Meta/` folder for agent logs and vault health reports. Any-language response capability for international users.

***

### 5. PraisonAI — Session Persistence API Patterns

PraisonAI (MervinPraison/PraisonAI) provides the most complete production-grade session persistence layer. The `auto_save="session-name"` + `session_id` pattern is exactly the instantiation you want. The agent instantiates in **3.77μs** — negligible overhead when creating per-session contexts.

Key features worth implementing:

- **Graph Memory** (Neo4j-style): tracks relationships between concepts across sessions and models — your cross-session knowledge linker
- **Shadow git checkpoints**: rollback on agent failure, every N turns — maps to your session `artifacts/` folder
- **Doom Loop Detection**: catches stuck agents repeating tool calls — critical for production robustness
- **Context Compaction**: auto-triggers when approaching token limits, never hitting walls mid-session

The `db=db(database_url=...)` + `session_id` persistence pattern is the cleanest API surface for your Rust FFI layer to implement. SQLite for local, PostgreSQL for any future cloud sync.

**What to cherry-pick:** `auto_save` + `session_id` API design. Doom loop detection config. Context compaction trigger threshold (implement at 80% context fill). Shadow git checkpoint pattern for session `artifacts/`. Graph memory relationship tracking.

***

### 6. Hermes Agent Self-Evolution — The Self-Improvement Loop

NousResearch/hermes-agent-self-evolution is the most forward-looking repo in the list. It uses DSPy + GEPA (Genetic-Pareto Prompt Evolution) to automatically improve SKILL.md files by reading execution traces — understanding *why* things fail, not just *that* they failed. Every run costs ~$2-10, produces a PR for human review, and never commits directly.

For your app, this translates to a **vault-powered self-improvement loop**:
1. Each session writes `trace.json` (all tool calls, outcomes, timings)
2. A background process reads traces across N sessions
3. GEPA evolves the model's skill files based on trace evidence
4. Evolved skills are written to `models/claude-opus/skills/skill_v2.md`
5. You review and approve the updated skill in the sidebar

The 5 guardrails (tests, size limits, cache compatibility, semantic preservation, human review) are exactly what prevents runaway self-modification.

**What to cherry-pick:** Execution trace format (store as `trace.json` per session). The evolve-via-trace pipeline. Human-in-the-loop review gate. Skill versioning: `skill_v1.md` → `skill_v2.md` with diff log in the session vault.

***

### 7. metaharness — Filesystem-Backed Optimization History

SuperagenticAI/metaharness treats harness artifacts (AGENTS.md, setup scripts, validation logic) as a repeatable optimization target with stored evidence for every proposal. Every run stores prompts, candidate workspaces, validation results, evaluation results, proposal metadata, and workspace diffs on disk.

The `allowed_write_paths` scope enforcement is a critical safety pattern: agents operating within a session vault should only be allowed to write to that session's folder and the model's `memory/` directory — never outside. The outer optimization loop (improve harness → validate → keep best → store history) becomes your vault health/evolution cycle.

**What to cherry-pick:** `allowed_write_paths` scope enforcement for session agents. Filesystem-backed candidate ledger format (adapts to your session `trace.json`). The `inspect` / `summarize` / `compare` reporting commands — build these as sidebar views in your app.

***

### 8. SciAgent-Skills — Skill Template System

jaechang-hits/SciAgent-Skills provides 196 SKILL.md files and a structured template that boosted Claude Code from 65.3% to 92.0% on BixBench-Verified-50 (+26.7 percentage points). The template has: frontmatter (name, description, license for agent discovery) → overview → prerequisites → quick start → workflow → key parameters → common recipes → troubleshooting.

Critically, agents **read only the `description` field during planning** and load the full skill on demand. This is lazy loading for skills — your model vaults can store hundreds of skills without paying context cost until they're needed.

**What to cherry-pick:** The SKILL.md template format for your model vault `skills/` directory. Lazy description-first loading. The `registry.yaml` pattern — each model vault has a `skills_registry.yaml`. Skill categories that map to your use cases: coding, file ops, memory management, agent coordination.

***

### 9. claude-code-analysis — Production Agent Architecture Secrets

thtskaran/claude-code-analysis analyzed the accidentally-exposed full Claude Code TypeScript source (512,000 lines across 1,902 files). Three findings are directly actionable for your app:

**Multi-agent IPC via files** — when Claude Code spawns parallel agents, they coordinate via a file-based mailbox at `~/.claude/work/ipc/` with 500ms polling. This is exactly the pattern for your Swift ↔ Python agent bridge: write task JSON to an IPC folder, your Python agent picks it up, writes results back. No inter-process sockets needed.

**Context compaction at 93%** — six compaction strategies from lightweight (clear old tool results) to full (fork subprocess, summarize into 9-section format). Your trigger should be at 80% to stay ahead of the wall. The 9-section summary format maps to your `summary.md` per session.

**System prompt structure** — 7 static cached sections + 13 dynamic per-session sections, with a deliberate cache-busting boundary. Adopt this for your agent system prompts: static model identity + dynamic session context (date, vault path, current session ID, available skills).

**What to cherry-pick:** File-based IPC pattern for Swift FFI ↔ Python bridge. 80% context compaction trigger. 9-section session summary format. Static + dynamic system prompt boundary with cache optimization.

***

### 10. Open Multi-Agent — TypeScript DAG Orchestration (Reference Pattern)

JackChen-me/open-multi-agent provides the cleanest TypeScript-native multi-agent DAG implementation: `runTeam()` auto-decomposes a goal into a dependency graph, runs independent tasks in parallel, and synthesizes. Three runtime dependencies. 88% test coverage.

For your Swift app, this is the *reference architecture* for multi-step agent sessions: when a user triggers a complex agent task, decompose it into a DAG, run independent subtasks in parallel agents, write all outputs to the session vault. The `onTrace` callback emits structured spans for every LLM call, tool execution, and task — exactly your `trace.json` format.

The `SharedMemory: true` flag between team agents maps to your session's shared `session.json` context object passed via FFI.

**What to cherry-pick:** DAG task decomposition for complex sessions. `onTrace` structured span format (adopt as your `trace.json` schema). `SharedMemory` object pattern. Lifecycle hooks (`beforeRun`/`afterRun`) for session start/end vault writes.

***

### 11. obsidian-skills — Vault-Native Markdown Skills

kepano/obsidian-skills provides Obsidian-native skills: `obsidian-markdown` (full Obsidian Flavored Markdown syntax with wikilinks, embeds, callouts, properties), `obsidian-bases` (filtering/sorting views), `json-canvas` (visual session maps), `obsidian-cli`, and `defuddle` (clean web content for storage).

For your app: use Obsidian Flavored Markdown as the canonical format for all vault files. This gives you wikilinks graph, properties frontmatter (parseable by your Swift app), callouts for structured content, and compatibility with Obsidian as a visual viewer your users can open any vault in.

**What to cherry-pick:** OFM as vault file format. YAML frontmatter schema for all session files. `json-canvas` for visual session maps as a sidebar view. `defuddle` for cleaning any web content the agent fetches before storing in the vault.

***

### 12. llama.cpp-tq3 — Local Model Quality Optimization

turbo-tan/llama.cpp-tq3 provides TurboQuant quantization formats TQ3_1S and TQ3_4S for llama.cpp. On Qwen3.5-27B, TQ3_4S achieves PPL 6.8224 at 12.9 GiB — beating Q3_K_S (6.8630 at 11.4 GiB) in quality at similar size. The TurboQuant KV-cache (`-ctk tq3_0 -ctv tq3_0`) extends effective context to 8192+ tokens.

For your local model vault: use TQ3_4S for any 27B+ model you run locally to maximize quality per byte. The extended KV cache window means longer sessions before compaction triggers. This directly impacts how much of a session's context remains "live" versus needing to be written to the vault.

**What to cherry-pick:** TQ3_4S quantization for local models in your app. KV cache compression settings for long sessions. Use Qwen3.5-27B as the reference local model for the agent vault.

***

## The Vault Architecture — Complete Design

### Directory Structure

```
~/AppVaults/
├── _registry.json              # All vaults + model configs
├── _index.md                   # Global index (hub level)
├── models/
│   ├── claude-opus-4/          # One vault per model+version
│   │   ├── .vault_config.json  # Provider, API params, skill settings
│   │   ├── _index.md           # All sessions + memory overview
│   │   ├── SOUL.md             # Model identity: tone, personality, role
│   │   ├── skills/             # Model-specific skill library
│   │   │   ├── skills_registry.yaml
│   │   │   ├── code-review/SKILL.md
│   │   │   └── memory-search/SKILL.md
│   │   ├── memory/             # Long-term memory (grows forever)
│   │   │   ├── user_profile.md
│   │   │   ├── decisions.md    # Key decisions across all sessions
│   │   │   ├── knowledge.md    # Accumulated facts
│   │   │   └── graph.json      # Cross-session knowledge graph
│   │   └── sessions/
│   │       └── 2026-04-08_abc12345/
│   │           ├── session.json     # ID, model, provider, timestamps, tags
│   │           ├── transcript.jsonl # Raw verbatim turns (immutable)
│   │           ├── summary.md       # 9-section compaction summary
│   │           ├── knowledge.md     # Session-specific insights
│   │           ├── trace.json       # Tool calls, timings, outcomes
│   │           ├── graph.json       # Session knowledge graph (graphify)
│   │           └── artifacts/       # Files created during session
│   ├── gpt-4o/
│   ├── gemini-2-flash/
│   └── local-qwen3-27b/
└── shared/
    ├── user_profile.md         # Cross-model user preferences
    └── global_knowledge/       # Shared reference docs
```

### Session Lifecycle — What Happens Automatically

**On session start:**
1. `SessionManager` generates UUID: `2026-04-08T00-27-00_abc12345`
2. Creates folder at `models/{model}/sessions/{session_id}/`
3. Writes `session.json` with model, provider, start timestamp, initial tags
4. Injects `SOUL.md` + top N skills (lazy-loaded by description) into system prompt
5. Injects recent sessions summary from `memory/decisions.md`
6. Starts `transcript.jsonl` writer (Rust FFI, async)

**During session:**
- Every turn appended to `transcript.jsonl` (raw verbatim, never summarized)
- Tool calls + outcomes appended to `trace.json`
- At 80% context fill: background compaction writes `summary.md` (9-section format), older turns stay in JSONL but are replaced in context by the summary
- Files created by agent go to `artifacts/`

**On session end:**
1. Finalizes `session.json` with end timestamp, token counts, outcome
2. Runs graphify on the session folder → `graph.json` + GRAPH_REPORT.md
3. Merges session insights into `memory/knowledge.md` (Connector agent)
4. Updates `_index.md` with new session entry
5. Background: GEPA checks trace.json against evolved skills, proposes updates to skills/

***

## Multi-Vault Sidebar — UI Design

The sidebar has three sections:

**Model Vaults** (auto-loaded from `_registry.json`):
- One entry per model/provider you have configured
- Shows last session date + total session count
- Expandable: shows recent sessions by date
- Badge: 🟢 active, 🔵 has new memory, ⚪ idle

**Custom Vaults** (manually added):
- User can tap "+" to add a vault at any path
- Can be an existing Obsidian vault
- Useful for importing a corpus (notes, docs, research) as context

**Shared Vault** (always present):
- `user_profile.md`, global knowledge
- Cross-model preferences and facts

Tapping any vault opens it in a split view: file tree on left, markdown preview on right. Sessions are grouped by date. Each session has inline metadata from `session.json` frontmatter.

***

## Memory Tiers — How They Layer

| Tier | Content | Storage | Survives | Accessed By |
|------|---------|---------|---------|------------|
| **Working** | Current session turns | Context window (RAM) | Nothing (volatile) | LLM directly |
| **Session** | summary.md + knowledge.md | JSONL + MD files | Compaction | Reload from disk |
| **Model** | skills/ + memory/*.md | Markdown files | Everything | Injected at start |
| **Global** | shared/user_profile.md | Markdown files | Everything | Injected at start |
| **Semantic** | ChromaDB index | Vector DB (local) | Everything | Vault search tool |

This directly maps to the MemGPT OS paradigm (RAM = working, disk = session+model+global) but with your vault's Obsidian-compatible file structure, which means it's also human-readable and editable — something MemGPT never was.[^1]

***

## Self-Evolution Loop — The Game-Changer

This is what makes your memory system genuinely better than static tools:

```
Session runs → trace.json written
                    ↓
Background job reads N traces
                    ↓
GEPA/DSPy: why did tool calls fail? why did agent loop?
                    ↓
Proposes updated skill_v2.md in model vault
                    ↓
User reviews diff in sidebar → approve/reject
                    ↓
Approved skills injected in next session
                    ↓
Better outcomes → better traces → better skills
```

This is the hermes-agent-self-evolution loop but powered by your own session vault instead of a remote training dataset. After 50-100 sessions, your model vaults contain *your* custom-evolved skills, shaped by your exact usage patterns — something no static memory tool can replicate.

***

## Implementation Roadmap

### Phase 1 — Session Vault Core (Foundation)

1. **`SessionManager.swift`** — UUID generation, folder creation via `FileManager`, `session.json` writer with Codable struct
2. **`VaultManager.swift`** — loads `_registry.json`, exposes vault list to SwiftUI sidebar, handles model vault init
3. **`TranscriptWriter` (Rust FFI)** — async JSONL writer, handles concurrent writes safely using Rust's ownership system, exposed via `swift-bridge` or `uniffi`
4. **`session.json` schema**:
   ```json
   {
     "id": "2026-04-08T00-27-00_abc12345",
     "model": "claude-opus-4",
     "provider": "anthropic",
     "started_at": "2026-04-08T00:27:00Z",
     "ended_at": null,
     "tags": [],
     "token_count": 0,
     "context_fill_pct": 0
   }
   ```

### Phase 2 — Memory Injection & Compaction

5. **`MemoryLoader.swift`** — reads `SOUL.md`, `skills_registry.yaml` (description-only), recent `memory/decisions.md` at session start
6. **`ContextMonitor.swift`** — tracks token count / context fill %, triggers compaction at 80%
7. **`MemoryCompactor` (Python/local model)** — reads transcript.jsonl, writes `summary.md` in 9-section format, called via Rust FFI subprocess bridge or file-based IPC
8. **File-based IPC** (from claude-code-analysis pattern) — Swift writes task JSON to `~/.app/ipc/tasks/`, Python agent polls every 500ms, writes result to `~/.app/ipc/results/`

### Phase 3 — Vault Search & Knowledge Graph

9. **ChromaDB integration** — `PersistentClient` at `models/{model}/memory/chroma_db/`, indexes all session transcripts and knowledge files, exposed via MCP server
10. **Post-session graphify** — run on session folder after end, produces `graph.json` + `GRAPH_REPORT.md`
11. **`VaultSeeker` agent** — uses ChromaDB semantic search + `graph.json` traversal to answer "what did we decide about X?" across all sessions

### Phase 4 — Self-Evolution & Advanced Memory

12. **`TraceWriter` (Rust FFI)** — structured trace.json per session recording every tool call
13. **Background evolution job** — reads traces, runs GEPA/DSPy, proposes skill updates to sidebar
14. **Skill versioning** — `skill_v1.md` → `skill_v2.md` with diff log, user approval gate

***

## The Stack — What Goes Where

| Layer | Technology | Responsibility |
|-------|-----------|----------------|
| UI | SwiftUI (Swift 6) | Vault sidebar, session view, skill approval, settings |
| FFI Bridge | `swift-bridge` or `uniffi` | Swift ↔ Rust type-safe boundary |
| File I/O | Rust | async JSONL writer, trace.json, IPC polling |
| Vault Search | Python + ChromaDB | Semantic search MCP server |
| Compaction | Python + local model | Context summarization, knowledge extraction |
| Knowledge Graph | Python + graphify | Post-session graph building |
| Local Model | llama.cpp-tq3 (TQ3_4S) | Local compaction + evolution |
| File Format | Obsidian Flavored Markdown | All vault content files |
| Protocol | MCP stdio | Vault tools exposed to cloud + local agents |

***

## Why This Beats Every Existing Tool

| Feature | Your App | Claude.ai | ChatGPT | OpenClaw |
|---------|---------|-----------|---------|---------|
| Per-session folders | ✅ UUID-based | ❌ | ❌ | ❌ |
| Raw verbatim storage | ✅ (96.6% recall) | ❌ (extracts) | ❌ (extracts) | Partial |
| Per-model vaults | ✅ | ❌ | ❌ | ❌ |
| Obsidian-compatible | ✅ | ❌ | ❌ | Partial |
| Knowledge graph | ✅ (graphify) | ❌ | ❌ | ❌ |
| Self-evolving skills | ✅ (GEPA) | ❌ | ❌ | ❌ |
| Local sovereign | ✅ | ❌ | ❌ | ✅ |
| Cross-model memory | ✅ (shared/) | ❌ | ❌ | ❌ |
| MCP-exposed vault | ✅ | ❌ | ❌ | Partial |

The architecture you are building is not a feature improvement over existing apps. It is a qualitatively different category of system — one where memory is structural, sovereign, Obsidian-browsable, machine-searchable, and continuously evolving based on your actual usage. No static tool achieves all of this simultaneously.

---

## References

1. [Design Patterns for Long-Term Memory in LLM-Powered Architectures](https://serokell.io/blog/design-patterns-for-long-term-memory-in-llm-powered-architectures) - Dec 8, 2025

