# Eidos V0 — Closed-Citation Retrieval Design (2026-05-18)

**Branch:** `codex/t10-eidos-v0-2026-05-18`
**Mission:** Build Eidos V0 as deterministic local search fusion and closed-citation retrieval for the current app. Eidos V0 makes vault / chat / agent retrieval **honest** before web augmentation, VPD, model training, or 70B work.

**Status:** All seven retrieval modes implemented behind the `EidosRetriever` trait with 84 unit tests covering the closed-citation contract, the nine acceptance-bar paths (exact note hit, `.epdoc` projection hit, code hit, graph hit, duplicate merge, fake citation rejection, empty vault, unicode query, no-result defer), and per-mode determinism guards. Swift bridge facade and per-tier wiring land in subsequent iterations.

---

## 1. What Eidos V0 is (and is not)

Eidos V0 is the **product retrieval organ** for the current Epistemos app. It is *one* of the two T10 prompt slices; the other (T10B — Eidos Form Layer) ships the canonical schema/identity layer and is out of scope here.

### 1.1 Eidos V0 IS

- A deterministic local-first search fusion across **seven** canonical retrieval modes (lexical, semantic, hybrid via RRF k=60, code-symbol, claim-evidence, graph-neighborhood, raw-archive) **plus two operator-extension modes** (recency, provenance-verified) — nine total, all behind the same `EidosRetriever` trait.
- A **closed-citation contract**: the chat / model layer can cite *only* the `EidosChunkId`s that the retriever returned in the current `EidosContextPacket`. Any other id — fabricated, stale, smuggled from another snapshot — is rejected by `EidosContextPacket::validate_citation`.
- A **manifest-bound** snapshot model: every hit + packet records the `EidosIndexManifestId` of the index snapshot it was retrieved against. Same manifest + same query + same pinned clock ⇒ byte-equal packet.
- An **emit-only** surface. Eidos never mutates durable memory; the broader runtime decides whether to materialize a returned packet into the cognitive DAG or claim ledger.
- **Backend-agnostic** for ClaimEvidence: the retrieval mode is backed by either `InMemoryClaimEvidence` (tests / fixtures) or `LedgerBackedClaimEvidence` (production over `agent_core::provenance::ledger::ClaimLedger`; closes W-49). Both emit byte-equal `source_id` wire format, so downstream code never needs to know which backend produced a packet.
- **N-way fusion ready**: `HybridRetrieverN` accepts any `Vec<Box<dyn EidosRetriever>>` sharing a manifest and fuses via RRF — proven stable at 100 inner retrievers, validated for backend heterogeneity (Lexical + ledger + recency in one stack).

### 1.2 Eidos V0 is NOT

- Not a mythic companion. Not a research/philosophy UI. The Halo / paired-companion role from FINAL_DOCTRINE §4.3 is V2.2 territory.
- Not a web augmentor. Web retrieval, browser fan-out, and external knowledge bases are **Eidos Plus** (Pro tier) and live outside this module.
- Not a Metal re-ranker or llguidance-shaped reasoning surface — those are **Eidos Plus / Research**.
- Not a model. No inference, no training. Eidos does not embed text into vectors itself; callers supply precomputed embeddings (the same model used for the indexed corpus).
- Not a form layer. `EidosKind::{Note,Claim,Evidence,…}` and canonical-form binding live in **T10B** (`codex/t10b-eidos-form-layer-2026-05-18`).

---

## 2. The closed-citation contract

The single most load-bearing invariant in this module:

> The chat / model layer can cite **only** `EidosChunkId`s that appear in an `EidosContextPacket`'s `hits`, and *only* against the same `EidosIndexManifestId` the packet was retrieved against.

Implemented in `agent_core/src/eidos/types.rs` as `EidosContextPacket::validate_citation`:

| Citation form                                                | `validate_citation`                                        | Why                                            |
|--------------------------------------------------------------|-------------------------------------------------------------|------------------------------------------------|
| `source_id` ∈ `packet.hits[*].source_id`, manifest matches    | `Ok(())`                                                    | Legitimate citation.                            |
| `source_id` ∉ `packet.hits`                                   | `Err(CitationError::FabricatedSourceId(...))`              | Forged / hallucinated reference.                |
| `source_id` valid but `manifest_id` ≠ packet's                | `Err(CitationError::ManifestMismatch { … })`               | Cross-snapshot smuggling — corpus may have moved. |

This is what makes Eidos **honest**: any answer the chat layer produces can be verified after the fact by validating every citation against the originating packet. There is no path for the model to claim a source that Eidos did not surface.

---

## 3. The nine canonical types

Source: `agent_core/src/eidos/types.rs`. All types are `Clone + Debug + PartialEq + Serialize + Deserialize`. JSON round-trip is part of the determinism floor (tested).

| Type                    | Purpose                                                                 | Stable across snapshot?    |
|-------------------------|-------------------------------------------------------------------------|----------------------------|
| `EidosDocumentId`       | Opaque, Eidos-issued document identifier. Empty payload rejected.        | Yes (caller-supplied).      |
| `EidosChunkId`          | Opaque, Eidos-issued chunk identifier. The **only** citable token.       | Yes.                        |
| `EidosIndexManifestId`  | Snapshot id. Pinpoints the corpus state retrieval ran against.           | Yes (immutable).            |
| `EidosSourceKind`       | Discriminator: `Note`, `Epdoc`, `Chat`, `Code`, `Graph`, `Shadow`, `ExactPath`, `RawArchive`. | n/a.                       |
| `EidosSpan`             | Optional `(byte_start, byte_end)` within the document body.              | Yes when present.           |
| `EidosScoreComponents`  | `lexical`/`semantic`/`recency`/`graph` breakdown. Diagnostic, not normalized weights. | f32 bit-equal across runs. |
| `EidosProvenance`       | Snapshot id + mode + caller-supplied `retrieved_at_unix_ms`.             | Yes (clock pinned by caller). |
| `EidosHit`              | One retrieved chunk. Carries `source_id`, `document_id`, kind, span, confidence, score components, provenance. | Yes per (manifest, query, clock). |
| `EidosQuery`            | `text`, `mode`, `top_k`, optional `query_vector`. `Eq`/`Hash` intentionally absent (`Vec<f32>` ≠ Eq). | n/a.                       |
| `EidosContextPacket`    | Sealed query → hits result. The closed-citation universe.                | Yes (byte-equal JSON).      |
| `EidosCitation`         | The chat layer's reference back to one `EidosChunkId` + `EidosIndexManifestId`. | n/a.                       |
| `EidosIndexManifest`    | Descriptor for an index snapshot (id, creation time, corpus digest hex). | Yes (immutable).            |
| `EidosRetrievalMode`    | One of seven canonical modes.                                            | n/a.                       |

---

## 4. The retrieval modes — nine canonical + N-way fusion

Seven modes from the original prompt-deck canon plus two operator-extension modes (Recency, ProvenanceVerified) all implement the `EidosRetriever` trait (`agent_core/src/eidos/retriever.rs`). Each retriever is **manifest-bound** at construction; the bound manifest is what flows into every emitted hit's provenance.

| Mode                  | Crate path                              | Mechanism                                                              | Deterministic order             | `source_id` shape                              | Default kind          | Tests |
|-----------------------|-----------------------------------------|------------------------------------------------------------------------|---------------------------------|------------------------------------------------|-----------------------|-------|
| `Lexical`             | `eidos::lexical::InMemoryLexicalIndex`   | Case-insensitive Unicode substring count.                              | `(occurrences desc, source_id asc)` | `{doc_id}::lex`                                | `Note`                | 11    |
| `Semantic`            | `eidos::semantic::InMemorySemanticIndex` | Cosine similarity over fixed-dim f32 vectors (caller-supplied query vector). | `(cosine desc, source_id asc)`  | `{doc_id}::sem`                                | `Note`                | 12    |
| `Hybrid`              | `eidos::hybrid::HybridRetriever<L,S>`    | RRF fusion of one lexical + one semantic retriever sharing a manifest. `RRF_K_DEFAULT = 60`. | `(rrf desc, document_id asc)`   | `{doc_id}::hybrid` (dedup across modes)        | inherited             | 16    |
| `Hybrid` (N-way)      | `eidos::hybrid_n::HybridRetrieverN`      | RRF fusion of any `Vec<Box<dyn EidosRetriever>>` sharing a manifest. Max-merges per-component score fields. | `(rrf desc, document_id asc)` | `{doc_id}::hybrid` (same namespace as 2-way) | inherited      | 12    |
| `RawArchive`          | `eidos::raw_archive::InMemoryRawArchive` | Exact `EidosDocumentId` lookup. Query text == document id.             | n/a (≤ 1 hit)                   | `{doc_id}::raw` (span over full body, confidence 1.0) | caller-supplied       | 11    |
| `CodeSymbol`          | `eidos::code_symbol::InMemoryCodeSymbolIndex` | Case-sensitive symbol-table lookup. Multiple occurrences per document. | `(document_id asc, byte_start asc)` | `{doc_id}::sym@{byte_start}`                  | `Code`                | 13    |
| `GraphNeighborhood`   | `eidos::graph_neighborhood::InMemoryGraphNeighborhood` | 1-hop adjacency expansion from a seed document. Self-loops legal. | `document_id asc` (BTreeSet)    | `{neighbor_id}::graph::from::{seed_id}`        | `Graph`               | 13    |
| `ClaimEvidence`       | `eidos::claim_evidence::InMemoryClaimEvidence` | claim_id → evidence document links with explicit `EvidenceStance`. Stance encoded in `source_id` to make stance-spoofing a citation forgery. | `(document_id asc, stance lex asc)` | `{evidence_doc}::claim::{claim_id}::{stance}` | caller-supplied       | 12    |
| `Recency`             | `eidos::recency::InMemoryRecencyIndex`   | Time-ordered retrieval ranked by `created_at_unix_ms desc`. Optional substring filter + optional `since_unix_ms` floor on the query. Empty query text is meaningful here. | `(created_at_unix_ms desc, source_id asc)` | `{doc_id}::recency` | caller-supplied       | 13    |
| `ProvenanceVerified`  | `eidos::provenance_verified::ProvenanceVerifiedRetriever<R>` | Fail-closed wrapper around any other retriever. Filters hits to admitted `source_id`s; rewrites `provenance.mode` to `ProvenanceVerified` while preserving the inner source_id. | inherited from inner             | inherited from inner (e.g. `{doc_id}::lex` if wrapping Lexical) | inherited       | 11    |
| `ClaimEvidence` (ledger) | `eidos::ledger_backed_claim_evidence::LedgerBackedClaimEvidence` | Production wiring for W-49. Consumes a `crate::provenance::ledger::ClaimLedger` snapshot. Retracted evidence filtered out. Snapshot-isolated: post-construction ledger mutations do not propagate. | `(evidence_id asc)` (snapshot pre-sorted) | `{evidence_id}::claim::{claim_id}::supports` | `Note` (caller-supplied via Evidence record) | 10 |

**Cross-mode invariants:**

- Every retriever returns a deterministic empty packet on: empty `query.text` (except Recency, which treats empty as "no substring filter"), `top_k == 0`, missing seed / id / claim. No panics, no implicit fallbacks.
- Every retriever's `source_id` is constructed through `EidosChunkId::new` — the empty-payload guard fires uniformly.
- RRF's `k = 60` is the **cross-component constant** mirrored in `epistemos-shadow/src/backend/rrf.rs:22` (`RRF_K_DEFAULT`) and Swift `Phase3FusionConsts.K_RRF` in `Epistemos/Sync/RRFFusionQuery.swift`. A regression test asserts `RRF_K_DEFAULT == 60` so accidental drift surfaces immediately.
- `EidosRetriever: Send + Sync` — every retriever is safe to hold in `Box<dyn EidosRetriever>` and to query from multiple threads. The constraint is asserted at compile time by per-retriever Send+Sync witness tests.
- Wire format pinned: `EidosRetrievalMode` + `EidosSourceKind` serialize as PascalCase JSON strings; `EvidenceStance` tokens stay lowercase ASCII inside the `ClaimEvidence` source_id format. Tests in `agent_core/src/eidos/parity.rs` lock both wire formats end-to-end.

## 4b. F-Eidos-ClosedCitation runtime witness

`agent_core::eidos::falsifier::f_eidos_closed_citation_falsifier(retrievers, queries, ts)` is the **callable runtime witness** for the closed-citation contract — required by the acceptance bar ("F-Eidos-ClosedCitation falsifier has fixture corpus + assertion that no result lacks provenance"). For every `(retriever × query)` pair it verifies:

1. `packet.manifest_id == retriever.manifest_id()`.
2. Each emitted hit's `provenance.manifest_id == packet.manifest_id`.
3. Each hit's `provenance.mode` matches the retriever's mode (with the ProvenanceVerified-wrapper rewrite rule honored).
4. Each hit's `confidence ∈ [0.0, 1.0]` (catches NaN, infinities, > 1.0).
5. Each hit's optional span has `byte_start ≤ byte_end`.
6. `packet.validate_citation(...)` succeeds for the hit's own source_id.
7. A deliberately-fabricated sentinel id is rejected by `validate_citation`.

Returns `FEidosClosedCitationWitness { retrievers_checked, queries_per_retriever, total_hits_validated, fake_citation_rejections }` with exact counts on success; `FalsifierFailure` (tagged-enum JSON-serializable) on any violation. Both types derive `Serialize` so the future Swift "Verify Eidos integrity" surface (W-46) can read them directly. The canonical fixture corpus exercises all 9 + HybridRetrieverN modes against 6 queries, asserting `retrievers_checked = 10` and `fake_citation_rejections = 60` on every run.

---

## 5. Tier split

Per `docs/CODEX_AND_CLAUDE_TERMINAL_DISPATCH_2026_05_18.md` and the prompt-deck §1.1 lane spec. Every row below has lane, tier, status, evidence, missing proof, next action, falsifier — per the AGENTS.md doc rule.

### 5.1 MAS — current product app

| Lane / Surface          | Tier | Status                  | Evidence                                                           | Missing proof                                        | Next action                                                                  | Falsifier (M2 Pro pinned)                            |
|-------------------------|------|-------------------------|--------------------------------------------------------------------|-------------------------------------------------------|------------------------------------------------------------------------------|-----------------------------------------------------|
| All seven retrieval modes | MAS  | `implemented-not-wired` | 84 unit tests in `agent_core/src/eidos/*`                          | No Swift caller yet; not reachable from Brain Panel.  | Land `Epistemos/Eidos/EidosBridge.swift` next iter; wire to Brain Panel.     | Brain Panel renders "Retrieved by Eidos" with no cloud round-trip on 50 vault notes < 200 ms p95. |
| Closed-citation contract | MAS  | `implemented`           | `EidosContextPacket::validate_citation` + 9 acceptance-bar tests.   | No production caller has been forced through it yet.  | Wire the chat layer's citation step to call `validate_citation` before emit. | Chat layer rejects a deliberately fabricated source_id and refuses to emit the answer. |
| RRF k=60 fusion          | MAS  | `current-wired-internally` | `RRF_K_DEFAULT` asserted == 60 + 11 tests.                          | Not yet driving a production query.                   | After Swift bridge lands, run a real vault query through `HybridRetriever`.  | Same query against same manifest produces byte-equal packet under cargo test + Swift integration. |

### 5.2 Pro — personal agentic environment

| Lane / Surface             | Tier | Status            | Evidence                                                                 | Missing proof                                          | Next action                                                                                  | Falsifier (M2 Pro pinned)                           |
|----------------------------|------|-------------------|---------------------------------------------------------------------------|---------------------------------------------------------|----------------------------------------------------------------------------------------------|------------------------------------------------------|
| Eidos Plus (web augmentation, Metal re-ranker, llguidance) | Pro  | `not-implemented` | Out-of-scope per §1.2 above. Reserved for a later T-prompt.               | No Pro retrieval surface yet.                           | Defer until Eidos V0 is WRV in MAS + chat-layer enforcement is provable.                     | n/a — Pro slice not yet started.                     |
| Hybrid mode default       | Pro  | `implemented`     | Same `HybridRetriever` as MAS, RRF k=60.                                  | Pro-tier callers do not yet exist.                      | After Agent Runtime v2 (T11) lands, wire its retrieval step through `HybridRetriever`.       | T11's agent loop cites only Eidos-emitted source_ids. |

### 5.3 Research — Vault tier

| Lane / Surface           | Tier     | Status            | Evidence                                                          | Missing proof                                       | Next action                                                                          | Falsifier (M2 Pro pinned)                              |
|--------------------------|----------|-------------------|-------------------------------------------------------------------|------------------------------------------------------|--------------------------------------------------------------------------------------|--------------------------------------------------------|
| 2-hop neighborhood       | Research | `not-implemented` | 1-hop only in V0 per §1.1.                                        | Frontier-order + cycle-handling invariants unspecified. | Specify ordering + cycle dedup, then add as a `GraphNeighborhood2Hop` variant.       | 2-hop replay byte-equal across pinned clock + manifest. |
| Eidos Plus (full)        | Research | `not-implemented` | Out-of-scope.                                                      | n/a                                                  | After Pro slice lands.                                                                | n/a                                                    |

---

## 6. Web augmentation: explicitly later

**Eidos V0 does not call the network. Ever.** No `reqwest`, no Brave / Google / Perplexity fan-out, no remote embedding service. Local-first is the load-bearing property that makes the closed-citation contract meaningful: if the retriever cannot reach external knowledge, every citation in an answer is anchored to a local artifact a user can open.

Web augmentation, when it ships, is **Eidos Plus** at the **Pro tier** and runs through a separate retriever that *also* implements `EidosRetriever` and so plays by the same closed-citation rules — but only after these falsifiers are green:

1. MAS chat layer is provably enforcing `validate_citation`.
2. T11 Agent Runtime v2 capability gate (`AgentRuntimeV2Capability`) is wired so MAS cannot reach the web path even by accident.
3. UX surface for "Retrieved from the web" is visibly distinct from "Retrieved from the vault" in the Brain Panel.

Until all three are green, **the network does not get called.** This is not a soft preference — it is the entire reason Eidos V0 is a useful organ.

---

## 7. Determinism floor

Every retriever satisfies, per the closed-citation contract:

1. **Manifest binding.** `retriever.manifest_id()` is set at construction and immutable thereafter. The same manifest id is recorded in every emitted hit's provenance.
2. **Sorted output.** Every retriever's `retrieve(query, ts)` produces hits in a sort order keyed on stable bytes (document id ascending, byte offset ascending, stance lexicographically) so that two retrievers populated identically produce byte-equal packets for the same query + clock.
3. **JSON round-trip.** `EidosContextPacket` round-trips through `serde_json::to_string` / `from_str` byte-equal. The test `eidos::types::tests::packet_roundtrips_through_json` catches any future non-deterministic field (`HashMap` iteration, `Vec<f32>` with NaN, etc.) before it lands.
4. **Clock pinned by caller.** `retrieved_at_unix_ms` is a parameter of `retrieve`, not a wall-clock read. Tests pass `1_700_000_000_000` to make replay trivial.
5. **No global state.** No `lazy_static`, no `OnceCell`, no `thread_local!` inside `eidos::`. Every retriever owns its corpus.

---

## 8. Acceptance-bar coverage

From `docs/NO_COMPROMISE_ENDGAME_PROMPT_DECK_2026_05_18.md` §4 T10:

| Required test path           | Coverage                                                                                                            |
|------------------------------|---------------------------------------------------------------------------------------------------------------------|
| Exact note hit               | `raw_archive::tests::exact_id_hit_returns_single_chunk`, `lexical::tests::deterministic_ordering_score_desc_then_id_asc` |
| `.epdoc` projection hit      | `raw_archive::tests::epdoc_projection_hit_routes_to_epdoc_kind`                                                      |
| Code hit                     | `code_symbol::tests::exact_symbol_hit_returns_one_per_occurrence`                                                    |
| Graph hit                    | `graph_neighborhood::tests::seed_neighbors_returned_in_sorted_order`                                                 |
| Duplicate merge              | `hybrid::tests::same_doc_in_both_modes_merges_to_single_hybrid_hit`                                                  |
| Fake citation rejection      | `types::tests::fabricated_source_id_is_rejected` + every `closed_citation_contract_holds_through_*` test per mode    |
| Empty vault                  | `lexical::tests::empty_index_returns_empty_packet`, `semantic::tests::empty_index_returns_empty_packet`, `raw_archive::tests::missing_id_returns_empty_packet`, `hybrid::tests::empty_inner_retrievers_return_empty_hybrid_packet` |
| Unicode query                | `lexical::tests::unicode_query_matches`, `code_symbol::tests::unicode_symbol_round_trip`, `graph_neighborhood::tests::unicode_document_ids_round_trip`, `claim_evidence::tests::unicode_claim_id_round_trips`, `raw_archive::tests::unicode_id_round_trips` |
| No-result defer              | `*::tests::missing_*_returns_empty_packet`, `*::tests::empty_query_*_returns_empty_packet`, `*::tests::top_k_zero_returns_empty_packet` |

---

## 9. What's next (still inside T10)

### 9.1 Done (T10 Rust substrate)

- All 9 retrieval modes shipped behind `EidosRetriever` (+ N-way `HybridRetrieverN`, + `ProvenanceVerifiedRetriever` wrapper). 10 backend types total.
- F-Eidos-ClosedCitation falsifier with 11-retriever canonical fixture corpus, JSON-serializable witness + tagged-enum failure, 20-run determinism guard, id-agnostic non-fixture corpus test.
- Cross-language parity fixture: Rust `serde` + Swift `Codable` byte-equal on a canonical packet.
- Wire-format pinned: PascalCase enums (mode + source kind), lowercase stance tokens, RRF `k = 60`.
- Swift mirror types declared with closed-citation `validate(citation:)` / `validate(citations:)` methods + Swift Testing tests.
- W-49 (LedgerBackedClaimEvidence) closed in code; snapshot-isolated; retraction propagation pinned.
- ~217 unit tests / 50+ commits / drift detectors for §4 retrieval-modes table + §11 research-question subsections.

### 9.2 Pending wiring (downstream of this branch)

In W-row priority order — all gated on W-46 Swift bridge FFI:

1. **W-46** `Epistemos/Eidos/EidosBridge.swift` — Sendable-friendly retrieval shim over Rust ↔ Swift FFI. Mirror types already declared; FFI plumbing + xcodebuild verification is the remaining gap.
2. **W-47** ChatCoordinator emit-path gate — wire `validate_citations` into the chat answer-emit flow. The Rust contract is proven by the chat-layer emit-gate hardening tests; the wiring lives in Swift.
3. **W-48** Brain Panel "Retrieved by Eidos" surface — render per-hit mode + manifest id + 4-component score breakdown. Eidos packets already carry every required field.
4. **W-50** `DagBackedGraphNeighborhood` over `agent_core::cognitive_dag` — production wiring for graph retrieval. Same shape as W-49 LedgerBacked.
5. **W-51** `ShadowBackedSemanticIndex` over `epistemos-shadow` usearch HNSW — needs a matching FFI surface on the shadow side.

### 9.3 Open research (see §11)

Four questions captured in §11 with schema-impact notes: embedding-model identity, RRF k = 60 tuning, provenance verification source-of-truth, web cut-line. Question 11.1 should be answered before W-46 ships because it may force a schema change to `EidosIndexManifest`.

### 9.4 Forever-loop discipline

Per the T10 acceptance bar's "FLOOR not CEILING" rule, this branch continues to harden after the spec is met. Recent additions (all post-acceptance):

- Adversarial query coverage (NUL byte, ZWJ emoji, 4096-char strings)
- Boundary tests (top_k = `u16::MAX`, Recency since = `u64::MAX`, lexical body with 1000-occurrence needle, lexical empty body, claim with no evidence, all-empty Hybrid_N, N=100 inner retrievers)
- Compositional invariants (PV over Hybrid_N, PV over LedgerBacked, nested PV, ledger + memory ClaimEvidence dedup by document_id)
- Cross-snapshot invariants (citation drift across packets, retraction propagation, commit-retract-recommit lifecycle)
- Doc/code drift detectors (§4 retrieval table row count, §11 research-question subsection count)

---

## 10. References

- `agent_core/src/eidos/` — all module sources.
- `epistemos-shadow/src/backend/rrf.rs:22` — `RRF_K_DEFAULT` source of truth.
- `Epistemos/Sync/RRFFusionQuery.swift` — Swift mirror of the same constant.
- `agent_core/src/provenance/ledger.rs` — `ClaimLedger` that the production `ClaimEvidence` wiring will sit in front of (later W-row).
- `agent_core/src/cognitive_dag/` — graph store the production `GraphNeighborhood` wiring will sit in front of (later W-row).
- `docs/audits/F_VAULT_RECALL_50_DIAGNOSIS_2026_05_16.md` — the retrieval-seam audit that originally motivated this T-prompt.
- `docs/fusion/research/quickcapture-addenda/OBSCURA_BROWSER_ADDENDUM.md` §Eidos — the upstream thesis.

> "Preserve wide, build narrow. Current-app value first. WRV is the floor, never the ceiling."

---

## 11. Open research questions

V0 ships with these decisions defaulted but not validated. Each is genuinely unresolved and could shift the design materially. Order is by how much the answer would force a schema change.

### 11.1 Embedding-model identity in the manifest

`EidosIndexManifest` pins `corpus_digest_hex` and `live_files_snapshot_id` but does NOT pin the embedding model that produced the vectors backing `Semantic` / `Hybrid` retrieval. If a user re-embeds their vault under a different model (Qwen → MiniLM → Apple Intelligence local embed), the same `manifest_id` could technically be reused — and Semantic packets from yesterday would be meaningless against today's index.

**Question:** do production systems (Notion AI, Obsidian Smart Connections, mem.ai) treat embedding-model-version as part of the snapshot identity, and how do they surface "your old citations are stale" to the user?

**Schema impact if yes:** add `embedding_model_id: Option<String>` to `EidosIndexManifest`. The cross-language parity fixture and drift detector would need updating in lock-step.

### 11.2 RRF k = 60 — is it actually tuned for Eidos?

`RRF_K_DEFAULT = 60` is inherited from `epistemos-shadow/src/backend/rrf.rs:22` (and the Cormack et al. 2009 IR paper). That paper tunes against TREC adversarial benchmarks — a very different retrieval distribution from "personal vault + claim graph + code symbols."

**Question:** does a short empirical ranking-quality study on a real 50-note vault justify keeping 60, or propose a different default for Eidos?

**Schema impact if different:** `with_k(k)` already allows per-instance override, so no schema change — just a doc note + a new default constant. The shadow + Swift mirror would diverge from Eidos's k, which is the bigger concern.

### 11.3 Provenance verification source of truth

`ProvenanceVerifiedRetriever` admits source_ids via an explicit set, but where does that set come from in production? Three plausible answers, no canonical decision:

  - (a) **Signed by a trusted source ledger.** Invisible to the user; relies on key-rotation hygiene.
  - (b) **Walk the claim ledger to confirm `ClaimStatus::Active`.** Cheapest to wire today (just call `LedgerBackedClaimEvidence`); the chunk-id-level grain doesn't match cleanly because claims and evidence are different keys.
  - (c) **Cryptographic witness attached per chunk.** The only one that survives an evil-server attack. Requires schema for `EidosHit.provenance.witness: Option<...>` — currently absent.

**Question:** what's the canonical V0 / V1 policy that populates the admit set?

**Schema impact:** option (c) is the only one that touches `EidosHit`. Options (a) and (b) live entirely outside the retriever.

### 11.4 Web augmentation cut-line

The acceptance bar says Eidos V0 is local-first; Eidos Plus adds web. But the `EidosRetriever` trait pretends web could plug in. Can the closed-citation contract survive against a non-snapshot source like a live URL?

**Question:** either extend with a `web_snapshot_hash` field (Wayback-style — Eidos snapshots the page bytes at retrieval time), or declare web fundamentally outside the contract.

**Schema impact:** option 1 adds an optional field on `EidosHit.provenance` for web-snapshot identity. Option 2 keeps Eidos V0 untouched and pushes web entirely into Eidos Plus with its own surface.

### Next research action

Question 11.1 (embedding-model identity) is the most likely to require a substantive schema change. Better to learn the answer before W-46 ships and Swift starts caching manifests against a fixed schema.

---

## 12. Cross-language wire-format symmetry

The five FFI-bound contract types that move between Rust and Swift over the future `EidosBridge` are pinned by parallel tests on both sides. Each row links the Rust serde pin (which fixes the JSON byte shape) to the Swift Codable test (which proves those exact bytes round-trip on the consumer). If either side legitimately needs to evolve the wire format, both pins must move in lock-step or one of the tests below fires.

| Contract type                | Rust pin (parity / types)                                                  | Swift mirror (EidosParityTests)                                            |
|------------------------------|----------------------------------------------------------------------------|----------------------------------------------------------------------------|
| `EidosContextPacket`         | `parity::canonical_packet_serializes_to_pinned_bytes`                      | `canonicalPacketDecodes`                                                   |
| `EidosCitation`              | embedded in the packet round-trip + closed-citation pins                   | `canonicalPacketDecodes` + `closedCitationContractAgainstCanonicalPacket`  |
| `EidosCitationEnvelope`      | `hardening_tests::eidos_citation_envelope_serializes_validated_citation_with_provenance` via `EidosContextPacket::citation_envelope` | `citationEnvelopeDecodesRustWireShape` via `EidosContextPacket.citationEnvelope(for:)` |
| `CitationError`              | `types::tests::citation_error_serializes_with_external_tag`                | `citationErrorDecodesRustWireShape` + `citationErrorEncodeRoundTrip`       |
| `Vec<(usize, CitationError)>`| `types::tests::batch_failure_byte_equal_pin_for_two_error_canonical_input` | `batchCitationErrorDecodesRustWireShape` + `batchCitationErrorRoundTrip`   |

Two further wire-format pins back this table up:

  - **Variant-name case forms** for both `EidosRetrievalMode` (9 variants) and `EidosSourceKind` (8 variants) are PascalCase on the wire. Pinned by `parity::eidos_retrieval_mode_json_case_forms_are_pinned` + `parity::eidos_source_kind_json_case_forms_are_pinned_via_canon_all` on the Rust side, and by `retrievalModeRawValuesMatchRust` + `sourceKindRawValuesMatchRust` on the Swift side. Renaming a variant breaks both at once.
  - **Drift detectors** for this section itself: STATUS.md ships a parallel table (drift detector under `hardening_tests::status_md_wire_symmetry_section_lists_all_four_contract_types`) and a doc-side detector under `hardening_tests::design_doc_section_12_wire_format_summary_lists_all_four_contract_types` ensures §12 keeps mentioning every contract type by name. `hardening_tests::design_doc_section_12_lists_typed_citation_envelope_wire_shape` additionally requires `EidosCitationEnvelope`, `EidosContextPacket::citation_envelope`, and `EidosContextPacket.citationEnvelope(for:)` to stay documented together. Both surfaces fire on a one-sided rename.

The acceptance-bar requirement was "Swift mirror types declared" — that floor was cleared early in the loop. §12 is the no-compromise position: the mirror is wire-format-validated, with two independent canonical surfaces (STATUS.md for contributors browsing the eidos/ tree, §12 for readers of the design doc) and three drift detectors keeping them honest.

### 12.1 Falsifier outcome types — Rust bidirectional, Swift mirror pending

The four contract types above are the *steady-state* FFI surface. Two additional types ride the same seam but are diagnostic outputs of the F-Eidos-ClosedCitation falsifier rather than retrieval primitives, and their Swift mirror is deferred to W-46 (`EidosBridge`). They are nevertheless already `Serialize + Deserialize` on the Rust side so a future Swift consumer can decode them byte-equal the day W-46 lands.

| Falsifier outcome type           | Rust pin                                                                  | Swift mirror   |
|----------------------------------|---------------------------------------------------------------------------|----------------|
| `FEidosClosedCitationWitness`    | `falsifier::tests::witness_json_round_trips_serialize_then_deserialize` + `witness_decodes_canonical_pinned_json_bytes` | `EidosFalsifierWitness` + `EidosParityTests.falsifierWitnessDecodesRustWireShape` |
| `FalsifierFailure`               | `falsifier::tests::failure_json_round_trips_across_canonical_variants` + `failure_decodes_canonical_pinned_json_bytes` + `failure_serialize_pins_exact_bytes_for_every_variant` | `EidosFalsifierFailure` + `EidosParityTests.falsifierFailureDecodesRustWireShape` (6 non-NaN variants) + `falsifierFailureHitConfidenceFiniteDecodes` + `falsifierFailureUnknownVariantTagErrors` |

`FalsifierFailure::HitConfidenceOutOfRange.confidence: f32` is the one documented round-trip exception: NaN serializes to JSON `null` per serde_json convention and is therefore not round-trip-safe (finite values round-trip cleanly; flight behavior for the NaN case is pinned via the falsifier path itself, not via JSON).

Both Swift mirrors landed by iter 72. `EidosFalsifierWitness` (iter 69) is straightforward Codable. `EidosFalsifierFailure` (iter 72) carries a hand-rolled Codable conformance that consumes the exact `serde(tag = "variant")` internal-tag JSON bytes Rust serializes — variant name as a sibling `"variant"` field alongside the payload. Unknown variant tags (a future Rust-side rename) decode as `DecodingError` on the Swift side, not silent fallback. The full F-Eidos-ClosedCitation falsifier outcome surface is now bidirectional on both sides of the FFI seam ahead of W-46 wiring it through `EidosBridge`.
