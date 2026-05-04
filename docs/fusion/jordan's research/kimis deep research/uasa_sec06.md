# 6. The Repair Loop: Self-Correction, GRPO, and Active Inference

A deterministic substrate that claims superintelligence must do more than generate text—it must recognize its own errors, repair them, and converge on correct outputs through principled feedback. This chapter examines the empirical and theoretical foundations of iterative self-correction, the reinforcement learning methods that train models to reason, and the formal framework that tells us when to stop repairing and commit to an answer. The findings are sobering: intrinsic self-correction fails most of the time, but tool-augmented repair converges reliably within 1–3 iterations. Group Relative Policy Optimization (GRPO) eliminates the critic model, cutting memory consumption roughly in half while pushing mathematical reasoning benchmarks upward. And the Free Energy Principle provides a first-principles stopping criterion—repair continues only while the expected information gain from another iteration exceeds the pragmatic value of the current best answer.

![Figure 1: Left panel—GRPO eliminates the critic model, reducing memory footprint by ~25–50% relative to PPO. Right panel—empirical repair loop convergence curves show rapid gains in the first iteration followed by a plateau, consistent with single-exponential convergence models.](fig_sec06_repair_grpo.png)

## 6.1 The Propose-Extract-Constrain-Verify-Repair-Commit Cycle

### 6.1.1 Structural Isomorphism to Active Inference

The Rex repair loop—Propose, Extract, Constrain, Verify, Repair, Commit—is not an ad hoc prompting pattern. It maps, stage by stage, onto the Active Inference formalism developed under the Free Energy Principle (FEP). Active Inference frames decision-making as minimization of Expected Free Energy (EFE), which decomposes into an epistemic term (expected information gain) and a pragmatic term (expected utility) [^9^]. Variational Free Energy (VFE) is minimized in relation to data already gathered (perception and inference), while EFE is minimized for selecting data that will best optimize beliefs (planning and action) [^10^]. This distinction between inference-about-observations and inference-about-actions provides the theoretical scaffolding for why a staged repair loop works, and where each stage belongs in the computational pipeline.

Table 1 presents the explicit mapping between the Rex operational stages and their Active Inference counterparts. The isomorphism is structural: every Rex stage has a direct mathematical analogue in the FEP framework, suggesting that the repair loop is not merely an engineering convenience but an approximate implementation of variational inference over policies.

| Rex Stage | Active Inference Equivalent | Mathematical Expression | Functional Role |
|-----------|---------------------------|------------------------|-----------------|
| **Propose** | Policy selection from prior preferences | $\pi = \arg\min_\pi G(\pi)$ | Generate candidate outputs via policy model sampling |
| **Extract** | Observation generation (sampling from generative model) | $o \sim p(o \mid s, \pi)$ | Parse proposals into structured claims with citations [^11^] |
| **Constrain** | Prior enforcement with infinite precision on violation | $p(o \mid C) = \delta(\text{consistent})$ | Apply ontological rules; hard constraints generate infinite prediction error on violation |
| **Verify** | Variational Free Energy minimization (perception) | $\mathcal{F} = D_{KL}[q(s) \| p(s \mid o)]$ | Compute surprise of observations against generative model; high VFE triggers repair |
| **Repair** | Epistemic foraging (information gain from new policies) | $\text{EFE}_{\text{epistemic}} = -\mathbb{E}[D_{KL}]$ | Select alternative policies expected to resolve uncertainty |
| **Commit** | Posterior belief update (state transition) | $q'(s) = q(s \mid o)$ | Fix repaired output as updated system state; persist to memory |

The mathematical foundation for this mapping rests on the EFE objective for a policy $\pi$:

$$G_\pi = -\mathbb{E}_Q\left[D_{KL}[Q(s \mid o, \pi) \| Q(s \mid \pi)]\right] - \mathbb{E}_Q\left[\ln P(o \mid C)\right]$$

The first term is epistemic value: the expected information gain from executing policy $\pi$ and observing the outcome. The second term is pragmatic value: the log-probability of observations under the constraint prior $C$. In Rex terms, **Propose** samples policies, **Constrain** encodes $P(o \mid C)$, **Verify** evaluates $D_{KL}$ (surprise), and **Repair** selects policies with higher epistemic value when surprise remains high. Recent theoretical work has established that sufficient curiosity—weight on the epistemic term—simultaneously ensures Bayesian posterior consistency and bounded cumulative regret for EFE-minimizing agents [^12^], providing the first formal convergence guarantee for repair-loop-like dynamics.

The practical instantiation of this framework in LLM-based agents has been demonstrated experimentally: an Active Inference cognitive layer operating above multiple LLMs dynamically adjusts prompts and search strategies through principled information-seeking behavior, with action selection patterns revealing transitions from initial information-gathering to targeted prompt testing [^13^]. This empirically validates that the EFE formalism, when approximated via confidence scores and repair success rates, can govern real multi-agent repair behavior.

### 6.1.2 The Self-Correction Blind Spot

The most important empirical finding for repair loop design is also the most cautionary: large language models exhibit a systematic "Self-Correction Blind Spot." Across 14 models tested, the average failure rate is 64.5%—models that successfully correct identical errors when presented externally fail to correct them in their own outputs at substantially higher rates [^3^]. The root cause is training data composition: human demonstrations contain only 5–10% correction markers, so the knowledge to detect errors exists in the model but is not activated during self-evaluation.

A theoretical framework formalizes when self-evaluation fails: when the generator and evaluator share failure modes, self-evaluation can be non-identifying—agreement between generator and evaluator provides weak evidence of correctness. The proposed architectural remedy is **context separation**: fresh-context evaluation, tool use, and formal verification break the correlated error structure [^2^]. This directly motivates why Rex's repair loop is tool-augmented by design rather than relying on the model to critique its own output in isolation.

The training data perspective illuminates why the blind spot persists. In RL-derived datasets, the density of correction markers is 30–170× higher than in human demonstrations, yet even this elevated density does not eliminate the structural problem. The model's evaluation capacity and generation capacity are not independent random variables; they are drawn from the same parameter distribution, subject to the same biases and blind spots. Tools—calculators, compilers, proof assistants, retrieval systems—introduce genuinely independent error distributions, making cross-verification statistically valid in a way that self-verification cannot be.

The simple "Wait" intervention—prompting the model to pause before evaluating—reduces blind spots by 89.3% [^3^], suggesting that temporal separation between generation and evaluation partially decouples failure modes. However, this is a mitigation, not a solution. The structural unreliability of intrinsic self-correction means that any production repair architecture must incorporate external verifiers as first-class components, not optional enhancements.

### 6.1.3 Tool-Augmented Correction: CRITIC and Self-Debugging

When external feedback is available, repair loops achieve substantial and reproducible gains. CRITIC (Tool-Interactive Critiquing) enables LLMs to validate and progressively amend outputs through interaction with search engines, calculators, and code interpreters, achieving 7.7 F1 improvement on question-answering tasks and 7.9% absolute gains on mathematical reasoning [^4^]. The authors explicitly note that "exclusive reliance on self-correction without external feedback may yield modest improvements or even deteriorate performance" [^4^]—a finding that aligns with the 64.5% blind spot measurement and reinforces the tool-augmented design principle.

In code domains, Self-Debugging teaches models to debug predicted programs via execution feedback, achieving state-of-the-art performance on Spider (text-to-SQL) and TransCoder (C++→Python), with accuracy improvements of up to 12% on MBPP where unit tests serve as perfect verifiers [^5^]. The convergence pattern is consistent: most improvement occurs in the first verification-repair iteration, with diminishing returns thereafter. Program repair studies similarly find that limiting total patches to 10 aligns with developer practices, and iterative strategies like 4-3-3 (4 initial, 3+3 subsequent) outperform single-generation of 10 [^23^].

## 6.2 GRPO: Efficient Reinforcement Learning for Reasoning

### 6.2.1 Eliminating the Critic Model

Proximal Policy Optimization (PPO) has been the workhorse algorithm for RL-based fine-tuning of language models, but it carries a substantial architectural burden: the value function (critic model) is typically another model of comparable size to the policy, doubling memory requirements and complicating training dynamics [^6^]. Group Relative Policy Optimization (GRPO), introduced in DeepSeekMath, eliminates the critic model entirely, replacing it with a statistical baseline computed from grouped sample outcomes [^6^].

The memory reduction is substantial. For a 7B parameter model, PPO requires loading four models in memory: policy (7B), value/critic (7B), reference (7B), and reward (7B)—28B parameters total. GRPO requires only three: policy (7B), reference (7B), and reward (7B)—21B parameters, a 25% reduction in baseline configuration. Empirical measurements report peak GPU memory requirements dropping by over 40% in practice, because GRPO also reduces from two backward passes per update (policy + value) to one [^18^]. The freed capacity enables larger batch sizes or bigger models within the same memory envelope.

The performance gains are equally significant. On the MATH benchmark, DeepSeekMath-7B improved from 46.8% to 51.7% using GRPO; on GSM8K, from 82.9% to 88.2% [^6^]. These improvements are out-of-domain as well as in-domain, indicating that GRPO trains generalizable reasoning patterns rather than benchmark-specific memorization. The DeepSeek-R1-Zero model, trained with pure GRPO and no supervised fine-tuning cold start, spontaneously developed self-verification and reflection behaviors, improving AIME 2024 pass@1 from 15.6% to 71.0% during training—behaviors that the researchers described as an emergent "aha moment" when the model learned to rethink [^20^]. The final DeepSeek-R1 model, with a small SFT cold start before RL, achieved 79.8% on AIME 2024, demonstrating that GRPO scales from 7B to hundreds of billions of parameters while maintaining its efficiency advantages.

### 6.2.2 Group-Relative Advantage Estimation

GRPO's core innovation is the replacement of learned value estimates with intra-group normalization. For each question, the algorithm samples $G$ outputs from the current policy, computes a reward for each (e.g., 1 if the answer is correct, 0 otherwise), and normalizes rewards within the group to obtain advantages:

$$\hat{A}_{i,t} = \frac{r_i - \text{mean}(\{r_j\}_{j=1}^G)}{\text{std}(\{r_j\}_{j=1}^G)}$$

The same advantage is assigned to every token in a completion under outcome supervision; under process supervision, the advantage accumulates from subsequent step rewards [^6^]. The GRPO objective then applies the standard PPO clipped surrogate, but with this group-relative baseline:

$$\mathcal{J}_{\text{GRPO}}(\theta) = \mathbb{E}_{q \sim P(Q), \{o_i\} \sim \pi_{\theta_{\text{old}}}(O|q)} \left[ \frac{1}{G} \sum_{i=1}^{G} \frac{1}{|o_i|} \sum_{t=1}^{|o_i|} \min\left( \frac{\pi_\theta(o_{i,t}|q,o_{i,<t})}{\pi_{\theta_{\text{old}}}(o_{i,t}|q,o_{i,<t})} \hat{A}_{i,t}, \; \text{clip}(\cdot, 1-\epsilon, 1+\epsilon) \hat{A}_{i,t} \right) - \beta D_{KL}[\pi_\theta \| \pi_{\text{ref}}] \right]$$

This formulation is simpler than PPO in three respects: no critic network to train, no Generalized Advantage Estimation (GAE) hyperparameters to tune, and no per-token value targets to compute. Comparative studies confirm that GRPO and its descendant DAPO consistently outperform base models across transfer-learning evaluations, with larger group sizes leading to more stable training dynamics and higher accuracy [^19^]. The theoretical reinterpretation of GRPO identifies it as a form of contrastive learning: the minimum group size $G=2$ is necessary for stable training, but practical configurations use $G=8$ to $G=16$ for variance reduction. The impact of the KL-penalty coefficient $\beta$ is non-monotonic—too low and the policy diverges from the reference; too high and exploration is suppressed—requiring per-task tuning typically in the range $[0.001, 0.01]$.

The trade-off is coarse-grained credit assignment: all tokens in a response share the same reward, which can disadvantage long chain-of-thought reasoning where only a subset of tokens contains errors. A reasoning chain of 2,000 tokens receives a single scalar reward, meaning the gradient signal is distributed uniformly across all positions regardless of where the actual mistake occurred. Extensions such as Posterior-GRPO (P-GRPO) mitigate this by conditioning process-based reasoning rewards on task success: when the outcome reward $R^o = 1$, the thinking reward $R^t$ is preserved; when $R^o \neq 1$, $R^t = 0$ [^21^]. This gated design ensures that the model is only incentivized to explore superior reasoning paths for solutions that are functionally correct, preventing the policy from learning elaborate but incorrect reasoning styles that game the process reward without improving final accuracy.

### 6.2.3 Local Feasibility and Rule-Based Rewards

GRPO is feasible for 7B models on 128GB Apple Silicon Unified Memory Architecture (UMA) systems. The memory budget during training is dominated by policy parameters, reference model parameters, optimizer states, and rollout buffers. With 4-bit quantization for inference-phase generation and optimizer states in 32-bit, the total active memory for a 7B model falls within the 128GB envelope:

```python
# GRPO advantage estimation on Apple Silicon (MLX-like pseudocode)
import mlx.core as mx

def compute_grpo_advantage(rewards: mx.array, group_size: int) -> mx.array:
    """
    rewards: flat array of shape (batch_size * group_size,)
    Returns: advantage array of same shape, group-relative normalized
    """
    # Reshape to (batch_size, group_size)
    rewards_grouped = rewards.reshape(-1, group_size)
    
    # Compute per-group statistics
    reward_mean = rewards_grouped.mean(axis=1, keepdims=True)   # (batch_size, 1)
    reward_std = rewards_grouped.std(axis=1, keepdims=True)     # (batch_size, 1)
    
    # Normalize: (r_i - mean) / (std + epsilon)
    advantage = (rewards_grouped - reward_mean) / (reward_std + 1e-8)
    
    return advantage.reshape(-1, 1)   # (batch_size * group_size, 1)

# Example: 32 unique questions, 16 rollouts each, rule-based math reward
def rule_based_math_reward(completion: str, ground_truth: str) -> float:
    """
    Extract final answer from completion (boxed or final number)
    and compare against ground truth. No neural reward model.
    """
    extracted = extract_final_answer(completion)
    return 1.0 if numeric_match(extracted, ground_truth, rtol=1e-5) else 0.0
```

The rule-based reward design is critical for avoiding reward hacking. DeepSeek-R1-Zero intentionally avoided neural reward models "because we find that the neural reward model may suffer from reward hacking in the large-scale reinforcement learning process" [^10^]. Instead, R1-Zero used only accuracy rewards (verifiable via compiler or test cases against ground-truth answers) and format rewards (enforcing structured reasoning tags). This minimalist reward scheme achieved AIME 2024 pass@1 improvement from 15.6% to 77.9% without any supervised fine-tuning cold start [^20^].

For local deterministic substrates, the lesson is clear: GRPO's simplicity—no critic model, rule-based rewards, group-relative baselines—translates directly into deployable pipelines where external verifiers (compilers, SMT solvers, unit tests) provide the reward signal. The elimination of learned reward models removes a major source of instability and a vector for reward exploitation.

## 6.3 Convergence and Proactive Repair

### 6.3.1 Empirical Convergence Rates

Repair loops exhibit predictable convergence dynamics when external feedback is available. The evolution of correct answer rates under $t$ rounds of self-correction follows a single-exponential model:

$$\text{Acc}_t = \text{Upp} - \alpha^t(\text{Upp} - \text{Acc}_0)$$

where $\text{Acc}_0$ is the initial accuracy, Upp is the fixed-point (converged) accuracy, and $\alpha$ is the convergence rate determined by the model's confidence in preserving correctness and its critique quality [^35^]. Empirical measurements across math and code tasks confirm that most improvement occurs in the first 1–2 iterations; additional iterations show diminishing returns and can degrade performance if the error introduction rate exceeds the error correction rate [^36^].

A control-theoretic Markov diagnostic formalizes this: intrinsic self-correction has two critical rates, EIR (Error Introduction Rate) and ECR (Error Correction Rate). When $\text{EIR} > \text{ECR}$, refinement loops diverge and harm performance [^36^]. The diagnostic reveals non-stationarity in these rates—EIR increases from 1.3% to 3.8% across iterations—suggesting that fixed-iteration stopping is suboptimal and adaptive thresholds based on real-time rate monitoring are preferable. For math reasoning specifically, program repair studies find optimal strategies at 2–3 iterations, with the first patch generated being the most likely to be correct [^23^].

### 6.3.2 Proactive Self-Refinement (PASR)

The preceding analysis assumes post-hoc repair: generate fully, then verify and revise. Proactive Self-Refinement (PASR) inverts this pattern by intervening during generation rather than after. PASR, an RL-based proactive refinement method, reduces token consumption by 41.6% while increasing accuracy by 8.2% on Qwen3-8B, versus post-hoc baselines that often degrade performance without oracle feedback [^8^].

The mechanism is conditional: the model learns to detect when its current reasoning trajectory is likely to fail and inserts a repair operation mid-generation rather than completing a full incorrect chain. This requires training on a mixture of standard completions and interrupted completions where the model is forced to backtrack and restart from an earlier reasoning step. Training uses a specialized reward structure: the model receives a positive reward for successfully completing after an interruption, a small negative reward for unnecessary interruptions (false positives), and a larger negative reward for failing to interrupt before an irreversible error. This multi-component reward signal teaches the model to calibrate its uncertainty threshold—intervening early enough to avoid wasted computation but not so early that it interrupts correct reasoning trajectories.

The result is fewer wasted tokens on dead-end reasoning paths and faster convergence to correct answers. On Qwen3-8B, PASR achieves its 41.6% token reduction specifically by eliminating the long incorrect reasoning chains that models often generate before realizing their mistake in a post-hoc critique. Instead of generating 500 tokens of wrong derivation, then 200 tokens of critique, then 400 tokens of corrected derivation (1,100 tokens total), the proactive model interrupts after 150 tokens, restarts, and completes in 400 tokens (550 tokens total)—a 50% reduction that matches the empirical average.

PASR's efficacy depends on the same principle that makes GRPO successful: the reward signal must be verifiable and non-gameable. When trained with outcome rewards that can be verified by external execution (code compilation, numerical evaluation), proactive refinement learns to discriminate productive from unproductive reasoning trajectories. Without such verifiable rewards, proactive intervention has no training signal and the model cannot learn when to interrupt itself.

### 6.3.3 Expected Free Energy as Stopping Criterion

The final and most consequential question for a repair loop is: when should it stop? The Expected Free Energy formalism provides a principled answer. Repair should continue while the epistemic value (expected information gain) of an additional repair iteration exceeds its pragmatic cost (token consumption, latency, computational budget). The stopping condition is:

$$\text{Repair if: } \underbrace{-\mathbb{E}[D_{KL}[q(s \mid o, \pi) \| q(s \mid \pi)]]}_{\text{epistemic value}} > \underbrace{\lambda \cdot C_{\text{token}}}_{\text{pragmatic cost}}$$

where $\lambda$ is a task-dependent exchange rate between information and computation. In practical terms, this means: continue repairing if the model expects to learn something new from another iteration; stop when the expected gain falls below the cost of generation.

Table 2 translates this abstract criterion into operational thresholds for different task categories. The epistemic value proxy is approximated by the variance of repair outcomes across recent iterations; high variance indicates that the repair process is still exploring productively, while low variance suggests convergence. The pragmatic cost proxy is token consumption per iteration, which is directly measurable.

| Task Category | Epistemic Value Proxy | Pragmatic Cost Proxy | Typical Stopping Point | Key Source |
|--------------|----------------------|---------------------|------------------------|------------|
| Math reasoning | Variance of group rewards (GRPO) | Tokens per rollout | 1–2 iterations [^6^] | Diminishing returns after first verification |
| Code generation | Unit test pass rate variance | Tokens + compile time | ≤10 patches; optimal at 2–3 [^23^] | First patch most likely correct |
| QA / factuality | Claim-level NLI disagreement | Tokens + retrieval latency | 1 iteration [^4^] | Single verification cycle sufficient |
| Open-ended generation | Entropy of candidate set | Tokens + judge latency | 3–4 iterations [^11^] | SELF-REFINE max $k=3$ optimal |
| Proactive refinement | Trajectory confidence score | Interrupt + restart tokens | Mid-generation, 0–2 restarts [^8^] | PASR conditional on uncertainty |

The epistemic-pragmatic balance is not merely a theoretical construct; it is instantiated in the design choices of working systems. DeepSeek-R1-Zero spontaneously developed self-verification and reflection behaviors through pure RL, with the frequency of reflective terms ("wait," "verify," "check") increasing throughout training [^20^]. This emergent behavior suggests that the EFE objective, when approximated through rule-based rewards on verifiable outcomes, naturally induces the epistemic drive to seek additional information before committing.

Precision weighting provides a complementary control mechanism. In Active Inference, the prior over policies is $\pi_0 = \sigma(-\gamma \cdot G)$, where $\gamma$ is an inverse precision (temperature) parameter that governs exploration-exploitation balance. High precision ($\gamma \to \infty$) makes the agent almost deterministic, selecting the single policy with lowest EFE; low precision permits broader exploration. In Rex terms, safety-critical constraints should operate at infinite precision (hard constraints that must never be violated), while creative or exploratory tasks can use lower precision to permit a broader search over candidate policies. The precision scheduler thus becomes a runtime-configurable safety dial: high precision for verification gates, lower precision for proposal generation.

For the deterministic substrate, the operational protocol is: (1) **Propose** with multiple candidates when epistemic uncertainty is high (high VFE after initial generation), using a temperature-tuned sampling policy that balances diversity against coherence; (2) **Extract** and **Constrain** with hard priors that generate infinite prediction error on violation, encoded as executable ontological rules that can be checked in milliseconds; (3) **Verify** via external tools, not self-evaluation, with staged verification—fast path for syntactic and type constraints, medium path for unit-test execution, slow path for formal proof when available; (4) **Repair** only if the expected information gain from another iteration exceeds a token-cost threshold, computed from the variance of recent repair outcomes; (5) **Commit** when VFE falls below a precision-weighted bound, with the commitment logged as an immutable state transition for deterministic replay.

The convergence of these lines of evidence—empirical repair loop studies, GRPO training dynamics, and Active Inference formalism—suggests that reliable self-correction is achievable, but only under strict architectural preconditions. External verification is non-negotiable: the 64.5% blind spot for intrinsic correction [^3^] means that any loop without tool augmentation is structurally unreliable. Rule-based rewards are essential: learned reward models invite hacking [^10^]. And proactive refinement outperforms post-hoc repair when the training signal is clean [^8^]. The substrate that integrates these findings—tool-augmented verification, GRPO-trained reasoning, and EFE-governed stopping—represents a significant departure from standard inference pipelines, but one that the empirical literature increasingly supports.
