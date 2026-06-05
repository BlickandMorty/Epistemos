---
state: passed
created_on: 2026-06-04
falsifier_id: F-KVPageSketchIndex
artifact: artifacts/falsifiers/kv_page_sketch_index/result.json
scope: metadata-only architecture witness
---

# F-KVPageSketchIndex

North-star sentence: Epistemos is a local cognitive substrate where every meaningful object has an address, plane, budget, status, and witness; MAS ships the safe floor, Pro contains the gated/research/vault/omega ladder, and no claim promotes without visible proof.

- Result: PASS as a metadata-only primary witness on 2026-06-04.
- Script: `Tools/falsifiers/f_kv_page_sketch_index.sh`
- Artifact: `artifacts/falsifiers/kv_page_sketch_index/result.json`
- L1 next cursor at landing: `F-KVPageBloomSketch-Coverage`; current cursor after the 2026-06-04 `F-RouteDistillationTournament` witness is `F-ProofSearchSignal-RouteFeedback`
- L2 product route: unchanged, `vault_research_route_with_packetized_mitigation`; current next bottleneck `small_model_runtime_harness_logged_runtime_smoke` after downstream `F-SmallModelRuntimeHarnessAbortableRuntimeProbe`
- L3 user-facing/runtime route: unchanged; no live KV restore, sparse selector promotion, local model-byte load, 70B runtime claim, or UI claim is promoted.

## What It Proves

The witness proves a metadata-only `KVPageSketchIndex` fixture where KV/page sketches bind page IDs, UAS KV-page addresses, source references, page digests, byte counts, min/max key sketches, semantic tags, recency, hit/miss telemetry, compatibility fences, required-evidence coverage, privacy class, false-negative policy, rollback, RunEventLog, AnswerPacket, deterministic sketch-index address, and shadow-only route authority before query-aware page selection can promote.

The fixture includes 2 sketch indexes, 8 page sketches, 2 training pages, 6 held-out pages, and 4 required-evidence pages. Required-evidence coverage is `10000` bps and beats recency, tagless, and file-order baselines. Runtime/model bytes loaded remain zero.

## Hardening

The falsifier rejects duplicate indexes and pages; missing UAS addresses, digests, byte counts, min/max sketches, semantic tags, hit/miss telemetry, compatibility fences, required evidence, false-negative policy, rollback, RunEventLog, or AnswerPacket; zero or oversized pages; sketch dimension mismatch; invalid min/max sketch ordering; stale or incompatible pages; invalid privacy classes; hidden live authority; live policy mutation; hidden-chain exposure; cloud sources; metadata over budget; and unbeaten simple baselines.

## Scope

This advances L1 only. It does not make `KVPageSketchIndex` a live selector, does not restore live KV pages, does not permit hidden PatternBoost/lattice/Eidos route authority, does not load local model bytes, does not promote the 70B track to product runtime, and does not change MAS/Pro user copy. `F-KVPageBloomSketch-Coverage` now passes as metadata-only evidence; `F-SparseWakeCertificate-AnswerPacket` now passes metadata-only evidence; the `F-LayerKVJointLease` and `F-ShadowWakeOracle` now pass metadata-only evidence; the current architecture unit is `F-AblationShadowRun`, which must prove claimed useful units survive counterfactual remove-one-unit comparison before route-importance claims can promote.
