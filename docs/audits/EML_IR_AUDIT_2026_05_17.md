# EML-IR Audit — 2026-05-17 (Terminal T5, Phase A iter-1)

**Scope:** `agent_core/src/research/eml/` and adjacent scaffolding. Per
§4.I of `docs/CODEX_DEEP_INVESTIGATION_PROMPT_2026_05_16.md` (lines
853–913) the EML-IR is the elementary-function primitive in the
six-IR Primitive Stack. This audit covers types defined, generators
present, normal forms, missing primitives, tests, cited papers, and
the cross-IR reconciliation issues that Phase B will inherit.

**Authority:** §4.I + V6.1 integration doc
`docs/HELIOS_V6_1_NEW_RESEARCH_INTEGRATION_2026_05_16.md` §1.2.

---

## 1. Module inventory

| File | LOC | Primary types / fns | Tests |
|---|---:|---|---:|
| `eml/mod.rs` | 60 | Module re-exports + Wave J Phase B.0 sub-task ledger | 0 |
| `eml/grammar.rs` | 226 | `EmlExpr { One, Eml }` enum · `eml_grammar_root` · `depth` · `size` · `leaf_count` · `internal_node_count` · `is_balanced` | 16 |
| `eml/operator.rs` | 241 | `eml(x, y) = exp(x) − ln(y)` · `eml_partial_x` · `eml_partial_y` · `eml_inverse_x` · `EmlError { NonPositiveLogArg, NonFiniteResult }` | 18 |
| `eml/evaluator.rs` | 199 | `evaluate(&EmlExpr) → f64` · `MAX_EVAL_DEPTH = 32` · `EmlEvalError { DepthExceeded, Operator(EmlError) }` | 8 |
| `eml/ulp_oracle.rs` | 298 | `run_smoke_oracle` · `UlpToleranceFp16 { bar }` (`SHIPPING_BAR = 2.0`) · `UlpOracleReport { samples_evaluated, max_ulp_error, mean_ulp_error, samples_within_bar, bar, all_within_bar }` · `fraction_within_bar` · `fraction_outside_bar` | 14 |
| `eml/gate.rs` | 208 | `check_answer_packet_freeze_allowed` · `check_with_custom_tolerance` · `GateStatus { Allowed, Blocked }` · `GateError { OracleFailedToRun }` | 18 |
| **Total** | **1,232** | | **74** |

The FILE MAP figure of 1,232 LOC in §4.I (line 887) matches the
checked-in sum.

## 2. Types defined

- **Term algebra** — `EmlExpr` is a two-variant ADT: terminal `One`
  and binary `Eml(Box<EmlExpr>, Box<EmlExpr>)` (`grammar.rs:13–16`).
  Serde-derived (`grammar.rs:8`).
- **Primitive errors** — `EmlError { NonPositiveLogArg { y: f64 },
  NonFiniteResult { x, y, result } }` (`operator.rs:13–17`).
- **Evaluator errors** — `EmlEvalError { DepthExceeded { depth, cap
  }, Operator(EmlError) }` with `From<EmlError>` blanket impl
  (`evaluator.rs:31–41`).
- **ULP oracle types** — `UlpToleranceFp16 { bar: f32 }` with
  `SHIPPING_BAR = 2.0` (`ulp_oracle.rs:38–45`), `UlpOracleReport`
  (`ulp_oracle.rs:53–61`), `UlpOracleError { EmlEvaluationFailed,
  EmptySample }` (`ulp_oracle.rs:47–51`).
- **Gate types** — `GateStatus { Allowed { report }, Blocked {
  report, reason } }` (`gate.rs:16–20`), `GateError {
  OracleFailedToRun }` (`gate.rs:54–57`).

**Branch-safe typing — NOT YET PRESENT.** The current `EmlExpr` is
untyped over its inputs: there is no `EmlExpr<Domain>` or
`BranchedEmlExpr` that captures principal-branch constraints on the
`ln` argument. Phase B1 acceptance bar requires this — see §6.

## 3. Generators present

- `eml_grammar_root() → EmlExpr::One` (`grammar.rs:75–77`) — the
  trivial root, intended starting point for symbolic-regression search.
- **No corpus generator yet.** No `enumerate_depth_k_trees`, no
  100-fn elementary-function library, no symbolic-regression search
  driver. Phase B1 needs all three.
- **No constant extension.** The grammar is parameter-free (only
  `1` leaves); to materialize a real-valued elementary function the
  grammar must be extended with a `Const(f64)` leaf or a `Var(usize)`
  leaf. Currently every `EmlExpr::Eml(EmlExpr::One, EmlExpr::One)`
  collapses to the constant `e`. **Open design question for B1**:
  add `Const(f64)` to `EmlExpr` (breaks normal-form simplicity) or
  carry the constant table in a sibling type `EmlClosure { tree,
  consts: Vec<f64> }`. The Stachowiak paper's
  `S(x, y) = M(f(x), f⁻¹(y))` general form (§1.3, arXiv:2604.23893)
  suggests the sibling-type form preserves the term-algebra cleanly.

## 4. Normal forms

**STATUS: ABSENT.** The grammar carries five tree-shape queries
(`depth`, `size`, `leaf_count`, `internal_node_count`, `is_balanced`)
but **zero rewrite rules**. The V6.1 integration doc line 189 names
the falsifier `F-EML-Normal-Form` and the canonical-form criterion
"Stachowiak abelian-group + functional-inverse canonical normal form
preserved by all passes" with acceptance "round-trip > 95% canonical
library". None of that ships yet.

**What Stachowiak's normal form needs.** The general form
`S(x, y) = M(f(x), f⁻¹(y))` (Stachowiak arXiv:2604.23893
§1.3 / `eml_universal_operator.md:44–46`) gives an abelian-group
structure that rewrites should preserve. A minimum normal form
should:

1. Push `One` leaves to the canonical right-balanced position
   (well-defined since `eml` is not commutative — `exp(x) − ln(y) ≠
   exp(y) − ln(x)`).
2. Apply the elementary identities `eml(1, 1) = e`,
   `eml(0, 1) = 1` (already verified at runtime in
   `operator.rs:88–90, 98–101`).
3. Canonicalize the `M / f / f⁻¹` triple per Stachowiak's depth-3
   bound (every recovery of `f⁻¹` requires Polish-notation length 7,
   depth 3 — Stachowiak §1.3 quoted at
   `eml_universal_operator.md:59`).

**Action for Phase B1**: implement `normalize(&EmlExpr) → EmlExpr`
+ idempotence property test (`normalize(normalize(e)) == normalize(e)`).

## 5. Tests

74 `#[test]` attributes across the module. Coverage classes:

- **Tree-algebra invariants** (grammar) — depth/size/leaf-count
  identity `leaves = internal + 1`; serde round-trip; `is_balanced`
  cross-checks.
- **Primitive correctness** (operator) — `eml(0, 1) = 1`,
  `eml(1, e) = e − 1`, branch-cut rejection (`y ≤ 0`, `y` NaN),
  overflow rejection, ∂eml/∂x = exp(x), ∂eml/∂y = −1/y, inverse
  round-trip on a 5×3 grid.
- **Evaluator** — leaf-evaluates-to-1, `eml(1,1) = e`, depth-cap
  trigger at `MAX_EVAL_DEPTH + 2`, operator-error propagation.
- **ULP oracle smoke** — 1024-sample log-grid run, fraction-within-bar
  invariant `within + outside = 1.0`, serde round-trip.
- **AnswerPacket gate** — `is_allowed` ⊕ `is_blocked`, `report()`
  accessor parity, default-vs-custom-shipping-bar equivalence.

**Property-test gaps:**

- No quickcheck/proptest harness — every test is concrete-input. The
  driver-prompt §4.I (line 873) says "property-test corpus
  (round-trip identities)" is part of the per-IR acceptance shape.
- No fixture-corpus round-trip (B1 acceptance: 100-fn elementary
  corpus round-trips through EML-IR → normal form → Rust eval).
- No equivalence test between `eml_inverse_x` and a Stachowiak
  reference normal-form (since the normal-form rewriter doesn't
  exist yet).

## 6. Missing primitives (Phase B1 punch-list)

1. **Constant-extension to `EmlExpr`.** Either `Const(f64)` variant
   or sibling-type `EmlClosure { tree, consts }`. Required before
   "100-fn elementary corpus" can mean anything (every concrete
   function needs at least one numeric constant).
2. **`normalize(&EmlExpr) → EmlExpr` rewriter.** Per Stachowiak
   canonical form. Idempotence property test. (Section 4 above.)
3. **Branch-safe typing.** A `BranchedEmlExpr` (or `EmlExpr<Branch>`
   phantom-tagged) variant that captures the `y > 0` precondition
   for `ln` at the type level — turns the runtime `NonPositiveLogArg`
   error into a compile-time rejection for type-checked trees.
4. **Lean certificate emission.** Per §4.I line 875 ("Lean schema
   authority"): a function `lean_certificate(&EmlExpr) → String`
   that emits a Lean 4 term whose typechecking proves the tree
   well-formed under the branch-safe typing. Lands as the EML-IR
   contribution to the Tri-Fusion Lean canon.
5. **100-fn elementary-function corpus.** Seed entries: sin/cos/tan
   (via Euler's identity decomposed through EML), sinh/cosh, log_b,
   exp_b, sqrt, pow, atan via series. Each entry: `name`, `EmlExpr`
   tree, target `f64`-typed reference fn, ULP tolerance.
6. **Round-trip property test.** `for each f in corpus:
   evaluate(normalize(f.tree)) == f.reference(x)` within tolerance,
   across a sample grid.
7. **Carney inexpressibility citation.** §4.I line 887 names "Carney
   inexpressibility result" as a required citation. The current
   module cites Odrzywołek (mod.rs:6, operator.rs:1) and Stachowiak
   (mod.rs:9) but **not Carney** — no occurrence of "Carney" in any
   `eml/` source file or in the deeper-research markdown corpus
   (`grep -ri carney agent_core/src/research/eml/` returns zero
   hits). Phase B1 must locate the Carney citation, add it to the
   header, and write a test that documents the bound it implies
   (likely a `not_expressible` table for elementary functions
   outside the Liouvillian-solvable subdomain — Smith's quintic
   counter-construction, mod.rs:42–46, is the same hard-fence
   doctrine).

## 7. Cited papers — primary-source coverage

| Paper | arXiv / cite | Cited at | §5.0 verdict |
|---|---|---|---|
| Odrzywołek — Liouvillian-elementary universality of `eml` | arXiv:2603.21852 | `mod.rs:6–8`, `operator.rs:1` | ✅ primary |
| Stachowiak — abelian-group + functional-inverse decomposition | arXiv:2604.23893 | `mod.rs:9–10`, deep-research at `docs/fusion/jordan's research/kimis deep research/research/eml_universal_operator.md:7,44,234` | ✅ primary |
| Carney — inexpressibility result | TBD — find precise citation | **NOT YET CITED** | ⚠️ open |
| Smith — quintic counter-construction (universality fence) | doctrine, mod.rs:45 | `mod.rs:44–46` (doctrine comment) | partial — paper id TBD |

§5.0 ("every IR claim cited to primary source — paper + line") fails
for the Carney citation; Phase B1 entry slice should resolve this
before the 100-fn corpus is written, so the corpus boundary is
defensible.

## 8. Cross-link with `hyperdynamic_schemas/` (T1 coord)

The schemas module is 3 files (`diff.rs`, `mod.rs`, `repair.rs`),
small surface, no EML mention. The §4.I plan line 896 (Phase C):
"integration with `agent_core/src/research/hyperdynamic_schemas/` so
the Tri-Fusion content fabric (§4.A) can carry IR-typed expressions
natively" — that's Phase C territory, not Phase A/B. Audit verdict:
the cross-link is **structurally additive** (schemas don't reference
eml at all today, so EML-IR can land its typed-AST contribution
without conflict). No coordination friction with T1 expected at this
stage.

## 9. Reconciliation issues for Phase B

### 9.1 Flat `tropical.rs` vs new `tropical_ir/` directory

`agent_core/src/research/tropical.rs` is a 594-LOC flat file already
in tree (verified `wc -l`). §4.I line 864 + the driver SCOPE LOCK
both name a NEW `agent_core/src/research/tropical_ir/` directory
module. Three options:

| Option | Pros | Cons |
|---|---|---|
| **A — Extend flat file.** Rename internally, keep `tropical.rs`. | No file motion. | Violates driver SCOPE LOCK (directory expected); harder to grow to a typed-AST + normal-form + lowering + property-test split. |
| **B — Move + re-export.** New `tropical_ir/` dir; `tropical.rs` becomes `pub use crate::research::tropical_ir::*;`. | Driver-compliant, additive, preserves existing call sites. | Two iterations of file motion (the move itself + later removing the re-export). |
| **C — New `tropical_ir/` dir + deprecate flat.** Mark flat `tropical.rs` `#[deprecated]`, add new module separately. | Driver-compliant, no immediate motion. | Two parallel symbols; risk of drift if call sites land on either. |

**Recommendation: Option B**, with the move executed at Phase B2
entry slice. The audit-doc draft for B2 (iter 6, per Phase A task
list) writes the migration plan + grep-verifies no external call
sites depend on the flat file's internal layout. **No motion this
iteration** — audit-only.

### 9.2 Co-author tag

Driver-prompt PER-ITER says
`Co-Authored-By: Codex (T5) <noreply@anthropic.com>`. §7 of the
same driver doc says `Co-Authored-By: Codex <noreply@anthropic.com>`.
The driver-prompt form (with terminal marker) is more useful for
multi-terminal forensic tracing; using the (T5) form wins.

### 9.3 OxiEML vendoring (deferred per Wave J B.0.1)

Per `mod.rs:20–22`, vendoring `cool-japan/oxieml` is "deferred to
user / a manual setup pass" — needs `git submodule add` + network
access. T5 audit verdict: **leave deferred.** The substrate floor
(in-tree eml/) is enough for B1's 100-fn corpus; OxiEML can land in
Phase C alongside the Lean-schema-authority work without blocking
B1–B6 MVPs.

## 10. Phase A → B handoff

The Phase A close-out artifact (iter-8) will reference this audit +
the doctrine doc to come (iter-2). For iter-2 the punch-list is:

- Six-IR table verbatim from §4.I, but expanded with: per-IR primary
  paper + per-IR Rust crate target + per-IR lowering target.
- Cross-IR composition lattice (which IR calls which) — drafted in
  iter-7.
- Per-IR acceptance bar (iter-3).
- Lean schema authority cross-link (iter-3).

## 11. Verdict

Phase A iter-1 audit **PASS**. The EML substrate floor is solid for
B1 entry: ULP gate works, evaluator round-trips through the f64
reference, 74 tests green. The four blocking holes (constant
extension, normal form, branch-safe typing, Carney citation) are
all clean additive slices and are the right shape for one iter each.

The flat-`tropical.rs` reconciliation (§9.1) is the only motion-risk
item before Phase B2 begins.

---

**Co-Authored-By:** Codex (T5) <noreply@anthropic.com>
