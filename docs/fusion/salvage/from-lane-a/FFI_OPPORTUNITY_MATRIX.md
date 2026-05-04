# FFI Opportunity Matrix

## Summary

The app has multiple Rust/Swift bridges, but they are not equal.

- Some are tiny control calls and should stay plain FFI.
- Some are clearly hot and should be tuned or batched.
- Some already have a staged zero-copy answer (`knowledge-core`) but are not on the production path yet.

## Matrix

| Boundary | Files | Data Crossing | Frequency | Payload | Hidden Copies / Serialization | Hot? | Best Recommendation |
|---|---|---|---|---|---|---|---|
| Graph control/render commands | `Epistemos/Graph/GraphEngine.swift`, `Epistemos/Views/Graph/MetalGraphView.swift`, `Epistemos/Graph/GraphState.swift` | node IDs, toggles, camera/search/highlight commands | very high | tiny | `withCString` only | yes | `KEEP` |
| Rust graph label search | `Epistemos/Graph/GraphEngine.swift`, `graph-engine/src/lib.rs` | result rows with UUID, label, score | user typing | small | C strings become Swift `String`s | warm but modest | `KEEP` |
| BTK subscription payloads | `Epistemos/Graph/GraphEngine.swift`, `graph-engine/src/block_kernel/query_kernel.rs` | archived diff payloads | potentially high | medium | `Data(bytesNoCopy:)` is zero-copy only for raw buffer; rows and strings are materialized into Swift structs | yes | `BATCH` |
| BTK property/depth one-shot queries | `Epistemos/Engine/QueryRuntime.swift`, `graph-engine/src/lib.rs` | newline-separated page IDs | moderate | small-medium | newline string allocation + split + Swift lookup | moderate | `TUNE` |
| Block edit translation | `Epistemos/Engine/BlockEditTranslator.swift`, `graph-engine/src/lib.rs` | page ID, offsets, text edits, block init arrays | per edit | small | `withCString`, temporary C-string duplication for initial block load | yes | `KEEP` |
| Markdown parser bridge | `Epistemos/Graph/GraphState.swift`, `Epistemos/Views/Notes/MarkdownContentStorage.swift`, `graph-engine/src/markdown.rs` | UTF-8 text in, style spans out | page-mode graph build and editor styling helpers | medium | UTF-8 copy and span walk | moderate | `KEEP` |
| Embedding push | `Epistemos/Graph/EmbeddingService.swift`, `graph-engine/src/lib.rs` | float vectors + node IDs | batch after embedding compute | large batch but infrequent | vector buffers are borrowed; IDs still cross as C strings | warm/cold batch | `KEEP` |
| Hologram inspector helpers | `Epistemos/Views/Graph/HologramNodeInspector.swift` | node IDs, scalar lookups | interaction-time | tiny | none beyond C strings | no | `KEEP` |
| Knowledge-core shadow ring | `Epistemos/Engine/KnowledgeCoreBridge.swift`, `graph-engine/src/knowledge_core/ring.rs`, `graph-engine/src/lib.rs` | rkyv payloads over mmap ring | staged/shadow poll loop | medium | transport is shared-memory; Swift still rehydrates snapshots into strings/arrays | hot only in shadow mode | `ZERO-COPY` only after live UI consumes it |
| Search/query text via local inference stack | `Epistemos/Engine/MLXInferenceService.swift`, `Epistemos/Engine/LLMService.swift` | prompt/context strings | high for chat, not Rust FFI | large strings | not Rust FFI dominated | yes | `REMOVE` from FFI optimization agenda |

## Per-Boundary Notes

### 1. Graph Control and Render FFI

Use plain FFI.

Why:
- payloads are tiny
- latency is dominated by the work inside the engine, not by string marshaling
- shared memory would add ownership complexity for no measurable win

### 2. BTK Subscription Payloads

Current state:
- raw payload handoff uses `Data(bytesNoCopy:)`
- Swift then calls row accessors per row and turns every slice into owned `String`s

Meaning:
- this is not full zero-copy in the user-visible path
- the right near-term fix is not “move everything to shared memory”
- the right near-term fix is fewer row-accessor round-trips and less eager Swift rehydration

Recommendation:
- `BATCH`
- keep the current transport, but reduce row-by-row accessor churn and whole-result rebuilding

### 3. BTK One-Shot Query Helpers

Current state:
- property/depth query helpers return newline-separated page IDs

Meaning:
- simple and stable, but not ideal if query volume rises

Recommendation:
- `TUNE`
- if query UI leans harder on these paths, switch to a typed page-id array buffer before considering shared memory

### 4. Block Edit Translator

Current state:
- direct ABI, page ID + offsets + text
- initial block load duplicates content via `strdup`

Meaning:
- per-keystroke path is already simple and appropriate
- only the initial block bootstrap allocates extra C strings

Recommendation:
- `KEEP`
- do not overengineer this unless a measured editor bottleneck points here

### 5. Markdown Parser Bridge

Current state:
- parser bridge is used for spans, not a full document object graph

Meaning:
- this is closer to the correct architecture already: event/span-oriented, typed, short-lived

Recommendation:
- `KEEP`

### 6. Knowledge-Core Shared Memory

Current state:
- the most advanced bridge in the repo
- still shadow-only
- Swift still materializes snapshots into owned arrays/strings after transport

Meaning:
- the transport is stronger than the live UI integration
- moving more production UI to it before parity would be architecture theater

Recommendation:
- `ZERO-COPY` only where the UI actually consumes high-frequency diffs and benchmarks justify the switch

## Final Boundary Decisions

- `KEEP`
  - graph control/render commands
  - markdown parser span bridge
  - embedding vector push
  - block edit translator
- `TUNE`
  - none yet; the most obvious candidates want batching rather than micro-tuning
- `BATCH`
  - BTK subscription payload consumption
- `ZERO-COPY`
  - staged `knowledge-core` subscriptions only after the UI genuinely moves to them
- `REWRITE`
  - none justified right now
- `REMOVE`
  - do not treat local MLX prompt/context assembly as an FFI problem
