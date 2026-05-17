# Cross-IR Composition Lattice — Live Status — 2026-05-17 (Terminal T5, iter-64)

Companion to `CROSS_IR_COMPOSITION_EXAMPLES_2026_05_17.md` (iter-56,
the blueprint). This doc is the **live tracker** of which doctrine
§6.2 arrows are wired in code at HEAD, updated as Phase C iters
land.

**HEAD at iter-64:** `0584cf19a` (iter-63 cross-IR Tropical→EML).

---

## 1. Live status table

| # | Arrow | Status | Wiring location |
|---:|---|---|---|
| 1 | Operator → Scan | ⏳ Phase C | not yet wired; doctrine §6.2 row 1 |
| 2 | Operator → EML | ⏳ Phase C | needs complex-valued EML evaluation |
| 3 | **Operator → Fourier** | ✅ **WIRED** | `agent_core/src/research/operator_ir/fourier_kernel.rs::fno_spectral_block` (iter-38) |
| 4 | Scan → Info | 🟢 code-pattern | user-side composition via `info_ir::evaluate_scalar` + `scan_ir::sequential_scan` |
| 5 | **Info → EML** | ✅ **WIRED** | `tests/cross_ir_info_to_eml.rs::softplus_via_eml` (iter-59) |
| 6 | **Tropical → EML** | ✅ **WIRED** | `tests/cross_ir_tropical_to_eml.rs::lse_via_eml` (iter-63) |
| 7 | Tropical → Scan | 🟢 code-pattern | max-plus scan example in iter-56 doc §7 |
| 8 | Geometry → EML | ⏳ Phase C | needs complex-valued EML (rotor = `exp(-θB/2)` Euler decomposition) |
| 9 | Geometry → Info | ⏳ Phase C | Fisher metric via geometric product |

**Wired today: 3/9.** Code-pattern composable: 2/9. Phase C remaining:
4/9.

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
| 5 | Info→EML composition wiring | ✅ | 59 |
| 6 | Tropical→EML composition wiring | ✅ | 63 |
| 7 | Complex-valued EML evaluation | ⏳ Phase C | needs `num-complex` |
| 8 | Multi-layer Network in Operator-IR | ⏳ Phase C | future |
| 9 | OxiEML vendoring | ⏳ Phase C | needs network |
| 10 | Lean toolchain pin verification | ⏳ Phase C | needs Lean 4.29.1 |

**6 of 10 Phase C extensions delivered autonomously.**

## 4. Cross-IR integration test surface

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

## 5. Closure-form reusability pattern

Iters 59 + 63 used the **same** Plus/Minus/Eml/Slot pattern to
encode functions that EML's bare grammar can't express:

```
ln(y) = Minus(One, eml(Minus(One, One), y))    -- the "ln-via-eml" idiom
exp(θ) = eml(Slot(θ), One)                     -- the "exp-via-eml" idiom

softplus(θ) = ln(1 + exp(θ))
            = Minus(One, eml(0, Plus(One, eml(Slot(0), One))))

lse(a, b)   = ln(exp(a) + exp(b))
            = Minus(One, eml(0, Plus(eml(Slot(0), One),
                                     eml(Slot(1), One))))
```

The shared idioms `ln-via-eml` and `exp-via-eml` are the building
blocks for any Phase C cross-IR arrow that needs `ln`, `exp`, or
`+`/`−`. Geometry → EML's rotor exp will follow the same template
once complex-valued EML lands.

## 6. Lessons learned

1. **Closure-form is the right place for additions** (Plus, Minus).
   The bare EmlExpr grammar (`S → 1 | eml(S,S)`) stays
   Stachowiak-clean; the closure form's added expressivity unblocks
   composition arrows.
2. **Adding enum variants requires `cargo test --features research`
   in the iter loop** — default cargo test doesn't compile
   feature-gated `match` expressions. iter-61 caught this the hard
   way; documented for future Phase C work.
3. **The lattice is realizable in tight slices.** 6 Phase C
   extensions + 2 composition wirings landed in 7 iters (57-63),
   averaging ~1 hour of total work per slice including build +
   commit + push.

---

**Co-Authored-By:** Codex (T5) <noreply@anthropic.com>
