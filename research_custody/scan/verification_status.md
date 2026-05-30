# Scan-IR — Source Custody Verification Status

**Created:** 2026-05-17 (T5 Phase A iter-4 skeleton).
**Authority:** §4.I:898-900 of `docs/CODEX_DEEP_INVESTIGATION_PROMPT_2026_05_16.md`.
**Doctrine cross-link:** `docs/fusion/PRIMITIVE_IR_STACK_DOCTRINE_2026_05_17.md` §2.3.

## Primary sources

| Source | Vendoring status | Hash status | Lean-cert status |
|---|---|---|---|
| Dao, Gu — "Transformers are SSMs: Generalized Models and Efficient Algorithms Through Structured State Space Duality", arXiv:2405.21060 (ICML 2024); §6 the SSD algorithm | not vendored (iter-5+) | pending | pending (Phase C) |
| Blelloch — "Prefix Sums and Their Applications", CMU-CS-90-190 (1990); the associative-operator-over-monoid parallel-scan abstraction | not vendored (iter-5+) | pending | pending (Phase C) |

## T3 coordination

Per driver SCOPE LOCK + §4.G: Scan-IR exports the typed AST that
T3's **F-SemiseparableBlockScan-Correctness** gate consumes. T3 owns
the falsifier oracle (Dao/Gu reference SSD scan + a fixture sequence).
Scan-IR's contract: produce a Scan-IR AST whose Dao/Gu lowering
matches the oracle byte-equal.

## Verification gates

- **B3 acceptance** (§4.I:892): Mamba-2 reference scan matches
  Scan-IR scan on a fixture sequence. Status: **pending** (Phase B3).
- **T3 F-SemiseparableBlockScan-Correctness gate**: blocks if Scan-IR
  AST + Dao/Gu lowering disagrees with oracle. Status: **gate not yet
  wired**.
- **Monoid-associativity Lean certificate** (doctrine §5): per
  state-transition `⊕`. Status: **pending** (Phase B3 + Phase C).
