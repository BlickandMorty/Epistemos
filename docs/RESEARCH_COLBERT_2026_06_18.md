# R-COLBERT-TOOLSEL verdict — LiquidAI/LFM2-ColBERT-350M (2026-06-18)

**Verdict: RESEARCH-FIRST / DEFER to Pro+dev. No PyLate on the product path
(NO-SIDECAR). The native lane is real but non-trivial — the crux is the LFM2
*hybrid* encoder, not the scoring. Pre-build the trivial MaxSim substrate
(always-compiled, feature-gated, inert) now; ship a native single-vector
"tool-selector v0" as the honest interim; gate a true ColBERT lane behind a
native encoder export that does not yet exist. It is an ENHANCEMENT to
already-working rerank/tool-selection lanes, not a gap-filler. No code lifted.**

## What it is (primary source: HF model card)
- `LiquidAI/LFM2-ColBERT-350M` — 353,322,752 params on the **LFM2** backbone.
- **17 layers: 10 conv + 6 attn + 1 dense** — LiquidAI's hybrid, NOT a vanilla
  BERT encoder. This is the single most important integration fact (below).
- **Late-interaction** retriever/reranker via **MaxSim**: 128-dim embedding PER
  TOKEN (not one vector per doc); doc ≤512 tokens, query ≤32 tokens; 32K ctx;
  8 languages.
- **Deployment: PyLate (Python) ONLY.** The card documents `pip install pylate`
  + `from pylate import models, indexes, rank` and a web demo Space. **No ONNX,
  CoreML, GGUF, llama.cpp, MLX, or LiquidAI LEAP/native option exists.** Owner's
  catch confirmed verbatim.
- License: **LFM Open License v1.0 (LFM1.0)** → must pass
  `F-ProprietaryCompression-ProvenanceGate` license check before any vendor.

## Why this is harder than classic ColBERT
Classic ColBERTv2 sits on a standard BERT encoder with clean torch→ONNX exports
and many community CoreML/ONNX rerankers. LFM2-ColBERT does NOT: its encoder is
the LFM2 **conv+attention hybrid**. So the usual "export the BERT encoder to
ONNX" shortcut is unproven here. The native port splits into two very unequal
halves:

1. **The encoder (HARD)** — produce the per-token 128-dim ColBERT embeddings on
   Apple Silicon. Options, ranked by tractability:
   - **CoreML/ONNX export** (most tractable): self-export the LFM2 encoder
     (LiquidAI ships none). Conv + GQA-attention layers export, but it's
     unproven for this arch + needs our own export+validation harness.
   - **MLX-Swift port**: port the LFM2 hybrid encoder block to MLX + add the
     128-dim per-token projection/normalization head. Heaviest; only worth it if
     an LFM2 MLX path already exists to reuse.
   - PyLate (Python): **NO-SIDECAR on MAS.** Dev/bench only, never product.
2. **MaxSim scoring (TRIVIAL)** — `score = Σ_q max_d (q·d)` over the per-token
   matrices. ~30 lines of Rust/Swift over precomputed embeddings. **This is the
   part we CAN pre-build now** as always-compiled substrate (feature-gated,
   inert) — but it is USELESS without (1): you cannot MaxSim arbitrary
   single-vector embeddings; they must come from the ColBERT-trained encoder.

So "implement MaxSim over the existing embedding infra" (ledger option 3) does
NOT yield ColBERT — our existing embeddings (NLContextualEmbedding, TurboVec)
are single-vector and not ColBERT-trained. MaxSim needs the encoder's token
embeddings specifically.

## Side-by-side vs what Epistemos already has
| Owner role | Epistemos today | Verdict |
|---|---|---|
| **(1) Tool selector** (pick which tools/MCP to surface per query) | tool-tier gating + per-tool allowlist + **P8.1 deterministic schema gate**; no semantic ranking of the tool catalog | ➖ ENHANCEMENT. Tools are already gated correctly; ColBERT would rank them *better*. Honest interim = a native single-vector "tool-selector v0" (cosine over tool-description embeddings via the EXISTING NLContextualEmbedding, MAS-safe), clearly labeled single-vector. ColBERT is the upgrade once a native encoder lands. |
| **(2) RAG reranker** | **EML-3 `eml_rerank`** gate (Rust, vault.rs) + **RRF fusion** (tantivy BM25 + usearch HNSW, k=60) + Eidos/Halo/TurboVec | ➖ ENHANCEMENT. A late-interaction rerank lane would be stronger on token-level matching, but rerank is already served. Slot ColBERT as an OPTIONAL stronger rerank backend behind the existing `eml_rerank` seam — Pro/dev, native-encoder-gated. |
| **(3) Selectable model in importer/registry** | chat-model picker (Fast/Think/Code) + HF importer | ⚠️ HONESTY GATE. It is a RETRIEVAL/RERANK component, NOT a chat model — it must NEVER appear in the chat picker (that would fake a capability). If surfaced at all, it's a RETRIEVAL-BACKEND entry (Pro/dev), gated on a native encoder. |

## Recommendation (honest, no fake tool-selector)
1. **No PyLate on the product path.** Dev/bench harness only (Pro), to generate
   reference embeddings + a parity oracle for a future native port.
2. **Pre-build the MaxSim substrate now** — a pure, always-compiled,
   feature-gated (`EPISTEMOS_COLBERT_MAXSIM_V0`, default OFF), unit-tested
   `maxsim(query_tokens, doc_tokens)` scorer in Rust. Inert until an encoder
   feeds it. This is the only piece that's cheap + safe to land today; it is NOT
   ColBERT by itself and must be labeled as such (no "ColBERT live" claim).
3. **Honest interim tool-selector** — if/when P8 RAG-preflight tool-selection is
   built, back its v0 with the EXISTING native single-vector embeddings (cosine
   over tool descriptions), explicitly single-vector. Reserve "late-interaction
   tool selector" for after a native encoder export.
4. **Native encoder = the gating deliverable.** Verdict on the encoder path
   itself: try **self-exported CoreML/ONNX of the LFM2 encoder** first (most
   tractable), validate per-token output against the PyLate oracle, then wire
   MaxSim. MLX-Swift port only if an LFM2 MLX encoder already exists to reuse.
   Until that export validates, ColBERT stays Pro/dev-gated and is NOT claimed
   as available.
5. **License**: route LFM1.0 through `F-ProprietaryCompression-ProvenanceGate`
   before vendoring any weights/refs.

## Net
Real, attractive capability (token-level retrieval beats single-vector on hard
queries), but it fills no current GAP — tool gating + rerank already work — and
its only shipping path is Python (forbidden on MAS). The native lane hinges on a
non-trivial hybrid-encoder export that doesn't exist yet. So: pre-build the
trivial MaxSim substrate inert + feature-gated, keep an honest single-vector
interim, and gate the true ColBERT lane behind a validated native encoder. No
code lifted this slice (research-first verdict). Cross-ref: P8 schema engine,
HARNESS SYSTEMS (MCP routing), EML-3 `eml_rerank`, RRF fusion.
