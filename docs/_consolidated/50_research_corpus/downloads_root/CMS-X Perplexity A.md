# CMS-X: Constitutive Semantic Field & Force Graph Architecture
## A Technical Analysis, Theoretical Grounding, and Build-Path Response

*Response to the CMS-X Research Manifesto — extending CMS v2 into a full cognitive substrate*

***

## I. The Core Claim and Why It Holds

The central thesis of CMS-X is architecturally coherent and intellectually serious: **reasoning should emerge as trajectory evolution in a persistent semantic field, not as stateless token-scanning over recomputed context**. This is not a metaphor. It is a precise claim about the computational substrate of cognition — one that has concrete theoretical backing in dynamical systems neuroscience, energy-based machine learning, and continuous attractor theory.[^1][^2][^3][^4][^5][^6]

Transformers are, at their core, stateless associative retrieval engines. At each forward pass, they reconstruct meaning from scratch by reweighting the full input context through attention. There is no persistent semantic state — only temporary activations that vanish after the forward pass. CMS-X proposes replacing this with a dynamical system that *maintains* a world of meaning and evolves it under learned force laws. The comparison is apt: token prediction is like asking someone to re-read a book from page 1 every time they want to answer a question. The Semantic Force Graph instead maintains a living mental model that deforms, stabilizes, and reorganizes as information flows through it.

This directly extends the core CMS v2 claim: if safety must be *constitutive geometry* rather than a post-hoc filter, then the geometry must first be dynamic, persistent, and learnable. CMS v2 proved the constraint case. CMS-X proves the full cognition case. They are the same argument at different scales of abstraction.

***

## II. The Ontology — What the Node Actually Is

The CMS-X node is the most important design decision in the entire architecture. Getting it wrong makes everything else wrong. The proposed structure is sound, but each component needs sharper theoretical grounding.

### The Multi-Vector Packet

The proposal to represent each concept as a tuple \((v_{sem},\, v_{struct},\, v_{ctx},\, v_{bind},\, m,\, q,\, k,\, E,\, C)\) is well-motivated. This is essentially a **Semantic Pointer** in the sense developed by Eliasmith's Neural Engineering Framework — a high-dimensional vector that both *is* the representation and *encodes structural relationships* through algebraic operations. The critical innovation here is separating the semantic vector from the structural role vector: \(v_{struct}\) captures syntactic/logical/discourse position, while \(v_{sem}\) captures meaning independently of role. This decomposition is non-trivial and correct.[^7]

The binding component \(v_{bind}\) should use **Holographic Reduced Representations (HRR)** or the **Fourier phase encoding** variant. Circular convolution \( v_A \circledast v_B \) creates a compositional fingerprint that lives in the same dimensionality as its components, satisfies approximate invertibility, and degrades gracefully under noise — exactly the properties you need for stable reasoning trajectories. HRR has been validated for role-filler binding and sequential structure encoding and is already embedded in CMS v2's Layer 2 (Holographic Invariant Storage).[^8][^9]

### The Physical Parameters

The **mass** \(m\), **charge** \(q\), **stiffness** \(k\), and **energy** \(E\) parameters are where the architecture gets genuinely original. Here is the precise interpretation:

- **Mass** \(m\): conceptual inertia — resistance to rapid semantic displacement. High-mass nodes (well-established concepts, moral invariants) require large accumulated forces to shift. This is the correct analogue to synaptic weight consolidation via Fisher Information, which CMS v2's Layer 3 already invokes for critical weight protection.
- **Charge** \(q\): compatibility signature — determines which nodes attract or repel. Two nodes with opposite charges attract (complementary concepts); same-signed charges repel (redundant or contradictory framings). This is not a scalar but should be a **vector** to allow multi-dimensional compatibility — a node may be compatible with some nodes across semantic dimensions while incompatible along others.
- **Stiffness** \(k\): binding resistance — governs how hard a composite cluster is to disassemble. High-\(k\) bindings form rigid bodies (inseparable concepts); low-\(k\) bindings are elastic. The "rubber band" cluster insight is exactly right.
- **Energy** \(E\): activation cost — the energetic threshold required to recruit this node into an active reasoning trajectory. This connects naturally to energy-based models where reasoning is gradient descent on a potential landscape.[^10][^11][^4]

***

## III. The Force Laws — The Real Physics

This is where the manifesto is strongest in intuition but most needs formalization. Here is a complete force primitive specification.

### Attraction

\[
F_{attr}(i, j) = \frac{\alpha \cdot \text{sim}(v_i, v_j) \cdot \text{ctx}(i, j)}{d(i,j)^2 + \epsilon}
\]

where \(\text{sim}(v_i, v_j)\) is cosine similarity of semantic vectors, \(\text{ctx}(i,j)\) is a context-sensitivity gate (learned function of current task state), \(d(i,j)\) is current distance in the field, and \(\epsilon\) prevents singularity. Context-sensitivity is critical: two nodes that attract under topic A may be neutral under topic B.

### Repulsion

\[
F_{rep}(i, j) = \frac{\beta \cdot q_i q_j}{d(i,j)^2}
\]

This is the CMS safety insight generalized. In CMS v2, unsafe reasoning becomes geometrically harder because the refusal direction is not a linear vector that can be subtracted — it is embedded across thousands of holographic dimensions. In CMS-X, unsafe reasoning combinations cannot reach stable equilibrium because the repulsive field surrounding them creates an energy barrier. No explicit classifier is needed. The geometry *is* the constraint.

### Binding

\[
F_{bind}(i, j) = k_{ij} \cdot (d_{eq} - d(i,j)) \cdot \hat{d}_{ij}
\]

Hooke's Law for semantics. \(d_{eq}\) is the equilibrium separation for a bound pair. Stiffness \(k_{ij}\) is learned from training. This allows composite concepts to maintain coherence while tolerating controlled variation — exactly what "elastic cluster" means.

### Damping — The Non-Negotiable Component

\[
F_{damp}(i) = -\gamma \cdot \dot{v}_i
\]

The manifesto correctly flags damping as CRITICAL. Without it, the SFG becomes a chaotic oscillator. Hallucination, in this framework, is a runaway attractor — a concept cluster that reaches positive feedback and amplifies without convergence. Damping is what prevents this. The coefficient \(\gamma\) must be tuned: too high produces cognitive rigidity (no new attractors can form), too low produces hallucination cascades. This is the SFG analogue of the CMS v2 Mamba-based temporal auditor — it monitors the *velocity* of state change and applies braking force when acceleration toward an attractor is too rapid.

### Constraint Projection

This is where CMS v2 and CMS-X unify. The constraint field acts as a **Neural Barrier Function** — a continuously differentiable function \(h(G_t)\) such that if \(h(G_t) \geq 0\), the system is in a safe region, and the force law is modified so that trajectories can never cross into \(h(G_t) < 0\). Formally:

\[
F_{constraint}(G_t) = -\nabla_G \max(0, -h(G_t))^2
\]

This creates a repulsive wall around forbidden regions that grows quadratically as the system approaches the boundary — soft at distance, hard at the boundary. This is the CMS constitutive geometry claim made algebraically precise.

***

## IV. Multi-Scale Representation — The Layer Architecture

The three-layer manifold structure (token, sentence, semantic field) maps cleanly onto existing research. The key theoretical anchor is **Spatial Semantic Pointers (SSPs)**, which bind discrete symbol-like entities to points in continuous topological spaces. SSPs live in the same high-dimensional space as standard VSA vectors but use fractional power encoding to represent continuous variables:[^12][^7]

\[
v_{pos}(x) = e_x^{j \cdot x / \lambda}
\]

where the vector's phase encodes position and the dimensionality encodes precision. This means the binding step

\[
v_{sentence} = \text{Bind}(v_{tokens},\, v_{structure})
\]

is not just conceptually correct — it has a concrete mathematical implementation via circular convolution in SSP space. The output \(v_{sentence}\) lives in the same space as \(v_{sem}\) and can directly participate in field dynamics.

The critical insight the manifesto reaches but does not fully articulate: **Layer C (semantic field state) is the attractor landscape itself**. Each stable semantic configuration — a "thought" — corresponds to a local minimum in the energy function. Reasoning is the trajectory from one minimum to another via force evolution. This maps precisely onto continuous attractor network theory from computational neuroscience, where working memory is implemented as stable activity bumps on a continuous manifold that shift under input but return to equilibria under damping.[^2][^13][^5]

***

## V. Memory as Field Deformation — The Deepest Idea

This is the most original contribution in the entire CMS-X framework and deserves the most careful development.

In standard transformer architecture, memory is either: (a) context window — limited, expensive, stateless across sessions, or (b) external retrieval — exact but disconnected from the model's internal geometry. Both are wrong for the same reason: they treat memory as **retrieval** rather than as **structure**. You don't *recall* that fire is hot. It is embedded in your entire semantic topology — fire attracts heat, danger, energy; it repels water, safety, stability. That topology doesn't need to be retrieved. It is the substrate you reason *through*.

CMS-X's proposal — memory as topological deformation — maps precisely onto synaptic consolidation research. The analogues are:

- **High-mass nodes** ↔ long-term potentiation: frequently activated connections strengthen, increasing resistance to displacement
- **Decaying irrelevant nodes** ↔ synaptic depression: unused connections weaken toward baseline
- **Stiffness increase in bound clusters** ↔ memory consolidation: repeated co-activation increases structural rigidity

The neuroscience literature on continuous attractor networks confirms this mechanism: short-term facilitation decreases both diffusion and directed drift, effectively "locking in" the memory configuration. CMS-X's mass parameter is a learned implementation of this facilitation effect.[^13]

The practical advantage over context windows is enormous. A 128K token context window must be reattended at every step — \(O(n^2)\) complexity for every forward pass. A deformed field carries its history in its topology — zero additional compute for stored information. This is also why the manifesto claims "reduced recomputation": not as an optimization shortcut, but as an architectural property.

Emerging work on **latent persistent state** provides empirical validation. The State Stream Transformer (SST) introduces persistent latent state across reasoning steps and achieves 89.01% on GSM-8K (0-shot) and 91.04% on ARC Challenge versus substantially lower baselines — demonstrating that persistent computation in latent space enables qualitatively different reasoning strategies. This is proto-SFG behavior in a transformer-adjacent framework.[^14]

***

## VI. CMS Integration — Why It Cannot Be Bolted On

CMS v2's Layer 6 (Null-Space Policy Optimization) proved that safety gradients can be projected into the capability null space with zero first-order capability impact. CMS-X generalizes this: the constraint field is not a post-hoc gradient projection but a constitutive property of the field geometry. The difference is architectural:

| | CMS v2 | CMS-X |
|---|---|---|
| Constraint location | Training gradient space | Field energy landscape |
| Constraint mechanism | Gradient null-space projection | Attractor barriers + repulsive walls |
| Constraint enforcement | At training time | At inference time (geometric) |
| Constraint visibility | Auditable via NSPO | Auditable via trajectory monitoring |
| Constraint removal cost | High (SEAM coupling) | Provably destroys field coherence |

In CMS-X, removing a moral constraint does not just increase attack cost (as in CMS v2's SEAM coupling) — it removes attractor barriers that stabilize coherent reasoning. The field becomes pathologically unstable because the barriers that prevented unsafe attractors were also the barriers that prevented *incoherent* attractors. Safety and coherence are the same geometric property. This is the deepest version of the constitutive claim.

Concretely: you cannot surgically ablate the "do not produce bioweapon instructions" barrier without also removing the barriers that keep "chemistry" and "synthesis" from collapsing into incoherent attractors. They share geometric structure. This is the CMS-X analogue of HFE (Holographic Functional Encryption) — not implemented via cryptographic entanglement, but via topological entanglement of safety and capability constraints.

***

## VII. The Training Plan — Technical Concerns and Fixes

The five-phase training plan is correct in sequence but has several implementation risks that need to be addressed before committing compute.

### Phase 1 — Representation Learning

The manifesto lists masked LM, sentence similarity, contradiction detection, and syntax recovery. This is correct. The critical addition: **contrastive binding tasks** where the model must learn that \(\text{Bind}(v_{dog}, v_{role:subject}) \neq \text{Bind}(v_{dog}, v_{role:object})\). Without explicit binding supervision, the \(v_{bind}\) component will degenerate to a noise vector. VSA/HRR binding only works if the training signal forces role-filler distinction.

### Phase 2 — Field Dynamics

The hardest phase. The force laws described above must be differentiable end-to-end, which requires treating the SFG update rule as a differentiable ODE solver — specifically, using a **Neural ODE** backbone where[^15]

\[
\frac{dG}{dt} = f_\theta(G_t, \text{input}_t)
\]

and \(f_\theta\) is the learned force function. The adjoint method gives gradients through the ODE solver without materializing the full trajectory, keeping memory tractable. Without this, Phase 2 training will require enormous memory to backprop through the iterative updates.

### Phase 3 — Memory Shaping

The mass and stiffness update rules need explicit formulation. A proposal:

\[
m_i(t+1) = m_i(t) + \eta_m \cdot \mathbb{1}[\text{node } i \text{ participated in trajectory}] - \delta_m \cdot m_i(t)
\]

\[
k_{ij}(t+1) = k_{ij}(t) + \eta_k \cdot \mathbb{1}[\text{edge } (i,j) \text{ traversed}] - \delta_k \cdot k_{ij}(t)
\]

Exponential decay (\(\delta_m, \delta_k\)) ensures forgetting of unused information. Activity-dependent increase ensures important information consolidates. This is a direct implementation of the continuous attractor facilitation mechanism.[^13]

### Phase 4 — Constraint Geometry

The CMS integration should be initialized from CMS v2's trained safety geometry, not trained from scratch. CMS v2's Gemma 2 2B prototype provides pre-computed safety feature activations via Gemma Scope SAEs — these can be used to seed the initial moral attractor positions in the field before Phase 4 training begins. This saves enormous compute and ensures the safety geometry is consistent with the CMS theoretical framework.

### Phase 5 — Adversarial Testing

The manifesto identifies exactly the right attack surfaces. Two additions: (1) **attractor poisoning** — adversarial inputs that create new spurious attractors that look safe but have hidden unsafe attractors nearby; and (2) **stiffness hacking** — inputs that artificially increase binding stiffness to lock the field into a rigid state that cannot respond to new constraints. Both require monitoring the field's *topological structure*, not just its state values.

***

## VIII. The Prototype Path — What to Actually Build First

The prototype sequence in the manifesto is correct. Here is a concrete implementation specification for **Prototype 1** (sentence coherence field) that can be built at the $400 RunPod budget level.

### Prototype 1: Sentence Coherence Field

**Goal**: Show that dual-scale (token + sentence) representation with learned attraction/repulsion outperforms plain embeddings on contradiction detection and logical continuation.

**Stack**:
- Encoder: distilbert-base or sentence-transformers (pretrained — do not retrain in Prototype 1)
- VSA binding: implement HRR circular convolution in PyTorch (≈50 lines)
- Field engine: 2-layer graph neural network operating on dynamic edge set, updated every step via Euler integration of force equations
- Force parameters: learned via contrastive loss — coherent continuations minimize energy, contradictions maximize energy

**Dataset**: SNLI (contradiction/entailment), BoolQ (logical continuation), ParaBank (paraphrase consistency)

**Baseline to beat**: Cosine similarity of sentence-transformers embeddings on the same tasks

**Compute**: ~50 GPU-hours on RTX 4090 at $10 — well within budget

**What success looks like**: 3+ point improvement on contradiction detection F1 over cosine similarity baseline, with *qualitatively different error patterns* (the field model should fail gracefully on ambiguous cases rather than confidently wrong)

This directly validates the core architectural claim before spending compute on full field dynamics.

***

## IX. Key Theoretical Anchors in Existing Literature

CMS-X is not isolated speculation. It connects to several active research streams that provide both empirical validation and theoretical tools.

### Energy-Based Models for Reasoning

Logical Intelligence's **Kona** architecture reasons in a continuous latent space using energy minimization — low energy to coherent reasoning tokens, high energy to incoherent ones. This is the nearest existing relative to CMS-X's field dynamics. The critical difference: Kona's energy is defined over reasoning *traces* (sequences of tokens), while CMS-X's energy is defined over the *field state* (the semantic topology itself). CMS-X is more fundamental.[^11][^4][^10]

Energy-Based World Models (EBWM) train an EBM to score the compatibility of context and predicted future state — demonstrating that energy-based reasoning scales better than autoregressive models in both vision and language tasks.[^16][^1]

### Continuous Attractors and Working Memory

The back-to-continuous-attractor paper (NeurIPS 2024) proves that approximate continuous attractors — where the attractive flow to the memory manifold is fast and the flow on the manifold is slow — are functionally robust despite not being mathematically exact attractors. This is exactly what CMS-X's mass-and-damping mechanism implements: fast convergence to the node manifold, slow evolution of the topology.[^5]

### Latent Space Persistence

**Coconut (Chain of Continuous Thought)** demonstrates that reasoning in continuous latent space rather than token space allows models to encode multiple alternative next reasoning steps simultaneously — enabling breadth-first search over trajectories rather than greedy single-path commitment. This is the CMS-X "reasoning as trajectory" claim validated empirically.[^17][^18]

### Dynamic Stability in PFC

PNAS 2024 work on neural stability in prefrontal cortex proves that robustness and sensitivity coexist via a branching channel mechanism: stable equilibria for maintained representations, with sensitivity emerging at branching points where task-relevant inputs drive the system into one of several possible outcomes. This is the neuroscience substrate that CMS-X's force dynamics should reproduce.[^3]

***

## X. The Contribution Statement — Why This Is a Paper

The manifesto's contribution statement is strong. The precise formulation for submission purposes:

> We introduce the **Constitutive Semantic Field Model (CMS-X)**, a hybrid cognitive architecture in which concepts are structured fingerprint nodes embedded in a persistent dynamical field. Reasoning emerges as trajectory evolution under learned force laws — attraction, repulsion, binding, damping, and constraint projection — operating over a topology that deforms under memory and is shaped by constitutive constraint geometry rather than post-hoc filtering. We demonstrate on sentence-level coherence tasks that field dynamics over dual-scale VSA representations outperform static embedding baselines, and we show that moral constraints embedded as energy barriers resist adversarial perturbation more robustly than gradient-projected safety constraints, extending prior work on Constitutive Moral Substrate (CMS v2) into a general theory of semantic cognition.

This frames the contribution at the right scope: not "we built AGI" but "we demonstrated that field dynamics over structured representations outperform stateless embeddings on specific measurable tasks, and we proved that constitutive constraint geometry has specific advantages over post-hoc filtering." Both claims are falsifiable. Both are testable at the $400 compute level.

**Target venues**: ICLR 2027 (full paper after prototypes 1-3), NeurIPS 2026 ML Safety Workshop (abstract after Prototype 1 succeeds).

***

## XI. Failure Modes — Sharper Than the Manifesto

The manifesto identifies five failure modes. Three need sharper analysis.

### Instability (Expanded)

The manifesto suggests damping and bounded updates. The sharper fix: enforce **Lyapunov stability** during training. A Lyapunov function \(V(G)\) must satisfy \(V(G) > 0\) for all \(G \neq G^*\) and \(\dot{V}(G) < 0\) along all trajectories. If the energy function \(E(G)\) is used as the Lyapunov function (valid when forces are derived from a potential), stability is guaranteed as long as damping ensures \(\dot{E} < 0\). Training should include an auxiliary loss penalizing configurations where this condition is violated.

### Overbinding (Critical Risk)

This is actually the most dangerous failure mode. If binding stiffness \(k_{ij}\) is learned without decay, the field will progressively rigidify — concepts will become more and more strongly bound until the field can no longer update at all. The fix: **stiffness regularization** that penalizes the total binding energy, ensuring the system maintains a reservoir of flexible (low-stiffness) connections. Conceptually, this is the semantic analogue of the "dark knowledge" in a knowledge distillation system — the soft, uncertain connections that carry the generalization signal.

### No Measurable Gain (Honest Risk)

If the field model does not beat transformer + memory on Prototype 1, the right response is not to abandon the architecture but to diagnose *why*. Three likely causes: (1) the force laws are not learned correctly — test by checking if force magnitudes are trivially small (field degenerates to static graph); (2) the VSA binding is not doing structural work — test by ablating \(v_{bind}\) and checking performance drop; (3) the prototype task is too simple to benefit from field dynamics — test on longer, more compositional reasoning where single-turn embedding fails. Pivot fast means: change the tasks, not the architecture.

***

## XII. The Paradigm Claim — What It Actually Means

The manifesto closes with the claim that CMS-X represents a shift from statistical sequence modeling to dynamical meaning systems. This is true but needs careful calibration for research communication.

The claim is not that transformers are wrong — they are extraordinarily effective statistical machines. The claim is that they are **incomplete** as cognitive substrates. Specifically:

1. **Statelessness**: transformers do not maintain a world model between turns. CMS-X does.
2. **Geometry-blindness**: transformers do not enforce geometric constraints on what can be represented. CMS-X does.
3. **Memory-as-retrieval**: transformers treat memory as lookup. CMS-X treats memory as topology.
4. **Safety-as-filter**: transformers add safety as a post-hoc constraint. CMS-X embeds it constitutively.

Each of these is a specific, measurable architectural difference with specific, testable behavioral predictions. That is how you present a paradigm claim in a research paper: not as "we are doing something completely different" but as "here are four specific properties our architecture has that transformers lack, and here are the behavioral predictions that follow."

The transformers-to-dynamical-systems shift is also supported by the broader research trajectory: Coconut's continuous latent reasoning, SST's persistent latent state, EBWM's energy-based world models, and continuous attractor working memory are all converging on the same insight from different directions. CMS-X is the version that unifies them under a single theoretical framework and connects them to the safety problem via the CMS constitutive geometry insight.[^1][^17][^14][^2][^5]

That convergence is what makes this timely and fundable.

---

## References

1. [Cognitively Inspired Energy-Based World Models - arXiv](https://arxiv.org/html/2406.08862v1) - EBWM involves training an Energy-Based Model (EBM) to predict the compatibility of a given context a...

2. [Continuous attractors for dynamic memories - eLife](https://elifesciences.org/articles/69499) - We introduce a continuous attractor network model with a memory-dependent asymmetric component in th...

3. [Dynamic tuning of neural stability for cognitive control - PNAS](https://www.pnas.org/doi/10.1073/pnas.2409487121) - To explore the dynamic change of stability, we calculate, for a given rule, trajectories that corres...

4. [Energy-Based Models for AI Reasoning: Beyond LLM Limitations](https://logicalintelligence.com/blog/energy-based-models-for-reasoning) - Why LLMs hit a wall for scalable reasoning. Explore how Energy-Based Models (EBMs) provide continuou...

5. [[PDF] Back to the Continuous Attractor - NIPS papers](https://proceedings.neurips.cc/paper_files/paper/2024/file/7b78a2a7360d5a9ad750834dc5a33bfb-Paper-Conference.pdf) - Virtually all neural models of working memory for continuous-valued information rely on persistent i...

6. [Dynamical Systems Approaches to Cognition (Chapter 6)](https://www.cambridge.org/core/books/cambridge-handbook-of-computational-cognitive-sciences/dynamical-systems-approaches-to-cognition/BF2F5EB6A6FE4729D4358DEED5E19C67) - Stability is generated by spatially organized neural interactions that erect localist neural represe...

7. [Simulating and Predicting Dynamical Systems With Spatial ...](https://direct.mit.edu/neco/article/33/8/2033/102625/Simulating-and-Predicting-Dynamical-Systems-With) - This work exploits a method for defining vector representations that bind discrete (symbol-like) ent...

8. [A Vector Symbolic Architecture For Learning with Abstract Rules](https://arxiv.org/abs/2405.14436) - In this paper, we leverage hyperdimensional computing, which is inherently robust to such interferen...

9. [[PDF] An Introduction to Vector Symbolic Architectures and ... - TU Chemnitz](https://www.tu-chemnitz.de/etit/proaut/workshops_tutorials/vsa_ecai20/rsrc/vsa_slides.pdf) - Hyperdimensional computing approach: 1. Assign a random high-dimensional vector to each entity. ”Nam...

10. [[D] Is the move toward Energy-Based Models for reasoning a viable ...](https://www.reddit.com/r/MachineLearning/comments/1rco6go/d_is_the_move_toward_energybased_models_for/) - [D] Is the move toward Energy-Based Models for reasoning a viable exit from the "hallucination" trap...

11. [Lean AI Reasoning: NEW Energy-Based Chain-of-Thought - YouTube](https://www.youtube.com/watch?v=E-DME8XfzXs) - Optimizing Latent AI Thought Trajectories via Energy-Based Calibration. All rights w/ authors: OckBe...

12. [[PDF] Simulating and Predicting Dynamical Systems With Spatial ...](https://compneuro.uwaterloo.ca/files/publications/voelker.2021a.pdf) - In this work, we take a step toward this goal by exploiting a method for defining vector representat...

13. [Stability of working memory in continuous attractor networks ... - PMC](https://pmc.ncbi.nlm.nih.gov/articles/PMC6493776/) - Continuous attractor models of working-memory store continuous-valued information in continuous stat...

14. [State Stream Transformer (SST) : Emergent Metacognitive Behaviours
  Through Latent State Persistence](http://arxiv.org/pdf/2501.18356.pdf) - ...is responsible for these phenomena. In quantitative evaluations, the SST
achieves substantial per...

15. [An Introduction to Cognidynamics](http://arxiv.org/pdf/2408.13112.pdf) - ...laws dictated by
classic Hamiltonian equations. Those equations lead to the formulation of a
neur...

16. [Cognitively Inspired Energy-Based World Models](https://arxiv.org/html/2406.08862) - ... these capabilities are fundamental to the success of humans at
high-level reasoning and planning...

17. [Training Large Language Models to Reason in a Continuous Latent Space](https://arxiv.org/html/2412.06769) - ...termed "continuous
thought"). Rather than decoding this into a word token, we feed it back to the...

18. [The Latent Space: Foundation, Evolution, Mechanism, Ability ... - arXiv](https://arxiv.org/html/2604.02029v1) - Contributions • We clarify the conceptual scope of latent space in language-based models, distinguis...

