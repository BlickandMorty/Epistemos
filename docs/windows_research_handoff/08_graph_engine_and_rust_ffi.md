# Graph Engine And Rust FFI

## Real Source Files

- [GraphState.swift](/Users/jojo/Epistemos/Epistemos/Graph/GraphState.swift)
- [GraphStore.swift](/Users/jojo/Epistemos/Epistemos/Graph/GraphStore.swift)
- [lib.rs](/Users/jojo/Epistemos/graph-engine/src/lib.rs)

## Current Shape

The graph side is already a native frontend plus Rust-engine architecture.

`GraphState.swift`:

- owns graph mode and graph UI coordination
- bridges app state to the engine
- keeps mutation serialized on the main actor where needed

`GraphStore.swift`:

- keeps compact in-memory graph storage
- uses integer-indexed adjacency internally
- exposes a stable public API
- maintains a trigram index for search

`lib.rs`:

- defines the Rust FFI surface
- uses `#[repr(C)]` structs
- null-guards FFI entry points
- owns memory allocation conventions at the Rust boundary
- contains graph/search/renderer/simulation/retrieval modules

## Critical Pattern

The public app API stays ergonomic while internal storage stays compact.

That means:

- do not expose performance hacks as UI-facing complexity
- do not let the frontend own heavy graph data structures if Rust should own them

## Windows Research Requirement

Research the best Windows-native rendering and interop strategy for this graph:

- Rust core stays Rust
- frontend remains native
- incremental graph updates are cheap
- rendering avoids unnecessary copies
- interaction latency stays low

## Questions To Answer

- Best rendering surface on Windows for a Rust-driven graph?
- Direct3D 12, DirectComposition, Win2D, or another route?
- Best way to stream graph deltas and query results from Rust?
- When should shared-memory transport be used versus regular FFI structs?
- Best way to keep hover/selection updates cheap?

## FFI Rules To Preserve

- explicit ownership
- `#[repr(C)]` types
- no hidden string lifetime traps
- no freeing Rust memory from the frontend
- no giant copy-heavy serialization in hot paths
