---
state: falsifier
gate: F-ULP-Oracle
ladder_position: W1 (V6.1 foundation sequence — predates the §4.G 12-gate ladder)
owner: T3 (kernel + harness) · T7 (oracle reference — handshake)
created_on: 2026-05-17
authority: docs/fusion/EPISTENOS_HELIOS_V6_1_FOUNDATION_INTAKE_2026_05_07.md §"W1 F-ULP Oracle" (LOCK) + docs/CODEX_DEEP_INVESTIGATION_PROMPT_2026_05_16.md §4.G residency-tier examples (Verified Floor)
target_phase: Phase B (kernel) + Phase B (harness)
target_rig: M2 Pro 16 GB
---

# F-ULP-Oracle

> The **W1 hardware falsifier** in the V6.1 foundation sequence — predates even the §4.G 12-gate ladder. Gates
> the Morph DSL evaluator kernel `Epistemos/Shaders/morph_eval_reduced.metal v0.1` against the oxieml
> reference. **AnswerPacket schema freeze depends on this gate passing.**

## §1. Why this gate exists

Per `docs/fusion/EPISTENOS_HELIOS_V6_1_FOUNDATION_INTAKE_2026_05_07.md` §"W1 F-ULP Oracle":

> `F-ULP-Oracle` is the first hardware falsifier in this foundation sequence.

And per §"Stage Mapping":

> 1. Vendor `oxieml` read-only.
> 2. Vendor `eml-lean` and verify the claimed zero `sorry` / `admit` posture.
> 3. Land `morph_eval_reduced.metal v0.1`.
> 4. Land and pass `F-ULP-Oracle`.
> 5. Freeze AnswerPacket schema behind that passing oracle.
> 6. Pin Lean toolchain and record any divergence.
> 7. Track demoted claims as explicit DROP caveats.

So this gate sits at floor: step 4 of the V6.1 foundation sequence. The AnswerPacket schema (HELIOS V5 W1
landed kernel at `agent_core/src/scope_rex/answer_packet.rs`) cannot be FROZEN as canonical until this oracle
passes, because Morph DSL determinism (T5 in helios v5 first.md) feeds into provenance traces, which feed
into AnswerPacket emissions.

This gate is named in the §4.G residency-tier table under "Verified Floor (gated) — substrate primitive,
ships after its falsifier passes on M2 Pro 16 GB: ... F-ULP-Oracle" but is NOT in the 12-gate ladder
(§4.G ladder gates 1-12). It sits below the ladder in the foundation sequence; the ladder gates build on top
of this passing.

## §2. The kernel under test

`Epistemos/Shaders/morph_eval_reduced.metal v0.1` — the Morph DSL evaluator kernel (formerly named
`morph_dsl_dispatch.metal` per `docs/fusion/helios v5 first.md` line 339).

It evaluates expressions in the Morph DSL — Domain-Specific Language for kernel composition that supports
EML-family operators (`eml(x, y) = exp(x) - ln(y)`, the family closure `S → 1 | eml(S, S)`, terminal `1`)
plus the elementary scientific operations the §4.I EML-IR substrate names.

The "reduced" form (v0.1) is the substrate-floor evaluator capable of running this oracle gate; the full
DSL evaluator is reserved for later versions.

## §3. The oracle reference

`oxieml::EmlTree::eval_real` — a real-valued reference implementation of the EML expression tree, owned by
T7 in the `agent_core/src/research/eml/` lane (DO NOT EDIT per T3 scope lock). The reference is the
floating-point ground-truth that the Metal kernel must match within the ULP tolerance.

**Cross-terminal handshake**: T7 publishes `oxieml::EmlTree::eval_real` (live as of 2026-05-17 per V6.1
intake stage 1 "Vendor `oxieml` read-only"). T3 consumes it as the oracle reference. The gate's pass
requires both terminals' artifacts to align.

## §4. Pass/fail recipe (the test that decides) — VERBATIM from V6.1 intake

Per `docs/fusion/EPISTENOS_HELIOS_V6_1_FOUNDATION_INTAKE_2026_05_07.md` §"W1 F-ULP Oracle":

> Spec:
> - `412,000` log-sampled points.
> - `2,048` stress points.
> - tolerance `<= 2 ULP fp16` inside `[0.5, 2.0]`.
> - wall-clock budget `<= 90 s` on the M2 Pro 16 GB rig.
> - oracle reference: `oxieml::EmlTree::eval_real`.
> - kernel under test: `morph_eval_reduced.metal v0.1`.

A Swift test at `EpistemosTests/FUlpOracleTests.swift` (lands in Phase B):

```swift
let logSampledPoints = LogSampler.draw(count: 412_000, range: 0.5...2.0, seed: 0xULPA_0001)
let stressPoints = StressSampler.draw(count: 2_048, edges: [.zero, .one, .twoBoundary, .denormal], seed: 0xULPA_0002)
let allPoints = logSampledPoints + stressPoints

let wallStart = ContinuousClock.now
var maxUlpAbsDiff: Int = 0

for point in allPoints {
    let referenceValue = try await OxiEml.evalReal(point)            // T7-owned oracle (fp64)
    let kernelValue = try await MorphEvalReduced.evaluate(point)     // T3-owned Metal kernel (fp16)

    let ulpDiff = abs(ulpDifferenceF16(reference: referenceValue, actual: kernelValue))
    maxUlpAbsDiff = max(maxUlpAbsDiff, ulpDiff)
}

let wallSeconds = (ContinuousClock.now - wallStart).components.seconds

XCTAssertLessThanOrEqual(maxUlpAbsDiff, 2,
    "F-ULP-Oracle FAILED: max ULP abs-diff = \(maxUlpAbsDiff) > 2 ULP fp16")
XCTAssertLessThanOrEqual(wallSeconds, 90,
    "F-ULP-Oracle FAILED: wall-clock \(wallSeconds) s > 90 s budget on M2 Pro 16 GB")
```

Gate **fails** if max ULP abs-diff > 2 OR wall-clock > 90 s.

### §4.1 Sampler specifications

- **Log-sampler** (412,000 points): draws from `[0.5, 2.0]` with logarithmic spacing. Reseedable via the
  `0xULPA_0001` seed for reproducibility.
- **Stress sampler** (2,048 points): includes:
  - Subnormal floats (`0.5 * 2^-14`)
  - Boundary cases (`0.5`, `1.0`, `2.0`, `prev/next representable f16`)
  - NaN-adjacent values (`f16::EPSILON`, `f16::EPSILON * 4`)
  - Values that historically tripped reduced-precision evaluators

### §4.2 ULP-difference definition

ULP (Unit in the Last Place) in fp16:

```rust
fn ulp_difference_f16(reference: f64, actual: f16) -> i64 {
    let actual_f64 = actual as f64;
    let actual_bits = (actual as f16).to_bits();
    let reference_as_f16 = reference as f16;
    let reference_bits = reference_as_f16.to_bits();
    (actual_bits as i64) - (reference_bits as i64)
}
```

The gate is symmetric (signed ULP diff doesn't matter — only abs-diff). 2 ULP fp16 covers normal evaluator
drift; > 2 indicates the kernel is taking a non-IEEE-compliant shortcut somewhere.

## §5. M2 Pro 16 GB budget

| Metric | Budget |
|---|---|
| Max ULP abs-diff (fp16) inside `[0.5, 2.0]` | ≤ 2 (HARD GATE) |
| Wall-clock (full 414,048-point evaluation) | ≤ 90 s on M2 Pro 16 GB (HARD GATE) |
| Per-point evaluation wall (avg) | ≤ 217 µs (= 90 s / 414,048 points) |
| Peak RAM during harness run | < 1 GB (the kernel is small; the harness is the storage of the input/output arrays) |

## §6. Measurement methodology

- **Reproducibility**: seeds `0xULPA_0001` and `0xULPA_0002` produce identical point sets across runs.
- **Median-of-3 runs** absorbs Metal-dispatch noise.
- **Thermal control**: Spotlight off on `target/`; CPU governor pinned high-performance; idle for 30 s
  before timing.
- **Reference computation in fp64**: `oxieml::EmlTree::eval_real` uses fp64 internally; the comparison
  rounds to fp16 only at the comparison step. This ensures we're measuring the kernel's fp16 error against
  the closest representable fp16 of the true fp64 result.
- **Cross-validation against `eml-lean` (V6.1 stage 2)**: when `eml-lean` lands, a property check verifies
  that `oxieml::EmlTree::eval_real` matches the formal-proof `eml-lean` output on a fixed set of inputs.
  This is INFRASTRUCTURE for trust in the oracle; not a gate-pass requirement.

## §7. Fallback if the gate fails

Per V6.1 intake "No AnswerPacket schema freeze may be called complete until this oracle actually passes":
failure of this gate is a HARD BLOCK on the rest of the foundation sequence + on §4.G ladder progress.

1. **Max ULP > 2**:
   - **Tier 1 — kernel arithmetic review**: the Metal kernel is using a fast-math shortcut. Disable
     `-ffast-math` equivalent (Metal: `[[ no_fast_math ]]` attribute on the function).
   - **Tier 2 — codec / lookup-table swap**: if `exp` / `ln` are computed via polynomial approximation, swap
     to a more precise polynomial or to a lookup-table + correction.
   - **Tier 3 — domain restriction**: temporarily restrict the gate to a sub-range of `[0.5, 2.0]` (e.g.
     `[0.7, 1.5]`) and document the gap. NOT a clean pass; flag as PARTIAL.
   - **Tier 4 — STALLED**: file BLOCKER. Halt all §4.G ladder work that depends on this gate. The
     AnswerPacket schema cannot freeze; the substrate is at floor failure.
2. **Wall-clock > 90 s**:
   - **Tier 1 — Metal dispatch batching**: dispatch in batches of 1024 instead of point-by-point.
   - **Tier 2 — kernel parallelism**: ensure the kernel uses Metal SIMD groups for the parallel evaluation
     across the input array.
   - **Tier 3 — fixed-iteration polynomial**: if the kernel uses an iterative refinement, cap iterations.
     Trade: may push max-ULP closer to 2 but never beyond.

## §8. Acceptance bar

The gate **passes** when ALL of the following are true on M2 Pro 16 GB:

- [ ] max ULP abs-diff ≤ 2 across all 414,048 points (412k log-sampled + 2k stress).
- [ ] Wall-clock ≤ 90 s for the full evaluation.
- [ ] Reproducibility: same seeds produce same max-ULP across 3 median-of-3 runs (variance allowed only in
  wall-clock, not in correctness).
- [ ] `cargo test` ≥ baseline + new tests. `xcodebuild test` clean.
- [ ] Cross-validation with `eml-lean` (informational; not required for pass).
- [ ] Doctrine doc §5 register row #20 (Morph) status updates from `taxonomy-only` → `landed`.
- [ ] V6.1 foundation §"Stage Mapping" step 5 unlocks: AnswerPacket schema freeze can proceed.
- [ ] `Co-Authored-By: Codex (T3)` on every commit landing the kernel + harness.

## §9. Dependencies + downstream gates

**Depends on**:

- **V6.1 foundation stage 1**: T7 lands `oxieml` read-only (per V6.1 intake §"Stage Mapping" step 1; live as
  of 2026-05-17).
- **V6.1 foundation stage 3**: T3 lands `morph_eval_reduced.metal v0.1` Metal kernel (Phase B target).
- F-PageGather-M2Pro pass (informational — Metal dispatch overhead is bounded; this gate inherits the same
  expectation, though the 414k-point evaluation is not bandwidth-bound).

**Unblocks** (the V6.1 foundation sequence + the §4.G ladder):

- V6.1 foundation stage 5: AnswerPacket schema freeze (this gate's pass is the explicit precondition).
- §4.G ladder gate 2 F-UAS-ZeroCopy-Spine — the AnswerPacket hot-path it tests inherits the schema freeze.
- All §4.G ladder downstream — every gate that emits AnswerPackets cannot canonicalize until this passes.
- Lattice round-trip work (T4 LatticeCoder Babai bound, per helios v5 first.md line 473) — the Morph DSL
  controller is a multiplicative constant in that bound.
- WBO-7 controller (helios v5 first.md WBO-7 theorem) — the Morph DSL bounds bandwidth growth to factor-7
  per resonance step.

## §10. Cross-references

- V6.1 foundation primary: `docs/fusion/EPISTENOS_HELIOS_V6_1_FOUNDATION_INTAKE_2026_05_07.md` §"W1 F-ULP
  Oracle" + §"Stage Mapping" steps 1-5.
- Helios v5 substrate doctrine: `docs/fusion/helios v5 first.md` DOC 6 §T5 Morph DSL Determinism
  (lines 236, 339, 377, 460-463, 473, 475, 654).
- Driver authority: `docs/CODEX_DEEP_INVESTIGATION_PROMPT_2026_05_16.md` §4.G residency-tier table (Verified
  Floor row names F-ULP-Oracle as a gated falsifier) + §4.I EML-IR Primitive Stack (T7 lane).
- Morph deep-dive: `docs/audits/UAS_ACS_MORPH_DEEP_DIVE_2026_05_17.md`.
- Canonical doctrine: `docs/fusion/UAS_ACS_CANONICAL_ARCHITECTURE_2026_05_16.md` §5 register row #20.
- Substrate-floor audit: `docs/audits/UAS_ACS_SUBSTRATE_INVENTORY_2026_05_17.md` §A row #19.
- T7 oracle reference: `agent_core/src/research/eml/ulp_oracle.rs` (DO NOT EDIT per T3 scope lock; consume
  only).
- Active oxieml integration: per V6.1 intake stage 1 "Vendor `oxieml` read-only".
- AnswerPacket schema: `agent_core/src/scope_rex/answer_packet.rs` (W1 landed; awaits freeze post-this-gate-
  pass).
