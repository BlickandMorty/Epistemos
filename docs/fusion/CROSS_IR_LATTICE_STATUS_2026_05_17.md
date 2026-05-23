# Cross-IR Composition Lattice — Live Status — 2026-05-17 (Terminal T5, iter-96)

Companion to `CROSS_IR_COMPOSITION_EXAMPLES_2026_05_17.md` (iter-56,
the blueprint). This doc is the **live tracker** of which doctrine
§6.2 arrows are wired in code at HEAD, updated as Phase C iters
land.

**HEAD at iter-96:** `9decdd92e` (Geometry → Info Fisher metric).

---

## 1. Live status table (doctrine §6.2 arrows)

| # | Arrow | Status | Wiring location |
|---:|---|---|---|
| 1 | **Operator → Scan** | ✅ **WIRED** | `tests/cross_ir_operator_to_scan.rs` (iter-93) |
| 2 | Operator → EML | ⏳ Phase C | needs complex-valued EML evaluation |
| 3 | **Operator → Fourier** | ✅ **WIRED** | `agent_core/src/research/operator_ir/fourier_kernel.rs::fno_spectral_block` (iter-38) |
| 4 | **Scan → Info** | ✅ **WIRED** | `tests/cross_ir_scan_to_info.rs` (iter-95) — streaming Bayesian inference |
| 5 | **Info → EML** (all 3 families) | ✅ **WIRED** | `tests/cross_ir_info_to_eml.rs` (iter-59) + 3 complete Bregman trios across closure_builders (iters 67/68/70/72-77) |
| 6 | **Tropical → EML** (log-sum-exp) | ✅ **WIRED** | `tests/cross_ir_tropical_to_eml.rs::lse_via_eml` (iter-63) |
| 7 | **Tropical → Scan** | ✅ **WIRED** | `tests/cross_ir_tropical_to_scan.rs` (iter-94) — TropicalExpr trees as scan step combinators |
| 8 | Geometry → EML | ⏳ Phase C | needs complex-valued EML (rotor = `exp(-θB/2)` Euler decomposition) |
| 9 | **Geometry → Info** | ✅ **WIRED** | `tests/cross_ir_geometry_to_info.rs` (iter-96) — Fisher metric as Riemannian inner product on tangent multivectors |

**Wired today: 8/9.** Only arrows #2 and #8 remain (both
require complex-valued EML; deferred to Phase C with external
deps like `num-complex`).

## 2. Closure-form arithmetic completeness

After iters 57/58/66/70, the EmlClosureExpr term algebra has SEVEN variants:

```text
EmlClosureExpr ::= One
                |  Slot(u32)
                |  Eml(Box, Box)
                |  Plus(Box, Box)
                |  Minus(Box, Box)
                |  Divide(Box, Box)
                |  Mul(Box, Box)
```

This expresses **any rational function of elementary terms** in
exp/ln/inputs/constants with finite arithmetic. The bare
[`EmlExpr`] grammar stays `S → 1 | eml(S, S)` per Stachowiak
canonical form.

## 3. closure_builders helper inventory (44+ helpers, iters 65–88)

Reusable EmlClosureExpr-construction helpers in
`agent_core/src/research/eml/closure_builders.rs`:

### Information-theoretic
| Function | Iter |
|---|---:|
| `closure_zero` | 65 |
| `closure_exp(idx)` / `closure_ln(y)` / `closure_lse(args)` | 65 |
| `closure_softplus(idx)` | 65 |
| `closure_neg_slot(idx)` / `closure_neg_exp(idx)` | 67 |
| `closure_sigmoid(idx)` | 67 |
| `closure_tanh(idx)` | 68 |
| `closure_mul(a, b)` | 70 |
| `closure_kl_bernoulli(p, q)` | 70 |
| `closure_categorical_log_partition(slots)` | 72 |
| `closure_categorical_softmax_slot/pinned` | 73 |
| `closure_kl_categorical(p_slots, q_slots)` | 74 |
| `closure_gaussian_log_partition(θ, σ²)` | 75 |
| `closure_gaussian_dual_map(θ, σ²)` | 76 |
| `closure_kl_gaussian(p, q, σ²)` | 77 |
| `closure_bernoulli_log_prob_one/zero(θ)` | 78 |
| `closure_categorical_log_prob_slot/pinned` | 78 |
| `closure_cross_entropy_bernoulli(target, θ)` | 79 |
| `closure_neg_log_likelihood_categorical_slot/pinned` | 79 |
| `closure_entropy_bernoulli(θ)` | 82 |
| `closure_entropy_categorical(slots)` | 82 |
| `closure_logit(p)` | 86 |
| `closure_softmax_temperature_slot/pinned(target, slots, β)` | 86 |

### Activations
| Function | Iter |
|---|---:|
| `closure_swish/silu/mish/smooth_relu(x)` | 80 |
| `closure_glu/swiglu/reglu(x, gate)` | 81 |
| `closure_sigmoid_scaled(x, β)` | 83 |
| `closure_swish_scaled(x, β)` | 83 |
| `closure_gelu_sigmoid_approx(x, c)` | 83 |
| `closure_smooth_max/smooth_min(slots, β)` | 84 |

### Normalization
| Function | Iter |
|---|---:|
| `closure_residual_add(x, r)` | 88 |
| `closure_center(x, μ)` | 88 |
| `closure_standardize(x, μ, σ)` | 88 |
| `closure_affine(x, γ, β)` | 88 |
| `closure_layer_norm(x, μ, σ, γ, β)` | 88 |

**~50 helpers** spanning Info-IR Bregman trios (all 3 exp-families),
neural activations (swish/mish/GLU/SwiGLU/ReGLU/GELU-approx),
temperature controls (sigmoid_scaled, swish_β, softmax_T, smooth_max/min),
and transformer-block patterns (LayerNorm decomposition + residuals).

## 4. Per-IR extension inventory (iters 84–95)

### Geometry-IR (iter-85)
- `geo_dot(a, b)`, `geo_wedge(a, b)`, `reflect_vector(v, n)`
- `Multivector::norm_squared() / norm() / sub() / is_approximately_unit_rotor()`

### Tropical-IR (iter-87)
- `TropicalExpr::min(args)` via `-max(-args)` duality
- `compile_max_pool(input_dim, window, stride)` — neural max-pool as
  pure (max, +) trees
- `evaluate_max_pool_directly` — property-test oracle

### Operator-IR (iter-89)
- `LinearNetwork::weights() / biases()` accessors
- `compose_linear_layers(l1, l2)` — algebraic fusion W = W2·W1
- `evaluate_with_residual(network, input)` — ResNet / transformer skip
- `transpose_linear_layer(network)` — adjoint linear map

### Scan-IR (iter-90)
- `running_sum/max/min/product/mean(program)` — f64 wrappers

### Info-IR (iters 91–92)
- `entropy(family, theta)` — Fenchel duality form
- `cross_entropy(family, p, q) = H(P) + KL(P || Q)`
- `js_divergence(family, p, q)`
- `fisher_information(family, theta)` — Hessian of A(θ),
  Cov_θ[T(X)], the Riemannian metric

## 5. Cross-IR integration test surface

Total integration tests at `agent_core/tests/`:

| File | Iter | Tests | Lattice arrow | Purpose |
|---|---:|---:|---:|---|
| `eml_ir_corpus_round_trip.rs` | 14-15 | 7 | — | §4.I:906 ≥80% corpus closure |
| `scan_ir_ssd_match.rs` | 27 | 6 | — | §4.I:892 SSD ≡ sequential |
| `info_ir_logistic_mirror.rs` | 33 | 5 | — | §4.I:893 logistic bit-exact |
| `operator_ir_fno_equiv.rs` | 39 | 5 | — | §4.I:894 FNO equivalence |
| `geometry_ir_rotor.rs` | 45 | 6 | — | §4.I:895 identity + composition |
| `cross_ir_info_to_eml.rs` | 59 | 8 | #5 | Info → EML softplus |
| `cross_ir_tropical_to_eml.rs` | 63 | 8 | #6 | Tropical → EML log-sum-exp |
| `cross_ir_operator_to_scan.rs` | 93 | 6 | #1 | Recurrent linear over scan |
| `cross_ir_tropical_to_scan.rs` | 94 | 7 | #7 | TropicalExpr as scan step |
| `cross_ir_scan_to_info.rs` | 95 | 7 | #4 | Streaming Bayesian |
| `cross_ir_geometry_to_info.rs` | 96 | 8 | #9 | Fisher metric on tangents |

**73 integration tests total**, all green under `--features research`.

## 6. Lessons learned

1. **Closure-form is the right place for additions** (Plus, Minus,
   Divide, Mul). The bare EmlExpr grammar stays Stachowiak-clean;
   the closure form's added expressivity unblocked every composition
   arrow we've wired so far.
2. **Adding enum variants requires `cargo test --features research`
   in the iter loop** — default cargo test doesn't compile
   feature-gated `match` expressions. iter-61 caught this hard;
   subsequent iters (57/58/66/70) all included the smoke check.
3. **Helper extraction (closure_builders) compounds value.** Iters
   59 + 63 each hand-rolled the encoding; iters 65–88 abstracted
   into reusable functions. Iters 67 + 68 + 70 reused the helpers and
   landed in ~1 turn each instead of ~2.
4. **Cross-helper identities verify correctness.** Iter-68's
   `tanh(x) = 2·sigmoid(2x) - 1` test caught any drift between
   the two helper families.
5. **Cross-IR arrows wire fast once primitives are in place.**
   Iters 93–96 wired four lattice arrows in a single session
   (each: 6–8 integration tests, ~150 LOC each). The IRs were
   already composable in principle; the tests just made it
   first-class.
6. **info_ir::kl_divergence uses anchor-at-q Bregman convention**
   (A(p) - A(q) - η_q·(p-q)) which mathematically corresponds to
   KL(Q || P), not KL(P || Q). Iter-91 surfaced this; the project
   convention is preserved for byte-equality with all closure_kl_*
   helpers.

## 7. Phase C extensions delivered (iters 57–96)

| # | Extension | Status | Iter |
|---:|---|---|---:|
| 1 | Plus / Minus / Divide / Mul in EmlClosureExpr | ✅ | 57/58/66/70 |
| 2 | Scale in TropicalExpr + compile_real_relu_layer | ✅ | 61/62 |
| 3 | closure_builders library extraction (~50 helpers) | ✅ | 65-88 |
| 4 | All 3 Info-IR Bregman trios (Bernoulli/Cat/Gauss) | ✅ | 70/74/77 |
| 5 | Modern activations (swish/mish/GLU/SwiGLU/GELU≈) | ✅ | 80/81/83 |
| 6 | Temperature controls + softmax-T | ✅ | 83/84/86 |
| 7 | LayerNorm decomposition primitives | ✅ | 88 |
| 8 | Geometry: geo_dot/geo_wedge/reflect/norm | ✅ | 85 |
| 9 | Tropical: min + compile_max_pool | ✅ | 87 |
| 10 | Operator: compose / transpose / residual | ✅ | 89 |
| 11 | Scan: running_sum/max/min/product/mean | ✅ | 90 |
| 12 | Info: entropy/CE/JS/Fisher information | ✅ | 91/92 |
| 13 | **Lattice arrows wired**: 4 new (#1, #4, #7, #9) | ✅ | 93-96 |
| 14 | Complex-valued EML evaluation | ⏳ Phase C | needs `num-complex` |
| 15 | OxiEML vendoring | ⏳ Phase C | needs network |
| 16 | Lean toolchain pin verification | ⏳ Phase C | needs Lean 4.29.1 |
| 17 | PDF source custody vendoring | ⏳ Phase C | needs network |

**13 of 17 Phase C extensions delivered autonomously.**

---

**Co-Authored-By:** Codex (T5) <noreply@anthropic.com>
