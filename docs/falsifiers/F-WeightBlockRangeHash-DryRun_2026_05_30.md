---
state: primary_witness
created_on: 2026-05-30
falsifier_id: F-WeightBlockRangeHash-DryRun
artifact: artifacts/falsifiers/weight_block_range_hash_dry_run/result.json
command: Tools/falsifiers/f_weight_block_range_hash_dry_run.sh
scope_guard: tiny in-memory fixture only; no model file, mmap, MLX, Metal, KV, or inference executed
---

# F-WeightBlockRangeHash-DryRun - 2026-05-30

## Verdict

`F-WeightBlockRangeHash-DryRun` proves the safe model byte-range hashing ABI
that future real `WeightBlockManifest` ingestion must use.

It hashes a tiny in-memory fixture through `WeightBlockManifest::from_reader_range`
with a caller-provided byte limit, rejects over-limit requests before hashing,
rejects short readers, and verifies that known-hash manifests can describe the
same range without loading it.

This is **not** a model-file pass. It does not touch a local model, mmap,
Metal, MLX, KV, or generation.

## Artifact Summary

Artifact:

```text
artifacts/falsifiers/weight_block_range_hash_dry_run/result.json
```

Minimum axes:

| Axis | Result |
|---|---:|
| Bounded range hashed | `true` |
| Range length <= max | `true` |
| Over-limit rejected before read | `true` |
| Short reader rejected | `true` |
| Known-hash manifest valid | `true` |
| No model file touched | `true` |

## What This Does Not Prove

- It does not hash real model weights.
- It does not prove 70B execution.
- It does not prove mmap residency.
- It does not prove KV-Direct or sparse runtime.

It is the guard that prevents future agents from fingerprinting large model
ranges without an explicit `max_bytes_to_hash` budget.
