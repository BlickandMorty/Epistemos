# Agent-App Field Study — the Embedded-Agent Frontier (Cycle 1, Phase A1)

**Date:** 2026-07-05 · **For:** the Epistemos Experimental surface (embedded 1Code).
**Method:** three parallel deep-research agents cloned the frontier apps into the gitignored
`.research-clones/` and read the real source at HEAD, cross-checked against current product docs.
Full a–g breakdowns with `file:line` citations live in the (uncommitted, gitignored) section files
`.research-clones/fieldstudy-{codex-opencode,goose-zed-cline,aider-continue-claudedesktop}.md`.
This committed synthesis distills the comparative map: **what to match, what to beat, what only a
knowledge-embedded agent can do.**

Apps studied at HEAD: **Codex CLI** (`codex-rs/` @ be33f80), **opencode** (`packages/opencode/src/`
@ 68f225a), **goose** 1.41 (@1b2f77f), **Zed** ACP/agent-panel 0.61 (@5b805ac), **Cline** 4.0.0
(@25ef093), **Aider** (`aider/repomap.py`), **Continue** (LanceDB+FTS index), **Claude Desktop**
(closed-source; MCP/DXT connector model, web-verified).

---

## 1. The one finding that decides everything

**Exhaustive negative grep across all eight apps: none has semantic retrieval from a durable
personal knowledge base, a concept graph, or provenance write-back.** Every one models the world as
*open worktree + explicitly-attached files/threads + on-disk rules (`AGENTS.md`/`CLAUDE.md`/memory
files)*, and persists a transcript archive keyed by **session, grouped by project directory**
(goose `sessions.db` by `working_dir`; Zed `threads.db` by `folder_paths`; Cline `taskHistory.json`;
opencode event-sourced SQLite). Their "memory" features *prove* the gap rather than close it:

- **goose** memory MCP verbatim-dumps flat text; **Cline** "Memory Bank" is a hand-maintained
  markdown file *inside the repo*, re-read in full each task; **Zed** recalls a past thread only by a
  manual `@mention`; **Claude Desktop** memory is a rolling ~24 h summary; **Codex**'s memory pipeline
  distills its *own rollouts* and cites `thread_id`s — never the user's knowledge
  (`memories/read/src/citations.rs:45`).

This is a **structural** absence, not a backlog item: none of them lives inside a second brain, so
none can cite the user's notes, retrieve across their whole graph, or write a durable, provenance-
linked claim back. **That axis is closed to them and open only to us.**

---

## 2. Comparative map

### What to MATCH (table stakes the field does well — we must be at least as good)
- **App-owned agentic loop** (not the SDK's `maxSteps`): stream, parse tool calls, run tools
  concurrently, terminate on "final message + no tool calls" (Codex `session/turn.rs:225`; opencode
  `prompt.ts:1088`). — *We have this via the ACP/claude engines; keep streaming + thinking fidelity.*
- **Structured edits + review-at-apply approval gate** (apply-patch family). — *1Code has diff review.*
- **Per-tool approval, once/always** + auto-compaction + MCP. — *We have tool-policy (Claude) + MCP.*
- **Real cost/token observability + OpenTelemetry** (Codex). — *Gap: surface per-provider cost.*
- **Header-aware retry + context-overflow→compaction; durable resume/fork/revert** (opencode's
  event-sourced SQLite + shadow-git snapshots is the cleanest revert substrate). — *We have
  session-resume + budget; consider shadow-git snapshots.*
- **On-disk rules discovery** (`AGENTS.md`/`CLAUDE.md`). — *We have MCP-injected vault instead.*

### What to BEAT (where the field is weak — our opening)
- **Context assembly.** The field's ceiling is repo-scoped: Aider's tree-sitter + **PageRank** repo
  map (`aider/repomap.py:365-574`) is *structure* not meaning; Continue's LanceDB+BM25 local RAG is
  the field's best but indexes only the *current workspace*; everyone else is ripgrep-on-demand.
  **We retrieve from the personal vault (notes + chats) via RRF fusion (BM25 + HNSW), a strictly
  larger and more personal corpus than one workspace.**
- **Pre-apply diff review.** goose applies then shows; Cline v4's diff view is *unwired* (writes go
  straight to `fs`); only Zed does true hunk-level pre-commit review. — *Match Zed's bar.*
- **Sandbox.** Codex ships real OS jails (Seatbelt / bwrap+seccomp / restricted-token) + a MITM
  network-allowlist proxy; opencode is permission-prompt-only with a permissive `"*":"allow"`
  default. For an agent touching a personal vault, **adopt Codex's isolation model** — this is a
  hardening target (Phase E).
- **Cost intelligence.** Zed computes no dollar cost natively. — *We can surface it.*

### What ONLY WE can do (the moat — Phase C1; no standalone app can replicate)
Grounded in Epistemos's existing substrate (the vault + `agent_core`'s ClaimLedger with retraction
propagation, Merkle-verified ReplayBundle, the cognitive DAG, RRF fusion over notes+chats):
1. **Vault-grounded answers with citations** — the agent searches the user's *own notes* mid-task and
   cites them inline (built on the `epistemos-vault` MCP, already live to both engines).
2. **Provenance write-back** — a substantive answer/edit becomes a durable, linked vault note (what,
   why, sources) that feeds the graph. *(Shipped this cycle: the "Save to vault" button →
   `vault:create-note` → `<vault>/notes/*.md`.)*
3. **Cross-session memory via the graph** — recall "what we decided last time," keyed by concept not
   directory. Every field app's recall is a literal `LIKE`/list/id-lookup; ours is graph + retrieval.
4. **Graph-aware context assembly** — pull the *right* notes into context via the graph + RRF, not
   repo grep. This is the feature Codex/Cursor/Continue cannot build, because they have no graph.
5. **Provenance/observability console** — the agent's own tool calls, costs, and decisions, auditable
   in-app (append-only NDJSON already exists backend-side; surface it).

---

## 3. The thesis, validated by the evidence

All eight frontier apps are *agents with no memory of the user*. The Experimental surface is an agent
embedded in a knowledge substrate. The five moat features above are not aspirational — each maps to an
Epistemos capability that already exists (vault MCP, RRF fusion, ClaimLedger, cognitive DAG) and to a
confirmed *architectural* absence in the field. **Match the baseline; beat context-assembly and diff
review; win outright on the five knowledge-embedding axes.**

_Cycle-1 Phase-A1 deliverable. Detailed per-app a–g breakdowns + web-verification logs: the
`.research-clones/fieldstudy-*.md` section files (gitignored)._
