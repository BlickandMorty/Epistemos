---
state: falsifier
gate: F-PacketRouter1bit-Dispatch
ladder_position: 10 (after F-LocalRecallIsland-32K, before F-ControllerKernelPack)
owner: T3
created_on: 2026-05-17
authority: docs/CODEX_DEEP_INVESTIGATION_PROMPT_2026_05_16.md §4.G falsifier ladder (LOCK)
target_phase: Phase C
target_rig: M2 Pro 16 GB
---

# F-PacketRouter1bit-Dispatch

> Gate #10 in the §4.G falsifier ladder. **Ternary fire/suppress/defer router p99 dispatch latency under
> target on M2 Pro.** Helios v6.2 §4 acceptance: **P99 < 100 µs on M2 Pro 16 GB** across a 100k-element batch.

## §1. Why this gate exists

The §4.G hierarchy puts kernels under Shadow-first paging. The PacketRouter1bit is the dispatch primitive that
routes each input through one of two execution lanes — the kernel-level analog of the AAR's packet selection
(gate #6). Without bounded p99 dispatch latency, "active assembly" buckles under load: when the router takes
longer than the kernel it dispatches to, the substrate-level guarantee is hollow.

Driver §4.G prose + Helios v6.2 §4 acceptance:

> PacketRouter1bit.metal dispatch P99 < 100 µs on M2 Pro 16 GB.

CPU reference at `agent_core/src/helios/packet_router.rs` (439 LOC) implements `route_1bit` + `unroute_1bit`
with the dispatch semantics. The Metal stub lives at `Epistemos/Shaders/PacketRouter1bit.metal`. This gate
lands the production Metal kernel + harness.

## §2. The kernel under test

Given a batch of N input values + N decision bits, route each input to lane 0 (bit clear) or lane 1
(bit set); pack the per-lane outputs tightly so downstream kernels see contiguous memory.

```text
for i in 0..N:
  if decision_bit[i] == 0:
      lane_0.push(input[i])
  else:
      lane_1.push(input[i])
```

Two production variants:

- **Ternary extension** (`route_ternary`): three-way fire / suppress / defer using two decision bits per input.
  Same dispatch primitive, larger output buffer. Production substrate uses the ternary variant; the gate
  measures both.
- **Inverse pass** (`unroute_1bit` / `unroute_ternary`): reassemble per-lane outputs back into the original
  batch order. Required for any model whose downstream layers expect batch-order tensors.

## §3. Pass/fail recipe (the test that decides)

Swift integration test at `EpistemosTests/PacketRouter1bitDispatchTests.swift`:

```swift
let batchSize = 100_000
let inputs = (0..<batchSize).map { Float($0) }
let decisions = (0..<batchSize).map { Bool.random() }   // 50/50 lane distribution

// Warm up
for _ in 0..<100 { _ = try await PacketRouter.dispatch1bit(inputs, decisions) }

// Timed iterations
var latencies: [Double] = []
for _ in 0..<1000 {
    let t0 = ContinuousClock.now
    _ = try await PacketRouter.dispatch1bit(inputs, decisions)
    let dt = ContinuousClock.now - t0
    latencies.append(dt.components.attoseconds / 1e12)  // µs
}

let p99 = latencies.percentile(0.99)
let p50 = latencies.percentile(0.50)

XCTAssertLessThan(p99, 100.0,
    "F-PacketRouter1bit-Dispatch FAILED: p99 = \(p99) µs ≥ 100 µs budget")

// Correctness: random-decision routing reconstructs to identity through dispatch + unroute
let routed = try await PacketRouter.dispatch1bit(inputs, decisions)
let reconstructed = try await PacketRouter.unroute1bit(routed, decisions)
XCTAssertEqual(reconstructed, inputs,
    "F-PacketRouter1bit-Dispatch FAILED: dispatch + unroute is not identity")
```

Two assertions: latency gate (P99 < 100 µs) and correctness gate (dispatch + unroute = identity). Both must
pass.

### §3.1 Lane-distribution sweep

The 50/50 lane distribution is the canonical baseline. The harness also runs:

- 10/90 (skewed; tests imbalance-tolerance)
- 90/10 (skewed; mirror image)
- 100/0 + 0/100 (degenerate; one lane gets the whole batch)

Per-distribution p99 must be < 150 µs (looser than baseline because skewed cases have inherent dispatch
inefficiency). Baseline 50/50 must be < 100 µs.

## §4. M2 Pro 16 GB budget

| Variant | Distribution | p50 budget | p99 budget |
|---|---|---|---|
| 1-bit | 50/50 | < 50 µs | < 100 µs |
| 1-bit | 10/90 or 90/10 | < 80 µs | < 150 µs |
| 1-bit | 100/0 or 0/100 | < 60 µs | < 120 µs |
| Ternary | uniform 33/33/33 | < 70 µs | < 130 µs |
| Inverse (unroute) | symmetric to forward | matches forward p50 | matches forward p99 |

Memory: ~4 MB working set (100k × 4 bytes per fp32 input + 100k × 1 bit decisions = 400 KB).

## §5. Measurement methodology

- `cargo test` (Rust CPU-reference twin) AND `xcodebuild test` (Metal kernel measurement). Both must pass.
- Median-of-3 runs absorbs Metal-dispatch noise.
- ContinuousClock or `mach_absolute_time`; converted to µs.
- Spotlight off on `target/`; CPU governor pinned high-performance.
- Decision-bit seeds are deterministic for reproducibility.

## §6. Fallback if the gate fails

1. **p99 exceeds 100 µs**:
   - **Tier 1 — threadgroup size sweep**: try 16/32/64/128. M2 Pro typically prefers 32 or 64 for
     memory-bound kernels.
   - **Tier 2 — fused dispatch + scan**: replace two-pass (count-then-write) with single-pass atomic
     scattering. Atomics on Metal are slow but can win at small N.
   - **Tier 3 — lane prefix-scan precompute**: precompute the per-lane offset arrays on CPU; kernel just writes
     to the destination slot (one indexed-store per input, no atomics, no count pass).
   - **Tier 4 — STALLED** if no tier works: file STALLED row #18 in canonical-doctrine §5 + BLOCKER.
2. **Dispatch + unroute fails identity**:
   - Off-by-one in the lane-offset arithmetic. Bisect on decision-bit pattern.
   - Concurrency hazard in the lane-write step (race condition between two threads claiming the same lane
     slot). Add a Metal memory barrier between count and write phases.

## §7. Acceptance bar

- [ ] 50/50 distribution: p99 < 100 µs, p50 < 50 µs, dispatch+unroute = identity.
- [ ] 10/90 / 90/10 / 100/0 / 0/100 distributions all pass §4 budgets.
- [ ] Ternary variant: p99 < 130 µs at 33/33/33 distribution.
- [ ] Reproducibility: same seeds produce same latency stats within 5% across 3 runs.
- [ ] `cargo test` ≥ baseline + new tests. `xcodebuild test` clean.
- [ ] Doctrine doc §5 register row #18 status updates from `scaffolded` → `landed`.
- [ ] `Co-Authored-By: Codex (T3)` on every commit.

## §8. Dependencies + downstream gates

**Depends on**:

- F-PageGather-M2Pro (gate #5) PASS — bandwidth substrate; if page-gather is bottlenecked, this gate
  will be too (they share the kernel-dispatch infrastructure).
- CPU reference: `agent_core/src/helios/packet_router.rs` (439 LOC; route_1bit / unroute_1bit).
- Metal stub: `Epistemos/Shaders/PacketRouter1bit.metal`.

**Unblocks**:

- Gate #11 F-ControllerKernelPack (similar Metal-dispatch profile; if router can hit p99 < 100 µs, controller
  pack can too).
- Gate #12 F-70B-Local-Cocktail-Composition (the cocktail's "ternary kernel lane" component dispatches through
  this router).
- Ternary inference path wire-in to MLX-Swift (§4.E Phase C.8): the production model dispatch sits on this
  primitive.

## §9. Cross-references

- Canonical doctrine: §4 ladder + §5 register row #18.
- Substrate-floor audit: §B.1 row 4.
- Driver authority: §4.G ladder gate #10 + Helios v6.2 §4.
- MoE primary: Shazeer et al. arXiv:1701.06538 (Outrageously Large Neural Networks / Sparsely-Gated MoE).
- Switch Transformer (top-1 routing): Fedus et al. arXiv:2101.03961.
- CPU reference: `agent_core/src/helios/packet_router.rs`.
- Metal stub: `Epistemos/Shaders/PacketRouter1bit.metal`.
- Cognitive-DAG dispatch analog (different layer, same idea): `agent_core/src/cognitive_dag/dispatch.rs`.
