# Performance Rules And Antipatterns

> **Index status**: DEFERRED-RESEARCH — Windows porting research; deferred (V1 = macOS-only per ambient_V1_DECISION.md).
> Classified in [`docs/_INDEX.md §14`](_INDEX.md). Copy in `docs/_consolidated/60_deferred_research/windows_research/`.



## Primary Source

- [AGENTS.md](/Users/jojo/Epistemos/AGENTS.md)

## High-Level Rules

- zero copy-paste when shared code should exist
- shortest path from intent to execution
- performance is architecture
- minimal fixes
- test-first
- read before writing
- no speculative abstractions

## Concrete App Patterns

- pre-allocate in hot paths
- debounce state sync around editor and streaming surfaces
- avoid per-frame allocations
- keep render loops free of unnecessary clones
- avoid framework feedback loops
- keep environment injection centralized
- prefer background initialization for heavy subsystems

## Known Antipatterns Already Learned The Hard Way

### Binding Cascade

Reactive sync from native editor to app state can trigger expensive refetch and layout loops.

### Zone Protection Gap

Streaming AI edits inside the note editor need explicit protected zones, not optimistic assumptions.

### Multi-Turn Double Insertion

Streaming state must understand turn boundaries, not just append raw text.

### Environment Drift

Duplicated dependency injection per window causes runtime skew.

### Unpersisted Dirty Flags

In-memory change flags are not enough when query layers depend on persisted state.

## Windows Research Requirement

The Windows port must explicitly preserve these rules:

- no per-keystroke full-surface rebuilds
- no main-thread model work
- no fake async built on blocking UI calls
- no giant document reflow on resize
- no redundant serialization between frontend and Rust
- no hot-path allocations hidden inside convenience layers

## Required Research Output

For each proposed Windows architecture decision, research should state:

- why it is fast
- what it avoids
- where it can still fail
- how it should be measured
- what regression signals to track
