---
falsifier: F-Sparse-Runtime-Split
created_on: 2026-05-28
hardware_floor: M2 Pro 14-inch 2023, 12-core CPU, 19-core GPU, 16 GB UMA, approximately 200 GB/s
status: PRIMARY SYNTHETIC RUNTIME WITNESS IMPLEMENTED
artifact: artifacts/falsifiers/sparse_runtime_split/result.json
---

# F-Sparse-Runtime-Split

Purpose: prove that a selected sparse/active support set can reproduce a
dense/reference execution within bounded drift, while carrying the chart
coverage labels the Capability Ceiling route needs.

## Current Artifact

Command:

```bash
Tools/falsifiers/f_sparse_runtime_split.sh
```

Artifact:

```text
artifacts/falsifiers/sparse_runtime_split/result.json
```

Current measured axes:

| Axis | Current value | Threshold |
|---|---:|---:|
| `prompt_count` | 1000 | 1000 |
| `assembly_count` | 512 | 512 |
| `average_d_kl_nats` | 0.0 | <= 0.05 |
| `p95_d_kl_nats` | 0.0 | <= 0.05 |
| `max_d_kl_nats` | 0.0 | <= 0.10 |
| `top1_match_ratio` | 1.0 | >= 0.99 |
| `active_assembly_ratio` | 0.017578 | < 0.40 |
| `cost_ratio` | 0.006659 | < 0.40 |
| `wall_us_p99` | 30.542 us | < 10,000 us |
| `eml_chart_coverage_available` | true | true |
| `geometry_chart_coverage_available` | true | true |
| `scan_chart_coverage_available` | true | true |
| `operator_chart_coverage_available` | true | true |
| `residency_split_labeled` | true | true |
| `mas_safe_in_process_contract` | true | true |

## Scope

This is a primary witness for the synthetic sparse-runtime contract. It is not
a live 70B sparse runtime, not a KV-spill proof, and not a product claim. The
70B cocktail reads it as `sparse_runtime_split_artifact_available=true` and
`synthetic_ir_chart_coverage_available=true`, while keeping
`sparse_70b_runtime_available=false` and
`eml_geometry_scan_chart_coverage_available=false` until real model-backed
runtime inputs exist.

## Tier

| Field | Value |
|---|---|
| Motion | Mutate / Promote: dense/reference execution is projected through a selected sparse support set. |
| UAS | Synthetic assembly ids and chart rows; real UAS weight/KV addresses remain future work. |
| Plane | Verification plane. |
| Residency | Capability Ceiling substrate witness; MAS-safe because it is in-process and does not require subprocesses or external model assets. |
| WBO | Average KL budget <= 0.05 nats, p95 <= 0.05, max <= 0.10. |
| Witness | `artifacts/falsifiers/sparse_runtime_split/result.json`. |
| Falsifier | `F-Sparse-Runtime-Split`. |
| Rollback | Keep 70B route Vault/Research-only; ignore this artifact for live-model promotion if real 70B weights/KV/logits are absent. |

## Next Step

The next promotion is a model-backed sparse runner that writes the same axes
against a small real local model first, then a Qwen3-8B or 70B-class candidate.
Only that future artifact can move the 70B cocktail's live sparse runtime axis.
