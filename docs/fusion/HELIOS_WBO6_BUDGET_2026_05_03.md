# HELIOS WBO-6 Budget - Canonical Epistemos Re-Derivation

> Created 2026-05-03 during fusion verification floor STEP 2.
> Source reference: `/Users/jojo/Downloads/GPT research/docs/WBO6_INEQUALITY.md`.
> Authority note: GPT research is a reference brief, not canon. This document
> re-derives the useful WBO-6 accounting surface against current Epistemos code.

## Purpose

WBO-6 is a budget ledger for hot-path model drift, memory pressure, and
verification overhead. It is not yet a proven theorem inside Epistemos. The
canonical use today is narrower and safer: every new substrate or inference
slice must name which budget term it consumes, what current file owns that
term, and what test or verifier keeps the term from silently drifting.
This file owns the `F-WBO-DriftLedger` falsifier hook used by lattice/WBO
register rows that must prove they paid the drift ledger.

The reference note says the measured logit drift bound is half the sum of six
terms. In canonical Epistemos shape, those terms become:

| Term | Canonical meaning | Current code anchor | Verification anchor |
|---|---|---|---|
| `T_W` | Weight/runtime perturbation budget | `Epistemos/Engine/KIVIQuantization.swift`, `Epistemos/Engine/MLXInferenceService.swift` | `EpistemosTests/KIVIKVCacheRuntimeTests.swift` arithmetic tolerance |
| `T_K` | KV/cache compression and restore budget | `Epistemos/Vault/SSMStateService.swift` | `KIVIKVCacheRuntimeTests.roundTripsPromptCacheSerialization` |
| `T_R` | Resonance signature budget | `agent_core/src/resonance/{tau,pi,lambda,mod}.rs`, `Epistemos/Engine/ResonanceService.swift` | `agent_core/tests/resonance_seed.rs`, `EpistemosTests/ResonanceServiceTests.swift` |
| `T_Q` | Quantization approximation budget | `Epistemos/Engine/KIVIQuantization.swift` | `KIVIKVCacheRuntimeTests.attentionStaysWithinDeterministicToleranceAfterGroupedFlush` |
| `T_S` | Substrate/side-effect boundary budget | `Epistemos/LocalAgent/HermesGatewayPolicy.swift`, `Epistemos/LocalAgent/HermesCapabilityRegistry.swift` | `CoreMASBoundarySourceGuardTests`, `ToolSurfaceBehavioralMatrixTests`, `scripts/verify_hotpath.py` |
| `T_SE` | Sovereign/security enforcement budget | `Epistemos/Sovereign/SovereignGate.swift` | Sovereign source-owner grep in `scripts/verify_hotpath.py` |

## Canonical Inequality Shape

The working acceptance form is:

```text
measured_drift <= 0.5 * (T_W + T_K + T_R + T_Q + T_S + T_SE)
```

This must not be presented as a shipped scientific proof until a future
benchmark slice records real model logits and per-token KL. Today it is an
engineering budget contract that prevents slices from hand-waving drift.

## Hot-Path Rules

- `T_R` Core work is CPU-only τ + π + λ. It must stay O(1), allocation-light,
  and free of Z3/Kani/Lean/Kissat/cvc5 calls on the display or token path.
- `T_K` and `T_Q` may use MLX/KIVI harnesses, but live token-throughput remains
  blocked until memory preflight is sufficient.
- `T_S` keeps Hermes unified without making Hermes authoritative. Cloud, CLI,
  MCP, browser/computer-use, Docker, and external side effects are Pro/Research
  gateway surfaces returning structured evidence, not graph authority.
- `T_SE` has one owner for LocalAuthentication: `Epistemos/Sovereign/`.
- UI animation is never proof. A visible Resonance chip, Halo, or Simulation
  character must be backed by AgentEvent, tests, or verifier output.

## Current Status

Closed today:

- τ + π + λ Rust seed exists under `agent_core/src/resonance/`.
- Swift mirror exists at `Epistemos/Engine/ResonanceService.swift`.
- Hermes gateway policy and capability registry are typed and Core/MAS guarded.
- KIVI prompt-cache runtime tests exist with deterministic arithmetic tolerance.
- `scripts/verify_hotpath.py` now checks the canonical owners above.

Open proof obligations:

- Real WBO-6 per-token KL measurement is not yet run.
- KV-Direct Week 0 gate remains an experiment, not a shipped runtime mode.
- `agent_core/metal/` does not exist in the current canonical tree. Metal shader
  authority currently lives under `Epistemos/Shaders/`.

## Build Consequence

Every future inference, Resonance, Hermes, Sovereign, KV, or Metal slice should
include a one-line budget declaration:

```text
Budget: WBO-6 term=<T_W|T_K|T_R|T_Q|T_S|T_SE> | owner=<path> | verifier=<test/script>
```

Slices that cannot name a term are probably UI-only or out of scope for this
ledger. Slices that name multiple terms need a deliberation brief before code.
