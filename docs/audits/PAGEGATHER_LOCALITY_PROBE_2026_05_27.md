# PageGather Locality Probe - 2026-05-27

Status: diagnostic mitigation evidence landed; scheduler, Metal
dense destination-position, and packetized scheduled contracts now exist; no
product green promotion.

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

The latest diagnostic artifact uses the 256/512 MB M2 Pro envelope:

```text
swift Tools/metal-witness-gates/page-gather-metal-artifact.swift --probe-locality --working-sets-mb 256,512 --window-seconds 2 --trials 2 --warmup-iterations 1 --write-artifact
```

Result: **diagnostic failure report**, because the canonical dense primary axes
still fail. The packetized scheduled candidate is the current promising lead:

| Axis | 256 MB ratio | 512 MB ratio | Correctness |
|---|---:|---:|---:|
| Sequential gather | `0.704x` | `0.725x` | `0` sampled violations |
| Full random scatter | `0.069x` | `0.043x` | `0` sampled violations |
| Local-window scatter | `1.001x` | `1.038x` | `0` sampled violations |
| Dense block-sorted scheduled restore | `0.092x` | `0.058x` | `0` sampled violations |
| Packetized scheduled PageGather | `0.729x` | `0.752x` | `0` sampled violations |

Probe parameters:

- Local window: `65,536` elements.
- Block-sorted window: `8,192` elements per block.
- Working sets: `256 MB`, `512 MB`.
- Window: `2 s`.
- Trials: `2`.

## Interpretation

The failure stressor remains real: full-coverage random scatter is only about
`0.066x` measured STREAM and is not product-green.

The mitigation evidence is also real: packetized scheduled PageGather can clear
the `0.70x` floor at both M2 Pro envelope sizes without correctness violations.
It does this by preserving the logical-position witness coordinate in a compact
packet stream instead of paying random dense destination writes immediately.

This is not enough to promote `F-PageGather-M2Pro`, because:

- The canonical dense gate still requires dense output semantics; packetized
  output needs a caller-path consumption witness before it can replace dense
  restore.
- Sequential gather is still below its `0.95x` bar.
- Dense scheduled restore is correct but far below threshold at 256/512 MB.
- Thermal second-run and full reproducibility evidence still need the canonical
  pass run.
- No product caller has been changed to consume packetized work packets yet.

The follow-up scheduler slice is now recorded in
`docs/audits/PAGEGATHER_BLOCK_SORTED_SCHEDULER_2026_05_27.md`: Rust can build a
block-sorted execution plan and restore logical output order, and vault traces
surface the schedule as deferred evidence. The Metal-side output-position
contract now exists in
`docs/audits/PAGEGATHER_METAL_DESTINATION_CONTRACT_2026_05_27.md`; the
canonical pass run and optimization work remain open.

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

1. Optimize the Metal-side destination-position contract for the block-sorted
   schedule.
2. Keep the full random permutation as a failure stressor.
3. Add a caller-path witness that consumes `(logical_position, value)` packets
   without dense restore, or optimize dense restore and rerun it.
4. Promote only if the chosen product contract and its caller path pass their
   thresholds without hiding the dense-restore cost.
