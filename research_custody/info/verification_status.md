# Info-IR — Source Custody Verification Status

**Created:** 2026-05-17 (T5 Phase A iter-4 skeleton).
**Authority:** §4.I:898-900 of `docs/CODEX_DEEP_INVESTIGATION_PROMPT_2026_05_16.md`.
**Doctrine cross-link:** `docs/fusion/PRIMITIVE_IR_STACK_DOCTRINE_2026_05_17.md` §2.5.

## Primary sources

| Source | Vendoring status | Hash status | Lean-cert status |
|---|---|---|---|
| Amari — "Information Geometry and Its Applications" (Springer 2016); Ch. 2 (exp families + dual coordinates), Ch. 6 (Bregman divergences) | not vendored (iter-5+; book, not arXiv) | pending | pending (Phase C) |
| Beck, Teboulle — "Mirror descent and nonlinear projected subgradient methods for convex optimization", Operations Research Letters 31:167-175 (2003) | not vendored (iter-5+) | pending | pending (Phase C) |

## T2 coordination

Per driver-prompt COORDINATION clause: T2 consumes Info-IR's typed
`(P, Q) → kl_projection` primitive for `AnswerPacket.confidence`.
Info-IR's contract: export `KlProjection` as a typed function over
distribution-pairs; T2 wires it in once Phase B4 closes.

## Verification gates

- **B4 acceptance** (§4.I:893): logistic regression converges
  identically through Info-IR mirror descent vs raw mirror descent.
  Status: **pending** (Phase B4).
- **Bregman-positivity Lean certificate** (doctrine §5):
  `B(P, Q) ≥ 0` with equality iff `P = Q`. Status: **pending** (Phase
  B4 + Phase C).
- **AnswerPacket.confidence integration test** (T2 cross-link):
  blocks until Info-IR MVP closes.
