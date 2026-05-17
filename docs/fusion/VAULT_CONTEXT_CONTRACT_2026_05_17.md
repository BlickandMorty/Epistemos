# Vault Context Contract - 2026-05-17

Owner: T4 Vault Retrieval Repair  
Falsifier: F-VaultRecall-50  
Status: locked contract, partial implementation passing recall + visible provenance slices

## Contract Rules

When a user request touches the vault, the runtime must satisfy every rule below before it can claim it used the user's notes.

1. Never enumerate the first N notes as if they represent the vault. Index order, filesystem order, and `LIMIT 7` are not retrieval.
2. Check vault inventory completeness before search: note count, manifest hash, newest mtime, and index freshness.
3. Search the full manifest with lexical BM25 and dense note sketches. If either signal is unavailable, emit a degraded trace and compensate with broader lexical retrieval.
4. Pull a 50-200 candidate pool before context selection. The answer context may be small, but the candidate search may not be.
5. Rerank candidates with BM25, embedding similarity, graph proximity, recency exponential decay, user-attached priority, and Cognitive DAG resonance when available.
6. Run an MMR diversity pass before building the context pack, so near duplicates cannot crowd out distinct relevant notes.
7. Build a compact context pack that says it sampled top-K by relevance from the full inventory.
8. If confidence is low or ambiguous, ask the user or broaden the search. Do not silently answer from weak retrieval.
9. Emit a trace for every vault lookup: searched-note count, candidate count, selected count, top reasons, confidence band, and any degraded signals.
10. Surface loaded note provenance to the user: title/path plus lexical, semantic, graph, recency, and priority reasons where present.

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

## Implementation Order

1. Rust contract types in `agent_core/src/retrieval/`: inventory, signal scores, candidate trace, confidence band, MMR decision. Pending.
2. Extend `VaultStore::hybrid_search` without changing the public fallback shape: retrieve a larger pool, preserve raw BM25, attach contract trace internally, and expose a full-contract API for newer callers. Partially complete: larger pool, exact title/path lane, synthesis side-title seeding, and adversarial original-title suppression are live.
3. Swift RRF hardening: add graph-proximity source, reason labels, candidate pool accounting, and MMR-compatible result metadata. Partially complete: reason labels and renderable provenance summaries are live.
4. Chat enforcement: require contract success before vault-grounded answer claims and route low confidence to broaden-or-ask. Partially complete: indexed fallback uses a 50-200 candidate pool and emits per-hit reasons.
5. Notes UI provenance cards: surface why each note was loaded. Complete for indexed fallback answers; RRF results carry renderable reasons for callers that surface fused results.
