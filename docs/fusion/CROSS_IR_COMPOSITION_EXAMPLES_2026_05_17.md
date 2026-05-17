# Cross-IR Composition Examples — 2026-05-17 (Terminal T5, iter-56)

Doctrine `PRIMITIVE_IR_STACK_DOCTRINE_2026_05_17.md` §6.2 names 9
cross-IR composition arrows. This doc makes them concrete: for each
arrow, the math statement + current-state code pattern using T5's
shipped APIs + the Phase C realization plan.

**Convention.** Arrow `A → B` means *A consumes B* (B is more
primitive). Code examples assume `--features research`.

---

## 1. Operator-IR → Scan-IR

**Math.** PDE / SSM time-stepping is a parallel-prefix scan over a
state monoid. An `Operator(branch, trunk, Identity)` lowering where
the trunk discretizes time reduces to a `scan(⊕_state, …)`.

**Current state.** Both IRs exist; the composition isn't wired in
code today.

**Phase C realization.**

```rust,ignore
use agent_core::research::operator_ir::OperatorExpr;
use agent_core::research::scan_ir::{sequential_scan, ScanProgram};

// 1. Given an Operator-IR with time-discretized trunk:
let op: OperatorExpr = ...;

// 2. Pre-compute branch (function-space) output once.
let u = vec![...];
let b = evaluate_linear(&op.branch, &u).unwrap();

// 3. Build a ScanProgram with the time steps as inputs.
let times = vec![0.0, 0.1, 0.2, ...];
let prog = ScanProgram::new(b.clone(), times);

// 4. Scan with the operator's state-transition rule.
let trajectory = sequential_scan(&prog, |state, t| {
    // operator-defined time-step op
    ...
});
```

## 2. Operator-IR → EML-IR

**Math.** Spectral coefficients of the Fourier kernel are closed-form
elementary functions; the FNO Fourier block evaluates `exp(i·2π·k·x)`
through EML-IR's `eml(x, y)` primitive (Euler's identity
decomposed).

**Current state.** B5 ships the Fourier kernel as a sin/cos DFT
implementation in `fourier_kernel.rs` — it computes exactly `exp(i·2π·k·x)`
spectral coefficients via Rust's `f64::cos` and `f64::sin`. The
EML-IR primitive `eml(x, 1)` is mathematically equivalent to `exp(x)` but
the FNO block doesn't currently route through it.

**Phase C realization.**

Replace the DFT's `arg.cos()` + `arg.sin()` calls with EML-IR-emitted
closures over `exp(x)` and `exp(-x)`:

```rust,ignore
// Euler: exp(iθ) = cos(θ) + i sin(θ)
// In real (cos, sin) form: cos(θ) = (exp(iθ) + exp(-iθ)) / 2
//                          sin(θ) = (exp(iθ) - exp(-iθ)) / (2i)
//
// EML-IR's eml(θ, 1) = exp(θ) - ln(1) = exp(θ); so cos(θ) can be
// realized as (eml(iθ, 1) + eml(-iθ, 1)) / 2 once complex-valued
// EML evaluation lands (Phase C+).
```

## 3. Operator-IR → Fourier transform

**Math.** DFT/FFT as an external kernel. **WIRED today.**

**Code.**

```rust
# #![cfg(feature = "research")]
use agent_core::research::operator_ir::{dft, fno_spectral_block, idft_real};

// Forward DFT.
let x = vec![1.0, 0.5, -0.5, -1.0];
let spec = dft(&x);

// Truncate to 2 modes + inverse.
let smoothed = fno_spectral_block(&x, 2);
assert_eq!(smoothed.len(), x.len());

// Round-trip without truncation.
let full = fno_spectral_block(&x, x.len());
for (a, b) in x.iter().zip(&full) {
    assert!((a - b).abs() < 1e-9);
}

// Direct IDFT.
let recovered = idft_real(&spec);
```

## 4. Scan-IR → Info-IR

**Math.** Sequential Bayesian update is a scan with `kl_projection`
as the state-transition `⊕`. Info-IR's typed `KlProjection` primitive
is the building block; Scan-IR composes a sequence of updates.

**Current state.** Info-IR's `KlProjection` is the typed primitive;
Scan-IR's `ScanProgram<T>` is generic over the state carrier.
Composition is straightforward in user code.

**Sketch.**

```rust,ignore
use agent_core::research::info_ir::{kl_divergence, ExpFamily};
use agent_core::research::scan_ir::{sequential_reduce, ScanProgram};

// Each step's "input" is an observation; the state is the
// posterior natural parameters.
let prog = ScanProgram::new(prior_params.clone(), observations);
let posterior = sequential_reduce(&prog, |theta, obs| {
    // Bayesian update: minimize KL to the prior-plus-likelihood.
    // (Full update kernel = Phase C.)
    update_step(theta, obs)
});
```

## 5. Info-IR → EML-IR

**Math.** Closed-form log-partition for Bernoulli is softplus(θ) =
ln(1 + exp(θ)). This decomposes through EML-IR's `eml(x, y) =
exp(x) − ln(y)` primitive, but requires addition in the AST.

**Current state.** Info-IR's `log_partition(&ExpFamily::Bernoulli, &[θ])`
computes the value directly via Rust's `f64::exp` + `f64::ln`. The
math equivalence to EML-IR exists conceptually; routing the
computation through EML-IR's evaluator requires an extended AST
(see §11 Phase C extensions).

**Sketch (Phase C, requires Const arithmetic in EML AST):**

```text
softplus(θ) = ln(1 + exp(θ))
            = ln(eml(θ, 1) + eml(0, 1))     [eml(θ,1)=exp(θ), eml(0,1)=1]
            = ?  -- needs a Plus node in EmlExpr
```

The cleanest path: extend `EmlExpr` with a `Plus(Box<EmlExpr>, Box<EmlExpr>)`
variant (or add an `EmlExt` enum), evaluate through closure form.

## 6. Tropical-IR → EML-IR

**Math.** Smoothmax `softmax_β(x) = (1/β) · log(Σ exp(β · x))` —
direct EML composition. As `β → ∞` it converges to the tropical
`max`. Useful for: smoothing Tropical-IR's hard `max` for autodiff
(when ReLU networks need gradient flow).

**Current state.** Conceptual.

**Sketch.**

```rust,ignore
// For β = 1, softmax([a, b]) = log(exp(a) + exp(b)) = log-sum-exp.
// EML's eml(a, 1) = exp(a); so log-sum-exp becomes a chain of
// eml's once the AST has Plus. Phase C.
```

## 7. Tropical-IR → Scan-IR

**Math.** Viterbi inference is a max-plus scan on a trellis. Scan-IR's
`scan(⊕, …)` with `⊕ := max` and the trellis transition cost is the
Viterbi path computation.

**Current state.** Both ingredients exist. The composition is a
direct application — example below uses both shipping APIs.

**Code.**

```rust
# #![cfg(feature = "research")]
use agent_core::research::scan_ir::{sequential_scan, ScanProgram};

// Trivial Viterbi: 1D path with transition cost = identity.
// state = current best score; input = log-prob of next transition;
// op = max + add.
let prog = ScanProgram::new(0.0_f64, vec![0.5_f64, -0.3, 1.2, -1.0]);
let trajectory = sequential_scan(&prog, |state, transition| state + *transition);

// trajectory = [0, 0.5, 0.2, 1.4, 0.4]
assert!((trajectory[trajectory.len() - 1] - 0.4_f64).abs() < 1e-12);
```

(Full max-plus Viterbi over a state lattice — Phase C.)

## 8. Geometry-IR → EML-IR

**Math.** Rotor exponential `R = exp(-B/2)` where `B` is a bivector.
The scalar exp is the EML-IR primitive (`eml(x, 1)`); composing it
with the bivector grade-2 structure produces the rotor.

**Current state.** B6's `rotor_from_angle_and_bivector` computes the
rotor directly via `f64::cos` + `f64::sin`. The math is
`R = cos(θ/2) + sin(θ/2)·B`, equivalent to `exp(-θB/2)` in Cl(3,0).
Routing through EML-IR for the cos/sin computation requires
complex-valued EML evaluation (Phase C).

**Sketch.**

```rust,ignore
// cos(θ/2) and sin(θ/2) via Euler: cos = (exp(iθ/2) + exp(-iθ/2))/2.
// With EML's eml(iθ/2, 1) = exp(iθ/2) (once complex domain lands),
// the rotor can be computed entirely through EML-IR primitives.
// Phase C.
```

## 9. Geometry-IR → Info-IR

**Math.** Fisher information metric is a Riemannian metric on a
statistical manifold; the Clifford-algebra exterior derivative
interacts with Info-IR's dual-coordinate map.

**Current state.** Conceptual. Most Phase C of all 9 arrows.

**Sketch.**

```text
For an exponential family with natural parameters θ ∈ ℝ^n:
  - Fisher metric g_ij(θ) = ∂²A(θ) / (∂θ_i ∂θ_j)
  - In geometric-algebra terms, g defines an inner product on the
    tangent space at θ.
Geometry-IR's GeoProduct provides the inner product structure;
Info-IR's dual_map(θ) is ∇A(θ); the Fisher metric falls out of the
geometric product of differentials. Phase C work.
```

---

## 10. Implementation-status summary

| Arrow | Status | Realization |
|---|---|---|
| Operator → Scan | conceptual | Phase C (time-step trunk) |
| Operator → EML | conceptual | Phase C (complex-valued EML for Euler) |
| **Operator → Fourier** | **WIRED** | iter-38 `fno_spectral_block` |
| Scan → Info | code-pattern | user-side composition works today |
| Info → EML | conceptual | Phase C (needs Plus in EmlExpr) |
| Tropical → EML | conceptual | Phase C (softmax via log-sum-exp) |
| **Tropical → Scan** | **code-pattern** | example above with max-plus scan |
| Geometry → EML | conceptual | Phase C (complex-valued EML) |
| Geometry → Info | conceptual | Phase C (Fisher metric via geometric product) |

**Wired today: 1/9. Code-pattern (no IR-internal wiring needed):
2/9. Phase C: 6/9.**

The lattice is *structurally* complete — every IR exports the
primitives consumers need — but most composition arrows need
either AST extensions (Plus, complex-valued evaluation) or
domain-specific business logic that doesn't belong in the IR
layer itself.

## 11. Phase C extensions that unblock the conceptual arrows

1. **Plus/Minus in `EmlExpr`** — unblocks arrows 5, 6, 8 (all
   require addition).
2. **Complex-valued EML evaluation** — unblocks arrows 2, 5, 6, 8.
3. **`ScaledLinear` or `Scale` in `TropicalExpr`** — unblocks arrow
   2 generalization (Zhang/Naitzat/Lim Thm 5.4 for non-binary
   weights).
4. **Multi-layer non-linear `Network`** in Operator-IR — extends
   the LinearNetwork to full DeepONet branch/trunk MLPs.
5. **Cargo dependency on `num-complex`** — for complex-valued EML.

Each is well-scoped and low-risk; Phase C iter-49+ can adopt them
in any order.

---

**Co-Authored-By:** Codex (T5) <noreply@anthropic.com>
