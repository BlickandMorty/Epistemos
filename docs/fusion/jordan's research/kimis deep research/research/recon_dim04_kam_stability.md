# Dimension 04: KAM Stability for Capability Boundaries

## Key Findings

1. **KAM theory has been explicitly combined with statistical learning theory** to prove that Hamiltonian neural networks (HNNs) preserve quasi-periodic behaviors even with non-zero training loss, provided the loss is sufficiently small [^2842^]. The generalization error bound combined with KAM theory shows that trained models can be regarded as perturbed Hamiltonian systems whose periodic motions are stable under small perturbations. This provides a direct mathematical bridge between learning theory and dynamical systems stability.

2. **The golden ratio φ is the "most irrational" number** — its continued fraction expansion [1; 1, 1, 1, ...] has the slowest convergence of any irrational number, making it maximally resistant to rational approximation [^2869^][^2870^]. Hurwitz's theorem states that for every irrational ξ there are infinitely many relatively prime integers m, n such that |ξ − m/n| < 1/(√5 n²), and the constant √5 is the best possible; if replaced by any A > √5, the statement becomes false for ξ = φ [^2874^].

3. **In the standard map, the last surviving KAM torus has winding number equal to the golden mean**, and it breaks down at a critical parameter K_c ≈ 0.971635 [^2907^][^2908^]. This "Golden Torus" is the last invariant curve to disappear because φ is farthest from all rational numbers in a Diophantine sense.

4. **Lyapunov exponents directly quantify neural network training stability**: the largest Lyapunov exponent λ_max measures the asymptotic rate of trajectory expansion/contraction in weight space [^2862^][^2863^]. For RNNs, the condition number of the long-term Jacobian is approximated by κ₂ ≈ exp((λ_max − λ_min)s), directly linking forward dynamics stability to gradient backpropagation stability [^2863^].

5. **The stability-plasticity dilemma in continual learning** maps precisely to the KAM persistence problem: "stable" networks (smaller weight norms, flatter minima) forget less but learn new tasks more slowly, while "plastic" networks (larger weight updates, sharper minima) learn quickly but suffer catastrophic forgetting [^2902^][^2866^]. The weight displacement norm ‖Δw‖ correlates directly with forgetting magnitude [^2866^].

6. **Emergent capabilities in large language models exhibit phase-transition-like behavior**: performance jumps discontinuously at critical scales, modeled by sigmoid transitions in log-parameter space [^2890^]. This mirrors percolation theory's critical threshold p_c, where an infinite connected cluster suddenly appears [^2844^][^2887^].

7. **KAM theory extends to dissipative systems** through conformally symplectic systems, which transform the symplectic form into a multiple of itself [^2941^][^2938^]. In dissipative KAM, one must adjust a "drift parameter" to find invariant attractors with preassigned frequency — a direct analogue to adjusting hyperparameters to maintain capability stability under non-conservative (gradient descent) dynamics.

8. **Arnol'd diffusion describes how orbits in high-dimensional Hamiltonian systems can undergo large excursions in action variables** even for arbitrarily small perturbations ε, by traversing chains of transition tori through resonance gaps [^2864^]. This provides the mechanism for "capability drift" across residency levels when perturbations exceed local stability thresholds.

9. **Percolation theory provides the mathematical framework for critical mass thresholds**: the order parameter P_∞(p) ∝ (p − p_c)^β for p → p_c⁺, where p_c is the critical occupation probability [^2844^]. In network models of relational frames, a percolation threshold marks the transition from isolated frames to a self-organizing network where "new nodes can instantly connect to existing relations" [^2841^].

10. **The Neural Tangent Kernel (NTK) regime creates invariant structures in function space**: in the "lazy regime," the NTK remains effectively static during training, reducing dynamics to kernel gradient descent with closed-form solutions [^2901^]. The NTK invariance is established via a Lyapunov function Γ_L(t) bounded by Gronwall's lemma [^2914^].


## Formal Definitions

### Definition 1: KAM Torus as Capability Invariant Set
A learned capability C at residency level L_k corresponds to a quasi-periodic invariant torus T^n in weight space W. The capability is parameterized by an embedding K: T^n → W satisfying the invariance equation under the training dynamics flow Φ_t:

> Φ_t ∘ K(θ) = K(θ + ωt)    for θ ∈ T^n

where ω ∈ ℝ^n is the frequency vector characterizing the capability's "winding pattern" across the network's functional dimensions [^2906^][^2911^].

### Definition 2: Diophantine Condition for Capability Stability
A capability C with frequency vector ω satisfies the Diophantine condition with constants γ > 0, τ > n − 1 if:

> |⟨ω, k⟩| ≥ γ / |k|^τ     for all k ∈ ℤ^n \ {0}

This ensures the capability is "sufficiently irrational" — maximally distant from resonant (rational) frequency ratios that would cause instability under perturbation [^2906^][^2915^]. The set of such ω has full Lebesgue measure in ℝ^n for τ > n − 1 [^2915^].

### Definition 3: Golden Ratio Stability Threshold
The golden ratio φ = (1 + √5)/2 provides the optimal Diophantine constant. For a 1D frequency ratio (n = 1), the Diophantine condition reduces to:

> |ω − p/q| ≥ γ / q^2     for all p/q ∈ ℚ

The golden ratio achieves the largest possible γ = 1/√5 (Hurwitz's theorem) [^2874^]. For capability scheduling, we define the φ-threshold as:

> ε_φ = γ_φ · |k|^{−τ}     with γ_φ = φ^{−2} ≈ 0.382

### Definition 4: Perturbation in Capability Space
For a neural network f(·; w) with weights w, the perturbation magnitude under a weight update Δw is quantified by the Lipschitz bound on the function space perturbation [^2939^][^2945^]:

> ‖f(·; w + Δw) − f(·; w)‖ ≤ L_f · ‖Δw‖

where L_f is the network's Lipschitz constant. For a capability C residing on torus T_k, the critical perturbation is:

> ε_crit(k) = sup{‖Δw‖ : T_k persists as invariant under w → w + Δw}

### Definition 5: KAM Breakdown as Residency Reclassification
When perturbation exceeds ε_crit, the invariant torus T_k is destroyed. The capability trajectory escapes through resonance gaps (Arnol'd diffusion) and is captured by a new torus T_{k'} at a different residency level, requiring reclassification [^2864^]. The transition is marked by:

- Loss of quasi-periodicity (Lyapunov exponent crosses zero: λ_max > 0)
- Crossing of a resonance surface ⟨ω, k⟩ = 0 for some integer vector k
- Transition from ordered to chaotic dynamics in the capability subspace

### Definition 6: Percolation-Critical Mass Threshold
For a capability network (graph of sub-capabilities and their entailments), define the occupation probability p as the fraction of active sub-capabilities. The critical mass threshold p_c satisfies:

> P_∞(p) = 0    for p < p_c
> P_∞(p) ∝ (p − p_c)^β    for p → p_c⁺

where P_∞ is the fraction of sub-capabilities belonging to the giant connected component (the "percolating capability cluster") [^2844^][^2841^].


## Tensions and Counter-Arguments

1. **KAM theorem requires conservative (Hamiltonian) dynamics, but gradient descent is dissipative**: This is a fundamental objection. Gradient descent on a loss landscape is a dissipative system that converges to attractors (fixed points or limit cycles), not conservative Hamiltonian flow on invariant tori. However, recent KAM theory for *conformally symplectic* (dissipative) systems shows that invariant tori persist as attractors if one adjusts a drift parameter [^2938^][^2941^]. The Residency Governor can be modeled as a dissipative KAM system with adjustable drift.

2. **Neural network weight space is high-dimensional and non-symplectic**: Standard KAM requires a symplectic structure (canonical coordinates p, q with dp ∧ dq preserved). Weight space has no natural symplectic form. Counter-argument: The NTK regime induces a kernel structure that creates an approximate metric on function space, and saddle-to-saddle dynamics reveal invariant manifolds of effectively reduced dimension [^2888^][^2901^].

3. **The "most irrational number" property of φ is measure-theoretic, not algorithmic**: While φ is optimal for Diophantine approximation in the worst case, almost all irrational numbers satisfy the Diophantine condition for some γ [^2915^]. The special status of φ may be an artifact of 2D area-preserving maps; in higher dimensions, the story is more complex. The practical relevance of φ over other badly approximable numbers for ML scheduling remains empirically unproven [^2871^].

4. **Emergent capabilities may be metric artifacts, not true phase transitions**: Schaeffer et al. (2023, cited in [^2892^]) argue that apparent phase transitions in LLM capabilities may be artifacts of discontinuous evaluation metrics. If true, the percolation analogy would apply to measurement, not to intrinsic capability structure. However, even if the metric is continuous, the underlying network may still exhibit true topological transitions in its weight space attractors [^2930^].

5. **Arnol'd diffusion is exponentially slow**: In KAM systems, diffusion across destroyed tori occurs on timescales ∼ exp(1/ε^a) [^2864^]. For practical ML systems with finite training time, this means capability drift may be negligible — capabilities appear stable on observable timescales even above the KAM threshold. This suggests the Residency Governor should track *finite-time* stability (Lyapunov exponents) rather than asymptotic KAM persistence.

6. **NTK lazy regime contradicts feature learning**: The invariant NTK structure applies only in the "lazy" regime where weights barely move; real neural networks exhibit "rich" regime feature learning where the kernel evolves [^2900^]. The KAM-capability mapping may only apply near convergence or in the NTK limit.


## Buildable Elements

1. **Diophantine Capability Validator**: A module that computes the "frequency vector" of a capability from its activation patterns across network layers, then verifies whether it satisfies the Diophantine condition |⟨ω, k⟩| ≥ γ/|k|^τ for a sliding window of integer vectors k. Capabilities with frequency ratios close to φ receive maximum stability scores.

2. **Lyapunov-based Residency Monitor**: Track the largest Lyapunov exponent λ_max of weight trajectories during fine-tuning. If λ_max crosses zero (indicating chaos), trigger residency reclassification. Implementation: use QR-decomposition on Jacobian products along training trajectories [^2862^][^2867^].

3. **Weight Displacement Threshold Alert**: Based on continual learning results showing ‖Δw‖ directly correlates with forgetting [^2866^], implement a hard threshold: if the Frobenius norm of weight updates exceeds φ · ‖w‖ / √N (where N is parameter count), flag the capability for residency reassessment.

4. **Percolation Capability Graph Analyzer**: Model capabilities as nodes in a graph with edges representing compositional entailment. Compute the giant connected component size as a function of active capability fraction p. When p crosses p_c (estimated via k-core decomposition), declare the capability cluster "critically emergent" [^2841^].

5. **Golden Ratio Scheduler**: Replace standard step decay with intervals T_n = T_0 · φ^n for evaluation, rehearsal, or consolidation phases. The rationale: φ-spaced intervals maximize avoidance of rational-period resonance with the loss landscape's natural frequencies [^2907^].

6. **Conformally Symplectic Drift Controller**: For the Residency Governor modeled as a dissipative KAM system, implement a drift parameter e that adjusts learning rate or regularization strength to maintain an approximate invariant torus for a capability of fixed "frequency" (functional signature) [^2938^][^2942^].


## Theoretical Foundations

### What is Proven
- **KAM theorem**: For sufficiently small perturbations ε < ε₀(γ, τ, n), Diophantine invariant tori persist in nearly integrable Hamiltonian systems [^2915^][^2906^].
- **Hurwitz's theorem**: φ has the largest possible Diophantine constant γ = 1/√5 among all irrationals [^2874^].
- **Golden torus is last to break**: In 2D area-preserving maps, the torus with golden mean winding number persists to the largest perturbation parameter before destruction [^2907^][^2908^].
- **KAM for HNNs with non-zero loss**: Quasi-periodic behaviors persist with high probability when training loss is bounded by O(R_n + √(ln(1/δ)/n)) [^2842^].
- **Conformally symplectic KAM**: Invariant tori persist as attractors in dissipative systems with adjusted drift parameters [^2941^][^2938^].
- **Percolation critical exponents**: The order parameter P_∞ scales as (p − p_c)^β with known exponents in various dimensions [^2844^].
- **Lyapunov spectrum and trainability**: The difference between maximum and minimum Lyapunov exponents bounds the condition number of gradient propagation [^2863^].

### What is Conjectured / Analogical
- **Capability tori exist in weight space**: No proof that learned capabilities correspond to invariant tori in neural network weight dynamics. This is an analogy, not a theorem.
- **Golden ratio scheduling is optimal**: No proven convergence advantage of φ-spaced schedules over other irrational intervals. The intuition from KAM (avoiding resonance) has not been transferred to SGD convergence proofs.
- **Arnol'd diffusion describes catastrophic forgetting**: While weight updates cause forgetting, the specific mechanism of crossing resonance gaps in a high-dimensional capability space is conjectural.
- **Percolation threshold equals emergent capability threshold**: The analogy between p_c in percolation and capability emergence in LLMs is heuristic; no rigorous mapping exists.
- **Residency Governor as conformally symplectic system**: Modeling the Governor as a dissipative KAM system with drift is a formal analogy, not a derived result.


## Answers to Specific Questions

### 1. Mathematical analogue of a "KAM torus" for a learned capability
A KAM torus for a learned capability is an invariant set in weight space (or function space) on which the network's functional behavior is quasi-periodic — it neither converges to a fixed point nor diverges chaotically, but explores a low-dimensional manifold with incommensurable frequencies. Formally, it is an embedding K: T^n → W satisfying Φ_t ∘ K(θ) = K(θ + ωt), where Φ_t is the training dynamics flow. In the NTK lazy regime, such invariant structures are approximated by the static kernel's eigensubspaces [^2901^]. For recurrent networks, trained periodic tasks correspond to limit cycles with λ_max = 0 [^2863^].

### 2. Golden ratio winding number as stability threshold
The golden ratio winding number maps to stability through the Diophantine condition. For a capability with characteristic frequency ratio ω, the critical perturbation scales as ε_crit ∝ γ(ω)^τ where γ(ω) is the Diophantine constant. Since φ achieves the maximal γ = 1/√5, a capability whose internal frequency structure is φ-structured can withstand the largest perturbations before resonant destabilization [^2874^][^2907^].

### 3. "Perturbation" in capability space
Perturbation is multi-modal:
- **Weight update magnitude**: ‖Δw‖_F directly perturbing the torus embedding [^2866^]
- **Distribution shift**: Change in data distribution alters the effective Hamiltonian [^2842^]
- **Counter-evidence**: Gradient updates from conflicting samples act as resonant forcing
- **Architecture change**: Adding layers or modifying width changes the phase space dimension
The Lipschitz bound on function-space perturbation provides a unified measure: ‖f_{w+Δw} − f_w‖ ≤ L_f‖Δw‖ [^2939^].

### 4. Diophantine condition for capabilities
A capability satisfies the Diophantine condition if its activation frequency vector ω (e.g., from FFT of layer-wise activations or from Jacobian eigenvalue angles) satisfies |⟨ω, k⟩| ≥ γ/|k|^τ for all integer vectors k ≠ 0. This means the capability's internal periodicities are incommensurable enough to avoid small denominators in perturbation expansions. Capabilities near rational frequency ratios (e.g., ω ≈ 1/2, 2/3) are "resonant" and unstable.

### 5. What happens at KAM breakdown
At breakdown, the invariant torus is destroyed and the trajectory can escape to other regions of phase space. For capabilities:
- The capability loses its coherent quasi-periodic structure
- Performance on the capability becomes chaotic or decays to a fixed point
- The capability may be "ejected" to a different residency level (new torus with different ω)
- In 2D maps, breakdown is preceded by the torus developing "crinkles" with universal scaling properties [^2907^]

### 6. Arnol'd diffusion and capability drift
Arnol'd diffusion provides the mechanism for capability drift across residency levels. Even when primary KAM tori are destroyed, secondary (whiskered) tori can form chains that allow trajectories to traverse resonance gaps [^2864^]. In capability terms: a capability may drift from L3 to L5 not by direct transition, but by a slow cascade through intermediate "ghost" tori, with the drift velocity scaling as exp(−c/ε^a) [^2864^].

### 7. "Last KAM torus" at φ
Yes, in 2D symplectic maps the golden mean torus is empirically and renormalization-theoretically the last to survive [^2907^][^2908^]. For the Residency Governor, this suggests that capabilities whose internal structure is most φ-like (maximally incommensurable, most hierarchically nested) will be the most robust to system perturbations. A "φ-core" capability would define the ultimate stability backbone of the system.

### 8. Golden-ratio-spaced scheduling from KAM stability
The derivation is analogical rather than rigorous. In KAM theory, perturbations at frequencies commensurable with the unperturbed motion cause resonance and destruction. Scheduling updates at intervals T, φT, φ²T, ... ensures the perturbation spectrum is maximally non-resonant with any natural period of the system. This is the same principle as the "most irrational" property protecting tori [^2869^]. However, no SGD convergence proof currently exploits this property.

### 9. KAM stability and the Resonance Model's critical mass threshold
The connection is through percolation theory. KAM tori persist as long as perturbations stay below threshold; similarly, a capability cluster percolates only when the occupation probability p exceeds p_c [^2844^]. The Diophantine condition (irrational frequency ratio) is analogous to the non-degeneracy condition in percolation (sufficient connectivity). At the critical mass threshold, the system undergoes a phase transition analogous to KAM breakdown: isolated capabilities suddenly become part of a giant connected component with emergent functionality [^2841^][^2889^]. The exponent β in percolation P_∞ ∝ (p − p_c)^β corresponds to the scaling of surviving torus measure near breakdown.


## References

[^2842^] Jin, P., Zhang, Z., Zhu, A., Tang, Y., & Karniadakis, G. E. Hamiltonian Neural Networks with Non-zero Training Loss. *Proceedings of the AAAI Conference on Artificial Intelligence*, 2022. https://cdn.aaai.org/ojs/20582/20582-13-24595-1-2-20220628.pdf

[^2846^] The Golden Ratio in Nature: A Tour across Length Scales. *Symmetry*, 14(10), 2059, 2022. https://www.mdpi.com/2073-8994/14/10/2059

[^2864^] Delshams, A., de la Llave, R., & Seara, T. M. Instability of high dimensional Hamiltonian systems: Multiple resonances and diffusion. *Advances in Mathematics*, 294, 2016. https://web.mat.upc.edu/tere.m-seara/articles/DelshamsLlS2016advmath.pdf

[^2862^] Shlizerman, E. On Lyapunov Exponents for RNNs. *arXiv:2006.14123*, 2020. https://arxiv.org/abs/2006.14123

[^2863^] Engelken, R., et al. Lyapunov spectra of chaotic recurrent neural networks. *Physical Review Research*, 2023. https://www.columbia.edu/cu/neurotheory/Larry/EngelkenPRR23.pdf

[^2866^] Aljundi, R., et al. Alleviating catastrophic forgetting in continual learning. *WSU Technical Report*. https://rex.libraries.wsu.edu/view/pdfCoverPage?instCode=01ALLIANCE_WSU&filePid=13368867260001842&download=true

[^2867^] Shlizerman, E., & Wang, B. On Lyapunov Exponents for RNNs: Understanding Information Propagation Using Dynamical Systems Tools. *Frontiers in Applied Mathematics and Statistics*, 8, 2022. https://www.frontiersin.org/journals/applied-mathematics-and-statistics/articles/10.3389/fams.2022.818799/full

[^2869^] Nolte, D. How Number Theory Protects You from the Chaos of the Cosmos. *Galileo Unbound*, 2019. https://galileo-unbound.blog/2019/10/14/how-number-theory-protects-you-from-the-chaos-of-the-cosmos/

[^2870^] Nolte, D. KAM Theory / The Most Irrational Number. *Galileo Unbound*, 2019. https://galileo-unbound.blog/tag/kam-theory/

[^2874^] Hurwitz's theorem (number theory). *Wikipedia*, 2009. https://en.wikipedia.org/wiki/Hurwitz%27s_theorem_(number_theory)

[^2873^] KAM theory as a limit of renormalization. *CEMAPRE Preprints*, 381. https://cemapre.iseg.ulisboa.pt/archive/preprints/381.pdf

[^2875^] Khanin, K., & Mazel, G. Renormalization of Hamiltonians for Diophantine frequency vectors. *Nonlinearity*, 2005. http://home.olemiss.edu/~skocic/kocic_renormalization-hamiltonians-diophantine_Nonlinearity2005.pdf

[^2877^] Niranjana. Diophantine Approximation and the Limits of Irrationality. *Euler Circle*, 2025. https://simonrs.com/eulercircle/irpw2025/niranjana-diop-paper.pdf

[^2888^] Saddle-to-Saddle Dynamics Explains A Simplicity Bias Across Neural Network Architectures. *arXiv:2512.20607*, 2025. https://arxiv.org/html/2512.20607v1

[^2889^] Emergent Capabilities in AI. *Practical DevSecOps*, 2026. https://www.practical-devsecops.com/glossary/emergent-capabilities/

[^2890^] Brenndoerfer, M. Emergence in Neural Networks: Phase Transitions & Scaling. 2025. https://mbrenndoerfer.com/writing/emergence-neural-networks-phase-transitions-scaling

[^2892^] Emergent LLM capabilities. *Psychometrics.ai*, 2026. https://psychometrics.ai/emergence

[^2900^] Understanding the Evolution of the Neural Tangent Kernel at the Edge of Stability. *arXiv:2507.12837*, 2025. https://arxiv.org/pdf/2507.12837

[^2901^] Neural Tangent Kernel (NTK) Regime. *Emergent Mind*, 2026. https://www.emergentmind.com/topics/neural-tangent-kernel-ntk-regime

[^2902^] Lu, A., et al. Rethinking the Stability-Plasticity Trade-off in Continual Learning from an Architectural Perspective. *arXiv:2506.03951*, 2025. https://arxiv.org/abs/2506.03951

[^2906^] Braaksma, A. Introduction to KAM theory. *MSc Thesis, Utrecht University*. https://studenttheses.uu.nl/bitstream/handle/20.500.12932/45058/Master_thesis.pdf

[^2907^] Meiss, J. D. Chapter 28: Hamiltonian Chaos: Theory. *Caltech Chaos Course*. https://www.its.caltech.edu/~mcc/Chaos_Course/Lesson28/KAM.pdf

[^2908^] Tobin, R. A Glance at the Standard Map. *UC Davis*, 2009. https://csc.ucdavis.edu/~chaos/courses/nlp/Projects2009/RyanTobin/StdMapPresentation.pdf

[^2910^] de la Llave, R., et al. KAM theory without action-angle variables. *Nonlinearity*. https://empslocal.ex.ac.uk/people/staff/mag208/publications/LlGJV-nl.pdf

[^2911^] de la Llave, R. KAM theory for some dissipative systems. *arXiv:2004.08503*, 2020. https://web.ma.utexas.edu/mp_arc/c/20/20-58.pdf

[^2914^] Lee, J., et al. Neural Tangent Kernel Analysis of Deep Narrow Neural Networks. *PMLR*, 162, 2022. https://proceedings.mlr.press/v162/lee22a/lee22a.pdf

[^2915^] Pöschel, J. A Lecture on the Classical KAM Theorem. *Harvard APM 203*, 2003. https://courses.seas.harvard.edu/climate/eli/Courses/APM203/2003fall/Poschel_ClassicalKAM.pdf

[^2930^] Yu, J., & Morozov, A. V. Neural network optimization strategies and the topography of the loss landscape. *arXiv:2602.21276*, 2026. https://arxiv.org/html/2602.21276v1

[^2938^] Calleja, R., Celletti, A., Gimeno, J., & de la Llave, R. KAM quasi-periodic tori for the dissipative spin-orbit problem. *Communications in Nonlinear Science and Numerical Simulation*, 106, 2022. https://par.nsf.gov/servlets/purl/10358773

[^2939^] ICML 2025 Poster: A Rescaling-Invariant Lipschitz Bound Based on Path-Metrics for Modern ReLU Network Parameterizations. https://icml.cc/virtual/2025/poster/45188

[^2941^] Calleja, R., Celletti, A., & de la Llave, R. Whiskered KAM Tori of Conformally Symplectic Systems. *arXiv:1901.06059*, 2019. https://arxiv.org/abs/1901.06059

[^2942^] Gimeno, J. Invariant KAM torus, breakdown, and estimates for the spin-orbit problem. *I-CELMECH*, 2020. http://www.mat.unimi.it/I-CELMECH/wp-content/uploads/2020/12/Gimeno-20201203.pdf

[^2943^] Calleja, R., Celletti, A., & de la Llave, R. Domains of analyticity of Lindstedt expansions of KAM tori in dissipative perturbations of Hamiltonian systems. *Journal of Differential Equations*, 2021. https://ddd.uab.cat/pub/prepub/2011/hdl_2072_200242/Pr1076.pdf

[^2945^] Training Transformers with Enforced Lipschitz Bounds. *arXiv:2507.13338*, 2025. https://arxiv.org/pdf/2507.13338

[^2840^] Critical Mass: Phase Transitions, Covert Coordination Detection... *OpenReview*, 2026. https://openreview.net/forum?id=en4p00TPW8

[^2841^] Percolation Thresholds and Complex Relational Responding. *Contextual Science*, 2025. https://contextualscience.org/blog/percolation_thresholds_complex_relational_responding_0

[^2844^] Stauffer, D., & Aharony, A. Percolation Theory. *MIT Course Notes*. https://www.mit.edu/~levitov/8.334/notes/percol_notes.pdf

[^2845^] Guckenheimer, J., & Holmes, P. Numerical Analysis of Dynamical Systems. *Cornell Mathematics*. https://pi.math.cornell.edu/~gucken/PDF/algorithms.pdf
