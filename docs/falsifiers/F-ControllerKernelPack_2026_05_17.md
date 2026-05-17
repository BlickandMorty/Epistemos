---
state: falsifier
gate: F-ControllerKernelPack
ladder_position: 11 (after F-PacketRouter1bit-Dispatch, before F-70B-Local-Cocktail-Composition)
owner: T3
created_on: 2026-05-17
authority: docs/CODEX_DEEP_INVESTIGATION_PROMPT_2026_05_16.md §4.G falsifier ladder (LOCK)
target_phase: Phase C
target_rig: M2 Pro 16 GB
---

# F-ControllerKernelPack

> Gate #11 in the §4.G falsifier ladder. **Controller (small-state inference) kernel pack passes correctness +
> performance on M2 Pro.** Helios v6.2 §5 acceptance: 6 fused micro-kernels reference-equivalent vs Swift.

## §1. Why this gate exists

§4.G classifies "Kernels (MUSCLE)" as the layer below Shadow-first paging. The controller path of any
small-state inference engine (Mamba-2, RWKV-7, the controller half of hybrid models) dispatches many small
kernels per token. Packing those into a single Metal file amortizes the dispatch overhead and gates the
inference loop's per-token kernel cost.

The CPU reference at `agent_core/src/helios/controller_pack.rs` (343 LOC) implements the canonical 6:

| # | Function | Operation |
|---|---|---|
| 1 | `scalar_add_in_place` | `a[i] += scalar` |
| 2 | `scalar_mul_in_place` | `a[i] *= scalar` |
| 3 | `max_reduce` | `max(a)` (returns NaN for empty input, surfaced) |
| 4 | `argmax_reduce` | `argmax(a)` (first-index tie-break) |
| 5 | `copy_range` | `dst[..len] = src[..len]` |
| 6 | `zero_fill` | `a[..] = 0` |

This gate proves the Metal kernel pack matches the Rust reference bit-for-bit (within fp32 tolerance) AND
hits a per-call dispatch budget that keeps the per-token controller cost negligible.

Driver §4.G prose + Helios v6.2 §5 acceptance:

> ControllerKernelPack 6 fused micro-kernels reference-equivalent vs Swift.

## §2. Pass/fail recipe (the test that decides)

Two-track harness:

### §2.1 Track A — bit-for-bit correctness

`#[test]` at `agent_core/tests/controller_kernel_pack_correctness.rs`:

```rust
let fixtures = ControllerKernelFixtureSet::seeded(
    N = 100,
    array_sizes = vec![1, 16, 64, 256, 1024, 4096, 16_384],
);

for fixture in fixtures {
    for size in &fixture.array_sizes {
        // scalar_add_in_place
        let scalar = fixture.scalar(0);
        let mut buf_ref = fixture.array_f32(*size, 0).to_vec();
        let mut buf_metal = buf_ref.clone();
        scalar_add_in_place(&mut buf_ref, scalar)?;
        scalar_add_in_place_metal(&mut buf_metal, scalar)?;
        assert_arrays_equal_f32(&buf_ref, &buf_metal, /*tol*/ 0.0,
            "F-ControllerKernelPack FAILED: scalar_add size={} scalar={}", size, scalar);

        // scalar_mul_in_place
        // ... (same pattern for all 6 functions)

        // max_reduce, argmax_reduce — assert exact equality (no rounding)
        // copy_range — assert exact equality
        // zero_fill — assert exact equality
    }
}
```

Acceptance: max-abs-diff = 0.0 (exact equality, not fp tolerance) for `scalar_add`, `scalar_mul` operations
(they're trivially deterministic when single-threaded scalar; Metal must match). Argmax tie-break must match
the scalar reference's first-index policy.

### §2.2 Track B — dispatch performance

`XCTest` at `EpistemosTests/ControllerKernelPackPerfTests.swift`:

```swift
// Each kernel runs in a tight loop; measure per-call dispatch overhead.
for kernel in ControllerKernel.all {
    let latencies = (0..<1000).map { _ in
        let t0 = ContinuousClock.now
        try await kernel.dispatch(buffer: buf, scalar: scalar)
        return Double((ContinuousClock.now - t0).components.attoseconds) / 1e12  // µs
    }

    let p99 = latencies.percentile(0.99)
    XCTAssertLessThan(p99, 50.0,
        "F-ControllerKernelPack FAILED: \(kernel.name) p99 = \(p99) µs ≥ 50 µs budget")
}

// Sequence test: dispatch all 6 kernels in sequence over a 4096-element buffer.
let t0 = ContinuousClock.now
for _ in 0..<100 {
    scalar_add_in_place_metal(buf, 0.1)
    scalar_mul_in_place_metal(buf, 1.1)
    let _ = max_reduce_metal(buf)
    let _ = argmax_reduce_metal(buf)
    copy_range_metal(dst, src, 4096)
    zero_fill_metal(buf)
}
let sequenceWall = (ContinuousClock.now - t0).components.attoseconds / 1e12
XCTAssertLessThan(sequenceWall, 30_000.0,
    "F-ControllerKernelPack FAILED: 100-iteration sequence wall = \(sequenceWall) µs ≥ 30 ms (300 µs / iteration)")
```

Acceptance: per-kernel p99 < 50 µs AND 100-iteration full-sequence wall < 30 ms (300 µs per controller-cycle
of 6 kernels).

## §3. M2 Pro 16 GB budget

| Metric | Budget |
|---|---|
| Per-kernel p99 (4096-element buffer) | < 50 µs |
| Per-kernel p50 (4096-element buffer) | < 20 µs |
| Sequence wall (6 kernels × 100 iters) | < 30 ms (= 300 µs per cycle) |
| Correctness | bit-for-bit equality (Metal vs scalar reference) |

The 50 µs per-kernel budget aligns with the V6.1 "Attention as Interrupt" doctrine — the controller path
should not be a per-token bottleneck.

## §4. Measurement methodology

- Fixed-seed fixtures across 7 array sizes (1, 16, 64, 256, 1024, 4096, 16384) to catch size-dependent kernel
  bugs (warp-size boundary at 32, threadgroup at 256, etc.).
- 100 warmup + 1000 timed iterations per kernel.
- Median-of-3 runs absorbs Metal dispatch noise.
- Spotlight off on `target/`; CPU governor pinned high-performance.
- Per-kernel results logged in `target/F-ControllerKernelPack/results.json` for trend tracking across runs.

## §5. Fallback if the gate fails

1. **Correctness fails on `max_reduce` / `argmax_reduce`**:
   - Most likely: parallel reduction order differs from scalar (Metal SIMD reduces in tree-order;
     argmax tie-break may pick a different "first" index).
   - **Tier 1**: pin the SIMD reduction to one-thread-per-buffer (slow but order-deterministic).
   - **Tier 2**: change scalar reference to match parallel-reduction order (acceptable only if the change is
     documented and tests are updated).
2. **Performance fails on small arrays (≤ 64 elements)**:
   - Dispatch overhead dominates for small buffers. This is expected at very small sizes; the gate's budget
     applies at 4096 elements (the canonical controller-path size).
3. **Performance fails at 4096 elements**:
   - Threadgroup size needs tuning. Sweep {32, 64, 128, 256}.
   - For `copy_range` + `zero_fill`: use `MTLBlitCommandEncoder.copy` and `fill` instead of compute dispatch.
     These primitives are highly optimized for bulk operations.
4. **STALLED**: file STALLED row #19 in canonical-doctrine §5 + BLOCKER. Don't push.

## §6. Acceptance bar

- [ ] Track A correctness: all 6 kernels match scalar reference bit-for-bit across 7 array sizes × 100 seeds.
- [ ] Track B performance: per-kernel p99 < 50 µs at 4096 elements; p50 < 20 µs.
- [ ] Sequence wall: 6-kernel × 100-iteration sequence < 30 ms.
- [ ] argmax tie-break: matches first-index policy of scalar reference.
- [ ] max_reduce on empty input: surfaces NaN (no silent zero-return).
- [ ] Reproducibility: same seeds produce same results across 3 runs.
- [ ] `cargo test` ≥ baseline + new tests. `xcodebuild test` clean.
- [ ] Doctrine doc §5 register row #19 status updates from `scaffolded` → `landed`.
- [ ] `Co-Authored-By: Codex (T3)` on every commit.

## §7. Dependencies + downstream gates

**Depends on**:

- F-PageGather-M2Pro (gate #5) PASS — shared kernel-dispatch infrastructure on Metal.
- F-PacketRouter1bit-Dispatch (gate #10) PASS — confirms Metal dispatch overhead is bounded; this gate
  inherits the same expectation.
- CPU reference: `agent_core/src/helios/controller_pack.rs` (343 LOC; all 6 functions exposed).
- (Metal kernel pack stub: lands as `Epistemos/Shaders/ControllerKernelPack.metal` in Phase C.)

**Unblocks**:

- Gate #12 F-70B-Local-Cocktail-Composition (controller path is in every model's hot loop).
- Mamba-2 + RWKV-7 controller-path optimization (general SSM family value).
- Any small-state inference loop that runs many micro-ops per token (this is the load-bearing primitive).

## §8. Cross-references

- Canonical doctrine: §4 ladder + §5 register row #19.
- Substrate-floor audit: §B.1 row 5.
- Driver authority: §4.G ladder gate #11 + Helios v6.2 §5.
- CPU reference: `agent_core/src/helios/controller_pack.rs` (with all 6 functions documented in the module
  comment).
- Mamba-2 controller path discussion: Dao & Gu arXiv:2405.21060.
- Cognitive DAG controller-side analog (different layer): `agent_core/src/cognitive_dag/dispatch.rs`.
