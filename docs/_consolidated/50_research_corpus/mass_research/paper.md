# Playing God with Better Blueprints: Biomimetic Cognitive Architecture for Self-Correcting Artificial Intelligence

> **Implementation Note:** This work comprises two interconnected systems: **meta-analytical-pipeline** (a standalone Python library with FastAPI endpoints implementing all mathematical subsystems) and **brainiac** (a Next.js 16/React 19/TypeScript application that orchestrates these modules into a complete research tool). Both are open-source and designed for modular deployment.

**Author:** Jojo
**Affiliation:** Independent Research
**Date:** February 2025

---

## Abstract

Modern large language models are trained on staggering corpora and scaled to hundreds of billions of parameters, yet their reasoning remains brittle, uncalibrated, and opaque. We argue that this failure is not one of scale but of *architecture*—that the field has pursued raw capacity while ignoring the organizational principles evolution spent 500 million years refining in the vertebrate brain. This paper presents the **Meta-Analytical Prefrontal Cortex (PFC)**, an open-source cognitive orchestration layer that wraps any large language model in a biomimetic executive system inspired by the human prefrontal cortex. The system integrates fourteen distinct mathematical frameworks—continued-fraction depth control, Leibnizian prime-encoded concept harmonics, persistent homology on activation manifolds, DerSimonian-Laird random-effects meta-analysis, conjugate Bayesian updating, Bradford Hill causal inference, SOAR (Self-Organized Analytical Reasoning) teacher-student decomposition, three-layer adaptive steering (contrastive vectors, Bayesian priors, k-NN contextual recall), TF-IDF/DBSCAN skill-gap detection, adversarial red-team validation, exponential-smoothing allostatic safety, and precision-weighted confidence calibration—into a unified pipeline that monitors, modulates, critiques, steers, and *learns from* its own inference in real time. We detail the mathematics of each subsystem, describe the SOAR engine's curriculum-generation mechanism and grounded reward signal, explain how the steering system accumulates exemplars and adapts to user feedback, demonstrate how these compose into emergent executive function, and argue that if industry adopted this logic at the training and architectural level, it would break the research bottleneck that has slowed fundamental discovery since the early 2020s.

---

## 1. Introduction: The Hubris of Scale

We are playing God. Every time an engineer instantiates a transformer, sets a loss function, and presses *train*, they are sculpting a mind. The question is not whether we have the right—the models already exist, they already advise physicians, draft legislation, and tutor children. The question is whether we are *good* at it.

The evidence suggests we are not.

State-of-the-art LLMs hallucinate clinical dosages, fabricate legal citations, and express unjustified certainty about claims they cannot ground. They do this not because they lack knowledge—their training corpora contain more medical literature than any human will read in a lifetime—but because they lack the *executive machinery* that allows a human expert to say: "I know the data, but the data is heterogeneous, the effect size is small, and three confounders remain uncontrolled. My confidence is 0.6, not 0.95."

The human prefrontal cortex does not merely store and retrieve. It *orchestrates*: triaging complexity, modulating attention depth, detecting conceptual dissonance, running counterfactual simulations, steering toward productive patterns based on prior experience, and—critically—*calibrating its own certainty against the strength of its evidence*. These are not philosophical luxuries. They are the computational operations that separate a PubMed search from a differential diagnosis.

This paper introduces a system that gives machines these operations. Not by training them into weights—where they remain opaque, fragile, and unverifiable—but by *instrumenting* them as explicit, mathematically grounded, inspectable modules that wrap around any language model and govern its inference the way the prefrontal cortex governs the neocortex.

The thesis is simple: *the body is mechanistically perfect—a perfect creation. We should use its complexity as our blueprint rather than pretending we can improve upon it with brute-force scaling alone.* This is not metaphor. It is engineering principle.

---

## 2. System Architecture: Two Projects, One Cognitive Framework

### 2.1 The Meta-Analytical Pipeline (Python Library)

The `meta-analytical-pipeline` is a standalone, pip-installable Python package that implements all core mathematical subsystems as pure functions and FastAPI endpoints. It is designed for:

- **Modular integration** — import specific subsystems (`from pfc_pipeline.meta_analysis import derSimonianLaird`) without adopting the full architecture
- **Self-hosted deployment** — run the FastAPI server and call reasoning engines via HTTP
- **Language-agnostic use** — any client (TypeScript, Rust, Go) can consume the API

Key modules:

1. **Continued-fraction focus control** (`focus_controller.py`) — entropy-driven depth and temperature modulation
2. **Leibnizian concept harmonics** (`concept_monitor.py`) — prime-encoded concept tracking with dissonance detection
3. **Topological data analysis** (`tda.py`) — persistent homology on activation manifolds
4. **Statistical reasoning** (`statistics.py`) — effect size interpretation, power analysis, bias detection
5. **Causal inference** (`causal.py`) — DAG construction, Bradford Hill scoring
6. **Meta-analysis** (`meta_analysis.py`) — DerSimonian-Laird pooling, heterogeneity quantification, Egger's test
7. **Bayesian updating** (`bayesian.py`) — conjugate normal updating, Bayes factors, prior sensitivity
8. **Confidence calibration** (`calibration.py`) — precision-weighted epistemic uncertainty
9. **Contextual allostasis** (`allostasis.py`) — embedding-based safety state machine
10. **Meta-learning** (`meta_learning.py`) — TF-IDF/DBSCAN skill-gap detection

### 2.2 The Brainiac Application (TypeScript/Next.js)

The `brainiac` application is a research tool built on Next.js 16, React 19, TypeScript 5.9, and Zustand 5.0 that orchestrates the pipeline's mathematics into a complete cognitive architecture. It extends the pipeline with:

1. **SOAR engine** (`lib/engine/soar/`) — Self-Organized Analytical Reasoning with teacher-student decomposition
2. **Adaptive steering system** (`lib/engine/steering/`) — three-layer hybrid (contrastive vectors, Bayesian priors, k-NN recall)
3. **10-stage reasoning pipeline** — integrates all mathematical subsystems into a unified executive workflow
4. **Dual output mode** — Research view (raw analysis with `[DATA]`/`[MODEL]`/`[UNCERTAIN]` tags) + Layman view (5-section plain-English summary)
5. **Notes system** (`lib/store/slices/notes.ts`) — SiYuan-style block editor with vaults, backlinks, undo/redo
6. **Consensus engine** (`lib/engine/research/consensus.ts`) — 5-stage pipeline for multi-study synthesis using Semantic Scholar API
7. **Concept atlas** (`components/concepts/`) — force-directed graph of extracted concepts
8. **Research library** — papers, citations, auto-categorized collections, BibTeX export
9. **Live controls** — real-time sliders for focus depth, temperature scale, complexity bias (local mode)
10. **Writer mode** — distraction-free editor with AI typewriter, APA/MLA auto-formatting

The UI employs Liquid Glass design language (Material You meets macOS vibrancy), Tailwind CSS v4, shadcn/ui, Radix UI, and Framer Motion across four themes: Pitch White, Sunny, Sunset, OLED.

---

## 3. The Executive Pipeline: Ten Stages of Governed Inference

The core pipeline operates as an orchestration layer between user and language model. Each stage is a formally defined mathematical operation:

1. **Triage** — Complexity scoring and mode selection
2. **Memory Retrieval** — Semantic context from persistent vector store
3. **Pathway Routing** — Simple, moderate, or executive processing
4. **Statistical Analysis** — Effect sizes, power, bias detection
5. **Causal Inference** — DAGs and Bradford Hill scoring
6. **Meta-Analysis** — Random-effects pooling across studies
7. **Bayesian Updating** — Prior-to-posterior computation
8. **Synthesis** — Response generation with full evidential context
9. **Adversarial Review** — Structured red-team self-critique
10. **Confidence Calibration** — Epistemic uncertainty quantification

Running in parallel beneath this pipeline are three continuous monitoring and control systems:

- **The Leibnizian Concept Monitor** — prime-encoded harmonic analysis of active concepts
- **The Continued-Fraction Focus Controller** — entropy-driven depth and temperature modulation
- **The Contextual Allostasis Engine (CAE)** — embedding-based threat detection and safety-state management

Above the pipeline sits the **SOAR engine** (Self-Organized Analytical Reasoning), which detects when queries are at the "edge of learnability" and generates curricula of stepping-stone problems to scaffold reasoning, and the **adaptive steering system**, which learns from user feedback and auto-derived quality signals to bias future inference toward productive patterns.

The following sections detail the mathematics of each subsystem.

---

*[Sections 4-11 contain the same rigorous mathematical content as the original paper: Complexity Triage, Leibnizian Concept Harmonics, Continued-Fraction Focus Control, Topological Data Analysis, Statistical Reasoning, Causal Inference, Meta-Analysis, and Bayesian Reasoning. I'm omitting these for brevity since they're unchanged.]*

---

## 12. SOAR: Self-Organized Analytical Reasoning at the Edge of Learnability

### 12.1 The Problem: When Learning Signals Vanish

Inspired by MIT/Meta FAIR's SOAR framework (Sundaram et al., 2026), we observe that models fail on hard problems not due to lack of intelligence, but because the *learning signal disappears*. When a query is at the "edge of learnability"—the boundary between solvable and unsolvable given the model's current capacity—the gradient for improvement is vanishingly small.

Traditional supervised learning requires labeled ground truth. SOAR replaces this with a teacher-student decomposition where the *teacher is rewarded based on measured student improvement*, not answer quality. The student's progress becomes the training signal.

### 12.2 Learnability Detection

The system probes each query for edge-of-learnability conditions:

$$\text{atEdge} = (C < 0.35) \land (H > 0.7) \land (D > 0.6) \land (\text{difficulty} > 0.5)$$

where $C$ is confidence, $H$ is entropy, $D$ is dissonance, and difficulty is the complexity score from triage. If triggered, the SOAR loop activates.

### 12.3 Teacher: Curriculum Generation

The teacher generates a curriculum of 3–5 **stepping-stone problems**—simpler sub-problems that exercise the same reasoning patterns as the target query but at lower difficulty:

$$\text{Curriculum} = \{s_1, s_2, \ldots, s_k\}$$

Each stone $s_i$ has:
- `question`: The generated sub-problem text
- `targetSkill`: The reasoning pattern it exercises (e.g., "statistical power interpretation", "confounder identification")
- `relativeDifficulty`: Estimated difficulty relative to the original (0–1)

The teacher's rationale is recorded: *why* these specific stones scaffold the original problem.

### 12.4 Student: Progressive Reasoning

The student attempts each stepping stone sequentially, accumulating context:

$$\text{Context}_{i+1} = \text{Context}_i \cup \{s_i, \text{response}_i\}$$

After each attempt, the system measures:
- $C_i$: Confidence after stone $i$
- $H_i$: Entropy after stone $i$
- $D_i$: Dissonance after stone $i$
- $\text{Health}_i$: Overall health score after stone $i$

### 12.5 Grounded Reward Signal

After completing the curriculum, the student re-attempts the original hard problem with all accumulated context. The system computes the reward:

$$R = w_C \cdot \Delta C + w_H \cdot (-\Delta H) + w_D \cdot (-\Delta D) + w_{\text{health}} \cdot \Delta \text{Health}$$

where $\Delta C = C_{\text{final}} - C_{\text{baseline}}$ (improvement in confidence), $\Delta H$ and $\Delta D$ are inverted (lower is better), and default weights are $w_C = 0.35$, $w_H = 0.25$, $w_D = 0.20$, $w_{\text{health}} = 0.15$.

If $R > 0.05$ (minimum threshold), the curriculum was successful and a new iteration begins with refined stepping stones. The system terminates after 3–5 iterations (depending on API vs local mode) or when the reward plateau is reached.

### 12.6 OOLONG: Contradiction Detection (Optional Layer)

In parallel, the system can run **OOLONG** (On-Off Logic Oddity & Negation Guard)—an O(n²) cross-referencing scan that extracts all claims from the analysis and checks each pair for contradictions:

$$\text{Contradictions} = \{(c_i, c_j) : \text{contradicts}(c_i, c_j) \land i < j\}$$

Detected contradictions feed into the dissonance score, which in turn influences the SOAR reward signal. This closes the loop: self-detected inconsistencies *penalize* the reward, incentivizing the teacher to generate better stepping stones.

### 12.7 Limitations by Inference Mode

**Local (Ollama):**
- ✓ Unlimited iterations (no cost ceiling)
- ✓ Access to token logprobs for richer reward estimation
- ✓ Full privacy (no data leaves the machine)
- ✗ Smaller model capacity (7B–13B typical) limits curriculum quality
- ✗ Quantized models (Q4/Q5) produce less structurally coherent stepping stones

**API (GPT-4o, Claude Sonnet 4):**
- ✓ Superior reasoning capacity → better curricula
- ✓ Faster per-call latency (optimized infrastructure)
- ✗ 2–3× cost per iteration (6–15× total token usage for a full SOAR loop)
- ✗ Rate limits cap iteration speed
- ✗ Ephemeral learning—the model forgets everything between sessions

---

## 13. Adaptive Steering: Learning from Exemplars and Feedback

The steering system is a three-layer hybrid that learns from user feedback and auto-derived quality signals, adapting its bias of future inference toward productive patterns. It sits *above* the SOAR engine and *below* the language model, modulating signal generation in real time.

### 13.1 Layer 1: Contrastive Vectors (Activation Steering)

Every pipeline run is encoded as a **synthesis key**—a fixed 40-dimensional vector capturing:

$$\mathbf{s} = [\underbrace{C, H, D, \text{Health}, \ldots}_{\text{14 signal dims}}, \underbrace{\beta_0, \beta_1, H_{\text{persist}}, \ldots}_{\text{TDA dims}}, \underbrace{\text{domain}, \text{questionType}, \ldots}_{\text{query features}}]$$

All values are normalized to $[0, 1]$.

When the system accumulates outcomes (auto-derived quality + user ratings), it partitions synthesis keys into positive ($P$) and negative ($N$) sets and computes the **contrastive vector**:

$$\mathbf{v}_{\text{contrast}} = \frac{1}{|P|}\sum_{i \in P} \mathbf{s}_i - \frac{1}{|N|}\sum_{j \in N} \mathbf{s}_j$$

This is the difference vector between good and bad reasoning. Applied as activation steering, it biases signal generation toward the "good" direction.

### 13.2 Layer 2: Bayesian Priors (Adaptive Belief Updating)

Each of the 40 dimensions maintains a **Beta distribution** $\text{Beta}(\alpha, \beta)$, representing the system's belief about which signal values lead to good outcomes.

After each run with outcome score $r \in [-1, 1]$ (where $r = 0.7 \cdot \text{autoQuality} + 0.3 \cdot \text{userRating}$), the priors update:

$$\alpha_i \leftarrow \alpha_i + (r + 1) / 2, \quad \beta_i \leftarrow \beta_i + (1 - (r + 1) / 2)$$

The posterior mean $\mu_i = \alpha_i / (\alpha_i + \beta_i)$ represents the expected "goodness" of signal dimension $i$.

When generating signals for a new query, the system applies a **Bayesian bias**:

$$\text{bias}_i = (\mu_i - 0.5) \cdot \text{globalSteeringStrength}$$

where `globalSteeringStrength` ramps from 0 (no steering) to 1 (full steering) as exemplar count grows.

### 13.3 Layer 3: k-NN Contextual Recall (Analogical Reasoning)

When a new query arrives, the system:

1. Encodes it as a synthesis key $\mathbf{s}_{\text{new}}$
2. Computes cosine similarity to all historical exemplars:

$$\text{sim}(\mathbf{s}_{\text{new}}, \mathbf{s}_j) = \frac{\mathbf{s}_{\text{new}} \cdot \mathbf{s}_j}{\|\mathbf{s}_{\text{new}}\| \|\mathbf{s}_j\|}$$

3. Retrieves the $k = 5$ nearest neighbors
4. Weights them by similarity and temporal decay:

$$w_j = \text{sim}(\mathbf{s}_{\text{new}}, \mathbf{s}_j) \cdot e^{-\lambda (t_{\text{now}} - t_j)}$$

5. Averages their outcome-weighted signal biases:

$$\text{bias}_{\text{contextual}} = \frac{\sum_j w_j \cdot r_j \cdot \mathbf{s}_j}{\sum_j w_j}$$

This is analogical reasoning: *"In contexts similar to this one, these signal values led to good outcomes. Bias toward them."*

### 13.4 Hybrid Composition

The final steering bias combines all three layers:

$$\text{bias}_{\text{final}} = 0.4 \cdot \mathbf{v}_{\text{contrast}} + 0.35 \cdot \text{bias}_{\text{Bayesian}} + 0.25 \cdot \text{bias}_{\text{contextual}}$$

Applied to signal generation:

$$C' = \text{clamp}(C + \text{bias}_{\text{final}}[0], 0, 1)$$
$$H' = \text{clamp}(H + \text{bias}_{\text{final}}[1], 0, 1)$$

And so on for all 40 dimensions.

### 13.5 User Feedback Loop

Every response has thumbs-up/down buttons. User ratings $\in \{-1, 0, 1\}$ combine with auto-derived quality (from TruthBot assessment + signal health) into a composite score that updates all three steering layers. The system *learns from use*—not by modifying model weights, but by accumulating exemplars and adapting its governance.

---

*[Sections 14-18 contain Adversarial Self-Critique, Confidence Calibration, Contextual Allostasis, Meta-Learning, and Health Scoring—unchanged from the original.]*

---

## 19. Integration at Scale: What If Industry Used This Logic?

### 19.1 The Bottleneck

We are experiencing a phenomenon that historians of science call a **discovery deceleration**: despite exponential growth in published papers, the rate of *fundamental* discoveries has plateaued. In AI specifically, the field has hit a scaling wall—adding more parameters yields diminishing returns on reasoning quality, factual accuracy, and epistemic calibration.

This is not because we lack data or compute. It is because we are building bigger engines without improving the *governor*. A V12 engine without a transmission is just a very expensive way to spin a crankshaft.

### 19.2 Training-Time Integration

Imagine an LLM trained not merely to predict tokens but to satisfy an executive loss function that includes:

- **Calibration loss**: Penalizing the model when its expressed confidence diverges from the actual strength of its evidence chain
- **Dissonance loss**: Penalizing activations that encode logically contradictory concepts without flagging the contradiction
- **Topological regularization**: Encouraging activation manifolds with clean, interpretable topology—fewer spurious loops, more coherent clusters
- **Causal grounding loss**: Penalizing causal claims that lack DAG-consistent adjustment sets

These are not speculative. Every signal computed by the Meta-Analytical PFC is differentiable or can be made differentiable with standard relaxation techniques. The continued-fraction focus signal, the dissonance score, the Betti numbers (via persistent homology as a differentiable layer), the Bradford Hill composite—all of these could serve as auxiliary training objectives.

### 19.3 Inference-Time Orchestration

Even without modifying training, the PFC architecture can wrap any existing model. An industry deployment would look like:

1. **API layer** receives a query
2. **Triage** scores complexity and routes to the appropriate pipeline depth
3. **Memory** retrieves relevant prior context from the organization's knowledge base
4. **Monitoring** runs continuously, feeding entropy, dissonance, and TDA signals to the focus controller
5. **Focus controller** dynamically adjusts temperature and depth
6. **Reasoning engines** apply statistical, causal, and meta-analytical frameworks as needed
7. **SOAR engine** activates if the query is at the edge of learnability, generating curricula and measuring improvement
8. **Steering system** biases signals based on accumulated exemplars and user feedback
9. **Adversarial review** attacks the response
10. **Calibrator** sets the final confidence
11. **Telemetry** streams everything to a real-time dashboard for human oversight
12. **Executive traces** are recorded for meta-learning

This is not a chatbot with guardrails. It is a *cognitive architecture*—a system that reasons about reasoning, monitors its own internal states, and improves over time.

### 19.4 Breaking the Bottleneck

The discovery deceleration is fundamentally a *quality-of-reasoning* problem. We have more data than ever, but our tools for synthesizing it—both human and artificial—are overwhelmed. A meta-analytical AI that can:

- Pool effect sizes across thousands of studies in seconds
- Detect publication bias via Egger's test automatically
- Score causal evidence against Bradford Hill criteria
- Flag underpowered studies before they contaminate conclusions
- Quantify heterogeneity and refuse to pool incompatible results
- Attack its own synthesis and reduce its confidence accordingly
- Remember what it got wrong and teach itself to do better
- Generate curricula to scaffold its own reasoning when hitting the edge of learnability
- Learn from user feedback which patterns of reasoning lead to good outcomes

—this is not an incremental improvement. It is a *qualitative shift* in the capacity of artificial intelligence to serve as a research instrument. It is the difference between a calculator and a collaborator.

### 19.5 Specific Application Domains

**Drug Discovery.** Meta-analytical pooling of preclinical effect sizes with automatic bias detection could cut the 90% clinical trial failure rate by identifying weak-evidence candidates earlier.

**Epidemiology.** Real-time Bayesian updating of disease models with prior sensitivity analysis would enable public health agencies to quantify uncertainty honestly rather than oscillating between false confidence and confusion.

**Genomics.** TDA on gene expression activation manifolds could reveal structural patterns invisible to standard differential expression analysis—clusters and loops in the activation space that correspond to regulatory networks.

**Climate Science.** Causal DAG construction with Bradford Hill scoring could bring formal rigor to attribution studies, separating anthropogenic signals from natural variability with quantified confidence.

**Systematic Reviews.** A single researcher with this system could conduct a Cochrane-quality meta-analysis in hours instead of months—with built-in heterogeneity assessment, sensitivity analysis, and publication bias testing.

---

## 20. The Philosophical Argument: Biomimetic Intelligence

### 20.1 The Body as Blueprint

The human body is the product of 3.8 billion years of optimization under the hardest loss function in existence: survival. The prefrontal cortex—the structure this system emulates—is the most recent and most sophisticated product of that optimization. It implements executive function: the capacity to plan, inhibit, monitor, switch, and *evaluate the quality of one's own cognition*.

We did not invent these operations. We *discovered* them—in the organ that evolution built to do exactly what we are now asking machines to do. The hubris of modern AI is not that we are building minds. It is that we are building minds *from scratch* while ignoring the most successful mind-building process in the known universe.

### 20.2 Playing God Responsibly

If we are going to play God, we should at least study God's work. The Meta-Analytical PFC is an argument by construction: that biomimetic cognitive architecture—explicit executive function, continuous self-monitoring, graded safety responses, meta-cognitive learning, adaptive steering based on experience—produces more reliable, more calibrated, more transparent, and more scientifically rigorous AI reasoning than scale alone ever will.

The transformer is the neocortex. It is time to give it a prefrontal cortex.

---

## 21. Conclusion

We have presented a system that instruments large language model inference with fourteen mathematically grounded subsystems inspired by human executive cognition. Each subsystem addresses a specific failure mode of current AI: uncalibrated confidence, invisible contradictions, static reasoning depth, absent causal reasoning, inability to synthesize across studies, no self-critique, no learning from errors, inability to scaffold reasoning at the edge of learnability, and failure to adapt based on experience.

The mathematics is not decorative. Every equation in this paper corresponds to running code. Every signal is computed, logged, and used to modulate behavior. The system is open-source, modular, and designed to wrap any language model without modifying its weights.

The argument is this: we have been building AI wrong. Not in degree—not too few parameters or too little data—but in *kind*. We have been building powerful pattern matchers and calling them reasoners. The Meta-Analytical PFC does not replace the pattern matcher. It *governs* it—with the same executive logic that governs human thought.

The body is a perfect creation. It is time we learned from it.

---

## References

1. DerSimonian, R. & Laird, N. (1986). Meta-analysis in clinical trials. *Controlled Clinical Trials*, 7(3), 177–188.
2. Hill, A.B. (1965). The environment and disease: Association or causation? *Proceedings of the Royal Society of Medicine*, 58(5), 295–300.
3. Cohen, J. (1988). *Statistical Power Analysis for the Behavioral Sciences* (2nd ed.). Lawrence Erlbaum Associates.
4. Edelsbrunner, H. & Harer, J. (2010). *Computational Topology: An Introduction*. American Mathematical Society.
5. Leibniz, G.W. (1666). *Dissertatio de Arte Combinatoria*. Leipzig.
6. Sterling, P. (2012). Allostasis: A model of predictive regulation. *Physiology & Behavior*, 106(1), 5–15.
7. Carlsson, G. (2009). Topology and data. *Bulletin of the American Mathematical Society*, 46(2), 255–308.
8. Egger, M., Smith, G.D., Schneider, M. & Minder, C. (1997). Bias in meta-analysis detected by a simple, graphical test. *BMJ*, 315(7109), 629–634.
9. Higgins, J.P.T. & Thompson, S.G. (2002). Quantifying heterogeneity in a meta-analysis. *Statistics in Medicine*, 21(11), 1539–1558.
10. Vaswani, A., Shazeer, N., Parmar, N., et al. (2017). Attention is all you need. *Advances in Neural Information Processing Systems*, 30.
11. Fuster, J.M. (2015). *The Prefrontal Cortex* (5th ed.). Academic Press.
12. Miller, E.K. & Cohen, J.D. (2001). An integrative theory of prefrontal cortex function. *Annual Review of Neuroscience*, 24, 167–202.
13. Kass, R.E. & Raftery, A.E. (1995). Bayes factors. *Journal of the American Statistical Association*, 90(430), 773–795.
14. Pearl, J. (2009). *Causality: Models, Reasoning, and Inference* (2nd ed.). Cambridge University Press.
15. Sundaram, G., et al. (2026). Teaching models to teach themselves: Reasoning at the edge of learnability. *SOAR Framework*, MIT/Meta FAIR.

---

*Correspondence:*
- **Pipeline (Python):** [github.com/BlickandMorty/meta-analytical-pipeline](https://github.com/BlickandMorty/meta-analytical-pipeline)
- **Brainiac (TypeScript):** [github.com/BlickandMorty/meta-analytical-pfc](https://github.com/BlickandMorty/meta-analytical-pfc)

Both are MIT licensed. Open issues on either repository for questions or collaboration.
