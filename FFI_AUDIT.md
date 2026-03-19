# FFI Audit

## Scope

This audit covers the staged knowledge-core Rust <-> Swift bridge, not the legacy BTK byte-buffer path except where comparisons matter.

Primary files inspected:

- `graph-engine/src/knowledge_core/ring.rs`
- `graph-engine/src/knowledge_core/mod.rs`
- `graph-engine/src/lib.rs`
- `graph-engine-bridge/graph_engine.h`
- `Epistemos/Engine/KnowledgeCoreBridge.swift`
- `Epistemos/App/AppBootstrap.swift`
- `EpistemosTests/KnowledgeCoreBridgeTests.swift`

## Verdict

The staged knowledge-core bridge now satisfies the basic shape of a low-latency shared-memory SPSC transport. It does not yet satisfy the stronger claim of end-to-end zero-copy UI delivery.

Status by requirement:

- Shared memory transport: `PASS` for staged path
- True SPSC ownership model: `PASS`
- 128-byte head/tail separation: `PASS`
- Producer-side temp-buffer copy removed: `PASS`
- Summary-path repeated archive validation reduced: `PASS`
- Row-path repeated archive validation reduced: `PASS`
- Consumer-side zero-copy into UI models: `FAIL`
- Backpressure policy explicit: `PASS`
- Error observability across FFI: `PARTIAL`

## A. Shared memory transport

### What is actually true

- Transport is backed by `mmap` in `graph-engine/src/knowledge_core/ring.rs`.
- The mapping uses `MAP_ANON | MAP_SHARED`.
- Rust owns the mapped region and exposes its base pointer + length through:
  - `graph_engine_kc_ring_region`
  - `graph_engine_kc_ring_layout`
- Swift stores that raw mapping as `UnsafeMutableRawPointer` in `KnowledgeCoreBridge`.
- Swift computes slot addresses from the exported layout instead of asking Rust to copy frames.

### What is not true

- This is not a separate-process IPC bridge today.
- The mapping is shared inside the same process between Rust and Swift via FFI.
- The transport is therefore cross-language shared memory, not yet cross-process IPC.

### SPSC proof

The ownership split is structurally SPSC:

- Rust producer:
  - writes payload bytes
  - writes slot header
  - publishes `head`
- Swift consumer:
  - reads `head`
  - reads slot header/payload
  - publishes `tail`

No code path audited writes `head` from Swift or `tail` from Rust except the explicit consumer publish call `graph_engine_kc_ring_set_tail`.

### Layout and alignment proof

The ring now has both compile-time and runtime layout checks:

- Compile-time assertions in `ring.rs`:
  - `size_of::<CachePaddedAtomicU64>() == 128`
  - `align_of::<CachePaddedAtomicU64>() == 128`
  - `offset_of!(SharedRingHeader, head) == 0`
  - `offset_of!(SharedRingHeader, tail) == 128`
- Runtime debug assertions in `SharedRingBuffer::debug_assert_layout()`
- Swift startup precondition in `KnowledgeCoreBridge.init` validates basic ring layout invariants before use

Tests proving transport/layout:

- `layout_keeps_head_and_tail_on_separate_cache_lines`
- `slot_write_roundtrips`
- `archived_frame_roundtrips_without_intermediate_buffer`
- `advancing_tail_recovers_capacity_after_full`

## B. Memory ordering correctness

### Producer ordering

In `SharedRingBuffer::write_archived_frame(...)`:

1. Rust writes payload bytes into the reserved slot.
2. Rust writes the slot header.
3. Rust publishes `head` with `Ordering::Release`.

That is the right publication order for an SPSC queue.

### Consumer ordering

Swift does not read atomics directly from mapped memory. It calls:

- `graph_engine_kc_ring_head(core)` -> Rust `load_head()` -> `Acquire`
- `graph_engine_kc_ring_tail(core)` -> Rust `load_tail()` -> `Acquire`
- `graph_engine_kc_ring_set_tail(core, tail)` -> Rust `store_tail()` -> `Release`

That gives the intended symmetry:

- producer `Release(head)`
- consumer `Acquire(head)`
- consumer `Release(tail)`
- producer `Acquire(tail)`

### SeqCst usage

- No unnecessary `SeqCst` ordering was found in the staged ring path.
- The ring uses `Acquire`/`Release` only.

### UB / aliasing assessment

What is justified:

- slot payload writes use bounded `ptr::copy_nonoverlapping`
- slot header writes use `ptr::write`
- the mapped header is read through shared references after initialization
- archived payload access goes through `rkyv::access`, which validates before returning borrowed views

Remaining risk:

- Swift reads `KnowledgeCoreSlotHeader` directly with `UnsafeMutableRawPointer.load(as:)`.
- That is valid only because the consumer reads slots whose sequence is already published through the acquired `head`.
- If slot memory were corrupted, Swift currently breaks the drain loop and leaves `tail` unchanged, which can stall forward progress on a corrupt frame.

## C. Hidden copies

### Staged knowledge-core path

Producer hot path:

- Before this pass:
  - `QueryDiffEnvelope`
  - `rkyv::to_bytes(...)`
  - intermediate `Vec<u8>`
  - `memcpy` into ring slot
- After this pass:
  - `QueryDiffEnvelope`
  - `rkyv::to_bytes_in(...)` into `SlotWriter`
  - direct write into reserved ring slot

This copy was real and is now removed.

Consumer hot path:

- Swift maps ring memory directly.
- Swift reads slot header directly.
- Swift now reads staged payload summaries through one typed accessor:
  - `graph_engine_kc_payload_summary`
- Swift still passes slot payload pointers back into Rust for row accessors when full payload decoding is requested.
- Rust validates the archive and projects fields into C-stable slices.
- Swift then materializes:
  - `KnowledgeCorePayloadSummary`
  - `KnowledgeCoreRowSnapshot`
  - Swift `String`
  - Swift `[KnowledgeCoreRowSnapshot]`

Conclusion:

- Transport is zero-copy up to the mapped payload.
- The UI-safe snapshot path still copies heavily.
- The bridge is not end-to-end zero-copy.

### Hidden per-row overhead

The staged summary path is no longer the worst offender:

- `decodeSummary()` now calls one accessor:
  - `graph_engine_kc_payload_summary`
- this validates the archive once and returns tx id, subscription id, kind, and row counts together

Measured improvement:

- scalar summary accessor sequence: `34045 ns/decode`
- combined summary accessor: `5481 ns/decode`
- speedup: `6.21x`

The remaining FFI-chattiness is row decoding, but it is reduced now:

- old path:
  - `graph_engine_kc_payload_row_count`
  - `graph_engine_kc_payload_row` once per row
- new default Swift path:
  - `graph_engine_kc_payload_row_count`
  - `graph_engine_kc_payload_rows` once per section

Full row payload decoding still materializes Swift-owned strings and arrays, but repeated archive validation and per-row FFI call overhead are reduced.

Measured row-path improvement:

- scalar row accessor loop: `12506 ns/payload`
- batched row accessor: `3807 ns/payload`
- speedup: `3.28x`

## D. rkyv correctness

### What is correct

- Hot-path staged payloads are archived `QueryDiffEnvelope`s.
- Access uses `rkyv::access`, not unchecked casts.
- The archive stays resident in the mapped slot payload.
- Producer-side archive write now happens directly into the slot buffer.

### What is less ideal than the design brief

- Swift is not directly traversing archived relative pointers itself.
- Swift currently relies on Rust accessor functions to validate and expose fields.
- Relative-pointer safety is therefore mostly exercised on the Rust side, not the Swift side.

This is still a reasonable staged design, but it is weaker than the original claim of fully native Swift zero-copy archive traversal.

## E. Backpressure

### Current policy

The ring is bounded and non-overwriting:

- if `head - tail >= slot_count`, write returns `RingError::Full`
- no overwrite occurs
- no blocking occurs inside the ring
- no unbounded growth occurs

That is explicit and correct as a bounded queue policy.

### Recovery proof

Added test:

- `advancing_tail_recovers_capacity_after_full`

This proves `Full` is recoverable once the consumer advances `tail`.

### Operability

- `graph_engine_kc_ingest_document`
- `graph_engine_kc_insert_block`
- `graph_engine_kc_move_block`
- `graph_engine_kc_delete_block`

all still collapse `Result<_, _>` to `u8` success/failure, but the core now exposes:

- `graph_engine_kc_last_error_code`
- `graph_engine_kc_last_error_message`

Swift can now distinguish:

- ring full
- parser failure
- store/query failure
- CRDT failure

What is still missing:

- typed result objects instead of `0/1`
- richer backpressure policy beyond immediate failure

### Current explicit policy

The staged core now exposes:

- `graph_engine_kc_backpressure_policy(...)`
- `graph_engine_kc_transport_stats(...)`

Current policy is explicitly `FailFast` only:

- no blocking
- no overwrite
- no silent drop
- no coalescing

This is intentional for now. More complex policies were not added because they would either hide correctness failures or require a larger queue-ownership redesign.

## Targeted fixes landed

1. Direct archive-into-slot write:
   - `KnowledgeCore::publish_diff()` now calls `write_archived_frame()`
2. Layout assertions:
   - compile-time and runtime assertions in `ring.rs`
3. Backpressure recovery test:
   - `advancing_tail_recovers_capacity_after_full`
4. Explicit backpressure/stats FFI:
   - `graph_engine_kc_backpressure_policy(...)`
   - `graph_engine_kc_transport_stats(...)`
5. Batched row accessor:
   - `graph_engine_kc_payload_rows(...)`
   - `KnowledgeCoreBridge.decodeRows(...)` now prefers one batched section read with scalar fallback
6. Swift bridge regression coverage:
   - `KnowledgeCoreBridgeTests.bridgeExposesBackpressurePolicyAndTransportStats`

## Validation status

Validated successfully:

- `cargo test --manifest-path /Users/jojo/Epistemos/graph-engine/Cargo.toml knowledge_core_ffi_tests -- --nocapture`
- `cargo test --manifest-path /Users/jojo/Epistemos/graph-engine/Cargo.toml knowledge_core -- --nocapture`
- `cargo test --manifest-path /Users/jojo/Epistemos/graph-engine/Cargo.toml benchmark_knowledge_core_payload_rows_batch_accessor -- --ignored --nocapture`
- `xcodebuild -project /Users/jojo/Epistemos/Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO`

Still blocked:

- `xcodebuild -project /Users/jojo/Epistemos/Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/KnowledgeCoreBridgeTests CODE_SIGNING_ALLOWED=NO`

Reason:

- the app test target still has pre-existing unrelated Swift 6 migration compile failures outside `knowledge-core`, including `ConcurrencyEdgeCaseTests.swift`, `ConcurrencyStressTests.swift`, and older pipeline/graph tests
4. Swift shadow consumer:
   - feature-flagged shared-memory bridge in `KnowledgeCoreBridge.swift`
5. Rust payload accessors:
   - typed row projection without `Data` or JSON
6. Staged FFI error introspection:
   - `graph_engine_kc_last_error_code`
   - `graph_engine_kc_last_error_message`
7. Single-pass staged summary accessor:
   - `graph_engine_kc_payload_summary`

## Benchmarks run

Command:

```bash
cargo test --manifest-path /Users/jojo/Epistemos/graph-engine/Cargo.toml \
  knowledge_core::ring::tests::benchmark_archived_write_vs_temp_buffer_path \
  --release -- --ignored --nocapture
```

Result:

- ring producer temp-buffer path: `175 ns/write`
- ring producer direct-archive path: `64 ns/write`
- measured producer speedup: `2.70x`

Command:

```bash
cargo test --manifest-path /Users/jojo/Epistemos/graph-engine/Cargo.toml \
  benchmark_knowledge_core_payload_summary_accessor \
  -- --ignored --nocapture
```

Result:

- staged scalar summary decode: `34045 ns/decode`
- staged combined summary decode: `5481 ns/decode`
- measured summary decode speedup: `6.21x`

- temp-buffer path: `175 ns/write`
- direct archive-into-slot path: `64 ns/write`
- measured speedup: `2.70x`

This benchmark only measures the producer write path. It does not validate end-to-end UI latency.

## Bottom line

The staged ring transport is now materially better and structurally correct as an SPSC shared-memory bridge. The remaining hard truth is:

- producer path: strong
- transport path: strong
- consumer decode path: still copy-heavy and FFI-chatty
- observability/backpressure reporting: still weak

This path is good enough for continued shadow benchmarking. It is not yet evidence for replacing the default runtime.
