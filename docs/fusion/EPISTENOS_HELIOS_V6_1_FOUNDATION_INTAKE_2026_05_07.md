---
state: canon-intake
created_on: 2026-05-07
source: user-pasted Epistenos / Helios v6.1 Foundation Document
status: accepted-as-strict-sharpening
---

# Epistenos / Helios V6.1 Foundation Intake - 2026-05-07

## Verdict

This refresh is accepted as a V6.1 Foundation sharpening, not a rename and not a break in the V5 -> V6 -> V6.1 -> V6.2 canon chain.

The update reorders the immediate floor work:

1. EML-IR is the next arithmetic floor artifact for elementary scientific computation.
2. `F-ULP-Oracle` is W1 and gates `morph_eval_reduced.metal v0.1`.
3. AnswerPacket schema freeze sits behind the ULP oracle.
4. The V6.2 kernel-side ladder begins after this W1 gate.

## Decisions

### Goodfire Status

The Foundation text was cautious about the `9972 / 205 / 2.1%` Goodfire VPD activity subnumbers. Codex revalidated the live Goodfire research page on 2026-05-07 and found the table exposing `9972`, `205.0`, and `0.021`.

Canonical resolution:

- Internal math: use `205 / 9972`.
- Public wording: use `2.1%`.
- Runtime acceleration: remains candidate/Vault-only.
- Atlas and observability claims: public-confirmed.

Source used for live revalidation: https://www.goodfire.ai/research/interpreting-lm-parameters

### PageGather Threshold

The new PageGather baseline is no longer interpreted as 70% of theoretical M2 Pro peak bandwidth.

Canonical split:

- Baseline sustained band: `63-73 GB/s`.
- Scatter/gather target: `70%` of the locally measured baseline.
- Peak bandwidth remains `200 GB/s` as the hardware reference, not as the direct pass threshold.

### EML Boundaries

EML is a computational primitive for elementary scientific computation, not a primitive of the universe.

Accepted:

- `eml(x,y)=exp(x)-ln(y)`
- `S -> 1 | eml(S,S)`
- terminal `1` is required.
- constant-free universal EML generation remains open.

Rejected or demoted:

- "EML alone is dense in everything" without coordinates, conjugation, and point separation.
- Monnerot `eml*` as citable canon until independently verified.
- single-2-cell ZX/ZH Sheffer stroke as a commitment.
- single-generator Clifford universality as a commitment.

## W1 F-ULP Oracle

`F-ULP-Oracle` is the first hardware falsifier in this foundation sequence.

Spec:

- `412,000` log-sampled points.
- `2,048` stress points.
- tolerance `<= 2 ULP fp16` inside `[0.5, 2.0]`.
- wall-clock budget `<= 90 s` on the M2 Pro 16 GB rig.
- oracle reference: `oxieml::EmlTree::eval_real`.
- kernel under test: `morph_eval_reduced.metal v0.1`.

No AnswerPacket schema freeze may be called complete until this oracle actually passes.

## Stage Mapping

The Foundation sequence wraps the previous V6.2 ladder:

1. Vendor `oxieml` read-only.
2. Vendor `eml-lean` and verify the claimed zero `sorry` / `admit` posture.
3. Land `morph_eval_reduced.metal v0.1`.
4. Land and pass `F-ULP-Oracle`.
5. Freeze AnswerPacket schema behind that passing oracle.
6. Pin Lean toolchain and record any divergence.
7. Track demoted claims as explicit DROP caveats.

The V6.1 five kernels remain canonical Stage 3 targets:

- `SemiseparableBlockScan.metal`
- `LocalRecallIsland.metal`
- `PageGather.metal`
- `ControllerKernelPack.metal`
- `PacketRouter1bit.metal`

`InterruptScore.metal` remains the always-on shadow/kernel candidate, with Swift CPU canonical for single-token V6.2 use.

## Implementation Hooks Landed

Research substrate hooks:

- `epistemos-research/src/v6_1_foundation.rs`
- `epistemos-research/src/v6_2.rs`
- `epistemos-research/tests/canonical_consistency.rs`
- `epistemos-research/src/scientific_calculator_basis.rs`

Important correction:

- Removed the stale `+ 1` wording from the EML formula comment. The accepted operator is exactly `exp(x) - ln(y)`.

## Non-Claim

This intake does not mean `morph_eval_reduced.metal`, `oxieml`, `eml-lean`, or the full ULP oracle harness have shipped. It records the required floor sequence and prevents canonical drift before that implementation starts.
