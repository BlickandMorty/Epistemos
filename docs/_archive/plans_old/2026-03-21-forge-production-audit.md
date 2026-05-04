# 2026-03-21 Forge Production Audit

> **Index status**: SUPERSEDED-HISTORICAL — Older plan tree predecessor of `docs/plan/`; superseded by MASTER_FUSION.md + V1_5_IMPLEMENTATION_TRACKER.md.
> Classified in [`docs/_INDEX.md §14`](_INDEX.md).



## Goal

Run a deep dead-code and redundancy cleanup against the current `main` branch, using commit `0981039` as the pre-model-addition reference point.

## Constraints

- Keep `main` as the live branch
- Do not regress the current validated local Qwen-only architecture
- Do not remove code that is dynamically used without proving it is dead
- Every cleanup slice must keep the app building and focused tests passing

## Baseline

- Current head: `6c6d5cf` `Close Phase 4.5 stabilization pass`
- Reference commit: `0981039` `Checkpoint shell cleanup before AI stack rollout`

## Audit Tasks

1. Branch and history cleanup
   - keep `main`
   - keep explicit checkpoint branches only

2. Dead-code scan
   - `rg`/`git grep` unused or stale AI/retrieval symbols
   - stale imports, unused helpers, obsolete scripts, inactive config paths
   - orphaned tests and mocks

3. Redundancy scan
   - duplicate logic introduced during the AI stack rollout
   - overlapping runtime/readiness helpers
   - stale copy or settings surfaces no longer reachable

4. Cleanup slices
   - remove verified dead code only
   - run focused validation after each slice

5. Final validation
   - Rust retrieval tests
   - macOS build
   - focused Swift test suites
   - `git diff --stat 0981039..HEAD` comparison

## Current Focus

- Detect and remove dead code left behind by the model-stack transition
- Keep the retrieval/runtime work honest while shrinking unused surfaces
