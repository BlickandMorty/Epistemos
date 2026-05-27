# PageGather Metal Failure Witness - 2026-05-27

Status: failure evidence landed; no product green promotion.

Branch: `codex/pagegather-metal-primary-witness-2026-05-27`

## Canonical Read Order

1. `docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md`
2. `docs/EPISTEMOS_LIVING_INDEX_2026_05_24.md`
3. `docs/audits/LEGENDARY_POST_WAVE4_ROLLUP_2026_05_27.md`
4. `docs/falsifiers/F-PageGather-M2Pro_2026_05_17.md`
5. `Epistemos/Shaders/PageGather.metal`

## What This Slice Does

This slice does not wire PageGather into a product hot path. It adds the missing
hardware witness harness and records the first real sustained Metal result.

Added harness:

`Tools/metal-witness-gates/page-gather-metal-artifact.swift`

Failure artifact:

`artifacts/falsifiers/page_gather/metal_failure_result.json`

The harness compiles `Epistemos/Shaders/PageGather.metal`, adds an in-harness
STREAM triad kernel, then measures sequential gather and random scatter against
the measured STREAM ceiling.

## Result

The 256 MB mandatory-size run used:

```text
swift Tools/metal-witness-gates/page-gather-metal-artifact.swift --working-sets-mb 256 --window-seconds 5 --trials 3 --warmup-iterations 3 --write-artifact
```

Measured result:

| Axis | Median | Threshold | Verdict |
|---|---:|---:|---|
| STREAM triad | ~236 GB/s | > 0 | PASS |
| Sequential gather | ~175 GB/s / 0.74x STREAM | >= 0.95x | FAIL |
| Random scatter | ~15 GB/s / 0.064x STREAM | >= 0.70x | FAIL |
| Gather correctness | 0 sampled violations | 0 | PASS |
| Scatter correctness | 0 sampled violations | 0 | PASS |
| Scatter stability | ~0.003 range/mean | < 0.15 | PASS |
| Second-run ratio | ~1.00 | >= 0.90 | PASS |

The shader is semantically correct but not architecturally fast enough. The
current scalar one-thread-per-output pattern cannot be promoted to the
PageGather primary witness.

## No-Orphan Check

- Motion: Project / Verify.
- UAS: no new address shape; this measures the page-retrieval verification
  path already referenced by the PageGather falsifier.
- Plane: retrieval / page plane.
- Residency: Apple Silicon UMA via shared Metal buffers.
- WBO/error: the failing ratio is explicit; no fallback witness overwrites
  `result.json`.
- Witness: failure artifact, harness, falsifier doc, Living Index, and rollup.
- Falsifier: `F-PageGather-M2Pro`.
- Tier: Research / VerifiedFloor failure evidence; product UI remains
  orange/pending.
- Rollback: remove the harness/failure artifact/doc updates to return to the
  prior CPU fallback-only state.

## Next Mitigation

Run a focused kernel mitigation slice before any downstream PageGather wiring:

1. Sweep threadgroup sizes `{32, 64, 128, 256}`.
2. Add a 4-wide vectorized gather variant or block-sorted scatter variant.
3. Re-run the 256 MB gate first.
4. Only after 256 MB passes, run the full 256/512/1024 MB canonical gate.

Until that happens, `F-PageGather-M2Pro` remains pending and must not be shown
as green.
