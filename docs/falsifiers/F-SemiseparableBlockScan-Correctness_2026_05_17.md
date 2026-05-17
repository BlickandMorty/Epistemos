---
state: falsifier
gate: F-SemiseparableBlockScan-Correctness
ladder_position: 8 (after F-KV-Direct-Gate, before F-LocalRecallIsland-32K)
owner: T3
created_on: 2026-05-17
authority: docs/CODEX_DEEP_INVESTIGATION_PROMPT_2026_05_16.md §4.G falsifier ladder (LOCK)
target_phase: Phase C (after KV-Direct lands)
target_rig: M2 Pro 16 GB
---

# F-SemiseparableBlockScan-Correctness

> Gate #8 in the §4.G falsifier ladder. **Mamba-2 / SSD scan kernel matches reference scan numerically on a
> fixture corpus.** Two-track harness: Qwen transformer vs Mamba-2 on same long-context tasks.

## §1. Why this gate exists

§4.G F-SemiseparableBlockScan locks the Mamba-2 SSD (selective state-space duality) kernel against the
reference implementation. The current CPU scalar reference at `agent_core/src/helios/ssd_block_scan.rs`
(385 LOC) implements the per-timestep recurrence; this gate proves the Metal kernel matches it numerically
across a fixture corpus AND that the resulting Mamba-2 path is competitive with the Qwen transformer baseline
on long-context tasks.

Driver §4.G prose + Helios v6.2 §6 acceptance bar:

> SemiseparableBlockScan.metal correctness vs PyTorch `ssd_minimal.py` Listing 1 (acceptance: max-abs-diff ≤
> 1e-3 fp16 over 100 seeds).

## §2. The kernel under test

The per-timestep selective state-space recurrence (Mamba-2 SSD, scalar variant per `helios/ssd_block_scan.rs`):

```text
state[t] = a[t] * state[t-1] + b[t] * x[t]
y[t]     = c[t] * state[t]
```

The production kernel runs **per-channel** in parallel on Metal threads. "Semiseparable" naming comes from the
matrix-form rewrite where the matrix mapping `x → y` has a semiseparable structure (Dao & Gu 2024 §A).

## §3. Pass/fail recipe (the test that decides)

Two tracks:

### §3.1 Track A — Metal-vs-reference numerical equivalence

`#[test]` at `agent_core/tests/ssd_block_scan_correctness.rs`:

```rust
let fixtures = SsdScanFixtureCorpus::seeded(N_SEEDS = 100,
    timesteps = 512, channels = 64, fp16 = true);

for fixture in fixtures {
    let reference = ssd_block_scan_scalar(&fixture);   // helios::ssd_block_scan.rs
    let metal = ssd_block_scan_metal(&fixture);         // Phase C target

    let max_abs_diff = reference.iter().zip(metal.iter())
        .map(|(r, m)| (*r - *m).abs())
        .fold(0.0f32, f32::max);

    assert!(max_abs_diff <= 1e-3,
        "F-SemiseparableBlockScan-Correctness FAILED: seed={:?}, max_abs_diff={}",
        fixture.seed, max_abs_diff);
}
```

### §3.2 Track B — Two-track long-context comparison

Swift integration test at `EpistemosIntegrationTests/MambaVsQwenLongContextTests.swift`:

```swift
// Same prompt, two models.
let prompt = LongContextBenchmark.builder()
    .ruler(taskCategories: [.niah_single_1, .niah_multikey_1, .vt, .cwe], length: 32_000)
    .babiLong(reasoningDepth: 3, length: 32_000)
    .build()

let qwen = try await load(.qwen3_8b_mlx())
let mamba = try await load(.mamba2_2_8b_mlx())   // research-tier model bundle

let qwenResults = try await qwen.run(prompt, suite: .ruler_plus_babilong)
let mambaResults = try await mamba.run(prompt, suite: .ruler_plus_babilong)

// Mamba-2 acceptance: within 0.10 absolute accuracy of Qwen on RULER+BABILong at 32k.
XCTAssertLessThanOrEqual(
    qwenResults.weightedScore - mambaResults.weightedScore, 0.10,
    "F-SemiseparableBlockScan Track B FAILED: Mamba-2 accuracy gap = \(qwenResults.weightedScore - mambaResults.weightedScore)"
)

// Mamba-2 throughput acceptance: at least 2× faster than Qwen on the same prompt
// (the value proposition of linear scan).
XCTAssertGreaterThanOrEqual(
    mambaResults.tokensPerSec / qwenResults.tokensPerSec, 2.0,
    "F-SemiseparableBlockScan Track B FAILED: Mamba-2 throughput = \(mambaResults.tokensPerSec / qwenResults.tokensPerSec)× Qwen"
)
```

Gate **fails** if EITHER track fails. Track A is the substrate-correctness gate (matches the reference
numerically); Track B is the system-value gate (Mamba-2 actually delivers a long-context throughput win
without falling more than 10 absolute accuracy points behind transformer Qwen).

## §4. M2 Pro 16 GB budget

| Track | Metric | Budget |
|---|---|---|
| A | max-abs-diff (Metal vs scalar reference) | ≤ 1e-3 fp16 over 100 seeds |
| A | mean-abs-diff | ≤ 5e-5 (informational) |
| A | wall_us per scan (512 steps × 64 channels) | < 200 µs on Metal (informational; production target) |
| B | accuracy gap (Qwen - Mamba-2) | ≤ 0.10 weighted-score on RULER + BABILong subset |
| B | throughput ratio (Mamba-2 / Qwen) | ≥ 2.0× tokens/sec on 32k prompt |
| B | peak RAM | < 13 GB (same ceiling as F-KV-Direct-Gate) |

## §5. Measurement methodology

### §5.1 Track A — numerical equivalence

- Inputs are fp16 throughout (Metal hardware-native).
- Fixed seeds 0x550..0x5C3 (100 seeds).
- Inputs: `a`, `b`, `c` drawn from N(0, 1) clamped to [-2, 2] in fp16.
- `x` drawn from N(0, 1) in fp16.
- Initial state = 0.
- Reference: existing `agent_core/src/helios/ssd_block_scan.rs::ssd_scan_scalar` per Dao & Gu 2024
  `ssd_minimal.py` Listing 1.
- Metal kernel: per-channel parallel; result must match scalar within fp16-arithmetic tolerance.
- Report: per-seed max-abs-diff, mean-abs-diff; histogram across the 100 seeds.

### §5.2 Track B — long-context comparison

- RULER tasks: `niah_single_1`, `niah_multikey_1`, `vt` (variable tracking), `cwe` (common-word extraction).
  Per Hsieh et al. arXiv:2404.06654.
- BABILong reasoning depth = 3, context length = 32k. Per Kuratov et al. arXiv:2406.10149.
- Weighted score: equal weight per task (8 tasks: 4 RULER + 4 BABILong reasoning levels).
- Both models loaded in the same MLX-Swift session; cold-load for Qwen, then Mamba-2 (so Qwen's MLX cache is
  warm and the throughput comparison is conservative).
- Tokens-per-second measured over the steady-state generation phase (skip first 16 tokens).

### §5.3 Reproducibility

- Track A: `cargo test --release --test ssd_block_scan_correctness -- --nocapture` produces identical output
  on the same machine across runs.
- Track B: Swift integration test seeds the RULER + BABILong builders with fixed seed `0xC0_07_05`.
  Median-of-3 runs absorbs MLX dispatch noise.

## §6. Fallback if the gate fails

Per §4.G "No silent skips":

1. **Track A failure**:
   - Most common cause: precision drift in the per-channel parallel reduction (Metal SIMD reduction sums in a
     different order than the scalar reference).
   - **Tier 1**: switch the reference to fp32 internal accumulation (Metal kernel and scalar both); compare
     fp32 outputs. If gap closes, the Metal kernel is correct and the original test was over-strict on fp16
     reduction order.
   - **Tier 2**: pin the Metal SIMD reduction order via a one-thread-per-channel kernel (slower but
     order-deterministic). Reproduces scalar exactly.
   - **Tier 3**: if neither matches, the Metal kernel has a real bug — bisect on `timesteps` value to find
     the first step where divergence appears.
2. **Track B failure (accuracy gap)**:
   - Mamba-2 is intrinsically weaker on retrieval-heavy tasks (the known hybrid-architecture story per §3.41
     Nano Model Training Recipe). The 10-pt budget reflects this gap; if Mamba-2 is more than 10 pts behind,
     the model is broken, not the architecture.
   - **Tier 1**: try a different Mamba-2 checkpoint (the 2.8B Mamba-2 release vs the smaller variants).
   - **Tier 2**: STALLED — gate fails. Phase C composition (#12) can still proceed without Mamba-2 acting as
     a transformer replacement; it just means Mamba-2 is positioned as a *complement* (hybrid 75/25
     transformer/Mamba per §3.41).
3. **Track B failure (throughput)**:
   - Mamba-2 should be linearly faster than transformer at 32k. If it's not, the Metal kernel is leaving
     performance on the table.
   - **Tier 1**: profile the per-channel kernel; look for warp divergence or non-coalesced loads.
   - **Tier 2**: increase block size in the semiseparable structure (Mamba-2 block = 64 is the canonical
     value; pushing to 128 or 256 may help on M2 Pro's 32-wide SIMD).
   - **Tier 5**: STALLED if no kernel optimization recovers.

## §7. Acceptance bar (gate-pass criteria)

The gate **passes** when ALL of the following are true on M2 Pro 16 GB:

- [ ] Track A: max-abs-diff ≤ 1e-3 fp16 across 100 seeds. Mean-abs-diff ≤ 5e-5 (informational).
- [ ] Track B: accuracy gap (Qwen - Mamba-2) ≤ 0.10 weighted-score on RULER+BABILong subset.
- [ ] Track B: throughput ratio Mamba-2/Qwen ≥ 2.0× on 32k prompt.
- [ ] Reproducibility: identical Track A output across 3 runs; Track B within 5% across 3 runs.
- [ ] `cargo test` ≥ baseline + new tests. No regressions.
- [ ] `xcodebuild` clean.
- [ ] Doctrine doc §5 register row #17 status updates from `scaffolded` → `landed`.
- [ ] `Co-Authored-By: Codex (T3)` on every commit.

## §8. Dependencies + downstream gates

**Depends on**:

- CPU scalar reference: `agent_core/src/helios/ssd_block_scan.rs` (lands first; already exists per audit §B.1).
- Phase B gates 2-6 pass (Metal-dispatch overhead concern; F-PageGather provides bandwidth substrate).
- Mamba-2 2.8B MLX bundle in `~/Library/Models/mamba2-2_8b/` (research-tier model bundle).
- T5 coordination: Scan-IR substrate at `agent_core/src/research/scan_ir/` (gap; T5 owns) may provide
  generic SSM substrate that this gate reuses.

**Unblocks**:

- Gate #12 F-70B-Local-Cocktail-Composition (the cocktail's "Mamba-2 lane" component).
- §4.I EML-IR (Scan-IR primitive lands a kernel-doctrine substrate that this gate validates one consumer of).
- MASTER_FUSION §3.34 (Instant Recall — Mamba-2 state injection): once this gate passes, the state-injection
  path is a credible delivery vehicle for instant recall.

## §9. Cross-references

- Canonical doctrine: `docs/fusion/UAS_ACS_CANONICAL_ARCHITECTURE_2026_05_16.md` §4 ladder + §5 register
  row #17.
- Substrate-floor audit: `docs/audits/UAS_ACS_SUBSTRATE_INVENTORY_2026_05_17.md` §B.1 row 3.
- Driver authority: `docs/CODEX_DEEP_INVESTIGATION_PROMPT_2026_05_16.md` §4.G ladder gate #8.
- Mamba-2 SSD primary: Dao & Gu, "Transformers are SSMs: Generalized Models and Efficient Algorithms Through
  Structured State Space Duality", arXiv:2405.21060, 2024 (cited inline in `helios/ssd_block_scan.rs`).
- Mamba predecessor: Gu et al., "Mamba: Linear-Time Sequence Modeling with Selective State Spaces",
  arXiv:2312.00752, 2023.
- RULER: Hsieh et al. arXiv:2404.06654.
- BABILong: Kuratov et al. arXiv:2406.10149.
- §4.I EML-IR Scan-IR coordination: driver §4.I + T5 ownership.
- Helios v6.2 source: `docs/fusion/helios v6.2.md` 8-stage falsifier §6.
