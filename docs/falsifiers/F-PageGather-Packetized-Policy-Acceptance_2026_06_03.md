---
falsifier: F-PageGather-Packetized-Policy-Acceptance
created_on: 2026-06-03
hardware_floor: M2 Pro 16 GB UMA
status: PASS - FALLBACK WITNESS
artifact: artifacts/falsifiers/page_gather_packetized_policy_acceptance/result.json
---

# F-PageGather-Packetized-Policy-Acceptance

## Purpose

This is the executable policy witness for Capability Ceiling queue row 5:
PageGather is acceptable for the current retrieval and witness route when the
packetized floor and caller witness pass, while dense PageGather remains a
separate red primary gate.

## Command

```bash
Tools/falsifiers/f_page_gather_packetized_policy_acceptance.sh
```

## Artifact

- `artifact_kind`: `fallback_witness`
- `fallback_tier`: `Fallback`
- path: `artifacts/falsifiers/page_gather_packetized_policy_acceptance/result.json`

The artifact reads:

- `artifacts/falsifiers/page_gather/locality_probe_result.json`
- `artifacts/falsifiers/page_gather_packetized_caller/result.json`

It passes only when the packetized scheduled floor is present, both 256 MB and
512 MB scheduled ratios are at least `0.70x`, sampled correctness violations
are zero, the caller consumes packets, dense restore is deferred, and the
policy is scoped to retrieval/witness packet surfaces.

## Non-Promotion Rule

This falsifier does not green `F-PageGather-M2Pro`. Its rollback axis requires
dense primary to remain red, and the route kernel may use it only as the
accepted packetized policy half of "dense primary or accepted packet policy."

## Queue Effect

When this artifact validates, the Capability Ceiling Evaluation Kernel may mark
`page_gather_packetized_policy_acceptance_pass=true` and close the row
`pagegather_dense_primary_or_packet_policy` without pretending the dense
restore path passed. The next bottleneck then returns to the canonical
Qwen3-8B MLX 128K context asset issue.
