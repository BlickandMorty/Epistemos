---
state: passed
created_on: 2026-06-04
falsifier_id: F-QueryAwareKVSelector
artifact: artifacts/falsifiers/query_aware_kv_selector/result.json
scope: metadata-only architecture witness
---

# F-QueryAwareKVSelector

North-star sentence: Epistemos is a local cognitive substrate where every meaningful object has an address, plane, budget, status, and witness; MAS ships the safe floor, Pro contains the gated/research/vault/omega ladder, and no claim promotes without visible proof.

- Result: PASS as a metadata-only primary witness on 2026-06-04.
- Script: `Tools/falsifiers/f_query_aware_kv_selector.sh`
- Artifact: `artifacts/falsifiers/query_aware_kv_selector/result.json`
- L1 next cursor: `F-SparseWakeCertificate-AnswerPacket`
- L2 product route: unchanged, `vault_research_route_with_packetized_mitigation`; next bottleneck `sparse_wake_certificate_answer_packet`
- L3 user-facing/runtime route: unchanged; no live KV restore, sparse selector promotion, local model-byte load, 70B runtime claim, or UI claim is promoted.

## What It Proves

The witness proves a metadata-only `QueryAwareKVSelector` fixture where selector rows consume upstream `KVPageSketchIndex` and `KVPageBloomSketch` evidence, bind selector IDs, missions, query signatures, model/tokenizer identity, page IDs, UAS KV-page addresses, source-index refs, Bloom refs, page digests, compatibility fences, semantic tags, query/evidence/verifier utility, recency, file order, active bytes, restore latency, privacy class, required evidence, rollback, RunEventLog, AnswerPacket, deterministic selector address, and shadow-only authority.

The fixture includes 2 selectors, 8 page candidates, 2 training candidates, 6 held-out candidates, 4 selected pages, and 4 required-evidence pages. Query selector success is `10000` bps while recency, random, file-order, and Bloom-only baselines remain below the query-aware selector. Selected active bytes, latency, quality, verifier score, and metadata bytes stay within budget, and runtime/model bytes loaded remain zero.

## Hardening

The falsifier rejects duplicate selectors and pages; missing query, selected page, required evidence, UAS address, digest, Bloom ref, false-negative policy, rollback, RunEventLog, or AnswerPacket evidence; unknown selected pages; selected pages outside the Bloom prefilter; stale or incompatible selected pages; hidden live authority; live policy mutation; hidden-chain exposure; cloud sources; invalid privacy classes; over-budget or over-latency selections; verifier bypass; low-quality selections; metadata over budget; and unbeaten simple baselines.

## Scope

This advances L1 only. It does not make `QueryAwareKVSelector` a live KV selector, does not restore live KV pages, does not permit hidden PatternBoost/lattice/Eidos route authority, does not load local model bytes, does not promote the 70B track to product runtime, and does not change MAS/Pro user copy. The next architecture unit is `F-SparseWakeCertificate-AnswerPacket`, which must prove selected sparse/KV units, budgets, verifier/citation/test results, traces, uncertainty, fallback, and rollback are visible in an AnswerPacket-bound certificate before live route authority can promote.
