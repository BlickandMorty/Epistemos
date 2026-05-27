# PageGather Locality Probe - 2026-05-27

Status: diagnostic mitigation evidence landed; no product green promotion.

Branch: `codex/pagegather-locality-probe-2026-05-27`

## Canonical Read Order

1. `docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md`
2. `docs/audits/PAGEGATHER_METAL_FAILURE_2026_05_27.md`
3. `docs/falsifiers/F-PageGather-M2Pro_2026_05_17.md`
4. `Tools/metal-witness-gates/page-gather-metal-artifact.swift`
5. `Epistemos/Shaders/PageGather.metal`

## What This Slice Does

The prior Metal witness proved the current PageGather shader is correct but too
slow for the canonical product gate. This slice keeps that failure intact and
adds a locality probe to the same harness:

- `--probe-locality`
- `--locality-window-elements`
- `--locality-block-elements`

The probe writes a separate diagnostic artifact:

`artifacts/falsifiers/page_gather/locality_probe_result.json`

It never writes over `result.json`, and it never rewrites the primary failure
report at `artifacts/falsifiers/page_gather/metal_failure_result.json`.

## Measurement

The full diagnostic run used:

```text
swift Tools/metal-witness-gates/page-gather-metal-artifact.swift --probe-locality --working-sets-mb 256 --window-seconds 5 --trials 3 --warmup-iterations 3 --write-artifact
```

Result: **diagnostic failure report**, because the canonical primary axes still
fail. The locality candidate itself is promising:

| Axis | Median | Ratio vs STREAM | Correctness | Stability |
|---|---:|---:|---:|---:|
| STREAM triad | 228.64 GB/s | 1.00x | n/a | n/a |
| Sequential gather | 171.71 GB/s | 0.751x | 0 violations | n/a |
| Full random scatter | 15.13 GB/s | 0.066x | 0 violations | 0.009 |
| Local-window scatter | 246.90 GB/s | 1.080x | 0 violations | 0.043 |
| Block-sorted scatter | 167.80 GB/s | 0.734x | 0 violations | 0.018 |

Probe parameters:

- Local window: `65,536` elements.
- Block-sorted window: `8,192` elements per block.
- Working set: `256 MB`.
- Window: `5 s`.
- Trials: `3`.

## Interpretation

The failure stressor remains real: full-coverage random scatter is only about
`0.066x` measured STREAM and is not product-green.

The mitigation evidence is also real: locality-aware scheduling can make the
same shader clear the scatter ratio at 256 MB without correctness violations.
In particular, the block-sorted candidate preserves full source coverage while
changing traversal order, reaching about `0.734x` measured STREAM.

This is not enough to promote `F-PageGather-M2Pro`, because:

- The canonical gate requires `256/512/1024 MB`, not only `256 MB`.
- Sequential gather is still below its `0.95x` bar.
- Thermal second-run and full reproducibility evidence still need the canonical
  pass run.
- No product scheduler has been changed to emit block-sorted work packets yet.

## No-Orphan Check

- Motion: Project / Verify.
- UAS: no new address shape; the probe measures the existing page-retrieval
  path and records an additional artifact.
- Plane: retrieval / page plane.
- Residency: Apple Silicon UMA via shared Metal buffers.
- WBO/error: locality ratios are recorded separately from the primary witness;
  no failed primary axis is hidden.
- Witness: locality artifact, harness CLI, falsifier doc, and this audit note.
- Falsifier: `F-PageGather-M2Pro`.
- Tier: Research / VerifiedFloor diagnostic; product UI remains orange/pending.
- Rollback: remove the locality CLI options and
  `artifacts/falsifiers/page_gather/locality_probe_result.json`.

## Next Slice

Build the real mitigation, not another label:

1. Add a scheduler-side block-sorted PageGather packet path.
2. Keep the full random permutation as a failure stressor.
3. Rerun the canonical `256/512/1024 MB`, `5 s`, `3 trial` gate.
4. Promote only if both gather and locality-aware scatter pass their thresholds
   at all three sizes.
