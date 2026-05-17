---
state: falsifier
gate: F-70B-Local-Cocktail-Composition
ladder_position: 12 (the ceiling falsifier — last gate in the §4.G ladder)
owner: T3
created_on: 2026-05-17
authority: docs/CODEX_DEEP_INVESTIGATION_PROMPT_2026_05_16.md §4.G falsifier ladder (LOCK)
target_phase: Phase C (research-only — Capability Ceiling tier)
target_rig: M2 Pro 16 GB (composition feasibility) + M2 Max 64 GB / cloud cascade (research extensions)
posture: RESEARCH-ONLY · NOT PRODUCT · tagged C/Vault per §4.G "Tagged C/Vault, not product"
---

# F-70B-Local-Cocktail-Composition

> Gate #12 in the §4.G falsifier ladder — the **ceiling falsifier**. **Compose ternary + Mamba-2 + KV-Direct +
> PageGather + active assembly + speculative decode + cloud cascade.** Prove the cocktail composes: memory
> stays under budget, generation does not collapse, bottleneck is identified.
>
> **This is a research falsifier. NOT a product promise.** Tagged C/Vault per driver §4.G "Tagged C/Vault, not
> product." The point is **substrate composition feasibility**, not "run 70B perfectly NOW."

## §1. Why this gate exists

§4.G's Capability Ceiling tier (residency-tier table row 3) is real research substrate that does not ship to
MAS without an explicit promotion decision. The cocktail composition is the umbrella research target — it asks
whether the seven substrate primitives (ternary kernels, Mamba-2 SSM, KV-Direct cold-spill, PageGather scatter,
active assembly selector, speculative decode, cloud cascade) **compose** rather than merely existing in
isolation.

If they compose, the §4.G "Verified Floor" can be honestly described as "everything beneath this gate works
in concert at the Capability-Ceiling scale." If they don't, the §4.G hierarchy has a fundamental composition
flaw and at least one layer needs rework.

Driver §4.G prose:

> **F-70B-Local-Cocktail-Composition** — the ceiling falsifier. Compose ternary + Mamba-2 + KV-Direct +
> PageGather + active assembly + speculative decode + cloud cascade. Not "run 70B perfectly NOW" — prove the
> cocktail composes: memory stays under budget, generation does not collapse, bottleneck is identified.
> Tagged C/Vault, not product.

### §1.1 What this gate is NOT

- This gate is **NOT** "run a 70B model on the laptop." That is engineering, not science. If 70B-on-laptop
  becomes a product claim, it lands via a separate `F-70B-MAS-Ship` gate that does NOT exist yet and is
  explicitly out-of-scope for the current §4.G work.
- This gate is **NOT** a benchmark of LLM quality. The cocktail's loss / accuracy / KL drift are reported as
  diagnostics, not pass/fail.
- This gate is **NOT** a wall-clock latency target. Decode throughput is reported but not the gate.

### §1.2 What this gate IS

A **composition-feasibility study**. The output is a research-tier doc + harness that answers four questions:

1. Can all seven layers run in the same process without panic, memory-OOM, or substrate corruption?
2. Does memory stay under the **published budget** (10.5 GB on M2 Pro 16 GB; 60 GB on M2 Max 64 GB)?
3. Does generation produce coherent output for ≥ 256 tokens (no collapse-into-repetition or NaN propagation)?
4. **What is the bottleneck?** The deliverable is identifying which of the seven layers limits the
   composition, so the next iteration of the §4.G work knows where to push.

## §2. The seven cocktail components

| # | Layer | Falsifier (must pass first) | M2 Pro role |
|---|---|---|---|
| 1 | Ternary kernel lane | research-tier; supported by F-PacketRouter1bit (#10) | weight compression substrate for non-controller layers |
| 2 | Mamba-2 SSM track | F-SemiseparableBlockScan-Correctness (#8) PASS | controller half of hybrid (75/25 transformer/Mamba per §3.41) |
| 3 | KV-Direct cold-spill | F-KV-Direct-Gate (#7) PASS | long-memory path for transformer half |
| 4 | PageGather scatter | F-PageGather-M2Pro (#5) PASS | bandwidth substrate for cold-decode + sketch routing |
| 5 | Active assembly selector | F-ActiveAssembly-Minimal (#6) PASS | top-level routing: which packets fire per token |
| 6 | Speculative decode | (no upstream gate; produced by this study) | draft model + verify pass for throughput |
| 7 | Cloud cascade | (no upstream gate; produced by this study) | fallback to provider API when local cocktail can't satisfy |

Of the seven, components 1-5 are gated by upstream falsifiers in the ladder. Components 6-7 are studied
here as part of this gate (speculative-decode pairing with hybrid + cloud-cascade trigger thresholds are
research outputs of this gate, not pre-conditions).

## §3. Pass/fail recipe (the test that decides)

This gate is **operationally heavy**. The harness lives in `agent_core/tests/cocktail_composition_study.rs`
+ Swift integration test driving live MLX-Swift bundles.

```rust
// Substrate-floor study: synthetic composition without live model.
let synthetic = SyntheticCocktail::build(
    components = AllSevenLayers::default(),
    tokens_target = 256,
    seed = 0xCEFAEEEE
);
let report = synthetic.run()?;

assert!(report.no_panic_no_oom_no_corruption,
    "F-70B-Cocktail-Composition FAILED: substrate-floor synthetic crashed");
assert!(report.bottleneck_identified.is_some(),
    "F-70B-Cocktail-Composition FAILED: study did not localize bottleneck");

// Live-model study (M2 Pro 16 GB)
let live = LiveCocktail::build(
    transformer_bundle = "qwen3_8b_int4_mlx",
    mamba_bundle = "mamba2_2_8b_int4_mlx",
    ternary_kernels = TernaryKernels::default(),
    kv_direct = KvDirect::cold_spill(),
    page_gather = PageGather::metal_scatter(),
    selector = MarginAnchoredGreedyPull::default(),
    speculative_decode = Some(SpeculativeDecode::draft_with(qwen3_0_5b)),
    cloud_cascade = CloudCascade::on_uncertainty_above(0.3),
    token_budget = 256,
);
let live_report = live.run_on(prompt: PROMPT_32K, max_tokens: 256)?;

// Three gates
assert!(live_report.peak_ram_gb < 13.0,
    "F-70B-Cocktail-Composition FAILED: peak RAM {} GB ≥ 13 GB (M2 Pro budget)",
    live_report.peak_ram_gb);

assert!(!live_report.generation_collapsed,
    "F-70B-Cocktail-Composition FAILED: generation collapsed at token {}",
    live_report.collapse_token.unwrap_or(0));

assert!(live_report.bottleneck_identified.is_some(),
    "F-70B-Cocktail-Composition FAILED: live study did not identify bottleneck");
```

Gate **passes** when:

- Substrate-floor synthetic study runs end-to-end without panic / OOM / corruption.
- Live-model study completes 256 tokens of generation under the 13 GB RAM ceiling.
- Generation does not collapse (no repetition-loop, no NaN, no early-truncation due to budget).
- A primary bottleneck is identified (which of the 7 components is the binding constraint) and documented in
  the research doc.

**Critical: this gate explicitly DOES NOT require the cocktail to outperform individual components**.
It requires the cocktail to *compose*.

### §3.1 Collapse detection

"Generation collapsed" means any of:

- Repetition: the same n-gram (n ≥ 4) appears > 5× in the 256-token output.
- NaN: any NaN appears in logits, KV cache, or scan state.
- Early truncation: generation halts before 256 tokens for a budget-not-quality reason (OOM, dispatch error,
  substrate panic).
- Diverged from reference: cumulative KL/token vs the cloud reference > 1.0 over 256 tokens (this is loose —
  the cocktail is expected to drift, but not infinitely).

### §3.2 Bottleneck identification

The harness instruments per-component:

- Time spent in each layer (wall-clock budget breakdown)
- Memory used by each layer (resident-bytes attribution)
- Latency p99 per per-token operation in each layer
- Throughput impact when each layer is bypassed (e.g. cocktail-without-speculative-decode vs full)

The deliverable is a research doc identifying ONE primary bottleneck (the layer that, if 2× faster, would
unlock the most cocktail throughput) and ranking the remaining six.

## §4. Budget table (informational; not pass/fail)

| Metric | Budget (informational) |
|---|---|
| Peak RAM (M2 Pro 16 GB) | < 13 GB (GATE) |
| Peak RAM (M2 Max 64 GB) | < 60 GB |
| Generation length without collapse | ≥ 256 tokens (GATE) |
| Bottleneck identification | required (GATE) |
| Decode throughput (M2 Pro 16 GB) | ≥ 5 tok/s informational |
| Decode throughput (M2 Max 64 GB) | ≥ 20 tok/s informational |
| Cumulative KL/token vs cloud reference | < 1.0 informational |
| Speculative-decode acceptance rate | ≥ 0.3 informational |
| Cloud-cascade trigger rate | < 0.1 informational (high rate means local cocktail is failing too often) |

## §5. Methodology — composition-feasibility study

This is a research study; methodology IS the deliverable.

### §5.1 Layer instrumentation

Each of the seven layers exposes:

- `LayerKey` (identity)
- `metered_call` (wraps every entry/exit with timing + memory delta)
- `report()` (summarizes per-layer activity)

The harness aggregates per-layer reports into a `CocktailComposition::Report` that contains everything needed
for §3.2 bottleneck identification.

### §5.2 Iteration protocol

1. Substrate-floor pass: synthetic harness with mock layers — proves the composition wiring works.
2. Per-pair integration: each cross-layer interaction (ternary × Mamba, KV-Direct × PageGather,
   selector × speculative-decode, etc.) gets a focused two-layer micro-harness to catch interactions before
   the full 7-layer test.
3. Full cocktail pass on Qwen 3 8B + Mamba-2 2.8B at 32k context (under M2 Pro 16 GB budget).
4. (Optional, M2 Max) full cocktail pass scaled up to research-tier weights.

### §5.3 Reference

- **Substrate-floor synthetic**: no reference needed (composition feasibility is the deliverable).
- **Live**: cloud Claude / GPT-4 / DeepSeek-R1 same-prompt outputs as KL reference (informational only;
  cumulative KL/token < 1.0 over 256 tokens is the "did not catastrophically diverge" floor).

### §5.4 Reproducibility

- Seed `0xCEFAEEEE` for synthetic study.
- Live: fixed prompt corpus + Qwen 3 + Mamba-2 checkpoints + fixed RNG seed.
- Median-of-3 runs.

## §6. Fallback if the gate fails

Per §4.G "No silent skips" — but with a research-only twist: failure of THIS gate does not block ship, because
the gate's status is Capability Ceiling. Failure DOES require recording the cause and re-running with
adjustments.

1. **Substrate-floor synthetic panic / OOM**:
   - The composition wiring is broken. Bisect on layer combinations until the minimal panic case is found.
   - Most likely cause: layer N's output type does not match layer N+1's input expectation (FFI / Sendable
     boundary issue).
2. **Live RAM > 13 GB**:
   - **Tier 1**: shrink Mamba-2 from 2.8B to a smaller research-tier checkpoint.
   - **Tier 2**: aggressive KV-Direct tier eviction (force more cold-spill).
   - **Tier 3**: trim active-assembly selector firing rate (raise cost_weight).
   - **Tier 4**: drop speculative-decode (saves draft-model RAM; pure throughput trade).
   - **Tier 5**: STALLED — file bottleneck = "M2 Pro 16 GB cannot host the 4-of-7 composition without
     dropping speculative". Document; move ceiling research to M2 Max for further work.
3. **Generation collapsed**:
   - Repetition: speculative-decode acceptance pattern is rotting. Check draft-vs-target alignment.
   - NaN: identify offending layer via instrumentation; likely Mamba-2 state explosion (clamp state norm) or
     ternary kernel quantization edge case.
   - Diverged > 1.0 KL: too aggressive on KV-Direct + Shadow paging compression. Loosen one tier.
4. **No bottleneck identified**:
   - Harness instrumentation is incomplete. Add per-layer timing/memory hooks. This is the most fixable case.

## §7. Acceptance bar (gate-pass criteria)

The gate **passes** when ALL of the following are true:

- [ ] Substrate-floor synthetic study runs end-to-end without panic / OOM / corruption.
- [ ] Live-model 7-layer composition runs end-to-end on M2 Pro 16 GB without panic.
- [ ] Peak RAM during live run < 13 GB (M2 Pro 16 GB budget).
- [ ] 256 tokens generated without collapse (per §3.1 collapse detection).
- [ ] Primary bottleneck identified + documented + ranked against the other 6.
- [ ] Research-tier doc landed at `docs/research/UAS_ACS_COCKTAIL_COMPOSITION_2026_05_17.md` (or later
  date) capturing the bottleneck analysis.
- [ ] Reproducibility: same seed produces same bottleneck identification across 3 runs.
- [ ] `cargo test` ≥ baseline + new tests. `xcodebuild test` clean.
- [ ] Doctrine doc §5 register row #14 (70B Cocktail) status updates from `not yet` → `landed (research)`.
- [ ] `Co-Authored-By: Codex (T3)` on every commit.

## §8. Dependencies + downstream gates

**Depends on**:

- ALL OF gates #2-#11 PASS. This is the ceiling gate; it inherits all 10 substrate falsifiers.
- Speculative-decode primitive: not in the substrate-floor codebase yet; this gate produces it as part of the
  study.
- Cloud cascade trigger: not in the substrate-floor codebase yet; this gate produces the trigger-threshold
  spec.
- Qwen 3 8B + Mamba-2 2.8B + Qwen 3 0.5B (draft) MLX bundles available.

**Unblocks** (downstream — research-only consumers):

- §4.E model-gating-liberation Phase C.8+ (ternary inference path wire-in is supported by the cocktail
  bottleneck analysis).
- §4.F Local Agent Excellence multi-model brain constellation (the cocktail's component composition IS the
  multi-model brain when seen from the agent runtime).
- Future `F-70B-MAS-Ship` gate (if and when 70B-on-laptop becomes a product claim, it inherits this gate's
  bottleneck analysis as its baseline).

## §9. Cross-references

- Canonical doctrine: §4 ladder + §5 register row #14 (70B Cocktail).
- Substrate-floor audit: §A row #14 + §C gap list (cocktail components #6 + #7 produced by this gate).
- Driver authority: driver §4.G ladder gate #12 + driver Capability Ceiling tier definition.
- Hybrid 75/25 transformer/Mamba: MASTER_FUSION §3.41 Nano Model Training Recipe.
- Ternary lane: register row #15 + `agent_core/src/research/ternary/`.
- Mamba-2 lane: register row #17 + `agent_core/src/helios/ssd_block_scan.rs` (CPU ref) + Phase C Metal kernel.
- KV-Direct lane: register row #13 + `agent_core/src/scope_rex/kv/direct_gate.rs` + F-KV-Direct-Gate.
- PageGather lane: register row #10 + `agent_core/src/helios/page_gather.rs` + F-PageGather-M2Pro.
- Active assembly lane: register row #25 + Phase B.G.B6 target + F-ActiveAssembly-Minimal.
- "Tagged C/Vault, not product": driver §4.G F-70B prose explicitly + canon-hardening protocol §1 (WRV state
  machine; this gate's outputs remain `state: candidate` and `state: research`).
- §4.F Local Agent Excellence overlap: driver §4.F multi-model brain constellation is the same composition
  seen from a different vantage.
