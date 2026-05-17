# Tropical-IR — Source Custody Verification Status

**Created:** 2026-05-17 (T5 Phase A iter-4 skeleton).
**Authority:** §4.I:898-900 of `docs/CODEX_DEEP_INVESTIGATION_PROMPT_2026_05_16.md`.
**Doctrine cross-link:** `docs/fusion/PRIMITIVE_IR_STACK_DOCTRINE_2026_05_17.md` §2.2.

## Primary sources

| Source | Vendoring status | Hash status | Lean-cert status |
|---|---|---|---|
| Zhang, Naitzat, Lim — "Tropical Geometry of Deep Neural Networks", arXiv:1805.07091 (ICML 2018); Thm 5.4 the universality result | not vendored (iter-5+) | pending | pending (Phase C) |
| Charisopoulos, Maragos — "A Tropical Approach to Neural Networks with Piecewise Linear Activations", arXiv:1805.08749; §3 the explicit ReLU-to-`(max,+)` compilation | **cited** in claims.yaml + tropical_ir/grammar.rs header (iter-18 + iter-20) | pending vendor pass | pending (Phase C) |
| Maclagan, Sturmfels — "Introduction to Tropical Geometry", AMS GSM 161 (2015); algebra background | **cited** in claims.yaml + tropical.rs header lines 9-10 (iter-20 closure of iter-6 §6.1 pending entry) | pending vendor pass | pending (Phase C) |

## Reconciliation note

`agent_core/src/research/tropical.rs` (594 LOC, flat file) **predates**
the §4.I scope-lock requirement for a `tropical_ir/` directory module.
Iter-6 lands the move-and-re-export plan (audit §9.1 Option B, user-
confirmed via meta-message). This `research_custody/tropical/` folder
is independent of the Rust-module reconciliation.

## Verification gates

- **B2 acceptance** (§4.I:891): small ReLU network compiles byte-equal
  to `TropicalRational` form. Status: **pending** (Phase B2).
- **Semiring-axiom Lean certificate** (doctrine §5 acceptance bar):
  associativity + commutativity of `max`; distributivity of `+` over
  `max`; idempotence `max(x, x) = x`. Status: **pending** (Phase B2 +
  Phase C).
