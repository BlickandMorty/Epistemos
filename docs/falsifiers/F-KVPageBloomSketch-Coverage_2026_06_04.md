---
state: passed
created_on: 2026-06-04
falsifier_id: F-KVPageBloomSketch-Coverage
artifact: artifacts/falsifiers/kv_page_bloom_sketch_coverage/result.json
scope: metadata-only architecture witness
---

# F-KVPageBloomSketch-Coverage

North-star sentence: Epistemos is a local cognitive substrate where every meaningful object has an address, plane, budget, status, and witness; MAS ships the safe floor, Pro contains the gated/research/vault/omega ladder, and no claim promotes without visible proof.

- Result: PASS as a metadata-only primary witness on 2026-06-04.
- Script: `Tools/falsifiers/f_kv_page_bloom_sketch_coverage.sh`
- Artifact: `artifacts/falsifiers/kv_page_bloom_sketch_coverage/result.json`
- L1 next cursor at landing: `F-QueryAwareKVSelector`; current cursor after the 2026-06-04 `F-RouteDistillationTournament` witness is `F-ProofSearchSignal-RouteFeedback`
- L2 product route: unchanged, `vault_research_route_with_packetized_mitigation`; current next bottleneck `small_model_runtime_harness_fresh_product_runtime_l3_log_correlation_probe` after downstream `F-SmallModelRuntimeHarnessFreshProductRuntimeCapabilityRecheck`
- L3 user-facing/runtime route: unchanged; no live KV restore, sparse selector promotion, local model-byte load, 70B runtime claim, or UI claim is promoted.

## What It Proves

The witness proves a metadata-only `KVPageBloomSketch` fixture where Bloom-like page filters bind source indexes, source page references, page IDs, UAS KV-page addresses, page digests, feature hashes, compatibility fences, false-positive budgets, false-negative policy, required-evidence coverage, privacy class, rollback, RunEventLog, AnswerPacket, deterministic Bloom address, and shadow-only route authority before query-aware page selection can promote.

The fixture includes 2 Bloom sketches, 8 page candidates, 2 training candidates, 6 held-out candidates, and 4 required-evidence candidates. Required-evidence coverage is `10000` bps. Over-inclusion is allowed and measured with 2 non-required candidates selected; hash-only and tagless baselines cover only `5000` bps, and recency covers `0` bps. Runtime/model bytes loaded remain zero.

## Hardening

The falsifier rejects duplicate sketches and page candidates; missing source index, source page ref, UAS address, digest, feature hash, compatibility fence, false-positive budget, false-negative policy, required evidence, rollback, RunEventLog, or AnswerPacket; out-of-range feature hashes; incompatible fences; proof-critical or privacy-critical negative filtering; required-evidence false negatives; invalid privacy classes; hidden live authority; live policy mutation; hidden-chain exposure; cloud sources; metadata over budget; and unbeaten simple baselines.

## Scope

This advances L1 only. It does not make `KVPageBloomSketch` a live selector, does not restore live KV pages, does not permit hidden PatternBoost/lattice/Eidos route authority, does not load local model bytes, does not promote the 70B track to product runtime, and does not change MAS/Pro user copy. `F-QueryAwareKVSelector` now passes as metadata-only evidence; `F-SparseWakeCertificate-AnswerPacket` now passes metadata-only evidence; the `F-LayerKVJointLease` and `F-ShadowWakeOracle` now pass metadata-only evidence; the current architecture unit is `F-AblationShadowRun`, which must prove claimed useful units survive counterfactual remove-one-unit comparison before route-importance claims can promote.
