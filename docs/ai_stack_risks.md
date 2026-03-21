# AI Stack Risks

## 1. Retrieval runtime still incomplete

Severity: critical

Why it matters:

- Phase 5 cannot land on top of a fake retrieval runtime
- Swift fallback embeddings are not the target architecture

## 2. Local runtime hardening still partial

Severity: high

Why it matters:

- the remaining local Qwen lane still needs stronger readiness and residency behavior
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

Do not start Phase 5 until:

1. retrieval runtime closure is real
2. runtime/model selection is honest
3. the remaining local text lane is operationally stable
4. docs, manifests, and tests all match the live architecture
