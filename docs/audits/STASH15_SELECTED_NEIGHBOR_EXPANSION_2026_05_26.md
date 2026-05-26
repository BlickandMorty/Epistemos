# Stash 15 Selected Neighbor Expansion Recovery - 2026-05-26

Status: recovered as a focused graph behavior slice from `stash@{15}`.

Source: `stash@{15}` (`wip-codex-graph-filters-selected-expansion`).

Recovery rule: no stash was popped, dropped, checked out, or bulk-applied. The
stash was inspected as a patch and only the still-novel selected-neighbor
physics behavior was ported.

## What Was Already On Main

The Swift filter UI portion of the stash was already represented on current
`main`:

- `GraphForceSettings` has the `Filters` section.
- `GraphState.hideAllUserFilterableNodeTypes()` exists.
- `FilterEngineTests` and `GraphPhysicsSettingsAuditTests` guard the user
  filterable-node controls.

Those files were not replayed from the stash.

## What Was Recovered

Selecting a graph node now expands the rest distance of direct selected-neighbor
links. This gives the selected node and its immediate neighborhood readable
space without changing global charge, center gravity, collision, or default
boot physics.

Performance guard:

- The normal no-selection path still calls the original `force_link` hot
  function.
- Focused link distance only runs while selection focus is active.
- Focus state is a reused boolean vector in `Simulation`; it is not allocated
  per tick.
- The only event-time allocation is mapping highlighted graph IDs to simulation
  indices when selection changes.

## Verification

- Baseline graph-engine suite passed before recovery.
- Focused tests passed:
  - `focused_link_extends_selected_neighbor_distance`
  - `select_node_syncs_selection_and_neighborhood_focus`
- Recursive Physics Audit completed three consecutive full graph-engine passes
  without code changes between passes.

## Snappy Defaults Preserved

This recovery does not alter:

- Gravity Well boot default
- `linkDistance = 500`
- `centerStrength = 0`
- fluid field off by default
- graph filter UI already present on main
