# Variant Ladder — Tool Registry (B.2)
**Date:** 2026-05-15
**Scope:** MAS-allowed tool surface (30 tools from `ToolTierBridge.coreAppStoreAllowedToolNames`).
**Authority:** Master Fusion Plan §B.2 + `docs/fusion/COGNITIVE_VARIANT_LADDER_DOCTRINE_2026_05_04.md` §4.1 + §10.
**Pairs with:** §B.3 escalation policy (committed `7cb1ed426`) + §B.1 Variant Ladder retrofit (deferred — wires dispatch into `vault.search` first).

---

## 0. The 6-tier doctrine (recap)

Per `agent_core/src/variant_ladder/mod.rs` and `COGNITIVE_VARIANT_LADDER_DOCTRINE_2026_05_04.md`:

| Tier | Name | Examples | Cost | User opt-in needed? |
|---|---|---|---|---|
| **T1** | Deterministic Rust | pure functions, table lookups, regex, BM25, SQL | nanoseconds | no |
| **T2** | Embedding | nearest-neighbour over an index | ms | no |
| **T3** | Classical | small distilled / NLI model | tens of ms | no |
| **T4** | Small LLM | 1.5-3B local, grammar-bound | hundreds of ms | yes (`Always`/`OnEmpty`) |
| **T5** | Mid LLM | 7-8B local, grammar-bound | seconds | yes |
| **T6** | Cloud | Anthropic / OpenAI / Google etc. | seconds + $$ | yes (`/cloud` or ⌥-submit) |

**Default escalation policy: `EscalationPolicy::Never`** — registry tools must NOT walk into T4+ without an explicit user-opt-in signal. Honored at the seam by the `b3_never_policy_skips_generative_tiers_even_when_only_path` test.

**Confidence floors** (per doctrine §3): `FLOOR_T1 ≥ 0.85`, `FLOOR_T2 ≥ 0.75`, `FLOOR_T3 ≥ 0.70`. Variants must produce a confidence score ≥ floor or fall through (return `None`).

**Audit marker convention**: any tool whose registration sets a non-`Never` escalation policy MUST carry a `// VARIANT-LADDER-DEFER:` source marker + a row here noting the construction site.

---

## 1. Vault primitives (4 tools)

### `vault.search`
**Source:** `agent_core/src/tools/registry.rs::register_vault_search` + `VaultSearchHandler::execute`.
**Tiers populated:** T1 + T2 + T3 (RRF fusion).
**Tiers skipped:** T4+ (search results without an LLM rewrite are the whole point).
**Confidence floors:** BM25 ≥ 0.85, embedding ≥ 0.75, RRF-fused ≥ 0.70.
**Example T1 input:** `query="vault registry path traversal"` → exact-phrase BM25 hit on `RCA9-P0-001`.
**Example T2 input:** `query="how do agent tools sandbox notes"` → semantic embedding hit on `CodeFileService.swift`.
**Example T3 input:** mixed query exercising both → RRF k=60 fusion picks top 5.
**Status today:** the BM25 (T1) + embedding (T2) + RRF-fused (T3) paths already work in `VaultStore::hybrid_search`. Variant Ladder dispatch wiring is **deferred to §B.1**.

### `vault.read`
**Source:** `agent_core/src/tools/registry.rs::register_vault_read` + `VaultReadHandler::execute`.
**Tiers populated:** T1 only (filesystem read; no probabilistic reasoning).
**Tiers skipped:** T2-T6 (reading bytes is deterministic).
**Confidence floors:** N/A (file either exists or doesn't).
**Example T1 input:** `path="notes/research/state-space-models.md"` → returns the file contents or `NotFound`.
**Status today:** vanilla T1; no ladder needed. Documented here for completeness.

### `vault.write`
**Source:** `agent_core/src/tools/registry.rs::register_vault_write` + `VaultWriteHandler::execute`.
**Tiers populated:** T1 only.
**Tiers skipped:** T2-T6 (writing bytes is deterministic; the only T3+ pre-flight is the contradiction-detection scan which is a separate orthogonal stage).
**Confidence floors:** the contradiction check's `0.75` threshold is independent of ladder floors — it's a warning gate, not a ladder gate.
**Example T1 input:** `path="notes/today.md", content="…", tags=["daily"]` → file written + frontmatter injected + readback verified.
**Status today:** T1 with LockBusy retry shipped 2026-05-14 (commit `f7f3c273a`).

### `vault.list`
**Source:** `agent_core/src/tools/registry.rs::register_vault_list` + `VaultListHandler::execute`.
**Tiers populated:** T1 (alphabetical browse) — **auto-routes to `vault.search` Tiers T1+T2+T3 when caller supplies `query` param** (commit `41be78202`).
**Tiers skipped:** T4+ (listing paths needs no LLM).
**Confidence floors:** the path-prefix listing is exact; the auto-routed `vault.search` path uses vault.search's own floors.
**Example T1 input:** `path="daily"` → alphabetical list with diagnostic header "Vault has N notes under `daily` (alphabetical, NOT relevance-ranked)".
**Example auto-route input:** `query="state space models"` → tagged "Auto-routed to vault.search for relevance" + relevance-ranked results.
**Status today:** auto-route shipped 2026-05-15 fixes the user-reported "Qwen listed only 7 irrelevant notes" bug.

---

## 2. File ops (4 tools — scoped to vault root)

### `file.read`
**Source:** `agent_core/src/tools/file_ops.rs::file_read_handler`.
**Tiers populated:** T1 only (canonical containment via `CodeFileService` — verified 5-test drift gate per `RCA9-P0-001`, commit `504c2696d`).
**Tiers skipped:** T2-T6.
**Confidence floors:** N/A.
**Example T1 input:** `path="src/main.swift"` → file contents OR `ServiceError::pathEscapesVault` if path is outside vault.

### `file.write`
**Source:** `agent_core/src/tools/file_ops.rs::file_write_handler`.
**Tiers populated:** T1 only with `// SAFETY:` containment.
**Tiers skipped:** T2-T6.
**Confidence floors:** N/A.
**Example T1 input:** `path="src/foo.swift", content="…"` → written via `CodeFileService.updateCodeFile`. Outside-vault paths denied.

### `file.patch`
**Source:** `agent_core/src/tools/file_ops.rs::file_patch_handler`.
**Tiers populated:** T1 + T2 (unified-diff parser uses tree-sitter for syntax-aware line range matching when available — that's a classical-model assist).
**Tiers skipped:** T3 (NLI models add nothing for diff parsing), T4+ (patch correctness is structural).
**Confidence floors:** patch hunks must apply with `0.95` line-match confidence to be considered T1-clean; lower confidence falls through to T2 (tree-sitter); below `0.85` returns an error rather than escalating.
**Example T1 input:** clean unified diff with exact line matches → applied verbatim.
**Example T2 input:** diff where the surrounding context shifted by 1-3 lines → tree-sitter locates the symbol and re-anchors the hunk.

### `file.search`
**Source:** `agent_core/src/tools/file_ops.rs::file_search_handler`.
**Tiers populated:** T1 (ripgrep-like literal/regex search).
**Tiers skipped:** T2-T6.
**Confidence floors:** N/A (literal match either hits or doesn't).
**Example T1 input:** `query="VARIANT-LADDER-DEFER", glob="**/*.rs"` → all source markers across `agent_core/src/`.

---

## 3. System (1 tool)

### `system.todo`
**Source:** `agent_core/src/tools/system.rs` (or equivalent).
**Tiers populated:** T1 (todo list ops are CRUD against a typed store).
**Tiers skipped:** T2-T6.
**Confidence floors:** N/A.
**Example T1 input:** `action="add", item="Ship B.2"` → typed `TodoEntry` appended.

---

## 4. Graph + memory (4 tools)

### `graph.query`
**Source:** `agent_core/src/tools/registry.rs::register_graph_query` (or `graph_tools.rs`).
**Tiers populated:** T1 (SQL/GRDB query against graph table).
**Tiers skipped:** T2-T6 (graph queries are exact).
**Confidence floors:** N/A.
**Example T1 input:** `{ "node_id": "abc123" }` → row from `graph_nodes` table.

### `graph.neighbors`
**Source:** same module.
**Tiers populated:** T1 (BFS/DFS over edge table; bounded depth).
**Tiers skipped:** T2-T6.
**Confidence floors:** N/A.
**Example T1 input:** `{ "node_id": "abc123", "depth": 2 }` → neighbor set within radius 2.

### `graph.vault_navigate`
**Source:** vault graph navigation helper.
**Tiers populated:** T1 + T2 (vault-relative path resolution against the graph's `vault_id` column).
**Tiers skipped:** T3+ (path resolution is structural).
**Confidence floors:** path match ≥ 0.85.
**Example T1 input:** `from_note="research/alpha.md"` → returns wikilink targets + backlinks.

### `memory.curated`
**Source:** curated-memory recall surface (orphan candidates from §C.15; verify wiring before promotion).
**Tiers populated:** T1 + T2 (path-prefix lookup + embedding fallback).
**Tiers skipped:** T3+.
**Confidence floors:** ≥ 0.75 for T2 fallback.
**Example T1 input:** `topic="agent identity"` → exact-tag memory entries + semantic neighbours.

---

## 5. Web (4 tools — HTTPS via URLSession, no subprocess)

### `web.search`
**Source:** `agent_core/src/tools/web.rs::web_search_handler` + provider routing.
**Tiers populated:** T6 ONLY (cloud — Perplexity / Tavily / Brave Search HTTP).
**Tiers skipped:** T1-T5 (no local web index).
**Confidence floors:** N/A (cloud provider returns results).
**User-opt-in path:** approval card (host-native UI) per `BASE_SYSTEM_PROMPT`.
**Example input:** `query="state space models latest 2026"` → 3-5 cited HTTPS results.
**VARIANT-LADDER-DEFER:** `web.*` is the canonical T6-only tool family — by definition it bypasses the deterministic-first discipline because there's no T1 equivalent.

### `web.extract`
**Source:** `agent_core/src/tools/web.rs::web_extract_handler`.
**Tiers populated:** T1 (HTML→Markdown) + T6 (HTTPS fetch).
**Tiers skipped:** T2-T5.
**Confidence floors:** N/A.
**Example input:** `url="https://example.com/article"` → markdown body.
**VARIANT-LADDER-DEFER:** T6 fetch is unavoidable; T1 extraction lives in `htmd-rs` (or equivalent).

### `web.crawl`
**Source:** `agent_core/src/tools/web.rs::web_crawl_handler`.
**Tiers populated:** T1 (URL-set BFS over fetched pages) + T6 (HTTPS fetch per URL).
**Tiers skipped:** T2-T5.
**Confidence floors:** N/A.
**Example input:** `seed_urls=["…"], max_depth=2`.
**VARIANT-LADDER-DEFER:** same as web.extract.

### `web.fetch`
**Source:** `agent_core/src/tools/web.rs::web_fetch_handler`.
**Tiers populated:** T6 ONLY (single HTTPS GET; content returned raw or cleaned).
**Tiers skipped:** T1-T5.
**Confidence floors:** N/A.
**Example input:** `url="https://example.com/page.html"`.
**VARIANT-LADDER-DEFER:** T6 is the whole tool.

---

## 6. Knowledge (5 tools — vault knowledge primitives)

### `knowledge.recall`
**Source:** `agent_core/src/tools/registry.rs::register_knowledge_recall` (or `memory.rs`).
**Tiers populated:** T1 (path-prefix) + T2 (embedding nearest-neighbour) + T3 (RRF fuse).
**Tiers skipped:** T4+ (recall is retrieval, not generation).
**Confidence floors:** standard 0.85 / 0.75 / 0.70.
**Example T1 input:** `topic="release date", filter_kind="decision"` → matched decisions.

### `knowledge.contradiction_check`
**Source:** `agent_core/src/storage/contradiction_detector.rs::detect_contradictions`.
**Tiers populated:** T2 (embedding similarity) + T3 (NLI head classifies entailment / contradiction / neutral).
**Tiers skipped:** T1 (no exact-match equivalent for contradictions) + T4+ (generative LLM not needed for binary classification).
**Confidence floors:** T2 similarity ≥ 0.75 to be considered; T3 contradiction probability ≥ 0.75 to surface a warning (pre-flight on `vault.write`).
**Example T2/T3 input:** new fact "Epistemos ships V1 on 2026-06-01"; existing fact "Epistemos has no fixed release date" → contradiction probability ≥ 0.85 → warning surfaced (not blocking; commit `f7f3c273a` semantics).

### `knowledge.evidence_score`
**Source:** `ClaimLedger::evidence_score` + `provenance/ledger.rs`.
**Tiers populated:** T1 (count + age + retraction graph) — deterministic.
**Tiers skipped:** T2-T6.
**Confidence floors:** N/A.
**Example T1 input:** `claim_id="cl_abc"` → `{score: 0.78, evidence_count: 5, retraction_depth: 0}`.

### `knowledge.session_search`
**Source:** session search surface against `RunEventLog`.
**Tiers populated:** T1 (BM25 over typed event log) + T2 (embedding over `ModelDelta` content).
**Tiers skipped:** T3+ (session search is retrieval).
**Confidence floors:** standard.
**Example T1 input:** `query="when did we decide on Pro CLI adapters"`.

### `knowledge.neural_recall`
**Source:** `neural_cache.rs` — the Cognitive Architecture Layer 1 (memory entry: `project_cognitive_architecture`).
**Tiers populated:** T2 only (purely embedding-based — that's the point).
**Tiers skipped:** T1 (no exact-match path) + T3+ (no generation).
**Confidence floors:** T2 ≥ 0.75.
**Example T2 input:** `query="agent identity"` → top-k cached responses with cosine similarity ≥ 0.75.

---

## 7. Note ops (5 tools)

### `note.create`
**Source:** `agent_core/src/tools/note_tools.rs::note_create_handler`.
**Tiers populated:** T1 (filesystem create + frontmatter injection) + T3 contradiction pre-flight (per `knowledge.contradiction_check`).
**Tiers skipped:** T4+.
**Confidence floors:** contradiction probability ≥ 0.75 surfaces warning.
**Example T1 input:** `title="Today", body="…", folder="daily"`.

### `note.edit`
**Source:** `agent_core/src/tools/note_tools.rs::note_edit_handler`.
**Tiers populated:** T1 (typed diff) + T2 (tree-sitter line re-anchoring on context drift).
**Tiers skipped:** T3+.
**Confidence floors:** T1 ≥ 0.95 for exact-line match; T2 ≥ 0.80 for re-anchor.
**Example T1 input:** clean unified diff against `notes/today.md`.

### `note.research_digest`
**Source:** `agent_core/src/tools/note_tools.rs::note_research_digest_handler`.
**Tiers populated:** T1 (template assembly from note + citations) + T6 (cloud only for the synthesis step).
**Tiers skipped:** T2-T5 (the synthesis needs generation; only T6 is policy-allowed and only with user opt-in).
**Confidence floors:** N/A.
**VARIANT-LADDER-DEFER:** T6 escalation requires user-opt-in (the agent UI prompts).

### `note.template`
**Source:** template-substitution tool.
**Tiers populated:** T1 (template lookup + variable substitution).
**Tiers skipped:** T2-T6.
**Confidence floors:** N/A.
**Example T1 input:** `template="daily", date="2026-05-15"`.

### `note.linker`
**Source:** wikilink suggester.
**Tiers populated:** T1 (exact match against vault titles) + T2 (embedding nearest-neighbour for fuzzy matches).
**Tiers skipped:** T3+.
**Confidence floors:** T1 ≥ 0.85 (exact); T2 ≥ 0.75.
**Example T1 input:** `term="state space models"` → wikilink to `[[notes/state-space-models]]` if present.

---

## 8. Other (4 tools)

### `clarify.ask`
**Source:** `agent_core/src/tools/registry.rs::register_clarify_ask` (planned; B.8 wiring).
**Tiers populated:** T1 only (returns a typed GenUI `clarify.ask.v1` payload — no model needed at this tool; the calling agent already decided to clarify).
**Tiers skipped:** T2-T6.
**Confidence floors:** N/A.
**Example T1 input:** `question="Which folder?", options=["daily","journal"]`.
**Status:** B.8 (Master Fusion Plan) not yet shipped; tool exists in catalog but the GenUI schema + ClarifyGenUIView landing is pending.

### `research.collect_snippet`
**Source:** `agent_core/src/tools/research.rs::collect_snippet_handler`.
**Tiers populated:** T1 (snippet capture + citation metadata).
**Tiers skipped:** T2-T6.
**Confidence floors:** N/A.
**Example T1 input:** `text="…", source_url="…", note_path="research/today.md"`.

### `research.search_papers`
**Source:** `agent_core/src/tools/research.rs::search_papers_handler`.
**Tiers populated:** T6 (Semantic Scholar / arXiv HTTPS API).
**Tiers skipped:** T1-T5 (no local paper index).
**Confidence floors:** N/A.
**VARIANT-LADDER-DEFER:** T6 is unavoidable.
**Example T6 input:** `query="mamba state space models 2024"`.

### `citation.save`
**Source:** `agent_core/src/tools/research.rs::citation_save_handler`.
**Tiers populated:** T1 (CRUD on typed citation store).
**Tiers skipped:** T2-T6.
**Confidence floors:** N/A.
**Example T1 input:** `{ "title": "…", "authors": [...], "year": 2024, "url": "..." }`.

### `chunk.reduce`
**Source:** `agent_core/src/tools/chunk_reduce_handler` (compaction).
**Tiers populated:** T1 (heuristic windowing) + T3 (TextRank-style classical extractor) + T6 (cloud summarizer when policy allows).
**Tiers skipped:** T2 + T4-T5.
**Confidence floors:** T1 length-budget hit (deterministic); T3 ROUGE-L ≥ 0.70 against full content.
**VARIANT-LADDER-DEFER:** T6 path requires user opt-in (this is a generative tier).
**Example T1 input:** `text="…2000 words…", budget_tokens=512` → first/last/centroid windows.
**Example T3 input:** budget too tight for T1 → TextRank picks top-k sentences by graph centrality.

---

## 9. Summary table — 30 MAS-allowed tools at a glance

| Tool | T1 | T2 | T3 | T4 | T5 | T6 | Escalation needs opt-in? |
|---|---|---|---|---|---|---|---|
| vault.search | ✅ | ✅ | ✅ | – | – | – | no |
| vault.read | ✅ | – | – | – | – | – | no |
| vault.write | ✅ | – | – | – | – | – | no |
| vault.list | ✅+route | – | – | – | – | – | no |
| file.read | ✅ | – | – | – | – | – | no |
| file.write | ✅ | – | – | – | – | – | no |
| file.patch | ✅ | ✅ | – | – | – | – | no |
| file.search | ✅ | – | – | – | – | – | no |
| system.todo | ✅ | – | – | – | – | – | no |
| graph.query | ✅ | – | – | – | – | – | no |
| graph.neighbors | ✅ | – | – | – | – | – | no |
| graph.vault_navigate | ✅ | ✅ | – | – | – | – | no |
| memory.curated | ✅ | ✅ | – | – | – | – | no |
| web.search | – | – | – | – | – | ✅ | yes (T6-only family) |
| web.extract | ✅ | – | – | – | – | ✅ | yes (T6 fetch) |
| web.crawl | ✅ | – | – | – | – | ✅ | yes (T6 fetch) |
| web.fetch | – | – | – | – | – | ✅ | yes (T6-only) |
| knowledge.recall | ✅ | ✅ | ✅ | – | – | – | no |
| knowledge.contradiction_check | – | ✅ | ✅ | – | – | – | no |
| knowledge.evidence_score | ✅ | – | – | – | – | – | no |
| knowledge.session_search | ✅ | ✅ | – | – | – | – | no |
| knowledge.neural_recall | – | ✅ | – | – | – | – | no |
| note.create | ✅ | – | ✅ | – | – | – | no |
| note.edit | ✅ | ✅ | – | – | – | – | no |
| note.research_digest | ✅ | – | – | – | – | ✅ | yes (digest synthesis) |
| note.template | ✅ | – | – | – | – | – | no |
| note.linker | ✅ | ✅ | – | – | – | – | no |
| clarify.ask | ✅ | – | – | – | – | – | no |
| research.collect_snippet | ✅ | – | – | – | – | – | no |
| research.search_papers | – | – | – | – | – | ✅ | yes (T6-only) |
| citation.save | ✅ | – | – | – | – | – | no |
| chunk.reduce | ✅ | – | ✅ | – | – | ✅ | yes (T6 summarizer only) |

**T4 / T5 columns are deliberately empty across the MAS catalog.** Generative local LLM tiers don't make sense for retrieval/CRUD tools, and where generation IS needed (web search, paper search, digest synthesis, summarization) we go straight to T6 with user opt-in.

---

## 10. Acceptance bar for §B.2 (per Master Fusion Plan)

- ✅ Every MAS-allowed tool has a `## Variant Ladder` section above documenting:
  - Which tiers are populated (with concrete handler / module pointers)
  - Which tiers are deliberately skipped + why
  - Confidence floors per tier
  - Example inputs that exercise each populated tier
- ✅ Each tool with non-`Never` escalation policy carries an explicit `VARIANT-LADDER-DEFER:` note (here in the registry; source markers land when B.1 retrofit wires the actual dispatch into `agent_core/src/tools/registry.rs`).
- DEFERRED to §B.1: live wiring of `VariantLadder<I,O>` dispatch into the `ToolHandler::execute` path. This doc locks the contract every B.1 PR will satisfy.

---

## 11. Cross-references

- `docs/fusion/COGNITIVE_VARIANT_LADDER_DOCTRINE_2026_05_04.md` — Tier definitions + escalation rules
- `agent_core/src/variant_ladder/mod.rs` — `EscalationPolicy` + `VariantLadder<I,O>` typed seam (commit `7cb1ed426`)
- `Epistemos/Bridge/ToolTierBridge.swift:192-231` — the canonical 30-tool MAS allowlist
- `docs/MAS_COMPLETE_FUSION_IMPLEMENTATION_PLAN_2026_05_14.md` §B.1-B.4 — sequencing
- `docs/HERMES_AGENT_CORE_2_0_DESIGN_2026_05_15.md` §10 — Hermes 2.0 generalizes this dispatch shape

---

*— End of Variant Ladder Tool Registry. 30 tools, 11 sections, every tool's tier profile documented. Doctrine prep for B.1 (the actual dispatch retrofit). No live behavior change; this is the contract every future B.1 PR honors.*
