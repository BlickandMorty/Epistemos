---
falsifier: F-UAS-CopyCount
created_on: 2026-05-24
hardware_floor: M2 Pro 16 GB UMA
status: PASS
artifact: artifacts/falsifiers/uas_copy_count/result.json
---

# F-UAS-CopyCount

## Result

PASS on one measured run.

Command:

```bash
cargo +stable run --manifest-path agent_core/Cargo.toml --bin uas_copy_count
```

Measured artifact:

- `tensor_copy_count`: 0
- `data_copy_bytes`: 0
- hot-path labels: Swift shared buffer, Rust slice view, Metal shared buffer,
  MLX KV view, HNSW vector view

## Scope Note

This harness measures the T14 UAS copy counter over the shared-backing hot-path
fixture. It does not claim the full MLX production generation loop is copy-free;
that remains covered by the broader F-UAS-ZeroCopy-Spine path.

## Acceptance

The falsifier passes iff the measured hot path records zero tensor/data copies
after the shared backing is created. Metadata and JSON artifact serialization
happen after the measured region and are recorded separately in the artifact.
