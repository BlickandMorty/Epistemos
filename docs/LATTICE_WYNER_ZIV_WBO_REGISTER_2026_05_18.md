# Lattice-Wyner-Ziv / WBO Register - 2026-05-18

## Purpose

This register preserves the lattice/WBO lane as accounting substrate. It is not
a speed claim, not a kernel implementation plan, and not a replacement for UAS.
UAS names addressable residency; this document names the error law paid by each
compressed or approximate representation.

Canonical anchors:

- `docs/NO_COMPROMISE_ENDGAME_PROMPT_DECK_2026_05_18.md` §4 T17B.
- `docs/fusion/HELIOS_WBO6_BUDGET_2026_05_03.md`.
- `docs/MASTER_FUSION_NO_COMPROMISE_2026_05_13.md` §3.2, §3.4, §3.8, §3.16, §3.18.
- `docs/fusion/UNIFIED_ACTIVE_SUBSTRATE_CANON_2026_05_16.md` §2, §4, §5.

## Invariants

1. `LatticeCoder<BITS>` is an abstraction over a rate-limited codec family, not
   a promise that every tier is literally decoded by the same lattice.
2. Lattice-Wyner-Ziv means the decoder uses model-side information. That side
   information can be residual stream state, active support, calibration data,
   or a cold oracle depending on the tier.
3. Babai/GPTQ is the nearest-plane interpretation for weight quantization.
   Sherry, ShadowKV, QuIP/E8, residual sketches, NF4 SSD pages, and adapters
   are separate codecs with separate ledgers.
4. Weight quantization and KV quantization use different Hessians. Weight
   quantization uses a calibration Hessian; KV quantization uses runtime
   attention/KV curvature. Do not collapse `T_K` into Lattice-Wyner-Ziv or into
   the Babai/GPTQ weight lane.
5. The WBO post-correction is softmax-1/2: the ledger records pre-softmax
   contributions, then applies the 1/2 contraction after numerical correction.
   `T_num` is tracked as a numerical post-correction guard, not a seventh
   semantic WBO-6 term.

## Register

| Memory tier | Codec / representation | Side information | WBO term(s) | Falsifier / verifier | Canonical caveat |
|---|---|---|---|---|---|
| L0 RAM hot | Exact fp16/bf16 KV and residual stream | None beyond live model state | `T_num` only | `F-WBO-DriftLedger` plus per-token KL witness | Exact hot state is the reference path. It can pay numerical drift, but it must not hide codec error. |
