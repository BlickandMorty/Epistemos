# Vault Context Contract - 2026-05-17

Owner: T4 Vault Retrieval Repair  
Falsifier: F-VaultRecall-50  
Status: locked contract, recall pass bars green, trace/MMR/signal/provenance/prompt-threshold/rank-only-rejection/insufficient-evidence/shadow-exact-escalation slices landed

## Contract Rules

When a user request touches the vault, the runtime must satisfy every rule below before it can claim it used the user's notes.

1. Never enumerate the first N notes as if they represent the vault. Index order, filesystem order, and `LIMIT 7` are not retrieval.
2. Check vault inventory completeness before search: note count, manifest hash, newest mtime, and index freshness.
3. Search the full manifest with lexical BM25 and dense note sketches. If either signal is unavailable, emit a degraded trace and compensate with broader lexical retrieval.
4. Pull a 50-200 candidate pool before context selection. The answer context may be small, but the candidate search may not be.
5. Rerank candidates with BM25, embedding similarity, graph proximity, recency exponential decay, user-attached priority, and Cognitive DAG resonance when available.
6. Run an MMR diversity pass before building the context pack, so near duplicates cannot crowd out distinct relevant notes.
7. Build a compact context pack that says it sampled top-K by relevance from the full inventory.
8. If confidence is low or ambiguous, ask the user or broaden the search. Do not silently answer from weak retrieval, and do not collapse rejected weak hits into a false "no results" claim.
9. Source rank alone is never grounding. A candidate or fused hit is contract-sufficient only when it carries non-rank evidence, such as title/path/snippet/body, lexical, semantic, graph, recency, or priority reasons.
10. Emit a trace for every vault lookup: searched-note count, candidate count, selected count, top reasons, confidence band, contract-sufficient/high/medium/low confidence counts where applicable, and any degraded signals.
11. Surface loaded note provenance to the user: title/path plus lexical, semantic, graph, recency, and priority reasons where present. When vault notes ground a chat answer, end with a compact `Vault provenance:` block whose cited notes each include a `Why:` line.
12. Shadow-first retrieval may propose candidates from Model2Vec/HNSW/RRF, but dense-only, low-score, ambiguous-margin, or evidence-hidden Shadow hits are not answerable until exact lexical/body escalation verifies them. If exact escalation is unavailable, report insufficient evidence.

## Dataset

F-VaultRecall-50 contains 50 deterministic notes sampled from the user's local vault and 50 queries:

| Lane | Count | Requirement |
| --- | ---: | --- |
| Exact-title | 10 | Query is the literal title or a near title. Top-1 must hit. |
| Paraphrase | 10 | Query asks for note content without relying on title-only lookup. Top-5 must hit. |
| Recent | 10 | Query includes recency language. Rerank must not ignore freshness. |
| Synthesis | 10 | Query requires 2-3 distinct notes. Context must include at least two. |
| Adversarial | 10 | A similarly titled recent distractor exists. Retrieval must reject it. |

The baseline harness is `agent_core/tests/vault_recall_baseline.rs`. It samples by SHA-256 over `F-VaultRecall-50:2026-05-17:v1:<relative path>`, records content hashes, indexes a temporary mirror, and injects adversarial distractors only into that temp mirror.

## Pass Conditions

| Condition | Pass bar |
| --- | ---: |
| Top-1 exact-title recall | >= 95% |
| Top-5 paraphrase recall | >= 90% |
| Agent context recall | >= 90% |
| First-N enumeration failures | 0 |
| UI provenance visible | 100% of loaded notes |
| Synthesis distinct-note coverage | >= 2 notes per synthesis query |
| Adversarial distractor rejection | >= 85% |

## Failure Taxonomy

| Code | Failure | Required behavior |
| --- | --- | --- |
| `FIRST_N_SUBSTITUTION` | Runtime lists arbitrary early notes instead of searching. | Block answer, run full retrieval, emit trace. |
| `INVENTORY_UNKNOWN` | Note count or manifest hash is missing. | Mark trace degraded and avoid confidence claims. |
| `CANDIDATE_POOL_TOO_SMALL` | Search returns fewer than 50 candidates before rerank when inventory supports more. | Broaden query or add fallback source before context pack. |
| `SIGNAL_MISSING` | Lexical, dense, graph, recency, or priority signal is unavailable. | Emit degraded signal reason and continue only if confidence remains sufficient. |
| `LOW_CONFIDENCE` | Top result margin or absolute confidence is below threshold. | Ask user or broaden search. |
| `DUPLICATE_CROWDING` | Near duplicate notes fill the selected context. | Apply MMR and report diversity decisions. |
| `SYNTHESIS_UNDER_CITED` | Synthesis context contains fewer than two target notes. | Broaden candidates and rerank; do not answer as synthesis. |
| `ADVERSARIAL_CONFUSION` | Distractor outranks the target without an explicit ambiguity trace. | Reject or ask user to disambiguate. |
| `PROVENANCE_HIDDEN` | User cannot see why a note was loaded. | Show provenance card/badges before claiming vault grounding. |
| `TRACE_ABSENT` | No machine-readable retrieval trace exists. | Treat as contract failure. |
| `SHADOW_EXACT_ESCALATION_REQUIRED` | Shadow-first evidence is dense-only, low-score, ambiguous, or missing visible title/snippet/body evidence. | Run exact residual lexical/body verification before answering, or say evidence is insufficient if exact verification is unavailable. |

## Implementation Order

1. Rust contract types in `agent_core/src/retrieval/`: inventory, signal scores, candidate trace, confidence band, MMR decision, validation, and first-N failure typing. Complete.
2. Extend `VaultStore::hybrid_search` without changing the public fallback shape: retrieve a 50-200 pool, preserve raw lexical score, emit `hybrid_search_with_trace`, MMR-rerank selected context, and attach recency, priority, and vault-link graph proximity signals. Complete for the lexical/title VaultStore path; dense sketch and Cognitive DAG resonance still emit degraded trace entries.
3. Swift RRF hardening: reason labels and renderable provenance summaries are live for page/block/readable-block hits, fused search completion traces and in-memory metrics snapshots expose contract-sufficient/high/medium/low confidence counts, and rank-only fused hits are not contract-sufficient. Graph proximity in Swift RRF remains deferred to Shadow Search 1.0 unless backed by the Rust trace path.
4. Chat enforcement: indexed fallback searches a 50-200 candidate pool, rejects source-rank-only matches, emits per-hit reasons, and prompt contracts require title/path/snippet/body evidence plus a visible `Vault provenance:` block. If indexed hits exist but all fail the evidence contract, the user sees an explicit insufficient-evidence response instead of a no-results claim. Synthesis prompts require at least two independently retrieved vault notes or an honest insufficient-evidence response.
5. Notes UI provenance cards: surface why each indexed fallback note was loaded; RRF results carry renderable reasons for callers that surface fused results, and the note chat parser recognizes explicit `Vault provenance:` blocks.
6. Shadow Search 1.0 contract: `agent_core/src/retrieval/` now defines Shadow-first candidates, source parsing, RRF score/margin thresholds, and exact-escalation decisions. Dense-only, empty, ambiguous, low-score, or evidence-hidden Shadow hits must escalate to exact lexical/body verification before they can ground an answer.
