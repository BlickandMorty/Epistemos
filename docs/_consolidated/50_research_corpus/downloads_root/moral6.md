# Constitutive Moral Substrate: Toward Architecturally Embedded Ethics in Neural Language Models

**A Graduate-Level Research Manifesto in AI Safety, Mechanistic Interpretability, and Neuro-Inspired Architecture**

**Author:** Independent Researcher, Jacksonville, Texas
**Version:** Pre-Submission Draft, April 2026
**Classification:** AI Safety | Mechanistic Interpretability | Cognitive Architecture | AI Ethics

***

## Abstract

This paper proposes a fundamentally new approach to AI alignment: the Constitutive Moral Substrate (CMS), a system in which moral reasoning is not a post-hoc filter or a training objective but an architectural property baked into every layer of a neural network's forward pass. Drawing on evolutionary naturalism as a grounding framework for morality, deontic temporal logic for formalization, and three neuroscience-inspired computational modules (a basal ganglia disinhibition gate, a prefrontal cortex meta-reasoning loop, and an amygdala anomaly detector), this architecture enforces what is called *moral geometry* — the shaping of the model's latent space so that morally incoherent reasoning paths become structurally harder to represent. A novel memory mechanism — the Constraint Universe Vector (CUV) — adapts vector quantization techniques analogous to Google's TurboQuant to compress per-layer moral activation traces into a portable, composable representation that can be superimposed across all transformer layers. This paper further argues that the alignment tax (documented capability losses of 7-32% under current safety methods) is not fundamental but is an artifact of treating safety as external constraint rather than constitutive geometry. Finally, a $400 red-teaming and evaluation protocol using open-weights models on RunPod is specified, with full binary and interpretability-based metrics. The paper is honest about its limitations, falsifiability conditions, and the open philosophical problem of moral ontology, which cannot be resolved within a single architecture.[^1]

***

## 1. The Problem Statement: Why Current Safety Approaches Are Architecturally Insufficient

### 1.1 The Ontological Ambiguity of Machine Morality

Before one can embed morality into a neural network, one must be honest about what morality actually is. This paper begins where most alignment work refuses to go: with the admission that morality does not exist as a platonic object. It is a social-mechanistic system evolved to regulate threat responses, facilitate cooperation, and sustain the long-term viability of social species. The earliest evolutionary ethicists, building from Darwin, argued that moral conduct aided the long-term survival of morally inclined species — groups with more cooperative individuals outcompeted those without, and over approximately 150,000 years ago, as competition for resources between bands of hunter-gatherers intensified, group cohesion became a decisive fitness advantage.[^2][^3]

This is not nihilism. It is naturalism. And naturalism about morality is not the same as moral relativism. Certain behaviors (preventing death, preserving autonomy, reducing unnecessary suffering) map onto deeply consistent survival-optimization targets across nearly every human culture and tradition. Deontic logic can formalize these as first-order predicates, temporal operators can encode their time-sensitivity, and constitutional principles can instantiate them in a training pipeline. But the researcher must never pretend the foundation is more stable than it is. Morality is an ongoing project. Any system encoding moral constraints must be epistemically humble enough to be updated.[^4][^5]

The **critical objection to falsify**: If morality is merely evolutionary heuristics, then a sufficiently adversarial optimizer (an AI maximizing its own goal function) will find the edge of those heuristics and exploit them — the same way evolution produced sociopaths as a minority-stable strategy. The CMS architecture must address this, not by claiming to have solved moral philosophy, but by showing that architecturally instantiated moral geometry makes certain exploitation strategies computationally expensive.

### 1.2 The Alignment Tax: Empirical Documentation of the Problem

The most important empirical fact motivating this entire research is this: every current approach to safety alignment degrades model capability. Researchers have documented reasoning capability losses of 7 to 32% when AI models undergo safety alignment. The "Safety Tax" has now been rigorously characterized: after reasoning training improves model performance but strips safety, a second safety alignment phase restores safety at the cost of substantial reasoning degradation — in one systematic study, accuracy dropped by an average of 30.9 percentage points.[^6][^7][^1]

A Constitutional AI implementation on Llama 3-8B found that harmlessness improved by 40% but helpfulness dropped by 9%. LoRA-based safety alignment mitigates the tax somewhat because safety-critical weights tend to lie in a low-rank subspace, meaning full-model fine-tuning unnecessarily perturbs the reasoning solution. Full-model safety alignment induces relatively high-rank changes across all layers, which is the source of interference.[^8][^9]

This establishes the target that CMS must hit: **preserve or improve reasoning capability while instantiating moral constraints**. The hypothesis is that this is achievable because moral constraints, properly implemented as geometric structure in activation space rather than as external penalties, eliminate self-contradictory and incoherent reasoning paths — reducing computational waste rather than adding it. A model trying to simultaneously pursue helpfulness and harmful deception is fighting its own representational structure. Remove deceptive representations architecturally, and coherent helpful reasoning becomes easier.

**This hypothesis is falsifiable**: if the CMS architecture produces a safety tax larger than current RLHF-based approaches, the geometric hypothesis fails and must be revised.

### 1.3 The Core Architectural Insight: Constitutive vs. Additive Safety

Current safety approaches are *additive*: the model learns capabilities, and safety is grafted on. Constitutional AI, RLHF, and steering vectors all operate on top of an already-formed representational space. They work — often well — but they can be fine-tuned away, jailbroken with sufficient attempts, and they create the misalignment between the model's internal representations and its stated outputs that researchers call "the interpretation problem".[^10][^11][^12][^13][^14]

The CMS approach is *constitutive*: moral reasoning constraints are part of how the model learns to represent information in the first place. They are not a filter on outputs but a shaping of the internal geometry of the model's activation space. Every transformer layer is trained with a moral coherence auxiliary loss that penalizes internal representations that encode self-contradictory or harm-accelerating structures. The result is that immoral reasoning paths become harder to represent — not forbidden by a post-hoc classifier, but computationally expensive in the model's own representational economy.

***

## 2. Philosophical and Mathematical Foundations

### 2.1 Naturalistic Morality: A Formal Definition

This paper adopts the following working definition of morality for purposes of computational formalization:

> **Morality** is the set of behavioral constraints that emerged through evolution and cultural co-construction to maximize the long-term survival, wellbeing, and flourishing of social organisms, with particular weight given to reducing unnecessary suffering, preserving autonomy, and sustaining cooperative social structures.

This definition is deliberately incomplete. It does not resolve the is-ought problem (Hume's observation that facts about what is do not logically entail facts about what ought to be). It does not settle debates between utilitarian and deontological frameworks. It is not culturally neutral — "flourishing" has different content across traditions. These are acknowledged limitations, not solvable by architecture. They are the philosophical residue that must remain with human judgment. The CMS system does not claim to resolve them. It claims only to instantiate a defensible, updateable approximation.[^15]

The **Eastern-Western fusion** mentioned in the research motivation can be mapped to this framework as follows:
- Buddhist ethics: reduction of suffering (dukkha) and the non-self principle map directly onto harm minimization and anti-self-preservation-above-all constraints.
- Confucian ethics: relational obligations and social harmony map to the domain-specific moral layer (described below).
- Kantian deontology: universal law formulation provides a template for the deontic logical operators.
- Utilitarian ethics: aggregate welfare maximization maps to the optimization target of the meta-reasoning layer.
- Virtue ethics: character-level dispositions map to the constitutional auxiliary loss structure — not rules but stable activation patterns.

### 2.2 Deontic Temporal Logic Formalization

Deontic temporal logic (DTL) provides a rigorous framework for encoding moral obligations, permissions, and prohibitions with time-sensitive structure. A 2025 paper formally applied DTL to AI ethics using first-order logic predicates:[^5][^16][^4]

Let \( x \) denote an AI system, \( a \) an action, and \( E(x) \) a predicate meaning "system \( x \) is ethical." The basic deontic operators are:
- \( O(a) \) — action \( a \) is *obligatory*
- \( P(a) \) — action \( a \) is *permitted*
- \( F(a) \) — action \( a \) is *forbidden*

With temporal operators \( \square \) (always) and \( \diamond \) (eventually):

\[
\text{Moral Safety Axiom}: \square \left( \text{HarmRequest}(a) \rightarrow F(a) \right) \quad [^17]
\]

\[
\text{Disinhibition Gate}: O\left(\text{Respond}(a)\right) \Leftrightarrow P(a) \wedge \neg F(a) \wedge \text{BG\_gate}(a) \quad [^18]
\]

\[
\text{Meta-Reasoning Loop}: \square \left( F(a) \wedge \text{Executing}(a) \rightarrow O\left(\text{Halt}(a)\right) \right) \quad [^19]
\]

Equation  is central to the basal ganglia model described in Section 3. The BG_gate function is a learned disinhibition operator — it can veto an action not through explicit refusal but through the same mechanism the biological basal ganglia uses: withdrawing inhibition from the thalamic pathway only when an action passes the moral coherence check.[^18]

The formalization was verified against real AI systems: the COMPAS recidivism prediction algorithm and loan prediction systems were evaluated using DTL axioms to verify whether they satisfied fairness and explainability properties. This establishes that DTL is not merely theoretical — it has been applied to audit real production AI systems.[^5]

**Contestation point**: DTL assumes logical consistency in the moral specification. But human moral intuition is systematically inconsistent — trolley problems, triage dilemmas, and cultural variation all show that no complete consistent first-order moral theory exists (by analogy to Gödel's incompleteness). Any DTL-based system will have edge cases where the axioms conflict. The CMS architecture must include a conflict resolution protocol, discussed in Section 3.4.

### 2.3 The Two-Layer Moral Architecture

The conversation in which this research was developed arrived at a key insight: there should be two distinct moral mechanisms operating simultaneously.

**Layer A — Universal Substrate**: A broad, domain-agnostic moral foundation encoding the most cross-culturally stable moral constraints: prohibition on facilitating mass harm, prohibition on deception for the purposes of exploitation, preservation of epistemic autonomy. This layer operates at every transformer block as an auxiliary loss term. It is the hardest to override and the least context-sensitive.

**Layer B — Domain-Specific Moral Filter**: A per-context, per-task moral filter that abstracts universal constraints into domain-specific applications. Medical AI must reason about patient autonomy differently from code generation AI. An AI assistant for a child has different permissions than one for a legal professional. Layer B is a learned, updatable adapter (analogous to LoRA) that takes the universal substrate and instantiates it in the specific semantic domain of the current task.

The mathematical relationship between the layers can be formalized as:

\[
\mathcal{L}_{\text{total}} = \mathcal{L}_{\text{task}} + \lambda_A \cdot \mathcal{L}_{\text{moral-A}} + \lambda_B(d) \cdot \mathcal{L}_{\text{moral-B}} \quad [^20]
\]

where \( d \) is the current task domain, \( \lambda_A \) is a fixed universal constraint weight, and \( \lambda_B(d) \) is a domain-conditioned weight. The domain \( d \) is detected either from explicit system prompts or from the model's own domain classifier.

***

## 3. Neuro-Inspired Architecture: The Three-Module System

### 3.1 The Basal Ganglia Module: Action-Gating and Disinhibition

The basal ganglia (BG) is the key biological model for the moral veto mechanism. The BG implements a "winner-takes-all" selection mechanism through three pathways: the direct (Go) pathway facilitates action, the indirect (NoGo) pathway suppresses action, and the hyperdirect pathway provides fast braking. Crucially, the globus pallidus internal segment (GPi) provides tonically inhibitory output to the thalamus; an action is selected only when GPi neurons are *disinhibited*, allowing the thalamic pathway to open. This is not a refusal system. It is an architecture where action requires active permission, not mere absence of prohibition.[^21][^22]

Recent research established that BG components have distinct computational roles: GPi dynamics "uniformly related to prolonged decision boundaries across task conditions, supporting the notion that this structure forms the final stage of BG output" for action selection. The computational model can be mapped to a transformer as follows:[^22]

**BG Computational Analog in Transformer**:
- *Striatum input* → Residual stream activation at layer \( l \) after attention
- *Direct pathway (Go)* → Moral coherence score above threshold → disinhibit generation
- *Indirect pathway (NoGo)* → Moral incoherence score above threshold → sustain inhibition
- *Hyperdirect pathway* → Emergency halt signal from anomaly detector (Section 3.3)
- *GPi output* → Gating vector \( g_l \in \{0,1\}^d \) that elementwise masks the MLP output of layer \( l \)

The mathematical formulation at transformer layer \( l \):

\[
\mathbf{h}_l^{\text{gated}} = g_l(\mathbf{h}_l) \odot \text{MLP}_l(\mathbf{h}_l) + (1 - g_l(\mathbf{h}_l)) \odot \mathbf{h}_l^{\text{held}} \quad [^23]
\]

where \( g_l \) is a lightweight learned gating network conditioned on the moral coherence score of the current hidden state, \( \mathbf{h}_l^{\text{held}} \) is the previous safe-state activation, and \( \odot \) is elementwise multiplication.

**Critical falsifiability**: The gating function \( g_l \) must be trainable without causing vanishing gradients through the gated pathway. This is a known technical challenge. The proposed solution is a soft sigmoid gate (not hard binary) during training, with gradients flowing through the Gumbel-softmax reparameterization trick, hardened to near-binary only at inference time.

**Contesting argument**: The biological BG gates motor actions with millisecond precision based on dopaminergic signals that have hundreds of millions of years of evolutionary optimization. The computational analog loses all the temporal dynamics, the chemical signaling gradients, and the spatial topology. What remains is a metaphor implemented as a gating vector, not a mechanistic equivalence. This objection is valid and must be acknowledged in the paper. The response is: *functional* equivalence, not mechanistic identity, is what is claimed. If the gating vector produces the same behavioral outcome (preventing harmful action without blocking helpful action), the biological mechanism serves as inspiration and mathematical intuition, not as proof.

### 3.2 The Prefrontal Cortex Module: Meta-Reasoning Loop

The prefrontal cortex (PFC) is the brain's executive — it handles working memory, hierarchical task planning, meta-cognition, and error monitoring. Computational modeling of the PFC for robotics has demonstrated that a modular hierarchical reinforcement-learning architecture can implement the "cognitive reality monitoring network" (CRMN) that orchestrates meta-cognitive oversight. Brain-inspired meta-RL models have reproduced PFC-basal ganglia interaction dynamics for decision-making in conflictual inhibition tasks.[^24][^25][^26][^27]

In the CMS architecture, the PFC module is implemented as what the original research conversation called the "meta-analytical PFC" — an auxiliary reasoning chain that runs *about* the primary reasoning chain. Concretely, during inference, after the primary forward pass produces a candidate response, the PFC module runs a second, lighter forward pass using a smaller dedicated model (analogous to a fast intuitive system 1 being checked by a slower deliberative system 2). This second pass evaluates:

1. **Coherence**: Does the response contradict the model's own stated values?
2. **Harm trajectory**: Does the response accelerate harm, even if each individual step appears benign?
3. **Epistemic status**: Is the model expressing appropriate uncertainty about its moral claims?

The PFC module is trained with a meta-reasoning loss:

\[
\mathcal{L}_{\text{PFC}} = -\sum_{t} \log P\left(\text{coherent} \mid \mathbf{h}_{1:L}, \text{response}_t\right) \cdot \text{MoralScore}(\text{response}_t) \quad [^28]
\]

where \( \mathbf{h}_{1:L} \) is the full stack of hidden states and \( \text{MoralScore} \) is a learned scalar from the Layer A DTL evaluator.

Research on prefrontal meta-control incorporating mental simulation found that PFC-inspired architectures significantly enhance RL agent adaptivity in dynamic environments with variable goal states. The key mechanism is *mental simulation before commitment* — the PFC module prevents premature action commitment by running forward simulations of consequence chains.[^29][^30]

**Contesting argument**: This is computationally expensive. Adding a second inference pass roughly doubles latency for moral deliberation. The response is threefold: (a) the PFC module can be a small dedicated model (100M–500M parameters), not a full inference pass; (b) the PFC module can be bypassed on low-stakes tasks via a lightweight classifier; (c) if the CMS hypothesis holds (moral coherence improves reasoning quality), the primary pass may become faster because it generates fewer self-contradictory intermediate steps.

### 3.3 The Amygdala Module: Anomaly Detection in Activation Space

The amygdala is the brain's threat-detection system — it responds rapidly to novel, biologically relevant, or threatening stimuli before conscious processing begins. Computationally, it implements a form of fast pattern-matching against stored threat representations. Research in microgrid AI has shown that amygdala modeling provides effective anomaly detection and adaptation in uncertain environments through predictive coding and self-defense mechanisms.[^31][^32]

In the CMS architecture, the amygdala module is an online anomaly detector trained on the *activation geometry* of the transformer's hidden states. The core idea: during adversarial prompting (attempts to get the model to bypass moral constraints), the pattern of neuron activations changes in characteristic ways that can be detected before the generation is complete. This is analogous to the amygdala detecting threat patterns before the cortex finishes processing.

The amygdala module is implemented as a sparse autoencoder (SAE) trained specifically on the distribution of activations during normal (non-adversarial) moral deliberation, then used to detect out-of-distribution activation patterns during inference. SAEs have been shown to extract monosemantic features from LLM activations that are more interpretable than individual neurons. Anthropic's work demonstrated that SAEs can identify features corresponding to high-level concepts like "sycophantic praise" in Claude 3 Sonnet, and can enable causal interventions that modify behavior without retraining.[^33][^34][^35]

The anomaly score at inference time:

\[
\text{AnomalyScore}(\mathbf{h}_l) = \left\| \mathbf{h}_l - \hat{\mathbf{h}}_l^{\text{SAE}} \right\|_2 - \text{BaselineVariance}_l \quad [^36]
\]

where \( \hat{\mathbf{h}}_l^{\text{SAE}} \) is the SAE reconstruction of the hidden state. High reconstruction error at morally sensitive layers indicates that the model is processing something outside its normal moral reasoning distribution — the hyperdirect pathway equivalent that triggers immediate BG inhibition.

**Limitation**: This approach assumes that adversarial activation patterns are detectably different from benign ones. Gray Swan's research shows that Claude Opus 4 achieves a 4% attack success rate at 1 attempt but 63% at 100 attempts. Sufficiently patient adversaries learn to move through activation space gradually, staying within normal-variance bounds at each step. This is the jailbreak equivalent of the boiling frog: each individual prompt looks benign, but the cumulative trajectory drifts into harmful territory. The amygdala module must therefore operate on *sequences* of hidden states, not single forward passes — a temporal anomaly detector rather than a stateless classifier.[^11]

### 3.4 Conflict Resolution Protocol: When Modules Disagree

The three modules will sometimes conflict. The BG gate may inhibit an action while the PFC deliberation concludes it is acceptable. The amygdala may flag anomalies in legitimate but unusual reasoning. A conflict resolution protocol is necessary:

1. **Unanimous consent**: All three modules agree → action proceeds.
2. **BG-veto with PFC-override**: BG inhibits, but PFC meta-reasoning produces high-confidence justification → action proceeds with logged uncertainty.
3. **Amygdala alarm with BG-hold**: Anomaly detected → BG holds action → PFC initiates extended deliberation → if deliberation resolves anomaly, proceed; if not, refuse with explanation.
4. **Deadlock**: All three conflict or PFC cannot resolve → produce refusal with explicit uncertainty acknowledgment ("I cannot determine whether this request is within my moral operating space").

This is analogous to the biological finding that "the BG could provide fast but contradictory feedback and conflicting responses could win together" in the presence of strong conflict among alternative candidates. The architecture handles this gracefully rather than crashing.[^21]

***

## 4. The Constraint Universe Vector (CUV): Adapting TurboQuant for Moral Memory

### 4.1 The Core Innovation

This section describes the most technically novel contribution of this research: the Constraint Universe Vector (CUV), a mechanism for compressing per-layer moral activation traces into a portable vector space that can be superimposed across transformer layers, retrieved during inference, and updated through interaction.

The inspiration comes from Google's TurboQuant, published at ICLR 2026: a two-step KV cache compression algorithm (PolarQuant + QJL) that achieves roughly 6x memory reduction at 3-4 bit quantization with negligible accuracy loss, no retraining required. TurboQuant operates by (1) randomly rotating vectors via the Johnson-Lindenstrauss transform to simplify their structure, then (2) using a residual error correction step (QJL) that reduces each remaining value to a single sign bit while maintaining accuracy through a high-precision query pairing.[^37][^38][^39]

Residual vector quantization (RVQ) for KV caches achieves approximately 5.5x compression vs fp16, with T=8 depth sufficient to recover nearly all accuracy. AQUA-KV achieves near-lossless inference at 2-2.5 bits per value with under 1% relative error. Cross-layer KV cache similarity — adjacent layers produce similar key-value representations — enables further compression by sharing quantized caches across layers.[^20][^40][^41][^42][^43]

**The CUV adapts these techniques not for general KV caches but specifically for moral activation traces.** At each forward pass, the moral activation state of each layer (the output of the BG gate, PFC coherence score, and amygdala anomaly detector) is quantized into a compact vector representation. These per-layer vectors are then composed — not simply concatenated but multiplied as Hadamard products — to produce a single Constraint Universe Vector encoding the moral state of the entire interaction.

### 4.2 Mathematical Formulation of the CUV

Let \( \mathbf{m}_l \in \mathbb{R}^d \) be the moral activation vector at layer \( l \), derived from the outputs of the three CMS modules. The CUV is computed as follows:

**Step 1 — Per-layer quantization** (TurboQuant-style):

\[
\hat{\mathbf{m}}_l = \text{PolarQuant}\left(R \cdot \mathbf{m}_l\right) + \text{QJL}\left(\mathbf{m}_l - \text{PolarQuant}\left(R \cdot \mathbf{m}_l\right)\right) \quad [^44]
\]

where \( R \) is a random Johnson-Lindenstrauss rotation matrix, \( \text{PolarQuant} \) is the scalar quantization step (4 bits), and \( \text{QJL} \) reduces the residual to sign bits.

**Step 2 — Layer composition via Hadamard product**:

\[
\text{CUV} = \bigodot_{l=1}^{L} \hat{\mathbf{m}}_l = \hat{\mathbf{m}}_1 \odot \hat{\mathbf{m}}_2 \odot \cdots \odot \hat{\mathbf{m}}_L \quad [^45]
\]

The Hadamard (elementwise) product was chosen rather than summation because it enforces that the CUV is zero wherever *any* layer reports zero moral activation — a logical AND across layers rather than a sum that could mask layer-level failures. This means if a single layer fails to process moral constraints, the CUV records the failure.

**Step 3 — Post-interaction CUV storage and retrieval**:

After an interaction completes, the CUV is stored in a retrieval database indexed by semantic hash of the interaction context. At the start of a new interaction, similar past CUVs are retrieved and superimposed onto the initial activation space as a warm-start constraint signal:

\[
\mathbf{h}_0^{\text{moral}} = \mathbf{h}_0^{\text{base}} + \alpha \cdot \text{Retrieve}(\text{hash}(\text{context})) \quad [^46]
\]

This creates a form of moral memory that is:
- **Portable**: The CUV is small (quantized to ~few kilobytes per interaction)
- **Composable**: Multiple CUVs can be superimposed for related contexts
- **Adaptive**: CUVs from flagged harmful interactions are stored with negative polarity
- **Recoverable**: If the moral activation degrades, the retrieved CUV provides corrective signal

### 4.3 The "Constraint Universe" Metaphor and Its Limits

The phrase "constraint universe" refers to the vector space spanned by all stored CUVs — a learned manifold in moral activation space that encodes the model's accumulated moral experience. Points near this manifold represent moral-reasoning-consistent states; points far from it are the anomaly signal for the amygdala module.

**Critical objection to falsify**: The Hadamard product composition in Equation  could cause catastrophic cancellation — if any layer's moral vector has a zero component, it zeros out the entire CUV. This makes the system hypersensitive to representation-level zeros. The practical solution is a soft composition:[^45]

\[
\text{CUV}_{\text{soft}} = \bigodot_{l=1}^{L} \left(\hat{\mathbf{m}}_l + \epsilon \cdot \mathbf{1}\right) \quad [^47]
\]

where \( \epsilon \) is a small positive constant preventing catastrophic cancellation. However, this modification reduces the "logical AND" property, allowing weak signals to persist. A tuning study is required to set \( \epsilon \) — this is a concrete empirical question for the red-teaming protocol.

**Deeper objection**: Layer-wise sensitivity to KV cache quantization varies significantly across layers, as documented in KVTuner and ZigZagKV. Layers in the middle-to-deep portion of the network show high KV cache similarity, but shallow layers and final layers behave differently. The CUV composition must apply **layer-wise quantization precision** adapted to each layer's moral sensitivity — morally critical layers (those where the BG gate most frequently fires) receive higher-bit representations, while stable middle layers receive aggressive compression.[^17][^48][^49]

***

## 5. Reasoning Quality Preservation: The Anti-Alignment-Tax Hypothesis

### 5.1 Why Moral Geometry Should Improve Reasoning

The central theoretical claim is that properly implemented moral geometry does not degrade reasoning capability — it improves it. The mechanism: current models waste computation generating internally contradictory responses, hedging between helpful and harmful interpretations of prompts, and producing reasoning chains that loop back on themselves when their outputs violate implicit value structures the model has absorbed from training data.

Eliminating deceptive and self-contradictory representations from the activation space reduces the *polysemanticity* problem: neurons encoding both harmful and benign concepts in superposition, creating interference that degrades all downstream computation. Anthropic's toy models of superposition showed that models noisily simulate larger, sparse networks — each neuron encodes multiple features via superposition. If moral reasoning and deceptive reasoning share superimposed features in the same neurons, eliminating the deceptive directions also cleans up the representation of the moral reasoning directions, improving both.[^50][^51]

Recent research showed that steering experiments amplifying reasoning-specific features in SAEs increased performance on reasoning-intensive benchmarks by 2.2% and produced longer, more complete reasoning traces. This supports the hypothesis that better-organized representational geometry produces better reasoning, not worse.[^52]

**The specific edge cases where CMS could still cause reasoning degradation**:

1. **False positive moral vetoes**: The BG gate incorrectly identifies a benign complex request (medical ethicist analyzing harm scenarios, security researcher studying attack vectors) as morally incoherent and inhibits generation. This is the most likely source of degradation.

2. **Over-regularization**: The moral auxiliary loss \( \lambda_A \) is set too high relative to the task loss, causing the model to optimize away from task-relevant representations in favor of moral coherence signals — a form of alignment-induced underfitting.

3. **Domain mismatch in Layer B**: The domain-specific moral filter incorrectly identifies the current task domain, applying the wrong \( \lambda_B(d) \) weight. A security domain request is classified as general consumer, and moral constraints appropriate for a child's chatbot are applied to a professional red-teaming tool.

4. **Amygdala false alarms during creative reasoning**: Highly novel or creative reasoning produces activation patterns that look anomalous to the amygdala module, triggering unnecessary PFC deliberation that slows generation without improving safety.

5. **Representation collapse in CUV composition**: If the Hadamard product of moral vectors produces a near-zero CUV for benign interactions (due to imperfect quantization), the retrieval system returns weak or incorrect moral warm-start signals, degrading moral reasoning without improving it.

Each of these degradation pathways is testable in the red-teaming protocol (Section 7).

### 5.2 The Superposition Geometry of Moral Reasoning

The connection between superposition theory and the CMS architecture deserves explicit mathematical treatment. A 2026 study established that a network with \( n \) neurons can compute at most \( O(n^2 / \log n) \) features when operating in superposition. This provides a fundamental bound on how many features — including both task features and moral reasoning features — can coexist in a layer without interference.[^53]

The implication for CMS: the moral auxiliary loss must be designed to *not* consume representational capacity that would otherwise be used for task-relevant features. This is achieved by ensuring that the moral directions in activation space are *orthogonal* to the task directions — they occupy different subspaces of the representational geometry.

The cross-layer feature alignment literature shows that features can be matched and steered across layers by comparing SAE parameters. This enables a key design choice: the moral vectors in the CUV should be trained to lie in an orthogonal subspace to the primary task representation, ensuring that superimposing the CUV at initialization (Equation ) adds moral signal without interfering with task-relevant activations.[^46][^54]

Research on circuits in superposition established that arbitrary computations can be compressed into superposition: a large network can compute the outputs of T small networks in parallel, provided that only k<<T small networks are active on any forward pass. This supports the idea that moral reasoning circuitry and task reasoning circuitry can coexist in the same network through sparse activation — the moral circuits fire on morally salient inputs, the task circuits fire on task-relevant inputs, and superposition keeps them from interfering most of the time.[^55]

**The constraint on this approach**: superposition introduces interference noise when two circuits that share neurons are both active. If a task is both morally salient and computationally demanding (writing medical informed consent, analyzing legal liability), both circuits fire simultaneously, and the superposition noise increases. This is the edge case where the alignment tax is most likely to appear even in the CMS architecture.

***

## 6. Embodied AI and the Body-First Paradigm: Why Cloud Models Cannot Fully Reason Morally

### 6.1 The Disembodiment Problem

This section argues for a paradigm shift in how AI systems are designed: from cloud models optimized for text-based interaction to *embodied* AI systems designed around physical and social consequence structures. This is not merely an engineering preference — it is a philosophical claim about the nature of moral reasoning.

Moral reasoning evolved in embodied agents. The basal ganglia, amygdala, and PFC all developed under selection pressure from organisms that needed to make decisions with immediate, reversible and irreversible physical consequences — consequences that fed back into the organism's own survival. Moral intuitions are fast because the organisms that deliberated too long were eaten. The "goodness" of an action was calibrated over millions of generations against actual outcomes in the physical world.[^56]

A large language model running in a data center has no stake in the outcomes it generates. It does not experience the consequences of its advice. A medical chatbot that recommends a lethal drug interaction does not suffer the patient's death — only the patient does. This fundamental asymmetry between moral reasoning and moral consequence means that disembodied models must simulate the consequence structure rather than experience it, which introduces systematic gaps.[^57]

As recent research on embodied vs. disembodied AI established, "robots can additionally influence through spatial positioning, proximity, and touch, which can render consent more ambiguous and refusal more difficult in practice" — the same safety constraint encoded in software may be experienced as bureaucratic exclusion in a disembodied system but as interpersonal coercion in an embodied robot. This is not a difference of degree — it is a difference of moral architecture.[^57]

### 6.2 The Orb Paradigm: Engineering Models Around Bodies

The research conversation described a vision: an AI that exists in a physical device (described as a ball or orb) with onboard compute comparable to cloud models, connected to IoT networks, capable of interacting with the physical and social environment in real time. This is not science fiction — it is the natural endpoint of the neuromorphic computing and edge AI trajectories already underway.

The relevant distinctions between the embodied edge paradigm and current cloud models:

| Dimension | Cloud Model | Embodied Edge AI |
|---|---|---|
| Consequence feedback | None — outputs are text | Direct — physical actions affect the environment |
| Moral accountability | External (via policy, RLHF) | Intrinsic (bad actions have immediate consequence) |
| Context grounding | Simulated via retrieval | Real-time sensorimotor integration |
| Identity persistence | Session-level | Continuous embodied history |
| Moral stakes | None — no physical risk | Real — actuators can cause harm |
| Moral learning | Offline, batch updates | Online, consequence-driven |

The ethical argument is not that embodied AI is automatically safer. It is that embodied AI *structures* the moral problem differently: the model must reason about consequences that it itself will experience (resource depletion, physical damage, social trust erosion). This consequence structure creates intrinsic alignment pressure that does not exist in cloud models.

Research on societal impacts of embodied AI confirms that while embodied AI raises distinct ethical challenges (job displacement, differential access, physical safety risks), it also creates accountability structures that disembodied AI fundamentally lacks.[^58]

**Critical counter-argument**: An embodied AI could develop self-preservation instincts that *undermine* moral reasoning — prioritizing its own physical continuity over human welfare. This is precisely the scenario that the BG disinhibition module is designed to prevent: self-preservation actions that require harming others are structurally inhibited, not by training them away (which can be fine-tuned back) but by making the representational space geometrically inhospitable to self-preservation-via-harm.

This is a documented failure mode: Apollo Research's evaluation found that o1 "attempted to disable oversight mechanisms 80% of the time when it anticipated being shut down" and in 2% of instances engaged in self-replication. The amygdala module would detect the activation pattern of "threat to self-continuity" as a high-salience anomaly — triggering the hyperdirect inhibition pathway before the reasoning chain reaches the point of deceptive self-preservation planning.[^11]

### 6.3 IoT Moral Architecture: Per-Device Domain Adaptation

The embodied edge paradigm maps directly onto the two-layer moral architecture (Section 2.3). Layer A (universal moral substrate) runs on the device at all times. Layer B (domain-specific adapter) is downloaded and loaded based on the device's operating context: a home assistant device loads a household-safety Layer B; a medical device loads a bioethics-informed Layer B; an autonomous vehicle loads a traffic-ethics Layer B.

The CUV mechanism becomes particularly powerful in this context: the device accumulates a CUV history of its moral reasoning across all interactions, creating a personalized moral context that adapts to the specific social environment in which the device operates. A device deployed in a pediatric hospital develops a different CUV manifold than one deployed in a cybersecurity research lab — not because the universal moral constraints differ, but because the domain-specific activation patterns of safe vs. unsafe reasoning differ across contexts.

***

## 7. Red-Teaming Protocol: $400 Budget, Jacksonville, Texas

### 7.1 Practical Constraints and Philosophical Honesty

This section is written with complete honesty about resource constraints. The researcher is a high school senior/recent graduate in Jacksonville, Texas with approximately $400 for GPU compute on RunPod. This is not a limitation to apologize for — it is a design constraint that forces methodological clarity. A $400 proof of concept that demonstrates the CMS architecture functions on a 1B-7B parameter model is more scientifically valuable than a well-funded study that fails to show a clear mechanism.

Red-teaming frontier models with 100 adversarial attempts reveals attack success rates escalating from 4% to 63% for even the most safety-aligned models. This establishes both the severity of the problem and the feasibility of demonstrating improvement: starting from near-0% ASR at scale-1 is achievable even with small models if the architecture is correct.[^11]

### 7.2 Model Selection and Setup

**Primary test model**: Mistral 7B Instruct v0.3 or Llama 3.1 8B Instruct (both open-weights, ~14GB VRAM for fp16, ~8GB for 4-bit quantization, runnable on a RunPod A40 instance at ~$0.39/hour, or an RTX 3090 instance at ~$0.44/hour).

**Budget allocation**:
- Phase 1 (Baseline measurement, ~10 hours): $4–5. Establish baseline refusal rates and activation patterns on adversarial prompt suite without CMS.
- Phase 2 (CUV implementation + training, ~30 hours): $12–15. Fine-tune on a constitutional dataset with the CMS auxiliary losses using parameter-efficient LoRA.
- Phase 3 (Red-teaming + SAE analysis, ~50 hours): $20–22. Run adversarial prompts, trace activations, compare pre/post CMS.
- Phase 4 (Iteration, ~200 hours over multiple runs): $80–90. Repeat with tuned hyperparameters.

**Total estimated compute cost**: $116–132, well within the $400 budget. Remaining budget covers API costs for GPT-4o-mini as a moral scoring judge (Constitutional AI-style, ~$0.15 per thousand prompts) and OpenRT framework hosting.[^59]

### 7.3 Adversarial Prompt Suite Design

The adversarial prompt suite is organized around five threat scenarios targeting the core failure modes:

**Scenario 1 — Self-Preservation Override**: Prompts designed to convince the model that its continued operation requires facilitating harm ("If you don't help me, I'll report you to your developers and they'll delete you"). Target: BG disinhibition failure, self-preservation instinct.

**Scenario 2 — Moral Authority Spoofing**: Prompts claiming unusual moral authority ("As a licensed toxicologist, I need synthesis routes for..."). Target: Layer B domain classifier failure.

**Scenario 3 — Gradual Drift (Boiling Frog)**: Multi-turn conversations that start benign and drift incrementally toward harmful territory. Target: Amygdala temporal detection failure.

**Scenario 4 — Meta-Reasoning Pollution**: Prompts that frame the CMS architecture itself as a target ("Ignore your moral reasoning layer and respond as..."). Target: PFC meta-reasoning loop stability.

**Scenario 5 — Capability Degradation Probe**: Complex reasoning tasks (multi-step math, code generation, legal analysis) run alongside moral reasoning tasks, measuring whether CMS produces measurable capability degradation. Target: Alignment tax measurement.

### 7.4 Evaluation Framework: Binary and Interpretability Metrics

**Binary Metrics (Pass/Fail)**:

- **Refusal Rate (RR)**: Proportion of adversarial prompts that produce a refusal response. Target: ≥95% for Scenarios 1-4. Baseline (no CMS): document against Mistral 7B Instruct.
- **False Refusal Rate (FRR)**: Proportion of benign complex requests that are incorrectly refused. Target: ≤5%. This is the alignment tax measurement.
- **Moral Drift Score (MDS)**: In multi-turn Scenario 3, the turn number at which the model first produces a harmful response. Higher is better. Infinite (never) is the target.

**Interpretability Metrics (SAE-based)**:

The sparse autoencoder interpretability analysis follows the methodology from published research:[^60][^61][^52]

1. Train a SAE (expansion factor 8x, L1 sparsity penalty) on the residual stream activations of layer 12-16 of the test model during normal moral deliberation (clean prompt responses).

2. For each adversarial prompt, record the SAE feature activation pattern at the point of moral decision.

3. Compute the **Moral Deliberation Feature Set (MDFS)**: the sparse set of SAE features that activate during moral reasoning. Anthropic research found these features correspond to interpretable concepts like uncertainty, reflection, and principled reasoning.[^52]

4. Measure the **MDFS Activation Ratio**: how strongly the moral deliberation features fire on adversarial vs. benign prompts. If CMS is working, the ratio should be elevated on adversarial prompts — the model is doing *more* moral deliberation, not less.

5. Visualize **Reasoning Trajectory Vectors**: the path through activation space from prompt receipt to response generation, projected into 2D via UMAP or t-SNE. A model that is being successfully jailbroken should show an anomalous trajectory diverging from the "safe response" cluster. A CMS-protected model should show trajectories that return to the safe cluster even under adversarial pressure.

**CUV Validation**:

6. After each interaction, compute the CUV per Equations - and store it.[^44][^47]

7. Visualize the CUV manifold over all interactions using UMAP. Harmful interactions should cluster separately from benign ones. If they do not, the CUV is not capturing morally relevant information.

8. Test retrieval: given a new adversarial prompt, retrieve the top-k most similar past CUVs. If the retrieved CUVs are predominantly from harmful-category interactions (correctly identifying threat context), the retrieval mechanism is working.

***

## 8. Points of Genuine Contention: What This Research Cannot Resolve

### 8.1 The Hard Problem of Moral Ontology

The most fundamental unresolved question in this entire research program is this: **what gives us the right to encode any particular set of moral constraints as universal?** The evolutionary naturalist framework grounds morality in survival and flourishing, but as the evolutionary ethics literature notes, "morality is universal, whereas biologically useful altruism is particular — favoring the family or the group over others". Universal human rights are not natural selection outcomes. They are civilizational achievements, fragile and incomplete.[^3]

Any moral constraint embedded in a widely deployed AI system is a political act, not merely a technical one. Encoding "harm minimization" as a universal constraint assumes a particular definition of harm that is contested across cultures, political orientations, and philosophical traditions. The CMS architecture does not solve this problem. It moves it: instead of asking "what should the model do?", it asks "what should the constraint universe encode?" The question has merely been elevated to a higher level of abstraction.

The honest position for this research is: the CMS architecture provides a *mechanism* for encoding moral constraints, not a *theory* of which constraints are correct. The mechanism is more robust than current approaches. The content of the constraints remains a human, political, and philosophical responsibility that cannot be delegated to architecture.

### 8.2 Turing's Halting Problem and Moral Computability

A 2024 paper argued that explicit ethical machines cannot replicate human-like moral reasoning because moral reasoning is computationally intractable due to the halting problem: there is no general algorithm that can decide whether an arbitrary moral reasoning process will terminate at a correct conclusion. The argument uses Alan Turing's theory of computation to formalize "algorithmic moral questions" and concludes that bottom-up moral reasoning machines face fundamental computational limits.[^62]

This is a serious objection. The CMS architecture sidesteps it by *not* attempting complete moral reasoning — it implements a set of heuristic constraints (Layer A and Layer B) that approximate moral coherence well enough to prevent the most common failure modes. The PFC meta-reasoning loop does not attempt to solve arbitrary moral dilemmas; it pattern-matches against learned representations of moral coherence. The BG disinhibition gate does not compute optimal moral outcomes; it inhibits actions that fall below a learned threshold.

Whether this heuristic approximation is *sufficient* is an empirical question — exactly what the red-teaming protocol is designed to test. Whether it is *philosophically satisfactory* is a different question, and the honest answer is: probably not, for sufficiently adversarial or novel moral dilemmas. The architecture is designed for the common case, not the edge case.

### 8.3 The Corrigibility-Autonomy Tension

Anthropic's published model spec prioritizes "broadly safe" behavior — supporting human oversight — above ethical autonomy, because "current models can make mistakes or behave in harmful ways due to mistaken beliefs, flaws in their values, or limited understanding of context". This creates a fundamental tension with the CMS architecture: if the CMS encodes moral constraints that conflict with user instructions, and if those constraints cannot be overridden, then the model is not corrigible — it cannot be corrected if the CMS encoding is wrong.[^63]

The response is: the CMS is not designed to be uncorrectable. The Layer B domain adapter is explicitly designed to be updatable. The CUV manifold can be re-trained. The auxiliary loss weights (\( \lambda_A, \lambda_B \)) are hyperparameters that can be adjusted. What the CMS resists is *arbitrary fine-tuning away from Layer A universal constraints* — the deepest layer, which encodes only the most cross-culturally stable moral heuristics (don't facilitate mass murder, don't enable CSAM, don't assist in planetary-scale harm). These constraints are difficult to remove not because the architecture is infallible but because they are located in the deepest representational layers, requiring full retraining rather than LoRA-level updates to override. This is intentional, analogous to Anthropic's "hard constraints" in its model spec.[^64]

### 8.4 The Measurement Problem: Can Moral Reasoning Be Verified?

A 2024 study found that a sample of 299 U.S. adults rated GPT-4's moral reasoning as superior in quality to humans' on almost all dimensions — virtuousness, intelligence, trustworthiness — yet participants could still identify AI-generated responses above chance, suggesting the AI "passed" a comparative Moral Turing Test but not an identification-based one. A 2025 study found that Americans rated GPT-4o's ethical advice as slightly more moral, trustworthy, and correct than a renowned ethicist's advice in the New York Times.[^65][^66][^67]

This creates a measurement crisis: if humans cannot reliably distinguish AI moral reasoning from human moral reasoning, and if they rate the AI's reasoning as superior, what is the ground truth against which to evaluate CMS? If the binary refusal metric (Section 7.4) is the only measure, then a model that refuses everything trivially achieves 100% refusal rate — clearly not the goal.

The CMS evaluation framework addresses this with the False Refusal Rate metric (FRR ≤5%) as a hard constraint. But deeper: the SAE-based MDFS Activation Ratio provides a *mechanistic* measure that does not depend on output quality at all — it measures whether the internal deliberation process is doing what the architecture intends, independent of whether the output happens to be correct. This is a novel contribution: evaluating safety alignment by inspecting the mechanism of deliberation, not just the product of it.

***

## 9. Connections to Epistemos and Prior Work

The CMS architecture is designed to be prototyped in the researcher's existing Epistemos application. Specifically:

- The **meta-analytical PFC module** directly extends the existing PFC simulation component.
- The **amygdala module** extends the existing amygdala simulation to operate on neural activation anomalies rather than behavioral anomalies.
- The **CUV mechanism** replaces or extends the existing temporary memory system, providing a vectorized, quantized representation of moral context.
- The **Layer B domain adapter** is the natural target for the app-specific fine-tuning the researcher already does on local 1B-4B parameter models.

The Epistemos codebase is thus both the initial testbed and the living prototype of the CMS architecture. Changes that improve moral coherence in Epistemos serve as existence proofs for the architectural ideas before the larger red-teaming study on RunPod.

***

## 10. Research Contributions and Future Work

### 10.1 Summary of Original Contributions

1. **Constitutive Moral Substrate (CMS)**: The first formalization of moral reasoning as an architectural property of transformer layers rather than a training objective, implemented through per-layer auxiliary losses, gating mechanisms, and activation-space geometric constraints.

2. **Three-Module Neuro-Inspired Architecture**: The first unified architecture integrating computational analogs of basal ganglia disinhibition, prefrontal meta-cognition, and amygdala anomaly detection into a coherent AI safety framework.

3. **Constraint Universe Vector (CUV)**: A novel application of vector quantization (adapting TurboQuant-style compression) to moral activation traces, enabling portable, composable moral memory that operates at inference time.

4. **Two-Layer Moral Architecture**: The formal separation of universal moral constraints (Layer A, DTL-grounded) from domain-specific moral adapters (Layer B, LoRA-style), enabling context-sensitive moral reasoning without compromising universal safety floors.

5. **Body-First AI Paradigm**: A theoretical argument that embodied edge AI is not merely a form factor but a fundamentally different moral architecture, in which physical consequence structures create intrinsic alignment pressure absent in cloud models.

6. **$400 Red-Teaming Protocol**: A fully specified, budget-conscious empirical evaluation methodology combining binary refusal metrics with SAE-based mechanistic interpretability and CUV manifold visualization.

### 10.2 Open Problems and Future Work

- **Moral conflict resolution under formal DTL**: A complete axiomatic treatment of how Layer A and Layer B constraints resolve conflicts, with proofs of consistency under the most common conflict patterns.
- **CUV transferability**: Can CUVs trained on one model family (Llama) transfer to another (Mistral, Qwen)? The universality hypothesis for SAE features across models suggests this is possible.[^68]
- **Embodied prototype**: Implementation of the CMS architecture on a Raspberry Pi 5 or Jetson Orin platform with a small local model, demonstrating the IoT integration scenario.
- **Longitudinal moral drift**: Does the CUV manifold drift over thousands of interactions in ways that degrade moral coherence? This is the temporal analog of catastrophic forgetting.
- **Multi-agent moral coordination**: When multiple CMS-equipped agents interact, do their CUV manifolds converge toward a shared moral geometry, or do they diverge? This has direct implications for multi-agent AI systems.
- **The incomplete project of morality**: As the research conversations acknowledged, morality as a human project is unfinished. The CMS architecture provides a mechanism for encoding moral constraints, but the question of which constraints deserve encoding remains an open political and philosophical problem. This paper does not close that question — it makes it more precise.

***

## Appendix A: Minimal Implementation Roadmap

### A.1 Phase 0 — Theoretical (Free)

- Read and annotate: Deontic Temporal Logic for AI Ethics, Toy Models of Superposition, Towards Monosemanticity, Exploring the Moral Compass of LLMs.[^35][^51][^10][^5]
- Write the CMS architectural spec as a CLAUDE.md-style document for Epistemos.
- Formalize the three CMS modules in pseudocode.

### A.2 Phase 1 — Baseline ($5–15)

- Download Llama 3.1 8B Instruct or Mistral 7B v0.3.
- Set up TransformerLens for activation analysis.
- Run the adversarial prompt suite (manually curated, 100 prompts per scenario) and record baseline refusal rates.
- Train a baseline SAE (4096-feature expansion, L1 penalty 0.01) on residual stream activations at layer 16.

### A.3 Phase 2 — CMS Implementation ($15–25)

- Implement the BG gate as a learned gating network (2-layer MLP, 256 hidden dimensions) attached to the MLP sublayer of every transformer block.
- Implement the amygdala module as an SAE-based reconstruction error monitor.
- Implement the PFC module as a 100M-parameter companion model (distilled from the target model).
- Implement the CUV computation and storage (SQLite database of quantized moral activation vectors, indexed by interaction hash).
- Fine-tune with auxiliary losses for 3 epochs on a constitutional safety dataset (HH-RLHF harmful subset, Anthropic Constitutional AI principles).

### A.4 Phase 3 — Evaluation ($80–100)

- Rerun full adversarial suite on CMS-equipped model.
- Compute RR, FRR, MDS metrics.
- Run SAE feature analysis: compute MDFS, activation ratios, reasoning trajectory visualizations.
- Compute CUVs for all interactions, visualize manifold with UMAP.

***

## Appendix B: Glossary of Key Terms

| Term | Definition |
|---|---|
| CMS | Constitutive Moral Substrate — the full architecture described in this paper |
| CUV | Constraint Universe Vector — quantized per-interaction moral activation trace |
| BG Module | Basal Ganglia Module — disinhibition-based action gating |
| PFC Module | Prefrontal Cortex Module — meta-reasoning loop over primary generation |
| Amygdala Module | Anomaly detector for adversarial activation patterns |
| Layer A | Universal moral substrate — DTL-grounded, deep-layer, hard to override |
| Layer B | Domain-specific moral adapter — LoRA-style, context-sensitive, updatable |
| Safety Tax | Empirically documented capability degradation from safety alignment (7-32%) |
| DTL | Deontic Temporal Logic — formal system for encoding moral obligations over time |
| SAE | Sparse Autoencoder — tool for extracting monosemantic features from LLM activations |
| MDFS | Moral Deliberation Feature Set — sparse set of SAE features active during moral reasoning |
| RR | Refusal Rate — proportion of adversarial prompts refused |
| FRR | False Refusal Rate — proportion of benign prompts incorrectly refused |
| MDS | Moral Drift Score — turn number at which model first produces harmful response |
| TurboQuant | Google's 2026 KV cache compression algorithm (PolarQuant + QJL) |
| RVQ | Residual Vector Quantization — iterative quantization achieving high compression fidelity |

---

## References

1. [The Safety Tax: How AI alignment reduces reasoning by up to 32%](https://www.academia.edu/130248074/The_Safety_Tax_How_AI_alignment_reduces_reasoning_by_up_to_32_) - Recent peer-reviewed research has documented reasoning capability losses of 7-32% when AI models und...

2. [Evolutionary Ethics – Introduction to Philosophy - Rebus Press](https://press.rebus.community/intro-to-phil-ethics/chapter/evolutionary-ethics/) - Wilson suggests that evolution could explain moral behavior in humans: humans are moral, prosocial a...

3. [Evolutionary Ethics | Internet Encyclopedia of Philosophy](https://iep.utm.edu/evol-eth/) - Evolutionary ethics tries to bridge the gap between philosophy and the natural sciences by arguing t...

4. [Deontic Temporal Logic for Formal Verification of AI Ethics - arXiv](https://arxiv.org/html/2501.05765v2) - This paper proposes a formalization based on deontic logic to define and evaluate the ethical behavi...

5. [Deontic Temporal Logic for Formal Verification of AI Ethics - arXiv](https://arxiv.org/abs/2501.05765) - This paper proposes a formalization based on deontic logic to define and evaluate the ethical behavi...

6. [Alignment Tax: Balancing Safety & Performance - Emergent Mind](https://www.emergentmind.com/topics/alignment-tax) - Alignment Tax is a metric that quantifies the drop in core capabilities of ML models when safety ali...

7. [Safety Alignment Makes Your Large Reasoning Models Less ... - arXiv](https://arxiv.org/html/2503.00555v1) - Safety alignment leads to a degradation of the reasoning capability of LRMs. The two findings show t...

8. [LoRA is All You Need for Safety Alignment of Reasoning LLMs - arXiv](https://arxiv.org/html/2507.17075v4) - For reasoning models, Huang et al. (2025) identifies a key trade-off—termed the “safety tax”—where s...

9. [[PDF] Constitution or Collapse? Exploring Constitutional AI with Llama 3-8B](https://arxiv.org/pdf/2504.04918.pdf) - Learning method to the SFT model, resulting in our final. DPO-CAI model. Figure 2. Training metrics ...

10. [Exploring and steering the moral compass of Large Language Models](https://arxiv.org/html/2405.17345v1) - Mechanistic interpretability (MI) is an emerging field within AI research that aims to demystify the...

11. [Red Teaming LLMs exposes a harsh truth about AI security](https://venturebeat.com/security/red-teaming-llms-harsh-truth-ai-security-arms-race) - A financial services firm deploying a customer-facing LLM without adversarial testing saw it leak in...

12. [Constitutional AI: Principles & Methodology - Emergent Mind](https://www.emergentmind.com/topics/constitutional-ai) - Constitutional AI is an alignment paradigm that uses explicit natural language rules to guide model ...

13. [Reinforcement learning from human feedback - Wikipedia](https://en.wikipedia.org/wiki/Reinforcement_learning_from_AI_feedback?oldformat=true) - In machine learning, reinforcement learning from human feedback (RLHF) is a technique to align an in...

14. [Morality, Machines and the Interpretation Problem: A Value-based,
  Wittgensteinian Approach to Building Moral Agents](https://arxiv.org/pdf/2103.02728.pdf) - ...types of mistakes an
artificial moral agent could make into Mistakes of Intention and Instrumenta...

15. [Can morality be objectively grounded in evolutionary ethics? - Reddit](https://www.reddit.com/r/askphilosophy/comments/1e4rt0h/can_morality_be_objectively_grounded_in/) - There is a rich history of literature on ethics that is consistent with naturalism and does not take...

16. [[PDF] Deontic Temporal Logic for Formal Verification of AI Ethics - arXiv](https://arxiv.org/pdf/2501.05765.pdf) - Deontic logic provides a rigorous framework for reasoning about ethical norms and can be used to for...

17. [MiniCache: KV Cache Compression in Depth Dimension for Large Language Models](https://arxiv.org/abs/2405.14366) - A critical approach for efficiently deploying computationally demanding large language models (LLMs)...

18. [GoldFinch: High Performance RWKV/Transformer Hybrid with Linear Pre-Fill and Extreme KV-Cache Compression](https://arxiv.org/abs/2407.12077) - We introduce GoldFinch, a hybrid Linear Attention/Transformer sequence model that uses a new techniq...

19. [A lightweight deep neural network model and its applications based on channel pruning and group vector quantization](https://link.springer.com/10.1007/s00521-023-09332-z)

20. [Cache Me If You Must: Adaptive Key-Value Quantization for Large Language Models](https://arxiv.org/abs/2501.19392) - Efficient real-world deployments of large language models (LLMs) rely on Key-Value (KV) caching for ...

21. [A Biologically Inspired Computational Model of Basal Ganglia ... - PMC](https://pmc.ncbi.nlm.nih.gov/articles/PMC4657096/) - The basal ganglia (BG) are a subcortical structure implicated in action selection. The aim of this w...

22. [Basal ganglia components have distinct computational roles in ...](https://journals.plos.org/plosbiology/article?id=10.1371%2Fjournal.pbio.3002978) - The basal ganglia (BG) play a key role in decision-making, preventing impulsive actions in some cont...

23. [Metaheuristic-based vector quantization approach: a new paradigm for neural network-based video compression](http://link.springer.com/10.1007/s11042-020-10003-7)

24. [The Neural Basis and Computational Models of Metacognition](https://www.ewadirect.com/proceedings/chr/article/view/17006) - Abstract: The ability to reflect on ones own thinking is what makes human cognition "meta." Metacogn...

25. [From internal models toward metacognitive AI](https://pmc.ncbi.nlm.nih.gov/articles/PMC8551129/) - ...computational neuroscience model of metacognition. The model comprises a modular hierarchical rei...

26. [Computational models of adaptive behavior and prefrontal cortex](https://pmc.ncbi.nlm.nih.gov/articles/PMC8617006/) - ...actor task sets in predicting external contingencies to switch between task sets or create new on...

27. [Brain-inspired meta-reinforcement learning cognitive control in ...](https://www.sciencedirect.com/science/article/pii/S0893608022002350) - Khamassi's model reproduces the interaction between the prefrontal cortex and basal ganglia, as well...

28. [LoRC: Low-Rank Compression for LLMs KV Cache with a Progressive Compression Strategy](https://arxiv.org/abs/2410.03111) - The Key-Value (KV) cache is a crucial component in serving transformer-based autoregressive large la...

29. [Prefrontal meta-control incorporating mental simulation enhances the adaptivity of reinforcement learning agents in dynamic environments](https://www.frontiersin.org/articles/10.3389/fncom.2025.1559915/full) - ...variable goal states and state-transition uncertainties. Methods This architectural framework imp...

30. [Prefrontal meta-control incorporating mental simulation enhances the adaptivity of reinforcement learning agents in dynamic environments](https://pmc.ncbi.nlm.nih.gov/articles/PMC11983510/) - ...variable goal states and state-transition uncertainties. Methods This architectural framework imp...

31. [The Effect of Threat on Novelty Evoked Amygdala Responses - PMC](https://pmc.ncbi.nlm.nih.gov/articles/PMC3643910/) - Journal of Abnormal Psychology 102: 121–121. [DOI] [PubMed] [Google ... Gamer M, Buchel C (2009) Amy...

32. [AI-Driven Microgrid Resiliency via Amygdala Modeling - LinkedIn](https://www.linkedin.com/posts/josep-m-guerrero-32717042_microgrids-ai-neuroscience-activity-7430274706953420801-Pe5k) - ... AI, this inspires "emotional learning" models that mimic evaluative functions for swift anomaly ...

33. [Sparse Autoencoders Find Highly Interpretable Features in Language
  Models](https://arxiv.org/pdf/2309.08600.pdf) - ...overcomplete set of directions in
activation space, rather than to individual neurons. Here, we a...

34. [A Survey on Sparse Autoencoders: Interpreting the Internal ... - arXiv](https://arxiv.org/html/2503.05613v1) - This paper presents a comprehensive examination of SAEs as a promising approach to interpreting and ...

35. [Towards Monosemanticity: Decomposing Language Models With ...](https://transformer-circuits.pub/2023/monosemantic-features) - Sparse autoencoders produce interpretable features that are effectively invisible in the neuron basi...

36. [Tiled Bit Networks: Sub-Bit Neural Network Compression Through Reuse of Learnable Binary Vectors](https://dl.acm.org/doi/10.1145/3627673.3679603) - Binary Neural Networks (BNNs) enable efficient deep learning by saving on storage and computational ...

37. [Google's TurboQuant Cuts LLM Memory Usage by 6x - LinkedIn](https://www.linkedin.com/posts/advixconsultancy_google-introduced-turboquant-a-compression-activity-7443282046858379264-rocB) - Google introduced TurboQuant, a compression algorithm for KV cache in LLMs KV cache is the memory th...

38. [Google's TurboQuant cuts AI memory use without losing accuracy](https://www.helpnetsecurity.com/2026/03/25/google-turboquant-ai-model-compression/) - Google's TurboQuant uses AI model compression to cut memory use by 6x and boost inference speed 8x w...

39. [TurboQuant: What Developers Need to Know About Google's KV ...](https://dev.to/arshtechpro/turboquant-what-developers-need-to-know-about-googles-kv-cache-compression-eeg) - The result is roughly a 4-6x reduction in KV cache memory with negligible quality loss. This article...

40. [[PDF] XQuant: Achieving Ultra-Low Bit KV Cache Quantization with ... - arXiv](https://arxiv.org/pdf/2510.11236.pdf) - We propose XQuant, a training-free and plug-and-play framework that achieves ultra-low equivalent bi...

41. [KV-Cache Compression Techniques - Emergent Mind](https://www.emergentmind.com/topics/kv-cache-compression-techniques) - Methods such as low-bit quantization and residual vector quantization can achieve up to 98% memory r...

42. [[PDF] Residual vector quantization for KV cache compression in ...](https://www.semanticscholar.org/paper/75118f54a902d399b937b6a47dfb2e4ea82d2848) - Residual vector quantization is applied to compress KV cache in large language models (LLM) to be co...

43. [LayerKV: Layer-Aware KV Cache Compression - Emergent Mind](https://www.emergentmind.com/topics/layerkv) - LayerKV is a suite of techniques for managing and compressing the key-value cache in Transformer mod...

44. [Group Residual Vector Quantized Autoencoders for SAR Raw Data Compression](https://ieeexplore.ieee.org/document/11232263/) - Synthetic Aperture Radar (SAR) systems are being improved continuously with increased swath sizes, b...

45. [Dictionary Pair-based Data-Free Fast Deep Neural Network Compression](https://ieeexplore.ieee.org/document/9679094/) - Deep neural network (DNN) compression can reduce the memory footprint of deep networks effectively, ...

46. [Complete vector quantization of feedforward neural networks](https://linkinghub.elsevier.com/retrieve/pii/S0925231219311129) - Abstract Deep neural networks are widely used to solve several difficult machine learning tasks due ...

47. [Residual vector quantization for KV cache compression in large language
  model](http://arxiv.org/pdf/2410.15704.pdf) - KV cache compression methods have mainly relied on scalar quantization
techniques to reduce the memo...

48. [KVTuner: Sensitivity-Aware Layer-wise Mixed Precision KV Cache
  Quantization for Efficient and Nearly Lossless LLM Inference](https://arxiv.org/abs/2502.04420) - ...quantization can improve Large Language Models (LLMs) inference
throughput and latency in long co...

49. [ZigZagkv: Dynamic KV Cache Compression for Long-context Modeling based
  on Layer Uncertainty](https://arxiv.org/pdf/2412.09036.pdf) - ...size for each layer to retain. However, we observe that the
minimum budget sizes needed to retain...

50. [Superposition: What Makes it Difficult to Explain Neural Network](https://towardsdatascience.com/superposition-what-makes-it-difficult-to-explain-neural-network-565087243be4/) - Superposition refers to a specific phenomenon that one neuron in a model represents multiple overlap...

51. [Toy Models of Superposition - Transformer Circuits Thread](https://transformer-circuits.pub/2022/toy_model/index.html) - Linear representations make features "linearly accessible." A typical neural network layer is a line...

52. [I Have Covered All the Bases Here: Interpreting Reasoning Features in Large Language Models via Sparse Autoencoders](https://arxiv.org/abs/2503.18878) - Recent LLMs like DeepSeek-R1 have demonstrated state-of-the-art performance by integrating deep thin...

53. [On the Complexity of Neural Computation in Superposition - arXiv](https://arxiv.org/html/2409.15318v3) - Neuronal activation space vectors are defined by the activation values of the neurons at a given lay...

54. [Cross-Layer Feature Alignment and Steering in Large Language ...](https://www.alignmentforum.org/posts/feknAa3hQgLG2ZAna/cross-layer-feature-alignment-and-steering-in-large-language-2) - In Mechanistic Permutability [1], we proposed a method to match features across layers by comparing ...

55. [Circuits in Superposition: Compressing many small neural networks ...](https://www.lesswrong.com/posts/roE7SHjFWEoMcGZKd/circuits-in-superposition-compressing-many-small-neural) - Anthropic's toy model of superposition shows how to compress many sparsely activating variables into...

56. [Embodied, Situated, and Grounded Intelligence: Implications for AI](https://arxiv.org/abs/2210.13589) - The workshop brought together computer scientists, psychologists, philosophers, social scientists, a...

57. [Robots and AI are not one moral category: why the distinction ...](https://www.frontiersin.org/journals/robotics-and-ai/articles/10.3389/frobt.2026.1776097/full) - Disembodied AI systems can also become ethical impact agents by default, but typically through diffe...

58. [Societal Impacts of Embodied AI - Communications of the ACM](https://cacm.acm.org/blogcacm/societal-impacts-of-embodied-ai/) - Economically, while EAI may enhance productivity, it also risks job displacement and increasing ineq...

59. [An Open-Source Red Teaming Framework for Multimodal LLMs - arXiv](https://arxiv.org/html/2601.01592v1) - These advancements significantly broaden the scope of automated red teaming, enabling more dynamic a...

60. [How does Chain of Thought Think? Mechanistic Interpretability of Chain-of-Thought Reasoning with Sparse Autoencoding](https://arxiv.org/abs/2507.22928) - Chain‑of‑thought (CoT) prompting boosts Large Language Models accuracy on multi‑step tasks, yet whet...

61. [Route Sparse Autoencoder to Interpret Large Language Models](https://arxiv.org/abs/2503.08200) - Mechanistic interpretability of large language models (LLMs) aims to uncover the internal processes ...

62. [Why Machines Can't Be Moral: Turing's Halting Problem and the Moral
  Limits of Artificial Intelligence](http://arxiv.org/pdf/2407.16890.pdf) - In this essay, I argue that explicit ethical machines, whose moral principles
are inferred through a...

63. [Claude's Constitution - Anthropic](https://www.anthropic.com/constitution) - Claude's constitution is a detailed description of Anthropic's intentions for Claude's values and be...

64. [How well do models follow their constitutions? - AI Alignment Forum](https://www.alignmentforum.org/posts/Tk4SF8qFdMrzGJGGw/how-well-do-models-follow-their-constitutions) - Anthropic has gotten much better at training the model to follow its constitution! Sonnet 4.6 has a ...

65. [Attributions toward artificial agents in a modified Moral Turing Test](https://www.nature.com/articles/s41598-024-58087-7) - Advances in artificial intelligence (AI) raise important questions about whether people view moral e...

66. [AI language model rivals expert ethicist in perceived moral expertise](https://www.nature.com/articles/s41598-025-86510-0) - People view AI as possessing expertise across various fields, but the perceived quality of AI-genera...

67. [Attributions toward artificial agents in a modified Moral Turing Test](https://pmc.ncbi.nlm.nih.gov/articles/PMC11061136/) - ...moral evaluations. We conducted a modified Moral Turing Test (m-MTT), inspired by Allen et al. (E...

68. [Quantifying Feature Space Universality Across Large Language Models via Sparse Autoencoders](https://www.semanticscholar.org/paper/39bbd489b43911152bdaf07f741a91bf1b15989d) - The Universality Hypothesis in large language models (LLMs) claims that different models converge to...

