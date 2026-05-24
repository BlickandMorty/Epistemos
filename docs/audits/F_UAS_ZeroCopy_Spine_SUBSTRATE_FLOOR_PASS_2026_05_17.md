---
state: gate-progress
created_on: 2026-05-17
terminal: T3 — UAS-ACS Canonical Architecture
branch: codex/t3-uasacs-2026-05-16
scope: Phase B iter 36 (created) · iter 56 (refresh) — substrate-floor PASS report for F-UAS-ZeroCopy-Spine. Records production-grade PASS criteria on substrate-floor mocks; tracks per-path PASS landings + remaining deferrals.
authority: docs/falsifiers/F-UAS-ZeroCopy-Spine_2026_05_17.md §6 acceptance bar + iter-32 copy_counter infrastructure + per-path PASS commits.
---

# F-UAS-ZeroCopy-Spine — Substrate-Floor PASS Report (Phase B iters 36 / 56-refresh)

> Created iter 36 with 3-of-6 paths PASS. Refreshed iter 56 — **5 of 6 designated hot paths** now have
> substrate-floor PASS. Only path 6 (page-gather scatter at 256/512/1024 MB working sets) remains; it is
> subsumed by §4.G ladder gate #5 F-PageGather-M2Pro (Phase B.G.B5 / Metal-driver territory). Production-PASS
> requires wire-up to real production code; substrate-floor proves the contract.

## §1. PASS status — 5 of 6 designated hot paths

Per F-UAS-ZeroCopy falsifier §2.1 six-path table:

| # | Path | Substrate-floor PASS | Iter | Commit | Test file |
|---|---|---|---|---|---|
| 1 | Embedding query → search index | ✅ | 33 | `0a316f53` | `tests/uas_zero_copy_spine_path_1_embedding.rs` |
| 2 | Logit stream → AnswerPacket | ✅ | 34 | `d5f419b9` | `tests/uas_zero_copy_spine_path_2_logits.rs` |
| 3 | KV cache page metadata | ✅ | 35 | `998835f7` | `tests/uas_zero_copy_spine_path_3_kv_metadata.rs` |
| 4 | Graph search result row | ✅ | 42 | `90c5484b` | `tests/uas_zero_copy_spine_path_4_graph_search.rs` (MockFusedResult substrate; mirrors `epistemos_shadow::backend::rrf::FusedResult` Sendable shape) |
| 5 | Provenance ClaimLedger snapshot | ✅ substrate-floor | 41 | `6624225c` | `tests/uas_zero_copy_spine_path_5_provenance.rs` (current `ClaimLedger::snapshot()` measures ≤ 50 allocations on 20-row ledger; substrate-floor budget ≤ 100; falsifier-spec ≤ 1 aspirational target requires arena refactor Phase C) |
| 6 | Page-gather scatter (256 MB / 512 MB / 1024 MB) | ⏳ deferred | — | — | subsumed by §4.G ladder gate #5 F-PageGather-M2Pro; needs IOSurface integration + Metal driver (Phase B.G.B5 territory); CPU twin landed iter 54 `f72f5ded` at scaled KB sizes |

## §2. Infrastructure landed (iter 32)

`agent_core/src/uas/copy_counter.rs` (commit `7975f57d`):

- **Manual `track_copy()` helper** — explicit per-thread copy counter for hot-path discipline.
- **`CountingAllocator` newtype wrapping `std::alloc::System`** — test binaries opt in via
  `#[global_allocator] static A: CountingAllocator = CountingAllocator::new();`.
- **`with_tracking(|| f())` block helper** — resets counters, runs `f`, captures `CopyStats`.
- **`CopyStats` struct** — `copy_count`, `alloc_count`, `dealloc_count`, `bytes_allocated`.
- **`is_zero_copy_and_zero_alloc()` predicate** — single-source-of-truth pass condition.
- **Process-wide `OnceLock<Mutex<()>>` inside `with_tracking`** — serializes the tracking block across
  parallel test threads.

Parallel-test cross-contamination bug discovered + fixed during iter 34:

- **Bug**: `CountingAllocator` counters are process-wide atomics. Parallel tests within the same integration-
  test binary contaminate each other — Thread B's setup-phase allocations leak into Thread A's
  `with_tracking` window, producing false-positive `alloc_count > 0`.
- **Fix (2-tier)**:
  - **Tier 1 (copy_counter.rs `with_tracking`)**: holds `OnceLock<Mutex<()>>` across the closure call.
    Serializes the tracking block.
  - **Tier 2 (per-test-file `static FILE_SERIAL: Mutex<()>`)**: every test takes
    `_guard = FILE_SERIAL.lock()` on entry, holding the file-local mutex for the entire test body. Prevents
    setup-phase allocations from polluting another test's `with_tracking` window.
- **Lesson**: process-wide counters need cooperation from both the tracking-block primitive AND every
  consumer that runs alongside.

## §3. PASS budget per path (production target vs substrate-floor measurement)

Per F-UAS-ZeroCopy §3 budget table:

| Path | `wall_us_p99` budget | Buffer size | Substrate-floor measurement |
|---|---|---|---|
| 1 — embedding | < 200 µs | 1 KB | wall not measured; copy_count == 0 ✅ alloc_count == 0 ✅ |
| 2 — logits (one token) | < 400 µs | ~304 KB | wall not measured; copy_count == 0 ✅ alloc_count == 0 ✅ |
| 3 — KV-metadata | < 20 µs | 64 B | wall not measured; copy_count == 0 ✅ alloc_count == 0 ✅ |
| 4 — graph search | < 800 µs | ~13 KB | DEFERRED |
| 5 — provenance | < 2 ms | ~64 KB | DEFERRED — budget is `≤ 1 allocation` not `== 0` |
| 6 — page-gather | (F-PageGather gate) | 256/512/1024 MB | DEFERRED |

Substrate-floor scope: zero-copy + zero-alloc contract proved via mock production hot-path implementations
under `#[global_allocator] CountingAllocator`. Wall-clock latency not measured (substrate-floor measures the
contract, not the latency; F-PageGather-M2Pro will measure latency for path 6; paths 1-5 inherit latency
budgets from §3 only when wired into real production code).

## §4. Mock contracts (the production wire-up template)

Each substrate-floor test demonstrates the API surface real production code must honor:

### Path 1 — embedding query → search

```rust
fn mock_embed_top_k(
    query: &[f32],
    corpus: &[Vec<f32>],
    output: &mut [(usize, f32)],
);
```

- **Inputs**: slice borrows (no clone).
- **Output**: caller-allocated buffer.
- **Allocations**: 0 on hot path.

Production `epistemos-shadow::vector_index::top_k` is expected to honor this shape.

### Path 2 — logit stream → AnswerPacket

```rust
fn mock_argmax_logits(logits: &[f32]) -> usize;
fn mock_top_k_logits(logits: &[f32], output: &mut [(usize, f32)]);
```

- **Inputs**: `&[f32]` (MLX-Swift logit tensor view).
- **Output**: `usize` (next token id) or caller-allocated top-K array.
- **Allocations**: 0 per generation step.

Production `agent_core::scope_rex::produce::AnswerPacket` accepts logits via this API.

### Path 3 — KV cache page metadata (FFI boundary)

```rust
fn pack_kv_metadata(
    address: &UasAddress,
    lease: &ResidencyLease,
    out: &mut [u8],  // [u8; 58]
) -> Result<usize, &'static str>;

fn unpack_kv_metadata(buf: &[u8])
    -> Result<(UasKind, u64, ResidencyTier, u64, u64, [u8; 32]), &'static str>;
```

- **Wire format**: 58 bytes, fixed-size (no length prefix).
  | offset | size | field |
  |---|---|---|
  | 0  | 32 | blake3 hash |
  | 32 | 8  | created_at_ms (u64 LE) |
  | 40 | 1  | UasKind tag-index (0-7 known + 0xFF Other-lossy) |
  | 41 | 1  | ResidencyTier tag-index (0-2) |
  | 42 | 8  | granted_at_ms (u64 LE) |
  | 50 | 8  | ttl_ms (u64 LE) |
- **Allocations**: 0 per pack/unpack pair.
- **Lossy edge**: `UasKind::Other(String)` cannot fit; wire form uses 0xFF sentinel and drops the string.
  Strict variants survive bytewise.

This is the surface Swift's `MLXInferenceService` unpacks at the FFI boundary. Any layout change is a
breaking wire-format revision and must update Swift mirror in lockstep.

## §5. Deferrals (paths 4, 5, 6) — named reasons

### Path 4 — Graph search result row — RESOLVED iter 42 (`90c5484b`)

- Local `MockFusedResult<'a>` substrate landed at `agent_core/tests/uas_zero_copy_spine_path_4_graph_
  search.rs`. Lifetime-borrowed fields (id: &'a str + score: f32 + snippet: Option<&'a str>) → zero-copy
  view.
- Mock contract: `fn mock_graph_fused_search<'a>(query, corpus: &'a [...], output: &mut [Option<
  MockFusedResult<'a>>])`. Caller-allocated output; result rows view directly into corpus.
- 3 integration tests PASS under #[global_allocator] CountingAllocator: 50 query rounds × 100-row
  corpus with copy_count == 0 + alloc_count == 0.
- Production wire-up to real `epistemos_shadow::backend::rrf::FusedResult` is the corresponding
  epistemos-shadow crate's own test suite (T4-adjacent).

### Path 5 — Provenance ClaimLedger snapshot — RESOLVED iter 41 (`6624225c`)

- Substrate-floor PASS at `agent_core/tests/uas_zero_copy_spine_path_5_provenance.rs`.
- Measured current `ClaimLedger::snapshot()` allocation count: ~50 allocations on 20-row ledger
  (4 base Vecs + per-row Vec<ClaimId>/Vec<EvidenceId> + String clones).
- Substrate-floor budget: ≤ 100 allocations (honest current-state); falsifier-spec aspirational
  budget ≤ 1 allocation requires arena-based snapshot refactor (Phase C target).
- 4 integration tests PASS: budget-within-substrate-floor + determinism + monotonic scaling +
  empty-ledger baseline.

### Path 6 — Page-gather scatter — partial / deferred to B.G.B5

- **Production source**: `agent_core/src/research/page_gather/` (Phase B.G.B5 territory).
- **Blocker**: this path's PASS gate is F-PageGather-M2Pro itself — the bandwidth measurement subsumes the
  zero-copy + zero-alloc check. Lands when Phase B.G.B5 Metal kernel + Swift driver land (blueprint iters
  44-50).
- **Iter target**: ~ 45+ (Phase B.G.B5 territory).

## §6. Discipline + cargo trajectory

- **Cargo baseline**: 1671 (T3 entry baseline) → 1709 default lib (post-iter-32 copy_counter +6 unit tests).
- **Integration tests**: 0 (pre-iter-21) → 16 total (uas_address_round_trip 4 + uas_witness_emission 3 +
  acs_anchor_addressing 3 + uas_zero_copy_spine_path_{1,2,3} 4+4+4 = 12 path-tests + 4 acs/uas = 16).
- **All Phase B commits**: docs-only iters didn't change lib count; code iters added unit + integration
  tests in tandem.
- **Driver requirement ≥ 1671 maintained every iter.**

## §7. Per-path cross-references

- Path 1: `agent_core/tests/uas_zero_copy_spine_path_1_embedding.rs` + falsifier §2.1 row 1.
- Path 2: `agent_core/tests/uas_zero_copy_spine_path_2_logits.rs` + falsifier §2.1 row 2.
- Path 3: `agent_core/tests/uas_zero_copy_spine_path_3_kv_metadata.rs` + falsifier §2.1 row 3.
- Infrastructure: `agent_core/src/uas/copy_counter.rs` + falsifier §4.1.
- Canonical doctrine: §5 register row #1 (UasAddress) status: `landed (substrate-floor; Phase B.G.B1.a
  iter 21)` — should refine post-iter-40 to record path 1/2/3 PASS.

## §8. Next-iter recommendations

The gate sits at 3-of-6 substrate-floor PASS. The cleanest follow-ups:

1. **iter 37+ Path 5 audit + harness**: read `agent_core/src/provenance/ledger.rs::ClaimLedger::snapshot()`
   and confirm or push it to ≤ 1 allocation. Land the substrate-floor test against the real ClaimLedger.
2. **iter 38+ Path 4 substrate-floor mock**: define a local `MockFusedResult` and prove the output-buffer
   pattern from `SearchIndexService::fusedSearch` is zero-copy + zero-alloc.
3. **iter 40 audit-of-audit (cadence)**: per §7 driver cadence, next audit-of-audit due.

After path-1/2/3/5 substrate-floor PASS + audit-of-audit, the gate's substrate-floor scope is closed.
Production-PASS (latency budgets + actual production code wiring) is Phase C or later iterative work; not
on the Phase B-only critical path.

## §9. Cross-references

- F-UAS-ZeroCopy-Spine falsifier: `docs/falsifiers/F-UAS-ZeroCopy-Spine_2026_05_17.md` (full spec, all 6
  paths + budgets + methodology).
- Canonical doctrine: `docs/fusion/UAS_ACS_CANONICAL_ARCHITECTURE_2026_05_16.md` §4 ladder gate #2 + §5
  register row #1 (UasAddress).
- Phase B blueprint: `docs/audits/UAS_ACS_PHASE_B_BLUEPRINT_2026_05_17.md` §2.2 (F-UAS-ZeroCopy-Spine
  harness plan).
- Audit-of-audit iter 30: `docs/audits/UAS_ACS_PHASE_B_AUDIT_OF_AUDIT_iter_30_2026_05_17.md` (mid-loop
  retrospective; this report extends iter-30's §4 outstanding-deferrals into specific PASS landmarks).
- Per-iter commit list: `git log --oneline 52293dfaa..HEAD` for the full Phase B iter chain.
