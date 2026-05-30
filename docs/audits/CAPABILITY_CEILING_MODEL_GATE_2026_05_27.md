---
state: audit
created_on: 2026-05-27
scope: dense 36B gate vs. ACS/UAS 70B Capability Ceiling
posture: no-compromise intent preserved; shipped gate hardened
---

# Capability Ceiling Model Gate - 2026-05-27

## Decision

Power-user mode must not lower the dense MLX 36B primary-agent memory gate on
16 GB Macs. The 70B / mixture-of-model-brains ambition remains canonical, but
it belongs to the ACS/UAS addressable-substrate route, not the current dense
MLX route.

## Why this is not a retreat

The user's target is:

> SSD/RAM unified address space + ACS + PageGather + KV-Direct + active
> assembly + ternary/Sherry lattice compression + EML/Geometry/Scan IR, so a
> 70B-class or multi-brain model can live cold on SSD while the active assembly
> behaves like a much smaller resident model.

That is still the northstar. The guard here prevents a weaker thing from
wearing the stronger thing's name. A dense 36B MLX model behind a 16 GB toggle is
not proof that the SSD/RAM cocktail works.

## Current truth

| Route | Current status | Gate |
|---|---|---|
| Dense MLX Qwen 3 8B fallback | Live | 16 GB floor |
| Dense MLX LocalAgent 4.3 36B | Opt-in | 32 GB host RAM |
| Power-user mode | Live posture | preserves research controls; does not lower dense gate |
| ACS/UAS 70B cocktail | Canonical target | `F-70B-Local-Cocktail` / `F-70B-Local-Cocktail-Lite` |

## Required unlock path

The 16 GB / 70B-class path reopens only through a separate substrate route that
passes local artifacts:

- `F-KV-Direct-Gate` for SSD-backed KV/residual parity
- `F-UAS-CopyCount` for zero hidden tensor copies
- `F-PageGather-M2Pro` caller-path packet consumption and dense restore fix
- `F-ActiveAssembly-Minimal` for useful active-support selection
- `F-Sparse-Runtime-Split` for bounded drift vs. dense/reference execution
- `F-70B-Local-Cocktail` or `F-70B-Local-Cocktail-Lite` for composed RAM,
  throughput, quality, and bottleneck evidence

## EML-everything clarification

"EML is everything" is preserved as an IR discipline:

- every eligible elementary transform should lower to EML-IR;
- model weights/layers should expose an EML, Geometry-IR, Scan-IR, or Operator
  chart when possible;
- opaque objects are only acceptable when they still carry UAS address,
  residency tier, WBO budget, and witness;
- the app should move toward weights, kernels, and layer transforms being
  proof-addressable substrate objects instead of opaque blobs.

This keeps the no-compromise route comprehensive without claiming every current
model byte is already an EML tree.

## Code consequence

`LocalModelCatalog.primaryAgentModelMinHostRAMGB_powerUser` intentionally
matches the dense 32 GB gate. Settings copy now says power-user mode preserves
Capability Ceiling / 70B research controls but does not lower the 36B memory
gate until the SSD/RAM composition falsifier passes.

## 70B preflight row-root

`tools/falsifiers/f_70b_local_cocktail_lite.sh` now emits a schema-valid red
preflight artifact at
`artifacts/falsifiers/70b_local_cocktail_lite/result.json`. This is not a
working 70B claim. It is the first real row-root for the Capability Ceiling
work, so future ACS/UAS, KV-Direct, PageGather, active-assembly, and sparse
runtime work can flip named axes from failed sentinel values to measured passes
without ever lowering the dense MLX memory gate.

The preflight includes an `eml_geometry_scan_chart_coverage_available` axis.
That keeps the "EML is everything" route concrete: a 70B candidate is not just a
large file to page from SSD; it eventually has to expose proof-addressable
EML/Geometry/Scan/Operator charts for the active weights, layers, KV pages, and
kernels, or remain an explicitly opaque red-axis object.
