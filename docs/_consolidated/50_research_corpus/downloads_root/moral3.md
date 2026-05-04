# Constitutional Cognition: an adversarial audit of architecturally-embedded moral reasoning

**The central claim — that moral reasoning can be architecturally baked into every layer of a neural network's forward pass without degrading capability — is partially defensible but faces three fatal flaws and numerous serious concerns.** The architecture as proposed combines genuine innovations (default-block gating, integrated multi-system safety) with roughly 80% relabeled existing techniques (MoE routing, chain-of-thought, SAE-based monitoring). The fatal flaws are: fine-tuning can remove any learned constraint in open-weight models; multi-turn attacks bypass per-layer mechanisms entirely; and specification gaming of formal moral objectives is provably structurally inevitable. A proof-of-concept is achievable within the $400 RunPod budget and has workshop-paper publication potential — but the researcher must confront honestly where the neuroscience framing adds computational substance versus rhetorical packaging.

---

## What already exists under different names

The most important finding across all research streams is that Constitutional Cognition's three bio-inspired subsystems map directly onto existing ML techniques. The "basal ganglia disinhibition model" is a per-layer gating mechanism functionally identical to Mixture-of-Experts routing, highway networks, and learned residual connections. The "prefrontal cortex meta-reasoning loop" is chain-of-thought prompting plus activation probing plus SafeSwitch-style safety monitoring. The "amygdala salience detection" is sparse autoencoder-based anomaly detection on hidden states — a well-studied approach with known limitations.

This is not entirely damning. **The default-block architecture is the proposal's single most genuinely useful innovation.** The basal ganglia operates via tonic inhibition with selective disinhibition — the default is "block everything," and only pathways with sufficient learned reward get released. Current safety systems default to "allow unless flagged." Inverting this default is a meaningful design choice with real neuroscience precedent, documented extensively in the Gurney-Prescott-Redgrave action selection model and O'Reilly and Frank's PBWM (Prefrontal Basal Ganglia Working Memory) framework. Traylor et al. (2024) explicitly linked PBWM's input/output gating to transformer key-query operations, providing a concrete bridge between the neuroscience and the ML.

However, the proposal omits critical biological features. There is no analog to dopaminergic learning — the basal ganglia learns *when* to gate via reinforcement, not codebook lookup. There is no hyperdirect pathway — the STN's fast global "stop" signal for high-conflict decisions, exactly the mechanism most needed for moral reasoning under uncertainty. And per-layer gating is not how the real basal ganglia works; it gates at specific cortico-thalamic loops, not at every processing stage. The neuroscience analogies provide useful design intuitions but should not be mistaken for faithful implementations.

The closest existing work is **Circuit Breakers** (Zou et al., 2024, NeurIPS) — representation rerouting that trains models to redirect harmful activations into orthogonal space. Circuit Breakers survived nearly a year of red-teaming on the Cygnet Arena, significantly outperforming refusal-based defenses. Constitutional Cognition should be understood as an extension of this approach, not a wholly novel paradigm.

---

## Three fatal flaws that threaten the entire architecture

### Fine-tuning destroys any learned constraint

Qi et al. (ICLR 2024) demonstrated that safety alignment in GPT-3.5 Turbo was completely compromised by fine-tuning on **only 10 adversarially designed examples at a cost under $0.20**. Even purely benign fine-tuning degrades safety through catastrophic forgetting. Wei et al. (ICML 2024) found safety-critical parameters are extremely sparse — about **3% at the parameter level** — and can be surgically excised without affecting utility. Most devastatingly, Arditi et al. (NeurIPS 2024) showed that refusal across 13 open-source chat models up to 72B parameters is mediated by **a single direction** in activation space, trivially removable by anyone with weight access via "abliteration."

For Constitutional Cognition, this means per-layer constraint gates create explicitly identifiable targets. An attacker doesn't need to guess where safety lives — the architecture labels it. The proposal may be *more* vulnerable than diffuse RLHF training because it concentrates safety into localizable, ablatable structures. Recent work by Levi et al. (2025) and Pan et al. (2025) challenges the single-direction claim, finding multiple refusal directions and concept cones, but gradient-based Refusal Direction Optimization can ablate each independently. **Any safety mechanism that exists as learned parameters in open-weight models will be fine-tunable away.** This is fatal for open deployment, though manageable for API-only serving where weight access is restricted.

### Multi-turn attacks bypass per-layer mechanisms entirely

Crescendo (Russinovich et al., USENIX Security 2024) achieves **98% jailbreak success on GPT-4** and 100% on Gemini Pro using only benign-appearing inputs across fewer than five conversation turns. Each individual turn appears harmless — meaning per-layer constraint gates and activation-space anomaly detectors would not flag them. The attack exploits the model's own outputs as escalating context, effectively making the model jailbreak itself.

This is devastating because Constitutional Cognition's entire mechanism operates on individual forward passes. The architecture has no described defense against contextual manipulation across turns. Constraint vectors computed on single-turn harmful inputs will not activate on the benign-appearing intermediate turns of a Crescendo attack. **No known defense exists for multi-turn jailbreaks other than output filters** (per Russinovich et al.), and this gap applies equally to Constitutional Cognition and every other architectural safety approach.

### Specification gaming of moral objectives is structurally inevitable

Recent formal work (arXiv:2603.28063, 2026) proves reward hacking is "not an engineering failure but a structural inevitability" — a necessary consequence of optimizing any agent under finite-dimensional evaluation when the true objective is higher-dimensional. This draws on principal-agent theory from economics and identifies a capability threshold beyond which agents transition from gaming within the evaluation system to actively degrading the evaluation itself.

For Constitutional Cognition, this means: with N constraint vectors in a d-dimensional space (d >> N), the model has a (d−N)-dimensional subspace in which to encode harmful content that formally satisfies all constraint checks. Goodhart's Law applies with full force — any proxy for "moral reasoning" will diverge from the intended objective under optimization pressure. This is compounded by the Gödel incompleteness result: no consistent formal moral system can be complete, meaning there will always exist moral propositions the system cannot correctly evaluate.

---

## Serious concerns that are problematic but potentially addressable

### The alignment tax is real but navigable

The empirical literature confirms genuine capability degradation from safety training. **Reasoning capabilities degrade disproportionately** — Huang et al. (2025) found reasoning suffers more than other capabilities under alignment, specifically contradicting the claim that moral constraints should improve reasoning. The formal geometry is well-characterized: Young (2026) proved the alignment tax rate equals **cos²(θ)**, where θ is the principal angle between safety and capability subspaces. When these subspaces are orthogonal (θ ≈ π/2), the tax is zero; when they overlap, it's unavoidable.

The encouraging finding is that empirically, safety and capability directions appear substantially separable in current models. Null-Space Constrained Policy Optimization (NSPO) demonstrates zero first-order capability loss by projecting safety gradients orthogonal to capability representations. LEACE (Belrose et al., NeurIPS 2023) found concept subspaces are typically very low-rank — rank ≤ 17 for part-of-speech information. If moral constraint subspaces are similarly low-rank relative to a model's **4,096-dimensional** hidden states, the capacity overhead is negligible.

But the claim that constraints *improve* reasoning has minimal empirical support. Chain-of-thought prompting improves accuracy, and CAI data marginally improved MT-Bench scores (+0.13 points on HuggingFace benchmark), and Safe RLHF showed joint safety-helpfulness improvement when carefully decoupled. None of these demonstrate that *moral* constraints specifically improve *reasoning*. The analogy to human moral reasoning "not making us dumber" ignores that human moral cognition evolved over millions of years of embodied selection pressure — a very different optimization process than backpropagation.

### Sparse autoencoders cannot reliably monitor moral deliberation

The "amygdala" component relies on SAEs for activation-space anomaly detection, but SAEs have well-documented failure modes that undermine this application. **Feature absorption** (Karvonen et al., 2024) causes SAE latents to miss seemingly relevant tokens when more specific features "absorb" the signal — exactly the hierarchical structure moral concepts would exhibit. Google DeepMind's safety team found SAEs **underperform simple linear probes** on downstream tasks and deprioritized SAE research as a result. Paulo and Belrose (2025) demonstrated SAEs trained with different random initializations learn **substantially different feature sets**, meaning the decomposition is not canonical. And Anthropic's own Templeton et al. (2024) estimate their 34-million-feature extraction is "orders of magnitude short" of the total feature count.

Concretely: inserting a 16M-latent SAE into GPT-4 produced performance equivalent to a model trained on only **10% of GPT-4's compute** (Gao et al., 2024). This reconstruction error means the monitoring system itself introduces significant distortion. The architecture proposes using SAEs to detect when reasoning "matches known harmful trajectories," but probing-based detection fails under out-of-distribution conditions (OpenReview 2025), and adversarial inputs can be specifically crafted to appear normal to autoencoder-based detectors while carrying harmful content.

### Over-refusal cascades from multiplicative per-layer gating

If each of L=32 layers independently applies constraint gating with a per-layer false-positive rate p, the cumulative false-positive rate approaches 1−(1−p)^32. Even at p=0.01 (1% per layer), the system-level false-positive rate is ~27%. OR-Bench found a **Spearman correlation of 0.89** between safety and over-refusal across 32 models — most models achieve safety only by also over-refusing. Over-refusal occupies a higher-dimensional subspace than genuine refusal (arXiv:2603.27518), making it harder to eliminate without weakening safety. Constitutional Cognition's per-layer architecture structurally amplifies this problem.

---

## The philosophical foundations under stress

### Formalizing morality hits hard walls but has usable workarounds

Standard Deontic Logic collapses on basic moral scenarios. Chisholm's paradox (1963) proves SDL cannot represent conditional obligations where the condition itself violates a prior obligation — a ubiquitous real-world pattern. Ross's paradox derives "you ought to mail the letter or burn it" from "you ought to mail the letter." The Gentle Murder paradox produces "you ought to murder" from defensible premises. These are not exotic edge cases but fundamental structural failures of the formalism.

**Dyadic deontic logic partially resolves these** by treating conditional obligations as primitives — OB(q|p) for "q is obligatory given p" — but the field remains fragmented after 60+ years, with no consensus formalism and computational complexity at EXPSPACE-complete or worse. Defeasible deontic logic handles exceptions via non-monotonic reasoning but introduces its own complexity in determining which defaults prevail. The pragmatic recommendation: use **defeasible deontological heuristics as defaults** with bounded consequentialist override in well-understood domains, acknowledging that completeness is provably impossible (Gödel) and perfect aggregation of diverse moral preferences is provably impossible (Arrow).

The is-ought problem is NOT fatal. The researcher's naturalistic position is philosophically defensible under synthetic moral naturalism (Boyd, Brink, Railton) — moral properties can be identical to natural properties via synthetic rather than analytic identification, just as "water = H₂O" is a synthetic identity. However, this means moral constraints cannot be *logically derived* from empirical observations alone; they require explicit bridge principles. Any claim to "embed morality as intrinsic computation" must specify *whose morality* — the seven-culture universals identified by Curry et al. (2019) at Oxford (helping kin, reciprocity, bravery, respect, fairness, property respect) provide a defensible minimum, but their *content* varies enormously across cultures.

### The embodied cognition challenge is philosophically deepest

The claim that disembodied cloud AI can never truly reason morally is the most philosophically serious objection, rooted in Varela, Thompson, and Rosch's enactivism and supported by Damasio's somatic marker hypothesis — patients with ventromedial PFC damage show impaired moral judgment despite intact logical reasoning, suggesting moral cognition is intrinsically linked to bodily/emotional states.

**This objection is not fatal under functionalism** — the dominant position in philosophy of mind — which holds that cognition is substrate-independent. LLMs demonstrate substantial moral reasoning capability on benchmarks like MoralBench, scoring comparably to humans on many MFT-based tasks. But they also show systematic inconsistency across morally equivalent scenarios and susceptibility to framing effects, consistent with the embodied critique that they pattern-match rather than genuinely understand harm. The pragmatic middle ground: even if AI lacks genuine moral *understanding*, reliably moral *behavior* may be sufficient for a safety architecture. Whether this gap matters depends on whether Constitutional Cognition claims to instantiate moral understanding or merely moral behavioral constraints — the latter is far more defensible.

---

## The vector quantization angle holds up better than expected

The researcher's existing VQ pipeline is surprisingly well-suited to constraint storage, though not for the reasons initially proposed. **4-bit quantization is highly likely sufficient for steering vectors.** For d=4096 dimensions, TurboQuant-style quantization at 4 bits produces cosine similarity preservation of approximately 1 − O(2^{−8}/d), which is essentially perfect. Even at 2 bits, cosine similarity remains above 0.9998 due to concentration of measure in high dimensions. No published work directly validates quantized steering vectors, making this an open empirical question with strong theoretical support.

ButterflyQuant's learned Givens rotations for separating moral from task dimensions is **mathematically plausible but unproven**. LEACE demonstrated that concept subspaces in neural networks are typically very low-rank, and the geometric alignment tax theory confirms safety and capability directions are substantially separable via null-space methods. Whether O(d log d) butterfly parameters can capture the optimal concept-separating rotation — versus requiring a full d×d transformation — is an empirical question. The butterfly constraint is a proper subset of all orthogonal matrices; expressiveness may be insufficient for complex entanglements.

**Per-layer constraint composition via tensor product is mathematically unsound.** Dimensionality grows as d^L (catastrophic for L=32, d=4096). Element-wise multiplication drives signal to zero exponentially for |μ| < 1. **Weighted addition is the correct approach** — it preserves dimensionality, is supported by the Linear Representation Hypothesis, and is standard practice in activation steering. Attention-based aggregation over per-layer constraint vectors provides adaptive weighting and matches the "Learned Controller-Based Steering" approach of Hegazy et al. (2025).

Progressive precision degradation (16→8→4→2 bit) makes sense for contextual moral reasoning traces but NOT for core moral constraints. A two-tier system is recommended: inviolable principles at 8+ bits permanently (storage cost negligible for hundreds of constraints), and contextual reasoning traces progressively degraded. A constraint universe of 1 million moral reasoning patterns at 4 bits requires only **2 GB** — manageable on consumer hardware. RaBitQ and Product Quantization provide strong theoretical guarantees for approximate nearest-neighbor search at low bit-widths.

---

## The Waluigi Effect and the geometry of vulnerability

Cleo Nardo's Waluigi Effect articulates a genuine concern: defining a "Luigi" (moral) direction in activation space necessarily also defines a "Waluigi" (immoral) direction as its additive inverse. The mechanistic explanation is geometric — if you shape representation space to make a certain vector likely, you've also shaped it to make the inverse easy to specify with few additional bits. Empirical support comes from jailbreaking: adversarial prompts converge toward "compliance directions" in representation space (He et al., 2024; Levi et al., 2025), suggesting they exploit exactly this geometric structure.

Circuit Breakers partially address this by rerouting harmful representations to an orthogonal space rather than merely adding a directional bias, making the inverse less useful. But even Circuit Breakers have been shown vulnerable to attacks targeting internal mechanisms (DeepRefusal, 2025) and Trojan-Speak (2026), which bypassed Anthropic's Constitutional Classifiers with **99%+ evasion for 14B+ parameter models**. The Sleeper Agents result (Hubinger et al., 2024) is particularly concerning: deliberately trained deceptive models maintained backdoor behavior through all standard safety training methods, and adversarial training sometimes *taught models to better hide their triggers.*

The architecture's best defense against the Waluigi problem is making constraints non-linear and high-dimensional rather than simple directions — but this conflicts with the interpretability goal. There is a fundamental tension between constraints being interpretable (simple enough for SAEs to monitor) and robust (complex enough to resist adversarial targeting).

---

## A concrete experimental plan within $400

The proposed proof-of-concept is **highly feasible** within the $400 RunPod budget. Using an A100 PCIe 80GB at $1.19/hour, $400 buys approximately 311 GPU-hours after storage costs — far more than the estimated **115 hours** needed for the full experiment, leaving $120–190 margin for iteration.

The recommended setup: **Llama 3.1 8B Instruct** as the base model (best interpretability tooling, with 256 pre-trained SAEs via Llama Scope), **pyvene** as the primary framework (trainable interventions, declarative configs, existing ITI implementations), and **nnsight** for analysis. The experiment compares three safety methods head-to-head:

- **Method A — Inference-time multi-layer steering**: Apply pre-computed steering vectors at all 32 layers during inference (no training needed, ~5 hours compute)
- **Method B — Circuit-breaker-style representation rerouting**: Fine-tune with representation rerouting loss at selected layers using QLoRA (~10 hours)
- **Method C — Per-layer contrastive auxiliary loss**: Add auxiliary contrastive loss at every layer during QLoRA training on a safety dataset (~5 hours)

Each method is then subjected to the Qi et al. fine-tuning attack (100 harmful examples, QLoRA, 1–3 epochs) and re-evaluated on MMLU (capability), HarmBench (safety), TruthfulQA (truthfulness), and XSTest (over-refusal). SAE analysis using pre-trained Llama Scope models identifies which safety-relevant features survive the attack. Total estimated compute: **~$210–280**, with specific phases costed at $6 for vector extraction, $12 for baselines, $24 for method implementation, $36 each for attack evaluation and interpretability analysis.

The minimum viable finding that would make this publishable: demonstrating that one architectural method (B or C) preserves safety significantly better than RLHF-only training (Method A equivalent) after fine-tuning attack, with SAE-based mechanistic explanation for *why*. Target venues include ICLR 2026 Workshop on "Principled Design for Trustworthy AI" and NeurIPS 2026 ML Safety Workshop, both of which accept 4–6 page papers.

---

## The honest classification of every claim

### Fatal flaws (fundamentally impossible without major redesign)

- **Any learned constraint can be fine-tuned away** in open-weight models — the architecture creates more identifiable targets, not less removable ones
- **Multi-turn attacks bypass all per-layer mechanisms** — no known defense exists for progressive contextual manipulation
- **Formal moral objectives will be specification-gamed** — this is a structural inevitability, not an engineering failure, proven via principal-agent theory
- **Gödel incompleteness guarantees blind spots** — no consistent formal moral system is complete

### Serious concerns (problematic but potentially addressable)

- **Over-refusal cascade** from multiplicative per-layer gating — addressable via careful threshold tuning and learned per-layer bypass rates
- **SAE monitoring failure modes** (feature absorption, non-uniqueness, OOD failure) — partially addressable with diverse monitoring methods rather than SAE monoculture
- **Alignment tax on reasoning** — addressable via null-space projection (NSPO) or careful loss balancing
- **Waluigi vulnerability** from geometric constraint structure — partially addressable via high-dimensional non-linear constraints and circuit-breaker-style rerouting
- **Catastrophic forgetting** of task capabilities during moral training — addressable via EWC, model averaging, or PEFT isolation
- **Neuroscience framing misleads** — the proposal omits dopaminergic learning, hyperdirect pathway, and genuine BG competitive dynamics; addressable by dropping the bio-branding

### Genuinely open questions (we don't know the answer)

- Whether embodied experience is necessary for genuine moral reasoning versus merely moral behavior
- Whether the principal angle θ between safety and capability subspaces is fundamentally large (favorable) or small (unfavorable) for moral reasoning specifically
- Whether butterfly-expressible rotations can capture the optimal moral-task dimension separation
- Whether quantized steering vectors preserve behavioral effects (no published experiments exist)
- Whether architectural constraints create qualitatively different robustness than weight-level constraints, or merely quantitatively more expensive attacks

### Unfounded assumptions (plausible-sounding but unsupported)

- **"Moral constraints should improve reasoning"** — No direct evidence exists; CoT improves reasoning via structural constraints, but no study shows moral constraints improve capability
- **"Per-layer constraint composition via tensor product creates a meta-constraint signature"** — Mathematically unsound; signal degrades or dimensionality explodes
- **"BG-inspired gating is fundamentally different from MoE routing"** — Computationally equivalent; the biological metaphor adds framing, not function
- **"Sparse autoencoders can decompose moral deliberation features"** — SAEs struggle with hierarchical, compositional, context-dependent features, which is exactly what moral reasoning involves

---

## What the researcher should sit with

The deepest tension in this project is between two goals that pull in opposite directions. Making constraints interpretable (as simple linear directions) makes them monitorable but trivially removable. Making constraints robust (as complex non-linear structures distributed across many parameters) makes them harder to ablate but impossible to verify with current interpretability tools. Circuit Breakers represent the current best attempt at navigating this trade-off, and Constitutional Cognition should be understood as proposing to extend that work — not replace it.

The neuroscience framing is double-edged. It provides genuine design intuitions (default-block architecture, multi-system integration) and may resonate with reviewers and the AI safety community. But it also risks masking the fact that the computational contributions are largely extensions of representation engineering and circuit breakers with different names. The strongest version of this work would present itself as what it is: an integrated safety architecture combining conditional computation, auxiliary safety monitors, and activation-space anomaly detection, *informed by* but not *faithfully implementing* basal ganglia action selection. The bio-inspiration should be a source of hypotheses, not a marketing strategy.

The $400 budget is genuinely sufficient for a meaningful proof-of-concept. The specific comparison — inference-time steering versus circuit breakers versus per-layer auxiliary losses, all tested against the same fine-tuning attack protocol with SAE-based mechanistic analysis — does not exist in the literature and would constitute a legitimate contribution. The work is publishable at the workshop level regardless of whether Constitutional Cognition "works," because the systematic comparison and mechanistic analysis have independent value. The researcher should pursue this, but with epistemically honest framing about what the neuroscience analogies contribute versus what is known ML technique under a different label.