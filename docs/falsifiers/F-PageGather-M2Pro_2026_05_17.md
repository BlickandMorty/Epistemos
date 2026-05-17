---
state: falsifier
gate: F-PageGather-M2Pro
ladder_position: 5 (after F-ShadowFirst-PageEscalation, before F-ActiveAssembly-Minimal)
owner: T3
created_on: 2026-05-17
authority: docs/CODEX_DEEP_INVESTIGATION_PROMPT_2026_05_16.md §4.G falsifier ladder (LOCK)
target_phase: Phase B.G.B5
target_rig: M2 Pro 16 GB (canonical ship target)
---

# F-PageGather-M2Pro

> Gate #5 in the §4.G falsifier ladder. **Metal page-sketch scoring sustains ≥ 70% of MEASURED M2 Pro
> streaming bandwidth (NOT theoretical 200 GB/s spec). 256/512/1024 MB buffers; 1 s+ windows.** Per V6.2
> 8-stage falsifier methodology.

## §1. Why this gate exists

Apple Silicon UMA gives the page-gather kernel a theoretical ceiling of 200 GB/s (LPDDR5X-7500 ×16), but the
MEASURED streaming bandwidth on an M2 Pro 16 GB rig — per STREAM-on-Metal microbenchmarks — is closer to
63-73 GB/s (see `agent_core/src/helios/mod.rs` lines 19-22). The §4.G ladder LOCKs the gate against the
MEASURED baseline because:

- Vendor-spec numbers do not survive thermal throttling, ANE/GPU contention, or working-set spillover.
- The 70% target is a load-bearing constraint: below this, the page-gather kernel is not the bottleneck of
  Shadow-first paging (#4) — main memory is — and the entire UAS-ACS hot path stalls.

Driver §4.G prose:

> **F-PageGather-M2Pro** — Metal page-sketch scoring sustains ≥ 70% of MEASURED M2 Pro streaming bandwidth (NOT
> theoretical 200 GB/s spec). 256/512/1024 MB buffers, 1 s+ windows. Per V6.2 M2 Pro methodology.

Cross-reference: `agent_core/src/helios/page_gather.rs` is the CPU scalar reference (342 LOC, lands the
PageGather scatter/gather semantics). `Epistemos/Shaders/PageGather.metal` is the GPU stub. Phase B.G.B5
lands the Metal kernel + Swift driver + harness that this gate exercises.

## §2. The kernel under test

```text
out[i] = source[indices[i]]   for i in 0..N
```

Two flavors:

- **Gather** (stage 1, easy case): `indices` is a contiguous prefix `[0, 1, 2, ...]`. Prefetcher-friendly.
- **Scatter** (stage 2, hard case): `indices` is an arbitrary permutation of `0..source.len()`. Random-access;
  fights the prefetcher.

The gate is the **scatter** kernel — that's where the 70% target binds. Gather is expected to hit closer to
100% of STREAM since it is the same access pattern STREAM measures.

## §3. Pass/fail recipe (the test that decides)

A Swift `XCTest` in `EpistemosTests/HeliosPageGatherBandwidthTests.swift` (lands in Phase B.G.B5) drives the
Metal kernel and records sustained throughput. The Rust side at `agent_core/tests/page_gather_m2pro.rs` is the
CPU-baseline twin:

```rust
// Rust-side: CPU baseline for cross-check
let stats_cpu = page_gather_scatter_bench(
    source_bytes = WORKING_SET,         // 256 MB, 512 MB, 1024 MB
    duration_secs = WINDOW_SECONDS,     // 1.0, 2.0, 5.0
    seed = 0xBA7AC15A,
);
```

```swift
// Swift-side: Metal kernel measurement (the gate)
let stats_metal = try await pageGatherMetalBenchmark(
    workingSet: bytes(256.MB),   // and 512.MB, 1024.MB
    windowSeconds: 1.0,           // and 2.0, 5.0
    accessPattern: .scatter
)

// 1. STREAM baseline (Triad: a[i] = b[i] + c * d[i])
let streamBaseline = try await streamOnMetalBaseline()

// 2. Compute MEASURED bandwidth (NOT vendor spec)
let measuredCeiling = streamBaseline.triadGBs   // ~63-73 GB/s on M2 Pro

// 3. Gate
XCTAssertGreaterThanOrEqual(
    stats_metal.sustainedGBs / measuredCeiling,
    0.70,
    "F-PageGather-M2Pro FAILED: scatter sustained \(stats_metal.sustainedGBs) GB/s = "
    + "\(stats_metal.sustainedGBs / measuredCeiling * 100)% of MEASURED ceiling "
    + "\(measuredCeiling) GB/s (target ≥ 70%)"
)
```

Gate **fails** if `sustained_scatter_gbs / measured_stream_triad_gbs < 0.70` at any of the three working-set
sizes.

### §3.1 Working-set ladder

| Working set | Why this size | Acceptance bar |
|---|---|---|
| **256 MB** | fits comfortably in M2 Pro 16 GB without eviction; pure-throughput case | ≥ 70% measured STREAM |
| **512 MB** | starts to compete with the AppKit working set; tests stability under modest pressure | ≥ 70% measured STREAM |
| **1024 MB** | the canonical Helios-spec working set; tests survival of TLB pressure + page fault | ≥ 70% measured STREAM |

The driver explicitly names "256/512/1024 MB buffers"; Terminal-B-style adaptation to 256/512 MB only is
permitted **as fallback** but the gate's true pass requires all three.

### §3.2 Indices distribution

Scatter indices are drawn from a `ChaCha20Rng` with the fixed seed `[0xBA, 0x7A, 0xC1, 0x5A, …]` so reruns are
deterministic. The permutation is a true random shuffle (Fisher-Yates) — not a deterministic-stride hash.

The same indices are reused for `Rust scalar` and `Metal kernel` runs so the comparison is apples-to-apples
on identical workloads.

## §4. M2 Pro 16 GB budget

| Metric | Budget |
|---|---|
| **Sustained scatter throughput** | ≥ 70% of MEASURED STREAM triad (i.e. ≥ ~44-51 GB/s if STREAM = 63-73 GB/s) |
| **Sustained gather throughput** | ≥ 95% of MEASURED STREAM triad (gather is the easy case; below 95% indicates kernel inefficiency) |
| **Window stability** | range(max, min) / mean over the 1 s+ window < 15% (no spikes/dips) |
| **Thermal stability** | second run within 5 s of first run holds ≥ 90% of first-run throughput (i.e. no major thermal throttling kicks in) |
| **Peak resident memory** | working_set + ~32 MB harness overhead |

## §5. Measurement methodology

This is the V6.2 M2 Pro methodology spelled out:

### §5.1 STREAM-on-Metal baseline

The measured-ceiling is computed every run, not hardcoded. The harness runs a Metal STREAM Triad
(`a[i] = b[i] + c * d[i]`) on the same working-set ladder, takes the median throughput of 5 trials, and
uses that as `measured_ceiling_gbs`. This insulates the gate from:

- Thermal state at run time (different days, different sustained throughputs)
- Kernel-version changes (macOS version bumps)
- AGX driver-side changes (graphics drivers regress)

The measured ceiling is logged with every gate run.

### §5.2 Timing window

Each measurement is a **sustained-throughput** value over a `WINDOW_SECONDS ≥ 1.0` window:

- The harness runs the scatter kernel in a tight loop.
- After 100 warmup iterations (discarded), the harness records start time.
- The kernel runs as many times as fit in `WINDOW_SECONDS`.
- Throughput = `(N_iterations × working_set_bytes) / WINDOW_SECONDS`.
- Three windows (1 s, 2 s, 5 s) — short window catches burst behavior, long window catches steady-state.

The gate's pass requires the **5-second window** to pass; 1 s and 2 s windows are diagnostic.

### §5.3 Thermal control

- The harness logs SoC temperature (via `IOServiceMatching("AppleSMC")` + `SMCKey("TC0F")`) before / during /
  after.
- If temperature delta over the run > 15°C, the run is flagged as thermal-questionable and rerun after 60 s
  idle.
- Median-of-3 runs absorbs residual thermal noise.

### §5.4 Background-noise control

- Spotlight off on `target/` directory (`mdutil -d`).
- Power mode = high performance (`pmset -a powermode 2`).
- No other Xcode build / cargo build active during the harness run (kill those processes first).
- Other terminals' worktrees pose no contention since their `target/` is distinct.

## §6. Fallback if the gate fails

Per §4.G "No silent skips":

1. **Identify the failure case**.
   - **Scatter < 70% but gather ≥ 95%**: random-access penalty is the bottleneck. The Metal kernel's memory
     access pattern is fighting the L2 cache and TLB. Mitigations are kernel-level.
   - **Scatter < 70% AND gather < 95%**: kernel inefficiency more general than scatter. Threadgroup sizing or
     SIMD-group utilization is wrong.
   - **Window-1s passes but window-5s fails**: thermal throttling. Mitigations are platform-level.
2. **Mitigation tier** (least invasive first):
   - **Tier 1 — threadgroup tune**: sweep `threadgroup_size ∈ {16, 32, 64, 128, 256}`. M2 Pro's preferred size
     for memory-bound kernels is usually 32 or 64.
   - **Tier 2 — vector width**: switch from `uint` index loads to `uint4` (4-wide) or `uint8` vector loads;
     dispatch fewer threadgroups but more work per thread.
   - **Tier 3 — prefetch hints**: insert `prefetch` instructions before the scatter load (Metal Shading
     Language `metal::prefetch`).
   - **Tier 4 — index-pattern reshape**: pre-sort scatter indices into blocks of contiguous chunks
     (CSR-style); the kernel reads block-contiguous and the indirection is in the block header. Significantly
     more complex but recovers a lot of the gather-vs-scatter penalty.
   - **Tier 5 — STALLED**: file STALLED row #10 + #42 in canonical-doctrine §5 + BLOCKER commit. Do not push.
3. **Document the mitigation** on the Metal source: `// F-PageGather-M2Pro: threadgroup_size=64 + uint4 vector
   load lifts scatter to 72% of STREAM; see docs/falsifiers/F-PageGather-M2Pro_2026_05_17.md §6.`

## §7. Acceptance bar (gate-pass criteria)

The gate **passes** when ALL of the following are true on M2 Pro 16 GB:

- [ ] `sustained_scatter_gbs / measured_stream_triad_gbs ≥ 0.70` at all three working-set sizes (256, 512,
  1024 MB) over the 5-second window.
- [ ] `sustained_gather_gbs / measured_stream_triad_gbs ≥ 0.95` at all three working-set sizes (gather is the
  easy case).
- [ ] Window stability `range/mean < 15%` over the 5 s window.
- [ ] Thermal stability: second consecutive run holds ≥ 90% of first run.
- [ ] STREAM-on-Metal baseline logged with the run (so the ratio is grounded in MEASURED, not VENDOR-SPEC).
- [ ] Reproducibility: median-of-3 runs within 5% on throughput.
- [ ] `cargo test` count ≥ baseline + new tests. No regressions.
- [ ] `xcodebuild` clean on the Swift driver side.
- [ ] Doctrine doc §5 register row #9, #10, #11, #42 status updates from `scaffolded` → `landed`.
- [ ] `Co-Authored-By: Codex (T3)` on every commit.

## §8. Dependencies + downstream gates

**Depends on**:

- Phase B.G.B2 F-UAS-ZeroCopy-Spine: the IOSurface-backed working-set buffer is a zero-copy hot path; failed
  zero-copy will be the first thing to investigate if bandwidth tanks.
- Phase B.G.B4 F-ShadowFirst-PageEscalation: the escalation policy's cost model assumes this gate passes;
  without it, the policy is over-optimistic on cheap-path savings.
- Existing infrastructure: `agent_core/src/helios/page_gather.rs` (CPU reference; the Metal kernel must match
  it bit-for-bit within fp32 tolerance on fixed-seed inputs).

**Unblocks**:

- Gate #6 F-ActiveAssembly-Minimal (active-pull selector dispatches through page-gather for its packet reads).
- §4.H F-VaultRecall-50 retrieval bandwidth (Halo/Shadow search uses the same kernel family).
- All Phase C kernel gates (F-LocalRecallIsland, F-SemiseparableBlockScan, F-PacketRouter1bit,
  F-ControllerKernelPack) which share the Metal-dispatch-overhead concern this gate isolates.

## §9. Cross-references

- Canonical doctrine: `docs/fusion/UAS_ACS_CANONICAL_ARCHITECTURE_2026_05_16.md` §4 ladder + §5 register
  rows #9, #10, #11, #42.
- Substrate-floor audit: `docs/audits/UAS_ACS_SUBSTRATE_INVENTORY_2026_05_17.md` §B.1 + §C gap list.
- Driver authority: `docs/CODEX_DEEP_INVESTIGATION_PROMPT_2026_05_16.md` §4.G ladder gate #5.
- V6.2 M2 Pro methodology: `docs/fusion/helios v6.2.md` 8-stage falsifier §1-§2.
- STREAM benchmark: McCalpin J. D., "Memory bandwidth and machine balance in current high performance
  computers", IEEE TCCA newsletter Dec 1995 (cited inline in `agent_core/src/helios/page_gather.rs`).
- CPU reference: `agent_core/src/helios/page_gather.rs` (342 LOC) — the Metal kernel must match this
  bit-for-bit on fixed-seed inputs.
- Metal stub: `Epistemos/Shaders/PageGather.metal` (per helios mod.rs line 16; Phase B.G.B5 lands the real
  kernel).
