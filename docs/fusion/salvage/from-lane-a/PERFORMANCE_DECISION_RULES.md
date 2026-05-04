# Performance Decision Rules

## Purpose

Use the simplest architecture that wins on measured user-visible latency.

## When to Choose Plain FFI

Choose plain FFI when:
- payloads are tiny
- calls are command-style or scalar lookups
- ownership is simple
- call frequency is high but data volume is low

Examples:
- graph camera/highlight/control calls
- node drift or hover lookups

## When to Choose Batched FFI

Choose batched FFI when:
- the boundary is hot
- data is medium-sized
- the current problem is many tiny crossings, not transport bandwidth itself

Examples:
- BTK row accessors
- typed result arrays instead of per-row callback churn

## When to Choose Zero-Copy Shared Memory

Choose shared memory only when all are true:
- crossing frequency is high
- payload size is large enough for copy tax to matter
- transport is on the production hot path
- lifetime/ownership can be made explicit and safe
- measured wins justify the added complexity

Do not choose it merely because it is elegant or advanced.

## When to Choose Memory-Mapped File Access

Choose mapped file access when:
- the workload scans many note files in bulk
- the data is cold or background-read heavy
- the code only needs bytes, hashes, snippets, or one short-lived decode

Do not choose it for long-lived editor state that will immediately become an owned string anyway.

## When to Choose Direct Swift-Native Implementation

Choose Swift-native when:
- the operation is UI-adjacent
- the data already lives in SwiftData/AppKit/SwiftUI land
- the bridge would add copies or ownership complexity
- platform APIs already solve the problem efficiently

Examples:
- GRDB/FTS5 text search integration
- editor/UI coordination

## When to Choose Direct Rust-Native Implementation

Choose Rust-native when:
- the work is CPU-heavy or data-structure heavy
- it benefits from compact memory layout or SIMD
- the output can stay compact across the boundary

Examples:
- physics/render graph engine
- staged typed watcher diffs

## When to Choose Reactive Incremental Invalidation

Choose incremental invalidation when:
- the same query/view updates often
- mutations are localized
- the cost of rerunning everything is user-visible

Examples:
- graph/search subscriptions
- note-derived projections that update frequently

## When Full Recomputation Is Acceptable

Choose full recomputation when:
- the path is cold
- the state size is small
- correctness simplicity beats incremental complexity
- the operation is background-only

Examples:
- one-off rebuilds
- rare migrations

## Actor Isolation vs Lock-Free Structures

Choose actor isolation when:
- state is Swift-owned
- correctness and maintainability matter more than a few microseconds
- update frequency is moderate

Choose lock-free/shared-memory only when:
- a truly hot producer-consumer boundary exists
- actor hops or allocation churn are already proven bottlenecks

## Custom Stack vs Existing Library

Choose the existing library when:
- it already fits the problem and performance envelope
- replacing it would mostly add migration cost

Replace it only when:
- the current library is a measured bottleneck
- the new design is simpler for the hot path, not just more impressive

## Final Rule

If a proposed optimization does not produce a clear user-visible win, clearer ownership, or simpler hot-path behavior, do not build it.
