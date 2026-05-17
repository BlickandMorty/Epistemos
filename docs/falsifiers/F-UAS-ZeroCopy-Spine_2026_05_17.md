---
state: falsifier
gate: F-UAS-ZeroCopy-Spine
ladder_position: 2 (after F-VaultRecall-50, before F-ACS-Anchor-Addressing)
owner: T3
created_on: 2026-05-17
authority: docs/CODEX_DEEP_INVESTIGATION_PROMPT_2026_05_16.md §4.G falsifier ladder (LOCK)
target_phase: Phase B.G.B2
target_rig: M2 Pro 16 GB (canonical ship target)
---

# F-UAS-ZeroCopy-Spine

> Gate #2 in the §4.G falsifier ladder. **Rust ↔ MLX-Swift ↔ Swift UI hot buffers do not re-serialize.** Zero
> re-marshalling on designated hot paths. Until this gate passes, the UAS layer cannot claim ship-readiness on
> M2 Pro 16 GB.

## §1. Why this gate exists

The §4.G hierarchy puts UAS — *identity-independent-of-residency* — directly under the Helios memory substrate.
That promise is only credible if a `UasAddress` resolves to a buffer that hot-path code can read without
serializing through JSON, base64, or `Vec<u8>` round-trips at the FFI boundary.

The driver §4.G prose:

> **F-UAS-ZeroCopy-Spine** — Rust ↔ MLX-Swift ↔ Swift UI hot buffers do not re-serialize. Measure copy count +
> allocation count + latency for embeddings, logits, KV metadata, graph/search results. Target: zero
> re-marshalling on the hot path.

Project rule reinforcement (`CLAUDE.md` "research-first, semantic expansion"):

> "zero-copy" means UMA, shared buffers, IOSurface, in-process, single-binary, deterministic provenance, no
> hot-path subprocess, no tensor copies, direct/bare-metal path.

## §2. Pass/fail recipe (the test that decides)

A `#[test]` in `agent_core/tests/uas_zero_copy_spine.rs` (lands in Phase B.G.B2) exercises each designated hot
path and records:

- **copy_count** — number of times the buffer's bytes are read/written into a fresh allocation
- **allocation_count** — number of fresh allocations on the path (Box / Vec / String / Arc-from-new)
- **fp_op_count** — control measurement to confirm the kernel actually ran
- **wall_us_p50** + **wall_us_p99** — latency percentiles over `N = 1000` warm iterations

The gate **fails** if `copy_count > 0` for any designated hot-path operation. The gate **passes** when
`copy_count == 0` AND `allocation_count == 0` (steady-state — startup allocations don't count) AND `wall_us_p99`
is within the §3 budget table.

### §2.1 Designated hot-path operations

| # | Path | Buffer type | Source | Sink | Acceptance |
|---|---|---|---|---|---|
| 1 | Embedding query → search index | `&[f32]` (Model2Vec embedding) | Swift `EmbedderRegistry` | Rust `epistemos-shadow::vector_index` | `copy_count == 0` |
| 2 | Logit stream → AnswerPacket | `&[f32]` (MLX-Swift logits) | Swift `MLXInferenceService` | Rust `agent_core::scope_rex::produce::AnswerPacket` | `copy_count == 0` |
| 3 | KV cache page metadata | `&[u8]` (UasAddress + ResidencyLease handle) | Rust `agent_core::scope_rex::kv::direct_gate` | Swift `Epistemos/Engine/MLXInferenceService` | `copy_count == 0` |
| 4 | Graph search result row | `&FusedResult` (Sendable struct, see Sync/RRFFusionQuery.swift:18) | Rust `epistemos-shadow::backend::rrf` | Swift `SearchIndexService::fusedSearch` | `copy_count == 0` (FFI pre-serialized to bytes is acceptable IFF the bytes are mmap'd) |
| 5 | Provenance ClaimLedger snapshot | `&LedgerSnapshot` (BLAKE3-hashed canonical-JSON IS the wire format) | Rust `agent_core::provenance::ledger` | Rust `agent_core::provenance::replay::ReplayBundle` | snapshot bytes ≤ 1 allocation (in-process, no FFI) |
| 6 | Page-gather scatter input/output | `&[f32]` (256 MB / 512 MB working set) | Swift `PageGather.metal` driver | Rust `agent_core::helios::page_gather` (CPU reference path) | `copy_count == 0` (IOSurface- or shared-buffer-backed) |

### §2.2 Instrumentation

The harness uses Rust's standard tooling:

- **copy_count**: `dhat::start_heap_profiling()` + a custom `tracking-allocator` shim wrapping
  `std::alloc::System` (per the `dhat-heap` example). Counters reset at iteration boundary.
- **allocation_count**: same allocator shim, separate counter.
- **fp_op_count**: incremented inline by the kernel under test.
- **wall_us**: `std::time::Instant::elapsed().as_micros()` recorded per iteration; percentile over `N` samples.

For Swift side (path #1, #2, #3, #4, #6), the harness shells out via FFI to a Rust helper that calls into
MLX-Swift through the bridge (`agent_core::bridge`) and reads the allocator counters before/after.

## §3. M2 Pro 16 GB budget (per-path)

The latency budget is constrained by M2 Pro 16 GB MEASURED bandwidth (per `epistemos-research::hardware_profile`
and the §4.G "NOT theoretical 200 GB/s spec" warning):

| Path | Buffer size | `wall_us_p50` | `wall_us_p99` | Memory ceiling |
|---|---|---|---|---|
| 1 — Embedding query | 256 floats × 4 B = 1 KB | < 50 µs | < 200 µs | reuse pool |
| 2 — Logit stream (one token) | vocab × 2 B fp16 (152 k for Qwen3) ≈ 304 KB | < 100 µs | < 400 µs | reuse pool |
| 3 — KV cache page metadata | 64 B handle | < 5 µs | < 20 µs | (negligible) |
| 4 — Graph search result row | ~256 B per row × 50 rows = ~13 KB | < 200 µs | < 800 µs | mmap |
| 5 — Provenance ClaimLedger snapshot | ~64 KB | < 500 µs | < 2 ms | 1 in-process Vec |
| 6 — Page-gather scatter | 256 MB (M2 Pro working-set per §4.G F-PageGather-M2Pro) | (covered by F-PageGather-M2Pro gate) | (covered by F-PageGather-M2Pro gate) | IOSurface |

Total per-token hot-path budget (1+2+3): `p99 ≤ 620 µs`. This budget aligns with the V6.1 "Attention as Interrupt"
posture — interrupt latency P99 < 100 µs (Swift CPU side) means UAS handoffs cannot dominate.

## §4. Measurement methodology

### §4.1 Iteration protocol

1. Run `cargo test --manifest-path agent_core/Cargo.toml --release --test uas_zero_copy_spine -- --nocapture --test-threads=1`.
2. The harness:
   - Allocates each buffer once outside the timing loop.
   - Runs 100 warm-up iterations (discarded).
   - Runs `N = 1000` timed iterations.
   - Records copy_count, allocation_count, fp_op_count, and latency per iteration.
   - Reports p50 + p99 + max + min + mean + stddev + total allocations + total copies.
3. The `#[test]` body asserts (per path):
   ```rust
   assert_eq!(stats.copy_count, 0,
       "F-UAS-ZeroCopy-Spine FAILED: path = {:?}, copy_count = {}",
       path_id, stats.copy_count);
   assert_eq!(stats.allocation_count, 0,
       "F-UAS-ZeroCopy-Spine FAILED: path = {:?}, allocation_count = {} (steady-state)",
       path_id, stats.allocation_count);
   assert!(stats.wall_us_p99 < BUDGET_P99_PER_PATH[path_id]);
   ```

### §4.2 Background-noise control

- Disable Spotlight indexing on `/Users/jojo/Downloads/Epistemos-t3-uasacs/target/` before the run
  (`mdutil -d` for the dir).
- Run with CPU governor pinned (`pmset -a powermode 2` for "high performance" on macOS).
- Idle for 30 s before timing loop to let thermal settle.
- Re-run the suite 3× and take the median of the 3 runs to absorb thermal-throttle noise.

### §4.3 What counts as a "copy"

Per `CLAUDE.md` semantic expansion, the gate's definition of "zero-copy" excludes:

- IOSurface-backed buffers (UMA shared between CPU + GPU)
- `mmap`'d files (kernel-page-cache shared with userspace)
- `Arc<[T]>` reference-count handoff (no byte copy)
- FFI-passing a stable raw-pointer + length (`*const u8` + `usize`)

It includes (i.e. counts as a copy and fails the gate):

- `Vec<u8>::clone()` / `[T]::to_vec()`
- `serde_json::to_string` / `serde_json::from_str` on the hot path
- `base64::encode` / `base64::decode` on the hot path
- `String::from_utf8_lossy` allocating a new String
- Re-allocation due to growth (`Vec::push` beyond capacity)
- MLX `to_array` → Rust `Vec<f32>` materialization (must be Metal-buffer-backed view instead)

## §5. Fallback if the gate fails

Per §4.G "No silent skips. A falsifier failing means its dependency cap stays closed; the work below it gets a
STALLED status row in the doctrine doc":

1. **Identify the offending path**. The harness reports per-path stats; the failing path is the one with
   `copy_count > 0` or `wall_us_p99 > BUDGET[path_id]`.
2. **Classify the copy**. Walk the offending path with `cargo flamegraph --release` and trace the
   first `Vec::with_capacity` / `to_vec` / `clone` on the hot path.
3. **Mitigation tier** (least invasive first):
   - **Tier 1 — buffer reuse**: hoist the allocation out of the loop into a thread-local arena / `bumpalo`.
     Try this before any refactor.
   - **Tier 2 — view-not-copy**: change the function signature from `Vec<T>` / `String` to `&[T]` / `&str`.
   - **Tier 3 — Arc handoff**: if ownership transfer is genuinely needed, switch to `Arc<[T]>` so the second
     receiver gets a refcount, not a clone.
   - **Tier 4 — IOSurface / mmap**: for buffer sizes ≥ 64 KB on the GPU path, route the buffer through an
     IOSurface (Metal) or mmap'd file. This is the §4.G "UMA, shared buffers, IOSurface" path.
   - **Tier 5 — STALLED**: if no mitigation passes the gate, file a STALLED row in
     `docs/fusion/UAS_ACS_CANONICAL_ARCHITECTURE_2026_05_16.md` §5 (register row #1-3 for UAS) and a
     `BLOCKER:` commit message. Do not push.
4. **Document the mitigation** in a tail comment on the source file: `// F-UAS-ZeroCopy-Spine: buffer reused
   from thread-local pool; see docs/falsifiers/F-UAS-ZeroCopy-Spine_2026_05_17.md §5.`

## §6. Acceptance bar (gate-pass criteria)

The gate **passes** when ALL of the following are true on M2 Pro 16 GB:

- [ ] All 6 designated hot-path operations report `copy_count == 0` in steady state.
- [ ] All 6 designated hot-path operations report `allocation_count == 0` in steady state.
- [ ] All 6 designated hot-path operations meet their §3 `wall_us_p99` budget.
- [ ] Median-of-3-runs reproducibility: same per-path stats across 3 separate harness invocations (within 10% on
  latency, exact on copy_count + allocation_count).
- [ ] `cargo test` count remains ≥ 1671 + (number of new uas_zero_copy_spine tests). No regressions on the
  agent_core lib-test suite.
- [ ] The gate's `#[test]` is listed in `docs/fusion/UAS_ACS_CANONICAL_ARCHITECTURE_2026_05_16.md` §5 register
  row #1-3 with a green status.
- [ ] `Co-Authored-By: Codex (T3)` on every commit landing the gate.

## §7. Dependencies + downstream gates

**Depends on** (must land before this gate's `#[test]` is meaningful):

- Phase B.G.B1: `UasAddress` + `ResidencyLease` + `UasKind` typed identity in `agent_core/src/uas/`.

**Unblocks** (the next gates whose acceptance refers to UAS plumbing):

- Gate #3 F-ACS-Anchor-Addressing (anchor round-trips through the same FFI surface)
- Gate #4 F-ShadowFirst-PageEscalation (the sketch/residual/exact pipeline runs through the same hot path)
- Gate #5 F-PageGather-M2Pro (the 256/512/1024 MB scatter buffers are the heaviest hot-path consumer)

## §8. Cross-references

- Canonical doctrine: `docs/fusion/UAS_ACS_CANONICAL_ARCHITECTURE_2026_05_16.md` §4 ladder + §5 register rows #1-3.
- Substrate-floor audit: `docs/audits/UAS_ACS_SUBSTRATE_INVENTORY_2026_05_17.md` §A row #1-3 + §C gap list.
- Driver authority: `docs/CODEX_DEEP_INVESTIGATION_PROMPT_2026_05_16.md` §4.G ladder gate #2.
- Project rules: `CLAUDE.md` "zero-copy" semantic expansion + memory-pressure hardening section.
- Related work landed: provenance ClaimLedger zero-copy path (path #5 above) already lands at
  `agent_core/src/provenance/{ledger,replay}.rs` via BLAKE3-hashed canonical JSON; tests at
  `agent_core/tests/epistemos_trace_e2e.rs`.
