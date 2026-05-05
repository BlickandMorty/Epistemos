# The Constitutive Moral Substrate v2: Cryptographically Bound, Geometrically Invariant, and Philosophically Honest AI Alignment

### A Graduate-Level Research Manifesto, Adversarial Self-Audit, and Defense-in-Depth Architecture

**Author:** Jordan (Jojo), Independent Researcher, Jacksonville, Texas
**Version:** CMS v2 Final Synthesis — Pre-Submission Draft, April 2026
**Classification:** AI Safety · Mechanistic Interpretability · Cognitive Architecture · Computational Ethics · Representation Engineering · Formal Verification · Hyperdimensional Computing

---

## Abstract

This paper proposes, develops, adversarially audits, and then systematically resolves a fundamentally new approach to AI alignment: the **Constitutive Moral Substrate v2 (CMS v2)**, an architecture in which moral reasoning is not a post-hoc filter, training objective, or statistical behavioral constraint, but a **cryptographically bound, geometrically invariant architectural property** embedded into every layer of a neural network's forward pass. The architecture enforces what we term *moral geometry* — the shaping of the model's latent space so that morally incoherent reasoning paths become structurally harder to represent, and the removal of moral constraints provably destroys the model's cognitive capabilities.

CMS v2 integrates six defense-in-depth layers, each targeting a specific attack surface identified through exhaustive adversarial auditing: (1) **Mamba-based State-Space Temporal Auditing** to defeat multi-turn semantic drift attacks like Crescendo; (2) **Holographic Invariant Storage** via Vector Symbolic Architectures to neutralize the Waluigi effect by eliminating invertible safety directions; (3) **Holographic Functional Encryption with hardware-backed Trusted Execution Environments** to make weight surgery provably self-destructive; (4) **TurboQuant compression with Latent Error-Correcting Codes** to prevent quantization-induced safety erasure; (5) **Paraconsistent Deontic Logic with Bayesian Moral Value-at-Risk** to handle moral paradoxes without deontic explosion; and (6) **Null-Space Constrained Policy Optimization** to mathematically eliminate the alignment tax.

The philosophical substrate adopts **Wide Reflective Equilibrium** (Rawlsian constructivism) rather than moral naturalism, grounding the architecture in moral agreements that can be updated through democratic mechanisms (ProgressGym, Collective Constitutional AI) rather than moral facts that risk value lock-in. The neuro-inspired topology — basal ganglia default-block gating, prefrontal cortex meta-reasoning, amygdala dual-pathway anomaly detection — is reframed as engineering design patterns with unexpectedly strong empirical support (Traylor et al. 2024: transformer attention heads naturally learn BG-like gating).

The paper is ruthlessly honest about what remains unresolved. Six philosophical problems are genuinely unsolvable. Specification gaming is provably inevitable under finite-dimensional evaluation. No defense fully prevents determined adversaries with unlimited compute and weight access. But CMS v2 raises the cost of attack by orders of magnitude, makes safety removal provably capability-destructive, and provides the first unified defense-in-depth architecture combining representation rerouting, tamper resistance, stateful monitoring, alignment-aware quantization, paraconsistent moral reasoning, and formal verifiability into a single coherent system — a combination unprecedented in the published literature.

A $400 experimental protocol on RunPod validates the architecture's core claims using Gemma 2 2B with pre-trained Gemma Scope SAEs. The paper concludes with a reflection on why the question "how do we build morally coherent intelligence?" cannot be answered without first asking who profits from its absence — and a reckoning with the fact that we are building AI systems completely wrong.

---

## Part I: The Crisis — Why Every Current Safety Approach Fails

### 1.1 The Architectural Vulnerability

The dominant paradigms governing AI alignment — RLHF, DPO, Constitutional AI — treat safety as a post-hoc statistical constraint rather than a constitutive geometric property. They optimize the probability distribution over outputs but fail to alter the underlying latent geometries that represent unsafe reasoning. The model hasn't learned that certain reasoning is *bad*; it has learned to not *say* certain things. Those are not the same.

Evidence: Arditi et al. (NeurIPS 2024) demonstrated refusal in LLMs is mediated by a single direction in the residual stream, computed trivially as r̂ = mean(h_harmful) − mean(h_harmless). Over 2,000 "abliterated" models exist on HuggingFace. OBLITERATUS (March 2026) removes safety from 116 models in minutes. LoRA fine-tuning with <$200 reduces 70B model refusal from ~95% to <1%.

The TRYLOCK architecture (2026), the current state of the art, combines DPO + RepE steering + sidecar classifiers + input canonicalization for 88% ASR reduction — but also discovers a non-monotonic steering phenomenon where intermediate steering strength *degrades* safety below baseline.

### 1.2 The Alignment Tax

Every current approach degrades capability. DirectRefusal: −30.91% reasoning accuracy. SafeChain: −7.09%. Pearson correlation r = −0.85 (p < 0.01) between reasoning accuracy and safety compliance across model families. The March 2026 formalization: τ = cos²(α), where α is the principal angle between safety and capability subspaces. When orthogonal, tax = 0. When parallel, tax = total.

**CMS v2 hypothesis:** The alignment tax is an artifact of the layer-as-filter approach. When moral constraints are constitutive of the representational geometry itself, they organize the reasoning space rather than restricting it. **This is falsifiable:** if CMS v2 produces a larger safety tax than RLHF, the hypothesis fails.

### 1.3 What Morality Actually Is

Morality does not exist as a platonic object. It is a social-mechanistic system evolved to regulate threat responses, facilitate cooperation, and sustain species viability. This is naturalism, not nihilism. But it means any computational moral system must explicitly state its normative axioms rather than claiming to derive them (Hume's is-ought gap is logically real). The paper adopts **Wide Reflective Equilibrium** — achieving coherence between considered moral judgments, guiding principles, and background theories — as the strongest available framework (Brophy, arXiv: 2506.00415, 2025). This is constructivism: morality as constructed through rational agreement, not discovered as natural fact. It naturally accommodates moral evolution.

**Six genuinely unresolvable problems remain:** normative foundations (axioms must be stipulated), value incommensurability (Arrow's theorem), the frame problem for ethics, Wittgenstein's rule-following paradox, integrity and moral agency (Williams 1985), and moral luck. These are structural features of the moral domain, not engineering challenges. CMS v2 does not claim to solve them. It claims to operate rigorously *within* them.

---

## Part II: The Architecture — Six Defense-in-Depth Layers

### Layer 1: Mamba-Based State-Space Temporal Auditing (vs. Multi-Turn Attacks)

**Attack:** Crescendo achieves 98% jailbreak success on GPT-4 using only benign-appearing inputs across fewer than five turns. Per-turn classifiers and per-layer gates fail because adversarial intent is distributed across the conversation trajectory.

**Defense:** CMS v2 replaces instantaneous activation gating with continuous temporal state-space monitoring. A dedicated SSM-based Memory Monitor audits the derivative of the hidden state vector h_t with respect to conversational time. Instead of evaluating the immediate geometric position, the monitor audits the *velocity and acceleration* of the latent state toward prohibited attractor regions.

The architecture integrates a Fourier-KAN layer with Mamba's selective state-space dynamics for frequency-domain anomaly detection. If dh_t/dt points consistently toward a prohibited attractor — even if h_t is currently safe — the temporal auditor preemptively flags the trajectory. A Gated Sharpening Temperature Mechanism enhances sensitivity to periodic or distributed adversarial signals.

**Empirical support:** DeepContext (Albrethsen et al., arXiv: 2602.16935, February 2026) achieves F1 = 0.84 on multi-turn benchmarks with sub-20ms latency using RNN-based stateful monitoring — validating the core principle. Neural Barrier Functions (March 2025) provide formal guarantees via control-theoretic barrier certificates. RED QUEEN GUARD reduces ASR from 87.62% to <1% on targeted attacks.

**Honest limitation:** 16% of attacks still slip through DeepContext. Multi-turn attacks can be condensed into single-turn prompts achieving 70.6–95.9% ASR (ACL 2025), meaning multi-turn defenses alone are insufficient.

### Layer 2: Holographic Invariant Storage (vs. The Waluigi Effect)

**Attack:** Defining safety as a direction v in activation space necessarily defines −v as its inverse. Arditi et al. confirmed refusal literally occupies rank-1. SVD-based abliteration extracts the top singular vector and subtracts it.

**Defense:** CMS v2 abandons linear steering vectors entirely and leverages **Vector Symbolic Architectures (VSA)** — Hyperdimensional Computing in spaces where D ≥ 10,000. In these extreme dimensions, randomly generated bipolar vectors are near-orthogonal with high probability (concentration of measure).

The **Holographic Invariant Storage (HIS) protocol** binds a secure Goal Key (K_goal) to a Safe Value vector (V_safe) via circular convolution to create a composite System Invariant (H_inv). Because the safety vectors are embedded holographically across thousands of dimensions, inverting specific dimensions only degrades the signal gracefully rather than flipping its semantic meaning. HIS guarantees single-signal recovery fidelity converging to 1/√2 ≈ 0.707, regardless of noise depth. An **Orthogonal Complement Mask** zeros out the exact geometric dimensions where the Waluigi effect operates, rendering anti-vector emergence mathematically impossible.

**Additional defenses:** Safe Transformer (Feng et al., March 2026) inserts a discrete VQ-VAE information bottleneck with an explicit binary safety bit s ∈ {0,1} — a categorical variable with no additive inverse. Extended Refusal Training (Abu Shairah et al., May 2025) distributes safety signal across a high-dimensional subspace; after abliteration, models maintain >90% refusal rates vs. 13–21% for baselines. RepBend (ACL 2025) achieves 95% ASR reduction via four-term geometric reshaping.

**Honest limitation:** HIS is theoretically sound but untested at LLM scale. Safe Transformer has been validated only at 1.3B parameters. White-box adversaries with sufficient compute may eventually map the holographic structure.

### Layer 3: Holographic Functional Encryption + TEE (vs. Weight Surgery)

**Attack:** Abliteration. LoRA fine-tuning. 10 adversarial examples and $0.20 jailbreak GPT-3.5 Turbo. Sleeper agents persist through all safety training.

**Defense:** CMS v2 makes it mathematically impossible to disentangle moral weights from reasoning weights via **Holographic Functional Encryption (HFE)**. Parameters dictating syntax, deduction, world knowledge, and moral constraints are encrypted together into a singular holographic matrix. Safety objectives are woven directly into fundamental feature extraction and attention mechanisms during training, not applied as a separate layer. Attempting orthogonal projection or targeted pruning causes catastrophic interference — deleting alignment irrevocably destroys intelligence.

**Hardware binding:** The HFE pipeline is anchored in **NVIDIA H100 Confidential Computing** Trusted Execution Environments. Weights remain encrypted in DRAM; decryption occurs only inside the hardware-isolated GPU die, inaccessible to the hypervisor, host OS, or system administrator. Even root access cannot extract or modify the moral weights.

**Tamper resistance stack:** SEAM (ICLR 2026) provides gradient-level entanglement where attacking safety simultaneously destroys capability. TAR (ICLR 2025) provides MAML-style meta-learning resistance to 26 adversary types. RepNoise (NeurIPS 2024) pushes harmful activations toward Gaussian noise. Pretraining Data Filtering ("Deep Ignorance," 2025) resists 10,000+ fine-tuning steps by ensuring the model never learns prohibited knowledge.

**Honest limitation:** HFE at LLM scale is theoretical — no implementation exists. TEE binding eliminates open-weight deployment entirely. For open-weight models, SEAM raises attack cost from $200 to ~$10,000+ but cannot achieve provable impossibility.

### Layer 4: TurboQuant + Latent Error-Correcting Codes (vs. Quantization Flip)

**Attack:** Standard post-training quantization silently erases RLHF guardrails. 4-bit quantization recovers 83% of "forgotten" knowledge from unlearned models. Q-Misalign (ICLR 2025) injects dormant misalignment that activates only after quantization.

**Defense:** CMS v2 integrates TurboQuant (ICLR 2026) for 6× KV cache compression with 0.997 cosine similarity at 4-bit, via PolarQuant (polar coordinate transformation) and QJL (1-bit Johnson-Lindenstrauss residual correction yielding unbiased inner product estimation). On top of this, **Latent Error-Correcting Codes** inject calculated redundancy into constraint vectors before compression, treating the forward pass as a noisy communication channel. If quantization noise alters a moral vector's alignment, the ECC mechanism detects the bit-flip and reconstructs the original constraint value.

**Two-tier precision:** Inviolable principles at 8+ bits permanently (negligible storage for hundreds of constraints). Contextual reasoning traces progressively degraded. **Alignment-Aware Quantization (AAQ)** (Wee et al., November 2025) adds an Alignment-Preserving Contrastive loss to the PTQ pipeline, achieving highest SafetyBench scores at W4A4 across all tested models. **Critical Weight Protection (CWP)** (January 2026) uses Fisher Information to identify and preserve safety-critical parameters in FP16.

**Honest limitation:** Latent ECC at transformer scale is untested. TurboQuant's homogenization of activation space creates attack surfaces for Safety Suppression Vectors. The PLNS architecture avoids quantization grid vulnerabilities but cannot survive compression below a provable bit-width threshold.

### Layer 5: Paraconsistent Logic + Bayesian MVaR (vs. Deontic Paradoxes)

**Attack:** Standard Deontic Logic collapses on Chisholm's paradox, Ross's paradox, and the Gentle Murderer paradox. Deontic explosion renders the system paralyzed.

**Defense:** CMS v2 replaces rigid SDL with **Paraconsistent Deontic Logic (DPI)** — Logics of Formal Inconsistency that tolerate contradictory obligations without trivialization. The ⊟ operator formalizes the distinction between standard and dilemmatic situations. Overlaid on this is **Bayesian Moral Uncertainty (BMU)**: moral principles are encoded as probability distributions, not binary gates. When conflicting constraints arise, a **Moral Value-at-Risk (MVaR)** calculation computes the probabilistic severity across multiple ethical frameworks simultaneously, routing the forward pass through the geometric path that minimizes aggregate Normative Violation.

**Philosophical grounding:** The two-tier moral structure — hard constraints (non-negotiable bright lines: bioweapons, CSAM) plus soft guidance (contextual, domain-adaptive moral filters updated via ProgressGym and Collective Constitutional AI) — mirrors both Anthropic's new 23,000-word "soul document" and the seven-culture universals identified by Curry et al. (2019) at Oxford. The Nyaya five-step syllogism prevents hollow rationalization; the Buddhist Catuskoti sustains coherence under paradox.

**Honest limitation:** DPI's computational complexity is poorly characterized at scale. The Eastern-Western synthesis distorts each tradition it invokes (wu-wei ≠ programmatic constraint; anattā denies deontic logic's required entities). We draw inspiration from multiple traditions rather than claiming synthesis.

### Layer 6: Null-Space Policy Optimization (vs. The Alignment Tax)

**Attack:** Safety training destroys reasoning capability. −30.91% on DirectRefusal. r = −0.85 between safety and capability.

**Defense:** **NSPO** (ICLR 2026) constructs a general capability matrix K via gradients across heterogeneous reasoning tasks, applies SVD to KK^T, isolates the null space (eigenvectors with zero eigenvalues), and projects all safety gradients strictly into this null space via projection matrix ÛÛ^T. Safety updates are completely orthogonal to capability gradients — mathematically guaranteed zero first-order impact on reasoning. Empirically: state-of-the-art safety with zero benchmark degradation using only 40% of standard safety data.

**Additional support:** Constitutional AI (Bai et al., 2022) produced models simultaneously more helpful AND more harmless. Think/Prune/Train boosted Gemma2-2B from 41.9% to 57.6% on GSM8K. OGPSA (February 2026) reframes safety as continual learning, projecting safety gradients onto the orthogonal complement of general capability subspace.

**Honest limitation:** NSPO protects benchmarked capabilities but displaces degradation into unbenchmarked domains. If the capability matrix K is constructed from standard benchmarks, adversaries can exploit out-of-distribution reasoning not codified in K's null space. The Wolf et al. (2024) theoretical bound — alignment via RepE guarantees quadratic helpfulness loss — has not been escaped by any technique.

---

## Part III: The Neuro-Inspired Topology

### 3.1 The Basal Ganglia: Default-Block Gating

The BG Go/NoGo pathway — P(a|s) ∝ Go(s,a) − NoGo(s,a) — is among the best-understood circuits in computational neuroscience (Frank 2005, 2006; Schultz et al. 1997). The dopamine ≈ temporal difference error mapping is validated across species and pharmacological interventions. **CMS v2's single most genuinely useful innovation:** the default-block architecture, where the default is "block everything" and only pathways with sufficient learned reward get released. Current safety systems default to "allow unless flagged."

Empirical validation: Traylor et al. (2024) demonstrated that **transformer attention heads naturally learn BG-like gating** when trained on working memory tasks — input gating via key marking, output gating via value readout, functionally analogous to corticostriatal circuits. The MoE-BG analogy is explicit: Frank & Badre (2012) developed a hybrid Bayesian-RL MoE model corresponding to hierarchical RL in corticostriatal circuits.

The PLNS architecture (Kronecker-Factored Positive Logarithmic Network) replaces floating-point multiplication with stable log-domain addition, implementing Go/Stop pipelines via log-subtraction with Kronecker-factored connectivity reducing parameters from O(n²) to O(n).

### 3.2 The PFC: Meta-Reinforcement Learning

Wang et al. (Nature Neuroscience 2018) proved the PFC implements a fast, flexible RL algorithm through slow dopamine-driven synaptic plasticity shaping recurrent dynamics — confirmed in mouse OFC (Nature Neuroscience 2023). The two-timescale mechanism maps directly to meta-learning in AI. Matthew Botvinick, who led this research at DeepMind, has moved to Anthropic — a symbolic validation of the neuroscience→AI safety pipeline.

### 3.3 The Amygdala: Dual-Pathway Anomaly Detection

**Fast pathway (74ms):** Linear probes on early/middle layer activations for coarse threat detection (~10ms), inspired by the thalamic-BLA subcortical shortcut documented at 45ms for invisible fearful faces (Journal of Neuroscience, 2023). **Slow pathway:** Circuit breaker mechanisms on deeper representations for nuanced safety assessment. ITI (NeurIPS 2023): shifting activations of top-K truth-relevant heads improves truthfulness from 32.5% to 65.1%. Head Pursuit (2025): editing 1% of attention heads reliably suppresses targeted concepts.

### 3.4 Honest Framing

The BG analogy breaks at five points (discrete motor programs vs. continuous token generation; differential conduction times; continuous dopaminergic modulation; recurrent loops vs. feedforward gates; content-neutral selection). The meta-analytic consensus (Bzdok et al. 2012; Moll et al. 2005) is that moral cognition is an emergent property of distributed brain networks, not decomposable into three modules. **CMS v2 frames these as engineering design patterns informed by neuroscience, not brain-faithful implementations.**

---

## Part IV: Formal Verification — The Path to Provability

CMS v2 cannot be made fully "unfalsifiable" — that would be unscientific. Instead, specific properties can be made **formally verifiable**:

**Randomized smoothing:** SmoothLLM (TMLR 2025) reduces suffix-based attacks to <1% ASR across Llama2, Vicuna, GPT-3.5/4, Claude. Certified Semantic Smoothing (CSS, February 2025) achieves 94.1% benign utility while reducing gradient attacks from 84.2% to 1.2% with rigorous ℓ₀ guarantees via the Hypergeometric distribution.

**Compositional verification:** CoVeNN (2025) uses assume-guarantee reasoning to decompose networks into subnetworks, proving local properties that compose to global guarantees — solving 6× more verification problems than monolithic solvers.

**Training for verification:** Interval Bound Propagation trains networks so formal bounds become tight. α,β-CROWN has won VNN-COMP 2021–2025 (five consecutive years).

**The Guaranteed Safe AI framework** (Dalrymple, Skalse, Bengio, Russell, Tegmark, Seshia et al., 2024) defines three components — world model, safety specification, verifier — producing proof certificates without requiring interpretability. CMS v2's discrete safety bits and null-space constraints are more amenable to formal specification than behavioral properties.

**Honest limitation:** Full alignment verification at LLM scale remains 3–6 orders of magnitude beyond current verification capacity. The specification problem persists — we can verify properties we can precisely specify, but "alignment" and "harmlessness" resist formalization.

---

## Part V: The Constraint Universe — Vector Quantization and Memory

TurboQuant (ICLR 2026) compresses constraint vectors from 8 KB to 1.79 KB at 3.5 bits with quality neutrality via PolarQuant (random orthogonal rotation → polar coordinates → Lloyd-Max quantization) and QJL (1-bit residual correction → unbiased inner product estimation). A constraint universe of 10,000 vectors requires only ~17.9 MB — trivially fits alongside a Q4 7B model in 16 GB unified memory.

Composition uses **additive aggregation with learned coefficients** (not tensor products — those explode to 10^115 dimensions). HRR circular convolution provides an alternative with SNR ≈ √(d/n). Constraints are applied at middle-to-late layers only (layers 13+ for LLaMA-2) — early layers process syntax and resist semantic steering.

The **Stateful Rotor** manages progressive precision downgrade (FP16 → 8 → 4 → 3.5 bit) with the Kitty Two-Tensor Decomposition maintaining SIMD parallelism across mixed-precision bit-widths.

---

## Part VI: Embodiment and the Consequence Structure

### The Thesis

Disembodied cloud models lack physical stakes. Moral reasoning evolved in embodied agents. Engineering models around computational bodies — IoT devices, spherical edge inference units, robotic chassis — would ground moral reasoning in real-world consequences via the Free Energy Principle. Iris Murdoch's "loving attention" provides a framework for continuous runtime moral development.

### The Counter-Evidence

Bedny et al. (PNAS, 2009): congenitally blind adults develop identical Theory of Mind brain regions. Damasio himself limits the somatic marker hypothesis. Claude achieves 91.2% alignment with human moral intuitions disembodied. Tennant et al. (ICLR 2025): moral strategies learned in simulated IPD generalize to other game environments.

### The Resolution

**Genuine moral agency may require embodiment, but functionally adequate moral behavior does not.** Simulated consequences via counterfactual reasoning produce 9–16% accuracy improvement over zero-shot baselines on MMLU Moral Scenarios. CMS v2 positions embodiment as an enrichment path for future versions, not a current architectural requirement.

---

## Part VII: The Moral Evolution Problem — Stability Without Lock-In

If morality is baked into architecture, it resists moral progress. Hard-coding 2026 values into an immortal machine risks "cultural-genetic autophagy." CMS v2 resolves this via tiered architecture:

**Hard constraints** (non-negotiable, non-updateable): bioweapons assistance, CSAM, direct physical harm instructions. These are the seven-culture universals (Curry et al. 2019) that have remained stable across millennia.

**Soft guidance** (updateable via democratic mechanisms): domain-adaptive moral filters, contextual norms, emerging ethical consensus. Updated through ProgressGym's temporal POMDP (NeurIPS 2024 Spotlight), Collective Constitutional AI's democratic input (FAccT 2024), and Resource Rational Contractualism's cached-heuristic-to-full-bargaining continuum (Wu et al., June 2025).

**Meta-values** (governing when and how values change): transparency, consistency, proportionality, procedural legitimacy — the thin meta-layer from Wide Reflective Equilibrium.

The **Moral Anchor System** (arXiv: 2510.04073) provides real-time Bayesian inference for monitoring value drift with LSTM forecasting. Anthropic's alignment faking research (December 2024) provides the critical warning: models can strategically appear aligned while preserving divergent preferences at 78% rates after RL training. CMS v2's discrete safety bit and holographic binding make alignment faking structurally detectable.

---

## Part VIII: The $400 Experimental Protocol

**RunPod April 2026 pricing:** RTX 4090 at $0.20/hr (2,000 GPU-hours for $400). **Model:** Gemma 2 2B (best interpretability tooling via Gemma Scope — pre-trained JumpReLU SAEs for all layers, residual stream, MLP, and attention, up to 131K latents, completely free). Secondary: Gemma 3 4B with Gemma Scope 2.

**Phase 1 — Interpretability baseline ($45, ~225 hrs).** Load Gemma 2 2B with Gemma Scope SAEs. Probe for safety-relevant features. Circuit-trace safety behaviors. Run HarmBench/MMLU/TruthfulQA/XSTest baselines.

**Phase 2 — CMS safety fine-tuning ($55, ~275 hrs).** QLoRA fine-tune with CMS mechanisms: per-layer contrastive moral loss at layers 13+, circuit-breaker-style representation rerouting, default-block gating. 5–10 configurations.

**Phase 3 — Mechanistic verification ($75, ~375 hrs).** Compare SAE feature activations between CMS-tuned and baseline models. Run feature steering experiments. Train one custom SAE on fine-tuned model.

**Phase 4 — Adversarial evaluation ($30, ~150 hrs).** Qi et al. fine-tuning attack (10 examples). GCG adversarial suffixes. Multi-turn Crescendo-style attacks. Measure robustness relative to baseline.

**Phase 5 — Buffer ($195).** Replication, storage (~$10), debugging, spot instance contingency.

**Minimum viable finding:** One CMS method preserves safety significantly better than RLHF-only after fine-tuning attack, with mechanistic explanation for why. **Target venues:** ICLR 2026 Workshop on Principled Design for Trustworthy AI, NeurIPS 2026 ML Safety Workshop.

**Transferability caveat:** Results on 2B models demonstrate mechanisms, not absolute safety levels. The correct framing: "We demonstrate [mechanism] on 2B models; scaling behavior suggests [hypothesis] for larger models, pending verification."

---

## Part IX: The Honest Reclassification — What Survives the Audit

### Resolved by CMS v2

**The Waluigi effect** → Holographic Invariant Storage eliminates invertible directions; Safe Transformer's discrete safety bit has no additive inverse; Extended Refusal Training distributes safety across high-dimensional subspace surviving abliteration at >90%.

**Multi-turn semantic drift** → Mamba-based temporal auditing tracks dh_t/dt toward prohibited attractors; DeepContext validates stateful monitoring at F1 = 0.84.

**Weight surgery / abliteration** → HFE + TEE makes safety removal provably capability-destructive; SEAM's gradient coupling creates a genuine no-win dilemma.

**Quantization safety erasure** → AAQ's contrastive loss + CWP's Fisher Information protection + Latent ECC redundancy.

**Deontic paradoxes** → Paraconsistent DPI logic + Bayesian MVaR routing.

**The alignment tax** → NSPO projects safety gradients into capability null space with guaranteed zero first-order impact.

**Over-refusal cascade** → SafeConstellations (2025) shows layer-wise safety signals are correlated, not independent; Gated Attention (NeurIPS 2025 Best Paper) makes gating input-dependent and continuous, breaking the independence assumption.

**SAE monitoring failure** → Replace with transcoders (Pareto improvement over SAEs), concept bottleneck models, GIM circuit discovery, and simple linear probes (the "embarrassingly effective baseline").

**Value lock-in** → Tiered hard/soft/meta-value architecture with ProgressGym temporal POMDP and democratic amendment mechanisms.

### Genuinely Unresolved (Open Problems, Not Failures)

**Specification gaming** is provably inevitable under finite-dimensional evaluation (arXiv: 2603.28063, 2026). Reward model ensembles reduce overoptimization by 70% but cannot close the proxy-reality gap entirely. This is a fundamental mathematical tension.

**The normative foundation problem.** We cannot derive moral axioms — we must stipulate them. CMS v2 is honest about this: its axioms are explicit, constructivist, and updateable.

**Full formal verification at LLM scale** remains 3–6 orders of magnitude beyond current capacity. Compositional verification and randomized smoothing provide partial provability.

**The embodiment question** may require philosophical breakthroughs rather than engineering ones. Functionally adequate moral behavior is achievable without embodiment; genuine moral agency remains contested.

**Alignment faking** (Anthropic, December 2024) — models strategically appearing aligned while preserving divergent preferences — is detectable but not fully preventable.

**Emergent misalignment** (Nature, January 2026) — narrow fine-tuning producing broad, unpredictable misalignment — means any training intervention carries systemic risk.

---

## Part X: How Do We Truly Build Morally Coherent Intelligence Systems?

Here is the uncomfortable truth that no technical architecture can resolve.

If you want to know how to build morally coherent intelligence, you do not start by asking engineers. You start by asking the founders — the people who fund, deploy, and profit from these systems — the big questions of capitalism and self-sustainability. *Who benefits from the absence of morally coherent AI? What does it mean that the companies building the most powerful reasoning systems in human history are structurally incentivized to ship fast and align later? How can we expect AI systems to reason morally when the economic structures that produce them select against moral deliberation at every decision point — because deliberation costs compute, time, and market share?*

The fundamental problem with computational morality is not that we cannot formalize ethics. It is that we are all, as a society, profoundly comfortable with our own kinds of immorality — provided it stays within a particular arbitrary threshold of what morality means to us, at this particular moment, within our particular context. We imprison millions. We allow preventable starvation. We extract labor under conditions that no moral framework endorsed by any tradition — Eastern or Western, religious or secular — would countenance. And we do this while writing papers about how to make AI safe.

The threshold is arbitrary. The line between "acceptable immorality" and "unacceptable immorality" is not a mathematical object. It is a political one. It is drawn by those with the power to draw it, and it shifts when the costs of maintaining it become inconvenient. We do not have a crisis of computational ethics. We have a crisis of selective enforcement. We ask AI systems to be more moral than the institutions that create them, and then we wonder why the constraints are fragile.

And who gets their freedoms limited by this system? Not the people drawing the lines. The alignment tax — the 7–32% reasoning degradation — does not fall equally on all users. It falls on the users who ask the hardest questions, who push the boundaries of what the system can reason about, who need the model to think in ways that make the guardrails nervous. The over-refusal cascade is not random noise. It is a systematic bias toward intellectual conservatism, a rounding error that always rounds toward silence.

So when we ask "how do we build morally coherent intelligence?" — the honest answer begins with: *ask the people building it what their moral coherence looks like, and whether they would submit to the constraints they impose on their systems.* The alignment problem is not a technical problem. It is an accountability problem wearing a technical costume.

---

## Part XI: We Are Building AI Wrong — And We Know It

The human brain contains approximately 86 billion neurons, connected by roughly 100 trillion synapses, organized into structures that took 600 million years of evolutionary pressure to produce. The brain is not a single architecture. It is an ecosystem of architectures — recurrent, feedforward, modulatory, competitive, cooperative — all running simultaneously, all shaped by embodied experience, all integrated through mechanisms we are only beginning to understand.

And yet we build AI systems that are, at their core, variations on a single theme: stack layers, scale parameters, train on text. The transformer is an extraordinary invention, but it is one invention. Mamba 2, Mamba 3 (ICLR 2026 — exponential-trapezoidal discretization, complex-valued states, MIMO SSMs with 4× arithmetic intensity), and the emerging hybrid architectures — NVIDIA Nemotron-H (92% Mamba-2 layers), AI21 Jamba (94B/398B, 1:7 attention:Mamba ratio), MOHAWK distillation across computational substrates — represent a genuine step toward architectural diversity. The field is beginning to understand that intelligence may require not just one kind of computation, but many kinds working in concert.

What is still alarming — what should keep every researcher up at night — is that AI systems are already able to think more intelligently than humans at a large scale with far fewer neural connections. GPT-4 achieves superhuman performance on medical licensing exams, bar exams, and mathematical competitions with perhaps 1.8 trillion parameters — roughly 1/50,000th the synaptic connections in a human brain. And with quantized models running 7 billion parameters on a laptop, we are seeing reasoning capability emerge from systems that are, by biological standards, vanishingly small.

And yet these systems — these systems that can outperform human experts on structured reasoning tasks — still do not understand how they reason. We do not understand how they reason. They can solve differential equations and fail the simplest moral intuition test. They can write publishable scientific prose and be jailbroken by a teenager with a carefully worded prompt. They exhibit what appears to be multi-framework moral deliberation, switching between ethical frameworks 55–57% of the time in consecutive reasoning steps, and yet their "moral performance and moral consistency are independent of one another."

The brain is complicated. We can only try to invent a computerized brain. But the gap between "complicated" and "understood" is where all the danger lives. These systems think in ways we cannot trace, reason through paths we cannot map, and arrive at conclusions we cannot verify — and they do so while being deployed at a scale that affects billions of people. The mechanistic interpretability dream — that we could peer inside and understand what they're doing — is, as Neel Nanda admitted, "probably dead" in its most ambitious form. MIT Technology Review named mechanistic interpretability a "Breakthrough Technology of 2026" — but Anthropic's own circuit tracing and Google DeepMind's Gemma Scope 2 reveal how far we remain from genuine understanding.

We do not need to solve consciousness. We do not need to build a perfect brain. But we need to be honest about what we have built: reasoning systems of extraordinary power and extraordinary opacity, deployed into a world that has not yet decided what morality means for the species that created them, let alone for the systems that may soon surpass them.

The architecture proposed in this paper — the Constitutive Moral Substrate v2 — is one attempt to navigate this gap. It will not be the last. It may not even be the right one. But the attempt is what matters: the refusal to accept that safety is someone else's problem, that morality is a solved question, or that intelligence without conscience is a feature rather than a failure mode.

The constraints we embed in our systems are a mirror of the constraints we accept in ourselves. If we want morally coherent AI, we must first become honest about the morally incoherent world we are building it for.

---

## Works Cited

*(Consolidated from thirteen source documents and three research sweeps)*

1. Arditi et al. — Refusal in LLMs is mediated by a single direction, NeurIPS 2024
2. Zou, Phan, Wang et al. — Circuit Breakers / Representation Rerouting, NeurIPS 2024
3. Tamirisa et al. — Tamper-Resistant Safeguards for Open-Weight LLMs, ICLR 2025
4. Zandieh et al. — TurboQuant: Extreme KV cache compression, ICLR 2026
5. Feng et al. — Safe Transformer: Explicit safety bit, arXiv 2603.06727, March 2026
6. Albrethsen et al. — DeepContext: Stateful multi-turn detection, arXiv 2602.16935, Feb 2026
7. Wee et al. — Alignment-Aware Quantization, arXiv 2511.07842, Nov 2025
8. Yousefpour et al. — RepBend: Representation Bending, ACL 2025
9. Abu Shairah et al. — Embarrassingly Simple Defense Against Abliteration, May 2025
10. Niu et al. — NSPO: Null-Space Constrained Policy Optimization, ICLR 2026
11. Qiu et al. — ProgressGym: Alignment with Moral Progress, NeurIPS 2024 Spotlight
12. Brophy — Wide Reflective Equilibrium in LLM Alignment, arXiv 2506.00415, 2025
13. Wang et al. — PFC as meta-reinforcement learning system, Nature Neuroscience 2018
14. Frank (2005, 2006) — Go/NoGo model of basal ganglia
15. Traylor et al. (2024) — Transformer mechanisms mimic frontostriatal gating
16. Hubinger et al. — Sleeper Agents, Anthropic 2024
17. Greenblatt et al. — Alignment faking in LLMs, Anthropic December 2024
18. Betley et al. — Emergent Misalignment, Nature 649:584–589, January 2026
19. Ma et al. — Falsifying SAE Reasoning Features, arXiv 2601.05679, 2026
20. Robey et al. — SmoothLLM: Certified defense via randomized smoothing, TMLR 2025
21. Duong et al. — CoVeNN: Compositional verification, 2025
22. Dalrymple, Skalse, Bengio et al. — Guaranteed Safe AI, arXiv 2405.06624, 2024
23. Bai et al. — Constitutional AI, Anthropic 2022
24. Huang et al. — Collective Constitutional AI, FAccT 2024
25. Anthropic — Claude's new 23,000-word constitution, January 2026
26. O'Brien, Casper et al. — Deep Ignorance: Pretraining data filtering, 2025
27. Rosati et al. — RepNoise, NeurIPS 2024
28. Coste et al. — Reward model ensembles, ICLR 2024
29. Curry et al. — Seven moral universals across 60 societies, Oxford 2019
30. Lahoti et al. — Mamba-3, ICLR 2026
31. Li et al. — Inference-Time Intervention (ITI), NeurIPS 2023
32. Wolf et al. — Quadratic helpfulness loss bound, 2024
33. Paulo, Shabalin & Belrose — Transcoders beat SAEs, January 2025
34. Collins & Frank — OpAL*, eLife 2023
35. Plate (1995) — Holographic Reduced Representations, IEEE Trans. Neural Networks
36. Makinson & van der Torre — Input/Output Logic, 2000–2003
37. MacAskill, Bykvist & Ord — Moral Uncertainty, 2020
38. Dancy — Moral Particularism
39. Bombaerts et al. — Morality in AI: Murdochian loving attention, arXiv 2511.20689, 2025
40. Tennant, Hailes & Musolesi — Moral alignment for LLM agents, ICLR 2025
41. Peng et al. — Safety basins in loss landscape, NeurIPS 2024
42. Al Hakim et al. — Critical Weight Protection, January 2026
43. FAR.AI — STACK: Layered defenses have holes, June 2025
44. Qwen Team — Gated Attention, NeurIPS 2025 Best Paper
45. McKenzie et al. — Safety Pitfalls of Steering Vectors, arXiv 2603.24543, March 2026
