# AI Stack Risks

> **Index status**: CANONICAL-OPERATIONAL — AI stack risk register; companion docs.
> Classified in [`docs/_INDEX.md §14`](_INDEX.md). Copy in `docs/_consolidated/30_canonical_operational/`.



## 1. Future retrieval overreach

Severity: critical

Why it matters:

- later phases could overclaim native Rust ML support before the dependency/runtime story is justified
- Swift-owned query embeddings are an intentional boundary, not a bug to paper over

## 2. Single-lane local runtime pressure

Severity: high

Why it matters:

- the remaining local Qwen lane still needs continued readiness and residency discipline
- an 18 GB target has little room for sloppy load/unload policy

## 3. Streaming smoothness can still regress

Severity: high

Why it matters:

- local generation is one of the heaviest visible app paths
- any per-token UI churn will show up immediately as hitching

## 4. Manifest/runtime drift

Severity: medium-high

Why it matters:

- stale manifest claims were a major source of earlier routing confusion
- model registry truth must match real runtime behavior

## 5. Experimental scope creep

Severity: medium

Why it matters:

- MoE and advanced orchestration are still tempting distractions
- retrieval/runtime closure is the real blocker

## Rollout Gate

Phase 4.5 satisfied this gate before Phase 5 started:

1. retrieval runtime closure is real
2. runtime/model selection is honest
3. the remaining local text lane is operationally stable
4. docs, manifests, and tests all match the live architecture

Current rule:

- do not reintroduce removed prepared roles or hidden extra local lanes without a new explicit phase and audit
