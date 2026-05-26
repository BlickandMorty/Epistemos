# Stash 15 Graph Closeout - 2026-05-26

Status: closed for current product graph recovery; preserved as a historical
graph/performance donor reference.

Source: `stash@{15}` (`wip-codex-graph-filters-selected-expansion`).

Recovery rule: this slice was inspected without popping, dropping, checking out,
or bulk-applying the stash. The raw stash tree is stale and is not safe to
restore onto current `main`.

## Decision

Do not raw-apply `stash@{15}`. It contains useful selected-neighborhood graph
ideas mixed into an older graph-engine tree. Comparing the stash against current
`main` shows the old tree would remove newer graph modules, tests, and UI
surfaces that are already part of the snappy graph/editor checkpoint.

The current product recovery is complete because:

1. The Swift graph filter UI is already present on `main`.
2. The durable Rust behavior was recovered as selected-neighbor link rest-distance
   expansion in `docs/audits/STASH15_SELECTED_NEIGHBOR_EXPANSION_2026_05_26.md`.
3. The recovered behavior keeps normal no-selection link physics on the original
   hot path.
4. The prior recovery recorded a three-pass graph physics audit.

## Preserved Performance Guardrails

- Gravity Well remains the canonical resting preset.
- `linkDistance = 500` remains the restored default.
- `centerStrength = 0` remains the restored default.
- Fluid dynamics remain off by default.
- Selected-neighborhood expansion is gated to active selection focus.
- No per-frame stash donor UI is restored.
- No stale graph-engine files are removed.

## What Remains

No current product graph recovery remains for `stash@{15}`.

Future graph work should start from current `main`, not from the stash. If a
future agent wants more of the old visual idea, it must write a new focused
proposal and pass the graph performance gate before code changes.
