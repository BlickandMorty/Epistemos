# Neural Network Editing and Model Surgery: A Deep Research Compendium

## 1. Introduction and Scope

Neural network editing and model surgery comprise a family of techniques for modifying trained models without full retraining. These methods enable knowledge updates, behavior modification, safety tuning, and capability transfer in large language models (LLMs). This document surveys the state of the art across activation steering, rank-one editing, mass editing, parameter-efficient adaptation, weight patching, model merging, safety-oriented unlearning, and practical implementation for local 7B--8B models.

---

## 2. Activation Steering and Representation Engineering (RepE)

### 2.1 Core Concept

Activation steering modifies internal neural activations during the forward pass to influence behavior without changing weights [^2363^]. The fundamental operation is:

$$
\tilde{h} = h + \alpha \cdot v_{\text{steer}}
$$

Where $h$ is the original activation, $v_{\text{steer}}$ is the steering direction, and $\alpha$ is a scalar steering strength [^2363^]. Steering vectors are typically derived from contrastive examples:

$$
v_{\text{steer}} = \text{mean}(h_{\text{positive}}) - \text{mean}(h_{\text{negative}})
$$

### 2.2 Representation Engineering Framework

Zou et al. (2023) formalized Representation Engineering (RepE) as a top-down approach to AI transparency [^595^]. The framework unifies three capabilities:

1. **Read**: Identify what the model represents (via linear probes, CAA, LAT)
2. **Control**: Steer behavior through intervention (addition or ablation)
3. **Analyze**: Interpret what interventions reveal about model mechanics [^2672^]

Key insight: the direction a linear classifier uses to *detect* a concept is the same direction you *add* to induce that concept, or *project out* to eliminate it [^2672^].

### 2.3 Contrastive Activation Addition (CAA)

CAA (Panickssery et al., 2024) provides positive and negative examples of a behavior, collects activations, and takes the mean difference between sets to calculate a steering vector [^598^]. The concept operator is a vector used to steer the model with regard to high-level behavioral characteristics.

### 2.4 Anthropic's Sparse Autoencoder (SAE) Steering

In "Scaling Monosemanticity," Anthropic demonstrated remarkable SAE-based steering on Claude 3 Sonnet, extracting ~34 million interpretable features [^2363^]. The famous "Golden Gate Bridge" experiment showed that clamping a specific feature to maximum activation caused Claude to claim to *be* the Golden Gate Bridge. Other successes included reducing buggy code generation, mitigating gender/political biases, and detecting harmful outputs [^2363^].

### 2.5 Inference-Time Intervention (ITI)

ITI trains a linear probe on activations of each attention head to predict whether an answer corresponds to a concept (e.g., truthfulness). Heads with highest probing accuracy are selected, and probe weight vectors are added to their activations during inference [^598^].

### 2.6 Low-Rank Representation Adaptation (LoRRA)

LoRRA (Zou et al., 2023) trains a LoRA adapter to output activations similar to adding a steering vector to original activations. This can steer high-level concepts including honesty, emotions, and ethical values [^598^].

### 2.7 Dynamic Steering

Intervention strength can be set dynamically at inference time based on probes, unsupervised clustering, KL divergence, cosine similarity of activation matrices, or gradient-based optimization [^595^].

### 2.8 Limitations

- Steering works for semantic concepts but cannot enforce discrete constraints (e.g., JSON syntax) [^2363^]
- Does not track state across token sequences or guarantee token-level correctness [^2363^]
- High steering strength with multi-layer injection can cause representation collapse [^2639^]
- A direction that reads well but steers poorly suggests the representation is correlated but not causal [^2672^]

---

## 3. ROME: Rank-One Model Editing

### 3.1 Foundation: Causal Tracing

ROME (Meng et al., 2022) builds on causal tracing to localize factual associations in GPT models [^2681^]. The methodology involves:

1. **Clean prompt**: Run the model normally and cache activations
2. **Corrupted prompt**: Add Gaussian noise $\mathcal{N}(0, \nu)$ to token embeddings (where $\nu = 3\sigma$ of the embedding set)
3. **Patched run**: Restore cached activations one component at a time during corrupted inference [^2682^][^2686^]

**Key finding**: Restoring the *last subject token* at *middle MLP layers* (layers 5--10 in GPT-2 XL) is sufficient to recover factual recall [^2686^]. Factual associations are stored in specific MLP weights, not distributed across the network.

### 3.2 The Localized Factual Association Hypothesis

The hypothesis posits that midlayer MLP modules accept inputs encoding a subject and produce outputs recalling memorized properties. Middle layer MLP outputs accumulate information, then attention at high layers copies the summed information to the last token [^2681^].

### 3.3 ROME Algorithm

ROME interprets feed-forward layers as linear associative memories encoding key-value pairs. For a factual association $(x_i, r, x_j)$:
- **Key** $k_*$: determined by the subject $x_i$
- **Value** $v_*$: the object $x_j$ to be recalled

ROME applies a rank-one update to MLP weights [^2637^]:

$$
\hat{W} = W_0 + \Delta \quad \text{where} \quad \Delta = (v_* - W_0 k_*) \frac{k_*^T C^{-1}}{k_*^T C^{-1} k_*}
$$

Where $C$ is the uncentered covariance of keys at that layer. This causes $W_{\text{proj}}^{(l)} k_* = v_*$ while minimizing interference with other memories [^2681^].

### 3.4 Performance and Limitations

ROME performs well for single edits (~100% edit success) but degrades starting at $n=32$ sequential edits [^2642^]. It suffers from "representation shattering" where edits disrupt the underlying geometric structure of representations, degrading logical inference and compositional reasoning [^2637^].

---

## 4. MEMIT: Mass-Editing Memory in a Transformer

### 4.1 Conceptual Framework

MEMIT extends ROME to perform thousands of edits simultaneously [^2641^]. It modifies the MLP weights of a *range* of critical layers (for GPT-J: $\mathcal{R} = \{3, 4, 5, 6, 7, 8\}$) [^2641^].

### 4.2 The Preservation-Memorization Objective

Both ROME and MEMIT optimize the same preservation-memorization objective [^2643^]:

$$
\min_{\hat{W}} \lambda \|\hat{W} K_0 - W_0 K_0\|_F^2 + \|\hat{W} K_E - V_E\|_F^2
$$

Where:
- $W_0, \hat{W}$: original and updated weight matrices
- $K_0$: keys for knowledge to be preserved
- $K_E, V_E$: edited keys and values for insertion
- $\lambda$: trade-off parameter

ROME optimizes an **equality-constrained** version; MEMIT optimizes a **least-squares** version enabling closed-form batched solutions [^2643^].

### 4.3 Multi-Layer Update Distribution

For a set of new memories, MEMIT calculates update $\Delta$ and spreads it across all mediating MLP layers such that at the final layer, the output captures all new memories [^2641^].

### 4.4 Scaling Performance

MEMIT significantly outperforms single-edit methods at scale [^2642^]:

| Method | # Edits | Efficacy (ES) | Paraphrase (PS) | Neighborhood (NS) | Composite Score |
|--------|---------|---------------|-----------------|-------------------|-----------------|
| ROME | 1 | ~100% | High | High | High |
| MEMIT | 1--10k | >85% (at 10k) | High | High | **85.8** |
| MEND | 1--1k | Drops sharply | Moderate | Low | Lower |

On GPT-J 6B with 10,000 CounterFact edits [^2642^]:
- MEMIT: Score 85.8, Efficacy 98.9%, Generalization 88.6%, Specificity 73.7%
- ROME (sequential): Score 50.3, rapidly degraded
- FT-W: Score 67.6 but suffers generation failure (model damage)
- MEND: Score 23.1, negligible effect at 10,000 edits

### 4.5 Limitations

- Certain relations are more difficult to edit with robust specificity [^2642^]
- Limited to directional $(s, r, o)$ relations; does not cover spatial/temporal reasoning, mathematical knowledge, procedural knowledge, or symmetric relations [^2642^]
- "Tim Cook is CEO of Apple" must be processed separately from "The CEO of Apple is Tim Cook" [^2642^]
- Same methods could enable malicious actors to insert false information [^2642^]

---

## 5. LoRA Injection for Behavior Modification

### 5.1 Low-Rank Adaptation Fundamentals

LoRA introduces trainable low-rank matrices $A$ and $B$ into specific transformer layers while keeping pretrained weights frozen [^2644^]:

$$
W = W_0 + BA
$$

During backpropagation, only $A$ and $B$ receive gradients. The effective weight update is constrained to a low-rank subspace. LoRA leverages the observation that weight updates during fine-tuning are often rank-deficient [^2644^].

### 5.2 Scaling Factor $\alpha/r$

Every adapter output is scaled by $\alpha/r$ before addition:

$$
h = W_0 x + \frac{\alpha}{r} BAx
$$

- $\alpha = r$: scaling factor = 1.0 (unit strength)
- $\alpha = 2r$: twice the strength, faster learning but risk of destabilizing the residual stream
- $\alpha = r/2$: conservative injection, appropriate for limited data [^2639^]

### 5.3 Rank-Stabilized LoRA (rsLoRA)

Standard LoRA has a structural problem at high ranks: variance scales linearly with $r$, and the $1/r$ term over-suppresses updates. rsLoRA replaces scaling with $\alpha/\sqrt{r}$, maintaining constant output and gradient norms regardless of rank [^2639^].

### 5.4 LoRA for Model Surgery

LoRA adapters enable:
- **Task switching**: Swap adapters without retraining the base model [^2644^]
- **Behavior modification**: Inject domain-specific or safety-oriented behaviors
- **Composable modifications**: Multiple LoRAs can be merged or interpolated
- **LoRRA**: Train adapters to reproduce activation-steering effects [^598^]

### 5.5 Residual Stream Integrity

If $\alpha/r$ is set high while adapters are applied across all targeted layers simultaneously, each layer injects an amplified update into the stream passed to the next layer. These amplifications compound across layers, potentially causing the residual representation to lose coherence with the pre-trained structure entirely [^2639^].

---

## 6. Weight Patching and Model Surgery

### 6.1 Weight Patching as Source Localization

Weight Patching shifts intervention targets from activations to parameters [^2638^]. In a paired-model setting ($M_{\text{base}}$ vs. $M_{\text{sft}}$), it tests whether transplanting a component's specialized parameters into the base model recovers target behavior.

For component $c$, the single-component patched model is:

$$
M_{\text{base}}^{(c \leftarrow \text{sft})} := \text{Replace}(M_{\text{base}}, M_{\text{sft}}; \Theta^{(c)})
$$

The source-level effect is quantified by:

$$
E_w(c) = \mathbb{E}_{x \sim \mathcal{D}_{\text{inst}}} \left[ \frac{\mathcal{F}_a(M_{\text{base}}^{(c \leftarrow \text{sft})}, x) - \mathcal{F}_a(M_{\text{base}}, x)}{G(x)} \right]
$$

A large $E_w(c)$ indicates the component's specialized parameters make a substantial contribution to recovering the target capability [^2638^].

### 6.2 Parameter Slice Definitions

For **attention heads** $H^{(l,h)}$:

$$
\Theta^{(H^{(l,h)})} = \{W_Q^{(l,h)}, W_O^{(l,h)}\}
$$

For **MLP neurons** $N^{(l,j)}$ in SwiGLU:

$$
\Theta^{(N^{(l,j)})} = \{W_{\text{gate}}^{(l)}[:, j], W_{\text{up}}^{(l)}[:, j], W_{\text{down}}^{(l)}[j, :]\}
$$

This preserves the full feature-detection, gating, and write-back interface [^2638^].

### 6.3 Key Finding: Source-Aggregation Separation

Across Llama-3.1-8B and Llama-2-13B [^2638^]:
- **Activation Patching** highlights attention heads and adjacent neurons in middle-to-late layers (aggregation/routing bottlenecks)
- **Weight Patching** isolates parameter subsets in **shallow-layer MLP neurons** (source-level carriers)

This separation between parameter sources and activation routers is a general structural property of instruction-tuned LLMs [^2638^].

### 6.4 Activation Patching and Circuit Tracing

TransformerLens enables activation patching across 50+ model families including GPT-2, LLaMA, and Mistral [^2668^]. The standard workflow is:

1. Define scope and hypothesis about behavior
2. Extract features via sparse autoencoders and probing
3. Perform targeted ablations and activation patching to establish causality
4. Document interpretable maps with actionable steering recommendations [^2669^][^2674^]

---

## 7. Model Editing for Safety: Removing Harmful Knowledge

### 7.1 SafeLLM: Unlearning Harmful Outputs

SafeLLM proposes a three-stage pipeline for jailbreak defense [^2648^]:

1. **Dynamic unsafe output detection**: Hybrid external classifier + model self-evaluation
2. **Token-level harmful content tracing**: Trace through FFN activations to localize harmful knowledge
3. **Constrained optimization**: Suppress unsafe behavior without degrading model quality

The parameter adjustment is formulated as a regularized least-squares problem:

$$
\Delta = \arg\min_{\Delta} \|(W_0 + \Delta) K_{w_s} - V_m\|_F^2 + \lambda \|\Delta K_c\|_F^2
$$

Where $K_{w_s}$ denotes harmful keys and $K_c$ denotes benign keys. The closed-form solution:

$$
\Delta^{\ell} = E_s^{\ell} K_{w_s}^\top \left( K_{w_s} K_{w_s}^\top + \lambda K_c K_c^\top \right)^{-1}
$$

Applied to FFN output weights: $W_0^{\ell} \leftarrow W_0^{\ell} + \Delta^{\ell}$ [^2648^].

### 7.2 Model Editing for Unlearning

Model editing can surpass traditional unlearning methods in forgetting quality [^2646^]. Three target definitions for removing information:

1. **Dummy**: Replace target with generic/empty response
2. **Incorrect**: Replace with factually wrong information
3. **Avoidant** (novel): Train model to refuse answering

Findings [^2646^]:
- ROME performs well with simple Dummy edits but degrades significantly with complexity and quantity
- IKE shows promise but does not edit model weights (context-only)
- WISE retains model utility but struggles with forget quality
- Effective forgetting requires trade-offs with overall model performance

### 7.3 Representation Shattering and Unlearning Limits

Patil et al. (2023) found that deleted content remains accessible in hidden states and via rephrased queries, highlighting the difficulty of truly removing knowledge from LLMs [^2646^]. Counterfactual edits with larger distance display larger degrees of representation shattering [^2637^].

---

## 8. Model Merging: TIES, Task Arithmetic, Model Soups, DARE

### 8.1 Task Arithmetic

Task Arithmetic (Ilharco et al., 2023) frames merging as vector addition in weight space. Given base model $W_0$ and fine-tuned variant $W_i$, the task vector is [^2647^]:

$$
\Delta W_i = W_i - W_0
$$

Merged model:

$$
\Delta W_{\text{TA}} = \sum_{i=1}^{n} \alpha_i \Delta W_i, \quad W_{\text{merged}} = W_0 + \lambda \Delta W_{\text{TA}}
$$

Setting $\alpha_i = 1$ and $\alpha_j = -1$ enables "forgetting by negation" and "learning by addition" [^2647^].

### 8.2 TIES-Merging

TIES (Yadav et al., 2023) mitigates conflicts in three stages [^2647^][^2650^]:

1. **Trim**: Retain only top-$k$% parameters by absolute magnitude in $\Delta W_i$; reset rest to zero
2. **Select signs**: Compute sign consensus across checkpoints; mask out parameters disagreeing with consensus
3. **Disjoint merge**: Average aligned parameters and add to base:

$$
\Delta W_{\text{TIES}} = \frac{1}{n} \sum_{i=1}^{n} \alpha_i \Delta W_i^{\text{masked}}, \quad W_{\text{merged}} = W_0 + \lambda \Delta W_{\text{TIES}}
$$

### 8.3 Model Stock

Model Stock (Jang et al., 2024) interpolates between $W_0$ and the geometric center of fine-tuned checkpoints [^2647^]:

$$
W_{\text{avg}} = \frac{1}{N} \sum_{i=1}^{N} W_i, \quad t = \frac{N \cos \theta}{1 + (N-1) \cos \theta}
$$

$$
W_{\text{merged}} = t \cdot W_{\text{avg}} + (1-t) \cdot W_0
$$

Where $\theta$ is the mean inter-model angle. Tight alignment (small $\theta$) $\rightarrow$ more weight on average; diverse checkpoints $\rightarrow$ more weight on base.

### 8.4 Model Soups (Weight Averaging)

The simplest form of merging averages weight tensors element-wise [^2650^]:

$$
\theta_{\text{merged}} = \frac{1}{n} \sum_{i=1}^{n} \theta_i
$$

Modern LLMs fine-tuned from shared pretraining checkpoints are close in weight space, making averaging surprisingly effective [^2650^].

### 8.5 DARE: Drop and Rescale

DARE (Yu et al., 2023) randomly drops delta parameters and rescales survivors [^2680^][^2683^]:

1. Draw $m_t \sim \text{Bernoulli}(p)$ for each delta parameter
2. Rescale remaining by $1 / (1-p)$
3. Add rescaled deltas to pretrained weights

Key finding: SFT delta parameter ranges are typically small (within 0.002--0.005). DARE can eliminate **90--99%** of them without performance loss [^2680^][^2692^]. Larger models tolerate higher drop rates.

DARE workflow example for merging WizardLM + WizardMath [^2689^]:
- WizardLM GSM8K accuracy: 2.2 (before) $\rightarrow$ 66.3 (after merging with WizardMath)
- Retains instruction-following while surpassing WizardMath's original 64.2

### 8.6 DELLA-Merging

DELLA replaces DARE's random dropping with magnitude-based sampling (MagPrune) [^2679^]:
- Rank delta magnitudes; assign drop probability inversely proportional to magnitude
- Larger magnitude parameters have lower drop probability
- Rescale by $1 / (1 - p_i)$ where $p_i$ is parameter-specific drop probability

DELLA outperforms DARE and TIES on three out of four merges, averaging +2.4 points over DARE and +3.6 over TIES [^2679^].

### 8.7 Practical MergeKit Configuration

Example DARE-TIES merge configuration for Llama-3.1-8B [^2683^]:

```yaml
models:
  - model: NousResearch/Hermes-3-Llama-3.1-8B
    parameters:
      weight: 0.3
  - model: deepseek-ai/DeepSeek-R1-Distill-Llama-8B
    parameters:
      weight: 0.7
merge_method: dare_ties
base_model: meta-llama/Llama-3.1-8B-Instruct
parameters:
  lambda: 0.5
  density: 0.7
```

---

## 9. MEND: Hypernetwork-Based Model Editing

### 9.1 Architecture

MEND (Mitchell et al., 2022) trains small auxiliary editing networks that transform fine-tuning gradients into effective parameter updates [^2684^][^2687^]. It uses **low-rank decomposition of gradients** to make the transformation tractable.

Key properties:
- Can be trained on a single GPU in < 1 day for 10B+ parameter models
- Once trained, enables rapid application of new edits
- The only approach effective for models with > 10B parameters at the time of publication [^2684^]

### 9.2 Gradient Transformation

Each MEND layer consists of two consecutive blocks initialized to compute the identity function of the normalized decomposed gradient [^2691^]. Inputs are decomposed gradients; outputs are pseudo-activations and pseudo-deltas encapsulating reliability, generality, and locality.

### 9.3 Limitations

- MEND is strictly tied to the weights of the starting model; performance degrades as edited model diverges [^2691^]
- Shows large regression over 100 simultaneous edits [^2691^]
- MEND drops sharply in efficacy with batch size > 1, losing all effect before 1,000 edits [^2640^]

---

## 10. SERAC: Memory-Based Model Editing

### 10.1 Semi-Parametric Approach

SERAC (Mitchell et al., 2022) stores edits in external memory rather than model parameters [^2666^][^2673^]. It consists of:

1. **Scope classifier**: Determines if prompt falls within scope of cached edits
2. **Counterfactual model**: Generates outputs conditioned on retrieved edits

$$
f^*_{\phi, \omega}(x) = \begin{cases} f_\phi(x), & \text{if } x \text{ not in scope of any edit} \\ f_c(x, \mathcal{E}), & \text{otherwise} \end{cases}
$$

### 10.2 Advantages

- Does not require access to base model parameters, activations, or gradients (treats as black box) [^2666^]
- Can be trained once and immediately edit multiple models with different architectures
- Consumes edits specified in natural language rather than input-output pairs [^2666^]
- Excels when multiple edits are applied, when scope is complex, and when edits are not specified as input-output pairs [^2666^]

### 10.3 Limitations

- Relies on dataset of edits for training classifier and counterfactual model [^2666^]
- Edit memory may grow without bound in continuous editing settings [^2666^]
- Could enable malicious users to craft agents amplifying particular viewpoints [^2666^]

---

## 11. Lifelong Knowledge Editing and Stability

### 11.1 The Sequential Editing Problem

Existing methods (ROME, MEMIT, GRACE, AlphaEdit) demonstrate specialization in locality or accuracy but fail to achieve high performance across all three metrics simultaneously [^2645^]:

- **GRACE**: Perfect locality, limited generality
- **ROME/MEMIT**: Poor reliability and generality under sequential editing
- **FT**: Significant decline in reliability and generality due to overfitting

### 11.2 AlphaEdit: Null-Space Constraints

AlphaEdit (Fang et al., 2025) projects parameter updates onto the null space of the covariance matrix of previously learned knowledge [^2667^][^2645^]:

- Ensures new edits are orthogonal to existing knowledge features
- Maintains original model performance even after 3,000 edits on all metrics [^2667^]
- Prevents distributional shift in hidden representations (verified via t-SNE) [^2667^]

On MQuAKE and LEME benchmarks for multi-hop reasoning [^2667^]:

| Method | Multi-hop | Multi-hop (CoT) | Edit Consistency |
|--------|-----------|-----------------|------------------|
| MEMIT | 3.35 | 6.13 | 2.11 |
| AlphaEdit | **5.03** | **9.14** | **3.34** |

### 11.3 Norm-Constrained MEMIT

Explicit Frobenius norm constraints substantially improve MEMIT's sequential editing [^2676^]:

$$
\hat{W} = W_0 + \Delta \quad \text{where} \quad \Delta = (V_1 - W_0 K_1) K_1^\top (\lambda_p K_0 K_0^\top + K_1 K_1^\top + \lambda_n I)^{-1}
$$

MEMIT + Norm Constraint outperforms all prior methods on Llama-2-7B and all except AlphaEdit on Llama3-8B [^2676^]. AlphaEdit itself **completely fails without its norm constraint** -- after 10,000 edits the model effectively collapses [^2676^].

### 11.4 R-ROME

R-ROME (Gupta et al., 2024) minimizes model collapse associated with ROME edits and enhances stability during sequential editing by adding regularization terms to the optimization objective [^2645^][^2678^].

---

## 12. Knowledge Editing Benchmarks and Reliability Metrics

### 12.1 Core Datasets

| Dataset | Description | Purpose |
|---------|-------------|---------|
| **CounterFact** | Counterfactual knowledge with lower generation probability | Primary editing benchmark [^2645^] |
| **ZSRE** | Zero-shot relation extraction QA | Scale testing (up to 10,000 edits) [^2642^] |
| **RIPE** | Ripple effects of injecting knowledge into related facts | Evaluating compositional effects [^2645^] |
| **MQuAKE** | Multi-hop reasoning and long-form editing | Multi-hop consistency [^2667^] |
| **WMDP** | Biosecurity, chemical, cybersecurity knowledge | Safety/unlearning evaluation [^2646^] |

### 12.2 Core Metrics

**Reliability (Efficacy/Edit Success)**: Whether the edited model produces the correct updated answer for queries targeting modified knowledge [^2645^]:

$$
\text{Reliability} = \frac{1}{|X^{\text{rel}}|} \sum_{i=1}^{|X^{\text{rel}}|} \mathbb{I}(f^*(q_i^{\text{rel}}) = o_i^*)
$$

**Generality (Paraphrase Success)**: Generalization across rephrased prompts [^2640^].

**Locality (Neighborhood Success)**: Unedited nearby facts remain unchanged [^2640^].

**Fluency**: Generation quality measured by perplexity or entropy [^2642^].

**Composite Score**: Harmonic mean of efficacy, generalization, and specificity [^2642^].

### 12.3 Current SOTA Benchmarks

Selected results from the knowledge editing leaderboard [^2649^]:

| Benchmark | SOTA Method | Metric | Score |
|-----------|-------------|--------|-------|
| Counterfact | EAMET | Efficacy | 93.87 |
| ZSRE | MetaKE | Generality | 97.37 |
| CounterFact 10k facts | GRACE | Reliability | 100 |
| Counterfact | LightEdit | AVG Score | 92.96 |
| MQuAKE | CoT2Edit | Edit Success Rate | 99.95 |

---

## 13. Practical Implementation for Local 7B/8B Models

### 13.1 EasyEdit Framework

EasyEdit (Zhejiang University NLP team) is the primary open-source framework for LLM knowledge editing [^2670^][^2694^]. It encompasses three paradigms:

1. **Memory-Based Editing**: SERAC, IKE
2. **Meta-Learning Editing**: MEND, KE
3. **Locate-Then-Edit**: ROME, MEMIT, KN

Supported models include LLaMA-2-7B, LLaMA-3-8B, GPT-J, GPT-NeoX, and many others [^2670^].

Installation [^2670^]:
```bash
git clone https://github.com/zjunlp/EasyEdit.git
conda create -n EasyEdit python=3.9.7
cd EasyEdit
pip install -r requirements.txt
```

### 13.2 Training MEND for LLaMA-7B

```python
from easyeditor import EditTrainer, MENDTrainingHparams, ZsreDataset

training_hparams = MENDTrainingHparams.from_hparams('hparams/TRAINING/MEND/llama-7b.yaml')
train_ds = ZsreDataset('./data/zsre/zsre_mend_train.json', config=training_hparams)
eval_ds = ZsreDataset('./data/zsre/zsre_mend_eval.json', config=training_hparams)
trainer = EditTrainer(config=training_hparams, train_set=train_ds, val_set=eval_ds)
trainer.run()
```

### 13.3 Running ROME/MEMIT on LLaMA-2-7B

Experiments with EasyEdit on LLaMA-2-7B demonstrate that parameter-modifying methods (ROME, MEMIT) can update factual knowledge in seconds with minimal code [^2670^].

### 13.4 Model Merging with MergeKit

MergeKit (Goddard et al., 2024) is the standard toolkit for model merging [^2679^]. It supports TIES, DARE, DELLA, and Task Arithmetic for models like Llama-3.1-8B and Mistral-7B.

### 13.5 Activation Patching with TransformerLens

For local circuit analysis [^2668^][^2669^]:
- Install TransformerLens and baukit
- Use HookPoints to inspect activations at any layer
- Perform causal tracing via activation patching
- Supports LLaMA, Mistral, GPT-2 families

### 13.6 Sparse Autoencoders with SAELens

SAELens enables training and analysis of sparse autoencoders on local models for feature extraction and steering [^2668^].

### 13.7 Hardware Considerations

- **MEND training**: Single GPU, < 1 day for 10B+ models [^2684^]
- **ROME/MEMIT editing**: No training required; edits apply in seconds [^2670^]
- **Model merging**: CPU-only possible; no retraining or GPUs needed [^2680^]
- **Activation patching**: Requires inference-only; minimal memory overhead
- **LoRA fine-tuning**: Standard consumer GPUs (16GB+ VRAM) sufficient for 7B/8B models

---

## 14. Unified Mathematical Formulations

### 14.1 Steering

$$
\tilde{h}^{(l)} = h^{(l)} + \alpha \cdot v_{\text{steer}}^{(l)}
$$

### 14.2 ROME Rank-One Update

$$
\hat{W}_{\text{proj}}^{(l)} = W_{\text{proj}}^{(l)} + (v_* - W_{\text{proj}}^{(l)} k_*) \frac{k_*^T C^{-1}}{k_*^T C^{-1} k_*}
$$

### 14.3 MEMIT Closed-Form Batch Update

$$
\min_{\hat{W}} \lambda \|\hat{W} K_0 - W_0 K_0\|_F^2 + \|\hat{W} K_E - V_E\|_F^2
$$

### 14.4 LoRA

$$
W_{\text{eff}} = W_0 + \frac{\alpha}{r} BA, \quad A \in \mathbb{R}^{r \times d}, B \in \mathbb{R}^{d \times r}
$$

### 14.5 Task Arithmetic

$$
W_{\text{merged}} = W_0 + \lambda \sum_{i=1}^{n} \alpha_i (W_i - W_0)
$$

### 14.6 DARE Delta Sparsification

$$
\hat{\Delta} = \frac{1}{1-p} (m \odot \Delta), \quad m \sim \text{Bernoulli}(1-p)
$$

### 14.7 SafeLLM Unlearning

$$
\Delta = \arg\min_{\Delta} \|(W_0 + \Delta) K_{w_s} - V_m\|_F^2 + \lambda \|\Delta K_c\|_F^2
$$

---

## 15. Summary Table: Methods Comparison

| Method | Type | Training Required | Batch Edits | Scalability | Key Strength | Key Weakness |
|--------|------|-------------------|-------------|-------------|--------------|--------------|
| **ROME** | Locate-then-edit | No | No | Low (single) | Exact single-edit (~100% ES) | Degrades at $n>32$ |
| **MEMIT** | Locate-then-edit | No | Yes | High (10k) | Mass editing, closed-form | Relation-specific limitations |
| **MEND** | Meta-learning | Yes | Limited | Low-Med | Works on >10B models | Degrades with sequential edits |
| **SERAC** | Memory-based | Yes | Yes | High | Black-box compatible | Memory grows unbounded |
| **LoRA** | PEFT | Yes | Yes | High | Composable, efficient | Residual stream risk at high $\alpha/r$ |
| **Activation Steering** | Inference-time | No | Yes | High | Dynamic, reversible | Cannot enforce hard constraints |
| **TIES** | Model merge | No | N/A | High | Reduces interference | Requires homologous models |
| **DARE** | Delta sparsify | No | N/A | High | 90-99% delta pruning | Random dropping suboptimal |
| **AlphaEdit** | Locate-then-edit | No | Yes | High | Null-space preservation | Needs norm constraint |
| **SafeLLM** | Safety editing | Yes (detector) | Limited | Med | Token-level tracing | Trade-off: forget vs. utility |

---

## 16. Safety Considerations and Ethical Implications

### 16.1 Dual-Use Concerns

Model editing methods shed light on internal mechanisms and reduce energy needed to fix errors, but the same methods might enable malicious actors to insert false or damaging information [^2642^]. SERAC's dialogue sentiment editing experiments suggest powerful editors could enable precisely crafting agents to amplify particular viewpoints [^2666^].

### 16.2 Unlearning Limitations

- Deleted content may remain accessible in hidden states [^2646^]
- Rephrased queries may recover supposedly unlearned knowledge [^2646^]
- Effective forgetting often comes at the cost of overall model performance [^2646^]
- There is a fundamental trade-off between knowledge erasure and preserving reasoning capacity [^2648^]

### 16.3 Reliability Warning

LLMs should not be used as authoritative sources of facts, and edited models are even less reliable [^2642^]. Memory-editing enables dynamic knowledge management but the model's confidence may not reflect actual accuracy.

### 16.4 Recommended Safeguards

1. Always evaluate edited models on reliability, generality, locality, and fluency metrics
2. Test for hidden-state leakage of supposedly removed knowledge
3. Monitor downstream task performance after any editing intervention
4. Consider SERAC or memory-based approaches when edit auditability is required
5. Use norm constraints (AlphaEdit, MEMIT+NC) for sequential editing to prevent model collapse

---

## 17. References

[^2363^] MaziyarPanahi. "Why Anthropic's SAE Steering Fails for Structured Output." HuggingFace Blog, 2026. https://huggingface.co/blog/MaziyarPanahi/sae-steering-json

[^2637^] "Representation Shattering in Transformers: A Synthetic..." arXiv:2410.17194, 2024. https://arxiv.org/html/2410.17194v1

[^2638^] "Toward Source-Level Mechanistic Localization in LLMs." arXiv:2604.13694, 2026. https://arxiv.org/html/2604.13694v1

[^2639^] "The Ultimate Guide to LoRA: How to Fine-Tune LLMs Correctly, Part 2." TowardsAI, 2026. https://pub.towardsai.net/the-ultimate-guide-to-lora-how-to-fine-tune-llms-correctly-part-2-659c75cf375b

[^2640^] "Mass-Editing Memory in Transformers." EmergentMind, 2025. https://www.emergentmind.com/topics/mass-editing-memory-in-a-transformer-memit

[^2641^] Meng et al. "Mass Editing Memory in a Transformer." ICLR 2023. https://memit.baulab.info/

[^2642^] Meng et al. "Mass-Editing Memory in a Transformer." ICLR 2023. https://belinkov.com/assets/pdf/iclr2023-memit.pdf

[^2643^] "A Unified Framework for Model Editing." ACL 2024 Findings. https://aclanthology.org/2024.findings-emnlp.903.pdf

[^2644^] "Parameter Efficient Fine-Tuning (PEFT)." Aman.ai Primers. https://aman.ai/primers/ai/parameter-efficient-fine-tuning/

[^2645^] "Towards Scalable Lifelong Knowledge Editing with Selective Knowledge Suppression." arXiv:2604.19089, 2026. https://arxiv.org/html/2604.19089v1

[^2646^] "Investigating Model Editing for Unlearning in Large Language Models." arXiv:2512.20794, 2025. https://arxiv.org/html/2512.20794v1

[^2647^] "A Systematic Study of Model Merging Techniques in Large Language Models." arXiv:2511.21437, 2025. https://arxiv.org/html/2511.21437v1

[^2648^] "SafeLLM: Unlearning Harmful Outputs from Large Language Models against Jailbreak Attacks." arXiv:2508.15182, 2025. https://arxiv.org/html/2508.15182v1

[^2649^] "SOTA Knowledge Editing benchmarks and papers with code." WizWand, 2026. https://www.wizwand.com/task/knowledge-editing

[^2650^] Michael Brenndoerfer. "Model Merging: Weight Averaging, Task Arithmetic, TIES, and DARE." 2026. https://mbrenndoerfer.com/writing/model-merging-weight-averaging-task-arithmetic-ties-dare

[^2666^] Mitchell et al. "Memory-Based Model Editing at Scale." arXiv:2206.06520. https://arxiv.org/pdf/2206.06520

[^2667^] "Null-Space Constrained Knowledge Editing for Language Models." arXiv:2410.02355, 2024. https://arxiv.org/html/2410.02355v3

[^2668^] "TransformerLens Interpretability." MCPMarket. https://mcpmarket.com/tools/skills/transformerlens-interpretability

[^2669^] Subhadip Mitra. "Circuit Tracing for the Rest of Us." 2026. https://subhadipmitra.com/blog/2026/circuit-tracing-production/

[^2670^] "EasyEdit -- Fixing and Updating Knowledge in Large Language Models." Medium, 2023. https://medium.com/@jack16900/easyedit-fixing-and-updating-knowledge-in-large-language-models-2f3df451ce8f

[^2671^] Mitchell et al. "Memory-Based Model Editing at Scale." ICML 2022. https://proceedings.mlr.press/v162/mitchell22a/mitchell22a.pdf

[^2672^] "Representation Control." Learn Mechanistic Interpretability, 2026. https://learnmechinterp.com/topics/representation-control/

[^2673^] "Knowledge Editing for Large Language Models: A Survey." ACM Computing Surveys, 2024. https://dl.acm.org/doi/10.1145/3698590

[^2674^] "Neuron Surgery | AI Interpretability & Ablation." https://neuronsurgery.com/

[^2675^] "Prompt-based model editing." Stanford CS224N. https://web.stanford.edu/class/archive/cs/cs224n/cs224n.1224/reports/custom_117170743.pdf

[^2676^] "Lifelong Knowledge Editing requires Better Regularization." EMNLP 2025 Findings. https://aclanthology.org/2025.findings-emnlp.1234.pdf

[^2677^] "easyeditor." PyPI. https://pypi.org/project/easyeditor/

[^2678^] "Lifelong Model Editing with Hierarchical Reinforcement Learning." arXiv:2604.11214, 2026. https://arxiv.org/html/2604.11214v1

[^2679^] "DELLA-Merging: Reducing Interference in Model Merging through Magnitude-Based Sampling." arXiv:2406.11617, 2024. https://arxiv.org/html/2406.11617v1

[^2680^] Yu et al. "Language Models are Super Mario: Absorbing Abilities from Homologous Models as a Free Lunch." arXiv:2311.03099, 2023. https://arxiv.org/abs/2311.03099

[^2681^] Meng et al. "Locating and Editing Factual Associations in GPT." arXiv:2202.05262. https://arxiv.org/pdf/2202.05262

[^2682^] "Toward Unified Modular Editing in LLMs." arXiv:2510.27400, 2025. https://arxiv.org/html/2510.27400v1

[^2683^] Ritvik Rastogi. "Papers Explained Review 13: Model Merging." Medium, 2025. https://ritvik19.medium.com/papers-explained-review-13-model-merging-d0db49797b90

[^2684^] Mitchell et al. "Fast Model Editing at Scale." arXiv:2110.11309, 2021. https://arxiv.org/abs/2110.11309

[^2685^] "MedMKEB: A Comprehensive Knowledge Editing..." AAAI 2025. https://ojs.aaai.org/index.php/AAAI/article/view/40705/44666

[^2686^] "Week 5: Causal Localization." Neural Mechanics. https://neural-mechanics.baulab.info/week5.html

[^2687^] Mitchell et al. "Fast Model Editing at Scale." ICLR 2022. https://openreview.net/pdf?id=0DcZxeWfOPt

[^2688^] "Revisiting Delta-Parameter Pruning for Fine-Tuning." ICLR 2025. https://proceedings.iclr.cc/paper_files/paper/2025/file/d0074bea472f8b9b839fa2d50ce67595-Paper-Conference.pdf

[^2689^] Yu et al. "MergeLM: Codebase for Merging Language Models." GitHub. https://github.com/yule-buaa/mergelm

[^2690^] "Reinforced Lifelong Editing for Language Models." ICML 2025. https://icml.cc/virtual/2025/poster/46622

[^2691^] "A Survey on Knowledge Editing of Neural Networks." Amazon Science. https://assets.amazon.science/a8/50/4a59dda14e17bdef77ce6c8b5ea0/a-survey-on-knowledge-editing-of-neural-networks.pdf

[^2692^] Cameron R. Wolfe. "Model Merging: A Survey." Substack, 2024. https://cameronrwolfe.substack.com/p/model-merging

[^2693^] "Language Models are Super Mario." HuggingFace Papers, 2023. https://huggingface.co/papers/2311.03099

[^2694^] "EasyEdit: An Easy-to-use Knowledge Editing Framework for LLMs." GitHub. https://github.com/zjunlp/EasyEdit

[^595^] "Representation Engineering for Large-Language Models." arXiv:2502.17601, 2025. https://arxiv.org/html/2502.17601v1

[^598^] Wehner. "Representation Engineering." arXiv:2502.19649, 2025. https://janwehner.com/files/representation_engineering.pdf
