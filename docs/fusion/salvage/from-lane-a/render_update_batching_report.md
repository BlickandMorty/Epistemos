# Render Update Batching Report

## Staged bridge

- one polling task
- default interval: 16 ms
- batch apply: yes

## Live query UI

- not frame-batched
- notification debounced, then fully reevaluated on main actor

## Verdict

The staged path has a batching shape compatible with frame cadence. The live query path does not.
