# Cross-IR Composition Lattice — Live Status — 2026-05-17 (Terminal T5, iter-69)

Companion to `CROSS_IR_COMPOSITION_EXAMPLES_2026_05_17.md` (iter-56,
the blueprint). This doc is the **live tracker** of which doctrine
§6.2 arrows are wired in code at HEAD, updated as Phase C iters
land.

**HEAD at iter-69:** `f54c5a75e` (iter-68 closure_tanh).

---

## 1. Live status table (doctrine §6.2 arrows)

| # | Arrow | Status | Wiring location |
|---:|---|---|---|
| 1 | Operator → Scan | ⏳ Phase C | not yet wired; doctrine §6.2 row 1 |
| 2 | Operator → EML | ⏳ Phase C | needs complex-valued EML evaluation |
| 3 | **Operator → Fourier** | ✅ **WIRED** | `agent_core/src/research/operator_ir/fourier_kernel.rs::fno_spectral_block` (iter-38) |
| 4 | Scan → Info | 🟢 code-pattern | user-side composition via `info_ir::evaluate_scalar` + `scan_ir::sequential_scan` |
| 5 | **Info → EML** (softplus + sigmoid) | ✅ **WIRED** | `tests/cross_ir_info_to_eml.rs::softplus_via_eml` (iter-59) + closure_sigmoid matching `info_ir::dual_map(Bernoulli)` (iter-67) |
| 6 | **Tropical → EML** (log-sum-exp) | ✅ **WIRED** | `tests/cross_ir_tropical_to_eml.rs::lse_via_eml` (iter-63) |
| 7 | Tropical → Scan | 🟢 code-pattern | max-plus scan example in iter-56 doc §7 |
| 8 | Geometry → EML | ⏳ Phase C | needs complex-valued EML (rotor = `exp(-θB/2)` Euler decomposition) |
| 9 | Geometry → Info | ⏳ Phase C | Fisher metric via geometric product |

**Wired today: 3/9 (with arrow #5 doubly wired via softplus + sigmoid).**
Code-pattern composable: 2/9. Phase C remaining: 4/9.

## 2. Tropical-IR expressivity bonus (iters 61-62)

Beyond the lattice arrows, iter-61 + iter-62 closed §4.I:907
**for the full Zhang/Naitzat/Lim Thm 5.4 case** (general rational
weights):

- iter-61: `TropicalExpr::Scale(f64, Box<TropicalExpr>)` variant —
  enables real-multiplication inside the AST.
- iter-62: `compile_real_relu_layer(&RealReluLayer) → Vec<TropicalExpr>`
  with byte-equal property test on a 3×3 fixture.

Before: binary-weight ReLU compile (iter-21 MVP).
After: general rational-weight ReLU compile.

## 3. Phase C extensions delivered so far

Per iter-49 punch-list + iter-56 §11 Phase C extension list:

| # | Extension | Status | Iter |
|---:|---|---|---|
| 1 | Plus in EmlClosureExpr | ✅ | 57 |
| 2 | Minus in EmlClosureExpr | ✅ | 58 |
| 3 | Scale in TropicalExpr | ✅ | 61 |
| 4 | compile_real_relu_layer (uses Scale) | ✅ | 62 |
| 5 | Info→EML softplus wiring | ✅ | 59 |
| 6 | Tropical→EML lse wiring | ✅ | 63 |
| 7 | closure_builders library extraction | ✅ | 65 |
| 8 | Divide in EmlClosureExpr | ✅ | 66 |
| 9 | closure_sigmoid + Info dual_map wiring | ✅ | 67 |
| 10 | closure_tanh + sigmoid-tanh identity | ✅ | 68 |
| 11 | Complex-valued EML evaluation | ⏳ Phase C | needs `num-complex` |
| 12 | Multi-layer Network in Operator-IR | ⏳ Phase C | future |
| 13 | OxiEML vendoring | ⏳ Phase C | needs network |
| 14 | Lean toolchain pin verification | ⏳ Phase C | needs Lean 4.29.1 |

**10 of 14 Phase C extensions delivered autonomously.**

## 4. closure_builders helper inventory (iter-65 + iter-67-68)

Reusable EmlClosureExpr-construction helpers in
`agent_core/src/research/eml/closure_builders.rs`:

| Function | Encoding | Iter |
|---|---|---|
| `closure_zero()` | `Minus(One, One)` | 65 |
| `closure_exp(idx)` | `eml(Slot(idx), One)` | 65 |
| `closure_ln(y)` | `Minus(One, eml(zero, y))` | 65 |
| `closure_lse(args)` | `closure_ln(Plus chain of args)` | 65 |
| `closure_softplus(idx)` | `closure_ln(Plus(One, closure_exp(idx)))` | 65 |
| `closure_neg_slot(idx)` | `Minus(zero, Slot(idx))` | 67 |
| `closure_neg_exp(idx)` | `eml(neg_slot(idx), One)` | 67 |
| `closure_sigmoid(idx)` | `Divide(One, Plus(One, neg_exp(idx)))` | 67 |
| `closure_tanh(idx)` | `Divide(Minus(exp, neg_exp), Plus(exp, neg_exp))` | 68 |

**9 helpers covering the canonical-activation + exp-family-log-partition
identities.** 31 tests verify each helper + cross-helper identities
(e.g. `tanh(x) = 2·sigmoid(2x) - 1` at iter-68; `closure_sigmoid` ≡
`info_ir::dual_map(Bernoulli)` at iter-67).

## 5. Cross-IR integration test surface

Total integration tests at `agent_core/tests/`:

| File | Iter | Tests | Purpose |
|---|---:|---:|---|
| `eml_ir_corpus_round_trip.rs` | 14-15 | 7 | §4.I:906 ≥80% corpus closure |
| `scan_ir_ssd_match.rs` | 27 | 6 | §4.I:892 SSD ≡ sequential |
| `info_ir_logistic_mirror.rs` | 33 | 5 | §4.I:893 logistic bit-exact |
| `operator_ir_fno_equiv.rs` | 39 | 5 | §4.I:894 FNO equivalence |
| `geometry_ir_rotor.rs` | 45 | 6 | §4.I:895 identity + composition |
| `cross_ir_info_to_eml.rs` | 59 | 8 | Info → EML softplus |
| `cross_ir_tropical_to_eml.rs` | 63 | 8 | Tropical → EML log-sum-exp |

**45 integration tests total, all green** under `--features research`.

## 6. Closure-form arithmetic completeness

After iters 57/58/66 (Plus + Minus + Divide), the EmlClosureExpr
term algebra has SIX variants:

```text
EmlClosureExpr ::= One
                |  Slot(u32)
                |  Eml(Box, Box)
                |  Plus(Box, Box)
                |  Minus(Box, Box)
                |  Divide(Box, Box)
```

This is sufficient to encode **any rational function of
elementary terms** — every closed-form expression in
exp/ln/inputs/constants with finite arithmetic. The bare
[`EmlExpr`] grammar stays `S → 1 | eml(S, S)` per Stachowiak
canonical form.

## 7. Lessons learned

1. **Closure-form is the right place for additions** (Plus, Minus,
   Divide). The bare EmlExpr grammar stays Stachowiak-clean; the
   closure form's added expressivity unblocks every composition
   arrow we've wired so far.
2. **Adding enum variants requires `cargo test --features research`
   in the iter loop** — default cargo test doesn't compile
   feature-gated `match` expressions. iter-61 caught this hard;
   subsequent iters (57/58/66) all included the smoke check.
3. **Helper extraction (closure_builders) compounds value.** iters
   59 + 63 each hand-rolled the encoding; iters 65-68 abstracted
   into reusable functions. Iters 67 + 68 reused the helpers and
   landed in ~1 turn each instead of ~2.
4. **Cross-helper identities verify correctness.** Iter-68's
   `tanh(x) = 2·sigmoid(2x) - 1` test caught any drift between
   the two helper families.

---

**Co-Authored-By:** Codex (T5) <noreply@anthropic.com>
