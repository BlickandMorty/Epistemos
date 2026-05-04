# FFI Copy Trace

## Purpose

This traces where bytes and object materialization occur in both the staged knowledge-core path and the live BTK path.

## Summary

| Path | Transport copy | Decode copy | Status |
|---|---|---|---|
| Staged knowledge-core producer | removed in this pass | still present on Swift snapshot build | `PARTIAL` |
| Staged knowledge-core consumer | no `Data` copy | per-row FFI + Swift `String`/array materialization | `PARTIAL` |
| Live BTK producer | `Vec<u8>` archive buffer | yes | `FAIL` for zero-copy claim |
| Live BTK consumer | `Data(bytesNoCopy)` handoff, then decoded rows/strings | yes | `FAIL` for zero-copy claim |

## 1. Staged knowledge-core producer path

Code path:

```text
KnowledgeCore::publish_diff()
  -> SharedRingBuffer::write_archived_frame()
  -> SlotWriter
  -> rkyv::to_bytes_in(...)
  -> mapped slot payload
```

### Copies

Before this pass:

1. archive into temporary `Vec<u8>`
2. copy temporary bytes into slot payload

After this pass:

1. archive bytes are written directly into the slot payload

### Result

- Intermediate `Vec<u8>` removed
- One real hot-path copy eliminated

## 2. Staged knowledge-core consumer path

Code path:

```text
KnowledgeCoreBridge.drain(...)
  -> graph_engine_kc_ring_head/core tail
  -> slot(at:)
  -> decodeSummary()
  -> graph_engine_kc_payload_summary(...)
  -> decodePayload()
  -> decodeRows()
  -> graph_engine_kc_payload_rows(...)
  -> String(decoding: ...)
  -> KnowledgeCoreRowSnapshot
```

### Copies and allocations

Shared-memory transport stage:

- `KnowledgeCoreBridge` reads directly from mapped shared memory
- no `Data` wrapper
- no JSON
- no Foundation collection bridge

Archive access stage:

- Rust `graph_engine_kc_payload_summary(...)` validates the payload once for staged summary reads
- Rust `graph_engine_kc_payload_rows(...)` validates the payload once per section for the default staged row path
- scalar fallback still uses `graph_engine_kc_payload_row(...)` per row if the batch accessor fails
- no payload copy here
- row field slices point back into the archived payload

Swift projection stage:

- `decode(_:)` creates a new Swift `String`
- `rows.append(...)` allocates/appends `KnowledgeCoreRowSnapshot`
- `KnowledgeCorePayloadSnapshot` owns new Swift arrays

### Result

- zero-copy transport: `TRUE`
- zero-copy UI snapshotting: `FALSE`

## 3. Live BTK producer path

Code path:

```text
BtkQueryKernel diff payload
  -> rkyv::to_bytes(...)
  -> Vec<u8>
  -> GraphEngineByteBuffer
```

### Copies

- archive bytes are materialized in a `Vec<u8>`
- ownership of the vector is handed across FFI

### Result

- not zero-copy

## 4. Live BTK consumer path

Code path:

```text
graph_engine_btk_take_subscription_update(...)
  -> Swift GraphEngineByteBuffer
  -> Data(bytesNoCopy/deallocator or equivalent wrapper path)
  -> decodeBTKPayload(...)
  -> Swift arrays
  -> Swift strings
```

### Copies

- `Vec<u8>` archive allocation on Rust side
- `Data(bytesNoCopy:...)` avoids a second payload memcpy on Swift side
- row materialization into Swift structs
- string materialization into Swift `String`

### Result

- far from zero-copy

## 5. Hidden costs still present in staged knowledge-core

### Remaining row-level FFI chatter

The summary path improved in this pass:

- `decodeSummary()` now uses one FFI call:
  - `graph_engine_kc_payload_summary`
- measured improvement vs scalar summary accessors: `6.36x`

The row path improved in this pass too:

- `KnowledgeCoreBridge.decodeRows(...)` now requests a whole section through:
  - `graph_engine_kc_payload_rows`
- scalar fallback remains available through:
  - `graph_engine_kc_payload_row`

Implication:

- large diffs still pay Swift string/array materialization once row projection begins
- per-row boundary crossings are reduced for the default staged path
- repeated archive validation is reduced from once per row to once per section when the batch accessor succeeds

Measured row-path improvement:

- scalar row accessor loop: `19825 ns/payload`
- batched row accessor: `5710 ns/payload`
- speedup: `3.47x`

### Swift snapshot safety tradeoff

Materializing Swift-owned snapshots is not accidental. It buys:

- actor-safe ownership
- lifetime independence from ring reuse
- simpler UI update logic

But it means the current staged bridge optimizes transport first, not full end-to-end ownership-free UI consumption.

## 6. Copy-removal opportunities still open

1. Reduce repeated payload validation:
   - row sections now validate once per section; whole-slot reuse is still open
2. Reduce row-level FFI calls:
   - section batching landed; full-payload projection is still open
3. Reduce Swift string materialization when summaries are enough:
   - keep summary-only path for non-visible subscriptions
4. Keep default runtime on BTK until these costs are measured against real workloads

## Final classification

- `knowledge-core`: zero-copy transport, non-zero-copy consumption
- `BTK`: copied on both producer and consumer sides
