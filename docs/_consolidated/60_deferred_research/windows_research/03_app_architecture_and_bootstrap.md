# App Architecture And Bootstrap

> **Index status**: DEFERRED-RESEARCH — Windows porting research; deferred (V1 = macOS-only per ambient_V1_DECISION.md).
> Classified in [`docs/_INDEX.md §14`](_INDEX.md). Copy in `docs/_consolidated/60_deferred_research/windows_research/`.



## Real Source Files

- [AppEnvironment.swift](/Users/jojo/Epistemos/Epistemos/App/AppEnvironment.swift)
- [AppBootstrap.swift](/Users/jojo/Epistemos/Epistemos/App/AppBootstrap.swift)
- [ChatCoordinator.swift](/Users/jojo/Epistemos/Epistemos/App/ChatCoordinator.swift)

## Core Pattern

The app is built around a centralized bootstrap object that creates:

- state objects
- services
- coordinators
- the dependency graph

Behavioral orchestration is not scattered randomly across views.

## Injection Pattern

`AppEnvironment.swift` exposes a single `withAppEnvironment(_:)` extension that injects all shared state and services from `AppBootstrap`.

The rule is:

- one source of truth for environment wiring
- no duplicated environment chains
- no per-window drift

Research should preserve that idea on Windows:

- a single composition root
- centralized dependency construction
- per-window native views consuming shared app state without hand-wired duplication

## Bootstrap Pattern

`AppBootstrap.swift` does the heavy setup:

- model container
- local model manager
- hardware snapshot
- local inference service
- prepared model registry
- local LLM client
- triage service
- vault sync
- note insight service
- pipeline service
- coordinators
- graph loading

The frontend does not own this logic.

## Windows Port Requirement

Research a Windows equivalent with:

- one composition root for shared state/services
- deterministic ordering of startup wiring
- background graph/vault initialization
- UI-safe startup that avoids a big launch stall

## Coding Style To Preserve

- direct control flow
- no wrapper around wrapper around wrapper
- services created once, then injected
- background work off the main UI path
- state changes serialized where required

## Architectural Question For Research

What is the best Windows-native equivalent to this structure if the frontend is written in Swift 6, but some host glue may still need to be Windows-native?

Research should specify:

- how the root dependency container is built
- how windows attach to shared app state
- how background services are started and torn down
- how per-window resources are scoped
