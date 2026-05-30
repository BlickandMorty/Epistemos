# Geometry-IR — Source Custody Verification Status

**Created:** 2026-05-17 (T5 Phase A iter-4 skeleton).
**Authority:** §4.I:898-900 of `docs/CODEX_DEEP_INVESTIGATION_PROMPT_2026_05_16.md`.
**Doctrine cross-link:** `docs/fusion/PRIMITIVE_IR_STACK_DOCTRINE_2026_05_17.md` §2.6.

## Primary sources

| Source | Vendoring status | Hash status | Lean-cert status |
|---|---|---|---|
| Hestenes, Sobczyk — "Clifford Algebra to Geometric Calculus: A Unified Language for Mathematics and Physics" (Reidel 1984); Ch. 1 geometric-product axioms | not vendored (iter-5+; book) | pending | pending (Phase C) |
| Dorst, Fontijne, Mann — "Geometric Algebra for Computer Science" (Morgan Kaufmann 2007); §10.3 rotor sandwich + algorithms | not vendored (iter-5+; book) | pending | pending (Phase C) |

## Verification gates

- **B6 acceptance** (§4.I:895): identity rotation returns input
  unchanged + composition law for rotor sandwich. Status: **pending**
  (Phase B6).
- **Clifford-algebra axiom Lean certificate** (doctrine §5):
  `e_i² = 1`, `e_i e_j = −e_j e_i` for `i ≠ j`. Status: **pending**
  (Phase B6 + Phase C).
