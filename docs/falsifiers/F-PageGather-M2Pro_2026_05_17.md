---
state: falsifier
gate: F-PageGather-M2Pro
ladder_position: 5 (after F-ShadowFirst-PageEscalation, before F-ActiveAssembly-Minimal)
owner: T3
created_on: 2026-05-17
authority: docs/CODEX_DEEP_INVESTIGATION_PROMPT_2026_05_16.md §4.G falsifier ladder (LOCK)
target_phase: Phase B.G.B5
target_rig: M2 Pro 16 GB (canonical ship target)
phase2_terminal_f_status: FALLBACK WITNESS (CPU scalar baseline) — primary Metal gate pending W-41
phase2_terminal_f_artifact: artifacts/falsifiers/page_gather/result.json
phase2_terminal_f_harness: agent_core/src/bin/falsify_page_gather.rs
phase2_terminal_f_caveat: CPU scatter benchmark over 16/64/256 MB working sets via `helios::page_gather::gather` (not the Metal scatter kernel). The artifact records CPU-bound sustained GB/s; this is NOT the 70%-of-STREAM-on-Metal bar. Full gate requires Metal kernel + STREAM-on-Metal triad baseline (W-41).
phase2_terminal_f_audit_doc: docs/audits/FALSIFIER_M2PRO_5_PASS_2026_05_23.md
metal_preflight_status: runtime dispatch/equivalence smoke test added in EpistemosTests/MetalWitnessGatesTests.swift; 2026-05-27 256 MB sustained witness failed the primary bandwidth ratio and is recorded at artifacts/falsifiers/page_gather/metal_failure_result.json; packetized scheduled PageGather now crosses the 0.70x STREAM mitigation floor at 256/512 MB in artifacts/falsifiers/page_gather/locality_probe_result.json, F-PageGather-Packetized-Caller proves one Vault retrieval trace consumes packets before dense restore, and F-PageGather-Packetized-Policy-Acceptance accepts that packet route only for retrieval/witness surfaces; dense restore remains pending
---

> **2026-06-01 current canon bridge (JUNE1-PATTERNBOOST-LOCK):** This file is preserved as a legacy, planning, research, or witness artifact. For active architecture, route Helios/UAS/ACS/mmap/KV-Direct/70B/NeuralImportance claims through `docs/fusion/RESIDENCY_PATTERNBOOST_DISCOVERY_2026_06_01.md`, `docs/falsifiers/F-RESIDENCY-PATTERNBOOST-BUNDLE_2026_06_01.md`, `docs/fusion/SEMANTIC_WORKING_SET_COMPILER_2026_06_01.md`, and `docs/fusion/COLDSTREAM_RESIDENCY_TRANSPORT_2026_06_01.md`. Legacy claims remain historical until promoted by falsifiers, AnswerPacket evidence, LatticeAbstentionGate, ComputeResumeLease, rollback, and the intentional-copy/zero-copy caveat.

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
  Shadow-first paging (#4) — main memory is — and the entire UAS/AcsAnchor hot path stalls.

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

Access classes:

- **Gather** (stage 1, easy case): `indices` is a contiguous prefix `[0, 1, 2, ...]`. Prefetcher-friendly.
- **LocalWindow / SparseScatter** (stage 2, product candidate): the page scheduler keeps the working set local
  enough that the Metal path can plausibly clear the bandwidth gate.
- **FullCoverageRandom** (failure stressor): `indices` is an arbitrary permutation of `0..source.len()`.
  The 2026-05-27 witness proved this is semantically useful but not product-green on the current shader.

The gate is the **locality-aware scatter** kernel — that's where the 70% target binds. Gather is expected to
hit closer to 100% of STREAM since it is the same access pattern STREAM measures. Full random permutation is
retained as an honest failure stressor, not as the required product layout.

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

Failure-stressor indices are drawn from a fixed-seed permutation so reruns are
deterministic. Product-candidate indices must also report their access class
from `PageGatherStats::access_class(...)` so a full-coverage random layout
cannot be mislabeled as a locality-aware pass.

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

### §4.1 2026-05-27 Metal failure evidence

`Tools/metal-witness-gates/page-gather-metal-artifact.swift` now runs the
Metal shader against an in-harness STREAM triad baseline.

The 256 MB required-size run was measured with:

```text
swift Tools/metal-witness-gates/page-gather-metal-artifact.swift --working-sets-mb 256 --window-seconds 5 --trials 3 --warmup-iterations 3 --write-artifact
```

Result: **FAIL**, recorded at
`artifacts/falsifiers/page_gather/metal_failure_result.json`.

The shader is correct (`0` sampled gather/scatter violations), but the current
one-thread-per-output scatter kernel does not meet the throughput floor:

- STREAM triad median: about `236 GB/s`.
- Sequential gather median: about `175 GB/s` (`0.74x` STREAM; below the `0.95x`
  gather bar).
- Random scatter median: about `15 GB/s` (`0.064x` STREAM; below the `0.70x`
  scatter bar).

Therefore `artifacts/falsifiers/page_gather/result.json` remains the CPU
fallback witness. The product-facing PageGather / Vault escalation UI must stay
orange/pending until a mitigation run clears the full 256/512/1024 MB gate.

### §4.2 2026-05-27 locality probe evidence

The same Swift harness now supports a diagnostic locality probe and a
packetized scheduled mitigation witness:

```text
swift Tools/metal-witness-gates/page-gather-metal-artifact.swift --probe-locality --working-sets-mb 256,512 --window-seconds 2 --trials 2 --warmup-iterations 1 --write-artifact
```

Result: **diagnostic failure report**, recorded at
`artifacts/falsifiers/page_gather/locality_probe_result.json`.

The primary dense-restore gate still fails, and `F-PageGather-M2Pro` stays
pending. The probe is useful because it now separates four different facts:

| Axis | 256 MB ratio vs STREAM | 512 MB ratio vs STREAM | Correctness |
|---|---:|---:|---:|
| Sequential gather | `0.704x` | `0.725x` | `0` sampled violations |
| Full random scatter stressor | `0.069x` | `0.043x` | `0` sampled violations |
| Local-window scatter | `1.001x` | `1.038x` | `0` sampled violations |
| Dense block-sorted scheduled restore | `0.092x` | `0.058x` | `0` sampled violations |
| **Packetized scheduled PageGather** | **`0.729x`** | **`0.752x`** | **`0` sampled violations** |

The packetized scheduled kernel emits:

```text
packetValues[i] = source[execution_indices[i]]
packetLogicalPositions[i] = logical_positions[i]
```

This is the lean PageGather motion: recall is emitted as a compact packet stream
with witness coordinates, and dense logical-order restore is paid only by a
downstream projection that truly needs dense order. The result crosses the
`0.70x` mitigation floor at both M2 Pro working-set sizes named by the shader
budget (`256` and `512` MB), but it does **not** erase the dense-restore failure.
The product UI must therefore continue to show PageGather as orange/pending
until the caller path consumes packetized output or the dense restore path is
optimized and re-measured.

2026-05-27 caller-path update: `agent_core::helios::gather_packetized`,
`gather_block_sorted_packetized`, and `restore_packets` now encode the packet
contract on the Rust side. This does not flip the primary gate green; it removes
one orphan by giving product code a typed way to keep PageGather packetized
through retrieval and pay dense restore lazily.

2026-05-28 caller-path fallback witness:
`F-PageGather-Packetized-Caller` proves
`VaultStore::hybrid_search_with_trace` consumes retained-score PageGather
packets and defers dense restore. This moves one product-adjacent retrieval
surface onto the packetized path while leaving dense `F-PageGather-M2Pro` red.

2026-06-03 policy fallback witness:
`F-PageGather-Packetized-Policy-Acceptance` closes only the route-kernel
"accepted packet policy" row for retrieval/witness packet surfaces. It does not
promote dense PageGather primary throughput.

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
