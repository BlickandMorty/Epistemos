# R-OKF — Open Knowledge Format + vault dedup/privacy verdict (2026-06-18)

Research-first verdict on (1) the Open Knowledge Format (OKF), (2) the best vault
**dedup** system, (3) the best **privacy** system. Owner ask: take/skip + free-vs-
paid + license + on-device-vs-cloud + best UX. All three are strong **TAKE**s and
— the headline — all three land on infra we **already have**.

## TL;DR

| Item | Verdict | Cost | License | On-device |
|---|---|---|---|---|
| **OKF** (Open Knowledge Format) | **TAKE as an interop/export format** for the vault + Knowledge Core | Free | Apache-2.0 | ✅ (it's just markdown) |
| **Privacy** (OpenAI Privacy Filter / `privacy-filter.cpp`) | **TAKE as a Pro "redact-before-cloud" guard** | Free | Apache-2.0 | ✅ GGML/CPU |
| **Dedup** (semantic near-duplicate notes) | **BUILD on our existing embeddings + usearch HNSW** (SemDeDup-style) | Free | — (our code) | ✅ |

## (1) OKF — TAKE as interop/export, zero dependency

OKF (Google Cloud, v0.1, **Apache-2.0**, vendor-neutral) represents knowledge as a
**directory of markdown files with YAML frontmatter**, one concept per file; the
only required field is `type`; no central authority, no SDK, git-diffable,
human-readable. **The Epistemos vault is already this shape** (markdown notes +
frontmatter in a directory). So OKF isn't a migration — it's an *export/interop*
win:

- **Export the Knowledge Core / curated notes as an OKF bundle** → portable,
  shareable, agent-ready, readable by any OKF consumer (incl. Google's Knowledge
  Catalog). Add a `type:` frontmatter field on export (the one required field).
- Optionally **ingest** OKF bundles (drop a folder → notes) — composes with the
  R-EVE filesystem-first pattern + our `SKILL.md` (which is itself OKF-ish).
- Zero code dependency (a format, not a library); fully on-device; free.
- Founding-Thesis fit: human-readable + diffable + portable = the same
  determinism/provenance ethos. Pairs with ClaimLedger (provenance) and the
  Cognitive DAG (structure) as the *portable* projection of curated knowledge.

UX: a "Export as Open Knowledge Format" action on the vault / Knowledge Core
(Settings or vault menu), honest about what it writes (the markdown bundle).

## (2) Privacy — TAKE OpenAI Privacy Filter as a Pro "redact-before-cloud" guard

`localai-org/privacy-filter.cpp` is a minimal **C++/GGML** runtime for OpenAI's
**Privacy Filter** (Apache-2.0, ~1.5B token-classifier, **96% F1** context-aware
PII detection, exact UTF-8 byte offsets, ~7.7× faster than HF on CPU). It runs
**fully on-device**.

- **Use case that fits our North Star:** when a turn routes to a CLOUD model, run
  the filter locally first to **mask PII before any context leaves the device**.
  This is the honest version of "local-first" privacy — local turns never need it;
  cloud turns get a real on-device guard.
- Lane: it's GGML/C++ (like our GGUF llama-cli lane) → **Pro/dev**, in-process if
  linked as a lib (MAS-honest, no Python, no hidden subprocess). ~1.5B ≈ 1–2 GB —
  Pro-only is the right gate on the 16 GB ship rig.
- Verdict: **TAKE as a Pro "Cloud privacy guard" toggle** — redact PII from
  outbound cloud context. Until the lane lands, an honest "available in Pro" note,
  never a fake toggle. (MAS default stays local-first, so PII rarely leaves
  anyway.)

## (3) Dedup — BUILD on the embeddings + HNSW we already have

Best practice splits two ways:
- **Textual near-dupes** → MinHash + LSH (Jaccard, sublinear; MinHash > SimHash).
- **Semantic dupes** (same meaning, different words) → **SemDeDup**: embed → ANN
  cluster → cosine-similarity threshold.

**We already have the semantic stack**: `TextEmbeddingLookup`,
`SemanticClusterService`, and the Halo shadow index (usearch 2.24 **HNSW** + RRF
fusion). So a **"find duplicate notes"** vault-maintenance pass is mostly wiring:
embed each note (have it) → ANN nearest-neighbor search in the existing HNSW (have
it) → flag pairs above a cosine threshold → present for **user-confirmed merge**
(never auto-delete — honest, reversible). Optional cheap MinHash for exact-ish
textual dupes.

- Verdict: **BUILD** a vault dedup affordance on the existing vector index;
  on-device, free, deterministic-friendly. UX: a vault-maintenance "Duplicate
  notes" review (cluster → suggest merge), user-confirmed.

## SKIP / not now

- Cloud dedup/privacy services (paid, off-device) — conflict with local-first.
- A bespoke new vector store for dedup — we have usearch HNSW; reuse it.

## Sources

- [OKF SPEC.md (GoogleCloudPlatform/knowledge-catalog)](https://github.com/GoogleCloudPlatform/knowledge-catalog/blob/main/okf/SPEC.md)
- [How the Open Knowledge Format can improve data sharing (Google Cloud Blog)](https://cloud.google.com/blog/products/data-analytics/how-the-open-knowledge-format-can-improve-data-sharing/)
- [Google Cloud introduces OKF (MarkTechPost)](https://www.marktechpost.com/2026/06/16/google-cloud-introduces-open-knowledge-format-okf-a-vendor-neutral-markdown-spec-for-giving-ai-agents-curated-context/)
- [localai-org/privacy-filter.cpp](https://github.com/localai-org/privacy-filter.cpp)
- [OpenAI Privacy Filter (on-device PII redaction)](https://openai.com/index/introducing-openai-privacy-filter/)
- [Finding near-duplicates with Jaccard + MinHash](https://blog.nelhage.com/post/fuzzy-dedup/)
- [SemDeDup — semantic deduplication (NVIDIA NeMo Curator)](https://docs.nvidia.com/nemo/curator/curate-text/process-data/deduplication/semdedup)
