# Compute Steering Spec v1

## Purpose

Compute Steering is the policy-driven selection of auxiliary modules, masks, expert budgets, and execution budgets under explicit telemetry.

It exists to unify:

- KAN helper modules
- retrieval/reranking helpers
- structured masking
- expert budgeting
- KV policy
- sidecar activation
- future overseer hints

without polluting the base runtime contract with raw research-specific schemas.

## Inputs

- `compute_profile`
- `compute_budget`
- runtime capability flags
- context requirements
- optional overseer hints

## Compute profiles

- `standard`
- `deep_graph`
- `adaptive`
- `experimental`
- `visual_sidecar`

## Compute budget

Fields:

- `max_wall_ms?`
- `max_tokens?`
- `max_io_bytes?`
- `max_adapt_steps?`
- `max_aux_calls?`

## Internal Rust output

Rust resolves an `ExecutionGraph` or `ExecutionPlan` with nodes such as:

- `retrieve_context`
- `graph_score`
- `rerank_context`
- `compress_history`
- `select_mask`
- `generate_main`
- `adapt_helper`
- `image_sidecar`

## Hard rules

- unsupported nodes must be rejected before execution
- serial I/O invariant must hold in streamed/fallback GGUF paths
- dense fallback must exist for invalid mask plans
- no unapproved sidecar or adaptation work
- compute steering must always be visible in telemetry

## Structured mask rules

- structured masks only
- compiler/kernels must support them
- unexecutable masks fail closed
- masking state must be logged

## Expert budget rules

Expose expert budget classes:

- `default`
- `constrained`
- `deep`

No hidden expert inflation.

## KV policy

KV policy should remain abstract and resolved by Rust:

- `baseline`
- `compressed`
- `blocked`

## Telemetry requirements

Every execution must surface:

- compute profile
- execution policy ref
- masking state
- expert budget state
- KV policy state
- sidecar state
- budget outcome