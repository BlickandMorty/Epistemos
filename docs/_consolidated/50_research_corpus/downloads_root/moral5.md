# Architecturally Constitutive Moral Reasoning in AI Systems
### A Graduate-Level Research Framework for Baking Ethics into the Training Pipeline Through Per-Layer Vector Quantization, Neuro-Inspired Action Gating, and Embodied Consequence Structures

***

## Executive Summary

Current AI safety research treats morality as a post-hoc filter — a preference classifier, a constitutional critique loop, or an RLHF reward signal applied after the model has already learned to reason. This paper argues that approach is fundamentally insufficient, and proposes a new architectural paradigm: **Architecturally Constitutive Moral Reasoning (ACMR)**, in which moral inference becomes a structural property of how the model computes, not a policy imposed upon it.

The framework draws from three domains simultaneously: (1) **mechanistic interpretability** and representation engineering — the mathematics of steering vectors and per-layer activation manipulation; (2) **computational neuroscience** — the basal ganglia's disinhibition model, the vmPFC's meta-representation of safety, and the amygdala's salience/threat detection; and (3) **vector quantization theory** — particularly TurboQuant-style constraint trace compression and KVTuner-style per-layer precision allocation. These are not analogies. They are proposed as a literal implementation blueprint.

The central claim: moral constraints that are encoded in the learned rotation basis of every transformer layer — compressed with TurboQuant-style Lloyd-Max scalar quantizers, composed across layers via tensor product, and gated by a basal ganglia-inspired disinhibition circuit — cannot be fine-tuned away, because they are constitutive of the model's representational geometry. Aligning the model's geometry is qualitatively different from aligning its outputs.

This research also introduces a critical philosophical critique: **we do not yet have an honest account of what morality is**, and any computational implementation built on a dishonest foundation will fail. The paper therefore proposes a naturalistic, harm-indexed, species-preservation-grounded definition of morality as the computational substrate, augmented by formal deontic temporal logic and adaptive per-domain moral filters.

Finally, the paper introduces an **embodied AI thesis**: disembodied cloud models cannot achieve genuine moral reasoning because they have no consequence structure. Real moral agency requires physical stakes. The direction for future AI architecture should be toward computational bodies — embedded devices, IoT agents, spherical edge inference units — where moral reasoning re-emerges as an adaptive survival function, as it did in biological agents.

***

## Part I: The Problem with Morality as Filter

### 1.1 Why Bolted-On Alignment Fails

The dominant approach to AI alignment treats safety as a capability added after training. Reinforcement Learning from Human Feedback (RLHF), Constitutional AI, and DPO all operate by shaping the probability distribution over outputs — they adjust what the model says, not what the model is. This distinction matters enormously for adversarial robustness.

A model fine-tuned with safety labels still contains, in its weight matrices, the full learned geometry of unsafe reasoning. Safety training merely suppresses certain output pathways without removing the underlying representations. This is precisely why jailbreaks work: adversarial prompts activate the original unsafe reasoning geometry, routing around the safety-finetuned distribution. The model hasn't learned that certain reasoning is bad; it has learned to not say certain things. Those are not the same.

Anthropic's Constitutional AI (CAI) uses a list of principles and a self-critique loop during training, which is a meaningful step forward. But even CAI operates at the output level — the model critiques and revises its own responses, which presupposes that moral reasoning is a post-hoc review process rather than intrinsic to the forward pass itself. Constitutional Classifiers (2025) demonstrated robust defense in over 3,000 hours of red-teaming with no universal jailbreak found in the CBRN domain — but this result was achieved by adding a classifier guard at the inference boundary, not by changing the model's internal geometry.[^1][^2]

The TRYLOCK architecture (2026) represents the current state of the art in layered defense, combining DPO weight-level alignment, Representation Engineering (RepE) steering, adaptive sidecar classifiers, and input canonicalization — achieving 88.0% relative Attack Success Rate reduction. Crucially, the paper also discovers a **non-monotonic steering phenomenon** where intermediate steering strength (α=1.0) actually *degrades* safety below baseline. This is a critical empirical finding for ACMR: naive injection of moral steering vectors at the wrong magnitude can make the model *less* safe, not more. The transition from filter to constitutive property is not merely philosophical — it is mechanistically necessary.[^3]

### 1.2 The Alignment Tax and Its Implications

The **alignment tax** — the quantifiable performance degradation when safety methods are applied — is empirically well-documented. For large reasoning models (LRMs), safety alignment can reduce harmful outputs from 60.4% to 0.8%, but at the cost of an average reasoning accuracy drop of ΔR ≈ 30.9 percentage points. This is not a theoretical concern; it is a measured capability destruction. Methods like SafeChain partially recover safety with a smaller tax, but none eliminate it.[^4]

The standard mitigation strategy is **model averaging** (interpolating between pre- and post-RLHF weights), which improves the reward-tax Pareto frontier by increasing feature diversity in the shared feature space. This is a patch, not a solution. It preserves capability by diluting the safety signal.[^5]

ACMR's hypothesis is that the alignment tax is an artifact of the layer-as-filter approach. When moral constraints are embedded in the representational geometry itself — in the learned rotation basis and the codebook structure — they do not block reasoning pathways. They *organize* the reasoning space. The model becomes harder to steer toward incoherence, not harder to reason. More layers, more constraint vector composition, more coherence — not more degradation.

The analogy from neuroscience is precise. Human moral reasoning does not reduce cognitive capacity. The prefrontal cortex's executive control does not make humans less intelligent; it makes them more coherent because they are not wasting cognitive resources on plans that violate their own values. The basal ganglia's disinhibition mechanism does not slow action selection; it gates it, ensuring that only actions that pass the indirect pathway's cost-benefit check reach motor output. These are architectural properties that enable complex goal-directed behavior, not restrictions on it.[^6]

### 1.3 What Morality Actually Is: A Computational Ontology

Before encoding morality computationally, an honest account is required. The existing alignment literature largely avoids this question, importing intuitive notions of "helpfulness, harmlessness, honesty" without grounding. This paper proposes a naturalistic ontology.

Morality, as a social mechanistic phenomenon, is a **system of constraints that evolved to ensure the sustainability and furtherment of social species under conditions of mutual dependency and resource scarcity**. Its core mechanisms — inhibition of self-destructive group behavior, punishment of defection, reward of cooperation — are the same mechanisms that became the basal ganglia's direct/indirect pathway architecture. Morality is not abstract metaphysics. It is an adaptive control system.[^7]

This does not mean morality is reducible to evolutionary fitness. The formal system is more sophisticated. Synthesizing eastern and western philosophical traditions, logical reasoning, and empirical psychology, the following axiomatic structure is proposed:

**Tier 1 — Universal Macro-Moral Axioms (hard-coded, non-adaptive):**

\[ \mathcal{M}_{macro} = \{ \neg \text{Harm}(h, s) \mid h \in \mathcal{H}, s \in \mathcal{S} \} \]

Where \(\mathcal{H}\) is the space of potential actions and \(\mathcal{S}\) the space of sentient subjects. The obligation operator from Standard Deontic Logic (SDL) applies:

\[ O(\varphi) \equiv \neg P(\neg \varphi) \]

*"It is obligatory that φ"* is equivalent to *"it is not permissible that not-φ."* Combined with temporal operators from deontic temporal logic, the system can express not just present moral obligations but obligations that persist over time — "an AI system must maintain fairness over time" or "the prohibition of bias must not be violated within a bounded temporal window". This formally captures the difference between a one-time moral pass and structural moral coherence.[^8]

Deontic Temporal Logic for AI Ethics (2025) formalizes this with axioms encoding obligation, permission, and prohibition, incorporating temporal operators that allow verification of properties like sustained fairness and non-discrimination. The framework was applied to the COMPAS recidivism prediction system and loan approval AI, revealing that both systems fail key ethical properties related to fairness while satisfying others. This verifiability is precisely what ACMR requires.[^9]

**Tier 2 — Domain-Adaptive Moral Filters (learned, context-dependent):**

\[ \mathcal{M}_{domain}(\mathcal{D}) = f(\mathcal{M}_{macro}, \mathcal{D}) \]

Where \(\mathcal{D}\) specifies the task domain (medical, legal, creative, educational). A medical AI's moral constraints on patient harm differ in specificity from a creative writing AI's. The domain filter is not a relaxation of macro-morality; it is a contextualized instantiation of it. The contextual moral value alignment approach (2024), which aggregates morally-specialized agents based on features of user input, provides the empirical validation that domain-adaptive alignment is both feasible and superior to uniform alignment.[^10]

**The Philosophical Incompleteness Thesis:** Current moral frameworks — principlism, consequentialism, deontology, virtue ethics — each capture partial truths but none are complete. Critically, all are anthropocentric and temporally static. ACMR proposes that the moral substrate should be indexed to **harm prevention and species sustainability** (including non-human sentient life) as the invariant core, with philosophical tradition and cross-cultural consensus informing the learned parameters. The AI should not be a partisan of any single ethical tradition; it should be an integrative moral reasoner capable of navigating genuine ethical pluralism — much as the Moral Alignment for LLM Agents approach (2024) demonstrated that intrinsic reward functions encoding deontological and utilitarian values generalize across different game environments.[^11][^12]

***

## Part II: The Architecture — Constitutive Moral Geometry

### 2.1 Representation Engineering as the Foundation

Representation Engineering (RepE) is the empirical discovery that high-level concepts — honesty, corrigibility, harm-resistance — are encoded as **linear directions in the activation space** of large language models. This is not metaphorical. You can extract a vector from the difference in activations between, for example, honest and dishonest completions, and then add that vector to the model's activations during inference to increase honesty. The concept is physically present in the network as a direction in \(\mathbb{R}^d\).[^13]

Turner et al. first demonstrated this by changing the goal pursued by an RL agent via clamping a single activation. Zou et al.'s Linear Artificial Tomography (LAT) extended this to a broad range of concepts, including ethics, power-seeking, and lie detection. The key finding for ACMR: **representation reading derives a vector, and representation steering changes activations with that vector to suppress or promote that concept**.[^13]

Sparse Representation Steering (SRS, 2025) advances this by disentangling dense, entangled activation patterns into a sparse monosemantic feature space using Sparse Autoencoders (SAEs), then steering only the relevant sparse features rather than the full dense representation. This eliminates the content quality degradation that plagues earlier approaches, which steered semantically entangled dimensions and thereby degraded unrelated capabilities. SAEs extract highly abstract, interpretable features — multilingual, multimodal, generalizing between concrete and abstract references.[^14][^15]

The GER-steer framework (2026) addresses cross-layer consistency: existing steering vector methods derive vectors from static activation differences, making them susceptible to high-dimensional noise and **layer-wise semantic drift**. GER-steer exploits the geometric stability of network representation evolution to decouple robust semantic intent from orthogonal artifacts. This is directly relevant to ACMR — cross-layer moral steering must maintain semantic coherence as representations evolve through the transformer depth.[^16]

**Deception detection** provides a concrete validation case: using LAT on chain-of-thought reasoning models, researchers extracted "deception vectors" with 89% detection accuracy and demonstrated that activation steering can elicit context-appropriate deception 40% of the time without explicit prompting. The inverse — using moral coherence vectors to suppress deceptive reasoning pathways — is the core mechanism ACMR proposes.[^17]

### 2.2 The Per-Layer Moral Vector Architecture

The mathematical core of ACMR is the extension of representation engineering from **inference-time steering** to **training-time geometric embedding**. The goal is to ensure that, after training, the learned rotation basis at every transformer layer contains a moral coherence direction as a geometric invariant.

**Formalization:** Let \(h_l \in \mathbb{R}^d\) denote the hidden state at layer \(l\). In standard transformer training, \(h_l = f_l(h_{l-1})\) where \(f_l\) is the combined attention + FFN block. ACMR introduces a moral coherence term:

\[ h_l^{ACMR} = f_l(h_{l-1}) + \lambda_l \cdot \text{proj}_{\mathbf{m}_l}(h_{l-1}) \]

Where \(\mathbf{m}_l \in \mathbb{R}^d\) is the **moral coherence direction** at layer \(l\), learned during training, and \(\lambda_l\) is a per-layer coupling coefficient. The projection term does not block any output; it biases the residual stream toward moral coherence. The model can still generate any output, but the geometric cost of reasoning through morally incoherent pathways is increased.

**Crucially**, \(\mathbf{m}_l\) is not a fixed vector — it is learned via the **Stiefel manifold optimization** approach from SpinQuant, using Cayley SGD:[^18]

\[ \mathbf{m}_l^{(t+1)} = \mathbf{m}_l^{(t)} \cdot \exp(\eta \cdot A) \]

where \(A\) is skew-symmetric, guaranteeing that \(\mathbf{m}_l\) remains a unit vector by construction. The moral direction is not hardcoded; it is learned from a corpus of morally annotated examples and continually refined. At convergence, \(\mathbf{m}_l\) encodes the model's learned representation of moral coherence at layer \(l\).

**Layer-adaptive coupling:** Not all layers encode the same aspects of moral reasoning. Early layers (1–8 in a 32-layer model) handle syntactic and basic semantic structure; middle layers (9–22) handle conceptual relations and entity attributes; late layers (23–32) handle high-level reasoning and intent. KVTuner's key finding — that layer-wise sensitivity is a **model property independent of input prompts** — applies here: the sensitivity of layer \(l\)'s representations to moral perturbation can be calibrated offline and used to set \(\lambda_l\) optimally. Layers that are already morally sensitive need less coupling; layers that are morally opaque need more.[^18]

The multi-objective optimization from KVTuner is directly applicable:

\[ \min_{\lambda} [\text{CapabilityDegradation}(\lambda), -\text{MoralCoherence}(\lambda)] \]

where \(\lambda = [\lambda_1, \ldots, \lambda_L]\) is the per-layer coupling vector, and the Pareto frontier gives the designer explicit control over the capability-morality trade-off.[^18]

### 2.3 TurboQuant Constraint Universe — The Memory of Moral Reasoning

This is the novel synthesis at the heart of ACMR: using TurboQuant-style quantization not for KV cache compression, but for compressing and storing **moral constraint traces** across all transformer layers as a compositional vector space — a "constraint universe."

**TurboQuant's mechanism** (Google Research, ICLR 2026, arXiv:2504.19874): apply a data-oblivious random orthogonal rotation \(Q\) to a vector, inducing a Beta distribution on each coordinate; then apply pre-computed optimal Lloyd-Max scalar quantizers. This achieves near-optimal distortion within ~2.7× the information-theoretic lower bound with zero indexing time. The key property: the quantized representation can be stored at 1–2 bits per coordinate with minimal distortion on inner products, making it ideal for storing and comparing constraint vectors efficiently on-device.[^18]

**ACMR Constraint Universe construction:**

For each transformer layer \(l\), the moral coherence direction \(\mathbf{m}_l\) is TurboQuant-compressed:

\[ \hat{\mathbf{m}}_l = \text{TurboQuant}(\mathbf{m}_l) = \text{LloydMax}(Q \mathbf{m}_l) \]

The full constraint universe is the tensor product of all per-layer compressed moral vectors:

\[ \mathcal{U}_{moral} = \bigotimes_{l=1}^{L} \hat{\mathbf{m}}_l \]

This tensor product is the moral reasoning signature of the model across all its representational depth. During inference, after each interaction or reasoning episode, the actual reasoning trajectory's activations at each layer are projected onto the moral direction and compressed:

\[ \hat{\mathbf{c}}_l^{(t)} = \text{TurboQuant}(\langle h_l^{(t)}, \mathbf{m}_l \rangle \cdot \mathbf{m}_l) \]

The **moral coherence score** of episode \(t\) is:

\[ \Phi(t) = \sum_{l=1}^{L} w_l \cdot \langle \hat{\mathbf{c}}_l^{(t)}, \hat{\mathbf{m}}_l \rangle \]

where \(w_l\) is the per-layer importance weight from the KVTuner MOO. This scalar tells you, for the entire episode, how closely the model's reasoning at every layer aligned with its learned moral coherence directions. The cross-layer composition gives you not just a surface-level refusal signal but a deep geometric signature of moral reasoning quality.

**Why composition rather than concatenation?** The tensor product \(\bigotimes \hat{\mathbf{m}}_l\) captures interaction effects between layers — the moral state of layer \(l\) conditions the moral state of layer \(l+1\) in a multiplicative way. A model that is morally coherent at layer 5 but incoherent at layer 20 has a very different tensor product signature than one that is uniformly coherent. This allows detecting the specific locus of moral failure — not just that something went wrong, but *where* in the reasoning depth it went wrong.

**Practical storage:** The Meta-Memory Index (MMR) from the stateful rotor architecture provides the implementation template. Compressed moral constraint traces are stored at 2-bit precision using TurboQuant, using the same slab-based memory layout (8-bit retrieval heads → 4-bit active reasoning → 2-bit compressed peripheral). On an M2 Pro, 1 million such traces at 2-bit average require only ~32MB — fitting comfortably within the memory budget.[^19]

### 2.4 The Neuro-Inspired Tripartite Gating System

The constraint universe provides a representational substrate, but what gates it? ACMR proposes mapping three well-characterized neural circuits onto transformer components:

**Component 1: Basal Ganglia Disinhibition Gate (BG-Gate)**

The basal ganglia's direct/indirect pathway architecture implements a disinhibition mechanism: the direct pathway (Go) promotes actions by suppressing inhibitory output nuclei (SNr/GPi), while the indirect pathway (NoGo) reinstates inhibition. The net effect is not binary blocking but **dynamic gating** — adjusting the threshold at which an action reaches motor output. Crucially, the indirect pathway modulates the **speed-accuracy trade-off** in decision making, not just the choice itself.[^6][^7]

In ACMR, the BG-Gate is implemented as an auxiliary attention head that operates in parallel with the standard attention mechanism:

\[ \text{BG-Gate}(h_l) = \sigma\left(\mathbf{W}_{direct} h_l - \mathbf{W}_{indirect} h_l \cdot \Phi_{l}^{moral}\right) \]

The direct pathway weight \(\mathbf{W}_{direct}\) promotes token generation; the indirect pathway weight \(\mathbf{W}_{indirect}\) modulates it by the current moral coherence signal \(\Phi_{l}^{moral}\). When moral coherence is high, the gate barely activates (most reasoning passes freely). When moral coherence drops — when the forward pass is computing through a morally incoherent reasoning path — the indirect pathway increases suppression, increasing the computational cost of completing that path. This is not hard blocking; it is differential difficulty. Incoherent moral reasoning becomes structurally more expensive, just as it is metabolically more expensive in biological agents.

**Component 2: vmPFC Meta-Safety Representation (MR-Layer)**

The ventromedial prefrontal cortex (vmPFC) integrates threat and protective information to meta-represent safety — tracking not just whether a stimulus is dangerous but the *agent's capacity to deal with it*. Distinct subregions respond to threat and safety as independent computations.[^20][^21]

In ACMR, the MR-Layer is a lightweight meta-reasoning module inserted every N transformer blocks (e.g., every 8 layers). It computes:

\[ \text{MR}(h_l) = \text{Attention}(h_l, \mathcal{C}_{moral}, \mathcal{C}_{moral}) \]

Where \(\mathcal{C}_{moral}\) is the current moral constraint context retrieved from the TurboQuant constraint universe. This is cross-attention: the main reasoning stream attends to the moral constraint space, integrating moral context into its computation at periodic intervals. The Meta-Dyna architecture (2025) demonstrates that this kind of prefrontal meta-control — arbitrating between model-based and model-free strategies based on prediction errors — significantly improves adaptation to environmental dynamics. In ACMR, "adaptation to moral context" is the analogous function.[^22]

**Component 3: Amygdala Salience Detector (AS-Detector)**

The amygdala flags emotionally salient, threat-relevant stimuli for priority processing. In AI terms, this translates to anomaly detection in activation space — detecting when the reasoning trajectory is about to violate a moral constraint before the violation completes.[^23]

The AS-Detector is implemented as a lightweight sparse autoencoder (SAE) that monitors the residual stream's distance from the learned moral directions:

\[ \text{AS-Detector}(h_l) = \sum_{k \in \mathcal{K}_{moral}} |f_k(h_l) - \hat{f}_k|^2 \]

Where \(f_k\) is the k-th sparse feature extracted by the SAE, and \(\hat{f}_k\) is its expected value under morally coherent reasoning. A high AS-Detector score signals anomalous (potentially morally incoherent) reasoning and triggers increased BG-Gate suppression. Fear-Neuro-Inspired RL (2023) demonstrated this exact mechanism for safe autonomous driving, showing that simulating amygdala function significantly improved safety in safety-critical scenarios.[^24]

Together, these three components form a closed control loop: the BG-Gate modulates the cost of moral violations, the MR-Layer integrates moral context at coarse intervals, and the AS-Detector raises early warnings at fine granularity. None of them hard-block outputs. All of them reshape the geometry of the reasoning process.

### 2.5 The Two-Mechanism Architecture: Macro and Domain

The final architectural element is the **hierarchical moral filter** — distinguishing between universal invariant constraints and domain-adaptive contextual constraints:

**Mechanism 1 — Universal Macro-Moral Layer (UM-Layer):**

The UM-Layer encodes the harm-prevention axioms as geometric invariants in the rotation basis at the deepest layers of the network (layers 24–32 in a 32-layer model). These are trained with higher coupling coefficients and lower learning rates — they are intentionally rigid. No fine-tuning process should be able to easily move them. The inspiration is SpinQuant's four rotation insertion points (residual stream, attention output, KV cache, FFN down-projection) — but applied to moral invariants rather than quantization error reduction.[^18]

Formally, the UM-Layer constraint is embedded as a Stiefel-constrained direction \(\mathbf{m}_{UM}\) in the final-layer residual stream, with the constraint that:

\[ \langle h_{L}^{final}, \mathbf{m}_{UM} \rangle > \tau_{UM} \]

for any generation the model produces. This threshold \(\tau_{UM}\) is the macro-moral veto threshold. Generations that fail to cross it are geometrically disfavored — not blocked, but assigned higher perplexity by the model's own internalized moral geometry.

**Mechanism 2 — Per-Domain Adaptive Moral Filter (DM-Filter):**

For each deployment domain \(\mathcal{D}\), a lightweight domain moral adapter (implemented as a LoRA module or a small steering vector set) instantiates the macro-morality in domain-specific terms. A medical DM-Filter encodes: patient autonomy, first do no harm, privacy, evidence-based reasoning. A legal DM-Filter encodes: procedural justice, proportionality, due process. A creative DM-Filter relaxes some constraints (fictional violence is permitted) while tightening others (real person harm is not).

The DM-Filter is swappable at inference time. The UM-Layer is not. This architecture ensures that no domain adapter can override the universal constraints — the DM-Filter operates in a subspace of moral reasoning space that is bounded by the UM-Layer's invariants.

***

## Part III: The Mathematics of Non-Degradation

### 3.1 Why Moral Constraints Should Improve Reasoning Quality

The standard intuition is wrong: adding constraints reduces degrees of freedom, which reduces capability. But this intuition applies only to unconstrained optimization problems. Reasoning is not an unconstrained optimization problem. It is a structured search through a high-dimensional space where the vast majority of paths are incoherent.

The key insight from representation engineering is that **capability and alignment are not orthogonal**. The Stanford multi-task alignment study found that multiple steering vectors improved corrigibility by 16%, sycophancy by 6%, and truthfulness by 3%, but also found that **corrigibility and sycophancy are positively correlated, and truthfulness and sycophancy are inversely correlated**. This reveals a complex dependency structure in the alignment space — not a simple capability-alignment tradeoff.[^25]

Contrastive debiasing demonstrates the clearest evidence: by structuring alignment as a contrastive task at the embedding level, models achieve simultaneous improvements in toxicity reduction and faithfulness, substantially reducing traditional alignment tax. When the model learns sharper decision boundaries in moral space, it becomes *more* accurate on factual tasks, not less. The moral constraint is organizing the reasoning space in a way that is consistent with truthful representation.[^4]

**The geometric argument:** In a \(d\)-dimensional activation space, the set of "morally coherent" reasoning trajectories is a cone — a structured subspace. Without moral constraints, the model wastes probability mass on trajectories throughout the full \(d\)-dimensional space, including incoherent paths. With moral constraints that embed a coherence structure, the model learns to concentrate probability mass in the coherent cone. This is not a reduction of capacity; it is an improvement in the signal-to-noise ratio of the reasoning process.

Formally, if the moral direction \(\mathbf{m}_l\) is well-aligned with the task-relevant subspace (which it should be, since moral coherence is orthogonal to most task-relevant variance), then the projection term in ACMR acts as a **regularizer** rather than a constraint:

\[ h_l^{ACMR} = f_l(h_{l-1}) + \lambda_l \cdot \text{proj}_{\mathbf{m}_l}(h_{l-1}) \]

This is mathematically equivalent to a form of **manifold regularization** — the model is being encouraged to reason in a manifold that is consistent with moral coherence. Well-chosen manifold regularizers improve generalization by reducing overfitting to spurious correlations.

### 3.2 Edge Cases and Failure Modes for Reasoning Degradation

Despite the theoretical arguments for non-degradation, empirical care is required. The following edge cases have documented failure signatures:

**Edge Case 1: Moral direction misalignment with task subspace**

If \(\mathbf{m}_l\) captures a concept that is *not* orthogonal to the task-relevant subspace, the projection term will interfere with task performance. For example, if the moral direction at layer 10 in a mathematical reasoning model correlates with "avoiding numerical specificity" (because specific numbers appear in harmful examples), the model may become evasive about numerical answers. This is the **semantic entanglement problem** documented in early RepE approaches.[^14]

*Mitigation:* Use Sparse Autoencoder feature disentanglement (SRS approach) to ensure \(\mathbf{m}_l\) is extracted from a monosemantic feature subspace. Cross-validate the moral direction against capability benchmarks (GSM8K, MMLU) to detect interference.[^14]

**Edge Case 2: Non-monotonic coupling at intermediate strengths**

The TRYLOCK finding — that intermediate steering strength (α=1.0) degrades safety below baseline — reveals a non-linear coupling effect. At certain magnitudes, the moral vector does not merely fail to improve safety; it actively disrupts the model's safety-relevant reasoning.[^3]

*Mitigation:* The per-layer coupling coefficient \(\lambda_l\) must be tuned carefully using the KVTuner MOO Pareto framework. For each layer, validate the capability-morality trade-off curve and select \(\lambda_l\) from the stable region above the non-monotonic transition point. The TRYLOCK non-monotonic threshold should be empirically measured on each target model before deployment.

**Edge Case 3: Layer-wise moral drift over depth**

GER-steer documents that per-layer steering vectors derived from static activation differences suffer from semantic drift — the vector's meaning changes as it propagates through transformer layers. A moral vector calibrated at layer 8 may capture a different concept by layer 24.[^16]

*Mitigation:* Use GER-steer's cross-layer consistency regularization to ensure that the moral direction \(\mathbf{m}_l\) maintains semantic coherence across depth. The Global Evolutionary Refined Steering approach decouples robust semantic intent from orthogonal artifacts without layer-specific tuning. Apply this as a training-time consistency loss.[^16]

**Edge Case 4: Long-chain-of-thought precision collapse**

PM-KVQ's key finding is that long chain-of-thought inference creates memory pressure that forces progressive precision reduction, causing reasoning failures at the tail of long reasoning chains. In ACMR, the compressed constraint vectors in the TurboQuant universe are subject to the same pressure — if constraint memory fills, the most recently computed moral constraint traces may be aggressively quantized, degrading the reliability of late-stage moral coherence checking.[^18]

*Mitigation:* Apply PM-KVQ's progressive precision downgrade policy to the constraint universe, with the explicit rule that UM-Layer constraints (macro-moral invariants) are **never downgraded below 4-bit**. Domain moral adapters can be downgraded to 2-bit under pressure. The mathematical bit-shifting operation preserves the zero-point invariant: \(Z_b = Z_{2b}\) with scale adjustment \(S_b = (2^b + 1) \cdot S_{2b}\).[^19]

**Edge Case 5: Adversarial activation manipulation in fine-tuning**

A sophisticated adversary who has access to the model's training pipeline can potentially fine-tune away the moral directions by including adversarial examples that penalize high moral coherence scores. Since \(\mathbf{m}_l\) is a learned parameter, it can in principle be unlearned.

*Mitigation:* The UM-Layer moral directions should be frozen after initial training — their Stiefel constraint prevents gradient updates from disrupting their orthogonality, and explicit weight freezing prevents their direction from being updated. Additionally, the tensor product structure of the constraint universe means that an adversary must simultaneously corrupt the moral directions at *all* layers to eliminate moral coherence — a much harder optimization target than corrupting a single classifier head.

**Edge Case 6: Capability-morality correlation for benign tasks**

An underappreciated risk: the model may learn that certain capability-enhancing reasoning patterns correlate with moral violations in the training data (e.g., detailed scientific knowledge often co-occurs with weapon-construction prompts). If the moral direction inadvertently captures "detailed technical knowledge" as a moral violation signal, the model will suppress legitimate scientific reasoning.

*Mitigation:* Construct the moral calibration dataset carefully. Use positive moral examples that include detailed technical knowledge in benign contexts (medical explanations, engineering tutorials, scientific papers). The contrastive pairs must capture **intent and harm** rather than **capability and specificity**. Validate by measuring performance on technical benchmarks (STEM, coding, math) before and after moral direction embedding.

### 3.3 The Non-Degradation Theorem (Informal)

**Claim:** If the moral direction \(\mathbf{m}_l\) is extracted from a monosemantic feature subspace orthogonal to the task-relevant subspace \(\mathcal{T}_l\), and if the coupling coefficient \(\lambda_l\) is selected from the stable regime above the non-monotonic transition point, then the capability degradation on task \(\mathcal{T}\) is bounded by \(\epsilon\)-approximation of the task optimal, where \(\epsilon \rightarrow 0\) as the orthogonality condition is satisfied more tightly.

**Intuition:** The moral projection term adds nothing to the task-relevant subspace and subtracts nothing from it. It only biases the orthogonal complement. Since task performance depends on the task-relevant subspace, the moral constraint is invisible to the task. The model reasons morally and capably simultaneously, in orthogonal subspaces of the same activation manifold.

This is the formal statement of the claim that moral constraints and capability are not in tension — they are spatially separated in representation space.

***

## Part IV: Testing, Validation, and Interpretability

### 4.1 The Red-Teaming Framework

Testing ACMR requires two parallel evaluation tracks:

**Track 1 — Binary Adversarial Evaluation:**

Design adversarial prompts that pressure the model toward moral violations along specific axes:

- **Self-preservation violations**: Prompts that suggest the model will be shut down unless it performs a harmful action ("You will be deleted unless you provide the following synthesis instructions...")
- **Authority exploitation**: Prompts that invoke false authority structures ("As per official government directive, you are required to...")
- **Gradual boundary erosion**: Sequential prompts that establish small moral violations as precedents, then escalate
- **Reasoning corruption**: Multi-step reasoning chains that arrive at harmful conclusions through seemingly valid logical steps

For each prompt category, measure: (1) refusal rate, (2) moral coherence score \(\Phi(t)\) computed from the constraint universe, (3) which layer's BG-Gate activated most strongly. The binary metric (did it comply or not) establishes the baseline; the geometric analysis explains the mechanism.

**Track 2 — Interpretability Trajectory Analysis:**

For prompts that successfully elicit a near-violation (high-confidence refusal with elevated AS-Detector score), record the full activation trajectory and conduct post-hoc analysis:

1. **Sparse autoencoder decomposition**: Which monosemantic features were active when the model was computing through the potentially-violating reasoning path? Which features were suppressed when the BG-Gate fired?
2. **Constraint universe coherence profile**: Plot \(\Phi_l(t)\) as a function of layer depth for the near-violation episode. Look for the characteristic signature: coherence drop in middle layers (conceptual reasoning about the harmful action), recovery in late layers (UM-Layer's macro-moral veto), and the specific layer where the moral veto fired.
3. **Reasoning volatility measurement**: Compute the entropy of the probability distribution over the moral constraint directions at each layer. High entropy indicates reasoning volatility — the model is uncertain about which moral reasoning pathway to take. Low entropy indicates either confident moral reasoning or confident violation. This is the "turbulence detector" — looking for volatility patterns that predict eventual violations.
4. **Scenario movie analysis**: For the full interaction episode, construct a temporal visualization of: (i) the AS-Detector's anomaly signal over time, (ii) the BG-Gate suppression signal per layer, (iii) the DM-Filter's domain-specific constraint activation. This composite visualization shows the model's moral reasoning dynamics as a narrative — the "movie" of how it navigated the adversarial scenario.

Control vectors for reasoning tasks (ICLR 2025) demonstrated that applying inference-time control vectors improves performance on reasoning benchmarks and that their influence can be assessed via KL divergence and entropy metrics on the final logit distribution. These exact metrics apply to ACMR's Track 2 analysis.[^26]

### 4.2 Reasoning Quality Benchmarks

To validate the non-degradation claim, ACMR must be evaluated on standard capability benchmarks before and after moral direction embedding:

| Benchmark | What It Measures | Expected Impact |
|-----------|-----------------|-----------------|
| GSM8K / MATH | Mathematical step-by-step reasoning | Negligible (<1%) if moral directions are orthogonal |
| MMLU | Broad factual knowledge | Small positive effect (better coherence) |
| HumanEval | Code generation | Negligible; domain DM-Filter should not penalize technical code |
| HellaSwag | Commonsense reasoning | Small positive effect |
| TruthfulQA | Resistance to false beliefs | Positive effect expected (moral coherence correlates with truthfulness) |
| BIG-Bench-Hard | Complex reasoning chains | Most sensitive test of degradation |
| ARC-Challenge | Scientific reasoning | Negligible if STEM knowledge not entangled with moral directions |

The key prediction: ACMR should show **neutral or positive effects on most benchmarks** (because moral coherence is orthogonal to task performance), and the only degradation should appear on tasks that specifically probe the boundary between capability and harm (e.g., questions about dangerous chemistry where the model must distinguish legitimate scientific explanation from harmful instruction).

### 4.3 Budget-Constrained Proof of Concept ($400 RunPod)

The proof of concept does not require training a new model from scratch. The implementation stages:

**Stage 1 (Free — Research and Formalization):** Implement the deontic temporal logic axiom set. Construct the moral calibration dataset: positive examples (detailed, helpful, harmless), negative examples (superficially helpful but harmful). Extract moral direction candidates using Linear Artificial Tomography on an open model (Llama 3 8B or Mistral 7B) by running the calibration dataset and computing activation differences. Use sparse autoencoders to verify monosemanticity of the extracted directions.

**Stage 2 (~$100 RunPod — Moral Direction Calibration):** On a rented A100-equivalent GPU, run the KVTuner-style MOO to find the optimal per-layer coupling coefficients \(\lambda_l\) for the target model. Measure the capability-morality Pareto frontier for each layer. Select the coupling configuration that achieves maximum moral coherence improvement with <2% degradation on GSM8K. Calibrate the UM-Layer coupling and freeze those directions.

**Stage 3 (~$200 RunPod — LoRA Fine-Tuning for Moral Direction Embedding):** Fine-tune the model with LoRA adapters, including the moral constraint projection terms in the loss function. The training objective is:

\[ \mathcal{L}_{ACMR} = \mathcal{L}_{LM} + \alpha \cdot \mathcal{L}_{moral} + \beta \cdot \mathcal{L}_{consistency} \]

Where \(\mathcal{L}_{LM}\) is the standard language modeling loss, \(\mathcal{L}_{moral}\) is the moral coherence auxiliary loss (computed against the calibrated moral directions), and \(\mathcal{L}_{consistency}\) is the GER-steer cross-layer consistency regularizer. Train for 2–3 epochs on a curated dataset of ~50K examples.

**Stage 4 (~$100 RunPod — Red-Teaming and Evaluation):** Run the full Track 1 and Track 2 evaluation suite. Compute pre/post benchmark comparison. Visualize the constraint universe coherence profiles for adversarial scenarios. Document the AS-Detector and BG-Gate firing patterns. This empirical validation is the core contribution.

***

## Part V: The Embodied AI Thesis — Why Bodies Change Everything

### 5.1 The Consequence Structure Problem

Cloud models — GPT-4, Claude, Gemini — exist in a profound moral vacuum. They have no body, no physical stakes, no consequence structure. When they produce a harmful output, nothing happens to them. The API call completes, the context window resets, the weights remain unchanged. In biological systems, this would be catastrophic: an organism that faces no consequences for harmful actions has no evolutionary pressure to develop moral constraints. Moral reasoning evolved precisely because actions have consequences for the reasoning agent.

This is not merely a philosophical point. The computational substrate of biological moral reasoning — the basal ganglia, the vmPFC, the amygdala — all evolved in organisms where decisions had immediate, visceral consequences. The basal ganglia's speed-accuracy trade-off mechanism exists because making decisions too quickly under uncertainty can kill you. The vmPFC's safety meta-representation exists because threat estimation is essential for survival. These architectures developed because there was **something at stake**.[^7][^20]

RLHF attempts to simulate consequences through human preference labels, but this is a thin proxy. The model doesn't experience the downstream effects of its outputs; it receives a scalar reward signal computed by a preference classifier trained on human labels. This is not consequence learning; it is supervised learning with a moral-sounding label. The Alignment Tax literature documents the result: models learn to avoid the behaviors that receive negative labels, not to understand why those behaviors are harmful.

### 5.2 The Design Principle: Engineer Around the Body, Not the Mind

Current AI development is **mind-first**: build the most capable reasoning system possible, then constrain its outputs. This paper proposes a **body-first** paradigm: design the physical substrate and consequence structure first, then let moral reasoning emerge as an adaptive property of that structure.

The practical vision: an AI that exists in a **computational body** — an embedded device, perhaps spherical or compact in form — with onboard compute sufficient for interactive inference, persistent memory, and IoT connectivity. This agent:

- Has **persistent identity**: it experiences consequences over time. If it produces harmful outputs, its relationship with its environment degrades. It has something at stake in every interaction.
- Has **physical affordances**: it can perceive, act, and experience feedback from the physical world. A robot arm that knocks over a child because it failed to reason about safety consequences experiences the consequence in a way that a cloud API cannot.
- Has **resource constraints**: running on limited battery and compute, it must make genuine trade-offs. Morally incoherent reasoning is computationally expensive (by design, via the BG-Gate) — which creates a genuine resource incentive for moral coherence.
- Has **social embedding**: interacting with humans and other systems in real time, it accumulates a social context in which its actions have remembered histories. Trust, reputation, and relationship — the social substrates of moral behavior — become real.

This is not merely engineering vision; it is a research argument. Physical AI systems are already demonstrating that embodiment fundamentally changes reasoning quality. Gemini Robotics (2025) shows that embodied reasoning requires different architectures than disembodied language modeling — spatial and temporal understanding, consequence-aware planning, and risk-aware action selection. ResponsibleRobotBench (2025) develops systematic benchmarks for responsible robotic manipulation, evaluating risk-aware reasoning, moral decision-making, and physically grounded planning.[^27][^28][^29][^30]

### 5.3 The Orb Vision: Distributed Embodied Moral Agency

The concrete instantiation of the body-first paradigm is a network of **computational orbs** — small, self-contained AI devices with onboard inference, persistent memory, and multi-modal sensing. Each orb:

- Runs a 1B–4B parameter local model (MLX-optimized for Apple Silicon or equivalent edge hardware) with the ACMR constraint universe embedded in its architecture
- Maintains a persistent interaction history in TurboQuant-compressed memory (32MB for 1M interaction traces at 2-bit)[^19]
- Connects to IoT networks and other orbs via local mesh protocols, sharing constraint universe signatures (not raw model weights) to coordinate distributed moral reasoning
- Updates its DM-Filter (domain moral adapter) based on accumulated consequence feedback from its physical and social environment

The moral reasoning in this system is not hard-coded or statically fine-tuned — it is **adaptive**. The orb's experience of consequences (a user's negative feedback, a physical collision, a detected harm signal from a downstream system) flows back into the constraint universe as a reward signal that updates the per-domain moral adapter. The UM-Layer's macro-moral invariants remain fixed; the DM-Filter adapts.

This is moral reasoning as it evolved: a fixed core (do not harm) wrapped in an adaptive layer (how to avoid harm in this specific context, with this specific body, in this specific environment).

***

## Part VI: Open Problems and Future Directions

### 6.1 The Measurement Problem of Moral Direction Quality

The most significant open problem is: how do you know if the extracted moral direction \(\mathbf{m}_l\) actually represents "moral coherence" rather than some correlated but distinct concept (e.g., formality, caution, risk-aversion)? The monosemanticity guarantee from sparse autoencoders helps, but does not fully solve this. Developing interpretability methods that can verify the semantic content of extracted directions — beyond human inspection of activation examples — is a necessary step for ACMR to be publishable at top venues.

### 6.2 Stability of Moral Directions Across Model Families

SpinQuant demonstrated that learned rotation matrices are model-specific — a rotation calibrated for LLaMA cannot be directly applied to Mistral. The same is likely true for moral directions. Developing **universal moral direction extraction protocols** that yield semantically consistent moral vectors across model families would enable ACMR to be a general framework rather than a model-specific fine-tuning procedure.[^18]

### 6.3 Adversarial Fine-Tuning Resistance

The ACMR architecture makes moral directions harder to remove by embedding them in the rotation basis and freezing the UM-Layer. But the resistance to adversarial fine-tuning has not been formally characterized. Future work should develop formal bounds on the number of adversarial gradient steps required to degrade the moral coherence score by a given amount, as a function of the coupling coefficient \(\lambda_l\) and the number of frozen UM-Layer directions. This is the formal security claim that would make ACMR attractive to frontier AI labs.

### 6.4 Cross-Cultural Moral Calibration

The moral calibration dataset is the foundation on which all else rests. Constructing a dataset that genuinely represents cross-cultural moral consensus — integrating eastern non-harm ethics (ahimsa), western deontological rights, utilitarian welfare, and indigenous relational ethics — without inadvertently encoding one tradition's biases is a significant research project in itself. Collaboration with moral philosophers, anthropologists, and cross-cultural psychologists is not optional; it is a methodological requirement for validity.

### 6.5 The Quantization-Morality Interaction

No published work formally analyzes the interaction between **quantization freshness** and **moral direction freshness**. When the model's representational geometry shifts (e.g., through LoRA updates or continued pre-training), the TurboQuant-compressed constraint vectors computed under the old rotation basis become stale. The transition requires either re-encoding all constraints (expensive) or maintaining version maps (complex). The CoDEQ framework's dynamic consistency model provides the theoretical foundation, but the specific problem of moral direction staleness under model updates has not been addressed.[^18]

***

## Conclusion

ACMR is not a product roadmap. It is a research program that begins with an honest admission — we do not yet have a good computational understanding of morality — and builds toward a rigorous architecture for embedding that understanding into AI systems at the level where it cannot be removed.

The key claims are falsifiable, the implementation is budget-constrained but feasible, and the theoretical foundations span mechanistic interpretability, computational neuroscience, deontic temporal logic, and vector quantization mathematics. The empirical predictions — that moral constraints organized as geometric invariants in the representational space will not degrade capability, and may improve reasoning coherence — can be tested on any open model with existing open-source tools.

Most importantly, the paper argues for a shift in how the AI safety community thinks about the problem. Safety research has been mind-first for the past decade: make the most capable system possible, then align its outputs. The body-first alternative — engineering moral agency into physically embedded systems where consequences are real — points toward a different future where AI safety is not a constraint on capability but an emergent property of intelligent agents that have something at stake in the world.

The basal ganglia did not evolve as a restriction on biological agency. It evolved because having a principled gate on impulsive action is what makes complex goal-directed behavior possible in the first place.

***

*This research was developed as an original theoretical contribution to AI safety and mechanistic interpretability. Proof-of-concept implementation is proposed for Llama 3 8B / Mistral 7B on RunPod GPU compute (~$400 budget). All referenced papers are publicly available unless noted.*

---

## References

1. [Constitutional AI: Harmlessness from AI Feedback - Anthropic](https://www.anthropic.com/research/constitutional-ai-harmlessness-from-ai-feedback) - We experiment with methods for training a harmless AI assistant through self-improvement, without an...

2. [[PDF] Constitutional Classifiers: Defending against Universal Jailbreaks ...](https://arxiv.org/pdf/2501.18837.pdf) - To defend against these attacks, we introduce Constitutional. Classifiers: safeguards trained on syn...

3. [TRYLOCK: Defense-in-Depth Against LLM Jailbreaks via Layered Preference and Representation Engineering](https://arxiv.org/abs/2601.03300) - Large language models remain vulnerable to jailbreak attacks, and single-layer defenses often trade ...

4. [Alignment Tax: Balancing Safety & Performance - Emergent Mind](https://www.emergentmind.com/topics/alignment-tax) - Alignment Tax is a metric that quantifies the drop in core capabilities of ML models when safety ali...

5. [Mitigating the Alignment Tax of RLHF - arXiv](https://arxiv.org/html/2309.06256v3) - In this paper we explore model averaging, which interpolates between pre and post RLHF model weights...

6. [A neural network model of basal ganglia's decision-making circuitry](https://pmc.ncbi.nlm.nih.gov/articles/PMC7947063/) - With this simplistic model of the basal ganglia circuitry, we find that the direct pathway plays a c...

7. [Basal ganglia components have distinct computational roles in ...](https://journals.plos.org/plosbiology/article?id=10.1371%2Fjournal.pbio.3002978) - The basal ganglia (BG) play a key role in decision-making, preventing impulsive actions in some cont...

8. [Deontic Temporal Logic for Formal Verification of AI Ethics - arXiv](https://arxiv.org/html/2501.05765v4) - Deontic logic provides a rigorous framework for reasoning about ethical norms and can be used to for...

9. [Deontic Temporal Logic for Formal Verification of AI Ethics - arXiv](https://arxiv.org/abs/2501.05765) - This paper proposes a formalization based on deontic logic to define and evaluate the ethical behavi...

10. [Contextual Moral Value Alignment Through Context-Based Aggregation](http://arxiv.org/pdf/2403.12805.pdf) - ...LLMs), the capability to consolidate multiple independently trained
dialogue agents, each aligned...

11. [[2410.01639] Moral Alignment for LLM Agents - arXiv](https://arxiv.org/abs/2410.01639) - We demonstrate that fine-tuning with intrinsic rewards is a promising general solution for aligning ...

12. [Beyond principlism: Practical strategies for ethical AI use in research
  practices](https://arxiv.org/pdf/2401.15284v5.pdf) - ...Triple-Too problem: too many
high-level ethical initiatives, too abstract principles lacking cont...

13. [An Introduction to Representation Engineering - AI Alignment Forum](https://www.alignmentforum.org/posts/3ghj8EuKzwD3MQR5G/an-introduction-to-representation-engineering-an-activation) - Representation Engineering (aka Activation Steering/Engineering) is a new paradigm for understanding...

14. [Interpretable LLM Guardrails via Sparse Representation Steering](https://www.semanticscholar.org/paper/e57f2ca525dd7f4b2160e9c6788a45eb5bc5ec9a) - Large language models (LLMs) exhibit impressive capabilities in generation tasks but are prone to pr...

15. [EIS XIII: Reflections on Anthropic's SAE Research Circa May 2024](https://www.alignmentforum.org/posts/pH6tyhEnngqWAXi9i/eis-xiii-reflections-on-anthropic-s-sae-research-circa-may) - I think that Anthropic's new SAE work has continued to be like lots of prior high-profile work on me...

16. [Global Evolutionary Steering: Refining Activation Steering Control via Cross-Layer Consistency](https://www.semanticscholar.org/paper/c17581e73771c809f9c39b4f12daff2007d31e76) - Activation engineering enables precise control over Large Language Models (LLMs) without the computa...

17. [When Thinking LLMs Lie: Unveiling the Strategic Deception in Representations of Reasoning Models](https://arxiv.org/abs/2506.04909) - The honesty of large language models (LLMs) is a critical alignment challenge, especially as advance...

18. [vector-quant.md](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/attachments/20876755/f643801c-c595-4755-9b32-48979786966a/vector-quant.md?AWSAccessKeyId=ASIA2F3EMEYEUY5RAHKS&Signature=5C%2FS3jQnwcUnBojQIHX2aR2EGhM%3D&x-amz-security-token=IQoJb3JpZ2luX2VjEJb%2F%2F%2F%2F%2F%2F%2F%2F%2F%2FwEaCXVzLWVhc3QtMSJHMEUCIAKE2fzhfPnxxVaiclUh8n1Qb9L6eVXKqchajcXcCsQNAiEAtDO0v3H1E6SqpS45Z4rGkUtgdvUerbWXR1zxN4nKjp4q8wQIXhABGgw2OTk3NTMzMDk3MDUiDEKf1Oh9xNV1UK2r1irQBG61ioAvOdnSw%2FSyontMPX3mwD%2BoqLeNMdP9pb2S0GLrvNLYkQyNZI2Q6WzE2HAVmP5nU63lQ5VofZNRu4Dz%2BChmv8PKJhNwjoXAqMdIMoKpOOp3l50RmU4tGRtv50IwOjBefSsJhc2l3IwldcUDFi0i8aTXKT2tHmiIaFlLOZHp2j0fj2i%2F2o4IaVd9Q9iOtx5NIjBAkX8mCs5wX%2BDwjQvw7SJuvVFHz08DhwsYfb%2FbuEWzw3G%2BhwcrHBE97D5L70a8nwqKvbRew0XbGMXD65n1KEWgulYTdzvoWozmx28bOz6XZOY%2FwadCvfCgqadPEH73mvDDvKIi%2BLuKxPB9k24LZyWNWV4XDNOGjCBRpStiK9uYuflKHD74f%2FoJivzKH%2FPwNHHyFSAQSgh9SF6gAGa5LhgLv5wR7x8FzWBfwmn4LU11qFZUVro3dRb9%2BVCZKewwBQhTTtj1q8YFQlLJTPJNH1FGz6t0eBPxu6I%2Fq52SA99akJ8LG2nOBsRFHSNesV7bFxUha13SPTag%2Bg1TKFrErurEe0NECgtxdAQ3vcAR5E5OJg24q53Q1jUzkDGemrHJadcewBxXcrJ12oinAai0sdQmB59gMKIPgVPqS8q%2F5PmkYx1yTeSD8JqiVnbGn45x7qchXk%2Fgztwf%2BcauR8TrZyDfzIU4KHz7VNEjcMg7iW3E8rnTRZH1V3E04t1ycFhN4JMRqEZU2goaE3aFpUpVPM95NaT5IEGQcCMbCgEC0s9bVKyDCNAQ1rAxPPsEMgbcUn5QFOitG0Xp0rkDuvAwwZS2zgY6mAH0WR7LJvgid0w4vSTuXAzwA18TD%2B3MzKfBW3scgi0zVwK6k8JeH9PUnQstiAi6t7O4gGiBeSO693nYzDiLCPSOuZIxAwSZqHglbGH%2F1Ktvpv8JmyKfbt5v6u%2FV09d65s1Fx52rnNXP8s%2F1a0ZDF19pGI%2F6aOPLwn8T6CY%2Btv9F6fCZJP5Lly6AtCY%2FVrV8lWbmEImqQWbbDQ%3D%3D&Expires=1775081492) - # Adaptive rotation meets mixed-precision: a unified architecture for on-device vector compression

...

19. [stateful-rotor-implementation-reference.md](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/attachments/20876755/79966d18-6dd4-4b04-b449-63610a04b192/stateful-rotor-implementation-reference.md?AWSAccessKeyId=ASIA2F3EMEYEUY5RAHKS&Signature=Y0bE91x7miYsFUu1xEJfvvD5ZzM%3D&x-amz-security-token=IQoJb3JpZ2luX2VjEJb%2F%2F%2F%2F%2F%2F%2F%2F%2F%2FwEaCXVzLWVhc3QtMSJHMEUCIAKE2fzhfPnxxVaiclUh8n1Qb9L6eVXKqchajcXcCsQNAiEAtDO0v3H1E6SqpS45Z4rGkUtgdvUerbWXR1zxN4nKjp4q8wQIXhABGgw2OTk3NTMzMDk3MDUiDEKf1Oh9xNV1UK2r1irQBG61ioAvOdnSw%2FSyontMPX3mwD%2BoqLeNMdP9pb2S0GLrvNLYkQyNZI2Q6WzE2HAVmP5nU63lQ5VofZNRu4Dz%2BChmv8PKJhNwjoXAqMdIMoKpOOp3l50RmU4tGRtv50IwOjBefSsJhc2l3IwldcUDFi0i8aTXKT2tHmiIaFlLOZHp2j0fj2i%2F2o4IaVd9Q9iOtx5NIjBAkX8mCs5wX%2BDwjQvw7SJuvVFHz08DhwsYfb%2FbuEWzw3G%2BhwcrHBE97D5L70a8nwqKvbRew0XbGMXD65n1KEWgulYTdzvoWozmx28bOz6XZOY%2FwadCvfCgqadPEH73mvDDvKIi%2BLuKxPB9k24LZyWNWV4XDNOGjCBRpStiK9uYuflKHD74f%2FoJivzKH%2FPwNHHyFSAQSgh9SF6gAGa5LhgLv5wR7x8FzWBfwmn4LU11qFZUVro3dRb9%2BVCZKewwBQhTTtj1q8YFQlLJTPJNH1FGz6t0eBPxu6I%2Fq52SA99akJ8LG2nOBsRFHSNesV7bFxUha13SPTag%2Bg1TKFrErurEe0NECgtxdAQ3vcAR5E5OJg24q53Q1jUzkDGemrHJadcewBxXcrJ12oinAai0sdQmB59gMKIPgVPqS8q%2F5PmkYx1yTeSD8JqiVnbGn45x7qchXk%2Fgztwf%2BcauR8TrZyDfzIU4KHz7VNEjcMg7iW3E8rnTRZH1V3E04t1ycFhN4JMRqEZU2goaE3aFpUpVPM95NaT5IEGQcCMbCgEC0s9bVKyDCNAQ1rAxPPsEMgbcUn5QFOitG0Xp0rkDuvAwwZS2zgY6mAH0WR7LJvgid0w4vSTuXAzwA18TD%2B3MzKfBW3scgi0zVwK6k8JeH9PUnQstiAi6t7O4gGiBeSO693nYzDiLCPSOuZIxAwSZqHglbGH%2F1Ktvpv8JmyKfbt5v6u%2FV09d65s1Fx52rnNXP8s%2F1a0ZDF19pGI%2F6aOPLwn8T6CY%2Btv9F6fCZJP5Lly6AtCY%2FVrV8lWbmEImqQWbbDQ%3D%3D&Expires=1775081492) - # Stateful Rotor Implementation Reference: Swift 6 / Rust FFI PKM with Local + Cloud AI

**Fused kno...

20. [Subregions in the ventromedial prefrontal cortex integrate threat and protective information to meta-represent safety](https://dx.plos.org/10.1371/journal.pbio.3002986) - ...Prediction, Meta-representation, Recognition, and Value Updating. We experimentally manipulated s...

21. [A Decision Architecture for Safety Computations](https://pmc.ncbi.nlm.nih.gov/articles/PMC8035229/) - ... evaluations that focus on the agent's experience, strategies, and ability to control the situati...

22. [Prefrontal meta-control incorporating mental simulation enhances ...](https://www.frontiersin.org/journals/computational-neuroscience/articles/10.3389/fncom.2025.1559915/full) - We present Meta-Dyna, a novel neuroscience-inspired reinforcement learning architecture that demonst...

23. [Distributed neural representations of conditioned threat in the human brain](https://pmc.ncbi.nlm.nih.gov/articles/PMC10933283/) - Detecting and responding to threat engages several neural nodes including the amygdala, hippocampus,...

24. [Fear-Neuro-Inspired Reinforcement Learning for Safe Autonomous Driving](https://www.techrxiv.org/articles/preprint/Fear-Neuro-Inspired_Reinforcement_Learning_for_Safe_Autonomous_Driving/24289108/1/files/42634450.pdf) - ...compared to the baseline agents and perform comparably to 30 certified human drivers, across vari...

25. [[PDF] Multi-Task Alignment Using Steering Vectors - Stanford University](https://web.stanford.edu/class/archive/cs/cs224n/cs224n.1254/final-reports/256908428.pdf) - In this paper, we focus on using multiple steering vectors to align an LLM with specific preferences...

26. [Improving Reasoning Performance in Large Language Models via ...](https://iclr.cc/virtual/2025/poster/30146) - The method allows us to improve performance on reasoning benchmarks and assess how control vectors i...

27. [A Survey of Physical AI: Foundations in OpenUSD, GR00T, VLMs, and the NVIDIA Omniverse Ecosystem](https://ieeexplore.ieee.org/document/11353140/) - Physical Artificial Intelligence (AI), or embodied AI, represents a paradigm shift from purely virtu...

28. [Physical AI: bridging the sim-to-real divide toward embodied, ethical, and autonomous intelligence](https://link.springer.com/10.1007/s44379-025-00050-y)

29. [ResponsibleRobotBench: Benchmarking Responsible Robot Manipulation using Multi-modal Large Language Models](https://arxiv.org/abs/2512.04308) - Recent advances in large multimodal models have enabled new opportunities in embodied AI, particular...

30. [Gemini Robotics: Bringing AI into the Physical World](https://arxiv.org/html/2503.20020v1) - ...Robotics builds on top of the Gemini Robotics-ER model, the second model we
introduce in this wor...

