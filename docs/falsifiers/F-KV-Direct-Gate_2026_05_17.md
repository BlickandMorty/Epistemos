---
state: falsifier
gate: F-KV-Direct-Gate
ladder_position: 7 (after F-ActiveAssembly-Minimal, before F-SemiseparableBlockScan-Correctness)
owner: T3
created_on: 2026-05-17
authority: docs/CODEX_DEEP_INVESTIGATION_PROMPT_2026_05_16.md §4.G falsifier ladder (LOCK)
target_phase: Phase C.G.C2
target_rig: M2 Pro 16 GB (canonical ship target)
---

# F-KV-Direct-Gate

> Gate #7 in the §4.G falsifier ladder. **Qwen 3 8B at 128k context, KV-Direct cold-spill to SSD: peak RAM
> under 13 GB on 16 GB rig, D_KL/token under threshold, decode speed ≥ 10 tok/s.**

## §1. Why this gate exists

§4.G classifies KV-Direct / L3 SSD Oracle as the LONG-TERM MEMORY PATH layer. The W8 Tier-1 KV-Direct gate
already lands at `agent_core/src/scope_rex/kv/direct_gate.rs`; this gate is the **full path proof**: at 128k
context (~16× typical chat), can the system spill cold KV pages to SSD without (a) exceeding the 13 GB RAM
ceiling, (b) drifting per-token KL above threshold, or (c) collapsing decode throughput below ship-relevant
levels?

If F-KV-Direct-Gate passes, the §4.G "long memory path" is real on the M2 Pro 16 GB ship rig. If it fails, the
substrate's 70B Cocktail composition target (#14, gate #12) is closed at the KV layer and the Capability
Ceiling cannot rest on KV-Direct.

Driver §4.G prose:

> **F-KV-Direct-Gate** — Qwen 3 8B at 128k context, KV-Direct cold-spill to SSD: peak RAM under 13 GB on
> 16 GB rig, D_KL/token under threshold, decode speed ≥ 10 tok/s.

## §2. The path under test

```
hot KV (recent tokens)        — RAM, fp16, fully attended
       ↓ ResidencyLease tier "warm"
warm KV (mid-context)         — RAM, INT8 residual + per-block scale
       ↓ ResidencyLease tier "cold"
cold KV (oldest tokens)       — SSD, mmap'd, paged on demand
       ↓ Shadow-first paging escalation policy decides which cold pages decode this token
```

Decode-time flow (per token):

1. Compute query for this token (in RAM, hot path).
2. Score query against hot KV (cheap full).
3. Score query against warm KV (INT8 dot-product, see Shadow-first paging gate #4).
4. Score query against cold KV sketches (mmap'd, hits page cache or SSD).
5. Promote top-k cold pages to warm (or directly decode if margin is small per F-ShadowFirst).
6. Compute attention weighted across hot + warm + (selected) cold.
7. Emit token; update KV with new K/V from this token; tier-eviction may push hot → warm → cold.

The Tier-1 W8 gate (already landed) covers steps 1-3. This Phase C gate (#7) covers steps 4-7.

## §3. Pass/fail recipe (the test that decides)

A Swift integration test in `EpistemosIntegrationTests/KVDirectColdSpillTests.swift` (Phase C.G.C2) drives the
full path on a real Qwen 3 8B model:

```swift
let model = try await MLXInferenceService.shared.load(
    spec: .qwen3_8b_int4_mlx(),
    config: .init(
        kvDirectMode: .coldSpillToSSD,
        residencyLeases: .threeTier(hot: 8_192, warm: 32_768, cold: .remaining),
        contextWindowTokens: 128_000
    )
)

let promptBytes = SyntheticPromptCorpus.build_128k_seeded(seed: 0xC0_05_15)
let referenceModel = try await MLXInferenceService.shared.load(
    spec: .qwen3_8b_int4_mlx(),
    config: .init(kvDirectMode: .ramOnlyDisabled, contextWindowTokens: 16_000)
)
let reference = try await referenceModel.generate(prompt: promptBytes.suffix(15_000), maxTokens: 256)

// Long-context run with cold-spill
let actual = try await measureWithRAM {
    return try await model.generate(prompt: promptBytes, maxTokens: 256)
}

// Metrics
let peakRamGB = actual.peakResidentBytes / 1_073_741_824.0
let klPerToken = klDivergencePerToken(reference.logits, actual.logits.suffix(256))
let decodeTokPerSec = Double(actual.tokensEmitted) / actual.elapsedSeconds

XCTAssertLessThan(peakRamGB, 13.0,
    "F-KV-Direct-Gate FAILED: peak RAM \(peakRamGB) GB ≥ 13 GB ceiling on 16 GB rig")
XCTAssertLessThan(klPerToken, 0.08,
    "F-KV-Direct-Gate FAILED: D_KL/token \(klPerToken) ≥ 0.08 (drift threshold)")
XCTAssertGreaterThanOrEqual(decodeTokPerSec, 10.0,
    "F-KV-Direct-Gate FAILED: decode speed \(decodeTokPerSec) tok/s < 10 tok/s")
```

Gate **fails** if any of the three assertions fails. Gate **passes** when peak RAM stays under 13 GB AND
KL/token stays under 0.08 AND decode throughput stays at or above 10 tok/s.

### §3.1 The drift-threshold question

The driver says "D_KL/token under threshold" without naming the number. The recommended threshold is **0.08**,
chosen so it is:

- Looser than F-ShadowFirst-PageEscalation's 0.06 (Shadow paging is upstream of KV-Direct in the hierarchy;
  the cold-spill path inherits some Shadow paging drift plus its own).
- Tighter than the F-70B-Cocktail's eventual composition budget (the cocktail gets to absorb additional drift
  from speculative decode + cloud cascade).
- Defensible against the reference: a 0.08 KL per token over 256 generated tokens corresponds to ~20 nats of
  cumulative divergence, well below the threshold where the actual generated text diverges semantically from
  the reference.

If the threshold needs revision, update `docs/fusion/UAS_ACS_CANONICAL_ARCHITECTURE_2026_05_16.md` §4 ladder
row #7 and this falsifier doc §3.1 together (single source of truth).

### §3.2 Reference setup

The reference is **Qwen 3 8B at 16k context, no KV-Direct, no cold-spill, full RAM**. The reference and the
gate's measurement consume the *same* trailing-15k window of the 128k prompt — the gate is asking *"does
cold-spill change what the model produces?"*, not *"does adding 113k tokens of prefix change what the model
produces?"* (the latter is a model-side question, out-of-scope).

## §4. M2 Pro 16 GB budget

| Metric | Budget |
|---|---|
| **Peak resident RAM** | < 13 GB (leaves ~3 GB for OS + Swift + Xcode test runner) |
| **D_KL/token** | < 0.08 (see §3.1 rationale) |
| **Decode throughput (steady-state, 200+ tokens)** | ≥ 10 tok/s |
| **First-token latency** | < 30 s (acceptable for the heavy prefill at 128k) |
| **SSD read bandwidth (informational)** | ≥ ~2 GB/s sustained (NVMe SSD on M2 Pro should easily exceed) |
| **PSI (page-fault rate)** | informational; high page-fault rate indicates the cold tier is too small or the warm tier too eager-to-evict |

## §5. Measurement methodology

This gate is the most operationally heavy in the ladder (live 8B model, 128k tokens, real SSD reads). The
methodology accounts for that:

### §5.1 Pre-run conditioning

- Free RAM check: `vm_stat` reports ≥ 14 GB free RAM at run start; abort if less (other processes are
  competing for the 13 GB budget).
- Disk free check: ≥ 8 GB free on the SSD for the cold KV pages (a 128k KV cache is ~6 GB for 8B model at
  bf16; INT8 + lattice compression shrinks it but the harness logs the actual on-disk footprint).
- Pre-flight: kill any other model load (e.g. concurrent xcodebuild Metal compilation).

### §5.2 RAM measurement

`mach_task_basic_info` polled at 100 ms cadence throughout the run. Peak is reported. Additionally, the harness
logs the *trajectory* (peak after prefill, peak during decode, peak at completion) so failures are localized
to a phase.

### §5.3 KL measurement

Per-token KL is `KL(softmax(reference_logits) || softmax(actual_logits))`. Computed over the trailing 256
emitted tokens (skip first 16 to avoid initial-token edge effects). Median, mean, p99 reported.

### §5.4 Throughput measurement

Steady-state decode speed = `(tokens_emitted - 16) / (elapsed_after_token_16 - elapsed_at_token_16)`. Skips the
first 16 tokens because they include pipeline-fill overhead.

### §5.5 Drift on smaller probes

If the live-8B run is impractical for iteration speed during development, the gate spec supports an
**intermediate probe**: same path, same metrics, but on Qwen 3 0.5B at 32k context. The intermediate probe
must pass with the same RAM-relative ceiling (< 13 GB / 16 GB = 81% on the small probe's rig-relative
ceiling) and KL/throughput thresholds before the full 8B-128k run is attempted.

## §6. Fallback if the gate fails

Per §4.G "No silent skips":

1. **Identify the failure mode**.
   - **peak_ram ≥ 13 GB**: tier policy is keeping too much warm. Investigate the residency-lease boundaries.
   - **kl_per_token ≥ 0.08**: cold-decode path is too lossy. Investigate the lattice-VQ residual codec or
     escalation thresholds (F-ShadowFirst-PageEscalation must pass first; if it does, the failure is in this
     gate's specific cold-path step).
   - **decode_throughput < 10 tok/s**: SSD-read bottleneck OR warm-tier rescore overhead. Profile.
2. **Mitigation tier** (least invasive first):
   - **Tier 1 — tier-boundary tune**: shrink warm-tier capacity from 32k to 16k tokens; let more KV cold-spill
     sooner. Trade-off: more cold-decode work per token.
   - **Tier 2 — codec swap on warm tier**: replace INT8 with Sherry 1.25-bit (register row #31) for a 6×
     compression boost. Re-measure KL.
   - **Tier 3 — page-gather scatter optimization**: the cold-decode path is page-gather-bound; if
     F-PageGather-M2Pro just barely passed (~70% threshold), pull more aggressive optimizations (`uint8`
     vector loads, CSR-style index reshape).
   - **Tier 4 — quantize KV at write time**: emit INT8 + per-block scale at K/V emission, never holding fp16
     KV. Sharply reduces RAM but raises KL; must rerun KL gate.
   - **Tier 5 — STALLED**: file STALLED row #11, #12, #13 in canonical-doctrine §5 + BLOCKER commit. Do not
     push. The downstream F-70B-Local-Cocktail-Composition gate (#12) inherits the STALLED.

## §7. Acceptance bar (gate-pass criteria)

The gate **passes** when ALL of the following are true on M2 Pro 16 GB:

- [ ] peak RAM < 13 GB during the full 128k-prefill + 256-token-decode run.
- [ ] D_KL/token < 0.08 against the 16k-context-no-cold-spill reference.
- [ ] decode throughput ≥ 10 tok/s steady state.
- [ ] First-token latency < 30 s (informational gate; doesn't fail the run but is logged).
- [ ] Intermediate probe (Qwen 3 0.5B / 32k) passes the same gates at the small-probe scale.
- [ ] Reproducibility: same prompt seed produces same peak-RAM / KL / throughput within 5% across 3 runs.
- [ ] `cargo test` count ≥ baseline + new tests. No regressions.
- [ ] `xcodebuild` clean on the Swift integration test.
- [ ] Doctrine doc §5 register row #11, #12, #13 (Unified Page Oracle / L3 SSD Oracle / KV-Direct Gate) status
  updates from `not yet` / `landed (Tier-1)` → `landed (full path)`.
- [ ] `Co-Authored-By: Codex (T3)` on every commit.

## §8. Dependencies + downstream gates

**Depends on**:

- Phase B.G.B1-B6 all pass (this is gate #7 — the entire Phase B substrate must be sound).
- Tier-1 W8 KV-Direct gate (already landed at `agent_core/src/scope_rex/kv/direct_gate.rs`).
- F-ShadowFirst-PageEscalation pass (cold-decode pages rely on the escalation policy).
- F-PageGather-M2Pro pass (cold-decode is page-gather-bound).
- Live model: Qwen 3 8B INT4 MLX bundle in `~/Library/Models/qwen3-8b-int4/`.
- SSD free space ≥ 8 GB for the cold KV cache file.

**Unblocks**:

- Gate #12 F-70B-Local-Cocktail-Composition (the cocktail's KV layer rests entirely on this gate).
- §4.E model gating liberation — Qwen 3 8B agent capability for power-users (once KV-Direct allows >32k
  context without OOM, the agent capability can be widened).

## §9. Cross-references

- Canonical doctrine: `docs/fusion/UAS_ACS_CANONICAL_ARCHITECTURE_2026_05_16.md` §4 ladder + §5 register
  rows #11, #12, #13.
- Substrate-floor audit: `docs/audits/UAS_ACS_SUBSTRATE_INVENTORY_2026_05_17.md` §A row #12 + §C gap list.
- Driver authority: `docs/CODEX_DEEP_INVESTIGATION_PROMPT_2026_05_16.md` §4.G ladder gate #7.
- Tier-1 W8 doctrine: `docs/HELIOS_V5_INTEGRATION_PLAN_v2_2026_05_05.md` §3 W8 +
  `docs/HELIOS_V5_INTEGRATION_PLAN_v2_FINALIZE_2026_05_05.md` §I.
- W8 active gate file: `agent_core/src/scope_rex/kv/direct_gate.rs`.
- Research-tier doctrine: `epistemos-research/src/kv_direct_gate.rs`.
- MASTER_FUSION cross-link: `docs/MASTER_FUSION_NO_COMPROMISE_2026_05_13.md` §3.3 (the KV-Direct gate row).
- Sherry 1.25-bit residual codec candidate: `agent_core/src/research/sherry_lattice/`.
- Active analog of KV cache: `Epistemos/Engine/MLXInferenceService.swift` (the live KV-cache substrate the
  test drives).
