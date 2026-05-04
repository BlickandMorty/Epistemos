# Living Vault Memory: Diff-Based Vault Evolution & Chat-Driven Mutation

## Overview

The core idea here is that a vault should behave like a brain, not a database. Real memory doesn't append-only — it reinforces, rewrites, and forgets. This addendum to the Cloud Vault Knowledge Fusion design introduces the **Living Vault** model: vault files are living documents that grow, shrink, and mutate over time based on a continuous diff-apply-commit cycle. When you send a message to the vault's memory channel, an agent reads the current file state, generates a targeted patch (additions, removals, or rewrites), diffs it against the existing file, and applies only the meaningful change. Every mutation is versioned via git so the vault's full evolutionary history is always inspectable.

***

## Part 1 — The Philosophical Model: Memory is a Diff, Not an Append

### Why Appending Breaks Real Memory

Most AI memory systems use append-only logs or vector stores where every piece of information is permanently added and retrieved by similarity search. The fundamental problem is accumulation: old, outdated, contradictory, or low-importance facts pile up and eventually dominate retrieval results. Real human memory doesn't work this way. Knowledge is continuously reinforced, updated, generalized, and selectively forgotten.[^1]

The Ebbinghaus forgetting curve quantifies this: without reinforcement, about 50% of newly learned information is forgotten within 24 hours, around 70% within a few days, and up to 90% within a week. This is not a failure of memory — it is how a memory system stays clean, fast, and relevant. An AI vault that never forgets is not simulating intelligence; it is simulating a cluttered filing cabinet.[^2][^1]

The Living Vault model treats memory as a **diff over time**. The "current state" of the vault is a compact, curated snapshot — the working directory. History is preserved in git commits, accessible when needed but not cluttering the active context. As the DiffMem project describes it: "current-state files store only the 'now' view — current relationships, facts, timelines. Historical states live in Git's history, accessible on-demand."[^3][^4]

### Memory Operations Are Not All the Same

Mem0's architecture — one of the most rigorous agent memory systems built so far — classifies every memory operation into exactly four types:[^5][^6]

- **ADD**: A genuinely new piece of knowledge that doesn't conflict with existing content
- **UPDATE**: An existing memory whose information content is increasing or changing (replaces the old version)
- **DELETE**: A conflicting or now-false memory that must be removed so it doesn't corrupt future retrieval
- **NOOP**: The incoming information is already present — no change needed

This four-operation taxonomy is the heart of the Living Vault's mutation engine. Every time the vault receives a message — whether from a chat, an agent's completed task, or a scheduled reflection — the mutation engine classifies the incoming content against the current file state and generates only the correct operation. The vault does not blindly append.[^7][^8]

***

## Part 2 — Architecture: How the Diff Cycle Works

### The Mutation Pipeline

When a message is sent to the vault memory channel (or when an agent completes work and triggers a memory flush), the following pipeline runs:

```
1. MESSAGE RECEIVED
   "I've realized I prefer bottom-up architecture explanations"

2. RETRIEVAL SCAN
   Semantic search over current vault files → finds existing entry:
   "User prefers top-down explanations" in KNOWLEDGE_CORE.md (line 47)

3. LLM CLASSIFIES OPERATION
   Operation: UPDATE (contradicts existing, higher specificity)
   Target: KNOWLEDGE_CORE.md, line 47
   Old: "User prefers top-down architecture explanations"
   New: "User prefers bottom-up architecture explanations (updated 2026-03-29)"

4. DIFF GENERATED
   --- a/KNOWLEDGE_CORE.md
   +++ b/KNOWLEDGE_CORE.md
   @@ -47,1 +47,1 @@
   -User prefers top-down architecture explanations
   +User prefers bottom-up architecture explanations (updated 2026-03-29)

5. PATCH APPLIED TO FILE

6. GIT COMMIT
   "memory update: revised explanation-style preference [auto]"
```

This is the exact pattern used in GCC (Git-based Context Control for LLM Agents), which introduces version control semantics — COMMIT, BRANCH, and MERGE — as the operational backbone for agent context management. The Living Vault borrows this semantics: every meaningful vault change is a commit, with a machine-readable commit message tagging the operation type (ADD, UPDATE, DELETE) and the source (chat, agent, reflection, decay).[^9]

### Vault Chat — The Direct Memory Interface

The **vault chat** is a dedicated mini-chat channel that writes directly to vault files rather than producing conversational output. It is the "memory channel" described in the concept. Unlike a normal chat where the assistant responds, vault chat is a write-first interface:

- The user (or an agent) types a message like: `"I no longer care about React — I've fully moved to SvelteKit"`
- The vault agent reads the current `/skills/skill_frontend.json` and `KNOWLEDGE_CORE.md`
- It generates patches: deletes React-related skill entries, adds SvelteKit entries, updates the preference record
- Diffs are shown in the UI before committing, like a git staging area — the user can approve, edit, or reject individual hunks
- On confirmation, the commit is written with timestamp and source tag

This interface is conceptually similar to how patch diff analysis using LLMs works — the diff itself becomes the unit of communication, not the full file. The vault chat doesn't show you a rewritten file; it shows you exactly what changed, in `+/-` format, so you can see the vault "thinking."[^10]

### Automated Triggers: When the Vault Updates Itself

Beyond manual vault chats, the Living Vault updates itself automatically from several triggers:

| Trigger | Example | Operation Type |
|---------|---------|---------------|
| Chat session ends | Agent finished a research session | ADD new facts, NOOP duplicates |
| Agent completes agentic task | Desktop coding agent finishes a PR | UPDATE skill proficiency, ADD tool used |
| Contradiction detected | Agent finds a note contradicting a vault fact | DELETE old, ADD corrected |
| Time-based decay | A fact hasn't been accessed in 30 days | Strength score decays → DELETE if threshold breached |
| User sends vault message | Direct command to memory channel | ADD/UPDATE/DELETE per classification |
| Reflection cycle | Scheduled weekly "memory consolidation" agent run | Promotion of daily notes into MEMORY.md |

The reflection cycle is particularly important. Systems like OpenClaw implement this as a weekly cron job: promote durable rules and decisions from daily logs into MEMORY.md, keeping the always-on context compact while archiving detail in dated log files. The Living Vault's reflection agent runs the same process, but also performs **contradiction scanning** — checking whether any newly consolidated memories conflict with existing vault entries and issuing DELETE operations to resolve them.[^11]

***

## Part 3 — Memory Decay: Intelligent Forgetting

### The Ebbinghaus Engine

Every vault node — whether a fact in KNOWLEDGE_CORE.md, a skill entry, or a memory event — carries a `strength` score between 0.0 and 1.0. This score decays exponentially over time following the Ebbinghaus forgetting curve, with the decay rate modulated by the node's importance:[^12][^2]

```python
# Decay formula (from YourMemory open-source MCP server)
decay_rate = 0.16 * (1 - importance * 0.8)
strength = importance * math.exp(-decay_rate * days_since_last_access)

# importance=1.0 (critical) → decay_rate=0.032 → very slow decay
# importance=0.1 (noise)    → decay_rate=0.144 → fast decay
```

When `strength` falls below a configurable threshold (e.g., 0.15), the vault agent issues a DELETE patch for that node and commits it. The deletion is visible in git history and can be recovered if needed, but it no longer pollutes active context. This architecture is validated by MemoryBank, which introduced decay mechanisms inspired by Ebbinghaus to prioritize salient information over stale knowledge.[^7][^12]

Crucially, every time a vault node is *accessed* — either because an agent retrieved it during a task or because the user sent a vault message referencing it — its decay clock resets and its strength snaps back to its importance level. This is the **spacing effect**: frequent retrieval prevents forgetting. A fact you use every day stays forever; a fact you haven't touched in two months quietly disappears.[^2]

### Strength Score in the Graph Visualizer

The strength score maps directly to the knowledge graph visualizer described in the first report. Node opacity and size will encode strength: a bright, large node is strong and frequently accessed; a dim, small node is fading and close to deletion. This makes the "health" of the vault's knowledge immediately visible — you can glance at the graph and see which areas of the agent's memory are active vs. stale.

GraphMem's implementation shows this in practice: memories without reinforcement naturally fade through states (ACTIVE → EPHEMERAL → ARCHIVED), while facts that conflict with stronger memories are automatically superseded. The state machine concept translates directly to vault node lifecycle management.[^13]

***

## Part 4 — Diff-as-Thought: Simulating Thinking

### What "Simulated Thinking" Actually Means

The most philosophically interesting part of this design is the reframing of vault mutations as **visible cognition**. When a human changes their mind about something, the change is invisible — you can't observe the neurons firing. In the Living Vault, every change of mind, every learned skill, every forgotten detail is a committed diff. The git log of a vault is literally a record of an agent's evolving knowledge over time.

This makes several previously impossible things possible:

- **"Why does the agent think X?"** — Run `git log --grep="knowledge_core"` and trace when and from what source the belief was introduced
- **"The agent was better at this two weeks ago"** — Check out the vault at an earlier commit and compare the skill files
- **"Something changed that broke the agent's behavior"** — `git bisect` the vault to find the mutation that caused the regression

The A-MEM system formalizes this as **memory evolution**: when a new memory is added, it can trigger updates to the contextual representations and attributes of existing historical memories — the vault isn't just accumulating, it is re-evaluating itself. Every new ADD patch potentially generates a cascade of UPDATE and DELETE patches on related nodes.[^14]

### The Vault Chat as a Thinking Interface

The vault chat described in Part 2 becomes, under this framing, an interface for **direct thought injection**. When you type into it, you are literally editing the agent's mind with surgical precision. You don't just tell the agent something — you commit a diff to its knowledge graph. The system shows you the before/after, like a code review for the agent's beliefs.

This is implemented in practice by DiffMem's writer agent pattern: a Writer Agent analyzes transcripts, creates or updates entities, and stages changes in Git's working tree, ensuring atomic commits. The atomic commit guarantee is critical — a vault mutation either fully applies (all related changes land together) or fully fails (nothing changes), preventing partial updates that could leave the vault in a contradictory state.[^4][^3]

***

## Part 5 — Multi-File Coherence and Conflict Resolution

### The Problem of Multi-File Vaults

A vault is not a single file — it is a directory of interdependent markdown and JSON files. When the mutation engine patches `KNOWLEDGE_CORE.md` to update a preference, it must also check whether `skill_frontend.json` references that preference, and whether any `episodic_log.md` entries cite the old fact. Naive single-file patching creates "belief drift" — the main knowledge file says one thing while older skill files or memory logs say another.

Research on multi-agent shared markdown files confirms this fragility: "Two agents can't safely read and write the same markdown file simultaneously. If you're running multiple autonomous agents, this becomes a write-conflict problem immediately." The solution for single-agent vaults is the atomic commit — but for multi-agent desktops sharing a team vault, a coordination layer is needed.[^15]

### Cross-File Propagation Engine

The Living Vault's mutation engine runs **cross-file propagation** after every primary patch. The steps are:

1. Primary patch applied to the target file and staged
2. Cross-file scanner checks for references to the changed entity across all vault files
3. If references found, secondary patches are generated for each affected file
4. All patches staged together as a single atomic commit
5. Commit message includes the full propagation tree: `"[UPDATE] frontend preference → KNOWLEDGE_CORE.md + skill_frontend.json + 2026-03-15.md"`

This is analogous to how RECIPE's Knowledge Sentinel tracks downstream effects of knowledge edits — the requirement that a post-edit model should account for "alternative names, reversed relationships, and further reasoning" that flow from a single changed fact. Cross-file propagation is the structural implementation of that requirement.[^16]

### Conflict Resolution for Multi-Agent Vaults

When multiple desktop agents (research agent, coding agent, writing agent) share a team vault and attempt concurrent writes, the system uses a **branch-per-agent, merge-on-reflection** pattern:

- Each agent writes to its own vault branch during work (e.g., `agent/research`, `agent/coding`)
- The weekly reflection agent merges all branches into `main`, resolving conflicts using the four-operation classifier
- Conflicts where two agents hold genuinely different beliefs about the same fact are surfaced to the user in the vault chat with a "resolve belief conflict" prompt
- The resolution is committed as a MERGE commit with explicit reasoning recorded

This mirrors the GCC framework's branch semantics for managing parallel agent contexts, adapted specifically for knowledge rather than code.[^9]

***

## Part 6 — Implementation Stack

### Core Components to Build

| Component | What It Does | Tech |
|-----------|-------------|------|
| **Mutation Engine** | Classifies ADD/UPDATE/DELETE/NOOP per incoming message | Local LLM (classification task) |
| **Diff Generator** | Produces `unified diff` patches for each operation | Python `difflib` or `unidiff` |
| **Git Backend** | Versions all vault mutations as atomic commits | `gitpython` + bare repo per vault |
| **Cross-File Propagator** | Finds and patches all files referencing a changed entity | Ripgrep + LLM patch generator |
| **Decay Engine** | Runs on schedule, applies Ebbinghaus decay scores, DELETEs below threshold | Cron + Python |
| **Vault Chat UI** | Message input → staged diff preview → commit/reject | React component, `diff2html` for rendering |
| **Strength Visualizer** | Maps node strength to opacity/size in graph view | Integration with Sigma.js graph |

### The Vault Chat UI in Detail

The vault chat UI is the most user-facing component and deserves specific attention. It renders like a code review tool, not a messaging app. After a message is sent and the mutation engine runs, the UI shows:

```
Vault Memory — Staged Changes
────────────────────────────────────
File: KNOWLEDGE_CORE.md

- 47: User prefers top-down architecture explanations
+ 47: User prefers bottom-up architecture explanations

File: skill_frontend.json

- "explanation_style": "top-down"
+ "explanation_style": "bottom-up"

────────────────────────────────────
[✓ Commit]  [✎ Edit]  [✗ Discard]
```

Each hunk can be individually approved or discarded, exactly like staging patches in git. This gives the user full surgical control over what enters the vault. The design is validated by the principle that file-based memory must be "transparent and editable — if the agent hallucinates a goal, you simply highlight the text and delete it. This zero-friction human-in-the-loop capability builds trust."[^17]

### Decay Dashboard

A companion panel in the vault viewer shows a **decay dashboard**: a sorted list of all vault nodes by current strength score, with visual indicators (green/yellow/red) for health. Nodes in the red zone are flagged for deletion on the next decay cycle. The user can "reinforce" a node (bumping its strength back to its importance baseline) or "archive" it (move to a read-only `archived/` directory instead of deleting). This prevents permanent loss of knowledge that might still be occasionally useful while still keeping the active vault clean.

***

## Key Design Principles Summary

- **Diffs are the unit of memory change**, not whole-file rewrites or append-only logs[^3][^9]
- **Every mutation is classified** as ADD, UPDATE, DELETE, or NOOP before touching any file[^8][^5]
- **Forgetting is engineered**, not avoided — decay scores ensure the vault stays relevant and compact[^12][^2]
- **Git is the memory journal** — the vault's git log is the agent's intellectual autobiography, fully auditable and reversible[^18][^4]
- **Cross-file propagation** ensures no belief drift between related vault files after any mutation[^16]
- **Vault chat = direct thought injection** — the user and agents can surgically edit the agent's mind with immediate, visible diffs[^17][^11]
- **Human approval layer** is preserved — all staged diffs are shown before commit, maintaining trust and preventing hallucination from corrupting the vault

---

## References

1. [Curve of Forgetting: Combat Memory Loss with Cohort Learning](https://www.intrepidlearning.com/blog/curve-of-forgetting/) - Ebbinghaus plotted this decline on a graph, and the resulting curve showed just how dramatically our...

2. [AI Agent Memory Part 2: The Case for Intelligent Forgetting](https://dev.to/sudarshangouda/ai-agent-memory-part-2-the-case-for-intelligent-forgetting-4i48) - YourMemory is a practical open-source MCP server that bakes the Ebbinghaus forgetting curve directly...

3. [DiffMem: Git-Based Differential Memory for AI Agents - GitHub](https://github.com/Growth-Kinetics/DiffMem) - DiffMem is a lightweight, git-based memory backend designed for AI agents and conversational systems...

4. [DiffMem: Using Git as a Differential Memory Backend for AI Agents](https://www.reddit.com/r/LocalLLaMA/comments/1mvgw9k/diffmem_using_git_as_a_differential_memory/) - It's a lightweight, Git-based memory backend that stores "current state" knowledge in Markdown files...

5. [Mem0: Scalable Memory Architecture - Emergent Mind](https://www.emergentmind.com/topics/mem0-system) - Classify operation via LLM: - ADD: store as new memory. - UPDATE: replace similar memory if informat...

6. [Mem0 (Memo.ai) Memory Layer — Purpose and Core Functionality](https://blog.stackademic.com/mem0-memo-ai-memory-layer-purpose-and-core-functionality-375cc5a2bfd0) - For each fact the LLM selects ADD/UPDATE/DELETE/NOOP. For example, if a new fact “User likes hiking”...

7. [TeleMem: Building Long-Term and Multimodal Memory for Agentic AI](https://arxiv.org/html/2601.06037v4) - MemoryBank [45] introduces a decay mechanism inspired by the Ebbinghaus forgetting curve to prioriti...

8. [Add Memory - Mem0 Docs](https://docs.mem0.ai/core-concepts/memory-operations/add) - Add memory into the Mem0 platform by storing user-assistant interactions and facts for later retriev...

9. [Manage the Context of LLM-based Agents like Git - arXiv](https://arxiv.org/html/2508.00031v1) - We introduce GCC, a structured context management framework for LLM agents that integrates version c...

10. [Automated Patch Diff Analysis using LLMs | SySS Tech Blog](https://blog.syss.com/posts/automated-patch-diff-analysis-using-llms/) - So we coded a simple tool for automating patch diffing binaries using ghidriff and implemented a cus...

11. [OpenClaw Memory Masterclass: The complete guide to agent ...](https://velvetshark.com/openclaw-memory-masterclass) - Every OpenClaw user hits the same wall. The agent works great for 20 minutes, then silently loses it...

12. [MemoryBank: Enhancing Large Language Models with Long-Term Memory](https://arxiv.org/pdf/2305.10250.pdf) - ...a long-term memory mechanism within these
models. This shortfall becomes increasingly evident in ...

13. [GraphMem: A New Standard for Agent Memory Systems | Ayush P ...](https://www.linkedin.com/posts/ayushpatil007_big-respect-to-al-amin-for-shipping-graphmem-activity-7412855965483601920-0qpN) - Memory Decay: Implements Ebbinghaus forgetting curve. Memories without reinforcement naturally fade ...

14. [A-MEM: Agentic Memory for LLM Agents](https://arxiv.org/pdf/2502.12110.pdf) - ...address this
limitation, this paper proposes a novel agentic memory system for LLM agents
that ca...

15. [Stop Calling It Memory: The Problem with Every "AI + Obsidian ...](https://limitededitionjonathan.substack.com/p/stop-calling-it-memory-the-problem) - Two agents can't safely read and write the same markdown file simultaneously. If you're running mult...

16. [Knowledge Updating? No More Model Editing! Just Selective ... - arXiv](https://arxiv.org/html/2503.05212v1) - In this paper, we provide an evaluation of ten model editing methods along four dimensions: reliabil...

17. [AI Agent Memory Management - When Markdown Files Are All You ...](https://dev.to/imaginex/ai-agent-memory-management-when-markdown-files-are-all-you-need-5ekk) - Here are the key properties that make them effective for AI agents: Persistent: Memory survives agen...

18. [Show HN: DiffMem in production, Git-based AI memory | Hacker News](https://news.ycombinator.com/item?id=47228509) - Six months ago I shared DiffMem, a PoC that used git instead of vector databases for AI memory. 790 ...

