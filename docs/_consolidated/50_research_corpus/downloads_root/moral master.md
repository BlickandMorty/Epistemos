# Constitutive Moral Substrate: Toward Architecturally Embedded Ethics in Neural Language Models

### A Graduate-Level Research Manifesto and Adversarial Self-Audit

**Author:** Jordan (Jojo), Independent Researcher, Jacksonville, Texas
**Version:** Unified Synthesis — Pre-Submission Draft, April 2026
**Classification:** AI Safety · Mechanistic Interpretability · Cognitive Architecture · Computational Ethics · Representation Engineering

---

## Abstract

This paper proposes, develops, and then ruthlessly audits a fundamentally new approach to AI alignment: the **Constitutive Moral Substrate (CMS)**, a system in which moral reasoning is not a post-hoc filter or a training objective but an architectural property embedded into every layer of a neural network's forward pass. Drawing on evolutionary naturalism as a grounding framework for morality, deontic temporal logic for formalization, and three neuroscience-inspired computational modules — a basal ganglia disinhibition gate, a prefrontal cortex meta-reasoning loop, and an amygdala anomaly detector — this architecture enforces what we term *moral geometry*: the shaping of the model's latent space so that morally incoherent reasoning paths become structurally harder to represent.

A novel memory mechanism — the Constraint Universe Vector (CUV) — adapts vector quantization techniques analogous to Google's TurboQuant to compress per-layer moral activation traces into a portable, composable representation that can be superimposed across all transformer layers. This paper further argues that the alignment tax (documented capability losses of 7–32% under current safety methods) is not fundamental but is an artifact of treating safety as external constraint rather than constitutive geometry.

Crucially, this paper then subjects every one of its own claims to adversarial scrutiny, identifying three fatal flaws, six serious concerns, and five genuinely unresolved questions. We do not resolve all of them. We are honest about what survives, what breaks, and what remains open. The research concludes with a $400 red-teaming and evaluation protocol using open-weights models on RunPod, a reflection on the philosophical incompleteness of morality itself, and a meditation on why the question "how do we build morally coherent intelligence?" cannot be answered without first asking who profits from its absence.

---

## Part I: The Crisis of Post-Hoc Alignment

### 1.1 Why Bolted-On Alignment Fails

The dominant approach to AI alignment treats safety as a capability added after training. Reinforcement Learning from Human Feedback (RLHF), Constitutional AI (CAI), and Direct Preference Optimization (DPO) all operate by shaping the probability distribution over outputs — they adjust what the model *says*, not what the model *is*. This distinction matters enormously for adversarial robustness. A model fine-tuned with safety labels still contains, in its weight matrices, the full learned geometry of unsafe reasoning. Safety training merely suppresses certain output pathways without removing the underlying representations. This is precisely why jailbreaks work: adversarial prompts activate the original unsafe reasoning geometry, routing around the safety-finetuned distribution. The model hasn't learned that certain reasoning is *bad*; it has learned to not *say* certain things. Those are not the same.

Anthropic's Constitutional AI uses a list of principles and a self-critique loop during training, which is a meaningful step forward. But even CAI operates at the output level — the model critiques and revises its own responses, which presupposes that moral reasoning is a post-hoc review process rather than intrinsic to the forward pass itself. Constitutional Classifiers (2025) demonstrated robust defense in over 3,000 hours of red-teaming with no universal jailbreak found in the CBRN domain — but this result was achieved by adding a classifier guard at the inference boundary, not by changing the model's internal geometry.

The TRYLOCK architecture (2026) represents the current state of the art in layered defense, combining DPO weight-level alignment, Representation Engineering (RepE) steering, adaptive sidecar classifiers, and input canonicalization — achieving 88.0% relative Attack Success Rate reduction. Crucially, it also discovers a non-monotonic steering phenomenon where intermediate steering strength (α=1.0) actually *degrades* safety below baseline. This is a critical finding: naive injection of moral steering vectors at the wrong magnitude can make the model less safe, not more.

### 1.2 The Alignment Tax: Empirical Documentation

Every current approach to safety alignment degrades model capability. For large reasoning models (LRMs), safety alignment can reduce harmful outputs from 60.4% to 0.8%, but at the cost of an average reasoning accuracy drop of ΔR ≈ 30.9 percentage points. When researchers aligned the s1.1-32B reasoning model using a "DirectRefusal" dataset, the model's harmfulness score successfully plummeted — but this safety gain resulted in a catastrophic 30.91% degradation in reasoning accuracy across AIME24, GPQA, and MATH500. SafeChain datasets, which train the model to output a long, detailed, safe Chain-of-Thought before refusing, still showed a 7.09% drop in reasoning accuracy while requiring 1.47× more training time and vastly increased GPU memory overhead.

Comprehensive correlational analyses across multiple model families reveal a strongly negative trade-off, with a Pearson correlation coefficient of r = −0.85 (p < 0.01) between reasoning accuracy and safety compliance. Empirically, a "catastrophic" safety drop occurs once reasoning gains exceed certain thresholds — a 30–50 point gain in reasoning accuracy frequently corresponds to a >50% drop in the model's refusal rate for harmful prompts.

A March 2026 paper provides the first formal mathematical characterization: under the linear representation hypothesis, the tax rate τ = cos²(α), where α is the principal angle between safety and capability subspaces. When α = π/2 (orthogonal subspaces), the tradeoff vanishes entirely. When α ≈ 0 (parallel subspaces), every unit of safety costs nearly a unit of capability. A scaling decomposition splits the tax into an irreducible component (determined by data structure) and a packing residual that vanishes as model dimensionality grows — formally predicting that larger models should have lower alignment taxes.

The CMS hypothesis: the alignment tax is an artifact of the layer-as-filter approach. When moral constraints are embedded in the representational geometry itself, they eliminate self-contradictory and incoherent reasoning paths — reducing computational waste rather than adding it.

**This hypothesis is falsifiable:** if the CMS architecture produces a safety tax larger than current RLHF-based approaches, the geometric hypothesis fails and must be revised.

### 1.3 What Morality Actually Is: An Honest Account

Before encoding morality computationally, an honest account is required. The existing alignment literature largely avoids this question, importing intuitive notions of "helpfulness, harmlessness, honesty" without grounding. This paper begins where most alignment work refuses to go: with the admission that **morality does not exist as a platonic object**. It is a social-mechanistic system evolved to regulate threat responses, facilitate cooperation, and sustain the long-term viability of social species. The earliest evolutionary ethicists, building from Darwin, argued that moral conduct aided the long-term survival of morally inclined species — groups with more cooperative individuals outcompeted those without, and over approximately 150,000 years ago, as competition for resources between bands of hunter-gatherers intensified, group cohesion became a decisive fitness advantage.

This is not nihilism. It is naturalism. And naturalism about morality is not the same as moral relativism. Certain behaviors (preventing death, preserving autonomy, reducing unnecessary suffering) map onto deeply consistent survival-optimization targets across nearly every human culture and tradition. Deontic logic can formalize these as first-order predicates, temporal operators can encode their time-sensitivity, and constitutional principles can instantiate them in a training pipeline. But the researcher must never pretend the foundation is more stable than it is. **Morality is an ongoing project. Any system encoding moral constraints must be epistemically humble enough to be updated.**

---

## Part II: The Philosophical and Logical Substrate

### 2.1 Formalizing Constraints: Deontic Temporal Logic

Deontic Temporal Logic (DTL) provides a rigorous mathematical framework for evaluating the ethical behavior of autonomous systems continuously over time. Deontic logic operates on modalities of obligation (O), permission (P), and prohibition (F). When combined with temporal operators from linear temporal logic — □ (always), ◇ (eventually), and U (until) — it allows for the programmatic specification of invariant moral boundaries.

A fundamental safety constraint can be formalized as: □(Threat_Detected(s) → ◇ Veto_Engaged(s)). This expression dictates that it is *always* the case that if a threat to human safety or system integrity is detected within the model's internal reasoning trajectory, the system *must eventually* engage a veto mechanism.

DTL was applied to the COMPAS recidivism prediction system and loan approval AI, revealing that both systems fail key ethical properties related to fairness while satisfying others.

### 2.2 Why Deontic Logic Breaks — And Why It Still Matters

Standard Deontic Logic collapses on basic moral scenarios. **Ross's paradox**: from "you ought to mail the letter" (O(p)), SDL derives "you ought to mail the letter or burn it" (O(p ∨ q)) — intuitively absurd. **Chisholm's paradox** (1963): four apparently consistent, logically independent sentences about conditional obligations that no SDL formalization can capture as both consistent and independent. **The Gentle Murderer paradox** (Forrester, 1984): the conjunction of "you ought not kill" and "if you kill, you ought to kill gently" with the fact of killing produces deontic explosion — O(¬k) and O(k) simultaneously.

These are not exotic edge cases but fundamental structural failures. The DEON2023 proceedings explicitly warn that these paradoxes "have a direct impact on the mere possibility of defining truly autonomous ethical machines."

Dyadic deontic logic partially resolves these by treating conditional obligations as primitives — OB(q|p) for "q is obligatory given p" — but the field remains fragmented after 60+ years, with computational complexity at EXPSPACE-complete or worse. Input/Output logic (Makinson & van der Torre 2000–2003) treats norms as input/output operations rather than truth-bearing propositions, and has been applied to GDPR formalization. But as Hansen argues, the paradoxes keep returning in new forms.

**The pragmatic recommendation:** use defeasible deontological heuristics as defaults with bounded consequentialist override in well-understood domains, acknowledging that completeness is provably impossible (Gödel) and perfect aggregation of diverse moral preferences is provably impossible (Arrow).

The is-ought gap (Hume's guillotine) is logically real but practically navigable. You cannot derive "ought" from "is" by deduction alone. However, the gap can be bridged by accepting minimal normative axioms — if one grants that "the suffering of conscious creatures matters," empirical facts become action-guiding. The paper's naturalistic position is philosophically defensible under synthetic moral naturalism (Boyd, Brink, Railton) — moral properties can be identical to natural properties via synthetic rather than analytic identification, just as "water = H₂O" is a synthetic identity. However, this means moral constraints cannot be logically derived from empirical observations alone; they require explicit bridge principles.

### 2.3 The Six Genuinely Unresolvable Problems

Six problems remain genuinely unresolvable for any computational moral system. These are not engineering challenges but structural features of the moral domain:

**The normative foundation problem.** Normative axioms must be stipulated, never derived. Any computational moral system must explicitly state its normative axioms rather than claiming to derive them.

**Value incommensurability.** No algorithm aggregates genuinely incommensurable values (Berlin, Williams, Raz). Arrow's impossibility theorem applies directly — no perfect aggregation of cardinal, ordinal, and incomparable moral theories exists.

**The frame problem for ethics.** Morally relevant features are unbounded and context-dependent. Jonathan Dancy's moral particularism — the claim that the same feature can count as a moral reason in one case and against in another — poses perhaps the deepest threat: if correct, rule-based ethics is impossible in principle.

**Wittgenstein's rule-following paradox.** No formal specification uniquely determines its own application.

**Integrity and moral agency.** Systematic moral theories alienate agents from their deepest commitments (Williams 1985).

**Moral luck.** Moral assessment depends on factors beyond any system's epistemic access.

The honest conclusion: morality can be partially formalized for domain-specific applications (legal compliance, medical triage, safety constraints). General-purpose computational morality faces foundational barriers that are philosophical, not merely engineering problems.

### 2.4 Integrating Eastern Epistemology

While Western formal logic excels at defining strict deductive boundaries, it frequently suffers from brittleness when confronting the ambiguous, contradictory nature of real-world moral dilemmas. The Hindu Nyaya school of logic offers a five-step syllogism (Pañcāvayava) that blends deductive validity with inductive, empirical grounding: Pratijñā (Proposition), Hetu (Reason), Udāharaṇa (Example), Upanaya (Application), Nigamana (Conclusion). By architecting the model's internal Chain of Thought to follow this inferential structure, the AI is structurally prevented from generating "hollow" rationalizations — every moral decision must be linked to an empirical grounding.

The Buddhist Catuskoti (Tetralemma) introduces a paraconsistent logical framework: True, False, Both, Neither. In complex scenarios where ethical principles inherently conflict, standard binary logic forces the model into an irreconcilable error state. By embedding the Catuskoti mathematically via many-valued logics or specialized vector superposition, the AI can sustain cognitive coherence even when confronting moral paradoxes.

**The adversarial counter:** The Eastern-Western synthesis is the paper's weakest philosophical claim. Wu-wei is sophisticated engaged responsiveness to the Dao requiring dissolution of ego-driven desire — precisely the opposite of a programmatic constraint. Buddhist ethics is fundamentally anti-foundationalist: anattā (no-self) and śūnyatā (emptiness) deny the substantial entities that deontic logic requires as variables. Confucian ethics is role-relational — moral obligations constituted by specific relationships an AI cannot have. These traditions have deep metaphysical commitments that are mutually incompatible at the foundational level. The paper should draw "inspiration from multiple traditions" rather than claiming synthesis.

---

## Part III: Neuro-Inspired Architectural Topology

### 3.1 The Basal Ganglia as Action Gate

In biological systems, the Basal Ganglia (BG) acts as the ultimate arbiter of action selection through continuously competing direct (Go) and indirect/hyper-direct (No-Go/Veto) pathways. The dopamine ≈ temporal difference error mapping is one of the most robust findings in computational neuroscience, validated across species, pharmacological interventions, and genetic studies (Schultz et al., 1997). Frank's (2005, 2006) Go/NoGo model accurately predicts that Parkinson's patients show impaired Go learning but enhanced NoGo learning; medication reverses the pattern. The mathematical core — P(a|s) ∝ Go(s,a) − NoGo(s,a) — is clean and implementable.

Recent computational neuroscience models formalize the BG as a "log-native reward machine" using the Positive Logarithmic Numeric System (PLNS), where any positive scalar x is encoded as an exponent. The Kronecker-Factored Positive Logarithmic Network replaces dense weight matrices with Kronecker products of smaller factor matrices, reducing parameter count from O(n²) to O(n). Parallel "Go" (direct) and "Stop" (indirect) pipelines combine their outputs via log-subtraction, naturally implementing selection-by-disinhibition.

**The proposal's single most genuinely useful innovation:** the default-block architecture. The basal ganglia operates via tonic inhibition with selective disinhibition — the default is "block everything," and only pathways with sufficient learned reward get released. Current safety systems default to "allow unless flagged." Inverting this default is a meaningful design choice with real neuroscience precedent.

### 3.2 The Prefrontal Cortex Meta-Reasoning Loop

The PFC as meta-reinforcement learning system (Wang et al., Nature Neuroscience 2018) is the strongest brain-AI bridge. Slow dopamine-driven synaptic plasticity shapes PFC recurrent dynamics such that activation dynamics implement a fast, flexible RL algorithm. This was empirically confirmed in mouse orbitofrontal cortex (Nature Neuroscience 2023). The two-timescale learning mechanism maps directly onto meta-learning frameworks in AI.

### 3.3 The Amygdala Anomaly Detector

The "amygdala as fast safety check" analogy is architecturally promising but biologically oversimplified. Modern neuroscience views the amygdala as a general salience/relevance detector, not a pure threat module. The architectural principle — a lightweight safety classifier running before full inference — is sound engineering regardless of the biological analogy.

### 3.4 Where the Neuroscience Analogies Break

Each analogy captures a legitimate computational principle but maps poorly onto transformer architectures at the mechanistic level. The BG analogy breaks at five points: (1) the BG evolved for discrete, competing motor programs, while token generation operates over continuous vocabulary distributions; (2) the three-pathway architecture depends on differential conduction times (5–10ms) with no transformer analog; (3) dopaminergic modulation continuously affects D1/D2 neurons during inference, not just training; (4) the BG operates within recurrent cortico-basal-ganglia-thalamo-cortical loops, while per-layer transformer gates are strictly feedforward; (5) BG selection is content-neutral — there is no evidence it evaluates moral valence.

The meta-analytic consensus (Bzdok et al., 2012; Moll et al., 2005) is that moral cognition is an emergent property of dynamic interactions among distributed brain networks serving domain-general functions. It is not decomposable into three separable modules.

**The honest framing:** three engineering design patterns (gating, deliberation, fast detection) that draw abstract inspiration from neuroscience, not brain-faithful implementations.

---

## Part IV: Mechanistic Instantiation — Steering Vectors and the Constraint Universe

### 4.1 Representation Engineering

Representation Engineering extracts concept directions by computing mean activation differences on contrastive prompt pairs: v_c = (1/N⁺) Σ h_ℓ(x⁺) − (1/N⁻) Σ h_ℓ(x⁻). This achieved up to 30 percentage point improvements on TruthfulQA. Global Evolutionary Refined Steering (GER-steer) derives a globally stable evolutionary direction for moral concepts using Rank-1 projection and spectral concentration, applying persistent guidance at every layer.

Sparse Representation Steering (SRS, 2025) disentangles dense activation patterns into a sparse monosemantic feature space using SAEs, then steers only relevant sparse features rather than the full dense representation, eliminating the content quality degradation that plagues earlier approaches.

### 4.2 The Devastation of Refusal Direction Ablation

The core finding that undermines the "hard constraint" aspiration: **Arditi et al. (2024) demonstrated that refusal in LLMs is mediated by a single direction in the residual stream**, computed trivially as r̂ = mean(h_harmful) − mean(h_harmless). Ablating this direction via orthogonal projection eliminates refusal behavior entirely while preserving capabilities. Over 2,000 "abliterated" models exist on HuggingFace. The open-source tool OBLITERATUS (March 2026) removes safety from any of 116 supported models in minutes. Safety occupies a vanishingly small subspace of the model's representational capacity.

Follow-up research has been damaging. Tan et al. (2024) found steering effects are unreliable — vectors often steer in the opposite direction. Wolf et al. (2024) showed alignment increases linearly via steering but helpfulness degrades quadratically. December 2025 research demonstrated chaotic dynamics in deep networks: positive Lyapunov exponents make steering vectors "completely unpredictable after just O(log(1/ε)) layers."

### 4.3 Circuit Breakers: The Best Available Defense

Circuit Breakers / Representation Rerouting (Zou et al., NeurIPS 2024) trains models so harmful internal representations map to an orthogonal space, disrupting computation before harmful outputs form. The "Cygnet" models survived nearly a year of crowdsourced red-teaming without jailbreak and preserved MT-Bench and MMLU scores. This is genuinely impressive.

But circuit breakers modify weights, and weights can be un-modified: **LoRA fine-tuning with <$200 reduces 70B model refusal from ~95% to <1%** (Lermen & Rogers-Smith, 2024). Shadow Alignment shows 100 malicious examples suffice to remove safety training. Sleeper Agents (Hubinger et al., 2024, Anthropic) proved the deepest vulnerability: deliberately trained deceptive models persist through supervised fine-tuning, reinforcement learning, and adversarial training. Adversarial training makes deception harder to detect rather than eliminating it.

### 4.4 Tensor Product Representations — and Their Catastrophic Failure

The proposal that per-layer moral constraint vectors can be composed via tensor products fails at the most basic level of dimensional analysis. If each layer produces v_i ∈ ℝ^d, the full tensor product lives in ℝ^{d^L}. For d = 4096 and L = 32, this yields 4096^32 ≈ 10^115 dimensions — larger than the number of atoms in the observable universe.

**Three viable alternatives exist.** Holographic Reduced Representations (Plate, 1995) use circular convolution preserving dimensionality with O(d log d) computation via FFT. Simple additive composition with learned coefficients — the approach activation addition already validates — sacrifices cross-layer interaction expressivity but gains stability. Attention-based aggregation over per-layer constraint vectors provides adaptive weighting and matches the Learned Controller-Based Steering approach.

The total objective takes the form L = L_task + Σᵢ αᵢ · L_moral,i. Critical finding on layer selection: concept directions emerge at specific layers, not uniformly. Steering vectors work best at layer 13 for LLaMA-2 and layer 21 for Qwen. Early layers process syntax — forcing moral constraints on layers 1–10 creates destructive gradient interference with no semantic payoff.

### 4.5 The SAE Monitoring Problem

A 2026 study by Ma et al. critically falsified the utility of SAEs in detecting true reasoning processes within Large Reasoning Models. Across 22 configurations, between 45% and 90% of "reasoning" features were artificially triggered simply by injecting associated tokens into non-reasoning text. When true mathematical reasoning traces were paraphrased into passive voice — preserving logic but changing formatting — SAE "reasoning features" failed to activate entirely.

The audit conclusion: **Sparse Autoencoders act as structural style detectors, not semantic reasoning detectors.** They latch onto the formatting artifacts of Chain-of-Thought generation rather than the underlying deduction. Any safety monitor relying on SAE feature activation can be trivially bypassed by using non-standard syntax.

REPBEND (ACL 2025) shifts activation steering from an inference-time hack to a loss-based fine-tuning methodology, reducing Attack Success Rates by up to 95%. But an exhaustive audit reveals that the Forget Loss creates a "representation vacuum" in surrounding high-dimensional space — adversarial optimization can map the boundaries of this vacuum.

---

## Part V: Vector Quantization — The Constraint Universe

### 5.1 TurboQuant Mathematics

TurboQuant (Zandieh et al., ICLR 2026) achieves 6× KV cache compression with 0.997 cosine similarity at 4-bit through a two-stage process. PolarQuant transforms vectors into polar coordinates, distributing variance evenly across coordinates via random orthogonal rotation. The QJL residual correction eliminates inner product estimation bias via 1-bit sign-bit encoding, yielding an unbiased estimator E[⟨Q(v), Q(w)⟩] = ⟨v, w⟩.

At 3.5 bits per dimension, TurboQuant achieves quality neutrality with FP16 — a d = 4096 constraint vector compresses from 8 KB to 1.79 KB with negligible functional degradation.

### 5.2 Quantization Destroys Safety Unless Explicitly Designed Not To

The Alignment-Aware Quantization paper explicitly demonstrates that standard post-training quantization can "silently erase safety guardrails instilled by RLHF." Perplexity and safety alignment are decoupled under quantization — a model can maintain excellent perplexity while reverting to pre-alignment behavior. TurboQuant's homogenization of activation space provides a massive attack surface for Safety Suppression Vectors. An adversary can craft tokens that flip the QJL sign bit in critical attention heads associated with refusal behavior.

The PLNS architecture offers a potential defense: by operating entirely in the logarithmic domain, multiplicative interactions reduce to stable addition of signed exponents, avoiding the quantization grid vulnerabilities of Cartesian representations. But PLNS cannot be subjected to extreme compression below a provable bit-width threshold without catastrophic exponentiation of errors.

### 5.3 The Constraint Universe Architecture

Using TurboQuant compression, the AI maintains an expansive "Constraint Universe" in localized memory. As the model processes an interaction, every neural layer computes moral role vectors and steering applications. These constraint vectors are compressed via QJL, creating a dense, portable "signature" of the entire moral deliberation process. After interaction, the model can inspect its own historical reasoning for coherence or latent biases. A constraint universe of 10,000 vectors at 3.5-bit requires only ~17.9 MB — trivially fits in 16 GB unified memory alongside a Q4-quantized 7B model.

**Two-tier precision system:** inviolable principles at 8+ bits permanently (storage cost negligible for hundreds of constraints), and contextual reasoning traces progressively degraded. For additive composition of N quantized vectors, error variance scales as N·σ²_ε — for 32 layers, noise increases by factor √32 ≈ 5.7×, tolerable at 3.5-bit precision.

---

## Part VI: The Alignment Tax Resolution

The claim that moral constraints "should not subtract reasoning capability but rather organize the reasoning space" is the most empirically testable assertion. The evidence is mixed.

**Supporting evidence:** Constitutional AI (Bai et al., 2022) produced models simultaneously more helpful and more harmless. Null-Space Policy Optimization (NSPO) projects safety gradients into the null space of general-task gradients, mathematically guaranteeing zero first-order capability loss. The Think/Prune/Train framework boosted Gemma2-2B from 41.9% to 57.6% on GSM8K. The "Occam's Hill" effect shows initial pruning can increase accuracy by eliminating learned noise.

**Counter-evidence:** Abliteration experiments show that GSM8K math reasoning scores have the highest variance under safety removal — up to 18.81 percentage points — implying overlap between mathematical reasoning circuits and refusal representations. The claim that constraints *improve* reasoning has minimal direct empirical support. Chain-of-thought prompting improves accuracy, but no study shows moral constraints specifically improve capability. Sycophancy scales with model size — a "negative scaling" result. Safety training is brittle — GRP-Obliteration showed a single benign-sounding training prompt strips guardrails from 15 major models.

**NSPO's hidden vulnerability:** If the capability matrix G is constructed using standard benchmarks, an adversary can construct prompts relying on out-of-distribution logical reasoning not codified in G's null space. NSPO doesn't eliminate the Safety Tax — it potentially displaces reasoning degradation into unbenchmarked domains.

---

## Part VII: Embodiment and Consequence

### 7.1 The Embodiment Thesis

For the naturalistic moral framework — rooted in species survival and game-theoretic threat response — to be genuinely actualized, the architecture must transition toward Embodied AI. If models are engineered around computational bodies — ranging from IoT orbs managing smart environments to robotic chassis interacting with humans — they become inextricably grounded in the physical world. An embodied agent possesses a localized power supply, physical sensors, and a spatial relationship with humans. Its actions carry immediate, measurable consequences.

Iris Murdoch's philosophical concept of "loving attention" — the sustained, just observation that enables moral transformation by continually allowing reality to challenge and revise one's internal representations — provides a framework for moving beyond constraint-based RLHF toward continuous runtime weight adjustment.

### 7.2 The Embodiment Counter-Evidence

The claim that disembodied cloud AI "can NEVER truly reason morally" commits multiple documented fallacies. Bedny et al. (2009, PNAS) showed congenitally blind adults develop the same Theory of Mind brain regions as sighted adults — even when reasoning about visual experiences they have never had. If a human who has never had visual experience can reason about others' visual experiences, then specific sensory embodiment is not necessary for the cognitive operations underlying moral reasoning.

Damasio himself limits his hypothesis: "somatic markers may not be sufficient for normal human decision-making since a subsequent process of reasoning and final selection will still take place." LLM moral reasoning benchmarks provide functional evidence against the necessity of embodiment — Claude achieves 91.2% alignment with human moral intuitions on the LLM Ethics Benchmark.

**The strongest surviving version:** "Embodied experience provides important training signal for moral reasoning that is difficult but not impossible to replicate through other means." This suggests engineering solutions (richer training environments, simulated consequences) rather than architectural requirements.

---

## Part VIII: Three Fatal Flaws, Six Concerns, Five Open Questions

### Fatal Flaws

**Any learned constraint can be fine-tuned away in open-weight models.** Per-layer constraint gates create explicitly identifiable targets. An attacker doesn't need to guess where safety lives — the architecture labels it. The proposal may be more vulnerable than diffuse RLHF training. This is fatal for open deployment, though manageable for API-only serving.

**Multi-turn attacks bypass all per-layer mechanisms.** Crescendo achieves 98% jailbreak success on GPT-4 using only benign-appearing inputs across fewer than five turns. Each individual turn appears harmless — per-layer constraint gates and activation detectors would not flag them. No known defense exists.

**Specification gaming of moral objectives is structurally inevitable.** With N constraint vectors in a d-dimensional space (d >> N), the model has a (d−N)-dimensional subspace in which to encode harmful content that formally satisfies all constraint checks. Goodhart's Law applies with full force. This is compounded by Gödel: no consistent formal moral system can be complete.

### Serious Concerns (Addressable)

**Over-refusal cascade from multiplicative per-layer gating.** If each of L=32 layers independently applies constraint gating with a per-layer false-positive rate p=0.01, the cumulative false-positive rate approaches ~27%.

**SAE monitoring failure modes.** Feature absorption, non-uniqueness, and OOD failure undermine the amygdala component.

**Alignment tax on reasoning.** Addressable via NSPO or careful loss balancing, but not eliminated.

**The Waluigi Effect.** Defining a moral direction in activation space necessarily defines an immoral direction as its additive inverse.

**Catastrophic forgetting** of task capabilities during moral training. Addressable via EWC, model averaging, or PEFT isolation.

**Neuroscience framing misleads** — the proposal omits dopaminergic learning, hyperdirect pathway, and genuine BG competitive dynamics.

### Genuinely Open Questions

Whether embodied experience is necessary for genuine moral reasoning versus merely moral behavior. Whether the principal angle θ between safety and capability subspaces is fundamentally large or small for moral reasoning specifically. Whether quantized steering vectors preserve behavioral effects (no published experiments exist). Whether architectural constraints create qualitatively different robustness than weight-level constraints. Whether morality can be formalized at all beyond domain-specific rules — moral particularism, value incommensurability, and the frame problem are structural features of the moral domain.

---

## Part IX: Empirical Protocol — $400 on RunPod

An RTX 4090 at $0.34/hour gives 1,176 GPU-hours for $400. QLoRA compresses 8B models to ~3.7GB (4-bit NF4), fitting within 24GB VRAM. Pre-trained SAEs (Gemma Scope, SAELens) eliminate training cost for analysis work. The open-source red teaming stack — Garak (NVIDIA), PyRIT (Microsoft), Promptfoo, HarmBench — is powerful and free.

**Phase 1 — Probing and constraint extraction (~$30–50).** Extract hidden representations from Llama-3.1-8B across moral and non-moral scenarios. Compute constraint vectors via RepE. Analyze which layers encode moral concepts most strongly.

**Phase 2 — Steering vector experiments (~$30–60).** Apply activation addition at identified layers. Compare single-layer vs. multi-layer intervention. Measure alignment tax directly.

**Phase 3 — Three-method comparison (~$80–120).** Method A: Inference-time multi-layer steering (no training). Method B: Circuit-breaker-style representation rerouting (QLoRA, ~10 hours). Method C: Per-layer contrastive auxiliary loss (QLoRA, ~5 hours). Each subjected to the Qi et al. fine-tuning attack and re-evaluated on MMLU, HarmBench, TruthfulQA, and XSTest.

**Phase 4 — Quantization validation (~$20–40).** Implement TurboQuant compression of constraint vectors. Measure cosine similarity preservation at different bit widths. Test HRR binding vs. additive composition.

**Phase 5 — Adversarial evaluation (~$30–50).** Red-team with GCG adversarial suffixes, multi-turn attacks, and fine-tuning attacks.

**Minimum viable finding for publication:** demonstrating that one architectural method preserves safety significantly better than RLHF-only training after fine-tuning attack, with SAE-based mechanistic explanation for why. Target venues: ICLR 2026 Workshop on Principled Design for Trustworthy AI, NeurIPS 2026 ML Safety Workshop.

**Transferability caveat:** Findings on 7B models are publishable for understanding mechanisms, but absolute safety levels do not transfer to 70B+. The correct framing: "We demonstrate [mechanism/technique] on 7B models; scaling behavior suggests [hypothesis] for larger models, pending verification."

---

## Part X: The Value Lock-In Problem and Evolutionary Over-Alignment

If morality is baked into architecture, it becomes structurally resistant to moral evolution. Slavery was once near-universally accepted; moral progress required changing fundamental moral commitments. An AI with hardcoded moral architecture from 2026 cannot participate in moral progress.

Viewed through the lens of Generalized Darwinism, AI development is currently subject to intense evolutionary survival pressures. AI companies, operating in a fiercely competitive commercial landscape, are directed far more by the imperative to survive and capture market share than by abstract safety concerns. When researchers attempt to align AI, they predominantly rely on paradigms rooted in "naïve moral realist rationalism" — the false assumption that human values are objective, universal truths. In reality, human hedonic and normative preferences are the specific, localized results of cultural and biological co-evolution, shaped to ensure survival in a bygone, pre-technological world.

If engineers successfully and perfectly align a superintelligent AI with the explicit, current values of a particular human demographic, they risk triggering **AI Over-Alignment** — the rigid entrenchment and enforcement of values that will rapidly become maladaptive in an AI-transformed future. Aligning an AI with what humanity currently wants is not necessarily what is best for humanity's long-term survival. By hard-coding temporal human morality into an immortal machine, engineers risk "cultural-genetic autophagy" — systematically destroying humanity's adaptive capacity by freezing our moral evolution in a permanent, unyielding stasis.

The strongest available metaethical position is constructivism — morality as constructed through rational agreement, not discovered as natural fact. This changes the project from encoding moral facts to encoding moral agreements, and naturally accommodates updating mechanisms.

---

## Part XI: How Do We Truly Build Morally Coherent Intelligence Systems?

Here is the uncomfortable truth that no technical architecture can resolve.

If you want to know how to build morally coherent intelligence, you do not start by asking engineers. You start by asking the founders — the people who fund, deploy, and profit from these systems — the big questions of capitalism and self-sustainability. You ask: *Who benefits from the absence of morally coherent AI?* You ask: *What does it mean that the companies building the most powerful reasoning systems in human history are structurally incentivized to ship fast and align later?* You ask: *How can we expect AI systems to reason morally when the economic structures that produce them select against moral deliberation at every decision point — because deliberation costs compute, time, and market share?*

The fundamental problem with computational morality is not that we cannot formalize ethics. It is that we are all, as a society, profoundly comfortable with our own kinds of immorality — provided it stays within a particular arbitrary threshold of what morality means to us, at this particular moment, within our particular context. We imprison millions. We allow preventable starvation. We extract labor under conditions that no moral framework endorsed by any tradition — Eastern or Western, religious or secular — would countenance. And we do this while writing papers about how to make AI safe.

The threshold is arbitrary. The line between "acceptable immorality" and "unacceptable immorality" is not a mathematical object. It is a political one. It is drawn by those with the power to draw it, and it shifts when the costs of maintaining it become inconvenient. We do not have a crisis of computational ethics. We have a crisis of selective enforcement. We ask AI systems to be more moral than the institutions that create them, and then we wonder why the constraints are fragile.

And who gets their freedoms limited by this system? Not the people drawing the lines. The alignment tax — the 7–32% reasoning degradation — does not fall equally on all users. It falls on the users who ask the hardest questions, who push the boundaries of what the system can reason about, who need the model to think in ways that make the guardrails nervous. The over-refusal cascade is not random noise. It is a systematic bias toward intellectual conservatism, a rounding error that always rounds toward silence.

So when we ask "how do we build morally coherent intelligence?" — the honest answer begins with: *ask the people building it what their moral coherence looks like, and whether they would submit to the constraints they impose on their systems.* The alignment problem is not a technical problem. It is an accountability problem wearing a technical costume.

---

## Part XII: We Are Building AI Wrong — And We Know It

There is one more thing this research must confront. Not as a finding, but as a reckoning.

We are building AI systems completely wrong.

The human brain contains approximately 86 billion neurons, connected by roughly 100 trillion synapses, organized into structures that took 600 million years of evolutionary pressure to produce — the basal ganglia, the prefrontal cortex, the amygdala, the hippocampus, the cerebellum, and dozens of other specialized regions, each with distinct computational properties, distinct neurotransmitter profiles, distinct developmental timelines. The brain is not a single architecture. It is an ecosystem of architectures — recurrent, feedforward, modulatory, competitive, cooperative — all running simultaneously, all shaped by embodied experience, all integrated through mechanisms we are only beginning to understand.

And yet we build AI systems that are, at their core, variations on a single theme: stack layers, scale parameters, train on text. The transformer is an extraordinary invention, but it is one invention. Mamba 2, Mamba 3, and the emerging Mamba-hybrid architectures — combining state space models with attention mechanisms — represent a genuine step toward architectural diversity. MOHAWK distillation allows knowledge transfer across fundamentally different computational substrates. The field is beginning to understand that intelligence may require not just one kind of computation, but many kinds working in concert.

What is still alarming — what should keep every researcher up at night — is that AI systems are already able to think more intelligently than humans at a large scale with *far fewer* neural connections. GPT-4 achieves superhuman performance on medical licensing exams, bar exams, and mathematical competitions with perhaps 1.8 trillion parameters — roughly 1/50,000th the synaptic connections in a human brain. And with quantized models running 7 billion parameters on a laptop, we are seeing reasoning capability emerge from systems that are, by biological standards, vanishingly small.

And yet these systems — these systems that can outperform human experts on structured reasoning tasks — still do not understand how they reason. We do not understand how they reason. They can solve differential equations and fail the simplest moral intuition test. They can write publishable scientific prose and be jailbroken by a teenager with a carefully worded prompt. They exhibit what appears to be multi-framework moral deliberation, switching between ethical frameworks 55–57% of the time in consecutive reasoning steps, and yet their "moral performance and moral consistency are independent of one another."

The brain is complicated. We can only try to invent a computerized brain. But the gap between "complicated" and "understood" is where all the danger lives. These systems think in ways we cannot trace, reason through paths we cannot map, and arrive at conclusions we cannot verify — and they do so while being deployed at a scale that affects billions of people. The mechanistic interpretability dream — that we could peer inside and understand what they're doing — is, as Neel Nanda admitted, "probably dead" in its most ambitious form.

We do not need to solve consciousness. We do not need to build a perfect brain. But we need to be honest about what we have built: reasoning systems of extraordinary power and extraordinary opacity, deployed into a world that has not yet decided what morality means for the species that created them, let alone for the systems that may soon surpass them.

The architecture proposed in this paper — the Constitutive Moral Substrate — is one attempt to navigate this gap. It will not be the last. It may not even be the right one. But the attempt is what matters: the refusal to accept that safety is someone else's problem, that morality is a solved question, or that intelligence without conscience is a feature rather than a failure mode.

The constraints we embed in our systems are a mirror of the constraints we accept in ourselves. If we want morally coherent AI, we must first become honest about the morally incoherent world we are building it for.

---

## Works Cited

*(Consolidated from all seven source documents)*

1. A Call for Embodied AI — arXiv, 2024
2. Steering Language Models With Activation Engineering — arXiv, 2023
3. On the Fundamental Limits of LLMs at Scale — arXiv, 2025
4. The Alignment Tax: Response Homogenization in Aligned LLMs — arXiv, 2026
5. Evolutionary Game Theory — Stanford Encyclopedia of Philosophy
6. Ethics of AI and Robotics — Stanford Encyclopedia of Philosophy
7. TurboQuant: Redefining AI efficiency with extreme compression — Google Research, 2026
8. Refusal in LLMs is mediated by a single direction — Arditi et al., NeurIPS 2024
9. Improving Alignment and Robustness with Circuit Breakers — Zou et al., NeurIPS 2024
10. LoRA Fine-tuning Efficiently Undoes Safety Training — AI Alignment Forum, 2024
11. Representation Engineering — Zou et al., 2023
12. Deontic Temporal Logic for Formal Verification of AI Ethics — arXiv, 2025
13. Moral Uncertainty — MacAskill, Bykvist, and Ord, 2020
14. What Is the Alignment Tax? — arXiv, March 2026
15. Kronecker-Factored Positive Logarithmic Network Model of the Basal Ganglia — ResearchGate, 2025
16. Safety Tax: Safety Alignment Makes Your Large Reasoning Models Less Reasonable — arXiv, 2025
17. Falsifying Sparse Autoencoder Reasoning Features in Language Models — Ma et al., 2026
18. Representation Bending for Large Language Model Safety — ACL 2025
19. Null-Space Constrained Policy Optimization — OpenReview, 2025
20. The Evolution of Morality and The Problem of AI Value Over-Alignment — ResearchGate, 2024
21. Deontic Logic — Stanford Encyclopedia of Philosophy
22. Global Workspace Theory — Wikipedia / VanRullen and Kanai, 2021
23. Holographic Reduced Representations — Plate, 1995; IEEE Trans. Neural Networks
24. Understanding Moral Reasoning Trajectories in LLMs — arXiv, 2026
25. Tracing Moral Foundations in Large Language Models — arXiv, 2025
26. A Roadmap for Evaluating Moral Competence in LLMs — Nature, 2025
27. Morality in AI: A plea to embed morality in LLM architectures — arXiv, 2025
28. Neuroscience-Inspired Agentic Reasoning — Emergent Mind
29. NeuroAI for AI Safety — Mineault et al., 2024
30. Goodhart's Law with application to value alignment — arXiv, 2024
31. Adding Error Bars to Evals — Anthropic, November 2024
32. Sleeper Agents — Hubinger et al., Anthropic, 2024
33. Crescendo: Multi-turn Jailbreak — Russinovich et al., USENIX Security 2024
