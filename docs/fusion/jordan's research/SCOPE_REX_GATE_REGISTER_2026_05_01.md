# SCOPE-Rex Gate Register — What Can Ship, What Must Wait

Date: 2026-05-01

## Ship / build now

| Item | Gate | Why |
|---|---|---|
| Residency Governor | V1.5 design + tests | Pure Rust logic, no model risk |
| Semantic ledger | V1.5 | Extends existing provenance spine |
| Claim extraction schema | V1.5 | Can start as structured output + validation |
| Verified Research Mode | V1.5 vertical slice | Proves the SCOPE-Rex thesis without weight mutation |
| Training-Free GRPO experience library | V1.5/Pro | Context/harness layer; reversible |
| Harness versioning | V1.5/Pro | Trace-based improvement, no model surgery |
| Feature fingerprint store | Pro/R&D | Can store telemetry before doing live steering |
| Qwen-Scope offline analysis | Pro/R&D | Useful, but model-specific and research-heavy |

## Build later / behind Pro flags

| Item | Gate | Why |
|---|---|---|
| PSOFT adapter lab | Pro R&D | Single-task adapter, training cost, validation required |
| OSFT consolidation | Pro R&D | Continual learning, no quant support, SVD overhead |
| coSO FD sketch | Pro R&D | Vision-validated, LLM-agent validation needed |
| DSC adapter composer | Pro R&D | promising but must be benchmarked |
| HCache/KVCrush state restoration | Pro R&D | needs MLX/Core ML integration proof |
| Brain Time Machine | V1.5 semantic first, Pro tensor later | semantic replay first; raw hidden/KV later |

## Do not build into Core/MAS

| Item | Reason |
|---|---|
| private `_ANEClient` / `_ANECompiler` APIs | App Store and stability risk |
| hot-path Python | violates native/hot-path doctrine |
| raw arbitrary subprocesses | Pro-only capability tunnel |
| direct weight mutation during user interactions | unstable and unsafe |
| activation steering as product claim | research-only until verified |
| sparse texture KV tree as product claim | research-only |
| infinite memory / zero forgetting language | false or unsupported |

## Updated claim language

Use:

> deterministic state governance
> witnessed local intelligence
> semantic Brain Time Machine
> capability residency
> verified research substrate
> local-first user-specific reasoning

Do not use:

> deterministic AGI
> infinite context
> zero forgetting
> guaranteed convergence
> full direct ANE control
> local beats cloud on everything

## First acceptable SCOPE-Rex milestone

A passing milestone is:

```text
Rust semantic kernel compiles.
Residency Governor unit tests pass.
Claim schema exists.
Verified Research Mode produces labeled outputs.
Ledger commits a SemanticDelta.
No model training is required.
No existing release path is broken.
```
