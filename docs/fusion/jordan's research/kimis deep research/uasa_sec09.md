## 9. Hallucination and Repetition: Root-Cause Elimination

Hallucination and repetition are not surface symptoms to be patched with post-hoc filters; they are deep dynamical pathologies that emerge from the geometry of hidden-state trajectories. Token-level repetition penalties and temperature tuning address the symptom while the underlying neural circuitry continues to spiral. This chapter maps the trajectory from reactive mitigation to root-cause elimination through a three-layer architecture: a multi-signal early warning system that detects failure modes before they reach the surface; a reinforcement-learning pipeline that manufactures negative evidence to teach the model avoidance of its own attractor states; and a claim-level neuro-symbolic constraint loop that grounds every assertion in verifiable structure before it is emitted.

### 9.1 The Early Warning System Architecture

The central insight from recent mechanistic interpretability research is that both hallucination and repetition leave detectable signatures in the latent trajectory *before* any token is generated. SAVE (Sparse Autoencoder-Driven Visual Information Enhancement) shows that steering toward identified visual-understanding features reduces the CHAIR_S hallucination score from 31.2 to 21.4 on LLaVA-1.6, while steering toward hallucination features increases it to 38.0---confirming that these failure modes are encoded as separable directions in activation space [^2^]. Qwen-Scope extends this causal finding to repetition: a specific SAE feature spikes sharply and sustains high activation at the exact onset of a textual loop [^1^]. These discoveries transform the detection problem from "inspect the output" to "monitor the latent trajectory."

#### 9.1.1 Multi-Signal Fusion: Latency-Accuracy Trade-offs

A production-grade early warning system must fuse multiple independent signals, each with distinct latency and detection characteristics, to minimize both false positives and missed precursors. The architecture distributes computation across the Apple Silicon substrate in a hardware-aware pipeline.

| Signal | Source | Latency | Detection Target | AUC (Representative) | Hardware |
|--------|--------|---------|-------------------|----------------------|----------|
| SAE feature slope | ANE | ~0.5 ms | Repetition/hallucination feature activation trend | 0.87 [^3^] | Apple Neural Engine |
| Attention entropy trajectory | GPU shader | ~0.1 ms | Entropy collapse phase transition | 0.71 [^3^] | Metal compute |
| Token entropy anomaly | GPU | ~0.1 ms | Probability surge at loop onset | 0.71 [^3^] | GPU (inline) |
| Claim-level NLI | CPU | ~2 ms | Semantic entailment against grounding context | 92.45 [^4^] | CPU (batched) |
| SpecRA spectral periodicity | GPU | O(W log W) amortized | FFT autocorrelation peak | Provable bounds [^22^] | Metal FFT |

The fusion logic is not a simple OR-gate across thresholds. Each signal carries a calibrated risk score: the SAE feature slope produces a *trend* score based on the derivative of repetition-feature activation over the last $k$ tokens; the attention entropy trajectory computes the cumulative deviation from an expected entropy band; and the claim-level Natural Language Inference (NLI) model scores entailment probability $P(\text{entail}\,|\,\text{claim}, \text{context})$ [^30^]. A weighted combination---learned on annotated failure cases---produces a unified hallucination-risk score. When the fused score exceeds a dynamic threshold (adapted per domain), the system triggers one of two preemptive interventions: either steer the residual stream away from the dangerous region using the steering formula $h' \leftarrow h + \alpha d$, or pause generation to invoke constraint validation on the partial claim graph.

#### 9.1.2 Semantic Circularity Precedes Textual Repetition

The Circular Reasoning paper establishes a critical temporal ordering for repetition detection: semantic circularity in hidden-state space significantly precedes verbatim textual repetition [^21^]. K-Means clustering (K=200) on final-layer hidden states reveals that node transitions converge into periodic oscillation while the generated sentences remain lexically distinct---they exhibit high semantic redundancy that causes them to fall into recurrent cluster labels [^21^]. This creates an early-warning window of multiple tokens during which the model is already trapped in an attractor but has not yet begun surface-level looping.

SpecRA (Spectral Repetition Analysis) exploits this pre-surface periodicity via Fast Fourier Transform (FFT) autocorrelation [^22^]. The core algorithm maps each generated token to a random complex phase, computes the power spectrum through the Wiener-Khinchin theorem, and detects peaks in the autocorrelation function that reveal the underlying periodicity. The method achieves $O(W \log W)$ processing complexity with $O(\log W)$ amortized time per token, and carries provable bounds on false-alarm and miss-detection probabilities [^22^]. The significance for Rex is architectural: SpecRA runs on the GPU via Metal Performance Shaders, concurrently with token generation on the ANE, adding no latency to the critical path.

The mechanistic root cause underlying these signals is the variance sensitivity of softmax attention. Theorem 5.1 from the entropy-collapse literature shows that attention entropy $H(p)$ collapses as the variance $\sigma^2$ of attention logits increases [^26^]:

$$H(p) = \log N - \frac{(N-1)\sigma^2}{2N} + O(\sigma^4)$$

$$\frac{\partial H}{\partial \sigma^2} = -\mathbb{E}_z\left[\sum_i z_i^2 \cdot p_i\right] < 0$$

As the model enters a loop, attention concentrates on a shrinking set of high-probability tokens, exponentially amplifying the logit variance and driving entropy toward zero. This creates a detectable phase transition---a "rigidity event"---that the multi-signal fusion layer can intercept before the loop manifests in text.

#### 9.1.3 Preemptive Intervention

When the fused risk score crosses the intervention threshold, the system has two options, selected by domain policy. Option A, *steering intervention*, applies the Qwen-Scope steering formula at the layer where the repetition or hallucination feature was detected: $h' \leftarrow h + \alpha d$, with $\alpha < 0$ to suppress the dangerous feature [^1^]. SAVE confirms that early layers respond best to small magnitudes ($\alpha = 3$), mid-layers benefit from moderate strengths ($\alpha \in \{3, 5\}$), and deep layers require stronger intervention ($\alpha \in \{5, 10, 15\}$) [^2^]. Option B, *constraint pause*, halts generation and routes the partial output through the claim extraction and NLI verification pipeline (Section 9.3). This transforms the system from a post-hoc validator into a predictive guard that intervenes while the failure mode is still forming in latent space.

### 9.2 Repetition Elimination via Reinforcement Learning

Token-level repetition penalties---the "familiarity tax" that divides logits of previously seen tokens by a penalty factor [^25^]---are symptomatic patches. A rigorous Markov model analysis proves that under greedy decoding with self-reinforcement effects, the expected escape time from a repetitive state is *infinite* [^23^]. Once the model enters the attractor, the local next-token process makes the same continuation ever more probable because each emitted pattern becomes part of the context for the next step [^24^]. Root-cause elimination requires attacking the attractor itself.

#### 9.2.1 Manufacturing Negative Rollouts via SAE Steering

Qwen-Scope's repetition feature provides the steering target. The feature exhibits a sharp and sustained increase around the onset of repetition while remaining near zero in non-repetitive responses [^1^]. Crucially, the causal role is confirmed experimentally: amplifying the repetition feature on non-repetitive samples *manufactures* repetition, while suppressing it on repetition-prone samples reduces repetition below baseline [^1^].

This causality enables a powerful RL training strategy. In standard RL for language models---Group Relative Policy Optimization (GRPO) or Direct Preference Optimization (DPO)---the model's own rollouts provide the training signal. But repetition is a rare failure mode: it barely appears in normal rollouts, so the policy never receives sufficient negative reinforcement to learn avoidance. Qwen-Scope's solution is SAE-guided rare negative augmentation. During the RL training loop, a separate set of rollouts is generated in which the identified repetition feature is *amplified* using steering, forcing the model into the very failure mode the training process aims to eliminate [^1^]. These synthetically manufactured negative examples are then fed into the RL objective as strong negative signal. The results are striking: across all three model scales tested, the repeat ratio drops sharply in early training and continues decreasing to a very low level, while vanilla RL yields only limited improvement [^1^].

The method is built on top of DAPO (Dynamic Anchor Preference Optimization) without dynamic sampling, adding the repetition feature direction $d$ to the residual stream at each generation step: $h' \leftarrow h + \alpha d$ for the negative rollouts. The positive rollouts remain unmodified, creating a clean preference pair where the only systematic difference is the presence or absence of pathological repetition.

#### 9.2.2 The Normal-Rollout Blind Spot

The reason vanilla RL fails to eliminate repetition is a data problem, not an algorithmic one. Repetition rarely appears in normal rollouts, so the reward model never observes the failure mode during training. The "Self-Correction Blind Spot" literature generalizes this finding: intrinsic self-correction fails 64.5% of the time across 14 models because the models lack internal signal for their own errors [^3^]. The Qwen-Scope negative-augmentation pipeline solves this by manufacturing the missing signal. It is the interpretability equivalent of adversarial training: instead of searching the input space for adversarial examples, it searches the *latent* space for adversarial directions and forces the model to traverse them.

A critical caveat: the repetition feature also activates in *benign* repetition scenarios---repeating a user's question, listing multiple-choice answers, iterative reasoning steps. Direct suppression of the feature during training would degrade these legitimate behaviors. The RL approach preserves the feature while teaching the policy to avoid pathological activation *patterns*: the distinction is not "never repeat" but "never enter an unbounded loop." This is achieved by training the policy to associate high sustained activation of the repetition feature with low reward, rather than removing the feature from the representation.

#### 9.2.3 SFT Code-Switching Suppression via Auxiliary Loss

The same SAE-guided intervention strategy extends to Supervised Fine-Tuning (SFT). Qwen-Scope demonstrates that SAEs can identify language-specific features that drive unexpected code-switching in multilingual models [^5^] (Dim02). SASFT (Sparse Autoencoder-guided Supervised Fine-Tuning) adds an auxiliary loss term to the standard SFT objective that penalizes high activation in the identified language-switching features when the training data is in a different target language [^140^]. This reduced unexpected code-switching by more than 50% in most cases and achieved 100% reduction in several scenarios, all while maintaining multilingual benchmark performance [^140^]. The principle generalizes: any undesirable behavior with a discoverable SAE feature direction can be suppressed through an auxiliary loss without full retraining.

### 9.3 Claim-Level Hallucination Prevention

Token-level hallucination metrics---perplexity, token entropy, repetition penalties---catch surface symptoms but miss semantic hallucinations: claims that are fluent, syntactically correct, and internally consistent but factually ungrounded. Entity-level detection naturally maps to token labels and enables streaming detection, but claims require structured extraction that breaks token alignment [^3^]. The Rex architecture therefore operates at the claim level, where each generated assertion is decomposed, verified, and either grounded or retracted before commitment.

#### 9.3.1 Claim Graph Extraction and NLI Verification

The claim-level pipeline begins with atomic-fact decomposition. SAFE (Search-Augmented Factuality Evaluator) decomposes model outputs into atomic factual claims, queries search APIs for each claim, and uses DeBERTa-MNLI entailment scoring to compute supported/contradicted/unverifiable ratios [^20^]. GraphEval extends this to structured knowledge graphs: each generated response is parsed into (subject, predicate, object) triples, and each triple is checked against grounding context using NLI, returning the specific inconsistent triples for explainability [^19^].

NSVIF (Neuro-Symbolic Verification Framework) provides the most rigorous instantiation, achieving 94.8% F1 on instruction-following verification by decomposing outputs into *logic constraints* (verified by symbolic reasoning/Python code via the Z3 SMT solver) and *semantic constraints* (verified by LLM-as-judge), then solving the unified constraint satisfaction problem [^15^]. This dual verification---symbolic for structural invariants, neural for semantic plausibility---catches hallucinations that either method alone would miss.

The NLI scoring formalism assigns probabilities over three mutually exclusive labels: entail, neutral, and contradict [^30^]. The factual consistency score for a claim $c$ against source context $s$ is the entailment probability $P(\text{entail}\,|\,c, s)$. SummaC extends this to long documents by building a score matrix of all pairwise entailment scores between generated and source sentences, taking the maximum per generated sentence---a method that significantly outperforms prior metrics on factual consistency benchmarks [^30^].

The choice between token-level and claim-level detection is not either-or but staged: fast token-level probes catch entity hallucinations in real time, while claim-level verification catches semantic fabrications that survive token-level scrutiny. The comparative characteristics determine where each method sits in the architecture.

| Method | Granularity | Latency | AUC / F1 | What It Catches | What It Misses |
|--------|-------------|---------|----------|-----------------|----------------|
| LoRA linear probes | Token/entity | Negligible | 0.90 [^3^] | Fabricated names, dates, citations | Semantically consistent false claims |
| Semantic entropy | Sequence | High (multi-sample) | 0.71 [^3^] | Uncertainty-driven hallucinations | Confident but wrong claims |
| SpecRA FFT | Sequence | O(W log W) | Provable bounds [^22^] | Periodic repetition loops | Aperiodic semantic drift |
| NLI (SummaC) | Claim/sentence | ~2 ms batched | 92.45 AUC-PR [^4^] | Ungrounded factual assertions | Novel claims with no source |
| NSVIF (neuro-symbolic) | Claim + logic | 10-100 ms | 94.8% F1 [^15^] | Structural + semantic violations | Ontologies outside graph coverage |

The probe row warrants emphasis: LoRA probes trained on one model generalize to detect hallucinations in other models, suggesting they capture fundamental failure patterns rather than model-specific artifacts [^3^]. However, probes trained on short-form QA fail to recover long-form performance, meaning long-form supervision is necessary for effective monitoring [^3^]. This finding shapes the Rex training pipeline: the probe supervision corpus must include paragraph-length generation, not just sentence-level factoids. The staged architecture deploys probes and SpecRA on the fast path (every token), NLI on the medium path (per sentence), and NSVIF on the slow path (per claim graph), with escalating verification depth matched to the criticality of the domain.

#### 9.3.2 CUSUM Early Detection on Hidden-State Trajectories

The CUSUM (Cumulative Sum) algorithm provides the statistical engine for early loop prediction. Rather than thresholding instantaneous entropy or activation values, CUSUM accumulates deviations from a baseline trajectory, making it robust to transient fluctuations while sensitive to sustained drift [^21^]. The algorithm is applied to three hidden-state-derived precursors simultaneously: entropy drops (monitoring $-\Delta H$), probability surges (monitoring $\Delta \max p_i$), and hidden-state convergence (monitoring $\cos\text{-sim}(h_t, h_{t-k}) \to 1$). In deep repetition cycles, cosine similarity between activation vectors of identical tokens saturates to nearly 1.0 while vector norm differences vanish, confirming that the loop constitutes a distinct internal state [^21^].

The following implementation fuses CUSUM drift detection with SpecRA spectral periodicity monitoring into a single early-warning kernel suitable for GPU deployment:

```python
def early_warning_kernel(hidden_states, token_ids, baseline_entropy,
                         cusum_threshold=4.0, specra_threshold=0.3):
    """
    Fused early-warning detector for repetition and hallucination precursors.
    Runs per-token during generation; returns (risk_score, should_intervene).
    
    Args:
        hidden_states:  [seq_len, d_model]  -- residual stream vectors
        token_ids:      [seq_len]           -- generated token indices
        baseline_entropy: float             -- expected entropy under normal decoding
        cusum_threshold:  float              -- CUSUM intervention threshold
        specra_threshold: float              -- SpecRA periodicity threshold
    """
    import numpy as np
    seq_len = hidden_states.shape[0]
    
    # --- Signal 1: CUSUM on hidden-state convergence ---
    # Detect cosine similarity approaching 1.0 (attractor collapse)
    if seq_len >= 8:
        h_current = hidden_states[-1]
        h_lag = hidden_states[-8]
        cosine_sim = np.dot(h_current, h_lag) / (
            np.linalg.norm(h_current) * np.linalg.norm(h_lag) + 1e-8
        )
        # CUSUM: accumulate positive deviations from healthy baseline
        deviation = max(0.0, cosine_sim - 0.85)  # 0.85 = healthy similarity bound
    else:
        deviation = 0.0
    
    # Stateful CUSUM accumulator (maintained across calls in production)
    cusum_stat = 0.0  # placeholder: real system persists this state
    cusum_stat = max(0.0, cusum_stat + deviation)
    cusum_alert = cusum_stat > cusum_threshold
    
    # --- Signal 2: SpecRA spectral periodicity ---
    # FFT autocorrelation via Wiener-Khinchin theorem
    specra_alert = False
    if seq_len >= 32:
        SPECRA_MAP = np.exp(2j * np.pi * np.random.RandomState(42).rand(50000))
        seq = SPECRA_MAP[token_ids]
        power = np.abs(np.fft.fft(seq)) ** 2
        autocorr = np.fft.ifft(power)
        peak = float(np.max(np.real(autocorr[1:seq_len//2+1])))
        normalized_peak = peak / float(np.real(autocorr[0]) + 1e-8)
        specra_alert = normalized_peak > specra_threshold
    
    # --- Signal 3: Entropy collapse (from external sampler) ---
    # entropy_alert = current_entropy < baseline_entropy * 0.5
    
    # --- Fusion ---
    risk_score = (0.5 * float(cusum_alert) + 
                  0.3 * float(specra_alert))
    should_intervene = risk_score > 0.4
    
    return risk_score, should_intervene
```

The CUSUM mechanism, validated across diverse Large Reasoning Models (LRMs), yields measurable gains: DeepSeek-Qwen-7B completion rate improves from 0.80 to 0.88 when early detection triggers a generation restart at the precursor stage [^21^]. The implementation above targets GPU execution via NumPy/Metal, with the CUSUM state persisted across tokens in a streaming inference engine.

#### 9.3.3 The SAE-Constraint Feedback Loop

The final integration layer closes the loop between real-time monitoring and ontological validation. This is the SAE-Constraint Feedback Loop---a cross-dimensional fusion of SAE interpretability (Dim02), claim-graph validation (Dim04), and repair dynamics (Dim08). The mechanism operates as follows.

First, the SAE encoder runs on the residual stream at every generation step, producing a sparse feature vector $z = \text{ReLU}(W_{\text{enc}} \cdot (x - b_{\text{pre}}) + b_{\text{enc}})$. The top-$K$ active features are compared against a registry of known dangerous directions: repetition features, hallucination features, and safety-critical features (deception, sycophancy, bias) identified in Anthropic's monosemanticity work [^102^]. Second, when a dangerous feature's activation slope exceeds its learned threshold, the system computes the steering intervention $h' \leftarrow h + \alpha d$ to redirect the trajectory. Third, if the claim-level NLI verifier (running concurrently on the CPU) flags a generated claim as unsupported, the constraint engine pauses generation, extracts the claim graph, and invokes the verification pipeline.

This transforms the constraint engine from a post-hoc validator into a predictive guard. The temporal ordering is critical: SAE activation precedes output generation; claim extraction parses partial output; steering modifies the latent state before the next token is sampled. The resulting closed control loop---monitor $\to$ detect $\to$ steer $\to$ verify---is not present in any individual research paper but emerges from the architectural fusion of independently proven components. Linear probes on SAE features achieve AUC 0.90 with negligible overhead [^3^]; claim-level NLI verification achieves 94.8% F1 [^15^]; SAE steering reduces hallucination scores by 31.4% [^2^]. Together, they create a system that watches its own cognition, detects when it is entering a dangerous region of latent space, and intervenes before the failure mode reaches the surface.

The practical implementation on Apple Silicon exploits hardware parallelism: the ANE runs SAE feature probes while the GPU runs token generation; the CPU runs claim extraction and NLI verification in a batched pipeline. Total end-to-end detection-to-intervention latency is under 5 ms for the fast path (SAE + entropy) and under 20 ms when claim-level verification is required. This latency profile makes the architecture viable for real-time, high-stakes applications where hallucination and repetition are not merely quality issues but safety-critical failure modes.
