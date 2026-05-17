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

## §4-§7 (placeholders, deliverables iters 3 + 7 + 8)

- **§4. Per-IR lowering target details** — iter-3. Rust crate
  scaffolding per IR, Metal-kernel targets where applicable, fixture
  corpus shape per IR.
- **§5. Per-IR acceptance bar** — iter-3. ULP / round-trip / proof
  obligations per IR, sized for Phase B MVP.
- **§6. Cross-IR composition lattice** — iter-7. Which IRs call
  which (e.g. Operator-IR ↣ Scan-IR for time-stepping;
  Info-IR ↣ EML-IR for closed-form log-partitions).
- **§7. Phase A audit-of-audit + Phase B branch plan** — iter-8.

---

**Status:** doctrine §1-3 complete; doc closes the Phase A "what is
the doctrine?" gap by binding each of the six IRs to its primary
source paper, Rust module, lowering target, and Lean schema
authority. §4-§7 to land iters 3, 7, 8. EML-IR carries the only
**open citation gap** (Carney inexpressibility; iter-1 audit §6
item 7).

**Co-Authored-By:** Codex (T5) <noreply@anthropic.com>
