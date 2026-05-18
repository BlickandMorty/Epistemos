---
falsifier: F-KV-Direct-Gate
created_on: 2026-05-18
hardware_floor: M2 Pro 14-inch 2023, 12-core CPU, 19-core GPU, 16 GB UMA, approximately 200 GB/s
status: PARTIAL SUBSTRATE, NOT FULLY PASSED
---

# F-KV-Direct-Gate

Handbook row: [M2 Pro Verified Floor Handbook](M2_PRO_VERIFIED_FLOOR_HANDBOOK_2026_05_18.md).

| Field | Value |
|---|---|
| Purpose | Prove the L3 SSD Oracle / KV-Direct memory floor: residual-patched cold-spill KV reproduces full-cache output at 128K without blowing the 16 GB rig. |
| Current status | PARTIAL SUBSTRATE, NOT FULLY PASSED. `agent_core/src/scope_rex/kv/direct_gate.rs` and `Epistemos/Shaders/kv_direct_gate.metal` implement the Tier-1 layout/equality contract, but `docs/HELIOS_V6_1_NEW_RESEARCH_INTEGRATION_2026_05_16.md` marks the end-to-end harness NOT-STARTED. No 100-prompt Qwen3-8B M2 Pro artifact or T23B script exists. |
| Input fixture | Qwen3-8B-MLX-4bit at 128K context; 100 prompts split into 25 long-prefix recall, 25 multi-turn, 25 code-completion, and 25 reasoning cases; full-RAM KV reference path; residual-patched mmap/NF4 KV test path; synthetic SSD spill is allowed if labeled. |
| Pass threshold | On Jojo's M2 Pro 14-inch 2023, 16 GB UMA, approximately 200 GB/s memory bandwidth: average D_KL between reference and residual-patched logits < 0.05 nats, peak RAM < 13 GB, decode speed >= 10 tok/s, and wall-clock for the suite <= 30 min. |
| Failure meaning | KV-Direct does not generalize to the target Qwen3/MLX/128K floor; the app cannot claim 128K local context via SSD oracle on 16 GB hardware. |
| Fallback route | Pivot to softer eviction: selective cold-region purge, prefix caching, attention-sink preservation, or sliding-window attention; keep full-cache/reference path authoritative. |
| Product lane | Verified Floor / MAS-compatible only after gate; Research until Qwen3 128K artifact exists. |
| Exact command | NOT IMPLEMENTED: `tools/falsifiers/f_kv_direct_gate.sh` |
| Expected artifact | `artifacts/falsifiers/kv_direct_gate/result.json` with per-prompt D_KL, token-match/decode metrics, peak RSS, SSD-spill trace, and fallback decision. |

## Canon Anchors

- MASTER_FUSION: [§3 claim 11 multi-objective KV cache precision allocation](../_consolidated/00_canonical_authority/MASTER_FUSION.md#3--convergent-claims-where-3-docs-agree--these-are-bedrock) and [§3 claim 4 Apple Silicon unified memory](../_consolidated/00_canonical_authority/MASTER_FUSION.md#3--convergent-claims-where-3-docs-agree--these-are-bedrock).
- Unified Active Substrate Canon: [§2 row 3 KV-Direct gate](../fusion/UNIFIED_ACTIVE_SUBSTRATE_CANON_2026_05_16.md#2-the-6-canonical-surfaces), which is the UAS memory-architecture floor.

## Failure Criterion

This falsifier fails if average D_KL is at least 0.05 nats, peak RAM reaches 13 GB, decode speed drops below 10 tok/s, the 100-prompt suite exceeds 30 min, SSD spill is unlabeled, or no Jojo M2 Pro 16 GB UMA artifact exists.

## Artifact Schema Axes

The expected `result.json` must conform to [Falsifier Artifact Schema](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md) and include these minimum axes in `measurements`, `acceptance_thresholds`, and `pass_per_axis`: `average_d_kl_nats`, `peak_ram_gb`, `decode_tok_s`, `suite_wall_clock_min`, and `spill_labeling`.
