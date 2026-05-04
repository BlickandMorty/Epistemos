# 5. Executable Ontologies: When Physics Becomes a Type System

The central thesis of this chapter is that physical law, mathematical structure, and software correctness can be treated as a single compile target. Rather than viewing physics as a post-hoc filter on model outputs — a validator that runs after generation is complete — we treat it as a *type system* that constrains what the model is permitted to propose in the first place. An ontology of mechanics, thermodynamics, or electromagnetism becomes an executable profile: a formal object that compiles to Rust traits for zero-cost runtime validation *and* to neural network architectural constraints for structural inductive bias. This is the dual-compile-target insight that underpins the Rex deterministic superintelligence substrate.

The approach is motivated by a structural observation. Large language models (LLMs) generate claims in natural language: equations, causal assertions, empirical statements, and code invariants. Each claim can be decomposed into typed structures — a graph of assertions with quantified variables, dimensional attributes, and logical dependencies — and validated against an ontological profile that defines what is physically admissible. The model ceases to be a source of truth and becomes a *proposal engine* whose outputs are checked, repaired, and committed only after they satisfy formal constraints. This chapter develops the machinery for that pipeline: the `OntologicalProfile` compiler, physics-as-type constraints via Rust dimensional analysis, the dual compile target into both software and neural architectures, and falsifiability-driven evidence evaluation.

## 5.1 The Ontological Profile Compiler

### 5.1.1 Profile Structure

An `OntologicalProfile` is the schema against which all model outputs in a domain are validated. It is not a lightweight JSON schema for syntax checking; it is a formal specification of entities, relations, quantities, invariants, transitions, and proof obligations. In the Rex architecture, a profile is defined as:

```rust
pub struct OntologicalProfile {
    pub id: ProfileId,
    pub name: String,
    pub entities: Vec<EntitySchema>,
    pub relations: Vec<RelationSchema>,
    pub quantities: Vec<QuantitySchema>,
    pub invariants: Vec<Invariant>,
    pub transitions: Vec<TransitionRule>,
    pub proof_obligations: Vec<ProofObligation>,
}
```

Each field encodes a distinct aspect of domain semantics. `entities` defines the kinds of objects that can appear in a claim (e.g., `Particle`, `Field`, `Wavefunction`). `relations` defines how entities may interact (e.g., `gravitates_to`, `interacts_with`, `decays_into`). `quantities` specifies the dimensional signatures of measurable attributes, expressed as exponent vectors over the seven SI base dimensions (mass, length, time, electric current, thermodynamic temperature, amount of substance, luminous intensity). `invariants` are conservation laws or fixed-point conditions that every valid claim graph must preserve — for instance, conservation of energy-momentum or positivity of entropy production. `transitions` defines admissible state-change rules, and `proof_obligations` attaches formal verification targets to critical claims.

A physics profile and a codebase profile differ only in the contents of these vectors, not in their structure. A physics profile might declare that `velocity` has dimension $[\text{L}^1\text{T}^{-1}]$, that energy is conserved under transitions, and that the speed of light is an upper bound on any velocity quantity. A codebase profile might declare that `Module` entities cannot participate in circular `imports` relations, that every `unsafe` block requires a proof obligation dispatched to Kani or Creusot, and that actor-isolation boundaries are transition invariants. The uniform structure enables a single validation engine to operate across domains.

### 5.1.2 Real-Time Claim Extraction via Constrained Decoding

The profile is useless unless claims can be extracted from model outputs in real time. Token-level physics validation is too brittle: individual tokens carry no semantic structure, and enforcing physical constraints on token distributions is both computationally expensive and semantically vacuous. The correct granularity is the *claim* — an atomic unit of information that can be evaluated against context, typically a single predicate with subject, object, and quantified attributes [^16^].

Constrained decoding provides the fastest path from natural language output to typed claim structures. XGrammar divides the vocabulary into context-independent tokens (pre-checked against a grammar) and context-dependent tokens (checked at runtime via a persistent pushdown automaton), achieving up to $100\times$ speedup over baseline constrained-decoding solutions with per-token overhead below $40\ \mu\text{s}$ for JSON Schema [^6^]. XGrammar 2 reduces this overhead further to $30$–$80\ \mu\text{s}$ per token — a latency budget small enough that structured generation adds less than $6\%$ overhead to unconstrained decoding on an H100 GPU [^45^].

The "In-Writing" unified decoding pattern provides the interaction model: the LLM first generates an unconstrained reasoning trace, then switches to structured generation once a trigger token is emitted [^46^]. This preserves reasoning quality while guaranteeing that the final output adheres to a grammar defining the six claim types. The output is not merely JSON — it is a *claim graph* with nodes (claims) and edges (dependency, support, contradiction) that the constraint engine can traverse and validate.

### 5.1.3 Claim Graph Extraction

Once structured, LLM prose is converted into a graph of typed claims. The taxonomy distinguishes six kinds, each with distinct validation semantics:

| Claim Kind | Structure | Validation Target | Example |
|---|---|---|---|
| **Equation** | `lhs: Expr`, `rhs: Expr` | Symbolic equality, dimensional consistency, bound checking | $E = \gamma m c^2$ |
| **Inequality** | `lhs: Expr`, `op: OrderingOp`, `rhs: Expr` | Range consistency, monotonicity, physical limit adherence | $v < c$ |
| **Causal** | `cause: EntityId`, `effect: EntityId` | Graph reachability, cycle detection, temporal ordering | "Force causes acceleration" |
| **Definition** | `symbol: String`, `meaning: String` | Non-circularity, symbol uniqueness, type consistency | "Let $\gamma = (1-v^2/c^2)^{-1/2}$" |
| **Empirical** | `statement: String`, `evidence: Vec<EvidenceId>` | Evidence sufficiency, replication history, source reliability | "Supernova 1987A neutrinos arrived 3h before light" |
| **CodeInvariant** | `module: String`, `invariant: String` | Static analysis, formal verification, dynamic invariant detection | "`buffer.len() > 0` before `pop()`" |

The table encodes a key design decision: different claim kinds require different validators. An `Equation` is checked by symbolic algebra and dimensional analysis; an `Empirical` claim is checked by evidence sufficiency scoring and source reliability propagation; a `CodeInvariant` is checked by dynamic invariant detection (Daikon-style trace analysis) [^35^] or static verification via abstract interpretation [^37^]. The claim graph edges capture logical dependencies — an `Equation` may depend on a `Definition`, a `Causal` claim may be supported by multiple `Empirical` observations — enabling the engine to propagate confidence and detect contradictions across the graph.

Circuit-based Reasoning Verification (CRV), developed at Meta FAIR, provides a complementary signal. CRV treats attribution graphs of chain-of-thought steps as execution traces of latent reasoning circuits and trains a classifier on structural graph features to predict reasoning errors before claim extraction occurs [^50^]. When CRV flags a reasoning trace as structurally anomalous, the claim graph is marked with elevated uncertainty even before domain-specific validation begins.

## 5.2 Physics as Type Constraints

### 5.2.1 Compile-Time Dimensional Analysis

The most immediate way to make physical law executable is to embed it in the type system. The International System of Quantities (ISQ) defines physical dimensions as exponent vectors over seven base quantities: mass ($\text{M}$), length ($\text{L}$), time ($\text{T}$), electric current ($\text{I}$), thermodynamic temperature ($\Theta$), amount of substance ($\text{N}$), and luminous intensity ($\text{J}$). Any derived quantity — velocity, force, energy, pressure — is a product of these base dimensions with integer exponents. In a type-safe programming language, these exponents can be encoded at the type level, making dimensional mismatch a *compile error* rather than a runtime exception.

The Rust `uom` crate (Units of Measurement) provides automatic type-safe zero-cost dimensional analysis based on the ISQ, with over 7.8 million downloads and `no_std` compatibility [^4^]. The `dimensioned` crate performs equivalent analysis using the `typenum` library for type-level integer arithmetic on unit exponents [^5^]. Both crates exploit Rust's monomorphization: dimension types are fully erased at compile time, leaving no runtime metadata and no measurable overhead compared to raw numeric code [^47^]. A Stanford CS231n project demonstrated that const-generic shape-safe deep learning in Rust passes "raw pointers and integer literals to the backend, so there is no measurable overhead compared to a handwritten C loop" [^8^].

For Rex, the relevant capability is not merely unit conversion — it is *dimensional consistency as a logical firewall*. When a language model proposes an equation, that equation is parsed into a claim graph where every quantity carries a `Dimension`. The constraint engine checks that both sides of an equation share the same exponent vector. The operation is not a heuristic; it is a formal property enforced by the type system.

### 5.2.2 The `Quantity` Type and Runtime Enforcement

While `uom` and `dimensioned` provide the foundation, Rex needs a `Quantity` abstraction that bridges compile-time types with runtime claim validation — since model outputs arrive at runtime and must be checked dynamically. The implementation uses a seven-element exponent array and enforces dimension matching on every arithmetic operation:

```rust
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub struct Dimension {
    // M, L, T, I, Θ, N, J
    pub exponents: [i8; 7],
}
impl Dimension {
    pub const SCALAR: Self = Self { exponents: [0; 7] };
    pub const LENGTH: Self = Self { exponents: [0, 1, 0, 0, 0, 0, 0] };
    pub const TIME: Self = Self { exponents: [0, 0, 1, 0, 0, 0, 0] };
    pub const MASS: Self = Self { exponents: [1, 0, 0, 0, 0, 0, 0] };
    pub const VELOCITY: Self = Self { exponents: [0, 1, -1, 0, 0, 0, 0] };
    pub const FORCE: Self = Self { exponents: [1, 1, -2, 0, 0, 0, 0] };

    pub fn mul(self, rhs: Self) -> Self {
        let mut out = [0i8; 7];
        for i in 0..7 { out[i] = self.exponents[i] + rhs.exponents[i]; }
        Self { exponents: out }
    }
    pub fn div(self, rhs: Self) -> Self {
        let mut out = [0i8; 7];
        for i in 0..7 { out[i] = self.exponents[i] - rhs.exponents[i]; }
        Self { exponents: out }
    }
}

pub struct Quantity {
    pub value: f64,
    pub dim: Dimension,
    pub label: String,
}

pub fn add(a: &Quantity, b: &Quantity) -> Result<Quantity, String> {
    if a.dim != b.dim {
        return Err(format!(
            "dimension mismatch: cannot add {:?} to {:?}",
            a.dim.exponents, b.dim.exponents
        ));
    }
    Ok(Quantity {
        value: a.value + b.value,
        dim: a.dim,
        label: format!("({}+{})", a.label, b.label),
    })
}
```

The `add` function is the critical gate: it is impossible to add meters to seconds, or energy to force, without triggering a typed error. When the model outputs a claim like "the kinetic energy is $10\ \text{kg} + 5\ \text{m/s}$," the claim extractor parses the quantities, constructs `Quantity` objects, and the constraint engine calls `add`. The mismatch is caught and logged as a violation before the claim ever reaches the user. This is the operational meaning of "physics as a type system": dimensional analysis is not a post-hoc check performed by a human reviewer, but a compiler-enforced invariant on the reasoning substrate itself.

Rust's type system has been described as a "hallucination defense layer" for AI-generated code: when coding agents produce incorrect APIs or mismatched types, the compiler catches the error before execution [^43^]. The same principle extends to physical reasoning. A local 7B model wrapped in this system stops making a whole class of mistakes — unit errors, dimensional inconsistencies, physically impossible combinations — that much larger unconstrained models still produce.

### 5.2.3 PhysicsReward: A Six-Component Signal

Validation must be more than boolean pass/fail. The `PhysicsReward` signal provides a six-dimensional scalar feedback vector that guides both the repair loop (Chapter 8) and, through GRPO (Group Relative Policy Optimization), the training of the proposal model itself. Each component corresponds to a distinct epistemic criterion:

| Component | Mathematical Form | Enforcement Mechanism |
|---|---|---|
| **data_fidelity** | $\|\hat{y} - y_{\text{obs}}\|_2 / \sigma_{\text{obs}}$ | Statistical comparison against empirical observations |
| **physical_consistency** | $\|\mathcal{R}[\hat{u}]\|_2$ where $\mathcal{R}$ is PDE residual | PINN/FNO surrogate evaluation of PDE satisfaction |
| **novelty** | $1 - \cos(\hat{y}, \mathcal{M}_{\text{train}})$ | Divergence from training-set manifold |
| **falsifiability** | $-\log p(\text{counterexample found})$ | Property-directed falsification search |
| **parsimony** | $\|\theta\|_0 / \|\theta\|_{\text{max}}$ | Sparsity of learned Lagrangian or equation structure |
| **unit_consistency** | $\delta(\text{dim}(\text{lhs}), \text{dim}(\text{rhs}))$ | Dimensional type-checking via `Quantity.add()` |

The `physical_consistency` component is where physics-informed architectures enter the training loop. Rather than evaluating PDE residuals with traditional solvers (hours for Navier-Stokes), Rex uses a Fourier Neural Operator (FNO) surrogate that evaluates the residual in milliseconds. FNO achieves a $\sim440\times$ inference speedup over pseudo-spectral methods on a $256 \times 256$ grid [^1^], making it feasible to incorporate PDE-residual reward into GRPO's rule-based reward function without a critic model. The reward becomes:

$$R = R_{\text{correctness}} + \lambda \cdot R_{\text{FNO residual}} + \mu \cdot R_{\text{unit consistency}}$$

This is differentiable physics-informed reinforcement learning: the model learns to generate physically consistent solutions not because it has memorized physical law, but because the reward landscape penalizes inconsistency at the speed of neural inference.

## 5.3 The Dual Compile Target

### 5.3.1 From Ontology to Rust Traits and NN Constraints

The central architectural insight of this chapter — Insight 13 in the cross-dimensional synthesis — is that an ontological profile compiles to *two* enforcement targets simultaneously:

1. **Rust traits** for runtime claim validation: zero-cost structural and dimensional checks via monomorphization, typestate patterns for protocol enforcement [^48^], and linear ghost permissions for formal verification via Verus [^21^].
2. **Neural network architecture constraints** for structural inductive bias: Hamiltonian and Lagrangian network structures that make conservation laws physically impossible to violate by construction, rather than penalizing violations in a loss function.

The compilation is isomorphic: the same conservation law expressed in an `OntologicalProfile.invariants` entry becomes both a Rust trait bound (`trait ConservesEnergy: Dynamics { ... }`) and a Hamiltonian network layer structure. Changes to the ontology propagate to both targets automatically, preventing the specification drift that occurs when runtime checks and model architecture evolve independently.

### 5.3.2 Hamiltonian and Lagrangian Neural Networks

Hamiltonian Neural Networks (HNNs) learn a scalar energy function $H_\theta(q, p)$ from trajectory data and recover dynamics via Hamilton's equations [^23^]:

$$\dot{q} = \frac{\partial H_\theta}{\partial p}, \quad \dot{p} = -\frac{\partial H_\theta}{\partial q}$$

Because the network is not trained to predict $\dot{q}$ and $\dot{p}$ directly, but rather to predict the Hamiltonian whose symplectic gradient *yields* the dynamics, the learned quantity $H_\theta$ is conserved by construction over much longer integration horizons than baseline neural networks [^23^]. The architecture *engraves* Hamilton's equations into the network structure, making energy violation physically impossible at inference time — not merely unlikely due to loss-function penalties.

Lagrangian Neural Networks (LNNs) extend this to systems where canonical coordinates are unknown or inconvenient. By parameterizing arbitrary Lagrangians $L_\theta(q, \dot{q})$ and deriving dynamics through the Euler-Lagrange equation, LNNs handle relativistic particles, non-conservative constraints, and coordinate choices where Hamiltonian approaches fail [^25^]. The choice between HNN and LNN compilation depends on the ontological profile: if the domain specifies canonical coordinates and energy conservation, the compiler emits an HNN structure; if it specifies generalized coordinates with holonomic constraints, it emits an LNN structure.

### 5.3.3 SymDLNN: Auto-Discovering Conservation Laws

The limitation of HNNs and LNNs is that they require the conservation law to be known a priori — the architecture assumes energy is conserved, but it does not discover *which* symmetries are present in an arbitrary system. SymDLNN (Discrete Lagrangian Neural Networks with Automatic Symmetry Discovery) closes this gap [^15^]. It learns a discrete Lagrangian $L_d(q_k, q_{k+1})$ from trajectory data, then automatically identifies subgroups of affine transformations $(M, w)$ under which $L_d$ is invariant. Applying discrete Noether's theorem yields the conserved quantity:

$$I(q_k, q_{k+1}) = -(Mq_k + w)^T \nabla_{q_k} L_d(q_k, q_{k+1})$$

The significance for Rex is profound: a system observing trajectory data can auto-discover conservation laws without human guidance, add them to its `OntologicalProfile.invariants`, and recompile the dual target so that both the Rust constraint engine and the neural architecture enforce the newly discovered law. This creates a closed loop of *structure discovery → ontology update → compile-target propagation → enforced consistency* — a form of machine-driven theory formation where the output is not merely a predictive model but a formally typed conservation law.

## 5.4 Falsifiability and Evidence Evaluation

### 5.4.1 The BEWA Framework

A deterministic superintelligence substrate must evaluate claims not only for internal consistency but for epistemic robustness. The BEWA (Bayesian Epistemology-Weighted Architecture) framework formalizes belief as a probabilistic relation over structured claims, indexed to authors, contexts, and replication history [^9^]. It integrates five design principles:

1. **Compositional Modularity**: each claim is evaluated independently, then combined via Bayesian belief networks.
2. **Evidential Locality**: evidence sufficiency is assessed per-claim, not per-document.
3. **Non-Monotonic Reversibility**: new evidence can reduce belief, not merely accumulate it.
4. **Temporal Sensitivity**: belief decays with time since last replication, with half-lives configurable per domain.
5. **Proof-Carrying Claims**: every claim object carries a formal trace of its derivation, inspired by Necula's Proof-Carrying Code (PCC) architecture [^7^].

The fifth principle is the critical bridge to Rex. Necula's original PCC required code fragments to carry proofs of safety-policy satisfaction, with validation times of $0.3$–$1.3\ \text{ms}$ and proof sizes of $300$–$900$ bytes [^7^]. BEWA adapts this to epistemic claims: every claim in the graph carries a derivation trace (how it was extracted, which model generated it, which validators checked it, which assumptions it depends on). A downstream consumer — human or agent — can verify the chain without re-executing the full extraction and validation pipeline.

### 5.4.2 Property-Directed Neural Network Falsification

Verification — proving a claim correct for all possible inputs — is computationally intractable for neural networks of production scale. Alpha-beta-CROWN, the state-of-the-art neural network verifier, handles networks with millions of parameters but cannot scale to transformer architectures. Falsification, by contrast, searches for *counterexamples* that disprove a claim, and is orders of magnitude faster.

Das and Mohalik's property-directed falsification algorithm directs counterexample search using derivative-free sampling-based optimization guided by safety property specifications [^31^]. On the ACAS Xu airborne collision avoidance benchmarks against ten safety properties, the falsification procedure detects all unsafe instances that verification tools also flag, and identifies most of them "by orders of magnitude" faster than state-of-the-art verifiers (NNENUM, Neurify) [^31^]. The algorithm is sound but incomplete: when it terminates without finding a counterexample, safety cannot be guaranteed — but the absence of a falsifying input after extensive search provides a defeasible confidence signal.

In Rex, falsification serves as a first-line filter in the `falsifiability` component of `PhysicsReward`. A proposed equation or neural dynamics model is subjected to property-directed search before it is promoted to the verification tier. Claims that survive falsification are marked with elevated confidence; claims that are falsified are rejected immediately, with the counterexample fed back into the repair loop.

### 5.4.3 Evidence Sufficiency and Information-Theoretic Bounds

The final gate in the evaluation pipeline is evidence sufficiency scoring. A claim that is internally consistent, dimensionally valid, and unfalsified may still be overconfident if the evidence supporting it is thin. BEWA addresses this through explicit evidence weighting, but Rex adds an information-theoretic bound: the Shannon entropy of the evidence distribution sets a lower bound on the uncertainty of the claim.

The mechanism operates as follows. For an empirical claim supported by $n$ independent observations, the evidence sufficiency score is:

$$S_{\text{evidence}} = 1 - \frac{H(p)}{H_{\text{max}}} = 1 - \frac{-\sum_i p_i \log p_i}{\log n}$$

where $p_i$ is the normalized reliability weight of the $i$-th source. When evidence is concentrated in a single source ($p_1 = 1$), the score approaches zero — the claim is inadequately supported. When evidence is distributed across independent, high-reliability sources, the score approaches one. Claims with $S_{\text{evidence}} < \theta_{\text{domain}}$ are flagged as speculative and withheld from commitment unless the user explicitly overrides the threshold.

This scoring prevents a failure mode common in both human and machine reasoning: the conflation of internal coherence with external warrant. A beautifully consistent physical theory built on a single unverified measurement receives a low sufficiency score, no matter how elegant its equations. The ontology runtime treats coherence as necessary but not sufficient — a claim must also carry adequate evidentiary mass before it is admitted to the knowledge graph.

---

The executable ontology architecture described in this chapter transforms the relationship between AI systems and physical law. Physics is no longer a domain of knowledge that models may or may not have learned correctly; it is a compiler constraint that shapes both the software checking the model and the neural architecture generating proposals. The dual compile target — Rust traits for zero-cost validation and Hamiltonian/Lagrangian structures for conservation-by-construction — ensures that the same specification enforces correctness at both levels. When combined with real-time claim extraction via XGrammar, dimensional analysis via type-level SI units, falsification-driven confidence scoring, and information-theoretic evidence bounds, the result is a reasoning substrate where invalid physical claims are caught as early as type-checking catches invalid code: at the boundary between proposal and commitment.
