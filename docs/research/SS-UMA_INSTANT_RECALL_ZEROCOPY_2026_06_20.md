# SS-UMA — Instant-recall via UMA zero-copy for local models (2026-06-20)

Read-only research (subagent), code-grounded + Apple/MLX facts. Feeds the INSTANT-RECALL-UMA flagship ledger
item. Owner: *"make a local model's search as fast as the 50ms FTS notes-sidebar — let models look directly into
the cache/memory via UMA, lower abstraction, but don't break the app or models."* **HARD CONSTRAINT: vault,
graph, TK2/Prose untouched.** Cross-refs the shadow index, SS-H, SS-PERF.

## Headline (honest)
The sidebar "instant" feel = TWO in-process engines: SQLite **FTS5 BM25** (`SearchIndexService`) + the
`epistemos-shadow` **tantivy BM25 + usearch HNSW + RRF k=60** cdylib via `RustShadowFFIClient`. Both in-process,
mmap-backed, bounded heaps, no subprocess. `InstantRecallService` already exists (binary-quantized, **<3ms
target**). **THE GAP: the local model does NOT use any of these.** Its `vault_recall`/`knowledge.recall` routes
through a SEPARATE `VaultStore` (its OWN tantivy index), and `eidos.query` semantic mode is an
`InMemorySemanticIndex` — the production shadow/HNSW backing is **NOT-STARTED** (W-51). So the model queries a
**colder, less-capable, DUPLICATE index** while the sidebar hits the warm RRF/HNSW fusion.
**UMA honesty: zero-copy is REAL + already exploited for MLX weights/KV (no CPU↔GPU copy), but zero-copy of
retrieved TEXT into the model's KV/context is NOT achievable today** — MLX-Swift consumes `prompt: String`; no
borrowed-buffer API. The honest win = **engine consolidation + removing the JSON round-trip**, NOT feeding
tensors into the KV. **And the real bottleneck is token GENERATION (100s of ms–seconds), not retrieval (already
single-digit ms)** — so making retrieval faster is invisible next to generation.

## Why notes-search is ~instant
- **FTS5** `Sync/SearchIndexService.swift`: own `search.sqlite`, `DatabasePool` queried from `nonisolated`
  methods (no actor hops, `:19-20,312`); PRAGMA `:236-248` (WAL, synchronous=NORMAL, temp_store=MEMORY,
  mmap_size=256MiB, cache_size=8MB, optimize) → warm mmap/page-cache reads, no syscall copy.
- **Shadow** `epistemos-shadow` cdylib: tantivy 0.22 BM25 + usearch 2.24 HNSW + **RRF k=60** (`backend/rrf.rs:22
  RRF_K_DEFAULT=60`); in-process via `@_silgen_name` `RustShadowFFIClient.swift:30-37 shadow_handle_search`;
  writer heap 15MB (`lexical_index.rs:42`); per-stage timings `ShadowSearchService.swift:302-323`.
- **RRF fusion** `Sync/RRFFusionQuery.swift`: `K_RRF=60.0 :186`; 3 CTEs + UNION ALL + GROUP BY + `epistemos_exp()`
  recency boost (`:299-308,381-419`); one-DB JOIN.
- **InstantRecallService** `KnowledgeFusion/InstantRecallService.swift`: `@MainActor @Observable` wraps
  `epistemos-core::instant_recall` (binary-quant two-phase), **<3ms target, warns >10ms (`:378`)**, FFI off-Main
  on a detached utility task (`:507-629`). The existing "instant recall" the owner means.
- **Truth:** in-process, mmap, bounded heaps, nonisolated queries. The ~50ms is dominated by SQLite query-plan +
  result hydration on a warm index; the engines themselves are sub-10ms.

## Model recall path today + the gap
- Model recall tools are entirely **in-process Rust `agent_core`** (no subprocess — `bridge.rs:3227-3280`). Good.
- **But a DIFFERENT index:** `vault_recall`/`knowledge.recall` (`tools/knowledge.rs:222,268`) →
  `VaultBackend::hybrid_search_with_trace` → `VaultStore`, opening its OWN tantivy `MmapDirectory`
  (`storage/vault.rs:794-803`, writer heap 15MB `:813`). NOT the `epistemos-shadow` index the sidebar uses.
- **Semantic tier is in-memory, not the production HNSW:** `eidos.query` semantic = `InMemorySemanticIndex`
  (`eidos/semantic.rs:5-7`: "production semantic path routes through epistemos-shadow's usearch HNSW … in-memory
  index ships behind the same trait"); shadow-backed impl **NOT-STARTED** (`eidos/STATUS.md:71` W-51); Tier-2
  embedding-only deliberately absent (`vault_search_ladder.rs:15-23`).
- **Cost:** tool-call → JSON args → VaultStore/in-memory query → JSON result → model reads text; retrieved text
  re-enters generation as a **prompt string** (`NoteChatState.swift:702-703`; MLX `generate(prompt:String)`
  `MLXInferenceService.swift:546`). The model queries a COLDER, less-capable index than the sidebar + never
  touches the warm RRF/HNSW fusion.

## UMA / zero-copy opportunity (+ honesty)
- **Real & exploited:** MLX arrays live in unified memory; CPU+GPU share physical RAM → weights/KV need NO copy
  (MLX unified-memory docs; WWDC25 "Get started with MLX"). `MLXInferenceService` already sizes Metal/KV caches
  against UMA budgets (`:397-420,1163-1195`).
- **FFI already supports direct in-process search** — `shadow_handle_search` (`RustShadowFFIClient.swift:30-37`)
  is plain C ABI returning JSON `char*`; agent_core could call the SAME shadow engine in-process instead of its
  own VaultStore (the code cross-references this as the intended prod backend: `eidos/semantic.rs:6`,
  `vault_search_ladder.rs:21`). Removes the SECOND index, not a copy.
- **NOT zero-copy-able today:** feeding retrieved text into MLX KV/context without serialization — MLX-Swift's
  public surface is `prompt:String`→tokenizer→tokens; no borrowed-buffer/precomputed-KV API. `<related_notes>` is
  a String concat (`NoteChatState.swift:702`). The genuine UMA zero-copy seam that DOES exist is the embedding/
  vector hot path (`falsify_uas_zero_copy_spine.rs` measures copy-count==0 on the Rust ledger path; the
  Swift/Metal/MLX/HNSW paths #1-4/#6 are explicitly UNMEASURED/blocked on Swift+Metal dispatch).
- **Net:** the FFI/UMA opportunity = ENGINE UNIFICATION (model + sidebar share one warm shadow index, results
  passed as borrowed `&str`/`Vec<ShadowHit>` not re-queried) — NOT literal tensor zero-copy into the KV.

## Safely replaceable vs must-stay
- **Swappable:** repoint `eidos.query` semantic + `vault_recall` from `InMemorySemanticIndex`/`VaultStore` to an
  **`epistemos-shadow`-backed `VaultBackend` adapter** (W-51, already scoped) — same trait, NO model-facing API
  change; share ONE warm shadow handle between sidebar + agent recall (kills the 2nd tantivy mmap + duplicate
  writer heap).
- **Must stay:** the JSON tool interface for CLOUD models (honest gating — only the BACKEND changes); the
  tier-4-6 LLM escalation gate (`vault_search_ladder.rs`, `EscalationPolicy::Never` default); provenance
  (`AgentToolProvenanceRecorder` events on every recall); the `<related_notes>` text-injection seam (NO honest
  zero-copy-KV alternative — don't claim one); vault/graph/TK2-Prose untouched (recall reads the vault's
  DERIVATIVE shadow/FTS index, never source bytes or the editor).

## The unified instant-recall design
One warm in-process retrieval spine, two consumers: (1) **single shadow handle** opened once at bootstrap
(`<vault>/.epcache/shadow`); sidebar + model recall both query it. (2) **model recall adapter** = an
`epistemos-shadow`-backed `impl VaultBackend` (W-51) so `vault_recall`/`eidos.query` hit the SAME RRF k=60 + HNSW
fusion the sidebar uses — closing the colder-index gap; Rust→Rust returns `Vec<ShadowHit>` directly (borrowed
`&str` snippets) → JSON round-trip removed for the LOCAL path. (3) **UMA-honest text handoff:** snippets still
enter MLX as the `<related_notes>` prompt string, but the embedding/vector work stays in unified memory (no
CPU↔GPU copy). (4) **honest gating preserved:** cloud keeps the JSON tool surface; only local models get the
direct Rust-to-Rust fast path; provenance on both.

## Honest gain estimate
- Model retrieval latency: **~sidebar-class achievable** (single-digit–low-tens ms) once it shares the warm
  shadow index; removing the JSON round-trip saves a parse, not orders of magnitude.
- **BUT end-to-end model recall is NOT bottlenecked by retrieval — token GENERATION dominates** (100s of ms–
  seconds for a local Qwen-class model). 50ms→8ms retrieval is invisible next to generation. **The defensible
  win is CORRECTNESS/QUALITY (model finally queries the warm RRF/HNSW = sidebar parity) + MEMORY (one tantivy
  index, not two: ~15MB writer heap + mmap saved)** — NOT a dramatic wall-clock speedup of the model's answer.
- **Zero-copy-into-KV: aspirational / not real today** — no MLX-Swift API; out-of-scope unless MLX exposes a
  borrowed-buffer prompt path.

## Ordered plan
1. **[S]** Add a provenance tag distinguishing "shadow-backed" vs "in-memory" recall so the gap is observable
   (`AgentToolProvenanceRecorder`).
2. **[S]** Share the single bootstrap shadow handle with the agent recall path (avoid the 2nd tantivy
   `MmapDirectory` in `VaultStore`).
3. **[M]** Implement the W-51 `epistemos-shadow`-backed `VaultBackend` adapter; route `eidos.query` Tier-2/3 +
   `vault_recall` through it behind a flag (mirror `EPISTEMOS_RRF_FUSION_V1`). Cloud tool interface unchanged.
4. **[M]** Bench model recall p50/p95 before/after (sidebar vs model, same query) to PROVE parity + show
   generation (not retrieval) is the floor — honest, no-fake.
5. **[L/research-only]** Investigate any MLX-Swift borrowed-buffer / precomputed-KV prompt path; aspirational
   until an API exists — never ship a fake "zero-copy KV" claim.

## Flagged
Literal zero-copy of retrieved text into MLX KV = no API found (not real); the exact "~50ms" is the owner's
number (engines are sub-10ms, SQLite hydration dominates; InstantRecall TARGET is <3ms `:378` — no committed
benchmark asserts exactly 50ms).

Key files: `Sync/SearchIndexService.swift:236-248,312` · `Sync/RRFFusionQuery.swift:186,381-419` · `epistemos-
shadow/src/backend/rrf.rs:22` · `Engine/RustShadowFFIClient.swift:30-37` · `Engine/ShadowSearchService.swift
:220-387` · `KnowledgeFusion/InstantRecallService.swift:265,378,507` · `epistemos-core/src/instant_recall/` ·
`agent_core/src/tools/knowledge.rs:222,268` · `agent_core/src/storage/vault.rs:794-813` (the model's SEPARATE
index) · `agent_core/src/eidos/semantic.rs:6` + `eidos/STATUS.md:71` (W-51) · `tools/vault_search_ladder.rs
:15-23` · `Engine/MLXInferenceService.swift:546,397-420` · `State/NoteChatState.swift:702-703` ·
`agent_core/src/bin/falsify_uas_zero_copy_spine.rs`. Sources: MLX unified-memory docs; WWDC25 MLX; ml-explore/mlx.
Cross-ref shadow index (`docs/RRF_FUSION_DESIGN.md`), SS-H, SS-PERF.
