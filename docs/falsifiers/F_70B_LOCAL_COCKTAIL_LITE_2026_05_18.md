---
falsifier: F-70B-Local-Cocktail-Lite
created_on: 2026-05-18
hardware_floor: M2 Pro 14-inch 2023, 12-core CPU, 19-core GPU, 16 GB UMA, approximately 200 GB/s
status: NOT IMPLEMENTED
---

# F-70B-Local-Cocktail-Lite

Handbook row: [M2 Pro Verified Floor Handbook](M2_PRO_VERIFIED_FLOOR_HANDBOOK_2026_05_18.md).

| Field | Value |
|---|---|
| Purpose | Prove the 70B-class local cocktail composes enough to identify whether the capability ceiling is real on the M2 Pro floor, without presenting it as a product feature. |
| Current status | NOT IMPLEMENTED. `docs/HELIOS_V6_1_NEW_RESEARCH_INTEGRATION_2026_05_16.md` defines the Phase B.0-LARGE gate, and `docs/audits/CROSS_TERMINAL_WIRING_BACKLOG_2026_05_17.md` W-43 keeps the composition harness NOT-STARTED. No local 70B model artifact, sparse path, cloud fp16 reference, bottleneck report, or T23B script exists. |
| Input fixture | 70B-class candidate set such as Llama-3.3-70B, Qwen2.5-72B, or Hermes-4-70B; 50-prompt suite covering MMLU-Pro subset, HumanEval, long-context reasoning, and multi-turn coherence; cloud/fp16 reference path; sparse local path using ternary/BitNet, hybrid SSM, KV-Direct, PageGather, active assembly, speculative decoding, and optional cascade. |
| Pass threshold | On Jojo's M2 Pro 14-inch 2023, 16 GB UMA, approximately 200 GB/s memory bandwidth: D_KL < 0.1 nats versus fp16/cloud reference, decode >= 5 tok/s, TTFT <= 30 s on a 4k prompt, resident memory < 14 GB, first run <= 2 h, and warm-cache run <= 30 min; any miss must identify the bottleneck. |
| Failure meaning | The 70B local-cocktail composition does not hold on the real floor, or the bottleneck is unknown; no local 70B product, marketing, or architecture-ceiling claim may ship. |
| Fallback route | Publish the fail report and pivot to the next strongest cocktail, likely Granite-4.0-H-Micro plus Network Cascade for large-model outliers; keep 70B paths Vault/Research-only. |
| Product lane | Capability Ceiling / Vault-Research only; never MAS/user-facing until the composition artifact passes and product policy is revisited. |
| Exact command | NOT IMPLEMENTED: `tools/falsifiers/f_70b_local_cocktail_lite.sh` |
| Expected artifact | `artifacts/falsifiers/70b_local_cocktail_lite/result.json` with prompt-level D_KL, TTFT, tok/s, RSS, cache state, component bottleneck, and next-best-cocktail recommendation. |

## Canon Anchors

- MASTER_FUSION: [§1 local-computer thesis](../_consolidated/00_canonical_authority/MASTER_FUSION.md#1--what-epistemos-is-the-one-paragraph-thesis-distilled-from-5-docs) and [§3 claim 2 honest capability gating](../_consolidated/00_canonical_authority/MASTER_FUSION.md#3--convergent-claims-where-3-docs-agree--these-are-bedrock), because the 70B cocktail is ceiling research until the local floor proves it.
- Unified Active Substrate Canon: [§4 Terminal B prompt cross-link](../fusion/UNIFIED_ACTIVE_SUBSTRATE_CANON_2026_05_16.md#4-uas-acs-cross-link-map) and [§5 MAS-first sort](../fusion/UNIFIED_ACTIVE_SUBSTRATE_CANON_2026_05_16.md#5-v1--v1x--v2--never-ships-sort), which keep this gate Vault/Research-only.

## Failure Criterion

This falsifier fails if D_KL is at least 0.1 nats, decode is below 5 tok/s, TTFT exceeds 30 s on a 4k prompt, resident memory reaches 14 GB, first or warm-cache runtime exceeds the threshold, the miss lacks a bottleneck, or no Jojo M2 Pro 16 GB UMA artifact exists.

## Artifact Schema Axes

The expected `result.json` must conform to [Falsifier Artifact Schema](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md) and include these minimum axes in `measurements`, `acceptance_thresholds`, and `pass_per_axis`: `d_kl_nats`, `decode_tok_s`, `ttft_seconds`, `resident_memory_gb`, and `bottleneck_identified`.
