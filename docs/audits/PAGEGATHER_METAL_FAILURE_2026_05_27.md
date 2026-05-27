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

## Access-Pattern Reclassification

The failure witness changes the canonical meaning of "scatter" in code and
docs:

- `Sequential`: correctness + easy-path throughput baseline.
- `LocalWindow`: product-promotable candidate pattern when the page scheduler
  keeps source coverage narrow.
- `SparseScatter`: product-promotable candidate pattern only if the scheduler
  keeps density low enough to avoid full-source churn.
- `FullCoverageRandom`: failure stressor. It proves semantic correctness but
  must not be treated as a green product layout until a locality-aware schedule
  or equivalent mitigation clears the measured gate.

`agent_core::helios::PageGatherStats::access_class(...)` now makes this
distinction explicit so future callers cannot silently collapse the failure
stressor into the product path.

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

The first focused mitigation probe now exists:

`docs/audits/PAGEGATHER_LOCALITY_PROBE_2026_05_27.md`

It writes
`artifacts/falsifiers/page_gather/locality_probe_result.json` and keeps the
primary failure report intact. On a 256 MB, 5 s, 3-trial run, local-window
scatter reached about `1.08x` measured STREAM and block-sorted scatter reached
about `0.734x` measured STREAM with zero sampled correctness violations. That
is promising scheduler evidence, not a product-green pass.

The scheduler contract follow-up now lives in
`docs/audits/PAGEGATHER_BLOCK_SORTED_SCHEDULER_2026_05_27.md`: Rust can build a
block-sorted execution plan and restore logical output order, and Vault Recall
traces surface the schedule as deferred measurement metadata.

Continue the kernel/scheduler mitigation slice before any downstream PageGather
promotion:

1. Sweep threadgroup sizes `{32, 64, 128, 256}`.
2. Add the Metal-side destination-position contract for block-sorted execution.
3. Add a 4-wide vectorized gather variant if gather still stays below `0.95x`.
4. Re-run the 256 MB gate first.
5. Only after 256 MB passes, run the full 256/512/1024 MB canonical gate.

Until that happens, `F-PageGather-M2Pro` remains pending and must not be shown
as green.
