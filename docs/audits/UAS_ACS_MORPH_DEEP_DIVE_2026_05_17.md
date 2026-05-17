---
state: audit
created_on: 2026-05-17
terminal: T3 — UAS-ACS Canonical Architecture
branch: codex/t3-uasacs-2026-05-16
scope: Phase A iter 14 — resolution of the "Morph" open question filed in iter 1 (audit §F.1) and iter 2 (canonical doctrine §8.1).
authority: docs/CODEX_DEEP_INVESTIGATION_PROMPT_2026_05_16.md §4.G hierarchy (LOCK) + docs/fusion/helios v5 first.md DOC 6 §T5 + docs/fusion/EPISTENOS_HELIOS_V6_1_FOUNDATION_INTAKE_2026_05_07.md.
---

# UAS-ACS Morph Deep-Dive — 2026-05-17

> Phase A iter 14 — resolves the audit's largest open question. Morph is **not** a gap. The iter 1 grep missed
> it because it was scoped to `agent_core/src/{helios,scope_rex,research}` only; the canonical authorities for
> Morph live in `docs/fusion/helios v5 first.md` and `docs/fusion/EPISTENOS_HELIOS_V6_1_FOUNDATION_INTAKE_2026_05_07.md`,
> with the kernel file landing in `Epistemos/Shaders/morph_eval_reduced.metal v0.1` (Phase B target).

## §1. Resolution summary

**Morph** in §4.G's "Kernels (MUSCLE — PageGather, LocalRecallIsland, SemiseparableBlockScan, PacketRouter1bit,
ControllerKernelPack, **Morph**)" refers to the **Morph DSL evaluator kernel** at
`Epistemos/Shaders/morph_eval_reduced.metal v0.1` (formerly named `morph_dsl_dispatch.metal` per helios v5
first.md line 339; renamed in the V6.1 foundation refresh).

It is:

1. A Metal kernel that evaluates expressions in the **Morph DSL**, a hardware-deterministic domain-specific
   language for kernel composition.
2. The substrate-level **controller** for the other 5 MUSCLE kernels — the DSL evaluator dispatches their
   composition with byte-identical-trace determinism (helios v5 first.md DOC 6 §T5).
3. Gated by **F-ULP-Oracle** (W1 in the V6.1 foundation falsifier sequence — see V6.1 intake doc §"W1 F-ULP
   Oracle").
4. Tied conceptually to the EML primitive family (§4.I in the driver prompt): the canonical Morph DSL
   expression evaluates `eml(x, y) = exp(x) - ln(y)` and similar elementary scientific compositions; this
   makes Morph the **arithmetic-primitive kernel** that anchors EML-IR (driver §4.I).

So the iter 1 / iter 2 disposition of Morph as `gap — flagged for user clarification` was incorrect. The
correct status is **landed (research-tier doctrine) + scaffolded (`oxieml::EmlTree::eval_real` reference) +
pending (Metal kernel + F-ULP-Oracle harness)**, with the F-ULP-Oracle gate as the falsifier dependency.

## §2. Where Morph lives (primary sources)

| Source | Reference | Quote |
|---|---|---|
| `docs/fusion/helios v5 first.md` line 236 | T5 row in the falsifier table | "Morph DSL deterministic replay" |
| `docs/fusion/helios v5 first.md` line 339 | new file list | "`Epistemos/Shaders/morph_dsl_dispatch.metal` **[NEW]**" |
| `docs/fusion/helios v5 first.md` line 377 | Cortical Packet Runtime §3.2 | "Three-cortex architecture (transformer + PARN + ternary morph) under Active Assembly Compiler" |
| `docs/fusion/helios v5 first.md` lines 460-463 | WBO-7 theorem statement | "Morph DSL controller bounds bandwidth growth to factor-7 per resonance step" |
| `docs/fusion/helios v5 first.md` line 473 | T4 LatticeCoder theorem | "round-trip error bounded by Babai's bound times a Morph DSL-controlled constant" |
| `docs/fusion/helios v5 first.md` line 475 | T5 Morph DSL Determinism theorem | "same DSL program + same input = byte-identical trace. Falsifier: verify-replay CI gate B2." |
| `docs/fusion/helios v5 first.md` line 654 | concept-doc cross-reference | "Morph DSL controller surfaces · helios_v3 · DOC 6 §T5 + DOC 2 §2.2 ✓" |
| `docs/fusion/EPISTENOS_HELIOS_V6_1_FOUNDATION_INTAKE_2026_05_07.md` line 17 | V6.1 floor-sequence | "`F-ULP-Oracle` is W1 and gates `morph_eval_reduced.metal v0.1`." |
| `docs/fusion/EPISTENOS_HELIOS_V6_1_FOUNDATION_INTAKE_2026_05_07.md` line 75 | F-ULP-Oracle spec | "kernel under test: `morph_eval_reduced.metal v0.1`." |
| `docs/fusion/EPISTENOS_HELIOS_V6_1_FOUNDATION_INTAKE_2026_05_07.md` line 85 | stage mapping | "Land `morph_eval_reduced.metal v0.1`." |

## §3. What Morph IS (conceptual scope)

### §3.1 The Morph DSL

A small domain-specific language for composing kernel dispatches in the hot path. Programs in the DSL are
sequences of typed operations (e.g. `eml(x, y)`, `babai_round(v, basis)`, `quantize_int8(t, scale)`) that the
evaluator kernel runs on Metal.

The **determinism property** (helios v5 first.md T5): "same DSL program + same input = byte-identical trace."
This is enforced by the verify-replay CI gate (B2). Determinism matters because the Morph DSL feeds into
provenance ledger snapshots (`agent_core/src/provenance/{ledger,replay}.rs`) — non-deterministic trace would
break replay equivalence.

### §3.2 The Morph kernel file

`Epistemos/Shaders/morph_eval_reduced.metal v0.1` (V6.1 foundation naming) — the "reduced" form is the
substrate-floor evaluator; full DSL expressivity is reserved for later iterations. The "v0.1" tag indicates
this is the first evaluator capable of running the F-ULP-Oracle gate.

The V6.1 intake explicitly does NOT claim this kernel has shipped: "This intake does not mean
`morph_eval_reduced.metal`, `oxieml`, `eml-lean`, or the full ULP oracle harness have shipped. It records the
required floor sequence and prevents canonical drift before that implementation starts." (V6.1 intake §"Non-
Claim".) So the substrate-floor inventory's `not yet` posture on Morph is correct; only the gap classification
was wrong.

### §3.3 The Cortical Packet Runtime role

Helios v5 first.md §3.2 places "ternary morph" as one of the three cortex types in the Cortical Packet
Runtime ("transformer + PARN + ternary morph"). The Active Assembly Compiler (AAC) composes the three under
OSPC bind/route/merge/split. So Morph also doubles as **one of the cortex types** in the AAR layer — the
ternary-morph cortex.

This is a layer-spanning role: Morph is both
- a MUSCLE-layer kernel (in §4.G hierarchy) AND
- a cortex type that AAR composes (V6.1 foundation §3.2).

The hierarchy LOCK in §4.G is not violated — Morph the kernel sits at the Kernels layer, and Morph the cortex
sits at AAR (NERVOUS SYSTEM); AAR USES the kernel. They are not the same layer-object but they share a name.

## §4. The F-ULP-Oracle gate

Per V6.1 foundation intake §"W1 F-ULP Oracle" (verbatim):

> `F-ULP-Oracle` is the first hardware falsifier in this foundation sequence.
>
> Spec:
> - `412,000` log-sampled points.
> - `2,048` stress points.
> - tolerance `<= 2 ULP fp16` inside `[0.5, 2.0]`.
> - wall-clock budget `<= 90 s` on the M2 Pro 16 GB rig.
> - oracle reference: `oxieml::EmlTree::eval_real`.
> - kernel under test: `morph_eval_reduced.metal v0.1`.
>
> No AnswerPacket schema freeze may be called complete until this oracle actually passes.

This is the falsifier doc T3 should write next (iter 15 target). It is the FIRST hardware falsifier in the
V6.1 foundation sequence — predating even the V6.2 8-stage ladder that F-PageGather (§4.G ladder #5) sits in.

## §5. Coordination with EML-IR (driver §4.I — T7 ownership)

Driver §4.I "EML-IR Primitive Stack — kernel-grade IR family for verifiable computation" specifies the EML
operator as a substrate primitive. T7 owns the EML lane (per driver scope locks); T3 reads EML as a consumer.

Morph is the **operational layer** for EML-IR: EML-IR specifies the family of operators (`eml(x,y)=exp(x)-ln(y)`,
the family closure rules `S -> 1 | eml(S,S)`, etc.); Morph kernel evaluates expressions over that family on
Metal. So Morph is the kernel-grade IR family's executor.

Two cross-ownership boundaries:

- **T7 EML-IR**: owns the operator family, the oracle reference (`oxieml::EmlTree::eval_real`), and the
  primitive closure proofs.
- **T3 UAS-ACS / Morph kernel**: owns the Metal kernel `morph_eval_reduced.metal v0.1`, the F-ULP-Oracle gate
  harness, and the substrate-level evaluator integration.

The two-terminal handshake is the F-ULP-Oracle's pass — once T7's reference passes against T3's kernel within
≤ 2 ULP fp16 over 412k+2k probe points within 90 s on M2 Pro 16 GB, both terminals can move forward.

## §6. Updates required (this iter + iter 15)

**This iter (iter 14)** — landing this deep-dive:

- ✅ Create `docs/audits/UAS_ACS_MORPH_DEEP_DIVE_2026_05_17.md` (this doc).
- ✅ Update `docs/fusion/UAS_ACS_CANONICAL_ARCHITECTURE_2026_05_16.md` §5 register row #20 (status from
  `gap — flagged for user clarification` to `taxonomy-only (V6.1 foundation; kernel pending Phase B)`).
- ✅ Update `docs/fusion/UAS_ACS_CANONICAL_ARCHITECTURE_2026_05_16.md` §8 question 1 (resolution: option (a)
  — future-target kernel; not deprecated; not a doctrine-doc placeholder).
- ✅ Update `docs/audits/UAS_ACS_SUBSTRATE_INVENTORY_2026_05_17.md` §A row #19 + §F question 1 with the same
  resolution.

**Next iter (iter 15)** — write the F-ULP-Oracle falsifier doc:

- `docs/falsifiers/F-ULP-Oracle_2026_05_17.md` — gate spec for the W1 hardware falsifier (412k log-sampled
  + 2k stress + ≤ 2 ULP fp16 in [0.5, 2.0] + ≤ 90 s wall-clock + `oxieml::EmlTree::eval_real` reference vs
  `morph_eval_reduced.metal v0.1` kernel under test). Coordinate with T7 on the oracle-reference handshake.

## §7. Cross-references

- Canonical doctrine: `docs/fusion/UAS_ACS_CANONICAL_ARCHITECTURE_2026_05_16.md` §5 row #20 (Morph) + §8
  question 1 (now resolved).
- Substrate-floor audit: `docs/audits/UAS_ACS_SUBSTRATE_INVENTORY_2026_05_17.md` §A row #19 + §F question 1
  (now resolved).
- Driver authority: `docs/CODEX_DEEP_INVESTIGATION_PROMPT_2026_05_16.md` §4.G hierarchy line "Kernels (MUSCLE
  — ... Morph)" + §4.G Verified-Floor residency-tier examples line "F-ULP-Oracle".
- V6.1 foundation: `docs/fusion/EPISTENOS_HELIOS_V6_1_FOUNDATION_INTAKE_2026_05_07.md` §"W1 F-ULP Oracle"
  + §"Stage Mapping".
- Helios v5 substrate doctrine: `docs/fusion/helios v5 first.md` lines 236, 339, 377, 460-463, 473, 475, 654.
- EML-IR (T7-owned): driver §4.I + `agent_core/src/research/eml/{evaluator, gate, grammar, operator,
  ulp_oracle}.rs` (DO NOT EDIT per T3 scope lock; reference only).
- AnswerPacket schema freeze dependency: V6.1 intake §"W1 F-ULP Oracle" — "No AnswerPacket schema freeze may
  be called complete until this oracle actually passes." This is the upstream binding constraint for the
  whole §4.G ladder.

## §8. Acceptance check (§5.0 reconciliation gate)

This deep-dive resolves the audit's largest open question. Verification:

```
$ grep -n "morph\|Morph" docs/fusion/helios\ v5\ first.md
236:| T5 | L2 | EB | ≤2 | Morph DSL deterministic replay |
339:- `Epistemos/Shaders/morph_dsl_dispatch.metal` **[NEW]**.
377:**§3.2 Cortical Packet Runtime + Helios Cortex first realization.** ... transformer + PARN + ternary morph ...
460:- ... For any sampler trajectory τ on X under the Morph DSL, the witnessed-bandwidth-output satisfies WBO-7 ...
473:**T4 — LatticeCoder (Babai quantization)** ... round-trip error bounded by Babai's bound times a Morph DSL-controlled constant.
475:**T5 — Morph DSL Determinism** [EB]. ... same DSL program + same input = byte-identical trace.
654:| 48 | Morph DSL controller surfaces | helios_v3 | DOC 6 §T5 + DOC 2 §2.2 ✓ |

$ grep -n "morph_eval_reduced\|morph_dsl" docs/fusion/EPISTENOS_HELIOS_V6_1_FOUNDATION_INTAKE_2026_05_07.md
17:2. `F-ULP-Oracle` is W1 and gates `morph_eval_reduced.metal v0.1`.
75:- kernel under test: `morph_eval_reduced.metal v0.1`.
85:3. Land `morph_eval_reduced.metal v0.1`.
116:This intake does not mean `morph_eval_reduced.metal` ... have shipped.
```

The grep proves: Morph is documented in primary sources (V5 substrate + V6.1 foundation), the kernel file
target is named, the falsifier gate is named, and the V6.1 intake explicitly disclaims shipping. The iter-1
"NOT FOUND" status was a scope error in the original grep (limited to `agent_core/src/{helios,scope_rex,
research}`); the correct status is "doctrine-canonical; kernel + harness Phase B targets gated by
F-ULP-Oracle."
