# Primitive-IR Stack Doctrine — 2026-05-17 (Terminal T5)

**Authority:** §4.I of `docs/CODEX_DEEP_INVESTIGATION_PROMPT_2026_05_16.md`
(lines 853-913). This doc is the kernel-grade-IR doctrine for
Epistemos: the typed primitive layer underneath the Tri-Fusion content
fabric (§4.A) and the agent runtime (§4.B). Iter-1 audit at
`docs/audits/EML_IR_AUDIT_2026_05_17.md` is the substrate-state
companion.

**Doctrine scope (this revision — iter-2 of Phase A).** §1 mission,
§2 the six IRs in table form with paper + crate + lowering target,
§3 Lean schema authority. §4 (lowering targets in detail) and §5
(per-IR acceptance bar) land iter-3. §6 cross-IR composition lattice
lands iter-7. §7 audit-of-audit + Phase B branch plan lands iter-8.

**No floating doctrine.** Every IR claim below cites a primary
source (paper · arXiv id · line / section). §5.0 of the driver
prompt is the discipline.

---

## §1. Mission — kernel-grade IR is the moat under the moat

Every other personal-knowledge-manager has prose. Epistemos has six
typed kernel IRs that compile down to verified runtime code. Each IR
is **branch-safe by construction** (precondition violations rejected
at the type level, not at runtime) and **Lean-certified** (a parallel
Lean schema authority emits proof terms for every well-formed IR
tree). The whole stack obeys one promise: a user can write a tool
spec in a hyperdynamic schema (`agent_core/src/research/hyperdynamic_schemas/`)
that compiles down through the primitive IRs to runtime code with a
provable correctness envelope.

The six IRs partition the math the agent runtime needs:

- **EML-IR + Tropical-IR** cover the math the language model actually
  emits when it writes code or expressions: elementary functions
  (sin, exp, log_b, sqrt, pow) and ReLU/piecewise-linear networks.
- **Scan-IR + Operator-IR** cover the recurrence and PDE/operator
  forms that today's local-model architectures (Mamba-2, RWKV-7) and
  scientific-computing surfaces use.
- **Info-IR** turns confidence math into a typed primitive — KL
  divergence, mirror descent, Bregman geometry — so `AnswerPacket.confidence`
  is mathematically disciplined, not a UI string.
- **Geometry-IR** handles spatial / phase reasoning (Clifford algebra
  + rotors + parallel transport) for the multi-plane Helios formalism.

§4.I lines 877-883 of the driver prompt are the verbatim per-IR
mission. This doctrine doc is the unfolded form: it locks the
primary source per IR, the lowering target, and the acceptance bar
(the latter in §5, iter-3).

## §2. The six IRs — paper · primitive signature · crate · lowering target

Each row binds an IR to (a) its primary-source paper (§5.0
discipline), (b) the kernel signature that all rewrites preserve,
(c) the Rust module that owns it (per driver SCOPE LOCK), and
(d) its first executable lowering target.

### 2.1 EML-IR

| Field | Value |
|---|---|
| **Generates** | elementary scientific functions on the Liouvillian-solvable subdomain |
| **Primitive signature** | `eml(x, y) = exp(x) − ln(y)`, terminal `1`, grammar `S → 1 | eml(S, S)` |
| **Primary source (universality)** | Odrzywołek, "Liouvillian-elementary universality of `eml(x,y) = exp(x) − ln(y)`", arXiv:2603.21852. Cited verbatim in `agent_core/src/research/eml/mod.rs:6-8` and `operator.rs:1`. |
| **Primary source (canonical form)** | Stachowiak, "Algebraic structure behind Odrzywołek's EML operator: abelian-group + functional-inverse decomposition", arXiv:2604.23893. The general form `S(x, y) = M(f(x), f⁻¹(y))` proven at §1.3 (quoted at `docs/fusion/jordan's research/kimis deep research/research/eml_universal_operator.md:44-59`). The Polish-notation-length-7 / depth-3 bound on `f⁻¹` recovery is the canonical-form invariant. |
| **Primary source (universality fence)** | Carney inexpressibility result — citation **TBD**. §4.I line 887 names it; iter-1 audit §6 item 7 flags it as the open citation gap. Phase B1 entry slice resolves. Smith's quintic counter-construction (doctrinal note at `eml/mod.rs:42-46`) is the same hard-fence in different language. |
| **Crate / module** | `agent_core/src/research/eml/` (1,232 LOC substrate floor; extend per Phase B1) |
| **First lowering target** | f64 reference evaluator (in tree at `eml/evaluator.rs`) + fp16 Metal kernel stub `morph_eval_reduced.metal` (mod.rs:26-28) — gated by F-ULP-Oracle ≤ 2 ULP fp16 in `[0.5, 2]` (`eml/ulp_oracle.rs:18`, `gate.rs`). |
| **Schema authority** | Lean 4 (vendored from `tomdif/eml-lean`, deferred per `mod.rs:23-25` until network + toolchain available). Iter-2 doctrine acknowledges; Phase B1 emits certificates. |

### 2.2 Tropical-IR

| Field | Value |
|---|---|
| **Generates** | piecewise-linear networks; ReLU compositions; tropical rational functions |
| **Primitive signature** | `(max, +)` semiring — `⊕ := max`, `⊗ := +`. Min-plus dual is `(min, +)`. Tropical polynomial `p(x) = max_i (a_i + ⟨b_i, x⟩)` with rational form `p / q`. |
| **Primary source (NN/tropical bridge)** | Zhang, Naitzat, Lim, "Tropical Geometry of Deep Neural Networks", arXiv:1805.07091 (ICML 2018). Theorem 5.4: every feedforward ReLU network computes a tropical rational map. |
| **Primary source (algorithmic)** | Charisopoulos & Maragos, "A Tropical Approach to Neural Networks with Piecewise Linear Activations", arXiv:1805.08749. Section 3 gives the explicit ReLU-to-`(max,+)` compilation. |
| **Crate / module** | `agent_core/src/research/tropical_ir/` (NEW per driver SCOPE LOCK). Existing flat `agent_core/src/research/tropical.rs` (594 LOC) reconciles at iter-6 — see audit §9.1, recommended path is move-and-re-export (Option B). |
| **First lowering target** | Small ReLU MLP (1–3 hidden layers) compiled to a `TropicalRational { numerator: TropicalPoly, denominator: TropicalPoly }` tree; property test: byte-equal output on a fixture corpus (§4.I line 891). |
| **Schema authority** | Lean 4 — tropical-semiring algebraic structure (semiring axioms + idempotence) emitted as a `TropicalSemiring` typeclass certificate per tree. |

### 2.3 Scan-IR

| Field | Value |
|---|---|
| **Generates** | recurrence; structured state-space models (SSM); linear attention; Mamba-2; RWKV-7 inner loops |
| **Primitive signature** | `scan(⊕, a_1, …, a_n)` with associative `⊕ : S × S → S` over state monoid `S`. Lifts to parallel-prefix per Blelloch 1990. |
| **Primary source (Mamba-2 / SSD)** | Dao & Gu, "Transformers are SSMs: Generalized Models and Efficient Algorithms Through Structured State Space Duality", arXiv:2405.21060 (ICML 2024). Section 6 (SSD algorithm) is the canonical lowering target. |
| **Primary source (parallel-scan algorithmics)** | Blelloch, "Prefix Sums and Their Applications", CMU-CS-90-190, 1990. The associative-operator-over-monoid abstraction. |
| **Crate / module** | `agent_core/src/research/scan_ir/` (NEW; **coord T3 for F-SemiseparableBlockScan-Correctness** per driver SCOPE LOCK + §4.G; Scan-IR must export the typed AST that T3's correctness gate consumes). |
| **First lowering target** | Mamba-2 SSD reference scan; property test: Scan-IR `scan(⊕_ssd, fixture_inputs)` matches a Dao/Gu reference implementation on a fixture sequence (§4.I line 892). |
| **Schema authority** | Lean 4 — monoid-associativity certificate per `⊕`. Required for parallel-scan correctness (Blelloch's reduction relies on associativity, not commutativity). |

### 2.4 Operator-IR

| Field | Value |
|---|---|
| **Generates** | neural operators; DeepONet branch/trunk decomposition; Fourier neural operators (FNO); PDE forward maps |
| **Primitive signature** | `Operator(branch: Network, trunk: Network, kernel: KernelTransform)`. Universal-operator factorization `G(u)(y) ≈ Σ_k branch_k(u) · trunk_k(y)`. Kernel transform may be Fourier (FNO) or identity (DeepONet baseline). |
| **Primary source (DeepONet universality)** | Lu, Jin, Karniadakis, "Learning nonlinear operators via DeepONet based on the universal approximation theorem of operators", arXiv:1910.03193 (Nat. Mach. Intell. 2021). Theorem 2 is the operator universal-approximation result. |
| **Primary source (FNO)** | Li, Kovachki, Azizzadenesheli, Liu, Bhattacharya, Stuart, Anandkumar, "Fourier Neural Operator for Parametric Partial Differential Equations", arXiv:2010.08895 (ICLR 2021). Section 3 specifies the Fourier-kernel lowering. |
| **Crate / module** | `agent_core/src/research/operator_ir/` (NEW) |
| **First lowering target** | A small FNO (1-2 Fourier blocks); property test: Operator-IR forward pass matches an FNO reference on a fixture (§4.I line 894). |
| **Schema authority** | Lean 4 — branch/trunk type-level separation (`Operator<U, Y>` carries the function-space domain/codomain explicitly), Fourier-transform-as-isometry certificate. |

### 2.5 Info-IR

| Field | Value |
|---|---|
| **Generates** | exponential-family inference; mirror descent; Bregman geometry; KL projection; confidence math for `AnswerPacket` |
| **Primitive signature** | `(log_partition: θ → A(θ), dual_map: θ → η, kl_projection: (P, Q) → P*)` triple. `A` is the cumulant / log-partition function; `η = ∇A(θ)` is the dual / mean parametrization; KL projection is the Bregman projection onto a convex constraint set. |
| **Primary source (information geometry)** | Amari, "Information Geometry and Its Applications", Springer 2016. Chapter 2 (exponential families + dual coordinates), Chapter 6 (Bregman divergences). The `(A, η, P*)` triple is the canonical encoding of Chapter 2 §2.2. |
| **Primary source (mirror descent equivalence)** | Beck & Teboulle, "Mirror descent and nonlinear projected subgradient methods for convex optimization", Operations Research Letters 31:167-175, 2003. The mirror-descent ↔ Bregman-projected-gradient equivalence is the algorithmic anchor that lets Info-IR mirror descent match raw mirror descent on logistic regression (§4.I line 893). |
| **Crate / module** | `agent_core/src/research/info_ir/` (NEW) |
| **First lowering target** | Logistic regression as exponential-family GLM; property test: convergence trajectory of Info-IR mirror descent equals raw mirror descent within numerical tolerance on a fixture dataset (§4.I line 893). |
| **Schema authority** | Lean 4 — `LogPartition` typeclass + Bregman-divergence positivity (`B(P, Q) ≥ 0`, `= 0 iff P = Q`). T2 consumes this for `AnswerPacket.confidence` (driver-prompt COORDINATION clause). |

### 2.6 Geometry-IR

| Field | Value |
|---|---|
| **Generates** | Clifford algebra / geometric algebra; rotor sandwich; parallel transport; phase / spatial reasoning; Helios five-plane formalism |
| **Primitive signature** | Geometric product `e_i e_j = δ_ij + (i≠j) wedge`. Rotor `R = exp(-B/2)` over bivector `B`. Rotor sandwich `v' = R v R̃`. |
| **Primary source (foundational)** | Hestenes & Sobczyk, "Clifford Algebra to Geometric Calculus: A Unified Language for Mathematics and Physics", Reidel 1984. The canonical algebraic foundation; geometric-product axioms in Chapter 1. |
| **Primary source (computational)** | Dorst, Fontijne, Mann, "Geometric Algebra for Computer Science", Morgan Kaufmann 2007. Algorithms and data layouts for the geometric product in code; rotor sandwich at §10.3. |
| **Crate / module** | `agent_core/src/research/geometry_ir/` (NEW) |
| **First lowering target** | 3D rotation via rotor sandwich; property test: identity rotation `R = 1` returns the input unchanged + composition law `(R_1 R_2) v (R_1 R_2)~ = R_1 (R_2 v R̃_2) R̃_1` (§4.I line 895). |
| **Schema authority** | Lean 4 — Clifford-algebra axiom set as a typeclass; rotor-sandwich-preserves-norm certificate. |

## §3. Lean schema authority — IR ↔ Lean ↔ runtime

Per §4.I line 875: "Lean schema authority (per §4.A Tri-Fusion +
analyst's May-12 synthesis on Lean as canonical schema)". The
discipline:

1. **Every IR has a Lean 4 schema module.** The schema declares the
   typeclass(es) the IR's term algebra inhabits — `Semiring` for
   tropical, `Monoid` for scan, `LogPartition` for info, etc. Lean
   is the source of truth for the algebraic structure; the Rust IR
   is a typed mirror.
2. **Per-tree certificate emission.** A function
   `lean_certificate(&IrExpr) → String` emits a Lean 4 term whose
   typechecking proves the tree well-formed under the IR's
   branch-safety conditions. For EML-IR that means proving the
   `y > 0` precondition holds at every `Eml(_, _)` node (audit §6
   item 4).
3. **Lockstep with the IR.** Any change to an IR's term algebra
   must update the Lean schema in the same commit. This is the
   May-12 source-custody discipline applied to IRs.
4. **Lean toolchain pin.** Per `eml/mod.rs:33-35`, the locked stack
   is Lean 4.29.1; current public Lean is 4.25.0 (2025-11-14). The
   verification is deferred (B.0.5 in the Wave J ledger). Phase B1
   entry slice must verify the pin against mathlib4.
5. **Vendored Lean proofs.** `tomdif/eml-lean` (claims 0-sorry) is
   the vendored proof corpus for EML-IR per `eml/mod.rs:23-25`.
   Similar vendoring will be needed for tropical (a Stachowiak-style
   tropical-semiring corpus), scan (Mamba-2-SSD-correctness), info
   (Amari's exp-family identities), and geometry (Clifford-algebra
   axioms in Lean). Phase C is the right window for these vendorings.

The `agent_core/src/research/paper_registry/` module
(4 files — `audit.rs`, `claim.rs`, `mod.rs`, `seed.rs`) is the
existing claim-citation infrastructure inside the Rust workspace.
Cross-link: every IR's `claims.yaml` (to land iter-5 in
`research_custody/<ir>/`) should be reachable from `paper_registry`
so the runtime can produce a per-IR provenance ledger entry for any
emitted Lean certificate.

---

## §4. Per-IR lowering target details

Each IR follows the same Rust crate-module shape; the per-IR mission
fills in the IR-specific names. The shape is:

```
agent_core/src/research/<ir>_ir/
├── mod.rs           — public re-exports + source-citation header
├── grammar.rs       — EnumName, typed AST nodes, depth/size/leaf invariants
├── normalize.rs     — normalize(&Tree) → Tree, idempotence-tested
├── evaluator.rs     — evaluate(&Tree) → ConcreteValue (the executable lowering)
├── lowering.rs      — IR → kernel form (Rust trait impl per backend)
└── certificate.rs   — lean_certificate(&Tree) → String (Lean 4 emit)
```

Tests live under `agent_core/src/research/<ir>_ir/<file>.rs#[cfg(test)]
mod tests { … }` for unit-level invariants and `tests/<ir>_ir_*.rs`
(integration crate) for property-test corpora and fixture round-trips.

**4.1 EML-IR.** Existing flat layout (`eml/{grammar,operator,evaluator,
ulp_oracle,gate}.rs`) maps directly to the shape above with two renames
needed in Phase B1: `operator.rs` keeps the binary `eml(x, y)` primitive
(an existing-file extension, not a rename), `ulp_oracle.rs` + `gate.rs`
sit alongside `evaluator.rs` as the executable-lowering surface
(fp16/fp32/fp64 verification harness). `normalize.rs` + `certificate.rs`
are NEW files Phase B1 adds. Lowering targets: (a) Rust `f64`
reference (in tree), (b) `morph_eval_reduced.metal v0.1` fp16 kernel
stub (`agent_core/src/research/eml/mod.rs:26-28`), (c) Lean 4 term
emission for branch-safety certificates.

**4.2 Tropical-IR.** New module `agent_core/src/research/tropical_ir/`.
Term algebra: `TropicalExpr { Const(f64), Var(usize), Max(Vec<TropicalExpr>),
Plus(Box<TropicalExpr>, Box<TropicalExpr>) }`. Higher form
`TropicalRational { numerator: TropicalPoly, denominator: TropicalPoly }`
per Zhang/Naitzat/Lim Thm 5.4 (arXiv:1805.07091). Lowering targets:
(a) Rust `f64` reference evaluator on the `(max, +)` semiring,
(b) byte-equal-to-ReLU-network property test (B2 acceptance §4.I:891),
(c) Lean 4 typeclass-instance emission proving the term satisfies
the semiring axioms. Existing flat `agent_core/src/research/tropical.rs`
(594 LOC) reconciles at iter-6 via move-and-re-export (audit §9.1
Option B, user-confirmed via meta-message).

**4.3 Scan-IR.** New module `agent_core/src/research/scan_ir/`.
Term algebra: `ScanExpr<S> { Seed(S), Step(Box<ScanExpr<S>>, AssocOp<S>) }`
where `AssocOp<S>: Fn(S, S) → S` carries a Lean-cert-emitting
associativity witness. Lowering targets: (a) sequential reference
scan (the obvious left-fold), (b) Dao/Gu SSD parallel-block scan per
arXiv:2405.21060 §6 (the lowering target T3's F-SemiseparableBlockScan-
Correctness consumes), (c) Lean 4 monoid-associativity certificate.
**Coord with T3 (§4.G):** T3 owns the correctness gate; Scan-IR exports
the typed AST + the associativity-certificate emitter. T3 supplies the
fixture sequence + the Dao/Gu reference oracle for the round-trip test
(driver-prompt COORDINATION clause).

**4.4 Operator-IR.** New module `agent_core/src/research/operator_ir/`.
Term algebra:
`OperatorExpr { Branch(NetworkRef), Trunk(NetworkRef), Kernel(KernelTransform) }`
with `KernelTransform { Identity, Fourier { modes: usize } }`.
Lowering targets: (a) Rust DeepONet reference forward pass per Lu et al.
arXiv:1910.03193 Thm 2, (b) FNO forward pass with `rustfft` for the
Fourier-kernel block per Li et al. arXiv:2010.08895 §3, (c) Lean 4
typeclass-instance emission for the branch-trunk dimensional
consistency (`branch_dim × trunk_dim` factoring into the universal
approximator output).

**4.5 Info-IR.** New module `agent_core/src/research/info_ir/`.
Term algebra:
`InfoExpr { LogPartition(ExpFamily), DualMap(ExpFamily), KlProjection { p: Distribution, q: Distribution } }`
where `ExpFamily` carries the sufficient statistics + natural-parameter
vector per Amari Ch. 2. Lowering targets: (a) Rust exp-family eval
on Bernoulli/Categorical/Gaussian (the three families logistic-regression
mirror-descent demonstrates), (b) Bregman-projection mirror-descent
step per Beck-Teboulle 2003, (c) Lean 4 typeclass-instance emission for
`Bregman.divergence ≥ 0` (positivity, zero-iff-equal). **T2 cross-link:**
`AnswerPacket.confidence` consumes the `(P, Q) → kl_projection`
primitive; T2's wiring lands when Info-IR MVP closes (Phase B4).

**4.6 Geometry-IR.** New module `agent_core/src/research/geometry_ir/`.
Term algebra:
`GeoExpr { Scalar(f64), Vector(Vec<f64>), Bivector(Vec<(usize, usize, f64)>), Rotor { bivector_log: Box<GeoExpr> } }`
+ binary `GeoProduct(Box<GeoExpr>, Box<GeoExpr>)`. Lowering targets:
(a) Rust geometric-product evaluator per Dorst-Fontijne-Mann §10.3,
(b) 3D rotor-sandwich kernel for the rotation property test
(§4.I:895), (c) Lean 4 Clifford-algebra typeclass instance emission
(Hestenes-Sobczyk Ch. 1 axioms).

## §5. Per-IR acceptance bar

Each IR's Phase B MVP closes against a fixed acceptance bar. The
table below extracts the bar from §4.I lines 904-910 + the
per-IR Phase B entry slice (§4.I lines 889-895). Property tests
ship in the per-IR `tests/<ir>_ir_*.rs` integration file.

| IR | Phase B MVP acceptance | Lean certificate obligation | Acceptance witness file |
|---|---|---|---|
| **EML-IR** | 100-fn elementary corpus round-trips through EML-IR → normal form → Rust eval within float tolerance; **closes ≥ 80%** of corpus per §4.I:906 + ≤ 2 ULP fp16 in `[0.5, 2]` per `eml/ulp_oracle.rs:18` | branch-safety: every `Eml(_, _)` node's `y > 0` precondition discharged at the type level (`certificate.rs`) | `tests/eml_ir_corpus_round_trip.rs` (NEW) — 100 named entries, each carries `(name, EmlExpr, reference_fn, tolerance)` |
| **Tropical-IR** | small ReLU MLP (1-3 hidden) compiles into `TropicalRational`, evaluates **byte-equal** to the ReLU network on a fixture corpus (§4.I:891) | `TropicalSemiring` typeclass instance: associativity + commutativity of `max`; distributivity of `+` over `max`; idempotence `max(x, x) = x` | `tests/tropical_ir_relu_compile.rs` (NEW) — at least 3 ReLU networks of increasing width/depth |
| **Scan-IR** | Mamba-2 SSD reference scan **matches Scan-IR scan on a fixture sequence** (§4.I:892); T3's F-SemiseparableBlockScan-Correctness gate **passes** on the IR's exported AST | `Monoid` associativity certificate for the state-transition `⊕` | `tests/scan_ir_ssd_match.rs` (NEW; T3-shared fixture) |
| **Operator-IR** | small FNO **matches Operator-IR forward pass** within float tolerance on a fixture input (§4.I:894) | branch-trunk dimensional-consistency: `branch_output_dim == trunk_output_dim` typechecked | `tests/operator_ir_fno_equiv.rs` (NEW) |
| **Info-IR** | logistic regression **converges identically** through Info-IR mirror descent vs raw mirror descent (per-step trajectory equal within numerical tolerance, §4.I:893); `AnswerPacket.confidence` calls the typed `kl_projection` primitive | `Bregman.divergence ≥ 0`; `divergence = 0 iff P = Q` (positivity + non-degeneracy) | `tests/info_ir_logistic_mirror.rs` (NEW) |
| **Geometry-IR** | identity rotation `R = 1` returns input unchanged + composition law `(R_1 R_2) v (R_1 R_2)~ = R_1 (R_2 v R̃_2) R̃_1` (§4.I:895) | Clifford-algebra typeclass instance: `e_i² = 1`, `e_i e_j = −e_j e_i` for `i ≠ j` | `tests/geometry_ir_rotor.rs` (NEW) |

**§4.I global acceptance** (line 904-910):

1. All 6 IRs have an MVP, audit doc, doctrine doc, and property-test suite.
2. EML-IR closes ≥ 80% of the elementary-function corpus by round-trip.
3. Tropical-IR compiles small ReLU networks exactly.
4. Scan-IR drives the F-SemiseparableBlockScan-Correctness gate (§4.G).
5. Info-IR is wired into AnswerPacket confidence labeling (T2 coord).
6. A user can write a tool spec in a hyperdynamic schema that
   compiles down through EML-IR + Info-IR to verified runtime code.

Phase A delivers items 1's audit + doctrine; Phase B closes 2-5;
Phase C closes 6 (Tri-Fusion integration with T1's hyperdynamic schemas).

## §6. Cross-IR composition lattice

The six IRs are not independent silos; later-Phase MVPs and Phase C
Tri-Fusion integration require **typed composition** — one IR's term
algebra contains nodes that reduce, by lowering, to another IR's
term algebra. The arrows below read **A → B** as "A's lowering
*consumes* B"; equivalently, B is more primitive than A. (No
arrow runs against the partial order: composition is acyclic.)

### 6.1 ASCII lattice

```
                  Operator-IR
                 /     |     \
                /      |      \
               v       v       v
          Scan-IR   EML-IR    [Fourier]
               \    /  ^   \    (rustfft)
                \  /   |    \
                 vv    |     \
            Info-IR    |      Tropical-IR
                  \    |     /
                   \   |    /
                    v  v   v
                     EML-IR  (most primitive)
                       ^
                       |
                  Geometry-IR
                  (rotor exp = exp of bivector → EML)


Level (most-primitive at bottom):
  L0 : EML-IR
  L1 : Tropical-IR · Info-IR · Geometry-IR
  L2 : Scan-IR
  L3 : Operator-IR
```

The "level" annotation is not strict — Geometry-IR can sit at L1 or
L0 depending on whether its rotor-exp form is reduced through EML
(L1) or kept as a self-contained Clifford-product primitive (L0).
Phase C decides.

### 6.2 Edge table — what each arrow carries

| From (consumer) | To (primitive) | Composition semantics | First demanded by |
|---|---|---|---|
| **Operator-IR → Scan-IR** | PDE / SSM time-stepping is a parallel-prefix scan over the state monoid; an Operator-IR `Operator(branch, trunk, Identity)` lowering reduces to a Scan-IR `scan(⊕_state, …)` when the trunk discretization is a time-step | Phase C — physics tool surface |
| **Operator-IR → EML-IR** | Spectral coefficients of the Fourier kernel are closed-form elementary functions; the FNO Fourier block evaluates `exp(i·2π·k·x)` through EML-IR's `eml(x, y)` primitive (Euler's identity decomposed) | Phase B5 — FNO equivalence test |
| **Operator-IR → Fourier transform** | DFT/FFT is treated as an external `KernelTransform { Fourier { modes } }` node, not its own IR — backed by `rustfft` | Phase B5 — FNO lowering |
| **Scan-IR → Info-IR** | Sequential Bayesian update is a scan with `kl_projection` as the associative state-transition `⊕` — Info-IR exports the typed projection that Scan-IR composes; T2's `AnswerPacket.confidence` running update consumes this | Phase B4 + Phase C |
| **Info-IR → EML-IR** | Closed-form log-partition `A(θ)` for Bernoulli / Categorical / Gaussian families is an elementary function; Info-IR's `LogPartition` node lowers to an EML-IR tree when the family has a closed form | Phase B4 — logistic regression `A(θ) = log(1 + exp(θ))` |
| **Tropical-IR → EML-IR** | Smoothmax `softmax_β(x) = (1/β) · log(Σ exp(β · x))` is the canonical "tropicalization at temperature 1/β" — direct EML composition. As `β → ∞` it converges to the tropical `max`. Useful for: smoothing Tropical-IR's hard `max` for autodiff; bridging neural-network ReLU layers to Tropical-IR's `(max, +)` form | Phase C — tropical autodiff |
| **Tropical-IR → Scan-IR** | Viterbi inference is a max-plus scan on a trellis — Scan-IR's `scan(⊕, …)` with `⊕ := tropical_add (= max)` and `⊗ := tropical_mul (= +)` for the state-transition cost. Lowers an HMM Viterbi step through Scan-IR | Phase C — graphical-model tool surface |
| **Geometry-IR → EML-IR** | Rotor exponential `R = exp(-B/2)` where `B` is a bivector — `exp` is the EML-IR primitive (the `eml(x, 1)` branch). Closed-form Euler-like decomposition for the rotor-sandwich kernel | Phase B6 — 3D rotation property test (`exp` of bivector) |
| **Geometry-IR → Info-IR** | Fisher information metric on a statistical manifold is a Riemannian metric inheriting from Info-IR's Bregman geometry; the Clifford-algebra exterior derivative interacts with Info-IR's dual-coordinate map | Phase C — info-geom unification (not Phase B) |

### 6.3 Order-of-implementation consequence

The arrows above pin the **strict order** of Phase B MVPs as a
lattice condition: an upstream IR (e.g. Operator-IR) cannot ship its
acceptance test until the IRs it consumes (Scan-IR + EML-IR) ship
theirs. The driver-prompt Phase B order (B1 EML · B2 Tropical · B3
Scan · B4 Info · B5 Operator · B6 Geometry) satisfies this. Notes:

- **B1 EML-IR first** is correct — every other IR can compose to it.
- **B2 Tropical-IR before B3 Scan-IR** is loose-fit: Tropical-IR's
  Viterbi lowering is Phase C work, so B2 can ship without B3. ✅
- **B5 Operator-IR after B3 Scan-IR + B1 EML-IR** is required for
  the FNO equivalence test (Operator-IR's evaluator calls Scan-IR
  on the time-step axis when the trunk is a discretization, and
  EML-IR for the spectral-coefficient Euler expansion).
- **B6 Geometry-IR after B1 EML-IR** is required for the rotor-exp
  decomposition; B6 can ship before B4/B5 since Geometry-IR's MVP
  test (`R = 1` identity + composition law) doesn't touch Info-IR.

### 6.4 Tri-Fusion integration (Phase C)

§4.I:896 names the Phase C handoff: `hyperdynamic_schemas/`
(T1 surface) carries IR-typed expressions natively. The composition
lattice above is what makes this typeable — a hyperdynamic schema
field can declare its value as `OperatorExpr<Branch, Trunk>` and the
runtime knows the lowering chain: `OperatorExpr → ScanExpr → EmlExpr`
or `OperatorExpr → EmlExpr` (via Euler), each reducible to a verified
runtime kernel. The Lean schema authority (§3) certifies each arrow
in the lattice as a structure-preserving morphism.

## §7. Phase A audit-of-audit + Phase B branch plan (placeholder, iter-8)

Lands in iter-8: re-check Phase A deliverables (audit doc · doctrine
doc · research_custody/ skeleton · claims.yaml seeds · tropical
reconciliation plan · composition lattice) + lock the Phase B1 entry
slice (constant-extension to `EmlExpr` + normalize.rs + Carney
citation) as the first Phase B commit.

---

**Status:** doctrine §1-3 complete; doc closes the Phase A "what is
the doctrine?" gap by binding each of the six IRs to its primary
source paper, Rust module, lowering target, and Lean schema
authority. §4-§7 to land iters 3, 7, 8. EML-IR carries the only
**open citation gap** (Carney inexpressibility; iter-1 audit §6
item 7).

**Co-Authored-By:** Codex (T5) <noreply@anthropic.com>
