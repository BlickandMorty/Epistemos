# Operator-IR — Source Custody Verification Status

**Created:** 2026-05-17 (T5 Phase A iter-4 skeleton).
**Authority:** §4.I:898-900 of `docs/CODEX_DEEP_INVESTIGATION_PROMPT_2026_05_16.md`.
**Doctrine cross-link:** `docs/fusion/PRIMITIVE_IR_STACK_DOCTRINE_2026_05_17.md` §2.4.

## Primary sources

| Source | Vendoring status | Hash status | Lean-cert status |
|---|---|---|---|
| Lu, Jin, Karniadakis — "Learning nonlinear operators via DeepONet based on the universal approximation theorem of operators", arXiv:1910.03193 (Nat. Mach. Intell. 2021); Thm 2 universality | not vendored (iter-5+) | pending | pending (Phase C) |
| Li, Kovachki, Azizzadenesheli, Liu, Bhattacharya, Stuart, Anandkumar — "Fourier Neural Operator for Parametric Partial Differential Equations", arXiv:2010.08895 (ICLR 2021); §3 the Fourier-kernel lowering | not vendored (iter-5+) | pending | pending (Phase C) |

## Verification gates

- **B5 acceptance** (§4.I:894): a small FNO matches Operator-IR
  forward pass within float tolerance. Status: **pending** (Phase B5).
- **Branch-trunk dimensional-consistency Lean certificate** (doctrine
  §5): `branch_output_dim == trunk_output_dim` discharged at the type
  level. Status: **pending** (Phase B5 + Phase C).
